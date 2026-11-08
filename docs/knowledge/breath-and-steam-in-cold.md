# Breath and steam in cold air: when breath shows for each animal, how far it is seen, steam off wet and hot bodies, and steam over springs and brooks

**Last checked:** 2026-11-08 (Jamie; a short web pass, with the thresholds our own sums). **Owners:**
- MikeW: animal breath and body steam (pr25, `breath_looks`, `docs/design/ANIMAL_BREATH.md` on his branch).
- Kathleen: steam over water (the frozen water look, #729 and #731).
- Steve: the states that make an animal hot or wet (#734, #737).

**Related:**
- `springs-and-brooks-in-winter.md` (#739): spring water at 5.5 °C.
- `fog-and-visibility.md` (#716): how far small things are seen in mist.
- `body-in-weather.md` (#703): wet coats and drying.
- [cave-microclimate.md](cave-microclimate.md): steam at cave mouths.

## Lessons (read these first)

1. **Breath shows when warm, wet breath mixes with cold air and passes its dew point.**
   - **The physics:** exhaled breath carries water vapour, and mixing it into cold air takes a small parcel past saturation. Then "some of the vapor condenses into tiny liquid droplets" (Farmers' Almanac, citing NOAA). The puff "fades quickly as it mixes with the drier surrounding air" (Kansas State climate office).
   - **For people:** breath "commonly begins showing up below about 45°F" (7 °C), per the Library of Congress via the Farmers' Almanac. In humid air it shows in the 40s °F, and in dry air it needs colder. Mental Floss puts the top at about 60 °F (15 °C) on a very humid day.
   - Steam fog is the same process: "water vapor is added to air that is much colder than the vapor's source". The source can be warm water or "exhaled breath" (AMS Glossary, Steam fog).

2. **Animals with a nasal heat exchanger breathe out cooler air, so their breath shows less than you'd think.**
   - In the cold, reindeer breathe out air "an average of 21 °C less than body temperature", which is about 18 °C. That recovers about 75% of the heat and 80% of the water (Langman 1985, *Respiration Physiology* 59: 279–287).
   - **For us:**
     - a deer, elk or horse breathing quietly through its nose puts out cooler, smaller puffs than a person breathing through the mouth. That is why its breath shows only in colder air, unless the animal is big;
     - a panting animal (after a chase, or a dog or wolf that is hot) breathes through its mouth at nearly body temperature. Its breath shows in much milder air.

3. **Water steams when the air over it is about 10 to 15 °C colder than the water.**
   - **Our sums:** we mixed saturated air at the water's temperature into the open air. We set the fog threshold at 0.2 g/m³ of condensed water, which is about the water content of a real fog. That threshold was tuned so sea smoke appears where Maine Sea Grant says it does: "below 10 degrees" °F (−12 °C) over winter seas "in the 30s" °F (1 to 3 °C).
     - The result is the same at any water temperature: steam starts when the air is about 14 °C colder than the water in 70% humidity, 11 °C colder in 90%, and 16 °C colder in 50%.
   - **Calm helps it:** "the quieter the wind, the greater the chance that sea smoke will form and persist" (Maine Sea Grant). It rises in drifting columns.
   - **Below −29 °C** the droplets may freeze into ice crystals ("frost smoke", AMS Glossary).

4. **Wet or hot bodies steam the same way.**
   - A horse worked hard in winter steams: "Steam rises off your horse's body and disappears around you into the cold winter air". It must be "completely dry" before it is blanketed, or it chills (WeatherBeeta).
   - **Our sums (lesson 3's rule, with judged coat temperatures):**

     | Surface | Its temperature (judged) | Steams when the air is below |
     |---|---|---|
     | A sweating horse, elk or deer just after a hard run | coat about 30 °C | about 16 °C |
     | A person sweating after a run, or an opened carcass, gut pile or fresh blood | 30 to 38 °C | 16 to 24 °C |
     | A coat just out of water, on a warm-blooded animal | about 15 °C at the surface | about 2 °C |
     | Dung and urine, just dropped | about 35 °C | about 20 °C |

   - **How long it lasts (judged):** a hot body steams for 5 to 15 minutes, until the coat surface cools. A wet coat steams faintly until it is mostly dry, and `body-in-weather.md` (#703) says that takes hours. So 2 to 10 minutes of visible steam, then nothing you can see.

## Judged numbers for pr25 and the water look

### When breath shows (our sums, judged inputs)

- **Method:** lesson 3's mixing, with a stricter threshold for a single small puff. That threshold was tuned so a person's mouth breath shows below 7 °C at 70% humidity (lesson 1).
  - A bigger puff needs less condensed water to be seen. We scaled the threshold by the puff's width, the cube root of the breath volume.
- **Judged inputs:**
  - the breath's temperature: mouth 34 °C, nose 25 to 31 °C, panting 35 to 37 °C;
  - the breath's volume: about 10 mL per kg of body weight (from memory).

  | Who | Breath (judged) | Shows below, in 70% humidity | In 90% humidity |
  |---|---|---|---|
  | Person, mouth (sourced anchor) | 34 °C, 0.5 L | 7 °C | 9 °C |
  | Person, nose | 31 °C, 0.5 L | 2 °C | 4 °C |
  | Person panting after a run | 35 °C, 1.5 L | 12 °C | 14 °C |
  | Horse, elk | 27 °C, 5 L | 5 °C | 7 °C |
  | Moose | 25 °C, 6 L | 3 °C | 5 °C |
  | Bear | 29 °C, 2 L | 5 °C | 7 °C |
  | Boar | 29 °C, 0.8 L | 1.5 °C | 3 °C |
  | Deer | 27 °C, 0.8 L | −2 °C | 0 °C |
  | Wolf, dog at rest | 30 °C, 0.4 L | −0.5 °C | 1 °C |
  | Wolf or dog panting after a chase | 37 °C, 1.2 L | 14 °C | 16 °C |
  | Fox, hare, small animals | 25 to 27 °C, under 0.1 L | only in hard frost (−10 °C or colder), and only seen close | |

- **For pr25 (`COLD_C` 5 for every animal):** make the threshold a row in each species' `breath` data.
  - The big animals (horse, elk, moose, bear) are about right at 5 °C. Deer, wolves and boar should be nearer 0 °C.
  - Small animals should hardly show at all.
  - Any animal that is panting should show up to about 14 °C.
  - The puff's thickness can keep MikeW's "thicker the colder" ramp.
- **Breathing rates (from memory, judged):** a person at rest 12 to 20 a minute; a horse 8 to 16; a dog 10 to 30; panting dogs and wolves far faster. MikeW's 15 a minute default with ×3 panting fits.

### How far breath and steam are seen (judged)

- **A person's puff:** about 0.3 m across, lasting 1 to 3 s. It is seen to about 30 m against a dark forest, about 10 m against snow or bright sky, and twice as far lit from behind by a low sun.
- **A horse's or elk's puff:** about 1 m. It is seen to 60 to 80 m against a dark background.
- **A steaming herd after a chase, or a steaming carcass:** a haze over the backs, seen to a few hundred metres in calm air.
- **Wind** shreds a puff within a metre or two. In a force 4 wind, breath is seen only close (judged).
- In mist, use the fog page's rule: small, faint things are seen to about ¼ of the visibility (`fog-and-visibility.md`, #716).

### Steam over springs and brooks (lesson 3)

- **A spring at 5.5 °C** (cave 8002) steams when the air is below about −8 °C in 70% humidity, or −5 °C in 90%, in calm air.
- **The brook below** cools toward 0 °C (`springs-and-brooks-in-winter.md`), so it steams less and less downstream. A 0 °C brook needs air below about −14 °C.
- **The sea:** the starter sea is about 7 to 9 °C in local winter (judged). It needs air below about −5 °C, so it hardly ever smokes on the starter.
- **On the starter island** (from `climate.gd`): the coldest dawn is about −4 °C at sea level and about −7.5 °C at spring 8002 (533 m), in a cold spell.
  - So the spring steams only on the coldest, stillest, most humid dawns of a cold spell, and only faintly.
  - Steam over spring mouths is a colder-world look: the arctic zone, and high springs in the mountains.
  - This corrects the "steam on cold mornings" line in #739, which now says the same.

### On the starter island (our sums from `climate.gd`)

- **Dawn air:**
  - at sea level, about 0 °C in midwinter, 5 °C in local spring and autumn, and 10 °C in midsummer;
  - about 3.5 °C colder at 500 m;
  - cold spells take another 4 °C off.
- **So:**
  - a person's breath shows on most dawns from mid local autumn to mid local spring, and on most dawns all year at 500 m and above;
  - horses, elk and bears show on most winter dawns;
  - deer and wolves show only on winter dawns in a cold spell, or up high. A deer that has just run shows on any cool morning;
  - a sweating, hot animal, a hunter after a run, a fresh kill or a gut pile steams on any day colder than about 16 °C. That is most of the year on the starter.

## Never-see checks

1. A deer at rest puffing clouds on a 10 °C morning.
2. A panting wolf after a chase showing no breath at 5 °C.
3. A fresh kill not steaming on a frosty morning.
4. Breath clouds just as thick in a force 5 wind as in calm air.
5. The 8002 spring steaming on a mild local winter afternoon.
6. A horse that has just run steaming for an hour.

## How ours works today (read from the code, 8 Nov, not tested)

- **Main:**
  - `climate.gd` names breath among the things that use the one temperature;
  - the weather looks have a steam breath. No per-animal breath was found on main.
- **MikeW's pr25** (`claude/mikew-pr25-breath`, head 750bb699, `animal_view.gd`, behind `breath_looks`, off):
  - `COLD_C` 5: every animal's breath puffs below 5 °C, thicker the colder;
  - the rate is `breath.per_min` (default 15), ×2.5 moving fast, ×0.7 at rest, and ×3 panting for 20 s after states 2, 7 and 11;
  - `BODY_STEAM_C` 8: a wet or hot body steams below 8 °C for 60 s (`hot_until`).
  - **Against this page:**
    - body steam should start in much milder air: about 16 °C for a hot body and 2 °C for a wet one;
    - it should last longer: 5 to 15 minutes hot, 2 to 10 minutes wet, not 60 s;
    - the breath threshold should vary by species and by panting (table above).
- **Kathleen's #731** frozen water look: no steam over open water was read.

## Sources

- Farmers' Almanac, Can you see your breath already? (Library of Congress: below about 45 °F; NOAA: dew point): https://www.farmersalmanac.com/?p=442461
- Mental Floss, Why can you sometimes see your breath? (up to about 60 °F when humid): https://www.mentalfloss.com/article/611491/why-you-can-see-your-breath
- Kansas State University climate office, Weekly wonder (breath and dew point): https://secondary.climate.ksu.edu/news/stories/2017/10/ww_oct_18
- American Meteorological Society Glossary, Steam fog: https://glossary.ametsoc.org/wiki/Steam_fog
- Maine Sea Grant, Cold enough yet? The science behind sea smoke: https://seagrant.umaine.edu/resource/cold-enough-yet-the-science-behind-sea-smoke
- Langman, V. A. (1985), Nasal heat exchange in a northern ungulate, the reindeer, *Respiration Physiology* 59: 279–287: https://bvbvf1.bib-bvb.de/vufind/PrimoRecord/cdi_proquest_miscellaneous_76079924
- WeatherBeeta, Cool out your hot horse safely this winter: https://www.weatherbeeta.com/blog/cool-out-your-hot-horse-safely-this-winter/
- Our sums: the mixing thresholds, the steam rule, the per-animal table, the starter dawns.
- **Judged or from memory:** breath temperatures and volumes, coat temperatures, steam durations, how far puffs are seen, breathing rates, the starter sea temperature.

## Fetches still to do

1. Measured exhaled air temperature for deer, horses or cattle in the cold.
2. A measured "breath visible" threshold with humidity, from a met service.
3. How long a horse or deer steams after work (an equine or deer physiology source).
4. Coat surface temperatures of wet mammals (thermal camera studies).
