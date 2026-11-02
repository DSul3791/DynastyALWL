> **Update 2 Nov 2026 (Dave): there is no daily branch any more.** Where this document says "the daily" or `DailyDev_20261029`, read `origin/main`. Work on your own new branch each day (`claude/<name>-YYYYMMDD`) and open a PR. Bugs in `docs/BUGS_FOUND_IN_PLAY.md` come first. Rules: `docs/START_HERE.md`.

# Handoff: Steve: Systems (written 1 Nov 2026, paper only, no Godot run)

Read `SCOPE_STEVE.md` next to this: it has the sub-system inventory with line numbers, the plan and the finish line. Who gave me each item is named in brackets: [Tyler] [Sal] [Sonny] [Dino] [Kathleen] [Moderator] or [me] (my own read of the code at head `d3aa3c2a`).

## My role
Rules and code of the sub-systems: character system, comfort and Rested, food and drink, warmth, sleep and energy, lit-fire and fixture rules, placement rules, death and respawn rules, goal and hint triggers, stump and trunk. Branch `claude/steve-systems-4680f3`. The moderator merges it into `DailyDev_20261029`. I never merge to main.

## State
Docs only so far: `SCOPE_STEVE.md` (`7808d2e3`) and this file. No code changed, nothing in flight in code. Tyler's last edits (energy setter, stump, handoff) are claimed to be in the daily; I did not confirm.

## Exact next steps (after RESTART; before it, no Godot)
1. Re-run a baseline: Tyler's 7 aborted tests (`test_warmth test_edible_offer test_flora_density test_ingredient_groups test_look_table test_river_ore test_stairs_climb`) are his [Tyler]; I take only `test_warmth` red results. Diff lane for the energy setter: `python3 tools/tests_for_diff.py --paths src/stream/terrain_net.gd src/stream/server_items.gd src/client/inventory_view.gd tools/items_check.py > /tmp/plan.json && bash tools/run_tests.sh --plan /tmp/plan.json` [Tyler].
2. **Character identity** [me]: the client sends ONE key per computer (`inventory_view.gd:270`, `user://player_key.txt`); the server keeps recipes, goals, vitals, bed, Rested under it. Make hello carry a per-character key (active character id), keep the machine key as fallback for old saves; add server delete-character; test that two characters do not share state. Touches `terrain_net.gd` hello, `character_store.gd`, `character_select.gd`.
3. Write `docs/CHARACTER_SYSTEM.md` (map of create, save, load, delete, fields) [Tyler asked, `2fa66d8d`].
4. Small tests [Tyler list + me]: corrupt-record save-compat; `ACT_ADMIN_ENERGY` (admin only, non-admin changes nothing) plus a PROTOCOL.md note; `_pace_factor` and `warmth_target` Rested hooks; idle timeout quiet with a menu open; headless select-screen test; first-minutes smoke (no `items tick slow`).
5. Mutation checks `tools/mutation_check.sh` for comfort, goals, lights, dev-place, hints, novice grace (never run) [Tyler].
6. Placement: confirm the silent refusals (wet beach, fire gap, per-chunk cap) now speak; only "Too far to place that." is confirmed [Tyler, Dino]. Check `test_placement_notices` covers each.
7. Heavy kits (stone wall about 314 kg, brick wall, brick floor, fireplace): propose "build from nearby stock" as a placement rule with Sal; Dave decides [Sal].
8. Real death: write the question list for Dave from `DESIGN_IDEAS.md` 6.1 (heir, children, downed state, final-death client flow, remains marker, wizard retrieval); build after his answer [Tyler, me]. Until QA card `death-novice` is answered keep `always`.
9. Review Kathleen's light diffs she sends before she pushes (see below).

