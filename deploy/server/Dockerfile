# The Dynasty game server (server and generator, one build) in a container: server/client split plan step C4, Dave 18 Nov 2026
# ("the generator and server stay one build in a Docker container"). Build it with deploy/server/build_image.sh, run it with
# deploy/server/compose.yaml; deploy/server/SERVER.md has the steps.
#
# shortcut: runs the project from source with the headless voxel editor build, because no export templates exist yet for our engine
# (Godot 4.7.2 + Voxel Tools 1.7, plan C1). Revisit when C1 lands: export the "Linux Server" preset and run that on the template.

# Both stages use Ubuntu 24.04: David4's engine binary needs its glibc 2.39 (Debian 12 has 2.36).
# Stage 1: the engine. tools/build_godot_linux.sh compiles it (about 30 to 40 minutes the first time; Docker keeps the result until
# the script changes). A ready binary of the same engine placed at deploy/server/engine/godot (for example a copy of David4's
# /work/bin/godot) is used instead and skips the compile.
FROM ubuntu:24.04 AS engine
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git build-essential pkg-config scons python3 \
    && rm -rf /var/lib/apt/lists/*
COPY tools/build_godot_linux.sh /src/build_godot_linux.sh
COPY deploy/server/engine/ /prebuilt/
RUN if [ -f /prebuilt/godot ]; then cp /prebuilt/godot /godot; \
    else bash /src/build_godot_linux.sh /build && cp /build/godot/bin/godot.linuxbsd.editor.x86_64 /godot && rm -rf /build; fi
RUN chmod +x /godot && /godot --version | tee /dev/stderr | grep -q '^4\.7\.2\.' \
    || { echo "the engine must be Godot 4.7.2 with Voxel Tools 1.7 (tools/build_godot_linux.sh)" >&2; exit 1; }

# Stage 2: the server. The project goes in /game without what the server never loads (art, docs, tools: the "Linux Server" export
# preset leaves them out too, and tools/export_check.py checks that), imported once here so a start does not import.
# build_stamp.json is there only when build_image.sh --stamp wrote it (a release); the odd spelling lets the copy go on without it.
# Everything the server writes goes in the /data volume: the world's store (edits, characters, admin.json, logs, run note) in /data/store, and Godot's user folder under /data/home.
FROM ubuntu:24.04
RUN useradd --create-home --uid 1001 dynasty && mkdir -p /data /game && chown dynasty:dynasty /data /game
COPY --from=engine /godot /usr/local/bin/godot
COPY --chown=dynasty:dynasty project.godot icon.svg icon.svg.import build_stamp.jso[n] /game/
COPY --chown=dynasty:dynasty addons /game/addons
COPY --chown=dynasty:dynasty assets /game/assets
COPY --chown=dynasty:dynasty data /game/data
COPY --chown=dynasty:dynasty scenes /game/scenes
COPY --chown=dynasty:dynasty src /game/src
COPY --chown=dynasty:dynasty worlds /game/worlds
COPY --chown=dynasty:dynasty --chmod=755 deploy/server/run_server.sh /game/deploy/server/run_server.sh
USER dynasty
WORKDIR /game
# A first import can fail on a resource it has not seen yet and pass on the second run (tools/gate_pc.sh does the same).
RUN godot --headless --path /game --import > /tmp/import.log 2>&1 || godot --headless --path /game --import > /tmp/import.log 2>&1 \
    || { tail -40 /tmp/import.log >&2; exit 1; }; \
    test -f /game/.godot/global_script_class_cache.cfg || { tail -40 /tmp/import.log >&2; exit 1; }; rm -f /tmp/import.log

ARG COMMIT=unknown
LABEL org.opencontainers.image.source="https://github.com/DSul3791/DynastyALWL" org.opencontainers.image.revision="$COMMIT"
ENV HOME=/data/home
VOLUME /data
EXPOSE 24600/udp 24601/tcp
# The server writes its run note (state running) once it is listening, and removes it when it closes.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10m CMD grep -q '"state":"running"' /data/store/server_run.json
# run_server.sh is PID 1: it turns docker stop's TERM into stop.now, so the server saves and closes (compose gives it 90 s).
ENTRYPOINT ["/game/deploy/server/run_server.sh", "godot", "--headless", "--path", "/game", "res://scenes/terrain_server/terrain_server.tscn", "--", "--dedicated", "--store=/data/store"]
