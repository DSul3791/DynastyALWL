# Build orders by tier (Sal, 2026-10-31)

Generated from data/items/recipes.json (known recipes only) with a reachability walk from what the world gives today (gathered plants and animals, stone, stick, log, clay, sand, hide, feathers and so on). Craft times are in seconds from the recipe. **GAP** = an ingredient nothing in the world yields yet (flint, ore, coal, iron, crops, shore foods) or a recipe built on one. This is the order a player should meet things in, not a promise they exist: gaps are listed per tier and in the gap table at the end.

Rule of thumb for order inside a tier: tools first (they speed everything else), then shelter, then food and clothing, then the next tier's gate.

## Tier 0 Hand and fire

| Order | Item | Needs | Station | Craft s | Reachable |
|---|---|---|---|---|---|
| 1 | Twine | plant_fibre x3 | hand | 2 | yes |
| 2 | Stone axe | stone x1, stick x1, twine x2 | hand | 4 | yes |
| 3 | Stone spear | wooden_spear x1, twine x2 (keeps stone) | hand | 4 | yes |
| 4 | Campfire | stick x6, stone x3 | hand | 3 | yes |
| 5 | Wooden spear | stick x1 (keeps stone) | hand | 3 | yes |
| 6 | Stone knife | stone x2, stick x1 | hand | 3 | yes |
| 7 | Basic torch | stick x1, plant_fibre x2 | hand | 2 | yes |
| 8 | Plantain poultice | plantain_leaves x3 | hand | 3 | yes |
| 9 | Comfrey poultice | comfrey_leaves x2 | hand | 3 | yes |
| 10 | Leaf bandage | plantain_leaves x1, plant_fibre x2 | hand | 3 | yes |
| 11 | Mossy bandage | staunchmoss x1, plant_fibre x2 | hand | 3 | yes |
| 12 | Wooden spade | stick x2 (keeps stone) | hand | 4 | yes |
| 13 | Small shelter | stick x8, leaves x6, twine x2 | hand | 8 | yes |
| 14 | Woven chest | stick x10, twine x4 | hand | 8 | yes |
| 15 | Chopping block | log x2 | hand | 3 | yes |
| 16 | Wooden bowl | firewood x1 | hand | 6 | yes |
| 17 | Clay pot | clay x6 | hand | 12 | yes |
| 18 | Bucket | lumber x6, twine x2 | hand | 10 | yes |
| 19 | Waterskin | hide x2, twine x1 | hand | 8 | yes |
| 20 | Bark twine | bark x2 | hand | 3 | yes |
| 21 | Rope | twine x4 | hand | 5 | yes |
| 22 | Iron spade | iron_ingot x2, stick x2 | hand | 10 | GAP: iron_ingot |
| 23 | Steel spade | steel_ingot x2, stick x2 | hand | 12 | GAP: steel_ingot |
| 24 | Backpack | hide x4, rope x1 | hand | 20 | yes |
| 25 | Energy bar | hazelnuts x3, dates x2, yarrow x1 | hand | 6 | yes |
| 26 | Herbal tea | mint x3 | hand | 4 | yes |
| 27 | Stomach tea | mint x2, chamomile_flowers x2 (keeps wooden_bowl) | hand | 5 | yes |
| 28 | Chamomile tea | chamomile_flowers x3 (keeps wooden_bowl) | hand | 5 | yes |
| 29 | Willow bark tea | willow_bark x2 (keeps wooden_bowl) | hand | 5 | yes |
| 30 | Grass skirt | plant_fibre x8 | hand | 6 | yes |
| 31 | Grass cloak | plant_fibre x16, twine x1 | hand | 10 | yes |
| 32 | Fibre sandals | plant_fibre x6, twine x1 | hand | 8 | yes |
| 33 | Hide cloak | hide x3, twine x2 | hand | 14 | yes |
| 34 | Hide boots | hide x2, twine x2 | hand | 14 | yes |
| 35 | Hide hood | hide x1, twine x1 | hand | 8 | yes |
| 36 | Hide mittens | hide x1, twine x1 | hand | 8 | yes |
| 37 | Hide leggings | hide x3, twine x2 | hand | 14 | yes |
| 38 | Sinew cord | sinew x3 | hand | 6 | yes |
| 39 | Camp bench | stick x12, twine x3 | hand | 12 | yes |
| 40 | Fishing rod | stick x2, twine x2 | hand | 8 | yes |
| 41 | Berry compote | blueberries x2, honeyspindle_nectar x1 | campfire_pot | 6 | yes |
| 42 | Nut paste | hazelnuts x3, honeyspindle_nectar x1 | campfire_pot | 6 | yes |
| 43 | Roast Roots | burdock_roots x2, wild_carrot_roots x2 | campfire | 8 | yes |
| 44 | Acorn mash | acorns x3, water x1 | campfire_pot | 8 | yes |
| 45 | Baked apples | crab_apples x3, honeyspindle_nectar x1 | campfire | 8 | yes |
| 46 | Mushroom skewer | porcini x2, chanterelles x1, wild_garlic_leaves x1 | campfire | 8 | yes |
| 47 | Herb fish | trout x1, thyme x1, samphire x1 | campfire | 8 | yes |
| 48 | Garlic meat | raw_meat x1, wild_garlic_bulbs x1, rosemary x1 | campfire | 8 | yes |
| 49 | Chestnut cakes | chestnuts x3, honeyspindle_nectar x1, linseed x1 | campfire | 10 | yes |
| 50 | Fruit leather | crab_apples x2, cranberries x1, honeyspindle_nectar x1 | campfire | 10 | yes |
| 51 | Smoked fish | pike x1, samphire x1, juniper_berries x1 | campfire | 10 | yes |
| 52 | Hunter's stew | raw_meat x1, wild_carrot_roots x1, wild_garlic_bulbs x1 | campfire_pot | 12 | yes |
| 53 | Forager's stew | greens x2, burdock_roots x1, chanterelles x1 | campfire_pot | 12 | yes |
| 54 | Fish stew | perch x1, watercress x1, wild_carrot_roots x1 | campfire_pot | 12 | yes |
| 55 | Trail bread | linseed x2, hazelnuts x2, animal_fat x1 | campfire | 12 | yes |
| 56 | Hearty pottage | seeds x2, wild_carrot_roots x1, dandelion_leaves x1, marjoram x1, animal_fat x1 | campfire_pot | 14 | yes |
| 57 | Roast Beast | raw_meat x2, wild_garlic_bulbs x1, thyme x1, rosemary x1, animal_fat x1 | campfire | 14 | yes |
| 58 | Wall section | lumber x4, twine x1 | hand | 8 | yes |
| 59 | Floor section | lumber x4, twine x1 | hand | 8 | yes |
| 60 | Roof section | lumber x5, twine x2, stick x2 | hand | 10 | yes |
| 61 | Foundation | stone x8, clay x2 | hand | 12 | yes |
| 62 | Doorway | lumber x3, twine x1 | hand | 8 | yes |
| 63 | Window wall | lumber x3, twine x1 | hand | 8 | yes |
| 64 | Timber prop | log x1, twine x1 | hand | 6 | yes |
| 65 | Timber set | lumber x4, twine x1, stick x1 | hand | 10 | yes |
| 66 | Brick | clay x2 | campfire | 14 | yes |
| 67 | Mortar | sand x2, clay x1 | hand | 8 | yes |
| 68 | Ladder | lumber x4, twine x2 | hand | 10 | yes |
| 69 | Wooden hoe | stick x2, twine x1 (keeps stone) | hand | 8 | yes |
| 70 | Iron hoe | iron_ingot x2, stick x2 | hand | 12 | GAP: iron_ingot |
| 71 | Steel hoe | steel_ingot x2, stick x2 | hand | 14 | GAP: steel_ingot |
| 72 | Tar | pine_tar x5 | campfire | 12 | yes |
| 73 | Rock pile | stone x45 | hand | 20 | yes |
| 74 | Lumber by hand | log x1 (keeps hand_saw) | hand | 24 | GAP: hand_saw |
| 75 | Wooden hammer | wooden_block x1, stick x1, twine x1 | hand | 5 | yes |
| 76 | Rough bed | thatch x10, stick x4, twine x2 | hand | 10 | yes |
| 77 | Shore net | twine x8, stone x4 | hand | 12 | yes |
| 78 | Campfire pot | stick x3, twine x3, clay_pot x1 | hand | 15 | yes |
| 79 | Wooden arrow | stick x2, feather x2 | hand | 4 | yes |
| 80 | Stone arrow | stick x2, feather x2, stone x2 | hand | 6 | yes |
| 81 | Quiver | hide x2, twine x2 | hand | 6 | yes |
| 82 | Flatbread | seeds x3, water x1 | clay_hearth | 8 | yes |
| 83 | Honey loaf | seeds x3, hazelnuts x1, honeyspindle_nectar x1 | oven | 12 | yes |
| 84 | Rosemary joint | raw_meat x2, rosemary x1, wild_garlic_bulbs x1 | oven | 14 | yes |
| 85 | Snare | twine x3, stick x2 | hand | 6 | yes |
| 86 | Kindling | stick x1 | hand | 2 | yes |
| 87 | Processed hide | hide x1 (keeps hide_scraper) | hand | 8 | GAP: hide_scraper |
| 88 | Wooden club | stick x3 | hand | 4 | yes |
| 89 | Hide tunic | hide x3, twine x2 | hand | 16 | yes |
| 90 | Hide trousers | hide x3, twine x2 | hand | 16 | yes |
| 91 | Hide gloves | hide x1, twine x2 | hand | 12 | yes |
| 92 | Clay jug | clay x4 | hand | 14 | yes |
| 93 | Herb salve | comfrey_leaves x2, animal_fat x1 | hand | 10 | yes |
| 94 | Splint | stick x2, twine x1 | hand | 6 | yes |
| 95 | Candle | animal_fat x1, plant_fibre x1 | hand | 6 | yes |
| 96 | Wicker shield | stick x3, plant_fibre x2 | hand | 12 | yes |
| 97 | Stone mace | stone x1, stick x1, twine x2 | hand | 14 | yes |
| 98 | Leather cap | leather x2 | hand | 16 | GAP: leather |
| 99 | Quern | stone x2, stick x1 | hand | 10 | yes |
| 100 | Flour | wheat x3 (keeps quern) | hand | 10 | GAP: wheat |
| 101 | Barley flour | barley x3 (keeps quern) | hand | 10 | GAP: barley |
| 102 | Compost | plant_fibre x3 | hand | 4 | yes |
| 103 | Hide glue | hide x1 | campfire_pot | 12 | yes |
| 104 | Bone arrow | stick x2, feather x2, bone x2 | hand | 6 | yes |
| 105 | Stone wedge | stone x2, stick x1 | hand | 8 | yes |
| 106 | Fibre arrow | stick x2, plant_fibre x1 | hand | 4 | yes |
| 107 | Tinder | thatch x2 | hand | 3 | yes |
| 108 | Rough bed | bedding x8, stick x4, twine x2 | hand | 10 | yes |
| 109 | Wooden hammer | wooden_block_soft x1, stick x1, twine x1 | hand | 5 | yes |
| 110 | Rough bed | straw x8, stick x4, twine x2 | hand | 10 | yes |

