# Torch and campfire light in fog, rain and snow

**Last checked:** 2026-11-08 (web research by Jamie). **System owners:** Kathleen (night light and weather look, `docs/design/art_weather_light.md`, #601 night light, #603 and #608 fog). **Related:** [torches-fire.md](torches-fire.md) (torch rules, burn time, rain douse), `sound-outdoors.md` (#642), `snow-on-slopes.md` (#632).

"Our sums" means arithmetic done here from a sourced formula. "Judged" means no source was found today.

## Lessons (read these first)

1. **Firelight is dim and close. A torch does useful work out to about 3 m, and you see shapes out to about 10 m.**
   - **Medina-Alcaide et al. (2021, PLoS ONE)**, replica Palaeolithic lights in a cave:
     - **Wooden torches:** on average 16.9 lux at 40 cm, with a working radius of about 3.0 m. They burned 19 to 61 minutes, 41 on average. Swinging a torch fans the flame: at 20 cm it went from 5 to 28 lux. The intensity was about 3.5 cd (one torch was reported as 14 cd, but the table says 3.5).
     - **Fat lamps:** about 3 to 3.7 lux at 40 cm and about 0.7 lux at 1 m, with a working radius of about 1.5 m. A torch is "almost five times more intense than a grease lamp".
     - **A small fireplace:** 19.2 lux at 40 cm, a working radius of about 3.3 m and up to 4.5 m.
     - **Firelight colour:** about 1,000 to 3,000 K.
   - **Open hearths about 1 m across** (Hoare 2025, EXARC Journal), average lux at 1 m by wood: ash 51, birch 46, beech 27, larch 26, spruce 23, pine 20, oak 6.
   - **Our sums** (inverse square from those intensities):

     | Light | 3 m | 6 m | 10 m | 20 m | 40 m |
     |---|---|---|---|---|---|
     | Torch, 3.5 cd | 0.39 lux | 0.10 | 0.035 | — | — |
     | Torch, fanned, 14 cd | 1.6 | 0.39 | 0.14 | 0.035 | — |
     | Good campfire (ash, about 50 cd) | 5.6 | 1.4 | 0.5 | 0.13 | 0.03 |

     Full moonlight is commonly quoted at about 0.1 to 0.3 lux (not checked today). So a torch lights the ground like a full moon at about 6 m. A good campfire does so at about 20 m. Beyond that, eyes adapted to the dark still pick out pale shapes.
2. **Fog scatters light. The visual range is 3.912 divided by the extinction coefficient.**
   - **Koschmieder's rule** (Visibility, encyclopedia entry): visual range = 3.912 / extinction, for a 2% contrast threshold.
   - **Met Office** ("Fog"): fog is visibility under 1,000 m, thick fog under 180 m, and dense fog under 50 m.
   - **Our sums:** dense fog of 50 m has an extinction of 0.078 per metre. Torchlight that goes 10 m to a rock and back loses 1 − e^(−1.56), about 80%. In thick fog of 180 m it loses about 35%.
3. **Your own light in fog throws a veil back into your eyes, and that hides more than the fog does.**
   - **Visual Expert** (weather and visibility page): in fog, more light from high beams mostly "scatter[s] more light back to the eye and actually decrease[s] visibility". In rain the backscatter "acts as a veil and reduces contrast of everything in the field of view", and it also glares.
   - Low lights that throw their beam along the ground do better.
   - **Our reading:** a torch held high in thick fog makes a glowing ball around the bearer and hides the ground beyond it. Held low, it shows more of the path.
4. **A light seen through fog or mist wears a halo. Small droplets make big halos.**
   - **Wikipedia, "Corona (optical phenomenon)":** the halo is diffraction by droplets. Its inner disc, the aureole, is "bluish-white" and fades "to reddish-brown towards the edge". It shows coloured rings when the droplets are all one size. "Smaller particles generally produce larger coronae."
   - **Our sums** with the first ring at about 1.22 × wavelength / droplet size: about 4° for 10 µm fog droplets and about 2° for 20 µm mist droplets.
   - For a fire's orange light, the halo is orange-white, reddening outward.
5. **Rain barely dims light at torch distances. It shows as lit streaks, and it puts open flames out.**
   - **Rain and visibility** (Atmósfera vol. 39, measured meteorological optical range against rain rate): visibility is about 19.5·R^−0.77 km and 13·R^−0.58 km at two sites. That is about 3.4 km at 10 mm/h and about 1 km at 50 mm/h. Shipley et al. (1974) give an extinction of 0.16·R^0.74 per km.
   - **Our sums:** at 10 mm/h, light loses under 2% over 10 m. So rain does not shorten the torch's reach. What you see is drops lit near the flame, and the ground turning dark and shiny.
   - **Game rule:** torches and fires go out in open rain (`torches-fire.md`).
6. **Falling snow hides more than rain, and lying snow throws your light back.**
   - **US Federal Meteorological Handbook No. 1, Table 8-4:** snow is light when visibility is over ½ mile (800 m), moderate from ¼ to ½ mile (400 to 800 m), and heavy at ¼ mile (400 m) or less.
   - **Our sums:** heavy snow at 400 m gives an extinction of about 0.01 per metre, about 10% lost each way over 10 m.
   - **What it looks like:** snowflakes are large, bright scatterers, so a torch lights a sparkling sphere of falling flakes around the bearer.
   - **Lying snow** reflects most of the light back (fresh snow albedo is commonly quoted at 0.8 to 0.9; not checked today), so firelight over snow reaches much further than over dark ground.

## Judged numbers for the game

### Reach of the light (what the player can make out at night)

Clear air, no moon:

| Light | Lit like day work | Ground and paths clearly | Pale shapes only | Its glow seen from |
|---|---|---|---|---|
| Torch | 3 m | 6 to 8 m | 10 to 12 m | 1 to 3 km |
| Campfire (good wood) | 5 m | 10 to 15 m | 20 to 30 m | 2 to 5 km |
| Small fire, or oak | 2 to 3 m | 5 m | 10 m | 1 to 2 km |
| Fat lamp (later) | 1.5 m | 3 m | 5 m | under 1 km |

- **The game's torch `light_m`** (9 on main, Sal's 12 pending) is about right as the reach of the light's falloff ("pale shapes"). The bright core should be about the first quarter of that (judged, lesson 1).
- **Wood matters:** ash and birch are bright, pine is middling, and oak is dull (lesson 1). That would suit a later firewood choice, but it is not needed now.

