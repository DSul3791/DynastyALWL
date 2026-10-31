#!/bin/bash
# Photograph the temporary showroom (make_showroom.py) one row per client run, 4 at a time. Restore data/items/showroom.json afterwards (git checkout).
cd "$(dirname "$0")/../.."
LOGS="${1:-art/playthrough/showroom/logs}"; mkdir -p "$LOGS" art/playthrough/showroom
N=$(python -c "import json;print(len(json.load(open('data/items/showroom.json'))['rows']))")
seq -f "R%02g" 1 "$N" | xargs -P 4 -I{} bash -c 'bash art/playthrough/rig.sh --showroom "{} " --showroom-spread --gy 1039.0 --wait 90 --settle 20 --out art/playthrough/showroom --name sr > "'"$LOGS"'/{}.log" 2>&1'
