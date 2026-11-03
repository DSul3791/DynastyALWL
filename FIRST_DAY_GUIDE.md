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
| 8 | Lash a ridge-pole lean-to and roof it with leaned sticks | 32 sticks, 8 leaves, 4 twine | 25 s | goal: build a shelter |
| 9 | Make a Rough bed and sleep | 10 thatch (or 8 bedding or straw), 4 sticks, 2 twine | 25 s | goal: make a bed |
| 10 | Build a Camp bench (the goal calls it a workbench) | 16 sticks, 6 twine, 4 stones | 60 s | goal: build a workbench |
| 11 | Make a spear, a knife, hunt a rabbit | wooden spear 1 stick (6 s, a stone kept) then 2 twine (10 s); knife 2 stones + 1 stick (8 s) | 6 s, 10 s, 8 s | goals: spear, knife |
| 12 | Fish at the pond | rod (2 sticks, 2 twine) or shore net (8 twine, 4 stones) | rod 8 s | goal: catch a fish |

Whole kit (re-added from data by Dino, 3 Nov; was "about 30 sticks, 6 stones, 6 leaves, 12 twine"): about **63 sticks** (campfire 6, axe 1, lean-to 32, bed 4, bench 16, spear 1, knife 1, rod 2), **10 stones** (axe 1, campfire 3, bench 4, knife 2; the spear's stone is kept), **8 leaves**, 10 thatch or 8 bedding, and **18 twine = 54 fibre** (axe 2, lean-to 4, bed 2, bench 6, stone spear 2, rod 2); crafting time about 3 minutes (171 s plus the bed, 10 s with bedding or 25 s with thatch); the rest of the day is gathering and walking, which nobody has timed yet.

## Hob's stall at the spawn pad (shops.json, coins.json trade; checked by Dino, 3 Nov)

Hob sleeps from 21:00 to 06:00 game time (npcs.json schedule). Asleep he only mumbles and no trade opens (server_dialogue.gd). So in a new world (08:00 start) he trades from minute 0 to about minute 32, then again from minute 55. Prices start at about value x 1.3 and move by up to -15 / +20 percent with how full his shelf is. He pays about value x 0.55, and less each time you sell him the same thing.

| Item | Price |
|---|---|
| Stick, stone, fibre, firewood | 2-3 copper each |
| Torch | 8 |
| Stone knife | 16 |
| Stone axe | 26 |
| Waterskin | 20 |
| Rough bed kit | 37 |
| Backpack | 52 |

The 69 copper of goal rewards buys the backpack plus a waterskin, or a bed kit plus a stone axe.

**Catch (fixed in Sal's open PR #53, `or_have`):** on main the axe goal counts only an axe you **make** (`made_item`). A bought axe fells trees but never completes the goal, and the fell, fire and later goals wait behind it. The hint asks for a stone axe, so a player who bought one has to craft a second.

## What works today and what does not
- **Works:** everything above, plus clothes from hide, torches, a stone forge, the chopping block and the log chain (F-16 fixed: a held log fills log recipes), the thatch house, and goals and hints on screen (one line at the top; a hint whose goal is still open is said once more after 5 minutes).
- **Needs code before a player sees it (not re-checked on 3 Nov unless named):** flint, ore and coal pickup, water gathering, farming, the learn system, shops beyond Hob. 13 hints never show because the server has no trigger for them (docs/handoff/DINO_ROUND6_GOALS.md), 3 of them early game.
- **Not measured:** how long a real first hour takes. CRAFT_PACING.md says what to time.

## Questions for you (my defaults in brackets)
1. Is two minutes of crafting right for the first day, or should the lean-to and bed be quicker? [keep]
2. Should rewards (69 copper in total, plus 4 sticks and 3 kindling) be in coin or only items? [coin]
3. Should hints repeat if a player ignores them for five minutes? [yes, once: this is what the game does now]
