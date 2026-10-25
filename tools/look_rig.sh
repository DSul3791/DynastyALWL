#!/bin/bash
# Look rig: take pictures from the real client, windowed, in the second clone, never touching Dave's game, server or settings.
#   tools/look_rig.sh --item torch [--count 1] [--cam first|left] [--at X,Z] [--agl 1.7] [--yaw 0] [--pitch 0]
#                     [--hour 12] [--weather clear|rain|storm|snow] [--admin] [--name NAME] [--out DIR] [--wait 25] [--settle 12]
#   --item   the item in slot 0 of the test character, held in the hand (omit for an empty hand)
#   --flora a,b,c  a labelled row of those plant species 4 m ahead (e.g. raspberry,bramble,nettle,wild_rose)
#   --pieces a,b,c  a labelled row of building pieces 4 m ahead, by structure name (data/items/structures.json keys, e.g. wall_section,doorway_section,window_section,floor_section,roof_section,foundation_section,chest,workbench), built by the game's own ghost_model, spaced by size; grass off; two pictures (wide, close) unless --views is given; one "shot runner: piece" line each with its size (FAIL empty = draws nothing). A typo stops in seconds with the valid names.
#   --showroom all|label,label  turns Admin mode on and takes ONE picture per admin showroom row (data/items/showroom.json; a label part matches, any case: --showroom spades,hoes), from the west, with a name tag over each item; one "shot runner: showroom row" line each (items expected vs found, FAIL missing)
#   --showroom-cam-height M  --showroom-look-down DEG  --showroom-spread  (the camera numbers are logged on every picture, "shot runner: view ... dist pitch above"; tag overlaps are counted: "shot runner: tag overlap")  with --showroom: camera M metres above the ground (default 1.6 + 0.25 x row length; 3 for a view from above), its pitch (e.g. -35), and name tags staggered in three heights so neighbours do not overlap
#   --pieces-yaw N  turn the whole --pieces row N degrees (see the back of a wall)
#   --ground ID:N  drop N of an item on the ground 2.2 m ahead of --at (stone:20 = a pile); --gy ground height of the pile (default 31.0 = the spawn ground in the current world; set it if you use --at elsewhere)
#   --ground-close ID[:N]  the same pile (default 1) seen close: camera 0.35 m above the ground 0.9 m from it, looking 45 degrees down, ground in view (held shots at 1.5 m hide the item behind the body). Numbers are flags: --close-height M --close-dist M --close-pitch DEG; --agl/--drop-dist/--look-down after it override. Example: tools/look_rig.sh --ground-close rose_petals:3 --name petals_ground
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
# Windows (Git bash) keeps the old behaviour; Linux (the server box) draws on the NVIDIA GPU under Xvfb, like tools/docker/shot.sh.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1;; *) WIN="";; esac
if [ -n "$WIN" ]; then
  GODOT="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"; PY=python; DEFOUT="E:/Software/godotDev/DynastyALWL_Evidence/shots"
else
  GODOT="${GODOT_EXE:-/opt/godot/godot}"; GFX="${GODOT_GFX_EXE:-/opt/godot/godot-gfx}"; PY=python3; DEFOUT=/out/shots
