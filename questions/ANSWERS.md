# Answers

## coffer-raid | Banking: if raiders break a family coffer, how much coin do they get?
Answer: None, a coffer cannot be raided
Answered: 2026-10-21 23:15 UTC

## coffer-place | Banking: where can a family coffer be placed?
Answer: Only inside owned land
Answered: 2026-10-21 23:15 UTC

## coffer-access | Banking: who can open a family coffer?
Answer: Only the owner
Answered: 2026-10-21 23:16 UTC

## coffer-atm | Banking: is there a fee to use coin from a faraway coffer for a big deal?
Answer: Free
Answered: 2026-10-21 23:16 UTC

## coffer-heir | Banking: when a character dies, what happens to their coffers?
Answer: They pass to the heir
Answered: 2026-10-21 23:17 UTC

## deal-offline | Banking: can a big deal be sealed while the payer is offline?
Answer: Yes, the agreement waits and seals when the coin is there
Answered: 2026-10-21 23:17 UTC

## fishing-bait | Fishing: should bait still make dawn fishing a sure bite (a fish every 19 s)?
Answer: Cap the bonus so dawn is a bit under sure (about 0.93 a cast)
Answered: 2026-10-22 00:06 UTC

## fishing-hint | Fishing: show a hint when a spot is nearly fished out?
Answer: Yes, "the water is still" when under 3 fish are left
Answered: 2026-10-22 00:06 UTC

## cast-roles | Starter town people: who lives here besides Hob (shopkeeper) and Edda (guard)?
Answer: Keep just Hob and Edda for now
Answered: 2026-10-22 00:06 UTC

## cast-names | Starter town people: what are the new people called?
Answer: I will name them myself later
Answered: 2026-10-22 00:07 UTC

## cast-trade | Starter town people: what do they trade?
Answer: Only Hob trades; the others only talk and give quests
Answered: 2026-10-22 00:07 UTC

## cast-child | Starter town people: should there be a child?
Answer: Yes: Pip chats, plays, and runs small errands, never trades or fights [recommended]
Answered: 2026-10-22 00:07 UTC

## fall-channel | The 300 m waterfall near x 53640 z 69150 is thin water running down bare mountain slope, not a carved river. Do you want a carved river channel (about 10 to 14 m wide, one clean chute, bed continuing from the pond) down it in the next bake?
Answer: Yes, carve the river channel down the fall in the next bake
Answered: 2026-10-22 01:04 UTC

## scale-target | What does "1000 players online" mean for the server plan?
Answer: 1000 spread across the whole world (normal MMO target)
Answered: 2026-10-22 01:24 UTC

## sound-music | Should the game have background music?
Answer: No music, only world sounds (recommended: keeps the world feeling real)
Answered: 2026-10-22 03:05 UTC

## sound-wolf-howl | When should wolves howl?
Answer: Only at night, far away, more in winter (recommended)
Answered: 2026-10-22 03:05 UTC

## sound-footstep-others | How far away should you hear other players' footsteps?
Answer: 15 m, same as NPC voices (recommended)
Answered: 2026-10-22 03:06 UTC

## sound-npc-voice-ambient | Should NPCs mutter or hum when you are nearby and they are idle?
Answer: Yes, rarely, short lines (recommended)
Answered: 2026-10-22 03:06 UTC

## river-flood | Should heavy rain make rivers swell and flood low ground?
Answer: Yes, real floods in storms and spring melt (can wash out low buildings and crops)
Answered: 2026-10-22 03:06 UTC

## dig-rock | Can a spade dig through solid rock? (my pick: soil only, rock needs a pick)
Answer: Spade digs soil, gravel and sand only; rock needs a pick and is slower
Answered: 2026-10-22 03:07 UTC

## hole-refill | Do small surface holes and pits (spade digs in open ground, not mines) fill back in by themselves? (the docs only say mines revert through erosion and water; my pick: yes, slowly)
Answer: No, a hole stays until someone fills it
Answered: 2026-10-22 03:08 UTC

## drop-cap-full | When the ground around you already holds 64 dropped items (a 256 m square), what should happen when you drop one more?
Answer: Refuse the drop and say why (current behaviour)
Answered: 2026-10-22 03:12 UTC

## build-first-set | Which player-built structures should come first after the campfire kit, lean-to and chest?
Answer: A full wall, floor and roof kit so players design their own houses
Answered: 2026-10-22 03:13 UTC

## hole-refill | Do dug holes slowly fill back in by themselves? (my pick: no, they stay until filled)
Answer: No, a hole stays until someone fills it
Answered: 2026-10-22 03:16 UTC


## dig-depth | How deep may players dig below the surface?
Answer: Already decided in DESIGN_IDEAS.md (Sections 4.5, 11): depth is measured from sea level; deep mines are limited by heat (lethal about -3,000 m), the world bottom is -4,000 m; deep mines need ventilation. No separate dig limit. (Removed from the page by Steve_002, answered in the docs)
Answered: 2026-10-22 03:20 UTC

## tunnel-collapse | Do unsupported tunnels and caves ever collapse?
Answer: Already decided in DESIGN_IDEAS.md (mines section): mines and caves can become unstable; bigger man-made openings need timber supports (reach about 10 m); unmaintained supports fail and the mine can cave in. (Removed from the page by Steve_002, answered in the docs)
Answered: 2026-10-22 03:20 UTC

## host-max-players | Friend-hosted game player cap
Answer: Already decided in DECISIONS.md 2026-10-22 01:40 (condition 2): baseline a friend session of 10 to 20 on an 8 GB machine; max_clients becomes a config value. Technical, not Dave's call. (Withdrawn by Steve_002)
Answered: 2026-10-22 03:20 UTC
## bracing-grace | How long is the grace window after digging a soil tunnel before the earth starts to shake? (my pick: 30 real minutes, shorter for wider spans)
Answer: About 30 real minutes (shorter for wider spans, longer for rock)
Answered: 2026-10-22 03:56 UTC

## collapse-lethal | Can a collapse kill a player who ignores the warnings? (my pick: heavy damage, buried, can be dug out)
Answer: Always lethal inside the collapse
Answered: 2026-10-22 03:57 UTC

## load-exertion-own-link | When the server is overloaded players tire faster. Should a player whose OWN connection is weak (but the server is fine) also tire faster? (my pick: no, only server load counts)
Answer: No, only server overload makes actions harder (a player on bad wifi is not punished)
Answered: 2026-10-22 03:58 UTC

## warning-cleanup-frozen | May Willy add warning-silencing annotations to the frozen terrain-generator files (no change to the baked result, checked by identical test-bake hashes)? (my pick: yes, gated)
Answer: No, leave the frozen files alone until the next real bake
Answered: 2026-10-22 03:59 UTC


