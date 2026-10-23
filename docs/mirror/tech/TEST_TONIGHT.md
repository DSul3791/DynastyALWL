# Things to test tonight (Guru, built 2026-10-23 00:30, head = build 693)

Dave tests ONLY after goodnight and the backup (BP-T40). Before testing: 1. Pull. 2. Close the game fully (server restarts). 3. Start it and check the HUD says the head build (687 or higher). Each line below becomes one Yes/No card with a Why-not box.

## Restart builds (do these first)
1. 650/651 Quit and resume: walk 60 m, Esc, Quit game, Play again: you start where you left. Kill the game window, wait 3 minutes, Play: you appear beside your nearest lean-to or campfire. Screenshot: none.
2. 654 Doors: place a doorway, press E to open and close, hold E to take it down; a shut door blocks you. Screenshot the open and shut door.
3. 653 Fire: open a campfire store with sticks and berries; sticks burn one by one, berries turn to roast.
4. 670 Names: hover cooked food: Campfire Stew, Roast Beast, Roast Meat, Roast Fish, Roast Roots. Hover rope: it is called Twine (684). Screenshot the inventory.
5. 671 Items: give yourself stone block, brick, mortar, ladder. 675 Ladder: place it against a wall, face it, hold W to climb, S down, Space lets go. Screenshot the ladder.
6. 673 Snaps: walls join end to end and at corners; floors and roofs meet edge to edge. Screenshot a small room.
7. 676/682 Spades: small, medium, large spade; Raise mode takes shovelfuls straight from the pack (no loading): 1, 4, 8. Right click switches Dig and Raise.
8. 677/679 Hoe: left click treads a tan path patch; right click smooths a bump (no items; only the hoe wears; "This ground is worked enough." when nothing moves). Screenshot a path and a smoothed bump.
9. 681/684 Chopping block: 18 kg, made from 2 logs; in the hand it is the placed model at 30 percent size. Does it look like the placed one, only smaller? Screenshot hand, ground and placed side by side. Set it down and split a log.
10. 685 Braces: timber prop holds a 5 m sphere, timber set 7.5 m; both shrink with wear.
11. 686 Collapse (protocol 72): Esc > Settings > Tunnel collapse On/Off (admin) and Cave-in time (2/5/10/20 min); set 2 min; dig a space wider than 2 m in a hand-dug tunnel; creaks, shaking, "The earth groans.", at least 90 s of shaking, then it falls; braces pause it; a natural cave never collapses. Screenshot the shaking and the rubble.
12. 687 VSync: Esc > Settings: VSync shows On green, Adaptive amber, Off red; the fps line says "N fps (vsync X)".

## Systems (Steve) detail lines for the collapse and menu (each a Yes/No card at goodnight)
S1. Collapse timer: tunnel about 2 m wide or more in solid ground (not natural): nothing for about 10 minutes (cave-in time can be set 2 to 20 min).
S2. Collapse warning: creaks, then shaking with dust and "The earth groans.", then "The roof is giving way. Get out now!" every 5 s. Screenshot the shake and dust.
S3. Collapse fall: standing outside, the roof falls about 30 minutes after the dig (or your shorter setting), fills about 70% with rubble and leaves the top open.
S4. Natural caves never shake or collapse.
S5. Esc > Settings "Tunnel collapse: On/Off (admin)" shows green On or red Off; Off stops all shaking.
S6. "Cave-in time" cycles 2, 5, 10, 20 min and stays set after leaving and rejoining.
S7. VSync button reads On green, Adaptive amber, Off red; fps line shows "(vsync X)"; stays set after restart.
S8. Ladder: W climbs, S down, Space lets go, W at the top steps onto the edge.
S9. Braces: a prop (5 m) or timber set (7.5 m) stops the collapse timer within its radius.
(Esc menu tidy lines come when it is built, after Dave answers its 9 cards.)

## Runtime builds
13. 672 Stations: at a workbench or forge the prompt says Press F, F or E opens crafting; hold E still takes it down.
14. 663 Clothing on the body: wear hide cloak, leggings, boots; third person shows coat, trousers, shoes in the item colours.
15. 674 Sound test menu (Esc > Settings > Admin): buttons still work.
16. Looks v5 and tools v6: the 4 hoes (wooden, stone, iron, steel), the 3 spade sizes, wedge axe (from the side it looks like a hoe head), bucket (light wood, dark hoops), stone block, brick, mortar read as the real things at 2 m and 20 m. Screenshot one row of them on the ground.
17. 683 Collapse warning visuals: covered by test 11.

## Waiting on a thread (not testable yet)
- Kathleen: new place sounds (place_stone, place_brick, place_thatch) and shovel soil/stone-load sounds are not merged (sound listen later); tier pieces (walls, floors, roofs, doors, ceilings, braces) are drawings only; nothing to test in the game until built.
- Sal: blueprint building (mallet, ghosts, foundations, pillars) not built.
- Sonny: ground rework BAKE-1 prototype on MikeW's PC; Dave only decides on the 9-tile bake.

## NEXT NIGHT test lines for merged branches (Guru 04:35 UTC 23 Oct, build 700)
- T | Please test: craft a rock pile from 45 stones, set it down, press E. Look for: 45 stones back in the pack; hold E instead and you carry the pile. (sal-rock-pile, item 235)
- T | Please test: dig a tunnel in rock off the beach and go under the sea until the ceiling is within about 4 m of the water above (or under a lake or river). Look for: drips, a dark wet patch under each, nothing collecting, no drips more than 4 m under the water. (steve-drip, protocol 73)
- T | Please test: hold a torch in a cave. Look for: quiet soft crackle, no loud echo. (kathleen-torch-rain)
- T | Please test: stand in open rain, then under a roof. Look for: no sharp clack in the open, clacky rain only under the roof. (kathleen-torch-rain)
- T | Please test: dig a cave, set the cave-in timer to 2 minutes. Look for: rumbling after the quiet part and the fall about 2 minutes later (or 90 s after the change if already past). (steve-cave-in-setting)
- T | Please test: craft with Admin mode on, then off (Esc > Admin). Look for: free crafting when on, normal rules when off; E on a recipe crafts one. (admin craft)
- T | Please test: Esc > Admin > Reset all terrain edits, confirm. Look for: dug holes gone after reload, no errors. Backup first. (steve-reset-edits)
- T | Please test: throw a log on the ground and chop it with an axe; put a block on the chopping block. Look for: 4 blocks from a pack log (12 from a shoulder log), 1 firewood beside the block per split. (sal-wooden-blocks)
- T | Please test: cut an oak, then a birch. Look for: log colours (oak grey-brown, birch pale), shoulder log centred. (kathleen-log-looks)
- T | Please test: hold the left mouse with a wooden hoe and walk on grass. Look for: a line of flat tan path patches. (sal-hoe-hold)
- T | Please test: Esc > Settings > Sound test and walk on wet tunnel floor. Look for: wet footsteps and drips once steve-drip drives them. (kathleen-wet; sounds exist, only heard when the drip effect calls them)
