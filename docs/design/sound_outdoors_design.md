# Sound outdoors: wind, night, rain, snow, forest, echoes and rivers

**Owner:** Kathleen (art, animation, sound). **Status:** design, 8 Nov 2026. **Behind:** `--sound-outdoors` (off until Dave's listen).
**Reads:** Jamie's research page [`docs/knowledge/sound-outdoors.md`](../knowledge/sound-outdoors.md) (#642), the numbers in its "Judged numbers" part.
Also `wind-over-terrain.md` (#637: m/s = 20 x wind^1.3). Client only: nothing here is sent, saved or read by the server.

## 1. What is wrong today

Read from the code on 8 Nov (main f2f1d6c9):

1. **Wind has no direction for sound.** A wolf howl 500 m upwind in a gale is as loud as one 500 m downwind. Wind only adds its own noise.
2. **No night carry.** A clear, calm night sounds the same as noon at 500 m.
3. **Rain does not mask anything.** `weather_sounds.gd` lowers the bird layer in rain (`calls` 0). Every other sound plays at full level through a downpour: a rabbit thump at 40 m, a dig at 30 m, a rustle.
4. **Snow hushes for weeks.** `snow_hush = 0.8 x ground_snow + falling`. While snow lies, the world stays 3 to 4 dB down and dull, even when the snow is a month old and crusted. Real snow hushes for a day or two after it falls, then the world gets louder again (lesson 6).
5. **Forest dulls but never quietens.** `sound_occlusion.gd` lowers the cutoff to 45 % in dense forest. There is no level loss: 300 m of trees take nothing off a howl. Jamie's judged loss is about 10 dB per 100 m.
6. **Cold has no effect.** Frost air eats the high end about twice as fast past a few hundred metres (lesson 2). Our cutoffs do not move with the temperature.
7. **No outdoor echoes.** A chop or a dropped stone in a gorge sounds like one on a meadow.
8. **Rivers fall off like a point.** `water_sounds.gd` places at most two voices per kind, 36 m apart, each with inverse-distance falloff. A long reach should fall 3 dB per doubling, not 6, out to about a third of its length.

None of these is a crash or a wrong picture. They are why the world sounds the same in every weather.

## 2. How it hooks in (one place, no fights over volume)

Every world sound is an `AudioStreamPlayer3D` in the group `world_sounds`. `sound_occlusion.gd` already visits each one every 0.5 s to set its low-pass cutoff. The new work rides on that scan.

- **Level: `unit_size`, not `volume_db`.** Many modules write `volume_db` every frame (loops, fades, the voice shedder), so changing it here would fight them. With Godot's inverse-distance falloff, the gain is `unit_size / distance`. Scaling `unit_size` by k therefore adds exactly 20·log10(k) dB at every distance, and no module writes `unit_size` after it makes the player.
  - The first time the scan sees a player, it stores the player's own `unit_size` in the meta `air_unit`.
  - From then on: `unit_size = air_unit x db_to_linear(air_db)`, with `air_db` eased at 6 dB/s.
- **Cutoff:** the extra factors multiply the cutoff the scan already sets, and are eased the same way as now.
- **First look:** a one-shot that starts between scans would play up to 0.5 s at the wrong level. A howl upwind must start low. The new module therefore listens to `SceneTree.node_added`, and gives each new 3D player its first `air_db` deferred, after its position is set.
- **Left alone:**
  - players made with `falloff = false` (far thunder: its level is its own `volume_db` and band bus);
  - players outside `world_sounds` (the player's own body, the UI).
  - The air-band buses (`air_bands.gd`) keep their job. The cold and fog factors also stretch their effective distance (3.5).
- **Pure functions** in a new `src/client/outdoor_air.gd` (static, so the tests call them without a scene):
  - `wind_db(...)`, `night_db(...)`, `forest_db(...)`, `mask_db(...)`, `snow_fresh_step(...)`, `cold_cutoff(...)`, `line_db(...)`, `echo_paths(...)`.
  - `sound_occlusion.gd` sums them for each player.
- **Total clamp:** the sum is held to +6 / -30 dB, so no mistake can make a far sound louder than near or silence a near one.
- **Flag off:** with `--sound-outdoors` off, nothing changes. `air_db` stays 0, the factors stay 1, and no hook is connected.

## 3. Rules

`d` is the distance from the listener's head to the source. Weather comes from `_client.weather` (`wind`, `wind_dir`, `rain`, `snow`, `cloud`, `temp_c`). The wind heading is where the wind blows toward, as in `weather_look.gd`. Sun height is `weather_look.day.elevation` (sin of the angle).

### 3.1 Wind direction (lesson 3), only past 50 m

Let `c = dot(normalize((listener - source).xz), wind_toward)`, which runs from +1 when the listener is downwind of the source to -1 when upwind.

| Where the listener stands | Change |
|---|---|
| downwind (c = +1) | +3 dB x smoothstep(0.05, 0.15, wind) (1 m/s is wind 0.1) |
| crosswind (c = 0) | -5 dB x smoothstep(0.1, 0.4, wind) |
| upwind (c = -1) | -(10 + 10 x smoothstep(0.3, 0.6, wind)) dB x smoothstep(0.1, 0.3, wind) (4 m/s is wind 0.3); cutoff x 0.6 |

- **Between those points:** linear in c, from crosswind to downwind or from crosswind to upwind.
- **Fades in with distance:** x smoothstep(50, 100, d), so a sound within 50 m is never moved.
- **Upwind shadow weakens far out** (turbulence): x lerp(1, 0.6, smoothstep(224, 1000, d)).
- **Gusts scatter sound back in:** x (1 - 0.35 x gust) on the upwind part only, with `gust` taken from the sound stage. So a far call upwind comes and goes.
- **Which wind:** the world wind, not the ridge exposure. The exposure changes the wind's noise, not the air between.

### 3.2 Night carry (lesson 4)

- **When:** a clear, calm night.
  - `night = 1 - smoothstep(-0.17, -0.02, elevation)` in the evening. In the morning (hour < 12) it is `1 - smoothstep(0.02, 0.17, elevation)`, so the cold layer holds until about an hour after sunrise.
  - `calm = (1 - smoothstep(0.3, 0.5, cloud)) x (1 - smoothstep(0.2, 0.35, wind))`.
- **What:** +4.5 dB x night x calm x smoothstep(150, 300, d), with no change past 2 km. The cutoff rises x 1.15 for the same sounds.
- **Fog morning:** the same carry at 60 %, because fog lies in the same cold layer (lesson 7), and it applies only to sounds with `unit_size` ≥ 12 (low far sounds: a wolf, a fall, a cowbell).
- **Calm is quiet:** the game's own bed (wind loops, insects) already drops on a calm night. Nothing extra here.

### 3.3 Forest level (lesson 8)

- **Level:** -10 dB per 100 m x forest x min(d, 300) / 100, capped at -18 dB. `forest` is `AmbientLife.weights["forest"]`, the share of trees around the player, as the cutoff already uses.
- **Cutoff:** the existing 45 % floor stays. The level is the missing half.
- **Judged simplification:** the trees around the listener stand for the trees between. A howl from inside a far wood heard across an open valley is not dulled. That is wrong only in that one case, and it needs no rays.

### 3.4 Masking by rain and gale (lesson 5)

A quiet sound past the mask distance fades out. A loud low one does not.

- **Rain mask distance**, `rain_mask_m(rain)`, from Jamie's table:

  | rain | mask distance |
  |---|---|
  | 0.15 | 30 m |
  | 0.4 | 15 m |
  | 0.7 | 8 m |
  | 1.0 | 5 m |

  - Linear between the points. No mask under rain 0.1.
  - Under crowns in leaf (the canopy map's `cover_at`, months 4 to 10) the distance is x 0.7, because rain on leaves is 5 to 10 dB louder.
- **Gale mask distance:** from wind 0.5, `lerp(60, 25, smoothstep(0.5, 1.0, wind))` m. The mask distance used is the smaller of the two.
- **Loss past the mask distance** M: -12 dB x smoothstep(M, 2M, d) x small. `small` is how quiet the source is: 1 at `unit_size` ≤ 6 (steps, digs, rustles, rabbit, duck, door), 0 at ≥ 15 (bear, wolf, falls, river, bell), linear between.
- **Why this is enough:** the -12 dB edge puts a small sound below the rain bed (the usual 10 dB rule), and big low sounds come through as lesson 5 says.

### 3.5 Snow: fresh hush that ages, and cold air (lessons 6 and 2)

- **Fresh snow** is a new `snow_fresh`, 0 .. 1 (in `outdoor_air.gd`, stepped by `weather_sounds.gd`):
  - set to 1 while snow falls (state `snow` > 0.1);
  - then down by 1 per 48 game hours;
  - 3 times as fast above 0 °C or in rain (the snow crusts or turns wet).
- **The hush** becomes `snow_hush = 0.8 x ground_snow x snow_fresh`, plus 0.2 while snow falls as today. Today's bus cuts (-3 / -4 dB) and the wind high cut keep their numbers, they just end.
- **Far sounds on fresh snow:** -4 dB x snow_fresh x ground_snow x smoothstep(50, 100, d), and cutoff x (1 - 0.3 x snow_fresh x ground_snow).
- **Cold air:** `cold = smoothstep(10, -5, temp_c)`.
  - Cutoff x lerp(1, 0.55, cold x smoothstep(100, 500, d)). In frost a far fall or fire is darker, and near sounds are untouched, so a snapped twig close by stays crisp.
  - The air-band effective distance is x (1 + 0.8 x cold), the same idea for the shared buses.
- **Fog:** cutoff x 0.8 past 100 m (`fog` from the weather look, eased), and nothing near.

### 3.6 Echoes off cliffs (lesson 9)

- **Sharp sounds only:** a sound module that makes one sets the meta `air_sharp` on its player. Those are:
  - axe chops (`hit_sounds.gd`);
  - pick on stone (`dig_sounds.gd`);
  - spear and arrow strikes (`spear_sounds.gd`);
  - the tree-fall crash (`tree_sounds.gd`).
  - Thunder is left out: its clips already roll.
- **Finding a face:** at most one echo search every 0.5 s, on Mid (4 rays) and High and Ultra (8 rays). None on Low.
  - Voxel rays go out level from the sound's place, every 360/n degrees, up to 400 m.
  - A hit counts as a face when its normal is steep (|n.y| < 0.35), it is 17 m or more away, and a second ray 17 m higher also hits within 6 m of the same range (a face at least 17 m tall).
  - The normal is read from two extra rays, 1 m to each side.
- **Playing it:**
  - **Clip:** the same clip as the direct sound.
  - **Delay:** 2 x range / 337 s.
  - **Place:** the mirror image of the source in the face, so it pans from the cliff.
  - **Bus:** `Echo`, a 2.5 kHz low-pass.
  - **Level:** the direct level at the listener minus lerp(12, 22, smoothstep(50, 300, range)) dB, with falloff off.
  - **Snow:** -5 dB if snow lies.
  - Then `air_db` (3.1 to 3.5) applies to it as to any sound.
- **Gorges:** when two opposite rays both find faces within 60 m, the stronger echo repeats once or twice more (2 x width / 337 s apart, each 8 dB softer and darker).
- **Never:**
  - an echo from trees or a grass slope (only faces);
  - from a face under 10 m (the 17 m rule covers this);
  - more than 3 echo voices at once (they count against the voice cap at priority 1).

### 3.7 Rivers as a line (lessons 1 and 10)

- **Which voices:** river and rapids voices in `water_sounds.gd` (not brook, pond or fall) get `line_db(d) = 10·log10(d / unit)` for unit < d < L/3, and the same value at L/3 beyond. That turns the 6 dB a doubling into 3 dB.
- **Length:** L is judged at 150 m (so the knee is at 50 m) until R7's record gives each reach its length.
- **Holding ground:** the second voice per kind and the 36 m spacing stay. They give the sense of a bank, and the line rule gives the slow fade.
- **Night:** the same river carries about twice as far on a calm night (3.2 already does it).
- **Not here:** the roar over a calm lake. That is R7's to fix by its cause, and this does not touch it.

## 4. Never-hear checks (from Jamie's list, each a test or a listen)

- a far sound as loud upwind as downwind on a windy day (test: `wind_db` gap ≥ 10 dB at wind 0.4, d 400 m);
- birdsong or a small rustle 30 m off heard clearly through heavy rain (test: `mask_db` ≤ -12 at rain 0.7, d 30 m, unit 4);
- a crisp echo in open woodland (test: `echo_paths` empty for a field of trunks; listen in the forest);
- snow that muffles sound for weeks (test: `snow_fresh` 0 after 3 game days of no snow below freezing);
- a calm night valley louder in the wind than by day (night carry is 0 at wind ≥ 0.35);
- a river that sounds the same at 10 m and 200 m (test: `line_db` gives ≥ 12 dB between them; listen).

Plus our own:

- no sound under 50 m changes for wind or night;
- the total never above +6 dB;
- with the flag off, every number is exactly as today.

## 5. Build order (each its own PR, stacked, behind `--sound-outdoors`)

1. **Air gain hook, wind direction, night carry, forest level, cold and fog cutoffs:**
   - `outdoor_air.gd`, the `unit_size` hook in `sound_occlusion.gd` and the `node_added` first look;
   - HUD counts in the sound panel: shadowed, carried, masked, echoed;
   - test `test_outdoor_air.gd`.
2. **Masking by rain and gale; fresh-snow hush that ages** (`weather_sounds.gd` `snow_fresh`).
3. **Rivers as a line** (`water_sounds.gd` sets `air_line` on river and rapids voices, and the scan adds `line_db`).
4. **Echoes off cliffs:** the `Echo` bus, `air_sharp` on the four modules, the search and the repeats.

Cost: steps 1 to 3 are a few multiplies per playing world voice every 0.5 s (96 voices at most on High). Step 4 is at most 8 to 12 voxel rays every 0.5 s, and only when a sharp sound played.

## 6. Listening (for Dave; sound listens wait for him, the flag stays off till then)

The pictures rig cannot judge sound, so the checks are listens on Dave's PC, each with `--sound-outdoors` on and then off:

1. On a windy day, a wolf pack 400 to 600 m off, first upwind, then walk round to downwind. Upwind it should come and go with the gusts.
2. A clear, calm night at the spawn: the far falls and the surf come up against the same spot at noon. A cloudy or windy night does not.
3. Heavy rain: chop wood 20 m from a friend, or watch a rabbit at 30 m. The thump is lost in the rain. A bear's growl is not.
4. A day after fresh snow, then 3 days later: hushed, then normal.
5. Chop beside a 30 m crag (tile 3,4 has granite walls) and in an open field: an echo at the crag only.
6. Walk away from a river: 10 m, 50 m, 150 m. It fades slowly, then falls off.

## 7. Open points

- `wind_dir` is one value for the island. Jamie's #637 local winds (valley drainage at night) could turn it in a valley. That waits for #637's code, if any.
- Forest between source and listener (not around the listener) would need rays or a canopy map read along the line. Left until someone hears the case.
- Thunder echoes in mountains: left to the clips.
- The river length L comes from R7's record when it exists. 150 m until then.
