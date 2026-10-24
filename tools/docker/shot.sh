#!/bin/bash
# One test picture on a machine WITHOUT a graphics card: throwaway server (no rendering) + the real client drawn by software
# Vulkan (Mesa lavapipe) on a virtual screen (Xvfb). Slow and not pixel-identical to Mike's GPU shots: use it to check content, not exact colours.
#   shot.sh [--at X,Z] [--agl 1.7] [--yaw 0] [--hour 12] [--name NAME] [--out DIR] [--wait 120] [--settle 20]
# Needs GODOT_GFX_EXE (the engine built WITH x11+vulkan; default /opt/godot/godot-gfx), xvfb, mesa-vulkan-drivers.
cd "${REPO:-/work/repo}" || exit 2
GFX="${GODOT_GFX_EXE:-/opt/godot/godot-gfx}"; SRV="${GODOT_EXE:-/opt/godot/godot}"
AT="53301,68427"; AGL=1.7; YAW=0; PITCH=0; HOUR=12; NAME=spawn; OUT=/out/shots; WAIT=120; SETTLE=20
while [ $# -gt 0 ]; do case "$1" in --at) AT="$2";; --agl) AGL="$2";; --yaw) YAW="$2";; --pitch) PITCH="$2";; --hour) HOUR="$2";; --name) NAME="$2";; --out) OUT="$2";; --wait) WAIT="$2";; --settle) SETTLE="$2";; *) echo "unknown argument $1"; exit 2;; esac; shift 2; done
X="${AT%,*}"; Z="${AT#*,}"
RIG=$(mktemp -d); STORE="$RIG/store"; mkdir -p "$STORE" "$OUT" "$RIG/home"
export HOME="$RIG/home" XDG_DATA_HOME="$RIG/data"; UD="$XDG_DATA_HOME/godot/app_userdata/Dynasty a life well lived"; mkdir -p "$UD"
echo -n "00112233445566778899aabb" > "$UD/player_key.txt"; echo -n "0" > "$UD/hotbar.txt"
PORT=$((7800 + RANDOM % 150))
"$SRV" --headless --rendering-driver dummy --path . res://scenes/terrain_server/terrain_server.tscn -- --port=$PORT --store="$STORE" --open-admin --quit-after=900 > "$RIG/server.log" 2>&1 &
SP=$!; trap 'kill $SP 2>/dev/null; sleep 1; rm -rf "$RIG"' EXIT
sleep 30
T0=$(date +%s)
LIBGL_ALWAYS_SOFTWARE=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json \
 xvfb-run -a -s "-screen 0 1280x720x24" "$GFX" --path . --rendering-driver vulkan --resolution 1280x720 res://scenes/terrain_client/terrain_client.tscn -- \
 --server=127.0.0.1 --port=$PORT --shots="$NAME:$X,$AGL,$Z,$YAW,$PITCH,$HOUR,clear,-1" --shot-dir="$OUT" --shot-wait=$WAIT --shot-settle=$SETTLE > "$RIG/client.log" 2>&1
echo "shot: $(( $(date +%s) - T0 )) s"
grep -E "shot runner: saved|ERROR|SCRIPT" "$RIG/client.log" | head -5 | cut -c1-200
ls -la "$OUT/$NAME.png" 2>/dev/null | awk '{print $5, $9}' || echo "no picture made"
