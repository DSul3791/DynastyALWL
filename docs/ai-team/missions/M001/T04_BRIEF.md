# M001-T04 brief: Phase 1b item-instance data

Mission 001, Phase 1b (`docs/design/CATALOG_IMPLEMENTATION_PLAN.md`). Owner: systems-engineer agent. Reviewer: independent gate-reviewer. Branch `m001/p1b-instances` in clone `E:\Software\godotDev\m001_p1b` (base `159b566`). Authorized by Dave's Mission 001 brief; new game, so no old-save migration (plan, "Dave's new-game ruling").

## Behaviour (all from master s2.2, s2.7 item 5, s2.9, s4 items 2, 15, 16)
1. Every inventory slot (pack, chest, any `Inventory`) carries optional per-instance data beside number, count and wear: `inst`, a Dictionary, `{}` for a plain item. Keys, written only when not default:
   - `sharp`: sharpness used so far (int, like `wear`; absent = fully sharp). Read by the sharpening work in Phase 2c.
   - `max_d`: current maximum durability (int; absent = the item row's `durability`).
   - `temper`: 1 when Tempered.
   - `craft`: physical craftsmanship 1 or 2 (absent = 0). Fixed at craft time; no API changes it afterwards.
   - `magic`: Array of exactly two Strings, "" for an empty slot. A magical slot can be filled only while empty, and nothing removes, replaces, moves or refunds it ([DE]). No magical effects are implemented (Phase 12).
2. A slot with non-empty `inst` never merges with any other stack, and nothing merges into it.
3. Every path that moves an item keeps its `inst`: pack ↔ chest, drop to the ground and pick up, equip and unequip (worn), hotbar moves, trade and hand-over, craft queues, take-down of containers, death drops. Find them all (`take_from_slot`, `add`, `move`, the server's chest, ground and worn code) and make them carry it. An item can never gain or lose `inst` by moving.
4. Saves: the slot JSON gains an optional fifth element `inst` (the fourth, the favourite flag, is then written explicitly). Ground items and worn slots save `inst` too (worn slots become slot arrays `[number, 1, wear, inst]`; reading an old bare number still works as `[n, 1, 0, {}]`, because it costs nothing). A playtest world from before this change may be started fresh; say so in the PR.
5. Wire: `Inventory.FORMAT` 3. After the fixed 8 bytes per slot, append the instance data for non-empty slots (compact; a `u16` length plus UTF-8 JSON of `{slot: inst}` is acceptable). Worn sync and anything else that sends a slot to the client carries it. Update `PROTOCOL.md` and bump `terrain_net.gd PROTOCOL_VERSION` to 106 with a history line.
6. Display: the item tooltip shows "Tempered", craftsmanship as `+1` / `+2` after the name, and filled magical slots; empty slots stay hidden (s2.9 item 1). No new item rows, names or recipes.
7. Server API for Phase 2c (no gameplay calls yet besides tests): helpers to read the effective maximum durability and sharpness of a slot, to create an instance with given `craft`/`temper` (used by crafting later), and `fill_magic(slot, index, effect) -> bool` that refuses an occupied slot.

## Not in scope
Making craftsmanship or Tempered do anything (Phase 2c), bag contents (Phase 5), magic effects (Phase 12), worn layering (Phase 4a).

## Acceptance (Dave's PC, headless, `tools/run_one_test.sh` / `tools/run_tests.sh` with `GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe`; never more than 3 Godot jobs, always with a timeout; never kill a Godot process you did not start)
- New `src/worldgen/tools/test_item_instances.gd`: JSON and bytes round trip of every field; chest, ground, worn, hotbar and trade moves keep `inst`; no merge with or into an instance slot; `fill_magic` refuses an occupied slot and nothing clears it; a server save and reload keeps every field in pack, chest, ground and worn; `PROTOCOL_VERSION` is 106.
- Existing tests that `python3 tools/tests_for_diff.py origin/dev HEAD` picks: no new failures compared with the same tests at base `159b566` (run the failures again at the base to tell new from old).
- `/ponytail-review` of your own diff, findings answered.
- Commit with the evidence file `docs/ai-team/missions/M001/T04_RESULTS.md` (test counts, PASS/FAIL/NOT RUN, exact head SHA, machine).
