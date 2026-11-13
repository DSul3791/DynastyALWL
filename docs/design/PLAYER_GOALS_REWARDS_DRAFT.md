# Dynasty — Goals & Coin Rewards: Complete First-Pass Catalog

**Status: PROPOSED / REVIEW DRAFT — NOT YET AUTHORIZED FOR GAMEPLAY IMPLEMENTATION.** Dated 13 November 2026. This document records ChatGPT's first catalog-wide ordered goal and reward proposal for creator review. The master item catalog remains authoritative for item design; this document becomes authoritative for goal titles, ordering and coin payouts only after the creator approves a reviewed final revision.

## Source of truth and method

- Repository `DSul3791/DynastyALWL`, branch `dev`. Master catalog: `docs/design/DYNASTY_MASTER_ITEMS.md`; catalog implementation/future phase authority: `docs/design/CATALOG_IMPLEMENTATION_PLAN.md` and the active catalog ledger.
- Current production definitions: `data/items/items.json`, `recipes.json`, `blueprints.json`, and `structures.json`. Existing automatic goals: `data/items/starter_goals.json` (18) and `data/items/camp_goals.json` (10), currently loaded by `src/stream/server_items.gd`; the JSON `_about` headers calling them proposals are obsolete relative to runtime code.
- One goal is proposed for each active distinct producible item output and each active buildable blueprint, plus the existing 28 goals and a small set of raw-material milestones. Alternative crafting recipes for the same output do **not** create duplicate paid goals. Existing goals that already check a specific output/build are not duplicated.
- Recipe dependency depth is calculated from actual ingredients, retained tools, required placed workstations, station levels and hammer tiers. A lower depth is placed before its dependents. `fuel`, `axe`, `saw`, `hammer`, `knife` are broad item groups; for this static first pass, an available representative tool/material path was used. All paths still require actual-game verification.
- **Currency:** 10 copper = 1 bronze, 10 bronze = 1 silver, 10 silver = 1 gold. Rewards are one-time per character; the purse uses integer *copper equivalents*. The denominations below are display values only.

## Rules to review and finalize

1. Goals run **automatically**, with no accepting, activation, manual tracking, submission or reward claiming. A player may complete any eligible goal regardless of the HUD, journal selection, or the authored display order. Never create a crafting/technology unlock restriction.
2. All reward types become **coins only**. In the original starter goals, `twine` awards Sticks and `fell` awards Kindling: this draft proposes copper equivalents instead. The `story` goal's reputation point would be removed from its goal reward. Current paid goal IDs must never re-award on save/reload.
3. The draft proposes small early rewards, gradually rising for complex production; stations pay a little more. Reward amounts are **not yet approved**. Audit total currency issuance, item sales values and first-hour earnings before locking the plan.
4. Source item names/IDs and crafting paths must be rechecked against the *current* master catalog, especially 28 separate door configurations (each door is an item; doorways are empty frames), arched vs straight recipes, Crude roof 45/65, and existing enhancements. Do not turn proposed/future/retired content into completable goals.
5. This is a full first pass of **current recipe and blueprint outputs**, not an assertion that every active natural resource, loot drop, animal drop, crop, interactable, trade good or other non-recipe acquisition has an approved goal. Audit those separately before declaring total master-catalog coverage.
6. Current `G` also controls Admin Fly, inventory Store All and a debug probe; `J` controls a jitter test. Reassign only with a full keybinding audit. `J` opens Journal Index, `G` Goals, `M` Map. Journal/Goals must match Inventory/Crafting art; upper-right HUD is just a thin box headed 'Goals' and two point-form unfinished goals.
7. Completing a goal plays the ornate **Goal Achieved** placard with actual goal name and awarded coins, rotating into screen with an original/licensed short trumpet fanfare; queue simultaneous completions without double-paying or replaying on reload. The two PNG design references (blank editable and placeholder) are on Dave's PC at `C:\Users\david\Downloads\GoalAchieved`. Claude must inspect actual filenames and alpha channels before importing; use the blank placard for runtime text overlay.
8. Crucial UX issue for creator review: with hundreds of achievements, the first two unfinished goals across a strict list could be difficult/optional and crowd out helpful guidance. Keep all automatic rewards, but decide whether the HUD should display the first two of the *entire list* or a separately authored tutorial/major-progression subset. **Do not change the two-goal HUD rule without creator approval.**

## Goal and Reward

Only two visible columns, **Goal** and **Reward**. Source IDs are preserved as non-displaying Markdown comments inside the Goal cell to allow unambiguous future implementation.

### Immediate survival and gathering — dependency depth 0 (4 goals)

| Goal | Reward |
|---|---|
| Gather sticks <!-- gather:stick --> | 3 copper <!-- coin_copper:3 --> |
| Gather stones <!-- gather:stone --> | 3 copper <!-- coin_copper:3 --> |
| Drink at the water <!-- existing:drink --> | 2 copper <!-- coin_copper:2 --> |
| Gather plant fibre <!-- existing:fibre --> | 3 copper <!-- coin_copper:3 --> |

### Basic handcrafts and primitive materials — dependency depth 1 (39 goals)

| Goal | Reward |
|---|---|
| Twist twine <!-- existing:twine --> | 4 copper <!-- coin_copper:4 --> |
| Build Grindstone <!-- build:grindstone; structure:grindstone --> | 1 bronze <!-- coin_copper:10 --> |
| Build Oil press <!-- build:oil_press; structure:oil_press --> | 1 bronze <!-- coin_copper:10 --> |
| Build Preserving jar <!-- build:preserving_jar; structure:preserving_jar --> | 1 bronze <!-- coin_copper:10 --> |
| Build Smelter <!-- build:smelter; structure:smelter --> | 1 bronze <!-- coin_copper:10 --> |
| Build Smoker <!-- build:smoker; structure:smoker --> | 1 bronze <!-- coin_copper:10 --> |
| Build Stone - Forge <!-- build:stone_forge; structure:stone_forge --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Chopping block <!-- craft:chopping_block; recipes:chopping_block --> | 6 copper <!-- coin_copper:6 --> |
| Craft Bone - Arrow <!-- craft:bone_arrow; recipes:bone_arrow --> | 3 copper <!-- coin_copper:3 --> |
| Craft Bone - Needle <!-- craft:sewing_needle; recipes:sewing_needle --> | 3 copper <!-- coin_copper:3 --> |
| Craft Campfire <!-- craft:campfire_kit; recipes:campfire --> | 3 copper <!-- coin_copper:3 --> |
| Craft Clay mortar <!-- craft:mortar; recipes:mortar --> | 3 copper <!-- coin_copper:3 --> |
| Craft Compost <!-- craft:compost; recipes:compost_rotten,compost --> | 3 copper <!-- coin_copper:3 --> |
| Craft Fibre - Skirt <!-- craft:grass_skirt; recipes:grass_skirt --> | 3 copper <!-- coin_copper:3 --> |
| Craft Fishing bait <!-- craft:fishing_bait; recipes:fishing_bait_worm,fishing_bait_fish --> | 3 copper <!-- coin_copper:3 --> |
| Craft Hand mill <!-- craft:quern; recipes:quern --> | 3 copper <!-- coin_copper:3 --> |
| Craft Herb bandage <!-- craft:bandage; recipes:bandage_plantain,bandage_staunchmoss --> | 3 copper <!-- coin_copper:3 --> |
| Craft Herb salve <!-- craft:herb_salve; recipes:herb_salve --> | 3 copper <!-- coin_copper:3 --> |
| Craft Hook <!-- craft:hook; recipes:hook --> | 3 copper <!-- coin_copper:3 --> |
| Craft Mortar and pestle <!-- craft:mortar_pestle; recipes:mortar_pestle --> | 3 copper <!-- coin_copper:3 --> |
| Craft Rock pile <!-- craft:rock_pile; recipes:rock_pile --> | 3 copper <!-- coin_copper:3 --> |
| Craft Rope <!-- craft:rope; recipes:rope,fibre_rope --> | 3 copper <!-- coin_copper:3 --> |
| Craft Sling stone <!-- craft:sling_stone; recipes:sling_stone --> | 3 copper <!-- coin_copper:3 --> |
| Craft Stone - Arrow <!-- craft:stone_arrow; recipes:stone_arrow --> | 3 copper <!-- coin_copper:3 --> |
| Craft Stone - Knife <!-- craft:stone_knife; recipes:stone_knife --> | 3 copper <!-- coin_copper:3 --> |
| Craft Thread <!-- craft:thread; recipes:thread --> | 3 copper <!-- coin_copper:3 --> |
| Craft Toggle <!-- craft:toggle; recipes:toggle --> | 3 copper <!-- coin_copper:3 --> |
| Craft Whetstone <!-- craft:whetstone; recipes:whetstone --> | 3 copper <!-- coin_copper:3 --> |
| Craft Wicker - Shield <!-- craft:wicker_shield; recipes:wicker_shield --> | 3 copper <!-- coin_copper:3 --> |
| Craft Wooden - Arrow <!-- craft:wooden_arrow; recipes:wooden_arrow,quill_arrow,fibre_arrow --> | 3 copper <!-- coin_copper:3 --> |
| Craft Wooden - Bolt <!-- craft:wooden_bolt; recipes:wooden_bolt --> | 3 copper <!-- coin_copper:3 --> |
| Craft Wooden - Spade <!-- craft:wooden_spade; recipes:wooden_spade --> | 3 copper <!-- coin_copper:3 --> |
| Craft Wooden - Spear <!-- craft:wooden_spear; recipes:wooden_spear --> | 3 copper <!-- coin_copper:3 --> |
| Build Flower pot <!-- build:flower_pot; structure:flower_pot --> | 5 copper <!-- coin_copper:5 --> |
| Build Hide - Rug <!-- build:hide_rug; structure:hide_rug --> | 5 copper <!-- coin_copper:5 --> |
| Build Seat <!-- build:log_seat; structure:log_seat --> | 5 copper <!-- coin_copper:5 --> |
| Build Storage jar <!-- build:storage_jar; structure:storage_jar --> | 5 copper <!-- coin_copper:5 --> |
| Build Sturdy - Foundation <!-- build:foundation_section; structure:foundation_section --> | 5 copper <!-- coin_copper:5 --> |
| Build Vice <!-- build:vice; structure:vice --> | 5 copper <!-- coin_copper:5 --> |

