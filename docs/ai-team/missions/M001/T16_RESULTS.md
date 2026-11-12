# M001-T16 results: phase 7 temporary food effects, phase 8 serving platters

- Branch `m001/p7`, clone `E:\Software\godotDev\m001_p7`, base `7ef057c18`. Not pushed. Brief: `T16_BRIEF.md`.

## Phase 7: temporary food effects

**Code head under test: `01fe26f77`** (this section is committed on top, docs only).

### What went live
- `data/items/food_effects.json` (new): one `group` and `tier` for each of the 75 edible crafted foods (s7 item 20: a separate file keyed by item id, not hand edits to generated rows) plus the [D17] table, `slots` 3 and the XP caps. Tier = ingredient kinds over the whole chain (prepared doughs expanded, kept equipment not counted, water counts): T1 1-2, T2 3, T3 4+. Groups: Main meal (roasts, stews, fish, eggs, pies, meats; 30 rows, 15 marked `hearty`: red meat or seal, and Hearty pottage), Bread and grains (11), Fruit and vegetables (15), Dessert (12, Nut cake among them), Beverage (the five teas, Fruit juice, Magic tonic FUTURE). Raw ingredients, salt and doughs have no profile and never touch a slot.
- `src/shared/food_effects.gd` (new, shared by server and client): live slots, the replace plan, the XP and multiplier combination, the HUD text.
- Server (`server_items.gd`): `characters.json` gains `food` {group: {id, t, until game-clock seconds}}; eating plans first (same group refreshes, never stacks; a weaker tier, or a fourth group with three live, asks; a declined question eats for calories only), then applies. Hooks: Fitness tick `xp_per_tick x fitness_xp_mult` (food only, at the tick, capped +20 %); skill `practice` difficulty `x skill_xp_mult` (all-skill food bonus minus dessert plus Rested, capped +25 %; a dessert never pushes real work under the trivial line); energy drain, hunger and thirst, health regeneration take the larger of the food effect and Rested or bed, never the product. Death clears every effect. Synced at hello, after eating, at death and each whole real minute.
- [D17] energy aids (s7 item 22): `vitals.json energy_aids` loses `fitness` and Nut cake energy is 12; `energy.json fitness_max_loss` and `_fitness_cost` are deleted; Nut cake, Herbal and Nettle tea are no longer refused when rested and give energy only when their slot is newly filled or had run out (a declined question gives none). Stomach, Chamomile and Willow bark tea are no longer refused when well (Beverage only) and cure as before when sick. Nut cake tooltip (items.json, encyclopedia.json): "Quick energy; a sweet slows what you learn for a while."
- Protocol **110**: `food_effects(rows)` and `food_ask(slot, number, groups)`; ACT_EAT b = the answer (0 none, a group index, 9 decline). 109 left for Phase 5. PROTOCOL.md rows and version note.
- Client: HUD lines under the comfort line ("Main meal (Roast joint): Fitness XP +15 %, health regeneration +10 %, 14 min"), the replace question window (Replace X / Eat, keep my effects / Cancel) and a tooltip line per food. Placeholder panels (NOT visually complete).

### Numbers ([D17] initial values, s5 tuning)
Main meal Fitness XP +10/15/20 % for 2/6/12 game h, hearty regen x1.05/1.10/1.10, a balanced T3 board all-skill +10 % instead; Bread and grains energy drain x0.90/0.85/0.80 for 4/8/12 h; Fruit and vegetables regen x1.05/1.10/1.15 for 4/8/12 h; Dessert +8/12/15 energy at once, XP -5 % for 1 h; Beverage hunger and thirst x0.95/0.90 for 2/4 h. HUD minutes are real minutes (1 game h = 2.5 min).

### Evidence (Dave's PC, voxel build, at `01fe26f77`, no edits during the run)
- `python3 tools/tests_for_diff.py 7ef057c18 HEAD` (342 fast, 8 timing) through `tools/run_tests.sh --jobs 3`: **349 PASS, 1 FAIL**: `test_flora_density` timed out after 300 s (the known flake under load; its checks printed ok up to the timeout). Wall 1269 s. Plan `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p7_plan.json`, log `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p7_suite.log`, per-test output `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p7_suite/`.
- Checks lane at the same head: `validate_items` PASS, 0 errors, 144 warnings (`C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p7_checks/validate_items.out`); `tools/check_look_names.py` clean; `merge_check.py` all clear (one carry-audit warning, present at base); `catalog_ledger.py --check` pass (Nut cake 51 IMPLEMENTED - UNVERIFIED).
- `test_food_effects` (new, 71 checks), `test_server_items` (energy section rewritten), `test_sickness`, `test_comfort`: PASS on the standard exe before the commit.

