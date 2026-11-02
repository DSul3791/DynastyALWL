















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

## death-new-start | After a real death with no child, where and how does the new character start?
Note: Design says the gear stays on the remains (owner only for the first real day, anyone after) and a wizard can fetch it for a fee.
Note: Recommendation A: the new character starts at the world spawn with an empty pack, like a new player; their old remains are marked on the map.
- At the world spawn, empty pack (recommended)
- At the world spawn with a small starter kit (stick, stone, twine)
- At the dead character's last bed, empty pack

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

## pic-p2-leanto-bed | Do the lean-to and the rough bed look like something you would shelter and sleep in?
Image: questions/img/p2_leanto_bed.jpg
Note: Real client, third person, lean-to left, rough bed right (the rig sets them in a row, the bed is not inside the lean-to here). Guide rates it 3.5 of 5: lean-to reads as a thatch frame; the bed is a yellow mattress on a frame.
- Yes
- No

## pic-yarrow-real | Do the white yarrow flowers look like real yarrow in the game?
Image: questions/img/kathreen-yarrow-real.png
Note: Real game, shade at the foot of a tree. Kathreen rates it 3.5 of 5: clearly white flowers, still a bit cool and faceted. Recommendation: Yes if the drift reads as flowers to you; No if the white looks grey or fake.
- Yes
- No

## jason-clear-hiss | Please test this: in clear, calm weather in a forest, do you hear a rain-like hiss?
Note: Blocked: the PC sound-log run hasn't happened yet. SOUND_AUDIT.md suspects the tree-wind loops (leaves, pine).
Note: 1. Start the latest build, wait for clear weather (F3 shows rain 0.00). 2. Walk into a forest and stand still for 30 s. 3. Then walk into open meadow for 30 s.
Note: Look for: a steady hiss like rain in the forest that stops in the meadow. If you hear it, open F3 and write the loudest sound line in the Notes box.
[test]

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
