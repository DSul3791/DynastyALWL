# WS walk-late: new-player walkthrough, manufacturing to the highest tier

Workstream: NEW-PLAYER WALKTHROUGH (late game). Audit only, read-only (WORKSTREAM_RULES.md).
Repo: `/home/user/DynastyALWL`, branch `claude/project-thread-d8jals`, HEAD `69d361b1d56de65a722a0424c605ad0ce6678f29` at writing. `git diff dc2fa52 HEAD -- data src docs/design/PLAYER_GOALS_REWARDS_DRAFT.md docs/design/DYNASTY_MASTER_ITEMS.md` is empty, so every data/code citation below holds for baseline `dc2fa52374d49ce05ef1f31a300999d1da872d9d`.

**Verification level.** Everything here is CODE_VERIFIED: data and code were read, nothing was run. Godot was not run and no test was run in this audit. Where a test exists that asserts the exact behaviour, it is cited as "AUTOMATED_TESTED (reported)": the David4 lane run at dc2fa52 (`work/david4_evidence_dc2fa52.md`, 20/20 pass) reports it passing, and this audit did not re-run it. Nothing is GAMEPLAY_VERIFIED.

**Other workstreams.** `work/ws_acquisition.json` and `work/ws_runtime.json` did not exist when this was written. Where a step depends on how a raw material is obtained, or on how a goal completes or persists, this file says "per acquisition workstream" or "per runtime workstream". It gives only the lead it found and does not re-audit those areas.

**Step numbering.** "Step N" is the Nth MAIN-route row in `work/goals_parsed.json` (route MAIN, in order). Step 44 is draft line 71 (Thread) and step 118 is line 145 (Fortified - Gate), so draft line = step + 27.

**Starting state assumed.** The player has completed steps 1-43 as written: gathered sticks, stones, fibre, twine, logs, oak logs, thatch, clay and sand; made a Stone - Knife, Stone - Axe, Stone - Pickaxe, Wooden - Hammer, Wooden - Spade and a lit campfire; split firewood; and built a Lean-to, Workbench (Wooden, L1), Crude foundation/wall/doorway/window/roofs, Campfire pot, Drying rack, Smoker, Food preparation table, Clay hearth (L2) and Oven. Bricks come from the campfire (`recipes.json recipes.brick`).

---

## (a) Walkthrough table, main route steps 44-118

Verdicts: YES = doable with what earlier steps taught. YES-WITH-UNTAUGHT-PREREQ = doable, but the guide leaves out something the player needs. NO = not doable as written at this point. UNKNOWN = depends on things this audit could not establish.

