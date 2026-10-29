# Overnight self-tests (Dave 2026-10-23 05:00 UTC): the team runs these tonight, then STOPS. Dave checks back in the morning.
Rules: test head build 701 (or newer ready branches) on MikeW's SECOND clone C:\GodotProjects\DynastyALWL_test or headless, NEVER in Dave's pulled build or world. No merging into head while testing unless a test finds a real bug (then fix on a branch, tell the Guru). Each result is ONE line appended to tech/OVERNIGHT_RESULTS.md: `id: PASS` or `id: FAIL short reason (+ picture path if any)`. When your list is done, STOP. Nobody works on the daily list overnight. The Guru then posts Dave one "Finished:" card (Test done: N pass, N fail, short failures).
Tools: headless tests (res://src/worldgen/tools/test_*.gd), the look rig (claude/mike-look-rig: windowed game, item in hand, camera turned back to take stills), the admin showroom when Steve's version exists (else Admin give).
| id | test | owner (runs) | how |
| t01 block-hand | chopping block in hand and placed: same model, hand one about 30 percent, not cut off | MikeW + Kathleen | look rig stills, 2 pictures |
| t02 hoe-spade-row | 4 hoes and 3 spade sizes in a row at x 53301 z 68427 | MikeW + Kathleen | look rig or admin give, picture |
| t03 axe-bucket | stone axe wedge shape, bucket light wood with dark hoops | MikeW + Kathleen | picture |
| t04 hoe-hold | hold left mouse with wooden hoe: repeat every 0.55 s makes a line of path patches; right button smooths | Sal + MikeW | headless test then windowed picture |
| t05 collapse-natural | natural cave never shakes or collapses | Steve | test_tunnel_watch (add if missing) |
| t06 collapse-prop | timber prop within 5 m (timber set 7.5 m) stops shaking | Steve | test_tunnel_watch brace cases |
| t07 ladder | climb up, down, let go backwards, step onto the top edge | Steve + MikeW | headless or windowed |
| t08 admin-craft | Admin mode on: craft with empty pack; off: refused; E on a recipe crafts one | Sal + Steve | test_server_items, windowed E check |
| t09 reset-edits | dig, fill, Reset all terrain edits, confirm: holes gone, no errors | Steve + MikeW | second clone only |
| t10 rock-pile | 45 stones craft a rock pile; set down; E returns 45 stones; hold E carries the pile; rock_pile item 235 | Sal | test_placement_rules and windowed |
| t11 sea-drip | tunnel under the sea within 4 m of water drips; more than 4 m no drips; nothing collects | Steve | test_tunnel_watch (leak) and a windowed look |
| t12 torch-sound | torch in a cave: soft crackle, no loud echo | Kathleen | headless audio load + bus check |
| t13 rain | open rain without sharp clack; wooden roof rain clacky | Kathleen | headless weather_sounds load and bus check |
| t14 cave-in-timer | cave-in timer set to 2 min applies to running windows (falls about 2 min, or 90 s after the change if past) | Steve | test_tunnel_watch (already added) plus a run |
| t15 wood-chain | log on ground + axe = 4 blocks (shoulder log 12); block on chopping block = 1 firewood beside it; axe wear once per chop and once per split | Sal | test_placement_rules / server_items |
| t16 log-looks | oak log grey-brown, birch pale; shoulder log centred | Kathleen + MikeW | look rig stills |
| t17 safe-text | no "Womens Health" or "Mens Health" wording anywhere player-visible; raspberry tooltip reads "soothing" | Sal | grep data and src, one tooltip check |
| t18 local-check | full local_check, headless load, validators on head 701; warnings 233 | MikeW | tools/local_check.sh |
| t19 merge-guard | (Guru) tools/merge_check.sh first version runs on head | Guru | after the above, if time |
Dave's own words 05:00: "once he gets everything working you need to self test... do the tests you asked me for that are still in the QA overnight but stop working once they are done."
