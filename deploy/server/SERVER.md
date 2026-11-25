# The Dynasty server in Docker

Server/client split plan step C4 (`/mnt/project-files/server-client-split/PLAN.md`; Dave 18 Nov 2026: the server and the generator stay one build in a Docker container, the testers' platform; the game server container runs on the gaming server beside David4, never inside it).

**Status: not yet run anywhere.** Nothing here has been built or started yet; the first build is the test.

## What is in it

- `Dockerfile`: stage 1 makes the engine (Godot 4.7.2 with Voxel Tools 1.7, headless, by `tools/build_godot_linux.sh`, about 30 to 40 minutes the first time, then cached), or takes a ready binary from `deploy/server/engine/godot`. Stage 2 is Ubuntu 24.04 with the engine and the project in `/game`, imported once at build time.
- It runs the project from source with that engine (`godot --headless --path /game ... terrain_server.tscn -- --dedicated --store=/data/store`), because there are no export templates for our engine yet (plan C1). When C1 lands, the image switches to the exported "Linux Server" preset.
- `run_server.sh` is the container's first process. `docker stop` sends it TERM; it writes `stop.now`, and the server saves and closes with exit 0 (plan A4, PR #1274). Compose allows 90 s for that.
- Everything the server writes lives in the `/data` volume: `/data/store` (ground edits, characters, chests, `admin.json`, `logs/`, `server_run.json`) and Godot's user folder under `/data/home`. A restart keeps the volume, so the world carries on; a new build is a clean install that removes it ("Another build" below).
- The world (the nine baked tiles of `worlds/base_world`) is inside the image.
- Health check: healthy once `/data/store/server_run.json` says `running` (the server is listening).

## Build (on the machine with Docker)

From a full clone of DynastyALWL at the commit to run (dev for testing, main for a release):

```
deploy/server/build_image.sh            # test image of this commit: dynasty-server:dev-<commit> and :latest
deploy/server/build_image.sh --stamp    # release image: dynasty-server:build-<N> and :latest
```

A test image has no build stamp, so the game run from the editor can join it. A stamped image refuses every other build, the editor included, so it only makes sense once there is an exported client of the same build.

To skip the engine compile, copy a ready Linux engine (for example David4's engine: `/work/bin/godot` is a link to `/work/engine/godot`, so copy the real file, `cp -L`) to `deploy/server/engine/godot` first. It must run on Ubuntu 24.04 (glibc 2.39 or older), as David4's does.

## Run (on the gaming server)

1. Get the image there. Either build it there (above), or on the PC: `docker save dynasty-server:latest | gzip > dynasty-server.tar.gz`, copy the file over, and on the server `docker load < dynasty-server.tar.gz`. (Plan pick for later: push to ghcr.io, not yet agreed.)
2. Copy `compose.yaml` there and start it: `docker compose -f compose.yaml up -d`.
   From Dave's PC to his gaming server (LAN address 192.168.0.108; he types his password), with a release build's files. This is its own copy, separate from the testers' site copy (deploy/testplayers/SERVER.md step 2), and goes to the folder /home/dave/dynasty:
   `$build = "<N>"; ssh dave@192.168.0.108 "mkdir -p /home/dave/dynasty"; scp "E:\Software\godotDev\dynasty_export\build-$build\dynasty-server-build-$build.tar" "E:\Software\godotDev\dynasty_export\build-$build\compose.yaml" "dave@192.168.0.108:/home/dave/dynasty/"`
   then `ssh dave@192.168.0.108`, `cd /home/dave/dynasty`, `docker load -i dynasty-server-build-<N>.tar` and the start line above.
3. Watch it come up: `docker logs -f dynasty-server` (the first start makes the ground round the spawn, a few minutes). `docker ps --filter name=dynasty-server --format "{{.Names}}: {{.Status}}"` shows just the server's line, with "healthy" once it listens.
4. Admins: the store's `admin.json` lists the admin player keys (`docs/design/ADMIN_CHECK.md`; Esc > Admin > "Show my player key" in local Play, or the file `%APPDATA%\Godot\app_userdata\Dynasty a life well lived\player_key.txt` on the PC, since the installed game hides Esc > Admin until you are an admin). Make a file `admin.json` with `{"keys": ["<your key>"]}`, then `docker exec -i -u dynasty dynasty-server sh -c 'cat > /data/store/admin.json' < admin.json` and `docker restart dynasty-server`. The start line in `docker logs dynasty-server` then says "1 admin keys". Without it nobody is an admin there.
5. Name, message and password (optional; `docs/design/SERVER_PICK_PAGE.md`): the store's `server.json`, for example `{"name": "Hannibal's House", "message": "Bring an axe.", "password": "your password"}`, copied in the same way as `admin.json` (`.../data/store/server.json`), then `docker restart dynasty-server`. At start the server replaces `password` in that file with a salted hash, so the password itself is not kept on disk. Or set the password without a file: `DYNASTY_SERVER_PASSWORD=your-password docker compose -f compose.yaml up -d` (compose passes it in; it is only hashed in memory and wins over the file). The start line in `docker logs dynasty-server` says "password: on" or "off". No password = anyone with the address may join. Players get three tries; a computer that gets it wrong five times in a minute waits a minute.
6. The router forwards UDP 24600 and TCP 24601 to the gaming server. The server pick page asks for each server's name, players and padlock on TCP 24601, so it must be forwarded too.

Stop: `docker compose -f compose.yaml down` (saves first). Run without compose, give `docker run` and `docker stop` `--stop-timeout 90` / `-t 90`, or docker kills it after 10 s.

Another build is always a clean install (Dave 25 Nov 2026: "the server is always a clean install no keeping backups"; "our backup is in github"; "and on my computer"). Nothing is backed up on the server and there is no going back to an older build there: a broken build is fixed by a new build. In /home/dave/dynasty, with the new tar and compose.yaml copied in (step 2), and `<old>` the build running now (`docker images dynasty-server` shows its tag):
1. `docker compose -f compose.yaml down`
2. Optional, keep the settings that are not in GitHub (steps 4 and 5): `docker run --rm -v dynasty_dynasty-data:/data -v /home/dave/dynasty:/keep ubuntu sh -c "cp /data/store/admin.json /keep/ 2>/dev/null; cp /data/store/server.json /keep/ 2>/dev/null; ls -l /keep/admin.json /keep/server.json"`
3. Remove the old world, the old image (its Dynasty tags only; never `docker system prune`, the machine runs other servers) and any old backup or tar files: `docker volume rm dynasty_dynasty-data`, `docker image rm dynasty-server:build-<old> dynasty-server:latest`, `rm -f dynasty-data-build-*.tgz; find . -maxdepth 1 -name 'dynasty-server-build-*.tar' ! -name 'dynasty-server-build-<N>.tar' -delete`
4. `docker load -i dynasty-server-build-<N>.tar`, then `rm dynasty-server-build-<N>.tar`. A prebuilt ground pack, if the build has one, is installed now ("Prebuilt ground" below, step 3).
5. `docker compose -f compose.yaml up -d`; if the settings were kept, put them back with the two `docker exec ... cat > /data/store/admin.json` / `server.json` lines of steps 4 and 5, then `docker restart dynasty-server`.

The store under bad luck (#1822). Lines to watch for in `docker logs dynasty-server`:
- `Terrain server: cannot start: ... the store folder ... cannot be written. The store is left as it was` means the store is read-only, owned by another user, or the disk is full. The server exits and saves nothing over the store. Fix the folder (owner `dynasty`, writable, space free), then start it again. The start check writes and removes `write_check.json` in the store.
- `SERVER SAVE FAILED: ...` means a save could not be written, most often because the disk is full. The server keeps running, the store stays the last whole save, and the next save tries again. If these lines repeat, free space on the disk.
- `server save: X is from save N, which stopped before it finished ...` appears after a hard stop (a kill or power loss mid-save). X is read from the last whole save, so packs and chests agree, and the half-written file is kept beside it as `X.unfinished`. The `.unfinished` files are safe to leave or to delete once the server has started.
`tools/crash_drill.py --from-store <copy or tar>` kills a server on a throwaway copy of a store, round after round, and checks the store each time. Never point it at the live volume.

CPU setting (Dave 23 Nov 2026: "make the thread/core count a setting we can set for the server to be allowed to use"): `DYNASTY_SERVER_CPUS` in
compose.yaml, default **4**, is how many CPU threads the server plans its own threads round: the main thread, `N - 1` ground makers
and up to 2 idle builders (none at 1 or 2), which work only when the makers have nothing queued, so N is the busy-time count. Set it in a `.env` file beside compose.yaml (`DYNASTY_SERVER_CPUS=6`) or on the command line
(`DYNASTY_SERVER_CPUS=6 docker compose up -d`); `--cpus=N` on the server's own command line wins over it (a thread-planning number, not docker's `--cpus` quota). 0 means every CPU the
container may use. On a 6-core, 12-thread box running five other servers, 4 leaves the others room. The engine's own helper pool still
sees the whole machine; to hold every thread to a set of CPUs, add a cpuset as below. The start line says what was chosen:
`... with 3 worker threads and 2 idle builders (4 usable CPUs of 12, CPU setting 4)`.

CPUs (coordinator decision D-STALL-1, 22 Nov 2026, from David4 tests): never give the server container a CPU quota (`--cpus`, compose `cpus:`). On David4 a 5-CPU quota (cgroup `cpu.max`) with a server and two clients inside gave 50 ms server stalls, because a quota pause stops every thread of the group at once. To keep the server and David4 apart, give the server its own CPUs with a cpuset instead, which never pauses: for example `cpuset: "6-11"` under the service (`docker run --cpuset-cpus 6-11`), with David4 pinned to other CPUs too (on Docker Desktop the numbers are the WSL 2 machine's CPUs, not Windows'). The server counts a cpuset when it picks its thread count (`src/shared/cpu_budget.gd`). Run no game clients inside the server's container. If a quota is set anyway (by hand or on the host), the server log's "items tick slow" line says "container CPU quota throttling rose X ms this tick" (#1481); without a quota that part is not printed.

Prebuilt ground (Dave 23 Nov 2026: "the server doesnt build anything it just serves the prebuilt stuff up to the clients"; plan in
docs/design/SERVER_SCALE.md, "Prebuilt ground for the nine tiles"). The ground of chosen tiles is built on a fast PC and installed into
the store, so the server serves it instead of making it as players walk. Ground not in the pack (caves, other tiles) is still made as
before. The pack also holds the tiles' trees and plants (flora_pack/); the server's start line says
`server flora: prebuilt plants for N chunks in N tiles`, or that a plants file was made from other game files and is not used
(build the pack again from the same commit as the image).
1. Build, on the PC, in a clone at the same commit as the server image (the pack must come from the same tiles; the install refuses
   one that does not). The starter tile takes about an hour (ground about 40 minutes, plants about 20) and 6-10 GB plus about 0.5 GB of plants; a stopped build goes on where it was when run again:
   `& <godot> --headless --path E:\Software\godotDev\dynasty_release --script res://src/worldgen/tools/prebuild_ground.gd -- --tiles=3_4 --out=E:/Software/godotDev/ground_pack`
   Add `--processes=N` to run N copies side by side (much faster: the generator gains little from threads inside one copy;
   `tools/prebuild_sweep.ps1` times several counts; while the copies are joined their parts and the pack both stand, about twice the
   pack's size on disk; a stopped run goes on when run again with the same N). (`--tiles=nine` for all nine tiles, about 6 hours and 55-90 GB plus about 4.5 GB of plants; `--threads=N` to leave the PC some room). It ends with a
   `prebuild_ground: DONE` line.
2. Copy it over: `scp -r E:\Software\godotDev\ground_pack dave@192.168.0.108:/home/dave/dynasty/`
3. Install it, on the server, with the server stopped. The normal case is a new build's clean install, after its step 4 (installing over a running world also works, digs and fills are kept, but a new build never keeps the world):
   `docker compose -f compose.yaml run --rm --no-deps -v /home/dave/dynasty/ground_pack:/pack:ro --entrypoint godot dynasty-server --headless --path /game --script res://src/worldgen/tools/install_ground.gd -- --pack=/pack --store=/data/store`
   which ends with `install_ground: DONE` (or `install_ground: FAILED: <why>`, the store left as it was; after a crash the server's
   run note still says running: add `--server-stopped` at the end once `docker ps` shows the server is down), then
   `docker compose -f compose.yaml up -d`. The copy needs the pack's size free again on the server's disk; the folder
   /home/dave/dynasty/ground_pack can be deleted afterwards.
   To check a store serves the pack without making ground or placing plants (on a copy or a fresh store, never the live one: a store
   from other tiles is cleared on open, as the server does), `src/worldgen/tools/check_ground_pack.gd -- --store=DIR` ends with
   `check_ground_pack: PASS`. All-air blocks are not in the pack: its `air_table/` folder (one file a tile, copied in by the install)
   says from which row each column is air, and the server fills those blocks from it without making or saving them (the 10 s report's
   "air from the table" count). A pack built before the air table still works: the server makes its air blocks as before.

## Join it

From the editor build: run the game with the user arguments `--client-only` (the join page asks for the address) or `--server=<address>` (for example `--server=hannibalshouse.duckdns.org`). On the same network use the gaming server's local address.

## Not done yet

A release (stamped server image plus the players' installer, the same build) is made by `tools/make_release.ps1`: see `deploy/RELEASE.md`. Still to do: running the server from the exported Linux template instead of the editor build, and ghcr.io (open with Dave). The whole world folder ships in the image; a separate world volume is not needed while the world is the nine tracked tiles.
