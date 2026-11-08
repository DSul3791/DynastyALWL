# Underground climate: cave air by depth and season, draughts, damp, and where a torch is needed

**Last checked:** 2026-11-08 (Jamie; web research plus our sums). **Owners:**
- Steve: cave warmth and drying (`server_items.gd` `cave_mean_c`, #667).
- Kathleen: cave light and the mouth's look (`weather_look.gd`, `cave_sounds.gd`).
- Sonny: cave shape and placement.

**Related:** [cave-microclimate.md](cave-microclimate.md) (read it first: this page adds numbers to it and does not repeat it), [caves.md](caves.md), [torches-fire.md](torches-fire.md), [warmth-weather.md](warmth-weather.md), `moonlight-starlight.md` (#679), `one-sky.md` (#706).

## Lessons (read these first)

1. **Rock damps the year's swing fast, and delays it.**
   - Heat moves through the ground by conduction. The swing at depth z falls as e^(−z/d), where the damping depth is d = √(κ × period ÷ π) (the heat conduction equation, *Rain or Shine* 13.4).
   - The same page gives d = 224 cm for the year's wave in soil with κ = 0.5 × 10⁻⁶ m²/s. Rock conducts better: κ is about 1 to 1.5 × 10⁻⁶ m²/s (judged, typical for limestone and granite), so d is about 3.2 to 3.9 m.
   - The lag grows as z ÷ d × (period ÷ 2π), which is about 58 days per damping depth.
   - **Our sums** (κ 1 × 10⁻⁶ m²/s, d 3.2 m):

     | Rock above or around | Share of the outside year's swing | Lag |
     |---|---|---|
     | 1 m | 73% | 18 days |
     | 2 m | 53% | 37 days |
     | 5 m | 21% | 3 months |
     | 10 m | 4% | half a year |
     | 15 m | 1% | 9 months |
     | 20 m or more | none worth counting | — |

   - This fits the field rule on [cave-microclimate.md](cave-microclimate.md) lesson 1: past about 11 m, caves vary by less than 1 °C.
   - At 10 m the little swing that is left is half a year late. The deep rock is at its warmest in late winter.

2. **In a cave, moving air carries the season further in than conduction does.**
   - Andrassa: the outside reached 180 m in in summer and 60 m in winter (Motta and Motta 2016, on [cave-microclimate.md](cave-microclimate.md)).
   - So the entrance zone is set by draughts, not by the rock. Lesson 1 gives the deep cave's tiny swing; lessons 3 and 4 give the mouth.

3. **Our caves are too small to breathe with the weather.**
   - A barometric cave blows out when air pressure falls and draws in when it rises. Its airflow speed "is directly correlated with the atmospheric pressure difference" between the cave and outside (Wikipedia, breathing cave; Gomell and Pflitsch 2022). Wind Cave's walk-in entrance has been clocked at over 70 mph (31 m/s) (NPS).
   - **Our sums:** the air that leaves is the cave's volume × the pressure change ÷ the pressure.
     - A pressure fall of 1 hPa an hour is a steady drop; 3 hPa an hour is a fast storm.
     - Cave 8002 (230 m of passage, about 2,300 m³): 0.6 to 1.9 litres a second. Through a 3 × 3 m mouth that is 0.1 to 0.2 mm/s. Nothing you could feel.
     - It takes about a million cubic metres behind a 0.1 m² crack to give 3 to 8 m/s. Wind Cave is one of the ten longest caves in the world (Wikipedia), and less than 10% of it has been found (NPS). That is why it howls.
   - So the judged line "before a storm the mouth blows out" on [cave-microclimate.md](cave-microclimate.md) holds only for a very large cave. It is now marked that way there.

4. **A one-entrance cave swaps air at its mouth in two layers, slowly.**
   - **Our sums** (density-driven exchange flow, speed about ½ × √(g × ΔT ÷ T × mouth height)):
     - a 3 m mouth with the outside 5 °C off the cave: about 0.35 m/s;
     - with 10 °C off: about 0.5 m/s;
     - a 5 m mouth with 10 °C off: about 0.65 m/s.
   - The colder air runs along the floor and the warmer along the roof.
     - In winter, cold air creeps in along the floor and the cave's air leaves under the roof.
     - In summer, the cave's cold air drains out along the floor, and warm air enters under the roof.
   - This fits the measured "a few cm/s, rarely over 1 m/s" inside caves, and the draught of 0.5 to 2 m/s at the mouth already on [cave-microclimate.md](cave-microclimate.md).
   - **Two entrances at different heights** (the chimney): the pull is ρ × g × height gap × ΔT ÷ T.
     - A 30 m gap with 10 °C off gives 13 Pa. Without friction that is 4.6 m/s.
     - Passage friction cuts it to a fraction of that (judged). Milandre's measured flow was up to 3 m³/s.

5. **Which way the cave runs decides which season gets in.**
   - **A cave that rises from its mouth** (most spring caves, including 8002, judged from the stream running out):
     - summer air is warm and light, so it enters under the roof and climbs in. The season reaches far;
     - winter air is cold and heavy, so it only pools a short way inside the floor of the mouth.
   - **A cave that drops from its mouth** (a pit or a descending passage): the reverse. Winter cold sinks in and stays, which is the cold trap and ice cave of [cave-microclimate.md](cave-microclimate.md) lesson 3.

6. **Winter air dries the mouth; summer air wets it.**
   - **Our sums** (saturation vapour, Magnus formula):
     - saturated air holds 3.4 g/m³ at −5 °C, 4.9 at 0 °C, 7.0 at 5.5 °C, 9.4 at 10 °C and 12.8 at 15 °C;
     - winter: outside air at 0 °C and 90% humidity, warmed to 5.5 °C in the mouth, falls to 62%. At −5 °C it falls to 44%;
     - summer: outside air at 15 °C and 80%, cooled to 5.5 °C, must drop 3.2 g of water per cubic metre. That is the summer mist and the wet walls.
   - So a winter cave mouth with cold air coming in is the one dry place in a cave. This fits BCRA's "about 75% near entrances with draughts".
   - Deep in, the air stays at 98 to 100% all year.

7. **Daylight in a passage falls off with distance and with every turn.**
   - The light-zone table and the bend rule are on [cave-microclimate.md](cave-microclimate.md) lesson 5. This page turns them into "where do I need a torch".
   - We take 1 lux as the point where a torch is needed on rough cave floor (judged). The full moon gives 0.25 lux on open ground (`moonlight-starlight.md`, #679), and a cave floor is rougher and has no sky glow.

## Judged numbers for Steve (#667) and Kathleen

### Cave air

- **Deep cave** (more than 50 m in, or past the second bend): the year mean at the height, `Climate.year_mean_c`. That is 9.0 − 6.5 × 0.533 = **5.5 °C** at cave 8002 (floor 533 m) with the starter climate. #667 already does this.
  - **Optional small swing:** ±0.5 °C (a tenth of `seasonal_swing_c` 5.0), half a year late. So deep air is warmest at year phase 0.875 (0.375 + 0.5), in late winter. Leaving it flat is also fine: no one can feel 0.5 °C.
- **The entrance zone:** blend from the outside air to the deep air with distance in from the mouth.
  - `cave_air = lerp(outside_air, deep_air, smoothstep(near_m, reach_m, depth_m))`.
  - Outside air here is the day's air (`Weather.air_c`), with the day and night swing halved inside the first 10 m.

  | Cave runs | Season (outside vs. cave) | near_m | reach_m |
  |---|---|---|---|
  | Rises from the mouth (8002) | outside warmer (summer) | 10 | 60 |
  | Rises from the mouth (8002) | outside colder (winter) | 5 | 20 |
  | Drops from the mouth (a pit) | outside colder (winter) | 10 | 60, and the deep air there may fall below the year mean |
  | Drops from the mouth (a pit) | outside warmer (summer) | 5 | 20 |
  | Level or not known | either | 10 | 40 |

- **What `depth_m` is:** the distance in from the nearest cave opening along the passage. `cave_sounds.gd` keeps a walked `depth_m` on the client. On the server, the straight distance to the nearest `cave_openings` point in `tile_terrain_data.gd` is close enough for a first pass (judged).

### Draught (wind chill in a cave)

- **Mouth (the first 10 m):** a draught of 0.3 to 0.6 m/s when the outside is 5 to 10 °C off the cave, from lesson 4. In wind-chill terms that is nothing to small. Keep the outside wind out.
- **Past 10 m:** no wind.
- **Before a storm:** no change for caves our size (lesson 3).
- **A cave with two entrances and a big height gap:** a steady through-draught of 1 to 3 m/s in the narrow parts (judged), up the cave in winter and down it in summer.

### Damp and drying

- **Past 20 m:** 98 to 100%. Only a fire dries you (#667 already does this).
- **Mouth in winter** (outside 3 °C or more colder than the cave): the incoming air is dry. Drying under cover there can run at half `dry_cover_per_h` (judged, from lesson 6).
- **Mouth in summer** (outside 5 °C or more warmer and humid): condensation. No drying, walls wet, and a mist under the roof.

### Where a torch is needed

**Our sums** for a 3 × 3 m mouth and a straight passage that wanders gently: the share of outside light is min(0.3, 9 ÷ (π × depth²)) × e^(−depth ÷ 40). The 40 m stands in for the passage's slow twists (judged). A torch is needed where that is under 1 lux.

| Outside light | Torch needed past |
|---|---|
| Bright day (20,000 lux of skylight) | 85 m |
| Overcast day (10,000 lux) | 70 m |
| Dark overcast or heavy rain (3,000 lux) | 50 m |
| Very dull day (1,000 lux) | 35 m |
| Sunset (about 400 lux) | 25 m |
| Late dusk (100 lux) | 15 m |
| Night, even under a full moon | the mouth |

- **A sharp bend** ends the daylight on its own. Past the first sharp bend, a torch is needed on anything but a bright day. Past the second, always.
- **For 8002** (230 m, west): the back two-thirds of the passage needs a torch at any hour.
- The torch on main gives 3.5 lux at 1 m and 0.035 lux at 10 m (`moonlight-starlight.md`, #679), so a carried torch lights about 2 m of floor well, which fits caves.

## Never-see checks

- a deep cave that is warmer in summer than in winter by more than 1 °C;
- wind you can feel 20 m into a one-entrance cave;
- a storm that makes a small cave's mouth gust;
- clothes that dry in a cave with no fire, except slowly at a winter mouth;
- daylight in a passage past the second bend, or bright enough to read 100 m in;
- summer mist forming deep in, instead of in the first chamber and under the roof.

## How ours works today (read from the code, 8 Nov, not tested)

- On main, cave air is not separate: warmth uses the weather outside. #667 (Steve's, open) adds:
  - `tile_terrain_data.in_cave(p)`: inside a carved passage or chamber with 2 m or more of roof;
  - `server_items.gd` `cave_mean_c`: the year mean at the height inside a cave, with no day swing, rain or wind, and no drying without a fire;
  - a cave pool's water at that same air temperature, in place of `cave_pool_c` 2.0.
- #667 has no entrance zone. Air jumps from the outside to the year mean at the line where `in_cave` turns true. The blend above would smooth that.
- `cave_sounds.gd` walks a `depth_m` while `rock_enclosure` is 0.5 or more, which could serve as the depth on the client.
- No draught, no mouth humidity and no seasonal breathing in the code.

## Sources

- *Rain or Shine*, 13.4 Sub-Surface Soil Temperatures (Oklahoma State University open textbook): damping depth d = √(α × period ÷ π), amplitude falling as e^(−z/d), the lag equation, d = 224 cm for the annual wave at α = 0.5 × 10⁻⁶ m²/s. https://open.library.okstate.edu/rainorshine/chapter/13-4-sub-surface-soil-temperatures/
- Wikipedia, Breathing cave: airflow "directly correlated with the atmospheric pressure difference", and the list of breathing caves. https://en.wikipedia.org/wiki/Breathing_cave
- Gomell, A. K. and Pflitsch, A. (2022). How do barometric caves breathe? *International Journal of Speleology* 51(3): airflow follows pressure gradients; Jewel Cave reacts more slowly than Wind Cave. https://digitalcommons.usf.edu/ijs/vol51/iss3/1
- NPS, What causes the wind of Wind Cave: winds over 70 mph at the walk-in entrance, and less than 10% of the cave found. https://www.nps.gov/wica/learn/education/what-causes-the-wind-of-wind-cave.htm
- The cave field figures (under 1 °C past 11 m, Milandre, Andrassa, BCRA humidity, daylight zones) are sourced on [cave-microclimate.md](cave-microclimate.md).
- Our sums: the depth table, the exchange-flow and chimney speeds, the barometric volumes, the vapour figures (Magnus formula), and the torch table. The script is simple enough to redo by hand from the formulas above.
