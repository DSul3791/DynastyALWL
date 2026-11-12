# Playtest Repair Mission 001: trading and coins (TEST-003, TEST-002, TEST-009)

Dave's playtest findings of 12 Nov 2026 (project chat). Base: `origin/dev` b922cc88a59586dfbd41f806744d9ccedfe2bf26. Branch `claude/project-thread-el0p66`.
Other findings are in the sibling ledgers of this folder.

## Ledger

| Test | Status | Summary |
|---|---|---|
| TEST-003 Merchant silently stops buying | NEEDS PLAYER VERIFICATION | Cause found by reading the code (not reproduced in a running game). Fixed so every refusal is shown in the trade window. |
| TEST-002 Coin denomination order | NEEDS PLAYER VERIFICATION | Window coins and coin words now run gold, silver, bronze, copper (left to right). Unit test updated. |
| TEST-009 Unexpected coins during gathering | NEEDS PLAYER VERIFICATION | Source found: starter-goal rewards. Kept (designed rewards), now named on screen. |

No Godot test has run yet for this change (cloud runs are forbidden; Dave's PC was in use). Statuses move to VERIFIED FIXED only after the PC tests and Dave's play check.

## TEST-003: cause

Two faults in the trade path, both silent to the player:

1. **Every trader answer was hidden.** The server answers each deal with a notice (`server_items._say`). The client draws notices on the HUD prompt line (`inventory_view._prompt`, centre of the screen). The trade window (`dialogue_view._build_shop`) is added to the same canvas layer later, covers 90% of the screen with a 95% opaque panel, and so is drawn over the prompt. "He cannot pay for that just now", "He has all the planks he wants today", even "Sold ..." were all invisible.
2. **Hob walks away with the window open.** Hob keeps a schedule (`data/npcs/npcs.json`: work, eat at 12:00 and 18:00, sleep from 21:00, rain shelter from `work`). A game hour is 2.5 real minutes, so he leaves his post every few minutes of play. The window stays open, and `server_trade.deal` returned `""` once he was over 4.5 m away, so the server sent nothing at all.

The real buying limits exist and do replenish (no new restriction was invented):
- Purse: 300 copper cap, refills 100 copper per game day (one real hour) (`shops.json` hob `purse_cap`, `purse_regen_per_day`).
- Per-item daily limits for boards (`shops.json` hob `buy_rules`), refilling over the game day.
- Demand: each unit sold lowers his price for that item; it recovers 4 units a real minute (`coins.json` trade.demand).

Fix:
- `dialogue_view.gd`: a reply line in the trade window shows the server's latest notice while the window is open.
- `server_trade.gd`: the "Would you like to buy my extra stuff?" button says the refusal too, not "no extra stuff" (gate review finding 1); a spent purse says Dave's words, "I've bought all I can for now. Come back in a little while."; the board limit says "He has all the planks he wants for now. Come back in a little while."; a trader out of reach says "Hob has walked off. Close this window and find them to trade." instead of nothing.

Not changed (would be new behaviour, Dave's call): Hob still keeps his hours while a player trades.

## TEST-002

`inventory_view.coin_text` and `fill_coin_line` drew copper first. Both now run richest first, matching the server's `_coin_words` and `coins.json` ("richest first"). Purse line, trade window, prices and tooltips all use these two functions. `test_coin_icons` checks the new order.

## TEST-009: cause

The only coin sources in the game are trade, a dead character's remains, dialogue `give_item` of a coin, and the starter and camp goals (`data/items/starter_goals.json`, `camp_goals.json`, paid by `server_items._goals_check`). There is no coin drop from trees, plants, stone or any harvest table.

The 5 copper while cutting a tree is a goal: felling the first tree completes "Fell a tree" (3 kindling), which opens "Light a fire" (5 copper). Goals count events from the start of the character, so a fire lit earlier completes it the moment the tree falls. In the same way "Gather plant fibre" pays 3 copper when the pack reaches 12 fibre, and "Make a Stone - Axe" pays 5 copper when twine is done and an axe is in the pack.

It looked like a find because the reason never showed: the pickup feed showed "+5 Copper coin" with no source, and the "Goal done" notice was replaced on the same frame by the "Next: ..." notice.

Fix (rewards unchanged): one notice per goal, "Goal done: Light a fire. You earn 5 copper. Next: ...", and the feed line reads "+5 Copper coin (goal reward)". `test_goals` checks the line. If Dave wants goals to pay no coin, that is a data change in the goal files, not done here.

## Tests

Selector (`tools/tests_for_diff.py origin/dev HEAD`): 171 fast, 3 timing, 1 pictures, wide because `server_items.gd` and `terrain_client.gd` are touched. The review commit also touches a comment in `terrain_net.gd`, which selects all fast and timing tests (path rule); it is comment-only. Scoped dev plan, agreed by the gate reviewer with three additions (TEST_GATES.md): `tools/local_check.sh` (parse check; the client edits have no headless test), `test_trade`, `test_trade_buy_rules`, `test_coin_icons`, `test_goals`, `test_mission001_walkthrough`, `test_wanted_order`, `test_earn_loop`, `test_first_town`, `test_dialogue`, `test_carrying`, `test_cooking_route`, the `always` set, and the PC start-up/world-load smoke through the client welcome (which builds the trade window). Deferred: the rest of the selection, to the next `tools/release_check.sh` run.

Results: see the PR.

## What Dave should check in play

1. Sell to Hob until he stops: the window says why (purse or "wants for now"), and his purse fills again after a while.
2. Keep the window open past noon or into rain: it says Hob walked off.
3. Purse and prices read gold, silver, bronze, copper from left to right.
4. On a new character, fell the first tree after lighting a fire: the line says "Goal done: Light a fire. You earn 5 copper." and the feed says "(goal reward)".
