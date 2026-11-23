#!/bin/sh
# A server restarted with a player online (coordinator, 23 Nov 2026): the player's game is told why and shows it at once on its
# "connection lost" window (Retry / Back to servers), not 60 to 120 s later at the line's timeout. Runs a headless server and client here,
# writes stop.now (what run_server.sh does on docker stop) and checks the client's window shows NetScript.SERVER_CLOSING within 10 s.
#   tools/restart_notice_check.sh            (from the repository root, `godot` on PATH; GODOT overrides; PORT default 24900)
# Exit 0 shown in time, 1 not shown or late, 2 the run broke (no join).
GODOT=${GODOT:-godot}
PORT=${PORT:-24900}
D=$(mktemp -d /tmp/dynasty_restart_notice_XXXX)
mkdir -p "$D/store"
timeout 300 $GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$D/store" --quit-after=280 > "$D/server.log" 2>&1 &
SP=$!
sleep 15
XDG_DATA_HOME="$D/data" timeout 260 $GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_client/terrain_client.tscn -- \
	--server=127.0.0.1 --port=$PORT --block-port=$((PORT + 1)) --cache="$D/cache" --timeout=240 --lost-notice > "$D/client.log" 2>&1 &
CP=$!
joined=0

for i in $(seq 1 200); do
	grep -q "^Client .* connected" "$D/server.log" 2>/dev/null && { joined=1; break; }
	sleep 1
done

if [ $joined = 0 ]; then
	echo "restart notice: BROKEN the client never joined (logs in $D)"
	kill $SP $CP 2>/dev/null
	exit 2
fi

sleep 20
: > "$D/store/stop.now"
asked=$(date +%s)
code=1

for i in $(seq 1 10); do
	sleep 1

	if grep -q "connection lost notice shown: The server is restarting" "$D/client.log"; then
		code=0
		break
	fi
done

shown=$(( $(date +%s) - asked ))
wait $SP
kill $CP 2>/dev/null
wait $CP 2>/dev/null

if [ $code = 0 ]; then
	echo "restart notice: PASS the player was told within $shown s: $(grep -m1 'connection lost notice shown' "$D/client.log" | sed 's/.*shown: //')"
	rm -rf "$D"
else
	echo "restart notice: FAIL no restart notice on the player's screen within 10 s of the stop (logs in $D)"
fi

exit $code