| Step | goal_id | Can do now? | What the guide fails to explain | Evidence |
|---|---|---|---|---|
| 44 | craft:thread | YES | — | `recipes.json recipes.thread` (hand, plant_fibre 2) |
| 45 | gather:hide | YES-WITH-UNTAUGHT-PREREQ | Hunting and carcass dressing are not taught (per acquisition workstream). The knife from step 6 is enough. | `carcass.json species.*.parts` (hide); test_mission001_walkthrough 1h AUTOMATED_TESTED (reported) |
| 46 | gather:flint | YES-WITH-UNTAUGHT-PREREQ | The draft itself says the source is unverified (per acquisition workstream). Lead: `boulders.json flint`, `drops.json ground_scatter.bank.flint`. | source_mentions.json `flint` |
| 47 | craft:hide_scraper | YES | — | `recipes.json recipes.hide_scraper` station workbench L1; workbench from step 27 |
| 48 | craft:processed_hide | YES | — | `recipes.json recipes.processed_hide` (drying_rack, keeps hide_scraper); drying rack step 39 |
| 49 | gather:tannin_bark | YES-WITH-UNTAUGHT-PREREQ | The How-to points to mangrove, but `items.json items.log_mangrove` is RETIRED/FUTURE. Data gives Tanbark from oak (`drops.json harvest_yield.oak.item` = tannin_bark). Per acquisition workstream. | source_mentions.json `tannin_bark` |
| 50 | build:tanning_rack | YES | — | `blueprints.json blueprints.tanning_rack` (log 6, twine 4, hammer 1) |
| 51 | craft:leather | YES-WITH-UNTAUGHT-PREREQ | Needs 1 **water**, and no goal teaches how to get water as an item (per acquisition workstream). | `recipes.json recipes.leather` needs water x1; pass2_report.txt "MAIN-ROUTE ORDER" |
| 52 | build:leatherworking_table | YES | Does not say what the table is for. No later main step uses it; Leather strap is side L439. | `blueprints.json blueprints.leatherworking_table` |
| 53 | build:tailors_table | YES | No later main step uses it. | `blueprints.json blueprints.tailors_table` |
| 54 | build:loom | YES | No later main step uses it. | `blueprints.json blueprints.loom` (clay 4 from step 34) |
| 55 | build:preserving_jar | YES | A food station placed inside the manufacturing chain; nothing later in the route uses it. | `blueprints.json blueprints.preserving_jar` |
| 56 | craft:charcoal | YES | 1) "Hard firewood" is really the group `firewood`, which soft firewood also fills. 2) It does not say how much fuel the metal chain burns: 5 per ingot, plus 1 to fire each burning station. 3) It does not mention coal (any pick) or Kiln charcoal at 100 per log. | `recipes.json recipes.charcoal` (firewood x2 → 12); `wood_species.json ingredient_groups.firewood`; `ingredient_groups.fuel` = charcoal, coal |
| 57 | gather:iron_ore | YES-WITH-UNTAUGHT-PREREQ (rock route: **NO**) | "Iron-bearing rock deposits" is offered first, but at this point the player has only a Stone - Pickaxe, and **iron ore cannot be taken with a stone pick**. Only bog iron dug with the Wooden - Spade works here. The How-to names neither the spade nor wet/peat ground, and does not say 4 ore make 1 ingot. | `boulders.json ore.needs_material.iron` = [bronze, iron, steel]; server_items.gd:5617-5618; `digging.json bog_iron` (item iron_ore); test_mission001_walkthrough 2c AUTOMATED_TESTED (reported); catalog s2.7 item 1 [D1] |
| 58 | build:smelter | YES | — | `blueprints.json blueprints.smelter` (clay 24, stone 10); `structures.json structures.smelter` (no craft_needs_lit) |
| 59 | craft:iron_ingot | YES | Does not say "Fuel" means Charcoal or Coal. Does not say to make **at least 3 ingots** (step 60), or 7 by step 62. | `recipes.json recipes.smelt_iron` (iron_ore 4, fuel 5 → 1); `items.json items.fuel` ("Never given itself") |
| 60 | build:blacksmithy | YES-WITH-UNTAUGHT-PREREQ | Needs 3 iron ingots, but step 59 teaches one craft. Does not say the Smithy must be burning to craft and fires itself from 1 fuel in the pack. | `blueprints.json blueprints.blacksmithy` (stone 16, clay 10, log 4, iron_ingot 3, hammer 1); `structures.json structures.blacksmithy` (station brick_forge L2, also forge 1, craft_needs_lit, fuel "fuel", fuel_s 1800) |
| 61 | craft:iron_hammer | YES-WITH-UNTAUGHT-PREREQ | Fuel (charcoal or coal) must be in the pack, or the cold Smithy serves nothing. | server_items.gd:13066-13092 (cold station serves only if the pack has its fuel; the craft fires it); `recipes.json recipes.iron_hammer` brick_forge L2; test_stations.gd:131,162-163 AUTOMATED_TESTED (reported) |
| 62 | craft:hand_saw | YES-WITH-UNTAUGHT-PREREQ | Same fuel gap as step 61. | `recipes.json recipes.hand_saw` brick_forge L1 (needs iron_ingot 2, stick 2); test_mission001 2f-2g AUTOMATED_TESTED (reported) |
| 63 | gather:log_spruce | YES | "Softwood" means spruce, Scots pine or the plain Log. | `wood_species.json ingredient_groups.log_spruce` |
| 64 | craft:lumber | YES | The How-to says "Spruce log"; the group label is "Softwood log". Hand saw and Sawmill give the same yield (6). | `recipes.json recipes.lumber_by_hand` (keeps saw); `recipes.json hand_saw_balance`; test_mission001 2h AUTOMATED_TESTED (reported) |
| 65 | craft:hardwood_board | YES | The How-to says "Oak log"; the group is "Hardwood log" (oak, beech, birch, mahogany, walnut, maple). | `recipes.json recipes.hardwood_board_by_hand`; `ingredient_groups.log_oak` |
| 66 | craft:wooden_pin | YES | — | `recipes.json recipes.wooden_pin` workbench L1, lumber 1 → 20 |
| 67 | build:log_workbench | YES | Workbench L2 is used by nothing later in the main route. Draft s4 says the Carpenter's bench was inserted "before the level-3 Stone Workbench", which implies a dependency that does not exist (see W-L10). | `structures.json structures.log_workbench` (workbench L2); `blueprints.json blueprints.log_workbench` |
| 68 | craft:cobblestone | YES | Quantity: steps 70, 71 and 97 need 48 cobblestone (144 stone). | `recipes.json recipes.cobblestone` |
| 69 | craft:mortar | YES | — | `recipes.json recipes.mortar` (hand, sand 2 clay 1 → 2) |
| 70 | build:stone_workbench | YES | Does not say this gives **workbench level 3**, which step 77 needs. | `structures.json structures.stone_workbench` station_level 3 |
| 71 | build:stonecutters_bench | YES (build). It is useless at this point. | All three of its recipes keep a **Bronze - Chisel**. The chisel is never in the main route (side L522), and bronze first appears at step 87. | `recipes.json recipes.bench_stone_block / carved_stone_block / carved_stone_shingle` keeps bronze_chisel |
| 72 | craft:nails | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel (as step 61). Quantity: 180 nails (steps 77 + 78) = 2 crafts. Bronze nails also fill `nails`. | `recipes.json recipes.nails` brick_forge L2 → 100; `ingredient_groups.nails` |
| 73 | craft:hinges | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel. | `recipes.json recipes.hinges` brick_forge L2 → 20 |
| 74 | craft:iron_band | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel. Quantity: steps 114-118 need 19 bands = 10 crafts. | `recipes.json recipes.iron_band` brick_forge L1 → 2 |
| 75 | gather:pine_tar | YES-WITH-UNTAUGHT-PREREQ | Says to collect 5, but the Water wheel needs 4 Tar = **20 Pine tar**. Source per acquisition workstream (lead: `drops.json trunk.by_species.scots_pine`). | `recipes.json recipes.tar` (pine_tar 5 → 1); `recipes.water_wheel` tar 4 |
| 76 | craft:tar | YES | Same quantity gap (4 crafts needed). | `recipes.json recipes.tar` station campfire |
| 77 | craft:water_wheel | YES | Says "Workbench (workstation level 3)" without naming the source: the Stone - Workbench (step 70), or a Wooden workbench with Tool rack + Vice beside it (side L208, L170). | `recipes.json recipes.water_wheel` workbench L3; server_items.gd:13184-13190, 13248-13263 (level = own + add-on kinds within 5 m) |
| 78 | build:saw_mill | YES-WITH-UNTAUGHT-PREREQ (NO if followed literally; site availability UNKNOWN) | Leaves out both placement rules: it must stand **on a foundation lifted ≥0.5 m**, with its 2 m wheel span **over a running river** (≥0.4 m deep, turned across the current, ≥150 W). The foundation goals come later (79-82); only the Crude foundation (step 28) exists. Whether a suitable river is near the player depends on the world. | `structures.json structures.saw_mill` (needs_base_lift_m 0.5, needs_running_water, note); server_items.gd:3786-3792, 3835-3875; `data/water_flow.json` (min_depth_m 0.4, min_power_w 150) |
| 79 | build:wood_foundation | YES | — (planks from step 64) | `blueprints.json blueprints.wood_foundation` |
| 80 | build:log_foundation | YES | Buildable since step ~33; it sits after the Sawmill only because of route order. | `blueprints.json blueprints.log_foundation` |
| 81 | build:foundation_section | YES | Buildable since step 34 (stone 8, clay 2). | `blueprints.json blueprints.foundation_section` |
| 82 | build:brick_foundation | YES | Buildable since step 69. | `blueprints.json blueprints.brick_foundation` |
| 83 | gather:copper_ore | YES | Locating deposits is per acquisition workstream. The stone pick works. | `boulders.json ore.needs_material.copper` includes stone |
| 84 | gather:tin_ore | YES | Same as step 83. | `boulders.json ore.needs_material.tin` |
| 85 | craft:copper_ingot | YES | Fuel = charcoal or coal. | `recipes.json recipes.smelt_copper` |
| 86 | craft:tin_ingot | YES | Same. | `recipes.json recipes.smelt_tin` |
| 87 | craft:bronze_ingot | YES | — | `recipes.json recipes.bronze_ingot` (3 copper + 1 tin → 4) |
| 88 | build:stone_forge | YES (redundant) | The Smithy from step 60 already does forge L1 bronze work. The Stone - Forge only adds a no-fuel bronze station. The catalog intends it as the bronze rung **before** iron; here it comes after. | `structures.json structures.blacksmithy.also.forge` = 1; `structures.stone_forge` (no craft_needs_lit); test_stations.gd:103-122 AUTOMATED_TESTED (reported); catalog s2.7 item 4 [C] |
| 89 | craft:bronze_hammer | YES | — (Stone - Forge, or the burning Smithy) | `recipes.json recipes.bronze_hammer` forge L1 |
| 90 | craft:bronze_pickaxe | YES | Does not say this is the first pick that can mine **rock iron ore**. | `boulders.json ore.needs_material.iron` |
| 91 | craft:bronze_sword | YES | — (leather from step 51) | `recipes.json recipes.bronze_sword` |
| 92 | craft:iron_pickaxe | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel. | `recipes.json recipes.iron_pickaxe` brick_forge L2 |
| 93 | craft:iron_sword | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel. | `recipes.json recipes.iron_sword` brick_forge L2 |
| 94 | build:kiln | YES | Buildable since step 69 (brick, clay, mortar). The guide never teaches the Kiln's charcoal function (logs → 100 charcoal each, lit with E) or Kiln bricks (6 per 2 clay instead of 3). | `blueprints.json blueprints.kiln`; `structures.json structures.kiln` (use kiln, takes log, per_log 100); server_items.gd:9163-9164, 9400; `recipes.json recipes.kiln_brick`; catalog s2.6 [D1] |
| 95 | gather:limestone | YES | Any pick takes it from limestone/chalk/marble bedrock boulders. Locating them is per acquisition workstream. | `boulders.json ore.rocks`, `rock_boulder_share` |
| 96 | craft:lime_powder | YES | — | `recipes.json recipes.lime_powder` kiln L1 |
| 97 | build:mixer | YES | — | `blueprints.json blueprints.mixer` |
| 98 | craft:concrete | YES-WITH-UNTAUGHT-PREREQ | Needs 1 **water**, which is never taught (per acquisition workstream). Quantity: steps 110-118 need 73 concrete = 25 crafts. | `recipes.json recipes.concrete`; pass2_report.txt |
| 99 | craft:clay_roof_tile | YES | Quantity: 24 tiles for step 112 = 8 crafts. | `recipes.json recipes.clay_roof_tile` |
| 100 | build:large_forge | YES | Does not say the Blast furnace must burn (fuel in pack) or that it also smelts ore. | `structures.json structures.large_forge` (craft_needs_lit, also smelter 1); test_stations.gd:126 AUTOMATED_TESTED (reported) |
| 101 | craft:steel_ingot | YES-WITH-UNTAUGHT-PREREQ | Needs 1 fuel to fire the furnace plus 5 as ingredient. | `recipes.json recipes.smelt_steel`; server_items.gd:13066-13092; test_mission001 3w AUTOMATED_TESTED (reported) |
| 102 | craft:steel_hammer | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel. | `recipes.json recipes.steel_hammer` brick_forge L1 |
| 103 | craft:steel_pickaxe | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel. | `recipes.json recipes.steel_pickaxe` |
| 104 | craft:steel_sword | YES-WITH-UNTAUGHT-PREREQ | Smithy fuel. | `recipes.json recipes.steel_sword` |
| 105 | build:master_forge | YES | The Iron - Hammer from step 61 (tier 4) meets hammer 3. **Does not say what the Master smithy does:** the +1/+2 craftsmanship variants of any forge/smithy recipe. No later step uses it. | `blueprints.json blueprints.master_forge` hammer 3; `items.json items.iron_hammer.tier` 4; `smithing.json craft.station` master_smithy; server_items.gd:17083-17096 |
| 106 | build:refined_door | YES-WITH-UNTAUGHT-PREREQ | Never says a door hangs only in an **empty doorway frame with the same opening**: any tier, one door per frame. The only single doorway the route has built is the Crude doorway (step 30). Needs no Master smithy, only boards + iron (from step 65). | placement_rules.gd:587-619 (doorway_fit: tier never matters; "taken"); test_doors.gd:178,180 AUTOMATED_TESTED (reported); `blueprints.json blueprints.refined_door` |
| 107 | build:rustic_door | YES-WITH-UNTAUGHT-PREREQ | Same doorway gap. Possible from step 64 (5 planks). The Crude doorway is already taken if step 106 used it. | placement_rules.gd:622-627 door_at |
| 108 | build:sturdy_door | YES-WITH-UNTAUGHT-PREREQ | Same. Possible from step 64. | `blueprints.json blueprints.sturdy_door` |
| 109 | build:superior_door | YES-WITH-UNTAUGHT-PREREQ | Same. The only door that really depends on a late step: steel from step 101. | `blueprints.json blueprints.superior_door` |
| 110 | build:engineered_foundation | YES | — | `blueprints.json blueprints.engineered_foundation` hammer 1 |
| 111 | build:engineered_wall | YES | — | `blueprints.json blueprints.engineered_wall` |
| 112 | build:engineered_roof | YES | — (pins from step 66: 20 − 6 used = 14 ≥ 8) | `blueprints.json blueprints.engineered_roof` |
| 113 | build:engineered_door | YES-WITH-UNTAUGHT-PREREQ | Needs a free single doorway. The Engineered - Doorway is only in side L746. | `blueprints.json blueprints.engineered_door` |
| 114 | build:fortified_foundation | YES | "Metal hammer" = tier ≥3: bronze, iron or steel (all three exist by now). | `blueprints.json blueprints.fortified_foundation` hammer 3; server_items.gd:8146-8149, 8211-8217 |
| 115 | build:fortified_wall | YES | — | `blueprints.json blueprints.fortified_wall` |
| 116 | build:fortified_doorway | YES | — | `blueprints.json blueprints.fortified_doorway` |
| 117 | build:fortified_door | YES | — (the Fortified doorway from step 116 takes it) | `blueprints.json blueprints.fortified_door` |
| 118 | build:fortified_gate | YES | — | `blueprints.json blueprints.fortified_gate` |

