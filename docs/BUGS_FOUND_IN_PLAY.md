# Bugs found in play-testing (Dave)

Dave's list of bugs found while testing. **Nobody is assigned to these and nobody should work on them.** They are part of the handoff once Dave has finished testing; he will say who takes what.

Each entry: the symptom in Dave's words, when it was found, and any context already known. Add new entries at the bottom.

## 1. The fire timer does not update after you add more wood

- **Found:** 2026-11-01, Dave, playing the daily.
- **Symptom (Dave):** the fire timer does not update after you add more wood.
- **Context, not a diagnosis:** the "Campfire hh:mm:ss Burn time" label is shown in inspect mode and was added to the daily today (client `_fire_label` in `src/client/inventory_view.gd`, burn time from the fire's server state in `src/stream/server_items.gd`). It is not known whether the shown time is stale on the client, not resent by the server when wood is added, or something else. `test_fire_fuel_tiers` and `test_fire_midburn_save` cover the burn time on the server side only; nothing has been run in a windowed client.
- **Status:** open, unassigned, not worked on.

## 2. I can't pick up the chopping block

- **Found:** 2026-11-01, Dave, playing the daily.
- **Symptom (Dave):** can't pick up the chopping block.
- **Context, not a diagnosis:** today's E-key change (`claude/e-priority-2`, commit `18e7dcd4`) made a block's aim point its middle and made E do only the cursor's action, with no pickup of other things. It is not known whether that is related, or whether the block was never pickable. Nothing has been run in a windowed client.
- **Status:** open, unassigned, not worked on.

## 3. The firewood pile beside the chopping block does not grow

- **Found:** 2026-11-01, Dave, playing the daily.
- **Symptom (Dave):** the firewood beside the chopping block does not grow when you add more wood to it by chopping wood. It should get bigger, so you can see there is a larger pile of wood there.
- **Context, not a diagnosis:** none known. Nothing has been run in a windowed client. Whether the pile is a placed look that never reads the stack count, or a count that is not sent to the client, is not known.
- **Status:** open, unassigned, not worked on.

## 4. First-person arms need better alignment and placement

- **Found:** 2026-11-01, Dave, playing the daily with the new first-person arms (built from `Dynasty_Base_Male_Parts_Split.glb`, commit `f4acaf4a`). Screenshot: `C:\Users\david\AppData\Local\Temp\claude\C--GodotProjects-DynastyALWL\48aa3172-4466-48c8-8bd4-2a4eae45a208\images\13.webp` (not committed).
- **Symptom (Dave):** these arms need to be aligned better and placed better.
- **What the screenshot shows (observation, not a diagnosis):** standing in a meadow with the stone axe selected. Both arms enter from the bottom of the screen with fingers visible. The right hand grips the axe handle partway up, with the head pointing up and slightly away. The left hand is open and reaches across in front of the right, not holding anything. The arms look thin and long against the view and lean toward the middle, and the hands look rotated relative to the forearms.
- **Context:** Kathleen's note says the arms are a rigid mesh cut by height into upper arm, forearm and hand on the old arm rig; the wrist and fingers do not move; the hand mounts and tool placement are the old ones; and arm size against the camera, hand scale and tool alignment in the hand were "not checked". No in-game first-person picture existed before this screenshot.
- **Status:** open, unassigned, not worked on.

## 5. Cutting a tree down takes over 20 hits (it used to take about 10)

- **Found:** 2026-11-01, Dave, playing the daily. First reported as "I can't cut this tree down, it says it's a beech"; Dave then corrected himself: the tree can be cut, but it now takes over 20 hits, where it originally took about 10.
- **Symptom (Dave):** originally it took 10 hits to cut a tree, now it takes over 20. He asked what affects this.
- **Screenshot** (the beech Dave was cutting; not committed): `C:\Users\david\AppData\Local\Temp\claude\C--GodotProjects-DynastyALWL\48aa3172-4466-48c8-8bd4-2a4eae45a208\images\14.webp`. Its debug overlay reads "build 826 (5254215)", which is commit `52542154`, the daily's head at that time, so the build has every change merged today. It shows first person at x 53287, z 68492, stone axe in hand, close in front of a tall trunk, with felled logs in the grass.
- **What decides the hit count (read from the code, not a diagnosis):** in `src/stream/server_items.gd` (the tree-hit handler, about line 3697) blows needed = round(`tree_base` + trunk radius in metres x `tree_per_trunk_m`), clamped between `tree_min` and `tree_max`, then divided by the player's `fell_tree` skill factor (clamped 0.25 to 4). The numbers are in `data/items/drops.json`, section `felling`: `tree_base` 2.0, `tree_per_trunk_m` 16.5, `tree_min` 3, `tree_max` 22. The tool tier does not enter the formula. One blow counts per swing, at least `HIT_COOLDOWN_MS` (400 ms) apart, and a half-chopped tree resets after `CHOP_RESET_MS` (60 s) untouched. The section's note says the blow counts were scaled by 0.55 on 31 Oct when the swing went from 0.55 s to 1.05 s, "to keep the real time per tree", and `test_felling_time` checks that.
- **So over 20 hits means:** either a thick trunk (about 1.1 m radius or more, which reaches the 22 cap) or a low fell skill factor that divides the count up (for example a cap of 22 at skill 1.0 is 22, and at skill 0.5 it is 44). Which of those applies to Dave's tree is not known. Whether today's swing changes (Jason's `7a616fcc`, Kathleen's `e90c46d1`) altered how many swings land per hit is also not known.
- **Status:** open, unassigned, not worked on.

## 6. Each cut on a fallen tree makes the game lag and lock up for about 2 seconds

- **Found:** 2026-11-01, Dave, playing the daily.
- **Symptom (Dave):** whenever I cut up a fallen tree, each cut causes the game to lag and lock up for 2 seconds at a time.
- **Context, not a diagnosis:** none measured. The fallen-tree cutting path is `_process_trunk` and `_cut_log_off` in `src/stream/server_items.gd`; today's change there made every felled tree give logs (`aae3a272`, `df56ffaf`). The game has an instrument that logs `SLOW RPC` over 100 ms and a `_slow_mark` helper, which may show where the time goes. The stall could be on the server (saving, creating the log item, or a world-state rewrite) or in the client (building the log mesh or re-importing). Nothing has been measured, and nothing has been run in a windowed client.
- **Status:** open, unassigned, not worked on.

## 7. The game has bad lag constantly

- **Found:** 2026-11-01, Dave, playing the daily. Reported right after entry 6 (a 2 s lock-up on each cut of a fallen tree), so it may or may not be the same problem.
- **Symptom (Dave):** it's got bad lag constantly.
- **From Dave's debug overlay (screenshot `images\14.webp`, same session; numbers only):** build 826 (`5254215`), 53 fps with vsync off, quality Ultra (F2), average frame 19.9 ms, worst frame 59.1 ms, memory 668 MB, flora 21,427 drawn with 5,115 colliders and 151,188 grass, 3D at 2560x1440 inside a 3816x1869 editor window ("embedded: editor owns the window"), NVIDIA GeForce RTX 20xx. That screenshot is one moment and may not show the lag Dave means.
- **Context, not a diagnosis:** things that changed on this machine or in the game today, any of which could be a factor and none of which has been measured:
  - The player body is now Dave's own mesh, about 55,700 triangles with two 4096 x 4096 textures (the old body was about 3,200 triangles). The first-person arms are a second mesh from a file with about 365,000 triangles and three embedded textures.
  - (Struck out: three hung headless Godot scripts and two old headless servers were running earlier today, but Dave restarted the computer, so none of them exists now. If the lag remains after the restart, they were not the cause.)
  - The game was running inside the editor (embedded window), which is slower than a standalone run.
  - Fires, the photo camera, the craft search and the E-key changes also went in today.
- **Status:** open, unassigned, not worked on.

## 8. Three or more firewood in the campfire does not upgrade it to a medium fire

- **Found:** 2026-11-01, Dave, playing the daily.
- **Symptom (Dave):** when I put 3 or more firewood in the campfire it did not upgrade to a medium fire.
- **Context, not a diagnosis:** Dave reported the same thing earlier today ("I have put many firewood in the fire, it hasn't got any bigger"). The tier rules (3 or more firewood is the medium fire; softwood firewood counts too, at twice the burn rate) were built by Steve on `claude/fire-fuel-tiers`, and `test_fire_fuel_tiers` shows them working on the server (4 logs lit the large fire; mixed soft and hard firewood made the medium fire). The server tests are not a windowed game, so the tier may not be reaching the client, the picture may not redraw when the tier changes, or the type of firewood Dave used may not count. Not known. Dave's debug overlay at the time of entry 5 shows build 826 (`5254215`, commit `52542154`), which includes the fuel tiers, so this is not an old build.
- **Status:** open, unassigned, not worked on.

## 9. Only one log can be put in the campfire

- **Found:** 2026-11-01, Dave, playing the daily.
- **Symptom (Dave):** it won't let me put more than one log in the fire.
- **Context, not a diagnosis:** same as the earlier report today ("the first log went in but the second one won't"). Steve could not reproduce it on the server (4 logs onto one laid fire all go in, and 5 onto a lit fire with a pot also go in; the only cap is the total, 18 real hours or 6 logs), and suggested the client may treat a tap on a laid fire as "light" and only a hold as "add fuel", or add sticks before logs. He then made fuel order logs first and prompts inspect-mode only (`18e7dcd4`). Since Dave still sees it on a build that includes those, the cause is not known. The pot rule (no logs while a pot hangs on the fire) may be involved if a pot was on that fire; Dave said earlier there was no pot.
- **Status:** open, unassigned, not worked on.
