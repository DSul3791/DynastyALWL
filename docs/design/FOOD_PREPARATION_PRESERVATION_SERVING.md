# Food preparation, simplified preservation and functional serving platters

**Status: MIXED — read approvals carefully.**
- **APPROVED [D12]:** 7 new cooking-equipment concepts, 16 uncooked/prepared intermediates, and the Food Preparation Table workflow.
- **OWNER-APPROVED PRESERVATION WORKFLOW:** prepare once; either finish at a suitable existing station OR allow sealed prepared jars/bottles to **mature passively** by elapsed game time. The **complete preservation additions roster is NOT yet approved**.
- **OWNER-DIRECTED SERVING PLATTER FUNCTION:** a generic reusable platter lets a prepared food-board inventory item be displayed on a table and eaten from. **The revised P15-v2 list of 15 board recipes is PROPOSED, not owner-approved.**
- **No implementation authorization** for any part of this companion document. The authoritative catalog of approved item statuses remains [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md).

## 1. Cooking: approved two-stage design [D12]

**Food Preparation Table** is a physical workstation visibly furnished with a cutting board, kitchen knives and a rolling pin, all **permanent props**. The player opens its **recipe interface**, supplies ingredients and obtains real tangible **uncooked/prepared food inventory**. The relevant cooking station takes that item and finishes it. **Players never need to carry a food-preparation knife, cutting board or rolling pin**; existing knives have skinning/dressing and other previously approved *non-cooking* uses.

**No inventory-only meal assembly.** Simpler food (a fish directly roasted over the Campfire; water boiled in a Campfire Pot; a basic unassembled stew) may be cooked directly at the appropriate food station. A separate prep step is mandatory only where food must be mixed, shaped, stuffed, rolled or assembled. Don't invent a duplicate uncooked item for every fish or vegetable.

### Approved seven ADD equipment items

| Item | Type and role |
|---|---|
| Food Preparation Table | New independent prep station / recipe interface |
| Clay Griddle | Compatible cooking surface: flatbreads, cakes and simple frying |
| Campfire Roasting Spit | Basic Campfire add-on, separate from existing Clay Hearth spit |
| Iron Grill Grate | Open-fire grilling attachment |
| Iron Frying Pan | Reusable vessel for eggs, fish and fried foods |
| Iron Cauldron | Larger-batch soups and stews |
| Fireplace Cooking Crane | Add-on enabling hanging pot use at existing Fireplace #514, **not a second fireplace** |

**Existing equipment kept**: Campfire, Campfire Pot #255, Clay Hearth #257, Oven #267, Fireplace #514, Clay Pot #40, Copper Pot #835 (future), Wooden Bowl #39, Hand Mill #344, Mortar & Pestle #807. No duplicate stove/bread oven, ladle/tool requirement or standalone knife row.

### Approved sixteen tangible intermediates

| Food Preparation Table output | Cooking result |
|---|---|
| Unbaked Flatbread | Flatbread |
| Unbaked Rye Flatbread | Rye Flatbread |
| Unbaked Garlic Flatbread | Garlic Bread |
| Unbaked Honey Loaf | Honey Loaf |
| Unbaked Trail Bread | Trail Bread |
| Unbaked Oatcakes | Oat Cakes |
| Unbaked Chestnut Cakes | Chestnut Cakes |
| Unbaked Apple Pie | Apple Pie |
| Unbaked Fish Pie | Fish Pie |
| Unbaked Venison Pie | Venison Pie |
| Uncooked Meatballs | Meatballs (already future in baseline) |
| Uncooked Sausages | Sausages |
| Uncooked Meat Skewers | Meat Skewers |
| Uncooked Mushroom Skewers | Mushroom Skewers |
| Uncooked Crab Cakes | Crab Cakes |
| Banana Fritter Batter | Banana Fritters |

**Open points from the master catalog's s3.12 reconciliation:**
- Build the Food Preparation Table from logs and twine, like Log - Table 631, so bread stays pre-metal.
- Move Energy bar and Fruit juice from hand recipes to the Table.
- Butter belongs with preservation.
- Map the attachments to `addon_of` structures with station tags.