### Decisions (documented, under the mission's autonomy direction)
- Nut cake is tier 2 as master s3.16 states ("3 ingredient kinds, tier 2"), though its recipe has 2 kinds; only its displayed tier depends on it (energy 12 comes from `energy_aids`).
- Groups for dishes the catalog does not name: stews and soups with meat or fish are Main meals, Forager stew too ("Main Meal (roasts/stews/fish)"); Pea soup, Turnip mash and roast vegetables Fruit and vegetables; Acorn mash, Barley broth, Chestnut and Oat cakes, Honey loaf Bread and grains; sweet stewed fruit, jams, Nut paste and Fritter Desserts.
- Timers run on the game clock (it advances only while the server runs), so an effect keeps through logout but runs out while the world runs.

### Self-review (`/ponytail-review` method, diff `7ef057c18..01fe26f77`)
Fixed before the commit: a declined question on an energy aid still gave its energy (repeatable without a slot); the dessert penalty could push practice at the trivial line (difficulty 0.2) to no XP at all. Left: the question is sent again on every repeated E (unpaced, one small message each); the HUD resend is checked every slow tick per player (a short array compare).

### Not done / not checked
- In-game look of the HUD lines and the question window (placeholders), NOT RUN in a real client; startup smoke NOT RUN.
- No notice when an effect runs out (the HUD line goes).

### Risks
- Every existing food now carries an effect: players who eat a weaker food in the same group get a question, which old habits (spamming E) will meet.
- A Fitness or skill change elsewhere that bypasses `_train_fitness` or `practice` would bypass the food hook.

## Phase 8: food boards and the Serving Platter

**Code head under test: `69c230020`** (on top of the Phase 7 results `07fe6f0e6`; this section is committed on top, docs only).

### What went live
- **Eight boards** (1243-1250) lose `future`; recipes 650-657 at the Food preparation table from cooked dishes only (master s3.15 table, live rows). A board's stack count is its portions; food (kcal) and weight per portion are the dishes' sums over the portions (no free food); shelf life is the shortest-lived dish (`spoilage.json`), and the crafted age is the stalest input's (Phase 6 rule). Boards join only at the very same age (`spoilage.json exact_age`, `Inventory._mergeable`). Each portion is one food of its group (Phase 7): tier 3; Dessert platter Dessert, Harvest platter Fruit and vegetables, the other six Main meals (s3.16 DELEGATED); hearty where red meat; the Tavern supper board (dishes from three groups) is the balanced board (all-skill XP +10 % instead of Fitness +20 %).
- **Ploughman's board** 1252 stays FUTURE (cheese and pickles FUTURE), no recipe.
- **Serving Platter** 1251: recipe 658 by hand, 2 Wooden block with the knife kept (s3.15 RECOMMEND: like the Wooden bowl); kind `container` -> `placeable` (the client places only `placeable` kits). Structure `serving_platter`, **state 280**: a one-slot container (`takes` the eight boards, `max_kg` 10), `attach_to` "table" with `attach_kinds` {table, crude, ornate, Food preparation 0.73 m; stone 0.85; iron 0.8}. `PlacementRules.table_spot` (shared by the server and the ghost) moves the spot onto the nearest table top under it and inside its edge; refused off a table ("Set it on a table."), one to a spot (0.35 m), a table with a platter on it cannot be taken down.
- Use: the owner opens it (E when empty) and puts a board on it (the stack moves); anyone eats a portion with E (`ACT_USE_STRUCT`, through the same `_eat` as the pack, so stomach cap, freshness and the food question apply; the question names the platter, slot = minus its world id, answered with `ACT_USE_STRUCT b`). Only the owner opens it, takes the board back or picks it up; picking up gives the portions back first (all or nothing), then the platter. Not crafting stock and not in storage views (`_is_storage`). Spoils at `place_mult` 1.0. Its world row carries `board` and `portions` (the prompt "Press E to eat from the roast platter, 3 left").
- Protocol stays **110** (the same unmerged version): state 280, row extra, `ACT_USE_STRUCT b`. PROTOCOL.md rows and note.

