# Hoe gardening and levelling (14 Nov 2026)

Thread "Add gardening to the Hoe". Dave's words (14 Nov 2026):
- "gardening should also be another option on the right click of the Hoe that allows you to make garden plots or plant seeds, plants, shrubs trees etc."
- "Trees should drop some seeds when cut down. a random number of seeds between 1 and 5 seeds per tree."
- "the hoe should work very much like the Valheim Hoe plus the plugin plant easy and plant everything." This is a feel reference only; the code and art are our own.
- "ground leveling currently works but its to small an area and its too week"; "make the ground level with where you are standing and if you are standing on say a foundation it make the ground just a little bit below your feet".
- Later the same day: "All trees when I say trees, I mean all trees follow the same rules and the seeds are just the name of the tree plus the word seed like an oak tree becomes oak tree seed or mirror bark seed".
- And: "There doesn't actually need to be garden plots. It should just till the soil so you can put seeds in the ground. Look up the way ValHeim does it."

The master items catalog (s2.1) lists the hoe's "Create Garden Plot" and "Plant" modes. Following Dave's later ruling, the hoe no longer lays out plots: tilling is how it makes garden ground. The garden plot items and blueprints are unchanged and are still built with the hammer.

**How Valheim does it (feel reference).** The Cultivator's right-click menu has Cultivate, which turns the ground under the cursor into dark tilled soil, and then the seeds you carry. A seed can only go on cultivated ground, and a green or red ghost shows whether it fits with enough space around it. The Plant Easily mod adds rows and grids of plants at once. Ours: Till turns a metre of ground into a bed, and a seed clicked on open ground in Garden mode tills it and sows it in the same click (G-1). The rows, grids and green or red preview are item 4 below.

