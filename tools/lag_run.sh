#!/bin/bash
# usage: tools/lag_run.sh [extra client args...]
# The scripted early-game lag run (Dave 3 Nov 2026): a headless server on a spare port, then a real client (headless, dummy renderer)
# with --lag-run that logs in, walks 300 m, digs, chops a tree (it falls and splits into logs), hoes a path and drinks at the nearest
# water (src/client/lag_run.gd). Prints the per-step frame numbers, every HITCH and FREEZE line the probes printed, and the probe
# report's slowest frames. Runs in a cloud session (GODOT=path to the headless engine) or on the PC. Run from the repository root.
#   GODOT=~/bin/godot tools/lag_run.sh
#   GODOT=~/bin/godot tools/lag_run.sh --quality=2
# Headless frames carry no drawing cost, so the numbers are the scripts' and physics' share of a frame: a step that hitches here
# hitches on the PC too; one that is clean here can still hitch on the PC through the GPU.
GODOT=${GODOT:-godot}
# A fresh checkout has no import cache: class names are unknown and the client fails to parse. Import once.
if [ ! -f .godot/global_script_class_cache.cfg ]; then echo "lag_run: importing once (about 1.5 min)"; $GODOT --headless --path . --import >/dev/null 2>&1; fi
PORT=$((21000 + RANDOM % 18000)); D=$(mktemp -d /tmp/lagrun_XXXX); mkdir -p $D/store $D/cache
$GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store=$D/store --quit-after=900 --open-admin > $D/server.log 2>&1 &
SP=$!
sleep 40
timeout 800 $GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --cache=$D/cache --timeout=790 --lag-run "$@" > $D/client.log 2>&1
CODE=$?
kill $SP 2>/dev/null; sleep 2
echo "== lag run (client exit $CODE) =="
grep -E "^LAGRUN|^Chop test" $D/client.log
echo "== HITCH / FREEZE lines =="
grep -E "HITCH|FREEZE" $D/client.log | head -80
echo "($(grep -c HITCH $D/client.log) HITCH lines, $(grep -c FREEZE $D/client.log) FREEZE lines)"
echo "== script errors =="
grep -E "SCRIPT ERROR|ERROR:" $D/client.log | sort | uniq -c | sort -rn | head -10
echo "== shader errors =="
# A headless (dummy renderer) run compiles no shaders, so this is 0 there; run with a real renderer and it fails the run (#416).
SHADERR=$(grep -cE "SHADER ERROR|Shader compilation failed" $D/client.log); echo "($SHADERR shader error lines)"
grep -E -A3 "SHADER ERROR" $D/client.log | head -24
echo "== probe report =="
awk '/^frame probe|^Frame probe|^probe:/{p=1} p' $D/client.log | head -60
echo "logs in $D (a crash as the client quits, after LAGRUN done, is the engine tearing down; the run still counts)"
[ "$SHADERR" -eq 0 ] || { echo "FAIL: shader errors in the client log"; exit 3; }
grep -q "^LAGRUN done" $D/client.log
