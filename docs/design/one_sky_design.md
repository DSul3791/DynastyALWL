# One sky: the sun and moon of the starter island at 57° S

**Owner:** Kathleen. **Status:** design, 8 Nov 2026.
**Reads:**
- Sonny's A4 "One sky" (`docs/water/watershed_rebuild_design.md`, R2 branch `sonny-watershed-r2-evolve`);
- Jamie's one-sky page `docs/knowledge/one-sky.md` (#706);
- the one-temperature climate record `src/shared/climate.gd` (#620).

The change sits behind one switch, `--one-sky`. It is off until Dave has seen the pictures, because flipping the hemisphere is his to veto. With the switch off, the sky is today's: 52° N, the noon sun in the south.

## 1. What changes

Today `day_cycle.gd` (`LATITUDE_DEG`) and `weather.gd` (`SUN_LATITUDE_DEG`) both fix the sky at 52° N for every island. Sonny's A4 puts the starter island at **57° S**. Two reasons:
- its 9 °C ±5 °C climate is that of the Hebrides and Skye;
- `world_settings.gd` `latitude_for_z` puts the starter rows south of the equator row.

The climate record now carries `latitude_deg`, signed with south negative (starter -57). With `--one-sky`:

- **Latitude.** The sun and moon read `latitude_deg` from the island's climate record.
  - `climate.gd` `DEFAULTS["starter"]` gets `latitude_deg: -57.0`, and `Climate.latitude_deg(climate)` reads it.
  - An island without one takes the starter's until its record has one. Their warmest phase, 0.375, is the southern calendar too.
- **The calendar is the starter island's.** Day 0 is its spring equinox. The sun's declination is δ = -23.44° × sin(2π × year phase), so midsummer is phase 0.25 (game day 91) and midwinter 0.75 (day 274). That is the same season order the game has today, so the seasons, the temperature and the flora do not move. Only the sun's path changes.
- **The sun's position** is the standard one, with the signed latitude φ and the hour angle h = 15° × (hour - 12):
  - sin(altitude) = sin φ sin δ + cos φ cos δ cos h;
  - east = -cos δ sin h;
  - north = sin δ cos φ - cos δ sin φ cos h;
  - north is -Z.

  So on the starter island the noon sun stands **due north (-Z)**, sunlit faces look north, and **shadows point south (+Z)**, as Jamie's snow pages need.
- **The moon** sits 360° × its phase east of the sun *along the ecliptic*, with the 5° tilt of its orbit left out (0 new, 180° full).
  - Ecliptic longitudes: the sun's is λ☉ = 2π × phase + π (its declination is the sun's δ above), and the moon's is λ☾ = λ☉ + 2π × moon phase.
  - The moon's declination is 23.44° × sin λ☾.
  - Its hour angle is the sun's minus the difference in right ascension, where α = atan2(cos ε sin λ, cos λ).

  A full moon therefore stands opposite the sun in declination too. It rides high in midwinter and low in midsummer, which the sun's own declination, used by `--moon-phase` (#681), cannot do. The moon's place only matters with `--moon-phase` on; without it, the moonlight stays opposite the sun, as today.
- **`weather.gd`** `sunrise_hour(day, group)` uses the same latitude and declination, so the valley fog still burns off 1 to 3 hours after the real sunrise.

This stacks on #681 (moon phase), whose `moon_direction` it extends.

## 2. Check numbers (local solar time, sun centre)

Sonny's table, which the formula reproduces with rise and set at -0.833° (the upper limb with refraction):

| season (year phase, game day) | sunrise | noon | sunset | midnight sun |
|---|---|---|---|---|
| midsummer (0.25, day 91) | 03:04, bearing 139° (SE) | 56.4° high, due north | 20:56, bearing 221° (SW) | -9.6° (nautical twilight all night) |
| equinox (0 and 0.5, day 0 and 182) | 05:54, due east | 33.0° | 18:06, due west | -33.0° |
| midwinter (0.75, day 274) | 08:39, bearing 45° (NE) | 9.6° | 15:21, bearing 315° (NW) | -56.4° |

Jamie's checks (#706):
- **The midsummer full moon** (day 100, midnight) stands only about 10° high, due north. The midwinter full moon (day 278) stands about 55° high.
- **Late winter, mid-August in real-world terms (phase 0.9, day 329):** the noon sun is 19.5° high. A 30° slope facing south (+Z) gets no direct sun at noon: the sun is behind the slope's crest.
- **Midsummer** has nautical twilight all night: the sun is never more than 12° down.

With the switch off, every number above stays at today's 52° N values: midsummer noon 61.4° due south, midwinter noon 14.6°.

## 3. Tests (`src/worldgen/tools/test_one_sky.gd`, headless, no world)

- **Noon:**
  - 56.4°, 33.0° and 9.6° (±0.2°) at phases 0.25, 0 and 0.75;
  - the sun's direction has z < 0 (north), so a shadow points to +Z.
- **Rise and set** (found by halving to -0.833°), all within ±3 minutes, with bearings within ±1.5°:
  - midsummer 03:04 at 139° and 20:56 at 221°;
  - equinox 05:54 and 18:06;
  - midwinter 08:39 at 45° and 15:21 at 315°.