The static re-check (scratch script over goals_parsed.json, recipes.json, blueprints.json, structures.json) found **no main-route row** that:
- asks for a station before the route builds it,
- uses a retired or locked recipe or blueprint, or
- needs a station level that cannot be reached.

The only untaught inputs it found are `water` (steps 51 and 98). The problems in this table are semantic, and a static check cannot see them: fuel for burning stations, ore tool tiers, placement rules, doorway frames, quantities and purpose.

---

## (b) Findings

Severity: HIGH = a player following the guide as written fails or is badly misled. MEDIUM = progress needs knowledge the guide does not give, or the order contradicts the approved design. LOW = clarity or quantity. INFO = verified non-issue. Every recommendation is a PROPOSAL for Dave's review of the draft. No data or catalog change is proposed: catalog freeze, DECISION_AUTHORITY.md.

**W-L01 — HIGH — iron ore route at step 57 (`gather:iron_ore`).**
- Problem: the How-to offers "iron-bearing rock deposits" first. With the Stone - Pickaxe, the only pick at this point, rock iron cannot be taken. At step 57 the only working route is bog iron dug with the Wooden - Spade (step 23).
- Evidence: `boulders.json ore.needs_material.iron` = ["bronze","iron","steel"], read by server_items.gd:5617-5618. `digging.json bog_iron.item` = iron_ore. Catalog s2.7 item 1 [D1]: "find bog iron (dug with any spade in wet ground)". test_mission001_walkthrough 2c AUTOMATED_TESTED (reported).
- Correction: rewrite step 57 to "Dig bog iron with your Wooden - Spade in wet bog/peat ground; you need 4 ore per ingot". Rock iron needs a Bronze or better pickaxe; say so at step 90.
- The exact soils and rate are per acquisition workstream.

**W-L02 — HIGH — burning stations are never explained.**
- Affected: steps 60-62, 72-74, 92-93, 100-105.
- Problem: the Smithy, Blast furnace and Master smithy serve a recipe only while lit. A cold one serves only if the player carries its fuel (charcoal or coal), and the craft then fires it with 1 unit for 1800 s. No How-to mentions this. A player who used all their charcoal in the Smelter cannot craft the Iron - Saw and is not told why.
- Evidence: `structures.json structures.blacksmithy / large_forge / master_forge` (`craft_needs_lit`, `fuel` "fuel", `fuel_s` 1800). server_items.gd:13066-13092 and 13209-13220. test_stations.gd:131 and 162-163 AUTOMATED_TESTED (reported). Catalog s3.3 row 90 "must be burning to craft".
- Correction: add one sentence to step 60 (Smithy), step 100 (Blast furnace) and step 105 (Master smithy): "Keep Charcoal or Coal in your pack: crafting here lights it, using 1 fuel per 30 minutes." No new goal is needed.

**W-L03 — HIGH — Sawmill placement (step 78, `build:saw_mill`).**
- Problem: the sawmill is refused unless it stands on a foundation lifted ≥0.5 m. Its wheel span must also lie over a river (water class 3) running ≥0.4 m deep across the span, giving ≥150 W, with the wheel turned across the current. The guide says only "Place it where the building ghost is valid", and its foundation goals come after it (79-82).
- Evidence: `structures.json structures.saw_mill` (`needs_base_lift_m` 0.5, `needs_running_water`, note). server_items.gd:3786-3792 and 3835-3875 (refusals "It needs a tall foundation…", WHEEL_SAYS "dry/river/still/shallow"). `data/water_flow.json`.
- Correction: ADD a step before 78: "Build a foundation on a river bank and raise it at least 0.5 m". The cheapest is Sturdy (stone 8, clay 2) or Rustic (log 10, stone 6, twine 2), so move step 81 or 80 here.
- Also extend step 78: "with its water wheel over fast, deep river water; the ghost tells you the wheel's power".
- UNKNOWN: whether every world has a qualifying river within reach of a typical base. The Sawmill is optional (hand saw yields are equal), so its How-to should say so.

**W-L04 — MEDIUM — Kiln charcoal, the catalog's main charcoal source, is never taught.**
- Affected: steps 56, 94 and every fuel use.
- Problem: catalog s2.6 [D1] makes the Kiln the charcoal maker: 100 per log, a batch of 6 logs, lit with E. The only charcoal the guide teaches is the campfire recipe (12 per 2 firewood).
- Scale: by my count the main route from step 59 onward burns about 690 fuel:
  - 108 iron ingots × 5 = 540
  - 22 steel × 5 = 110
  - 8 copper/tin ingots × 5 = 40
- That is about 58 campfire charcoal crafts, against about 7 logs in a Kiln. The Kiln comes at step 94 although it needs only brick, clay and mortar.
- Evidence: `structures.json structures.kiln` (`use` kiln, `takes` [log], `per_log` 100, `batch_logs` 6). server_items.gd:9163-9164 and 9400. `recipes.json recipes.kiln_charcoal` is RETIRED (replaced by the use action).
- Correction:
  - Move `craft:mortar` (step 69) to right after `craft:brick` (step 36), and `build:kiln` (step 94) to just before `craft:charcoal` (step 56).
  - ADD an activity goal "Burn charcoal in the Kiln" right after it. Its completion event is per runtime workstream: `_kiln_use` exists, but whether it can be observed as a goal is not established.
  - Keep the campfire charcoal goal as the first, simple route.
  - Also mention mined Coal: any pick, `boulders.json ore.needs_material.coal`.

**W-L05 — MEDIUM — bronze-before-iron is inverted; the Stone - Forge is redundant in the main route.**
- Affected: steps 59-62 vs 83-91; step 88.
- Problem: catalog s2.7 item 4 [C]: "the Stone - Forge stays as the bronze smithy… keeps Bronze a real rung before Iron". The route builds the Smithy at step 60, and the Smithy already provides forge L1. So by step 88 the Stone - Forge adds nothing except a fuel-free bronze bench.
- Evidence: `structures.json structures.blacksmithy.also.forge` = 1. Every bronze recipe is `station` forge L1 (`recipes.json` bronze_*). test_stations.gd:103-122 (want [0,1,2] for blacksmithy_kit) AUTOMATED_TESTED (reported).
- Both orders work in data (no cycle):
  - Bog iron needs no bronze.
  - Copper and tin ore take a stone pick.
  - Only rock iron needs bronze.
- Option A (follows catalog [C]): move steps 83-91 (copper, tin, ingots, bronze, Stone - Forge, bronze hammer, pickaxe, sword) to directly after step 58 (Smelter) and before step 59. Then step 57 can also offer rock iron after the bronze pickaxe.
- Option B: keep the order, drop `build:stone_forge` from the main route to the side tables, and write "Use the Stone - Forge or the burning Smithy" in steps 89-91.
- The draft says the route order itself awaits creator confirmation. Ask Dave only if he wants to deviate from [C]; otherwise apply Option A.

**W-L06 — MEDIUM — doors need empty doorway frames.**
- Affected: steps 106-109 and 113 (also 117).
- Problem: a door is placed only into an empty doorway frame with the same opening shape. Tier never matters, and each frame holds one door. No door How-to says this. Before step 116 the route has built exactly one single doorway (Crude, step 30), but it asks for five single doors (106, 107, 108, 109, 113).
- Evidence: placement_rules.gd:587-619 (`doorway_fit`: "tier and material never matter"; why "nodoorway", "mismatch", "taken") and 622-627 (`door_at`). `structures.json` doors `attach_to` "doorway". test_doors.gd:155, 161, 178, 180 AUTOMATED_TESTED (reported).
- Taking a piece down refunds its cost (`blueprints.json note`). Whether a goal stays earned after take-down is per runtime workstream.
- Correction: add to every door How-to: "Hang it in an empty single doorway frame of any tier; each frame holds one door." ADD `build:log_doorway` (Rustic - Doorway: log 6, twine 2), proposed position next to the first door (see W-L07).

