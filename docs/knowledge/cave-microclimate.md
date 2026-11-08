# Cave microclimate: temperature, damp, air at the mouth, daylight, drips

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:**
- Kathleen: cave light, mouth fog and the sound of drips (`weather_look.gd`, `cave_sounds.gd`).
- Steve: goblin dens (`server_goblins.gd`) and warmth (`server_items.gd` `warmth_target`).
- MikeW: animals that use caves, such as bats and bears.
- Sonny: cave shape and placement.

**Related:** [caves.md](caves.md), [firelight-in-weather.md](firelight-in-weather.md), [torches-fire.md](torches-fire.md), [warmth-weather.md](warmth-weather.md), `soils-ground-wetness.md` (#657), `docs/design/goblin_den_life_design.md`, `docs/design/one_temperature.md` (#620).

## Lessons (read these first)

1. **Deep in, a cave is the year's average temperature, all year round, day and night.**
   - Rock temperature "reflects the long-term mean annual air temperature of the outside atmosphere". Caves deeper than 11 m "display variations <1°C" (Pflitsch and Piasecki 2003, citing Moore and Sullivan).
   - Milandre Cave (Switzerland, 10.5 km long): the stream held 10.5 °C ± 0.1 °C from 2015 to 2018.
   - The larger Mendip caves (England) are "fairly constant; approximately 10-13°C" deep in (BCRA Cave Life).
   - Draughts and streams change this near the mouth, and "this effect decreases the further into the cave you go" (BCRA).
   - So a deep cave feels warm on a winter night and cool on a summer afternoon. It is the same air both times.

2. **The air in a cave is saturated, so nothing dries there.**
   - Humidity is "usually between 98 and 100%". It drops to about 75% only "near entrances with draughts" (BCRA Mendip).
   - Milandre's upper section stays "close to saturation all year long".
   - Cave air also holds a lot of carbon dioxide: 1 to 3% in Milandre, against 0.04% outside.

3. **The mouth breathes, and its direction turns with the seasons.**
   - **Two entrances at different heights (the chimney effect):**
     - in winter, cave air is warmer than outside, so it rises and leaves by the top entrance while cold air comes in low;
     - in summer the flow reverses (NCKRI). Milandre shows "ascending air flow in winter and descending in summer", up to 3 m³/s;
     - the flow turned over when the outside air was about 8 °C, a little below the cave's 10.5 °C.
   - **One entrance below the chamber (a pit or a descending passage):**
     - this is a cold trap. Winter air sinks in and stays, and warm summer air "is lighter and cannot enter" (Wikipedia, ice caves);
     - such caves can run colder than the yearly average and hold ice all year.
   - **Weather fronts:**
     - a cave also breathes with air pressure. It blows out when pressure falls and draws in when it rises (NPS Wind Cave);
     - a small entrance makes this fierce: over 70 mph (31 m/s) has been clocked at Wind Cave's walk-in entrance.
   - **Air speed inside:**
     - most cave air moves "of the order of a few cm/s", and "rarely exceeds 1 m/s" (Pflitsch and Piasecki);
     - Bear Cave in Poland: 1 to 4 cm/s in a still chamber, and 5 to 10 cm/s down a cascade;
     - so past the mouth there is, in practice, no wind.
   - **A single entrance does not always breathe in and out at the mouth.**
     - Andrassa (Italy) is a single-entrance cave with dripping water. Measurements found no warm air leaving along the roof. The air left through cracks above instead (Motta and Motta 2016).
     - Outside air still changed the cave to at least 180 m in summer, but to only about 60 m in winter.

4. **Mist forms where cave air and outside air meet.**
   - **Summer:** warm outside air that comes in cools, saturates, and "condenses on the walls and ceiling" (BCRA). Mammoth Cave once filled its first big room with a fog cloud near the ceiling. A storm had reversed the flow and "sucked" warm, moist air in (NPS, reported by NewsNation).
   - **Winter:** the reverse happens. Saturated air at the cave's temperature leaves into freezing air and steams at the mouth. This one is our sums: mixing saturated air with colder air always condenses, the same way breath does.

5. **Daylight reaches about 20 m, and a bend ends it.**
   - Caves have three zones: entrance, twilight and dark. The twilight zone reaches "about 20 metres into the cave", with ferns, lichens and algae on the rock (ASF cave ecology).
   - Green plants stop sharply at the entrance. "The dark zone lies beyond the reach of daylight", and any plant in it is an accident (BCRA).
   - **How fast the light drops (our sums):**
     - the light falls with the square of the distance from the mouth: share of outside light ≈ mouth area ÷ (π × distance²);
     - a 3 × 3 m mouth gives 11% at 5 m, 2.9% at 10 m, 0.7% at 20 m, 0.1% at 50 m and 0.03% at 100 m;
     - on a 10,000 lux overcast day, that is about 70 lux at 20 m and 3 lux at 100 m, but only down a passage that is perfectly straight;
     - every bend loses the direct view of the mouth. What is left is light bounced off rock that reflects 10 to 40% of it, so each bend divides the light by about 20 to 50 (judged);
     - one bend leaves about moonlight level, which is 0.1 to 0.25 lux (de Beaune, cited by Medina-Alcaide et al. 2021). Two bends leave pitch black.
   - A big open cave can be almost all twilight. In one large Mexican cave, about a third of the cave had more than 0.01 lux (International Journal of Speleology 47(1)).

6. **Eyes go dark fast and see again slowly. Coming out, they are dazzled for only seconds.**
   - Cones take 9 to 10 minutes to adapt to the dark. Full dark adaptation from sunlight takes 20 to 30 minutes (Wikipedia, adaptation of the eye).
   - Adapting back to light happens "within seconds", though it is not complete for up to about 5 minutes.
   - So stepping into a dim cave is black at first, then the twilight shapes slowly come back. Stepping out is a short white glare.

7. **Drips follow cracks, sit under thin rock, and come from rain that fell hours to months ago.**
   - Drip water reaches a cave through joints and cracks (NCKRI).
   - Speeds range widely. Many drips run at about 1 drip a minute or faster (Baker and Fairchild 2012). The fastest site in Golgotha Cave (Western Australia) gave 25 drips in 15 minutes, under 32 to 40 m of rock. Its slowest sites gave under 4 drips in 15 minutes.
   - Drips fed by cracks answer rain within hours. Slow seepage answers months later: about 6 months at Golgotha, and the water can be years old.
   - Many drips slow down or stop in a dry summer (Père Noël Cave in Belgium; Refugio Cave), and come back in the wet season.

8. **Cave animals pick their spot in the cave by its temperature.**
   - **Hibernating bats:**
     - in North America they choose caves at 2 to 10 °C with 60 to 100% humidity (Perry 2012);
     - in Wales, Myotis bats sit at 2 to 5 °C, "often ... in crevices near entrances";
     - long-eared bats and barbastelles take cold, draughty spots near the mouth (−3 to 11 °C);
     - lesser horseshoe bats sit over 200 m in, where the temperature is steadier (BCRA Wales);
     - over a winter, bats move to colder spots, from about 12 °C in November to 6 °C by March.
   - **Brown bears:**
     - they den in natural caves and in dens they dig, and reuse natural cavities more;
     - a small den "allows greater thermal stability";
     - a den is laid out as entrance, tunnel and chamber, with the nest in the chamber (González-Bernardo et al. 2020).

9. **Fire inside a cave: the smoke goes along the ceiling and out of the mouth, and the hearth's position decides who chokes.**
   - At Lazaret Cave (France, 290 m²), smoke models showed that a hearth at the back lets smoke "circulate out of the cave right next to the ceiling". But the back is far from where people worked.
   - The real hearth sat in a 25 m² middle zone that balanced heat against smoke (Kedar, Barkai and Kedar 2022).
   - In Medina-Alcaide et al.'s cave tests, a fire "quickly polluted the site" with smoke. A torch lit an area about 6 m across. A fire lit about 3.3 m around it and gave almost nothing beyond 2 m.

## Judged numbers for our caves

### Temperature

- **Deep cave air** is the yearly mean at the mouth's height. Using climate.json (sea level 9.0 °C, 6.5 °C per km): 7.7 °C at 200 m, 5.5 °C at 533 m (cave 8002's floor), 4.9 °C at 627 m (cave 8003) and 2.5 °C at 1,000 m. Spells, seasons and the daily range do not reach it.
- **The entrance zone:**

  | From the mouth | Air in the cave |
  |---|---|
  | 0 to 10 m | outside air, with the daily swing halved |
  | 10 to 50 m | blends from outside air to the cave mean. In winter the outside reaches about 60 m in, and in summer up to 180 m (Andrassa), so 50 m is our middle |
  | past 50 m | the cave mean, ± 0.5 °C |

  A rule that fits the code: `cave_air = lerp(outside_air, cave_mean, smoothstep(10, 50, depth_m))`. `cave_sounds.gd` already keeps `depth_m`.
