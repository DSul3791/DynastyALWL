# Playtest Repair Mission 001: hotbar (TEST-008, TEST-006)

Owner: hotbar thread. Base: `origin/dev` b922cc88a59586dfbd41f806744d9ccedfe2bf26. PR #1057 (branch `claude/project-thread-fba071`).

| Test | Status | Evidence |
|---|---|---|
| TEST-008 Hotbar duplicates backpack inventory | NOT YET VERIFIED (code done, PC tests not run) | Cause: the 8 Nov pointer hotbar (OVERNIGHT_DECISIONS_8NOV.md row 24): keys held item numbers and pointed at backpack slots, so one item showed in both. Fix: keys 1-9, 0 are pack slots 0-9, backpack slots 10-29; moving is ACT_MOVE. Test: `test_hotbar_keys.gd` sections 1-2, 6. |
| TEST-006 Hotbar retains removed items | NOT YET VERIFIED (code done, PC tests not run) | Cause: by design a pointer key kept its item, dimmed, after the last one left. Fix: a real slot is empty once its item is dropped, sold or used up. Test: `test_hotbar_keys.gd` section 3. |

## Decisions and their source
- Hotbar as real slots, one location per item: Dave, playtest message 12 Nov 2026 (TEST-008).
- Tools and weapons go to the hotbar by themselves; a food stack goes there when the player moves it; an empty slot stays empty "unless a player pulls more to the hotbar": Dave, thread message 12 Nov 2026 23:03Z.
- Capacity: total stays 30 stacks (hotbar 10 + backpack 20) pending Dave's card answer; the alternative (40) changes the inventory wire and save size.
- Removed with the pointer model (Decision 61): ACT_HOTBAR_SET, the `hotbar` rpc, the quick-bag draw-by-key (T15 item 3). A pointer-hotbar save's `characters.json` "hotbar" is adopted once at the join (each key's item moves into its slot) and then dropped.

## Tests
- Cloud, static only: `tools/merge_check.py` all clear; `tools/check_controls.py` ok.
- Selector (`tools/tests_for_diff.py b922cc8 HEAD`): 349 fast + 8 timing (protocol change). Godot: NOT RUN (Dave's PC only, when he is not playtesting).
- Independent review round 1 (gate-reviewer, a660110): FAIL with fixes; fixes in the next commit, re-review pending.

## For Dave's next playtest
Drag an axe and a food stack into the hotbar: each leaves the backpack. Drag them back. Eat or sell the last of a hotbar stack: the slot empties. Pick up a new tool: it goes into the first empty hotbar slot.
