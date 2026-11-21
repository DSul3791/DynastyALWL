#!/usr/bin/env python3
"""Verify history-backed document retirements; prepare reviewed expiry PRs after 168 hours."""
from pathlib import Path, PurePosixPath
from datetime import datetime, timedelta, timezone
import argparse
import hashlib
import json
import os
import posixpath
import re
import subprocess
import urllib.request

MANIFEST = 'docs/retirements.json'
TEXT_EXT = ('.md', '.markdown', '.txt', '.rst', '.adoc')
HISTORY_DIRS = ('docs/archive/', 'docs/mirror/')
CODE_EXT = ('.py', '.sh', '.gd', '.yml', '.yaml', '.json', '.cfg', '.godot', '.bat', '.cmd', '.ps1')
SHA = re.compile(r'^[0-9a-f]{40}$')


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.DEVNULL)


def safe_path(p):
    return isinstance(p, str) and '\\' not in p and ':' not in p and not PurePosixPath(p).is_absolute() and all(x not in ('', '..', '.') for x in p.split('/')) and bool(p)


def notice(p):
    return bool(re.search(r'(license|licence|copyright|attribution|credits|notices?|acknowledg|(^|/)sources\.)', p, re.I))


def blob(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()


def stamp(s):
    d = datetime.fromisoformat(s.replace('Z', '+00:00'))
    if d.tzinfo is None:
        raise ValueError('timestamp lacks timezone')
    return d.astimezone(timezone.utc)


def load(root):
    path = Path(root)/MANIFEST
    return json.loads(path.read_text()) if path.exists() else {'version': 1, 'batches': []}


def entry_map(data):
    return {e['retired']: (b, e) for b in data['batches'] for e in b['entries']}


def validate(root, data, deleted=(), now=None, previous=None, protected=(), integrations=None):
    """Return (errors, expiry-authorized paths). No network, clock override or bypass in CLI."""
    root = Path(root)
    now = now or datetime.now(timezone.utc)
    errors, allowed, seen = [], set(), set()
    deleted, protected = set(deleted), set(protected)
    try:
        if data['version'] != 1 or not isinstance(data['batches'], list):
            raise ValueError('unsupported manifest schema')
        old = entry_map(previous) if previous else {}
        current = entry_map(data)
        for path, (batch, entry) in old.items():
            if path not in current or current[path][1] != entry:
                errors.append(f'immutable recovery receipt changed or removed: {path}')
        # Raw path references in executable/configuration sources are conservative reader leads.
        texts = []
        for record in git(root, 'ls-files', '-v', '-z').decode().split('\0'):
            if not record:continue
            flag,p=record.split(' ',1)
            if p == MANIFEST or not p.endswith(CODE_EXT):
                continue
            f = root/p
            if f.is_file():
                texts.append((p, f.read_text(errors='replace')))
            elif flag.upper()=='S':
                # A sparse checkout must not turn a tracked reader into an apparent nonreader.
                texts.append((p,git(root,'show','HEAD:'+p).decode(errors='replace')))
        first_parent = set(git(root, 'rev-list', '--first-parent', 'origin/dev').decode().split())
        batch_ids = set()
        for b in data['batches']:
            if b['id'] in batch_ids:
                raise ValueError('duplicate batch ID')
            batch_ids.add(b['id'])
            source = b['source_commit']
            if not SHA.fullmatch(source):
                raise ValueError('invalid source commit')
            if subprocess.run(['git','merge-base','--is-ancestor',source,'origin/dev'],cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode:
                raise ValueError('source commit not in dev history')
            fields = [b.get(k) for k in ('retirement_commit', 'retired_at', 'expires_at', 'retirement_pr')]
            expired = False
            if any(fields):
                if not all(fields) or not SHA.fullmatch(fields[0]) or fields[0] not in first_parent:
                    raise ValueError('retirement must identify an actual first-parent dev integration')
                integrated = json.loads(git(root, 'show', fields[0]+':'+MANIFEST))
                original = next(x for x in integrated['batches'] if x['id'] == b['id'])
                if original['entries'] != b['entries'] or original['source_commit'] != source:
                    raise ValueError('retirement integration does not contain these exact recovery receipts')
                earlier = subprocess.run(['git','show',fields[0]+'^:'+MANIFEST],cwd=root,capture_output=True)
                if earlier.returncode == 0 and any(x['id']==b['id'] for x in json.loads(earlier.stdout)['batches']):
                    raise ValueError('retirement clock reset to a later integration')
                retired = stamp(fields[1]); expiry = stamp(fields[2])
                if not fields[1].endswith('Z') or not fields[2].endswith('Z'):
                    raise ValueError('receipt timestamps must be UTC Z')
                proof = (integrations or {}).get(str(fields[3]))
                if not proof or not proof.get('merged') or proof.get('base',{}).get('ref')!='dev' or proof.get('merge_commit_sha')!=fields[0] or proof.get('merged_at')!=fields[1]:
                    raise ValueError('verified GitHub dev integration event required')
                if retired > now or expiry != retired+timedelta(hours=168):
                    raise ValueError('invalid integration time or 168-hour expiry')
                expired = now >= expiry
            for e in b['entries']:
                p, original, identity = e['retired'], e['original'], e['blob']
                if not safe_path(p) or not safe_path(original) or not p.startswith(HISTORY_DIRS) or not p.lower().endswith(TEXT_EXT) or not original.lower().endswith(TEXT_EXT):
                    raise ValueError(f'not an eligible historical text document: {p}')
                if notice(original) or notice(p):
                    raise ValueError(f'license/attribution provenance cannot expire here: {p}')
                if p in seen:
                    raise ValueError('duplicate retired path: '+p)
                seen.add(p)
                source_bytes=git(root, 'show', source+':'+original)
                if re.search(rb'SPDX-License-Identifier|Permission is hereby granted|Copyright\s*(?:\(c\)|[0-9]{4})',source_bytes,re.I):
                    raise ValueError('embedded license/notice needs explicit retention: '+original)
                if not SHA.fullmatch(identity) or blob(source_bytes) != identity:
                    raise ValueError('unrecoverable source blob: '+original)
                if all(fields) and blob(git(root, 'show', fields[0]+':'+p)) != identity:
                    raise ValueError('retirement integration did not preserve this exact file: '+p)
                if not e.get('reason') or not e.get('disposition'):
                    raise ValueError('missing preservation disposition: '+p)
                target = e.get('target')
                if target and (not safe_path(target) or not (root/target).is_file() or target in current):
                    raise ValueError('missing or retired preservation target: '+str(target))
                f = root/p
                if f.exists() and blob(f.read_bytes()) != identity:
                    raise ValueError('retired content changed: '+p)
                if not f.exists() and p not in deleted:
                    # Already deleted in an earlier validated integration is recoverable from receipt.
                    existed = bool(git(root, 'ls-tree', 'origin/dev', '--', p).strip())
                    if existed or not expired:
                        raise ValueError('historical file missing outside an expired deletion: '+p)
                touched = p in deleted or original in deleted
                if touched:
                    if p in protected or original in protected or (target and target in protected):
                        errors.append('document belongs to active branch work: '+p)
                        continue
                    readers = [name for name,text in texts if p in text or original in text]
                    if readers:
                        errors.append('retired document still referenced by tool/config: '+p+' <- '+', '.join(readers))
                        continue
                if p in deleted:
                    if not expired:
                        errors.append('document recovery window not expired: '+p)
                    else:
                        allowed.add(p)
        if previous:
            old_batches = {b['id']:b for b in previous['batches']}
            for b in data['batches']:
                old_b = old_batches.get(b['id'])
                if old_b and old_b.get('retirement_commit') and any(old_b.get(k)!=b.get(k) for k in ('source_commit','retirement_commit','retired_at','expires_at','retirement_pr')):
                    errors.append('finalized retirement time/identity changed: '+b['id'])
    except (KeyError, TypeError, ValueError, StopIteration, subprocess.CalledProcessError, OSError) as exc:
        errors.append('invalid document retirement manifest: '+str(exc))
    return errors, allowed


def api(path):
    repo = os.environ.get('GITHUB_REPOSITORY', 'DSul3791/DynastyALWL')
    headers={'Accept':'application/vnd.github+json','User-Agent':'document-retirement'}
    token=os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    if token: headers['Authorization']='Bearer '+token
    request=urllib.request.Request('https://api.github.com/repos/'+repo+'/'+path,headers=headers)
    with urllib.request.urlopen(request,timeout=30) as response:
        return json.load(response)


def integration_events(data):
    return {str(b['retirement_pr']):api('pulls/'+str(b['retirement_pr'])) for b in data['batches'] if b.get('retirement_pr')}


def active_work(root):
    """Protect open PR paths and recent unmerged branches; fail closed without live PR access."""
    token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    if not token:
        raise ValueError('live active-work check requires GitHub token; no expiry deletion prepared')
    own_pr=None;own_branch=None
    event_path=os.environ.get('GITHUB_EVENT_PATH')
    if event_path:
        event=json.loads(Path(event_path).read_text())
        own_pr=event.get('pull_request',{}).get('number')
        own_branch=event.get('pull_request',{}).get('head',{}).get('ref')
    def pages(path):
        result=[]
        for page in range(1,101):
            batch=api(path+('&' if '?' in path else '?')+f'per_page=100&page={page}')
            result.extend(batch)
            if len(batch)<100:return result
        raise ValueError('active-work pagination limit exceeded')
    protected=set();ref_cache={}
    # Closed, unchanged PR heads are completed/retired work, not active merely because their
    # branch still exists. Unmatched heads remain protected, including work resumed after closure.
    closed_heads={(p['head']['ref'],p['head']['sha']) for p in api('pulls?state=closed&sort=updated&direction=desc&per_page=100')}
    def referenced(ref, paths):
        """Protect explicit document contracts used by changed branch files as well as edits."""
        key=(ref,tuple(sorted(paths)))
        if key in ref_cache:return ref_cache[key]
        result=set()
        if subprocess.run(['git','cat-file','-e',ref+'^{commit}'],cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode:
            git(root,'fetch','origin',ref)
        for p in paths:
            if not p.endswith(CODE_EXT+TEXT_EXT):continue
            content=subprocess.run(['git','show',ref+':'+p],cwd=root,capture_output=True)
            if content.returncode:continue  # renamed/deleted source is protected by its old path
            text=content.stdout.decode(errors='replace')
            values=(re.findall(r'`([^`\n]+\.(?:md|txt|markdown|rst|adoc))`',text)
                    +re.findall(r'\]\(([^)#\s]+)',text)
                    +re.findall(r'''["']([^"'\n]+\.(?:md|txt|markdown|rst|adoc))["']''',text))
            for value in values:
                value=value.removeprefix('res://')
                for candidate in (value,posixpath.normpath(str(PurePosixPath(p).parent/value))):
                    if safe_path(candidate) and candidate.endswith(TEXT_EXT) and subprocess.run(['git','cat-file','-e',ref+':'+candidate],cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:
                        result.add(candidate)
        ref_cache[key]=result
        return result
    for pr in pages('pulls?state=open'):
        if pr['number']==own_pr:
            continue
        branch_paths=set()
        for f in pages(f"pulls/{pr['number']}/files"):
            protected.add(f['filename'])
            branch_paths.add(f['filename'])
            if f.get('previous_filename'):protected.add(f['previous_filename'])
        protected.update(referenced(pr['head']['sha'],branch_paths))
    cutoff=datetime.now(timezone.utc)-timedelta(hours=72)
    for line in git(root,'for-each-ref','--format=%(refname:short)\t%(committerdate:iso8601-strict)','refs/remotes/origin').decode().splitlines():
        ref, date=line.split('\t')
        if not date or ref in ('origin/dev','origin/main','origin/HEAD','origin/'+str(own_branch)) or stamp(date) < cutoff:
            continue
        if (ref.removeprefix('origin/'),git(root,'rev-parse',ref).decode().strip()) in closed_heads:
            continue
        if subprocess.run(['git','merge-base','--is-ancestor',ref,'origin/dev'],cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode:
            branch_paths=set(git(root,'diff','--no-renames','--name-only','origin/dev...'+ref).decode().splitlines())
            protected.update(branch_paths)
            protected.update(referenced(ref,branch_paths))
    return protected


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=('check','prepare'))
    parser.add_argument('--base',default='origin/dev')
    args=parser.parse_args(); root=Path(__file__).resolve().parent.parent
    data=load(root)
    if args.command=='check':
        deleted=git(root,'diff','--no-renames','--name-only','--diff-filter=D',args.base).decode().splitlines()
        prior=subprocess.run(['git','show',args.base+':'+MANIFEST],cwd=root,capture_output=True)
        previous=json.loads(prior.stdout) if prior.returncode==0 else None
        touched=set(deleted)&{e[k] for b in data['batches'] for e in b['entries'] for k in ('original','retired')}
        errors,allowed=validate(root,data,deleted,previous=previous,protected=active_work(root) if touched else (),integrations=integration_events(data))
        for e in errors:print('FAIL:',e)
        print(f'Document retirement: {len(entry_map(data))} receipts, {len(allowed)} expired deletions authorized')
        return bool(errors)
    protected=active_work(root)
    candidates=[p for p,(b,e) in entry_map(data).items() if (root/p).is_file() and b.get('expires_at') and datetime.now(timezone.utc)>=stamp(b['expires_at'])]
    errors,allowed=validate(root,data,candidates,protected=protected,integrations=integration_events(data))
    # Schema/recovery failures hold all deletions; independent reader/work holds can be split.
    if any(e.startswith('invalid ') for e in errors):
        raise ValueError('\n'.join(errors))
    for p in sorted(allowed):(root/p).unlink()
    for e in errors:print('HELD:',e)
    print(f'Prepared {len(allowed)} expired document removals; {len(errors)} holds')
    return bool(errors and not allowed)


if __name__=='__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print('FAIL:',exc)
        raise SystemExit(1)
