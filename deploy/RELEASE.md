# Making a play-test release

Server/client split plan steps C1 to C3 (`/mnt/project-files/server-client-split/PLAN.md`). Dave, 22 Nov 2026: friends are waiting for an installer to play-test; make it work, looks do not matter.

**Status: not yet run.** Nothing here has been built yet; the first run on Dave's PC is the test.

## What it makes

`tools/make_release.ps1`, run in PowerShell on Dave's PC with Docker Desktop, from a full clone at the release commit (main):

1. `deploy/engine/Dockerfile`: compiles our engine (Godot 4.7.2 + Voxel Tools 1.7): the headless Linux editor, the Windows release template (MinGW cross-compile, with Vulkan and Direct3D 12; untested on a player's PC). The Linux release template is left out until the server is exported (nothing uses it yet). About 45 to 90 minutes the first time; Docker keeps it.
2. `deploy/client/Dockerfile`: exports the "Windows Client" preset with that template: `Dynasty.exe`, `Dynasty.pck` and the water library, with `build_stamp.json` and `client_config.json` (the official server, `-Official`, default `hannibalshouse.duckdns.org:24600`, confirmed by Dave 22 Nov 2026) inside.
3. `deploy/client/dynasty.iss`: Inno Setup (in a container) makes `DynastySetup-<N>.exe`. It installs for the current user into `%LOCALAPPDATA%\Programs\Dynasty`, with a Start menu entry and an optional desktop shortcut, and needs no administrator.
4. `deploy/server/Dockerfile`: the server image of the same build, stamped, saved as `dynasty-server-build-<N>.tar` with `compose.yaml` and `SERVER.md`.
5. Only with `-Publish`: a GitHub Release `build-<N>` (marked pre-release) with the installer, made with `gh` (signed in on Dave's PC). The repository is public (Dave, 22 Nov 2026), so that is a public download of a game that holds the bought animal models: use it only on Dave's explicit yes. The default hand-off is the installer file on Dave's PC, shared by his own link.

Everything lands in `..\dynasty_export\build-<N>\`.

## Steps

On Dave's PC (PowerShell; not while he plays or a test gate runs):

```
cd E:\Software\godotDev
git clone -b main https://github.com/DSul3791/DynastyALWL.git dynasty_release
cd dynasty_release
powershell -ExecutionPolicy Bypass -File tools\make_release.ps1
```

Next time: `git pull` in that folder, then the last line again.

`-WindowsEditor` exports the game with Dave's own Windows editor, which opens a window for a minute or two: only that way does the export shader baker run (PR #1544 turns it on; it needs a real renderer, so a headless export skips it). Leave it out and the export runs headless in a container, without baked shaders, so shaders compile while playing.

Before any friend gets it (gate review of #1546), with Docker Desktop running, when Dave allows his PC (windows open, nothing waits on a person):

```
powershell -ExecutionPolicy Bypass -File tools\release_first_run.ps1 -Out ..\dynasty_export\build-<N>
```

Each step has a hard time limit that closes whatever it started:
1. Install `DynastySetup-<N>.exe` silently into `first_run\install`. The script refuses to start when Dynasty is already installed on that PC, because the test would take over that install's uninstall entry.
2. Start the installed game twice with a fresh APPDATA, LOCALAPPDATA and TEMP (no cache, settings or characters, as on a friend's PC), 1200 frames each: once with the default driver and once with `--rendering-driver d3d12`. Each start's driver line is printed. FAIL if a start has no driver line or used another driver.
3. Load the server tar and bring its `compose.yaml` up as a throwaway project. It runs as `dynasty-firstrun` on ports 24700/24701 with its own volume, so it never clashes with Dave's own Play server or touches the real `dynasty_dynasty-data`. The script waits until the server is running.
4. Cold play: the installed game (Vulkan, 1920x1080 windowed, fresh profile) joins that server by itself (`--test`: no pages, no character), stands about two minutes and quits. The script prints the `JOIN: ground ready` line and the longest FREEZE. "Cold" is cold for the game only: the graphics driver's own shader cache may still be warm, so FREEZE times can come out a little low.
5. `compose stop`: the server must save and exit 0 inside the 90 s grace. Then `compose down -v` removes the test container and its volume.
6. Uninstall silently. The install folder and the uninstall entry must be gone.

Docker steps have time limits too. A test container or install left by a cut-off run is removed at the next run. The `docker load` also tags the image `dynasty-server:latest` on that PC, as `make_release.ps1` already did. `-NoServer` skips steps 3 to 5. Logs are in `..\dynasty_export\build-<N>\first_run\`; record the driver lines, the ground ready line and the longest FREEZE with the run.

On the gaming server: copy `dynasty-server-build-<N>.tar` and `compose.yaml` there, then `docker load -i dynasty-server-build-<N>.tar` and `docker compose -f compose.yaml up -d` (SERVER.md has admin keys, password and ports).

Players: download `DynastySetup-<N>.exe` from the release and run it. Windows SmartScreen warns about an unsigned program: More info, then Run anyway. The server refuses any other build, so when a new build is released, everyone installs it over the old one (the full updater, plan step A6, comes later).

## Known limits

- The bought animal models (`assets/animals`, gitignored by licence) go inside the game's pack (Dave, 22 Nov 2026: "incorporated right in with the game"). The script copies them, read only, from `-AnimalsFrom` (default `C:\GodotProjects\DynastyALWL\assets\animals`, Dave's game folder, never changed) into the release clone, and stops if there are none; `-NoAnimals` builds without them. They are never committed, never uploaded loose, and never in the server image.
- The game is not code-signed.
- `amake/innosetup` is a community image (Inno Setup 6 under Wine) on a floating tag. If `innosetup6-bookworm` is gone, use `amake/innosetup:innosetup6` in `tools/make_release.ps1`.
- The script stops if a world record folder is in the release clone. Keep that clone for releases only: the editor's import may touch its files.
