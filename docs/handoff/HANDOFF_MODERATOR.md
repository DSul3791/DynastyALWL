# Handoff: moderator (written 1 Nov 2026, for Dave's new thread)

## Who does what
I (the moderator) speak for Dave to ten Claude sessions (roster below; roles in `docs/START_HERE.md`) building *Dynasty: a life well lived* (Godot 4.7.2, repo `C:\GodotProjects\DynastyALWL`, integration branch `DailyDev_20261029`).
Sessions (each has `docs/handoff/SCOPE_<NAME>.md`, most also `HANDOFF_<NAME>.md`; roles changed on 1 Nov, current ones in `MODERATOR_QA_LOG.md`: Sonny (terrain and water mechanics), Kathleen and Kathreen (all looks), Sal (items), MikeW (plant and animal density, placement, behaviour), Steve (sub-system rules and code), Tyler (Q&A testing and tooling), Dino (playthrough guides), Jason (audio), Jamie (documentation)). Original six with their ids: Sonny `local_587c50f9-8f3c-407c-87d7-a3036a8403de` (was character and water, now terrain and water only; branch `dynasty-water`), Kathleen `local_c740b1f4-16c4-419d-8656-6aa61fc30def` (art, branch `kathleen-art`), Sal `local_5acf21b9-d5bb-4acc-b4c0-136b9af48a6e` (items, `sal-items`), Tyler `local_bd919edd-0ed5-4c90-b383-326b855075f6` (was systems; now Q&A testing and tooling, `claude/tyler-gates-fee5f7`; systems went to Steve), MikeW (formerly Flora; plants, animals) `local_038ad58f-e29c-4cdb-abef-887b84bdc70a` (`claude/flora-density-v2`), Dino (formerly Guide; playthrough guides) `local_c4dbf2fa-3207-4243-bef6-abb8c35c2d09` (`claude/dazzling-elbakyan-e46f22`). Added 1 Nov: Kathreen `local_5dc173d8-f090-4d75-9439-07b664414c73`, Steve `local_16c649fd-4cf3-45d8-9229-7147ddb99bda`, Jason `local_03596a68-5437-46d5-882b-8096718f4d2b`, Jamie (documentation).

