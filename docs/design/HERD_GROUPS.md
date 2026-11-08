# Herd and group layer: one leader, keeping places, drifting, scattering, regrouping

Deer, boar, horses, cattle and ground birds already spawn as herds on the server (`herd` [min, max]) and alarm each other
(`alarm_s`). Today each member wanders round its own home and is only pulled back when it strays past `herd_pull_m`, so a herd
grazes as a loose cloud that never goes anywhere. This layer makes the herd move as one. It is server-side movement (positions are
the server's), behind `animals.json` `groups.enabled` (default **false**). The client herd look (HERD_CLIENT.md: facing,
spacing on screen, looking up together) already sits on top and needs no change.

## Leader and places

- The leader is the herd's first living member (`_group_leader`). When it dies the next one leads.
- Each graze step the leader's home moves `groups.drift_m` (2 m) along its drift direction:
  - `group_drift: "into_wind"` (deer, elk): upwind when the wind is above 0.1. Red deer graze moving into the wind (Jamie's #639).
  - `"with_storm"` (cow, buffalo, wildebeest): downwind when the storm is above 0.5. Cattle drift with a storm (#639).
  - `"free"` (boar, warthog, horse, donkey, ground birds): a slow wander, turning up to 0.6 rad a step.
- Every other member's home is its place round the leader: a spiral at the golden angle, `group_spacing_m` x sqrt(place), turned
  with the drift. Deer 3 m, elk 4, horse 3.5, cow 3, boar 2, pheasant 1.5, guineafowl 1.

## Weather bunching (Jamie's #639)

Spacing x (1 - `rain_bunch` 0.35 x rain-or-snow - `wind_bunch` 0.25 x wind), never below `min_bunch` 0.5. In heavy rain a deer
herd stands about two thirds as far apart. Sheltering under trees is a later step (the habitat rule already prefers trees for deer).

## Scatter and regroup

- The sentinel's alarm reaches the herd as before (`alarm_s`). With groups on, each member bolts up to `scatter_deg` (25) either
  side of straight away, alternating sides by place, so the herd fans out instead of running in single file.
- Ground birds: Steve's #636 `alarm_group` (crow, pheasant, grouse, guineafowl, songbirds within 15 m) carries the alarm across
  species; with groups on, each ground-bird herd also fans out on it.
- Once safe (`safe_m`), each member's next graze step sends it to its place round the leader: the herd regroups where it stopped.
- The running members' footfalls go out on the client's footfall signal, `footfall(kind, at, ground, speed)` (#647), unchanged, so a
  scattering herd is heard drumming away with the ground under it.

## Check

`src/worldgen/tools/test_herd_groups.gd` (headless, a few seconds): a deer herd keeps within about 5 m of its leader, the leader
moves 5 m into the wind in 90 s, the herd is no wider in rain, all five bolt and fan out (130 degrees), regroup within about 5 m
once the player is 140 m off, and nothing drifts with the flag off. Passed on the PC, 8 Nov 2026.
