# The 2 m region round the player: why it was removed, and what a repaired one needs (Sonny, 10 Nov 2026)

Parked until after Dave's playtest. The coordinator decided on 10 Nov: water Dave can see working beats a 2 m sim he cannot see for the flicker. The 2 m sim stays where players dig (`src/sullivan_water/live/dig_windows.gd`); the region that followed the player (`docs/water/follow_players_2m.md`, #514, 7 Nov) is gone.

## What Dave saw (build 826, tile 3,4)

Dave reported five spots near the player. The follow region was the only part of the water that changed with where the player stood. Dave's playtest log (`playtest_water_log_9nov.txt`, Dino's extract) confirms it for three of them. Two remain open: spots 1 and 5 lie on z 69888, and that line was outside the region round Dave at the time.

| spot | what Dave saw | why |
|---|---|---|
| x 55113 z 69892, heading 274 | a lake "flowing two ways": a straight seam, dark calm water on one side and light foamy water on the other | **open.** The seam runs along z 69888, 4 m to his right and along his view. At the time, the region round him was tiles 574,727 (x 55104 to 55296, z 69792 to 69984), so z 69888 ran through its middle, not along its edge. z 69888 is also a 256 m flora chunk line. The chunk sheets reckon lakes (`water_grid.gd` `_flatten_lakes`) and still water (`_still_levels`) one chunk at a time. Both chunks along the seam had the region's 2 m levels in their east part, but whether the seam needs them is not known. The picture after this fix will tell. |
| x 55046 to 55048 z 70204 | a spring brook ran past him, then vanished while he stood still, and its sounds stopped | **confirmed.** A region opened round him: tiles 572,730, at x 54912 z 70080, "0 m3 of water (0 copied, 0 from the 8 m levels), 0 border cells held". No 2 m cell lay under the brook's 8 m surface, so the region started dry. At its first publish it wrote NaN over every 8 m sample in its 192 m square, brook included, and the sounds read those levels. A region that seeds water would still drain a spring brook, because it has no springs. |
| x 55174 z 70197, heading 256 | a river stopping at a hard edge; then all the water gone for about a second, then back | **confirmed.** As he walked between x 55045 and 55169, regions 574,730 (1,544 m3) and 572,730 (0 m3) were each built twice, and each build closed the other. The 8 m sheets step aside over a region's whole square whether or not its 2 m sheet draws water there, so its thin or dry stretches show nothing, with straight edges. |
| x 55443 z 70169, heading 289 | the upper river fuller, the lower thin, then it filled in ("the LOD still loading") | **confirmed in part.** Region 577,730 opened round him with only 472 m3 and 9 border cells: thin 2 m water inside it, full 8 m water outside. It took 7,299 ms to build, reading 354 blocks of ground. When a region closes, the chunk water the client holds there is still the region's until its next re-ask, 3 to 12 s later. Whether the builds also slowed the ground LOD is not measured. |
| x 55934 z 69911, heading 001 | a big stretch of stream invisible, with water far upstream and below him, and the brook sound faint | **open.** The region round him was tiles 582,728 (z 69888 to 70080, 1,330 m3), which is the water below him. The missing stretch lies ahead, north of z 69888, in a chunk that no region in the log touched. It may be a gap in the baked water, or chunk water not yet arrived. The picture after this fix will tell. |

## Measured from the playtest log (9 Nov, 22:16 log)
- 51 follow opens. 32 were refused because the join would pass the 4-tile budget: 23 "6 tiles needed" and 9 "9 tiles needed". 14 regions closed for the budget.
- Each region build read 300 to 761 blocks of ground and took 1.7 to 11.3 s (largest 11,266 ms). The water thread did nothing else meanwhile.
- Several regions round the player seeded 0 m3. They opened because some 8 m water lay somewhere in their four tiles, then blanked every 8 m sample in the square.

## How it went wrong (from the code)

1. **No springs.** The 8 m field feeds every headwater cell the inflow its outflow needs (`water_field.gd` `hold_steady`), so baked brooks keep running. The 2 m region was seeded from the 8 m levels, with its wet border cells held at the 8 m level. Nothing fed a head inside it, so a spring brook drained.
2. **Thin water dropped.** 2 m water under 5 cm is not drawn, and under 12 cm it gives no 8 m level. A region seeds only the 2 m cells whose bed lies under the 8 m surface. So a shallow brook could start thin and go to nothing.
3. **The 8 m sheets stepped aside over the whole square.** In the 8 m live window, the chunk sheets give way only where the live sheet draws water (Dave, 4 Nov: "a dry sim hid a baked river"). The fine holes had no such check.
4. **One region's levels replaced the 8 m water.** `publish()` wrote the region's 2 m means over the hub's 8 m levels, NaN where thin. Footsteps, swimming, sounds and the chunk sheets all read those levels.
5. **It stuck behind the player.** Near a region's edge (24 m), the new 2 x 2 square round the player overlaps the old one. Joining them needs 6 tiles, over the 4-tile budget, so the open is refused every 10 s. The player walks out of the region, and its edge lies beside them. Only once they are 48 m past it does a new region open and the old one close.
6. **The edge draws two systems.** Inside: the 2 m grid's own current and the fine sheet's look. Outside: the 8 m flow on the chunk or live sheets. The 6 m blend between them softens the line, but it cannot make two currents into one.

## What a repaired one needs (all six, before it comes back)

1. **Springs from the 8 m reckoning.** When a region opens, run `hold_steady` on the 8 m cells under it (plus a one-cell margin) and give each headwater's inflow, in m³/s, to the lowest open 2 m cell under that sample. Then a spring brook carries the 8 m discharge, not its own.
2. **A two-way border.** The region's border must trade water with the 8 m field both ways, by face fluxes on the shared border, not by holding the border cells at a fixed level. A held level drives a current through still lakes. This is M4's open item (guide 26.2, the FROZEN_CLOSED dry border).
3. **Draw only where it has water.** The 8 m sheets step aside inside a fine hole only where the fine sheet draws water: a fine-sheet cover, like `live_cover` for the live window. And a region nobody dug in must not overwrite the 8 m levels where its own water is thinner than the 8 m water.
4. **No sticking.** A follow region moves with the player: it closes or shrinks before the new square opens, so the join never passes the budget. The fine hole is never set before the new fine sheet has drawn.
5. **One look across the edge.** The same water at 2 m and at 8 m must draw the same colour, foam and current where the two sheets blend.
6. **Measured first, on the PC (Dino).** Stand at each of the five spots above for 2 minutes. Pass: no water lost, and no seam where the old and the new water meet. A picture at each spot, with the regions' log lines.

## Removed (git history keeps them)
- `dig_windows.gd`: `follow()`, `_wet_in()`, `FOLLOW_EDGE_M`, `FOLLOW_EVERY_MS`, the `followed` count, the "dug" mark, and the rule that a region nobody dug in closes instead of sleeping. With no follow region, every region is a dug one.
- `water_hub2.gd`: `set_players()` and its call to `follow()`.
- `terrain_server.gd`: the player positions it gave the hub every 2 s.
