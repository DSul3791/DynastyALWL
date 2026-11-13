# GOALS-AUDIT workstream: content inventory and catalog authority (ws_catalog)

Baseline: branch `claude/project-thread-d8jals`, `dev` dc2fa52. Method: Python join of `work/goals_parsed.json` (651 rows) against `data/items/{items,gathered,recipes,blueprints,structures,wood_species}.json`, `docs/design/catalog_ledger.json` and `DYNASTY_MASTER_ITEMS.md`; then reading of the authority documents and the code cited per finding. Evidence level: CODE_VERIFIED (static reading) at best. No Godot, no tests were run in this audit; test files named below were only checked for existence. Machine-readable results: `work/ws_catalog.json` (all 651 goals, 26 add candidates, inventory counts).

## 1. Headline results

| Goal kind | IMPLEMENTED | APPROVED_BUT_NOT_IMPLEMENTED | FUTURE | RETIRED | UNKNOWN | Total |
|---|---|---|---|---|---|---|
| craft | 342 | 0 | 0 | 0 | 0 | 342 |
| build | 232 | 23 | 1 | 0 | 0 | 256 |
| existing | 28 | 0 | 0 | 0 | 0 | 28 |
| gather | 20 | 0 | 0 | 0 | 0 | 20 |
| activity | 5 | 0 | 0 | 0 | 0 | 5 |
| **all** | **627** | **23** | **1** | **0** | **0** | **651** |

- 627 of 651 goals target live content. **24 target content that cannot be built today** (23 approved-but-locked water/irrigation/garden pieces, 1 FUTURE rug), all Additional route, 940 copper of the 15,670 total (C-01).
- **No goal targets a retired item, retired recipe, retired structure, or a recipe that is locked.** All 342 craft goals use live, known recipes with live outputs and inputs.
- **57 goals** (9 Main) target pieces the ledger marks IMPLEMENTED - UNVERIFIED or the BUGLIST ledger marks NEEDS PLAYER VERIFICATION (doors, all doorways, Crude - Roof 65): implemented in data, headless tests only (C-02).
- Every goal title that is a craft or build uses the data (implemented) name; the one exception is `craft:firewood` (task name). Legacy runtime titles are generic for four rows and one gather title uses a non-data name (C-05).
- Coverage of live equipment is complete (every tool, weapon, armour, clothing, gear, container tier has a goal); 26 add candidates are interactions or two fire-starter crafts, not missing item tiers (section 4).
- 36 goals are in a duplicate or overlap relation; 70 craft goals are intermediate components (728 copper) that could be grouped (sections 5, 6).

## 2. Findings

### C-01 [HIGH] 24 goals ask the player to build pieces that no player can build

**Affected goals:** 24 goals (all Additional, 940 copper): `build:clay_pipe_elbow`, `build:clay_pipe_run`, `build:clay_pipe_tee`, `build:iron_deep_well_pump`, `build:iron_hand_pump`, `build:iron_pipe`, `build:iron_pipe_elbow`, `build:iron_tap`, `build:stone_channel`, `build:stone_channel_corner`, `build:stone_channel_tee`, `build:stone_cistern`, `build:stone_raised_cistern`, `build:stone_trough`, `build:stone_well`, `build:wooden_channel`, `build:wooden_channel_corner`, `build:wooden_channel_tee`, `build:wooden_cold_frame`, `build:wooden_compost_bin`, `build:wooden_hand_pump`, `build:wooden_sluice`, `build:wooden_trough`, `build:wool_rug`

**Evidence:**
- Implementation side: `data/items/blueprints.json` blueprints.{stone_well, wooden_hand_pump, iron_hand_pump, wooden_trough, wooden_channel(+_corner,_tee), wooden_sluice, stone_trough, stone_channel(+_corner,_tee), clay_pipe_run/_elbow/_tee, iron_pipe, iron_pipe_elbow, iron_tap, iron_deep_well_pump, stone_cistern, stone_raised_cistern, wooden_compost_bin, wooden_cold_frame, wool_rug} all have `"known": false, "locked": true` and (except wool_rug) no `recipe` key to learn them from.
- `src/stream/server_items.gd:8138` `_can_blueprint`: `if not bool(row.get("known", true)) ... return false` outside free-build, so the hammer menu cannot place them. recipes.json note and `server_items.gd:15960` define `locked` as "a chain it depends on does not exist yet".
- Catalog side: ledger entries for the 23 water/garden rows are catalog KEEP, state NO CHANGE (`docs/design/catalog_ledger.json`, e.g. keys stone_well, wooden_hand_pump, stone_cistern, wooden_compost_bin, wooden_cold_frame; master Appendix A lines 1834-1857 KEEP), and `docs/design/buildables_plan.md` B6a/B6b (lines 231-267) approves the set (coordinator approval 10 Nov). So the design is approved (CATALOG) but only data rows exist; the water graph chain is not built. `wool_rug` is FUTURE: ledger FUTURE-GATED, items.json future:true, recipe wool_rug_kit locked.
- The draft already shows these rows with static flags BLUEPRINT_LOCKED, BLUEPRINT_NOT_KNOWN, STRUCT_NOT_BUILDABLE_STATIC (work/goals_parsed.json).

**Recommendation:** Mark all 24 as not playable (deferred) until the blueprints are unlocked by Dave-approved implementation; do not pay coins or show them in the Journal. Re-enable per piece when `locked` is removed and a learn route exists. Do not edit the catalog (freeze): report only.

### C-02 [MEDIUM] Door, doorway and Crude - Roof 65 goals target content not yet player-verified

**Affected goals:** 57 goals (2751 copper; Main: `build:thatch_doorway`, `build:thatch_roof_65`, `build:refined_door`, `build:rustic_door`, `build:sturdy_door`, `build:superior_door`, `build:engineered_door`, `build:fortified_doorway`, `build:fortified_door`): all door and doorway goals of the seven tiers plus `build:thatch_roof_65`

