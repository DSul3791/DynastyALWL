# Player goals catalog: corrected (proposal for Dave's review)

**Status: PROPOSAL. Not approved data.** This is the GOALS-REPAIR R7 (WP-GOALS) package for Dave's catalog review, made under the item catalog freeze (`docs/ai-team/DECISION_AUTHORITY.md`). Nothing in it changes game code, `starter_goals.json`, `camp_goals.json` or `PLAYER_GOALS_REWARDS_DRAFT.md`. Values tagged A-n are provisional engineering assumptions from `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` §4. They are not Dave-approved.

- **Rows:** `PLAYER_GOALS_CATALOG_CORRECTED.csv` has one row per goal: the draft's 651 goals (`status` ORIGINAL) and 11 new goals (`status` PROPOSED NEW).
- **Sources:**
  - Draft: `PLAYER_GOALS_REWARDS_DRAFT.md` (651 rows, 15,670 copper in total).
  - Audit: `PLAYER_GOALS_AUDIT_LEDGER.csv` (audit at `dc2fa52`).
  - Recovery: `PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md`, which holds the GA dispositions.
  - Data baseline: dev `9db936d` (data identical to `77460e3`). The hand-chop, fire-tier and site-kind fixes were read in PR #1095's worktree; that PR is not in dev.
