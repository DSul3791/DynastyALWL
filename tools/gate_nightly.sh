#!/bin/bash
# Nightly / per-shipped-build slow lane: full run (every test incl. slow and timing) of the current generator-v2, then the picture set.
#   tools/gate_nightly.sh [hash]      default hash = origin/claude/generator-v2 head. Results go to claude/box-results via gate.sh publish.
# Cron on the box: 30 3 * * * bash /work/bake/tools/gate_nightly.sh >> /out/gate/nightly.log 2>&1
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${GATE_ROOT:-/out/gate}"
H="$1"; [ -z "$H" ] && H=$(git -C "$HERE/.." ls-remote origin refs/heads/claude/generator-v2 | cut -f1)
[ ${#H} = 40 ] || { echo "no hash"; exit 2; }
[ -e /out/PAUSE ] && { echo "PAUSE file present, not running"; exit 0; }
bash "$HERE/gate.sh" "$H" --lane full --jobs 4 --base origin/claude/generator-v2
# picture set: the admin showroom and a flora row, one folder per night, never deleting older ones
OUT="$ROOT/pictures/$(date +%Y%m%d)_${H:0:8}"; mkdir -p "$OUT"
bash "$HERE/look_rig.sh" --showroom all --out "$OUT/showroom" > "$OUT/showroom.log" 2>&1 || echo "picture set: showroom failed, see $OUT/showroom.log"
bash "$HERE/look_rig.sh" --flora raspberry,bramble,nettle,wild_rose --out "$OUT/flora" > "$OUT/flora.log" 2>&1 || echo "picture set: flora failed, see $OUT/flora.log"
echo "pictures: $OUT ($(ls "$OUT"/*/ 2>/dev/null | grep -c png) png)"
