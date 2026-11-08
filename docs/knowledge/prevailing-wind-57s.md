# Prevailing wind at 57° S: direction, steadiness, fronts, coast and inland, sea breezes

**Last checked:** 2026-11-08 (Jamie; a short web pass, with much of it judged). **Owners:**
- Kathleen: the prevailing wind design note.
- Weather: `src/shared/weather.gd` `wind_dir`.
- Everyone who uses the wind's direction: snow drift, smoke, sound carry, tree lean, animals.

**Related:** [wind-over-terrain.md](wind-over-terrain.md) (which has the wind 0..1 to m/s mapping), `one-sky.md` (#706), [snow-on-slopes.md](snow-on-slopes.md), [sound-outdoors.md](sound-outdoors.md).

## Lessons (read these first)

1. **The wind at 57° S comes mostly from the west and north-west.**
   - **Macquarie Island** (54.5° S, the nearest well-described analog): "high winds, largely from the north and north-west". The annual mean is about 33 km/h (9.2 m/s), and gales over 63 km/h came on 76 days of the year (1983 to 1984; Wikipedia, Macquarie Island).
   - **Campbell Island** (52.5° S): "the westerly winds bring frequent rain", with 1,425 mm on over 320 days a year. It gets 659 hours of sun, 16% of the possible total (*NZ Geographic*, Danger isles).
   - **Stornoway** (58° N, the Hebrides): the mean direction is 216° (south-west), and the mean speed 12 knots (6.2 m/s) (Windfinder, observations 2000 to 2026).
   - **The mirror (our sums):** flipping the hemisphere maps a compass bearing B to 180° − B. Stornoway's 216° becomes 324°, which is north-west. Both checks agree: **from W to NW, with a mean of about 300° to 320°**.

2. **Southern hemisphere fronts turn the wind the other way round.**
   - In the southern hemisphere, a cold front shifts the wind "from northwest to southwest (counterclockwise, backing)". Before it, the wind is "northwest to northeast". After it, it is "south to west, usually southwest" (Wikipedia, Cold front).
   - So Kathleen's reading is right:
     - ahead of the front, the wind veers from W to NW and N (clockwise) as the low comes in from the west;
     - at the cold front, it backs sharply to SW, with "a quick, yet strong gust of wind".
   - Wikipedia gives no degrees or hours. Our judged numbers are below.

3. **The sea breeze is a small thing on an island like ours.**
   - Sea breezes reach 1 to 2 km deep and 10 to 100 km inland. An offshore wind of more than 8 knots (about 4 m/s) means the breeze is "not likely to develop" (Wikipedia, Sea breeze).
   - The breeze's strength goes with the land-sea temperature difference. At 57° S the sea is cool, but the summer land is not much warmer. And the mean wind (6 to 9 m/s) is above the 4 m/s limit most days.
   - **Judged:** a sea breeze only on calm, sunny summer days, which on a Hebrides-like island is a few days a month in high summer.

## Judged numbers for Kathleen's design note

### 1. Wind rose (share of the year, from each sector)

| From | N | NE | E | SE | S | SW | W | NW |
|---|---|---|---|---|---|---|---|---|
| Share | 10% | 4% | 4% | 5% | 9% | 16% | 26% | 26% |

- **Judged.** It is built from the two sourced checks (Macquarie's N and NW, and Stornoway's SW mirrored to NW), with the usual westerly shape. No sourced sector table was read.
- **Mean direction:** about 300° to 320° (WNW to NW).
- **Easterlies** (the 13% from NE, E and SE) come with highs that sit to the south of the island: clear, cold and still in winter.

### 2. Steadiness

- **Directional constancy** (the resultant over the mean speed): about 0.5 to 0.7 (judged). Southern Ocean westerlies are among the steadiest winds on Earth away from the trades. A Hebrides-like island sits on their edge, so less than the open ocean.
- **Within ±45° of WNW:** about 55 to 65% of the time (judged; it is W plus NW plus half of SW and N in the rose, our sums).
- **How long a direction holds:** a spell of one direction lasts 1 to 3 days. Then a front turns it (judged; the westerlies carry a low every 3 to 5 days).

### 3. Fronts (southern hemisphere)

| Stage | Wind from | Speed | How long |
|---|---|---|---|
| Fair, between lows | W to WSW | mean | 1 to 2 days |
| A low comes in from the west | **veers** (clockwise) through WNW to NW and N, 30° to 60° in all | rising | 6 to 18 hours |
| Warm sector | N to NW | strong, steady, mild and damp | 6 to 12 hours |
| Cold front passes | **backs** 45° to 90° to SW, in minutes to an hour | a gusty peak, then easing | the shift takes under an hour |
| Behind the front | SW to S | gusty showers, colder | half a day to a day |

- All the degrees and hours are **judged**. The directions are sourced (Wikipedia, Cold front).
- **In the game:** the storm noise in `weather.gd` can set this: veer slowly as `storm` rises, back sharply when it peaks and falls.

### 4. Coast and inland

| Where | Mean speed against the open coast | Direction |
|---|---|---|
| Open coast, headland | 1.0 (a crest adds more: `wind-over-terrain.md`) | steadiest |
| Moorland 5 to 10 km inland | 0.8 to 0.9 | turned by valleys |
| Above a forest canopy | 0.55 to 0.65 | as moorland |
| Under the forest canopy | 0.1 to 0.3 | erratic, gusty |

- **Our sums:** the ratios use the log wind profile, with a blending height of 60 to 200 m and roughness of 0.0002 m for sea, 0.03 m for moorland and about 1 m for forest.
- **The direction is steadier on the coast** (judged). Inland, hills and valleys bend the wind into the valley line, and the turn reaches up to 90° in a narrow glen (`wind-over-terrain.md`, gaps and channelling).

### 5. Sea and land breezes

- **When:** only when the background wind is under about 4 m/s (sourced, 8 knots), on a sunny day in summer (judged).
- **Speed:** 2 to 4 m/s (judged, small for a cool coast).
- **Onset:** late morning, about 10:00 to 11:00. The peak is around 14:00 to 15:00 and it dies at sunset (judged).
- **Depth:** a few hundred metres here, less than the 1 to 2 km of warmer coasts (judged).
- **Land breeze:** at night, weaker (1 to 2 m/s), and down the valleys toward the sea. It joins the night drainage on `wind-over-terrain.md`.

### 6. Mean speed and windy season

- **Mean annual speed:** Stornoway 6.2 m/s, and Macquarie 9.2 m/s in an exposed, more southern spot.
  - With our mapping (m/s = 20 × wind^1.3), that is wind 0.41 for a Hebrides-like coast and 0.55 for Macquarie.
  - For our starter, a mean wind of about 0.4 to 0.45 is a fair middle.
- **Gales:** about 76 days a year at Macquarie. A Hebrides-like island has fewer, perhaps 30 to 50 (judged).
- **Windy season:** **local winter** on the game calendar (the Hebrides' windiest season is its winter), with the equinoxes close behind (judged). Calmest: local summer.

## Never-see checks

- an east wind as the usual wind;
- a cold front that veers the wind;
- a wind that turns at random every few hours on a fair day;
- a strong sea breeze on a gale day;
- the forest floor as windy as the headland.

## How ours works today (read from the code, 8 Nov, not tested)

- `weather.gd` sets `wind_dir` from slow noise over the full circle, `TAU × _noise(seed, 4, game_s ÷ 20 h)`, plus a storm wobble. **There is no prevailing direction.** Every bearing is equally likely.
- `wind_dir` is the way the wind blows toward, as an angle on (x, z), with north at −Z.
  - **Our sums:** a wind from compass bearing B has `wind_dir = atan2(cos B, −sin B)`.
  - So a wind from the west is 0. From WNW (300°) it is 0.52 rad, and from NW (315°) 0.79 rad.
- `tree_wind.gd` `CALM_WORLD_WIND` is [0.35, 0.6], so a mean wind of 0.4 to 0.45 would keep the trees at the quiet end most days (`CONTRADICTIONS.md` B1, #690).

## Sources

- Wikipedia, Macquarie Island (climate). https://en.wikipedia.org/wiki/Macquarie_Island
- *NZ Geographic*, Danger isles (Campbell Island weather). https://www.nzgeo.com/stories/danger-isles/
- Windfinder, Stornoway Airport wind statistics. https://www.windfinder.com/windstatistics/stornoway
- Wikipedia, Cold front (southern hemisphere wind shift). https://en.wikipedia.org/wiki/Cold_front
- Wikipedia, Sea breeze (depth, reach, the 8-knot limit). https://en.wikipedia.org/wiki/Sea_breeze
- Our sums: the mirror rule, the wind mapping, the log-profile ratios and the `wind_dir` formula.
- **Wanted:** a sourced wind rose for a Southern Ocean island station (Macquarie or Campbell Island sector table), and a measured directional constancy.