Keep existing finished food IDs. Original ingredients are consumed **once** at preparation. Finishing consumes the intermediate **without also charging ingredients again**. Reusable vessels survive. Uncooked items are actual inventory with spoilage. Suitable station and fuel/heat still matter. Cooking and storage may use permitted nearby workstation inventory under §2.5 of master catalog.

## 2. Simplified preservation — owner-approved workflow, item roster pending

Two *simple* recipes paths, generally matching the Food Preparation Table and finishing station model:

1. **Station-finished:** where cutting, mixing or salting is involved, use the Food Preparation Table to create a physical prepared item or batch, then put it into the **existing** Drying Rack #775, Smoker #777, Oven or pot to complete one finishing operation. Do not require multiple busywork transitions (cure → take out → wait → move → dry → smoke). Where no prep is meaningfully necessary (e.g. plain berries at Drying Rack), direct station use is fine.
2. **Passive jar/bottle maturation:** at the Food Preparation Table, supply ingredients **and real containers** to assemble any supported bulk batch: 10, 50 or **hundreds of bottles/jars** if material inputs and storage permit. Each produced sealed portion is **Maturing** and changes to **Ready** automatically when elapsed game time reaches its recipe ready time. No manual stirring, clicking individual jars, moving them to another workstation, or per-frame timers; storage of the jars is enough. Sauerkraut, fermented vegetables and suitable brined/pickled vegetables are examples. Do not represent heat-dependent jam processing as raw fruit + honey sealed into a safe preserve: cook/heating as appropriate before packaging.

**Dumbed-down state model:** Maturing → Ready → Spoiled as relevant; ordinary fresh foods have their own shelf-life. Keep one game-time `ready_at` (or an equivalent batch time) plus expiry per batch/portion, update lazily when viewed/transferred/saved, not in continuous per-bottle physics. A transferred or split batch retains its maturation time and freshness. Different ready times should not silently collapse into a single stack with a reset clock. Storage (Root Cellar, Granary if approved) can modify shelf life according to a few consistent rules without microbiology, ambient humidity simulation or pointless micromanagement.

**Engineering note (Claude, recommendation, not an owner rule):** passive maturation can reuse the live spoilage clock (`spoilage.json`) instead of adding a new timer.
- **How the clock works today:** every perishable stack already keeps its age in the slot's `wear` field, and the server ages every pack and container by place and season.
- **Rotting:** at full age a stack already turns into another item (`rotten_food`).
- **Merging:** stacks only merge when their ages are within `merge_gap`.
- **Maturation:** a "Maturing X" item would turn into "X" at its ready age, in the same way, and X then spoils normally.
- **What it gives:** batch timing, safe stacking, save, load and network persistence all come with the existing system. Cold storage would also slow maturation, which is realistic.
- **Cost:** each passively matured food needs one "Maturing" row, which the pending roster must count.
- **Lazy updates:** today's ageing is a periodic server tick over stacks, not per bottle, so hundreds of jars cost no more than a few stacks. The "update lazily" wording above is therefore optional.

**Safeguards:** moving/stacking jars must not reset spoilage or ready times; batch crafting consumes real recipe resources and real vessels; no free thousands of bottles; all content persists across multiplayer, saving, vehicle and warehouse movement; any scale/performance limits must be tuned and disclosed rather than arbitrary hidden limits.

**Existing preservation KEEP, do not duplicate:** Drying Rack #775, Smoker #777, Preserving Jar #830, Root Cellar #832, Storage Jar #781, Barrel #649, Cheese Press #844 (future); preserved foods Jerky #406, Salted Fish #407, Smoked Fish #185, Dried Berries #408, Dried Apples #450, Dried Figs #456, Fruit Leather #184, Sauerkraut #409, Pickled Vegetables #834 (future), Plum Jam #453 and Preserved Damsons #455.

### Revised preservation roster — **P14-v2, FOR DAVE'S REVIEW, NOT APPROVED**

**Recommended minimum: one new portable container and four new preserved foods = 5 proposed ADD rows; ZERO new preservation stations.** This proposal supersedes the earlier 12-ADD list. It follows Dave's repeated requirements: prepare at ONE Food Preparation Table, finish once at an existing rack/smoker or let the jars mature automatically, keep the system light and minimize nearly identical foods and workstations.

