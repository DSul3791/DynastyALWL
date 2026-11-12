# M001-T08 results: Phase 3 graded furniture

- Task: M001-T08 (brief `T08_BRIEF.md`), systems-engineer agent. Status: IN REVIEW (not self-certified).
- Branch `m001/p3-furniture`, clone `E:\Software\godotDev\m001_p3`. Base `7a918611f`. **Tested code commit `cc445919faf27a9beec2c418cd59e9861438fefd`**; this file is committed on top of it (docs only). Not pushed.
- Numbers: blueprints 186-191 and structure states 230-235, as the mission lead assigned (a parallel Phase 2b branch takes blueprints from 200 and states from 240). `blueprints.json next_number` 186 -> 192. No new recipes, no new item rows.

## What changed
- `data/items/items.json`: the six rows 914-919 lose `future` and their placeholder note; renames Wooden - Chest 29 -> Rustic - Chest, Iron - Chest 852 -> Ornate - Chest, Wooden - Bench 504 -> Crude - Bench, Wooden - Chair 505 -> Rustic - Chair, Wooden - Table 506 -> Rustic - Table, Iron - Bench 637 -> Fine - Bench, Iron - Chair 639 -> Fine - Chair, Iron - Table 641 -> Fine - Table; descriptions that named planks or iron now name hardwood boards (and iron bands for the Ornate chest).
- `data/items/blueprints.json`: new rows 186-191; costs below; names follow the renames.
- `data/items/structures.json`: six structure rows (kit = own item id, as the Chopping block does); the Fine bench, chair and table count as `fine_bench`, `fine_chair`, `fine_table` for comfort.
- `data/items/comfort.json` + `src/stream/server_items.gd` (`comfort_at`, `comfort_tip`): a kind with a `grade` competes in its class; only the best graded seat and the best graded table count (rule `best_grade_counts`). Kinds with no grade (log seat, stool, workbench) still count by kind. The tooltip's "Could add" no longer offers another grade of a class already counted (as for beds).
- `src/client/look_table.gd`: five look names for the new grades (shortcut comment); Fine - Chest uses the existing `chest` look.
- Tests: new `test_furniture_grades.gd`; `test_blueprints` (185 live; the four regraded kit-recipe rows exempt from "cost equals retired kit recipe"); `test_hammer_list` (136 rows at hammer 1). `docs/COMFORT_DESIGN.md` table; ledger 20 rows IMPLEMENTED - UNVERIFIED (`--check` passes).

## Cost ladder (tuning, master s5)
| Piece | Crude | Rustic | Fine (hammer 3) | Ornate (hammer 3) |
|---|---|---|---|---|
| Chest | 4 boards, 8 pins, 2 twine | 6 boards, 12 nails, 2 hinges | 8 boards, 16 nails, 2 hinges | 10 boards, 24 nails, 2 hinges, 2 Iron bands |
| Chair | 2 boards, 4 pins | 3 boards, 8 nails | 4 boards, 12 nails, 1 Leather | 5 boards, 16 nails, 2 Leather, 1 Wool cloth |
| Table | 3 boards, 6 pins, 2 twine | 4 boards, 12 nails | 6 boards, 20 nails | 8 boards, 28 nails |
| Bench | 2 boards, 4 pins, 1 twine | - | 4 boards, 12 nails, 1 Leather | - |

Singles (Planks -> boards): Shelf 2 boards, 4 pins, 1 twine (master: "few boards, Wooden pins, Twine"); Cupboard 6 boards, 12 nails, 2 hinges; Barrel 4 boards, 2 twine, 8 nails; Weapon rack 6 boards, 2 twine; Armour stand 8 boards, 2 twine; Canopy bed 30 feathers, 8 boards, 4 Fibre cloth. Crate 168 unchanged (5 Planks, 8 nails). `nails`/`hinges` are the existing bronze-or-iron groups.

Chest slots / max kg: Crate 10/80, Crude 15/110, Rustic 20/150, Fine 25/200, Ornate 30/250.
Comfort points: seats Crude chair 1, Crude bench 1 (today), Rustic chair 2 (today), Fine chair 3, Fine bench 3, Ornate chair 4; tables Crude 1, Rustic 2 (today), Fine 3, Ornate 4.

## Placeholder looks (NOT visually complete)
Crude - Chest draws the Crate; Fine - Chest the Rustic (woven) chest look; Crude and Ornate - Chair the Rustic chair; Crude and Ornate - Table the Rustic table. The renamed Fine bench, chair and table keep their iron-strapped looks although they are now board and leather pieces. `look_placeholders.json` is not used: it lists grey item icons, and these structures have no item icon row.

## Tests (Dave's PC, voxel build `godot.windows.editor.x86_64.exe`, `tools/run_tests.sh --jobs 3`, plan from `tests_for_diff.py --paths` of the diff)
- 213 tests: **212 PASS, 1 FAIL** (`test_bronze_path` check 8, bronze pick on an iron outcrop). On the base `7a918611f` it PASSES (1 run); on the head it PASSES 3 of 3 reruns: a load-dependent flake, not caused by this change (no furniture or comfort data in it). Treat as flaky, not proven.
- Run explicitly: `validate_items` PASS (0 errors, 172 warnings; base also 172), `test_item_looks` PASS (not in the plan). In the 212: `test_furniture_grades` (171 checks), `test_blueprints`, `test_hammer_list`, `test_comfort`, `test_look_table`, `test_structure_looks`, `test_build_stock` PASS.
- Static: `catalog_ledger.py --check`, `check_look_names.py`, `merge_check.py` all clear.
- NOT RUN: the full base suite (only the failing test was compared); in-game look and sitting check; the standard exe.

## Ponytail review (self) and answers
1. Per-class best grade means a Crude bench next to a Rustic chair now gives 2, not 3 (bench and chair share the seat class). This is the literal rule of master s4 item 12 and the brief ("once per class ... like beds"). If the intent was per family, add a `family` key; one-line code change. **Reviewer to confirm.**
2. Fine and Ornate are not in the hammer list's `TIER_ORDER`, so those rows sort after the tier ladder by name. Left as is (UI order, not in the brief).
3. `spoilage.json place_mult` has no row for the Crude, Fine or Ornate chest (Ornate already had none), so food keeps there as in the pack, worse than in the Rustic chest (0.6). Not in s3.5; reported, not changed.
4. `encyclopedia.json` still carries the old names (a generated snapshot T05 did not regenerate either); nothing in `src/` reads it.
5. Values: structure rows carry no `value` and the economy guard checks recipes only, so there was nothing to set.
6. `plank_chest` item keeps `"material": "planks"` and its old note (descriptive only, nothing reads it for structures).

## Next action
Independent gate review of `cc445919f` (+ this file); decide item 1; Art pass for the six grade looks and the three Fine looks.