**W-L07 — MEDIUM — construction tiers in the main route are incoherent and late.**
- Affected: steps 79-82, 106-118.
- Problems:
  - The route builds four lone foundations (Refined, Rustic, Sturdy, Superior) with none of their walls, doorways, roofs or windows. Those exist only in the side tables: Rustic and Sturdy/Superior at dependency levels 4-5, Refined at 15-16.
  - It places Rustic, Refined and Sturdy doors after the Master smithy, although they need only planks or boards plus iron (from steps 64-65). Only the Superior door needs steel (step 101). **The "doors after the Master smithy" dependency is not real.**
  - The Engineered tier needs no steel, Blast furnace or Master smithy (only Mixer + Kiln). Fortified needs only iron bands and a metal hammer, apart from the Fortified door (10 steel).
- Evidence: the costs in matrix (c).
- Correction (proposed positions):
  - **Rustic block** (foundation, wall, doorway, window, roof with Bark shingles) after step 33. Bark shingle is side L177; bark source per acquisition workstream.
  - **Sturdy block** (foundation, Stone block ×12 + mortar wall, doorway) after step 69. The Sturdy roof needs stone shingles + planks, so put it after step 64.
  - **Refined block** (foundation, wall, doorway, roof with Wooden shingles) after step 66.
  - **Superior block** after step 69. The Superior roof needs Clay roof tiles, so put it after the Kiln.
  - Rustic and Sturdy doors right after the Refined block. Superior door after step 101.
  - Engineered (110-113) right after step 99. Fortified (114-118) can follow, except the Fortified door after step 101.
  - The Master smithy (105) can then be the last smithing step.

**W-L08 — MEDIUM — the Stonecutter's bench (step 71) is a dead end in the main route.**
- Problem: every recipe of the bench keeps a Bronze - Chisel. The chisel is never in the main route (side L522, forge L1), and bronze first appears at step 87. Catalog s2.1: "Chisel … Sculpture and art only; not required for stone construction". So the bench gives a main-route player nothing.
- Evidence: `recipes.json recipes.bench_stone_block`, `carved_stone_block` and `carved_stone_shingle` all have `keeps` bronze_chisel.
- Correction: move `build:stonecutters_bench` to the side tables. Alternatively move it after step 91 and ADD `craft:bronze_chisel` immediately before it.

**W-L09 — MEDIUM — water is never taught.**
- Affected: steps 51 and 98, and about 20 recipes overall.
- Evidence: pass2_report.txt "UNTAUGHT DEPENDENCIES": input:water 20. The item is `gathered.json items.water`, "gathered in a container".
- Per acquisition workstream. Here: ADD a water-container step before step 51.

**W-L10 — LOW — workbench levels are not explained, and the draft states a false dependency.**
- Affected: steps 67, 70, 77; side L170, L208.
- How levels work in code:
  - A station's level is its own `station_level` plus one per **different** add-on kind (`addon_of` workbench: Tool rack, Vice) within 5 m.
  - Wooden workbench = 1, +Tool rack = 2, +Vice = 3.
  - Carpenter's bench = 2, up to 4 with both add-ons.
  - Stone - Workbench = 3, up to 5.
- No live recipe needs more than workbench L3 (only `water_wheel` and `spyglass`). So **workbench L4 comes from** a Carpenter's bench with both add-ons, or a Stone - Workbench with one, and nothing uses it.
- The Carpenter's bench is not a prerequisite of the Stone - Workbench. The draft's s4 line "inserted the missing Carpenter's bench … before the level-3 Stone Workbench" implies one.
- Evidence: `structures.json structures.workbench / log_workbench / stone_workbench / tool_rack / vice` and the structures.json note "A station's level is 1 plus the number of different add-on kinds". server_items.gd:13184-13190 and 13248-13263. test_stations.gd:80 (a tool rack makes L2) and :117 AUTOMATED_TESTED (reported).
- Correction:
  - Step 70: add "gives workbench level 3".
  - Step 77: "Use a level-3 workbench: the Stone - Workbench, or a Workbench with a Tool rack and a Vice beside it".
  - Steps 67 and 70: say what each level unlocks.
  - Tool rack and Vice rows: say "place within 5 m of a workbench to raise its level".

**W-L11 — LOW — the Master smithy's purpose is untaught (step 105).**
- What it does in code: lets any forge/smithy recipe it serves be made as +1/+2 craftsmanship variants (more materials and time).
- Evidence: `smithing.json craft` (station master_smithy, materials [1.0,1.5,2.0], time [1.0,2.0,3.0]); server_items.gd:17083-17096; catalog s2.7 item 6 [D1].
- No later goal uses it, and no goal asks for a +1/+2 item.
- Correction: one sentence in step 105. Optionally ADD "Craft a masterwork (+1) item" after step 105 (PROPOSAL; completion event per runtime workstream).

**W-L12 — LOW — quantities are missing where one craft is not enough.**
- Iron ingots: 3 for the Smithy, 7 by step 62.
- Pine tar: 20 for 4 Tar (steps 75-76); the How-to says 5.
- Nails: 180 = 2 crafts.
- Iron bands: 19 = 10 crafts.
- Concrete: 73 = 25 crafts.
- Clay roof tiles: 24 = 8 crafts.
- Charcoal volume: see W-L04.
- Main-route totals (my count from blueprint and recipe costs; not GAMEPLAY_VERIFIED): about 108 iron ingots (432 iron ore), 22 steel ingots and about 150 bricks.
- The scale of bog-iron digging this implies is per acquisition workstream.
- Evidence: `recipes.json` gives counts; `blueprints.json` costs.
- Correction: state the needed count in the How-to of each producing step.

**W-L13 — LOW — group ingredients are shown as one item.**
- Affected: steps 56, 59, 64, 65, 85, 86, 101.
- "5 Fuel" means Charcoal or Coal (`ingredient_groups.fuel`; `items.json items.fuel` is a group, "Never given itself").
- "2 Hard firewood" (step 56) also accepts Soft firewood (`ingredient_groups.firewood`).
- "1 Spruce log" and "1 Oak log" are "Softwood log" and "Hardwood log" (`group_labels`).
- Evidence: goals_parsed.json `static_flags` GROUP_SHOWN_AS_KEY_ITEM on lines 83, 91, 92.
- Correction: use the group labels and name the members once.

**W-L14 — LOW — Tanbark source text (step 49).** The How-to names mangrove, which is RETIRED/FUTURE (`items.json items.log_mangrove`). Data drops Tanbark from oak (`drops.json harvest_yield.oak.item`). Per acquisition workstream.

**W-L15 — HIGH (side tables) — 24 goals point at blueprints that can never be built today.**
- Problem: these blueprints have `locked` true and `known` false. `_can_blueprint` returns false for any `known` false row, and test_blueprints.gd:199 records that their kit recipes are retired and cannot be learned.
- Evidence: `blueprints.json`; server_items.gd:8138.
- In levels 6-17:
  - build:wool_rug (L507)
  - build:iron_deep_well_pump (L605), iron_hand_pump (L612), iron_pipe (L615), iron_pipe_elbow (L616), iron_tap (L620)
  - build:wooden_cold_frame (L643), wooden_compost_bin (L644), stone_raised_cistern (L662), wooden_sluice (L684)
  - build:wooden_channel / _corner / _tee (L705-707), wooden_hand_pump (L709), wooden_trough (L712)
  - build:stone_well (L737)
- At level 5: build:stone_cistern, clay_pipe_run/elbow/tee, stone_channel/_corner/_tee, stone_trough (L308-323).
- These goals cannot be completed, so their coins cannot be earned.
- Correction: move these rows to a "future / locked" list outside the active goal set until the blueprints are made learnable. That is a catalog/data decision for Dave, not changed here.

**W-L16 — LOW — add-on station rows do not say where to place them or what they do.**
- Rows: build:bellows L513, build:quenching_trough L514, build:fireplace_cooking_crane L570.
- What the data says:
  - The Bellows and Quenching trough are `addon_of` brick_forge and work only within 5 m of a **Smithy**. They do not raise its level (`adds_level` false).
  - Bellows: craft_speed 1.25, fuel_saving 1.5. The trough enables Tempered steel.
  - The cooking crane serves as a campfire pot only within 2.5 m of a **lit Fireplace** (side L312).
- Evidence: `structures.json structures.bellows / quenching_trough / fireplace_cooking_crane`; server_items.gd:13064-13065 (fireplace crane); `smithing.json temper`; test_stations.gd:156-163 and test_mission001 3x-3y AUTOMATED_TESTED (reported).
- Correction: one placement-and-effect sentence each.

