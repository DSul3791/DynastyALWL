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

## cost-15 | Roof, per slope piece, Stone shingle: 30 stone shingles and 4 mortar?
Answer: No: Again these stone roofs need to have wooden roofing underneath them so you make the slate roof using all the stuff you use for a wooden roof plus the stones and mortar
Answered: 2026-10-23 00:48 UTC

## cost-15 | Roof, per slope piece, Stone shingle: 30 stone shingles and 4 mortar?
Answer: No: Again these stone roofs need to have wooden roofing underneath them so you make the slate roof using all the stuff you use for a wooden roof plus the stones and mortar
Answered: 2026-10-23 00:48 UTC

## cost-16 | Roof, Flat: 6 lumber, 20 nails and 4 tar (from bitumen)?
Answer: Yes
Answered: 2026-10-23 00:48 UTC

## cost-18 | Small foundation 2x2: 40 stone and 12 clay?
Answer: No: Depending on the tier of material
Answered: 2026-10-23 00:49 UTC

## cost-18 | Small foundation 2x2: 40 stone and 12 clay?
Answer: No: Depending on the tier of material
Answered: 2026-10-23 00:49 UTC

## cost-17 | Small foundation 1x1: 10 stone and 3 clay?
Answer: No: Again, this all depends on the tier of material. Remember, we have basic floors, which would be compacted dirt and potentially leaves and boughs but we also have wooden foundations, stone, foundations, etc.
Answered: 2026-10-23 00:50 UTC

## cost-19 | Large foundation 1x1: 30 stone, 10 clay and 4 mortar?
Answer: No: Look at my previous answer
Answered: 2026-10-23 00:50 UTC

## cost-19 | Large foundation 1x1: 30 stone, 10 clay and 4 mortar?
Answer: No: Look at my previous answer
Answered: 2026-10-23 00:50 UTC

## cost-20 | Large foundation 2x2: 120 stone, 40 clay and 16 mortar?
Answer: No: Look at my previous answer
Answered: 2026-10-23 00:51 UTC

## cost-20 | Large foundation 2x2: 120 stone, 40 clay and 16 mortar?
Answer: No: Look at my previous answer
Answered: 2026-10-23 00:51 UTC

## cost-21 | Door, Basic: 10 twine, 20 thatch, 8 sticks?
Answer: Yes
Answered: 2026-10-23 00:51 UTC

## cost-22 | Door, Plank: 8 rough planks and 20 nails?
Answer: Yes
Answered: 2026-10-23 00:51 UTC

## cost-23 | Door, Reinforced: a plank door plus 2 iron ingots (banding) and 30 nails?
Answer: Yes
Answered: 2026-10-23 00:51 UTC

## cost-24 | Door, Wrought iron: 6 iron ingots?
Answer: No: It will also need wood and nails
Answered: 2026-10-23 00:52 UTC

## cost-24 | Door, Wrought iron: 6 iron ingots?
Answer: No: It will also need wood and nails
Answered: 2026-10-23 00:52 UTC

## cost-26 | Double door: twice a single door plus 2 hinges (1 iron ingot)?
Answer: Yes
Answered: 2026-10-23 00:52 UTC

## cost-25 | Door, Steel and iron: 4 steel ingots and 4 iron ingots?
Answer: Yes
Answered: 2026-10-23 00:52 UTC

## cost-27 | Wood pillar: 4 logs?
Answer: No: One log. Also, when a log lays on the ground, it should be about 8 feet long whatever that is in meters.
Answered: 2026-10-23 00:53 UTC

## cost-28 | Stone pillar: 20 stone blocks and 4 mortar?
Answer: Yes
Answered: 2026-10-23 00:53 UTC

## cost-29 | Brace 1.5 m: 1 log and 1 twine?
Answer: No: All braces should be made up of logs and wooden pins, which is an old style of construction so for combining things like log buildings or log beams, you can use large posts or logs, and you can use large wooden pins and dowels, and these wood resist rotting. Also, we should have two types of each so we can have them made from regular logs or tar soaked logs, and the tar soak logs Wood basically never degrade.
Answered: 2026-10-23 00:55 UTC

## cost-29 | Brace 1.5 m: 1 log and 1 twine?
Answer: No: All braces should be made up of logs and wooden pins, which is an old style of construction so for combining things like log buildings or log beams, you can use large posts or logs, and you can use large wooden pins and dowels, and these wood resist rotting. Also, we should have two types of each so we can have them made from regular logs or tar soaked logs, and the tar soak logs Wood basically never degrade.
Answered: 2026-10-23 00:55 UTC

## cost-30 | Brace 3 m: 2 logs and 2 twine?
Answer: No: See my previous answer
Answered: 2026-10-23 00:56 UTC

