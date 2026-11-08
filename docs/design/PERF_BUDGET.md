# Life layer cost budget (MikeW, 8 Nov 2026)

A read of every hook in `src/client/animal_view.gd` as it would run with every flag on at once and 60 model animals drawn (the
`MAX_DRAWN` view near a player), then the fixes. Estimates are by count of operations per frame, not timed: they are checked on
the PC with the in-game frame probe at the sitting. "n" is the number of drawn model animals (60).

## The kill switch
`life_layer_all_off` (or `--life-layer-off` on the command line): every life-layer flag forced off at once, and the always-on looks
(tail, ears, breathing, head look, hop arc, herd look, eye shine) skipped, so a model animal costs what it costs on main. For Dave's
PC gate: run the session once with it and once without to see the layer's whole cost in the frame probe.

## Per flag, per frame (before, then after the fixes)
| Flag or look | What runs | Every frame or less | Before | After |
|---|---|---|---|---|
| tail, ears, breathing, look (always on) | one bone layer write each; tail and look read the clock and conditions | every frame per animal | n x 4 callable calls, n Dictionary copies (conditions) | 1 conditions read a frame, cached |
| herd look (always on) | facing and spacing against every mate of its kind | every frame per herd animal | n x n distance tests (3,600 at n = 60), plus 2 weather reads per pair with `weather_looks` (7,200 calls) | n x n / 12 (the pair loop 5 times a second, staggered by id), eased every frame; the spacing is read once a frame |
| eye shine #596 and v2 | torch, night light, angle tests | every frame per animal with eyes | n torch-array and n night-light Dictionary allocations | 1 of each a frame |
| `footfall_fx`, splashes | particles per landing | on each footfall | short one-shot nodes | unchanged (bounded by steps) |
| `prints_fx` | fade of up to 200 decals | every frame | 200 modulate writes a frame | 4 times a second (50 a frame on average) |
| `foot_ik` | 5 ground rays per animal, skeleton look-up | 4 times a second within 25 m | `find_children` (an Array allocation) per probe | skeleton cached on the animal |
| `slope_tilt` | 2 ground samples | per animal per frame | unchanged | unchanged (small) |
| `stalk_fx` | prey-looking scan | per stalker per frame | n per stalker (few stalkers) | unchanged |
| `season_coats`, `coat_dust`, `coat_ruffle` | coat colour and shader values | once a second per animal | small | unchanged |
| `young_gait` | wobble, age | every frame per young one | a conditions read per young one per frame | age cached once a second |
| `young_follow` | mother search | every 2 s per young one | n per search | unchanged |
| `water_life` | water depth | 4 times a second per animal | small | unchanged |
| `idle_variety` | timers | every frame per standing animal | small, a clip play per idle | unchanged |
| `flight_bank` | bank from turn rate | every frame per bird in the air | small | unchanged |
| `look_at_foe` | one Vector3 field | on rows | none | none |
| `swarm_fx` | each bat's offset | every frame per colony bat | up to 40 per colony | unchanged (colonies are rare) |
| `sea_life` | blow timer | per whale or dolphin | small | unchanged |
| `voice_fx` | voices.json lookup | on state change only | none per frame | none |
| `animal_sign` | track test per footfall, rest timers, 400-decal age check | per footfall; every 2 s for the pool | a soil read per footfall; the pool every 2 s | unchanged |
| `weather_looks` | shake, gale turn, steam, snow | every frame per animal | n weather Dictionary reads | 1 a frame, cached |
| `hunt_feedback` | reaction, limp | only animals hit | none otherwise | unchanged |

## The worst three, and the fixes
1. **The client's callables read once per animal per look.** `conditions_now` (which builds a new Dictionary in terrain_client every
   call), `weather_now`, `night_light` (a new Dictionary) and `torch_light` (a new Array) were called from the tail swish, the
   young age, the eye shine, the weather looks, the sign ground and the coat season, several times per animal per frame: about 300
   calls and 150 allocations a frame at n = 60. **Fix:** `_refresh_frame` reads each once a frame (`_cond`, `_wx_state`, `_night`,
   `_torch`, `_wind`), every look reads the cache. After: 5 calls a frame.
2. **The herd look's pair loop every frame.** Each grazing herd animal tested every other drawn body every frame (n x n), and with
   `weather_looks` on it asked the weather twice per pair for the huddle spacing. **Fix:** the loop runs 5 times a second per animal,
   staggered by id so the work spreads across frames; the facing and push it finds are eased every frame (the eye cannot tell at
   0.2 s, the motion is eased over seconds anyway); the spacing is one cached number a frame.
3. **Print fades every frame.** Up to 200 decals had their alpha set every frame for a fade that lasts 10 to 20 minutes. **Fix:** 4
   times a second. Also: `foot_ik` no longer searches the model for its skeleton on every probe (cached), and the young age is read
   once a second, not every frame.

## Still to watch on the PC
- The herd look is still n x n at 5 Hz: with 60 deer in view that is 720 distance tests a frame; a grid by kind would cut it if the
  frame probe shows it.
- Each particle effect (puffs, splashes, steam, spouts, rings) is a short-lived node; with every flag on, a running herd in rain
  makes a few a second. They are capped by the step and breath rates, and freed by their own timers.
- The 400-decal sign pool and the 200 prints are Decals: their draw cost is the GPU's, checked in the frame probe with the decal
  count on screen.
