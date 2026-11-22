#!/usr/bin/env python3
"""Exercise migration failures against an isolated package; never edit the checkout."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
patterns = (
    'CLAUDE.md', 'README.md', 'RULES.md', 'docs/START_HERE.md', 'docs/DOC_MAP.md',
    'docs/PONYTAIL_RULES.md', 'docs/ai-team/*.md', '.claude/settings.json',
    '.claude/agents/*.md', '.claude/skills/*/SKILL.md',
    'docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt',
    'docs/ai-team/package/cowork/COORDINATOR_BOOTSTRAP.md',
    'docs/ai-team/package/cowork/skill_uploads/*.zip', 'tools/check_ai_team_package.py',
)

with tempfile.TemporaryDirectory(prefix='ai-package-test-') as folder:
    fixture = Path(folder)
    for pattern in patterns:
        for source in root.glob(pattern):
            target = fixture / source.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)

    def check(label, expected, finding=''):
        result = subprocess.run([sys.executable, '-I', str(fixture/'tools/check_ai_team_package.py')],
                                text=True, capture_output=True)
        assert (result.returncode == 0) == expected, (label, result.stdout, result.stderr)
        assert finding in result.stdout, (label, result.stdout)
        assert 'Traceback' not in result.stderr, (label, result.stderr)
        print('PASS:', label)

    def changed(rel, transform, label, finding):
        path = fixture/rel
        before = path.read_bytes()
        try:
            path.write_text(transform(before.decode()))
            check(label, False, finding)
        finally:
            path.write_bytes(before)

    check('current four-rulebook package', True)
    changed('CLAUDE.md', lambda s:s+'\nRead DECISION_AUTHORITY.md.\n',
            'retired authority cannot return to active routing', 'RETIRED RULEBOOK IN ACTIVE ROUTING')
    changed('.claude/agents/doc-steward.md', lambda s:s+'\nRead RULES.md.\n',
            'worker cannot route to legacy rules', 'RETIRED RULEBOOK IN ACTIVE ROUTING')
    # Future expiry may legitimately remove this path from the real checkout.
    legacy = fixture/'RULES.md'
    if not legacy.exists():
        legacy.write_text('**Status: RETIRED AS AUTHORITY.**\n')
    changed('RULES.md', lambda s:s.replace('RETIRED AS AUTHORITY', 'IN FORCE'),
            'legacy rulebook cannot revive', 'RETIRED RULEBOOK REVIVED')
    changed('.claude/agents/gate-reviewer.md', lambda s:s.replace('Read, Grep, Glob', 'Read, Grep, Glob, Edit'),
            'reviewer remains read-only', 'REVIEWER MUST BE READ ONLY')
    changed('.claude/skills/ponytail-review/SKILL.md', lambda s:s+'\nChanged without upload mirror.\n',
            'stale upload mirror still fails', 'COWORK SKILL ZIP MISSING OR STALE')
    missing = fixture/'docs/ai-team/WORKFLOW.md'
    before = missing.read_bytes()
    missing.unlink()
    check('missing primary authority fails clearly', False, 'MISSING: docs/ai-team/WORKFLOW.md')
    missing.write_bytes(before)
    # Redirect removal must not require keeping a duplicate authority forever.
    for rel in ('RULES.md','docs/START_HERE.md',*(f'docs/ai-team/{n}.md' for n in
                ('DECISION_AUTHORITY','DOCUMENT_AUTHORITY','ROLE_CATALOG','SESSION_LIFECYCLE'))):
        (fixture/rel).unlink(missing_ok=True)
    check('package does not require expired redirects', True)
