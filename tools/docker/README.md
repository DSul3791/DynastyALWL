# Test box (Docker) for tests on the Ubuntu game server
Untested on a real Docker host (the cloud has no Docker daemon). The jobs inside (run_jobs.sh, selftest.gd) were run in the cloud with the same Linux engine binary.

## What it is
One container, `dynasty-testbox`: Godot 4.7.2 + Voxel Tools 1.7 (headless Linux), git, python3. It clones the public repo into a volume and runs the same test jobs as tools/mike_batch.sh (not the rig/picture rows: no graphics card). Limits: 2 CPUs, 8 GB RAM, lowest CPU priority, no published ports. It never touches the game containers.

## Dave's commands (on the server, one time)
1. `sudo mkdir -p /srv/testbox/work /srv/testbox/out` (or a folder on the 389 GB game drive; then use that path as DATA_DIR in step 4). `sudo chown -R 1500:1500 /srv/testbox`
2. `git clone https://github.com/DSul3791/DynastyALWL.git ~/dynasty && cd ~/dynasty && git checkout claude/docker-test-box && cd tools/docker`
3. `docker compose build` (builds the engine from source: 30-60 min, uses CPU; do it when the games are quiet. Add `--build-arg ENGINE=file` only if you already have the engine .xz in tools/docker/engine/).
4. `DATA_DIR=/srv/testbox docker compose run --rm testbox selftest`  -> must print `SELFTEST_PASS` and `Test done: 2 pass, 0 fail`.

## Each run (only when Dave allows)
- `docker compose run --rm testbox tests test_worldgen test_slot_sounds` (parse scan, item validator, then the named tests)
- `docker compose run --rm testbox queue` (the branch/test lines of tools/mike_queue.txt)
- Results: `/srv/testbox/out/<stamp>/` and one line `Test done: N pass, M fail`.
- Stop it at once: `docker stop dynasty-testbox`.

## Not in the box
Bakes (stay on Mike's PC), pictures and frame time (need a GPU).
