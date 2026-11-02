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

## 5. Can't cut a beech tree down

- **Found:** 2026-11-01, Dave, playing the daily. The debug overlay in his screenshot reads "build 826 (5254215)", which is commit `52542154`, the daily's head at that time, so this build has every change merged today. Screenshot: `C:\Users\david\AppData\Local\Temp\claude\C--GodotProjects-DynastyALWL\48aa3172-4466-48c8-8bd4-2a4eae45a208\images\14.webp` (not committed).
- **Symptom (Dave):** I can't cut this tree down. It says it's a beech.
- **What the screenshot shows (observation, not a diagnosis):** first person at x 53287, z 68492, stone axe in hand, close in front of a tall grey-brown trunk. Several felled logs lie on the ground around it, in tall grass.
- **Context, not a diagnosis:** earlier today Dave could fell a beech and cut it with the axe, but got no logs; Sal's fixes `df56ffaf` (beech is a key wood) and `aae3a272` (every felled tree gives logs) are in this build. Whether this tree is a different case (size, tool tier, hardness of the beech needing a better axe than the stone axe, a stuck tree state, or the E-key change `18e7dcd4`) is not known. Nothing has been run in a windowed client.
- **Status:** open, unassigned, not worked on.
