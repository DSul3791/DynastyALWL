# Master catalog final audit, 12 November 2026

**Status: DOCUMENTATION AUDIT ONLY.** Written by Claude on PR #1035 after Dave's [D17] decisions.

- **Data and code:** read only, from `dev` `7f8aabf4`.
- **Tests:** no Godot test was run. Every scenario here is a design walkthrough.
- **Authority:** the master catalog is authoritative. The earlier rounds are recorded in `FOOD_STORAGE_AUDIT_2026-11-12.md`.

## 1. How [D17] was incorporated

| # | Dave's decision | Where it now lives |
|---|---|---|
| 1 | Keep Preserving Jar #830; no Sealable Preserve Jar; passive bulk maturation with existing definitions | Master s3.14 and companion s2. Batches are sealed at #830 as the finished food's own stack, with a `ready_age` on the existing age. There is no vessel item, a batch size, no merging across `ready_age`, and cooked preserves move to the pot. |
| 2 | ADD Smoked Meat and Dried Mushrooms only | Master s3.14 table, Totals, s7 item 21. |
| 3 | All food effects temporary; remove permanent Fitness penalties | Master s3.16, s6 row 46, s7 item 22. Nut cake 51 becomes UPDATE because its tooltip changes. The migration rule for saved `train` values is in the migration doc. |
| 4 | Large Wooden Chest: more weight, larger footprint, within 30 slots | Master s3.13 row; storage companion s3. |
| 5 | Keep tack and vehicles; animal keeping is a later phase | Master s3.10 and s8; implementation plan phase 11. |
| 6 | Guides through NPCs and books, later | Master s3.16; companion s3a; UI note. Book rows are added in that phase. |
| 7 | Teas and Fruit juice are the first beverages | Master s3.16. Medicinal teas also cure, and teas are no longer refused when healthy or rested. |
| 8 | Suggested numbers are initial playtest values | Master s3.16 table and rules. The old audit's sheet is marked accepted. |

## 2. Verified counts

**Existing rows: 889.** Appendix A was recounted by script.

| Status | Rows |
|---|---|
| KEEP | 499 |
| UPDATE | 61 |
| RETIRE | 23 |
| FUTURE | 53 |
| Already retired | 253 |

**What changed in Draft 18:**
- Nut cake 51 moved from KEEP to UPDATE, because its tooltip loses "wears on your fitness".
- No other existing row changed status.
- Recipe changes (preserves to the pot, egg dishes, the hand-made foods) leave their item rows KEEP, as in every earlier category.

**New rows: ADD 176.**

| Category | ADD rows |
|---|---|
| Tools and stations | 18 |
| Furniture | 6 |
| Weapons and ammunition | 29 |
| Armour | 14 |
| Clothing | 17 |
| Carrying | 9 |
| Tack | 20 |
| Vehicles and parts | 13 |
| Cooking | 23 |
| Storage | 16 |
| Preservation | 2 |
| Boards and Serving Platter | 9 |

- **New FUTURE rows: 4.** Steel bolt, Iron - Lance, Riding - Boots and Ploughman's Board.
- **Not rows:** blueprints and structure states for vehicles and stations, storage layouts, the Ship Captain's Table, guide books (a later phase) and food effects.

