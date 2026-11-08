# Snow lines and mountain climate: where snow sits on a peak

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Sonny (terrain data and bakes), the weather owner (`src/shared/weather.gd`, `src/client/weather_sounds.gd`), Kathleen (the look). **Related:** `docs/design/art_mountains.md` (#585, section 3, snow rule 5, which asks the question), `docs/design/GUIDING_DOCUMENT.md` (D-10 mountains), `worlds/base_world/world.json` (climate), `worlds/base_world/plan/tile_rules.json` (biome thresholds), `worlds/base_world/plan/sketch_rules.json` (`summit_m` per island type), `glaciers-mountains.md` (#588), [warmth-weather.md](warmth-weather.md).

## Lessons (read these first)

1. **Height alone does not decide where snow lies.** The snow line depends on three things together: how cold the summer is, how much snow falls in winter, and where the wind and the shade put it. Ohmura et al. (1992) fitted 70 glaciers and found that the climate at the equilibrium line (where a year's snow just survives) follows annual precipitation and summer temperature together: P = 645 + 296·T + 9·T² (P in mm water a year, T the June-August air temperature in °C). They found 1°C of summer warmth is worth about 350 mm of extra snow. A single temperature threshold cannot be right for both wet and dry islands.
2. **Maritime snow lines sit far lower than continental ones.** In southern Norway the mean equilibrium line rises from about 1160 m at Ålfotbreen on the coast (3.7 m water of winter snow) to 1506 m at Nigardsbreen, 1763 m at Storbreen, 1909 m at Hellstugubreen and 2129 m at Gråsubreen, the furthest inland (0.8 m of winter snow). It falls northward, to 870 m at Langfjordjøkelen. Andreassen et al. (2005) put this down to drier conditions inland. For comparison, the snow line is about 4500 m at the equator, up to 5700 m in the subtropical Himalaya, just under 3000 m in the Alps and at sea level at the poles (Wikipedia, "Snow line").
3. **Summer snow on a 1000 to 1450 m peak is real, but only in a cool, wet, maritime climate, and only in sheltered places.** Scotland is the model.
   - The Ben Nevis summit (1345 m) observatory measured a mean of -0.3°C over the year (1883-1904), -4.4°C in January and 5.1°C in July, with about 4100 mm of precipitation, twice Fort William's 2050 mm at the foot.
   - Britain's most lasting patches lie at about 1130 m in Observatory Gully on Ben Nevis and about 1140 m in Garbh Choire Mòr on Braeriach (summit 1296 m). Garbh Choire Mòr was snow-free only about a dozen times in the last century, though now more often (every year from 2021 to 2025).
   - The patches sit in gullies, in hollows and under cliffs, and many face north-east, the lee side of the westerly winds. Patches on other Highland hills (Ben Wyvis, the Grey Corries, Glen Affric) usually melt in July or August, and a patch at 955 m under the Aonach Beag cliffs counts as unusually low.
   - So summer patches sit at about 84 to 88% of the summit height (1130 of 1345 m, 1140 of 1296 m), in the shade and in the lee.
4. **Shade and wind move snow more than height does.** In the northern hemisphere, north faces get less sun and hold snow lower and longer. On our starter island, at about 34° S with the noon sun in the north, it is the south faces (`one-sky.md`). The prevailing wind strips snow off the windward crest and drops it on lee slopes and in gullies. Purves et al. (1998) modelled this on Aonach Mòr (1221 m), next to Ben Nevis, with simple cell rules: lee cells within 45° of the downwind direction get shelter, wind slows there, and snow eroded upwind is deposited. Their model piled snow into gullies, as experts see on the hill. This is why a modest summit can carry patches while a much higher open slope is bare.
5. **Steep faces shed their snow to the foot.** Above about 45° snow does not build up; it slides off. Kathleen's rule 1 and lesson 6 of `glaciers-mountains.md` (#588) say the same (avalanches start on 30-45°, fewer above 60°). The snow that falls off a face collects in the gully or on the apron below, which is often exactly where the last summer patch survives.
6. **Melt can be counted in degree-days.** Daily melt is about DDF × the day's mean temperature above 0°C. For snow, measured DDFs average about 5 mm water per °C per day (5.1 ± 2.2 over 18 sites). Ice melts faster (8.9 ± 3.7) because it is darker (Hock 2003, as summarised in the review linked below). A patch survives the summer if the snow piled into it (snowfall × drift) is more than the summer's degree-days × DDF. That one comparison is enough to place snow on a peak.

## How ours works (main aa74fc22, 8 Nov 2026)

There are **two temperature models**, and they disagree.

- **World generation** (`tile_climate.gd`, `world_settings.gd`): the sea-level annual mean comes from the latitude curve in `world.json` (`temperature_by_abs_latitude`) and falls 6.5°C per km (`lapse_rate_c_per_km`).
  - The starter spawn near z = 68 km sits at an absolute latitude of about 0.37, so the sea-level mean is about **15°C**. The outer starter row 6 sits at about 0.57, which gives about 8°C.
  - Biomes: permanent snow where the annual mean is below -8°C (`snow_max_c`), glacier below -14°C (`glacier_max_c`).
  - So snow starts at about (15 + 8) / 6.5 ≈ **3.5 km** above the starter town, and about 2.4 km on row 6. A 1000 to 1450 m starter summit never reaches it. Kathleen's note in #585 ("snow would begin near 2000 m or more") is right, and on the inner starter rows it is worse than she says.
- **Live weather** (`src/shared/weather.gd`):
  - Every temperate row uses a mean of 10°C with a seasonal swing of ±14°C (cosine, warmest at year phase 0.375), minus 0.0065°C per metre.
  - Snow falls when the air is below 0.5°C.
  - A ±14°C swing (28°C between summer and winter) is a continental climate, like inland Europe. Ben Nevis swings about ±4.8°C.
  - At 1450 m the summer peak is about 14.6°C.
- **Lying snow** (`weather_sounds.gd`): `ground_snow` is one number for the player, not for the ground.
  - It rises to full in 60 real seconds while it snows. It melts in 120 seconds above 1°C, or 900 seconds below that.
  - `weather_look.gd` feeds it to the ground shader's `snow` parameter and hides grass at 0.5 or more.
  - Nothing remembers where snow fell, so there is no snowpack, no drift and no aspect. Snow either covers everything around you or nothing.
- **The sun** (`src/client/day_cycle.gd`): the code still follows the real path for 52°N (`LATITUDE_DEG`), with the noon sun in the south and north at -Z. **Decided (Sonny, 8 Nov; latitude corrected by the 21 by 21 grid, #717 row 19):** the starter island is at about 34° S (`world.json` `latitude_for_z`), so the noon sun stands in the north and the shaded faces are the south-facing (+Z) ones. The sun times are in `one-sky.md`.

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| Oct 2026 | Lying snow as one player-side number (owner's job 17): settles while it snows, melts above 1°C | — | Works for footsteps, hush and the ground shader. Has no place memory, so it can never show patches. |
| Oct 2026 | Snow and glacier biomes from the annual mean (-8°C, -14°C) | — | Right for ice caps and giant peaks. Gives no snow below about 2.4-3.5 km on starter rows. |
| 8 Nov 2026 | Kathleen's art proposal: per-island art snow line (starter about 80% of the summit in summer, down to the treeline in winter) | #585 | Proposal, awaiting Sonny and the weather owner. The 80% matches the Scottish patches (84-88%). This page gives the physical model behind it. |

## Worked case: what the starter summit needs

These are our own sums, not a run: the degree-day rule from lesson 6 applied to the seasonal temperature curve in `weather.gd`. Assumptions: DDF 5 mm per °C per day, 2500 mm of precipitation a year on the summit, all of it snow on days below 0.5°C (the weather's own snow rule), 6.5°C per km, three years run so the result settles.

"Drift ×3" means a lee gully that gets three times the open-slope snow. That is a plausible gully loading, but it is our assumption and not a measured number.

The table shows when the last snow melts. The percentage is how far through that season it goes.

| Sea-level mean, swing | Summit | Open slope (×1) | Lee gully (×3) |
|---|---|---|---|
| 15°C, ±14 (world gen today) | 1450 m | spring 68% | summer 1% |
| 10°C, ±14 (weather today) | 1450 m | spring 99% | summer 41% |
| 15°C, ±5.5 (maritime but warm) | 1450 m | spring 15% | spring 49% |
| 9°C, ±5.5 (Scottish-like) | 1000 m | spring 91% | summer 49% |
| 9°C, ±5.5 | 1200 m | summer 14% | summer 94% |
| 9°C, ±5.5 | 1450 m | summer 49% | survives the year |
| 8°C, ±5 | 1000 m | summer 11% | summer 87% |
| 8°C, ±5 | 1200 m | summer 39% | survives the year |

What this says:

- **With today's numbers, a starter summit is bare by the start of summer**, even in a loaded gully. Changing only the art would be a disguise that the weather and warmth systems contradict. A player at 1450 m in summer would read 14.6°C while standing on painted snow.
- **A Scottish-like climate at the peak gives exactly Kathleen's island table** ("patches and gullies in summer; deep cover in winter").
  - That means a summit-level annual mean near 0°C, a small swing of about ±5°C and drift into lee gullies.
  - Open slopes clear in late spring or early summer.
  - Gullies on a 1450 m summit keep their snow all year, and on a 1200 m summit almost to autumn.
  - A 1000 m summit keeps gully snow to mid-summer only. That fits Scotland, where the lasting patches sit above about 1100 m and one at 955 m is unusual.
- **The equivalent "summer snow-patch line" is about 1200-1250 m on a 1450 m starter summit**, about 80-85% of the summit height, in south- and lee-facing gullies only (south-east on the starter). Kathleen's 80% is a good art rule of thumb because it matches the physics.

## What others do (with sources)

- **Ohmura, Kasser and Funk (1992)**, Journal of Glaciology, "Climate at the equilibrium line of glaciers". 70 glaciers: ELA climate is set by annual precipitation and summer temperature together, P = 645 + 296T + 9T², with 1°C ≈ 350 mm ≈ 7 W/m². Our sums from the formula: about 1°C summer temperature at the ELA for 1000 mm a year, about 4°C for 2000 mm, about 9°C for 4000 mm. https://www.cambridge.org/core/services/aop-cambridge-core/content/view/8DCF1C24E32A6781CC365853535CD16F/S0022143000002276a.pdf/climate-at-the-equilibrium-line-of-glaciers.pdf
- **Andreassen et al. (2005)**, Annals of Glaciology, "Glacier mass-balance and length variation in Norway". Coast-to-inland ELA and winter snow numbers (lesson 2). https://www.cambridge.org/core/services/aop-cambridge-core/content/view/5773E0EFC8C82817E538725A4AE91F31/S026030550026521Xa.pdf/glacier_massbalance_and_length_variation_in_norway.pdf
- **Snow patches in Scotland** (Wikipedia, drawing on Iain Cameron's annual surveys for the Royal Meteorological Society): patch names, heights, survival years and settings (lesson 3). https://en.wikipedia.org/wiki/Snow_patches_in_Scotland and https://www.rmets.org/metmatters/scottish-snow-patches-report-20192020
- **Ben Nevis climate**: the summit observatory means, 1883-1904, and rainfall at the summit versus Fort William. https://en.wikipedia.org/wiki/Ben_Nevis and https://www.ben-nevis.com/information/climate/climate.php
- **Snow line** (Wikipedia): the latitude figures, the climatic and orographic snow line, north faces lower in the northern hemisphere, maritime lower than continental. https://en.wikipedia.org/wiki/Snow_line
- **Purves, Barton, Mackaness and Sugden (1998)**, Annals of Glaciology 26, "Development of a rule-based spatial model of wind transport and deposition of snow". A 50 m grid model of Aonach Mòr with shelter for lee cells within 45° of downwind, wind deflection by slope, a drift threshold, transport proportional to wind speed cubed, and no drifting after a melt-freeze crust. It reproduced gully accumulation. https://www.cambridge.org/core/services/aop-cambridge-core/content/view/710975E7F56C7C9CAC2D729CA5358DC0/S0260305500014804a.pdf/development_of_a_rulebased_spatial_model_of_wind_transport_and_deposition_of_snow.pdf
- **Hock (2003)**, Journal of Hydrology 282, "Temperature index melt modelling in mountain areas". Degree-day melt works well at catchment scale. Its weakness is that slope, aspect and shade change melt, so distributed versions add a radiation or shade term. The DDF means above are as cited in this review: https://core.ac.uk/download/74100932.pdf. Abstract: https://repository.geologyscience.ru/items/959fd6dc-a49d-44b9-8a58-c662ee369ac5/full

## Decided / next

Item 4 was decided by the coordinator (answering for Dave) on 8 Nov 2026. The rest are proposals.

1. **Keep `snow_max_c` -8 and `glacier_max_c` -14 for what they are:** permanent snowfields and ice on high peaks. Do not lower them to fake summer patches. Lowering them would put whole snow biomes on hills.
2. **[Proposal] A baked seasonal snow layer per terrain cell** (Sonny for the bake and format, the weather owner for the live side). Two bytes a cell: the year phase when snow first lies in autumn or winter, and the phase when it melts out. Work it out as in the worked case:
   - snowfall from the island's climate and height;
   - times a drift factor: lee of the prevailing wind within 45° (Purves et al.), hollows and gullies, about 0.3-0.5 on scoured crests, about 2-3 in lee gullies;
   - with snow shed from slopes over about 45° to their foot;
   - minus degree-day melt, scaled down on shaded faces (south-facing, +Z, at the starter's 34° S).

   The client then shows snow on a cell when the clock is inside that cell's window. Footsteps and the ground shader can read the same answer at the player's feet, so the look, the sound and the warmth agree. The bake runs on Dave's PC like every other bake.
3. **[Proposal] Per-island climate inputs**, set at the same island-type stage as `summit_m` (D-10): a sea-level mean, a seasonal swing and a precipitation level.
   - Small ocean islands should swing far less than ±14°C. ±5-7°C is realistic for a maritime island.
   - The starter island would need a peak climate like the 9°C ±5.5 row in the worked case for gully snow to last the summer.
4. **Decided (coordinator, 8 Nov 2026): a cooler, wetter starter island.** The starter island gets a sea-level mean of about 9°C with a seasonal swing of about ±5°C and high orographic rain, so summer snow patches sit at about 80-85% of the summit in lee and shaded gullies. The two options weighed were:
   - **(a) Chosen: a cooler, wetter starter island.** Sea-level mean about 9-10°C instead of 15°C (the weather already uses 10°C), a small swing and high orographic rain. This is real physics, as in Scotland or western Norway. It touches the warmth system (`warmth.json` reads the weather temperature), so Steve should check the night cold still feels fair.
   - **(b) Not chosen: a per-island `snow_bias_c`** of about -5 to -6°C, used only by the snow layer (the "mountain makes its own cold" fantasy). This is cheaper, but it is a stated fantasy rule that would need to be written into the guiding document. Otherwise it is the kind of disguise D-10 warns against.
5. **[Open, with Sonny] The two temperature models should become one.** World generation gives the starter 15°C and the weather gives it 10°C. Pick one source and have the other read it. The coordinator handed this to Sonny with the snow line work (8 Nov).
6. **Decided (Sonny, 8 Nov 2026; latitude corrected by the grid, #717 row 19): one sky.** The starter island is at about 34° S (33.7° S at the spawn), so the noon sun is in the north, and shade, late snow and cirques favour south to south-east slopes. `day_cycle.gd` still uses 52°N until it is changed to match. See `one-sky.md`.
