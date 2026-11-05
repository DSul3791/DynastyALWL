# Dynasty water: history for the next team (Sonny, 1 Nov 2026)

Branch `dynasty-water`. Code under `src/water2/`. Read with `docs/handoff/HANDOFF_SONNY.md`, `docs/DYNASTY_WATER_DESIGN.md`, `docs/PONYTAIL_RULES.md` (the 31 Oct stage log, `DYNASTY_WATER_STATUS.md`, and the old-water note `WATER_HANDOVER.md` are archived in `docs/archive/2026-11/`; their live parts are section 9).

## 1. Why we wrote our own water

The old system (`src/water/`) is a settled-levels water: tiles are baked with a "settled depth" file per tile, and a live hub nudges those levels. It draws well but it cannot do what Dave asked for: water that really runs down surfaces and over hills, a thickness you can change, a speed that is separate from the waves, spring and sink blocks you can place, rivers that carry flow, and rules for wading, swimming and drowning that come from the water itself. Its flow in the real game is guessed on the client from level differences (`WaterGrid._velocities`), not simulated. Dave decided (31 Oct) that we build a new system beside it, stage by stage, behind a flag, and keep the old one frozen until the new one is trusted. On 1 Nov he decided the new water becomes the default and the old one stays behind `--water-old` and a settings switch, so it can be deleted later.

## 2. What we were trying to overcome

Water that flows downhill by itself and fills basins to one level; thickness (depth in metres); settable colour, clarity, density, viscosity and flow rate; flow speed and waves as separate settings (a fast river can be calm); spring blocks and sink blocks; rivers, lakes, ponds, rain runoff and a sea held at a level; swim, wade, drown and being swept away; and all of it without rebuilding the world: the baked tiles and the water shader look stay as they are.

## 3. How it was built

Method: the local inertial shallow-water scheme (Bates, Horritt, Fewtrell 2010, the LISFLOOD-FP family). Flow is kept per cell face (m^2/s), friction is Manning's n plus an extra viscosity, the time step follows a CFL rule, and 16x16 blocks sleep when nothing moves. Chosen over cellular automata (no real speed), virtual pipes (sloshes) and full shallow water (heavier than needed).

Stages:
- **(a) core sim**, `water_field.gd`: bed, depth, qx, qy, springs, sinks, fixed levels (sea), open edges, rain, channel mask, rest snap, `hold_steady()` for rivers. Traits: `water_traits.gd` + `water_kinds.json` (fresh, sea, swamp, mud, lava). Rules: `water_rules.gd` (wade/swim/drown/sweep as pure functions). Test `test_water_field.gd` (30 checks).
- **(b) real tile window**, `water_window.gd`: reads a tile with the repo's own `TileFile` and `TileTerrainData` (no new reader), takes the 8 m height grid as the bed and the baked settled water as the starting depth, and cuts a 128x128 cell (1 km) window around the wettest spot. Test `test_water_window.gd` (7).
- **(c) visual demo**, `demo_water_field.gd`: draws the sim with the game's own `water_material.gd` shader, pictures in `src/water2/art/` and on the QA page.
- **(d) the swap**, `water_hub2.gd`: implements exactly the old hub's API (setup, set_centre, set_live, take_updates, data_of, sim_of, stats, step_rate, set_runoff, dig, fill, stop and the fields rate, runoff, busy, centre, data). The server gives each tile's data the levels with `set_sim`; the old client and shader draw them unchanged. That is the swap boundary: only levels cross it. One window runs; the rest of the tile keeps the baked levels; wet window-border cells are held at their baked level, the sea (bed under 0) is held at 0. Test `test_water_hub2.gd`.
- **(e) rain, springs, sinks from data** (`water_sources.json`, `apply_sources`) and rivers held steady. **Swim/drown is not wired** (the existing `swim.gd` works from the drawn levels).
- **(f) not built:** the protocol flow channel, windows that follow players, digs and fills into the field.
- **Render texture**, `water_flow_texture.gd` (+ `test_water_flow_texture.gd`): builds a depth + flow + foam texture and a shader include. Not used by the game yet.