## cost-31 | Brace 5 m: 4 logs and 4 twine?
Answer: No: See my previous answer
Answered: 2026-10-23 00:56 UTC

## cost-32 | Is it OK to add the new items this needs: rough plank, fine board, nails (1 iron ingot makes 100), cobblestone, stone shingle, tar and hinges?
Answer: Yes
Answered: 2026-10-23 00:56 UTC

## basins-store | Store the list of lakes and basins (where each is, how deep, where it overflows) in the tile file, so the game always puts water at the bottom of the same basins?
Answer: Yes
Answered: 2026-10-23 01:14 UTC

## farwater-radius | Far water: show it out to 3 tiles from the player?
Answer: No: I’m not sure I understand this. Can you restate it? I don’t think players can see that far but I’m not sure what you mean by far water?
Answered: 2026-10-23 01:16 UTC

## sea-dam | Does a pit you dam off from the sea keep its water as a puddle?
Answer: No: Because it should evaporated and dry up if it’s not a natural catch basin, but if you have a source of water going into it, then it could hold water.
Answered: 2026-10-23 01:17 UTC

## farwater-spacing | Far water: use a 32 m grid for the distant river and lake picture (any river cell inside a 32 m cell marks it wet, lowest surface taken)?
Answer: No: The answer here might be. Yes I need your recommendation. Shouldn’t something like this be controlled by draw distance or performance
Answered: 2026-10-23 01:17 UTC

## sea-tunnel | Do tunnels or rooms below sea level that connect to the sea flood and drown like the river-flood rule, with a plain warning line when you dig below sea level near the coast?
Answer: No: Yes, but there doesn’t need to be a warning line when you dig you will see the water move
Answered: 2026-10-23 01:18 UTC

## sea-tides | Are tides left for later, not now?
Answer: No: No tides
Answered: 2026-10-23 01:18 UTC

## sea-source | Is the sea an endless source at sea level, so a pit dug below sea level and connected to the sea fills to sea level (trenches flood, harbours and canals possible)?
Answer: Yes
Answered: 2026-10-23 01:19 UTC

## sea-feedcap | Should the sea feed a pit at most 50 m3/s per connection, so a huge pit fills over minutes instead of instantly (a tunable number)?
Answer: No: It depends on how wide the opening is for the river like if you do a little trench, then it’s only gonna let a little bit of water through but if you dig a really wide trench or really deep trench, then it’s gonna let more through
Answered: 2026-10-23 01:20 UTC

## sea-feedcap | Should the sea feed a pit at most 50 m3/s per connection, so a huge pit fills over minutes instead of instantly (a tunable number)?
Answer: No: It depends on how wide the opening is for the river like if you do a little trench, then it’s only gonna let a little bit of water through but if you dig a really wide trench or really deep trench, then it’s gonna let more through
Answered: 2026-10-23 01:20 UTC

## sea-rivermouth | Do river mouths stay sea-connected, so damming a mouth floods the river behind it (an intended risk)?
Answer: No: I need you to clarify what this means. Do you mean putting a dam in a river causes it to back up like a real damn Would then yes. However, I would expect if I built a dam at the bottom of a river between the river and the ocean, I would expect the river to back up until it went over my damn or around my damn unless I built a damn around the entire island tall enough to stop it
Answered: 2026-10-23 01:22 UTC

## island-fill | Can players fill shallow sea with the spade (Raise mode) to build their own islands, up to about 6 m deep? (Sonny says 6 m, Sal says 1.5 m, Guru says about 4 m: answer No and write your number if you prefer another.)
Answer: No: I think players can put sand, soil or stone anywhere they want to all the way to the sky until they run out of oxygen. If this becomes a problem in the future, we will handle it then, but I can also see how if placing sand on an unstable foundation could cause it to spread out or slide down. Obviously you couldn’t put something like sand or dirt on a steep slope but if you keep throwing sand in a hole, it will fill it up eventually while spreading out into the whole kind of like water the way sand does. I’m not sure how we want to handle that dirt might just be handle like a normal voxel we should have Tyler review that and come up with the best practice
Answered: 2026-10-23 01:26 UTC

## island-slope | Does loose soil and sand slope away under water while rock and stone hold their shape (so a sand island needs rock edges)?
Answer: Yes
Answered: 2026-10-23 01:26 UTC

## island-pier | Can you build piers and timber posts out over the water piece by piece, like Valheim?
Answer: Yes
Answered: 2026-10-23 01:26 UTC

## island-fort | Do fortress and town foundations on your own island need ground about 1 m above sea level?
Answer: No: Yes, but you wanna make sure they stay above the storm surge level of waves
Answered: 2026-10-23 01:26 UTC

