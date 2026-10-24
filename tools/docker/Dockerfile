# Test box for DynastyALWL: Godot 4.7.2 + Voxel Tools 1.7 (headless, Linux) and the repo's test jobs.
# Separate from any game container. Build from this folder (the context is this folder only, not the 1.5 GB repo):
#   docker build -t dynasty-testbox .                       builds the engine from source (about 30-60 min, needs 8 GB RAM, once)
#   (ENGINE=file is the headless-only copy: tests work, pictures do not)
#   docker build --build-arg ENGINE=file -t dynasty-testbox .   uses engine/godot-4.7.2-voxel1.7-linux-headless.xz put in this folder (fast)
ARG ENGINE=build

FROM ubuntu:24.04 AS engine-build
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates build-essential pkg-config python3 python3-pip \
 libx11-dev libxcursor-dev libxinerama-dev libxi-dev libxrandr-dev libgl-dev libxext-dev libxrender-dev && rm -rf /var/lib/apt/lists/*
RUN pip3 install --break-system-packages scons
# Godot 4.7.2-stable (ed1daf0bf) + godot_voxel v1.7, Linux, WITH x11 + vulkan so it can also draw pictures (the same flags as tools/build_godot_linux.sh plus x11/vulkan)
RUN git clone --depth 1 -b 4.7.2-stable https://github.com/godotengine/godot.git /build/godot \
 && git clone --depth 1 -b v1.7 https://github.com/Zylann/godot_voxel.git /build/godot/modules/voxel \
 && cd /build/godot && scons platform=linuxbsd target=editor x11=yes wayland=no vulkan=yes opengl3=no alsa=no pulseaudio=no udev=no dbus=no speechd=no fontconfig=no -j"$(nproc)" \
 && mkdir -p /out && cp bin/godot.linuxbsd.editor.x86_64 /out/godot

FROM ubuntu:24.04 AS engine-file
RUN apt-get update && apt-get install -y --no-install-recommends xz-utils && rm -rf /var/lib/apt/lists/*
COPY engine/godot-4.7.2-voxel1.7-linux-headless.xz /tmp/godot.xz
RUN mkdir -p /out && xz -dc /tmp/godot.xz > /out/godot

FROM engine-${ENGINE} AS engine

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends git openssh-client python3 python3-pil ca-certificates tini curl \
 xvfb libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libegl1 libvulkan1 mesa-vulkan-drivers vulkan-tools && rm -rf /var/lib/apt/lists/*
COPY --from=engine /out/godot /opt/godot/godot
RUN chmod +x /opt/godot/godot && ln -s /opt/godot/godot /opt/godot/godot-gfx && /opt/godot/godot --version
COPY run_jobs.sh /usr/local/bin/run_jobs.sh
COPY selftest.gd shot.sh /opt/box/
RUN chmod +x /usr/local/bin/run_jobs.sh && useradd -m -u 1500 tester && mkdir -p /work /out && chown tester /work /out
USER tester
# Claude Code (native installer from the official quickstart); signs in later with Dave's own browser login, nothing is baked in
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/tester/.local/bin:${PATH}" CLAUDE_CONFIG_DIR=/home/tester/.claude-box
ENV GODOT_EXE=/opt/godot/godot PYTHONDONTWRITEBYTECODE=1
WORKDIR /work
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/run_jobs.sh"]
CMD ["selftest"]
