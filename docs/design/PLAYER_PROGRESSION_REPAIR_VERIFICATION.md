# Player progression repair: verification report (GOALS-REPAIR R9)

**Status: DRAFT, updated as work lands.** Written 14 Nov 2026 against `dev` `54b2c51c` (last merge #1101). R4 (#1102), R5, R6 and the building work are not in `dev` yet. Their rows say so and will be filled in when they merge.

This is the R9 report that Dave's 14 Nov brief and [CATALOG_IMPLEMENTATION_PLAN.md](CATALOG_IMPLEMENTATION_PLAN.md) §2 R9 and §5 call for. The tracker is `docs/ai-team/missions/GOALS-REPAIR/STATE.md`, with its decisions in `REPAIR_DECISIONS.md`. The original audit (`PLAYER_GOALS_REWARDS_AUDIT.md`, `PLAYER_GOALS_AUDIT_LEDGER.csv`) is kept unchanged. Section 5 lists what this mission changed against it. The play checklist is [PLAYER_PROGRESSION_REPAIR_F6.md](PLAYER_PROGRESSION_REPAIR_F6.md).

## 1. How to read this report

**Status** (one per item):

| Status | Meaning |
|---|---|
| VERIFIED BY TEST | The rule is server-side, a headless Godot test plays it through the player's own actions, and the run passed on the exact SHA. Nothing about it needs eyes or feel. |
| NEEDS PLAYER VERIFICATION | Merged and tested headless, but part of it (looks, sound, motion, feel, on-screen text, the route as a person plays it) has only been checked by tests or by reading. Dave's F6 check decides it. |
| BLOCKED | Not in `dev` yet, or waiting on other work. The reason is given. |
| DEFERRED (needs Dave) | Waiting on a decision reserved to Dave. Section 6 lists it. |

**Evidence levels** (plan §5): STATIC_READ, AUTOMATED_TEST, HEADLESS_GODOT, PLAYED_F6, MULTIPLAYER_RESTART. Nothing here is passed on compile or on a static read. **No item has reached PLAYED_F6.** Dave said on 14 Nov, 00:43Z, that he would not play until the mission is settled. No picture lane ran anywhere, so nothing in this report has been seen in a running game. Where a test calls the server directly or gives materials with admin powers, it proves only that one mechanic, not the player's route (COMMON brief rule 5). The rows say which tests walk the route.

**Lane.** Every run was on lane B, David4: Linux, headless Godot 4.7.2 voxel build. The logs are on David4 under `/work/lanerun/` and are not in the repo. Names are as the lane reported them to the coordinator.

**Caveats that apply to every row:**

- **Tested at the branch head, merged later.** Each PR was tested at its own branch head and then merged after `dev` had moved on. The merge relied on a reviewer's clean-replay check, not a rerun, unless a later full run covers it.
- **The broad run on `dev` covers #1085 to #1100.** That run was on `0bc19301`: 384/384 (372 fast, 8 timing, 4 slow), no flakes, 1198 s. validate_items gave 0 errors and 114 warnings, the same as before. check_look_names passed, and the startup smoke showed 0 SCRIPT ERRORs. Logs: `broad_dev0bc1*`.
- **#1101 and later are not covered by a run on `dev` itself.**
- **#1095's merged head was not lane-run as a branch.** It merged at `becd736`, one reviewed commit after the lane run at `2145537` (an unused local removed). `becd736` is an ancestor of `0bc19301` (checked with `git merge-base --is-ancestor`), so the broad run on `dev` does cover it. The coordinator's relay said otherwise; the git history shows the broad run includes it.

## 2. Work merged to `dev` in this mission

| PR | What | Lane run (head, count, logs) | dev merge |
|---|---|---|---|
| #1085, #1086 | R0 documentation cleanup and follow-up fixes | docs only; gate review PASS WITH MINOR NOTES | `d990abd`, `303980d` |
| #1087 | Admin and debug keys always need Ctrl+Shift | `c024edd`, 73/73; `pr1087_plan`, `pr1087_extra` | `a17bb4b` |
| #1088 | Goal list and goal_done to the client, any-order completion (protocol 119) | `0cca037`, 371/371; `pr1088_first`, `pr1088_rest` | `e7d4919` |
| #1089 | Farming from the client: sow, water, harvest | `77ea7f3`, 189/189; `pr1089c_g1`, `_g2`, `_rest`, `_extra`. First run failed at `f105fcb` (`pr1089_g1`..`g5`) | `8c2a28a` |
| #1090 | Discovered charcoal Map (protocol 120) | `f8f2787`, 375/375 (367 fast + 8 timing); map cost in `test_map` | `2c33569` |
| #1091 | Oak tannin bark, Scots pine tar, recipe water from containers | `c619968`, 219/219; `pr1091b_first`, `_rest`, `_extra`. First run failed at `a50d304`: one real bug (refund rows lost liquid keys on load), fixed | `77460e3` |
| #1092 | R2a: Primitive and Improved smelters work by themselves | `cf8166b`, 238/238; `pr1092d_a`, `_b`, `_rest`, `_extra`. Three earlier runs failed, all fixed | `596d156` |
| #1093 | Journal (J/G/M), Goals box, Goal Achieved placard and fanfare | `3d0881fa`, 73/73 + test_goal_ui; `pr1093c_goalui`, `_plan`, `_extra` | `55b1254` |
| #1095 | Primitive route: 3 m logs, site goal kind, hand-chop credit, fire tiers, route test | `2145537`, 223/223; `pr1095b_g1`, `_rest`, `_extra`. The merged head `becd736` is covered by the broad run on `0bc19301` | `b94b1e7` |
| #1096 | Corrected 651-goal catalog for Dave's review (R7 content) | docs only, static review | `69e941e` |
| #1097 | Map sketch drawn on a worker thread | `cf83be1`, 36/36, test_goal_ui and test_map run 3 times each; `pr1097_twice1`..`3`, `pr1097_rest` | `272278f` |
| #1099 | R2b: Copper pickaxe and Copper axe | `bd86f165`, 255/255; `pr1099_first`, `_rest`, `_extra` | `eedef36` |
| #1100 | Goals: first-hand got_item counter, feller credit, corrected live checks | `67c0fd0`, 204/204; `pr1100_first`, `_rest`, `_extra` | `0bc1930` |
| #1101 | R3: Improved smithy without iron, Iron anvil, smithy wear | `5df0e8fc`, 252/252; `pr1101_first`, `_rest`, `_extra`, `val_deveede.txt` vs `val_1101.txt` | `54b2c51` |
| #1094, #1098 | Tracker documents | docs only | in `dev` |

**Open, not in `dev`:**

- #1102: R4, protocol 121. Lane run requested.
- #1103: a test warning fix.
- R5 and R6: reviewed locally, pushed one at a time.
- Building work: not started.

Work that was already in `dev` before this mission and is relied on below:

- **Doors** (BUGLIST-002): #1077 at `36a3250` and #1078 at `62c24e5`. The last lane run was `94596ec`: 214 pass, 0 fail (logs `bl002c_plan`, `bl002c_extra`). Report and checklist: `/mnt/project-files/buglist-002/`.
- **Roofs and building placement** (BUGLIST-001): #1068 to #1076. Lane run `8e46c4b`: 370/370. Report and checklist: `/mnt/project-files/buglist-001/`.
- **Catalog baseline** (Mission 001): `27d27fbbb`.

## 3. Item by item (Dave's brief, R0 to R9)

| # | Item (brief §3/§5) | Phase | PR → dev | Test evidence | Status | What is still open |
|---|---|---|---|---|---|---|
| 1 | **Oak tannin bark** | R1 | #1091 → `77460e3` | HEADLESS_GODOT `test_wood_sources` at `c619968`. A felled oak gives its 3 bark once, at the first axe blow on its logs or in the heap if it auto-splits. A saved `bark_taken` flag stops a second drop. A standing tree gives none. | NEEDS PLAYER VERIFICATION | The bark must be seen dropping in play, then followed through tanning to leather. Amount: A-2. |
| 2 | **Scots pine tar** | R1 | #1091 → `77460e3` | HEADLESS_GODOT `test_wood_sources`. Every species row rolls per log, so pine tar now drops. The resin roll is unchanged, and a test compares it. | NEEDS PLAYER VERIFICATION | The chain pine tar → tar → water wheel has not been played. The water wheel (64.8 kg of inputs) is above the 52.5 kg new-character carry cap. That gap existed before this mission (REPAIR_DECISIONS §5). |
| 3 | **Recipe water from filled containers** | R1 | #1091 → `77460e3` | HEADLESS_GODOT `test_liquid_ingredient`, plus the textile route, the walkthrough and the inventory tests. Water is taken only when a craft succeeds; salt water never counts; cancel and refund pour it back. | VERIFIED BY TEST | 500 mL per unit is A-1. Known limits: containers on the ground or inside bags don't count, and pooling is per inventory. |
| 4 | **Farming** (sow, water, harvest) | R1 | #1089 → `8c2a28a`; server side #1091 | HEADLESS_GODOT `test_farming` (flax from wild seed through the real route, seasons, refusals, save and restart) and `test_farm_prompt` at `77ea7f3` | NEEDS PLAYER VERIFICATION | The prompts and crop stage looks (placeholder boxes) have not been seen. The world starts in summer, when the grains can't be sown (A-4). Beds have no owner. A-6 and A-7 cover how you sow and water. |
| 5 | **Starting route** (gathering, tools, logs, blocks, firewood, fire sizes, shelter) | R1/R2 | #1095 → `b94b1e7`; #1100 → `0bc1930` | HEADLESS_GODOT `test_primitive_route` at `2145537` walks hand → Stone Axe → felled oak → logs → blocks → hammer → Chopping Block → firewood → medium fire → bonfire → charcoal → Lean-to → thatch floor, with **zero admin gives**, and checks every goal count. A fresh character drinks within 10 s. | NEEDS PLAYER VERIFICATION | The look of the 3 m log, the shoulder log and the cut band. The plain-log mesh is still 1.0 m. How log carrying feels: species logs weigh 45/32/26 kg; the plain log is 18.4 kg (A-25). F6–F8 and F10 are proposals for Dave and are not changed. |
| 6 | **Copper / Bronze / Iron / Steel progression** | R2–R4 | #1092 → `596d156`, #1099 → `eedef36`, #1101 → `54b2c51`; **Steel: #1102, not in dev** | HEADLESS_GODOT `test_smelters`, `test_bronze_path`, `test_iron_saw_route`, `test_copper_tools`, `test_tool_ladder`. There is no ore cycle: stone tools mine copper and tin, Bronze tools mine iron. | Copper/Bronze/Iron: NEEDS PLAYER VERIFICATION. Steel: BLOCKED (R4 #1102 not in dev) | The whole metal route has never been played from an empty character. The steel ratio is A-19 (owner decision, plan §4). |
| 7 | **3 smelter tiers** | R2–R4 | Primitive and Improved: #1092 → `596d156`. Advanced: #1102, not in dev | HEADLESS_GODOT `test_smelters`: 20/20 and ground output; 40/40/80; 20 s per ingot; bellows 1.30×; iron only while the bellows are worked; pause and resume; two players; save, load and old-layout migration | Primitive and Improved: NEEDS PLAYER VERIFICATION. Advanced: BLOCKED (R4) | The Improved smelter look is a placeholder. Banked smelt time is lost if the game crashes between saves. Costs: A-8, A-9; fuel: A-10. |
| 8 | **4 smithy tiers** | R2–R5 | Primitive (bp 9) and Improved (bp 10): #1092, #1101 → `54b2c51`. Advanced (#1102) and Master (R5): not in dev | HEADLESS_GODOT `test_iron_saw_route`: the Improved smithy is built without iron, makes the Iron anvil, and its wear is saved | Primitive and Improved: NEEDS PLAYER VERIFICATION. Advanced and Master: BLOCKED (R4, R5) | Carry feel: the Improved smithy needs 101.4 kg of materials, and the Primitive smithy and Improved smelter 61.8 kg each, against 52.5 kg carry. Sites take materials in 2–3 trips. Costs: A-8, A-15, A-20. |
| 9 | **Copper tools** | R2 | #1099 → `eedef36` | HEADLESS_GODOT `test_copper_tools` (rows, 1.5 stones per blow, ore without a cycle, felling) and `test_tool_ladder` | NEEDS PLAYER VERIFICATION | The looks are placeholders. The Copper pickaxe's "useful role" is speed only, so its value must be felt in play. The Copper axe needs a leather strap, so it depends on the tannin route. Roster and stats: A-13, A-14. |
| 10 | **Anvils** (Iron, Steel) | R3/R4 | Iron anvil #1307, recipe 724: #1101 → `54b2c51`. Steel anvil #1309, recipe 725: #1102, not in dev | HEADLESS_GODOT `test_iron_saw_route` | Iron: NEEDS PLAYER VERIFICATION. Steel: BLOCKED (R4) | Until R4 merges, validate_items warns that the Iron anvil is a dead end (STATE "temporary warnings"). Costs: A-16, A-21. |
| 11 | **Smelting rules** (conversions, capacities, ground output, rates, staffed bellows, wind, steel carbon vs hopper fuel) | R2–R4 | #1092 → `596d156`; wind and carbon in #1102, not in dev | HEADLESS_GODOT `test_smelters`: 1 ore → 1 ingot; 1 Cu + 1 Sn → 2 Bronze; ore and fuel are taken only when an ingot completes; jobs run in priority order with banked time kept | Non-wind rules: VERIFIED BY TEST. Wind and carbon: BLOCKED (R4) | Ingots on the ground last 7200 s (A-11). Wind threshold 4 m/s is A-18; carbon is dragged onto the input (A-24, protocol 121). |
| 12 | **Wear and repair** | R3/R5 | Wear counter: #1101 → `54b2c51`. Durability, "Needs repair" and hammer repair: R5, not in dev | HEADLESS_GODOT `test_iron_saw_route` (the wear counter is saved) | Wear counting: VERIFIED BY TEST. Repair: BLOCKED (R5) | Durability per tier is A-26. A repair never asks for the anvil (A-27). A worn smithy can't be taken down (A-23). Iron work on a bronze anvil wears it ×3 (A-17). |
| 13 | **Resource bins and fuel pulls** | R6 | not in dev | — | BLOCKED (R6) | A-28 to A-34 |
| 14 | **Building tiers** | R9 scope | No mission PR yet. The catalog baseline (`27d27fbbb`) and BUGLIST-001 placement fixes are in dev | Tests from before the mission only | BLOCKED (the building work package hasn't landed) | Whether every approved tier is buildable and useful from the player route |
| 15 | **Doors and roofs** | R9 scope | Doors: #1077 → `36a3250`, #1078 → `62c24e5`. Roofs: BUGLIST-001 (#1068–#1076) | HEADLESS_GODOT `test_doors`, `test_door_looks` at `94596ec`; BUGLIST-001 370/370 at `8e46c4b` | NEEDS PLAYER VERIFICATION | The look per tier, the arched curves and the frame rate. Icons are not baked. The Crude Roof 45 and Roof 65 rulings still need Dave's confirmation (BUGLIST-001). |
| 16 | **Goals** (automatic, any order, once per character, accurate how-to) | R7 | Runtime: #1088 → `e7d4919`, #1100 → `0bc1930`, credit hooks in #1092 and #1095. Content: #1096 → `69e941e` (docs) | HEADLESS_GODOT `test_goals`: out of order, Admin mode pauses counting, rejoin pays nothing twice, save and restart, exactly one goal_done each, first-hand got_item. The catalog itself: STATIC_READ only | Runtime: VERIFIED BY TEST. Corrected catalog going live: DEFERRED (needs Dave) | Dave decisions 1–6 in the catalog (section 6). Going live needs GA-49 event indexing or a timing measurement on the PC. Other ground pickups and an offline feller's auto-split logs don't count yet (GA-41 `shortcut:`). |
| 17 | **Journal** (J Index, G Goals, M Map, view-only, clickable prerequisites) | R8 | #1093 → `55b1254`; Map page #1090/#1097 | HEADLESS_GODOT `test_goal_ui` (J/G/M/Esc, view-only selection, Learn first, Leads to, Back, one window at a time) | NEEDS PLAYER VERIFICATION | Whether it matches the inventory screen; scrolling to the selected goal; small and large resolutions. Space still jumps under any open screen (pre-existing). |
| 18 | **HUD and placard** | R8 | #1093 → `55b1254` | HEADLESS_GODOT `test_goal_ui` (two-titles rule, placard queue, art, fanfare file, credit row, text fit) | NEEDS PLAYER VERIFICATION | The placard's look, spin and fanfare; HUD clearance under the Comfort and food lines |
| 19 | **Ctrl+Shift admin keys** | R8 | #1087 → `a17bb4b` | HEADLESS_GODOT `test_key_bindings`: exact Ctrl+Shift for all 16 defaults, plain/Ctrl/Shift presses refused, saved-bind migration, rebind/swap/reset, Store All kept | VERIFIED BY TEST (bindings). NEEDS PLAYER VERIFICATION (layouts) | `=`, `-` and `]` with Shift on Dave's keyboard layout; the editor intercepting F5 and F8. Finding not fixed: spring rate has no server admin check (GA-83). |
| 20 | **Discovered charcoal Map** | R8 | #1090 → `2c33569`, #1097 → `272278f` | HEADLESS_GODOT `test_map` (3 runs at `cf83be1`) covers: a blank new map; only cells near the path are surveyed or sent; each player's map is their own; practice only from new cells; a skill gain alone redraws nothing; a revisit at +3 redraws; jump, dash and cave guards; quit/rejoin persistence; no seam at block edges. Cost: about 0.1 ms per survey, 4.5 ms and 4.8 KB per full map send, about 55 ms per block sketch on a worker thread | Discovery rules: VERIFIED BY TEST. The look and smooth opening: NEEDS PLAYER VERIFICATION | Map Scroll mechanics are left alone (unresolved). The two map goals' events come with this PR (section 7). Constants: A-5. |
| 21 | **Integration and post-repair verification** | R9 | this report | The broad run on `0bc19301` (384/384) | BLOCKED | Waiting on: a broad run on `dev` after R4–R6 and the building work; a multiplayer restart test (MULTIPLAYER_RESTART); Dave's F6 pass |

## 4. Multiplayer, conservation and failure recovery (brief §6)

| Check | Evidence | Status |
|---|---|---|
| Two players at one smelter: a second worker is refused, ore is taken out mid-smelt, logging out pauses iron | `test_smelters` (#1092) | VERIFIED BY TEST |
| No item lost or doubled across save and load (smelter stores, old-layout migration, liquid refunds, crop stages) | `test_smelters`, `test_liquid_ingredient`, `test_farming` | VERIFIED BY TEST |
| A goal pays once across retries, reconnects and saves | `test_goals` (#1088, #1100) | VERIFIED BY TEST |
| Each player's map is their own and survives quit/rejoin; the file name is hashed; a bad file is set aside | `test_map` (#1090) | VERIFIED BY TEST |
| A real two-client session restarted mid-play | not run | BLOCKED (no MULTIPLAYER_RESTART lane yet) |

## 5. Changed audit dispositions

The audit (`PLAYER_GOALS_REWARDS_AUDIT.md`, ledger CSV) is unchanged. The findings this mission addressed, in recovery-document numbering:

| Finding | Was | Now | Where |
|---|---|---|---|
| GA-01 Oak tannin bark | no legitimate source | real source, once per felled oak | #1091 |
| GA-02 Scots pine tar | never dropped | drops per log | #1091 |
| GA-03 Client farming | client could only till | sow, water, harvest | #1089 |
| GA-04 Recipe water | stackable water only | filled containers | #1091 |
| GA-40 `after` as a lock | locked goals | display order and links only | #1088 |
| GA-41, GA-47 Live checks and first-hand gathering | possession counted | first-hand `got_item` counter; corrected checks for fibre, fish, hammer, hoe, workbench | #1100 (partial: `shortcut:` for other ground pickups) |
| GA-54 Debug play earns goals | yes | Admin mode and free crafts count nothing | #1088 |
| GA-55 Once per character, atomic | unclear | done before paid, prompt save | #1088 |
| GA-80 to GA-86 Admin keys | mixed | all Ctrl+Shift | #1087 (GA-83 server checks reported, not fixed) |
| P2 primitive route gap (F1, F3, F4, F5) | site kind lost, hand chops and fire tiers not counted | counted | #1095 |
| GA-49 Event-driven goal evaluation | — | still open, needed before the catalog goes live | R7 follow-up |

## 6. For Dave's review

Everything below is **PROVISIONAL**. None of it is approved. Each entry is in `REPAIR_DECISIONS.md` §4 on the lead branch, with its precedent, the files it touches and how to change it.

**First: ruling R-1.** The coordinator ruled that your 00:36Z message lets provisional catalog values go into data for features your brief names. Your message does not name the catalog freeze, so you need to confirm this reading. Until you do, these values merge to `dev` only.

| ID | Question | Provisional answer |
|---|---|---|
| A-1 | Millilitres of a filled container per recipe Water | 500 mL |
| A-2 | Tannin bark per oak, and from which action | 3, once per felled oak, when its logs are first cut |
| A-3 | Water per "water the bed" | up to 8000 mL, scaled by the crop's pour_pct |
| A-4 | The world starts in summer, when grains can't be sown. Change the seasons? | No; teach spring sowing; radish, lettuce and wild seeds come first |
| A-5 | Map constants and where the Mapping skill sits | `data/map.json` values; Mapping is a root skill raised only by surveying |
| A-6 | Which seed E on an empty bed sows | the seed in hand, else the first in the pack |
| A-7 | How a bed is watered | hold a filled container, E on the crop |
| A-8 | Primitive smithy cost | 2 Hide replaced by 2 Log |
| A-9 | Improved smelter cost | clay 24, stone 16, log 2, hide 3, bronze hinges 2, bronze nails 20 |
| A-10 | Smelting fuel | 1 Coal or Charcoal per ore |
| A-11 | How long ingots on the ground last | 7200 s |
| A-12 | Goal completions for old characters before protocol 119 | none |
| A-13 | Which Copper tools exist | Pickaxe and Axe only (no Knife or Hammer) |
| A-14 | Copper tool performance | between Stone and Bronze; no iron mining |
| A-15 | Improved smithy cost without iron | stone 16, clay 10, log 4, bronze ingot 6, bronze nails 20, bronze hinges 2 |
| A-16 | Iron anvil cost | iron ingot 5 + log 1 (from the obsolete bp 164) |
| A-17 | How much faster iron wears a bronze-anvil smithy | ×3 per craft |
| A-18 | Wind needed by the Advanced smelter | 4 m/s |
| A-19 | **Steel carbon quantity** (an owner decision, plan §4) | 1 Iron Ore + 1 Coal/Charcoal in the input → 1 Steel |
| A-20 | Advanced smithy cost | stone 24, clay 12, log 6, Iron anvil 1, nails 30, hinges 4 |
| A-21 | Steel anvil cost | 5 steel ingot + 1 log |
| A-22 | Taking down an old smithy refunds the new cost | yes |
| A-23 | A worn smithy can be taken down to reset wear | no; "Needs repair" |
| A-24 | How carbon goes into the input, not the hopper | drag it onto an input slot (protocol 121) |
| A-25 | Weight of a 3 m log | species logs unchanged at 45/32/26 kg; plain log 15 → 18.4 kg |
| A-26 | Smithy durability | stone 60, bronze 120, iron 240, steel 480 crafts |
| A-27 | Does a repair need the anvil again? | no |
| A-28 | How a smithy (no hopper) gets pulled fuel | the firing takes 1 Coal/Charcoal from within 30 m when the pack has none |
| A-29 | Which resources a bin holds | the existing open_storage_bin list |
| A-30 | Which fire fuel counts for pulls | Coal/Charcoal in an unlit fire only |
| A-31 | Does a lit kiln's finished charcoal count? | yes |
| A-32 | Bin storage form | units (1000/5000/10000), no kg cap |
| A-33 | Is the 300 s pull interval real or game time? | 300 real seconds |
| A-34 | A pull that empties someone's laid fire | the fire keeps its normal life |

These are also listed for your review: retirements made under the approved catalog (the standalone Smithy Bellows #909, the Blast furnace and `smelt_steel` 193, the Quenching trough), and the station display names Primitive smelter and Primitive smithy (REPAIR_DECISIONS §1).

**Open decisions in the corrected goal catalog** (`PLAYER_GOALS_CATALOG_CORRECTED.md`, "Dave decisions"):

1. Rewards for the 11 new goals (none proposed). `activity:repair_station` overlaps audit ADD-11, which is not approved.
2. The 24 locked water and garden blueprints: give them an owner, or leave them blocked.
3. Two reward switches when the catalog goes live: `twine` (4 Stick becomes 4 copper) and `fell` (3 Kindling becomes 6 copper).
4. The completion burst when the catalog goes live: accept it, reset the counters, or mark goals already met as done without paying (recovery Q4).
5. The HUD skipping goals whose mechanic isn't live (recommended: yes).
6. The provisional values the corrected text teaches, and R-1 (above).

**Earlier questions still open** (BUGLIST-001, PLAYTEST-001): the Crude Roof 45 and 65 names, backpack carry bonus 12/18 kg, the wicker basket, rucksack and pack frame slots, and the pickaxe kindling amounts.

## 7. Recheck of the #1096 catalog rows against `dev` `54b2c51c`

#1096 flagged these rows for a recheck once the mechanics landed. This is a static read of `dev` data and code. **This PR applies the changes to `PLAYER_GOALS_CATALOG_CORRECTED.csv` and `.md`,** with the lead's agreement. A row that carries a text correction becomes FIX, otherwise OK. Rewards are untouched. New counts: OK 195, FIX 169, BLOCKED 287 (was 178, 163, 310).

| Row(s) | Catalog verdict | Recheck on `dev` | Proposed verdict |
|---|---|---|---|
| `build:stone_forge` | BLOCKED (R2, bp 9 cost and name) | bp 9 is "Primitive smithy", costs stone 24, clay 10, log 2, hammer tier 1, with no metal (A-8). The site path that dropped the kind is fixed (#1095 F1). | **FIX** (no longer blocked; it carries the cost correction) |
| `craft:copper_ingot`, `craft:tin_ingot`, `craft:bronze_ingot` | BLOCKED (R2 smelting jobs) | Smelting jobs are live (#1092), and the owner gets `_goal_made` per ingot. The GAP-METAL-OWNER caveat stands: credit goes to the station owner only, and only while online. | **FIX** (no longer blocked; they carry the smelting-job text; the caveat stays) |
| `craft:iron_ingot` | BLOCKED (R3, Improved smelter and bellows) | The Improved smelter (bp 300) is live and smelts iron while someone works the bellows. Same owner caveat. | **FIX** (no longer blocked; the caveat stays) |
| 17 `craft:bronze_*` rows (hammer, pickaxe, axe, knife, chisel, sword, mace, shield, helm, greaves, scale shirt, scythe, sickle, spear, arrow, hinges, nails) | BLOCKED (R2) | All are at station `forge`, which the Primitive smithy (`stone_forge`, forge level 1) serves. Bronze ingots come from the Primitive smelter. | **OK**, except `craft:bronze_arrow`: **FIX** (it carries a text correction) |
| `build:log_palisade_gate` | BLOCKED (R2, needs Hinges) | Hinges (recipe 149) are 1 iron ingot at `brick_forge` level 2, the Improved smithy (`blacksmithy`, bp 10, no iron in its cost since #1101). Iron comes from the Improved smelter. The chain is reachable without a cycle. | **OK**. The blocker was R3, not R2 |
| `build:improved_smelter` (PROPOSED) | ids not re-verified | item #1304 "Improved smelter", structure state 368, bp 300 all exist. The placed kind is `improved_smelter`. | refs **verified**. Stays PROPOSED (its reward is for Dave) |
| `craft:copper_pickaxe`, `craft:copper_axe` (PROPOSED) | "key TBD" | The keys are `copper_pickaxe` #1305 (recipe 722) and `copper_axe` #1306 (recipe 723), both at `forge`. The axe needs a leather strap. | refs **verified**. Stays PROPOSED |
| `activity:map_survey`, `activity:map_redraw` (PROPOSED) | GAP-MAP-SURVEY, GAP-MAP-REDRAW | The gap is closed in this PR. `server_map.gd` raises `map_surveyed` once per survey that finds never-seen ground (a survey runs every 8 m walked) and `map_redrawn` once per survey that redraws known ground at a higher skill. Both go through `_goal_event`, so Admin mode pauses them and each goal pays once. It counts each survey, not each cell, so a survey costs one goal check (GA-49). The catalog condition says so. Tested in `test_map`. Survey count N is for Dave. | stays PROPOSED (reward and N for Dave); event gap closed |

## 8. Still to do before R9 is complete

1. Fill rows 6–8 and 10–14 when R4 (#1102), R5, R6 and the building work merge.
2. Run a broad lane run on `dev` after those merges.
3. Run a multiplayer restart test.
4. Get Dave's F6 pass with [PLAYER_PROGRESSION_REPAIR_F6.md](PLAYER_PROGRESSION_REPAIR_F6.md).
5. Get Dave's answers on section 6.
6. Recheck the rows blocked by WP-METAL R3, WP-R1B, WP-PRIM and WP-GUIDE-UI, now that those PRs are in `dev`.