## collapse-offline | A tunnel's collapse time runs out while the player is logged out inside it. What happens to them?
Answer (Dave, in chat): the game must tell a deliberate logout from a disconnect. A disconnect: the player respawns at the nearest place they rested or built a shelter. A deliberate logout inside a tunnel that then collapses: they die.
Answered: 2026-10-22 05:38 UTC
## rv-build-numbers | Build numbers keep colliding (5 re-pushes in one evening). Fix it? Research: short-lived branches merged fast by one owner work best. Best practices BP-C101, BP-C107.
Answer: Yes, all three (recommended)
Answered: 2026-10-22 15:01 UTC

## rv-big-files | Three code files are huge (server_items 5,000 lines, inventory_view 3,800, terrain_client 5,200), so every edit costs a lot of reading. Split them? Research: the context window is the scarce resource. BP-C03.
Answer: Yes, one at a time, after restart (recommended)
Answered: 2026-10-22 15:02 UTC

## rv-local-first | Run every build, test and warning check on your PC by default through one command (tools/local_check.sh), cloud threads only edit and review? Research: a check the agent can run is the best quality lever. BP-C83, BP-C80.
Answer: Yes (recommended)
Answered: 2026-10-22 15:02 UTC

## rv-warning-baseline | Commit the current warning list (233) as a baseline file so reports show only NEW warnings? BP-C01.
Answer: Yes (recommended)
Answered: 2026-10-22 15:03 UTC

## rv-bp-digest | Everyone reads the 80-entry best practices every day (costly; research says long instruction files get ignored). Replace with a 15-line digest per role plus the changelog lines? BP-T25.
Answer: Yes, role digests (recommended)
Answered: 2026-10-22 15:03 UTC

## rv-shared-files | Threads need one-line changes in other threads' files (piece looks, sounds, client wiring). Allow one-line data hooks in another thread's file if announced in BUILD_LOG? BP-C10, BP-T22.
Answer: Yes (recommended)
Answered: 2026-10-22 15:04 UTC

## rv-waiting-line | Your rule: every post ends "Still waiting on:". Threads often have nothing to wait for. Keep it always (writing "nothing") or only when something is pending? BP-T10.
Answer: Only when something is pending (recommended)
Answered: 2026-10-22 15:04 UTC

## rv-lfs | Tile files in git (BP-C108): all server runs, flight checks and edge-matching run on your PC (your rule), so cloud threads never need tiles. Tiles stay in git as backup and history. Is any extra step needed?
Answer: Keep tiles in git as backup, cloud threads simply never use them (recommended)
Answered: 2026-10-22 15:09 UTC

## cc-first-job | When the team restarts, what should they do first? (Triple-check item; every thread agreed the process is ready.)
Answer: Crashes, saves and version check first, then water, then items, then art (recommended)
Answered: 2026-10-22 15:14 UTC

## cc-radar-name | One thread is called Radar in the docs and Sal_Crafts in one review. Which name do we use?
Answer: Sal_Crafts
Answered: 2026-10-22 15:15 UTC

## cc-long-runs | Long test runs and bakes on your PC use the same computer and graphics card as your game. When may MikeW run them?
Answer: Any time except while the game is running; MikeW checks first (recommended)
Answered: 2026-10-22 15:15 UTC

## cc-keep-awake | Local-first only works if your PC is awake with Claude Desktop open while the team works. Can we ask Windows to stay awake then?
Answer: Yes, keep awake while the team is working (recommended)
Answered: 2026-10-22 15:15 UTC

## cc-branches | Per-thread branches (you approved): when do they start?
Answer: From the first job after restart (recommended)
Answered: 2026-10-22 15:16 UTC

## bk-plan | Nightly backup plan (your top priority). Approve it so MikeW can write the script? Plan and every failure case it handles: tech/BACKUP_PLAN.md (copy in docs/mirror/tech/). Restore steps: tech/RESTORE_PROCEDURE.md.
Answer: Approve as written (recommended)
Answered: 2026-10-22 15:35 UTC

## bk-weekly | Backups older than 30 days are thinned to one per week. Which one do we keep forever from each week?
Answer: The LAST backup of the week, normally Sunday night: it holds the whole week's work (recommended)
Answered: 2026-10-22 15:44 UTC

## bk-trigger | How should the nightly backup start?
Answer: When you say "goodnight", and MikeW checks that Godot is closed first (recommended: it only runs when you are done)
Answered: 2026-10-22 15:44 UTC

## bake-plan | Approve the bake plan (BP-T31)? Every change is labelled RUNTIME (just play), RESTART (close game fully) or BAKE (waits for a bake window). Bakes are batched, at most once a week, 1-tile test first, then one full 9-tile bake.
Answer: Approve as written (recommended)
Answered: 2026-10-22 16:52 UTC

## cl-tests | The 11 old "have you answered this" checks (builds 623 to 645) are parked. Many builds have changed since. What now?
Answer: Regroup them into one test card after the restart work, dropping any that no longer apply (recommended)
Answered: 2026-10-22 17:17 UTC

## cmd-ok | Approve the completeness phrases (status, audit, goodnight, idea), the decision trace and the moderator's 30-minute checklist? (BP-T29)
Answer: Approved (Dave in chat: the commands are already done)
Answered: 2026-10-22 17:18 UTC

## nf-ok | Approve the "never forget" rules for every thread (BP-T30)? Each thread keeps one open-items list, writes down promises at once, checks a six-box "definition of done" before saying done, lists unfinished things in its handoff, and may drop an item only with a one-line reason.
Answer: Approve as proposed (recommended)
Answered: 2026-10-22 17:19 UTC

## repo-vis | Important: the main DynastyALWL repo is PUBLIC on GitHub today. Anyone with the address can read the code, design docs, questions and answers. Do you want that?
Answer: Make it private (recommended: it is an unreleased game)
Answered: 2026-10-22 17:20 UTC

## review-rules | Approve the rules for the terrain review (BP-T32)? Sonny writes a docs-only review first: what is wrong today, 2 or 3 options with sources, tests a bake must pass (rivers flow downhill, lakes have outlets, 2 m of water does not flood everything, 9-tile bake 30 minutes or less). Nothing is built or baked until you pick an option.
Answer: Approve as written (recommended)
Answered: 2026-10-22 17:21 UTC

## terrain-opt | How should we fix the ground so water works like real nature? (Sonny's review, tech/TERRAIN_REVIEW.md)
Answer: B: Find rivers and lakes from the terrain itself. Meets all requirements, including natural channel shape. 1 to 2 weeks. Threaded bake about 8 to 10 minutes for 9 tiles. Makes the held spill-chute patch unnecessary (recommended)
Answered: 2026-10-22 17:22 UTC

## model-plan | Approve Kathleen's two-stage plan? Stage one: a simple first model AND a placeholder sound for every item, creature and plant. Stage two: upgrades. (art/MODEL_PLAN.md)
Answer: Approve, two stages: basic models and placeholder sounds first, upgrades later (recommended)
Answered: 2026-10-22 18:32 UTC

