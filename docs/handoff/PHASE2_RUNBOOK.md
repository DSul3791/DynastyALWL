# Phase 2 runbook (Guide): exact commands and the 14-step walk (run only after the moderator says RESTART)
Godot exe: `G=C:/GodotInstaller/godot.windows.editor.x86_64.exe` (voxel build). Run from the worktree root. Every heavy job goes through `tools/godot_slot.sh` (max 3), in the background, one at a time for windowed jobs. Pictures go in `art/playthrough/phase2/`; one QA card per picture afterwards.

## Commands, in order
1. `mkdir -p art/playthrough/phase2`
2. Creator picture: `tools/godot_slot.sh $G --path . --resolution 1920x1080 --script res://tools/proto_creator_view.gd -- --out=res://art/playthrough/phase2` (needs a window; expect several PNGs; check the back-view problem).
3. Clean-server sleep test: needs energy lowered first, so the existing `smoke_clients.py sleep` will still print FAILED (energy 100). Run it for the bed + lie part, and verify sleep with the probe: `tools/godot_slot.sh timeout 300 $G --headless --path . --script res://art/playthrough/probe_shelter.gd`.
4. Lean-to and bed in the real client: `tools/godot_slot.sh bash art/playthrough/rig.sh --pieces lean_to,rough_bed --views "wide:7:-15:2.5;close:4:-25:2.0" --at 53316,68476 --wait 60 --settle 60 --out art/playthrough/phase2 --name leanto_bed`
5. Lying in the bed (item 4 of the closing plan): `rig.sh --pieces lean_to,rough_bed --client-arg --shot-stance=lie --cam left --walk 0 --at 53316,68476 --wait 60 --settle 60 --out art/playthrough/phase2 --name lying` (check the log line "shot runner: view" and that the body lies under the 1.5 m roof).
6. Lit fire: `rig.sh --give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light --nograss --wait 60 --settle 60 --out art/playthrough/phase2 --name campfire_lit_nograss` (same shot with `--nograss` tells whether grass hides the fire).
7. Felling: `rig.sh --item stone_axe --client-arg --shot-fell=flat --wait 120 --settle 20 --out art/playthrough/phase2 --name fell`; stump chop is covered by `src/worldgen/tools/test_stump_chop.gd`.
8. Spawn with bars: `rig.sh --cam first --admin --wait 60 --settle 30 --out art/playthrough/phase2 --name spawn_tab`.
9. Self-tests: `tools/godot_slot.sh python art/playthrough/smoke_clients.py arrival,gather,plantpick,chop,fire,cook,leanto,spear,placed,walk` (they print no PASS/FAIL, they prove "no crash"); sleep and snare each in their own call.
10. Probes after the daily: `probe_place.gd` (read the "(silent ...)" lines), `probe_cook.gd`, `probe_shelter.gd`; `run_status.sh` once.
11. Then: update PLAYTHROUGH_STEP_STATUS.md, FINDINGS_REPORT.md, QA cards, push, message the moderator only.

## The 14-step walk script (what to do, what to see, how I check it)
| # | do | expect | check |
|---|---|---|---|
| 1 | join (F6 launcher) | meadow by a pond at 53316, 68476; time the freeze | stopwatch from welcome to first frame; client log "JOIN: ground ready" |
| 2 | look, press Tab | trees, ferns, grass; bars for Health, Food, Water, Warmth, Energy | step 8 picture (`--admin`) |
| 3 | walk to water, E | drink, Water bar rises | **no automated check**: needs a client drive; note as OPEN |
| 4 | E on sticks and stones, hold E to sweep | items in pack | gather self-test (no crash) |
| 5 | E on nettle | plant fibre and nettle leaves | data drops.json; probe_cook says 'nettles' item exists |
| 6 | craft twine from 3 fibre | 1 twine, 2 s | playability bot |
| 7 | craft stone axe | 10 s | bot |
| 8 | fell a tree, work the trunk | ~10 blows; branches then logs on shoulder | rig fell pictures; chop self-test |
| 9 | campfire kit, place | ring yellow/green; refused beyond 6 m | probe_place (13 PLACED) and a rig shot |
| 10 | light, feed | state 40; flames visible | probe_place; lit-fire pictures (open bug: no flames seen) |
| 11 | cook meat/fish | roast item; plants refused with notice | probe_cook; cook self-test PASS |
| 12 | lean-to kit, place | roof 2.6 x 3.4, 1.5 m | probe_shelter; rig step 4 |
| 13 | bed inside, E, Z to lie, hold Z to sleep | "Spawn point set"; asleep; respawn on bed | probe_shelter 16/16; rig step 5 |
| 14 | bench, wooden spear, stone spear, knife | recipe numbers as in the checklist | data re-read (done 1 Nov); bot stops before the bench |

Findings from this run go into docs/handoff/FINDINGS_REPORT.md and one message to the moderator.
