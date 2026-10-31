# Your first 30 minutes (tutorial script)

Written to become the in-game tutorial text. Every line states only what the game really does today (data of 2026-10-31 and the server code; see `PLAYTHROUGH_GUIDE.md` and `PLAYTHROUGH_FINDINGS.md` for the evidence). Each step has a **trigger** (when to show it), the **line** (the text, second person, short), and a **check** (what the game must see for the step to be done). Numbers are the real recipe numbers; if a recipe changes, `art/playthrough/status_check.py` and `PLAYTHROUGH_CHAPTERS.md` show it.

What a new player finds at the spawn (`art/playthrough/probe_spawn_output.txt`, real flora placer, re-run after the flora density merge): a forest pond shore, temperate forest, ground 31 m. Within 50 m: about 190 ferns, 88 balsam firs, 67 tall grass, 49 nettles, 30 hazels, 29 raspberry bushes, 18 elder, 17 beeches, 15 reeds, 14 wild garlic, 12 comfrey; 6 grown trees (cover) within 50 m, 17 within 100 m, 80 within 200 m (nearest: a 23 m beech 19 m away). Within 100 m: 142 nettles, 214 tall grass, 33 reeds, 577 ferns. Loose sticks and stones are laid thicker around the spawn on purpose (1-2 extra stones, 2-3 extra sticks per 32 m square within 300 m). Plant fibre comes from **nettles** and **tall grass** (and reeds), thatch from tall grass and reeds, bedding from ferns.

## Fix status that changes this script (2026-10-31; `PLAYTHROUGH_STATUS.md` has the live table)

| Fix | State | What the script gains when it lands |
|---|---|---|
| F-01 recipes known | **landed** (173 of 192 learnable) | pickaxe, club, kindling, hide clothes, waterskin are in the script's later steps |
| F-16 plain `log` recipes | **still broken** | steps A below (chopping block, planks, lumber, wooden house) |
| F-02 flint pickup | **still broken** | steps B below (hide scraper, tanning, sickle, javelin) |
| F-03 tinder sources | landed | the fire step may name birch bark, tinder (2 thatch make 2) as well as plant fibre |

## Minute 0 to 3: look, drink, move

1. Trigger: first frame. Line: "This is the pond shore. W A S D to walk, mouse to look. Hold Shift with W to run." Check: moved 5 m.
2. Trigger: after step 1. Line: "Press Tab to see your bars: Health, Food, Water, Warmth, Energy. They all drain slowly. Press Tab again to close." Check: character screen opened once.
3. Trigger: water in view, Water under 100 %. Line: "Walk to the water's edge and press E to drink." Check: one drink.

## Minute 3 to 8: sticks, stones, fibre

4. Trigger: after the drink. Line: "Pick things up with E. Tap E takes the nearest loose thing; hold E keeps taking everything within reach. Dead branches (sticks) lie under the trees; stones lie along the water's edge and on slopes." Check: 8 sticks and 3 stones in the pack.
5. Trigger: 8 sticks. Line: "Nettles grow here in patches. Press E on a nettle to pick it: you get plant fibre." (1 to 2 fibre a plant, no tool.) Check: 12 plant fibre.
6. Trigger: 12 plant fibre. Line: "Press I. Pick Twine and Craft: 3 plant fibre make 1 twine." (recipe 1, 2 s). Check: 4 twine.

## Minute 8 to 12: the first tool, the first tree

7. Trigger: 2 twine, 1 stone, 1 stick. Line: "Make a Stone axe: 1 stone, 1 stick, 2 twine." (recipe 2, 4 s). Check: stone axe in the pack.
8. Trigger: axe made. Line: "Tools only work from the hotbar. Drag the axe onto a box at the bottom, or press E on it in the inventory, then press its number key to hold it." Check: axe held.
9. Trigger: axe held, a standing tree within 20 m. Line: "Walk up to a tree and click again and again. Thin trees fall in about 10 blows, a thick oak in about 20." (blows = 4 + 30 x trunk thickness in metres, at least 4.) Check: a tree fell.
10. Trigger: tree down. Line: "Keep striking the fallen trunk: first its branches come off (sticks and leaves), then logs." (3 branch blows: 1-3 sticks and 1-3 leaves each; then a log every 3 blows, carried on your shoulder; Q puts it down.) Check: 6 leaves and 10 sticks in the pack. **Do not tell the player to make a chopping block yet (F-16).**

## Minute 12 to 18: fire

11. Trigger: 6 sticks and 3 stones. Line: "Make a Campfire kit: 6 sticks, 3 stones." (recipe 4, 3 s). Check: campfire kit in the pack.
12. Trigger: kit made. Line: "Hold the kit and click where the ring shows. Yellow: open ground, rain puts the fire out. Green: under a tree's crown, the fire survives rain. Stand under a big tree and the ring turns green." Check: a fire placed.
13. Trigger: fire placed, unlit. Line: "A laid fire is not lit yet. Stand close and press E: you spend one plant fibre as tinder." (tinder: plant fibre, birch bark, tinder, tinder fungus; open fires will not light in rain.) Check: fire burning.
14. Trigger: fire lit. Line: "Warmth: stay within 4 metres of the fire. Feed it with E: sticks burn 15 game minutes each, firewood an hour, a log two hours. One game hour is 2.5 real minutes." Check: one fuel added.
15. Trigger: hunger under 80 %. Line: "Hold E at the fire to roast one raw forage item at a time: nuts, berries, roots, mushrooms. Hazelnuts are ripe in autumn; raspberries in summer." Check: one item roasted.

