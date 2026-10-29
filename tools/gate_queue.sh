#!/bin/bash
# Gate queue on the box: one entry per branch, the newest hash wins, up to 4 gates at once.
#   tools/gate_queue.sh submit <branch> <40-char hash>   queue it (replaces a queued entry of that branch; stops a running gate of that branch)
#   tools/gate_queue.sh work                              dispatcher loop: starts queued gates in free clones, oldest first (run once, in the background)
#   tools/gate_queue.sh status                            what is queued and running
# Files: $GATE_ROOT/queue/<branch with / as _>.req (hash), $GATE_ROOT/running/<branch>.pid + .hash. /out/PAUSE stops new gates from starting.
ROOT="${GATE_ROOT:-/out/gate}"; MAX="${GATE_MAX:-4}"; HERE="$(cd "$(dirname "$0")" && pwd)"
Q="$ROOT/queue"; R="$ROOT/running"; mkdir -p "$Q" "$R"
key() { echo "$1" | tr '/' '_'; }
case "$1" in
submit)
	B="$2"; H="$3"; [[ "$H" =~ ^[0-9a-f]{40}$ ]] || { echo "need a 40-char hash"; exit 2; }
	K=$(key "$B"); echo "$H" > "$Q/$K.req.tmp" && mv "$Q/$K.req.tmp" "$Q/$K.req"
	if [ -f "$R/$K.pid" ] && [ "$(cat "$R/$K.hash" 2>/dev/null)" != "$H" ]; then
		kill -- "-$(cat "$R/$K.pid")" 2>/dev/null || kill "$(cat "$R/$K.pid")" 2>/dev/null
		echo "stopped the running gate of $B ($(cut -c1-8 "$R/$K.hash")), queued $(echo $H | cut -c1-8)"
	else echo "queued $B $(echo $H | cut -c1-8)"; fi;;
status)
	for f in "$R"/*.pid; do [ -f "$f" ] || continue; k=$(basename "$f" .pid); kill -0 "$(cat "$f")" 2>/dev/null && echo "running $k $(cut -c1-8 "$R/$k.hash")"; done
	for f in "$Q"/*.req; do [ -f "$f" ] && echo "queued  $(basename "$f" .req) $(cut -c1-8 "$f")"; done; true;;
work)
	exec 8>"$ROOT/dispatcher.lock"; flock -n 8 || { echo "dispatcher already running"; exit 0; }
	while :; do
		RUN=0; for f in "$R"/*.pid; do [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null && RUN=$((RUN + 1)); done
		NEXT=$(ls -tr "$Q"/*.req 2>/dev/null | head -1)
		if [ -n "$NEXT" ] && [ "$RUN" -lt "$MAX" ] && [ ! -e /out/PAUSE ]; then
			K=$(basename "$NEXT" .req); H=$(cat "$NEXT"); rm -f "$NEXT"
			# jobs per gate: 4 with one gate going, 2 when several share the box
			J=4; [ "$RUN" -ge 1 ] && J=2
			setsid bash -c 'echo $$ > "$1/$2.pid"; echo "$3" > "$1/$2.hash"; bash "$4/gate.sh" "$3" --lane fast --jobs "$5" --base origin/main >/dev/null 2>&1; rm -f "$1/$2.pid"' _ "$R" "$K" "$H" "$HERE" "$J" &
			sleep 3; continue
		fi
		sleep 10
	done;;
*) sed -n 2,7p "$0"; exit 2;;
esac
