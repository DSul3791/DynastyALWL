# Springs, seeps and drinking water from the record

Sonny, 8 Nov 2026, for Steve's water-source items (Stage E readers). This page covers three things the island water record (R6) and the stream network (R5) give the game:
- where a player can drink;
- whether a spring still runs in a dry August, and how far its brook runs then;
- which water freezes in winter: seeps and the perched clay table freeze, springs do not.

Nothing here is placed by chance or painted. Every answer is read from fields the record already holds. The three additions it needs are listed at the end.

## Fields to read

All files are under `<world>/record/`. Every point in `network.json` is `[x, y, z]` in world metres, y up, which is the convention of Steve's reader (`water_record.gd`).

| what | where | how to read it |
|---|---|---|
| water class | tile raster `water_class` (u1, 8 m, record codes; the reader maps them to the table's ids) | 2 lake: fresh water. 4 to 7 (marsh, swamp, fen, bog): wet ground with water among plants. 1 ocean and 10 salt marsh: salt. 3 river and 8 seasonal channel mark only rivers wider than about 8 m, once R6 item 3 carves them. Nothing writes 3, 8 or 9 (seasonal pond) yet; the manifest lists them under `missing`. A brook narrower than a cell is never a class: it is a reach polyline. |
| regime | `regime` (u1) | 1 perennial: runs all year, August too. 2 intermittent: dry in the dry season. 3 ephemeral: only during and just after rain. It comes from the 16 m network cell, so it marks a strip 16 m wide round a brook; the polyline says where the water is. |
| flow | `discharge` (u2, log-coded mean m³/s) | By the manifest's `fields` row: 10^(code / `codes_per_decade` − 4); 0 is no flow. The reader's `decode` does this. |
| water table | `table_depth` (u1, 0.25 m steps) | R4's regional table, a yearly mean. 0 means the table is at the ground: a seep or wet ground. 255 means 63.75 m or deeper. The reader takes the shallower of this and the soil's perched winter table (Jamie's wetness classes, #657). |
| nearest water | `fresh_m` (u2, m) | Distance to a lake or to regime 1 water, and with the spring store (addition 2) to a spring that still runs in the dry season. |
| springs | `network.json` `springs` | One row per spring: `pos`, `m3_s` (mean flow), `rock` and `feeds_reach`, and with the spring store `q_base_dry_m3_s`, `tau_days`, `karst_share` and `stores` ([spring_store_build_plan.md](spring_store_build_plan.md) section 4). The reader's `springs_in(rect)` finds them. |
| brooks | `network.json` `reaches` | Each reach's `polyline` rows follow `point_fields`: x, bed y, z, bankfull width and depth, then `q_mean_m3_s`, `q_wet_m3_s`, `q_dry_m3_s` and `q_base_dry_m3_s`, all after bed losses. `down` is the next reach the water enters (−1 for none). |
| season shares | `manifest.json` `summary.seasons` | R5's island shares of the mean flow by season. `base_dry` is the dry quarter's baseflow over the year's mean. |
| climate | `climate.json` | `by_island.<island id>`, else `default` (the reader's `climate(island)`): `sea_level_mean_c`, `seasonal_swing_c`, `daily_range_c`, `lapse_c_per_km`. |

## Where a player can drink

The game's drink already asks `water_near` within `thirst.reach_m` (3 m). With the record it says yes when any of these holds within reach:
- **A spring row** within reach of its `pos`. Clean all year while its dry flow is above 0. Even 0.01 L/s fills a 300 ml mouthful in half a minute.
- **A brook**: within reach of a reach's polyline plus half its bankfull width. A regime 1 reach is a drink in any season. A regime 2 or 3 reach is a drink only in the wet season or right after rain; Steve's season clock decides.
- **A lake cell** (class 2) in any season, and a wide river cell (class 3) once R6 item 3 writes them.
- **Wet ground** (`table_depth` 0, or classes 4 to 7). There is no open water here, but a scrape dug with a tool fills in a few minutes. Peat water (bog, 7) is brown but drinkable.

Water quality is Steve's call for the sickness table. The physical order, cleanest first, is: spring, flowing river, lake, then still marsh, swamp and seasonal pond water. The still water is warm in summer and holds whatever the animals left.

## A dry August

**The spring itself.** A spring's August flow is its row's `q_base_dry_m3_s` once the spring store is in (addition 1); before that it is `m3_s` × `summary.seasons.base_dry`. The brook below can still read regime 2 when the spring does not stop. R4 calls a reach perennial only when its dry baseflow reaches 1 L/s (`perennial_baseflow_m3_s`), so a 0.6 L/s trickle at the spring is a dry-season drink while its brook dries below.

**How far its brook runs.** Walk the spring's `feeds_reach` polyline downstream, then on through each `down`. In a rain-free August the water ends at the first row whose `q_base_dry_m3_s` reaches 0, where the bed losses (above the table, on gravel or karst) have taken it. Don't use `q_dry_m3_s` for this: it is the dry quarter's mean, with that quarter's average rain in it, so it shows more water than a drought leaves.

## Winter: what freezes

**Springs do not freeze.** Groundwater stays near the year's mean air temperature, usually 1 to 2 °C above it (Anderson 2005, *Ground Water* 43:951). So a spring comes out at about `sea_level_mean_c` − `lapse_c_per_km` × its height in km + 1 °C.

**How far below a spring the brook stays open.** On a frosty night the brook cools toward the air along its length. It reaches 0 °C at

  x₀ = λ ln((T_water − T_air) / (0 − T_air)), with λ = ρ c Q / (h W).

Here Q is the flow (m³/s), W the width (m), ρc is 4.19 MJ/m³K for water, and h is about 20 W/m²K for open water to cold night air (judged; wind raises it). Ice forms from x₀ on, by the #616 rim-ice rule.

**Seeps freeze.** A seep spreads its slow flow thin over a wide face, so λ is a metre or two. On a frosty night it turns to an ice sheet on the slope, slippery underfoot. Puddles on the perched clay table freeze by Kathleen's #614 rule (0.1 m by the ice rule).

**Frozen ground for weeks** only where the coldest month's mean, `sea_level_mean_c` − `seasonal_swing_c` − lapse × height, is below 0. On the starter island (9 °C, swing 5, 6.5 °C/km) that is above about 615 m. Below it, the ground freezes only a few centimetres on frosty nights: the daily wave fades about 0.12 m into moist soil. Thin ice is gone by early afternoon (#616).

## Worked example: the spring at cave 3,4#8002 (illustrative until the R4 and R5 runs)

This is a spring at the cave mouth, 56520 / 72360, at 533 m. Say R4 gives it 2 L/s (`m3_s` 0.002) and its brook is 0.5 m wide. The numbers are illustrative; the run replaces them.

- **Temperature.** The year's mean air there is 9 − 6.5 × 0.533 = 5.5 °C, the same as Jamie's cave air. So the spring water is about 6.5 °C, all year.
- **Drink.** Any time of year, within 3 m of the spring row.
- **August.** With `base_dry` 0.3, the spring gives 0.6 L/s: still a drink. Its brook is intermittent (under 1 L/s) and dries where its `q_base_dry_m3_s` reaches 0.
- **A −4 °C night in January.**
  - λ = 4.19e6 × 0.002 / (20 × 0.5) = 838 m.
  - x₀ = 838 × ln(10.5 / 4) = about 810 m.
  - So the brook runs open for about 800 m below the spring, then grows rim ice.
  - A seep on the slope beside it is an ice sheet by midnight.
- **The ground there.** At 533 m the coldest month averages 9 − 5 − 3.5 = 0.5 °C, so there is no frozen ground for weeks. Clay ground near the cave is wet at the surface all winter (class IV to V) and crusts with frost only on cold nights.

## Additions it needs (Sonny, after ws580g; record field list unchanged)

The build plan for additions 1 and 2, with the method, the specific yields and the checks, is [spring_store_build_plan.md](spring_store_build_plan.md).

1. **Per-spring dry flow.** R5 gives each spring its own store, with response time τ = 4 S_y L² / (π² T) (Rorabaugh 1960):
   - T from R4's transmissivity at the spring;
   - L the length of its groundwater flow path, up R4's head field to the divide;
   - S_y the specific yield by rock, from Jamie's table (#686): for example 0.002 for fresh granite, 0.01 for chalk, 0.08 for sandstone and 0.22 for sand and gravel. Lab values for hard limestone (14 to 18%) do not apply.
   It then writes `q_base_dry_m3_s` and `tau_days` per spring row. Large chalk or gravel aquifers then run steady while thin hillside springs fail. Until then every spring shrinks by the island's one `base_dry`.
2. **Springs in `fresh_m`.** Springs with dry flow above 0 count as perennial fresh water in `fresh_m`, so the distance to a drink includes them.
3. **Cave springs** (R5 item 10, with Steve's cave sizing), so a spring cave's spring is a row with its flow.