### First tools, fire and starter workshops — dependency depth 2 (100 goals)

| Goal | Reward |
|---|---|
| Gather clay <!-- gather:clay --> | 3 copper <!-- coin_copper:3 --> |
| Eat something wild <!-- existing:berries --> | 3 copper <!-- coin_copper:3 --> |
| Light a fire <!-- existing:fire --> | 5 copper <!-- coin_copper:5 --> |
| Make a Stone - Axe <!-- existing:axe --> | 5 copper <!-- coin_copper:5 --> |
| Make a Wooden - Hammer <!-- existing:hammer --> | 3 copper <!-- coin_copper:3 --> |
| Sell to Hob <!-- existing:sell --> | 2 copper <!-- coin_copper:2 --> |
| Build Drying rack <!-- build:drying_rack; structure:drying_rack --> | 1 bronze + 4 copper <!-- coin_copper:14 --> |
| Build Food preparation table <!-- build:food_preparation_table; structure:food_preparation_table --> | 1 bronze + 4 copper <!-- coin_copper:14 --> |
| Build Leatherworking table <!-- build:leatherworking_table; structure:leatherworking_table --> | 1 bronze + 4 copper <!-- coin_copper:14 --> |
| Build Loom <!-- build:loom; structure:loom --> | 1 bronze + 4 copper <!-- coin_copper:14 --> |
| Build Tailor's table <!-- build:tailors_table; structure:tailors_table --> | 1 bronze + 4 copper <!-- coin_copper:14 --> |
| Build Tanning rack <!-- build:tanning_rack; structure:tanning_rack --> | 1 bronze + 4 copper <!-- coin_copper:14 --> |
| Craft Bark shingle <!-- craft:bark_shingle; recipes:bark_shingle --> | 4 copper <!-- coin_copper:4 --> |
| Craft Bedroll <!-- craft:bedroll; recipes:bedroll --> | 4 copper <!-- coin_copper:4 --> |
| Craft Belt pouch <!-- craft:belt_pouch; recipes:belt_pouch,leather_belt_pouch --> | 4 copper <!-- coin_copper:4 --> |
| Craft Bone - Club <!-- craft:bone_club; recipes:bone_club --> | 4 copper <!-- coin_copper:4 --> |
| Craft Brick <!-- craft:brick; recipes:brick,kiln_brick --> | 4 copper <!-- coin_copper:4 --> |
| Craft Campfire roasting spit <!-- craft:campfire_roasting_spit; recipes:campfire_roasting_spit --> | 4 copper <!-- coin_copper:4 --> |
| Craft Clay - Griddle <!-- craft:clay_griddle; recipes:clay_griddle --> | 4 copper <!-- coin_copper:4 --> |
| Craft Clay - Pot <!-- craft:clay_pot; recipes:clay_pot --> | 4 copper <!-- coin_copper:4 --> |
| Craft Clay jug <!-- craft:clay_jug; recipes:clay_jug --> | 4 copper <!-- coin_copper:4 --> |
| Craft Clay pipe <!-- craft:clay_pipe; recipes:clay_pipe --> | 4 copper <!-- coin_copper:4 --> |
| Craft Fibre - Cloak <!-- craft:grass_cloak; recipes:grass_cloak --> | 4 copper <!-- coin_copper:4 --> |
| Craft Fibre - Sandals <!-- craft:fibre_sandals; recipes:fibre_sandals --> | 4 copper <!-- coin_copper:4 --> |
| Craft Fibre - Shoulder bag <!-- craft:fibre_shoulder_bag; recipes:fibre_shoulder_bag --> | 4 copper <!-- coin_copper:4 --> |
| Craft Fire arrow <!-- craft:fire_arrow; recipes:fire_arrow --> | 4 copper <!-- coin_copper:4 --> |
| Craft Fishing net <!-- craft:shore_net; recipes:shore_net --> | 4 copper <!-- coin_copper:4 --> |
| Craft Fishing rod <!-- craft:fishing_rod; recipes:fishing_rod --> | 4 copper <!-- coin_copper:4 --> |
| Craft Fishing spear <!-- craft:fishing_spear; recipes:fishing_spear --> | 4 copper <!-- coin_copper:4 --> |
| Craft Flour <!-- craft:flour; recipes:flour_from_wheat,flour_from_barley,flour_from_oats,flour_from_rye,wild_grain_flour --> | 4 copper <!-- coin_copper:4 --> |
| Craft Garlic meat <!-- craft:garlic_meat; recipes:cook_garlic_meat --> | 4 copper <!-- coin_copper:4 --> |
| Craft Herb antidote <!-- craft:herb_antidote; recipes:herb_antidote --> | 4 copper <!-- coin_copper:4 --> |
| Craft Herb fish <!-- craft:herb_fish; recipes:cook_herb_fish --> | 4 copper <!-- coin_copper:4 --> |
| Craft Herb poultice <!-- craft:poultice; recipes:poultice_plantain,poultice_comfrey --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Backpack <!-- craft:backpack; recipes:backpack --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Boots <!-- craft:hide_boots; recipes:hide_boots --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Cloak <!-- craft:hide_cloak; recipes:hide_cloak --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Gloves <!-- craft:hide_gloves; recipes:hide_gloves --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Hood <!-- craft:hide_hood; recipes:hide_hood --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Mittens <!-- craft:hide_mittens; recipes:hide_mittens --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Quiver <!-- craft:quiver; recipes:quiver --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Trousers <!-- craft:hide_trousers; recipes:hide_trousers --> | 4 copper <!-- coin_copper:4 --> |
| Craft Hide - Tunic <!-- craft:hide_tunic; recipes:hide_tunic --> | 4 copper <!-- coin_copper:4 --> |
| Craft Juniper trout <!-- craft:juniper_trout; recipes:cook_juniper_trout --> | 4 copper <!-- coin_copper:4 --> |
| Craft Lamp oil <!-- craft:lamp_oil; recipes:lamp_oil,press_lamp_oil_linseed,press_lamp_oil_walnuts --> | 4 copper <!-- coin_copper:4 --> |
| Craft Mug <!-- craft:mug; recipes:mug --> | 4 copper <!-- coin_copper:4 --> |
| Craft Roast beast <!-- craft:feast_roast; recipes:cook_feast_roast --> | 4 copper <!-- coin_copper:4 --> |
| Craft Sling <!-- craft:sling; recipes:sling --> | 4 copper <!-- coin_copper:4 --> |
| Craft Snare <!-- craft:snare; recipes:snare --> | 4 copper <!-- coin_copper:4 --> |
| Craft Splint <!-- craft:splint; recipes:splint --> | 4 copper <!-- coin_copper:4 --> |
| Craft Stone - Hammer <!-- craft:stone_hammer; recipes:stone_hammer --> | 4 copper <!-- coin_copper:4 --> |
| Craft Stone - Mace <!-- craft:stone_mace; recipes:stone_mace --> | 4 copper <!-- coin_copper:4 --> |
| Craft Stone - Pickaxe <!-- craft:stone_pickaxe; recipes:stone_pickaxe --> | 4 copper <!-- coin_copper:4 --> |
| Craft Straw - Hat <!-- craft:straw_hat; recipes:straw_hat --> | 4 copper <!-- coin_copper:4 --> |
| Craft Tar <!-- craft:tar; recipes:tar --> | 4 copper <!-- coin_copper:4 --> |
| Craft Thatch - Bed <!-- craft:rough_bed_kit; recipes:rough_bed_kit,rough_bed_bedding --> | 4 copper <!-- coin_copper:4 --> |
| Craft Waterskin <!-- craft:waterskin; recipes:waterskin --> | 4 copper <!-- coin_copper:4 --> |
| Craft Wicker - Pack basket <!-- craft:wicker_pack_basket; recipes:wicker_pack_basket --> | 4 copper <!-- coin_copper:4 --> |
| Craft Wooden - Hoe <!-- craft:wooden_hoe; recipes:wooden_hoe --> | 4 copper <!-- coin_copper:4 --> |
| Build Basket <!-- build:wicker_basket; structure:wicker_basket --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Arched door <!-- build:crude_arched_door; structure:crude_arched_door --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Arched doorway <!-- build:thatch_arched_doorway; structure:thatch_arched_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Door <!-- build:crude_door; structure:crude_door --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Doorway <!-- build:thatch_doorway; structure:thatch_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Double arched door <!-- build:crude_double_arched_door; structure:crude_double_arched_door --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Double arched doorway <!-- build:thatch_double_arched_doorway; structure:thatch_double_arched_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Double door <!-- build:crude_double_door; structure:crude_double_door --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Double doorway <!-- build:thatch_double_doorway; structure:thatch_double_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Fence <!-- build:thatch_fence; structure:thatch_fence --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Foundation <!-- build:thatch_floor; structure:thatch_floor --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Gate <!-- build:thatch_gate; structure:thatch_gate --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Pillar <!-- build:thatch_pillar; structure:thatch_pillar --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Roof 45 <!-- build:thatch_roof; structure:thatch_roof --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Roof 65 <!-- build:thatch_roof_65; structure:thatch_roof_65 --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Roof corner <!-- build:thatch_roof_corner; structure:thatch_roof_corner --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Wall <!-- build:thatch_wall; structure:thatch_wall --> | 7 copper <!-- coin_copper:7 --> |
| Build Crude - Window <!-- build:thatch_window; structure:thatch_window --> | 7 copper <!-- coin_copper:7 --> |
| Build Firewood rack <!-- build:firewood_rack; structure:firewood_rack --> | 7 copper <!-- coin_copper:7 --> |
| Build Hide - Sack <!-- build:hide_sack; structure:hide_sack --> | 7 copper <!-- coin_copper:7 --> |
| Build Log rack <!-- build:log_rack; structure:log_rack --> | 7 copper <!-- coin_copper:7 --> |
| Build Palisade <!-- build:log_palisade; structure:log_palisade --> | 7 copper <!-- coin_copper:7 --> |
| Build Post <!-- build:timber_prop; structure:timber_prop --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Arched doorway <!-- build:log_arched_doorway; structure:log_arched_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Ceiling <!-- build:log_floor; structure:log_floor --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Doorway <!-- build:log_doorway; structure:log_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Double arched doorway <!-- build:log_double_arched_doorway; structure:log_double_arched_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Double doorway <!-- build:log_double_doorway; structure:log_double_doorway --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Fence <!-- build:log_fence; structure:log_fence --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Foundation <!-- build:log_foundation; structure:log_foundation --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Gate <!-- build:log_gate; structure:log_gate --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Pillar <!-- build:log_pillar; structure:log_pillar --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Stairs <!-- build:log_stairs; structure:log_stairs --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Wall <!-- build:log_wall; structure:log_wall --> | 7 copper <!-- coin_copper:7 --> |
| Build Rustic - Window <!-- build:log_window; structure:log_window --> | 7 copper <!-- coin_copper:7 --> |
| Build Scarecrow <!-- build:thatch_scarecrow; structure:thatch_scarecrow --> | 7 copper <!-- coin_copper:7 --> |
| Build Straw - Bed <!-- build:straw_bed; structure:straw_bed --> | 7 copper <!-- coin_copper:7 --> |
| Build Thatch - Garden plot <!-- build:thatch_garden_plot; structure:thatch_garden_plot --> | 7 copper <!-- coin_copper:7 --> |
| Build Tool rack <!-- build:tool_rack; structure:tool_rack --> | 7 copper <!-- coin_copper:7 --> |
| Build Trellis <!-- build:wooden_trellis; structure:wooden_trellis --> | 7 copper <!-- coin_copper:7 --> |
| Build Wicker - Chest <!-- build:chest; structure:chest --> | 7 copper <!-- coin_copper:7 --> |

