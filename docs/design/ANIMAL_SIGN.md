# Animal sign: tracks, droppings, browse and beds (MikeW, 8 Nov 2026)

What an animal leaves behind for a tracker, drawn by the client from what it already hears from the server. Behind the flag
`animal_sign` (off). It takes over from the snow-and-mud prints of FOOTFALL.md step 5 (`prints_fx`) when on. Hints and tracking
levels are already in `data/animals/animal_sign.json` (group 40, species 65, age and injury 90); this note is the ground side.

## Where a track is left (only soft ground)
The ground under the foot is the sound stage's soil map (`soil_at`: the footstep surface) plus the weather (`conditions_now`):
| Ground | Track? |
|---|---|
| mud | yes |
| sand | yes |
| snow (lying snow above 0.3) | yes, on anything but bare stone |
| dirt, path | yes when wet (ground_wet 0.3 or more): "clay" |
| grass, tall grass, bushes | yes when wet: "turf" |
| stone, gravel, leaf litter, dry dirt or turf | none |
| under water | none |

## How long it lasts (game days; a game day is one real hour)
From Jamie's tracks page (`docs/knowledge/animal-tracks-sign.md`, #696), replacing the first soak-time values:
- **Mud and wet clay:** until the next real rain (rain 0.4 or more for a game hour), ten days at most. A print in drying mud outlasts
  the wet ground; rain is what erases it.
- **Turf:** half a day for bent grass; two and a half days for the deep hoof holes of a heavy animal (moose, horse, donkey, cow,
  buffalo, elk, bears, camel, elephant, rhino, mammoth).
- **Snow:** until it melts (lying snow below 0.2), new snow falls, or the wind stays above 0.35 for two game hours (drifting fills
  them); ten days at most.
- **Sand:** until rain over 0.5 or a wind of 0.6, three days at most.
- Browse 7 days, droppings 5, a bed 1 (Jamie: right as they are).
A fresh print is sharp and fades to a fifth of its darkness by the end of its life.

## Spacing by gait (Jamie's tracks page)
- `models.json` `stride_m` sits near the full stride (two steps), so one print per `stride_m` showed half the prints at a walk. Each
  species now has `track` {`walk_m`, `run_m`} from her table: deer 0.7 and 3.5 m, moose 1.3 and 4.5, boar 0.5 and 2, bear 0.6 and 3,
  black bear 0.5 and 2.5, wolf 0.7 and 3, fox 0.3 and 0.8, lynx 0.5 and 2, rabbit 0.3 and 1, horse 0.8 and 4, cow 0.7 and 2, goat 0.4
  and 1.5, dog 0.5 and 2, crow 0.1, pheasant 0.12. Without a row: half the `stride_m`, and five times that for a run.
- **Walk:** one print per step, alternating left and right a body's width apart (deer, wolves, foxes, cats and horses put the hind
  foot in the front print, so one print per step).
- **Trot** (above 1.4 times the walk speed): single prints 1.45 steps apart; a fox, wolf or dog almost on one line.
- **Run** (above 2.4 times the walk speed): a group of four prints in a slanting row, then the long gap; a **rabbit** leaves the Y
  (two small front prints one behind the other, the two big hind prints side by side ahead).
- Shape by the species' sign group (animal_sign.json); size by the animal's length (young smaller). All shapes are generated in code.

## Rest and feeding sign
- **Browse:** a grazer that has fed 40 s in one spot leaves nibbled flecks ahead of it.
- **Droppings:** one feeding spot in four also gets a pellet cluster behind the animal.
- **Bed:** an animal lying (state 19, or asleep) 30 s leaves a flattened oval of grass its body's size.
- Each spot is marked once (a 3 m spot); nothing beyond 60 m of the camera.

## The pool
One pool of Decals, at most 400; the oldest is dropped first when a new one comes; new sign only within 60 m of the camera, so the
nearest is kept. Checked every 2 s for age and weather.

## What a tracker can read
- **Species:** the shape (group) and size; species-level reading needs tracking 65 (animal_sign.json).
- **Direction:** prints point the way the animal faced.
- **Age:** how faint a print is against its ground's life; with snow and sand, whether it predates the last snowfall or rain.
- **Walking, trotting or running:** single alternating prints a step apart, a straighter line a little farther apart, or groups of four (a rabbit's Y) with long gaps.
- **Where it rested and fed:** a bed, browse and droppings at one spot.
The hint text when the player looks at sign is the existing animal_sign.json `signs` list (a later UI step).

## Check
Run sheet m38 (deer and wolf walking on mud: alternating prints a step apart), m39 (deer, wolf and rabbit running on sand: groups of four, the rabbit's Y, long gaps), m40 (on stone: none).
