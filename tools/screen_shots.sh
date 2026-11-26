#!/bin/bash
# Screen pictures for eyes (coordinator 23 Nov 2026, "every screen on a tester's real setup"): the screen audit (--screenaudit, also run
# headless by tools/items_check.py) in a real window, saving one picture of every screen at every text size: the HUD, inventory, character
# (empty and with everything shown), the Journal index, goals and map, and every Esc menu page. A throwaway server and the client's own
# user folder, so Dave's game, saves and settings are never read or written. Runs beside his game. Each picture is the game's 1920x1080
# canvas (what the window shows, before it is scaled to the window; the bars of a screen that is not 16:9 are not in it), so for the
# window's own look at a size, look at the window while it runs.
#   tools/screen_shots.sh --size 0|1|2|3 [--out DIR]      windowed at a size the game offers: 0 1280x720, 1 1366x768, 2 1600x900, 3 1920x1080
#   tools/screen_shots.sh --fullscreen [--out DIR]        fullscreen windowed on this PC's screen (bars on a screen that is not 16:9)
# Prints the audit's own lines ("Screen audit: N problems on M screens", one line per problem) and one "picture ... saved" line per screen.
# FAIL (exit 4) when a picture fails, none is saved, there is a script error or the audit summary is missing. Layout problems the audit
# reports are printed, not a FAIL here (tools/items_check.py --only screenaudit is the gate for them).
cd "$(dirname "$0")/.." || exit 2
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1;; *) WIN="";; esac
if [ -n "$WIN" ]; then GODOT="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"; DEFOUT="C:/DynastyLane/logs/screens"; else GODOT="${GODOT_EXE:-godot}"; DEFOUT=/out/screens; fi
SIZE=3; FULL=false; OUT="$DEFOUT"
while [ $# -gt 0 ]; do
  case "$1" in
    --size) SIZE="$2"; shift 2;; --fullscreen) FULL=true; shift;; --out) OUT="$2"; shift 2;; *) echo "unknown argument $1"; exit 2;;
  esac
done
case "$SIZE" in 0|1|2|3) ;; *) echo "--size is 0 to 3"; exit 2;; esac
NAME="size$SIZE"; [ "$FULL" = true ] && NAME=fullscreen
OUT="$OUT/$NAME"; mkdir -p "$OUT" || { echo "FAIL: cannot make $OUT"; exit 2; }
RIG=$(mktemp -d); STORE="$RIG/store"; mkdir -p "$STORE" "$RIG/home"
if [ -n "$WIN" ]; then UD="$RIG/appdata/Godot/app_userdata/Dynasty a life well lived"; ENVV=(APPDATA="$(cygpath -w "$RIG/appdata")"); else UD="$RIG/data/godot/app_userdata/Dynasty a life well lived"; ENVV=(HOME="$RIG/home" XDG_DATA_HOME="$RIG/data"); fi
mkdir -p "$UD"
echo -n "00112233445566778899aabc" > "$UD/player_key.txt"
printf '[display]\n\nsize=%s\nfullscreen=%s\n' "$SIZE" "$FULL" > "$UD/display_settings.cfg"
PORT=$((7950 + RANDOM % 40))
env "${ENVV[@]}" "$GODOT" --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$STORE" --quit-after=900 > "$RIG/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; sleep 1; rm -rf "$RIG"' EXIT
for _ in $(seq 1 120); do grep -q "Terrain server listening" "$RIG/server.log" 2>/dev/null && break; kill -0 $SP 2>/dev/null || break; sleep 0.5; done
kill -0 $SP 2>/dev/null || { echo "FAIL: the throwaway server stopped"; tail -20 "$RIG/server.log" | cut -c1-200; exit 5; }
echo "screens: server ready; client window $NAME, pictures to $OUT"
env "${ENVV[@]}" "$GODOT" --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --frames=9000 --timeout=690 --screenaudit --screenshots="$OUT" > "$RIG/client.log" 2>&1
grep -E "Screen audit: [0-9]+ problems on|Screen audit:   |Screen audit self test: [0-9]|SCRIPT ERROR" "$RIG/client.log" | cut -c1-220
SAVED=$(grep -c "Screen audit: picture .* saved" "$RIG/client.log")
grep -m1 "Screen audit: picture" "$RIG/client.log" | cut -c1-200
echo "screens: $SAVED picture(s) saved in $OUT"
grep -q "Screen audit: [0-9]* problems on" "$RIG/client.log" || { echo "FAIL: no audit summary (client log tail below)"; tail -15 "$RIG/client.log" | cut -c1-200; exit 4; }
[ "$SAVED" -gt 0 ] || { echo "FAIL: no picture saved"; exit 4; }
FAILED=$(grep -c "Screen audit: picture .* FAILED" "$RIG/client.log"); ERRS=$(grep -c "SCRIPT ERROR" "$RIG/client.log")
[ "$FAILED" -eq 0 ] || { echo "FAIL: $FAILED picture(s) not saved"; exit 4; }
[ "$ERRS" -eq 0 ] || { echo "FAIL: $ERRS script error(s) in the client log"; exit 4; }
