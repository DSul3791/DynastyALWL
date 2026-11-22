# Chests by nail tier

Status: Dave's ruling 21 Nov 2026 (thread "Show which nails a recipe needs"), built the same day. The picks marked CT-n are PROVISIONAL for his review.

## Source
Dave, 21 Nov 2026 05:40Z: "we should have a chest size for each tier of nails. so copper nails can make a smaller chest with an appropriate name, then bronze makes the rustic, iron can make the large, and steel could make the superior. just use the same names we use on all other tiers whatever the convention is." Then: "fix it now".

Earlier rulings this builds on: Dave 15 Nov 2026 (copper, bronze and iron nails differ in strength; many things can use simple copper nails, stronger builds need bronze or better); Dave 18 Nov 2026 (chest slots in six-slot rows, each tier one more row); Dave 21 Nov 2026 (the Rustic - Chest needs no chisel).

## The ladder

| Nail tier | Chest | Cost | Hammer, chisel | Slots |
|---|---|---|---|---|
| Copper | Small chest (new, item 1512, blueprint 364, state 462) | 4 Hardwood board, 8 Copper nails or better | any hammer, no chisel | 24 |
| Bronze | Rustic - Chest | 6 Hardwood board, 12 Bronze nails or better, 2 Bronze hinges or better | any hammer, no chisel | 30 |
| Iron | Large wooden chest | 14 Hardwood board, 20 Iron nails or better, 2 Iron hinges | any hammer, no chisel | 42 |
| Iron | Fine - Chest (unchanged otherwise) | 8 Hardwood board, 16 Iron nails or better, 2 Iron hinges | Bronze hammer or better, Iron chisel | 36 |
| Steel | Ornate - Chest | 10 Hardwood board, 24 Steel nails, 2 Iron hinges, 2 Iron band | Bronze hammer or better, Steel chisel | 48 |

"Or better": a need names the lowest metal it takes and any better metal serves, as the chisels do (wood_species.json ingredient_groups): copper_nails takes copper, bronze, iron or steel; bronze_nails bronze, iron or steel; nails (Iron nails) iron or steel; steel_nails steel only. bronze_hinges takes bronze or iron; hinges (Iron hinges) iron only. A cost spends its lowest member first and a taken-down piece gives the lowest back (ItemTable.spend_order).

Every other building and live recipe that took "nails" or "hinges" then asked for bronze_nails or bronze_hinges; since Dave's later ruling the same day each one names the metal its use needs (see "Nails for every build").

## The knife's store (Dave 21 Nov 2026)
Dave, 21 Nov 2026 06:58Z, of the Wicker - Chest (18 slots) and the Crude - Chest (24 slots), both knife builds: "get ride of both of those. the knife can make a wicker basket that could have 6 slots." Asked about placed ones: "there are none".

- Neither is listed or built by a player any more. The Crude - Chest (blueprint 186, item 914, state 230) is retired. The Wicker - Chest (blueprint 26, item 23, state 6) is hidden and locked rather than retired, because about a dozen server tests place it as their plain container (place_piece builds free); taken down, it gives back its sticks and twine. A saved world holding either still loads it with whatever is inside (nothing clears it at load; Dave says there are none; test_save_compat checks it).
- The knife's store is the existing **Wicker basket** (was named Basket; item 785, blueprint 157, state 195): 8 Stick, 4 Twine, a knife, 6 slots (one row). It takes the Wicker - Chest's storage comfort point. No new numbers.
- The Ragtooth goblin camp's chest prop is now a Small chest (it was a Crude - Chest).
- The chest ladder is now Crate 10, Small 24, Rustic 30, Fine 36, Large wooden 42, Ornate 48.
- CT-6 (PROVISIONAL): the basket keeps its existing cost and name "Wicker basket".

## Nails for every build (Dave 21 Nov 2026)
Dave, 21 Nov 2026 17:53Z: "anything that uses copper cladding should use copper nails to attach the copper sheets. copper nails are also good for light duty connections like decorations or small light boxes and such. bronze are slightly stronger and bigger and better for stronger construction like chests, cabinets, upholstery, iron are stronger and great for construction and building strong boxes, etc. steel is the strongest and is best for fortification level strength like steel rivets and fortified doors etc. use judgement based on these suggestions."

Each cost names the lowest metal it takes; a better metal always serves ("or better", above). NT-1 (PROVISIONAL, Claude's judgement on his rules):

| Nails | Builds |
|---|---|
| Copper | Raised cistern (copper lined), Crate, the three gardening plots, Bottle and jar rack, Small chest, Quality - Backpack |
| Bronze | Rustic - Chest; Cupboard, Wardrobe, Dresser, Bookcase, Apothecary cabinet, Tool cabinet; Rustic, Fine and Ornate chairs and tables, Fine - Bench (upholstery); Barrel; Warehouse desk; Improved smithy, Improved smelter (kept bronze: they come before iron in the route, so iron nails would lock them) |
| Iron | Large wooden chest, Fine - Chest; Warehouse crate, Ore and metal rack, the three resource bins (strong boxes); Sawmill, Water wheel, Advanced smithy, Iron - Fence, Iron - Railing (construction) |
| Steel | Ornate - Chest; Fortified - Gate (new: 12 Steel nails as its rivets) |

Hinges (there are only bronze and iron): bronze for the Refined gate, the Sluice, chests, cabinets and the Improved smithy and smelter; iron for the Sturdy, Superior, Engineered, Iron and Fortified gates, the Advanced smithy and the iron-tier chests.

Stone-age pieces take no metal (coordinator GR-1 and GR-2, 21 Nov 2026, under Dave's questions rule): the Sawbuck is pegged with 16 Wooden pins (treenails) instead of 16 Bronze nails, and the Palisade gate hangs on 1 Rope (8 Log, 3 Twine, 1 Rope) with no hinges, so both come before any smithy.

## Provisional picks (for Dave)
- CT-1: the copper chest is the **Small chest** (the Small / Medium / Large size words the gardening plots and resource bins use, beside the Large wooden chest). 24 slots: 27 would leave half a six-slot row, so it matched the Crude - Chest (retired since, see above). A bigger Small chest is for Dave. For comfort it counts as the crude grade of the chest family, so chests still count once. Cost 4 Hardwood board and 8 Copper nails, a lift-off lid with no hinges (there are no copper hinges).
- CT-2: Dave's "superior" chest is the existing **Ornate - Chest**: Ornate is the top furniture grade (Crude, Rustic, Fine, Ornate, [D4]); Superior is one of the seven building tiers. It now takes Steel nails and keeps its Iron hinges and Iron bands (no steel hinges exist). Whether the Large wooden chest or the Ornate chest is the bigger one stays an open question.
- CT-3: the Fine - Chest sits in the iron tier (Iron nails or better, Iron hinges); nothing else about it changed.
- CT-4: **Steel nails** (item 1513, recipe 750) are new: 1 Steel ingot makes 100 at the brick forge level 3, as other steel goods; value 2.
- CT-5: answered by Dave 21 Nov 2026 17:53Z; see "Nails for every build" (NT-1).
