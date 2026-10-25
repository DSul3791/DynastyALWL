# Action plan: clay hearth and oven, cooking tiers 2 and 3 (Sal)
Branch claude/sal-hearth-oven (plan only until Tyler answers). Rules it follows: no benches for cooking (Dave 25 Oct 02:50), later tiers are hammer blueprints (build 800), first tier stays by hand.
## Today
- The clay hearth exists as a structure (structures.json "clay_hearth", state 39, items 256 kit / 257 piece, station "clay_hearth" level 2, cap 4 per chunk, a look in piece_look.gd) but nothing makes it and no dish needs it. The only craft stations for food are the campfire and the campfire pot. There is no oven.
## Proposal
1. **Clay hearth = a blueprint** (blueprints.json id 9): cost 10 brick, 6 clay, 4 stone; hammer tier 1; no station. Brick is recipe 128 (2 clay to 3 bricks at a campfire), so the chain is campfire -> brick -> hammer -> hearth. The old kit recipe does not exist, so there is nothing to retire.
2. **Oven = a new structure** (state 45, next free; structures.json "oven", footprint 1.8 x 1.4, cap 2 per chunk, station "oven" level 3) with a blueprint (id 10): cost 24 brick, 10 clay, 8 stone; hammer tier 1 and a clay hearth within reach (you build the oven next to the hearth you already cook on). New items oven 267 and oven_kit 268 (reserved now; the kit is only the takedown key, never craftable, never given). A look for it comes from Kathleen (I stub it with the hearth look, bigger and with a door box).
3. **Dishes get a station.** dishes.json gains an optional "station" ("campfire" default, "clay_hearth", "oven"); the stations are tiered, so an oven cooks anything a hearth does and a hearth anything a campfire does. A dish cooked at a better station gets food points x1.15 (hearth) or x1.3 (oven) and shelf life x1.25 or x1.5 (a clay hearth holds a steady heat). Existing 17 dishes unchanged at a campfire.
4. **New dishes** (3, numbers appended by gen_dishes.py): flatbread (seeds 3 + water 1, hearth), honey loaf (seeds 3 + hazelnuts 1 + honeyspindle nectar 1, oven), roast joint (raw meat 2 + rosemary 1 + wild garlic bulb 1, oven). All known from the start like the rest.
5. **No bench anywhere** in this chain. The camp bench stays tools and weapons.
## Not changed
No save format change (new structure kind and item numbers only, old saves load), no protocol change (the structure state 45 is a world item state drawn from the table: needs a one-line PROTOCOL.md note like 50 did for states 20/21), no ground change. Label RESTART.
## Tests (David3)
Blueprint cost and refusal tests as in build 1 for ids 9 and 10; oven refused without a hearth near; a dish refused at the wrong station and cooked at a better one with the multipliers; gen_dishes.py safe to rerun, duplicate sweep, validate_items, test_server_items, test_first_hour, local_check 233.
## Questions for Tyler
a. OK to put the hearth/oven cost and the 1.15 / 1.3 multipliers in as tunable data?  b. State 45 for the oven (check NUMBER_RESERVATIONS.md).  c. Items 267/268 reserved?