### Starting settlement and foundational craft — dependency depth 3 (72 goals)

| Goal | Reward |
|---|---|
| Collect a log <!-- gather:log --> | 3 copper <!-- coin_copper:3 --> |
| Gather sand <!-- gather:sand --> | 3 copper <!-- coin_copper:3 --> |
| Obtain bone <!-- gather:bone --> | 3 copper <!-- coin_copper:3 --> |
| Obtain hide <!-- gather:hide --> | 3 copper <!-- coin_copper:3 --> |
| Build a lean-to <!-- existing:shelter --> | 8 copper <!-- coin_copper:8 --> |
| Build a Workbench <!-- existing:workbench --> | 1 bronze <!-- coin_copper:10 --> |
| Catch a fish <!-- existing:fish --> | 1 bronze <!-- coin_copper:10 --> |
| Fell a tree <!-- existing:fell --> | 6 copper <!-- coin_copper:6 --> |
| Make a hoe <!-- existing:hoe --> | 3 copper <!-- coin_copper:3 --> |
| Make a spear <!-- existing:spear --> | 5 copper <!-- coin_copper:5 --> |
| Make a Stone - Knife and work a kill <!-- existing:knife --> | 1 bronze <!-- coin_copper:10 --> |
| Build Campfire pot <!-- build:campfire_pot; structure:campfire_pot --> | 2 bronze <!-- coin_copper:20 --> |
| Build Clay hearth <!-- build:clay_hearth; structure:clay_hearth --> | 2 bronze <!-- coin_copper:20 --> |
| Build Kiln <!-- build:kiln; structure:kiln --> | 2 bronze <!-- coin_copper:20 --> |
| Build Oven <!-- build:oven; structure:oven --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Banana fritter batter <!-- craft:banana_fritter_batter; recipes:prep_banana_fritter --> | 5 copper <!-- coin_copper:5 --> |
| Craft Cobblestone <!-- craft:cobblestone; recipes:cobblestone --> | 5 copper <!-- coin_copper:5 --> |
| Craft Dried apples <!-- craft:dried_apples; recipes:cook_dried_apples --> | 5 copper <!-- coin_copper:5 --> |
| Craft Dried figs <!-- craft:dried_figs; recipes:cook_dried_figs --> | 5 copper <!-- coin_copper:5 --> |
| Craft Dried mushrooms <!-- craft:dried_mushrooms; recipes:dried_mushrooms_porcini,dried_mushrooms_chanterelles,dried_mushrooms_morels,dried_mushrooms_puffball --> | 5 copper <!-- coin_copper:5 --> |
| Craft Egg and nettle fry <!-- craft:egg_nettle_fry; recipes:cook_egg_nettle_fry,cook_egg_nettle_fry_iron_frying_pan --> | 5 copper <!-- coin_copper:5 --> |
| Craft Fibre cloth <!-- craft:fibre_cloth; recipes:fibre_cloth --> | 5 copper <!-- coin_copper:5 --> |
| Craft Fruit juice <!-- craft:fruit_juice; recipes:fruit_juice --> | 5 copper <!-- coin_copper:5 --> |
| Craft Fur - Boots <!-- craft:fur_boots; recipes:fur_boots --> | 5 copper <!-- coin_copper:5 --> |
| Craft Fur - Cloak <!-- craft:fur_cloak; recipes:fur_cloak --> | 5 copper <!-- coin_copper:5 --> |
| Craft Fur - Hat <!-- craft:fur_hat; recipes:fur_hat --> | 5 copper <!-- coin_copper:5 --> |
| Craft Fur - Mittens <!-- craft:fur_mittens; recipes:fur_mittens --> | 5 copper <!-- coin_copper:5 --> |
| Craft Hard firewood <!-- craft:firewood; recipes:chopping_hard_firewood --> | 5 copper <!-- coin_copper:5 --> |
| Craft Hardwood block <!-- craft:wooden_block; recipes:small_blocks_from_large --> | 5 copper <!-- coin_copper:5 --> |
| Craft Herb omelette <!-- craft:herb_omelette; recipes:cook_herb_omelette,cook_herb_omelette_iron_frying_pan --> | 5 copper <!-- coin_copper:5 --> |
| Craft Horn pane <!-- craft:horn_pane; recipes:horn_pane --> | 5 copper <!-- coin_copper:5 --> |
| Craft Javelin <!-- craft:javelin; recipes:javelin --> | 5 copper <!-- coin_copper:5 --> |
| Craft Linen <!-- craft:linen; recipes:linen --> | 5 copper <!-- coin_copper:5 --> |
| Craft Nut cake <!-- craft:energy_bar; recipes:energy_bar --> | 5 copper <!-- coin_copper:5 --> |
| Craft Rosemary joint <!-- craft:roast_joint; recipes:cook_roast_joint,cook_roast_joint_campfire_roasting_spit --> | 5 copper <!-- coin_copper:5 --> |
| Craft Scraper <!-- craft:hide_scraper; recipes:hide_scraper --> | 5 copper <!-- coin_copper:5 --> |
| Craft Shortbow <!-- craft:wooden_bow; recipes:wooden_bow --> | 5 copper <!-- coin_copper:5 --> |
| Craft Soft firewood <!-- craft:firewood_soft; recipes:chopping_soft_firewood --> | 5 copper <!-- coin_copper:5 --> |
| Craft Softwood block <!-- craft:wooden_block_soft; recipes:small_soft_blocks_from_large --> | 5 copper <!-- coin_copper:5 --> |
| Craft Stone - Hoe <!-- craft:stone_hoe; recipes:stone_hoe --> | 5 copper <!-- coin_copper:5 --> |
| Craft Stone block <!-- craft:cut_stone_block; recipes:cut_stone_block,bench_stone_block --> | 5 copper <!-- coin_copper:5 --> |
| Craft Stone shingle <!-- craft:stone_shingle; recipes:stone_shingle --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked apple pie <!-- craft:unbaked_apple_pie; recipes:prep_apple_pie --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked chestnut cakes <!-- craft:unbaked_chestnut_cakes; recipes:prep_chestnut_cakes --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked fish pie <!-- craft:unbaked_fish_pie; recipes:prep_fish_pie --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked flatbread <!-- craft:unbaked_flatbread; recipes:prep_flatbread --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked garlic flatbread <!-- craft:unbaked_garlic_flatbread; recipes:prep_garlic_bread --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked honey loaf <!-- craft:unbaked_honey_loaf; recipes:prep_honey_loaf --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked oatcakes <!-- craft:unbaked_oatcakes; recipes:prep_oat_cakes --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked trail bread <!-- craft:unbaked_trail_bread; recipes:prep_trail_bread --> | 5 copper <!-- coin_copper:5 --> |
| Craft Unbaked venison pie <!-- craft:unbaked_venison_pie; recipes:prep_venison_pie --> | 5 copper <!-- coin_copper:5 --> |
| Craft Uncooked crab cakes <!-- craft:uncooked_crab_cakes; recipes:prep_crab_cakes --> | 5 copper <!-- coin_copper:5 --> |
| Craft Uncooked meat skewers <!-- craft:uncooked_meat_skewers; recipes:prep_meat_skewer --> | 5 copper <!-- coin_copper:5 --> |
| Craft Uncooked mushroom skewers <!-- craft:uncooked_mushroom_skewers; recipes:prep_mushroom_skewer,prep_mushroom_skewer_dried --> | 5 copper <!-- coin_copper:5 --> |
| Craft Wool cloth <!-- craft:wool_cloth; recipes:wool_cloth --> | 5 copper <!-- coin_copper:5 --> |
| Build Brick - Garden plot <!-- build:brick_garden_plot; structure:brick_garden_plot --> | 1 bronze <!-- coin_copper:10 --> |
| Build Clay - Pipe <!-- build:clay_pipe_run; structure:clay_pipe_run --> | 1 bronze <!-- coin_copper:10 --> |
| Build Clay - Pipe elbow <!-- build:clay_pipe_elbow; structure:clay_pipe_elbow --> | 1 bronze <!-- coin_copper:10 --> |
| Build Clay - Pipe tee <!-- build:clay_pipe_tee; structure:clay_pipe_tee --> | 1 bronze <!-- coin_copper:10 --> |
| Build Fireplace <!-- build:fireplace; structure:fireplace --> | 1 bronze <!-- coin_copper:10 --> |
| Build Rustic - Roof <!-- build:log_roof; structure:log_roof --> | 1 bronze <!-- coin_copper:10 --> |
| Build Rustic - Roof corner <!-- build:log_roof_corner; structure:log_roof_corner --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Arched doorway <!-- build:brick_arched_doorway; structure:brick_arched_doorway --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Doorway <!-- build:brick_doorway; structure:brick_doorway --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Double arched doorway <!-- build:brick_double_arched_doorway; structure:brick_double_arched_doorway --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Double doorway <!-- build:brick_double_doorway; structure:brick_double_doorway --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Fence <!-- build:brick_fence; structure:brick_fence --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Foundation <!-- build:brick_foundation; structure:brick_foundation --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Pillar <!-- build:brick_pillar; structure:brick_pillar --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Stairs <!-- build:brick_stairs; structure:brick_stairs --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Wall <!-- build:brick_wall; structure:brick_wall --> | 1 bronze <!-- coin_copper:10 --> |
| Build Superior - Window <!-- build:brick_window; structure:brick_window --> | 1 bronze <!-- coin_copper:10 --> |

