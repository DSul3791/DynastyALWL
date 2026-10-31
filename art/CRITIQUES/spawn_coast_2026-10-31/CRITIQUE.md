# First-hour spawn area on the corrected world: does it look like a real, alive island? (2026-10-31, Kathleen)

Pictures (real game, tools/look_rig.sh --cam first --yaw N --agl 1.7 --wait 150, noon, autumn; spawn 53301, 68427, ground 31 m; the rig's test characters Edda and Hob stand in some frames and are not part of the game): coast_yaw0.jpg (north), coast_yaw90.jpg (west), coast_yaw-90.jpg (east). A south view did not finish.

Honest verdict: not yet. The land itself is a big step up (a full, varied forest of autumn broadleaves and pines, shrubs, ferns, flowers, a meadow), but the spawn sits where the water takes over and the water, the shore and a few object placements break the illusion. Rating of the scene as a whole: 2 of 4.

## Top ten visual problems, most damaging first, with owners

| # | Problem | Picture | Owner | Fix |
|---|---|---|---|---|
| 1 | The spawn is on or beside flooded ground: north, a forest stands in a lake; east, a flat sea runs to the horizon with no land in sight | coast_yaw0, coast_yaw-90 | world / water (terrain heights and sea level) | put the first-hour spawn on dry land at least 20 m above the water, with the coast in view |
| 2 | Loose sticks and stones sit on top of the water surface, floating in a line to the horizon | coast_yaw-90 | server items scatter / Sal (floor_below and water depth) | do not scatter on submerged ground, or settle onto the seabed; I will draw them correctly once placed |
| 3 | The water is an opaque perfect mirror: no depth tint, no transparency to the bed, no ripples, no foam; it reads as a sheet of glass | coast_yaw0, coast_yaw-90 | water renderer | depth tint from shallow turquoise to deep blue, soft transparency at the edge, small waves, a foam line where it meets land |
| 4 | No shore: grass runs straight into the water, no wet sand, sand, pebbles, driftwood, shells, kelp or seaweed band | coast_yaw0 | terrain materials (ground texture) and me (shore props) | a 3 to 8 m beach band of sand then wet sand, pebbles, driftwood, shells, seaweed; my part is the props and models |
| 5 | The puddle on the meadow is a hard-edged dark blue jagged sticker, the same blue as deep sea | coast_yaw90 | water / puddle | soft edge, shallower and browner tint, reflect the sky faintly |
| 6 | Broadleaf canopies carry pale spike-like branch stubs sticking out through the leaves like quills | coast_yaw90, coast_yaw0 | me (tree_builder.gd branches) | shorten and darken stubs, hide the tips under the foliage |
| 7 | Broadleaf trunks are pale blue-grey with marble blotches, wrong for oak and beech | coast_yaw90 | me (bark texture and tint) | warm grey-brown bark tint, finer vertical ridges |
| 8 | Shrubs are dark blob masses with large flat leaf sprites; they read as heavy dark bags beside the pale trunks | coast_yaw0, coast_yaw90 | me and the flora session | lighter, smaller leaf cards with some gaps and visible stems, berries in season |
| 9 | Wildflowers have a grey-green scruffy mound at the foot (lavender row in the foreground) | coast_yaw90 | me (wildflower basal clumps) | narrow leaves along the stems; the same fix as for flax |
| 10 | Nothing alive in sight: no birds, insects, rabbits or deer in the first-hour view, no shore birds | all | Sal (spawn rows) and me (models) | songbird, gulls and a rabbit near the spawn; my models for them are next after the rabbit |

What already works: sky and clouds, distance fog, autumn colour variety, the meadow grass, the conifers, the ferns, flowers in clumps.
