# Making a play-test release

Server/client split plan steps C1 to C3 (`/mnt/project-files/server-client-split/PLAN.md`). Dave, 22 Nov 2026: friends are waiting for an installer to play-test; make it work, looks do not matter.

**Status: not yet run.** Nothing here has been built yet; the first run on Dave's PC is the test.

## What it makes

`tools/make_release.ps1`, run in PowerShell on Dave's PC with Docker Desktop, from a full clone at the release commit (main):

1. `deploy/engine/Dockerfile`: compiles our engine (Godot 4.7.2 + Voxel Tools 1.7): the headless Linux editor, the Windows release template (MinGW cross-compile) and the Linux one. About 45 to 90 minutes the first time; Docker keeps it.
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
powershell -ExecutionPolicy Bypass -File tools\make_release.ps1 -Publish
```

Next time: `git pull` in that folder, then the last line again.

On the gaming server: copy `dynasty-server-build-<N>.tar` and `compose.yaml` there, then `docker load -i dynasty-server-build-<N>.tar` and `docker compose -f compose.yaml up -d` (SERVER.md has admin keys, password and ports).

Players: download `DynastySetup-<N>.exe` from the release and run it. Windows SmartScreen warns about an unsigned program: More info, then Run anyway. The server refuses any other build, so when a new build is released, everyone installs it over the old one (the full updater, plan step A6, comes later).

## Known limits

- The bought animal models (`assets/animals`, gitignored) are not in a fresh clone, so the release draws the code-built animals.
- The game is not code-signed.
- `amake/innosetup` is a community image (Inno Setup 6 under Wine) on a floating tag.
