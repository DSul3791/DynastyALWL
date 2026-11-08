# Herd and group layer: one leader, keeping places, drifting, scattering, regrouping

Deer, boar, horses, cattle and ground birds already spawn as herds on the server (`herd` [min, max]) and alarm each other
(`alarm_s`). Today each member wanders round its own home and is only pulled back when it strays past `herd_pull_m`, so a herd
grazes as a loose cloud that never goes anywhere. This layer makes the herd move as one. It is server-side movement (positions are
the server's), behind `animals.json` `groups.enabled` (default **false**). The client herd look (HERD_CLIENT.md: facing,
spacing on screen, looking up together) already sits on top and needs no change.

## Leader and places

- The leader is the herd's first living member on the ground (`_group_leader`): a bird that is flying or perched (#661 `fly`,
  `perched`) is passed over. When it dies the next one leads.
- Each graze step the leader's home moves `groups.drift_m` (2 m) on a slow wander (up to 0.6 rad a step), turned by Steve's
  `_upwind_angle` (#651): with `weather.on`, deer and hunters drift into a light or moderate wind and stop doing so in a gale. Storm
  drift for stock is Steve's weather step 2 (face downwind, 0.05 m/s), not this layer.
- The leader alone keeps any weather cover its home is given (#651 step 2); every other member's home is its place round the
  leader: a spiral at the golden angle, `group_spacing_m` x sqrt(place), turned with the drift. Deer 3 m, elk 4, horse 3.5, cow 3,
  boar 2, pheasant 1.5, guineafowl 1.

## Weather bunching

Read from Steve's `_wx` and only with `weather.on` (#651): spacing x (1 - `rain_bunch` 0.35 x rain-or-snow - `wind_bunch` 0.25 x
wind), never below `min_bunch` 0.5. In heavy rain a deer herd stands about two thirds as far apart.

## Scatter and regroup

- The sentinel's alarm reaches the herd as before (`alarm_s`). With groups on, each member bolts up to `scatter_deg` (25) either
  side of straight away, alternating sides by place, so the herd fans out instead of running in single file. A bird with a flight
  row takes off instead (#661: `_bolt` returns at `take_off` before the scatter).
- Ground birds: Steve's #636 `alarm_group` (crow, pheasant, grouse, guineafowl, songbirds within 15 m) carries the alarm across
  species; with groups on, each ground-bird herd also fans out on it.
- Once safe (`safe_m`), each member's next graze step sends it to its place round the leader: the herd regroups where it stopped.
- The running members' footfalls go out on the client's footfall signal, `footfall(kind, at, ground, speed)` (#647), unchanged, so a
  scattering herd is heard drumming away with the ground under it.

## Check

`src/worldgen/tools/test_herd_groups.gd` (headless, a few seconds): a deer herd keeps within about 5 m of its leader, the leader
moves upwind in a light wind with `weather.on` (more than 2 m in 90 s), the herd is no wider in rain, all five bolt and fan out (130 degrees), regroup within about 5 m
once the player is 140 m off, and nothing drifts with the flag off. Passed on the PC, 8 Nov 2026, on Steve's #661 branch.
