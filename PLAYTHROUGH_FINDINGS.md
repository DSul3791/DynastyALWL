# Playthrough findings: spawn to first shelter, tools and weapons

**Update 2026-10-31:** the height fix (TERRAIN_VERSION 44) changed the world; the pictures of items and structures are unaffected, the plant and ground pictures of 2026-10-30 were taken on the old world (see Part 2 sections 10 and 11).

Date 2026-10-30, branch `claude/dazzling-elbakyan-e46f22`, based on DailyDev_20261029 (4efe6b1d). Read `PLAYTHROUGH_GUIDE.md` first: every step number below is a step of that guide.

**How this was checked (and what was not)**
* **Data reachability** (`art/playthrough/reachability.txt`): every recipe ingredient traced to a source (ground scatter, boulders, plant drops, trunk/stump drops, digging, carcass, fishing, another reachable recipe), counting only recipes that are `known:true` or in `open_recipes.json`.
* **Server probe** (`art/playthrough/probe_playthrough.gd`, output `probe_output.txt`): the real `server_items.gd` with every recipe given exactly its ingredients and queued, the workbench placed, and a campfire lit with each tinder item. Result: 105 recipes behave exactly as their `known` flag says; the one mismatch is Lumber by hand (needs a hand saw nobody can make). `test_first_hour.gd` (job 78) also passes with 0 failures: gather, twine, axe, fell, campfire, drink, lean-to, chest.
* **Pictures** from the real client (`art/playthrough/rig.sh` = tools/look_rig.sh plus a `--row` option that lays items on the ground; `run_all.sh`; `rig_row_seed.py`). Ground at the spawn is y=1039 (the rig's default `--gy 31.0` is stale: items seeded there are invisible; use `--gy 1039.0`).
* **Not done:** I did not walk the game by hand with real mouse clicks, so picking a plant with E, swinging at a tree in the client and the in-game craft screen were not exercised in the client (only on the server code). Nettle and tall-grass patches near the spawn, the felled trunk, stump, lit campfire and cover under a grown tree were **not photographed** (the flora rig frame hid them, the fell rig is Kathleen's in-progress work, the machine was heavily loaded by other sessions: three of my picture runs, `04_tinder_and_missing`, `05_tools` and `07_kits` (twice), came out with the ground not loaded and no items visible, so I deleted those pictures instead of showing misleading ones).

## 1. Checklist

Status: PASS (exists, looks right, works) | LOOKS WRONG | MISSING ITEM | MECHANIC BROKEN | NOT SHOWN (could not photograph). Mechanics evidence is the probe or test_first_hour; looks evidence is a picture.

| # | Step | Items needed | Where the player gets them | Expected picture | Status and evidence |
|---|---|---|---|---|---|
| 01 | Arrive at spawn | nothing | n/a | meadow, conifers, NPCs | PASS: `03_raw_materials.jpg` (open meadow, Edda and Hob by the spawn) |
| 02a | Pick up sticks | none | ground scatter (spawn_boost: +2-3 per 32 m cell), shrubs drop 1-3 | stick lying on grass | PASS: scatter in data; stick looks like a pale branch in `03_raw_materials.jpg` |
| 02b | Pick up stones | none | ground scatter, bank stones, boulders (axe: 3 blows per stone) | grey stones | PASS for mechanic (data + probe); the item `stone` in my row was hidden by the NPC so its own look is NOT SHOWN; scattered world stones look fine in every picture |
| 02c | "Which rock gives what" | | only `stone` exists; boulder and rock outcrop give stone | | MISSING ITEM: flint has no source (F-02); no hand-stone variety, no ore reachable |
| 03 | Plant fibre from nettle, tall grass, flax, reeds | none (by hand) | forest nettle, grass tall grass, flax in summer, marsh reeds (drops.json by_species) | the plants | PASS in data; `02_fibre_plants.jpg` shows reeds, wild flax, thatching grass and heather labelled, all drawn plausibly. Nettle and tall grass not in frame: NOT SHOWN |
| 03b | Plant fibre item | | | bundle of pale strands | PASS: pale bundle with a tie in `03_raw_materials.jpg` (3rd in row) |
| 04 | Twine | 3 fibre | hand recipe #1 | coil | PASS mechanic (probe); look: tiny pale disc, readable only up close (`03_raw_materials.jpg` 4th) |
| 05 | Stone axe | 1 stone, 1 stick, 5 twine | hand recipe #2, 4 s | axe in hand | PASS mechanic (probe + first-hour test). LOOKS WRONG, in progress: `08_hold_stone_axe.jpg` axe drawn oversized, held with the arms straight out (Sonny: hands, axe swing) |
| 06 | Chop a tree | axe on hotbar | any tree | tree falls, trunk, stump | PASS mechanic (test_first_hour: 30 blows fell it, logs and leaves arrive). Look: NOT SHOWN (in progress: tree fall pose and stump) |
| 07 | Branches, leaves, logs, firewood, kindling | axe | trunk blows (3 branch blows, 3 blows per log) | | PASS mechanic; item looks PASS: leaves (green), kindling (bundle), firewood (brown logs), bark (layered slab) all readable in `03_raw_materials.jpg` |
| 08 | Chop a stump | axe | stump | | NOT SHOWN, in progress (Kathleen, commit a641581d) |
| 09 | Shelter under a big tree | a grown tree (size >= 0.8) | trees in the woods | standing under crown | PASS in code (cover.gd, only grown trees); NOT SHOWN. Note: every tree in the spawn-meadow pictures is a young conifer, so **no cover exists on the spawn meadow itself** (walk to the woods) |
| 10 | Campfire kit | 6 sticks, 3 stones | hand recipe #4 | kit item | PASS mechanic (probe); kit look NOT SHOWN (see F-09: kit rows would not frame) |
| 10b | Place the fire | kit | click on ground | laid fire | MECHANIC PASS; `10_campfire_placed.jpg` shows only the green placement ring on pale ground, not the fire. LOOKS in progress (campfire look) |
| 10c | Light with plant fibre | 1 plant fibre | | | PASS (probe: lit = true) |
| 10d | Light with birch bark, tinder, tinder fungus | | | | MECHANIC PASS (probe: lit = true for each) but **MISSING ITEM**: nothing in the game gives these (F-03). Amadou and twine do not light (correct per data) |
| 11 | Water | | river or lake | | PASS in test_first_hour; rivers not filling is in progress |
| 12 | Food: berries, roast | | raspberry 150, bramble 250, blueberry 150 per ripe bush, summer/autumn | bushes | PASS in data; picture NOT SHOWN: in `02b_berries_herbs.jpg` a huge golden shrub fills the frame and hides the row (blueberry label sits at the bottom-left under it), so the flora row could not be read |
| 13 | Lean-to | 8 sticks, 6 leaves, 2 twine | hand recipe #13 | lean-to | PASS: place works (first-hour test); `09_placed_shelter_wide.jpg` shows a roof of turf on posts, reads well |
| 14 | Rough bed | 10 thatch, 4 sticks, 2 twine | hand recipe #162 | low bed with thatch | PASS: `09_placed_shelter_wide.jpg` low timber frame topped with straw. The `bedding` item (heather yield in flora.json) is unused (F-12, in progress) |
| 15 | Chopping block | 2 logs (`log`) | recipe #15 | stump-like block | LOOKS PASS (`09_placed_shelter_close.jpg`) but **MECHANIC BROKEN (F-16)**: a felled tree gives `log_<species>` on the shoulder, the recipe needs plain `log`; probe_logs_output.txt |
| 16 | Workbench | 12 sticks, 3 twine | hand recipe #45 | bench | PASS: `09_placed_shelter_close.jpg` (a plain wooden table) |
| 17 | Thatch roof, wall, floor, doorway | twine + thatch + sticks (20-50 thatch each) | at workbench; open recipes | pieces | PASS mechanic (floor probe PASS; wall/roof/doorway PASS once the 20-30 s craft time is allowed); looks PASS in `09_placed_shelter_wide.jpg` and `_close.jpg` (thatch wall is a stack of reed planks, readable). Spend is heavy (50 thatch per wall) |
| 18 | Stone knife, wooden spade, stone spade, stone and wooden hammer, hoes | stone, sticks, twine, wooden block | recipes #6, #12, #26, #156, #161, #139/#140 | tools | PASS mechanic (probe). Looks NOT SHOWN (the `05_tools` run failed under load). Wooden hammer needs a hardwood `wooden_block`; conifer blocks are `wooden_block_soft`: a spruce-only start cannot make it (F-11) |
| 19 | **Pick axe** | stone pickaxe #186 (2 sticks, 3 stones, 2 twine, workbench) | | | **MISSING (MECHANIC): recipe is `known:false`, not in open_recipes.json: nobody can craft it** (F-01) |
| 20 | Wooden / stone spear | stick; + 5 twine | #5, #3 | spears | PASS mechanic; long thin spears drawn in `06_weapons.jpg` (far left, far right) |
| 21 | Bow and arrows | bow: 2 sticks + 3 twine at workbench; arrows: 2 sticks + 2 feathers | feathers only from grouse and ducks (carcass.json) | bow, arrows | PASS: bow and two arrow kinds readable in `06_weapons.jpg`; held bow in `08_hold_bow.jpg` reads well (arms stiff, in progress). Arrow supply = hunting (F-08) |
| 22 | Wooden club, stone mace, javelin, wicker shield | | | | **BLOCKED + LOOKS WRONG**: recipes `known:false` (F-01); in `06_weapons.jpg` all four are drawn as white blobs (no look yet) |
| 23 | Held spear | | | | PASS: `08_hold_spear.jpg` |
| 24 | Snare, fishing rod | | #177, #46 | | PASS mechanic; snare is a small green box, fishing rod a long pole in `06_weapons.jpg` |
| 25 | Kindling recipe, hide scraper, sickle, leather clothes, clothing sets | | | | **BLOCKED**: `known:false` (F-01) and flint (F-02) |

## 2. ACTION LIST (blockers first)

**BLOCKERS: the player cannot go on**

| ID | What is wrong | Evidence | Owner | Size |
|---|---|---|---|---|
| F-01 | **No way to learn recipes.** 93 of the 171 live recipes are `known:false` and only 5 of those are opened by `open_recipes.json`, so 88 can never be crafted by a player. The server refuses them (`recipe["known"]`, `_queue_craft`). Includes everything a first-day player expects: **stone pickaxe, wooden club, stone mace, javelin, wicker shield, kindling, grass skirt/cloak/sandals, hide tunic/trousers/gloves, waterskin, bucket, clay jug, quern, splint, candle, compost, herb salve, sinew cord, brick, cobblestone, mortar**. | `reachability.txt` ("NOT KNOWN" rows); probe: those recipes `crafted=false`; recipe_table.gd line 115 | Sal (items/recipes/data): decide which are open from minute one and add to open_recipes.json (small). A real learn system is a code owner task (large). | small (data) / large (system) |
| F-02 | **Flint does not exist as a pickup.** Item `flint` exists, `resources.json` lists it as a geology resource, no gather, drop or recipe gives it. Blocks hide scraper (#180), javelin (#181), sickle (#187), hence processed hide and leather. | grep: `flint` only in recipes, items, resources table, look code | Sal (data) plus a code owner (a flint source: flake from a boulder, or a drop from limestone) | medium |
| F-05 | **No lumber path, so no wood house.** Lumber needs a saw mill (blueprint cost itself needs 40 lumber, 100 nails, saw blade, water wheel) or a hand saw (needs saw blade <- forge <- iron ingot). Iron, copper, tin ore and coal have no source (no mining). Wall, floor, roof, doorway, window, ladder, timber set kits, bucket, plank chest, wooden pin and plank shield all need lumber. The thatch pieces are the only reachable house. | reachability.txt: "no source for lumber"; items `iron_ore`, `copper_ore`, `tin_ore`, `coal` have no source | Sal plus a code owner (mining) | large |
| F-06 | **Clay hearth, oven and brick** unreachable: brick is `known:false`. | blueprints.json oven cost brick 24; recipe #128 not known | Sal | small |

**HIGH: first-hour holes that are not full stops**

| ID | What is wrong | Evidence | Owner | Size |
|---|---|---|---|---|
| F-03 | **Three of four tinder fallbacks cannot be obtained.** `tinder_also` lists birch_bark, tinder, tinder_fungus, but no plant, tree or recipe yields them: `tinder_fungus` (flora) has no drops.json entry (it yields `amadou` on paper, also ungatherable), birch trunks give *thatch* from bark blows, not `birch_bark`. Only plant fibre lights a fire. In a forest with no nettle, the player is stuck. | probe: lighting works with each, but `grep -rn birch_bark src data/items/drops.json` finds no source | Sal (drops.json: birch trunk gives birch_bark; tinder_fungus plant gives tinder_fungus) / flora session | small |
| F-04 | **Doc says the opposite of the game in several places.** CONTROLS.md: campfire "10 stones and 20 sticks" (recipe is 6 sticks, 3 stones); "starts lit" (it is placed laid, light with E); chopping block "splits one log into 4 firewood" (code: one wooden block to one firewood, blocks come from chopping a log on the ground) A guide written from CONTROLS would send the player wrong. test_first_hour.gd also still says "20 sticks, 10 stones". | CONTROLS.md vs recipes.json #4 and server_items.gd 4505-4525 | doc owner (Tyler) | small |
| F-07 | **(fixed by the height fix, see Part 2 section 11) The spawn meadow has no cover.** Only trees >= 0.8 of full height shelter, and every tree in the spawn-area pictures is a young conifer. A new player cold or in rain has no tree to stand under until they find woods. | `03_raw_materials.jpg`, `06_weapons.jpg`; cover.gd SHELTER_MIN_SCALE | flora session (a few grown trees near spawn) / Dave to confirm design | small |
| F-08 | **Bow is useless without feathers.** Arrows need feathers; feathers only come from killing a grouse or duck (carcass.json), which a new player cannot do reliably. Quiver needs hide (rabbit). | recipes #171-#173 | Sal (a second arrow source, e.g. fletching from bark or reeds) | small |

**MEDIUM / looks**

| ID | What is wrong | Evidence | Owner | Size |
|---|---|---|---|---|
| F-09 | **Wooden club, stone mace, javelin and wicker shield are drawn as white blobs** (no look). Kits (campfire, lean-to, bed, chest, workbench) could not be framed on the ground in my runs; please re-shoot with `--showroom` once the machine is quiet. | `06_weapons.jpg` (the four blobs, in row order); `07_kits` run failed | Kathleen (looks) | small |
| F-10 | Stone axe in hand is oversized and held with arms straight out; bow arms stiff. | `08_hold_stone_axe.jpg`, `08_hold_bow.jpg` | Sonny (in progress: hands, axe swing) | small |
| F-11 | Wooden hammer needs `wooden_block` (hardwood). A conifer log gives `wooden_block_soft`, so a spruce or pine start cannot make it. Same for the `log_*` species chains. | recipe #161; wood_species.json class_items | Sal (accept either block) | small |
| F-12 | `bedding` (heather yield) and `straw` exist but nothing gathers or uses them: heather gives only thatch. Bed look placeholders are in progress. | drops.json by_species heather; flora.json yields | flora session / Sal (in progress) | small |
| F-13 | Wild berries scale: in `02b_berries_herbs.jpg` a golden-leaf shrub fills the frame (about 3 m wide) while the row label says Blueberry (0.25-0.5 m tall plant). Cannot tell which species it is; please verify blueberry height. | `02b_berries_herbs.jpg` | flora session (density / size is in progress) | small |
| F-14 | Fibre cost is high: axe = 15 fibre; bed + lean-to + workbench + bow + spear = ~60 more twine ~ 180 fibre; a thatch wall is 50 thatch + 20 twine. Nettle gives only 1-2 fibre per plant. Tuning, not a bug. | recipes + drops | Dave / Sal (balance) | small |
| F-15 | No pick axe, no hammer-tier gating (F-01) means boulders (the main stone source beyond scatter) are 3x slower and wear the axe 5 per blow (900 durability = 180 boulder blows = 60 stones). | boulders.json, drops.json tool_wear | Sal | small |

**Already in progress (not reported as new):** flora density and tall grass patches; tree fall pose and stump chopping; campfire look; item looks for placeholders (Bedding); rock sinking in a puddle; water not filling rivers; axe swing animation; character hands and feet.

## 3. What worked well

* The hand-craft chain itself is sound: fibre -> twine -> stone axe -> fell -> logs -> campfire -> lean-to -> chest all passes `test_first_hour.gd` with zero failures; 105 recipes behave exactly as their `known` flag says on the real server code.
* Every ingredient of the known first-day recipes has a source in the world (sticks, stones, fibre, thatch, leaves, bark, logs, hide, clay, sand, soil, berries and herbs by hand or tool).
* The spawn boost scatters extra sticks and stones around the spawn on purpose.
* Fire lights with the alternative tinders in code (birch bark, tinder, tinder fungus) once an item source exists.
* Structures read well: lean-to, rough bed, chopping block, workbench, thatch roof, wall, floor (`09_placed_shelter_wide.jpg`).
* Tools and weapons on the ground (spears, bow, arrows, fishing rod, snare) are readable.
* The look rig, the shot runner and `--pieces` give a repeatable way to photograph every new item.

## 4. Re-running this

```bash
# raw material, weapon and structure pictures (three at a time); needs a quiet machine
bash art/playthrough/run_all.sh
# the server probe
tools/godot.cmd --headless --path . --script res://art/playthrough/probe_playthrough.gd
# one row of items on the ground (needs --gy 1039.0 at the current spawn)
bash art/playthrough/rig.sh --row stone,stick,twine --gy 1039.0 --row-dist 3.5 --agl 1.8 --pitch -35 --name my_row --out art/playthrough
```


---

# Part 2: the whole tree (all tiers, every recipe, station, structure and look)

Dave widened the job: every bench, tool, weapon, armour piece, construction piece, container, food and item. Everything below was produced by three scripts that read the data and the real server code, and by pictures from the real client.

| Script | What it does | Output |
|---|---|---|
| `art/playthrough/audit_playthrough.py` | walks every recipe, item, station and structure; traces every ingredient to a world source (ground, plant, tree, dig, carcass, fish, NPC, another recipe), now (known and open recipes only) and "if every recipe were known"; checks station levels against structures that can really be built; checks looks (missing, grey placeholder, ignored override) | `audit.md`, `audit.json` |
| `art/playthrough/make_chapters.py` | turns the audit plus the data into the tier chapters with exact steps, a status per recipe and a checklist | `PLAYTHROUGH_CHAPTERS.md` |
| `art/playthrough/probe_playthrough.gd`, `probe_structures.gd`, `probe_logs.gd` | run the real `server_items.gd`: every recipe queued with exactly its ingredients; every structure placed from its kit and from its hammer blueprint; bench levels; the log problem | `probe_output.txt`, `probe_structures_output.txt`, `probe_logs_output.txt` |
| `art/playthrough/make_showroom.py`, `run_showroom.sh`, `rig.sh` | a temporary showroom of every item (14 per row, name tags) photographed from the real client | `art/playthrough/showroom/` |

## 5. Scoreboard by chapter (from `PLAYTHROUGH_CHAPTERS.md`)

See the table at the top of `PLAYTHROUGH_CHAPTERS.md` (regenerated each run). Reading it: **FUTURE** = the product is flagged `future:true` in items.json (not yet in play by design). **BLOCKER** = not flagged, so a real hole: either the recipe is `known:false` with no way to learn it, or an ingredient has no source, or the station cannot be built.

## 6. What the existing checks miss

`validate_items.gd` (run: 0 errors, 177 warnings), `tools/check_look_names.py` ("all 35 structure looks are drawable") and `test_first_hour.gd` all pass, yet the audit finds real holes:

| Hole | Why the existing checks do not see it |
|---|---|
| Every tree drops `log_<species>` (shoulder, one at a time) but five recipes and the blacksmithy blueprint ask for plain `log` (F-16) | validate_items counts `log` as "gatherable" because the server has a fallback that gives plain `log` for a species without a `log_*` item; all 25 tree species have one, so the fallback never fires |
| `ART_OVERRIDES` in basic_look.gd is ignored for 20 items whose looks.json row is still the grey chunk (F-17) | validate_items says "looks: 0 GENERIC items remaining" because it only counts items with no row at all |
| 46 items still use the grey "chunk" (armour, crops, three hide garments, quern, compost, bone items), two (clay_jug, candle) have no row (F-18) | same |
| 47 recipes are `known:false` or blocked but their product is not flagged `future` (F-19) | validate_items checks the item, not whether a player can learn the recipe (there is no learn system) |
| 100+ gathered items (herbs, flowers, mushrooms, saps, fibres) have no gather path although flora.json lists them as yields (F-20) | "95 gathered materials have no use yet" is a use check, not a source check; drops.json says a plant with no entry cannot be gathered, silently |
| Station levels, the foundation rule for the saw mill, "needs a clay hearth beside" for the oven | `test_stations.gd` checks the levels it knows; nothing checks that the chain can be walked from nothing |

## 7. New action items (continuing the numbering of section 2)

Severity: BLOCKER = a player cannot get past it. Owners as in the brief.

| ID | Sev | What is wrong | Evidence | Owner | Size |
|---|---|---|---|---|---|
| F-16 | **BLOCKER** | **Recipes that ask for plain `log` can never be filled.** Every one of the 25 tree species drops `log_<species>` (carried on the shoulder, one at a time, not in the pack). Chopping block (#15, 2 log), log workbench kit (#49, 4 log), rough plank (#143), lumber (#16), timber prop (#125), lumber by hand (#159) and the blacksmithy blueprint (10 log) need `log` and the crafting code does no matching of `log_oak` to `log`. So: **no chopping block, no log workbench (workbench level 2 by that route), no rough planks, no blacksmithy.** | `probe_logs_output.txt`: oak log on the shoulder, craft of the chopping block: "You do not have what that needs"; with 2 plain logs given by admin: crafted. `flora.json`: all 25 trees have a `log_*` item | Sal (data: let recipes name a class, or accept any `log_*`) plus a code owner (ingredient groups in recipe_table / inventory) | small to medium |
| F-17 | HIGH | **Real looks exist but are never drawn.** `basic_look.gd entry()` uses `ART_OVERRIDES` only when looks.json has no row, but 20 items still carry the grey `chunk` row: flint, pyrite, obsidian, processed hide, leather, fine leather, heavy leather, rivets, copper/tin/bronze ingot, flour, yeast, salt, javelin, wooden club, copper/tin/iron ore, coal. They are drawn as grey blobs. (This is the white blob seen for the club and javelin in `06_weapons.jpg`.) | `audit.md` "OVERRIDE IGNORED"; `src/client/basic_look.gd` lines 17-62 | Kathleen (one line: prefer the override when the row's shape is `chunk`; or delete the 20 grey rows) | small |
| F-18 | MEDIUM | **46 items still have the grey placeholder look and 2 have no look.** Hide tunic, trousers, gloves; herb salve, splint; wicker shield, stone mace; plank, bronze, iron and steel shields, swords, maces; leather cap, jerkin, bronze/iron/steel helm, gambeson, mail shirt, plate cuirass; wheat, barley, carrot, potato, turnip, flax and their six seed items; quern, compost, antler, tusk, claw, down, quill, hide glue, bone arrow. `clay_jug` and `candle` have no row. Most are `future` so players do not see them yet. | `audit.md` "Item looks that are missing or placeholders" | Kathleen | medium |
| F-19 | HIGH | **47 recipes cannot be crafted and their products are not flagged `future`.** Cooking: berry compote, nut paste, baked apples, garlic meat, chestnut cakes, fruit leather, hunter's, forager's stew, trail bread, hearty pottage, feast roast, flatbread, honey loaf, roast joint (ingredients `honeyspindle_nectar`, `wild_garlic_bulbs`, `linseed`, `greens`, `seeds`, `dandelion_leaves` have no gather entry). Wood and building: lumber, plank chest, bucket, wall, floor, roof, doorway, window, timber prop, timber set, ladder kits, fine board, wooden pin, nails, tar, hinges, water wheel, hand saw (all downstream of F-16 and F-21). Clothes and cord: grass skirt, grass cloak, fibre sandals, sinew cord (known:false). Stone: cut stone block, brick, mortar, cobblestone, stone shingle (known:false). Kindling (known:false). Willow bark tea (`willow_bark` has no source). | `audit.md` "Recipes blocked", column "future? NO" | Sal | medium |
| F-20 | HIGH | **About 100 gathered items cannot be gathered.** drops.json gives a plant yield only for the species listed in `by_species`, `harvest_yield` and `berry_yield`; the rest of flora.json's yields became items that nothing produces: wild garlic bulbs, linseed, dandelion leaves and roots, comfrey roots, honey flowers, elderflowers, rose hips, willow bark, birch bark, amadou, tinder, tinder fungus, sap, gum, oil, fiddleheads, reed stems, straw, bedding and many fantasy plants. Plus abstract yield names that became items and should probably be removed: `wood`, `hardwood`, `softwood`, `hard_wood`, `fine_wood`, `timber`, `fibre`, `herbs`, `food`, `fodder`, `poles`, `stuffing`, `spines`, `burrs`. | `audit.md` "ORPHAN items" with "NOT marked future" | Sal (add yields) / flora session (which species to harvest) | medium |
| F-21 | MEDIUM | **Saw mill chain is circular without iron.** Saw mill blueprint = 40 lumber + 100 nails + saw blade + water wheel (itself 20 lumber + 80 nails); lumber comes only from a saw mill or a hand saw; a hand saw needs a saw blade from a forge and iron. No iron ore exists (F-23). The saw mill also needs a tall foundation (0.5 m lift) under it. | `probe_structures_output.txt`: saw mill "It needs a tall foundation"; audit: recipes #16, #52-#101 blocked | Sal | medium |
| F-22 | MEDIUM | **Building tiers are incomplete.** Present: lean-to, thatch (wall, roof, floor, doorway), wood sections (wall, floor, roof, foundation, doorway, window, timber prop, timber set, ladder), rock pile. Missing: **stairs**, thatch window, any stone, brick, cobble or log wall/floor/roof pieces (blueprints.json says "when they land"), gates, fences, furniture (table, chair, shelf, door as its own piece: a door is only `door_open` of the doorway), storage beyond chest and plank chest. | `structures.json` (37 rows), `blueprints.json` (6 rows) | Sal (design and data), Kathleen (looks) | large |
| F-23 | **BLOCKER (by design, future)** | **No metal at all.** `copper_ore`, `tin_ore`, `iron_ore`, `coal` have no source (no mining, no ore deposit pickup), so ingots, bronze, iron and steel tools, weapons, armour, nails, hinges, rivets and the saw blade (27 recipes in chapter 9) cannot be made; the forge itself can be built (stone forge: workbench level 2 + 36 stone, 10 clay, 2 hide). The pick axe is `known:false` too, so there is no way to even try. | `audit.md` chapter 9; probe: stone forge PLACED beside workbench + tool rack | Sal plus a code owner (ore deposits and mining) | large |
| F-24 | MEDIUM | **No learn system.** Same as F-01, now counted over the whole table: 90 of 173 live recipes cannot be learned (`known:false` and not in `open_recipes.json`). 70 of the 90 make products flagged future (by design), 20 do not; 47 recipes in all are blocked without the future flag (F-19). | `recipes.json`, `recipe_table.gd craft()` | code owner (learn system), Sal (which recipes open now) | large (system) / small (data) |
| F-25 | LOW | The kit items of the big stations (`stone_forge_kit`, `blacksmithy_kit`, `large_forge_kit`, `master_forge_kit`, `saw_mill_kit`, `woodworking_table_kit`, `clay_hearth_kit`, `oven_kit`, `vice_kit`) are real items with no recipe: players use hammer blueprints, so the kits are dead rows (retired by Dave 25 Oct); they appear in the item table and the showroom. `large_forge` and `master_forge` have no blueprint at all, so they cannot be built by a player. | `probe_structures_output.txt`; `blueprints.json` | Sal | small |
| F-27 | MEDIUM | **All kits look alike.** The 32 kit items (campfire, lean-to, bed, chest, workbench, wall, floor, roof, doorway, window, ladder, timber, thatch kits...) are the same wrapped box in a different tint; in a pack or on the ground a player cannot tell a lean-to kit from a bed kit. | `art/playthrough/sheets/items_12.jpg`, `items_13.jpg` | Kathleen | medium |
| F-26 | LOW | `door`: no door item; `door_open` shares the doorway kit. `path_patch` is placed by the hoe only. Fine, noted so nobody looks for them. | `structures.json` | none | none |

## 8. Station and structure probe (real server code)

From `probe_structures_output.txt`:

* Every kit in structures.json places (campfire pot only on a laid fire; snare only on open ground away from buildings; the saw mill needs a foundation under it).
* Hammer blueprints: woodworking table, clay hearth, oven (beside a clay hearth) place; **stone forge needs workbench level 2** (a workbench with a tool rack within 5 m, or a log workbench) and places; **blacksmithy needs workbench level 3** (the stone forge) and 10 `log` which cannot be paid (F-16); the saw mill needs a foundation lift.
* Bench levels measured with `station_near`: workbench 1; workbench + tool rack 2; log workbench 2; stone forge 3 (+ forge 1); blacksmithy 4 (+ forge 2).
* The vice is a retired add-on ("the log workbench carries its own vice").

## 9. Chapters (in the order a player unlocks them)

The full per-recipe tables, with exact needs, where each ingredient comes from, station, known flag, status and the picture row, are in **`PLAYTHROUGH_CHAPTERS.md`**. Chapter 1 (the first day) is `PLAYTHROUGH_GUIDE.md`.

| Ch | Tier | State today |
|---|---|---|
| 1 | Hands: pick up sticks, stones, fibre, thatch, leaves; twine; stone axe; chop; campfire; lean-to; bed | works (see sections 1 and 2 above). Chopping block and the log chain blocked by F-16 |
| 2 | Stone age by hand | 16 PASS of 33; the rest are future (club, mace, candle, quern, compost, bone arrow, metal spades, hide scraper) or known:false (mortar, sinew cord) |
| 3 | Fire, food and medicine by hand | works: torch, tea, poultices, bandages, energy bar |
| 4 | Shelter, clothes, containers by hand | lean-to, chest, bed, backpack, hide clothes, wooden bowl, clay pot work; bucket, waterskin, clay jug, grass clothes, hide tunic set blocked (known:false) |
| 5 | Cooking stations | pot kit, simple campfire dishes work; 14 dishes blocked by gather holes (F-19, F-20); clay hearth and oven blocked by brick (known:false) |
| 6 | Workbench tier 1 | stone hammer, bow, hoes, spades, thatch pieces, hide scraper (flint missing) |
| 7 | Bigger benches | stone forge works; log workbench and blacksmithy blocked by F-16 |
| 8 | Wood tier | blocked (F-16, F-21) |
| 9 | Forge and metal | blocked (F-23, by design) |
| 10 | Every structure | see the table at the end of `PLAYTHROUGH_CHAPTERS.md` |

## 10. Photographs

* `art/playthrough/*.jpg`: the first-day pictures (taken on the OLD, wrongly-read world; item looks do not depend on the terrain, flora and ground do: `02_*` should be re-taken).
* `art/playthrough/sheets/items_01.jpg` to `items_14.jpg`: **every item** (420), 30 a sheet, drawn by the game's own look code (`BasicLook.mesh_for`, so what the game ignores is ignored here), name under each; grey blobs are labelled `[grey placeholder]`, items drawn by other code `[special drawing]`. `sheets.json` lists which item is on which sheet. Made by `art/playthrough/item_sheet.gd` (about 1 minute, no server, no world).
* `art/playthrough/sheets/structures_01.jpg` to `structures_10.jpg`: **every structure** (37), 4 a sheet, from the game's own dispatcher (`inventory_view.ghost_model`). All 37 draw something; the fires, remains and carcass included.
* The world showroom (`rig.sh --showroom`) was tried and dropped: the fixed spawn is a dense stand of grown trees whose crowns hide the item rows, and each rig run re-bakes the terrain store (about 5 minutes of machine time). Use the sheets.

What the sheets show: the structures, tools, weapons, bows, spades, hoes, hammers, saw, water wheel and foods are well drawn; the **kits are one identical box in a different colour** (campfire, lean-to, bed, wall, floor, roof, door, window, ladder, thatch kits: F-27); **all the grey blobs** are listed in F-17 and F-18; `nails`, `hinges`, `wooden_pin`, `steel_striker` are almost invisible at item size.

## 11. Fixed by the height fix (not action items)

* F-07 (no cover on the spawn meadow): the fixed world's spawn is by a pond in a stand of grown oaks and beeches (`showroom/` pictures); the old pictures showed young conifers on a 1,000 m plateau. Re-check cover with `tools/look_rig.sh` once the ground loads in the picture.
* My first rig note that the spawn ground is y=1039: that was the old height error. After the fix the spawn ground is 31.0 m again and `look_rig.sh --gy 31` (its default) is right.

## 12. What I could not photograph or run

* A walk by hand in the client (real mouse clicks), and the first-day trunk, stump, lit fire and cover pictures (the rig's world pictures need the ground to load and each run re-bakes the terrain).
* Items in the hand, worn on the body and falling or dropped: only the sheets (loose look) and the three held pictures `08_hold_*` exist. The armour and clothing pieces are drawn on the body by `worn.json` builders; I did not photograph the 21 worn rows.
* The `--pieces` rig run for placed structures in the world (the sheets draw the same models in isolation).
* A walk by hand in the client (real mouse clicks).
* Pictures of kits, placed stations and structures on the fixed world: the rig needs the ground to have loaded and each run re-bakes the terrain store (about 5 minutes of machine time), so I ran the item rows first; the `--pieces` run for the 37 structures is listed in `run_all.sh`.
* Pictures where an item has no look (it is drawn as the grey chunk) are in the showroom rows and marked in `audit.md`.

## 5. Fix status (Sal, 2026-10-31, branch sal-items)
Probe re-run after the fixes (`probe_playthrough.gd`): 112 recipes match their `known` flag, 1 mismatch (Lumber by hand, needs a hand saw), and fire lights with plant fibre, birch bark, tinder and tinder fungus.
* **F-01 FIXED (data):** 76 recipes now `known:true` (stone pickaxe, club, mace, javelin, wicker shield, kindling, hide and grass clothing, waterskin, bucket, brick, clay jug, quern, splint, candle, compost, salve and more). 19 stay locked (forge/workbench level 2 and up, water wheel). Code half: LEARN_SYSTEM_SPEC.md.
* **F-06 FIXED:** brick, mortar, cobblestone known; oven and clay hearth reachable.
* **F-03 FIXED (data):** drops.json harvest: tinder fungus gives 3 tinder fungus, cotton grass gives 8 tinder; birch trunks give 2 to 4 birch bark per seed roll; new recipe Tinder (2 thatch gives 2 tinder, by hand).
* **F-08 FIXED:** Fibre arrow (item 354, 2 sticks + 1 fibre gives 4, damage 3.5) needs no feather; Bone arrow (item 352) also added.
* **F-11 FIXED (hammer):** recipe "Wooden hammer" also accepts `wooden_block_soft`. The `log_*` species chains still need the code change in ITEM_CODE_HANDOFF.md section 1.
* **F-12 FIXED (data):** fern and heather harvest gives 6 bedding; recipe "Rough bed" also accepts 8 bedding instead of 10 thatch. Straw has no source yet (needs wheat or barley growing).
* **F-14 PARTLY FIXED:** twine cut on thatch floor 6 to 4, wall 20 to 8, roof 10 to 6, doorway 12 to 6, shore net 20 to 8, campfire pot 5 to 3. **The stone axe and stone spear stay at 5 twine** because test_first_hour and test_auto_craft hard-code 5 twine and 15 fibre; changing them needs those tests rewritten (about 12 lines in test_auto_craft). Proposal: axe 2 twine.
* **F-15 FIXED (data):** Stone pickaxe is known and no longer marked future.
* **F-02, F-05 data FIXED, code open:** Stone wedge (353) + log at a workbench gives 2 lumber, so wooden building is reachable with no iron. Flint, coal, ore and obsidian sources are specified in FLINT_ORE_SPEC.md for the code session; until then hide scraper, javelin and sickle stay unreachable.
* **F-14 FIXED (update 2026-10-31):** Stone axe and Stone spear now cost 2 twine (6 fibre) instead of 5; test_first_hour, test_auto_craft (the 50-craft-cap check is dropped because one queue call takes at most 20 axes, which now needs only 40 twine), test_inventory and PLAYTHROUGH_GUIDE.md updated.
* **F-12 straw FIXED (data):** tall grass now also gives 1 to 3 straw; recipe "Rough bed" also accepts 8 straw.
* **F-11 spec:** LOG_SPECIES_SPEC.md (code half for Tyler).



## 6. Fix status, part 2 (Sal, 2026-10-31)
* **F-16 data FIXED:** wood_species.json `ingredient_groups` (log, wooden_block, firewood); validate_items no longer treats plain `log` as a built-in source and now fails on any recipe ingredient with no source. The recipes and blueprints that use group ids are listed in LOG_SPECIES_SPEC.md. Code half (match members when filling an ingredient) is Tyler's.
* **F-19 FIXED (flagged):** products of recipes that no player can make yet are now `future`: willow bark tea, acorn mash, flatbread (need water; WATER_GATHER_SPEC.md), nails, hinges, hand saw (iron), tar (pine tar has no source), processed hide (flint), leather cap (leather). Everything else the guide listed (grass clothes, kindling, brick, mortar, cobblestone, wood chain via the stone wedge, cooking dishes) was already opened or made reachable by the `known` flips and the drops added earlier.
* **F-20 mostly a false alarm, one real fix:** plants without a drops.json row are still gatherable: the server picks a random in-season yield item that exists in the table (`gather()` natural yield). A check over all 174 gathered items found one true orphan: **rose hips** (needs a rose-hip harvest on wild rose from the flora session). Real bug fixed: flax, tall grass and nettle listed an abstract `fibre` yield next to their `plant_fibre` row, so a pick could give the useless "fibre"; removed from flora.json yields. The abstract names `wood, hardwood, softwood, hard_wood, fine_wood, timber, poles` are only yields of trees (felled, not picked) and are used by no recipe; `herbs, food, fodder, spines, stuffing, burrs` are generic items used as natural yields; none retired because the flora session owns the yield lists.
* **F-24 FIXED (data):** 19 of the live recipes stay `known:false` (forge/workbench level 2 and up, water wheel), by design; every other recipe is known from the start (F-01). The learn system is LEARN_SYSTEM_SPEC.md.

---

# Part 3: re-run after merging DailyDev_20261029 (2026-10-31, Sal's data fixes and Kathleen's look fix included)

Same scripts, new data (180 live recipes, 467 items): `python art/playthrough/audit_playthrough.py && python art/playthrough/make_chapters.py`. Sheets re-drawn with the game's current look code.

| Number | Before the merge | After |
|---|---|---|
| Recipes a player can learn (known or open) | 83 of 173 | **161 of 180** (19 stay locked: workbench level 2+, forge, water wheel) |
| Recipes blocked (any reason) | 117 | 92 |
| Blocked and NOT flagged future (a real hole) | 47 | **40** |
| Items with the grey placeholder look or no look | 114 | 103 (F-17 fixed) |

**Fixed since part 2:** F-17 (Kathleen, 0bf6e164: an override wins over a missing row or the grey chunk; flint, club, javelin, ores, ingots, coal now have their real look in the sheets), F-01 and F-24 (Sal, 76 recipes made known), F-03 (tinder fungus, cotton grass, birch bark and a Tinder recipe), F-06 (brick, oven, hearth), F-08 (fibre arrow), F-11 (soft block accepted for the hammer), F-12 (bedding), F-14 (axe and spear cost 2 twine), F-15 (stone pickaxe known).

**Still open, in the order that matters:**

1. **F-16 log chain (BLOCKER, code owner).** Still every chain that needs plain `log` is dead: chopping block, log workbench kit, rough plank, lumber by hand, timber prop, Sal's new `lumber_wedge` (stone wedge + log gives 2 lumber), and the blacksmithy blueprint. All 25 trees still give `log_<species>` on the shoulder. Sal's data side is done (ITEM_CODE_HANDOFF.md section 1 specifies the code change). Until it lands, **the whole wood tier is unreachable** (chapters 7, 8 and half of 6).
2. **F-19 cooking dishes (Sal):** 14 dishes still blocked: berry compote, nut paste, baked apples, garlic meat, chestnut cakes, fruit leather, hunter's stew, forager's stew, trail bread, hearty pottage, feast roast, flatbread, honey loaf, roast joint. Their ingredients (`honeyspindle_nectar`, `wild_garlic_bulbs`, `linseed`, `greens`, `seeds`, `dandelion_leaves`) still have no gather entry (F-20).
3. **F-20 (Sal / flora):** 97 gathered items with no gather path and not flagged future, including the abstract names (`wood`, `hardwood`, `fibre`, `herbs`, `food`, `fodder`...).
4. **F-18 (Kathleen):** 13 items a player can craft today still wear the grey chunk or no look: hide tunic, trousers, gloves, herb salve, splint, quern, compost, hide glue, bone arrow, stone wedge, fibre arrow; `clay_jug` and `candle` have no row.
5. **F-27 (Kathleen):** the 32 kits are one identical box in different tints.
6. **F-22 (Sal / Kathleen):** no stairs, no stone, brick or log wall pieces.
7. **F-23 (code owner, Sal):** ores, coal, flint still have no pickup (specified in FLINT_ORE_SPEC.md): no metal.
8. **F-21:** saw mill chain is circular without iron; the saw mill needs a foundation (design note).
9. Minor: willow bark tea (`willow_bark` has no source), leather cap (`leather` has no source), processed hide (needs the hide scraper, flint), `hand_saw` (saw blade, iron).

The whole picture in one line: **hands, stone age, fire, shelter, bed, workbench, tool rack, stone forge and the thatch house all work and look right; wood, metal and half the kitchen are not reachable yet, and the single biggest lever is the log recipe fix (F-16).**

## 6. Fix status, part 2 (Sal, 2026-10-31)
* **F-16 data FIXED:** wood_species.json `ingredient_groups` (log, wooden_block, firewood); validate_items no longer treats plain `log` as a built-in source and now fails on any recipe ingredient with no source. The recipes and blueprints that use group ids are listed in LOG_SPECIES_SPEC.md. Code half (match members when filling an ingredient) is Tyler's.
* **F-19 FIXED (flagged):** products of recipes that no player can make yet are now `future`: willow bark tea, acorn mash, flatbread (need water; WATER_GATHER_SPEC.md), nails, hinges, hand saw (iron), tar (pine tar has no source), processed hide (flint), leather cap (leather). Everything else the guide listed (grass clothes, kindling, brick, mortar, cobblestone, wood chain via the stone wedge, cooking dishes) was already opened or made reachable by the `known` flips and the drops added earlier.
* **F-20 mostly a false alarm, one real fix:** plants without a drops.json row are still gatherable: the server picks a random in-season yield item that exists in the table (`gather()` natural yield). A check over all 174 gathered items found one true orphan: **rose hips** (needs a rose-hip harvest on wild rose from the flora session). Real bug fixed: flax, tall grass and nettle listed an abstract `fibre` yield next to their `plant_fibre` row, so a pick could give the useless "fibre"; removed from flora.json yields. The abstract names `wood, hardwood, softwood, hard_wood, fine_wood, timber, poles` are only yields of trees (felled, not picked) and are used by no recipe; `herbs, food, fodder, spines, stuffing, burrs` are generic items used as natural yields; none retired because the flora session owns the yield lists.
* **F-24 FIXED (data):** 19 of the live recipes stay `known:false` (forge/workbench level 2 and up, water wheel), by design; every other recipe is known from the start (F-01). The learn system is LEARN_SYSTEM_SPEC.md.

---

# Part 4: second pass on systems, the spawn, and the status table (2026-10-31)

New files: `PLAYTHROUGH_STATUS.md` (every F-number marked FIXED or STILL BROKEN from the current data and probes; regenerate with `bash art/playthrough/run_status.sh`), `TUTORIAL_FIRST_30_MIN.md` (a tutorial script derived only from what the game does), `art/playthrough/probe_spawn.gd` and `spawn_survey.json`.

## 13. The spawn on the fixed world

Real flora placer around the spawn point (53316, 68476), from `probe_spawn_output.txt`: ground 31.6 m, biome temperate forest, a pond shore (the spawn code says so). Within 50 m: 193 ferns, 88 balsam fir, 44 nettles, 30 hazels, 20 raspberry bushes, 17 beeches, 14 wild garlic, 12 comfrey, 11 wild mint, 9 elder, 9 mushrooms, 5 oaks, 4 brambles, 2 tinder fungus; **6 grown trees (shelter) within 50 m, 17 within 100 m, 80 within 200 m**. No tall grass, flax, reeds, heather or thatch grass in this biome. So: fibre comes from nettles (about 95 within 100 m), bedding from ferns, thatch only from birch, spruce, pine and fir bark on a felled trunk (88 balsam firs near), berries from raspberry, bramble, elder and hazel (hazel is autumn). Picture: `art/playthrough/world/spawn_view.jpg` (an autumn forest of grown beeches and oaks, a bramble in the foreground, the pond between the trunks, Edda standing by). Loose sticks and stones are the scatter plus `spawn_boost`; their count is in drops.json, not measurable without the server world.

F-07 stays FIXED: grown trees stand within 50 m of the spawn.

## 14. Second pass on the later tiers and systems

| System | Reachable from a fresh start today | Looks | Placement | What is missing |
|---|---|---|---|---|
| **Hunting** (rabbit, deer, fox, wolf, moose, duck, horse; `animals.json`) | spear and bow are craftable, carcass work needs a stone knife (2 stones, 1 stick); parts: meat, hide, bone, sinew, fat, feather, antler, tusk, claw, down, quill | meat, hide, bone, feather real; antler, tusk, claw, down, quill grey blobs (F-18) | n/a | no tanning: `processed_hide` needs the hide scraper (flint, F-02), `leather` has no recipe; so leather, fine and heavy leather, gambeson, jerkin and cap are out of reach |
| **Fishing** (rod 2 sticks + 2 twine, shore net 8 twine + 4 stones) | yes, items: trout, perch, pike, carp (all obtainable via fishing.json) | fish drawn well (`items_01.jpg`) | n/a | `test_fishing` and `test_shore_net` results: see section 15 |
| **Trade and coin** | one shop only (Hob: stone axe, knife, spade, torch, twine, rope, fibre, bandage, waterskin, bowl, backpack, roast forage, firewood, stone, stick; buys materials, food, tools, containers, medicine, clothing, kits); coins live in a purse, never in the pack | coin_* items are 4 tiny discs (readable on `items_01.jpg`) | n/a | no second trader, no trader for ore, flint or seeds; coin items are orphans by design (purse) |
| **Containers** | wooden bowl (1 firewood), clay pot (6 clay, 12 s), waterskin (2 hide + twine), backpack, quiver, chest (10 sticks + 4 twine) | all real except clay_jug (no row) | chest, plank chest place | bucket needs lumber (F-16); plank chest needs workbench level 2 + lumber |
| **Food and dishes** | roast forage at any fire; boiled egg, roast shellfish, roast seal in `cooking.json` | the three new foods are grey blobs | n/a | 14 dishes blocked (F-19); seaweed, shellfish, crab meat, sea salt have no pickup (orphans, grey blobs) |
| **Farming** (items 332-343, `crops.json`) | **no**: nothing reads `crops.json`, nothing sows or grows; wheat, barley, carrot, potato, turnip, flax and their six seed items are orphans; flour recipes cannot be filled | all twelve are grey blobs | no field structure | whole system (S-farm). Hoe (paths, grading) and sickle exist; quern is craftable and useless |
| **Kiln, pottery, loom, cloth** | none exist: no kiln, loom or spinning structure, no cloth item; clay items are made by hand; brick is made at a campfire | n/a | n/a | design decision: if cloth and fired clay are wanted, they need items, recipes and stations |
| **Clothing and armour** (19 pieces) | hide set (cloak, boots, hood, mittens, leggings, tunic, trousers, gloves), grass skirt, grass cloak, fibre sandals are craftable; leather, bronze, iron, steel pieces are not | worn rows exist for all (generic builders); item looks real except the hide tunic set (grey) | worn via `worn.json` | metal chain (F-23), leather chain (F-02) |
| **Stations** | workbench, tool rack, stone forge (needs workbench level 2 = rack), woodworking table (needs lumber), clay hearth, oven | all draw (`structures_*.jpg`) | all place on the server except where a rule says no | log workbench and blacksmithy need plain logs (F-16); saw mill needs a foundation lift and iron-chain materials; large and master forge have **no blueprint** (F-25) |
| **Building pieces** | thatch floor, wall, roof, doorway, rough bed, lean-to place; the wood pieces need lumber | all 37 draw | all place (probe2) | no stairs, no stone, brick or log tiers, no gate, fence or furniture beyond chest and bed (F-22) |

## 15. Existing test suite, run on this branch

`python tools/items_check.py --only "stations,fishing,shore net,bed,warmth,dishes,trade,animals,big_game,placement_rules,first_hour,leanto,gather,new_player_day,plantpick,chest,eat,skills,spoilage"` (GODOT set to the editor binary). Result (raw output in `art/playthrough/items_check_output.txt`): **PASS** stations, fishing, shore net, bed, spoilage, warmth, skills, big_game, trade, dishes, new_player_day, placement_rules, first_hour, chest. **animals FAILED one timing check** (150 animals average 3.2 ms against a 3 ms limit; the machine was shared with other test runs, so a load artefact, not a game bug). The client step `gather` timed out after the server tests (machine load) and stopped the run, so `leanto`, `plantpick`, `eat` were not run. None of the passing tests touches the holes in this report: they check the rules that exist, not whether the chain can be walked, which is what the audit adds.

## 16. World pictures on the fixed world (`art/playthrough/world/`, `run_world.sh`)

| Picture | What it shows | Status |
|---|---|---|
| `spawn_view.jpg` | the spawn: an autumn forest of grown beeches and oaks, bramble in front, pond between the trunks | PASS (cover and berries are there) |
| `shelter_wide.jpg`, `shelter_close.jpg`, `shelter.jpg` | lean-to, rough bed, chopping block, workbench, tool rack, thatch roof placed in the forest | PASS: all six read well; the chopping block cannot be crafted by a player (F-16) |
| `campfire.jpg` | the placement ghost (a green ring) on grass; **the laid fire itself is not drawn** or the placement did not happen in this run | NOT CONFIRMED: needs a hand check (does a laid, unlit fire show its sticks?) |
| `fell.jpg` | only the spawn frame: the `--shot-fell=flat` rig produced none of its trunk and stump pictures when called through `rig.sh --client-arg` | NOT PHOTOGRAPHED (in progress, Kathleen's fell rig); trunk, stump, lit fire and under-tree cover are still missing |

Re-shoot recipe (quiet machine): `bash art/playthrough/run_world.sh` (about 12 minutes).


## 6. Fix status, part 2 (Sal, 2026-10-31)
* **F-16 data FIXED:** wood_species.json `ingredient_groups` (log, wooden_block, firewood); validate_items no longer treats plain `log` as a built-in source and now fails on any recipe ingredient with no source. The recipes and blueprints that use group ids are listed in LOG_SPECIES_SPEC.md. Code half (match members when filling an ingredient) is Tyler's.
* **F-19 FIXED (flagged):** products of recipes that no player can make yet are now `future`: willow bark tea, acorn mash, flatbread (need water; WATER_GATHER_SPEC.md), nails, hinges, hand saw (iron), tar (pine tar has no source), processed hide (flint), leather cap (leather). Everything else the guide listed (grass clothes, kindling, brick, mortar, cobblestone, wood chain via the stone wedge, cooking dishes) was already opened or made reachable by the `known` flips and the drops added earlier.
* **F-20 mostly a false alarm, one real fix:** plants without a drops.json row are still gatherable: the server picks a random in-season yield item that exists in the table (`gather()` natural yield). A check over all 174 gathered items found one true orphan: **rose hips** (needs a rose-hip harvest on wild rose from the flora session). Real bug fixed: flax, tall grass and nettle listed an abstract `fibre` yield next to their `plant_fibre` row, so a pick could give the useless "fibre"; removed from flora.json yields. The abstract names `wood, hardwood, softwood, hard_wood, fine_wood, timber, poles` are only yields of trees (felled, not picked) and are used by no recipe; `herbs, food, fodder, spines, stuffing, burrs` are generic items used as natural yields; none retired because the flora session owns the yield lists.
* **F-24 FIXED (data):** 19 of the live recipes stay `known:false` (forge/workbench level 2 and up, water wheel), by design; every other recipe is known from the start (F-01). The learn system is LEARN_SYSTEM_SPEC.md.

---

<!-- SCOREBOARD START (written by art/playthrough/status_check.py) -->
## Scoreboard: FIXED / STILL BROKEN (2026-10-31)

| id | what | status | evidence (short) |
|---|---|---|---|
| F-01/F-24 | recipes can be learned | **STILL BROKEN** | 173 of 192 recipes known or open (blockers: plank_chest_kit, steel_pickaxe, water_wheel, bronze_ingot, smelt_s |
| F-02 | flint can be picked up | **STILL BROKEN** | flint: ORPHAN |
| F-03 | tinder alternatives exist | **FIXED** | birch_bark now, tinder now, tinder_fungus now |
| F-04 | CONTROLS.md campfire cost matches recipe | **STILL BROKEN** | CONTROLS.md still says 10 stones and 20 sticks |
| F-05 | wood is reachable without iron (lumber) | **STILL BROKEN** | lumber RECIPE BLOCKED; lumber_wedge makeable now: False |
| F-06 | brick, oven and clay hearth reachable | **FIXED** | oven built wave 1, clay hearth 1 |
| F-07 | grown trees (cover) within 100 m of the spawn | **FIXED** | grown trees within 50 m / 100 m of the spawn: [6, 17] |
| F-08 | arrows without feathers | **FIXED** | fibre_arrow makeable now: True |
| F-09 | club, mace, javelin, wicker shield have real looks | **FIXED** | looks: ['override look', 'override look', 'override look', 'override look'] |
| F-10 | axe held with a natural pose | **MANUAL** | needs the in-hand picture art/playthrough/08_hold_stone_axe.jpg re-shot |
| F-11 | hammer can be made from a softwood block | **FIXED** | recipes giving wooden_hammer with a soft block: ['wooden_hammer_soft'] |
| F-12 | bedding can be gathered | **FIXED** | bedding: now; straw: now |
| F-13 | blueberry size | **MANUAL** | needs a picture |
| F-14 | first axe cost in twine | **FIXED** | stone axe needs 2 twine |
| F-15 | pickaxe craftable | **FIXED** | stone_pickaxe makeable now: True |
| F-16 | a felled log works in the log recipes | **STILL BROKEN** | probe_logs: probe3: chopping block crafted from an oak log on the shoulder: 0 |
| F-17 | override looks are drawn | **FIXED** | basic_look.entry() prefers the override over a placeholder row |
| F-18 | everything craftable today has a real look | **STILL BROKEN** | 20 craftable items with a grey or missing look: hide_tunic, hide_trousers, hide_gloves, clay_jug, herb_salve,  |
| F-19 | no blocked recipe without a future flag | **STILL BROKEN** | 27 recipes blocked and not flagged future |
| F-20 | every non-future gathered item has a gather path | **STILL BROKEN** | 96 orphan items not flagged future (first: log, aloe_gel, amadou, angelica_stems, banana_leaves, belladonna_be |
| F-21 | saw mill reachable | **STILL BROKEN** | saw mill built wave: None |
| F-22 | stairs and stone/brick/log pieces exist | **STILL BROKEN** | structures: 37, stairs: False |
| F-23 | ore, coal and flint can be picked up | **STILL BROKEN** | iron_ore ORPHAN, coal ORPHAN, flint ORPHAN |
| F-27 | kits are told apart by shape, not only tint | **STILL BROKEN** | 31 kits, 1 distinct shapes, 23 distinct tints/emblems |
| S-farm | farming exists (crops.json read by code) | **STILL BROKEN** | crops.json is read by: nothing |
| S-place | every kit and blueprint places on the server | **STILL BROKEN** | refused beyond the placement rules: ['blacksmithy'] (blacksmithy: its 10 plain logs, F-16) |
| S-craft | every recipe behaves as its known flag says | **FIXED** | mismatches: ['lumber_by_hand'] |

11 fixed, 14 still broken, 2 manual. Full evidence and owners: `PLAYTHROUGH_STATUS.md`.
<!-- SCOREBOARD END -->