### Processing, food and first construction — dependency depth 4 (112 goals)

| Goal | Reward |
|---|---|
| Gather copper ore <!-- gather:copper_ore --> | 5 copper <!-- coin_copper:5 --> |
| Gather tin ore <!-- gather:tin_ore --> | 5 copper <!-- coin_copper:5 --> |
| Obtain animal fat <!-- gather:animal_fat --> | 5 copper <!-- coin_copper:5 --> |
| Obtain iron ore <!-- gather:iron_ore --> | 5 copper <!-- coin_copper:5 --> |
| Fill Hob's order <!-- existing:order --> | 3 copper <!-- coin_copper:3 --> |
| Hear a story at the fire <!-- existing:story --> | 3 copper <!-- coin_copper:3 --> |
| Light the night <!-- existing:torch_night --> | 4 copper <!-- coin_copper:4 --> |
| Make a bed <!-- existing:bed --> | 8 copper <!-- coin_copper:8 --> |
| Tread a path from camp to the water <!-- existing:path --> | 5 copper <!-- coin_copper:5 --> |
| Build Stonecutter's bench <!-- build:stonecutters_bench; structure:stonecutters_bench --> | 3 bronze <!-- coin_copper:30 --> |
| Craft Acorn mash <!-- craft:acorn_mash; recipes:cook_acorn_mash --> | 7 copper <!-- coin_copper:7 --> |
| Craft Apple pie <!-- craft:apple_pie; recipes:cook_apple_pie --> | 7 copper <!-- coin_copper:7 --> |
| Craft Apple sauce <!-- craft:apple_sauce; recipes:cook_apple_sauce --> | 7 copper <!-- coin_copper:7 --> |
| Craft Baked apples <!-- craft:baked_apples; recipes:cook_baked_apples --> | 7 copper <!-- coin_copper:7 --> |
| Craft Baked potato <!-- craft:baked_potato; recipes:cook_baked_potato --> | 7 copper <!-- coin_copper:7 --> |
| Craft Banana fritter <!-- craft:banana_fritter; recipes:cook_banana_fritter,cook_banana_fritter_iron_frying_pan --> | 7 copper <!-- coin_copper:7 --> |
| Craft Barley broth <!-- craft:barley_broth; recipes:cook_barley_broth --> | 7 copper <!-- coin_copper:7 --> |
| Craft Beet roast <!-- craft:beet_roast; recipes:cook_beet_roast --> | 7 copper <!-- coin_copper:7 --> |
| Craft Berry compote <!-- craft:berry_compote; recipes:cook_berry_compote --> | 7 copper <!-- coin_copper:7 --> |
| Craft Boiled egg <!-- craft:boiled_egg; recipes:boil_eggs --> | 7 copper <!-- coin_copper:7 --> |
| Craft Cabbage stew <!-- craft:cabbage_stew; recipes:cook_cabbage_stew,cook_cabbage_stew_iron_cauldron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Cactus fry <!-- craft:cactus_fry; recipes:cook_cactus_fry --> | 7 copper <!-- coin_copper:7 --> |
| Craft Charcoal <!-- craft:charcoal; recipes:charcoal --> | 7 copper <!-- coin_copper:7 --> |
| Craft Chestnut cakes <!-- craft:chestnut_cakes; recipes:cook_chestnut_cakes,cook_chestnut_cakes_clay_griddle --> | 7 copper <!-- coin_copper:7 --> |
| Craft Clay roof tile <!-- craft:clay_roof_tile; recipes:clay_roof_tile --> | 7 copper <!-- coin_copper:7 --> |
| Craft Copper ingot <!-- craft:copper_ingot; recipes:smelt_copper --> | 7 copper <!-- coin_copper:7 --> |
| Craft Crab cakes <!-- craft:crab_cakes; recipes:cook_crab_cakes,cook_crab_cakes_iron_frying_pan --> | 7 copper <!-- coin_copper:7 --> |
| Craft Fibre - Gambeson <!-- craft:gambeson; recipes:gambeson --> | 7 copper <!-- coin_copper:7 --> |
| Craft Fish pie <!-- craft:fish_pie; recipes:cook_fish_pie --> | 7 copper <!-- coin_copper:7 --> |
| Craft Fish stew <!-- craft:fish_stew; recipes:cook_fish_stew,cook_fish_stew_iron_cauldron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Flatbread <!-- craft:flatbread; recipes:cook_flatbread,cook_flatbread_clay_griddle --> | 7 copper <!-- coin_copper:7 --> |
| Craft Forager's stew <!-- craft:forager_stew; recipes:cook_forager_stew,cook_forager_stew_iron_cauldron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Fruit leather <!-- craft:fruit_leather; recipes:cook_fruit_leather --> | 7 copper <!-- coin_copper:7 --> |
| Craft Garlic bread <!-- craft:garlic_bread; recipes:cook_garlic_bread,cook_garlic_bread_clay_griddle --> | 7 copper <!-- coin_copper:7 --> |
| Craft Hazelnut butter <!-- craft:hazelnut_butter; recipes:cook_hazelnut_butter --> | 7 copper <!-- coin_copper:7 --> |
| Craft Hearty pottage <!-- craft:hearty_pottage; recipes:cook_hearty_pottage,cook_hearty_pottage_iron_cauldron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Herbal tea <!-- craft:herbal_tea; recipes:herbal_tea --> | 7 copper <!-- coin_copper:7 --> |
| Craft Hide glue <!-- craft:hide_glue; recipes:hide_glue --> | 7 copper <!-- coin_copper:7 --> |
| Craft Honey loaf <!-- craft:honey_loaf; recipes:cook_honey_loaf --> | 7 copper <!-- coin_copper:7 --> |
| Craft Hunter's stew <!-- craft:hunters_stew; recipes:cook_hunters_stew,cook_hunters_stew_iron_cauldron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Iron ingot <!-- craft:iron_ingot; recipes:smelt_iron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Light crossbow <!-- craft:light_crossbow; recipes:light_crossbow --> | 7 copper <!-- coin_copper:7 --> |
| Craft Lime powder <!-- craft:lime_powder; recipes:lime_powder --> | 7 copper <!-- coin_copper:7 --> |
| Craft Linen - Apron <!-- craft:linen_apron; recipes:linen_apron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Linen - Dress <!-- craft:linen_dress; recipes:linen_dress --> | 7 copper <!-- coin_copper:7 --> |
| Craft Linen - Headwrap <!-- craft:linen_headwrap; recipes:linen_headwrap --> | 7 copper <!-- coin_copper:7 --> |
| Craft Linen - Shirt <!-- craft:linen_shirt; recipes:linen_shirt --> | 7 copper <!-- coin_copper:7 --> |
| Craft Linen - Skirt <!-- craft:linen_skirt; recipes:linen_skirt --> | 7 copper <!-- coin_copper:7 --> |
| Craft Linen - Trousers <!-- craft:linen_trousers; recipes:linen_trousers --> | 7 copper <!-- coin_copper:7 --> |
| Craft Meat skewer <!-- craft:meat_skewer; recipes:cook_meat_skewer,cook_meat_skewer_iron_grill_grate --> | 7 copper <!-- coin_copper:7 --> |
| Craft Mushroom skewer <!-- craft:mushroom_skewer; recipes:cook_mushroom_skewer,cook_mushroom_skewer_iron_grill_grate --> | 7 copper <!-- coin_copper:7 --> |
| Craft Mussel stew <!-- craft:mussel_stew; recipes:cook_mussel_stew,cook_mussel_stew_iron_cauldron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Nettle tea <!-- craft:nettle_tea; recipes:nettle_tea --> | 7 copper <!-- coin_copper:7 --> |
| Craft Nut paste <!-- craft:nut_paste; recipes:cook_nut_paste --> | 7 copper <!-- coin_copper:7 --> |
| Craft Oat cakes <!-- craft:oat_cakes; recipes:cook_oat_cakes,cook_oat_cakes_clay_griddle --> | 7 copper <!-- coin_copper:7 --> |
| Craft Oat porridge <!-- craft:oat_porridge; recipes:cook_oat_porridge --> | 7 copper <!-- coin_copper:7 --> |
| Craft Oilcloth - Cloak <!-- craft:oilcloth_cloak; recipes:oilcloth_cloak --> | 7 copper <!-- coin_copper:7 --> |
| Craft Onion roast <!-- craft:onion_roast; recipes:cook_onion_roast --> | 7 copper <!-- coin_copper:7 --> |
| Craft Pea soup <!-- craft:pea_soup; recipes:cook_pea_soup --> | 7 copper <!-- coin_copper:7 --> |
| Craft Plum jam <!-- craft:plum_jam; recipes:cook_plum_jam --> | 7 copper <!-- coin_copper:7 --> |
| Craft Preserved damsons <!-- craft:preserved_damsons; recipes:cook_preserved_damsons --> | 7 copper <!-- coin_copper:7 --> |
| Craft Quarterstaff <!-- craft:quarterstaff; recipes:quarterstaff --> | 7 copper <!-- coin_copper:7 --> |
| Craft Quince paste <!-- craft:quince_paste; recipes:cook_quince_paste --> | 7 copper <!-- coin_copper:7 --> |
| Craft Roast roots <!-- craft:roast_roots; recipes:cook_roast_roots --> | 7 copper <!-- coin_copper:7 --> |
| Craft Roasted forage <!-- craft:roast_forage; recipes:roast_hazelnuts,roast_chestnuts,roast_walnuts,roast_beechnuts,roast_morels,roast_bananas,roast_fiddleheads,roast_wild_pears --> | 7 copper <!-- coin_copper:7 --> |
| Craft Salt <!-- craft:sea_salt; recipes:sea_salt --> | 7 copper <!-- coin_copper:7 --> |
| Craft Scraped hide <!-- craft:processed_hide; recipes:processed_hide --> | 7 copper <!-- coin_copper:7 --> |
| Craft Seal stew <!-- craft:seal_stew; recipes:cook_seal_stew,cook_seal_stew_iron_cauldron --> | 7 copper <!-- coin_copper:7 --> |
| Craft Seaweed soup <!-- craft:seaweed_soup; recipes:cook_seaweed_soup --> | 7 copper <!-- coin_copper:7 --> |
| Craft Serving platter <!-- craft:serving_platter; recipes:serving_platter --> | 7 copper <!-- coin_copper:7 --> |
| Craft Stewed berries <!-- craft:stewed_berries; recipes:stew_raspberries,stew_blueberries,stew_blackberries,stew_strawberries --> | 7 copper <!-- coin_copper:7 --> |
| Craft Stewed pears <!-- craft:stewed_pears; recipes:cook_stewed_pears --> | 7 copper <!-- coin_copper:7 --> |
| Craft Tabard <!-- craft:tabard; recipes:tabard,tabard_wool --> | 7 copper <!-- coin_copper:7 --> |
| Craft Tallow <!-- craft:tallow; recipes:tallow --> | 7 copper <!-- coin_copper:7 --> |
| Craft Tin ingot <!-- craft:tin_ingot; recipes:smelt_tin --> | 7 copper <!-- coin_copper:7 --> |
| Craft Trail bread <!-- craft:trail_bread; recipes:cook_trail_bread --> | 7 copper <!-- coin_copper:7 --> |
| Craft Turnip mash <!-- craft:turnip_mash; recipes:cook_turnip_mash --> | 7 copper <!-- coin_copper:7 --> |
| Craft Venison pie <!-- craft:venison_pie; recipes:cook_venison_pie --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wooden - Club <!-- craft:wooden_club; recipes:wooden_club --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wooden - Hammer <!-- craft:wooden_hammer; recipes:wooden_hammer,wooden_hammer_soft --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wooden bowl <!-- craft:wooden_bowl; recipes:wooden_bowl --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Cap <!-- craft:wool_cap; recipes:wool_cap --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Cloak <!-- craft:wool_cloak; recipes:wool_cloak --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Coat <!-- craft:wool_coat; recipes:wool_coat --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Dress <!-- craft:wool_dress; recipes:wool_dress --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Mittens <!-- craft:wool_mittens; recipes:wool_mittens --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Robe <!-- craft:wool_robe; recipes:wool_robe --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Scarf <!-- craft:wool_scarf; recipes:wool_scarf --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Socks <!-- craft:wool_socks; recipes:wool_socks --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Trousers <!-- craft:wool_trousers; recipes:wool_trousers --> | 7 copper <!-- coin_copper:7 --> |
| Craft Wool - Tunic <!-- craft:wool_tunic; recipes:wool_tunic --> | 7 copper <!-- coin_copper:7 --> |
| Build Cistern <!-- build:stone_cistern; structure:stone_cistern --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Feather - Bed <!-- build:feather_bed; structure:feather_bed --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Root cellar <!-- build:root_cellar; structure:root_cellar --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Bench <!-- build:stone_bench; structure:stone_bench --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Brazier <!-- build:stone_brazier; structure:stone_brazier --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Channel <!-- build:stone_channel; structure:stone_channel --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Channel corner <!-- build:stone_channel_corner; structure:stone_channel_corner --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Channel tee <!-- build:stone_channel_tee; structure:stone_channel_tee --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Garden plot <!-- build:stone_garden_plot; structure:stone_garden_plot --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Planter <!-- build:stone_planter; structure:stone_planter --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Stone - Trough <!-- build:stone_trough; structure:stone_trough --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Arched doorway <!-- build:stone_arched_doorway; structure:stone_arched_doorway --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Doorway <!-- build:stone_doorway; structure:stone_doorway --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Double arched doorway <!-- build:stone_double_arched_doorway; structure:stone_double_arched_doorway --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Double doorway <!-- build:stone_double_doorway; structure:stone_double_doorway --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Fence <!-- build:stone_fence; structure:stone_fence --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Pillar <!-- build:stone_pillar; structure:stone_pillar --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Stairs <!-- build:stone_stairs; structure:stone_stairs --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Wall <!-- build:stone_wall; structure:stone_wall --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Sturdy - Window <!-- build:stone_window; structure:stone_window --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Wool - Rug <!-- build:wool_rug; structure:wool_rug --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |

