# M001-T04b results: follow-ups from the T04 round-2 review

Branch `m001/t04b-fixes`, cut from the T04 head `f7a099541` in `E:\Software\godotDev\m001_p1b`. Code under test: **`c8e233ace`** (the commit after it adds only this file). Machine: Dave's PC `ManlandRyzen5`, voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`, headless, through `tools/run_tests.sh` / `tools/run_one_test.sh` (slot lock, 3 jobs). Systems-engineer agent, 12 Nov 2026.

## Changes
1. `Inventory.remove_fill(number, count, taken, plain_only)` (and `count_of(number, plain_only)`): with `plain_only` it checks the plain count and takes at most each member's plain count, so an instance unit never fills a building cost, even when its member is first in spend order. Used by every building-cost path: `_deposit_site` (pack and containers), `_gather_site` (pack, containers, ground stacks with instance data skipped), `_repair_struct` (pack and containers), `_pay_blueprint` through `_stock_take(plain_only)` (pack and containers).
2. `_give_shoulder(..., drop_rest)`: `_pickup` and the chest take pass `false`. A large log that does not fit stays in the ground pile or the chest, and nothing is laid at the player's feet. `give()` still lays what does not fit, as its contract says.
3. Craft-queue unit rows are now `[number, inst, wear, count]`. They are recorded by `Inventory.remove` and `_stock_take` for instances and for any plain stack with wear (food age, wet wood), and a cancel gives them back as they were: instances first, then worn plain stacks, then plain unworn units. Rows from saves still load: `[number, inst]` reads wear 0 and count 1, `[number, inst, wear]` reads count 1.
4. Tests in `test_item_instances` (72 checks):
   - log-group spend order with an instance log first, for `remove_fill(plain_only)` and `_stock_take(plain_only)`;
   - no doubled log from a full-pack chest take or pick-up;
   - aged plain refund;
   - a positive control for the placement refusal (the same kit without instance data is placed);
   - two-, three- and four-value unit rows loaded from a written `craft_queues.json`, refunded, then saved and reloaded.

## Tests at `c8e233ace`
| Run | Result |
|---|---|
| `test_item_instances` | PASS (72 checks) |
| `tests_for_diff.py f7a099541 HEAD` plan (151 fast + 3 timing), `run_tests.sh --jobs 3` | 153 pass, 1 fail |
| `test_fish_trap` ("40 jabs land some fish but not all (0)", a chance check) | FAIL in the run, then PASS 3 of 3 runs alone at head. It passed in both T04 plan runs. Not attributed to this change |
| `validate_items` (run explicitly) | FAIL, 3 errors, the same as at base `159b566` and at `dacdbb630`. They are `structures.json woodworking_table names the retired item woodworking_table`: item data outside this task |
| Full suite, `check_look_names.py`, `warnings` | NOT RUN |

## Not done, risks
- The hammer list's craft_stock counts still include instance units of building materials, so it could show a piece as covered that the server only sets down as a site. Building materials cannot carry instance data in play yet (master s2.9 item 7).
- `_give_shoulder` still drops the log's wear (a wet log comes up dry). This is pre-existing and was not asked for.
- A non-perishable stack's wear is ignored when stacks join (`Inventory._joined_age` keeps the first stack's). So a refunded worn stack can absorb plain units, as before.
