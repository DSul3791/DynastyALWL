# Each spring's own store, and springs in fresh_m: build plan

Sonny, 8 Nov 2026. This builds additions 1 and 2 of `springs_and_drinking_water.md`. The code is drafted in `tools/watershed/springstore.py`, with short steps in R4 (`groundwater.py`), R5 (`network.py`) and R6 (`record.py`), on the spring store branch stacked on R5. Every run and test is on Dave's PC or David4.

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
- **S_y** is the specific yield at the water table: that of the layer R4's head sits in (loose cover, or one of the near-surface zones of section 7), averaged over the catchment's blocks. The table rises and falls there, so the column's mean would overstate the store (Jamie's #713).

R4 writes each store's share and τ (`gw_diffuse_share` and `gw_diffuse_tau_days`, the same for `conduit` and `matrix`, section 7), with `gw_sy`, `gw_flow_path_m` and `gw_catchment_m2`, at the 16 m cells where it puts the groundwater out, the same cells as `gw_discharge_m3_s`, with NaN elsewhere. Its manifest summary (`stores`) gives the diffuse store's τ quartiles by rock.

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
- `stores`: one row per store with a share, [store, share of the recharge, τ in days, its dry flow in m³/s];
- `q_base_dry_m3_s`: the stores' dry flows added, each `m3_s` × share × `base_dry(τ)`, the dry quarter's mean;
- `tau_days`: the τ of the store that gives most of the dry flow (the matrix on karst);
- `karst_share`;
- `sy`, `flow_path_m` (L) and `catchment_km2` of the diffuse store.

**In a drought** the game runs the stores on: from the start of a rain-free spell, each store's dry flow falls as exp(−t / its τ), and the spring gives their sum. With one store that is q_base_dry × exp(−t / τ), and a reader that keeps one store uses `tau_days`. A karst spring's conduit flow is gone in a week or two and its matrix then holds it for months, while a gravel terrace spring hardly changes in a month. Steve's reader keeps the spell's start day.

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

## 7. R4's transmissivity: the near-surface layer and karst's two stores

At a fixed L of 500 m, R4's present T (Gleeson's permeability over a uniform 50 m, conduits ×100 in cave-forming rock) gives karst a τ of 2 hours and shale about 2,700 years. Jamie's #713 (`docs/knowledge/groundwater-layers-recession.md`) shows three causes: the flow path, the layer and the store. The fixes are physical, in R4, and no clamp is put on τ.

**The flow path comes from R4's catchments, never a fixed distance.** Hard rock has perennial streams 200 to 250 m apart. Chalk and karst take the water underground and have few streams, so their groundwater catchments run for kilometres. Section 1 already reads L from R4's own head field, so a karst or chalk spring gets its kilometres. The fixed 500 m was the misleading part.

**(a) The near-surface layer on tight rock** (granite, slate, old basalt, shale and coal measures). R4 replaces the uniform 50 m under these rocks with the zones the surveys measured:

| layer | thickness | K (m/day) | S_y | source (#713) |
|---|---|---|---|---|
| soil, head and thin till | 1 m (0.5 to 2) | 0.3 (0.1 to 1) | 0.05 | judged |
| zone 1, the broken, weathered top of the rock | 2 m (1 to 3) | 0.1 | 0.02 | GSI 2015; BGS OR/15/028 |
| zone 2, shallow fractures | to 15 m | 0.01 | 0.005 | K: GSI; depth and S_y judged |
| zone 3, deeper fractures | to 100 m | 0.001 | 0.002 | GSI; BGS |

- **T is about 0.7 m²/day.** That matches the Dalradian specific capacity, 0.8 m³/day per metre.
- **Sandstone keeps its own K.** The check is Torridonian's median T, 16 m²/day. Chalk, karst and loose cover are not changed by (a).
- **S_y at the table** (section 1): a hillside table in zone 1 uses 0.02.
- **Shale.** The zones are its whole store, because the rock below adds about 0.001 m²/day against their 0.7. This follows from the sums with no special case.
- **Seeps and springs.** Where the zones cannot carry the recharge down the hillside, R4's head reaches the ground and the water comes out near where it fell. Those discharge cells have short catchments and a τ of weeks: the seep at the foot of the drift that fails in August. The rock springs lower down have flow paths of about 200 m and a τ of 1.5 to 2 years, as the Cairngorm plateau springs' 2-year water shows (Soulsby et al. 1999).

**(b) Karst as two stores in parallel.** In R4's karst cells, each discharge cell's recharge splits in two.
- **The conduits** take 0.55 of it: that is 1 − i, with Mangin's i at 0.20 to 0.65 (Olarinoye et al. 2022), and the middle is judged. Their τ is 5 days (2 to 10, from the 3 or 4 days of storm flow, judged), with S_y under 0.001. Conduit flow is pipe flow, not Darcy flow, so this τ is the measured one, not Rorabaugh's.
- **The matrix** takes the other 0.45. Its τ is Rorabaugh's, with:
  - S_y 0.003 (ORNL 1994, #686);
  - L the distance to the nearest conduit, judged at 300 m;
  - T from the matrix's own K over 50 m (R4's thickness, judged). R4 does not hold that K, because its ×100 factor is the conduits. Jamie's value is 1e-7 m/s (0.009 m/day), judged inside the sourced Floridan range of 1.9e-8 to 3e-5 m/s (#713). The matrix τ is then about 250 days.
  The checks are Mangin's regulation capacity, under 0.5 years for typical karst, and Fiorillo et al. (2012), 150 days to 7 years in large massifs.
- **The cell's season shares** are the two stores' shares added. A karst spring then floods within a day of a storm and falls back within a week. After that it tails off for months, and its dry-season flow is nearly all matrix.

**Check 1** (section 6) reads τ against #713's table (c) by rock. Only the karst rows are measured, so the other rows are reported, not failed. #713's never-see list joins #686's:
- a karst spring still in flood a week after a storm, or dry in a normal summer;
- a granite or slate hillside where the rock spring and the soil seep fail together in August;
- a shale valley with a strong summer base flow;
- a chalk stream that rises within hours of a storm;
- a τ of hours or of millennia for any spring.

The base flow index is not a separate check here, because R4's recharge split already uses it (`water_budget.bfi_by_rock`).

**Still asked of Jamie:** stream density on chalk and karst.

## 8. Test plan (unit tests; nothing run in the cloud)

The pure functions go in a new module, `tools/watershed/springstore.py`, which R4, R5 and R6 call. Its unit tests are in `tools/watershed/test_springstore.py`. They need numpy and scipy only, use small synthetic arrays and the repo's `params.json`, and read no run files. David4 or Dave's PC runs them, as for `test_network.py` and `test_peaks.py`.

| test | checks | fixture |
|---|---|---|
| `test_tight_rock_transmissivity` | One granite cell with no cover has T = soil 1 m × 0.3 + zone 1 2 m × 0.1 + zone 2 13 m × 0.01 + zone 3 85 m × 0.001 = 0.715 m²/day. Under 3 m of coarse cover the soil zone is gone and the cover's K × 3 m is added. Sandstone, chalk, limestone and loose sediment are not in the tight-rock mask, so they keep Gleeson's K × (50 m − cover). | `params.json` `groundwater`; three cells and a rock list |
| `test_sy_at_the_table` | On tight rock, S_y at a table depth of 0.5, 2, 10, 50 and 150 m is the soil's, then zones 1, 2 and 3, and zone 3 below the stack. Under 3 m of coarse cover a table at 1 m reads 0.22. On sandstone it is the cover's, then the rock's #686 value. | the same cells, five depths |
| `test_sy_by_rock_id` | Every rock in `groundwater.rock_class` has a specific yield; an unlisted rock stops the run. | `params.json` |
| `test_catchments_on_a_plane` | H falls east on a 6 × 6 block grid, and the east column discharges. Each block ends at the east block of its row, at a distance of (columns to go) × the block size + half a block. | synthetic H |
| `test_catchments_on_a_mound` | H peaks in the middle and every edge block discharges. Every block ends at an edge, none is left out, and each block's end is downhill of it. | synthetic H |
| `test_rorabaugh_strip` | On a strip of uniform T and S_y, τ = 4 S_y L² / (π² T), with L twice the mean distance. Two halves of T₁ and T₂ in series give the harmonic mean. | one row of blocks |
| `test_karst_two_stores` | An all-karst catchment has shares of 0.55 (conduit, 5 days) and 0.45 (matrix, Rorabaugh with S_y 0.003, L 300 m and the matrix T), and no diffuse store. A catchment with half its recharge on karst has shares 0.5, 0.275 and 0.225. | synthetic catchments with a karst mask |
| `test_store_response_limits` | The response keeps the year's mean at 1 for every τ, so mean flows cannot change (section 6, check 3). τ near 0 returns the recharge shape's quarter means. τ of 100 years gives wet and dry within 0.5% of 1. τ of 45 days, the old island store (`network.seasons` now calls the same function for it), matches the response worked by hand for a cosine. | a cosine recharge shape, 24 samples |
| `test_bins_interpolate` | The shares from 48 log-spaced τ bins are within 0.005 of the exact response at 200 random τ between 0.1 days and 100 years. The shares are over the year's mean flow, so that is 0.5% of the mean flow; linear in log τ between bins 1.31 apart, the error stays under about 0.003. | random τ, fixed seed |
| `test_cell_shares_and_spring_row` | A cell's dry share is its stores' shares times their own dry shares, added. A karst spring row lists the conduit and the matrix, takes the matrix's τ as `tau_days`, and sums their dry flows. | three synthetic cells |
| `test_drought_recession` | q(t) = q_base_dry × exp(−t/τ) falls to 1/e after τ days and is never negative. | scalars |
| `test_params_give_713_times` | The params give #713's table (c): tight rock at L 50 m within 2 weeks to 3 months and at L 200 m within 6 months to 2 years; a karst matrix within 3 months to 2 years; a conduit at 2 to 10 days. Nothing reads hours or millennia. | `params.json` only |
| `test_fresh_spring_sources` | Two spring rows: one with `q_base_dry_m3_s` 2e-5 marks its nearest 8 m sample as fresh water; one with 5e-6 marks nothing; one outside the window is ignored. | a 20 × 20 sample grid |

What the tests do not cover, for the run on Dave's PC to judge (section 6):
- the island's dry share against the old 45-day store;
- the kilometres of perennial stream;
- the springs that change regime;
- the never-see lists on real ground.

## Cost and what does not change

R4 gains one D8 pass on the 64 m grid. R5 gains 48 small FFTs. Each takes seconds.

These do not change: the mean water budget, the record's raster field list, `water_class` and TERRAIN_VERSION. `network.json` spring rows only gain keys.
