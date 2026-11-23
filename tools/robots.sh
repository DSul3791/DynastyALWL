#!/bin/bash
# usage: tools/robots.sh [ROBOTS] [PLAN] [link options...]
#   tools/robots.sh                       3 robots, plan first_hours, the default internet link (60 ms +- 25 each way, 2% loss)
#   tools/robots.sh 2 first_hours --delay-ms 75 --jitter-ms 30 --loss 0.03
#   tools/robots.sh 2 watch --delay-ms 120 --jitter-ms 30 --loss 0.03   Robot 1 walks, stops, swings, sleeps; Robot 2 draws it (robot_watch.py)
#   ROBOT_S=900 tools/robots.sh 1 route; ROBOT_S=900 ROBOT_CLIENT_ARGS=--quality=0 tools/robots.sh 1 route   the moving route (src/client/robot_play.gd _route) at Low quality
#   tools/robots.sh 1 screens             every screen a tester opens, every lit Craft button, a basket, then the rejoin pass
#   tools/robots.sh 1 drops               the link dies mid-action (6 twine queued, a basket open, asleep, in a wolf rush) and the robot comes
#                                         straight back; a 10 s freeze; two clients as one character (about 15 min)
#   ROBOT_S=400 tools/robots.sh 1 cold    a hard frost to 1 health, pass out, wake at a rescue spot; then goblin blows at health 1 (one robot only)
#   ROBOT_S=200 tools/robots.sh 1 fight_goblin|fight_bandit [link]   a charging foe: shield at the warning, side-steps, jabs
#   ROBOT_S=300 tools/robots.sh 3 bear | 3 bear_group | 2 wolves | 1 snares   (docs/ROBOT_PLAYTESTERS.md)
#   ROBOT_S=260 tools/robots.sh 2 kind_moose [link]   two robots hunt one animal kind; tools/robot_kinds.py <run folder> prints the measures
#   ROBOT_S=800 tools/robots.sh 2 together [link]   two robots on one basket, stack, crate site and door at once, a 20 s hold, one watching the other
# Robot play-testers (23 Nov 2026, after build 9257's first hour on Dave's server found faults no one-machine test saw).
# Starts a headless server with --robot-audit (src/server/robot_audit.gd) and --open-admin on a spare port, a simulated internet link in
# front of it (tools/lossy_link.py: delay, jitter, loss), and ROBOTS real clients (headless, dummy renderer) each run by
# src/client/robot_play.gd as a new player: craft twine, axe, hammer, spear, snare and knife, drop and pick up, walk every stance,
# crouch through the forest, hunt a rabbit, a deer and a wolf together, build a basket, eat and drink, lie down and sleep, quit. Then each robot rejoins (plan rejoin) and
# checks its pack came back. tools/robot_check.py then reads every log and fails the run on any broken invariant.
# Run from the repository root; needs `godot` on PATH (GODOT=path overrides) and python3. Logs stay in the printed folder.
# Exit 0 = every invariant held; 1 = a FAIL (listed); 2 = the run itself broke (a robot never joined, the server died).
set -u
ROBOTS=${1:-3}; PLAN=${2:-first_hours}; shift $(( $# > 2 ? 2 : $# ))
[ "$PLAN" = "cold" ] && ROBOTS=1   # the frost and the control file are for one robot
[ "$PLAN" = "together" ] && ROBOTS=2   # Robot 1 and Robot 2 each have their own part
LINK_ARGS=("$@"); [ ${#LINK_ARGS[@]} -eq 0 ] && LINK_ARGS=(--delay-ms 60 --jitter-ms 25 --loss 0.02)
GODOT=${GODOT:-godot}
ROBOT_S=${ROBOT_S:-600}   # one robot pass at most (first_hours takes about 7 min)
cd "$(git rev-parse --show-toplevel)"
# A fresh checkout has no import cache. The import can crash part way (seen 23 Nov 2026: a segfault left fonts and body models
# unimported, and every robot logged "Cannot open file" errors): try twice, and stop as a broken run if it never finishes.
if [ ! -f .godot/global_script_class_cache.cfg ] || [ ! -f .godot/robots_import_ok ]; then
	echo "robots: importing (about 1.5 min)"
	for try in 1 2; do $GODOT --headless --path . --import >/dev/null 2>&1 && { touch .godot/robots_import_ok; break; }; echo "robots: import try $try failed"; done
	[ -f .godot/robots_import_ok ] || { echo "robots: the import never finished"; exit 2; }
fi
PORT=$((21000 + RANDOM % 9000)); LINK=$((PORT + 10))
D=$(mktemp -d /tmp/robots_XXXX); mkdir -p "$D/store"
echo "robots: $ROBOTS robots, plan $PLAN, server port $PORT, link port $LINK, logs in $D"
ROBOT_SHARE="$D" $GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$D/store" \
	--quit-after=$(( ROBOT_S * 2 + 400 )) --open-admin --robot-audit > "$D/server.log" 2>&1 &
SP=$!
LP=""
# On exit or Ctrl-C: the link, the server and any robot client still running (each has --port=$LINK on its command line).
cleanup() { [ -n "$LP" ] && kill $LP 2>/dev/null; [ -n "$SP" ] && kill $SP 2>/dev/null; [ -n "${LINK:-}" ] && pkill -f -- "--port=$LINK " 2>/dev/null; }
trap cleanup EXIT
for i in $(seq 1 120); do grep -q "^Terrain server listening" "$D/server.log" && break; kill -0 $SP 2>/dev/null || break; sleep 1; done
if ! grep -q "^Terrain server listening" "$D/server.log"; then echo "robots: the server never came up"; tail -20 "$D/server.log"; exit 2; fi
python3 tools/lossy_link.py --listen $LINK --server-port $PORT --control "$D/link_control.txt" "${LINK_ARGS[@]}" > "$D/link.log" 2>&1 &
LP=$!
sleep 1

# One client: robot number i with plan, log tag, user data folder (its character) and cache.
launch() {
	local i=$1 plan=$2 tag=$3 data=$4 cache=$5
	mkdir -p "$data" "$cache"
	( XDG_DATA_HOME="$data" ROBOT_SHARE="$D" timeout $(( ROBOT_S + 60 )) $GODOT --headless --rendering-driver dummy --path . \
		res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$LINK --block-port=$((LINK + 1)) \
		--cache="$cache" --timeout=$ROBOT_S --robot=Robot_$i --robot-plan=$plan --robot-admin ${ROBOT_CLIENT_ARGS:-} > "$D/robot${i}_$tag.log" 2>&1
	  echo $? > "$D/robot${i}_$tag.exit" ) &   # the client's exit code: 0 after a clean quit (134 was the quit abort, fixed by #1647)
}

# One pass: every robot at once (they start at the same spawn, so they meet the same animals and see each other).
pass() {
	local plan=$1 tag=$2 pids=()
	for i in $(seq 1 $ROBOTS); do
		launch $i "$plan" "$tag" "$D/r$i/data" "$D/r$i/cache"
		pids+=($!)
		sleep 2
	done
	wait "${pids[@]}"
}

# Plan drops, one robot: each case cuts the link mid-action (lossy_link.py --control), then the same robot starts again at once, while the
# server may still hold the dead connection. If it cannot get in, once more after 35 s (the server's timeout for a dead peer).
drops() {
	ROBOTS=1
	for c in twine chest asleep; do
		pass drop_$c drop_$c
		pass drop_back back_$c
		if ! grep -q "step joined" "$D/robot1_back_$c.log"; then
			echo "FAIL robots: Robot 1 could not get back in at once after the link died ($c); again in 35 s" | tee -a "$D/robots_sh.log"
			sleep 35; pass drop_back back2_$c
		fi
	done
	pass drop_freeze freeze
	launch 1 drop_twin1 twin1 "$D/r1/data" "$D/r1/cache"; local p1=$!
	sleep 30
	launch 1 drop_twin2 twin2 "$D/r1/data" "$D/r1/cache2"; local p2=$!   # the same user data folder: the same character
	wait $p1 $p2
	# The wolf case last: its raw meat ages in the pack, and an ageing pack would read as changed in the freeze and twin checks.
	pass drop_wolf drop_wolf
	pass drop_back back_wolf
	grep -h "same character" "$D/server.log" | head -3
}

START=$(date +%s)
if [ "$PLAN" = "drops" ]; then drops; else pass "$PLAN" play; fi
{ [ "$PLAN" = "first_hours" ] || [ "$PLAN" = "screens" ]; } && { sleep 3; pass rejoin rejoin; }
echo "robots: passes took $(( $(date +%s) - START )) s"
kill $LP 2>/dev/null; sleep 1
kill $SP 2>/dev/null; sleep 3
python3 tools/robot_check.py "$D"; RC=$?
[ -f "$D/robots_sh.log" ] && grep -q "^FAIL" "$D/robots_sh.log" && [ $RC -eq 0 ] && RC=1   # drops: a robot that could not get back in at once
if [ "$PLAN" = "watch" ]; then python3 tools/robot_watch.py "$D"; WC=$?; [ $WC -gt $RC ] && RC=$WC; fi   # the worse of the two: 2 broken over 1 a finding
exit $RC