### Specialized resources and intermediate stations — dependency depth 5 (32 goals)

| Goal | Reward |
|---|---|
| Gather flax <!-- gather:flax --> | 5 copper <!-- coin_copper:5 --> |
| Gather wool <!-- gather:wool --> | 5 copper <!-- coin_copper:5 --> |
| Obtain hardwood logs <!-- gather:log_oak --> | 5 copper <!-- coin_copper:5 --> |
| Obtain softwood logs <!-- gather:log_spruce --> | 5 copper <!-- coin_copper:5 --> |
| Cross the camp at night with a torch <!-- existing:night_walk --> | 4 copper <!-- coin_copper:4 --> |
| Dress for the cold <!-- existing:fur_for_winter --> | 2 bronze <!-- coin_copper:20 --> |
| Dry berries for winter <!-- existing:dry_berries --> | 8 copper <!-- coin_copper:8 --> |
| Make jerky <!-- existing:jerky --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Salt a fish <!-- existing:salted_fish --> | 1 bronze + 2 copper <!-- coin_copper:12 --> |
| Smoke a fish <!-- existing:smoke_fish --> | 1 bronze + 2 copper <!-- coin_copper:12 --> |
| Work by candlelight <!-- existing:candle --> | 8 copper <!-- coin_copper:8 --> |
| Build Blast furnace <!-- build:large_forge; structure:large_forge --> | 4 bronze <!-- coin_copper:40 --> |
| Build Smithy <!-- build:blacksmithy; structure:blacksmithy --> | 4 bronze <!-- coin_copper:40 --> |
| Craft Bronze ingot <!-- craft:bronze_ingot; recipes:bronze_ingot --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Chamomile tea <!-- craft:chamomile_tea; recipes:chamomile_tea --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Dessert platter <!-- craft:dessert_platter; recipes:dessert_platter --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Harvest platter <!-- craft:harvest_platter; recipes:harvest_platter --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Leather <!-- craft:leather; recipes:leather --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Roast platter <!-- craft:roast_platter; recipes:roast_platter --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Sauerkraut <!-- craft:sauerkraut; recipes:cook_sauerkraut --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Seafood platter <!-- craft:seafood_platter; recipes:seafood_platter --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Smoked meat <!-- craft:smoked_meat; recipes:smoked_meat --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Soap <!-- craft:soap; recipes:soap --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Stomach tea <!-- craft:stomach_tea; recipes:stomach_tea --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Tavern supper board <!-- craft:tavern_supper_board; recipes:tavern_supper_board --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Unbaked rye flatbread <!-- craft:unbaked_rye_flatbread; recipes:prep_rye_flatbread --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Uncooked meatballs <!-- craft:uncooked_meatballs; recipes:prep_meatballs --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Uncooked sausages <!-- craft:uncooked_sausages; recipes:prep_sausage --> | 1 bronze <!-- coin_copper:10 --> |
| Craft Willow bark tea <!-- craft:willow_bark_tea; recipes:willow_bark_tea --> | 1 bronze <!-- coin_copper:10 --> |
| Build Quenching trough <!-- build:quenching_trough; structure:quenching_trough --> | 2 bronze <!-- coin_copper:20 --> |
| Build Torch post <!-- build:wooden_torch_post; structure:wooden_torch_post --> | 2 bronze <!-- coin_copper:20 --> |
| Build Wall torch <!-- build:wall_torch; structure:wall_torch --> | 2 bronze <!-- coin_copper:20 --> |

### Developing production and workstations — dependency depth 6 (58 goals)