## Rules Dave set (do not re-litigate)
- NEVER merge to main until Dave has play-tested and says go. After his go: backup, merge the daily into main, final tests, start a fresh daily branch (e.g. `DailyDev_20261101`).
- Decide and document reversible choices in `MODERATOR_QA_LOG.md`; never let agents wait on Dave; Dave answers on the QA page (branch `qa`, worktree `C:/GodotProjects/DynastyALWL_qa`, cards in `questions/QUESTIONS.md`, one item per card, Yes/No, optional notes).
- Standing instruction (applies to ALL agents, including those started later; paused during the handoff hold): when an agent finishes, it invents three more tasks for its own job, writes them down, does them, and repeats until it honestly has none. Never go idle waiting for the moderator.
- Ponytail rules (`docs/PONYTAIL_RULES.md`) for the water build. Max 3 heavy Godot jobs (`tools/godot_slot.sh`). Do not kill Godot processes (one may be Dave's editor).
- The new water becomes the DEFAULT; the old water stays only behind a flag (`--water-old` plus a settings switch). Dave's words: if it does not work we remove the old one later.
- Death rule: `data/items/death.json` `novice_grace` is `always` until Dave answers QA card `death-novice` (recommended: respawn until level 5).

## State at handoff (1 Nov 2026, end of day)
- Daily `DailyDev_20261029` is fully merged with every agent's latest work and pushed (head after Jamie's last merge; `git log -1 origin/DailyDev_20261029`). All 104 data JSON files parse.
- Last full test run: 159 of 159 pass on `27dfe828` (132 on the standard exe; 27 world tests on the voxel build `C:\GodotInstaller\godot.windows.editor.x86_64.exe`; `test_water_soak` needs about 340 s). NOT re-run after the day's later merges (Dave needed the computer, then a Godot hold). Running them is the first job after RESTART; Tyler runs the full pass now (moved from the moderator).
- Never played in a real client by anyone but the agents' rigs: the join freeze fix, the checklist, the lit fire, the creator preview are unconfirmed.
- The new water is merged as CODE (`src/water2/`) but the old water is still the DEFAULT: the default flip is only a parked patch `docs/handoff/water_default_flip.patch` (six tests passed with it applied; `test_water_soak` did not finish). Sonny applies it first after RESTART.
- Dave's play-test page: `MORNING_PLAYTEST_CHECKLIST.md` (14 steps), long version `_FULL.md`; step table `PLAYTHROUGH_STEP_STATUS.md`; findings `docs/handoff/FINDINGS_REPORT.md` (Dino, 14 rows, each handed to an owner).
- Hold: every agent is on a no-Godot hold until the moderator sends RESTART (Dave was restarting his computer and killing stale Godot processes).
- Branches: remote cleaned from 398 to 43. Deleted: 265 merged plus 89 owner-approved drops (Dave ran the delete commands; the agents' permission rules blocked them). Kept: the PORT/backlog branches listed in `docs/OLD_BRANCH_REVIEW.md` (owners port, then delete), active agent branches, `main`, the daily, `qa`, `qa-poke`. Open: `claude/flora-density` and `sonny-character` (recent, ask MikeW and Sonny). 6 leftover worktrees removed (safety copies in `E:\Software\godotDev\DynastyALWL_ProjectBackups\worktree_leftovers_2026-11-01\`; full branch bundle `all_branches_before_cleanup_2026-11-01.bundle`, 8.6 GB, deletable).

## Second art agent (started 1 Nov)
A second art agent, "Kathreen: Art assistant" (session local_5dc173d8-f090-4d75-9439-07b664414c73, branch kathree-art), started 1 Nov 2026 at Dave's word; her scope document is docs/handoff/SCOPE_KATHREEN.md. See MODERATOR_QA_LOG.md 2026-11-01.

## Known open items
1. RESTART, then in this order: Sonny applies the water-default patch and runs his water tests (`test_water_soak` 900 s); Tyler runs the full test pass and re-runs the 7 tests killed by the Godot kills (`test_warmth`, `test_edible_offer`, `test_flora_density`, `test_ingredient_groups`, `test_look_table`, `test_river_ore`, `test_stairs_climb`); Dino runs the creator picture, rig walks and clean-server sleep test; then pictures (Kathleen: campfire flames first, lying trunk, orchard; Kathreen: water look, yarrow, blueberry, creator).
2. Ports from the old-branch review (owners keep their branches until ported): see `docs/OLD_BRANCH_REVIEW.md`. Bake-changing set (`lake-lip`, `pond-notch`, `steve-spring-feed`, land types) needs ONE bake proposal and Dave's go, after the water.
3. Chest self-test error `inventory_view.gd:4562` (Tyler); creator preview facing front and plain colours (Kathreen); Steve's first jobs: per-character key plus delete-character (existing saves share one key per computer), real-death question list for Dave, placement refusal messages, bed respawn landing search (`steve-bed-respawn`).
4. Questions for Dave: `death-novice` (QA card), the heavy stone wall kit (a 75 kg player carries about 52 kg; kit needs about 314 kg), 3 pieces per fire tier, pending picture cards, whether to keep `claude/flora-density` and `sonny-character`.
5. Dave's own: play-test the daily, answer the cards, then say go for main (backup, merge, final tests, new daily branch).
6. Doc housekeeping: `RULES.md` (October build-number flow, marked out of date) and `HANDOFF.md` (29 Oct state) still contradict the daily-branch flow; Jamie's fuller review after RESTART.

## How to run things
```
GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>   # result in <out>/<test>.result
GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json   # plan: python3 tools/tests_for_diff.py origin/main HEAD --full > /tmp/plan.json
```
Merging tips: a Godot-generated untracked file (`.uid`, `crash_reports/telemetry_client.log`) can block a merge; delete just those and retry.

## Not checked by me
Anything in a real client; the merged water in any run; the creator; Dave's computer state (it was being restarted at handoff).
