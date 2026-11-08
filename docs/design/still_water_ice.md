# Ice on still water: frosty nights, midday thaw, a sea that does not freeze

> **Update (stacked follow-up):** the air's numbers now come from the island climate and are the one live temperature: see `docs/design/one_temperature.md`. The day range there has no midwinter shrink, the temperate zone is the starter island (9 °C ±5), and `temp_c` now carries the swing. The ice rules below are unchanged; the sums in this note are for the old 10 °C ±14 climate.

Jamie, 8 Nov 2026. This builds Kathleen's ask 3 in `docs/design/art_water.md` (#587, section 8 item 5 and the winter row of section 10), which stays the source of truth for the look. It changes the ice model of `docs/mirror/tech/ICE_DESIGN.md` (approved 21 Oct). Dave's rules from that note still hold: pond and lake ice always bears once it is walkable, and you never drop through as it melts.

**Kathleen's rule:** ponds and lake edges freeze below 0 °C overnight, thaw by midday above 2 °C, and the sea never freezes. Art also wants ice to form "from the shore inwards in winter, thin and clear at first, white-frosted later".

## What was there, and why it could not do this

- **`src/shared/ice.gd`, `Ice.cover`:** a pure function of the clock, the zone and the altitude.
  - It runs hourly over the last 30 game days.
  - Ice grows by the Stefan law and melts at 1 mm per degree-hour.
  - The client sets it on the water shader (`ice` uniform: a sheet grows from the shore and shallows in patches, clear and dark when thin, milky with cracks when thick) and on the walkable collider (from cover 0.5).
  - The server uses the same number for fishing through the ice.
- **There was no day and night in the air.** `Weather.temp_at` is the season only, so a pond could not freeze at night and thaw by day.
- **The sea froze in every temperate winter.** `terrain_client.gd` fed the sea floes from `Ice.cover` at sea level (minus 0.05). A temperate midwinter at sea level is -4 °C all day, so floes would appear.
- **The first frost froze everything at once.** A new sheet started at 2 cm the moment the air dropped below 0 °C, even when the water was still at summer warmth.

## The real thing

- **Air temperature runs a daily cycle.** It is coldest just before dawn and warmest in the afternoon. Clear skies widen the range and cloud narrows it, and winter ranges are modest (Met Office, "What is diurnal temperature range", 2026). UK land ranges of about 7 to 9 °C are general knowledge, not checked against a source today.
- **Water must cool first.** A pond or lake must cool to about 4 °C (39 °F) all through before an ice sheet forms on the first calm, freezing night (Star Tribune, Minnesota freeze-up). Shallow ponds get there first, and deep lakes later.
- **First ice is thin and comes and goes.** Early ice can form and melt again the next day (the same article: Lake Waconia froze one day and reopened the next).
- **Sea water freezes at about -1.8 °C** and needs long, steady cold (WHOI, Beaufort Gyre dispatch 18). Temperate seas almost never freeze.

## The rule (`src/shared/weather.gd`, `src/shared/ice.gd`)

### Air with a day and night swing: `Weather.air_c(game_s, group, altitude_m)`

- **Base:** `temp_at` (season and altitude), plus half the day's range × `day_shape(hour)`.
- **Shape:** -1 at 05:00 (coldest, just before dawn) and +1 at 15:00. It rises as a half cosine over 10 hours and falls as one over 14 hours, so the day's mean is `temp_at`.
- **Range** (judged), shrunk to 60% in midwinter:

  | Zone | Range |
  |---|---|
  | Temperate | 8 °C |
  | Transition | 10 °C |
  | Desert | 14 °C |
  | Arctic | 5 °C |

