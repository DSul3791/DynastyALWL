# Playtest Repair Mission 001: trading and coins (TEST-003, TEST-002, TEST-009)

Dave's playtest findings of 12 Nov 2026 (project chat). Base: `origin/dev` b922cc88a59586dfbd41f806744d9ccedfe2bf26. Branch `claude/project-thread-el0p66`.
Other findings are in the sibling ledgers of this folder.

## Ledger

| Test | Status | Summary |
|---|---|---|
| TEST-003 Merchant silently stops buying | NEEDS PLAYER VERIFICATION | Cause found by reading the code (not reproduced in a running game). Fixed so every refusal is shown in the trade window. |
| TEST-002 Coin denomination order | NEEDS PLAYER VERIFICATION | Window coins and coin words now run gold, silver, bronze, copper (left to right). Unit test updated. |
| TEST-009 Unexpected coins during gathering | NEEDS PLAYER VERIFICATION | Source found: starter-goal rewards. Kept (designed rewards), now named on screen. |

Automated tests pass on Dave's PC (below); merged into `dev` by PR #1058 (merge 00d8f2a20a537ab1111cd8fac9de515042b86a25). Statuses move to VERIFIED FIXED only after Dave's play check (nothing here was seen on screen).

## TEST-003: cause

Two faults in the trade path, both silent to the player:

1. **Every trader answer was hidden.** The server answers each deal with a notice (`server_items._say`). The client draws notices on the HUD prompt line (`inventory_view._prompt`, centre of the screen). The trade window (`dialogue_view._build_shop`) is added to the same canvas layer later, covers 90% of the screen with a 95% opaque panel, and so is drawn over the prompt. "He cannot pay for that just now", "He has all the planks he wants today", even "Sold ..." were all invisible.
2. ~~Hob walks away with the window open.~~ **Withdrawn (13 Nov 2026).** Dave reported that Hob does not move at all, and he is right: `data/npcs/npcs.json` `test_hold` (its note: "Dave 2026-10-21, TEST") holds Hob at his post all day, and `server_npcs.package_of` returns the hold before the schedule and the rain shelter. Only the NPC-AI outage mode ("unwell", Hob walks to a chair) overrides it. The schedule reading was wrong. What remains true: `server_trade.deal` returned `""` (nothing said) whenever the player was over 4.5 m from the trader, which now gets a plain line.

The real buying limits exist and do replenish (no new restriction was invented):
- Purse: 300 copper cap, refills 100 copper per game day (one real hour) (`shops.json` hob `purse_cap`, `purse_regen_per_day`).
- Per-item daily limits for boards (`shops.json` hob `buy_rules`), refilling over the game day.
- Demand: each unit sold lowers his price for that item; it recovers 4 units a real minute (`coins.json` trade.demand).

Fix:
- `dialogue_view.gd`: a reply line in the trade window shows the server's latest notice while the window is open.
- `server_trade.gd`: the "Would you like to buy my extra stuff?" button says the refusal too, not "no extra stuff" (gate review finding 1); a spent purse says Dave's words, "I've bought all I can for now. Come back in a little while."; the board limit says "He has all the planks he wants for now. Come back in a little while."; out of talk range the deal says "You are too far from Hob to trade. Close this window and go closer." instead of nothing (first worded as "Hob has walked off", corrected 13 Nov 2026 because Hob does not move).


## TEST-002

`inventory_view.coin_text` and `fill_coin_line` drew copper first. Both now run richest first, matching the server's `_coin_words` and `coins.json` ("richest first"). Purse line, trade window, prices and tooltips all use these two functions. `test_coin_icons` checks the new order.

## TEST-009: cause

The only coin sources in the game are trade, a dead character's remains, dialogue `give_item` of a coin, and the starter and camp goals (`data/items/starter_goals.json`, `camp_goals.json`, paid by `server_items._goals_check`). There is no coin drop from trees, plants, stone or any harvest table.

The 5 copper while cutting a tree is a goal: felling the first tree completes "Fell a tree" (3 kindling), which opens "Light a fire" (5 copper). Goals count events from the start of the character, so a fire lit earlier completes it the moment the tree falls. In the same way "Gather plant fibre" pays 3 copper when the pack reaches 12 fibre, and "Make a Stone - Axe" pays 5 copper when twine is done and an axe is in the pack.

