# Guide findings for the moderator (1 Nov 2026, daily d05e86b3 / 27dfe828)
Format: what | evidence | suggested owner | severity. Paths are relative to the Guide worktree (branch claude/dazzling-elbakyan-e46f22).

| # | what | evidence | owner | severity |
|---|---|---|---|---|
| 1 | Lit campfire shows no flames or glow (stones in grass, green placement-style glow) | art/playthrough/world3/campfire_lit.png, QA card pic-fh-campfire-lit | Kathleen (looks) | high |
| 2 | Felled trunk looks dark and smooth, bark fix 993aafab not visible | art/playthrough/world3/fell_resting.png, QA card pic-fh-felled-trunk | Kathleen / MikeW (plants) | medium |
| 3 | Creator preview opens on the back of the body, plain colours | QA card pic-fh-creator; picture retake pending (tools/proto_creator_view.gd) | Sonny | medium |
| 4 | Chest self-test errors: Invalid access 'numbers' on Nil | src/client/inventory_view.gd:4562; smoke/logs/client_chest_shared_server.log | Tyler | medium |
| 5 | flora_view.gd:2270 _decimate_task invalid cast to PackedInt32Array | smoke/logs/client_eat.log | MikeW (plants) | medium |
| 6 | Sleep self-test starts at energy 100 so ACT_SLEEP is refused (test gap) | smoke/logs/fresh/client_sleep_fresh.log; inventory_view.gd ~4538 | Tyler (tests) | low |
| 7 | Shared-server self-tests leave pieces at the spawn, so later bed/snare tests fail "not set down" | smoke/logs/client_sleep.log, client_snare.log vs logs/fresh/ | Tyler (tests) | low |
| 8 | Placement refusals beyond 6 m, wet beach, fire gap, per-chunk cap give no message to the player (not re-tested after Tyler's changes) | art/playthrough/probe_place_output.txt ("silent") | Steve (systems) | medium |
| 9 | No tutorial step teaches the campfire pot or clay hearth, though the campfire now refuses plants | probe_cook_output.txt; TUTORIAL_FIRST_30_MIN.md | Sal (items) | medium |
| 10 | Steps 11-20 need ~62 sticks; playability bot budget is 60 and it stops before the bench | src/worldgen/tools/test_playability_bot.gd | Tyler (tests) | low |
| 11 | Camp bench (16 sticks, 6 twine, 4 stones, 60 s) and drink have no automated check | PLAYTHROUGH_STEP_STATUS.md rows 3, 20 | Tyler (tests) | low |
| 12 | Join freeze ~15 s on earlier heads; not seen in the 1 Nov smoke, unconfirmed by a person | smoke/logs/*.log, SMOKE_TEST.md | Tyler / Steve | high if it returns |
| 13 | Stale Godot processes from 31 Oct (10 headless, sal-items and ic_old worktrees) and all 3 slots held, which blocks windowed jobs | process list 1 Nov 05:27 | moderator | process |
| 14 | Lying under the 1.5 m lean-to roof, spawn on bed, sleep: server OK (16/16), never lain in via a real client | probe_shelter_output.txt | Guide (retest) | info |

## Phase 2 additions (1 Nov, daily 9ca75719)
| # | what | evidence | owner | severity |
|---|---|---|---|---|
| 15 | Grass hides a lit campfire: with grass off the fire shows flames and glow (small) | art/playthrough/phase2/campfire_lit_nograss.png, QA pic-p2-fire-nograss | Kathleen / MikeW (grass clearing around a placed fire) | high (row 1 is explained) |
| 16 | Creator preview still shows the back and patchy colours | phase2/4_undo_twice.png, QA pic-p2-creator | Sonny | medium |
| 17 | Rig fell picture is unusable (camera upside down over water, blank before frames), so bark fix is unconfirmed | phase2/fell_resting.png | Kathleen (shot_runner --shot-fell) | medium |
| 18 | --shot-stance=lie did not frame a lying body, so lying under the roof has no picture | phase2/lying_wide.png | Kathleen (rig) | low |
| 19 | Chop self-test once exited 10 s after join with no error (second run fine) | smoke/logs/client_chop.log first run | Tyler | low |
| 20 | Spawn rig "Tab bars" picture shows the F3 debug text, not the vitals bars | phase2/spawn_tab.png | Kathleen (rig) | low |
| 21 | Sleep self-test now PASSES on a clean server | phase2/client_sleep_clean.log | resolved (row 6) | info |

Not yet done (superseded by the Phase 2 table in PLAYTHROUGH_STEP_STATUS.md): creator picture, windowed rig walk of checklist steps 1-14, sleep test on a clean server with low energy.