## island-fort | Do fortress and town foundations on your own island need ground about 1 m above sea level?
Answer: No: Yes, but you wanna make sure they stay above the storm surge level of waves
Answered: 2026-10-23 01:26 UTC

## log-wall-r4 | Does the log wall look right now: only this wall's logs, ends offset left and right, open spaces where a joining wall's logs pass through, no curved notch?
Answer: Yes
Answered: 2026-10-23 01:27 UTC

## ceilings-r4 | Do the six ceilings look right now: log = wide boards on top with rounded undersides, fine boards full length with no strips, cobblestone looks like cobblestone, mason unchanged?
Answer: No: Yes, but I wanna make sure that the log ceiling should look like that on the bottom but on the top, it should look exactly the same as the fine boards, except the boards are twice as wide
Answered: 2026-10-23 01:27 UTC

## roof-65-low | Kathleen read '65 degrees' as measured from the vertical, so a LOW roof: 45 degrees rises 2.0 m per 2 m of run, 65 rises only 0.93 m. Is that the shorter peak you meant?
Answer: Yes
Answered: 2026-10-23 01:28 UTC

## braces-r4 | Do the braces look right: round logs joined with wooden pins, each of the three sizes in a plain and a tar-soaked version?
Answer: No: Yes, these look perfect and as far as the materials to make them, you should be able to count the amount of logs on the images for each one and then add tar for the treated logs
Answered: 2026-10-23 01:29 UTC

## floor-frames | Do the cobblestone and mason floors look right: stone on top, a log split in half along each of the four edges underneath, plank floor under the cobblestones?
Answer: Yes
Answered: 2026-10-23 01:29 UTC

## esc-character | Esc menu: should Character open the Tab screen from the menu? (You answered No without a reason earlier; tell me why in the Why-not box.)
Answer: No: No, because characters can’t do anything from the escape menu that’s a player menu only
Answered: 2026-10-23 01:30 UTC

## cost-cobble-floor | Cobblestone floor = a full wooden floor (8 rough planks + 20 nails) plus 60 cobblestones and 6 mortar?
Answer: Yes
Answered: 2026-10-23 01:30 UTC

## cost-mason-floor | Mason floor = a full wooden floor (8 rough planks + 20 nails) plus 36 stone blocks and 8 mortar?
Answer: Yes
Answered: 2026-10-23 01:30 UTC

## cost-stone-roof | Stone shingle roof = a full lap board roof (10 rough planks + 40 nails) plus 30 stone shingles and 4 mortar?
Answer: Yes
Answered: 2026-10-23 01:30 UTC

## cost-found-basic | Basic foundation (compacted dirt with leaves and boughs): small 1x1 = 6 boughs + 10 leaves + 4 sticks and the ground tamped; small 2x2 = four times that?
Answer: No: No, you don’t have to tamp the ground when you place the foundation it will automatically flatten the ground
Answered: 2026-10-23 01:31 UTC

## cost-found-wood | Wooden foundations (for Plank, Fine wood, Log tiers): small 1x1 = 3 logs + 12 nails, small 2x2 = 12 logs + 48 nails, large 1x1 = 6 logs + 24 nails, large 2x2 = 24 logs + 96 nails?
Answer: Yes
Answered: 2026-10-23 01:31 UTC

## cost-found-stone | Stone foundations (Cobblestone, Mason tiers) keep the earlier numbers: small 1x1 = 10 stone + 3 clay, 2x2 = 40 stone + 12 clay; large 1x1 = 30 stone + 10 clay + 4 mortar, 2x2 = 120 stone + 40 clay + 16 mortar?
Answer: Yes
Answered: 2026-10-23 01:31 UTC

## cost-door-wrought | Wrought iron door = 6 iron ingots + 4 lumber + 20 nails?
Answer: No: It’s probably six iron ingots for lumber and 100 nails
Answered: 2026-10-23 01:32 UTC

## cost-pillar-wood | Wood pillar = ONE log (a lying log is about 2.4 m long, so one log is one pillar and one wall height)?
Answer: Yes
Answered: 2026-10-23 01:32 UTC

## cost-braces | Braces are logs plus wooden pins (no twine): 1.5 m = 3 logs + 4 pins; 3 m = 4 logs + 6 pins; 5 m = 6 logs + 8 pins?
Answer: Yes
Answered: 2026-10-23 01:33 UTC

## cost-braces-tar | Tar-soaked braces: same shape, add 1 tar per log, and the wear decay is almost zero?
Answer: Yes
Answered: 2026-10-23 01:33 UTC

## floor-brace-1 | Floor brace: under the four edges of every 2 x 2 m floor runs one log split in half (flat side up), cut in quarters so the pieces meet the neighbouring walls, ceilings and floors like a sill beam?
Answer: Yes
Answered: 2026-10-23 01:33 UTC

