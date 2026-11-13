# David4 evidence run for the goals audit

Relayed by the coordinator from the David4 lane report, 2026-11-13. Original files are on David4 under `/work/lanerun/goals-audit-dc2fa52/` (per-test .out/.result/.godot.log, summary.txt, sha.txt, validate_items.txt, three_stdout.txt).

- Checkout: dc2fa52374d49ce05ef1f31a300999d1da872d9d, confirmed as the origin/dev head at run time.
- dbef6bf..dc2fa52 changed only docs/design/ADMIN_KEYBINDINGS_POLICY.md, PLAYER_GOALS_REWARDS_DRAFT.md, PLAYER_JOURNAL_GOALS_UI.md.
- Fresh import, Godot 4.7.2 voxel headless, --jobs 2, 300 s timeouts, throwaway user data.
- All 20 named tests exist at that SHA; none missing, none substituted.
- Result: 20 pass, 0 fail: test_goals, test_mission001_walkthrough, test_fire_fuel_tiers, test_fire_wet_wood, test_campfire_pot, test_wanted_order, test_camp_bench_drink, test_cooking_route, test_iron_saw_route, test_lumber_route, test_textile_route, test_stations, test_blueprints, test_doors, test_bog_iron, test_stump_chop, test_logs_carry, test_auto_pickup, test_fishing, test_shore_gather.
- validate_items: 0 errors, 114 warnings.

Transcription note: test_goals below is the lane's stdout as reported (engine banner and blank lines already removed by the lane). For test_mission001_walkthrough the coordinator kept every "ok" and STEP line and dropped the "pack:" and "fire store:" lines. For test_fire_fuel_tiers the lane notes it prints no per-check "ok" lines.

## test_goals

```
ok   goals_state lists the goals: the first open, the axe locked (28 goals)
ok   the hoe and path goals are listed, locked until the fire (Dave 4 Nov 2026)
ok   drinking at the water completes the first goal and pays 2 copper (2)
ok   the player is told: ["Goal done: Drink at the water. You earn 2 copper."]
ok   the goal's coins are named in its line, so they are not taken for a find (TEST-009): ["Goal done: Drink at the water. You earn 2 copper."]
ok   12 plant fibre in the pack completes the fibre goal; twine is not done yet
ok   two crafts of twine complete the twine goal and give 4 sticks (reward)
ok   and the next goal's hint is said in the same line
ok   making the stone axe completes the axe goal
ok   felling a tree completes the fell goal and gives kindling
ok   a fire that is only placed does not complete the fire goal
ok   lighting the fire completes the fire goal
ok   placing a lean-to completes the shelter goal
ok   placing a workbench completes the workbench goal
ok   the done goals are saved with the character and still done after a restart
ok   goals_state shows workbench done and the bed goal open
ok   the first hint is said at once (["Walk with W A S D. Hold Shift to run."])
ok   and not said twice
ok   moving 5 m brings the next hint (["Walk with W A S D. Hold Shift to run.", "Press Tab to see Health, Food, Water, Temperature and Energy."])
ok   nine sticks in the pack bring the fibre hint
ok   the said hints are saved with the character (["move", "bars", "fibre"])
ok   bare: not warm enough
ok   hood, cloak and boots add up to 0.55 warmth
ok   talking to someone else does not count for the story goal
ok   talking to Edda at 21:00 completes the story goal
ok   at noon the same talk does not count
ok   walking 120 m with a torch at night adds up (120 m)
ok   and completes the night walk goal
ok   no plant food hint without a fire or ingredients
ok   ingredients but no lit fire: no hint
ok   berries and nectar beside a lit fire: the hint triggers
ok   no pot placed yet
ok   placing a campfire pot triggers its hint
ok   once a pot stands at the fire the plant food hint stops
ok   no sea water in the pack: no hint
ok   sea water in the pack triggers its hint
ok   no bench placed: the workbench goal is open
ok   a log workbench also completes the workbench goal (Dino round 6)
ok   a log workbench fires the workbench_placed hints
ok   no fire kit in the pack: no place-fire reminder
ok   no fish caught or held: the fish goal is open
ok   a caught fish completes the fish goal even when it is gone from the pack
ok   no tree near: no fell hint
ok   a bought stone axe in the pack completes the axe goal (was false before)
ok   an axe on the hotbar beside a tree fires the fell hint
ok   a fire kit in the pack triggers the place-fire reminder
ok   near_nettle needs nettles in the pack
ok   no fruit in the pack: no fruit hint
ok   a plum in the pack fires the fruit hint
ok   the first look only records the season
ok   the same season: no season hint
ok   a new season fires the season hint
ok   no deep dig yet: no cave-in hint
ok   a deep dig fires the cave-in hint
ok   no trees: no orchard hint
goals: 0 failures
```

