#!/usr/bin/env bash
# A server with a password (docs/design/SERVER_PICK_PAGE.md, server_auth.gd): starts a throwaway server with DYNASTY_SERVER_PASSWORD set (own store,
# own user folder, so no real save or note is touched), then joins it as the testers' client would (--client-only, the address remembered):
#   C  the right password (--password=)  -> the server welcomes it
#   D  a wrong password                  -> refused before any welcome, "Wrong password", code 1
#   GODOT=/path/to/voxel/godot bash tools/join_password_smoke.sh   (Git Bash on Windows or Linux; about 2 to 3 minutes; the voxel build)
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
env "${SENV[@]}" DYNASTY_SERVER_PASSWORD=Hannibal "$GODOT" --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$RIG/store" > "$RIG/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; sleep 1; rm -rf "$RIG"' EXIT
for _ in $(seq 1 240); do grep -q '"pid"' "$UD/server_run.json" 2>/dev/null && break; kill -0 $SP 2>/dev/null || break; sleep 0.5; done
grep -q '"pid"' "$UD/server_run.json" 2>/dev/null || { echo "FAIL no server_run.json (server.log tail below)"; tail -20 "$RIG/server.log" | cut -c1-200; exit 1; }

grep -q "password: on" "$RIG/server.log" && ok "the server says its password is on" || bad "no 'password: on' in the server log"
printf '[join]\n\naddress="127.0.0.1:%d"\n' $PORT > "$UD/join_address.cfg"
env "${SENV[@]}" "$GODOT" --headless --path . -- --client-only --test --timeout=150 --password=Hannibal > "$RIG/client_c.log" 2>&1
grep -q "Terrain client: welcome after" "$RIG/client_c.log" && ok "C: the right password is welcomed" || bad "C: no welcome with the right password"
env "${SENV[@]}" "$GODOT" --headless --path . -- --client-only --test --timeout=150 --password=hannibal > "$RIG/client_d.log" 2>&1
CODE=$?
grep -q "Terrain client: join refused: The password was wrong" "$RIG/client_d.log" && ok "D: a wrong password is refused" || bad "D: no refusal line"
grep -q "Terrain client: welcome after" "$RIG/client_d.log" && bad "D: welcomed with a wrong password" || ok "D: no welcome"
[ $CODE -ne 0 ] && ok "D: code $CODE" || bad "D: code 0"
[ $FAIL = 0 ] || { echo "--- server tail"; tail -15 "$RIG/server.log" | cut -c1-200; echo "--- client_c tail"; tail -15 "$RIG/client_c.log" | cut -c1-200; echo "--- client_d tail"; tail -15 "$RIG/client_d.log" | cut -c1-200; }
echo "join_password_smoke: $([ $FAIL = 0 ] && echo ok || echo FAIL)"; exit $FAIL
