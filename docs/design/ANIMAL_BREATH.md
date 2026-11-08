# Breath and steam (MikeW, 8 Nov 2026)

Behind `breath_looks` (off). From Jamie's springs-in-winter page (#739: spring mouths steam on frosty mornings, and animals gather at
the open water below a spring) and the weather looks' steam breath. It reads the air at the animal (`_air`: `Weather.air_c` by height
and hour through terrain_client's `air_at`, the cave's air under rock; the client weather look has no air of its own, so this is the one
temperature) and the wind (`wind_looks`' direction for the drift).

## Breath puffs, every rig family
- Below 5 C every model animal breathes a visible puff at its muzzle (the muzzle is found from the body's length, so every family
  gets it, with or without a breath bone). With `weather_looks` off, `breath_looks` runs it on its own.
- **The rate by what it is doing:** the row's `breath.per_min` (15 if none); slower (0.7) at rest (graze 0, recover 12, lie 19, hunch
  20, drink 21, asleep); 2.5 times moving fast; **panting** 3 times for 20 s after it fled (2), charged (11) or attacked (7).
- Thicker the colder it is; it drifts downwind with `wind_looks`; it fades into the mist with `fog_looks`; underground at the cave's
  5.5 C there is none.

## Steam off a wet or hot animal
- Below 8 C, soft wisps rise off the back, every 0.6 to 1.2 s for a minute: after it swam (water deeper than 0.3 m, water_life's probe),
  while it stands hunched in rain (20, rain over 0.3), and after a chase or a kill (states 2, 11, 7). Thin (alpha 0.06 to 0.2, more
  the colder), slow, blown by the wind.

## At the open brook below a spring (Jamie #739)
Nothing of the client's own: Steve's server sends the animals there (deer and stock walk to fresh water at dawn and dusk, #734, and
stand facing it in state 21 DRINK; water flocks stand at the open-water edge, #737), and the springs are always open water (Sonny,
6.5 C at cave 8002). The client draws what arrives: the drinkers' sips and glances and the churned bank (drink_looks), their breath
puffs in the frost (here), and the spring's own steam is Kathleen's water look.

## Check
Run sheet m60 (a deer herd at -12 C: slow puffs at rest; a deer that ran (state 2) panting; a deer out of 0.6 m of water steaming
off its back) and DINO_SHOTS.md.
