# Early-game forage at the starter spawn (MikeW, 3 Nov 2026)

Tool: `src/worldgen/tools/flora_near.gd --at=53301,68427` on main (d05664a6). Nearest plant of each kind, and how many grow within 100 m. The world starts in spring (day 30). Per Dave's rule nothing is placed because it is near spawn; this only checks what the terrain already gives.

## First-hour needs: all within 100 m
| Need | Plant | Nearest | Within 100 m |
|---|---|---|---|
| Fibre and thatch | tall_grass | 14 m | 454 |
| Fibre (cordage) | nettle | 11 m | 185 |
| Sticks, nuts | hazel | 16 m | 127 |
| Reeds | reeds | 24 m | 483 |
| Fern (bedding) | fern | 1 m | 519 |

## Spring food (in season at the start)
| Plant | Nearest | Within 100 m |
|---|---|---|
| wild_mint | 1 m | 18 |
| comfrey | 22 m | 12 |
| dandelion | 28 m | 91 |
| watercress | 35 m | 17 |
| wild_garlic | 83 m | 14 |
| elder (flowers) | 62 m | 21 |
| morel | 174 m | 0 |
| sorrel, plantain, hawthorn, heartroot, dewlantern | 290 to 340 m | 0 |

Berry bushes (raspberry 32 m, bramble 16 m, blueberry 35 m) are close, but they fruit in summer and autumn, not at the spring start.

## Findings
1. Fibre, sticks and bedding are plentiful within 30 m. No change needed.
2. Spring food near spawn is herbs and greens (mint, dandelion, watercress, comfrey, wild garlic). That is enough for the first hour if those items give real calories; whether they do is Sal's item data.
3. Meadow herbs (wild thyme, sorrel, plantain, wild strawberry, flax) do grow on tile 3,4, but in the big meadow about 7 km north-east of spawn (around 58496, 73856: thyme 31 m, sorrel 3 m, plantain 5 m, flax 4 m away there). The spawn sits in forest, so they are a trip, not a first-hour find. No change, per the no-placement-near-spawn rule.

# Bushes and flowers at distance: not worth thinning (MikeW, 3 Nov 2026)
Tool: `src/worldgen/tools/flora_ring_count.gd` (5x5 chunks around spawn). Each kind is split into the near half and the far half of its view distance.

| Kind | View | Near half | Far half | Saved by Dave's curve |
|---|---|---|---|---|
| Trees | 450 m | 1,615 | 5,389 | about 2,150 (done in PR #162) |
| Bushes | 45 m | 11 | 64 | about 26 |
| Small plants and flowers | 60 m | 240 | 667 | about 270 |

Trees are 88% of what flora draws. Thinning bushes and flowers would save about 4% of flora instances, and would force their chunks to re-plan as the player walks, which costs more than it saves. So I am not doing it unless the hitch log says otherwise.
