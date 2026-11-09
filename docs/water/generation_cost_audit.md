# Generation cost audit (9 Nov 2026)

Sonny, for Dave. Dave asked whether this whole chain has to run every time tiles are made, because there are 9 tiles now and 441 later: "Im worried we have let the process bloat again. we need to look at the generation process and see if it can be simplified to achieve the same goals with much faster turnarounds." This note proposes cuts and changes no code. "Measured" means a Dino time from 8 or 9 Nov. "Estimate" is my judgement.

**The short answer:** no. The chain (export to record) only needs to run when the land itself changes. A change to tile rules (springs, caves, sites) needs only the bake: 59 s with the setup from its cache and 5 min 27 s without (measured 9 Nov, after the bake fixes in section 2; 19 min before them). Tonight's run is the whole chain because removing `spawn_keep` changed the land. But nothing skips a stage today, and the job sheets are written by hand, so a full run is easy to start when it isn't needed.

## 1. Every step, what it costs, and how it scales

Today the chain runs once per **window**: one square of tiles around an island group. The starter window is 3×3 tiles: 2,881² cells of 16 m (8.3 M cells), of which 362 km² is land. The bake and the water steps run once per **tile**.

| step | Dino, measured | runs | threads |
|---|---|---|---|
| landform export | 284–299 s | per window | 1 |
| geology export | 225–236 s | per window | 1 (beside the landform) |
| inputs.py | 16–17 s | per window | 1 |
| evolve.py, 200 steps | 1,040 s (580d), 1,172 s (580h) | per window | partly 9 |
| glacial.py, 650 steps | 3,637 s (ws580u) | per window | 1 |
| lakes / groundwater / network | 24 s / 26 s / 57 s | per window | 1 |
| record.py | 53 s | per window | 1 |
| check_record.py | not timed (seconds) | per window | 1 |
| bake: setup | 418 s (8 Nov) | once per bake run, for the whole world | 1 |
| bake: tiles | 206 s for 9 tiles on 9 threads | per tile | 9, but queued on one lock |
| settle + refilm | 338 s for 9 tiles at once | per tile | 9 |
| rebake_check.sh | 196 s | per bake | 3 tests |

Since then (measured 9 Nov, section 2): the bake's setup is 269 s when its cache misses and 0.75 s when it hits, and the nine tiles take 57.3 s. `rebake_check.sh` has left the bake run. Settle + refilm stays (363 s on ws580v).

The starter window adds up to about 88 min for the chain plus 19 min for the bake through the check, about 1 h 50 min in all.

**Scaling to 21×21.** The plan has 441 tiles, of which 227 need a file, with 4,398 km² of land on 323 islands (`tile_plan_summary.txt`).
- **One window for the whole world:** 20,161² = 406 M cells, which is 49× the starter window. Glacial would take about 49 × 61 min ≈ 50 h on one thread, and the memory would be 49× as well. That is not feasible, so the chain must stay per window.
- **Windows like the starter's:** the starter window holds 362 km² of land and the world has 4,398 km², so about 12 windows' worth. One thread doing them one after another: 12 × 88 min ≈ 18 h. Nine windows at once (the stages are single-threaded, so this is how the nine threads get used): about 18 h / 9 ≈ 2 h of wall time (estimate; the windows vary in size, so they pack unevenly). That needs about nine windows' worth of memory at once. Glacial's memory is not measured; my estimate is a few GB per window.
- **Per tile:** the bake is 418 s of setup once, plus 227 / 9 = 26 rounds × 206 s ≈ 1 h 36 min. Settle + refilm 26 × 338 s ≈ 2.4 h.
  - After the bake fixes: 269 s of setup once, plus 26 rounds × 57 s ≈ 25 min (estimate from the starter's measured round). Settle + refilm is up to 26 × 363 s ≈ 2.6 h. The 363 s is the slowest of nine, so tiles with less water should settle faster, but that is not measured.

## 2. Where the time goes, and cuts that keep the same goals

The goals that must not move are the summit, the lakes, the river network, the springs, and caves or head ponds where the rules put them.

**Evolve: 80% of its run is thrown away.** Evolve runs 500 kyr (200 steps of 2,500 years) and writes snapshots. Glacial starts from the **t100k** snapshot only, which is step 40, reached at 278 s on 580h. The other 160 steps (about 894 s) are never read.
- **Cut:** run evolve for 100 kyr, at about 4.6 min instead of 19.5. Only the run's own stop check reads the run length, so t100k should come out identical. I'd confirm that once by comparing the hash of `ground.npz`.

**Glacial: 650 full-grid steps at about 5.6 s each.** There are 49 cycles, 39 of the 41-kyr world and 10 of the 100-kyr world: 512 cold steps of 2,000 years plus 138 interglacial river steps. Every step rebuilds everything on all 8.3 M cells:
- the flow routing (priority-flood fill, D8-LTD receivers, order);
- the ice flux and swath;
- two discharge sums and the channel share;
- the implicit stream-power solve (4 sweeps);
- the slope limit and creep.

It is not profiled, but by the code the routing and the solve are most of each step. A one-cycle profile on Dino (a few minutes) would settle it. The cycles can't simply be cut: the summit climbs to 1,586 m by cycle 25 and comes down to 1,338 m by cycle 49 (the manifest's cycles list), so the result depends on the whole history. The possible cuts:

