# Sky mathematics, climate interface and checks

[Environmental design](art_weather_light.md) owns the intended sky/light/seasonal appearance. This reference preserves mathematics and check cases from the 8 Nov one-sky work. Dave's grid ruling and later feature-enable decision are recorded in [overnight decisions](OVERNIGHT_DECISIONS_8NOV.md) rows 19/25. The old `--one-sky`/`--moon-phase` flags and 52° N fallback are removed, not a pending veto gate. No new Godot/PC evidence is claimed.

## 1. What changes
**Grid:**21×21 tiles, equator `world.json::equator_tile_row`0; north−Z, south+Z. `Climate.latitude_of_row(row,equator_row) = clamp(-(row-equator_row)*DEG_PER_ROW,-90,90)`. Recorded spread 90/10.5=8.57° per row (`world_settings.gd::latitude_for_z`×90). Starter tile(3, 4), row 4 centre 34.3° S, not 57° S. Spawn~33.7° S/cave 8002~36.1° S are position examples; current sky uses tile-row latitude, not an assertion it samples continuous latitude each frame. `terrain_client.gd` refreshes row about once/second and sets `day_cycle.gd::sky_row_latitude`; fallback before fix/server is `Climate.STARTER_ROW`4. Northern row−4 gets the corresponding northern sky.

**Calendar:** day 0 is starter spring equinox. Let p=year phase, s=`Climate.calendar_sign()` (−1 for southern starter), axial tilt ε=23.44°. Sun declination δ=s ε sin(2πp); starter summer p 0.25/day 91, winter p 0.75/day 274. `Climate.local_year_phase(year_phase,row,equator_row)` offsets the opposite hemisphere by half a year for place-based season reads. See §7 for remaining climate scope; a sky formula alone does not prove every temperature reader is row-local.

**Sun:** signed latitude φ; hour angle h=15°(hour−12). Local direction before normalization:

- sin(altitude)=sinφ sinδ+cosφ cosδ cosh;
- east=−cosδ sinh;
- north=sinδ cosφ−cosδ sinφ cosh;
- world north is−Z.

Southern starter noon sun north/shadows south. Recorded centre-row targets: daylight 14.3 h summer/9.7 h winter (sun centre), noon 79°/56°/32° at summer/equinox/winter. Actual sunrise/set includes the horizon convention below.

**Moon:** phase 0=new, 0.5=full; ecliptic offset 2π×moon_phase east of sun, omitting orbital 5° tilt. Southern-calendar example: solar longitude λ☉=2πp+π, lunar λ☾=λ☉+2π×moon_phase. Lunar declination ε sinλ☾; right ascension α=atan 2(cosε sinλ, cosλ); lunar hour angle is sun's minus lunar−solar right ascension. A full moon is opposite in declination, high in winter/low in summer. `day_cycle.gd::moon_on_ecliptic` owns general calendar-sign implementation; the old permanently opposite-sun light is superseded.

`weather.gd::sunrise_hour(day,latitude_deg)` uses the same latitude/declination as day cycle. Fog timing uses actual sunrise as a tendency under Dave's current fog design, not the old unconditional 1–3 h burnoff.

## 2. Check numbers (local solar time, sun centre)
**Pinned 57° S fixture, not starter predictions.** Rise/set at−0.833° (upper limb/refraction):

| season (year phase, game day) | sunrise | noon | sunset | midnight sun |
|---|---|---|---|---|
| midsummer (0.25, day 91) | 03:04, bearing 139° (SE) | 56.4° high, due north | 20:56, bearing 221° (SW) | -9.6° (nautical twilight all night) |
| equinox (0 and 0.5, day 0 and 182) | 05:54, due east | 33.0° | 18:06, due west | -33.0° |
| midwinter (0.75, day 274) | 08:39, bearing 45° (NE) | 9.6° | 15:21, bearing 315° (NW) | -56.4° |

