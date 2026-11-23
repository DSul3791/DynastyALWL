#!/bin/bash
# A tester updating from the installed build 9257 (main) to this checkout (coordinator, 23 Nov 2026): the same user folder (their settings,
# keys, remembered address and the ground cache 9257 filled) and the same server store must carry on: the new game joins, lands and shows no
# script error. Makes a worktree of OLD_REF the way tools/cross_version_check.sh does (models skipped, imported once, kept in
# /tmp/dynasty_xver_<sha>), then headless:
#   1  OLD_REF's server and client-only game, with a 9257-style user folder (settings, a rebind, the address): joins and fills the cache
#   2  this checkout's server on the same store and this checkout's game on the same user folder: joins, lands, no script error
# The values read from those settings files are checked by test_settings_files.gd (the same 9257 file); this is the whole start.
#   tools/upgrade_9257_check.sh [OLD_REF]      (default origin/main; from the repository root, `godot` on PATH; about 5 to 15 minutes)
# Exit 0 carried over; 1 a step failed (its log tail is printed); 2 the run broke (no worktree or import).
GODOT=${GODOT:-godot}
OLD_REF=${1:-origin/main}
NEW=$(pwd)
OLD_SHA=$(git rev-parse --short "$OLD_REF") || exit 2
OLD=/tmp/dynasty_xver_$OLD_SHA
if [ ! -d "$OLD" ]; then
	git worktree add -q --detach "$OLD" "$OLD_REF" || exit 2
	( cd "$OLD" && tools/skip_models.sh >/dev/null 2>&1 ); true
fi
if [ ! -f "$OLD/.godot/xver_import_ok" ]; then
	for try in 1 2; do ( cd "$OLD" && timeout 900 $GODOT --headless --path . --import >/dev/null 2>&1 ) && { touch "$OLD/.godot/xver_import_ok"; break; }; done
	[ -f "$OLD/.godot/xver_import_ok" ] || { echo "upgrade: the import of $OLD_REF never finished"; exit 2; }
fi
D=$(mktemp -d /tmp/upgrade_XXXX); mkdir -p "$D/store" "$D/home" "$D/data"
UD="$D/data/godot/app_userdata/Dynasty a life well lived"; mkdir -p "$UD"
trap 'kill $SP 2>/dev/null; sleep 1; rm -rf "$D"' EXIT
PORT=$((25000 + RANDOM % 2000)); bad=0
printf '[display]\n\nsize=1\nfullscreen=false\nvsync=2\nquality=1\ntext=2\nhud_text=true\nidle_minutes=90\ncave_dark=false\ndamage_numbers=false\nfahrenheit=true\nreduce_motion=false\nsort=3\nsort_version=2\n' > "$UD/display_settings.cfg"
printf '{"auto_pickup": {"key": %d, "ctrl": false, "shift": false}}' 66 > "$UD/key_bindings.json"   # B, before the shield took it
printf '[join]\n\naddress="127.0.0.1:%d"\n' $PORT > "$UD/join_address.cfg"
printf '[sound]\n\n[levels]\n\nmaster=0.6\n' > "$UD/sound_settings.cfg"
serve() {   # dir, tag
	( cd "$1" && exec env HOME="$D/home" XDG_DATA_HOME="$D/data_server" timeout 400 $GODOT --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$D/store" --quit-after=300 > "$D/server_$2.log" 2>&1 ) &
	SP=$!
	for i in $(seq 1 300); do grep -q "^Terrain server listening" "$D/server_$2.log" 2>/dev/null && return 0; kill -0 $SP 2>/dev/null || break; sleep 1; done
	echo "upgrade $2: the server never came up"; tail -8 "$D/server_$2.log" | cut -c1-200; exit 2
}
play() {   # dir, tag
	( cd "$1" && env HOME="$D/home" XDG_DATA_HOME="$D/data" timeout 200 $GODOT --headless --path . -- --client-only --test --timeout=150 > "$D/client_$2.log" 2>&1 )
}
serve "$OLD" old; play "$OLD" old; kill $SP 2>/dev/null; wait $SP 2>/dev/null; sleep 2
grep -q "Terrain client: welcome after" "$D/client_old.log" && echo "upgrade 1: ok: the $OLD_REF game joined its server" || { echo "upgrade 1: FAIL the $OLD_REF game did not join"; tail -8 "$D/client_old.log" | cut -c1-200; bad=1; }
CACHE=$(find "$UD/terrain_cache" -type f 2>/dev/null | wc -l)
echo "upgrade 1: the $OLD_REF game left $CACHE ground cache file(s) and $(ls "$UD" | tr '\n' ' ')"
serve "$NEW" new; play "$NEW" new; kill $SP 2>/dev/null
grep -q "Terrain client: welcome after" "$D/client_new.log" && echo "upgrade 2: ok: this game joined with the old user folder and store" || { echo "upgrade 2: FAIL no welcome"; bad=1; }
grep -q "JOIN: ground ready" "$D/client_new.log" && echo "upgrade 2: ok: and landed on the ground" || { echo "upgrade 2: FAIL no ground ready"; bad=1; }
grep -q "SCRIPT ERROR" "$D/client_new.log" "$D/server_new.log" && { echo "upgrade 2: FAIL script errors:"; grep -h -A1 "SCRIPT ERROR" "$D/client_new.log" "$D/server_new.log" | head -10 | cut -c1-200; bad=1; } || echo "upgrade 2: ok: no script error in the new game or server"
grep -q "join refused" "$D/client_new.log" && { echo "upgrade 2: FAIL refused: $(grep -m1 'join refused' "$D/client_new.log")"; bad=1; }
[ $bad = 0 ] || { echo "--- new client tail"; tail -12 "$D/client_new.log" | cut -c1-200; }
echo "upgrade_9257_check: $([ $bad = 0 ] && echo ok || echo FAIL)"; exit $bad
