# Food variety check (Sal, 2026-10-31)

Counted from recipes.json, dishes.json, cooking.json (cooks_into) and the item tables. The 3-ingredient rule holds for every dish except the two special top-tier ones (Hearty pottage and Roast Beast, 5 each).

## Today: 31 prepared foods
- **Roasts by fire (cooks_into, no recipe):** roast meat, roast fish (trout, perch, carp, pike), roast forage, steamed shellfish, boiled egg, seal steak. Shore ones need a gather action that does not exist yet.
- **Campfire and pot dishes (20, dishes.json):** berry compote, nut paste, roast roots, acorn mash, baked apples, mushroom skewer, herb fish, garlic meat, chestnut cakes, fruit leather, smoked fish, hunter's stew, forager's stew, fish stew, trail bread, hearty pottage, roast beast, flatbread (clay hearth), honey loaf (oven), rosemary joint (oven).
- **Drinks (5):** herbal tea, stomach tea, chamomile tea, willow bark tea, energy bar as a snack.
- **Stored foods inside those:** smoked fish, fruit leather, honey loaf, trail bread.

That is 31, not 40. By biome: temperate forest and grassland are well covered (berries, nuts, roots, mushrooms, game); boreal and tundra have nothing special; beach and marsh have the shore roasts only; alpine none; desert and tropics none (dates, bananas and prickly pear exist as items with no dish).

## Missing dishes to reach 45 (all at most 3 ingredients; station in brackets; prices follow the ECONOMY_PLAN rule)
| # | Dish | Ingredients | Station | Biome / season |
|---|---|---|---|---|
| 1 | Oat porridge | oats 2, water, hazelnuts | pot | boreal, heath, winter |
| 2 | Barley broth | barley 2, wild carrot roots, water | pot | all, winter |
| 3 | Rye flatbread | rye flour 2, water, salt | hearth | boreal, tundra |
| 4 | Pea soup | peas 2, onion, water | pot | grassland, spring |
| 5 | Turnip mash | turnip 2, animal fat | pot | tundra, boreal |
| 6 | Baked potato | potato 2, animal fat | campfire | grassland, heath |
| 7 | Cabbage stew | cabbage, raw meat, onion | pot | grassland, autumn |
| 8 | Beet roast | beet 2, thyme | campfire | beach, grassland |
| 9 | Onion roast | onion 2, animal fat | campfire | all |
| 10 | Seaweed soup | seaweed 2, shellfish, water | pot | beach |
| 11 | Mussel stew | shellfish 3, wild garlic leaves, water | pot | beach |
| 12 | Crab cakes | crab meat 2, flour | campfire | beach |
| 13 | Egg and nettle fry | egg 2, nettle greens, animal fat | campfire | spring |
| 14 | Omelette with herbs | egg 3, thyme | campfire | all |
| 15 | Seal stew | seal meat, turnip, water | pot | beach, winter |
| 16 | Venison pie | raw meat, flour, animal fat | oven | autumn, forest |
| 17 | Fish pie | fish, flour, onion | oven | lake, river |
| 18 | Salmon roast | salmon, juniper berries | campfire | river, autumn |
| 19 | Wild garlic bread | flour 2, wild garlic leaves | hearth | spring |
| 20 | Oat cakes | oats 2, honey (when bees exist) or fat | hearth | boreal |
| 21 | Jerky | raw meat 2, sea salt | drying rack | winter store |
| 22 | Salted fish | fish, sea salt | jar | winter store |
| 23 | Dried berries | berries 3 | drying rack | winter store |
| 24 | Sauerkraut | cabbage 2, sea salt | jar | winter store |
| 25 | Rose hip syrup | rose hips 3, water, honey or sugar | pot | autumn |
| 26 | Hazelnut butter | hazelnuts 3 | quern | autumn |
| 27 | Date bar | dates 2, nuts | campfire | savanna, desert |
| 28 | Banana fritter | bananas 2, flour | campfire | tropical |
| 29 | Cactus fry | prickly pear, onion | campfire | desert |
| 30 | Coconut milk | coconut | by hand | tropical, beach |

Items needed first: Sea salt, a drying rack and jar structure, Honey (bees), Flour (done), the crops (items exist, no farming code), Salmon, Fish pie ingredients (Flour via Quern: done). Dishes 1 to 9, 13, 14, 16 to 20 and 26 need only items that exist today (once crops grow); 10 to 12, 15, 21 to 24 need shore gathering or salt.

## Cost to add (not done this round)
Each dish is one row in dishes.json and recipes.json, one item in items.json, and kcal, shelf life and warmth rows in vitals.json, spoilage.json and cooking.json (as I did for the shore foods). The dishes generator (tools/gen_dishes.py) rewrites seven files and must not be run blind; add by hand, about 30 rows. Recommend doing dishes 1 to 9, 13, 14, 16 to 20 and 26 (16 dishes) in one batch after farming lands, to bring the total to 47.
