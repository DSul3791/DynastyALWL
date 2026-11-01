















## pic-water2-in-game | Does the water look right in the real game with the new Dynasty water switched on (--water2, sea inlet on the starter tile)?
Image: questions/img/water2_game_first_person.png
Note: Real game, first person, the new water system feeding the old water look (the shader is unchanged on purpose). Sonny rates it 3 of 5: it works and looks like today's water; nothing visibly better yet, and only one 1 km window of one tile runs.
- Yes
- No

## pic-water2-game-shader-calm-rough | Is "fast but calm" vs "fast and rough" now visible with the game's own water shader (same river at 4.7 m/s: left calm, right rough)?
Image: questions/img/water2_game_shader_calm_rough.png
Note: Demo scene in Godot (not the running game) using the game's own water shader fed by the new Dynasty water sim. In the game the shader's roughness is tied to the flow rate; here it is a separate setting. Sonny rates it 3.5 of 5; in the real game the flow does not reach the shader yet (the protocol carries levels only).
- Yes
- No

## pic-fh-campfire-lit | In the real game: can you see a lit campfire (flames or glow) after you place the kit and light it with plant fibre?
Image: questions/img/fh_campfire_lit.jpg
Note: Real game rig shot (guide session), 60 s after placing and lighting. I see only stones half hidden in grass and a green placement-style glow; no flames. Guide rates it 1.5 of 5: either the fire is not drawn when lit, or the grass hides it. Not confirmed which.
- Yes
- No

## pic-fh-felled-trunk | In the real game: does a felled tree trunk look like bark (brown, rough), not a smooth black pipe?
Image: questions/img/fh_felled_trunk.jpg
Note: Real game rig shot (guide session), the trunk standing next to its stump after felling with a stone axe. The trunk reads dark grey-black and smooth, with a squared block beside it. Guide rates it 2 of 5; the bark fix 993aafab does not show here.
- Yes
- No

## pic-felled-bark-after | In the real game: do the stump and the cut log now look like brown bark (before: dark grey smooth, card pic-fh-felled-trunk)?
Image: questions/img/felled_bark_after.png
Note: Real game rig shot, same spot as the guide picture. The cause was missing warm shading; fixed with a brightness lift on the bark shader. Kathleen rates it 3.5 of 5: brown and textured; the stump side still looks smooth and the log is a plain block.
- Yes
- No

## fire-tier-1-survival | Fire tier 1: with 3 sticks, is the fire a small survival fire?
Note: 1. Place a campfire kit and put in exactly 3 sticks (or kindling or driftwood), then light it with plant fibre.
Note: 2. Look at the flame and stand 2 m away, then 4 m away.
Note: Expect: a small flame, light about 6 m, a little warmth only within 2.5 m (heat +8 C), gone when the sticks burn out. Fewer than 3 pieces still counts as tier 1.
[test]

## fire-tier-2-campfire | Fire tier 2: with 3 pieces of firewood, is the fire a proper campfire?
Note: 1. Place a campfire kit and put in exactly 3 firewood, then light it with plant fibre.
Note: 2. Look at the flame, then stand 3 m away on a cold night.
Note: Expect: a bigger flame than tier 1, light about 12 m, warmth out to 4 m (heat +20 C). It stays this size until the firewood is gone, then drops to tier 1 if sticks remain.
[test]

## fire-tier-3-bonfire | Fire tier 3: with 3 logs, is the fire a bonfire?
Note: 1. Place a campfire kit and put in exactly 3 logs, then light it with plant fibre.
Note: 2. Look at the flame, then stand 5 m away on a cold night.
Note: Expect: the biggest flame, light about 14 m, warmth out to 5 m (heat +25 C). Note whether the flame is visibly bigger than tier 2 and whether it shows at all (open campfire-flames bug).
[test]

## heavy-kits-carry | Heavy build kits: craft them from stock lying near the workbench, so you never carry 314 kg?
Note: A player carries about 52 kg. Stone wall kit needs 12 cut stone blocks (25 kg each) + 4 mortar = 314 kg. Fireplace kit about 79 kg, brick wall about 57 kg, brick floor about 54 kg. So the stone wall and fireplace kits cannot be made today.
Note: Option A (recommended): the workbench uses ingredients lying within 3 m, so you stack blocks beside it. Needs code (Steve), fixes all four.
Note: Option B: data only, lighter blocks and smaller kits. Brick wall and floor can be cut to about 43 kg, but stone stays above 52 kg.
Note: Recommendation: Yes, option A, because it fixes all four kits and matches how a builder stacks stone beside the work; option B stays as the fallback for the two brick kits.
[check]

## leanto-pace | Lean-to pace: does 32 sticks, 8 leaves, 4 twine feel right for the first hour?
Note: 1. Start a new character and time yourself with a stopwatch.
Note: 2. Collect the sticks, leaves and twine for a lean-to and place it.
Note: 3. Write down the minutes it took and whether it felt too slow, about right, or too quick. The pace numbers are estimates only.
[test]

## berries-stew-cook | Food: do berries (4 kcal) stew in a pot, and does the campfire refuse plants?
Note: 1. Pick 3 berries and hold water. Put a berry in the campfire: it should not cook (campfire cooks only meat and fish).
Note: 2. Place a clay pot on the campfire (6 clay, then 3 sticks and 3 twine), put in 3 berries and water.
Note: 3. Note whether you get Stewed berries and whether the hint about the pot appeared once.
[test]

