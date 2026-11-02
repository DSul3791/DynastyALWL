















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

## mikew-fauna-day-wolves | Animals: more animals by day near the start, and should wolves be on?
Note: Blocked on your call (MikeW). Measured at spawn (PR #19): by day about 2 deer, 2 rabbits, 4 songbirds within 500 m; at dusk 5 deer. Wolves are switched off in the data (target 0), so nothing hunts.
Note: Recommendation: more daytime deer and rabbits, wolves stay off for now.
- More by day, wolves off
- Leave as is
- More by day, wolves on

## tree-hits-follow-size | Should a small tree take fewer axe hits than a big one of the same kind?
Note: Today the hit count uses the kind of tree only, so a 6 m beech takes as many hits as a 28 m beech.
Note: Felled trunks now match the real size of each tree; the hits could follow that same size.
Note: Recommendation: Yes, because a sapling taking as many blows as a giant feels wrong, and big trees would take a little longer.
[check]

## claude-crop-seeds | Which wild plants should give the other crop seeds (potato, turnip, cabbage, onion, peas, beet, radish, lettuce)?
Note: 8 of 14 crops have no seed source, so their farming and cooking recipes cannot be reached. Oats and rye now come from tall grass (PR 96).
Note: Option A: add wild plants to the world, one per crop, each giving seeds (wild turnip, sea beet, ramsons, vetch and so on). Option B: seeds come from the food you gather or buy (dig a root and keep a seed, buy seed from an NPC trader).
Note: Recommendation: B for the first week, because it needs no new plant art and Hob or Edda can sell seed; add wild plants later.
[A] Wild plants for each crop
[B] Seeds from food or trader first

## sal-lumber-vs-picking | Lumber pays far more than picking. Is that right, or cut it?
Note: Picking now pays a poor wage, about 48 copper for 4 hours (0.2 copper a minute). One spruce log sawn at a mill gives 7 lumber, and Hob pays about 4 copper each, so about 28 copper from one log. That is a day's picking wage in a few minutes of chopping and sawing, but it needs an axe, a sawmill and carrying a 32 kg log.
Note: Option A: leave it, because sawing is skilled work with a machine and a heavy carry, and it gives players a reason to build the sawmill. Option B: cut the lumber price so a log is worth about 10 copper (lumber value 8 to 3). Option C: Hob pays full price only for a few boards a day (a small shelf limit), then very little.
Note: Recommendation: C, because it keeps the reward for building a sawmill but stops one trader being drained by logs. Say A, B or C and I will make the change.
[A] Leave it
[B] Cut the lumber price
[C] Limit how many boards Hob buys a day

## sal-wanted-orders | Should Hob post one small "wanted order" a day, so a poor-wage day has a goal?
Note: Now a day of picking pays about 48 copper at a flat rate with no goal. Survival and farming games (Medieval Dynasty, Stardew Valley's bundles, 7 Days to Die trader quests) pace early income with small asks from a trader: bring a set amount, get a fixed bonus. My web search returned mostly forum titles, so this comes from how those games work, not from numbers I could check.
Note: Example: "60 sticks and 10 plant fibre for 6 copper" (about twice the lot rate), one order a game day, refreshed each day. It teaches the town's needs, lets a player reach the bed sooner, and is easy to cap so it cannot break the wage.
Note: Recommendation: Yes, as a small first version with one order a day. It is a small data and server change; I would not start it before your answer.
[A] Yes, one wanted order a day
[B] No, keep the flat lots only

## sal-bed-for-sale | Hob now sells a rough bed (37 copper) as the place to sleep a day's wage can buy. Right?
Note: Your wage answer said a day of picking buys a meal and maybe a place to sleep, but Hob sold nothing to sleep in. A day now pays about 48 copper: meal 8 plus rough bed 37. The bed is a kit you place yourself.
Note: Option A: keep the rough bed (37). Option B: sell a lean-to kit (39) instead, which is shelter plus a place to lie. Option C: sell neither; sleeping is only what you build.
Note: Recommendation: A, because it is the cheapest thing that fits a day's wage.
[A] Keep the rough bed
[B] Sell a lean-to kit instead
[C] Sell neither

## tyler-bug6-first-fell | Bug 6: on a fresh start, fell the first tree; does it fall straight away with no pause and no missing tree?
Note: Fix merged in #98 (main e69a1ad): the felled trunk's bark is prepared while the game loads, and the trunk is sent with the cut.
Note: Start the game fresh, fell the first tree you find, then a second one. If anything pauses, say on which blow or at the landing.
- Yes
- No

## steve-damage-numbers | Hits: do floating damage numbers show, and does the Gameplay toggle turn them off?
Note: 1. Hit a tree, a boulder and an animal.
Note: 2. Check: a number rises and fades where each hit landed.
Note: 3. Esc > Settings > Gameplay > Damage numbers off, hit again: no numbers.
Note: Recommendation: On main (#82).
[test]

## steve-bush-work | Bushes: does an axe chop a bush into leaves and sticks, and a pickaxe dig it up to replant?
Note: 1. Hit a bush (hazel is fine) twice with the axe: it goes, you get leaves and sticks.
Note: 2. Hit another bush twice with the pickaxe: you get the bush item, for example hazel_bush.
Note: 3. Hold the bush item, aim at open ground and press the use key to plant it.
Note: 4. Check: a full bush stands there and is still there after a restart.
Note: Recommendation: On main (#84, #100).
[test]
