#!/bin/bash
# One test in its own data dir and log (used by run_tests.sh and flake_finder.sh).
#   tools/run_one_test.sh <test name without .gd> <timeout seconds> <out dir>
# Writes <out>/<name>.out (stdout and stderr), <out>/<name>.godot.log, <out>/<name>.result = "PASS|FAIL <seconds> <exit code> <why>".
# Each run gets a fresh XDG_DATA_HOME / APPDATA so user:// folders never collide with another job. GODOT_EXE and PYTHON come from the environment.
NAME="$1"; LIMIT="${2:-300}"; OUT="$3"
[ -z "$NAME" ] || [ -z "$OUT" ] && { echo "usage: run_one_test.sh <test> <timeout s> <out dir>"; exit 2; }
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT_EXE:-godot}"
JOB=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/rt_$$_$RANDOM")
mkdir -p "$JOB/data" "$JOB/appdata" "$OUT"
export XDG_DATA_HOME="$JOB/data" APPDATA="$JOB/appdata"
START=$(date +%s%N); case "$START" in *N*) START=$(( $(date +%s) * 1000000000 ));; esac
timeout "$LIMIT" "$GODOT" --headless --path . --log-file "$OUT/$NAME.godot.log" --script "res://src/worldgen/tools/$NAME.gd" > "$OUT/$NAME.out" 2>&1
RC=$?
END=$(date +%s%N); case "$END" in *N*) END=$(( $(date +%s) * 1000000000 ));; esac
SECS=$(awk "BEGIN{printf \"%.1f\", ($END - $START) / 1000000000}")
WHY=""
if [ $RC -eq 124 ]; then WHY="timed out after ${LIMIT}s"
elif [ $RC -ne 0 ]; then WHY="exit code $RC"
elif grep -qE "SCRIPT ERROR|Parse Error|^FAIL " "$OUT/$NAME.out"; then WHY="error text in output"; RC=1
fi
if [ $RC -eq 0 ]; then echo "PASS $SECS $RC ok" > "$OUT/$NAME.result"; else echo "FAIL $SECS $RC $WHY" > "$OUT/$NAME.result"; fi
rm -rf "$JOB"
exit $RC