| Goal | Reward |
|---|---|
| Craft Bronze - Arrow <!-- craft:bronze_arrow; recipes:bronze_arrow --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Chisel <!-- craft:bronze_chisel; recipes:bronze_chisel --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Hammer <!-- craft:bronze_hammer; recipes:bronze_hammer --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Helm <!-- craft:bronze_helm; recipes:bronze_helm --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Knife <!-- craft:bronze_knife; recipes:bronze_knife --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Mace <!-- craft:bronze_mace; recipes:bronze_mace --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Pickaxe <!-- craft:bronze_pickaxe; recipes:bronze_pickaxe --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Scale shirt <!-- craft:bronze_scale_shirt; recipes:bronze_scale_shirt --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Scythe <!-- craft:bronze_scythe; recipes:bronze_scythe --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Shield <!-- craft:bronze_shield; recipes:bronze_shield --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Sickle <!-- craft:bronze_sickle; recipes:bronze_sickle --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Spear <!-- craft:bronze_spear; recipes:bronze_spear --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze - Sword <!-- craft:bronze_sword; recipes:bronze_sword --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze hinges <!-- craft:bronze_hinges; recipes:bronze_hinges --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Bronze nails <!-- craft:bronze_nails; recipes:bronze_nails --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Fine leather <!-- craft:fine_leather; recipes:fine_leather --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Heavy crossbow <!-- craft:heavy_crossbow; recipes:heavy_crossbow --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Heavy leather <!-- craft:heavy_leather; recipes:heavy_leather --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Hinges <!-- craft:hinges; recipes:hinges --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Arrow <!-- craft:iron_arrow; recipes:iron_arrow --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Bolt <!-- craft:iron_bolt; recipes:iron_bolt --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Breastplate <!-- craft:iron_breastplate; recipes:iron_breastplate --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Buckler <!-- craft:iron_buckler; recipes:iron_buckler --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Cauldron <!-- craft:iron_cauldron; recipes:iron_cauldron --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Chisel <!-- craft:iron_chisel; recipes:iron_chisel --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Frying pan <!-- craft:iron_frying_pan; recipes:iron_frying_pan --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Gauntlets <!-- craft:iron_gauntlets; recipes:iron_gauntlets --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Greatsword <!-- craft:iron_greatsword; recipes:iron_greatsword --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Grill grate <!-- craft:iron_grill_grate; recipes:iron_grill_grate --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Halberd <!-- craft:iron_halberd; recipes:iron_halberd --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Hammer <!-- craft:iron_hammer; recipes:iron_hammer --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Helm <!-- craft:iron_helm; recipes:iron_helm --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Hoe <!-- craft:iron_hoe; recipes:iron_hoe --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Knife <!-- craft:iron_knife; recipes:iron_knife --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Lantern <!-- craft:iron_lantern; recipes:iron_lantern --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Mace <!-- craft:iron_mace; recipes:iron_mace --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Pickaxe <!-- craft:iron_pickaxe; recipes:iron_pickaxe --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Pike <!-- craft:iron_pike; recipes:iron_pike --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Sabatons <!-- craft:iron_sabatons; recipes:iron_sabatons --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Saw <!-- craft:hand_saw; recipes:hand_saw --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Scythe <!-- craft:scythe; recipes:scythe --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Shortsword <!-- craft:iron_shortsword; recipes:iron_shortsword --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Sickle <!-- craft:iron_sickle; recipes:iron_sickle --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Spade <!-- craft:iron_spade; recipes:iron_spade --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Spear <!-- craft:iron_spear; recipes:iron_spear --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Sword <!-- craft:iron_sword; recipes:iron_sword --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Trident <!-- craft:iron_trident; recipes:iron_trident --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron - Warhammer <!-- craft:iron_warhammer; recipes:iron_warhammer --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Iron band <!-- craft:iron_band; recipes:iron_band --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Leather - Belt <!-- craft:leather_belt; recipes:leather_belt --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Leather strap <!-- craft:leather_strap; recipes:leather_strap --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Meatballs <!-- craft:meatballs; recipes:meatballs,cook_meatballs_iron_frying_pan --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Nails <!-- craft:nails; recipes:nails --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Rivets <!-- craft:rivets; recipes:rivets --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Rye flatbread <!-- craft:rye_flatbread; recipes:cook_rye_flatbread,cook_rye_flatbread_clay_griddle --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Sausage <!-- craft:sausage; recipes:cook_sausage,cook_sausage_iron_grill_grate --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Craft Steel ingot <!-- craft:steel_ingot; recipes:smelt_steel --> | 1 bronze + 5 copper <!-- coin_copper:15 --> |
| Build Bellows <!-- build:bellows; structure:bellows --> | 3 bronze <!-- coin_copper:30 --> |

### Advanced tools, equipment and construction — dependency depth 7 (87 goals)

| Goal | Reward |
|---|---|
| Fill your winter store <!-- existing:winter_store --> | 3 bronze <!-- coin_copper:30 --> |
| Build Fireplace cooking crane <!-- build:fireplace_cooking_crane; structure:fireplace_cooking_crane --> | 8 bronze <!-- coin_copper:80 --> |
| Build Master smithy <!-- build:master_forge; structure:master_forge --> | 8 bronze <!-- coin_copper:80 --> |
| Craft Breakfast platter <!-- craft:breakfast_platter; recipes:breakfast_platter --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Bronze - Axe <!-- craft:bronze_axe; recipes:bronze_axe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Bronze - Greaves <!-- craft:bronze_greaves; recipes:bronze_greaves --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Carved stone block <!-- craft:carved_stone_block; recipes:carved_stone_block --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Carved stone shingle <!-- craft:carved_stone_shingle; recipes:carved_stone_shingle --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Charcuterie board <!-- craft:charcuterie_board; recipes:charcuterie_board --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Hardwood board <!-- craft:hardwood_board; recipes:hardwood_board,hardwood_board_by_hand --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Axe <!-- craft:iron_axe; recipes:iron_axe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Battleaxe <!-- craft:iron_battleaxe; recipes:iron_battleaxe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Brigandine <!-- craft:iron_brigandine; recipes:iron_brigandine --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Greataxe <!-- craft:iron_greataxe; recipes:iron_greataxe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Greaves <!-- craft:iron_greaves; recipes:iron_greaves --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Mail chausses <!-- craft:iron_mail_chausses; recipes:iron_mail_chausses --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Mail coif <!-- craft:iron_mail_coif; recipes:iron_mail_coif --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Mail hauberk <!-- craft:iron_mail_hauberk; recipes:iron_mail_hauberk --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Iron - Mail shirt <!-- craft:mail_shirt; recipes:mail_shirt --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Apron <!-- craft:leather_apron; recipes:leather_apron --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Backpack <!-- craft:leather_backpack; recipes:leather_backpack --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Boots <!-- craft:leather_boots; recipes:leather_boots --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Broad-brim hat <!-- craft:leather_broad_brim_hat; recipes:leather_broad_brim_hat --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Cap <!-- craft:leather_cap; recipes:leather_cap --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Gloves <!-- craft:leather_gloves; recipes:leather_gloves --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Jerkin <!-- craft:leather_jerkin; recipes:leather_jerkin --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Quiver <!-- craft:leather_quiver; recipes:leather_quiver --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Satchel <!-- craft:leather_satchel; recipes:leather_satchel --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Shoes <!-- craft:leather_shoes; recipes:leather_shoes --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Leather - Trousers <!-- craft:leather_trousers; recipes:leather_trousers --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Mixed grill platter <!-- craft:mixed_grill_platter; recipes:mixed_grill_platter --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Plank <!-- craft:lumber; recipes:lumber,lumber_by_hand --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Snowshoes <!-- craft:wooden_snowshoes; recipes:wooden_snowshoes --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Arrow <!-- craft:steel_arrow; recipes:steel_arrow --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Axe <!-- craft:steel_axe; recipes:steel_axe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Battleaxe <!-- craft:steel_battleaxe; recipes:steel_battleaxe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Chisel <!-- craft:steel_chisel; recipes:steel_chisel --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Cuirass <!-- craft:plate_cuirass; recipes:plate_cuirass --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Gauntlets <!-- craft:steel_gauntlets; recipes:steel_gauntlets --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Greataxe <!-- craft:steel_greataxe; recipes:steel_greataxe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Greatsword <!-- craft:steel_greatsword; recipes:steel_greatsword --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Greaves <!-- craft:steel_greaves; recipes:steel_greaves --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Halberd <!-- craft:steel_halberd; recipes:steel_halberd --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Half plate <!-- craft:steel_half_plate; recipes:steel_half_plate --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Hammer <!-- craft:steel_hammer; recipes:steel_hammer --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Helm <!-- craft:steel_helm; recipes:steel_helm --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Hoe <!-- craft:steel_hoe; recipes:steel_hoe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Knife <!-- craft:steel_knife; recipes:steel_knife --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Mace <!-- craft:steel_mace; recipes:steel_mace --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Maul <!-- craft:steel_maul; recipes:steel_maul --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Pickaxe <!-- craft:steel_pickaxe; recipes:steel_pickaxe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Plate harness <!-- craft:steel_plate_harness; recipes:steel_plate_harness --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Rapier <!-- craft:steel_rapier; recipes:steel_rapier --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Sabatons <!-- craft:steel_sabatons; recipes:steel_sabatons --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Saw <!-- craft:steel_saw; recipes:steel_saw --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Scimitar <!-- craft:steel_scimitar; recipes:steel_scimitar --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Scythe <!-- craft:steel_scythe; recipes:steel_scythe --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Shortsword <!-- craft:steel_shortsword; recipes:steel_shortsword --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Sickle <!-- craft:steel_sickle; recipes:steel_sickle --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Spade <!-- craft:steel_spade; recipes:steel_spade --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Spear <!-- craft:steel_spear; recipes:steel_spear --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Sword <!-- craft:steel_sword; recipes:steel_sword --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Steel - Warhammer <!-- craft:steel_warhammer; recipes:steel_warhammer --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Tool roll <!-- craft:tool_roll; recipes:tool_roll,leather_tool_roll --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Traveller's rucksack <!-- craft:travellers_rucksack; recipes:travellers_rucksack --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Utility bandolier <!-- craft:utility_bandolier; recipes:utility_bandolier --> | 2 bronze <!-- coin_copper:20 --> |
| Craft Weapon scabbard <!-- craft:weapon_scabbard; recipes:weapon_scabbard --> | 2 bronze <!-- coin_copper:20 --> |
| Build Deep-well pump <!-- build:iron_deep_well_pump; structure:iron_deep_well_pump --> | 4 bronze <!-- coin_copper:40 --> |
| Build Fortified - Arched door <!-- build:fortified_arched_door; structure:fortified_arched_door --> | 4 bronze <!-- coin_copper:40 --> |
| Build Fortified - Door <!-- build:fortified_door; structure:fortified_door --> | 4 bronze <!-- coin_copper:40 --> |
| Build Fortified - Double arched door <!-- build:fortified_double_arched_door; structure:fortified_double_arched_door --> | 4 bronze <!-- coin_copper:40 --> |
| Build Fortified - Double door <!-- build:fortified_double_door; structure:fortified_double_door --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Brazier <!-- build:iron_brazier; structure:iron_brazier --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Fence <!-- build:iron_fence; structure:iron_fence --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Gate <!-- build:iron_gate; structure:iron_gate --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Hand pump <!-- build:iron_hand_pump; structure:iron_hand_pump --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Hanging lantern <!-- build:iron_hanging_lantern; structure:iron_hanging_lantern --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Lamp post <!-- build:iron_lamp_post; structure:iron_lamp_post --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Pipe <!-- build:iron_pipe; structure:iron_pipe --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Pipe elbow <!-- build:iron_pipe_elbow; structure:iron_pipe_elbow --> | 4 bronze <!-- coin_copper:40 --> |
| Build Iron - Railing <!-- build:iron_railing; structure:iron_railing --> | 4 bronze <!-- coin_copper:40 --> |
| Build Palisade gate <!-- build:log_palisade_gate; structure:log_palisade_gate --> | 4 bronze <!-- coin_copper:40 --> |
| Build Stone - Lamp post <!-- build:stone_lamp_post; structure:stone_lamp_post --> | 4 bronze <!-- coin_copper:40 --> |
| Build Tap <!-- build:iron_tap; structure:iron_tap --> | 4 bronze <!-- coin_copper:40 --> |
| Build Torch pillar <!-- build:stone_torch_pillar; structure:stone_torch_pillar --> | 4 bronze <!-- coin_copper:40 --> |
| Build Torch stand <!-- build:iron_torch_stand; structure:iron_torch_stand --> | 4 bronze <!-- coin_copper:40 --> |
| Build Wall lantern <!-- build:iron_wall_lantern; structure:iron_wall_lantern --> | 4 bronze <!-- coin_copper:40 --> |