## Minute 18 to 26: shelter and bed

16. Trigger: fire burning, Warmth under 70 %. Line: "Shelter keeps rain and wind off you. Make a Lean-to kit: 8 sticks, 6 leaves, 2 twine." (recipe 13, 8 s). Check: kit in the pack.
17. Trigger: kit made. Line: "Click to place it with the open side towards you. Standing under its roof counts as being under cover. Hold E at it to take it down." Check: lean-to placed.
18. Trigger: lean-to placed. Line: "Ferns give bedding. Press E on two ferns, then craft a Rough bed: 8 bedding, 4 sticks, 2 twine." (recipe 231; thatch also works: 10 thatch.) Check: bed kit.
19. Trigger: bed kit. Line: "Place the bed under the lean-to. Lie down on it with Z. Hold Z for three seconds to sleep. Under cover on a bed you heal faster and food and water drain at half speed." Check: slept 3 s or lay on the bed.

## Minute 26 to 30: tools and what comes next

20. Trigger: bed placed. Line: "A Workbench (12 sticks, 3 twine) lets you make better tools: a stone hammer, a bow, a stone spade, a pickaxe." (recipes 45, 156, 170, 26, 186.) Check: workbench placed.
21. Trigger: workbench placed. Line: "For defence make a Wooden spear: 1 stick (keep a stone in your pack), then bind it with 2 twine for a stone spear. Left click jabs; hold right click to aim a throw." (recipes 5 and 3.) Check: spear made.
22. Trigger: spear made. Line: "Food runs out in about an hour of work. Rabbits give meat, hide and bone: strike them with the spear, then work the body with a stone knife (2 stones, 1 stick)." (recipe 6.) Check: knife made.

## What the tutorial must NOT promise yet

| Do not say | Why (finding) |
|---|---|
| "make a chopping block / log workbench / planks" | recipes need plain `log`; trees give `log_<species>` (F-16) |
| "build a wooden house" | lumber needs the log chain (F-16); the thatch house works (workbench: thatch floor, walls, roof, doorway) |
| "smelt iron, make a forge sword" | no ore, coal or flint pickup (F-23) |
| "farm wheat" | crops.json is read by no code (S-farm) |
| "cook a stew or bread" | 14 dishes lack gatherable ingredients (F-19) |
| "make leather" | no source of flint or leather (F-02) |

## Checks the game can run to advance each step

Steps 4 to 22 each end on an inventory or world event the server already knows (items in the pack, a crafted item, a placed structure with `kind` lean_to, rough_bed or workbench, a fire whose state is lit, a tree felled). No new server code is needed to detect them; the tutorial layer only has to watch the pack and the placed structures.

## Steps that unlock when the open fixes land (write them in now, switch them on with the fix)

**A. When F-16 lands (a felled `log_oak` counts as a `log`):**

| Trigger | Line | Recipe (data) |
|---|---|---|
| 2 logs in the pack or on the shoulder | "Lay the logs down (Q) and make a Chopping block: 2 logs." | #15, 3 s |
| a chopping block placed and an axe held | "Press E at the block to split a wooden block into firewood. Hold E to keep splitting." | server: one block to one firewood |
| workbench placed | "Rough planks: 1 log makes 4 planks at the workbench." | #143, 6 s |
| workbench placed, stone wedge (2 stones + 1 stick, #227) in the pack | "Split a log into 2 lumber with the wedge." | #230 lumber_wedge, 14 s |
| 4 lumber + 1 twine | "Wall section kit: 4 lumber, 1 twine; floor 4 lumber, 1 twine; roof 5 lumber, 2 twine, 2 sticks; doorway 3 lumber, 1 twine." | #119, #120, #121, #123 |
| 4 logs, 6 twine, 6 sticks | "Log workbench: the second bench tier." | #49, 30 s |

A small wooden room (four walls, floor, roof, doorway) is 28 lumber = 14 logs = 14 trees' worth of logs. Say so in the text.

**B. When F-02 lands (flint can be picked up):**

| Trigger | Line | Recipe |
|---|---|---|
| flint + stick + twine, workbench | "Hide scraper." | #180 |
| hide + scraper | "Scrape a hide: processed hide, the start of leather." | #179 |
| flint + stick + twine | "Sickle." | #187 |
| 2 sticks + 1 flint | "Javelins (2)." | #181 |

## Time and quantity check

`PLAYTHROUGH_BUDGET.md` says what the whole order of play costs: about 4 minutes of hands-on time (estimate, see the parameters there) from the first stick to the spear and knife, with 34 plant fibre and about 9 trees' worth of sticks and leaves; the tutorial's 30 minutes is therefore mostly reading and walking.
