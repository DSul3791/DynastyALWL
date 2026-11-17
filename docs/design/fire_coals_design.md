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

Two new world-item states, 76 and 77, are the first free numbers after `structures.json` (42 to 75 are building pieces), so old clients and saves read nothing wrong:

| State | Name | Lasts | Light (client) | Warmth | Wolves |
|---|---|---|---|---|---|
| 76 | coals | `coals_s` 7200 real s | dim red, about 1 m, no flame, a thin wisp | `coals_heat_c` 8 °C within `coals_heat_m` 1.5 m | not protected: `fire_is_lit` stays false |
| 77 | warm ash | `ash_s` 43200 real s | none, a faint wisp for the first hour | none | no |
| 8 | cold ash | `FIRE_OUT_S` 300 s, as today | none | none | no |

- **Burning out:**
  - When `burn_left` reaches 0, a fire with a coal bed becomes 76. A coal bed is `coal_bed_s`, 600 real s (10 minutes), of burning in total since it was last cold.
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
  - Pick-up (hold E) works on 76 and 77 as on 8, and nothing burns the player.
  - `left` counts down as now. 76 becomes 77 when it runs out, and 77 becomes 8.
- **Wire:**
  - The fire row gains one field, `glow` 0..1. That is how far through its coals or warm-ash time the fire is, so the client can dim it.
  - Protocol bump. An old client drawing an unknown state draws nothing, which is safe.
  - Kathleen draws 76 and 77.

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

1. **Coals and warm ash.** States 76 and 77, `coal_bed_s`, `catch_s`, tinder on warm ash, the `glow` field, the protocol bump, and `cooking.json` keys.
   **Test `test_fire_coals`:**
   - a 10-minute fire burns out to coals, then after `coals_s` to warm ash, then after `ash_s` to cold ash, then is gone;
   - a 2-minute stick fire goes straight to cold ash;
   - firewood laid on coals catches in 45 s with no E;
   - tinder plus wood on warm ash lights in light rain where a cold fire fails the damp roll;
   - rain on uncovered coals turns them to ash, and then the ash goes cold;
   - coals warm within 1.5 m and not at 3 m;
   - wolves are not held off by coals;
   - a save and load keeps 76 and 77 with their time left.
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

## 8. Charcoal left by burning wood (17 Nov 2026)

Dave, 17 Nov 2026: "I shouldn't have to craft charcoal it should just automatically get left int he campfire as wood burns. it should be a biproduct", then "anything that burns wood should leave behind charcoal". Built in `server_items.gd` (`_fire_burn` counts it, `_fire_leave_charcoal`, `_light_leave_charcoal`), set in `cooking.json` `charcoal_left`, tested by `test_fire_charcoal`. Nobody has played it yet.

### For Dave (provisional, chosen on your behalf; change the numbers in `cooking.json` `charcoal_left`)
- **CH-1 How much.** One Charcoal for every 9600 game seconds of wood burned: a Firewood leaves 3, a Wooden block 6, a log 27. Part-made lumps carry over and are saved with the fire. The kiln yields you gave (log about 100, firewood about 10) stay far better: a log in a fire gives about a quarter of a kiln's. An evening's medium fire (3 Firewood, an hour) leaves 9; one bonfire log leaves 27, more than a Primitive smelter's full hopper (20).
- **CH-2 Small wood.** Sticks, driftwood, kindling and tinder leave none in a fire (`classes` lists only firewood and logs). Your kiln numbers give a stick about 5; in an open fire I judged a stick too small to leave a lump. Adding `"weak"` to `classes` makes sticks leave a third of a charcoal each.
- **CH-3 Where it goes.** Into the fire's own store, where you take it with F like food or wood. If the store has no free slot it lands on the ground beside the fire (never refused; no ground cap).
- **CH-4 Charcoal is not campfire fuel.** Its rows in `fuel` and `fuel_class` are gone, so the charcoal a fire leaves is never burned away, a store of only charcoal has no burn time, and the F window will not take charcoal into a fire. It is still the smelters' and smithies' fuel. Before, a charcoal in a fire burned 150 real seconds.
- **CH-5 It outlasts the fire.** Coals, warm ash and cold ash keep it. A cold fire holding charcoal waits a real day (`keep_s`) for the charcoal to be taken; then the charcoal is left on the ground beside it and the fire goes, so abandoned fires do not fill the fire limit forever. Taken sooner, the fire goes 5 minutes later as before. A half-burnt piece taken back out of a fire comes back whole, so the charcoal it had made is owed back from the next (no charcoal from wood that never burned). A smelter within 30 m still draws charcoal from an unlit fire's store by itself (GOALS-REPAIR A-30).
- **CH-6 What else leaves it.** The Fireplace (one Firewood per 2 hours, 3 charcoal) and the Stone and Iron braziers (a log per half hour, 27) drop it at their foot (`structures.json` `leaves_charcoal`). Left out on purpose: torches and sconces (they burn sticks), the Kiln (it already turns logs to charcoal; its slow self-burn burns charcoal, not wood), smithies and smelters (they burn coal or charcoal), and the Clay hearth and Oven (they cook on a nearby campfire, which leaves its own). A light's part-made lump is not saved over a restart (under one charcoal lost).
- **CH-7 The old recipe.** Campfire recipe 341 (2 Firewood to 12 Charcoal) is retired, its number kept. The design goal `craft:charcoal` is now "Get Charcoal" (have one, from any source) in `PLAYER_GOALS_CATALOG_CORRECTED.csv`; the goal catalog is still off. The Encyclopedia and the Coal and charcoal guide page say charcoal is left in the fire.

