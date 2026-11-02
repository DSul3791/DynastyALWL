















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

## pic-campfire-lit-real | In the real game: is this lit campfire (stone ring, logs, flames, warm light on the ground at dusk) visible and right? (Grass hidden to see it; the guide's earlier picture had tall grass over it)
Image: questions/img/campfire-lit-real.png
Note: Kathleen's rig shot of a placed and lit campfire. The fire is NOT missing: flames and glow draw. The flames are small and pale cream; Kathleen rates it 3 of 5 and will make them bigger and more orange if you say No.
- Yes
- No

## pic-apples-smooth | Do these apples (four views) now look like smooth round apples with a stem and a highlight?
Image: questions/img/apples-smooth.png
Note: Rebuilt as a lathe with 12 sides and a dimple at the stem (they were low-poly diamonds). Offline picture, not the game. Kathleen rates it 3.5 of 5.
- Yes
- No

## pic-fibre-cloth-weave | Does the fibre cloth (left, brown) now show woven lines (linen on the right for comparison)?
Image: questions/img/fibre-cloth-weave.png
Note: Thin dark threads along the cloth and pale threads across it, on the folded top. Offline picture. Kathleen rates it 3.5 of 5.
- Yes
- No

## pic-shore-net-look | Does the shore net now look like a hand net (pole, hoop, string bag, floats) and not a hammer?
Image: questions/img/shore-net-look.png
Note: Four views, offline picture. Kathleen rates it 3.5 of 5 (thin, but clearly a net).
- Yes
- No

## pic-axe-no-cube | Is the stone axe now a smooth blade with no grey cube at the end (four views)?
Image: questions/img/axe-no-cube.png
Note: The grey cube (poll block and chipped corner) is removed. Offline picture on a sheet, not the held view. Kathleen rates it 3.5 of 5.
- Yes
- No

## pic-yarrow-real | Do the white yarrow flowers look like real yarrow in the game?
Image: questions/img/kathreen-yarrow-real.png
Note: Real game, shade at the foot of a tree. Kathreen rates it 3.5 of 5: clearly white flowers, still a bit cool and faceted. Recommendation: Yes if the drift reads as flowers to you; No if the white looks grey or fake.
- Yes
- No

## pic-chamomile-real | Do the white daisies (chamomile, left of the picture) look like real daisies in the game?
Image: questions/img/kathreen-chamomile-real.png
Note: Real game. Kathreen rates it 3 of 5: the white petals carry a grey-blue speckle; the yellow flowers beside them read well. Recommendation: No, we will fix the petal material.
- Yes
- No

## pic-blueberry-real | Does the blueberry bush (right of centre, with blue berries) look like a blueberry bush?
Image: questions/img/kathreen-blueberry-real.png
Note: Real game, from about 4 m, grass in front. Kathreen rates it 3 of 5: small dark thin bush with blue berries, easy to miss behind the grass.
- Yes
- No

## pic-creator-front | Does the character creator preview now face you with a readable face?
Image: questions/img/kathreen-creator-front.png
Note: Real creator scene facing the camera (it starts at 180 degrees and then turns slowly). Kathreen rates it 3 of 5: face reads, colours are flat. Recommendation: Yes for facing front; flat colours are a separate later polish.
- Yes
- No

## pic-body-details | Does the character in the game now have a nose, brow and thumb that read at a normal distance?
Image: questions/img/kathreen-body-details.png
Note: Real game, third person from the right at 1.6 m. Kathreen rates it 3 of 5: reads as a person, the face is still crude.
- Yes
- No

## sell-lots-value1 | Cheap goods sell at a full copper each: give them lots like stones (5 for 1 copper)?
Note: Stones now sell 5 for 1 copper. Everything else worth 1 copper still sells at 1 copper each, so 40 sticks pay 40 copper and 40 stones pay 8.
Note: Groups: sticks, leaves, bark, plant fibre, feathers, nettles, nails, wooden pins, soft firewood; soil, clay, sand, gravel; all seeds. Each group is one line of data (sell_lot), nothing else changes.
Note: Proposed lots: sticks, leaves, bark, fibre, nettles, feathers 5; soil, clay, sand, gravel 10; seeds 5; nails and wooden pins 10; soft firewood 5.
Note: Recommendation: Yes, with those lots, because these are free-to-gather bulk goods and a full copper each lets a player sell stacks of 40 for easy coin; heavier digging goods get bigger lots because a pile of dirt is worth less than a stick.
[check]

