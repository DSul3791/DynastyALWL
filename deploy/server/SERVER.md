# The Dynasty server in Docker

Server/client split plan step C4 (`/mnt/project-files/server-client-split/PLAN.md`; Dave 18 Nov 2026: the server and the generator stay one build in a Docker container, the testers' platform; the game server container runs on the gaming server beside David4, never inside it).

**Status: not yet run anywhere.** Nothing here has been built or started yet; the first build is the test.

## What is in it

- `Dockerfile`: stage 1 makes the engine (Godot 4.7.2 with Voxel Tools 1.7, headless, by `tools/build_godot_linux.sh`, about 30 to 40 minutes the first time, then cached), or takes a ready binary from `deploy/server/engine/godot`. Stage 2 is Debian slim with the engine and the project in `/game`, imported once at build time.
- It runs the project from source with that engine (`godot --headless --path /game ... terrain_server.tscn -- --dedicated --store=/data/store`), because there are no export templates for our engine yet (plan C1). When C1 lands, the image switches to the exported "Linux Server" preset.
- `run_server.sh` is the container's first process. `docker stop` sends it TERM; it writes `stop.now`, and the server saves and closes with exit 0 (plan A4, PR #1274). Compose allows 90 s for that.
- Everything the server writes lives in the `/data` volume: `/data/store` (ground edits, characters, chests, `admin.json`, `logs/`, `server_run.json`) and Godot's user folder under `/data/home`. A new image keeps the volume, so the world carries on.
- The world (the nine baked tiles of `worlds/base_world`) is inside the image.
- Health check: healthy once `/data/store/server_run.json` exists (the server is listening).

## Build (on the machine with Docker)

From a full clone of DynastyALWL at the commit to run (dev for testing, main for a release):

```
deploy/server/build_image.sh            # test image of this commit: dynasty-server:dev-<commit> and :latest
deploy/server/build_image.sh --stamp    # release image: dynasty-server:build-<N> and :latest
```

A test image has no build stamp, so the game run from the editor can join it. A stamped image refuses every other build, the editor included, so it only makes sense once there is an exported client of the same build.

To skip the engine compile, copy a ready Linux engine (for example David4's `/work/bin/godot`, the same engine) to `deploy/server/engine/godot` first. It must run on Debian 12 (bookworm).

## Run (on the gaming server)

1. Get the image there. Either build it there (above), or on the PC: `docker save dynasty-server:latest | gzip > dynasty-server.tar.gz`, copy the file over, and on the server `docker load < dynasty-server.tar.gz`. (Plan pick for later: push to ghcr.io, not yet agreed.)
2. Copy `compose.yaml` there and start it: `docker compose -f compose.yaml up -d`.
3. Watch it come up: `docker logs -f dynasty-server` (the first start makes the ground round the spawn, a few minutes). `docker ps` shows "healthy" once it listens.
4. Admins: the store's `admin.json` lists the admin player keys (`docs/design/ADMIN_CHECK.md`; Esc > Admin > "Show my player key" in local Play). Make a file `admin.json` with `{"keys": ["<your key>"]}`, then `docker cp admin.json dynasty-server:/data/store/admin.json` and `docker restart dynasty-server`. Without it nobody is an admin there.
5. The router forwards UDP 24600 and TCP 24601 to the gaming server.

Stop: `docker compose -f compose.yaml down` (saves first). Another build: load the new image, then `docker compose -f compose.yaml up -d`. Go back a build: `DYNASTY_TAG=dev-<commit> docker compose -f compose.yaml up -d`.

The server takes the CPUs Docker gives it (`src/shared/cpu_budget.gd` reads a container limit). On the machine David4 shares, a limit such as `cpus: "6"` under the service keeps the two from slowing each other.

## Join it

From the editor build: run the game with the user arguments `--client-only` (the join page asks for the address) or `--server=<address>` (for example `--server=hannibalshouse.duckdns.org`). On the same network use the gaming server's local address.

## Not done yet

The exported server (C1 templates), stamped releases with an exported client (C2/C3), ghcr.io (open with Dave). The whole world folder ships in the image; a separate world volume is not needed while the world is the nine tracked tiles.
