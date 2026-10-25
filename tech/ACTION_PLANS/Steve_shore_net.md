# Action plan: shore net fishing (list step 9)

Branch: claude/steve-shore-net. Build 790, CHANGE_LABEL: RESTART (server action + data). Dave said yes: shore net, hand-made from 20 twine + 4 stones, stand at the water's edge, hold E about 20 s, 1 to 3 small fish, best at dawn and dusk. Builds on the fishing plan (design/FISH_AND_FISHING_PLAN.md, build order item G) but does NOT wait for the school module.

## What exists
Fishing is a server roll on a hidden stock per 128 m cell (fishing.json: stock 4-12, regrow 1 per 15 real min, species by water type, hour_mult 1.3 at dawn and dusk, rain/cloud/cold factors, fate() for luck). Rod and spear built. No net, no schools, no ripples.

## What I build (server + data, Sal supplies the item)
1. **Item and recipe (Sal):** `shore_net`, recipe 20 twine + 4 stones by hand, durability about 20 uses (wear 1 per use), added to data/items/open_recipes.json (see Steve_new_player). Needs an item number claim from Sal.
2. **Action ACT_NET** (new inventory_action kind, no protocol bump): `a` = pack slot of the net in hand, `at` = water point. Server checks: net in slot, water within net reach 5 m, water depth at the point 0.3 to 1.2 m (shore water; deeper or dry says why in one line), not frozen.
3. **Hold 20 s:** the server starts a `net` phase in the existing `_fishing` state (phase "net", started msec, spot, cell). The client holds E; moving more than move_cancel_m or letting go cancels with a line. After net_hold_s (20) the server rolls once: catches 1 to 3, limited by the cell's stock, chance and time-of-day from the same fishing.json factors (hour_mult already gives dawn/dusk 1.3), species from the cell's water type (`_fish_species`). Stock is used up per fish (a camper still cannot empty a pond). Raw fish go to the pack, net wears 1.
4. **Data (fishing.json "net" block):** reach_m 5, depth_m [0.3, 1.2], hold_s 20, catch [1, 3], wear 1, factors. No numbers in code.
5. **Feedback:** existing say lines (cast, nothing, "the water is still"), splash sound reused from the rod. Voice hint H18 ("Enough string for a net. Stones for weights.") comes with the hint engine, not here.
6. **Ripple spots: NOT in this plan.** Stock is hidden on the server; showing it needs the school module (fishing plan C/D). v1 uses the existing "the water is still" line when stock is low.

## Tests (test_server_items.gd)
Net refused without water, on deep water, when frozen; cancelled by moving; takes 20 s; catches 1-3 and never more than stock; stock goes down; net wears; dawn gives more than noon over 200 seeded rolls; deterministic with fate().

## Cost and risk
Server: one handler and one timer per netting player, nothing else. Risk: hold-to-act needs a client hold timer and a progress hint (text line first; a bar later). The client change is small (E held with a net in hand sends the action; release or move cancels).
Not run in Godot in the cloud.

## Build notes (24 Oct 22:50 UTC)
Built as planned. ACT_NET = 47 (46 is the water thread's Land types). Client: hold the left button with the net in hand (held_item.gd, tool_class "net"); release sends the cancel. Server: _net_cast / _net_haul in server_items.gd, phase "net" in the existing _fishing state, move cancel 2 m (fishing.json net.move_cancel_m). Data: fishing.json "net" block (all numbers and say lines); item shore_net number 260 (Sal had not supplied one: Sal, keep it or tell me a different number), recipe 163 (20 twine + 4 stone, craft_s 12, known by open_recipes.json), durability 20 (wear 1 per haul), weights 0.8, look cloth. Test: src/worldgen/tools/test_shore_net.gd, added to tools/items_check.py. Not run in Godot in the cloud: Mike please run test_shore_net.gd, test_fishing.gd, validate_items and local_check (expect 233).
Renumbered 24 Oct 22:40 UTC: recipe 160 clashed with the wooden hammer; shore_net recipe is now 163 (next_number 164), item stays 260.
