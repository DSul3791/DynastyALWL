# Picture plan for Kathleen's look stack (#605, #607, #614, #619, #627, #633, #635)

Owner: Kathleen (art direction). Written 8 Nov 2026 for Dino, who takes the pictures on Dave's PC.

This plan covers every picture the seven look PRs need before they can merge. It gives each one's commands, game day and hour, where to stand, and what the picture must show and must never show. The pictures are listed in the order to take them, in one sitting.

## 0. Before you start

### 0.1 One checkout covers all seven PRs

The PRs are stacked: #601, #605, #607, #614, #619, #627, #633, #635. The top branch holds all of their code. Take every picture from a worktree at **#635's head**:

```
git fetch origin claude/kathleen-summit-snow-wind
git worktree add ../pics_kathleen 27a19618d61f198d3a641cb99403156f5d33e7c5
cd ../pics_kathleen
```

If Tyler has merged main into the stack since then, use the newest #635 head he sends. Every picture is for a new look, which is either on by default or turned on by a switch, so the PR a picture belongs to is named in each shot's title.

Never run anything in Dave's own checkout or game folder. `art/playthrough/rig.sh` uses its own server, store and APPDATA, so it is safe to run beside Dave's game.

### 0.2 Setting the game day

A new world starts on **day 100**, at 08:00. That is summer, with a full moon.

For any other day, give the rig's server a store folder holding a `game_clock.json`. The server reads `seconds` from it at start-up. Write the file fresh **before every start**, because the server saves its own clock every 30 s and so moves it on.

```
DAYS=E:/Software/godotDev/kathleen_days
mkday() { mkdir -p "$DAYS/d$1"; echo "{\"seconds\": $(( $1 * 86400 + 8 * 3600 ))}" > "$DAYS/d$1/game_clock.json"; }
# then, per start:   mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh ...
```

Keep one folder per day and reuse it, so the terrain the server bakes is kept between starts. The days used here:

| Day | Season | Moon | Why |
|---|---|---|---|
| 100 (default, no store) | summer | full | most shots |
| 115 | summer | new | dark night colour |
| 232 | autumn | waning | foam in autumn |
| 314 | winter | last quarter | breath, winter summit snow, cold haze |

### 0.3 Forced weather and live weather

The rig's `--weather` and the 7th field of a shot can force the weather. A forced kind also fixes the air temperature, and it carries no season:

| Forced kind | Rain | Cloud | Wind | Air |
|---|---|---|---|---|
| `clear` | 0 | 0.15 | 0.1 | 14 °C |
| `rain` | 0.65 | 0.8 | 0.3 | 9 °C |
| `storm` | 1.0 | 1.0 | 0.9 | 8 °C |
| `snow` | snow 0.6 | 0.8 | 0.1 | -3 °C |

For temperature and season looks (breath, cold haze, autumn foam), use **live** weather instead: the world's own weather for that day and hour.

- On the rig line, write `--weather live`. `live` is not a forced kind, so nothing is forced.
- In a `--more-shots` entry, leave the 7th field out, or write `live` when an 8th field (walk speed) follows.

Live weather is a fixed rule of the world seed, the day and the hour (`src/shared/weather.gd`), and the shot runner holds the hour, so it is the same on every run. I worked out the live hours used here from that rule, off the PC:

| Day, hour | Rain | Cloud | Wind | Air at the spawn |
|---|---|---|---|---|
| 100, 12:00 | 0 | 0.17 | 0.38 | 21 °C |
| 100, 15:00 | 0 | 0.16 | 0.42 | 21 °C |
| 232, 12:00 | 0 | 0.04 | 0.41 | 9 °C |
| 314, 09:00 | 0 | 0.06 | 0.30 | -4 °C |
| 314, 10:00 | 0 | 0.05 | 0.33 | -4 °C |
| 314, 12:00 | 0 | 0.05 | 0.37 | -4 °C |
| 314, 22:00 | 0 | 0.17 | 0.18 | -4 °C |

If a live shot shows rain or a grey sky where this table says clear, write that in the report and carry on. It would mean my copy of the rule is off, not that the look is wrong.

### 0.4 Places

