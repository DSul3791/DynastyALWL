# Hearing in weather: how far people and animals hear thunder, rain, running water and a stalking player

**Last checked:** 2026-11-08 (Jamie; a short web pass, with the distance tables our own sums). **Owners:**
- Kathleen: the outdoor sound stack (`weather_sounds.gd`, `water_sounds.gd`, `tree_wind.gd`).
- Steve and MikeW: animal senses (`server_animals.gd` `_sense_factor`, `_sample_noise`) and hunting (#705).

**Related (this page builds on them, and does not repeat their tables):**
- [weather-water-sounds.md](weather-water-sounds.md): rain and wind levels, how far water and thunder carry for a person.
- [sound-outdoors.md](sound-outdoors.md): distance loss, wind shadow, night carry, the rain masking rule.
- [animal-behaviour.md](animal-behaviour.md): perceived distance and `alert_m`.
- [animals-in-weather.md](animals-in-weather.md): what animals do in storms.
- `fog-and-visibility.md` (#716): seeing in fog, the other half of noticing.

## Lessons (read these first)

1. **Our animals hear about the same pitches we do, plus a high end we lack.**
   - **White-tailed deer** hear "from 0.25 to 30 kHz, with best sensitivity between 4 and 8 kHz", and detect "frequencies to at least 30 kHz" against our 20 kHz (D'Angelo 2007, University of Georgia thesis; *J. Wildlife Management* 71(4)).
     - An earlier Texas A&M study found the best hearing at 1 to 8 kHz, peaking at 4 kHz (Risenhoover, cited by Wildlife Online).
   - **Reindeer** hear 70 Hz to 38 kHz, best at 8 kHz (Flydal et al. 2001, cited by Wildlife Online).
   - **Other animals** (Wikipedia, Hearing range):
     - dogs 67 Hz to 45 kHz; cats 55 Hz to 79 kHz;
     - birds about our range, most sensitive at 1 to 4 kHz;
     - people 20 Hz to 20 kHz, most sensitive at 2 to 5 kHz.
   - **Wolves:** up to 25 kHz (wolf.org, citing wolfcountry.net).
   - Deer ears "can be rotated almost 180 degrees", independently, and keep scanning while the deer rests (Wildlife Online).
   - **For us:**
     - a footstep's crunch and a twig's snap sit right in every animal's best band (1 to 8 kHz). So does the hiss of rain;
     - thunder's rumble and a river's roar are low. There, hoofed animals and dogs hear no better than we do (their low limits are 67 Hz and up, against our 20 Hz);
     - pigeons hear down to 0.5 Hz (Wikipedia), so birds may sense far storms we cannot.

2. **Outdoors, the background noise decides how far anything is heard, not the ear.**
   - **Our reading:** on all but the stillest night, wind, rain or water is louder than the quietest sound an ear can catch. A sound is heard only once it rises above that background (the masking rule on `sound-outdoors.md`).
   - **So weather shrinks hearing for animals and people alike.** Each 6 dB more background halves the distance at which a small sound is heard.
   - **Judged, from the levels on [weather-water-sounds.md](weather-water-sounds.md):** hearing range against a calm day (28 dBA):

     | Calm night | Calm day | Force 2 | Drizzle | Force 4, open | Moderate rain | Force 4, forest | Heavy rain |
     |---|---|---|---|---|---|---|---|
     | ×2 | ×1 | ×0.6 | ×0.35 | ×0.2 | ×0.1 | ×0.08 | ×0.04 |

3. **When they cannot hear, prey animals look more, and eat less.**
   - Chaffinches under played-back noise shortened the gaps between their scans, and "pecked significantly less". They did not get used to the noise over five trials (Quinn, Whittingham, Butler and Cresswell 2006, *J. Avian Biology* 37: 601–608).
   - In one lizard study, white noise made skinks look about more, but they fled from an approaching person at the same distance (Kelligrew et al. 2020, *Current Zoology*).
   - **For us:** in wind and rain, animals hear the player later but watch harder. So sight matters more and hearing less.

4. **Noise takes a hearing hunter's prey away.** Wild short-eared and long-eared owls detected a played rustle of prey 17% less often at 40 dB of road noise, and 89% less often at 80 dB. The effect reached 120 m from the road (Senzaki et al. 2016, *Scientific Reports* 6: 30602).
   - **For us:** the same goes for our foxes and owls hunting voles under snow or grass. A wet, windy night is a poor night for them (judged).

5. **Wind does not stop deer moving.**
   - In Pennsylvania GPS data, bucks moved more by day in wind. "Strong winds will increase buck movement no matter what", while does were unaffected above 16 mph. Bucks moved less on windy nights.
   - Rain alone cut buck movement, but only when there was little wind (Penn State Deer Research, observational).
   - **For us:** don't make animals hide in wind for the sake of their hearing. Keep them out and watching (lesson 3), and keep the shelter rules on [animals-in-weather.md](animals-in-weather.md).

6. **Wolves hear and answer howls from kilometres away.**
   - A wolf reply can carry "six miles (ten kilometres)" (Root-Gutteridge, via National Geographic). Indian wolves' howls are detected "over more than 6 km". Conservation groups give "up to ten miles" (16 km) in open terrain (all via ScienceBlog).
   - Wolves hear sounds "from 6 to 10 miles away depending on the terrain and wind" (wolf.org, unsourced there).
   - **For us:** a howl is a loud, low, long call (judged about 110 dB at 1 m). It is one of the few animal sounds that should carry like water does. With the air taking only 1 to 2 dB per km at a howl's low pitch (judged), it carries about 7 km on a calm night, more with the night carry, and about 2 km in a force 4 wind (our sums with the method on [weather-water-sounds.md](weather-water-sounds.md)).

## Judged numbers for the game

### How far a player's sounds are heard (our sums)

- **Method:**
  - level at 1 m, minus 6 dB per doubling of distance, minus 5 dB per km of air;
  - heard when that is at or above the background (lesson 2);
  - **ear gain (judged):** person 0 dB. Deer and other big-eared hoofed animals +6 dB, from turning their large cupped ears to the sound. Owls +10 dB.
- **Source levels at 1 m (judged, dBA):**
  - walking on turf 35;
  - walking on dry leaves 45;
  - walking on gravel or frozen snow 50;
  - running on dry leaves 55;
  - talking 60;
  - a snapped twig 65;
  - an axe stroke 85.
- **Distances in metres at which a deer hears the player:**

  | Player sound | Calm night | Calm day | Force 2 | Drizzle | Force 4, open | Moderate rain | Force 4, forest | Heavy rain |
  |---|---|---|---|---|---|---|---|---|
  | Walking, turf | 9 | 4 | 3 | 2 | under 1 | under 1 | under 1 | under 1 |
  | Walking, dry leaves | 28 | 14 | 9 | 5 | 3 | 2 | 1 | under 1 |
  | Walking, gravel or frozen snow | 49 | 25 | 16 | 9 | 5 | 3 | 2 | under 1 |
  | Running, dry leaves | 85 | 44 | 28 | 16 | 9 | 5 | 4 | 2 |
  | Talking | 146 | 76 | 49 | 28 | 16 | 9 | 6 | 3 |
  | A snapped twig | 245 | 131 | 85 | 49 | 28 | 16 | 11 | 5 |
  | An axe stroke | 1,300 | 860 | 620 | 400 | 245 | 146 | 106 | 49 |

- **For a person, halve these (−6 dB). For an owl, multiply them by about 1.6 (+4 dB over the deer).**
- **What the table says:**
  - on a calm day a careful walker on turf is heard only at a few metres. On dry leaves or frozen snow a deer hears them at 15 to 25 m, and a snapped twig at over 100 m;
  - wind or rain closes all of this down to a few metres. That is why hunters stalk in wind and rain;
  - a calm, frosty night is the hardest time to stalk: frozen snow and still air.

### Running water hides the stalker (our sums)

- A brook is about 55 dBA at 5 m and rapids about 56 at 10 m ([weather-water-sounds.md](weather-water-sounds.md)).
- So within about 20 m of a brook, or 40 m of rapids, the bed is as loud as a force 4 wind (42 to 45 dBA). A deer drinking there hears a walker on dry leaves only at about 3 m.
- **For #734 (animals at water):**
  - animals drinking at loud water hear less, so they look up more often (lesson 3);
  - a player who comes from the water's side, with the roar between them, gets closest.

### Thunder, rain and water for animals

- **Thunder:** animals hear it as far as people do, 15 to 20 km on a still evening, and less in wind ([weather-water-sounds.md](weather-water-sounds.md) lesson 6). Their low hearing is no better than ours (lesson 1).
  - Birds may sense a storm's infrasound farther off. Use the 12 to 24 h warning already on [animals-in-weather.md](animals-in-weather.md) rather than a hearing rule.
- **A near strike** (under about 1 km, the crack and thud) startles animals the way a shot does (judged). Suggest an `alarm_near` at the strike with a radius like the bow's `noise_m` 40 m, scaled up for thunder: 150 to 300 m (judged).
- **Approaching rain:** the hiss of heavy rain on a forest is heard a few hundred metres before it arrives on a calm day, and drizzle hardly at all (judged). Animals start toward shelter as it comes (judged).
- **Running water:** a brook is heard 500 m to 1 km off on a calm night, and rapids 1 to 1.5 km. Animals hear it as far, or a little farther with the +6 dB ear (×2 at short range, much less where the air loss and terrain dominate). Animals could steer toward water by its sound when thirsty in a dry season (judged).

### Suggested rule for `_sense_factor` (for Steve and MikeW to judge)

- **Split the hearing part from sight and scent.** Today the undergrowth noise multiplies the whole perceived distance (see below).
- **Scale only the noise bonus by the weather factor from lesson 2:** `noise = 1.0 + extra × hear_factor`, where `hear_factor` is ×2 on a calm night, 1 on a calm day, down to 0.04 in heavy rain, with a floor of about 0.25 for play (judged).
- **When `hear_factor` is under 0.5, raise sight a little:** animals scan more (lesson 3). For example, `alert_s` shortened by 20% (judged).
- Wind already carries scent (`scent_gain`). Leave that as it is.

## Never-hear checks

1. A deer hearing a careful walker on turf at 30 m on a windy day.
2. Footsteps on frozen snow on a still night no easier to hear than on wet turf in rain.
3. A drinking deer beside rapids hearing a stalker 20 m away.
4. Animals hiding from wind because they cannot hear (deer keep moving in wind).
5. A wolf howl heard only within 100 m.
6. Thunder from 5 km off startling a herd into a bolt.

## How ours works today (read from the code on main, 8 Nov, not tested)

- **`server_animals.gd` `_sense_factor`:** the perceived distance is the true distance divided by a factor built from:
  - scent: `1 + scent_gain 0.5 × wind × (downwind dot)`, never under 0.5;
  - stance: crouch 0.6, sit 0.8, lie 0.5; a covered bed 0.7, a closed room 0.05;
  - sight: blocked sight scales toward `blind_factor` 0.35 past `always_notice_m` 8 m;
  - noise, last: `_sample_noise` gives `1 + brush_noise_per_ms 0.04 × speed ÷ skill²` while moving through undergrowth. Crouching halves the extra (`brush_crouch_share` 0.5).
- **There is no hearing rule for weather.** Rain, wind noise, night and nearby water do not change what animals hear. Only scent uses the wind. Ground type (leaves, gravel, frozen snow) does not change the noise either.
- **Loud noises:** `alarm_near(point, radius)` bolts every animal within the radius. The bow calls it with `noise_m` 40 m (`server_items.gd`). Thunder does not call it.
- **What the player hears:**
  - NPC voices are cut off at `hear_m` 15 m (`data/npcs/voices.json`);
  - nest calls at `NEST_HEAR_M` 45 m (`ambient_life.gd`);
  - thunder only to about 1.8 km (`weather-water-sounds.md`).
- Open PRs on animals and hunting (#705, MikeW's stack) were not read for this page.

## Sources

- D'Angelo, G. J. (2007), PhD thesis, University of Georgia (deer hearing 0.25 to 30 kHz, best 4 to 8 kHz): https://getd.libs.uga.edu/pdfs/d-angelo_gino_j_200705_phd.pdf. Journal paper: *J. Wildlife Management* 71(4), https://bioone.org/journals/Journal-of-Wildlife-Management/volume-71/issue-4/2006-326/Hearing-Range-of-White-Tailed-Deer-as-Determined-by-Auditory/10.2193/2006-326.full
- Wildlife Online, Deer senses: hearing (Risenhoover; Flydal et al. 2001; ear movement): https://www.wildlifeonline.me.uk/animals/article/deer-overview-senses-hearing
- Wikipedia, Hearing range (people, dogs, cats, birds, pigeons): https://en.wikipedia.org/wiki/Hearing_range
- International Wolf Center, How wolves use their sense of hearing: https://wolf.org/?p=48975
- ScienceBlog, A wolf's howl can carry six miles or more: https://scienceblog.com/m-a-wolfs-howl-can-carry-six-miles-or-more-across-open-country-far-enough-to-cross-a-whole-valley-and-wolves-can-discriminate-individual-callers-from-their-howls/
- Quinn, J. L. et al. (2006), Noise, predation risk compensation and vigilance in the chaffinch, *J. Avian Biology* 37: 601–608: https://ueaeprints.uea.ac.uk/35067
- Kelligrew, C. et al. (2020), The effect of white noise on behavioral and flight responses of blue-tailed skinks, *Current Zoology* 67: https://pmc.ncbi.nlm.nih.gov/articles/PMC7901765
- Senzaki, M. et al. (2016), Traffic noise reduces foraging efficiency in wild owls, *Scientific Reports* 6: 30602: https://www.global.hokudai.ac.jp/blog/traffic-noise-reduces-wild-owls-foraging-efficiency/index.htm
- Penn State Deer Research, deer movement in wind and rain: https://www.deer.psu.edu/?p=3957
- Our sums: the hearing-range factors, the player-sound distances, masking by running water, howl carry.
- **Judged:** ear gains, player sound levels at 1 m, the howl level, thunder startle radius, approaching rain, the play floor and scan rule.

## Fetches still to do

1. A large-mammal audiogram with thresholds in dB (Heffner's horse, cattle, pig and goat work at the University of Toledo; the pages fetched today returned only the college homepage). Also their sound-localisation acuity, which from memory is poor in hoofed animals (horses and cattle about 25 to 30°), against about 1° in people.
2. Measured footstep levels on leaves, snow and gravel.
3. People's hearing distance for wolf howls in forest and open ground.
4. A study of deer or elk vigilance in wind noise.
