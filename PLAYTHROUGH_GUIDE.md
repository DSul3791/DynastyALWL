# Dynasty: your first days, from nothing to a shelter, tools and weapons

A walkthrough for a brand-new player, written second person, derived from the game's own data and server code (build of 2026-10-30, branch DailyDev_20261029). Every number below is read from `data/items/*.json` or the server code, not guessed. Step numbers match the pictures in `art/playthrough/` and the rows in `PLAYTHROUGH_FINDINGS.md`.

Lines marked **[BLOCKED]** are places where this guide has to assume something the game does not have yet; they are collected in `PLAYTHROUGH_FINDINGS.md` as an action list. Lines marked **[in progress]** are known work somebody else is already doing.

## Controls you need first (CONTROLS.md)

| Key | What it does |
|---|---|
| W A S D, mouse | Walk, look. Double-tap W jogs, Shift+W runs. C crouch, X sit, Z lie down |
| **E** | Gather. Tap = the nearest loose item in view (3 m) or the nearest pickable plant (2.5 m). **Hold E** = keeps taking one thing at a time, about 5 a second, from everything within 2 m |
| I | Crafting and inventory screen: recipes left, pack right. Click a recipe, press Craft |
| 1 to 9, 0 | Hotbar: hold what is in pack slot 1 to 10. **Tools must be on the hotbar to work** |
| Left click | Use the held item (swing the axe, jab the spear, place a kit) |
| Right click | Eat / apply food or medicine; with a spade, switch dig / raise |
| Tab | Character screen (health, food, water, warmth, energy) |
| P | Auto pickup on / off |

## Step 01. Arrive and look around (spawn 53301, 68427)

You start with nothing and full bars. Open the character screen (Tab) once and look at **Food, Water, Warmth, Energy**: they all drain. Food lasts about an hour of work, water you must drink every game day. The spawn area is open grass with young conifers and ferns; big woods are a short walk away. Within 300 m of the spawn point the game scatters extra loose sticks and stones on purpose (drops.json `spawn_boost`: 1-2 extra stones and 2-3 extra sticks in every 32 m square) so you do not have to search long.

Picture: `art/playthrough/03_raw_materials.jpg` shows the spawn meadow (the NPC Edda stands near the spawn).

## Step 02. First pickups: sticks and stones

* **Sticks** (item `stick`) lie on the ground as thin dead branches, more of them under trees. Walk up and tap/hold E. Shrubs (bushes) also drop 1-3 sticks when picked (drops.json `by_kind.shrub`).
* **Stones** (item `stone`, stack 20) lie loose, mostly on slopes, next to rocks and along the water's edge. There is only one kind of loose rock item: `stone` (the "hand stone"). There is **no flint** anywhere yet **[BLOCKED, see findings F-02]**, and no ore you can reach with bare hands.
* **Boulders** (big grey rocks) are not pickable. An axe (or pick) breaks them: **3 axe blows give 1 stone** (boulders.json). A blow on bare rock with the axe also gives a stone.

How many do you need for the whole first hour? About 12 sticks, 4 stones to start (axe 1 stone + 1 stick; fire 6 sticks + 3 stones; knife 2 stones + 1 stick), then more.

Pictures: `03_raw_materials.jpg` (stone, stick, plant fibre, twine, thatch, leaves, bark, kindling, firewood lying on the ground, in that order left to right).

## Step 03. Plant fibre: which plants to pick

Plant fibre (`plant_fibre`) is the first real material. You pick it with bare hands (no tool), one E per plant. What each plant gives (drops.json `by_species`):

| Plant | Where it grows (flora.json) | Season | You get |
|---|---|---|---|
| **Nettle** | forest, mixed forest, marsh (patches of 10-20) | spring, summer | 1-2 plant fibre |
| **Tall grass** | grassland (300 per hectare), savanna, meadow | spring-autumn | 1-3 plant fibre **and** 4 thatch |
| **Wild flax** | grassland | summer | 2-4 plant fibre |
| **Reeds** | marsh, mangrove (800 per hectare) | all | 2-3 plant fibre **and** 8 thatch |
| Riverbraid | grass/forest/marsh, rare | summer-autumn | 2-3 plant fibre |
| Tanglewort | forest, rare | all | 1-2 plant fibre |
| **Thatching grass** | everywhere, very rare (patches of 10-20 plants) | all | 10 thatch (no fibre) |
| Heather | heath | all | 4 thatch |

A picked plant is gone and the spot grows another after about 3 game days. Hold E in a patch of nettles or tall grass and you fill your pack quickly.

Pictures: `02_fibre_plants.jpg` (reeds, wild flax, thatching grass, heather labelled), `02b_berries_herbs.jpg`.

## Step 04. Twine