| Name | x, z | Ground | Note |
|---|---|---|---|
| Spawn | 53296, 68080 | 48 m | the spawn meadow; flat ground nearby |
| Rig spawn | 53301, 68427 | 31 m | the rig's default `--at`; flat, pond just north-east |
| Pond | 53316, 68476 | water | view it from 53316, 68495 facing north |
| Brook | 54101, 69709 | 544 m | the steep brook |
| Hero peak | 54784, 71424 | **1421 m** | the highest top on the starter island (shipped tiles) |
| Peak, north-west side | from the spawn | | yaw **-156**, pitch 12 (the summit is 3.7 km away, 20° up) |
| Peak, north-east side | 57300, 69400 | 172 m | yaw 129, pitch 14 (3.2 km, 21° up); this is the lee side |
| Peak, south-west side | 52300, 73400 | 21 m | yaw -51, pitch 14 (3.2 km, 24° up); this is the windward side |
| Peak, close | 55400, 71000 | 915 m | from 1300 m (`agl -1300`): yaw 125, pitch 5 (750 m from the top) |
| Far peak | 66944, 79296 | 1051 m | from the spawn: yaw -129, pitch 2 (17.7 km); a long view across ridges for haze |

**Correction:** #619 and #627 said "yaw about 160" toward the hero peak. That faces away from it. The right yaw is **-156**: yaw 0 faces north (-Z), 90 faces west and -90 faces east.

### 0.5 Rig habits for this plan

- **Windowed, as always.** Shaders compile only in a window, so a shader error shows only here. Any `SHADER ERROR` line fails the start (exit 3). Report every one word for word.
- **Timing.** `--settle S` is the wait before each picture after its move, and the same for every shot of a start. Sequences that depend on time (rain stopping, snow melting) use repeated shots at the same spot as a timer.
- **Long starts.** For a start longer than 15 minutes, set `RIG_CLIENT_TIMEOUT` (seconds) and `SERVER_ARGS=--quit-after=SECONDS`.
- **Output.** `--out E:/Software/godotDev/DynastyALWL_Evidence/kathleen_stack` for every start. Then zip the folder and copy the client log lines `shot runner: saved`, `Summits:` and any error.

## 1. Day 100 (no store needed): summer, full moon

### 1.1 #605 night colour, full moon, open ground (no torch)
```
art/playthrough/rig.sh --name n605_fullmoon_open --at 53296,68080 --agl 1.7 --yaw -156 --pitch 0 --hour 22 --weather clear \
  --more-shots "n605_fullmoon_down:53296,1.7,68080,-156,-20,22,clear"
```
- **Must show:** a dim scene where about half the colour is left. Grass reads as dull green-grey, not black and white. The moon side of things is a little brighter.
- **Never:** full daytime colour, a pure grey picture, or anything glowing.

### 1.2 #605 night colour with a torch
```
art/playthrough/rig.sh --name n605_torch --item torch --at 53296,68080 --agl 1.7 --yaw -156 --pitch -15 --hour 22 --weather clear
```
- **Must show:** warm full colour within the torch's light, about 12 m, and grey-blue beyond it.
- **Never:** colour coming back across the whole view, or a hard edge where the colour comes back.

### 1.3 #605 night colour beside a fire
```
art/playthrough/rig.sh --name n605_fire_close --give campfire_kit:1 --drop --client-arg --shot-place --client-arg --shot-light \
  --at 53301,68427 --hour 22 --weather clear --wait 60 --settle 30 \
  --more-shots "n605_fire_5m:53301,1.7,68432,0,-10,22,clear;n605_fire_20m:53301,1.7,68447,0,-3,22,clear"
```
The fire is placed about 1 m north of the rig spawn.
- **Must show:** at 5 m, colour around the fire, with the ground and grass warm. At 20 m, the fire is a warm spot in a grey scene.
- **Never:** a grey scene at 5 m, or the colour lifting the whole scene at 20 m.

### 1.4 #607 rainbow, then no bow at noon
```
art/playthrough/rig.sh --name rb_rain --at 53296,68080 --agl 1.7 --yaw -90 --pitch 8 --hour 17 --weather rain --settle 20 \
  --more-shots "rb_clear_20s:53296,1.7,68080,-90,8,17,clear;rb_clear_40s:53296,1.7,68080,-90,8,17,clear;rb_clear_60s:53296,1.7,68080,-90,8,17,clear;rb_clear_100s:53296,1.7,68080,-90,8,17,clear;nb_rain:53296,1.7,68080,0,0,12,rain;nb_clear:53296,1.7,68080,0,0,12,clear"
```
At 17:00 on day 100 the sun is in the west, 27° up, so the bow stands in the east (yaw -90). Its top is about 15° above the horizon.
- **Must show:**
  - `rb_clear_20s` to `_60s`: one bow centred on the point straight opposite the sun, red on the outside. A fainter second bow sits outside it with its colours reversed, and the sky is darker between the two.
  - The bow fades from 20 s to 60 s, and is gone by `rb_clear_100s`.
  - `nb_*` at noon, with the sun 61° up: no bow.
