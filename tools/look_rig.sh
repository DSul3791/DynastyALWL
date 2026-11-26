#!/bin/bash
# Only the hold of an item (how a tool sits in the hand)? Use tools/shot_held.gd instead: the game's body and held-item code on a flat floor, no
# server or world, a few seconds per set of angles:  "$GODOT_EXE" --path . --script res://tools/shot_held.gd -- --item=copper_saw --out=DIR
# Look rig: take pictures from the real client, windowed, in the second clone, never touching Dave's game, server or settings.
#   tools/look_rig.sh --item torch [--count 1] [--cam first|left] [--at X,Z] [--agl 1.7] [--yaw 0] [--pitch 0]
#                     [--day D] [--hour 12] [--weather clear|rain|storm|snow] [--admin] [--name NAME] [--out DIR] [--wait 25] [--settle 12]
#   --item   the item in slot 0 of the test character, held in the hand (omit for an empty hand)
#   --flora a,b,c  a labelled row of those plant species 4 m ahead (e.g. raspberry,bramble,nettle,wild_rose)
#   --pieces a,b,c  a labelled row of building pieces 4 m ahead, by structure name (data/items/structures.json keys, e.g. wall_section,doorway_section,window_section,floor_section,roof_section,foundation_section,chest,workbench), built by the game's own ghost_model, spaced by size; grass off; two pictures (wide, close) unless --views is given; one "shot runner: piece" line each with its size (FAIL empty = draws nothing). A typo stops in seconds with the valid names.
#   --showroom all|label,label  turns Admin mode on and takes ONE picture per admin showroom row (data/items/showroom.json; a label part matches, any case: --showroom shovels,hoes), from the west, with a name tag over each item; one "shot runner: showroom row" line each (items expected vs found, FAIL missing)
#   --showroom-cam-height M  --showroom-look-down DEG  --showroom-per N  one picture per N items of a row, framed to those items (use 5 for 10-item rows). A --showroom word now matches a whole label, else one word of it (K1 no longer picks K10-K12), else part of a label.  --showroom-spread  (the camera numbers are logged on every picture, "shot runner: view ... dist pitch above"; tag overlaps are counted: "shot runner: tag overlap")  with --showroom: camera M metres above the ground (default 1.6 + 0.25 x row length; 3 for a view from above), its pitch (e.g. -35), and name tags staggered in three heights so neighbours do not overlap
#   --day D  the server's clock starts on day D of the year (0 to 364; spring 0, summer from 91.25, autumn 182.5, winter 273.75), at the
#            shot's --hour: season tints, bare winter trees and the sun's path for that day
#   --pieces-yaw N  turn the whole --pieces row N degrees (see the back of a wall)
#   --piece-extra K:V[,K:V]  draw the --pieces / --piece-views pieces as placed with those row extras, light on, instead of the cold ghost:
#            forge:1 a smithy's red coals (fuel in, idle), forge:2 its flare (working), site:1 a blueprint site in the game's see-through blue (e.g. --pieces campfire --piece-extra site:1), lit:1 a lit kiln or smelter, or any lit light (torches, torch posts, lanterns, lamp posts, braziers, fireplace: its flame and light as in the game). Best at night (--hour 22)
#   --ground ID:N  drop N of an item on the ground 2.2 m ahead of --at (stone:20 = a pile); --gy ground height of the pile (default 31.25 = 0.08 m over the visible spawn ground 31.17, so flat things (saw blade, kindling) are not buried; set it if you use --at elsewhere)
#   --ground-close ID[:N]  the same pile (default 1) seen close: camera 0.35 m above the ground 0.9 m from it, looking 45 degrees down, ground in view (held shots at 1.5 m hide the item behind the body). Numbers are flags: --close-height M --close-dist M --close-pitch DEG; --agl/--drop-dist/--look-down after it override. Example: tools/look_rig.sh --ground-close rose_petals:3 --name petals_ground
#   --flora-scale N  draw the --flora row N times its size (diagnosis: is a small plant only hard to see?)
#   --cam-above M  with --flora: the camera stands M metres above the ground at the plant row (e.g. --cam-above 0.5 --dist 3 --pitch -10); default keeps --agl
#   --frametime S [--quality 0-3]  once the body has landed at the shot (--at, default the spawn, --agl over the real ground) measures frame times for S seconds (quality 0 = Low); the picture is taken after it. The rig prints one "shot runner: frametime" line (no line = FAIL, exit 6): build, quality, spot (x,z, y and m above the ground), avg, p95, p99, max, frames over 50/100 ms, verdict (FAIL = p95 >= 33 ms or any frame over 100 ms; WARN = p99 over 50 ms), machine (GPU, driver, window). VSync off, fixed hour and weather, flora and water on. For a borderline number run it 3 times and take the median
#   --run M_PER_S  with --frametime (a player runs at 9): the body lands on foot and runs the way the shot faces (--yaw) at this speed for the whole measurement, so the ground, flora and grass stream in as for a running player (the running lag; a flying body holds all building while it moves). One extra "shot runner: ran" line gives the metres and the frames with no ground collision under the runner (it glides level there); the picture after it is from where the run ended. Ignored without --frametime
#   --views "name:dist:pitch:above;..."  extra pictures of the same scene in ONE start: camera dist m south of the subject (flora row middle, else 4 m ahead), pitch deg, above = camera m above the ground; frames <name>_<view>.png, one "shot runner: view" line each (e.g. --views "wide:8:-8:1.5;close:3:-10:0.5")
#   --summer  draw the --flora row in the species' own green instead of the game's autumn tint
#   --give ID:N --drop  give N of an item, then drop all N 2.2 m ahead (a real drop: stone:20 makes a pile)
#   --skill SKILL:N    set a skill to N 6 s after connecting (admin), e.g. --skill tracking:5 to see the trail signs
#   --dig N   Dave's dirt test: use with --item wooden_shovel --pitch -60: N digs (add --heavy for 400 stones in the pack first, so the yield spills onto the ground) at one spot (use 20), then DROPS the soil it got 1.2 m ahead, steps back 1 m, looks down (-60) and spins a full turn with a picture every quarter (_spin0..3), then the final picture at -50
#   --look-down DEG (default -50)  --back M (default 1)  --drop-dist M (default 1.0; also where --ground lays its pile)  --expect "text"
#     Ground tests (--drop, --ground, --dig) step back M and look down DEG before the picture (tech/TEST_RECIPE.md), and the log gets a
#     "shot runner: state:" line: the expectation, the player, and every loose item within 6 m with its gap above the ground.
#   --dist M  third-person camera distance (under 2 m aims at the held item: a hand close-up)
#   --cam    first = the player's own view; left = the character seen from 2.8 m to its left (third person)
#   --yaw    default: a plain view at the spawn (no --at, held item or scene row) faces the camp fire as a new character does; otherwise 0
#   --at     world x,z (default the server's own spawn, read from its log, where the starter ground is loaded; --ground piles keep 53301,68427 because
#            they are seeded before the server starts, so pass --at and --gy together for them); --agl metres above the ground; --yaw 0 faces north (-Z), 90 west, -90 east
#   --cam right = the character seen from its right (the right hand shows); --nograss hides the grass; --bow STATE[:DRAW] poses a held bow (with --give wooden_bow; first person shows the arms, --cam left the body with the bow at its side); --lit keeps a given torch or lantern burning in the pictures (fuel given, arms on in first person); --keep keeps the temp folder
#   --admin  also show the F3 admin/debug lines
#   --walk M_PER_S  with --cam left|right: the third-person body walks at that speed (4 = walk, 8 = run, 0 = standing; the shot runner fakes the pace)
#   --angles "name:deg:dist;..."  several third-person pictures from ONE start (camera deg round the body from its front: 0 front, 90 its left, -90 its right,
#            180 behind; dist m, under 2 m aims at the held item); frames <name>_<angle>.png. Implies --cam right when --cam is not given. Example, a held tool:
#            tools/look_rig.sh --give copper_saw --angles "right:-90:1.6;left:90:1.6;hand:-90:0.7;front:0:1.6" --name copper_saw
#   Held-item shots (--give or --item, without --ground/--pieces/--look/--showroom/--flora/--views/--frametime/--drop/--dig) take the picture as soon as the
#   scene is ready instead of on fixed timers (--shot-ready=held; --wait and --settle become the most they wait; --no-ready keeps the old timers), and the
#   body stands in its idle pose (--walk 0) in every third-person shot. --at defaults to the server's spawn in every mode but --ground piles.
#   Every run ends with "rig: N picture(s) in T s"; no picture saved is a FAIL (exit 4).
#   --server-arg ARG  pass one extra argument to the throwaway server (repeat), e.g. --server-arg --water2 (Dynasty water)
#   --client-arg ARG  pass one extra argument to the client (repeat the option), e.g. --client-arg --generated-body
#   Subject shots (--pieces, --look(s), --showroom, held items) hide the plant layer (trees, reeds, bushes) as well as the grass, so a reed bed cannot hide the subject.
#   Every shot (but aerial, over 40 m, and absolute-height ones, which start at their own height) starts 1 m above the real ground at its spot (the server's ground height there), held until the ground under it loads, then goes to --agl (Dave 20 Nov 2026: never from high in the air).
# Runs a throwaway server (own store, --open-admin) and a windowed client with its own APPDATA, so Dave's saves, hotbar and
# display settings are never read or written. PNGs go to --out (default C:/DynastyLane/logs/shots).
# Close Dave's game first only if the PC is short of RAM; the rig runs beside it. Needs Git bash and GODOT_EXE (default below).
cd "$(dirname "$0")/.." || exit 2
SECONDS=0
# Windows (Git bash) keeps the old behaviour; Linux (the server box) draws on the NVIDIA GPU under Xvfb, like tools/docker/shot.sh.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1;; *) WIN="";; esac
if [ -n "$WIN" ]; then
  GODOT="${GODOT_EXE:-C:/DynastyLane/godot/godot_lane_a.exe}"; PY=python; DEFOUT="C:/DynastyLane/logs/shots"
