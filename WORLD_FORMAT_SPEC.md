# World Format Specification (draft)

Draft of 2026-10-12, revised 2026-10-14. The generator is built and tested through step 12 (sites) on branch `claude/generator-v2`; the tile file writer and reader (step 13) are not yet written. This file defines the permanent parts of the world: the world settings, what each tile stores, and the plan of the whole map. The reasoning behind it is in `DESIGN_IDEAS.md`, Sections 4.1 to 4.11.

Every item is **[Proposed]** unless marked otherwise. Items marked **Permanent** cannot change once tiles are kept without rebaking or breaking saved worlds. Items marked **Tunable** can change at any time.

## 1. Principles

- **Store what defines a place. Derive everything else.** Tiles store land shape, water, climate results, soil, geology features, ore bodies and sites. Voxels, rock layers, caves, ore voxels, surface clues, flora, fauna, weather, seasons and sea ice are worked out at runtime.
- **Content is permanent. Encoding is not.** A tile's content can be re-encoded losslessly into a newer file format without changing a single hill. Only changes to content force a rebake.
- **Each tile freezes its generator version.** The runtime generator keeps every released version's behavior. A new version is added for new tiles; an old one is never changed. This replaces the current rule that rejects worlds with mixed generator versions.
- **IDs are append-only.** Biome, soil, rock, resource, site and feature type IDs are never renumbered or reused. New types get new numbers.
- **A missing tile is ocean.** A tile with no file is a standard ocean placeholder, generated the same way everywhere. Replacing a placeholder means adding a file.

## 2. Coordinates

Builds on the current code (`world_definition.gd`, `region_mapper.gd`).

| Item | Value | Status |
|---|---|---|
| Tile size | 15,360 m (15 by 15 regions of 1,024 m) | Permanent (decided; was 10,240 m) |
| Tile (x, z) covers | x·15,360 to (x+1)·15,360 m, same for z | Permanent |
| World size | 21 by 21 tiles, x and z from -10 to 10 | Permanent (decided) |
| Wrap | Both axes, period 322,560 m | Permanent |
| North | The -Z direction | Permanent |
| Voxel size | 1 m | Permanent (existing) |
| Vertical range | -4,000 m to +2,048 m, sea level 0 | Permanent (existing) |
| Equator line | z = 7,680 m (the middle of row 0) | Permanent |

The world is symmetric about the equator line: rows -10 and 10 are the same distance from it and meet across the wrap seam, which is the pole.

## 3. World settings (`world.json`)

One file for the whole world, fixed before the first tile is kept.

**Identity (Permanent)**

- World name and **world identity seed**. **[Decided]** The seed is the phrase `This1is2the3greatest4game5of6all7time`, turned into a number with SHA-256, which gives the same result on every machine.
- Format version and the list of generator versions in use.
- **Tile seed function.** **[Decided]** SHA-256 of the master seed and the tile coordinate, replacing the old XOR-and-multiply hash that could give related seeds to nearby tiles.

**Geometry (Permanent)**

- Tile size, region size, map spacing (8 m) and map samples per side (1,921, see Section 4).
- World extent and wrap, vertical range, sea level.

**Climate (Permanent, because biomes are baked from it)**

- Latitude φ = −(z − 7,680) / 161,280, from -1 (south pole) through 0 (equator) to 1 (north pole). The poles are the wrap seam.
- Sea-level annual mean temperature as control points over |φ|, smoothly interpolated. Starting values to tune in the preview:

| \|φ\| | Row (approx.) | Temperature | Zone |
|---|---|---|---|
| 0.00 | 0 | 30 °C | Desert (hottest) |
| 0.14 | 1.5 | 26 °C | Desert edge |
| 0.24 | 2.5 | 20 °C | Temperate edge |
| 0.43 | 4.5 | 13 °C | Temperate middle (starter rows) |
| 0.62 | 6.5 | 6 °C | Temperate edge |
| 0.71 | 7.5 | 0 °C | Arctic edge |
| 1.00 | 10.5 (pole) | -18 °C | Polar |

- Temperature drops 6.5 °C per 1,000 m of altitude.
- Zone thresholds that turn temperature and moisture into biomes.

