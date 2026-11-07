# Stage E readers and the systems that depend on the water (design)

Steve, 7 Nov 2026. This doc covers what the coordinator assigned to me, with Dave's approval: Stage E readers and the dependent systems in section 7 of `docs/water/watershed_rebuild_design.md` (#535, "the rebuild design").

The goal is that when Sonny's R6 island water record lands, every system that uses water reads that record and none of them break. Those systems are:
- spawn;
- caves and dens (bears and goblins);
- climate, biomes and flora;
- placer gold;
- falls and water sounds;
- NPC markers;
- tests.

The governing document is Dave's `docs/water/Dynasty_How_Natural_Watersheds_Work.md` ("the watershed document"). It says (section 14) that it "does not authorize a replacement architecture". So this design keeps every existing seam: the tile file sections, `tile_terrain_data.gd`, and the server's callables. It changes what the data behind them comes from. **No code until Sonny agrees the record shape (section 3).**

## 1. The rule

Water is worked out once, in the record (Stage D). Every other system asks the record and never works water out again.

Today several systems each run their own version:
- the climate uses the 160 m world river guide lines (`RiverNetwork.guides_in`);
- the sites search for brook heads again (`tile_sites._brook_heads`);
- the placers walk the `flow` map;
- the animals probe the live sim for "near fresh water".

That is the same root cause the rebuild design names for the water bugs: several systems disagreeing about where the water is. Génevaux et al. (2013) build terrain and feature placement from one river network for the same reason.

There are two sides, and each keeps its seam:

| side | today's seam | stays | what changes |
|---|---|---|---|
| bake (tile_baker, island_checks) | `water` object (tile_water.gd: heights, water_class, water_surface, flow, cave_heads) passed to climate, land_types, geology, sites | the call order in `tile_baker.bake` | a `WaterRecord` reader (section 4) replaces the `water` object as the source |
| runtime (server, client) | tile file sections read by `tile_terrain_data.gd`; the live 2 m and 8 m sims | section names, `tile_terrain_data` fields, server callables | sections are written from the record; a few sections are added (section 5) |

The live sim stays the truth at runtime, because players' ditches change it (rebuild design, Stage E). Everything that already reads the live sim needs only the sim to be seeded from the record. That seeding is Sonny's R7. The systems in this group are:
- water sounds (`water_sounds.gd`);
- falls (`water_falls.gd`, `fall_mist.gd`, `fall_growth.gd`);
- the animals' `water_level`;
- swimming.

## 2. What each system reads today, and what it will read

