# Valley fog: height fog with a mist value

Jamie, 8 Nov 2026. This builds item 1 of Kathleen's fog table in `docs/design/art_weather_light.md` (#598, section 7). It follows the coordinator's decision 6 of 8 Nov 2026: height fog and a `mist` value in the weather state, valley fog first. Her document stays the source of truth for the look. This note only adds the numbers and limits the code needed.

## What the real thing does

- **Radiation fog** forms on calm, clear nights. The ground loses heat to a clear sky, the air touching it cools to its dew point, and the cold air drains into low ground.
- It is thickest around dawn and burns off from the edges 1 to 3 hours after sunrise.
- It is most common in autumn, when nights are long and the air is still moist.
- Wind mixes it away. Cloud stops the ground cooling. Rain is a different kind of murk (rain haze, already built).
- Radiation fog is usually tens of metres to a few hundred metres deep. Seen from a hill it has a flat top, with hills and trees standing out of it.

## What the code does

**Weather** (`src/shared/weather.gd`, still a pure function of seed, clock, zone and spirit):
- `state()` now also returns two values:
  - `mist` (0 to 1), the strength of the fog layer;
  - `mist_top_m`, the height of its top above sea level, or 0 when there is none.
- `mist` is a product of:
  - **timing**: gathers from 22:00 and is full four hours later; burns off from sunrise + 1 h to sunrise + 3 h, using the real 52°N sunrise from `sunrise_hour()`, which matches `day_cycle.gd`;
  - **calm**: full at or below wind 0.3, none at 0.5 or above;
  - **clear**: the front noise at or below 0.4, none from 0.6, which is well below where rain starts;
  - **dry**: no rain or snow;
  - **autumn**: 1 in mid-autumn, 0.55 in summer and winter, 0.1 in mid-spring;
  - **night**: a daily noise, so some calm, clear nights have no fog;
  - **zone**: temperate 1, transition 0.45, arctic 0.5, desert 0.1;
  - **spirit**: high town spirit gives up to ×1.5 (Kathleen section 9: "clear mornings with valley mist").
- **The top** is a new height each night, 30 to 140 m above sea level for a full layer. It sits lower while the layer is thin, so it sinks as it burns off.
- Neither value depends on the altitude the caller passes. The layer is one for the whole zone row, the same for every player.

**Look** (`src/client/weather_look.gd`):
- **From above the top:** Godot's height fog (`fog_height` = the top, `fog_height_density` = 0.08 per metre × mist). Ground 5 m below the top is about a third white, and 30 m below is nearly solid. The sky and anything above the top stay clear.
- **From inside the layer:** the camera's depth below the top is eased over ±6 m. Inside, the height fog steps aside, because it would whiten the ground at your feet as much as the far valley. Instead the distance fog thickens to 15 times the clear-air haze, about 95% white at 220 m (fog by definition is under 1 km of visibility), and the fog hides 90% of the sky.
- **Colour** (Kathleen rule 2):
  - the haze colour moved 55% toward white by day;
  - warm at sunrise, because the dusk horizon colour feeds it;
  - blue-grey at night, from the night horizon colour;
  - a soft glow toward the low sun (`fog_sun_scatter` 0.25 × mist);
  - it keeps its own colour rather than the sky's (aerial perspective cut by 80% × mist).
- **Under rock**, the mist goes with the light, as the haze already does. Underwater, the underwater fog replaces it as before.
- **The "fog" test kind** (Esc > Settings weather test) is now this valley fog, with a top at 90 m, instead of an even haze. A fog equally thick at every height is on Kathleen's never-see list.
- **Shot runner:** `--shots` takes `mist` as a weather (top 90 m), for Dino's pictures.

## Known limits (next steps, not in this change)

1. **One top height for the whole island.** Low ground near sea level fills first. An inland basin higher than the top gets no fog even when its own cold air would pool. The honest fix is a cold-air pooling mask from the terrain record (R6: low, enclosed, convergent cells). The weather would then give the strength, and the mask the place.
2. **The sea under the top is white too.** Radiation fog does not form over the open sea. From a summit at dawn the island reads as a sea of cloud, which is a real inversion picture, but near the shore it is wrong. Sea fog is Kathleen's kind 4 and needs its own rule. A sea mask can come with it.
3. **Sound:** fog does not yet hush birds or carry sound differently.
4. Steam fog over water (kind 2), cap clouds (kind 3) and sea fog (kind 4) are separate later items. Cap clouds wait for Dino's check picture (decision 7).

## Checks (on Dave's PC, never in the cloud)

- `test_weather`: mist within 0 to 1; a top only with mist; none from noon to 21:00; none in rain or snow; at least 5 foggy autumn dawns in 180 (three seeds); autumn more than twice spring and twice the desert; sunrise at 52°N 3.0 to 4.5 midsummer and 7.5 to 8.7 midwinter.
- Pictures for Dino: `--shots="fog_above:53296,120,68080,0,-10,6.5,mist;fog_inside:53296,2,68080,0,0,6.5,mist"` at the spawn. One shot from above the 90 m top and one from inside.
