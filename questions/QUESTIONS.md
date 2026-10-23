## block-hand | Please test the chopping block in your hand. Look for: same model as the placed one, but smaller in hand.
Note: 1. Give yourself a chopping block (admin menu).
Note: 2. Hold it in first person: it should fit the hand and not be cut off at the screen edge.
Note: 3. Drop it, then place another next to it. Compare the three.
[test]

## hoe-spade-row | Please take a picture of the 4 hoes and 3 spade sizes in one row, at x 53301, z 68427.
Note: 1. Give yourself a wooden, stone, iron and steel hoe and the small, medium and large spade.
Note: 2. Drop all seven in one row on the ground at the spawn.
Note: 3. Take a picture from about 2 m away.
[picture]

## axe-bucket | Please take a picture of a stone axe and a bucket on the ground, at x 53301, z 68427.
Note: 1. Drop a stone axe and a bucket side by side.
Note: 2. The axe should look like a wedge, the bucket light wood with dark hoops.
[picture]

## hoe-hold | Please test the hoe: hold the left mouse button with a wooden hoe and walk forward on grass. Look for: a continuous line of flat tan path patches.
Note: 1. Hold the wooden hoe.
Note: 2. Hold the LEFT mouse button and walk forward on grass.
Note: 3. Then hold the RIGHT button on a rough strip to smooth it. It should get smoother, the hoe should wear only when ground moves, and "This ground is worked enough." shows when it refuses.
[test]

## collapse-natural | Please test a natural cave. Look for: no shaking and no collapse.
Note: 1. Walk into a natural cave you did not dig.
Note: 2. Stay 10 minutes (do something else nearby).
[test]

## collapse-prop | Please test a timber prop. Look for: the shaking stops within 5 m of the prop.
Note: 1. Dig a tunnel about 2 m wide and wait for the shaking to start (use cave-in time 2 min).
Note: 2. Place a timber prop 3 m from the roof.
Note: 3. Shaking should stop near it (7.5 m for a timber set).
[test]

## ladder | Please test a ladder. Look for: it climbs, comes down, lets go backwards and steps you onto the top edge.
Note: 1. Place a ladder against a wall and face it.
Note: 2. Hold W to climb, then S to come down, Space to let go backwards.
Note: 3. Climb to the top and hold W: you step onto the edge.
[test]

## admin-craft-test | Please test free crafting as admin. Look for: crafting works with an empty pack while Admin mode is on, and normal rules come back when it is off.
Note: 1. Pull build 697 and close the game fully, then start it. The HUD should say 697.
Note: 2. Esc > Admin: the switch "Admin mode (crafting is free)" should be green (On).
Note: 3. With an empty pack, open the crafting list and craft an iron pickaxe or a forge recipe. It should craft with no ingredients.
Note: 4. Select a recipe and press E: one item should be crafted.
Note: 5. Switch Admin mode Off (red). Crafting an iron pickaxe with an empty pack should now be refused.
[test]

## hotbar-move | Is this how the hotbar should work: a tool dragged onto the hotbar MOVES there and leaves the pack grid (the hotbar is extra holding slots, not a copy, and it still counts for weight), and E over a hotbar slot with the inventory window open puts it back in the first free pack slot?
Note: Tyler recommends Yes because it already matches what you described, so nothing needs changing.
[check]

## blocks-from-log | A log from your pack, dropped on the ground and chopped with an axe, gives 4 wooden blocks (about 0.3 m long, 3.75 kg each)?
Note: Tyler recommends Yes because the pack log is the smaller log (about 15 kg), so 4 blocks of 3.75 kg add up. The big shoulder log gives more (next card).
[check]

## blocks-from-shoulder-log | A log from your shoulder, put on the ground and chopped with an axe, gives 12 wooden blocks?
Note: Tyler recommends Yes because it is the full-size log (about 45 kg) and 12 blocks matches your "quite a few".
[check]

## firewood-from-block | One wooden block used on the chopping block gives 1 firewood (3.5 kg) that falls beside the block, and the pieces merge into one heap (the pile look from 5 pieces is Kathleen's)?
Note: Tyler recommends Yes because one block makes one piece (simple to learn), and the heap uses the same pile rule as rocks.
[check]

