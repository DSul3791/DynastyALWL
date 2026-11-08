# Soils and ground wetness: infiltration, puddles, peat and clay, frost heave, mud season

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Sonny (the R6 record: `table_depth`, `fresh_m`, `sediment_m`, soil types from `tile_climate.gd`); Kathleen (puddles, #610 design in `docs/design/art_weather_light.md`, #614 code). **Related:** `upland-streams-numbers.md` (#612, Plynlimon runoff), [warmth-weather.md](warmth-weather.md), `docs/design/one_temperature.md` (#620), `docs/design/still_water_ice.md`.

"Our sums" means arithmetic done here from a sourced number. "Judged" means no source was found today.

## Lessons (read these first)

1. **How fast water sinks in depends on the soil: from about 40 mm an hour in gravel to about 1.5 mm an hour in clay.**
   - **Minnesota Stormwater Manual, "Design infiltration rates"** (uncompacted soils):

     | Soil | mm/h |
     |---|---|
     | Gravel, sandy gravel, gravelly sand | 41 |
     | Sand, loamy sand, sandy loam | 20 |
     | Silty sand | 11 |
     | Loam, silt loam | 7.6 |
     | Sandy clay loam, silt | 5.1 |
     | Clay loam, silty clay, clay | 1.5 |

     For compacted soil, the manual says to drop one row.
   - **Seepage from standing water** (FAO pond guide), mm a day:

     | Soil | Natural | After puddling (worked wet and trodden) |
     |---|---|---|
     | Sand | 25 to 250 | — |
     | Sandy loam | 13 to 76 | 3 to 6 |
     | Loam | 8 to 20 | 2 to 3 |
     | Clay loam | 2.5 to 15 | 1 to 2 |
     | Clay | 1.25 to 10 | about 1 |

     Trampled wet ground seals: under a puddle on a used track, clay lets through only about 1 mm a day.
2. **Trampling packs the soil and stops water soaking in. That is why tracks hold puddles** (US Forest Service, trail impacts): "Compaction packs the soil particles closer together and eliminates pore spaces". The pictured trail is "compacted, muddy, and rutted", and walkers stepping round the puddles widen it.
3. **Blanket peat is nearly always full. Its water table stays within 5 cm of the surface 93% of the year, and rain runs off it quickly.**
   - **Holden and Burt (Moor House, North Pennines), White Rose eprint:**
     - the water table is "above 5 cm depth for 93 % of the year";
     - under 3 to 12 mm/h of rain, steady infiltration was only 2 to 7 mm/h, and 32 to 41% of the rain ran off over the surface;
     - another 22 to 26% came out of the top 1 to 5 cm;
     - runoff started "only 20 minutes after the onset of rain", and it was steady after about an hour.
4. **Clay soils stay waterlogged near the surface for months.**
   - **Soil wetness classes** (Natural England soil reports):

     | Class | Wet within 40 cm or 70 cm |
     |---|---|
     | I | wet within 70 cm for 30 days or less a year |
     | II | 31 to 90 days within 70 cm |
     | III | 91 to 180 days within 70 cm |
     | IV | more than 180 days within 70 cm |
     | V | 211 to 335 days within 40 cm |
     | VI | more than 335 days within 40 cm |

   - **Clay over clay:** "Clay topsoils overlie clay subsoils which show evidence of shallow wetness". "Gleying occurs right from the surface" (Wetness Class IV).
5. **Puddles dry mostly by sinking in where the soil allows it. On packed clay and rock they dry only by evaporation, which is slow.**
   - **Open water evaporation** (FAO): a Class A pan read 56 to 84 mm a month from April to August at the example station, and ponds evaporate about 0.75 times the pan.
   - **UK factors** (Environment Agency, open water evaporation report): open water evaporates 1.25 times the grass reference in midsummer, 1.43 in spring and autumn, and 1.67 in midwinter (Penman 1948).
   - **Our sums:** about 1.5 to 2 mm a day in summer. Commonly quoted UK grass figures (not checked today) are about 0.3 mm a day in winter and 3 mm in summer, which gives about 0.5 mm a day of open water evaporation in winter and 3 to 4 mm in summer.
6. **Frost heave needs three things: freezing, a frost-susceptible soil (silt, loam, very fine sand) and plenty of water.**
   - **North Dakota Geological Survey newsletter, "Frost heave":** it needs "the right kind of soil and an abundant, readily available water supply". Ice lenses grow at the freezing front, fed by water drawn up from below, lying flat to the surface.
   - **Stones and posts:** frost brings up "more stones to the surface each spring", and it lifts fence posts.
   - **Size:** a Bismarck street rose about 46 cm in spring 2011, in a hard continental winter.
7. **Mud season: the ground thaws from the top while the frozen layer below traps the water.**
   - **Wikipedia, "Mud season":** "The frozen lower layers of ground prevent water from percolating into the soil." The topsoil waterlogs.
   - **Timing:** New England in March and April.
   - **Soil:** clay, especially poorly drained clay, makes deep, sticky mud. Sandy soil gets waterlogged but not gluey.

## Checking the puddle design's drain times (#610)

Kathleen's table has puddles dry again 1 h (gravel), 1.5 h (turf), 2 h (litter), 2.5 h (flat rock) and 3 h (mud and clay) after the rain. In real ground (our sums, a typical puddle 2 to 3 cm deep):

| Ground | What empties it | Real time to dry | Design | Verdict |
|---|---|---|---|---|
| Gravel | sinking in, 41 mm/h | about 45 min | 1 h | right |
| Sand, beach | sinking in, 20+ mm/h | under 10 min, so no puddles | proneness 0 | right |
| Turf on loam | sinking in, 7.6 mm/h | about 3 to 4 h | 1.5 h | a little fast. 3 h would be truer |
| Forest humus and litter | sinking in fast (judged) | about 1 to 2 h | 2 h | right |
| Peat | does not sink in (lesson 3) | stays wet for days or weeks; bog pools are permanent | 2 h, with humus | wrong for peat. Split peat from humus |
| Flat bare rock | evaporation only | 1 cm dips take 3 to 7 days in summer and weeks in winter | 2.5 h | much too fast |
| Mud, clay and worn tracks | sealed at about 1 mm a day, plus evaporation | 3 cm takes about 5 to 10 days in summer and 3 to 6 weeks in winter | 3 h | much too fast |

**At game speed:** one game day is about one real hour (2.5 real minutes per game hour). So real times map to:
- track puddles lasting 5 to 10 game days in summer: 5 to 10 real hours;
- weeks in winter: most of a real day or more.

That is a real game feel: tracks stay muddy through a wet spell. Judged proposal, if Kathleen wants it:

| Ground | Dry again in (game time) |
|---|---|
| Gravel | 1 h |
| Turf | 3 h |
| Forest litter | 2 h |
| Flat rock dips | 2 days in summer, 6 in winter |
| Worn tracks, mud and clay | 3 days in summer, 10 in winter, and never fully dry in a wet spell |
| Peat | the shallowest pools never dry; the rest as clay |

- **Light rain** (below 0.15) halves the drying, as in the design.
- **Evaporation scales with the season:** use the open-water rates in lesson 5, about 0.5 mm a day in winter and 3 to 4 mm in summer. Sun and wind speed it up, at about 1.5 times on a sunny, windy day (judged).

If the cost of slow puddles is a concern, the design's short times are a fine first pass. The never-see checks below are what matter most.

## Judged numbers for the record (R6) and the ground

### Standing water and table depth by soil

| Soil (`tile_climate.gd`) | Wetness class (judged) | Table depth in winter | In summer | Surface water |
|---|---|---|---|---|
| sand, beach_sand | I | deep (2 m or more) | deep | none |
| gravel, stony_soil | I to II | 1 to 2 m | deep | none, except where packed |
| loam, silt | II to III | 0.4 to 0.7 m | 1 m or more | puddles after heavy rain, in hollows |
| alluvium (valley floors) | III to IV | 0.2 to 0.5 m | 0.5 to 1 m | wet flats after floods, standing for days |
| clay | IV to V | 0 to 0.3 m | 0.5 m | puddles and wet patches all winter |
| peat (blanket and basin) | VI | 0 to 0.05 m (93% of the year) | 0.05 to 0.2 m | bog pools all year, and rain runs straight off |
| forest_humus | as the soil below | — | — | a spongy layer, few puddles |
| bare_rock | — | — | — | water only in dips, drying by evaporation |

- **Slope and position matter as much as the soil:**
  - hollows, valley floors and the foot of slopes are a class wetter;
  - ridges and steep slopes are a class drier.
- **The record's `table_depth`:** it can carry the winter value. The client can blend toward the summer value with the season.

### Runoff for the water record

- **Rain on peat and saturated clay runs off** in 20 to 60 minutes (lesson 3). About a third or more runs over the surface. That is why peat uplands have flashy streams (`upland-streams-numbers.md`).
- **Rain on sand and gravel** sinks in. Streams on it are steady and spring-fed.

### Frost heave and needle ice (starter island)

- **When:** only on frosty nights (air −2 °C or colder; about 25 to 60 a year at the coast, more inland), on bare wet silt or loam (paths, fresh digging, molehills, stream banks).
- **What:** needle ice a few millimetres to 2 cm tall, lifting soil crumbs and small stones (judged). It crunches underfoot, then collapses into loose mud at 09:00 to 11:00 as the sun reaches it.
- **Over a long hard spell** (a week below 0 °C): the ground lifts 1 to 3 cm (judged; the 46 cm Bismarck case is a continental extreme). Fence posts and stakes rise a little each winter. Stones turn up in dug ground each spring.
- **Never:** heave in sand, gravel or peat (peat freezes, but it is not frost-susceptible in the same way, judged), or under deep snow (snow insulates).

### Mud season

- **On the starter island** (9 °C mean, short frost spells): the ground rarely freezes more than a few centimetres. There is no real mud season. Instead, clay and tracks are muddy all through the wet winter, as above.
- **Cold islands** (arctic and transition zones, or high ground above about 600 m on the starter):
  - the ground freezes 0.3 to 1 m deep over winter;
  - in the 2 to 6 weeks after the thaw starts, the top thaws over the frozen layer, so tracks on clay and silt turn to deep sticky mud (lesson 7);
  - sand only goes soft and wet.
- **What the player sees:**
  - footprints and ruts that stay;
  - slower walking on clay tracks (judged: about 0.8 times);
  - carts and horses bogging (a later job).

### Never-see checks

- a track puddle that is gone an hour after a storm on clay;
- puddles on sand or on a beach;
- dry, firm footing across a peat bog in winter;
- frost needles on dry sand;
- spring mud on the coast of the temperate starter as deep as on a cold island.

## How ours works today

From a grep on 8 Nov:
- **Soils:** `tile_climate.gd` lists bare_rock, sand, gravel, silt, clay, loam, peat, alluvium, forest_humus, stony_soil, permafrost, snow, glacial_ice and beach_sand. Peat depth comes from `tile_geology.gd` (`peat_m`).
- **The R6 record** (Sonny's design) carries `table_depth`, `fresh_m` and `sediment_m` per 8 m tile.
- **Puddles:** in Kathleen's design (#610) and code (#614), on fixed hollows with proneness and drain times by ground type, a look and sound only. The server does not know them.
- **What's missing:** no frost heave, no needle ice and no mud season. The ground wetness the client uses for the look (`cover.gd` wetness maps) was not checked in detail.

## Sources

- Minnesota Stormwater Manual, Design infiltration rates: https://stormwater.pca.state.mn.us/index.php/Design_infiltration_rates
- FAO, Simple methods for aquaculture: estimates of water requirements (evaporation, seepage by soil): https://www.fao.org/fishery/static/FAO_Training/FAO_Training/General/x6705e/x6705e02.htm
- US Forest Service, trail and recreation impacts on soils: https://www.fs.usda.gov/eng/pubs/html/04231201/page11.htm
- Holden, J. and Burt, T. P., runoff production in blanket peat (Moor House), White Rose eprint: https://eprints.whiterose.ac.uk/482/1/holdenj4.pdf
- Natural England, agricultural land and soil survey report (soil wetness class definitions, Appendix II): https://publications.naturalengland.org.uk/file/5352117091434496
- Environment Agency, Estimating open water evaporation in England and Wales (Penman factors): https://assets.publishing.service.gov.uk/media/5a7b90d4e5274a7202e17ff6/sw6-043-tr-e-e.pdf
- North Dakota Geological Survey newsletter (Summer 2011), Frost heave: https://www.dmr.nd.gov/ndgs/documents/newsletter/2011Summer/FrostHeave.pdf
- Wikipedia, Mud season: https://en.wikipedia.org/wiki/Mud_season
