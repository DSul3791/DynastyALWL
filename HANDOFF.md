# NOW (29 Oct 2026)
HEAD = build 826 on `main` plus the October clean-up PRs. Dave plays and tests on his PC; Claude ships through pull requests (`tools/ship.sh`). Read `RULES.md` first. The 25 Oct block that was here (queues, holds, MERGE-793 notes) is in `docs/archive/2026-10/HANDOFF_FULL_2026-10-29.md`.
Open: play-test of `main` after the clean-up; possible bug: `grass_view._rebuild_trails()` is never called, so worn trails are not drawn; remaining clean-up items are listed in NerdRunner/BLOAT_AUDIT_2026-10-29.md (outside the repo, in C:/GodotProjects).

# Project handoff (rewritten 2026-10-22 by the Technical Director; short on purpose)

Read this first. About 10 KB. All older detail is kept, unchanged, in `docs/archive/HANDOFF_FULL_2026-10-22.md` (index at the bottom of this file). Rules and decisions live in the project files `tech/` folder (`/mnt/project-files/tech/`): **BEST_PRACTICES.md (read first, daily), PROCESS.md, DECISIONS.md, JOBS.md, BUILD_LOG.md, TEST_QUEUE.md**.

## What this is
A multiplayer medieval survival and town-building game ("Dynasty, a life well lived"): Godot 4.7.2 (custom build with Voxel Tools 1.7 compiled in), GDScript plus a C++ water core, built for weak hardware (minimum 1050-class GPU, 8 GB RAM, SATA SSD, 30 fps). Owner: David Sullivan (Dave; voice user, wants SHORT reports). Repo `DSul3791/DynastyALWL`. Base branch is `main`. It is protected: changes reach it only through a pull request (builds through `tools/ship.sh`, which opens and merges one with `tools/pr_merge.sh`). Work on a `claude/<topic>` branch off `main`; never push to `main` directly.

## Current state (2026-10-29)
- Development is active. `main` is the base for all code (protected, pull requests only); Dave's questions live on branch `qa`. Build 826 plus the October clean-up (PRs 4 to 9: switch to `main`, bloat removals, plan images untracked, docs archived, one `RULES.md`). Latest build and protocol: `src/shared/build.gd` and the tail of `docs/mirror/tech/BUILD_LOG.md`.
- Decisions and recent state: tail of `docs/mirror/tech/DECISIONS.md`. Open plans: `tech/ACTION_PLANS/`.
- Runtime-only changes need no re-bake; server-side builds need the game closed fully so the server restarts.
- Old per-day state, parked notes and the 23 to 25 Oct bake schedule: `docs/archive/2026-10/HANDOFF_FULL_2026-10-29.md`.

## Working rules (one file: RULES.md; BEST_PRACTICES.md is the reference library)
- Read `RULES.md` first: it replaces TEAM_AND_RULES, HOW_WE_WORK and PROCESS (archived 29 Oct 2026). The lines below are a short copy.
- Before anything NEW, find its entry in `tech/BEST_PRACTICES.md`; none = ask the Technical Director and take another job meanwhile.
- Zero new GDScript warnings; typed code; no `@warning_ignore` without a reason.
- Server and client talk only through `src/stream/terrain_net.gd`; shared code in `src/shared`.
- Every input change updates `CONTROLS.md` and passes `python3 tools/check_controls.py`.
- Questions for Dave: pickable answers only, in `questions/QUESTIONS.md` on branch `qa` (format `questions/README.md` there), answers in `questions/ANSWERS.md` on `qa`. Post with `tools/qa_post.py`; read with `git fetch origin qa && git show origin/qa:questions/ANSWERS.md`. Never merge `qa` and `main` into each other. Test asks go to `tech/TEST_QUEUE.md`. Never wait for Dave: park the job and take the next.
- Before shipping: `git pull --rebase origin main`, conflict-marker grep empty, headless load of touched files, controls check, build number = max(origin BUILD, last BUILD_LOG line) + 1 with the BUILD_LOG line in the same commit. Never commit crash reports, editor logs, temp DLLs or .tile files.
- Confidence rule: technical details decide yourself; thinly discussed design = one short question with your recommended answer.
- Dave's style: SUCCINCT. Test reports "Test done: X pass, Y fail", one line per failure; simple fix = steps, big fix = say so; end posts with "Still waiting on:".
- Performance routine after client/server/streaming/flora/water changes (details in the archive, section "Performance routine").

## Where things are