## floor-brace-2 | Floor brace: one log makes the four edge sills of one floor cell, and the wooden floor sits on the sills; every Plank, Fine and Log floor costs +1 log?
Answer: No: Because you can use boards to make the edges also so they just require boards of whatever they’re type is
Answered: 2026-10-23 01:34 UTC

## floor-brace-3 | Floor brace: neighbouring floor cells share the sill where they touch, so a big floor needs fewer logs than cells?
Answer: Yes
Answered: 2026-10-23 01:35 UTC

## pier-bed | May a pier cell (pillar or foundation) sit on the sea bed under up to 0.5 m of water?
Answer: Yes
Answered: 2026-10-23 01:35 UTC

## fill-stone | Is the spade fill with stone enough for bulk rock, with no separate rock-pile item?
Answer: No: Yes, but we are going to have rock piles so that we can put down rock piles just to store our rock. Also, you should just be able to pick up a rock pile by pushing E on it and you will get back all the rocks it took to make it and you should guesstimate how many rocks it should take to make a rock pile based on the size of our rocks and one rock pile should be about the right weight to fill someone’s inventory if they are average strength and their inventory was empty, so one character should be able to pick up a rock pile and slowly carry it to the waggon where they might dump it into the wagon, and the waggon would change his animation to look like it has rock in it
Answered: 2026-10-23 01:37 UTC

## fill-stone | Is the spade fill with stone enough for bulk rock, with no separate rock-pile item?
Answer: No: Yes, but we are going to have rock piles so that we can put down rock piles just to store our rock. Also, you should just be able to pick up a rock pile by pushing E on it and you will get back all the rocks it took to make it and you should guesstimate how many rocks it should take to make a rock pile based on the size of our rocks and one rock pile should be about the right weight to fill someone’s inventory if they are average strength and their inventory was empty, so one character should be able to pick up a rock pile and slowly carry it to the waggon where they might dump it into the wagon, and the waggon would change his animation to look like it has rock in it
Answered: 2026-10-23 01:37 UTC

## wet-stages | Within 4 m of water above, should a tunnel go through three stages by distance: damp (4 to 2.5 m, rare drips), dripping (2.5 to 1.2 m, drip points every few metres), running (under 1.2 m, thin streams down the wall and a drizzle)?
Answer: Yes
Answered: 2026-10-23 01:37 UTC

## wet-looks | Should the wet ceiling and walls look darker with a sheen and a few streaks, and each drop be a small falling sprite with a tiny ring splash on the floor?
Answer: Yes
Answered: 2026-10-23 01:38 UTC

## wet-floor | Should the wet floor look dark and glossy under and between the drips, with no puddles and no standing water?
Answer: Yes
Answered: 2026-10-23 01:38 UTC

## wet-steps | Should footsteps on the wet floor make a small splash and squelch?
Answer: Yes
Answered: 2026-10-23 01:38 UTC

## wet-sounds | Should drips plink with sound from each drip point, more often the closer you are to the water, plus a soft trickle loop in the running stage?
Answer: Yes
Answered: 2026-10-23 01:38 UTC

## wet-bracing | Does a wet ceiling need full bracing and a collapse window no longer than the cave-in time, so bracing matters more (water softens the roof)?
Answer: No: We don’t really wanna overcomplicate the game. Keep it simple stay the same as a normal cave. They already have the danger that if they break the ceiling, the ocean will flood in on them and flood their tunnel.
Answered: 2026-10-23 01:39 UTC

## wet-rivers | Do rivers and lakes drip into tunnels under them too, not only the sea?
Answer: Yes
Answered: 2026-10-23 01:40 UTC

## wet-noflood | Is there no real flooding under the sea until the sea link is built (only drips and wet floors for now)?
Answer: No: I’m not exactly sure what this question means but if somebody breaks a hole from a tunnel into the ocean, it should flood the tunnel and fill it in every direction up to sea level
Answered: 2026-10-23 01:40 UTC

## esc-character-2 | Add the Character button back to the Esc menu?
Answer: No: This seems confusing. I don’t want to be able to push tab while I’m in the setting screen and have it open my character screen if that’s what you’re asking me. But if you’re asking me if the escape key should open the menu for settings, then the answer is yes the escape key should open the settings menu. I hope that answers this.
Answered: 2026-10-23 01:57 UTC

## item-recipes-2 | Are these recipes OK: rough plank = 1 log gives 4; fine board = 1 lumber; nails = 1 iron ingot gives 100; cobblestone = 3 stone; stone shingle = 2 stone; tar = 5 pine tar; hinges = 1 ingot gives 4; wooden pin = 1 lumber gives 4?
Answer: No: Tar, you get from bitumen . Hinges you get 20 from one iron ingot. Wooden pins you probably get 20 from one lumber. But other than that, everything else is correct.
Answered: 2026-10-23 02:06 UTC

