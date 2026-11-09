# Prevailing wind

Owner: Kathleen (art, animation and sound). Status: **on by default** (Dave, 8 Nov: no flags; decisions row 31), **retuned to the starter island's real latitude, 34.3° S**, from Jamie's `docs/knowledge/prevailing-wind-34s.md` (#773). Section 2a below is the model in the code now; sections 2 to 6 were first written for 57° S (`prevailing-wind-57s.md`, #714) and keep that tuning only for the other zone rows, the local wind (section 3) and the readers (section 4). Coordinator job of 8 Nov 2026; the local wind numbers come from `docs/knowledge/wind-over-terrain.md` (#637).

## 1. What changes

Today `Weather.state` gives `wind_dir` as noise over the whole circle. The wind is as likely to come from the east as from the west, and it does not turn with a front. Now (always on):

- **The world's wind** (`Weather.state`, the same on the server and every client, nothing sent):
  - each weather zone has a mean bearing the wind comes from, westerly to north-westerly on the starter island;
  - the wind swings slowly about that mean;
  - now and then a blocked spell brings it round from the south-east;
  - every front turns it the southern-hemisphere way.
- **The wind where you stand** (`Weather.local_wind`, client only for now):
  - steadier and stronger with the sea upwind;
  - weaker and gustier inland, in the lee of a steep crest, or under trees;
  - a slope breeze on light-wind clear nights (down the slope) and sunny days (up it);
  - a sea breeze on calm sunny afternoons, and a land breeze on clear nights.

Switch off: `wind_dir` is exactly what it is today (the test checks it bit for bit), and `local_wind` hands the state back untouched.

**Turn it on** on both the server and the client: the server reads `wind_dir` for scent (`server_animals.gd`, `server_thieves.gd`). With the flag on one side only, the animals smell along one wind while the smoke shows another.

```
art/playthrough/rig.sh ...
```

## 2a. The starter island at 34.3° S (the code now)

At 34° S the wind turns with the season (34 S page, lesson 1). The temperate row has two spells instead of one mean:

| Spell | Blows from | When |
|---|---|---|
| South-easter (the summer high) | 140° (`WIND_EAST_FROM_DEG`), ±50° slow swing | most spells in local summer |
| Westerlies with their fronts | 288° (`WIND_WEST_FROM_DEG`), ±50°, then each front veers it up to +60° (to NW and N) and backs it up to −85° (to SW) | most spells in local winter |

- Every 48 game hours (`WIND_SPELL_H`) the wind keeps or changes spell. The westerlies win `WIND_WEST_BY_MONTH` of them: Spring 1 to Winter 3 are 0.52, 0.45, 0.27, 0.22, 0.22, 0.33, 0.62, 0.82, 0.9, 0.9, 0.88 and 0.72, read between month centres. Runs of the same spell give the page's 2 to 6 days.
- A change of spell swings round through the south over 8 game hours (`WIND_SPELL_TURN_H`): SE, S, SW, W, never through the north and east.
- Fronts follow the storm noise as before, the southern way round. In a south-easter they turn the wind only 0.4 of the way (`WIND_EAST_FRONT`), since summer fronts are weak, often only a wind shift and cloud.
- The month roses, hourly over ten years of a Python copy of the code on seeds 574716103 and 777, against the page:

| Month | Model | Page |
|---|---|---|
| Summer 1 | SE 37 to 39, S 22, E 17, W and NW 6 to 8 %; mean from 142 to 147; constancy 0.53 to 0.57 | SE 33, S 18, E 15, W and NW 7 %; 141; 0.41 |
| Winter 1 | W 27 to 29, NW 25 to 26, SW 15, N 11 %; mean from 275 to 276; constancy 0.49 to 0.51 | W 24, NW 26, SW 18, N 11 %; 279; 0.46 |
| Spring 1 | mean from 191 to 198, constancy 0.23 to 0.29 | 202, 0.28 |
| Autumn 1 | mean from 222 to 235 | 232 |

- The model is a little steadier than the page in deep summer and winter (constancy about 0.1 high), and has almost no NE. Both are judged acceptable for now.
- **Gusts** (page section 4):
  - The factors are open sea 1.4, inland 1.7, under trees or in a lee 2.5, and up to 2.0 in the cold front's squall. The squall is `Weather.front_squall`: how sharply the wind is backing, carried in the state as `wind_squall`.
  - The mean `wind` (0..1) stays capped at 1, which is 20 m/s. `local_wind` also gives `wind_gust_mps`, which is **not** capped, so the year's worst gusts can pass 20 m/s as the page's 26.7 m/s does. A reader on the 0..1 scale clamps at 1 itself.
- **Not changed here:** the mean speed by month (page section 5: spring about a third windier than autumn) and the afternoon rise. Both would change `wind` for every reader (rain, sounds, fire, the server), so they are left for their own PR.

## 2. The world's wind (`Weather.state`)

`wind_dir` keeps its meaning: the way the wind blows toward, as (cos, sin) on (x, z), with north at -Z. From compass bearing B the wind blows toward B + 180, and `wind_dir` = B + 90 degrees in radians. That agrees with Jamie's `atan2(cos B, -sin B)`; the test checks it for every 5 degrees. `wind_dir` is no longer wrapped, so it never jumps from 2π to 0. The new `Weather.prevailing_from_deg` gives the bearing for logs and readers.

`from = mean + spread x (2 x noise(36 h) - 1) + reversal x blocked(3-day noise) + front turn`

| Zone | Mean from | Spread | Veer before a front | Back after | Blocked spell |
|---|---|---|---|---|---|
| temperate (starter, 57° S) | 310° | ±60° | +30° | −85° | −165° (to SE) |
| transition | 295° | ±70° | +30° | −60° | −150° |
| desert | 120° (trades) | ±25° | +15° | −15° | +60° |
| arctic | 110° (polar easterlies) | ±40° | +30° | −40° | +120° |

Only the temperate row follows a page (#714). The other three are judged guesses for islands nobody has written up yet; change them when those islands get a page.

**The starter island against Jamie's rose (#714).** One year, hourly, seeds 574716103 (the base world) and 777:

| Sector | N | NE | E | SE | S | SW | W | NW | Mean | Constancy | Within ±45° of WNW |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Jamie (judged) | 10 | 4 | 4 | 5 | 9 | 16 | 26 | 26 | 300–320° | 0.5–0.7 | 55–65 % |
| Model | 17 | 3 | 2 | 3 | 8 | 13 | 26 | 29 | 293° | 0.55 | 55–58 % |

North is a little high and the south-west a little low: the veer ahead of each front spends hours near north. I left it there, because the front rule matters more to what the player sees than a few points of north on the rose. One direction holds for a day or more (the 36-hour noise; Jamie: 1 to 3 days).

**Fronts, mirrored for 57° S.** The coordinator's note said "backing before rain, veering after". That is the northern rule. South of the equator it is the other way round (#714, sourced from the cold-front article):

- As a front comes (its noise rising), the wind **veers**, clockwise: W to NW to N, up to +30°, over 6 to 18 h.
- Once the front has passed (its noise falling), the wind **backs**, anticlockwise: to SW, up to −85°. This happens in an hour or two with the strongest wind, and the showers go on for half a day to a day.

The trend is the front noise now against 6 hours ago (`WIND_FRONT_LAG_H`), so the back comes a few hours after the heaviest rain, as a cold front's change does. The turn only starts once the front noise passes 0.35; the rain itself starts near 0.73. Each zone row has `south: true`. A northern island sets it false and the rule flips.

**Not changed here:**
- Wind speed is untouched. Its mean is about 0.38 (5.6 m/s) against Jamie's fair 0.4 to 0.45, and there is no windy local winter. Both change scent, valley fog and sound everywhere, so they wait for Dave.

## 3. The wind where you stand (`Weather.local_wind`)

`local_wind(state, here, game_s)` is pure and shared. The caller measures `here`:

| Key | Meaning | How the client measures it (`terrain_client.gd`, every 2 s, 19 rays straight down) |
|---|---|---|
| `downhill`, `grade` | the way the ground falls, and rise over run | ground heights 20 m east, west, north and south of the viewer |
| `lee` | 0..1, sheltered by a crest rising 14° to 22° or more upwind | heights 30, 60 and 120 m upwind |
| `sea_upwind` | 0..1, the share of the ground upwind that is open sea | heights 100, 250 and 450 m upwind; ground at or under 0.25 m is sea |
| `sea_way` | toward the sea, length 0..1 for how much sea is near | heights 300 m off on eight bearings |
| `canopy` | 0..1 under trees | the client's `under_cover` |

Each new measure moves the kept one 0.4 of the way, so walking does not jerk the wind about. Ground that is not loaded counts as unknown, not as land.

| Effect | Number | Source |
|---|---|---|
| inland against the open coast | x0.85 | #714: moorland 5 to 10 km inland 0.8 to 0.9 |
| under a canopy | x0.2 | #714: 0.1 to 0.3 |
| the lee of a crest of 18° or more | x0.35 | wind-over-terrain.md: 0.25 to 0.5 |
| gust over the mean wind | 1.3 with the sea upwind, 1.6 inland | wind-over-terrain.md: 1.5, rough 1.7 to 2; the coast is steadier (judged) |
| katabatic, down-slope | 1 m/s (grade 0.05) to 3 m/s (grade 0.3 and steeper) | wind-over-terrain.md: 1 to 3 on our hills |
| when it blows | builds from 0.5 h before sunset, full 1.5 h after; holds all night; dies 0.5 to 2 h after sunrise | judged on the same page |
| anabatic, up-slope | 0.5 to 1.5 m/s in full sun, from 1.5 h after sunrise (full at 3.5), gone 0.5 h before sunset | wind-over-terrain.md 1 to 2, judged |
| slope breezes only in light wind | full under 2 m/s of the world's wind, gone at 6; the katabatic needs a clear sky (cloud under 0.4 full, none from 0.8) | judged |
| sea breeze, onshore | 2 m/s in spring and autumn to 4 m/s in high summer; from 10:00, full by 14:30, gone at sunset; needs sun | #714, judged |
| none in a fresh wind | the sea breeze is gone once the world's wind passes 4 m/s | #714, sourced |
| land breeze, offshore | 1.5 m/s on clear nights, same hours as the katabatic | #714: 1 to 2 |

The breezes add as vectors to the world's wind, and the shelter scales the sum. The result's heading stays next to the world's heading (no 2π jump). `local_wind` also returns:
- `wind_mps`, `wind_gust`;
- `wind_slope_mps` (+ down-slope);
- `wind_sea_mps` (+ onshore);
- `wind_base_dir`.

**Client only for now.** `terrain_client.gd` applies it to `weather` once a second, so every client reader sees the local wind. The server's scent still uses the world's wind. A katabatic of 2 or 3 m/s on a calm night can therefore carry smoke downhill while the deer smell along the world's wind. The difference shows only in light winds. It is Steve's call whether the server measures slopes too; `local_wind` is shared, so the maths is already there for him.

## 4. What reads it

Every reader takes `wind_dir` and `wind` from the one weather dictionary, so none of them needs a change:

- **Trees:** sway and lean (#684 `flora.set_wind`); canopy drip (#700).
- **Fire:** smoke and sparks (#680, `fire_smoke_wind_design.md`); smoke goes downhill on a calm clear night.
- **Rain and snow:** streak lean (#649 stack); puddle ripples (#614) and summit snow plumes (#635).
- **Fog:** sea fog drift (#608 and #672). Jamie's #716 wants sea fog on a light onshore N to NW wind of 0.15 to 0.45, and the sea fog owner can read `prevailing_from_deg` for that. Valley fog's calm check uses the same `wind`.
- **Sound outdoors:** upwind and downwind carry (`sound_occlusion.gd` `set_air`, #665 to #676; #704 breeze loss).
- **Small effects:** wind cue specks; breath puffs (#625); cap cloud (#619).
- **Animals:** scent (server), as said in section 3.

Two readers could use the new keys later, in their own PRs:
- the wind cue's wobble and the trees' gusts could take `wind_gust`;
- the sound of wind could take `wind_mps`.

The F3 text gets one line:
`wind: from 283 deg (world from 283), 8.0 m/s, gust x1.60 | slope 0.04 downhill toward 095, slope breeze +0.0 m/s | sea upwind 0.00, sea breeze +0.0 m/s | lee 0.00, canopy 0.0`.
The shot runner prints the same line after every saved picture.

**The shot runner's forced weather.** The weather `live` (any name that is not a preset) keeps the world's own weather; an empty field does not work, because the shot list drops empty fields. A preset (`clear`, `rain` and so on) keeps its rain, cloud and speed. It takes the world's wind heading for that hour and then the ground's bending, as in play. Off, the presets keep their fixed heading of 1 rad, as today.

## 5. Tests

`src/worldgen/tools/test_wind_dir.gd`. It was written without being run; there is no Godot here.

- **Off:**
  - `wind_dir` matches today's formula to 1e-6 over 30 days;
  - `local_wind` returns the state as it is.
- **Bearings:**
  - from the west the wind blows toward +x; from the north toward +z;
  - Jamie's `atan2(cos B, -sin B)` and `bearing_of_heading` agree for every 5 degrees.
- **The rose** (one year hourly, seeds 574716103 and 777):
  - W and NW over 45 %;
  - NE, E and SE under 15 % together, and SE plus E over 2 %;
  - mean from 280 to 320;
  - constancy 0.45 to 0.7;
  - 50 to 70 % within 45° of WNW.
- **Smooth:** the heading moves under 60° per 10 game minutes. The sharpest step is the back at a front, about 40°.
- **Fronts:** over a year, while the rain is coming on, the mean turn is above +10° (veered); while it eases, below −20° (backed). A Python copy of the noise gives +29° and −58°.
- **The pictures' front:**
  - day 107 22:00 is raining on a veered WNW wind (about 298°, turn above +20°);
  - day 108 07:00 has backed to SSW (about 194°), still raining and windier (wind above 0.5);
  - day 109 noon is from the WNW (about 283°).
- **Local wind:**
  - the coast keeps the wind and inland keeps 0.85; lee 0.35, canopy 0.2; the coast's gust is lower;
  - no slope breeze in a 10 m/s wind;
  - the bent heading stays next to the world's.
- **Slope hours** (day 109, 1.7 m/s, clear):
  - about 3 m/s down a steep slope before dawn, and the wind then runs downhill;
  - a gentle slope drains more weakly;
  - full by 1.5 h after sunset;
  - little either way 2 h after sunrise;
  - up the slope in the sunny afternoon;
  - none under full cloud or on the flat;
  - smooth through the day (under 0.4 m/s per 6 minutes).
- **Sea breeze:**
  - 2 to 4 m/s onshore on a calm sunny afternoon, blowing in from the sea;
  - none in a 6 m/s wind;
  - not yet at 08:00;
  - a 1 to 2 m/s land breeze at night.

`test_weather` still passes unchanged: it runs with the switch off.

## 6. Pictures for Dino

All pictures are in the base world. Set the day with `mkday N` and `PERSIST_STORE=$DAYS/dN` (KATHLEEN_PICTURE_PLAN.md). There is no flag any more: every line is the game as it is. **The front pictures of days 107 and 108 below were picked for the 57° S tuning.** At 34° S use day 281 21:00 (veered to NNE, from about 34) and day 282 04:00 (backed to WSW, from about 248, the squall at its peak). `test_wind_dir` checks both.

Up to this PR's head, the only wind visual on main is the wind-cue specks. The check is mostly the log line `shot runner: wind: ...` after each picture, and Dino copies those lines with the pictures. When #680 (smoke) and the rain stack (#649) are on main, the same cameras show smoke and rain lean. Dino retakes then with the same lines.

**Day 109, ON** (one start, five pictures):
```
mkday 109; PERSIST_STORE=$DAYS/d109 art/playthrough/rig.sh --name wd_noon_spawn \
  --at 53296,68080 --agl 1.7 --yaw 0 --pitch 0 --hour 12 --weather live --wait 60 --settle 20 \
  --more-shots "wd_noon_coast:52600,1.7,66592,90,0,12,live,-1;wd_sea_breeze:52600,1.7,66592,-90,0,14.5,clear,-1;wd_night_spawn:53296,1.7,68080,0,0,23,clear,-1;wd_night_fire_site:53301,1.7,68427,0,0,23,clear,-1"
```

| Picture | Camera (x, height, z, yaw, pitch, hour, weather) | Must show in the log line | Never |
|---|---|---|---|
| wd_noon_spawn | 53296, 1.7 m, 68080, yaw 0 (north), pitch 0, 12:00, live | world from 283 ±5; from within 20° of that; about 7 to 9 m/s; sea upwind under 0.3 | world from 340 to 20 (the old heading, about 355) |
| wd_noon_coast | 52600, 1.7 m, 66592, yaw 90 (west, to the sea), 12:00, live | sea upwind 0.6 or more; m/s above wd_noon_spawn's; gust x1.45 or under | sea upwind 0 (then the coast camera is not on the coast: tell me) |
| wd_sea_breeze | 52600, 1.7 m, 66592, yaw -90 (east, inland), 14:30, clear (1 m/s) | sea breeze +2.5 to +4 m/s; from within 60° of the sea's side (west) | sea breeze 0 with sea upwind above 0 |
| wd_night_spawn | 53296, 1.7 m, 68080, yaw 0, 23:00, clear | a slope breeze of +0.5 to +3 m/s if grade is 0.05 or more, with "from" uphill of "downhill toward"; +0.0 if grade is under 0.05 | a negative slope breeze at night |
| wd_night_fire_site | 53301, 1.7 m, 68427, yaw 0, 23:00, clear | the same rule as wd_night_spawn | the same |

If both night shots print a grade under 0.05, there is no slope picture this round. Dino sends the two grade lines, and I pick a slope from them.

**Days 107 and 108, ON** (the front; two starts, live weather):
```
mkday 107; PERSIST_STORE=$DAYS/d107 art/playthrough/rig.sh --name wd_front_before \
  --at 53296,68080 --agl 1.7 --yaw 0 --pitch 0 --hour 22 --weather live --wait 60 --settle 20
mkday 108; PERSIST_STORE=$DAYS/d108 art/playthrough/rig.sh --name wd_front_after \
  --at 53296,68080 --agl 1.7 --yaw 0 --pitch 0 --hour 7 --weather live --wait 60 --settle 20
```

| Picture | Must show | Never |
|---|---|---|
| wd_front_before (day 107, 22:00, facing north) | rain falling; world from 298 ±8 | dry; or world from under 270 |
| wd_front_after (day 108, 07:00, facing north) | still raining; world from 194 ±12 (backed to SSW); wind stronger than before (F3 wind above 0.5) | world from 280 to 320 (no back) |

**OFF** (one start, for the same picture without the flag):
```
mkday 109; PERSIST_STORE=$DAYS/d109 art/playthrough/rig.sh --name wd_off_noon_spawn --at 53296,68080 --agl 1.7 --yaw 0 --pitch 0 --hour 12 --weather live --wait 60 --settle 20
```
- **Must show:** no `shot runner: wind:` line, since the flag is off; the wind-cue specks drift toward the south.
- **Never:** a `wind:` line, which would mean the flag leaked in.

The expected numbers come from a Python copy of `Weather._noise` for seed 574716103. The test checks the same days in Godot. If the test passes and a picture's line disagrees, the client did not get the flag. If the test fails on these days, my copy of the noise is wrong: send me the printed lines and I re-time the front.
