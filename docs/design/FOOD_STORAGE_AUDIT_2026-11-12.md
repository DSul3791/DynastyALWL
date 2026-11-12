# Food and storage cross-document audit, 12 November 2026

**Status: DOCUMENTATION AUDIT ONLY. Its s5 questions were all resolved by Dave's [D17] decisions (12 Nov 04:49Z); see the master catalog and `CATALOG_FINAL_AUDIT_2026-11-12.md`. Kept as the record of rounds 1 to 4.** Written by Claude on PR #1035 for `CLAUDE_FOOD_STORAGE_HANDOFF.md` and Dave's 12 Nov consolidation request.

- Data and code were read only, from `dev` `7f8aabf4`: `data/items/*.json`, `inventory.gd`, `recipe_table.gd`, `craft_stock.gd`, `src/stream/server_items.gd`, `PROTOCOL.md` and `tools/gen_dishes.py`.
- No game file was changed and no Godot test was run. Every scenario is a design walkthrough.
- `DYNASTY_MASTER_ITEMS.md` is the single source of truth for approvals and totals. Where this file and the master disagree, the master wins.

**Approval key:**
- **Approved:** an owner decision [D#], or ChatGPT on Dave's behalf [C].
- **Recommendation:** Claude's proposal. For ChatGPT to confirm, or for Dave when it touches an approved item.
- **Pending:** [P14-v2] and [P17], which wait for Dave.

## 1. Conflicts found and fixes made

| # | Topic | Conflict | Fix in the documents |
|---|---|---|---|
| 1 | Food slots | The master s6 row 46 and s7 item 20 still recommended a single food-buff slot. | Both now describe three group slots, as [D16] says. |
| 2 | Board roster | Master s3.13 still called the platter roster unapproved, and `item_system.md` cited only [D1]–[D13]. | Both now say: nine boards and the Serving Platter approved [D15], only [P14-v2] pending. |
| 3 | Open questions | Master s8 said "Design questions open: none" and referred to "two pending rosters" [P14]. | s8 now points to this file's s5 and lists the new food, storage and animal systems. |
| 4 | Tags | [P14-v2] and [P17] were not defined. The companion list omitted this file and the handoff. Some places still used [P14]. | Tag rows and links added. [P14] replaced with [P14-v2]. |
| 5 | Stale notes | Several old "next category" lines, s6 row 28 ("food untouched") and row 39 (Hide - Trousers) predated later decisions. | Marked historical or corrected. |
| 6 | Maturing | The docs said jars mature by plain elapsed time, then praised reusing the spoilage clock. That clock is scaled by place and season, and the only built transition is to rotten food. They also described both new `Maturing X` IDs and no new IDs. | One working representation in master s3.14 and companion s2: same food ID plus a `ready_age` against the existing age. Place and season scaling is stated. Plain elapsed time would need a new field. |
| 7 | Transit ageing | The docs said food keeps ageing on carts and ships. Today ageing covers all saved packs, placed containers and ground items, but not cargo. | Recorded as needed code: cargo joins the ageing loop, plus `place_mult` rows for new containers and cargo. |
| 8 | Slot state | Boards keeping portions and freshness, and jars returning a vessel, were assumed. A slot holds only number, count, `wear` and favourite, and eating returns nothing. | Board stack count = portions; shelf life fixed at assembly. A jar return on eating is needed code. |
| 9 | Board group | "A complex board is a Main Meal" was worded as owner text. It would let the Dessert Platter escape the dessert penalty. | Marked PROPOSED: Dessert Platter → Dessert, Harvest Platter → Fruit & Vegetables, the other seven → Main Meal. |
| 10 | Drinks | "Herbal tea" was used as a Beverage example. Medicinal teas are refused unless the player is sick. Herbal and Nettle tea are energy aids, refused unless tired, and they permanently cost Fitness training. No coffee exists. | Facts added to master s3.16. Scenarios use Fruit juice 806. The energy-aid conflict is owner question 2. |
| 11 | Rested | The audit said Rested `skill_gain_mult` is "1.0 today". It is 1.00–1.10 by tier, for skill practice only, never Fitness. | Corrected. The combination rule is now only in the tuning sheet (s4). |
| 12 | Nesting | "A container never goes inside another container" clashed with sacks and crates carried on wagons and ships. | One rule (master s3.9): vehicles and holds carry whole container objects in cargo positions, never in item slots. Their full mass counts. |
| 13 | Large chest | Recommended "more slots than Ornate", but every inventory is capped at 30 slots and Ornate has 30. It was also left "for ChatGPT", although it is a Dave-approved row. | The cap is recorded, and the row became owner question 3. |
| 14 | Lockout clock | "Monotonic clock" does not survive a server restart. | Changed to a saved wall-clock deadline per character and container, as Rested does. |
| 15 | Contracts | No doc said that locks, codes, the desk view, loaded crates, food slots or portions need new protocol actions and save fields. | Added to master s3.13, s8 and the storage companion. |
| 16 | Names and counts | "Energy bar" is the id `energy_bar`; the item is Nut cake. The food rows are 108 live, 7 FUTURE and 1 retired, not "115 live". | Corrected. |
| 17 | Lock icon | The older "keep out" tick (exclude from crafting) shared the lock icon with the code lock. | Noted as two separate settings with two icons. |
| 18 | Guides | The [P17] sample advice ("fish + fruit + tea for long study") promised effects that do not exist. | Marked illustrative. Final guide text must use real effects. |

**Checked and consistent:**
- Totals:
  - ADD 174 = 18 + 6 + 29 + 14 + 17 + 9 + 20 + 13 + 23 + 16 + 9.
  - 4 new FUTURE rows.
  - Existing rows 889.
- Nine boards: Ploughman's is FUTURE, and there is no Roast Beef board.
- Lock rules in four documents: owner access without a code, the desk grants nothing, codes are per container, waits of 10/20/30/40 s with no cap, persistent across interfaces.
- Three slots by group.
- XP is applied when earned, not at midnight.

## 2. Recommendations for ChatGPT

These are recorded in the master with "for ChatGPT". None removes approved function.

1. **Food Preparation Table:** built from logs and twine, so bread stays pre-metal.
2. **Hand recipes:** Nut cake and Fruit juice move from hand to the Table.
3. **Egg dishes:** Herb omelette and Egg-nettle fry move to the Clay Griddle or the Iron Frying Pan, not the Pan alone, so eggs avoid an iron gate.
4. **Meatballs:** Uncooked Meatballs goes live together with Meatballs #837, made at the Campfire Pot or Pan. The count stays 174.
5. **Maturing representation** as in fix 6. Also decide whether crafted food inherits its oldest ingredient's age; today it starts fresh.
6. **If the jar is approved:** move the six placed Preserving Jar #830 recipes to the Table with jars, and retire #830.
   - Compote, apple sauce, plum jam and damsons get a heated pot step [D14].
7. **Board representation, and board groups** as in fix 9.
   - NPC diners are FUTURE, because no NPC hunger exists.
   - The Serving Platter gets a pre-saw wooden recipe.
8. **Locked containers:** only the owner or a player with access may lift, load or take down a locked container. Sourcing never bypasses a lock.
9. **Warehouse Desk:** covers a stated radius or its building. Where a desk and a Storage sign cover the same crate, the desk takes priority, so Dave's one-context rule holds.
10. **Crate #850** keeps everything. The Warehouse Crate earns its row as heavier, stackable, ship-rated freight.
11. **Bookcase:** holds general small items until book items exist. No book, map or scroll item exists today.
12. **Bulk storage accepts separate sets:**
    - Open Storage Bin: clay, sand and charcoal.
    - Ore & Metal Rack: ore, ingots and worked metal.
    - Mason's Pallet: stone blocks and bricks.

## 3. Scenario walkthroughs (design only)

| Scenario | Expected under the documents | Result |
|---|---|---|
| Rosemary joint, then Flatbread, then Fruit juice | Main Meal, Bread & Grains and Beverage: three slots, three timers. Only the joint's Fitness XP bonus counts. | Consistent. |
| A plain roast while the Rosemary joint is active | Same group. Under the tuning sheet the player is asked before a weaker effect replaces a stronger one; otherwise it is calories only. | Consistent with [D16] "same group replaces". The prompt is a proposal. |
| Apple pie while three groups are active | Dessert is a fourth group, so the player picks a slot to replace. The XP penalty has its own timer, which a later replacement does not clear. | Consistent. The separate penalty timer is a proposal (closes an exploit). |
| Roast eaten at 23:59 after a day of running | `xp_today` was earned without the bonus. Only later ticks are boosted. | Consistent with `fitness.json`. |
| An NPC tip, then the suggested meal | Same effect as without the tip [P17]. | Consistent. |
| Owner shares code 0042; a friend fails 3 times | Only that crate opens. Waits of 10, 20 and 30 s are kept across crate and desk and survive reconnect. A correct code resets the count. | Consistent in all four documents. |
| A stranger tries to lift a locked, loaded crate | Refused (recommendation 8). | Gap closed by recommendation. |
| Loaded crate: Warehouse A → wagon → ship → Warehouse B | Same crate, contents, owner and code. Desk A loses it, then the ship table sees it, then Desk B. | Consistent. Ageing in transit needs cargo in the ageing loop (fix 7). |
| 200 jars of sauerkraut | Needs the [P14-v2] jar, 200 jars, cabbage and salt. That is about 20 stacks, and a batch-size mechanic. Maturing until `ready_age`, then Ready. | Consistent, **if the jar is approved**. |
| Roast Platter eaten portion by portion | Each portion removes one from the stack and refreshes the Main Meal effect without stacking it. Leftovers keep their age. | Consistent with recommendation 7. |

## 4. Suggested tuning sheet (accepted by Dave as initial playtest values [D17]; master s3.16 is now authoritative)

Times are in game hours (1 game hour = 2.5 real minutes). Tier follows the existing `dishes.json` count of ingredient kinds:
- T1: 1–2 kinds.
- T2: 3 kinds.
- T3: 4 or more kinds, and boards.

The hooks reuse existing multiplier fields (`regen_mult`, `exhaustion_mult`, `hunger_thirst_mult`, `skill_gain_mult` in `comfort.json`). A food multiplier in the Fitness tick, and instant energy from ordinary food (today only energy aids give it, and only when tired), are new code.

| Group | T1 | T2 | T3 | Hook |
|---|---|---|---|---|
| Main Meal | Fitness XP +10 %, 2 h | +15 %, 6 h | +20 %, 12 h; a balanced T3 board may give all-skill XP +10 % instead | `fitness` tick and skill `practice`. Red-meat and hearty mains also get `regen_mult` ×1.05 / ×1.10 / ×1.10. |
| Bread & Grains | energy drain −10 %, 4 h | −15 %, 8 h | −20 %, 12 h | `exhaustion_mult`. No XP. |
| Fruit & Vegetables | health regen ×1.05, 4 h | ×1.10, 8 h | ×1.15, 12 h | `regen_mult`. No XP. |
| Dessert | +8 energy at once | +12 | +15 | XP −5 % for 1 h, on its own timer. |
| Beverage | hunger and thirst drain −5 %, 2 h | −10 %, 4 h | — | `hunger_thirst_mult`. No XP. Medicinal teas keep their cure and take no slot. |

**Rules:**
- **XP:** take the single best food XP bonus, then subtract any dessert penalty.
  - Skill XP: add Rested (`skill_gain_mult − 1`), capped at +25 %.
  - Fitness XP: food only, capped at +20 %.
  - Both stay under the existing caps (Fitness `max_gain`, skill `day_cap_units`).
- **Other multipliers:** take the larger of the food effect and the Rested or bed effect. Never multiply them (the `comfort.json` bed precedent).
- **Replacing effects:**
  - The player is asked before a weaker food replaces a stronger effect in the same group.
  - If the player declines a fourth-group prompt, the food gives calories only.
  - Food with no effect profile (raw ingredients, medicines) never touches a slot.
  - Eating can still be refused at the stomach cap.
- **Timers:** saved with the character, kept through logout, cleared on death.

## 5. Decisions that were open for Dave (all resolved by [D17])

1. **Preservation roster [P14-v2].**
   - *Recommendation:* approve three rows: Sealable Preserve Jar, Smoked Meat and Dried Mushrooms.
   - Drop Dried Herbs: fresh herbs never spoil today.
   - Drop Cured Olives: Olives #445 are already edible and keep well.
   - The alternative is to keep all five and change fresh herbs and raw olives to match.
   - Approving the jar also retires the placed Preserving Jar #830 (an existing KEEP row) and moves its six recipes to the Table (s2 item 6).
   - Ripening clock: you said jars mature with elapsed game time. The simplest build reuses the spoilage clock, so cellars and winter would slow ripening too. *Recommendation:* accept that. Plain elapsed time needs a new field.
2. **Energy aids vs [D16].**
   - Today Nut cake, Herbal tea, Nettle tea and Magic tonic (FUTURE) give instant energy and permanently cost Fitness training (21 Oct rule).
   - [D16] wants temporary effects only.
   - *Recommendation:* replace the permanent cost with [D16]'s temporary dessert-style penalty, and let teas join the Beverage group.
3. **Large Wooden Chest.** It cannot have more slots than the 30-slot Ornate - Chest without a format change.
   - *Recommendation:* keep it as a large chest that cannot be lifted while loaded, distinct by footprint and weight capacity.
   - The alternative is to merge it into the chest grades, which gives 173 ADD.
4. **Animal keeping.** The 20 tack rows and 9 of the 10 vehicles need a system to capture or buy, own, lead, ride and hitch animals, plus a domestic ox. None of it is designed.
   - *Recommendation:* approve it as its own future design category.
5. **Nutrition guides [P17].**
   - *Recommendation:* NPC dialogue only for now, with no book items. Revisit when book items exist.
6. **Drinks for the Beverage slot.** No coffee exists, and the only plain drink is Fruit juice. Teas are medicines or energy aids.
   - *Recommendation:* for now, accept Fruit juice plus the teas (after question 2). Add coffee, ale or other drinks only in a later catalog decision; each would be a new ADD row.
7. **Tuning sheet (s4).** Accept, change or defer.

## 6. Audit rounds

- **Round 1 (Claude, commit 05fb0a7):** 10 cross-document checks. Fixes 1 and 10 (part).
- **Round 2, three independent read-only reviewers:**
  - A documentation-authority review (21 findings).
  - A gameplay and duplication review (24).
  - An implementation review against code and data (23).
  - Every substantive finding is fixed (s1), recommended (s2), or an owner question (s5).
  - Minor points with no design effect were not carried forward: the misplaced s3.7 table heading, and a `wear` overflow far beyond any planned ready time.
- **Round 3, a fresh independent re-audit of commit 03db6fd:** 4 must-fix and 7 should-fix findings. All are fixed in the next commit:
  - Sign overlap: first marked as a recommendation, then (round 4) withdrawn in favour of a desk-over-sign priority that keeps Dave's one-context rule.
  - The merge rule (`merge_gap` is 10% of shelf life) now never merges across `ready_age` or merges boards.
  - #830 retirement is tied to the jar decision.
  - Beverage drinks became owner question 6. Magic tonic was added to question 2, and the ripening clock to question 1.
  - "Container" is defined.
  - Master s5 now lists the food and storage numbers.
  - The recipe-route count was corrected.
  - Log - Shelf #848 is flagged: its blueprint and structure are retired.
  - Ageing is described as covering all saved packs.
  - The hook claim was narrowed.
  - Ox wording was fixed.
- **Round 4, a final independent check of commit d023f6a:** confirmed the round 3 fixes. It found 3 remaining issues, all fixed in the final commit:
  - Sign overlap still narrowed Dave's rule; it is now a desk-over-sign priority.
  - A self-contradicting bag-in-chest sentence was removed.
  - Magic tonic was added to the master's energy-aid list.
- **Result:** no substantive issue remains open, other than the seven owner decisions in s5 and the s2 recommendations for ChatGPT.