| P14-v2 | Proposed item | Unique reason; actual process |
|---|---|---|
| ADD (container) | **Sealable Preserve Jar** | One small reusable **portable sealed container**, distinct from *placed* Preserving Jar station #830 and Storage Jar structure #781. Crafted from existing clay process, taken empty to the Food Preparation Table and filled with real food/brine for bulk `Maturing` → `Ready` jars. Empty container returned when food eaten or jar emptied; no free jars and no material dupes. A cosmetic bottle variant, if added, must not require a whole new inventory ladder. |
| ADD (food) | **Smoked Meat** | Uses meat and Smoker #777, different from existing *Jerky* #406 (dried strips). Requires at most one Food Prep Table step if food must be assembled or seasoned. |
| ADD (food) | **Dried Mushrooms** | Drying Rack #775 makes a lightweight preserved ingredient useful for travel/winter stews |
| ADD (food) | **Dried Herbs** | Drying Rack #775 makes long-lived cooking ingredient; do not multiply by herb species |
| ADD (food) | **Cured Olives** | Existing *Olives* #445 are bitter before curing; prepare in a Sealable Preserve Jar and allow passive brine maturation |

**No new cheese/butter rows or stations.** Existing Butter #417, Cheese #418, Cheese Press #844 and Milk #416 are already FUTURE and will be used when livestock/dairy systems warrant them; no `Salted Butter`, `Hard Cheese` or standalone Butter Churn now. The proposed **Granary becomes a logical storage layout** using the approved Storage Sign / Ledger, warehouse storage, suitable bins and storage jars; it isn't a second magical storage inventory or a 6th item here.

**Explicit consolidation / drops:**
- **Curing Tub** → OMIT; existing Preserving Jar #830, the Food Preparation Table and the single-step finish rule cover the role; do not make the placed #830 mandatory to click for every newly assembled sealed jar.
- **Prepared Meat Strips** → OMIT separate master item; existing Jerky #406 and Smoked Meat cover uses, and any genuinely necessary preparation follows the already-approved Table mechanic without a new universal strip ingredient.
- **Salted Meat** → OMIT as redundant with Jerky and Smoked Meat.
- **Smoked Sausage** → OMIT as redundant with existing Sausage #804 and proposed Smoked Meat.
- **Dried Fish** → OMIT because existing Salted Fish #407 and Smoked Fish #185 supply distinct preserving methods.
- **Butter Churn, Salted Butter, Hard Cheese** → DEFER/OMIT in this category; current dairy items are future.
- **Granary** → NO new object; create a storehouse/granary using approved Storage and Warehousing [D13] objects.

**Passively maturing jars: one gameplay item status, not one new item ID for each product's maturing stage.** E.g., `Sauerkraut — Maturing` and `Sauerkraut — Ready` may share its existing final food definition plus batch condition/ready-time metadata, accompanied by an actual sealed-jar unit. **Technical feasibility is an implementation-gate concern:** Claude noted that the existing `spoilage.json`/stack `wear` system currently transitions food IDs with time. Prefer reuse of that clock, but if a change of schema is required to avoid duplicate maturing rows, compare complexity, compatibility and saves before proceeding; never silently claim this is already supported in live code. Do not mint separate `Maturing X` item IDs unless an approved implementation review proves it is substantially simpler/safer.

**Simple bulk examples (design only):**
- Food Preparation Table + 200 empty Sealable Preserve Jars + real cabbages/salt → 200 portions of sealed Sauerkraut in *Maturing* state (or legal recipe batch sizes), which become *Ready* automatically as in-game time passes. Existing Sauerkraut #409 stays the same finished food ID.
- Similar sealed batches of **Pickled Vegetables #834** (existing FUTURE, not activated without its gate) and **Cured Olives**. Heat-required jams are still cooked before filling and are not treated as safe by passive raw soaking.
- Dry herbs or mushrooms directly on existing Drying Rack if no preparation is needed. Use the Smoker directly for appropriate meat if no separate assembly is necessary.