**Evidence:**
- Ledger: entries 1255-1303 (49 goals) are IMPLEMENTED - UNVERIFIED; the 8 pre-existing doorways (thatch_doorway, log_doorway, doorway_section, double_doorway, stone_doorway, brick_doorway, engineered_doorway, fortified_doorway) were changed by BUGLIST-002 but their ledger rows still read NO CHANGE (stale), and BUGLIST-002 LEDGER.md marks them NEEDS PLAYER VERIFICATION. Ledger keys (`catalog_ledger.json` keys thatch_roof_65, thatch_double_doorway ... fortified_double_arched_door).
- `docs/ai-team/missions/BUGLIST-002/LEDGER.md`: every row NEEDS PLAYER VERIFICATION; icons BLOCKED (art lane); picture lanes NOT RUN. `docs/ai-team/missions/BUGLIST-001/construction-pieces.md`: BUG-011 NEEDS PLAYER VERIFICATION; question open on Crude - Roof corner (still a post-supported hip, so it no longer matches the post-free Roof 45/65).
- Verified against Dave's rulings (CREATOR, BUGLIST-002 CONTRACT/LEDGER 13 Nov 2026 14:41-15:15Z): 56 door/doorway goals = 28 doorways + 28 doors; every blueprint with "door" in its name has a goal and none is missing; names are `<Tier> - [Double ][Arched ]door[way]` with no "Single"; no Iron/Steel doorway goal (iron_doorway, steel_doorway retired in items.json and blueprints.json, no structure row); all 28 door blueprint costs equal the master s3.0 approved table exactly (script comparison, 0 mismatches); frames cost their tier wall (e.g. blueprints thatch_doorway = thatch_wall = 3 twine, 20 thatch, 6 stick).
- Draft ordering: Main route holds Rustic/Refined/Sturdy/Superior/Engineered/Fortified doors but only the Crude and Fortified doorways; the other doorways are Additional. A door only places into a doorway (`PlacementRules.doorway_fit`, BUGLIST-002 decision 1), though any tier door fits any frame.

**Recommendation:** Keep the goals but flag them "needs player verification" and gate rewards on Dave's F6 check; consider moving one doorway per tier next to its door, or accept that the Crude doorway serves every Main door. Resolve the Crude - Roof corner question with Dave.

### C-03 [MEDIUM] Legacy runtime goals overlap the new craft/build rows

**Affected goals:** 36 goals; see table in section 5

**Evidence:**
- Legacy goals are live runtime goals: `data/items/starter_goals.json` and `camp_goals.json` are loaded at `src/stream/server_items.gd:15635-15640` (their `_about` still says "read by nothing yet": stale).
- knife: check is only `carcass_worked` yet the title crafts the knife = `craft:stone_knife` (Main). bed: legacy places a rough bed made by hand = `craft:rough_bed_kit`. workbench: check `what_any: [workbench, log_workbench]` so placing the Carpenter's bench (`build:log_workbench`) completes it. hammer: `have_item_any` includes stone_hammer (`craft:stone_hammer`). hoe: `have_item_any` wooden_hoe, stone_hoe, steel_hoe (`craft:stone_hoe`, `craft:steel_hoe`; iron_hoe not in list). fire / `activity:place_campfire` / `craft:campfire_kit`: one chain, three payments. fell / `gather:log`. spear / `craft:wooden_spear` (prerequisite inside the same recipe chain). `gather:pine_tar` text includes making Tar = `craft:tar`. winter_store re-counts four goals' outputs.
- No craft rows exist for stone_axe, wooden_hammer, wooden_hoe, spear, torch, candle, twine, smoked_fish, dried_berries, jerky, salted_fish (the legacy goals are their only goal), so no item is paid twice by identical rows; the overlap is in completion effect.

**Recommendation:** Decide per pair whether the legacy goal or the new row is canonical; keep legacy ids (saved goals_done) and make the new row a different action (for example craft vs place vs light) or drop it. Do not delete anything without Dave.

### C-04 [LOW] 70 craft goals are intermediate components that could be grouped

**Affected goals:** 70 goals, 728 copper, 24 in Main; see section 6

**Evidence:**
- Definition used: item is kind material (or a prep-stage food: Unbaked/Uncooked/batter) and at least one live recipe or blueprint consumes it (script over recipes.json needs/keeps and blueprints.json cost).
- Counts of live consumers: nails 27, hinges 14, iron_band 15, rivets 12, lumber 70, hardwood_board 38, leather 43, thread 30, mortar 35, iron_ingot 80, steel_ingot 41, concrete 19.

**Recommendation:** Group, not remove: keep the gating milestones (iron ingot, Iron - Saw, Plank, Hardwood board, leather, steel ingot) as single goals, and group the rest by family as in section 6 (fasteners, bronze route, leather chain, cloth, masonry, roof coverings, wood processing, machine parts, prep-stage foods). Ammunition tiers (10 goals) are consumables, not intermediates, and can be one "make ammunition" group.

### C-05 [LOW] Names: all craft/build titles match data names; five other title/name conflicts

**Affected goals:** `craft:firewood`, `gather:tannin_bark`, legacy `workbench`, `bed`, `hoe`, `spear` (name_ok=false in the JSON)

