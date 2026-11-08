# Prevailing wind on the starter island at 34.3° S: wind rose by game month, fronts, gusts

**Last checked:** 2026-11-08 (Jamie). This page replaces [prevailing-wind-57s.md](prevailing-wind-57s.md) for retuning Kathleen's wind (#723). That older page is kept for its links. **Owners:**
- Kathleen: [prevailing_wind.md](../design/prevailing_wind.md) and #723.
- Weather: `src/shared/weather.gd` `wind_dir`.
- Everyone who reads the wind: smoke, snow drift, sound carry, tree lean, and scent (the server).

**Where the island is.** Grid rows run from −10 to +10, with the equator on row 0, and each row is 8.57°. The starter tile (3, 4) is on row +4, which is the 15th of the 21 rows counted from the north. Its centre is at 34.3° S, and the spawn is at 33.7° S (`one-sky.md`, decisions row 19).

**Related:** [wind-over-terrain.md](wind-over-terrain.md) (the mapping between game wind 0..1 and m/s, and gaps and channelling), [one-sky.md](one-sky.md), [fog-and-visibility.md](fog-and-visibility.md), [sound-outdoors.md](sound-outdoors.md).

## Lessons (read these first)

1. **At 34° S the wind turns with the season.**
   - **Local summer:** the island sits under the subtropical high, which lies to its south. The wind comes round the high from the south-east and south. It is steady and dry.
   - **Local winter:** the high moves toward the equator, and the westerlies and their fronts reach the island. The wind blows from the west to north-west ahead of each front and from the south-west behind it. It is wet and stormier.
   - **Cape Town (34° S)** is the model. Its south-easter blows "spring to late summer", "strong, often persistent and dry". In winter the north-westerlies come "often ahead of a cold-front", "can be far stronger than the South-Easter" and are "usually accompanied by rain" (Wikipedia, Cape Doctor).
   - **Auckland (37° S)** is the damper. It lies further into the westerlies: "predominantly from the southwest, especially in winter and spring", with "northeasterly winds" more common in summer (NIWA, Auckland climate).
   - **Our island** is in the open ocean, so we take Cape Town's seasonal flip, tempered by Auckland's south-westerlies.

2. **Fronts veer the wind, then back it.** This is the southern hemisphere's way round.
   - The low comes from the west and passes to the south. Ahead of it the wind veers (turns clockwise) from W through NW to N.
   - At the cold front it backs (turns counterclockwise) sharply to SW or S: "from northwest to southwest", with "a quick, yet strong gust of wind" (Wikipedia, Cold front).
   - Behind the front, the south-westerlies bring showers. At Auckland, "decaying cold fronts embedded in the flow frequently cause increases in the shower activity as they pass" (NIWA).

3. **The windiest time by mean speed is spring, not winter. The gales come in winter.**
   - At Auckland Airport the mean speed peaks in October and November at 21 km/h and is lowest in April at 15 km/h. Its share of strong-wind hours (31 km/h or more) is 36 % in spring and 19 to 23 % in the other seasons (NIWA, Tables 1 and 2).
   - Cape Town's summer south-easter is its strongest steady wind. Its winter north-westers bring the storms (lesson 1).

4. **On summer afternoons the wind picks up and sea breezes form.**
   - The mean speed at Auckland Airport is 15 km/h at midnight and 23 km/h at 15:00. NIWA puts the afternoon peak down to land heating mixing the stronger wind aloft down to the ground (Table 3).
   - Sea breezes come on fine days, "most often November to March", on about 20 % of summer days (NIWA).
   - A sea breeze is "not likely to develop" when the background wind blows offshore at more than 8 knots, about 4 m/s (Wikipedia, Sea breeze).

## Judged numbers for Kathleen's retune

**The game calendar.** Day 0 is the local spring equinox, and `game_clock.season()` splits the year into four even seasons of about 91 days each. Below, each season is split into three game months of about 30 days: Spring 1 is days 0 to 30, Spring 2 is days 30 to 61, and so on.

### 1. Wind rose by game month (% of hours with wind, by the sector it blows from)

