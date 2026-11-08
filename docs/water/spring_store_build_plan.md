# Each spring's own store, and springs in fresh_m: build plan

Sonny, 8 Nov 2026. This builds additions 1 and 2 of `springs_and_drinking_water.md`. It is docs only for now. The code is a short step in R4 (`groundwater.py`), R5 (`network.py`) and R6 (`record.py`) once the ws580g pictures are in, and every run is on Dave's PC.

## Why

Today every spring and every groundwater-fed reach shrinks by one island-wide share in the dry season. That share comes from one linear store with a judged response time of 45 days (`network.season.baseflow_recession_days`). Real springs differ by their rock:
- a karst spring rises and falls within days;
- chalk, sandstone and gravel springs run steadily through the summer;
- a small spring on a thin hillside store fails in August.

Jamie's never-see list (#686) asks for exactly that difference. Each spring therefore gets its own store, sized from the ground it drains.

## 1. The response time (R4)

Rorabaugh (1960) solved the recession of a strip aquifer that is drained by a stream at one edge and closed by a divide at the other. After a short while only its slowest term is left, with time constant

  τ = 4 S_y L² / (π² T),

where L is the distance from the stream to the divide, T the transmissivity and S_y the specific yield.

Each part is read from R4's own solve, so there is one groundwater model:
- **Groundwater catchments.** On the 64 m head field H, each block passes its water to its steepest-descent neighbour in H, the same D8 rule the surface routing uses, until it reaches a block that discharges (`dis` > 0) or a fixed sea or lake block. A discharge block's catchment is every block that ends there.
- **L = 2 × the mean flow distance** of the catchment's blocks to its discharge block. A strip with even recharge has a mean distance of L/2.
- **T** is the harmonic mean of the catchment's block transmissivities along the flow, because flow in series takes the harmonic mean.
- **S_y** is the storage-weighted mean over the saturated thickness. It combines rock and loose cover by thickness, the same way R4 already combines their transmissivities (`T16 = Kc dcov + Krock (b − dcov)`), and storage adds across the catchment.

R4 writes `gw_tau_days`, `gw_sy` and `gw_flow_path_m` at the 16 m cells where it puts the groundwater out, the same cells as `gw_discharge_m3_s`, with NaN elsewhere. Its manifest summary gives the τ quartiles by rock.

## 2. Specific yield by rock (Jamie's #686, the "Use" column)

These go in `params.json` as `groundwater.specific_yield`. Values marked "judged" are flagged there.

