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

## Test system review, 30 Oct 2026 (Tyler, branch claude/tyler-gates-fee5f7)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/worldgen/tools/test_scree.gd (+ .uid) | Tyler | 30 Oct | a report, not a test: no check, cannot fail; needs the baked tile 3,4; writes a PNG to /tmp (fails on Windows); 10 s | none (git mv back and drop the .removed suffix to restore) |

## Dave's sound fixes, 4 Nov 2026 (Jason, branch claude/jason-20261104-wind-stomach)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| assets/audio/cooking/stomach_growl_0.ogg, stomach_growl_1.ogg | Jason | 4 Nov | Dave: "the funny sound that keeps happening is the stomach_growl. get rid of that." The growl and its hunger timer (item_sounds.watch_vitals) are removed | none |

## Docs archive, 5 Nov 2026 (MikeW, branch claude/mikew-20261105-docmap)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| docs/HEAVY_KITS_OPTIONS.md (pointer only) | MikeW for Jamie, Sal told | 5 Nov | superseded by no kits (#292) | docs/archive/2026-11/HEAVY_KITS_OPTIONS.md |

## #524 rebake, 7 Nov 2026 (Sonny, branch sonny-20261107-river-carve-6m)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/worldgen/tools/test_drainage_flow.gd (+ .uid) | Sonny, coordinator's call | 7 Nov | checks the old rule-carved channel shape ("outer bank at least 1.3x the inner bank depth"); the only red test on the #524 nine-tile rebake; planned for archive in TYLER_TEST_SYSTEM_REVIEW.md once natural rivers are on | test_drainage_small (shared fill and flow invariants) and test_drainage_natural (P2 natural rivers) |

## Faster generation, PR C, 9 Nov 2026 (Sonny, branch sonny-gen-speed-c; docs/water/generation_cost_audit.md section 4, approved by Dave: "good make it so. I approve it all.")
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| tools/rebake_check.sh | Sonny, coordinator's call | 9 Nov | ran test_drainage_fill, test_river_surface and test_head_pond_fill after a bake, which the gate runs again on the rebake PR (145 s of each bake run) | the gate's bake class: tools/test_lanes.json lists all three for baked tiles and water |

## After R6: no switches on the readers, nothing placed from the spawn, 9 Nov 2026 (Steve, coordinator; docs/water/stage_e_readers_design.md 6d and 6e, docs/water/watershed_rebuild_design.md "R6 as built")
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/worldgen/tools/orchard_site.gd (+ .uid) | Steve | 9 Nov | found the flat spot near the spawn for the starter orchard; the orchard by the spawn is gone | none |
Also removed inside live files (git history keeps them):
- `tile_geology.gd`: the `ores.placer_traps.on` switch and the old single placer along the whole river below an ore (the trap placers are the only placers now).
- `tile_sites.gd`: the `starter.spawn_picker.on` switch (the spawn is always picked by rule).
- `flora_placer.gd`: the spawn clearing (`CLEAR_SPAWN_M`), the starter orchard by the spawn (`ORCHARD_*`, `orchard_places`, `_orchard_items`, `orchard_ground_ok`); flora layout version 26. The NPC marker clearings stay.
- `spawn_point.gd` `town_shift`, and its use in `server_npcs.gd` (the shipped town no longer moves with the spawn), `flora_placer.gd` and `island_checks.gd`.
- `server_wolves.gd` `near_town` and `animals.json` `wolves.town_keep_m` (the town point was the spawn).
- `drainage_channels.gd` `_keep_spawn_clear` and `SPAWN_GULLY_*`, `tile_rolling.gd` `_spawn_pad` (rule-bake code that no rule switched on).
- Checks: `test_flora_density`'s starter orchard check, `test_wolf_pups`'s town keep-out check, `test_spawn_picker`'s town shift checks.