It looked like a find because the reason never showed: the pickup feed showed "+5 Copper coin" with no source, and the "Goal done" notice was replaced on the same frame by the "Next: ..." notice.

Fix (rewards unchanged): one notice per goal, "Goal done: Light a fire. You earn 5 copper. Next: ...", and the feed line reads "+5 Copper coin (goal reward)". `test_goals` checks the line. If Dave wants goals to pay no coin, that is a data change in the goal files, not done here.

## Tests

Selector (`tools/tests_for_diff.py origin/dev HEAD`): 171 fast, 3 timing, 1 pictures, wide because `server_items.gd` and `terrain_client.gd` are touched. The review commit also touches a comment in `terrain_net.gd`, which selects all fast and timing tests (path rule); it is comment-only. Scoped dev plan, agreed by the gate reviewer with three additions (TEST_GATES.md): `tools/local_check.sh` (parse check; the client edits have no headless test), `test_trade`, `test_trade_buy_rules`, `test_coin_icons`, `test_goals`, `test_mission001_walkthrough`, `test_wanted_order`, `test_earn_loop`, `test_first_town`, `test_dialogue`, `test_carrying`, `test_cooking_route`, the `always` set, and the PC start-up/world-load smoke through the client welcome (which builds the trade window). Deferred: the rest of the selection, to the next `tools/release_check.sh` run.

Results (Dave's PC ManlandRyzen5, 12 Nov 2026, worktree `E:/Software/godotDev/wt_trading` at exactly 1a0857f92790fe62c7c98bb580f9ee6830003d6e, Godot 4.7.2.stable.custom_build.ed1daf0bf voxel build, `run_tests.sh --jobs 2`):
- 22/22 PASS, 0 retries (the 11 named tests and the 11 of the `always` set).
- Import exit 0, 0 script errors. Client smoke (headless, separate APPDATA): welcome and ground ready, 0 script errors (exit 127 is the known headless-quit issue).
- `local_check.sh`: parse OK; FAIL on warning counts over `tools/warning_baseline.txt`, all pre-existing on dev and outside this change (server_items.gd 9 vs 8, the extra from 62395ee91; four other files not touched). The baseline is stale on dev.
- Outputs: `E:/Software/godotDev/wt_trading/_out/`. Deferred: the rest of the selector's 171 fast / 3 timing / 1 pictures, to the next `tools/release_check.sh`.
- Review: independent gate review PASS WITH NITS on ef1e947, findings 1-2 fixed, re-review PASS on 1a0857f. CI green.

## What Dave should check in play

1. Sell to Hob until he stops: the window says why (purse or "wants for now"), and his purse fills again after a while.
2. Purse and prices read gold, silver, bronze, copper from left to right.
3. On a new character, fell the first tree after lighting a fire: the line says "Goal done: Light a fire. You earn 5 copper." and the feed says "(goal reward)".

## Coins keep their denomination until a trader (Dave, 14 Nov 2026, PR #1140)

Dave, 14 Nov 2026 15:37Z: "I don't want my coins to automatically change denomination unless I am at a vender. so if I have gathered 200 copper I should have 200 copper until the next time I am talking to a vendor then It can redenominated it." This is the Class C basis for protocol 123.

Rule (the simplest, Dave may change it): the purse is the coins as held (`characters.json` `purse`). Opening a trader's conversation or shop, and every deal (the shop reopens), changes the purse into the fewest coins, richest first. Paying spends the smallest coins first and the change comes back as the fewest coins. Known limit: a dead character's remains store a copper number, so coins found on remains come back as the fewest coins.

Evidence at 4c3abd444f73036fba68225930f38a8f6ebb4695 (dev b034f2ef merged in): independent gate review PASS; CI merge-check green; lane B (David4) smoke PASS (import, parse, 4 coin/trade tests, 3 play-role smokes to ground ready, 0 script errors); lane A (Dave's PC) 383 fast + 8 timing: 389 pass, 2 fail, both failing on dev on that PC (test_world_items_cost, fix in PR #1144; test_flora_density timeout). Picture tests and on-screen checks not run. Status: NEEDS PLAYER VERIFICATION.

Dave should check: gather copper and see it stay copper; talk to Hob and see it become the fewest coins; buy something with mixed coins and get correct change.