| cut | saving | risk |
|---|---|---|
| a. Crop each window to its island plus a margin instead of whole tiles (83% of the starter window is sea) | estimate 30–50% of every per-window stage | none to the goals, if the margin holds the coast and the shelf |
| b. Steps of 4,000 years instead of 2,000 in the 41-kyr cycles (8 → 4 per cycle) | estimate 25% of glacial | the summit and cirques may shift; one probe against ws580v decides |
| c. 32 m cells for the 39 early cycles, 16 m for the last 10 | estimate 40–45% of glacial | early valleys are coarser; one probe decides |
| d. Nine threads on the cell-by-cell parts (numba `parallel`); routing and sums stay in order | estimate 1.5–2× per step | none (same arithmetic) |

**Skip what hasn't changed.** Each stage's manifest already holds its input hashes and params. A single runner (`tools/watershed/run_chain.py`) could take one command, give each stage the nine-thread rule, print the clock times, and skip any stage whose inputs, params block and script hash match the last run. Then:
- a tile-rule change skips straight to the bake;
- a water-rule change starts at lakes;
- the geology export (about 4 min) is skipped unless the rock rules change.

It would also replace the hand-written job sheets.

**Water files from the record.** For a tile baked from the record, settle and refilm re-run the water sim to a level the record already holds. Writing the `.water` file straight from the record's levels (R7 item 1, "seeding", which is planned anyway) would turn 338 s per nine tiles into seconds (estimate).
- **Measured, and dropped for now (PR C, 9 Nov).** Before any code, Dino gave the nine ws580v tiles the settle's start (one tick, then the same refilm) and compared them with the settled files (`compare_seed_settle.py`, `seed_vs_settle_ws580v.txt`). The bar was R7 item 2's levels check: every lake within 10 cm, 90% of the river cells within 10 cm, and no new body of water of 0.5 ha or more on plain ground. The verdict was FAIL:
  - the settled files hold 9.79 M m³ of water, against 2.68 M m³ seeded (+265%);
  - 102 of 107 lakes move more than 10 cm;
  - 5.7% of the river cells are within 10 cm;
  - every land tile gets new bodies of water.
- **The cause is the live water's springs, not the record.** Each head pours 3 m³/s per km² of catchment, and the sides add 1 m³/s per km² (`data/water_settle.json`). Both are multiplied by the server's start key of 10 (`WaterLive.DEFAULT_RATE`), which comes to about 30 to 40 m³/s per km². The record's mean flow is at most 0.035 m³/s per km², which is all of the 1,100 mm of rain a year (the chain's `climate.rain_mm_yr`) running off, so the springs pour about 1,000 times as much. The live water stands above the record's levels everywhere: every difference is settled above seeded.
- **So the settle stays.** A seeded file would rise after a fresh server start until the server saved its own. The settle's 363 s per nine tiles stays in every bake that changes the water. Matching the springs to the record's flows is R7 items 1 and 2 (watershed design), and seeding comes back then.

**The bake: nine threads that queue for one lock (the biggest cheap win).**

Dino's log of the 8 Nov bake (9 threads, ms per tile):