## test_mission001_walkthrough ("pack:" and "fire store:" lines dropped)

```
--- STEP 1 early survival
ok   1a. a new character arrives with nothing in the pack and nothing worn
ok   1b. gathering by hand gives 48 plant fibre, 40 sticks, 4 stones and a large wooden block
ok   1c. plant fibre is twisted into 13 twine by hand
ok   1d. a Stone - Axe and a Stone - Knife are made by hand
ok   1e. the axe splits the large block and a Wooden - Hammer is made by hand; it sits in the hand bar
ok   1f: the lean_to stands, built from its blueprint [["stick", 20.0], ["leaves", 60.0], ["twine", 6.0]]
ok   1f. the Lean-to is a shelter
ok   1g: the chest stands, built from its blueprint [["stick", 10.0], ["twine", 4.0]]
ok   1g. the Wicker - Chest stands and has a store
ok   a campfire is made by hand, placed and lit at the camp
ok   1h. the knife dresses the deer: 12 raw meat, 1 hide, 1 fat, 5 bone
ok   1i. the campfire roasts two pieces of meat (2 Roast meat)
ok   1j. a Roast meat is eaten and feeds (1113 kcal in the stomach)
ok   1k. 5 bones and 1 stones are stored in the Wicker - Chest
--- STEP 2 wood and metal
ok   2a. a Wooden spade is made by hand
ok   a campfire is made by hand, placed and lit at the forge yard
ok   2b: the smelter stands, built from its blueprint [["clay", 24.0], ["stone", 10.0]]
ok   2c. bog iron dug with the spade, charcoal burnt at the campfire and smelted at the Smelter: 5 Iron ingots (5 needed)
ok   2d: the blacksmithy stands, built from its blueprint [["stone", 16.0], ["clay", 10.0], ["log", 4.0], ["iron_ingot", 3.0]]
ok   2e. the new Smithy stands cold
ok   2f. the craft fires the Smithy with charcoal from the pack
ok   2g. an Iron - Saw is made at the Smithy (no Saw blade)
ok   2h. the saw gives 6 Planks from a spruce log and 4 Hardwood boards from an oak log
ok   2i. the saw wears with use (0 -> 2)
ok   2j. nothing was bought: the purse never paid out (0 -> 8 copper, goal rewards only)
--- STEP 3 construction and equipment
ok   3a. more deer dressed: 6 hides, 16 bones
ok   3b: the workbench stands, built from its blueprint [["stick", 16.0], ["twine", 6.0], ["stone", 4.0]]
ok   3b. a hide scraper at the workbench
ok   3c: the drying_rack stands, built from its blueprint [["stick", 8.0], ["twine", 4.0]]
ok   3c: the tanning_rack stands, built from its blueprint [["log", 6.0], ["twine", 4.0]]
ok   3c. two hides scraped, dried and tanned into Leather
ok   3d: the leatherworking_table stands, built from its blueprint [["log", 4.0], ["stick", 4.0], ["twine", 4.0], ["stone", 2.0]]
ok   3d. the Leatherworking table cuts 2 Leather straps (the knife is kept: 1)
ok   3e. Thread is twisted by hand from plant fibre
ok   3f. a Loom blueprint site with its materials still to come weaves nothing
ok   3f. the materials deposited with E, the Loom stands
ok   3f. the Loom weaves 3 Fibre cloth
ok   3g: the tailors_table stands, built from its blueprint [["log", 3.0], ["stick", 6.0], ["twine", 4.0]]
ok   3g. the Tailor's table makes a Fibre - Gambeson
ok   3h. a Hide - Backpack sewn by hand (the needle is kept)
ok   3i. 8 Hardwood boards sawn and 20 wooden pins cut
ok   3j. 10 more Iron ingots from the bog (10)
ok   3k. the Smithy makes nails, hinges and rivets
ok   3l. an Iron - Mace (iron weapon) at the Smithy
ok   3m. an Iron - Mail shirt (iron armour) at the Smithy, with the second Leather
ok   3n: the plank_chest stands, built from its blueprint [["hardwood_board", 6.0], ["nails", 12.0], ["hinges", 2.0]]
ok   3n: the crude_chair stands, built from its blueprint [["hardwood_board", 2.0], ["wooden_pin", 4.0]]
ok   3n. the Rustic - Chest opens with 20 slots
ok   3n. the Crude - Chair stands
ok   3o. the gambeson and the mail shirt are worn together on the body
ok   3o. layered they stop 0.265 of a cut: more than the gambeson alone (0.090), not more than both summed
ok   3p. the backpack is worn on the back with the gambeson and mail
ok   3q. the worn backpack has no slots: it is not opened, takes nothing and the stones stay in the pack
ok   3r. a wolf bite wears the worn mail shirt (wear 8)
ok   3s. taken off at the camp, far from a Smithy, it is not mended
ok   3s. at the Smithy it is mended with one Iron ingot
ok   3s. and worn again
ok   3t. 10 more Iron ingots for the Blast furnace, the trough and the steel
ok   3u. 42 bricks fired at the campfire and 8 mortar mixed by hand
ok   3v: the large_forge stands, built from its blueprint [["brick", 40.0], ["stone", 20.0], ["mortar", 8.0], ["iron_ingot", 6.0]]
ok   3v. the Blast furnace stands
ok   3w. the Blast furnace makes 1 steel ingot from route iron
ok   3x: the quenching_trough stands, built from its blueprint [["stone", 12.0], ["log", 2.0], ["iron_ingot", 2.0]]
ok   3x. with the trough beside the Smithy, Tempered is offered for the Steel - Knife
ok   3y. a Tempered Steel - Knife from Blast furnace steel (lasts 7031 against 5625)
ok   3z. the mace, the hinges and rivets left over and the sewing tools are stored in the Rustic - Chest
--- STEP 4 cooking and preservation
ok   a campfire is made by hand, placed and lit at the kitchen
ok   4a: the food_preparation_table stands, built from its blueprint [["log", 3.0], ["twine", 2.0]]
ok   4b. wheat milled by hand with the quern: 2 flour
ok   4c. the table prepares 2 Unbaked flatbread
ok   4d: the clay_hearth stands, built from its blueprint [["brick", 10.0], ["clay", 6.0], ["stone", 4.0]]
ok   4d. the Clay hearth bakes 2 Flatbread
ok   4e: the preserving_jar stands, built from its blueprint [["clay", 6.0]]
ok   4e. one craft seals the batch: 4 Sauerkraut, Maturing (no ingredient yet)
ok   4f. a Maturing stack is not eaten
ok   4g. after 48.0 game hours the batch is Ready
ok   4h: the smoker stands, built from its blueprint [["stone", 16.0], ["clay", 6.0]]
ok   4h. the Smoker smokes the deer's meat into Smoked meat
ok   4i: the drying_rack stands, built from its blueprint [["stick", 8.0], ["twine", 4.0]]
ok   4i. the Drying rack dries porcini into Dried mushrooms
ok   4j. the dishes are cooked: ["roast_meat 2", "roast_joint 2", "roast_roots 2", "onion_roast 2"]
ok   4k. the table assembles a Roast platter of 4 portions
ok   4l. a Serving platter is carved by hand
ok   4m. the Serving platter sits on the table top
ok   4n. the board is set on the platter: 4 portions
ok   4o. a portion is eaten from the platter: a Main meal
ok   4p. portions conserved: 3 on the platter + 0 in the pack + 1 eaten = 4 made
--- STEP 5 food effects
ok   5a. the last meal's effect has expired
ok   5b. a platter portion, a Flatbread and a Sauerkraut: three groups active ["main", "bread", "fruit_veg"]
ok   5c. eating changes no XP already earned
ok   5d. XP earned afterwards is raised x1.20 (21.60 against 18.00 plain)
ok   5e. the Flatbread's effect expires on its own timer; the platter's Main meal runs on
ok   5f. a Nut cake is eaten into a free slot
ok   5g. it gives energy (52) and costs no Fitness (train 0.06 -> 0.06)
ok   5h. the food left over (10 pieces, the Sauerkraut among them) is stored in the Wicker - Chest
--- STEP 6 storage and warehousing
ok   6a. 6 more Iron ingots from the bog
ok   6a. an Iron - Hammer and 8 iron bands at the Smithy
ok   6b. 24 Hardwood boards and 29 Planks sawn
ok   6c: the warehouse_desk stands, built from its blueprint [["hardwood_board", 8.0], ["nails", 12.0]]
ok   6c: the warehouse_crate stands, built from its blueprint [["hardwood_board", 8.0], ["nails", 16.0], ["iron_band", 4.0]]
ok   6c. the Warehouse crate stands, owned by its builder
ok   6d. the owner stores 6 flint and locks the Rustic - Chest with 0042 (only a hash is kept)
ok   6e. the owner opens it; the second player is refused
ok   6f. the Warehouse crate is loaded: { 1: 5, 68: 2 }
ok   6g. the desk shows the second player the open crate but not the locked chest; the owner sees both
ok   6h. the second player enters 0042 and gets in; the desk now lists the chest for them too
ok   6i: the log_workbench stands, built from its blueprint [["lumber", 8.0], ["twine", 4.0], ["wooden_pin", 6.0]]
ok   6i. two Wooden cart wheels and an Axle at the Carpenter's bench
ok   6j: the handcart stands, built from its blueprint [["lumber", 6.0], ["wooden_cart_wheel", 2.0], ["axle", 1.0], ["wooden_pin", 12.0]]
ok   6j. the Handcart is its builder's
ok   6k: the warehouse_desk stands, built from its blueprint [["hardwood_board", 8.0], ["nails", 12.0]]
ok   6l. the loaded crate goes onto the Handcart
ok   6l. desk A no longer lists it
ok   6m. the owner takes the handle
ok   6n. the cart is wheeled to depot B and let go ((-76.91785, 10.05, 120.302))
ok   6o. the crate is set down at depot B
ok   6p. contents identical ({ 1: 5, 68: 2 }) and desk B lists them
ok   6p. desk A does not
ok   6q. the meat in the crate aged on the road (564 -> 604) and goes on ageing at B (616)
--- STEP 7 save and reload
ok   7. pieces: 23 before, all identical after the reload []
ok   7. boxes: 15 before, all identical after the reload []
ok   7. people: 2 before, all identical after the reload []
ok   7. the gambeson, the mail shirt and the backpack are still worn
ok   7. the Rustic - Chest is still locked
STEP 1 early survival: PASS
STEP 2 wood and metal: PASS
STEP 3 construction and equipment: PASS
STEP 4 cooking and preservation: PASS
STEP 5 food effects: PASS
STEP 6 storage and warehousing: PASS
STEP 7 save and reload: PASS
mission 001 walkthrough: PASS (0 failures)
```

## test_fire_fuel_tiers

Prints no per-check "ok" lines. Output is 22 lines of the form `fire store: one stick burned away (weak burned 120 s, N counted left)` in three countdowns (9 to 0, 5 to 0, 5 to 0), then `test_fire_fuel_tiers: ok`.
