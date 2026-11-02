#!/bin/bash
# Hourly merge watch (Tyler, 31 Oct 2026): tools/merge_watch_loop.sh [minutes between rounds, default 60] [max rounds, default 8]
# Runs tools/merge_watch.sh every N minutes and EXITS as soon as a round reports NEW (a changed conflict list or red tests), printing it, so whoever started it in
# the background is told. Exits quietly after the last round.
cd "$(dirname "$0")/.." || exit 2
GAP="${1:-60}"; ROUNDS="${2:-8}"
for n in $(seq 1 "$ROUNDS"); do
	sleep $(( GAP * 60 ))
	OUT=$(MW_OUT=$(mktemp -d) bash tools/merge_watch.sh 2>&1)
	echo "round $n: $(echo "$OUT" | head -1)"
	case "$OUT" in NEW*) echo "$OUT"; exit 0;; esac
done
