# Items data handover (Sal, 2026-10-31): one page for Dave

## Where everything is (all under data/items/ unless noted)
| Thing | File |
|---|---|
| Items (name, description, kind, stack, value, number; `future` = not obtainable yet; `retired` = kept for its number) | items.json (crafted/made things), gathered.json (picked wild things) |
| Recipes (needs, keeps, gives, station, `known`, `locked`) | recipes.json |
| Dishes (food points, shelf life, warmth) | dishes.json -> vitals.json (calories), spoilage.json, cooking.json |
| Weights, looks (grey placeholders until Kathleen draws them) | weights.json, looks.json, look_placeholders.json, look_wishlist.md |
| Crops and seeds | crops.json (14 crops, grow hours, seasons) |
| Fruit trees and fruit | items 431-449, drops.json `fruit_tree`, seasons.json `fruit_and_nuts` |
| Fauna loot, spawn plan, sign | carcass.json, data/animals/animals.json, spawn_plan.json, fauna_proposal.json, animal_sign.json |
| Fish | fishing.json, fish_schools.json |
| Shops and NPCs | data/npcs/shops.json (live), shops_proposal.json, town_proposal.json, dialogue_lines.json |
| Goals and hints | starter_goals.json, camp_goals.json, hints.json (36 lines) |
| Economy (values, coins, prices) | items.json `value` (copper), coins.json, ECONOMY_PLAN.md; test_economy_guard.gd keeps prices honest |
| Seasons and calendar | seasons.json |
| Structures and building pieces | structures.json, blueprints.json |
| Encyclopedia and voice descriptions | encyclopedia.json, descriptions_voice.json, item_uses.json |

## How to add an item (about ten minutes, by hand)
1. items.json: add the entry with the next `number` (`next_number` at the top), a name that is a plain noun, a description of 110 characters or fewer ending in a full stop, `kind`, `stack`, `value`. Add `"future": true` if players cannot get it yet. Never reuse or renumber a number; to remove one add `"retired": true`.
2. weights.json `by_id`: weight in kg. looks.json: a grey chunk row (copy another) and list the item in look_placeholders.json.
3. A recipe: recipes.json (next `number`, at most 3 kinds of ingredient; set `known: true` unless it is an advanced one). A food: add calories to vitals.json `food.by_id`, shelf life (game hours) to spoilage.json, and a `cooks_into` row in cooking.json if a fire cooks it.
4. Something picked in the world: a drops.json row (`harvest_yield`, `berry_yield`, `by_species` or a carcass part).
5. Run: `python tools/items_check.py --only validate_items,dishes,economy,server_items,first_hour,inventory,stations,save_compat` (the economy test fails any craft worth far more or less than its ingredients). Fix what it names.

## What is not finished
- Code owed by Tyler: ore tier check (CODE_MISMATCHES.md), hints on screen and camp events (HINTS_AND_CAMP_EVENTS_SPEC.md), learn-by-seeing already done, shop enabling, quality grades (QUALITY_GRADES_SPEC.md), crop planting UI.
- Art owed by Kathleen: the list in look_wishlist.md (about 90 items, building pieces, fruit, fish, clothes).
- Questions waiting for Dave: berry calories (FIRST_HOUR_FOOD.md), whether to slow the first hour further (CRAFT_PACING.md, FIRST_WEEK_WALK.md), the crop list, shop names (TOWN_NPC_SPEC.md).
- The log of every decision: ITEM_DECISION_LOG.md. The morning checklist: DAVE_MORNING_ITEMS.md.