**W-L17 — LOW — hammer wording.**
- In code, the heaviest working hammer anywhere on the **hotbar** counts; it does not have to be held (server_items.gd:8194-8206).
- "Metal hammer" = tier ≥3: bronze 3, iron 4, steel 5 (`items.json items.*_hammer.tier`). Catalog s2.1: "Any metal hammer builds any tier (decision 73)". Implemented: Fortified pieces, Master smithy and Fine/Ornate/Iron/warehouse pieces need hammer 3; Engineered needs hammer 1.
- No blueprint uses hammer 2, so the Stone - Hammer (side L193) gates nothing; it only extends sourcing range (catalog s2.1).
- Correction: "Have a bronze, iron or steel hammer on your hotbar". Main-route steps 105 and 114-118 are satisfied by the Iron - Hammer from step 61.

**W-L18 — LOW — introductory stations with no downstream use in the main route.**
- Steps 52-55: Leatherworking table, Tailor's table, Loom, Preserving jar.
- They are valid, but each How-to should say what it is for, or they should move to their side branches.
- Leather strap (side L439) is needed by bronze and iron axes and greaves, so the Leatherworking table does matter for the side tables.

**W-L19 — INFO — verified non-issues.**
- **No circular requirement** in live data along the main route. Iron needs bronze only for rock ore (bog iron avoids it). Planks need only the Iron - Saw, never the Sawmill: lumber_by_hand and hardwood_board_by_hand, as the draft correctly says. The Smithy needs ingots from the Smelter, which needs no metal.
- **Retired stations:** no draft goal uses clay_bloomery or woodworking_table (`structures.json structures.clay_bloomery/woodworking_table` retired; draft grep: no row). Their only recipes (`bloomery_iron`, `fine_board`) are retired.
- **Station levels check out:**
  - Smithy = brick_forge L2 + forge L1 (iron recipes are brick_forge L1/L2, bronze recipes forge L1).
  - Master smithy = master_smithy L1 + brick_forge 2 + forge 1.
  - Blast furnace = blast_furnace L1 + smelter 1 (steel only here).
  - Iron - Saw at the Smithy (brick_forge L1).
  - Planks 6 per softwood log and Hardwood boards 4 per hardwood log, by hand saw or Sawmill (`recipes.json hand_saw_balance`).
  - Wooden pin at workbench L1. Carpenter's bench = workbench L2. Stone - Workbench = workbench L3.
  - Smithy cost includes 3 iron ingots.
  - These match the catalog (s2.7 items 1-7; s3.3).
- Every tiered construction blueprint appears in the draft (matrix (c), 0 "NOT IN DRAFT").
- The Fortified tier has no Window, Roof, Roof corner, Ceiling, Stairs or Fence in data, so a Fortified building must take another tier's roof. That is a catalog matter, reported here and not proposed as a change.

**Easiest introductory route vs advanced alternatives (data-backed)**

| Need | Easiest (intro) | Advanced alternative |
|---|---|---|
| Iron ore | Bog iron dug with the Wooden - Spade (`digging.json bog_iron`) | Rock iron with a Bronze/Iron/Steel pickaxe (`boulders.json ore.needs_material.iron`) |
| Fuel | Campfire charcoal, 12 per 2 firewood (`recipes.charcoal`) | Kiln charcoal, 100 per log (`structures.kiln`); mined Coal with any pick |
| Bronze working | Stone - Forge, no fuel (`structures.stone_forge`) | Burning Smithy (also forge 1); Master smithy |
| Smelting | Smelter, no fuel needed to run | Blast furnace (also smelter 1, must burn) |
| Workbench L2 | Wooden workbench + Tool rack (sticks, twine) | Carpenter's bench (planks, pins: post-iron) |
| Workbench L3 | Wooden workbench + Tool rack + Vice | Stone - Workbench (cobblestone, mortar, planks) |
| Planks / boards | Iron - Saw by hand, 24 s | Sawmill, 6 s (river + raised foundation) |
| Bricks | Campfire, 3 per 2 clay | Kiln, 6 per 2 clay (`recipes.kiln_brick`) |
| Stone block | Workbench, 8 stone | Stonecutter's bench, 6 stone + Bronze - Chisel kept |
| Nails / hinges | Iron at the Smithy (L2) | Bronze nails/hinges at the Stone - Forge (fill the same `nails`/`hinges` groups) |
| Hammer ≥3 | Bronze - Hammer (Stone - Forge) | Iron/Steel - Hammer (Smithy) |
| Door frame | Any empty single doorway, even Crude | Matching-tier doorway (cosmetic only) |

**Highest-tier outputs actually available (live data, CODE_VERIFIED):**
- Steel tools, weapons and armour, up to Steel - Plate harness and Half plate (brick_forge L1 + Blast-furnace steel).
- Tempered steel variants (Smithy + Quenching trough).
- +1/+2 craftsmanship (Master smithy).
- The Fortified construction set: foundation, wall, doorway shapes, pillar, wall top, gate.
- Fortified doors (10 iron + 10 steel).
- Superior doors (steel).
- Ornate, Fine and Warehouse furniture (hammer 3).
- Handcart.

Not available: the whole water network (locked, W-L15).

---

## (c) Construction-tier matrix

From `blueprints.json` (live rows only; tier = the name prefix). "Main route" = step number in route MAIN. "Draft row" = line in PLAYER_GOALS_REWARDS_DRAFT.md with its dependency level. Hammer: 1 wooden+, 3 bronze/iron/steel.

Two placement rules apply to every tier:
- Walls, roofs and ceilings snap to **any** foundation's anchors, whatever the tier (placement_rules.gd:63-168).
- Doors fit **any** doorway with the same opening (placement_rules.gd:587-619).

**Crude**

| Piece | Blueprint id | Cost | Hammer | Main route | Draft row |
|---|---|---|---|---|---|
| Foundation | `thatch_floor` | 4 twine, 20 thatch | 1 | step 28 | L55 |
| Wall | `thatch_wall` | 3 twine, 20 thatch, 6 stick | 1 | step 29 | L56 |
| Doorway | `thatch_doorway` | 3 twine, 20 thatch, 6 stick | 1 | step 30 | L57 |
| Double doorway | `thatch_double_doorway` | 6 twine, 40 thatch, 12 stick | 1 | no | L246 (lvl 4) |
| Arched doorway | `thatch_arched_doorway` | 3 twine, 20 thatch, 6 stick | 1 | no | L244 (lvl 4) |
| Double arched doorway | `thatch_double_arched_doorway` | 6 twine, 40 thatch, 12 stick | 1 | no | L245 (lvl 4) |
| Window | `thatch_window` | 15 thatch, 8 stick, 3 twine | 1 | step 31 | L58 |
| Door | `crude_door` | 50 stick, 100 twine | 1 | no | L200 (lvl 2) |
| Double door | `crude_double_door` | 100 stick, 200 twine | 1 | no | L202 (lvl 2) |
| Arched door | `crude_arched_door` | 50 stick, 100 twine | 1 | no | L199 (lvl 2) |
| Double arched door | `crude_double_arched_door` | 100 stick, 200 twine | 1 | no | L201 (lvl 2) |
| Roof 45 | `thatch_roof` | 6 twine, 30 thatch, 12 stick | 1 | step 32 | L59 |
| Roof 65 | `thatch_roof_65` | 6 twine, 30 thatch, 12 stick | 1 | step 33 | L60 |
| Roof corner | `thatch_roof_corner` | 4 twine, 18 thatch, 8 stick | 1 | no | L247 (lvl 4) |
| Pillar | `thatch_pillar` | 6 stick, 2 twine | 1 | no | L205 (lvl 2) |
| Fence | `thatch_fence` | 12 stick, 2 twine | 1 | no | L203 (lvl 2) |
| Gate | `thatch_gate` | 14 stick, 3 twine | 1 | no | L204 (lvl 2) |

No blueprint in data for Crude: Ceiling, Stairs, Wall top.

**Rustic**

