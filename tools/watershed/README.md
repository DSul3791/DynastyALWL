# tools/watershed: the island's terrain and water, made together

The design is `docs/water/watershed_rebuild_design.md`. Dave's `docs/water/Dynasty_How_Natural_Watersheds_Work.md` governs it.

Everything here runs offline on Dave's PC (Dino), never in the cloud. Each stage writes its outputs, plus a manifest that holds the parameters and the input hashes, so a run can be reproduced.

| step | script | writes |
|---|---|---|
| R1, stage A (inputs) | `inputs.py` | `inputs.npz`, `inputs.png`, `inputs_manifest.json` |
| R2, stage B (landscape evolution) | `evolve.py` | `ground.npz`, `evolve.png`, `evolve_manifest.json` |
| R2b, stage B2 (glacial history, then post-glacial) | `glacial.py` | `glacial.npz`, `glacial.png`, `glacial_manifest.json` |
| R3, stage C1 and C2 (basins, lakes by water balance) | `lakes.py` | `lakes.npz`, `lakes.json`, `lakes.png`, `lakes_manifest.json` |
| R4, stage C3, C4 and C6 (water table, heads, wetlands) | `groundwater.py` | `groundwater.npz`, `groundwater.png`, `groundwater_manifest.json` |
| R6, stage D (the island water record) | `record.py` | `record/manifest.json`, `record/climate.json`, `record/network.json`, `record/tiles/X_Z/*` |
| R5, stage C5, C7 and C8 | to come | |
| R6, stage D (island water record) | to come | |

## R1: inputs

1. **Landform** (stage A1): the world's shape, with no valleys cut around the old world rivers, no detail noise and no strata.
   `godot --headless --path . --script res://src/worldgen/tools/export_raw_heights.gd -- --landform --out=LANDFORM_DIR`
2. **Rock** (stage A3) on the model grid (16 m):
   `godot --headless --path . --script res://src/worldgen/tools/export_geology.gd -- --step=16 --out=GEOLOGY_DIR`
3. **Inputs**: uplift (stage A2) and rain (stage A4, Smith and Barstad 2004 linear orographic rain, wind from the landform manifest):
   `python tools/watershed/inputs.py LANDFORM_DIR GEOLOGY_DIR OUT_DIR`
   It needs numpy, scipy, numba (for the rock rule shared with `tools/erosion_precarve/rock.py`) and matplotlib.

Check `inputs.png` against these:
- the landform has the island's shape and massifs, but no valleys yet;
- the uplift is highest under the mountains, zero at sea, and smooth: no blobs or other pattern at hill scale;
- the rain is heavier on windward slopes, with a rain shadow behind the high ground, and its peak is near the calibration peak in params.json (about 4,100 mm/yr), not several times it;
- the rock map shows the provinces, with soluble rock (limestone, marble, chalk) outlined.

## R2: landscape evolution (the final ground)

`python tools/watershed/evolve.py INPUTS_DIR GEOLOGY_DIR OUT_DIR`, where INPUTS_DIR is R1's output and GEOLOGY_DIR is the same 16 m geology export.

