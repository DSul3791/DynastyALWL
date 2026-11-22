# The Dynasty server in Docker

Server/client split plan step C4 (`/mnt/project-files/server-client-split/PLAN.md`; Dave 18 Nov 2026: the server and the generator stay one build in a Docker container, the testers' platform; the game server container runs on the gaming server beside David4, never inside it).

**Status: not yet run anywhere.** Nothing here has been built or started yet; the first build is the test.

## What is in it

- `Dockerfile`: stage 1 makes the engine (Godot 4.7.2 with Voxel Tools 1.7, headless, by `tools/build_godot_linux.sh`, about 30 to 40 minutes the first time, then cached), or takes a ready binary from `deploy/server/engine/godot`. Stage 2 is Ubuntu 24.04 with the engine and the project in `/game`, imported once at build time.
- It runs the project from source with that engine (`godot --headless --path /game ... terrain_server.tscn -- --dedicated --store=/data/store`), because there are no export templates for our engine yet (plan C1). When C1 lands, the image switches to the exported "Linux Server" preset.
- `run_server.sh` is the container's first process. `docker stop` sends it TERM; it writes `stop.now`, and the server saves and closes with exit 0 (plan A4, PR #1274). Compose allows 90 s for that.
- Everything the server writes lives in the `/data` volume: `/data/store` (ground edits, characters, chests, `admin.json`, `logs/`, `server_run.json`) and Godot's user folder under `/data/home`. A new image keeps the volume, so the world carries on.
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
3. Watch it come up: `docker logs -f dynasty-server` (the first start makes the ground round the spawn, a few minutes). `docker ps` shows "healthy" once it listens.
4. Admins: the store's `admin.json` lists the admin player keys (`docs/design/ADMIN_CHECK.md`; Esc > Admin > "Show my player key" in local Play). Make a file `admin.json` with `{"keys": ["<your key>"]}`, then `docker exec -i -u dynasty dynasty-server sh -c 'cat > /data/store/admin.json' < admin.json` and `docker restart dynasty-server`. The start line in `docker logs dynasty-server` then says "1 admin keys". Without it nobody is an admin there.
5. Name, message and password (optional; `docs/design/SERVER_PICK_PAGE.md`): the store's `server.json`, for example `{"name": "Hannibal's House", "message": "Bring an axe.", "password": "your password"}`, copied in the same way as `admin.json` (`.../data/store/server.json`), then `docker restart dynasty-server`. At start the server replaces `password` in that file with a salted hash, so the password itself is not kept on disk. Or set the password without a file: `DYNASTY_SERVER_PASSWORD=your-password docker compose -f compose.yaml up -d` (compose passes it in; it is only hashed in memory and wins over the file). The start line in `docker logs dynasty-server` says "password: on" or "off". No password = anyone with the address may join. Players get three tries; a computer that gets it wrong five times in a minute waits a minute.
6. The router forwards UDP 24600 and TCP 24601 to the gaming server. The server pick page asks for each server's name, players and padlock on TCP 24601, so it must be forwarded too.

Stop: `docker compose -f compose.yaml down` (saves first). Run without compose, give `docker run` and `docker stop` `--stop-timeout 90` / `-t 90`, or docker kills it after 10 s. Another build: load the new image, then `docker compose -f compose.yaml up -d`. Go back a build: `DYNASTY_TAG=dev-<commit> docker compose -f compose.yaml up -d`.

CPUs (coordinator decision D-STALL-1, 22 Nov 2026, from David4 tests): never give the server container a CPU quota (`--cpus`, compose `cpus:`). On David4 a 5-CPU quota (cgroup `cpu.max`) with a server and two clients inside gave 50 ms server stalls, because a quota pause stops every thread of the group at once. To keep the server and David4 apart, give the server its own CPUs with a cpuset instead, which never pauses: for example `cpuset: "6-11"` under the service (`docker run --cpuset-cpus 6-11`), with David4 pinned to other CPUs too (on Docker Desktop the numbers are the WSL 2 machine's CPUs, not Windows'). The server counts a cpuset when it picks its thread count (`src/shared/cpu_budget.gd`). Run no game clients inside the server's container. If a quota is set anyway (by hand or on the host), the server log's "items tick slow" line says "container CPU quota throttling rose X ms this tick" (#1481); without a quota that part is not printed.

## Join it

From the editor build: run the game with the user arguments `--client-only` (the join page asks for the address) or `--server=<address>` (for example `--server=hannibalshouse.duckdns.org`). On the same network use the gaming server's local address.

## Not done yet

A release (stamped server image plus the players' installer, the same build) is made by `tools/make_release.ps1`: see `deploy/RELEASE.md`. Still to do: running the server from the exported Linux template instead of the editor build, and ghcr.io (open with Dave). The whole world folder ships in the image; a separate world volume is not needed while the world is the nine tracked tiles.
