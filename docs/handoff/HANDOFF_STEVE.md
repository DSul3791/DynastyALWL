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
Novice grace stays data-driven, default `always` until Dave answers `death-novice` (recommended: level 5). Comfort: 0 to 20, radius 9 m, each kind once, Rested always 45 real minutes. Campfire cooks only meat and fish; berries 4 kcal. Lean-to 2.6 x 3.4, ridge 1.5. Stump is destroyed and gives firewood, kindling, sticks. Fire LOOKS are Kathleen's. Items are retired, never deleted. Never merge to main. Max 3 Godot jobs. Ponytail rules, one small test per logic. Standing instruction: when done, invent three more tasks and do them [Tyler, Sal, Moderator].

## Skipped or not verified
No Godot run. Nothing played in a real client. I did not read `terrain_client.gd`, `game_menu.gd`, vitals, sickness, crafting queue, skills, fishing, farming bodies. All "works" statements are the other agents' claims. Sonny's `SMOKE_TEST.md` and `src/client/character/` internals were not read.