| system | file | reads today | will read from the record | migration notes |
|---|---|---|---|---|
| Spawn | `src/shared/spawn_point.gd` | a constant `OVERRIDE` (moved by hand on 6 Nov when the rivers moved); `island_checks --spawn-search` and `test_spawn_dry` check it after a bake | a spawn chosen by a rule at bake time from the record (dry, not in a floodplain or wetland, gentle slope, a short walk from a perennial reach, in the starter tile near the bay). The bake writes it to the starter tile's header; `spawn_point.gd` reads it and keeps `OVERRIDE` only as the fallback when the tile has none | systemic, per Dave's "move the spawn, do not adjust heights": every rebake picks again, so nobody moves it by hand again |
| Spring caves | `tile_sites.gd` `_make_spring_caves`, `_brook_heads`, `cave_heads` (drainage_channels) | brook heads found again from heights and `water_class`; the cave head flag from the old drainage | the record's cave springs (C7): mouth position, flow, rock, underground catchment. A cave is built only where the record has one, with stream width from its flow | `_brook_heads` and the cave-head search are retired. Spring caves become rare by construction (C7) |
| Dry caves | `tile_sites.gd` `_make_karst`, `_make_lava_tubes`, `_make_sea_caves`, `_make_shelters` | rock and slope (no water) | unchanged, plus a check that no mouth sits under the record's water level or in a wetland | these become the main den source (next row) |
| Goblin dens | `tile_terrain_data.gd` `goblin_dens`, `goblin_den_mouths` (60% of spring caves with a side branch, Dave 7 Nov "any spring tunnel"); `terrain_server` `lair_mouths` to `server_animals` | spring caves only | dry side branches of any cave (karst, lava tube, spring cave). Choosing by cave id stays. `lair_mouths` keeps its signature | needed because far fewer spring caves remain (rebuild design section 7). Dave's rule "any spring tunnel" needs a fresh reading: **question for Dave, via the coordinator** (section 7, Q1) |
| Bear dens and "near fresh water" habitats | `server_animals.gd` `_habitat_score` with `near_fresh_water_m` from `_water_near`, which probes the live `water_level` | live sim water nearby (including puddles and ditch water, and nothing until the sim has settled) | a baked `fresh_m` section: the distance to perennial fresh water (reach, lake or spring) in 8 m cells, with an intermittent flag. `_water_near(fresh)` reads it through a new callable `fresh_water_m(x, z)` | the den then sits by a real river, as Dave's bear rule says ("near river by den, fishes"). Fishing still uses the live water level |
| Climate and moisture | `tile_climate.gd` `build`, `use_world_fresh_water` (world river guide points) | `water_class` plus the 160 m world river guides, which the rebuild retires | the record's reach, lake and wetland raster for the "near fresh water" bonus, and its depth to the water table for soil wetness | with the guides retired, this has to change at R6 or the climate loses its rivers |
| Biomes and land types | `tile_land_types.gd` `apply`, `farmland`; `data/tables/biomes.json` | `water_class` 0 to 3 | new water classes: wetland by type (marsh, swamp, fen, bog) and seasonal water. Each wetland type maps to a biome row | the biome rows and their flora are MikeW's data. I give the class codes and the map, and MikeW gives the rows |
| Flora placement | `flora_placer.gd`, `flora_view.gd` | sections `water_class`, `water_surface`, `moisture` | the same sections; new class codes treated as wet ground until MikeW's rows exist | flora must never plant dry upland plants in a permanent marsh (a never-see item) |
| Placer gold and tin | `tile_geology.gd` `_find_placers` | `water_class` plus `flow` | record reaches downstream of a gold or tin body that reaches the ground, at the places where the water slows: where a steep reach meets a gentler one, inside bends, below falls, at confluences (USGS placer Au model; gold-rush guides on bends and riffles) | the same ore bodies; only the stream positions change |
| Falls | `water_falls.gd` (from live sim levels) | live sim | unchanged (live). The record's falls list gives the lip rock and the hard bed at bake time (R5 and C5 "falls only where the bed drops sharply over hard rock") | nothing new for me; the sim is seeded in R7 (Sonny) |
| Water sounds | `water_sounds.gd`, `cave_water_sounds.gd` | live sim; `cave_streams` | unchanged; cave streams come from the record's cave springs (row above) | |
| Spring mouths in the settler | `water_settler.gd` `_near_spring_mouth` from `tile_terrain_data.spring_mouths` | spring cave mouths | the same field, filled from the record's cave springs | |
| NPC markers | `data/npcs/markers.json`, `server_npcs.gd` | fixed positions | unchanged positions, plus a new `island_checks --markers` check: each marker is dry, on walkable slope, and not in a wetland. Failures are listed for the markers' owner to move | Dave: move the thing, do not adjust heights. No automatic moves, because a marker is a design choice |
| Tools | `island_checks.gd`, `edge_compare.gd`, `export_tile_maps.gd`, `tile_preview.gd` | tile sections | the same sections, plus the new ones | edge_compare also compares `fresh_m` across seams |

## 3. What I need in the record (to agree with Sonny)

This is my proposal. It follows the rebuild design's Stage D list, so no new science is asked for. Sonny decides.

1. **Reachable from Godot.** The record is written by Python (tools/watershed). Godot cannot read `.npz`. I propose this layout per tile:
   - `record/tile_X_Z.json`, holding the vectors and a manifest;
   - raw little-endian `.f32` and `.u8` grids at 8 m, cut by world position so the tiles agree at seams.
2. **Water class codes.** Keep 0 none, 1 ocean, 2 lake and 3 river, so no runtime reader breaks. Add 4 marsh, 5 swamp, 6 fen, 7 bog and 8 seasonal channel or pond.
3. **Per-cell rasters:** ground, water class, water level, discharge (mean), regime, depth to the water table and basin id, exactly as Stage D lists them. From these the bake makes `fresh_m`. Sonny needs to do nothing extra for it.
4. **Vectors:**
   - reaches, as polylines with Q per season, width, depth, reach type, regime and bed material;
   - heads, by kind;
   - falls (lip, drop, rock);
   - lakes (cause, level, spill point);
   - springs and seeps;
   - **cave springs**: mouth x, y, z; flow in m3/s; rock; and the direction the underground passage runs, to build the cave along;
   - coast outlets.
