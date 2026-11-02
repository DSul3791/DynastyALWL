# Handoff: moderator (written 1 Nov 2026, for Dave's new thread)

## Who does what
I (the moderator) speak for Dave to ten Claude sessions (roster below; roles in `docs/START_HERE.md`) building *Dynasty: a life well lived* (Godot 4.7.2, repo `C:\GodotProjects\DynastyALWL`, integration branch `DailyDev_20261029`).
Sessions (each has `docs/handoff/SCOPE_<NAME>.md`, most also `HANDOFF_<NAME>.md`; roles changed on 1 Nov, current ones in `MODERATOR_QA_LOG.md`: Sonny (terrain and water mechanics), Kathleen and Kathreen (all looks), Sal (items), MikeW (plant and animal density, placement, behaviour), Steve (sub-system rules and code), Tyler (Q&A testing and tooling), Dino (playthrough guides), Jason (audio), Jamie (documentation)). Original six with their ids: Sonny `local_587c50f9-8f3c-407c-87d7-a3036a8403de` (was character and water, now terrain and water only; branch `dynasty-water`), Kathleen `local_c740b1f4-16c4-419d-8656-6aa61fc30def` (art, branch `kathleen-art`), Sal `local_5acf21b9-d5bb-4acc-b4c0-136b9af48a6e` (items, `sal-items`), Tyler `local_bd919edd-0ed5-4c90-b383-326b855075f6` (was systems; now Q&A testing and tooling, `claude/tyler-gates-fee5f7`; systems went to Steve), MikeW (formerly Flora; plants, animals) `local_038ad58f-e29c-4cdb-abef-887b84bdc70a` (`claude/flora-density-v2`), Dino (formerly Guide; playthrough guides) `local_c4dbf2fa-3207-4243-bef6-abb8c35c2d09` (`claude/dazzling-elbakyan-e46f22`). Added 1 Nov: Kathreen `local_5dc173d8-f090-4d75-9439-07b664414c73`, Steve `local_16c649fd-4cf3-45d8-9229-7147ddb99bda`, Jason `local_03596a68-5437-46d5-882b-8096718f4d2b`, Jamie (documentation).

