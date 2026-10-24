# Test box for DynastyALWL: Godot 4.7.2 + Voxel Tools 1.7 (headless, Linux) and the repo's test jobs.
# Separate from any game container. Build from this folder (the context is this folder only, not the 1.5 GB repo):
#   docker build -t dynasty-testbox .                       builds the engine from source (about 30-60 min, needs 8 GB RAM, once)
#   docker build --build-arg ENGINE=file -t dynasty-testbox .   uses engine/godot-4.7.2-voxel1.7-linux-headless.xz put in this folder (fast)
ARG ENGINE=build

FROM ubuntu:24.04 AS engine-build
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates build-essential pkg-config python3 python3-pip curl && rm -rf /var/lib/apt/lists/*
RUN pip3 install --break-system-packages scons
# the project's own build script (Godot 4.7.2-stable ed1daf0bf + godot_voxel v1.7, headless)
RUN curl -fsSL https://raw.githubusercontent.com/DSul3791/DynastyALWL/claude/generator-v2/tools/build_godot_linux.sh -o /build.sh && chmod +x /build.sh && /build.sh /build \
 && mkdir -p /out && cp /build/godot/bin/godot.linuxbsd.editor.x86_64 /out/godot

FROM ubuntu:24.04 AS engine-file
RUN apt-get update && apt-get install -y --no-install-recommends xz-utils && rm -rf /var/lib/apt/lists/*
COPY engine/godot-4.7.2-voxel1.7-linux-headless.xz /tmp/godot.xz
RUN mkdir -p /out && xz -dc /tmp/godot.xz > /out/godot

FROM engine-${ENGINE} AS engine

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends git python3 ca-certificates tini && rm -rf /var/lib/apt/lists/*
COPY --from=engine /out/godot /opt/godot/godot
RUN chmod +x /opt/godot/godot && /opt/godot/godot --version
COPY run_jobs.sh /usr/local/bin/run_jobs.sh
RUN chmod +x /usr/local/bin/run_jobs.sh && useradd -m -u 1500 tester && mkdir -p /work /out && chown tester /work /out
USER tester
ENV GODOT_EXE=/opt/godot/godot PYTHONDONTWRITEBYTECODE=1
WORKDIR /work
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/run_jobs.sh"]
CMD ["selftest"]