| Piece | Blueprint id | Cost | Hammer | Main route | Draft row |
|---|---|---|---|---|---|
| Foundation | `log_foundation` | 10 log, 6 stone, 2 twine | 1 | step 80 | L107 |
| Wall | `log_wall` | 6 log, 2 twine | 1 | no | L264 (lvl 4) |
| Doorway | `log_doorway` | 6 log, 2 twine | 1 | no | L255 (lvl 4) |
| Double doorway | `log_double_doorway` | 12 log, 4 twine | 1 | no | L257 (lvl 4) |
| Arched doorway | `log_arched_doorway` | 6 log, 2 twine | 1 | no | L253 (lvl 4) |
| Double arched doorway | `log_double_arched_doorway` | 12 log, 4 twine | 1 | no | L256 (lvl 4) |
| Window | `log_window` | 5 log, 2 twine | 1 | no | L265 (lvl 4) |
| Door | `rustic_door` | 5 lumber | 1 | step 107 | L134 |
| Double door | `rustic_double_door` | 10 lumber | 1 | no | L681 (lvl 15) |
| Arched door | `rustic_arched_door` | 5 lumber | 1 | no | L677 (lvl 15) |
| Double arched door | `rustic_double_arched_door` | 10 lumber | 1 | no | L680 (lvl 15) |
| Roof | `log_roof` | 4 log, 14 bark_shingle, 2 twine | 1 | no | L261 (lvl 4) |
| Roof corner | `log_roof_corner` | 3 log, 9 bark_shingle, 2 twine | 1 | no | L262 (lvl 4) |
| Ceiling | `log_floor` | 8 log, 2 twine | 1 | no | L254 (lvl 4) |
| Stairs | `log_stairs` | 8 log, 2 twine | 1 | no | L263 (lvl 4) |
| Pillar | `log_pillar` | 1 log, 1 twine | 1 | no | L260 (lvl 4) |
| Fence | `log_fence` | 3 log, 1 twine | 1 | no | L258 (lvl 4) |
| Gate | `log_gate` | 4 log, 2 twine | 1 | no | L259 (lvl 4) |

No blueprint in data for Rustic: Wall top.

**Refined**

| Piece | Blueprint id | Cost | Hammer | Main route | Draft row |
|---|---|---|---|---|---|
| Foundation | `wood_foundation` | 8 lumber, 2 twine | 1 | step 79 | L106 |
| Wall | `wall_section` | 4 lumber, 1 twine | 1 | no | L675 (lvl 15) |
| Doorway | `doorway_section` | 4 lumber, 1 twine | 1 | no | L666 (lvl 15) |
| Double doorway | `double_doorway` | 8 lumber, 2 twine | 1 | no | L670 (lvl 15) |
| Arched doorway | `wood_arched_doorway` | 4 lumber, 1 twine | 1 | no | L664 (lvl 15) |
| Double arched doorway | `wood_double_arched_doorway` | 8 lumber, 2 twine | 1 | no | L668 (lvl 15) |
| Window | `window_section` | 3 lumber, 1 twine | 1 | no | L676 (lvl 15) |
| Door | `refined_door` | 6 hardwood_board, 1 iron_ingot | 1 | step 106 | L133 |
| Double door | `refined_double_door` | 12 hardwood_board, 2 iron_ingot | 1 | no | L669 (lvl 15) |
| Arched door | `refined_arched_door` | 6 hardwood_board, 1 iron_ingot | 1 | no | L663 (lvl 15) |
| Double arched door | `refined_double_arched_door` | 12 hardwood_board, 2 iron_ingot | 1 | no | L667 (lvl 15) |
| Roof | `roof_section` | 3 lumber, 18 wooden_shingle, 2 twine | 1 | no | L731 (lvl 16) |
| Roof corner | `wooden_roof_corner` | 2 lumber, 11 wooden_shingle, 1 twine | 1 | no | L732 (lvl 16) |
| Ceiling | `floor_section` | 4 lumber, 1 twine | 1 | no | L665 (lvl 15) |
| Stairs | `stairs_wood` | 8 lumber, 2 twine | 1 | no | L674 (lvl 15) |
| Pillar | `wooden_pillar` | 2 lumber, 1 twine | 1 | no | L673 (lvl 15) |
| Fence | `wood_fence` | 3 lumber, 1 twine | 1 | no | L671 (lvl 15) |
| Gate | `wood_gate` | 3 lumber, 1 twine, 1 hinges | 1 | no | L672 (lvl 15) |

No blueprint in data for Refined: Wall top.

**Sturdy**

| Piece | Blueprint id | Cost | Hammer | Main route | Draft row |
|---|---|---|---|---|---|
| Foundation | `foundation_section` | 8 stone, 2 clay | 1 | step 81 | L108 |
| Wall | `stone_wall` | 12 cut_stone_block, 4 mortar | 1 | no | L330 (lvl 5) |
| Doorway | `stone_doorway` | 12 cut_stone_block, 4 mortar | 1 | no | L325 (lvl 5) |
| Double doorway | `stone_double_doorway` | 24 cut_stone_block, 8 mortar | 1 | no | L327 (lvl 5) |
| Arched doorway | `stone_arched_doorway` | 12 cut_stone_block, 4 mortar | 1 | no | L324 (lvl 5) |
| Double arched doorway | `stone_double_arched_doorway` | 24 cut_stone_block, 8 mortar | 1 | no | L326 (lvl 5) |
| Window | `stone_window` | 9 cut_stone_block, 3 mortar | 1 | no | L331 (lvl 5) |
| Door | `sturdy_door` | 6 lumber, 2 iron_ingot | 1 | step 108 | L135 |
| Double door | `sturdy_double_door` | 12 lumber, 4 iron_ingot | 1 | no | L689 (lvl 15) |
| Arched door | `sturdy_arched_door` | 6 lumber, 2 iron_ingot | 1 | no | L687 (lvl 15) |
| Double arched door | `sturdy_double_arched_door` | 12 lumber, 4 iron_ingot | 1 | no | L688 (lvl 15) |
| Roof | `stone_roof` | 20 stone_shingle, 6 lumber | 1 | no | L691 (lvl 15) |
| Roof corner | `stone_roof_corner` | 12 stone_shingle, 4 lumber | 1 | no | L692 (lvl 15) |
| Ceiling | `stone_floor` | 6 lumber, 8 wooden_pin, 2 mortar | 1 | no | L735 (lvl 16) |
| Stairs | `stone_stairs` | 20 cobblestone, 4 mortar | 1 | no | L329 (lvl 5) |
| Pillar | `stone_pillar` | 8 cobblestone, 2 mortar | 1 | no | L328 (lvl 5) |
| Fence | `stone_fence` | 10 cobblestone | 1 | no | L269 (lvl 4) |
| Gate | `stone_gate` | 6 cobblestone, 3 lumber, 2 hinges | 1 | no | L690 (lvl 15) |

No blueprint in data for Sturdy: Wall top.

**Superior**

| Piece | Blueprint id | Cost | Hammer | Main route | Draft row |
|---|---|---|---|---|---|
| Foundation | `brick_foundation` | 16 brick, 4 mortar, 4 stone | 1 | step 82 | L109 |
| Wall | `brick_wall` | 16 brick, 4 mortar | 1 | no | L339 (lvl 5) |
| Doorway | `brick_doorway` | 16 brick, 4 mortar | 1 | no | L333 (lvl 5) |
| Double doorway | `brick_double_doorway` | 32 brick, 8 mortar | 1 | no | L335 (lvl 5) |
| Arched doorway | `brick_arched_doorway` | 16 brick, 4 mortar | 1 | no | L332 (lvl 5) |
| Double arched doorway | `brick_double_arched_doorway` | 32 brick, 8 mortar | 1 | no | L334 (lvl 5) |
| Window | `brick_window` | 12 brick, 3 mortar | 1 | no | L340 (lvl 5) |
| Door | `superior_door` | 12 hardwood_board, 2 iron_ingot, 1 steel_ingot | 1 | step 109 | L136 |
| Double door | `superior_double_door` | 24 hardwood_board, 4 iron_ingot, 2 steel_ingot | 1 | no | L695 (lvl 15) |
| Arched door | `superior_arched_door` | 12 hardwood_board, 2 iron_ingot, 1 steel_ingot | 1 | no | L693 (lvl 15) |
| Double arched door | `superior_double_arched_door` | 24 hardwood_board, 4 iron_ingot, 2 steel_ingot | 1 | no | L694 (lvl 15) |
| Roof | `brick_roof` | 5 lumber, 24 clay_roof_tile | 1 | no | L697 (lvl 15) |
| Roof corner | `brick_roof_corner` | 3 lumber, 15 clay_roof_tile | 1 | no | L698 (lvl 15) |
| Ceiling | `brick_floor` | 7 lumber, 8 wooden_pin, 3 mortar | 1 | no | L736 (lvl 16) |
| Stairs | `brick_stairs` | 20 brick, 4 mortar | 1 | no | L338 (lvl 5) |
| Pillar | `brick_pillar` | 8 brick, 2 mortar | 1 | no | L337 (lvl 5) |
| Fence | `brick_fence` | 10 brick, 2 mortar | 1 | no | L336 (lvl 5) |
| Gate | `brick_gate` | 6 brick, 2 mortar, 3 lumber, 2 hinges | 1 | no | L696 (lvl 15) |

No blueprint in data for Superior: Wall top.

**Engineered**

