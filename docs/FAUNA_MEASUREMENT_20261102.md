# Fauna measurement at the starter spawn (MikeW, 2 Nov 2026)

Tool: `src/worldgen/tools/fauna_near.gd --at=53301,68427` on main (1749521), baked tiles 2..4 x 3..5. It estimates the ceiling per player (target x spawn_share x biome weight x hour chance); it is not a simulation.

## Ground around spawn
- Within 100 m: 91.8% temperate_forest, 8.2% ocean.
- Within 500 m: 95.3% temperate_forest, 4.1% ocean, 0.6% bare_rock.
- So everything here is one biome: the spawn mix is decided by the temperate_forest weights alone.

## Expected animals held per player (500 m disc; 100 m is within 5% of it)
| Species | day | dusk | night | Note |
|---|---|---|---|---|
| deer | 1.9 | 4.8 | 1.0 | strongest day animal |
| rabbit | 1.7 | 3.4 | 0.5 | |
| songbirds | 3.8 | 1.9 | 0.1 | |
| frog | 0.1 | 3.8 | 3.8 | |
| boar | 0.0 | 1.5 | 1.5 | |
| fox | 0.1 | 0.3 | 0.4 | |
| duck | 0.5 | 0.5 | 0.5 | needs water edge; ocean share is 4% |
| moose | 0.05 | 0.08 | 0.02 | temperate_forest weight 0.4, plus 1500 m exclusion at spawn |
| wolf | 0 | 0 | 0 | `target_per_player` is 0 in animals.json (switched off) |
| horse, grouse, seal, seabird | 0 | 0 | 0 | no matching biome in this disc |

## Findings
1. Day-time is thin: about 2 deer, 2 rabbits, 4 songbirds. Dusk is rich (deer 4.8). The day feels emptier than the dusk.
2. Wolf is off (target 0). If wolves are meant to exist, that is a design call; I will not switch it on without Dave.
3. Horses cannot appear near spawn (grassland, savanna, heath only). Fine unless Dave wants horses near the town.
4. Seal and seabird need a beach biome; the shore here is 4% ocean with no beach row. Check after Sonny's bake.
5. Per Dave's rule (24 Oct) nothing is boosted for being near spawn; no fix proposed on that basis.

## Proposed fixes (not applied; need Dave's view on day-time density)
- Raise deer and rabbit `spawn_share` a little for day, or give rabbit an `active.day` of 0.8 instead of its current value.
- Leave wolf, moose and horse alone until Dave decides.

## Also closed
F-13 blueberry: data says 0.25-0.5 m; the 3 m golden shrub in the old picture is not a blueberry by data (see docs/FLORA_NEXT_TASKS.md). Closed unless Dave says the size looks wrong.
