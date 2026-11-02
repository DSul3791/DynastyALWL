# Fauna behaviour audit (MikeW, 2 Nov 2026)

Read from `src/stream/server_animals.gd`, `server_wolves.gd` and `data/animals/animals.json` on main. Nothing run in a game; this is what the code and data say.

## Dave's list: what exists
| Behaviour | State |
|---|---|
| Wander and graze | Yes, all species (`graze_s`, `wander_m`). |
| Flee from the player | Yes: spook distance, alert pause, burst run, zigzag, safe distance. Senses use wind and line of sight (`_sense_factor`, `_sight`). |
| Herding | Yes: `herd` size and `herd_pull_m` (deer, horse, boar, songbird, frog, grouse, seal, seabird). |
| Hunting | Wolf packs only (`server_wolves.gd`), and wolf `target_per_player` is 0, so no wolf spawns. |
| Defending | Moose only (`defend`: warn, charge, recover). |
| Stealing | Fox only (`thief`). |
| Taming | Horse only (`tame`). |
| Spawn and despawn | Yes: top-up out of sight, despawn beyond `despawn_m`, off-hours despawn by `active`. |
| Resting or sleeping | **No.** Animals graze at every hour; `active` only changes spawn chance. |

## Gaps
1. Six newer species (boar, songbirds, frog, grouse, seal, seabird) are copies of rabbit or deer numbers. A boar flees like a deer and never defends; a seal flees on land; seabirds do not take off as a flock like ducks do.
2. No rest state, so night animals look the same as day animals.
3. Wolf is off. Nothing hunts, so deer and rabbits only ever react to the player.

## Proposed order (needs Dave's view on 1 and 3, which are design)
1. Boar: reuse the moose `defend` block (boar charge when cornered). Small data change.
2. Seabird: reuse the duck `flock` block.
3. Rest state at night for day-active species (code).
4. Wolves on (Dave's decision).
