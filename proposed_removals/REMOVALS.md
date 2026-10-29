# Proposed removals (waiting for Dave's approval)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/builder/ (36 .gd + .uid), scenes/builder/world_builder.* | Sonny, FINAL 793 merge (build 810) | 25 Oct | old world builder, unused since the tile pipeline | tools and src/worldgen |
| world_preview.tscn | Sonny, 793 | 25 Oct | preview scene of the old builder | none |
| worlds/base_world/base_stratigraphy.tres | Sonny, 793 | 25 Oct | resource of the old builder | tile data |
| tools/bake_island_queue.ps1, tools/island_queue.txt | Sonny, 793 | 25 Oct | old bake queue | tools/bake scripts of the tile pipeline |
| src/worldgen/tools/test_pond_outlet.gd | Sonny, 793 | 25 Oct | test of a removed pond rule | none |
Restored here by Tyler on 25 Oct 18:10 UTC from commit 804932bf (the tree just before the 793 merge) so nothing is lost; the live copies stay deleted in the tree until Dave says otherwise. Say "bring it back" on the card to restore any of them.

## Bloat clean-up, 29 Oct 2026 (Claude, branch claude/bloat-safe-removals; audit in NerdRunner/BLOAT_AUDIT_2026-10-29.md)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| scenes/client/client_main.*, scenes/server/server_main.*, src/client/client_world.gd, local_baked_block_store.gd, local_baked_voxel_stream.gd, local_region_provider.gd, src/shared/network_bridge.gd, src/server/server_world_regions.gd | Claude | 29 Oct | old client/server pair, only reachable with --role=client / --role=server, which nothing starts (NET-001 lived here) | "play" role: terrain_server + terrain_client |
| src/shared/baked_region_format.gd, baked_region_reader.gd, baked_world_config.gd, baked_block_codec.gd, baked_voxel_layout.gd, baked_implicit_block_factory.gd, region_catalog.gd, region_manifest.gd, region_mapper.gd | Claude | 29 Oct | old region-file API, used only by the old client and by each other | tile files (src/worldgen/tile) |
| src/shared/geology_properties.gd | Claude | 29 Oct | used only by the old builder (already in this folder) | none |
| src/worldgen/tile/tile_erosion.gd | Claude | 29 Oct | old per-tile erosion, not run since the pre-carve; the baker only borrowed it to hold heights | erosion_delta_v2.bin pre-carve |
| src/worldgen/tools/sonny_wcheck, sketch_ray, pond_profile, water_window, river_ends, profile_join, island_profile, water_surface_check (.gd) | Claude | 29 Oct | one-off diagnostics, referenced by nothing | none |
| tools/gate.sh, gate_queue.sh, gate_nightly.sh | Claude | 29 Oct | David3 (Linux box) gates; that machine no longer runs this project | tools/gate_pc.sh |
| tools/ship_run.sh | Claude | 29 Oct | byte-identical copy of tools/ship.sh, used by nothing | tools/ship.sh |
| worlds/base_world/world_definition.tres, world_preview.png, world_preview_scour.png (+ .import) | Claude | 29 Oct | used only by the old builder | none |
| addons/water_core/bin/~libwatercore.windows.template_release.x86_64.dll | Claude | 29 Oct | leftover temp lock copy of the water DLL (never commit temp DLLs) | the real DLL beside it |
| src/client/crash_breadcrumb.gd.uid | Claude | 29 Oct | orphan: its script is gone | none |
Also removed inside live files (git history keeps them): 23 functions nothing called, about 25 constants nothing read, the never-run water-settle step in src/admin/tile_bake_launcher.gd, client scenery boulders (SCENERY_BOULDERS was false) in grass_view.gd, breathing sounds (BREATHING was false) in breath_sounds.gd, and the launcher roles client/server/builder.

## Finished tools, 29 Oct 2026 (Claude, branch claude/debloat)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/worldgen/tools/analyze_land.gd, flora_map.gd, stitch_water_seams.gd, river_settle_report.gd, terrain_bench.gd, basin_census.gd, river_pits.gd (+ .uid) | Claude | 29 Oct | one-off analysis tools; no script, test or bake references them | none |