- **No weather yet.** Clouds and rain should narrow it, and that needs the seed.
- **`Weather.state`'s `temp_c` is not changed.** Snow, breath, warmth and the server's air temperature still read the season-only number. Switching them to `air_c` is a decision for whoever settles the one temperature model (the climate record in Sonny's #537). This change keeps the swing to ice so nothing else moves.

### Ice: `Ice.cover(game_s, group, altitude_m, depth_m)`

It still runs hourly over 30 game days, now on `air_c`, with three changes:

1. **The water cools first.**
   - The water's temperature follows the air with a lag of 2 days for a 1 m pond, rising to 12 days for a 10 m lake (judged).
   - No ice forms until the water is at 4 °C or colder. A deep lake therefore starts freezing later in autumn than a pond.
2. **A new skin starts at 5 mm, not 2 cm.**
   - One frosty night (about 2 °C below freezing for 8 hours) grows about 2 cm by the Stefan law.
   - That is cover 0.1. The shader draws it as rim ice at the shore and in the shallows (`grown = ice·1.25 + edge·0.5 − patch·0.5 − 0.05`), clear and dark: Art's "thin and clear at first".
3. **Thin ice melts in daylight.**
   - Ice under 5 cm thick loses 4 mm an hour more from 08:00 to 16:00 while the air is above freezing (judged).
   - A frosty night's ice is gone by about 14:00 on a day that reaches 2 °C at noon.
   - A thick winter sheet is white and reflects the sun, so it does not get this melt. It thins only by the air's degree-hours as before, so walkable ice is not lost in an afternoon.

### The sea: `Ice.sea_cover(game_s, group)`

- It is always 0 outside the arctic zone.
- In the arctic zone, salt water freezes at -1.8 °C, at a 12 m depth.
- The floes (`ocean_ice.gd`, `ice_floes.gd`) are kept for the arctic. The coordinator's call: they go "unless a cold island type wants them". The arctic zone stands in for that until island types exist in the climate record.

## What it gives (sums from a Python copy of the code, temperate zone, sea level, 3 m pond)

| Day of year (season) | Night low | Noon | Pond ice |
|---|---|---|---|
| 240 (early autumn) | 4.1 °C | 8.8 °C | none |
| 260 | -0.1 °C | 4.2 °C | a trace at dawn (cover 0.03), gone by 09:00 |
| 270 | -1.9 °C | 2.2 °C | cover 0.11 at dawn, 0.03 at noon, gone by 14:00 |
| 280 | -3.5 °C | 0.5 °C | about 0.15 to 0.18, still 0.08 at 15:00 |
| 300 (early winter) | -5.7 °C | -1.8 °C | about 0.93: bears a person |
| 320 (midwinter) | -6.4 °C | -2.6 °C | full sheet |

- Over a year there are about 120 mornings with some ice.
- On all 23 days that freeze at night and reach 2 °C at noon, the night's ice is gone by 14:00.
- First ice comes on day 260 for a 1 m pond and day 265 for a 10 m lake.
- The arctic pond's yearly build and melt keeps the same largest two-day step as before (0.40, then 0.42).

## Checks (`src/worldgen/tools/test_ice.gd`)

- `day_shape` is -1 at 05:00 and +1 at 15:00, and smooth through midnight. The day's mean air is the season's temperature.
- Temperate ponds have ice on at least 20 mornings a year.
- Thaw rule: on every day with a frosty night, a noon of 2 °C or warmer and thin dawn ice (cover under 0.25), there is no ice at 14:00. At least 5 such days must occur.
- A temperate pond still bears at midday in deep winter.
- A 10 m lake freezes later in autumn than a 1 m pond.
- The sea never freezes in the temperate, transition or desert zones. The arctic sea freezes in midwinter.
- The existing checks stay: no summer ice, no desert ice, the arctic pond bears in midwinter and changes gradually, and the walkable sheet only on still water.

## Known limits

- **One pond depth for the look.** The client uses a 3 m depth for every still water near the player, so a deep lake and a puddle look the same at the same moment. Per-body depth needs the record's lake depths (Sonny's R3).
- **No clouds in the swing.** A cloudy night should not freeze. This needs the seed in `air_c`, and the server's fishing call would have to pass it.
- **`temp_c` and the ice now disagree at night.** The HUD can say 2 °C while a pond freezes at 03:00. This lasts until the one temperature model is settled (above).
- **Frost rims on the ground and plants in autumn** (Art, section 8 item 5) are not in this change.
- **Freezing falls and edge ice on rivers** (Art, section 10 winter row) are not in this change. Running water still never freezes.

## Pictures for Dino (windowed, on the PC, after merge to a test branch)

The look is the existing shader. These shots check that the timing reads right:
- a temperate pond at about day 270 at 07:00 and again at 14:00 (rim ice, then open water);
- the same pond at day 320 at noon (full sheet);
- the open temperate sea at day 320 (no floes).