### Expanded fabrication and furnishings — dependency depth 8 (93 goals)

| Goal | Reward |
|---|---|
| Build Mixer <!-- build:mixer; structure:mixer --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Stone - Workbench <!-- build:stone_workbench; structure:stone_workbench --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Craft Bucket <!-- craft:bucket; recipes:bucket --> | 3 bronze <!-- coin_copper:30 --> |
| Craft Iron - Shield <!-- craft:iron_shield; recipes:iron_shield --> | 3 bronze <!-- coin_copper:30 --> |
| Craft Steel - Shield <!-- craft:steel_shield; recipes:steel_shield --> | 3 bronze <!-- coin_copper:30 --> |
| Craft Wooden - Lantern <!-- craft:wooden_lantern; recipes:wooden_lantern --> | 3 bronze <!-- coin_copper:30 --> |
| Craft Wooden pin <!-- craft:wooden_pin; recipes:wooden_pin --> | 3 bronze <!-- coin_copper:30 --> |
| Craft Wooden shingle <!-- craft:wooden_shingle; recipes:wooden_shingle --> | 3 bronze <!-- coin_copper:30 --> |
| Build Antler mount <!-- build:antler_mount; structure:antler_mount --> | 6 bronze <!-- coin_copper:60 --> |
| Build Apothecary cabinet <!-- build:apothecary_cabinet; structure:apothecary_cabinet --> | 6 bronze <!-- coin_copper:60 --> |
| Build Armour stand <!-- build:armour_stand; structure:armour_stand --> | 6 bronze <!-- coin_copper:60 --> |
| Build Barrel <!-- build:wooden_barrel; structure:wooden_barrel --> | 6 bronze <!-- coin_copper:60 --> |
| Build Beam <!-- build:timber_set; structure:timber_set --> | 6 bronze <!-- coin_copper:60 --> |
| Build Bookcase <!-- build:bookcase; structure:bookcase --> | 6 bronze <!-- coin_copper:60 --> |
| Build Bottle and jar rack <!-- build:bottle_and_jar_rack; structure:bottle_and_jar_rack --> | 6 bronze <!-- coin_copper:60 --> |
| Build Canopy bed <!-- build:canopy_bed; structure:canopy_bed --> | 6 bronze <!-- coin_copper:60 --> |
| Build Chandelier <!-- build:chandelier; structure:chandelier --> | 6 bronze <!-- coin_copper:60 --> |
| Build Cold frame <!-- build:wooden_cold_frame; structure:wooden_cold_frame --> | 6 bronze <!-- coin_copper:60 --> |
| Build Compost bin <!-- build:wooden_compost_bin; structure:wooden_compost_bin --> | 6 bronze <!-- coin_copper:60 --> |
| Build Crate <!-- build:wooden_crate; structure:wooden_crate --> | 6 bronze <!-- coin_copper:60 --> |
| Build Cupboard <!-- build:wooden_cupboard; structure:wooden_cupboard --> | 6 bronze <!-- coin_copper:60 --> |
| Build Dresser <!-- build:dresser; structure:dresser --> | 6 bronze <!-- coin_copper:60 --> |
| Build Engineered - Arched door <!-- build:engineered_arched_door; structure:engineered_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Engineered - Door <!-- build:engineered_door; structure:engineered_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Engineered - Double arched door <!-- build:engineered_double_arched_door; structure:engineered_double_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Engineered - Double door <!-- build:engineered_double_door; structure:engineered_double_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Fine - Bench <!-- build:iron_bench; structure:iron_bench --> | 6 bronze <!-- coin_copper:60 --> |
| Build Fine - Chair <!-- build:iron_chair; structure:iron_chair --> | 6 bronze <!-- coin_copper:60 --> |
| Build Fine - Chest <!-- build:fine_chest; structure:fine_chest --> | 6 bronze <!-- coin_copper:60 --> |
| Build Fine - Table <!-- build:iron_table; structure:iron_table --> | 6 bronze <!-- coin_copper:60 --> |
| Build Ladder <!-- build:ladder; structure:ladder --> | 6 bronze <!-- coin_copper:60 --> |
| Build Large wooden chest <!-- build:large_wooden_chest; structure:large_wooden_chest --> | 6 bronze <!-- coin_copper:60 --> |
| Build Ore and metal rack <!-- build:ore_and_metal_rack; structure:ore_and_metal_rack --> | 6 bronze <!-- coin_copper:60 --> |
| Build Ornate - Chair <!-- build:ornate_chair; structure:ornate_chair --> | 6 bronze <!-- coin_copper:60 --> |
| Build Ornate - Chest <!-- build:iron_chest; structure:iron_chest --> | 6 bronze <!-- coin_copper:60 --> |
| Build Ornate - Table <!-- build:ornate_table; structure:ornate_table --> | 6 bronze <!-- coin_copper:60 --> |
| Build Planter box <!-- build:wooden_planter_box; structure:wooden_planter_box --> | 6 bronze <!-- coin_copper:60 --> |
| Build Raised cistern <!-- build:stone_raised_cistern; structure:stone_raised_cistern --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Arched door <!-- build:refined_arched_door; structure:refined_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Arched doorway <!-- build:wood_arched_doorway; structure:wood_arched_doorway --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Ceiling <!-- build:floor_section; structure:floor_section --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Door <!-- build:refined_door; structure:refined_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Doorway <!-- build:doorway_section; structure:doorway_section --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Double arched door <!-- build:refined_double_arched_door; structure:refined_double_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Double arched doorway <!-- build:wood_double_arched_doorway; structure:wood_double_arched_doorway --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Double door <!-- build:refined_double_door; structure:refined_double_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Double doorway <!-- build:double_doorway; structure:double_doorway --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Fence <!-- build:wood_fence; structure:wood_fence --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Foundation <!-- build:wood_foundation; structure:wood_foundation --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Gate <!-- build:wood_gate; structure:wood_gate --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Pillar <!-- build:wooden_pillar; structure:wooden_pillar --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Stairs <!-- build:stairs_wood; structure:stairs_wood --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Wall <!-- build:wall_section; structure:wall_section --> | 6 bronze <!-- coin_copper:60 --> |
| Build Refined - Window <!-- build:window_section; structure:window_section --> | 6 bronze <!-- coin_copper:60 --> |
| Build Rustic - Arched door <!-- build:rustic_arched_door; structure:rustic_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Rustic - Chair <!-- build:chair; structure:chair --> | 6 bronze <!-- coin_copper:60 --> |
| Build Rustic - Chest <!-- build:plank_chest; structure:plank_chest --> | 6 bronze <!-- coin_copper:60 --> |
| Build Rustic - Door <!-- build:rustic_door; structure:rustic_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Rustic - Double arched door <!-- build:rustic_double_arched_door; structure:rustic_double_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Rustic - Double door <!-- build:rustic_double_door; structure:rustic_double_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Rustic - Table <!-- build:table; structure:table --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sign <!-- build:sign; structure:sign --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sluice <!-- build:wooden_sluice; structure:wooden_sluice --> | 6 bronze <!-- coin_copper:60 --> |
| Build Stone - Table <!-- build:stone_table; structure:stone_table --> | 6 bronze <!-- coin_copper:60 --> |
| Build Storage sign <!-- build:storage_sign; structure:storage_sign --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sturdy - Arched door <!-- build:sturdy_arched_door; structure:sturdy_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sturdy - Door <!-- build:sturdy_door; structure:sturdy_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sturdy - Double arched door <!-- build:sturdy_double_arched_door; structure:sturdy_double_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sturdy - Double door <!-- build:sturdy_double_door; structure:sturdy_double_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sturdy - Gate <!-- build:stone_gate; structure:stone_gate --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sturdy - Roof <!-- build:stone_roof; structure:stone_roof --> | 6 bronze <!-- coin_copper:60 --> |
| Build Sturdy - Roof corner <!-- build:stone_roof_corner; structure:stone_roof_corner --> | 6 bronze <!-- coin_copper:60 --> |
| Build Superior - Arched door <!-- build:superior_arched_door; structure:superior_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Superior - Door <!-- build:superior_door; structure:superior_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Superior - Double arched door <!-- build:superior_double_arched_door; structure:superior_double_arched_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Superior - Double door <!-- build:superior_double_door; structure:superior_double_door --> | 6 bronze <!-- coin_copper:60 --> |
| Build Superior - Gate <!-- build:brick_gate; structure:brick_gate --> | 6 bronze <!-- coin_copper:60 --> |
| Build Superior - Roof <!-- build:brick_roof; structure:brick_roof --> | 6 bronze <!-- coin_copper:60 --> |
| Build Superior - Roof corner <!-- build:brick_roof_corner; structure:brick_roof_corner --> | 6 bronze <!-- coin_copper:60 --> |
| Build Tool cabinet <!-- build:tool_cabinet; structure:tool_cabinet --> | 6 bronze <!-- coin_copper:60 --> |
| Build Tusk mount <!-- build:tusk_mount; structure:tusk_mount --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wardrobe <!-- build:wardrobe; structure:wardrobe --> | 6 bronze <!-- coin_copper:60 --> |
| Build Warehouse crate <!-- build:warehouse_crate; structure:warehouse_crate --> | 6 bronze <!-- coin_copper:60 --> |
| Build Warehouse desk <!-- build:warehouse_desk; structure:warehouse_desk --> | 6 bronze <!-- coin_copper:60 --> |
| Build Weapon rack <!-- build:weapon_rack; structure:weapon_rack --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Channel <!-- build:wooden_channel; structure:wooden_channel --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Channel corner <!-- build:wooden_channel_corner; structure:wooden_channel_corner --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Channel tee <!-- build:wooden_channel_tee; structure:wooden_channel_tee --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Garden plot <!-- build:wooden_garden_plot; structure:wooden_garden_plot --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Hand pump <!-- build:wooden_hand_pump; structure:wooden_hand_pump --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Hanging lantern <!-- build:wooden_hanging_lantern; structure:wooden_hanging_lantern --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Railing <!-- build:wooden_railing; structure:wooden_railing --> | 6 bronze <!-- coin_copper:60 --> |
| Build Wooden - Trough <!-- build:wooden_trough; structure:wooden_trough --> | 6 bronze <!-- coin_copper:60 --> |

