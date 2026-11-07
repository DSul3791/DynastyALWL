# Sullivan water

The project's new water systems, built on Dave's guide, `docs/water/Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md`. Dave made the guide the foundation on 7 Nov 2026. Where the old water plan or `docs/DYNASTY_WATER_DESIGN.md` disagrees with the guide, the guide wins. Owner: Sonny.

The layout follows the guide's section 2 (`core/`, `ocean/`, `freshwater/`, `render/`, `interaction/`), with one change: the code lives under `src/sullivan_water/` instead of `addons/sullivan_water/`. The reason is the test gate. Any change under `addons/**` also runs the slow world tests (`tools/test_lanes.json`, `slow_triggers`), and those would then run on Dave's PC for every water PR. The tests live in `src/worldgen/tools/test_sullivan_water_*.gd`, the place every project test lives.

This code runs beside `src/water2` (today's live water) until its gates pass. Nothing in the game calls it yet. That follows the guide, section 12: "build a separate demonstration scene before integrating".

## Milestones (guide section 13, numbered as in the guide)

| | Deliverable | Gate | State |
|---|---|---|---|
| M0 | `docs/water/runtime_inventory.md` | the PC probes P1 to P4 | written; P1 and P2 PASS, P3 and P4 waiting for Dino |
| M1 | `freshwater/water_grid_2d.gd`, one closed conservative region | `test_sullivan_water_grid`: F01, F02, F03, F04, F05, F07 (open-air part), F09, F13, a 10k tick ledger, a stable pond | PASS on David4 headless, 611db289: 30 ok, 0 failures, ledger residual 1.9e-13 m³ over 10k ticks |
| M2 | ditch, dam, spillway and irrigation sandbox: `freshwater/irrigation_field.gd` (soil moisture, granted intake only, runoff back) | `test_sullivan_water_m2`: partial dam opening, bypass, spillway, uphill canal, canal split, shutoff gates, drought withdrawal, field runoff | PASS on David4 (#499) |
| M3 | `freshwater/terrain_adapter.gd` (beds and face crests read from the ground, STACKED and UNKNOWN columns never guessed) and `freshwater/terrain_water_edit_coordinator.gd` (precheck, edit, reconcile, commit; undo or freeze) | first half `test_sullivan_water_m3` on made-up ground: G01, G02, G03 (detection; flow BLOCKED), F06, F07, F14, roof over water. Second half: a server ground source (generator plus the dig log) and wiring the real digs | first half written; test NOT RUN |
| M4 | chunk seams, sleep and wake, persisted boundary reservoirs (guide 26) | cross-region and unload/reload comparisons | first step written: live regions are 96 m tiles on a fixed lattice; touching tiles join into one grid (one owner per face, no seam), copying every m³ (`test_sullivan_water_live`, waiting for David4). Second step: a region pushed out by the tile budget sleeps with all its water and is still drawn; a dig that reaches it wakes it with exactly that water. Still open: a region's dry border is closed (labelled limitation, guide 26.2), and sleeping water is not saved across a server restart (M8) |
| M5 | ocean baseline, one wave function for CPU and GPU (guide 6, 28) | height and normal cross-check (F10) | |
| M6 | river and ocean look (guide 5, 27) | shore, foam, refraction, underwater | |
| M7 | swimmers, boats, sources and sinks, river mouths (guide 7, 29) | movement and volume consistency | |
| M8 | save and load, optimisation | worst-case profiles | |

## Decisions recorded (guide 22: a departure needs a short record)

1. **Face law: the virtual pipe with memory (M1, changed after the first PC run).** The guide's baseline formula (3.1) is `Q = C·w·over·sqrt(2g|head|)`, with no memory between ticks. Its slope is infinite at zero head, so at dt 0.1 s, near-level water overshoots, and a cap is needed to stop it. The first run on Dave's PC (#498, 7 Nov 2026) showed the cost of that cap. With the cap at 0.2 of the levelling volume, a 3 m reservoir fed 2 m³/s stood 0.57 m over its dam crest and sloped 0.9 m from end to end. Every metre of flow needs a slope, so deep water moves like syrup. The guide allows this change. Its 3.1 says to "select and calibrate an appropriate weir/channel relation" when the baseline is not realistic enough, and its 3.4 says to "adjust damping or upgrade momentum treatment".
   - **The change:** the default is now the classic virtual pipe (Mei, Decaudin and Hu 2007). It is the model the guide names in 3.1. Each face keeps its discharge, and gravity accelerates it by the head over the wetted area above the sill. Linear friction of 0.5/s damps it, and the speed is capped at half a cell per tick.
   - **What stays the same:** the transaction (snapshot, candidates, scaling per cell, paired apply) and the ledger.
   - **The guide's formula:** it stays as `LAW_ORIFICE` for comparison.
   - **Cost:** two more float64 arrays per region.
   - **Tests:** the same test file, with F04's reservoir level as the check that tells the two laws apart.
2. **Rounding guard.** After the paired apply, a donor can sit a few 1e-17 m³ under zero from float rounding. Those traces are set to zero and added to `rounding_m3` in the ledger. They are not hidden, so a real leak still shows as a residual.

## Dave's standing water rules this system must keep

- The simulation decides where water is. Players dig ditches and build dams, and the water must follow (guide 3.6, 3.7). Today's water ignores digs (`water_hub2.gd:102`).
- Riverbeds run through the lowest part of each valley, in a neat carved channel that holds the river (Dave, 6 Nov 2026). The baked rivers (`tile_valley_drain.gd`, `drainage_channels.gd`) feed the guide's section 4.3 ("procedural river creation before runtime flow").
- A river starts at a lake or head pond with a spring on flat ground, or at a cave with springs on a hillside. Caves appear only far inland.
- No area-specific code and no height patches. Only rules that hold across the whole world.

## Dave's companion code (7 Nov 2026), compared and reconciled

Dave sent the guide's code files: `docs/water/edition3_code/`, kept as he sent them. A `.gdignore` keeps that folder out of the game, so its `class_name`s never clash with ours. `implementation/WaterGrid2D.gd` and `implementation/OceanWater.gd` are byte-for-byte the same as the `edition_1_baseline` copies.

| Dave's file | What we did |
|---|---|
| `WaterGrid2D.gd` | **Adopted as `LAW_ORIFICE`, exactly**: C = 0.18, heads under 1e-6 m ignored, each face capped at the donor's volume, then the same per-cell scaling. Our grid follows the same transaction and adds the ledger, springs and sinks, persistent crests and the kept-discharge pipe law (decision 1), which stays the default, because a law with no memory needs a slope to carry any flow. Measured on David4: a spring-fed 3 m reservoir tilts 1 m with the orifice law and stays level with the pipe law. `test_sullivan_water_grid` runs his smoke tests on both laws. |
| `TestWaterGrid.gd` | **Adopted**: his three tests (conservation, ditch through a ridge, dam built and removed) run with the same setups and pass conditions in `test_sullivan_water_grid._daves_smoke_tests`, under both laws. |
| `freshwater_runner.gd` | **Adopted its rule**: at most 4 ticks per frame, and time that could not run is **kept, never thrown away**, with a warning after 1 s of backlog. Our first `advance()` threw the backlog away. That is fixed. |
| `core/water_sample.gd`, `core/water_service.gd` | **Adopted** as `core/water_sample.gd` and `core/water_service.gd`, with the same field names (`surface_y_m`, `current_world_mps`, ...) and freshwater taking priority over the ocean. Adapted to read our grid directly and to run without a scene. |
| `OceanWater.gd`, `ocean_baseline.gdshader` | **Waiting for M5.** One thing to fix when they come in: the shader takes `world_vertex_coords`, and our world is about 54 km across. A wave phase `k·x` near x = 54,000 m loses precision in the shader's 32-bit floats, while the CPU copy uses 64-bit. The swimmer and the picture would then disagree, which is exactly what test F10 catches (knowledge doc water.md, lesson 3). The fix is a shared phase origin near the camera, given to both. |
| `water_buoyancy.gd` | **Waiting for M7** (swimmers and boats). It reads the service, so it slots in unchanged. |
| `voxel_terrain_edit_bridge.gd` | **Waiting for M3, second half.** Its checks (unit scale, `is_area_editable` before the edit, a revision per edit) match our edit coordinator's precheck. In our game the server owns the ground, so the server adapter reads the server's ground. The bridge's VoxelTool code is the client-side source. `is_area_editable` still needs probing on Dave's build (P2 did not list it). |
