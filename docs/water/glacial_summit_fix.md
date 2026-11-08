# Glacial summit fix: why ws580h's ice took the peaks down, and the probe that picks the fix

Sonny, 8 Nov 2026. This is the build note for the cause of ws580h's line 4 failure (`docs/water/rule6_build_plan.md`, line 4: each checked summit within 25 m of its landform after the ice; D-10). Rule 6 says the cause is fixed, not guarded. Nothing here is run in the cloud. Locally only `py_compile`, `pyflakes` and `check_doc_links.py` run. David4 runs `tools/watershed/test_glacial.py`, and Dino runs the probes on Dave's PC.

## What ws580h showed

Line 4 failed on all three checked summits (Dino's stage 3 run, glacial manifest `summary.cycles`):

| summit | landform | after the ice | loss |
|---|---|---|---|
| main, x 54800 z 71440 | 1,441.3 m | 543.8 m | 897.5 m |
| second massif, x 66800 z 79760 | 977.3 m | 593.3 m | 384.0 m |
| x 65360 z 81520 | 910.2 m | 612.0 m | 298.2 m |

The main summit, cycle by cycle:

- **Cycles 1 to 21.** The summit holds: 1,438 m, then 1,425 m. The plateau shrinks from 110 m to 18 m, and the slope within 300 m steepens from 37 to 52 degrees. The three headwalls cut back from 96 to 136 m from the top to 16 to 32 m. This is the horn that rule 6 asked for, standing 1 m under the 25 m line at cycle 21.
- **Cycles 22 to 39** (the rest of the 41 kyr world). The headwalls have met at the top. The floors within 600 m beyond them fall from 507, 584 and 734 m to 314, 145 and 209 m, and the summit falls 404 m to 1,021 m.
- **Cycles 40 to 49** (the 100 kyr world). The floors fall only 60 to 140 m more, to 65 to 180 m, yet the summit falls 477 m to 544 m. The horn's faces are being cut back, not only undercut.

All three summits ended 57 to 125 m above the 100 kyr world's snowline (487 m). That is the glacial buzzsaw: with no rock uplift, ice wears all ground above the snowline toward it. The cycle-20 and cycle-39 zooms show the massif as a Y of 57-degree faces between broad flat-floored troughs that reach the top.

Real cirque floors sit near the snowline of the glaciers that cut them (Porter 1989, via #654), and a cirque deepens about ten times slower after its first cycle (#654). Here the troughs under the main summit were cut 300 to 400 m below the snowline, within 600 to 900 m of the top, and kept deepening at about 1.6 mm a year of active ice from cycle 3 to cycle 20.

## Two faults in the model that feed it

**1. Trough ice laid up the walls above its own surface.** `_swath` gives every cell within half a glacier's width of an ice cell, up that cell's donor tree, the cell's ice flux, and so its thickness (delta × width). On a valley floor that is the U-trough: the glacier fills its valley and erodes the floor and lower sides across its width (Hergarten 2021, section 3). At a valley head, though, the donor tree climbs the headwall. A trough glacier 460 m wide (half-width 229 m) then lays its whole flux and about 115 m of ice on every headwall cell within 229 m of the floor, even where the wall rises far above the ice. The erosion term uses the slope of that ice surface, which on a draped wall is the wall's own 57 degrees, about ten times a trough floor's. So the head and side walls were cut at trough rates times ten.

A real glacier covers its valley only up to its own surface. Above the bergschrund the headwall is bare rock, and it retreats by frost and rockfall at the measured headwall rates (0.5 to 1.0 mm a year while active, #654), not at the trough's.

The fix is `glacial.swath_below_ice_surface`. A cell joins a glacier's swath only if its ground lies below that glacier's ice surface (the start cell's ground plus delta × width), and the walk up the donor tree stops there. The swath's cells hold ice only up to that surface. On a valley floor and gentle sides nothing changes (`test_glacial.py`: same swath on a gentle floor). The walls above the ice keep their own small flux, and the threshold-slope cap still fails them when the floor below is cut.

**2. Glaciers melt too slowly below the snowline.** The mass balance (Hergarten's eq. 23, as `glacial.py` has it) melts ice below the snowline at the same rate per metre as it makes ice above it. Hergarten chose that form for his examples; it is not a measured value. Measured glaciers lose mass faster per metre below the equilibrium line than they gain above it. The balance ratio (ablation gradient over accumulation gradient) of 1.56 is recommended from measured glaciers worldwide (Oien et al. 2022, Journal of Glaciology, testing the AABR method). The widely used mean of 1.75 is skewed by a few large values. With a ratio of 1, the ws580h glaciers reached the sea (`lowest_ice_m` 0.05), so their troughs were cut toward sea level right under the peaks.

The fix is `glacial.balance_ratio`: melt below the snowline is multiplied by it. That shortens the tongues and leaves the cutting near and above the snowline, where cirque floors are measured.

**Not a fault, noted.** The river-era K is three times the earlier pre-carve value (raised for quick steady-state runs). B1 picks its own length from snapshots, so its K is not tested against real years, while the glacial history runs in real years from the climate record. `glacial_K_ratio` 2 is Hergarten's ratio of glacial to fluvial erodibility. Its absolute value is therefore uncertain by that factor of three, and the probe measures how much it matters.

## The probe (Dino, Dave's PC)

These start from ws580h's `glacial_cycle_20.npz`, the horn just formed, and run the next 5 cycles of the 41 kyr world (`--start`; the params files set `glacial.history` to those 5 cycles). Each takes about 50 steps (5 to 6 minutes). Snapshots before this change did not keep the loose cover, so every probe starts from B1's cover. They are therefore compared with probe A, not with ws580h's own cycles 21 to 25 (1,425 to 1,371 m).

| probe | settings | what it tests |
|---|---|---|
| A | as ws580h | the baseline from the snapshot |
| B | `swath_below_ice_surface` true | fault 1 |
| C | `balance_ratio` 1.56 | fault 2 |
| D | both | the fix |
| E | `glacial_K_ratio` 0.667 | the time base, for scale only |

What each reports (its manifest's `summary.cycles`, main summit first): `top_m`, and each headwall's distance, floor and depth, after every cycle.

**Decision.** D is the fix to build if its main summit loses at most a fifth of A's loss over the 5 cycles, and its floors stop falling or fall at most 10 m a cycle (the measured slowed deepening, #654). Whichever of B or C does most of that is named as the main cause. The sign-off run is then ws580i's glacial stage from ws580h's B1 output, with all of rule 6's lines (4 to 12) judged as written. E is only reported. A change to the K ratio would need a measured glacial erosion rate on hard rock first, not a probe.

If D does not pass, nothing is changed in `params.json`, and the probe numbers decide the next cause to look at: cold-based summit ice, or rock uplift through the history (`glacial.py` takes B1's uplift, 0 since B1 dissects the landform).

## Files

- `tools/watershed/glacial.py`: `_swath` with the below-the-surface rule; the balance ratio in the mass balance; `--start SNAPSHOT.npz`; snapshots keep `sediment_m`.
- `tools/watershed/test_glacial.py` (new): the swath on a head wall and on a gentle floor.
- `params.json` `glacial`: no change until the probe decides. Both settings default to off, so older manifests reproduce.

## Probe result (Dino, Dave's PC, 8 Nov 19:10; manifests `manifest_A.json` to `manifest_E.json`)

The main summit, from 1,426.2 m at ws580h's cycle 20, after 5 more cycles of the 41 kyr world:

| probe | top after 5 cycles | loss | share of A's | 300 m floors, m a cycle |
|---|---|---|---|---|
| A as ws580h | 1,361.0 m | 65.2 m | 1 | 19 and 29 |
| B swath below the ice surface | 1,353.7 m | 72.5 m | 1.11 | 18 and 30 |
| C balance ratio 1.56 | 1,370.7 m | 55.5 m | 0.85 | 28 |
| D both | 1,320.6 m | 105.6 m | 1.62 | 30 to 38 |
| E glacial_K_ratio 0.667 | 1,413.0 m | 13.2 m | 0.20 | 5.5 (north-east) and 25 (south) |

**D fails the rule**, and no probe passes it: E comes closest, at 0.20 of A's loss, but its south head still falls 25 m a cycle. `params.json` is not changed. Neither fault is the main cause. Fault 1's fix makes the loss worse: the floors under the summit fall faster when the walls above the ice keep their own small flux. Why is not yet known. Fault 2's fix helps a little, but the glaciers still reach the sea (`lowest_ice_m` 0.05).

What the numbers show:

- **The summit stands at the threshold slope over the ground 300 m out** (1,321 m over 860 m in D is 57 degrees, granite's threshold). So it falls as fast as that ground does. The faces met at the top by cycle 21, as in ws580h.
- **The loss scales with the glacial erosion rate.** In A, the north-east floor falls about 1.2 mm a year of active ice. That is above every bedrock cirque floor rate in the compilation by Barr et al. (2019, Earth Surface Processes and Landforms, table 1): 0.1 to 0.9 mm a year (Ben Ohau Range, New Zealand, 0.29; Kråkenes, Norway, 0.5 to 0.6; Canadian Rockies 0.5 to 0.9). Only the rates from proglacial sediment run higher, and those measure sediment evacuation, not bedrock erosion. In E it falls 0.34 mm a year, inside that range. The same paper says a cirque grows about ten times slower after the cycle that first cuts it, so cycles 21 to 25 should sit at the low end. E's K is Hergarten's ratio of 2 applied to the river K before it was tripled for quick runs (4e-6), which is the time-base note above.
- **Even at measured rates, line 4 cannot be met with no rock uplift.** E loses about 2.6 m a cycle. Carried through the remaining 14 cycles of the 41 kyr world and the 100 kyr world (2.4 times the active ice per cycle), that is about 130 m more, against the 9 m left under the 25 m line. The design's own headwall rates (0.5 to 1 km of retreat over the history, rule 6's history note) also take a horn whose faces have met down by hundreds of metres. Horns stay high where rock uplift keeps pace.

## Next

1. Glacial K is set from the measured cirque floor rate, not from the quick-run river K: `glacial_K_ratio` 0.667 (2 times 4e-6, over the river K of 1.2e-5). With the measured balance ratio of 1.56, this is ws580i's glacial stage, run in full from ws580h's B1 output. All of rule 6's lines (5 to 12) are judged as written, and line 4 is judged and reported. That run gives the summit loss curve at measured rates.
2. Line 4 then needs rock uplift through the history (the second suspect above). Uplift comes from a design note first: its source, a measured rate, and where on the island it acts. Then code. The swath rule (fault 1) stays off until it is understood why it speeds the floors under a horn.

## ws580i result (Dino, 8 Nov 21:00; `manifest_ws580i_full.json`)

ws580i was run with K set from the measured cirque rate and a balance ratio of 1.56. Lines 5 to 10 pass. Line 4 fails: the main summit ends at 942 m, 499 m below its landform. The time line shows where the loss comes from:

- **41 kyr world.** The summit holds within 25 m of the landform until cycle 33 (1,425 m), then falls to 1,383 m by cycle 39.
- **100 kyr world.** It loses 441 m in 10 cycles, about 1 mm a year while active.

The estimate in the uplift note (about 145 m) was wrong. It carried E's 41 kyr rate into the 100 kyr world, where the ice is twice as large (56.7 km² at most).

## The cause: all active ice at the stadial line

Rule 6's history puts all 40 kyr of active ice in each 100 kyr cycle at the stadial line (487 m), the coldest stage. It puts all 16.4 kyr in each 41 kyr cycle at 637 m. The measured climate record says otherwise.

- **What the LR04 stack shows.** LR04 is the global benthic oxygen isotope stack (Lisiecki and Raymo 2005, `tools/watershed/data/lr04_stack.csv`). Scaled linearly, it puts the snowline at today's line (1,500 m, design A4's 1,450 to 1,550 m) at the Holocene mean and at the stadial line at the LGM mean.
  - In the last 1 Myr the line stood at or below 550 m for only 40 kyr, not 400 kyr. Its mean while the summit held ice was 955 m.
  - From 2.6 to 1.0 Ma the line never fell below 727 m, and its mean was 1,208 m.
- **This matches Porter.** Porter (1989, Quaternary Research 32:245) finds that most of Quaternary time had intermediate conditions, with snowlines about 500 m below today's. The design cited him for the active share but applied the full stadial depression to all of it.
- **It also matches the measured buzzsaw.** Against a mean line of 955 m, the 1,441 m summit stands about 490 m above. That is inside the about 600 m that measured summits rise above their cirque floors (Mitchell and Montgomery 2006). Against 487 m it stood 950 m above, and the ice took it down.

So the uplift note's question falls away if this is the cause: the ice was too large for too long, and the summit did not lack uplift.

`tools/watershed/lr04_history.py` writes the snowline history from the stack into `glacial.history`, in glacial.py's own format, with no change to glacial.py. It cuts the time into steps of glacial.dt and joins runs that stay within 100 m into one entry. Time with the line at or above today's is river time. A new setting, `glacial.today_ela_m` (1,500 m), sets the warm end of the scale.

## Probe L (Dino, about 15 minutes)

Probe L starts from ws580i's `glacial_cycle_39.npz` (the end of the 41 kyr world). It runs the last 240 kyr of the LR04 history: MIS 7 to today, two full 100 kyr cycles with the LGM and MIS 6, 43 entries and 226 kyr of ice. Params are `/mnt/project-files/water/ws580i_probe_params_L.json`, ws580i's settings plus that history.

**Decision.** The baseline is ws580i's cycles 40 and 41, where the main summit lost 65.3 m (1,383.4 to 1,318.1 m). If L's main summit loses at most a fifth of that (13 m), the full LR04 history run from B1 is worth its time, about 2 hours: 1,243 cold steps against ws580i's 520. Rule 6's lines 4 to 12 are then judged as written. If L loses more, the history is not the main cause, and the uplift note's options come back.