## model-look | Basic models and placeholder sounds may differ in colour, size and sound from the final art (stage one). Is that fine for now?
Answer: Yes, fine for now (recommended)
Answered: 2026-10-22 18:32 UTC

## model-creatures | Do animals count as "basic done" when they read as the right animal from 20 m (shape and colour)?
Answer: Yes (recommended)
Answered: 2026-10-22 18:33 UTC

## chk-looks1 | Check the first 12 basic item looks: does each one read as the right thing? (spear, bark, leaves, bandage, firewood, cordage, seed bundle, roots, poultice, plant fibre, roast forage, bone)
Answer: No: The spear is not pointy. It should be, and I can’t tell what all the other things are. I think I recognized the cordage. and the bone looks fine.
Answered: 2026-10-22 19:12 UTC

## chk-looks2 | Check batch 2 of basic item looks: tools, kits and containers. Do they read as the right things? (the bone is now dimmer)
Answer: No: Anything that’s in a container or that is a container like a potion or a bottle or something with its own name needs to have its own colour so we learned to recognize the colours and use very separate colours nice bowl, green, blue, red, yellow, pink purple, etc.
Answered: 2026-10-22 19:13 UTC

## chk-animals | Check the animals from 20 m: moose (grazing, warning, charging), horse, fox, ducks. Does each read as the right animal?
Answer: Yes
Answered: 2026-10-22 19:13 UTC

## chk-looks1v2 | Check the revised first 12 item looks (labelled picture): is the spear pointed now, and can you tell the items apart?
Answer: No: Fibre bundle should look like fibers, and the roast forage is a terrible name. We should rename it. I would call it campfire Stew. And it should look like a bowl of chunky vegetable soup.
Answered: 2026-10-22 19:36 UTC

## chk-looks1v2 | Check the revised first 12 item looks (labelled picture): is the spear pointed now, and can you tell the items apart?
Answer: No: Fibre bundle should look like fibers, and the roast forage is a terrible name. We should rename it. I would call it campfire Stew. And it should look like a bowl of chunky vegetable soup.
Answered: 2026-10-22 19:36 UTC

## chk-foods | Check the 16 prepared foods (labelled picture): can you tell them apart by colour?
Answer: No: Anything that’s a soup or a stew should be in a bowl. So make a basic wooden bowl and then use that as the foundation and then put whatever the food is inside of it the thing it looks like a roast we should call roast beast . An energy bar should look like a trail mix bar. You have to put an effort into seeing what the real things look like first and then trying to make something that resembles them slightly. Try again.
Answered: 2026-10-22 19:38 UTC

## chk-looks2v2 | Check the revised tools, containers and potions (labelled picture): does each have its own colour you can learn?
Answer: No: The backpack, the bucket, the clay pot and the bowl don’t look anything like what they really look like. And the ax looks like it could be a hammer or a shovel. The Action should have a rounded edge and be sharpened.
Answered: 2026-10-22 19:40 UTC

## looks-raw | Should raw materials (logs, lumber, ores, stones) also get strongly distinct colours, or stay natural?
Answer: Stay natural (recommended)
Answered: 2026-10-22 19:41 UTC

## chk-foods-v4 | Check the redrawn foods (labelled picture): do the stews and soups look like food in a wooden bowl, does the roast look like a roast on the bone, and does the energy bar look like a trail-mix bar?
Answer: Yes
Answered: 2026-10-22 19:55 UTC

## chk-tools-v4 | Check the redrawn backpack, bucket, clay pot, wooden bowl and stone axe (labelled picture): does each look like the real thing, and does the axe look like an axe and not a hammer?
Answer: Yes
Answered: 2026-10-22 19:56 UTC

## roast-names | The other roasts are still called roast meat, roast fish and roast roots. Rename any of them like Roast Beast?
Answer: Rename them to match (Roast Beast style, e.g. Roast Fish, Roast Roots as proper names)
Answered: 2026-10-22 19:56 UTC

## building-plan | Kathleen's building plan (art/BUILDING_PLAN.md): approve all five points?
Answer: Approve all five (recommended)
Answered: 2026-10-22 19:57 UTC

## chk-spades | Check the four spades from above (labelled picture): wooden, stone, iron, steel. Do they look like real spades (D-grip, long handle, pointed blade), and can you tell the four apart?
Answer: No: Bucket should be made out of wood and look like a wooden bucket. The ax looks like it’s round. It should be a wedge with a sharp edge on the end of a stick, and if you turn it sideways, it would look like a gardening hoe
Answered: 2026-10-22 20:10 UTC

## chk-materials-walls | Check the wall materials (labelled picture): wood, log, daub, stone, brick. Can you tell them apart, and does each look like the real material?
Answer: No: Let’s figure out the tears for building materials because I think we need to have the basic tier which is where people use Thatch and twine and wooden sticks so you could have a basic wall which would be made from Thatch twine and wooden sticks in woven to create a wall and you could have a plank wall where you use rough wooden planks like the kind that are smooth on one side, but they’re rounded and have bark on the other and then you could have fine wooden walls and they would be made from quality lumber and nails and then you could have log walls and they’re made from large round logs to look like a log cabin and they would be thicker and they should be placed on large foundations and then we could have cobblestone walls which are made with cobblestones and mortar and they would be thick also so they would have to be on a large foundation and then we could have mason walls which are very large carved bricks that require proper mason foundations. They would look like the bricks in a castle. Do have some designs and let me see.
Answered: 2026-10-22 20:14 UTC

## chk-materials-walls | Check the wall materials (labelled picture): wood, log, daub, stone, brick. Can you tell them apart, and does each look like the real material?
Answer: No: Let’s figure out the tears for building materials because I think we need to have the basic tier which is where people use Thatch and twine and wooden sticks so you could have a basic wall which would be made from Thatch twine and wooden sticks in woven to create a wall and you could have a plank wall where you use rough wooden planks like the kind that are smooth on one side, but they’re rounded and have bark on the other and then you could have fine wooden walls and they would be made from quality lumber and nails and then you could have log walls and they’re made from large round logs to look like a log cabin and they would be thicker and they should be placed on large foundations and then we could have cobblestone walls which are made with cobblestones and mortar and they would be thick also so they would have to be on a large foundation and then we could have mason walls which are very large carved bricks that require proper mason foundations. They would look like the bricks in a castle. Do have some designs and let me see.
Answered: 2026-10-22 20:14 UTC

## chk-materials-floors | Check the floors and roofs (labelled picture): floors, wood roofs and thatch roofs. Does each look like the real material?
Answer: No: I just submitted the walls and we had an entire discussion and now you need to rework all of these to match the walls
Answered: 2026-10-22 20:15 UTC

