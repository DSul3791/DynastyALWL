# Quality grades: data and rules spec for Tyler (Sal, 2026-10-31)

Dave's rule (ITEM_CODE_HANDOFF.md section 5): higher cooking tiers give better food, leather, gear, boats and carts; oven rung and maker skill set the grade; low rungs burn more often. Nothing is built; this spec fixes the numbers so the code job is small. Grades: **Poor, Normal, Good, Masterwork** (the moderator's four; the earlier five-grade idea Poor/Common/Good/Fine/Excellent is dropped to keep it simple).

## 1. Where a grade comes from
`score = skill_term + station_term + luck_term`, rolled once when a craft finishes (server, with the existing luck function).
- `skill_term` = (relevant skill level 0..100) / 100 x 0.6.
- `station_term` = 0.1 per station level above the recipe's minimum level, up to 0.3 (a better bench, forge, oven or tannery rack).
- `luck_term` = a random value in [-0.1, +0.1] shifted by the luck stat like other rolls.
Grade: score under 0.25 Poor; 0.25 to 0.6 Normal; 0.6 to 0.85 Good; 0.85 and over Masterwork. A fresh player (skill 1, minimum station) is Normal about 60 percent of the time and Poor 40 percent; Masterwork needs skill above 70 and a station two levels up.
Recipes that never carry a grade (graded = false): raw materials, kits, structures, fuel, seeds. Graded: tools, weapons, armour, clothing, shields, food (dishes and cooked meat), leather, boats, carts.

## 2. What a grade does (multipliers on the item's own numbers)
| Item kind | Poor | Normal | Good | Masterwork |
|---|---|---|---|---|
| Tool (durability, work speed) | durability x0.7, speed x0.9 | x1 | durability x1.25, speed x1.1 | durability x1.6, speed x1.2 |
| Weapon (damage, durability) | damage x0.85, dur x0.7 | x1 | damage x1.1, dur x1.25 | damage x1.25, dur x1.6 |
| Armour and clothing (warmth, protection) | x0.85 | x1 | x1.1 | x1.2, clothing wet_resist +0.1 |
| Food (kcal, warmth, shelf life) | kcal x0.85, shelf life x0.8 | x1 | kcal x1.1, warms +2, shelf life x1.2 | kcal x1.25, warms +4, shelf life x1.4 |
| Leather | counts as 0.8 of a unit in recipes (rounded down) | 1 | 1 and a Good leather item built from it | 1 and a Masterwork-capable material |
| Price (items.json value) | x0.7 | x1 | x1.3 | x2 |

Poor food still feeds; it never makes you sick by itself. Spoilage rules stay as they are (spoilage.json).

## 3. Burn chance for low cooking rungs (Dave's oven ladder)
Cooking at a Campfire burns a dish with chance 0.20 minus 0.15 x (cook skill / 100), Clay hearth 0.12 minus the same, Basic Oven 0.06, Clay Oven 0.03, Iron Stove 0.01. A burned dish is the Poor grade of the same dish at 50 percent kcal (not destroyed). Burn chance never goes below 0.

## 4. Data to add (small)
- recipes.json: optional `graded` (default true for the kinds above), optional `skill` (id from skills.json that sets the roll).
- items.json: optional `grade_stats` is not needed: the multipliers above live in one new file `data/items/quality.json` (keys: thresholds, skill_weight 0.6, station_step 0.1, station_cap 0.3, luck_range 0.1, multipliers per kind, burn per station).
- Inventory stacks: add a `grade` field (0 Poor, 1 Normal, 2 Good, 3 Masterwork); stacks merge only on equal grade; old saves read as Normal (save_compat). The `species` tag from the lumber spec uses the same slot mechanism, so build both together.
- UI: a coloured name suffix and one tooltip line ("Good: durability +25%").

## 5. Tests
test_server_items: a craft at skill 1 gives only Poor or Normal over 200 rolls; at skill 100 on the top station gives Good or Masterwork more than 80 percent of the time; multipliers apply to durability and kcal; stacks of different grades do not merge. save_compat: an old stack loads as Normal. Burn test: a campfire burns more than an oven over 500 cooks.

## 6. Open for Dave
Whether Poor items can be refused by shops (recommended: shops buy them at x0.7); whether Masterwork items get a maker's mark with the player's name.
