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
| Iron | Fine - Chest (unchanged otherwise) | 8 Hardwood board, 16 Iron nails or better, 2 Iron hinges | iron-tier hammer, Iron chisel | 36 |
| Steel | Ornate - Chest | 10 Hardwood board, 24 Steel nails, 2 Iron hinges, 2 Iron band | iron-tier hammer, Steel chisel | 48 |

"Or better": a need names the lowest metal it takes and any better metal serves, as the chisels do (wood_species.json ingredient_groups): copper_nails takes copper, bronze, iron or steel; bronze_nails bronze, iron or steel; nails (Iron nails) iron or steel; steel_nails steel only. bronze_hinges takes bronze or iron; hinges (Iron hinges) iron only. A cost spends its lowest member first and a taken-down piece gives the lowest back (ItemTable.spend_order).

Every other building and live recipe that took "nails" or "hinges" (iron or bronze) now asks for bronze_nails or bronze_hinges: the same metals as before, plus steel nails. Only the chests are tiered.

## Provisional picks (for Dave)
- CT-1: the copper chest is the **Small chest** (the Small / Medium / Large size words the gardening plots and resource bins use, beside the Large wooden chest). 24 slots: 27 would leave half a six-slot row, so it matches the Crude - Chest (a knife build of 4 boards, 8 wooden pins and 2 twine) and holds no more; what it adds is a hammer build with copper nails and no twine. A bigger Small chest, or a smaller Crude one, is for Dave. For comfort it counts as the crude grade of the chest family, so chests still count once. Cost 4 Hardwood board and 8 Copper nails, a lift-off lid with no hinges (there are no copper hinges).
- CT-2: Dave's "superior" chest is the existing **Ornate - Chest**: Ornate is the top furniture grade (Crude, Rustic, Fine, Ornate, [D4]); Superior is one of the seven building tiers. It now takes Steel nails and keeps its Iron hinges and Iron bands (no steel hinges exist). Whether the Large wooden chest or the Ornate chest is the bigger one stays an open question.
- CT-3: the Fine - Chest sits in the iron tier (Iron nails or better, Iron hinges); nothing else about it changed.
- CT-4: **Steel nails** (item 1513, recipe 750) are new: 1 Steel ingot makes 100 at the brick forge level 3, as other steel goods; value 2.
- CT-5: whether the nail tiers should spread to the other buildings that use nails (about 40: chairs, tables, cupboards, bins, the Raised cistern, the Sawmill and more) is Dave's call; they take bronze or better today.