**APPROVAL WARNING:** Dave approved the *workflow*, not these 5 item entries. Count remains **zero new approved preservation ADD** until he says yes to this roster; no gameplay JSON/recipes/merge authorized.

## 3. Functional decorative platters and edible boards — owner idea, exact roster pending

**Owner-directed behavior:** A **generic reusable Serving Platter** is the physical tabletop display carrier. At the **Food Preparation Table**, the player combines **already cooked/prepared edible components** into a named board/platter meal. That assembled food becomes **one inventory item**, can be carried or traded, and can be **placed onto a compatible dining table using the Serving Platter**. The board's identity/recipe determines what foods appear. There are NOT twenty distinct platter furniture types.

- Platter presentation is not purely decorative: a player (and eventually an authorized NPC) can **take/eat actual portions**, which lowers its remaining contents and changes the visible arrangement. No free infinite food.
- One placed carrier reserves appropriate tabletop surface/slot and bears an actual assembled food item/batch. Removing the board gives the player its remaining edible contents safely; removing an empty carrier returns the reusable Serving Platter. No duplicated platter objects.
- Spoilage/quality of its contents continue aging on the table; placing or repacking a board must not reset them. Capacity, shared access and item persistence obey regular inventory rules. Save/multiplayer transactions must be atomic and authorized.
- Table size, clipping and dining animations need eventual art/interaction design; use the existing approved table furniture, **no extra new table type**.
- If a recipe depends on a future ingredient (e.g. **Beef** is not a current distinct food ID; **Cheese** currently has `future: true`), mark it blocked for now rather than silently inventing livestock or activating future recipes.

### Revised prepared boards — **P15-v2, FOR DAVE'S REVIEW, NOT APPROVED**

