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

## spade-raise | Please test spade Raise mode. Look for: each click takes soil from your pack and the pack count drops.
Note: 1. Switch a spade to Raise mode (right click).
Note: 2. Click on the ground.
Note: 3. Small spade should use 1 piece per click, medium 4, large 8.
[test]

## collapse-switch | Please test the tunnel collapse switch. Look for: green On, red Off, no shaking while Off, cave-in time kept after rejoining.
Note: 1. Esc > Settings > Tunnel collapse: press it Off, then On.
Note: 2. Press Cave-in time through 2, 5, 10, 20 min.
Note: 3. Quit and rejoin; the time should still be what you set.
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

## vsync | Please test VSync. Look for: On green, Adaptive amber, Off red, and the same after restart.
Note: 1. Esc > Settings > VSync: press it through all three.
Note: 2. Look for "(vsync X)" next to the fps in the top text.
Note: 3. Restart the game; the setting should be kept.
[test]

## ladder | Please test a ladder. Look for: it climbs, comes down, lets go backwards and steps you onto the top edge.
Note: 1. Place a ladder against a wall and face it.
Note: 2. Hold W to climb, then S to come down, Space to let go backwards.
Note: 3. Climb to the top and hold W: you step onto the edge.
[test]

## sound-fire | Please test Esc > Settings > Sound test: fire. Look for: each step is heard, from embers to the hiss when it is put out.
Note: 1. Open Esc > Settings > Sound test.
Note: 2. Press the fire sounds one by one.
[test]

## beach-loud | Is the beach still too loud when you walk on it?
Note: Kathleen already lowered sand steps by 3 dB. If the loud part is the waves, answer No and say so in Why not.
Note: Tyler recommends Yes only if the steps are what you hear: she lowers sand steps another 3 dB, which is cheap and easy to undo.
[check]

## offhand-items | Off-hand items: pick a torch, shield or similar from the hotbar and it goes in your left hand; pick it again and it is put away; hold B to block with it?
Note: This works for a torch, a shield and any other item that can be held in the left hand.
Note: Tyler checked: nothing in the game uses the B key today, so there is no clash.
Note: Tyler recommends Yes because it matches what you described and B is free. Steve builds the input and left-hand slot, Sal marks which items can go in the left hand, Kathleen does the hand pose. It is tomorrow's work, not tonight's.
[check]

## ground-piles | Should loose items on the ground of the same kind that land close together (about 1 m) merge into one pile with a count, so the limit of 64 items near a spot is no longer a problem?
Note: Today a drop is refused when 64 loose items are already within 12 m. Items already carry a count, so a pile is one ground item holding many.
Note: A pile shows bigger the more it holds. Picking up takes the whole pile or part of it, and the rock pile item is the same idea for rock.
Note: Tyler recommends Yes because it removes the limit without more lag (fewer objects to send and draw), and it matches the rock pile you already approved. Steve does merge and split on the server, Sal the pile counts, Kathleen the pile looks.
[check]

## rockpile-merge | Should rocks dropped within 1 m of each other join into one pile (same kind only, never tools), and does this fix the limit on items on the ground?
Note: Up to 5 they look like loose rocks, 6 or more become a pyramid pile made from the count (1 on top, 3 under, 5 under that...). One pile counts as one item, so the limit of 64 is no longer hit.
Note: Full design: tech/items/ROCK_PILE_DESIGN.md.
Note: Tyler recommends Yes because it removes the limit, adds no lag, and costs almost no save space (one entry per pile).
[check]

## rockpile-take | Taking from a pile: press E to take a handful (about 5), hold E to take as many as you can carry, and the pile shrinks row by row?
Note: At 5 or fewer left it turns back into loose rocks.
Note: Tyler recommends Yes because it is quick for one rock and for a lot, and matches the rock pile item Sal built.
[check]

## rockpile-kinds | Should the same pile rule work for soil, sand, clay, gravel and ore (as mounds), and for logs, planks and bricks (stacked, look later), but no mixed piles?
Note: Different kinds near each other stay separate side by side.
Note: Tyler recommends Yes because one rule is simpler for everyone, and mixed piles would be hard to take things out of.
[check]

## rockpile-block | Should a pile of 6 or more block movement like a boulder (you walk around it, you cannot climb it)?
Note: Loose rocks (5 or fewer) do not block and roll when you walk over them.
Note: Tyler recommends Yes because big piles would otherwise be walked through, and climbing makes terrain bugs. We can add climbing later.
[check]

