#!/bin/bash
# Look rig: take pictures from the real client, windowed, in the second clone, never touching Dave's game, server or settings.
#   tools/look_rig.sh --item torch [--count 1] [--cam first|left] [--at X,Z] [--agl 1.7] [--yaw 0] [--pitch 0]
#                     [--hour 12] [--weather clear|rain|storm|snow] [--admin] [--name NAME] [--out DIR] [--wait 25] [--settle 12]
#   --item   the item in slot 0 of the test character, held in the hand (omit for an empty hand)
#   --flora a,b,c  a labelled row of those plant species 4 m ahead (e.g. raspberry,bramble,nettle,wild_rose)
#   --ground ID:N  drop N of an item on the ground 2.2 m ahead of --at (stone:20 = a pile); --gy ground height (default 28.0 = the spawn)
#   --summer  draw the --flora row in the species' own green instead of the game's autumn tint
#   --give ID:N --drop  give N of an item, then drop all N 2.2 m ahead (a real drop: stone:20 makes a pile)
#   --dig N   Dave's dirt test: use with --item wooden_spade --pitch -60: N digs (add --heavy for 400 stones in the pack first, so the yield spills onto the ground) at one spot (use 20), then DROPS the soil it got 1.2 m ahead, steps back 1 m, looks down (-60) and spins a full turn with a picture every quarter (_spin0..3), then the final picture at -50
#   --look-down DEG (default -50)  --back M (default 1)  --drop-dist M (default 1.0; also where --ground lays its pile)  --expect "text"
#     Ground tests (--drop, --ground, --dig) step back M and look down DEG before the picture (tech/TEST_RECIPE.md), and the log gets a
#     "shot runner: state:" line: the expectation, the player, and every loose item within 6 m with its gap above the ground.
#   --dist M  third-person camera distance (under 2 m aims at the held item: a hand close-up)
#   --cam    first = the player's own view; left = the character seen from 2.8 m to its left (third person)
#   --at     world x,z (default the spawn 53301,68427); --agl metres above the ground; --yaw 0 faces north (-Z), 90 west, -90 east
#   --cam right = the character seen from its right (the right hand shows); --nograss hides the grass; --keep keeps the temp folder
#   --admin  also show the F3 admin/debug lines
# Runs a throwaway server (own store, --open-admin) and a windowed client with its own APPDATA, so Dave's saves, hotbar and
# display settings are never read or written. PNGs go to --out (default E:/Software/godotDev/DynastyALWL_Evidence/shots).
# Close Dave's game first only if the PC is short of RAM; the rig runs beside it. Needs Git bash and GODOT_EXE (default below).
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"
ITEM=""; GROUND=""; GY=28.0; COUNT=1; CAM=first; AT="53301,68427"; AGL=1.7; YAW=0; PITCH=0; HOUR=12; WEATHER=clear; ADMIN=""; NAME=""; OUT="E:/Software/godotDev/DynastyALWL_Evidence/shots"; WAIT=25; SETTLE=12; DDIST=1.0
while [ $# -gt 0 ]; do
  case "$1" in
    --item) ITEM="$2"; shift 2;; --count) COUNT="$2"; shift 2;; --cam) CAM="$2"; shift 2;; --at) AT="$2"; shift 2;;
    --agl) AGL="$2"; shift 2;; --yaw) YAW="$2"; shift 2;; --pitch) PITCH="$2"; shift 2;; --hour) HOUR="$2"; shift 2;;
    --weather) WEATHER="$2"; shift 2;; --admin) ADMIN="$ADMIN --shot-admin"; shift;; --flora) ADMIN="$ADMIN --shot-flora=$2"; shift 2;; --ground) GROUND="$2"; ADMIN="$ADMIN --shot-ground"; shift 2;; --gy) GY="$2"; shift 2;; --summer) ADMIN="$ADMIN --shot-summer"; shift;; --drop) ADMIN="$ADMIN --shot-drop"; shift;; --dig) ADMIN="$ADMIN --shot-dig=$2"; shift 2;; --heavy) ADMIN="$ADMIN --shot-heavy"; shift;; --look-down) ADMIN="$ADMIN --shot-lookdown=$2"; shift 2;; --back) ADMIN="$ADMIN --shot-back=$2"; shift 2;; --drop-dist) ADMIN="$ADMIN --shot-drop-dist=$2"; DDIST="$2"; shift 2;; --expect) EXPECT="$2"; shift 2;; --give) ADMIN="$ADMIN --shot-give=$2"; shift 2;; --dist) ADMIN="$ADMIN --shot-dist=$2"; shift 2;; --nograss) ADMIN="$ADMIN --shot-nograss"; shift;; --keep) KEEP=1; shift;; --keep) KEEP=1; shift;; --name) NAME="$2"; shift 2;; --out) OUT="$2"; shift 2;;
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
if [ -n "$GROUND" ]; then
  GID="${GROUND%%:*}"; GCOUNT="${GROUND#*:}"; [ "$GCOUNT" = "$GROUND" ] && GCOUNT=1
  python tools/look_rig_seed.py "$STORE/world_items.json" "$GID" "$GCOUNT" "$X" "$GY" "$Z" "$DDIST"
fi
PORT=$((7800 + RANDOM % 150))
"$GODOT" --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$STORE" --open-admin --quit-after=900 > "$RIG/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; sleep 1; [ -z "$KEEP" ] && rm -rf "$RIG"; [ -n "$KEEP" ] && echo "rig kept: $RIG"' EXIT
sleep 30
WALK=-1; [ "$CAM" = "left" ] && WALK=0; [ "$CAM" = "right" ] && { WALK=0; ADMIN="$ADMIN --shot-right"; }
SHOT="$NAME:$X,$AGL,$Z,$YAW,$PITCH,$HOUR,$WEATHER,$WALK"
APPDATA="$(cygpath -w "$RIG/appdata")" "$GODOT" --path . --resolution 1280x720 res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --shots="$SHOT" --shot-dir="$OUT" --shot-wait=$WAIT --shot-settle=$SETTLE $ADMIN ${EXPECT:+"--shot-expect=$EXPECT"} > "$RIG/client.log" 2>&1
grep -E "shot runner: saved|ERROR|SCRIPT" "$RIG/client.log" | head -5 | cut -c1-200
ls -la "$OUT/$NAME.png" 2>/dev/null | awk '{print $5, $9}'
