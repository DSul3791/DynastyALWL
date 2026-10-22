# TEST QUEUE (RULE 2, Dave 2026-10-22)
Threads never ask Dave for tests in chat or posts. Add ONE line here instead; Steve groups the queue into a single test card on the question page every few builds (or when 3 or more items are queued) and removes answered or stale lines.

Line format: `- build N | thread | what to look at (x y z if any) | what to check`

## Queue
- 658 | Kathleen (shots by MikeW) | creatures at 20 m, picture /mnt/project-files/animals_20m_sheet.png (the game's AnimalView, side-on, 70 degree view, standing still, not a live game): moose grazing, warning and charging, horse, fox, ducks | each reads as the right animal from 20 m? Then in game walk up to a moose and watch warn and charge
- 657 | Kathleen (shots by MikeW) | batch 2 item looks, picture /mnt/project-files/looks_batch2.png (BasicLook rendered on a plane, not an in-game drop): stone axe, knife, wooden spade, iron pickaxe, torch, three kits, clay pot, bucket, backpack, bone (now dimmer), bowl, waterskin, iron ingot, oak lumber | does each read as what it is; any wrong size or colour?
- 656 | Kathleen (shots by MikeW) | stage-one item looks, picture /mnt/project-files/looks_batch1.png (rendered with the game's BasicLook on a ground plane, not an in-game drop): spear, bark, leaves, bandage, firewood, cordage, seed bundle, roots, poultice, plant fibre, roast forage, bone | does each read as what it is; any wrong size or colour? Then in game drop a few and compare

## Sent to Dave (card id in questions/QUESTIONS.md)
Card test-626 (2026-10-22 05:05), build 626:
- 612 | Radar | torch in third person: hold a torch, scroll out; torch and light should be in the right hand. Drops near stumps and trunks: dropping soil should work when only trunks and stumps lie around.
- 620 | Radar | wall, floor and roof sections (workbench recipes): place a few edge to edge; check snapping, solid walls, roof shelter. "Press E to gather" only when looking straight at it within 2 m; E still picks up what is near.
- PASSED (Dave 05:16) 620 | Radar | trade window: one click "Would you like to buy my extra stuff?" sells materials, food and medicine under 50 copper, never tools or valuables; result line shows.
- PASSED (Dave) 622 | Radar | coin icons in the purse and trade window: order copper, bronze, silver, gold left to right; circle size and colours readable at 1080p.
- 0 | Mandy | sounds for movement and digging (current build): dig soil, gravel and rock, walk through a tunnel, wade in water, run on grass and stone; say which sounds are wrong (name the file from the F3 sounds-heard list).
- Sonny 623: restart server, fly to x 53800 z 69340 (head pond, 427 m). Check: the round pond there fills over ~30 real minutes at the default rate, and the lower basin west of it (x 53672) is a river lake, not the source; nothing spills south over x 53670 z 69300 onto the plains.
- Sonny 623 (extra): watch the back pond (dark crater at x 53800 z 69340) for 30 real minutes: does it fill and spill out its own outlet, and does the front lake (x 53672) stop growing? Note: the front lake is baked as a river lake 4 m deep, so it stays smaller, not gone (that needs the bake fix).
- Sonny/Willy slab hunt (build 622, pond near spawn x 53300-53350 z 68400-68450, flat brown squares on the water): ANSWERED by Dave 05:02: you cannot stand on them, they are visual only, no Dump needed. Next look: fly low over the lake and move the camera slowly: do the squares flip when the camera moves (sorting/z-fight) or only with the clock/water level (water sim), and do they vanish at Low quality (F2)?
- 624 | Radar | place a wall or campfire kit at the pond edge: ghost red with 'you cannot build in water', refused on the server; dry ground still works.
- Sonny 623 (check position): stand at the rim of the east bowl, x 53838 y 428 z 69341, after a server restart. HUD water should read above -1.00 m within about 30 real minutes (bowl floor 413 m, full at 425.6 m). Look down: is it filling?
- 626 | Mandy | building pieces look and sound: place a wall, floor and roof; boards should read as 25 cm timber planks (wall, floor) and close split boards (roof), darker timber posts and edges; hear a hammer-tap-and-creak when a piece is placed; say if too bright, too dark or the sound is wrong.
- Sonny build 628: fly to the spawn lake (x 53300-53350 z 68400-68450) where the brown squares show. Press Ctrl+Shift+W (hides the water). Do the squares stay? Stay = ground problem; gone = water drawing. Press again to bring water back. Tell us which.
629 | Radar | Foundation: craft or /give a Foundation, place it near spawn; check grass is cleared 2 m past its edge, walls/floors snap to its edges and corners and stand on top. Talk to Hob: the 'buy my extra stuff' button sells materials and keeps tools
- 630 | Mandy | foundation look and sound: place a foundation; grey fitted stone sides with a darker earth top inside a rim, the walls/floors still snap on; hear a deep thud with a stone scrape.
- 631/632 | Tyler | (a) grass 618: stand in a dug pit looking up, no grass over the mouth; NPC names hidden behind ground. (b) ruler 621: marks every 10 plus one at 45, no centre line, shows in an open pit and in water. (c) under-the-world 631: break rocks next to you with the spade; you should never end up under the world, and if you do you are stood back on the surface within 2 s (tell me x y z if not). (d) exhaustion sleep 632: collapse from exhaustion; the black screen shows minutes left and Space held wakes you from 30 percent energy. (e) join 621: close the game and press Play again right away; it should wait for or replace the old server, no stuck "0 blocks" screen.

Added to card test-626 at build 631:
- 625 | Willy_002 | rock rescue: if you pop out below the world again (it happened after hitting a rock), tell us; 625 lifts you out of rock and logs a RESCUE line in crash_reports with where and why | push crash_reports/ if it happens
- 625 | Willy_002 | pit wall panels (the hard-edged rectangles in the deep pit at x 53320 y 10.5 z 68418, facing 289 and 004) | press F2 until the HUD says Low (shadows off): do the panels vanish? Yes = shadow setup (Willy tunes), no = ground mesh or material

- 627 Mandy sand steps; 628 debug Ctrl+Shift+W; 629/630 foundation and extras sale button
- Sonny 623+ (back pond still dry?): Dave, please read the build number on the top-left HUD (must be 623 or higher AND the server restarted after pulling it), then fly to x 53838 y 428 z 69341. Tell us the HUD build, minutes since the server restart, and what the pond looks like. The pond should be filling within 5 minutes of the restart.
633 | Radar | Hover a coin icon in the purse or the trade window: it says Copper coin, Bronze coin, Silver coin or Gold coin
636 | Radar | In a leafy spot look at a loose dark branch on the ground within 2 m: 'Press E to gather' shows and E gives a stick, the branch vanishes
637 | Radar | Hold a campfire kit, a bench or a wall: a see-through copy of the real item shows where it will go, green when allowed, red when not (water, too close, steep)
638 | Radar | Third person (scroll out): hold a torch, an axe, a knife: the hand grips the handle end with the flame or head up and away
- 639 | Mandy | campfire sound: only the crackle now, no jet-engine roar under it; check small and big fires, near and 20 m away; say if the fire now sounds too quiet or thin.
Added to card test-626 at build 639 (05:35): 633 coin names, 636 sticks, 637 placement ghost, 638 tool grip, 639 campfire sound.
641 | Radar | Craft a Doorway and a Window wall (workbench, 3 lumber 1 cordage), place them on or beside a foundation: you walk through the door gap, the window opening is at chest height; a foundation with a wall on it says 'Take down what stands on it first'
643 | Radar | Let a campfire burn out: it stays a campfire with no flames. Stand beside a chest and press F: your pack left, chest right, T moves the selected stack. G still flies
645 | Radar | Stand at a campfire, press F: pack left, fire right. T a few sticks and some berries into it: the sticks feed the fire when it burns low and the berries roast. Crafting list > Admin: ten placeables, free

## Parked 2026-10-22 (Dave: "we will address the old questions later")
The 11 "Have you answered this yet?" checks (builds 623 to 645) were moved from the question page to `questions/LATER.md` and can be restored at any time. They will be regrouped into one test card when development restarts.
PROVISIONAL | Sal | branch claude/sal-piecelook | RESTART | Same look as before: place a wall, doorway, campfire, chest; grass clears under the foundation, floor and campfire but not under walls or roofs; placed sounds unchanged

## Batching rule (Dave 17:10)
Dave does NOT pull or run builds until a thread needs him to look. A thread adds a line here: build number, one-line what to look at, owner. The Guru batches ready lines into check cards ("[check]" blocks, see questions/README.md) so Dave tests several things in one pull. Dave answers Yes, or No plus a reason; the coordinator relays No reasons to the owner. The 11 old checks in questions/LATER.md become cards only when their owner says they are ready.

- 649 (Steve_ProblemSolver): rock rescue and void rescue still work after the rescue.gd split. Look: get stuck in a rock / fall through a void and see you are rescued. Status: waiting to batch.

- cl-tests (Dave 17:17): the 11 old checks in questions/LATER.md are regrouped into check cards after the restart work; owner of each says whether it still applies. Guru builds the cards.
