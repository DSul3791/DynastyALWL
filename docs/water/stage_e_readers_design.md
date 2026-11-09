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

## 3. The record shape (agreed with Sonny, 7 Nov 2026)

Sonny's reply is in `/mnt/project-files/water/record_schema_reply_to_steve.md`. This section is the summary readers code against.

1. **Layout.**
   - **Rasters:** raw little-endian grids at 8 m, one set per tile, (T+1)² samples with shared edge samples. This is the `export_raw_heights` convention, so neighbouring tiles agree at their edges by construction.
   - **Vectors:** one island-wide `record/network.json`. A reach is never clipped at a tile edge, and the bake loads the file once.
   - **Manifest:** `record/manifest.json` holds `version` (the record version), the params, the input hashes, the grid origin and the cell size.
   - **Units:** metres and m3/s. Coordinates are world x and z, with y up.
2. **Water class codes:**
   - 0 none, 1 ocean, 2 lake, 3 perennial river (unchanged, so no runtime reader breaks);
   - 4 marsh, 5 swamp, 6 fen, 7 bog;
   - 8 seasonal channel, 9 seasonal pond;
   - 10 salt marsh or tidal flat. This needs its own biome row, separate from freshwater marsh.

   Perennial, intermittent or ephemeral is in the regime raster, not the class.
3. **Rasters:**
   - ground, water class, water level, mean discharge, regime, depth to the water table, basin id;
   - `fresh_m`, the distance to perennial fresh water. It is island-wide, so the bake needs no frame for it;
   - `sediment_m` (alluvium, till and colluvium), for the placers and the soils.
4. **Vectors:**
   - reaches: polyline; wet-season, mean and dry-season flow; width, depth, reach type, regime, bed material and the downstream reach id;
   - heads (by kind);
   - falls;
   - lakes (cause, level, spill point);
   - springs and seeps;
   - cave springs (mouth, flow, rock, underground catchment area);
   - karst sinks, each linked to the cave spring it feeds, so a cave can follow the route from sink to spring;
   - coast outlets.

   Every feature also carries the seven plausibility answers and its appearance fields.
5. **Ids** are deterministic from the seed and params, and stable within one record version only. Readers never keep them across rebakes, except in bake output that is rebuilt with the record.
6. **Ground:** in R6 the record's ground becomes the tile `height`. The current tile_height pipeline is bypassed for baked tiles, so M2 also switches `height`.

## 4. The bake-time reader (one script)

`src/worldgen/record/water_record.gd`, a RefCounted script. It gives the bake one API:

