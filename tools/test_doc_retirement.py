#!/usr/bin/env python3
"""Exercise real Git history, integration clocks, reader and work protection without live writes."""
from pathlib import Path
from datetime import datetime, timedelta, timezone
import copy
import json
import os
import subprocess
import tempfile
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import doc_retirement as dr


def check(label, data, ok=True, deleted=(), protected=(), previous=None, mutate=None, contains='', proof_override=None):
    candidate=copy.deepcopy(data)
    if mutate: mutate(candidate)
    errors,allowed=dr.validate(root,candidate,deleted,now,previous,protected,proof if proof_override is None else proof_override)
    assert (not errors)==ok,(label,errors)
    if contains: assert any(contains in e for e in errors),(label,errors)
    if ok and deleted: assert set(deleted)==allowed,(label,allowed)
    print('PASS:',label)


with tempfile.TemporaryDirectory(prefix='document-retirement-') as folder:
    root=Path(folder)
    def git(*args, env=None):
        return subprocess.check_output(['git',*args],cwd=root,env=env,stderr=subprocess.DEVNULL).decode().strip()
    git('init','-b','dev');git('config','user.name','Fixture');git('config','user.email','fixture@example.invalid')
    original='docs/archive/old.md';(root/'docs/archive').mkdir(parents=True)
    (root/original).write_text('Historical result.\n');(root/'docs/live.md').write_text('Historical result.\n');git('add','.');git('commit','-m','source')
    source=git('rev-parse','HEAD');identity=git('rev-parse','HEAD:'+original)
    data={'version':1,'batches':[{'id':'fixture','source_commit':source,'retirement_commit':None,'retired_at':None,'expires_at':None,'entries':[
        {'original':original,'retired':original,'blob':identity,'disposition':'already-historical','reason':'Frozen checkpoint, not active instructions','target':None}]}]}
    (root/dr.MANIFEST).write_text(json.dumps(data));git('checkout','-b','cleanup');git('add','.');git('commit','-m','retire')
    git('checkout','dev');date='2026-11-01T12:00:00Z';env=dict(os.environ,GIT_COMMITTER_DATE=date)
    git('merge','--no-ff','cleanup','-m','integrate retirement',env=env)
    integrated=git('rev-parse','HEAD');git('update-ref','refs/remotes/origin/dev',integrated)
    b=data['batches'][0];b.update(retirement_commit=integrated,retired_at=date,expires_at='2026-11-08T12:00:00Z',retirement_pr=17)
    proof={'17':{'merged':True,'base':{'ref':'dev'},'merge_commit_sha':integrated,'merged_at':date}}
    now=datetime(2026,11,9,tzinfo=timezone.utc)
    check('verified expired historical source',data,deleted=[original])
    check('protected active branch file cannot expire',data,False,[original],[original])
    check('future retirement timestamp rejected',data,False,mutate=lambda d:d['batches'][0].update(retired_at='2026-11-20T12:00:00Z'))
    check('expiry must be exactly 168 hours',data,False,mutate=lambda d:d['batches'][0].update(expires_at='2026-11-07T12:00:00Z'))
    check('nonintegration commit rejected',data,False,mutate=lambda d:d['batches'][0].update(retirement_commit=source))
    check('unknown recovery source rejected',data,False,mutate=lambda d:d['batches'][0].update(source_commit='0'*40))
    check('commit timestamps alone cannot prove integration',data,False,proof_override={},contains='GitHub dev integration')
    check('changed recovery receipt rejected',data,False,previous=data,mutate=lambda d:d['batches'][0]['entries'][0].update(reason='rewritten'))
    before=now;now=datetime(2026,11,3,tzinfo=timezone.utc)
    check('premature deletion rejected',data,False,[original]);check('future expiry valid during recovery',data)
    now=before
    (root/'reader.py').write_text('open("docs/archive/old.md")\n');git('add','reader.py')
    check('tool reader blocks deletion',data,False,[original]);git('reset','--','reader.py');(root/'reader.py').unlink()
    (root/'docs/tools').mkdir();reader=root/'docs/tools/reader.py';reader.write_text('open("docs/archive/old.md")\n');git('add','docs/tools/reader.py')
    check('executable reader inside docs also blocks expiry',data,False,[original],contains='still referenced')
    git('reset','--','docs/tools/reader.py');reader.unlink()
    (root/original).write_text('Changed content.\n');check('changed retired blob rejected',data,False);(root/original).write_text('Historical result.\n')
    check('license source cannot be scheduled here',data,False,mutate=lambda d:d['batches'][0]['entries'][0].update(original='docs/archive/LICENSE.md'))
    check('path traversal rejected',data,False,mutate=lambda d:d['batches'][0]['entries'][0].update(retired='../old.md'))
    check('missing preservation target rejected',data,False,mutate=lambda d:d['batches'][0]['entries'][0].update(target='docs/missing.md'))
    pending=copy.deepcopy(data);pending['batches'][0].update(retirement_commit=None,retired_at=None,expires_at=None,retirement_pr=None)
    check('pending batch cannot authorize deletion',pending,False,[original])
    moved=copy.deepcopy(pending);moved['batches'][0]['entries'][0].update(original='docs/live.md',retired='docs/archive/live.md')
    (root/'docs/live.md').unlink();(root/'docs/archive/live.md').write_text('Historical result.\n')
    check('initial pending move protects original branch work',moved,False,['docs/live.md'],['docs/live.md'],contains='active branch')
    reader.write_text('open("docs/live.md")\n');git('add','docs/tools/reader.py')
    check('initial pending move protects source readers',moved,False,['docs/live.md'],contains='still referenced')
    git('reset','--','docs/tools/reader.py');reader.unlink()
    (root/'docs/live.md').write_text('Historical result.\n');(root/'docs/archive/live.md').unlink()
    git('checkout','-b','feature/work')
    (root/'src').mkdir();(root/'src/reader.py').write_text('open("docs/live.md")\n# [contract](../docs/live.md)\n')
    git('add','src/reader.py');git('commit','-m','active task');active_sha=git('rev-parse','HEAD')
    git('update-ref','refs/remotes/origin/feature/work',active_sha)
    saved_api=dr.api; saved_env=dict(os.environ)
    def fake_api(path):
        if 'state=closed' in path:return []
        if path.startswith('pulls?'):return [{'number':44,'head':{'sha':active_sha,'ref':'feature/work'}}]
        return [{'filename':'src/reader.py'}]
    try:
        dr.api=fake_api;os.environ['GH_TOKEN']='fixture-not-a-real-token';os.environ.pop('GITHUB_EVENT_PATH',None)
        active=dr.active_work(root)
        assert 'src/reader.py' in active and 'docs/live.md' in active,active
        print('PASS: live work protects changed paths and relative document contracts')
        (root/'src/reader.py').write_text('open("docs/live.md")\n');git('add','src/reader.py');git('commit','-m','string reader only')
        active_sha=git('rev-parse','HEAD');git('update-ref','refs/remotes/origin/feature/work',active_sha)
        assert 'docs/live.md' in dr.active_work(root)
        print('PASS: branch-only executable string reader protects its document')
        event=root/'event.json';event.write_text(json.dumps({'pull_request':{'number':44,'head':{'ref':'feature/work'}}}))
        os.environ['GITHUB_EVENT_PATH']=str(event)
        assert not dr.active_work(root),'own PR/branch must not self-lock'
        print('PASS: own cleanup PR and its exact branch do not self-lock')
        closed_sha=active_sha
        event.write_text('{}')
        def closed_api(path):
            if 'state=closed' in path:return [{'head':{'sha':closed_sha,'ref':'feature/work'}}]
            return []
        dr.api=closed_api
        assert not dr.active_work(root)
        print('PASS: closed unchanged planning head is no longer active work')
        (root/'src/reader.py').write_text('open("docs/live.md")\n# resumed work\n');git('add','src/reader.py');git('commit','-m','resume after closure')
        git('update-ref','refs/remotes/origin/feature/work',git('rev-parse','HEAD'))
        assert 'docs/live.md' in dr.active_work(root)
        print('PASS: new commits after closure restore branch and contract protection')
        os.environ.pop('GH_TOKEN',None);os.environ.pop('GITHUB_TOKEN',None)
        try:dr.active_work(root)
        except ValueError:print('PASS: unavailable live work inventory fails closed')
        else:raise AssertionError('missing live token was accepted')
    finally:
        dr.api=saved_api;os.environ.clear();os.environ.update(saved_env)
    git('checkout','dev');git('update-ref','-d','refs/remotes/origin/feature/work')
    (root/original).unlink();check('expired deletion validated after file removal',data,deleted=[original])
    (root/original).write_text('Historical result.\n')
    (root/'tools').mkdir();(root/'tools/reader.py').write_text('open("docs/archive/old.md")\n')
    git('add','tools/reader.py');git('commit','-m','tracked reader outside sparse cone')
    git('sparse-checkout','init','--cone');git('sparse-checkout','set','docs')
    assert not (root/'tools/reader.py').exists()
    check('sparse checkout cannot hide a tracked executable reader',data,False,[original],contains='still referenced')
print('Document retirement regression checks passed; no live network or project files modified.')
