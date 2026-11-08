# One sky: where the sun and moon are on the starter island (57° S)

**Last checked:** 2026-11-08 (Jamie; Sonny's decision and sun times, checked here with the standard solar formulas). **Owners:**
- Sonny decided the sky.
- Kathleen: the sun and moon in `src/client/day_cycle.gd`, night light.
- Everyone who uses shade: snow, melt, cirques, fuel wetness, dens.

**Related:** [snow-on-slopes.md](snow-on-slopes.md), [snow-lines-mountain-climate.md](snow-lines-mountain-climate.md), [cirques-and-horns.md](cirques-and-horns.md), [glaciers-mountains.md](glaciers-mountains.md), `moonlight-starlight.md` (#679).

## The rule

- **Where the island is:** the starter island is at **57° S**, from `world.json` and `latitude_for_z` in `world_settings.gd`. North is −Z.
- **The noon sun stands in the north.** So:
  - shaded faces are the **south-facing (+Z)** slopes;
  - late snow, summer snow patches and cirques favour **south to south-east**, which is shade plus the lee of the westerlies;
  - sunny, early-melting and drier slopes face north.
- **Every page in this library now uses this.** The Scottish and other northern-hemisphere sources are the same physics mirrored: their north is our south.
- **Today's code** (`day_cycle.gd`, read 8 Nov, not tested) still draws the sun for 52°N (`LATITUDE_DEG`), standing in the south at noon. It must change to match, or the shadows on screen will contradict the snow.

## Sun times (Sonny's, checked here)

Times are local solar time. Sunrise and sunset use the usual −0.833° (refraction plus half the disc). Azimuth is from north, clockwise.

| Day | Sunrise | Sunset | Day length | Noon sun | Rise and set direction |
|---|---|---|---|---|---|
| Midsummer (December solstice) | 03:04 | 20:56 | 17.9 h | 56.4° high, in the north | rises at 139° (south-east), sets at 221° (south-west) |
| Equinox | 05:54 | 18:06 | 12.2 h | 33.0° | rises due east, sets due west |
| Midwinter (June solstice) | 08:39 | 15:21 | 6.7 h | 9.6° | rises at 45° (north-east), sets at 315° (north-west) |

**Our sums** (same formulas):
- **Twilight:**
  - **Midsummer:** the sun goes only 9.6° below the horizon at midnight. Civil twilight (sun 6° down) ends at about 22:05, and nautical twilight lasts all night. So the sky is **never fully dark**: a pale glow stays low in the south.
  - **Equinox:** civil twilight ends at 18:44, nautical at 19:30, and full dark comes at 20:18.
  - **Midwinter:** civil twilight ends at 16:11, nautical at 17:02, and full dark comes at 17:49. The winter night is about 14 hours of real dark.
- **Late winter (August):** the noon sun is only 19.5° high. A 30° south-facing slope gets no direct sun all day, which is why its snow lasts (`snow-on-slopes.md` lesson 3).

## The moon

- **Where:** the moon sits **360° × phase east of the sun** along the sky.
  - New moon (phase 0) is beside the sun, and is up by day and unseen.
  - First quarter (0.25) is 90° east, highest at sunset, and sets about midnight.
  - Full moon (0.5) is opposite the sun: it rises at sunset and is up all night.
  - Last quarter (0.75) rises about midnight and is highest at dawn.
- **Timing:** moonrise comes about phase × 24 h after sunrise, about 50 minutes later each day.
- **How high:** a full moon rides high in winter and low in summer. At midsummer the full moon stands where the midwinter sun does, low in the north, about 10° at its highest (our sums). A midwinter full moon climbs to about 56°.
- **How bright:** see `moonlight-starlight.md` (#679). A quarter moon gives 8 to 9% of a full moon's light.
- **Today's code** puts the moon always opposite the sun (`moonlight-starlight.md`, `CONTRADICTIONS.md` B5).

## Never-see checks

- the noon sun in the south, or shadows pointing north at noon;
- the last spring snow on a north-facing slope;
- a pitch-black midsummer midnight;
- a full moon high overhead on a midsummer night;
- a crescent moon up at midnight.

## Sources

- Sonny's decision and sun times (8 Nov 2026), from `worlds/base_world/world.json` and `world_settings.gd` `latitude_for_z`.
- Standard solar geometry for the checks (declination ±23.44°, hour angle, −0.833° for sunrise and sunset; −6°, −12° and −18° for civil, nautical and astronomical twilight).
