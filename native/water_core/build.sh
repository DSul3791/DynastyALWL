#!/bin/sh
# Builds the C++ water core for Linux (cloud, servers) and Windows (the owner's PC) from
# Linux. Needs: g++, mingw-w64, scons (pip install scons), git. The engine is 4.7.
set -e
cd "$(dirname "$0")"
GODOT_CPP_COMMIT=2bb1acf6f8ae1ce96ac7b9ba3a10b499c59c49ec

if [ ! -d godot-cpp ]; then
	git clone -q https://github.com/godotengine/godot-cpp.git godot-cpp
fi

git -C godot-cpp fetch -q --depth 1 origin "$GODOT_CPP_COMMIT" 2>/dev/null || true
git -C godot-cpp checkout -q "$GODOT_CPP_COMMIT"
scons -j"$(nproc)" platform=linux target=template_release api_version=4.7
scons -j"$(nproc)" platform=windows use_mingw=yes target=template_release api_version=4.7