- **Never:**
  - a bow during `rb_rain`, or a bow drawn on the ground or on the hills;
  - a bright or neon bow, or any bow at noon.

### 1.5 #607 snow on branches, then the melt
```
art/playthrough/rig.sh --name snow_trees --at 53301,68427 --hour 12 --weather snow --settle 30 \
  --flora scots_pine,spruce,oak,birch --views "near:12:10:1.6;wide:30:6:1.6" \
  --more-shots "snow_trees_full:53301,1.7,68445,0,10,12,snow;snow_far:53296,2,68080,-156,4,12,snow;melt_30s:53301,1.7,68445,0,10,12,clear;melt_60s:53301,1.7,68445,0,10,12,clear;melt_90s:53301,1.7,68445,0,10,12,clear;melt_120s:53301,1.7,68445,0,10,12,clear"
```
The trees are a labelled row 2.4 m north of the rig spawn. The snow memory takes 60 s to cover fully and melts in 120 s at 14 °C.
- **Must show:**
  - snow on the tops of leaf clusters and on the upper side of branches;
  - dark undersides, and upright trunks that stay dark;
  - far trees with whitened upper crowns in `snow_far`;
  - the trees clearing together with the ground, from `melt_30s` to `melt_120s`.
- **Never:**
  - trunks white all round, snow on the undersides, or pure white;
  - far trees staying white after the near ones have cleared.

### 1.6 #614 puddles: full, in rain and after
```
art/playthrough/rig.sh --name pud_rain --client-arg --puddles=1 --at 53296,68080 --agl 1.7 --yaw 0 --pitch -25 --hour 12 --weather rain \
  --more-shots "pud_after:53296,1.7,68080,0,-20,9,clear;pud_night:53296,1.7,68080,0,-20,22,clear;pud_far:53296,30,68080,0,-30,12,clear"
```
- **Must show:**
  - `pud_rain`: puddles in flat hollows and worn tracks, with small rain rings and none on slopes;
  - `pud_after`: the sky and sun mirrored in still water, with damp dark rims;
  - `pud_night`: dark water showing only the moonlit sky;
  - `pud_far`: puddles fading out by about 200 m, none on hillsides, none on river or lake beds, none under tree crowns.
- **Never:**
  - water on steep ground, glowing puddles at night, or ripples beyond about 40 m;
  - a hard line where they stop.

### 1.7 #614 puddles: a little rain, ice, and torch
```
art/playthrough/rig.sh --name pud_light --client-arg --puddles=0.35 --at 53296,68080 --agl 1.7 --yaw 0 --pitch -25 --hour 12 --weather clear
art/playthrough/rig.sh --name pud_ice --client-arg --puddles=1,ice --at 53296,68080 --agl 1.7 --yaw 0 --pitch -25 --hour 10 --weather clear
art/playthrough/rig.sh --name pud_torch --client-arg --puddles=1 --item torch --at 53296,68080 --agl 1.7 --yaw 0 --pitch -20 --hour 22 --weather clear
```
- **Must show:**
  - `pud_light`: only the deepest hollows, on mud and gravel first;
  - `pud_ice`: pale, glossy ice with cracks and no ripples;
  - `pud_torch`: the torch flame reflected near the player.
- **Never:**
  - in `pud_light`, the full set of puddles;
  - in `pud_ice`, rain rings on ice;
  - in `pud_torch`, a puddle that is lit from inside.

