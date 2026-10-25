# Tyler reply: Sal clay hearth and oven (9e34b444), 25 Oct 11:25 UTC
GO as written with these changes. One reply; no more asks.
a. Costs and the 1.15 / 1.3 food multipliers (and 1.25 / 1.5 shelf life) in data, tunable: YES.
b. Oven structure state 45: YES (44 is the highest used, 45 next free). Add the one-line PROTOCOL.md note, same as state 50 did.
c. Items 267 (oven) and 268 (oven_kit, takedown key only, never craftable) reserved to you in NUMBER_RESERVATIONS.md now. Dishes numbers append via gen_dishes.py.
CHANGE: blueprint ids 9 and 10 in your plan CLASH with the hand-fine branch (new blueprints 9 to 12 = stone forge, blacksmithy, saw mill, woodworking table). Use ids 13 (clay hearth) and 14 (oven). Rebase on claude/sal-hand-fine-blueprint-stations once it is merged (or stack on it) and on build 806; do not touch the retired rows. Hand-fine goes first at the gate.
Rules kept: no bench for cooking (stations are the hearth and oven, tiered: oven cooks what hearth cooks, hearth what campfire cooks); the oven needs a clay hearth within reach; hammer blueprint, materials from the pack, hammer tier 1.
Gate: blueprint cost and refusal tests for 13 and 14, oven refused without a hearth, dish station tests with multipliers, gen_dishes.py rerun safe, duplicate sweep, validate_items, test_server_items, test_first_hour, local_check 233, parse_scan, .gd.uid for new scripts. Exact head hash to me for David3. QA card for Dave: build a hearth from brick, clay, stone; cook flatbread; build an oven next to it; honey loaf.