- `load_tile(tile) -> String` (an error text, empty when it loaded);
- `water_class`, `water_level`, `discharge`, `regime`, `table_depth`, `basin`, `ground` (rasters cropped to the tile, the same layout as today's `water` object, so `tile_baker` hands them on unchanged);
- `reaches_in(rect) -> Array` (queries the island-wide `network.json`);
- `cave_springs_in(rect) -> Array`;
- `falls_in(rect) -> Array`;
- `lakes_in(rect) -> Array`;
- `fresh_distance() -> PackedFloat32Array` (M0 and M1: computed with an 8-neighbour chamfer over the bake frame from today's water; M2: read from the record's `fresh_m`);
- `sediment() -> PackedFloat32Array` (M2; empty before it);
- `placer_traps(ore_rect) -> Array` (positions where the water slows, from reach type changes, bends, falls and confluences).

At runtime, `tile_terrain_data.gd` gains:
- `fresh_water_m(x, z)`, from the new `fresh_m` section;
- the cave springs, through the existing `spring_mouths` and `cave_streams` fields.

## 5. Tile file changes (one TERRAIN_VERSION bump, in R6)

- Kept, written from the record: `height`, `water_surface`, `water_class` (with the extended codes), `flow` (now the record's discharge), and `moisture` (from the climate, which reads the record).
- Added:
  - `fresh_m` (uint8, 4 m steps up to 1 km; from the record's island-wide raster at M2);
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

## 6b. The R6 files and the reader (8 Nov, matched to Sonny's writer #622)

Sonny's field list is firm (#537, Stage D "Record layout" and R6 item 4), and his writer `tools/watershed/record.py` (#622) fixes the bytes. **Sonny owns the schema.** The reader follows the writer, and it reads each raster's coding from the manifest's field table instead of hard-coding it, so a new field or a changed scale needs no reader change.

### Files (as #622 writes them)

All files are under `<world>/record/`:
- `manifest.json`
- `network.json`
- `climate.json`
- `tiles/<tx>_<tz>/<name>.<type>`

A raster is raw, row-major (row = z, column = x, the `export_raw_heights` convention), little-endian, with `tile_samples`² samples (T + 1 at 8 m: 1,921 for a starter tile) and shared edge samples. `<type>` is `f4`, `u1`, `u2` or `i4`.

| raster | type | coding (manifest `fields`) |
|---|---|---|
| `ground` | f4 | metres |
| `water_level` | f4 | metres; NaN = no water |
| `water_class` | u1 | 0 to 10, as agreed |
| `discharge` | u2 | log10(m³/s) = code / `codes_per_decade` − 4; 0 = none |
| `regime` | u1 | 0 none, 1 perennial, 2 intermittent, 3 ephemeral |
| `table_depth` | u1 | × `scale` m |
| `basin` | i4 | basin id; −1 = none |
| `fresh_m` | u2 | × `scale` (1 m) |
| `sediment_m` | u2 | × `scale` m |
| `snow_on`, `snow_off` (A4, later) | u1 | year phase 0 to 255. The window runs from `on` to `off`; equal = none; `on` 0 and `off` 255 = all year |
| `fog_pool` (later) | u1 | depth below the cold-air surface |

**`manifest.json`:** `{version, complete, record_sha, cell_m, origin_x, origin_z, tile_samples, tiles [x0, z0, x1, z1], inputs, stage_manifests, fields [{name, type, file, scale?, nodata?, codes_per_decade?, units?}], params, summary}`.
- **The bake refuses a record with `complete` false.** Until R5, #622 writes no rivers, and says so.
- It also refuses a `version` it does not know, and any raster whose byte length is wrong for its type and `tile_samples`.
- Tools and tests may open an incomplete record on purpose (`allow_incomplete`).

**`network.json`:** `{reaches, heads, confluences, falls, springs, cave_springs, coast_outlets, cold_air_pools, lakes}`. #622 writes the lakes alone until R5. The reader queries every list the same way: a feature is "in" a rect when one of its points lies in the rect. A point is `pos`, `mouth`, `lip` or `spill` as [x, y, z], any `<name>_x` and `<name>_z` pair (R3's lakes give `deepest_x` and `spill_x`), or any point of its `polyline` or `outline`. Nothing is clipped.

**`climate.json`:** `{default, by_island: {<island id>: …}}`. Each entry is `{sea_level_mean_c, seasonal_swing_c, warmest_year_phase, daily_range_c, lapse_c_per_km, rain_mm_yr}` (A4), and `climate(island)` falls back to `default`. The live air formula stays Jamie's `Weather.air_c` (#616 and #620); the reader hands these numbers over and never works out a second air formula.

### The reader (`src/worldgen/record/water_record.gd`)

An instance opens one world's record, keeps the network and climate in memory, and reads rasters per tile on demand (one tile's 8 m set is about 30 MB, so at most the nine tiles of a bake frame are held):

- `open(record_dir, allow_incomplete = false) -> String`: reads the manifest, network and climate. Returns an error text, or empty when it loaded;
- `has_tile(tx, tz) -> bool`;
- `raster(tx, tz, name) -> PackedFloat32Array`: decoded by the field table to metres, m³/s and codes, with no-data as NaN, cached per tile;
- `frame(tile, margin, name) -> PackedFloat32Array`: the tile's raster with `margin` samples taken from its eight neighbours, the bake frame the baker works on. A sample beyond a missing neighbour repeats the nearest edge sample, and the bake reports it;
- `reaches_in(rect)`, `falls_in(rect)`, `lakes_in(rect)`, `cave_springs_in(rect)`, `springs_in(rect)`, `pools_in(rect)`: features whose position (or any polyline point) lies in the rect, never clipped;
- `reach(id)`, and `downstream(id) -> Array` (the ids to the sea, for the follow-the-water checks);
- `climate(island) -> Dictionary` (the live temperature is `Weather.air_c`, one formula);
- the static helpers already there (`fresh_distance`, `encode_fresh`, `decode_fresh`) stay, for tiles baked with `water_source` "rules".

The M0 check is a headless test (`test_water_record.gd`). It writes a small record in #622's format (two tiles of 3 × 3 samples, a network with a reach across their seam, a climate), opens it, and checks:
- the decodings (f4 with NaN, the log discharge, scales, i4 no-data);
- the seam samples;
- the frame margin from the neighbour;
- a reach found from both tiles with one id;
- `downstream`;
- the refusals: an incomplete record, an unknown version, a wrong length.

## 6c. Water classes: one code space (M1 step 2, 8 Nov)

**The clash:** `data/tables/water_classes.json` is append-only. It already holds 4 marsh and 5 estuary. The record's codes put swamp at 5 and run on to 10 salt marsh. Nothing bakes estuary today, but the rule forbids reusing its id.

**The fix, with no change asked of Sonny:**
- The table keeps the game's ids, which tile files, flora and land types use. New rows are 6 swamp, 7 fen, 8 bog, 9 seasonal channel, 10 seasonal pond and 11 salt marsh.
- Each row carries `record_code`, the code the record writes.
- `water_record.gd` maps record codes to table ids when it reads `water_class`. A code the table lacks reads as 255, and the bake reports it.

**What each class means to the land:** a row with `land: true` is ground to the climate and the land types. That covers the wetlands and the dry-season beds.
- The bake hands them a `land_view` of the classes, with those cells as 0.
- After the land types, `apply_wet_land` lays on the row's `biome` and `soil`:
  - marsh, swamp and salt marsh: marsh biome on mud;
  - fen and bog: marsh biome on peat;
  - a seasonal channel: its climate biome on gravel;
  - a seasonal pond: its climate biome on silt.
- MikeW's own wetland biome rows replace "marsh" per row when they exist.
- The native climate loop (`GenCore.classify_climate`) needs no change, because it never sees a land class.

**Rules bakes are unchanged:** today's bake writes only classes 0 to 3, so `land_view` returns the same array and `apply_wet_land` changes nothing. A rules tile is byte-identical before and after.

## 6d. Placers where the water slows (M1 step 3, 8 Nov)

**Today:** `tile_geology.gd` `_find_placers` walks from an ore outcrop down to a river, then lays one long placer along the river below it, the same grade all the way.

**The real rule:** heavy grains settle where the water slows. That happens at:
- the inside of a bend;
- a break in slope, where a steep reach meets a gentle one;
- a confluence, where a tributary joins and the flow spreads;
- the plunge pool at the foot of a fall.
(USGS placer model and prospecting guides, section 8.)

**The finder:** `WaterRecord.placer_traps(path, rules)` takes the river walked downstream, one row per recorded step, as [x, z, bed height, flow]. The rows come from the reach `polyline` columns 0, 2, 1 and 5 (each point is [x, y, z, ...] with y the bed height, Sonny's R5 writer, #648). It returns the steps that are traps, in order. The kinds, checked in this order at each step:

| Kind | Test | Rule key, default |
|---|---|---|
| `confluence` | the flow grows by this factor in one step | `confluence_x` 1.4 |
| `slope_break` | the bed's fall below is under 1/ratio of the fall above (and the fall above is over 0.002) | `slope_ratio` 2 |
| `bend` | the course turns by this much or more | `bend_deg` 35 |

- Never two traps within `min_gap` steps (2), and at most `max_traps` (4) per river.
- If nothing qualifies, it returns the gentlest step as kind `slow`, so every source still gets one placer.
- The foot of a fall comes at M2, when the reader reads the record's falls list. A drop in today's rules heights is not a fall.

**The bake:** each trap gets one short placer:
- 3 points, the trap step and one either side;
- the grade is the ore's grade × `grade_x` (0.8);
- the tonnage is for a length of 2 × `record_every` steps;
- each placer names its `trap` kind.

The old single long placer is not written then.

**On (9 Nov 2026, after R6):** the `on` switch is gone (Dave's rule, no feature switches); `ores.placer_traps` in `tile_rules.json` only tunes the defaults above. It shows in the tiles at the next bake on Dave's PC.

## 6e. The spawn picker (M1 step 4, 8 Nov)

**Today:** the spawn is a constant, `src/shared/spawn_point.gd` `OVERRIDE` (x 53296, z 68080), moved by hand on 6 Nov when the rivers moved. The starter tile already writes a `spawn_point` in its `starter` section (the beach by the river mouth), but the server ignores it, because `OVERRIDE` always wins. The NPC markers (`data/npcs/markers.json`) were moved by hand with it.

**The rule (Dave: "move the spawn, do not adjust heights"):** every bake of the starter tile picks the spawn again, by rule. A spot is a candidate only when all of these hold:

| Test | Rule key, default | Why |
|---|---|---|
| inside `ring_m`: steepest step, height range, wet cells | `ring_m` 30, `max_slope_deg` 7, `range_m` 1.5, no wet cell | the same gate as `island_checks` (spawn gate) and room for the town markers (within 12 m) |
| the ground is high enough over the sea | `min_ground_m` 10 | above the beach and storm reach |
| no water within `dry_m` | `dry_m` 12 | test_spawn_dry: 5 m from any wet cell, with margin |
| over the nearest water surface by `above_water_m` or more | `above_water_m` 2.5 | not on a floodplain (test_spawn_dry asks 2 m) |
| a perennial river (catchment `perennial_km2` or more) or a lake within a short walk | `walk_m` [40, 400], `perennial_km2` 2 | drinking water and a landmark, Dave's bear and town rules |

Of the candidates, the one nearest the bay head wins: the river mouth, or the bay centre when the tile has no river. A tie goes to the first in row order, so the pick is stable. It searches within `search_m` (3000) of that point, every 2 samples.

**Where it runs:** `src/worldgen/tile/spawn_picker.gd` `pick(maps, target, rules)`, a static function on plain arrays: heights, water class, water surface and flow. The two distance fields (to any water, carrying that water's surface, and to a perennial river) are chamfer passes over the search window only. `tile_sites.gd` `_make_starter` always calls it (the `on` switch went on 9 Nov 2026, after R6), and writes `starter.spawn_picked` = [x, ground + 1, z]. The old beach `spawn_point` stays as it is.

**One reader:** `spawn_point.gd` gets:
- `use_world(world_dir)`, which reads the starter tile's `spawn_picked` once;
- `current()`, the picked spawn, or `OVERRIDE` when the tile has none.

(`town_shift()` went on 9 Nov 2026, with the flora clearing and the orchard by the spawn: nothing is placed from the spawn, Dave 9 Nov.)

The server calls `use_world` at start. Only the server spawn and the island checks read `current()`. The shipped NPC markers stand where `markers.json` puts them, whatever the spawn. Clients already get the spawn in the welcome message, and flora is placed on the server only, so the two sides cannot disagree.

**On (9 Nov 2026, after R6):** the `on` switch is gone; `starter.spawn_picker` only tunes the defaults. Tiles baked before have no `spawn_picked`, so `current()` stays `OVERRIDE` until the next bake on Dave's PC. From then the picker then reads the record's water level and its wetland and floodplain classes: a wetland cell counts as wet. A small tool, `spawn_pick.gd` (headless, run on the PC), runs the picker on today's baked starter tile and prints where it would put the spawn, against the gate. So the rule can be checked before R6.

**Left for M2:** the starter ground the client ships (`prebuild_blocks.gd`, its fixed corner) has to follow the picked spawn. So do the old debug tools that still name x 53301 z 68427.

## 7. Questions (to the coordinator, not to Sonny)

- **Q1, for Dave: goblin dens.** Sonny agrees with the recommendation below. Under Dave's 6 Nov QA rule (go with the recommendation), M1 builds it, and Dave can still overrule it. Dave's 7 Nov rule puts goblins in "any spring tunnel". With the rebuild, spring caves become rare, which follows his watershed document. I recommend letting goblin dens use dry side branches of any cave (karst, lava tube or spring cave). Goblins then stay common enough on the starter island, and the caves stay natural.
- **Q2 (answered, Sonny 7 Nov):** raw grids per tile, plus one island-wide `network.json` for the vectors (section 3).

## 8. Sources

- The watershed document, sections 7, 12 and 14, and the rebuild design (#535), sections 3D, 3E and 7.
- USGS, Descriptive model of placer Au-PGE: https://pubs.usgs.gov/bul/b1693/html/bull6945.htm
- Where placer gold settles (inside bends, riffles and where the water slows): https://www.goldprospectors.org/news/where-s-the-gold-bending-the-bends-801 , https://www.goldprospectors.org/news/how-to-locate-a-placer-deposit-45
- Génevaux et al. (2013), "Terrain generation using procedural models based on hydrology", ACM ToG: https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf
- Knowledge docs read: docs/knowledge/water.md, caves.md (spring caves at least 1.5 km from the sea, #473) and animal-behaviour.md (levels change strength, never placement, #485).