else
  GODOT="${GODOT_EXE:-/opt/godot/godot}"; GFX="${GODOT_GFX_EXE:-/opt/godot/godot-gfx}"; PY=python3; DEFOUT=/out/shots
fi
AT_GIVEN=""; HELD=""; SCENE=""; NOREADY=""; ANGLES=""; CAM_GIVEN=""; CLOSE=""; CH=0.35; CD=0.9; CP=-45; PIECES=""; LOOKS=""; ITEM=""; GROUND=""; GY=31.25; COUNT=1; CAM=first; AT="53301,68427"; AGL=1.7; YAW=0; PITCH=0; HOUR=12; WEATHER=clear; ADMIN=""; NAME=""; OUT="$DEFOUT"; WAIT=""; SETTLE=""; DDIST=1.0
while [ $# -gt 0 ]; do
  case "$1" in
    --item) ITEM="$2"; HELD=1; shift 2;; --count) COUNT="$2"; shift 2;; --cam) CAM="$2"; CAM_GIVEN=1; shift 2;; --at) AT="$2"; AT_GIVEN=1; shift 2;;
    --angles) ANGLES="$2"; shift 2;; --no-ready) NOREADY=1; shift;;
    --agl) AGL="$2"; shift 2;; --yaw) YAW="$2"; YAW_GIVEN=1; shift 2;; --pitch) PITCH="$2"; shift 2;; --hour) HOUR="$2"; shift 2;;
    --weather) WEATHER="$2"; shift 2;; --admin) ADMIN="$ADMIN --shot-admin"; shift;; --flora) ADMIN="$ADMIN --shot-flora=$2"; shift 2;; --pieces) PIECES="$2"; ADMIN="$ADMIN --shot-pieces=$2"; shift 2;; --pieces-yaw) ADMIN="$ADMIN --shot-pieces-yaw=$2"; shift 2;; --piece-extra) ADMIN="$ADMIN --shot-piece-extra=$2"; shift 2;; --look) LOOKS="$2"; ADMIN="$ADMIN --shot-pieces=look:$2 --shot-piece-views"; shift 2;; --looks) LOOKS="$2"; ADMIN="$ADMIN --shot-pieces=look:${2//,/,look:}"; shift 2;; --piece-views) PIECES="$2"; ADMIN="$ADMIN --shot-pieces=$2 --shot-piece-views"; shift 2;; --showroom) ADMIN="$ADMIN --shot-showroom=$2"; shift 2;; --frametime) ADMIN="$ADMIN --shot-frametime=$2 --shot-build=$(git rev-parse --short HEAD 2>/dev/null)"; shift 2;; --quality) ADMIN="$ADMIN --shot-quality=$2"; shift 2;; --run) ADMIN="$ADMIN --shot-run=$2"; shift 2;; --views) ADMIN="$ADMIN --shot-views=$2"; shift 2;; --cam-above) ADMIN="$ADMIN --shot-cam-above=$2"; shift 2;; --flora-scale) ADMIN="$ADMIN --shot-flora-scale=$2"; shift 2;; --ground) GROUND="$2"; ADMIN="$ADMIN --shot-ground"; shift 2;; --showroom-cam-height) ADMIN="$ADMIN --shot-showroom-height=$2"; shift 2;; --showroom-look-down) ADMIN="$ADMIN --shot-showroom-look=$2"; shift 2;; --showroom-spread) ADMIN="$ADMIN --shot-showroom-spread"; shift;; --showroom-per) ADMIN="$ADMIN --shot-showroom-per=$2"; shift 2;; --gy) GY="$2"; shift 2;; --ground-close) GROUND="$2"; CLOSE=1; shift 2;; --close-height) CH="$2"; shift 2;; --close-dist) CD="$2"; shift 2;; --close-pitch) CP="$2"; shift 2;; --summer) ADMIN="$ADMIN --shot-summer"; shift;; --drop) ADMIN="$ADMIN --shot-drop"; shift;; --dig) ADMIN="$ADMIN --shot-dig=$2"; shift 2;; --heavy) ADMIN="$ADMIN --shot-heavy"; shift;; --look-down) ADMIN="$ADMIN --shot-lookdown=$2"; shift 2;; --back) ADMIN="$ADMIN --shot-back=$2"; shift 2;; --drop-dist) ADMIN="$ADMIN --shot-drop-dist=$2"; DDIST="$2"; shift 2;; --expect) EXPECT="$2"; shift 2;; --give) ADMIN="$ADMIN --shot-give=$2"; shift 2;; --skill) ADMIN="$ADMIN --shot-skill=$2"; shift 2;; --dist) ADMIN="$ADMIN --shot-dist=$2"; shift 2;; --nograss) ADMIN="$ADMIN --shot-nograss"; shift;; --bow) ADMIN="$ADMIN --shot-bow=$2"; shift 2;; --lit) ADMIN="$ADMIN --shot-lit"; shift;; --keep) KEEP=1; shift;; --keep) KEEP=1; shift;; --name) NAME="$2"; shift 2;; --out) OUT="$2"; shift 2;;
    --day) SARGS="$SARGS --game-day=$2"; shift 2;;
    --walk) WALKSPEED="$2"; shift 2;; --client-arg) XARGS="$XARGS $2"; shift 2;; --server-arg) SARGS="$SARGS $2"; shift 2;;
    --wait) WAIT="$2"; shift 2;; --settle) SETTLE="$2"; shift 2;; *) echo "unknown argument $1"; exit 2;;
  esac
