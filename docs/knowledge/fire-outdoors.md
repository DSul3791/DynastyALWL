# Fire outdoors: wood moisture, rain, wind, smoke drift and embers

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:**
- Kathleen: flames, smoke and sparks (`building_look.gd`).
- Steve: fire rules and warmth (`server_items.gd`, `data/items/cooking.json`).
- Dave: decides the rain rule and the burnt-fire timer. Both are on his open list.

**Related:** [torches-fire.md](torches-fire.md) (Dave's simple fire rules), [firelight-in-weather.md](firelight-in-weather.md) (light in fog, rain and snow), [wind-over-terrain.md](wind-over-terrain.md), [warmth-weather.md](warmth-weather.md), `cave-microclimate.md` (#664, smoke in caves).

## Lessons (read these first)

1. **Freshly cut wood is about half water. Dry wood gives about twice the heat.**
   - Wood is about 50% water when felled. Depending on storage it can be 30 to 65% (FAO).
   - Green moisture by species: ash 32%, the driest; Norway spruce 65% (Forest Research).
   - Moisture bands (Maine Forest Service): green is 36 to 50%, seasoned 20 to 36%, and dry is under 20%.
     - "Seasoned" means wood at the moisture of the surrounding air, about 20%.
     - Air drying to 20% is "likely to take two summers or more" (Forest Research).
     - Splitting logs to under 10 cm across lets them dry from the middle.
   - Heat:
     - completely dry wood gives 18 to 20 MJ/kg;
     - wood at 30% moisture gives about 13 MJ/kg, and at 50% about 8.5 (FAO);
     - "a fresh green log has only around half the energy content" of a seasoned one (Forest Research).
   - Wet logs give "a fire that smoulders and creates lots of tars and smoke" (Forest Research).

2. **Small dead wood dries in hours. Logs take weeks.** The fire services sort dead wood by how fast it reaches 63% of the way to the air's moisture (the "timelag"):

   | Class | Thickness | Response |
   |---|---|---|
   | 1 hour | under 6 mm (twigs, grass, needles) | under 2 h |
   | 10 hour | 6 to 25 mm (sticks) | 2 to 20 h |
   | 100 hour | 25 to 76 mm (thick branches) | 20 to 200 h |
   | 1,000 hour | over 76 mm (logs) | over 200 h |

   - Sources: Forest Encyclopedia Network; Northwest Fire Science Consortium.
   - Bark slows it: wood with bark gains and loses moisture at about 2/3 the rate.
   - Rotten wood takes up and gives off water faster.
   - North-facing slopes and high ground stay wetter (Forest Encyclopedia Network).
   - Dead fuel under 30% moisture "is essentially considered to be dead and highly flammable" (Northwest Fire Science Consortium).
   - Grass still lights well above that. In a Mediterranean grass study, half of the lighting tries took at 38.5% moisture, and almost none at 55.5% (Dimitrakopoulos et al. 2010).

3. **Rain kills a young fire. A big fire on a bed of coals lives through a downpour.**
   - Birch bark lights wet or dry: it "includes oil that repels moisture". Dry tinder is found under shrubs, at the foot of trees and inside split wood (AMC).
   - The rule in the rain is "speed" and a stockpile of fuel gathered first. A shield (a body, or a tarp held high) carries a small fire until it can "stand on its own" (AMC; BladeForums).
   - Woodsmen's experience (BladeForums):
     - "Keep it big!", with the coals under the larger logs;
     - a large fire with a coal bed "survives a downpour with a little protection";
     - a tipi lay sheds water;
     - sound logs shed rain onto the fire, while rotten logs soak it up like a sponge.

4. **Embers outlast the flames by hours.**
   - Fire pits "retain heat up to 12 hours after being extinguished". "70% of Campfire burns are caused by embers rather than flames" (UTMB).
   - Embers can relight a fire "up to 12 hours after it goes out", if air can reach them (Wikipedia, Ember).
   - The glow is slow combustion without a flame (Wikipedia, Ember).
   - The fire services say "never bury a fire": buried coals stay hot and hidden (UTMB).

5. **Wind feeds a fire and carries its sparks.**
   - In wildfires, embers can be "blown far ahead of the fire front, starting spot fires several kilometres" away (Wikipedia, Ember). A campfire's sparks are much smaller, so this is the far upper bound.

6. **Smoke rises on the fire's heat, bends with the wind, and lies flat on still nights.**
   - **How far the plume lifts**, using Briggs' two-thirds law: rise Δh = 1.6 × F^(1/3) × x^(2/3) ÷ u. Here F = 8.8 × 10⁻⁶ × heat in watts (NOAA ARL; MetricGate), x is the distance downwind and u is the wind speed.
   - **The air's layering decides the plume's shape** (NSW EPA):
     - **looping** in strong sun and wind over 10 m/s;
     - **coning** in cloudy or windy weather;
     - **fanning** (a thin flat layer) under a night inversion with light wind and clear sky;
     - **fumigation** (smoke pulled down to the ground) on clear, light-wind mornings.
   - **At night:**
     - inversions form in the late afternoon or evening, and last until about 8 to 10 am;
     - cold air drains downslope into valleys and carries smoke "often quite effectively" across a region (NSW EPA);
     - "in a stable atmosphere, smoke ... will stay near the ground". Hot fires can loft partly through it (Forest Encyclopedia Network).
   - **Smoke "follows you"** because the fire's rising air pulls air in from all round. A person blocks that inflow, leaving a low-pressure pocket that draws the smoke to them (Kerry Anderson, Canadian Forest Service, CTV News).
   - **Smoke colour:**
     - juniper and oak gave white smoke;
     - pine resin and birch bark gave thick black smoke;
     - a flame within 5 cm of rock leaves soot (Medina-Alcaide et al. 2021).

7. **A small open fire burns about 2 kg of wood an hour.**
   - In Medina-Alcaide et al.'s cave tests, 500 g of juniper and 400 g of oak kept a fire going "for at least 30 minutes".
   - It lit about 3.3 m around it, with almost nothing beyond 2 m.

## Our sums and judged numbers

### Heat and burn time

| Fire | Wood per hour | Heat (at 15 MJ/kg) | Plume buoyancy F |
|---|---|---|---|
| Small (sticks, our "weak") | about 2 kg | about 7.5 kW | 0.066 m⁴/s³ |
| Medium (3 or more firewood) | about 4 kg | about 17 kW | 0.15 |
| Large (3 or more logs) | about 10 kg | about 40 kW | 0.37 |

- Dave's real-time burn times in `cooking.json` sit inside the real range:
  - a stick lasts 2 real minutes;
  - a bolt of firewood lasts 20 real minutes, where a real 1 to 2 kg split bolt burns in 30 to 60 minutes;
  - a log lasts 3 real hours, where a real 10 to 20 kg log burns in 2 to 5 hours.

### Smoke height downwind (our sums, Briggs)

Height the smoke has risen above the flames, in metres:

| Wind | Small, 10 m downwind | Medium, 10 m | Large, 10 m | Large, 30 m |
|---|---|---|---|---|
| 1 m/s (near calm) | 3.0 | 3.9 | 5.3 | 11 |
| 2 m/s | 1.5 | 2.0 | 2.7 | 5.5 |
| 5 m/s | 0.6 | 0.8 | 1.1 | 2.2 |
| 10 m/s | 0.3 | 0.4 | 0.5 | 1.1 |

- **What the table means:** above about 2 m/s, campfire smoke is at head height 10 m downwind. A player downwind of a fire walks through it. In a near calm it rises as a column.
- **Night:** on a still, clear night the column rises a few tens of metres and then spreads flat at the inversion (fanning). Before dawn the flat layer drifts downhill with the cold drainage air, 1 to 3 m/s along the valley floor (`wind-over-terrain.md`). Judged: smoke from a valley camp pools in the hollow below by morning.
- **Seeing a fire from far off (judged):** a calm morning column can be seen 2 to 5 km away. In wind it is a low grey smear seen only within a few hundred metres. A goblin or a player could read a still-morning column as "a camp is there".

### Wood moisture (an option for Dave, not built)

- Sticks picked up after rain dry in hours, and firewood in a day or two. A log stays wet for days to weeks (lesson 2).
- If wood ever carries a wet flag:
  - wet sticks light at about half the chance;
  - wet firewood burns at about 2/3 of its heat, with thick white-grey smoke;
  - a wet log on a good coal bed dries and catches in 10 to 20 minutes.
- Fuel kept under a roof or a tree crown stays dry.

### Rain on a fire (Dave's call)

- Dave's rule today is that rain puts a fire out in seconds. It is simple, and it was chosen on purpose.
- Judged, what real fires do, if Dave wants it:

  | Fire | Light rain | Heavy rain |
  |---|---|---|
  | Small (weak tier) | lives, smoking | out in 1 to 3 minutes |
  | Medium | lives | drops a tier every 10 to 20 minutes |
  | Large, on coals | lives | lives through a downpour, out only after an hour or more of heavy rain |

  A roof or a tree crown over the fire counts as cover.

### Embers after the flames (Dave's open question on the 5 minute burnt fire)

- **Judged:**
  - glowing coals for 1 to 3 hours after the last flame (game time);
  - warm ash that relights with tinder alone for up to about 12 hours;
  - then cold.
- **What it could look like:** a dim red light of about 1 m, no flame, a thin wisp of smoke, and warmth only within 1 m.
- **What it means for play:** a camp found with warm ash says someone was there recently.

### Wind on a fire (judged)

- **2 to 5 m/s:** the fire burns about 1.2 to 1.5 times faster, the flames lean downwind, and sparks carry 2 to 5 m.
- **Over 10 m/s:** lighting fails without a windbreak, about half the time. Sparks carry 5 to 20 m, and flames lean almost flat.
- **Fire spread:** none from a campfire in the current game. A spark landing on dry grass would be the first step, if fire spread is ever wanted.

## Never-see checks

1. Campfire smoke rising straight up in a strong wind, or blowing upwind.
2. A fire with no smoke at all. Today the campfire has sparks but no smoke (below).
3. Sparks rising straight up in a gale.
4. A big log fire with a deep coal bed dying in the first seconds of a shower, if Dave ever moves off the simple rule.
5. A fire that was roaring a minute ago leaving cold, grey nothing.
6. Smoke rising on a still clear night to the top of the sky. It should flatten at a few tens of metres.

## How ours works today (read from the code, 8 Nov, not tested)

- **Fire tiers** (`cooking.json` `fire_tiers`):
  - weak: light 3.5 m, heat 10 °C within 2.5 m;
  - firewood: light 7 m, heat 20 °C within 4 m;
  - log: light 14 m, heat 40 °C within 5 m.
  - A tier needs 3 pieces (`min_pieces`).
- **Burn times:** real time, set by Dave on 1 Nov. A stick lasts 2 real minutes, firewood 20 and a log 3 real hours. The game clock runs at 24:1.
- **Rain:** `rain_light_chance` makes lighting fail in light rain (`puts_out` 0.2, `loss` 0.8, `min_chance` 0.2). Rain over 0.2 puts a fire out in seconds. A burnt-out fire is deleted after 5 minutes (Dave's open list).
- **Wood:** any wood counts the moment it goes in, with no wet or dry state.
- **The look** (`building_look.gd` `fire()`): a fire is coals, flame cards, ember sparks (`_ember_sparks`, lifetime 1.8 s, gravity +0.25 up) and one omni light. There is no smoke on campfires. The sparks do not follow the wind.
- **Forges:** the forge model hooks (`add_hooks`) do have a smoke plume (`_smoke_plume`). It has 14 particles, a 5 s life, and a fixed sideways drift of `gravity` (0.25, 0.1, 0), not the wind.
- **Wind for the look** is already on the client (`wind_cue.gd`, `tree_wind.gd`), so smoke and sparks could take the wind's direction and strength from there.

## Sources

- FAO, wood as a fuel, heating values by moisture: https://www.fao.org/4/P2396E/p2396e03.htm
- Forest Research, Wood as fuel guide: https://cdn.forestresearch.gov.uk/2022/02/fr-bec-wood-as-fuel_v2.pdf
- Forest Research, Wood as fuel technical supplement (green moisture by species): https://cdn.forestresearch.gov.uk/2022/02/fr_bec_wood_as_fuel_technical_supplement_2010.pdf
- Maine Forest Service, green and seasoned firewood chart: https://www.maine.gov/DACF/mfs/projects/woodheatmaine/downloads/greenandseasonedfirewoodchart2.pdf
- Forest Encyclopedia Network, Dead woody fuel timelag classes: https://forestencyclopedia.net/p/p523/
- Forest Encyclopedia Network, Factors regulating the moisture content of dead fuels: https://forestencyclopedia.net/p/p519/
- Northwest Fire Science Consortium, What is fuel moisture content: https://archive-nwfsc.forestry.oregonstate.edu/sites/default/files/publications/FuelMoistureContent.pdf
- Dimitrakopoulos, Mitsopoulos and Gatoulas (2010), Assessing ignition probability and moisture of extinction in a Mediterranean grass fuel, International Journal of Wildland Fire: https://publish.csiro.au/wf/WF08124
- AMC Outdoors, Maintain a fire during a rainstorm: https://oldprod.outdoors.org/?p=12595
- BladeForums, Keeping fire going when it's raining: https://www.bladeforums.com/threads/keeping-fire-going-when-its-raining.438819
- UTMB Health, Campfire safety: cool the coals: https://www.utmb.edu/news/article/health-blog/2023/07/17/campfire-safety-cool-the-coals
- Wikipedia, Ember: https://en.wikipedia.org/wiki/Ember
- NOAA ARL, Rise equations (buoyancy flux): https://ready2.arl.noaa.gov/documents/TutorialX/files/Rise_equations.pdf
- MetricGate, Briggs plume rise (two-thirds law): https://metricgate.com/docs/briggs-plume-rise/
- NSW EPA, Local government air quality toolkit, meteorology and air quality (plume types, inversions, drainage): https://www.epa.nsw.gov.au/sites/default/files/240162localgovernmentairqualitytoolkitmodule1scienceofairqualitypart1meteorologyairquality.pdf
- Forest Encyclopedia Network, smoke and atmospheric stability: https://forestencyclopedia.net/p/p776
- CTV News (2022), The science behind why smoke seems to follow you around a campfire: https://www.ctvnews.ca/sci-tech/the-science-behind-why-smoke-seems-to-follow-you-around-a-campfire-1.5913790
- Medina-Alcaide et al. (2021), The conquest of the dark spaces: an experimental approach to lighting systems in Paleolithic caves, PLOS ONE: https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0250497
