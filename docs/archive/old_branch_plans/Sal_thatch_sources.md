# Sal: more ways to get thatch (short plan; Dave 15:20 UTC 24 Oct)
STATUS: APPROVED by Dave 15:30 UTC (thatch should be everywhere: grass clump patches in all grassy areas, bark of felled trees is thatch, more biome sources added later). Build after the devstop. Queue note: branch claude/sal-thatch-sources is plan only until GO.
Goal: thatch must not come only from reeds. Add bark from felled trees, a special thatching grass that grows in patches and can be picked, keep reeds, tall grass and heather. Reachability of the first 50 thatch is checked when the spawn point is chosen, not by placing plants near spawn.

## Today (generator-v2)
- Thatch is an item (gathered.json 1146) but nothing gives it. flora.json lists it as a yield name on reeds (marsh, mangrove only), tall_grass (grassland, savanna, alpine meadow, heath, beach) and heather, with no count (drops.json harvest_yield has no thatch row).
- Around spawn (53301, 68427; mixed and temperate forest): 0 reeds, 0 tall grass, 0 heather within 300 m; nearest reeds 615 m. Within 1 km: reeds 4,210, heather 4,068, tall grass 1,105.
- Felling already drops bark: drops.json trunk bark_chance 0.3, item "bark" (server_items.gd ~3421), not thatch.
- Plants are harvested by E: drops.json harvest_yield (item x count, scaled 1 to 3 by patch scale, stays bare until next season).

## Sources and yields (all numbers are table rows)
| source | where | yield per pick | notes |
|---|---|---|---|
| **Thatching grass (new plant `thatch_grass`)** | patches of 10 to 20, scale 1 to 3, in mixed and temperate forest clearings, meadow and heath edges, moisture 80 to 200, slope under 20 deg | 10 thatch (x scale), spring to autumn, bare till next season | pickable; 5 plants fill a 50-thatch wall |
| **Bark of felled trees** | birch, spruce, balsam fir, Scots pine (spawn has balsam fir 567, birch 247 within 300 m) | trunk roll: birch 50% for 3 to 5 thatch, spruce/fir/pine 30% for 2 to 4 | each log cut rolls once; replaces the plain bark drop for those species |
| Reeds | marsh, lake and river banks | 8 thatch (x scale), all year | unchanged places, now with a number |
| Tall grass | grassland, heath, beach | 4 thatch | |
| Heather | heath, summer and autumn | 4 thatch | |
Placement (Dave 15:47 UTC: nothing is placed because it is close to spawn): thatching grass is placed by grassy biome only, about 0.02 patches per hectare in the allowed areas (about 6 patches in a 1 km circle), with no spawn guarantee. Later, once the world is settled, the spawn point is chosen near the needed resources (including thatch) instead. Bark gives a new player thatch from the first birch or spruce felled wherever they stand.

## Changes
- data/tables/flora.json: new entry thatch_grass (kind plant, model grass_tuft taller, golden-green, patch fields like berry plants, yields ["thatch"]); VERSION in flora_layout.gd bumped to 5 (plants move, the removed-plant marks clear).
- data/items/drops.json: harvest_yield rows for thatch_grass 10, reeds 8, tall_grass 4, heather 4; trunk gets `thatch_bark` per species (chance, min, max).
- src/stream/server_items.gd (trunk roll ~3421): species lookup in thatch_bark, gives thatch instead of bark.
- Validator: every harvest_yield item exists and is gatherable; thatch_grass must have a model and a look. Tests: harvest gives 10 x scale and leaves the plant bare, birch trunk can give thatch, spawn patch exists within 300 m on the nine tiles (counts script).
- Art: Kathleen gets a request for a thatch_grass model (placeholder is the grass tuft taller, tinted).
- Labels: RESTART (flora version, data). No protocol change.

## Not in this plan
Thatch recipes (basic wall 50, rough bed) are a separate plan.

## Flag: spawn-radius extras to drop later (Dave 15:47 UTC)
data/items/drops.json ground_scatter.spawn_boost (radius 300 m: +1 to 2 stones and +2 to 3 sticks per cell, added for the "campfire friction fix") and its use in server_items.gd `_scatter` place stones and sticks because they are near spawn. Dave's rule says nothing is placed for being near spawn; when the world is settled and the spawn point is picked near the resources, remove spawn_boost (data row plus the code branch). Not touched in this plan.
