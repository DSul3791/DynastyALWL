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
3. **Animals.** Visual detection follows the new fog field at the animal and along the line of sight. Hearing and smell are unchanged.

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
- **Halo strength.** The billboard halo now follows any fog at the eye, valley or sea (before: valley fog only, and squared).
- **Visibility number.** The client's `visibility_m` is now the depth fog's 95 % distance (about 50 m in full fog, about 60 m on High and Ultra, about 2.8 km in clear air). The server's animals see by the same fog since PR 3 (below).

## Where and when: what the code does (PR 2)

- **Weather** (`src/shared/weather.gd`, still a pure function of seed, clock and zone, the same on server and client). `mist` is now the land fog's strength from these tendencies, each with natural variation:
  - **Radiation fog.** It needs calm, clear nights. It starts gathering an hour after sunset and has fully gathered six hours later, deepening toward dawn. It starts clearing half an hour after sunrise and takes 1.5 h in dry air up to 5 h in damp air ("sunrise should not instantly remove it"). Some nights it does not form at all.
  - **After rain.** Rain in the last 3, 8 or 14 hours is moisture. It makes a cooling calm night's fog likelier and thicker (up to 1.3 ×) and longer-lasting. It never makes fog on its own on a warm, dry, windy afternoon: no fog from 14:00 to 18:00 without rain.
  - **In rain.** Light, steady rain (0.05 to 0.6) in cool (full at 7 °C, none from 14 °C), quiet air brings a thin fog (at most 0.45) at any hour, though not with every shower. Heavy rain washes the air.
  - **Steam fog.** `water_steam` (0..1) forms when the air is 3 to 8 °C colder than the water (the year's mean warmth), in calm air, at any hour.
  - **Sea fog.** Unchanged: banks carried in on a light onshore wind, in the day too, and longer while the conditions last.
  - **Depth.** `mist_depth_m` replaces `mist_top_m`. It is the fog's depth over the local low ground: 15 to 90 m, a new depth each night, shallower while the fog is thin (it starts shallow and sinks as it clears).
- **Place** (`src/shared/fog_ground.gd`, client).
  - From the tiles' coarse heights (32 m) in a 4.6 km window round the player (so the 1280 m view floor reaches past the 1 km rebuild step), read on a worker thread, it builds the cold-air floor: the lowest ground within 320 m, smoothed. The fog's top is that floor plus its depth, so valleys and high basins fill while the slopes and hilltops round them stay clear. The top belongs to the place, not to the player, and changes smoothly across the land.
  - Seen from above, the layer lies over the wider floor (1280 m), which is the valley below a hill.
  - Steam fog is a 4 m layer over the water, fading out within 60 m of rivers and lakes (the tiles' fresh-water distance).
  - The land layer at the eye is the one the eye is most inside (strength × depth at the eye): 10 m above a river in valley fog it is the valley fog, not the stronger steam below. Above every layer it is the strongest. The floors ease at 25 m/s toward a new reading, so the top never jumps on a first read or a teleport.
  - The fog's air is the low ground's (sea-level air of the zone row), so the server and every client get the same fog whatever their height.
  - Limit: the steam's top is the coarse 32 m ground plus 4 m, not the water surface itself, so over a deep river cut it can sit a little off. Good enough for wisps; revisit if it shows in play.
  - Where no tile is known, the floor is sea level, which was the old single layer.
- **Wind.** It mixes away the shallow ground fog and the steam (none from wind 0.5 and 0.4). It carries the sea fog banks in (sea fog needs a breeze). Drifting patches move with it (fog look, High and Ultra).

## Animals (PR 3)

- **One fog.** The distance shape (depth fog, haze fit, dense end 60 m) moved to `src/shared/fog_shape.gd`, so the client's look and the server's animals use the same sums (the Low and Medium look exactly; High and Ultra draw the dense end at 70 m with the drifting body adding the rest). `Weather.fog_shape(state, height, floor)` is the fog at a point: the haze thickened by rain, snow and storm, and the fog strength there (the valley fog over the cold-air floor, or the sea fog over the land under its top). Steam wisps are left out, as in the look. Graphics presets change only how a client draws it, never what animals see.
- **Where it lies.** The server keeps cold-air floor windows round the players (`fog_ground.gd`, read from the world's tiles on a worker thread; players within 1 km of a window share it, at most 16), so a deer in a high basin is in that basin's fog. A point takes the window it lies deepest inside.
- **Along the line of sight.** The fog's strength between an animal and a player is each layer's strength times the share of the line below its top: a deer in the valley fog looking up at a player on the clear slope sees through only the part below the top, and a line from ridge to ridge over a filled basin is clear. In clear air with no rain the sight rule needs no sums inside 800 m.
- **Sight.** Jamie's rule for exponential fog (all of a player to V/4, nothing past V/2) is the same contrast as the fog taking 53 % and 78 % of the view. On the depth fog that is all of a player to about 31 m in full fog and nothing past about 42 m, which is Dave's "silhouettes at 20 to 40 m". Past that only hearing and smell (`senses.blind_factor`), unchanged.
- **Visibility V** (95 %): about 2.8 km clear, 460 m in heavy rain, 52 m in full fog (was 3.3 km, 555 m, 220 m). The rules that take V (birds sit out fog, deer keep dawn hours, herds stay close) keep about the same fog strengths as before (within 0.03): `sit_below_m` 250 → 100 (strength 0.85 and up), `deer_v_m` 1000 → 1400 (strength 0.17 and up). Wolves still shadow at half V, never under 10 m (25 m in full fog, as before; that is inside the 31 m they are seen in full, so fog gives them no cover, as before).
- Limits: the server reads one weather for the island (the starter row's), as before. Animals over the sea see by the sea fog over the land only.

## Tunables, in one place: `src/client/fog_look.gd` (the shape in `src/shared/fog_shape.gd`, the drifting body in `fog_volume.gd`)

| Number | Now | What it does |
|---|---|---|
| `FogShape.DENSE_END_M` | 60 m | full fog: everything gone by here (raise for thinner dense fog); animals see by it too |
| `DENSE_END_VOL_M` | 70 m | the same on High and Ultra, where the drifting body adds to it |
| `FogShape.FOG_CURVE` | 1.0 | under 1 thickens the near fog, over 1 clears it |
| `FogShape.BEGIN_M` | 0 m | start of the fog at full strength (0: no clear bubble) |
| `SKY_HIDE_DEEP` | 0.94 | share of the sky deep fog hides (the rest lets the disc through) |
| `OVERHEAD_M` | 15 m | fog depth above you that hides 63 % of that |
| `SUN_DIM` | 0.7 | share of the sunlight deep fog takes |
| `DISC`, `DISC_DEG` | 0.35, 1.6° | faint sun or moon disc |
| `LOW_WEATHER_FOG` | "distance" | lowest preset: "distance" (distance fade only, Dave 15 Nov) or "off" (no weather fog) |
| `VOL_DENSITY` | 0.006 /m | the drifting body's thickness (High, Ultra) |
| `VOL_PATCH_M`, `VOL_DETAIL_M` | 70 m, 23 m | the two patch sizes |
| `VOL_DRIFT`, `VOL_DRIFT_MIN_MS` | 0.25, 0.15 m/s | drift as a share of the wind, and its least speed |
| `VOL_CONTRAST` | 0.8 | patchiness (0 even) |
| `FireWeather.FIRE_FOG_SHARE` | 1.0 | fire light halo in the volumetric fog |
| `Weather.MIST_*`, `RAIN_FOG*`, `STEAM_*` | see weather.gd | when fog forms and clears (PR 2): gathering and burn-off hours, wind, moisture, fog in rain, steam |
| `Weather.MIST_DEPTH_MIN_M`, `MAX` | 15, 90 m | how deep a full fog lies over the low ground |
| `FogGround.FLOOR_REACH_M`, `VIEW_REACH_M` | 320, 1280 m | how far round counts as the low ground (bigger: broader valleys fill) |
| `FogGround.STEAM_REACH_M`, `STEAM_DEPTH_M` | 60 m, 4 m | steam fog's reach from the water and its depth |
| animals.json `weather.fog` `sight_full_fog`, `sight_gone_fog` | 0.53, 0.78 | how much fog an animal sees a player through in full, and not at all (PR 3) |
| animals.json `weather.fog` `sit_below_m`, `deer_v_m` | 100, 1400 m | V under which birds sit out fog, and deer keep dawn hours and herds stay close |

## Graphics presets (Dave 14 Nov 2026: "full on ultra setting but off on lowest setting")

| Preset | Weather fog | Sky hidden, sun dims, layer from above | Volumetric body and halos |
|---|---|---|---|
| Low | distance fade only (Dave 15 Nov 2026) | no | no |
| Medium | yes | yes | no (billboard halos only) |
| High | yes | yes | yes, 48 × 48 × 48 froxels, 48 m reach |
| Ultra | yes | yes | yes, 64 × 64 × 96 froxels, 64 m reach |

The clear-air haze and rain murk are drawn on every preset as before; they cost nothing. The volumetric fog runs only while there is fog (fog at the eye or the layer's strength over 0.02).

Dave, 15 Nov 2026: "yes low gets a cheap distance fade". Low draws the depth fade, so a Low player does not see through fog that hides things from everyone else and from animals; it keeps no sky hiding, no layer from above and no volumetric body.
