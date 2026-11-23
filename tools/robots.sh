#!/bin/bash
# usage: tools/robots.sh [ROBOTS] [PLAN] [link options...]
#   tools/robots.sh                       3 robots, plan first_hours, the default internet link (60 ms +- 25 each way, 2% loss)
#   tools/robots.sh 2 first_hours --delay-ms 75 --jitter-ms 30 --loss 0.03
# Robot play-testers (23 Nov 2026, after build 9257's first hour on Dave's server found faults no one-machine test saw).
# Starts a headless server with --robot-audit (src/server/robot_audit.gd) and --open-admin on a spare port, a simulated internet link in
# front of it (tools/lossy_link.py: delay, jitter, loss), and ROBOTS real clients (headless, dummy renderer) each run by
# src/client/robot_play.gd as a new player: craft twine, axe, hammer, spear, snare and knife, drop and pick up, walk every stance,
# crouch through the forest, hunt the nearest animal together, lie down and sleep, quit. Then each robot rejoins (plan rejoin) and
# checks its pack came back. tools/robot_check.py then reads every log and fails the run on any broken invariant.
# Run from the repository root; needs `godot` on PATH (GODOT=path overrides) and python3. Logs stay in the printed folder.
# Exit 0 = every invariant held; 1 = a FAIL (listed); 2 = the run itself broke (a robot never joined, the server died).
set -u
ROBOTS=${1:-3}; PLAN=${2:-first_hours}; shift $(( $# > 2 ? 2 : $# ))
LINK_ARGS=("$@"); [ ${#LINK_ARGS[@]} -eq 0 ] && LINK_ARGS=(--delay-ms 60 --jitter-ms 25 --loss 0.02)
GODOT=${GODOT:-godot}
ROBOT_S=${ROBOT_S:-420}   # one robot pass at most (the plan itself takes about 5 min)
cd "$(git rev-parse --show-toplevel)"
if [ ! -f .godot/global_script_class_cache.cfg ]; then echo "robots: importing once (about 1.5 min)"; $GODOT --headless --path . --import >/dev/null 2>&1; fi
PORT=$((21000 + RANDOM % 9000)); LINK=$((PORT + 10))
D=$(mktemp -d /tmp/robots_XXXX); mkdir -p "$D/store"
echo "robots: $ROBOTS robots, plan $PLAN, server port $PORT, link port $LINK, logs in $D"
$GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$D/store" \
	--quit-after=$(( ROBOT_S * 2 + 400 )) --open-admin --robot-audit > "$D/server.log" 2>&1 &
SP=$!
cleanup() { kill $LP 2>/dev/null; kill $SP 2>/dev/null; }
trap cleanup EXIT
for i in $(seq 1 120); do grep -q "^Terrain server listening" "$D/server.log" && break; kill -0 $SP 2>/dev/null || break; sleep 1; done
if ! grep -q "^Terrain server listening" "$D/server.log"; then echo "robots: the server never came up"; tail -20 "$D/server.log"; exit 2; fi
python3 tools/lossy_link.py --listen $LINK --server-port $PORT "${LINK_ARGS[@]}" > "$D/link.log" 2>&1 &
LP=$!
sleep 1

# One pass: every robot at once (they start at the same spawn, so they meet the same animals and see each other).
pass() {
	local plan=$1 tag=$2 pids=()
	for i in $(seq 1 $ROBOTS); do
		mkdir -p "$D/r$i/data" "$D/r$i/cache"
		XDG_DATA_HOME="$D/r$i/data" timeout $(( ROBOT_S + 60 )) $GODOT --headless --rendering-driver dummy --path . \
			res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$LINK --block-port=$((LINK + 1)) \
			--cache="$D/r$i/cache" --timeout=$ROBOT_S --robot=Robot_$i --robot-plan=$plan --robot-admin > "$D/robot${i}_$tag.log" 2>&1 &
		pids+=($!)
		sleep 2
	done
	wait "${pids[@]}"
}

START=$(date +%s)
pass "$PLAN" play
[ "$PLAN" = "first_hours" ] && { sleep 3; pass rejoin rejoin; }
echo "robots: passes took $(( $(date +%s) - START )) s"
kill $LP 2>/dev/null; sleep 1
kill $SP 2>/dev/null; sleep 3
python3 tools/robot_check.py "$D"
