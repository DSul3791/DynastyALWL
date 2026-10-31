# Recipe learning: rule and code spec (Sal, 2026-10-31, fixes F-01)

## Decision (data half, done)
Nothing a first-day player needs is locked. Rule: a recipe is `known: true` from the start unless it needs a **forge level 2 or more** or a **workbench level 2 or more** (or is the water wheel). Those stay `known: false` until the learn system exists. 76 recipes were switched to known. The gate for everything else is the ingredients and the station, not a hidden unlock. `open_recipes.json` is left as it is (now redundant).

Still `known: false` (19): plank chest kit, steel pickaxe, water wheel, bronze ingot, smelt steel, bronze/iron/steel sword, mace, shield, bronze/iron/steel helm, mail shirt, plate cuirass.

Until the code below exists, nothing past forge 2 can be crafted. That is on purpose: forge 2 and 3 are not buildable yet either.

## Code half (for the code session)
Server (src/stream/server_items.gd, `_queue_craft` refuses `known == false`). Add a per-player set of learned recipe numbers, saved with the player:
1. **Learn by seeing:** the first time the item a recipe makes is in the player's pack, or the player stands at the station it needs, the recipe becomes known (no popup spam: one line "You work out how to make X").
2. **Learn by discovery:** the first time a player holds all the ingredients of an unknown recipe at its station, it is learned.
3. **Learn by skill:** optional `learn_skill: [skill, level]` field on a recipe; known when the skill reaches the level.
4. `open_recipes.json` stays as the always-open list.
Save compatibility: old saves have no learned set; treat every `known:true` as known and start the set empty. Tests: test_server_items (refuse until learned, accept after), save_compat (round trip).
