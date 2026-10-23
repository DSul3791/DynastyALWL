#!/bin/bash
# Look rig: take pictures from the real client, windowed, in the second clone, never touching Dave's game, server or settings.
#   tools/look_rig.sh --item torch [--count 1] [--cam first|left] [--at X,Z] [--agl 1.7] [--yaw 0] [--pitch 0]
#                     [--hour 12] [--weather clear|rain|storm|snow] [--admin] [--name NAME] [--out DIR] [--wait 25] [--settle 12]
#   --item   the item in slot 0 of the test character, held in the hand (omit for an empty hand)
#   --flora a,b,c  a labelled row of those plant species 4 m ahead (e.g. raspberry,bramble,nettle,wild_rose)
#   --cam    first = the player's own view; left = the character seen from 2.8 m to its left (third person)
#   --at     world x,z (default the spawn 53301,68427); --agl metres above the ground; --yaw 0 faces north (-Z), 90 west, -90 east
#   --cam right = the character seen from its right (the right hand shows); --nograss hides the grass; --keep keeps the temp folder
#   --admin  also show the F3 admin/debug lines
# Runs a throwaway server (own store, --open-admin) and a windowed client with its own APPDATA, so Dave's saves, hotbar and
# display settings are never read or written. PNGs go to --out (default E:/Software/godotDev/DynastyALWL_Evidence/shots).
# Close Dave's game first only if the PC is short of RAM; the rig runs beside it. Needs Git bash and GODOT_EXE (default below).
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"
ITEM=""; COUNT=1; CAM=first; AT="53301,68427"; AGL=1.7; YAW=0; PITCH=0; HOUR=12; WEATHER=clear; ADMIN=""; NAME=""; OUT="E:/Software/godotDev/DynastyALWL_Evidence/shots"; WAIT=25; SETTLE=12
while [ $# -gt 0 ]; do
  case "$1" in
    --item) ITEM="$2"; shift 2;; --count) COUNT="$2"; shift 2;; --cam) CAM="$2"; shift 2;; --at) AT="$2"; shift 2;;
    --agl) AGL="$2"; shift 2;; --yaw) YAW="$2"; shift 2;; --pitch) PITCH="$2"; shift 2;; --hour) HOUR="$2"; shift 2;;
    --weather) WEATHER="$2"; shift 2;; --admin) ADMIN="$ADMIN --shot-admin"; shift;; --flora) ADMIN="$ADMIN --shot-flora=$2"; shift 2;; --nograss) ADMIN="$ADMIN --shot-nograss"; shift;; --keep) KEEP=1; shift;; --keep) KEEP=1; shift;; --name) NAME="$2"; shift 2;; --out) OUT="$2"; shift 2;;
    --wait) WAIT="$2"; shift 2;; --settle) SETTLE="$2"; shift 2;; *) echo "unknown argument $1"; exit 2;;
  esac
done
[ -z "$NAME" ] && NAME="${ITEM:-empty}_${CAM}"
X="${AT%,*}"; Z="${AT#*,}"
RIG=$(mktemp -d); STORE="$RIG/store"; UD="$RIG/appdata/Godot/app_userdata/Dynasty a life well lived"
mkdir -p "$STORE" "$UD" "$OUT"
KEY="00112233445566778899aabb"; echo -n "$KEY" > "$UD/player_key.txt"; echo -n "0" > "$UD/hotbar.txt"
if [ -n "$ITEM" ]; then
  NUM=$(python - "$ITEM" <<'PYEOF'
import json,sys
d=json.load(open('data/items/items.json',encoding='utf-8'))
def find(o,k):
    if isinstance(o,dict):
        if k in o and isinstance(o[k],dict) and 'number' in o[k]: return o[k]['number']
        for v in o.values():
            r=find(v,k)
            if r is not None: return r
r=find(d,sys.argv[1])
print(r if r is not None else "")
PYEOF
)
  [ -z "$NUM" ] && { echo "no such item: $ITEM"; exit 2; }
  python - "$STORE/inventories.json" "$KEY" "$NUM" "$COUNT" <<'PYEOF'
import json,sys
slots=[[0,0,0] for _ in range(30)]
slots[0]=[int(sys.argv[3]),int(sys.argv[4]),0]
json.dump({"version":2,"inventories":{sys.argv[2]:slots}},open(sys.argv[1],"w"))
PYEOF
fi
PORT=$((7800 + RANDOM % 150))
"$GODOT" --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$STORE" --open-admin --quit-after=900 > "$RIG/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; sleep 1; [ -z "$KEEP" ] && rm -rf "$RIG"; [ -n "$KEEP" ] && echo "rig kept: $RIG"' EXIT
sleep 30
WALK=-1; [ "$CAM" = "left" ] && WALK=0; [ "$CAM" = "right" ] && { WALK=0; ADMIN="$ADMIN --shot-right"; }
SHOT="$NAME:$X,$AGL,$Z,$YAW,$PITCH,$HOUR,$WEATHER,$WALK"
APPDATA="$(cygpath -w "$RIG/appdata")" "$GODOT" --path . --resolution 1280x720 res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --shots="$SHOT" --shot-dir="$OUT" --shot-wait=$WAIT --shot-settle=$SETTLE $ADMIN > "$RIG/client.log" 2>&1
grep -E "shot runner: saved|ERROR|SCRIPT" "$RIG/client.log" | head -5 | cut -c1-200
ls -la "$OUT/$NAME.png" 2>/dev/null | awk '{print $5, $9}'