## lake-min-size | Should a hollow only count as a lake when it is at least 3 m deep and about 2,500 square metres (smaller hollows are filled in and hold no water)?
Answer: No: This is a good question and I’m gonna need Tyler to look it over and make suggestions because as long as there’s enough to rain above it to feed water into it it should be a lake or a pond or hold water in the real world anywhere that can hold water and doesn’t have a runoff will hold water. If we end up with lakes where we don’t want them, then we have to change the generator and how it makes the terrain.
Answered: 2026-10-23 02:08 UTC

## loose-fill-slope | Should sand and loose soil refuse to be placed on ground steeper than they would slide on ("too steep, it would slide")?
Answer: No: No, they should just slide down until they would settle and that way you could dump sand or soil over a cliff and it would fall to the bottom eventually making a big pile at the bottom
Answered: 2026-10-23 02:09 UTC

## river-mouth-dam | If a player dams a river where it meets the sea, should the river back up like a real dam until it goes over or around?
Answer: Yes
Answered: 2026-10-23 02:09 UTC

## far-water-2 | Far rivers and lakes: should the flat distant picture of water follow your draw-distance setting, so it costs nothing on Low?
Answer: Yes
Answered: 2026-10-23 02:10 UTC

## collapse-test-3 | Please test the tunnel collapse after the backup. Look for: warnings that build up over 5 minutes, then the roof falls. Did it work?
Answer: Yes
Answered: 2026-10-23 03:37 UTC

## lake-chunks-pic | Please take a picture of the lake water surface flickering between textures, with the F3 text showing your x, z.
Answer: Picture taken: Dave sent screenshots in chat and said "they are the water surface just rapidly changing textures for some reason". (Answered in chat 03:20 UTC; Guru removed the card at his request 04:10 UTC.)
Answered: 2026-10-23 04:10 UTC
## collapse-switch | Please test the tunnel collapse switch. Look for: green On, red Off, no shaking while Off, cave-in time kept after rejoining.
Answer: No: Caven time is not working for sure. It seems to be hard set.
Answered: 2026-10-23 04:05 UTC
## vsync | Please test VSync. Look for: On green, Adaptive amber, Off red, and the same after restart.
Answer: Yes: Worked fine. The switch turned green and red, and the VSC turned on and off.
Answered: 2026-10-23 04:07 UTC

## sound-fire | Please test Esc > Settings > Sound test: fire. Look for: each step is heard, from embers to the hiss when it is put out.
Answer: Yes: The crackling fire sounds good
Answered: 2026-10-23 04:09 UTC

## sound-fire | Please test Esc > Settings > Sound test: fire. Look for: each step is heard, from embers to the hiss when it is put out.
Answer: Yes: The crackling fire sounds good
Answered: 2026-10-23 04:09 UTC

## beach-loud | Is the beach still too loud when you walk on it?
Answer: No: The walking sound is slightly too loud, but the running sound is significantly too loud on the sand. The running sound should just be slightly louder than the walking sound.
Answered: 2026-10-23 04:10 UTC

## ground-piles | Should loose items on the ground of the same kind that land close together (about 1 m) merge into one pile with a count, so the limit of 64 items near a spot is no longer a problem?
Answer: Yes
Answered: 2026-10-23 04:10 UTC

## rockpile-merge | Should rocks dropped within 1 m of each other join into one pile (same kind only, never tools), and does this fix the limit on items on the ground?
Answer: Yes
Answered: 2026-10-23 04:11 UTC

## rockpile-kinds | Should the same pile rule work for soil, sand, clay, gravel and ore (as mounds), and for logs, planks and bricks (stacked, look later), but no mixed piles?
Answer: Yes
Answered: 2026-10-23 04:11 UTC

## rockpile-block | Should a pile of 6 or more block movement like a boulder (you walk around it, you cannot climb it)?
Answer: Yes
Answered: 2026-10-23 04:11 UTC

## rockpile-despawn | Should a pile of 6 or more last 2 hours after the last add or take, instead of the usual 20 minutes?
Answer: Yes
Answered: 2026-10-23 04:11 UTC

## rockpile-big | Above about 500 rocks, should the look change to a smooth rocky mound instead of drawing every rock, with a limit of 100,000 rocks per pile?
Answer: Yes
Answered: 2026-10-23 04:12 UTC

## rockpile-big | Above about 500 rocks, should the look change to a smooth rocky mound instead of drawing every rock, with a limit of 100,000 rocks per pile?
Answer: Yes
Answered: 2026-10-23 04:12 UTC

## cavein-death-slow | Should a cave-in that kills you be slow and dramatic: the roof falls in 3 to 5 waves over about 6 seconds, with dust and rumble, instead of all at once?
Answer: Yes
Answered: 2026-10-23 04:12 UTC

