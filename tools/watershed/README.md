# tools/watershed: the island's terrain and water, made together

The design is `docs/water/watershed_rebuild_design.md`. Dave's `docs/water/Dynasty_How_Natural_Watersheds_Work.md` governs it.

Everything here runs offline on Dave's PC (Dino), never in the cloud. Each stage writes its outputs, plus a manifest that holds the parameters and the input hashes, so a run can be reproduced.

| step | script | writes |
|---|---|---|
| R1, stage A (inputs) | `inputs.py` | `inputs.npz`, `inputs.png`, `inputs_manifest.json` |
| R2, stage B (landscape evolution) | to come | |
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
- the uplift is highest under the mountains, zero at sea, and varies at hill scale;
- the rain is heavier on windward slopes, with a rain shadow behind the high ground;
- the rock map shows the provinces, with soluble rock outlined.
