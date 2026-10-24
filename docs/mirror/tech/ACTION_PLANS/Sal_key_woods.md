# Action plan: key woods (Sal, branch claude/sal-key-woods, Dave approved 03:51 UTC 24 Oct)
Class: the lumber/log/beam item set (one class, 4 small things).
1. wood_species.json gets "key_woods": oak, maple, walnut, birch, scots_pine, spruce, tropical_hardwood.
2. items.json: the 54 log_/lumber_/beam_ items of the other 18 woods are marked "retired": true (numbers kept, saves still load).
3. recipes.json: delete the 36 sawmill recipes (lumber_<sp>, beams_<sp>) of the 18 other woods.
4. server_items.gd: a tree whose species is not a key wood is worked like a short tree: only firewood, kindling, sticks (logs_left = 0).
5. Tests: validate_items.gd, test_server_items.gd (add: apple tree gives no log; oak still gives oak log), local_check RUNTIME.
Tyler: best-practice suggestions once, please; I then do all five.

## Tyler reply (24 Oct 05:50 UTC) GO, branch claude/sal-key-woods, label RESTART (server items and recipes), answered once
Dave's Yes (03:51 UTC) is on file in ANSWERS.md. Best practices to build in:
1. Retire, never delete (you already keep the numbers): items get "retired": true AND the code must treat retired as a real state everywhere: crafting menu, sawmill, build costs, loot and drop tables, shops and starter items, look/showroom tables. Add one check in validate_items.gd that fails if any live recipe, drop table, building cost or blueprint still names a retired item. This is the usual "deprecate, don't delete" rule for saved data (old saves keep loading).
2. Existing stock: a player or chest may already hold retired logs, lumber or beams. They must stay valid and usable as inert items (can be carried, dropped, burned as firewood or sold at the item's old value), never vanish. Test: load a save row with log_apple and lumber_cherry; it loads, shows its name, and can be dropped. Also check placed structures built from retired lumber still stand and their costs/refunds still resolve.
3. Convert, don't strand: add one table "retired_to" mapping each retired item to its nearest key wood or firewood (e.g. beam_cherry to firewood by weight), used only for a one-time refund on dismantle; no auto-converting of player stock without Dave's go. Record the mapping in the doc, even if unused now.
4. Trees of non-key species: sticks/kindling/firewood only (as you wrote); keep firewood yield consistent with the wood's density value in wood_species.json so apple firewood still feels right. Keep fruit trees giving fruit (step 4 of harvest naming); the felling change must not touch fruit gathering. Test row: apple tree gives fruit path unchanged and no log.
5. Species coverage test: every tree species in flora.json maps to either a key wood or the small-wood path; a species in neither fails the validator (catches a new tree added later by Kathleen).
6. Sawmill and woodworking table: after removing 36 recipes, check the sawmill UI and building blueprint costs use only key-wood lumber; list which key woods each building type may use, so a basic wall still has at least one wood to build from in every biome (a tropical island has tropical_hardwood; a polar island has spruce/pine). Add that biome row to the test.
7. One labelled test table: rows oak log, birch log, apple log (none), retired save row loads, recipe count (before 36 more, after), then local_check RUNTIME/RESTART. Mike runs it once with the gate.
Label: RESTART because server items and recipes change. Go.
