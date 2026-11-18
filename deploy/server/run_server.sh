#!/bin/sh
# Runs a Dynasty server so that a stop signal saves the world (plan A4, Dave 18 Nov 2026). Godot dies at once on TERM (exit 143,
# nothing saved: David4, 18 Nov 2026), and `docker stop` sends TERM. This script takes TERM, INT and HUP itself, writes stop.now
# in the server's store (the server then closes the normal way: spots noted, everything saved, exit 0) and exits with the server's code.
#   deploy/server/run_server.sh <server command ... --store=DIR ...>
#   e.g. deploy/server/run_server.sh godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --dedicated --store=/data/store
# The server itself never sees the signal (it is started with them ignored), so only this script's process should be signalled.
# A server that does not close inside the stop grace (docker: --stop-timeout) is killed by docker and loses what was unsaved.
store=""

for arg in "$@"; do
  case "$arg" in --store=*) store="${arg#--store=}" ;; esac
done

if [ -z "$store" ]; then
  echo "run_server: the server command needs --store=DIR (stop.now is written there)" >&2
  exit 2
fi

mkdir -p "$store" || exit 2
ask_stop() {
  echo "run_server: stop signal; asking the server to save and close" >&2
  : > "$store/stop.now"
}
trap ask_stop TERM INT HUP
(trap '' TERM INT HUP; exec "$@") &
child=$!

while :; do
  wait "$child"
  code=$?
  kill -0 "$child" 2>/dev/null || break   # still there: the wait was cut short by a signal, and the server is saving
done

echo "run_server: the server exited with code $code" >&2
exit "$code"
