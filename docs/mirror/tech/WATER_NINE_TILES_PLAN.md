# Water sim over all nine starter tiles - PLAN ONLY (Sonny, 2026-10-21), for Steve

## Where we are (correction to my earlier line)
The water hub (src/water/water_hub.gd, build 393) already runs several tiles on ONE water thread with border coupling (tested: volume conserved across a border, both sides level within 5 cm, sea never coupled). The cost report measured 3 tiles. Going to 9 is a scaling and lifecycle question, not a new design. Border data in the baked tiles is clean (all compared borders: class and surface differ 0 m, river crossings 0 to 4 per border, 0 unmatched).

## Cost
Measured per tile (starter tile, x10 flow, from dry): 5.6 ms per tick at ramp-up; a fully active settle averages about 14 ms per tick (about 100,000 active cells). x20 storm 21.6 ms. Memory about 125 MB per tile in water arrays (375 MB for 3, limit 1.2 GB).
Naive 9 tiles all active: about 50 ms/tick at x10 (9 x 5.6), 125 ms/tick fully wet (9 x 14), about 195 ms in a storm (9 x 21.6). The thread is capped at 50 percent of a core (33 in a storm), so it falls behind real time at x10 in storm and at full wet; memory about 1.1 GB, right at the limit. So: do not run nine tiles flat out.

## Options
A. Sim only tiles within range of a player (tile of each player plus any neighbour within ~1000 m of the player). Others sleep. 1 to 4 tiles live for a few players. Cost proportional to players, not world size.
B. Sleep settled tiles: a tile whose active cell count and moved volume per tick fall under a threshold for N seconds drops to a cheap check (only springs and rain input are watched) and wakes on a dig, a border inflow, a weather change or a player arriving. Most tiles are mostly settled river and lake.
C. Lower rate far away: step a tile every 2nd to 4th tick when no player is within 2 km (water speed ceiling keeps it stable; coupling moves per publish already).
D. Second water thread: only if A to C are not enough; costs locking on hub borders. Not recommended first.

## Borders while tiles load and unload
- A tile entering the live set loads its saved .water file, replays the dig log (edits), then couples to neighbours that are live. A neighbour that is NOT live is treated as a fixed boundary at its saved water: inflow at a border from a sleeping neighbour is replayed from its saved river discharge (the same spring rule the single tile uses), outflow into it is dropped but counted (mass log), and is credited when it wakes.
- Unload: save the tile's .water, then drop its arrays. Never unload while a river crossing has non-zero flux: finish the tick, save, then unload.
- Order tiles upstream first (high ground to sea) each tick so flux crosses in the same tick.

## What must be saved
Per tile: the .water depth file (already exists for 3,4; the settle tool makes them) written on unload and every few minutes with the existing autosave off the tick thread; the dig log (already global with replay); the per-tile border flux ledger (small, a few floats per crossing) so water in flight at unload is not lost. Not saved: ice, floes, weather swell (pure functions of the clock).
Settled .water files for all nine tiles are needed after the bake (settle_water.gd per tile, about 10 s each headless, 9 files about 2 to 3 MB each); I run these after Dave's bake, as generated data pushed separately from the tiles.

## Recommendation
Do A plus B first (live set near players, settled tiles sleep): cost then tracks active water, expected 1 to 3 tiles worth (6 to 40 ms/tick, inside the 50 percent cap), memory under 400 MB. Add C only if the water HUD line shows the thread over its cap with more players. Keep one thread. Build order: (1) settle files for the nine tiles after the bake; (2) live-set manager (load/unload with player tile, save on unload); (3) sleep/wake rule with the border ledger; (4) a 9-tile headless soak with 3 simulated players moving between tiles, checking total volume (springs in minus sea out minus stored) stays within 0.1 percent. Needs no re-bake and no protocol change; one build number each. Question for Steve: approve A plus B and the one-thread rule?
