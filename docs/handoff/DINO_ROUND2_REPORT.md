# Dino round 2 report (2 Nov 2026, paper review on main, no Godot run)

Nothing in game code or data was changed. Findings go to the moderator.

## 1. Clay hearth cost is understated in the hint and tutorial (drift)
- `data/items/hints.json` (`pot_first_dish`) says "Baked food needs a clay hearth: 10 bricks." TUTORIAL_FIRST_30_MIN.md step 24 says the same.
- `data/items/blueprints.json` (clay_hearth): cost is **10 bricks + 6 clay + 4 stones**, built with a **hammer** (hammer level 1) from the blueprint list, not from a kit recipe. A brick is 2 clay for 3 bricks at a campfire (recipe 128), so 10 bricks is about 8 clay of firing on top of the 6 clay.
- Effect: a player who reads the hint gathers 10 bricks and is then refused. Suggested owner: Sal (hint text), Jamie (tutorial text). Severity: medium (it blocks the first baked dish).

## 2. Open item "no tutorial step for the pot or hearth" is stale
TUTORIAL_FIRST_30_MIN.md already has steps 23 and 24 (31 Oct), and hints.json now has `plant_food_pot` and `pot_first_dish`. HANDOFF_DINO.md section 5 and PLAYTHROUGH_STEP_STATUS.md still list it as missing. Pot numbers match data (clay pot 6 clay; campfire pot 3 sticks, 3 twine, 1 clay pot). Only the hearth line is wrong (item 1).

## 3. Kits vs looks (the old "56 kits vs 19 looks" figure is out of date)
- 60 distinct structure looks for 63 structures; only 3 pairs share one: chest / plank_chest, large_forge / master_forge, path_patch / tilled_bed.
- 57 kit items have a look entry in looks.json; `chopping_block_kit` has none. 31 kits use the generic "kit" shape (campfire, lean-to, bed, pot, hearth, section kits, forges and others): that is the look of the kit in the hand and pack, so they look alike until placed. Suggested owner: Kathleen (decide whether kits need their own hand look). Severity: low.

## 4. Stick budget for steps 11-20
Sticks needed from data: campfire 6, axe 1, lean-to 32, bed 4, bench 16, wooden spear 1, knife 1 = 61, plus fuel sticks for the fire. The old "about 62" is right and is over the 60-stick playability-bot budget, so the bot stops before the bench. Suggested owner: Tyler (raise the bot budget to about 70). Severity: low.

## Still needs a machine with Godot
Windowed walk of steps 1-14, creator picture, live placement probe, lit-fire and felled-trunk pictures.
