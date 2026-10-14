# Baked Voxel Game — Modular Island Generator

> **Old generator.** This file describes the earlier volumetric generator (10 by 10 region tiles, 10,240 m). It stays accurate for that code, which remains in the repository until the new generator replaces it (plan step 19 in `GENERATOR_V2_PLAN.md`). For the current design see `DESIGN_IDEAS.md` and `WORLD_FORMAT_SPEC.md`.

Godot 4.7 project for deterministic, geology-driven voxel islands stored as independently movable region files.

## What changed in V3

- 10,240 x 10,240 meter island tiles aligned to 10 x 10 storage regions and all seven LODs.
- Permanent `--island-x` / `--island-z` addressing for adjacent or negative-coordinate islands.
- Inland tectonic mountain ranges instead of one wrapped mountain split across four corners.
- Eroded foothills and plains feeding a marine coast and world-bottom abyssal edge.
- Sheltered sandy southern shores and exposed rocky/gravel northern shores.
- Ocean classification at sea level without baking millions of water voxels.
- Resumable, atomic `.dat.partial` output and finalized-file skipping.
- Region headers carrying generator version and canonical world seed.
- Server startup inventory, compatibility checks, hole-free rectangle validation, and authoritative wrap bounds.
- Canonical position mapping for future persistent players, ships, and placed objects.
- Machine-derived worker defaults, per-region timings, and removal of redundant hot-path buffer work.

## Requirements

- Godot 4.7.x with the Voxel Tools classes used by this project (`VoxelBuffer`, `VoxelLodTerrain`, `VoxelStream`, and related types).
- The console/headless executable is recommended for long bakes.

Open `project.godot` for client/server development. For generation and expansion commands, read [GENERATION_GUIDE.md](GENERATION_GUIDE.md). The implementation checklist and follow-on runtime work are in [PROJECT_ROADMAP.md](PROJECT_ROADMAP.md).

The project intentionally ships without baked `.dat` terrain because a full island contains 100 large region files. Run the base `(0,0)` bake before launching the local client or dedicated server.
