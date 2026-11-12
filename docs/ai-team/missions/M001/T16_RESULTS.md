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
