#!/bin/bash
# usage: tools/animal_net_probe.sh [SECONDS_PER_RUN]
# What a player sees of the animals over an internet-like connection, before and after protocol 154 (Dave 23 Nov 2026, the real server:
# animals "teleporting and jumping right through us"; docs/design/ANIMAL_NETCODE.md). One headless server on a spare port with its own
# throwaway store (never the live server, its container or its ports), then ONE protocol bot at a time (scenes/bot/bot_main.gd
# --probe-animals), joined through an in-process relay that adds delay, jitter and loss. Each run prints a PROBE line (frames over 0.5 m a
# minute, worst frame move, holes, turn rate and acceleration in the rows, state changes a minute) and a RELAY line. Light: one server, one
# bot, about 8 minutes. Run from the repository root; needs `godot` on PATH (GODOT= to override).
#   before: --old-throttle --old-draw (ENet's default throttle, the old drawing); after: neither.
SECS=${1:-90}
GODOT=${GODOT:-godot}
PORT=$((7800 + RANDOM % 300)); D=$(mktemp -d /tmp/animal_probe_XXXX); mkdir -p $D/store
$GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store=$D/store --quit-after=$(( 6 * (SECS + 30) + 120 )) --open-admin > $D/server.log 2>&1 &
SP=$!
sleep 40
run() {   # name, lag argument, extra flags
  $GODOT --headless --rendering-driver dummy --path . res://scenes/bot/bot_main.tscn -- --server=127.0.0.1 --port=$PORT --name=$1 --seconds=$SECS --stand-after=20 --spawn=deer,boar,elephant,moose --lag=$2 --probe-animals $3 > $D/$1.log 2>&1
  grep -h "^PROBE\|^RELAY\|^BOT" $D/$1.log
}
echo "== 60 ms, 30 ms jitter, no relay loss (ENet's own drops show as holes)"
run before_60ms "60,30,0" "--old-throttle --old-draw"
run after_60ms "60,30,0" ""
echo "== 60 ms, 30 ms jitter, 10% loss"
run before_loss10 "60,30,10" "--old-throttle --old-draw"
run after_loss10 "60,30,10" ""
echo "== 120 ms, 60 ms jitter, 20% loss"
run before_loss20 "120,60,20" "--old-throttle --old-draw"
run after_loss20 "120,60,20" ""
kill $SP 2>/dev/null; sleep 2
echo "logs in $D"
