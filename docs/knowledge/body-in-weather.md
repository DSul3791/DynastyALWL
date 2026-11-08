# The player's body in weather: wet clothes, drying, hypothermia, wind chill, shelter and food sickness

**Last checked:** 2026-11-08 (web research by Jamie). **System owner:** Steve (warmth, `data/items/warmth.json`, `src/stream/server_items.gd`). **For Dave's open questions:** wet clothes and raw-meat sickness. **Related:**
- [warmth-weather.md](warmth-weather.md): the game's warmth model and other games;
- [cave-microclimate.md](cave-microclimate.md): cave air, about 5.5 °C at cave 8002;
- [fire-outdoors.md](fire-outdoors.md): fire size, embers and rain;
- [wind-over-terrain.md](wind-over-terrain.md): the shared wind mapping, m/s = 20 × wind^1.3;
- `CONTRADICTIONS.md` (#690).

"Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found today. One game day is about one real hour (2.5 real minutes per game hour).

## Lessons (read these first)

1. **Wet plus wind is what kills, not cold alone.**
   - **The Four Inns Walk, 1964:** three walkers died on the Pennine moors in "30 mph winds, heavy rain, and temperatures from 0 to 7 °C". Griffith Pugh's study of the deaths found that "a combination of wet and windy conditions could reduce the thermal properties of clothing to nearly nothing", and fatigue and hypothermia fed each other (Wikipedia, "Four Inns Walk").
   - **The "Wet Walk" experiments** (University of Victoria, under John Hayward): walkers in cotton-based clothing walked in about 5 °C air, very heavy artificial rain and an 8 km/h wind.
     - Most kept their core above 36 °C for 2 hours, though they "often exhibited signs and symptoms of 'hypothermia'".
     - A walker with low fitness reached 35.2 °C while still walking.
     - One subject's core "dropped 1.4°C to 35.3°C in less than 30 minutes" after about 3 hours: the collapse comes late and suddenly.
     - Sitting in the wet clothes afterwards, core fell about 0.35 to 0.9 °C in an hour.
   - **Wet clothing on its own, without much wind, costs less than people think.** With a wet mid layer under protective clothing, total insulation fell 16% while walking and 9% standing, at 0.5 m/s of air (Bröde, Havenith et al. 2008, Eur. J. Appl. Physiol.). It is the wind pumping through wet cloth that takes the insulation down to "nearly nothing".

2. **Hypothermia comes in stages by core temperature** (MSD Manual, after the Swiss staging):

   | Stage | Core | What you see |
   |---|---|---|
   | Mild (Swiss 1) | 32 to 35 °C | conscious and shivering |
   | Moderate (Swiss 2) | 28 to 32 °C | drowsy or confused, shivering stops |
   | Severe (Swiss 3) | 24 to 28 °C | unconscious |
   | Profound (Swiss 4 to 5) | under 24 °C | apparent death |

   The ranges overlap. The sign that matters most for a player is that **shivering stops** when it gets worse, not better.

3. **Wind chill**, by the NWS and Environment Canada formula of 2001, for exposed skin: WCT = 13.12 + 0.6215 T − 11.37 V^0.16 + 0.3965 T V^0.16. T is in °C, V is the wind in km/h at 10 m, and the formula holds for T at or below 10 °C and V over 4.8 km/h. **Our sums:**

   | Air | 5 km/h (1.4 m/s) | 10 (2.8) | 20 (5.6) | 30 (8.3) | 40 (11.1) | 60 (16.7) |
   |---|---|---|---|---|---|---|
   | 10 °C | 9.8 | 8.6 | 7.4 | 6.6 | 6.0 | 5.1 |
   | 5 °C | 4.1 | 2.7 | 1.1 | 0.1 | −0.7 | −1.8 |
   | 0 °C | −1.6 | −3.3 | −5.2 | −6.5 | −7.4 | −8.8 |
   | −5 °C | −7.3 | −9.3 | −11.6 | −13.0 | −14.1 | −15.7 |
   | −10 °C | −12.9 | −15.3 | −17.9 | −19.5 | −20.8 | −22.6 |

   - **The game's wind:** on the shared mapping, game `wind` 0.3 is about 15 km/h, 0.5 about 29 km/h and 0.7 about 45 km/h.
   - **Size of the chill:** at the starter's temperatures (0 to 10 °C), a strong wind takes 5 to 9 °C off bare skin.
   - **Caveat:** the index is for the face. A clothed body loses less, unless the clothes are wet (lesson 1).

4. **Fibres hold water differently, and so they dry differently.**
   - **Moisture regain** at 65% humidity and 20 °C (Morton and Hearle, *Physical Properties of Textile Fibres*, via a fibre comparison page):
     - wool 13 to 18%;
     - linen 10 to 12%;
     - cotton 7 to 8.5%.
   - **Wool:** takes up about a third of its weight in water "before feeling wet". It holds the water inside the fibre, so it still traps air and feels warm when damp. It also gives off a little heat as it takes up water (general knowledge, not checked today). It is slow to dry.
   - **Linen:** wicks and dries fast: linen towels in 30 to 45 minutes against 2 to 4 hours for cotton terry (a trade figure on the same page). Wet linen against the skin is cold, because it holds the water on the surface.
   - **Leather:** soaks slowly, dries very slowly, and stiffens or cracks if dried hard by a fire. Greased leather sheds water (general knowledge, not checked today).

5. **Food sickness: the onset time tells you the cause** (Washington State Department of Health, foodborne illness chart):

   | Cause | Onset | Lasts | Medieval source |
   |---|---|---|---|
   | *Staphylococcus* toxin | 1 to 6 h | 1 to 2 days | meat and food left out unrefrigerated |
   | *Bacillus cereus* (vomiting toxin) | 1 to 6 h | 1 day | cooked grain or meat kept warm |
   | *Clostridium perfringens* | 8 to 16 h | 1 to 2 days | stews and gravies kept warm, "time and temperature abused" (the pottage pot) |
   | Scombroid (histamine) | under 3 h | 3 to 6 h | spoiled oily sea fish |
   | Vibrio | 12 to 24 h | 2 to 5 days | raw shellfish and fish |
   | Norovirus | 12 to 48 h | 12 to 60 h | food or water fouled by people, shellfish |
   | Botulism | 12 to 36 h | days to months | sealed or fermented fish, preserved food |
   | Salmonella | 1 to 3 days | 4 to 7 days | eggs, raw milk, raw meat |
   | Campylobacter | 2 to 5 days | 2 to 10 days | raw poultry, raw milk, bad water |
   | *E. coli* O157 | 2 to 6 days | 5 to 10 days | undercooked beef, raw milk, bad water |
   | Cryptosporidium | 5 to 8 days | weeks, comes and goes | bad water |
   | Giardia | 7 to 10 days | days to weeks | bad water |
   | Hepatitis A | about 30 days (15 to 50) | 2 weeks to 3 months | food or water fouled by people |

   - **Anisakis worm** (raw sea fish such as mackerel, salmon and trout): intense stomach pain, "frequently ... within eight hours". It is killed by 60 °C for 1 minute, or by freezing at −20 °C for 24 hours (Tokyo Metropolitan Government).
   - **Trichinella** (bear, boar, pork): in a 2023 outbreak from undercooked black bear meat, 10 of the 22 people who ate it (45%) became probable cases. The median onset was **21 days** (7 to 26), with facial swelling, muscle pain and fever. Cooking to 74 °C kills it, and freezing "might not be sufficient" (CDC, MMWR 73(40), 2024).

## Judged numbers for the game

### Heat loss by clothing state (multiplier on the cold stress)

Against dry clothes in still air, judged from lessons 1 and 4:

| Clothes | Still air | Wind 0.3 or more | Wind 0.6 or more |
|---|---|---|---|
| Dry wool | 1.0 | 1.2 | 1.4 |
| Damp wool (soak 0.3 to 0.6) | 1.1 | 1.4 | 1.8 |
| Soaked wool (soak over 0.6) | 1.2 | 1.7 | 2.5 |
| Dry linen | 1.2 | 1.5 | 1.8 |
| Soaked linen | 1.6 | 2.5 | 3.5, almost no insulation (Pugh) |
| Leather over wool (jerkin, boots) | 0.9 | 1.0 (cuts the wind) | 1.2 |

- **Wool damp** is the forgiving case and **linen soaked in wind** is the dangerous one. That gives a real reason to choose wool over linen for the hills.
- **Today the game has one rain multiplier** (`rain_mult` 1.5, scaled by soak) and no clothing types yet (`max_insulation` 0.85 is the hook).

### Drying time from soaked to dry

Times are in game hours, judged. The real hours are the same number; at game speed, one game hour is 2.5 real minutes.

| Where | Linen shirt | Wool tunic | Wool cloak | Leather boots |
|---|---|---|---|---|
| Worn, by a fire at 1.5 m | 0.5 to 1 | 2 to 3 | 3 to 5 | 6 to 10 (too close and they crack) |
| Hung by a fire | 0.5 | 1.5 to 2 | 3 to 4 | 8 to 12 |
| Sun and a breeze, 15 °C | 1 to 2 | 3 to 5 | 5 to 8 | 12 to 24 |
| Wind, overcast, 8 °C | 2 to 4 | 6 to 12 | 12 to 24 | 2 to 3 days |
| Worn under a roof or lean-to, no fire | 3 to 5 | 8 to 12 | dries slowly, a day | days |
| In a cave, no fire (98 to 100% humid air) | does not dry | does not dry | does not dry | does not dry |
| Packed in a bag | does not dry; mildews in 2 to 3 days | the same | the same | the same |

- **Against today's game:**
  - `dry_fire_per_h` 6 dries you from soaked in about 10 game minutes by a fire;
  - `dry_cover_per_h` 1 takes about an hour under cover.
- **Real wool** takes 2 to 3 hours by a fire, and most of a day under a roof. If Dave wants it real, use 0.4 an hour by a fire and 0.1 an hour under cover for wool, and about twice that for linen. That also gives the "clothes stay damp about an hour after rain" item (DAVE_TODO 7) a real basis.

### How fast the stages come

Core temperature fall, judged from lesson 1:

| Conditions | Walking | Resting or sitting |
|---|---|---|
| 15 °C, dry, light wind, any clothes | none | none overnight (a little chilled by morning without a fire) |
| 10 °C, dry, wool | none | about 0.1 °C an hour, uncomfortable, no hypothermia |
| 5 °C, rain, wind 0.3 to 0.5, wool | holds about 36 °C for 3 to 5 h, then a sudden fall as fatigue sets in | 0.5 to 1 °C an hour: mild (35 °C) in 2 to 4 h, moderate (32 °C) in 5 to 8 h |
| 5 °C, rain, wind 0.5 or more, soaked linen | holds 2 to 3 h, then a fast fall (1.4 °C in 30 min, Wet Walk) | 1 to 2 °C an hour: mild in 1 to 2 h, moderate in 3 to 4 h |
| 0 °C, wet, gale | 1 to 2 h | mild within an hour |
| In water at 10 °C | — | dangerous within 30 to 60 minutes (judged; the game's swim chill handles it) |

**Mapping to the warmth bar** (judged, if Steve wants stages): warmth 40 to 100 is normal, 20 to 40 "cold, shivering" (mild), under 20 "freezing" (moderate). Shivering should stop at about 10, the true moderate stage. That is a late warning sign, not a recovery.

### What shelter and fire cut (judged)

| Shelter | Wind | Rain | Air | Net heat loss against the open |
|---|---|---|---|---|
| Lee of a crest or wall | 0.25 to 0.5 (`wind-over-terrain.md`) | none cut | same | 0.7 |
| Under a big conifer | about 0.3 | 50 to 70% held off (`trees-in-weather.md`, #675) | +1 °C at night | 0.6 |
| Lean-to | 0.1 to 0.3 on the open side | almost all | +1 to 2 °C | 0.5 |
| Tent or hut | almost none | all | +2 to 5 °C with a body inside | 0.3 to 0.4 |
| Cave past 20 m | none | all | the cave mean, 5.5 °C at cave 8002, all year | 0.4 in winter; worse than outside on a warm summer day |
| A fire at 1.5 m | — | — | +10 to +20 °C felt on the side facing it | 0.3 to 0.5, and it dries you |
| A fire at 1.5 m in a lean-to or cave mouth | — | — | the warmest place in the game | 0.2 |

- **Radiant heat:** a campfire warms the side facing it and leaves the back cold. Turning or using a reflector (a rock face behind the fire, or the lean-to wall) roughly doubles the comfort (judged).
- **Today's game:** a lit fire adds 20 °C within 4 m (`fire_c`, `fire_radius_m`), and a roof or crown cuts the wind to 30% (`covered_wind_share` 0.3). Caves are not cover (`cover_at` sees no rock); that is a bug, in `CONTRADICTIONS.md` B2.

### Food and water sickness

- **Odds per meal or drink** (judged; no source gives odds for a medieval wild-food diet):

  | What | Chance of sickness | Kind | Onset in game time |
  |---|---|---|---|
  | Raw or rare deer, elk or moose | 1 in 15 | Salmonella or *E. coli*, a few days of illness | 1 to 3 game days |
  | Raw poultry (grouse, duck, chicken) | 1 in 5 | Campylobacter | 2 to 5 game days |
  | Raw bear or boar | 1 in 3 | Trichinella: swelling, aches, weakness for weeks | 1 to 3 weeks (real time 7 to 26 days, lesson 5) |
  | Raw sea fish | 1 in 20 | Anisakis: stomach pain | within 8 game hours |
  | Raw freshwater fish | 1 in 30 | a slow tapeworm, mild (general knowledge, not checked today) | weeks |
  | Shellfish raw | 1 in 10 | Vibrio or norovirus | 12 to 48 game hours |
  | Old cooked meat or pottage (a day or more unheated) | 1 in 6 | toxin: vomiting, short | 1 to 16 game hours |
  | Spoiled fish | 1 in 3 | scombroid or toxin | under 3 game hours |
  | Water from a still pond, a bog or below a camp | 1 in 5 | Giardia, Cryptosporidium or Campylobacter | 2 to 10 game days |
  | Water from a fast stream high in the hills | 1 in 50 | the same | the same |
  | Water from a spring at its source | about none | — | — |
  | Anything cooked through, or water boiled | about none | — | — |

- **Medieval sense** (judged): people boiled pottage for hours and kept it hot, which is safe. The danger is when it cools and sits. Salt, smoke and drying keep meat and fish for weeks.
- **Game-time note:** real onset times run in game days here, so a meal's sickness lands 1 to 5 real hours later for most causes. Trichinella's real 3 weeks would be 21 real hours. Dave may prefer a shortened "1 to 3 game days" for all of them, so the player can link cause and effect. Either is a fair choice.

## Never-see checks

- a player soaked in linen on a windy hill at 5 °C, warm and fine after hours;
- wet wool drying in 10 minutes by a fire, or clothes drying in a cave with no fire;
- shivering that keeps going as the player gets colder past the moderate stage;
- a cave colder than the open on a summer day, or warmer than a fire;
- sickness the moment raw meat is eaten (onset is hours to weeks);
- boiled water or well-cooked meat making anyone ill.

## How ours works today (read from the code, 8 Nov, not tested)

From `data/items/warmth.json` and the server warmth tick:
- **Air:** comfort at 20 °C; the air comes from the weather (one temperature since #620) with its own daily swing on top. That is `CONTRADICTIONS.md` A3: decided, the warmth tick should read the one temperature.
- **Chill:** wind chill up to 6 °C (`wind_chill_c`), cut to 30% under cover. In the open, rain chill is × `rain_mult` 1.5 through the soak level.
  - **Our sums:** the real wind chill at the starter's 0 to 10 °C and a strong wind (40 to 60 km/h) is 4 to 9 °C, so 6 °C is about right for dry skin. It is too small for wet clothes (lesson 1).
- **Soak and drying:** soak rises 4 an hour in open rain. It dries at 1 an hour under cover and 6 an hour within a lit fire's 4 m. The drying is much faster than real cloth (table above).
- **Fire:** +20 °C within 4 m.
- **Water:** a swimmer's chill comes from the water temperature (`water_base_c` 12 °C, following the air at 0.7), and spring cave pools are 2 °C (`cave_pool_c`). The coordinator decided the pool should follow the sourced cave mean (`CONTRADICTIONS.md` A2).
- **No clothing types, no hypothermia stages, no food or water sickness yet.** Cold costs health slowly, down to 1 (Dave, 21 Oct).

## Sources

- Wikipedia, Four Inns Walk (the 1964 deaths and Pugh's findings): https://en.wikipedia.org/wiki/Four_Inns_Walk
- University of Victoria dissertation (supervisor J. Hayward), wet-cold exposure and hypothermia during prolonged walking in rain ("Wet Walk"): https://dspace.library.uvic.ca/bitstreams/ba9972bb-027f-4044-91f5-ff3c36994089/download
- Bröde, P., Havenith, G. et al. (2008), Non-evaporative effects of a wet mid layer on heat transfer through protective clothing, Eur. J. Appl. Physiol. 104(2): 341 to 349: https://dspace.lboro.ac.uk/dspace-jspui/bitstream/2134/9295/5/Broede_EJAP2008.pdf
- MSD Manual Professional, Classification and staging of accidental hypothermia: https://www.msdmanuals.com/professional/multimedia/table/classification-and-staging-of-accidental-hypothermia
- National Weather Service, Wind Chill Temperature Index (the 2001 formula): https://www.weather.gov/media/arh/brochures/WindChillTempIndexBro.pdf
- Fibre comparison page citing Morton and Hearle (2008), Physical Properties of Textile Fibres (moisture regain; drying figures are trade figures): https://natural-fibers-research.pages.dev/comparison
- Washington State Department of Health, Foodborne illness chart: https://doh.wa.gov/sites/default/files/2025-08/foodchart.pdf
- Tokyo Metropolitan Government, Anisakis food poisoning: https://www.fukushihoken.metro.tokyo.lg.jp/shokuhin/eng/faq/category06/92.html
- CDC, MMWR 73(40) (2024), trichinellosis outbreak linked to undercooked bear meat: https://www.cdc.gov/mmwr/volumes/73/wr/mm7340a4.htm
