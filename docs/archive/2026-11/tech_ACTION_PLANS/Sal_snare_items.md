# Action plan: snare item (Sal, branch claude/sal-snare-items, build 796, pairs with Steve's claude/steve-hide-traps)

Items, one recipe and a structure row only; Steve's server_traps.gd does the catching. Label RESTART (new items and a structure kind, no code, no protocol change).

## Items (reserved from my block; next free is 276)
| # | id | kind | notes |
|---|---|---|---|
| 276 | snare | placeable (the kit in the pack) | "A loop of twine on a bent stick. Set it on a worn animal path." durability 20 (Steve wears it 1 per catch), value 6 |
| 277 | snare_trap | structure (the set snare in the world) | placed piece, takedown returns the `snare` with its wear |

## Recipe (next free 177)
| # | gives | needs | where |
|---|---|---|---|
| 177 | snare | 3 twine, 2 stick | by hand, known from the start (fine wood or lower, small gear: no bench; Dave's rule) |

## Structure row (structures.json "snare_trap")
kit snare, item snare_trap, next free world state 46, footprint 0.6 x 0.6, cap_per_chunk 12, sound "thump", clears_grass false, look "snare_trap" (stub: a bent stick and a small loop until Kathleen's art). Steve's plan reads the kind name `snare_trap`; he owns the per-player cap, rules for where it may be set and the catch.

## Hide items: nothing new
`hide` (item 43, "a raw animal skin") is what the carcass yields and what the quiver and the hide clothing recipes already take. A scraped-hide or rawhide item would be a second name for the same thing, so I add none (Dave's trim direction: no redundant items). If tanning is wanted later it comes with the tanning rack plan.

## Handoffs
- Steve: item id `snare` (276), structure kind `snare_trap` (277, state 46); catch rules and numbers in his data/animals/traps.json.
- Kathleen via the Moderator: names `snare`, `snare_trap`.

## Tests (David3)
validate_items 0 errors, a test_server_items case for recipe 177 by hand and a snare placed and taken back with its wear, test_craft_menu (next recipe 178), duplicate sweep, local_check 227.

## Ask
GO or changes, one reply.
