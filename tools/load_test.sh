#!/bin/bash
# Server load test (23 Nov 2026): a headless server and BOTS protocol-only players (scenes/bot/bot_swarm.tscn, 16 bots a process) that
# walk, dig, chop, craft, hunt and build, then a summary of how the server coped (tools/load_report.py): frame time and its worst spikes,
# which frame step grows, CPU, memory growth, traffic per player, block waits, and how long the closing save took.
#   tools/load_test.sh BOTS SECONDS [SPREAD_M] [OUT_DIR]
# SPREAD_M 0 (default) keeps every bot around the spawn; 2000 scatters them over a 2 km disc (more ground and flora to build).
# Env: GODOT (default godot), BOT_FLAGS (default "--work --fight --build --dig-every=5"), SERVER_FLAGS (extra server arguments),
# BOTS_PER_PROC (default 16). Run from the repository root. Never point it at a live server: it starts its own on a spare local port.
set -u
BOTS=${1:-8}; SECS=${2:-120}; SPREAD=${3:-0}; OUT=${4:-$(mktemp -d /tmp/load_XXXX)}
GODOT=${GODOT:-godot}; BOT_FLAGS=${BOT_FLAGS:---work --fight --build --dig-every=5}; PER=${BOTS_PER_PROC:-16}; SERVER_FLAGS=${SERVER_FLAGS:-}
PORT=$((7800 + RANDOM % 400)); mkdir -p "$OUT/store"
$GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$OUT/store" \
	--open-admin --profile=10 --timeout=$(( SECS + 400 )) $SERVER_FLAGS > "$OUT/server.log" 2>&1 &
SP=$!
trap 'kill $SP $PIDS 2>/dev/null' EXIT   # an aborted run leaves no server or swarm behind
trap 'exit 130' INT TERM
PIDS=""
for _ in $(seq 1 180); do grep -q "server listening on port" "$OUT/server.log" 2>/dev/null && break; kill -0 $SP 2>/dev/null || break; sleep 1; done
if ! grep -q "server listening on port $PORT" "$OUT/server.log" 2>/dev/null; then
	echo "load_test: the server did not start (see $OUT/server.log); no bots started" >&2
	exit 1
fi
sleep 5
# CPU (ticks) and resident memory of the server every 2 s, for load_report.py
( HZ=$(getconf CLK_TCK); while kill -0 $SP 2>/dev/null; do
	read -r -a st < /proc/$SP/stat 2>/dev/null || break
	echo "$(date +%s.%N) $(( ${st[13]} + ${st[14]} )) $HZ $(awk '/VmRSS/{print $2}' /proc/$SP/status) $(ls /proc/$SP/task | wc -l)"
	sleep 2; done ) > "$OUT/server_proc.txt" &
echo "load_test: server pid $SP port $PORT, $BOTS bots for $SECS s, spread $SPREAD m, out $OUT"
date +%s.%N > "$OUT/bots_start.txt"
FIRST=1
while [ $FIRST -le $BOTS ]; do
	N=$(( BOTS - FIRST + 1 )); [ $N -gt $PER ] && N=$PER
	$GODOT --headless --rendering-driver dummy --path . res://scenes/bot/bot_swarm.tscn -- --server=127.0.0.1 --port=$PORT --bots=$N --first=$FIRST \
		--stagger-ms=400 --seconds=$SECS --spread=$SPREAD --timeout=$(( SECS + 200 )) $BOT_FLAGS > "$OUT/swarm_$FIRST.log" 2>&1 &
	PIDS="$PIDS $!"; FIRST=$(( FIRST + N ))
done
wait $PIDS
date +%s.%N > "$OUT/bots_end.txt"
# the closing save: stop.now, as run_server.sh does on a stop signal
date +%s.%N > "$OUT/stop_asked.txt"; touch "$OUT/store/stop.now"
for _ in $(seq 1 300); do kill -0 $SP 2>/dev/null || break; sleep 0.5; done
date +%s.%N > "$OUT/server_gone.txt"
kill $SP 2>/dev/null
du -sk "$OUT/store" | awk '{print $1}' > "$OUT/store_kb.txt"
python3 tools/load_report.py "$OUT" "$BOTS" | tee "$OUT/report.txt"
