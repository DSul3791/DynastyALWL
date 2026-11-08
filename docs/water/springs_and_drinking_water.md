# Springs, seeps and drinking water from the record

Sonny, 8 Nov 2026, for Steve's water-source items (Stage E readers). This page covers four things the island water record (R6) and the stream network (R5) give the game:
- where a player can drink;
- whether a spring still runs in a dry August, and how far its brook runs then;
- which water freezes in winter: seeps and the perched clay table freeze, springs do not.

Nothing here is placed by chance or painted. Every answer is read from fields the record already holds. The three additions it needs are listed at the end.

## Fields to read

| what | where | how to read it |
|---|---|---|
| water class | record tile raster `water_class` (u1, 8 m) | 2 lake and 3 river: fresh water. 4 to 7 (marsh, swamp, fen, bog): wet ground with water among plants. 8 seasonal channel and 9 seasonal pond: water only in the wet season. 1 ocean and 10 salt marsh: salt. |
| regime | `regime` (u1) | 1 perennial: runs all year, August too. 2 intermittent: dry in the dry season. 3 ephemeral: only during and just after rain. |
| flow | `discharge` (u2, log-coded mean m³/s) | Decode with the manifest's `fields` table: 10^(code / codes_per_decade − 4). |
| water table | `table_depth` (u1, 0.25 m steps) | R4's regional table, a yearly mean. Code 0 means the table is at the ground: a seep or wet ground. The reader takes the shallower of this and the soil's perched winter table (Jamie's wetness classes, #657). |
| nearest water | `fresh_m` (u2, m) | Distance to perennial fresh water: lakes and regime 1 water. |
| springs | `network.json` `springs` | One row per spring: `x`, `z`, `y`, `m3_s` (mean flow), `rock` and `feeds_reach`. |
| brooks in August | `network.json` `reaches` | Each reach's points carry `q_mean_m3_s`, `q_wet_m3_s` and `q_dry_m3_s` after bed losses. |
| dry-season share | `network_manifest.json` `summary.seasons.base_dry` | The island's baseflow in the dry quarter over its mean. |
| climate | `climate.json` | `sea_level_mean_c`, `seasonal_swing_c`, `daily_range_c`, `lapse_c_per_km`. |

## Where a player can drink

The game's drink already asks `water_near` within `thirst.reach_m` (3 m). With the record it says yes when any of these holds within reach:
- **A spring row.** Clean all year while its dry flow is above 0. Even 0.01 L/s fills a 300 ml mouthful in half a minute.
- **A river or lake cell** (classes 2 and 3) with regime 1, in any season.
- **A seasonal channel or pond** (classes 8 and 9, or regime 2 or 3), only in the wet season or right after rain. Steve's season clock decides.
- **Wet ground** (`table_depth` 0, or classes 4 to 7). There is no open water here, but a scrape dug with a tool fills in a few minutes. Peat water (bog, 7) is brown but drinkable.

Water quality is Steve's call for the sickness table. The physical order, cleanest first, is: spring, flowing river, lake, then still marsh, swamp and seasonal pond water. The still water is warm in summer and holds whatever the animals left.

## A dry August

**The spring itself.** A spring's August flow is `m3_s` × `base_dry` until per-spring stores exist (addition 1). The brook below can still read regime 2 when the spring does not stop. R4 calls a reach perennial only when its dry baseflow reaches 1 L/s (`perennial_baseflow_m3_s`), so a 0.6 L/s trickle at the spring is a dry-season drink while its brook dries below.

**How far its brook runs.** Walk the spring's `feeds_reach` points downstream. The August water ends at the first point whose `q_dry_m3_s` reaches 0, where the bed losses (above the table, on gravel or karst) have taken it.

## Winter: what freezes

**Springs do not freeze.** Groundwater stays near the year's mean air temperature, usually 1 to 2 °C above it (Anderson 2005, *Ground Water* 43:951). So a spring comes out at about `sea_level_mean_c` − `lapse_c_per_km` × height + 1 °C.

**How far below a spring the brook stays open.** On a frosty night the brook cools toward the air along its length. It reaches 0 °C at

  x₀ = λ ln((T_water − T_air) / (0 − T_air)), with λ = ρ c Q / (h W).

Here Q is the flow (m³/s), W the width (m), ρc is 4.19 MJ/m³K for water, and h is about 20 W/m²K for open water to cold night air (judged; wind raises it). Ice forms from x₀ on, by the #616 rim-ice rule.

**Seeps freeze.** A seep spreads its slow flow thin over a wide face, so λ is a metre or two. On a frosty night it turns to an ice sheet on the slope, slippery underfoot. Puddles on the perched clay table freeze by Kathleen's #614 rule (0.1 m by the ice rule).

**Frozen ground for weeks** only where the coldest month's mean, `sea_level_mean_c` − `seasonal_swing_c` − lapse × height, is below 0. On the starter island (9 °C, swing 5, 6.5 °C/km) that is above about 615 m. Below it, the ground freezes only a few centimetres on frosty nights: the daily wave fades about 0.12 m into moist soil. Thin ice is gone by early afternoon (#616).

## Worked example: the spring at cave 3,4#8002 (illustrative until the R4 and R5 runs)

This is a spring at the cave mouth, 56520 / 72360, at 533 m. Say R4 gives it 2 L/s (`m3_s` 0.002) and its brook is 0.5 m wide. The numbers are illustrative; the run replaces them.

- **Temperature.** The year's mean air there is 9 − 6.5 × 0.533 = 5.5 °C, the same as Jamie's cave air. So the spring water is about 6.5 °C, all year.
- **Drink.** Any time of year, within 3 m of the spring row.
- **August.** With `base_dry` 0.3, the spring gives 0.6 L/s: still a drink. Its brook is intermittent (under 1 L/s) and dries where its `q_dry_m3_s` reaches 0.
- **A −4 °C night in January.**
  - λ = 4.19e6 × 0.002 / (20 × 0.5) = 838 m.
  - x₀ = 838 × ln(10.5 / 4) = about 810 m.
  - So the brook runs open for about 800 m below the spring, then grows rim ice.
  - A seep on the slope beside it is an ice sheet by midnight.
- **The ground there.** At 533 m the coldest month averages 9 − 5 − 3.5 = 0.5 °C, so there is no frozen ground for weeks. Clay ground near the cave is wet at the surface all winter (class IV to V) and crusts with frost only on cold nights.

## Additions it needs (Sonny, after ws580g; record field list unchanged)

1. **Per-spring dry flow.** R5 gives each spring its own store, with response time τ = 4 S_y L² / (π² T) (Rorabaugh 1960):
   - T from R4's transmissivity at the spring;
   - L the length of its groundwater flow path, up R4's head field to the divide;
   - S_y the specific yield by rock, which Jamie is to source.
   It then writes `q_dry_m3_s` and `tau_days` per spring row. Large chalk or gravel aquifers then run steady while thin hillside springs fail. Until then every spring shrinks by the island's one `base_dry`.
2. **Springs in `fresh_m`.** Springs with dry flow above 0 count as perennial fresh water in `fresh_m`, so the distance to a drink includes them.
3. **Cave springs** (R5 item 10, with Steve's cave sizing), so a spring cave's spring is a row with its flow.
