#!/bin/bash
# Look rig: take pictures from the real client, windowed, in the second clone, never touching Dave's game, server or settings.
#   tools/look_rig.sh --item torch [--count 1] [--cam first|left] [--at X,Z] [--agl 1.7] [--yaw 0] [--pitch 0]
#                     [--hour 12] [--weather clear|rain|storm|snow] [--admin] [--name NAME] [--out DIR] [--wait 25] [--settle 12]
#   --item   the item in slot 0 of the test character, held in the hand (omit for an empty hand)
#   --flora a,b,c  a labelled row of those plant species 4 m ahead (e.g. raspberry,bramble,nettle,wild_rose)
#   --pieces a,b,c  a labelled row of building pieces 4 m ahead, by structure name (data/items/structures.json keys, e.g. wall_section,doorway_section,window_section,floor_section,roof_section,foundation_section,chest,workbench), built by the game's own ghost_model, spaced by size; grass off; two pictures (wide, close) unless --views is given; one "shot runner: piece" line each with its size (FAIL empty = draws nothing). A typo stops in seconds with the valid names.
#   --showroom all|label,label  turns Admin mode on and takes ONE picture per admin showroom row (data/items/showroom.json; a label part matches, any case: --showroom spades,hoes), from the west, with a name tag over each item; one "shot runner: showroom row" line each (items expected vs found, FAIL missing)
#   --pieces-yaw N  turn the whole --pieces row N degrees (see the back of a wall)
#   --ground ID:N  drop N of an item on the ground 2.2 m ahead of --at (stone:20 = a pile); --gy ground height (default 28.0 = the spawn)
#   --flora-scale N  draw the --flora row N times its size (diagnosis: is a small plant only hard to see?)
#   --cam-above M  with --flora: the camera stands M metres above the ground at the plant row (e.g. --cam-above 0.5 --dist 3 --pitch -10); default keeps --agl
#   --frametime S [--quality 0-3]  after a 10 s warm-up measures frame times for S seconds (quality 0 = Low) and prints one "shot runner: frametime" line: build, quality, spot, avg, p95, p99, max, frames over 50/100 ms, verdict (FAIL = p95 >= 33 ms or any frame over 100 ms; WARN = p99 over 50 ms), machine (GPU, driver, window). VSync off, fixed hour and weather, flora and water on. For a borderline number run it 3 times and take the median
#   --views "name:dist:pitch:above;..."  extra pictures of the same scene in ONE start: camera dist m south of the subject (flora row middle, else 4 m ahead), pitch deg, above = camera m above the ground; frames <name>_<view>.png, one "shot runner: view" line each (e.g. --views "wide:8:-8:1.5;close:3:-10:0.5")
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
PIECES=""; ITEM=""; GROUND=""; GY=28.0; COUNT=1; CAM=first; AT="53301,68427"; AGL=1.7; YAW=0; PITCH=0; HOUR=12; WEATHER=clear; ADMIN=""; NAME=""; OUT="E:/Software/godotDev/DynastyALWL_Evidence/shots"; WAIT=25; SETTLE=12; DDIST=1.0
while [ $# -gt 0 ]; do
  case "$1" in
    --item) ITEM="$2"; shift 2;; --count) COUNT="$2"; shift 2;; --cam) CAM="$2"; shift 2;; --at) AT="$2"; shift 2;;
    --agl) AGL="$2"; shift 2;; --yaw) YAW="$2"; shift 2;; --pitch) PITCH="$2"; shift 2;; --hour) HOUR="$2"; shift 2;;
    --weather) WEATHER="$2"; shift 2;; --admin) ADMIN="$ADMIN --shot-admin"; shift;; --flora) ADMIN="$ADMIN --shot-flora=$2"; shift 2;; --pieces) PIECES="$2"; ADMIN="$ADMIN --shot-pieces=$2"; shift 2;; --pieces-yaw) ADMIN="$ADMIN --shot-pieces-yaw=$2"; shift 2;; --showroom) ADMIN="$ADMIN --shot-showroom=$2"; shift 2;; --frametime) ADMIN="$ADMIN --shot-frametime=$2 --shot-build=$(git rev-parse --short HEAD 2>/dev/null)"; shift 2;; --quality) ADMIN="$ADMIN --shot-quality=$2"; shift 2;; --views) ADMIN="$ADMIN --shot-views=$2"; shift 2;; --cam-above) ADMIN="$ADMIN --shot-cam-above=$2"; shift 2;; --flora-scale) ADMIN="$ADMIN --shot-flora-scale=$2"; shift 2;; --ground) GROUND="$2"; ADMIN="$ADMIN --shot-ground"; shift 2;; --gy) GY="$2"; shift 2;; --summer) ADMIN="$ADMIN --shot-summer"; shift;; --drop) ADMIN="$ADMIN --shot-drop"; shift;; --dig) ADMIN="$ADMIN --shot-dig=$2"; shift 2;; --heavy) ADMIN="$ADMIN --shot-heavy"; shift;; --look-down) ADMIN="$ADMIN --shot-lookdown=$2"; shift 2;; --back) ADMIN="$ADMIN --shot-back=$2"; shift 2;; --drop-dist) ADMIN="$ADMIN --shot-drop-dist=$2"; DDIST="$2"; shift 2;; --expect) EXPECT="$2"; shift 2;; --give) ADMIN="$ADMIN --shot-give=$2"; shift 2;; --dist) ADMIN="$ADMIN --shot-dist=$2"; shift 2;; --nograss) ADMIN="$ADMIN --shot-nograss"; shift;; --keep) KEEP=1; shift;; --keep) KEEP=1; shift;; --name) NAME="$2"; shift 2;; --out) OUT="$2"; shift 2;;
    --wait) WAIT="$2"; shift 2;; --settle) SETTLE="$2"; shift 2;; *) echo "unknown argument $1"; exit 2;;
  esac
done
# --pieces: refuse a name that is not a structures.json key before the scene starts (a typo costs seconds, not a launch).
if [ -n "$PIECES" ]; then
  KEYS=$(grep -oE '^		"[a-z_0-9]+": \{' data/items/structures.json | sed -E 's/^\s*"([a-z_0-9]+)".*/\1/' | grep -vE '^(campfire)$' | tr '\n' ' ')
  IFS=',' read -ra WANT <<< "$PIECES"
  for P in "${WANT[@]}"; do
    case " $KEYS " in *" $P "*) ;; *) echo "no such piece: $P"; echo "valid pieces: $KEYS"; exit 2;; esac
  done
fi
[ -z "$NAME" ] && NAME="${ITEM:-empty}_${CAM}"
X="${AT%,*}"; Z="${AT#*,}"
RIG=$(mktemp -d); STORE="$RIG/store"; UD="$RIG/appdata/Godot/app_userdata/Dynasty a life well lived"
mkdir -p "$STORE" "$UD" "$OUT"
KEY="00112233445566778899aabb"; echo -n "$KEY" > "$UD/player_key.txt"; echo -n "0" > "$UD/hotbar.txt"
if [ -n "$ITEM" ]; then
  NUM=$(python - "$ITEM" <<'PYEOF'
import json,sys
def find(o,k):
    if isinstance(o,dict):
        if k in o and isinstance(o[k],dict) and 'number' in o[k]: return o[k]['number']
        for v in o.values():
            r=find(v,k)
            if r is not None: return r
r=None
for f in ('items','gathered'):
    r=find(json.load(open('data/items/%s.json'%f,encoding='utf-8')),sys.argv[1])
    if r is not None: break
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
