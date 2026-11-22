# Our engine for releases (server/client split plan step C1): Godot 4.7.2 stable with Voxel Tools 1.7 compiled in, the engine Dave uses.
# Voxel Tools publishes no ready export templates for this pair, so the Windows one is built here with the editor, all on Linux (it is
# cross-compiled with MinGW), so nothing is installed on Windows besides Docker Desktop.
#   docker build -f deploy/engine/Dockerfile --output type=local,dest=<folder> deploy/engine
# writes into <folder>:
#   godot                         headless Linux editor: imports and exports the game, and runs the server (deploy/server)
#   windows_release_x86_64.exe    Windows release template: the players' Dynasty.exe
# The first build takes roughly 45 to 90 minutes of full CPU; Docker keeps every stage, so later builds take seconds.
FROM ubuntu:24.04 AS source
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git build-essential pkg-config scons python3 \
        mingw-w64 \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix \
    && update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix
# The same pins as tools/build_godot_linux.sh (the engine Dave and David4 run).
RUN git clone --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git /godot \
    && git clone --depth 1 -b v1.7 https://github.com/Zylann/godot_voxel.git /godot/modules/voxel
WORKDIR /godot
# Headless Linux: no desktop libraries in the container (the flags of tools/build_godot_linux.sh).
ENV LINUX_FLAGS="x11=no wayland=no alsa=no pulseaudio=no udev=no dbus=no speechd=no fontconfig=no"

# The builds run one after another (each stage starts from the one before): run side by side, two -j"$(nproc)" compilers can
# run Docker Desktop's memory out. Each stage keeps the binaries of the stage before it in bin/. Docker keeps each finished stage,
# so a run after a failure starts at the stage that failed (keep the RUN lines above a changed one as they are).
FROM source AS editor
RUN scons platform=linuxbsd target=editor $LINUX_FLAGS -j"$(nproc)" && bin/godot.linuxbsd.editor.x86_64 --version

FROM editor AS windows
# Vulkan (on by default) and Direct3D 12 are both in: the game uses one and can fall back to the other (project.godot
# rendering_device; D-TODO-1 21 Nov 2026, PR #1544). Not yet tried on a player's PC. For D3D12 Godot's own script fetches the Mesa
# NIR libraries it needs into bin/build_deps, where the Windows build looks when cross-compiling. The Agility SDK and PIX parts are removed so the template uses the D3D12 that comes with Windows 10 and 11 and needs
# no extra DLLs. AccessKit (screen reader) needs another SDK and is left out; an option this Godot does not know is only warned about.
RUN python3 misc/scripts/install_d3d12_sdk_windows.py && rm -rf bin/build_deps/agility_sdk bin/build_deps/pix \
    && scons platform=windows target=template_release arch=x86_64 use_mingw=yes d3d12=yes accesskit=no -j"$(nproc)" \
    && ls -l bin/godot.windows.template_release.x86_64.exe

# No Linux release template: nothing uses it yet (the server image runs the editor binary above), and the headless one does not
# link in 4.7.2 with these flags (undefined RenderingContextDriverVulkan, Lane A 22 Nov 2026). Add it back with the exported server.
FROM scratch
COPY --from=windows /godot/bin/godot.linuxbsd.editor.x86_64 /godot
COPY --from=windows /godot/bin/godot.windows.template_release.x86_64.exe /windows_release_x86_64.exe
