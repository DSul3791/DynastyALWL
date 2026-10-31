# Playthrough findings: spawn to first shelter, tools and weapons

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
| 15 | Chopping block | 2 logs | recipe #15 | stump-like block | PASS: `09_placed_shelter_close.jpg` |
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
| F-07 | **The spawn meadow has no cover.** Only trees >= 0.8 of full height shelter, and every tree in the spawn-area pictures is a young conifer. A new player cold or in rain has no tree to stand under until they find woods. | `03_raw_materials.jpg`, `06_weapons.jpg`; cover.gd SHELTER_MIN_SCALE | flora session (a few grown trees near spawn) / Dave to confirm design | small |
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
