#!/usr/bin/env python3
"""Static package checks. Useful before installation, not a live Claude or Godot test."""
# Installed 11 Nov 2026: package-only files (README_FIRST, audit log, cowork/) live under docs/ai-team/package/.
from pathlib import Path
import re, sys

root = Path(__file__).resolve().parent.parent
required = [
    'docs/ai-team/package/README_FIRST.md', 'docs/ai-team/package/REVISION_AND_AUDIT_LOG.md', 'CLAUDE.md',
    'docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt', 'docs/ai-team/package/cowork/COORDINATOR_BOOTSTRAP.md',
    'docs/ai-team/CONSTITUTION.md', 'docs/ai-team/DECISION_AUTHORITY.md',
    'docs/ai-team/DOCUMENT_AUTHORITY.md', 'docs/ai-team/WORKFLOW.md',
    'docs/ai-team/TEST_GATES.md', 'docs/ai-team/ROLE_CATALOG.md',
    'docs/ai-team/SESSION_LIFECYCLE.md', 'docs/ai-team/KNOWN_CONFLICTS.md',
    'docs/ai-team/MIGRATION_PLAN.md', 'docs/ai-team/EVALUATION_CASES.md',
    'docs/ai-team/TASK_BRIEF_TEMPLATE.md', 'docs/ai-team/HANDOFF_TEMPLATE.md',
    'docs/ai-team/COORDINATOR_STATE_TEMPLATE.md',
    'docs/ai-team/SOURCES_AND_ASSUMPTIONS.md',
]
errors=[]
for rel in required:
    if not (root/rel).is_file(): errors.append(f'MISSING: {rel}')
agent_files = sorted((root/'.claude/agents').glob('*.md'))
skill_files = sorted((root/'.claude/skills').glob('*/SKILL.md'))
if len(agent_files) != 8: errors.append(f'EXPECTED 8 agent definitions, got {len(agent_files)}')
if len(skill_files) != 7: errors.append(f'EXPECTED 7 skill definitions, got {len(skill_files)}')

def frontmatter(path):
    raw=path.read_text(encoding='utf-8')
    m=re.match(r'\A---\n(.*?)\n---\n',raw,re.S)
    if not m:
        errors.append(f'MISSING/BROKEN FRONTMATTER: {path.relative_to(root)}'); return {}
    vals={}
    for line in m.group(1).splitlines():
        if ':' in line:
            k,v=line.split(':',1)
            vals[k.strip()]=v.strip()
    return vals

for path in agent_files+skill_files:
    data=frontmatter(path)
    for key in ('name','description'):
        if not data.get(key): errors.append(f'MISSING {key}: {path.relative_to(root)}')
    if path.name=='SKILL.md' and data.get('name')!=path.parent.name:
        errors.append(f'SKILL NAME/DIR MISMATCH: {path}')
    if path.name!='SKILL.md':
        if data.get('model') not in {'sonnet','opus','haiku','fable','inherit'}:
            errors.append(f'UNKNOWN MODEL ALIAS: {path}')
        if data.get('effort') not in {'low','medium','high','xhigh','max'}:
            errors.append(f'UNKNOWN EFFORT: {path}')
for name in ('gate-reviewer','art-reviewer'):
    p=root/f'.claude/agents/{name}.md'; d=frontmatter(p)
    allowed=set(v.strip() for v in d.get('tools','').split(','))
    if allowed!={'Read','Grep','Glob'}: errors.append(f'REVIEWER MUST BE READ ONLY: {name}')

for path in (root/'docs/ai-team').glob('*.md'):
    s=path.read_text(encoding='utf-8')
    if 'Status:' not in s and path.name not in {'SOURCES_AND_ASSUMPTIONS.md','EVALUATION_CASES.md'}:
        errors.append(f'NO STATUS: {path.name}')

policy = '\n'.join(p.read_text(encoding='utf-8') for p in (root/'docs/ai-team').glob('*.md'))
for term in ('dev', 'main', 'PROPOSED', 'SOURCE UNVERIFIED', 'handoff freeze',
             'SYNC PENDING', 'NOT RUN', 'water record', 'Foundation', 'Ceiling'):
    if term.lower() not in policy.lower(): errors.append(f'MISSING POLICY TERM: {term}')

# Key behavior is routed in all entry points; these assertions are not agent evaluations.
entrypoints = {
    'CLAUDE.md': ('docs/START_HERE.md','CONSTITUTION.md','freeze'),
    'docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt': ('START_HERE.md','freeze','Coordinator'),
    'docs/ai-team/package/cowork/COORDINATOR_BOOTSTRAP.md': ('MIGRATION_PLAN.md','KNOWN_CONFLICTS.md','freeze'),
}
for rel,terms in entrypoints.items():
    s=(root/rel).read_text(encoding='utf-8').lower()
    for term in terms:
        if term.lower() not in s: errors.append(f'MISSING ENTRYPOINT POINTER {term}: {rel}')

# Tests are not allowed to silently become claims about what ran.
for rel in ('docs/ai-team/TEST_GATES.md','docs/ai-team/WORKFLOW.md',
            '.claude/skills/nightly-dev-checkpoint/SKILL.md'):
    s=(root/rel).read_text(encoding='utf-8').lower()
    if 'sha' not in s: errors.append(f'NO EXACT SHA CONCEPT: {rel}')
for rel in ('CLAUDE.md', 'docs/ai-team/WORKFLOW.md','docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt',
            'docs/START_HERE.md', 'RULES.md'):  # repo entry points reconciled at install
    s=(root/rel).read_text(encoding='utf-8').lower()
    if 'there is no daily branch' in s or 'dailydev_yyyy' in s:
        errors.append(f'SUPERSEDED OLD RULE IN ACTIVE ENTRY: {rel}')
if 'ff650afb' not in (root/'docs/ai-team/package/README_FIRST.md').read_text(encoding='utf-8'):
    errors.append('MISSING VERIFIED FINAL HANDOFF SHA IN README')

if errors:
    print(f'FAIL: {len(errors)} package consistency findings')
    for e in errors: print(' -',e)
    sys.exit(1)
print(f'PASS: {len(required)} core files, {len(agent_files)} Claude Code agents, {len(skill_files)} skills')
print('PASS: frontmatter, known instruction collisions, authority markers, guardrail references')
print('LIMIT: static checks only; no Cowork, GitHub write, PC, Godot or live Claude evaluation.')
