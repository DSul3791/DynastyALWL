# Radar_001 handoff (read this first, Radar_002)

You are Radar, the "Items and Crafting" thread of Dave's medieval fantasy MMO "Dynasty a life well lived" (Godot 4.7.2, GDScript). Repo `DSul3791/DynastyALWL`, cloud checkout `/home/user/dynastyalwl`. You get instructions as coordinator relays quoting Dave. Dave talks by voice: keep posts short, end every post with "Still waiting on:". Never mention wakes, sessions or ids to him.

## Rules that always apply
- Work on your local branch, push with `git fetch; git rebase origin/claude/generator-v2; git push -q origin HEAD:claude/generator-v2`. Never touch main. The Stop hook's "unpushed commits" complaint is noise.
- Every push that changes the game claims a build number: read the tail of `/mnt/project-files/tech/BUILD_LOG.md`, take the next free number (others claim in parallel), bump `const BUILD` in `scenes/terrain_client/terrain_client.gd`, append a line to the log. Last mine: 588.
- New code must make ZERO GDScript warnings (no shadowing of members or base-class properties like `name`, `tick`, `action`, no unused params/vars, no integer division without `@warning_ignore("integer_division")`). Check with `PATH=/tmp/gbin:$PATH bash tools/check_warnings.sh --changed` (needs `godot` on PATH: `mkdir -p /tmp/gbin; ln -sf /tmp/claude/eng/godot /tmp/gbin/godot`). Without godot on PATH it prints 0 falsely. Run before every push.
- QUESTIONS RULE (Dave, 2026-10-22): every pickable-answer question for Dave goes ONLY in `questions/QUESTIONS.md` on claude/generator-v2 (format in `questions/README.md`), then you report "Question added: <title>". Never ask Dave a pickable question anywhere else (not in chat, not in a doc, not on a decision card).
- Do not chase bugs you cannot reproduce or see in a log (Dave: "chasing ghosts wastes my tokens"). Willy owns crash hunting.
- Pickable-answer questions for Dave go in `questions/QUESTIONS.md` (`## id | question`, then `- choice` lines, recommended first); answers land in `questions/ANSWERS.md`. Dave said the named starter-town cast was NOT wanted: Hob, Edda and the others are TEST DUMMIES. Keep NPC work generic and data-driven.
- Tests: `GODOT=/tmp/claude/eng/godot python3 tools/items_check.py --only name1,name2` (`--list` for names). Run a few at a time; the full run exceeds the tool timeout (use run_in_background). Client tests (quickkeys, eat, chest, gather) are slow and flaky under load.
- Item/recipe JSON files round-trip with `json.dumps(indent='\t', ensure_ascii=False) + "\n"`.
- Validator (`validate_items`): core items need a source or `"future": true`; descriptions at most 110 characters ending in a full stop; item names are plain nouns (no leading verb/article, so not "Roast roots").
- GDScript gotchas: lambdas capture local primitives by value (mutate captured arrays with append/clear); a script error in a headless test hangs the SceneTree (a test that "times out" usually has a signature mismatch: check every `send_*` lambda when a protocol signature changes); no duplicate variable names in a scope.
- A dev STOP from Dave was in force at 00:42 UTC 2026-10-22 (game crashes; Willy hunting). Check with the coordinator whether it has lifted before pushing.

## Who owns what
Steve = technical director (jobs in tech/JOBS.md, "Radar refill 11"); Mandy = art, animation, sound, voice; Willy = ground loading, performance, crashes, the warning checker; Sonny = water; Tyler = problem solver/cynic reviewer (FINDINGS.md). Items/crafting/survival/trade/animals/NPC design is mine. Never edit another thread's code except through a small agreed change.

