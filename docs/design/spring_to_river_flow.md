# Spring to river: how the springs feed a reach month by month

Sonny, 8 Nov 2026. This design says how R5 (the stream network) turns each spring's own stores into the flow a river reach carries in every twelfth of the year, in a drought and after a storm, and what the game reads. It builds on:
- the spring store (#726) and its monthly flows (#732);
- the R7 plan (`docs/design/r7_plan.md`, #728), section 4.1.

The stores come from Jamie's `docs/knowledge/groundwater-layers-recession.md` (#713, not yet on main) and [specific-yield.md](../knowledge/specific-yield.md) (#686). The water budget is A5 in [watershed_rebuild_design.md](../water/watershed_rebuild_design.md).

This is docs only. The code is a short R5 step above #732, and every run is on Dave's PC.

## 1. What a reach carries

A reach's flow in a twelfth m of the year is everything that enters upstream of it, less what its beds and lakes lose on the way:

  Q_reach(m) = Σ upstream cells [ quick(cell) × quick_share(cell, m) + gw(cell) × gw_share(cell, m) ] − losses(m)

The terms:
- **quick(cell)** is the cell's quick runoff from the one water budget, (rain − ET) × (1 − BFI).
- **quick_share(cell, m)** is the cell's water left over in twelfth m, over its year's mean. This is the same seasonal model `network.seasons` uses today, cut into twelve instead of two quarters:
  - rain follows 1 + 0.33 cos 2π(phase − 0.8);
  - evaporation follows 1 + 0.9 cos 2π(phase − 0.375);
  - the leftover water is never below 0.
- **gw(cell)** is R4's groundwater coming out at the cell (springs and seeps alike).
- **gw_share(cell, m)** = Σ stores share_k × month_means(τ_k)[m]: each store's response to the island's recharge shape, from `springstore.month_means`. It is read between 48 τ bins, as the quarter shares are.
- **losses(m)** are the bed losses where a bed sits well above the table (at the streambed's conductivity, scaled by the month's wetted width) and a full lake's evaporation in that twelfth.

So a reach's dry-month flow is the sum of its own springs' dry months, not one island share. A reach fed by a karst spring and granite seeps falls in a dry spell differently from one fed by a gravel terrace. That follows from the stores, with no rule per reach.

**Twelfths, not calendar months.** Twelfth 1 runs from phase 0 to 1/12 of the climate year. That is the same phase `record.climate.warmest_year_phase` (0.375) counts from. The game's season clock maps phase to its calendar.

## 2. What R5 adds (the code step above #732)

1. **Twelve routed passes.**
   - For each twelfth, R5 builds the sources above and routes them with that twelfth's losses (`_flow`, as for mean, wet and dry today).
   - It routes them a second time with the groundwater alone, for the base flow.
   - Each pass is one walk of the routing tree, as long as today's mean pass, so the step adds 24 walks.
2. **Per reach in `network.json`:**
   - `q_month_m3_s`: the 12 flows at the reach's lowest point, after losses;
   - `q_base_month_m3_s`: the groundwater part alone, after losses;
   - `base_stores`: the groundwater from upstream grouped into τ bands, so the game can run a drought or a storm at any reach. There are 2 bands per decade, from 0.1 days to 100 years, and only bands that carry water are written. Each row is [τ_days, q_mean_m3_s, 12 monthly flows] before losses.
     - The band's τ is its flow-weighted geometric mean.
     - Its monthly flows are summed exactly from each cell's own stores.
3. **Along a reach**, the polyline rows keep their mean flows. A point's flow in twelfth m is its mean × the reach end's `q_month_m3_s`[m] ÷ its `q_mean`. Reaches run between confluences, so the ratio barely changes along one.
4. **Params:** `network.season.store_bands` {per_decade 2, min_days 0.1, max_days 36525}.
5. **The summary reports, without judging:**
   - the reaches whose driest twelfth runs under 1 L/s of base flow while their dry quarter is over it;
   - each rock's share of reach flow from springs in the driest twelfth.

## 3. What the game reads (R7)

- **A normal day.** The live water puts in each crossing reach's `q_month_m3_s` for the date, read between twelfths. Springs inside the window put in their own `q_month_m3_s` (#732).
- **A drought.** From the spell's start day d0, a reach's base flow is:

    Q_base(t) = r_loss × Σ bands q_band(d0) × exp(−t / τ_band)

  - The bands' flows at d0 are read between their twelfths.
  - r_loss = `q_base_month` ÷ (Σ bands, before losses) at d0. That keeps the losses' share of the flow at its start value, which slightly overstates a losing reach late in a long drought.
  - Quick runoff is 0 until it rains again.
- **A storm.** Each band adds `storm_pulse(q_mean_band, 1, τ_band, storm recharge, recharge, t)` (#732). The storm's recharge ÷ the mean daily recharge is the storm's rain × 365.25 ÷ the year's rain, because the recharge share cancels.
  - Travel down a brook takes minutes to hours against pulses of days, so the pulses add at the reach with no extra delay.
  - The storm's quick runoff is not in the record. It is the live water's rain falling on the ground.

## 4. Worked example on the starter island

**The numbers are illustrative until the ws580i run.** The rock under the brook, the areas and the split of the granite water between seeps and rock springs are assumed. ws580i's R5 replaces them with the run's catchments. Every number below follows from the stated inputs by the formulas above (our sums).

**The brook.** It runs from the spring at cave 3,4#8002 (56520, 72360, 533 m) down 1.5 km² of granite.

**Inputs:**
- **Rain** is 1,700 mm a year, the upland rain the water budget note quotes. PET is 483 mm (MORECS) and Fu's ω is 2.6. That gives ET 458 mm and runoff 1,242 mm, a runoff ratio of 0.73.
- **The karst spring** has a mean of 2.0 L/s, as in the springs page example. Its stores:
  - the conduits take 0.55, with τ 5 days;
  - the matrix takes 0.45, with τ 253 days (S_y 0.003, L 300 m, K 1e-7 m/s over 50 m).
- **The granite** has BFI 0.40, so its recharge is 497 mm a year and its quick runoff 745 mm a year. Half the recharge comes out in rock springs and half in seeps (judged; the run's catchments decide). Both use T 0.715 m²/day and S_y 0.02, the hillside table in zone 1:
  - the rock springs have L 200 m, so τ is 453 days;
  - the seeps, at the foot of drift, have L 50 m, so τ is 28 days.
- **Mean flows:** the rock springs give 11.8 L/s, the seeps 11.8 L/s and the quick runoff 35.4 L/s.
- **Losses:** there are no losing beds, because the granite table is near the ground.

**The year, twelfth by twelfth (L/s at the brook's foot):**

| twelfth | phase | conduits | matrix | rock springs | seeps | quick | total | from springs |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.00–0.08 | 1.37 | 1.05 | 12.93 | 17.00 | 42.07 | 74.4 | 32.4 |
| 2 | 0.08–0.17 | 0.95 | 1.03 | 12.85 | 13.25 | 28.21 | 56.3 | 28.1 |
| 3 | 0.17–0.25 | 0.56 | 0.98 | 12.49 | 9.11 | 16.27 | 39.4 | 23.1 |
| 4 | 0.25–0.33 | 0.32 | 0.90 | 11.94 | 5.69 | 9.46 | 28.3 | 18.9 |
| 5 | 0.33–0.42 | 0.29 | 0.83 | 11.36 | 3.91 | 9.61 | 26.0 | 16.4 |
| 6 | 0.42–0.50 | 0.47 | 0.77 | 10.90 | 4.24 | 16.66 | 33.0 | 16.4 |
| 7 | 0.50–0.58 | 0.83 | 0.75 | 10.68 | 6.60 | 28.74 | 47.6 | 18.9 |
| 8 | 0.58–0.67 | 1.25 | 0.77 | 10.76 | 10.35 | 42.61 | 65.7 | 23.1 |
| 9 | 0.67–0.75 | 1.64 | 0.82 | 11.12 | 14.50 | 54.54 | 82.6 | 28.1 |
| 10 | 0.75–0.83 | 1.88 | 0.90 | 11.66 | 17.91 | 61.35 | 93.7 | 32.4 |
| 11 | 0.83–0.92 | 1.91 | 0.97 | 12.24 | 19.70 | 61.21 | 96.0 | 34.8 |
| 12 | 0.92–1.00 | 1.73 | 1.03 | 12.71 | 19.36 | 54.15 | 89.0 | 34.8 |

**The three months the game needs.**

| case | the brook carries | from its springs | how the springs split |
|---|---|---|---|
| **normal** (the year's mean) | 61.0 L/s | 25.6 L/s (42%) | rock springs 11.8, seeps 11.8, karst spring 2.0 |
| **dry** (twelfth 5, at the warmest phase 0.375) | 26.0 L/s | 16.4 L/s (63%) | rock springs 11.4, seeps 3.9, karst 1.1 (matrix 0.83, conduits 0.29); quick runoff 9.6 |
| **dry, after a 30-day rain-free spell** from the start of twelfth 5 | 12.7 L/s (quick runoff 0) | 12.7 L/s | rock springs 10.6, seeps 1.4, matrix 0.73, conduits 0.00; 14.7 on day 10, 11.1 on day 60 |
| **storm** (twelfth 11, the wettest, 96.0 L/s, springs 34.8) with 30 mm of rain | 96.0 L/s plus the storm's runoff | springs +4.3 L/s at once, +2.6 a week later, +1.9 after two weeks | seeps +2.7, conduits +1.4, rock springs +0.17, matrix +0.02 on the storm day |

How to read them:
- **The dry month** is the warmest twelfth, not the rainiest's opposite. Evaporation peaks at 0.375 and the rain's low comes at 0.3.
- **The seeps lag the rain by about a month**, and their low is in twelfths 5 and 6. The rock springs barely move all year (10.7 to 12.9 L/s), so the brook is perennial with room to spare: its driest twelfth's base flow is 16 times R4's 1 L/s.
- **In a 30-day drought the brook keeps 78% of its spring flow.** The seeps fall to a third, the conduits are gone in two weeks, and the rock springs and the matrix hold. That is #713's honest line: a granite hillside's seep fails in a dry summer and its rock spring trickles on.
- **The karst spring alone.** In twelfth 11 it runs 2.9 L/s. A 30 mm storm takes it to 4.3 L/s at once and 3.2 a week later, under twice its flow, as the R7 plan's line needs. Its dry twelfth is 1.1 L/s, and after 30 dry days 0.73, all matrix.
- **The storm's quick runoff** is 30 mm × 0.73 × 0.6 = 13.1 mm off 1.5 km², or 19,700 m³. That is about 230 L/s averaged over the storm day, on top of the 96. The live water draws it from the rain; the record holds only the springs' share.

## 5. Checks before success (on ws580i and the run after it)

1. **Months keep the mean.** On a reach with no losses, the twelve `q_month_m3_s` average its `q_mean_m3_s` to rounding.
   - With losses, the monthly losses scale with width, which is not linear in flow, so the months' mean may differ a little. The summary reports the largest difference. Over 2% means the losses need a second look.
2. **Months agree with the quarters.** R5's dry quarter is centred on the rain's low at phase 0.3, so it spans twelfths 3 to 5. Those three twelfths average within 5% of the reach's `q_dry_m3_s`. The same holds for the wet quarter, twelfths 9 to 11 around the rain peak at 0.8.
3. **Bands sum to the base flow.** At every reach, Σ `base_stores` monthly flows equals `q_base_month_m3_s` before losses, within 0.5% (the τ bins' interpolation).
4. **Reported** (the run decides the numbers):
   - each rock's base flow index read off its reaches (the springs' share of the year's flow), beside #713's column: about 0.4 on granite, 0.9 or more on chalk, 0.2 to 0.3 on shale;
   - each rock's springs' share in the driest twelfth, which should sit above its year's share (the brook: 63% against 42%);
   - the reaches that read perennial on the dry quarter but fall under 1 L/s in their driest twelfth.
5. **Never-see (#713, read on the reach tables):**
   - a karst-fed reach whose base flow is still more than twice its month's a week after a storm;
   - a granite reach whose seeps and rock springs fall together in a drought;
   - a shale reach with a strong summer base flow;
   - a chalk reach whose base flow rises within hours of a storm;
   - a band with τ in hours or millennia.

## 6. What does not change

- The record's raster fields, `water_class` and TERRAIN_VERSION stay as they are. The `regime` raster keeps R5's dry-quarter rule; whether to move to the driest twelfth is a later call, made with the run's count in hand.
- The mean, wet, dry and `q_base_dry` flows, and `network.json`'s existing keys, stay as they are. Reaches only gain keys.
- The live water stays the truth at runtime: a dug ditch still changes where water goes, and the record is where it starts.
