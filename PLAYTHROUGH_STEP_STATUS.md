# UPDATE 2 Nov evening (PC run on main 4e8f662d, scripted; outputs on the PC in DynastyALWL_w9/out/)
| Check | Result |
|---|---|
| test_first_hour | PASS, 0 failures |
| test_playability_bot | PASS, all 11 steps (bench included now that the stick budget is 70) |
| test_fire_store, test_fire_fuel_tiers, test_fell_autosplit, test_stump_chop | all PASS (new fire store with F, tiers, auto-split drops, stump chop) |
| probe_place | 13 kits placed; the 13 "(silent:" lines are on successful placements, not refusals; the one probed refusal speaks ("The ground is too steep there.") |
| probe_shelter | 15 PASS, 1 FAIL: check 16 wanted the respawn within 1.0 m of the bed; the game lands you 1.2 m beside it by design (bed.json respawn landing_m), under roof cover 1.0. Probe corrected (this commit), plus a writer flush before quit for the exit error |
| probe_cook | meat and fish cook; plants refused with the pot/hearth notice. "morel" was a probe typo (the item is "morels"): fixed |
| run_status | 25 fixed, 2 still broken: F-20 (orphan gathered items, Sal/flora) and S-place (a kit or blueprint refused beyond the rules, Tyler); F-01/F-24, F-19, S-craft now FIXED. 46 of 274 recipes blocked, 100 orphan items, 72 placeholder looks |
| smoke clients (gather, chop, fire, leanto, cook, spear, plantpick, sleep) | all ran; sleep ran. Two HIGH lines come from older logs, not this run: inventory_view.gd:4562 Nil 'numbers' (chest, Tyler) and flora_view.gd:2270 cast (MikeW) |
| windowed pictures | being taken on the PC |
Step table below: steps 4-13 and 15-19 hold on the server; 20 (bench) now has a bot check. Still not walked by a person in a window: 2 (Tab bars), 3 (drink), the fire store by hand, lying in the bed.

# UPDATE 1 Nov evening (daily 224e78bd): headless first-hour reruns after the Dynasty body, E rules, fire tiers, carry weights, logs everywhere
Run in my worktree with the slots shared with Tyler's test pass, so frames were slow. Logs: art/playthrough/smoke/logs, outputs: art/playthrough/refresh1nov/.

| Step | Result on 224e78bd |
|---|---|
| Arrival (join, ground) | OK: ground ready after 22 s, no retries |
| Gather (sticks, stones) | ran, no error of its own |
| Plant pick | PASS: tried 8, gone 8 |
| Chop | 10 blows, felled states [3, 4] seen: OK |
| Cook | COOK TEST PASS |
| Spear / campfire kit | ran: kit slot 1, fires in view, states [3, 4, 40, 9] |
| Walk | joined, but ground took 94 s after the welcome (loads 10952, 0 failed); the other runs took 22-30 s. Probably the shared machine, not confirmed |
| Fire, lean-to, sleep | queued behind these when this was written, see below if present |

New errors on this daily (all in FINDINGS_REPORT rows 22-23):
- `terrain_client.gd:2915` `_avatar.animation_player.active` on Nil: 45,600 times in every client log. Cause is the Dynasty body not loading in my worktree: its .glb has no import cache here (`Cannot open file res://.godot/imported/Dynasty_Base_Male...scn`), then `dynasty_body.gd:78` instantiate on null. The missing import is probably my worktree (never opened in the editor), so check on a project that has been imported. But the line has no null guard, so a body that fails to load makes the log flood and the avatar vanish.
- Not re-run: lying picture, felled-trunk bark picture, creator view (rig pictures need the windowed slot).

# PLAYTHROUGH_STEP_STATUS: the 22 first-hour steps, which work end to end (paper review, 31 Oct afternoon)

Written with no Godot run (Dave has the computer): from the daily head code and data (13b84fa3 merged), the tutorial text, and the probe and smoke results from earlier today. WORKS = a probe, test or bot has driven it on the real server code and nothing found; CLIENT = the client side (hands, prompts, pictures) was not driven by me; OPEN = something known is wrong. "Re-run" names what to run when the computer is back (list at the end).

