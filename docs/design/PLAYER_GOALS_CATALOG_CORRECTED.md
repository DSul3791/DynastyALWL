# Player goals catalog: corrected (proposal for Dave's review)

**Status: PROPOSAL. Not approved data.** This is the GOALS-REPAIR R7 (WP-GOALS) package for Dave's catalog review, made under the item catalog freeze (`docs/ai-team/DECISION_AUTHORITY.md`). Nothing in it changes game code, `starter_goals.json`, `camp_goals.json` or `PLAYER_GOALS_REWARDS_DRAFT.md`. Values tagged A-n are provisional engineering assumptions from `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` §4. They are not Dave-approved.

- **Rows:** `PLAYER_GOALS_CATALOG_CORRECTED.csv` has one row per goal: the draft's 651 goals (`status` ORIGINAL) and 11 new goals (`status` PROPOSED NEW).
- **Sources:**
  - Draft: `PLAYER_GOALS_REWARDS_DRAFT.md` (651 rows, 15,670 copper in total).
  - Audit: `PLAYER_GOALS_AUDIT_LEDGER.csv` (audit at `dc2fa52`).
  - Recovery: `PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md`, which holds the GA dispositions.
  - Data: dev `9db936d`. Only docs changed after `77460e3`, so the data read is the same as at `77460e3`.
- **Rewards:** unchanged. Every ORIGINAL row carries the draft figure, which totals 15,670 copper. The new goals say "for Dave".

## Rules applied