fi
LETTERS=abcdefgh; TURNS=1; GSETTLE=10; GMAX=60; CLOSE=""; CH=0.35; CD=0.9; CP=-45; PIECES=""; ITEM=""; GROUND=""; GY=31.0; COUNT=1; CAM=first; AT="53301,68427"; AGL=1.7; YAW=0; PITCH=0; HOUR=12; WEATHER=clear; ADMIN=""; NAME=""; OUT="$DEFOUT"; WAIT=""; SETTLE=""; DDIST=1.0
while [ $# -gt 0 ]; do
  case "$1" in
    --item) ITEM="$2"; shift 2;; --count) COUNT="$2"; shift 2;; --cam) CAM="$2"; shift 2;; --at) AT="$2"; shift 2;;
    --agl) AGL="$2"; shift 2;; --yaw) YAW="$2"; shift 2;; --pitch) PITCH="$2"; shift 2;; --hour) HOUR="$2"; shift 2;;
    --weather) WEATHER="$2"; shift 2;; --admin) ADMIN="$ADMIN --shot-admin"; shift;; --flora) ADMIN="$ADMIN --shot-flora=$2"; shift 2;; --pieces) PIECES="$2"; ADMIN="$ADMIN --shot-pieces=$2"; shift 2;; --pieces-yaw) ADMIN="$ADMIN --shot-pieces-yaw=$2"; shift 2;; --showroom) ADMIN="$ADMIN --shot-showroom=$2"; shift 2;; --frametime) ADMIN="$ADMIN --shot-frametime=$2 --shot-build=$(git rev-parse --short HEAD 2>/dev/null)"; shift 2;; --quality) ADMIN="$ADMIN --shot-quality=$2"; shift 2;; --views) ADMIN="$ADMIN --shot-views=$2"; shift 2;; --cam-above) ADMIN="$ADMIN --shot-cam-above=$2"; shift 2;; --flora-scale) ADMIN="$ADMIN --shot-flora-scale=$2"; shift 2;; --ground) GROUND="$2"; ADMIN="$ADMIN --shot-ground"; shift 2;; --showroom-cam-height) ADMIN="$ADMIN --shot-showroom-height=$2"; shift 2;; --showroom-look-down) ADMIN="$ADMIN --shot-showroom-look=$2"; shift 2;; --showroom-spread) ADMIN="$ADMIN --shot-showroom-spread"; shift;; --gy) GY="$2"; shift 2;; --ground-close) GROUND="$2"; CLOSE=1; shift 2;; --close-height) CH="$2"; shift 2;; --close-dist) CD="$2"; shift 2;; --close-pitch) CP="$2"; shift 2;; --summer) ADMIN="$ADMIN --shot-summer"; shift;; --drop) ADMIN="$ADMIN --shot-drop"; shift;; --dig) ADMIN="$ADMIN --shot-dig=$2"; shift 2;; --heavy) ADMIN="$ADMIN --shot-heavy"; shift;; --look-down) ADMIN="$ADMIN --shot-lookdown=$2"; shift 2;; --back) ADMIN="$ADMIN --shot-back=$2"; shift 2;; --drop-dist) ADMIN="$ADMIN --shot-drop-dist=$2"; DDIST="$2"; shift 2;; --expect) EXPECT="$2"; shift 2;; --give) ADMIN="$ADMIN --shot-give=$2"; shift 2;; --dist) ADMIN="$ADMIN --shot-dist=$2"; shift 2;; --nograss) ADMIN="$ADMIN --shot-nograss"; shift;; --keep) KEEP=1; shift;; --keep) KEEP=1; shift;; --name) NAME="$2"; shift 2;; --out) OUT="$2"; shift 2;;
    --wait) WAIT="$2"; shift 2;; --settle) SETTLE="$2"; shift 2;; --turns) TURNS="$2"; shift 2;; --ground-settle) GSETTLE="$2"; shift 2;; --ground-max) GMAX="$2"; shift 2;; --realview) ADMIN="$ADMIN --shot-realview"; shift;; *) echo "unknown argument $1"; exit 2;;
  esac
done
# --ground-close: the camera numbers are flags (--close-height, --close-dist, --close-pitch); later --agl/--drop-dist/--look-down still win.
if [ -n "$CLOSE" ]; then
  ADMIN="$ADMIN --shot-ground --shot-back=0 --shot-lookdown=$CP --shot-drop-dist=$CD"; DDIST="$CD"; AGL="$CH"
  echo "rig: ground close-up camera: height $CH m, distance $CD m, pitch $CP deg (flags --close-height --close-dist --close-pitch)"