## PHASE 2 RESULTS, 1 Nov 2026 (daily 9ca75719, real windowed rig client and headless client on real servers; pictures in art/playthrough/phase2/)
| step | result | evidence |
|---|---|---|
| 1 join | WORKS: no freeze or crash report in the Phase 2 runs; welcome to ground ready about 2-5 s in client logs. A person has still not timed it | art/playthrough/smoke/logs/client_*.log |
| 2 Tab bars | NOT SHOWN: the admin rig picture shows the F3 debug text, not the Tab vitals bars (rig does not press Tab) | phase2/spawn_tab.png |
| 3 drink | NOT TESTED (no rig or self-test action) | |
| 4-5 sticks, stones, nettle | WORKS to "no crash" (gather, plantpick self-tests ran) | smoke/logs/client_gather.log |
| 6-7 twine, axe | WORKS in data and bot | recipes.json |
| 8 fell | WORKS: chop self-test felled a tree in 9 blows (felled states [3,4]). One earlier run quit after 10 s with no error (flaky, not repeated) | smoke/logs/client_chop.log |
| 8 felled-trunk look | the rig fell picture is useless: camera upside down over water, 54 KB blank "before" frames; bark fix still NOT confirmed | phase2/fell_resting.png |
| 9-10 fire place and light | WORKS: 13 PLACED, lit state 40; fire draws small flames and a glow, but grass hides it (picture with grass off shows it) | phase2/campfire_lit_nograss.png |
| 11 cook | WORKS: cook self-test PASS earlier, probe_cook meat only | probe_cook_output.txt |
| 12-13 lean-to, bed | WORKS on the server: probe_shelter 18 PASS, 0 FAIL on 9ca75719 (1.5 m roof, lie, sleep, spawn, respawn on bed). Real client picture shows the lean-to and bed as models; the bed was not placed inside the lean-to by the rig (it sets a row) | art/playthrough/probe_shelter_output.txt, phase2/leanto_bed_wide.png |
| 13 sleep in client | WORKS: clean-server sleep self-test PASS (lying 3, asleep true, energy 60 to 61, woke) | phase2/client_sleep_clean.log |
| 13 lying picture | NOT OBTAINED: --shot-stance=lie did not frame a lying body (picture shows grass and an unrelated shape). Needs a rig change (Kathleen) or a manual look | phase2/lying_wide.png |
| 14 bench, spears, knife | data checked; no client check | |
Placement probe on 9ca75719: 13 PLACED, one REFUSED (steep slope, with message "The ground is too steep there."). The other refusals were not probed.
Creator: preview still shows the back of the body with patchy colours (phase2/4_undo_twice.png).

## UPDATE 1 Nov 2026 (probes and smoke ran on d05e86b3 after COMPUTER BACK; recipes, structures, drops and hints re-read from data on daily 9ca75719, no Godot)
Verified by running (headless server probes, headless real-client self-tests; **no step was walked by hand in a windowed client**):
- 17, 19 WORKS: probe_shelter 16/16 PASS with the lean-to roof 2.6 x 3.4 m, 1.5 m high (lie, good bed 1.0, sleep, E sets spawn, respawn on the bed).
- 12 WORKS: probe_place 13 PLACED; only the steep-slope refusal speaks; the silent refusals (beyond 6 m, wet beach, fire gap, per-chunk cap) are NOT re-tested.
- 15 WORKS: probe_cook, campfire cooks meat, fish, shellfish, seal; refuses plants with a notice.
- 1: no join freeze and no crash report in the d05e86b3 smoke run (earlier runs froze ~15 s): needs Dave's eyes to confirm.
- 19 sleep self-test: on a clean server the bed places and the player lies, but the test fails because energy is 100 (sleep refused at full energy). Test gap, not a game bug. Snare places on a clean server.
- 10 (felled trunk) STILL LOOKS WRONG: rig picture shows dark smooth trunk; bark fix not visible (QA card pic-fh-felled-trunk).
- 13/14 (lit fire) STILL UNPROVEN VISUALLY: rig picture shows no flames or glow (QA card pic-fh-campfire-lit). Server state 40 (lit) is fine.
- 20 bench (now 16 sticks, 6 twine, 4 stones, 60 s): no automated check at all.
- Self-tests arrival, gather, plantpick, chop, fire, leanto, spear, placed, walk run without script errors but print no PASS/FAIL line, so they prove "no crash" only.
- New in data since d05e86b3: hints plant_food_pot and pot_first_dish (step 15 now has an in-game hint for the pot, still no tutorial step); stump chop destroys the stump and gives firewood, kindling, sticks by stump size (drops.json; test_stump_chop.gd exists, not run by me).
- Recipe numbers re-checked in data: campfire 6 sticks + 3 stones 8 s; lean-to 32 sticks, 8 leaves, 4 twine 25 s; rough bed 8 bedding (or 8 straw) + 4 sticks + 2 twine 10 s, or 10 thatch + 4 sticks + 2 twine 25 s; Camp bench 16 sticks, 6 twine, 4 stones 60 s; wooden spear 1 stick 6 s (stone kept); stone spear = wooden spear + 2 twine 10 s; stone knife 2 stones + 1 stick 8 s; stone axe 10 s; twine 3 fibre 2 s. Checklist step 14 had the spear recipe wrong: fixed.
- Still open: chest self-test (Tyler, inventory_view.gd:4562), flora_view.gd:2270 cast error (flora session), creator preview back view, no pot/hearth tutorial step.

