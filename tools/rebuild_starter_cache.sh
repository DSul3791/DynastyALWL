#!/bin/bash
# Rebuilds worlds/base_world/starter_cache from the committed tiles (HANDOFF.md, "Starter ground").
# Usage: tools/rebuild_starter_cache.sh [godot path]   (about 5 minutes)
set -e
GODOT=${1:-$HOME/bin/godot}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d)
cd "$ROOT"
VERSION=$(grep -o 'TERRAIN_VERSION := [0-9]*' src/worldgen/runtime/terrain_layout.gd | grep -o '[0-9]*$')
MD5=$(md5sum worlds/base_world/tiles/tile_3_4.tile | cut -c1-10)
"$GODOT" --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --store=$W/st > $W/srv.log 2>&1 &
SRV=$!
sleep 25
timeout 400 "$GODOT" --headless --path . res://scenes/terrain_client/terrain_client.tscn -- --cache=$W/cc --frames=5000 > $W/cli.log 2>&1 || true
kill $SRV 2>/dev/null || true
python3 -c "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.execute(\"VACUUM\"); c.close()" $W/cc/tile_3_4_r1.sqlite
gzip -9 -c $W/cc/tile_3_4_r1.sqlite > worlds/base_world/starter_cache/tile_3_4_r1.sqlite.gz
printf '%s_%s' "$VERSION" "$MD5" > worlds/base_world/starter_cache/tiles_stamp.txt
echo "stamp $(cat worlds/base_world/starter_cache/tiles_stamp.txt); log $W"
