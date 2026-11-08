# Sea and shore: tides, waves, surf, swash, wrack, spray and shore ice

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Sonny (the coast in the record and the sea level); Kathleen (how the sea and shore look); the shore gathering rules (`src/shared/shore_rules.gd`, Tyler's `ACT_GATHER_EDGE`). **Related:** `wind-over-terrain.md` (#637, the wind's m/s), `docs/design/still_water_ice.md` (ice), `docs/design/fog_pools_and_sea_fog.md` (#608), `sound-outdoors.md` (#642).

"Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found today.

## Lessons (read these first)

1. **Most coasts have two high tides a day, 12 h 25 min apart. The range swells and shrinks over two weeks.**
   - **Period** (Wikipedia, "Tide"): the main lunar tide has a period of "about 12 hours and 25.2 minutes", so high water comes about 50 minutes later each day. The Moon returns to the same place in the sky after about 24 h 50 min.
   - **Springs and neaps:** spring and neap tides are about 7 days apart, on a cycle of about two weeks. In theory the spring tide is 79 cm and the neap 29 cm, a ratio of about 2.7 to 1. Coasts amplify this a great deal.
   - **The rule of twelfths:** over the six hours from low to high water, the level rises 1/12, 2/12, 3/12, 3/12, 2/12, then 1/12 of the range in successive hours. The middle two hours move half the water.
   - **A real mid-latitude island coast** (Scotland's Marine Atlas): tidal range is "generally between 4 and 5 m", and 7 to 8 m in the inner Solway Firth. Near amphidromic points (for example between Islay and Kintyre) the range is small.
2. **Waves grow with wind speed and fetch (the open water upwind), until the sea is fully developed.**
   - **Shore Protection Manual fetch-limited growth** (NPTEL coastal engineering notes):
     - gH/U_A² = 0.0016·(gF/U_A²)^0.5 and gT/U_A = 0.286·(gF/U_A²)^(1/3), with U_A ≈ 0.71·U₁₀^1.23.
     - As a check, a steady 10 m/s wind for 48 h gave Hs = 2.14 m and Tp = 7.4 to 7.7 s in three models.
   - **Our sums** (significant height and peak period, capped at a fully developed sea):

     | Wind | 1 km fetch | 10 km | 50 km | 200 km |
     |---|---|---|---|---|
     | 5 m/s | 0.08 m, 1.1 s | 0.26 m, 2.3 s | 0.59 m, 4.0 s | 0.66 m, 4.3 s (full) |
     | 10 m/s | 0.19 m, 1.4 s | 0.62 m, 3.1 s | 1.4 m, 5.3 s | 2.8 m, 8.4 s |
     | 15 m/s | 0.32 m, 1.7 s | 1.0 m, 3.6 s | 2.3 m, 6.2 s | 4.5 m, 9.9 s |
     | 20 m/s | 0.46 m, 1.9 s | 1.4 m, 4.1 s | 3.2 m, 7.0 s | 6.5 m, 11.1 s |

     A sheltered bay or a sea loch with 1 to 10 km of fetch never gets big waves. An open Atlantic coast also gets swell from storms far away, longer and higher than the local wind makes.
   - **Real numbers for comparison:** in Scotland, wave height is greatest on the Atlantic side and "generally below 1.2 m" close inshore (Marine Atlas).
3. **Waves break at about 0.8 times the water depth. The surf zone is the depth of breaking divided by the beach slope.**
   - **Bosboom and Stive, "Coastal Dynamics", 5.2.5 Wave breaking:**
     - the breaker index γ = H/h is about 0.6 to 0.8 for spilling breakers and 0.8 to 1.2 for plunging ones, with "ca. 0.8" on average;
     - the Iribarren number ξ = tan(slope) / √(H₀/L₀) sets the breaker type. Flat beaches give spilling breakers over 6 to 7 wavelengths. Steep shores with long swell give surging breakers with a narrow breaker zone, and more than half the energy reflects back to sea.
   - **Beach states** (OzCoasts, Australian beach types):
     - **Dissipative:** fine sand, waves often over 2.5 m, a surf zone "up to 500m wide" with 2 or 3 bars.
     - **Intermediate:** a bar 100 to 150 m out with 1.5 to 2 m waves, or a low-tide terrace with about 1 m waves.
     - **Reflective:** coarser sand (about 0.4 mm), steep and narrow, waves under 0.5 m, and "no bar or surf zone".
   - **Our sums:** surf zone width ≈ (H ÷ 0.8) ÷ tan(slope). For 1 m waves that is 13 m on a 1:10 beach, 63 m on 1:50 and 125 m on 1:100. For 2 m waves on 1:100 it is 250 m.
4. **Coarse sediment makes a steep beach.** Gravel beaches are steeper than sand beaches (Canterbury Bight and Kaikoura study, New Zealand).
   - **Mixed sand and shingle:** median foreshore 5 to 6°, and over 80% of slopes under 10°.
   - **Sandy Portuguese beaches** (Geomorphology 114, 2010): gradients 0.03 to 0.14 (2 to 8°) on fine to medium sand, and 0.1 to 0.19 (6 to 11°) on coarse sand.
5. **The swash runs up the beach and the backwash runs down. On gravel, much of it sinks in.**
   - **Coastal Wiki, "Swash zone dynamics":**
     - runup and backwash reach 2 to 5 m/s;
     - the backwash is usually longer and shallower than the uprush;
     - on coarse sand and gravel, "a significant volume of the uprush and some of the backwash may percolate into the beach";
     - on dissipative beaches, the swash is driven by slow surf beat (infragravity waves) rather than each wave.
   - **Runup** (Stockdon et al. 2006, via Coastal Wiki "Wave run-up"):
     - for ξ ≥ 0.3: R2 = 1.1·(0.35·H·ξ + 0.5·√(H·L·(0.563·β² + 0.004)));
     - on dissipative beaches (ξ < 0.3): R2 ≈ 0.043·√(H·L).
   - **Our sums (R2, the vertical runup height):**

     | Waves | Slope 1:50 | Slope 1:20 | Slope 1:10 |
     |---|---|---|---|
     | 0.5 m, 5 s | 0.19 m | 0.26 m | 0.41 m |
     | 1 m, 8 s | 0.43 m | 0.60 m | 0.92 m |
     | 2 m, 10 s | 0.76 m | 1.05 m | 1.6 m |

     Divided by the slope, 1 m waves on a 1:50 beach run about 20 m up the sand.
6. **The wrack line marks the last high tide. It sits higher at springs than at neaps.**
   - **Wikipedia, "Beach wrack":** debris is "deposited at high tide" in a line parallel to the water's edge, higher during spring tides. It holds kelp, seagrass, land plants, driftwood, dead animals, and today plastics and fishing line. Storms add more.
   - Kelp flies and shore flies breed in it, rove beetles live in the wet sand below, and shorebirds feed on the sand-hoppers and worms.
7. **Salt spray falls most within a few hundred metres of the sea, but it reaches km inland.**
   - **Gulei Peninsula, Fujian** (Chinese Journal of Ecology 2019): in winter, deposition "decreased rapidly with distance closer than 500 m from the shoreline". From 100 m to 1,700 m inland it fell only from 98 to 58 mg/m² a day, a 41% drop. Wind speed and direction drive it.
8. **The temperate sea does not freeze, but freezing spray ices rocks and boats when the air is −2 °C or colder.**
   - **Finnish Meteorological Institute, ice accretion warnings:** "the air temperature must be at −2 °C or under it to cause freezing splashes in salty sea water". The sea surface must be under +5 °C. Stronger wind means more spray.
   - **Our ice design** (`still_water_ice.md`): salt water freezes at −1.8 °C, and the open sea freezes only in the arctic zone.

## Judged numbers for the game

The game has no tide today. `world_definition.gd` has a fixed `sea_level_meters`, and the moon in `day_cycle.gd` is always full. Shore gathering already speaks of "the tide line" (`shore_rules.gd`).

### Tides, if they come

- **Shape:** semidiurnal, 12 h 25 min between high waters, following the rule of twelfths. High water comes about 50 minutes later each game day.
- **Range on the starter island:** spring about 3 m and neap about 1.2 m, on a 14.8 game-day cycle (judged: a little under Scotland's 4 to 5 m, to keep beaches readable).
  - **Sheltered sea lochs and enclosed bays:** about 0.7 times that.
  - **Islands near an amphidromic point:** as little as 0.5 m.
  - **Other island types** can carry their own range in the climate record.
- **The moon:** springs fall 1 to 2 days after new and full moon. The moon is always full today, so this is only for a later moon-phase job.
- **Server and client:** both can work out the tide level from game time alone, as with the weather. Nothing needs to be sent.
- **What the tide changes:**
  - the waterline and the wet sand band;
  - rock pools at low water;
  - where `shore_rules` nodes appear (the wrack line moves with the last high water);
  - the sea caves flooding (already assumed in `tile_terrain_data.gd`).

### Waves by fetch

- **Wave height:** read from the table in lesson 2, using the weather's `wind` turned into m/s (m/s = 20·wind^1.3, `wind-over-terrain.md`) and the fetch upwind along `wind_dir` from each shore stretch.
- **Fetch values** (judged): a bay or sea loch 1 to 10 km; an open coast facing the ocean 200 km plus swell.
- **Swell on open coasts** (judged): about 1 to 2 m at 8 to 12 s on most days, even in calm weather.
- **Lee shores:** a coast facing away from the wind gets only swell that wraps around the island, about 0.3 times as high.

### Surf zone and beach slope by material

| Beach | Slope | Breakers | Surf zone with 1 m waves |
|---|---|---|---|
| Fine sand, exposed | 1:50 to 1:100 (0.6 to 1.1°) | spilling, several lines of white water | 60 to 125 m |
| Medium sand | 1:20 to 1:30 (2 to 3°) | spilling or plunging | 25 to 40 m |
| Coarse sand | 1:8 to 1:12 (5 to 7°) | plunging | 10 to 15 m |
| Shingle and gravel | 1:5 to 1:8 (7 to 11°), steps and berms | surging and dumping, little surf | under 10 m |
| Rock platform | flat to stepped | breaks on the outer edge | — |

- **Swash:** runs up the beach 3 to 20 m by the table in lesson 5. Each wave's swash lasts about half the wave period.
- **Backwash:** thinner and longer than the uprush.
- **On gravel:** the backwash mostly sinks in, with a rattle of stones as it drains (judged sound).
- **The wet line:** the swash leaves a dark band of wet sand that dries in 1 to 2 minutes in sun and wind (judged).

### The wrack line

- **What:** a band 1 to 3 m wide of seaweed, wood and shells (judged).
- **Where:**
  - just below the last high water's swash limit;
  - an older, drier line higher up from the last spring tide;
  - a storm line higher still (judged: up to 2 m vertically above spring high water on exposed coasts).
- **Freshness:** fresh lines are dark and wet. Older ones are bleached and dry, with flies over them in summer.
- **The game's wrack:** `grass_view.gd` already has a shore layer called `wrack`. It should follow these lines, not scatter across the beach.

### Spray

- **Salt spray on plants** (judged, from lesson 7's steep first 500 m):
  - stunted, wind-cut shrubs and salt-tolerant grasses within about 50 to 200 m of exposed shores;
  - trees leaning and dying back on the windward side within about 500 m;
  - little effect beyond 1 km.
- **Visible spray:** off breaking waves above `wind` 0.5. Drifting mist 20 to 100 m inland on rough days (judged).

### Shore ice in cold spells (temperate starter)

- **The open sea:** never freezes (lesson 8, `still_water_ice.md`).
- **Freezing spray** (air −2 °C or colder with `wind` 0.4 or more): a glaze on rocks, wrack and posts within the spray reach. It melts on the next tide or when the air rises above 0 °C.
- **Rock pools above high water:** fresh or brackish (rain-fed). They freeze like ponds by the ice rules.
- **Wet sand above the swash:** freezes crisp on frosty nights (air −2 °C or colder) and thaws in the morning sun.
- **Slush in the swash:** only in the arctic zone, when the sea is near −1.8 °C.

### Never-see checks

- big surf in a small sheltered bay with 2 km of fetch;
- surf breaking far out on a steep shingle beach;
- the wrack scattered across the whole beach instead of in lines;
- ice on the open temperate sea;
- dry sand right below the swash.

## How ours works today

From a grep on 8 Nov:
- **Sea level:** fixed (`world_definition.gd`, `sea_level_meters`), and there are no tides.
- **The moon:** always full and opposite the sun (`day_cycle.gd`).
- **Shore gathering:** `shore_rules.gd` puts tide-line nodes on 8 m cells by a seeded draw per game day, and the server's `ACT_GATHER_EDGE` hands them out.
- **Shore props:** `grass_view.gd` shore layers (pebbles, shells, wrack, reeds, boulders) and `shore_props.gd`.
- **Ocean ice:** `ocean_ice.gd` (the client) draws sea ice from `Ice.sea_cover`, which is zero outside the arctic.
- **Not checked:** how the client draws waves and surf today.

## Sources

- Wikipedia, Tide: https://en.wikipedia.org/wiki/Tide
- Scotland's Marine Atlas, Physical characteristics: https://www.gov.scot/publications/scotlands-marine-atlas-information-national-marine-plan/pages/10/
- NPTEL, Coastal engineering Module 6 (SPM deep-water wave prediction): https://archive.nptel.ac.in/content/storage2/courses/114106028/Module-6.pdf
- Bosboom, J. and Stive, M., Coastal Dynamics, 5.2.5 Wave breaking: https://geo.libretexts.org/Bookshelves/Oceanography/Coastal_Dynamics_(Bosboom_and_Stive)/05%3A_Coastal_hydrodynamics/5.02%3A_Wave_transformation/5.2.5%3A_Wave_breaking
- OzCoasts, Beach types: https://ozcoasts.org.au/?p=1112
- Relationships between grain size, size sorting and foreshore slope on mixed sand-shingle beaches (NZ): https://ref.coastalrestorationtrust.org.nz/site/assets/files/5104/relationships_between_grain_size_size_sorting_and_foreshore_slope_on_mixed_sand_shingle_beaches.pdf
- Beachface slope and sand size, Geomorphology 114 (2010): https://home.uevora.pt/~ahr/9.pdf
- Coastal Wiki, Swash zone dynamics: https://www.coastalwiki.org/wiki/Swash_zone_dynamics
- Coastal Wiki, Wave run-up (Stockdon et al. 2006): https://www.coastalwiki.org/wiki/Wave_run-up
- Wikipedia, Beach wrack: https://en.wikipedia.org/wiki/Beach_wrack
- Salt spray deposition on the Gulei Peninsula, Chinese Journal of Ecology (2019): https://core.ac.uk/download/343510453.pdf
- Finnish Meteorological Institute, Ice accretion warnings: https://en.ilmatieteenlaitos.fi/ice-accretion-warnings