- **Midsummer midnight:** the sun is at -9.6° (±0.2°).
- **The moon:**
  - the midsummer full moon's highest point is 9.6° (±0.5°), in the north;
  - the midwinter full moon is above 50°;
  - a first-quarter moon is up at 18:00 at either equinox and has set by 03:30 (about 03:10 in spring, when it rides high, and 21:25 in autumn).
- **Phase 0.9:** noon 19.5° (±0.5°), and a 30° slope facing +Z gets no direct sun (its normal dotted with the sun direction is at most 0).
- **Switch off:** midsummer noon is 61.4° due south, as today.
- **`Weather.sunrise_hour(day, "temperate")`** with the switch on matches the day cycle's own horizon crossing within 2 minutes.

## 4. Pictures for Dino (Dave's veto)

**Days.** Set each day with `mkday N` and `PERSIST_STORE` (`docs/design/KATHLEEN_PICTURE_PLAN.md`). Days used: 91, 274, 100 and 278.

**Switch.** Take every shot twice:
- switch on: `--client-arg --one-sky` plus `SERVER_ARGS=--one-sky`, and `--client-arg --moon-phase` for the moon shots;
- switch off: the same command without those (name suffix `_off`).

**Place.** The open ground at the spawn, x 53296, z 68080, 1.7 m up. Yaw 0 faces north (-Z), 180 faces south (+Z), and -B faces compass bearing B.

| name | day | camera x, agl, z | yaw | pitch | hour | what Dave should see (switch on) |
|---|---|---|---|---|---|---|
| sky_summer_noon_n | 91 | 53296, 1.7, 68080 | 0 | 30 | 12 | the sun high in the north, 56° up, the near side of things lit |
| sky_summer_noon_s | 91 | 53296, 1.7, 68080 | 180 | -15 | 12 | shadows running away from the camera (south), the sun behind it |
| sky_summer_rise | 91 | 53296, 1.7, 68080 | -136 | 3 | 3.5 | the sun just up in the south-east, gold light, long shadows |
| sky_summer_midnight | 91 | 53296, 1.7, 68080 | 180 | 5 | 0 | a bright twilight sky to the south, never full night |
| sky_winter_noon | 274 | 53296, 1.7, 68080 | 0 | 5 | 12 | the sun low in the north, under 10°, long shadows |
| sky_winter_set | 274 | 53296, 1.7, 68080 | 43 | 3 | 15 | the sun setting in the north-west |
| moon_summer_full | 100 | 53296, 1.7, 68080 | 0 | 8 | 0 | a full moon low in the north, about 10° up, long moon shadows |
| moon_winter_full | 278 | 53296, 1.7, 68080 | -18 | 50 | 0 | a full moon high in the north, about 55° up |

Shot strings (`name:x,agl,z,yaw,pitch,hour,weather`):

```
mkday 91;  PERSIST_STORE=$DAYS/d91  SERVER_ARGS=--one-sky art/playthrough/rig.sh --client-arg --one-sky --name sky_summer_noon_n --at 53296,68080 --agl 1.7 --yaw 0 --pitch 30 --hour 12 --weather clear --more-shots "sky_summer_noon_s:53296,1.7,68080,180,-15,12,clear;sky_summer_rise:53296,1.7,68080,-136,3,3.5,clear;sky_summer_midnight:53296,1.7,68080,180,5,0,clear"
mkday 274; PERSIST_STORE=$DAYS/d274 SERVER_ARGS=--one-sky art/playthrough/rig.sh --client-arg --one-sky --name sky_winter_noon --at 53296,68080 --agl 1.7 --yaw 0 --pitch 5 --hour 12 --weather clear --more-shots "sky_winter_set:53296,1.7,68080,43,3,15,clear"
mkday 100; PERSIST_STORE=$DAYS/d100 SERVER_ARGS=--one-sky art/playthrough/rig.sh --client-arg "--one-sky --moon-phase" --name moon_summer_full --at 53296,68080 --agl 1.7 --yaw 0 --pitch 8 --hour 0 --weather clear
mkday 278; PERSIST_STORE=$DAYS/d278 SERVER_ARGS=--one-sky art/playthrough/rig.sh --client-arg "--one-sky --moon-phase" --name moon_winter_full --at 53296,68080 --agl 1.7 --yaw -18 --pitch 50 --hour 0 --weather clear
```

Then repeat each line without the switches, with `_off` added to each name.

**Fallback** if the spawn view is blocked by a hill or trees in the north: x 53326, z 68056, 4 m up, the trees camera of #682, with the same yaws and hours.

**Settle.** The rig holds the hour, so the sun stands still. The default settle is fine.

## 5. What else follows the flip (not in this change)

- **Snow.** Late snow and the cirques favour the shady south to south-east faces (Sonny's rule 6 aspect term). The snow layer comes baked from the record, so the art follows by itself.
- **Moss and lichen.** If an art pass ever puts moss on the shady side of rocks and trunks, it goes on the south (+Z) side here.
- **Signs and stories.** Any sign or story that says "the sun in the south" needs the switch's answer. None has been found in `data/` so far.

## 6. Cost

A few more trig calls twice a second, the same as today: no new light, no new uniform.
