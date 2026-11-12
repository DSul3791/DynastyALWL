# M001-T12 results: phase 6 cooking and preservation

- Branch `m001/p6`, clone `E:\Software\godotDev\m001_p6`, base `f3d0d2ac0`. Code commits: `d552567b1` (data, code, tests), **`cdf5849b2`** (suite fixes; code head). This file is committed on top (docs only). Not pushed.
- Brief: `T12_BRIEF.md`. Master `DYNASTY_MASTER_ITEMS.md` s3.12, s3.14, s4, s7 items 18 and 21; companion `FOOD_PREPARATION_PRESERVATION_SERVING.md` s1, s2, s4, s5.

## What went live
- **Food preparation table** 1202: state 250, blueprint 210 (3 Log, 2 Twine, hammer 1, like the Log - Table: pre-saw, pre-metal), station `food_preparation_table`, reach 3 m. Borrows the plank `table` look.
- **Kept equipment** (pack items in a recipe's `keeps`, like Clay - Pot 40; nothing is used up):
  | Row | Recipe | Used for |
  |---|---|---|
  | Clay - Griddle 1203 | 465 at a campfire, 4 clay | Flatbread, Rye flatbread, Garlic bread, Oat cakes, Chestnut cakes at a plain campfire (no hearth); Crab cakes, Banana fritter, Herb omelette, Egg and nettle fry (their main recipe) |
  | Campfire roasting spit 1204 | 466 by hand, 4 stick, 2 twine | Roast joint at a campfire (else the Oven) |
  | Iron - Grill grate 1205 | 467 Smithy, 2 iron | Sausage at a campfire (else the Campfire pot); Meat and Mushroom skewers two batches per craft |
  | Iron - Frying pan 1206 | 468 Smithy, 2 iron, 1 stick | Meatballs, Crab cakes, Banana fritter, Herb omelette, Egg-nettle fry at a campfire |
  | Iron - Cauldron 1207 | 469 Smithy, 5 iron | seven stews three batches per craft, in twice the cook time, at the Campfire pot |
  Griddle, spit and grate change kind `structure` -> `tool` (Phase 1 placeholder kind; the catalog says kept equipment, not placed pieces). Pan and cauldron stay `container` (no capacity, so no water vessel).
- **Fireplace cooking crane** 1208: state 251, blueprint 211 (3 Iron ingot), `addon_of` fireplace, `attach_to` "fireplace", `attach_m` 2.5. It serves `campfire_pot` only while a lit Fireplace stands within 2.5 m (new branch in `ServerItems.serving_station` and the client `_station_near_now`). Borrows the `tool_rack` look. No blueprint `near` rule (the fireplace has no station id).
- **Sixteen prepared foods** 1209-1224 live. Fifteen dish recipes are rewritten through `dishes.json` + `tools/gen_dishes.py` (new fields `prepared`, `keeps`, `also_cook`, `ready_age`): `prep_<dish>` at the table takes the old ingredients once, `cook_<dish>` takes only the prepared item (same counts and cook time as before). Mushroom skewer moves from the hearth to the campfire; Crab cakes, Banana fritter, Herb omelette and Egg-nettle fry to the griddle or pan (s3.12). **Meatballs 837** live: prep 470, recipe 396 at the Campfire pot without the Copper pot, 471 in the pan; description no longer names the Copper pot.
- **Nut cake 31 and Fruit juice 376** at the Food preparation table, no intermediate.
- **Preservation**: Sauerkraut 271 `ready_age` 48 game h, Pickled vegetables 393 (FUTURE) 72 h. One craft at #830 seals the whole queued count (one timer) at age 0: pack (by carry weight), then the player's own storage in crafting reach (by `max_kg`), then the ground. A Maturing stack is not eaten, sold, counted or taken as an ingredient (pack, chests, ground), and never merges with another age; Ready stacks merge as before. Sealing refuses inputs under half freshness (refunded as they were). Other crafts now give their output the age fraction of the stalest perishable input. Berry compote 102, Apple sauce 283, Plum jam 285, Preserved damsons 287 move to the Campfire pot. Tooltip shows "Maturing, about N h more" or "Ready".
- **Smoked meat** 1241 (Smoker, 472: 2 raw meat + 1 salt -> 1) and **Dried mushrooms** 1242 (Drying rack, 473-476: 3 porcini / chanterelles / morels / puffball -> 1; not in the `mushrooms` group) plus Uncooked mushroom skewers from dried (477: 2 dried, 1 wild garlic, 1 water -> 2).
- `validate_items`: shelf life x gentle_mult must stay under the u16 wear cap (6553.5 h); a ready_age must be under its food's shelf life.

## Numbers chosen (s5 tuning, for playtest)
Prep 4 s per craft. Sauerkraut ready 48 game h (2 real h in a pack; slower in jars, cellars, winter). Smoked meat 1000 kcal, 0.6 kg, 480 h, warms 6 (Jerky 500 kcal, 0.3 kg). Dried mushrooms 200 kcal, 720 h. Shelf lives: doughs 24 h (trail bread 48), apple and venison pie 18, fish pie 12, raw-meat preps 18, mushroom skewers 24, crab cakes and fritter batter 12; Mushrooms 551 36 h, Puffball 24 h. Keeping apple and Pickled vegetables 2160 -> 1638 h (the largest whole value under the wear cap; before, they could never rot). Prepared foods have no food value (raw dough: "You cannot eat that"). Griddle value 4, spit 5, grate 35; weights 2.0 / 1.0 / 3.0 kg. Batch size is the craft count, at most 20 crafts (40 Sauerkraut) per seal (`CRAFT_QUEUE_MAX_COUNT`).

## Numbers used
Structure states 250-251, blueprints 210-211 (`next_number` 212), recipes 430-477 (`next_number` 478; 430-464 written by the generator).

## Files
`data/items/{items,recipes,blueprints,structures,dishes,spoilage,vitals,weights,cooking,look_placeholders}.json`, `src/shared/{item_table,inventory,recipe_table}.gd`, `src/stream/{server_items,server_trade}.gd`, `src/client/inventory_view.gd`, `src/client/ui/inventory/pack_grid.gd`, `src/worldgen/tools/validate_items.gd`, `tools/gen_dishes.py`, `docs/design/catalog_ledger.json`; tests `test_cooking_route.gd` (+ `.uid`, new), `test_dishes.gd`, `test_blueprints.gd` (194 live), `test_hammer_list.gd` (144), `test_item_instances.gd` (Nut cake at a table), `test_economy_guard.gd` (a recipe that is exactly k crafts of another is checked as that one: 7 cauldron recipes skipped, their base stews checked).

## Generator note
`gen_dishes.py` had drifted from the data: run on base it would have reset 28 hand-tuned dish values, dropped every recipe `category` and moved six stews off the Campfire pot. It now keeps an existing dish's `value` and `category`, and `dishes.json` was synced to the live stations and two descriptions first, so it is a semantic no-op on base. Its output was ported into the repo files entry by entry (the script rewrites whole files with its own formatting); a check confirmed the repo data equals the generator's output.

## Looks (NOT visually complete)
All 18 new foods keep the grey placeholder; the table and crane borrow looks; the five equipment rows have no looks.json row. All listed in `look_placeholders.json`.

## Evidence (Dave's PC, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`)
- `python3 tools/tests_for_diff.py f3d0d2ac0 HEAD` at `d552567b1`: 216 tests (212 fast, 4 timing), **214 PASS, 2 FAIL**: `test_economy_guard` (four cauldron stews over the per-craft cap, the spit losing money) and `test_item_instances` (its Nut cake refund check crafted by hand). Both fixed in `cdf5849b2`.
- Same plan at **`cdf5849b2`**: **216 PASS, 0 FAIL** (wall 7 min, 3 jobs). The known flakes (`test_flora_density`, `test_npc_view`) are not in this plan.
- At the `cdf5849b2` content: `validate_items` PASS, 0 errors, 144 warnings (base count not measured); `test_cooking_route` PASS (all 75 checks), `test_dishes`, `test_item_looks`, `test_economy_guard`, `test_item_instances` PASS.
- `test_cooking_route` asserts on real server state: table and hearth built from their blueprints; dough at the table, bread at the hearth with no flour charged again; half-fresh dough gives half-fresh bread; a griddle made and used at a campfire; a fish roasted without the table; a Frying pan made at a fired Smithy and an omelette fried with it; the crane cooks only while its fireplace burns; 10 Sauerkraut sealed as one stack, not eaten or counted while Maturing, eaten when Ready; a later batch stays separate and will not join a Ready stack, both join once Ready; 30 percent fresh cabbage refused and returned; age and count survive save and load; a full pack sends a batch into the player's chest, a full chest to the ground, none lost; Smoked meat and the four Dried mushrooms at their built stations.
- `python3 -I tools/merge_check.py`: all clear (one carry-audit warning, recipe 153 water wheel, present at base). `python3 -I tools/catalog_ledger.py --check`: pass. Generator check: repo data equals `gen_dishes.py` output.
- NOT RUN: `tools/items_check.py`, startup smoke, any in-game look, the standard exe.

## Self-review (`/ponytail-review` method, diff `f3d0d2ac0..cdf5849b2`)
No must-fix left. Fixed during review: the guard and value findings above. Notes left as they are: `_lit_structure_within` walks all items, only for crane rows within reach (unmeasured, small); `count_fill` now asks the ready table per slot (a dictionary lookup); the sealed-batch stale check runs when the craft finishes, so a refused seal costs the craft time.

## Not done
- Encyclopedia text for the moved recipes (as T07).
- Nut cake's [D17] tooltip and energy-aid change (s7 item 22): phase 7; its ledger row stays IN DEVELOPMENT.
- Selling a Maturing stack is refused in `server_trade.gd`; no test covers it (needs a trader set-up).
- In-game look of the table, crane and equipment; the client crane mirror (reads the fireplace's lit light) is not exercised by any test.

## Risks
- Crafted age now applies to every recipe whose output spoils: cooking stale ingredients gives stale food (design default, s3.14), a behaviour change players will notice.
- A batch queued while the same seal is running joins it and finishes with it. One entry of several crafts gives every output its stalest input's age (`shortcut:` comment in `_made_age`).
- Batches over the pack and nearby storage land on the ground instead of being capped, per the brief.
- Six data files share lines with Phase 9 / 4a; touched entries were rewritten one per line (`jsonedit.py`), so expect merge conflicts only on the same rows and on `next_number`.