### Numbers (s5 tuning: "portions per board" is open; chosen: one portion per dish)
| Board | Dishes | Portions | kcal each | kg each | Shelf h | Value each |
|---|---|---|---|---|---|---|
| seafood_platter | 2 roast_fish, 2 roast_shellfish, 1 crab_cakes | 5 | 516 | 0.26 | 24 | 10 |
| roast_platter | 1 roast_meat, 1 roast_joint, 1 roast_roots, 1 onion_roast | 4 | 537 | 0.33 | 48 | 14 |
| mixed_grill_platter | 2 sausage, 2 meat_skewer, 1 garlic_meat | 5 | 744 | 0.30 | 48 | 26 |
| charcuterie_board | 2 jerky, 1 sausage, 1 smoked_meat, 1 sauerkraut | 5 | 604 | 0.36 | 360 | 17 |
| harvest_platter | 1 roast_roots, 1 beet_roast, 1 onion_roast, 1 mushroom_skewer | 4 | 422 | 0.30 | 48 | 9 |
| tavern_supper_board | 1 venison_pie, 1 fish_pie, 1 flatbread, 1 roast_roots | 4 | 642 | 0.30 | 72 | 14 |
| breakfast_platter | 2 boiled_egg, 2 oat_cakes, 1 sausage | 5 | 504 | 0.20 | 120 | 14 |
| dessert_platter | 1 apple_pie, 1 honey_loaf, 1 baked_apples, 1 berry_compote | 4 | 522 | 0.30 | 72 | 14 |
Platter value 6 (two blocks are 6), weight 0.6 kg. Board values are the dishes' values over the portions (the Phase 1 placeholders 35-60 a piece would have let a board sell above its dishes).

