# Project handoff (2026-10-16)

Read this first in a new conversation. It is the short master summary; the details are in the files named below.

## What this is

A multiplayer medieval survival and town-building game: Godot 4.7.x, GDScript, Voxel Tools 1.7, built for weak hardware (older quad-core, 8 GB RAM, SATA SSD). Owner: David Sullivan. Repo `DSul3791/WorldGeneratorV1` (it moved from `WorldGeneratorv1`). Work happens on branch `claude/generator-v2`. Never touch `main`.

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

Steps 2 to 13 are done. Step 13b (rivers across tile edges and edge matching) is nearly done:

- Done: world river network on the 160 m map (`src/worldgen/sketch/river_network.gd`), tiles built on a 640 m margin then cropped (`tile_baker.gd`), world-wide wet-air field, guide-carved rivers, `edge_match.gd` tool, wrap-seamless noise (`wrap_noise.gd`), stored flow = river discharge only. Four neighboring tiles and both wrap-seam pairs match with 0 failures. 837 tests pass.
- Left: rivers show long straight 45 degree runs (the 160 m grid shows through). Add meander to the guide curves in `tile_water.gd` / `river_network.gd`, rebake, rerun the edge check. Then update the plan and commit.
- Then: step 14 (runtime terrain generator that turns the tile maps into 1 m voxel blocks), then step 16 (server streaming to the client with a disk cache). The owner's near-term goal: bake a real tile, run the server, connect a client and see the world.

## Commands

You need a Godot 4.7 headless binary (the one used so far lived in a session scratch folder and will not exist in a new session; download it).

```
godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd        # tests (about 6 min, run in background)
godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- "--tiles=3,4;3,3"   # bake tiles to worlds/base_world/tiles/
godot --headless --path . --script res://src/worldgen/tools/edge_match.gd           # compare neighboring tiles
godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4          # preview pngs in plan/
```

Tile files are git-ignored. The starter tile is (3,4). Bake time is 25 to 70 s per tile (plus about 25 s setup).

## Setup a new session needs

- **Godot 4.7.1 stable, headless (Linux x86_64).** Download it from the Godot releases page, unzip it, and use the binary in the commands above. Nothing carries over from earlier sessions.
- **Voxel Tools 1.7** (Zylann's `godot_voxel`, the add-on that does the voxel terrain). It is not in the repo and not needed yet: the generator only makes 2D maps and runs on plain Godot. It is needed from step 14 (runtime terrain generator) and step 16 (server streaming and the client). It must match the Godot version: use a build made for Godot 4.7 (a custom engine build or the GDExtension release, whichever the project settles on) and put it in the project as the add-on's instructions say. Check the project settings and the roadmap before choosing.
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
