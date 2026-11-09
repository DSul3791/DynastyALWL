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
| A2. The numpy sums of a cold step on nine threads in one numba kernel. `Aeff ** m` and `Qwi ** m` are each computed twice today (for `kq` and for `kq_c`), and once is enough | no for the shared powers. Numba's and numpy's `pow` may differ in the last bit, which the check would show | that part's share of the 3.06 s × about 8/9. It is sized by the split profile below |
| B. 4,000-year cold steps in the 41-kyr cycles (the audit's cut b) | yes | about 25% of what is left (156 fewer steps). It needs a probe judged by `compare_runs.py`, the stable lakes and rivers included, and runs only if A1 and A2 leave glacial over about 25 min |

**Next measurement (Dino, about 2 min; `water/glacial_split_profile_job.md`):** the same cycle, with each numba kernel wrapped in a plain Python function so the profile lists it on its own (`water/glacial_split_profile.py`; the arithmetic is unchanged). It splits the 3.06 s into the in-order kernels and the numpy sums. It also shows whether one in-order kernel (most likely `_solve`) is the big one; that would get its own note.

**A1 can be coded now.** It is sized by measured calls, and the check needs no other cut.

**What it could give (estimate):** glacial from 61 min to about 49 min with A1. A2 is sized after the split profile. A chain that sets `NUMBA_NUM_THREADS=9` for glacial too (Dave's nine-thread rule; today only evolve sets it) runs A1 and A2 on the nine threads.

## What stays

- The 16 m grid, the 49 cycles and the physics.
- The outputs, on the same window grid, so lakes.py, groundwater.py, network.py and record.py read what they read today.
- No runs in the cloud. The profile, the comparisons and any probe run on Dave's PC.