| tile | record | climate + land types + geology + sites |
|---|---|---|
| 2,3 | 40,077 | 22,634 |
| 3,3 | 64,972 | 24,396 |
| 4,3 | 103,201 | 24,448 |
| 2,4 | 89,885 | 23,181 |
| 3,4 | 121,729 | 28,174 |
| 4,4 | 134,721 | 25,252 |
| 2,5 | 147,767 | 20,090 |
| 3,5 | 161,246 | 21,677 |
| 4,5 | 174,768 | 24,630 |

The other stages are flat at about 25 s a tile. The record stage climbs about 17 s a tile, because every thread waits its turn: `tile_baker.gd` `_bake_from_record` takes `_record_mutex` around all of the record reading. The record's raster cache is not safe to share, so the lock is there for a reason. What makes it slow is the work done under the lock, all of it in GDScript one sample at a time:
- `water_record.gd` `decode` turns each 1,921² raster into floats one sample at a time, with a `match` on the type for every sample (3.7 M per raster);
- `frame` copies the 2,081² frame (the tile plus an 80-sample margin) one sample at a time, with a dictionary lookup per sample, for each of five fields (about 22 M steps a tile).

The fix keeps the same bytes:
1. Decode the nine tiles' rasters once, before the threads start. That is 45 rasters, about 670 MB of floats; the bake peaked at 15.5 GB of 31.9. Use the engine's own `to_float32_array()` for f4 fields.
2. Build each frame from row slices instead of single samples.
3. Drop the lock, because nothing is written after the load.

Estimate: the record stage falls to a few seconds a tile, and the stages are then about 30 s a tile on every thread at once.

**The bake's setup: 418 of its 624 s, on one thread, before any tile starts.** Dino's log of the 8 Nov bake: "Setup (world elevation, wet air, river network, tables) in 417696 ms" and "9 tiles on 9 threads in 205.8 s".
- **What it builds** (`tile_baker.gd` `setup`, all GDScript on one thread):
  - the world elevation for the whole 21×21 world at 160 m (about 2,016² = 4.1 M cells of sketch shaping);
  - the wet-air field for the whole world;
  - the rule bake's river network for the whole world, with its meanders and head ponds ("20998 river cells in 4400 chains");
  - the tables;
  - the record's `network.json`, which is parsed when the record opens.

  The log prints only the total. A per-part line costs nothing to add, and the fix PR should add it before the split is guessed.
- **How it scales:** with the world, not the tiles. A bake of 1 tile or 227 pays the same 418 s once. That is two thirds of a 9-tile bake, and 7 min of a 1 h 36 min full-world bake.
- **Caching:** the cache exists (`setup_cache.gd`, which saves the elevation, wet air and river network), but it is nearly always missed. Its key hashes every script under `src/worldgen/sketch`, `settings`, `tile`, `tables` and `runtime`, plus the whole of `tile_rules.json` and `tile_plan.json`. So a change to `tile_sites.gd` or to a sites rule means a full setup again, and every bake after a code change pays it. Two fixes:
  1. Key only what the setup reads: the sketch and settings scripts, `river_network.gd`, the wet-air builder, `world.json`, `sketch_rules.json`, `world_sketch.json`, and the `tile_rules` blocks the setup reads, hashed as blocks rather than as the whole file.
  2. Skip the river network when every tile in the bake is inside the record, since record tiles never read it (`_finish` reads only the wet air, the elevation and the sketch).

  A cache hit then costs one file load (not timed; estimate under 30 s).
- **With the lock fix as well** (estimate): nine tiles in about 1 to 2 min when the setup comes from the cache, and about 8 min when the sketch or elevation code has changed.

**As built (9 Nov; Dave: "good make it so. I approve it all.").** The bake fixes above, in one PR:
- `water_record.gd`:
  - `prepare` decodes the rasters a batch of tiles reads (each tile and its neighbours inside the record) once, then the record is read only;
  - `field_problem` and `frame_and_gaps` write nothing, so threads call them at once;
  - frames are copied as row slices;
  - plain fields decode in one call (f4) or one short loop, and the water class goes through its code table in the same pass.
- `tile_baker.gd`:
  - `_bake_from_record` takes the lock only for a record that was not prepared (a one-thread bake, a test);
  - `setup` opens the record first and skips the rule river network and its ponds when every tile asked for is in the record;
  - `setup` prints "Setup parts (ms): …".