- **Wind chill in a cave:**
  - past the mouth, cut it to nothing: the air moves at a few cm/s;
  - at the mouth, keep a draught of 0.5 to 2 m/s in the direction the season sets (lesson 3).
- **Spring caves** have their mouth at the low end (the stream runs out), so they rise into the hill. Judged: they are warm traps, the reverse of a cold trap.
  - In summer, cold cave air drains out along the floor beside the stream, so the mouth breathes cool.
  - In winter, warm air is held up in the high back of the cave.
  - A spring cave never freezes deep in. Only a pit that drops below its entrance can hold ice.
- **Spring water** comes out at about the cave mean too.
  - The game's `cave_pool_c` of 2.0 °C is colder than any spring cave below about 1,000 m should be.
  - It is a fine game choice ("icy", BUG-008). But measured, the water would be the cave's temperature.

### Damp and drying

- In a cave, the humidity is 98 to 100%, falling to about 75% in a draughty mouth.
- Wet clothes do not dry in a cave unless there is a fire. Near the mouth they dry at about half the open-air rate.
- Rain and snow do not reach past the drip line at the mouth.

### Air at the mouth (look and feel)

- **Winter**, outside air 3 °C or more below the cave mean: a thin steam plume leaves the top of the mouth, and frost and icicles form on its lip. The cave air is saturated, so any colder outside air will do.
- **Summer**, outside air 5 °C or more above the cave mean and humid: a mist hangs under the ceiling of the first chamber, the walls near the mouth run wet, and drips come from condensation.
- **Weather fronts**: before a storm, as the pressure falls, the mouth blows out. It lasts hours, and a narrow mouth makes it stronger (judged).

