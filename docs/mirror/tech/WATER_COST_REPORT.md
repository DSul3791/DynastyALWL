# Water thread cost report (River start thread, 2026-10-21)

Measured in the cloud (one core of a shared server CPU, native C++ water core, starter tile 3,4 with 46 springs, headless sim stepping the same `WaterSim.step` the water thread runs, `level_map` every 15 ticks as the publish does). A real PC core is faster or slower, so read the ratios, not the milliseconds.

| Case (first 10 min from a dry start, the worst growth phase) | ms per tick | sim time per wall time at 100 percent of a core | at the 50 percent cap | active cells (peak) |
|---|---|---|---|---|
| x10 flow (default) | 5.6 | 92x | 46x | 39,062 |
| x20 flow (storm) | 21.6 | 22x | 11x | 72,531 |
| x20 plus 5 digs and 3 fills mid-run | 32.4 | 14.5x | 7x | 82,956 |

Reading: the water thread never needs more than one core in full, and under its cap (50 percent, 33 percent in a storm) it still runs 7 to 46 times faster than the game clock needs (the sim only has to keep up with real time, 1x). The cap holds: the thread sleeps in proportion to the work it did (`CPU_DUTY` in water_live.gd). The slowest case is a storm at x20 while a player digs and fills, 7x real time at the cap.

Ice: no cost in the water thread (ice is draw side and a pure function of the clock; the colliders are built on the client when a chunk's water arrives, one collider per chunk, rebuilt only when the ice crosses 10 cm or the chunk's water moves). Ocean floes: client only, about 50 colliders within 160 m at a full pack.
Digs and fills: a dig or fill costs one pass over the few 8 m squares it touches in the water thread; the table row above has 8 of them in the middle of a storm.
Replay at start: all saved edits are queued as the thread starts; each is a handful of squares.

Not measured here: the steady state after an hour (the active cells stay at or below the peak above), and a 1050-class PC (Dave's table). Asked of Dave when a build with the water HUD line is on his machine.

## Update (Sonny, 2026-10-21)
- Tile-border hub (build 393): three tiles on one water thread, about 375 MB of water memory for 3 tiles (limit 1.2 GB), about 60 m3/s crossing the border once rivers run; the 50 percent duty cap is shared, so each tile steps slower than a tile alone.
- Pond still-water mask (builds 425-427, server side, per 33 x 33 water chunk): about 12 ms in GDScript for a chunk that is almost all lake (worst case), once per chunk (it was twice in 425); chunks without ponds are cheaper. Candidate saving if it ever shows: reuse the 7 x 7 window sums with a running sum (about 5x less).
- Pond spring at 1x versus 10x: the pond surface is equally calm in the sim (1-2 cm); the shore ring that looked like moving water was drawn from the rim's tilt, not from the flow rate.

## Update (Sonny, 2026-10-22): four live tiles
Hub with 4 live tiles (3,4 4,4 3,5 4,5, dry start, x10 flow, springs filling, cloud core, thread duty cap as in the server): in 20 s of wall time each tile simulated about 336 s, i.e. about 17x game time per tile (all four together 67 sim-seconds per wall second), where 1x is all that is needed. Water memory 708 MB after 20 s, peak 985 MB in the 6-phase soak walking 8 tiles (limit 1.2 GB, about 240 MB per live tile). Drawn river smoothing at 4 passes costs about +8 ms per 256 m water chunk build (62 to 70 ms). Save error when a tile sleeps: 0.003 to 0.03 percent of its volume.
