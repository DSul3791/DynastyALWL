# Handoff: moderator (written 1 Nov 2026, for Dave's new thread)

## Who does what
I (the moderator) speak for Dave to six Claude sessions building *Dynasty: a life well lived* (Godot 4.7.2, repo `C:\GodotProjects\DynastyALWL`, integration branch `DailyDev_20261029`).
Sessions (each has `docs/handoff/HANDOFF_<NAME>.md` and `SCOPE_<NAME>.md`; Flora is now MikeW and Guide is now Dino, files HANDOFF_MIKEW, SCOPE_MIKEW, HANDOFF_DINO, SCOPE_DINO): Sonny `local_587c50f9-8f3c-407c-87d7-a3036a8403de` (character, new water, branch `dynasty-water`), Kathleen `local_c740b1f4-16c4-419d-8656-6aa61fc30def` (art, branch `kathleen-art`), Sal `local_5acf21b9-d5bb-4acc-b4c0-136b9af48a6e` (items, `sal-items`), Tyler `local_bd919edd-0ed5-4c90-b383-326b855075f6` (systems, comfort, tests, `claude/tyler-gates-fee5f7`), Flora `local_038ad58f-e29c-4cdb-abef-887b84bdc70a` (plants and density, `claude/flora-density-v2`), Guide `local_c4dbf2fa-3207-4243-bef6-abb8c35c2d09` (first-hour playthrough, `claude/dazzling-elbakyan-e46f22`).

## Rules Dave set (do not re-litigate)
- NEVER merge to main until Dave has play-tested and says go. After his go: backup, merge the daily into main, final tests, start a fresh daily branch (e.g. `DailyDev_20261101`).
- Decide and document reversible choices in `MODERATOR_QA_LOG.md`; never let agents wait on Dave; Dave answers on the QA page (branch `qa`, worktree `C:/GodotProjects/DynastyALWL_qa`, cards in `questions/QUESTIONS.md`, one item per card, Yes/No, optional notes).
- Standing instruction (paused for the handoff): when an agent finishes, it invents three more tasks for its own job and does them, repeating until it honestly has none.
- Ponytail rules (`docs/PONYTAIL_RULES.md`) for the water build. Max 3 heavy Godot jobs (`tools/godot_slot.sh`). Do not kill Godot processes (one may be Dave's editor).
- The new water becomes the DEFAULT; the old water stays only behind a flag (`--water-old` plus a settings switch). Dave's words: if it does not work we remove the old one later.
- Death rule: `data/items/death.json` `novice_grace` is `always` until Dave answers QA card `death-novice` (recommended: respawn until level 5).

## State at handoff
- Daily head pushed: `f50d17f0` (+ local unpushed merge of `origin/dynasty-water`, commit `26a51f65`, clean merge, NOT tested after the merge, NOT pushed). Check `git log origin/DailyDev_20261029..HEAD`.
- Full test run on `27dfe828`: 159 of 159 pass (132 on the standard exe, 27 on the voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`; `test_water_soak` needs 900 s, takes 338 s). The world tests fail to compile on the standard exe: wrong build, not a bug.
- NEVER run the whole suite from the standard exe and call the 27 failures real.
- Never played in a real client by anyone but the agents' rigs: the join freeze fix (Tyler: server placed nine flora chunks on its main thread), the whole checklist, the lit fire, the creator preview are unconfirmed.
- Dave's play-test page: `MORNING_PLAYTEST_CHECKLIST.md` (14 steps), long version `_FULL.md`; step table `PLAYTHROUGH_STEP_STATUS.md`; status script `art/playthrough/run_status.sh` (24 fixed, 3 broken: F-01/F-24 recipes learnable, F-19 14 recipes blocked without future flag, S-craft flag mismatches; 2 need pictures F-10 held axe, F-13 blueberry).

## Known open items
1. Merge Sonny's water-default push (water2 default, `--water-old` flag, settings switch, lake sleep/cap, river drain) into the daily, then run the full test pass. Sonny will report the commit.
2. Merge each agent's final handoff push into the daily (branches above; Kathleen's pushed branch is `origin/kathleen-art`, not her worktree branch).
3. Chest self-test error `inventory_view.gd:4562` (Tyler); SLEEP self-test starts at full energy (test gap); creator preview picture (no rig flag found).
4. Pictures: lit campfire (Guide saw no flames; Tyler says it is drawn, hidden by grass), lying trunk after the bark fix, held axe, orchard and crown close-ups, white yarrow/chamomile, pale flower stems.
5. Dave's own: play-test the daily, answer `death-novice` and the pending picture cards, then say go for main.

## How to run things
```
GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>   # result in <out>/<test>.result
GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json   # plan: python3 tools/tests_for_diff.py origin/main HEAD --full > /tmp/plan.json
```
Merging tips: a Godot-generated untracked file (`.uid`, `crash_reports/telemetry_client.log`) can block a merge; delete just those and retry.

## Not checked by me
Anything in a real client; the merged water in any run; the creator; Dave's computer state (several Godot processes were open at handoff).
