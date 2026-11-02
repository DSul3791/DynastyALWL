# Dino round 4 (2 Nov 2026, paper review on main): in-game hints left behind by the 2 Nov fire and felling changes

Nothing in game data was changed (hints.json is Sal's). These hints now tell the player to do the wrong thing.

| Hint id | Trigger | Text today | Problem | Suggested text |
|---|---|---|---|---|
| fuel | fire_lit | "Press E at the fire to add sticks or wood." | Since #32, E on a burning fire **puts it out**. A new player following the hint loses their fire. | "Press F at the fire to put wood in. E puts it out." |
| roast | hungry | "Hold E at the fire to roast raw meat or fish." | Hold-E roasting was removed in #32; food cooks in the fire's store. | "Put raw meat or fish in the fire with F. It cooks while the fire burns." |
| trunk | tree_down | "Keep striking the fallen trunk for sticks, leaves and logs." | Since #39 and #49 the trunk breaks up by itself about 2 s after landing. | "Your tree has broken up. Pick up the sticks, leaves and logs with E." (Dave's choice pending on QA card tut-fell-line) |
| cook_rule, berries, starter goal "berries" hint | near_fire_with_food, hungry | "Roast raw meat on the campfire..." / "Roast meat." | Still true as a rule, but "roast" now means "put in the store". Low priority. | Leave, or "Cook raw meat in the campfire (F)." |

Severity: **fuel is high** (it makes the first fire go out), roast medium, trunk low. Suggested owner: Sal (text), Steve to confirm the control wording. `tools/text_vs_recipe.py` cannot catch these (it checks numbers, not controls).

Guides I updated in the same PR: PLAYTHROUGH_GUIDE (kit laid with a stick in its store; removed the stale CONTROLS note), MORNING_PLAYTEST_CHECKLIST_FULL row 13, PLAYTHROUGH_WILDLIFE cook row, PLAYTHROUGH_STEP_STATUS rows 14 and 20 (bench is 16 sticks).
