# Fixed Bugs

All Fixed Bugs Go here.

## 49. Shovel name

Dave asked on 16 Nov 2026 for every Spade to be called a Shovel, including icons and internal names. Fixed by PR #1182, merged to dev at bcd02908. Verified in a Dave play test on 19 Nov 2026 ("Yes it is now called shovel in game").

## 1. Level terrain without lifting the player or creating free fill

Level keeps the feet height from the start of the held action, never edits within 1.2 m of the feet, and every fill costs Soil from the crafting stock. Fixed by PR #1252, merged to dev at a9fd033a. Automated: test_server_items on Dave's PC. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 2. Foundations must use the edited ground surface

Placement height, slope and roof-panel checks read the saved digs and fills. Fixed by PR #1252 (dev a9fd033a). Automated: test_server_items foundation on raised ground. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 3. Rocks must visibly deplete as they are mined

Boulders hold stones by volume at 0.04 a unit (RK-1), crack as they are worked and crumble when mined out; the count survives reload. Fixed by PR #1252 (dev a9fd033a). Automated: test_server_items stone counts. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 4. Keep the hoe menu readable on screen

At most 75% of the window wide, wrapped, in view. First fix PR #1252; second fix after the 19 Nov play test, PR #1283 (dev df8716cf). Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 5. Present the hoe actions in a practical order

Level, Plant, Till Garden Grid - 20m Edge Blend, Till Soil 2m, Pathen (one click, one spot), Survey a Path unchanged. Fixed by PR #1252 (dev a9fd033a). Automated: test_server_items Pathen checks. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 6. Make gardening and planting deliberate, quick and predictable

Server-checked neon preview; obstacles and 2 m building clearance refuse before any change; garden grid averages, levels, tills and blends within 20 m, then a 20 s countdown; Till Soil 2m; one-click Plant grid from the crafting stock. Fixed by PR #1252 (dev a9fd033a), validator follow-up PR #1260 (dev a57c24cb). Automated: test_farming and test_farm_prompt on Dave's PC. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 50. Level gives no soil back when it cuts ground

Cutting with Level gives Soil back at the rate a fill of the same depth costs. Fixed by PR #1286, merged to dev at e5272847. Automated: Lane B 201 of 201. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 84. Sixty NPCs cost over 1 ms a server tick (test_npcs timing check red on Lane A)