| Game month (days) | N | NE | E | SE | S | SW | W | NW | Calm | Mean from | Constancy |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Spring 1 (0–30) | 4 | 4 | 8 | 22 | 16 | 16 | 15 | 15 | 7% | 202° SSW | 0.28 |
| Spring 2 (30–61) | 4 | 5 | 11 | 28 | 17 | 12 | 11 | 12 | 7% | 168° S | 0.30 |
| Spring 3 (61–91) | 4 | 6 | 14 | 32 | 18 | 9 | 8 | 9 | 8% | 148° SSE | 0.38 |
| Summer 1 (91–122) | 5 | 7 | 15 | 33 | 18 | 8 | 7 | 7 | 9% | 141° SE | 0.41 |
| Summer 2 (122–152) | 5 | 7 | 15 | 32 | 18 | 8 | 7 | 8 | 10% | 142° SE | 0.39 |
| Summer 3 (152–183) | 6 | 6 | 12 | 27 | 17 | 10 | 10 | 12 | 11% | 158° SSE | 0.26 |
| Autumn 1 (183–213) | 8 | 5 | 8 | 18 | 13 | 14 | 16 | 18 | 12% | 232° SW | 0.18 |
| Autumn 2 (213–243) | 10 | 4 | 5 | 10 | 10 | 17 | 21 | 23 | 11% | 270° W | 0.34 |
| Autumn 3 (243–274) | 11 | 4 | 3 | 6 | 9 | 18 | 24 | 25 | 8% | 277° W | 0.45 |
| Winter 1 (274–304) | 11 | 4 | 3 | 5 | 9 | 18 | 24 | 26 | 6% | 279° W | 0.46 |
| Winter 2 (304–335) | 10 | 4 | 3 | 6 | 9 | 19 | 25 | 24 | 6% | 274° W | 0.45 |
| Winter 3 (335–365) | 7 | 4 | 5 | 13 | 12 | 18 | 21 | 20 | 7% | 252° WSW | 0.32 |
| **The year** | 7 | 5 | 9 | 19 | 14 | 14 | 16 | 17 | 9% | 218° SW | 0.19 |

How to read the table:
- The sector columns add up to 100 % of the windy hours. Calm is the share of all hours below 1 m/s.
- The rows are **judged**, shaped on lessons 1 and 3. No sourced sector table for a 34° S ocean station was read.
- **Our sums from the rose:**
  - **Mean from** is the vector mean of the sectors.
  - **Constancy** is the length of the resultant: 1 when every hour blows from one way, 0 when the sectors cancel.
- **The two turnarounds are fast.** About Summer 3 the mean goes from SE to SW within one month, and about Autumn 1 to Autumn 2 it settles in the west. Spring 1 still has winter's fronts and summer's south-easter in about equal measure. These are the months when the wind is least predictable, so a 0.18 to 0.30 constancy is correct.
- **One spell, one direction.** The rose is a share of hours, not a jitter. The wind holds one direction for a spell (section 2) and then changes. A month of Spring 1 is a few days of south-easter, then a front with its north-westerly, and so on.
- **`wind_dir` at the mean** (the way the wind blows toward, `atan2(cos B, −sin B)`): Summer 1 (from 141°) is −2.25 rad; Winter 1 (from 279°) is 0.15 rad. The earlier page's winter "WNW 300°" was rounded too far north. With the south-westerlies behind fronts counted, the winter mean is W.

### 2. Spells (how long a direction holds)

| Season | Spell | How long (judged) |
|---|---|---|
| Local summer | South-easter (SE to S) | 2 to 6 days. It breaks down for a day of calm, a light NE or a weak front. Cape Town's south-easter "can blow for days" (Cape Doctor; days judged) |
| Local summer | Sea breeze on top | Afternoons only, on about 20 % of days (NIWA). It turns the coast wind onshore whatever the background, when the background is under 4 m/s |
| Local autumn and spring | Mixed | 1 to 3 days each way, with the season's direction winning more often |
| Local winter | One front cycle | 4 to 7 days from one front to the next (judged): 1 to 2 days fair W to WSW, half a day to a day of veering to NW and N, the front, then half a day to a day of SW showers |
| Local summer | Front | About one every 10 to 20 days, weak, often only a wind shift and cloud (judged) |

