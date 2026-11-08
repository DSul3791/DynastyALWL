# Sound outdoors: distance, wind, night, rain, snow, fog, forest, echoes and rivers

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Kathleen (the sound stage and how the world sounds); Jason (audio). **Related:** `wind-over-terrain.md` (#637, local wind and night drainage), [warmth-weather.md](warmth-weather.md), `src/client/sound_stage.gd`, `sound_occlusion.gd`, `air_bands.gd`.

"Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found today.

## Lessons (read these first)

1. **Distance: a small source loses 6 dB each time the distance doubles. A long river or a shoreline loses about 3 dB.**
   - That is standard spreading: a point source spreads over a sphere, so its level falls by 20·log10(distance). A long line source spreads over a cylinder, so its level falls by 10·log10(distance), until you are far enough away that the line looks short.
   - **Our reading:** a river reach or a beach heard from beside it should fade more slowly than a fire or a call.
2. **Air eats the high end. Cold, dry air eats more of it.**
   - **Our sums** with the ISO 9613-1 formula (as given at sengpielaudio.com, "Air damping formula"), loss in dB per km:

     | Air | 125 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
     |---|---|---|---|---|---|---|
     | 20 °C, 70% humidity | 0.3 | 2.8 | 5.0 | 9.0 | 23 | 78 |
     | 10 °C, 80% (a starter island day) | 0.4 | 2.0 | 3.6 | 8.8 | 29 | 105 |
     | 0 °C, 80% | 0.4 | 1.5 | 4.1 | 14 | 49 | 148 |
     | −10 °C, 70% | 0.3 | 2.6 | 9.2 | 28 | 59 | 86 |

   - **What it means:** air barely touches anything up to 1 kHz within a few hundred metres. Above 4 kHz, a sound 500 m away loses 15 to 50 dB of its top.
   - **That fits the game's distance low-passes** (`air_bands.gd`: falls 6 → 3 → 1.4 kHz at 110 / 260 / 520 m, thunder 1.6 kHz past 600 m). In frost the high end should go about twice as fast.
3. **Wind bends sound: toward the ground downwind, and up over your head upwind.**
   - **Waddington and Lam** (Institute of Acoustics, "The effect of weather conditions on the propagation of sound"):
     - Downwind, levels rise "by a few dB" with even 1 m/s of wind behind the sound.
     - Upwind or crosswind, "level decreases in excess of 20 dB may result". The shadow deepens quickly up to about 4 m/s against you, then levels off.
     - Further out (224 m to 1 km) the upwind shadow is weaker, because turbulence scatters sound back into it.
     - The weather matters little within about 100 m, except above 2 kHz.
4. **On clear, calm nights, sound carries further over cold air.**
   - **The cause:** the cold air lies at the ground with warmer air above it, an inversion, and this bends sound back down.
   - **COMSOL model** ("Why sounds travel farther at night"): a trumpet heard 500 m away was more than 5.5 dB louder at night (ground 9 °C, air above 19 °C) than by day, across 125 to 2,000 Hz.
   - **Standard correction** (ISO 9613-2, per Waddington and Lam): weather corrections lie in a 0 to 5 dB band. A "well-developed moderate ground-based temperature inversion as commonly occurs on clear nights" is the case the standard plans for.
5. **Rain masks sound. Rain on leaves is louder than rain on gravel.**
   - **Kobe University study** of measured rain noise:
     - The level rises about 10 dB for every tenfold increase in rainfall with artificial rain, and 15 to 20 dB with natural rain.
     - Rain adds mostly above 500 Hz to 1 kHz. At 30 mm/h it is "almost flat within the range of 1–4 kHz" and falls off above that.
     - The site where rain hit tree leaves was 5 to 10 dB louder than the gravel site.
   - **Our reading:** rain fills the very band where birdsong, footsteps, rustles and small calls live.
6. **Fresh snow absorbs sound like an acoustic panel. Packed snow and ice reflect it.**
   - **Acentech, "The quiet snow":** a 4-inch (10 cm) layer of snow measured an NRC of 0.89, "similar to high performing acoustical panels". Fresh snow absorbs more than compacted snow, ice or frozen grass.
   - So after fresh snow, sound fades faster with distance. As the snow settles, crusts or freezes, the world gets louder again.
7. **Fog does not help sound carry. The droplets damp the high notes, and low sounds like foghorns carry best** (University of Wisconsin SSEC, "Does sound travel better in fog?").
   - **Our reading:** a foggy morning feels quiet because fog comes with calm air and a cold layer at the ground (#608). The calm removes wind noise, and the cold layer can bend far sounds down (lesson 4). So fog is quiet nearby, but a low far sound (a cowbell, a horn, a dog) can be clear.
8. **Forest takes sound away, a little low down and a lot up high.**
   - **Martens, "Sound propagation in forests"** (Institute of Acoustics): temperate woods add about 3 dB per 100 m at 100 Hz, rising to about 25 dB per 100 m at 5 kHz. Some stands add a fairly even 20 dB per 100 m up to 2 kHz. The results vary a lot with the soil, the plants and the source.
9. **An echo is heard as separate when it arrives at least 50 ms after the sound, and clearly so at 100 ms** (SFU Handbook for Acoustic Ecology, "Echo").
   - **Our sums** (sound at about 337 m/s at 10 °C):
     - a 50 ms delay needs a cliff at least 8.5 m away, and 100 ms needs about 17 m;
     - a cliff 170 m away gives a 1 s echo;
     - thunder is about 3 s per km.
10. **Moving water is the loudest natural sound. It fades a lot within 100 to 200 m.**
    - **Yosemite National Park sound survey** (Merced River plan, Appendix F, 1999), in dBA:
      - Vernal Fall mist trail: 75.5. Atop Vernal Fall: 65.5. Atop Nevada Fall: 60.5.
      - Granite cascades at the river edge: 53.5 to 56.
      - Beside the South Fork with "a few minor rapids and cascades" (distance from the river not given): 44. About 30 m off the river with "distant river rapids": 35.5.
      - About 60 m from the river: 40.5. A campground about 210 m from the river: 40.
      - Lake shore with no sounds: 30.5 (near the meter's floor).
    - **Quietest natural nights** (2005-06 medians): 18 to 26 dB at alpine, subalpine and conifer sites, against 28 to 29 dB by day.

## Judged numbers for the game

The weather inputs come from `weather.gd` (`wind`, `wind_dir`, `rain`, `snow`, `cloud`, `temp_c`). The wind's m/s mapping is in `wind-over-terrain.md` (m/s = 20 × wind^1.3).

### Distance

- **Point sources** (a fire, an animal, an axe, a voice): inverse distance (6 dB per doubling), as today.
- **Line sources** (a river, a beach, a long falls lip): 3 dB per doubling out to about the reach's length divided by 3, then 6 dB. In practice this means several emitters along the bank instead of one at the nearest point (judged).
- **High-end loss:** the distance low-pass should close about twice as fast below 0 °C as at 10 °C (lesson 2). Fog adds a small extra cut above 2 kHz (judged: about 20% lower cutoff).

### Wind (only past about 100 m, lesson 3)

The change in level for a sound more than 100 m away, by where the listener stands:

| Listener stands | Change in level |
|---|---|
| Downwind of the source | +2 to +4 dB once the wind is above about 1 m/s (`wind` ≥ 0.1) |
| Crosswind | −3 to −8 dB |
| Upwind, wind 4 m/s or more (`wind` ≥ 0.3) | −10 to −20 dB, with a lower cutoff. It comes and goes with the gusts as turbulence scatters some back |

- **Near sounds:** under 50 m, the wind changes nothing except masking.
- **Wind noise as a mask:** above `wind` 0.5, the wind's own noise hides quiet sounds more than 30 m away. A snapped twig or a soft call 40 m off is lost in a gale (judged).

### Night (lesson 4)

- **When:** clear, calm nights (`cloud` < 0.4, `wind` < 0.3), from an hour after sunset to an hour after sunrise.
- **What:** sounds 200 m to 2 km away are 3 to 6 dB louder, and the distance cutoff is a little higher. Distant water, a far dog or wolf, or a fall across the valley come up at night.
- **Calm makes it quiet:** the bed noise drops to 18 to 26 dB against about 28 dB by day (lesson 10), so the same far sound is heard from farther off.

### Rain (lesson 5)

| `rain` | Rain bed (judged) | Masks |
|---|---|---|
| 0.15 drizzle | 35 to 40 dBA | small sounds beyond 30 m |
| 0.4 moderate | 45 to 50 dBA | beyond 15 m |
| 0.7 heavy | 55 to 60 dBA | beyond 8 m |
| 1.0 downpour | 60 to 65 dBA | beyond 5 m |

- **Leaves:** add 5 to 10 dB under broadleaf trees in leaf (lesson 5), and less under conifers and bare trees.
- **What gets masked:** rain masks sounds in its own band (1 to 4 kHz). Low sounds (a river, thunder, a bear's growl, a big fall) still come through. Birdsong stops anyway (`animals-in-weather.md`).
- **Masking rule** (judged, the usual psychoacoustic rule): a sound more than about 10 dB below the rain in its own band is not heard.

### Snow (lessons 6 and 2)

- **Snow falling, and the first day of fresh snow:**
  - distant sounds 3 to 6 dB down;
  - a high cut over open snow (judged: −30% cutoff past 50 m);
  - footsteps a soft crunch.
- **After about 2 days** (settled, crusted or frozen): back to normal. Icy crust is a little brighter than bare ground.
- **Today:** the game's `snow_hush` takes 3 to 4 dB off the buses and cuts the wind's high end. That matches. It should ease out as the snow ages, not only when it stops falling (judged).
- **The cold makes it brighter close up:** in frost, near sounds keep their crispness, because air loss matters only over distance. A crack of ice or a snapped twig in frost should sound sharp.

### Fog (lesson 7)

- **Nearby:** quieter, because the air is calm and there is no wind noise.
- **High end:** a small high cut beyond about 100 m.
- **Low far sounds:** clear, and helped by the cold layer, as at night.
- **Never:** fog that muffles everything like a blanket.

### Forest (lesson 8)

The extra loss in dB per 100 m of woods between the source and the listener:

| Band | Extra loss per 100 m |
|---|---|
| Low (around 100 Hz) | 3 to 5 dB |
| Mid (1 kHz) | 10 to 15 dB |
| High (4 to 5 kHz) | 20 to 25 dB |

- **Today:** the occlusion lowers the cutoff to 45% for forest. A level loss of about 10 dB per 100 m of trees is missing (judged from the table).
- **Inside the forest at night:** the low roar of wind in the canopy above (`wind-over-terrain.md`), with sheltered quiet below.

### Echoes (lesson 9)

- **When:** only off bare rock faces (cliffs, gorge walls, crags) more than about 17 m high and 17 m or more away, and only for sharp sounds (a shout, an axe, a shot, a dropped stone, thunder).
- **Delay:** 2 × distance ÷ 337 m/s. A gorge 30 m wide gives about 0.18 s, and a cliff across a lake 300 m away gives about 1.8 s.
- **Level** (judged): 10 to 15 dB below the direct sound at 50 m, and 20 to 25 dB below at 300 m, darker each time.
- **Repeats:** two parallel walls (a gorge) give 2 or 3 repeats, each 6 to 10 dB softer.
- **Snow-covered faces** echo less, by about −5 dB (lesson 6, judged size).
- **Never:** an echo in open forest, on a grassy hillside, or from a wall under 10 m.

### Rivers and falls (lesson 10)

Level by where you stand, in dBA (judged from the Yosemite readings):

| Where | dBA |
|---|---|
| At a big fall's foot in the spray | 70 to 80 |
| At the lip of a big fall | 60 to 65 |
| At the edge of rapids or cascades | 53 to 58 |
| 30 m from a river with small rapids | about 35 to 44 (use 40) |
| 60 to 200 m away | 40, then fading into the bed |
| A calm lake or a still pool | under 30, and silent |

- **Flow:** a river in spate is louder by about 3 to 6 dB for each doubling of flow (judged).
- **Downstream of falls:** foam and rapids carry the sound downstream (`foam-falls-rapids.md`, #623).
- **Nights:** the same river is heard from about twice as far away on a calm night (bed and inversion, above).
- **Never:** a roar over a calm lake. That is the open bug, which R7 fixes by its cause.

### Never-see (never-hear) checks

- a far sound just as loud upwind as downwind on a windy day;
- birdsong or small rustles 30 m off heard clearly through heavy rain;
- a crisp echo in open woodland;
- snow that muffles sound for weeks after it fell;
- a night valley louder in the wind than by day, when the night is calm;
- a river that sounds the same 10 m and 200 m away.

## How ours works today

From reading the code headers on 8 Nov:
- **Distance:** `sound_3d.gd` players use inverse distance (`unit_size`, `max_distance`) and a distance low-pass (`attenuation_filter_cutoff_hz`, 5 kHz by default).
- **Big far sounds:** `air_bands.gd` moves falls, fires and thunder into low-passed bands by "effective distance". The distance is stretched by forest (up to +0.6 at 80 m), by a hill in the way (+1.2), by a roof (+0.8) and by a cave (+1.5).
- **Muffling:** `sound_occlusion.gd` lowers each world sound's cutoff for forest (down to 45%) and for ground in the way (a voxel ray, Mid and High only).
- **The sound stage** (`sound_stage.gd`):
  - wind loudness from the world wind, gusts, ridge and valley exposure and trunk shelter;
  - a fire ducks the wind and surf by 9 dB within 6 to 25 m;
  - `snow_hush` takes 3 to 4 dB off the Wind, Nature and Surf buses, 3 dB off steps, and 30% off the wind's high end;
  - caves have their own reverb (`cave_sounds.gd`).
- **What's missing:**
  - no wind direction effect on far sounds (upwind shadow, downwind carry);
  - no night carry;
  - no rain masking of other sounds;
  - no outdoor echoes off cliffs;
  - no line-source rivers;
  - no temperature effect on the high end.

  Not checked: `weather_sounds.gd` and `water_sounds.gd` in full.

## Sources

- ISO 9613-1 air absorption formula, as given by sengpielaudio, Air damping formula: https://sengpielaudio.com/AirdampingFormula.htm
- Waddington, D. C. and Lam, Y. W., The effect of weather conditions on the propagation of sound, Institute of Acoustics proceedings: https://www.ioa.org.uk/system/files/proceedings/dc_waddington_yw_lam_the_effect_of_weather_conditions_on_the_propagation_of_sound.pdf
- COMSOL blog, Why sounds travel farther at night: https://www.comsol.com/blogs/why-sounds-travel-farther-at-night
- Rain noise measurements (Kobe University repository): https://da.lib.kobe-u.ac.jp/da/kernel/90009294/90009294.pdf
- Acentech, The quiet snow: https://www.acentech.com/resources/the-quiet-snow/
- University of Wisconsin SSEC, Does sound travel better in fog?: https://wxguys.ssec.wisc.edu/?p=475
- Martens, M. J. M., Sound propagation in forests, Institute of Acoustics: https://www.ioa.org.uk/system/files/publications/MJM%20MARTENS%20SOUND%20PROPAGATION%20IN%20FORESTS.pdf
- Simon Fraser University, Handbook for Acoustic Ecology, Echo: https://www.sfu.ca/sonic-studio-webdav/cmns/Handbook/Echo.html
- National Park Service, Yosemite Merced River Plan DEIS, Appendix F (soundscape measurements): https://www.nps.gov/yose/learn/management/upload/mrp-deis-appendix-f-web.pdf
- Outdoor sound propagation overview (Canadian Acoustics, ground and refraction concepts): https://jcaa.caa-aca.ca/index.php/jcaa/article/download/1603/1350/1740