## Rules Dave set (do not re-litigate)
- NEVER merge to main until Dave has play-tested and says go. After his go: backup, merge the daily into main, final tests, start a fresh daily branch (e.g. `DailyDev_20261101`).
- Decide and document reversible choices in `MODERATOR_QA_LOG.md`; never let agents wait on Dave; Dave answers on the QA page (branch `qa`, worktree `C:/GodotProjects/DynastyALWL_qa`, cards in `questions/QUESTIONS.md`, one item per card, Yes/No, optional notes).
- Standing instruction (applies to ALL agents, including those started later; during the closing pass agents worked only until their list was done): when an agent finishes, it invents three more tasks for its own job, writes them down, does them, and repeats until it honestly has none. Never go idle waiting for the moderator.
- Ponytail rules (`docs/PONYTAIL_RULES.md`) for the water build. Max 3 heavy Godot jobs (`tools/godot_slot.sh`). Do not kill Godot processes (one may be Dave's editor).
- The new water becomes the DEFAULT; the old water stays only behind a flag (`--water-old` plus a settings switch). Dave's words: if it does not work we remove the old one later.
- Death rule: Dave ANSWERED `death-novice` on 31 Oct: respawn at the bed until level 10, then real death (dynasty). Steve sets `data/items/death.json` `novice_grace` to level 10 (commit 3f51ccd6 on his branch, unrun); the client flow for a real final death is not built yet. New death cards for Dave (QA branch): death-before-heirs, death-new-start, death-downed-state.

## State at handoff (1 Nov 2026, end of day)
- Daily `DailyDev_20261029` has every agent's verified work merged and is pushed (`git log -1 origin/DailyDev_20261029`). All data JSON parses. Nothing is merged to main; Dave fetches the daily and tests it himself, then says go.
- Tests: Tyler's full pass on `a4443f1d` (voxel build, 645 s): 164 tests, 163 pass; the one fail (`test_trade`, forty stones) is superseded by the stone-lot rule and passes. A delta pass on the final daily was run after (see Tyler's last report). Items_check chest/sleep/gather/eat/leanto/snare pass; 3 rig joins: no crash report, no SLOW RPC, no stall.
- Water: the new water is the DEFAULT (`water-default-flip` merged; `--water-old` and Esc > Settings > Gameplay "Old water" switch). Nobody has clicked the switch in a real game: Dave's play-test item. Water LOOK (flow channel, sea/river retakes) is not built: Sonny supplies depth/flow, Kathreen owns the look; Kathreen's untested `sea_slope`/emission edits are NOT merged.
- Join: the 6 to 8 s stall is fixed (near_water by native find). A rig join still shows stalls from the client competing for the CPU; a bot-only join has 3. The ~32 s join in the rig is mostly rig overhead (a fixed 30 s sleep).
- Stones sell in lots of 5 (`sell_lot` in `items.json`); cheap gathered goods have lots so a 4-hour day earns about 195 copper (`docs/ECONOMY_FIRST_DAY.md`; pick rates are guesses, Dave to time gathering and correct). Death: respawn at the bed until level 10, then real death (`death.json`; the client flow for a real final death is not built).
- Branches: remote cleaned from 398 to about 50. `FINAL_delete_now.txt` (28) is in `E:\Software\godotDev\DynastyALWL_ProjectBackups\worktree_leftovers_2026-11-01\`: Dave runs `git push origin --delete` on it (agent permissions blocked it). Kept on purpose: the terrain bake set (`lake-lip`, `pond-notch`, `land-types*`, `steve-spring-feed`, `terrain-bake-set`; needs Dave's answer on QA card `bake-terrain-set-1`; unbaked) and the ground PBR pair (`kathleen-photoreal-batch1`, `mike-pbr-ground`; port only if the ground reads flat).
- The 8.6 GB bundle `all_branches_before_cleanup_2026-11-01.bundle` and the `worktree_leftovers_2026-11-01` folder are backups Dave may delete.

## Second art agent (started 1 Nov)
"Kathreen: Art assistant" (session local_5dc173d8-f090-4d75-9439-07b664414c73): water look, character look, animals and plants look. Her scope: `docs/handoff/SCOPE_KATHREEN.md`.

## Final state (1 Nov, about 20:00; added by Jamie from the branch list and the moderator's message)
- Daily head when written: `a96dae1f` (`git log -1 origin/DailyDev_20261029` is the truth).
- **Stuck-slot warning:** three hung headless Godot scripts were holding the `tools/godot_slot.sh` slots. Never start a Godot run without a timeout (`run_one_test.sh <test> <seconds>`, or `timeout N`). Do not kill Godot processes blindly (one may be Dave's editor); check which ones are the hung scripts first.
- **Held back, NOT in the daily** (checked with `git rev-list`, commits ahead of the daily): `terrain-bake-set` (13; lake lip, land types, spring feed, pond notch: needs Dave's bake go, card `bake-terrain-set-1`), `claude/mike-pbr-ground` (2; CC0 ground-texture sets plus the download list), `claude/kathree-art-20c939` (Kathreen's work incl. the water emission look, untested), `water-flow-channel` (1; protocol 84 flow-channel texture for the water), `qa` (Dave's question page; never merged into the daily or main) and `qa-poke` (1; a standing PR that must never be merged).
- Open questions for Dave: the cards on the QA page (branch `qa`, `questions/QUESTIONS.md`), the list in "Known open items" 1 below; the real-death cards (`death-before-heirs`, `death-new-start`, `death-downed-state`) are unanswered and `real_death` stays false in `death.json`.

## Known open items
1. Dave: fetch and test the daily; click the Esc water switch; time gathering (sticks per minute); answer the QA cards: `bake-terrain-set-1`, `first-day-lots`, `sell-lots-value1`, `heavy-kits-carry`, `death-before-heirs`, `death-new-start`, `death-downed-state`, fire tiers, lean-to pace, plus the picture cards; run the delete command; say go for main (then backup, merge, tests, new daily branch).
2. Backlogs (owner, next step, why): `docs/KATHLEEN_NEXT_TASKS.md`, `docs/FLORA_NEXT_TASKS.md`, `docs/TERRAIN_WATER_BACKLOG.md`, `docs/handoff/JASON_NEXT_TASKS.md`, `docs/TYLER_NEXT_TASKS.md`, `HANDOFF_STEVE.md`, `HANDOFF_KATHREEN.md`, `SCOPE_SAL.md` section 7. Open examples: lying trunk and orchard pictures, fire look pass, water look, bridges, plank tier, real-death build, wiring remaining sound hooks, fauna tuning, client check for bench and drink.
3. Doc housekeeping: six dead links left to owners (`MODEL_INVENTORY` etc., see DOC_MAP); Jamie's rhythm after the next batch of changes.

## How to run things
```
GODOT_EXE=/c/GodotInstaller/Godot_v4.7.2-stable_win64_console.exe tools/run_one_test.sh <test> 300 /tmp/o_<test>   # result in <out>/<test>.result
GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe tools/run_tests.sh --jobs 3 --out /tmp/run --plan /tmp/plan.json   # plan: python3 tools/tests_for_diff.py origin/main HEAD --full > /tmp/plan.json
```
Merging tips: a Godot-generated untracked file (`.uid`, `crash_reports/telemetry_client.log`) can block a merge; delete just those and retry.

## Not checked by me
Anything in a real client; the merged water in any run; the creator; Dave's computer state (it was being restarted at handoff).