## axe-wear-chop | The axe wears once for each log chop and once for each split at the chopping block?
Note: Tyler recommends Yes because both are real chopping, and one wear per action is easy to understand and to tune later.
[check]

## species-uses-1 | Should each kind of tree be good for different things, using four numbers per species (hardness, burn time, rot resistance, how easy it is to work)? For example oak for strong beams and posts, birch and beech for firewood, pine and spruce for planks, alder for piers in water, apple and cherry for tool parts.
Note: Full table: tech/items/TREE_SPECIES_USES_DRAFT.md.
Note: Tyler recommends Yes because it follows real wood, so players can learn it, and it needs only data (four numbers per tree).
[check]

## species-uses-2 | Recipes still accept "any log", but a better species gives a better result (stronger beam, less tool wear, longer-burning fire)?
Note: Tyler recommends Yes because nobody is blocked when the right tree is far away, and the good tree is a reward.
[check]

## species-uses-3 | Hard woods (oak, walnut) take more axe wear to chop, so they feel valuable?
Note: Tyler recommends Yes because cost is how a player feels value, and it is one number per species.
[check]

## species-uses-4 | Firewood and wooden blocks from different species stay in separate piles (no mixed piles), and piers and wet foundations need a rot-proof wood (oak, chestnut, alder)?
Note: Tyler recommends Yes because mixed piles are hard to take from and piers rotting would be unfair without a warning.
[check]

## logs-per-tree | A felled tree gives whole 8 ft (2.44 m) logs by its height, rounded down, at most 20 per tree (a 24 ft tree gives 3, a 9 ft tree gives 1)? The old bonus for thick trunks goes away.
Note: Tyler recommends Yes because it is easy to predict by looking at the tree, and it ties to the wooden blocks (4 per log) and species.
[check]

## small-tree-work | A small tree (under 8 ft) gives no whole log: working the trunk gives 3 blows of branches (sticks and leaves) and then 3 blows of firewood, kindling and sticks, then it is used up (no roots, no blocks)?
Note: Tyler recommends Yes because a small tree can never give a proper log, so it gives small useful things and is gone.
[check]

## log-names | Logs are named by the tree, written "Oak logs", "Beech logs" instead of "Oak_Logs" (item ids stay log_oak, log_beech and so on). Is that fine?
Note: Tyler recommends Yes because "Oak logs" reads naturally for players, and the underscore form stays only in the item ids.
[check]

## lake-rule-2 | Should any hollow hold water when enough rain can reach it, with no minimum size, and we fix places with unwanted lakes by changing how the generator makes the land?
Note: This is your own rule from your answer. Tyler's suggestion to make it work: a hollow gets water from the rain that falls on the land that drains into it (its catchment), and it dries to a smaller pond or nothing if the rain is too little for its size (evaporation). So a tiny hollow with a tiny catchment is only a puddle, and a big hollow with a big catchment is a lake.
Note: Tyler recommends Yes because it needs no extra rule beyond catchment and rain, and the stripe ponds from terrace steps disappear because they catch almost no rain.
[check]

## reset-edits-test | Please test Reset all terrain edits. Look for: the holes you dug are gone after the reload, with no errors.
Note: 0. The evidence copy of your dry river now exists, so the reset is safe to test (MikeW copied it first).
Note: 1. WARNING: this wipes ALL your digs and fills on the server (collapse rubble too). Inventories, characters, buildings, plants, dropped items and tree stumps stay. A backup is taken first by MikeW; do not test before it is done.
Note: 2. Pull build 698, close the game fully, start it. The HUD should say 698.
Note: 3. Dig a hole and fill a bit.
Note: 4. Esc > Admin > Reset all terrain edits, then confirm on the page (Yes).
Note: 5. After the reload, the holes and fills should be gone and the ground back as baked. Write any errors in Notes.
[test]

## close-godot-backup | Please close the Godot editor so tonight's backup can run. Closed?
Note: 1. Close the Godot editor on C:\GodotProjects\DynastyALWL (and the game and the hidden server window if they are open).
Note: 2. Answer Yes here. MikeW runs the backup the moment it is closed.
Note: 3. If you answer No (Not now), the backup moves to the first thing tomorrow morning. Write anything in Why not.
Note: Tyler recommends Yes because the backup protects tonight's 700+ builds, and it only takes a few minutes.
[check]
