#!/bin/bash
# Settle a list of baked tiles, --jobs at a time (default 9, Dave's rule for water work on his PC), one Godot process per tile: a queue, not
# rounds, so a worker takes the next tile as soon as it is done (docs/design/settle_speed_design.md cut 1). Tiles start in the order given:
# put the wettest first (on the starter block 3,4, by far the slowest, 9 Nov 2026) so the long one starts at once and the rest fill the other
# workers. The settle saves the film too (data/water_settle.json film v13), so no refilm follows. One log per tile in --out; prints each tile's
# "settle done" and "film floor" lines with its seconds, then the wall time. Close Dave's game first. Exits 1 if any tile failed.
#   tools/settle_tiles.sh --tiles="3,4 4,5 3,5 3,3 4,3 2,3 4,4 2,4 2,5" [--world=res://worlds/base_world] [--jobs=9] [--out=DIR]
cd "$(dirname "$0")/.." || exit 2
TILES=""; WORLD="res://worlds/base_world"; JOBS=9; OUT=""
for A in "$@"; do
	case "$A" in
		--tiles=*) TILES="${A#--tiles=}";;
		--world=*) WORLD="${A#--world=}";;
		--jobs=*) JOBS="${A#--jobs=}";;
		--out=*) OUT="${A#--out=}";;
		*) echo "unknown argument $A"; exit 2;;
	esac
done
[ -n "$TILES" ] || { echo "settle_tiles: give --tiles=\"X,Z X,Z ...\""; exit 2; }
OUT="${OUT:-settle_logs_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"
export WORLD OUT
START=$(date +%s)
echo "settle_tiles: $(echo $TILES | wc -w) tiles, $JOBS at a time, started $(date +%H:%M:%S)"
# shellcheck disable=SC2016
printf '%s\n' $TILES | xargs -P "$JOBS" -n 1 bash -c '
	S=$(date +%s); LOG="$OUT/settle_${1/,/_}.txt"
	godot --headless --path . --script res://src/worldgen/tools/settle_water.gd -- --tile="$1" --world="$WORLD" > "$LOG" 2>&1
	CODE=$?
	echo "settle $1: $(grep -E "settle done|film floor" "$LOG" | tr "\n" " " | cut -c1-400) ($(( $(date +%s) - S )) s, exit $CODE)"
	exit $CODE' _
FAILED=$?
echo "settle_tiles: done $(date +%H:%M:%S), $(( $(date +%s) - START )) s wall; logs in $OUT"
[ "$FAILED" -eq 0 ] || { echo "settle_tiles: at least one tile failed (see its log)"; exit 1; }
