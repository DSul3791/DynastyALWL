#!/bin/bash
# One command for the whole river job on a block of baked tiles: settle every tile, stitch the shared edges, run the river report on the middle tile
# and print ONE block of results (seam rows, continuity, class counts). Close Dave's game first. The tiles must already be baked in --world.
#   tools/settle_block.sh --world=DIR [--from=2,3] [--to=4,5] [--report=3,4] [--probe=X,Z ...]
cd "$(dirname "$0")/.." || exit 2
WORLD="res://worlds/base_world"; FROM="2,3"; TO="4,5"; REPORT="3,4"; PROBES=""
for A in "$@"; do
	case "$A" in
		--world=*) WORLD="${A#--world=}";;
		--from=*) FROM="${A#--from=}";;
		--to=*) TO="${A#--to=}";;
		--report=*) REPORT="${A#--report=}";;
		--probe=*) PROBES="$PROBES ${A#--probe=}";;
		*) echo "unknown argument $A"; exit 2;;
	esac
done
OUT="${OUT:-E:/Software/godotDev/DynastyALWL_Evidence/settle_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"
T="res://src/worldgen/tools"
for Z in $(seq "${FROM#*,}" "${TO#*,}"); do
	for X in $(seq "${FROM%,*}" "${TO%,*}"); do
		S=$(date +%s)
		godot --headless --path . --script "$T/settle_water.gd" -- --tile="$X,$Z" --world="$WORLD" > "$OUT/settle_${X}_${Z}.txt" 2>&1
		echo "settle $X,$Z: $(grep -E 'settle done|film floor' "$OUT/settle_${X}_${Z}.txt" | tr '\n' ' ' | cut -c1-260) ($(( $(date +%s) - S )) s)"
	done
done
godot --headless --path . --script "$T/stitch_water_seams.gd" -- --from="$FROM" --to="$TO" --world="$WORLD" > "$OUT/stitch.txt" 2>&1
tail -1 "$OUT/stitch.txt"
godot --headless --path . --script "$T/river_settle_report.gd" -- --tile="$REPORT" --world="$WORLD" > "$OUT/report.txt" 2>&1
grep -E "^seam|continuity|painted river cells|water bodies" "$OUT/report.txt"
grep -o "CLASS [A-Z ,]*" "$OUT/report.txt" | sort | uniq -c
for P in $PROBES; do godot --headless --path . --script "$T/river_settle_report.gd" -- --tile="$REPORT" --world="$WORLD" --probe="$P" > "$OUT/probe_${P/,/_}.txt" 2>&1; done
echo "all output in $OUT"