The run starts from the landform and uses:
- the uplift (stage A2), the rock (A3) and the rain (A4);
- stream power with deposition, solved implicitly;
- the quick runoff of the one water budget (`runoff.py`: rain minus evaporation, times the rock's quick share), so chalk, limestone and dry slopes cut less;
- channels that begin by the slope-area rule (steeper and wetter hollows need less water; `channel_head`, from measured source areas, with at least `min_area_m2` of drainage) and then run on downstream;
- loose cover over the rock: a river cuts through the cover at the cover's rate and the rest of the step at the rock's rate, so a thin cover never lets hard rock wear like soft;
- an incision threshold: bedrock channels cut only where Q^m S passes `incision_threshold_m` (none in loose cover);
- threshold hillslopes: no cell stands steeper than its threshold above its receiver or any other ground (the limit is a true round cone within each rock, carried from cell to cell each step, so a wall beside a slot comes down along its whole height and faces are not cut into eight-sided facets), set by rock (`threshold_slope_deg_by_rock`: hard rock holds steeper walls) and `threshold_slope_deg` under loose cover; landslide debris joins the sediment;
- flow paths that follow the true downhill direction (`flow_paths`, D8-LTD): one receiver per cell, chosen between the two neighbours beside the steepest facet so the path's sideways drift stays small, so smooth faces are not combed along the compass;
- a rough start (`start_roughness`): the landform plus roughness with the spectrum of real ground (mean slope 0.1, 48 m to 1.5 km), so flow lines find each other and valleys branch instead of combing the flanks in parallel lines; the summary's `start_roughness` gives its size;
- soil creep.

It writes:
- the final ground;
- quick-runoff area, drainage area, receivers and the channel map;
- the water budget fields (evaporation, quick runoff, recharge) for R3 and R4;
- the hollows left (pit depth);
- the sediment thickness (floodplains, fans, deltas);
- a picture and a manifest.

With `uplift_share` 0 (the default since 8 Nov) the run dissects the landform as it stands, with no uplift, and writes a snapshot at each of `snapshot_years` to `OUT_DIR/t<kyr>k` (each with its own ground.npz, summary and picture), so the run length can be chosen from one run. The final ground is in OUT_DIR itself.

To calibrate the uplift from a finished run (only for runs with uplift), add `--calibrate=PREV_RUN_DIR`: the uplift is scaled by the landform over that run's ground, both smoothed at `uplift.smooth_m`, so the massifs end at the landform's heights. The summary then reports `uplift_calibration` and `massif_scale_height_mismatch_m` (near 0 is right).

`python tools/watershed/plots.py ground RUN_DIR` redraws `evolve.png` from a saved run in seconds. RUN_DIR is the run's output folder, the one holding `ground.npz`. `python tools/watershed/plots.py zoom RUN_DIR X Z [SIZE_M]` draws a close look at full resolution (`zoom_X_Z.png`, a 6 km square by default, world metres), to tell branching valleys from straight parallel gullies.

Check `evolve.png` and the summary for:
- branching valleys everywhere, with hills between them;
- sediment on the valley floors and at the coast;
- few closed hollows: a long river era fills them, and lakes come from named causes in R2b and R3, not from leftovers. The summary's `hollows` says whether each is held by a sediment sill (a fan or floodplain laid across a valley, a real cause) or by rock, and lists the ten deepest in world metres; the picture marks them red;
- a drainage density near measured ones (`drainage_density_km_per_km2`; Tennessee Valley, at 760 mm of rain, is 7.3 km/km²), higher on wet steep ground and low on chalk, and no rock where nearly every cell is a channel;
- hard rock wearing least: in `cut_by_start_rock_m`, granite and basalt show the smallest mean and 99th-percentile cut, and soft rock (shale, chalk, tuff) the largest;
- no slopes above the threshold angle (`max_slope_deg`, `share_of_land_steeper_than_deg`), and `share_of_land_near_threshold` small: a large share would mean the uplift is too fast for the rock, so landslides, not rivers, set the form;
- a summit near the landform's and tall peaks kept: `land_height_percentiles_m` close to `landform_height_percentiles_m` at 99 and 99.9, and `local_relief_2km_on_high_ground_m` above the landform's (valleys cut deep between the peaks); with uplift, `last_tenth_summit_change_m_per_kyr` near zero (steady state);
- fewer channels (lower drainage density in the summary) on chalk and on the dry lee slopes than on the wet west flanks.

## R2b: glacial history (stage B2)

`python tools/watershed/glacial.py INPUTS_DIR GEOLOGY_DIR B1_DIR OUT_DIR`, where B1_DIR is the R2 output folder (the one holding `ground.npz`). It starts from the river era's final ground, so the ice settings can be changed and rerun without rerunning R2. Point B1_DIR at the chosen snapshot (for example `ground_<sha>\t1000k`) to glaciate the ground at that run length. The slope limit by rock and the uplift are B1's.

The glacial history (`params.json` `glacial`), with the glacial stream-power model of Hergarten (2021) in each cold phase:
- ice made above the snowline (`ela_m`) from the same rain field, and melted below it;
- the ice flux accumulated down the ice surface, spread over each glacier's width (the swath), and a finite ice thickness;
- erosion and deposition with the same implicit solve as R2, so moraines, till and outwash come from the sediment budget;
- frozen ground, so all runoff is quick;
- then an interglacial of today's rivers and creep.

`glacial.history` (design A1 rule 6, `docs/water/rule6_build_plan.md`) runs the whole Pleistocene as cycles of a cold phase and an interglacial: 39 cycles of the 41 kyr world (snowline 150 m higher), then 10 of the 100 kyr world, the last interglacial the Holocene's 11,700 years. The snowline lies `aspect_ela_m` lower on steep ground facing the shady lee quarter (`shady_bearing_deg`, SE on the starter island) and as much higher facing the sunny one. After every cycle the peak shapes go into the manifest's `summary.cycles`; `summary.peaks` holds the rule 6 lines 4 to 10; `snapshot_after_cycles` saves `glacial_cycle_NN.npz` (ground and that cycle's ice), which `python tools/watershed/plots.py zoom RUN_DIR/glacial_cycle_NN.npz X Z` draws beside the river-era ground. `ice_cut_m` is the ice's own cut (cold phases only); `glacial_cut_m` also holds the rivers' work between. About 650 steps, some 70 minutes on Dave's PC. With no `history` it is one cold stage of `years`, then `post_glacial_years`, as before.

`python tools/watershed/plots.py glacial RUN_DIR` redraws `glacial.png`. `python tools/watershed/glacial.py report GEOLOGY_DIR RUN_DIR` reads a saved run in seconds and writes `glacial_report.json`: where the ice cut most and into what rock, and where the ground is steepest (the same report is in the manifest's summary under `where`).

Check `glacial.png` and the summary for:
- ice on the high ground only, thickest in the big valley heads, with tongues down the main valleys (`ice_max_km2`, `ice_thickest_m`, `lowest_ice_m`);
- U-shaped troughs where the ice was, and V-shaped valleys left where it was not;
- tributary valleys hanging above the troughs they join;
- hollows with a cause (`hollows.by_cause`): ice-scoured floors high up (cirques) and in troughs (rock basins), and glacial deposit sills near where the ice ended (moraine dams). Many hollows with no cause would mean a numerical leftover, not a lake;
- till under the ice's reach and outwash beyond it;
- for one cold stage, trough floors cut 100 to 300 m below the river-era valley floors (`where.cut_under_ice_m`, p90 and p99, the ice's own cut), not thousands; the whole history cuts deeper. The single deepest cell (`glacial_cut_max_m`, listed in `where.deepest_cut`) can be a truncated spur or a cirque cut back into a steep flank, and may be twice that. If the cut is far off, `years` is the setting to change first;
- no cliffs the slope cap should have stopped: `where.neighbour_drop_steepest` above 48 degrees (granite's cap) away from the coast and from hollows is a fault. The summary's `max_slope_deg` is the plain gradient, which also spans the sea floor, so a shore cell beside deep water reads as a cliff; `where.slope_shore_max_deg` counts the sea at sea level.

## R3: basins and lakes (stage C1 and C2)

`python tools/watershed/lakes.py INPUTS_DIR GEOLOGY_DIR B2_DIR OUT_DIR`, where B2_DIR is the R2b output folder (the one holding `glacial.npz`).

1. Hollows with no cause are filled: they are numerical leftovers, not lakes. The deepest are listed so a missing cause shows.
2. The depression tree (Barnes et al. 2020): each hollow, which hollows merge at which saddle, and where each spills.
3. Fill, spill and merge (Barnes et al. 2021): each hollow gets its catchment's runoff from the one water budget (karst recharge leaves through the caves) and loses open-water evaporation and floor seepage. Full ones spill over their lowest saddle into the next hollow or down to the sea; the rest stand at their balance level as closed lakes, each with its reason.
4. Each lake's cause: cirque, glacial rock basin, moraine or till dam, fan or delta dam.
5. Basins: every cell's outlet to the sea.

`python tools/watershed/plots.py lakes RUN_DIR` redraws `lakes.png`.

Check `lakes.png`, `lakes.json` and the summary for:
- every lake with a cause (`unexplained_lakes` 0);
- tarns in cirques high up, rock-basin lakes in the troughs, moraine-dammed lakes where the ice ended;
- closed lakes rare, each on leaky rock or with a tiny catchment (`closed_lakes`); in this wet climate almost every lake should spill;
- each outflow going on to the sea or a lower lake (`spills_to`), and `overflow_lost_m3_s` 0;
- the filled leftovers shallow (a few decimetres); a deep one marks a cause the model lacks;
- basins of many sizes, not one per valley of equal size.

## R4: water table, heads and wetlands (stages C3, C4 and C6)

`python tools/watershed/groundwater.py INPUTS_DIR GEOLOGY_DIR B2_DIR R3_DIR OUT_DIR`, where B2_DIR holds `glacial.npz` and R3_DIR holds `lakes.npz`.

- The water table: steady groundwater flow on a 64 m grid from the recharge of the one water budget. Conductivity comes from the rock (Gleeson et al. 2011 classes), with loose cover over it and conduits in cave-forming rock. The sea and the lakes hold their levels, and the ground is a ceiling, so groundwater comes out where the table meets it (springs, seeps, gaining reaches).
- At 16 m: depth to the table, groundwater discharge, baseflow down the routing, and a first regime (perennial, intermittent, ephemeral).
- Heads labelled by what feeds them: spring, seep or damp hollow, lake outlet, wetland outlet, seasonal rill.
- Wetlands typed by what wets them: salt marsh, fen (groundwater), marsh and swamp (river or lake), bog (rain).

`python tools/watershed/plots.py groundwater RUN_DIR` redraws `groundwater.png`.

Check `groundwater.png` and the summary for:
- `balance_m3_s.closure` near 0: recharge comes out at the land surface, into lakes or into the sea;
- a deep table under ridges and permeable rock, a shallow one in valley floors and on tight rock;
- perennial channels fed by baseflow; seasonal ones on chalk and in small catchments (chalk dry valleys);
- most heads seeps and damp hollows, a few springs, and those mostly where permeable rock meets tight rock or at the foot of karst;
- wetlands only on low ground and gentle slopes (`wetland_on_steep_ground_cells` 0): fens where groundwater comes out, bogs on wet, tight uplands, marsh and swamp along rivers and lakes, salt marsh at the coast;
- the largest springs (`springs_largest`): the ones on or beside cave-forming rock are the cave-spring candidates for R5.

## R6: the island water record (stage D)

`python tools/watershed/record.py INPUTS_DIR B2_DIR R3_DIR R4_DIR OUT_DIR [--network=R5_DIR]`, where the four folders are one run's chain: each stage's manifest must name the very files given, or the writer stops.

- It refuses a window with land on its frame, so no river or groundwater divide is cut by the edge.
- The 8 m ground is R3's 16 m ground refined by a separable monotone cubic (it passes through every 16 m height and does not overshoot), plus fine roughness at 16 to 48 m on hillslopes only, continuing the B1 start spectrum. An epsilon-free priority flood then checks for closed cells: where the roughness made one, it is taken out round it, and any closed cell left is counted and listed (`closed_cells_outside_lakes`), never filled.
- Lakes take their R3 levels on the refined ground, so their shores follow the 8 m ground; the sea is at 0.
- Per tile (T + 1 samples at 8 m, shared edges, little-endian): `ground` and `water_level` (f4), `water_class`, `discharge` (log-coded u2), `regime`, `table_depth`, `basin`, `fresh_m`, `sediment_m`; the manifest lists each field's type and scale. `network.json` and `climate.json` are island-wide.
- Until R5 exists it writes no rivers as water and marks the record `complete: false`, which the bake must refuse.

Look for: `closed_cells_outside_lakes` near 0; `summit_8m` within a metre of `summit_16m`; a lake area close to R3's.
## Peak checks (design A1 rule 6)

`tools/watershed/peaks.py` judges whether the tall summits are pyramids rather than domes. It runs sign-off lines 1 to 10 of `docs/water/rule6_build_plan.md` on a run's saved files, in seconds:
- `python tools/watershed/peaks.py landform INPUTS_DIR [BASELINE_INPUTS_DIR]` checks lines 1 to 3 on the landform:
  - at least 3 valley heads round each summit within 1 km;
  - no new closed hollows near the summits;
  - summit heights unchanged against the baseline run.
  It writes `peaks_landform.json` and `.md`.
- `python tools/watershed/peaks.py glacial INPUTS_DIR GLACIAL_DIR` checks lines 4 to 10 after the ice:
  - the top within 25 m of the landform;
  - the valley heads kept;
  - steeper near the top;
  - no flat cap over 300 m;
  - the headwall retreat rate, the shady/sunny ratio (SE against NW on the starter island, from `glacial.shady_bearing_deg`) and the early cirque depth, read from the glacial cycles.
  It writes `peaks_glacial.json` and `.md`.

Each line reads PASS, FAIL or N/A with its numbers. A run of one cold stage has no cycles, so lines 8 to 10 read N/A. Settings are in `params.json` `peaks`. `python tools/watershed/test_peaks.py` runs its unit tests on small synthetic peaks (numpy and scipy only, a few seconds).
