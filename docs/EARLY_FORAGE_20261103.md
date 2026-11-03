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
3. wild_thyme grows nowhere on tile 3,4 (no match in the 5x5 chunk search). Its biomes may not exist here. A data check for Sal or me if it is meant to be a starter herb.
