# Your first day: one page for Dave (Sal, 2026-10-31; rows 5, 7, 10-12 and the totals updated by Dino on 3 Nov for the fire store, the felled-tree break-up and the real stick count)

What a new player does, in order, with what it costs after the pacing pass. Every number is from the data as of this commit; the in-game hint lines are in `data/items/hints.json` and the goals in `data/items/starter_goals.json`.

| # | Do this | Costs | Time (craft) | Goal and hint |
|---|---|---|---|---|
| 1 | Drink at the pond | nothing | - | "Stand at the water's edge and press E to drink." |
| 2 | Pick sticks, stones and plant fibre | about 12 fibre from nettles or grass, 8 sticks | gathering | "Press E to pick things up." |
| 3 | Twist twine | 3 fibre each (2 s) | 2 s | "Press I, pick Twine..." |
| 4 | Make a Stone axe | 1 stone, 1 stick, 2 twine | 10 s | goal: make an axe |
| 5 | Fell a tree; about 2 s after it lands it breaks into logs, sticks, leaves and bark (3 Nov) | by species while `felling.size_scaled` is off: about birch 5, pine 8, beech 9, oak 12 blows | - | goal: fell a tree |
| 6 | Make and place a Campfire | 6 sticks, 3 stones | 8 s | goal: light a fire |
| 7 | Put wood in with F, light it with E and plant fibre; raw meat in the store (F) cooks (3 Nov) | 1 fibre | - | goal: light a fire, then eat something wild |
| 8 | Make a wooden hammer: strike a big hardwood log with the axe for a large wooden block, split it into 4 small blocks (I), then hammer = 1 small block, 1 stick, 1 twine | 1 stick, 1 twine | 4 s + 5 s | goal: make a wooden hammer |
| 9 | Hold the hammer, right click (or R), pick Lean-to and place it (no kits since #292, Dave 4 Nov) | 30 sticks, 200 leaves, 10 twine from the pack | - | goal: build a shelter |
| 10 | Make a Rough bed in the inventory (the one bed made by hand) and sleep | 10 thatch (or 8 bedding or straw), 4 sticks, 2 twine | 25 s | goal: make a bed |
| 11 | Build a workbench with the hammer: the Camp bench, or the log workbench (4 logs, 6 twine and 6 more sticks) | 16 sticks, 6 twine, 4 stones for the Camp bench | - | goal: build a Camp bench (either counts, #53) |
| 12 | Make a spear, a knife, hunt a rabbit (the wooden spear already kills a rabbit in one jab; the goal wants the stone spear) | wooden spear 1 stick (6 s, a stone kept) then 2 twine (10 s); knife 2 stones + 1 stick (8 s) | 6 s, 10 s, 8 s | goals: spear, knife |
| 13 | Fish at the pond | rod (2 sticks, 2 twine) or shore net (8 twine, 4 stones) | rod 8 s | goal: catch a fish |

Whole first day (re-added from data by MikeW, 5 Nov, after the 4 Nov shelter and no-kits changes): about **62 sticks** (campfire 6, axe 1, hammer 1, lean-to 30, bed 4, bench 16, spear 1, knife 1, rod 2), **10 stones** (axe 1, campfire 3, bench 4, knife 2; the spear's stone is kept), **200 leaves** (one felled tree), 1 large wooden block, 10 thatch or 8 bedding, and **25 twine = 75 fibre** (axe 2, hammer 1, lean-to 10, bed 2, bench 6, stone spear 2, rod 2). The lean-to and bench are hammer builds with no craft time; the rest of the day is gathering and walking, which nobody has timed yet.

## Hob's stall at the spawn pad (shops.json, coins.json trade; checked by Dino, 3 Nov)

Hob sleeps from 21:00 to 06:00 game time (npcs.json schedule). Asleep he only mumbles and no trade opens (server_dialogue.gd). So in a new world (08:00 start) he trades from minute 0 to about minute 32, then again from minute 55. Prices start at about value x 1.3 and move by up to -15 / +20 percent with how full his shelf is. He pays about value x 0.55, and less each time you sell him the same thing.

| Item | Price |
|---|---|
| Stick, stone, fibre, firewood | 2-3 copper each |
| Torch | 8 |
| Stone knife | 16 |
| Stone axe | 26 |
| Waterskin | 20 |
| Backpack | 52 |

The 69 copper of goal rewards buys the backpack plus a waterskin. Hob sells no bed (Dave 2 Nov: you make your own).

**Fixed (#53, merged 3 Nov, `or_have`):** the axe goal used to count only an axe you **make** (`made_item`). A bought axe fells trees but never completes the goal, and the fell, fire and later goals wait behind it. The hint asks for a stone axe, so a player who bought one has to craft a second.

## What works today and what does not
- **Works:** everything above, plus clothes from hide, torches, a stone forge, the chopping block and the log chain (F-16 fixed: a held log fills log recipes), the thatch house, and goals and hints on screen (one line at the top; a hint whose goal is still open is said once more after 5 minutes).
- **Needs code before a player sees it (not re-checked on 3 Nov unless named):** flint, ore and coal pickup, water gathering, farming, the learn system, shops beyond Hob. 13 hints never show because the server has no trigger for them (docs/handoff/DINO_ROUND6_GOALS.md), 3 of them early game.
- **Not measured:** how long a real first hour takes. CRAFT_PACING.md says what to time.

## Questions for you (my defaults in brackets)
1. Is two minutes of crafting right for the first day, or should the lean-to and bed be quicker? [keep]
2. Should rewards (69 copper in total, plus 4 sticks and 3 kindling) be in coin or only items? [coin]
3. Should hints repeat if a player ignores them for five minutes? [yes, once: this is what the game does now]