## Tier 1 Workbench

| Order | Item | Needs | Station | Craft s | Reachable |
|---|---|---|---|---|---|
| 1 | Stone spade | wooden_spade x1, stone x2, twine x1 | workbench | 8 | yes |
| 2 | Tool rack | stick x10, twine x4 | workbench | 10 | yes |
| 3 | Log workbench | log x4, twine x6, stick x6 | workbench | 30 | yes |
| 4 | Stone block | stone x25 | workbench L1 | 20 | yes |
| 5 | Stone hoe | wooden_hoe x1, stone x2, twine x1 | workbench | 10 | yes |
| 6 | Rough plank | log x1 | workbench L1 | 6 | yes |
| 7 | Cobblestone | stone x3 | workbench L1 | 6 | yes |
| 8 | Stone shingle | stone x2 | workbench L1 | 6 | yes |
| 9 | Wooden pin | lumber x1 | workbench L1 | 5 | yes |
| 10 | Stone hammer | stone x1, stick x1, twine x1 | workbench | 6 | yes |
| 11 | Hand saw | saw_blade x1, stick x2, twine x2 | workbench | 10 | GAP: saw_blade |
| 12 | Thatch floor | twine x4, thatch x20 | workbench | 10 | yes |
| 13 | Thatch wall | twine x8, thatch x50, stick x15 | workbench | 20 | yes |
| 14 | Thatch roof | twine x6, thatch x40, stick x12 | workbench | 20 | yes |
| 15 | Thatch doorway | twine x6, thatch x25, stick x12 | workbench | 20 | yes |
| 16 | Wooden bow | stick x2, twine x3 | workbench | 8 | yes |
| 17 | Hide scraper | flint x1, stick x1, twine x1 | workbench | 6 | GAP: flint |
| 18 | Javelin | stick x2, flint x1 | workbench | 6 | GAP: flint |
| 19 | Obsidian knife | obsidian x1, stick x1, twine x1 | workbench | 6 | GAP: obsidian |
| 20 | Stone pickaxe | stick x2, stone x3, twine x2 | workbench | 10 | yes |
| 21 | Sickle | flint x1, stick x1, twine x1 | workbench | 6 | GAP: flint |
| 22 | Plank shield | lumber x3, hide x1 | workbench | 14 | yes |
| 23 | Leather jerkin | leather x3 | workbench | 16 | GAP: leather |
| 24 | Gambeson | twine x3, leather x1 | workbench | 16 | GAP: leather |
| 25 | Rough planks | log x1 (keeps stone_wedge) | workbench | 14 | yes |

