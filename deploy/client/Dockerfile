# The players' Windows game (server/client split plan step C2): exports the "Windows Client" preset of export_presets.cfg with our
# engine's Windows template (deploy/engine). tools/make_release.ps1 runs it; by hand:
#   docker build -f deploy/client/Dockerfile --build-context engine=<deploy/engine output> --build-arg OFFICIAL=<host:port> \
#     --output type=local,dest=<folder> .
# writes Dynasty.exe, Dynasty.pck and the water library into <folder>. build_stamp.json must be at the repository root (make_release.ps1
# writes it): a client without it would be refused by every release server.
FROM ubuntu:24.04 AS export
COPY --from=engine --chmod=755 /godot /usr/local/bin/godot
COPY --from=engine /windows_release_x86_64.exe /templates/windows_release_x86_64.exe
COPY project.godot export_presets.cfg icon.svg icon.svg.import build_stamp.json /game/
COPY addons /game/addons
COPY assets /game/assets
COPY data /game/data
COPY scenes /game/scenes
COPY src /game/src
COPY worlds /game/worlds
WORKDIR /game
# The official server players see first (src/client/server_list.gd official(); make_release.ps1 -Official sets it).
ARG OFFICIAL=""
RUN printf '{"official": "%s"}\n' "$OFFICIAL" > client_config.json \
    && sed -i '0,/^custom_template\/release=""/s||custom_template/release="/templates/windows_release_x86_64.exe"|' export_presets.cfg \
    && grep -q '^custom_template/release="/templates/windows_release_x86_64.exe"' export_presets.cfg
# A first import can fail on a resource it has not seen yet and pass on the second run (tools/gate_pc.sh does the same).
RUN godot --headless --path /game --import > /tmp/import.log 2>&1 || godot --headless --path /game --import > /tmp/import.log 2>&1 \
    || { tail -40 /tmp/import.log >&2; exit 1; }
RUN mkdir /out && godot --headless --path /game --export-release "Windows Client" /out/Dynasty.exe > /tmp/export.log 2>&1; \
    tail -20 /tmp/export.log; test -s /out/Dynasty.exe && test -s /out/Dynasty.pck \
    || { echo "export failed: no Dynasty.exe and Dynasty.pck (log above)" >&2; exit 1; }

FROM scratch
COPY --from=export /out/ /
