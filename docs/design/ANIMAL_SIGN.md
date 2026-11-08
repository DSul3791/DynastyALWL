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

## How long it lasts (Jamie's soak numbers, game days; a game day is one real hour)
- Wet clay and turf: 3 days in summer, 10 in winter, 5 in spring and autumn.
- Snow: until it melts (lying snow below 0.2) or new snow falls; 10 days at most.
- Sand: until rain (over 0.5) or a strong wind (0.6); 3 days at most.
- Browse 7 days, droppings 5, a bed 1.
A fresh print is sharp and fades to a fifth of its darkness by the end of its life.

## Stride by species and speed
- One print is laid per footfall event (`footfall(kind, at, ground, speed)`, the same signal Kathleen's #647 sounds use), but only
  when the animal has gone a stride since the last: the row's `stride_m` x (1 + 1.2 x speed / run speed). A deer at a walk lays a
  print every metre or so, at a full run every 2 m.
- **Walking:** single prints alternating left and right, a body's width apart.
- **Running:** prints in pairs, front and hind foot side by side, at the longer stride, so a run reads differently from a walk.
- Shape by the species' sign group (animal_sign.json): two cloven ovals for hoofed, pad and four toes for pawed, the same with
  claw points for clawed, three thin toes for birds. Size by the animal's length (young smaller). All shapes are generated in code.

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
- **Walking or running:** single alternating prints against pairs at a longer stride.
- **Where it rested and fed:** a bed, browse and droppings at one spot.
The hint text when the player looks at sign is the existing animal_sign.json `signs` list (a later UI step).

## Check
Run sheet m38 (deer and wolf walking on mud: alternating prints), m39 (running on sand: pairs farther apart), m40 (on stone: none).
