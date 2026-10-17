#!/usr/bin/env bash
# Builds the project's engine for Linux: Godot 4.7.2 stable (ed1daf0bf) with
# the Voxel Tools 1.7 module compiled in, the same engine the owner uses on
# Windows. Headless only (no X11 or Wayland), which is what cloud sessions
# need to run the generator, the tests and the server.
#
# About 30 minutes on 4 cores. Needs git, a C++ compiler and scons
# (pip install scons).
#
#   tools/build_godot_linux.sh [build_dir]
#
# The binary ends up in <build_dir>/godot/bin/godot.linuxbsd.editor.x86_64.
# In a project cloud session a compressed copy may already be in
# /mnt/project-files/engine/ (unpack it with xz -dc).
set -euo pipefail

BUILD_DIR="${1:-$HOME/build}"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -d godot ]; then
	git clone --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git
fi

if [ ! -d godot/modules/voxel ]; then
	git clone --depth 1 -b v1.7 https://github.com/Zylann/godot_voxel.git godot/modules/voxel
fi

cd godot
scons platform=linuxbsd target=editor \
	x11=no wayland=no alsa=no pulseaudio=no udev=no dbus=no speechd=no fontconfig=no \
	-j"$(nproc)"

bin/godot.linuxbsd.editor.x86_64 --version