## 9. The three kilns (17 Nov 2026)

Dave, 17 Nov 2026: "there are suppose to be 3 tiers of kilns. primative which is small needs stones and clay to make and any wood can burn in it including sticks, firewood, kindling and logs. the bigger the wood the more charcoal it makes. logs make about 100 charcoal each. sticks would make about 5 kindling really wont make any but it will burn. firewood should make about 10", then "primative kiln, improved kiln(stones, clay, iron ingots) is bigger and can hold upto 4 logs. advanced kiln(stones, clay, iron ingots and steel ingots) bigger and can hold 6 logs". Built in `server_items.gd` (`_kiln_yield`, `_kiln_room`, `_kiln_burn`), set in `structures.json` `kilns` and the three kiln rows, tested by `test_station_storage` (5 and 5b). Nobody has played it yet.

### For Dave (provisional, chosen on your behalf)
- **KL-1 The old brick Kiln.** It is now the Primitive kiln (same item, blueprint and saved state), re-costed to stone and clay. It is not kept as a fourth kiln. Two new items: Improved kiln and Advanced kiln.
- **KL-2 Sizes.** Primitive holds 2 logs' worth of wood, Improved 4, Advanced 6. A kiln's room is counted in charcoal: 100 for each log it holds, a piece of wood taking its yield (at least 5, so kindling still takes room). So a Primitive kiln holds 2 logs, or 20 firewood, or 40 sticks, or a mix. Slots: the Primitive and Improved kilns keep the old Kiln's 6 input and 8 output slots (so a kiln already in a saved world keeps its contents in place), the Advanced has 8 and 8; how much wood fits is set by the logs' worth, not the slots. Input slots 4 / 6 / 8, output slots 3 / 5 / 8.
- **KL-3 Yields.** Your numbers: a log 100, a firewood 10, a stick 5, kindling 0 (it burns away). Mine: a Wooden block 17 (a sixth of a log) and driftwood 5 (like a stick). Note: since a log splits into 6 blocks and 24 firewood, splitting it to firewood first gives 240 charcoal instead of 100. Tell me if logs should give more, or firewood less.
- **KL-4 Costs.** Primitive 20 Stone + 10 Clay; Improved 30 Stone + 15 Clay + 4 Iron ingot; Advanced 40 Stone + 20 Clay + 6 Iron ingot + 4 Steel ingot.
- **KL-5 Bigger tiers take small wood too.** All three take any wood; the bigger ones just hold more. All three fire bricks and lime as the old Kiln did.
- **KL-6 Speed.** A charcoal every 3 seconds in every tier (a log 5 minutes, a firewood 30 seconds), as the old Kiln; the biggest wood burns first. Once all is done and still lit, it slowly burns its own charcoal, as before.
- **KL-7 Looks.** All three use the old domed kiln model as a placeholder until art draws them.
