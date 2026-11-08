# Rule 6 build plan: pyramid peaks (valley heads and the glacial cycles)

Sonny, 8 Nov 2026. This is the build note for design A1 rule 6 in `docs/water/watershed_rebuild_design.md`. It says which lines change in which files, the settings and their sources, how the run is made on Dave's PC, and the lines that judge it.

Build it only after the ws580g pictures pass `ws580f_signoff.md`. Nothing here is run in the cloud. Locally only `py_compile`, `pyflakes`, `check_doc_links.py` and the GDScript parse and lint run.

## Why

On ws580f every number held: the summit kept 1,438 m through the ice. But the top is a granite dome about 2 km across, at 10 to 20 degrees, with corries only at its edge. The landform gives water and snow no place to gather near the top, and one cold stage of 100 kyr cannot cut back into it.

Real horns form where three or more cirques cut back into one peak. The cirques start in valley heads that the rivers made before the ice (Benn and Evans 2010, *Glaciers and Glaciation*). They then take many glacial cycles.

## The measured numbers this uses

These come from Jamie's cirque page, #654 (head 128076b2), as relayed on 8 Nov.

- **Long-term headwall retreat.** 0.1 to 1.3 mm/yr: Ben Ohau 0.44, Canadian Rockies 1.2 to 1.3, Kråkenes 0.1. The bursts of 2 to 10 mm/yr just after the ice goes are not long-term.
- **While a glacier is active.** 0.5 to 1.0 mm/yr, with 0.7 in the middle. Lochnagar granite is about 1 mm/yr while active, and needs about 400 kyr of active ice over many cycles.
- **Averaged over whole cycles.** 0.1 to 0.15 mm/yr. A granite plateau lowers only 0.16 m per 100 kyr.
- **Depth.** A cirque gets most of its depth (150 to 200 m) in its first cycle, then deepens about 10 times slower.
- **Ice sheets.** Cirques do not grow under ice sheets.
- **Per cycle.** At about 40 kyr of active ice per 100 kyr cycle, a headwall retreats 20 to 40 m.
  - A small horn takes 5 to 10 cycles.
  - Arran or Cuillin scale takes 12 to 25.
  - Matterhorn scale takes 25 to 50.
- **The record since 1 Ma.** It holds only 7 to 12 cycles of 100 kyr, so horns on the Matterhorn scale need the earlier 41 kyr cycles too.
- **Aspect.** North- to east-facing sides retreat 1.5 to 2 times faster.

Jamie suggested 10 cycles for an honest record since 1 Ma, or 20 or more for colossal peaks. Dave's D-10 asks for colossal peaks on the starter island, so this plan runs the whole Pleistocene: the 41 kyr world and then the 100 kyr world.

That gives about 26 cycles' worth of active ice (100 kyr cycle equivalents). This is honest history rather than a count picked for the look. The climate history is the same for every island. Each island's peaks then differ by their landform, rock and snowline.

## Change 1: valley heads in the landform export

This goes on the #580 branch (`sonny-landform-standing`), in `src/worldgen/tile/tile_height.gd` `_add_summits()` and `worlds/base_world/plan/tile_rules.json` `summit`.

It applies only when `landform_only` is set: the watershed model's input, set only by `tile_baker.bake(..., raw_only, landform_only)` for the export. The live game's terrain is unchanged, so there is no TERRAIN_VERSION bump. The live game moves to the record at R6 and R7 anyway.

New settings in `tile_rules.json` `summit` (both judged, checked below):

- `"head_depth_share": 0.4`. At its deepest, the valley head lies 0.4 times the tent's rise below the ground beside it. On the starter summit that is 0.4 × 232 m, or 93 m.
- `"head_peak_share": 0.35`. The head is deepest at 0.35 of the tent's reach from the top. On the starter summit that is about 325 m.

The code, inside the loop over samples (`w` replaces the second call to `spur_weight_at`):

```gdscript
	var head_share: float = float(rules.get("head_depth_share", 0.0)) if landform_only else 0.0
	var head_shape: float = log(0.5) / log(float(rules.get("head_peak_share", 0.35)))
	...
		var heads: bool = spurs and head_share > 0.0     # a summit with no spurs gets no heads (else a ring moat)
	...
				var w: float = _elevation.spur_weight_at(summit, offset * spacing_m) if spurs else 0.0
				var here: float = reach * (1.0 + spur_reach * w)
				var k: int = j * samples + i

				if distance < here:
					heights[k] += rise * pow(1.0 - distance / here, power)

				if heads and distance < reach:
					var u: float = pow(distance / reach, head_shape)    # u = 0.5 where distance = head_peak_share x reach
					heights[k] -= head_share * rise * (1.0 - w) * pow(sin(PI * u), 2.0)
```

