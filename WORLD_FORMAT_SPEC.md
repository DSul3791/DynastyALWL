# World Format Specification (draft)

Draft of 2026-10-12. Nothing here is implemented. It defines the permanent parts of the world: the world settings, what each tile stores, and the tile matrix that plans the whole map. The reasoning behind it is in `DESIGN_IDEAS.md`, Sections 4.1 to 4.11.

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
- **Ocean edge floor depth.** Every tile edge converges to this depth. The current code uses the world bottom plus 1 m (about -3,999 m), so the open sea is 4 km deep with almost no rock beneath it. **[Decided]** -2,000 m, which keeps 2 km of rock under the deep sea and leaves room for shelves, seamounts and wrecks within diving reach near islands. Players will dive on wrecks and fish with spears, as in Atlas.

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
- `center_island`: the fixed landmark island at (0,0), about 20 by 12 km (about 164 km²), volcano peak 1,900 m, jungle flanks, rising from the middle of the trench and reaching into tiles (-1,0) and (1,0). Every value comes from `world.json` and its seed from the world seed, so it is identical on every generation.

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

Samples sit on grid points from the tile's west edge to its east edge inclusive, so a tile can be interpolated without reading its neighbors. The outer ring always holds the standard ocean edge values, so neighboring tiles agree automatically.

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

About 13 bytes per sample, about 48 MB per tile before compression. Mostly-ocean tiles compress to a small fraction of that.

**Low-resolution maps**

A 32 m version (481 by 481) of height, water class and biome for the world map and for drawing distant terrain on clients. About 1 MB before compression.

**Lists**

Stored as compressed JSON during development for readability. They can move to a binary encoding later without changing content.

- **Provinces:** ID, kind (granite, sedimentary basin, volcanic, fold belt), rock layer stack (rock ID and thickness from the top), base rock.
- **Features:**
  - Intrusions: kind, center, top depth, horizontal radii, depth extent.
  - Faults: a line of points, dip angle and direction, width, depth extent.
  - Volcanic vents and pipes: center, radius, depth.
  - Salt domes: center, radius, top depth.
- **Ore bodies:** ID, resource, shape (vein, lens, pipe, layer or halo) with its dimensions, grade, total amount, and the feature it formed from.
- **Sites:** ID, kind (cave system, mineshaft, labyrinth, dormant lair, landmark, harbor, town site), position, size, seed and kind-specific settings. A cave system stores its entrances, bounds and seed. The runtime generator carves it.
- **Starter data (starter tiles only):** spawn point and the suggested town block position.

A global ID is (tile x, tile z, tile revision, local ID). Ore body IDs are what NPC miners draw down.

**Not stored in the tile**

- Voxels, rock layers, caves, ore voxels, surface clues: derived by the runtime generator from the maps and lists.
- Flora: derived from biome, moisture and the flora seed. Only removals are stored, in the living layer. **[Decided]**
- Fauna, weather, seasons, sea ice: runtime.

## 5. Server-side stores (not part of the tile)

- **Edits store** per region: voxel edits, removed trees, placed objects. Authoritative and backed up.
- **Generated block cache** per region: speeds up streaming. Disposable. It can be deleted and rebuilt from the tiles at any time.
- **Region revision** (already in the region manifest): tells clients when cached blocks or edits are stale.

## 5b. World sketch and elevation map (`plan/world_sketch.json`)

**[Decided]** The world is planned world-first (approved 2026-10-13). Islands come from large undersea features, not per-tile dice, and the shared deep-ocean tile edge is dropped: neighboring tiles agree because they read the same world elevation map and world-coordinate detail. The tile matrix in Section 6 becomes a result of the sketch (still to be rebuilt).

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

**World elevation map:** one map for the whole world, 160 m per sample (2,016 by 2,016), heights in meters from sea level. Built from the sketch in about 17 seconds; noise fields are seamless, so the map joins across both wrap seams (checked by a test). The center island is a broad jungle shield plus a steep cone whose crater rim sits at 1,900 m, with a 250 m deep crater holding lava and a breach toward the south-southeast. The tile bake will add fine detail on top of this map.

## 6. Tile matrix (`plan/tile_matrix.json`)

The plan for all 441 tiles, read and written by the randomizer and the island properties panel.

**Each cell**