| # | step | status | evidence and what is not covered |
|---|---|---|---|
| 1 | spawn, walk, run | WORKS, OPEN | smoke walk picture and arrival test fine; **about 15 s main-thread freeze at join** (watchdog, fps 1) | 
| 2 | Tab bars | CLIENT | not driven; the vitals exist on the server |
| 3 | drink at the water | CLIENT | server drink code present; the spawn pond shore (probe_spawn) is 31 m ground, water near; not driven in the client |
| 4 | pick sticks and stones | WORKS | gather self-test ran (no crash); loose sticks and stones are laid thicker near the spawn (probe_spawn) |
| 5 | nettles: fibre and nettle leaves | WORKS after Sal's branch | 49 nettles within 50 m; drop counts read from data (1-2 fibre, 2-4 nettles), not run |
| 6 | twine (3 fibre -> 1) | WORKS | playability bot |
| 7 | stone axe (1 stone, 1 stick, 2 twine, **10 s**) | WORKS | bot; tutorial time fixed (was 4 s) |
| 8 | hotbar, hold the axe | CLIENT | quickkeys self-test ran; held pose F-10 still MANUAL |
| 9 | fell a tree | WORKS, CLIENT | bot and chop self-test; aiming and the swing not driven |
| 10 | work the trunk, logs on the shoulder | WORKS | probe_logs (rough planks from the shoulder log); felled-trunk look was flat black this morning, bark fix commit 993aafab not re-photographed |
| 11 | campfire kit (6 sticks, 3 stones, **8 s**) | WORKS | bot; tutorial time fixed (was 3 s) |
| 12 | place the fire | WORKS | probe 6 (re-run on the 14:40 head): places at the spawn and the other flat spots; the only refusal seen is the steep slope, with its message. The silent refusals (beyond 6 m, wet beach, fire gap, per-chunk cap) were not re-tested after Tyler's changes |
| 13 | light it (fibre, bark) | WORKS | probe 6: state 40 with both |
| 14 | feed it, warmth | WORKS, CLIENT (rules changed 2 Nov: wood goes in with F, E puts a burning fire out; not re-run) | fire self-test ran; warmth numbers from data; test_fire_store added by Steve |
| 15 | roast meat (campfire cooks only meat) | WORKS | probe 8: refuses berries, nuts, bulbs, fiddleheads with a message; cooks meat, fish, shellfish, seal. Plants now need a pot or hearth: **steps for the pot and hearth are not in the tutorial yet** |
| 16 | lean-to kit (**30 sticks, 200 leaves, 10 twine** since #186, 3 Nov; 25 s) | WORKS, OPEN | halved from 32 sticks, so the pace worry is mostly answered |
| 17 | place the lean-to | WORKS | probe 7 ran on the 14:40 head with a 2.6 x 2.4 m roof, 2.1 m high; the data now says 2.6 x 3.4 m and **height 1.5 m** (a later daily merge: probe 7 not re-run on it, so a lying player under a 1.5 m roof is unchecked); cover under it |
| 18 | bedding and rough bed (8 bedding, 4 sticks, 2 twine, 10 s) | WORKS | recipe 231 known; ferns give bedding |
| 19 | bed inside the lean-to, lie, sleep, spawn point | WORKS, CLIENT | probe 7: placed at the centre, cover, good bed (quality 1.0), E sets spawn, respawn on the bed. Not lain in, in the client |
| 20 | workbench (**Camp bench: 16 sticks, 6 twine, 4 stones, 60 s**, data 2 Nov) | OPEN | tutorial said 12 sticks 3 twine: text fixed; 60 s and 20 sticks make this a long step, and the playability bot stops before it (not covered) |
| 21 | wooden spear, stone spear | WORKS | recipes 5 and 3 known; spear self-test ran |
| 22 | rabbit, knife, dress, roast, eat | WORKS | kill-to-roast chain driven on the server earlier (meat, hide, bone); client aiming not driven |

## What a new player still cannot do, from code and data
1. Join without a ~15 s frozen window (voxel start).
2. See what they are making in the creator (preview opens on the back).
3. Learn about the pot and hearth: the campfire no longer cooks forage, and no tutorial step teaches the pot (recipes exist in Sal's data).
4. Open and use a chest from the client self-test path (chest self-test fails).
5. ANSWERED by #186 (3 Nov): sticks for steps 11-20 are now 6 + 16 + 4 + 16 = 42 (lean-to 16, Camp bench 16), well under the bot's 60-stick budget.
6. See a lit fire and a felled log picture: no rig frame yet.

## Probes to re-run when the computer is back (in this order, all headless unless noted)
1. `art/playthrough/run_status.sh` (about 6 min): status table, audit.
2. `probe_shelter.gd`: lean-to height 1.5 and roof 2.6 x 3.4; bed centre still places; step 15 respawn.
3. `probe_place.gd`: fire and kit placement after Tyler's message changes (silent refusals now say why?).
4. `probe_cook.gd`: meat only, after Sal's branch is on the daily head.
5. `test_playability_bot.gd`: extend to the bench (step 20), the bed (19), the cook (15).
6. Rig (windowed): `rig.sh --pieces lean_to,rough_bed --views`, a lit fire (`--shot-place --shot-light`, longer settle), felling picture for the bark fix, creator preview (Sonny's fix).
7. `smoke_test.sh` (about 30 min): the 15 s join freeze, chest test.
