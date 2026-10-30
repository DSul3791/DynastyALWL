#!/bin/bash
# The full test set, slow lane included (Tyler, 30 Oct 2026). Per commit only the tests a diff touches run; this is the safeguard:
# every test once a day and before anything goes to main (ship.sh calls it unless SKIP_SLOW=1).
#   tools/nightly_slow.sh [--jobs N]        about 7 min on Dave's PC with 6 jobs
# Output: tests in $NIGHTLY_OUT (default a new temp folder), one summary line appended to $NIGHTLY_LOG
# (default ~/.local/state/dynasty/nightly.log). Exit 0 = no failure (a known PC failure is reported, not counted), 1 = failure.
# Schedule on Windows (Task Scheduler, daily 03:30):  schtasks /create /tn DynastyNightly /sc daily /st 03:30 /tr "\"C:\Program Files\Git\bin\bash.exe\" -lc 'cd /c/GodotProjects/DynastyALWL && tools/nightly_slow.sh'"
cd "$(dirname "$0")/.." || exit 2
export PATH="$PWD/tools:$PATH"
PY="${PYTHON:-$(command -v python3 || command -v python)}"
JOBS="${GATE_JOBS:-6}"; [ "$1" = "--jobs" ] && JOBS="$2"
LOG="${NIGHTLY_LOG:-$HOME/.local/state/dynasty/nightly.log}"; mkdir -p "$(dirname "$LOG")"
OUT="${NIGHTLY_OUT:-$(mktemp -d)}"; mkdir -p "$OUT"
"$PY" tools/tests_for_diff.py --paths project.godot --full > "$OUT/plan.json" || exit 2
START=$(date +%s)
bash tools/run_tests.sh --jobs "$JOBS" --plan "$OUT/plan.json" --out "$OUT/tests" | tee "$OUT/summary.txt" | tail -25
RC=${PIPESTATUS[0]}
echo "$(date -u +%Y-%m-%dT%H:%MZ) $(git rev-parse --short HEAD) $(grep '^Test done' "$OUT/summary.txt") wall $(( $(date +%s) - START )) s rc=$RC" >> "$LOG"
echo "logged to $LOG"
exit $RC