### Daylight reach (for `weather_look.gd`)

| Spot | Share of outside light | Overcast day (10,000 lux) | What it looks like |
|---|---|---|---|
| Mouth, first 5 m | 10 to 30% | 1,000 to 3,000 lux | shade; colours still read |
| 10 to 20 m, mouth in view | 0.5 to 3% | 50 to 300 lux | dusk; grey shapes |
| 20 to 50 m, straight passage | 0.1 to 0.5% | 10 to 50 lux | deep dusk |
| After one bend | about 0.002 to 0.01% | 0.2 to 1 lux | moonlight; outlines only |
| After two bends, or past 100 m | none | under 0.01 lux | pitch black |

- At night the mouth's twilight zone is simply night. Under a full moon, the mouth gets about 0.2 lux, and one bend makes it black.
- **The eyes (lesson 6):**
  - going in, the light should drop within about 1 s, which `CAVE_GO_DARK_S` already does;
  - only where twilight light exists, a slow gain over 1 to 2 minutes could bring back some shapes. Cap it, so a pitch-black chamber stays black;
  - coming out, a short over-bright glare of 1 to 3 s that settles to normal is truer than a slow brighten.

### Drips (for `cave_sounds.gd`)

| Where | Drip interval | After rain |
|---|---|---|
| Under thin rock near the mouth (under about 15 m) | 2 to 10 s | faster within hours, and back to slow over 1 to 2 days |
| Deep under the hill (30 m of rock or more) | 10 to 60 s, steady | no change for weeks to months |
| Dry summer, thin rock | stops | — |
| Summer mouth in humid weather | condensation on the walls, drips every 5 to 30 s | — |

- Drips fall on the line of a crack, so they come in rows and clusters, not evenly over the roof.
- A drip leaves a wet spot and a small hollow or stalagmite under it, and the same spot drips every visit.

### Dens (for Steve and MikeW)

- A goblin den at the dead end is the darkest and steadiest spot. Day sleep there makes sense.
- The den's fire is a different matter.
  - Smoke rides the ceiling out to the mouth, and the den is choking.
  - Judged: a den fire's smoke shows as a thin grey stream at the top of the mouth. A player can read it as "someone lives here".
  - A smarter band keeps its fire in the middle, where the smoke clears overhead (Lazaret).
- Bears want a small chamber off the main passage, near enough to the mouth to dig in and out, in snow country on a slope facing south-east or south-west.
- Bats, if they come: some hang near a draughty mouth, others are 200 m or more in. They are never on the warm side of a den fire.

## Never-see checks

1. Daylight in a chamber two bends in with the "Dark" setting, or on any day past 100 m.
2. Frost, snow or ice deep inside a spring cave. Icicles belong only at the mouth's lip, in frost.
3. Clothes drying in a cave with no fire.
4. Rain soaking a player who stands in a cave, or a gust making the player colder 30 m in.
5. A deep cave that feels colder than outside on a freezing winter night. It should feel warmer than outside then. On a summer day it should feel cooler.
6. Drips evenly spread over the roof, or a deep chamber that drips harder the moment it rains outside.
7. A fire in a closed dead end with its smoke going nowhere.

## How ours works today (read from the code, 8 Nov, not tested)