### 1.8 #619 and #635 summit snow in summer (no switch; on by default)
```
art/playthrough/rig.sh --name ss_summer_nw --at 53296,68080 --agl 2 --yaw -156 --pitch 12 --hour 12 --weather clear \
  --more-shots "ss_summer_ne:57300,2,69400,129,14,12,clear;ss_summer_sw:52300,2,73400,-51,14,12,clear;ss_summer_close:55400,-1300,71000,125,5,12,clear"
```
The summer snow line is at 82% of the 1421 m summit, about 1165 m. With #635, summer patches stay only where the ground is lee (facing north-east), shaded (facing north) or creased.
- **Must show:**
  - `ss_summer_ne`: clear patches on the north-east faces and in their gullies near the top;
  - `ss_summer_nw`: a few patches, in north-facing gullies only;
  - `ss_summer_sw`: the windward face almost bare;
  - `ss_summer_close`: ragged patch edges, thin streaks on steep rock, broad snow only on gentle ground.
- **Never:**
  - a straight, level snow line, or a white cap all round;
  - snow below about 1000 m in summer;
  - more snow on the south-west than the north-east.

### 1.9 #619 cap cloud (switch on)
```
art/playthrough/rig.sh --name cap_nw --client-arg --cap-cloud=1200 --at 53296,68080 --agl 2 --yaw -156 --pitch 12 --hour 10 --weather rain --settle 75 \
  --more-shots "cap_side:57300,2,69400,129,14,10,rain;cap_dusk:57300,2,69400,129,14,19,rain;cap_night:57300,2,69400,129,14,23,rain;cap_inside:54784,-1480,71424,0,0,10,rain"
```
Forced rain gives moist air and wind 0.3, about 4 m/s by Jamie's wind page (#637: m/s = 20 × wind^1.3), so the cap is at full strength after its 60 s ease. The wind blows toward the south-east, so the banner trails away from the spawn. `cap_side` sees it from the side.
- **Must show:**
  - a soft lens hugging the top, and a banner 300 to 1000 m long downwind (best in `cap_side`);
  - a soft edge where it meets the rock;
  - `cap_dusk`: a dimmer cap, with no gold, because the forced rain hides the sun;
  - `cap_night`: only faintly lit;
  - `cap_inside`, taken 60 m above the summit: grey mist, with no flat card in front of the camera.
- **Never:**
  - a glowing cap, or the outline of a sprite;
  - a cap on a low hill under 1200 m;
  - a banner pointing upwind;
  - a hard edge against the rock.

### 1.10 #619 cost
```
art/playthrough/rig.sh --name cost_cap_off --frametime 30 --at 53296,68080 --agl 2 --yaw -156 --pitch 12 --hour 10 --weather rain
art/playthrough/rig.sh --name cost_cap_on --client-arg --cap-cloud=1200 --frametime 30 --at 53296,68080 --agl 2 --yaw -156 --pitch 12 --hour 10 --weather rain
```
- **Report:** both `shot runner: frametime` lines, and the `Summits: N found` log line with its time.
- **Fail:** p95 more than 1 ms higher with the cap on, or the summit search taking over 2 s.

### 1.11 #627 haze in summer, dry and after rain (switch on, then off)
```
art/playthrough/rig.sh --name hz_summer_dry --client-arg --haze --at 53296,68080 --agl 2 --yaw -129 --pitch 2 --hour 15 --weather live --settle 30 \
  --more-shots "hz_rain:53296,2,68080,-129,2,15,rain;hz_wash_30s:53296,2,68080,-129,2,15;hz_wash_90s:53296,2,68080,-129,2,15;hz_after_150s:53296,2,68080,-129,2,15;hz_after_210s:53296,2,68080,-129,2,15"
art/playthrough/rig.sh --name hz0_summer_dry --at 53296,68080 --agl 2 --yaw -129 --pitch 2 --hour 15 --weather live
```
This view runs across the ridges to the far peak, 17.7 km away.
- **Must show:**
  - `hz_wash_30s`: the clearest picture of the set, with far ridges sharper than in `hz_summer_dry`;
  - `hz_wash_90s` to `hz_after_150s`: the haze coming back;
  - `hz_summer_dry` against `hz0_summer_dry`: close to the same look, since a mild day is the 1.0 point.
- **Never:**
  - the far peak lost in the dry shot, or a haze colour that does not match the sky;
  - banding in the distance.
- **Known weak spot:** the milky look after rain may hardly show in `hz_after_210s`. The haze reads ground wetness from the footstep system, which dries in 4 real minutes, and the haze leaves its washed state only after about 2.5. If the after-rain pictures look no paler than `hz_summer_dry`, report that. The fix is a slower wetness memory in `haze.gd`, as a small follow-up.

