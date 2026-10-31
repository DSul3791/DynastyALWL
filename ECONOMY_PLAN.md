# Trade and economy plan (Sal, 2026-10-31)

Reads data/items/coins.json, data/npcs/shops.json and docs/mirror/items/COINS.md. Nothing in the data files was changed for this plan; it lists findings and a proposal. Price ratios are "real-world-ish" in the sense Radar set them (a hot meal about a day's small change, a day's unskilled labour 30 copper, a tool several days of labour); I did not research real historical wage tables.

## What exists
- Ladder: 1 bronze = 10 copper, 1 silver = 10 bronze, 1 gold = 10 silver. `value` in items.json is copper.
- Traders sell at 1.3 x value and buy at 0.55 x value (reputation, charisma and luck shift this); buying back never loses less than selling (min_sell 1.05 > max_buy 0.9); demand drops 3 percent per unit sold, floor 30 percent, recovering 4 points a minute; stock and purse limits per shop.
- One shop: **Hob's stall** (stone axe, stone knife, wooden spade, torch, twine, rope, plant fibre, bandage, waterskin, wooden bowl, backpack, roast forage, firewood, stone, stick). Buys materials, food, tools, containers, medicine, clothing and placeables. Purse cap 300 copper, regen 100 a day.
- 34 live items have no `value` (kits and structures such as lean-to, chest, workbench), so inventory sort and shops treat them as 2 copper.

## Findings from a value audit (value of what a recipe makes against the value of what it uses)
Ratios below 1 mean crafting loses money; very high ratios mean a trader would pay far more than the inputs.
- **Loses money:** all thatch kits (wall 10 against 139 of inputs: because thatch and twine are valued by item but the kits have no `value`), Bucket (3 against 54, lumber priced at 8 each), Rope, Rough bed, Waterskin, Grass cloak, Shore net. Cause: the kits have no value (counted as 2), and Bucket and waterskin are priced under their inputs.
- **Pays far more than inputs:** Wooden spear (12 for a stick), Wooden spade (15 for 2 sticks), Lumber (32 for 4), Rough plank, Kindling, and the dishes: Hearty pottage 195 for 14 of inputs, Trail bread 138 for 12, Forager's and Fish stew about 85 for 8 to 10, probably because dish values were set high and the herbs are cheap (cause not checked). A player could cook stew and sell it to Hob for a profit each time; demand decay (30 percent floor) and the purse cap (300 copper) limit it, but it is the largest exploit.

## Proposed pricing rule (for new and fixed items)
value = round(sum of ingredient values x tier factor), with tier factor 1.3 for hand recipes, 1.6 for workbench recipes, 2.0 for forge recipes, plus 1 copper per 4 seconds of craft time. Raw gathered goods stay at 1 to 3 copper. Food: 4 copper per 100 kcal for raw and simple roasts, 6 per 100 kcal for dishes with 3 ingredients, never above 2.5 times the ingredient value.
Fix list (data edits, not done): give every kit a value by that rule (lean-to 30 stays as the anchor), lift Bucket and Waterskin to about 1.3 times inputs, and lower Hearty pottage, Trail bread and the three stews to about 3 times inputs.

## First-island shops (proposal; only Hob exists)
| Shop | Sells | Buys | Why |
|---|---|---|---|
| Hob's stall (exists) | as above, add fibre_arrow, kindling, hide_glue | everything | general store |
| Fisher | fishing rod, shore_net, bone_arrow, salt (when it exists) | fish, seaweed, shellfish, crab meat, eggs | uses the shore foods (items 355 to 363) |
| Hunter | wooden_bow, wooden_arrow, stone_arrow, quiver, stone_spear | hide, feathers, sinew, bone, antler, claw, tusk, raw meat | feeds the animal drops (ANIMAL_SPEC.md) |
| Healer | bandage, herb_salve, splint | herbs, roots, comfrey, plantain, mushrooms | medicinal plants |
Each needs an NPC in npcs.json and a dialogue file (Mandy), then a shops.json entry in Hob's format (`stock`, `buys`, `stock_rules`, `purse_cap`). Start with purse caps of 200 to 300 copper.

## Prices for new items (already in items.json, copper; first look, not tuned)
Wool 5, linen 6, wool tunic 40, fur cloak 70, seal meat 5, seal steak 14, egg 3, boiled egg 6, shellfish 3, steamed shellfish 8, crab meat 4, antler 6, tusk 8, claw 6, down 3, quill 2. Bronze sword 70, iron sword 120, steel sword 250, plate cuirass 500 (steel sword in COINS.md is planned at 1500: our armour and weapon values are about a sixth of those anchors, so either raise by the factor or accept cheaper gear; recommend raising when forges exist).

## Open questions (my default in brackets)
1. Should shops buy cooked dishes at all? (yes, but cap the dish price rule above)
2. Should a trader's purse also limit buying stew? (yes, already by purse cap)
3. Should coin rewards for quests follow 1.5 to 2 times the goods (COINS.md)? (yes, unchanged)
