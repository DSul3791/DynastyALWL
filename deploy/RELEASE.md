# Making a play-test release

Server/client split plan steps C1 to C3 (`/mnt/project-files/server-client-split/PLAN.md`). Dave, 22 Nov 2026: friends are waiting for an installer to play-test; make it work, looks do not matter.

**Status: not yet run.** Nothing here has been built yet; the first run on Dave's PC is the test.

## What it makes

`tools/make_release.ps1`, run in PowerShell on Dave's PC with Docker Desktop, from a full clone at the release commit (main):

1. `deploy/engine/Dockerfile`: compiles our engine (Godot 4.7.2 + Voxel Tools 1.7): the headless Linux editor, the Windows release template (MinGW cross-compile, with Vulkan and Direct3D 12; untested on a player's PC) and the Linux one. About 45 to 90 minutes the first time; Docker keeps it.
2. `deploy/client/Dockerfile`: exports the "Windows Client" preset with that template: `Dynasty.exe`, `Dynasty.pck` and the water library, with `build_stamp.json` and `client_config.json` (the official server, `-Official`, default `hannibalshouse.duckdns.org:24600`, provisional) inside.
3. `deploy/client/dynasty.iss`: Inno Setup (in a container) makes `DynastySetup-<N>.exe`. It installs for the current user into `%LOCALAPPDATA%\Programs\Dynasty`, with a Start menu entry and an optional desktop shortcut, and needs no administrator.
4. `deploy/server/Dockerfile`: the server image of the same build, stamped, saved as `dynasty-server-build-<N>.tar` with `compose.yaml` and `SERVER.md`.
5. With `-Publish`: a GitHub Release `build-<N>` (marked pre-release) with the installer, made with `gh` (signed in on Dave's PC).

Everything lands in `..\dynasty_export\build-<N>\`.

## Steps

On Dave's PC (PowerShell; not while he plays or a test gate runs):

```
cd E:\Software\godotDev
git clone -b main https://github.com/DSul3791/DynastyALWL.git dynasty_release
cd dynasty_release
powershell -ExecutionPolicy Bypass -File tools\make_release.ps1 -WindowsEditor <path to Dave's Godot 4.7.2 voxel editor .exe> -Publish
```

Next time: `git pull` in that folder, then the last line again.

`-WindowsEditor` exports the game with Dave's own Windows editor, which opens a window for a minute or two: only that way does the export shader baker run (PR #1544 turns it on; it needs a real renderer, so a headless export skips it). Leave it out and the export runs headless in a container, without baked shaders, so shaders compile while playing.

Before any friend gets it (gate review of #1546), with a window, when Dave allows one:

```
powershell -ExecutionPolicy Bypass -File tools\release_first_run.ps1 -Exe ..\dynasty_export\build-<N>\client\Dynasty.exe -Play
```

It starts the exported game twice with a fresh APPDATA, LOCALAPPDATA and TEMP (no cache, settings or characters, as on a friend's PC): once with the default driver and once with `--rendering-driver d3d12`, about 20 s each, and prints the driver line of each. Then `-Play` opens one cold play (Vulkan, 1920x1080 windowed) that runs until the window is closed; its `play.log` has the longest FREEZE and ground-ready lines for the lag thread. The graphics quality is the game's first-start default unless it is changed in Settings during that play. Logs are in `..\dynasty_export\build-<N>\first_run\`. Record both driver lines with the run. Then install `DynastySetup-<N>.exe` once and start it from the Start menu.

On the gaming server: copy `dynasty-server-build-<N>.tar` and `compose.yaml` there, then `docker load -i dynasty-server-build-<N>.tar` and `docker compose -f compose.yaml up -d` (SERVER.md has admin keys, password and ports).

Players: download `DynastySetup-<N>.exe` from the release and run it. Windows SmartScreen warns about an unsigned program: More info, then Run anyway. The server refuses any other build, so when a new build is released, everyone installs it over the old one (the full updater, plan step A6, comes later).

## Known limits

- The bought animal models (`assets/animals`, gitignored) are not in a fresh clone, so the release draws the code-built animals.
- The game is not code-signed.
- `amake/innosetup` is a community image (Inno Setup 6 under Wine) on a floating tag. If `innosetup6-bookworm` is gone, use `amake/innosetup:innosetup6` in `tools/make_release.ps1`.
- Bought animal models: `tools/export_check.py` lets them into a pack (decision 83: copied in on a build machine), but whether play-test downloads, which are public on GitHub, may carry them is Dave's call; until then build from a fresh clone, which has none. The script stops if `assets\animals` is there, unless `-IncludeAnimals` is given, and if a world record folder is there. Keep the release clone for releases only: the editor's import may touch its files.
