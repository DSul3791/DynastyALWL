#!/usr/bin/env bash
# A stop signal saves a dedicated server (plan A4, Dave 18 Nov 2026). Before: kill -TERM ended the server at once, exit 143, nothing
# saved (David4, dev 6dedf7fe). Throwaway store and user folder, so no real save is touched. Two Godot processes at most at a time.
#   1  start deploy/server/run_server.sh ... --dedicated; its run note and telemetry log are in the store, not the user folder
#   2  a client joins (--resume-test=stay): 60 m from the spawn, then 90 m, and stays in
#   3  kill -TERM the wrapper: the server logs "stop asked", saves, and the wrapper exits 0; run note and stop.now gone
#   4  restart it on the same store; a client (--resume-test=check) starts about 90 m from the spawn: the save at the stop kept it
#   GODOT=/path/to/voxel/godot bash tools/dedicated_stop_smoke.sh   (Linux; about 5 to 10 minutes; the voxel build, as for world tests)
set -u
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-godot}"
RIG=$(mktemp -d); mkdir -p "$RIG/store" "$RIG/home"
export HOME="$RIG/home" XDG_DATA_HOME="$RIG/data"
UD="$RIG/data/godot/app_userdata/Dynasty a life well lived"; mkdir -p "$UD"
PORT=$((8100 + 2 * (RANDOM % 70))); FAIL=0; WP=0; CP=0
ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; FAIL=1; }
trap 'kill $CP $WP 2>/dev/null; sleep 1; pkill -KILL -f -- "--store=$RIG/store" 2>/dev/null; rm -rf "$RIG"' EXIT

serve() {   # $1 = log name
  deploy/server/run_server.sh "$GODOT" --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --dedicated --port=$PORT --store="$RIG/store" > "$RIG/$1" 2>&1 &
  WP=$!
  for _ in $(seq 1 480); do grep -q '"pid"' "$RIG/store/server_run.json" 2>/dev/null && return 0; kill -0 $WP 2>/dev/null || break; sleep 0.5; done
  echo "FAIL no server_run.json in the store ($1 tail below)"; tail -20 "$RIG/$1" | cut -c1-200; exit 1
}

client() {   # $1 = resume test, $2 = log name
  "$GODOT" --headless --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --resume-test="$1" --timeout=900 > "$RIG/$2" 2>&1 &
  CP=$!
}

wait_line() {   # $1 = pattern, $2 = log, $3 = seconds
  local t0=$SECONDS
  while [ $((SECONDS - t0)) -lt "$3" ]; do grep -q "$1" "$RIG/$2" 2>/dev/null && return 0; kill -0 $CP 2>/dev/null || break; sleep 1; done
  grep -q "$1" "$RIG/$2" 2>/dev/null
}

stop_server() {   # $1 = step name; TERM to the wrapper, as docker stop does
  local t0=$SECONDS code
  kill -TERM $WP
  while kill -0 $WP 2>/dev/null && [ $((SECONDS - t0)) -lt 90 ]; do sleep 0.5; done
  kill -0 $WP 2>/dev/null && { bad "$1: server still up 90 s after TERM"; return; }
  wait $WP; code=$?
  [ $code = 0 ] && ok "$1: wrapper exit 0 after TERM, $((SECONDS - t0)) s" || bad "$1: wrapper exit $code after TERM"
}

serve server1.log
grep -q "dedicated; admin check on, 0 admin keys" "$RIG/server1.log" && ok "1: dedicated, admin check on" || bad "1: no dedicated admin line"
[ ! -f "$UD/server_run.json" ] && ok "1: no run note in the user folder" || bad "1: run note in the user folder"
ls "$RIG/store/logs/telemetry_server_$PORT.log" > /dev/null 2>&1 && ok "1: telemetry log in <store>/logs" || bad "1: no telemetry log in <store>/logs"

client stay client1.log
wait_line "Resume test: staying in at" client1.log 600 && ok "2: $(grep -o 'Resume test: staying in at.*' "$RIG/client1.log")" || { bad "2: client never stayed in (tail below)"; tail -15 "$RIG/client1.log" | cut -c1-200; }
stop_server 3
grep -q "stop asked (stop.now); saving and closing with 1 players here" "$RIG/server1.log" && ok "3: the server took the stop with the player in" || bad "3: no 'stop asked' line with 1 player"
grep -q "server: done;" "$RIG/server1.log" && ok "3: clean close line" || bad "3: no 'server: done' line"
[ ! -f "$RIG/store/server_run.json" ] && [ ! -f "$RIG/store/stop.now" ] && ok "3: run note and stop.now gone" || bad "3: a note was left"
kill $CP 2>/dev/null; sleep 2

serve server2.log
client check client2.log
if wait_line "Resume test: started" client2.log 600; then
  LINE=$(grep -o 'Resume test: started.*' "$RIG/client2.log"); M=$(echo "$LINE" | grep -oE 'started [0-9]+' | grep -oE '[0-9]+')
  [ "$M" -ge 80 ] && [ "$M" -le 100 ] && ok "4: $LINE" || bad "4: $LINE (expected about 90 m)"
else
  bad "4: the check client never started (tail below)"; tail -15 "$RIG/client2.log" | cut -c1-200
fi
stop_server 4
grep -E "stop asked|shutdown|done;|EXIT|run_server" "$RIG/server1.log" | head -8 | cut -c1-160
echo "dedicated_stop_smoke: $([ $FAIL = 0 ] && echo ok || echo FAIL)"; exit $FAIL
