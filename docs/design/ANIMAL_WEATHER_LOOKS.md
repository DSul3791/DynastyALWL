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

## Requests to Steve (no new wire fields are used yet)
1. **Hunch in shelter:** send state 20 while a deer or stock animal stands in its rain or cold cover (under crowns, a conifer stand or
   a cave), not only for the rain hunch spells, so the shelter reads as sheltering. Nothing else changes on the wire.
2. **Lying snow:** when Sonny's baked snow window (A4) lands, the server's "falling snow stands in for lying snow" can switch; the
   client already reads `ground_snow` from the weather sounds for prints and could take a server value the same way.
3. **Cold air by height:** the client uses the shared weather's `temp_c` with no height or night swing, the same limit Steve notes for
   the server; a shared `air_c(position)` would let both use one number.

## Check
Run sheet m41 (deer and horse in a gale: rumps turned to the wind), m42 (deer herd at -12 C: closer, heads low, steam at the
muzzles), m43 (dog and wolf as the rain stops: a shiver and drops), m44 (deer lying in falling snow: whiter coat).
