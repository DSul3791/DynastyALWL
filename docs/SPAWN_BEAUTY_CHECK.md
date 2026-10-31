# Spawn-area beauty check (flora session, 2026-10-31)

Ten things that would make the spawn view (53301, 68427, temperate forest) prettier, and what was done at data level.

1. **A forest that reads as a forest:** hardwood mix back (beech, maple, oak), trees 2.6 times the table figure, shrub understory 78 to 90 per hectare. Done (flora.json, TREE_DENSITY).
2. **Flowers:** meadow and clearing flower density up (yarrow, St John's wort, chamomile, thyme, foxglove, dewlantern). Done; colour change by season needs wildflower bloom looks (Kathleen).
3. **Tall grass patches, clearly taller than the ground grass:** done (patches, 1.3 to 1.8 m); readability at 20 to 40 m not yet seen.
4. **Berries and fruit near the spawn:** bramble 7 m, elder 4 m, raspberry 26 m, blueberry 35 m. Done.
5. **Fallen logs, hollow logs, old stumps:** about 4.5 per hectare, 14 within 100 m of the spawn. Done; needs a look at the models in game.
6. **Mushrooms and moss on the forest floor:** raised. Done (chanterelle, porcini, staunchmoss, mushrooms).
7. **Wildlife in sight:** animals within 60 to 120 m, butterflies, bees, birds, fireflies. Done (code), not yet seen.
8. **Season colour:** green spring and summer, colour in autumn, brown winter leaves; grass tint by season. Done (code), not yet seen.
9. **Rocks and boulders with moss:** not a flora row; ground scatter (drops.json ground_scatter) places stones and sticks; moss-covered boulders need a model (Kathleen).
10. **Light:** sun shafts through the canopy and a cooler tint under big crowns; the cover rule already thins grass and deepens litter under crowns; shafts and tint are shader work (not done).
