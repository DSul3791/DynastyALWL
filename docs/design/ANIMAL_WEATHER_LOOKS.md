# Animals in weather: the client looks (MikeW, 8 Nov 2026)

The client side of Steve's animals-in-weather work (`docs/design/animals_in_weather_design.md`, #646; step 2 #667, step 3 #671).
The server already moves the animals: deer and stock to tree cover in rain, deer to conifers in the cold, stock to shade in heat,
stock facing downwind and drifting 0.05 m/s in a gale, wolves slower in snowfall, caves as full cover; and it sends state 20 (hunch)
for a grazer standing still in rain. All of that reaches the client as positions, headings and states and is drawn already. This
note adds the looks that the server does not send, behind `weather_looks` (off), from the client's own weather state
(`terrain_client.weather`: `temp_c`, `rain`, `snow`, `wind`, `wind_dir`; the same on every client, no wire traffic).

## The looks
| Look | Who | When | How (animal_view.gd) |
|---|---|---|---|
| Shake-off | dog, wolf, fox, bears | the rain stops (0.4 or more, then under 0.1) | `_weather_look` 1: a 1 s shiver of the whole body (the Rig's roll, dying away), each animal a moment after the last, a spray of drops; sets `shed` for the wet look |
| Tail to the wind | deer, elk, horse, donkey, cattle, buffalo, goats, sheep, chamois, wildebeest | standing in a gale (wind 0.6, Steve's `gale_from`) | 2: the Rig turns up to 60 degrees toward downwind, eased, on top of the herd facing; for stock the server's heading already points downwind, deer turn on the client only |
| Cold huddle | every herd row | air below -5 C (Steve's `cold_c`) | 3: herd spacing on screen 2 m to 1.2 m (`_herd_space`), and the hunch pose (head low) while standing |
| Steam breath | every model animal | air below 5 C, within 30 m | 4: `_steam_breath`, a small white puff at the muzzle on each breath at the row's `breath.per_min` (15 if none), quicker after a run, thicker the colder it is |
| Snow on the back | any animal lying (19, or asleep) | snow falling (0.2 or more) | 5: the coat whitens over 2 minutes; getting up it shakes (the 1 s shiver) and a snow puff falls off |
| Wet coat | swimmers and everything out in rain | rain | the wet look (claude/mikew-wet-look, WET_LINE_SHADER.md) darkens coats by its `wet_dark`; the shake-off here sheds part of it once both branches are merged |
| Shelter pose | deer and stock in cover | server state 20 | the hunch (POSED_STATES.md, state 20): the standing idle under a head-low pose, ears back, tail still |

## Requests to Steve, and his answers (8 Nov 2026)
1. **Hunch in shelter:** accepted. The server will send state 20 while an animal is at its dry home inside the cover radius during
   rain, a gale or cold, after his fire steps. The client already draws 20 as the hunch; nothing to change here.
2. **Lying snow:** waits for Sonny's baked snow window (A4). Until then the server's falling snow stands in, and the client reads
   `ground_snow` from the weather sounds.
3. **One temperature by height:** accepted on a condition: it is `Weather.air_c` from #620. Once #620 merges the server calls it, and
   the client's `weather_now` should call the same function (`Weather.air_c(game_s, group, altitude)` at the animal) instead of the
   flat `temp_c`. No second shared function before then. **Done (8 Nov 2026, #620 merged):** `air_at` in terrain_client calls
   `Weather.air_c(game_clock.seconds, weather_group, y)` at the animal's height; the steam breath, the cold huddle and the herd spacing
   all read it through `_air`. The client has no lapse of its own; the motion tool, with no world, falls back to its `temp_c`.

## Check
Run sheet m41 (deer and horse in a gale: rumps turned to the wind), m42 (deer herd at -12 C: closer, heads low, steam at the
muzzles), m43 (dog and wolf as the rain stops: a shiver and drops), m44 (deer lying in falling snow: whiter coat).