fi
# Defaults changed on 24 Oct 2026: printed on every run so a before/after picture is not mistaken for a game change.
echo "rig defaults: --gy $GY (was 28.0 until 24 Oct; the spawn ground is 31.0 in the current world, pass --gy 28 to repeat an old picture)"
# --pieces: refuse a name that is not a structures.json key before the scene starts (a typo costs seconds, not a launch).
if [ -n "$PIECES" ]; then
  KEYS=$(grep -oE '^		"[a-z_0-9]+": \{' data/items/structures.json | sed -E 's/^\s*"([a-z_0-9]+)".*/\1/' | grep -vE '^(campfire)$' | tr '\n' ' ')
  IFS=',' read -ra WANT <<< "$PIECES"
  for P in "${WANT[@]}"; do
    case " $KEYS " in *" $P "*) ;; *) echo "no such piece: $P"; echo "valid pieces: $KEYS"; exit 2;; esac
  done
fi
[ -z "$NAME" ] && NAME="${ITEM:-empty}_${CAM}"
if [ -n "$WIN" ]; then WAIT="${WAIT:-3}"; SETTLE="${SETTLE:-12}"; else WAIT="${WAIT:-3}"; SETTLE="${SETTLE:-20}"; fi
X="${AT%,*}"; Z="${AT#*,}"
RIG=$(mktemp -d); STORE="$RIG/store"; mkdir -p "$RIG/home"; if [ -n "$WIN" ]; then AD="/e/Software/godotDev/rig_appdata"; UD="$AD/Godot/app_userdata/Dynasty a life well lived"; else UD="$RIG/data/godot/app_userdata/Dynasty a life well lived"; fi
mkdir -p "$STORE" "$UD" "$OUT"
KEY="00112233445566778899aabb"; echo -n "$KEY" > "$UD/player_key.txt"; echo -n "0" > "$UD/hotbar.txt"
if [ -n "$ITEM" ]; then
  NUM=$($PY tools/item_numbers.py "$ITEM") || { echo "item tables: duplicate name or number (see above)"; exit 2; }
  [ -z "$NUM" ] && { echo "no such item: $ITEM"; exit 2; }
  $PY - "$STORE/inventories.json" "$KEY" "$NUM" "$COUNT" <<'PYEOF'
import json,sys
slots=[[0,0,0] for _ in range(30)]
slots[0]=[int(sys.argv[3]),int(sys.argv[4]),0]
json.dump({"version":2,"inventories":{sys.argv[2]:slots}},open(sys.argv[1],"w"))
PYEOF
fi
if [ -n "$GROUND" ]; then
  GID="${GROUND%%:*}"; GCOUNT="${GROUND#*:}"; [ "$GCOUNT" = "$GROUND" ] && GCOUNT=1
  $PY tools/look_rig_seed.py "$STORE/world_items.json" "$GID" "$GCOUNT" "$X" "$GY" "$Z" "$DDIST"
fi
PORT=$((7800 + RANDOM % 150)); while netstat -an 2>/dev/null | grep -q ":$PORT "; do PORT=$((7800 + RANDOM % 150)); done   # a port nobody holds
T0=$(date +%s)
"$GODOT" --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$STORE" --open-admin --quit-after=900 > "$RIG/server.log" 2>&1 &
SP=$!
if [ -n "$WIN" ] && [ -z "$NOWINDOW" ]; then   # Dave 25 Oct: a visible window shows the server log live; it stays open after the run, the next run closes it first
  taskkill //F //FI "WINDOWTITLE eq Test server*" > /dev/null 2>&1
  cmd //c start "Test server" powershell -NoExit -Command "\$host.UI.RawUI.WindowTitle='Test server'; Get-Content -Wait -Tail 60 -LiteralPath '$(cygpath -w "$RIG/server.log")' -ErrorAction SilentlyContinue; Write-Host '--- run finished ---'" > /dev/null 2>&1
