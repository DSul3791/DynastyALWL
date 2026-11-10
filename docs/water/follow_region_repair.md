# The 2 m region round the player: why it was removed, and what a repaired one needs (Sonny, 10 Nov 2026)

Parked until after Dave's playtest. The coordinator decided on 10 Nov: water Dave can see working beats a 2 m sim he cannot see for the flicker. The 2 m sim stays where players dig (`src/sullivan_water/live/dig_windows.gd`); the region that followed the player (`docs/water/follow_players_2m.md`, #514, 7 Nov) is gone.

## What Dave saw (build 826, tile 3,4)

All five spots are within a few metres of the player. The follow region was the only part of the water that changed with where the player stood.

| spot | what Dave saw | why |
|---|---|---|
| x 55113 z 69892, heading 274 | a lake "flowing two ways": a straight seam, dark calm water on one side and light foamy water on the other | the edge of a follow region. The seam runs along the 96 m lattice line z 69888, 4 m to his right and along his view. Inside the region the current comes from its held border levels, which need not be level round a lake, not from the 8 m flow. The light foamy side fits the region's own current; which side was the region is not confirmed in a log. |
| x 55046 to 55048 z 70204 | a spring brook ran past him, then vanished while he stood still, and its sounds stopped | the region opened round him. It has no springs, so the brook's head inside it drained. Its 8 m levels then went NaN (fewer than 4 of 16 cells at 12 cm), and the sounds read those levels. |
| x 55174 z 70197, heading 256 | a river stopping at a hard edge; then all the water gone for about a second, then back | the 8 m sheets step aside over the region's whole square whether or not its 2 m sheet draws water there. A drained or thin stretch shows nothing, and it has straight edges. The second's vanish fits a region closing and a new one opening, but this was not confirmed in a log. |
| x 55443 z 70169, heading 289 | the upper river fuller, the lower thin, then it filled in ("the LOD still loading") | the same: thin 2 m water inside the region, full 8 m water outside. When a region closes, the chunk water the client holds there is the region's (thin or none) until its next re-ask, 3 to 12 s later. |
| x 55934 z 69911, heading 001 | a big stretch of stream invisible, with water far upstream and below him, and the brook sound faint | the region round him, as above. |

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
