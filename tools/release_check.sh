#!/bin/bash
# Every test, the big ones included (Tyler, 30 Oct 2026). Run it BY HAND before a release or after a big change to the world or water code; there is no
# schedule. Per commit the small fast tests run instead (tools/tests_for_diff.py + run_tests.sh); the big tests on the real baked tiles run per commit only
# when baked tiles, water data or plan files change.
#   tools/release_check.sh [--jobs N]        about 7 min on Dave's PC with 6 jobs
# Output: tests in $RELEASE_OUT (default a new temp folder), one summary line appended to $RELEASE_LOG
# (default ~/.local/state/dynasty/release_check.log). Exit 0 = no failure (a known PC failure is reported, not counted), 1 = failure.
cd "$(dirname "$0")/.." || exit 2
export PATH="$PWD/tools:$PATH"
PY="${PYTHON:-$(command -v python3 || command -v python)}"
JOBS="${GATE_JOBS:-6}"; [ "$1" = "--jobs" ] && JOBS="$2"
LOG="${RELEASE_LOG:-$HOME/.local/state/dynasty/release_check.log}"; mkdir -p "$(dirname "$LOG")"
OUT="${RELEASE_OUT:-$(mktemp -d)}"; mkdir -p "$OUT"
"$PY" tools/tests_for_diff.py --paths project.godot --full > "$OUT/plan.json" || exit 2
START=$(date +%s)
bash tools/run_tests.sh --jobs "$JOBS" --plan "$OUT/plan.json" --out "$OUT/tests" | tee "$OUT/summary.txt" | tail -25
RC=${PIPESTATUS[0]}
echo "$(date -u +%Y-%m-%dT%H:%MZ) $(git rev-parse --short HEAD) $(grep '^Test done' "$OUT/summary.txt") wall $(( $(date +%s) - START )) s rc=$RC" >> "$LOG"
echo "logged to $LOG"
exit $RC