| our rock or cover | S_y | from #686 |
|---|---|---|
| limestone and marble where caves form (R4's karst cells) | 0.004 | karst, ORNL 1994 well hydrographs |
| limestone and marble elsewhere | 0.015 | not karst, 0.01 to 0.02 (Morris and Johnson 1967). Never the lab 14 to 18% |
| chalk | 0.01 | MacDonald and Allen 2001, median 0.008 |
| sandstone | 0.08 | 0.05 to 0.15 |
| shale and coal measures | 0.01 | shale and mudstone. Coal measures judged the same |
| granite | 0.002 | fresh granite and gneiss (judged range) |
| slate | 0.002 | judged as fresh crystalline rock (not in #686) |
| basalt | 0.01 | old and dense (judged). 0.08 only where a young flow is marked, and nothing marks one yet |
| tuff | 0.03 | judged (not in #686) |
| fine cover (clay-rich till, R4's "fine unconsolidated") | 0.03 | judged |
| coarse cover (sand and gravel, outwash, R4's "coarse unconsolidated") | 0.22 | 0.15 to 0.30 |

Peat is not in the aquifer. Its water is the soil's perched store (`soils-ground-wetness.md`, #657).

## 3. Season shares per cell (R5)

`seasons()` today filters the island's recharge shape through one linear store to get `base_wet` and `base_dry`. Each discharge cell now uses its own τ instead:
- The filter is one FFT per τ. The cells' τ are binned into 48 bins, log-spaced from 0.1 days to 100 years, and the shares are read between bins.
- The sources become `wet = q_cell × quick_wet + gw × base_wet(τ)` and `dry = q_cell × quick_dry + gw × base_dry(τ)`. The dry baseflow (`base_dry` routed with its losses), the perennial test (1 L/s) and `q_base_dry_m3_s` all follow, so a reach's dry flow is the sum of its own springs' shares.
- A store slower than about a year evens out the seasons, so its dry share tends to 1. A store of a few days follows the recharge, which is near nothing in the dry quarter.
- `network.season.baseflow_recession_days` goes to `proposed_removals/` once the checks below pass. Only Dave's yes deletes it.

## 4. Spring rows (network.json)

Each `springs` row keeps `pos`, `m3_s`, `rock` and `feeds_reach`, and gains:
- `tau_days`;
- `sy`;
- `flow_path_m` (L);
- `catchment_km2`;
- `q_base_dry_m3_s`: `m3_s` × `base_dry(τ)`, the dry quarter's mean.

**In a drought** the game runs the store on: from the start of a rain-free spell, q(t) = q_base_dry × exp(−t / τ). A karst spring then fails in a week or two, while a gravel terrace spring hardly changes in a month. Steve's reader keeps the spell's start day.

## 5. Springs in fresh_m (R6)

`record.py` adds to the fresh-water sources every spring row whose `q_base_dry_m3_s` is at least `record.fresh_spring_min_m3_s`. That is 1e-5 m³/s (0.01 L/s, which fills a 300 ml mouthful in 30 s), a judged value. Each such spring counts at the 8 m sample nearest its `pos`. The `fresh_m` field note becomes "to a lake, regime 1 water or a spring that runs in the dry season".

## 6. Checks before success

1. **τ against measured recession times by aquifer type.** Jamie is to source these. Until she does, the check reports and does not pass or fail.
2. **#686 never-see list:**
   - no granite hillside spring that runs strongly through a dry summer while a gravel terrace spring beside it fails;
   - no karst spring that rises slowly over days after a storm;
   - no chalk with a sand-like S_y.
3. **Mean flows unchanged.** Only the season shares move, so every reach's `q_mean_m3_s` must match the run before to rounding.
4. **Reported:** the island's flow-weighted dry share against the old 45-day store, the kilometres of perennial stream before and after, and the springs that change regime.

## 7. The known risk: R4's transmissivity

At L = 500 m, R4's present T (Gleeson's permeability over a uniform 50 m, conduits ×100 in cave-forming rock) gives:

| rock | T (m²/day) | S_y | τ |
|---|---|---|---|
| karst limestone | 5,140 | 0.004 | 2 hours |
| chalk | 51 | 0.01 | 20 days |
| old basalt | 10 | 0.01 | 99 days |
| sandstone | 10 | 0.08 | 2.2 years |
| fresh granite | 0.26 | 0.002 | 2.2 years |
| shale | 0.001 | 0.01 | about 2,700 years |
| 5 m of outwash on granite | 41 | 0.024 | 59 days |

The karst and shale rows are not real springs. Real hard-rock uplands drain through soil, drift and the fractured top few metres of the rock: #686 says the store sits in that weathered zone, and the Low Flow Studies give such rocks a base flow index of about 0.4, which needs a store of weeks, not millennia. A karst spring has a fast conduit store sitting on a slower matrix store (#686: conduits under 0.001, fractures 0.001, matrix 0.003).

The fix is in R4 and is physical. No clamp is put on τ.
- **(a) A near-surface layer** of soil and fractured rock, with its own thickness, conductivity and S_y. It is added to T and to the store the way the loose cover is. This also gives hard-rock hillsides their seasonal seeps.
- **(b) Karst as two stores in parallel**, conduit and matrix, each with its own share of the recharge and its own τ.

Jamie is asked for:
- the near-surface thickness and conductivity in glaciated hard-rock uplands;
- the conduit and matrix split of karst spring flow;
- measured recession times by aquifer type, for check 1.

The build waits for those numbers. Section 7(a) and (b) then go into this plan before any code.

## Cost and what does not change

R4 gains one D8 pass on the 64 m grid. R5 gains 48 small FFTs. Each takes seconds.

These do not change: the mean water budget, the record's raster field list, `water_class` and TERRAIN_VERSION. `network.json` spring rows only gain keys.
