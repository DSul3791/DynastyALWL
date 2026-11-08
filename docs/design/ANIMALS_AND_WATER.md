# Land animals and water: drinking, wading, swimming, shaking off

Client look only, behind the flag `water_life` (default off). True swimmers with their own swim clip (alligator, beaver, moose,
goose) keep the swim block they already have and are skipped here. Water height comes from `water_level` (flora.water_level_at,
already wired for the swimmers).

## Drinking at the bank

- Grazing (state 0), standing in less than 10 percent of its height of water, with water just ahead of its muzzle (0.55 of its
  length forward): the animal drinks. The graze clip already puts the head down; a ring spreads on the water at the muzzle every
  1.6 s.
- The server has no drink state. A later server step could send the animals to water at dawn and dusk (Steve); the client look
  needs nothing more.

## Wading depth by species

- The server stands the animal on the ground under the water, so its legs are in the water by their real depth with no change.
  The footfall splashes (FOOTFALL.md) already play in water.
- Swim depth: `swim_depth_x` (default 0.7) of the shoulder height (`height_m`, else 0.55 of `length_m`, times the young scale).
  A horse (2.4 m long) swims from about 0.9 m of water, a fawn from about 0.35 m.

## Swimming (deer, dog, bears, elk, wolf, horse, buffalo, elephant, raccoon, tiger)

- Rows with `water_swim: true`. Deeper than swim depth, the body floats with 15 percent of its height above the surface (back and
  head showing), eased; the walk clip plays at 1.8 times as a paddle, even while the animal is still (treading water); a ring
  spreads behind it every 0.6 s.
- The server's habitat rule keeps most of these off deep water today, so this shows only where a path or a flight crosses water.
  Letting a deer swim across a river on purpose is a server step for Steve.

## Shake-off

- Out on the bank (under 15 percent of its height of water) after swimming: a fast roll of the body that dies away over 0.9 s
  and a burst of drops.
- Wet look tie-in: the shake sets `shed`; the wet look (claude/mikew-wet-look) drops its `wet_shed` share of the wet amount on it
  once both are merged.

## Check on the PC

Run sheet m24 and m25: deer and dog in 1.2 m of water walking (`--wlife --water=1.2 --speed=1`), body low with the legs moving
quickly; deer and horse grazing at a bank (`--bank`), rings at the muzzle.
