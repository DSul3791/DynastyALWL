# First-hour walkthrough vs current build (generator-v2 d62dd3e, 24 Oct)
Ranked by what blocks the first hour. Source: data/items/recipes.json, cooking.json, sleep.json, drops.json, structures.json, src/shared/recipe_table.gd.

1. BLOCKER, no building. Every wall, floor, roof, foundation and doorway recipe is known=false and craft() refuses unknown recipes; no learn path found in code. They also need lumber (sawmill/iron) or stone+clay at a workbench. Only lean-to, chest, campfire and camp bench kits can be made. (List step 12.)
2. BLOCKER for shelter and bed. Nothing yields thatch (tall grass and reeds give 1-3 plant fibre only); no thatch wall or rough bed recipe; no tall grass clump plant. Lean-to (8 sticks + 6 leaves + 2 twine) and sleeping on open ground (hold Z 3 s) work, so night one is survivable. No bed, no respawn at bed. (Steps 11-13.)
3. Fire costs too much. Campfire kit = 20 sticks + 10 stones by hand; one fire strength; no tiny stick fire. Lighting takes 1 plant fibre from the pack (no stone striking). Roasting a raw item at a lit fire works. (Step 5.)
4. Recipes differ from Dave's: stone axe = 2 stone + stick (no twine); wooden spear = 1 stick (no rock); stone spear = 2 stone + stick + twine from scratch; stone hammer and adze = 2 stone + stick + twine at a workbench. Twine = 3 fibre works. (Steps 3, 4, 7, 15.)
5. No shore net recipe. Fishing rod (2 sticks + 2 twine) exists with hidden stock and bite roll. (Step 9.)
6. Camp bench (12 sticks + 3 twine) works. Rough plank (1 log, workbench) and hand lumber (1 log = 2) exist but nothing uses them for walls. (Step 14.)
7. Pickaxes exist only as iron/steel (forge, not learnable). Breaking rock with the stone axe is not verified. (Step 15.)
8. Cooking: simple roast works. No tripod pot or hearth. Named dishes need rare items (honey nectar, thyme). (Step 16.)
9. Not verified, needs Mike's play test: first-hour hints, drinking from streams, spawn resources. New-player switch does not exist yet.

Suggested fix order: (a) learn path or known building recipes; (b) thatch yields, clump plant, thatch wall, bed; (c) fire sizes and cheaper first fire; (d) axe/spear/hammer recipes, remove adze; (e) new-player switch; then shore net and cooking stations.

## Steps with no clear owner (proposed)
- Learn path for recipes: Steve/Tyler (no owner yet).
- Tall grass clump plant and thatch yields: Sal (thatch plan) with Kathleen for the look.
- Fire sizes: Sal. Bed and respawn at bed: Sal + Steve. New-player switch and first-hour hints and inner-voice settings panel: Steve.
- Grand blueprint and hammer blueprint maker: Sal (building).
- Copper/tin ore placement: Sonny. Choosing the final spawn point: Sonny + Dave.