## Tier 2 Sawmill, woodworking, workbench 2+

| Order | Item | Needs | Station | Craft s | Reachable |
|---|---|---|---|---|---|
| 1 | Lumber | log x1 | saw_mill | 6 | yes |
| 2 | Oak lumber | log_oak x1 | saw_mill | 6 | GAP: log_oak |
| 3 | Oak beams | log_oak x1 | saw_mill | 8 | GAP: log_oak |
| 4 | Birch lumber | log_birch x1 | saw_mill | 6 | GAP: log_birch |
| 5 | Birch beams | log_birch x1 | saw_mill | 8 | GAP: log_birch |
| 6 | Scots pine lumber | log_scots_pine x1 | saw_mill | 6 | GAP: log_scots_pine |
| 7 | Scots pine beams | log_scots_pine x1 | saw_mill | 8 | GAP: log_scots_pine |
| 8 | Spruce lumber | log_spruce x1 | saw_mill | 6 | GAP: log_spruce |
| 9 | Spruce beams | log_spruce x1 | saw_mill | 8 | GAP: log_spruce |
| 10 | Tropical hardwood lumber | log_tropical_hardwood x1 | saw_mill | 6 | GAP: log_tropical_hardwood |
| 11 | Tropical hardwood beams | log_tropical_hardwood x1 | saw_mill | 8 | GAP: log_tropical_hardwood |
| 12 | Walnut lumber | log_walnut x1 | saw_mill | 6 | GAP: log_walnut |
| 13 | Walnut beams | log_walnut x1 | saw_mill | 8 | GAP: log_walnut |
| 14 | Sugar maple lumber | log_maple x1 | saw_mill | 6 | GAP: log_maple |
| 15 | Sugar maple beams | log_maple x1 | saw_mill | 8 | GAP: log_maple |
| 16 | Fine board | lumber x1 | woodworking_table L1 | 4 | yes |

