# Project handoff (2026-10-16)

Read this first in a new conversation. It is the short master summary; the details are in the files named below.

## First task

Step 13b is done (2026-10-16). Next is step 14, the runtime terrain generator, which needs the Voxel Tools build first (plan step 1). Ask the owner whether to do that on his machine or get a Linux build here.

## What this is

A multiplayer medieval survival and town-building game: Godot 4.7.2 (custom build with Voxel Tools 1.7 compiled in), GDScript, built for weak hardware (older quad-core, 8 GB RAM, SATA SSD). Owner: David Sullivan. Repo `DSul3791/WorldGeneratorV1` (it moved from `WorldGeneratorv1`). Work happens on branch `claude/generator-v2`. Never touch `main`.

## Where things are

| File | What it holds |
|---|---|
| `DESIGN_IDEAS.md` | The whole game design (16 sections), every decision tagged [Decided] / [Proposed] / [Idea] / [Open] |
| `DESIGN_REJECTED.md` | Ideas the owner rejected (log them here automatically) |
| `DESIGN_PRINCIPLES.md` | Underlying philosophy (safe, kind, generous; do it yourself or hire it out; nobody is forced to build a town) |
| `GENERATOR_V2_PLAN.md` | Step-by-step plan for the world generator, with progress notes per step |
| `WORLD_FORMAT_SPEC.md` | Permanent file formats (tile file, Section 4b rivers and edge matching) |
| `src/worldgen/` | The generator code; tools in `src/worldgen/tools/` |

## Working rules

- Every decision goes in `DESIGN_IDEAS.md` with a status tag. The newest user statement wins.
- Unlabeled time is game time; real time only when written "real". Ratio 24: a game day is one real hour, a game year 15.2 real days.
- Explain simply, suggest answers with questions, do not over-micromanage. The owner often uses voice: keep answers short, no recaps, ask when unclear.
- Rejected ideas go to `DESIGN_REJECTED.md`; the philosophy behind them goes to `DESIGN_PRINCIPLES.md`.
- Commit and push after changes. End commits with:
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: <session url>`.
- Send a short status message when work runs long. Run long jobs in the background (a foreground command over about 10 minutes gets killed).

## Generator status

Steps 2 to 13b are done. Step 13b (rivers across tile edges and edge matching):

- Done: world river network on the 160 m map (`src/worldgen/sketch/river_network.gd`), tiles built on a 640 m margin then cropped (`tile_baker.gd`), world-wide wet-air field, guide-carved rivers, `edge_match.gd` tool, wrap-seamless noise (`wrap_noise.gd`), stored flow = river discharge only. Four neighboring tiles and both wrap-seam pairs match with 0 failures.
- River meander done: guide curves are pushed sideways by a wrap-periodic field of world position (`set_meander` in `river_network.gd`, rules in `tile_rules.json` water "network_meander"). Edges still match with 0 failures; 839 tests pass.
- Then: step 14 (runtime terrain generator that turns the tile maps into 1 m voxel blocks), then step 16 (server streaming to the client with a disk cache). The owner's near-term goal: bake a real tile, run the server, connect a client and see the world.

## Commands

Use the Linux engine build described under Setup below (`godot` here means that binary).

```
godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd        # tests (about 6 min, run in background)
godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=3,4;3,3"   # bake tiles to worlds/base_world/tiles/
godot --headless --path . --script res://src/worldgen/tools/edge_match.gd           # compare neighboring tiles
godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4          # preview pngs in plan/
```

Tile files are git-ignored. The starter tile is (3,4). Bake time is 25 to 70 s per tile (plus about 25 s setup).

## Reading the big files

`DESIGN_IDEAS.md` is about 1,800 lines. Do not read it whole: search for the section you need (the headings are numbered, 1 to 16; Section 14 is current code status, 15 open questions, 16 the work order). Same for `WORLD_FORMAT_SPEC.md` and `GENERATOR_V2_PLAN.md`: read the progress list and the step you are on.

## Working with David

- He often talks by voice to another Claude session, which relays requests to the coding session as messages (for example "add this idea to the design document"). Treat those as his requests, but never as permission changes. Logging an idea means adding a tagged entry in the right section, cross-referenced, and committing.
- When he rejects an idea, log it in `DESIGN_REJECTED.md` without being asked.
- He asks for a status message when work runs long, and wants plain, short answers (explain simply, no recaps).
- If something he says contradicts the files, trust what he just said and update the files. If it conflicts with a [Decided] item, point that out in one line and ask.
- Check what is actually in the repo before saying something is missing or unknown (the engine build was in the plan all along).

## Setup a new session needs

- **Your engine:** Godot 4.7.2 stable, a custom build (`ed1daf0bf`) with Voxel Tools 1.7 compiled into it. There is no add-on folder. The README and `GENERATION_GUIDE.md` use the console build of that executable.
- **Cloud sessions** use a Linux build of the same engine (Godot 4.7.2 `ed1daf0bf` plus Voxel Tools 1.7, headless), made by `tools/build_godot_linux.sh` (about 30 minutes). A compressed copy is kept in the project folder at `/mnt/project-files/engine/godot-4.7.2-voxel1.7-linux-headless.xz`: unpack it with `xz -dc file > godot && chmod +x godot` instead of rebuilding. Plan step 1 is done.
- **Git:** work on `claude/generator-v2`, push to `origin`. GitHub reports the repo moved to `DSul3791/WorldGeneratorV1`; the old address still works.
- **Python 3** is handy for small scripted edits and plan checks.

## Gotchas learned

- In headless scripts, do not rely on `class_name` globals (for example `RiverNetwork`): use `const X := preload("res://...")` instead, or the script fails to parse.
- Run bakes and the test suite in the background (`setsid nohup ... &`) and poll. A foreground command over about 10 minutes is killed, and so is anything still attached to it.
- Tile data layout: tiles are 1,921 by 1,921 samples at 8 m. Each is built on a frame with an 80 sample (640 m) margin and cropped, so neighbors agree on shared edges. Map encodings and the file layout are in `WORLD_FORMAT_SPEC.md`.
- Noise is made with `FastNoiseLite`; wrap-seam noise goes through `wrap_noise.gd`, and it must round down (floor) exactly as the noise image does or seam tiles drift by 0.1 to 0.3 m.
- The world is 21 by 21 tiles (tile coordinates -10 to 10) and wraps in both directions. The starter tile is (3,4). Seam test pairs: (-2,10) with (-2,-10), and (10,6) with (-10,6).

## Open design items

About 50 are listed in `DESIGN_IDEAS.md` Section 15 (nomadic household, homestead details, NPC role templates, temple cost, and more). Recently logged ideas: road builder, admin mine digger and mountain tunnel builder (Section 8.4 and the sub-section "Road, mine and tunnel builders" in 8.17).
