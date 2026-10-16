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

## Open design items

About 50 are listed in `DESIGN_IDEAS.md` Section 15 (nomadic household, homestead details, NPC role templates, temple cost, and more). Recently logged ideas: road builder, admin mine digger and mountain tunnel builder (Section 8.4 and the sub-section "Road, mine and tunnel builders" in 8.17).