## cavein-death-fade | Then: the picture fades to black over about 4 seconds while the rumble keeps going for about 3 more seconds, then the sound fades out too?
Answer: Yes
Answered: 2026-10-23 04:13 UTC

## cavein-death-skull | Then: a grey, translucent skull and crossbones fills about 75% of the screen over the black?
Answer: Yes
Answered: 2026-10-23 04:13 UTC

## cavein-death-voice | Until the real voice exists, show the three lines as big text under the skull with a small horn sting and a comic sting, and swap the voice in later?
Answer: No: Use your voice to text generator to come up with something fun
Answered: 2026-10-23 04:13 UTC

## cavein-death-voice | Until the real voice exists, show the three lines as big text under the skull with a small horn sting and a comic sting, and swap the voice in later?
Answer: No: Use your voice to text generator to come up with something fun
Answered: 2026-10-23 04:13 UTC

## head-ponds-retire | Should we stop making the round stamped pond at the top of each river, and let lakes and rivers start only where the land has a real catch basin (terrain B), at the next bake?
Answer: Yes
Answered: 2026-10-23 04:14 UTC

## lake-low-quality | Please test: set quality to Low and see what happens. Look for: do the grey shapes and dark squares VANISH on Low?
Answer: No: They don’t vanish they just get darker but they keep switching
Answered: 2026-10-23 04:14 UTC

## lake-low-quality | Please test: set quality to Low and see what happens. Look for: do the grey shapes and dark squares VANISH on Low?
Answer: No: They don’t vanish they just get darker but they keep switching
Answered: 2026-10-23 04:14 UTC

## cavein-death-next | Then everything fades out slowly and you fade in on the inheritance or character creation screen, and this long sequence is only for cave-ins (other deaths keep the simple screen)?
Answer: Yes
Answered: 2026-10-23 04:15 UTC

## rockpile-take | Taking from a pile: press E to take a handful (about 5), hold E to take as many as you can carry, and the pile shrinks row by row?
Answer: Yes
Answered: 2026-10-23 04:15 UTC

## offhand-items | Off-hand items: pick a torch, shield or similar from the hotbar and it goes in your left hand; pick it again and it is put away; hold B to block with it?
Answer: Yes
Answered: 2026-10-23 04:15 UTC

## spade-raise | Please test spade Raise mode. Look for: each click takes soil from your pack and the pack count drops.
Answer: Yes
Answered: 2026-10-23 04:18 UTC

## lake-hide-water | Please test: hide the water and see what stays. Look for: do the grey shapes and dark squares STAY when the water is hidden?
Answer: No: No, if the water is gone, there’s nothing there. It is literally changing the texture on the water.
Answered: 2026-10-23 04:19 UTC

## hotbar-move | Is this how the hotbar should work: a tool dragged onto the hotbar MOVES there and leaves the pack grid (the hotbar is extra holding slots, not a copy, and it still counts for weight), and E over a hotbar slot with the inventory window open puts it back in the first free pack slot?
Answer: Yes
Answered: 2026-10-23 10:10 UTC

## blocks-from-shoulder-log | A log from your shoulder, put on the ground and chopped with an axe, gives 12 wooden blocks?
Answer: Yes
Answered: 2026-10-23 10:10 UTC

## firewood-from-block | One wooden block used on the chopping block gives 1 firewood (3.5 kg) that falls beside the block, and the pieces merge into one heap (the pile look from 5 pieces is Kathleen's)?
Answer: No: Yes but it gives 2 firewood which is split wood
Answered: 2026-10-23 10:11 UTC

## blocks-from-log | A log from your pack, dropped on the ground and chopped with an axe, gives 4 wooden blocks (about 0.3 m long, 3.75 kg each)?
Answer: No: No, there’s only one type of log. There is no pack log. The log in your backpack is just symbolic of the log on your shoulder. They are connected. If you dropped the log out of your shoulder, the pack log is gone too.
Answered: 2026-10-23 10:13 UTC

## axe-wear-chop | The axe wears once for each log chop and once for each split at the chopping block?
Answer: Yes
Answered: 2026-10-23 10:13 UTC

## species-uses-1 | Should each kind of tree be good for different things, using four numbers per species (hardness, burn time, rot resistance, how easy it is to work)? For example oak for strong beams and posts, birch and beech for firewood, pine and spruce for planks, alder for piers in water, apple and cherry for tool parts.
Answer: No: Yes, but don’t overcomplicate it. Hardest is a good one which affects how long it takes to cut down. Hardwood trees are harder, but they’re also thinner. Soft wood trees are significantly larger around and you could use burn time. Hardwood takes a lot longer to burn. Softwood even though it’s Biggar burns really fast. Have Tyler do some research and come up with some numbers. We don’t wanna get into too many micromanaging of details software is better for making boards hardwood like Birch are really good for a different type of board. Have Tyler research what type of lumber hardwood versus softwood
Answered: 2026-10-23 10:18 UTC

