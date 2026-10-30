# Item decision log (for Dave to review)

Kept by Sal. Dave (2026-10-30): decide on your own, look best practice up on the internet first, ask Dave only if truly needed, and keep a record here. Newest items at the bottom. "Dave" = Dave's own words; "Sal" = my decision. Main working document: `ITEM_GROUPS_AND_NAMES.md`. Branch: `sal-items`.

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
