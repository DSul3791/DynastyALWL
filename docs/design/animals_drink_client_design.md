# Animals drinking: the client half, and the switch that keeps it off

**Owner:** Steve. The design takes over MikeW's client half (`docs/design/ANIMAL_DRINK.md` on `claude/mikew-eye-placement`, behind `drink_looks`). It reuses his sip and look-round rule and drops the flag.
**Server half:** `docs/design/animals_at_water_server.md` (#734), merged.
**Status:** design only. It goes to code once the coordinator has read it. It ships on, with no flag and no protocol change.

## 1. What the game does today (read from main 439a6371)

1. **The server never sends animals to water.** `data/animals/animals.json` `drink.on` is still `false`, and `server_animals.drink_on()` checks it. So no deer or stock animal walks to the bank, and no row ever carries state 21 (`DRINK`).
   - The 8 Nov flag sweep (OVERNIGHT_DECISIONS rows 25 and 26) missed this switch. It is not in Jamie's audit list.
2. **The client has no drink look.** `models.json` maps no `"21"` clip for any species. `animal_view._animate_model` falls back to clip `"0"` for any state it has no role for.
   - For the deer, moose, bighorn, mountain goat, buffalo, wildebeest, chamois and pronghorn, `"0"` is a graze with the head down. That reads near enough to drinking.
   - For the elk, horse, donkey, cow, goat and camel, `"0"` is a standing idle. These would stand at the water's edge with the head up.
   - The built (procedural) bodies have no case for 21, so their head stays level.
3. **None of MikeW's helpers are on main**: no `water_life` drinking spot, no `animal_sign` pool, no `pose_library`. His churned bank and bird bathing would need them, so they are out of scope here (section 5).

## 2. What the player will notice

- At dawn and dusk (05:00 to 08:00 and 18:00 to 21:00), most deer and stock walk to the nearest fresh water within 300 m. Each stands 1 to 3 minutes at the bank, as the server design already says. Wolves hang about 15 m back.
- At the bank the animal **drinks with its head down**. Every 6 to 14 s it **lifts its head to look round** for 1.5 to 3 s, then drinks again. Each animal keeps its own timing, so a herd never lifts its heads together.
- Nothing else changes, and nothing changes at noon.

## 3. The change

### 3.1 Server: remove the switch

- Delete `drink.on` from `animals.json`, and drop the `on` check from `drink_on()`, which keeps its `water_level.is_valid()` guard.
- Update the `note` in `animals.json`.
- `test_animals_drink.gd` has a "flag off: a deer does not go" check. That check goes, because there is no off. Its other checks stay.
- This follows Dave's 8 Nov rule: no flags, the features ship on. It is the one server change. Without it the client half never shows. There is no protocol change: state 21 has been on the wire since #734.

### 3.2 Client: the drink clip (models)

- Add `"21"` to `animal_view._ROLE_WORDS` with the words `["drink", "eat", "graz"]`.
  - The role loop already walks every `_ROLE_WORDS` key, so each model finds its own drinking clip by name.
  - Many WildMesh files have a `Drinking` clip. Where a file has none, an eat or graze clip is the next best.
  - A clip that lays the model flat is refused by the existing `flat_share` test, and the next word is tried.
  - With no match there is no `"21"` role, and `_animate_model` keeps today's fallback to `"0"`.
- A new note line goes in the log once per model, through `_model_note`: `animal model <kind>: role 21 plays <clip>`.
  - Dino's run lists the 14 drinking species' choices from that note.
  - A species whose choice looks wrong in the shots gets a fixed `"21"` name in its `models.json` row. That is a data line, not code.

### 3.3 Client: sip and look round

This is MikeW's rule, with fixed numbers and no flag.
- In `_animate_model`, while the state is 21 and the animal is standing (speed under 0.3), a per-animal cycle runs from its `phase`.
  - The cycle is 6 to 14 s of drinking (role `"21"`), then 1.5 to 3 s of looking (role `"3"`, the alert or breathing clip with the head up).
  - The cycle's lengths come from a hash of the animal id and the cycle number, so they are the same on every client.
  - The switch between clips uses the same 0.25 s blend as every clip change.
- **Built bodies:** the four-legged body (`_animate_quad`) gets `state == 21` beside the graze case. `head_down` is 0.9 while drinking and -0.35 while looking, on the same cycle.
  - The wolf body is left alone, because wolves never drink.

### 3.4 What it does not do

- It adds no water sampling on the client. The server has already put the animal at the edge, facing the water.
- It adds no ripple, bank mark, bird bath or sound.

## 4. Checks

**Static, in the cloud:** merge_check, lanes, luck, doc links and lint.

**Tests, on Dave's PC through David4:**
- `test_animals_drink.gd` without its flag-off check.
- A new check in it: the client cycle. A stub row in state 21 alternates the drinking and looking roles within 20 s, and two ids do not lift at the same moments.

**Dino, in-world:** a dusk run at a lake edge on tile 3,4 using the look rig.
- Dawn is at 05:00, so the run uses `--hour 6`.
- It needs a deer and a horse at the bank: a head-down drink with head lifts in between.
- Send the `role 21 plays` lines for the drinking species.

## 5. Later, not in this change

- **The churned bank and tracks:** MikeW's trampled patch needs his `animal_sign` pool, which is not on main.
- **Birds bathing:** this is not state 21. Ducks and geese already swim.
- **Springs first:** `drink_spot` could try the tile's spring heads and brooks (`DrinkRules.chunk_points`) before sampling `water_level`, as the server design's section 4 planned. It is a server change with its own design line, after this one.

## 6. Undo

To undo, revert the PR. If the animals' walk to water turns out wrong in play, only the server part needs reverting (section 3.1). The client part does nothing without state 21.
