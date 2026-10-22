#!/bin/bash
# GDScript warning counter (Dave's rule: new code makes zero warnings, so the log holds only real problems).
#
#   tools/check_warnings.sh              warnings per file, all scripts (about 1 minute)
#   tools/check_warnings.sh --changed    only files changed against origin/claude/generator-v2 (and uncommitted):
#                                        prints their warnings and exits 1 if there are any. Run before every push.
#   tools/check_warnings.sh --detail F   every warning of file F (path from the project root, e.g. src/client/hud.gd)
#
# Needs the project's Godot on the PATH (godot). It loads every script with --debug, because headless Godot only
# reports warnings in debug mode, and counts what the engine says.
cd "$(dirname "$0")/.." || exit 2
OUT=$(mktemp)
timeout 600 godot --headless --debug --path . --script res://tools/check_warnings.gd 2>&1 | grep "^WARN \|^scripts checked" | sed 's/^WARN //' | sort -u > "$OUT"
grep "^scripts checked" "$OUT" | tail -1

case "$1" in
	--changed)
		git fetch -q origin claude/generator-v2 2>/dev/null
		CHANGED=$( (git diff --name-only origin/claude/generator-v2...HEAD; git diff --name-only HEAD) | sort -u | grep '\.gd$')
		BAD=0
		for f in $CHANGED; do
			N=$(grep -c "^$f:" "$OUT")
			if [ "$N" -gt 0 ]; then
				grep "^$f:" "$OUT"
				BAD=$((BAD + N))
			fi
		done
		echo "warnings in changed files: $BAD"
		rm -f "$OUT"
		[ "$BAD" -eq 0 ]
		exit $?
		;;
	--detail)
		grep "^$2:" "$OUT"
		;;
	*)
		grep -v "^scripts checked" "$OUT" | cut -d: -f1 | sort | uniq -c | sort -rn
		;;
esac
rm -f "$OUT"