## rockpile-despawn | Should a pile of 6 or more last 2 hours after the last add or take, instead of the usual 20 minutes?
Note: Loose items keep the 20 minute timer.
Note: Tyler recommends Yes because piles take work to make, and losing them in 20 minutes would feel unfair.
[check]

## rockpile-big | Above about 500 rocks, should the look change to a smooth rocky mound instead of drawing every rock, with a limit of 100,000 rocks per pile?
Note: A mound keeps the game fast. Past 100,000 a second pile starts beside the first.
Note: Tyler recommends Yes because drawing thousands of rocks would slow the game, and nobody can tell the difference at that size.
[check]

## cavein-death-slow | Should a cave-in that kills you be slow and dramatic: the roof falls in 3 to 5 waves over about 6 seconds, with dust and rumble, instead of all at once?
Note: Damage comes in chunks, one per wave, and you stagger and then lie down on the last one. You still get the full warning first.
Note: Tyler recommends Yes because it matches what you asked for and keeps the 90 second warning rule.
[check]

## cavein-death-fade | Then: the picture fades to black over about 4 seconds while the rumble keeps going for about 3 more seconds, then the sound fades out too?
Note: Tyler recommends Yes because it is the order you described and is easy to tune.
[check]

## cavein-death-skull | Then: a grey, translucent skull and crossbones fills about 75% of the screen over the black?
Note: Kathleen draws it (grim cartoon, not gory).
Note: Tyler recommends Yes because it is cheap to build (one picture with transparency) and easy to swap later.
[check]

## cavein-death-voice | Until the real voice exists, show the three lines as big text under the skull with a small horn sting and a comic sting, and swap the voice in later?
Note: Line 1 (sad): "I tried to warn you, but would you listen? Oh no..." Pause. Line 2 (jokey): "Oh well, now you're dead." Pause. Line 3: "Better luck next time, eh?"
Note: Tyler recommends Yes because the voice (Kokoro) is not built yet, and swapping sound files later needs no code change.
[check]

## cavein-death-next | Then everything fades out slowly and you fade in on the inheritance or character creation screen, and this long sequence is only for cave-ins (other deaths keep the simple screen)?
Note: Tyler recommends Yes because it gives cave-ins their own moment without slowing down every death, and we can add the sequence to other deaths later if you like it.
[check]

## lake-chunks-pic | Please take a picture of the lake water surface flickering between textures, with the F3 text showing your x, z.
Note: 1. Stand where the water surface rapidly changes textures (grey shapes at lake level).
Note: 2. Press F3 so the coordinates show, and take the picture. If you can, take two pictures a second apart.
Note: 3. In Notes write whether it was near a waterfall, the collapsed tunnel, or open lake, and whether it flickers all the time or only when you move.
[picture]

## head-ponds-retire | Should we stop making the round stamped pond at the top of each river, and let lakes and rivers start only where the land has a real catch basin (terrain B), at the next bake?
Note: Today the round pond at the top of the falls is stamped in by a rule (30 to 70 m wide, 10 to 14 m deep, a flat bench, an outlet brook). That is why it looks like a bowl set into the hillside. Plunge pools and the spill channel are stamped too.
Note: With terrain B, each lake is a natural basin from the land, and the river starts from its overflow and from rain gathering on slopes. Nothing changes until the next bake, and we look at the first natural result with you before it replaces anything.
Note: Tyler recommends Yes because polishing a stamped bowl will never look natural, and terrain B is already built (switched off for now) and gets its first small test bake tomorrow.
[check]

## lake-hide-water | Please test: hide the water and see what stays. Look for: do the grey shapes and dark squares STAY when the water is hidden?
Note: 1. Go to x 52392, z 69477 (or x 53786, z 69256) where the water surface flickers.
Note: 2. Press Ctrl+Shift+W (hides every river and lake drawing).
Note: 3. Yes means the shapes STAY (so they are ground, not water). No means they disappear with the water.
Note: 4. Press Ctrl+Shift+W again to bring the water back.
[test]

## lake-low-quality | Please test: set quality to Low and see what happens. Look for: do the grey shapes and dark squares VANISH on Low?
Note: 1. Go to x 52392, z 69477 (or x 53786, z 69256).
Note: 2. Press F2 until the quality says Low.
Note: 3. Yes means the shapes VANISH on Low (so it is the water's depth effect, and Sonny fixes it). No means they are still there.
Note: 4. Press F2 until you are back on your normal quality.
[test]