### 3. Front behaviour (veer, then back)

| Stage | Wind from | Turn | Speed against the season's mean | How long (judged) |
|---|---|---|---|---|
| Fair, between lows | W to WSW | none | 0.8 to 1.0× | 1 to 2 days |
| The low comes in | **veers** WNW → NW → N, 30° to 90° in all | clockwise, slowly | rising to 1.3 to 1.6× | 6 to 18 hours |
| Warm sector (if there is one) | N to NW | steady | 1.4 to 1.8×, damp, mild, drizzle | 3 to 12 hours |
| Cold front passes | **backs** to SW (or S), 45° to 120° | counterclockwise, in 10 to 60 minutes | a squall peak (section 4), then easing | the shift takes under an hour |
| Behind the front | SW to S | small swings with each shower | 1.1 to 1.4×, gusty, colder | half a day to a day |
| Ridge of high pressure | backs on to S or SE, or settles to W | slowly | falling to 0.5 to 0.8× | then the next fair stage |

- The directions and the gust at the front are sourced (Wikipedia, Cold front). The degrees, hours and speed factors are judged.
- **In summer** the same cycle runs further south and weaker. The island mostly sees the backing from SE through S toward SW and back again as the high rebuilds, with little or no NW.
- **In the game:** the cycle can follow the storm noise in `weather.gd`. As `storm` rises the wind veers slowly; at the storm's peak it backs sharply. Kathleen's design already turns fronts the southern hemisphere's way (§1 of `prevailing_wind.md`). What changes is the mean: it now follows the season, with the rose above in place of a year-round W to NW.

### 4. Gusts

| Situation | Gust factor (peak 3 s gust over the 10 min mean) | Example: mean → gust |
|---|---|---|
| Open sea, headland, steady summer south-easter | 1.3 to 1.5 | 7 m/s → 9 to 11 m/s |
| Open coast, ordinary day | 1.4 to 1.6 | 5 m/s → 7 to 8 m/s |
| Pre-front north-westerly, open | 1.4 to 1.7 | 10 m/s → 14 to 17 m/s |
| The cold front passing (squall) | 1.7 to 2.2, for 1 to 10 minutes | 10 m/s → 17 to 22 m/s |
| Post-frontal SW showers | 1.6 to 2.0, with each shower | 8 m/s → 13 to 16 m/s |
| Moorland inland | 1.6 to 1.8 | (lower mean, `wind-over-terrain.md`) |
| Under forest, in the lee of a crest | 2.0 to 3.0 | a weak mean with sudden puffs |

- **Sourced:**
  - At Cape Town, Windfinder's Van Riebeeckshof station (2018 to 2021) gives a mean of 7 kt and a mean gust of 11 kt. By our sums that is a factor of 1.6 inland.
  - Auckland Airport has gusts over 63 km/h (17.5 m/s) on 55 days a year, over 96 km/h (26.7 m/s) on 3 days, and gales on 3 days (NIWA, Table 4).
- **Judged:** the factors by situation. They use the usual rule that rough ground and showers raise the factor and a steady sea wind lowers it.
- **For the game:**
  - About 55 days a year with a gust over 17.5 m/s, mostly local winter and spring. By `wind-over-terrain.md`'s mapping (m/s = 20 × wind^1.3), that is a gust at game wind 0.90 or above.
  - About 3 days a year with a gust over 26.7 m/s. That is above the mapping's top of 20 m/s at wind 1.0, so either gusts may exceed 1.0 or the top gusts are clipped. That is Kathleen's call.
  - About 3 gale days a year (a mean of 17 m/s or more), in local winter.

### 5. Mean speed by game month (open coast at 10 m)

