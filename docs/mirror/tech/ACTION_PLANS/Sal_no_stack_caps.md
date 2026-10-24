# Sal: no stack caps, weight is the only limit (one plan, whole class)
Goal (Dave 14:26 and 14:27 UTC 24 Oct): a stack holds up to the count type's maximum, because how much you can carry comes from weight; all stone in one stack. Things that cannot stack (shovels, tools, kits, placed structures) stay at 1. Nothing is built until Dave says go.

## What the code does today (read from generator-v2)
- Cap comes from items.json "stack" (118 items are 1; most materials 5 to 40; coins 999; nails and rotten food 200). `item_table.stack_of`, used by `inventory.gd` add() and move() and `server_items.gd` (rotten food clamp at line ~5512).
- Counts live in memory as PackedInt32Array (31-bit), but are written as **u16 (max 65,535)** in four places: `inventory.gd` to_bytes/from_bytes (FORMAT 2, 8 bytes a slot, shared by the pack, chests and the full-inventory message), the slot-update message (`server_items.gd` ~2508, read at `inventory_view.gd` ~934), and ground drops (`ground_ops.gd` decode_u16). The JSON save (`to_json_array`) has no limit.
- Ground piles already allow 100,000 (PILE_CAP in server_items.gd).
- Carry limit is by weight: weights.json, 0.7 x body kg, slows from 80 percent (server refuses pickup above the limit). Stone is 1 kg, stick 0.4 kg, fibre a few grams.
- Tooltip says "stacks to N" (`inventory_view.gd` ~3144); Split, Drop and Shift+D take counts; craft queue caps (10 entries x 20 crafts).

## Proposal
1. **Count maximum = 65,535 (u16), no wire change.** Real carry weight stops a pack long before that (a 70 kg body carries about 49 kg: 49 stones, 120 sticks, thousands of fibre or coins at a few grams). So the cap only matters for tiny items; u16 is far enough. If Tyler wants u32 for future, it is one protocol bump (FORMAT 3, 10 bytes a slot, slot message count field, ground_ops), listed as option B.
2. **Unstackable flag per item.** items.json gets `"unstackable": true` for every item that is stack 1 today and must stay 1: all tools, weapons, containers, clothing, gear, kits (placeable), structures (about 100 rows, set by a script from the current stack-1 rows; materials that are stack 1 today (8 rows) are reviewed by hand). Everything else loses its cap. The old "stack" number stays in the file for one version (ignored) so a revert is a one-line change, then it is removed.
3. **Code change (small):** `item_table.stack_of(number)` returns 1 for unstackable, else COUNT_MAX (65,535). add(), move() and the leftover logic already use it, so a full stack just returns leftover or fills the next slot as today. Items that carry wear (tools, containers, food age) keep the existing merge rules (food merges by age gap and averages).
4. **Overflow:** add() stops at COUNT_MAX and puts the rest in a new slot; if no slot, leftover drops to the ground (existing behaviour). Admin give, craft output, trade and pickup all go through add(). from_json_array and from_bytes clamp counts to 0..COUNT_MAX; a negative or over-range number in a hand-edited save is clamped, logged once. Craft refunds, queue totals and split use clamped ints. The ground pile stays 100,000 but a pickup moves at most COUNT_MAX at once.
5. **UI that assumes small stacks:** tooltip "stacks to N" becomes "stacks without limit, weight is your limit" (or "does not stack"); slot count label needs room for 5 digits (shown as 12.3k above 9,999); Split halves large counts; Drop dialogs accept up to the count; chest screen unchanged. Craft queue unchanged.
6. **Save and compatibility:** old saves load unchanged (counts only get larger). A rollback to the old cap would clamp counts down and lose items: so the rollback rule is "never go back without Dave", noted in the commit.
7. **Weight check first:** because stack no longer limits carrying, the weight rules must cover every item (default_kg 0.05 means 65,535 of an unlisted item weighs 3.3 t, still stopped by the limit). A validator row lists stackable items missing from weights.json so none rides on the default by accident.

## Files
data/items/items.json (unstackable flags), src/shared/item_table.gd, src/shared/inventory.gd (clamp), src/stream/server_items.gd (clamps, pile pickup), src/client/inventory_view.gd (tooltip, label), src/worldgen/tools/validate_items.gd (unstackable rule, weights row), tests: test_server_items (65,535 stone in one slot, overflow to second slot, clamp on load, unstackable stays 1, food merge unchanged). Label RESTART (data and server) with a client change; no protocol change under option A.

## Test and Dave check
validate_items 0 errors, test_server_items new rows, item_master --check, local_check. Dave sees: pick up all the stone into one slot; shovels stay one per slot.

## Open for Tyler (answer once)
A or B (u16 now, or u32 with a protocol bump)? Recommended A.
