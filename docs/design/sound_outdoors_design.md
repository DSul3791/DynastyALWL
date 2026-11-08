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

### 3.8 Breeze loss (step 5, Jamie #683)

- **What:** a moderate breeze cuts every range about five times (about 14 dB): Jamie's force 4 column, where a large fall is heard to 850 m, not 3 km.
- **Rule:** past 200 m, full from 400 m, every source (big low sounds too) loses `lerp(6, 14, smoothstep(0.3, 0.5, wind))` dB, faded in from wind 0.15. That is -6 dB at wind 0.3 (4 m/s) and -14 dB from wind 0.5 (8 m/s).
- **With the others:** it adds to the wind direction (3.1) and the gale mask (3.4); the total is still held to -30 dB.

### 3.9 Running water hides small sounds (step 6, Jamie #742)

- **What:** a brook or rapids beside the player is a loud bed, and small sounds farther off are lost in it, just as in rain. Jamie's sums: within about 20 m of a brook, or 40 m of rapids, the bed is as loud as a force 4 wind (42 to 45 dBA). So a stalker who comes in under the water's noise gets close.
- **The bed at the player:** a brook is 55 dBA at 5 m and rapids (or a fall) 62 dBA at 5 m (Jamie's 56 at 10 m). Each falls 6 dB per doubling of distance, and two beds add as power. Nothing is taken off nearer than 5 m.
- **Mask distance:** `water_mask_m = 100 m x hearing factor`, where the factor is `10^(-(bed - 28) / 20)` against Jamie's calm day bed of 28 dBA.
  - Beside a brook (5 m): 4.5 m, the same as heavy rain.
  - 20 m from a brook: about 18 m. 40 m from rapids: about 16 m.
  - 40 m from a brook: about 36 m. Past about 65 m from a brook nothing is masked (a mask wider than 60 m is dropped).
  - The 100 m is judged. It puts Jamie's hearing factors close to 3.4's rain table: drizzle (x 0.35) at 35 m against 30 m, heavy rain (x 0.04) at 4 m against 5 m.
- **Loss:** the same as 3.4, -12 dB x smoothstep(M, 2M, d) x small. The mask distance used is the smallest of rain, gale and water. Big low sounds (a bear, a howl, thunder) come through.
- **Where the distances come from:** `water_sounds.gd`'s last scan (every 2.5 s, 64 m each way) keeps `brook_m` and `rapids_m`, the nearest flowing square of each and the nearest fall. A flowing square with a drop of 1 m or more to a neighbour counts as rapids. A brook kept quiet beside a lake does not count.
- **The water's own voices are left out:** the brook, river, fall, fall base and lap voices carry `air_water`, so the bed does not hide itself or the fall's spray.
- **Player side only.** How well animals hear the player in noise is Steve's and MikeW's (`server_animals.gd` `_sense_factor`; Jamie's suggested `hear_factor`). This is what the player hears.

## 4. Never-hear checks (from Jamie's list, each a test or a listen)

- a far sound as loud upwind as downwind on a windy day (test: `wind_db` gap ≥ 10 dB at wind 0.4, d 400 m);
- birdsong or a small rustle 30 m off heard clearly through heavy rain (test: `mask_db` ≤ -12 at rain 0.7, d 30 m, unit 4);
- a crisp echo in open woodland (test: `echo_paths` empty for a field of trunks; listen in the forest);
- snow that muffles sound for weeks (test: `snow_fresh` 0 after 3 game days of no snow below freezing);
- a calm night valley louder in the wind than by day (night carry is 0 at wind ≥ 0.35);
- a river that sounds the same at 10 m and 200 m (test: `line_db` gives ≥ 12 dB between them; listen);
- a footstep 20 m off heard clearly by a player standing beside a brook (test: `total` ≤ -12 dB with `brook_m` 5, unit 4; Jamie #742).

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
5. **Breeze loss** (3.8): `breeze_db` in `outdoor_air.gd`, added in `total`.
6. **Running water hides small sounds** (3.9): `water_mask_m` and `mask_m_of` in `outdoor_air.gd`; `water_sounds.gd` keeps `brook_m` and `rapids_m` and marks its voices `air_water`.

Cost: steps 1 to 3 are a few multiplies per playing world voice every 0.5 s (96 voices at most on High). Step 4 is at most 8 to 12 voxel rays every 0.5 s, and only when a sharp sound played.

## 6. Listening (for Dave; sound listens wait for him, the flag stays off till then)

The pictures rig cannot judge sound, so the checks are listens on Dave's PC, each with `--sound-outdoors` on and then off:

1. On a windy day, a wolf pack 400 to 600 m off, first upwind, then walk round to downwind. Upwind it should come and go with the gusts.
2. A clear, calm night at the spawn: the far falls and the surf come up against the same spot at noon. A cloudy or windy night does not.
3. Heavy rain: chop wood 20 m from a friend, or watch a rabbit at 30 m. The thump is lost in the rain. A bear's growl is not.
4. A day after fresh snow, then 3 days later: hushed, then normal.
5. Chop beside a 30 m crag (tile 3,4 has granite walls) and in an open field: an echo at the crag only.
6. Walk away from a river: 10 m, 50 m, 150 m. It fades slowly, then falls off.
7. Stand beside a brook while a friend walks toward you from 30 m: their steps come up only in the last few metres. Then do the same 80 m from the brook: the steps are heard from the start.

## 7. Open points

- `wind_dir` is one value for the island. Jamie's #637 local winds (valley drainage at night) could turn it in a valley. That waits for #637's code, if any.
- Forest between source and listener (not around the listener) would need rays or a canopy map read along the line. Left until someone hears the case.
- Thunder echoes in mountains: left to the clips.
- The river length L comes from R7's record when it exists. 150 m until then.
- **Wolf howls carry far too short (Jamie #742 lesson 6).** A howl is drawn 150 to 520 m off and never past 950 m (`creature_sounds.gd`). Jamie gives 6 to 10 km for a reply, about 7 km on a calm night and about 2 km in a force 4 wind. A far howl at 1.5 to 3 km on calm nights, and the 950 m reach raised to match, is a candidate step after Dave's listen of steps 1 to 6. It is a level and voice-count question, and the far rules (night carry, breeze) already shape it.

## 8. Checked against Jamie's hearing ranges (#683, 8 Nov)

Jamie's table, "How far it is heard: calm night against a moderate breeze", set beside the rules above:

- **Night carry matches.** Our +4.5 dB past 150 to 300 m is her +4 dB past 200 m.
- **Gap 1: the cut-off distances, not the air rules, set the range.**
  - River and brook voices stop at 140 m and fall voices at 110 m (`max_distance` in `water_sounds.gd`). Jamie hears a brook at 0.5 to 1 km and a large fall at 3 km or more on a calm night.
  - The fire's voice stops at 52 m (`REACH_M` 35 x 1.5). Its pops should carry about 100 m on a calm night.
  - So none of the far rules (night carry, line rivers) can be heard past those distances. Raising them is a cost question (more voices kept alive, the voice shedder) and is left to the water sound work after R7, when each reach and fall has its size from the record.
- **Gap 2: a moderate breeze cuts every range about five times (about 14 dB).** Our gale mask starts at wind 0.5 (about 8 m/s), takes at most 12 dB and only from small sounds. At force 4 (7 m/s, wind about 0.42) a fall should be heard to 850 m, not 3 km, and our big sounds lose nothing except by direction. The game's own wind bed masks some of it by ear. A breeze loss for every source past 200 m, about -6 dB at wind 0.3 rising to -14 dB at wind 0.5, is a candidate step 5 once Dave has listened to steps 1 to 4.
- **Thunder** is its own note: `docs/design/thunder_delay_design.md`.

## 9. Checked against Jamie's hearing in weather page (#742, 8 Nov)

- **Hearing factors against a calm day:** calm night x2, force 2 x0.6, drizzle x0.35, force 4 open x0.2, moderate rain x0.1, force 4 forest x0.08, heavy rain x0.04.
  - **Calm night:** x2 is +6 dB. Our night carry is +4.5 dB past 150 to 300 m (3.2), close enough, and it fades by wind 0.35.
  - **Rain:** 3.4's table (30 m in drizzle, 5 m in heavy rain) sits within the factors' spread. Moderate rain at 15 m is a little generous against x0.1. Left for Dave's listen.
  - **Force 4 in the open:** the gale mask starts at wind 0.5 (60 m) and the breeze loss (3.8) takes far sounds. A force 4 mask for small near sounds (about 20 m) is not in. Left for the listen: the game's own wind bed already masks by ear.
- **Running water:** step 6 (3.9).
- **Wolf howls:** see the open point in section 7.