## Inventory redesign cleanup, 9 Nov 2026 (Kathleen, branch claude/kathleen-inventory-cleanup, #797)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/client/ui/inventory/parchment_tooltip.gd | Kathleen, coordinator approved the cleanup plan (Dave delegated approval while asleep) | 9 Nov | the redesign (docs/ui/inventory_crafting_redesign.md section 10) replaces the parchment card; nothing loads it any more | ArtKit.card in src/client/ui/art_kit.gd (item tooltips, pinned recipe, bulk toast) and the pack's info strip |
| src/worldgen/tools/refilm_water.gd (+ .uid) | Sonny, coordinator approved (settle speed design, docs/design/settle_speed_design.md cut 2) | 9 Nov | its --film pass (the settle's film floor with min_seen_m 0 and min_km2 0 on the saved water) now runs inside the settle before the save, which gives the same bytes (cm rounding) and saves a Godot start and a tile load per tile; its level-fill and --relax modes were unused since 31 Oct and the sim's theta weighting | settle_water.gd with data/water_settle.json film min_seen_m 0, min_km2 0 (rules v13) |

## Old water hub and natural rivers, 9 Nov 2026 (Sonny, branch sonny-flags-water-old, stacked on #848; Steve's flags sweep, coordinator approved)
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| src/water/water_hub.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | the old water hub, run only by the server's `--water-old` switch; the game has run Dynasty water since 1 Nov and nothing else loads it | src/water2/water_hub2.gd |
| src/water2/water_choice.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | kept the Esc > Settings > Gameplay "Old water" switch and told the launcher to pass `--water-old`; both are gone | none (Dynasty water always) |
| src/worldgen/tools/test_water_hub.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | border coupling of the old hub only | test_water_hub2 and test_water_window (src/water2) |
| src/worldgen/tools/test_water_hub_small.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | the old hub's live set and sleep saves | its save-format check moved to src/worldgen/tools/test_water_store.gd; the hub checks to test_water_hub2 |
| src/worldgen/tools/test_water_soak.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | the old hub on the nine real tiles (slow and release lanes); it never ran the game's water | test_water_hub2 (the swap hub on the real starter tile) |
| src/worldgen/tile/drainage_natural.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | natural rivers, behind tile_rules `water.drainage.natural.enabled` (false); not baked since 30 Oct, and record tiles never reach it (docs/water/watershed_rebuild_design.md, natural rivers switch) | the island water record (tools/watershed) |
| src/worldgen/tools/test_drainage_natural.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | tests drainage_natural.gd only | none |
| src/worldgen/tools/test_water_small.gd (+ .uid) | Sonny, coordinator approved (flags sweep) | 9 Nov | runs the live water on natural rivers ground only | the settler's tests (test_water_settle_rules, test_head_pond_fill) and the live sim's (test_water_sim, test_dam_backup, test_water_falls, test_river_hold) |
| assets/audio/body/heartbeat_0.ogg, heartbeat_1.ogg, heartbeat_2.ogg | Steve, Dave's heartbeat order | 10 Nov | the generated lub-dub heartbeat (make_body.py) | assets/audio/heartbeat/Daggorath_Style_Heartbeat_Pulse.wav, the Daggorath pulse (docs/design/heartbeat_design.md) |

## The 2 m region that followed the player, 10 Nov 2026 (Sonny, branch sonny-water-follow-removed; the coordinator's call during Dave's playtest)
No whole files. Removed inside live files (git history keeps them; why, and what a repaired one needs: docs/water/follow_region_repair.md):
- `src/sullivan_water/live/dig_windows.gd`: `follow()`, `_wet_in()`, `FOLLOW_EDGE_M`, `FOLLOW_EVERY_MS`, the `followed` count, the "dug" mark, and the rule that a region nobody dug in closes instead of sleeping (every region is a dug one now).
- `src/water2/water_hub2.gd`: `set_players()` and its call to `follow()`.
- `scenes/terrain_server/terrain_server.gd`: the player positions given to the hub every 2 s.
- `src/worldgen/tools/test_sullivan_water_live.gd`: the four follow checks (replaced by: no dig opens no region, and the 8 m levels go out untouched).

## Tool swing whoosh, 10 Nov 2026 (Kathleen; Dave: "get rid of the swinging sound and only have the thwacking sound when it hits")
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| assets/audio/hits/hit_swing_0.ogg, hit_swing_1.ogg, hit_swing_2.ogg | Kathleen | 10 Nov | the whoosh every tool swing played, hit or miss | none: only the blow sounds (hit_sounds.hit) |
| assets/audio/make_swing.py | Kathleen | 10 Nov | generated the whoosh | none |
Also removed inside live files: hit_sounds.gd swing() with its SWING_* constants and counters, the call in held_item.gd _start_swing, the "swing" row of tools/sound_check.py, and the hit_swing rows of the sound manifest, SOUND_PACK.md and LOUDNESS.md.

## Retired Iron and Steel doorways, 13 Nov 2026
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| assets/ui/item_icons/iron_doorway.png, steel_doorway.png | Claude (BUGLIST-002) | 13 Nov | Dave: "There is no iron or steel door" / "Yes remove them please": Iron - Doorway and Steel - Doorway are retired (their .import files deleted) | none: a saved one loads as Refined - Doorway / Fortified - Doorway, which have their own icons |

## Retired clay plumbing, 14 Nov 2026
| path (under proposed_removals/) | who | date | why | replaced by |
|---|---|---|---|---|
| assets/ui/item_icons/clay_pipe.png, clay_pipe_run.png, clay_pipe_elbow.png, clay_pipe_tee.png | Claude (plumbing PR 3) | 14 Nov | Dave: "I don't think clay plumbing would make sense. We should remove clay plumbing altogether." Clay pipe, Clay - Pipe, Clay - Pipe elbow and Clay - Pipe tee are retired (their .import files deleted) | none: a saved Clay pipe loads as Clay (renames.json); stone channels and wooden pipes carry the water |
Also removed inside live files: the three clay_pipe rows of structures.json and look_table.gd, the "clay" branches of piece_look.gd conduit, the clay_pipe painter of tools/paint_item_icons.py and its rows in tools/paint_look_icons.py.

## Replaced code (deleted outright, Decision 61 as clarified by Dave, 12 Nov 2026)
Code that new code replaced is deleted, not moved here. Add one row per deleted file in the same PR; `tools/merge_check.py` checks that the replacement exists and that nothing still uses the old file. Code with no replacement is an ordinary unused file: move it aside as above.
| deleted path | replaced by (path at HEAD) | who | date | why |
|---|---|---|---|---|