**Recommended: 15 named edible board/platter recipes, one generic reusable Serving Platter.** This is **15 prepared-food inventory items + 1 display carrier** if each recipe is represented as its own item, sharing one display/eating code path. Thirteen board recipes use existing obtainable ingredients in principle; **two are explicitly FUTURE-gated** (Roast Beef, Ploughman's Board). Exact recipe materials and portions are for later tuning and availability validation; no livestock or food dependency is silently activated.

| Status | Board / platter (Food Prep Table output) | What appears, using live food when available |
|---|---|---|
| PROPOSED ADD | **Seafood Platter** | Steamed shellfish #361, Crab Cakes #397, roasted fish #80 |
| PROPOSED ADD | **Fisherman's Board** | Smoked Fish #185, Salted Fish #407, Rye Flatbread #388; visually distinct **preserved fish board** |
| PROPOSED ADD | **Roast Dinner Platter** | Rosemary Joint #275, Baked Potato #391, roasted root vegetables; renames Sunday Roast |
| PROPOSED FUTURE | **Roast Beef Platter** | Genuine species-specific beef once livestock/meat source exists; current generic Roast Meat #69 is not silently called beef |
| PROPOSED ADD | **Hunter's Feast** | Roast Beast #191, mushroom skewers #180, roots/vegetables |
| PROPOSED ADD | **Mixed Grill Platter** | Sausage #804, Meat Skewers #803, grilled/roasted meat |
| PROPOSED ADD | **Charcuterie Board** | Jerky #406, sausage #804, dried fruit; cheese may join when FUTURE Cheese #418 becomes available, not mandatory now |
| PROPOSED FUTURE | **Ploughman's Board** | Bread, Cheese #418 (FUTURE), Pickled Vegetables #834 (FUTURE), apple; keep as beloved style but gate properly |
| PROPOSED ADD | **Harvest Platter** | Roasted roots #177, Baked Potatoes #391, mushrooms or seasonal vegetables |
| PROPOSED ADD | **Tavern Supper Board** | Existing savoury pie #401 or #402, flatbread #273, roasted vegetables |
| PROPOSED ADD | **Breakfast Platter** | Boiled Eggs #362, Oat Cakes #405, Sausages #804 |
| PROPOSED ADD | **Traveller's Board** | Trail Bread #189, Jerky #406, Dried Apples #450, nuts |
| PROPOSED ADD | **Orchard Fruit Platter** | Apples #431–435, pears #436–438, plums #440 |
| PROPOSED ADD | **Dessert Board** | Apple Pie #452, Honey Loaf #274, Chestnut Cakes #183 and fruit where appropriate |
| PROPOSED ADD | **Grand Banquet Platter** | One substantial Roast Beast #191 plus bread, vegetables and other banquet food (actual costly inputs, no free food) |

**Five deliberate merges from the original 20 names (not extra IDs):**
1. **Smoked Fish Board** → Fisherman's Board; same cold fish/bread layout.
2. **Coastal Feast** → Seafood Platter; same mixed seafood feast.
3. **Sausage Supper** → Mixed Grill Platter; same sausage-focused cooked-meat board.
4. **Bread & Cheese Board** → Ploughman's Board; cheese/bread plate with additional pickled foods.
5. **Sweet Treats Board** → Dessert Board; overlapping sweet/pastry food group.

The result retains 15 **visually and functionally distinct compositions** instead of 20 slightly duplicated variants, including Dave's explicit examples: Seafood, Roast Beef, Charcuterie and Ploughman's. Do not add one item for each wooden platter model; **one Serving Platter** is the reusable physical carrier. Each named board is still a **real prepared food** in the inventory (not an image-only decoration), made using the Food Preparation Table and actual existing cooked ingredients. Eating portions changes the visible arrangement and decreases actual remaining servings. Reusable carrier can be removed when empty; normal spoilage continues. Per-board item IDs (15 food rows) are the low-risk default for current item-data compatibility; a future proposal could use a polymorphic prepared-board ID, but that may increase per-instance complexity and is **not** an owner-approved simplification.

**P15-v2 counts:** **1 physical Serving Platter + 13 ready-eligible food-board ADD + 2 FUTURE-gated food boards = 16 proposed definitions**. These are **not part of the currently approved catalog totals**. No item is approved just because its name appears on this list.

## 4. How storage, preservation and serving interact

- A sealed **Maturing** jar can sit in a suitable jar rack, crate, Root Cellar or future Granary/warehouse, automatically becoming **Ready** on schedule. Moving an entire loaded crate between warehouses or later onto a ship does not alter the jar's time/ownership/spoilage.
- When combined with the approved warehouse system [D13], a Warehouse Desk exposes preserved food only from **local physical crates** and only to authorized players. Locked crate owners retain access; four-digit codes and escalating lockout are enforced consistently. Neither desk nor jar grants remote food teleportation.
- Food Preparation Table shares permitted nearby storage sourcing but still performs every recipe's required real ingredient consumption.
- Multiple identical boards may share appearance meshes, but each retains actual consumable portions, composition and freshness as normal inventory.
- Table meal props and platter items are **not** identical to portable physical crates; they do not increase tabletop capacity or any NPC food budget for free.

## 5. Validation/audit scenarios for future implementation

1. Make Unbaked Apple Pie at Food Preparation Table; Oven consumes it, not original apples/flour twice.
2. Fish roasts directly at Campfire with no artificial prep-table gate.
3. Batch-create 200 brined jars only if real ingredients and 200 containers are present; output preserves distinct maturity timestamps if produced in different batches.
4. Store sealed jars; time passes; they become Ready without any manual station interaction, including while their warehouse crate is being carried by a cart or ship.
5. No ingredient/item duplication when transferring partially mature jars, and no clock reset after saving/loading or restacking.
6. Smoker and Drying Rack finish their prepared food in one processing step; jam keeps any required heating logic.
7. Create a proposed edible Ploughman's Board only when actual bread, cheese and pickles exist and are eligible; do not activate gated future food to make recipe appear.
8. Place a board inventory item on a table using an empty reusable Serving Platter; displayed layout matches board food and food count.
9. Eat half the portions; visible fullness drops, remaining food returns correctly when picked up and retains spoilage state.
10. Another player without permission does not withdraw protected assembled food/food jars through a Warehouse Desk or by manipulating a locked loaded crate.
11. Confirm all approved IDs remain stable; no accidental item count inflation from duplicate crafting props or food stages.

**Implementation gate:** These are test designs, not run tests. Preserve explicit owner approval states in the master catalog. No runtime work until complete master catalog plus separate implementation permission.