### 1.12 #633 water look in summer (switch off, then on)
```
art/playthrough/rig.sh --name wl0_brook --at 54101,69709 --agl 3 --yaw 0 --pitch -35 --hour 12 --weather live \
  --more-shots "wl0_pond:53316,2,68495,0,-15,12"
art/playthrough/rig.sh --name wl_brook --client-arg --water-look --at 54101,69709 --agl 3 --yaw 0 --pitch -35 --hour 12 --weather live \
  --more-shots "wl_pond:53316,2,68495,0,-15,12"
```
- **Must show:**
  - `wl_brook`: white water only on shallow fast chutes, with deep fast runs staying dark and smooth;
  - thin lines of foam flecks along the seams beside fast water;
  - the stream bed showing through clear water.
- **Never:**
  - white on a deep smooth reach, or foam on the still pond;
  - foam spread evenly over the whole surface;
  - flecks that stand still in moving water (check across two frames if you can).

## 2. Day 115 (`mkday 115`): new moon

### 2.1 #605 night colour on a dark night
```
mkday 115; PERSIST_STORE=$DAYS/d115 art/playthrough/rig.sh --name n605_newmoon_open --at 53296,68080 --agl 1.7 --yaw -156 --pitch 0 --hour 22 --weather clear
```
- **Must show:** darker than `n605_fullmoon_open`, with less colour (0.4 left). Shapes can still be made out against the sky.
- **Never:** the same brightness as the full-moon shot, or a black frame.

## 3. Day 314 (`mkday 314`): winter, -4 °C, clear

### 3.1 #605 breath, first person, third person and animals
```
mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh --name br_fp_a --at 53296,68080 --agl 1.7 --yaw -156 --pitch 0 --hour 9 --weather live --settle 3 \
  --more-shots "br_fp_b:53296,1.7,68080,-156,0,9;br_fp_c:53296,1.7,68080,-156,0,9;br_fp_d:53296,1.7,68080,-156,0,9"
mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh --name br_tp_a --cam left --at 53296,68080 --yaw -156 --hour 9 --weather live --settle 3 \
  --more-shots "br_tp_b:53296,1.7,68080,-156,0,9,live,0;br_tp_c:53296,1.7,68080,-156,0,9,live,0;br_tp_d:53296,1.7,68080,-156,0,9,live,0"
mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh --name br_animals_a --client-arg --shot-animals=deer,wolf --at 53296,68080 --agl 1.7 --yaw -156 --pitch -5 --hour 9 --weather live --settle 3 \
  --more-shots "br_animals_b:53296,1.7,68080,-156,-5,9;br_animals_c:53296,1.7,68080,-156,-5,9"
```
The air is about -4 °C, so breath is near full. A breath comes every 3 to 4.5 s and lasts 1.5 s, so one of each four pictures catches a puff. The sun is only 10° up at 09:00.
- **Must show:**
  - in first person, a faint soft puff in front of the face that grows, rises and drifts with the wind;
  - in third person, the puff leaving the head, not the chest or the floor;
  - the deer and the wolf, 4 m ahead, puffing from the muzzle, not in time with each other;
  - puffs shaded by the scene's light.
- **Never:**
  - a glowing puff, or a puff from a body without a head bone;
  - puffs from all bodies at the same moment;
  - a puff stuck to the camera.
- The third-person shots repeat with the 7th field `live` (nothing forced) and the 8th field `0`, so the body stays shown, standing. Without the 8th field the body is hidden.

### 3.2 #605 breath at night by torchlight
```
mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh --name br_night_a --item torch --cam left --at 53296,68080 --yaw -156 --hour 22 --weather live --settle 3 \
  --more-shots "br_night_b:53296,1.7,68080,-156,0,22,live,0;br_night_c:53296,1.7,68080,-156,0,22,live,0"
```
- **Must show:** breath lit warm by the torch.
- **Never:** breath visible in the dark beyond the light, or breath that glows.

### 3.3 #619 and #635 summit snow in winter
```
mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh --name ss_winter_nw --at 53296,68080 --agl 2 --yaw -156 --pitch 12 --hour 12 --weather live \
  --more-shots "ss_winter_ne:57300,2,69400,129,14,12;ss_winter_sw:52300,2,73400,-51,14,12"
```
The winter line is at 50% of the summit, about 710 m. North faces hold it about 100 m lower and lee faces about 85 m lower. Windward faces stand about 100 m higher and keep at most 30% cover.
- **Must show:**
  - snow well down the mountain on the north-west and north-east faces;
  - the south-west face clearly patchier, with rock showing through;
  - the snow line wandering with the ground, not following a contour.
