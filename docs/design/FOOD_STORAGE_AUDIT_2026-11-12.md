# Food and storage cross-document audit, 12 November 2026

**Status: DOCUMENTATION AUDIT ONLY.** Written by Claude on PR #1035 in response to `CLAUDE_FOOD_STORAGE_HANDOFF.md`.

- Data was read only, from `dev` `7f8aabf4`: `data/items/*.json` and the code that reads them.
- No game file was changed and no Godot test was run. Every scenario below is a design walkthrough.
- `DYNASTY_MASTER_ITEMS.md` stays the single source of truth for approvals and totals. If this file and the master disagree, the master wins.

## 1. Conflicts found and fixes

| # | Where | Conflict | Fix |
|---|---|---|---|
| 1 | Master s6 row 46, s7 item 20 | These rows still recommended a **single** food-buff slot. That predates Dave's three-group rule [D16]. | FIXED. Both now describe three slots, one per food group. |
| 2 | Master s3.16, handoff | "Coffee" appears as an example drink. **No coffee item exists.** The drinks that do exist are Herbal tea 52, Stomach tea 57, Chamomile tea 58, Willow bark tea 59, Nettle tea 486 and Fruit juice 806. Milk 416 is FUTURE. | Already marked "once it exists" in s3.16. The scenarios below use Herbal tea. No change needed. |
| 3 | `vitals.json energy_aids` vs [D16] | **Existing rule (Dave, 21 Oct):** Energy bar, Herbal tea and Nettle tea give instant energy and **permanently remove Fitness training points** (`_fitness_cost`, down to `fitness_max_loss` 3 below the base). **[D16] says instead:** desserts give a *temporary* XP reduction, and drinks are a positive group. | **OWNER QUESTION 1** (s4). Nothing is changed here. |
| 4 | [D16] food groups vs data | No food row has a group or tier field. `dishes.json` already sets dish quality by **number of ingredient kinds**: 2 kinds ≈ 350–450 kcal, up to 5 kinds ≈ 1050–1200. | RECOMMEND: a hand-set `food_group` on each of the 115 live food rows. Tier follows the existing ingredient-kind count. Examples of rows that need a deliberate choice: Fish pie (Main or Bread), Hearty pottage (Main), Baked potato (Bread & Grains, per s3.16), Apple pie (Dessert), Energy bar (Dessert). |
| 5 | [D16] XP rule vs the Rested buff | `comfort.json` Rested already has `skill_gain_mult` (1.0 today) with a one-tier, refresh-never-stack rule. [D16] says "strongest single food XP bonus". It does not say how that combines with Rested. | RECOMMEND (tuning sheet s3): the food bonus and the Rested bonus **add** together, with one cap, and never multiply. |
| 6 | [D16] Fitness timing | `fitness.json` earns XP every 10 s into `xp_today` and pays it out at midnight. | PASS. Multiplying at the 10 s tick matches [D16], and the payout needs no change. |
| 7 | Maturing jars | Companion s2 now says to *prefer* one food ID with a maturing state. The live spoilage clock instead converts **items** at full age. | CONSISTENT. Both options and their trade-off are recorded. The choice is left to the implementation review. No ID is added. |
| 8 | Storage, desk vs locks | Checked master s3.13, the storage companion, `INVENTORY_CRAFTING_LOOK.md` s14 and the handoff. | PASS. Every document says the owner gets in without a code, the desk owner gains nothing, codes are per container, and the 10/20/30/40 s wait is shared across interfaces. |
| 9 | Board counts | Checked master s3.15, the food companion, the UI doc and the handoff. | PASS. All say nine boards (8 ADD and Ploughman's FUTURE) plus 1 Serving Platter, with no Roast Beef board. Totals are ADD 174 and 4 new FUTURE. |
| 10 | Placed Preserving jar 830 | Six live recipes are made at the placed jar 830: sauerkraut, jam, compote, apple sauce, damsons and pickles. Portable jars will mature on their own. | **OWNER QUESTION 2** (s4). |

## 2. Scenario walkthroughs (design only)

| Scenario | Expected under the documents | Result |
|---|---|---|
| Rosemary joint, then Flatbread, then Herbal tea | Main Meal, Bread & Grains and Beverage: three slots, three timers. Only the joint's Fitness XP bonus counts. | Consistent. |
| A second roast while the joint is active | Same group: the new roast replaces the joint's effect and timer. | Consistent. |
| Apple pie while three groups are active | Dessert is a fourth group. The player chooses which slot to replace. | Consistent. Also needs owner question 1 settled for desserts. |
| Eat a roast at 23:59 after a day of running | `xp_today` was earned without the bonus, so nothing applies retroactively. Only ticks after eating are boosted. | Consistent with `fitness.json`. |
| Read an NPC tip, then eat the suggested meal | Same effect as eating it without the tip. The tip only reveals information [P17]. | Consistent. |
| Owner shares code 0042, then a friend guesses wrong 3 times | The friend gets into that crate only. Waits of 10, 20 and 30 s, kept across the crate and the desk. A correct code resets the count. | Consistent across the three documents. |
| Loaded crate: Warehouse A → wagon → ship → Warehouse B | Same crate, contents, owner and code. Desk A loses it, then the ship table sees it, then Desk B. Food keeps ageing on the way. | Consistent. Depends on the movable-container code ([D9], [D11], [D13]). |
| 200 jars of sauerkraut | Needs 200 real jars, cabbage and salt. They are Maturing until their age is reached, then Ready, wherever they are stored. | Consistent. Representation is left open (item 7). |
| Roast Platter placed and eaten | Each serving removes a real portion. The display empties, and the leftovers keep their age. | Consistent. Portions can use the stack count and age (`spoilage.json`). |

## 3. Suggested tuning sheet: Claude's proposal, NOT owner-approved

Times are in game hours. One game hour is 2.5 real minutes.

| Group | Tier 1 (1–2 kinds) | Tier 2 (3 kinds) | Tier 3 (4+ kinds, boards) | XP |
|---|---|---|---|---|
| Main Meal | 2 h | 6 h | 12 h | Fitness XP +10 / +15 / +20 %. A Tier 3 balanced board may instead give all-skill XP +10 %. |
| Bread & Grains | energy drain −10 % for 4 h | −15 %, 8 h | −20 %, 12 h | none |
| Fruit & Vegetables | health regen ×1.05 for 4 h | ×1.10, 8 h | ×1.15, 12 h | none |
| Dessert | +8 energy at once | +12 | +15 | −5 % XP for 1 h |
| Beverage | exertion recovery +5 % for 2 h | +10 %, 4 h | — | none; medicinal teas keep their cure |

**XP combination rule:**
- Take the single best food XP bonus, subtract any dessert penalty, then **add** Rested's `skill_gain_mult − 1`.
- Cap the total at +25 %.
- Apply it at the moment XP is earned.

## 4. Owner decisions still open (Dave)

1. **Energy aids vs [D16].** Do Energy bar, Herbal tea and Nettle tea keep their 21 Oct rule (instant energy, with a *permanent* loss of Fitness training points)? Or does [D16]'s temporary dessert XP penalty replace that rule, with teas becoming a positive drink group? *Recommendation:* replace it with [D16]. That keeps one food-effect rule.
2. **Placed Preserving jar 830.** Either keep it as a bulk crock that also matures on its own, or move its six recipes to the Food Preparation Table and retire it. *Recommendation:* keep it as the bulk option, with the same maturing rule.
3. **Preservation roster [P14-v2]:** approve, change or reject the five rows (Sealable Preserve Jar, Smoked Meat, Dried Mushrooms, Dried Herbs, Cured Olives). *Recommendation:* approve all five. None duplicates a live row, and the jar fills a real gap.
4. **Nutrition guides [P17]:** whether to add any guide book items, or keep tips in NPC dialogue only. *Recommendation:* dialogue only for now, so no new rows.
5. **Tuning numbers:** accept, change or defer the s3 sheet.
