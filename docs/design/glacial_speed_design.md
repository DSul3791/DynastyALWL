# A faster glacial stage, still on 16 m cells (design note; Sonny, 9 Nov 2026)

The coordinator asked for the next speed cut after #822 and #828. A land change on the nine starter tiles is the slow case today: 1 h 50 min measured, or about 50 min to 1 h 5 min with the cuts already decided. Dave wants it well under an hour (his rule d). A full world is about 2 h 10 min with the cuts, already inside his 10 h.

The biggest measured step is glacial: 3,664 s (61 min) on ws580v. The 32 m probe failed (C3 closed, `docs/water/generation_cost_audit.md` section 5), so glacial stays on the 16 m grid. This note says how to make it faster on that grid. The first measurement is in (below); it moves the plan from a crop to threads.

## What glacial does (from the code)

- 49 cycles: 39 of the 41-kyr world and 10 of the 100-kyr world. That is 512 cold steps of 2,000 years and 138 interglacial river steps of 1,950 years, 650 steps in all, at about 5.6 s each. Each step works on all 8.3 M cells of the window (2,881² samples), and 83% of the window is sea.
- **The parts that must stay in order** (each cell needs the result of the cells before it):
  - the priority flood and order (`lem.route`);
  - the D8-LTD receivers (`_ltd_receivers`, whose drift is carried down the flow path);
  - the ice flux, the discharges and the channel share's carry downstream;
  - the implicit solve (`evolve._solve`);
  - the slope ceiling's raster sweeps (`_slope_ceiling`).
- **The parts that could run on nine threads with the same arithmetic:**
  - the whole-grid numpy sums in `_cold_phase`: Aeff, water, kq, kq_c, Qd, thick, kc and the cell limits, each a pass over 8.3 M cells, several with a power;
  - the creep sweeps, which are already parallel (`_creep_sweep`).
- **Nobody has measured** which part is most of the 5.6 s.

## What the profile measured (Dino, 9 Nov, main 540ac3c5)

One 41-kyr cycle (8 cold and 2 river steps) on ws580v's inputs, under `cProfile`: 89.6 s in all, and the ten steps took 55 s (`water/glacial_profile_job.md`, `glacial_profile_ws580v.txt`).

- **Per step.** A cold step took 5.47 s (`_cold_phase` 43.8 s over 8), a river step 4.74 s (`_river_phase` 9.5 s over 2). Over 512 cold and 138 river steps that is 3,455 s. The chain measured 3,664 s, and the rest is the start, the seven snapshots and the outputs.
- **Inside a cold step (5.47 s):**
  - `_cold_phase`'s own time, 3.06 s: the in-order kernels it calls (`_ice_flux`, `_donors`, `_swath`, `_discharge` twice, `_channel_share`, `_solve`) and the numpy sums together. cProfile does not see inside a numba call, so this profile cannot split them.
  - `rock.rock_ids`, 0.95 s: the bedrock id of every cell, on one thread, the sea included. The same lookup inside `parts`, which skips the sea, takes 0.18 s.
  - `evolve.route`, 0.82 s: the priority flood and the D8-LTD receivers. The flood already works on land alone (the sea is marked seen and never enters the heap).
  - the cover and creep: `parts` 0.18 s, `fn` 0.12 s, `_diffuse` 0.16 s, `cell_limits` 0.05 s.
- **Once a run, not once a step:** the picture (15.4 s), the `glacial.npz` save (7.3 s) and the report (4.2 s). Together that is under 1% of a full run, so they are not worth a cut. They look big only in a one-cycle profile.
- **The crop share:** "window 2881 land share 0.171 box rows 0 2880 cols 0 2880 box share 1.000 land on the frame True". Land touches the window's frame, so the box round the land is the whole window, and the old cut A (a crop to that box) saves nothing. It is dropped. Land is 17.1% of the cells.
- **`rock_ids` can't be kept from one step to the next.** Every step lowers the ground, and a cell that cuts into the next layer changes rock. Threads give the same ids every step, so they are the safe speed-up.

## The cuts, in order

