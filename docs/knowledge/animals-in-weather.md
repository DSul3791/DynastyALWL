# Animals in weather: rain, wind, storms, snow and cold

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** MikeW (animal behaviour and clips), Steve (wolves, dogs, goblins). **Related:** [animal-behaviour.md](animal-behaviour.md) (senses, ranges, temperaments), `wind-over-terrain.md` (#637, local wind and night drainage), `docs/design/one_temperature.md` (#620, the one live temperature), `data/animals/animals.json`.

"Judged" means no source was found today. Anecdote means a practitioner's account, not a study.

## Lessons (read these first)

1. **Rain cuts feeding hard. Wind on its own does little, but it makes rain worse.**
   - **Dairy cattle** under simulated rain and wind (Schütz et al., Animal Welfare, Cambridge):
     - Feed intake fell 62% under rain and under rain with wind. "Wind alone had little effect", but it made the rain's effect stronger.
     - Lying time per 22 h was 5.9 h (control), 4.4 h (wind), 2.8 h (rain) and 1.1 h (wind and rain). Wet animals stay on their feet.
     - About half the time was spent in shelter in every treatment.
   - **Cows lying down are not a sign of coming rain.** That is a myth with little evidence (Naked Scientists). Cows lie down for up to half the day in any weather and avoid lying in mud.
2. **Deer seek shelter, because their coats insulate poorly.** From the Scottish deer best-practice guide, "The Red Deer":
   - Deer have poor insulation compared with sheep and cattle: "Their behavioural strategy therefore is to seek shelter."
   - **Wind:** deer usually graze moving into the wind. "Periods of strong wind from one direction may move deer to the furthest extent of their range".
   - **Bad weather and height:** hinds stay on high ground until "pushed onto lower ground by poor weather or food shortage". Stags winter on lower ground from November to April. Open-hill deer go down at dusk and back up at dawn.
   - **Feeding rhythm:** feeding comes in bouts about every 3 hours. Woodland deer feed mostly at dawn and dusk.
3. **Wind makes prey jumpy and helps predators** (Studd et al. 2022, Oecologia; accelerometers on hares, red squirrels and lynx in the Yukon boreal forest):
   - **Snowshoe hares:** activity fell about 25% as the daily wind rose from 0 to 15 km/h (0 to 4 m/s), and up to 65% above that.
   - **Hare vigilance:** their short still pauses roughly doubled from 0 to 25 km/h of wind. The rise was largest in the cold, from 0.35 to 0.8 minutes per minute of activity.
   - **Squirrels:** vigilance reached 0.7 minutes per minute of activity above 15 km/h.
   - **Lynx:** 25% more active in wind.
   - **Why:** the authors read it as wind masking the sounds that let prey and predator detect each other. Wind explains only a little of the variation (6.5% of hare activity), so it is a tilt, not a switch.
4. **Animals feed more before a storm, and they can sense the pressure falling.**
   - **White-crowned sparrows** (Breuner et al. 2013, J. Exp. Biol.): barometric pressure fell in the 12 to 24 h before snowstorms, and in the laboratory "declining barometric pressure stimulated food intake".
   - **White-throated sparrows** (MacDougall-Shackleton, Guglielmo, Metcalfe and colleagues; phys.org 2013): after a simulated pressure drop before dawn, the birds began eating at once instead of preening first.
   - **Insects court less** when pressure falls (Pellegrino et al. 2013, PLoS ONE). In cucurbit beetles, males responded less to the female scent. Armyworm moth females and potato aphid females called less.
   - **Swallows flying low before rain** is plausible but not proven. Insects stay low in cool, humid air, and the swallows follow their food (Farmers' Almanac, no study cited).
5. **Predators move less during snowfall and are back to normal within a day.**
   - **Grey wolves** (Droghini and Boutin 2018, PLoS ONE; 17 collared wolves over two winters, University of Alberta): wolves "travel shorter distances and move slower during snowfall events", most of all at night when they hunt. "Behaviour returned to normal within a day."
6. **Bats stay in when it is windy.**
   - **Forest bats** (Ellerbrook et al. 2024): high mean wind cut nightly activity by 97% for bats that hunt in tight spaces and 82% for bats that hunt along edges. Earlier work expects a strong drop above about 6 m/s.
   - **Temperature:** warm nights had far more activity.
   - **Rain:** not tested in that study, but earlier work links bat activity to rain too.
7. **Cattle drift with a storm, and bison face into it** (anecdote; Western Horseman, "Lesson from bison"):
   - **Cattle** "drift with the storm, letting the winds and snow push them whatever way it's blowing". On the northern plains this has killed whole herds.
   - **Bison** "turn right into the storm and walk", so the storm passes over them sooner.
8. **Horses use a shed most in cold, wet, windy weather, but rarely heavily** (TheHorse.com, a study of more than 50 horses over a year).
   - **Summer** (Swedish study, Acta Vet. Scand. 2015): horses used shelters for about 100 minutes by day and the same by night, mainly to escape insects. Shelter cut their insect-defence moves. Wind (below 4 m/s on those days) and temperature (around 19 °C) made no difference.

## Judged rules for the game

These rules use only what `ServerAnimals` already gets from the weather: `rain`, `snow`, `storm`, `wind` and `wind_dir` (0 to 1), `temp_c`, `season`.
- **Looking ahead:** `weather.gd` is a pure function of game time. So the server can look 12 to 24 h ahead to know a storm is coming, which is what the birds sense from the falling pressure. Nothing has to be stored.
- **Wind speeds:** these use the m/s mapping in `wind-over-terrain.md` (m/s = 20 × wind^1.3).

### Rain (rain above about 0.4)

- **Grazers** (deer, horses, cattle, sheep, goats):
  - spend 40% of their usual time feeding (lesson 1: −62%);
  - stand instead of lying, and never lie on wet ground;
  - move to cover within about 100 m (a forest edge, a large tree, a crag's lee) if any is there. Deer always do, and sheep and cattle half the time (judged from lesson 2).
- **Posture** (judged): head low, ears back, tail clamped, standing still for long spells.
- **Small animals** (rabbits, hares, squirrels): mostly in burrows and dreys. They come out in light rain or right after it.
- **Bats and insect calls:** none in rain heavier than a drizzle.
- **Birds:** perch in cover and stop singing in heavy rain. Ground birds feed on worms just after rain (judged).

### Wind

- **Light to moderate wind (`wind` below about 0.6):**
  - deer, wolves and dogs graze or travel facing into the wind, so their noses lead (lesson 2);
  - prey are jumpier: spook range ×1.2 at `wind` 0.3 and ×1.4 at 0.6 (judged from lesson 3: twice the vigilance);
  - hares and rabbits are 25% less active above `wind` 0.25 (about 3.5 m/s) and 65% less above 0.35 (lesson 3);
  - predators (lynx, wolves, foxes) hunt a little more (lesson 3).
- **Strong wind and storms (`wind` 0.6 or more, or `storm` 0.5 or more):**
  - horses, cattle, sheep and goats turn their rumps to the wind and drift slowly downwind, a few metres a minute (judged, lesson 7). They gather in the lee of crests, walls and woods (`wind-over-terrain.md`, lee within 5 to 10 H);
  - deer go into woodland or down to lower ground (lesson 2);
  - wild bison or aurochs, if added, face into the storm and walk (lesson 7).
- **Bats:** none above `wind` 0.35 (about 5 to 6 m/s, lesson 6).
- **Every animal in the open faces about the same way in a gale.** That is the look to get right. Deer facing into the wind and livestock turned away is fine.

### Before a storm (`storm` reaching 0.5 within the next 12 to 24 game hours)

- **Birds, squirrels, rabbits and deer:** feed about 1.3 to 1.5 times as much (judged size, lesson 4 direction). They start at first light and skip resting bouts.
- **Insects:** quieter. Fewer calls and less buzzing in the last 12 h (lesson 4).
- **Swallows and martins:** hunt low over fields and water (lesson 4, lore).
- **Not a sign:** cows lying down (lesson 1).

### During and after a storm or snowfall

- **During:**
  - most animals bed down in cover and barely move;
  - wolves travel shorter and slower, about half their usual distance (judged size, lesson 5);
  - goblins and bears follow their own den rules.
- **After:** back to normal within a day (lesson 5). On the morning after, there is a burst of feeding (judged).

### Cold and snow

- **Deer:** move down to lower ground and into conifers when it is cold and snowy (lesson 2). Below about −5 °C, or with snow above 0.3 m, they gather in sheltered conifer stands (judged).
- **Sheep and cattle:** stay out longer than deer. They have better coats (lesson 2).
- **Hare vigilance** rises most in the cold (lesson 3).
- **Cold calm nights:** the cold air drains into valley floors (`wind-over-terrain.md`). Animals bed on slopes a little above the floor (judged).

### Heat and insects (summer days above about 22 °C)

- **Horses and cattle:** stand in shade or a shelter at midday, mostly to escape flies, and switch their tails a lot (lesson 8).
- **Deer:** feed at dawn and dusk and lie up in woods at midday (lesson 2).

### Fog

Prey rely more on hearing and smell. Sight ranges are cut with the fog distance, and spook ranges shrink (judged).

## Never-see checks

- a herd grazing in the open through a downpour as if it were sunny;
- animals in an open field in a gale facing every which way;
- bats out in a gale or heavy rain;
- wolves pacing far and fast in a blizzard;
- hares dashing about on a windy day as much as on a calm one;
- a cow lying down "because rain is coming" as a scripted sign.

## How ours works today

From a grep on 8 Nov:
- **What the server reads:** `ServerAnimals` (`src/stream/server_animals.gd`) reads the weather through its `wind` callable each tick, but only `wind` and `wind_dir` (`_wind_s`, `_wind_dir`).
- **What it uses them for:** only scent, in `_sense_factor`. A player upwind of an animal is sensed from farther off, by `1 + scent_gain × wind × alignment`, never below 0.5.
- **What's missing:** nothing reacts to rain, snow, storm, temperature or what the weather will do next. There is no shelter seeking, no facing the wind and no feeding change. Flocks (`server_flocks.gd`) use the same senses.
- **Possible bug found while reading:** in `_sense_factor`, the wind line sets `f = maxf(...)` instead of `f *= maxf(...)`. It overwrites the bed and closed-room factors just above it (`bed_mult` 0.7, `hidden_mult` 0.05). The world wind is never below 0.15, so a player lying in a closed room is sensed as an open lying player. Reported to the coordinator. This page does not change code.

## Sources

- Schütz, K. E. et al., Responses to short-term exposure to simulated rain and wind by dairy cattle: time budgets, shelter use, body temperature and feed intake, Animal Welfare: https://core-prod.cambridgecore.org/core/journals/animal-welfare/article/responses-to-shortterm-exposure-to-simulated-rain-and-wind-by-dairy-cattle-time-budgets-shelter-use-body-temperature-and-feed-intake/BF29E10AF2BD9069AD422323F761045D
- The Naked Scientists, Myth: do cows lie down in the rain?: https://www.thenakedscientists.com/node/192533
- Scottish deer best practice guides, The Red Deer: https://bestpracticeguides.scot/deer-ecology/red-deer/
- Studd, E. K. et al. (2022), Behavioural adjustments of predators and prey to wind speed in the boreal forest, Oecologia: https://par.nsf.gov/servlets/purl/10414813
- Breuner, C. W. et al. (2013), Environment, behavior and physiology: do birds use barometric pressure to predict storms?, J. Exp. Biol. 216: https://scholarworks.umt.edu/biosci_pubs/386
- phys.org (2013), Birds adjust behaviour to barometric pressure (white-throated sparrows): https://phys.org/news/2013-11-birds-weather-adjust-behaviour-barometric.pdf
- phys.org (2013), Insects modify mating behavior in anticipation of storms (Pellegrino et al., PLoS ONE): https://phys.org/news/2013-10-insects-behavior-storms.html
- Farmers' Almanac, When the swallows fly low, rain is on the way: https://www.farmersalmanac.com/?p=433025
- University of Alberta (2018), Snowed in: wolves stay put when it's snowing (Droghini and Boutin, PLoS ONE): https://www.ualberta.ca/en/science/news/2018/december/wolves-snowfall-behaviour.html
- Ellerbrook, L. et al. (2024), Forest bat activity declines with increasing wind speed: https://tethys.pnnl.gov/sites/default/files/publications/Forest-bat-activity-declines-increasing-wind-speed-operating-wind-turbines-Ellerbrook-et-al-2024.pdf
- Western Horseman, Lesson from bison: https://westernhorseman.com/writing-on-the-range/lesson-from-bison/
- TheHorse.com, Shelter-seeking behavior most common in poor weather conditions: https://thehorse.com/?p=50207
- Shelter use of horses during Swedish summer in relation to weather conditions and insect abundance, Acta Veterinaria Scandinavica (2015): https://link.springer.com/article/10.1186/s13028-015-0135-x
