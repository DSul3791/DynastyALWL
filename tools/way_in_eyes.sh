#!/bin/bash
# A tester's way in on a real Windows PC (coordinator, 23 Nov 2026): the cases tools/way_in_check.sh cannot see headless, in a real window,
# unattended. A throwaway server and throwaway user folders, so Dave's game, saves and settings are never read or written. Every window it opens
# is closed by the script (each has its own time limit as well).
#   A  no sound device (--audio-driver Dummy)            -> joins, lands, no script error
#   G  the OpenGL renderer (what Godot falls back to when Vulkan fails; --rendering-driver opengl3), pictures of every screen
#   X  the D3D12 renderer (project.godot's Vulkan fallback on Windows)
#   S  a second copy started while one is open           -> "Dynasty is already open" asked
#   F  a full server, in a window                        -> refused with the reason, and the window waits on Back to servers / Quit
#   tools/way_in_eyes.sh [--out DIR]      (Git Bash from the clone's root; about 10 to 15 minutes; the windows must not be minimised)
# Prints one "ok" or "FAIL" line per check and "way_in_eyes: ok|FAIL"; exit 0 all ok, 1 a check failed, 2 the run broke.
cd "$(dirname "$0")/.." || exit 2
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1;; *) WIN="";; esac
if [ -n "$WIN" ]; then GODOT="${GODOT_EXE:-C:/GodotInstaller/godot.windows.editor.x86_64.exe}"; OUT="E:/Software/godotDev/DynastyALWL_Evidence/way_in"; else GODOT="${GODOT_EXE:-godot}"; OUT=/out/way_in; fi
[ "${1:-}" = "--out" ] && OUT="$2"
mkdir -p "$OUT" || { echo "FAIL: cannot make $OUT"; exit 2; }
RIG=$(mktemp -d); FAIL=0; PIDS=""
ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; FAIL=1; }
trap 'kill $PIDS 2>/dev/null; sleep 1; cp "$RIG"/*.log "$OUT"/ 2>/dev/null; rm -rf "$RIG"' EXIT
user_env() {   # $1 = name; sets ENVV and UD
  if [ -n "$WIN" ]; then UD="$RIG/$1/appdata/Godot/app_userdata/Dynasty a life well lived"; ENVV=(APPDATA="$(cygpath -w "$RIG/$1/appdata")")
  else UD="$RIG/$1/data/godot/app_userdata/Dynasty a life well lived"; ENVV=(HOME="$RIG/$1/home" XDG_DATA_HOME="$RIG/$1/data"); mkdir -p "$RIG/$1/home"; fi
  mkdir -p "$UD"; printf '%024x' $((RANDOM * 32768 + RANDOM)) > "$UD/player_key.txt"
}
server() {   # $1 = name, more = server flags; sets PORT
  local last="${PORT:-0}"; PORT=$((7990 + RANDOM % 40)); [ "$PORT" = "$last" ] && PORT=$((PORT + 41)); user_env "srv_$1"; mkdir -p "$RIG/store_$1"
  env "${ENVV[@]}" timeout 1200 "$GODOT" --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$RIG/store_$1" "${@:2}" > "$RIG/server_$1.log" 2>&1 &
  SP=$!; PIDS="$PIDS $SP"
  for _ in $(seq 1 240); do grep -q "Terrain server listening" "$RIG/server_$1.log" 2>/dev/null && return 0; kill -0 $SP 2>/dev/null || break; sleep 0.5; done
  echo "FAIL: the throwaway server stopped"; tail -10 "$RIG/server_$1.log" | cut -c1-200; exit 2
}
window() {   # $1 = name, $2 = time limit s, more = Godot flags before "--" then game flags; in the foreground
  local name="$1" limit="$2"; shift 2
  user_env "$name"
  env "${ENVV[@]}" timeout "$limit" "$GODOT" --path . "$@" > "$RIG/$name.log" 2>&1
}
joined() {   # $1 = name, $2 = label
  grep -q "Terrain client: welcome after" "$RIG/$1.log" && ok "$2: joined" || bad "$2: no welcome"
  grep -q "JOIN: ground ready" "$RIG/$1.log" && ok "$2: landed on the ground" || bad "$2: no ground ready"
  grep -qE "SCRIPT ERROR|CrashHandler|signal 11" "$RIG/$1.log" && bad "$2: a script error or crash: $(grep -m1 -E 'SCRIPT ERROR|CrashHandler' "$RIG/$1.log" | cut -c1-140)" || ok "$2: no script error or crash"
}

