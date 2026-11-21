# Frozen-water rendering, integration and checks

[Environmental design §8.6](art_weather_light.md#86-frozen-water-skim-sheet-snow-holes-and-thaw) owns the visible skim/sheet/snow/thaw/hole design. This reference keeps calculations and checks; [still-water ice](still_water_ice.md)/`src/shared/ice.gd` own underlying cover, [ice walk feel](ice_walk_feel.md) owns footing/sounds. Default-on under the 8 Nov enable decision; obsolete `--frozen-water`/OFF instructions are removed. `--frozen-force` and `--frozen-hole` remain picture overrides, not feature-enable flags. Static review is not a new playtest.

## 1. Integration baseline
The 8 Nov problem report described invisible ice on `LIQUID_CHUNKS` sheets while colliders/sounds already followed `Ice.cover`, no river-edge/spring distinction and unsent holes. Rendering is now wired; that report is provenance, not a list to reimplement. Preserve parity across live window, chunk sheets and Sullivan fine sheets, and avoid a one-second liquid flash on newly created sheets.

## 2. Seed/climate fixtures
Original seed 574716103, 3 m pond, first three years:

| Place | Coldest morning in the first three years | Ice (`open`, 3 m pond) | Thickness |
|---|---|---|---|
| Pond near spawn (about 50 m) | day 342, 07:00, air -2.3 °C | 0.14 | 2.8 cm |
| Spring #8002 level (533 m) | day 343, 09:00, air -2.3 °C after a -5 °C night | 0.28 | 5.6 cm |

Those air figures came from the old 9 °C climate calculation. Snow/ice-only bias retained its tuned cover figures, while **plain air and spring temperature changed**; [sky §7](one_sky_design.md#7-temperature-by-row-and-the-snow-bias) records current 14.16/−5.16 °C defaults and world-curve limitation. The old table's "never bears" conclusion is only that fixture (<0.5/10 cm), not every seed/altitude/current climate. Reproduce tests before treating these as current observed weather. High-corrie/arctic sheet looks still need forced captures even if lowland fixture gives skim.

## 3. Where ice forms
- `open=Ice.cover` at 3 m (`ICE_POND_DEPTH_M`), `shore` at 1 m (shallowest lag distinguished by ice rule, 2 days). Below 0.3 m water depth use max(open, shore), above 2 m use open, blend between; noise lobes break the edge.
- Current speed(m/s): below 0.3 pond-like; 0.3–0.5 thins sheet; above 0.5 no full sheet.0.5–0.9 permits border ice: water shallower 0.15 m plus up to 1.5 m band as cover grows. At 0.9+ or fall/turbulent faces, open water. The 0.5 m/s source and judged surrounding bands are distinguished in §8.
- Spring water uses plain yearly mean at height (`spring_c`), not snow bias. Current fallback at#8002 is about 10.7 °C, superseding old 5.5 °C; older mean+1 °C alternative is history. Open length `x0=λ ln((Tw-Ta)/(0-Ta))`, λ840 m. Worked fixture Tw 6.5 °C/Ta−4 °C gives 810 m. Research comparison:440 m×sqrt(L/s) at−5 °C calm; multipliers 1.8/0.6/0.4 at−2/−10/−15 °C (log-rule ratios 1.78/0.59/0.42).
- Breeze halves reach over wind 0.3→0.5; clamp effective air at most−0.5 °C to avoid divergent noon radius (old 5.5 °C example~2.2 km). Nonpositive spring temperature gives no open reach. Intended transition: half-thickness over 30 m beyond open reach; research thin ice within 10–30 m of inflow.
- Approximation: nearest 8 cave pool centres (`cave_streams._pools`), circular reach with fade 0.8 x 0→x 0, not stream-distance rows. Winding brook/path vs radial mismatch remains; future `below_spring_m` bake can replace it. Cave water is unfrozen; steam over frosty spring mouth belongs to ice-walk design. Do not apply old cold-spring lengths after changing plain climate.

## 4. How it looks and thaws
See main §8.6 for the single visual band/colour schedule. Technical thaw=`clamp(1-now_cover/peak_cover,0,1)`, peak from last 30 days; only when peak>=0.125 (2.5 cm). Shore moat spans depth<1.6×thaw m; wet grey darkening reaches 0.7×thaw, then lobed breakup. Ice simulation can retain thicker shallow ice longer; the visual moat is an added look/footing rule, not a silent change to shared 3 m cover. Check collision/drink parity (section 9).

## 5. The ice hole
Render data: up to 8 nearest `Vector4(x,z,radius,age0..1)`; server records `{pos,until}` use game seconds, converted by `hole_game_h`18. Default radius 0.3 m; optional `radius`/`life_h` support broken skim, `forever` supports picture fixtures. Expired holes omitted. Server transmission exists; the scoped client-receiver gap is recorded in §9. Pure shader parsing and forced pictures do not establish live hole display. Only solid cover>=0.5 exposes a hole. Visual rim/refreeze schedule is in main §8.6.

## 6. Code and checks
| Location | Responsibility |
|---|---|
| `src/shared/ice.gd` | `season(game_s,zone,altitude,depth,seed)->{cover,peak}` shares hourly loop with `cover`; unchanged server-cover contract. |
| `src/client/frozen_water.gd` | Pure `look()->Vector4(open,shore,thaw,snow)`; `spring_c`, `spring_open_m`, `springs_near`, `holes_near`, `force_of`. Nearest-first arrays max 8. Current search bounds holes 3000 m/springs 5500 m are implementation values. |
| `src/water2/liquid_surface.gd` | `frozen_on`, `ice_look`, `ice_springs[8]`, `ice_holes[8]`/counts; ice after water colour; dims underwater Snell window; static `set_ice_all` seeds newly created sheets. Shader initialization 0 is not a gameplay off-toggle. |
| `scenes/terrain_client/terrain_client.gd::_update_weather` | Periodic look/spring/hole updates, forced-picture values and ice-moat routing; original cadence 5 s/two 720-step loops is a recorded budget, not measured timing. |
| `src/client/fall_mist.gd` | Shares liquid-sheet group; ice propagates through static storage, not `call_group`. |

`src/worldgen/tools/test_frozen_water.gd` retains season==cover and peak>=cover; fixture days 342/343/344; noon/late thaw; spring 810 m at−4 °C; force/hole parse and ages; shader bands. Old test text claiming default-off is superseded. Additional parity checks belong to gameplay tests. Run only on permitted runner; no Godot test result is claimed here.

## 7. Pictures
Use approved day/persistence procedure on an authorized PC; record F3/seed/climate/day and actual air/cover. Old repeated commands and OFF comparison are recoverable from [8 Nov source](https://github.com/DSul3791/DynastyALWL/blob/090129ec43942e90a28eb7c4fd0d202df3ee68c3/docs/design/frozen_water_look.md), not current instructions. Retain these captures:

| Group/names | Camera and setup | Check |
|---|---|---|
| Pond: `fw_pond_dawn`, `_noon`, `_late` | Day 342; 53316, 68495; AGL2 m, yaw 0, pitch−15; 07:00/12:00/15:00, live weather. Pond 53316, 68476/~50 m altitude. | Historical cover 0.14 dawn dark glossy skim/frost rim, noon~0.66 thaw with open shore/lobed centre, late open. Treat numbers as fixtures; no snowy sheet or ice ripples. |
| Spring: `fw_spring_mouth`, `_down` | Day 34309:00; mouth 56520, 72360/floor 533.2 m, west passage/east outlet. Cameras 56545, 72360, AGL1.7, yaw 90, pitch−5; 56525, 72360, AGL1.7, yaw−90, pitch−8. | Warm moving mouth/downstream, freezing only beyond computed current-climate reach. Old 5.5 °C/−2.3 °C1030 m-calm/half-breeze example is historical; do not demand it from current plain climate. |
| `fw_force_sheet` | Pond camera/noon/clear; `--frozen-force=0.8,0,0` | Opaque grey-white/dark cracks, lobed edge, no chunk seam or blue glassy liquid. |
| `fw_force_snow_hole` | Same, pitch−30; `--frozen-force=0.8,0,1 --frozen-hole=53316,68484` | Patchy snow/bare drifts; 0.6 m dark round hole 11 m ahead, white rim; no square/unrimmed hole or snow over open water. |
| `fw_force_thaw` | Same, pitch−15; `--frozen-force=0.6,0.5,0` | Open shore moat; grey wet glossy remaining sheet, never open centre with frozen shore. |

First-person/walk−1, original wait 60 s/settle 20 s; forced values held per start, so use separate starts per force case. If brook absent capture F3 and top view pitch−60/AGL40 m before choosing another camera. Do not use removed `--frozen-water` or pretend a no-flag run is an OFF comparison.

## 8. Sources

1. USACE EP 1110-2-11, *Ice Engineering* (sheet ice forms in slow reaches where the flow is under 0.5 m/s): https://usaceengineeringpamplets2.tpub.com/EP-1110-2-11/EP-1110-2-110013.htm
2. NWS Nashville, *Weather 101: River Ice* (border ice forms first in the shallower, slower water along the sides and grows across): https://www.weather.gov/media/ohx/PDF/Weather101RiverIce.pdf
3. White Lake Preservation, *The evolution of lake ice* (black ice on calm water, white snow ice from top water, candle ice in spring, the last ice can go overnight): https://www.wlpp.ca/linked/environment_bulletin_-_the_evolution_of_lake_ice.pdf
4. Minnesota DNR, *Ice formations and conditions* (clear ice looks blue or black, white ice is weaker, white cracks are normal, ice near shore melts fastest in late season, flowing water stays thin): https://dnr.state.mn.us/safety/ice/ice-formations-conditions.html

The speed bands either side of 0.5 m/s, the 0.3 m hole, the snow-holding 5 cm and the colours are judged, not sourced.

## 9. Open points and later dispositions
- **Frozen brook:** the old missing-`_on_ice` proposal is superseded by existing code: `drink_rules.gd` requires `row.iced` beyond the spring open reach, and `server_items.gd` fills it from `_on_ice` when absent. Keep visual/current/radial parity checks; [drinking-water design](drinking_water_design.md) owns behavior. Static presence is not a new gameplay PASS.
- **Holes — existing client integration gap:** `terrain_server.gd` sends `items.ice_holes_near` through `net.ice_holes.rpc_id`; `terrain_net.gd` emits `ice_holes_received`. Scoped static review of `scenes/terrain_client` found the empty `ice_holes` field and rendering consumption, but no receiver/assignment connecting that signal. A water/client implementation owner must verify and complete this connection, then test live cut-hole display; do not repeat the old claim that the server never sends holes or mark forced pictures as proof of live wiring.
- **Thaw moat:** later coordinator decision in [ice walk feel](ice_walk_feel.md) says refuse walking in moat, superseding the old unanswered design question. Static terrain client calls `IceFeel.moat_cells`/`flora.set_ice_moat`; player/collider parity still needs its actual check. Do not reintroduce a missing-implementation task from old prose.
- **Climate:** making colder starter winters/skating ponds is a separate design decision (mean/cold-spell amplitude), not authorized by visual consolidation.
