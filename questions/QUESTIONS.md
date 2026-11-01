















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
