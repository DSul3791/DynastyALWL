# One temperature: the island climate and the air everything reads

Jamie, 8 Nov 2026. This change does three things:
- It carries out the coordinator's call on #616: `Weather.air_c` becomes the one live temperature.
- It uses Sonny's climate record shape (his A4 item in `docs/water/watershed_rebuild_design.md` on #537).
- It closes the open item "one temperature model" in `docs/knowledge/snow-lines-mountain-climate.md` (#594).

It is stacked on #616 (`docs/design/still_water_ice.md`).

## The rule

Air temperature at a place and hour (`src/shared/climate.gd`):

> air = `sea_level_mean_c` + `seasonal_swing_c` × cos(2π (year phase − `warmest_year_phase`)) + `daily_range_c` / 2 × day_shape(hour) − `lapse_c_per_km` × height / 1000

- **day_shape** is −1 at 05:00 (coldest, just before dawn) and +1 at 15:00. It rises as a half cosine over 10 hours and falls as one over 14 hours, so the day's mean is the seasonal number.
- **Readers.** Weather, warmth, ice and snow all use this formula:
  - `Weather.temp_at` is the day's mean;
  - `Weather.air_c` is the hour's air;
  - `Weather.state`'s `temp_c` is `air_c` less the rain's cooling, as before.
- **Snow** falls when that `temp_c` is under 0.5 °C, so night snow can now fall where the afternoon would give rain.
- **The record.** Each island's numbers come from Sonny's `record/climate.json` (one object per island id, same field names). Until the record exists they come from one constant table, `Climate.DEFAULTS`:

| Island (zone today) | Mean | Seasonal ± | Warmest phase | Day range | Lapse | Rain |
|---|---|---|---|---|---|---|
| starter (temperate) | 9.0 °C | 5.0 °C | 0.375 | 8 °C | 6.5 °C/km | 2,000 mm/yr |
| desert | 28 | 8 | 0.375 | 14 | 6.5 | 150 |
| transition | 19 | 11 | 0.375 | 10 | 6.5 | 700 |
| arctic | −9 | 14 | 0.375 | 5 | 6.5 | 400 |

- **Starter numbers.**
  - The starter's mean and swing are Sonny's (Fort William at the foot of Ben Nevis).
  - The 8 °C day range is the coordinator's starter value (judged). Maritime islands should be smaller, and no sourced figure was found today.
- **Other zones.** They keep the weather's old zone means and swings. Their day ranges and rain are judged, until their islands have records.
- **Rain field.** `rain_mm_yr` is carried for the record's shape only. The live weather's wetness is still per zone. The starter's 2,000 mm is a rough Fort William figure, not checked.
- **Islands are found by zone, not yet by position.** The temperate zone reads the starter island.

## What moves

**Before:** the weather was season-only, with the temperate zone at 10 °C ±14 and no day and night. Tyler's warmth added its own day and night swing on the server (`daily_offset`, sized by cloud, rain and wind), and the breath in #605 copied that swing on the client.

**Now:** one swing for everything, and the starter is milder in winter and cooler in summer.

### Starter at sea level

| Season | Before | Now, 05:00 to 15:00 |
|---|---|---|
| Midwinter | −4 °C all day | 0 to 8 °C |
| Spring equinox | 0 °C | 1.5 to 9.5 °C |
| High summer | 24 °C | 10 to 18 °C |
| Mid autumn | 10 °C | 5 to 13 °C |

### Snow line, where `temp_c` is under 0.5 °C

| Season | Before | Night, at 05:00 | Day, at 15:00 |
|---|---|---|---|
| Midwinter | sea level all day | sea level | about 1,150 m |
| Spring equinox | sea level | about 150 m | about 1,400 m |
| Mid autumn | about 1,450 m | about 700 m | about 1,900 m |
| High summer | about 3,600 m | about 1,450 m | above the summit (1,410 to 1,440 m) |

- High summer never snows on the summit. That agrees with #594: today's snow line is about 1,450 to 1,550 m, with no glaciers.
- Ground snow (`weather_sounds.gd`) stops melting on frosty nights.

### Breath

Breath shows below 5 °C (#605, `FROM_C`).

| Place | Midwinter | Mid autumn | High summer |
|---|---|---|---|
| Sea level | 14 hours a day (night and morning) | about 1 hour around 05:00 | never |
| 500 m | all day | 11 hours | never |
| Summit | all day | all day | 13 hours (the night) |

### Warmth (server)

- `warmth_target` reads `temp_c` minus the lapse, and no longer adds `daily_offset`. Leaving it in would count the swing twice.
- **Removed:** the function, its test block in `test_warmth.gd`, and the `daily_swing_c`, `daily_low_hour` and `daily_high_hour` keys in `data/items/warmth.json`.
- **What is lost:** Tyler's swing narrowed in cloud, rain and wind. The one formula has no weather in its swing yet; rain still cools `temp_c` by up to 4 °C.
- **Feel:** winters are milder (no −4 °C sea-level days) and summers cooler (18 °C afternoons, not 24 °C plus the old swing).
- **Swimming.** The water temperature follows `temp_c` at sea level, so it now swings a little through the day (water_follow 0.7). A lagged water temperature would be better later.

### Ice (#616)

- The starter coast is too mild for pond ice. The midwinter low at sea level is 0 °C, and ice needs air below 0 °C and water at 4 °C or colder.
- **About 100 m up:** ponds get night ice on about 50 mornings a year.
- **At 300 m:** about 100 mornings.
- **On thaw days:** at 300 m, every night's ice is gone by 14:00 on days that reach 2 °C at noon.
- **Higher up:** at 800 m and over, a hard frost (below about −2 °C) leaves ice that lasts into the afternoon.
- **Walkable ice** forms only near the summit in deep winter. Kathleen's frosty-night rule therefore shows on the starter from the foothills up, not on the shore.

### Rivers in a dry spell

`Weather.river_dry` starts drying rivers above 22 °C (full effect at 32 °C). The starter's afternoons now peak at about 18 °C at sea level, so starter rivers no longer shrink from heat; only rain-free spells matter. Whether the starter should have summer low flows is a question for the water work (Sonny), not decided here.

### HUD and debug

The air temperature shown in the inventory and character screens, and in the debug line, now swings through the day.

### What does not move

- Rain, clouds, wind, fronts, valley fog and sea fog: none of them read the temperature.
- Desert, transition and arctic seasonal means and swings.
- The worldgen tile climate: its own numbers stay until the record's readers (R6).

## Cold and warm spells (stacked follow-up, coordinator's call 8 Nov)

**Why.** Without spells the starter coast never froze. Its coldest hour sat at about 0 °C, while the real Fort William gets air frosts in most winters.

**The rule** (`Climate.spell_c`), with Sonny's field names:
- **Air** = mean + seasonal + spell + daily − lapse × h.
- **The spell** = `spell_amplitude_c` × (2 × mix − 1), where mix = 0.6 × noise(day / longest) + 0.4 × noise(day / shortest).
  - `spell_days` = [shortest, longest] = [3, 6].
  - Both are smooth value noise from the world seed in the island's own stream (`spell_stream`, ours).
  - This is a bounded random walk that relaxes back to the season, so a spell lasts about 3 to 6 days.
- **Long-run record.** The record and the baked snow window use the climate **without** spells (the long-run average); the live air adds them.
- **The same everywhere.** Server and clients agree: the server's pond ice for fishing, the client's ice and the weather all pass the world seed.
- `spell_amplitude_c` per island (judged):

  | Island | spell_amplitude_c |
  |---|---|
  | starter | ±4 °C (coordinator and Sonny) |
  | desert | ±3 |
  | transition | ±3 |
  | arctic | ±3 (kept low so the arctic pond's yearly melt still has no sudden jump) |
  | small ocean island, later | about ±2 |

**What it gives** (sums from an exact Python copy of the noise; seeds 0, 777 and 12345):
- **Air frosts:** 25 to 60 nights a year at sea level on the starter. The real Fort William figure was not checked today.
- **Spell range:** about −3.8 to +3.8 °C. The largest change in one day is about 2 °C.
- **Ice, seed 777:**
  - the coast's ponds get ice on about 40 mornings a year;
  - ponds at 300 m on about 84;
  - a frosty night's ice (down to −3 °C) at 300 m is still gone by 14:00 on days that reach 2 °C at noon;
  - after a hard frost below −3 °C, ice can last into the afternoon.
- **Snow** can now fall at sea level on cold-spell nights in winter, and summers have warm spells up to about 22 °C at 15:00.

**Checks:**
- `test_weather`: spells stay within ±`spell_amplitude_c` and do swing; they change by under 2.5 °C a day; they follow the seed; and the coast gets 10 to 120 air-frost nights a year.
- `test_ice`: uses world seed 777. The coast gets some icy mornings, but fewer than at 300 m.

## Follow-ups for others

- **Kathleen (#605).** `breath_look.gd` adds its own copy of `daily_offset`. Once this merges it should read `temp_c` alone, or the breath counts the swing twice.
- **Steve.** Check the night cold against the new numbers: the starter's coldest sea-level hour is now about 0 °C. Steve was asked to check night cold fairness when the climate record lands.
- **Sonny.** The record's `climate.json` replaces `Climate.DEFAULTS` field for field. A reader that finds the island by position, not by zone, comes with R6.
- **Later, not decided.** Weather in the swing (narrower under cloud). Cold spells: done, see the section above.

## Checks

- **`test_weather`:**
  - `temp_c` is always the island air, or up to 4 °C cooler in rain, over a whole year;
  - the starter's sea-level mean runs 4 to 14 °C;
  - the day's range is 8 °C from 05:00 to 15:00;
  - it is 6.5 °C colder per km;
  - summer is warmer than winter (the margin is now 6 °C, since the swing is ±5 °C, not ±14 °C).
- **`test_ice`** now runs on the starter at 300 m:
  - frosty mornings;
  - one night's ice gone by 14:00;
  - deep lake later than shallow pond;
  - the coast stays open in midwinter;
  - a summit tarn bears at midday in deep winter.
- **`test_warmth`:** the day and night block is removed, and the other warmth checks pass weather in directly, so they are not affected.