Reused, not rewritten: baked tiles and `TileFile`, `TileTerrainData._load_sim_water`, the 8 m grid, the game water shader (`src/client/water_material.gd`, unchanged), `ShoreRules` (the shore drawing still comes from levels), Godot's JSON and Packed arrays. Edited outside `src/water2/`: `scenes/terrain_server/terrain_server.gd` (hub choice), `tools/look_rig.sh` (`--server-arg`), and, with the default flip, `scenes/launcher.gd` and `src/client/game_menu.gd` plus `src/water2/water_choice.gd`.

## 4. Problems and how they went

- **Lake cost.** First numbers were 224 ms per simulated second; the deep held sea set the time step. Fixed by holding the sea at level 0 and never stepping cells outside the channel mask: 92 ms. Re-measured 1 Nov: 101-116 ms alone (170-190 when another job shared the PC). That is about 10 percent of one core on a thread limited to 50 percent duty; the main thread only swaps an array reference in `set_sim`.
- **Sleeping blocks.** In the real window all 64 blocks stay awake, because the held rivers move all the time. So "lakes sleep" is true for a closed lake (the test shows it) but the starter window never sleeps. The cap is the fixed window size (128x128 cells). Smarter options: a cell list instead of blocks (2-3 times cheaper), or stop stepping steady river cells (see 6).
- **River flooding.** `hold_steady()` first made huge springs from steep slopes and the deep sea and flooded the window. Fixed with caps (3 m^2/s, 6 m/s), headwater-only springs, the sea held at 0 and the channel mask: 0 cells flooded.
- **River drain.** An early figure said 12 percent of baked wet cells stopped being drawn in 180 s. `probe_drain.gd` on the current code: 98.6 percent stay drawn at 1, 3, 10 and 30 minutes (2595 of 2633), 113 cells are under half their baked depth (worst loss 2.2 m), volume 140 percent of the start. So rivers do not vanish; they get slightly deeper. No drain fix was needed.
- **Real-game picture.** First rig picture: grey, camera inside the terrain (a walking shot at agl 12 fell through, y -37). Second: open sea (ground -49 at the chosen spot). Fix: fly the camera (agl over 40, no collision) and choose a spot with real river or lake. `probe_pick_spot.gd` finds them (its printed world x/z are wrong, see the handoff). A good picture of a river or lake is still outstanding.
- **Shader depth and flow.** In the real game the client computes flow from received levels, so the sim's flow, depth and traits do not reach the shader. A protocol flow channel is needed; the six-line `water_material.gd` patch plan is in section 9 and is not applied.
- **Imports.** A new worktree renders missing textures until `godot --headless --path . --import` is run once; the import leaves hundreds of untracked `.uid`/`.import` files that block a merge, delete only those exact files before merging.
- Smaller ones: GDScript `%e` format unsupported; `:=` cannot infer from Variant; a `Window` const shadows a native class (renamed `WaterWindow`); test thresholds for the settled bowl and last wet cell; QA-page pushes rebased over Dave's removals.

## 5. Numbers and tests (voxel build godot.windows.editor.x86_64.exe, via `tools/godot_slot.sh`)

31 Oct: `test_water_field` 0 failures (30 checks, rain, hold_steady), `test_water_flow_texture` 0, `test_water_window` 0, `test_water_hub2` 0 (window draws 2732 of 2732 at start, over 95 percent after 180 s, outside the window exactly baked). Rivers hold: 98.6 percent kept, 0 flooded. About 32 microseconds per wet cell per simulated second; 128x128 window with 2,900 wet cells. Earlier physics numbers: a 4 percent chute runs 1.9 m/s with no waves; front to 80 m in 27 s (fresh), 102 s (swamp), 828 s (mud). The 1 Nov run of the three slow tests (`test_water_soak`, `test_spawn_dry`, `test_first_hour`) and the four water tests with the default flipped is listed at the end of this file.

## 6. Unfinished, exact next steps

