#!/usr/bin/env bash
# A tester's way in when it goes wrong (coordinator, 23 Nov 2026): each case must end with a plain reason the game shows on its joining
# window (headless: on the console), never a silent wait. Runs a throwaway server for one player (own store, own user
# folder, so no real save or note is touched) and the testers' client (--client-only, the address remembered):
#   C  a ground cache whose files are damaged   -> the game still joins and lands
#   F  a second player on a full server   -> "join refused: The server is full", soon; the player in stays; the same character back is let in
#   N  an address with a name that does not exist   -> "cannot reach", within 60 s
#   D  an address with no server on it   -> "No server answered", within 60 s
#   E  no address at all   -> "no server address yet", at once
# The other cases have their own checks: versions both ways tools/cross_version_check.sh, a restart tools/restart_notice_check.sh, a wrong
# password tools/join_password_smoke.sh; a drop during the load and a slow join are the join window's (test_way_in.gd).
#   GODOT=godot bash tools/way_in_check.sh      (Git Bash on Windows or Linux; about 2 to 4 minutes)
set -u
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-godot}"
RIG=$(mktemp -d); mkdir -p "$RIG/store"
FAIL=0
ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; FAIL=1; }
# Each client gets its own user folder (two copies in one folder would share a character and a ground cache).
user_env() {   # $1 = name; sets ENVV and UD
  mkdir -p "$RIG/$1/home"
  if [ -n "${WINDIR:-}" ] || [ "$(uname -o 2>/dev/null)" = Msys ]; then
    ENVV=(APPDATA="$(cygpath -w "$RIG/$1/appdata")"); UD="$RIG/$1/appdata/Godot/app_userdata/Dynasty a life well lived"
  else
    ENVV=(HOME="$RIG/$1/home" XDG_DATA_HOME="$RIG/$1/data"); UD="$RIG/$1/data/godot/app_userdata/Dynasty a life well lived"
  fi
  mkdir -p "$UD"
}
client() {   # $1 = name, $2 = address or "", $3 = timeout s, more = extra client flags; runs in the foreground, sets CODE and TOOK
  local name="$1" address="$2" limit="$3"; shift 3
  user_env "$name"
  [ -n "$address" ] && printf '[join]\n\naddress="%s"\n' "$address" > "$UD/join_address.cfg"
  local t0=$SECONDS
  env "${ENVV[@]}" "$GODOT" --headless --path . -- --client-only --test --timeout="$limit" "$@" > "$RIG/$name.log" 2>&1
  CODE=$?; TOOK=$((SECONDS - t0))
}
PORT=$((8100 + RANDOM % 140)); EMPTY=$((PORT + 300))
user_env server
env "${ENVV[@]}" "$GODOT" --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$RIG/store" --max-players=1 > "$RIG/server.log" 2>&1 &
SP=$!; C1=""
trap 'kill $SP $C1 2>/dev/null; sleep 1; rm -rf "$RIG"' EXIT
for _ in $(seq 1 240); do grep -q '"pid"' "$UD/server_run.json" 2>/dev/null && break; kill -0 $SP 2>/dev/null || break; sleep 0.5; done
grep -q '"pid"' "$UD/server_run.json" 2>/dev/null || { echo "FAIL no server (server.log tail below)"; tail -20 "$RIG/server.log" | cut -c1-200; exit 2; }

# C first: the server takes one player, and a killed game's seat stays taken until its line times out.
client cache_fill "127.0.0.1:$PORT" 90 --cache="$RIG/cache"
grep -q "JOIN: ground ready\|Terrain client: welcome after" "$RIG/cache_fill.log" && ok "C: a first join fills the ground cache ($(find "$RIG/cache" -type f | wc -l) files)" || bad "C: the first join did not get in"
for f in $(find "$RIG/cache" -type f); do head -c 4096 /dev/urandom > "$f"; done
client cache_bad "127.0.0.1:$PORT" 90 --cache="$RIG/cache"
grep -q "Terrain client: welcome after" "$RIG/cache_bad.log" && ok "C: with every cache file damaged the game still joins" || bad "C: no welcome with a damaged cache"
grep -q "JOIN: ground ready" "$RIG/cache_bad.log" && ok "C: and lands on the ground" || bad "C: no ground ready with a damaged cache"
grep -qE "SCRIPT ERROR|Segmentation|signal 11|CrashHandler" "$RIG/cache_bad.log" && bad "C: an error or crash with a damaged cache" || ok "C: no script error or crash"
sleep 3