## species-uses-2 | Recipes still accept "any log", but a better species gives a better result (stronger beam, less tool wear, longer-burning fire)?
Answer: No: Logs are named after their trees and Tyler could research which trees are best for making white stuff. And this will affect which are good at making boards or different types of boards of which are best for firewood or for making pillars usually big round soft wood or cedar are used for making pillars or beams that have Tyler researched this also we should not make our system to overly complicated but we do not watch it to simple
Answered: 2026-10-23 10:21 UTC

## species-uses-3 | Hard woods (oak, walnut) take more axe wear to chop, so they feel valuable?
Answer: No: They might be harder, but you don’t have to hit them as much because they are smaller
Answered: 2026-10-23 10:22 UTC

## logs-per-tree | A felled tree gives whole 8 ft (2.44 m) logs by its height, rounded down, at most 20 per tree (a 24 ft tree gives 3, a 9 ft tree gives 1)? The old bonus for thick trunks goes away.
Answer: Yes
Answered: 2026-10-23 10:22 UTC

## species-uses-4 | Firewood and wooden blocks from different species stay in separate piles (no mixed piles), and piers and wet foundations need a rot-proof wood (oak, chestnut, alder)?
Answer: No: Yes, except foundations. It’s video game logic. A foundation is a foundation.
Answered: 2026-10-23 10:24 UTC

## small-tree-work | A small tree (under 8 ft) gives no whole log: working the trunk gives 3 blows of branches (sticks and leaves) and then 3 blows of firewood, kindling and sticks, then it is used up (no roots, no blocks)?
Answer: Yes
Answered: 2026-10-23 10:24 UTC

## log-names | Logs are named by the tree, written "Oak logs", "Beech logs" instead of "Oak_Logs" (item ids stay log_oak, log_beech and so on). Is that fine?
Answer: Yes
Answered: 2026-10-23 10:24 UTC

## lake-rule-2 | Should any hollow hold water when enough rain can reach it, with no minimum size, and we fix places with unwanted lakes by changing how the generator makes the land?
Answer: Yes
Answered: 2026-10-23 10:25 UTC

## fix-merge-guard | Should we build a pre-merge check script first (it checks conflict markers, duplicate item numbers and action ids, next_number, crash logs, JSON and the warning count) and then run it automatically on GitHub (CI)?
Answer: Yes
Answered: 2026-10-23 10:26 UTC

## fix-id-claims | Should item numbers and action ids be claimed in one short file (or given fixed ranges per thread), so two threads can never pick the same number?
Answer: Yes
Answered: 2026-10-23 10:26 UTC

## fix-team-tests | Confirm the rule that the team tests first (headless, look rig, showroom) and only human-judgment tests go to you?
Answer: Yes
Answered: 2026-10-23 10:26 UTC

## fix-inbox | Should each thread get a short inbox file that the coordinator and Tyler write only the changes into, instead of long relays?
Answer: Yes
Answered: 2026-10-23 10:27 UTC

## fix-slim-reading | Should we shrink what every thread reads at the start: a short first-jobs block at the top of HANDOFF.md (40 lines at most), old sections archived, and only the rules that apply to each thread?
Answer: No: Yes, as long as we don’t lose the details
Answered: 2026-10-23 10:28 UTC

## fix-slim-reading | Should we shrink what every thread reads at the start: a short first-jobs block at the top of HANDOFF.md (40 lines at most), old sections archived, and only the rules that apply to each thread?
Answer: No: Yes, as long as we don’t lose the details
Answered: 2026-10-23 10:28 UTC

## small-tree-under-8ft | Is a tree under 8 feet 'small', giving only firewood, kindling and sticks?
Answer: Yes
Answered: 2026-10-23 10:29 UTC

## kath-log-carry | Is the carried log centred on your shoulder now?
Answer: No: You should be able to test this I am not at my computer
Answered: 2026-10-23 10:29 UTC

## keep-item-roll | Items roll a little when walked over
Answer: Yes
Answered: 2026-10-23 13:14 UTC

## kath-flora-cane-berries | Do the raspberry bush and bramble look like the real plants?
Answer: No: I don’t know that looks terrible
Answered: 2026-10-23 13:14 UTC

## lake-flicker-dump | Lake flicker: dump the live water under the shifting patches (build 703)
Answer: No: Regarding the flicker, have Tyler research it and see if he could come up with an answer because it never used to happen. The water is there the water is fine, but the surface of the water is flickering and losing its textures.
Answered: 2026-10-23 13:18 UTC

