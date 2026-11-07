# Sullivan water

The project's new water systems, built on Dave's guide, `docs/water/Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md`. Dave made the guide the foundation on 7 Nov 2026. Where the old water plan or `docs/DYNASTY_WATER_DESIGN.md` disagrees with the guide, the guide wins. Owner: Sonny.

The layout follows the guide's section 2 (`core/`, `ocean/`, `freshwater/`, `render/`, `interaction/`), with one change: the code lives under `src/sullivan_water/` instead of `addons/sullivan_water/`. The reason is the test gate. Any change under `addons/**` also runs the slow world tests (`tools/test_lanes.json`, `slow_triggers`), and those would then run on Dave's PC for every water PR. The tests live in `src/worldgen/tools/test_sullivan_water_*.gd`, the place every project test lives.

This code runs beside `src/water2` (today's live water) until its gates pass. Nothing in the game calls it yet. That follows the guide, section 12: "build a separate demonstration scene before integrating".

## Milestones (guide section 13, numbered as in the guide)

| | Deliverable | Gate | State |
|---|---|---|---|
| M0 | `docs/water/runtime_inventory.md` | the PC probes P1 to P4 | written; probes NOT RUN |
| M1 | `freshwater/water_grid_2d.gd`, one closed conservative region | `test_sullivan_water_grid`: F01, F02, F03, F04, F05, F07 (open-air part), F09, F13, a 10k tick ledger, a stable pond | code written; test NOT RUN |
| M2 | ditch, dam, spillway and irrigation sandbox (a demo scene) | edit, bypass, overflow and withdrawal tests | next |
| M3 | terrain adapter on our `VoxelLodTerrain` and edit transaction (guide 17, 24, 25) | real digs change cells and crests without a reset | |
| M4 | chunk seams, sleep and wake, persisted boundary reservoirs (guide 26) | cross-region and unload/reload comparisons | |
| M5 | ocean baseline, one wave function for CPU and GPU (guide 6, 28) | height and normal cross-check (F10) | |
| M6 | river and ocean look (guide 5, 27) | shore, foam, refraction, underwater | |
| M7 | swimmers, boats, sources and sinks, river mouths (guide 7, 29) | movement and volume consistency | |
| M8 | save and load, optimisation | worst-case profiles | |

## Decisions recorded (guide 22: a departure needs a short record)

1. **Damping cap per face (M1).** The guide's orifice law, `Q = C·w·over·sqrt(2g|head|)`, has an infinite slope at zero head. At dt 0.1 s, near-level water would overshoot and swap sides every tick. So each face moves at most 0.2 of the volume that would level its two cells. That is below the 1/4 stability bound for a cell with four faces. It changes only how fast the last centimetres settle, never how much water there is. The algorithm (snapshot, candidates, scaling per cell, paired apply) is unchanged. If ponds settle too slowly in play, raise the share toward 0.25, never above it.
2. **Rounding guard.** After the paired apply, a donor can sit a few 1e-17 m³ under zero from float rounding. Those traces are set to zero and added to `rounding_m3` in the ledger. They are not hidden, so a real leak still shows as a residual.

## Dave's standing water rules this system must keep

- The simulation decides where water is. Players dig ditches and build dams, and the water must follow (guide 3.6, 3.7). Today's water ignores digs (`water_hub2.gd:102`).
- Riverbeds run through the lowest part of each valley, in a neat carved channel that holds the river (Dave, 6 Nov 2026). The baked rivers (`tile_valley_drain.gd`, `drainage_channels.gd`) feed the guide's section 4.3 ("procedural river creation before runtime flow").
- A river starts at a lake or head pond with a spring on flat ground, or at a cave with springs on a hillside. Caves appear only far inland.
- No area-specific code and no height patches. Only rules that hold across the whole world.
