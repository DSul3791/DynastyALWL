# Ice design note (River start thread, 2026-10-21) - NOTE ONLY, nothing built

Dave's rules: pond and lake ice ALWAYS holds (you cannot fall through). Ocean ice is floating chunks with open water between them: you can fall in, swim, or climb onto a chunk.

## What exists now
Only a client timer: `weather.ice_cover` in weather_sounds.gd (air <= -2 C for 15 min). No ice in the world: no look, no walkable surface, no server state, no melt. Weather is a pure function (src/shared/weather.gd: `temp_c` from zone, season, altitude), so no weather traffic exists today.

## Part 1: pond and lake ice

**State: none to save.** Ice thickness is a pure function like weather: integrate freezing/thawing over the last ~30 game days of `Weather.state` at the body's altitude (cheap: 720 hourly steps, once per game hour per body). Server and every client compute the same number, so protocol cost is zero and nothing drifts or needs a save file. `Ice.cover(clock, zone, altitude_m, depth_m)` in src/shared/ice.gd, returns 0..1 (walkable from 0.5, as ice_sounds.gd already assumes). Shallow ponds freeze faster than deep lakes (depth factor), high ponds earlier.

**Which water:** still bodies only (the draw side already knows: `_calm_still_water`, 778a430; running rivers and falls never freeze, maybe edge ice later). Ice applies to the cells the draw marks as standing water.

**Walkable surface, options:**
- A. Client floor rule (RECOMMENDED if the controller allows it): the character treats a frozen cell's water level as floor (one function `floor_at`, no physics objects). Zero cost, always holds by construction.
- B. One flat StaticBody3D slab per water chunk, built from the frozen cells (collider only). Works with any physics, small mesh cost, one rebuild per freeze change.
- C. Ice as a voxel material in the ground store. Rejected: puts ice into the edits/block stores and re-bakes.

**Look (Art):** the water shader gets a `ice` uniform 0..1 (frost edge, then opaque white-blue sheet, cracks); thaw runs it back. Water thread: flow continues under the ice, surface level locked is a draw-only rule (the sim is not changed). Sounds: ice_sounds.gd switches from its timer to `Ice.cover` (one line).

**Melt:** same function run backwards in warm weather (thickness falls by degree-hours); below 0.5 the pond is open water again (you swim; stepping rule: you can never be on ice while it melts under you: the surface becomes water, you are in it at the surface, no drop).

## Part 2: ocean ice (built after pond ice)
The sea is held at level 0 by the sim, so floes are draw and collide only, no water-thread work.
- **Floes (RECOMMENDED: deterministic static):** Voronoi cells (20 to 60 m) over the sea in cold zones, seeded from the world seed; each cell is a floe or open water by a threshold on `Ice.cover` plus per-cell noise (cover 0.2 = scattered chunks, 0.8 = nearly solid pack). Floe radius shrinks with melt, so chunks break up and vanish in spring. No state, no traffic, same on every client. Floe top 0.4 m above sea, 1 m thick.
- **Fall in:** gaps are open water: normal swimming. **Climb on:** mantle rule at a floe edge (the swimmer pulls up onto it when facing it, within reach). **Under a floe:** a swimmer under a slab is pushed gently to the nearest gap and takes cold exertion cost; never trapped.
- B. Drifting floes (server entities, positions in the protocol, collision between floes): richer, but a new server entity system and bandwidth. Later, if wanted. C. Voxel ice: rejected as above.

## Order and cost
1. `Ice.cover` shared function and a test (no protocol, no save).
2. Floor rule or slab collider, plus Art uniform; Sounds switch (their hold applies: only the one-line switch).
3. Ocean floes (Voronoi), edge climb rule.
Protocol: none for 1 to 3. Saves: none. Cost: client per-frame floor lookup only near frozen water.

## Questions for Technical direction
Does the character controller go through a custom floor query (option A) or Godot physics (option B)? Approve the stateless approach? Recommended: yes and yes.