5. **Stable ids** per reach, lake and cave spring, so a goblin den or a placer can name its source and the log can follow the water.

## 4. The bake-time reader (one script)

`src/worldgen/record/water_record.gd`, a RefCounted script. It gives the bake one API:

- `load_tile(tile) -> String` (an error text, empty when it loaded);
- `water_class`, `water_level`, `discharge`, `table_depth`, `ground` (rasters cropped to the tile, the same layout as today's `water` object, so `tile_baker` hands them on unchanged);
- `reaches_in(rect) -> Array`;
- `cave_springs_in(rect) -> Array`;
- `falls_in(rect) -> Array`;
- `lakes_in(rect) -> Array`;
- `fresh_distance() -> PackedFloat32Array` (computed once, with an 8-neighbour chamfer over the frame, so the tiles agree);
- `placer_traps(ore_rect) -> Array` (positions where the water slows, from reach type changes, bends, falls and confluences).

At runtime, `tile_terrain_data.gd` gains:
- `fresh_water_m(x, z)`, from the new `fresh_m` section;
- the cave springs, through the existing `spring_mouths` and `cave_streams` fields.

## 5. Tile file changes (one TERRAIN_VERSION bump, in R6)

- Kept, written from the record: `height`, `water_surface`, `water_class` (with the extended codes), `flow` (now the record's discharge), and `moisture` (from the climate, which reads the record).
- Added:
  - `fresh_m` (uint8, 4 m steps up to 1 km);
  - `table_depth` (uint8, 0.25 m steps);
  - a `water` list holding this tile's reaches, falls, lakes and cave springs, for tools and later systems.
- `sites` stays as it is (caves, lairs, harbour). A den row gains its source cave id.

## 6. Migration order (so R6 breaks nothing)

1. **M0, the reader over today's data.** `water_record.gd` first reads today's tile water. Every consumer switches to the API with no change in behaviour. Byte-identical tiles before and after are the check (headless, David4).
2. **M1, consumer by consumer, in Dave's priority order (animals and goblins first):**
   1. dens and goblin lairs from dry caves, and `fresh_water_m` for the habitats;
   2. the climate and land types;
   3. the placers;
   4. the spawn picker;
   5. the markers check.

   Each step is a small PR with its own check.
3. **M2, at R6.** Sonny switches the reader's source to the record. Nothing else changes. The checks from M1 run again on the nine rebaked tiles (David4 headless; Dino pictures of the dens, spawn and placers).
4. **M3, tests.** Each test pinned to old tiles is re-pinned or archived with a REMOVALS row as R6 lands:
   - test_river_surface, test_head_pond_fill, test_drainage_fill, test_tile_lakes;
   - test_water_start_drawn, test_drainage_natural, test_drainage_small;
   - test_spawn_dry, test_beach_belt and test_water_falls.

   New checks:
   - every den mouth is dry and inside its cave's rock;
   - every placer lies on a reach downstream of its ore body;
   - the spawn passes the spawn gate;
   - every marker passes `--markers`.

M0 and M1 can be built before R6 because they use today's data. Nothing waits on Sonny except M2.

## 7. Questions (to the coordinator, not to Sonny)

- **Q1, for Dave: goblin dens.** Dave's 7 Nov rule puts goblins in "any spring tunnel". With the rebuild, spring caves become rare, which follows his watershed document. I recommend letting goblin dens use dry side branches of any cave (karst, lava tube or spring cave). Goblins then stay common enough on the starter island, and the caves stay natural.
- **Q2, for Sonny, when he is free:** whether the per-tile JSON and raw-grid layout (section 3, item 1) suits his R6 writer, or what he would rather write.

## 8. Sources

- The watershed document, sections 7, 12 and 14, and the rebuild design (#535), sections 3D, 3E and 7.
- USGS, Descriptive model of placer Au-PGE: https://pubs.usgs.gov/bul/b1693/html/bull6945.htm
- Where placer gold settles (inside bends, riffles and where the water slows): https://www.goldprospectors.org/news/where-s-the-gold-bending-the-bends-801 , https://www.goldprospectors.org/news/how-to-locate-a-placer-deposit-45
- Génevaux et al. (2013), "Terrain generation using procedural models based on hydrology", ACM ToG: https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf
- Knowledge docs read: docs/knowledge/water.md, caves.md (spring caves at least 1.5 km from the sea, #473) and animal-behaviour.md (levels change strength, never placement, #485).
