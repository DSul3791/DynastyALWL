# World Generation Roadmap

> **Old generator.** This file describes the earlier volumetric generator (10 by 10 region tiles, 10,240 m). It stays accurate for that code, which remains in the repository until the new generator replaces it (plan step 19 in `GENERATOR_V2_PLAN.md`). For the current design see `DESIGN_IDEAS.md` and `WORLD_FORMAT_SPEC.md`.

This checklist turns the design discussion into testable project goals. The first release in this project focuses on world generation, safe incremental growth, and server-owned world topology.

## Release 3 acceptance checklist

- [x] Generate one self-contained island tile at a time.
- [x] Use a 10 x 10 storage-region tile (10,240 x 10,240 meters at 1-meter voxels) so tile edges stay aligned at every configured LOD.
- [x] Allow each tile to be placed at a permanent integer tile coordinate without renaming old region files.
- [x] Keep the existing tectonic, folded, faulted, stratigraphic, cave, mineral, erosion, river, lake, and deposit systems.
- [x] Replace the four-corner mountain layout with an inland mountain mass that falls through foothills and plains into an ocean margin.
- [x] Standardize tile boundaries as world-bottom ocean so independently generated tiles meet safely and edge columns bake cheaply.
- [x] Bias exposed northern shores toward rock, cliffs, and cobble.
- [x] Bias sheltered southern shores toward sand, dunes, deltas, and marsh-like deposits.
- [x] Treat the compass bias as an environmental tendency, not a hard north/south material split.
- [x] Skip finalized `.dat` files when a bake resumes.
- [x] Write unfinished output as `.dat.partial`, then atomically promote it only after the region index and header are complete.
- [x] Accept headless command-line controls for tile coordinate, worker count, output folder, and automatic exit.
- [x] Derive a sensible worker default from the machine instead of hard-coding one CPU model.
- [x] Keep shared terrain/hydrology data read-only while region workers run.
- [x] Remove avoidable per-block buffer work from the voxel hot path.
- [x] Put a generator compatibility signature in each newly baked region header.
- [x] Make the server scan all finalized `.dat` files before listening for players.
- [x] Require a complete rectangular region set with no internal or outer holes.
- [x] Permit rectangles such as 10 x 10, 20 x 10, and 20 x 20; do not incorrectly require equal width and depth.
- [x] Make the server the authority for wrap bounds and region mapping.
- [x] Preserve canonical storage-region coordinates separately from wrapped logical coordinates.
- [x] Expose the authoritative region manifest to connecting clients.
- [x] Reject mixed format/generator/seed region sets instead of silently loading an incompatible world.
- [x] Keep seven LOD levels for now, but document that LOD count and visible cutoff treatment are runtime concerns rather than reasons to bake duplicate worlds.
- [x] Include an unattended-bake guide and an incremental-expansion guide.
- [ ] Run script/static checks, project resource checks, and a clean-package check before delivery.

## Performance priorities

1. Avoid generating detailed voxel blocks that the planner can prove are uniform.
2. Avoid repeated geology, cave, mineral, metadata, compression, and checksum work in hot loops.
3. Keep enough independent region jobs to occupy all useful CPU cores.
4. Build the 8-meter surface/hydrology fields once per island tile, not once per region.
5. Make interruption recovery region-granular so completed work is never repeated.
6. Measure stage and region timing so later optimization is based on evidence.

## Deferred runtime work

These goals matter, but are intentionally not mixed into the generation release:

- Hide the visible-distance cutoff with fog, atmospheric scattering, ocean haze, and horizon impostors.
- Tune client view distance independently from the seven stored LODs.
- Stream region payloads from the server instead of relying on the local provider.
- Add live topology expansion. The safe initial rule is to activate a larger complete rectangle on server restart.
- Add persistent player/entity storage keyed by canonical region coordinate plus region-local position.

## Design review

- A complete rectangle is required; a square is not. Requiring only 4 x 4, 6 x 6, or 8 x 8 would prevent the requested 10 x 20 two-island world.
- A tile is 10,240 meters rather than exactly 10,000 meters because storage regions are 1,024 meters wide. This prevents partial region files and keeps every LOD aligned.
- Wrapping applies to the outside edge of the server's active rectangle. Internal island-tile edges are ordinary neighboring ocean, so adding a tile does not create a second wrap boundary.
- All tile borders use a common deep-ocean profile. This makes independently baked neighbors continuous even when their island seeds differ.
- Existing finalized region coordinates never move. Expansion adds coordinates around the existing rectangle and changes only the server's outer wrap bounds.
- A server restart is the activation boundary for new files. This avoids moving wrap targets underneath connected players.