## Done (builds 538-588, all pushed)
- 538/546/548 coins, reputation, trade (server_trade.gd); 548 trader demand tiredness (protocol 63).
- 555 inventory/hotbar rules (items go to the bag first, `Inventory.bag_from = 10`; hotbar only by player action; Use (E) on tool/blueprint moves it to first free hotbar slot; E over a hotbar item moves it to the bag), Tracking skill and `items.trail_mult`, felled-log lift.
- 558 species logs and the shoulder log (one big log carried at a time; protocol 64), lumber/beams data, 72 species wood items, 48 saw-mill recipes (saw mill station itself NOT built).
- 560 game-trail grid (server_trails.gd, trail_codec.gd, protocol 65).
- 562 wild and tame horses (species 7, per-animal `tame`), 565 species logs drawn full size.
- Balance sheet (`tools/balance_sheet.py` -> BALANCE.md), first-town loop test (test_first_town.gd, 20 steps).
- 575 NPC routines: schedule packages sleep/sit/work/eat/wander/shelter, markers in data/npcs/markers.json, rain shelter, test_npc_routines.gd. `test_hold` in npcs.json still pins Hob (work) and Edda (sit): delete it when Dave stops testing.
- 576 trader stock: finite shelf per trader restocked by game days, supply moves the price (full shelf 0.85x, empty 1.2x), trader purse caps what he pays, saved in `trade_state.json`; protocol 66 (`shop()` gains stock, supply_milli, trader_purse). Data: coins.json `trade.stock`, shops.json `stock_rules`, `purse_cap`, `purse_regen_per_day`.
- 578 fishing: chance cap 0.93 and "The water is still." when fewer than 3 fish left (Dave's answers to fishing-bait and fishing-hint).
- 582 tool repair: iron/steel tools need a forge nearby (`repair_station` in items.json); a smith mends worn/broken tools for coin (shops.json `"repairs": true`, coins.json `trade.repair.rate` 0.4; trade `deal` kind 2; client builds the "Mend" rows itself, no protocol change). `tools/tool_wear_sheet.py` writes items/TOOL_WEAR.md (minutes of steady work, smith price).
- 585 durability raised on the coordinator's word: stone axe ~30 min of steady work (900), wooden spear ~10 min (300), others in proportion. first_hour test fixed for the hotbar rule and species logs.
- 588 cooking variety: 17 campfire dishes from data/items/dishes.json via `tools/gen_dishes.py` (re-runnable; keeps numbers). Recipe station `"campfire"` = a lit fire within reach (server `station_near` special case, client mirror). More ingredient kinds = better dish. Validator now knows carcass parts and the campfire station. items/DISHES.md lists them. New test test_dishes.gd ("dishes").

## In progress / uncommitted
Nothing committed-but-unpushed. A warning cleanup of `src/stream/server_items.gd` (10 warnings) and `src/client/inventory_view.gd` (12) is saved as a patch: `/mnt/project-files/handoff/Radar_001_warning_cleanup.patch` (verified 0 warnings in both files, no behaviour change). Apply with `git apply` after rebasing (resolve if the files moved), re-check with `--detail`, claim a build number, push. Remaining warnings of mine at last count: test_server_items 64, test_dialogue 19, test_items_persistence 6, server_wolves 4 (also check my newer files: server_trade.gd, dialogue_view.gd, server_trails.gd, test_trade.gd, test_dishes.gd, test_first_town.gd).

## Open queue, in order (Steve's "Radar refill 11", tech/JOBS.md)
1. Warning cleanup in ONE build: the patch above plus the test files listed.
2. Player building basics: 3 to 5 structures, a placement framework, caps, versioned saves (existing: campfire kit, lean-to, chest in structures.json with `gap_m`, `cap_per_chunk`, `max_rise_m`; see `_place_structure` in server_items.gd and tests placement_rules/leanto). Banking coffers (placeable chest on owned land, design only) come after land ownership exists.
3. Armour and defence groundwork for boar/bear: damage reduction data, durability, weight; armour slots exist in clothing.json; hits go through the damage hook; tests. Boar/bear stay on hold until armour exists.
4. Clothing and warmth polish: wet clothes dry, layering, hat/gloves, warmth table.
5. Persistence drills and a 20-player stress refresh (coins, trade, horses, flocks, trails, wood, carry); report ms per tick and memory (tools: soak, test_items_persistence, STRESS_20_PLAYERS.md).
6. Follow-ups: count wolf pack members in trails; Tracking species-reading idea (proposal only in data/items/tracking.json); the saw mill station; delete `test_hold`; the gather client test flake (held-E pace check); horses taming/riding/harness and the logging sled/wagon are future (design only in DESIGN_IDEAS.md); tell Mandy voice ids and look needs if a new NPC is ever added.

## Decisions and why
- Banking (Dave answered): family coffers are placeable chests, cannot be raided, owned land only, only the owner opens, free remote use, offline deals can seal, coffers pass to the heir who becomes dynasty head. Design only.
- Three-ingredient recipes stay; more ingredients = better item. Money is a copper-total purse (10 copper = 1 bronze, 10 bronze = 1 silver, 10 silver = 1 gold); item `value` is copper. Reputation ranks Stranger 0, Known 2, Friend 5, Trusted 10.
- Wood: cutting a felled tree gives species-named logs; one large log on the shoulder at a time (Q lays it down); chopping block turns a shoulder log into 12 firewood.
- Trails: grass takes 5 real minutes to stand up; Tracking skill raises the player's own `trail_mult` (1.0 to 6.0). Game-trail grid is a server 4 m grid with decay, sent on tile entry (Mandy draws it).
- Natural wolves are OFF; tool exertion numbers kept; fishing 15 real minutes per fish per cell.
- Stranger trade multipliers: sells at 130%, buys at 55% before supply; charisma -10..+10 and luck 0.04/pt move prices.

## Traps
- Protocol changes: bump `PROTOCOL_VERSION` in terrain_net.gd, add a PROTOCOL.md entry, and update EVERY `send_shop`-style lambda in terrain_server.gd and tests (test_trade, test_first_town); a stale lambda hangs the headless test instead of failing.
- New player items land in the BAG (slot 10+), not the hotbar. Tests that assumed slot 0 must `Inventory.move` or use ADMIN_GIVE (which fills from slot 0). A client test (`eat`) still fails on a clean checkout ("roast eaten", "every tool ... held"): pre-existing, probably this bag rule; fixing needs the client test to move items to the hotbar. I changed its "edible slot" print only (not pushed, in the dropped diff).
- Build numbers collide: re-read BUILD_LOG right before pushing.
- Server restart is needed after server-side builds (576, 578, 582, 585, 588); no protocol change since 66.
- `first_hour` test: trunk now gives a species log on the SHOULDER; lay it down before crafting.
- Memory notes live in `/tmp/claude/memory/team/silo/` (index MEMORY.md); read it.

## What Dave is waiting on / owes
Nothing pending from Radar. He owes looks at builds 465-588 (list in memory). Open question page items: none from me (fishing answered; cast questions removed). Posted-and-finished for Dave: trader stock (576), fishing answers (578), tool repair (582), durability raise (585), dishes (588).
