#!/bin/bash
# usage: tools/bots.sh BOTS SECONDS [DIG_EVERY_S]
# Starts a headless server on a spare port and BOTS protocol-only players (scenes/bot) that walk, ask for ground and dig,
# then prints each bot's numbers and the server's worst frame gap. Run from the repository root; needs `godot` on PATH.
BOTS=${1:-10}; SECS=${2:-60}; DIG=${3:-0}
GODOT=${GODOT:-godot}
PORT=$((7400 + RANDOM % 400)); D=$(mktemp -d /tmp/bots_XXXX); mkdir -p $D/store
$GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store=$D/store --quit-after=$(( SECS + 120 )) --open-admin > $D/server.log 2>&1 &
SP=$!
sleep 40
for i in $(seq 1 $BOTS); do
  $GODOT --headless --rendering-driver dummy --path . res://scenes/bot/bot_main.tscn -- --server=127.0.0.1 --port=$PORT --name=b$i --seconds=$SECS --dig-every=$DIG > $D/bot$i.log 2>&1 &
  sleep 0.5
done
wait $(jobs -p | grep -v "^$SP$") 2>/dev/null
sleep 3
cat $D/bot*.log | grep "^BOT"
kill $SP 2>/dev/null; sleep 2
T=crash_reports/telemetry_server_$PORT.log
if [ -f $T ]; then echo "server worst frame gap: $(grep -o 'max gap [0-9]* ms' $T | awk '{print $3}' | sort -n | tail -1) ms over $(grep -c 'max gap' $T) seconds"; fi
echo "logs in $D"