## Tier 3 Forge 1

| Order | Item | Needs | Station | Craft s | Reachable |
|---|---|---|---|---|---|
| 1 | Iron pickaxe | iron_ingot x3, stick x2 | forge | 10 | GAP: iron_ingot |
| 2 | Nails | iron_ingot x1 | forge | 10 | GAP: iron_ingot |
| 3 | Hinges | iron_ingot x1 | forge | 8 | GAP: iron_ingot |
| 4 | Saw blades | iron_ingot x2 | forge | 20 | GAP: iron_ingot |
| 5 | Steel striker | steel_ingot x1 | forge | 8 | GAP: steel_ingot |
| 6 | Rivets | iron_ingot x1 | forge | 8 | GAP: iron_ingot |
| 7 | Scythe | iron_ingot x2, stick x2 | forge | 12 | GAP: iron_ingot |
| 8 | Copper ingot | copper_ore x2 | forge | 10 | GAP: copper_ore |
| 9 | Tin ingot | tin_ore x2 | forge | 10 | GAP: tin_ore |
| 10 | Iron ingot | iron_ore x3 | forge | 12 | GAP: iron_ore |

## Gap table (what to build next, by effect)

| Missing ingredient | Recipes it blocks |
|---|---|
| iron_ingot | 8: Iron spade, Iron hoe, Iron pickaxe, Nails, Hinges, Saw blades, Rivets, Scythe |
| steel_ingot | 3: Steel spade, Steel hoe, Steel striker |
| leather | 3: Leather cap, Leather jerkin, Gambeson |
| flint | 3: Hide scraper, Javelin, Sickle |
| log_oak | 2: Oak lumber, Oak beams |
| log_birch | 2: Birch lumber, Birch beams |
| log_scots_pine | 2: Scots pine lumber, Scots pine beams |
| log_spruce | 2: Spruce lumber, Spruce beams |
| log_tropical_hardwood | 2: Tropical hardwood lumber, Tropical hardwood beams |
| log_walnut | 2: Walnut lumber, Walnut beams |
| log_maple | 2: Sugar maple lumber, Sugar maple beams |
| hand_saw | 1: Lumber by hand |
| hide_scraper | 1: Processed hide |
| wheat | 1: Flour |
| barley | 1: Barley flour |
| saw_blade | 1: Hand saw |
| obsidian | 1: Obsidian knife |
| copper_ore | 1: Copper ingot |
| tin_ore | 1: Tin ingot |
| iron_ore | 1: Iron ingot |

Notes: ingredients flagged here as GAP are a spec for the code session (FLINT_ORE_SPEC.md); 'known' recipes are only those available from the start (LEARN_SYSTEM_SPEC.md covers the 19 locked ones). Times are crafting seconds only, not gathering time.

False alarms in the gap table: the species logs (log_oak and so on) come from felling those trees, which this walk does not model; the Lumber by hand, Hand saw and Saw blade rows follow from the missing iron. The Stone wedge route (Rough planks) gives lumber with no iron.

Update 2026-10-31 (Tyler water-gather merged): seaweed, shellfish, crab meat, eggs and sea salt are obtainable from the tide-line nodes, and sea water fills a container, so they are no longer gaps; the dishes and leather chain that waited on them (seaweed soup, mussel stew, herb omelette, salted fish, jerky, acorn mash, flatbread, leather, heavy leather, leather cap, jerkin, gambeson, strap) are no longer `future`.
