#!/bin/bash
# Flying-over-new-ground stress test (headless): flies a route at a fixed height and counts missing ground colliders.
# usage: tools/hole_stress.sh route(east|south|diag) height speed seconds quality
# Reads the last "holes" line: cells missing at once, longest a cell stayed missing. Compare builds with the same arguments.
ROUTE=${1:-east}; ALT=${2:-300}; SPEED=${3:-60}; SECS=${4:-40}; Q=${5:-ultra}
PORT=$((7400 + RANDOM % 400)); D=$(mktemp -d /tmp/hole_XXXX); mkdir -p $D/store $D/cache
godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store=$D/store --quit-after=$((SECS + 150)) > $D/s.log 2>&1 &
SP=$!
sleep 25
timeout $((SECS + 200)) godot --headless --max-fps 30 --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --cache=$D/cache --quality=$Q --wait=40 --frames=$(( (SECS + 150) * 30 )) --fly --route=$ROUTE --move=$SPEED --flyalt=$ALT --flytime=$SECS --hole-probe > $D/c.log 2>&1
kill $SP 2>/dev/null
echo "== route $ROUTE height $ALT speed $SPEED m/s $SECS s $Q"
grep "hole probe" $D/c.log; grep "Terrain client: holes" $D/c.log | tail -1