## test-floating-soil | Mined soil lies in the hole
Answer: No: To make the rig dig can’t you put a shovel in your hand look down at a 15° angle and push the mouse button and then walk forward a step and do it again and then look around
Answered: 2026-10-23 14:27 UTC


## test-lake-flicker | Lake no longer flashes grey
Answer: Yes: told in chat, "I can clearly see the flickering on the lake water is gone" (build 727)
Answered: 2026-10-23 14:55 UTC

## playtester-plan | Build a play-tester that plays the game and reports problems?
Answer: No: told in chat, no player bot; instead improve how testing works (drop dirt, look down, step back a very short distance) 15:58 UTC
Answered: 2026-10-23 15:58 UTC
## kath-moose-standin | Use an elk bugle as the moose call for now?
Answer: No: This is not what the move sounds like a moose. Sounds like somebody having a grunt when they poop so see if you can look up that sound.
Answered: 2026-10-23 16:00 UTC

## kath-wolf-real-clips | Do the real wolf howl recordings (clip A and clip B) sound like a wolf?
Answer: Yes
Answered: 2026-10-23 16:30 UTC

## kath-fox-real-clips | Do the real fox clips (a bark and a scream) sound like a fox?
Answer: Yes
Answered: 2026-10-23 16:37 UTC

## kath-deer-horse-real-clips | Do the real deer grunt and the two horse neighs sound right?
Answer: Yes
Answered: 2026-10-23 16:37 UTC

## kath-bear-real-clips | Do the real bear growls (clip A and clip B) sound like a bear?
Answer: Yes
Answered: 2026-10-23 16:37 UTC

## pull-deletes-crash-logs | OK that your next Pull removes the old crash report files from your folder?
Answer: Yes
Answered: 2026-10-23 17:36 UTC

## foundation-sizes | Should foundations come in two sizes, small 2 m and large 3 m?
Answer: No: We’ve already answered this a couple times
Answered: 2026-10-23 19:07 UTC

## dry-river-dump | Dump the water once at the dry river spot (build 750)
Answer: No: You do the test
Answered: 2026-10-23 19:07 UTC

## bake9-steps | New island ground: pull, let Mike copy the tiles, commit them (build 751)
Answer: No: This is all stuff you can do
Answered: 2026-10-23 19:08 UTC

## kath-raspberry-rig | Does this look like a real raspberry bush?
Answer: No: You didn’t provide a picture
Answered: 2026-10-23 19:08 UTC

## kath-raspberry-rig-2 | Does this look like a real raspberry bush? (picture attached)
Answer: No: There is no picture here. Please tell somebody to review this and figure out why ask Tyler
Answered: 2026-10-23 19:25 UTC

## kath-raspberry-rig-2 | Does this look like a real raspberry bush? (picture attached)
Answer: No: There is no picture here. Please tell somebody to review this and figure out why ask Tyler
Answered: 2026-10-23 19:25 UTC

## hoe-grade-keys | Hoe grade line: Shift + right click sets points A and B, Shift + left click grades. OK?
Answer: Yes
Answered: 2026-10-23 19:26 UTC

## kath-raspberry-rig-3 | Does this look like a real raspberry bush? (picture shown)
Answer: Yes: Not bad, but it needs a lot more stems and way more leaves so it should look like a full bush
Answered: 2026-10-23 20:33 UTC

## ok-pull-754 | Build 754 starts fine. OK for MikeW to update your game folder now (and copy the new island tiles)?
Answer: Yes
Answered: 2026-10-23 20:33 UTC

## hold-pull-754 | Do NOT Pull or start the game yet: the newest build does not start (fix coming)
Answer: No: OK
Answered: 2026-10-23 20:34 UTC

## hold-pull-754 | Do NOT Pull or start the game yet: the newest build does not start (fix coming)
Answer: No: OK
Answered: 2026-10-23 20:34 UTC

## allow-mike-pull | NEW PERMISSION ask: let MikeW update your game folder, copy the island tiles and commit them?
Answer: Yes
Answered: 2026-10-23 21:24 UTC

## cost-basic-foundation | Basic foundation cost: small 1x1 = 6 boughs, 10 leaves, 4 sticks (2x2 = four times that)?
Answer: Yes
Answered: 2026-10-23 21:24 UTC

## cost-floor-brace | Stone floors (cobblestone and mason) also take 1 log, split in half, as sills under the floor edge?
Answer: No: Stone floors don’t need a sill edge
Answered: 2026-10-23 21:25 UTC

## cost-floor-brace | Stone floors (cobblestone and mason) also take 1 log, split in half, as sills under the floor edge?
Answer: No: Stone floors don’t need a sill edge
Answered: 2026-10-23 21:25 UTC

