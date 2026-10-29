# Action plan: hide clothing goes live (Sal, branch claude/sal-hide-clothing, build 796)

Data only, no new items. Label RESTART (recipes and item flags change; no code, no protocol change).

## Today
The knife already gives raw meat and a hide from a carcass (test_new_player_day, test_animals). The hide clothing items exist since the first item batch (63 cloak, 64 boots, 65 hood, 66 mittens, 67 leggings, plus 50 backpack) with looks, worn models and weights, but every one is still `future` and every recipe is `known: false`, and the cloak, boots, leggings and backpack ask for a workbench. That breaks Dave's rule (benches only for weapons and tools, everything else by hand).

## Change
1. Remove `future` from items 63-67 and 50 (the backpack is the hide pack; it keeps its 12 kg carry bonus).
2. Recipes 39-43 and 30: known from the start, no station (hand-made). Costs unchanged (cloak 3 hide + 2 twine, boots 2 + 2, hood 1 + 1, mittens 1 + 1, leggings 3 + 2, backpack 4 hide + 1 rope).
3. Warmth numbers stay as they are (cloak 0.3, leggings 0.12, boots 0.15, hood 0.1, mittens 0.08): they are Steve's to tune in the cold balance pass, not mine.

## Not changed
No new item numbers, no renames, nothing retired. The grass clothing (items 60-62) is untouched. Hide still comes only from the knife on a carcass, so the clothing is reachable only after the first hunt.

## Tests (David3)
validate_items 0 errors, test_server_items (the five recipes by hand from hide and twine, wearing each fills its slot), test_new_player, local_check 227.

## Ask
GO or changes, one reply.
