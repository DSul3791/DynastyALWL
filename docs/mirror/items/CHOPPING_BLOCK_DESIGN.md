# Chopping block: design note (Items and crafting, 2026-10-20)

For Technical direction approval before code. Dave: "you can further process logs ... into firewood at a chopping block" (and into lumber at a saw mill, which waits for the building design).

## What it is
- A placed structure like the lean-to and chest: `chopping_block_kit` (placeable) crafted by hand from 1 log; placed with left click, ghost footprint 0.6 x 0.6 m, `structures.json` entry `chopping_block` (state 7, cap 4 per 256 m chunk, no roof, no slots).
- Taking it down with E returns the kit (never holds anything).

## Use
- Stand within 3 m with a usable axe on the hotbar, press E at the block: one log becomes 4 `firewood` (new stackable item, stack 40). Hold E repeats at the server pace (one split per 0.6 s). Each split wears the axe one use (existing tool wear). With no log: notice "You need a log"; with no usable axe: "You need an axe".
- `ACT_USE_STRUCT` (17), `a` = structure id. The server checks reach, log in the pack, axe, pace. Same message shape as the other ACT kinds, no new RPC.

## Firewood
- Fuel for fires: `cooking.json` fuel gets `firewood: 300.0` seconds (a stick is 120, a log 600); V adds the best fuel in the pack in the order firewood, stick, log... (the player chooses by what is in the pack; firewood first because it is made for it).
- Cooking and fire follow-ups are unchanged.

## Protocol and save
- New world-row state 7 (client draws a stump on end with a split-axe cut), new ACT kind 17: PROTOCOL_VERSION bump (next free).
- Saves ride in the existing world_items.json row (kind string "chopping_block"); no new file.

## Cost at Low
- No per-frame cost, no lights; about 30 triangles per block, only within 160 m; server work only on E.

## Not in this job
Saw mill (lumber, planks) needs the workshop and building design: planks, power, ownership. Tell me when that design exists. Splitting by hand without a block (a log on the ground) is deliberately not possible.
