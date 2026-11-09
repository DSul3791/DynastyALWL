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
| bake | 624 s for 9 tiles on 9 threads, so about 624 s per tile per thread | per tile | 9 |
| settle + refilm | 338 s for 9 tiles at once | per tile | 9 |
| rebake_check.sh | 196 s | per bake | 3 tests |

The starter window adds up to about 88 min for the chain plus 19 min for the bake through the check, about 1 h 50 min in all.

**Scaling to 21×21.** The plan has 441 tiles, of which 227 need a file, with 4,398 km² of land on 323 islands (`tile_plan_summary.txt`).
- **One window for the whole world:** 20,161² = 406 M cells, which is 49× the starter window. Glacial would take about 49 × 61 min ≈ 50 h on one thread, and the memory would be 49× as well. That is not feasible, so the chain must stay per window.
- **Windows like the starter's:** the starter window holds 362 km² of land and the world has 4,398 km², so about 12 windows' worth. One thread doing them one after another: 12 × 88 min ≈ 18 h. Nine windows at once (the stages are single-threaded, so this is how the nine threads get used): about 18 h / 9 ≈ 2 h of wall time (estimate; the windows vary in size, so they pack unevenly). That needs about nine windows' worth of memory at once. Glacial's memory is not measured; my estimate is a few GB per window.
- **Per tile:** bake 227 / 9 = 26 rounds × 624 s ≈ 4.5 h. Settle + refilm 26 × 338 s ≈ 2.4 h.

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

**The bake itself.** A record tile copies its ground and water, so 624 s per tile is more than the copy needs. The rest is geology, climate, sites and packing, but nobody has looked at the split. Tonight's bake log prints the stages per tile ("Tile X baked in … stages {…}"). Dino can send those lines, and the next cut is chosen from them, not guessed.

## 3. What a run costs: today, and after the cuts

| run | today (measured sums) | after the evolve cut, a, the runner, seeding, and rebake_check left to the gate (estimate) | also b, c, d (estimate) |
|---|---|---|---|
| tile rules change (springs, caves, sites), 9 tiles | 19 min (if no one starts the chain) | about 11 min (the bake) | the same, unless the bake profile finds more |
| water rules change (R3–R6), 9 tiles | 22 min | about 13 min | the same |
| land changes (tonight), 9 tiles | 1 h 50 min | about 1 h | about 30 min |
| full world, first time (all windows, 227 tiles) | about 2 h of chains (9 at once) + 4.5 h bake + 2.4 h water ≈ 9 h | about 1 h + 4.5 h + minutes ≈ 5.5 h | about 35 min + 4.5 h ≈ 5 h; the bake profile decides the rest |

A first full world is one night either way. The cuts matter most for the everyday case: one island, a rule change, 15 min instead of 2 h.

## 4. What could go, merge, or stop being checked

- **Delete:** evolve's steps after 100 kyr; the snapshots after t100k; settle + refilm for record tiles, once the `.water` file is written from the record.
- **Merge:** `check_record.py` into `record.py`'s own summary. It lives only in the shared folder and repeats checks that `record.py` already makes (closed cells, frame land, summit). The two Godot exports could share one Godot start and thread their 9 tiles (estimate: 5 min down to about 1).
- **Redundant checks:**
  - `rebake_check.sh` runs `test_drainage_fill`, `test_river_surface` and `test_head_pond_fill`, which David4's gate runs again on the PR. It can come out of the bake run.
  - `test_head_pond_fill` guards rule-bake head ponds, which record tiles no longer have. Its own decision table says to archive it once natural rivers are on.
  - Glacial works out the peak shapes after every cycle. That was for the summit question, which is now closed, so it could run only at the end (its time isn't measured; small, estimate).
- **Keep:** every chain stage itself. Each makes one of the goals (ground, ice, lakes, groundwater, network, record), and none duplicates another.

**My recommendation, in order:**
1. The evolve cut and the runner with skip-by-hash. These are small, and they don't change results.
2. Cropping windows to their islands, and writing `.water` from the record.
3. The bake profile from tonight's log.
4. One probe each for b and c against ws580v before either becomes the rule.
