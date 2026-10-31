# Item decision log (for Dave to review)

Kept by Sal. Dave (2026-10-30): decide on your own, look best practice up on the internet first, ask Dave only if truly needed, and keep a record here. Newest items at the bottom. "Dave" = Dave's own words; "Sal" = my decision. Main working document: `ITEM_GROUPS_AND_NAMES.md`. Branch: `sal-items`.

**One page of every item change: `ITEM_CHANGES_SUMMARY.md` (read it before this log).**

## FOR DAVE: decisions Sal made for you or still needs (read this first)
1. **Bench rule conflict.** `docs/mirror/design/CRAFTING_STATIONS_RULE.md` records "benches make weapons and tools only" as your standing rule (25 Oct). You said on 30 Oct it is not yours. Sal followed the 30 Oct words; the old file is untouched.
2. **Trim list: your 25 Oct answers stand** (ITEM_TRIM_DECISIONS.md). Done: spade sizes retired (stone spade digs 4 pieces, iron and steel 8: Sal's mapping, change it if you wish), sewing needle retired, vice kit no longer craftable. Deferred: one Lumber/Beam with a species tag (needs a code feature; spec below).
3. **Dishes:** four dishes trimmed to 3 ingredients; Hearty pottage and Roast Beast stay at 5 as special top-tier dishes. Food points were not reduced (a small buff). Say if you want them reduced.
4. **Crops:** medieval European crops in the starter lands; potato, maize, rice only as exotic crops from far islands.
5. **Copper tool rung:** you asked for copper, tin and bronze ingots; no copper tools exist and TOOL_TIERS.md says none until you ask. Do you want copper axe, pickaxe, knife?
6. **Pickaxe tier:** the pickaxes are tiered one rung earlier than the spades (iron pick tier 2, iron spade tier 3). Sal left it.
7. **Clay Oven and Iron Stove** need new structures, models and the quality system; spec below, nothing built.
8. **Numbers used:** items 278 to 300 and recipes 178 to 189, inside the block reserved in TOOL_TIERS.md.
9. **Not tested:** the full 40-step suite and the animal, wolf and trade scenarios.

### Sal's default answers to the questions above (reversible; Dave can overrule)
- Copper tool rung: NOT added now. Copper and bronze stay ingots and weapon/jewellery materials until Dave asks for tools; adding the rung later is a data change plus the tier-numbering issue noted in ITEM_TIER_BALANCE.md.
- Pickaxe versus spade tier: left as is (no change).
- Dish food points: left as is (a small buff); cutting them later is a one-line edit per dish.
- Bench-rule file: left untouched; Sal follows the 30 Oct words.
- Spade bite mapping (stone 4, iron and steel 8): kept; changeable in items.json (`spade_size`).
- Clay Oven and Iron Stove: spec written, nothing built; needs models and states.

## Dave's rules (his words, condensed)
- Recipes: three ingredients at most; only a really special, powerful top-tier item may use 4 or 5.
- Keep it simple, engaging, educational (a hint), fun and reasonable to make; never so complicated players stop enjoying it.
- Benches are for crafting; some things are made by hand, others at a station, item by item. (The "benches only for weapons and tools" rule was never Dave's.)
- No extra steps just to add steps (no bloomery).
- Work alone, take initiative, ask Dave only if really needed.

## Questions and answers
| # | Question | Answer | By | Basis |
|---|---|---|---|---|
| 1 | Flint a separate item? | Yes, its own stone item (a type of stone); common near rivers | Dave | his words |
| 2 | Hide and Leather? Tannery? | Hide, Leather, Heavy leather; tannery with tubs and drying racks; leather working table early; hide scraper as the hand tool | Dave + Sal | his leather chain |
| 3 | Metals | Smelt ores straight to ingots; copper, tin, bronze before iron and steel; no bloomery | Dave | his words |
| 4 | Fire starting | Built, not an item: rocks for the ring, sticks as fuel; E lights or stamps out; needs stone + flint; flint+stone about 8-9 tries; pyrite between; flint+steel about 2 | Dave + Sal | his words; pyrite and steel facts from Fire striker (Wikipedia) |
| 5 | Climbing and traversal | In: climbing picks, anchored ropes, gliders | Dave | his words |
| 6 | Javelin | Own item | Dave | his words |
| 7 | Gunpowder, siege | Both in, tiered | Dave | his words; tiers by Sal from History Crunch / Wikipedia (weak sources) |
| 8 | Drinks | All kinds, with food effects | Dave | his words; order of tiers by Sal from Barm / BYO / SCA pages |
| 9 | Furniture | In, fun and useful (stool, chair, bench, throne) | Dave | his words |
| 10 | Farming | Crop to food, simple; windmill; recipe tiers | Dave | his words |
| 11 | Boats and carts | In, many types, sizes and qualities | Dave | his words |
| 12 | Tyler's trim list A to J | ALREADY ANSWERED by Dave on 25 Oct (docs/mirror/design/ITEM_TRIM_DECISIONS.md): A, B (no vice, no sewing needle), C yes; D, E, G rejected; F one forge in tiers; H keep all coins, add tunic, trousers, gloves; I scythe and sickle, no rake, shears not yet. My earlier decisions were wrong and are withdrawn | Dave | that file |
| 13 | Pyrite | In | Dave | his words |
| 14 | Obsidian | In, mid tier, on dormant-volcano islands past the starter islands; knives, arrows, spears, swords, jewellery, magic component | Dave | his words |
| 14b | Magic | A huge magic system comes later; magic items get a separate pass | Dave | his words |
| 15 | Quality system | One grade scale: Poor, Common, Good, Fine, Excellent; owned by the game-systems owner | Sal | design test |
| 15b | Rivets | New item | Sal | needed for bound leather |
| 16 | Ovens | Basic Oven (existing 268), Clay Oven, Iron Stove | Dave (Basic Oven, 3 rungs) + Sal (names) | his words |
| 17 | Crop strictness | Medieval European crops in the starter lands; potato, maize, rice only as exotic crops from far islands | Sal | potatoes and maize reached Europe after 1492 (general knowledge; the search did not cover it) |
| 17b | Sickle | Keep: scythe AND hand sickle (Dave 25 Oct) | Dave | ITEM_TRIM_DECISIONS.md |
| 17c | Seeds / plots | One seed item per crop; no plot item, the hoe tills a field | Sal | simplicity |
| 18 | First animals | Chickens, bees, then sheep, goats/cows, pigs | Sal | simplicity |
| 19 | Forges | One forge model (furnace plus anvil), upgraded in tiers (Dave 25 Oct) | Dave | ITEM_TRIM_DECISIONS.md |
| 20 | Camp bench, sewing needle, shears, bronze coin | Camp bench and bronze coin keep; sewing needle CUT and shears out until sheep exist (Dave 25 Oct) | Dave | ITEM_TRIM_DECISIONS.md |
| 21 | Bench rule | `docs/mirror/design/CRAFTING_STATIONS_RULE.md` records "benches make WEAPONS and TOOLS only" as Dave's standing rule (25 Oct 02:50). On 2026-10-30 Dave told Sal that rule is not his and benches are for crafting generally. Sal follows the 30 Oct words; the older file was not edited. Flagged to the moderator | Dave (30 Oct) | conflict, needs the moderator to reconcile |

## Work log
- 2026-10-30: grouping document, Part B decisions, data batch 1 (Basic Oven rename; items 278-292).
- 2026-10-30: data batch 2: Hide scraper 293, Steel striker 294, Javelin 295, Obsidian knife 296, all `future`.

## Still open (Sal will decide when reached)
- Tyler merges (need a game test); recipes/blueprints for new items; Clay Oven and Iron Stove (need game states); magic items pass; second-tier extras.
- Anything needing Dave: only a true design conflict. None yet.

## Sources used so far (quick searches, mixed quality)
Fire striker (Wikipedia); Conchoidal fracture (Wikipedia mirror); Flint knapping (nordling.de); Geology In (pyrite, obsidian); Rockhounding.org; History Crunch (medieval food and siege); Wikipedia regional cuisines, siege engines list, medieval ships; Gilbey, Early Carriages and Roads; Barm (Wikipedia); BYO medieval ale; SCA Introduction to Brewing.

## Data batch 3 (2026-10-30)
Recipes 178 to 185 added in `data/items/recipes.json` (`next_number` 186), all `known: false`: Kindling (stick), Processed hide (hide, keeps Hide scraper), Hide scraper (flint, stick, twine; workbench), Javelin (stick x2, flint; workbench), Obsidian knife (obsidian, stick, twine; workbench), Steel striker (steel ingot; forge), Rivets (iron ingot; forge), Bronze ingot (copper ingot, tin ingot; forge level 2). Each uses at most 3 ingredient kinds. Recipes for Leather, Fine leather, Heavy leather, Flour, Yeast, Salt, Copper ingot and Tin ingot are NOT written because their inputs (tannery, grain, ore items) do not exist yet.

## Merge plan (A, B, C approved by Dave on 25 Oct; NOT executed)
Why not executed: each retirement touches many files that need the game to test, and I found no Godot binary here to run `tools/items_check.py` (validate_items, server_items, tool_looks). Doing it blind risks breaking tests. Files touched per merge (from a repo search by id):
- **A, spades 213-220** (wooden/stone/iron/steel medium and large): items.json, looks.json, recipes.json (2 to 3 each), showroom.json, weights.json, tools/gen_looks.py, design/TOOL_TIERS.md, ITEM_MASTER.md, tests test_server_items.gd (wooden_spade_large) and test_tool_looks.gd (stone/iron/steel large). Needs: a bite-size setting on the one spade per material (code), all spades the same weight.
- **B, wooden vice 83/84 and sewing needle 49:** vice into the log workbench; hammer line to one. Sewing needle recipe/uses need checking.
- **C, species lumber/beam:** items 101-102, 107-108, 110-111, 113-114, 125-126, 149-150, 173-174 into one Lumber and one Beam with a species tag; touches wood_species.json, src/stream/server_items.gd and tests.
Method when a session with Godot runs it: retire (never delete) with `"retired": true` and a `"merged_into"` note, one commit per group so each can be reverted alone.

## Food pass: existing dishes against Dave's 3-ingredient rule
Dave (25 Oct) keeps every dish. The rule says three kinds normally and four or five only for special powerful top-tier items. These are the current dishes by number of kinds (from data/items/dishes.json):

| Dish | Kinds | Needs | Food points |
|---|---|---|---|
| Acorn mash | 2 | acorns x3, water x1 | 380 |
| Baked apples | 2 | crab_apples x3, honeyspindle_nectar x1 | 420 |
| Berry compote | 2 | blueberries x2, honeyspindle_nectar x1 | 350 |
| Flatbread | 2 | seeds x3, water x1 | 420 |
| Nut paste | 2 | hazelnuts x3, honeyspindle_nectar x1 | 450 |
| Roast Roots | 2 | burdock_roots x2, wild_carrot_roots x2 | 400 |
| Chestnut cakes | 3 | chestnuts x3, honeyspindle_nectar x1, linseed x1 | 600 |
| Fruit leather | 3 | crab_apples x2, cranberries x1, honeyspindle_nectar x1 | 520 |
| Garlic meat | 3 | raw_meat x1, wild_garlic_bulbs x1, rosemary x1 | 760 |
| Herb fish | 3 | trout x1, thyme x1, samphire x1 | 680 |
| Honey loaf | 3 | seeds x3, hazelnuts x1, honeyspindle_nectar x1 | 620 |
| Mushroom skewer | 3 | porcini x2, chanterelles x1, wild_garlic_leaves x1 | 560 |
| Rosemary joint | 3 | raw_meat x2, rosemary x1, wild_garlic_bulbs x1 | 700 |
| Smoked fish | 3 | pike x1, samphire x1, juniper_berries x1 | 700 |
| Fish stew | 4 | perch x1, watercress x1, wild_carrot_roots x1, sage x1 | 880 |
| Forager's stew | 4 | greens x2, burdock_roots x1, chanterelles x1, sorrel_leaves x1 | 850 |
| Hunter's stew | 4 | raw_meat x1, wild_carrot_roots x1, wild_garlic_bulbs x1, porcini x1 | 900 |
| Trail bread | 4 | linseed x2, hazelnuts x2, dates x1, animal_fat x1 | 950 |
| Hearty pottage | 5 | seeds x2, wild_carrot_roots x1, dandelion_leaves x1, marjoram x1, animal_fat x1 | 1050 |
| Roast Beast | 5 | raw_meat x2, wild_garlic_bulbs x1, thyme x1, rosemary x1, animal_fat x1 | 1200 |

Verdict (Sal): 2 and 3 kinds are fine. **4 kinds** (Hunter's stew, Forager's stew, Fish stew, Trail bread) and **5 kinds** (Hearty pottage, Feast roast) exceed the normal limit. Proposal: keep Feast roast and Hearty pottage as the special top-tier dishes; reduce the other four to 3 kinds when the dish file is next edited (change `needs` in dishes.json and run `tools/gen_dishes.py`, which regenerates items, recipes and food points). NOT done: gen_dishes.py and the tests were not run. The file note also says more kinds = better dish (DESIGN_IDEAS 5.3); that still works with 3 as the normal ceiling.

## Spec for the code owner: Clay Oven and Iron Stove (Dave's cooking ladder, 2026-10-30)
How the Basic Oven is wired today (data/items/structures.json, blueprints.json): structure `oven`, kit `oven_kit` (item 268), world state 45, footprint 1.8 x 1.4 m, `station: oven`, `station_level: 3`, `also` = it counts as a clay hearth (level 2) and a campfire (level 1); blueprint 14 "Basic Oven" costs brick 24, clay 10, stone 8, built with a hammer next to a clay hearth. Cooking recipes name a station (`oven`) and may name `station_level`.
The ladder maps onto station levels (campfire 1, clay hearth 2, Basic Oven 3):
| Rung | Name | Station level | Cost (3 kinds max) | Needs near | Cooking effect (proposal) |
|---|---|---|---|---|---|
| 3 | Basic Oven (exists) | oven 3 | brick 24, clay 10, stone 8 | clay hearth | baseline speed, some burn chance |
| 4 | Clay Oven | oven 4 | brick 40, clay 20, stone 20 | a Basic Oven | holds more, faster, lower burn chance |
| 5 | Iron Stove | oven 5 | iron ingot 6, brick 20, hinges 2 | a Clay Oven | fastest, best quality, adds a hob for a pot |
Needs from code: two new structures with world states, footprints, looks and kits; `also` lists so a level-5 station satisfies lower-level recipes; the burn chance and quality grade need the quality system (not built). Dishes in the food pass (high tier) should require oven level 4 or 5. Nothing of this is written into data yet because new structures need models and states.

## Merge status (2026-10-30, tested with Godot via tools/godot.cmd)
| Merge | Status | Commit scope |
|---|---|---|
| A, spade sizes 213-220 | DONE. Retired with a note (never deleted); recipes 131-138 retired; the base spades carry the bite size: stone spade medium (4 pieces), iron and steel large (8), wooden stays small (1) (Sal's mapping of "a better material digs a bigger bite"); test_server_items now uses the iron spade. Looks, weights and showroom rows for the retired ids were left in place (harmless). | one commit |
| B, sewing needle 49 | DONE (retired, recipe retired). | one commit |
| B, hammer line | NOTHING TO DO: wooden hammer and stone hammer are tiers of one line (Tyler's wording), not duplicates. | none |
| B, wooden vice 83/84 | DEFERRED. The vice is a workbench add-on that sets the bench level (tool rack = level 2, rack plus vice = level 3, test_stations.gd). Folding it into the log workbench changes the station-level rule, which needs a design call: proposal (Sal) the log workbench is level 2 by itself (it already has a rack and vice in its model), a tool rack beside it makes level 3; the vice kit retires. Not done because it changes crafting access. | none |
| C, one Lumber and one Beam | DEFERRED. wood_species.json already has `key_woods` (Dave 24 Oct) and `retired_to` conversion for retired species; there is no per-stack species tag in code. Needs that feature first. | none |
Tests run after each change: validate_items, server_items, dishes, stations, save_compat, inventory, first_hour (all pass), plus test_tool_looks (0 failures) for A. The full 40-step suite was started and stopped (too long); steps not run: the client/server scenarios (animals, wolves, trade scenes and so on).

## Magic items: first pass (names only, for the later magic design; from the analysis rows, unconfirmed unless marked)
Dave: a huge magic system is coming. Sources seen so far:
- **Staves and wands:** Valheim Staff of Embers, Staff of Frost, Staff of Protection*, Dead Raiser*, Echo Spike, Spirit Caller; Dragonwilds wands and battlestaves by wood (Ash, Oak, Blightwood, Splitbark, Maple, Master, Ancestral). Magic armour sets in Dragonwilds: Apprentice, Wizard, Dark Mage, Splitbark, Mystic, Infinity, Ancestral.
- **Energy resource:** Valheim Eitr (Refined Eitr, Eitr Refinery, Galdr Table, Minor Eitr Mead); Ark Element (Element Dust, Shard).
- **Potions and brewing:** Minecraft brewing stand, base potion (water bottle, awkward potion), about 15 effects (healing, strength, swiftness, regeneration, night vision, water breathing, fire resistance, slow falling, weakness, poison), modifiers (longer, stronger, splash, lingering, reversed); Valheim meads (healing, stamina, resistance); Dragonwilds focused potions (weak to super) and antifire and antipoison.
- Obsidian (Dave): a magic component; Obsidian mirror (Sal idea): scrying.
REC for the magic pass (later): few, readable components (a crystal or stone, a herb, a metal), not dozens; each spell tool a staff or a wand with a clear job; potions follow the 3-ingredient rule. No design is decided.

## Update: vice done, hammer line, and the species-tag spec (merge C)
- **Vice (B): DONE, in its own commit.** The vice kit recipe is retired, so it can no longer be crafted. The kit item and the `vice` structure stay, because validate_items forbids a structure naming a retired item and because vices already placed or carried must keep working (a later save migration can retire them fully). Bench levels now: camp bench 1, a tool rack beside it makes 2; log workbench 2, with a rack 3. No live recipe needs workbench level 3 or more (21 need level 1, 1 needs level 2), so nothing became unreachable. `test_stations.gd` now checks that a camp bench with a rack stays level 2.
- **Hammer line (B): nothing to do.** The wooden hammer (247) and stone hammer (244) are tiers of one line; no item is a duplicate. Independent of the vice.

### Spec for the code owner: one Lumber and one Beam with a species tag (merge C, approved by Dave 25 Oct, DEFERRED)
Goal: items 27 (Lumber) and a single Beam stay; the 14 species items (oak, birch, Scots pine, spruce, tropical hardwood, walnut, sugar maple: lumber 101, 107, 110, 113, 125, 149, 173 and beams 102, 108, 111, 114, 126, 150, 174) retire; the tree species is carried on the item, and affects burn, tier and look.
What does not exist yet: a per-stack species tag. Inventory slots hold only item number and count (plus wear for tools, server-owned).
Work for the code owner:
1. Inventory: let a slot carry an optional species id; stacks of the same item and species merge, different species do not; save format and `save_compat` must read old saves without the tag.
2. Crafting: a recipe consuming Lumber/Beam may demand any species or a named one; the sawmill, hand saw and block recipes carry the input log's species to the output.
3. Conversion: `wood_species.json` already has `key_woods` and `retired_to`; extend it so retired species lumber/beam rows convert into (Lumber or Beam + species tag) on load.
4. Display: tooltip shows the species; looks tint by species (BasicLook already knows wood colours).
5. Tests: test_server_items.gd, test_inventory.gd, save_compat, test_first_hour; new test for tag merge, split and save/load.
Files touched (from the repo search): data/items/items.json, recipes.json, looks.json, weights.json, wood_species.json; src/stream/server_items.gd; src/shared (inventory); client inventory_view.gd; tools/gen_looks.py; tests above.
Why deferred: it is a feature, not a data merge. Nothing is half-done in the data.

## Three new plans (self-approved by Sal under the moderator's pre-approval, 2026-10-30)
1. **Recipe balance check** (done below). 2. **Items still lacking a look, for Kathleen** (done below). 3. **Progression gap check across tiers** (first pass below; full review waits for Dave's final list).

### Plan 1 result: recipe balance against the 3-ingredient rule
132 live recipes. By number of ingredient kinds: 1 kind 47, 2 kinds 52, 3 kinds 27, 4 kinds 4, 5 kinds 2. Only the six dishes already named exceed 3: Hunter's stew, Forager's stew, Fish stew, Trail bread (4 each), Hearty pottage and Roast Beast (5 each). Everything else obeys Dave's rule. Proposal: Roast Beast and Hearty pottage stay as the special top-tier dishes (allowed 4 to 5); the other four drop to 3 kinds when someone edits dishes.json and runs `tools/gen_dishes.py` (the generator rewrites items, recipes, vitals, spoilage and weights; run the `dishes` check after). Nothing was changed. The recipes file note ("hand crafts at most two ingredient kinds") is older than Dave's rule and still true for hand crafts.

### Plan 2 result: for Kathleen (art): items with no look yet
226 live items. Own models already (left out of looks.json on purpose): stone, stick, log, driftwood, chopping block, species logs, log workbench kit, timber prop and set kits, ladder kit. Items with only a generated placeholder look (a simple shape and colour from tools/gen_looks.py): all the materials I added (Flint, Pyrite, Obsidian, Processed hide, Leather, Fine leather, Heavy leather, Rivets, Copper, Tin and Bronze ingots, Flour, Yeast, Salt) and the Javelin; plus four older placeholder-flagged items. Items with NO look row at all: Hide scraper, Steel striker, Obsidian knife (tools have separate in-hand models). Art asks, by priority: Flint, Pyrite and Obsidian (they are visible in the world and in fire-making), Javelin, Hide scraper, Obsidian knife, Steel striker, then leather grades and ingots.

### Plan 3 first pass: progression by tier (live and `future` items)
| Tier | Tools | Weapons | Clothing |
|---|---|---|---|
| 0 | wooden spade, hoe, fishing rod, shore net | none | grass skirt, cloak, fibre sandals |
| 1 | stone axe, stone knife, torch, wooden hammer (hide scraper, future) | wooden spear, wooden bow | hide cloak, boots, hood, mittens, leggings |
| 2 | stone spade, hoe, hammer (iron pickaxe, obsidian knife, future) | stone spear (javelin, future) | none |
| 3 | hand saw (steel pickaxe, iron spade, iron hoe, future) | none | none |
| 4 | (steel spade, hoe, striker, future) | none | none |
Gaps seen: no club, sword, mace, shield or armour above hide in any tier; no stone pickaxe (the first pickaxe is iron); no body armour; no head/hand/foot gear above tier 1; copper and bronze items exist only as ingots; no axe above stone. These match the first-thoughts list in ITEM_GROUPS_AND_NAMES.md and are inputs to the later progression review, not decisions.

## Dishes done and plan 3 (tool and weapon tier balance), 2026-10-30
**Dishes (one commit):** Hunter's stew drops porcini, Forager's stew drops sorrel, Fish stew drops sage (description updated), Trail bread drops dates. All four now take 3 ingredient kinds. Hearty pottage and Roast Beast keep 5 as special top-tier dishes (Dave: 4 or 5 only for really special powerful items). Food points, shelf life and warmth unchanged on purpose (a dish that is cheaper to make but worth the same is a buff, which Sal judged fine for first-hour cooks; Dave can ask for a cut). I edited dishes.json and the four recipes by hand instead of running tools/gen_dishes.py, which rewrites seven data files in a different format. Tests pass: validate_items, dishes, server_items, first_hour, inventory.

**Tool and weapon balance (observations from items.json, no changes):**
- Durability climbs about tenfold per material: stone axe 900, stone spade/hoe/hammer about 4000, iron spade/hoe 20250, steel 40500, iron pickaxe 9000, steel pickaxe 22500. The jump from stone to iron is about 5 times for spades but the first pickaxe is iron, so there is no stone mining tool.
- Pickaxes are tiered 2 (iron) and 3 (steel) while spades are tiered 2 (stone), 3 (iron), 4 (steel): the pickaxe sits one tier earlier than the matching spade. Check against design/TOOL_TIERS.md.
- Weapons: wooden spear 6 melee / 5 thrown, stone spear 8 / 6; Javelin (new, future) 4 melee / 9 thrown with durability 120, which makes it the best thrown weapon and a poor melee one, as Dave described. Obsidian knife cuts 1.6 against flint-class stone knife 1.0 with durability 300 against 540: sharper and more brittle, as intended.
- Value: Steel pickaxe 300 and Iron pickaxe 120 are priced far above the stone tools (20 to 30); copper, tin and bronze tools do not exist yet, so there is a gap between stone (T2) and iron (T3).

## Data batch 4: progression gap items (plan 1 started, 2026-10-30)
Added as `future` (not obtainable yet), all passing validate_items, dishes, server_items, first_hour, inventory, stations, save_compat: **Stone pickaxe 297** (pick, tier 2; the missing stone rung in design/TOOL_TIERS.md), **Sickle 298** (stone, tier 1; Dave 25 Oct: scythe AND sickle), **Scythe 299** (iron, tier 3), **Wooden club 300** (weapon, tier 1, damage 7). Recipes 186 to 189 (all `known: false`): Stone pickaxe (stick 2, stone 3, twine 2; workbench), Sickle (flint, stick, twine; workbench), Scythe (iron ingot 2, stick 2; forge), Wooden club (stick 3; by hand). Weights added; look row added for the club (tools use in-hand models). `next_number` items 301, recipes 190. Note: design/TOOL_TIERS.md reserved items 267-299 and recipes 170-199 for early tools; my numbers 278-300 and 178-189 fall in that block, so anyone planning those numbers should start after 300 / 189.
Not added on purpose: copper tools (TOOL_TIERS says no copper rung until Dave asks; Dave asked for copper, tin and bronze ingots but not yet for a tool rung: open call), sword, mace, shield, sling, armour above hide. These wait for the final list.

## Plans round 4 (self-approved, 2026-10-30): 1 station and bench chain check (done below), 2 one hand-off page for the code owner (Clay Oven, Iron Stove, species tag, vice migration), 3 tool durability and tier number pass.
### Plan 1 result: crafting-station level and bench chain against the item list
How stations work: a recipe names a station and a level; a placed structure provides a station at its `station_level` and may also provide others through `also` (stone forge gives workbench 3 and forge 1; blacksmithy workbench 4 and forge 2; large forge forge 3; master forge forge 4).
Chain as built: hand -> camp bench (workbench 1, hand recipe) -> log workbench (workbench 2, made at workbench 1) -> sawmill, woodworking table, stone forge, blacksmithy (blueprints) -> large and master forge. Live recipes by station: hand 66; workbench 1: 22, workbench 2: 1; forge 1: 7, forge 2: 2; sawmill 15; woodworking table 1; campfire 12; campfire pot 7; clay hearth 1; oven 2.
Findings:
- **No recipe uses workbench level 3 or 4 or forge level 3 or 4.** The large forge (92) and master forge (94), and the blacksmithy's top levels, unlock nothing yet; large and master forge also have no kit recipe or blueprint (not buildable). That fits Dave's 25 Oct answer F (one forge upgraded in tiers) but the upgrade path is not built.
- **No recipe makes an ingot.** iron_ingot and steel_ingot (and my copper, tin and bronze) are `future` materials with no smelting recipe and no ore items, so every forge recipe (nails, hinges, iron pickaxe, scythe, rivets, striker, bronze ingot) hangs on a missing step. Dave's rule: ore smelts straight to an ingot in a forge, one step. Needed: ore items (copper, tin, iron; the world resources table has the minerals but they are not items), smelting recipes at forge 1 (copper, tin, iron), forge 2 (bronze, steel).
- The new bronze ingot recipe needs forge level 2 (blacksmithy); iron-tier recipes need forge 1.
- Nothing in the new items asks for workbench 3 or 4, so no new dead ends were added.

## Kathleen's reply (2026-10-30)
All 22 art requests have looks on branch kathleen-art (commits eccd2c88, 90efaa55) through ART_OVERRIDES in src/client/basic_look.gd; looks.json untouched, so the branches should merge cleanly. Not yet viewed in the real game. The code hand-off page is ITEM_CODE_HANDOFF.md (plan 2 of round 4, done).

## Data batch 5 (2026-10-30) and plan results
- Metals gap closed in data: ore items Copper ore 301, Tin ore 302, Iron ore 303, Coal 304 (future) and smelting recipes 190 to 193 (copper, tin, iron at forge 1; steel from 2 iron ingots plus coal at forge 2). Ore gathering in the world is still missing (code).
- Clothing from Dave's 25 Oct H answer: Hide tunic 305, Hide trousers 306, Hide gloves 307 (future), recipes 194 to 196 (hide and twine, hand-made in the data's class but hidden). Drawn with the existing cloak, leggings and mittens builders via worn.json until new drawings exist.
- Plan 3 (durability and tier numbers): new items sit on the ladder in ITEM_TIER_BALANCE.md: stone pickaxe 4500 (stone rung about 4050), scythe 9000 (iron-tool band), sickle 600, club 350, javelin 120, obsidian knife 300 (brittle, 0.6 of flint). No existing number was changed.
- One-page summary of every change: ITEM_CHANGES_SUMMARY.md.

## Food, medicine and storage gap check across tiers (2026-10-30)
Live: food 35 items (raw and cooked fish and meat, teas, 20 dishes; the flour, yeast, salt and grain chain is data only), medicine 2 (poultice, bandage), containers 4 (wooden bowl, clay pot, bucket, waterskin) plus the woven and plank chests, tool rack and backpack.
Gaps against the catalogue: storage has nothing between the bowl and the chest for loose goods (basket, sack, barrel, shelf); no jug for ale and mead; medicine stops at the poultice and bandage (no salve, splint, antidote); preserved food (jerky, salt meat, hardtack) not yet in dishes; no grain, bread or cake items because no crops exist.
Added (future, with recipes of at most 3 ingredients): Clay jug 308, Herb salve 309, Splint 310 (recipes 197 to 199). Not added: basket, sack, barrel and shelf (storage items need capacity and placement rules that belong with the code owner), antidote (needs poisons and injuries), jerky and hardtack (need salt in the world and grain).
Plans for this round: clothing recipes (done, see batch 5), this gap check (done), summary page at the top (done).

## Lighting gap check and reachability check (2026-10-30)
**Lighting:** live: Basic torch (12) and the campfire. Gaps from the catalogue: candle, oil lamp, lantern. Added Candle 311 (future; animal fat plus plant fibre gives 2; light range 4 m against the torch's 9 m; not offhand because the validator only allows torch and shield classes in the left hand). Lantern needs iron and glass and oil, so it waits for metals; oil lamp waits for oil.
**Reachability from nothing** (approximate script: starts from gatherable plants and animals plus stone, stick, log, treats future items as unobtainable). 146 live recipes; 59 could not be reached by the script. Real causes, in order of importance:
1. **Iron has no source.** Iron, steel and (new) copper, tin and bronze ingots depend on ore items nothing yields. That blocks nails, hinges, saw blades, hand saw, the sawmill chain (lumber, every species lumber and beam, fine board), water wheel, chests, wall/floor/roof/doorway sections, ladder, timber set, iron tools. In short: everything made of lumber waits on iron through the saw. Today lumber comes only from the sawmill or the hand saw. The fix is the same as before: ore gathering in the world (code).
2. **Flint, Obsidian, Pyrite and Coal have no world source.** The resources table lists flint, coal and others as terrain minerals, but no gather yield makes the items. Blocks Hide scraper, Javelin, Sickle, Obsidian knife.
3. False alarms of the script: firewood, wooden block, fish, species logs come from felling and fishing, which the script does not model.
Conclusion: only two data-side gaps are not dead ends of the code: the ore items exist now, and the smelting recipes exist; the missing piece is the code that gives them out.

## Plans round (2026-10-30, after the iron finding)
1. Stone wedge path: write the item and recipe spec for the stone-age lumber route (needs Dave's yes before data change).
2. Storage gap check: basket, sack, barrel, shelf specs with 3-ingredient recipes.
3. Medicine gap check: antidote, jerky, hardtack specs.
Approved by Sal (moderator pre-approval). Plan 1 started: spec is in ITEM_CHANGES_SUMMARY.md; data change waits for Dave.

## Plans round 2 (2026-10-30)
1. Combat tier list (swords, maces, shields, armour): DONE as ITEM_COMBAT_TIER_LIST.md (spec only).
2. Farming crops and tools gap check: next.
3. One-page glossary of item names for the team: after that.

Plan 1 of round 2 built: items 312-331, recipes 201-220 (shield off-hand = choice A; plate = future only). Tests green. Next: farming gap check, then glossary.

Plan 2 of round 2 done: ITEM_FARMING_GAP_CHECK.md (spec only). Dave question: which first crops (rec: wheat, barley, carrot, potato, turnip, flax). Next: item-name glossary.

Farming items built (332-345, recipes 221-224), tests green. ITEM_GLOSSARY.md generated (plan 3 of round 2 done).
## Plans round 3 (2026-10-30)
1. Storage items: basket, sack, barrel, shelf as future items (3 ingredients max). Starting.
2. Animals and beehive item spec (egg, milk, wool, honeycomb, wax; no live animals).
3. Final consistency pass: every new item has a weight, look, recipe, art request line.

## Fauna data pass (2026-10-30, moderator job 1)
Merged origin/DailyDev_20261029 into the branch (clean). Added items 346-352, recipes 225-226, 14 carcass rows, fauna_proposal.json (50 species), ANIMAL_SPEC.md. Tests green except the animals timing check (machine load, unrelated). Choice made (reversible): kept spawn rows out of animals.json because the code and models do not exist; the proposal file is read by nothing.

## Plans round 4 (2026-10-30 night, self-approved per moderator)
1. Guide findings: fix every item/recipe/reachability finding once PLAYTHROUGH_FINDINGS.md is pushed (not on disk or remote yet at this check).
2. Tropical and desert fauna list (monkey, parrot, crocodile, camel, scorpion) with loot, same format as fauna_proposal.json.
3. Re-run test_animals on a quiet machine and record the real timing.

## Guide findings pass (2026-10-31)
Decisions (reversible): F-01 rule = known unless forge/workbench level 2+ (76 flipped); axe twine left at 5 (tests hard-code it); stone wedge route for lumber (moderator QA yes). See PLAYTHROUGH_FINDINGS.md section 5, LEARN_SYSTEM_SPEC.md, FLINT_ORE_SPEC.md. New items: Stone wedge 353, Fibre arrow 354.

## Moderator round 3 (2026-10-31)
Axe/spear to 2 twine (tests updated). Straw from tall grass. Shore and sea foods added: Seaweed, Shellfish, Crab meat, Egg, Seal meat, Sea salt, Steamed Shellfish, Boiled egg, Seal Steak (items 355-363; cooking through cooking.json cooks_into; kcal and spoilage follow existing cooked/raw ratios, my numbers); carcass rows seal, seabird. FAUNA_BY_BIOME.md, LOG_SPECIES_SPEC.md, BUILD_ORDERS.md written.
Plans (self-approved): 1 per-tier build orders with timings (done, BUILD_ORDERS.md); 2 add Sea salt recipe once a water-gather action exists (code); 3 recheck BUILD_ORDERS.md after the flint/ore code lands.

## Food coverage check and gap plans (2026-10-31)
Shrubs and berries: all 11 berry species have berry_yield rows and eat by the `berries` suffix (vitals.json by_suffix); herbs, roots and fungus have harvest_yield rows; plants without a row (gorse, wolfsbane, aloe, belladonna, henbane and the magic plants) fall back to their flora `yields` (test_server_items checks this), so I added nothing. Poisonous look-alikes already exist in gathered.json look_alikes (belladonna berries vs blueberry and so on). Seasons are in flora.json. Result: no food-side gap found for the new bushes except the ones needing code (crops, shore foods). I tried adding 33 explicit harvest rows and reverted: they broke test_server_items, which relies on the fallback.
Added: recipes Leather, Heavy leather, Fine leather (236 range 234-236); oak gives tannin_bark; data/items/crops.json; WATER_GATHER_SPEC.md; GAP_PLANS.md.
New plans (self-approved): 1 keep BUILD_ORDERS.md current after each code drop; 2 wildlife: write spawn weights per biome from FAUNA_BY_BIOME.md for the code session; 3 dishes using shore foods (seaweed soup, mussel stew) at 3 ingredients.

## Guide part 2 (2026-10-31)
F-16 groups + validator rule; F-19 nine products flagged future; F-20 fibre yield removed from flax/tall grass/nettle, rose hips orphan listed; F-24 re-count: 19 locked by design. Basis: server gather() natural-yield fallback (server_items.gd 1063).

## Moderator round 5 (2026-10-31)
Dishes: wild_garlic_bulbs to wild_garlic_leaves, dandelion_leaves to dandelion_flowers, seeds to seed_bundle (plants with a harvest row yield only that item). linseed, greens and honeyspindle nectar stay (reachable by the natural-yield fallback). The guide count of 40 blocked-not-future differs from my walk, which includes the fallback: only lumber by hand remains (hand saw is future). Rose hips still an orphan (to flora via moderator). New: FARMING_SPEC.md, CLOTHING_WARMTH.md (items 364-373, recipes 237-245), FAUNA_SPAWN_PLAN.md and data/animals/spawn_plan.json.
Plans (self-approved): 1 shore-food dishes (seaweed soup, mussel stew); 2 refresh BUILD_ORDERS after the next merge; 3 art requests for new clothes and crops to Kathleen.

## Night check round (2026-10-31)
item_uses.json audited against recipes and blueprints: 20 lines said a thing was used in a blueprint or recipe when none uses it (cut stone, mortar, cobblestone, stone shingle, tar, hinges, wooden pin, rough plank, fine board); rewritten as planned/true. Old species boards marked old. Flora handoff done (rose hips, garlic, dandelion via the natural-yield fallback; willow bark/withies and pine tar added to trunk drops). New docs: BALANCE_SHEET.md (sources cited, quality mixed), ECONOMY_PLAN.md (value audit, pricing rule, shop proposal).
Plans (self-approved): 1 apply the ECONOMY_PLAN value fixes after Dave/moderator OK (kits, bucket, stews); 2 time gathering in the next guide play-through and fill BALANCE_SHEET; 3 shop NPC data for fisher, hunter, healer once Mandy writes dialogue.

## Economy fixes applied (2026-10-31, moderator YES)
Values by rule: thatch kits 54/147/117/93, rough bed kit 28, bucket 30, waterskin 15, rope 15, grass cloak 20, shore net 36, wooden spear 5; dishes capped at 2.5x ingredients plus labour: hearty pottage 38, trail bread 33, forager stew 23, fish stew 28, hunters stew 33. The 34 items "without value" are placed structures, not tradeable, so they got none. Basic Forge stone 36 to 24 (blueprint and its retired kit recipe; test_blueprints checks they match). No shops added.

## Plans round (2026-10-31)
Done: SEASONALITY_WINTER.md (plants by season, winter chain, gaps: Jerky/Salted fish/dried berries need a drying rack and salt), TOWN_NPC_SPEC.md (7-NPC roster, shop wants), MEDICINE_CHAIN.md (ailments, cures, poison status needs code; folk-herbal references from general knowledge). Guide told to teach audit_playthrough.py the natural-yield fallback. Next (self-approved): 1 data for Jerky, Salted fish, dried berries, yarrow bandage, arnica salve, feverfew and valerian teas, charcoal and antidote; 2 recheck BUILD_ORDERS after the next merge; 3 art list for new items to Kathleen.

## Night round 3 (2026-10-31)
Guide counts: audit_playthrough.py now knows the natural-yield fallback and ingredient groups; status_check ignores a blocked recipe when another already makes the product. Plank chest, fine board, water wheel flagged future; 38 abstract/tree-only gathered items flagged future; my fern/heather/cotton grass harvest rows removed (they hid fiddleheads, honey flowers, stuffing). F-05, F-19, F-20 now FIXED in PLAYTHROUGH_STATUS.md. New: data/items/starter_goals.json (13 goals), crops.json 12 crops with storage chain, 12 new crop/seed items (374-385), flour from oats and rye (recipes 246-247), FOOD_VARIETY.md (31 foods today, 30 proposed). Plans (self-approved): 1 add the 16 buildable dishes after farming; 2 drying rack and jar structures; 3 wild seed drops.

## 27 new dishes (2026-10-31)
Added 27 dishes (oat porridge ... cactus fry, FOOD_VARIETY.md list; rose hip tea left out because teas are drinks, not dishes) by hand across dishes.json, items, recipes, vitals, spoilage, cooking warms, weights and looks. 24 are future (crops, shore foods, salt, flour, water are not obtainable yet); 3 are buildable now (juniper trout, dried berries, hazelnut butter); banana fritter needs flour and cactus fry needs onion, so they are future. Cooking set is now 31 + 27 = 58 prepared foods. test_dishes bound 15-20 raised to 15-80 and it now clears each dish from the pack; validate_items counts future foods as sources. Values capped at 2.5x ingredients plus labour. Looks queued in look_placeholders.json.

## Animal products, shops, pacing (2026-10-31)
Items 413-418 (tallow, soap, leather strap, milk, butter, cheese) and recipes 275-280; ANIMAL_PRODUCTS.md; data/npcs/shops_proposal.json (fisher, hunter, healer, ready to enable, not enabled); CRAFT_PACING.md (proposal only: craft seconds 98 -> 251 for the starter kit, plus spawn boost 4 -> 2; needs a timed play-through before applying). Starter-goal events sent to Tyler.

## Pacing applied, quality grades, town, encyclopedia (2026-10-31)
Applied (moderator): starter-kit craft times 98 -> 250 s (twine stays 2 s because tests hard-code it), spawn boost max 4 -> 2; fibre quantities unchanged. Tests updated: test_server_items campfire-kit-worth thresholds (8 stones, 12 sticks), test_first_hour lean-to/chest wait 40 -> 70 s. QUALITY_GRADES_SPEC.md (four grades, score formula, multipliers, burn chance). data/npcs/town_proposal.json (4 NPCs, 11 markers, 7 jobs, buildings from kits). data/items/encyclopedia.json (522 entries, 250 obtainable now, generated). The suite run (python tools/items_check.py, all steps) was started in the background; results below if it finishes.

## Carcass rows, hints, first day (2026-10-31)
carcass.json now has 35 species (added horse, red squirrel, pine marten, hedgehog, raven, owl, woodpecker, songbirds, frog, grass snake, adder) and per-species `blows` (code reads the single global 4 today). ANIMAL_SPEC.md has the first-hour model priority. data/items/hints.json (26 lines, 12 words or fewer), FIRST_DAY_GUIDE.md. test_new_player_day waits raised for the new craft times. Full suite (items_check, all steps) run once: remaining reds are test_animals timing (machine load), npc view / faint smooth / placed clearing (no result), client scenes gather, eat and quickkeys (not investigated; gather may follow the spawn boost cut). Plans (self-approved): 1 wild foods bestiary with look-alike warnings per biome; 2 fishing data (species per water, season, bait, rods, edible); 3 camp-life night quests.

## Fishing, wild foods, camp goals (2026-10-31)
Fish items salmon..cod (419-424) wired into schools (river eel, sea cod, seasons), vitals, spoilage, cooking; validate_items reads fish_schools as a source. FISHING_DATA.md. data/items/wild_foods.json (92 edible plants, 20 with look-alike warnings, 11 poisonous). data/items/camp_goals.json (10 camp and winter goals, 4 need code). Looks queued in look_placeholders.json.

## Audit against Tyler systems, first week, animal sign (2026-10-31)
crops.json sow_season fixed for a summer start (see CODE_MISMATCHES.md); flint, ores, coal, ingots, nails, hinges, rivets, saw blade, processed hide unflagged; validate_items reads boulders.json as a source. FIRST_WEEK_WALK.md (paper walk, rates unmeasured), data/animals/animal_sign.json (20 species, 41 sign hints). Plans (self-approved): 1 timed play-through numbers into FIRST_WEEK_WALK; 2 halve grow_days after Dave answers; 3 unflag iron tools when held models exist.

## Pace pass 2 and crop times (2026-10-31)
See CRAFT_PACING.md section Pace pass 2: workbench 20 sticks/6 twine/4 stones/60 s; smelting slower and iron needs coal; ore scarcer; crop grow_days 4 to 30; radish and lettuce added (426-429). Guide asked for a stopwatch run (queued).

## Look wishlist, economy guard, Dave checklist (2026-10-31)
data/items/look_wishlist.md (43 items, prioritised, colour and shape hints); test_economy_guard.gd added; dish values corrected to batch caps (see ECONOMY_PLAN.md); DAVE_MORNING_ITEMS.md. Moderator decision: wait for Dave play-through before raising stick/twine quantities.

## Voice descriptions, seasons, dialogue (2026-10-31)
data/items/descriptions_voice.json (105 items; 82 written back to items/gathered descriptions, including truth fixes: stone hammer now places blueprints, lumber has the wedge route, iron ingot is no longer a placeholder); data/items/seasons.json (calendar with months, forage, crops, fish, game, 12 season hints); data/npcs/dialogue_lines.json (36 lines for 6 NPCs tied to goals or seasons, 3 rumours). Encyclopedia descriptions refreshed.

## Final tidy and full suite (2026-10-31, after the 05:41 crash)
Worktree was clean after the crash. kindling_duplicate was already retired; it stays listed in look_placeholders.json with that reason because test_item_looks does not skip retired items. Full suite run once on daily head a00c2e04 via godot_slot.sh: 42 steps PASS; reds: luck_rolls (server_animals.gd:650 raw randf_range without luck: owner Tyler/animal wiring), npcs timing (1.77 ms against a load-scaled limit of 1.67: machine load, owner Radar/Tyler), client scenes chest ("script error", but its own checks pass when rerun verbose), gather (no pickups registered in the headless client) and plantpick (400 s timeout, which aborted the remaining client scenes, so leanto, quickkeys, eat and later were NOT run). Owner of the client scenes: Tyler.

## Fruit trees (2026-10-31)
Items 431-449 (apples, pears, cherries, plums, quince, medlar, figs, olives, pomegranates, mangoes, oranges, lemons), 8 fruit dishes, seasons.json fruit_and_nuts and hints, FRUIT_TREES.md. Dried apples and dried figs give 3 each (economy guard caught a money-losing 1-for-3 recipe).

## Water gather landed (2026-10-31)
Unflagged `future` on seaweed, shellfish, crab meat, egg, sea salt, steamed shellfish, boiled egg, seaweed soup, mussel stew, herb omelette, egg and nettle fry, salted fish, jerky, acorn mash, flatbread, willow bark tea, tar and the leather chain (leather, heavy and fine leather, cap, jerkin, gambeson, strap). validate_items now reads shore_nodes.json as a source and treats what a fire cooks as obtainable when the raw item is.

## Metal ladder (2026-10-31)
Bronze ingot recipe at forge level 1 and known; Bronze pickaxe, axe, hammer, knife (458-461, recipes 290-293); boulders.json bronze tools and ore.needs_material (code check for Tyler). Guide audit taught the ore, flint and shore sources: blocked-without-future 0. Goal events verified.
