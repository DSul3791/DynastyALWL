# Player goals catalog: corrected (review draft)

**Status: REVIEW DRAFT. Not activated.** Dave approved the 26 audit ADD goals and the coins-only rewards on 14 Nov 2026; the A-42 amounts are provisional, and the catalog goes into the game only on his explicit go. This is the GOALS-REPAIR R7 (WP-GOALS) package for Dave's catalog review, made under the item catalog freeze (`docs/ai-team/DECISION_AUTHORITY.md`). Nothing in it changes game code, `starter_goals.json`, `camp_goals.json` or `PLAYER_GOALS_REWARDS_DRAFT.md`. Values tagged A-n are provisional engineering assumptions from `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` §4. They are not Dave-approved.

- **Rows:** `PLAYER_GOALS_CATALOG_CORRECTED.csv` has one row per goal, 702 in all: the draft's 651 goals (`status` ORIGINAL), 25 new goals (`status` PROPOSED NEW: the 11 of R7, the five tier Roof 65 panels, the Fortified Roof 45, Roof 65 and Roof corner, and the six tier pieces of PR #1113) and the audit's 26 ADD goals, approved by Dave: 25 `status` APPROVED NEW and ADD-16, `status` MERGED into `activity:temper_steel` (A-43). See "Approved new goals" below.
- **Sources:**
  - Draft: `PLAYER_GOALS_REWARDS_DRAFT.md` (651 rows, 15,670 copper in total).
  - Audit: `PLAYER_GOALS_AUDIT_LEDGER.csv` (audit at `dc2fa52`).
  - Recovery: `PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md`, which holds the GA dispositions.
  - Data baseline: dev `9db936d` (data identical to `77460e3`). The hand-chop, fire-tier and site-kind fixes were read in PR #1095's worktree; #1095 has since merged to dev (`b94b1e7`).
