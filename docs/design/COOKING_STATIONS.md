# Cooking stations, no cookware

Status: **APPROVED by Dave 17 Nov 2026** (he chose "Yes, build it" on the plan in the thread "Plan cooking stations to replace cookware"). Values marked CS-n in "For Dave" are assumed on his behalf and provisional.

## The ruling

Dave, 17 Nov 2026 03:28Z: "We dont use things like pots pans and griddles we use cooking stations." 03:29Z: "if you have documents that suggest or say cookware thay were mistakes made by the ai." 03:35Z he named the stations: "the grill would be a classic brick/grill looking BBQ, the cooking pot which would be like a caldron hanging on a chain from some metal frame work. a cooking prep table to get meals ready to be cooked in the oven. the griddle could be a cookstation with a flat iron griddle with metal legs standing over an open fire. like an ancient version of a blackstone griddle."

The hand cookware of master catalog s3.12 [D12] (Clay Griddle, Campfire Roasting Spit, Iron Grill Grate, Iron Frying Pan, Iron Cauldron, and the Copper Pot as a cooking vessel) was an AI drafting mistake. The catalog and FOOD_PREPARATION_PRESERVATION_SERVING.md carry a SUPERSEDED note pointing here.

**Rule: no recipe keeps cookware. A cooking station alone cooks.** `tools/gen_dishes.py` refuses a dish with `keeps`, and test_dishes and test_cooking_route check that no food recipe keeps anything.

## Stations

| Station | Item / blueprint / state | Look | Cooks |
|---|---|---|---|
| Campfire, Campfire pot, Fireplace cooking crane, Clay hearth, Oven, Smoker, Drying rack, Preserving jar | unchanged | unchanged | unchanged |
| Food preparation table (Dave's "cooking prep table") | unchanged, item 1202 | unchanged | prepares uncooked food |
| **Grill** (new) | item 1494, blueprint 360, state 452 | brick barbecue, iron grate over glowing coals, chimney stub | Meat skewer and Mushroom skewer (4 a craft), Sausage, Rosemary joint |
| **Cooking pot** (new) | item 1495, blueprint 361, state 453 | iron pot on a chain from an iron A-frame over a ring-stone fire | the seven big-batch stews (3 batches a craft); also everything a Campfire pot cooks (`also`) |
| **Griddle** (new) | item 1496, blueprint 362, state 454 | flat iron plate with a lip on four iron legs over a wood fire | Flatbread, Rye flatbread, Garlic bread, Oat cakes, Chestnut cakes, Crab cakes, Egg and nettle fry, Herb omelette, Banana fritter, Meatballs |
| **Hand mill** (now placed) | item 344 `quern` (kind structure), blueprint 363, state 455 | stone base, two millstones, wooden handle | Flour, Barley flour, Oat flour, Rye flour, Wild grain flour, Bonemeal |

The looks are first box-and-cylinder models in `src/client/piece_look.gd` (grill, cooking_pot, griddle, hand_mill) until Art draws them. They have not been seen in game.

## Recipes

The cookware recipes kept their numbers under new ids, `cook_<dish>_<station>`:

- Grill: 431 `cook_mushroom_skewer_grill`, 462 `cook_meat_skewer_grill`, 464 `cook_sausage_grill`, 442 `cook_roast_joint_grill` (was the spit).
- Cooking pot: 434, 435, 436, 438, 445, 446, 451 (`cook_<stew>_cooking_pot`, was the cauldron).
- Griddle: 433, 440, 444, 455, 457 (`cook_<bread or cakes>_griddle`, was the clay griddle); 448, 449, 450, 459 (`cook_<crab_cakes, egg_nettle_fry, herb_omelette, banana_fritter>_griddle`, was the frying pan); 471 `cook_meatballs_griddle` (was the pan).
- Kept their station, dropped the cookware: 259 Crab cakes, 260 Egg and nettle fry, 261 Herb omelette, 273 Banana fritter (a plain campfire, CS-4); 33 Stomach tea, 34 Chamomile tea, 35 Willow bark tea (no Wooden bowl); 395 Fish soup (no Copper pot; still locked).
- Hand mill: 222-226 and Bonemeal now name `"station": "quern"` instead of keeping the Hand mill.
- Retired, never reused: recipes 394 `copper_pot`, 465 `clay_griddle`, 466 `campfire_roasting_spit`, 467 `iron_grill_grate`, 468 `iron_frying_pan`, 469 `iron_cauldron`, 221 `quern`.

## Items

Retired (rows kept for their numbers): 835 Copper - Pot, 1203 Clay - Griddle, 1204 Campfire roasting spit, 1205 Iron - Grill grate, 1206 Iron - Frying pan, 1207 Iron - Cauldron. No save migration (new game, Dave 12 Nov 2026).

Kept: Wooden bowl #39 (holds water, sold by Hob, carved at the carving station) and Clay - Pot #40 (holds water and builds the Campfire pot). Mortar and pestle #807 stays a hand tool (CS-7; superseded 18 Nov 2026: it is a placed station, MORTAR_PESTLE.md).

## For Dave (assumed on your behalf, provisional)

- **CS-1** The three new stations need no fuel and are not lit, like the Clay hearth and Oven.
- **CS-2** Costs: Grill 12 Brick, 4 Stone, 2 Iron ingot. Cooking pot 5 Iron ingot, 2 Iron band. Griddle 3 Iron ingot, 4 Stone. All wooden-hammer blueprints, known from the start, so they arrive with iron.
- **CS-3** Batches as the cookware had them: the Grill makes 4 skewers a craft, the Cooking pot 3 batches of stew a craft.
- **CS-4** Before iron nothing gets harder: flatbreads and cakes bake at the Clay hearth, stews use the Campfire pot, the Rosemary joint roasts in the Oven, and Crab cakes, Egg and nettle fry, Herb omelette and Banana fritter cook on a plain campfire (they needed the 4-clay Clay griddle before).
- **CS-5** The Cooking pot also cooks everything a Campfire pot cooks. The Grill and Griddle cook only their own recipes.
- **CS-6** The Hand mill is a placed station built from what the hand tool cost (2 Stone, 1 Stick).
- **CS-7** Mortar and pestle stays a hand tool held while grinding medicine (four recipes). Superseded 18 Nov 2026: Dave agreed MORTAR_PESTLE.md, it is a placed station.
