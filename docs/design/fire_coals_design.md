# Fire after the flames: coals, warm ash, rain on a big fire, and wet wood

**Owner:** Steve (server: `src/stream/server_items.gd`, `data/items/cooking.json`). **Look:** Kathleen (`building_look.gd` `fire()`).
**Status:** design, 8 Nov 2026. **Coordinator decision, Dave may revert** (it comes off Dave's open list: "burnt-out fire 5 min").
**Research:** Jamie, `docs/knowledge/fire-outdoors.md` (#668), lessons 1 to 4. **Related:** [torches-fire.md](../knowledge/torches-fire.md) (Dave's simple fire rules).

## 1. The decision

1. A burnt-out fire is no longer cold ash for 5 minutes. It becomes **coals that glow for 2 hours (real time)**. Then it is **warm ash that relights with tinder for up to 12 hours**. Then it is cold.
2. **A large fire on a bed of coals survives a downpour.** Small fires still go out in rain, as today.
3. **Wood has a wet flag.** Sticks dry in hours and logs in weeks. Wet wood smokes and burns slower.
4. **Burn times do not change** (a stick lasts 2 real minutes, firewood 20, a log 3 real hours; Dave, 1 Nov).

Coals and ash run in real time, like the burn times. A log fire that burned 3 real hours leaves coals for 2 more. Drying runs in game time, like spoilage and the weather (a game day is one real hour). So a log takes a game week, about 7 real hours, to dry. All the numbers are `cooking.json` keys.

## 2. Today (read from the code, 8 Nov)

- **Lit states:** a lit fire's world-item state is its tier: 40 small, 1 campfire, 41 bonfire. State 9 is a laid fire (wood in, not lit), and 8 is burnt out.
- **Burning out:** when `burn_left` reaches 0, `_tick_fires` sets state 8 with `left = FIRE_OUT_S` (300 s). The item is deleted when that runs out.
- **Rain:** rain of `FlameRules.RAIN_DOUSE` (0.2) or more on an uncovered lit fire puts it out after the short grace. It goes back to state 9 with its wood kept.
- **Lighting:** any wood plus E lights it, and no starter is needed (Dave, 5 Nov). Light rain makes it a gamble (`rain_light_chance`).
- **Wood:** wood carries no wet or dry state. A slot's `wear` field is used only by spoilage (age), and wood does not spoil.

## 3. Coals and warm ash (step 1)

Two new world-item states are appended after 41, so old clients and saves read nothing wrong:

| State | Name | Lasts | Light (client) | Warmth | Wolves |
|---|---|---|---|---|---|
| 42 | coals | `coals_s` 7200 real s | dim red, about 1 m, no flame, a thin wisp | `coals_heat_c` 8 °C within `coals_heat_m` 1.5 m | not protected: `fire_is_lit` stays false |
| 43 | warm ash | `ash_s` 43200 real s | none, a faint wisp for the first hour | none | no |
| 8 | cold ash | `FIRE_OUT_S` 300 s, as today | none | none | no |

- **Burning out:**
  - When `burn_left` reaches 0, a fire with a coal bed becomes 42. A coal bed is `coal_bed_s`, 600 real s (10 minutes), of burning in total since it was last cold.
  - A fire with no coal bed becomes cold ash (8), as today. A handful of sticks lit and gone in two minutes leaves no coals.
- **Wood laid on coals** (F, as on any fire) catches by itself, with no E needed. It takes `catch_s` (weak 10 s, firewood 45 s, log 180 s; ×2 when wet). The fire goes to its tier as lit by E, so the fire is back.
  - Light rain does not stop wood catching on coals. Rain of 0.2 or more on uncovered coals puts them out:
    - after `coals_rain_s` 120 s, they go to warm ash;
    - after a further `ash_rain_s` 600 s, the warm ash goes cold.
- **Warm ash:**
  - Wood plus at least one tinder item (`cooking.json` `tinder` and `tinder_also`: plant fibre, tinder, tinder fungus) and E lights it with no damp roll. The tinder is used up.
  - Without tinder it is lit like a cold laid fire.
  - Lighting needs no starter today, so warm ash matters mostly in damp weather (a sure light) and as a sign that someone was there recently (Jamie's lesson 4).
- **The world item:**
  - Coals and ash keep the fire's store (`uid`) and its position.
  - Pick-up (hold E) works on 42 and 43 as on 8, and nothing burns the player.
  - `left` counts down as now. 42 becomes 43 when it runs out, and 43 becomes 8.
- **Wire:**
  - The fire row gains one field, `glow` 0..1. That is how far through its coals or warm-ash time the fire is, so the client can dim it.
  - Protocol bump. An old client drawing an unknown state draws nothing, which is safe.
  - Kathleen draws 42 and 43.

## 4. Rain on a big fire (step 2)

- A **large fire** (state 41, 3 or more logs) **with a coal bed** keeps burning in rain of any strength, uncovered.
  - It burns ×`rain_burn_x` 1.25 faster while the rain is 0.6 or more (the rain cools it, so more wood goes).
  - It sends `smoke` 1 (below), and drops a tier only when its logs are gone, as today.
- **Small (40) and medium (1) fires go out in rain of 0.2 or more**, as today: back to laid (9), wood kept, and the wood in the store is now wet (section 5).
  - Jamie's medium option (dropping a tier every 10 to 20 minutes) is not taken. The decision names only large and small, and medium stays with today's simple rule.
- A roof, a tree crown or a cave (`cover_at` above 0.5, which now covers caves, #667) still counts as cover for every fire.

## 5. Wet wood (step 3)

- **Where wetness lives:** in the slot's `wear` field, the way spoilage keeps a food's age.
  - For a wood item (any id with a `cooking.json` `wood_class`), `wear` is the drying left, in tenths of a game hour. 0 is dry, so old saves read dry.
  - Wood never spoils, so the field is free for this.
  - A wet stack and a dry stack merge only when their drying left differs by less than `wet_merge_h` 2 game hours, and a merge keeps the wetter number. That is a small cost, and it never makes wood drier than it is.
- **What wets wood:**
  - Rain of 0.2 or more falling on it: loose wood lying uncovered, the store of an uncovered fire (laid or put out), and an open stockpile.
  - A pack and a chest under cover keep wood dry.
  - It is wetted up to its class's full wet time: weak `wet_h` 4, firewood 36, log 168 game hours (Jamie's timelag classes: sticks in hours, logs in weeks).
- **Freshly cut wood is dry.** Green wood is about half water in life (lesson 1), but Dave's chop-and-burn play stays as it is. Green wood is a later option, not part of this decision.
- **Drying:** wood dries at 1 per game hour anywhere the rain is not on it. Next to a lit fire (in its store, or within its heat reach on the ground) it dries ×`fire_dry_x` 6.
- **What wet wood does:**
  - **Lighting:** a laid fire whose weak wood is all wet lights at half the usual chance. With dry tinder in the store it lights normally.
  - **Burning:**
    - a wet piece burns ×`wet_burn_x` 1.5 as long, which is "burns slower";
    - it gives the heat and light of one tier lower (lesson 1: about 2/3 of the heat) until it is dry;
    - in the store it dries ×6, so a mixed store comes up to full heat as it goes.
  - **Smoke:** the fire row's `smoke` field is 0 for a clean fire and 1 while wet wood burns. Kathleen draws thick white-grey smoke at 1 (lesson 1, and lesson 6 for where it goes). Today campfires have no smoke at all, so Kathleen also gets a thin smoke at 0.

## 6. Steps and tests

Each step is a separate PR off main.

1. **Coals and warm ash.** States 42 and 43, `coal_bed_s`, `catch_s`, tinder on warm ash, the `glow` field, the protocol bump, and `cooking.json` keys.
   **Test `test_fire_coals`:**
   - a 10-minute fire burns out to coals, then after `coals_s` to warm ash, then after `ash_s` to cold ash, then is gone;
   - a 2-minute stick fire goes straight to cold ash;
   - firewood laid on coals catches in 45 s with no E;
   - tinder plus wood on warm ash lights in light rain where a cold fire fails the damp roll;
   - rain on uncovered coals turns them to ash, and then the ash goes cold;
   - coals warm within 1.5 m and not at 3 m;
   - wolves are not held off by coals;
   - a save and load keeps 42 and 43 with their time left.
2. **Rain on a big fire.** **Test:**
   - a log fire with a coal bed stays lit through 30 real minutes of rain 0.9 and burns ×1.25;
   - a log fire lit 1 minute ago (no coal bed) goes out;
   - a firewood fire goes out as today.
3. **Wet wood.** **Test:**
   - a loose stick in rain 0.5 becomes wet for 4 game hours and dries in 4;
   - a log needs 168;
   - a wet stack and a dry stack do not merge;
   - wet sticks light at half the chance;
   - a wet firewood piece burns 1.5 times as long at small-fire heat and sends `smoke` 1;
   - wood in a lit fire's store dries ×6;
   - a pack in the rain keeps its wood dry.

## 7. Open for Dave

The whole of section 1 is a coordinator decision that Dave may revert. Each part is a `cooking.json` key, and 0 turns it off:
- `coals_s` 0 brings back the 5-minute cold ash;
- `rain_burn_x` 0 brings back the old rain rule for large fires;
- `wet_h` 0 turns wet wood off.
