#!/bin/bash
# Photograph the temporary showroom (make_showroom.py): three rows per client run (rows 3g+1..3g+3 sit 40 m apart, so only their own name tags are in
# view), two runs at a time. Restore data/items/showroom.json afterwards: git checkout data/items/showroom.json
cd "$(dirname "$0")/../.."
LOGS="${1:-art/playthrough/showroom/logs}"; mkdir -p "$LOGS" art/playthrough/showroom
N=$(python -c "import json;print(len(json.load(open('data/items/showroom.json'))['rows']))")
G=$(( (N + 2) / 3 ))
for g in $(seq 0 $((G - 1))); do printf "R%02d ,R%02d ,R%02d \n" $((3*g+1)) $((3*g+2)) $((3*g+3)); done | \
  xargs -P 2 -d '\n' -I{} bash -c 'L="{}"; T=$(echo "$L" | cut -c1-3); bash art/playthrough/rig.sh --showroom "$L" --showroom-spread --wait 240 --settle 40 --out art/playthrough/showroom --name sr > "'"$LOGS"'/$T.log" 2>&1'