### Fog (lessons 2 to 4)

The torch's useful reach against the fog's visibility (judged):

| Fog | Visibility | Torch reach | Halo | Look |
|---|---|---|---|---|
| Mist | 1 to 2 km | unchanged | faint, about 2° | almost none |
| Fog | 200 to 1,000 m | about −10% | clear | a soft glowing sphere 1 to 2 m round the flame |
| Thick | 50 to 180 m | about −30% | strong | a bright sphere 3 to 5 m across, held high it veils the ground |
| Dense | under 50 m | about −50% | very strong | a lit room of fog round the bearer, the ground beyond hidden |

- **Torch height:** held high (the game's carry pose has the flame above head height) gives more veil. Lowered or set in the ground, the path shows further. A "lower torch in fog" pose is a nice later touch.
- **A far fire seen through fog:** within about 1 times the visibility it is a point with a halo. At 1 to 3 times, a soft glow with no point. Beyond 3 times, nothing.
- **Today:** `held_item.gd` sets `light_volumetric_fog_energy = 0` on both torch lights ("no glowing ball in the fog around the hand"). In real thick fog that glowing ball is right. A small value only when the fog is thick (visibility under about 200 m), about 0.2 to 0.4, would match lesson 3. That needs Dino pictures first.

### Rain (lesson 5)

- **The reach of the light:** unchanged.
- **Drops:** lit drops show as short warm streaks within 2 to 4 m of a flame under cover, at a lantern, or at a sheltered fire.
- **Wet ground:** darker by about a third, and it shows bright specular glints of the flame (judged).
- **Open flames** go out (the existing rule). A fire under a lean-to keeps burning and lights the rain falling at its edge.

### Snow (lesson 6)

- **Falling snow:**
  - **Light snow:** the torch lights a few flakes near the bearer.
  - **Heavy snow:** a sparkling sphere about 3 to 5 m across. The reach drops about 20% (judged), and the flakes glint orange.
- **Lying snow:** the light reaches about 1.5 to 2 times further over fresh snow than over grass or soil (judged from the albedo). Snow glows orange in firelight with blue-grey shadows.
  - **Example:** a campfire on snow lights a ring about 1.5 times wider.
- **Snow on the ground with fog:** the brightest, most closed-in night look. Use it as the never-too-dark check.

### Colour

- **Flame light:** about 1,800 to 2,000 K for a campfire and about 1,500 to 1,800 K for a torch (judged inside the sourced 1,000 to 3,000 K).
- **Fog and snow** take on the flame's colour close in and fade to the night's blue-grey further out.

### Never-see checks

- a torch in dense fog that lights the far ground as on a clear night;
- a clean point of light with no halo through thick fog;
- rain making the torch's reach shorter (it shouldn't), or a torch burning on in open rain;
- a campfire on fresh snow lighting no more than on grass;
- a torch lighting a whole valley side, more than about 15 m clearly.