| Piece | Blueprint id | Cost | Hammer | Main route | Draft row |
|---|---|---|---|---|---|
| Foundation | `engineered_foundation` | 14 concrete, 4 stone | 1 | step 110 | L137 |
| Wall | `engineered_wall` | 11 concrete | 1 | step 111 | L138 |
| Doorway | `engineered_doorway` | 11 concrete | 1 | no | L746 (lvl 17) |
| Double doorway | `engineered_double_doorway` | 22 concrete | 1 | no | L748 (lvl 17) |
| Arched doorway | `engineered_arched_doorway` | 11 concrete | 1 | no | L744 (lvl 17) |
| Double arched doorway | `engineered_double_arched_doorway` | 22 concrete | 1 | no | L747 (lvl 17) |
| Window | `engineered_window` | 8 concrete | 1 | no | L751 (lvl 17) |
| Door | `engineered_door` | 12 lumber, 4 iron_ingot | 1 | step 113 | L140 |
| Double door | `engineered_double_door` | 24 lumber, 8 iron_ingot | 1 | no | L650 (lvl 15) |
| Arched door | `engineered_arched_door` | 12 lumber, 4 iron_ingot | 1 | no | L648 (lvl 15) |
| Double arched door | `engineered_double_arched_door` | 24 lumber, 8 iron_ingot | 1 | no | L649 (lvl 15) |
| Roof | `engineered_roof` | 5 lumber, 24 clay_roof_tile, 8 wooden_pin | 1 | step 112 | L139 |
| Roof corner | `engineered_roof_corner` | 3 lumber, 15 clay_roof_tile, 5 wooden_pin | 1 | no | L728 (lvl 16) |
| Ceiling | `engineered_floor` | 12 concrete, 2 lumber | 1 | no | L745 (lvl 17) |
| Stairs | `engineered_stairs` | 15 concrete | 1 | no | L750 (lvl 17) |
| Pillar | `engineered_pillar` | 5 concrete | 1 | no | L749 (lvl 17) |

No blueprint in data for Engineered: Fence, Gate, Wall top.

**Fortified**

| Piece | Blueprint id | Cost | Hammer | Main route | Draft row |
|---|---|---|---|---|---|
| Foundation | `fortified_foundation` | 16 concrete, 4 iron_band | 3 | step 114 | L141 |
| Wall | `fortified_wall` | 13 concrete, 4 iron_band | 3 | step 115 | L142 |
| Doorway | `fortified_doorway` | 13 concrete, 4 iron_band | 3 | step 116 | L143 |
| Double doorway | `fortified_double_doorway` | 26 concrete, 8 iron_band | 3 | no | L754 (lvl 17) |
| Arched doorway | `fortified_arched_doorway` | 13 concrete, 4 iron_band | 3 | no | L752 (lvl 17) |
| Double arched doorway | `fortified_double_arched_doorway` | 26 concrete, 8 iron_band | 3 | no | L753 (lvl 17) |
| Door | `fortified_door` | 10 iron_ingot, 10 steel_ingot | 3 | step 117 | L144 |
| Double door | `fortified_double_door` | 20 iron_ingot, 20 steel_ingot | 3 | no | L608 (lvl 14) |
| Arched door | `fortified_arched_door` | 10 iron_ingot, 10 steel_ingot | 3 | no | L606 (lvl 14) |
| Double arched door | `fortified_double_arched_door` | 20 iron_ingot, 20 steel_ingot | 3 | no | L607 (lvl 14) |
| Pillar | `fortified_pillar` | 7 concrete, 2 iron_band | 3 | no | L755 (lvl 17) |
| Gate | `fortified_gate` | 6 concrete, 7 iron_band, 5 lumber, 2 hinges | 3 | step 118 | L145 |
| Wall top | `fortified_wall_top` | 7 concrete, 2 iron_band | 3 | no | L756 (lvl 17) |

No blueprint in data for Fortified: Window, Roof, Roof corner, Ceiling, Stairs, Fence.

Untiered building pieces (all in the draft, side tables): Palisade and Palisade gate (`log_palisade`, `log_palisade_gate`; hinges 2); Beam (`timber_set`); Post (`timber_prop`); Ladder; Wooden - Railing; Iron - Fence, Iron - Gate and Iron - Railing (hammer 3; L610, L611, L617).

---

## (d) Side branches, dependency levels 6-17: goal ids checked

Method: each row's recipe or blueprint was re-checked against data for retired/locked/unknown status, a reachable station and level, hammer tier, and inputs taught by an earlier goal (scratch script; the static tool's MATERIALS_MISMATCH flag fires only on `craft:firewood` in the whole draft, so stated materials match data for every row below).

Out of scope here:
- 68 cooking/food rows (stations campfire_pot, clay_hearth, oven, food_preparation_table, preserving_jar, smoker).
- The legacy goals night_walk, dry_berries, path, jerky, salted_fish, smoke_fish, candle, winter_store (per runtime workstream).

"(acq)" = an input with no teaching goal, per acquisition workstream.

**Tanning and leatherworking** (tanning_rack, leatherworking_table; built at steps 50 and 52)
- craft:heavy_leather L437: YES (tanning rack; leather 2, tanbark 2).
- craft:leather_strap L439: YES (keeps any knife). Needed by bronze/iron/steel axes and greaves, snowshoes and straps.
- craft:leather_belt L438: YES (toggle from bone, L294).
- craft:leather_apron L459, leather_backpack L460, leather_boots L461, leather_broad_brim_hat L462, leather_cap L463, leather_gloves L464, leather_jerkin L465, leather_quiver L466, leather_satchel L467, leather_shoes L468, leather_trousers L469, utility_bandolier L476, weapon_scabbard L477: YES each (leatherworking table; leather + straps; Bone - Needle kept, L282).

**Hand sewing** (no station; Bone - Needle kept, thread from step 44)
- craft:bedroll L356, belt_pouch L358, backpack L380 (rope), hide_boots L381, hide_cloak L382, hide_gloves L383, hide_hood L384, hide_mittens L385, quiver L386, hide_trousers L387, hide_tunic L388, waterskin L418: YES each.

**Tailoring and weaving** (tailors_table, loom; built at steps 53-54)
- gather:flax L427, gather:wool L428: (acq).
- craft:linen L470, craft:wool_cloth L478: YES once flax/wool are obtained.
- craft:gambeson L365: YES (fibre cloth from loom).
- craft:fur_boots L372, fur_cloak L373, fur_hat L374, fur_mittens L375: YES-WITH-UNTAUGHT-PREREQ (fur, sinew (acq)).
- craft:tool_roll L475: YES (linen, thread, strap).
- craft:linen_apron L486, linen_dress L487, linen_headwrap L488, linen_shirt L489, linen_skirt L490, linen_trousers L491, tabard L495: YES each.
- craft:oilcloth_cloak L493: YES (lamp oil from herring L290; herring (acq)).
- craft:travellers_rucksack L496, wool_cap L497, wool_cloak L498, wool_coat L499, wool_dress L500, wool_mittens L501, wool_robe L502, wool_scarf L503, wool_socks L504, wool_trousers L505, wool_tunic L506: YES each once wool cloth exists.
- build:wool_rug L507: **NO** (blueprint locked + unknown; W-L15).
- build:feather_bed L421, build:canopy_bed L641: YES-WITH-UNTAUGHT-PREREQ (feather, down (acq)).