## What is built
1. **Garden mode (PR #1119).** The hoe's right-click list gains Garden. Choosing it opens a second list of what the pack can plant, with counts.
   - Seeds go in a tilled bed (or a garden plot built with the hammer). Seeds clicked on open ground till it first.
   - Dug-up bushes and tree seeds go in open ground.
   - The client sends the existing ACT_SOW / ACT_TILL / ACT_PLANT_BUSH, so there is no protocol change. The server rules on reach, season, ground and spacing.
2. **Levelling (PR #1119).** Smooth levels a 1 m grid within 3 m to the ground under your feet. When you stand on a piece (0.2 m or more above the ground, such as a foundation), it levels to 0.1 m under your feet.
   - Heights are read through the saved dig/fill log, so strokes add up and stop once level.
   - Constants are in `src/stream/server_items.gd` (`SMOOTH_REACH_M`, `LEVEL_*`).
3. **No garden plots with the hoe (Dave's later ruling).** PR #1123 let the hoe lay out plot blueprints. That code is deleted (decision 61): the Garden list holds only what can be planted, and a plot blueprint needs a hammer, as every blueprint does.
4. **Rows and grids with a preview.**
   - The mouse wheel picks one cell, a row of 5 along the way you face, 3 by 3 or 5 by 5 (`FarmRules.GARDEN_GRIDS`).
   - Green markers show where a click will plant, red where it will not.
   - A grid never takes more than the pack holds of the pick, and a 2 m plot takes one seed.
   - Requests go out paced: tills 600 ms apart, sows 150 ms apart (`FarmRules.garden_step`).
5. **Tree seeds.**
   - When a felled tree breaks up, it drops a random 1 to 5 of its seed as one heap in its crown circle (`drops.json trunk.felled_seeds`). The feller is credited like the split logs.
   - A trunk cut by hand gives its seeds into the pack with its first axe blow on the branches. A pick gives none, since it gives only thatch and kindling. A trunk whose branch blows were all made with a pick loses its seeds, as it loses its sticks and leaves.
   - Every tree, fantasy trees included, drops its own seed item, named the tree plus "seed" (Dave's ruling). Items 1360-1369 kept their ids and were renamed; 1370-1404 are new. A tree's fruit or nut (acorns, apples) stays food and is not planted.
   - The Garden list plants a tree seed in open ground as a sapling (`_saplings`, planted now) that grows like wild regrowth.

Herb and plant seeds come in the next change (Dave: "All herbs and plants should produce seeds"). Cold frame and Compost bin stay locked.

## Herb and plant seeds (design, 14 Nov 2026)
Dave: "All herbs and plants should produce seeds so there must be a way to find seeds in the wild or to convert herbs and plants into seeds"; "it should be simple and it should [mirror] nature in a simplified way so that it's fun in a video game".

In nature a plant flowers, then sets seed late in its season, and gardeners save seed from the plants they grow. The game keeps that as two rules a player can learn in one go:

1. **Wild plants give seed when they have gone to seed.** Picking a wild herb or plant by hand late in its season also gives 1 or 2 of its seed, beside the usual harvest. "Late in its season" means the last season in its flora.json `season` list; a plant that grows all year sets seed in summer and autumn. This uses the existing wild-seed rule (`drops.json seed_drops`, already used for wild carrot, flax and the wild crops), so no new code is needed.
2. **Garden plants give seed back.** A seed sown in a tilled bed or a planter (Planter box, Stone - Planter, Flower pot) grows into its plant. A ripe one, taken by hand, gives the plant's harvest and 1 or 2 seeds back, like the field crops (`crops.json seeds_back`).

So the first seed comes from the wild, and a garden keeps itself going after that. There is no separate "make seeds" recipe; picking a plant at the right time is the conversion.

Which plants: every flora.json `plant` that is a real plant, the fantasy herbs included. Left out: the fallen log, hollow log and old stump (not plants), and the mushrooms and other fungi, which grow from spores rather than seed (an open question for Dave). Plants that already have a seed keep it: flax (Flax seeds), tall grass (the cereal seeds), wild carrot and the eight wild crops, and henbane and stillwater lotus, whose existing Henbane seeds and Stillwater seeds become their seed. Every other plant gets a new "<Plant> seed" item, named from its game name (Dave's tree rule), from item 1405.

Assumed numbers (PROVISIONAL): wild seed 1 to 2 a pick, late in season; a sown herb is ripe after 12 game days, needs 0.3 waterings a day like the crops, and gives what a wild one gives (its `harvest_yield` or berry row, at most 12; else 2 of each of its yields) and 1 to 2 seeds back; it is sown in the plant's own seasons; a plant with nothing to harvest (nettle, dune grass, sea holly) grows for its looks and gives only its seeds back. A plant that grows in winter in the wild keeps growing in winter (`grows_in_winter`). Garden looks are the placeholder crop tufts, raised to the planter's soil (`structures.json soil_y`). The three planters became beds (`"plot": true`): E sows, hold E takes one down.

## Assumed on Dave's behalf, for his review
These are PROVISIONAL values the thread or the coordinator chose under Dave's standing order. Each can be changed by editing the named constant or data row.

| # | Assumption | Where |
|---|---|---|
| G-1 | A seed clicked on open ground tills a bed there and then sows it, with no second click. | `FarmRules.garden_action`, `held_item._garden_here` |
| G-2 | Levelling reach 3 m (was 1.5); up to 4 edits a stroke of up to 0.5 m each (was 0.25), with 2.5 m spheres. On a piece, it levels to 0.1 m under the feet, at most 1.5 m above the ground under them. The soil is free (not volume balanced), Valheim-style. | `server_items.gd` `SMOOTH_REACH_M`, `LEVEL_MAX_OPS`, `LEVEL_MAX_M`, `LEVEL_SPHERE_M`, `LEVEL_BELOW_PIECE_M`, `LEVEL_MAX_RAISE_M` |
| G-3 | The Garden list holds seeds, bushes and tree seeds in pack order. | `held_item._hoe_menu_choose` |
| G-6 | Grid sizes are one, a row of 5, 3 by 3 and 5 by 5. Seeds go 1 m apart and bushes 2 m apart. | `FarmRules.GARDEN_GRIDS`, `SEED_SPACING_M`, `BUSH_SPACING_M` |
| G-7 | Client planting reach is 3.7 m from the feet, inside the server's 4 m. | `held_item.GARDEN_REACH_M` |
| G-8 | Garden pacing: tills 600 ms apart (the server's hoe pace is 500 ms), sows 150 ms apart. A sow waits up to 3 s for the bed its till asked for. | `FarmRules.GARDEN_*_MSEC` |
| G-9 | Each seed's name is the tree's game name plus "seed" (Dave's rule), so oak is "English oak seed" and the tropical hardwood is "Mahogany seed". Ids are permanent; names can change. | `items.json` 1360-1404 |
| G-11 | Tree seeds go 3 m apart in a grid. The server keeps a tree seed 2 m from other plants (bushes 1 m). The heap lands within half the crown radius. | `FarmRules.TREE_SPACING_M`, `server_items.PLANT_TREE_GAP_M` |
| G-12 | The existing per-log fruit roll (`trunk.seed_chance`: a species' fruit or nut, else Wild grain) is unchanged. It comes on top of the 1 to 5 felled seeds. | `drops.json trunk.seed_chance` |

G-4 (a species' own fruit or nut is its seed) and G-10 (fantasy trees drop none) are withdrawn by Dave's ruling that every tree follows the same rules with its own "<Tree> seed".

**Numbers.** The coordinator gave gardening items 1360-1399 and then 1400-1549 (checked free on dev and in PR #1133, 14 Nov 2026). Tree seeds use 1360-1404; herb and plant seeds use 1405-1471.

## For Dave: open points and your rulings
All values are provisional, and each is a one-line change if you want it different.

1. **Every tree drops its own seed (your ruling).** All 45 trees, the fantasy trees included, drop 1 to 5 of their own seed when felled, and every seed plants as a sapling. The names follow your rule, using each tree's name in the game. Correct any you want changed: English oak seed, Beech seed, Birch seed, Scots pine seed, Spruce seed, Alder seed, Willow seed, Coconut palm seed, Mahogany seed, Acacia seed, Mangrove seed, Rowan seed, Crab apple seed, Wild pear seed, Wild cherry seed, Sweet chestnut seed, Walnut seed, Date palm seed, Mirrorbark seed, Wardpine seed, Hearthwood seed, Everember seed, Witness tree seed, Balsam fir seed, Sugar maple seed, Early summer apple seed, Summer apple seed, Autumn apple seed, Keeping apple seed, Cooking apple seed, Summer pear seed, Autumn pear seed, Winter pear seed, Sour cherry seed, Plum seed, Damson seed, Quince seed, Medlar seed, Fig seed, Olive seed, Pomegranate seed, Mango seed, Orange seed, Lemon seed, Wild apple seed.
2. **Herb and plant seeds (your ruling).** Two rules, in "Herb and plant seeds" above: a wild plant picked late in its season gives 1 to 2 of its seed, and a garden plant gives seeds back. They grow in tilled beds and in the Planter box, Stone - Planter and Flower pot. Mushrooms and other fungi are left out because they grow from spores: say if you want them to have spawn. The new names (items 1405-1471) are: Bracken seed, Heather seed, Common reed seed, Nettle seed, Cotton grass seed, Mountain avens seed, Blueberry seed, Lingonberry seed, Cranberry seed, Cloudberry seed, Wild strawberry seed, Crowberry seed, Wild garlic seed, Wild thyme seed, Water mint seed, Sorrel seed, Dandelion seed, Watercress seed, Samphire seed, Wild marjoram seed, Wild sage seed, Lavender seed, Yarrow seed, Ribwort plantain seed, Chamomile seed, Comfrey seed, St John's wort seed, Valerian seed, Meadowsweet seed, Feverfew seed, Burdock seed, Mugwort seed, Arnica seed, Angelica seed, Aloe seed, Foxglove seed, Deadly nightshade seed, Wolfsbane seed, Owlpetal seed, Staunchmoss seed, Emberroot seed, Wispbloom seed, Hushfern seed, Heartroot seed, Tideglass weed seed, Gloomthistle seed, Dewlantern seed, Marrowroot seed, Riverbraid seed, Brinebell seed, Quenchbell seed, Whisperfern seed, Duskmallow seed, Tanglewort seed, Stormreed seed, Truthsage seed, Echo moss seed, Nightcrown seed, Mournbloom seed, Pilgrim's cup seed, Frostglass orchid seed, Sevenyear lily seed, Gloaming star seed, Tidecrown seed, Thatching grass seed, Dune grass seed, Sea holly seed. Henbane and stillwater lotus use their existing Henbane seeds and Stillwater seeds.
3. **The hoe makes no garden plots (your ruling).** It tills, and seeds go into the tilled ground, as in Valheim. Plots remain in the catalog and are built with the hammer. If you want plots gone from the catalog too, that is your call.
4. **Every other gardening value is assumed.** The table above (G-1 to G-3, G-6 to G-9, G-11 and G-12) lists each number we chose: one-click till and sow on open ground, levelling reach and strength, list order, grid sizes and spacing, reach, pacing, seed names, tree spacing and the per-log fruit roll.
5. **Planting counts as a use in the item check.** Crop seeds, dug-up bushes and tree seeds no longer show up as dead ends in `validate_items`.
