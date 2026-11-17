#!/usr/bin/env bash
# Play's stop request against a real server (Dave 17 Nov 2026, PR #1223): starts a throwaway Play-style server (--quit-when-empty, own
# store, own user folder, so no real save or note is touched), then writes user://server_stop.json three ways:
#   A  naming another process          -> ignored, server stays up, note stays
#   B  naming it, from its own commit  -> note taken, server stays up (a request left behind)
#   C  naming it, from other code      -> server writes "closing", saves and exits; note and server_run.json gone
#   GODOT=/path/to/godot bash tools/play_stop_smoke.sh        (Git Bash on Windows or Linux; about 1 to 2 minutes)
set -u
# No --quit-after: a server with a set quit time does not look for stop requests (nor empties); the trap ends it.
GODOT="${GODOT:-godot}"
RIG=$(mktemp -d); mkdir -p "$RIG/store" "$RIG/home"
if [ -n "${WINDIR:-}" ] || [ "$(uname -o 2>/dev/null)" = Msys ]; then
  SENV=(APPDATA="$(cygpath -w "$RIG/appdata")"); UD="$RIG/appdata/Godot/app_userdata/Dynasty a life well lived"
else
  SENV=(HOME="$RIG/home" XDG_DATA_HOME="$RIG/data"); UD="$RIG/data/godot/app_userdata/Dynasty a life well lived"
fi
mkdir -p "$UD"
PORT=$((7950 + RANDOM % 140)); FAIL=0
ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; FAIL=1; }
env "${SENV[@]}" "$GODOT" --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$RIG/store" --quit-when-empty > "$RIG/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; sleep 1; rm -rf "$RIG"' EXIT
for _ in $(seq 1 240); do [ -f "$UD/server_run.json" ] && break; kill -0 $SP 2>/dev/null || break; sleep 0.5; done
[ -f "$UD/server_run.json" ] || { echo "FAIL no server_run.json (server.log tail below)"; tail -20 "$RIG/server.log" | cut -c1-200; exit 1; }
NOTE=$(cat "$UD/server_run.json"); echo "run note: $NOTE"
GPID=$(echo "$NOTE" | grep -oE '"pid": ?[0-9]+' | grep -oE '[0-9]+$'); COMMIT=$(echo "$NOTE" | grep -oE '"commit": ?"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')
echo "$NOTE" | grep -qE '"stop": ?1' && ok "a Play-style server says it obeys (stop 1)" || bad "run note has no stop 1"
STOP="$UD/server_stop.json"

echo "{\"pid\": $((GPID + 1)), \"commit\": \"zzzzzzz\"}" > "$STOP"; sleep 6
kill -0 $SP 2>/dev/null && [ -f "$STOP" ] && ok "A: a request naming another process is ignored" || bad "A: server gone or note taken"
rm -f "$STOP"

echo "{\"pid\": $GPID, \"commit\": \"$COMMIT\"}" > "$STOP"; sleep 6
kill -0 $SP 2>/dev/null && [ ! -f "$STOP" ] && ok "B: a request from its own commit is taken and ignored" || bad "B: server gone or note left"

echo "{\"pid\": $GPID, \"commit\": \"zzzzzzz\"}" > "$STOP"
T0=$SECONDS; CLOSING=0
while kill -0 $SP 2>/dev/null && [ $((SECONDS - T0)) -lt 60 ]; do grep -q '"closing"' "$UD/server_run.json" 2>/dev/null && CLOSING=1; sleep 0.25; done
kill -0 $SP 2>/dev/null && bad "C: server still up after 60 s" || ok "C: server closed after $((SECONDS - T0)) s"
grep -q "asked this server (commit $COMMIT) to close" "$RIG/server.log" && ok "C: the server logged the request" || bad "C: no request line in server.log"
[ ! -f "$STOP" ] && [ ! -f "$UD/server_run.json" ] && ok "C: stop note and run note gone" || bad "C: a note was left"
echo "C: closing seen in the run note while it saved: $CLOSING (may be 0 if it closed between looks)"
grep -E "shutdown|done;|EMPTY|QUIT" "$RIG/server.log" | head -5 | cut -c1-160
echo "play_stop_smoke: $([ $FAIL = 0 ] && echo ok || echo FAIL)"; exit $FAIL