- `bake_tiles.gd` `--threads=N` bakes in batches of N tiles and prepares the record before each, so the rasters held are one batch's (a full world does not hold them all).
- `setup_cache.gd` keys on:
  - the sketch and settings folders;
  - the scripts the setup's builders reach (16 of worldgen's 384 on main), by `res://` path or class name;
  - the input files;
  - the `climate`, `water` and `valleys` blocks of `tile_rules.json`;
  - whether the rule rivers were built.

The tiles must come out byte for byte the same as the ws580v bake. Dino checks this by rebaking the nine tiles on Dave's PC and comparing them.

**Measured (Dino, 9 Nov):** two bakes of the nine ws580v tiles on Dave's PC, the first with an empty setup cache and the second from it (`pr788_same_bytes.txt`, `pr788_bake_a.log`, `pr788_bake_b.log`). All nine tiles came out byte for byte the same as the ws580v bake, in both runs.

| | before (8 Nov log) | cache miss | cache hit |
|---|---|---|---|
| setup | 417,696 ms | 268,976 ms | 750 ms |
| 9 tiles on 9 threads | 205.8 s | 57.3 s | 57.3 s |
| record stage, per tile | 40,077 to 174,768 ms | 7,435 to 7,870 ms | 7,621 to 8,074 ms |
| whole bake | 624 s | 5 min 27 s | 59 s |

- On a miss, 263,930 ms of the setup is the world elevation. That is what is left to cut there (recommendation 4).
- A tile now takes about 40 to 50 s, all on its own thread. Land types (10 to 15 s) and geology (12 to 17 s) are its biggest stages.

## 3. What a run costs: today, and after the cuts

| run | today (measured sums) | after the evolve cut, a, the runner, the bake fixes (lock and setup cache), and rebake_check left to the gate; the settle stays (estimate, with the bake measured) | also b, c, d (estimate) |
|---|---|---|---|
| tile rules change (springs, caves, sites), 9 tiles | 19 min (if no one starts the chain) | 59 s for the bake, setup from the cache (measured); 6 min more when the tile's water changes and it is settled again | the same |
| water rules change (R3–R6), 9 tiles | 22 min | about 10 min: lakes to record 2.5 min, the bake 1 min, the settle 6 min | the same |
| land changes (tonight), 9 tiles | 1 h 50 min | about 50 min to 1 h 5 min | about 25 to 30 min |
| full world, first time (all windows, 227 tiles) | about 2 h of chains (9 at once) + 1 h 36 min bake + 2.4 h water ≈ 6 h | about 1 h + 4.5 min setup + 26 rounds × 57 s ≈ 25 min + up to 2.6 h of settle ≈ 4 h | about 35 min + 30 min + up to 2.6 h ≈ 3.7 h |

Even today a first full world fits in one night: about 6 h, against Dave's limit of 10. With the cuts it takes about 4 h, and the settle is most of that until R7 lets the water be seeded from the record (section 2). The everyday case gains the most: one island and a rule change take about a minute, not 19 (or 2 h when the chain is started by habit).

## 4. What could go, merge, or stop being checked

