# Moonlight and starlight: night light levels by moon phase, cloud and snow

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Kathleen (night light: `day_cycle.gd`, `weather_look.gd`, `docs/design/art_weather_light.md` 5.3, 6.2 and 12). **Related:** [firelight-in-weather.md](firelight-in-weather.md) (torch reach against the moon), `cave-microclimate.md` (#664, eyes adapting to the dark), `trees-in-weather.md` (#675, canopy at night).

## Night light at a glance (lux on the ground)

This is the quick reference for eye shine, animal sight and torch work. The sources and sums are in the lessons below.

**Moonlight, clear sky, by the moon's height and phase.** Our sums:
- 0.25 lux for a full moon overhead (lesson 1's top value), scaled by the sine of its height and by about 0.79 transmission for each air mass;
- phase shares from the standard phase formula (lesson 2).
They agree with the sourced "full moon 0.05 to 0.1 lux" for a moon at 20 to 35°.

| Moon height | Full | 1.6 days off full | Gibbous (3.7 days) | Quarter | Crescent (11 days) |
|---|---|---|---|---|---|
| 90° (overhead) | 0.25 | 0.16 | 0.085 | 0.023 | 0.003 |
| 60° | 0.21 | 0.13 | 0.071 | 0.019 | 0.0025 |
| 45° | 0.16 | 0.10 | 0.055 | 0.014 | 0.002 |
| 30° | 0.10 | 0.061 | 0.034 | 0.009 | 0.0012 |
| 20° | 0.054 | 0.034 | 0.019 | 0.005 | 0.0007 |
| 10° | 0.014 | 0.009 | 0.005 | 0.0013 | 0.0002 |
| 5° | 0.002 | 0.001 | 0.0006 | 0.0002 | — |

**No moon.** Clear starlight with airglow gives 0.002 lux. Overcast with no moon gives 0.0001. Overcast with a full moon gives about 0.005 to 0.03, judged as 5 to 15% of the moonlight in the table above (Wikipedia, Lux; lesson 5).

**A torch, by distance.**
- The base figure is a measured juniper torch at 21.94 lux at 40 cm (Medina-Alcaide et al. 2021, PLOS ONE). That makes it about 3.5 candela, which we spread by the inverse square.
- A campfire measured 19.2 lux at 40 cm in the same study, so it is about the same at these distances.

| Distance | 1 m | 2 m | 3 m | 5 m | 10 m | 20 m |
|---|---|---|---|---|---|---|
| Torch, lux | 3.5 | 0.9 | 0.4 | 0.14 | 0.035 | 0.009 |
| Matches | civil twilight's end | | | a full moon at 45° | a gibbous moon at 30° | a quarter moon at 30° |

- **What the tables say:**
  - past about 5 m a torch is no brighter than a high full moon;
  - past about 10 m it is no brighter than a gibbous moon;
  - on a full-moon night, a torch adds little beyond 5 m. Its use is the near pool and the eyes it lights (`firelight-in-weather.md`);
  - on a moonless night, even 20 m of torchlight (0.009 lux) is about four times clear starlight.
- **Eye shine** needs a light near the viewer's eye and an animal facing it. Judged: it reads out to where the torch's light on the animal still beats the moon's, about 10 to 20 m on a moonless night and about 5 m under a full moon.

## Lessons (read these first)

1. **Real night light covers a range of about 3,000 to 1.** These are typical horizontal illuminances (Wikipedia, Lux; American Meteorological Society glossary):

   | Sky | Lux |
   |---|---|
   | sunrise or sunset, clear | 400 |
   | end of civil twilight (sun 6° down) | 2 to 3.5 |
   | full moon, clear | 0.05 to 0.3 (typically 0.05 to 0.1; up to 0.32 for a high perigee moon in the tropics) |
   | quarter moon, clear | 0.01 |
   | end of nautical twilight (sun 12° down) | 0.008 |
   | moonless, clear, with airglow | 0.002 |
   | end of astronomical twilight (sun 18° down) | 0.0006 |
   | moonless, overcast | 0.0001 |

   - At the end of civil twilight, a clear sky was historically "just adequate for doing outdoor work without artificial illumination". At its end, "the brightest stars" show.
   - At the end of nautical twilight "the horizon is generally invisible".

2. **A half moon gives only about a twelfth of the full moon's light, not half.**
   - The full moon is magnitude −12.7 and the first quarter −10.0. At first and third quarter the moon is "only about 8% of full Moon", a 12-times drop (Astronomical League, *How bright is the Moon?*).
   - The moon brightens sharply in the last few days before full. The standard phase formula (Allen) is m = −12.73 + 0.026α + 4 × 10⁻⁹α⁴, where α is the phase angle in degrees, 0 at full. It gives the 8% at quarter as a check:

     | Days from full | Phase angle | Lit share of the disc | Light, share of full |
     |---|---|---|---|
     | 0 | 0° | 100% | 100% |
     | 1.6 | 20° | 97% | 62% |
     | 3.7 | 45° | 85% | 34% |
     | 7.4 (quarter) | 90° | 50% | 9% |
     | 11 | 135° | 15% | 1.2% |
     | 12.3 | 150° | 7% | 0.4% |

   - The full moon is about 1/380,000 as bright as the sun, and reflects about 14% of the light that falls on it (Wikipedia, Moonlight).

3. **Moonlight is not blue. The eye makes it look blue.**
   - Moonlight's spectrum has "slightly more red light than daylight". The blue look "is actually an illusion due to the Purkinje effect" (Wikipedia, Moonlight).
   - Rods see best at about 498 to 507 nm, which is blue-green. In dim light, blues look brighter and reds darker (Wikipedia, Scotopic and Mesopic vision).

4. **Colour fades by moonlight and is gone by starlight.**
   - **Mesopic vision** runs from about 0.001 to 3 cd/m². In it, colours are "desaturated", reds dim and blues brighten, and "spatial acuity decreases" with the light.
   - **Scotopic vision** is below about 0.001 cd/m². Colours are "barely perceptible" and fine detail is lost (Wikipedia, Mesopic vision; Scotopic vision).
   - **Our sums for grass** (luminance = lux × reflectance ÷ π, grass reflectance 0.25):

     | Light | Lux | Grass, cd/m² | Vision |
     |---|---|---|---|
     | Full moon | 0.1 | about 0.008 | low mesopic: faint colour, shapes clear, can't read small print |
     | Quarter moon | 0.01 | about 0.0008 | scotopic: grey, outlines only |
     | Clear starlight | 0.002 | 0.00016 | scotopic: the path is a paler strip, trees are shapes against the sky |
     | Overcast, no moon | 0.0001 | 0.000008 | near the floor of vision: almost nothing |

5. **In the wild, clouds make the night darker.**
   - Near towns, clouds reflect city light back down, so overcast nights there are up to 18 times brighter.
   - At dark sites "clouds darken the night sky", and the darkest nights are the overcast ones (Kyba et al. 2015, *Scientific Reports*).
   - Moonless overcast (0.0001 lux) is about 20 times darker than moonless clear (0.002 lux) (lesson 1).

6. **Snow makes a moonlit night three to four times brighter.**
   - Fresh snow reflects 0.8 to 0.9 of the light. Green grass reflects 0.25, conifer forest 0.09 to 0.15, and open water 0.06 (Wikipedia, Albedo).
   - A snowfield under a full moon is about as bright to the eye as grass under a moon twice as strong. A dark conifer forest beside it is almost black.

## Judged numbers for our night (for `day_cycle.gd` and `weather_look.gd`)

The game maps light to the screen, so these are shares, not lux. "Never pitch black outdoors" (decided 8 Nov) stays: every value below sits on or above `OUTDOOR_FLOOR`.

### Moonlight by phase

- **Today:** `moon_light_at` uses lit share^1.5 (`MOON_FALLOFF`).
  - A quarter moon gives 35% of the full moon. The real value is 9%.
  - A moon 45° from full gives 79%. The real value is 34%.
- **Suggestion:** use the standard phase formula directly. `alpha` is the phase angle in degrees, from 0 at full to 180 at new:

  ```
  var alpha: float = absf(phase - 0.5) * 360.0
  return pow(10.0, -0.4 * (0.026 * alpha + 4.0e-9 * pow(alpha, 4.0)))
  ```

- **What it means for play:**
  - nights brighter than about a third of full come only within about ±4 days of the full moon, so 7 to 8 nights a month;
  - the half-moon nights are dim;
  - more of the month is torch weather, which fits the "eye nights" design.

### Where the moon is

- **Today:** the moon is always opposite the sun, so every phase's moon is up all night.
- **Real:**
  - a waxing crescent sets a few hours after sunset;
  - the first quarter sets about midnight;
  - the full moon is up all night;
  - the last quarter rises about midnight;
  - the moon rises about 50 minutes later each day.
- **Simple rule:** put the moon at the sun's place, turned back by (phase × 360°) around the same path. At phase 0.5 that is the current opposite. Moonlight is then zero when the moon is below the horizon, so the evening after a first quarter turns dark at midnight.
- The full moon rides high in winter and low in summer. The current opposite-the-sun rule already gives that.

### Clouds and weather on the moonlight

| Sky | Moonlight left | Star and sky glow left |
|---|---|---|
| Clear | 100% | 100% |
| Thin, high cloud | 50 to 80%, with a halo | 30 to 60% |
| Broken cloud | patchy, 20 to 100% as clouds pass | 50% |
| Overcast | 5 to 15% (the disc is not seen) | 5 to 10% (lesson 5) |
| Fog, rain, snowfall | as overcast, and less with distance (`firelight-in-weather.md`) | as overcast |

- Overcast with no moon is the darkest outdoor night, so it should sit at `OUTDOOR_FLOOR`.
- Full moon on a clear night over fresh snow is the brightest.

### Ground brightness at night (multiply the moon and sky light)

- **By ground:** fresh snow ×3.5, sand or bare rock ×1.5, grass ×1, bare soil ×0.7, forest floor under the crown ×0.5 or less (the existing `CANOPY_NIGHT_DIM` 0.45), water ×0.25. On water, the moon's glitter path is the only bright thing.
- **Colour (judged):**
  - from a full moon down to about a third of it, keep a little colour;
  - below that, go grey;
  - lift the blues and dim the reds slightly as it darkens (Purkinje), rather than tinting the whole picture blue.
  - The current `MOON_COLOR` of (0.62, 0.72, 1.0) is the film convention for "night". It reads fine, and the real eye effect is similar.

### Twilight (sun below the horizon)

| Sun | Share of the sunset light | What is seen |
|---|---|---|
| 0° to −6° (civil) | 100% to about 1% | work possible without light at the end; brightest stars appear |
| −6° to −12° (nautical) | 1% to 0.002% | the horizon fades; a full moon outshines what is left |
| −12° to −18° (astronomical) | down to starlight | full night |

- At mid-latitudes civil twilight lasts about 30 to 40 minutes, and nautical another 35 to 45 (judged, it varies with season).
- The game fades the sun out between `up` −0.02 and −0.08 and brings night in by −0.2, a sun angle of about 1° to 11° below. That is close to the real civil and nautical stages.

## Never-see checks

1. A half moon lighting the land almost as well as a full moon.
2. A thin crescent high in the sky at midnight.
3. A cloudy night brighter than a clear moonless one, in the wild.
4. Bright saturated colours by moonlight.
5. A moonlit snowfield as dark as the forest beside it.
6. Pitch black outdoors. The game's own rule; the floor holds.

## How ours works today (read from the code, 8 Nov, not tested)

- **`day_cycle.gd`:**
  - `MOON_ENERGY` 0.22 of the sun's light energy at full moon, colour (0.62, 0.72, 1.0);
  - the phase runs on `SYNODIC_DAYS` 29.53, with a full moon on game day 100 (`MOON_FULL_DAY`), the day a world starts;
  - `moon_light_at` = lit share^1.5;
  - the stars are 1.35 times brighter on a moonless night (`STARS_DARK`);
  - `AMBIENT_NIGHT` 0.24 of the day's ambient;
  - the moon is always opposite the sun.
- **`weather_look.gd`:**
  - `AMBIENT_FLOOR` 0.32 and `AMBIENT_STORM_FLOOR` 1.1, with the "never pitch black outdoors" `OUTDOOR_FLOOR` rule;
  - `CANOPY_NIGHT_DIM` 0.45 under crowns at night;
  - `TORCH_NIGHT_DIM` 0.15 when a flame is held;
  - exposure 1.1 clear and 0.95 in storm, with AgX tone mapping (`look_settings.gd`).
- **Not modelled:**
  - the moon setting or rising with its phase;
  - moonlight cut by cloud separately from the storm darkness;
  - snow brightening the night;
  - colour fading at low light.

## Sources

- Wikipedia, Lux (illuminance examples): https://en.wikipedia.org/wiki/Lux
- Wikipedia, Moonlight: https://en.wikipedia.org/wiki/Moonlight
- Astronomical League, How bright is the Moon?: https://asterism.org/?p=728
- American Meteorological Society glossary, Civil twilight: https://glossary.ametsoc.org/wiki/civil-twilight/
- American Meteorological Society glossary, Nautical twilight: https://glossary.ametsoc.org/wiki/nautical-twilight/
- American Meteorological Society glossary, Astronomical twilight: https://glossary.ametsoc.org/wiki/astronomical-twilight/
- Wikipedia, Mesopic vision: https://en.wikipedia.org/wiki/Mesopic_vision
- Wikipedia, Scotopic vision: https://en.wikipedia.org/wiki/Scotopic_vision
- Kyba, C. C. M. et al. (2015), Worldwide variations in artificial skyglow, Scientific Reports 5, 8409: https://link.springer.com/content/pdf/10.1038/srep08409.pdf
- Wikipedia, Albedo: https://en.wikipedia.org/wiki/Albedo
- Medina-Alcaide et al. (2021), The conquest of the dark spaces: an experimental approach to lighting systems in Paleolithic caves, PLOS ONE (torch and fire lux): https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0250497
