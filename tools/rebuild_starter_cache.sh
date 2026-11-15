#!/bin/bash
# Rebuilds worlds/base_world/starter_cache from the committed tiles (HANDOFF.md, "Starter ground"). Headless, no hands needed.
# Usage: tools/rebuild_starter_cache.sh [godot path] [port]   (2 to 7 minutes; godot defaults to $GODOT, else tools/godot; python to $PYTHON, else python3)
# Own port (default a random high one) and its own temp store and cache, so it never meets a running game or server; the
# client's other user files (telemetry, settings) still go to the Godot user folder, so isolate APPDATA/XDG_DATA_HOME on a PC.
# Writes nothing unless the client reached ground, nothing was still waiting at the end, and the tile holds at least MIN_BLOCKS blocks
# (the stale cache of 15 Nov 2026 held 7955); test_starter_cache_stamp checks the stamp afterwards.
set -e
GODOT=${1:-${GODOT:-$(cd "$(dirname "$0")" && pwd)/godot}}
PYTHON=${PYTHON:-python3}
MIN_BLOCKS=${MIN_BLOCKS:-4000}
PORT=${2:-$((21000 + RANDOM % 18000))}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d)
cd "$ROOT"
VERSION=$(grep -o 'TERRAIN_VERSION := [0-9]*' src/worldgen/runtime/terrain_layout.gd | grep -o '[0-9]*$')
MD5=$(md5sum worlds/base_world/tiles/tile_3_4.tile | cut -c1-10)
"$GODOT" --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store=$W/st --quit-after=600 > $W/srv.log 2>&1 &
SRV=$!
sleep 40
# 20000 frames: a cold join reached ground at +40 s on Dave's PC (~100 fps), so the old 5000 left little time to fill the tile around the spawn.
timeout 450 "$GODOT" --headless --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1 --port=$PORT --cache=$W/cc --frames=20000 --timeout=440 > $W/cli.log 2>&1 || true
kill $SRV 2>/dev/null || true
FILE=$W/cc/tile_3_4_r1.sqlite
if ! grep -q "JOIN: ground ready" $W/cli.log || ! grep -q ", 0 still waiting," $W/cli.log || [ ! -s "$FILE" ]; then
	echo "FAIL: no ground, blocks still waiting at the end, or no tile_3_4_r1.sqlite; nothing written. Logs in $W"
	ls -la $W/cc* 2>/dev/null || true
	exit 1
fi
BLOCKS=$("$PYTHON" -c "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); print(c.execute('SELECT COUNT(*) FROM blocks').fetchone()[0]); c.execute('VACUUM'); c.close()" "$FILE" | tr -d "\r")
echo "blocks in tile 3,4: $BLOCKS"
if [ "$BLOCKS" -lt "$MIN_BLOCKS" ]; then
	echo "FAIL: only $BLOCKS blocks (want $MIN_BLOCKS or more); nothing written. Logs in $W"
	exit 1
fi
gzip -9 -c "$FILE" > worlds/base_world/starter_cache/tile_3_4_r1.sqlite.gz
printf '%s_%s' "$VERSION" "$MD5" > worlds/base_world/starter_cache/tiles_stamp.txt
grep "JOIN: ground ready" $W/cli.log | head -1
echo "stamp $(cat worlds/base_world/starter_cache/tiles_stamp.txt); gz $(wc -c < worlds/base_world/starter_cache/tile_3_4_r1.sqlite.gz) bytes; log $W"
