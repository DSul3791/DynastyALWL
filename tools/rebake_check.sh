#!/bin/bash
# Run after the tiles are re-baked (Tyler, 31 Oct 2026): runs the four tests that read the baked tile 3,4 and say what to do with each.
#   tools/rebake_check.sh [--jobs N]
# Decisions (TYLER_TEST_SYSTEM_REVIEW.md, 31 Oct): drainage_fill and river_surface are RE-PINNED when red (the test stays, its numbers are refreshed with a
# recorded reason); head_pond_fill and drainage_flow are ARCHIVED when natural rivers are on (move to proposed_removals/ with a row in REMOVALS.md).
# Prints PASS or RED per test and the action; with --mark it also writes the red ones into tools/known_red.txt so merge_day.sh does not count them as new.
cd "$(dirname "$0")/.." || exit 2
export PATH="$PWD/tools:$PATH"
JOBS=3; MARK=0
while [ $# -gt 0 ]; do case "$1" in --jobs) JOBS="$2"; shift 2;; --mark) MARK=1; shift;; *) shift;; esac; done
OUT=$(mktemp -d)
bash tools/run_tests.sh --jobs "$JOBS" --out "$OUT" --slow test_drainage_fill test_river_surface test_drainage_flow test_head_pond_fill > "$OUT/summary.txt" 2>&1
declare -A ACTION=( [test_drainage_fill]="re-pin its numbers on the new tile" [test_river_surface]="re-pin the cross-section limit with a recorded reason" [test_drainage_flow]="archive (natural rivers replace the channels)" [test_head_pond_fill]="archive (natural rivers have no head ponds)" )
for t in test_drainage_fill test_river_surface test_drainage_flow test_head_pond_fill; do
	R=$(cat "$OUT/$t.result" 2>/dev/null || echo "FAIL no result")
	if [ "${R%% *}" = PASS ]; then echo "PASS  $t   ($R)"
	else echo "RED   $t   ($R)  -> ${ACTION[$t]}"; [ $MARK = 1 ] && echo "$t red after the re-bake: ${ACTION[$t]}" >> tools/known_red.txt; fi
done
echo "logs in $OUT"