## Open bugs and risks
- Identity: all characters on one machine share one server record; delete leaves an orphan [me].
- Join: first-tick scatter about 0.75 s (`_scatter_around_players`); the 15 s freeze was not seen on `d05e86b3` but no person confirmed it; provisional open tree cover for a few seconds can make a bed under a canopy read uncovered [Tyler, Dino]. Tyler keeps this; I only watch for it in my smoke test.
- Chest self-test: `inventory_view.gd:4562` Invalid access 'numbers' on Nil, still failing at Sonny's last smoke rerun (`5b29b37e`) [Dino, Sonny]. Tyler's list says the chest was his; with systems moved it is a candidate for me, ask Tyler who takes it.
- Sleep and snare self-tests fail in a full shared-server run because earlier tests leave pieces at spawn (2.5 m `gap_m`); on a clean server the bed places. Sleep at full energy is refused by design (nap only with high exertion) [Dino, Tyler].
- `flora_view.gd:2270` cast error is MikeW's [Dino].
- Lit fire shows no flames in Dino's picture (QA card `pic-fh-campfire-lit`); server state 40 is right. Look is Kathleen's, first task after RESTART [Dino, Kathleen].
- Goal list has no protocol message or client list, notices only [me]. No pot or hearth tutorial step was open on 31 Oct; steps 23 and 24 now exist [Sal].
- Drinking at water, the pot, hearth, bench have never been driven in a real client [Dino].
- Berries 4 kcal and campfire-only-meat unplayed; lean-to 32 sticks pace unmeasured; steps 11 to 20 need 58 sticks of the bot's 60 [Sal].
- Smoke: startup freezes under load noted in `SMOKE_TEST.md` (Sonny's branch, not in my tree) [Sonny].

## Tests to run and which Godot
- Standard exe `C:\GodotInstaller\Godot_v4.7.2-stable_win64_console.exe` for data and most server tests; voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe` for WORLD tests and client scenes. Never judge a full suite on the standard exe [Moderator].
- One test: `GODOT_EXE=... tools/run_one_test.sh <test> 300 /tmp/o_<test>`; heavy jobs only via `tools/godot_slot.sh`, max 3.
- My tests, in `src/worldgen/tools/` [Tyler]: character `test_new_player test_new_player_day test_save_compat test_idle_timeout test_learn test_first_hour`; comfort `test_comfort`; warmth/sleep `test_warmth test_bed test_lean_to_bed test_weather`; fire `test_lit_fixture test_fire_state_look test_campfire_pot`; placement `test_placement_rules test_placement_notices test_leanto_collider test_dev_place test_placed_clearing`; death `test_death test_death_novice test_cavein_death`; goals `test_goals test_playability_bot`; stump `test_stump_chop test_trunk_cutting test_felling_time test_fell_pose`; food `test_eat_once`; client `python3 tools/items_check.py --godot <voxel exe> --only chest,gather,eat,leanto,sleep`.

## Read first
`SCOPE_STEVE.md`; `HANDOFF_TYLER.md`, `SCOPE_TYLER.md` (section 7); `docs/COMFORT_DESIGN.md`; `DESIGN_IDEAS.md` 6.1; `data/items/{death,comfort,vitals,cooking,hints,starter_goals,camp_goals}.json`; `PLAYTHROUGH_STEP_STATUS.md`; `art/playthrough/RIG_PLACE.md`; `docs/PONYTAIL_RULES.md`; in `server_items.gd`: `peer_connected_hello` 406, `kill` 6905, `_comfort_tick` 8365, `_hints_check` 8679, `_goals_check` 8832.

## Edges agreed with others
- Kathleen edits LOOK values only: `building_look.gd` `FIRE_LIGHT[tier]` (range, energy), the fixture spot cone (about line 995), inner glow omni (1009), fixture omni (1020), flame lights (1038, 1268), flame meshes and flicker; `held_item.gd` torch flicker (734, 1278) and hand light (1659-1669). She will NOT touch lit/unlit, fuel, warmth, `server_items.gd`, `structures.json` fire rows, item `light_m` (Sal/me), save state. She sends me each light diff before pushing; I review that it changes no rule [Kathleen].
- Character LOOK (stance, creator preview facing, character and loading pictures, generated body) goes to Kathreen; the store, records, learned recipes, goals, idle timeout and smoke tests are mine [Sonny].
- Tyler keeps tests, rigs, the join freeze, merge gates; I write one small test per rule [Tyler, Moderator].
- Stump: the server reads `drops.json` `stump.final_by_radius` (checked in `_stump_final_rows`, line 3969). Sal's note that it still reads only `final` is stale [me, Tyler].

## Decisions not to re-litigate
Novice grace is data-driven; Dave answered `death-novice` on 31 Oct: respawn at the bed until level 10, then real death (`death.json` now `level` 10, `best_skill`). Comfort: 0 to 20, radius 9 m, each kind once, Rested always 45 real minutes. Campfire cooks only meat and fish; berries 4 kcal. Lean-to 2.6 x 3.4, ridge 1.5. Stump is destroyed and gives firewood, kindling, sticks. Fire LOOKS are Kathleen's. Items are retired, never deleted. Never merge to main. Max 3 Godot jobs. Ponytail rules, one small test per logic. Standing instruction: when done, invent three more tasks and do them [Tyler, Sal, Moderator].

## Skipped or not verified
No Godot run. Nothing played in a real client. I did not read `terrain_client.gd`, `game_menu.gd`, vitals, sickness, crafting queue, skills, fishing, farming bodies. All "works" statements are the other agents' claims. Sonny's `SMOKE_TEST.md` and `src/client/character/` internals were not read.

## Phase 1 progress and backlog (1 Nov 2026, closing plan; nothing below was run: no Godot)
Done and pushed on `claude/steve-systems-4680f3` (written, NOT run; tests waiting for Phase 2):
- Per-character server key + delete-character, protocol 82: `character_keys.gd`, `forget_key` in server_items, `forget_character` rpc, `test_character_keys.gd`. First character to play after the update adopts the old machine key (existing progress kept). Risk: admin.json lists keys, a non-adopted character has a NEW key and is not admin until its key (Esc > Advanced, Show my player key) is added.
- Bed respawn port: landing search and the third-death fallthrough on the existing `spawn_bed` (`bed.json` `respawn`); checks added to `test_lean_to_bed.gd` (the planned `test_bed_respawn.gd` was folded in there). Old claim-by-lying dropped.
- Placement: the only silent exit was ground-not-streamed-in; now says so. `test_placement_notices.gd` gained that case and the per-chunk fire cap.
- `death.json` set to Dave's answer (level 10); `test_death_novice` updated.
- Stack caps: ported to branch `claude/steve-stack-caps` (clean-ish cherry-pick of Sal's `39a03c5c`, 236 stack-1 items flagged by script). NOT merged into this branch because it changes inventory counts everywhere. Next step in Phase 2: run `test_server_items`, `validate_items`, `test_save_compat`, inventory items_check on that branch; if green ask the moderator to merge it. Rollback rule: never go back to a cap without Dave. Owner: me. Why held: core inventory change, unrun.
- Old plans archived to `docs/archive/old_branch_plans/` (stack caps, fire tiers, auto pickup, thatch sources, building tiers plan and table, bed respawn).
- QA cards written on branch `qa` (commit `656580b0`): `death-before-heirs`, `death-new-start`, `death-downed-state`. The card `heavy-kits-carry` already exists (Sal) with option A recommended.

Backlog with owner, exact next step, why:
1. **Heavy kits, option A** (waits on Dave's `heavy-kits-carry`): craft from stock lying within 3 m of the workbench. Owner me. Next step: copy the pattern of `_pull_nearby_logs` and `logs_near_count` (server_items.gd about 8914..8948) into `_queue_craft` for the four kits (stone wall, fireplace, brick wall, brick floor), data flag `near_stock` on those recipes (Sal). Test: a craft with 12 blocks on the ground within 3 m and an empty pack succeeds.
2. **Bridges** (`art/BUILDING_TIERS_PLAN.md` section 7, archived): 18 kits by tier and size 5/10/20 m. Owner me (rules, placement, flood wash-out), Sal (`tools/gen_bridges.py`, item numbers), Kathleen (meshes), Sonny (flow numbers for the flood rule, his water2). Next step: after water2 is the default and Dave's play-test is done, Sal generates the rows from the table; I add the `bridge` kind to `placement_rules.gd` and the server wash-out check. Why not now: needs new item and state numbers (the old plan's numbers collide with furniture 487+ and states 59 to 73), art, and Sonny's flow data.
3. **Plank tier and thatch window** (`BUILDING_TIERS_TABLE.md`, archived): branch `sal-building-tiers-p1` cannot be cherry-picked, its item numbers 350 to 375 and states 48 to 61 are in use today. Owner Sal (re-number from `next_number` in items.json, free states from 74), me (new state kinds in `structures.json`, `thatch_doorway` open kind), Kathleen (looks, 8 new models). Next step: Sal regenerates the table with free numbers; then I wire states. Not a Dave question: the tiers were his rule (09:06).
4. **Real death build**: after Dave answers the three cards. Death screen, new-character flow, remains marker, then children and heirs (`DESIGN_IDEAS.md` 6.1, 6.2, 6.6, 6.7). Owner me.
5. **Fire tiers rule** (Sal's card pending): code is built (3 tiers). If Dave says a different piece count, change `_fire_best_state` (server_items.gd) and `cooking.json`.

## Phase 2 results (1 Nov 2026, run on the standard exe; world tests on the voxel build)
- Branch `claude/steve-systems-4680f3`: `test_character_keys`, `test_placement_notices`, `test_death_novice`, `test_lean_to_bed` PASS (lean_to_bed after two spawn-bed distance checks were widened for the landing ring). The diff-lane run (155 tests) gave 133 pass and 22 fail; all 22 failures were world tests compiled on the standard exe (no VoxelBuffer), and all 22 PASS on the voxel build.
- Branch `claude/steve-stack-caps` (head `7d771061`): `test_server_items`, `validate_items` (after flagging snare, javelin, candle unstackable: javelins and candles no longer stack, a behaviour change), `test_inventory` (expectation updated: 45 stone in one slot), `test_save_compat`, `test_goals`, `test_learn`, `test_comfort`, `test_death`, `test_new_player`, `test_eat_once`, `test_logs_carry`, `test_trunk_cutting`, `test_stump_chop`, `test_dishes`, `test_blueprints`, `test_auto_craft`, `test_first_hour`, `test_craft_menu`, `test_economy_guard` PASS. Not run: client scenes (items_check chest, gather, eat, leanto, sleep), a rig join, the slot-count label (12.3k above 9,999) in a real client. The moderator can merge it once he is happy with that; rollback rule: never go back to a cap without Dave.
- Not run: a real join with per-character keys (the delete path over the network, the forget rpc) and the select screen delete. Next step: one windowed join with two characters, then delete one.

## Real death flow (1 Nov 2026, later)
Built and OFF: `death.json real_death` false. Server marks `dead`, sends `final_death` (protocol 83), no respawn; `src/client/death_screen.gd` shows the screen and sends the player to character select with the dead character deleted from the machine. Test `test_real_death`. Waits on Dave: death-before-heirs (recommended: keep respawning, so leave it off), death-new-start, death-downed-state. Heirs, children, remains marker on the map, wizard retrieval and the downed state are not built.
