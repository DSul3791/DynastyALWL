# Food preparation, simplified preservation and functional serving platters

**Status: MIXED — read approvals carefully.**
- **APPROVED [D12]:** 7 new cooking-equipment concepts, 16 uncooked/prepared intermediates, and the Food Preparation Table workflow.
- **OWNER-APPROVED PRESERVATION WORKFLOW:** prepare once; either finish at a suitable existing station OR allow sealed prepared jars/bottles to **mature passively** by elapsed game time. The **complete preservation additions roster is NOT yet approved**.
- **OWNER-DIRECTED SERVING PLATTER FUNCTION:** a generic reusable platter lets a prepared food-board inventory item be displayed on a table and eaten from. **Dave approved nine boards [D15]** (8 ADD, plus Ploughman's Board as FUTURE) and one Serving Platter. The earlier 20- and 15-board lists are superseded.
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
- Move Nut cake (`energy_bar`) and Fruit juice from hand recipes to the Table.
- Route Herb omelette and Egg-nettle fry to the Clay Griddle or Iron Frying Pan, so eggs stay pre-iron.
- Uncooked Meatballs goes live together with Meatballs #837 (Campfire Pot or Pan).
- Generated dishes are rewritten through `dishes.json` and `tools/gen_dishes.py`, not by hand.
- Butter belongs with preservation.
- Map the attachments to `addon_of` structures with station tags.

Keep existing finished food IDs. Original ingredients are consumed **once** at preparation. Finishing consumes the intermediate **without also charging ingredients again**. Reusable vessels survive. Uncooked items are actual inventory with spoilage. Suitable station and fuel/heat still matter. Cooking and storage may use permitted nearby workstation inventory under §2.5 of master catalog.

## 2. Simplified preservation — owner-approved workflow, item roster pending

Two *simple* recipes paths, generally matching the Food Preparation Table and finishing station model:

1. **Station-finished:** where cutting, mixing or salting is involved, use the Food Preparation Table to create a physical prepared item or batch, then put it into the **existing** Drying Rack #775, Smoker #777, Oven or pot to complete one finishing operation. Do not require multiple busywork transitions (cure → take out → wait → move → dry → smoke). Where no prep is meaningfully necessary (e.g. plain berries at Drying Rack), direct station use is fine.
2. **Passive jar/bottle maturation:** at the Food Preparation Table, supply ingredients **and real containers** to assemble any supported bulk batch: 10, 50 or **hundreds of bottles/jars** if material inputs and storage permit. Each produced sealed portion is **Maturing** and changes to **Ready** automatically when its age reaches its recipe ready age (the engineering note below explains how storage and season affect age). No manual stirring, clicking individual jars, moving them to another workstation, or per-frame timers; storage of the jars is enough. Sauerkraut, fermented vegetables and suitable brined/pickled vegetables are examples. Do not represent heat-dependent jam processing as raw fruit + honey sealed into a safe preserve: cook/heating as appropriate before packaging.

**Dumbed-down state model:** Maturing → Ready → Spoiled as relevant; ordinary fresh foods have their own shelf-life. Keep one ready age plus expiry per batch/portion, update lazily when viewed/transferred/saved, not in continuous per-bottle physics. A transferred or split batch retains its maturation time and freshness. Different ready times should not silently collapse into a single stack with a reset clock. Storage (Root Cellar, Granary if approved) can modify shelf life according to a few consistent rules without microbiology, ambient humidity simulation or pointless micromanagement.

**Engineering note (Claude, working representation for ChatGPT to confirm; not an owner rule):** one representation, with no new item IDs.
- **The clock today:** a slot holds only number, count, `wear` and favourite. For food, `wear` is the stack's age. The server ages packs, placed containers and ground items each tick, scaled by `place_mult` (for example pack 1.0, storage jar 0.5, root cellar far lower) and by season (winter 0.5, summer 1.5). At full age a stack turns into `rotten_food`; that is the only transition built.
- **Maturing jars:** a filled jar is a stack of the finished food's own ID (Sauerkraut #409). Each passive recipe has a `ready_age`. While `wear` is below it the stack shows Maturing and cannot be eaten; after that it is Ready, then spoils at its normal shelf life. The age is never reset, so shelf life must exceed `ready_age`.
- **Consequence:** ready time follows the same place and season scaling, so a cellar or winter slows ripening as well as spoiling. If Dave wants plain elapsed game time instead, each stack needs a new timestamp field.
- **Needed code:** eating and UI gating for unready stacks; returning the empty jar on eating (eating takes one item and returns nothing today); `place_mult` rows for new containers and vehicle or ship cargo; cargo in the ageing loop (a crate on a cart or ship does not age today).
- **Known behaviour:** stacks within `merge_gap` (10% of life) merge by averaging their age, which can shift a ready time by up to 5% of the interval. `wear` is capped at 65535, which bounds very long ready ages.
- **Open (for ChatGPT):** crafted outputs start fresh today (`wear` 0), so preparing old produce resets its age. Whether prepared food inherits its oldest ingredient's age is undecided.
- **Lazy updates:** ageing is a periodic server tick over stacks, not per bottle, so hundreds of jars cost no more than a few stacks.

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

**Review notes (12 Nov audit; roster still pending):** fresh herbs have no spoilage entry, so Dried Herbs adds nothing unless fresh herbs gain a shelf life. Olives #445 are already edible (80 kcal) and long-keeping, with a tooltip saying they are cured in salt, so Cured Olives duplicates them unless raw olives become bitter. Smoked Meat needs a role distinct from Jerky #406 (a Main Meal joint for the boards). Dried Mushrooms joins the `mushrooms` ingredient group. If the jar is approved, RECOMMEND moving the six placed Preserving Jar #830 recipes to the Table with jars and retiring #830; four of them (compote, apple sauce, plum jam, damsons) also need a heated pot step under [D14]. If the jar is rejected, passive batches stay at #830 and Storage Jar #781 scale. The master catalog s3.14 holds the same notes.

**No new cheese/butter rows or stations.** Existing Butter #417, Cheese #418, Cheese Press #844 and Milk #416 are already FUTURE and will be used when livestock/dairy systems warrant them; no `Salted Butter`, `Hard Cheese` or standalone Butter Churn now. The proposed **Granary becomes a logical storage layout** using the approved Storage Sign / Ledger, warehouse storage, suitable bins and storage jars; it isn't a second magical storage inventory or a 6th item here.

**Explicit consolidation / drops:**
- **Curing Tub** → OMIT; existing Preserving Jar #830, the Food Preparation Table and the single-step finish rule cover the role; do not make the placed #830 mandatory to click for every newly assembled sealed jar.
- **Prepared Meat Strips** → OMIT separate master item; existing Jerky #406 and Smoked Meat cover uses, and any genuinely necessary preparation follows the already-approved Table mechanic without a new universal strip ingredient.
- **Salted Meat** → OMIT as redundant with Jerky and Smoked Meat.
- **Smoked Sausage** → OMIT as redundant with existing Sausage #804 and proposed Smoked Meat.
- **Dried Fish** → OMIT because existing Salted Fish #407 and Smoked Fish #185 supply distinct preserving methods.
- **Butter Churn, Salted Butter, Hard Cheese** → DEFER/OMIT in this category; current dairy items are future.
- **Granary** → NO new object; create a storehouse/granary using approved Storage and Warehousing [D13] objects.

**Passively maturing jars: one gameplay item status, not one new item ID for each product's maturing stage.** `Sauerkraut — Maturing` and `Sauerkraut — Ready` share the existing final food ID, using the ready age in the engineering note above. None of this is built yet. Do not mint separate `Maturing X` item IDs unless an approved implementation review proves it is substantially simpler or safer.

**Simple bulk examples (design only):**
- (Needs the [P14-v2] jar.) Food Preparation Table + 200 empty Sealable Preserve Jars + real cabbages/salt → 200 portions of sealed Sauerkraut in *Maturing* state (or legal recipe batch sizes), which become *Ready* automatically as in-game time passes. Existing Sauerkraut #409 stays the same finished food ID. With stacks of 10 that is about 20 stacks; the craft queue allows 20 per entry and 10 entries, so a batch-size mechanic and enough storage are needed.
- Similar sealed batches of **Pickled Vegetables #834** (existing FUTURE, not activated without its gate) and **Cured Olives**. Heat-required jams are still cooked before filling and are not treated as safe by passive raw soaking.
- Dry herbs or mushrooms directly on existing Drying Rack if no preparation is needed. Use the Smoker directly for appropriate meat if no separate assembly is necessary.

**APPROVAL WARNING:** Dave approved the *workflow*, not these 5 item entries. Count remains **zero new approved preservation ADD** until he says yes to this roster; no gameplay JSON/recipes/merge authorized.

## 3. Edible serving platters — nine OWNER-APPROVED board recipes [D15]

Dave requested one **generic reusable Serving Platter** that displays different real edible boards crafted from actual food at the **Food Preparation Table**. The player carries the prepared board in inventory, places it on compatible household/tavern table furniture using the Serving Platter, and players (and later NPC diners, once an NPC hunger system exists) take actual portions. As food is consumed, the display visibly empties. Leftovers and the reusable carrier remain recoverable; no free food, spoilage reset or duplication.

Dave then directed merging similar board recipes and explicitly approved **NINE** distinct names. The previously proposed 20-board and 15-board lists are superseded, not pending.

| Approved status | Prepared food-board item | Suitable already-defined food inputs / distinction |
|---|---|---|
| ADD | **Seafood Platter** | Cooked crab/shellfish/fish, including former Fisherman's and Coastal ideas |
| ADD | **Roast Platter** | Roast Meat #69, Rosemary Joint #275, Roast Beast #191, roots and vegetables; includes former Roast Beef (species-specific beef is not available in live data and may become a future variant only) |
| ADD | **Mixed Grill Platter** | Sausage #804, Meat Skewer #803, grilled foods |
| ADD | **Charcuterie Board** | Jerky #406, cured sausage and preserved accompaniments; Traveller's Board merged here |
| FUTURE | **Ploughman's Board** | Bread + Cheese #418 and Pickled Vegetables #834; cheese and pickles remain FUTURE |
| ADD | **Harvest Platter** | Roasted vegetables, roots and mushrooms |
| ADD | **Tavern Supper Board** | Savoury pies and cooked sides |
| ADD | **Breakfast Platter** | Eggs, Oat Cakes and sausage |
| ADD | **Dessert Platter** | Sweet cakes, baked fruit, pie, honey loaf |

**Counts:** 8 new current food boards + 1 new future board + 1 reusable **Serving Platter** physical carrier = **9 approved ADD item concepts and 1 approved FUTURE concept**. The nine names are nine distinct food inventory items, **not nine physical serving-plate variants**. No separately named generic Roast Beef item is added; true beef could be a look/ingredient variant only after that item source exists. Ploughman's Board remains inaccessible until real cheese and pickles exist.

**How it functions:** Food Preparation Table combines real cooked food inputs to one board inventory item, with real mass/portions/freshness. Placing the board onto a table consumes an available Serving Platter carrier's presentation slot; the display mesh depends on board identity, with a few efficient visible portion states. Click/take serving reduces food available. Picking up the board transfers all remaining portions back to a safe inventory while releasing the carrier; storage, ownership, multiplayer and save/replication are authoritative. Serving platters do not automatically create XP or other bonuses unrelated to their recipe; future food effects are shared profiles in §3a. **Working representation (for ChatGPT to confirm):** the board stack's count is its remaining portions; its shelf life is set at assembly from the shortest-lived ingredient; each portion eaten counts as one food of the board's group, refreshing but never stacking that effect; boards can also be eaten from the pack. Table display needs a table-surface attach point and a placed-platter structure (new code).

### 3a. Future food effects, Fitness training XP and skill XP [D16]

Dave directs that eating real meals should give **temporary, intuitive gameplay benefits** tied to what they contain, and better/higher-tier recipes should produce stronger or longer benefits. This extends the existing hunger/calorie, Fitness training, exertion and health systems rather than creating entirely new character attributes.

| Food class | Example temporary benefit | XP policy |
|---|---|---|
| Protein-rich meat/fish/egg | More effective exertion endurance / physical recovery | **Fitness XP boost while actually earning Fitness training XP**. Dave used **+20% Fitness XP** as illustrative value. |
| Hearty red-meat meals | Better temporary health recovery, physical nourishment | Fitness XP if assigned protein role; don't multiply two competing XP profiles |
| Bread, grains, potatoes | Energy/stamina and light exertion or movement recovery | **NO XP gain bonus** from this food group |
| Fruit and vegetables | Sustained recovery/comfort, possible mild endurance | No arbitrary blanket XP bonus |
| Desserts and sweets | Fast energy burst, shorter duration | May **reduce** XP earned while active, a conscious balance trade-off, magnitude TBD |
| Higher-tier balanced meals | Combined longer-lasting benefits | May boost **all actively earned skill XP** (including Fitness), but apply **one** multiplier, not Fitness bonus multiplied again |

**Simple tier ladder** (proposed tuning, not yet numerical): everyday raw/simple food = brief/small benefit; cooked recipe = moderate; multi-ingredient advanced meal/feast = more useful/longer. Ordinary eating still provides calories; do not force players to eat luxury meals just to gain any XP. Profiles should be readable and predictable. **Owner's later decision supersedes the earlier one-food wording: allow up to THREE simultaneous food benefits, each from a DIFFERENT food group**, never three mains or three desserts. Proposed primary groups: Main Meals, Breads & Grains, Fruit & Vegetables, Desserts, Beverages. A new food in the same group replaces that group's bonus, and a fourth distinct group prompts the player to replace one of the three. Each timer is independent. Normal calories/hunger work regardless of benefit-slot occupancy. Overlapping XP boosters do NOT multiply together: apply the single strongest eligible XP boost, with one simple and visible resolution for dessert XP penalty to tune later. A platter is assigned ONE primary group (proposed: Dessert Platter → Dessert, Harvest Platter → Fruit & Vegetables, the other seven → Main Meals). No permanent free Fitness points; Fitness still levels by genuine physical effort. A Fitness XP bonus is calculated **at each training XP earning event** (the current system accumulates daily and grants at midnight), not when daily points are paid out; eating 30 seconds before midnight cannot retroactively boost a day's efforts. The same rule applies to later skill XP sources; a meal only changes XP being earned *while its effect is active*.

**Discoverable nutritional advice in books and NPC dialogue [P17, owner suggested for FUTURE design]:** Players can hear believable meal-combination tips from innkeepers, cooks, hunters, trainers, healers, scholars and similar NPCs, or read books/manuals. Advice is playstyle-oriented (warrior: hearty main + grain + drink; wizard/scholar: fish + fruit + drink; laborer: stew + bread + beverage), grounded in whichever mechanics and food items actually exist. These samples are illustrative; final guide text must use only effects in the approved tuning (no study or magic skill exists today). **Do not invent mana, available coffee items or unimplemented XP tracks** to make sample advice work. The advice teaches combinations that work for *any* character, never class-restricted diet, secret exclusive combo bonus, magical perk, mandatory reading gate or extra item row. Optionally record discoveries in an existing/future personal knowledge log only when that system is separately approved. The player can experiment without learning the hint. NPC/book dialogue and exact guide/recipe roster are future content not yet individually approved as additions.

**Developer note, not additional owner approval:** food profile ID, effect duration, one XP modifier category, one vitals/exertion bonus and potency tier can be data-driven; no one-off per-dish script. Avoid double counting via prepared board servings, overpowered movement speeds, excessive XP stacking or infinite re-eating. Exact +/− percentages, duration and profile precedence require later owner-approved balancing. The food effect system is planned for later, not implemented or granted by this document.

## 4. How storage, preservation and serving interact

- A sealed **Maturing** jar can sit in a suitable jar rack, crate, Root Cellar or future Granary/warehouse, automatically becoming **Ready** on schedule. Moving an entire loaded crate between warehouses or later onto a ship does not alter the jar's time/ownership/spoilage (cargo must first be added to the ageing loop; see §2).
- When combined with the approved warehouse system [D13], a Warehouse Desk exposes preserved food only from **local physical crates** and only to authorized players. Locked crate owners retain access; four-digit codes and escalating lockout are enforced consistently. Neither desk nor jar grants remote food teleportation.
- Food Preparation Table shares permitted nearby storage sourcing but still performs every recipe's required real ingredient consumption.
- Multiple identical boards may share appearance meshes; each board is a normal stack whose count is its remaining portions and whose age is its freshness.
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
