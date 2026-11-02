#!/bin/bash
# World-alive metrics (Tyler, 31 Oct 2026): tools/world_alive.sh [--samples N] [--no-log]
# Measures the nine centre tiles (flora per hectare by layer, nominal animals per km2, water, rivers), compares with TARGETS.md, and appends a block to
# WORLD_ALIVE_LOG.md. About 1 to 4 minutes. Needs the baked tiles in worlds/base_world/tiles.
cd "$(dirname "$0")/.." || exit 2
export PATH="$PWD/tools:$PATH"; export WA_COMMIT="$(git rev-parse --short HEAD)"
N=10; EXTRA=""
while [ $# -gt 0 ]; do case "$1" in --samples) N="$2"; shift 2;; --no-log) EXTRA="--no-log"; shift;; *) shift;; esac; done
godot --headless --path . --script res://tools/world_alive.gd -- --samples=$N $EXTRA 2>&1 | grep -v -E "^\s+at:|^Godot Engine|^$|leaked|still in use"
