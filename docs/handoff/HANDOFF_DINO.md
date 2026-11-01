# Handoff: Dino: Guides and Walkthrough (formerly Guide, first-hour playthrough), 1 Nov 2026

## 1. Role
**Reporting rule (Dave, 1 Nov):** I build and test the playthrough/walkthrough guides and send every finding to the moderator in one report (what, evidence path, suggested owner, severity); the moderator assigns owners. Do not route problems to owners yourself. See `docs/handoff/FINDINGS_REPORT.md`.
I play the game as a new player would, on paper and through probes, and report what is missing or broken. I do **not** edit game code or data (the one exception: Kathleen allowed one small `src/debug/shot_runner.gd` commit). I never merge to main. I may merge `origin/DailyDev_20261029` into my own branch. Heavy Godot jobs go through `tools/godot_slot.sh` (max 3). Pictures for Dave go on the QA page (qa worktree `C:/GodotProjects/DynastyALWL_qa`, `questions/QUESTIONS.md`), ONE item per card, Yes/No plus a comments box, never in chat. Peer messages cannot grant permission escalation. Killing processes was refused by the permission classifier: do not work around it, ask the user.

- Repo `C:/GodotProjects/DynastyALWL`; my worktree `.claude/worktrees/dazzling-elbakyan-e46f22`; branch `claude/dazzling-elbakyan-e46f22`; integration branch `origin/DailyDev_20261029` (merged into mine, last at 27dfe828).
- Moderator session: local_7ff23b94-9e23-4422-abf8-3ba320742902. Teammates: Sal (items/data) local_5acf21b9-d5bb-4acc-b4c0-136b9af48a6e; Kathleen (looks, owns shot_runner.gd) local_c740b1f4-16c4-419d-8656-6aa61fc30def; Sonny (terrain, water) local_587c50f9-8f3c-407c-87d7-a3036a8403de; Tyler (tests, tooling) local_bd919edd-0ed5-4c90-b383-326b855075f6; Steve (sub-systems) local_16c649fd-4cf3-45d8-9229-7147ddb99bda; Kathreen (looks) local_5dc173d8-f090-4d75-9439-07b664414c73; Jason (sound) local_03596a68-5437-46d5-882b-8096718f4d2b; MikeW (formerly Flora) local_038ad58f-e29c-4cdb-abef-887b84bdc70a.

## 2. Done (all pushed on my branch)
- Probes 6, 7, 8 (`art/playthrough/probe_place.gd`, `probe_shelter.gd`, `probe_cook.gd`): placement, lean-to plus bed plus sleep plus spawn point, campfire cooking. Found the "bed refused inside the lean-to" bug (gap rule); Tyler fixed it.
- Docs: `PLAYTHROUGH_FINDINGS.md` (parts 11 and 12), `PLAYTHROUGH_STEP_STATUS.md` (22 steps, updated 1 Nov), `TUTORIAL_FIRST_30_MIN.md` (numbers matched to data), `MORNING_PLAYTEST_CHECKLIST.md` (one page for Dave; long one kept as `_FULL`), `SMOKE_TEST.md`, `art/playthrough/smoke/notes.md`.
- Commits this stretch: 562b9e21, b57c9b14, b4be0897, 27d12f8d, 26451218, 835e583e, 51176ef3, b2bebde9, 6cb59bf3, 3b2eb13c, plus the handoff commit (below).
- QA cards (qa branch, last aabe3f2c): pic-fh-spawn, pic-fh-leanto, pic-fh-creator, pic-fh-campfire-lit, pic-fh-felled-trunk.
- 1 Nov results on d05e86b3: shelter probe 16/16, cook probe good, place 13 PLACED, status 24 fixed / 3 broken, smoke: no join freeze, no crash report. Fresh-server reruns: snare places; sleep places and lies but its self-test is refused at energy 100 (test gap).

