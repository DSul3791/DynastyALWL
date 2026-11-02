# Bugs found in play-testing (Dave)

Dave's list of bugs found while testing. **Nobody is assigned to these and nobody should work on them.** They are part of the handoff once Dave has finished testing; he will say who takes what.

Each entry: the symptom in Dave's words, when it was found, and any context already known. Add new entries at the bottom.

## 1. The fire timer does not update after you add more wood

- **Found:** 2026-11-01, Dave, playing the daily.
- **Symptom (Dave):** the fire timer does not update after you add more wood.
- **Context, not a diagnosis:** the "Campfire hh:mm:ss Burn time" label is shown in inspect mode and was added to the daily today (client `_fire_label` in `src/client/inventory_view.gd`, burn time from the fire's server state in `src/stream/server_items.gd`). It is not known whether the shown time is stale on the client, not resent by the server when wood is added, or something else. `test_fire_fuel_tiers` and `test_fire_midburn_save` cover the burn time on the server side only; nothing has been run in a windowed client.
- **Status:** open, unassigned, not worked on.
