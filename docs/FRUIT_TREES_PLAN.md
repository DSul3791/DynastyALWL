# Fruit trees with a real fruit store (flora session, 2026-10-31; plan, nothing built yet)

Dave's spec (via the moderator): pick the fruit from the tree by pressing E, as many as the pack carries, come back until the tree is empty; the store is
server state shared by all players; the drawn fruit thins out with the store; out of season there is no fruit and no prompt; the store refills when the
next fruiting season starts; a variety of apples over the year and other fruit by climate.

## What exists today (checked in the code)
- `data/items/drops.json harvest_yield` gives `wild_apple` crab_apples x120, `wild_pear`, `wild_cherry` 200, `walnut` 80, `sweet_chestnut`, `rowan`, `hazel`, date and coconut
  palms, banana: all-or-nothing per plant: one E hands out the whole product and the plant is "stripped" until the next season (`server_items._gather_berries`,
  `GatherRules.harvest_row/harvest_count`, client `harvest.gd`, `flora_view` stripped set and the seasonal fruit models in `tree_builder._wild_apple(..., season, stripped)`).
- The client prompt code skips trees (`harvest.gd _candidates`: `if kind == 0: continue`), so fruit on a tree cannot be picked from the client today; the apple fruit in the model
  is drawn per season (ripe or bare), not per count.
- The in-season rule (this branch, 888236ac): `GatherRules.in_season`, no prompt out of season, server refuses quietly.
- Items: `crab_apples`, `cherries`, `walnuts` exist in gathered.json; `apples`, `pears`, `plums`, `quinces`, `medlars`, `figs`, `olives` do not (Sal).

## Design (data-driven, one row per variety)
1. **flora.json** fruit tree rows get `"fruit": {"item": "apples", "max": [40, 120], "per_pick": 5, "season": ["summer"], "shelf_days": 20}`; a variety is one row with
   the shared apple model (`"model": "wild_apple"`) and a fruit colour (`"fruit_color": [r, g, b]`, read by `tree_builder._wild_apple`).
2. **Server store** (`server_items.gd`, Tyler's file): `_fruit[flora_key] = {"epoch": year*4+season, "left": n}`. Initial `n` = `max` scaled by the tree's height against the species
   reference and a stable variance from the tree id; a new epoch (the fruiting season comes round again) refills to the maximum; trees picked bare stay bare until then. Saved
   with the other harvest state (the `_picked` / stripped overlay). A press takes `min(per_pick, left, what the weight limit allows)`; if the pack is full the reply is "Too heavy to carry more".
3. **Client**: trees with a `fruit` block join the prompt candidates; the server sends the count of fruit left per tree in view (a small delta message next to the stripped set); the prompt
   is "Press E to pick apples (63 left)", hidden at 0 or out of season.
4. **Drawn fruit** (Kathleen, `tree_builder.gd`): the fruit clusters of the apple model are built as separate beads; the view draws 100 / 66 / 33 / 10 / 0 percent of them from the
   fruit-left share (one extra shader parameter per tree or four model variants per species, whichever she prefers: variants fit the existing seasonal model cache).
5. **Calendar**: one table, `data/look/seasons.json` `fruit` block, mirrored into Sal's `data/items/seasons.json`; the in-season rule reads `flora.json` season, which is generated from it.
6. **Varieties and climate** (rows only, no new models; list for Kathleen: fruit-colour variants and fig, olive, pomegranate, mango, citrus trees): apple early summer / late summer / autumn / keeping
   (winter) / cooking / crab; pear x3, cherry sweet and sour, plum and damson, quince, medlar; nuts walnut, chestnut, hazel; boreal crab apple, rowan, sea buckthorn; dry fig, olive, pomegranate, date;
   tropical banana, coconut, mango, papaya. Each with its biomes (`per_hectare`), altitude, moisture, season, store range.

## Tests to write with it
Pick until the weight limit; come back and pick the rest; an empty tree gives nothing and shows no prompt; the season gate; save and load of the store; refill at the next season; client prompt and server gather agree.

## Order of work and who
Server store + gather + tests (flora session with Tyler), items and spoilage (Sal), fruit beads and counts on the model (Kathleen), then varieties as data.