**Fixed world features (Permanent once tiles are kept)**

- Hand-placed features the generator must honor, such as `central_trench`: an abyssal trench covering columns -2 to 2 and rows -1 to 1, floor about -2,800 m, kept free of ordinary islands.
- `center_island`: the fixed landmark island at (0,0), about 20 by 12 km (about 164 km²), volcano peak 1,900 m, desert and scorched lava slopes (the "ultimate island", Section 4.13 of the design document), rising from the middle of the trench and reaching into tiles (-1,0) and (1,0). Every value comes from `world.json` and its seed from the world seed, so it is identical on every generation.

**Danger map (Tunable, except the terrain the world sketch derives from it)**

- Curves by column and by row, plus peaks inside dangerous world features, combined into one value from 0 (easy) to 1 (deadly), with tiers easy, moderate, medium, hard and deadly.

**Tunable (runtime, not baked)**

- Seasonal swing by latitude (small at the equator, large at the poles).
- Day length by season, sea ice extent and thickness, weather.
- Lethal depth (about -3,000 m) and the heat, cold and altitude effects.

**Tables (append-only IDs)**

- Biomes, soils, rocks, resources, water classes, site types, feature types. Each table lives in its own data file that every system reads.

## 4. Tile file

One file per tile: `tiles/tile_<x>_<z>.tile`, written as `.partial` and renamed when complete, as the current bake does.

**Container**