done
case "$ADMIN" in *--shot-give=*) HELD=1;; esac
case "$ADMIN $GROUND" in *--shot-flora=*|*--shot-pieces=*|*--shot-showroom=*|*--shot-frametime=*|*--shot-views=*|*--shot-drop*|*--shot-dig=*|*--shot-ground*) SCENE=1;; esac
[ -n "$GROUND" ] && SCENE=1
[ -n "$ANGLES" ] && [ -z "$CAM_GIVEN" ] && CAM=right
[ -n "$ANGLES" ] && [ "$CAM" = "first" ] && echo "rig: WARNING --angles needs a third-person camera (--cam left or right); with --cam first it is ignored"
# --ground-close: the camera numbers are flags (--close-height, --close-dist, --close-pitch); later --agl/--drop-dist/--look-down still win.
if [ -n "$CLOSE" ]; then
  ADMIN="$ADMIN --shot-ground --shot-back=0 --shot-lookdown=$CP --shot-drop-dist=$CD"; DDIST="$CD"; AGL="$CH"
  echo "rig: ground close-up camera: height $CH m, distance $CD m, pitch $CP deg (flags --close-height --close-dist --close-pitch)"
fi
# Defaults changed on 24 Oct 2026: printed on every run so a before/after picture is not mistaken for a game change.
echo "rig defaults: --gy $GY (was 28.0 until 24 Oct; the spawn ground is 31.17 in the current world, 31.25 clears flat items, pass --gy 28 to repeat an old picture)"
# --piece-views NAME: one piece, four close views (front, side, top, diag) at 3 to 6 m, judged like the item views (one name per run).
#   --look NAME  one look straight from look_table.gd (plank_wall, crude_door_open, ...), four views like --piece-views; --looks a,b,c  a row of looks. Both need no structure.
# --pieces: refuse a name that is not a structures.json key before the scene starts (a typo costs seconds, not a launch).
if [ -n "$PIECES" ]; then
  KEYS=$(grep -oE '^		"[a-z_0-9]+": \{' data/items/structures.json | sed -E 's/^\s*"([a-z_0-9]+)".*/\1/' | tr '\n' ' ')
  IFS=',' read -ra WANT <<< "$PIECES"
  for P in "${WANT[@]}"; do
    case " $KEYS " in *" $P "*) ;; *) echo "no such piece: $P"; echo "valid pieces: $KEYS"; exit 2;; esac
  done