- **Delete:** evolve's steps after 100 kyr; the snapshots after t100k; settle + refilm for record tiles, once the `.water` file is written from the record. *The settle stays for now (PR C, 9 Nov): the measurement in section 2 failed.*
- **Merge:** `check_record.py` into `record.py`'s own summary. It lives only in the shared folder and repeats checks that `record.py` already makes (closed cells, frame land, summit). The two Godot exports could share one Godot start and thread their 9 tiles (estimate: 5 min down to about 1).
- **Redundant checks:**
  - `rebake_check.sh` runs `test_drainage_fill`, `test_river_surface` and `test_head_pond_fill`, which David4's gate runs again on the PR. It can come out of the bake run. *Done in PR C (9 Nov): the script is in `proposed_removals/`, and `tools/test_lanes.json` lists all three tests for baked tiles and water, so the gate's bake class always runs them.*
  - `test_head_pond_fill` guards rule-bake head ponds, which record tiles no longer have. Its own decision table says to archive it once natural rivers are on.
  - Glacial works out the peak shapes after every cycle. That was for the summit question, which is now closed, so it could run only at the end (its time isn't measured; small, estimate).
- **Keep:** every chain stage itself. Each makes one of the goals (ground, ice, lakes, groundwater, network, record), and none duplicates another.

**My recommendation, in order:**
1. The bake's two fixes:
   - the record load: decode once, slice the frames, drop the lock;
   - the setup cache key: what the setup reads, with no river network for record-only bakes;
   - a per-part setup line in the log.

   The bytes stay the same, and a 9-tile bake should fall from 624 s to about 1 to 2 min (estimate). *Done (9 Nov): the bytes are the same, and the bake is 59 s from the cache and 5 min 27 s without it (measured, section 2).*
2. The evolve cut and the runner with skip-by-hash. These are small, and they don't change results.
3. Cropping windows to their islands, and writing `.water` from the record. *The `.water` file waits for R7 (measured in section 2).*
4. The bake's setup and packing time, from the bake log's lines.
5. One probe each for b and c against ws580v before either becomes the rule.

## 5. Could glacial be replaced by cutting the peak by a set share?

Dave, 9 Nov: "if we know the glacial always cuts the peak height off by x percent why dont we just find the height by seed and reduce it x percent instead of all the glacial or does it serve any other purpose."

**The share isn't fixed.** On ws580u the summit rose from 1,446 m after cycle 1 to 1,586 m by cycle 25, then fell to 1,338 m by cycle 49 (the manifest's cycles list). The −7% at the end is what is left of a climb and a fall, both driven by the rock uplift against the ice's cutting. Another island, with its own height, rock and snowline, would end at a different share.

**The summit is the smallest thing glacial does.** These are ws580u's own numbers (`manifest_ws580u_full.json` summary):
- Ice covered 64 km², 18% of the island's 362 km². Under the ice it cut 294 m on average and up to 1,176 m. That cutting makes the troughs, cirques and horns on every high massif, not only at the top.
- **Every lake comes from it.** 105 of the 106 hollows, 0.404 of 0.404 km², are ice-scoured floors. `lakes.py` keeps a hollow as a lake only when it has a cause (design A1), so with no glacial the island has no lakes.
- It lays 6.3 km² of outwash gravel and 1.05 km² of till. These are the aquifers and stream beds of the lower valleys.

**What each later stage reads from `glacial.npz`** (from the code on main):

| stage | reads | for |
|---|---|---|
| lakes.py | `ground`, `sea`, `hollow_cause` | the final ground everything after builds on; which hollows may hold a lake |
| groundwater.py | `till_m`, `sediment_m`, `channel` | aquifer thickness and the springs |
| network.py | `rock`, `till_m`, `outwash_m`, `sediment_m`, `sediment_flux_m3_yr`, `ice_max_m`, `et_mm`, `quick_mm`, `recharge_mm`, `channel` | bed material, reach types, flows through the year |
| record.py | `sediment_m` (and the ground, through lakes.npz) | the loose cover on the tiles |

**With no glacial and a summit scale, what goes:**
- the lakes;
- the cirques, troughs and horns;
- the outwash and till under the valleys, and with them the springs and stream beds they make.

The mountains would be the river era's V valleys, only shorter. The summit would come out right and everything else would be wrong.

**The cheapest substitute that keeps the look: the same glacial on a 32 m grid.** The ice works at the scale of troughs hundreds of metres wide, and groundwater already solves at 64 m and rain at 128 m. At 32 m the grid has a quarter of the cells, and each step costs about a quarter or less, so glacial would take about 13 to 15 min instead of 61 (estimate). If the big shapes hold, the next step is a short 16 m finish: the 32 m cut added to the 16 m river ground, then the last interglacial at 16 m to sharpen the channels. That needs code, so it waits for the probe.
- A one-pass carve, with U-shapes stamped along the ice-flux paths above the snowline, would take seconds. But its shapes are set by hand rather than modelled, so I'd try it only if the 32 m probe fails.
- Fewer cycles is ruled out by the summit's climb and fall above.