**Woodworking** (workbench levels, hand saw, chopping block)
- craft:quarterstaff L404, serving_platter L411, wooden_club L419, wooden_bowl L420: YES (wooden block from step 11; knife kept).
- craft:light_crossbow L392: YES-WITH-UNTAUGHT-PREREQ (sinew (acq)).
- craft:wooden_snowshoes L474: YES (workbench L1; straps).
- craft:firewood_soft L494: YES (chopping block from step 17; any axe).
- craft:bucket L629: YES (hand; 6 planks).
- craft:wooden_shingle L633: YES (workbench L1; knife kept). Feeds the Refined roof.
- craft:wooden_lantern L632: YES (candle goal L432; horn pane L221, horn (acq)).
- craft:plank_shield L721: YES (workbench L2 via Carpenter's bench or Tool rack; hide glue L389).
- craft:wooden_longbow L719: YES-WITH-UNTAUGHT-PREREQ (large wooden block, sinew (acq)).
- craft:spyglass L722: YES-WITH-UNTAUGHT-PREREQ (workbench L3; crystal lens (acq)). The draft says "Hardwood block"; the group is "Wooden block".

**Furniture, storage, signs, lights** (hammer blueprints; boards, pins, nails)
- Hammer 1, YES each: build:apothecary_cabinet L635, armour_stand L636, wooden_barrel L637, timber_set L638, bookcase L639, bottle_and_jar_rack L640, wooden_crate L645, wooden_cupboard L646, dresser L647, ladder L655, large_wooden_chest L656, ore_and_metal_rack L657 (iron bands), chair L678, plank_chest L679, table L682, sign L683, stone_table L685, storage_sign L686 (charcoal), tool_cabinet L699, wardrobe L701, warehouse_desk L703, weapon_rack L704, wooden_railing L711, board_rack L723, bench L724, crude_chair L725, crude_chest L726, crude_table L727, masons_pallet L729, open_storage_bin L730, wooden_shelf L733, stool L734 (pins: post-saw), wooden_lamp_post L738 (wooden lantern).
- Hammer 3, YES once a bronze, iron or steel hammer is on the hotbar: build:iron_bench L651, iron_chair L652, fine_chest L653, iron_table L654, ornate_chair L658 (wool cloth), iron_chest L659, ornate_table L660, warehouse_crate L702.
- YES-WITH-UNTAUGHT-PREREQ (acq): build:antler_mount L634 (antler), tusk_mount L700 (tusk), wooden_planter_box L661 and wooden_garden_plot L708 (soil).
- build:chandelier L642, wooden_hanging_lantern L710: YES (candles from the candle goal).
- build:wooden_torch_post L451, wall_torch L452: YES (tallow L414).

**Stoneworking** (stonecutters_bench, step 71)
- craft:carved_stone_block L571, carved_stone_shingle L572: YES only after craft:bronze_chisel L522. This is the bench's only use (W-L08). Inputs: Stone block L227, Stone shingle L228.

**Pottery and kiln**
- No side goal at levels 6-17 uses the kiln. Kiln bricks (`recipes.kiln_brick`) and Kiln charcoal (use action) have no goal at all (W-L04).
- Clay pipe/jug/mug rows are at levels 4-5, outside this range. Clay pipe placements are locked (W-L15).

**Smelting** (smelter, blast furnace)
- No side goals at levels 6-17. All smelting is in the main route (steps 59, 85-87, 101).

**Bronze** (station forge L1: Stone - Forge, or burning Smithy/Master smithy)
- YES each: craft:bronze_axe L521 (strap), bronze_chisel L522, bronze_greaves L523 (straps), bronze_helm L524, bronze_knife L525, bronze_mace L526, bronze_scale_shirt L527, bronze_scythe L528, bronze_shield L529 (wicker shield L166, hide), bronze_sickle L530, bronze_spear L531.
- craft:bronze_hinges L532, bronze_nails L533: YES (they fill the `hinges`/`nails` groups).
- craft:bronze_arrow L520: YES-WITH-UNTAUGHT-PREREQ (feather (acq)).

**Iron smithy** (brick_forge L1/L2: the Smithy, burning; W-L02 applies to every row)
- YES each: craft:iron_axe L536, iron_battleaxe L537, iron_breastplate L539, iron_buckler L540, iron_cauldron L541, iron_chisel L542, iron_frying_pan L543, iron_gauntlets L544, iron_greataxe L545, iron_greatsword L546, iron_greaves L547, iron_grill_grate L548, iron_halberd L549, iron_helm L550, iron_hoe L551, iron_knife L552, iron_mace L554, iron_pike L555, iron_sabatons L556, scythe L557, iron_shortsword L558, iron_sickle L559, iron_spade L560, iron_spear L561, iron_trident L562, iron_warhammer L563, rivets L564, iron_shield L630 (planks).
- Riveted iron armour, YES (rivets L564; heavy leather L437 for the brigandine): craft:iron_brigandine L573, iron_mail_chausses L574, iron_mail_coif L575, iron_mail_hauberk L576, mail_shirt L577.
- craft:iron_lantern L553: YES (horn pane, lamp oil; horn (acq)).
- YES-WITH-UNTAUGHT-PREREQ (acq): craft:heavy_crossbow L534 (sinew), iron_arrow L535 and iron_bolt L538 (feather).

**Steel** (Blast-furnace steel + Smithy brick_forge L1)
- YES each: craft:steel_axe L579, steel_battleaxe L580, steel_chisel L581, plate_cuirass L582, steel_gauntlets L583, steel_greataxe L584, steel_greatsword L585, steel_greaves L586, steel_halberd L587, steel_half_plate L588, steel_helm L589, steel_hoe L590, steel_knife L591, steel_mace L592, steel_maul L593, steel_plate_harness L594, steel_rapier L595, steel_sabatons L596, steel_saw L597, steel_scimitar L598, steel_scythe L599, steel_shortsword L600, steel_sickle L601, steel_spade L602, steel_spear L603, steel_warhammer L604, steel_shield L631.
- Tempered variants need a Quenching trough beside the Smithy (`smithing.json temper.include`).
- craft:steel_arrow L578: YES-WITH-UNTAUGHT-PREREQ (feather (acq)).

**Smithy add-ons and advanced stations**
- build:bellows L513: YES; placement/effect untaught (W-L16).
- build:quenching_trough L514: YES; same.
- build:fireplace_cooking_crane L570: YES (iron bands; needs a lit Fireplace within 2.5 m, L312; W-L16).

**Metal construction and lights** (hammer 3 unless noted)
- YES each: build:iron_brazier L609, iron_fence L610, iron_gate L611, iron_railing L617, iron_torch_stand L622, stone_torch_pillar L621 (tallow).
- YES (iron lantern L553): build:iron_lamp_post L614, stone_lamp_post L619.
- YES (horn panes, lamp oil): build:iron_hanging_lantern L613, iron_wall_lantern L623.
- build:log_palisade_gate L618: YES (hammer 1; hinges).

**Water system and other locked blueprints**
- **NO** each (W-L15): build:iron_deep_well_pump L605, iron_hand_pump L612, iron_pipe L615, iron_pipe_elbow L616, iron_tap L620, wooden_cold_frame L643, wooden_compost_bin L644, stone_raised_cistern L662, wooden_sluice L684, wooden_channel L705, wooden_channel_corner L706, wooden_channel_tee L707, wooden_hand_pump L709, wooden_trough L712, stone_well L737 (and wool_rug L507 above).

**Construction tiers** (hammer blueprints; see matrix (c))
- Refined, YES each after planks: build:wood_arched_doorway L664, floor_section L665, doorway_section L666, wood_double_arched_doorway L668, double_doorway L670, wood_fence L671, wood_gate L672 (hinges), wooden_pillar L673, stairs_wood L674, wall_section L675, window_section L676, roof_section L731 (wooden shingles L633), wooden_roof_corner L732.
- Doors, YES-WITH-UNTAUGHT-PREREQ each (needs a free doorway of the same opening: double needs a double frame, arched an arched frame; W-L06):
  - Rustic: rustic_arched_door L677, rustic_double_arched_door L680, rustic_double_door L681.
  - Refined: refined_arched_door L663, refined_double_arched_door L667, refined_double_door L669.
  - Sturdy: sturdy_arched_door L687, sturdy_double_arched_door L688, sturdy_double_door L689.
  - Superior (steel): superior_arched_door L693, superior_double_arched_door L694, superior_double_door L695.
  - Engineered: engineered_arched_door L648, engineered_double_arched_door L649, engineered_double_door L650.
  - Fortified (hammer 3; 20 iron + 20 steel for doubles): fortified_arched_door L606, fortified_double_arched_door L607, fortified_double_door L608.
- Sturdy, YES each: build:stone_gate L690 (hinges), stone_roof L691 and stone_roof_corner L692 (stone shingles + planks), stone_floor L735 (planks, pins, mortar).
- Superior, YES each: build:brick_gate L696, brick_roof L697 and brick_roof_corner L698 (kiln roof tiles), brick_floor L736.
- Engineered, YES each (concrete; water (acq)): build:engineered_roof_corner L728, engineered_arched_doorway L744, engineered_floor L745, engineered_doorway L746, engineered_double_arched_doorway L747, engineered_double_doorway L748, engineered_pillar L749, engineered_stairs L750, engineered_window L751.
- Fortified, YES each (hammer 3; concrete + iron bands): build:fortified_arched_doorway L752, fortified_double_arched_doorway L753, fortified_double_doorway L754, fortified_pillar L755, fortified_wall_top L756.

**Vehicles**
- craft:axle L718, craft:wooden_cart_wheel L720: YES (workbench L2: Carpenter's bench or Workbench + Tool rack; planks, pins, iron band). Catalog [D11] expects them at the Carpenter's bench; data allows any workbench L2.
- build:handcart L757: YES (hammer 1).
- Test evidence: test_mission001 6i-6j AUTOMATED_TESTED (reported).

---

## Verified / not verified

- **Verified by reading (CODE_VERIFIED):**
  - Every recipe, blueprint and structure field cited above.
  - Station serving and level code: server_items.gd:13023-13263.
  - Blueprint gating: server_items.gd:8134-8217.
  - Sawmill site rules: server_items.gd:3835-3875.
  - Ore tool rule: server_items.gd:5617-5618.
  - Door fitting: placement_rules.gd:587-627.
  - Master-smithy variants: server_items.gd:17083-17096.
- **AUTOMATED_TESTED (reported by the David4 run at dc2fa52, not run here):**
  - test_mission001_walkthrough steps 2b-2h, 3b-3y, 6i-6j.
  - test_stations.gd:80, 103-131, 156-164.
  - test_doors.gd:155-180.
- **Not verified:**
  - Whether a qualifying river exists near a typical base (Sawmill).
  - Every raw-material acquisition rate (per acquisition workstream).
  - Every goal completion event and whether it persists after a piece is taken down (per runtime workstream).
  - Any in-game play.