fi
# --look NAME / --looks a,b: a look straight from src/client/look_table.gd (no structure needed); refuse a name that is not a key there.
if [ -n "$LOOKS" ]; then
  LKEYS=$(grep -oE '^	"[a-z_0-9]+": \{"builder' src/client/look_table.gd | sed -E 's/^\s*"([a-z_0-9]+)".*/\1/' | tr '\n' ' ')
  IFS=',' read -ra WANTL <<< "$LOOKS"
  for L in "${WANTL[@]}"; do
    case " $LKEYS " in *" $L "*) ;; *) echo "no such look: $L"; echo "valid looks (src/client/look_table.gd): $LKEYS"; echo "a new look is one line in that file"; exit 2;; esac
  done
fi
[ -z "$NAME" ] && NAME="${ITEM:-empty}_${CAM}"
if [ -n "$WIN" ]; then WAIT="${WAIT:-25}"; SETTLE="${SETTLE:-12}"; else WAIT="${WAIT:-120}"; SETTLE="${SETTLE:-20}"; fi
X="${AT%,*}"; Z="${AT#*,}"
RIG=$(mktemp -d); STORE="$RIG/store"; mkdir -p "$RIG/home"; if [ -n "$WIN" ]; then UD="$RIG/appdata/Godot/app_userdata/Dynasty a life well lived"; else UD="$RIG/data/godot/app_userdata/Dynasty a life well lived"; fi
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
PORT=$((7800 + RANDOM % 150))
# The throwaway server gets the rig's own user folder too (Dave 17 Nov 2026: one wrote server_run.json into his, where Play reads it).
if [ -n "$WIN" ]; then SENV=(APPDATA="$(cygpath -w "$RIG/appdata")"); else SENV=(HOME="$RIG/home" XDG_DATA_HOME="$RIG/data"); fi
env "${SENV[@]}" "$GODOT" --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$STORE" --open-admin --quit-after=900 $SARGS > "$RIG/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; sleep 1; [ -z "$KEEP" ] && rm -rf "$RIG"; [ -n "$KEEP" ] && echo "rig kept: $RIG"' EXIT
# The server is ready when it says it listens (about 5 to 20 s), not after a fixed 30 s; its spawn is where the starter ground is, so a shot there needs no streaming.
for _ in $(seq 1 120); do grep -q "Terrain server listening" "$RIG/server.log" 2>/dev/null && break; kill -0 $SP 2>/dev/null || break; sleep 0.5; done
kill -0 $SP 2>/dev/null || { echo "FAIL: the throwaway server stopped (server.log below)"; tail -20 "$RIG/server.log" | cut -c1-200; exit 5; }
grep -q "Terrain server listening" "$RIG/server.log" || echo "rig: WARNING the server log has no listening line after $SECONDS s (output not flushed?); going on"
echo "rig: server ready after $SECONDS s"
SPAWN=$(grep -oE "spawn \(-?[0-9.]+, -?[0-9.]+, -?[0-9.]+\)" "$RIG/server.log" | head -1 | tr -d '(),' | awk '{print $2","$4}')
if [ -z "$AT_GIVEN" ] && [ -z "$GROUND" ] && [ -n "$SPAWN" ]; then
  X="${SPAWN%,*}"; Z="${SPAWN#*,}"; echo "rig: --at defaults to the server spawn $X,$Z"
