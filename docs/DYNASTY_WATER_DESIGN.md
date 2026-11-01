# Dynasty water: design (Sonny, 31 Oct 2026, branch `dynasty-water`, code in `src/water2/` only)

A water system of our own, built beside the live one (`src/water/`, untouched) and swapped in behind a flag only when it beats it. Why: `docs/WATER_OWN_SYSTEM_PROPOSAL.md`. Stage (a), the core sim, is built and tested; this page is the whole plan.

## 0. Ponytail ladder (Dave's rule, `docs/PONYTAIL_RULES.md`): what we reuse and what we write

Reused, not rewritten: baked tiles and `TileFile` (header, height step, sections), `TileTerrainData._load_sim_water` (the settled `.water` depth), the 8 m grid of the heights as the sim grid (no resampling), the water shader and its look, `ShoreRules`, JSON for traits (Godot's `JSON`), `PackedFloat32Array` and `Dictionary` (no new containers), `class` free scripts like the rest of the repo, the repo's headless-test style. Written, because nothing in the codebase or Godot does it: the shallow-water step (`water_field.gd`, one file), the trait table (`water_kinds.json` + a 40-line loader), the rules (pure functions, one file), the tile window (`water_window.gd`, 70 lines). Not written: no new renderer yet (the existing shader is the render boundary), no copy of the old sim, no custom serialisation (the tile and the `.water` files are the save format). Shortcuts are marked `shortcut:` in the code. Validation kept: unreadable tile gives `{}`, depths never negative or NaN (tested), tile file never written (tested).

## 1. Research: what the field does (the Bates paper is confirmed by search: Journal of Hydrology 387(1) 33-45, doi 10.1016/j.jhydrol.2010.03.027; de Almeida et al. 2012 report instability in low-friction areas, which is why every kind here has a base viscosity of at least 0.05; the other citations are from memory and unchecked)

| Approach | Good | Bad for us |
|---|---|---|
| **Cellular automata** (Minecraft-style levels, spread to lowest neighbour) | trivial, fast, deterministic | no real speed or momentum; rivers look like staircases; no "fast flow" |
| **Virtual pipes** (O'Brien & Hodgins 1995; Mei, Decaudin, Hu 2007) | simple, GPU friendly, mass conserving | sloshes and rings on slopes unless damped; flux per pipe, awkward friction |
| **Local inertial shallow water** (Bates, Horritt, Fewtrell 2010, LISFLOOD-FP) | same grid as pipes, but real units (m^2/s per width), Manning friction, stable with a CFL step, no waves in steady flow | needs a small step on deep fast water; wet/dry fronts need care |
| **Full shallow water** (Saint-Venant, momentum in two directions) | best fidelity (hydraulic jumps) | heavier, stability tricks; not needed for a game river |
| **Flow maps** (Vlachos, Valve 2010, Portal 2 / Left 4 Dead 2) | the standard for how flowing water *looks* | look only, not a sim: we feed one from the sim |
| **Particles / SPH** | splashes | cost; not for lakes and rivers |

**Choice: local inertial shallow water for the sim, a flow map (velocity texture) for the look, a fixed-level sea.** It is what hydrology tools use for floods at this scale (8 m cells), and it makes the two things Dave wants fall out of the physics: water runs downhill by itself, and a fast river is fast *because friction balances the slope*, so it stays smooth.

**Godot options:** GDScript on the CPU (what stage a is: ~3.7 microseconds a cell, only for awake blocks); a compute shader through `RenderingDevice` (the same stencil, 100x faster, but the server is headless and must agree with the client, so the CPU sim stays authoritative); a GDExtension in C++ if GDScript proves too slow (the arrays are flat `PackedFloat32Array`, so it ports directly). Surface rendering: a mesh per chunk whose heights and flow come from textures.

## 2. Capabilities

Flow downhill and fill basins to one level; springs and sinks; fast chutes without waves; falls (a drop of more than a few cells simply produces fast thin flow that the render calls a fall); a sea held at a level; wet/dry shores; liquids that differ by settable traits (below); swim, wade, drown and current rules; sleep when nothing moves.

## 3. Settable traits (`water_kinds.json`, `water_traits.gd`; one kind per field, five kinds shipped: fresh, sea, swamp, mud, lava)

| Trait | Unit | Feeds | Effect |
|---|---|---|---|
| `color` | rgb | render | body tint |
| `clarity_m` | m | render | how deep you see the bed (swamp 0.6, mud 0.1) |
| `density` | kg/L | rules | floats a body higher; heavy liquids carry more drag |
| `viscosity` | 1/s | sim, rules | extra linear drag: mud and lava creep, water runs (test: front to 80 m, fresh 27 s, swamp 102 s, mud 828 s) |
| `roughness` | Manning n | sim | friction that sets river speed on a slope |
| `flow_rate` | x gravity | sim | how eagerly it runs (lava 0.25) |
| `film_m` | m | sim | depth under which it will not flow: thin water wets, honey keeps a film |
| `turbulence`, `wave_speed` | 0..1, x | **render only** | surface waves; **separate from flow speed** by design, they never reach the sim, so a fast river can be glassy or choppy as art wants |
| `harm_per_s` | hp/s | rules | lava, acid |

Mixing liquids in one field is not in stage a (one kind per field; a lava flow and a river are two fields). A per-cell kind id with advection is the later step, listed in section 11.

## 4. Springs, sinks, edges

`add_spring(i, j, m3/s)`, `add_sink(i, j, m3/s)` (takes at most what is there), `fix_level(i, j, level)` (the sea: depth is held to the level, so waves and tides are a changing level), `open_edges` (water leaving the field). A spring on a ridge flows both ways by itself.

## 5. Swim, wade, drown, current (`water_rules.gd`, pure functions so server and client agree)

Under 2 cm dry; 8 cm wet (splash); to 1.0 m wade (speed down to 0.45, thick liquids slower); deeper than 1.0 m the body floats and swims at 0.45 speed with breath refilling; head under only when the player dives and the water is over the head, then 25 s of breath, then drowning. Current: a walker is **swept off their feet when depth x speed passes 1.0 m^2/s** (the flood-safety rule of thumb; 0.6 would be for children or slippery beds). Lava and acid add `harm_per_s`. All thresholds are constants at the top of the file.

## 6. Data model

Per field: `bed` (m), `depth` (m), `qx`, `qy` (m^2/s on the east and south face of each cell), `traits`. Springs, sinks and fixed levels are dictionaries by cell. 16 x 16 cell blocks carry an awake counter. Memory is 16 bytes a cell plus 4 for the scratch limiter: 20 bytes x 3.7 million cells = 74 MB for a whole 1921 x 1921 tile, which is why only windows around players and springs run.

## 7. Algorithm (per substep of at most `0.7 * cell / sqrt(g * hmax)`, capped at 1 s)

1. Springs add volume. 2. For every face of an awake block: flow depth `hf = max(surfaceA, surfaceB) - max(bedA, bedB)`; if `hf` is under `film_m` the face is dry, else `q' = (q_mixed - g hf dt (surfaceB - surfaceA)/dx) / (1 + dt (g n^2 |q| / hf^(7/3) + viscosity))`, with `q_mixed` blending in the neighbouring faces (theta 0.85, the scheme's stabiliser). 3. Cell limiter: no cell gives away more than it holds (outgoing discharges scaled). 4. Depths from net discharge; sinks; held levels; open edges; depths under 10 micrometres snapped to 0. 5. A block sleeps after 24 quiet steps (depth change under 2 micrometres and discharge under 2e-5), and wakes when water or flux reaches it (blocks next to an awake block are always stepped, so the front wakes what it reaches).

Known limits seen in the tests: a violent dam break (2 m column) leaves a short-lived dry hole in the middle (the film threshold meeting the rarefaction); a bowl filled by a 20 m^3/s fountain rests within 12 cm after 300 s of settling, not yet 1 cm (tighten with a smaller theta or a longer settle). Both are visible in `src/water2/art/dam_break_0_4_12_40s.png`.

## 8. Tile integration (via the baked heights)

The bed of a field is `TileTerrainData.heights` (decoded with `TileFile.height_step_of`) resampled to the field's cell size (8 m matches the `.water` files, so the settled water can be loaded straight as `depth = level - bed`: that **is** the start-full state). A field window follows each player (for example 128 x 128 cells = 1 km) and every spring or lake outlet; outside windows the baked levels stand still. Player-visible digging changes `bed` (the voxel edits), which wakes the block. Windows hand water across their edges by the same face flux (two fields side by side share a face array on the seam).

## 9. Render contract

The sim exposes per cell: surface height `bed + depth`, depth, velocity (`velocity(i, j)`, m/s), and the look traits. The client builds one RGBA float texture per window: R depth, G velocity x, B velocity z, A `turbulence` times a foam hint (speed, depth change, shore distance). The existing water shader (`src/client/water_material.gd`) keeps its sea, foam and glint look but reads depth and flow from the texture instead of the depth buffer and the Manning guess (its flow-advected ripples already take a speed). The sea stays the analytic plane with the held level.

## 10. Performance budget

Target: under 2 ms a frame on the server for all awake windows, under 0.3 ms on the client for texture upload. Measured on a real tile (stage b, `test_water_window.gd`, 96 x 96 window with a 14 m deep lake, one quarter of the cells wet): **about 27 microseconds per wet-cell substep, 500 ms per simulated second** for the whole window, far over budget; so GDScript is fine for rivers and ponds but a lake needs the GDExtension or compute path, or the lake stays a flat level (sleeping) until a player disturbs it. Earlier probe (mostly dry cells, cheap): 3,072 awake cells cost 11.5 ms per simulated second on a 256 x 256 field and 15.6 ms on 512 x 512 (the extra is the block scan). A river of 400 m is 50 cells long, so a handful of rivers fit; a sleeping field is exactly zero cells. If a window with many awake blocks exceeds the budget: a GDExtension (the arrays port as they are) or a compute pass on the client with the server keeping only the coarse state. **Not yet measured:** a big lake wake-up (thousands of cells awake together); that is the stress test for stage (b).

## 11. Tests (`src/water2/test_water_field.gd`, 21 checks, passes, about 60 s; small and headless)

Closed box keeps its volume; dam break settles flat and sleeps; a sleeping field costs zero cells; water on a slope moves downhill and never uphill; a spring's volume equals rate x time and the bowl rests at one level; a 4 percent chute runs at 1.9 m/s with a surface swing of 0.1 mm (no waves) and no sideways drift; thick liquids are slower; a held sea wets a beach to its height; the wade, swim, drown, sweep and lava rules. Next: a seam test (two windows equal one big field), a heavy-wake-up cost test, a baked-tile test (the nine `.water` files load as settled depth and stay still), a determinism test (same inputs, same depths, for server and client).

## 12. Swap-in plan, behind a flag

1. Stage (a): core sim and rules (done, this branch). 2. (b): tile bed and window following, springs from the plan, load `.water` as the start state, a test that the start stays still. 3. (c): render contract: the texture, the shader reading it, pictures against the old look. 4. (d): the server side: swim and drown wired to the player, falls, NPC and flora queries through a small `WaterQuery` interface that both systems implement. 5. (e): flag `--water2` (default off), run both side by side on the same tiles, compare levels and cost, then flip the default only with Dave's go. The old system is deleted last, after one release with the flag on. Rollback is the flag.

## 13. Risks and what I do not know

GDScript cost on big wake-ups; the seam between windows; dry holes in violent fronts; the flora, NPC and server code that reads `sim_levels` today must move to the query interface; I have not yet checked how voxel digging edits reach a field. Ratings, honest: sim core 4 of 5 (works and tested, not yet on real tiles), traits 3 (settable and tested for flow speed only; colour and clarity unused until stage c), rules 3 (pure and tested, not wired to the player).