- Header, then a section table (name, offset, size, compression, checksum), then the sections.
- Sections are compressed with Zstandard, which Godot supports (`PackedByteArray.compress`). Ocean compresses to almost nothing.
- Each section has a SHA-256 checksum (Godot's `HashingContext`).

**Header**

| Field | Notes |
|---|---|
| Magic and format version | Identifies the file |
| World identity seed | Must match `world.json` |
| Tile x, z and tile seed | |
| Generator version | Frozen for this tile |
| Revision | Starts at 1. Rises when the tile is replaced or re-encoded, so clients refresh cached copies |
| Status | Placeholder or final |
| Matrix entry | A copy of the tile's matrix cell (Section 5), so the tile can be previewed or rebaked exactly |
| Map spacing and sample count | 8 m, 1,921 by 1,921 **[Decided]** |
| Flora seed | For runtime flora placement |

**Maps (8 m grid, 1,921 by 1,921 samples)**

Samples sit on grid points from the tile's west edge to its east edge inclusive, so a tile can be interpolated without reading its neighbors. Neighboring tiles hold the same values on their shared edge. They agree because both compute the edge from the same world-position data (the world elevation map, world-aligned noise, world-grid provinces, the world river network), never from a fixed edge value. Section 4b describes the final pass that checks every shared edge.

| Map | Type | Encoding | Used for |
|---|---|---|---|
| Surface height | uint16 | height = raw × 0.1 − 4,000 m (covers -4,000 to +2,553 m) | Terrain shape |
| Water surface | uint16 | Same encoding. 0 = no water | Lakes and rivers above sea level |
| Water class | uint8 | None, ocean, lake, river, marsh | Water rendering, fishing, travel |
| Flow | uint8 | Logarithmic river discharge | Channel width, water wheels, placer gold |
| Biome | uint8 | Biome table ID | Flora, fauna, look |
| Soil | uint8 | Soil table ID | Surface material, farming |
| Fertility | uint8 | 0 to 255 | Farming, planner |
| Moisture | uint8 | 0 to 255 | Farming, flora, planner |
| Province | uint8 | Index into the tile's province list | Bedrock under this point |
| Cover depth | uint8 | raw × 0.25 m (0 to 63.75 m) | Loose material above bedrock |
| Layer offset | int16 | raw × 0.1 m (±3,276 m) | Bends rock layers for folds |

About 14 bytes per sample (2+2+1+1+1+1+1+1+1+1+2), so about 52 MB per tile before compression (1,921 × 1,921 = 3,690,241 samples). Mostly-ocean tiles compress to a small fraction of that. **[Decided]** There is no size limit on tile files, because we do not yet know what they will need to hold. Efficiency is a standing goal: do not add a map or list without a use, store derived data only when computing it again is too slow, and measure the size of every new section when it is added.

**Low-resolution maps**

A 32 m version (481 by 481) of height, water class and biome for the world map and for drawing distant terrain on clients. About 1 MB before compression.

**Lists**

Stored as compressed JSON during development for readability. They can move to a binary encoding later without changing content.

- **Provinces:** ID, kind (granite, sedimentary basin, volcanic, fold belt), rock layer stack (rock ID and thickness from the top), base rock. First version (step 11): provinces are cells of a world grid (four per tile edge, about 3.8 km) with one jittered seed point each and warped borders, so they cross tile edges cleanly. A province also stores its datum (height of the top of the stack, just above the highest ground in the cell), cycle length (the stack repeats down to `repeat_to_m`, then base rock) and fold settings (a sine fold with direction, wavelength, amplitude and phase, or a basin sag). The per-sample layer offset map is computed from these.
- **Features:**
  - Intrusions: kind, center, top depth, horizontal radii, depth extent.
  - Faults: a line of points, dip angle and direction, width, depth extent.
  - Volcanic vents and pipes: center, radius, depth.
  - Salt domes: center, radius, top depth.
- **Ore bodies:** ID, resource, shape (vein, lens, pipe, layer or halo) with its dimensions, grade, total amount, and the feature it formed from. First version (step 11) adds a `scatter` shape (gems spread thinly through a band of one layer across a province: geodes in basalt, garnets in slate; stores province, depth below datum, band thickness and density) and a `placer` shape (a line of points along a river with width and thickness) for gold and tin washed out of bodies that reach the surface. Layer bodies name their province and repeat with its cycle.
- **IDs. [Proposed, recommended]** A record's identity is its **home tile and local ID**, written `x,z#local` (for example `3,4#101`). The tile revision is **not** part of identity: it is a cache marker that rises when a tile is replaced, re-encoded or extended by a resource pass, and records keep their IDs through all of that, so an NPC miner's record against an ore body never breaks. An ID is unique within its kind of record (province, feature, ore body, site), not across kinds.
  - Features and ore bodies belong to the province cell they formed in. Their home tile is the tile holding that cell, and the local ID is cell index × 100 + n (features 1 to 49, ore 51 to 99). A feature listed by two tiles is the identical record in both.
  - Placers belong to the tile they lie in, with local IDs from 9001. Sites use local IDs from 8001.
  - Records added later by a resource pass (Section 4a) take local IDs from `pass number × 10,000 + n`, so they can never collide with the first-version ranges. Local IDs are never reused, including after a record is mined out or removed.
- **Sites:** ID, kind (cave system, mineshaft, labyrinth, dormant lair, landmark, harbor, town site), position, size, seed and kind-specific settings. A cave system stores its entrances, bounds and seed. The runtime generator carves it. First version (step 12): a cave system stores its kind (karst, lava_tube, sea_cave, rock_shelter), a skeleton (nodes [x, y, z, width, height] with y at the passage center; segments [from, to, type] with type passage, squeeze, shaft, water or ledge), chambers (node, radius, height, features such as cavern or chasm with chasm depth and bridge width), entrance and skylight node lists, creature dens (node, where, tier), the ore bodies it exposes, bounds, length, depth and a seed for carving detail. Caves stay inside their tile. Dormant lairs point at a cave and chamber node with a score and a state. Site local IDs start at 8001.
- **Starter data (starter tiles only):** spawn point and the suggested town block position.

A record's global ID is its home tile and local ID (see IDs above). Ore body IDs are what NPC miners draw down.

**Not stored in the tile**

- Voxels, rock layers, caves, ore voxels, surface clues: derived by the runtime generator from the maps and lists.
- Flora: derived from biome, moisture and the flora seed. Only removals are stored, in the living layer. **[Decided]**
- Fauna, weather, seasons, sea ice: runtime.

## 4a. Adding resources later (resource passes)

**[Proposed]** The world must be able to gain new ores and resources after tiles are kept, without moving or removing anything that exists. The pieces that make this possible are already in place: append-only ID tables, ore bodies built from a few shapes (vein, lens, pipe, layer, halo, scatter, placer) placed by how deposits really form, and a container made of independent, checksummed sections.

A **resource pass** is a numbered, versioned generator step run against the finished world:

- **Inputs, read only:** the tile's maps (height, water, flow, biome, soil, province, cover), its provinces, features, existing ore bodies and sites, and the pass's own rules file.
- **Output:** one new section in the tile, `ore_bodies_pass_<n>`, holding new records. Existing sections, records and maps are never edited or removed. The tile's header lists which passes it carries, and the revision rises so clients refresh.
- **Determinism:** the pass's seed is SHA-256 of the world seed, the pass number and the home tile, so running it again gives the same result, and the order tiles are processed in does not matter.
- **Safety rules:** a pass adds only inside solid rock and never changes caves, sites, maps or earlier ore bodies. Nothing a player has built or dug is touched, because player changes live in a separate server layer. Ore that appears in rock a player has already tunnelled past is simply not present in the air they dug.
- **Tool:** `run_resource_pass` takes a pass number and a list of tiles (or all), writes each tile to a temporary file and renames it when complete, as the baker does. It can be run on unkept tiles first and on live tiles later.
- **Resources that are derived at runtime** (flint pebbles, bog iron, saltpeter, sea salt) need no pass at all. Adding a new derived resource is a table entry and a rule.

Anything that changes where existing ore sits is not a pass. It is a new generator version, which only applies to tiles that have not been kept.

## 4b. Rivers and edge matching

**[Decided]** (2026-10-14) Rivers must continue across tile edges. A river that ends at a tile edge is a bug. The same holds for every other feature: mountain ranges continue as mountain ranges on both sides of an edge, plains as plains, and water as water.

**[Proposed]** How to get there:

1. **World river network.** Work out rivers once for the whole world, wrap-aware, on the 160 m world elevation map (flow accumulation, outlets to the sea or to lakes). The result is a list of river paths with discharge. Each tile reads from it the points where each river crosses each of its four edges (position and discharge).
2. **Tile rivers follow the network.** The 8 m tile water step carves each channel so it enters and leaves at the stored crossing points with the stored discharge, and only fills in local detail between them. Two neighbors then agree on every crossing by construction.
3. **Overlap margin.** Steps that look at neighboring ground (erosion, drainage, biome cells, flow) work on the tile plus a margin of about 1 km that is computed from the world-position data, then crop to the tile. The tile edge then sees the same inputs as its neighbor. This replaces the present erosion fade at tile edges.
4. **Final edge-matching pass.** After the tiles of a region of the map are built, a tool compares every pair of neighboring tiles along their shared edge and reports differences in height, water, water class, flow, biome, soil, province and river crossings. Small differences are a failure to fix in the generator, not something to patch. The pass runs on the whole map before tiles are kept (step 18), and again when a placeholder tile is replaced.
5. **Tests.** The existing check that height and geology match on a shared edge extends to every map and to the river crossings.
6. **Wrap seam.** The same rules apply across the world wrap at x or z = ±10. Detail and climate noise must be made wrap-seamless first (known gap).

Rivers that cross into a placeholder ocean tile simply reach the sea, since the world river network ends in the ocean there.

## 5. Server-side stores (not part of the tile)

- **Edits store** per region: voxel edits, removed trees, placed objects. Authoritative and backed up.
- **Generated block cache** per region: speeds up streaming. Disposable. It can be deleted and rebuilt from the tiles at any time.
- **Region revision** (already in the region manifest): tells clients when cached blocks or edits are stale.

## 5b. World sketch and elevation map (`plan/world_sketch.json`)

**[Decided]** The world is planned world-first (approved 2026-10-13). Islands come from large undersea features, not per-tile dice, and the shared deep-ocean tile edge is dropped: neighboring tiles agree because they read the same world elevation map and world-coordinate detail. The tile plan (Section 6) is derived from the sketch.

**Sketch features** (rules in `plan/sketch_rules.json`, Tunable until tiles are kept):

| Feature | What it is |
|---|---|
| Continental shelf | One per pair of inner and outer starters: a shallow platform (about -90 m) with extra lobes so no two match. Hilly islands rise where hills break the surface. Each starter gets a town-friendly island (28 to 36 km² before coast roughening) near its tile middle. |
| Trench arc | A curved chain of volcanoes along one side of the central trench, bowed toward it. |
| Island arcs | Five curved volcanic chains in dangerous waters (danger 0.45 and up). |
| Hotspot tracks | Four lines: a big young volcano, older smaller islands, then atolls in warm water or seamounts in cold water. |
| Mid-ocean ridge | An undersea range following the east-west wrap seam, crossing both poles, with three islands on it. |
| Seamount field | 300 seamounts and islets, mostly in groups, leaving wide empty seas. |
| Central trench, center island | Fixed, from `world.json`. |

Each feature is a list of mounts (volcano, seamount, atoll or starter island: position, size, rotation, peak height, profile, cliff height, shallow fringe width) plus, for shelves and the ridge, their outline or path. Danger shapes them: taller, steeper peaks, cliffs and narrow shallows where it is dangerous; gentle shores near starters. Ordinary peaks are capped at 1,450 m so the center volcano (rim 1,900 m) is the tallest. A feature marked `"locked": true` in a saved sketch is kept as it is when the sketch is rebuilt.

**World elevation map:** one map for the whole world, 160 m per sample (2,016 by 2,016), heights in meters from sea level. Built from the sketch in about 17 seconds; noise fields are seamless, so the map joins across both wrap seams (checked by a test). The center island is a broad shield plus a steep cone whose crater rim sits at 1,900 m, with a 250 m deep crater holding lava and a breach toward the south-southeast. The tile bake will add fine detail on top of this map.

## 6. Tile plan (`plan/tile_plan.json`, `plan/island_list.json`)

Derived from the sketch elevation map by `tools/build_tile_plan.gd`. Same container as the old matrix (`format_version` 1, `meta`, `cells`), `meta.source` is `sketch`. Locked and baked cells are kept on rebuild.

**Each cell**

| Field | Notes |
|---|---|
| x, z, zone | Tile coordinate and climate zone |
| kind | ocean, shallows (sea above -200 m, no land), trench, islands, landmark, starter |
| status | placeholder (nothing to bake), planned, baked, live |
| locked | True for starters and the landmark tile |
| starter_set | inner, outer or empty |
| danger, danger_tier | From the danger map at the tile center |
| land_km2, land_share | Land inside this tile |
| peak_m, deepest_m | Highest and deepest elevation in the tile |
| features | Sketch features with at least 0.25 km2 of land here, plus world features reaching the tile |
| island_ids | World-wide island numbers touching this tile |
| geology_hints | Union of the features' geology |
| special | lava, salt_flat, scorched, ruins, road on the landmark island |

`island_list.json` holds one record per island, largest first: area, size class, peak, peak tile, owning feature and every tile it touches. Islands can span several tiles; a tile file bakes the part inside its own tile.

## 7. Workflow

1. Fix `world.json`: identity seed, climate curve, fixed world features, danger map.
2. Build the world sketch and elevation map, then derive the tile plan. Review the preview images and tune `plan/sketch_rules.json`.
3. A tile with no file is an ocean placeholder. Only tiles that hold land need a file (227 of 441 in the current plan).
4. Build the four inner starter tiles first, then their neighborhoods, then outward.
5. Run the edge-matching pass (Section 4b) over every built tile and its neighbors before any tile is kept.
6. Each built tile goes live at a server restart, replacing its placeholder. Later additions go in through resource passes (Section 4a) or, for terrain, new generator versions on tiles not yet kept.

## 8. Settled

Flora is derived at runtime, the map grid is 8 m, the master seed is the phrase `This1is2the3greatest4game5of6all7time` turned into a number with SHA-256 (574716103), and each tile's seed is SHA-256 of the master seed and the tile coordinate (branch `claude/world-seed`). There is no shared deep-ocean tile edge: neighboring tiles agree because they read the same world data. The tile matrix randomizer of the first draft was replaced by the world sketch and tile plan.
