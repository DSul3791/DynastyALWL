# Prevailing wind on the starter island (about 34° S): direction by season, fronts, coast and inland, sea breezes

**Last checked:** 2026-11-08 (Jamie; a short web pass, with much of it judged. Rewritten for 34° S after the grid fix: the starter island is at 33.7° S at the spawn, not 57° S, `one-sky.md` and `OVERNIGHT_DECISIONS_8NOV.md` row 19, #717. The file name still says 57s so links do not break). **Owners:**
- Kathleen: the prevailing wind design note.
- Weather: `src/shared/weather.gd` `wind_dir`.
- Everyone who uses the wind's direction: snow drift, smoke, sound carry, tree lean, animals.

**Related:** [wind-over-terrain.md](wind-over-terrain.md) (which has the wind 0..1 to m/s mapping), `one-sky.md` (#706), [snow-on-slopes.md](snow-on-slopes.md), [sound-outdoors.md](sound-outdoors.md).

## Lessons (read these first)

1. **At about 34° S the wind changes with the season: south-easterly in local summer, westerly to north-westerly in local winter.**
   - At this latitude an island sits under the edge of the subtropical high. In local summer the high lies to the south and the wind comes round it from the south-east. In local winter the high moves toward the equator and the westerlies and their fronts reach the island (judged, standard climatology; not fetched).
   - **Cape Town** (34° S) shows both: the south-easter blows "spring to late summer (September to March in the southern hemisphere)", "strong, often persistent and dry". Winter brings north-westerlies, "often ahead of a cold-front", which "can be far stronger than the South-Easter" and are "usually accompanied by rain" (Wikipedia, Cape Doctor).
   - **For us:** summer winds from SE to S, dry and steady; winter winds from W to NW, wet and stormier, with fronts.
   - The earlier version of this page put the island at 57° S, in the year-round westerlies. That was wrong.

2. **Southern hemisphere fronts turn the wind the other way round.** This holds in local winter, when the fronts reach the island.
   - In the southern hemisphere, a cold front shifts the wind "from northwest to southwest (counterclockwise, backing)". Before it, the wind is "northwest to northeast". After it, it is "south to west, usually southwest" (Wikipedia, Cold front).
   - So Kathleen's reading is right:
     - ahead of the front, the wind veers from W to NW and N (clockwise) as the low comes in from the west;
     - at the cold front, it backs sharply to SW, with "a quick, yet strong gust of wind".
   - Wikipedia gives no degrees or hours. Our judged numbers are below.

3. **At 34° S the sea breeze matters on summer days.**
   - Sea breezes reach 1 to 2 km deep and 10 to 100 km inland. An offshore wind of more than 8 knots (about 4 m/s) means the breeze is "not likely to develop" (Wikipedia, Sea breeze).
   - The breeze's strength goes with the land-sea temperature difference. A warm summer land against a cooler sea gives a real afternoon breeze, and the summer wind is often light enough for it.
   - **Judged:** a sea breeze on most sunny summer days when the background wind is light, and on some spring and autumn days.

## Judged numbers for Kathleen's design note

### 1. Wind rose (share of each season, from each sector)

| From | N | NE | E | SE | S | SW | W | NW |
|---|---|---|---|---|---|---|---|---|
| Local summer | 5% | 6% | 14% | 30% | 18% | 9% | 9% | 9% |
| Local winter | 10% | 4% | 3% | 5% | 9% | 18% | 25% | 26% |
| The year | 8% | 6% | 9% | 17% | 13% | 14% | 17% | 16% |

- **Judged.** The shapes follow lesson 1 (Cape Town's summer south-easter and winter north-westerlies). No sourced sector table was read.
- **Mean direction:** local summer about 140° (SE); local winter about 300° (WNW). Spring and autumn swap between the two, about half and half.
- **`wind_dir`** (the way it blows toward, our formula below): from SE (135°) it is −2.36 rad; from WNW (300°) it is 0.52 rad.

### 2. Steadiness

- **Directional constancy** (the resultant over the mean speed): about 0.5 to 0.6 within a season (judged); summer's south-easter is the steadier. Over the whole year it is low, about 0.2 to 0.3, because the two seasons blow from opposite sides (our sums from the rose).
- **Within ±45° of the season's mean:** about 60% of the time in local winter (W plus NW plus half of SW and N) and about 55% in local summer (SE plus half of E and S) (our sums from the rose).
- **How long a direction holds:** in local winter a spell lasts 1 to 3 days before a front turns it (a low every 4 to 7 days at this latitude, judged). In local summer the south-easter holds for days at a time, broken by calm spells and sea breezes (judged).

### 3. Fronts (southern hemisphere, mostly local winter)

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

- **When:** when the background wind is under about 4 m/s (sourced, 8 knots), on sunny days, mostly in local summer (judged).
- **Speed:** 3 to 6 m/s (judged).
- **Onset:** late morning, about 10:00 to 11:00. The peak is around 14:00 to 15:00 and it dies at sunset (judged).
- **Depth:** a few hundred metres to 1 km (judged), and it reaches 10 to 20 km inland on the bigger islands.
- **Land breeze:** at night, weaker (1 to 2 m/s), and down the valleys toward the sea. It joins the night drainage on `wind-over-terrain.md`.

### 6. Mean speed and windy season

- **Mean annual speed:** about 5 to 5.5 m/s on an open coast at this latitude (judged, from memory of mid-latitude coastal stations; not fetched).
  - With our mapping (m/s = 20 × wind^1.3), that is wind 0.34 to 0.37. For our starter, a mean of about 0.35 is a fair middle. The earlier 0.4 to 0.45 was for 57° S.
- **Gales:** perhaps 10 to 25 days a year, mostly with winter fronts (judged).
- **Windy season:** **local winter** for storms and gales. A strong summer south-easter can blow for days, but it is dry and steadier (lesson 1). Calmest: late local summer and early autumn mornings (judged).

## Never-see checks

- a west wind as the usual wind in local summer, or a south-easter as the usual wind in local winter;
- a cold front that veers the wind;
- a wind that turns at random every few hours on a fair day;
- a strong sea breeze on a gale day, or no sea breeze on a calm, hot summer afternoon;
- the forest floor as windy as the headland.

## How ours works today (read from the code, 8 Nov, not tested)

- `weather.gd` sets `wind_dir` from slow noise over the full circle, `TAU × _noise(seed, 4, game_s ÷ 20 h)`, plus a storm wobble. **There is no prevailing direction.** Every bearing is equally likely.
- `wind_dir` is the way the wind blows toward, as an angle on (x, z), with north at −Z.
  - **Our sums:** a wind from compass bearing B has `wind_dir = atan2(cos B, −sin B)`.
  - So a wind from the west is 0. From WNW (300°) it is 0.52 rad, and from NW (315°) 0.79 rad.
- `tree_wind.gd` `CALM_WORLD_WIND` is [0.35, 0.6], so a mean wind of about 0.35 would keep the trees quiet on most days (`CONTRADICTIONS.md` B1, #690).

## Sources

- Wikipedia, Cape Doctor (Cape Town's summer south-easter and winter north-westerlies). https://en.wikipedia.org/wiki/Cape_Doctor
- The 57° S version also used Macquarie Island, Campbell Island and Stornoway. Those apply to the outer starters near 51° and are kept here for them: https://en.wikipedia.org/wiki/Macquarie_Island, https://www.nzgeo.com/stories/danger-isles/, https://www.windfinder.com/windstatistics/stornoway
- Wikipedia, Cold front (southern hemisphere wind shift). https://en.wikipedia.org/wiki/Cold_front
- Wikipedia, Sea breeze (depth, reach, the 8-knot limit). https://en.wikipedia.org/wiki/Sea_breeze
- Our sums: the wind mapping, the log-profile ratios, constancy from the rose and the `wind_dir` formula.
- **Wanted:** a sourced seasonal wind rose for a station near 34° S on an ocean coast (Cape Town, Valparaíso or Auckland), a mean speed, and a gale-day count.
