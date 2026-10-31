# Your first day: one page for Dave (Sal, 2026-10-31)

What a new player does, in order, with what it costs after the pacing pass. Every number is from the data as of this commit; the in-game hint lines are in `data/items/hints.json` and the goals in `data/items/starter_goals.json`.

| # | Do this | Costs | Time (craft) | Goal and hint |
|---|---|---|---|---|
| 1 | Drink at the pond | nothing | - | "Stand at the water's edge and press E to drink." |
| 2 | Pick sticks, stones and plant fibre | about 12 fibre from nettles or grass, 8 sticks | gathering | "Press E to pick things up." |
| 3 | Twist twine | 3 fibre each (2 s) | 2 s | "Press I, pick Twine..." |
| 4 | Make a Stone axe | 1 stone, 1 stick, 2 twine | 10 s | goal: make an axe |
| 5 | Fell a tree, work the trunk | about 10 to 30 blows | - | goal: fell a tree |
| 6 | Make and place a Campfire | 6 sticks, 3 stones | 8 s | goal: light a fire |
| 7 | Light it with plant fibre, roast food | 1 fibre | - | goal: eat something wild |
| 8 | Make a Small shelter (lean-to) | 8 sticks, 6 leaves, 2 twine | 25 s | goal: build a shelter |
| 9 | Make a Rough bed and sleep | 10 thatch (or 8 bedding or straw), 4 sticks, 2 twine | 25 s | goal: make a bed |
| 10 | Build a Workbench | 20 sticks, 6 twine, 4 stones | 60 s | goal: build a workbench |
| 11 | Make a spear, a knife, hunt a rabbit | stick, 2 twine; 2 stones + stick | 10 s, 8 s | goals: spear, knife |
| 12 | Fish at the pond | rod or shore net | - | goal: catch a fish |

Whole kit: about 30 sticks, 6 stones, 10 thatch, 6 leaves and 12 twine (36 fibre); crafting time about 2 minutes 10; the rest of the day is gathering and walking, which nobody has timed yet.

## What works today and what does not
- **Works:** everything above, plus clothes from hide, torches, a stone forge, a chopping block (once logs fill ingredients), the thatch house.
- **Needs code before a player sees it:** wood from the log chain (ingredient groups), flint, ore and coal pickup, water gathering, farming, the learn system, goals and hints on screen, shops beyond Hob.
- **Not measured:** how long a real first hour takes. CRAFT_PACING.md says what to time.

## Questions for you (my defaults in brackets)
1. Is two minutes of crafting right for the first day, or should the lean-to and bed be quicker? [keep]
2. Should rewards (70 copper in total) be in coin or only items? [coin]
3. Should hints repeat if a player ignores them for five minutes? [yes, once]