Cuts A1 and A2 keep every number. The check for both: Dino runs glacial on ws580v's inputs, and every array of `glacial.npz` must equal ws580v's (`np.array_equal`). If any differs, the next check is `compare_runs.py` against ws580v, with ws580u as the reference.

| cut | changes the result? | saving (estimate from the measured times) |
|---|---|---|
| A1. `rock_ids`, and the cover lookups `fn` and `parts`, on nine threads (`prange`; each cell is its own sum). Evolve (B1) uses them too and gains as well | no: the same per-cell arithmetic in a different order of cells | `rock_ids` 0.95 s to about 0.12 s on all 650 steps (about 540 s), `fn` and `parts` about 0.27 s a step (about 175 s): about 12 min |
| A2. The numpy lines of a cold step in five numba kernels on nine threads, over every cell, in numpy's order of operations (`fastmath` off). The powers stay numpy's `**`, taken only on the cells that keep them (the swath: the old `np.where` threw them away elsewhere), and `Aeff ** m`, `Qwi ** m` once each instead of twice. The step's constant arrays are made once a run | no: the same arithmetic cell by cell, and the same `**` | measured: the numpy lines were 1.15 s of a 5.4 s cold step (split profile), estimated at about 8.5 min over 512 cold steps; the full run measured 402 s (6.7 min) less than A1 |
| B. 4,000-year cold steps in the 41-kyr cycles (the audit's cut b) | yes | about 25% of what is left (156 fewer steps). It needs a probe judged by `compare_runs.py`, the stable lakes and rivers included, and runs only if A1 and A2 leave glacial over about 25 min |

**The split profile (Dino, 9 Nov, main 8545d12f; `glacial_split_profile_ws580v.txt`).** Each cold step of 5.4 s: `_solve` 1.49 s, the numpy lines 1.15 s, the rock lookups 1.24 s (A1), the route 0.83 s (`_ltd_receivers` 0.47 s, `lem.route` 0.36 s), the other kernels and creep about 0.7 s. `_solve` runs in every step, cold and river, so it is about 16 min of the 61; whether it gets a cut of its own (A3, before B) waits on `water/glacial_solve_split_job.md` (how much of it is the slope ceiling). The compression (zlib) is the output saves, once a run, not once a step.

**Measured (Dino, 9 Nov, ws580v's inputs and params, nine threads). Every array of `glacial.npz` and the seven cycle snapshots is equal to ws580v's:**

| | one cycle | full glacial (history done) | against before |
|---|---|---|---|
| before (ws580v) | 55 s (profiled) | 3,664 s, 61 min 4 s | |
| A1 (#840, 2d0b2bd7) | 47 s | 2,889 s, 48 min 9 s (wall 48 min 49 s) | 775 s less (21%) |
| A2 (#845, 6d5f2a1a) | 42 s | 2,487 s, 41 min 27 s (wall 42 min 7 s) | 402 s less than A1; 1,177 s less than before (32%) |
| A3 (#853, a722c016) | 43 s, of which about 8 s compiling (both changed files recompile on a first run); about 32.7 s a cycle warm, against A2's 38 s | 2,076 s, 34 min 36 s (wall 35 min 16 s) | 411 s less than A2; 1,588 s less than before (43%) |

**Where that leaves it.** Glacial has gone from 61 min to 34 min 36 s, measured. Nine tiles end to end are about 20 to 24 min plus glacial, so about 55 to 59 min with A3 (estimate). B is still needed for Dave's rule (d). Every stage of the chain now runs with `NUMBA_NUM_THREADS=9` (#840).

## What stays

- The 16 m grid, the 49 cycles and the physics.
- The outputs, on the same window grid, so lakes.py, groundwater.py, network.py and record.py read what they read today.
- No runs in the cloud. The profile, the comparisons and any probe run on Dave's PC.

## Cut A3: the implicit solve (sized from the solve split; coordinator approved 9 Nov)

**Measured (Dino, 9 Nov, #840 2d0b2bd7, one cycle; `glacial_solve_split_ws580v.txt`).** `evolve._solve` takes 1.44 to 1.59 s a call, 15.06 s for 10. Its slope ceiling (`_slope_ceiling`, raster sweeps in 6 to 8 passes) is 0.57 to 0.73 s of that, 6.37 s in all (42%). The rest (58%) is the solve's sweeps, up to 4, with their sediment bookkeeping. `_solve` runs in all 650 steps (cold and river) and in evolve (B1).

**Three parts. All of them are exact: every cell's arithmetic stays as it is, and so does the order of the cells within each river tree.**
- **A3a. The sweeps run on nine threads, one river basin at a time.**
  - In a sweep, a cell reads only its own values, its receiver's new height and the sediment from upstream of it. The sediment sum adds only within its own tree. So two basins never read or write each other's cells.
  - Each basin is the tree that drains to one outlet, the first cell whose receiver is the sea or none. Its cells keep their relative order from the route's `order`. So each sum adds the same numbers in the same order, and every height comes out bit for bit as before.
  - Each step, the basins are packed into nine buckets, largest first, each into the lightest bucket (ties by cell index). Each thread runs one bucket. The result does not depend on the scheduling, or on how many threads there are.
  - The largest bucket sets the speedup. Glacial logs its share of the land once a run (`solve buckets:`).
  - If a receiver ever came after its donor in `order`, or lay off it, the step runs in one thread as before. The route never makes such a receiver, but the check keeps the cut exact if one appears.
- **A3b. The sediment bookkeeping is done on land cells only.**
  - Each sweep made three passes over all 8.3 M cells: new zeros, a copy and the upstream loop. 83% of those cells are sea, where every value stays 0.
  - The arrays are now made once a call. Each bucket writes only its own cells.
- **A3c. The slope ceiling loops over a land index in the same raster order.**
  - It loops over the cells it does not skip (not sea, threshold above 0), forwards and then backwards, as before. Before, it looked at all 8.3 M cells in every sweep of every pass.
  - Its passes stay one thread. A different sweep order could settle on a different set of sources, so that would not be exact.

**Measured (Dino, 9 Nov, a722c016):** the full glacial took 2,076 s, 411 s less than A2's 2,487 s. All 8 files are array-equal to ws580v's. The run logged `solve buckets: 9 threads, the largest bucket 11.1% of the land cells, the largest basin 1.8% (21269 basins)`, so the buckets are even. One evolve (B1) run on ws580v's inputs and params gave all 7 ground files (the final ground and its snapshots) array-equal to ws580v's, in 14 min 27 s wall against ws580v's own 1,208 s (20 min 8 s): about 28% faster, A1's threaded rock lookups and A3 together, since ws580v ran before both. The one-cycle check took 43 s against A2's 42 s. That is compile time, not the cut: step 0 came at 17 s against 9 s, and the five warm steps after it took 14 s against 18 s.

**Estimate (before the run).** About 1.5 s down to about 0.85 s a call:
- A3a: the sweeps' 0.7 s falls to about 0.2 s, if no bucket holds more than a quarter of the land;
- A3b: about −0.15 s;
- A3c: about −0.05 s.

That is about 0.65 s × 650 calls, about 7 min a glacial. Evolve gains too.

**The check.** David4 runs `tools/watershed/test_evolve.py` (new: the new `_solve` and `_slope_ceiling` against verbatim copies of the old ones, on routed random islands with cover, ice lift, sea receivers and a forced one-thread case, at 1 and 9 threads), plus `test_glacial.py` and `test_rock.py`. Dino then runs three checks, and every array of every file must be equal:
1. one cycle against the profile's one cycle on main;
2. the full glacial on ws580v against ws580v's own outputs;
3. one evolve run against ws580v's evolve output.

**After A3 (measured 34 min 36 s):** nine tiles take about 55 to 59 min (estimate). B (4,000-year cold steps, about 8 min less at A3's 3.2 s a step; estimate) is then still needed for Dave's rule (d). B changes the result, so its probe (`water/glacial_b_probe_job.md`) runs only after A3 is measured, and is judged by `compare_runs.py` against ws580v.