1. Real-game before/after pictures at a river or lake (fix `probe_pick_spot.gd` origin, fly at agl 50, compare `--water-old` and default).
2. Protocol flow channel + shader patch so the game shows the sim's flow, depth and kinds (patch plan in section 9).
3. Windows that follow players, with a shared seam; one window only today (starter tile).
4. Digs and fills reaching the field (`dig` and `fill` in the hub are empty shortcuts).
5. Swim, drown and sweep wired to the player (`water_rules.gd`).
6. Cost: cell-list stepping, or sleeping steady river cells, if more windows are needed; a GDExtension only if windows must cover whole tiles.
7. One-hour held-river soak; lava and swamp through the game shader; the rain scale is a guess (`RAIN_PER_RUNOFF`).

## 7. PONYTAIL shortcuts (`shortcut:` in the code) and when to revisit

One window only (revisit when a second player is far from the first). `dig`/`fill`/`step_rate` do nothing yet (when digging should change water). Rain only on channel cells and the rain scale constant (tune with real storms). Hold-steady caps 3 m^2/s and 6 m/s (revisit if a big river looks too thin). Draw threshold 0.12 m and film 0.14 m copied from `TileTerrainData` (revisit if the shore looks wrong). Block stepping instead of a cell list (when cost matters). One kind per field (mixing liquids later). Research citations other than Bates 2010 are from memory.

## 8. Also useful

Pictures for Dave go on the QA page, one card per picture (worktree `C:/GodotProjects/DynastyALWL_qa`, branch qa). Never `git add` `worlds/base_world/water_archive/` or `scratch_world_*`. No baked tile may be committed without Dave's go. Max 3 heavy Godot jobs at once; other sessions often fill the slots, jobs just queue. The look rig runs from this worktree and needs `--server-arg --water-old` to show the old water after the flip.

## 9. Kept from the 31 Oct status doc (moved here word for word, 5 Nov 2026, when `DYNASTY_WATER_STATUS.md` was archived)

### Shader patch plan (for the protocol flow channel, item 2 of section 6)
**Superseded (Sonny, 5 Nov 2026): not to be applied.** Since protocol 85 (2 Nov) the sim's flow reaches the screen through `src/water2/liquid_surface.gd`, which samples the same texture (R surface, G/B flow, A depth) and carries ripples and foam along the flow. Inside the live window the grid look (`water_material.gd`) crossfades out over `blend_m` and the liquid sheet draws the water; outside it there is no sim data. This patch would only touch the 24 m blend band. Kept below as history.

- **The six-line patch for `src/client/water_material.gd`, to apply only after the tests have run** (it changes the game's shader, default path must stay identical when `water2_on` is 0): (1) paste `SHADER_INCLUDE` after the uniform block (line 45); (2) in `vertex()` compute `world_pos` first; (3) after `flow = ...` add `if (water2_on > 0.5) { vec4 w = water2_at(world_pos.xz); if (w.x >= 0.0) { flow = w.gb / fastest_m_s; } }` (the flow is then the sim's, in units of the drawn top speed); (4) add `varying float water2_foam;` set in the same branch to `w.a`; (5) in `fragment()` multiply the existing foam by `1.0 + water2_foam * rough_or_turbulence` only when `water2_on > 0.5`; (6) the client calls `FlowTexture.apply` for the window it knows (needs the protocol flow channel for real play; in the demo scene it is a direct call).

### Step 4 if GDScript is not enough: options (cost, risk)
Measured: 92 ms of compute per simulated second for a 1 km window with 2,900 wet cells, on a 50 percent duty thread = 9 percent of a core. That is inside the budget for ONE window, so no native code is needed for the starter case. It is not enough for many windows (one per player) or a wide lake wake-up. Options when it is: (1) static lake levels, sim only for moving water: lakes already sleep after the rest snap, so this is mostly done; (2) skip stepping dry channel cells (a cell list instead of 16 x 16 blocks): about 2 to 3 times cheaper, 1 day, low risk; (3) a GDExtension in C++ for the flux and depth loops: about 20 to 50 times faster, 3 to 5 days, adds a build step and a platform binary to the repo (the main risk), keeps the same arrays; (4) compute shader on the client, server keeps the coarse state: biggest change, 5+ days, server and client could disagree. Recommendation: do (2) first if a second window is needed, (3) only if windows must cover whole tiles.
