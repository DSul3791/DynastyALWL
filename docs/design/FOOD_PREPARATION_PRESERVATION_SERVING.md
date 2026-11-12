# Food preparation, simplified preservation and functional serving platters

**Status: OWNER-APPROVED DESIGN [D12]–[D17]; DOCS ONLY — NOT IMPLEMENTED.**
- **APPROVED [D12]:** 7 new cooking-equipment concepts, 16 uncooked/prepared intermediates, and the Food Preparation Table workflow.
- **APPROVED PRESERVATION [D14, D17]:** prepare once; either finish at a suitable existing station OR let sealed batches **mature passively** with in-game time. Roster: keep Preserving Jar #830, add Smoked Meat and Dried Mushrooms, no other new rows.
- **APPROVED SERVING PLATTER [D15]:** a generic reusable platter lets a prepared food-board inventory item be displayed on a table and eaten from. **Dave approved nine boards [D15]** (8 ADD, plus Ploughman's Board as FUTURE) and one Serving Platter. The earlier 20- and 15-board lists are superseded.
- **APPROVED FOOD EFFECTS [D16, D17]:** three group slots, temporary effects only, initial playtest values in master s3.16.
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

**Delegated defaults from the master catalog's s3.12 reconciliation:**
- Build the Food Preparation Table from logs and twine, like Log - Table 631, so bread stays pre-metal.
- Move Nut cake (`energy_bar`) and Fruit juice from hand recipes to the Table.
- Route Herb omelette and Egg-nettle fry to the Clay Griddle or Iron Frying Pan, so eggs stay pre-iron.
- Uncooked Meatballs goes live together with Meatballs #837 (Campfire Pot or Pan).
- Generated dishes are rewritten through `dishes.json` and `tools/gen_dishes.py`, not by hand.
- Butter belongs with preservation.
- Keep the Griddle, Spit, Grate, Pan and Cauldron as kept equipment used at the fire or hearth; only the Fireplace Cooking Crane gets new attach code.

Keep existing finished food IDs. Original ingredients are consumed **once** at preparation. Finishing consumes the intermediate **without also charging ingredients again**. Reusable vessels survive. Uncooked items are actual inventory with spoilage. Suitable station and fuel/heat still matter. Cooking and storage may use permitted nearby workstation inventory under §2.5 of master catalog.

## 2. Simplified preservation — owner-approved workflow [D14] and roster [D17]

Two simple routes, matching the Food Preparation Table and finishing-station model:

1. **Station-finished:** where cutting, mixing or salting is involved, the Food Preparation Table makes a physical prepared item, then one existing station finishes it: Drying Rack #775, Smoker #777, Oven or pot. No multi-station chores (cure → take out → wait → move → dry → smoke). Plain berries go straight onto the Drying Rack.
2. **Passive maturation:** at the existing placed **Preserving Jar #830**, the player seals a batch of real ingredients (any cutting or mixing first happens at the Food Preparation Table; whole cabbage and salt need none). The batch comes out as the finished food's own stack (Sauerkraut #409), *Maturing* until it has aged enough, then *Ready*, with no stirring, clicking each jar or moving between stations. Sauerkraut and brined or pickled vegetables are the examples. Jam and other cooked preserves are cooked, not sealed raw.

**Roster [D17]:** keep the Preserving Jar #830; no Sealable Preserve Jar. **ADD Smoked Meat** (Smoker #777: raw meat and salt; a Main Meal joint that keeps, distinct from Jerky #406, the light travel snack) and **ADD Dried Mushrooms** (Drying Rack #775: one recipe per fresh mushroom; a long-keeping Fruit & Vegetables food kept out of the `mushrooms` group so it cannot dry itself; used in a dried-mushroom skewer and the Harvest Platter). Dried Herbs and Cured Olives are not added.

**Representation (DELEGATED default; no new item IDs):**
- **The clock today:** a slot holds only number, count, `wear` and favourite. For food, `wear` is the stack's age. The server ages all saved packs, placed containers and ground items each tick, scaled by `place_mult` (for example pack 1.0, storage jar 0.5, root cellar far lower) and by season (winter 0.5, summer 1.5). At full age a stack turns into `rotten_food`, the only transition built.
- **No vessel item.** #830 is a placed station with no inventory. Its sealed foods carry their jar as part of the food, as today. Nothing is made, consumed or returned as a jar, so jars cannot be duplicated or lost.
- **Maturing:** each passive recipe has a `ready_age`. While `wear` is below it the stack shows Maturing and cannot be eaten; then it is Ready, and later it spoils at its normal shelf life, which must exceed `ready_age`. The age is never reset. Because the clock is scaled, a cellar or winter slows ripening as well as spoiling; this reading of "enough in-game time" needs no new field.
- **Merging:** today stacks merge when their ages differ by less than `merge_gap`, 10% of the shelf life (for Sauerkraut about 192 game hours), and the merge averages their age. New rule: never merge across `ready_age`, and never merge two boards.
- **Bulk:** one craft at #830 takes a batch size (for example ×1, ×10, ×50) that multiplies real inputs and outputs. #830 has no inventory, so output goes to the pack and then nearby containers, capped by their free space. 200 portions are 20 stacks of 10. One timer per stack, not per portion. Batch limits are tuning.
- **Heat rule:** Berry compote (102), Apple sauce (283), Plum jam (285) and Preserved damsons (287) move from #830 to the Campfire Pot or a cooking pot and are Ready when cooked.
- **Crafted age (DELEGATED default):** a prepared or cooked output inherits the age fraction of its oldest perishable input, so preparing old produce does not make it fresh. Today outputs start at `wear` 0. Exception: a passive recipe's output starts at age 0 and sealing refuses inputs below half freshness, so maturing cannot be skipped.
- **Unready stacks:** a Maturing stack cannot be eaten, used as an ingredient, drawn by stations or sold.
- **Needed code:** eat and UI gating for unready stacks; batch size; the merge rule; `place_mult` rows for new containers and vehicle or ship cargo, and cargo in the ageing loop.
- **Lazy updates:** ageing is a periodic server tick over stacks, not per portion, so hundreds of portions cost no more than a few stacks. `wear` is capped at 65535 tenths of an hour, which bounds very long ready ages.

**Safeguards:** moving or stacking never resets age or ready time; batches consume real ingredients; no free food; everything persists across multiplayer, saving, vehicle and warehouse movement; scale limits are tuned and disclosed, not hidden.

**Existing preservation KEEP, do not duplicate:** Drying Rack #775, Smoker #777, Preserving Jar #830, Root Cellar #832, Storage Jar #781, Barrel #649, Cheese Press #844 (future); preserved foods Jerky #406, Salted Fish #407, Smoked Fish #185, Dried Berries #408, Dried Apples #450, Dried Figs #456, Fruit Leather #184, Sauerkraut #409, Pickled Vegetables #834 (future), Plum Jam #453 and Preserved Damsons #455. Dairy (Milk #416, Butter #417, Cheese #418, Cheese Press #844) stays FUTURE. The Granary is a storage layout [D13], not an item. Omitted: Sealable Preserve Jar, Dried Herbs, Cured Olives, Curing Tub, Butter Churn, Prepared Meat Strips, Salted Meat, Smoked Sausage, Dried Fish, Salted Butter, Hard Cheese.

**Bulk example (design only):** the Food Preparation Table is not needed for cabbage; at #830 the player seals ×50 Sauerkraut (100 cabbage, 50 salt) twice, giving 200 Sauerkraut in 20 stacks in the pack and a nearby crate, Maturing, then Ready on their own in a crate or the Root Cellar (slower there).

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

**How it functions:** Food Preparation Table combines real cooked food inputs to one board inventory item, with real mass/portions/freshness. Placing the board onto a table consumes an available Serving Platter carrier's presentation slot; the display mesh depends on board identity, with a few efficient visible portion states. Click/take serving reduces food available. Picking up the board transfers all remaining portions back to a safe inventory while releasing the carrier; storage, ownership, multiplayer and save/replication are authoritative. Serving platters do not automatically create XP or other bonuses unrelated to their recipe; future food effects are shared profiles in §3a. **Working representation (DELEGATED default):** the board stack's count is its remaining portions; its shelf life is set at assembly from the shortest-lived ingredient; each portion eaten counts as one food of the board's group, refreshing but never stacking that effect; boards can also be eaten from the pack. Table display needs a table-surface attach point and a placed-platter structure (new code).

### 3a. Food effects, Fitness training XP and skill XP [D16, D17]

Dave directs that eating real meals should give **temporary, intuitive gameplay benefits** tied to what they contain, and better/higher-tier recipes should produce stronger or longer benefits. This extends the existing hunger/calorie, Fitness training, exertion and health systems rather than creating entirely new character attributes.

| Food class | Example temporary benefit | XP policy |
|---|---|---|
| Protein-rich meat/fish/egg | More effective exertion endurance / physical recovery | **Fitness XP boost while actually earning Fitness training XP**. Initial playtest values: +10 / +15 / +20 % by tier [D17]. |
| Hearty red-meat meals | Better temporary health recovery, physical nourishment | Fitness XP if assigned protein role; don't multiply two competing XP profiles |
| Bread, grains, potatoes | Energy/stamina and light exertion or movement recovery | **NO XP gain bonus** from this food group |
| Fruit and vegetables | Sustained recovery/comfort, possible mild endurance | No arbitrary blanket XP bonus |
| Desserts and sweets | Fast energy burst, shorter duration | **Reduces** XP earned while active: −5 % for 1 h on its own timer [D17 initial value]; temporary only |
| Higher-tier balanced meals | Combined longer-lasting benefits | May boost **all actively earned skill XP** (including Fitness), but apply **one** multiplier, not Fitness bonus multiplied again |

**Simple tier ladder** (initial values in master s3.16 [D17]): everyday raw/simple food = brief/small benefit; cooked recipe = moderate; multi-ingredient advanced meal/feast = more useful/longer. Ordinary eating still provides calories; do not force players to eat luxury meals just to gain any XP. Profiles should be readable and predictable. **Owner's later decision supersedes the earlier one-food wording: allow up to THREE simultaneous food benefits, each from a DIFFERENT food group**, never three mains or three desserts. Proposed primary groups: Main Meals, Breads & Grains, Fruit & Vegetables, Desserts, Beverages. A new food in the same group replaces that group's bonus, and a fourth distinct group prompts the player to replace one of the three. Each timer is independent. Normal calories/hunger work regardless of benefit-slot occupancy. Overlapping XP boosters do NOT multiply together: apply the single strongest eligible XP boost, minus any dessert penalty (master s3.16). A platter is assigned ONE primary group (DELEGATED default: Dessert Platter → Dessert, Harvest Platter → Fruit & Vegetables, the other seven → Main Meals). No permanent free Fitness points and **no permanent penalties** [D17]: the energy aids' permanent Fitness cost is removed. Beverages are the existing teas and Fruit juice; coffee may come later. Fitness still levels by genuine physical effort. A Fitness XP bonus is calculated **at each training XP earning event** (the current system accumulates daily and grants at midnight), not when daily points are paid out; eating 30 seconds before midnight cannot retroactively boost a day's efforts. The same rule applies to later skill XP sources; a meal only changes XP being earned *while its effect is active*.

**Discoverable nutritional advice in books and NPC dialogue [D17: approved; implemented when the supporting systems exist]:** Players can hear believable meal-combination tips from innkeepers, cooks, hunters, trainers, healers, scholars and similar NPCs, or read books/manuals. Advice is playstyle-oriented (warrior: hearty main + grain + drink; wizard/scholar: fish + fruit + drink; laborer: stew + bread + beverage), grounded in whichever mechanics and food items actually exist. These samples are illustrative; final guide text must use only effects in the approved tuning (no study or magic skill exists today). **Do not invent mana, available coffee items or unimplemented XP tracks** to make sample advice work. The advice teaches combinations that work for *any* character, never class-restricted diet, secret exclusive combo bonus, magical perk or mandatory reading gate. Guide books are a future content set added in that later phase, kept in the Bookcase [D13]. Optionally record discoveries in an existing/future personal knowledge log only when that system is separately approved. The player can experiment without learning the hint. Exact guide texts and book rows are written in that later phase.

**Developer note, not additional owner approval:** food profile ID, effect duration, one XP modifier category, one vitals/exertion bonus and potency tier can be data-driven; no one-off per-dish script. Avoid double counting via prepared board servings, overpowered movement speeds, excessive XP stacking or infinite re-eating. Percentages and durations start at the [D17] initial values and are retuned in playtest. Not implemented by this document.

## 4. How storage, preservation and serving interact

- A **Maturing** stack can sit in a suitable jar rack, crate, Root Cellar or a Granary layout or warehouse, automatically becoming **Ready** on schedule. Moving an entire loaded crate between warehouses or later onto a ship does not alter its age, ownership or spoilage (cargo must first be added to the ageing loop; see §2).
- When combined with the approved warehouse system [D13], a Warehouse Desk exposes preserved food only from **local physical crates** and only to authorized players. Locked crate owners retain access; four-digit codes and escalating lockout are enforced consistently. No desk grants remote food teleportation.
- Food Preparation Table shares permitted nearby storage sourcing but still performs every recipe's required real ingredient consumption.
- Multiple identical boards may share appearance meshes; each board is a normal stack whose count is its remaining portions and whose age is its freshness.
- Table meal props and platter items are **not** identical to portable physical crates; they do not increase tabletop capacity or any NPC food budget for free.

## 5. Validation/audit scenarios for future implementation

1. Make Unbaked Apple Pie at Food Preparation Table; Oven consumes it, not original apples/flour twice.
2. Fish roasts directly at Campfire with no artificial prep-table gate.
3. Batch-seal 200 Sauerkraut at #830 only if the real ingredients are present; batches made at different times stay separate stacks and never merge across `ready_age`.
4. Store the Maturing stacks; time passes; they become Ready without any manual station interaction, including while their warehouse crate is being carried by a cart or ship.
5. No ingredient/item duplication when transferring partially mature stacks, and no clock reset after saving/loading or restacking.
6. Smoker makes Smoked Meat and Drying Rack makes Dried Mushrooms in one step; jam, compote, apple sauce and damsons are cooked at a pot, not sealed raw.
7. Create a proposed edible Ploughman's Board only when actual bread, cheese and pickles exist and are eligible; do not activate gated future food to make recipe appear.
8. Place a board inventory item on a table using an empty reusable Serving Platter; displayed layout matches board food and food count.
9. Eat half the portions; visible fullness drops, remaining food returns correctly when picked up and retains spoilage state.
10. Another player without permission does not withdraw protected assembled food/food jars through a Warehouse Desk or by manipulating a locked loaded crate.
11. Eat a Nut cake: quick energy, a 1-hour −5 % XP effect, and no change to Fitness training afterwards.
12. Drink Chamomile tea while healthy: Beverage effect, no refusal; while sick: cure as well.
13. Confirm all approved IDs remain stable; no accidental item count inflation from duplicate crafting props or food stages.

**Implementation gate:** These are test designs, not run tests. Preserve explicit owner approval states in the master catalog. No runtime work until Dave approves the complete catalog and authorizes each phase (`CATALOG_IMPLEMENTATION_PLAN.md`).
