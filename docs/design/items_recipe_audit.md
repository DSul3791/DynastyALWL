# Recipe and blueprint audit (stage 2 of the items review)

Jamie, 10 Nov 2026, on main plus PR #875 (head aecce080), so names are the new "Tier - Item" ones. Asked for by Dave (playtest, 10 Nov): every recipe should need things that are readily available or that we can make; low tiers few, simple inputs; higher tiers made or bought inputs; common cross-game names. **This is the audit only. Nothing in the data changes until the coordinator rules.**

How it was checked: a script follows every item from where the world gives it (tree and plant drops, butchering, boulders, digging, fishing, nests, the shore, crops, Hob's stall, items the server code hands out) through every live recipe and blueprint, station by station, until nothing new can be made. That shows exactly what can be made today. The judgement flags (b to g) are by reading each recipe against the real-world thing and against Valheim, Vintage Story, Minecraft, Rust, Conan Exiles and Kenshi.

Flags: **a** an input or station has no source in the game; **b** an input makes no real-world sense for the item; **c** over-complicated for its tier, or a dead end; **d** under-specified for its tier; **e** an input's name differs from the common cross-game name; **f** the tree is missing an ingredient item; **g** station or tier inconsistent with its neighbours.

Tiers (from the station): T1 by hand, campfire or campfire pot; T2 workbench, clay hearth; T3 upgraded workbench, oven, sawmill, woodworking table, Stone forge; T4 Blacksmith's forge (forge 2); T5 forge 3 (only the future Large forge).

## Summary

- 242 live recipes and 52 blueprints. 234 recipes can be made today; every blueprint can be built.
- Stations reachable today: campfire 1, campfire_pot 1, clay_hearth 2, forge 2, oven 3, saw_mill 1, woodworking_table 1, workbench 4. Forge level 3 is not reachable (the Large forge is future), so the five steel weapons and armour pieces can never be made, although steel ingots can.
- The metal tree is mostly right. Dave's touchstone (iron sword: smithy, 2 iron ingots, leather) is already the iron sword's recipe. Bronze has no grip, helms have no lining, smelting copper and tin needs no fuel, and nothing is an anvil.
- The early tree is sound and simple: stone tools, twine, the workbench, thatch and the lean-to all come from sticks, stone, plant fibre and thatch.
- The biggest holes are missing items: no Charcoal, no Anvil, no Fur, no Honey, no milk source, no obsidian source, and no yarn or loom step for wool and linen.
- The biggest over-complications are the wood products: Rough plank, Lumber, Hand-split lumber, Fine board, plus 8 species lumber and 8 species beams that nothing uses. There are also cooking recipes that name exact species from different biomes.

## The worst 20, with a proposed fix for each

1. **Steel weapons and armour can never be made.** Steel sword, Steel mace, Steel kite shield, Steel helm, Plate cuirass need forge level 3, which only the future Large forge gives. *Fix:* Make them forge level 2 (the Blacksmith's forge, where steel ingots are already made), or make the Large forge real.
2. **No anvil.** Iron and steel are smithed at a forge with nothing to hammer on. Valheim adds anvils and bellows to its forge; Vintage Story smiths on an anvil. *Fix:* Add an Anvil (e.g. 4 iron ingots, made at the Stone forge) as a forge add-on that raises the forge level, the way the tool rack and vice raise the workbench.
3. **Smelting fuel is inconsistent and there is no charcoal.** Copper and tin smelt with no fuel; iron and steel need Coal from boulders. Charcoal, the common smelting fuel (Minecraft, Vintage Story, Valheim's charcoal kiln), does not exist. *Fix:* Every smelt takes 1 fuel. Add Charcoal (logs or firewood burned in a charcoal pit or kiln) and let Coal count too.
4. **Bronze sword has no grip.** 2 bronze ingots + 1 stick. *Fix:* 2 bronze ingots + 1 leather, as the iron sword (Dave's touchstone). Steel sword: steel ingots + 1 leather (it uses heavy leather now).
5. **Metal helms and mail have no lining.** Bronze and iron helms are ingots only; the steel helm has heavy leather and rivets; the mail shirt has no lining. *Fix:* + 1 leather on every helm and the mail shirt, so the family reads the same.
6. **Butter and cheese need milk, which has no source.** No animal is milked. *Fix:* Mark them future until dairy animals are in, or remove them.
7. **Obsidian knife needs obsidian, which has no source.** No boulder, drop or vendor gives obsidian. *Fix:* Add obsidian to volcanic-ground boulders, or mark the knife future.
8. **Clay pots and jugs are never fired.** 6 or 4 raw clay shaped by hand; bricks, by contrast, are fired at a campfire. *Fix:* Make them at a campfire, like bricks.
9. **Teas with no water and no fire.** Herbal tea is 3 mint by hand; chamomile, stomach and willow bark tea are herbs plus a kept bowl. *Fix:* + 1 water, made at the campfire pot, as nettle tea already is.
10. **Wool and linen go straight from fibre to clothes.** 3 raw wool + twine is a tunic, by hand; 4 flax is 2 linen by hand. *Fix:* One middle step at a loom (a workbench add-on): Wool to Wool cloth, Flax to Linen; clothes then use the cloth. Valheim (linen thread) and Vintage Story (loom) both have it.
11. **Fur clothes are made of plain hide.** Fur cloak, hat and boots use hide + sinew; there is no fur item. *Fix:* Add Fur (from wolves, foxes and bears when butchered); the fur clothes use it.
12. **The gambeson is twine and leather.** A gambeson is a quilted cloth coat. *Fix:* 3 woven cloth + 2 plant fibre (the stuffing) at the workbench.
13. **Four plank items and 16 dead-end species recipes.** Rough plank (only the ladder uses it), Lumber, Hand-split lumber (gives Lumber) and Fine board (used by nothing). The sawmill also makes oak, beech, birch, pine, spruce, tropical, walnut and maple lumber and beams, and nothing uses any of them. *Fix:* One plank item. Keep Lumber or call it Planks, the common name (Minecraft, Vintage Story). Retire Rough plank (the ladder takes lumber) and Fine board. Hide the 16 species recipes until furniture uses them.
14. **Stone and brick ceilings use raw sand.** Stone - Ceiling is cobblestone + sand and Brick - Ceiling is brick + sand, while the walls use mortar. *Fix:* Use mortar, the same as the walls.
15. **Honeyspindle nectar is the game's honey.** Ten recipes sweeten with a fantasy plant's nectar. *Fix:* Call the sweetener Honey, the name every game uses (Valheim, Vintage Story, Conan). Either the nectar becomes Honey, or wild bee nests give Honey and the recipes accept either.
16. **Seed bundle stands in for flour.** Flatbread, Honey loaf and Hearty pottage use seed bundles as grain. *Fix:* Use Flour (farming makes it) or a plain Wild grain. Flatbread stays early through wild grain.
17. **Cooking names exact species from different places.** Mushroom skewer needs porcini + chanterelles + wild garlic; Herb fish needs trout + thyme + coastal samphire; Nut cake needs hazelnuts (forest), dates (desert) and yarrow (a medicine herb). *Fix:* Ingredient groups, as logs and firewood already have: any fish, any mushroom, any herb, any nuts, any berries, any sweetener. Recipes then ask for "1 fish, 1 herb".
18. **Metal station levels differ inside one metal.** Steel spade, hoe and striker are forge 1 while steel needs forge 2. Bronze and iron tools are forge 1 while bronze and iron weapons are forge 2. *Fix:* One rule: the metal sets the forge level (bronze 1, iron 2, steel 2 or 3), for tools and weapons alike.
19. **Basic stone tools and thatch pieces need a workbench.** The stone pickaxe and stone hammer need a workbench while the stone axe, knife and wedge are made by hand. The thatch roof, doorway and foundation need a workbench while the thatch wall does not. *Fix:* By hand and with no station, for all tier 1 stone tools and all thatch pieces.
20. **Small things that make no sense.** Torch: stick + fibre, no fuel. Wooden bowl: carved from firewood. Wooden club: three sticks. Leather cap: leather + fine leather. Compost: three fibres in four seconds. *Fix:* Torch + 1 resin (or fat); bowl and club from a wooden block; cap from 1 leather + 1 strap; compost from a compost heap over time.

## Items the tree is missing (flag f)

| Missing item | Needed by | How it would be obtained | Common in |
|---|---|---|---|
| Anvil (forge add-on) | iron and steel smithing | iron ingots at the Stone forge, placed beside a forge | Valheim, Vintage Story, Kenshi |
| Charcoal | every smelt | logs or firewood in a charcoal pit or kiln | Minecraft, Vintage Story, Valheim (kiln makes Coal), Conan |
| Fur | Fur cloak, hat, boots | butchering wolves, foxes and bears | Valheim (wolf pelt), Conan (thick hide), Vintage Story |
| Honey | 10 sweet recipes | wild bee nests, or rename the nectar | Valheim, Vintage Story, Conan |
| Wool cloth / Linen at a Loom | wool and linen clothes | wool or flax at a loom (workbench add-on) | Valheim (spinning wheel), Vintage Story (loom) |
| Milk source | Butter, Cheese | a dairy animal (goat, cow), later | Vintage Story, Minecraft |
| Obsidian source | Obsidian knife | volcanic-ground boulders | Valheim (obsidian), Ark |
| A forge level 3 that exists | the five steel pieces | the Anvil above, or the Large forge built for real |  |

## Names that differ from the common cross-game name (flag e)

| Ours | Common name | Games |
|---|---|---|
| Lumber (and Rough plank, Fine board) | Planks (one item) | Minecraft, Vintage Story (Valheim: Wood and Fine wood; Conan: Shaped wood) |
| Honeyspindle nectar | Honey | Valheim, Vintage Story, Conan |
| Coal (from boulders) as the only fuel | Charcoal (and Coal) | Minecraft, Vintage Story, Conan |
| Sea salt | Salt | most games |
| Woven cloth | Cloth | Rust, Conan |
| Seed bundle (as grain) | Grain or Flour | Valheim (barley flour), Vintage Story (flour) |
| Brick roof (bricks) | Roof tiles | Vintage Story |

Names that already match the common one: Iron ingot, Copper ingot, Tin ingot, Bronze ingot, Steel ingot, Leather, Hide, Scraped hide, Plant fibre, Twine, Rope, Resin, Tar, Flint, Clay, Brick, Mortar, Sand, Cobblestone, Stone block, Nails, Hinges, Rivets, Tallow, Animal fat, Sinew, Feather, Bone, Thatch, Kindling, Tinder.

## Every recipe

Sorted by category, then tier. Inputs read "count name"; "keep" items are tools that stay in the pack.

| id | name | tier | station | inputs | gives | time s | flags | note |
|---|---|---|---|---|---|---|---|---|
| wicker_shield | Wicker - Shield | T1 | hand | 3 Stick, 2 Plant fibre | 1 Wicker - Shield | 12.0 |  |  |
| plank_shield | Plank - Shield | T2 | workbench | 3 Lumber, 1 Hide, 1 Hide glue | 1 Plank - Shield | 14.0 |  |  |
| leather_jerkin | Leather - Jerkin | T2 | workbench | 2 Leather, 2 Leather strap | 1 Leather - Jerkin | 16.0 |  |  |
| gambeson | Gambeson | T2 | workbench | 3 Twine, 1 Leather, 1 Leather strap | 1 Gambeson | 16.0 | b | A gambeson is quilted cloth; here it is twine and leather. Woven cloth (or linen) and plant fibre stuffing. |
| bronze_shield | Bronze - Kite shield | T4 | forge 2 | 2 Lumber, 1 Bronze ingot | 1 Bronze - Kite shield | 16.0 |  |  |
| iron_shield | Iron - Kite shield | T4 | forge 2 | 2 Lumber, 2 Iron ingot | 1 Iron - Kite shield | 18.0 |  |  |
| bronze_helm | Bronze - Helm | T4 | forge 2 | 3 Bronze ingot | 1 Bronze - Helm | 16.0 | d | Ingots only; a helm needs a leather liner (the steel helm already has one). + 1 leather. |
| iron_helm | Iron - Helm | T4 | forge 2 | 3 Iron ingot | 1 Iron - Helm | 16.0 | d | Ingots only; + 1 leather liner, as the steel helm. |
| mail_shirt | Mail shirt | T4 | forge 2 | 2 Rivets, 2 Iron ingot | 1 Mail shirt | 16.0 | d | No lining; + 1 leather (or a gambeson worn under it). |
| steel_shield | Steel - Kite shield | T5 | forge 3 | 1 Lumber, 2 Steel ingot | 1 Steel - Kite shield | 20.0 | a | Needs forge level 3 (Large forge, future): never makeable. One lumber where bronze and iron use two. |
| steel_helm | Steel - Helm | T5 | forge 3 | 2 Steel ingot, 1 Heavy leather, 1 Rivets | 1 Steel - Helm | 16.0 | a | Needs forge level 3 (Large forge, future): never makeable. |
| plate_cuirass | Plate cuirass | T5 | forge 3 | 3 Steel ingot, 1 Heavy leather, 2 Rivets | 1 Plate cuirass | 16.0 | a | Needs forge level 3 (Large forge, future): never makeable. |
| grass_skirt | Grass - Skirt | T1 | hand | 8 Plant fibre | 1 Grass - Skirt | 6.0 |  |  |
| grass_cloak | Grass - Cloak | T1 | hand | 16 Plant fibre, 1 Twine | 1 Grass - Cloak | 10.0 |  |  |
| fibre_sandals | Fibre - Sandals | T1 | hand | 6 Plant fibre, 1 Twine | 1 Fibre - Sandals | 8.0 |  |  |
| hide_cloak | Hide - Cloak | T1 | hand | 3 Hide, 2 Twine | 1 Hide - Cloak | 14.0 |  |  |
| hide_boots | Hide - Boots | T1 | hand | 2 Hide, 2 Twine | 1 Hide - Boots | 14.0 |  |  |
| hide_hood | Hide - Hood | T1 | hand | 1 Hide, 1 Twine | 1 Hide - Hood | 8.0 |  |  |
| hide_mittens | Hide - Mittens | T1 | hand | 1 Hide, 1 Twine | 1 Hide - Mittens | 8.0 |  |  |
| hide_leggings | Hide - Leggings | T1 | hand | 3 Hide, 2 Twine | 1 Hide - Leggings | 14.0 |  |  |
| quiver | Quiver | T1 | hand | 2 Hide, 2 Twine | 1 Quiver | 6.0 |  |  |
| hide_tunic | Hide - Tunic | T1 | hand | 3 Hide, 2 Twine | 1 Hide - Tunic | 16.0 |  |  |
| hide_trousers | Hide - Trousers | T1 | hand | 3 Hide, 2 Twine | 1 Hide - Trousers | 16.0 |  |  |
| hide_gloves | Hide - Gloves | T1 | hand | 1 Hide, 2 Twine | 1 Hide - Gloves | 12.0 |  |  |
| leather_cap | Leather - Cap | T1 | hand | 1 Leather, 1 Fine leather | 1 Leather - Cap | 16.0 | c | Leather plus Fine leather for a cap: two kinds of leather for the simplest leather item. 1 leather (+ 1 leather strap). |
| wool_tunic | Wool - Tunic | T1 | hand | 3 Wool, 1 Twine | 1 Wool - Tunic | 16.0 | d f | Raw wool straight into a tunic by hand: no spinning or weaving. Common games put a step between: yarn or cloth at a loom or spinning wheel (Valheim linen thread, Vintage Story loom). |
| wool_trousers | Wool - Trousers | T1 | hand | 3 Wool, 1 Twine | 1 Wool - Trousers | 16.0 | d f | As wool tunic. |
| wool_cap | Wool - Cap | T1 | hand | 2 Wool | 1 Wool - Cap | 16.0 | d f | As wool tunic. |
| wool_mittens | Wool - Mittens | T1 | hand | 2 Wool | 1 Wool - Mittens | 16.0 | d f | As wool tunic. |
| linen_shirt | Linen - Shirt | T1 | hand | 3 Linen, 1 Twine | 1 Linen - Shirt | 16.0 |  |  |
| fur_cloak | Fur - Cloak | T1 | hand | 3 Hide, 2 Sinew | 1 Fur - Cloak | 16.0 | b f | A fur cloak from plain hide: there is no Fur (pelt) item. Fur from wolves, foxes and bears is the common ingredient. |
| fur_hat | Fur - Hat | T1 | hand | 1 Hide, 1 Sinew | 1 Fur - Hat | 16.0 | b f | As fur cloak. |
| fur_boots | Fur - Boots | T1 | hand | 2 Hide, 1 Sinew | 1 Fur - Boots | 16.0 | b f | As fur cloak. |
| wooden_bowl | Wooden bowl | T1 | hand | 1 Firewood | 1 Wooden bowl | 6.0 | b | Carved from a piece of firewood; a wooden block (and a knife kept) makes more sense. |
| clay_pot | Clay pot | T1 | hand | 6 Clay | 1 Clay pot | 12.0 | b | Raw clay shaped by hand and never fired, while bricks are fired at a campfire. Fire it at a campfire like brick. |
| bucket | Bucket | T1 | hand | 6 Lumber, 2 Twine | 1 Bucket | 10.0 |  |  |
| waterskin | Waterskin | T1 | hand | 2 Hide, 1 Twine | 1 Waterskin | 8.0 |  |  |
| backpack | Backpack | T1 | hand | 4 Hide, 1 Rope | 1 Backpack | 20.0 |  |  |
| rough_bed_kit | Rough bed (thatch) | T1 | hand | 10 Thatch, 4 Stick, 2 Twine | 1 Rough bed | 25.0 |  |  |
| clay_jug | Clay jug | T1 | hand | 4 Clay | 1 Clay jug | 14.0 | b | As clay pot. |
| rough_bed_bedding | Rough bed (bedding) | T1 | hand | 8 Bedding, 4 Stick, 2 Twine | 1 Rough bed | 10.0 |  |  |
| rough_bed_straw | Rough bed (straw) | T1 | hand | 8 Straw, 4 Stick, 2 Twine | 1 Rough bed | 10.0 |  |  |
| cook_berry_compote | Berry compote | T1 | campfire_pot | 2 Blueberries, 1 Honeyspindle nectar | 2 Berry compote | 6.0 | e | Honeyspindle nectar is the sweetener: common name Honey. |
| cook_nut_paste | Nut paste | T1 | campfire_pot | 3 Hazelnuts, 1 Honeyspindle nectar | 2 Nut paste | 6.0 | e | Honeyspindle nectar = honey. |
| cook_acorn_mash | Acorn mash | T1 | campfire_pot | 3 Acorns, 1 Water | 2 Acorn mash | 8.0 |  |  |
| cook_herb_fish | Herb fish | T1 | campfire | 1 Trout, 1 Thyme, 1 Samphire | 1 Herb fish | 8.0 | c | Trout + thyme + samphire (a coastal plant): three named species from different places. |
| cook_garlic_meat | Garlic meat | T1 | campfire | 1 Raw meat, 1 Wild garlic leaves, 1 Rosemary | 1 Garlic meat | 8.0 |  |  |
| cook_smoked_fish | Smoked fish | T1 | campfire | 1 Pike, 1 Samphire, 1 Juniper berries | 1 Smoked fish | 10.0 | c | Pike + samphire + juniper berries for smoked fish; smoking needs fish and a fire (+ salt). |
| cook_hunters_stew | Hunter's stew | T1 | campfire_pot | 1 Raw meat, 1 Wild carrot roots, 1 Wild garlic leaves | 2 Hunter's stew | 12.0 |  |  |
| cook_forager_stew | Forager's stew | T1 | campfire_pot | 2 Nettles, 1 Burdock roots, 1 Chanterelles | 2 Forager's stew | 12.0 |  |  |
| cook_fish_stew | Fish stew | T1 | campfire_pot | 1 Perch, 1 Watercress, 1 Wild carrot roots | 2 Fish stew | 12.0 |  |  |
| cook_hearty_pottage | Hearty pottage | T1 | campfire_pot | 2 Seeds, 1 Wild carrot roots, 1 Dandelion flowers, 1 Marjoram, 1 Animal fat | 3 Hearty pottage | 14.0 | c | Five different inputs for a pottage, two of them herbs. |
| cook_feast_roast | Roast beast | T1 | campfire | 2 Raw meat, 1 Wild garlic leaves, 1 Thyme, 1 Rosemary, 1 Animal fat | 2 Roast beast | 14.0 | c | Five inputs, three of them herbs. Fine for a feast, but "any herb" would help. |
| kindling | Kindling | T1 | hand | 1 Stick | 3 Kindling | 2.0 |  |  |
| candle | Candle | T1 | hand | 1 Animal fat, 1 Plant fibre | 2 Candle | 6.0 |  |  |
| tinder | Tinder | T1 | hand | 2 Thatch | 2 Tinder | 3.0 |  |  |
| cook_oat_porridge | Oat porridge | T1 | campfire_pot | 2 Oats, 1 Water, 1 Hazelnuts | 2 Oat porridge | 12.0 |  |  |
| cook_barley_broth | Barley broth | T1 | campfire_pot | 2 Barley, 1 Wild carrot roots, 1 Water | 2 Barley broth | 12.0 |  |  |
| cook_pea_soup | Pea soup | T1 | campfire_pot | 2 Peas, 1 Onion, 1 Water | 2 Pea soup | 12.0 |  |  |
| cook_turnip_mash | Turnip mash | T1 | campfire_pot | 2 Turnip, 1 Animal fat | 2 Turnip mash | 10.0 |  |  |
| cook_cabbage_stew | Cabbage stew | T1 | campfire_pot | 1 Cabbage, 1 Raw meat, 1 Onion | 2 Cabbage stew | 14.0 |  |  |
| cook_seaweed_soup | Seaweed soup | T1 | campfire_pot | 2 Seaweed, 1 Shellfish, 1 Water | 2 Seaweed soup | 10.0 |  |  |
| cook_mussel_stew | Mussel stew | T1 | campfire_pot | 3 Shellfish, 1 Wild garlic leaves, 1 Water | 2 Mussel stew | 12.0 |  |  |
| cook_crab_cakes | Crab cakes | T1 | campfire | 2 Crab meat, 1 Flour | 2 Crab cakes | 10.0 |  |  |
| cook_egg_nettle_fry | Egg and nettle fry | T1 | campfire_pot | 2 Egg, 1 Nettles, 1 Animal fat | 2 Egg and nettle fry | 8.0 |  |  |
| cook_herb_omelette | Herb omelette | T1 | campfire_pot | 3 Egg, 1 Thyme | 2 Herb omelette | 8.0 |  |  |
| cook_seal_stew | Seal stew | T1 | campfire_pot | 1 Seal meat, 1 Turnip, 1 Water | 2 Seal stew | 14.0 |  |  |
| cook_juniper_trout | Juniper trout | T1 | campfire | 1 Trout, 1 Juniper berries | 1 Juniper trout | 10.0 |  |  |
| cook_jerky | Jerky | T1 | campfire | 2 Raw meat, 1 Sea salt | 2 Jerky | 12.0 |  |  |
| cook_salted_fish | Salted fish | T1 | campfire_pot | 1 Trout, 1 Sea salt | 1 Salted fish | 10.0 |  |  |
| cook_sauerkraut | Sauerkraut | T1 | campfire_pot | 2 Cabbage, 1 Sea salt | 2 Sauerkraut | 12.0 |  |  |
| cook_hazelnut_butter | Hazelnut butter | T1 | campfire_pot | 3 Hazelnuts | 1 Hazelnut butter | 8.0 |  |  |
| tallow_candle | Tallow candle | T1 | hand | 1 Tallow, 1 Plant fibre | 3 Candle | 8.0 |  |  |
| butter | Butter | T1 | hand | 3 Milk | 1 Butter | 20.0 | a | Milk has no source: no dairy animal is milked. No source in game: Milk. |
| cheese | Cheese | T1 | campfire_pot | 4 Milk, 1 Sea salt | 1 Cheese | 30.0 | a | Milk has no source. No source in game: Milk. |
| sea_salt | Sea salt | T1 | campfire_pot | 2 Sea water | 1 Sea salt | 20.0 | e | Common name: Salt. |
| cook_apple_sauce | Apple sauce | T1 | campfire_pot | 3 Cooking apple, 1 Honeyspindle nectar | 2 Apple sauce | 10.0 | e | Honeyspindle nectar = honey. |
| cook_plum_jam | Plum jam | T1 | campfire_pot | 3 Plums, 1 Honeyspindle nectar | 2 Plum jam | 12.0 | e | Honeyspindle nectar = honey. |
| cook_stewed_pears | Stewed pears | T1 | campfire_pot | 2 Autumn pear, 1 Honeyspindle nectar | 2 Stewed pears | 10.0 | e | Honeyspindle nectar = honey. |
| cook_preserved_damsons | Preserved damsons | T1 | campfire_pot | 3 Damsons, 1 Honeyspindle nectar | 2 Preserved damsons | 12.0 | e | Honeyspindle nectar = honey. |
| cook_quince_paste | Quince paste | T1 | campfire_pot | 2 Quince, 1 Honeyspindle nectar | 2 Quince paste | 14.0 | e | Honeyspindle nectar = honey. |
| stew_raspberries | Stewed raspberries | T1 | campfire_pot | 3 Raspberries, 1 Water | 2 Stewed berries | 8.0 |  |  |
| stew_blueberries | Stewed blueberries | T1 | campfire_pot | 3 Blueberries, 1 Water | 2 Stewed berries | 8.0 |  |  |
| stew_blackberries | Stewed blackberries | T1 | campfire_pot | 3 Blackberries, 1 Water | 2 Stewed berries | 8.0 |  |  |
| stew_strawberries | Stewed strawberries | T1 | campfire_pot | 3 Strawberries, 1 Water | 2 Stewed berries | 8.0 |  |  |
| boil_eggs | Boiled egg | T1 | campfire_pot | 2 Egg, 1 Water | 2 Boiled egg | 8.0 |  |  |
| cook_roast_roots | Roast roots | T2 | clay_hearth | 2 Burdock roots, 2 Wild carrot roots | 2 Roast roots | 8.0 |  |  |
| cook_baked_apples | Baked apples | T2 | clay_hearth | 3 Crab apples, 1 Honeyspindle nectar | 2 Baked apples | 8.0 | e | Honeyspindle nectar = honey. |
| cook_mushroom_skewer | Mushroom skewer | T2 | clay_hearth | 2 Porcini, 1 Chanterelles, 1 Wild garlic leaves | 2 Mushroom skewer | 8.0 | c | Two named mushrooms plus wild garlic; "any mushroom" would do. |
| cook_chestnut_cakes | Chestnut cakes | T2 | clay_hearth | 3 Chestnuts, 1 Honeyspindle nectar, 1 Linseed | 3 Chestnut cakes | 10.0 | e | Honeyspindle nectar = honey. |
| cook_fruit_leather | Fruit leather | T2 | clay_hearth | 2 Crab apples, 1 Cranberries, 1 Honeyspindle nectar | 3 Fruit leather | 10.0 | e | Honeyspindle nectar = honey. |
| cook_trail_bread | Trail bread | T2 | clay_hearth | 2 Linseed, 2 Hazelnuts, 1 Animal fat | 3 Trail bread | 12.0 |  |  |
| cook_flatbread | Flatbread | T2 | clay_hearth | 3 Seeds, 1 Water | 2 Flatbread | 8.0 | b e | Flatbread from a seed bundle: wild seed stands in for grain or flour. |
| cook_rye_flatbread | Rye flatbread | T2 | clay_hearth | 2 Flour, 1 Water, 1 Sea salt | 2 Rye flatbread | 8.0 |  |  |
| cook_baked_potato | Baked potato | T2 | clay_hearth | 2 Potato, 1 Animal fat | 2 Baked potato | 10.0 |  |  |
| cook_beet_roast | Beet roast | T2 | clay_hearth | 2 Beet, 1 Thyme | 2 Beet roast | 10.0 |  |  |
| cook_onion_roast | Onion roast | T2 | clay_hearth | 2 Onion, 1 Animal fat | 2 Onion roast | 8.0 |  |  |
| cook_garlic_bread | Garlic bread | T2 | clay_hearth | 2 Flour, 1 Wild garlic leaves | 2 Garlic bread | 8.0 |  |  |
| cook_oat_cakes | Oat cakes | T2 | clay_hearth | 2 Oats, 1 Animal fat | 2 Oat cakes | 8.0 |  |  |
| cook_dried_berries | Dried berries | T2 | clay_hearth | 3 Blueberries | 1 Dried berries | 10.0 |  |  |
| cook_banana_fritter | Banana fritter | T2 | clay_hearth | 2 Bananas, 1 Flour | 2 Banana fritter | 8.0 |  |  |
| cook_cactus_fry | Cactus fry | T2 | clay_hearth | 1 Prickly pears, 1 Onion | 1 Cactus fry | 8.0 |  |  |
| cook_dried_apples | Dried apples | T2 | clay_hearth | 3 Autumn apple | 3 Dried apples | 10.0 |  |  |
| cook_dried_figs | Dried figs | T2 | clay_hearth | 3 Figs | 3 Dried figs | 10.0 |  |  |
| roast_hazelnuts | Roasted hazelnuts | T2 | clay_hearth | 3 Hazelnuts | 2 Roasted forage | 10.0 |  |  |
| roast_chestnuts | Roasted chestnuts | T2 | clay_hearth | 3 Chestnuts | 2 Roasted forage | 10.0 |  |  |
| roast_walnuts | Roasted walnuts | T2 | clay_hearth | 3 Walnuts | 2 Roasted forage | 10.0 |  |  |
| roast_beechnuts | Roasted beechnuts | T2 | clay_hearth | 3 Beechnuts | 2 Roasted forage | 10.0 |  |  |
| roast_morels | Roasted morels | T2 | clay_hearth | 3 Morels | 2 Roasted forage | 10.0 |  |  |
| roast_bananas | Roasted bananas | T2 | clay_hearth | 2 Bananas | 2 Roasted forage | 10.0 |  |  |
| roast_fiddleheads | Roasted fiddleheads | T2 | clay_hearth | 3 Fiddleheads | 2 Roasted forage | 10.0 |  |  |
| roast_wild_pears | Roasted pears | T2 | clay_hearth | 3 Wild pears | 2 Roasted forage | 10.0 |  |  |
| cook_honey_loaf | Honey loaf | T3 | oven | 3 Seeds, 1 Hazelnuts, 1 Honeyspindle nectar | 2 Honey loaf | 12.0 | b e | Seed bundle as flour; honeyspindle nectar as honey. |
| cook_roast_joint | Rosemary joint | T3 | oven | 2 Raw meat, 1 Rosemary, 1 Wild garlic leaves | 2 Rosemary joint | 14.0 |  |  |
| cook_venison_pie | Venison pie | T3 | oven | 1 Raw meat, 1 Flour, 1 Animal fat | 2 Venison pie | 14.0 |  |  |
| cook_fish_pie | Fish pie | T3 | oven | 1 Trout, 1 Flour, 1 Onion | 2 Fish pie | 14.0 |  |  |
| cook_apple_pie | Apple pie | T3 | oven | 2 Cooking apple, 1 Flour, 1 Animal fat | 2 Apple pie | 14.0 |  |  |
| energy_bar | Nut cake | T1 | hand | 3 Hazelnuts, 2 Dates, 1 Yarrow | 2 Nut cake | 6.0 | b c | Hazelnuts (temperate), dates (desert) and yarrow (a medicine herb) for a starter snack. Nuts + a sweetener. |
| herbal_tea | Herbal tea | T1 | hand | 3 Mint | 1 Herbal tea | 4.0 | b | Three mint leaves become tea with no water and no fire. Nettle tea already does it right: + 1 water, at the campfire pot. |
| stomach_tea | Stomach tea | T1 | hand | 2 Mint, 2 Chamomile flowers; keep Wooden bowl | 1 Stomach tea | 5.0 | b | No water, no heat. + 1 water, campfire pot. |
| chamomile_tea | Chamomile tea | T1 | hand | 3 Chamomile flowers; keep Wooden bowl | 1 Chamomile tea | 5.0 | b | No water, no heat (keeps a bowl). + 1 water, campfire pot. |
| willow_bark_tea | Willow bark tea | T1 | hand | 2 Willow bark; keep Wooden bowl | 1 Willow bark tea | 5.0 | b | No water, no heat. + 1 water, campfire pot. |
| nettle_tea | Nettle tea | T1 | campfire_pot | 3 Nettles, 1 Water | 1 Nettle tea | 6.0 |  |  |
| twine | Twine | T1 | hand | 3 Plant fibre | 1 Twine | 2.0 |  |  |
| twine_bark | Bark twine | T1 | hand | 2 Bark | 1 Twine | 3.0 |  |  |
| rope | Rope | T1 | hand | 4 Twine | 1 Rope | 5.0 |  |  |
| sinew_cord | Sinew cord | T1 | hand | 3 Sinew | 2 Twine | 6.0 |  |  |
| brick | Brick | T1 | campfire | 2 Clay | 3 Brick | 14.0 |  | Fired at a campfire; a kiln is the usual station (Vintage Story pit kiln) but a campfire is fine for tier 1. |
| mortar | Mortar | T1 | hand | 2 Sand, 1 Clay | 2 Mortar | 8.0 |  | Sand + clay; real mortar is lime + sand, but nothing in the game makes lime, so this is fine. |
| tar | Tar | T1 | campfire | 5 Pine pitch | 1 Tar | 12.0 |  |  |
| lumber_by_hand | Lumber by hand | T1 | hand | 1 Log; keep Hand saw | 2 Lumber | 24.0 |  |  |
| processed_hide | Scraped hide | T1 | hand | 1 Hide; keep Hide scraper | 1 Scraped hide | 8.0 |  |  |
| flour_from_wheat | Flour | T1 | hand | 3 Wheat; keep Hand mill | 2 Flour | 10.0 |  |  |
| flour_from_barley | Barley flour | T1 | hand | 3 Barley; keep Hand mill | 2 Flour | 10.0 |  |  |
| compost | Compost | T1 | hand | 3 Plant fibre | 1 Compost | 4.0 | b | Three fibres become compost in four seconds; compost is a heap that rots over days. |
| hide_glue | Hide glue | T1 | campfire_pot | 1 Hide | 2 Hide glue | 12.0 |  |  |
| leather | Leather | T1 | campfire_pot | 1 Scraped hide, 2 Tannin-rich bark, 1 Water | 1 Leather | 30.0 |  | Scraped hide + tannin-rich bark + water: real tanning, and Conan and Vintage Story do the same. |
| heavy_leather | Heavy leather | T1 | campfire_pot | 2 Leather, 2 Tannin-rich bark | 1 Heavy leather | 40.0 |  |  |
| fine_leather | Fine leather | T1 | campfire_pot | 1 Leather, 1 Animal fat | 1 Fine leather | 30.0 |  | Leather worked with fat: sensible. |
| linen | Linen | T1 | hand | 4 Flax | 2 Linen | 20.0 | d | Flax to linen by hand in one step (no retting, spinning or loom). |
| flour_from_oats | Oat flour | T1 | hand | 3 Oats; keep Hand mill | 2 Flour | 10.0 |  |  |
| flour_from_rye | Rye flour | T1 | hand | 3 Rye; keep Hand mill | 2 Flour | 10.0 |  |  |
| tallow | Tallow | T1 | campfire_pot | 2 Animal fat | 1 Tallow | 14.0 |  |  |
| soap | Soap | T1 | campfire_pot | 2 Tallow, 1 Potash | 1 Soap | 16.0 |  |  |
| leather_strap | Leather strap | T1 | hand | 1 Leather; keep Stone - Knife | 2 Leather strap | 6.0 |  |  |
| fibre_cloth | Woven cloth | T1 | hand | 8 Plant fibre | 1 Woven cloth | 30.0 |  |  |
| compost_rotten | Compost from rotten food | T1 | hand | 2 Rotten food | 1 Compost | 4.0 |  |  |
| fibre_rope | Rope from fibre | T1 | hand | 12 Plant fibre | 1 Rope | 6.0 |  |  |
| small_blocks_from_large | Small wooden blocks | T1 | hand | 1 Large wooden block; keep Stone - Axe | 4 Wooden block | 4.0 |  |  |
| small_soft_blocks_from_large | Small softwood blocks | T1 | hand | 1 Large softwood block; keep Stone - Axe | 4 Softwood block | 4.0 |  |  |
| cut_stone_block | Stone block | T2 | workbench | 8 Stone | 1 Stone block | 20.0 |  |  |
| rough_plank | Rough plank | T2 | workbench | 1 Log | 4 Rough plank | 6.0 | c e | Rough plank, Lumber, Hand-split lumber and Fine board are four plank items; only the ladder uses rough planks. One "Planks" item is the common name (Minecraft, Vintage Story). |
| cobblestone | Cobblestone | T2 | workbench | 3 Stone | 1 Cobblestone | 6.0 |  |  |
| stone_shingle | Stone shingle | T2 | workbench | 2 Stone | 1 Stone shingle | 6.0 |  |  |
| wooden_pin | Wooden pin | T2 | workbench | 1 Lumber | 20 Wooden pin | 5.0 |  |  |
| lumber_wedge | Hand-split lumber | T2 | workbench | 1 Log; keep Stone - Wedge | 2 Lumber | 14.0 |  | The early route to lumber before the sawmill: good. |
| lumber | Lumber | T3 | saw_mill | 1 Log | 4 Lumber | 6.0 | e | Common name: Planks (Minecraft, Vintage Story); Valheim says Wood or Fine wood, Conan says Shaped wood. |
| lumber_oak | Oak lumber | T3 | saw_mill | 1 Oak logs | 6 Oak lumber | 6.0 | c | Makes Oak lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_oak | Oak beams | T3 | saw_mill | 1 Oak logs | 2 Oak beams | 8.0 | c | Makes Oak beams, which nothing uses (species lumber and beams are a dead end). |
| lumber_beech | Beech lumber | T3 | saw_mill | 1 Beech logs | 6 Beech lumber | 6.0 | c | Makes Beech lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_beech | Beech beams | T3 | saw_mill | 1 Beech logs | 2 Beech beams | 8.0 | c | Makes Beech beams, which nothing uses (species lumber and beams are a dead end). |
| lumber_birch | Birch lumber | T3 | saw_mill | 1 Birch logs | 6 Birch lumber | 6.0 | c | Makes Birch lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_birch | Birch beams | T3 | saw_mill | 1 Birch logs | 2 Birch beams | 8.0 | c | Makes Birch beams, which nothing uses (species lumber and beams are a dead end). |
| lumber_scots_pine | Scots pine lumber | T3 | saw_mill | 1 Scots pine logs | 7 Scots pine lumber | 5.0 | c | Makes Scots pine lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_scots_pine | Scots pine beams | T3 | saw_mill | 1 Scots pine logs | 2 Scots pine beams | 6.0 | c | Makes Scots pine beams, which nothing uses (species lumber and beams are a dead end). |
| lumber_spruce | Spruce lumber | T3 | saw_mill | 1 Spruce logs | 7 Spruce lumber | 5.0 | c | Makes Spruce lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_spruce | Spruce beams | T3 | saw_mill | 1 Spruce logs | 2 Spruce beams | 6.0 | c | Makes Spruce beams, which nothing uses (species lumber and beams are a dead end). |
| lumber_tropical_hardwood | Tropical hardwood lumber | T3 | saw_mill | 1 Tropical hardwood logs | 6 Tropical hardwood lumber | 6.0 | c | Makes Tropical hardwood lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_tropical_hardwood | Tropical hardwood beams | T3 | saw_mill | 1 Tropical hardwood logs | 2 Tropical hardwood beams | 8.0 | c | Makes Tropical hardwood beams, which nothing uses (species lumber and beams are a dead end). |
| lumber_walnut | Walnut lumber | T3 | saw_mill | 1 Walnut logs | 6 Walnut lumber | 6.0 | c | Makes Walnut lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_walnut | Walnut beams | T3 | saw_mill | 1 Walnut logs | 2 Walnut beams | 8.0 | c | Makes Walnut beams, which nothing uses (species lumber and beams are a dead end). |
| lumber_maple | Sugar maple lumber | T3 | saw_mill | 1 Sugar maple logs | 6 Sugar maple lumber | 6.0 | c | Makes Sugar maple lumber, which nothing uses (species lumber and beams are a dead end). |
| beams_maple | Sugar maple beams | T3 | saw_mill | 1 Sugar maple logs | 2 Sugar maple beams | 8.0 | c | Makes Sugar maple beams, which nothing uses (species lumber and beams are a dead end). |
| fine_board | Fine board | T3 | woodworking_table | 1 Lumber | 1 Fine board | 4.0 | c | Made at the woodworking table and used by nothing. |
| nails | Nails | T3 | forge | 1 Iron ingot | 100 Nails | 10.0 |  | 1 iron ingot gives 100 nails: generous but sensible. |
| hinges | Hinges | T3 | forge | 1 Iron ingot | 20 Hinges | 8.0 |  |  |
| saw_blade | Saw blade | T3 | forge | 2 Iron ingot | 1 Saw blade | 20.0 |  |  |
| rivets | Rivets | T3 | forge | 1 Iron ingot | 50 Rivets | 8.0 |  |  |
| bronze_ingot | Bronze ingot | T3 | forge | 1 Copper ingot, 1 Tin ingot | 2 Bronze ingot | 10.0 |  | Copper + tin at the forge: sensible (Valheim and Vintage Story alloy the same way). |
| smelt_copper | Copper ingot | T3 | forge | 3 Copper ore | 1 Copper ingot | 30.0 | f g | No fuel, while iron needs coal. Every smelt should burn fuel (Charcoal or Coal). |
| smelt_tin | Tin ingot | T3 | forge | 3 Tin ore | 1 Tin ingot | 30.0 | f g | No fuel, while iron needs coal. |
| smelt_iron | Iron ingot | T3 | forge | 4 Iron ore, 1 Coal | 1 Iron ingot | 45.0 | e | Fuel is "coal" from boulders; the common route is Charcoal (Minecraft, Vintage Story, Valheim's charcoal kiln). No charcoal item exists. |
| smelt_steel | Steel ingot | T4 | forge 2 | 2 Iron ingot, 1 Coal | 1 Steel ingot | 14.0 |  | Iron + coal at the Blacksmith's forge: sensible. |
| poultice_plantain | Plantain poultice | T1 | hand | 3 Plantain leaves | 1 Herb poultice | 3.0 |  |  |
| poultice_comfrey | Comfrey poultice | T1 | hand | 2 Comfrey leaves | 1 Herb poultice | 3.0 |  |  |
| bandage_plantain | Leaf bandage | T1 | hand | 1 Plantain leaves, 2 Plant fibre | 1 Herb bandage | 3.0 |  |  |
| bandage_staunchmoss | Mossy bandage | T1 | hand | 1 Staunchmoss, 2 Plant fibre | 2 Herb bandage | 3.0 |  |  |
| herb_salve | Herb salve | T1 | hand | 2 Comfrey leaves, 1 Animal fat | 2 Herb salve | 10.0 |  |  |
| splint | Splint | T1 | hand | 2 Stick, 1 Twine | 1 Splint | 6.0 |  |  |
| campfire | Campfire | T1 | hand | 6 Stick, 3 Stone | 1 Campfire | 8.0 |  |  |
| rock_pile | Rock pile | T1 | hand | 45 Stone | 1 Rock pile | 20.0 |  |  |
| stone_axe | Stone - Axe | T1 | hand | 1 Stone, 1 Stick, 2 Twine | 1 Stone - Axe | 10.0 |  |  |
| stone_knife | Stone - Knife | T1 | hand | 2 Stone, 1 Stick | 1 Stone - Knife | 8.0 |  |  |
| torch | Torch | T1 | hand | 1 Stick, 2 Plant fibre | 1 Torch | 2.0 | b | Stick and plant fibre with no fuel. Valheim and most games use resin or fat on the head: + 1 resin (or animal fat). |
| wooden_spade | Wooden - Spade | T1 | hand | 2 Stick; keep Stone | 1 Wooden - Spade | 8.0 |  |  |
| fishing_rod | Fishing rod | T1 | hand | 2 Stick, 2 Twine | 1 Fishing rod | 8.0 |  |  |
| wooden_hoe | Wooden - Hoe | T1 | hand | 2 Stick, 1 Twine; keep Stone | 1 Wooden - Hoe | 8.0 |  |  |
| wooden_hammer | Wooden - Hammer | T1 | hand | 1 Wooden block, 1 Stick, 1 Twine | 1 Wooden - Hammer | 5.0 |  |  |
| shore_net | Fishing net | T1 | hand | 3 Rope, 4 Stone | 1 Fishing net | 12.0 |  |  |
| wooden_arrow | Wooden - Arrow | T1 | hand | 2 Stick, 2 Feather | 4 Wooden - Arrow | 4.0 |  |  |
| stone_arrow | Stone - Arrow | T1 | hand | 2 Stick, 2 Feather, 2 Stone | 4 Stone - Arrow | 6.0 |  |  |
| snare | Snare | T1 | hand | 3 Twine, 2 Stick | 1 Snare | 6.0 |  |  |
| quern | Hand mill | T1 | hand | 2 Stone, 1 Stick | 1 Hand mill | 10.0 |  |  |
| bone_arrow | Bone - Arrow | T1 | hand | 2 Stick, 2 Feather, 2 Bone | 4 Bone - Arrow | 6.0 |  |  |
| stone_wedge | Stone - Wedge | T1 | hand | 2 Stone, 1 Stick | 1 Stone - Wedge | 8.0 |  |  |
| fibre_arrow | Fibre - Arrow | T1 | hand | 2 Stick, 1 Plant fibre | 4 Fibre - Arrow | 4.0 |  |  |
| wooden_hammer_soft | Wooden - Hammer (softwood) | T1 | hand | 1 Softwood block, 1 Stick, 1 Twine | 1 Wooden - Hammer | 5.0 |  |  |
| quill_arrow | Quill arrows | T1 | hand | 2 Stick, 1 Quill | 4 Wooden - Arrow | 4.0 |  |  |
| stone_spade | Stone - Spade | T2 | workbench | 1 Wooden - Spade, 2 Stone, 1 Twine | 1 Stone - Spade | 8.0 |  | Upgrades the wooden spade: sensible. |
| stone_hoe | Stone - Hoe | T2 | workbench | 1 Wooden - Hoe, 2 Stone, 1 Twine | 1 Stone - Hoe | 10.0 |  | Upgrades the wooden hoe: sensible. |
| stone_hammer | Stone - Hammer | T2 | workbench | 1 Stone, 1 Stick, 1 Twine | 1 Stone - Hammer | 15.0 | g | Workbench, while the wooden hammer is by hand. |
| hand_saw | Hand saw | T2 | workbench | 1 Saw blade, 2 Stick, 2 Twine | 1 Hand saw | 10.0 |  |  |
| hide_scraper | Hide scraper | T2 | workbench | 1 Flint, 1 Stick, 1 Twine | 1 Hide scraper | 6.0 |  |  |
| obsidian_knife | Obsidian - Knife | T2 | workbench | 1 Obsidian, 1 Stick, 1 Twine | 1 Obsidian - Knife | 6.0 | a | Obsidian has no source (no drop, boulder or vendor). No source in game: Obsidian. |
| stone_pickaxe | Stone - Pickaxe | T2 | workbench | 2 Stick, 3 Stone, 2 Twine | 1 Stone - Pickaxe | 25.0 | g | Needs a workbench while the stone axe, knife and wedge are made by hand. Rust and Valheim make the first pickaxe by hand. |
| sickle | Sickle | T2 | workbench | 1 Flint, 1 Stick, 1 Twine | 1 Sickle | 6.0 |  | Flint sickle: real (stone age) and early. |
| iron_pickaxe | Iron - Pickaxe | T3 | forge | 3 Iron ingot, 2 Stick | 1 Iron - Pickaxe | 10.0 | g | Forge 1 while iron weapons are forge 2; a rule (metal sets the level) would make these consistent. |
| iron_spade | Iron - Spade | T3 | forge | 2 Iron ingot, 2 Stick | 1 Iron - Spade | 10.0 | g | As iron pickaxe. |
| steel_spade | Steel - Spade | T3 | forge | 2 Steel ingot, 2 Stick | 1 Steel - Spade | 12.0 | g | Forge level 1, but steel ingots need forge level 2: the levels of one metal differ by item. |
| iron_hoe | Iron - Hoe | T3 | forge | 2 Iron ingot, 2 Stick | 1 Iron - Hoe | 12.0 | g | As iron pickaxe. |
| steel_hoe | Steel - Hoe | T3 | forge | 2 Steel ingot, 2 Stick | 1 Steel - Hoe | 14.0 | g | Forge level 1 while steel ingots need level 2. |
| steel_striker | Steel - Striker | T3 | forge | 1 Steel ingot | 1 Steel - Striker | 8.0 | g | Forge level 1 while steel ingots need level 2. A fire striker that needs steel comes very late for fire-lighting. |
| scythe | Scythe | T3 | forge | 2 Iron ingot, 2 Stick | 1 Scythe | 12.0 |  |  |
| bronze_pickaxe | Bronze - Pickaxe | T3 | forge | 3 Bronze ingot, 2 Stick | 1 Bronze - Pickaxe | 25.0 | g | Forge 1 while bronze weapons are forge 2. |
| bronze_axe | Bronze - Axe | T3 | forge | 2 Bronze ingot, 1 Stick, 1 Twine | 1 Bronze - Axe | 20.0 | g | Forge 1 while bronze weapons are forge 2. Twine binding on a cast metal head (a socket or a leather wrap is usual). |
| bronze_hammer | Bronze - Hammer | T3 | forge | 2 Bronze ingot, 1 Stick | 1 Bronze - Hammer | 20.0 | g |  |
| bronze_knife | Bronze - Knife | T3 | forge | 1 Bronze ingot, 1 Stick | 1 Bronze - Knife | 12.0 | g |  |
| steel_pickaxe | Steel - Pickaxe | T4 | forge 2 | 3 Steel ingot, 2 Stick | 1 Steel - Pickaxe | 12.0 |  |  |
| spear | Stone - Spear | T1 | hand | 1 Wooden - Spear, 2 Twine; keep Stone | 1 Stone - Spear | 10.0 |  |  |
| wooden_spear | Wooden - Spear | T1 | hand | 1 Stick; keep Stone | 1 Wooden - Spear | 6.0 |  |  |
| wooden_club | Wooden - Club | T1 | hand | 3 Stick | 1 Wooden - Club | 4.0 | b | Three sticks make a club; a club is one heavy piece: 1 wooden block. |
| stone_mace | Stone - Mace | T1 | hand | 1 Stone, 1 Stick, 2 Twine | 1 Stone - Mace | 14.0 |  |  |
| wooden_bow | Wooden - Bow | T2 | workbench | 2 Stick, 3 Twine | 1 Wooden - Bow | 20.0 |  | Sticks + twine at a workbench: fine (a bowstring of sinew would be a later upgrade). |
| javelin | Javelin | T2 | workbench | 2 Stick, 1 Flint | 2 Javelin | 6.0 |  |  |
| bronze_sword | Bronze - Sword | T4 | forge 2 | 2 Bronze ingot, 1 Stick | 1 Bronze - Sword | 16.0 | d | Blade on a stick: no grip. Dave's touchstone (iron sword: forge, 2 ingots, leather grip) says + 1 leather. |
| bronze_mace | Bronze - Mace | T4 | forge 2 | 2 Bronze ingot, 1 Stick | 1 Bronze - Mace | 16.0 |  | Mace on a stick handle: fine (Valheim and Minecraft put metal heads on wood). |
| iron_sword | Iron - Sword | T4 | forge 2 | 2 Iron ingot, 1 Leather | 1 Iron - Sword | 18.0 |  | Matches Dave's touchstone: smithy, 2 iron ingots, 1 leather. |
| iron_mace | Iron - Mace | T4 | forge 2 | 2 Iron ingot, 1 Stick | 1 Iron - Mace | 18.0 |  |  |
| steel_sword | Steel - Sword | T5 | forge 3 | 2 Steel ingot, 1 Heavy leather | 1 Steel - Sword | 20.0 | a d | Needs forge level 3: only the Large forge (future) gives that, so it can never be made. Heavy leather grip where iron uses plain leather. |
| steel_mace | Steel - Mace | T5 | forge 3 | 2 Steel ingot, 1 Stick | 1 Steel - Mace | 20.0 | a | Needs forge level 3 (Large forge, future): never makeable. |
| chopping_block | Chopping block | T1 | hand | 1 Large wooden block | 1 Chopping block | 8.0 |  |  |
| water_wheel | Water wheel | T2 | workbench | 20 Lumber, 80 Nails, 4 Tar | 1 Water wheel | 40.0 |  |  |

## Every blueprint (built with the hammer)

| id | name | category | tier | station | cost | flags | note |
|---|---|---|---|---|---|---|---|
| foundation_section | Stone - Foundation | Foundations | T1 | none | 8 Stone, 2 Clay |  |  |
| thatch_floor | Thatch - Foundation | Foundations | T2 | workbench | 4 Twine, 20 Thatch | g | Needs a workbench while the thatch wall does not. |
| log_seat | Log seat | Furniture | T1 | none | 1 Log |  |  |
| stool | Stool | Furniture | T1 | none | 6 Stick, 1 Twine, 2 Wooden pin |  |  |
| bench | Bench | Furniture | T2 | workbench | 3 Lumber, 1 Twine |  |  |
| chair | Chair | Furniture | T2 | workbench | 4 Lumber, 1 Hide, 4 Wooden pin |  |  |
| table | Table | Furniture | T2 | workbench | 6 Lumber, 2 Twine |  |  |
| hide_rug | Hide - Rug | Furniture | T1 | none | 3 Hide, 1 Sinew |  |  |
| wool_rug | Wool - Rug | Furniture | T1 | none | 4 Wool, 1 Twine |  |  |
| straw_bed | Straw bed | Furniture | T2 | workbench | 12 Straw, 6 Stick, 2 Twine |  |  |
| feather_bed | Feather bed | Furniture | T2 | workbench | 10 Thatch, 20 Feather, 10 Down, 2 Woven cloth |  |  |
| canopy_bed | Canopy bed | Furniture | T2 | workbench | 30 Feather, 8 Lumber, 4 Woven cloth |  |  |
| fireplace | Fireplace | Lights and decoration | T1 | none | 24 Brick, 4 Mortar, 6 Clay |  |  |
| wall_torch | Wall torch | Lights and decoration | T1 | none | 2 Stick, 1 Tallow |  |  |
| chandelier | Chandelier | Lights and decoration | T2 | workbench | 2 Lumber, 2 Twine, 6 Candle |  |  |
| flower_pot | Flower pot | Lights and decoration | T1 | none | 2 Clay, 1 Soil |  |  |
| antler_mount | Antler mount | Lights and decoration | T2 | workbench | 2 Antler, 1 Lumber, 1 Twine |  |  |
| floor_section | Wooden - Ceiling | Roofs and ceilings | T1 | none | 4 Lumber, 1 Twine |  |  |
| roof_section | Wooden - Roof | Roofs and ceilings | T1 | none | 5 Lumber, 2 Twine, 2 Stick |  |  |
| log_floor | Log - Ceiling | Roofs and ceilings | T1 | none | 8 Log, 2 Twine |  |  |
| log_roof | Log - Roof | Roofs and ceilings | T1 | none | 4 Log, 20 Thatch, 3 Twine |  |  |
| brick_floor | Brick - Ceiling | Roofs and ceilings | T1 | none | 20 Brick, 4 Sand | b | Bricks + raw sand: use mortar, as the brick wall. |
| brick_roof | Brick - Roof | Roofs and ceilings | T1 | none | 16 Brick, 6 Lumber | e | Bricks for a roof; roofs are clay tiles (Roof tile is the common item). |
| thatch_roof | Thatch - Roof | Roofs and ceilings | T2 | workbench | 6 Twine, 40 Thatch, 12 Stick | g | Needs a workbench while the thatch wall does not (and costs twice the wall's thatch). |
| stone_floor | Stone - Ceiling | Roofs and ceilings | T2 | workbench | 16 Cobblestone, 4 Sand | b | Cobblestone + raw sand, while walls use mortar: use mortar. |
| stone_roof | Stone - Roof | Roofs and ceilings | T2 | workbench | 20 Stone shingle, 6 Lumber |  |  |
| timber_set | Timber set | Stairs, ladders and supports | T1 | none | 4 Lumber, 1 Twine, 1 Stick |  |  |
| ladder | Ladder | Stairs, ladders and supports | T1 | none | 4 Rough plank, 2 Twine |  |  |
| timber_prop | Timber prop | Stairs, ladders and supports | T1 | none | 1 Log, 1 Twine |  |  |
| stairs_wood | Wooden - Stairs | Stairs, ladders and supports | T2 | workbench | 8 Lumber, 2 Twine |  |  |
| lean_to | Lean-to | Storage and shelter | T1 | none | 20 Stick, 60 Leaves, 6 Twine |  |  |
| chest | Wicker - Chest | Storage and shelter | T1 | none | 10 Stick, 4 Twine |  |  |
| plank_chest | Wooden - Chest | Storage and shelter | T2 | workbench | 8 Lumber, 2 Twine, 2 Hinges |  |  |
| wall_section | Wooden - Wall | Walls and doors | T1 | none | 4 Lumber, 1 Twine |  |  |
| doorway_section | Wooden - Doorway | Walls and doors | T1 | none | 3 Lumber, 1 Twine |  |  |
| window_section | Wooden - Window | Walls and doors | T1 | none | 3 Lumber, 1 Twine |  |  |
| log_wall | Log - Wall | Walls and doors | T1 | none | 6 Log, 2 Twine |  |  |
| stone_wall | Stone - Wall | Walls and doors | T1 | none | 12 Stone block, 4 Mortar |  |  |
| brick_wall | Brick - Wall | Walls and doors | T1 | none | 16 Brick, 4 Mortar |  |  |
| thatch_wall | Thatch - Wall | Walls and doors | T1 | none | 3 Twine, 20 Thatch, 6 Stick |  |  |
| thatch_doorway | Thatch - Doorway | Walls and doors | T2 | workbench | 6 Twine, 25 Thatch, 12 Stick | g | Needs a workbench while the thatch wall does not. |
| stone_forge | Stone forge | Workshops and stations | T2 | workbench | 24 Stone, 10 Clay, 2 Hide |  | Stone, clay and hide (bellows): sensible. |
| blacksmithy | Blacksmith's forge | Workshops and stations | T2 | workbench | 30 Stone, 10 Log, 10 Clay | d f | Stone, logs and clay; no anvil anywhere in the game. Valheim's forge takes anvils and bellows as add-ons; Vintage Story smiths on an anvil. Iron work should need an Anvil. |
| saw_mill | Sawmill | Workshops and stations | T2 | workbench | 40 Lumber, 100 Nails, 1 Saw blade, 1 Water wheel |  | Lumber, nails, saw blade and water wheel; reachable through hand-split lumber first. |
| woodworking_table | Woodworking table | Workshops and stations | T2 | workbench | 12 Lumber, 60 Nails |  |  |
| clay_hearth | Clay hearth | Workshops and stations | T1 | none | 10 Brick, 6 Clay, 4 Stone |  |  |
| oven | Brick oven | Workshops and stations | T1 | none | 24 Brick, 10 Clay, 8 Stone |  |  |
| log_workbench | Sturdy workbench | Workshops and stations | T1 | none | 4 Log, 6 Twine, 6 Stick |  |  |
| campfire_pot | Campfire pot | Workshops and stations | T1 | none | 3 Stick, 3 Twine, 1 Clay pot |  |  |
| workbench | Workbench | Workshops and stations | T1 | none | 16 Stick, 6 Twine, 4 Stone |  |  |
| tool_rack | Tool rack | Workshops and stations | T2 | workbench | 10 Stick, 4 Twine |  |  |
| vice | Wooden vice | Workshops and stations | T2 | workbench | 8 Stick, 4 Stone |  |  |

## Every ingredient and how it is obtained

Every item some live recipe or blueprint takes (as an input or a kept tool).

| ingredient | id | obtained from | made by recipe | used by (count) | obtainable now |
|---|---|---|---|---|---|
| Acorns | acorns | drop/harvest, flora pick |  | 1 | yes |
| Animal fat | animal_fat | butchering |  | 14 | yes |
| Antler | antler | butchering |  | 1 | yes |
| Autumn apple | apple_autumn | drop/harvest, flora pick |  | 1 | yes |
| Autumn pear | pear_autumn | drop/harvest, flora pick |  | 1 | yes |
| Bananas | bananas | drop/harvest, flora pick, wild food |  | 2 | yes |
| Bark | bark | drop/harvest, flora pick, server code |  | 1 | yes |
| Barley | barley | crop |  | 2 | yes |
| Bedding | bedding | flora pick, wild food |  | 1 | yes |
| Beech logs | log_beech | felling |  | 2 | yes |
| Beechnuts | beechnuts | drop/harvest, flora pick |  | 1 | yes |
| Beet | beet | crop, drop/harvest, flora pick |  | 1 | yes |
| Birch logs | log_birch | felling |  | 2 | yes |
| Blackberries | blackberries | drop/harvest, flora pick, wild food |  | 1 | yes |
| Blueberries | blueberries | drop/harvest, flora pick, wild food |  | 3 | yes |
| Bone | bone | animal, butchering |  | 1 | yes |
| Brick | brick | none | brick | 6 | yes |
| Bronze ingot | bronze_ingot | none | bronze_ingot | 8 | yes |
| Burdock roots | burdock_roots | drop/harvest, flora pick, wild food |  | 2 | yes |
| Cabbage | cabbage | crop, drop/harvest, flora pick |  | 2 | yes |
| Candle | candle | none | candle, tallow_candle | 1 | yes |
| Chamomile flowers | chamomile_flowers | drop/harvest, flora pick, wild food |  | 2 | yes |
| Chanterelles | chanterelles | drop/harvest, flora pick, wild food |  | 2 | yes |
| Chestnuts | chestnuts | drop/harvest, flora pick |  | 2 | yes |
| Clay | clay | digging |  | 11 | yes |
| Clay pot | clay_pot | none | clay_pot | 1 | yes |
| Coal | coal | boulder |  | 2 | yes |
| Cobblestone | cobblestone | none | cobblestone | 1 | yes |
| Comfrey leaves | comfrey_leaves | drop/harvest, flora pick, wild food |  | 2 | yes |
| Cooking apple | apple_cooking | drop/harvest, flora pick |  | 2 | yes |
| Copper ingot | copper_ingot | none | smelt_copper | 1 | yes |
| Copper ore | copper_ore | boulder |  | 1 | yes |
| Crab apples | crab_apples | drop/harvest, flora pick |  | 2 | yes |
| Crab meat | crab_meat | shore |  | 1 | yes |
| Cranberries | cranberries | drop/harvest, flora pick, wild food |  | 1 | yes |
| Damsons | damsons | drop/harvest, flora pick |  | 1 | yes |
| Dandelion flowers | dandelion_flowers | flora pick, wild food |  | 1 | yes |
| Dates | dates | drop/harvest, flora pick |  | 1 | yes |
| Down | down | butchering |  | 1 | yes |
| Egg | egg | butchering, nest, shore |  | 3 | yes |
| Feather | feather | animal, butchering, nest |  | 5 | yes |
| Fiddleheads | fiddleheads | flora pick, wild food |  | 1 | yes |
| Figs | figs | drop/harvest, flora pick |  | 1 | yes |
| Fine leather | fine_leather | none | fine_leather | 1 | yes |
| Firewood | firewood | drop/harvest, server code, shop (hob) |  | 1 | yes |
| Flax | flax | crop, drop/harvest, wild food |  | 1 | yes |
| Flint | flint | animal, boulder, drop/harvest |  | 3 | yes |
| Flour | flour | none | flour_from_wheat, flour_from_barley, flour_from_oats... | 7 | yes |
| Hand mill | quern | none | quern | 4 | yes |
| Hand saw | hand_saw | none | hand_saw | 1 | yes |
| Hazelnuts | hazelnuts | drop/harvest, flora pick, wild food |  | 7 | yes |
| Heavy leather | heavy_leather | none | heavy_leather | 3 | yes |
| Hide | hide | animal, butchering |  | 20 | yes |
| Hide glue | hide_glue | none | hide_glue | 1 | yes |
| Hide scraper | hide_scraper | none | hide_scraper | 1 | yes |
| Hinges | hinges | none | hinges | 1 | yes |
| Honeyspindle nectar | honeyspindle_nectar | flora pick, wild food |  | 11 | yes |
| Iron ingot | iron_ingot | none | smelt_iron | 14 | yes |
| Iron ore | iron_ore | boulder |  | 1 | yes |
| Juniper berries | juniper_berries | drop/harvest, flora pick, wild food |  | 2 | yes |
| Large softwood block | wooden_block_soft_large | server code |  | 1 | yes |
| Large wooden block | wooden_block_large | server code |  | 2 | yes |
| Leather | leather | none | leather | 7 | yes |
| Leather strap | leather_strap | none | leather_strap | 2 | yes |
| Leaves | leaves | drop/harvest, flora pick |  | 1 | yes |
| Linen | linen | none | linen | 1 | yes |
| Linseed | linseed | flora pick, wild food |  | 2 | yes |
| Log | log | server code |  | 11 | yes |
| Lumber | lumber | none | lumber, lumber_by_hand, lumber_wedge | 26 | yes |
| Marjoram | marjoram | drop/harvest, flora pick, wild food |  | 1 | yes |
| Milk | milk | none |  | 2 | **no** |
| Mint | mint | drop/harvest, flora pick, wild food |  | 2 | yes |
| Morels | morels | drop/harvest, flora pick, wild food |  | 1 | yes |
| Mortar | mortar | none | mortar | 3 | yes |
| Nails | nails | none | nails | 3 | yes |
| Nettles | nettles | drop/harvest, server code, wild food |  | 3 | yes |
| Oak logs | log_oak | felling |  | 2 | yes |
| Oats | oats | crop |  | 3 | yes |
| Obsidian | obsidian | none |  | 1 | **no** |
| Onion | onion | crop, drop/harvest, flora pick |  | 5 | yes |
| Peas | peas | crop, drop/harvest, flora pick |  | 1 | yes |
| Perch | perch | animal, fishing |  | 1 | yes |
| Pike | pike | animal, fishing |  | 1 | yes |
| Pine pitch | pine_tar | drop/harvest, flora pick |  | 1 | yes |
| Plant fibre | plant_fibre | crop, drop/harvest, fishing, flora pick, server code, shop (hob) |  | 14 | yes |
| Plantain leaves | plantain_leaves | drop/harvest, flora pick, wild food |  | 2 | yes |
| Plums | plums | drop/harvest, flora pick |  | 1 | yes |
| Porcini | porcini | drop/harvest, flora pick, wild food |  | 1 | yes |
| Potash | potash | flora pick, wild food |  | 1 | yes |
| Potato | potato | crop, drop/harvest, flora pick |  | 1 | yes |
| Prickly pears | prickly_pears | drop/harvest, flora pick, wild food |  | 1 | yes |
| Quill | quill | butchering |  | 1 | yes |
| Quince | quince | drop/harvest, flora pick |  | 1 | yes |
| Raspberries | raspberries | drop/harvest, flora pick, wild food |  | 1 | yes |
| Raw meat | raw_meat | animal, butchering, fishing |  | 7 | yes |
| Rivets | rivets | none | rivets | 3 | yes |
| Rope | rope | shop (hob) | rope, fibre_rope | 2 | yes |
| Rosemary | rosemary | drop/harvest, flora pick, wild food |  | 3 | yes |
| Rotten food | rotten_food | spoilage |  | 1 | yes |
| Rough plank | rough_plank | none | rough_plank | 1 | yes |
| Rye | rye | crop |  | 1 | yes |
| Samphire | samphire | drop/harvest, flora pick, wild food |  | 2 | yes |
| Sand | sand | digging |  | 3 | yes |
| Saw blade | saw_blade | none | saw_blade | 2 | yes |
| Scots pine logs | log_scots_pine | felling |  | 2 | yes |
| Scraped hide | processed_hide | none | processed_hide | 1 | yes |
| Sea salt | sea_salt | none | sea_salt | 5 | yes |
| Sea water | sea_water | server code, shore |  | 1 | yes |
| Seal meat | seal_meat | butchering |  | 1 | yes |
| Seaweed | seaweed | animal, shore |  | 1 | yes |
| Seeds | seed_bundle | server code |  | 3 | yes |
| Shellfish | shellfish | animal, shore |  | 2 | yes |
| Sinew | sinew | butchering |  | 5 | yes |
| Softwood block | wooden_block_soft | server code | small_soft_blocks_from_large | 1 | yes |
| Soil | soil | digging |  | 1 | yes |
| Spruce logs | log_spruce | felling |  | 2 | yes |
| Staunchmoss | staunchmoss | drop/harvest, flora pick, wild food |  | 1 | yes |
| Steel ingot | steel_ingot | none | smelt_steel | 9 | yes |
| Stick | stick | drop/harvest, server code, shop (hob) |  | 64 | yes |
| Stone | stone | boulder, digging, server code, shop (hob) |  | 27 | yes |
| Stone - Axe | stone_axe | shop (hob) | stone_axe | 2 | yes |
| Stone - Knife | stone_knife | shop (hob) | stone_knife | 1 | yes |
| Stone - Wedge | stone_wedge | none | stone_wedge | 1 | yes |
| Stone block | cut_stone_block | none | cut_stone_block | 1 | yes |
| Stone shingle | stone_shingle | none | stone_shingle | 1 | yes |
| Straw | straw | crop, drop/harvest, flora pick, wild food |  | 2 | yes |
| Strawberries | strawberries | drop/harvest, flora pick, wild food |  | 1 | yes |
| Sugar maple logs | log_maple | felling |  | 2 | yes |
| Tallow | tallow | none | tallow | 3 | yes |
| Tannin-rich bark | tannin_bark | drop/harvest, flora pick |  | 2 | yes |
| Tar | tar | drop/harvest | tar | 1 | yes |
| Thatch | thatch | drop/harvest, flora pick, server code, wild food |  | 8 | yes |
| Thyme | thyme | drop/harvest, flora pick, wild food |  | 4 | yes |
| Tin ingot | tin_ingot | none | smelt_tin | 1 | yes |
| Tin ore | tin_ore | boulder |  | 1 | yes |
| Tropical hardwood logs | log_tropical_hardwood | felling |  | 2 | yes |
| Trout | trout | animal, fishing |  | 4 | yes |
| Turnip | turnip | crop, drop/harvest, flora pick |  | 2 | yes |
| Twine | twine | shop (hob) | twine, twine_bark, sinew_cord | 70 | yes |
| Walnut logs | log_walnut | felling |  | 2 | yes |
| Walnuts | walnuts | drop/harvest, flora pick |  | 1 | yes |
| Water | water | animal, flora pick, server code, wild food |  | 16 | yes |
| Water wheel | water_wheel | none | water_wheel | 1 | yes |
| Watercress | watercress | drop/harvest, flora pick, wild food |  | 1 | yes |
| Wheat | wheat | crop |  | 1 | yes |
| Wild carrot roots | wild_carrot_roots | drop/harvest, flora pick, wild food |  | 5 | yes |
| Wild garlic leaves | wild_garlic_leaves | flora pick, wild food |  | 7 | yes |
| Wild pears | wild_pears | drop/harvest, flora pick |  | 1 | yes |
| Willow bark | willow_bark | drop/harvest, flora pick |  | 1 | yes |
| Wooden - Hoe | wooden_hoe | none | wooden_hoe | 1 | yes |
| Wooden - Spade | wooden_spade | shop (hob) | wooden_spade | 1 | yes |
| Wooden - Spear | wooden_spear | none | wooden_spear | 1 | yes |
| Wooden block | wooden_block | server code | small_blocks_from_large | 1 | yes |
| Wooden bowl | wooden_bowl | shop (hob) | wooden_bowl | 3 | yes |
| Wooden pin | wooden_pin | none | wooden_pin | 2 | yes |
| Wool | wool | animal, butchering |  | 5 | yes |
| Woven cloth | fibre_cloth | none | fibre_cloth | 2 | yes |
| Yarrow | yarrow | drop/harvest, flora pick, wild food |  | 1 | yes |

## Notes on the method

- Crops count as a source of their yields (wheat, barley, oats, rye, flax and so on) because farming is in the game; the seeds come from wild grass.
- "Obtainable now" ignores the `future` tag, as the server does (section 6 of items_review_stage1.md).
- Generated by a script from data/items (items, gathered, recipes, blueprints, structures, drops, carcass, boulders, digging, fishing, nests, shore_nodes, crops, cooking, dishes, spoilage, wood_species), data/tables/flora.json, data/animals and data/npcs/shops.json. The flags b to g are judgement and are listed per recipe so each can be ruled on.