**The probe** (no code; params only; on Dino after the ws580v chain, so nothing slows it): ws580v at 32 m model cells, with `/mnt/project-files/water/ws580v32_probe_params.json` (ws580u's params with `model_step` 4).
- **Order:** geology export `--step=32` → inputs → evolve to 100 kyr (`--set.evolve.years=100000`) → glacial → lakes → groundwater → network.
- **Reused:** the landform export comes from ws580v.
- **Stop:** `record.py` refines a 16 m grid only, so the probe stops at network, and carved cells can't be compared. R5's reach count and length stand in for them.
- **Compare:** `python /mnt/project-files/water/compare_runs.py` with ws580v's B2, R3 and R5 folders, then the probe's B2, R3 and R5 folders, then an output PNG. It prints, base against probe:
  - summit, ice km², ice-scoured hollow km², lakes and lake km²;
  - R5 reaches, km and spring heads;
  - the ground difference on land (mean, 95th percentile, and km² over 20 m and over 50 m).

  It also writes three pictures side by side: base, probe, and probe minus base.
- **Pass lines** (each judged; Dave can set them):
  - summit within 60 m (two 16 m runs with the same params ended 55 m apart, below);
  - lake km² within 20%;
  - reach km within 10%;
  - ground within 20 m over 95% of the land.
- **Why the summit line is 60 m, not 10.** ws580u and ws580v ran the same params at 16 m and ended at 1,338.1 m and 1,393.0 m.
  - They agreed within 1 m for 22 cycles, and their B1 summit was the same.
  - Once a horn's three headwalls meet at the top, which 16 m cell survives is chaotic, and the summit moves by tens of metres.
  - The ice work matched within a few percent: ice area, mean cut, outwash and till.
  - So no tight summit rule stops a run, and the summit is never the deciding check.
- **The deciding test (Dave, 9 Nov: "we should say if it comes close to tonights land. its a trade of of perfect for speed and what is a reasonable tradeoff"):** the same lakes and rivers in the same places. A near miss on one pass line passes; a lost lake or a broken river fails. `compare_runs.py` prints "same places" and ends with `verdict: PASS` or `verdict: FAIL`.
  - **The bar is the model's own spread.** The probe is compared with the base (ws580v), and also with a second run of the base's own model (the reference, ws580u). Two such runs already differ: ground p95 30.5 m, and 89% of river km in place. Each place check therefore allows the probe to sit up to 1.25 times as far from the base as the reference does, but never less than a floor:
    - 5% of the base's lake area in lost lakes;
    - 5% of the river km moved;
    - ground p95 20 m;
    - summit 60 m.
    Without a reference run, fixed limits apply: 20% of lake area lost, 10% of river km moved, ground p95 20 m, summit 60 m.
  - **Lakes are matched by footprint.** A base lake is still there when half of its footprint, grown by one probe cell, is lake in the probe. The two runs may be on different grids, so footprints are compared in world metres. Lost lakes of 0.002 km² or more are listed by name.
    - The first rule matched deepest points within 150 m. It counted a basin as lost when the ice had only moved its deepest point (4 basins on ws580u against ws580v), so it is retired.
  - **Rivers:**
    - The check covers reaches draining 1 km² or more.
    - A reach is in place when 80% of its points lie within 64 m of a probe reach.
    - The share of river km in place is judged against the spread, as above.
  - **Broken rivers:** reaches that end nowhere (not at the sea, a lake or another reach). The probe may have no more of these than the base or the reference.
  - **Near miss:** a pass line no more than 1.5 times past its limit.
  - **PASS** when the same places hold and at most one pass line is a near miss.
  - Every distance, share and allowance here is judged, not Dave's.
- **Time on Dino (estimate):**

  | step | time |
  |---|---|
  | geology export at 32 m | about 1 min |
  | inputs | seconds |
  | evolve | about 1 min |
  | glacial | about 13 to 15 min |
  | the three water stages and the compare | about 1 min |
  | total | about 20 min |

**Against Dave's targets.** If the probe passes and the 16 m finish holds, nine tiles take, end to end:

| step | time |
|---|---|
| exports | 5 min |
| evolve | 4.6 min |
| glacial at 32 m with the 16 m finish | about 15 to 20 min |
| water (lakes to record) | 2.5 min (measured on ws580v) |
| bake | 59 s or 5 min 27 s (cache hit or miss, measured) |
| settle + refilm | 6 min (363 s, measured on ws580v) |
| total | about 35 to 45 min |

That is well under the hour (estimate). Without it, the cuts in section 3 give about 50 min to 1 h 5 min. A full world is about 3.7 to 4 h with the cuts while the settle stays, and about 6 h today (section 3). Either fits inside the 10 h night.
