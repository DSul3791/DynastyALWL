# Dev and test box (Docker) for the Ubuntu game server (dell-gameserver-01)
STATUS: written and partly tested in the cloud. The Docker build, the GPU path, the deploy key and Claude Code sign-in have NOT been run on a real Docker host. The jobs inside (selftest, tests, gitcheck, main-push block) were run in the cloud with the same Linux engine.

## What it is
One container `dynasty-testbox`: Godot 4.7.2 + Voxel Tools 1.7 (+ the water core), git, python3, Claude Code. Limits: 8 GB RAM, 2 CPUs, lowest CPU priority, no published ports. Everything under `/data/godot/`: the repo checkout `/data/godot/projects/dynasty` (survives recreation), the deploy key and sign-in `/data/godot/box/`. It never touches your five game containers. It only pushes `claude/*` branches (a hook blocks main).

## Dave's commands (on the server, in this order)
**A. One-time folders and code**
1. `sudo mkdir -p /data/godot/projects/dynasty /data/godot/box/ssh /data/godot/box/out /data/godot/box/claude && sudo chown -R 1500:1500 /data/godot/projects/dynasty /data/godot/box`
2. `git clone https://github.com/DSul3791/DynastyALWL.git ~/dynasty-src && cd ~/dynasty-src && git checkout claude/docker-test-box && cd tools/docker` (only to get the box files; the working checkout is made in step 7)
3. `cp box_settings.json /data/godot/box/claude/settings.json` (what Claude in the box may do; it cannot read your key and cannot push to main)

**B. GPU (NVIDIA GTX 1050 Ti)**
4. On the host: `nvidia-smi` (must show the card and a driver). If missing: `sudo ubuntu-drivers install` then reboot (not while players are on).
5. NVIDIA Container Toolkit (official steps, https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html): add the apt repo, `sudo apt-get install -y nvidia-container-toolkit`, `sudo nvidia-ctk runtime configure --runtime=docker`, `sudo systemctl restart docker` (this restarts Docker: your game containers restart unless they have a live-restore setting; do it in a quiet hour).
6. Check: `docker run --rm --gpus all ubuntu:24.04 nvidia-smi`

**C. Build and GitHub key**
7. `docker compose build` (compiles the engine from source, 30 to 60 minutes once, uses CPU: do it when quiet). Then `docker compose run --rm testbox keygen` and it prints a PUBLIC key.
8. GitHub: repo DSul3791/DynastyALWL > Settings > Deploy keys > Add deploy key, title `dynasty-dev-box`, paste the public key, tick **Allow write access**. (Only the public key goes to GitHub. The private key stays in /data/godot/box/ssh.)
9. `docker compose run --rm testbox update` (clones into /data/godot/projects/dynasty and imports), then `docker compose run --rm testbox gitcheck`. Must show: login works, fetch, push to main is blocked, test branch pushed and deleted.

**D. Self test**
10. `docker compose run --rm testbox selftest` must print `SELFTEST_PASS` and `Test done: 2 pass, 0 fail`.

**E. Claude Code ("Mike2")**
11. First sign-in (you, in the browser, once): `docker compose run --rm testbox claude`, type `/login`, choose your Claude account, open the URL it prints in your own browser, finish there, then `/exit`. Nothing is typed into chat or stored in the repo.
12. Start the remote session: `docker compose up mike2` (first run asks "Trust directory? y" and "Enable Remote Control? y"). It shows a session name "Mike2 test box" in claude.ai/code. Leave it running with Ctrl+P then Ctrl+Q, or later `docker compose up -d mike2`. Stop: `docker compose stop mike2`.
13. Needs your OK: the Remote Control toggle if your plan is Team or Enterprise; the two prompts above; and the deploy key's write access.

**F. Pictures (needs the graphics build; see below)**
14. `docker compose run --rm testbox shot --name spawn_server` makes one picture at the spawn in `/data/godot/box/out/shots/`. Compare with Mike's PC picture of the same spot (look_rig.sh --at 53301,68427).

## Each run (only when Dave allows)
- `docker compose run --rm testbox tests test_worldgen test_slot_sounds` / `queue` / `validate` (local_check)
- `docker compose run --rm testbox godot --headless --path /work/repo --script res://tools/check_addons.gd`
- Pull updates: `... testbox update`. Push: Claude commits to a `claude/*` branch and pushes; you merge by pull request.
- Stop everything at once: `docker stop dynasty-testbox dynasty-mike2`.

## GPU and speed notes
- The 1050 Ti (4 GB) is weaker than your PC, and shares the card with whatever the game containers use: run `nvidia-smi` before a picture job and skip it if the card is busy. Frame times from it are labelled "server GPU" and are not comparable to Mike's PC.
- Without the toolkit the picture job falls back to software rendering (Mesa llvmpipe): works for content checks, is slow (a minute or more per picture) and not pixel-identical.