## first-day-lots | Sell lots for cheap goods: is about 195 copper for a 4 hour day of gathering right?
Note: Target (your rule): one day of gathering buys 3 meals (24), a waterskin (20), clothing (33) and an iron spade (117), about 195 copper, no more.
Note: Lots: sticks and leaves 15, fibre 12, nettles 10, bark 8, soil/clay/sand/gravel 5, seeds 4, soft firewood 5, pins 5, nails 10, feathers 2, stone 5 (stone lands at 288 in 4 h; 6 would give 240).
Note: I assumed 4 hours of play and made-up pick rates (12 a minute for sticks, 4 for digging); nobody has timed them. Table: docs/ECONOMY_FIRST_DAY.md. At 8 hours everything doubles. Hob's purse (300 cap, 100 an hour) also caps one trader.
Note: Recommendation: Yes, because every item then pays about 0.8 copper a minute, so what a player gathers does not change the day's income; if you think 4 hours is too short, tell me the hours and I rescale the lots.
[check]

## softwood-boards | Softwood boards: spruce and pine saw faster and give 7 lumber a log (hardwood 6)?
Note: Your note: softwood is better for boards than firewood. Before, every wood sawed the same: 6 lumber a log in 6 s, 2 beams in 8 s. Softwood logs already weigh less (32 against 45 kg) and softwood lumber is worth less (8 against 12 copper).
Note: Now: spruce and pine lumber 7 per log in 5 s, beams 2 per log in 6 s. Hardwood unchanged.
Note: Bigger question: hardwood is classed 'fine boards' and softwood 'plank boards'. Should fine boards be worth more (floors, furniture) and plank boards the cheap building board? Today both are called lumber.
Note: Recommendation: Yes, because softwood saws easily and straight, so a bit more, faster lumber fits your note; keep the fine-board question for later when furniture needs it.
[check]