fi
WALK=-1; [ "$CAM" = "left" ] && WALK=0; [ "$CAM" = "right" ] && { WALK=0; ADMIN="$ADMIN --shot-right"; }
[ -n "$WALKSPEED" ] && WALK="$WALKSPEED"
# A plain view at the spawn (no --at, --yaw, held item or scene row; --frametime is fine) faces the way a new character does: Edda and Hob's camp fire.
if [ -z "$AT_GIVEN" ] && [ -z "$YAW_GIVEN" ] && [ -z "$GROUND" ] && [ -z "$HELD" ]; then
  case "$ADMIN" in *--shot-flora=*|*--shot-pieces=*|*--shot-showroom=*|*--shot-views=*|*--shot-drop*|*--shot-dig=*|*--shot-ground*) ;;
    *) ADMIN="$ADMIN --shot-spawn-facing"; echo "rig: facing the way a new character at the spawn faces (the camp fire); pass --yaw to choose";; esac
fi
SHOT="$NAME:$X,$AGL,$Z,$YAW,$PITCH,$HOUR,$WEATHER,$WALK"
[ -n "$ANGLES" ] && ADMIN="$ADMIN --shot-angles=$ANGLES"
if [ -n "$HELD" ] && [ -z "$SCENE" ] && [ -z "$NOREADY" ]; then ADMIN="$ADMIN --shot-ready=held"; echo "rig: held-item shot: the picture is taken once the scene is ready (--wait $WAIT s, --settle $SETTLE s at most)"; fi
CSTART=$SECONDS
CARGS=(--server=127.0.0.1 --port=$PORT --shots="$SHOT" --shot-dir="$OUT" --shot-wait=$WAIT --shot-settle=$SETTLE $ADMIN $XARGS ${EXPECT:+"--shot-expect=$EXPECT"})
if [ -n "$WIN" ]; then
  APPDATA="$(cygpath -w "$RIG/appdata")" "$GODOT" --path . --resolution 1280x720 res://scenes/terrain_client/terrain_client.tscn -- "${CARGS[@]}" > "$RIG/client.log" 2>&1
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
echo "rig: client window open $((SECONDS - CSTART)) s"
grep -E "shot runner: (saved|timing|FAILED|--wait cap|--settle cap|.* starts at y|landed)|JOIN: ground ready|ERROR|SCRIPT" "$RIG/client.log" | head -14 | cut -c1-200
SAVED=$(grep -cE "shot runner: (saved |view .* saved |lapse .* saved|chop phase .* saved)" "$RIG/client.log")   # every picture the runner saves says so on one line
ls -la "$OUT/$NAME.png" 2>/dev/null | awk '{print $5, $9}'
# Shaders compile only in a windowed client, never in a headless gate, so this run is where a broken shader shows (#416: a '#'
# comment in GREENS_SHADER, "Unknown character #35 ... Shader compilation failed"). Any SHADER ERROR fails the rig run (exit 3).
SHADERR=$(grep -cE "SHADER ERROR|Shader compilation failed" "$RIG/client.log")
if [ "$SHADERR" -gt 0 ]; then
  echo "FAIL: $SHADERR shader error line(s) in the client log:"; grep -E -A3 "SHADER ERROR" "$RIG/client.log" | head -24 | cut -c1-200
  exit 3
fi
echo "shader errors: 0"
echo "rig: $SAVED picture(s) in $SECONDS s"
case "$ADMIN" in *--shot-frametime=*)
  FT=$(grep -m1 "shot runner: frametime" "$RIG/client.log")   # printed in full here: the temp folder (and its client.log) is deleted on exit without --keep
  if [ -z "$FT" ]; then echo "FAIL: --frametime gave no frametime line (client log tail below)"; tail -15 "$RIG/client.log" | cut -c1-200; exit 6; fi
  echo "$FT"
  case "$ADMIN" in *--shot-run=*)
    RAN=$(grep -m1 "shot runner: ran" "$RIG/client.log")
    if [ -z "$RAN" ]; then echo "FAIL: --run gave no ran line"; exit 6; fi
    echo "$RAN";;
  esac;;
esac
if [ "$SAVED" -eq 0 ]; then
  echo "FAIL: no picture was saved (client log tail below)"; tail -15 "$RIG/client.log" | cut -c1-200
  exit 4
fi
