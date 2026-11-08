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

## State 20 in cover (flag `cover_still`, Steve #646 section 11, code #701)
The server now sends 20 for a deer or stock animal standing in its cover (within 8 m of the cover home it moved to, or under tree
crowns) for as long as the rain, gale or cold lasts. The client draws 20 as the hunch already; with `cover_still` it is also still:
- the idle clip at half speed, breathing at 0.8 of its rate, no glances at the player;
- silent: voices.json names no call for 20;
- eyes shine only in a light (the eye shine rules are unchanged);
- the wet look held: `wet_hold` is set while it stands in cover, so the wet look (claude/mikew-wet-look) keeps its wet amount
  instead of drying; cleared as soon as it leaves 20.
Check: run sheet m48 (deer and horse in state 20 with `--cover`: heads low, barely moving between frames).

## The cave climate and the body in weather (flag `cave_air`, pr20; Jamie #709, Steve #715 and #712)
- **The air underground** is the cave's, not the sky's: deep in, the year mean at the height (Steve's `cave_mean_c`, 5.5 C at cave
  8002), with no season and no day or night swing. `_air` (every weather look's temperature) takes it when `cave_air` is on and the
  animal is under rock: terrain_client's `cave_c_at` casts one ray up (solid within 30 m), and gives the zone's sea-level year mean
  less the lapse at that height (the same climate numbers `Weather.air_c` uses). A 2 m cell cache keeps it to one ray per cell every
  5 s.
- **The entrance blend** (Steve's `lerp(outside, deep, smoothstep(near_m, reach_m, depth_m))`, bands by season and which way the cave
  runs) needs the distance to the nearest mouth, which is server tile data (`cave_mouths`, #715). Until it reaches the client an animal
  under rock counts as deep in. When #715 merges, `cave_c_at` calls his shared `src/shared/cave_climate.gd` instead of the year-mean
  line, so there is one formula, not two; the `warmth.json cave_climate` block's bands and `day_swing_kept` then apply on the client
  as on the server.
- **Steam breath follows the local air:** underground at 5.5 C a deer breathes no steam (the threshold is 5 C), though the sky outside
  is -12; at a winter mouth, once the blend comes, it steams again.
- **Bats and cave animals** take the same air: a bat colony's roost is underground by Steve's design (BAT_RIG.md), so its air is the
  cave's; nothing they draw depends on it yet beyond the steam rule.
- **Wet coats dry by where they are** (`_dry_rate`, every 2 s, `b["dry_per_h"]` for the wet look to read): by a fire
  `warmth.json dry_fire_per_h`, in the open `dry_cover_per_h`; underground none deep in under Steve's cave block (half the cover rate
  only at a winter mouth, which needs the mouth distance), or half the cover rate in the flat cave without the block. The rates are
  Steve's wool model; the wet look branch scales its fade by them once both are in. Fires come through an optional `fire_near`
  callable (unset: no fire), to be wired to the client's fire list with the wet look.
- Reads only `Weather.air_c` (through `air_at`), the shared climate numbers and `warmth.json` (its rates and `cave_climate` block).

Check: run sheet m54 (a deer at -12 C outside but under rock at 5.5 C: no steam, against m42's steaming herd) and DINO_SHOTS.md.

## On ice and in snow (flag `ice_looks`, pr22; paired with Kathleen's frozen water look)
Reads only the existing `water_level`, the weather's lying snow (`ground_snow`) and ice (`ice_cover`, the same number the walkable ice
uses, now passed in the animal conditions) and `Weather.air_c` (through `_air`).
- **On ice:** an animal at the water's surface (within 0.15 m of the level) where still water is frozen (ice_cover over 0.5) steps
  carefully, its clip at three quarters. Deer, elk, boar and stock, who avoid open ice, slip now and then: a sideways lurch of 10
  degrees that rights itself in half a second, every 2 to 6 s. Wolves, foxes, lynx, dogs, bears and birds cross surely.
- **Where they go is the server's** (requests to Steve): deer and boar skirt frozen ponds rather than cross; wolves cross the ice
  (and use it as a road); ground birds and ducks stand on the ice at the edge of open water.
- **Snow on the back while still:** with `weather_looks`, an animal standing still for 30 s in falling snow gathers it too, not only
  one lying down; when the snow stops it melts on the back above 0 C, faster the warmer (the air at the animal, `_air`); moving off
  shakes it away as before.
- **Snow prints deeper and longer-lived:** with `animal_sign`, prints in snow are up to 40 percent bigger in deep lying snow and
  darker; they last until melt, new snow or drifting (as before), and a thaw (air above 2 C for two game hours) softens them away.
- **Sources:** Jamie's animals-on-ice page (#736, `docs/knowledge/animals-on-ice-and-snow.md`): deer on bare ice fall and stay down
  splayed on all fours, about one fall per three running strides, and are fine on snow-covered ice; wolves run on ice as a road; snow
  builds on a standing animal's back over 15 to 30 game minutes; water birds stand at the ice edge by open water; the starter's ice
  carries only birds, hares, foxes and perhaps a wolf or a roe deer. Snow prints from her tracks page (#696).
- **Changed for #736:** no slips on snowy ice (lying snow over 0.3); a still animal starts gathering snow after 5 s and is white in about
  60 real seconds (15 to 30 game minutes); the splayed fall on bare ice while running is the pose library's (pr24, POSE_LIBRARY.md),
  so this PR keeps the slips and the fall comes with the library.
- **Steve's answer (#737):** deer and boar never step on ice; foxes and hares do on the starter's skim; water flocks stand at the
  open-water edge; and the client gets `ice_holes(points, untils)` (protocol 97: up to 8 live fishing holes within 120 m and when each
  closes). With `ice_looks` the client draws each as a dark 0.6 m disc of open water (`on_ice_holes`, connected when the network has the
  signal; Kathleen's frozen water look may take it over). The slips and falls stay for any animal the server puts on ice; the rabbit is
  now sure-footed with the fox.

Check: run sheet m56 (a deer and a wolf walking on frozen water: the deer slips, the wolf does not; a deer standing still in snow
whitening) and DINO_SHOTS.md.

## Check
Run sheet m41 (deer and horse in a gale: rumps turned to the wind), m42 (deer herd at -12 C: closer, heads low, steam at the
muzzles), m43 (dog and wolf as the rain stops: a shiver and drops), m44 (deer lying in falling snow: whiter coat).