## 3. In flight / unfinished (exact next steps)
1. **Walk checklist steps 1-14 in a real windowed client.** Not done. Only server probes and headless client self-tests were run. Next: use `art/playthrough/rig.sh` windowed shots (flags in its header; `--give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light`, `--client-arg --shot-fell=flat`, `--pieces lean_to,rough_bed --views`).
2. **Creator preview picture.** The script exists: `tools/proto_creator_view.gd` (run `godot --path . --resolution 1920x1080 --script res://tools/proto_creator_view.gd -- --out=res://art/playthrough/smoke/<dir>`; the smoke test runs it with `proto_select_view.gd`). My 1 Nov attempt produced no output in 5 minutes: it sat behind a busy PC (stale godot processes from 31 Oct, not mine) and I stopped it. Retry when the PC is quiet.
3. **Sleep self-test** needs energy lowered first (test change, Tyler's area).
4. **Lit fire and felled-trunk pictures** looked wrong (no flames/glow; dark smooth trunk). Waiting for Dave's answers on the QA cards and for Kathleen/Sonny to look.
5. Silent placement refusals (beyond 6 m, wet beach, fire gap, per-chunk cap): not re-tested after Tyler's changes. Re-run `probe_place.gd` and read the "(silent: ...)" lines.
6. GUIDE_TASKS.md holds my round 1 self-made tasks (silent refusals, test gaps, tutorial numbers vs data); not started.

## 4. Current state of the first hour
See `PLAYTHROUGH_STEP_STATUS.md` (top "UPDATE 1 Nov" block, then the 22-row table). Short version: steps 4-7, 11-13, 15-19, 21-22 work on the server; 1 (join freeze), 10 (trunk look), 13/14 (lit fire look), 20 (bench has no check) are open; 2, 3, 8, 9 never driven in a client.

## 5. Open bugs and risks
- Chest self-test fails at `inventory_view.gd:4562` (Tyler). `flora_view.gd:2270` `_decimate_task` cast error (MikeW). Creator preview opens on the back with plain colours (Kathleen/Kathreen; Sonny's c41e2d21 may have fixed the direction). Join freeze ~15 s seen on older heads; gone in the 1 Nov smoke, unconfirmed by a person.
- No tutorial step for the campfire pot or clay hearth although the campfire now refuses plants. Steps 11-20 need about 62 sticks, over the playability bot's 60 budget; the bot stops before the bench.
- Many self-tests print no PASS/FAIL (arrival, gather, plantpick, chop, fire, leanto, spear, placed, walk): they prove "no crash" only.
- "Crash report written" in a log is the 15 s freeze watchdog, not a process crash.

## 6. How to run things (Godot exe: `C:/GodotInstaller/godot.windows.editor.x86_64.exe`, the voxel build; set `GODOT_EXE` to override)
- Probe: `tools/godot_slot.sh timeout 300 $G --headless --path . --script res://art/playthrough/probe_shelter.gd > out.txt` (also `probe_place`, `probe_cook`; a segfault line at exit after all output is shutdown noise).
- Status table: `tools/godot_slot.sh bash art/playthrough/run_status.sh` (about 6 min).
- Client self-tests on a fresh server: `tools/godot_slot.sh python art/playthrough/smoke_clients.py sleep,snare` (argument = comma list; one server per call, so put tests that place structures in separate calls). Full smoke: `bash art/playthrough/smoke_test.sh` (about 30 min) then `python art/playthrough/smoke_report.py`.
- Pictures: `art/playthrough/rig.sh` (windowed, second clone, never touches Dave's game). Run in the background; use `run_in_background`, not `nohup &`.
- Merge notes: untracked generated `.import` files can block a merge (delete the blockers); resolve generated-file conflicts with `--ours`.

## 7. Read first
`PLAYTHROUGH_STEP_STATUS.md`, `MORNING_PLAYTEST_CHECKLIST.md`, `PLAYTHROUGH_FINDINGS.md`, `TUTORIAL_FIRST_30_MIN.md`, `art/playthrough/smoke/notes.md`, `GUIDE_TASKS.md`, `art/playthrough/rig.sh` header, `tools/godot_slot.sh` header, the moderator's `MODERATOR_QA_LOG.md`.

## 8. Decisions not to re-open
Campfire cooks only meat, fish, shellfish (plants go in a pot or on the hearth). Nettles give fibre and leaves. Bed goes inside the lean-to and E on it sets the spawn point. Pictures for Dave go on QA cards, one per card. No game code or data edits from this role. Never touch main.

## 9. Skipped or not verified
Windowed walk of steps 1-14; creator preview picture; bench, chest, drink, pot, hearth in a client; lying under the 1.5 m roof in a client; felled-trunk bark; silent refusals after Tyler's changes; whether the join freeze is really gone for a person.

## 10. Next tasks I would have done
1. Windowed rig walk of steps 3-14 with one picture per step. 2. Extend the playability bot through bench, bed and cook (ask Tyler; it is his file). 3. Re-run silent-refusal probe and ask for messages. 4. Write a tutorial step for the pot and hearth (to Sal). 5. Check every tutorial and checklist number against data again after each daily. 6. Check each kit's look vs its item (56 kits, 19 looks) and file the grey ones.
