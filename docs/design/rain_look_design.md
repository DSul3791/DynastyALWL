# The look of rain: streaks, splashes, drips, wet surfaces

Owner: Kathleen (art direction). Written 8 Nov 2026 and stacked on #635. This is a design note only; the code follows behind a switch.

## Goal

Rain should read as weather that falls through light and lands on things:

- streaks that slant with the wind and fall at the speed real drops fall;
- a low sheet of splashes on rock and hard ground;
- trees and roofs that go on dripping after the rain stops;
- ground and rock that darken by material, wet first on the faces the rain reaches and dry again at different rates.

The art goal stays realistic, with a little fantasy exaggeration: the streaks may be a bit longer and easier to see than a camera would show, but nothing glows.

Game time runs at RATIO 24, so one game hour is 150 real seconds. Every time below is in game time unless it says real.

## 1. What exists today, and what is wrong with it

| Part | Today | Problem |
|---|---|---|
| Streaks (`weather_look.gd` `_make_rain`, `RAIN_SHADER`) | GPU particles in a 48 m box over the eye. Two crossed quads 0.6 m long, falling at 15-19 m/s, unshaded, colour (0.78, 0.84, 0.95), alpha 0.10-0.26 by strength. They are hidden under crowns, caves and roofs (canopy map). | **Unshaded, so they show at night as if lit** (the "never glows" rule). They fall about twice as fast as the heaviest real rain. The slant uses only the wind's strength and always leans toward +X, ignoring `wind_dir`. Drizzle falls as fast as a storm. |
| Wet ground (`ground_material.gd` `wet`) | The colour darkens by 35% on every material and roughness drops to 0.38. No wetting under crowns. It reads the footstep system's `ground_wet`. | One darkening for sand and granite alike, where real materials differ by a factor of three. Every face wets at once, including overhangs. It dries in 4 real minutes (`WET_DRY_SEC 240`), about 1.6 game hours, the same for rock and soil. The haze reads the same number (picture plan 1.11). |
| Splashes | Rain rings in puddles only (#614). | No splash on rock, gravel or water, so a downpour on a bare summit looks like drizzle. |
| Drips | Cave ceiling drips only (`drip_view.gd`). | Trees and roofs stop the instant the rain does. |
| Bark, rocks, buildings | Unchanged in rain. | Trunks and boulders stay dry-looking in a storm. |

## 2. What real rain does (the numbers this note uses)

- **Fall speed by drop size** (Gunn and Kinzer 1949; the standard curve):

  | Drop | Fall speed |
  |---|---|
  | 0.5 mm | 2 m/s |
  | 1 mm | 4.0 m/s |
  | 2 mm | 6.5 m/s |
  | 3 mm | 8.1 m/s |
  | 5 mm | 9.1 m/s |

  No drop falls faster than about 9 m/s. Drizzle is mostly under 0.5 mm, moderate rain 1-2 mm, and the drops in a heavy shower 2-4 mm.
- **Slant:** a drop moves with the air, so the streak leans by atan(wind / fall speed), toward where the wind blows. Light rain in a stiff breeze slants far more than a downpour does.
- **Wind** (Jamie's #637):
  - speed in m/s = 20 × wind^1.3, so 0.3 is 4.2 m/s and 0.6 is 10.3 m/s;
  - gusts run about 1.5 × the mean;
  - at night, air drains downhill at 1-3 m/s.
- **Splash:** a drop hitting hard ground throws a crown of droplets 2-15 cm high, which lasts about 0.1 s. In heavy rain these join into a pale sheet a hand high over rock and roads. Grass and leaf litter swallow them. On water a drop makes a ring and a small upward jet.
- **Drip:**
  - Tree crowns hold 0.5-2 mm of water before rain falls through (interception storage). Conifers hold the most, and bare winter broadleaves the least.
  - After rain stops, crowns go on dripping for roughly 20-60 minutes. They drip less in sun and wind, and the drips are shaken off sooner in a breeze.
  - The heaviest drips fall along the crown's outer edge, the drip line, and along a roof's lower edge (the eaves). Leaf drops are big (4-6 mm), so they fall near 8-9 m/s after a few metres.
- **Wet darkening** (Lekner and Dorf 1988, "Why some things are darker when wet"):
  - A water film makes light bounce back into the surface (total internal reflection), so more of it is absorbed.
  - Light, rough, porous materials darken most: dry soil, sand and sandstone lose up to about half their brightness.
  - Dense dark rock darkens less, but turns glossy and mirrors the sky.
  - Already-wet mud barely changes.
- **Drying:** bare rock dries first, in under an hour in sun and wind. Gravel, turf and litter take 2-4 hours, and deep mud stays wet. The upper and windward faces get wet first. Overhangs and the lee sides of boulders stay dry.

## 3. The rules

### 3.1 Streaks
1. **Fall speed** follows the rain's strength `hard` (today's value, max(rain, storm)):
   - fall = lerp(2.5, 9.0, smoothstep(0.1, 0.9, hard)) m/s;
   - each streak gets ±12% at random, so the rain does not fall in step.
2. **Length and width** follow the speed: the length is the distance fallen in 0.05 s (0.12-0.45 m). Drizzle is fine and short, and a storm is thick and long. Today's `size_scale` stays the control.
3. **Slant:**
   - the streak's direction is (wind_ms · (cos wind_dir, sin wind_dir), -fall), normalised, using the weather's own `wind_dir` (the way the wind blows toward);
   - the slant is capped at 65° from upright;
   - gusts multiply wind_ms by 1 + 0.5 · gust(t), where gust is a smooth noise in 0..1 with a 3-8 s period, shared with the wind cue so sound and rain gust together.
4. **Light, never glow:**
   - The streaks are lit by hand in the shader, like the cap cloud: colour = water tint × (sun light × sun up × 0.35 + sky light × 0.65).
   - A forward-scatter boost of up to 2.5× applies when looking toward the sun, using the same `sun_dir` uniform. A drop against a dark wood in low sun is the brightest rain there is.
   - At night they take only moonlight and the held light. Within a torch's or fire's reach (the light radius #605 already reads, 12 m for a torch), the light term adds the flame's warm colour, falling off with distance. Rain at night is seen in the torchlight, not across the valley.
   - Alpha stays 0.10-0.26.
5. **Where:** the box, the canopy cut-out, caves and underwater all stay as they are.

### 3.2 Splash sheets on hard ground
1. **Ground shader flecks.** These are cheap, read the material, and work at every quality level.
   - They use the same jittered 0.3 m grid as #614's rain rings, which drop by the dozen.
   - Each cell flashes a tiny pale crown for 0.12 s, at a random phase.
   - They are drawn within 30 m of the eye, on rain ≥ 0.3, and not under crowns.
   - Strength by layer: rock 1.0, gravel 0.7, sand 0.35, mud 0.3 (a dull plop, darker), turf 0.1, litter 0.05.
   - Puddles keep their rings, and a puddle cell shows rings, not crowns.
2. **Splash sheet** (quality ≥ 2, high and ultra).
   - The streaks collide with a `GPUParticlesCollisionHeightField3D` that is 64 m across and follows the eye, refreshed when the eye moves 8 m.
   - Each hit sub-emits 3-5 droplets: up at 0.5-1.5 m/s, lifetime 0.25 s, the same lit shading as the streaks.
   - The heightfield cannot tell rock from turf, so the sheet is faded by a per-particle look-up of the ground's rock and gravel weight. It is drawn only where `hard` ≥ 0.5, so it reads as a downpour, never drizzle.
   - The splashes drift downwind at 30% of wind_ms.
3. **On water:** the liquid sheets and grid water get the same ring flecks as the puddles. They are fainter, and none appear on fast white water, where the surface hides them.

### 3.3 Drips after rain
1. **Crown wetness memory**, one number for the canopy around the player:
   - It fills while it rains, at a rate set to full after 10 game minutes of rain ≥ 0.3.
   - It empties after the rain stops, half-life 15 game minutes × (1 − 0.5 · sun) ÷ (1 + 2 · wind), so it is gone in about 45 minutes on a still grey day and in 10 in a sunny breeze.
   - Conifers hold 1.5 × and bare broadleaves 0.4 × (the flora view's leafless winter hardwoods).
2. **Where:**
   - A drip particle system follows the eye: 12 m radius, 60-240 drops by quality.
   - Each drop's spot reads the canopy map. Drops survive only where the map is between 0.25 and 0.9, the drip line of a crown or the eaves of a roof, with a sparse 15% inside full cover.
   - They start at crown height for trees (the flora view's height for that crown, else 8 m). For roofs they start at the roof's edge height, which the roof list sent to the canopy map does not carry yet (it holds shape, centre, half sizes and yaw), so it needs the height added.
   - Drops are 4-6 mm, lit like the streaks, and land with a ground fleck.
   - Rain falling under the crown during the rain itself is the same system at full rate. Under a tree in a storm you see big, slower drops, not the fine open-air rain.
3. **Roofs:**
   - Thatch holds 2 ×, so it drips longer than plank (0.6 ×). The roof list needs the roof's material added, alongside the height.
   - A gutter-like line of drips along the eaves is what to look for.
4. **Sound:**
   - The drip loop under trees, and a drip plink at the eaves, as two new sound slots. They need recordings, so the slots are listed in this note and wait for the sound job.
   - With the switch off, nothing plays.

### 3.4 Wet surfaces
1. **A wetness memory per ground layer.** This replaces `ground_wet` for the look and lives in `puddles.gd`, which already keeps per-layer levels.
   - It soaks in over 3 game minutes of rain ≥ 0.15. A first shower darkens the ground in seconds of real time, not at the first drop.
   - It dries, in game hours: rock 0.75, gravel 1.5, turf 2.5, litter 3, sand 2, mud never below 0.5.
   - Light rain holds it. Sun halves the drying time and wind takes off another third.
   - The footstep sounds keep their own `ground_wet`. The haze reads this new memory instead, which also fixes the weak after-rain haze in the picture plan.
2. **Darkening and gloss by layer:**

   | Layer | Colour × | Roughness to |
   |---|---|---|
   | sand | 0.55 | 0.30 (wet sand already shines at the waterline) |
   | turf | 0.72 | 0.45 |
   | litter | 0.65 | 0.45 |
   | gravel | 0.70 | 0.30 |
   | rock | 0.78 | 0.22, with sky reflection |
   | mud | 0.92 | 0.18 |

   Snow cover cancels it, as today.
3. **Faces:**
   - A face is wet by up + windward = clamp(0.6 · n.y + 0.4 · dot(n.xz, −wind_dir_vec) + 0.4, 0, 1).
   - Faces looking down (n.y < −0.15, the underside of an overhang) stay dry.
   - The lee side of a boulder dries 2 × faster as the rain eases.
   - The canopy map still keeps the ground dry under crowns, but the drip line (map 0.25-0.9) gets the drip wetting instead, so a ring of dark ground shows under each crown's edge after rain. This is the most telling real detail.
4. **Wet streaks on steep rock:** faces steeper than 50° show vertical dark streaks where water runs down. They use a noise stretched 1:8 along the slope, like the summit snow streaks, at 60% of the face's wetness. They stay for a game hour after the face is otherwise dry.
5. **Bark and buildings:**
   - The bark shader takes the same per-layer rock value as a stand-in: colour × 0.75 and slightly glossy. It is darker on the windward side of the trunk and in stemflow lines.
   - Plank walls and thatch take colour × 0.8 on the windward side.
   - These are step 5 of the build.

## 4. Never see

- Rain that glows at night, or rain seen far beyond a torch at night.
- Rain slanting against the wind, upright rain in a gale, or a downpour falling slower than drizzle.
- Splash crowns on grass, a splash sheet in drizzle, or splashes under a crown or roof during open-air rain.
- Dripping trees on a dry day, or after an hour of sun.
- A dry drip line under a crown just after rain, or wet ground deep under a dense crown.
- Wet undersides of overhangs, or every face wet at once.
- Sand and granite darkening the same, or a hard line between wet and dry.
- Puddles drying before the ground around them.

## 5. Build order (all behind `--rain-look`, off by default until Dino's pictures)

1. **Streaks:** fall speed, length, slant from `wind_dir` and gusts, and lit shading with the torch term. These are in `weather_look.gd` and the `RAIN_SHADER`. This is the biggest visible fix, for one shader and a few lines.
2. **Wet surfaces:** the per-layer memory, darkening and gloss table, face rule, drip-line ring and steep streaks. These are in `puddles.gd` and `ground_material.gd`, and the haze switches to the new memory.
3. **Splash flecks** in the ground shader, then the heightfield splash sheet at quality ≥ 2.
4. **Crown and roof drips:** a new `rain_drips.gd`, with the canopy map read on the CPU at a stride of 2 m for spawn spots.
5. **Bark and buildings wet.**
6. **Sounds** for the drip slots, after recordings.

**Cost:**

- Step 1 costs nothing extra.
- Step 2 adds a few lines per ground pixel, and only while some layer is wet.
- The splash sheet adds up to 5 × the streaks' particles at quality 2-3. At ultra that is 4500 streaks with about 15% hitting per frame, so it is capped at 2000 splash particles.
- Drips add up to 240 particles.
- Dino measures each step with `--frametime 30` on and off, in `storm`.

## 6. Pictures for Dino (when the code exists)

Use the same rig habits as `KATHLEEN_PICTURE_PLAN.md`.

- **Streaks:**
  - in `rain` at the spawn, looking across the wind and with it;
  - in `storm` at 17:00 looking toward the sun (backlit rain);
  - at 22:00 with a torch: rain only in the light.
- **Splashes:** `storm` on the summit rock (54784, -1430, 71424, pitch -30) against the meadow at the spawn: a sheet on rock, nothing on grass.
- **Drips:** under an oak at the spawn in `rain`, then shots 20, 60 and 150 real seconds after `clear`. The drips thin out, the drip-line ring stays dark, and both are gone by the last shot.
- **Wet surfaces:**
  - a boulder or cliff seen from windward and from lee, 30 s into rain and 60 s after it stops;
  - the beach sand against the summit rock: sand clearly darker, rock clearly glossier;
  - the overhang of cave #8002's mouth (56520, 72360) staying dry.

## 7. Open points for later

- **Snow drifting off summits** in wind from 0.35 (Jamie #637). This is moving snow, with a shape of its own, and comes with the wind work.
- **Rain masking sound** beyond 30/15/8 m (drizzle/moderate/heavy) is on Jamie's #642. It goes in the sound-outdoors note, not here.
- The climate record (R6) will give the island's prevailing wind and rain totals. Until then, `wind_dir` from the weather is the only wind.
