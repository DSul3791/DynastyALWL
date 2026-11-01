# Scope: MikeW: Flora and Fauna Density and Placement (formerly Flora), 1 Nov 2026

> **UPDATE (Dave, 1 Nov 2026): animal BEHAVIOUR is yours too, not only placement:** wandering, fleeing, hunting, herding, resting, spawn and despawn, how they react to the player. Tyler keeps only the shared server rules animals plug into (damage and death handling, carcass, protocol).

> **RULE (Dave, 1 Nov 2026): anything about LOOKS is Kathleen's.** You keep density, placement, seasons and draw cost for plants and animals. How a plant or animal looks (shapes, flower and stem colours, grass appearance and shader look, fur, models) is Kathleen's. Report look problems to her with a picture, as with the yarrow stems.

> **ROLE ADDITION (Dave, 1 Nov 2026): animals are yours.** Fauna as a system: which animals live where, how many, density, placement and spread, herds, spawn rules and seasons (start at data/animals/ and the animal placer code). Kathleen keeps how animals look; Sal keeps what they drop and the animal text; Tyler keeps combat and behaviour rules in server code. Plants first, as already planned; then write a fauna measurement like your flora density one (animals within 100 m, 500 m of the spawn) and propose fixes.

## 1. The job
Make the world look alive and be fair to forage in: where trees, shrubs, berries, fibre plants, herbs, flowers and tall grass stand (density, clumping, seasons, harvest stores), how grass and plants draw at range, and what that costs. It starts at the placer and data (`flora_placer.gd`, `flora.json`, drops and fruit stores), the layout version, and the flora and grass views and shader. It stops at the art itself (Kathleen: models, colours, `tree_builder.gd`), animals, and item rules.

## 2. Done so far
- Density measurement and fixes, patch, thicket, orchard and shore rules, seasons and fruit store: see docs/FLORA_HANDOVER.md.
- Tall grass clumps and 25/40 m visibility: 8543fc35 (tool), layout v20.
- Grass clear radius at the player's feet: grass_view.gd, with guard fb90e7c5.
- Conifer nurseries instead of evenly spaced saplings: 69d43800 (v21).
- Meadow flowers with Kathleen's tall bright art: f0336365, 68c7901e (v22).
- Mid-model decimate crash guard: 4458a7c0.
- QA cards on the qa branch (last 26aaf274); pictures under E:/Software/godotDev/DynastyALWL_Evidence/alive_check.

## 3. Planned (in order)
1. Pictures: blueberry (F-13), chamomile, orchard, crowns; QA cards.
2. Resolve F-13: find the 3 m golden shrub labelled Blueberry; fix data or label.
3. Flower art follow-up with Kathleen (pale glassy stems, blue-grey heads in shade).
4. Check orchard picking and thinning in the real game.
5. Month-level fruit calendar.
6. Make the 40 m tall-grass clump readable in shade.
7. Flowers in the open meadow middle, not only at the edge.
8. Elder thickets to 90 percent in clumps of 4 or more.
9. Meadow draw calls: far-tree merging, then lower TREE_DENSITY if a weak PC needs it.
10. Models and rows for the future fruit trees (fig, olive, pomegranate, mango, orange, lemon).

## 4. Priorities
1. F-13 blueberry size: a visible, reported bug.
2. Pictures and QA cards: Dave judges by the QA page.
3. Flower look (with Kathleen): flowers are the most visible aliveness cue.
4. Real-game fruit picking: an untested path players will hit.
5. Draw-call cost: protects weaker PCs.

## 5. Dependencies
I depend on Kathleen (flora art), Tyler (test gates, godot_slot, world_alive), the moderator (merges, QA page) and Sal (fruit items, seasons data). Kathleen, Sal and Tyler depend on me for placement, flora.json rows and layout version bumps.

## 6. Finished when
All 7 flora tests pass on the daily; every open picture is on the QA page with Dave's Yes; F-13 is closed; fruit picking is verified in the real game; no frame-cost warning in the meadow on the target PC.
