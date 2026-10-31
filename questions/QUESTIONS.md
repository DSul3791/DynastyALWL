














## pic-fireplace-light | Does the lit fireplace light up the ground in front of it only (front shown), with the sides and back dark?
Image: questions/img/fireplace_light_front.png
Note: Real game at dusk, with Tyler's front-facing spot light (the side view is questions/img/fireplace_light_side.png: dark at the side, light only in front). Kathleen rates it 4.5 of 5: the cone and shadows are right and the brick inside glows warm.
- Yes
- No

## pic-grass-feet | Do the character's feet and lower legs now show above the grass in third person (left: before, right: after)?
Image: questions/img/grass_feet_before_after.png
Note: Real game, third person, noon, same spot. Flora rates it 4 of 5: grass within 1.8 m of the player is cut low with a soft edge (done in the grass shader, no extra draw), boots and legs are visible; the cut patch is a little visible as a soft hollow.
- Yes
- No

## pic-meadow-saplings | Does the starter meadow look more natural now, with no lone young conifers standing in the open grass (left: before, right: after)?
Image: questions/img/meadow_saplings_before_after.png
Note: Real game, noon, same spot. Flora rates it 3.5 of 5: the evenly spaced saplings are gone from the open meadow (young conifers now only in patches or next to a parent tree); the meadow is still one uniform lawn without flowers.
- Yes
- No

## pic-tall-grass-25m | Can you spot the tall-grass clump (circled) from about 25 m away, standing in the meadow?
Image: questions/img/tall_grass_25m.png
Note: Real game, noon, camera 25 m west of a clump at (53358,68366). Flora rates it 3.5 of 5: it reads as a tuft of tall grass with dark plumes at 25 m, but small; at 40 m it is only just visible and dark in shade.
- Yes
- No

## death-novice | Our design says death is final (remains, then you play on as your child or a new character; no respawn). Should new characters get a free respawn at their bed until they reach a set level?
Note: Today the build respawns you at your spawn bed on death, which does not match the design (DESIGN_IDEAS.md section 6.1: "dies; the player restarts as a new character", heir inherits). Your idea fixes that: a short "novice grace" so new players can learn, then real dynasty death. Recommendation: respawn at the bed until level 5, then real death with remains and an heir, because a first-hour player has no heir yet and no reason to lose a whole life to a fall.
- Respawn at the bed until level 5, then real death
- Respawn at the bed until level 10, then real death
- No respawn at all (design as written; no heir means a new character)
- Respawn until the character has a child (an heir), then real death

## pic-water2-basin | Does the new water fill a bowl, spill over the low rim and run down the hill around the bump (four frames, 20 / 70 / 140 / 300 s)?
Image: questions/img/water2_basin_series.png
Note: Real Godot render of the new Dynasty water sim with a demo shader, not the game's water look. Sonny rates it 3 of 5: the flow is right, the picture style is plain.
- Yes
- No

## pic-water2-calm-rough | Is "fast but calm" vs "fast and rough" a good split (the same river at 4.9 m/s, left calm, right rough)?
Image: questions/img/water2_valley_calm_vs_rough.png
Note: Real Godot render of the new sim with a demo shader. Flow speed and waves are separate settings; both pictures are the same simulation. Sonny rates it 3.5 of 5.
- Yes
- No

## pic-water2-kinds | Do the liquids look and move differently enough (water, swamp, lava after 60 seconds on the same slope)?
Image: questions/img/water2_kinds.png
Note: Real Godot render of the new sim with a demo shader. Fronts after 60 s: water 188 m, swamp 98 m, lava 28 m. Sonny rates it 3 of 5; the lava glow is overexposed.
- Yes
- No
