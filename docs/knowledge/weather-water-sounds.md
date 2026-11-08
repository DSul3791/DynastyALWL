# Sounds of weather and water: rain on surfaces, wind in plants, how far water and fire carry, thunder

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:**
- Kathleen: the outdoor sound stack (`weather_sounds.gd`, `tree_wind.gd`, `wet_sounds.gd`, `sound_stage.gd`).
- Steve: fire sounds (`flame_sounds.gd`).

**Related:** [sound-outdoors.md](sound-outdoors.md) (distance, wind shadow, night carry, rain masking, forest loss, Yosemite river levels; this page builds on it), [wind-over-terrain.md](wind-over-terrain.md) (wind tones off rock, Strouhal), `trees-in-weather.md` (#675), `fire-outdoors.md` (#668), `sea-and-shore.md` (#650).

## Lessons (read these first)

1. **Rain gets louder by a fixed step each time the rainfall rate goes up tenfold.**
   - The step is about 10 dB with artificial rain and 15 to 20 dB with natural rain (`sound-outdoors.md` lesson 5).
   - At four sites in Japan, LAeq "tended to increase linearly with the logarithm of the rainfall rate", but the slope differed by site. The rise was "mainly above mid-frequencies of around 500 Hz to 1 kHz". How loud a drop hits depended on the surface (Sato et al. 2021, *Applied Acoustics* 172).
   - Rain on tree leaves was 5 to 10 dB louder than rain on gravel (`sound-outdoors.md`).
   - **Roof test rain** (ISO 140-18, the standard for rain noise on roofs): "intense" is 15 mm/h and "heavy" is 40 mm/h. The standard recommends "heavy" for comparing roofs (Sound Reduction Systems). Light, stiff roofs without damping are the loud ones.

2. **On water, drop size sets the sound.** These are NASA's underwater findings, which explain the plink in air too:
   - drops under 0.8 mm are silent;
   - small drops of 0.8 to 1.2 mm are "remarkably loud", because each traps a bubble that rings at 13 to 25 kHz. This is "the sound of drizzle";
   - medium drops of 1.2 to 2 mm are "relatively quiet";
   - large drops of 2 to 3.5 mm trap many bubbles and ring lower, at 1 to 10 kHz;
   - drops over 3.5 mm are loud across 1 to 50 kHz.

   So light rain on a pond is a high, fine fizz with plinks. Heavy rain on a pond is a lower, fuller hiss.

3. **Wind noise rises with the log of wind speed: gently over grass, steeply in a forest past a moderate breeze.**
   - **Grassland** (Netherlands, Boersma and Etienne 1996): the quiet floor LA95 = 22.6 × log₁₀(v) + 22.7 dBA, with v in m/s. That is 23 dBA at 1 m/s, 39 at 5 and 45 at 10.
   - **Oak and beech forest:** the floor is "almost independent of the wind velocity" up to 3 to 4 m/s at the treetops. Above that it rises as about 50 log(v) with leaves on and 55 log(v) bare. Leaves "seem to affect the L95 only slightly".
   - **Deciduous trees in full leaf** (London, Reading): about 59 dBA at 0.5 m/s and 79 dBA at 7 m/s, averaged over seven sites, rising about 1.5 dBA for each 1 m/s between 1 and 6 m/s. The spectrum peaks at 1 to 2 kHz.
   - **A coniferous forest** (Sneddon et al. 1990, *JASA*): "over half of the variance in ambient sound levels can be predicted from knowledge of wind speed".

4. **Surf is loud, and grows with wave height.**
   - Baltic shore: the sound level rose "from 60 dB at 0.4 m wave height to 78 dB at 2.0 m wave height". The spectrum depends on the type of surf (Bolin and Åbom 2010, *JASA*).
   - A popular summary puts waves at 60 to 80 dB, heard from about 1.5 km and from up to about 6 km in good conditions (HomeGrail, citing the same study; a weak source for the distances).

5. **Waterfalls and cascades are the loudest natural sounds on the trail.** These are Yosemite readings in dBA (NPS, Merced River plan, Appendix F, 1999):

   | Where | dBA |
   |---|---|
   | Mist Trail beside Vernal Fall | 75.5 |
   | Viewing area atop Vernal Fall | 65.5 |
   | Base of Vernal Fall, river bridge (the fall "audible in the distance") | 64 |
   | Atop Nevada Fall | 60.5 |
   | Beside granite cascades | 53.5 to 56 |
   | About 200 ft (60 m) from the river, narrow canyon | 40.5 |
   | About 700 ft (210 m) from the river | 40 |
   | About 100 ft (30 m) off the river, "distant river rapids" | 35.5 |
   | Beside the South Fork, "a few minor rapids and cascades" (distance not given) | 44 |
   | Quarter mile off the river, river still heard | 41.5 |

6. **Thunder: 3 seconds a kilometre, and rarely heard past 15 to 20 km.**
   - Sound travels at about 340 m/s, so count the seconds from the flash and divide by 3 for kilometres (Met Office).
   - Thunder is "rarely heard more than 20 km away" (Met Office), and "seldom heard by a ground observer beyond 15 kilometres" (Hong Kong Observatory).
   - The reason is that air cools with height, so sound slows with height and bends up over the listener's head (HKO).
   - It rumbles because sound from different parts of the long channel arrives at different times (Met Office).

## Judged numbers for our sound stack

All levels are dBA at the listener, before the game's own mix gain. Where a number is the game's to set, the table gives an offset.

### Rain on each surface by rain rate

Base level in the open on gravel or bare ground. The base levels are `sound-outdoors.md`'s rain table. Our mapping of rain strength to mm/h is judged, at about 15 dB per tenfold.

| Game rain | mm/h | Base, gravel or bare ground |
|---|---|---|
| 0.15 drizzle | about 1 | 35 to 40 |
| 0.4 moderate | about 4 | 45 to 50 |
| 0.7 heavy | about 15 ("intense") | 55 to 60 |
| 1.0 downpour | about 40 ("heavy" test rain) | 60 to 65 |

Offsets from the base, judged except where marked:

| Surface | Offset | Character |
|---|---|---|
| Broadleaf trees in leaf, overhead | +5 to +10 (sourced) | a patter with distinct taps, plus heavy drip drops after the rain |
| Conifer overhead | +0 to +3 | a soft, even hiss; the needles break the drops |
| Bare winter broadleaf | 0 | ticks on twigs, little patter |
| Turf and long grass | −3 to −5 | a soft wash; grass soaks up the impact |
| Bare rock and stone | +2 to +4 | sharp, bright splashes |
| Mud and puddles | 0 | slaps and plops, louder as puddles grow |
| Open water | −2 to 0 | a fine fizz with plinks in drizzle (lesson 2), a deeper hiss in heavy rain |
| Snow lying | −8 to −10 | almost silent; rain on snow is a soft sizzle |
| Tent or a tarp, from inside | +10 to +20 | a drumming that drowns speech in heavy rain; light, stiff and undamped like a bare metal roof (lesson 1) |
| Thatch or turf roof, from inside | −10 to −15 | a muffled, distant hush; the thick soft layer damps it |
| Wooden shingle or plank roof, from inside | +3 to +8 | a hollow tapping (the game's `rain_woodroof` loops) |

### Wind noise by Beaufort force

Levels in dBA at the listener. The grass column uses the sourced formula. The others are judged from lessons 3 and 4 and the tree page.

| Force (m/s) | Open grass | Broadleaf in leaf | Bare broadleaf | Conifer | Around rock and crags |
|---|---|---|---|---|---|
| 1 (1) | 23 | 25 (still) | 23 | 24 | 23 |
| 2 (2.5) | 32 | 35 rustle | 28 | 32 soft hiss | 30 |
| 3 (4) | 36 | 45 | 35 | 40 hiss | 35 |
| 4 (7) | 42 | 55 to 60 steady rustle | 45, twig ticks | 50 strong hiss, pulsing with gusts | 45, first whistles off edges |
| 5 (10) | 45 | 60 to 65 | 52, creaks | 55 to 60 roar | 52, whistling and moaning gaps |
| 6 (12) | 47 | 65 to 70 | 57, branch knocks | 60 to 65 | 58, howl in notches |
| 7 to 8 (14 to 20) | 49 to 52 | 70 to 79 (Reading's 79 at 7 m/s at the trees) | 62 to 68 | 65 to 72, a deep roar | 62 to 70, buffeting |

- **Character:**
  - broadleaf is a broad rustle peaking at 1 to 2 kHz (Reading);
  - conifer is a smoother hiss, higher, that swells and fades with each gust;
  - bare branches give a thin whistle with creaks and knocks;
  - rock gives tones at f = 0.2U/d, so a 5 cm rib in a 10 m/s wind sings at 40 Hz and a 1 cm twig at 200 Hz (`wind-over-terrain.md`).
- **Gusts:** forest noise swings 5 to 10 dB with each gust. Grass swings less.

### How far it is heard: calm night against a moderate breeze

- **Method (our sums):**
  - point sources lose 6 dB per doubling of distance;
  - rivers and beaches are line sources, losing 3 dB per doubling out to a third of their length;
  - air takes 5 dB per km at 1 kHz;
  - a calm night adds 4 dB past 200 m (`sound-outdoors.md`).
  - Heard means louder than the background: 22 dBA on a calm night (Yosemite's quiet nights were 18 to 26). At force 4 the background is 42 dBA in open grass and about 48 in a forest (judged).
- Terrain and forest in between cut these ranges, often by half (`sound-outdoors.md` forest loss).

| Source (level at reference distance) | Calm night, open | Force 4, open grass | Force 4, in a forest |
|---|---|---|---|
| Small campfire, steady roar (45 at 1 m, judged) | about 15 m | 1 m | at the fire only |
| Campfire pops (60 peak at 1 m, judged) | about 100 m | 8 m | 4 m |
| Brook (55 at 5 m, judged from lesson 5) | 500 m to 1 km | about 90 m | about 25 m |
| Rapids and cascades (56 at 10 m) | 1 to 1.5 km | about 190 m | about 60 m |
| Large waterfall (75 at 30 m) | 3 km or more | 850 m | 500 m |
| Small surf, 0.4 m waves (60 at the shore) | about 3 km | 600 m | 250 m |
| Big surf, 2 m waves (78 at the shore) | 5 km or more | 2 km | 1.5 km |
| Thunder | 15 to 20 km (lesson 6) | 10 to 15 km | 10 km |

- **What the table says:**
  - on a calm night the land is full of distant water: brooks half a kilometre off, the sea from the hills;
  - a moderate breeze shrinks every range about five times;
  - a campfire is a near sound. Its pops carry tens of metres, its roar a few metres.

### Thunder (for `weather_sounds.gd`)

- **Delay:** distance ÷ 340 m/s, so 3 s per km. A 5 km strike is heard after about 15 s. Rumble length grows with distance and channel length: a near crack is under 1 s, a far rumble 5 to 20 s (judged from lesson 6).
- **By distance (judged):**
  - under 500 m: a sharp crack, then a heavy thud, felt in the chest;
  - 1 to 3 km: a crack softening into a long rumble;
  - 3 to 10 km: a low rumble only, with the high end gone (air takes 20 to 50 dB at 4 kHz over 1 km);
  - 10 to 20 km: a faint grumble on a still evening, unheard in wind;
  - past 20 km: lightning without thunder ("heat lightning").

## Never-hear checks

1. Rain on a tent no louder than rain on grass.
2. Rain on a still pond sounding like rain on rock.
3. Wind in a forest no louder at force 6 than at force 3.
4. A crackling campfire heard 100 m away in a breeze.
5. Thunder arriving at once from a strike 5 km off, or a 15 s gap after a strike 1 km away.
6. A calm night with no distant water anywhere near rivers or the coast.
7. Surf as loud with 0.4 m waves as in a 2 m swell.

## How ours works today (read from the code, 8 Nov, not tested)

- **Rain** (`weather_sounds.gd`):
  - loops for rain on the ground (light and heavy), on leaves, on a wooden roof (light and heavy) and on water. Their mix levels (`LOOP_DB`) sit within 4 dB of each other, from −13 to −17;
  - rain under a canopy plays on the leaves;
  - the water loop swells near ponds and rivers;
  - there are no separate turf, rock, snow, tent or thatch voices.
- **Wind in trees** (`tree_wind.gd`): pine, leaves, dry-leaf and bare loops by stand and season, silent below a world wind of 0.35 and fully on by 0.6. They follow the gusts.
- **Thunder:**
  - `THUNDER_NEAR_M` 500 gives a crack and thud. Past `THUNDER_FAR_M` 1,800 it is a low grumble;
  - the delay is half the real travel time (`THUNDER_DELAY_SCALE` 0.5), capped at 4 s (`THUNDER_MAX_DELAY_SEC`);
  - so counting the seconds does not give the distance: any strike past about 2.7 km waits 4 s;
  - strikes go no farther than about 1.8 km, while real thunder is heard to 15 to 20 km.
- **Fire** (`flame_sounds.gd`) and **surf** are separate voices. A fire ducks the wind and surf by 9 dB within 6 to 25 m (`sound-outdoors.md`).

## Sources

- Sato, H., Kurisu, K., Morimoto, M. and Maeda, M. (2021), Effects of rainfall rate on physical characteristics of outdoor noise, Applied Acoustics 172: https://www.sciencedirect.com/science/article/abs/pii/S0003682X20307209
- Sound Reduction Systems, Noise problems created by rainfall on profiled metal roof systems (ISO 140-18 rain rates): https://www.soundreduction.co.uk/about-us/news/the-problem-of-noise-created-by-rainfall-on-profiled-metal-roofing-systems/
- NASA Earth Observatory, Listening to raindrops: https://science.nasa.gov/earth/earth-observatory/listening-to-raindrops/
- Boersma, H. F. and Etienne, R. S. (1996), Characterization of the natural ambient sound environment, Internoise 96: https://www.ioa.org.uk/system/files/proceedings/hf_boersma_rs_etienne_characterization_of_the_natural_ambient_sound_environment.pdf
- Reading, C. M., Noise emitted by deciduous trees blown by the wind, Proceedings of the Institute of Acoustics: https://www.ioa.org.uk/system/files/publications/CM%20READING%20NOISE%20EMITTED%20BY%20DECIDUOUS%20TREES%20BLOWN%20BY%20THE%20WIND.pdf
- Sneddon, M. et al. (1990), Predicting sound levels from wind speed in a coniferous forest, JASA: https://labs.sonicfield.org/library/predicting-sound-levels-from-wind-speed-in-a-coniferous-forest
- Bolin, K. and Åbom, M. (2010), Air-borne sound generated by sea waves, JASA: https://labs.sonicfield.org/library/air-borne-sound-generated-by-sea-waves
- HomeGrail, How far away can you hear ocean waves: https://homegrail.com/how-far-away-can-you-hear-ocean-waves/
- NPS Yosemite, Merced River plan, Appendix F (sound survey, 1999): https://www.nps.gov/yose/learn/management/upload/mrp-deis-appendix-f-web.pdf
- Met Office, Thunder: https://www.metoffice.gov.uk/learning/storms/thunder-and-lightning/thunder
- Hong Kong Observatory, Why we cannot hear the thunder of a distant lightning: https://www.hko.gov.hk/en/education/weather/thunderstorm-and-lightning/00020-why-we-cannot-hear-the-thunder-of-a-distant-lightning.html
