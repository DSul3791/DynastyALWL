# Water in Godot: rivers, brooks, lakes, falls

**Last checked:** 2026-11-06 (web research by Jamie). **System owner:** Sonny. **Related:** `docs/DYNASTY_WATER_DESIGN.md`, `DIGGING_DESIGN.md`, `DESIGN_IDEAS.md` (water decisions, #289), `docs/archive/2026-11/` (old water handover).

## Lessons (read these first)

1. **The simulation decides where water is.** Players dig ditches and change where water flows (Dave's hard rule). So water can't come from fixed, hand-placed river paths. Our sim gives the height and the flow, and the drawing only makes it look good. Fluid Flux and terrainwatersim work the same way.
2. **Fine detail comes from textures, not from the sim grid and not from procedural noise.** Every source agrees on this: Valve, terrainwatersim ("fine waves are handled with a normal map"), Waterways, Unreal Water. Drag tiled normal, foam and noise textures along the flow map with the two-phase trick.
3. **Never feed absolute world coordinates (about 54 km here) into shader noise.** A float has a step of about 4 mm at that distance, and a `fract(sin(x)*43758)` hash breaks completely at large inputs: you get blocky "square panes" that differ between GPUs (#470, #472). Use small local coordinates, such as a chunk origin taken modulo the texture period on the CPU, or camera-relative coordinates. Use texture noise or an integer hash.
4. **A Godot double-precision build does not fix shader math.** Shaders stay 32-bit, and only the model-view transform is emulated. A double build would also force every GDExtension (our `water_core`) to be rebuilt, and the server and all clients onto the same build.
5. **An 8 m grid can't carry a 2 m ditch or a thin brook.** It needs either finer live cells near players (the decided plan) or extra "fine" 2 m data. Grid sheets on steep, thin water show steps and panes (#167, #465, #470).
6. **Rivers must be the valley floor.** Cutting beds to a fixed depth along a world-scale network before the final hills left 23-59% of river cells above their local low line (tile 3,4). Carve last, along the finished ground (#473), and check the share on every bake.
7. **Every place where two water systems meet is a seam that can break.** The live window, chunk sheets, the old grid look, fall ribbons and cave ribbons all had seam bugs (#301, #366, #459, #465). Use fewer overlapping systems and blend across a wandering band, not a straight edge.
8. **Water lag comes from sending and redrawing, not from the sim math.** The fixes that worked: skip unchanged chunks, redraw at most one chunk a frame, a 1 cm notify threshold, re-ask less and less often, and keep the sim thread from running ahead of real time (#63, #128, #147, #337, #343).
9. **Shore and depth looks come from the depth buffer.** Shore fade, depth colour and refraction all use the scene depth behind the water. This is standard in every Godot water shader, and ours does it too.

## How ours works (6 Nov 2026)

- **Simulation (server):** a pipe-model heightfield on 8 m cells (`src/water2`, `water_hub2`). Each tile has one live 1 km window (128 x 128 cells). Everything else is baked offline by `water_settler.gd` into `worlds/base_world/water/*.water`. The sim sends, per point, the level, current and shore, plus "fine" 2 m heights on running water and waterfall chains (`water_grid.gd`). The flow texture (protocol 85) is R surface, G and B flow, and A depth.
- **Drawing (client):** the live window is one sheet reading the sim texture. Other chunks each get a `liquid_surface.gd` sheet from the baked levels (2 m where water runs). One procedural shader handles shore fade from depth, ripples dragged two-phase along the current, foam from speed and white water from slope, depth colour, and Snell's window from below. Cave streams are ribbon meshes (`cave_streams.gd`). The sea is a separate plane (`water_material.gd`). Falls have mist (`fall_mist.gd`).
- Full write-up: `/mnt/project-files/water/current-water-system.md` (Sonny).

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| 2 Nov | All inland water as continuous flowing sheets from the sim texture | #91 | Worked; the base of today's look |
| 2 Nov | A baked wet cell keeps a film where live water runs thin | #90 | Fixed puddle chains in the live window |
| 2 Nov | Thin water on hillsides: 2 m chunk sheets laid on the ground | #167 | Brooks became one stream; steep ones still blocky |
| 2 Nov | Falls: thin fast water drawn on the live sheet; fall chains painted wet; mist | #142, #109 | Worked |
| 2 Nov | Water lag: skip unchanged chunks, reuse the texture, one chunk redraw a frame | #128, #147 | Worked |
| 2 Nov | The sim thread never runs ahead of real time (it was 4.5x) | #63 | Worked; saved half a core |
| 3-4 Nov | River sources on flats or in their own pond; spring caves; hillside springs | #92, #170, #252 | Worked, following Dave's water rules |
| 4 Nov | Live window crossfades into the chunk water over a wandering band | #301 | Fixed the hard square edge (BUG-006) |
| 4 Nov | Running water and falls read as water, not glass | #312 | Worked (BUG-010) |
| 4 Nov | Theta flow weighting in the sim | #342 | Stopped the deep-lake chequer (BUG-030) |
| 4 Nov | Settled water not re-sent (1 cm threshold); re-asks back off | #337, #343 | Cut network lag |
| 4 Nov | A chunk sheet draws baked water where the live sim is dry | #366 | Fixed invisible water spots |
| 5 Nov | `water_material` flow patch from the 31 Oct plan | #434 | Dropped: superseded by protocol 85 and `liquid_surface` |
| 5-6 Nov | Rivers grow to the sea; caves only at brook heads; rivers keep their water in the bed | #450, #464 | Worked (rebakes on the PC) |
| 6 Nov | Steep brooks drawn smooth; no bare strip between sheets | #465 | Better; square panes remained |
| 6 Nov | Square panes on brooks traced to the sin hash at about 54 km | #470, #472 | #472 swaps in a sin-free hash; the coordinates are still large (lesson 3) |
| 6 Nov | Rivers routed over the finished ground, cut 5 m deeper, dry land beside a river raised to drain to it (tile_valley_drain.gd) | #473 | Merged. Dry ground lower than the settled water beside gentle rivers, tile 3,4: 11.9% to 7.8%. Lessons: measure against the SETTLED water (.water), not the painted surface, which stands about 1.5 m higher (median) once beds are cut deeper; a spawn pad pinned in the bake is an area patch (Dave): move the spawn instead |
| 7 Nov | Dave's guide made the water foundation; M1 closed grid built (m³ volumes, paired faces with crests, outflow scaled per cell, ledger) in `src/sullivan_water/` beside water2; the current water ignores digs (`water_hub2.gd:102`) | this PR | PASS on David4 (30 ok). Lesson: the guide's sqrt(head) law chatters near level water; cap each face below 1/4 of the levelling volume |
| 7 Nov | Dave's guide code files saved (docs/water/edition3_code) and compared: his orifice grid, smoke tests, runner rule and water query adopted; ocean, buoyancy and voxel bridge kept for M5, M7, M3 | this PR | NOT RUN yet. Lesson: his runner keeps the backlog; ours had thrown it away. Watch the ocean shader's world coordinates at 54 km (lesson 3) |
| 7 Nov | Water M3 first half: terrain adapter (bed = first ground met scanning down, refined by bisection; face crest = highest of the two ends and the midpoint; roofed columns STACKED, unloaded UNKNOWN) and one edit coordinator for digs | this PR | NOT RUN yet. Lesson: read everything before writing anything, so an edit that meets unloaded ground leaves no half-updated grid |
| 7 Nov | A 3 m ditch on 2 m cells read as shut: the face crest was the highest of three samples, and one end of most faces along the ditch sat on the uncut bank. Now five samples in two half-faces; the face takes the lower half (guide 24.1 subsegments). The live test now digs like the client (1.5 m spheres on the surface every 1.5 m), because sparser digs grazed the surface and read as roofed | #506 | Lesson: test a ditch whose axis lies on a cell edge; the plain maximum over-blocks openings narrower than about two cells |
| 7 Nov | Dave's guide code files saved (docs/water/edition3_code) and compared: his orifice grid, smoke tests, runner rule and water query adopted; ocean, buoyancy and voxel bridge kept for M5, M7, M3 | this PR | NOT RUN yet. Lesson: his runner keeps the backlog; ours had thrown it away. Watch the ocean shader's world coordinates at 54 km (lesson 3) |
| 7 Nov | Water M4 first step: live 2 m water runs in 96 m tiles on a fixed lattice; a dig past a region's edge joins the touching regions into one grid (exact copy of every cell's m³), so a ditch flows on across the old edge. At most 4 tiles run | M4 PR | Lesson: separate grids side by side cannot share a face honestly (guide 26.1 needs one supply scale per cell), so join them into one grid instead of stitching |

## What others do (with sources)

**Flow maps, the industry standard.** Valve, Portal 2 and Left 4 Dead 2 (SIGGRAPH 2010):
- A tiled normal map is offset by flow times time. Two layers run half a phase apart and crossfade.
- A noise texture shifts the phase so the surface doesn't pulse in sync.
- Normal strength scales with speed.
- The flow map is about 4 texels per metre, combed in Houdini.
- Cost: 2 texture fetches and about 21 instructions.
- https://www.advances.realtimerendering.com/s2010/Vlachos-Waterflow(SIGGRAPH%202010%20Advanced%20RealTime%20Rendering%20Course).pdf · https://www.hlportal.de/files/GDC2011_BronwenGrimes_NonstandardTextures.pdf

**Godot:**
- **Waterways (Arnklit).** Spline rivers with a baked flow and foam map, made by raycasting to the terrain and building a shore distance field. It uses normal, foam and noise textures, plus a global height and flow map for gameplay. Rivers only; they don't merge. https://raw.githubusercontent.com/Arnklit/Waterways/main/README.md
- **Godot water-sim devlog.** 1 m voxel water with virtual pipes in chunks. The flow is stored per vertex and rebuilt only when a chunk changes, and the shader drags ripples along it. https://engineer-game.org/devlog/2025/12/22/water-rendering.html
- **terrainwatersim.** A GPU pipe model (outgoing flow in 4 directions), rendered with Portal 2 flow mapping, foam from speed, and normal maps for fine waves. https://github.com/Wumpf/terrainwatersim/wiki
- **Shaders.** Two scrolling normal maps, depth-buffer shore foam, and screen-texture refraction. https://godotshaders.com/shader/water-shader-3d-godot-4-3/ · https://github.com/spicyhaydenc/Godot-4-Realistic-Water
- **FFT oceans (Godot 4).** https://github.com/tessarakkt/godot4-oceanfft · https://github.com/2Retr0/GodotOceanWaves · OceanPro for Godot 4.7: https://forum.godotengine.org/t/oceanpro-1-0-gpu-fft-ocean-system-for-godot-4-7/144004

**Big games and engines:**
- **Horizon Zero Dawn.** The river curve is snapped to the terrain, and each point's height is capped at the running minimum ("only goes lower"). The slope sets the width. The banks are carved with noisy edges. Steep parts are built as steps, pools and cascades. https://80.lv/articles/horizon-zero-dawn-procedural-rivers-wires/
- **Unreal Water.** Spline rivers, lakes and ocean that carve the landscape. https://dev.epicgames.com/documentation/en-us/unreal-engine/water-system-in-unreal-engine
- **Fluid Flux (Unreal).** A GPU shallow-water sim that can save and load its state and bake flow into vertex colours for static rivers. Foam and waves are dragged by velocity, and a small ripple solver follows the player. https://80.lv/articles/fluid-flux-a-cool-water-simulation-system-for-unreal-engine/
- **Waterfalls.** A sheet with a scrolling texture, a faster second layer, splash and mist particles, and pool foam. https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/create-waterfalls

**Rivers on the valley floor:**
- **Priority-Flood** pit filling, then D8 flow accumulation on the final heightmap. Rivers sit where flow is high. https://arxiv.org/pdf/1511.04463 · https://landlab.readthedocs.io/en/latest/tutorials/flow_direction_and_accumulation/PriorityFlood_realDEMs.html
- **Rivers first, then terrain around them** (Génevaux et al. 2013; Red Blob mapgen4). https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf · https://www.redblobgames.com/maps/mapgen4/
- **Hydraulic erosion** passes (Houdini, Gaea, World Machine) output flow masks. https://www.sidefx.com/docs/houdini/heightfields/erosion.html

**Large-world precision:**
- Godot's docs table gives a 4 mm step at 32-65 km, "the most recommended for any 3D game". https://notabug.org/godotengine/godot-docs/src/4.3/tutorials/physics/large_world_coordinates.rst
- Double builds still leave shader world-space math 32-bit. https://godotengine.org/article/emulating-double-precision-gpu-render-large-worlds
- The sin hash is "completely broken" at large inputs; use an integer hash or a noise texture. https://arugl.medium.com/hash-noise-in-gpu-shaders-210188ac3a3e

## Decided / next (Sonny's plan, 6 Nov; `/mnt/project-files/water/water-plan-2026-11-06.md`)

1. #473: rivers on the valley floor (PC rebake and gate). The river survey's share of cells above the low line is checked on every bake.
2. #472: precision. The sin-free hash is merged; small, camera-relative coordinates come with the textures.
3. CC0 normal, foam and noise textures dragged along our two-phase flow. Kathreen can replace them to match Art_Direction.md.
4. A fine 2 m live sim window follows each player (about 256 m, in `water_core`), so ditches and brooks are real water. It gets a PC cost test first. Brooks are **not** drawn as ribbons, because ribbons can't follow a player's ditch. Cave streams stay ribbons.
5. Later: one sim-driven sheet instead of overlapping systems, and an FFT sea if Dave wants one.

Open questions go on the QA page. The four water research cards were answered by this plan on 6 Nov.

Full research report: `/mnt/project-files/water/water-research-2026-11-06.md`.
