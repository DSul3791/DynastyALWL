# 2 m water follows the players (Sullivan water, Sonny, 7 Nov 2026)

**Removed on 10 Nov 2026** after Dave's playtest. It drained spring brooks, hid the 8 m water across its square, and stuck behind the player. Why, and what a repaired one needs: `docs/water/follow_region_repair.md`. The 2 m water now runs only where players dig. What follows is the design as it was.

Design first. This builds on `docs/water/fine_drawing_2m.md`. The goal is that the river a player stands by runs and is drawn on the guide's 2 m grid, not only where they dig. That is what Dave asked for: the riverbed is a neat carved channel down the valley floor, and a 3 m channel needs 2 m cells.

## Cost (measured)
Dino ran `src/sullivan_water/probe_sullivan_water_cost.gd` headless on 7 Nov:
- one 96 m tile (48 x 48 cells): 49 ms per simulated second;
- four tiles (96 x 96 cells): 189 ms per simulated second.

The water thread may use about half a core, so the 4-tile budget fits with room to spare. The whole 1 km window at 2 m would be about 16 times that, so only the ground near players moves to 2 m.

## The rule
1. Every 2 s the server gives the hub the players' positions (`water_hub2.set_players`).
2. On each hub tick, `dig_windows.follow()` checks the first player. It opens the 2 x 2 tiles round them (192 m square) when both of these hold:
   - they are not at least 24 m inside a running region;
   - the hub's 8 m levels show water somewhere in those tiles.

   It opens at most once every 10 s, because each open reads up to 4 tiles of ground. The new region joins any region it touches, through the same `_open` as digs, with exact water copies.
3. A region opened only to follow a player is **not dug**. Under the tile budget it **closes** rather than sleeps. Its river is still in the 8 m field, so closing loses nothing the 8 m water doesn't already hold, and a river must not be frozen in a sleeping copy.
4. A dig inside a followed region makes it dug. From then on it sleeps with its water like any dug region (guide 26.2).

## Limits, labelled
- Only the first player gets a followed region. With 4 tiles in the budget, two players far apart cannot both have one. The first in the server's list wins.
- The hub publishes only its one simulated tile. A player on another tile gets no followed region, because there are no 8 m levels there to start from.
- The 8 m field and a followed region don't trade water back across its border beyond the held wet border cells (guide 26.2 FROZEN_CLOSED on the dry border).

## Check
`test_sullivan_water_live` (David4) checks:
- a player by the river gets a 2 x 2 region that is not dug, starting with the river's water;
- staying inside it opens nothing more;
- dry ground opens nothing;
- under the budget, the region nobody dug in closes rather than sleeps.

In game (Dino): stand by the brook at x 53240 z 68330. The client log shows "2 m water sheet", and the picture shows the brook drawn at 2 m.