**Retirements: 23 item rows.**
- Tools: Stone - Spade 45, Stone - Sickle 298, Stone - Wedge 353.
- Saw blade 238.
- 16 species `lumber_*`/`beam_*` rows.
- Stations: Woodworking table 243 (PR #1036), Clay bloomery 795, Anvil 827.

**Other retirements:**
- Recipes 26, 152, 187, 227, 230 and 367.
- Blueprints 162 and 164.
- Structure states 200 and 204.

## 3. Progression scenarios (design walkthroughs)

| Scenario | Path under the catalog | Result |
|---|---|---|
| **First hour, new character** | Gather sticks, stone and fibre, then make stone tools and twine. Campfire and fish over the fire need no prep table, which rule 3 allows. The Wicker - Chest is the first storage, Basket and Hide - Sack the first bags. | Holds. Food and storage are reachable with no metal and no saw. |
| **First bread, pre-iron** | Logs and twine make the Food Preparation Table (delegated default). Unbaked Flatbread is finished at the Clay hearth or Clay griddle. | Holds. If the Table were built from boards, bread would wait for the saw, which is why the log recipe is the default. |
| **First preserves** | Place Preserving Jar #830, then seal ×10 Sauerkraut from cabbage and salt. It shows Maturing, then Ready, with no further clicks. Jerky comes from the Drying Rack. Dried Mushrooms come from the Drying Rack, and Smoked Meat from the Smoker. | Holds. #830, the Smoker and the Drying Rack are all live stations today. |
| **200 portions** | Seal ×50 twice: 100 cabbage and 50 salt per batch. That makes 20 stacks of 10, delivered to the pack and then a nearby Crate or Root Cellar, capped by free space. They mature more slowly in the cellar. | Holds, with batch size built in phase 6. Fresh cabbage is needed: sealing refuses inputs below half freshness, and output starts at age 0. |
| **Jam** | Plums and nectar are cooked at the Campfire Pot and are Ready at once. | Holds, under the [D14] heat rule. |
| **Route to the first saw** | Bog iron, then the Smelter, charcoal, iron, the Smithy and the Iron hand saw. Planks and Hardwood boards follow, then graded furniture and the Wardrobe and Bookcase. | Holds (master s6 rows 15–17). Hardwood-free biomes need travel or trade (s6 row 30). |
| **A day of training on food** | A Rosemary joint (Main Meal: +10 to +20 % Fitness XP by its tier), Flatbread (Bread & Grains: lower energy drain) and Herbal tea (Beverage: a small energy lift, plus −5 % hunger and thirst drain for 2 h). Fitness XP is boosted per tick, then paid at midnight. | Holds. There is no permanent Fitness change, because energy aids lose their cost. |
| **Dessert after training** | A Nut cake fills a slot after a replace prompt. It gives its 25 energy (once per slot fill, so it cannot replace sleep) and −5 % XP for 1 h on its own timer. Replacing it later does not clear the penalty. | Holds. No permanent penalty. |
| **Sick player with Chamomile tea** | The tea cures and fills the Beverage slot. A healthy player gets the Beverage effect only. | Holds under [D17]. |
| **Warehouse trade run** | A Warehouse Crate is coded 0042. The owner wheels it full on a Handcart from Warehouse A to Warehouse B. Desk A loses it and Desk B shows it to the owner. A friend with the code sees it; a stranger sees nothing. The Sauerkraut inside keeps ageing. | Holds, once cargo joins the ageing loop (phase 10). |
| **Old save after the update** | A playtest world with a Clay bloomery, a Saw blade in a chest, a worn quiver and old Sauerkraut. The bloomery still works, the Saw blade becomes its ingredients, the quiver moves to the pack, and the Sauerkraut is Ready. | Holds under the migration rules. |
| **Animal wagon before phase 11** | The Farm Wagon row is FUTURE-flagged until animal keeping exists. The Handcart is live. | Holds. No half-built item is exposed. |

## 4. Review rounds

- **Rounds 1–4 (before [D17]):** see `FOOD_STORAGE_AUDIT_2026-11-12.md`.
- **Round 5:** see s5 below.

## 5. Round 5: independent reviews of commit 30b7fd0

Three read-only reviewers worked in parallel:
- **Cross-document consistency and counts.** 20 findings. All the counts verified, including 176 ADD counted row by row in each s3 table.
- **Gameplay progression walkthrough against the data.** 15 findings.
- **Save migration and plan against the code.** 3 HIGH and 6 MED findings, plus minor ones.

All are fixed in the next commit. The main fixes:

**Stale "pending" wording**
- Removed from the s1 tags, s5, the storage companion, the UI note and the handoff.
- The Granary is now a fourth layout everywhere.

**Labels**
- Rules derived from [D17] are labelled DELEGATED, so [D17] itself is only Dave's eight points.
- RECOMMEND is defined as a delegated default.

**Dried Mushrooms**
- Kept out of the `mushrooms` group, so it cannot dry itself. Its uses are named directly.
- Mushrooms 551 and Puffball gain a shelf life.

**Food effects and maturing**
- Instant energy is given only when a slot is newly filled, so energy aids cannot replace sleep. There is one energy number per item.
- Maturing cannot be skipped: output starts at age 0, there is a fresh-input floor, and unready stacks cannot be used.
- Food tier is counted over the whole prepare-and-cook chain.

**Stations, routes and output**
- Cooking attachments are kept equipment, because `addon_of` cannot host them; only the Crane needs attach code.
- Batch output goes to the pack and nearby containers.
- The Handcart's wheel and axle use Planks, so it can be built in the hardwood-free biomes.
- The Loom is pre-saw.
- Log furniture is marked unbuildable.
- The Serving Platter can use the Food Preparation Table as its surface before the first saw.
- The `wear`-cap validation was added.

**Save migration**
- Loaders keep accepting v1 files.
- The backup is `.catalog.bak`.
- Retired blueprints become `hidden`, so take-down still refunds materials.
- Refunds use stored lists and an offline path.
- The worn pre-pass is placed correctly in the load order.
- Worn slots become slot arrays.
- Old Sauerkraut is made Ready by age.

**Implementation plan**
- Retirements move to the phase that replaces them.
- A slot-format phase 1b is added.
- Phase dependencies are fixed: clothing and carrying need phase 2, storage needs 3, Handcart needs 2, books need 9.
- Poison preparation and enhancement effects are placed in phase 12.

## 6. Round 6
A fresh independent check of the round 5 fixes is recorded in the PR comment for the final commit.