user_env first; FIRST_UD="$UD"
printf '[join]\n\naddress="127.0.0.1:%d"\n' $PORT > "$UD/join_address.cfg"
env "${ENVV[@]}" "$GODOT" --headless --path . -- --client-only --test --timeout=240 > "$RIG/first.log" 2>&1 &
C1=$!
for _ in $(seq 1 240); do grep -q "Terrain client: welcome after" "$RIG/first.log" 2>/dev/null && break; kill -0 $C1 2>/dev/null || break; sleep 0.5; done
grep -q "Terrain client: welcome after" "$RIG/first.log" && ok "F: the first player is in" || bad "F: the first player got no welcome"
client second "127.0.0.1:$PORT" 150
grep -q "join refused: The server is full" "$RIG/second.log" && ok "F: the second player is told the server is full" || bad "F: no 'server is full' refusal"
[ $CODE -ne 0 ] && [ $TOOK -lt 90 ] && ok "F: the refused game ended (code $CODE) after $TOOK s" || bad "F: code $CODE after $TOOK s"
for _ in $(seq 1 120); do grep -q "JOIN: ground ready" "$RIG/first.log" 2>/dev/null && break; kill -0 $C1 2>/dev/null || break; sleep 0.5; done
grep -q "join refused" "$RIG/first.log" && bad "F: the player already in was refused: $(grep -m1 'join refused' "$RIG/first.log" | cut -c1-120)" || ok "F: the player already in was not refused"
grep -q "JOIN: ground ready" "$RIG/first.log" && ok "F: and stands on the ground" || bad "F: the player already in never got the ground"
# The same character coming back (a crashed game, a second window) while the server is full is let in; its old connection is dropped.
user_env again; cp "$FIRST_UD/player_key.txt" "$UD/" 2>/dev/null
printf '[join]\n\naddress="127.0.0.1:%d"\n' $PORT > "$UD/join_address.cfg"
env "${ENVV[@]}" "$GODOT" --headless --path . -- --client-only --test --timeout=120 > "$RIG/again.log" 2>&1
[ -f "$UD/player_key.txt" ] || bad "F: the first player left no character key to come back with"
grep -q "join refused: The server is full" "$RIG/again.log" && bad "F: the same character coming back was told the server is full" || ok "F: the same character coming back was not told the server is full"
grep -q "Terrain client: welcome after" "$RIG/again.log" && ok "F: and joined" || bad "F: the same character coming back got no welcome"
kill $C1 2>/dev/null; C1=""

client name "nosuch-dynasty-server.invalid:24600" 150
grep -q "cannot reach the server" "$RIG/name.log" && ok "N: a name that does not exist: $(grep -o 'cannot reach the server: .\{0,70\}' "$RIG/name.log" | head -1)" || bad "N: no cannot-reach reason"
[ $TOOK -lt 90 ] && ok "N: ended after $TOOK s" || bad "N: took $TOOK s"

client down "127.0.0.1:$EMPTY" 150
grep -q "cannot reach the server: No server answered" "$RIG/down.log" && ok "D: no server at the address: No server answered" || bad "D: no 'No server answered' reason"
[ $TOOK -lt 90 ] && ok "D: ended after $TOOK s" || bad "D: took $TOOK s"

client empty "" 60
grep -q "cannot reach the server: This game has no server address yet" "$RIG/empty.log" && ok "E: no address: told to choose a server" || bad "E: no 'no server address' reason"
[ $TOOK -lt 60 ] && ok "E: ended after $TOOK s" || bad "E: took $TOOK s"

[ $FAIL = 0 ] || for f in cache_fill cache_bad second name down empty; do echo "--- $f tail"; tail -8 "$RIG/$f.log" | cut -c1-200; done
echo "way_in_check: $([ $FAIL = 0 ] && echo ok || echo FAIL)"; exit $FAIL
