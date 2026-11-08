# tools/watershed: the island's terrain and water, made together

The design is `docs/water/watershed_rebuild_design.md`. Dave's `docs/water/Dynasty_How_Natural_Watersheds_Work.md` governs it.

Everything here runs offline on Dave's PC (Dino), never in the cloud. Each stage writes its outputs, plus a manifest that holds the parameters and the input hashes, so a run can be reproduced.

| step | script | writes |
|---|---|---|
| R1, stage A (inputs) | `inputs.py` | `inputs.npz`, `inputs.png`, `inputs_manifest.json` |
| R2, stage B (landscape evolution) | `evolve.py` | `ground.npz`, `evolve.png`, `evolve_manifest.json` |
| R3 to R5, stage C (hydrology) | to come | |
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
