Optional: put a ready Linux build of our engine here as "godot" (Godot 4.7.2 with Voxel Tools 1.7, headless editor build, from
tools/build_godot_linux.sh, for example a copy of David4's /work/bin/godot). deploy/server/Dockerfile then uses it instead of
compiling the engine (about 30 to 40 minutes). The file is gitignored.