**Evidence:**
- Method: for 598 craft/build goals, the title minus "Craft "/"Build " was compared with the data item name (recipe output) or blueprint name; all match except `craft:firewood` (title "Split your first firewood"; data name "Hard firewood", items.json key firewood; recipe chopping_hard_firewood).
- Approved-name checks that PASS: master s3.0 (no "Single", tier names Crude, Rustic, Refined, Sturdy, Superior, Engineered, Fortified), BUGLIST-001 "Crude - Roof 45"/"Crude - Roof 65", no goal for Wooden - Pack frame (retired, items.json key wooden_pack_frame), backpack rows say weight only (no bag slots; data: backpack, leather_backpack, wicker_pack_basket, travellers_rucksack have carry_bonus_kg 12/18/8/24 and no bag_slots), no Iron/Steel doorway, no retired name (Anvil, Saw blade, Woodworking table, Brick - Forge, Large forge, Master forge, Stone - Sickle, Stone - Spade, Wooden - Chair, Iron - Chair: 0 occurrences in the draft).
- Conflicts: (1) `gather:tannin_bark` title and text say "tannin bark" but items name is "Tanbark" (gathered.json key tannin_bark) and the draft's own recipe rows say Tanbark. (2) Legacy titles "Build a Workbench" (blueprint "Wooden - Workbench"; buildables_plan.md line 28), "Make a hoe" ("Wooden - Hoe"), "Make a spear" (item `spear` is "Stone - Spear"; ambiguous with Wooden - Spear), "Make a bed" ("Thatch - Bed") are generic. (3) Ledger/Appendix A names differ from data for 20 goals (Brick - Forge vs Smithy, Large forge vs Blast furnace, Master forge vs Master smithy, Wooden - Bow vs Shortbow, Wooden block vs Hardwood block, Softwood firewood vs Soft firewood, Wooden - Chair/Table/Chest/Bench vs Rustic/Rustic/Rustic/Crude, Iron - Bench/Chair/Table vs Fine, Iron - Chest vs Ornate, Lumber Rack vs Board rack, Axle Assembly vs Axle, Storage Sign / Ledger vs Storage sign, Bottle & Jar Rack, Ore & Metal Rack, Longbow). These are Appendix A pre-rename names; master section 3 text explicitly delegates the data names (e.g. master lines 337-338 Shortbow/Longbow, 741 "Axle", 906 "Board rack", "Ore and metal rack", "Bottle and jar rack"; 2.7.7 Smithy/Blast Furnace/Master Smithy; 3.5 grades Crude/Rustic/Fine/Ornate). Draft titles therefore use APPROVED names; Appendix A is the stale side (master header says Appendix A is an unreconciled older snapshot).
- Group-label titles: "Obtain softwood logs" / "Obtain hardwood logs" name ingredient groups whose key items are Spruce log and Oak log (`wood_species.json` ingredient_groups.log_spruce, log_oak).
- Goal ids are legacy structure keys and no longer match names (build:chair = Rustic - Chair, build:iron_chest = Ornate - Chest, build:iron_bench = Fine - Bench, build:thatch_* = Crude, build:log_* = Rustic, build:stone_* = Sturdy, build:brick_* = Superior, build:wood_* / wall_section = Refined). Never derive a display name from the id.

**Recommendation:** Use the title as written for craft/build; fix the Tanbark title; rename or annotate the four generic legacy titles only if Dave wants them to show item names (they are existing runtime titles).

### C-06 [LOW] Stale or inaccurate legacy hint text copied into the draft

**Affected goals:** `smoke_fish`, `dry_berries`, `salted_fish`, `fish`, `night_walk`, `fur_for_winter`, `activity:chop_log_blocks`

**Evidence:**
- smoke_fish how-text: "smoke it with samphire and juniper berries at the campfire"; live recipe cook_smoked_fish = 1 fish + 1 Salt at the Smoker (recipes.json). dry_berries: "by the fire"; live recipe cook_dried_berries = 3 berries at the Drying rack. salted_fish: "a fish"; recipe needs Trout (cook_salted_fish). fish: starter hint "2 sticks, 2 twine" but fishing_rod needs stick, twine and hook (recipes.json). night_walk: code counts a torch carried in the pack or standing within 4 m of a lit fire between hours 19 and 6 (`server_items.gd:15185-15186`), not a lit torch. fur_for_winter: threshold is worn warmth >= 0.7 (`server_items.gd:15188`), not literally "a full hide set". chop_log_blocks: draft says "wooden blocks"; data names are Large wooden block / Large softwood block (small: Hardwood block / Softwood block).

**Recommendation:** Refresh the instruction text from the live recipes before any goal is shown (accuracy rule in the draft header). Hand to the UI/text workstream.

### C-07 [MEDIUM] Classification problems

**Affected goals:** see list