| File | What it holds |
|---|---|
| `CONTROLS.md` | The player controls, now and planned. Update it when a control changes |
| `DESIGN_IDEAS.md` | The whole game design (16 sections), every decision tagged [Decided] / [Proposed] / [Idea] / [Open]. The permanent home for ideas to raise in design discussions and fold in when they fit; "(brainstorm)" marks ideas from the owner's ChatGPT sessions |
| `DESIGN_REJECTED.md` | Ideas the owner rejected (log them here automatically) |
| `DESIGN_PRINCIPLES.md` | Underlying philosophy (safe, kind, generous; do it yourself or hire it out; nobody is forced to build a town) |
| `GENERATOR_V2_PLAN.md` | Step-by-step plan for the world generator, with progress notes per step |
| `WORLD_FORMAT_SPEC.md` | Permanent file formats (tile file, Section 4b rivers and edge matching) |
| `src/worldgen/` | The generator code; tools in `src/worldgen/tools/` |
| `questions/` (branch `qa`, not in `main`) | Question page for Dave (QUESTIONS.md, ANSWERS.md, qa.html) |
| `data/` | JSON tables (items, network, tunnels, flora, soils, rocks, tile rules) |
| `src/` | admin, builder, client, debug, flora, server, shared, stream, water, worldgen |
| `tools/` | check scripts (check_warnings.sh, check_controls.py, items_check.py, bots.sh, ...) |
| `docs/archive/` | old handoff text, kept verbatim |

## Commands

Use the Linux engine build described under Setup below (`godot` here means that binary).

On Dave's PC (threads running locally via Remote Control, project folder `C:\GodotProjects\DynastyALWL`), `godot` means the editor executable `C:\GodotInstaller\godot.windows.editor.x86_64.exe`. Use it for headless runs and tests, e.g. `& "C:\GodotInstaller\godot.windows.editor.x86_64.exe" --headless --path . --script res://src/worldgen/tools/test_worldgen.gd`. Proven there (2026-10-22): `--script` runs work (validate_items.gd takes about 2 s, 0 errors); the voxel classes and water_core load headless; a bare `--headless --path .` (no `--script`) starts the game launcher and a terrain server, so never use it. The `.sh` tools run through Git bash (`C:\Program Files\Git\bin\bash.exe`) with a `godot` shim on PATH: `printf '#!/bin/sh\nexec "C:/GodotInstaller/godot.windows.editor.x86_64.exe" "$@"\n' > /tmp/gbin/godot; chmod +x /tmp/gbin/godot; PATH=/tmp/gbin:$PATH bash tools/check_warnings.sh` (about 20 s). `gh` is installed and logged in as DSul3791, so PRs can be opened from the PC. Never commit `crash_reports/`, tiles or the `~libwatercore` temp dll.

```
godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd        # tests (about 6 min, run in background)
godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=3,4;3,3"   # bake tiles to worlds/base_world/tiles/
godot --headless --path . --script res://src/worldgen/tools/edge_match.gd           # compare neighboring tiles
godot --headless --path . --script res://src/worldgen/tools/validate_items.gd        # item data validator (ids, numbers, unreachable recipes); also run test_inventory.gd and test_server_items.gd
godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4          # preview pngs in plan/
godot --headless --path . --script res://src/worldgen/tools/terrain_bench.gd -- --tile=3,4      # runtime generator speed and cross-sections
godot --headless --path . --script res://src/worldgen/tools/flora_map.gd -- --tile=3,4         # top-down flora picture around the spawn
godot --path . res://scenes/terrain_preview/terrain_preview.tscn                              # walk the tile (needs a baked tile)
godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=24600     # terrain server
godot --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1           # client (headless check: add --frames=6000 [--dig] [--cut]; --frames=12000 --walk checks landing, walking and tree collisions)
godot --path . -- --role=play                                                                  # host and play: starts a server in the background and joins it (the default role, so pressing Play in the editor does the same)
```

Baked tiles for the inner starters and their neighbors (36 files) are in `/mnt/project-files/tiles/base_world/`; copy them into `worlds/base_world/tiles/` at the start of a session. Tile files are git-ignored except the starter tile `worlds/base_world/tiles/tile_3_4.tile` (about 9 MB, committed so every session has it; recommit it only after a rebake that changes it). The starter tile is (3,4). Bake time is 25 to 70 s per tile (plus about 25 s setup).


## Setup a new session needs
- Cloud engine: unpack `/mnt/project-files/engine/godot-4.7.2-voxel1.7-linux-headless.xz` with `xz -dc file > godot && chmod +x godot`.
- Dave's PC: editor `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, project `C:\GodotProjects\DynastyALWL`; headless via `--script` only (a bare launch starts the game server). Ffmpeg is missing there (sound tools only).
- Baked tiles: `/mnt/project-files/tiles/base_world/` into `worlds/base_world/tiles/`. Git ignores tiles except `tile_3_4.tile`.
- Python 3 for the check tools. No GitHub CLI in the cloud: use the GitHub tools.

## Gotchas (short)
- Headless scripts: use `preload` consts instead of `class_name` globals.
- Run bakes and the test suite in the background and poll (a foreground run over about 10 minutes is killed).
- Commit a new script's `.uid`. Re-read shader edits: a failed compile draws flat grey.
- World is 21x21 tiles (-10..10), wraps both ways; starter tile (3,4); tiles are 1,921 samples at 8 m with an 80 sample margin.
- In the cloud engine a headless load prints no warnings; the warning count comes from the local `tools/check_warnings.sh` run.
