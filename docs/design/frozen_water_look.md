# Frozen water look: skim, sheet, snow, holes and thaw

**Owner:** Kathleen. **Status:** design, 8 Nov 2026. **Behind:** `--frozen-water` (client only, off until Dino's pictures).
**Builds on:** `still_water_ice.md` (the ice rule, `src/shared/ice.gd`, unchanged). **Reads:** Jamie's snow pages (`snow-on-slopes.md`, `snow-lines-mountain-climate.md`, #632 and #594) and water clarity (`water-clarity-after-rain.md`, #623). Neither page covers ice, so the ice facts below come from the sources in section 8.
**Why now:** Steve's drink rules (#719, #720) refuse frozen water without an ice hole, so the player has to be able to see when water is frozen, and see the hole.

## 1. What is wrong today

- **No ice is drawn anywhere on land water.** Since 2 Nov every chunk's water is a liquid sheet (`flora_view.gd` `LIQUID_CHUNKS := true`, `src/water2/liquid_surface.gd`), and the liquid sheet has no ice. The ice look of 8 Nov (`still_water_ice.md`) lives in `water_material.gd`, which now only draws chunks when `LIQUID_CHUNKS` is false. The walkable ice collider (`flora_view._draw_ice`) and the ice sounds still follow `Ice.cover`, so a player can stand on ice they cannot see.
- **Running water never freezes, and slow water freezes like a pond.** The old look was still water only (`steep < 0.02`). It had no river edges, and nothing kept spring water open.
- **No snow lies on ice, there is no thaw order, and a fishing hole has no look.** The server keeps the holes (`server_items._holes`) and never sends them.

## 2. What the starter island's winter actually gives

These sums come from a Python copy of `Ice.cover` and `Climate` for seed 574716103 (scratch only). The test checks the same days in Godot.

| Place | Coldest morning in the first three years | Ice (`open`, 3 m pond) | Thickness |
|---|---|---|---|
| Pond near spawn (about 50 m) | day 342, 07:00, air -2.3 °C | 0.14 | 2.8 cm |
| Spring #8002 level (533 m) | day 343, 09:00, air -2.3 °C after a -5 °C night | 0.28 | 5.6 cm |

So on the starter island **ice never bears a person** (cover 0.5, 10 cm), and it is gone by mid-afternoon on most days. That is right for a Fort William climate, where lowland ponds get a skim on frosty mornings and seldom hold. It shapes the look:

- **On the starter island,** the ice is mostly dark skim, a white frost rim on the shore, and grey film. It is drinkable through, because `_on_ice` needs cover 0.5.
- **The grey-white sheet with snow** belongs to the high corries, the colossal peaks and the arctic. The look still has to be right there, so the forced pictures in section 7 show it.
- **The rule the player learns:** dark ice is thin, and you break it with a hand. Grey-white ice is solid, and you need a hole.

## 3. Where ice forms

All of this is per pixel on the liquid sheet. Every sheet draws it: the live window, chunk sheets and Sullivan fine sheets.

1. **Shallows first.** Two covers are worked out once a second: `open` is today's `Ice.cover` at 3 m (`ICE_POND_DEPTH_M`, unchanged), and `shore` is the same at 1 m. 1 m is the depth `ice.gd` treats as shallowest (2-day water lag, faster freeze). Water shallower than 0.3 m takes `max(open, shore)`, water deeper than 2 m takes `open`, and depths in between blend. A noise patch pattern (the old look's) breaks the sheet's edge into lobes. So on a frosty night the ice creeps in from the bank.
2. **The current decides.** `speed` is the sheet's own current in m/s.
   - Below 0.3 m/s the water freezes like a pond.
   - From 0.3 to 0.5 m/s the sheet thins out: no full sheet forms above 0.5 m/s. That is the USACE rule that sheet ice forms where the flow is under 0.5 m/s (source 1).
   - From 0.5 to 0.9 m/s only **border ice** forms: a shore band where the water is shallower than 0.15 m plus up to 1.5 m more as the cover grows. River ice starts as border ice in the slower water along the banks (source 2).
   - From 0.9 m/s the water stays open: riffles, rapids and fall faces (`fall`), where the water is turbulent.
