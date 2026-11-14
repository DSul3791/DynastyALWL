# Fog: how Dave's fog instruction is built

Design: [FOG_DESIGN_DAVE.md](FOG_DESIGN_DAVE.md) (Dave, 14 Nov 2026, approved, verbatim). This note is the technical plan and where every number lives. The look is judged only by Dave on his PC: everything here is NEEDS PLAYER VERIFICATION until he has seen it ([FOG_F6.md](FOG_F6.md)).

## Three PRs

1. **Look** (this PR). How fog looks once it is there: the distance shape, the sky, the sun, night, halos, shelter, graphics presets. It uses the weather's existing fog values (`mist`, `mist_top_m`, sea fog) unchanged.
2. **Where and when.** Fog forms from moisture, cooling, wind and terrain:
   - overnight fog;
   - fog after rain and during rain;
   - wisps over rivers, lakes and wetlands;
   - fog collecting in valleys and low ground;
   - coastal banks drifting inland.
   It comes and goes gradually, varies naturally, and belongs to places: a fog field by position, not one layer for the whole island. The server reads the same field.
3. **Animals.** Visual detection follows the new fog field at the animal and along the line of sight. Hearing and smell are unchanged. Until then, animals keep today's rule (`Weather.visibility_m`, about 220 m inside full valley fog), so in PR 1's dense fog the player sees less than the animals' sight rule assumes.

## Look: what the code does (PR 1)

- **Distance shape.** Open-air fog is Godot's depth fog, `amount = pow(smoothstep(begin, end, d), curve)`. That is the only engine fog that gives Dave's dense-fog targets:
  - 7 % at 10 m, 26 % at 20 m, 74 % at 40 m, all of it from 60 m;
  - thin from the eye outward (no clear bubble);
  - never more than 2.5 % more per metre (no wall).
  Exponential fog cannot do this: thick enough to hide 40 m, it already hides a third of 10 m.
- **Clear air.** The old exponential haze is refitted as depth fog (end = 3.25 / density, curve 0.35, within 4.4 % everywhere), so a clear day looks as before and fog grows out of it with no jump.
- **Inside fog.** The fog at the eye (`mist_inside` = strength × how far below the layer's top) pulls the end toward 60 m on a log scale: half strength gives about 390 m, a light mist leaves long views.
  - Rain and snow murk still thin the haze as before.
  - The water shader uses the same depth sums.
  - Under water stays exponential.
- **Seen from above.** The layer is unchanged: Godot height fog below the top, so a valley fills white below clear hills. Inside, it steps aside (#1137).
- **Sky.**
  - The share hidden is 0.94 × fog at the eye × (1 - e^(-overhead/15 m)). Deep fog hides the sky, the stars and the clouds; shallow ground fog (little overhead) leaves the sky.
  - The sky shader draws the sun or moon as a soft, faint disc through it.
  - The sunlight dims by up to 70 % with the hidden share, so shadows go weak.
- **Night.** The fog colour comes from the sky's horizon colour, near black at night (day_cycle NIGHT), so night fog is dark unless lit.
- **Halos.**
  - Fires and torches keep their billboard halo (fire_weather.gd, all presets).
  - On High and Ultra they also light the volumetric fog (`light_volumetric_fog_energy` 1.0), giving soft shafts and glows. The hand light stays out of it.
- **Body and drift (High and Ultra).** One FogVolume box (160 × 60 × 160 m) moves with the eye in 32 m steps, but its density is read in world space from a 3D noise texture at two crossing scales (70 m and 23 m, so no pattern repeats in view). The patches belong to places and drift slowly with the wind (a quarter of its speed, never below 0.15 m/s, so they creep even in dead calm). It is thin (0.006 per metre at full fog), and with it on the depth fog's dense end is 70 m instead of 60 m, so the two together keep Dave's distances: about 11 % at 10 m, 29 % at 20 m and 69 % at 40 m. It is lit by the ambient light, the sun and fire lights, so it is dark at night unless lit. It belongs to the layer the eye is in or over; sea fog adds body only down at sea level, not inland. It is built only the first time a High or Ultra player meets fog, starts at 0.02 fog and stops below 0.01 (no flicker), and follows a preset change at once.
- **Shelter.**
  - Under rock (caves, tunnels), the fog at the eye goes with the light (as before), and the depth fog returns to the haze.
  - In a building, depth fog leaves the first 10 m nearly clear, so a room is clear while the doorway shows the fog outside.
  - Known limit: the High/Ultra volumetric body does not yet stop at walls (a thin share can show indoors).
- **Halos.** The billboard halo now follows any fog at the eye, valley or sea (before: valley fog only, and squared).
- **Visibility number.** The client's `visibility_m` is now the depth fog's 95 % distance (about 50 m in full fog, about 2.8 km in clear air). The server's animal rule stays at about 220 m in full fog until PR 3.

## Tunables, in one place: `src/client/fog_look.gd` (and `fog_volume.gd` for the drifting body)

| Number | Now | What it does |
|---|---|---|
| `DENSE_END_M` | 60 m | full fog: everything gone by here (raise for thinner dense fog) |
| `DENSE_END_VOL_M` | 70 m | the same on High and Ultra, where the drifting body adds to it |
| `FOG_CURVE` | 1.0 | under 1 thickens the near fog, over 1 clears it |
| `BEGIN_M` | 0 m | start of the fog at full strength (0: no clear bubble) |
| `SKY_HIDE_DEEP` | 0.94 | share of the sky deep fog hides (the rest lets the disc through) |
| `OVERHEAD_M` | 15 m | fog depth above you that hides 63 % of that |
| `SUN_DIM` | 0.7 | share of the sunlight deep fog takes |
| `DISC`, `DISC_DEG` | 0.35, 1.6° | faint sun or moon disc |
| `LOW_WEATHER_FOG` | "off" | lowest preset: "off" (no weather fog) or "distance" (distance fade only) |
| `VOL_DENSITY` | 0.006 /m | the drifting body's thickness (High, Ultra) |
| `VOL_PATCH_M`, `VOL_DETAIL_M` | 70 m, 23 m | the two patch sizes |
| `VOL_DRIFT`, `VOL_DRIFT_MIN_MS` | 0.25, 0.15 m/s | drift as a share of the wind, and its least speed |
| `VOL_CONTRAST` | 0.8 | patchiness (0 even) |
| `FireWeather.FIRE_FOG_SHARE` | 1.0 | fire light halo in the volumetric fog |

## Graphics presets (Dave 14 Nov 2026: "full on ultra setting but off on lowest setting")

| Preset | Weather fog | Sky hidden, sun dims, layer from above | Volumetric body and halos |
|---|---|---|---|
| Low | off (switch: "distance" draws the distance fade only) | no | no |
| Medium | yes | yes | no (billboard halos only) |
| High | yes | yes | yes, 48 × 48 × 48 froxels, 48 m reach |
| Ultra | yes | yes | yes, 64 × 64 × 96 froxels, 64 m reach |

The clear-air haze and rain murk are drawn on every preset as before; they cost nothing. The volumetric fog runs only while there is fog (fog at the eye or the layer's strength over 0.02).

Open question from the coordinator to Dave, not yet answered: with weather fog off on Low, a Low player sees through fog that hides things from everyone else and from animals. `LOW_WEATHER_FOG = "distance"` is the cheap alternative.
