# BLOCKER-001 results: Admin Reset world

Brief and design calls: `BRIEF.md`. Branch `claude/project-thread-o138r7` from dev `27d27fbbb`, clone `E:\Software\godotDev\reset01` (Dave's checkout and saves untouched). All runs on Dave's PC (ManlandRyzen5), voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`.

## Change
- `src/stream/server_items.gd`: `ACT_RESET_WORLD` branch (admin check, `reset_world()`, then `reset_terrain_edits`, everyone told) and `reset_world()`.
- `src/stream/terrain_net.gd`: `ACT_RESET_WORLD := 79` (new kind, no protocol change).
- `src/client/game_menu.gd`: Esc > Admin > "Reset world (terrain, dropped items, buildings)" -> confirmation page ("Yes, reset the world" / "No, keep it").
- `scenes/terrain_server/terrain_server.gd`: testing flag `--dev-reset-world=S` (command line only).
- Tests: new `src/worldgen/tools/test_reset_world.gd`; new store tool `src/worldgen/tools/reset_world_store.gd`.

## Tests run
1. **`test_reset_world` (new): PASS.** Drop from the pack and a drop 3 km out; dig, fill and a far dig in the edit log; foundation, wall, door, floor, bed, workbench, chest with contents, lit campfire, tilled bed with a crop, far chest; a dead player's remains. Non-admin refused, nothing changed. Admin reset: 0 player rows left, chests and crop gone, edit log empty, walk grid clear; scatter, boulder, picked marks, sapling, remains, pack, vitals, skills, fitness, learned recipes, coins kept; building and dropping work after. Restart (new server over the same store): nothing removed came back; character and remains kept.
2. **Real terrain server, throwaway store, twice (before and after the remains fix): PASS.** `reset_world_store.gd --seed` (12 rows, 3 edits) -> server with `--dev-reset-world` ("12 world rows removed", no terrain reset error, clean quit) -> `--check` RESET_STORE_OK -> plain server restart -> `--check` RESET_STORE_OK (rows 0, chests 0, crops 0, edits 0, character kept). Store dirs `E:\Software\godotDev\reset01_store_a`, `_b`.
3. **Game start smoke**, `--role=play --test` with `APPDATA` pointed at `E:\Software\godotDev\reset01_appdata` (so the server did not open Dave's live store): world joined, ground answered; exit 139 at quit (known, pre-existing).
4. **Risk-based existing tests (Dave 19:39: terrain persistence, construction, drops, characters, reset): all PASS.** test_ground_ops, test_persistence_drills, test_items_persistence, test_save_compat, test_placement_rules, test_server_items, test_building_wear, test_blueprints, test_dev_place, test_station_storage, test_storage_locks, test_handcart, test_farming, test_water_pieces, test_traps, test_fire_store, test_felled_stays_gone, test_tunnel_watch, test_death, test_real_death, test_inventory, test_skills, test_new_player, test_character_keys, test_corrupt_character, test_admin_mode_crafting, test_mission001_walkthrough, test_test_flag, test_feel_intensity (loads game_menu). Most ran inside a broader run on `66b918e7c` that was stopped at Dave's request; the later commit changes only the reset itself, which test 1 and 2 reran.
5. The stopped broader run: 283 of 357 finished; 277 PASS, 6 FAIL: test_npc_view (known flake) and five audio tests (test_batch3_slots, test_den_sounds, test_heartbeat, test_sound_log, test_sound_panel) that fail on missing audio imports in the clone's copied `.godot` (environment, no audio code touched). The rest of the suite is to be run later (Dave).

## Independent review
Read-only gate reviewer on `66b918e7c`. Finding 1 (remains held the dead character's pack and purse and were deleted) **fixed**: remains are kept, with a test. Background-write race: checked safe. Admin bypass: none (fails closed). Character data: untouched. Client sync: removed rows go by the normal world sync, ground by `ground_reset`. No regressions seen.

## Revision 2 (Dave 20:09: the world as before anyone played)
- Code: `drop_world_made` and the saved `world_rows` key; `reset_world` restores natural content; `server_flora.restore_all`; the server wires goblin piles, gifts and thief loot to `drop_world_made`.
- `test_reset_world` (extended: den pile kept, felled trunk gone and trees restored, scatter re-laid, picked, boulder, bog and plant marks cleared, saplings gone, all held after a restart): PASS.
- Real server, throwaway store `E:\Software\godotDev\reset01_store_c` (seed adds a den pile, picked scatter, a mined boulder and two flora removals): reset then `--check` RESET_STORE_OK (world_piles 1, felled_chunks 0, taken 0), plain restart then `--check` RESET_STORE_OK again.
- Focused existing tests, 32 PASS: test_felled_stays_gone, test_trunk_cutting, test_stump_chop, test_fell_autosplit, test_fruit_tree, test_shrub_work, test_flora_near_water, test_bog_iron, test_bog_rows, test_shore_gather, test_nests, test_goblin_den_life, test_goblin_stealing, test_goblin_friendship, test_thieves, test_items_persistence, test_save_compat, test_persistence_drills, test_server_items, test_ground_ops, test_death, test_real_death, test_mission001_walkthrough, test_dev_place, test_placement_rules, test_storage_locks, test_handcart, test_farming, test_skills, test_new_player, test_test_flag, test_reset_world.

## Limitations (open)
- Admin check: local play has `check_admin` false (`data/items/admin_setting.json`), so everyone is an admin there, as for every admin action. Must be true before any public server.
- The button and confirmation page are **not visually checked** (no windowed run); the server path is tested.
- (Revision 2 fixed: trees, plants and scatter are restored; den piles, gifts and loot are kept.) Den piles saved before revision 2 carry no mark and go once. Animals are not reset. Materials deposited in an unfinished blueprint site are lost with the site.
- The reset runs in one server frame (synchronous saves plus the terrain reload); a hitch on a big world is likely and not measured.
- If the terrain log could not be rewritten the server prints an error but players are still told the ground is rebuilding; pressing the reset again retries.
- `.prev` backups of the store files keep the pre-reset world until the next save (read only if a main file is corrupt).