fi
trap 'kill $SP 2>/dev/null; sleep 1; [ -z "$KEEP" ] && rm -rf "$RIG"; [ -n "$KEEP" ] && echo "rig kept: $RIG"' EXIT
for _i in $(seq 1 60); do grep -q "listening" "$RIG/server.log" 2>/dev/null && break; sleep 0.5; done   # was a fixed sleep 30: go as soon as the server prints its listening line (30 s at most)
echo "rig timing: server listening after $(( $(date +%s) - T0 )) s"
WALK=-1; [ "$CAM" = "left" ] && WALK=0; [ "$CAM" = "right" ] && { WALK=0; ADMIN="$ADMIN --shot-right"; }
SHOT="$NAME:$X,$AGL,$Z,$YAW,$PITCH,$HOUR,$WEATHER,$WALK"
if [ "$TURNS" -gt 1 ]; then   # Dave 25 Oct: 3 shots per spot, turning left 90 degrees after each (yaw, yaw+90, yaw+180)
  SHOT=""; for _t in $(seq 0 $((TURNS - 1))); do
    SHOT="${SHOT:+$SHOT;}${NAME}_${LETTERS:$_t:1}:$X,$AGL,$Z,$(python3 -c "print(($YAW) + 90 * $_t)" 2>/dev/null || python -c "print(($YAW) + 90 * $_t)"),$PITCH,$HOUR,$WEATHER,$WALK"
  done
fi
CARGS=(--server=127.0.0.1 --port=$PORT --shots="$SHOT" --shot-dir="$OUT" --shot-wait=$WAIT --shot-settle=$SETTLE --shot-ground-settle=$GSETTLE --shot-ground-max=$GMAX $ADMIN ${EXPECT:+"--shot-expect=$EXPECT"})
if [ -n "$WIN" ]; then
  APPDATA="$(cygpath -w "$AD")" "$GODOT" --path . --resolution 1280x720 res://scenes/terrain_client/terrain_client.tscn -- "${CARGS[@]}" > "$RIG/client.log" 2>&1
else
  # NVIDIA Vulkan file when nvidia-smi works (found by looking), else Mesa lavapipe; own HOME so Dave's settings are never touched.
  ICD=""; REND=software
  if [ "${SHOT_RENDERER:-auto}" != software ] && command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then
    ICD=$(ls /usr/share/vulkan/icd.d/nvidia_icd*.json /etc/vulkan/icd.d/nvidia_icd*.json 2>/dev/null | head -1); [ -n "$ICD" ] && REND=nvidia
  fi
  [ -z "$ICD" ] && ICD=$(ls /usr/share/vulkan/icd.d/lvp_icd*.json /etc/vulkan/icd.d/lvp_icd*.json 2>/dev/null | head -1)
  [ -z "$ICD" ] && { echo "no Vulkan driver file found"; exit 1; }
  echo "renderer: $REND ($ICD)"; [ "$REND" = software ] && export LIBGL_ALWAYS_SOFTWARE=1
  HOME="$RIG/home" XDG_DATA_HOME="$RIG/data" VK_ICD_FILENAMES="$ICD" xvfb-run -a -s "-screen 0 1280x720x24" "$GFX" --path . --rendering-driver vulkan --resolution 1280x720 res://scenes/terrain_client/terrain_client.tscn -- "${CARGS[@]}" > "$RIG/client.log" 2>&1
fi
echo "rig timing: client run (join to last picture) $(( $(date +%s) - T0 )) s since the server started"
grep -E "shot runner: saved|ERROR|SCRIPT" "$RIG/client.log" | head -5 | cut -c1-200
grep -E "shot runner: pose" "$RIG/client.log" | cut -c1-220   # the pose read back at each capture (POSE MISMATCH / GROUND NOT READY are flagged on the line)
if grep -q "GROUND NOT READY" "$RIG/client.log"; then echo "FAILED: ground not ready at the shot (pictures are named _FAILED_ground_not_ready, do not use them)"; exit 4; fi
if [ "$TURNS" -gt 1 ]; then   # no two pictures of one run may be identical (STANDARD_SHOTS rule)
  _SUMS=$(for _t in $(seq 0 $((TURNS - 1))); do md5sum "$OUT/${NAME}_${LETTERS:$_t:1}.png" 2>/dev/null; done | cut -d' ' -f1)
  _N=$(echo "$_SUMS" | grep -c .); _D=$(echo "$_SUMS" | sort -u | grep -c .)
  echo "duplicate check: $_N pictures, $_D distinct"; [ "$_N" != "$_D" ] && { echo "DUPLICATE PICTURES: the batch fails"; exit 3; }
fi
ls -la "$OUT/$NAME.png" 2>/dev/null | awk '{print $5, $9}'
