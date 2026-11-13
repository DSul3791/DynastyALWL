# Playtest Repair Mission 001: hotbar (TEST-008, TEST-006)

Owner: hotbar thread. Base: `origin/dev` b922cc88a59586dfbd41f806744d9ccedfe2bf26. PR #1057 (branch `claude/project-thread-fba071`).

| Test | Status | Evidence |
|---|---|---|
| TEST-008 Hotbar duplicates backpack inventory | NOT YET VERIFIED (tests pass on 9145d59; merged-with-dev check and dev merge pending) | Cause: the 8 Nov pointer hotbar (OVERNIGHT_DECISIONS_8NOV.md row 24): keys held item numbers and pointed at backpack slots, so one item showed in both. Fix: keys 1-9, 0 are pack slots 0-9, backpack slots 10-29; moving is ACT_MOVE. Test: `test_hotbar_keys.gd` sections 1-2, 6. |
| TEST-006 Hotbar retains removed items | NOT YET VERIFIED (tests pass on 9145d59; merged-with-dev check and dev merge pending) | Cause: by design a pointer key kept its item, dimmed, after the last one left. Fix: a real slot is empty once its item is dropped, sold or used up. Test: `test_hotbar_keys.gd` section 3. |

## Decisions and their source
- Hotbar as real slots, one location per item: Dave, playtest message 12 Nov 2026 (TEST-008).
- Tools and weapons go to the hotbar by themselves; a food stack goes there when the player moves it; an empty slot stays empty "unless a player pulls more to the hotbar": Dave, thread message 12 Nov 2026 23:03Z.
- Capacity: Dave 12 Nov 23:06Z: "slots should be almost endless... minimum of 20 and if they add more stuff just start adding more slots... they are limited by weight really". This PR keeps 30 (hotbar 10 + backpack 20); the growing backpack is a follow-up PR.
- Removed with the pointer model (Decision 61): ACT_HOTBAR_SET, the `hotbar` rpc, the quick-bag draw-by-key (T15 item 3). A pointer-hotbar save's `characters.json` "hotbar" is adopted once at the join (each key's item moves into its slot) and then dropped.

## Tests
All Godot runs on Dave's PC (ManlandRyzen5), voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe` 4.7.2.stable.custom_build.ed1daf0bf, clone `E:\Software\godotDev\hotbar01` (Dave's checkout, editor and saves untouched), throwaway APPDATA, `tools/run_one_test.sh` 300 s or `tools/run_tests.sh --jobs 3`.
- Cloud, static only: `tools/merge_check.py` all clear; `tools/check_controls.py` ok.
- Focused: on 68f653e PASS test_bulk_ops, test_server_items, test_offhand, test_tool_care, test_tool_ladder, test_station_storage, test_bronze_path, test_handcart, test_mission001_walkthrough, test_item_instances, test_item_renames, test_inventory, test_items_persistence, test_save_compat, test_new_player_day; test_hotbar_keys PASS on e7dd2f3; test_carrying PASS on 9145d59 (failed before the test fix; passes on dev b922cc8).
- Broad (selector `tests_for_diff.py b922cc8 9145d59`: 349 fast + 8 timing, 3 pictures, 3 checks; 1139 s): 349 pass, 8 fail, 0 skip. Caused by the PR: test_cooking_route (its pack-fill loop left hotbar slots empty); fixed in 34e884e, PASS there. Also failing on dev b922cc8: test_batch3_slots, test_den_sounds, test_heartbeat, test_sound_log, test_sound_panel (audio imports missing from the clone's copied `.godot`), test_flora_density (300 s timeout on both). test_npc_view: PASS then exit 139 at quit (known); clean PASS on rerun.
- Logs: `E:\Software\godotDev\hotbar01_run`, `hotbar01_focus2..4`, `hotbar01_recheck`, `hotbar01_devfails`, `hotbar01_cook2`.
- Merge of origin/dev 12cc665 into the branch: 6dbb744. Interaction check (test_hotbar_keys, test_craft_click, test_trade, test_goals, test_coin_icons, test_server_items, test_bulk_ops, test_carrying, test_cooking_route, test_inventory, test_new_player, test_first_hour, test_items_persistence, test_save_compat, game start smoke): NOT RUN. Dave stopped all testing at 00:19Z 13 Nov 2026.
- Independent review: round 1 FAIL (a660110), round 2 FAIL (d2a041c, one test bug), round 3 PASS subject to the broad run (9145d59).

## For Dave's next playtest
Drag an axe and a food stack into the hotbar: each leaves the backpack. Drag them back. Eat or sell the last of a hotbar stack: the slot empties. Pick up a new tool: it goes into the first empty hotbar slot.