## How ours works today

From reading the code headers on 8 Nov:
- **The torch** (`held_item.gd`): an `OmniLight3D` with `omni_range` = the item's `light_m` (9 by default), plus a short hand light (1.6 m) so the hand is not black. Both set `light_volumetric_fog_energy` to 0.
- **The weather look** (`weather_look.gd`): ordinary fog density and colour follow the day and the weather (`fog_density`, `fog_light_color`, `fog_aerial_perspective`). Volumetric fog was not found in use.
- **Fire rules** (`flame_rules.gd`): open rain at 0.2 or more douses after a 5 s grace (`torches-fire.md`).
- **What's missing:** no halo or fog glow around flames, no lit rain streaks, no extra reach over snow, no change by wood. Not checked: the campfire light's own range in `fire_sounds.gd` and the placed fire look.

## Sources

- Medina-Alcaide, M. Á. et al. (2021), The conquest of the dark spaces: an experimental approach to lighting systems in Paleolithic caves, PLoS ONE 16(6): e0250497: https://core.ac.uk/download/492648507.pdf
- AIP Inside Science (2021), Scientists recreate Stone Age lamps and torches: https://www.aip.org/inside-science/scientists-recreate-stone-age-lamps-and-torches-to-see-how-ancient-artists-illuminated-caves
- Hoare, S. (2025), light output of open wood fires, EXARC Journal: https://exarc.net/ark:/88735/10799
- Visibility (encyclopedia entry with the Koschmieder formula): https://cavac.at/cavacopedia/Visibility
- Met Office, Fog: https://metoffice.gov.uk/learning/fog
- Visual Expert, weather and visibility: https://www.visualexpert.com/Resources/weather.html
- Wikipedia, Corona (optical phenomenon): https://en.wikipedia.org/wiki/Corona_(optical_phenomenon)
- The influence of rainfall on the extinction coefficient and the meteorological optical range, Atmósfera 39: https://www.scielo.org.mx/pdf/atm/v39/0187-6236-atm-39-53491.pdf
- US Federal Meteorological Handbook No. 1, chapter 8 (Table 8-4, snow intensity by visibility): https://webarchive.library.unt.edu/eot2008/20090115024600/http:/www.ofcm.gov/fmh-1/pdf/H-CH8.pdf