1. **Automatic goals.** Every goal is checked automatically. There is no activation step and no `after` award gate. `after` sets only the display order and the Journal links (GA-40, already done in dev by #1088).
2. **Once per character, coins only.** The three live item or reputation rewards switch to the draft coin figure when the catalog is activated (see the rows `twine`, `fell` and `story`).
3. **Stable ids.**
   - The 28 legacy ids are unchanged.
   - Every other goal uses `<kind>:<key>`.
   - Each row names its item, recipe and blueprint by key and number (column `stable_refs`).
   - The metal ingot rows point to the smelting jobs. They do not point to the old recipes 185 and 190–192, which retire in PR #1092.
4. **Counting.**
   - **Crafts are counted per craft.** The craft queue calls `_goal_made(peer, gives, times)` with `times` set to 1 for each finished craft, or to the number of crafts in a sealed batch (`server_items.gd` ~17607). Where a recipe gives more than one item, the condition says "crafts". Jerky is the only goal where this changes the count: 2 crafts make 4 Jerky.
   - **Smelting is counted per ingot.** PR #1092's `_credit` calls `_goal_made` once for each ingot delivered.
   - **Conflict, disclosed:** recovery GA-44 recommended counting units. Dave's brief for this package says per craft, and this package follows the brief.
5. **Nothing is hidden or deleted.** Blocked rows stay in the catalog. They are visible and marked with the work package (WP) that unblocks them. This includes the 24 locked water and garden blueprints (GA-31).
6. **Precedence.** Where a row has several problems, its verdict follows this order: DESIGN-QUESTION, then BLOCKED-BY-MECHANIC, then FIX, then OK. A blocked row still carries its text corrections in `correction`, so it is ready on the day the blocker lands.

## Counts by verdict

| Verdict | All 651 | 328 rule-only rows (reviewed individually in this pass) | 323 rows already reviewed individually in the audit |
|---|---:|---:|---:|
| OK | 178 | 54 | 124 |
| FIX | 162 | 56 | 106 |
| BLOCKED-BY-MECHANIC | 311 | 218 | 93 |
| DESIGN-QUESTION | 0 | 0 | 0 |
| **Total** | **651** | **328** | **323** |

- **Blocked rows that also have text corrections:** 147, of which 97 are rule-only rows.
- **New goals (verdict PROPOSED):** 11.
- **Rows with a play test or player-verification note:**
  - 109 need player verification of the PR #1091 sources (Tanbark, Pine tar, water from containers).
  - 58 are F6 door, doorway and bed checks.
  - 15 need a wool reach test (GA-39).
  - 2 others.
- **No row became a DESIGN-QUESTION.**
  - Every open point is already covered by a settled rule, a recovery disposition or an A-n assumption.
  - The genuine scope questions are in the Dave decision list below.

**Main blocker of each blocked row** (`blocking_wp`, first entry):

| WP | Rows | What it unblocks |
|---|---:|---|
| WP-METAL R2 (PR #1092) | 22 | Bronze route: the Primitive smithy cost (A-8), the copper, tin and bronze smelting jobs, Bronze tools, nails and hinges |
| WP-METAL R3 | 197 | Iron route. The Improved smelter and its bellows are in #1092, the Improved smithy without iron is A-15, and the Iron Saw is needed for Planks and Hardwood boards. Anything that uses Planks, Nails or Hinges waits for it |
| WP-METAL R4 | 41 | Steel (A-19, A-24), the Advanced smelter (wind, A-18) and the Advanced smithy |
| WP-METAL R5 | 2 | Master smithy and tempering |
| WP-METAL R6 | 1 | Small Resource Bin (16 Planks and 32 Nails, single type) |
| WP-R1B (PR #1089) | 17 | Crop-only inputs: wheat, barley, oats, rye, flax (and linen) |
| WP-PRIM | 3 | No event yet for chopping a log into blocks (F3) or for fire size (F4) |
| WP-GUIDE-UI (goals section) | 19 | Gather goals need a first-hand `got:<item>` counter |
| UNASSIGNED | 9 | Locked water and garden blueprints. No WP owns these; 15 more locked rows are also behind a metal phase |

## Dave decisions (short list)

1. **Rewards for the 11 new goals.**
   - The `reward` column says "for Dave"; nothing is proposed.
   - `activity:repair_station` overlaps audit ADD-11, which is not approved.
2. **The water and garden module.**
   - 24 blueprints are locked in data: cisterns, pipes, pumps, channels, troughs, sluice, well, cold frame, compost bin, and the FUTURE Wool rug.
   - No work package owns them, so they stay visible but blocked.
   - Decide whether to assign an owner, or leave them blocked.
3. **Activation of the live goals.** Confirm:
   - **A-12, no backfill.** No goal pays for actions taken before protocol 119.
   - **The three reward switches**, which use draft figures and pay coins only:
     - `twine`: 4 Stick becomes 4 copper.
     - `fell`: 3 Kindling becomes 6 copper.
     - `story`: drops the +1 reputation.
4. **The provisional values the corrected text teaches.**
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

| id | Title | Completes when | Stable refs | Blocked by |
|---|---|---|---|---|
| `build:improved_smelter` | Build Improved Smelter | placed:improved_smelter | item #1304, state 368, bp 300 (A-9) | WP-METAL R3 (#1092) |
| `build:advanced_smithy` | Build Advanced Smithy | placed:advanced_smithy | item #1308, state 369, bp 301 (A-20) | WP-METAL R4 |
| `craft:copper_pickaxe` | Make a Copper - Pickaxe | made:copper_pickaxe | new from #1305, key to be set (A-13) | WP-METAL R2b |
| `craft:copper_axe` | Make a Copper - Axe | made:copper_axe | new from #1305, key to be set (A-13) | WP-METAL R2b |
| `craft:iron_anvil_part` | Make an Iron anvil | made:iron_anvil_part | item #1307 (A-16), not #827 | WP-METAL R3 |
| `craft:steel_anvil_part` | Make a Steel anvil | made:steel_anvil_part | item #1309, recipe 725 (A-21) | WP-METAL R4 |
| `build:medium_resource_bin` | Build Medium Resource Bin | placed:<R6 structure> | to be set in R6 | WP-METAL R6 |
| `build:large_resource_bin` | Build Large Resource Bin | placed:<R6 structure> | to be set in R6 | WP-METAL R6 |
| `activity:repair_station` | Repair a worn smithy | new event `station_repaired` | none until R5 durability | WP-METAL R5 |
| `activity:map_survey` | Map new ground | new event `map_surveyed` (count for Dave) | data/map.json, skill `mapping` (A-5) | WP-MAP (#1090) |
| `activity:map_redraw` | Redraw an old map area | new event `map_redrawn` | data/map.json revisit rule (A-5) | WP-MAP (#1090) |

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

**The events and counters the server already emits are:**

- `drink`, `ate_food`, `fire_lit`, `carcass_worked`, `fish_caught`, `tree_felled`, `path_laid`, `sold` and `wanted_order`.
- `placed:<kind>`, which comes from `_after_built` and from the campfire placement.
- `made:<item>`, which comes from the craft queue and, in #1092, from the smelter.
- The checks `talked`, `worn_warmth` and `moved_lit_night`.

**Missing events**, listed under the WP that owns each one:

- **WP-GUIDE-UI (goals section):**
  - **G1: a `got:<item>` first-hand counter.** It counts pickup, harvest, dig, mine, carcass and fishing gains. It does not count trade, chest or admin gains. The hook is `_report_gains`, with its source tags. It unblocks 20 gather rows, and it is also the proposed check for `fibre`.
  - **Live check changes at activation (GA-41, GA-47):**
    - `fibre` uses the `got:` counter.
    - `fish` uses only the `fish_caught` event.
    - `hammer` uses `made:wooden_hammer`. It also drops the item `wooden_hammer_soft`, which does not exist.
    - `hoe` uses `made:wooden_hoe`.
    - `workbench` checks for the workbench only.
  - **Optional:** adding the item to `ate_food` would let the `berries` goal enforce "wild". Indexing goals by event (GA-49) is a performance shortcut, not a gap.
- **WP-PRIM:**
  - **F1.** `_finish_site` passes a structure row without `kind`, so a building finished as a site records `placed` with no kind. This affects 256 build rows. It does not block them, because building straight from the pack works.
  - **F3, the event `log_chopped`.** It blocks `activity:chop_log_blocks`. Credit for the hand split affects `craft:firewood` and `craft:firewood_soft`, whose queued recipes 721 and 720 already count.
  - **F4, the event `fire_tier`.** It blocks `activity:medium_fire` and `activity:bonfire`.
  - **Cooking from the fire store** does not credit `roast_forage`. The recipe path still counts. The owner of this fix is still to be confirmed.
- **WP-METAL:**
  - **Smelter credit** goes only to the station owner, and only while the owner is online. This affects 4 ingot rows. Decide whether the owner or the operator gets the credit.
  - **Kiln charcoal** is not credited (`craft:charcoal`; the campfire recipe 341 counts).
  - **The event `bellows_iron`** is needed for `activity:operate_bellows` (R3).
  - **Steel smelting credit** is needed (R4).
  - **The event `tempered`** is needed for `activity:temper_steel` (R5).
  - **The event `station_repaired`**, sent from `_repair_struct`, is needed for `activity:repair_station` (R5).
  - **The bins** need no new event, because `placed:<kind>` covers them once the R6 structures exist.
- **WP-MAP:** needs the events `map_surveyed` and `map_redrawn`, or an equivalent cells-seen check, from `server_map.gd` (PR #1090).

## Migration (A-12)

- **No backfill.** Counting started at protocol 119 (#1088). No goal pays for anything done before that.
- **Existing completions stand.** Entries already in a character's `goals_done` stay. The 28 legacy ids are unchanged, so nothing pays twice.
- **Changed checks do not reopen goals.** A changed check (for example `hammer` or `fish`) never takes back a completion.
- **No top-ups.** A character who was already paid an item reward (Stick, Kindling, reputation) gets no coin top-up when the reward becomes coins.
- **Renamed ids.** The two replaced ids, `activity:operate_bellows` (was `build:bellows`) and `activity:temper_steel` (was `build:quenching_trough`), were never live, so there is nothing to migrate.
- **New goals count from activation.** They count only actions taken after they go live. A character who built a station before then does not get the goal for it.

## Verified, and not verified

**Verified (static reads at dev `9db936d`):**

- All 651 draft rows were parsed. The reward total is 15,670 copper.
- Every row's recipe, blueprint and structure key and number was checked against `data/items/*.json`.
- The goal engine check types and events were read in `server_items.gd` ~15694–15975.
- Credit per craft was confirmed at ~17607.
- The 28 doorway names were checked across all seven tiers.
- Every legacy recipe the corrections name was checked: 1, 2, 3, 4, 46, 112, 139, 161, 162, 232, 268, 269, 270, 275, 277, 720 and 721.
- The smelter's per-ingot credit was read in the PR #1092 diff.

**Not verified:**

- No Godot run, no tests and no play.
- The player sources from PR #1091 (Tanbark, Pine tar, water from containers) are marked NEEDS PLAYER VERIFICATION in 109 rows.
- The acquisition evidence comes from the audit at `dc2fa52`. Its text was cut at 90 characters, and the cuts are shown as "...".
- The ids from PRs #1092 and #1090 and from the planned R2b–R6 work (#1304–#1309, bp 300–301, recipe 725, copper tool keys, bin structures) are not in dev.
- The Leaves drop from felling is not verified.
- Whether a newly placed Campfire kit starts with sticks in its fuel store is not verified.