### Evidence (Dave's PC, voxel build, at `69c230020`, no edits during the run)
- `python3 tools/tests_for_diff.py 7ef057c18 HEAD` (343 fast, 8 timing) through `tools/run_tests.sh --jobs 3`: **349 PASS, 2 FAIL**, both the known flakes: `test_flora_density` timed out after 300 s (checks ok up to the timeout), `test_npc_view` exit 139 at quit after printing PASS. Wall 950 s. Plan `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p8_plan.json`, log `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p8_suite.log`, per-test output `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p8_suite/`.
- Checks lane at the same head: `validate_items` PASS, 0 errors, 136 warnings (`C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/p8_checks/validate_items.out`); `check_look_names.py` 237 drawable; `merge_check.py` all clear (one carry-audit warning, at base); `catalog_ledger.py --check` pass (the eight boards and the platter IMPLEMENTED - UNVERIFIED, the Ploughman's board FUTURE-GATED).
- `test_serving_platter` (new, 51 checks): the data (live, at the table, from cooked foods, portions, kcal, shortest shelf, tier and group), a board made at a table from real dishes (spent once) with the stalest dish's age, boards of other ages kept apart, a portion from the pack is one tier 3 Main meal that refreshes without stacking, the platter refused off a table and snapped onto the top, one to a spot, boards only, the owner sets the board out, a stranger can neither take, open-and-Take-all nor pick it up, two players eat half, the food question at the platter, every portion counted, the table not taken from under it, save and reload (portions, age, owner), the world row's board and portions, picked up whole with its age.

### Self-review (`/ponytail-review` method, diff `07fe6f0e6..69c230020`)
Fixed before the commit: a stranger could open the platter and Take all (the owner check moved into `_chest_of`, which every open, put, take and bulk action passes); taking the table down left the platter floating; boards still averaged ages within the 10 % merge gap (exact-age rule added). Left: `_platter_on` and `_surface_rows` walk every world record, only on a placement or a table take-down (unmeasured, small).

### Not done / not checked
- Looks: the platter is a flat placeholder board, the same full or empty; the boards are grey placeholders (NOT visually complete; the row data for fullness is there). The ghost on a table and the E prompt are NOT RUN in a real client.
- NPC diners (s3.15: FUTURE, no NPC hunger). Encyclopedia text for the new recipes.

### Risks
- Recipe `next_number` 478 -> 659 (above this task's block 650-658): Phases 4b and 5 will conflict on that line.
- A platter's owner is the placer; a platter left by a player who never returns stays theirs (no expiry).
- Table heights are read from the looks by eye (0.73 / 0.8 / 0.85 m), not measured in game.

## Review round 1 and the dev merge

Gate review FAIL on one must-fix (mission lead's message). Fix commit `3bfe4f401`; merge of the dev state `a2a8f1ea8` (dev `aa0ce7d2d`: Phase 4b, protocol 108, plus the mission state commit): **`ce4dfad59` = code head under test**. This section is committed on top (docs only). Not pushed.

### Fixed
1. **MUST, swap exploit:** a slot replaced through the fourth-group question no longer vanishes. It stays as an `off` entry until its own end: it holds no slot and gives no benefit, but it locks that group's instant energy (a later food of that group is not "fresh" until then; a newer entry carries the lock on as `lock`), and a replaced dessert's XP -5 % keeps running to its own end. The HUD shows it ("Dessert (Nut cake), replaced: XP -5 %, 3 min"; `food_effects` rows gain a fifth field, replaced 1/0). Test: Nut cake and Herbal tea alternated three times with three slots full: energy rises once (+12), Fitness XP stays x1.10 while the replaced dessert's penalty runs, back to x1.15 at its end.
2. **Ghost frame cost:** the client's `surface_rows(states)` keeps only the states of the platter's `attach_kinds` (`PlacementRules.attach_states`), as the server's `_surface_rows` does.
3. **Logout:** effects are kept through logout (master s3.16): `peer_left` stops each timer with its time left (`left`, `lock_left`), the next hello runs it on (`FoodEffects.pause` / `resume`). Test: 20 game hours away and a server restart, the stew has the same time left.
5. **Platter blocking:** a table with a platter on it is found with the turned footprint (`PlacementRules.over_table`, shared with `table_spot`), not a radius: the table end to end beside it, or turned a quarter, can be taken down.
6. The serving kinds are read once (`_serve_kinds`) for the world-item sync.

### Recorded, not changed
- **(4) Dave's tuning call, flagged for playtest:** a tier 1 dessert gives +8 energy once per game hour (2.5 real minutes) of its slot; the drain is 12 to 54 a game day (0.5 to 2.25 an hour), so desserts eaten each hour can out-supply the drain and stand in for rest. The [D17] values are Dave's accepted starting values; the slot rule, the stomach cap and the XP -5 % are the only limits.
- **Catalog data edits made in Phase 8** (implementation fields on catalog rows, reported for review): board values 40-60 a board -> the dishes' value per portion (9-26); board weights 0.8 -> per portion 0.20-0.36 kg; Serving platter value 20 -> 6, weight 1.0 -> 0.6 kg, kind `container` -> `placeable`; board descriptions gain "Each piece is one portion."; the Serving platter description rewritten for the table use.
- **Nut cake tier:** master s3.16 states "Nut cake (3 ingredient kinds, tier 2)"; its live recipe 31 has 2 kinds (nuts group, nectar), which the chain rule makes tier 1. Kept at tier 2 as the master says; only its shown tier depends on it (its energy 12 is `energy_aids`). Reported, not fixed.

### Merge
One conflict, `recipes.json`: both blocks kept (Phase 4b 500-560, T16 650-658; no duplicate numbers), `next_number` 659 (4b had 561). Protocol: dev 108, Phase 5 takes 109, T16 keeps 110. Phase 5's recipes 600-610 sit under 659.

### Evidence (Dave's PC, voxel build, at `ce4dfad59`, no edits during the run)
- `python3 tools/tests_for_diff.py a2a8f1ea8 HEAD` (344 fast, 8 timing) through `tools/run_tests.sh --jobs 3`: **350 PASS, 2 FAIL**, both the known flakes: `test_flora_density` timed out after 300 s (checks ok up to the timeout), `test_npc_view` exit 139 at quit after printing PASS. Wall 939 s. Plan `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/r1_plan.json`, log `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/r1_suite.log`, per-test output `C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/r1_suite/`.
- Checks lane at the same head: `validate_items` PASS, 0 errors, 116 warnings (`C:/Users/david/AppData/Local/Temp/claude/01b3e68161e49208/35a61d07-6ae9-47de-b88c-fe7400bb03ef/scratchpad/t16/r1_checks/validate_items.out`); `check_look_names.py` 237 drawable; `merge_check.py` all clear (one carry-audit warning, at base); `catalog_ledger.py --check` pass.
- Before the merge, at `3bfe4f401`: `test_food_effects`, `test_serving_platter`, `test_server_items`, `test_placement_rules`, `test_comfort` PASS. NOT RUN: startup smoke, any in-game look.