server main --quit-after=1500
CLIENT=(res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT)

window sound 300 --audio-driver Dummy "${CLIENT[@]}" --frames=2400 --timeout=240
joined sound "A no sound device"

window opengl 800 --rendering-driver opengl3 "${CLIENT[@]}" --frames=9000 --timeout=690 --screenaudit --screenshots="$OUT/opengl3"
grep -qi "OpenGL API" "$RIG/opengl.log" && ok "G: ran on $(grep -m1 -io 'OpenGL API [^ ]* [^ ]*' "$RIG/opengl.log")" || bad "G: no OpenGL line (did it start on OpenGL?)"
joined opengl "G OpenGL"
echo "G: $(grep -c 'Screen audit: picture .* saved' "$RIG/opengl.log") picture(s) saved in $OUT/opengl3; $(grep -m1 -o 'Screen audit: [0-9]* problems on [0-9]* screens' "$RIG/opengl.log")"

window d3d12 300 --rendering-driver d3d12 "${CLIENT[@]}" --frames=2400 --timeout=240
grep -qi "D3D12" "$RIG/d3d12.log" && ok "X: ran on D3D12" || bad "X: no D3D12 line (did it start on D3D12?)"
joined d3d12 "X D3D12"

# S: the first copy opens the title page and waits; the second, from the same user folder, must ask.
user_env copy; COPY=("${ENVV[@]}")
env "${COPY[@]}" timeout 240 "$GODOT" --path . -- --client-only > "$RIG/copy_first.log" 2>&1 &
C1=$!; PIDS="$PIDS $C1"
for _ in $(seq 1 240); do [ -f "$UD/game_open.json" ] && break; kill -0 $C1 2>/dev/null || break; sleep 0.5; done
[ -f "$UD/game_open.json" ] && ok "S: the first copy keeps its note" || bad "S: the first copy wrote no game_open.json"
env "${COPY[@]}" timeout 45 "$GODOT" --path . -- --client-only > "$RIG/copy_second.log" 2>&1
grep -q "Launcher: another copy of the game is open" "$RIG/copy_second.log" && ok "S: the second copy asked 'Dynasty is already open'" || bad "S: the second copy did not ask"
kill $C1 2>/dev/null

# F: one headless player fills a one-player server; a window that joins is refused and keeps its window up.
kill $SP 2>/dev/null; server full --max-players=1 --quit-after=400
user_env full_first
env "${ENVV[@]}" timeout 300 "$GODOT" --headless --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --frames=99999 --timeout=280 > "$RIG/full_first.log" 2>&1 &
C2=$!; PIDS="$PIDS $C2"
for _ in $(seq 1 240); do grep -q "Terrain client: welcome after" "$RIG/full_first.log" 2>/dev/null && break; sleep 0.5; done
T0=$SECONDS
window full 60 res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --timeout=55
grep -q "join refused: The server is full" "$RIG/full.log" && ok "F: the window was told the server is full" || bad "F: no 'server is full' refusal"
[ $((SECONDS - T0)) -ge 50 ] && grep -q "join refused" "$RIG/full.log" && ! grep -q "JOIN: ground ready" "$RIG/full.log" && ok "F: and waited on its window (closed by the time limit), no ground loaded" || bad "F: the refused window did not stop at its window"
kill $C2 2>/dev/null

echo "way_in_eyes: logs in $OUT; $([ $FAIL = 0 ] && echo ok || echo FAIL)"
exit $FAIL
