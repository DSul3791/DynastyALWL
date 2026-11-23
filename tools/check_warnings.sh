#!/bin/bash
# GDScript warning counter (Dave's rule: new code makes zero warnings, so the log holds only real problems).
#
#   tools/check_warnings.sh              warnings per file, all scripts (about 1 minute), against tools/warning_baseline.txt: exits 4 and
#                                        names each file over its baseline count; says so when files are below it (lower the baseline)
#   tools/check_warnings.sh --counts     the same counts with no baseline comparison (run_tests.sh and local_check.sh compare themselves)
#   tools/check_warnings.sh --update-baseline   rewrite tools/warning_baseline.txt from the current counts (after warnings were cleared)
#   tools/check_warnings.sh --changed    only files changed against origin/main (and uncommitted):
#                                        prints their warnings and exits 1 if there are any. Run before every push.
#   tools/check_warnings.sh --detail F   every warning of file F (path from the project root, e.g. src/client/hud.gd)
#   tools/check_warnings.sh --self-check checks only a script that warns and one that does not parse (tools/test_check_warnings.sh)
#
# Needs the project's Godot on the PATH (godot). It loads every script with --debug, because headless Godot only
# reports warnings in debug mode, and counts what the engine says. --ignore-error-breaks keeps a parse error from
# stopping the run at the local debugger's "debug>" prompt (Godot 4.7: GDScript::reload breaks there on a parse error).
#
# Exit codes: 0 checked, no file over the baseline; 1 warnings in changed files (--changed); 2 the check did not finish (no godot, timed out,
# or no "scripts checked" line), so nothing it printed can be trusted; 3 a script does not parse (named on stderr); 4 new warnings: a file
# has more than its count in the baseline (coordinator 23 Nov 2026: exit 0 used to mean only "finished", and four threads read it as clean).
# CHECK_WARNINGS_TIMEOUT sets the time limit in seconds (default 600); WARNING_BASELINE another baseline file (tools/test_check_warnings.sh).
cd "$(dirname "$0")/.." || exit 2
BASE=${WARNING_BASELINE:-tools/warning_baseline.txt}
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
	--self-check|--counts)
		cut -d: -f1 "$OUT" | sort | uniq -c | sort -rn
		;;
	--update-baseline)
		if grep -q "^PARSE FAIL \|^parse failures: " "$RAW"; then
			echo "check_warnings: baseline NOT written, a script does not parse" >&2
		else
			cut -d: -f1 "$OUT" | sort | uniq -c | sort -rn > "$BASE"
			echo "baseline written to $BASE: $(awk '{s+=$1} END{print s+0}' "$BASE") warnings in $(wc -l < "$BASE") files"
		fi
		;;
	*)
		COUNTS=$(cut -d: -f1 "$OUT" | sort | uniq -c | sort -rn)
		echo "$COUNTS" | grep -v '^$'

		if [ ! -s "$BASE" ]; then
			echo "check_warnings: FAIL, the baseline $BASE is missing or empty, so new warnings cannot be told apart" >&2
			STATUS=4
		else
			NOW_TOTAL=$(echo "$COUNTS" | awk '{s+=$1} END{print s+0}')
			BASE_TOTAL=$(awk '{s+=$1} END{print s+0}' "$BASE")
			OVER=$(echo "$COUNTS" | awk 'NR==FNR{b[$2]=$1; next} NF==2 && $1 > b[$2]+0 {printf "  %s: %d now, %d in the baseline\n", $2, $1, b[$2]+0}' "$BASE" -)
			UNDER=$(echo "$COUNTS" | awk 'NR==FNR && NF==2 {n[$2]=$1; next} $1 > n[$2]+0 {c++} END{print c+0}' - "$BASE")

			if [ -n "$OVER" ]; then
				echo "check_warnings: FAIL, new warnings ($NOW_TOTAL now, $BASE_TOTAL in the baseline); files over their baseline count:" >&2
				echo "$OVER" >&2
				echo "  see each with: tools/check_warnings.sh --detail <file>" >&2
				STATUS=4
			else
				echo "no new warnings: $NOW_TOTAL now, $BASE_TOTAL in the baseline"
			fi

			if [ "$UNDER" -gt 0 ]; then
				echo "check_warnings: $UNDER files are below their baseline count: lower the baseline with tools/check_warnings.sh --update-baseline and commit it"
			fi
		fi
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
