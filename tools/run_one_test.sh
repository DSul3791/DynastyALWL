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
# A script that fails to compile leaves Godot idle (no quit()), so a broken test used to run to the full limit (25 min for slow tests).
# Watch the output and stop it at once; the result says why.
# Extra arguments for one test (tools/test_args.txt: "<test> <args>"): test_npc_view must run with --old-body, or the generated bodies it starts on worker
# threads keep Godot from exiting for 5 minutes or more on a fresh data folder (31 Oct 2026).
XARGS=$(grep -E "^$NAME " "$(dirname "$0")/test_args.txt" 2>/dev/null | head -1 | cut -d' ' -f2- | tr -d '')
[ -n "$XARGS" ] && XARGS="-- $XARGS"
# Wait for a free Godot slot (at most 3 heavy jobs at once on the whole PC, tools/godot_slot.sh; GODOT_SLOTS=0 switches it off). The time waiting is not counted.
. "$(dirname "$0")/godot_slot.sh"; slot_acquire; trap slot_release EXIT
START=$(date +%s%N); case "$START" in *N*) START=$(( $(date +%s) * 1000000000 ));; esac
timeout "$LIMIT" "$GODOT" --headless --path . --log-file "$OUT/$NAME.godot.log" --script "res://src/worldgen/tools/$NAME.gd" $XARGS > "$OUT/$NAME.out" 2>&1 &
GP=$!; DEAD=""
while kill -0 $GP 2>/dev/null; do
	sleep 0.5
	if grep -qE "Failed to load script|SCRIPT ERROR: (Compile|Parse) Error" "$OUT/$NAME.out" 2>/dev/null; then sleep 1; kill $GP 2>/dev/null; sleep 1; kill -9 $GP 2>/dev/null; DEAD=1; break; fi
done
wait $GP 2>/dev/null; RC=$?
[ -n "$DEAD" ] && RC=3
END=$(date +%s%N); case "$END" in *N*) END=$(( $(date +%s) * 1000000000 ));; esac
SECS=$(awk "BEGIN{printf \"%.1f\", ($END - $START) / 1000000000}")
WHY=""
if [ -n "$DEAD" ]; then WHY="script does not compile (stopped early)"
elif [ $RC -eq 124 ]; then WHY="timed out after ${LIMIT}s"
elif [ $RC -ne 0 ]; then WHY="exit code $RC"
elif grep -qE "SCRIPT ERROR|Parse Error|^FAIL " "$OUT/$NAME.out"; then WHY="error text in output"; RC=1
fi
if [ $RC -eq 0 ]; then echo "PASS $SECS $RC ok" > "$OUT/$NAME.result"; else echo "FAIL $SECS $RC $WHY" > "$OUT/$NAME.result"; fi
rm -rf "$JOB"
exit $RC