**Status: Fixed in dev - nothing to play (no behaviour change).** Not found in play: the coordinator, 20 Nov 2026, from Lane A (Dave's PC). test_npcs "60 NPCs cost under 1 ms a tick", run alone, read 1.019 and 1.022 ms on dev 8b83b176, 1.036 and 1.031 on 95bb7530, and 1.036 and 1.039 on 00d407d5 (limit 1.00, load scale 1.00); it passed on David4 and would block the full pass before main. Cause: the goblin camp (entry 71) added three tribe NPCs and their three own markers; most of the test's NPCs (60, 63 with the tribe members) find no free chair on every 10 Hz step and each such claim scanned every marker, and each dormant tribe NPC worked out its anchor twice per player every tick. Fix: PR #1364, merged to dev at 763b8531 (head 0471044d) after independent review (PASS, no Must-fix or Should-fix findings): a claim reads only the markers of its kind (same order, so the same choice), and a dormant NPC's anchor and the tick's settings are read once a tick. The test and its limit are unchanged. Lane A on the exact head: test_npcs alone passed twice at 0.678 and 0.677 ms (the same step count on both runs), test_goblin_camp 0.113 ms at chores (dev 0.127); import 0 errors; 37 of 37 selected tests passed (35 fast, 2 timing), 0 script errors; warnings 381, identical to dev per file.

**Required outcome:** the server's NPC tick stays within its 1 ms budget for 60 NPCs on Dave's PC, with every NPC doing exactly what it did before.

**Acceptance:** test_npcs passes on Lane A run alone; nothing to see in play.

Moved to Fixed on 24 Nov 2026: a test or tooling fix with nothing for a player to check.

## 85. The warning check passed when a script did not parse (merge gate hole)

**Status: Fixed in dev - nothing to play (test tools only).** Not found in play: the coordinator, 20 Nov 2026, from Lane A (Dave's PC). A PR head had a parse error in tools/creature_check.gd. tools/check_warnings.gd runs under --debug, so Godot 4.7.2 stopped it at the local debugger's "debug>" prompt; it never printed its "scripts checked" line and hung to the 600 s timeout, and tools/check_warnings.sh still exited 0 with empty output, so tools/local_check.sh passed ("0 total"). Fix: PR #1365, merged to dev at d0aae1d3 (head 4f27e26d) after independent review (PASS on fb946102; delta PASS on 8a57768a and 4f27e26d). check_warnings.sh passes --ignore-error-breaks (no wait at the prompt), exits 2 when the check did not finish (no godot, timed out, no "scripts checked" line) and 3 when a script does not parse, named on stderr; check_warnings.gd names each script that loads invalid; local_check.sh fails on any of these, and its three-script parse check fails when godot cannot start or times out; --update-baseline refuses to write from a failed run. New self-test tools/test_check_warnings.sh (stub cases and a real-engine case on a broken script in a temp folder). tools/warning_baseline.txt is unchanged. Lane B (David4) on the exact head: the self-test all ok including both real-engine cases; check_warnings exit 0, 381 warnings; local_check PASS; 11 of 11 selected tests passed. Lane A on the exact head: the self-test exit 0 in 23 s; check_warnings exit 0 in 76 s; with the creature_check.gd parse error put back in the lane clone, exit 3 after 77 s, "script does not parse: tools/creature_check.gd", no hang (then discarded); local_check PASS; 11 of 11 selected tests passed.

**Required outcome:** a script that does not parse fails the warning check quickly and by name, on Windows and Linux; a check that did not finish is never reported as a pass.

**Acceptance:** `REQUIRE_GODOT=1 bash tools/test_check_warnings.sh` passes on both lanes; nothing to see in play.

Moved to Fixed on 24 Nov 2026: a test or tooling fix with nothing for a player to check.

## 87. The first look build cost check failed now and then on Lane A (test_look_build_cost flake)

**Status: Fixed in dev - nothing to play (no behaviour change you can see).** Not found in play: the coordinator, 20 Nov 2026, from Lane A (Dave's PC), where test_look_build_cost failed now and then and passed on a rerun, which tonight's gate does not accept. Cause, most likely (not measured apart): the saws are model looks, and the first build of each read its .glb file cold inside the timed build, 56 ms and 248 ms on Dave's PC against the 40 ms limit, 9 to 11 ms on later runs. Fix: PR #1371, merged to dev at c081b92a (head 3389f369) after independent review: BasicLook.warm_models() reads every model look's file ahead when the inventory looks are prewarmed at join (on the loader thread in a window, on the main thread headless), so the first build should no longer wait on the disk. The test reads them ahead the same way, checks that every model look's file was read ahead, and keeps the 40 ms limit; it now runs alone in the serial lane (tools/test_lanes.json). Lane B (David4) on the exact head: local_check PASS, 381 warnings zero new, 120 of 120 selected tests passed, 0 script errors, join smoke clean; test_look_build_cost alone 3 of 3 PASS, files read ahead in 19.6, 19.3 and 20.5 ms (3 files), slowest look plant_fibre 5.5 ms. Lane A (Dave's PC) on the exact head: test_look_build_cost alone 3 of 3 PASS, files read ahead in 31.2, 31.4 and 29.7 ms (3 files, every model look's file read ahead), slowest look plant_fibre 6.9, 7.2 and 6.9 ms, no saw among the slowest.

**Required outcome:** the first build of every item look stays under 40 ms on Dave's PC, with the cost of reading model files paid once at join, not in the middle of play.

**Acceptance:** test_look_build_cost passes alone on Lane A every time; nothing to see in play. In a window the read ahead runs on the loader thread, not yet seen on screen.

Moved to Fixed on 24 Nov 2026: a test or tooling fix with nothing for a player to check.

## 96. Picture rig character started high in the air, so the ground loaded slowly before it dropped to the spot

**Status: Implemented - debug tooling only; verified on Lane A, nothing for a player to check.** Dave, 20 Nov 2026, after watching the rig run on his PC: "the character is spawning way up in the air which causes ground loading to go slower and they eventually load in drop to the ground and then quit."

**Required outcome:** "they should start 1m above ground then face whatever it is they need to photograph and take the images."

**Cause:** the shot runner (src/debug/shot_runner.gd) held the body at 400 m above each spot until the ground there loaded, and only then put it at the shot height. --frametime started counting 10 s after joining, wherever the body was at that moment.

**As built (PR #1384, reviewed head 07a92b06, dev 51352924):**
- The runner asks the server for the ground height at the spot. It starts the body 1 m above that height (aerial shots over 40 m and absolute-height shots start at their own height), held so it cannot fall through ground that has not loaded. Once the ground under it has collision, the body moves to the shot height. The 400 m hold is deleted.
- Subject shots (--pieces, --look, --showroom and held items) also hide the plants, so a reed bed cannot block the subject.
- A plain spawn view faces the camp fire, the way a new character does.
- --frametime measures standing at the spot after landing, and look_rig.sh prints the frametime line itself.

This changes debug tooling only. There is no game, protocol, save or terrain change.

**Evidence:**
- Independent review PASS on 07a92b06.
- Lane B: 26 PASS / 0 FAIL, and warnings stay at 381.
- Lane A, windowed, 5 runs, all exit 0. Every start was about 1 m over the server ground (y 5.7 over 4.7), and every landing was 1.7 m over it. The camp fire, pieces, saw and showroom were visible.
- Remaining issues found by these runs, outside the rig: the spawn frame time had 4 frames over 100 ms (max 138.5 ms); two showroom pictures miss their items on the sandy slope at the new spawn (the framing was already like that before this change); and reeds stand in front of a new player's first view.

**Acceptance:** run tools/look_rig.sh at the spawn. The log shows "starts at y" about 1 m over the ground, then "landed", and the picture shows its subject. A --frametime run prints its frametime line from the script.

Not a game change; nothing to play.

Moved to Fixed on 24 Nov 2026: a test or tooling fix with nothing for a player to check.

## 119. The goblin camp is at the cave nearest the spawn

**Status: Replaced by entry 131 (the camp brings its own cave, PR #1456).** The camp no longer stands at 3,4#8006; the text below is history. Dave, 21 Nov 2026: "I think we should move the goblins cave much closer to spawn so people might actually find it. it should probably be right in the closest mountain or hill to the spawn point then we can make a path to it for players later." And: "include that before merging to main."

**What was found:** the Ragtooth camp sat at spring cave 3,4#8013, about 3.6 km north-north-west of the spawn. The nearest cave is 3,4#8006, about 1.6 km west-south-west. The nearer hills, about 1.2 km south and north of the spawn, have no cave.

**Required outcome:** the whole camp (cave, five goblins, props, stock, keep zone) at the nearest hill or cave to the spawn, nothing left at the old place, existing worlds loading with the camp at the new place. No path yet.

**As built (PR #1378, reviewed head e5846163, merged to dev at 1acec47b):**
- data/creatures/goblin_tribes.json: the camp moves to cave 3,4#8006, with its mouth at x 56560 z 71776 and its fire at x 56608 z 71800. The fire, Small chest, two Log benches, Drying rack, Tanning rack and the five goblins stand on a dry bench of 3 to 11 degrees on the brook's south bank. The bench is about 50 m south-east of the mouth. The wood and fibre points are on the slope 25 to 40 m further east. Every spot was read from the baked tile and is checked on it by test_goblin_camp.
- TileTerrainData.CAMP_CAVES keeps wild goblins and animal dens out of the camp cave. Without it, 8006 would hold a goblin band and a wolf den. 8013 is no longer reserved; by its id it holds neither, and the tile's always-goblins cave stays 3,4#8002.
- The new mouth is farther from the camp than angry_keep_m. A struck goblin running for the mouth now goes all the way in, and gives up after twice the run time plus 10 s. While in the cave it also counts a striker who waits at its camp spot, so it stays in until that striker goes.
- Existing worlds: the fire and props are laid by the server and never saved, so after a restart the camp is at the new cave and nothing is left at the old one. Standing, anger and the stock clock carry over per tribe.
- The test that the camp's stock carries over a server restart (entry 86) went in with it.
- Provisional: GOBLIN-19 in docs/design/GOBLIN_CAMP.md. A possible follow-up for Dave is a cave carved into the nearer hill about 1.2 km from the spawn; it needs cave carving, a TERRAIN_VERSION and a new starter cache.

**Evidence:**
- Independent review PASS on d9d5b30b, 948659f8, 6673aad0, d97be1f2 and e5846163.
- Lane B on 6673aad0: 268 pass / 1 fail. test_goblin_camp failed because Skritch stopped short of the mouth; this was fixed.
- Lane B on e5846163: 270 pass / 0 fail (260 fast, 8 timing, test_worldgen and test_bake_from_record), test_goblin_camp 0 failures. Warnings stay at 381, validate_items had 0 errors, all 340 looks are drawable, and the join smoke was clean.
- Tile 3,4's mines are identical before and after the move (a one-off Lane B check, print_tile_mines_3_4.gd in the project files: MINES 2 on both), so the version 79 starter cache stays valid.

**Acceptance:** walk about 1.6 km west and a little south from the spawn to the brook coming out of the hill. The Ragtooth camp is by the cave mouth, with the goblins at their chores. Strike one and they all run into the cave, staying in while you wait at the camp. Nothing is left at the old cave.

Not yet played.

Moved to Fixed on 24 Nov 2026: superseded by entry 131 (still in BugsList_Current.md), nothing left to play.

## 137. The fibre backpack did not show as something to take off

Tester DungeonMaster, build 9257, [QA #8](https://github.com/DSul3791/DynastyALWL-QA/issues/8) ("fibre backpack not appearing as unequippable"). The tester's "fibre backpack" was the Fibre - Shoulder bag, renamed Fibre - Backpack by Dave's ruling of 24 Nov 2026 (entry 143). Worn, it is listed on the Tab character screen's worn list with Take off, and its gear well opens it like any worn bag (CONTROLS.md). Closed 24 Nov 2026 with the rename; nothing else was found wrong.
