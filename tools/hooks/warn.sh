#!/bin/bash
# Claude Code hook (.claude/settings.json): warn-only checks before a git commit or push. Never blocks: always exits 0,
# and prints nothing when all is well (Dave 25 Nov 2026, team audit step 4).
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
for py in python3 python py; do
	if "$py" -c 1 >/dev/null 2>&1; then   # a real Python, not the Windows Store stub
		"$py" -I tools/hooks/agent_warn.py "$1" 2>/dev/null
		exit 0
	fi
done
exit 0