## chk-materials-floors | Check the floors and roofs (labelled picture): floors, wood roofs and thatch roofs. Does each look like the real material?
Answer: No: I just submitted the walls and we had an entire discussion and now you need to rework all of these to match the walls
Answered: 2026-10-22 20:15 UTC

## hoe-path | Garden hoe path look: how should the trodden path look at first?
Answer: Clear the grass and paint a flat tan blend now, real material later (recommended)
Answered: 2026-10-22 20:15 UTC

## hoe-grade | Hoe grading for roads: must cut and fill balance?
Answer: Free grading for admin only at first
Answered: 2026-10-22 20:16 UTC


## hoe-grade | Hoe grading for roads: must cut and fill balance?
Answer: No: the hoe moves dirt from space to space on the ground; it needs no soil items and no materials and only wears down its own durability (Dave's words, chat 20:17, resolved by Guru)
Answered: 2026-10-22 20:17 UTC
## hoe-mode | Shovel: should right click switch between Dig and Raise? (Design: items/HOE_AND_SHOVEL_DESIGN.md)
Answer: Right click toggles Dig/Raise (recommended)
Answered: 2026-10-22 20:17 UTC

## hoe-load | How much can a shovel carry for Raise mode?
Answer: One shovelful at a time
Answered: 2026-10-22 20:18 UTC

## hoe-order | In what order should Sal build the shovel and hoe work?
Answer: Shovel Raise mode and new model first, then hoe path and smooth, then grade line (recommended)
Answered: 2026-10-22 20:19 UTC

## chk-tiers | Check the building tier designs (drawn, not engine renders): walls, floors and roofs for the six tiers. Does each tier look like what you described, and is it clearly different from the next?
Answer: Yes
Answered: 2026-10-22 20:56 UTC

## chk-tools-tv6 | Check the reworked tools and containers (labelled picture): backpack, wooden bucket, clay pot, bowl, wedge axe, chopping block kit, pickaxe, stone block. Does each look like the real thing now, and does the axe look like a wedge with a sharp edge?
Answer: No: I don’t think there should be a chopping block kit. It should just be a chopping block and it’s heavy and it looks exactly like the model for the actual chopping block.
Answered: 2026-10-22 20:57 UTC

## chk-spades-tv6 | Check the spades (labelled picture): small, medium and large in wood, stone, iron and steel. Can you tell the sizes and materials apart? (The sheet is crowded because the handles are long.)
Answer: Yes
Answered: 2026-10-22 20:57 UTC

## chk-masonry-tv6 | Check the masonry items (labelled picture): stone block, brick, mortar. Do they look like the real things?
Answer: Yes
Answered: 2026-10-22 20:58 UTC

## tier-fine | Existing lumber pieces become the FINE WOOD tier (nails added to their recipe)?
Answer: No: You can turn logs into lumber at the sawmill and then at the firsttier woodworking table you can turn lumber into fine boards
Answered: 2026-10-22 22:13 UTC

## tier-foundations | Foundation sizes: 4 x 4 standard, 6 x 6 large, 8 x 8 mason?
Answer: No: They’re also has to be a one by one and a 2 x 2 in the smaller versions
Answered: 2026-10-22 22:13 UTC

## tier-basic-ground | May tier-1 basic buildings (woven thatch hut) sit on bare ground with no foundation?
Answer: No: They have to have the same related foundation
Answered: 2026-10-22 22:14 UTC

## tier-nails | Nails: 1 iron ingot makes 20 nails at a forge?
Answer: No: One iron and it weighs 1 kg and makes 100 nails
Answered: 2026-10-22 22:16 UTC

## tier-mason-heavy | Mason walls are so heavy (about 200 kg) that you build them where you stand?
Answer: No: We want a design system where you can put down blueprints for the items you want and you can keep placing the blueprint so you could build the whole building out of blueprints and then you can come along and put the items into those blueprints however, if the item they are connected to and depend on like the foundation is not complete completed, you can’t put the last item into whatever it is your building so you have to finish the foundations first, and then the walls, and then the ceilings
Answered: 2026-10-22 22:17 UTC

## tl-plank | Should the plank wall have a rough bark side outside and a smooth side inside?
Answer: No: No, they would have a flat rough side on the inside and a rounded smooth side on the outside
Answered: 2026-10-22 22:18 UTC

## tl-logs | Should log walls be real round logs with notched corner ends sticking out (8 small meshes per wall), not just a picture?
Answer: Yes
Answered: 2026-10-22 22:18 UTC

## tl-doors | Should doors and windows follow the wall tier's look (nailed boards with iron straps and shutters from tier 3 up)?
Answer: No: Actually, yes, however for stick tier, they will be sticking twine and Thatch doors for the next year they will be made out of planks for the next year. They will be made out of wood, but they can also be made out of wood with iron banding, and that would be called a reinforced door, and there will also be probably two more tears of nicer doors so iron doors with and forced wrought iron and then we could have fancier doors that might use steel and iron combined, but they will all fit into a door frame and we will have to have a double French door style also and we will have to be able to place walls and use the mouse wheel to scroll through the different type of walls so like a wall and then a wall with a window and a wall with the door frame or a wall with a double door frame or a wall with a double window frame
Answered: 2026-10-22 22:21 UTC

## tier-plan | THE BUILDING COSTS IN SHORT (Sal's plan). Have you read this?
Answer: No: You’re very close, but your numbers are off so I’ve already previously answered about one iron ingot makes 100 nails every wall and every building has to have a foundation and lumber can get made into fine boards at a woodworking table. Everything gets built where you stand because you put blueprints down to represent the items and you can join blueprints together like you can put down a blueprint of a foundation and you can put a blueprint of a wall on it and you can attach blueprints of all the walls and blueprints of the ceilings and then this will allow you or NPC builders to come along and put items into those walls to complete them so when you look at the wall, it will tell you what type of wall it is and what it needs to finish. Also, what it takes to make. The wall has to make sense like the build a Thatch or basic tier wall you would have to use Thatch and sticks and cordage or twine. From now on, let’s call it twin so it’s gonna take 20 twine, 50 Thatch and 15 sticks
Answered: 2026-10-22 22:26 UTC

## chk-looks-short | THE BUILDING LOOKS IN SHORT (six tiers, same 2 m grid, 2.4 m walls). Have you read this?
Answer: Yes
Answered: 2026-10-22 22:27 UTC

## spade-load | You said "one shovelful at a time" for raising ground. How should the spade work?
Answer: No load: each raise click takes one shovelful straight from the pack, nothing is loaded onto the spade
Answered: 2026-10-22 22:27 UTC

## build-recap | WHAT I TOOK FROM YOUR 22:13-22:26 ANSWERS (nothing you already answered is asked again). Is this right?
Answer: No: You are very, very close most of that is correct. However, basic doors would have to use twine Thatch and sticks. And correct we are not gonna run around with 200 kg of stuff in our inventory, but we might use a wheelbarrow or a donkey or a waggon and you might have to bring in a waggon load of lumber from the sawmill and then carry five boards at a time or three boards or two boards at a time and put them into your wall. We have to find a balance because it can’t be so tedious that it’s no fun to do but also it should take a little bit of time because the goal is to use NPC’s to do most of the work people might build their first house, but they’ll probably just put down the blueprints and let the builders do the work the second time.
Answered: 2026-10-22 22:51 UTC

## found-sizes | Foundation sizes: 1 x 1, 2 x 2 (small), 4 x 4, 6 x 6, 8 x 8 (large), measured in metres. Right?
Answer: No: Remember that we have some walls that are thin walls and some walls that are thick walls and the thick walls all go on large foundations and the thin walls go on small foundations so we should have a 1x1 small and a 2 x 2 small, and a one by one large and a 2 x 2 large. The other thing is foundations are collectible. You can stack them on top of each other so you can level out a floor or you can connect them side-by-side into different configurations for your building. You can use your scroll wheel to move them up and down on the ground when you place the first one, but you can only do that while it’s on the ground and they will have a very wide snapping range so they will connect together very well. One of the biggest problems I see in most games is that snapping pieces together can be difficult and it’s hard to find the snap point so we need to be aware of that and plan for it.
Answered: 2026-10-22 22:53 UTC

## found-sizes | Foundation sizes: 1 x 1, 2 x 2 (small), 4 x 4, 6 x 6, 8 x 8 (large), measured in metres. Right?
Answer: No: Remember that we have some walls that are thin walls and some walls that are thick walls and the thick walls all go on large foundations and the thin walls go on small foundations so we should have a 1x1 small and a 2 x 2 small, and a one by one large and a 2 x 2 large. The other thing is foundations are collectible. You can stack them on top of each other so you can level out a floor or you can connect them side-by-side into different configurations for your building. You can use your scroll wheel to move them up and down on the ground when you place the first one, but you can only do that while it’s on the ground and they will have a very wide snapping range so they will connect together very well. One of the biggest problems I see in most games is that snapping pieces together can be difficult and it’s hard to find the snap point so we need to be aware of that and plan for it.
Answered: 2026-10-22 22:53 UTC

## chk-plank-v2 | Check the redrawn plank wall (picture): smooth rounded planks outside, the small inset shows the flat rough face inside. Does the plank wall look right now?
Answer: No: Very close almost perfect everyone was perfect except for the log wall because you’re notched ends need to be opposite on each side so they can fit into each other so rework the log wall and send it back for approval
Answered: 2026-10-22 22:55 UTC

## chk-plank-v2 | Check the redrawn plank wall (picture): smooth rounded planks outside, the small inset shows the flat rough face inside. Does the plank wall look right now?
Answer: No: Very close almost perfect everyone was perfect except for the log wall because you’re notched ends need to be opposite on each side so they can fit into each other so rework the log wall and send it back for approval
Answered: 2026-10-22 22:55 UTC

## chk-doors | Check the door and window designs (picture): five door tiers (twine and thatch hurdle, planks, reinforced with iron bands, wrought iron, steel and iron), a double door, a window and a double window. Do these look right?
Answer: No: A wall with a window hole in it is just a hole for a window. And we should have a square window around window and eventually in the future we’re going to make double walls so we can make tall windows and eventually stained glass windows, but when it comes to making walls, they just have holes in them for windows, and eventually we will make shutters that you can put on them, so you’ll just have a wooden type shutter that you can open her clothes to cover the window with hinges, so it would take wood and hinges to make and nails
Answered: 2026-10-22 23:01 UTC

## chk-doors | Check the door and window designs (picture): five door tiers (twine and thatch hurdle, planks, reinforced with iron bands, wrought iron, steel and iron), a double door, a window and a double window. Do these look right?
Answer: No: A wall with a window hole in it is just a hole for a window. And we should have a square window around window and eventually in the future we’re going to make double walls so we can make tall windows and eventually stained glass windows, but when it comes to making walls, they just have holes in them for windows, and eventually we will make shutters that you can put on them, so you’ll just have a wooden type shutter that you can open her clothes to cover the window with hinges, so it would take wood and hinges to make and nails
Answered: 2026-10-22 23:01 UTC

## doors-width | Is it OK that a double door fills the whole 2 m wall slot and a double window is 2 m wide?
Answer: No: A double door should just be slightly smaller than the wall so it leaves roughly 10 cm all the way around the wall around the outside of the door. If you can look up the doors from Ark survival
Answered: 2026-10-22 23:02 UTC

## blueprint-refund | When you take down a FINISHED piece, how much of its items come back? Sal recommends half (50%).
Answer: No: There is a write up in the design document talking about if a piece is in good repair because everything will gradually degrade so everything should have a durability and that affects how much you get back from it. Check in the design document.
Answered: 2026-10-22 23:12 UTC

## chk-block-hand | Check the chopping block in your hand (picture, bottom right of the screen): is it a good size now, and does it look like the placed chopping block? It is made from 2 logs and weighs 30 kg.
Answer: No: It should weigh about 18 kg
Answered: 2026-10-22 23:13 UTC

## chk-block-hand | Check the chopping block in your hand (picture, bottom right of the screen): is it a good size now, and does it look like the placed chopping block? It is made from 2 logs and weighs 30 kg.
Answer: No: It should weigh about 18 kg
Answered: 2026-10-22 23:13 UTC

## chk-log-wall | Check the reworked log wall (two pictures: the 4th wall on the first, the corner on the second). Round logs with saddle-notched corners that interlock; the log running through the corner alternates each course; the two ends of a wall are opposite (left end runs through on even courses, right end on odd). Does it look right now?
Answer: No: That is close, but you have the notches wrong. Look up any log cabin picture and you will see what I mean.
Answered: 2026-10-22 23:14 UTC

## chk-log-wall | Check the reworked log wall (two pictures: the 4th wall on the first, the corner on the second). Round logs with saddle-notched corners that interlock; the log running through the corner alternates each course; the two ends of a wall are opposite (left end runs through on even courses, right end on odd). Does it look right now?
Answer: No: That is close, but you have the notches wrong. Look up any log cabin picture and you will see what I mean.
Answered: 2026-10-22 23:14 UTC

## found-metres | Foundation sizes in metres. Small foundation (for thin walls): 2 x 2 m, or 4 x 4 m as a double. Large foundation (for thick walls: log, cobblestone, mason): 3 x 3 m, or 6 x 6 m as a double. Pieces snap from about 6 m away. Are these sizes right?
Answer: Yes
Answered: 2026-10-22 23:14 UTC

## collapse-on | May we turn the tunnel collapse ON in your test world so you can test it? (This is the second approval; you will get a test card after.)
Answer: Yes
Answered: 2026-10-22 23:15 UTC

## collapse-plan-1 | A dug space wider than the ground can hold starts a timer. The grace window is 225 s to 60 min, depending on width and depth. Digging more does not reset it. Is this right?
Answer: No: If you dig a hole any wider than about 2 m roughly wide then it will start a timer and you have about 10 minutes before it starts to rumble randomly then you’ll have another 20 minutes to get your space dug out and braces put in place. And braces can just be a blueprint of two logs standing on each side with a log going across. And what we can do is make the blueprint very tall and it acts like a foundation, but it connects on the top to the dirt or the stone above so you will look up pick where you wanna put your brace. Turn it accordingly using your mouse wheel, and when you set it, the logs will be so long that they go down into the ground and they disappear into the ground. Does that make sense if you have any questions just repost it.
Answered: 2026-10-22 23:19 UTC

## collapse-plan-1 | A dug space wider than the ground can hold starts a timer. The grace window is 225 s to 60 min, depending on width and depth. Digging more does not reset it. Is this right?
Answer: No: If you dig a hole any wider than about 2 m roughly wide then it will start a timer and you have about 10 minutes before it starts to rumble randomly then you’ll have another 20 minutes to get your space dug out and braces put in place. And braces can just be a blueprint of two logs standing on each side with a log going across. And what we can do is make the blueprint very tall and it acts like a foundation, but it connects on the top to the dirt or the stone above so you will look up pick where you wanna put your brace. Turn it accordingly using your mouse wheel, and when you set it, the logs will be so long that they go down into the ground and they disappear into the ground. Does that make sense if you have any questions just repost it.
Answered: 2026-10-22 23:19 UTC

## collapse-plan-2 | Supports (props, timber sets) in reach pause the timer. A new support restarts the full window. A removed or worn-out support starts a fresh half window. Is this right?
Answer: No: When I support is not being maintained anymore from the town funds, it will slowly degrade over a medium time. What happens is the Support has an influence range and based on full health its influence range. Should be 10 m in any direction but if it’s at half health, it would be 5 ma medium time. What happens is the Support has an influence range and based on full health it’s influence range. Should be 10 m in any direction but if it’s at half health, it would be 5 m in any direction. Like torches in Minecraft if you place your support you want to make sure you place your next one close enough so they either overlap so the influence circles cover the entire area and that would be a sphere of influence. Does that make sense? If you have any questions, please ask. Also I need it noted. There will be at least three sizes of Support beams so we can have one that has one log up one log over and one log down and then we can have another larger one that does the same thing but is wider so the first one could be 1.5 m wide. The second one could be 3 m wide and the third one could be 5 m wide and turn each one would be taller and use larger beams and they would each have larger influence so the first one could support a sphere with a radius of 5 m the second one a sphere of 7 1/2 m and the third Support beam could support 10 m. Again, if there’s any questions just repost them.
Answered: 2026-10-22 23:24 UTC

## collapse-plan-3 | Warnings: quiet until 60% of the window. Then creaks, then shaking with dust and "The earth groans.", then strong shaking with a warning line every 5 seconds. Then it falls. Is this right?
Answer: Yes
Answered: 2026-10-22 23:25 UTC

## collapse-plan-5 | When it falls, rubble fills about 70% of the space and the top stays open, so you can dig it out. The land above does not sink (at most 1 m under a thin roof). Anyone inside dies and leaves remains and a purse. Floor items are buried; braces and chests inside are destroyed. Is this right?
Answer: No: Anyone trapped inside dies and leaves everything they have on them according to our death rules already established.
Answered: 2026-10-22 23:26 UTC

## roofs-angles | Should there be two roof angles, 45 and 65 degrees?
Answer: Yes
Answered: 2026-10-22 23:26 UTC

## collapse-plan-8 | Should the collapse stay OFF until your second approval and a test card? (The warning shaking and messages are built but never fire while it is off.)
Answer: No: Since we’re enabling it, we might as well use it and test it
Answered: 2026-10-22 23:27 UTC

## roofs-pieces | Should each angle have a straight slope piece, an outside (hip) corner piece and an inside (valley) corner piece, 6 roof pieces per tier look?
Answer: Yes
Answered: 2026-10-22 23:27 UTC

## roofs-65-tall | Is it OK that a 65 degree roof is very tall (4.3 m rise per 2 m of run)?
Answer: No: It’s the opposite direction it’s a shorter peak. Also, please pass along that I want the cave in duration for now to be a number we can set and adjust in settings and it’s lowest setting should be two minutes and it’s highest setting should be 20 minutes
Answered: 2026-10-22 23:28 UTC

## roofs-65-tall | Is it OK that a 65 degree roof is very tall (4.3 m rise per 2 m of run)?
Answer: No: It’s the opposite direction it’s a shorter peak. Also, please pass along that I want the cave in duration for now to be a number we can set and adjust in settings and it’s lowest setting should be two minutes and it’s highest setting should be 20 minutes
Answered: 2026-10-22 23:28 UTC

## pillars-snap | Should a pillar snap to the centre or any of the 4 corners of a foundation or a ceiling (5 snap points)?
Answer: Yes
Answered: 2026-10-22 23:29 UTC

## pillars-looks | Should pillars come as round log post, squared timber, stone pillar and mason column?
Answer: Yes
Answered: 2026-10-22 23:29 UTC

## found-start | Does every building start on a foundation, with foundations joined side by side to make the floor shape, and you build up from them?
Answer: Yes
Answered: 2026-10-22 23:36 UTC

## found-start | Does every building start on a foundation, with foundations joined side by side to make the floor shape, and you build up from them?
Answer: Yes
Answered: 2026-10-22 23:36 UTC

## blueprint-6 | Foundation snap range about 6 m (very wide)?
Answer: Yes
Answered: 2026-10-22 23:42 UTC

## blueprint-7 | Rename cordage to Twine in names only, id unchanged so saves keep working?
Answer: No: It’s early on in the development go ahead and change them all to twine. I assume you mean the save files for the game so that we keep materials laying around on the ground and if this is the case just to delete all the files and we will make more.
Answered: 2026-10-22 23:43 UTC

## blueprint-1 | A builder's mallet tool replaces building kits?
Answer: Yes
Answered: 2026-10-22 23:44 UTC

## blueprint-2 | Does the mouse wheel cycle piece type, then tier, with the cost shown on the ghost?
Answer: No: It only rotates the type of piece so if it’s a wall, then it can also be placed as a wall with a door, a wall with a window, etc. when you pull the piece from your inventory and place it in your hot bar, the piece that you put in your hot bar, determines the tier of the wall so you would put a basic wall in your hot bar or a plank wall or a fine wooden wall, etc., but when you place a foundation, it only has one piece it can’t be variations of a foundation so when you turn the mouse wheel, it will allow you to raise the foundation up or down.
Answered: 2026-10-22 23:46 UTC

## blueprint-2 | Does the mouse wheel cycle piece type, then tier, with the cost shown on the ghost?
Answer: No: It only rotates the type of piece so if it’s a wall, then it can also be placed as a wall with a door, a wall with a window, etc. when you pull the piece from your inventory and place it in your hot bar, the piece that you put in your hot bar, determines the tier of the wall so you would put a basic wall in your hot bar or a plank wall or a fine wooden wall, etc., but when you place a foundation, it only has one piece it can’t be variations of a foundation so when you turn the mouse wheel, it will allow you to raise the foundation up or down.
Answered: 2026-10-22 23:46 UTC

## blueprint-3 | Place a see-through blueprint first, then fill it with items (E or drag a stack, any order, partial is fine)?
Answer: No: Yes is the correct answer here except you will only be able to press E on it if you have the items in your inventory.
Answered: 2026-10-22 23:47 UTC

## blueprint-4 | A piece cannot finish before what it rests on is finished (wall waits for foundation, roof for walls)?
Answer: Yes
Answered: 2026-10-22 23:47 UTC

## blueprint-5 | Taking down an unfinished blueprint returns every item put in?
Answer: Yes
Answered: 2026-10-22 23:48 UTC

## blueprint-8 | Keep the old flat roof as the fine-wood flat roof next to the six new slope pieces?
Answer: No: There should be what we call a ceiling which is just a wooden style floor turned 90° so you can place it up on top of a wall or attach it to anything that has an attachment point but there should also be a flat roof piece that is specifically only made of wood and tar which comes from Bitumen. Which is one of the things in our world and once you combine these things, you make a Flat tarred roof and it can protect everything below it from the elements just like every other roof piece. You can make a roof piece out of Thatch and that has a natural look. You can make a roof piece out of boards and nails, and that would look like a lap board roof and you can make it out of stone shingles. And that would be it for roof roofing.
Answered: 2026-10-22 23:53 UTC

## blueprint-10 | Foundation needs ground level enough to hide the whole bottom (about 0.3 m), otherwise you level it first?
Answer: No: I want to clarify what I mean by hide the whole bottom if it is a slope and you can only set a foundation down until it starts to go underground has to stop there if the bottom does not have ground underneath all of it and it cannot be placed so if the slope is shallow, then you should have no problem, but if it’s too steep, this will stop you. And a foundation should have a height, maximum height, the same as its width and length so it’s a cube and you can raise it until there’s about point one of a metre underground or you can lower it until there’s point one of a metre above ground
Answered: 2026-10-22 23:55 UTC

## blueprint-10 | Foundation needs ground level enough to hide the whole bottom (about 0.3 m), otherwise you level it first?
Answer: No: I want to clarify what I mean by hide the whole bottom if it is a slope and you can only set a foundation down until it starts to go underground has to stop there if the bottom does not have ground underneath all of it and it cannot be placed so if the slope is shallow, then you should have no problem, but if it’s too steep, this will stop you. And a foundation should have a height, maximum height, the same as its width and length so it’s a cube and you can raise it until there’s about point one of a metre underground or you can lower it until there’s point one of a metre above ground
Answered: 2026-10-22 23:55 UTC

## blueprint-9 | Pillars on every tier, 5 anchors per cell, solid but not carrying load yet?
Answer: No: Pillars on every tier yes they can anchor to the centre or each corner of a foundation or ceiling or the ground. They can act like foundations. They are stackable and they support just like a foundation and foundations and pillars. Can both allow you to connect items up to three spaces away from the pillar or foundation in all directions so when you go to place the blueprint, it will have to check to make sure there’s enough foundation connecting to it also structures can have a load limit like in Valheim. So when you place a foundation, it can carry three walls worth of weight and then out from those walls you can go three spaces out in any direction off the square edges. I’m sure you can see what I’m trying to do here it’s the same as Ark and Atlas. Look those up if you need a reference.
Answered: 2026-10-22 23:58 UTC

## doors-window-hole | Is a window just a plain hole in the wall, with no frame or glass piece for now (shutters come later as separate hinged wood pieces)?
Answer: Yes
Answered: 2026-10-22 23:58 UTC

## doors-double | Does the double door look right: it fills the 2 x 2.4 m wall slot with a 10 cm gap all round (leaves 1.8 m wide, 2.2 m high)?
Answer: No: Yes, it does but there shouldn’t be an edge across the bottom. It should look like a realistic door.
Answered: 2026-10-22 23:59 UTC

## doors-singles | Do the five single door looks (twine and thatch hurdle, planks, reinforced, wrought iron, steel and iron) look right?
Answer: No: The basic door should not have a door knob and the steel door shouldn’t have the black band across the middle and the door handle should be a steel handle on the steel door and none of these doors should have door knobs they should have handles without latching mechanisms
Answered: 2026-10-23 00:01 UTC

## log-corner | Does the log wall now look like a real log cabin corner: round logs with saddle notches, each log overlapping the one below, the crossing log's end tucked into the notch?
Answer: No: It’s almost right, but here’s what you do remove the protruding logs that look like they’re coming from the side walls and just have the logs that are in this wall and then we allow the other walls if they get connected to mix in between that space so that has to be an open space for logs to go through and then allow them to connect so that they interlock the way they properly should. Do your best get rid of the curved notch altogether. Redesign and send it back to me. It should almost look like your first one except the notches should be offset on each side.
Answered: 2026-10-23 00:08 UTC

## door-handles | Are the door handles right: steel bar pulls, no knobs, no handle on the basic twine door?
Answer: Yes
Answered: 2026-10-23 00:09 UTC

## door-steel-r3 | Is the steel and iron door right now: steel panels, steel handle, no black crossband?
Answer: Yes
Answered: 2026-10-23 00:09 UTC

## ceilings-six | Do the six ceiling looks (pole rafters and straw, rough planks, planed boards, log joists, heavy beams, coffered stone) look right?
Answer: No: The logs should just look like wide fine boards on top and rounded on the bottom like a log. And the fine board ceiling shouldn’t have the dark brown strips going across the fine boards should reach the whole distance and cobblestone should actually look like cobblestone not like boards and masonry looks perfect.
Answered: 2026-10-23 00:11 UTC

## ceilings-six | Do the six ceiling looks (pole rafters and straw, rough planks, planed boards, log joists, heavy beams, coffered stone) look right?
Answer: No: The logs should just look like wide fine boards on top and rounded on the bottom like a log. And the fine board ceiling shouldn’t have the dark brown strips going across the fine boards should reach the whole distance and cobblestone should actually look like cobblestone not like boards and masonry looks perfect.
Answered: 2026-10-23 00:11 UTC

## flat-roof | Does the flat tarred roof look right: boards under black tar, board seams, streaks, raised lip?
Answer: Yes
Answered: 2026-10-23 00:11 UTC

## braces-three | Do the three braces look right: small 1.5 m (two posts and cap beam), medium 3 m (adds corner braces), large 5 m (thick posts, double cap beam, corner braces, centre prop)?
Answer: Yes
Answered: 2026-10-23 00:11 UTC

## door-double-r3 | Is the double door right: 10 cm gap at the top and sides only, leaves reaching the floor?
Answer: Yes
Answered: 2026-10-23 00:12 UTC

## esc-menu-1 | Esc menu: should Resume be at the top and close the menu?
Answer: Yes
Answered: 2026-10-23 00:30 UTC

## esc-menu-2 | Esc menu: should Settings open a page with Display (quality, VSync, resolution, window mode, text size, reset), Sound (volumes) and Gameplay (NPC voice; tunnel collapse and cave-in time for admins)?
Answer: Yes
Answered: 2026-10-23 00:31 UTC

## esc-menu-3 | Esc menu: should Controls show the hotkey list?
Answer: Yes
Answered: 2026-10-23 00:31 UTC

## esc-menu-4 | Esc menu: should Character open the Tab screen from the menu?
Answer: No: (no reason given)
Answered: 2026-10-23 00:31 UTC

## esc-menu-5 | Esc menu: should Quit game sit near the bottom with a short "Leave the game?" confirm click?
Answer: Yes
Answered: 2026-10-23 00:32 UTC

## esc-menu-6 | Esc menu: should Admin be one collapsible group at the very bottom, closed by default, holding Clear saved ground, Dump ground, Show my player key, Bake starter tiles, Jitter test, GPU breakdown, Measure this machine, the test switches and all the Sound test buttons?
Answer: No: I’m gonna ask you to read this review it and then reword this question I don’t know what dump ground is, I also don’t know what measure this machine means and I don’t know what the test switches are and if we are going to have a sound test, it should be its own page with a scrolling list of sounds and you can just click on one and it will play
Answered: 2026-10-23 00:33 UTC

## esc-menu-6 | Esc menu: should Admin be one collapsible group at the very bottom, closed by default, holding Clear saved ground, Dump ground, Show my player key, Bake starter tiles, Jitter test, GPU breakdown, Measure this machine, the test switches and all the Sound test buttons?
Answer: No: I’m gonna ask you to read this review it and then reword this question I don’t know what dump ground is, I also don’t know what measure this machine means and I don’t know what the test switches are and if we are going to have a sound test, it should be its own page with a scrolling list of sounds and you can just click on one and it will play
Answered: 2026-10-23 00:33 UTC

## esc-menu-7 | Esc menu: should the panel be fully opaque (solid dark background, no see-through shade) so world text cannot show through the labels?
Answer: Yes
Answered: 2026-10-23 00:34 UTC

## esc-menu-8 | Esc menu: should Debug details (F3) move from Settings into Admin?
Answer: Yes
Answered: 2026-10-23 00:34 UTC

## esc-menu-9 | Esc menu: should VSync and the tunnel collapse switch be green On and red Off buttons?
Answer: No: Actually, yes, specifically I want them to slide to the right front on the left or off and when you slide them to the right, they turned green and when you slide them to the left, they turned red
Answered: 2026-10-23 00:35 UTC

## chk-collapse-test | TEST THE TUNNEL COLLAPSE (build 686). Did it work as designed?
Answer: No: By default set the timeout to five minutes and if I understand correctly, that should mean that it will cave in in five minutes, but it will break down the warnings over that five minutes by percentage of time. Also, I will not be testing this until after the back up this evening so rework this question and repost it and please include the instructions on how I should do this test.
Answered: 2026-10-23 00:37 UTC

## cost-1 | Wall (2 m x 2.4 m), Basic: 20 twine, 50 thatch, 15 sticks?
Answer: Yes
Answered: 2026-10-23 00:43 UTC

## cost-2 | Wall, Plank: 12 rough planks and 30 nails?
Answer: Yes
Answered: 2026-10-23 00:43 UTC

## cost-3 | Wall, Fine wood: 8 fine boards and 40 nails?
Answer: Yes
Answered: 2026-10-23 00:43 UTC

## cost-4 | Wall, Log: 8 logs and 10 twine?
Answer: Yes
Answered: 2026-10-23 00:44 UTC

## cost-5 | Wall, Cobblestone: 120 cobblestones and 8 mortar?
Answer: Yes
Answered: 2026-10-23 00:44 UTC

## cost-6 | Wall, Mason: 60 stone blocks and 12 mortar?
Answer: Yes
Answered: 2026-10-23 00:44 UTC

## cost-7 | Floor or ceiling (2 m x 2 m), Basic: 12 twine, 30 thatch, 8 sticks?
Answer: Yes
Answered: 2026-10-23 00:44 UTC

## cost-8 | Floor or ceiling, Plank: 8 rough planks and 20 nails?
Answer: Yes
Answered: 2026-10-23 00:44 UTC

## cost-9 | Floor or ceiling, Fine wood: 6 fine boards and 24 nails?
Answer: Yes
Answered: 2026-10-23 00:45 UTC

## cost-10 | Floor or ceiling, Log: 6 logs?
Answer: Yes
Answered: 2026-10-23 00:45 UTC

## cost-11 | Floor or ceiling, Cobblestone: 60 cobblestones and 6 mortar?
Answer: No: These type of floors need a wooden floor underneath them so they need everything that a wooden floor has and then they put the stones on top of the wooden floor with the mortar
Answered: 2026-10-23 00:45 UTC

## cost-11 | Floor or ceiling, Cobblestone: 60 cobblestones and 6 mortar?
Answer: No: These type of floors need a wooden floor underneath them so they need everything that a wooden floor has and then they put the stones on top of the wooden floor with the mortar
Answered: 2026-10-23 00:46 UTC

## cost-12 | Floor or ceiling, Mason: 36 stone blocks and 8 mortar?
Answer: No: Again, these type of floors need to be braced with logs underneath so each floor has to have at least one log that gets split in half and put around the bottom edges in quarters so it matches up with the other walls and ceiling pieces, etc. it will take some design. Drop a design and let me look at it later put it back in the QA.
Answered: 2026-10-23 00:47 UTC

## cost-12 | Floor or ceiling, Mason: 36 stone blocks and 8 mortar?
Answer: No: Again, these type of floors need to be braced with logs underneath so each floor has to have at least one log that gets split in half and put around the bottom edges in quarters so it matches up with the other walls and ceiling pieces, etc. it will take some design. Drop a design and let me look at it later put it back in the QA.
Answered: 2026-10-23 00:47 UTC

## cost-13 | Roof, per slope piece, Thatch: 30 thatch, 10 twine, 8 sticks?
Answer: Yes
Answered: 2026-10-23 00:47 UTC

## cost-14 | Roof, per slope piece, Lap board: 10 rough planks and 40 nails?
Answer: Yes
Answered: 2026-10-23 00:47 UTC

