# Autoload: loading a container from the ground

**Status: built from Dave's own words (19 Nov 2026); the choices marked AL- are provisional, assumed on his behalf for his review.**

## Dave's words
- 19 Nov 2026 22:14Z: "it would be cool if we had an autoload button on carts and wagons or barrels and such where you could push the button and it could show you everything on the ground around you within say 30 meters in a list where you could choose an item and it would just pick up as much of it as it can until it fills the capacity or the weight limit onto the card or into the barrel."
- 22:15Z: "this could work on crates and boxes too. would be cool to be able to set an autoload on a container that could just always pick up items of the chosen type from time to time off the ground."
- 22:16Z: "maybe just have autoload with a check box beside it to make it continuously autoload every 10 minutes or something"

## How it works
- The container window has an **Autoload** button and an **Every 10 min** check box beside it. Autoload lists each item lying loose on the ground within 30 m of the container that the container takes, with the total there and the nearest pile's distance. Picking one loads as much as fits, nearest piles first; a pile is taken in part when only part fits (a very large pile is one record).
- Limits: a container's slots; a vehicle's payload (`max_kg`: Handcart, Small log sled, Small wagon, and a crate riding on one). Storage has no weight limit (Dave 19 Nov 2026). A container's own rules apply (a rack takes only its items; a barrel holding water takes no goods).
- Ticked, the container also keeps loading that item every 10 minutes (`server_items.gd` `AUTOLOAD_EVERY_S`, 600 real seconds), saved with the container. Full, it loads nothing and keeps the setting. Unticked, it stops.
- Which containers: `StoreRules.autoloads` (chests, crates, barrels, shelves, racks, bins, the vehicles). Not fires, kilns, smelters, chopping blocks, station stores, serving platters, fish traps or remains.
- Server cost: one request per press (at most 4 a second per player) looks only at the world sync's grid cells round the container; the 10 minute round makes one pass over the records. Protocol 139: `ACT_AUTOLOAD` 84, `autoload_info`; world_items structure row index 22.

## For Dave (provisional)
- AL-1: the 30 m is measured from the container (the player stands within 4 m of it to press).
- AL-2: one item per standing autoload; a one-off load of another item ends it.
- AL-3: loading is instant, no time cost.
- AL-4: anyone who may open the container may use Autoload and set or stop its standing autoload; the standing autoload also picks up other players' drops in range.
- AL-5: what Autoload gathers does not count toward goals (a pickup of natural stones and sticks does).