### Late-stage craftsmanship and construction — dependency depth 9 (24 goals)

| Goal | Reward |
|---|---|
| Craft Axle <!-- craft:axle; recipes:axle --> | 4 bronze <!-- coin_copper:40 --> |
| Craft Concrete <!-- craft:concrete; recipes:concrete --> | 4 bronze <!-- coin_copper:40 --> |
| Craft Longbow <!-- craft:wooden_longbow; recipes:wooden_longbow --> | 4 bronze <!-- coin_copper:40 --> |
| Craft Water wheel <!-- craft:water_wheel; recipes:water_wheel --> | 4 bronze <!-- coin_copper:40 --> |
| Craft Wooden - Cart wheel <!-- craft:wooden_cart_wheel; recipes:wooden_cart_wheel --> | 4 bronze <!-- coin_copper:40 --> |
| Craft Wooden - Shield <!-- craft:plank_shield; recipes:plank_shield --> | 4 bronze <!-- coin_copper:40 --> |
| Craft Wooden - Spyglass <!-- craft:spyglass; recipes:spyglass --> | 4 bronze <!-- coin_copper:40 --> |
| Build Board rack <!-- build:board_rack; structure:board_rack --> | 8 bronze <!-- coin_copper:80 --> |
| Build Crude - Bench <!-- build:bench; structure:bench --> | 8 bronze <!-- coin_copper:80 --> |
| Build Crude - Chair <!-- build:crude_chair; structure:crude_chair --> | 8 bronze <!-- coin_copper:80 --> |
| Build Crude - Chest <!-- build:crude_chest; structure:crude_chest --> | 8 bronze <!-- coin_copper:80 --> |
| Build Crude - Table <!-- build:crude_table; structure:crude_table --> | 8 bronze <!-- coin_copper:80 --> |
| Build Engineered - Roof <!-- build:engineered_roof; structure:engineered_roof --> | 8 bronze <!-- coin_copper:80 --> |
| Build Engineered - Roof corner <!-- build:engineered_roof_corner; structure:engineered_roof_corner --> | 8 bronze <!-- coin_copper:80 --> |
| Build Mason's pallet <!-- build:masons_pallet; structure:masons_pallet --> | 8 bronze <!-- coin_copper:80 --> |
| Build Open storage bin <!-- build:open_storage_bin; structure:open_storage_bin --> | 8 bronze <!-- coin_copper:80 --> |
| Build Refined - Roof <!-- build:roof_section; structure:roof_section --> | 8 bronze <!-- coin_copper:80 --> |
| Build Refined - Roof corner <!-- build:wooden_roof_corner; structure:wooden_roof_corner --> | 8 bronze <!-- coin_copper:80 --> |
| Build Shelf <!-- build:wooden_shelf; structure:wooden_shelf --> | 8 bronze <!-- coin_copper:80 --> |
| Build Stool <!-- build:stool; structure:stool --> | 8 bronze <!-- coin_copper:80 --> |
| Build Sturdy - Ceiling <!-- build:stone_floor; structure:stone_floor --> | 8 bronze <!-- coin_copper:80 --> |
| Build Superior - Ceiling <!-- build:brick_floor; structure:brick_floor --> | 8 bronze <!-- coin_copper:80 --> |
| Build Well <!-- build:stone_well; structure:stone_well --> | 8 bronze <!-- coin_copper:80 --> |
| Build Wooden - Lamp post <!-- build:wooden_lamp_post; structure:wooden_lamp_post --> | 8 bronze <!-- coin_copper:80 --> |

### Highest current production dependency level — dependency depth 10 (21 goals)

| Goal | Reward |
|---|---|
| Build Sawmill <!-- build:saw_mill; structure:saw_mill --> | 2 silver + 4 bronze <!-- coin_copper:240 --> |
| Build Engineered - Arched doorway <!-- build:engineered_arched_doorway; structure:engineered_arched_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Ceiling <!-- build:engineered_floor; structure:engineered_floor --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Doorway <!-- build:engineered_doorway; structure:engineered_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Double arched doorway <!-- build:engineered_double_arched_doorway; structure:engineered_double_arched_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Double doorway <!-- build:engineered_double_doorway; structure:engineered_double_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Foundation <!-- build:engineered_foundation; structure:engineered_foundation --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Pillar <!-- build:engineered_pillar; structure:engineered_pillar --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Stairs <!-- build:engineered_stairs; structure:engineered_stairs --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Wall <!-- build:engineered_wall; structure:engineered_wall --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Engineered - Window <!-- build:engineered_window; structure:engineered_window --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Arched doorway <!-- build:fortified_arched_doorway; structure:fortified_arched_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Doorway <!-- build:fortified_doorway; structure:fortified_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Double arched doorway <!-- build:fortified_double_arched_doorway; structure:fortified_double_arched_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Double doorway <!-- build:fortified_double_doorway; structure:fortified_double_doorway --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Foundation <!-- build:fortified_foundation; structure:fortified_foundation --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Gate <!-- build:fortified_gate; structure:fortified_gate --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Pillar <!-- build:fortified_pillar; structure:fortified_pillar --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Wall <!-- build:fortified_wall; structure:fortified_wall --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Fortified - Wall top <!-- build:fortified_wall_top; structure:fortified_wall_top --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |
| Build Handcart <!-- build:handcart; structure:handcart --> | 1 silver + 2 bronze <!-- coin_copper:120 --> |

## Required audit before this draft becomes approved

- Current live item definitions: 1120 total; 776 active; 279 retired; 65 future.
- Distinct active craft outputs: 353; buildable blueprints: 258; resulting proposed rows: 642 (344 added craft goals, 255 added build goals, 28 preserved goals, 15 added resource milestones).
- Unresolved static dependency nodes: 0; this is not game-playthrough proof. Verify station use, interactions, every material's actual acquisition, proper retained tools and hammer tiers.
- Essential production route to verify: sticks/fibre/stone → tools and fire → Chopping Block/firewood/charcoal → Smelter/iron ingots → Smithy/Iron Saw → Planks and Hardwood Boards → carpenter stations/Sawmill → advanced construction. Bronze/copper/tin, Blast Furnace/steel, textiles, food-preparation/preservation, furniture, weapons, armor, storage and vehicles must each pass a similar test.
- All currently inactive FUTURE items/animal-related unreleased mechanics and item categories without crafting outputs require a later explicitly approved addendum. Do not invent obtainable recipes or rewards.
- The original automatic goals include both `after` dependencies and persistent event counters. Preserve early/out-of-order credit, save/load and one-time idempotency, while avoiding an O(players × all goals × many loops) per-tick scan where indexed event completion is possible.
- Before implementing, jointly audit this complete generated draft line by line against the Master Catalog, current data, and actual gameplay; resolve any missing prerequisite or impossible goal. The author of this first pass is not claiming that these 600+ goals were playtested.
- This is a reviewed **design draft only**. No gameplay or goal JSON was changed by creating this document. The coordinator must not implement its rewards before creator signoff.