Why this shape:

- The hollow is 0 at the summit and at the tent's foot. Near the point every direction lies on a spur (w is about 1), so the top stays round, and the summit, spur crests and massif edge keep their heights (D-10).
- Between 3 and 5 spurs it makes 3 to 5 valley heads converging on the top: places where water gathers and snow drifts, where rivers and then ice can start cutting. Cirques form in such pre-glacial valley heads.
- It is a function of world position only, so tiles agree on shared edges.

**Drainage condition.** The hollow must not make pits. Its outward rise is steepest at about 2.4 × head_depth_share × rise / reach: 0.24 on the starter summit. The ground there falls at about 0.5 (the tent plus the 18-degree summit cone), so the head drains outward. The landform check below counts any new pits.

## Change 2: the glacial cycles

This goes on R2b (`sonny-watershed-r2b-glacial`, #556) in `tools/watershed/glacial.py` and `params.json` `glacial`, then is merged forward.

### Settings

New keys in `params.json` `glacial`:

```json
"history": [
  {"era": "41 kyr world, 2.6 to 1.0 Ma", "cycles": 39, "period_years": 41000, "active_years": 16400,
   "interglacial_years": 4800, "ela_offset_m": 150},
  {"era": "100 kyr world, since about 1.0 Ma", "cycles": 10, "period_years": 100000, "active_years": 40000,
   "interglacial_years": 11700, "ela_offset_m": 0}
],
"aspect_ela_m": 75,
"aspect_smoothing_m": 240,
"aspect_full_slope_deg": 30,
"snapshot_after_cycles": [1, 3, 10, 20, 39, 44, 49]
```

Where the values come from:

- **100 kyr world.** 10 cycles (#654: 7 to 12 since 1 Ma), with 40 kyr of active ice each (#654). Its interglacial is today's climate for the Holocene's 11,700 years, so the last cycle ends today, as the old post-glacial era did.
- **41 kyr world.** 39 cycles, from the length of the era (2.6 to 1.0 Ma is about 1.6 Myr, over 41 kyr each).
- **The 41 kyr world's other values** (#654 lessons 7 and 8, head 128076b2):
  - **Active share: 40%.** Judged range 35 to 50%. Early cycles were symmetric, with smaller ice volumes (Lisiecki and Raymo 2007). For most of Quaternary time conditions were intermediate, with a mountain snowline about 500 m below today's, and cirques follow those average conditions (Porter 1989). Norway had mountain glaciers for about 46% of the last 2.6 Myr, the high-latitude top.
  - **Interglacial: 4.8 kyr**, scaled from the Holocene by period. Judged range 4 to 8 kyr. Interglacials before the transition held less CO2, so they took no longer a share than today's.
  - **Snowline: 150 m higher** than in the 100 kyr world. Judged range +100 to +200 m. The glacials were mild, but cirque glaciers follow the average conditions, not the peaks.
- **Aspect.** The snowline lies 113 to 220 m lower on north-facing than south-facing sides:
  - Făgăraş: 113 m;
  - Kamchatka cirques: 163 m, and its modern glaciers 190 m;
  - south-west British Columbia: 194 and 220 m (Evans 2006).
  These are via Barr and Spagnolo 2015 (#654). A difference of 150 m gives `aspect_ela_m` 75, which is half of it.
  - `aspect_smoothing_m` is judged: the aspect is that of a valley head, not of one cell.
  - The measured NE/SW retreat ratio (1.5 to 2) and floor difference (NE cirque floors 100 to 200 m below SW ones) are checks reported after the run, not tuned in.
- **What the history adds up to.** Total active ice is 39 × 16.4 + 10 × 40, or about 1.04 Myr. At 0.5 to 1.0 mm/yr that is 0.5 to 1.0 km of headwall retreat, which is the Arran-to-Matterhorn range.
- **Backward compatible.** With no `history` and `aspect_ela_m` 0, glacial.py runs exactly as today: one stage of `years`, then `post_glacial_years`. Old manifests reproduce.

### Code

1. **Split the stage into functions.** The body of today's cold-step loop moves unchanged into `_cold_phase(state, years, ela_local)`. `state` holds `h`, `deposit`, `ice`, `ice_max`, `flux_max` and `ery_fn`. It also keeps `ice_cycle_max`, reset at each phase's start. The post-glacial loop becomes `_river_phase(state, years)`. Each phase takes steps = max(round(years / dt), 1) at dt = years / steps (`dt` for the cold phase, `post_glacial_dt` for the river phase), so it covers exactly its years.

2. **The cycle loop.** It replaces the single cold stage and the post-glacial era. The landform comes from `inputs.npz` (`data['landform']`), with `tops = peaks.summits(...)` and `axes = peaks.axes(...)` found once at the start:

```python
history = GL.get('history') or [dict(era='one cold stage', cycles=1, active_years=GL['years'],
                                     interglacial_years=GL['post_glacial_years'], ela_offset_m=0.0,
                                     period_years=GL['years'] + GL['post_glacial_years'])]
k = 0
for e, era in enumerate(history):
    for c in range(int(era['cycles'])):
        k += 1
        ela_local = He + float(era['ela_offset_m']) - _aspect_shift(state['h'], GL, n, dx)
        _cold_phase(state, float(era['active_years']), ela_local)
        if e == len(history) - 1 and c == int(era['cycles']) - 1:
            cold_ground, cold_deposit = state['h'].copy(), state['deposit'].copy()
        _river_phase(state, float(era['interglacial_years']))
        idle = float(era['period_years']) - float(era['active_years']) - float(era['interglacial_years'])
        state['h'] += U * idle          # full-glacial ice-sheet cover and frozen dry time: not modelled (cirques do not grow under ice sheets)
        cycles.append(dict(cycle=k, era=era['era'], shape=peaks.shapes(state['h'], landform, sea, dx, tops, axes)))
        if k in GL.get('snapshot_after_cycles', []):
            np.savez_compressed(f'{out_dir}/glacial_cycle_{k:02d}.npz', ground=R(state['h']), ice_max_m=R(state['ice_cycle_max']))
```

3. **The aspect shift.** It is computed once per cold phase, from the ground at the phase's start (cheap: one blur):

```python
def _aspect_shift(h, GL, n, dx):
    a = float(GL.get('aspect_ela_m', 0.0))
    if a == 0.0:
        return 0.0
    from scipy.ndimage import gaussian_filter
    sm = gaussian_filter(h.reshape(n, n), float(GL['aspect_smoothing_m']) / dx)
    gz, gx = np.gradient(sm, dx)                          # rows run +z (south), columns +x (east); north is -z
    g = np.maximum(np.hypot(gx, gz), 1e-9)
    ne = (-gx / g + gz / g) / np.sqrt(2.0)                # +1 where the slope faces north-east, -1 south-west
    steep = np.clip(np.degrees(np.arctan(g)) / float(GL['aspect_full_slope_deg']), 0.0, 1.0)
    return (a * ne * steep).ravel()                       # metres the snowline lies lower there
```

   In `_cold_phase` the mass balance becomes `frac = np.minimum((surf - ela_local) / (Hf - He), 1.0)`. The gradient `full_ice_above_ela_m` is unchanged.

4. **The ice's own cut.** A new field `ice_cut_m` is summed over the cold phases only: the net change in each cold step, less uplift. The hollow cause "ice-scoured floor" uses it instead of `glacial_cut_m`, which now also holds the interglacial rivers' work. Both are saved in glacial.npz.

5. **The bound check** uses the whole history's years: `b1 max + U.max × sum of period_years + 100`.

6. **The manifest summary** gains:
   - `history`, the eras as run;
   - `active_ice_years`;
   - `cycles`, the peak shapes after every cycle (small: a few numbers per summit);
   - `peaks`, the final checks below.

### Cost on Dave's PC

ws580f's cold stage ran at about 6.5 s a step on the starter window.

- 41 kyr world: 39 cycles × (8 cold + 2 interglacial steps) = 390 steps.
- 100 kyr world: 10 cycles × (20 + 6) = 260 steps.
- Total: 650 steps, about 70 minutes. B1 is unchanged (about 20 to 25 minutes).

The seven snapshots hold only the ground and that cycle's ice. The cycle shapes in the manifest show the retreat after every cycle without a picture.

## Change 3: the peak checks

This goes on R2b (#556) as a new `tools/watershed/peaks.py`, which reads the run's saved files, so it changes no other stage:

- `python tools/watershed/peaks.py landform INPUTS_DIR [BASELINE_INPUTS_DIR]` checks lines 1 to 3 on `inputs.npz`;
- `python tools/watershed/peaks.py glacial INPUTS_DIR GLACIAL_DIR` checks lines 4 to 10 on `glacial.npz`, with the cycles from the manifest or the snapshots;
- `glacial.py` calls its `shapes()` after every cycle once change 2 is built.

Its settings are in `params.json` `peaks`. Its unit tests, `test_peaks.py`, use small synthetic peaks.

- **`summits(landform, sea, dx, min_m)`.** The landform's peaks, as evolve.py already finds them: the highest point within 1 km. Only those at least 300 m above the stadial snowline count (487 + 300 = 787 m on the starter island), because lower tops hold no cirque glacier. On the starter island that is the 1,438 m summit and the 1,018 m second massif.
- **`axes(landform, tops)`.** The valley-head bearings, read from the landform itself: the heads on whichever ring (300 to 1,000 m) shows the most, nearest first. If no ring shows a head, the minima of the 500 m ring are used.
- **`shapes(ground, landform, sea, dx, tops, axes)`.** For each summit, on a 2.5 km window round it:
  - `top_m`, and `top_change_m` against the landform (the highest ground within 200 m, as evolve.py measures);
  - `heads`: on rings at 300, 500, 700 and 1,000 m, the ring minima at least 50 m below the highest ring ground on either side before the next minimum, by bearing and depth;
  - `plateau_m`: the widest flat cap. Cells within 100 m of the top, under 20 degrees and joined to the top; its size is the diameter of a circle of the same area;
  - `slope_300m_deg`: the mean slope within 300 m of the top;
  - `headwalls`: along each valley-head axis, these values:
    - the distance from the top to the first point steeper than 40 degrees (the headwall's upper edge);
    - the cirque's depth (that edge's height less the lowest ground on the axis within 600 m beyond it);
    - the facing (NE quadrant, SW quadrant or other).
  - `retreat`: from the cycles, each headwall's retreat in metres per cycle and in mm per active year, from the cycle it first stands. Also the NE/SW ratio of the mean rates, and the cirque depth after the first three cycles against its later growth.

## Sign-off lines for the run (ws580h, after ws580g)

These lines are judged as written. Failing lines are relayed word for word, with no reruns on changed settings.

**Landform (inputs.py summary `peaks`):**
1. Every checked summit has at least 3 valley heads within 1 km, each at least 50 m below the ridges either side.
2. The landform's closed hollows are not more than ws580g's, so the heads make no pits.
3. The summit heights are unchanged from ws580g (within 1 m).

**After the ice (glacial.py summary `peaks`):**

4. Each checked summit is within 25 m of its landform height (D-10).
   - If one is lower, the report names the headwalls that met at its top and their cirque floor heights. That is the cause, and the cause is fixed, not guarded.
5. At least 3 valley heads still stand within 1 km, each at least 50 m below the ridges either side.
6. `slope_300m_deg` is steeper than on the landform.
7. `plateau_m` is under 300 m.
8. Headwall retreat lies within the measured long-term 0.1 to 1.3 mm/yr of active ice. 0.5 to 1.0 is the middle; outside that is noted, not failed.
9. North-east headwalls retreat 1.5 to 2 times faster than south-west ones (noted with the measured ratio; fails only if under 1.2 or over 3). North-east cirque floors lie 100 to 200 m below south-west ones (noted).
10. Cirques get most of their depth early: the rate after cycle 3 is at most a fifth of that in the first three cycles.

**Glacial zooms (Dino, at 54800 71424 and 66960 79296, from the final ground and the cycle 20 and 39 snapshots):**

11. Cirques sit at the valley heads, with arêtes between them and a pyramid top.
12. No ring cliff, no star of straight rays, no even wall ribbon round the top beyond the open 57-degree item below.

## Not changed, and still open

- Rule 1 still holds every slope at or under its rock's standing angle (granite 57 degrees), under the ice too. A horn's faces are that angle, so their height above the cirque floors sets how tall a horn can stand. If the summit cannot stand above its cirque floors at 57 degrees, line 4 fails with the cause.
- Full-glacial ice-sheet phases are not modelled: they protect summits under cold-based ice and deepen the troughs. Their time passes with only uplift.
- The even 57-degree ribbon stays open. It needs a threshold that varies with the rock mass (joint spacing from the faults), once the geology export carries faults.
- B1's snapshot (t100k) is kept. The interglacials add about 300 kyr of river time. If drainage density then runs well past ws580g's, the B1 snapshot is chosen again on the same check, earlier rather than later.
