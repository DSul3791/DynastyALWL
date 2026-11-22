# M001-T04c results: craft refund order and test controls

Branch `m001/t04b-fixes` in `E:\Software\godotDev\m001_p1b`, after T04b `cd7d9a936`. Code under test: **`516f11f96`** (the commit after it adds only this file). Machine: Dave's PC `ManlandRyzen5`, voxel build, headless, through `tools/run_tests.sh` / `tools/run_one_test.sh` (slot lock, 3 jobs). Systems-engineer agent, 12 Nov 2026.

## Changes
1. Refund order: `Inventory.remove` and `_stock_take` record every stack a craft takes, in the order taken (`[number, inst, wear, count]`). Before, only instance and worn stacks were recorded. `_refund_entry` gives from the last row backwards. Crafts finish in queue order, so the last rows are the units the unfinished crafts still own, and they come back at their own age, wear and instance data. What no row covers (an older save) still comes back plain, as before.
2. Positive controls for the large-log checks: with one free slot, the same pick-up and chest take succeed and exactly one log exists. The filler is now fibre, so the weight never decides.
3. Perishable case: five queued energy bars (recipe 31: three nuts and one nectar) over a young stack of 9 and an old stack of 6 nuts. Two crafts are counted as finished, then a cancel. The 9 young nuts come back at their age with 3 nectar; the old nuts the finished crafts used are not refunded.

## Tests at `516f11f96`
| Run | Result |
|---|---|
| `test_item_instances` | PASS (77 checks) |
| `tests_for_diff.py cd7d9a936 HEAD` plan (151 fast + 3 timing), `run_tests.sh --jobs 3` | 154 pass, 0 fail |
| `validate_items`, full suite | NOT RUN (no data change; validate_items had the 3 pre-existing `woodworking_table` errors at T04b) |

## Note
- A finished craft is not counted down in the test through `_craft_tick`: the entry's count is set from 5 to 3, as `_craft_tick` does per craft.
- Unit rows now also exist for plain unworn stacks, so a saved queue holds one small row per stack taken (at most 20 crafts per entry).
