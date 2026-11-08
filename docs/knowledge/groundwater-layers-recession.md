# Groundwater layers and recession: the near-surface zone, karst's two stores, and how fast springs fall by rock

**Last checked:** 2026-11-08 (Jamie; web research plus our sums). **Owners:**
- Sonny: R4 groundwater (`groundwater.py`), R5 network, and the spring store plan (`docs/water/spring_store_build_plan.md`, on the R6 branch).
- Steve: drinkable springs in the game (reader).

**Related:** `specific-yield.md` (#686, which gives S_y), [upland-streams-numbers.md](upland-streams-numbers.md) (stream density), [soils-ground-wetness.md](soils-ground-wetness.md), [caves.md](caves.md).

This page answers Sonny's three asks for section 7 of his plan:
1. how thick, and how permeable, the near-surface layer is in glaciated hard-rock uplands;
2. how karst spring flow splits between conduit and matrix;
3. measured recession times by aquifer type.

## Lessons (read these first)

1. **In hard rock, almost all the flow is in the broken top of the rock, and permeability falls by ten at each step down.**
   - Geological Survey Ireland: "most of the flow in poorly productive aquifers will be in the broken up portion of the top of the bedrock". This transition zone "can rapidly change in thickness over very short distances and may be absent in places" (GSI, GW3D Transition Zone).
   - The Irish aquifer manual reports a permeability of 0.1 m/day in the uppermost broken, weathered zone (Zone 1), 0.01 m/day in Zone 2 and 0.001 m/day in Zone 3. In its quarry example, the subsoil and transition zone take up the top 1 to 3 m (GSI, *Irish Aquifer Properties*, 2015, Figures 7 and 9).
   - **Scotland** (BGS OR/15/028):
     - Highland metamorphic rock: "fractures are generally more common at depths of up to approximately 100 m". Weathering raises permeability only in "the uppermost few metres". Intergranular porosity is under 1%.
     - Granite and other intrusive rock: weathered zones "are rarely more than few metres thick". Only in parts of Aberdeenshire and the Cairngorms does weathering reach tens of metres, and in north-east Scotland it "commonly extends to between 10 and 20 m".
     - Often "a single fracture, or at most three or four fractures" give all of a borehole's water. Each fracture gives up to about 0.3 L/s.
     - Dalradian median specific capacity is 0.8 m³/day per metre. Torridonian sandstone median transmissivity is 16 m²/day.
   - **Superficial deposits:** glaciofluvial gravels "can be very thick and highly permeable", and the thickest reach over 80 m (BGS).

2. **High plateau springs on hard rock hold water for about two years.**
   - Springs on the Cairngorm plateaux above 800 m are fed by "groundwater flow in shallow drift deposits and fractured bedrock". Their water's mean residence time is "around 2 years". Lower down, deeper drift and larger catchments raise it to over 5 years (Soulsby et al. 1999, *HESS* 3, 409).
   - The water's age is not the same as the speed of the flow's response. A pressure pulse moves faster than the water does. But it does rule out both "2 hours" and "2,700 years".

3. **Karst springs have a quick conduit part that lasts days, and a slow matrix part that lasts months to years.**
   - Recession is split into a quick (conduit) part and a slow (matrix) part, and Mangin's two-reservoir model is fitted to each (Olarinoye, Gleeson and Hartmann 2022, *HESS* 26, 5431).
     - Brutsaert's method drops the first 3 or 4 days after a storm as storm flow. That is roughly how long the conduit flush lasts.
     - Mangin's "regulation capacity" K (years of slow-store output held in storage) is under 0.1 year at Saivu (Switzerland), 0.25 to 0.80 years at Lehnbachquellen (Austria), and up to 0.45 years in winter at Qachquoch (Lebanon). A typical karst system has K under 0.5.
     - The infiltration delay i (how much of the recharge is slowed) was 0.20 to 0.65 at all three springs.
   - **Big karst massif springs in a dry summer** (Picentini Mountains, Italy, 2000 to 2009): one recession coefficient a year, from 0.0004 to 0.0065 per day (Fiorillo, Revellino and Ventafridda 2012, *J. Cave and Karst Studies* 74(2)). That is a time constant of 150 days to 7 years. These are very large springs; Caposele is one of Italy's biggest.
   - Kovács et al. 2005 work examples with 0.005 and 0.05 per day for the base recession. They note "the equivalent storage of the conduits is much smaller than the storativity of the matrix".
   - `specific-yield.md` (#686): S_y under 0.001 for conduits, 0.001 for fractures and 0.003 for the matrix (ORNL 1994).

4. **The flow path L matters as much as the rock, and permeable rock has few streams.**
   - Rorabaugh's τ goes with L². On hard rock, perennial streams run at about 2 to 2.5 km per km² ([upland-streams-numbers.md](upland-streams-numbers.md)). A strip between streams then has L = 1 ÷ (2 × density), about 200 to 250 m.
   - On chalk and karst, water sinks instead of running off, and there are few streams. L is kilometres, not hundreds of metres (judged; we have no sourced density for permeable rock yet).
   - So a karst τ of 2 hours at L = 500 m is mostly a wrong L, as well as a missing matrix.

## Judged numbers for Sonny (R4 section 7)

### (a) The near-surface layer on hard rock

| Layer | Thickness | K (m/day) | S_y | Source |
|---|---|---|---|---|
| Soil, head and thin till on slopes | 0.5 to 2 m | 0.1 to 1 | 0.03 to 0.10 | judged. `soils-ground-wetness.md` has infiltration by soil |
| Zone 1: the broken, weathered top of the rock | 1 to 3 m | 0.1 | 0.02 | K: GSI. Thickness: GSI quarry example and BGS "rarely more than few metres". S_y: #686 weathered mantle |
| Zone 2: shallow fractured rock | down to about 15 m (judged) | 0.01 | 0.005 (judged) | K: GSI |
| Zone 3: deeper fractured rock | to about 100 m | 0.001 | 0.002 | K: GSI. Depth: BGS |
| North-east Scotland and Cairngorm granite regolith | 10 to 20 m, and up to 50 m | 0.1 (judged, as Zone 1) | 0.02 | BGS |

- **Transmissivity, our sums:** soil 1 m × 0.3, plus Zone 1 at 2 m × 0.1, plus Zone 2 at 12 m × 0.01, plus Zone 3 at 85 m × 0.001, comes to about 0.7 m²/day.
  - That agrees in size with the Dalradian specific capacity of 0.8 m³/day per metre. Transmissivity is roughly 1 to 1.5 times specific capacity (a judged rule of thumb).
  - Torridonian sandstone, at a median of 16 m²/day, is twenty times more transmissive.
- **The S_y that counts** in τ is the one where the water table moves. On a hillside that is Zone 1 or the soil, 0.02 to 0.05, not the bulk of the column.

### Our sums: τ = 4 S_y L² ÷ (π² T)

| Store | S_y | T (m²/day) | L 50 m | L 100 m | L 200 m | L 500 m |
|---|---|---|---|---|---|---|
| Hard rock, all zones (above) | 0.02 | 0.5 to 0.7 | 30 to 40 days | 4 to 5 months | 1.5 to 2 years | 8 to 11 years |
| Dalradian-like (T 1) | 0.01 | 1 | 10 days | 40 days | 5 months | 3 years |
| Torridonian-like sandstone (T 16) | 0.02 | 16 | 1 day | 5 days | 20 days | 4 months |
| 5 m of outwash, K 10 | 0.15 | 50 | 3 days | 12 days | 7 weeks | 10 months |

- **On a hard-rock hillside** with L about 200 m, the store takes 1.5 to 2 years. That fits the 2 years of the Cairngorm springs.
- **The quick part** of hard-rock base flow is the soil and head on top, with τ of days to a few weeks (judged). A base flow index of about 0.4 is then a soil store that dries by August, plus a slow rock store that gives a small, steady trickle all summer.
- **What that means in the game:**
  - a granite hillside spring does run all summer, but weakly;
  - a spring that fails in August is a soil or head spring, a seep at the foot of drift, not a rock spring.
  - That is the honest version of the #686 never-see line.

### (b) Karst as two stores in parallel

| Store | Share of recharge | τ | S_y | Source |
|---|---|---|---|---|
| Conduits (quick) | 35 to 80% | 2 to 10 days | under 0.001 | Share: 1 − i, with i 0.20 to 0.65 (Olarinoye 2022). τ: the 3 to 4 days of storm flow, judged to 2 to 10 |
| Matrix and fissures (slow) | 20 to 65% | 3 months to 2 years in a normal massif; up to 7 years in the very largest | 0.003 to 0.004 | τ: Mangin K under 0.5 years for typical karst; Fiorillo 150 days to 7 years. S_y: ORNL |

- The conduits hold little water, so they cannot carry a dry summer. The dry-season flow of a karst spring is nearly all matrix.
- A karst spring therefore rises within hours to a day after a storm and falls back within a week. Then it tails off slowly for months.
- **L for the matrix store:** the distance to the conduit, not to the spring. Conduits drain the matrix every few hundred metres (judged).

### (c) Recession times by aquifer type (for check 1)

| Aquifer | Base flow τ | Base flow index | Sourced? |
|---|---|---|---|
| Karst, conduit part | 2 to 10 days | — | Mostly (Olarinoye: 3 to 4 storm days) |
| Karst, matrix part | 3 months to 2 years (up to 7 in big massifs) | over 0.9 for chalk and limestone (MetricGate, unsourced there) | Yes: Fiorillo; Olarinoye |
| Chalk | 2 to 6 months (judged) | about 0.9 or more | BFI yes (weak source); τ judged |
| Sandstone (Torridonian or Permo-Triassic) | 1 to 6 months (judged, our sums above) | 0.6 to 0.8 (judged, from memory of the UK Low Flow Studies) | No |
| Hard rock: granite, schist, slate | rock store 6 months to 2 years; soil store 1 to 4 weeks | about 0.4 (#686, Low Flow Studies) | Partly: Cairngorm 2-year residence |
| Shale and mudstone | soil store only, 1 to 3 weeks; the rock adds almost nothing | 0.2 to 0.3 (as clay, MetricGate) | BFI yes (weak); τ judged |
| Sand and gravel, outwash | 2 weeks to 1 year, by thickness and L (our sums) | 0.7 to 0.9 (judged) | No |

- **Shale:** Sonny's 2,700 years is the right sum for the rock and the wrong answer for the spring.
  - Shale rock passes almost nothing (BFI 0.2 to 0.3).
  - Its "groundwater" is the soil and drift and the weathered top, with τ of weeks.
  - So for shale, the near-surface layer is the whole store, and the rock below should not count in τ.
- **The best check is the base flow index**, not τ alone. It needs no single "measured τ". Each rock's dry share of the year, from Sonny's `base_dry(τ)` and the recharge split, should land near the base flow index column.

## Never-see checks

- a karst spring that is still in flood a week after the storm, or that dries out completely in a normal summer (only its conduit share should go);
- a granite or slate hillside where the rock spring and the soil seep fail together in August;
- a shale valley with a strong summer base flow;
- a chalk stream that rises within hours of a storm;
- τ of hours or of millennia for any spring in the game.

## How ours works today (read from Sonny's plan, 8 Nov, not tested)

- R4 uses Gleeson's permeability over a uniform 50 m, with conduits at ×100 in cave-forming rock.
- `network.season.baseflow_recession_days` is one 45-day store for the whole island.
- Sonny's plan table (section 7) gives τ at L = 500 m:
  - karst 2 hours, chalk 20 days, old basalt 99 days;
  - sandstone and fresh granite 2.2 years;
  - shale about 2,700 years;
  - 5 m of outwash on granite 59 days.

## Sources

- Geological Survey Ireland, GW3D Transition Zone. https://gsi.ie/programmes-projects/groundwater/groundwater-projects/gw3d/transition-zone/
- Geological Survey Ireland (2015). *Irish Aquifer Properties: a reference manual and guide*, version 1.0: Zone 1 0.1, Zone 2 0.01 and Zone 3 0.001 m/day; the transition zone at 1 to 3 m in the quarry example. https://gsi.ie/wp-content/uploads/2026/07/IrishAquifersPropertiesAreferencemanualandguideVersion10March2015.pdf
- British Geological Survey, OR/15/028 *Aquifer characteristics* (Scotland's aquifers): fracture depth, weathered zones, yields, Torridonian T, Dalradian specific capacity, superficial deposits. https://earthwise.bgs.ac.uk/index.php/OR/15/028_Aquifer_characteristics_continued
- Soulsby, C. et al. (1999). Hydrogeochemistry of montane springs and their influence on streams in the Cairngorm mountains, Scotland. *HESS* 3, 409. https://hess.copernicus.org/articles/3/409/1999/hess-3-409-1999.html
- Olarinoye, T., Gleeson, T. and Hartmann, A. (2022). Karst spring recession and classification. *HESS* 26, 5431. https://hess.copernicus.org/articles/26/5431/2022/hess-26-5431-2022.html
- Fiorillo, F., Revellino, P. and Ventafridda, G. (2012). Karst aquifer draining during dry periods. *J. Cave and Karst Studies* 74(2), 148. https://legacy.caves.org/pub/journal/PDF/V74/cave-74-02-148.pdf
- Kovács, A., Perrochet, P., Király, L. and Jeanneret, P. (2005). Spring hydrograph recession and karst aquifer geometry and hydraulics. *J. Hydrology* 303, 152 to 164. https://libra.unine.ch/bitstreams/c1031b11-54b6-4133-b853-2a4ea9348689/download
- MetricGate, Baseflow index (BFI over 0.9 for chalk and limestone, under 0.3 for clay; the page cites no source). https://metricgate.com/docs/baseflow-index/
- Our sums: the transmissivity total and the τ tables.
- **Wanted:** a sourced table of BFI and of recession constants by UK geology (Institute of Hydrology Low Flow Studies 1980, or the HOST classes), and stream density on chalk and karst.