| Game month | Spring 1 | Spring 2 | Spring 3 | Summer 1 | Summer 2 | Summer 3 | Autumn 1 | Autumn 2 | Autumn 3 | Winter 1 | Winter 2 | Winter 3 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| m/s | 5.8 | 5.8 | 5.3 | 5.0 | 4.7 | 4.4 | 4.2 | 4.4 | 4.4 | 4.4 | 4.7 | 5.3 |
| Game wind | 0.39 | 0.39 | 0.36 | 0.34 | 0.33 | 0.31 | 0.30 | 0.31 | 0.31 | 0.31 | 0.33 | 0.36 |

- **Sourced:** Auckland Airport's monthly means from NIWA's Table 1, in km/h, divided by 3.6. Each game month takes the station month it mostly falls in. Spring 1 starts at the equinox, which is late September at a real southern station, so it takes October.
- The yearly mean is 5.0 m/s, which is game wind 0.34. That fits the 0.35 on the earlier page.
- **Day and night (sourced ratio):** the speed is about 0.85× the day's mean at midnight and 1.3× at 15:00 (Auckland Airport: 15 and 23 km/h against a mean of 18). Inland and on calm clear nights the drop is bigger: Whenuapai goes from 9 to 21 km/h.

### 6. Coast and inland, sea and land breezes

These are unchanged from [prevailing-wind-57s.md](prevailing-wind-57s.md) sections 4 and 5:
- open coast 1.0, moorland 0.8 to 0.9, above the forest canopy 0.55 to 0.65, under it 0.1 to 0.3;
- a sea breeze of 3 to 6 m/s from late morning to sunset when the background wind is under about 4 m/s;
- a land breeze of 1 to 2 m/s at night.

On the 34° S island, count the sea breeze on about 20 % of summer days (NIWA), fewer in spring and autumn, and almost none in winter.

## Never-see checks

- A westerly as the usual wind in local summer, or a south-easter as the usual wind in local winter.
- A cold front that veers the wind, or a front coming in that backs it.
- A wind that turns at random every few hours in a settled south-easter or a fair westerly spell.
- The strongest gusts of the year on a calm summer afternoon.
- A sea breeze on a gale day, or none on any calm, hot summer afternoon for a whole month.
- The forest floor as windy as the headland.
- The same mean wind all year: spring should be windier than autumn by about a third.

## How ours works today (read from main, 8 Nov, not tested)

- On main, `weather.gd` sets `wind_dir` from slow noise over the full circle, so there is no prevailing direction.
- Kathleen's `--wind-dir` (#723, not merged) adds a zone mean of W to NW all year, from the 57° S page. Retune it to the month rose above:
  - a mean that follows the game month;
  - spells of 2 to 6 days in summer and front cycles of 4 to 7 days in winter;
  - the section 4 gust factors.
- `wind_dir` is the way the wind blows toward: from compass bearing B, `wind_dir = atan2(cos B, −sin B)` (§2 of `prevailing_wind.md`; north is −Z).

## Sources

- Wikipedia, Cape Doctor: Cape Town's summer south-easter and winter north-westerlies. https://en.wikipedia.org/wiki/Cape_Doctor
- NIWA, The climate and weather of Auckland, 2nd edition (Tables 1 to 4: monthly mean speeds, strong and light wind shares, the daily cycle, gust days; sea breezes; fronts in the south-westerlies). https://docs.niwa.co.nz/library/public/NIWAsts60.pdf
- Windfinder, Cape Town / Van Riebeeckshof (mean 7 kt, mean gust 11 kt, 2018 to 2021). https://www.windfinder.com/windstatistics/cape-town_van-riebeeckshof
- Wikipedia, Cold front (the southern hemisphere wind shift). https://en.wikipedia.org/wiki/Cold_front
- Wikipedia, Sea breeze (the 8 knot limit). https://en.wikipedia.org/wiki/Sea_breeze
- Our sums: the means and constancy from the rose, the km/h to m/s and game-wind conversions, the gust factor from Windfinder's means, and the `wind_dir` formula.
- **Still wanted:** a sourced 8-sector rose by month for a 34° S ocean station (Cape Town airport, Cape Point, or Lord Howe Island at 31.5° S), and a count of front passages per winter month.