- **Dev moved after the baseline.** Dev has since taken #1090 (Map), #1092 (R2a smelters), #1097 and #1098, and later #1089, #1095, #1099, #1100 and #1101.
- **Rechecked on dev `54b2c51` (R9, PR #1105; static read of data and code):**
  - **Verdicts changed:** the 22 WP-METAL R2 rows and `craft:iron_ingot` are no longer blocked: 17 are OK and 6 are FIX (they carry text corrections).
  - **Refs verified:** `build:improved_smelter` and the two Copper tool rows have their ids checked.
  - **Map goals:** the two map goals have their events from PR #1105.
  - **Second recheck on dev `d4b2473` (R9 follow-up; static):** every row blocked by WP-METAL R3, WP-METAL R4, WP-R1B, the `got_item` gap (#1100) or the `fire_tier` gap (#1095) whose goal item or structure is reachable from an empty character is no longer blocked: 258 rows, 119 OK and 139 FIX (123 and 135 before the A-35 roof rename).
    - "Reachable" comes from the reach model in `tools/encyclopedia_reach.py`, run with the smelting jobs added (that tool does not know the self-running smelters yet). It is a static read of the data, not play. Every such row is NEEDS PLAYER VERIFICATION.
    - The correction text of those rows was spot-checked, not re-read row by row, against the final R3 and R4 data. The review of #1108 found stale R3/R4 text in `build:large_forge`, `craft:steel_ingot` and `build:blacksmithy`; it is corrected, and the 252 build rows' GAP-PRIM-F1 note now says #1095 is in dev.
    - The check is reproducible: `python3 docs/ai-team/missions/GOALS-REPAIR/r9_reach_with_smelters.py . out.json` (it wraps `tools/encyclopedia_reach.py` and adds the smelting jobs; 1,072 items reachable on `d4b2473`).
  - **Roof 45 and 65 (#1110; naming CONFIRMED by Dave (14 Nov 2026 05:29Z: "all tiers get a tier - Roof 45 and tier - Roof 65. there is no such item as just roof", Fortified included)):** every tier has a "<Tier> - Roof 45" and a "<Tier> - Roof 65". A Roof 65 costing the same as its Roof 45 is still an assumption (A-35). The five `build:*roof` rows for Rustic, Sturdy, Superior, Refined and Engineered now say "choose <Tier> - Roof 45" and are FIX (they were OK). Goal ids and structure ids are unchanged. The Crude pair (`build:thatch_roof`, `build:thatch_roof_65`) already had both goals. The five new 65 panels are PROPOSED rows now (the R9 reward pass), and the Fortified pair follows when its data is in dev. The roofs PR is #1110. `PLAYER_GOALS_REWARDS_DRAFT.md` and the audit CSVs are the historical review inputs and are left as they were; this catalog supersedes them.
    - Still blocked (28): the 24 locked water and garden blueprints (all now UNASSIGNED; their materials are reachable; Dave 14 Nov 06:26Z keeps them as future goals, still locked), R5 (`build:master_forge`, `activity:temper_steel`), R6 (`build:open_storage_bin`) and `activity:chop_log_blocks` (no `made_item_any` check type). `activity:operate_bellows` is OK since the reward pass: `server_smelter.gd` emits `bellows_iron` in dev. R5, R6 and `made_item_any` have since landed in dev too; their rows are rechecked in the final R9 docs update, not here.
  - The counts below include these changes.
- **Rewards:** every row now pays the A-42 coin scale (section "Rewards (A-42)" below): 6,520 copper over the 701 paying rows, 6,010 of it on the 651 ORIGINAL rows. The draft's 15,670 copper is replaced.
- **Wording:** "go live" means the day the corrected catalog replaces the live goal files. It is not a player action; the player never activates anything.

## Rewards (A-42)

**Dave's rulings (14 Nov 2026):**

- 06:19Z: "all goals only payout coins". No item, reputation or other reward.
- 06:22Z: "+5cp for low level stuff and as you progress the amount increases a small simple amount to be determined reasonable by you the ai. just enough to keep the reward feeling good."
- 06:18Z: "they will get nothing because we will wipe the characters and all world edits and items to start fresh before testing". **No catch-up payouts:** characters, world edits and items are wiped before the catalog is tested, so no goal pays for anything done before.
- 06:18Z: the fanfare is a simple programmatic sound players learn to recognize (already in dev from #1093).
- 06:20Z: "gathering counts when you pick it or cut it down or harvest something by your own hand". A gather goal counts only what the character picks, cuts down or harvests by hand. Items bought, traded, looted or taken from storage do not count.

**The scale (A-42, assumed on Dave's behalf by the coordinator; provisional).** One flat amount per progression stage, with no bonuses and no exceptions:

| Stage | Pays | Covers | Rows |
|---|---:|---|---:|
| Stone | 5 copper | the start, stone tools, Crude | 416 |
| Bronze | 10 copper (1 bronze) | Copper, Bronze, Improved | 27 |
| Iron | 15 copper (1 bronze + 5 copper) | Iron, Refined, Advanced | 198 |
| Steel | 20 copper (2 bronze) | Steel, Fortified, Master | 60 |
| **All** | **6,520 copper** | 701 paying rows (651 ORIGINAL: 6,010; 25 PROPOSED: 360; 25 APPROVED: 150); the MERGED ADD-16 row pays nothing | **701** |

**How a row gets its stage.** A row pays the higher of two stages:

- the stage its title names (a tier word such as "Crude", "Copper", "Refined" or "Fortified", or a metal), and
- the stage its target really needs in the data: the static reach model (`r9_reach_with_smelters.py`) run with the later ingots withheld. A target reachable with no ingots is stone; with copper, tin and bronze ingots it is bronze; with iron as well it is iron; otherwise steel.

A row with no stage of its own (an event such as drinking or selling) takes the stage of the tool, item or station it needs (where any one of several will do, such as any hoe, the easiest of them), or stone when it needs none. Events are placed by a table in the tool (`EVENT_STAGES`, `EVENT_NEEDS`); repairing a worn smithy is stone, because the Primitive smithy already wears. Every row was placed; none is left without a reward.

**Rows that pay above the stage their name suggests**, because their data needs a later tier (right under the rule; listed so Dave can see them):

| Goal | By name | Pays |
|---|---|---|
| `activity:operate_bellows` | bronze (Improved smelter) | iron, 15: the bellows goal is the first Iron ingot |
| `build:bench` | stone (Crude) | iron, 15: it needs planks, and planks need the Iron saw |
| `build:crude_chair` | stone (Crude) | iron, 15: planks |
| `build:crude_chest` | stone (Crude) | iron, 15: planks |
| `build:crude_table` | stone (Crude) | iron, 15: planks |

The check is reproducible: `python3 docs/ai-team/missions/GOALS-REPAIR/goal_reward_stages.py .` prints the counts, the total and these rows (`--write` rewrites `reward_copper` and `reward_text`). It is a static read of the data, not play.

**Roof corners (A-37, #1118):** a corner now has a 45 and a 65 shape, and one placed at 65 records its `<kind>_65` twin, so the six corner goals and the new Fortified one count either shape (`what_any`).

## What Dave ruled on 14 Nov (06:26Z), and what it means here

- **The 26 audit ADD goals are approved** ("approve the 26 goals because the system is more important than the actual goals we can adjust them as we go"). They are rows now, with the A-42 scale.
- **The 24 locked blueprints stay** as future goals ("yes keep the 24 blueprints"). Their rows stay in the catalog, still locked and blocked (listed below).
- **The HUD order:** "the first goal should always be the first goal a play can do next. the second one will be what should be next." The HUD's first goal is the earliest goal the player can do now; the second is the one that should come after it. The coordinator's reading: a blocked goal (any row with a `blocking_wp`) is never one the player can do next, so it does not take a HUD slot; it stays visible in the Journal.
- **Build costs** stay assumed values that can be changed at any time ("keep assuming build costs we can adjust them in the future at anytiime").
- **Nothing is switched on.** Approving the rows does not activate the catalog in the game; that still waits for Dave's explicit go (the coordinator's reading).

**The 24 locked blueprints (future goals, still locked):**

1. `build:stone_cistern`: Cistern
2. `build:clay_pipe_run`: Clay - Pipe
3. `build:clay_pipe_elbow`: Clay - Pipe elbow
4. `build:clay_pipe_tee`: Clay - Pipe tee
5. `build:stone_channel`: Stone - Channel
6. `build:stone_channel_corner`: Stone - Channel corner
7. `build:stone_channel_tee`: Stone - Channel tee
8. `build:stone_trough`: Stone - Trough
9. `build:wool_rug`: Wool - Rug
10. `build:iron_deep_well_pump`: Deep-well pump
11. `build:iron_hand_pump`: Iron - Hand pump
12. `build:iron_pipe`: Iron - Pipe
13. `build:iron_pipe_elbow`: Iron - Pipe elbow
14. `build:iron_tap`: Tap
15. `build:wooden_cold_frame`: Cold frame
16. `build:wooden_compost_bin`: Compost bin
17. `build:stone_raised_cistern`: Raised cistern
18. `build:wooden_sluice`: Sluice
19. `build:wooden_channel`: Wooden - Channel
20. `build:wooden_channel_corner`: Wooden - Channel corner
21. `build:wooden_channel_tee`: Wooden - Channel tee
22. `build:wooden_hand_pump`: Wooden - Hand pump
23. `build:wooden_trough`: Wooden - Trough
24. `build:stone_well`: Well

## Rules applied

1. **Automatic goals.** Every goal is checked automatically. There is no player activation and no `after` award gate. `after` sets only the display order and the Journal links (GA-40, already done in dev by #1088).
2. **Once per character, coins only** (Dave 14 Nov 06:19Z: "all goals only payout coins"). The two live item rewards become coins at the A-42 stage amount when the catalog goes live: `twine` and `fell`, 5 copper each.
   - `story`'s live row also lists `rep: 1`, but `_goals_check` pays only `coin_copper` and `item`. The reputation was never paid, so this is not a switch. The dead field is simply dropped.
3. **Stable ids.**
   - The 28 legacy ids are unchanged.
   - Every other goal uses `<kind>:<key>`.
   - Each row names its item, recipe and blueprint by key and number (column `stable_refs`).
   - The metal ingot rows point to the smelting jobs. They do not point to the old recipes 185 and 190–192, which retire in PR #1092.
4. **Counting.**
   - **Crafts are counted per craft.** This follows the GOALS-REPAIR lead's work brief of 14 Nov. The craft queue calls `_goal_made(peer, gives, times)` with `times` set to 1 for each finished craft, or to the number of crafts in a sealed batch (`server_items.gd` ~17607). Where a recipe gives more than one item, the condition says "crafts". Jerky is the only goal where this changes the count: 2 crafts make 4 Jerky.
   - **Smelting is counted per ingot.** This is a ruling by the GOALS-REPAIR lead, following GA-44. PR #1092's `_credit` calls `_goal_made` once for each ingot delivered.
   - **Conflict, disclosed:** recovery GA-44 recommended counting units. The lead's brief says per craft, and this package follows the brief.
5. **Nothing is hidden or deleted.** Blocked rows stay in the catalog. They are visible and marked with the work package (WP) that unblocks them. This includes the 24 locked water and garden blueprints (GA-31).
6. **Precedence.** Where a row has several problems, its verdict follows this order: DESIGN-QUESTION, then BLOCKED-BY-MECHANIC, then FIX, then OK. A blocked row still carries its text corrections in `correction`, so it is ready on the day the blocker lands.

## Counts by verdict

| Verdict | All 651 | 328 rule-only rows (reviewed individually in this pass) | 323 rows already reviewed individually in the audit |
|---|---:|---:|---:|
| OK | 314 | 157 | 157 |
| FIX | 309 | 153 | 156 |
| BLOCKED-BY-MECHANIC | 28 | 18 | 10 |
| DESIGN-QUESTION | 0 | 0 | 0 |
| **Total** | **651** | **328** | **323** |

- **Blocked rows that also have text corrections:** 5, of which 3 are rule-only rows.
- **New goals:** 25 PROPOSED (verdict PROPOSED), 25 APPROVED NEW (2 OK, 23 BLOCKED-BY-MECHANIC until their new event is built) and 1 MERGED (ADD-16). They are not in the table above.
- **Rows with a play test or player-verification note:**
  - 109 need player verification of the PR #1091 sources (Tanbark, Pine tar, water from containers).
  - 58 are F6 door, doorway and bed checks.
  - 15 need a wool reach test (GA-39).
  - 2 others.
- **No row became a DESIGN-QUESTION.**
  - Every open point is already covered by a settled rule, a recovery disposition or an A-n assumption.
  - The scope questions are in the Dave decision list below; Dave ruled on items 1 to 5 on 14 Nov.
- **Build rows marked OK or FIX assume PR #1095.** In dev, a building finished as a site records `placed` with no kind (F1), and #1095 fixes this. Until #1095 lands, a building finished as a site does not complete its goal; a building placed straight from the pack does.

**Main blocker of each blocked row** (`blocking_wp`, first entry):

| WP | Rows | What it unblocks |
|---|---:|---|
| WP-METAL R2 (PR #1092) | 0 | Was 22. The Bronze route is in dev, and the rows were rechecked on `54b2c51` |
| WP-METAL R3 | 0 | Was 196. `activity:operate_bellows` is OK: `server_smelter.gd` credits the worker with `bellows_iron` (in dev) |
| WP-METAL R4 | 0 | Was 41. Steel, the Advanced smelter and the Advanced smithy are in dev (#1102) |
| WP-METAL R5 | 2 | Master smithy and tempering |
| WP-METAL R6 | 1 | Small Resource Bin (16 Planks and 32 Nails, single type) |
| WP-R1B (PR #1089) | 0 | Was 16. Client farming is in dev (#1089) |
| WP-PRIM (PR #1095) | 0 | Was 3. `fire_tier` and the hand-chop credit are in dev; `activity:chop_log_blocks` moved to WP-GUIDE-UI (it needs a check type) |
| WP-GUIDE-UI (goals section) | 1 | Was 19 (the `got_item` counter is in dev, #1100). Left: `activity:chop_log_blocks`, which needs a `made_item_any` check type |
| UNASSIGNED | 24 | Locked water and garden blueprints. Dave 14 Nov 06:26Z: kept as future goals, still locked. Since R3 their materials are reachable, so only the lock holds them |

## Dave decisions (short list)

1. **Rewards.** Ruled (06:19Z and 06:22Z): coins only, the A-42 scale above. The amounts are provisional; Dave can tune them.
2. **The water and garden module.** Ruled (06:26Z): the 24 locked blueprints stay as future goals, still locked.
3. **Two reward switches when the catalog goes live.** Ruled by "coins only": `twine` (was 4 Stick) and `fell` (was 3 Kindling) pay 5 copper each.
4. **The completion burst when the catalog goes live.** Ruled (06:18Z): characters, world edits and items are wiped before testing, so there is no burst and no catch-up payout.
5. **The HUD and blocked goals.** Ruled (06:26Z): the first HUD goal is the first one the player can do next, the second what should be next. The coordinator's reading: a blocked goal is not one the player can do, so it does not take a HUD slot.
6. **The provisional values the corrected text teaches.**
   - **Station costs and fuel:**
     - A-8: Primitive smithy, 2 Log instead of 2 Hide.
     - A-9: Improved smelter cost.
     - A-10: 1 fuel per ore.
     - A-15: Improved smithy without iron.
     - A-16: Iron anvil.
     - A-20: Advanced smithy.
     - A-21: Steel anvil.
   - **Steel smelting:** A-18 (wind of at least 4 m/s), A-19 (steel carbon 1:1, which the tracker lists high on your review) and A-24 (carbon is dragged onto the input slots).
   - **Copper tools:** A-13 and A-14, a Copper pickaxe and axe only.
   - **Sources and water:** A-1 (500 mL of water per Water) and A-2 (Tanbark once per felled oak).
   - **The coordinator's ruling R-1**, that these may go into data at all. It is item 1 of your review list.

## New proposed goals

A `runtime_check` that contains `count: "N"` is a placeholder. It is **not loadable** as goal data until the value is set. The R6 bin ids are in dev (#1111); the tier piece ids come with PR #1113.

| id | Title | Completes when | Stable refs | Pays |
|---|---|---|---|---:|
| `build:improved_smelter` | Build Improved Smelter | placed:improved_smelter | item improved_smelter #1304, structure state 368, bp 300 (dev, PR #1092; rechecked on dev 54b2c51) | 10 |
| `build:advanced_smithy` | Build Advanced Smithy | placed:advanced_smithy | item advanced_smithy #1308, state 369, bp 301 (dev, PR #1102; A-20) | 15 |
| `craft:copper_pickaxe` | Make a Copper - Pickaxe | made:copper_pickaxe | item copper_pickaxe #1305; recipe copper_pickaxe #722 at station forge (dev, PR #1099; A-13) | 10 |
| `craft:copper_axe` | Make a Copper - Axe | made:copper_axe | item copper_axe #1306; recipe copper_axe #723 at station forge (dev, PR #1099; A-13) | 10 |
| `craft:iron_anvil_part` | Make an Iron anvil | made:iron_anvil_part | item iron_anvil_part #1307, recipe 724 at the Improved smithy (dev, PR #1101; not #827) | 15 |
| `craft:steel_anvil_part` | Make a Steel anvil | made:steel_anvil_part | item steel_anvil_part #1309, recipe 725 at the Advanced smithy (brick_forge L3) (dev, PR #1102; A-21) | 20 |
| `build:medium_resource_bin` | Build Medium Resource Bin | placed:medium_resource_bin | item medium_resource_bin #1310, state 370, bp 302 (dev, R6 #1111) | 15 |
| `build:large_resource_bin` | Build Large Resource Bin | placed:large_resource_bin | item large_resource_bin #1311, state 371, bp 303 (dev, R6 #1111) | 15 |
| `activity:repair_station` | Repair a worn smithy | event `station_repaired` | no data yet (station durability is R5) | 5 |
| `activity:map_survey` | Map new ground | event `map_surveyed` | data/map.json, skills.json 'mapping' (dev, PR #1090) | 5 |
| `activity:map_redraw` | Redraw an old map area | event `map_redrawn` | data/map.json revisit rule improve_min_levels (dev, PR #1090; A-5) | 5 |
| `build:log_roof_65` | Build Rustic - Roof 65 | placed:log_roof_65 | item log_roof_65 #1320, state 380, bp 310 (dev, PR #1110) | 5 |
| `build:roof_section_65` | Build Refined - Roof 65 | placed:roof_section_65 | item roof_section_65 #1321, state 381, bp 311 (dev, PR #1110) | 15 |
| `build:stone_roof_65` | Build Sturdy - Roof 65 | placed:stone_roof_65 | item stone_roof_65 #1322, state 382, bp 312 (dev, PR #1110) | 15 |
| `build:brick_roof_65` | Build Superior - Roof 65 | placed:brick_roof_65 | item brick_roof_65 #1323, state 383, bp 313 (dev, PR #1110) | 15 |
| `build:engineered_roof_65` | Build Engineered - Roof 65 | placed:engineered_roof_65 | item engineered_roof_65 #1324, state 384, bp 314 (dev, PR #1110) | 15 |
| `build:fortified_window` | Build Fortified - Window | placed:fortified_window | item fortified_window #1330, state 400, bp 320 (PR #1113) | 20 |
| `build:fortified_floor` | Build Fortified - Ceiling | placed:fortified_floor | item fortified_floor #1331, state 401, bp 321 (PR #1113) | 20 |
| `build:fortified_stairs` | Build Fortified - Stairs | placed:fortified_stairs | item fortified_stairs #1332, state 402, bp 322 (PR #1113) | 20 |
| `build:fortified_fence` | Build Fortified - Fence | placed:fortified_fence | item fortified_fence #1333, state 403, bp 323 (PR #1113) | 20 |
| `build:fortified_roof` | Build Fortified - Roof 45 | placed:fortified_roof | item fortified_roof #1325, state 391, bp 315 (dev, #1112) | 20 |
| `build:fortified_roof_65` | Build Fortified - Roof 65 | placed:fortified_roof_65 | item fortified_roof_65 #1326, state 392, bp 316 (dev, #1112) | 20 |
| `build:fortified_roof_corner` | Build Fortified - Roof corner | placed:fortified_roof_corner or fortified_roof_corner_65 | item fortified_roof_corner #1327, state 393 and 394, bp 317 (dev, #1118) | 20 |
| `build:engineered_fence` | Build Engineered - Fence | placed:engineered_fence | item engineered_fence #1334, state 404, bp 324 (PR #1113) | 15 |
| `build:engineered_gate` | Build Engineered - Gate | placed:engineered_gate | item engineered_gate #1335, state 405, bp 325 (PR #1113) | 15 |

## Approved new goals (audit ADD, Dave 14 Nov 2026 06:26Z)

The 26 goals the audit recommended (`PLAYER_GOALS_REWARDS_AUDIT.md` section 7, ADD-01 to ADD-26). Approved as goals; the catalog is not switched on. Two complete with today's craft counter. ADD-16 is merged into `activity:temper_steel` (A-43). The other 23 each need a new server goal event, named in `runtime_check` and listed under "Server events the approved goals need" below; they are BLOCKED-BY-MECHANIC and stay out of the live goal files until their event ships. The counts in `activity:forage_new_plant` (5) and `activity:catch_different_fish` (3) are assumptions. Gathering, foraging and harvesting count only by the character's own hand (06:20Z).

| Audit | id | Title | Completes when | Pays |
|---|---|---|---|---:|
| ADD-01 | `craft:kindling` | Craft Kindling | made:kindling | 5 |
| ADD-02 | `craft:tinder` | Craft Tinder | made:tinder | 5 |
| ADD-03 | `activity:cook_on_campfire` | Cook meat or fish on a campfire | new event `cooked_on_fire` | 5 |
| ADD-04 | `activity:till_garden_bed` | Till soil into a garden bed with a hoe | new event `bed_tilled` | 5 |
| ADD-05 | `activity:sow_seed` | Sow a seed in a bed | new event `seed_sown` | 5 |
| ADD-06 | `activity:harvest_crop` | Harvest a ripe crop | new event `crop_harvested` | 5 |
| ADD-07 | `activity:plant_bush` | Dig up a bush and replant it | new event `bush_replanted` | 5 |
| ADD-08 | `activity:set_snare` | Set a snare | new event `snare_set` | 5 |
| ADD-09 | `activity:sharpen_tool` | Sharpen a tool on a whetstone or grindstone | new event `tool_sharpened` | 5 |
| ADD-10 | `activity:repair_tool` | Repair a worn or broken tool | new event `tool_repaired` | 5 |
| ADD-11 | `activity:repair_building` | Repair a damaged building piece with a hammer | new event `building_repaired` | 5 |
| ADD-12 | `activity:sleep_in_bed` | Sleep through a night in a bed or lean-to | new event `slept_night` | 5 |
| ADD-13 | `activity:store_in_chest` | Put items in a chest or crate | new event `stored_item` | 5 |
| ADD-14 | `activity:set_container_code` | Lock a chest with a four-digit code | new event `container_locked` | 5 |
| ADD-15 | `activity:haul_with_handcart` | Move a loaded crate with a Handcart | new event `handcart_hauled` | 15 |
| ADD-16 | `activity:craft_tempered_item` | Craft a Tempered steel item at a Smithy with a Quenching trough | MERGED into `activity:temper_steel` (A-43) | 0 |
| ADD-17 | `activity:craft_masterwork` | Craft a +1/+2 craftsmanship item at the Master smithy | new event `masterwork_made` | 20 |
| ADD-18 | `activity:burn_kiln_charcoal` | Burn a kiln batch of charcoal | new event `kiln_charcoal` | 5 |
| ADD-19 | `activity:buy_from_trader` | Buy something from Hob | new event `bought` | 5 |
| ADD-20 | `activity:preserve_in_jar` | Seal a batch in the Preserving jar and wait for it to mature | new event `jar_matured` | 5 |
| ADD-21 | `activity:serve_platter` | Place a Serving platter with food on a table | new event `platter_served` | 5 |
| ADD-22 | `activity:eat_prepared_meal` | Eat a prepared meal for a temporary food effect | new event `meal_effect` | 5 |
| ADD-23 | `activity:place_torch` | Wedge a torch into a wall or stand | new event `torch_placed` | 5 |
| ADD-24 | `activity:forage_new_plant` | Forage a new herb, nut or fruit | new event `foraged_new` x5 | 5 |
| ADD-25 | `activity:catch_different_fish` | Catch several kinds of fish | new event `fish_kind_caught` x3 | 5 |
| ADD-26 | `activity:mine_ore_with_pick` | Mine a boulder with a pickaxe | new event `ore_mined` | 5 |

**Overlaps, settled:**

- `activity:craft_tempered_item` (ADD-16) and `activity:temper_steel` were the same act on the same event, `tempered`. ADD-16 is merged into `activity:temper_steel`: the row stays for the record (`status` MERGED) and pays nothing (A-43, assumed on Dave's behalf; he approved the 26 as adjustable). `activity:temper_steel` still needs the `tempered` event, which dev does not emit yet.
- `activity:repair_building` (ADD-11) repairs a building piece; `activity:repair_station` repairs a smithy. They are different acts, so both stay.

### Server events the approved goals need (a package for the lead)

The 23 approved goals below wait for one new goal event each. Each should be sent through `server_items._goal_event(peer, "<event>")`, so Admin mode pauses it, once per act, crediting the character whose own hand does it (Dave 06:20Z). The names are the ones in each row's `runtime_check`; the lead may rename them, as long as the row changes with it. Kindling and Tinder need nothing new.

| Goal | Event | Fires when |
|---|---|---|
| `activity:cook_on_campfire` | `cooked_on_fire` | a roast (meat, fish, shellfish, seal) taken off a campfire |
| `activity:till_garden_bed` | `bed_tilled` | the hoe's till action on soil |
| `activity:sow_seed` | `seed_sown` | a seed sown into a tilled bed |
| `activity:harvest_crop` | `crop_harvested` | a ripe crop harvested by the character's own hand |
| `activity:plant_bush` | `bush_replanted` | a dug-up bush replanted |
| `activity:set_snare` | `snare_set` | a snare placed and set |
| `activity:sharpen_tool` | `tool_sharpened` | a tool sharpened on a whetstone or grindstone |
| `activity:repair_tool` | `tool_repaired` | a worn or broken tool repaired |
| `activity:repair_building` | `building_repaired` | a hammer repair of a damaged building piece (not a station; stations use `station_repaired`) |
| `activity:sleep_in_bed` | `slept_night` | a night slept through in a bed or lean-to |
| `activity:store_in_chest` | `stored_item` | an item put into a chest, crate or bin |
| `activity:set_container_code` | `container_locked` | a four-digit code set on a container the character owns |
| `activity:haul_with_handcart` | `handcart_hauled` | a loaded crate moved some distance on a Handcart |
| `activity:craft_masterwork` | `masterwork_made` | a +1 or +2 craftsmanship item made at the Master smithy |
| `activity:burn_kiln_charcoal` | `kiln_charcoal` | a kiln charcoal batch collected |
| `activity:buy_from_trader` | `bought` | an item bought from Hob |
| `activity:preserve_in_jar` | `jar_matured` | a matured batch taken out of a Preserving jar |
| `activity:serve_platter` | `platter_served` | a Serving platter with food placed on a table |
| `activity:eat_prepared_meal` | `meal_effect` | a prepared meal eaten that gives a temporary food effect |
| `activity:place_torch` | `torch_placed` | a torch put into a wall bracket or a stand |
| `activity:forage_new_plant` | `foraged_new` | a herb, nut or fruit foraged by hand that this character has not foraged before (count 5) |
| `activity:catch_different_fish` | `fish_kind_caught` | a kind of fish this character has not caught before (count 3) |
| `activity:mine_ore_with_pick` | `ore_mined` | an ore boulder mined with a pickaxe |

Also still owed by earlier rows: `tempered` (`activity:temper_steel`, which now covers ADD-16 too) and `station_repaired` (`activity:repair_station`). Neither is emitted in dev.

### Order of the rows (the HUD)

The live HUD shows the first goal not yet done, in authored order. `test_goals.gd` (#1118) guards the live goals: every goal a goal follows (`after`) comes before it. This CSV has no `after` column, so the same rule was applied by reading each new row's needs (its blueprint cost or recipe) against the rows that make them. So the CSV order is the authored order, and every new row sits right after the row for what it needs: for example `craft:kindling` after placing the first campfire, the Improved smelter before the first Iron ingot, each Roof 65 after its Roof 45, the tier pieces after their tier's last piece, sowing after the hoe, and setting a snare after crafting one. New side goals that need nothing beyond the start (map, tinder, cooking, sleeping and the rest) open the side goals, right after the main route. The kiln and jar goals close the stone-stage side goals, after the main route has built both. The Fortified Roof 45, Roof 65 and Roof corner follow the Fortified tier pieces. `PLAYER_GOALS_REWARDS_DRAFT.md` keeps the draft's order for the record.

**Order gaps found (not changed; the main route's order is the authored order):** three materials the main route needs have their goal only in the side goals, after the pieces that use them. `build:improved_smelter` (new) and `build:blacksmithy` (original) need Bronze nails and Bronze hinges (`craft:bronze_nails`, `craft:bronze_hinges`), and `craft:copper_axe` (new) needs a Leather strap (`craft:leather_strap`). When these goals go live with `after` links, either those three material goals move into the main route ahead of the smelter, or the links point only at goals earlier in the list.

### Coverage of the required stations

| Station | Goal |
|---|---|
| Primitive smelter (`smelter` #908, bp 200) | `build:smelter` (existing, FIX: the cost is 24 Clay and 10 Stone) |
| Improved smelter | `build:improved_smelter` (NEW) and `activity:operate_bellows` (existing) |
| Advanced smelter (`large_forge` #93, bp 201) | `build:large_forge` (existing, FIX; R4 in dev) |
| Primitive smithy (`stone_forge` #88, bp 9) | `build:stone_forge` (existing, FIX; R2 in dev, cost A-8) |
| Improved smithy (`blacksmithy` #90, bp 10) | `build:blacksmithy` (existing, FIX; R3 in dev, cost A-15) |
| Advanced smithy | `build:advanced_smithy` (NEW) |
| Master smithy (`master_forge` #95, bp 202) | `build:master_forge` (existing, R5) and `activity:temper_steel` (existing, R5) |
| Copper pickaxe and axe | `craft:copper_pickaxe` and `craft:copper_axe` (NEW, A-13) |
| Iron and Steel anvils | `craft:iron_anvil_part` and `craft:steel_anvil_part` (NEW) |
| Resource bins | `build:open_storage_bin` (Small, existing, R6), plus the NEW Medium and Large bins |
| Station repair | `activity:repair_station` (NEW) |
| Map and Mapping skill | `activity:map_survey` and `activity:map_redraw` (NEW) |

### Tier dependency (goal ids, display order only, never a lock)

```
fell -> activity:chop_log_blocks -> hammer -> workbench -> ...
gather:clay + gather:stone -> build:smelter (Primitive smelter)
  -> craft:copper_ingot, craft:tin_ingot -> craft:bronze_ingot        [R2]
  -> build:stone_forge (Primitive smithy, A-8) -> bronze tools, craft:bronze_nails, craft:bronze_hinges,
     craft:copper_pickaxe / craft:copper_axe (A-13)                    [R2/R2b]
bronze fittings -> build:improved_smelter (A-9) -> activity:operate_bellows -> craft:iron_ingot   [R3]
bronze ingot + fittings -> build:blacksmithy (Improved smithy, A-15) -> Iron Saw -> Planks, Hardwood boards,
     Nails, Hinges -> most furniture and building tiers; craft:iron_anvil_part (A-16)             [R3]
craft:iron_anvil_part -> build:advanced_smithy (A-20) -> craft:steel_anvil_part (A-21)            [R4]
build:large_forge (Advanced smelter, wind A-18) -> craft:steel_ingot (A-19)                         [R4]
craft:steel_anvil_part -> build:master_forge (Master smithy) -> activity:temper_steel; activity:repair_station [R5]
Planks + Nails -> build:open_storage_bin (Small) -> Medium -> Large resource bin                     [R6]
```

## How each goal completes, and the event gaps by owner

Every row has a `condition`, a `runtime_check` in the goal engine's own JSON, and an `event_emitter` naming the server call that feeds it.

**What dev's server already emits:**

- Events: `drink`, `ate_food`, `fire_lit`, `carcass_worked`, `fish_caught`, `tree_felled`, `path_laid`, `sold` and `wanted_order`.
- `placed:<kind>`, which comes from `_after_built` and from the campfire placement.
- `made:<item>`, which comes from the craft queue and, from #1092, from the smelter.
- The checks `talked`, `worn_warmth` and `moved_lit_night`. `moved_lit_night` counts any Torch in the pack, not only a lit one in hand.

**Missing events**, listed under the WP that owns each one:

- **WP-GUIDE-UI (goals section):**
  - **G1: a `got:<item>` first-hand counter.**
    - It is needed by the 20 gather rows, and is also the proposed check for `fibre`.
    - The hook is `_report_gains`. Only the gain tags pickup, harvest, craft and quest exist, so trade, chest and admin gains need new tags at their call sites before they can be left out.
  - **A `made_item_any` check type.** `_goal_met` accepts a single `made_item`, so "a block of any species" (`activity:chop_log_blocks`) needs a new check type. It works like `what_any` does for events.
  - **Live check changes when the catalog goes live (GA-41, GA-47):**
    - `fibre` uses the `got:` counter.
    - `fish` uses only the `fish_caught` event.
    - `hammer` uses `made:wooden_hammer` and drops `wooden_hammer_soft`, which is not an item.
    - `hoe` uses `made:wooden_hoe`.
    - `workbench` checks for the workbench only.
  - **The HUD order** (Dave 14 Nov 06:26Z): the first goal is the one the player can do next; the coordinator's reading is that a blocked goal therefore takes no HUD slot.
  - **Optional:** add the item to `ate_food`. Indexing goals by event (GA-49) is a performance shortcut, not a gap.
- **WP-PRIM (PR #1095, in dev since `b94b1e7`):**
  - **F1.** `_finish_site` lost the structure kind; #1095 fixed this and is in dev, so the build rows rely on code that is in dev.
  - **F3.** There is no `log_chopped` event. Instead, #1095 credits the hand chop as `_goal_made(peer, <species block>)`, which covers Hardwood, Softwood and Large blocks, and the hand split as `_goal_made(peer, <firewood>)`.
    - **Overlap:** a hand chop now also feeds `craft:wooden_block` and `craft:wooden_block_soft`. Under GA-38 each goal still pays once.
  - **F4.** `_goal_fire_tier` sends `fire_tier` with what `medium` or `large`, at most once per character for each tier, and only after player actions. A fire lit straight to large credits medium too.
  - **Cooking in the fire store** does not credit `roast_forage`; the Clay hearth recipe does. The owner of this fix is still to be confirmed.
- **WP-METAL:**
  - **Smelter credit** goes only to the station owner, and only while the owner is online. This affects 5 ingot rows (copper, tin, bronze, iron, steel). Decide whether the owner or the operator gets the credit.
  - **Kiln charcoal** is not credited (`craft:charcoal`; the campfire recipe 341 counts).
  - **The event `bellows_iron`** for `activity:operate_bellows` is emitted in dev (`server_smelter.gd`, the worker, once per stint).
  - **Steel smelting credit** is in dev (#1102): the steel job credits `made:steel_ingot` per ingot, with the same owner caveat.
  - **The event `tempered`** is needed for `activity:temper_steel` (R5).
  - **The event `station_repaired`**, sent from `_repair_struct`, is needed for `activity:repair_station` (R5).
  - **The bins** need no new event: `placed:medium_resource_bin` and `placed:large_resource_bin` (R6, in dev).
- **WP-MAP:** PR #1105 emits `map_surveyed` and `map_redrawn` from `server_map.gd`, through `_goal_event`, so Admin mode pauses them. Each survey counts once (a survey runs every 8 m walked), not each cell, so a survey costs one goal check (GA-49).

## Migration (A-12, and what going live really does)

Each character's counters (`goal_counts`) have been kept since protocol 119 for every event and every craft. `_goals_check` tests every goal against them on every slow tick. So when the corrected catalog goes live:

1. **Existing counters count from protocol 119.** A goal whose counter already exists completes at once and pays for actions taken since 119. This covers `made:<item>`, `placed:<kind>`, `tree_felled`, `fish_caught` and the other dev events. For example, a character who has built a Smelter completes `build:smelter` the moment the catalog goes live. Nothing counts from before 119, which is A-12.
2. **New events count from the day they ship.** That covers `got:<item>`, `fire_tier`, the hand-chop block credit (#1095) and the WP-METAL and WP-MAP events. A goal that uses one completes only for actions taken after the server first emits it.
3. **Possession checks pay on what is held, however it was obtained.** That covers `axe`, `hammer` and `hoe` (through `or_have`), `winter_store` and `fur_for_winter` (worn warmth).
4. **Existing completions stand.** Entries already in `goals_done` stay, and the 28 legacy ids are unchanged, so nothing pays twice. A changed check (for example `hammer` or `fish`) never takes back a completion.
5. **No top-ups.** A character already paid an item reward (Stick or Kindling) gets no coin top-up when the reward becomes coins.
6. **Renamed ids.** The two replaced ids, `activity:operate_bellows` (was `build:bellows`) and `activity:temper_steel` (was `build:quenching_trough`), were never live, so there is nothing to migrate.

**Ruled (Dave 14 Nov 06:18Z): no catch-up payouts.** Characters, world edits and items are wiped before the catalog is tested, so points 1 to 5 do not arise in that test.

## Verified, and not verified

**Verified (static reads):**

- At dev `9db936d`:
  - All 651 draft rows were parsed. The reward total is 15,670 copper.
  - Every row's recipe, blueprint and structure key and number was checked against `data/items/*.json`.
  - The goal engine was read: the `_goal_met` check types, `_goals_check` (pays only `coin_copper` and `item`), `_night_walk_tick` (any torch in the pack) and the trunk `seed_chance` source of Wild grain.
  - Credit per craft was confirmed at ~17607.
  - The 28 doorway names were checked across all seven tiers.
  - Every recipe the corrections name was checked: 1, 2, 3, 4, 46, 112, 139, 161, 162, 232, 268, 269, 270, 275, 277, 339, 340, 343, 720 and 721.
- In PR #1095's worktree: `_goal_fire_tier`, the hand chop in `_chop_loose_log` and the hand split credit.
- In the PR #1092 diff: the smelter's per-ingot credit.

**Not verified:**

- No Godot run, no tests and no play.
- PR #1095 was not in dev at the review baseline. The rows that rely on it (F1, F3, F4) were checked against its worktree code; it has since merged (`b94b1e7`).
- Dev moved to `596d156` (#1090, #1092, #1097, #1098) after the baseline, and the rows were not recomputed there.
- The player sources from PR #1091 (Tanbark, Pine tar, water from containers) are marked NEEDS PLAYER VERIFICATION in 109 rows.
- The acquisition evidence comes from the audit at `dc2fa52`. Its text was cut at 90 characters, and the cuts are shown as "...".
- At the review baseline the planned ids from R2b–R6 were not in dev. Since then #1305–#1307 (copper tools, Iron anvil, recipes 722–724) are in dev and were rechecked on `54b2c51` (R9, PR #1105); #1308, #1309, bp 301 and recipe 725 came with #1102 and were rechecked on `d4b2473`; the bin structures are not in dev yet.
- The Leaves drop from felling is not verified.
- Whether a newly placed Campfire kit starts with sticks in its fuel store is not verified.