Open the crafting screen (I). Recipe **Twine** (#1, known from the start): **3 plant fibre -> 1 twine**, 2 seconds. Twine can also come from 2 bark (#24 "Twine from bark").

You need **5 twine for the first axe = 15 plant fibre**. Gather 20 fibre before you go on.

## Step 05. Make the first stone axe

Recipe **Stone axe** (#2, known, no station): **1 stone + 1 stick + 5 twine -> stone axe**, 4 seconds, anywhere. It lasts 900 uses (durability), wears 1 per tree blow, 5 per boulder blow.

Put it on the hotbar: drag it from the pack onto a hotbar box, or press E on it in the inventory. Press its number to hold it.

Also craftable at once with no station: **stone knife** (#6: 2 stone + 1 stick), **wooden spear** (#5: 1 stick, keeps 1 stone in the pack), **torch** (#7: 1 stick + 2 plant fibre).

## Step 06. Chop a tree

Walk up to a standing tree (trunk within about 2 m), hold the axe, **click repeatedly** (about one blow every 0.5 s). The number of blows is `clamp(4 + trunk_thickness_m x 30, 4, 40)`: a 0.2 m trunk takes about 10, an oak (0.6 m) about 22. Practice makes it faster (Fell tree skill). When the last blow lands the tree falls and rests on the ground as a **trunk**, leaving a **stump**. **[in progress: the fall pose and the stump chopping were just finished, see commit a641581d.]**

Work the trunk with the axe (one blow each, press the use key at it):
1. Blows 1-3: **branches come off**: 1-3 sticks and 1-3 leaves per blow.
2. Then **logs**: 3 blows per log, each log 2.44 m, up to 20 logs; 30% of blows also peel bark (birch, spruce, pine give thatch bark instead), 15% give seeds or the tree's nut.
3. When the last log is gone a root ball (`tree_roots`, 1-3) comes up.

Small trees (a sapling) give only 3 blows of firewood 1-2, kindling 2-4, stick 2-4.
A **stump** can be chopped up with the axe too: 3 + 15 x radius blows (max 14), some blows chip off 1-2 sticks, the last gives 2-4 firewood, 2-4 kindling and 1-3 sticks.

A log is carried on the shoulder, alone (Q lays it down). Chop a log on the ground with the axe to get **wooden blocks** (`wooden_block`, hardwood; `wooden_block_soft` from conifers). A **chopping block** (recipe #15: 2 logs) splits one block into one firewood with the axe (E at the block).

Pictures: `art/playthrough/` has no stump or trunk picture from this run (see findings, "could not photograph").

## Step 07. Shelter under a big tree

The cover rule (src/shared/cover.gd): a spot is "under cover" when it lies inside the crown circle of a **grown** tree. **Only trees at least 0.8 of their full height give shelter**; young trees (the little conifers on the spawn meadow) give none. The sheltered disc is about the crown radius (crown_m, e.g. 9 m for oak = 4.5 m x 2 scale). Under cover: rain does not reach you, fires you light survive rain, sleep is better, warmth is better (wind 30%). Cover is only mild shelter: it does **not** warm you against cold air.

Walk to the biggest tree you can find (oaks, beeches, tall pines), stand under the crown, press **Z** to lie down and hold Z 3 s to sleep when you are tired. Open ground in rain: you cannot sleep.

## Step 08. Campfire: kit, place, light

1. Recipe **Campfire** (#4): **6 sticks + 3 stones -> campfire kit** (4 s). (CONTROLS.md still says 20 sticks and 10 stones: out of date.)
2. Hold the kit and left click. The ring on the ground is **yellow on open ground** (rain puts the fire out) and **green under a tree crown** (the fire survives rain). Fires need 2 m of space from other fires and ground no steeper than 0.6 m rise.
3. The kit is placed already laid with 4 sticks. **Press E at the fire to light it**: it uses **one tinder item** from the pack: `plant_fibre` first, or `birch_bark`, `tinder`, `tinder_fungus`. **[BLOCKED partly: only plant fibre can really be had, see F-03.]** In rain on open ground it will not light; in a drizzle there is a chance it fails and the fibre is lost.
4. Feed it: tap E at the fire adds fuel in order firewood, driftwood, stick, kindling, log. **A fire size follows its wood**: sticks and kindling = survival fire; 3+ firewood = campfire; 3+ logs = bonfire. A stick burns 15 game minutes, firewood 1 game hour, a log 2 game hours. 1 game hour = 2.5 real minutes.
5. **Hold E** at a lit fire roasts raw forage (berries, nuts, roots, mushrooms) one at a time.

**Warmth:** stand within 4 m of a lit fire, or under cover. Warmth below 40: you shiver and stop healing; below 20 the cold costs health. A fire plus a roof is the first cold-night answer.

Pictures: `10_campfire_placed.jpg` (the placement ghost; the lit fire itself is [in progress, Kathleen]).

## Step 09. Water, food

* **Water:** walk to a river or lake and press E at the edge to drink (300 ml a press). With a bowl, pot, bucket or waterskin in hand E fills it (500 ml). **[in progress: water in some rivers is not filling yet.]**
* **Food:** pick berries (raspberry 150, bramble 250, blueberry 150 per big bush, in season summer/autumn), hazelnuts, apples, roots (roots need a spade). Eat by right click. **Raw food is allowed but some makes you sick** (raw meat 24 h, acorns and mushrooms mild). Roast at the fire to be safe. First time you eat an unknown food it costs food and water only; the game remembers.
* Herbs: plantain and comfrey give leaves (poultice, bandage recipes #8-#11).

## Step 10. The first shelter: a lean-to

Recipe **Lean-to kit** (#13, known): **8 sticks + 6 leaves + 2 twine**. Leaves come from the branch blows of a felled tree (step 06) or from a stump/trunk. Hold the kit, click to place (ghost 2.4 x 2.1 m, open front towards you). It is a roof for the cover rule (1.1 x 0.95 m half-sizes, 2.1 m high): anyone under it is "under cover", fires under it survive rain. Hold E 0.6 s at it to take it down (kit comes back). A chunk holds at most 6.

## Step 11. Bedding / bed

Recipe **Rough bed kit** (#162, known): **10 thatch + 4 sticks + 2 twine**. Thatch comes from tall grass (4 each), reeds (8), heather (4), thatching grass (10), birch/spruce/pine bark on a felled trunk (2-5). Place it under the lean-to or a tree. A lying or sleeping player within 1.2 m of it, under cover, sleeps better: health regen x1.25, food and water drain x0.5, warmth bonus 0.1. (The plant "bedding" item exists but nothing uses it.)

## Step 12. Workbench and thatch house pieces

* **Workbench kit** (#45, known): **12 sticks + 3 twine**. Place it; a recipe needing "workbench" works only near it (reach + 1 m).
* Thatch pieces (open to everyone though not "known"): **thatch floor kit** 6 twine + 20 thatch; **wall** 20 twine + 50 thatch + 15 sticks; **roof** 10 twine + 40 thatch + 12 sticks; **doorway** 12 twine + 25 thatch + 12 sticks. All at the workbench. They are big spends: 50 thatch is five tall-grass patches.
* Wood walls, floors and roofs (`wall_section_kit` etc.) need **lumber**, which needs a saw. **[BLOCKED, F-05.]**

## Step 13. First tools

| Tool | Recipe | Notes |
|---|---|---|
| Stone axe (#2) | stone, stick, 5 twine | step 05 |
| Stone knife (#6) | 2 stone + stick | bark, gum, sap, carcasses |
| Wooden spade (#12) | 2 sticks, keeps a stone | digs soil, roots, clay |
| Stone spade (#26) | workbench: wooden spade + 2 stone + twine | 2x the dig |
| Wooden hammer (#161) | wooden block + stick + twine | blueprints |
| Stone hammer (#156) | workbench: stone + stick + twine | better hammer |
| Wooden / stone hoe (#139/#140) | sticks + twine (+stone at bench) | paths, grading |
| **Pick axe** | stone pickaxe #186: 2 sticks + 3 stones + 2 twine at the bench, **known false: no player can learn it** | **[BLOCKED, F-01]** The stone axe breaks boulders 3x slower |
| Fishing rod (#46) | 2 sticks + 2 twine | catch fish at water |
| Torch (#7) | stick + 2 fibre | |
| Chopping block (#15), chest (#14: 10 sticks + 4 twine), rock pile (#151: 45 stones) | | |

## Step 14. First weapons

| Weapon | Recipe | Damage / life |
|---|---|---|
| Wooden spear (#5) | 1 stick (keeps a stone) | 6, 300 uses |
| Stone spear `spear` (#3) | wooden spear + 5 twine (keeps a stone) | 8, 450 uses |
| Wooden bow (#170) | workbench: 2 sticks + 3 twine | needs arrows |
| Wooden arrow (#171) | 2 sticks + **2 feathers** -> 4 | feathers only drop from grouse and ducks (needs a kill and a knife) |
| Stone arrow (#172) | 2 sticks + 2 feathers + 2 stones -> 4 | |
| Quiver (#173) | 2 hide + 2 twine | |
| Snare (#177) | 3 twine + 2 sticks | |
| Wooden club (#189), stone mace (#202), javelin (#181), wicker shield (#201) | **known false: not craftable** | **[BLOCKED, F-01]** |

Left click jabs the spear; hold right click to aim a throw, left click throws. Hold the bow, hold click to draw.

## Quick order of play (the whole thing in one list)

1. Hold E around you: 6 sticks, 4 stones, then 20 plant fibre from nettles or tall grass.
2. Craft 5 twine, then the stone axe; put it on the hotbar.
3. Fell a small or medium tree (10-22 blows); work the trunk: sticks, leaves, logs; split blocks.
4. Craft the campfire kit, place it under a big tree, light it with a plant fibre.
5. Roast berries, drink at the water.
6. Craft the lean-to kit (8 sticks, 6 leaves, 2 twine) and place it by the fire.
7. Gather 10 thatch + 4 sticks, craft the rough bed kit, place it under the lean-to.
8. Workbench (12 sticks, 3 twine) -> stone hammer, bow, thatch pieces.
9. Spear (stick, then 5 twine) for hunting; knife (2 stones, stick) for carcasses.
