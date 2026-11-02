# Bug 5 (tree takes over 20 hits): findings from the code (Sal, 2 Nov 2026)

Read from the code only; nothing was run in a game.

## The server cannot ask for more than 15 blows on a normal tree
Blows needed = round(2 + trunk_m x 16.5), between 3 and 22, divided by the fell skill factor (never below 0.8). `trunk_m` is a fixed number per species in `data/tables/flora.json`, not scaled by the tree's size.

| Tree | trunk_m | Blows | Worst case (skill factor 0.8) |
|---|---|---|---|
| Beech (Dave's tree) | 0.4 | 9 | 12 |
| Oak, sweet chestnut | 0.6 | 12 | 15 |
| Walnut | 0.5 | 10 | 13 |
| Everember (only one over 15) | 3.2 | 22 | 28 |

Before the 31 Oct change a beech took 4 + 0.4 x 30 = 16 blows at the old 0.55 s swing, so the server number went **down**, not up. Over 20 on a beech therefore means swings that the server never counted as a tree hit.

## Where swings can be lost (`held_item.gd` `_strike`)
Each swing casts one ray from the camera and the first thing it hits decides the action, in this order: loose log, boulder, felled trunk, stump, standing tree, else the ground (a pick-at-ground sound and `ACT_MINE`).
1. **Felled logs and trunks near the point win over the tree.** Dave's screenshot shows felled logs lying in the grass beside the tree. A swing that lands near one of them goes to `ACT_PROCESS` (cutting the log), not `ACT_HIT`.
2. **A ray that hits grass or ground instead of the trunk** finds no tree (`_tree_near`) and goes to the ground branch.
3. The server drops any hit less than 400 ms after the last one, and rejects one when the player is farther than 3.5 m + trunk from the tree's centre.

## What I cannot tell without a run
Which of 1 to 3 happened to Dave. A server log line per tree hit ("hits / needed") would show it in one test: if the server counts 9 of 9 but Dave swung 20 times, the swings are being lost on the client.

## Suggested next step (needs Godot, so for the PC thread)
1. Log `hits/needed` on the server for each `ACT_HIT` and which action each swing sent.
2. Chop one beech with felled logs lying beside it, and one with none, and compare.
3. If it is cause 1, make a standing tree under the crosshair win over a log within about 1 m.