**Evidence:**
- Crafts of placeables (goal completes on crafting, placing is separate): `craft:campfire_kit` (item "Campfire", kind placeable), `craft:chopping_block`, `craft:rock_pile`, `craft:snare`, `craft:rough_bed_kit` (Thatch - Bed; hand craft by Dave 4 Nov, blueprint 24 retired), `craft:serving_platter`. Only the campfire and chopping block have a separate placement goal. These are legitimate hand crafts (items.json kind placeable, recipes with no station), not mis-labelled builds.
- No build goal is really a hand craft: all 256 build goals have a hammer blueprint row (blueprints.json), and the two blueprint-less structures (`lean_to`, `workbench`) are legacy goals.
- "gather" goals that are really hunting/butchering: `gather:hide`, `gather:bone`, `gather:animal_fat` (sources carcass.json species.*.parts; event carcass_worked); `gather:log` is felling; `gather:clay`/`sand` are digging; `gather:wool` has only carcass-part sources (wild_sheep, bighorn) and no shearing mechanic was found.
- Activity goals with no goal event: `activity:medium_fire`, `activity:bonfire`, `activity:chop_log_blocks` (the only emitted events are drink, ate_food, fire_lit, carcass_worked, dug_under, path_laid, tree_felled, fish_caught, placed, wanted_order, sold: `_goal_event` calls in src/stream/*.gd). Fire tiers exist in cooking.json fire_tiers; this is runtime work, not a catalog defect.
- Add-ons presented as ordinary builds: `build:bellows`, `build:quenching_trough` (structures.json addon_of brick_forge; master s2.7.5 [D4]: add-ons, not workstations), `build:tool_rack`, `build:vice` (addon_of workbench), `build:fireplace_cooking_crane` (addon_of fireplace). Cargo/vehicle: `build:wooden_crate`, `build:warehouse_crate`, `build:handcart`.

**Recommendation:** Annotate rather than reclassify; the add-on rows need their parent station mentioned in the how-text (stations workstream).

### C-08 [MEDIUM] Live recipes exist for FUTURE items (catalog problem, report only)

**Affected goals:** no goal affected (goals correctly omit them)

**Evidence:**
- recipes.json: steel_striker (#183, known:true, station brick_forge, 1 steel_ingot) -> items.json steel_striker future:true (ledger FUTURE-GATED, note M001-T09 "row stays FUTURE"). `src/shared/recipe_table.gd:49` reads known/locked only, no future filter, so a player at a Smithy can craft a FUTURE item. obsidian_knife (needs obsidian, FUTURE), butter and cheese (need milk, FUTURE) are live recipes but their inputs cannot be obtained, so they are inert.
- Also locked recipes for future outputs: bonemeal, fish_trap, bird_trap, pickled_vegetables, copper_pot, fish_soup, claw_necklace (all locked+future: consistent).

**Recommendation:** Dave/catalog owner to decide: lock or retire the steel_striker recipe, or release the item. Not changed (freeze).

### C-09 [INFO] Master catalog vs implementation: retired stations are consistent; four KEEP rows are not buildable

**Affected goals:** none

**Evidence:**
- Clay bloomery (#795): items.json retired; structures.json clay_bloomery retired:true; recipe bloomery_iron retired:true; blueprint retired. The task premise that it is "still a recipe station" does not hold at dc2fa52. Remaining references are cosmetic or test names: showroom.json, weights.json, building_wear.json, looks.json, design_names.json, encyclopedia.json, tests test_bloomery_bench.gd etc.
- Woodworking table (#243): items.json retired, structures retired, recipe fine_board retired (still names station woodworking_table, harmless). Anvil (#827) retired with addon_of brick_forge row retired. All species lumber_*/beams_* recipes are retired (recipes.json; 44 retired recipes also still carry locked), consistent with master s2.3.6; the 7 locked-and-not-retired recipes are all FUTURE outputs.
- Log - Bench (#629), Log - Table (#631), Log - Trough (#719), Log - Shelf (#848): items.json rows live, ledger KEEP/NO CHANGE (master Appendix A lines 1797, 1798, 1885 and s3.5 line 314, 829 say retired blueprints, "placed shelves in old saves keep working"), but structures.json retired:true and their blueprints retired. Not obtainable; no goals (correct).

**Recommendation:** No goal impact. Note for the catalog owner: item rows should carry retired:true to match their structure rows (not changed).

### C-10 [INFO] Tool ladders and station set verified complete against master s2.1

**Affected goals:** all

**Evidence:**
- Master s2.1 ladders vs data (items.json tool_class/material) vs goals: Axe stone (legacy axe), bronze, iron, steel; Pickaxe stone, bronze, iron, steel; Spade wooden, iron, steel (no stone, no bronze); Hammer wooden (legacy), stone, bronze, iron, steel; Hoe wooden (legacy), stone, iron, steel (no bronze); Knife stone, bronze, iron, steel; Hand saw iron (`craft:hand_saw`, Iron - Saw), steel; Sickle bronze, iron, steel; Scythe bronze, iron (id `scythe`), steel; Chisel bronze, iron, steel; one Bone - Needle. Every one has a live item and a goal; no extra tier exists in data.
- Stations with recipes: all 23 station ids used by live recipes map to a goal or are built by one (campfire is a fire entity, chopping_block is a craft+place pair, workbench is the legacy goal). `brick_forge`, `forge`, `blast_furnace` are station names carried by blacksmithy (Smithy), stone_forge and large_forge structure rows (`structures.json` station fields), so no goal is missing.
- Live blueprint coverage: 234 live blueprints, 232 have a build goal, the other two (lean_to, workbench) are legacy goals.

**Recommendation:** None.

### C-11 [LOW] Hob sells some goal items

**Affected goals:** `craft:bandage`, `craft:waterskin`, `craft:wooden_bowl`, `craft:rope`, `craft:stone_knife`, `craft:wooden_spade`, `craft:backpack`, `craft:roast_forage`, legacy `axe`, `torch_night`, `twine`

**Evidence:**
- `data/npcs/shops.json` hob.stock: stone_axe, stone_knife, wooden_spade, torch, twine, rope, plant_fibre, bandage, waterskin, wooden_bowl, backpack, roast_forage, firewood, stone, stick.
- Legacy goals use `made_item` for crafts (counted when a craft finishes) but `have_item` for fibre, hammer, hoe, winter_store, fish, so buying could complete the have-type goals.

**Recommendation:** Runtime workstream to confirm each craft goal listens to crafting, not holding.

### C-12 [INFO] Status of gathered and other raw items for the 20 gather goals

**Affected goals:** 20 gather goals

**Evidence:**
- All 20 target live raw items with a data source lead (source_mentions.json): stick, stone (ground, boulders), plant fibre, log groups, thatch (drops.json harvest_yield.thatch_grass), clay and sand (digging.json), hide, bone, animal fat (carcass.json), flint (boulders.json), tannin bark (flora.json mangrove, drops.json oak), iron/copper/tin ore and limestone (boulders.json, digging.json bog_iron), pine tar (drops.json scots_pine), flax (crops.json, drops.json seed_drops), wool (carcass.json wild_sheep, bighorn only). A mention is a lead, not proof it works in play (acquisition workstream).

**Recommendation:** None here.
## 3. Inventory and coverage tables

### 3.1 Inventory counts (all rows in the data tables, dc2fa52)

Item ids = items.json (1120 rows) + gathered.json (175 rows) = 1295, loaded together by `src/shared/item_table.gd:6-9`. Definitions in `ws_catalog.json` `inventory_counts._notes`.

| Category | Implemented | Approved, not implemented | Future | Retired | Unknown |
|---|---|---|---|---|---|
| material | 176 | 0 | 9 | 73 | 0 |
| tool | 53 | 0 | 2 | 12 | 0 |
| weapon | 45 | 0 | 1 | 0 | 0 |
| placeable | 6 | 0 | 4 | 186 | 0 |
| food | 135 | 0 | 7 | 1 | 0 |
| medicine | 5 | 0 | 0 | 0 | 0 |
| structure | 244 | 23 | 16 | 9 | 0 |
| container | 8 | 0 | 1 | 0 | 0 |
| gear | 14 | 0 | 20 | 1 | 0 |
| clothing | 63 | 0 | 1 | 1 | 0 |
| coin | 0 | 0 | 4 | 0 | 0 |
| material(gathered.json) | 165 | 0 | 3 | 7 | 0 |
| recipes | 414 | 0 | 11 | 125 | 0 |
| blueprints | 234 | 23 | 1 | 10 | 0 |
| structures_rows | 283 | 23 | 1 | 7 | 0 |
| materials_and_food_unknown_source | 0 | 0 | 0 | 0 | 0 |

### 3.2 Live crafted items vs goals

| Category | Live crafted | Craft goal | Legacy goal only | No goal |
|---|---|---|---|---|
| clothing | 63 | 63 | 0 | 0 |
| container | 8 | 8 | 0 | 0 |
| food (cooked, prepared, preserved) | 94 | 90 | 4 | 0 |
| gear (packs, quivers, bags) | 14 | 14 | 0 | 0 |
| material (intermediates, ingots, boards) | 70 | 67 | 1 | 2 |
| medicine | 5 | 5 | 0 | 0 |
| placeable (hand-crafted) | 6 | 6 | 0 | 0 |
| tool | 50 | 45 | 5 | 0 |
| weapon and ammunition | 45 | 44 | 1 | 0 |

Legacy-only: stone_axe, wooden_hammer, wooden_hoe, torch, candle (tools), spear (weapon), twine (material), smoked_fish, dried_berries, jerky, salted_fish (food). No goal: kindling, tinder (materials, add candidates). Blueprints: 234 live, 232 with a build goal, 2 legacy (lean_to, workbench). Raw items (no recipe, no blueprint): 20 gather goals plus ~165 forage materials, 45 wild foods/fish/fruit, crops, seeds, bushes with no goal (add candidates group them).

## 4. (a) Eligible content with no goal: add candidates

Catalog freeze: these are recommendations, not additions. Each needs a Dave decision and, for activities, a server goal event that does not exist yet (only the events listed in C-07 are emitted).

| # | Proposed id | Title | Kind | Group | Why / evidence |
|---|---|---|---|---|---|
| 1 | `craft:kindling` | Craft Kindling | craft | Fire starting (group with tinder as ONE goal) | Live hand craft with no goal (only legacy starter reward gives kindling). cooking.json lists kindling as a weak fuel class. Teaches fire lighting inputs. Evidence: recipes.json recipe kindling (#178): 1 Stick -> 3 Kindling, by hand, known:true; item resolves to gathered.json item 1080 (items.json kindling_duplicate note) |
| 2 | `craft:tinder` | Craft Tinder | craft | Fire starting (group with kindling) | Live hand craft with no goal; cooking.json tinder class. Evidence: recipes.json recipe tinder (#229): 2 Thatch -> 2 Tinder by hand, known:true |
| 3 | `activity:cook_on_campfire` | Cook meat or fish on a campfire | activity | Cooking basics | Roast Meat/Fish/Shellfish/Seal items (items.json roast_meat, roast_fish, roast_shellfish, roast_seal) have no recipe and no goal; this is the first cooking step before pots and hearths. Needs a new goal event (none emitted for cooking). Evidence: data/items/cooking.json cooks_into (raw meat and fish); src/stream/server_items.gd _plant_food_at_fire ~15541 and its helpers; test_cooking_route.gd exists (not run) |
| 4 | `activity:till_garden_bed` | Till soil into a garden bed with a hoe | activity | Farming (till, sow, harvest) | Farming starts with the hoe; build:*_garden_plot goals teach framed plots but not tilling. Needs a goal event. Evidence: structures.json tilled_bed (state-only row, no blueprint); hoe modes in master s2.1 (Create Garden Plot); test_farming.gd (not run) |
| 5 | `activity:sow_seed` | Sow a seed in a bed | activity | Farming (till, sow, harvest) | Seeds and 12 crops exist; no goal teaches sowing or harvesting. Evidence: server_items.gd sow() line 14635; data/items/crops.json (12 crops, sow_season); test_farming.gd |
| 6 | `activity:harvest_crop` | Harvest a ripe crop | activity | Farming (till, sow, harvest) | Pairs with sowing; sickle ladder (Bronze, Iron, Steel) is only taught as three craft goals. Evidence: server_items.gd harvest() line 14757; crops.json tool_to_harvest sickle/hand |
| 7 | `activity:plant_bush` | Dig up a bush and replant it | activity | Foraging and planting | 23 live bush items (kind material) have no goal and no recipe. Evidence: server_items.gd 7116-7195 (_plant_bush); drops.json shrub_work dig_suffix _bush; 23 *_bush items |
| 8 | `activity:set_snare` | Set a snare | activity | Hunting and trapping | craft:snare (Additional) crafts the placeable but nothing teaches setting it; fish and bird traps are FUTURE and correctly absent. Evidence: recipes.json snare; structures.json snare_trap; test_traps.gd (not run) |
| 9 | `activity:sharpen_tool` | Sharpen a tool on a whetstone or grindstone | activity | Tool care (sharpen, repair) | craft:whetstone and build:grindstone exist as goals but the sharpening mechanic itself, central to metal tools, has no goal. Evidence: server_items.gd _start_sharpen 6181, _grindstone_station 6196, _whetstone_slot 6219; master s2.2 items 6-8; test_whetstone.gd, test_tool_care.gd (not run) |
| 10 | `activity:repair_tool` | Repair a worn or broken tool | activity | Tool care (sharpen, repair) | Break/repair rules are live (Phase 2c TESTED - ACCEPTED in ledger) and untaught. Evidence: server_items.gd _repair 6116 (workstation repair, master s2.2 item 5); server_trade.gd _repair_deal 498 (NPC repair) |
| 11 | `activity:repair_building` | Repair a damaged building piece with a hammer | activity | Tool care (sharpen, repair) | Live mechanic with no goal. Evidence: server_items.gd _repair_struct 8557; data/items/building_wear.json |
| 12 | `activity:sleep_in_bed` | Sleep through a night in a bed or lean-to | activity | Rest and comfort | Legacy goals only place the lean-to and bed; sleeping (and its comfort rules) is never a goal. Evidence: server_items.gd _sleep 10379, sleep_quality 10801; test_bed.gd, test_lean_to_bed.gd (not run) |
| 13 | `activity:store_in_chest` | Put items in a chest or crate | activity | Storage and locks | Many storage build goals but no goal for using one. Evidence: structures.json slots containers (chest, wicker_basket, plank_chest ...); test_storage_locks.gd |
| 14 | `activity:set_container_code` | Lock a chest with a four-digit code | activity | Storage and locks | Phase 9 TESTED - ACCEPTED (ledger); owner locks are a headline storage feature. Evidence: server_items.gd ~16255-16380 (Phase 9 locks); structures.json lockable rows; test_storage_locks.gd |
| 15 | `activity:haul_with_handcart` | Move a loaded crate with a Handcart | activity | Storage and locks | build:handcart, craft:axle, craft:wooden_cart_wheel exist; hauling does not. Evidence: structures.json handcart vehicle; server_carts.gd; test_handcart.gd; ledger Phase 10 TESTED - ACCEPTED |
| 16 | `activity:craft_tempered_item` | Craft a Tempered steel item at a Smithy with a Quenching trough | activity | Smithing mastery | build:quenching_trough (Smithy add-on) exists but its purpose is never taught. Instance-level property, needs a new event. Evidence: server_items.gd 16948 (variant codes), 17081; master s2.7.5 [C7]; test_tool_care.gd |
| 17 | `activity:craft_masterwork` | Craft a +1/+2 craftsmanship item at the Master smithy | activity | Smithing mastery | build:master_forge exists as a Main goal with no goal for what it unlocks. Evidence: master s2.7.6, s2.9; ledger Phase 2c; server_items.gd 16948 |
| 18 | `activity:burn_kiln_charcoal` | Burn a kiln batch of charcoal | activity | Kiln and fuel | build:kiln has a goal but only for its brick/lime recipes; the log-to-charcoal batch is the kiln feature master s2.6 describes. Evidence: structures.json kiln batch_logs 6, per_log 100; recipes.json kiln_charcoal is RETIRED (kiln batch use replaces it); master s2.6 |
| 19 | `activity:buy_from_trader` | Buy something from Hob | activity | Trading | Legacy goals teach selling and an order but not buying; 15 items are on sale. Evidence: data/npcs/shops.json hob.stock; server_trade.gd; test_trade.gd |
| 20 | `activity:preserve_in_jar` | Seal a batch in the Preserving jar and wait for it to mature | activity | Food preservation | craft:sauerkraut is a goal but the maturing mechanic (sealed batch, unusable until ready) is the point of the jar. Evidence: recipes.json cook_sauerkraut ready_age 48 h (preserving_jar); master s3.14; ledger Phase 6 |
| 21 | `activity:serve_platter` | Place a Serving platter with food on a table | activity | Food preservation and serving | craft:serving_platter and eight board goals exist; placing and serving them is not taught. Evidence: recipes.json serving_platter; test_serving_platter.gd; master s3.15 [D15] |
| 22 | `activity:eat_prepared_meal` | Eat a prepared meal for a temporary food effect | activity | Cooking basics | Temporary food effects are the reason for ~90 cooked-food goals; no goal teaches reading or using them. Evidence: master s3.16 [D16][D17]; test_food_effects.gd; ledger Phase 7 |
| 23 | `activity:place_torch` | Wedge a torch into a wall or stand | activity | Light and night | Two live state-only structure rows with no goal; legacy goals only craft and carry a torch. Evidence: structures.json standing_torch, torch_sconce (hand_placed, kit_out torch_doused) |
| 24 | `activity:forage_new_plant` | Forage a new herb, nut or fruit (discovery goals) | gather | Foraging and planting | Per-item gather goals would add ~165 goals; recommend a few counted discovery goals instead (for example 5 different herbs, 5 different nuts and fruits, 5 different mushrooms). Do not invent acquisition methods: each material needs the acquisition workstream first. Evidence: gathered.json 165 live plant materials, 9 FUTURE; wild_foods.json; flora.json |
| 25 | `activity:catch_different_fish` | Catch several kinds of fish | activity | Fishing | Fishing methods: rod, net (craft:shore_net), hook; one legacy goal only. Evidence: data/items/fishing.json, fish_schools.json; test_fishing.gd; legacy fish goal accepts any one fish |
| 26 | `activity:mine_ore_with_pick` | Mine a boulder with a pickaxe | activity | Mining and digging | gather:iron_ore, copper_ore, tin_ore, limestone text covers it by item; a single mining-action goal would teach tool-tier requirements (boulders.json ore needs_material). Evidence: boulders.json ore items; pickaxe ladder Stone/Bronze/Iron/Steel |

Correctly absent (no goal expected): animal tack, animal vehicles, Riding - Boots, Steel bolt, Iron - Lance, Ploughman's board, coins, Cheese/Milk/Butter, Spinning wheel, Chicken coop and other FUTURE-GATED rows (65 ledger rows: Phase 11/12 not authorized, `docs/design/CATALOG_IMPLEMENTATION_PLAN.md`); enchantments (Phase 12); taming (Phase 11). Retired rows have no goals.

## 5. (c) Duplicates and near-duplicates

| Goal | Overlaps with | Basis |
|---|---|---|
| `craft:stone_knife` | `knife` | legacy knife title crafts the same item |
| `fell` | `gather:log` | felling yields the log |
| `gather:log` | `fell` | collect the log from felling |
| `hammer` | `craft:stone_hammer` | have_item_any includes stone_hammer |
| `craft:campfire_kit` | `activity:place_campfire`, `fire` | craft/place/light chain |
| `activity:place_campfire` | `craft:campfire_kit`, `fire` | craft/place/light chain |
| `fire` | `activity:place_campfire`, `craft:campfire_kit` | craft/place/light chain |
| `craft:chopping_block` | `activity:place_chopping_block` | craft then place |
| `activity:place_chopping_block` | `craft:chopping_block` | craft then place |
| `bed` | `craft:rough_bed_kit` | same hand craft; also places |
| `workbench` | `build:log_workbench` | what_any also accepts log_workbench |
| `build:log_workbench` | `workbench` | completes legacy workbench |
| `gather:pine_tar` | `craft:tar` | text includes the Tar craft |
| `craft:tar` | `gather:pine_tar` | same step as pine tar text |
| `craft:wooden_spear` | `spear` | prerequisite of spear |
| `craft:stone_hammer` | `hammer` | completes legacy hammer |
| `craft:rough_bed_kit` | `bed` | same hand craft as legacy bed |
| `spear` | `craft:wooden_spear` | Wooden - Spear is a step of the Stone - Spear recipe |
| `craft:stone_hoe` | `hoe` | completes legacy hoe |
| `knife` | `craft:stone_knife` | check = carcass_worked; title also crafts the knife (craft:stone_knife) |
| `hoe` | `craft:steel_hoe`, `craft:stone_hoe` | have_item_any includes stone_hoe, steel_hoe |
| `dry_berries` | `winter_store` | counted by winter_store |
| `jerky` | `winter_store` | counted by winter_store |
| `salted_fish` | `winter_store` | counted by winter_store |
| `smoke_fish` | `winter_store` | counted by winter_store |
| `winter_store` | `dry_berries`, `jerky`, `salted_fish`, `smoke_fish` | re-counts the four preserved-food goals |
| `craft:steel_hoe` | `hoe` | completes legacy hoe |

Not duplicates (checked): no two goals share a recipe, a recipe output item, a structure, or a title (script check). Hard vs Soft firewood, Hardwood vs Softwood block, door vs doorway, torch vs night_walk are distinct items/actions.

## 6. (d) Intermediate-only components: suggested groups (do not remove)

| Group | Goals (route M=Main) | Rationale |
|---|---|---|
| fasteners | `nails` (M), `hinges` (M), `iron_band` (M), `rivets`, `wooden_pin` (M), `toggle`, `bronze_nails`, `bronze_hinges` | Small metal/wood fasteners consumed by builds; nails, hinges, iron band are Main milestones needed before furniture/doors: keep nails, group the rest as one "make fasteners" goal. |
| metal_ingots_bronze_route | `copper_ingot` (M), `tin_ingot` (M), `bronze_ingot` (M) | Copper, tin and bronze ingots are three steps of one bronze route; keep iron and steel ingots as separate milestones. |
| leather_chain | `processed_hide` (M), `leather` (M), `fine_leather`, `heavy_leather`, `leather_strap`, `hide_glue` | Processing steps of one chain (scrape, tan, grade, strap, glue); keep leather itself as the milestone. |
| cloth_and_thread | `thread` (M), `fibre_cloth`, `wool_cloth`, `linen` | Thread, fibre cloth, wool cloth, linen are textile feedstock for the Tailor's table/Loom. |
| masonry_materials | `cobblestone` (M), `mortar` (M), `cut_stone_block`, `carved_stone_block`, `lime_powder` (M), `concrete` (M), `brick` (M) | Stone/brick/lime/concrete feedstock; some Main milestones (brick, cobblestone, mortar, concrete) gate building tiers. |
| roof_coverings | `bark_shingle`, `stone_shingle`, `carved_stone_shingle`, `clay_roof_tile` (M), `wooden_shingle` | Five roofing coverings (bark, stone, carved stone, wooden shingle, clay tile) used in roof pieces; one goal "make a roof covering" fits. |
| wood_processing | `wooden_block`, `wooden_block_soft`, `lumber` (M), `hardwood_board` (M), `firewood` (M), `firewood_soft`, `charcoal` (M), `tar` (M) | Blocks, planks, boards, firewood, charcoal, tar: process outputs of the log; Plank and Hardwood board are gate milestones (keep). |
| vehicle_and_machine_parts | `axle`, `wooden_cart_wheel`, `water_wheel` (M) | Axle, wheel, water wheel exist only to build one Handcart/Sawmill each. |
| cooking_ingredients | `flour`, `sea_salt`, `tallow`, `lamp_oil`, `hook`, `horn_pane`, `rope` | Flour, salt, tallow, lamp oil, hook, horn pane, rope: ingredients/parts with a few consumers each. |
| prep_stage_foods | `banana_fritter_batter`, `unbaked_apple_pie`, `unbaked_chestnut_cakes`, `unbaked_fish_pie`, `unbaked_flatbread`, `unbaked_garlic_flatbread`, `unbaked_honey_loaf`, `unbaked_oatcakes`, `unbaked_trail_bread`, `unbaked_venison_pie`, `uncooked_crab_cakes`, `uncooked_meat_skewers`, `uncooked_mushroom_skewers`, `unbaked_rye_flatbread`, `uncooked_meatballs`, `uncooked_sausages` | Unbaked/Uncooked/batter items are the tangible prepare step before cooking (master s3.12 [D12]); each pairs with its cooked goal, so one goal per pair would remove 16 paid steps. |
| ungrouped intermediates | `iron_ingot`, `steel_ingot`, `wooden_arrow` | Materials consumed elsewhere but not in a family above: keep as is or fold into the nearest family. |

## 7. Master catalog vs implementation: mismatches that affect goals

| # | Topic | Master / documents say | Implementation says | Goal effect |
|---|---|---|---|---|
| M-1 | Approval status of the master catalog | DYNASTY_MASTER_ITEMS.md header still reads "DRAFT 18 ... SUBMITTED FOR DAVE'S FINAL APPROVAL ... NO IMPLEMENTATION AUTHORIZED"; CATALOG_IMPLEMENTATION_PLAN.md line 3 and catalog_ledger.json `catalog` say Dave approved Draft 18 on 12 Nov 2026 (Mission 001) and authorized Phases 0-10, 1b; Phases 11-12 not authorized | Phases 0-10 implemented (ledger: 230 TESTED - ACCEPTED, 23 RETIRED, 65 FUTURE-GATED); automated tests only, in-game checks NOT RUN (ledger acceptance_note) | Treat Draft 18 as CATALOG authority; the header text is stale. "Tested" never means player-verified. |
| M-2 | Locked water/garden pieces | KEEP/approved (ledger NO CHANGE; buildables_plan B6) | blueprints known:false, locked:true; unbuildable (C-01) | 24 goals not playable |
| M-3 | Clay bloomery, Woodworking table, Anvil | Retired (master s2.7, s2.3, ledger RETIRE) | Retired in items, structures, recipes and blueprints; no live recipe uses them | No goal; consistent |
| M-4 | Kiln charcoal | master s2.6: Kiln turns 3 m logs into 100 charcoal each, about six logs per batch | recipes.json kiln_charcoal is retired; the kiln structure row carries batch_logs 6, per_log 100 and use "kiln" (structures.json); charcoal goal uses the campfire recipe (2 firewood -> 12 charcoal) | craft:charcoal teaches the campfire route; kiln batch has no goal (add candidate) |
| M-5 | Firewood path | master s2.3.7: Log -> Blocks -> Firewood; s2.4: Chopping Block may take logs through blocks to firewood | Both exist: recipes chopping_hard_firewood/chopping_soft_firewood (1 log -> 12 firewood at chopping_block, needs axe kept) and the block's own use split_log (3 blocks per log, 2 firewood per block, 4 per large block; structures.json chopping_block) | craft:firewood how-text conflates them (already flagged in the draft); emit one event |
| M-6 | Steel - Striker | FUTURE (ledger FUTURE-GATED, M001-T09) | recipe 183 live and known at the Smithy (C-08) | No goal; possible craftable FUTURE item |
| M-7 | Pack ruling | master s3.9 rule 2 (D9) says a pack adds no carry power and rows 50/767 had bag slots | Dave 13 Nov 2026 11:35Z and 16:19Z (BUGLIST-001 backpack.md): no backpack has slots, only carry weight; data carry_bonus_kg 12/18/8/24, no bag_slots on the four back packs; Wooden - Pack frame retired (items.json 988). master text carries dated notes | Draft pack goals say nothing about slots: PASS |
| M-8 | Door system | master s3.0 and BUGLIST-002 (Dave 13 Nov): empty frames, separate doors, seven tiers, no "Single", Iron/Steel doorways retired | Implemented at the exact approved costs; 48 new pieces + the roof IMPLEMENTED - UNVERIFIED, 8 existing doorways NEEDS PLAYER VERIFICATION | 56 goals PASS content check; verification pending (C-02) |
| M-9 | Crude - Roof | BUGLIST-001: Crude - Roof 45 and 65 (names are a lead ruling, flagged for Dave) | structures thatch_roof (45), thatch_roof_65 (state 291, item 1255); thatch_roof_corner still has posts | 2 goals PASS; corner open question |
| M-10 | Hand saw, hammer and other ladders | master s2.1 | Match data and goals (C-10) | None |
| M-11 | Master smithy and Quenching trough | master s2.7.5-6: add-on and prestige station that change instance quality (Tempered, +1/+2) | structure rows exist (master_forge, quenching_trough addon_of brick_forge); recipes make variants through variant codes (`server_items.gd:16948`, 17081) | build goals fine; the capability they unlock has no goal |
| M-12 | Appendix A of the master catalog | Generated 889-row snapshot, "not current door design instructions", hand-edited for doors | Data now 1295 item ids; names in Appendix A differ for 20 goal items (C-05) | Use section 3 and the ledger, not Appendix A, for names |

## 8. Verification limits

- Static reading and scripts only (CODE_VERIFIED). No test was run; test files cited (test_farming, test_traps, test_whetstone, test_tool_care, test_bed, test_lean_to_bed, test_storage_locks, test_handcart, test_trade, test_cooking_route, test_serving_platter, test_food_effects, test_fishing) were checked for existence only and not read for exact assertions.
- `IMPLEMENTED` means live in data and intended to work; it does not mean obtainable in play (acquisition workstream) or visually checked (ledger: no in-game visual, UI or two-client checks were run; most new pieces use placeholder looks; grindstone shares the chopping_block look in structures.json).
- Source mentions are leads. Items marked unknown count is 0 only after excluding derived world states and group pseudo-items (listed in `inventory_counts._notes`).
- Not checked: station-level and add-on proximity rules of individual blueprints, reward values, text accuracy beyond the names and the legacy hints in C-06 (other workstreams).