## tyler-bug6-cut-log | Bug 6: cut one log off a felled trunk; does the game still pause for about a second?
Note: Blocked: the PC run only had the lag lines at join (world items 1070 ms, 961 ms building loose item meshes; PR #61 now builds those while loading). Nobody cut a log in that run, so the per-cut pause is still unmeasured.
Note: 1. Start the latest build, wait 10 s after you arrive. 2. Fell a tree or use one already down, cut one log off it with the axe. 3. Note if it pauses.
Note: Expect: no pause. If it pauses, the console prints a line starting "client slow:" right after the cut; send that line to Tyler.
[test]

## tyler-arms-axe-look | First-person arms (PR #58): hold the stone axe; are both hands on the handle and nothing through the camera?
Note: Blocked on your look: the headless arms check passes (4013 cases), but a picture cannot judge if it feels right in your hands.
Note: Hold the stone axe, look level and then down; swing once.
- Yes
- No

## tyler-bug7-arms-compression | Bug 7 trial (PR #31): with the arms textures compressed, is the frame rate better and do the arms still look the same?
Note: Blocked: needs a windowed fps comparison on your PC. Same spot, Ultra, F3 overlay: average and worst frame on main, then on branch claude/tyler-bug7-compress-textures.
Note: The three arms textures are about 200 MB uncompressed in graphics memory; compression makes them 4 to 8 times smaller. A suspect for the constant lag, not proven.
Note: Recommendation: Yes only if fps is better and the skin shows no blocky patches.
[check]

## sonny-headpond-leak | Sonny blocked: run the head-pond escape-path probe (two coastal ponds drain dry)
Note: Two shallow head ponds on tile 3,4 lose their water to the sea; test_head_pond_fill fails on them. Sonny needs the escape path to fix the bake, and has no Godot.
Note: 1. git fetch origin, then git checkout sonny-20261102-pondprobe
Note: 2. godot --headless --path . --script res://tools/head_pond_probe.gd -- --only=1900590,3082096 (about 10 min)
Note: 3. Paste the lines that start with path into Notes
[test]

## fp-arms-axe-pr58 | First-person arms with the stone axe (bug 4, PR 58)
Note: Blocked: Kathreen chose the new arm position from bare-arm pictures and cannot see a held tool.
Note: 1. Play the build with PR 58 merged (or branch claude/kathreen-arms-pos).
Note: 2. Hold the stone axe, stand still, look level and then 35 degrees down.
Note: 3. Swing at a tree twice.
Note: 4. Yes if the hands hold the axe and no huge upper arms fill the top corners; No and a note or screenshot if not.
[test]

## jason-pixabay-urls | Sounds: which Pixabay pages did your footsteps, frogs, tree frogs, fish splash, crows, angry crow, wing flaps and brook come from?
Note: Blocked: 8 rows in assets/audio/CREDITS.csv say "page URL TODO". The licence is known (Pixabay); only the page links are missing, and we need them before release.
Note: 1. Paste any links you still have, one per line, with the sound name. 2. If you don't have them, type "don't know" and I'll list these as needing a replacement before release.
[text]

## jason-new-animal-calls | Sounds: boar, grouse, seal and seabird have no calls yet. Where should they come from?
Note: Blocked: their footsteps borrow existing clips (PR 41), but there's no recording for their calls, and made-up calls sounded fake to you before.
Note: Recommendation: MikeW finds Pixabay clips on the PC, because the cloud can't reach Pixabay; I then cut and level them and post one card per animal for your ear.
- MikeW finds Pixabay clips, Jason cuts them
- I'll record or send my own
- Leave them silent for now

## jason-clear-hiss | Please test this: in clear, calm weather in a forest, do you hear a rain-like hiss?
Note: Blocked: the PC sound-log run hasn't happened yet. SOUND_AUDIT.md suspects the tree-wind loops (leaves, pine).
Note: 1. Start the latest build, wait for clear weather (F3 shows rain 0.00). 2. Walk into a forest and stand still for 30 s. 3. Then walk into open meadow for 30 s.
Note: Look for: a steady hiss like rain in the forest that stops in the meadow. If you hear it, open F3 and write the loudest sound line in the Notes box.
[test]

## dino-blocked-pc-walk | Dino (guides) is blocked: the first-hour windowed walk and its pictures need Godot, which the cloud does not have. Who should run them?
Note: Commands are ready in docs/handoff/DINO_ROUND3_PC_COMMANDS.md (probe, status table, creator, lit fire, felled trunk, lean-to) and the per-bug checks in docs/handoff/DINO_BUG_CHECKS.md. Dino has moved on to paper work meanwhile.
- The PC thread runs the commands
- I walk the checklist myself
- Skip it for now

## tut-fell-line | After a tree falls it now breaks into logs, sticks and leaves by itself. Which tutorial line should the player see?
Note: Tutorial step 10 still says "Keep striking the fallen trunk". Since 2 Nov the trunk breaks up about 2 s after landing.
- "Your tree has broken up. Press E to take the sticks and leaves, and a log on your shoulder."
- "Your tree is down. Gather what fell: sticks, leaves, bark and logs."
- No line, the player will see it

## felled-tree-size-and-split | Does a felled tree keep its size and break into logs?
Note: The team's headless tests all pass; only the look in the game needs you.
Note: 1. Start the game and walk to a small tree and a big tree near the starter town.
Note: 2. With the stone axe in hand, chop the small tree until it falls.
Note: 3. Watch it fall: it should lie on the ground at the same thickness and height it had standing.
Note: 4. About 2 seconds after it lands it should turn into logs along where it fell, with a heap of sticks and leaves beside it.
Note: 5. Do the same with the big tree, and note any stall or freeze when it breaks up.
Note: Recommendation: Yes, because the size now uses the same scaling as the standing tree and the tests pass.
[test]

## kathleen-firewood-kindling-look | Do firewood and kindling look like split wood and thin sticks?
Note: Blocked here: no Godot in my cloud box. New looks are in pull request 60, untested.
Note: 1. In GitHub Desktop, switch to branch claude/kathleen-wood-looks-20261102.
Note: 2. Run the game and open your inventory with firewood and kindling in it.
Note: 3. Drop one of each on the ground and look from 2 m.
Note: 4. Say Yes if firewood reads as split logs with pale faces and kindling as a handful of sticks; No plus what is wrong.
Note: Recommendation: Yes, merge it if they read right, because every player handles these daily.
[test]
