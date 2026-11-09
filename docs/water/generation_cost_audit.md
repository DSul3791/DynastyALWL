# Generation cost audit (9 Nov 2026)

Sonny, for Dave. Dave asked whether this whole chain has to run every time tiles are made, because there are 9 tiles now and 441 later: "Im worried we have let the process bloat again. we need to look at the generation process and see if it can be simplified to achieve the same goals with much faster turnarounds." This note proposes cuts and changes no code. "Measured" means a Dino time from 8 or 9 Nov. "Estimate" is my judgement.

**The short answer:** no. The chain (export to record) only needs to run when the land itself changes. A change to tile rules (springs, caves, sites) needs only the bake, about 19 min. Tonight's run is the whole chain because removing `spawn_keep` changed the land. But nothing skips a stage today, and the job sheets are written by hand, so a full run is easy to start when it isn't needed.

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

The starter window adds up to about 88 min for the chain plus 19 min for the bake through the check, about 1 h 50 min in all.

**Scaling to 21×21.** The plan has 441 tiles, of which 227 need a file, with 4,398 km² of land on 323 islands (`tile_plan_summary.txt`).
- **One window for the whole world:** 20,161² = 406 M cells, which is 49× the starter window. Glacial would take about 49 × 61 min ≈ 50 h on one thread, and the memory would be 49× as well. That is not feasible, so the chain must stay per window.
- **Windows like the starter's:** the starter window holds 362 km² of land and the world has 4,398 km², so about 12 windows' worth. One thread doing them one after another: 12 × 88 min ≈ 18 h. Nine windows at once (the stages are single-threaded, so this is how the nine threads get used): about 18 h / 9 ≈ 2 h of wall time (estimate; the windows vary in size, so they pack unevenly). That needs about nine windows' worth of memory at once. Glacial's memory is not measured; my estimate is a few GB per window.
- **Per tile:** the bake is 418 s of setup once, plus 227 / 9 = 26 rounds × 206 s ≈ 1 h 36 min. Settle + refilm 26 × 338 s ≈ 2.4 h.

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

## 3. What a run costs: today, and after the cuts

| run | today (measured sums) | after the evolve cut, a, the runner, seeding, the bake fixes (lock and setup cache), and rebake_check left to the gate (estimate) | also b, c, d (estimate) |
|---|---|---|---|
| tile rules change (springs, caves, sites), 9 tiles | 19 min (if no one starts the chain) | about 1 to 2 min (the bake, setup from the cache) | the same |
| water rules change (R3–R6), 9 tiles | 22 min | about 5 min | the same |
| land changes (tonight), 9 tiles | 1 h 50 min | about 45 min to 1 h | about 20 to 25 min |
| full world, first time (all windows, 227 tiles) | about 2 h of chains (9 at once) + 1 h 36 min bake + 2.4 h water ≈ 6 h | about 1 h + 7 min setup + 26 rounds × 35 s ≈ 22 min + minutes ≈ 1 h 25 min | about 35 min + 22 min ≈ 1 h |

Even today a first full world fits in one night: about 6 h, against Dave's limit of 10. With the cuts it takes an evening. The everyday case gains the most: one island and a rule change take about 2 min, not 19 (or 2 h when the chain is started by habit).

## 4. What could go, merge, or stop being checked

- **Delete:** evolve's steps after 100 kyr; the snapshots after t100k; settle + refilm for record tiles, once the `.water` file is written from the record.
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

   The bytes stay the same, and a 9-tile bake should fall from 624 s to about 1 to 2 min (estimate).
2. The evolve cut and the runner with skip-by-hash. These are small, and they don't change results.
3. Cropping windows to their islands, and writing `.water` from the record.
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
- **Pass:**
  - summit within 10 m;
  - lake km² within 20%;
  - reach km within 10%;
  - ground within 20 m over 95% of the land.

  These limits are judged; Dave can set them.
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
| water | 3 min |
| bake | about 1 to 8 min (cache hit or miss) |
| total | about 30 to 40 min |

That is well under the hour (estimate). Without it, the cuts in section 3 give about 45 min to 1 h. A full world is about 1 to 1.5 h with the cuts, and about 6 h today (section 3). Either fits inside the 10 h night.
