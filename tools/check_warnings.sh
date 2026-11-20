#!/bin/bash
# GDScript warning counter (Dave's rule: new code makes zero warnings, so the log holds only real problems).
#
#   tools/check_warnings.sh              warnings per file, all scripts (about 1 minute)
#   tools/check_warnings.sh --changed    only files changed against origin/main (and uncommitted):
#                                        prints their warnings and exits 1 if there are any. Run before every push.
#   tools/check_warnings.sh --detail F   every warning of file F (path from the project root, e.g. src/client/hud.gd)
#   tools/check_warnings.sh --self-check checks only a script that warns and one that does not parse (tools/test_check_warnings.sh)
#
# Needs the project's Godot on the PATH (godot). It loads every script with --debug, because headless Godot only
# reports warnings in debug mode, and counts what the engine says. --ignore-error-breaks keeps a parse error from
# stopping the run at the local debugger's "debug>" prompt (Godot 4.7: GDScript::reload breaks there on a parse error).
#
# Exit codes: 0 checked; 1 warnings in changed files (--changed); 2 the check did not finish (no godot, timed out,
# or no "scripts checked" line), so nothing it printed can be trusted; 3 a script does not parse (named on stderr).
# CHECK_WARNINGS_TIMEOUT sets the time limit in seconds (default 600).
cd "$(dirname "$0")/.." || exit 2
command -v godot >/dev/null || { echo "check_warnings: godot is not on the PATH, nothing was checked" >&2; exit 2; }
LIMIT=${CHECK_WARNINGS_TIMEOUT:-600}
RAW=$(mktemp)
OUT=$(mktemp)
trap 'rm -f "$RAW" "$OUT"' EXIT
USER_ARGS=()
[ "$1" = "--self-check" ] && USER_ARGS=(-- --self-check)
timeout "$LIMIT" godot --headless --debug --ignore-error-breaks --path . --script res://tools/check_warnings.gd "${USER_ARGS[@]}" > "$RAW" 2>&1
RC=$?
SUMMARY=$(grep "^scripts checked" "$RAW" | tail -1)

if [ "$RC" -eq 124 ] || [ -z "$SUMMARY" ]; then
	if [ "$RC" -eq 124 ]; then
		echo "check_warnings: FAIL, godot did not finish within $LIMIT s; nothing was checked. Last output:" >&2
	else
		echo "check_warnings: FAIL, no 'scripts checked' line (godot exit $RC); nothing was checked. Last output:" >&2
	fi
	grep -v '^WARN ' "$RAW" | tail -15 | sed 's/^/  /' >&2
	exit 2
fi

grep "^WARN " "$RAW" | sed 's/^WARN //' | sort -u > "$OUT"
echo "$SUMMARY"
STATUS=0

case "$1" in
	--changed)
		git fetch -q origin main 2>/dev/null
		CHANGED=$( (git diff --name-only origin/main...HEAD; git diff --name-only HEAD) | sort -u | grep '\.gd$')
		BAD=0
		for f in $CHANGED; do
			N=$(grep -c "^$f:" "$OUT")
			if [ "$N" -gt 0 ]; then
				grep "^$f:" "$OUT"
				BAD=$((BAD + N))
			fi
		done
		echo "warnings in changed files: $BAD"
		[ "$BAD" -eq 0 ] || STATUS=1
		;;
	--detail)
		grep "^$2:" "$OUT"
		;;
	*)
		cut -d: -f1 "$OUT" | sort | uniq -c | sort -rn
		;;
esac

# A script that does not parse fails the check whatever the mode (its warnings were never counted).
PARSE=$(grep "^PARSE FAIL " "$RAW" | sed 's/^PARSE FAIL //' | sort -u)
grep -q "^parse failures: " "$RAW" && [ -z "$PARSE" ] && PARSE="(the run counted parse failures but named none)"

if [ -n "$PARSE" ]; then
	echo "$PARSE" | sed 's/^/check_warnings: FAIL, script does not parse: /' >&2
	grep -E "(Parse|Compile) Error" "$RAW" | sort -u | head -10 | sed 's/^/  /' >&2
	STATUS=3
fi

exit $STATUS