3. **Springs keep their water open.** A spring comes out at the year's mean plus 1 °C (6.5 °C at #8002, Steve's design) and never freezes. Its brook stays open for Sonny's open length `x0 = λ ln((Tw − Ta)/(0 − Ta))`.
   - The client has no brook rows, so it uses one λ for every spring: λ = 840 m, the value that gives Sonny's worked example (810 m on a -4 °C night, Tw 6.5 °C).
   - The client takes `x0` as a radius round each spring pool it knows (the cave stream packets, `cave_streams._pools`, up to 8 nearest). Ice fades in between 0.8 x0 and x0.
   - Above -0.5 °C the air counts as -0.5, which gives about 2.2 km, so the radius never jumps to infinity at noon.
   - A brook winds, so the open stretch along it is a little shorter than the radius. Steve's baked `below_spring_m` rows (his step 2) can replace the radius later.
   - The cave pools themselves are drawn by `cave_streams.gd`, which has no ice. Cave water never freezes, which is right (`cave-microclimate.md`, never-see 2).

## 4. How it looks

`cover` is the local cover from section 3, and 1 is a 20 cm sheet.

| Ice | Cover | Look |
|---|---|---|
| **Skim (black ice)** | under 0.12 (2.5 cm) | Clear. It reads dark, because you look through it into the water, the "black" ice of calm nights (sources 3, 4). Glossy and flat: the ripples, foam and rain rings stop. A few long straight white cracks. A white frost rim of crystals where it meets the bank. See-through, alpha about 0.6, so the bed shows in the shallows. |
| **Grey film** | 0.12 to 0.5 | Grey with a little blue (0.58, 0.64, 0.68), more opaque. White cracks in it are normal (source 4). A soft milky patchiness, the bubbles. |
| **Solid sheet** | 0.5 and up (10 cm, bears; `_on_ice`) | Grey-white (0.80, 0.85, 0.88), almost opaque. Cracks show darker grey. Little gloss, roughness 0.35. |

- **Snow on top.** Snow comes from `sound.weather.ground_snow`, the one lying-snow number (`weather_sounds.gd`).
  - It lies only on ice of 5 cm or more (cover 0.25). The cover is patchy, in drifts made by a noise pattern stretched across the wind, because wind scours bare patches on a lake (`snow-on-slopes.md` lesson 1).
  - The snow is matte white (0.92, 0.94, 0.96), roughness 0.9.
  - Snow falling on thinner ice turns to grey **slush** patches, darker and wet. This is the "top water" of source 3, which also makes white ice.
- **Thaw.** `thaw` (0 to 1) is how much of the last 30 days' thickest ice has gone: `1 − now / peak`. It counts only when the peak is at least 2.5 cm (cover 0.125).
  - **The shore goes first.** Shallow water near the shore warms fastest in spring, so the ice melts there first and leaves a moat of open water round the sheet (source 4). The moat covers water shallower than `1.6 x thaw` m.
  - **The sheet then greys.** It darkens toward wet grey (0.42, 0.46, 0.48) by `0.7 x thaw`, and gets a wet gloss.
  - **Then the middle goes.** The sheet breaks into lobes along its patch pattern, because thinner ice melts out first, and disappears.
  - This is the daily melt on the starter island and the spring break-up on the peaks. The order is the same, only slower.
  - `ice.gd` itself melts shallow ice a little later, since it grows thicker. The moat is a look rule on top of it. The walkable collider and the server still use the 3 m cover, so the player cannot fall into the moat. Section 9 asks Steve whether the moat should refuse a walk.

## 5. The ice hole

- **What it looks like.** A round hole of radius 0.3 m (0.6 m across), cut where the player stood. The inside is open dark water, at half the water colour, because the water under ice is dark. A ragged white rim of chips runs from 1.0 to 1.6 radii, with a few loose chips out to 2.2 radii. From its last sixth of life (the last 3 of `hole_game_h` 18 game hours) a thin black skin grows back across it, which is what makes it "freeze over".
- **The data.** A hole is `x, z, radius, age 0 to 1`, up to 8 nearest, in shader uniforms. The holes live on the server (`server_items._holes`) and are not sent today. **Steve's part:** send the nearby holes with the ice state, as `{pos, until}`. The client converts `until` to an age with `hole_game_h`. Until that exists, holes come only from the picture switch `--frozen-hole=x,z` (section 7).
- **Where it shows.** Only where the sheet is solid, cover 0.5 and up. A hole in skim makes no sense, and the server refuses to cut one there (`say_no_ice`).

## 6. Code

