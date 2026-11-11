# Items data handover (Sal, 2026-10-31): one page for Dave

> **HISTORICAL (Jamie, 11 Nov 2026):** Sal's handover from 31 Oct. Its file layout is still mostly right, but it predates the building tiers, blueprint-only building, ingredient groups, bronze nails and bog iron. Current: `/mnt/project-files/handoffs/Jamie_handoff_11Nov.md` (data layout, id counters, naming rules) and `docs/design/item_system.md`.

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
- Code owed (rules code is Steve's now; see "Needs code" below and the *_SPEC files): ore tier check (CODE_MISMATCHES.md), hints on screen and camp events (HINTS_AND_CAMP_EVENTS_SPEC.md), learn-by-seeing already done, shop enabling, quality grades (QUALITY_GRADES_SPEC.md), crop planting UI.
- Art owed by Kathleen: the list in look_wishlist.md (about 90 items, building pieces, fruit, fish, clothes).
- Questions waiting for Dave: berry calories (FIRST_HOUR_FOOD.md), whether to slow the first hour further (CRAFT_PACING.md, FIRST_WEEK_WALK.md), the crop list, shop names (TOWN_NPC_SPEC.md).
- The log of every decision: ITEM_DECISION_LOG.md. The morning checklist: docs/archive/2026-11/DAVE_MORNING_ITEMS.md (archived).

## Needs code (from the archived `docs/archive/2026-11/ITEM_CODE_HANDOFF.md`, 30 Oct; checked 1 Nov by Jamie against data and Steve's and Sal's answers; owner of the code: Steve, tests Tyler)
Full detail of each item (files, steps, tests) is in the archived page.
1. **One Lumber and one Beam with a species tag** (Dave approved 25 Oct). Data side exists (`wood_species.json` has `key_woods`, `retired_to`); slot species tag, stack merge rule, save conversion and tooltip not verified.
2. **Clay Oven and Iron Stove** (oven levels 4 and 5): no such items in `items.json`; open.
3. **Vice migration**: `structures.json` still has vice rows; open.
4. **Quality grades** (Poor to Excellent): not built (`QUALITY_GRADES_SPEC.md`, Steve confirms).
Dropped as done: ingots and smelting recipes exist (`recipes.json` has 44 ingot lines; smelting levels not re-checked); the `kathleen-art` merge.
