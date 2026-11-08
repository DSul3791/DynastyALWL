# tools/watershed: the island's terrain and water, made together

The design is `docs/water/watershed_rebuild_design.md`. Dave's `docs/water/Dynasty_How_Natural_Watersheds_Work.md` governs it.

Everything here runs offline on Dave's PC (Dino), never in the cloud. Each stage writes its outputs, plus a manifest that holds the parameters and the input hashes, so a run can be reproduced.

| step | script | writes |
|---|---|---|
| R1, stage A (inputs) | `inputs.py` | `inputs.npz`, `inputs.png`, `inputs_manifest.json` |
| R2, stage B (landscape evolution) | `evolve.py` | `ground.npz`, `evolve.png`, `evolve_manifest.json` |
| R2b, stage B2 (glacial history, then post-glacial) | `glacial.py` | `glacial.npz`, `glacial.png`, `glacial_manifest.json` |
| R3, stage C1 and C2 (basins, lakes by water balance) | `lakes.py` | `lakes.npz`, `lakes.json`, `lakes.png`, `lakes_manifest.json` |
| R4 to R5, stage C3 to C8 | to come | |
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
- channels that begin by the slope-area rule (steeper hollows need less water) and then run on downstream;
- threshold hillslopes: no slope steeper than the threshold above its receiver, set by rock (`threshold_slope_deg_by_rock`: hard rock holds steeper walls) and `threshold_slope_deg` under loose cover; landslide debris joins the sediment;
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

`python tools/watershed/plots.py ground RUN_DIR` redraws `evolve.png` from a saved run in seconds. RUN_DIR is the run's output folder, the one holding `ground.npz`.

Check `evolve.png` and the summary for:
- branching valleys everywhere, with hills between them;
- sediment on the valley floors and at the coast;
- few closed hollows: a long river era fills them, and lakes come from named causes in R2b and R3, not from leftovers. The summary's `hollows` says whether each is held by a sediment sill (a fan or floodplain laid across a valley, a real cause) or by rock, and lists the ten deepest in world metres; the picture marks them red;
- no slopes above the threshold angle (`max_slope_deg`, `share_of_land_steeper_than_deg`), and `share_of_land_near_threshold` small: a large share would mean the uplift is too fast for the rock, so landslides, not rivers, set the form;
- a summit near the landform's and tall peaks kept: `land_height_percentiles_m` close to `landform_height_percentiles_m` at 99 and 99.9, and `local_relief_2km_on_high_ground_m` above the landform's (valleys cut deep between the peaks); with uplift, `last_tenth_summit_change_m_per_kyr` near zero (steady state);
- fewer channels (lower drainage density in the summary) on chalk and on the dry lee slopes than on the wet west flanks.

## R2b: glacial history (stage B2)

`python tools/watershed/glacial.py INPUTS_DIR GEOLOGY_DIR B1_DIR OUT_DIR`, where B1_DIR is the R2 output folder (the one holding `ground.npz`). It starts from the river era's final ground, so the ice settings can be changed and rerun without rerunning R2. Point B1_DIR at the chosen snapshot (for example `ground_<sha>\t1000k`) to glaciate the ground at that run length. The slope limit by rock and the uplift are B1's.

One cold stage (`params.json` `glacial`) with the glacial stream-power model of Hergarten (2021):
- ice made above the snowline (`ela_m`) from the same rain field, and melted below it;
- the ice flux accumulated down the ice surface, spread over each glacier's width (the swath), and a finite ice thickness;
- erosion and deposition with the same implicit solve as R2, so moraines, till and outwash come from the sediment budget;
- frozen ground, so all runoff is quick;
- then 11,700 years of today's rivers and creep.

`python tools/watershed/plots.py glacial RUN_DIR` redraws `glacial.png`.

Check `glacial.png` and the summary for:
- ice on the high ground only, thickest in the big valley heads, with tongues down the main valleys (`ice_max_km2`, `ice_thickest_m`, `lowest_ice_m`);
- U-shaped troughs where the ice was, and V-shaped valleys left where it was not;
- tributary valleys hanging above the troughs they join;
- hollows with a cause (`hollows.by_cause`): ice-scoured floors high up (cirques) and in troughs (rock basins), and glacial deposit sills near where the ice ended (moraine dams). Many hollows with no cause would mean a numerical leftover, not a lake;
- till under the ice's reach and outwash beyond it;
- trough floors cut 100 to 300 m below the river-era valley floors (`glacial_cut_max_m`), not thousands. If the cut is far off, `years` is the setting to change first.

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