- **Light:**
  - `weather_look.gd` dims sun, sky and ambient light by rock enclosure. Enclosure is measured with rays in `cave_sounds.gd` (`UP_M` 30, `WALL_M` 20). The fade runs from enclosure 0.1 to 0.6.
  - `CAVE_LIGHT_DARK` is 0. `CAVE_LIGHT_NORMAL` is 0.12, which keeps 12% of daylight deep in. That is far more than a real twilight zone gives.
  - It fades over `CAVE_GO_DARK_S` 1.0 going in and `CAVE_COME_OUT_S` 2.5 coming out.
  - The light comes from how enclosed the spot is, not from distance or bends. A long straight passage and a twisting one look the same.
- **Sound:**
  - Wind, weather and nature are muffled in a cave (`DROP_DB`, `MUFFLE_HZ` 1,800).
  - Drips play every 2.5 to 7 s (`DRIP_EVERY`) from enclosure 0.45. They play only in wet caves, and `wet` follows rain leaks.
- **Warmth (`server_items.gd` `warmth_target`):**
  - In a cave, the air is the outside air with the daily offset, minus the lapse with height. Full wind chill applies.
  - `cover_at` sees tree crowns and built roofs, not rock. So by the code, a player in a cave in the rain is "not covered". They soak (`_update_soak`) and feel the full wind. That breaks never-see check 4. It is worth a test on the PC.
  - Spring cave pools are fixed at 2.0 °C (`cave_pool_c`).
- **Goblins:** a band sleeps in its den by day. The den is within `den_m` (12 m) of the path's end. The band walks out at night. `cave_dressing.gd` gives a den fire one warm light. Smoke is not modelled.
- **Not modelled:**
  - the cave's own temperature;
  - air at the mouth (draught, steam, summer mist);
  - humidity;
  - dark adaptation of the eyes.

## Sources

- Pflitsch, A. and Piasecki, J. (2003), Detection of an airflow system in Niedzwiedzia (Bear) Cave, Kletno, Poland, Journal of Cave and Karst Studies 65(3): https://legacy.caves.org/pub/journal/PDF/V65/v65n3-Pflitsch.pdf
- Ventilation regime in a karstic system (Milandre Cave, Switzerland), arXiv 2304.12819: https://arxiv.org/pdf/2304.12819
- BCRA, Cave Life of Mendip, cave climate: https://bcra.org.uk/cavelife/mendips/climate.html
- BCRA, Cave Life of Wales, bats: https://bcra.org.uk/cavelife/wales/bats.html
- NCKRI, Cave environment: https://nckri.org/about-caves/cave-environment/
- NPS, What causes the wind of Wind Cave: https://www.nps.gov/wica/learn/education/what-causes-the-wind-of-wind-cave.htm
- Wikipedia, Ice cave (cold traps): https://en.wikipedia.org/wiki/Ice_cave
- Motta, M. and Motta, L. (2016), The caves with single entrance have a circulation "air bag style" really? (Andrassa, Liguria): https://iris.unito.it/retrieve/e27ce42a-fba4-2581-e053-d805fe0acbaa/The%20caves%20with%20single%20ent%20Quaesti%202016.pdf
- NewsNation, Cloud of fog forms in Mammoth Cave: https://digital-release.newsnationnow.com/?p=1660372
- ASF, Ecology of limestone caves (zones, twilight about 20 m): http://st1.asflib.net/MEDIA/ASF-CD/ASF-M-00219/cave%20ecosystems%20V2/caves/textcave/5acaveec.htm
- The blurred line between photic and aphotic environments: a large Mexican cave with almost no dark zone, International Journal of Speleology 47(1): https://digitalcommons.usf.edu/ijs/vol47/iss1/6/
- Medina-Alcaide et al. (2021), The conquest of the dark spaces: an experimental approach to lighting systems in Paleolithic caves, PLOS ONE: https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0250497
- Wikipedia, Adaptation (eye): https://en.wikipedia.org/wiki/Adaptation_(eye)
- Baker, A. and Fairchild, I. J. (2012), Drip water hydrology and speleothems, Nature Education Knowledge: https://www.nature.com/scitable/knowledge/library/drip-water-hydrology-and-speleothems-26394838
- Hydrological characterization of cave drip waters in a porous limestone: Golgotha Cave, Western Australia, HESS 22 (2018): https://hess.copernicus.org/articles/22/977/2018/
- Perry, R. W. (2012), A review of factors affecting cave climates for hibernating bats in temperate North America: https://digitalcommons.usf.edu/kip_articles/4967
- González-Bernardo, E. et al. (2020), Denning in brown bears, Ecology and Evolution: https://pmc.ncbi.nlm.nih.gov/articles/PMC7381752/
- Tel Aviv University via Phys.org (2022), Early humans placed hearth at optimal location in caves (Lazaret, Scientific Reports): https://phys.org/news/2022-02-early-humans-hearth-optimal-caves.html
