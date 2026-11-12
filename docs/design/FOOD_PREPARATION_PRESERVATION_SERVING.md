# Food preparation, simplified preservation and functional serving platters

**Status: MIXED — read approvals carefully.**
- **APPROVED [D12]:** 7 new cooking-equipment concepts, 16 uncooked/prepared intermediates, and the Food Preparation Table workflow.
- **OWNER-APPROVED PRESERVATION WORKFLOW:** prepare once; either finish at a suitable existing station OR allow sealed prepared jars/bottles to **mature passively** by elapsed game time. The **complete preservation additions roster is NOT yet approved**.
- **OWNER-DIRECTED SERVING PLATTER FUNCTION:** a generic reusable platter lets a prepared food-board inventory item be displayed on a table and eaten from. **The exact list of 20 board recipes is PROPOSED, not owner-approved.**
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

### Pending preservation item roster — proposals only

The original proposal suggested **3 stations** (Curing Tub, Butter Churn, Granary) plus **9 new foods** (Prepared Meat Strips; Salted Meat; Smoked Meat; Dried Mushrooms; Dried Herbs; Cured Olives; Salted Butter; Hard Cheese; Smoked Sausage). Later simplification favored **dropping the separate Curing Tub** in favor of existing Preserving Jar, and suggested **Dried Fish** as another possible new preserved food. Therefore the previously floated "**12 ADD**" total is **obsolete as a final count**. Before catalog approval, Dave must review the final minimal roster, including Butter Churn, Granary, any dairy/livestock gating, and whether cured/smoked items warrant distinct IDs. Do **not** implement or count any pending ADD in the accepted 165-item total.

No duplicate Fermentation Crock, second Smoker or extra Fish Drying Rack. The sealed jar maturation technique may require actual jars/bottles as consumable or returnable containers; finalize physical representation before adding recipe data. Container compatibility and spoilage need simple UI text.

## 3. Functional decorative platters and edible boards — owner idea, exact roster pending

**Owner-directed behavior:** A **generic reusable Serving Platter** is the physical tabletop display carrier. At the **Food Preparation Table**, the player combines **already cooked/prepared edible components** into a named board/platter meal. That assembled food becomes **one inventory item**, can be carried or traded, and can be **placed onto a compatible dining table using the Serving Platter**. The board's identity/recipe determines what foods appear. There are NOT twenty distinct platter furniture types.

- Platter presentation is not purely decorative: a player (and eventually an authorized NPC) can **take/eat actual portions**, which lowers its remaining contents and changes the visible arrangement. No free infinite food.
- One placed carrier reserves appropriate tabletop surface/slot and bears an actual assembled food item/batch. Removing the board gives the player its remaining edible contents safely; removing an empty carrier returns the reusable Serving Platter. No duplicated platter objects.
- Spoilage/quality of its contents continue aging on the table; placing or repacking a board must not reset them. Capacity, shared access and item persistence obey regular inventory rules. Save/multiplayer transactions must be atomic and authorized.
- Table size, clipping and dining animations need eventual art/interaction design; use the existing approved table furniture, **no extra new table type**.
- If a recipe depends on a future ingredient (e.g. **Beef** is not a current distinct food ID; **Cheese** currently has `future: true`), mark it blocked for now rather than silently inventing livestock or activating future recipes.

**Roster review notes (Claude, against `items.json`; for the owner review):**
- **Possible duplicates of existing rows in the pending preservation list:**
  - Salted Butter vs Butter 417 (FUTURE, hand recipe)
  - Hard Cheese vs Cheese 418 (FUTURE)
  - Cured Olives vs Olives 445
  - Smoked Sausage vs Sausage 804 finished in the Smoker
  - Smoked Meat and Salted Meat vs Jerky 406
  - Dried Fish vs Salted fish 407 and Smoked fish 185
- **Granary:** it exists nowhere in the data.
- **Platter #5:** a live **Roast beast 191** ("feast_roast") and **Rosemary joint 275** exist. Naming the board after Roast beast would avoid the beef gate.

### Twenty named board/feast recipes — PROPOSAL, awaiting Dave's list approval

| # | Proposed prepared platter or board | Representative food composition or visual |
|---|---|---|
| 1 | Seafood Platter | Cooked shellfish, crab cakes, fish |
| 2 | Fisherman's Platter | Herb fish, juniper trout, vegetables |
| 3 | Smoked Fish Board | Smoked/salted fish and rye bread |
| 4 | Coastal Feast | Mixed seafood, roast fish and bread |
| 5 | Roast Beef Platter | **Future beef** roast slices, roots and onions |
| 6 | Sunday Roast Platter | Rosemary joint, baked potatoes, vegetables |
| 7 | Hunter's Feast | Roast beast, mushroom skewers, roots |
| 8 | Mixed Grill Platter | Sausages, skewers, grilled meat |
| 9 | Sausage Supper | Sausages, turnip mash, roasted onion |
| 10 | Charcuterie Board | Cured meats, sausage, jerky, **future cheese** and dried fruit |
| 11 | Ploughman's Board | Bread, **future cheese**, pickled vegetables and apples |
| 12 | Bread & Cheese Board | Breads, **future cheese**, fruit |
| 13 | Harvest Platter | Vegetables, baked potatoes, mushrooms |
| 14 | Tavern Supper Board | Savoury pie, bread, roast vegetables |
| 15 | Breakfast Platter | Eggs, oatcakes, sausage |
| 16 | Traveller's Board | Trail bread, jerky, dried apples, nuts |
| 17 | Orchard Fruit Platter | Seasonal apples, pears, plums |
| 18 | Sweet Treats Board | Honey loaf, chestnut cakes, fruit leather, pastries |
| 19 | Dessert Platter | Apple pie, baked fruit, sweet cakes |
| 20 | Grand Banquet Platter | Large roast with bread, vegetables and other dishes |

The one generic Serving Platter **concept** is owner-directed, but the exact 20 platter item IDs/recipes, portions, quantities and prerequisites are **NOT fully approved**. Do **not** count 1+20 ADD in the master catalog's approved rows until Dave explicitly signs off. If one recipe matches another too closely, the final owner review can combine or remove it.

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
