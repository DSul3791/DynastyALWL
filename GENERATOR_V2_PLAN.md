# New Generator Plan

Working plan for the new world generator described in `DESIGN_IDEAS.md` (Sections 4.1 to 4.11) and `WORLD_FORMAT_SPEC.md`. Each step ends with something that can be seen or measured before the next step starts. Work happens on branch `claude/generator-v2`; `main` stays untouched until the new generator replaces the old one.

## Ground rules

- New code lives in its own folder, `src/worldgen/`. The old volumetric pipeline stays untouched and working until the new one replaces it, then it is retired in one step.
- Every step is tested in headless Godot 4.7 before it is shown. Timings are recorded.
- Permanent formats follow `WORLD_FORMAT_SPEC.md`. Any change to them updates the spec first.
- Reuse what already works: tile coordinates, region mapping and wrapping, the resumable atomic write pattern, the 2D hydrology (ocean mask, flow, lakes, channels) and the SHA-256 seeds.

## Steps

### Preparation

1. **Voxel Tools build.** The project uses Voxel Tools compiled into Godot (there is no addon folder), so terrain steps need a matching Linux build in Claude's workspace. The project owner uses Godot 4.7.2 stable (custom build `ed1daf0bf`) with Voxel Tools 1.7. Get or compile a matching Linux build (Godot 4.7.2 source plus the Voxel Tools 1.7 module) before step 14.
2. **Folder layout and branch.** Create `src/worldgen/` with subfolders for settings, tables, matrix, tile pipeline, tile file and runtime. Create branch `claude/generator-v2`.

### Planning the world (no terrain yet)

3. **World settings.** `worlds/<world>/world.json` with identity, geometry, climate curve and runtime-tunable values, plus a loader that validates it. The climate function (latitude, temperature, altitude) lives here.
4. **Data tables.** Append-only ID tables for biomes, soils, rocks, resources, water classes, site types and feature types.
5. **Tile matrix randomizer.** Fills `plan/tile_matrix.json` for all 441 tiles: ocean, peers, or main island with satellites; locked starter tiles; reproducible from the seed; locked cells preserved.
6. **Whole-world preview.** One image of all tiles (islands, climate zones, starter tiles) and a text summary (land per zone, islands per size class). **Checkpoint:** the project owner reviews and tunes the odds.

### Building one tile (2D maps)

7. **Island layout and elevation.** From a matrix cell: land masks with irregular coasts and islets, height from coast distance, mountain spines and ridges, shelves down to the -2,000 m ocean edge. Preview image.
8. **Water.** Adapt the existing hydrology to the new height field: rivers, lakes, flow. Preview image.
9. **Erosion.** A 2D erosion pass for valleys and winding terrain. Timed.
10. **Climate, biome and soil.** Temperature, moisture, rain shadow, biome, soil, fertility. Preview images.
11. **Geology and ore.** Provinces, features (intrusions, faults, basins, volcanic), ore bodies with stable IDs, layer offsets and cover depth.
12. **Sites.** Cave systems, mineshafts, labyrinths, dormant lairs, harbors, and starter data for starter tiles.
13. **Tile file.** Writer and reader for the container in the spec (sections, Zstandard, SHA-256, atomic rename), plus low-resolution maps. **Checkpoint:** bake a starter tile end to end, record the time and file size.

### Seeing it in the game

14. **Runtime terrain generator.** Turn the maps and lists into 1 m voxels: interpolation, detail noise, rock layers, caves, ore. Compare Voxel Tools' graph generator, a GDScript generator and, if needed, a small C++ one. **Checkpoint:** walk the tile in Godot and measure generation speed.
15. **Flora at runtime.** Trees and plants placed from biome, moisture and the flora seed.
16. **Server streaming and client cache.** Server-generated blocks streamed to clients, the generated block cache, the edits store and the client disk cache with a size limit.
17. **Minimum machine test.** The project owner runs the client on the older quad-core and reports frame rate and memory.

### Finishing

18. **Bake the inner starter tiles** and their neighborhoods.
19. **Retire the old pipeline** and update `README.md`, `GENERATION_GUIDE.md` and `PROJECT_ROADMAP.md`.