All of this is behind `--frozen-water`. With the switch off, nothing changes: the liquid sheets draw no ice, as today.

- **`src/shared/ice.gd`:** new `Ice.season(game_s, zone, altitude, depth, seed)` returns `{cover, peak}` from the same hourly loop. `cover` and `_thickness` give exactly what they give today: the loop is shared, and the server output is unchanged.
- **`src/client/frozen_water.gd` (new, pure):**
  - `look(...)` returns `Vector4(open, shore, thaw, snow)`;
  - `spring_c(zone, altitude)` and `spring_open_m(air_c, spring_c)`;
  - `springs_near(pools, at, air_c, zone)` and `holes_near(holes, at, now_s)` return up to 8 `Vector4`s each, nearest first;
  - `force_of(text)` parses the picture switch.
- **`src/water2/liquid_surface.gd`:**
  - new uniforms `frozen_on`, `ice_look`, `ice_springs[8]`, `ice_holes[8]` and their counts;
  - the ice block runs after the water colour. It draws section 3, section 4 and the holes, and dims Snell's window from below under a sheet;
  - a static `set_ice_all(...)` keeps the values, so a sheet made later starts with them, with no one-second flash of open water.
- **`scenes/terrain_client/terrain_client.gd` `_update_weather`:** when the switch is on, it works out the look every 5 s (two extra 720-step loops), the springs from `_cave_streams` and the holes, and calls `LiquidSurface.set_ice_all`. With `--frozen-force=open[,thaw[,snow]]` those numbers replace the computed ones, for pictures of a sheet the starter island never grows.
- **`src/client/fall_mist.gd`:** no change. It is in the `liquid_sheet` group, but the ice goes through the static, not `call_group`.
- **Test** `src/worldgen/tools/test_frozen_water.gd`: the switch is off by default; `season` matches `cover`; the section 2 days; the thaw on day 344; the spring open length (810 m at -4 °C); the force parse; hole ages; the shader carries the bands of sections 3 to 5. It has not been run here (no Godot in the cloud).

## 7. Pictures for Dino

Set the day with `mkday N` and `PERSIST_STORE=$DAYS/dN` (KATHLEEN_PICTURE_PLAN.md). All shots are first person (walk -1). Add `--client-arg --frozen-water` on every ON line, and send the F3 page for the first shot of each start.

**A. The pond near spawn, day 342, ON.** The pond is at 53316, 68476, about 50 m. One start, three pictures, live weather:
```
mkday 342; PERSIST_STORE=$DAYS/d342 art/playthrough/rig.sh --name fw_pond_dawn --client-arg --frozen-water \
  --at 53316,68495 --agl 2 --yaw 0 --pitch -15 --hour 7 --weather live --walk -1 --wait 60 --settle 20 \
  --more-shots "fw_pond_noon:53316,2,68495,0,-15,12,live,-1;fw_pond_late:53316,2,68495,0,-15,15,live,-1"
```

| Picture | Camera (x, height, z, yaw, pitch, hour) | Must show | Never |
|---|---|---|---|
| fw_pond_dawn | 53316, 2 m, 68495, yaw 0 (north), pitch -15, 07:00 | Dark glossy skim over most of the pond (cover 0.14, 2.8 cm). A white frost rim along the bank. No ripples on the ice. The bed shows through the shallow skim. | A white or snowy sheet; ripples or rain rings on ice |
| fw_pond_noon | the same, 12:00 | Thaw (about 0.66): open dark water round the shore, skim left only in the middle, in lobes, greyer | Ice at the bank with open water in the middle (the wrong order) |
| fw_pond_late | the same, 15:00 | Open water, no ice | Any ice |

**B. Spring #8002, day 343, ON.** The mouth is at 56520, 72360 (floor 533.2) and the passage runs west, so the brook leaves eastward. At 09:00 the air is -2.3 °C and a 3 m pond up here would hold 0.28 (5.6 cm). The spring's open length is 840 x ln(8.8 / 2.3) ≈ 1,130 m.
```
mkday 343; PERSIST_STORE=$DAYS/d343 art/playthrough/rig.sh --name fw_spring_mouth --client-arg --frozen-water \
  --at 56545,72360 --agl 1.7 --yaw 90 --pitch -5 --hour 9 --weather live --walk -1 --wait 60 --settle 20 \
  --more-shots "fw_spring_down:56525,1.7,72360,-90,-8,9,live,-1"
```

