# A faster glacial stage, still on 16 m cells (design note; Sonny, 9 Nov 2026)

The coordinator asked for the next speed cut after #822 and #828. A land change on the nine starter tiles is the slow case today: 1 h 50 min measured, or about 50 min to 1 h 5 min with the cuts already decided. Dave wants it well under an hour (his rule d). A full world is about 2 h 10 min with the cuts, already inside his 10 h.

The biggest measured step is glacial: 3,664 s (61 min) on ws580v. The 32 m probe failed (C3 closed, `docs/water/generation_cost_audit.md` section 5), so glacial stays on the 16 m grid. This note says how to make it faster on that grid. It proposes no code until one measurement is in.

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

## The measurement first (Dino, about 4 min; job `water/glacial_profile_job.md`)

1. **A one-cycle profile.** Run glacial on ws580v's inputs with the history cut to one 41-kyr cycle (8 cold and 2 river steps), under Python's `cProfile`. The numba kernels show up as single calls, and the numpy sums show up as `_cold_phase`'s own time. So the profile splits each step into the in-order kernels, the numpy sums, and the rest.
2. **The crop share.** Find the box round the land plus 1 km of sea, and its share of the window. Also check whether land touches the window's frame.

## The cuts, in order (after the measurement)

| cut | changes the result? | saving (estimate) | check |
|---|---|---|---|
| A. Crop each step to the land box plus a margin (the audit's cut a, for glacial first): run on the box, and write the outputs back onto the window grid so later stages are unchanged | expected no. Every in-order pass already starts from the sea, and the margin keeps the sea round the coast | glacial's time × (1 − crop share): 30 to 50% if the box is half to two thirds of the window | the land cells of `glacial.npz` against ws580v's, array by array; if they are not equal, `compare_runs.py` against ws580v with ws580u as reference |
| D. The numpy sums of a step fused into one numba kernel on nine threads (Dave's nine-thread rule) | possibly in the last bit: numba's and numpy's `pow` may round differently | that part's share of a step × about 7/8, if the profile shows it is large | the same: equal arrays, or else the bar |
| B. 4,000-year cold steps in the 41-kyr cycles (audit cut b) | yes | about 25% of glacial (156 fewer steps) | a probe judged by `compare_runs.py`, the stable lakes and rivers included; only if A and D leave glacial over about 25 min |

**Why A first.** It cuts every part of a step, the in-order ones too, and it keeps the arithmetic. The risk is at the frame: if land touches the window's edge, the box can't shrink on that side, and the saving is smaller.

**What it could give (estimate until the profile):** glacial from 61 min to about 30 to 43 min with A, and to about 20 to 30 min if D also pays. A land change on nine tiles would then be about 35 to 50 min.

## What stays

- The 16 m grid, the 49 cycles and the physics.
- The outputs, on the same window grid, so lakes.py, groundwater.py, network.py and record.py read what they read today.
- No runs in the cloud. The profile, the comparisons and any probe run on Dave's PC.
