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
