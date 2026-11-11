# Project handoff: commands, setup, gotchas
> **Read first (11 Nov 2026).** This repo file is the commands and setup sheet only. It is not the project handoff. The current state, roles and rules are in `docs/START_HERE.md` and `RULES.md`, and the team handoff is `HANDOFF.md` in the project's shared folder (`/mnt/project-files/HANDOFF.md`), which has the same file name as this one. Some lines below are from October and are out of date; they are marked *(stale)*. Dave's law: no tests and no bakes run in the cloud; the commands below run on Dave's PC or on the David4 test machine.
**Current state, roles and rules: `docs/START_HERE.md`, `docs/handoff/` and `RULES.md`.** This file keeps only what does not change: where things are, commands, setup, gotchas. The 29 Oct state, the October working-rules copy and the 22 Oct "What this is" text are in `docs/archive/2026-11/HANDOFF_2026-10-29_state_and_rules_copy.md` and `docs/archive/2026-10/HANDOFF_FULL_2026-10-29.md`.

## Where things are

| File | What it holds |
|---|---|
| `CONTROLS.md` | The player controls, now and planned. Update it when a control changes |
| `DESIGN_IDEAS.md` | The whole game design (16 sections), every decision tagged [Decided] / [Proposed] / [Idea] / [Open]. The permanent home for ideas to raise in design discussions and fold in when they fit; "(brainstorm)" marks ideas from the owner's ChatGPT sessions |
| `DESIGN_REJECTED.md` | Ideas the owner rejected (log them here automatically) |
| `DESIGN_PRINCIPLES.md` | Underlying philosophy (safe, kind, generous; do it yourself or hire it out; nobody is forced to build a town) |
| `docs/archive/2026-11/GENERATOR_V2_PLAN.md` | Step-by-step plan for the world generator, with progress notes per step (archived 5 Nov 2026: done; current rules in `DESIGN_IDEAS.md`) |
| `WORLD_FORMAT_SPEC.md` | Permanent file formats (tile file, Section 4b rivers and edge matching) |
| `src/worldgen/` | The generator code; tools in `src/worldgen/tools/` |
| `questions/` (branch `qa`, not in `main`) | *(stale)* Old question page for Dave. Decision 46 (11 Nov 2026): the QA artifact page is the only QA channel; these cards are being copied there and then retired |
| `data/` | JSON tables (items, network, tunnels, flora, soils, rocks, tile rules) |
| `src/` | admin, builder, client, debug, flora, server, shared, stream, water, worldgen |
| `tools/` | check scripts (check_warnings.sh, check_controls.py, items_check.py, bots.sh, ...) |
| `docs/archive/` | old handoff text, kept verbatim |

## Commands

`godot` means `tools/godot` (the voxel build); see `docs/START_HERE.md` for the two Godot builds.

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

Baked tiles for the inner starters and their neighbors (36 files) are in `/mnt/project-files/tiles/base_world/`; copy them into `worlds/base_world/tiles/` at the start of a session. *(stale: since the nine-tile bake, `.gitignore` tracks all nine tiles 2_3 to 4_5, so a fresh clone has them and no copy is needed.)* Tile files are git-ignored except the starter tile `worlds/base_world/tiles/tile_3_4.tile` (about 9 MB, committed so every session has it; recommit it only after a rebake that changes it). The starter tile is (3,4). Bake time is 25 to 70 s per tile (plus about 25 s setup).


## Setup a new session needs
- *(stale: cloud tests and bakes are banned since 5 Nov 2026.)* (Cloud sessions only, October; local PC sessions skip these two lines.) Cloud engine: unpack `/mnt/project-files/engine/godot-4.7.2-voxel1.7-linux-headless.xz` with `xz -dc file > godot && chmod +x godot`.
- Dave's PC: editor `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, project `C:\GodotProjects\DynastyALWL`; headless via `--script` only (a bare launch starts the game server). Ffmpeg is missing there (sound tools only).
- *(stale)* Baked tiles (cloud copy): `/mnt/project-files/tiles/base_world/` into `worlds/base_world/tiles/`. Git ignores tiles except `tile_3_4.tile`. (Now all nine starter-area tiles are tracked in git.)
- Python 3 for the check tools. No GitHub CLI in the cloud: use the GitHub tools.

## Gotchas (short)
- Headless scripts: use `preload` consts instead of `class_name` globals.
- Run bakes and the test suite in the background and poll (a foreground run over about 10 minutes is killed).
- Commit a new script's `.uid`. Re-read shader edits: a failed compile draws flat grey.
- World is 21x21 tiles (-10..10), wraps both ways; starter tile (3,4); tiles are 1,921 samples at 8 m with an 80 sample margin.
- In the cloud engine a headless load prints no warnings; the warning count comes from the local `tools/check_warnings.sh` run.
