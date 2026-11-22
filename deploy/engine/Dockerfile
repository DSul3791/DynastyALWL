# Our engine for releases (server/client split plan step C1): Godot 4.7.2 stable with Voxel Tools 1.7 compiled in, the engine Dave uses.
# Voxel Tools publishes no ready export templates for this pair, so they are built here, all on Linux (the Windows one is
# cross-compiled with MinGW), so nothing is installed on Windows besides Docker Desktop.
#   docker build -f deploy/engine/Dockerfile --output type=local,dest=<folder> deploy/engine
# writes into <folder>:
#   godot                         headless Linux editor: imports and exports the game, and runs the server (deploy/server)
#   windows_release_x86_64.exe    Windows release template: the players' Dynasty.exe
#   linux_release_x86_64          headless Linux release template (for a later exported server)
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

# The three builds run one after another (each stage starts from the one before): run side by side, three -j"$(nproc)" compilers can
# run Docker Desktop's memory out. Each stage keeps the binaries of the stages before it in bin/.
FROM source AS editor
RUN scons platform=linuxbsd target=editor $LINUX_FLAGS -j"$(nproc)" && bin/godot.linuxbsd.editor.x86_64 --version

FROM editor AS windows
# The game asks for Direct3D 12 on Windows (project.godot rendering_device/driver.windows, decision D-TODO-1, 21 Nov 2026), so the
# template has it: Godot's own script fetches the Mesa NIR libraries it needs into bin/build_deps, where the Windows build looks when
# cross-compiling. The Agility SDK and PIX parts are removed so the template uses the D3D12 that comes with Windows 10 and 11 and needs
# no extra DLLs. AccessKit (screen reader) needs another SDK and is left out; an option this Godot does not know is only warned about.
RUN python3 misc/scripts/install_d3d12_sdk_windows.py && rm -rf bin/build_deps/agility_sdk bin/build_deps/pix \
    && scons platform=windows target=template_release arch=x86_64 use_mingw=yes d3d12=yes accesskit=no -j"$(nproc)" \
    && ls -l bin/godot.windows.template_release.x86_64.exe

FROM windows AS linux
RUN scons platform=linuxbsd target=template_release $LINUX_FLAGS -j"$(nproc)" && ls -l bin/godot.linuxbsd.template_release.x86_64

FROM scratch
COPY --from=linux /godot/bin/godot.linuxbsd.editor.x86_64 /godot
COPY --from=linux /godot/bin/godot.windows.template_release.x86_64.exe /windows_release_x86_64.exe
COPY --from=linux /godot/bin/godot.linuxbsd.template_release.x86_64 /linux_release_x86_64