| Picture | Camera | Must show | Never |
|---|---|---|---|
| fw_spring_mouth | 56545, 1.7 m, 72360, yaw 90 (west, at the mouth), pitch -5, 09:00 | The brook out of the mouth open, dark and moving; frost on the ground if the frost look is on main | Ice on the brook or the pool within about 1 km of the spring |
| fw_spring_down | 56525, 1.7 m, 72360, yaw -90 (east, downstream), pitch -8, 09:00 | The brook open as far as it shows. Any still water past about 1.1 km may carry grey film. | A frozen reach right below the mouth |

If no water shows in either picture, send me the F3 page and a top view (`--pitch -60 --agl 40`) and I place the camera on the brook.

**C. Forced looks on the pond, ON.** Any day at 12:00, clear. Three starts, one picture each, because the force holds for a whole start:
```
art/playthrough/rig.sh --name fw_force_sheet --client-arg --frozen-water --client-arg --frozen-force=0.8,0,0 \
  --at 53316,68495 --agl 2 --yaw 0 --pitch -15 --hour 12 --weather clear --walk -1 --wait 60 --settle 20
art/playthrough/rig.sh --name fw_force_snow_hole --client-arg --frozen-water --client-arg --frozen-force=0.8,0,1 --client-arg --frozen-hole=53316,68484 \
  --at 53316,68495 --agl 2 --yaw 0 --pitch -30 --hour 12 --weather clear --walk -1 --wait 60 --settle 20
art/playthrough/rig.sh --name fw_force_thaw --client-arg --frozen-water --client-arg --frozen-force=0.6,0.5,0 \
  --at 53316,68495 --agl 2 --yaw 0 --pitch -15 --hour 12 --weather clear --walk -1 --wait 60 --settle 20
```

| Picture | Must show | Never |
|---|---|---|
| fw_force_sheet | A grey-white solid sheet, near opaque, with darker grey cracks and lobes at its edge; it meets the bank without a line | Blue glassy water; a hard straight edge where two sheets meet |
| fw_force_snow_hole | Patchy white snow on the sheet, with bare grey drifts showing between. A round dark hole about 0.6 m across, 11 m ahead, with a white chip rim. | Snow over open water; a hole with no rim; a square hole |
| fw_force_thaw | A dark open moat round the shore. The sheet greyer and wet, with gloss. | Open water in the middle with ice at the shore |

**D. OFF, the same as fw_pond_dawn without `--frozen-water`.** It must show open water, today's look. Any ice means the switch leaked.

## 8. Sources

1. USACE EP 1110-2-11, *Ice Engineering* (sheet ice forms in slow reaches where the flow is under 0.5 m/s): https://usaceengineeringpamplets2.tpub.com/EP-1110-2-11/EP-1110-2-110013.htm
2. NWS Nashville, *Weather 101: River Ice* (border ice forms first in the shallower, slower water along the sides and grows across): https://www.weather.gov/media/ohx/PDF/Weather101RiverIce.pdf
3. White Lake Preservation, *The evolution of lake ice* (black ice on calm water, white snow ice from top water, candle ice in spring, the last ice can go overnight): https://www.wlpp.ca/linked/environment_bulletin_-_the_evolution_of_lake_ice.pdf
4. Minnesota DNR, *Ice formations and conditions* (clear ice looks blue or black, white ice is weaker, white cracks are normal, ice near shore melts fastest in late season, flowing water stays thin): https://dnr.state.mn.us/safety/ice/ice-formations-conditions.html

The speed bands either side of 0.5 m/s, the 0.3 m hole, the snow-holding 5 cm and the colours are judged, not sourced.

## 9. Open points

- **Steve, brooks below springs (#720).** `drink_rules.frozen` calls a brook "frozen" past `x0` on any night below 0 °C, whatever the ice thickness. On the starter island that asks for a hole where the look shows open water, because the ice there is under 10 cm and running water mostly stays open. Suggestion: past `x0`, a brook is frozen only when `_on_ice` is also true at that spot.
- **Steve, holes to the client.** The hole list in section 5.
- **Steve, the moat.** Should the shore moat in a thaw refuse a walk? Today the collider covers the whole pond while it bears.
- **Dave.** A colder starter winter is not this design's call. If Dave wants skating ponds on the starter island, that is the climate's `spell_amplitude_c` or the mean.
