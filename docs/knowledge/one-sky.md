# One sky: where the sun and moon are on the starter island (about 34° S)

**Last checked:** 2026-11-08 (Jamie; latitude corrected from 57° S to the grid's 33.7° S after Dave's 21 by 21 grid note, sun times redone with the standard solar formulas). **Owners:**
- Sonny decided the sky.
- Kathleen: the sun and moon in `src/client/day_cycle.gd`, night light.
- Everyone who uses shade: snow, melt, cirques, fuel wetness, dens.

**Related:** [snow-on-slopes.md](snow-on-slopes.md), [snow-lines-mountain-climate.md](snow-lines-mountain-climate.md), [cirques-and-horns.md](cirques-and-horns.md), [glaciers-mountains.md](glaciers-mountains.md), `moonlight-starlight.md` (#679).

## The rule

- **Where the island is:** the world is a 21 by 21 grid of islands with the centre row as the equator (Dave, 8 Nov). Our starter is tile (3, 4), four rows south of the equator, since north is −Z.
  - `latitude_for_z` in `world_settings.gd` puts the poles at the wrap seam, 10.5 rows out, so one row is 90 ÷ 10.5 = 8.57°.
  - Row 4 spans 30.0° to 38.6° S. The spawn is at **33.7° S**, the tile centre 34.3° S and cave 8002 36.1° S (`OVERNIGHT_DECISIONS_8NOV.md` row 19, #717).
  - The other inner starters (rows ±4) sit near 34° N or S, and the outer ones (rows ±6) near 51°. So the sky should read the latitude from the position (`latitude_for_z(z) × 90`), not a constant.
  - An earlier version of this page said 57° S. That was wrong.
- **The noon sun stands in the north.** So:
  - shaded faces are the **south-facing (+Z)** slopes;
  - late snow, summer snow patches and cirques favour **south to south-east**, which is shade plus the lee of the westerlies;
  - sunny, early-melting and drier slopes face north.
- **Every page in this library now uses this.** The Scottish and other northern-hemisphere sources are the same physics mirrored: their north is our south.
- **Today's code** (`day_cycle.gd`, read 8 Nov, not tested) still draws the sun for 52°N (`LATITUDE_DEG`), standing in the south at noon. It must change to match, or the shadows on screen will contradict the snow. Kathleen's #711 (`--one-sky`) sets `latitude_deg` −57, which should become the position's latitude.

## Sun times at the spawn (33.7° S, our sums)

Times are local solar time. Sunrise and sunset use the usual −0.833° (refraction plus half the disc). Azimuth is from north, clockwise.

| Day | Sunrise | Sunset | Day length | Noon sun | Rise and set direction |
|---|---|---|---|---|---|
| Midsummer (December solstice) | 04:48 | 19:12 | 14.4 h | 79.7° high, in the north | rises at 119° (east-south-east), sets at 241° (west-south-west) |
| Equinox | 05:56 | 18:04 | 12.1 h | 56.3° | rises due east, sets due west |
| Midwinter (June solstice) | 07:03 | 16:57 | 9.9 h | 32.9° | rises at 61° (east-north-east), sets at 299° (west-north-west) |

**Our sums** (same formulas):
- **Twilight** is short at this latitude, about 30 minutes for each stage:
  - **Midsummer:** civil twilight ends at 19:41, nautical at 20:17, and full dark comes at 20:56. Midsummer nights are fully dark for about 6 hours.
  - **Equinox:** civil twilight ends at 18:29, nautical at 18:58, and full dark comes at 19:27.
  - **Midwinter:** civil twilight ends at 17:25, nautical at 17:56, and full dark comes at 18:27. The winter night has about 11 hours of full dark.
- **Late winter (August):** the noon sun stands 42.5° high. A 30° south-facing slope still gets a little direct sun at midday (about a quarter of flat ground's daily total), and only south faces steeper than about 45° get none (`snow-on-slopes.md` lesson 3). At midwinter the noon sun is 32.9° high, so south faces steeper than about 33° see no direct sun at all.

## The moon

- **Where:** the moon sits **360° × phase east of the sun** along the sky.
  - New moon (phase 0) is beside the sun, and is up by day and unseen.
  - First quarter (0.25) is 90° east, highest at sunset, and sets about midnight.
  - Full moon (0.5) is opposite the sun: it rises at sunset and is up all night.
  - Last quarter (0.75) rises about midnight and is highest at dawn.
- **Timing:** moonrise comes about phase × 24 h after sunrise, about 50 minutes later each day.
- **How high:** a full moon rides high in winter and low in summer. At midsummer the full moon stands where the midwinter sun does, about 33° at its highest, in the north (our sums). A midwinter full moon climbs to about 80°, nearly overhead.
- **How bright:** see `moonlight-starlight.md` (#679). A quarter moon gives 8 to 9% of a full moon's light.
- **Today's code** puts the moon always opposite the sun (`moonlight-starlight.md`, `CONTRADICTIONS.md` B5).

## Never-see checks

- the noon sun in the south, or shadows pointing north at noon;
- the last spring snow on a north-facing slope;
- a long, light midsummer night (the summer dusk is short: full dark by about 21:00);
- a full moon high overhead on a midsummer night (it stays near 33°);
- a crescent moon up at midnight.

## Sources

- The latitude: Dave's 21 by 21 grid (8 Nov 2026), `worlds/base_world/world.json` (rows −10 to +10, equator row 0, starter tiles) and `world_settings.gd` `latitude_for_z`. Sonny's first sun times were for 57° S and are replaced here.
- Standard solar geometry for the checks (declination ±23.44°, hour angle, −0.833° for sunrise and sunset; −6°, −12° and −18° for civil, nautical and astronomical twilight).
