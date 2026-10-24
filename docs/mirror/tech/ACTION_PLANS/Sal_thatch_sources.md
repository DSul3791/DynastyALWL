# Sal: more ways to get thatch (short plan; Dave 15:20 UTC 24 Oct)
Goal: thatch must not come only from reeds. Add bark from felled trees, a special thatching grass that grows in patches and can be picked, keep reeds, tall grass and heather. A first shelter's 50 thatch must be reachable near spawn.

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
Spawn guarantee: one thatching-grass patch within 300 m of the respawn point (a small `spawn_patches` row in the flora placer, seeded from the respawn position), plus about 0.02 patches per hectare in the allowed biomes (about 6 patches in a 1 km circle) so later areas are not bare. Bark alone gives a new player thatch within minutes of felling the first spruce or birch.

## Changes
- data/tables/flora.json: new entry thatch_grass (kind plant, model grass_tuft taller, golden-green, patch fields like berry plants, yields ["thatch"]); VERSION in flora_layout.gd bumped to 5 (plants move, the removed-plant marks clear).
- data/items/drops.json: harvest_yield rows for thatch_grass 10, reeds 8, tall_grass 4, heather 4; trunk gets `thatch_bark` per species (chance, min, max).
- src/stream/server_items.gd (trunk roll ~3421): species lookup in thatch_bark, gives thatch instead of bark; flora placer: spawn_patches rule.
- Validator: every harvest_yield item exists and is gatherable; thatch_grass must have a model and a look. Tests: harvest gives 10 x scale and leaves the plant bare, birch trunk can give thatch, spawn patch exists within 300 m on the nine tiles (counts script).
- Art: Kathleen gets a request for a thatch_grass model (placeholder is the grass tuft taller, tinted).
- Labels: RESTART (flora version, data). No protocol change.

## Not in this plan
Thatch recipes (basic wall 50, rough bed) are a separate plan.
