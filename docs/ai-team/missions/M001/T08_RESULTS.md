# M001-T08 results: Phase 3 graded furniture

- Task: M001-T08 (brief `T08_BRIEF.md`), systems-engineer agent. Status: IN REVIEW (not self-certified).
- Branch `m001/p3-furniture`, clone `E:\Software\godotDev\m001_p3`. Base `7a918611f`. Code commits: `cc445919f` (phase 3), `fab790723` (lead decisions), **`5ea330bd80a6c86668fdff436341983d4b97b6f5` (review fixes; the full `tests_for_diff.py origin/dev HEAD` plan was run at this commit)**. This file is committed on top (docs only). Not pushed.
- Numbers: blueprints 186-191 and structure states 230-235, as the mission lead assigned (a parallel Phase 2b branch takes blueprints from 200 and states from 240). `blueprints.json next_number` 186 -> 192. No new recipes, no new item rows.

## What changed
- `data/items/items.json`: the six rows 914-919 lose `future` and their placeholder note; renames Wooden - Chest 29 -> Rustic - Chest, Iron - Chest 852 -> Ornate - Chest, Wooden - Bench 504 -> Crude - Bench, Wooden - Chair 505 -> Rustic - Chair, Wooden - Table 506 -> Rustic - Table, Iron - Bench 637 -> Fine - Bench, Iron - Chair 639 -> Fine - Chair, Iron - Table 641 -> Fine - Table; descriptions that named planks or iron now name hardwood boards (and iron bands for the Ornate chest).
- `data/items/blueprints.json`: new rows 186-191; costs below; names follow the renames.
- `data/items/structures.json`: six structure rows (kit = own item id, as the Chopping block does); the Fine bench, chair and table count as `fine_bench`, `fine_chair`, `fine_table` and the Ornate chest as `ornate_chest` for comfort.
- `data/items/comfort.json` + `src/stream/server_items.gd` (`comfort_at`, `comfort_tip`): a kind with a `grade` competes in its `family` (chair, table, bench, board chest); each family counts once at its best grade (rule `best_grade_counts`), so a bench and a chair both count as today. Kinds with no grade (log seat, stool, workbench, Wicker chest) still count by kind. The tooltip's "Could add" offers no other grade of a family already counted (as for beds).
- `src/client/look_table.gd`: five look names for the new grades (shortcut comment); Fine - Chest uses the Rustic - Chest's `chest` look. Also `spoilage.json` (new chests and Ornate 0.6, as Rustic), `encyclopedia.json` names, hammer list `TIER_ORDER` (Fine, Ornate after Rustic).
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
Comfort points (each family counts once, its best grade): chairs Crude 1, Rustic 2 (today), Fine 3, Ornate 4; benches Crude 1 (today), Fine 3; tables Crude 1, Rustic 2 (today), Fine 3, Ornate 4; board chests 1 at every grade (today's Rustic storage point; chests are graded by storage, s3.5). The Wicker chest keeps its own 1.

## Placeholder looks (NOT visually complete)
Crude - Chest draws the Crate; Fine - Chest shares the Rustic - Chest's `chest` look (`BuildingLook.chest`, which the Wicker chest also draws); Crude and Ornate - Chair the Rustic chair; Crude and Ornate - Table the Rustic table. The renamed Fine bench, chair and table keep their iron-strapped looks although they are now board and leather pieces. `look_placeholders.json` is not used: it lists grey item icons, and these structures have no item icon row.

## Tests (Dave's PC, voxel build `godot.windows.editor.x86_64.exe`, `tools/run_tests.sh --jobs 3`, plan from `tests_for_diff.py --paths` of the diff)
- 213 tests: **212 PASS, 1 FAIL** (`test_bronze_path` check 8, bronze pick on an iron outcrop). On the base `7a918611f` it PASSES (1 run); on the head it PASSES 3 of 3 reruns: a load-dependent flake, not caused by this change (no furniture or comfort data in it). Treat as flaky, not proven.
- Run explicitly: `validate_items` PASS (0 errors, 172 warnings; base also 172), `test_item_looks` PASS (not in the plan). In the 212: `test_furniture_grades` (171 checks), `test_blueprints`, `test_hammer_list`, `test_comfort`, `test_look_table`, `test_structure_looks`, `test_build_stock` PASS.
- Static: `catalog_ledger.py --check`, `check_look_names.py`, `merge_check.py` all clear.
- NOT RUN: the full base suite (only the failing test was compared); in-game look and sitting check; the standard exe.

## Ponytail review (self) and answers
1. SUPERSEDED by lead decision 1: comfort now counts per family, not per class, so bench + chair still both count.
2. SUPERSEDED by lead decision 4: Fine and Ornate are in `TIER_ORDER`.
3. SUPERSEDED by lead decision 3: the three chests have `place_mult` 0.6.
4. SUPERSEDED by lead decision 2: names updated; its descriptions and material lists are still the old snapshot (nothing in `src/` reads it).
5. Values: structure rows carry no `value` and the economy guard checks recipes only, so there was nothing to set.
6. `plank_chest` item keeps `"material": "planks"` and its old note (descriptive only, nothing reads it for structures).

## Mission lead decisions (12 Nov 2026, coordinator message) and what was done in `fab790723`
1. Comfort counts once per FAMILY at its best grade (chairs, tables, benches each once; a bench and a chair both count, as today). Done: graded kinds carry `"family"` in `comfort.json`; `comfort_at` and `comfort_tip` group by it; the test checks bench + chair = 1 + 1 + 2. This supersedes self-review item 1 above.
2. `encyclopedia.json` names for the renamed rows: done for the eight item entries and their 27 "Used in" lines (descriptions and material lists there stay the old snapshot).
3. Chest spoilage: `crude_chest`, `fine_chest`, `iron_chest` get the Rustic chest's `place_mult` 0.6 (supersedes item 3).
4. Hammer list order: `TIER_ORDER` gains Fine and Ornate right after Rustic/Log, so graded furniture sorts Crude < Rustic < Fine < Ornate (supersedes item 2); `test_hammer_list` ordering passes.
5. `T08_BRIEF.md` committed.

Rerun at `fab790723` (voxel build, this PC): `test_comfort`, `test_furniture_grades`, `test_hammer_list`, `validate_items` (0 errors, 172 warnings), `test_blueprints`, `test_spoilage`: 6/6 PASS. `merge_check.py` and `catalog_ledger.py --check` clear. NOT RUN at this head: the other ~177 tests the diff selects (they passed at `cc445919f`; this commit changes only comfort grouping, spoilage rows, encyclopedia names and the hammer sort order).

## Review fixes (gate review PASS WITH NOTES) in `5ea330bd8`
1. Chest comfort: the Crude, Rustic, Fine and Ornate chests are one graded `chest` family worth today's 1 storage point at every grade, so any board chest counts once and no grade gives less than Rustic. The Wicker chest stays its own kind (1), so Wicker + board chest still give 2 as today.
2. `test_furniture_grades`: after each piece stands it is taken down and must return its boards and every other material (group costs as any member) and no Plank; chest comfort checks added (189 checks).
3. Stale text in this file corrected (comfort rule, look of the Fine chest, superseded self-review items).

## Evidence at `5ea330bd8` (voxel build, this PC)
- `python3 tools/tests_for_diff.py origin/dev HEAD` plan (origin/dev = `7f8aabf4f`, so it also covers phases 1 to 2a under this branch): 341 tests, **340 PASS, 1 FAIL**: `test_flora_density` timed out at 300 s under the 3-job load; alone at the same head it PASSES in 417 s (the known timing-lane issue, `tools/test_lanes.json` timing_note). `test_bronze_path` PASSED in this run.
- `validate_items` run explicitly: PASS, 0 errors, 172 warnings (base 172).
- `test_bronze_path` flake: base `7a918611f` 12/12 PASS (3 parallel, then 9 in batches of 3). Head 14/17 PASS overall (cc445919f suite fail; 3/3 sequential; 1/3 parallel; 9/9 in batches of 3; suite pass). Every failure is "Too heavy to carry any more" after random ore and stone yields (check 8, or the crafts in one run). No file this branch changes feeds weights, boulders, recipes or crafting; the cause is not proven.
- NOT RUN: in-game look, sitting and comfort HUD check; the standard exe.

## Next action
Gate re-check of `5ea330bd8` (+ this file); Art pass for the six grade looks and the three Fine looks; seed or loosen `test_bronze_path` carry weight (separate task).
