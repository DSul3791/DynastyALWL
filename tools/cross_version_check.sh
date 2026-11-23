#!/bin/bash
# usage: tools/cross_version_check.sh [OLD_REF]      (default origin/main: the build players have)
# A game and a server of different versions must tell the player plainly, both ways (protocol 161; 23 Nov 2026: a build 9257 client on a
# newer server got every call on the wrong method and no word). Makes a worktree of OLD_REF (models skipped, imported once and kept in
# /tmp/dynasty_xver_<sha>), then runs headless: this checkout's server with OLD_REF's client, and OLD_REF's server with this checkout's
# client. Each client must end with a "join refused" line that names another build or version, within 60 s.
# Exit 0 = both said why; 1 = one did not (its logs are printed); 2 = the run broke (no worktree, a server never came up).
# Run from the repository root with `godot` on PATH (GODOT overrides). Same protocol on both sides is not a mismatch: it exits 0 at once.
set -u
GODOT=${GODOT:-godot}
OLD_REF=${1:-origin/main}
NEW=$(pwd)
OLD_SHA=$(git rev-parse --short "$OLD_REF") || exit 2
OLD=/tmp/dynasty_xver_$OLD_SHA
proto() { grep -m1 -o "PROTOCOL_VERSION := [0-9]*" "$1/src/stream/terrain_net.gd" | grep -o "[0-9]*$"; }
if [ ! -d "$OLD" ]; then
	git worktree add -q --detach "$OLD" "$OLD_REF" || exit 2
	( cd "$OLD" && tools/skip_models.sh >/dev/null 2>&1 ); true
fi
if [ ! -f "$OLD/.godot/xver_import_ok" ]; then   # a fresh import can crash part way (robots.sh, 23 Nov 2026): try twice
	for try in 1 2; do ( cd "$OLD" && timeout 900 $GODOT --headless --path . --import >/dev/null 2>&1 ) && { touch "$OLD/.godot/xver_import_ok"; break; }; done
	[ -f "$OLD/.godot/xver_import_ok" ] || { echo "cross version: the import of $OLD_REF never finished"; exit 2; }
fi
if [ "$(proto "$OLD")" = "$(proto "$NEW")" ]; then echo "cross version: $OLD_REF speaks the same protocol $(proto "$NEW"): nothing to check"; exit 0; fi
bad=0
run() {   # server dir, client dir, tag
	local D; D=$(mktemp -d /tmp/xver_$3_XXXX); mkdir -p "$D/store" "$D/data" "$D/cache"
	local PORT=$((24000 + RANDOM % 3000))
	( cd "$1" && exec timeout 200 $GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$D/store" --quit-after=150 > "$D/server.log" 2>&1 ) &
	local SP=$!
	for i in $(seq 1 150); do grep -q "^Terrain server listening" "$D/server.log" 2>/dev/null && break; sleep 1; done
	if ! grep -q "^Terrain server listening" "$D/server.log"; then echo "cross version $3: the server never came up"; kill $SP 2>/dev/null; exit 2; fi
	( cd "$2" && XDG_DATA_HOME="$D/data" timeout 90 $GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_client/terrain_client.tscn -- \
		--server=127.0.0.1 --port=$PORT --block-port=$((PORT + 1)) --cache="$D/cache" --timeout=60 > "$D/client.log" 2>&1 )
	kill $SP 2>/dev/null
	local said; said=$(grep -m1 "join refused" "$D/client.log")
	if echo "$said" | grep -qiE "older|newer|another build|different version|update"; then echo "cross version $3: ok: ${said#*join refused: }"
	else echo "cross version $3: FAIL the client was not told why (logs in $D)"; tail -5 "$D/client.log"; bad=1; fi
}
run "$NEW" "$OLD" "old_client_new_server"
run "$OLD" "$NEW" "new_client_old_server"
exit $bad