- **Dev moved after the baseline.** Dev has since taken #1090 (Map), #1092 (R2a smelters), #1097 and #1098, and later #1089, #1095, #1099, #1100 and #1101.
- **Rechecked on dev `54b2c51` (R9, PR #1105; static read of data and code):**
  - **Verdicts changed:** the 22 WP-METAL R2 rows and `craft:iron_ingot` are no longer blocked: 17 are OK and 6 are FIX (they carry text corrections).
  - **Refs verified:** `build:improved_smelter` and the two Copper tool rows have their ids checked.
  - **Map goals:** the two map goals have their events from PR #1105.
  - **Not rechecked yet:** the rows blocked by WP-METAL R3, WP-R1B, WP-PRIM and WP-GUIDE-UI were not rechecked here, although those PRs are now in dev.
  - The counts below include these changes.
- **Rewards:** unchanged. Every ORIGINAL row carries the draft figure, which totals 15,670 copper. In the PROPOSED rows `reward_copper` is empty, and `notes` says "Reward: for Dave".
- **Wording:** "go live" means the day the corrected catalog replaces the live goal files. It is not a player action; the player never activates anything.

## Rules applied

1. **Automatic goals.** Every goal is checked automatically. There is no player activation and no `after` award gate. `after` sets only the display order and the Journal links (GA-40, already done in dev by #1088).
2. **Once per character, coins only.** Two live item rewards switch to the draft coin figure when the catalog goes live: `twine` and `fell`.
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
| OK | 195 | 59 | 136 |
| FIX | 169 | 57 | 112 |
| BLOCKED-BY-MECHANIC | 287 | 212 | 75 |
| DESIGN-QUESTION | 0 | 0 | 0 |
| **Total** | **651** | **328** | **323** |

- **Blocked rows that also have text corrections:** 140, of which 96 are rule-only rows.
- **New goals (verdict PROPOSED):** 11.
- **Rows with a play test or player-verification note:**
  - 109 need player verification of the PR #1091 sources (Tanbark, Pine tar, water from containers).
  - 58 are F6 door, doorway and bed checks.
  - 15 need a wool reach test (GA-39).
  - 2 others.
- **No row became a DESIGN-QUESTION.**
  - Every open point is already covered by a settled rule, a recovery disposition or an A-n assumption.
  - The genuine scope questions are in the Dave decision list below.
- **Build rows marked OK or FIX assume PR #1095.** In dev, a building finished as a site records `placed` with no kind (F1), and #1095 fixes this. Until #1095 lands, a building finished as a site does not complete its goal; a building placed straight from the pack does.

**Main blocker of each blocked row** (`blocking_wp`, first entry):

| WP | Rows | What it unblocks |
|---|---:|---|
| WP-METAL R2 (PR #1092) | 0 | Was 22. The Bronze route is in dev, and the rows were rechecked on `54b2c51` |
| WP-METAL R3 | 196 | Iron route. The Improved smelter and its bellows are in #1092, the Improved smithy without iron is A-15, and the Iron Saw is needed for Planks and Hardwood boards. Anything that uses Planks, Nails or Hinges waits for it |
| WP-METAL R4 | 41 | Steel (A-19, A-24), the Advanced smelter (wind, A-18) and the Advanced smithy |
| WP-METAL R5 | 2 | Master smithy and tempering |
| WP-METAL R6 | 1 | Small Resource Bin (16 Planks and 32 Nails, single type) |
| WP-R1B (PR #1089) | 16 | Crop-only inputs: barley, oats, rye, flax (and linen). Flour is not blocked; see `craft:flour` |
| WP-PRIM (PR #1095) | 3 | `activity:chop_log_blocks` (hand-chop credit; it also needs a WP-GUIDE-UI check type), `activity:medium_fire` and `activity:bonfire` (the `fire_tier` event) |
| WP-GUIDE-UI (goals section) | 19 | Gather goals need a first-hand `got:<item>` counter. 20 gather rows have this gap; `gather:flax` is counted under WP-R1B |
| UNASSIGNED | 9 | Locked water and garden blueprints. No WP owns these; 15 more locked rows are also behind a metal phase |

## Dave decisions (short list)

1. **Rewards for the 11 new goals.**
   - Nothing is proposed; each PROPOSED row's `notes` says "Reward: for Dave".
   - `activity:repair_station` overlaps audit ADD-11, which is not approved.
2. **The water and garden module.**
   - 24 blueprints are locked in data: cisterns, pipes, pumps, channels, troughs, sluice, well, cold frame, compost bin, and the FUTURE Wool rug.
   - No work package owns them, so they stay visible but blocked.
   - Decide whether to assign an owner, or leave them blocked.
3. **Two reward switches when the catalog goes live.** Both use the draft figures and pay coins only:
   - `twine`: 4 Stick becomes 4 copper.
   - `fell`: 3 Kindling becomes 6 copper.
4. **The completion burst when the catalog goes live.** Goals complete at once, and pay, for what a character has already done. The details are under Migration. Choose one:
   - **Accept the burst.** Players are paid for actions since protocol 119.
   - **Reset the goal counters when the catalog goes live.** Nothing counts from before that day.
   - **Use recovery Q4's default.** Mark goals already met as done without paying, and without a flood of placards.

   A-12 only rules out a backfill from before protocol 119, so it does not settle this.
5. **The HUD and blocked goals.**
   - The two-item HUD always shows the earliest unfinished goals. A visible but blocked row would sit there for good.
   - **Recommendation:** the HUD skips any goal whose mechanic is not live (any row with a `blocking_wp`). The goal stays visible in the Journal.
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

## New proposed goals (rewards for Dave)

Ids from R4 to R6 are **not yet in dev**: they come from the blocking WP. The Improved smelter and Copper tool ids were rechecked on dev `54b2c51` (R9, PR #1105). A `runtime_check` that contains a `<...TBD>` value or `count: "N"` is a placeholder. It is **not loadable** as goal data until the value is set.

| id | Title | Completes when | Stable refs | Blocked by |
|---|---|---|---|---|
| `build:improved_smelter` | Build Improved Smelter | placed:improved_smelter | item #1304, state 368, bp 300 (A-9), rechecked on dev | in dev (#1092) |
| `build:advanced_smithy` | Build Advanced Smithy | placed:advanced_smithy | item #1308, state 369, bp 301 (A-20) | WP-METAL R4 |
| `craft:copper_pickaxe` | Make a Copper - Pickaxe | made:copper_pickaxe | item #1305, recipe 722 (A-13) | in dev (#1099) |
| `craft:copper_axe` | Make a Copper - Axe | made:copper_axe | item #1306, recipe 723 (A-13) | in dev (#1099) |
| `craft:iron_anvil_part` | Make an Iron anvil | made:iron_anvil_part | item #1307 (A-16), not #827 | WP-METAL R3 |
| `craft:steel_anvil_part` | Make a Steel anvil | made:steel_anvil_part | item #1309, recipe 725 (A-21) | WP-METAL R4 |
| `build:medium_resource_bin` | Build Medium Resource Bin | placed:<R6 structure> (placeholder) | to be set in R6 | WP-METAL R6 |
| `build:large_resource_bin` | Build Large Resource Bin | placed:<R6 structure> (placeholder) | to be set in R6 | WP-METAL R6 |
| `activity:repair_station` | Repair a worn smithy | new event `station_repaired` | none until R5 durability | WP-METAL R5 |
| `activity:map_survey` | Map new ground | event `map_surveyed`, one per survey (every 8 m walked) that finds never-seen ground (count N for Dave: placeholder) | data/map.json, skill `mapping` (A-5) | WP-MAP (#1105) |
| `activity:map_redraw` | Redraw an old map area | event `map_redrawn`, one per survey that redraws known ground at a higher skill | data/map.json revisit rule (A-5) | WP-MAP (#1105) |

The proposed How-to text for each goal is in the CSV `correction` column.

### Coverage of the required stations

| Station | Goal |
|---|---|
| Primitive smelter (`smelter` #908, bp 200) | `build:smelter` (existing, FIX: the cost is 24 Clay and 10 Stone) |
| Improved smelter | `build:improved_smelter` (NEW) and `activity:operate_bellows` (existing) |
| Advanced smelter (`large_forge` #93, bp 201) | `build:large_forge` (existing, blocked by R4) |
| Primitive smithy (`stone_forge` #88, bp 9) | `build:stone_forge` (existing, blocked by R2, cost A-8) |
| Improved smithy (`blacksmithy` #90, bp 10) | `build:blacksmithy` (existing, blocked by R3, cost A-15) |
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
  - **The HUD skip** (Dave decision 5).
  - **Optional:** add the item to `ate_food`. Indexing goals by event (GA-49) is a performance shortcut, not a gap.
- **WP-PRIM (PR #1095, not in dev):**
  - **F1.** In dev, `_finish_site` loses the structure kind; #1095 fixes this. The 256 build rows assume the fix.
  - **F3.** There is no `log_chopped` event. Instead, #1095 credits the hand chop as `_goal_made(peer, <species block>)`, which covers Hardwood, Softwood and Large blocks, and the hand split as `_goal_made(peer, <firewood>)`.
    - **Overlap:** a hand chop now also feeds `craft:wooden_block` and `craft:wooden_block_soft`. Under GA-38 each goal still pays once.
  - **F4.** `_goal_fire_tier` sends `fire_tier` with what `medium` or `large`, at most once per character for each tier, and only after player actions. A fire lit straight to large credits medium too.
  - **Cooking in the fire store** does not credit `roast_forage`; the Clay hearth recipe does. The owner of this fix is still to be confirmed.
- **WP-METAL:**
  - **Smelter credit** goes only to the station owner, and only while the owner is online. This affects 4 ingot rows. Decide whether the owner or the operator gets the credit.
  - **Kiln charcoal** is not credited (`craft:charcoal`; the campfire recipe 341 counts).
  - **The event `bellows_iron`** is needed for `activity:operate_bellows` (R3).
  - **Steel smelting credit** is needed (R4).
  - **The event `tempered`** is needed for `activity:temper_steel` (R5).
  - **The event `station_repaired`**, sent from `_repair_struct`, is needed for `activity:repair_station` (R5).
  - **The bins** need no new event, because `placed:<kind>` covers them once the R6 structures exist.
- **WP-MAP:** PR #1105 emits `map_surveyed` and `map_redrawn` from `server_map.gd`, through `_goal_event`, so Admin mode pauses them. Each survey counts once (a survey runs every 8 m walked), not each cell, so a survey costs one goal check (GA-49).

## Migration (A-12, and what going live really does)

Each character's counters (`goal_counts`) have been kept since protocol 119 for every event and every craft. `_goals_check` tests every goal against them on every slow tick. So when the corrected catalog goes live:

1. **Existing counters count from protocol 119.** A goal whose counter already exists completes at once and pays for actions taken since 119. This covers `made:<item>`, `placed:<kind>`, `tree_felled`, `fish_caught` and the other dev events. For example, a character who has built a Smelter completes `build:smelter` the moment the catalog goes live. Nothing counts from before 119, which is A-12.
2. **New events count from the day they ship.** That covers `got:<item>`, `fire_tier`, the hand-chop block credit (#1095) and the WP-METAL and WP-MAP events. A goal that uses one completes only for actions taken after the server first emits it.
3. **Possession checks pay on what is held, however it was obtained.** That covers `axe`, `hammer` and `hoe` (through `or_have`), `winter_store` and `fur_for_winter` (worn warmth).
4. **Existing completions stand.** Entries already in `goals_done` stay, and the 28 legacy ids are unchanged, so nothing pays twice. A changed check (for example `hammer` or `fish`) never takes back a completion.
5. **No top-ups.** A character already paid an item reward (Stick or Kindling) gets no coin top-up when the reward becomes coins.
6. **Renamed ids.** The two replaced ids, `activity:operate_bellows` (was `build:bellows`) and `activity:temper_steel` (was `build:quenching_trough`), were never live, so there is nothing to migrate.

Whether the burst in point 1 is acceptable is Dave decision 4: accept it, reset the counters when the catalog goes live, or use recovery Q4's default (mark goals already met as done without paying).

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
- PR #1095 is not in dev. The rows that rely on it (F1, F3, F4) were checked against its worktree code only.
- Dev moved to `596d156` (#1090, #1092, #1097, #1098) after the baseline, and the rows were not recomputed there.
- The player sources from PR #1091 (Tanbark, Pine tar, water from containers) are marked NEEDS PLAYER VERIFICATION in 109 rows.
- The acquisition evidence comes from the audit at `dc2fa52`. Its text was cut at 90 characters, and the cuts are shown as "...".
- The planned ids from R2b–R6 (#1305–#1309, bp 301, recipe 725, copper tool keys, bin structures) are not in dev.
- The Leaves drop from felling is not verified.
- Whether a newly placed Campfire kit starts with sticks in its fuel store is not verified.
