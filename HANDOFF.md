# Project handoff (rewritten 2026-10-22 by the Technical Director; short on purpose)

Read this first. About 10 KB. All older detail is kept, unchanged, in `docs/archive/HANDOFF_FULL_2026-10-22.md` (index at the bottom of this file). Rules and decisions live in the project files `tech/` folder (`/mnt/project-files/tech/`): **BEST_PRACTICES.md (read first, daily), PROCESS.md, DECISIONS.md, JOBS.md, BUILD_LOG.md, TEST_QUEUE.md**.

## What this is
A multiplayer medieval survival and town-building game ("Dynasty, a life well lived"): Godot 4.7.2 (custom build with Voxel Tools 1.7 compiled in), GDScript plus a C++ water core, built for weak hardware (minimum 1050-class GPU, 8 GB RAM, SATA SSD, 30 fps). Owner: David Sullivan (Dave; voice user, wants SHORT reports). Repo `DSul3791/DynastyALWL`. Work ONLY on branch `claude/generator-v2`; never touch `main` (Dave merges).

## Current state (2026-10-23 night)
- Development is ACTIVE. Latest build 693, protocol 72, TERRAIN_VERSION 25 baked. Terrain B drainage code is merged but OFF (rules drainage_mode false); the first real bake needs Dave's go; no tiles committed.
- Dave tests only at night after the backup (BP-T40); test lines for tonight are in tech/TEST_CARDS_TONIGHT.md; cards are test, picture and Yes/No with a Notes or Why-not box (BP-T36 to T40). Every plan goes to Dave as one Yes/No card per line (BP-T39).
- Live in the test world: tunnel collapse ON (admin switch and cave-in time 2 to 20 min in Esc > Settings, man-made spaces only), braces as spheres of influence, blueprint building NOT built yet (design in items/BLUEPRINT_BUILD_DESIGN.md plus DECISIONS 2026-10-23), twine (ex cordage), spades take shovelfuls from the pack, hoes, ladders, tier designs are drawings only.
- Runtime-only changes need no re-bake; server-side builds need the game closed fully so the server restarts.
- Tomorrow's first 3 jobs: 1. Sal: blueprint build system (mallet, ghosts, foundations, pillars, load limit) once Dave answers the cost-table cards. 2. MikeW and Sonny: 1-tile BAKE-1 test of Terrain B in the second clone; Steve: Esc menu tidy after Dave's 9 answers, then snapping rules with Sal. 3. Kathleen: build the tier looks in the game from Sal's piece ids after Dave answers the round-3 cards.

## Team (2026-10-22, Dave approved)
Coordinator (routing, moderator every 30 min, Dave's reports); Technical Director + Guru (docs, approvals, build numbers, JOBS/DECISIONS/PROCESS, question page, BEST_PRACTICES daily check); Sonny (World: ground, tunnels, bracing, water); Sal_Crafts (was Radar: items, crafting, NPCs, animals, buildings); Steve_ProblemSolver (Systems, was Tyler_002: server, network, HUD, movement, performance, saves); Kathleen_ArtisticDirector (was Kathleen_ArtisticDirector: art, animation, sound); MikeW_LocalAgent (runs on Dave's PC on demand: warnings, headless tests, GPU/visual checks). Workers run on demand from the queue. Details: `tech/TEAM_PROPOSAL.md`, `tech/PROCESS.md`.

## Working rules (pointers; the full text is in tech/)
- Before anything NEW, find its entry in `tech/BEST_PRACTICES.md`; none = ask the Technical Director and take another job meanwhile.
- Zero new GDScript warnings; typed code; no `@warning_ignore` without a reason.
- Server and client talk only through `src/stream/terrain_net.gd`; shared code in `src/shared`.
- Every input change updates `CONTROLS.md` and passes `python3 tools/check_controls.py`.
- Questions for Dave: pickable answers only, in `questions/QUESTIONS.md` (format `questions/README.md`), answers in `questions/ANSWERS.md`. Test asks go to `tech/TEST_QUEUE.md`. Never wait for Dave: park the job and take the next.
- Before pushing: `git pull --rebase origin claude/generator-v2`, conflict-marker grep empty, headless load of touched files, controls check, build number = max(origin BUILD, last BUILD_LOG line) + 1 with the BUILD_LOG line in the same commit. Never commit crash reports, editor logs, temp DLLs or .tile files.
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
| `questions/` | Question page for Dave (QUESTIONS.md, ANSWERS.md, qa.html) |
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

## Index of the archive (`docs/archive/HANDOFF_FULL_2026-10-22.md`, line numbers of that file)
- 1-26: first task, what this is, file table. 27-77: working rules and dated owner decisions (fall columns and water volume, flow x10, river mouths, and more).
- 78-88: generator status (steps 2 to 16). 89-110: commands. 111-131: reading big files, working with David, setup.
- 133-146: gotchas, open design items. 148-169: performance routine, ground loading speed.
- 171-180: "Water and terrain: start here" (outgoing water thread, 2026-10-20). 181-235: water state, open problems, HUD, quality tiers, stances, oxygen, tile-border water, cold generation speed.
