# Gather from water and shore: code spec for Tyler (Sal, 2026-10-31; needed for Sea salt, buckets, crops)

## Why
The game has drinking at the water's edge (vitals.json `drink_ml`) and an item `water` ("plain water, gathered in a container"), but no action that fills a container, takes things from the tide line, or boils sea water. Blocked: **Sea salt**, watered crop beds, the Clay jug and Bucket having any job, shellfish, seaweed, crab meat and seabird eggs (items 355 to 363 exist, nothing gives them).

## One action: ACT_GATHER_WATER_EDGE (E on water or shore, like drinking)
1. **Fill a container:** with a Bucket, Clay jug or Waterskin in the pack, E at the water edge fills it: `water` x1 per container (a bucket holds 8 L, jug 2 L, skin 1.5 L). Fresh vs sea water is by the water kind already known to the fish code (server_fish_water.gd): sea water gives `sea_water` (new item, same stack rules).
2. **Tide-line nodes:** deterministic nodes on beach cells (hash of cell and game day, like fish schools; data table `data/items/shore_nodes.json`, to be written by the code owner): kelp patch gives `seaweed` 2 to 5, mussel bed gives `shellfish` 3 to 8 (knife not needed), rock-pool crabs give `crab_meat` 1 to 2 (only at night or low tide), seabird nest gives `egg` 1 to 3 (only in nesting season, scares the colony). Each node refills after one game day.
3. **Sea salt:** recipe at a Campfire pot: `sea_water` x2 gives `sea_salt` x1, 20 s (boil off). Add `sea_water` as an item and the recipe in data once the action exists.

## Files and tests
src/stream/server_items.gd (new action number in src/shared/net.gd, `_gather_edge`), server_fish_water.gd (water kind), inventory (container fill), data: items.json (`sea_water`), recipes.json (sea salt), shore_nodes.json. Tests: test_server_items (fill bucket, refuse without a container, node refills after a day), save_compat (nodes are not saved, derived from the hash).
Real-world basis: salt by boiling or evaporating sea water is the standard early method; mussels, limpets, kelp and bird eggs are classic shore foods (general knowledge, not individually sourced).