## bake-terrain-set-1 | May we re-bake the 9 starter tiles once, with the terrain set on branch terrain-bake-set (recommended: yes, after the play-test settles)?
Note: What changes: lakes must have a lip of at least 4 m (coastal flats no longer flood and stand trees in water), ponds hold to 0.1 m under their rim instead of draining 1-2 m low, river ends are fed (settle rules v10), land types (shore marsh, treeline, evergreen belt), valley farmland becomes grass fields with hedge strips, and every tile with a river gets a river ore guarantee. TERRAIN_VERSION goes 44 to 45, so players' generated ground is thrown away once and rebuilt.
Note: Time: not measured on this machine; I will first bake ONE tile (3,4) and time it, then do the rest. Risk: the shape of lakes, rivers and the spawn area changes, so anything placed by hand near water may sit wrong; a bad bake is the main risk. Roll back: the old tiles stay in git (no tile is committed without your go), restore them and set TERRAIN_VERSION back to 44. Branch: terrain-bake-set (merge of claude/land-types2-springfeed plus lake-lip on the daily), unbaked and unrun.
- Yes
- No

## death-before-heirs | You said: respawn at the bed until level 10, then real death. Children and heirs are not built yet. What should happen to a level 10 character who dies, until they are?
Note: Today a death leaves your remains with all your gear and then puts you back at the spawn point (nothing is lost for good). Real death needs a screen that says you died and sends you to the creator for a new character; that screen is not built.
Note: Option A (recommended): keep respawning at level 10 and above, but leave the remains as today; switch to real death in the same release that adds children and the death screen. Nobody loses a character before there is anyone to inherit.
Note: Option B: real death now. The character is gone, the player makes a new one, the old gear waits in the remains for 7 days. Needs the death screen first (a few days of work).
- Keep respawning until heirs and the death screen exist (recommended)
- Real death at level 10 now, build the death screen first

## death-new-start | After a real death with no child, where and how does the new character start?
Note: Design says the gear stays on the remains (owner only for the first real day, anyone after) and a wizard can fetch it for a fee.
Note: Recommendation A: the new character starts at the world spawn with an empty pack, like a new player; their old remains are marked on the map.
- At the world spawn, empty pack (recommended)
- At the world spawn with a small starter kit (stick, stone, twine)
- At the dead character's last bed, empty pack

## death-downed-state | Should we build the "downed" state (knocked out, can be revived or carried, bleeds out after a timer) before real death?
Note: Design 6.1 decided it (ARK style). It is large: a new body pose, a revive action, a timer that keeps running while offline, and carrying another player.
Note: Recommendation A: no, build it after real death and children. Today a character at zero health dies at once.
- Later, after real death and children (recommended)
- Before real death
- Never, keep death immediate

## pic-flora-yarrow | In the real game: does the white yarrow drift (bottom left, with varied tree crowns) look like white flowers in the shade, not blue-grey metal?
Image: questions/img/flora_yarrow_crowns.jpg
Note: Real game rig shot at noon, (53302,68423) facing north. Placement is right (a dense drift at the forest edge). The heads read blue-grey, faceted and slightly metallic and the stems are pale, so Flora rates it 3 of 5. The look is Kathleen's (warmer head colour, smoother normals, matte stems). The crowns look varied: 4 of 5.
- Yes
- No

## pic-flora-chamomile | In the real game: is the chamomile and wildflower meadow (yellow drift, red roses behind a bush) a good spread of colour?
Image: questions/img/flora_chamomile_roses.jpg
Note: Real game rig shot at noon, (53326,68446) facing north. The yellow drift and red roses show; white chamomile is not clearly visible from here. Flora rates it 3.5 of 5.
- Yes
- No

## pic-flora-orchard-rows | In the real game: do the orchard trees read as rows of fruit trees?
Image: questions/img/flora_orchard_rows.jpg
Note: Real game rig shot at noon from the south edge of the orchard, (53376,68535). The rows read, but it is dark under the crowns and no fruit is visible from this height. Flora rates it 3 of 5; fruit visibility is a look question for Kathleen.
- Yes
- No

## pic-flora-blueberry-size | Is the small bush on the right (about 30 cm tall, blue berries, ten metres away) a believable blueberry plant size?
Image: questions/img/flora_blueberry_size.jpg
Note: Real game rig shot at noon, (53331,68359) facing north, from 1 m above the ground. This is a real blueberry placed by the game (data says 0.25 to 0.5 m). The shrub in the old picture 02b that was about 3 m wide and labelled Blueberry is not a blueberry by the data (raspberry is 1.5 to 2.5 m), so the label in that rig row is the likely mistake. Flora rates this 3.5 of 5.
- Yes
- No

## pic-p2-creator | Does the character creator preview show the FRONT of the body with sensible colours?
Image: questions/img/p2_creator.jpg
Note: Phase 2 real window (guide session), creator after "undo twice". The preview still stands with its back to us (ponytail seen from behind) and the body is patchy green, tan and pink. Guide rates it 2 of 5.
- Yes
- No

## pic-p2-fire-nograss | With the grass hidden, is the lit campfire clearly visible (flames and glow)?
Image: questions/img/p2_fire_nograss.jpg
Note: Same lit fire as the earlier card but with grass switched off. A small flame and warm glow show among the logs and stones, so the fire is drawn; the grass hid it before. Guide rates it 3 of 5 (flame small). Question for Dave: should grass be cleared around a placed fire?
- Yes
- No

## pic-p2-leanto-bed | Do the lean-to and the rough bed look like something you would shelter and sleep in?
Image: questions/img/p2_leanto_bed.jpg
Note: Real client, third person, lean-to left, rough bed right (the rig sets them in a row, the bed is not inside the lean-to here). Guide rates it 3.5 of 5: lean-to reads as a thatch frame; the bed is a yellow mattress on a frame.
- Yes
- No
