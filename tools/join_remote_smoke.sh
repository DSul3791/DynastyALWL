#!/usr/bin/env bash
# A client-only build joining a server it did not start (server/client split step A2, join_address.gd): starts a throwaway server (own store,
# own user folder, so no real save or note is touched), then runs the game as the testers' client would (--client-only, role play, no --server=),
# with the join address remembered in its user folder:
#   A  address of the running server  -> joins it and gets the welcome; no local server is started
#   B  address with no server on it   -> gives up within about 30 s with code 1 ("connection failed"); no local server is started
#   GODOT=/path/to/voxel/godot bash tools/join_remote_smoke.sh   (Git Bash on Windows or Linux; about 2 to 4 minutes; the voxel build, as for world tests)
set -u
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-godot}"
RIG=$(mktemp -d); mkdir -p "$RIG/store" "$RIG/home"
if [ -n "${WINDIR:-}" ] || [ "$(uname -o 2>/dev/null)" = Msys ]; then
  SENV=(APPDATA="$(cygpath -w "$RIG/appdata")"); UD="$RIG/appdata/Godot/app_userdata/Dynasty a life well lived"
else
  SENV=(HOME="$RIG/home" XDG_DATA_HOME="$RIG/data"); UD="$RIG/data/godot/app_userdata/Dynasty a life well lived"
fi
mkdir -p "$UD"
PORT=$((7950 + RANDOM % 140)); EMPTY=$((PORT + 200)); FAIL=0
ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; FAIL=1; }
env "${SENV[@]}" "$GODOT" --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$RIG/store" > "$RIG/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; sleep 1; rm -rf "$RIG"' EXIT
for _ in $(seq 1 240); do grep -q '"pid"' "$UD/server_run.json" 2>/dev/null && break; kill -0 $SP 2>/dev/null || break; sleep 0.5; done
grep -q '"pid"' "$UD/server_run.json" 2>/dev/null || { echo "FAIL no server_run.json (server.log tail below)"; tail -20 "$RIG/server.log" | cut -c1-200; exit 1; }

printf '[join]\n\naddress="127.0.0.1:%d"\n' $PORT > "$UD/join_address.cfg"
env "${SENV[@]}" "$GODOT" --headless --path . -- --client-only --test --timeout=150 > "$RIG/client_a.log" 2>&1
grep -q "connecting to 127.0.0.1:$PORT" "$RIG/client_a.log" && ok "A: the client used the remembered address" || bad "A: no connecting line for port $PORT"
grep -q "Terrain client: welcome after" "$RIG/client_a.log" && ok "A: the server welcomed it" || bad "A: no welcome"
grep -q "Play: started the terrain server" "$RIG/client_a.log" && bad "A: a local server was started" || ok "A: no local server started"

printf '[join]\n\naddress="127.0.0.1:%d"\n' $EMPTY > "$UD/join_address.cfg"
T0=$SECONDS
env "${SENV[@]}" "$GODOT" --headless --path . -- --client-only --test --timeout=150 > "$RIG/client_b.log" 2>&1
CODE=$?; TOOK=$((SECONDS - T0))
grep -q "connecting to 127.0.0.1:$EMPTY" "$RIG/client_b.log" && grep -q "Terrain client: connection failed" "$RIG/client_b.log" && ok "B: no server at the address: connection failed" || bad "B: no connecting/failed lines"
[ $CODE -ne 0 ] && [ $TOOK -lt 120 ] && ok "B: gave up with code $CODE after $TOOK s" || bad "B: code $CODE after $TOOK s"
grep -q "Play: started the terrain server" "$RIG/client_b.log" && bad "B: a local server was started" || ok "B: no local server started"
[ $FAIL = 0 ] || { echo "--- client_a tail"; tail -15 "$RIG/client_a.log" | cut -c1-200; echo "--- client_b tail"; tail -15 "$RIG/client_b.log" | cut -c1-200; }
echo "join_remote_smoke: $([ $FAIL = 0 ] && echo ok || echo FAIL)"; exit $FAIL