| Field | Notes |
|---|---|
| x, z | Tile coordinate |
| Kind | Ocean, islands or starter |
| Status | Placeholder, planned, baked or live |
| Locked | If true, the randomizer never changes this cell |
| Revision | Matches the tile file |
| Islands | A list (below) |
| Geology hints | Optional: granite, basin, volcanic, fold belt |
| Notes | Free text |

**Each island**

| Field | Notes |
|---|---|
| ID | Local to the tile |
| Center | Meters from the tile center (x east, z south) |
| Size class and target area | See below |
| Shape | Round, elongated, crescent, ragged, or a cluster for archipelagos |
| Character | Mountainous, rolling, flat, volcanic, archipelago |
| Peak height | Target highest point |
| Rotation | Direction of the long axis |
| Seed | Stored explicitly so it is visible and editable |

**Size classes**

| Class | Area |
|---|---|
| Islet | Under 1 km² |
| Small | 1 to 5 km² |
| Medium | 5 to 15 km² |
| Large | 15 to 30 km² |
| Great | 30 to 45 km² |

The largest class changed from the first draft (50 to 75 km²). Every tile edge must drop to the shared deep-ocean floor, so an island keeps about 1 km of margin from the tile edge. A single island then cannot cover more than about 45 km². For scale, the project owner remembers the whole ARK map, ocean included, at about 48 km².

**Randomizer rules (starting values, Tunable)**

- **[Decided] Two kinds of island tile, chosen at random for variety:**
  - **Peers:** one to five islands of similar size (small or medium).
  - **Main island with satellites:** one large or great island, with a chance of a few islets or small islands just off its coast.
- **Tile odds (starting values):** ocean 25%, peers 40%, main island with satellites 35%.
- **Peers:** 2 islands 35%, 3 islands 30%, 1 island 15%, 4 islands 12%, 5 islands 8%. Sizes vary within about a factor of two of each other.
- **Satellites:** 0 satellites 30%, 1 satellite 30%, 2 satellites 20%, 3 satellites 12%, 4 satellites 8%. Each is an islet (70%) or small island (30%), placed 0.3 to 3 km off the main island's shore.
- **One great island per tile at most.** Total land per tile is capped at about 75 km².
- **Margins.** Islands keep a minimum distance from the tile edge for the shared ocean edge, and from each other (for example 1 km of open water), except within an archipelago cluster.
- **No visible grid.** Island centers are jittered and sizes mixed, so neighboring tiles do not line up.
- **Climate.** Arctic rows have fewer, smaller, glaciated islands and more sea ice. The desert row leans toward flatter and volcanic islands.
- **World-scale patterns.** The matrix sees the whole world, so it can create patterns no single tile could: island chains that curve across several tiles, a volcanic arc, a few large open seas with no islands for epic crossings.
- **Starter tiles.** The eight starter tiles are locked and hand-tuned: one medium-to-large, rolling, town-friendly island with flat land, a river and a natural harbor. Inner set at (-3,4), (3,4), (-3,-4), (3,-4); outer set at (-6,6), (6,6), (-6,-6), (6,-6).
- **Starter neighborhoods.** Within one or two tiles of each starter, guarantee medium islands that between them offer stone, wood, clay, iron, copper, tin and coal, reachable by an early boat.
- **Resource fairness.** Every climate zone gets every key resource somewhere, steered through geology hints.
- **Reproducible.** Every random pick derives from the world seed and the tile coordinate, so rerunning the randomizer gives the same result unless the rules change. Locked cells are always preserved.

**Outputs**

- A whole-world preview image showing every tile's islands, climate zones and starter tiles.
- A summary: land area per zone, island counts per size class, and resource coverage per zone.

## 7. Workflow

1. Fix `world.json`: identity seed, ocean edge depth, climate curve.
2. Run the randomizer to fill the matrix. Review the preview, hand-edit, and lock what you like.
3. Every tile starts as a placeholder (no file, so it is ocean).
4. Bake the four inner starter tiles first, then their neighborhoods, then outward.
5. Each baked tile goes live at a server restart, replacing its placeholder.

## 8. Decisions needed

Settled: flora is derived at runtime, the map grid is 8 m, the ocean edge is -2,000 m, and island tiles are either peers or a main island with satellites.

Also settled: the master seed is the phrase `This1is2the3greatest4game5of6all7time`, turned into a number with SHA-256 (574716103), and each tile's seed is SHA-256 of the master seed and the tile coordinate (branch `claude/world-seed`).

1. The odds above are starting values to tune with the preview image.