Retained 57° S checks: full moon day 100 near midnight~10° high north, day 278~55°; phase 0.9/day 329 noon 19.5°, 30° south-facing slope gets no direct noon sun; summer sun stays above−12° overnight. Old 52° N61.4°/14.6° seasonal noon figures are history only; there is no switch-off gameplay path to test.

## 3. Tests
`src/worldgen/tools/test_one_sky.gd` pins `sky_row_latitude=-57` for the table and separately checks grid rows. Preserve scopes/tolerances:

- noon 56.4/33.0/9.6°, ±0.2°, north(z<0); shadow+Z;
- rise/set table within 3 min, bearings±1.5°; binary horizon crossing−0.833°;
- summer midnight−9.6°±0.2°;
- full-moon summer highest 9.6°±0.5° north; winter>50°;
- equinox first quarter up 18:00, set by 03:30 (original spring~03:10, autumn 21:25);
- phase 0.9 noon 19.5°±0.5°, south-facing 30° normal dot sun<=0;
- weather sunrise matches day-cycle horizon crossing within 2 min;
- grid sign/equator/clamping, opposite-hemisphere seasons and actual starter latitude are separate from 57° S fixtures.

Current source tests are the runnable checks; this list is not a test result. Follow permitted runner/test gates, with no cloud Godot run.

## 4. Pictures
Authorized PC: compare summer/winter noon and sunrise/sunset, summer midnight and low/high full moons, facing north/south. Use actual row latitude for expected times/heights; do not apply 57° S camera targets to 34° S starter. Test days retained:91/274 summer/winter, 100/278 full moons; view from spawn x 53296, z 68080, AGL1.7 m. Fallback if blocked:53326, 68056, AGL4 m. Yaw 0=north, 180=south; yaw−B is compass bearingB. Capture F3/day/seed/row/weather and observed shadows. Rig holds hour; normal settle is sufficient. Set day through the approved persistence/rig procedure rather than changing Dave's live save.

Original 57° S shot purposes retained: `sky_summer_noon_n`/`_s` (sun vs shadows), `sky_summer_rise`, `sky_summer_midnight`, `sky_winter_noon`/`_set`, `moon_summer_full`/`moon_winter_full`. Exact old camera rows/commands remain in [source history](https://github.com/DSul3791/DynastyALWL/blob/090129ec43942e90a28eb7c4fd0d202df3ee68c3/docs/design/one_sky_design.md); their obsolete enable switches and 52° N off-comparison are not current instructions.

## 5. What else follows the hemisphere
Snow/cirques favour shady south/south-east on the starter (A4 glacial rule 6), not the old northern shade assumption. A future moss/lichen pass should follow actual shade (south+Z here). Signs/stories asserting "sun in the south" must be checked against place, not a switch; the original data scan found none, not a permanent guarantee.

## 6. Cost and sources
Original estimate: a few extra trigonometric calls twice/second, no additional light/uniform. This is not measured GPU evidence. Sources: watershed A4 "One sky", [one-sky research](../knowledge/one-sky.md), `src/shared/climate.gd` and original 8 Nov notes. No current personal owner/queue is set here.

## 7. Temperature by row and the snow bias
The initial approximate 14.4 °C/−6 °C proposal was refined in overnight decision 21: current fallback starter sea-level mean 14.16 °C, snow_bias_c−5.16 °C (9−14.16), seasonal swing±5 °C, lapse 6.5 °C/km, warmest phase 0.375. `Climate._from_world` can override the mean from `world.json::temperature_by_abs_latitude`; the current implementation does **not** dynamically recompute the snow bias when the curve changes. Keep this limitation explicit rather than promising exact 9 °C biased climate for every record.

Plain air supplies HUD, breath/steam, warmth, fire, cold water, cave air/springs and weather `temp_c`. Only snow/ice (`Ice.cover`, `Ice.season`, snowline/precipitation phase) add bias. The old "code waits after freeze" instruction is superseded by existing reads. Original open issue retained: northern-place temperature season reads must actually use local phase, not blindly reuse southern warmest-phase timing; nonstarter zone values remain placeholders until proper per-island records. Check each climate consumer before claiming world-wide alignment.
