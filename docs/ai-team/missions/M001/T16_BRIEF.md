# M001-T16 brief: Phase 7 temporary food effects, then Phase 8 serving platters

Mission 001, Phases 7 and 8 (`docs/design/CATALOG_IMPLEMENTATION_PLAN.md`), one engineer in order: finish and commit Phase 7 first (its own results section), then Phase 8. Owner: systems-engineer agent. Reviewer: independent gate-reviewer (one review per phase). Branch `m001/p7` in clone `E:\Software\godotDev\m001_p7` (base `7ef057c18` = dev `c2fc59a73` tree: Phase 6 cooking with prepared foods and ready ages, Phase 9 storage, Phase 3 tables). New game: no migration.

Parallel work: Phase 4b (m001_p4b, weapons/armour/combat) and Phase 5 (m001_p5, bags). Keep to food effects, vitals, HUD and boards. JSON edits line-local (helper `C:\Users\david\AppData\Local\Temp\claude\01b3e68161e49208\35a61d07-6ae9-47de-b88c-fe7400bb03ef\scratchpad\jsonedit.py`). Numbers: recipes 650-699; structure states 280-289; blueprints 240-249; protocol: take 110 (4a 107, 9 108, 5 109).

## Phase 7 (master `docs/design/DYNASTY_MASTER_ITEMS.md` s3.16 with the [D17] table, s6 row 46, s7 items 20 and 22; companion `docs/design/FOOD_PREPARATION_PRESERVATION_SERVING.md` s3a; `CATALOG_SAVE_MIGRATION.md` rule 13 intent)
1. A `food_group` and tier per food (Main Meal, Bread & Grains, Fruit & Vegetables, Dessert, Beverage) in data; teas and Fruit juice are Beverages.
2. **Three group slots** with independent timers: eating a food of a group fills or refreshes that group's slot (never stacks); a food of a fourth group asks the player which slot to replace (a prompt), per s3.16; the [D17] initial values (Main Meal Fitness XP +10/15/20 % for 2/6/12 h, balanced T3 board may give all-skill XP +10 % instead; Bread & Grains energy drain −10/15/20 %; Fruit & Vegetables health regen ×1.05/1.10/1.15; Dessert +8/12/15 energy at once and XP −5 % for 1 h on its own visible timer; Beverage hunger and thirst drain −5/10 %).
3. **XP bonuses apply when XP is actually earned** (at the Fitness tick / skill practice), never retroactively, never multiplied by repeat eating; no permanent Fitness penalties: energy aids lose their `fitness` cost (`vitals.json energy_aids`), Nut cake 51 tooltip without "wears on your fitness" and its energy 12; energy aids and medicinal teas are no longer refused when rested or healthy and give instant energy only when their slot is newly filled or expired; death clears all effects; every effect temporary and shown on the HUD with time left.
4. Save and wire: active effects persist with the character and sync to the owner.
5. Tests: XP applied at the tick only while active; replace and expire; no stacking or repeated-consumption exploit; fourth-group prompt; dessert penalty finite and visible; death clears; save/load and wire round trip; no Fitness loss from energy aids.

## Phase 8 (master s3.15, s7 item 20; companion s3)
1. **Eight board rows and the Serving Platter go live** (Ploughman's Board stays FUTURE): boards crafted at the Food Preparation Table from real prepared/cooked ingredients; a board stack's count is its remaining portions; shelf life set at assembly from its shortest-lived ingredient; eating a portion counts as one food of the board's group (Phase 7), refreshing but never stacking.
2. **Placing**: the Serving Platter is a placeable carrier for a table surface (Phase 3 tables; a table-surface attach point); placing a board moves the stack into the placed platter's own inventory; players eat portions from it; picking up returns the stack and the platter; spoilage, ownership, save and network continuity persist; food can never be duplicated by moving, loading, eating or picking up.
3. Tests: portion conservation; place on a table, eat half from it with two players, pick it up; no board merge across ages; save and reload a placed platter.

## Rules
Work only in `E:\Software\godotDev\m001_p7`. Never touch `C:\GodotProjects\DynastyALWL` or other clones. Do not push. Godot only through the slot scripts with timeouts; never kill a Godot process you did not start. No catalog changes beyond the catalog text; report problems. Looks placeholders marked (NOT visually complete). Ledger rows updated per phase; `catalog_ledger.py --check` passes.

## Acceptance per phase
`validate_items` PASS, `merge_check.py` clear, a clean full plan `python3 tools/tests_for_diff.py 7ef057c18 HEAD` at the exact head with no new failures (known flakes: test_flora_density timeout under load, test_npc_view crash at quit); `/ponytail-review`; commit with `docs/ai-team/missions/M001/T16_RESULTS.md` (sections Phase 7 and Phase 8: head SHAs, counts with log paths, numbers, risks).
