# Tile-border water (River start thread, 2026-10-21) - DESIGN NOTE, nothing built

## State today
One water sim runs, for the starter tile (3,4) only (`terrain_server`: `water_tile`, one `WaterLive`, one saved `tile_3_4.water`). Each tile file is 1921 x 1921 samples at 8 m, so a tile's last row and column are the first row and column of its neighbour (a shared line of samples, same ground). The sim treats the tile edge as a wall: water cannot leave. Rivers cut by the generator cross tile borders and end in a dry bank at the edge; ponds near a border would pile against it. The draw side already reads a neighbour tile's `sim_levels` when a chunk reaches across (`WaterGrid._level_at`), so it only needs the neighbours to be simulated.

## What must hold
Water ends only at the ocean; rivers keep running over a border; a lake on a border is one level; the 50 percent core cap holds; saved water per tile; no seam in the picture.

## Options
- **A. One-way border flux (RECOMMENDED first stage).** Rivers and outflows cross a border downhill, so one direction per crossing. Each tile sim exports, per border cell, the discharge leaving it toward the neighbour (it already computes the flux it blocks at the wall); the neighbour adds it as a spring at the matching shared-row cell, and runs. Each tile has its own `.water` file as now. A tile's first load with no neighbour data yet starts dry like today. Cost: a few springs per border, nothing else.
- **B. Ghost rows (full coupling).** Neighbouring sims exchange the shared row's depth and ground every publish (copy the neighbour's row next to the edge as a ghost, flux computed against it, mass moved both ways). Needed only for a lake that straddles a border; costs coordination every tick and a lock-step schedule. Second stage, only if one of the nine starter tiles has such a lake (a check script over the generator's ponds says; I expect none, ponds are placed inside tiles).
- **C. One big sparse global sim.** Loads active 64 x 64 blocks around water everywhere. Cleanest, biggest change (new core), no.

## Scheduling and cost
One water thread steps the active tiles round robin inside the same 50 percent duty (33 percent in a storm), so nine tiles cost the same CPU as one when only a few cells are wet; the cost report (WATER_COST_REPORT.md) gives the per-tick numbers. Order the tiles upstream first (high ground to the sea) so an exported flux arrives the same tick. Memory: only a tile with wet cells keeps its depth array (a tile that is all dry or all sea is never loaded).

## Order
1. Border check script: where do rivers cross borders in the nine tiles and is any pond on one (report).
2. Export/import flux and the neighbour springs; one thread, round robin; the server creates a `WaterLive` state per tile with water.
3. Neighbours' `sim_levels` published to clients (water chunks across the border; protocol: none, chunk water bytes already per chunk).
4. Ghost rows only if the check in 1 finds a straddling lake.
Needs: a re-bake is NOT required (the ground is shared already); a build number each for 2 and 3.

## Questions for Technical direction
Approve A first? Is a single round-robin water thread acceptable (one thread, one cap) instead of one thread per tile?


## Stage A built (River start thread, 2026-10-21, build 393)

What was built, as approved:
- `src/water/water_hub.gd`: ONE water thread steps every active tile in turn (always the tile furthest behind in simulated time), under the same duty cap (CPU_DUTY 0.5, storm 0.33). `WaterLive` is now a per-tile object the hub drives (`begin`, `tick`), no thread of its own.
- Border water: at the cells where a river or lake meets a shared border line (plus 3 cells either side) the two tiles' depths are drawn level after each tick, water moving from the higher surface to the lower, never faster than the sim's speed ceiling (12 m/s x face depth). Depth moves between equal cells, so volume is exactly conserved and the tiles' time steps need not match. No flux estimate, no springs, no ghost rows (the border check found only river crossings, no ponds on any border). Sea cells are left alone. A tile that receives water is woken for 600 s.
- Active set: the centre tile plus the neighbours a crossing leads into, most crossing cells first, at most 3 (starter: (3,4), (4,4), (3,5)). `set_centre(tile)` moves it; tiles not wanted are saved to `water/tile_X_Z.water` (versioned file, water_store.gd) and dropped; they reload from it this session. Water memory limit 1.2 GB measured as growth of process memory since the hub started; the least recently stepped neighbour goes first. A session starts dry, no neighbour data, as before.
- No protocol change: the server fills each tile's `sim_levels` and the clients already draw neighbours from them.

Measured (cloud, headless, dry start, x10): three tiles loaded = about 375 MB of water memory (starter alone 333 MB), peak process 711 MB; moving the centre to (4,4) loaded (4,5) with the heavy tile at 882 MB process (about 420 MB of water memory). Water crosses the borders at about 60 m3/s once the rivers run (192,000 m3 in the first 3270 simulated seconds), starter volume grows as before and (4,4) holds a steady 72,000 m3 as it drains to the sea. CPU: three tiles share the one duty cap, so each tile advances slower than when it had the core alone; the lagging-tile rule keeps them in step.
- Tests: `test_water_hub.gd` (border cells found, conservation, levelling, speed ceiling, sea left alone).

Not done (stage B): flux from rivers that cross a border far from any player, player on other tiles swimming (the server only reads water on loaded tiles), tile-border water for digs across a border.