- **Never:**
  - snow on the lowland meadow (no snow has fallen in this start, so lying snow below the line would be a fault);
  - a level line;
  - an even white cover on the windward face.

### 3.4 #627 haze on a cold, dry morning (switch on, then off)
```
mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh --name hz_cold --client-arg --haze --at 53296,68080 --agl 2 --yaw -129 --pitch 2 --hour 10 --weather live
mkday 314; PERSIST_STORE=$DAYS/d314 art/playthrough/rig.sh --name hz0_cold --at 53296,68080 --agl 2 --yaw -129 --pitch 2 --hour 10 --weather live
```
- **Must show:** in `hz_cold`, crisp ridges and a far peak sharper than in `hz0_cold`, with the distance a deeper blue at the same brightness.
- **Never:** a haze that has gone completely, so nothing fades with distance, or a blue that is brighter than the sky.

## 4. Day 232 (`mkday 232`): autumn

### 4.1 #633 foam in autumn against summer
```
mkday 232; PERSIST_STORE=$DAYS/d232 art/playthrough/rig.sh --name wl_brook_autumn --client-arg --water-look --at 54101,69709 --agl 3 --yaw 0 --pitch -35 --hour 12 --weather live \
  --more-shots "wl_pond_autumn:53316,2,68495,0,-15,12"
```
- **Must show:** more foam lines on the brook than in `wl_brook` (1.12), with tan flecks in slow water.
- **Never:** foam on the still pond.

## 5. Last, unattended (about 2 h 10 min): #633 clarity after a storm

```
RIG_CLIENT_TIMEOUT=9000 SERVER_ARGS=--quit-after=9000 art/playthrough/rig.sh --name wl_t00_storm --client-arg --water-look \
  --at 54101,69709 --agl 3 --yaw 0 --pitch -35 --hour 12 --weather storm --settle 600 \
  --more-shots "wl_t10_brook:54101,3,69709,0,-35,12,clear;wl_t20_pond:53316,2,68495,0,-15,12,clear;wl_t30_brook:54101,3,69709,0,-35,12,clear;wl_t40_pond:53316,2,68495,0,-15,12,clear;wl_t60_brook:54101,3,69709,0,-35,12,clear;wl_t70_pond:53316,2,68495,0,-15,12,clear;wl_t80_brook:54101,3,69709,0,-35,12,clear;wl_t90_pond:53316,2,68495,0,-15,12,clear;wl_t100_brook:54101,3,69709,0,-35,12,clear;wl_t110_pond:53316,2,68495,0,-15,12,clear;wl_t120_brook:54101,3,69709,0,-35,12,clear"
```
The storm runs 10 minutes, so the rivers' push is near full and the running water is cloudy. Each later picture is 10 more real minutes after the rain stops. The `tNN` in a name is the minutes since then. The running water clears with a 30-minute half-life. Still water takes half that cloud and clears with a 45-minute half-life.
- **Must show:**
  - the brook brown and cloudy at `t00` and `t10`;
  - clearly clearing by `t30` and `t60`;
  - clear, with the bed showing, by `t120`;
  - the pond less cloudy than the brook at first, but staying cloudy longer.
- **Never:**
  - water that clears the moment the rain stops;
  - a brown pond while the brook is still clear in the first half hour;
  - foam that disappears while the water is cloudy (foam should be a little thicker then).

## 6. What to send back

- The zip of `kathleen_stack/`.
- For each start:
  - the `shot runner: saved` lines;
  - every `SHADER ERROR`, `SCRIPT ERROR` or `ERROR` line, word for word;
  - the exit code.
- For 1.10, the frametime lines and the `Summits:` line.
- One line per picture: **pass** (shows the must and none of the never) or **fail**, saying which line it broke.

## 7. Not in this plan

- #601 night light has its own list (Dino's night check).
- Fresh snow drifting off summits in wind is not built. Jamie's #637 puts the start at wind 0.35. It would come with the rain and wind work.
- Peat colour in the water waits for R6.
