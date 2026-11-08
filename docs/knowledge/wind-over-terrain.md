# Wind over terrain: crests, lee, valleys, night drainage and gusts

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Kathleen (how wind looks: trees, grass, smoke, flags); MikeW (animals and anything on a rig that moves in the wind); the sound stage (`src/client/sound_stage.gd`, `tree_wind.gd`, `wind_structures.gd`). **Related:** `snow-on-slopes.md` (#632, wind moving snow), `docs/design/fog_pools_and_sea_fog.md` (#608, cold-air pools), [warmth-weather.md](warmth-weather.md) (wind chill).

"Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found today.

## Lessons (read these first)

1. **Wind speeds up over crests: about 1.6 times on a typical hill, and up to 2 times on a steep one.**
   - **Taylor and Teunissen (1987, the Askervein Hill project):** for a typical low hill (height h about 100 m, half-length L about 250 m), near-surface wind speeds rise by about 60%. On steeper hills the rise is up to 100%. Askervein itself is 116 m high, an ellipse 2 km by 1 km.
   - **Rule of thumb** (Taylor and Lee 1984, as cited by Lubitz 2007): the fractional speed-up at the crest is ΔS = B·h/L. B depends on the hill's shape. **Our sums:** the 60% case gives B ≈ 1.5. The rule holds only for slopes below about 0.3 (17°) and hills under 2 km long. Above that, use about 2 times as the cap.
   - **Where the fastest air is:** the maximum is at the surface or close to it, at about 0.1 to 0.2 of the hill's height (Lubitz 2007, Table 2). A person standing on a summit is in the fastest air.
2. **Behind a steep crest the flow breaks away, and the lee is sheltered but gusty.**
   - **Slope rule** (Finnigan 1988, as cited by Lubitz 2007): there is no separation below a lee slope of about 0.27 (15°). Separation always happens at 0.32 (18°) or more, and it comes and goes between the two. Others use 0.4 (22°) for smooth 2-D hills.
   - Beyond the separation point there is a **rotor**: a slow eddy where the ground wind can blow back up the slope, toward the crest.
   - **How far the shelter reaches** (windbreaks as a stand-in; "How windbreaks work", New Mexico Environment Department copy), as a share of the open wind:

     | Barrier | 5 H | 10 H | 15 H | 20 H | 30 H |
     |---|---|---|---|---|---|
     | Solid (like a cliff or crest) | 25% | 70% | 90% | 95% | 100% |
     | Conifer belt, 40 to 60% dense | 30% | 50% | 60% | 75% | 95% |
     | Broadleaf belt, 25 to 35% dense | 50% | 65% | 80% | 85% | 100% |

     H is the barrier's height. A solid barrier gives deep shelter close in, with turbulence, but the shelter does not reach far. A half-open barrier (40 to 60%) shelters the longest stretch. Barriers under 20% dense do almost nothing. Upwind, the wind is already slowed for 2 to 5 H.
3. **Gaps and passes channel the wind, and the strongest wind is at the gap's exit.**
   - **Navy mesoscale primer (University of Washington):** gap winds can be several times the upstream wind. The Nuuanu Pali pass (Oahu) takes 10 to 20 knot trade winds and often blows over 40 knots at the narrowest point. The Hinlopen Strait goes from about 8 knots upstream to about 30 knots at its exit.
   - "The strongest winds are generally not in the narrowest portion of gaps but rather in gap exit regions." Behind solid terrain, the wake can be very light for long distances.
4. **On calm, clear nights cold air drains downhill. This is katabatic flow.**
   - **AMS Glossary of Meteorology, "katabatic wind":** "a downslope flow driven by cooling at the slope surface during periods of light larger-scale winds".
     - The cooled layer is about 10 to 100 m deep. The fastest air is a few metres to a few tens of metres above the ground.
     - On a simple slope the flow is about 0.05 times as deep as the drop from the top of the slope.
     - In mountain valleys the surface speed is usually 3 to 4 m/s. On long slopes it can be over 8 m/s.
   - **AMS Glossary, "along-valley winds":** at night, cold air flows down the valley at 1 to 8 m/s, in a layer 10 to 400 m deep. By day a gentle up-valley wind blows along the floor.
   - **Our sums:** a 400 m slope above a camp gives a drainage layer about 20 m deep.
   - The same cold air fills hollows and valley floors. That is the cold-air pool in the fog design (#608) and Sonny's `fog_pool` byte.
5. **Wind always comes in gusts. In the open, the strongest 3-second gust is about 1.5 times the 10-minute mean.**
   - **Van den Brink (2020, KNMI):** at 10 m over open grass (roughness 0.03 m) with a 20 m/s mean, the median peak 3-second gust is 29.1 m/s, a ratio of about 1.46. The 90% range is 1.37 to 1.59.
   - **Rougher ground** (forest edges, broken rocks) is gustier. That is judged: no table was found today.
6. **Smoke, leaves and flags read the wind. The Beaufort land scale is the reference** (NOAA NCEI, "Land Beaufort Scale"). The m/s column is our sums from the knots.

   | Force | m/s | On land |
   |---|---|---|
   | 0 | under 0.5 | Smoke rises vertically |
   | 1 | 0.5 to 1.5 | Smoke drift shows the direction |
   | 2 | 1.6 to 3.3 | Wind felt on face, leaves rustle |
   | 3 | 3.4 to 5.4 | Leaves and small twigs in constant motion, wind extends a light flag |
   | 4 | 5.5 to 7.9 | Raises dust and loose paper, small branches move |
   | 5 | 8.0 to 10.7 | Small trees in leaf begin to sway |
   | 6 | 10.8 to 13.8 | Large branches in motion |
   | 7 | 13.9 to 17.1 | Whole trees in motion, walking against the wind is hard |
   | 8 | 17.2 to 20.7 | Twigs break off trees, progress is impeded |
   | 9 | 20.8 to 24.4 | Slight damage to buildings |
   | 10 | 24.5 to 28.4 | Trees uprooted |

7. **Trees sway at their own slow beat, whatever the wind.**
   - **Jackson et al. (2019), "An architectural understanding of natural sway frequencies in trees":**
     - Slender trees "behave like a simple pendulum, with a single natural frequency dominating". A simulated sycamore sways at 0.26 Hz, about one swing every 4 seconds.
     - Leaves lower the frequency. In winter the mean rose about 19% at Wytham Woods.
     - Damping is 8.6 ± 2.2% in summer and 3.9 ± 1.3% in winter, so a bare tree keeps swinging about twice as long after a gust.
   - **Crops and grass** (Py et al. 2006, as cited at FIV 2008): the travelling waves across a field ("honami") move at the plants' own natural frequency, whatever the wind speed. The wind sets how far the plants bend and where the waves go, not how fast each stem bobs.
8. **Wind noise is a tone set by speed and thickness.**
   - **Wikipedia, "Aeolian sound":** air past a cylinder sheds eddies at f = St·U/d, with the Strouhal number St about 0.2. Each doubling of the wind raises the tone by an octave.
   - **Our sums at 5 m/s:** a 1 mm pine needle gives about 1,000 Hz (a hiss), a 5 mm twig about 200 Hz, and a 3 cm branch about 33 Hz (a low roar).
   - **This fits the game's sound stage:** its wind filter cutoff already rises with strength and on ridges.

## Judged numbers for the game

### The weather's wind in m/s

`weather.gd` gives `wind` from 0 to 1. Calm days sit near 0.15 to 0.3, and storms reach 0.9 to 1. Proposal (judged), so that the look and sounds share one speed: **m/s = 20 × wind^1.3**.

| wind | m/s | Force |
|---|---|---|
| 0.15 | 1.7 | 2 (leaves rustle) |
| 0.3 | 4.2 | 3 (light flag out) |
| 0.5 | 8.1 | 5 (small trees sway) |
| 0.7 | 12.6 | 6 (large branches) |
| 0.9 | 17.4 | 8 (gale) |
| 1.0 | 20 | 8 to 9 |

On this scale the snow page's "moving snow above 0.5" is about 8 m/s. Real fresh snow starts moving at 4 to 5 m/s, which is about 0.35. Kathleen can choose either for the look. 0.5 keeps drifting to clearly windy days.

### Local wind multiplier, per place, against the open-ground wind

| Place | Multiplier | Basis |
|---|---|---|
| Summit or crest of a steep hill | 1.6 to 2.0 | Lesson 1 |
| Crest of a gentle hill (under 10°) | 1.2 to 1.5 | Lesson 1, ΔS = 1.5 h/L |
| Pass, col or gap lined up with the wind, at its downwind end | 1.5 to 2.0 | Lesson 3, capped (judged) |
| Valley lined up with the wind | 1.1 to 1.3 | judged |
| Upwind foot of a hill | 0.8 to 0.9 | judged, from the 2 to 5 H upwind slowing |
| Lee of a crest steeper than 18°, within 5 H | 0.25 to 0.5, gusty, can blow back upslope | Lesson 2 |
| Lee, 10 H | 0.5 to 0.7 | Lesson 2 |
| Lee, 20 to 30 H | back to 1 | Lesson 2 |
| Valley floor across the wind | 0.4 to 0.7 | judged |
| Inside forest, 2 m up | 0.2 to 0.4 | judged |
| Open shore and sea | 1.1 to 1.3 | judged (smoother surface) |

**For the sound stage:** today `EXPOSURE_GAIN` 0.45 gives a ridge 1.45 times and a valley 0.55 times. That is inside these ranges and can stay. A steep summit could go to about 1.8 (judged).

### Gusts

- **Gust peaks:** about 1.5 times the mean, and 1.7 to 2 times on rough or broken ground (judged). The lull between gusts is about 0.6 to 0.7 times the mean (judged).
- **Timing** (judged): one gust lasts 3 to 10 s, and a strong one comes about every 20 to 60 s. A gust should be seen crossing the ground: the grass and the treetops upwind move first, about U × time ahead of the player.
- **The lee is gustier:** the same mean speed, but bigger swings and short reversals of direction behind a crest steeper than 18°.

### Night drainage (katabatic)

- **When:** clear, calm nights (judged: `wind` < 0.3 and `cloud` < 0.4), from about an hour after sunset to an hour after sunrise.
- **What:** air near the ground flows downslope and then down-valley, whatever the weather's `wind_dir`.
  - Speed 1 to 3 m/s on our hills, up to 4 below long slopes (judged, inside the AMS 1 to 8).
  - The layer is about 0.05 times the drop above, so 10 to 30 m on our valley sides.
- **What it shows:**
  - campfire smoke drifts downhill and gathers in the valley floor;
  - mist and fog pools fill from the sides (#608);
  - the breath plume drifts downhill.
- **Sound:** almost none. It is too slow to rustle much, which helps the night feel still.
- **By day:** with sun and light wind, a weak up-slope and up-valley breeze of about 1 to 2 m/s (judged).

### Trees

- **Sway frequency:** about 0.2 to 0.5 Hz for full-size trees, slower for taller ones. Use 0.26 Hz (one swing about every 4 s) for a mid broadleaf. Use about 20% faster for bare winter trees and small trees (judged spread around the 0.26 Hz value).
- **Ringing on:** bare winter trees keep swinging after a gust about twice as long as trees in leaf (damping 4% against 9%).
- **What moves when**, following Beaufort:
  - below force 2 (`wind` < 0.15): nothing but a few leaves;
  - force 3 to 4: twigs and leaves in constant motion, small branches;
  - force 5 (`wind` 0.5): small trees sway as a whole;
  - force 6: large branches;
  - force 7 and up (`wind` 0.8 or more): whole trees, crowns leaning downwind with each gust.
- **How far** (judged): treetop sway is about 0.5% of the tree's height at force 5, 1 to 2% at force 7, and 3% at a gale. Conifers lean less and shiver more at the needle tips.

### Grass and reeds

- **Waves:** waves of bending travel across the grass downwind at about the wind speed (judged; honami travels with the gusts).
- **Stem rhythm:** each stem bobs at its own pace whatever the wind (lesson 7): about 1 to 2 Hz for grass and 0.5 to 1 Hz for reeds and tall grass (judged).
- **Bend at the tip** (judged): about 10° at force 3, 30° at force 5, and 50 to 60° at a gale, so the tufts show their lighter undersides.
- **This fits `grass_view.gd`:** it bends grass by the tip squared and gives tall grass and reeds 1 to 1.4 times the wind. That matches.

### Smoke

- **Calm (force 0):** a straight column.
- **Light (force 1 to 2):** the column leans and drifts.
- **Tilt from vertical** (judged; a campfire plume rises at about 1 to 2 m/s near the fire): about 30 to 45° at 1 m/s, 60 to 70° at 3 m/s, and almost flat and torn into wisps above about 6 m/s.
- **Cold, still nights:** smoke rises a few metres, then spreads flat under the cold layer and drifts downhill (night drainage, above).

### Flags, cloth, banners

All judged except the Beaufort force 3 line:
- under 1.5 m/s: hangs limp;
- 2 to 3 m/s: lifts and flops;
- 3.5 to 5 m/s: a light flag stands out (Beaufort force 3);
- 8 m/s and up: stands straight and ripples fast;
- 15 m/s and up: snaps loudly.

### Sound

- **Calm:** silent below about 1.5 m/s (`wind` < 0.12).
- **Pitch** follows thickness. Pine needles hiss high, broadleaf trees rustle in the middle, and bare branches and rock edges roar low. Each doubling of the wind raises the tone an octave (lesson 8).
- **Ridges:** louder and higher, and they whistle through rocks and gaps.
- **Lee and valley floors:** a low, distant roar from the trees above, with sudden near gusts.
- **Night drainage:** near silent.

### Animals (for MikeW, more in the animals-in-weather page to come)

- **Fur and feathers** flutter at the same Beaufort steps: the tail and the edges of the mane above force 5.
- **The wind carries smell.** The wind multiplier above changes how far a scent travels. Downwind and in a funnelling gap, smell reaches further. In the lee eddy it comes and goes.

### Never-see checks

- smoke rising straight up on a gale day, or lying flat on a calm one;
- every tree swaying in perfect time;
- a summit with less wind than the valley floor below;
- grass bobbing faster just because the wind is stronger;
- a flag stretched out on a day when the smoke goes straight up.

## How ours works today

From a grep of the code on 8 Nov. The tree shaders were not read.
- **The world wind:** `src/shared/weather.gd` gives `wind` from 0 to 1 and `wind_dir` (the way the wind blows toward). It is the same on every client. There is no prevailing direction per island yet.
- **The sound stage** (`src/client/sound_stage.gd`) works out one `wind_strength` from:
  - the world wind;
  - a gust noise (FastNoise, frequency 0.02);
  - ridge and valley exposure (a ring of ground samples, `EXPOSURE_GAIN` 0.45);
  - height (up to +0.2 at 300 m);
  - shelter from trunks within 18 m.

  The wind filter opens on ridges and closes in valleys.
- **Grass** (`grass_view.gd`) bends by tip squared with the same gusts. Each layer has its own multiplier: short grass 1, tall grass 1.4, reeds 1.
- **Wind in the trees** (`tree_wind.gd`) plays loops for pine, leaves, dry leaves and bare branches by season. **Wind in structures** (`wind_structures.gd`) whistles under lean-tos and moans at cave mouths.
- **Specks** (`wind_cue.gd`) drift with `wind_dir` so you can read the wind.
- **What's missing:** no night drainage, no lee rotor, no gap channelling, and no smoke tilt by wind (not checked).

## Sources

- Taylor, P. A. and Teunissen, H. W. (1987), The Askervein Hill project: overview and background data, Boundary-Layer Meteorology: https://data-ww3.ifremer.fr/BIB/Taylor_Teunissen_BLM1987.pdf
- WEMEP benchmark page, The Askervein isolated smooth hill: https://wemep.readthedocs.io/en/latest/windconditions/benchmarks/askervein.html
- Lubitz, W. D. (2007), review of speed-up guidelines (Taylor and Lee 1984; Finnigan 1988 separation slopes): https://research.engineering.ucdavis.edu/wind/wp-content/uploads/sites/17/2014/03/lubitz-2007.pdf
- How windbreaks work (New Mexico Environment Department copy): https://www.env.nm.gov/wp-content/uploads/sites/2/2017/02/How_windbreaks_work.pdf
- Navy Mesoscale Primer, Gap winds (University of Washington): https://atmos.uw.edu/~cliff/Navygap5.html
- AMS Glossary of Meteorology, katabatic wind: https://glossary.ametsoc.org/wiki/katabatic-wind/
- AMS Glossary of Meteorology, along-valley winds: https://glossary.ametsoc.org/wiki/along-valley-winds/
- van den Brink, H. W. (2020), An effective parametrization of gust profiles, Environmental Research Communications (KNMI): https://www.knmiprojects.nl/binaries/knmiprojects/documenten/reports/2019/11/28/parametrization-of-gust-profiles/van_den_Brink_2020_Environ._Res._Commun._2_011001.pdf
- NOAA NCEI, Land Beaufort Scale: https://www.ncei.noaa.gov/sites/default/files/2021-09/Land_Beaufort_Scale.pdf
- Jackson, T. et al. (2019), An architectural understanding of natural sway frequencies in trees, J. R. Soc. Interface: https://discovery.ucl.ac.uk/10078184/1/Jackson%20et%20al%20%282019%29%20An%20architectural%20understanding%20of%20natural%20sway%20frequencies%20in%20trees%20-%20accepted.pdf
- Modelling waving crops using large eddy simulation (FIV 2008, citing Py et al. 2006): https://eng-web77-v02.ocio.monash.edu/intranet/proceedings/fiv2008/html/pdf/120.pdf
- Wikipedia, Aeolian sound: https://en.wikipedia.org/wiki/Aeolian_sound
