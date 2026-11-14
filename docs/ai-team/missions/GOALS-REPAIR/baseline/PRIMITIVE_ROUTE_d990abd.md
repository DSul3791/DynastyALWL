# GOALS-REPAIR WP-PRIM baseline: primitive starting route (read-only)

- Repo HEAD read: `08121e5c35c0ed44dd053c5afef757bc574e1bd6` on `claude/project-thread-21lhdk`. `git diff --stat d990abd HEAD -- src data` is empty, so `src/` and `data/` are identical to dev `d990abd` (verified).
- Method: STATIC_READ only. No Godot run, no test run, no repo edit. Line numbers are `src/stream/server_items.gd` unless stated.
- Authority read: repair plan §1, §2, §3 P2, §5; recovery GA-10..18, 22, 24..26, 34..37, 43..45 (lines 40-75); master §2.1-2.6, §3.0, §3.1, §3.2, §4, §7; buildables_plan §1-§3, §6; progression Gate 1-2 and Buildings; STATE.md ownership table; REPAIR_DECISIONS; BUGLIST-002 LEDGER; audit ledger CSV rows for the primitive goals.
- Already fixed in dev (kept, not re-raised): BUGLIST-002 doors/empty frames (#1077/#1078), BUGLIST-001 roof panels 45/65 (BUG-011) and placement fixes. All still NEEDS PLAYER VERIFICATION per their ledgers.

## Route trace (fresh character, no admin)

| # | Step | Server action | Client affordance | Data | Goal event today | Verdict |
|---|---|---|---|---|---|---|
| 1 | Sticks, stones | ACT_PICKUP `_pickup` 4619; batch `_pickup_batch` 4706; seeded scatter `_lay_out_cell` 5386 (spawn boost 5406-5412); dead branch ACT_LITTER `_pick_litter` | E on item; harvest.gd:121 (branch) | drops.json spawn_boost, pickup_batch.json | none (no got: counter; GA-41/46 belongs to guide-UI) | Reachable |
| 1 | Plant fibre | `gather()` 1563 via terrain_server.gd:1872 (`cut_flora` from harvest.gd:152); by_species rows 1588 | E prompt harvest.gd `_prompt_for` 228 | drops.json by_species flax/tall_grass/nettle/reeds/riverbraid/tanglewort | live goal `fibre` = have_item 12 (possession poll) | Reachable |
| 2 | Twine, Stone Knife/Axe/Pickaxe | ACT_CRAFT_QUEUE `_queue_craft`; completion 17359-17414 `_goal_made` | Crafting UI (hand) | recipes 1 twine (3 fibre), 24 bark twine (2 bark), 6 knife (2 stone,1 stick), 2 axe (1 stone,1 stick,2 twine), 186 pickaxe (2 stick,3 stone,2 twine) all known, hand | made:twine / made:stone_axe / made:stone_knife / made:stone_pickaxe (per craft, not per unit: GA-44) | Reachable |
| 3 | Fell a tree | ACT_HIT `_hit` 5828 (axe or pick in hand, `_wood_tool` 5988), `_fell_record` 5942, auto split `_auto_split` 6640 / `split_trunk` 6671; hand cutting `_process_trunk` 6423 | swing held tool (held_item.gd) | drops.json trunk.log_length_m **2.44**, max_logs 20; felling counts drops.json felling | `tree_felled` at 5900 for ANY tree, including a sapling with no log (GA-35) | Reachable; log length not the approved 3.0 m (F2) |
| 3 | Small vs large blocks | `_chop_loose_log` 9223: shoulder species log -> 3 `block_large` of its class; plain `log` -> 3 `block` of default class; `_wood_item` 9207 | axe swing on a loose log, held_item.gd:1972 (ACT_PROCESS) | wood_species.json class_items, default class softwood; `_log_number` 6627 | none (GA-45) | See species table below |
| 4 | Carry/place logs, 3 m sourcing | shoulder pickup 4637-4656 (one at a time, "Put your log down first (Q)"); `lay_down_shoulder` 930 (ACT_DROP a=-1); `_pull_nearby_logs` 15895 with `LOG_NEAR_M` 3.0 (15844), used by blueprints 8164, recipes 17006, repairs 8599 | Q `put_down_log` key_bindings.gd:30 -> terrain_client.gd:4351; F-twice / D in pack inventory_view.gd:1087-1092, 4984; client nearby-log count inventory_view.gd:3260-3292 (hard-coded 3.0) | items.json log_<species> carry shoulder, stack 1; plain `log` stack 5 | "Using nearby logs" notice only | Reachable |
| 5 | Wooden Hammer, Chopping Block | hand craft queue | Crafting UI | recipe 161 (wooden_block group + stick + twine), 232 duplicate (soft block), 339/340 large -> 4 small (keeps axe group), 15 Chopping block (1 wooden_block_large group) | made:wooden_hammer / made:chopping_block; live `hammer` goal = have_item_any (possession) | Reachable from any full-size tree (hammer); Chopping Block needs a key-species tree |
| 6a | Manual: log -> blocks | `_chop_loose_log` 9223 axe branch 9270-9278 | axe on loose log | structures.json chopping_block blocks_per_log 3, blocks_per_shoulder_log 3 | **none** | Works, no completion signal |
| 6b | Manual: block -> firewood at the block (E) | `_use_struct` split_log branch 9160-9204 (axe in hand, block in pack, firewood dropped beside block 9215) | "Press E to split firewood, F to chop logs from storage" inventory_view.gd:931 | firewood_per_block **2**, firewood_per_large_block 4 | **none** | Works, no completion signal |
| 6c | Chopping Block station (F queue) | recipes 720/721 `chop: true`, `_chop_yield` 17433; output to block's out_slots; `_goal_made` 17414 | F opens the block, craft queue | station takes `log`; 12 firewood per species log, 6 per plain Log | made:firewood (hard only) or made:firewood_soft, per craft not per unit | Works; event only on this path |
| 7 | Campfire build/fuel/light | recipe 4 (6 stick, 3 stone) -> campfire_kit placed from pack `_place` 3666 -> laid fire with start sticks 3820-3826; feed via fire store (F, ACT_CHEST_PUT, `_sync_fire_from_box` 9790 on close / at once when unlit 9966-9968); E light `_light` 7568 | F store window; E light inventory_view.gd:859 | cooking.json fuel, fuel_class, fire_tiers, min_pieces 3, wet_wood | `placed:campfire` 3829, `fire_lit` 1133-1139 | Reachable |
| 7 | Medium / bonfire | tier state = fire["state"] 40 / 1 / 41 (`FIRE_STATE_SURVIVAL` 117, `FIRE_STATE_BONFIRE` 118, `_fire_tier_of_state` 7451); `_fire_best_state` 7345 (3 pieces of class; pot caps logs at medium 7356-7357; wet = one tier lower 7363-7364); `_fire_restate` 7370; `_refresh_pots` 7410; `_fuel` refuses logs under pot 7535/7559 | notice "a small/medium/large fire" on store close 9821-9823 only; fire look by state | firewood, blocks and charcoal are all class "firewood"; every log incl. plain `log` class "log" | **none on tier change** (GA-45) | Mechanic present; no event |
| 8 | Leaves, Lean-to | crown litter on fall `_crown_litter` 6826 (crown_scatter ~5.5-8 leaves/m; none from conifers or bare broadleaf in winter); trunk branch blows; shrub axe 10-20 leaves (drops.json shrub_work); `_pickup_batch` | hammer blueprint list | blueprint 25 Lean-to: 20 stick, **60 leaves**, 6 twine, hammer 1 | `placed:lean_to` via `_after_built` 8499 (but see F1) | Reachable |
| 8 | Bed | rough_bed_kit hand recipe 162 (10 thatch, 4 stick, 2 twine) or 231 (bedding); kit placed from pack; structure `shelter_needed` | Crafting UI then place | blueprint 24 is `retired` (bed is a pack kit, `is_dead_kit` comment, Dave 4 Nov 2026: "only the rough bed and the campfire are still made in the pack") | `placed:rough_bed` | Reachable; GA-17 F6 test owed |
| 8 | Workbench and levels | blueprint 33 (16 stick, 6 twine, 4 stone) L1; Tool rack bp 34 and Vice bp 53 each +1 level (`_addon_kinds` 13246, `station_level_of` 13184) | hammer list | L2: longbow, plank shield, cart wheel, axle; L3: water wheel, spyglass | `placed:workbench` | Wooden Workbench reaches L3 with primitive add-ons |
| 9 | Crude shelter | blueprints 29 foundation, 30 wall, 32/252/253/254 empty doorways, 272-275 Crude doors, 60 window, 31 Roof 45, 251 Roof 65, 83 roof corner; all `hammer` 1, known; door snap `PlacementRules.doorway_fit` (`_place` 3726-3732); roof panel must rest (3719-3721) | hammer blueprint menu | costs match buildables_plan §2 and master §3.0 (frame = wall: 3 twine, 20 thatch, 6 stick; Crude door 50 stick + 100 twine) | `placed:<kind>` | Reachable at Crude with a Wooden Hammer (tier 1); F6 still owed (BUGLIST-001/002) |
| 10 | Drink / eat early | `_drink_water` 18363: refuses only at `wet >= cap - 1` (18407-18409); drain 1000-2200 mL per game day in the vitals tick 11601-11603; new vitals full 10219 | E at water inventory_view.gd:980/2196 | vitals.json thirst cap 2400, drink 300 | `drink` 1104-1109 (wet rose), `ate_food` 1098-1103 (fed rose; eating at full stomach adds weight, not fed: no event) | Drink possible about 4 real s after spawn by code; GA-36 is wording/UX (TEST NEEDED) |
| 11 | Campfire charcoal | recipe 341 at `campfire` station (lit fire, `station_near` 13039-13046): 2 firewood (group, soft too) -> 12 charcoal; kiln recipe 364 retired, kiln batch `_kiln_burn` 9421 (metal thread) | Crafting UI near lit fire | cooking.json fuel charcoal 3600 game s, class "firewood" | made:charcoal per craft | Reachable before any Kiln (master §4.8 satisfied) |

### Which species give which blocks (step 3)

| Felled tree | Log item | Hand chop on ground (`_chop_loose_log`) | Chopping Block F |
|---|---|---|---|
| Oak, beech, birch, maple, walnut, tropical hardwood (mahogany) | own `log_<species>`, shoulder | 3 Large wooden block (hardwood) | 12 Hard firewood (recipe 721) |
| Scots pine, spruce | own log, shoulder | 3 Large softwood block | 12 Soft firewood (recipe 720) |
| Every other species (alder, willow, rowan, sweet chestnut, wild apple/pear/cherry, palms, acacia, mangrove, balsam fir, fantasy trees; their log_ rows are retired) | plain `Log` (pack, stack 5) | 3 Softwood block (small) | 6 Soft firewood |
| Any tree shorter than one log length (2.44 m today, 3.0 m approved) | none | firewood, kindling, sticks only (`_split_small` 6748, small rows) | n/a |

Small Hardwood blocks exist only via recipe 339 (large -> 4 small). A Chopping Block needs a key-species tree; a Wooden Hammer works from any full-size tree; a Stone Hammer needs no tree at all.

### Dependency graph (primitive tier, as coded)

```
hands --> stick, stone (scatter), plant fibre (grass/nettle/reeds/flax), thatch (thatch grass/reeds/heather), leaves (crown litter, shrub+axe)
fibre x3 --> Twine            bark x2 --> Twine (bark from trunk work)
stone+stick ------------------------> Stone Knife   (carcass, knife recipes)
stone+stick+twine2 -----------------> Stone Axe ----+--> fell tree --+--> key species log (shoulder) --axe--> 3 Large block --+--> Chopping Block (1 large)
stick2+stone3+twine2 ---------------> Stone Pickaxe |                |                                                       +--axe recipe 339/340--> 4 small block
stone+stick+twine ------------------> Stone Hammer (tier 2, no tree) |  +--> plain Log (pack) --axe--> 3 Softwood block -------+--> Wooden Hammer (tier 1)
                                                    |                +--> sapling --> firewood/kindling/sticks
                                                    +--> Chopping Block: E (axe in hand, block in pack) --> firewood beside block;  F queue: log --> 12/6 firewood
stick6+stone3 --> Campfire kit --place--> laid fire (start stick) --E--> lit (small) --3 firewood/blocks/charcoal--> medium --3 logs, no pot--> bonfire
lit campfire + 2 firewood --> 12 Charcoal  (later: Kiln 100/log, metal thread)
hammer (t1) --> Lean-to (20 stick, 60 leaves, 6 twine), Workbench L1 (+Tool rack, +Vice = L3), Crude foundation/wall/doorways/doors/window/Roof 45/Roof 65/corner
hand --> Thatch - Bed kit --place under cover--> bed (spawn point)
```

No circularity found. One species dead end: no key-species tree within reach means no Chopping Block (the hand E-split needs a placed block).

## Findings (repair plan §5 tags)

**F1. DEFECT AGAINST EXISTING APPROVED RULE (goal truthfulness; recovery GA-43 "all legitimate creation paths via common server completion events"; repair plan P2 "any goal event must reflect an actual player-caused achievement").** A blueprint placed short of materials becomes a site; when the last material is deposited `_finish_site` 8948-8956 passes the raw `_structures` row to `_after_built`, and `_after_built` 8499 emits `_goal_event(peer, "placed", str(def.get("kind", "")))`. No structures.json row has a `kind` field (0 of 314, checked); only `_structure_of_kit` 8346-8352 adds it to a copy. So a Lean-to, Workbench or any Crude piece finished through a site records `event:placed` with no kind and never `placed:lean_to` / `placed:workbench`. Same through `_gather_site` 8937. Smallest fix: in `_after_built` use `str(entry["struct"]["kind"])` (always set, 8445). Files: server_items.gd `_after_built` only. Test: test_blueprints.gd site path (235) or test_goals.gd: place lean_to with half its sticks, deposit the rest with E, assert goal `shelter` done. Owner: construction placement code, not in the STATE table; lead to assign (WP-PRIM).

**F2. DEFECT AGAINST EXISTING APPROVED RULE (master §2.3 item 1 "Felled full logs are 3.0 m; adjust weight and geometry consistently"; §4.3 last bullet; §7 item 3).** drops.json `trunk.log_length_m` is 2.44 (code fallbacks 2.44 at 6460, 6483, 6619, 6679, 6921). Smallest fix: drops.json `log_length_m` 3.0 (re-check `blows_per_log`, `max_logs`), weights.json log masses, client log mesh length if it encodes 2.44, and tests that count logs (test_all_trees_logs, test_fell_autosplit, test_trunk_cutting, test_beech_logs, test_logs_carry). Fewer logs per tree and trees 2.44-3.0 m stop giving a log: GA-35 text must say "full-grown". **Shared-file conflict:** drops.json and tree/trunk processing are WP-R1A's; do it in WP-R1A or after it merges.

**F3. MISSING FEATURE (GA-13, GA-45; ledger rows activity:chop_log_blocks, craft:firewood).** No completion signal for manual chopping: `_chop_loose_log` axe branch 9270-9278 and the E split in `_use_struct` 9196-9204 emit nothing. Only the F-queue path credits `made:firewood` / `made:firewood_soft` (17414), per craft. Smallest fix: two call sites, `_goal_event(peer, "log_chopped", <block id>)` after 9277 and `_goal_event(peer, "firewood_split", <firewood id>)` after 9200 (event names and unit-vs-action counting to agree with the guide-UI thread, which owns `_goal_*`). Note the ledger goal craft:firewood checks `made:firewood` (Hard only); soft-firewood routes never satisfy it. **Conflicts:** `_chop_loose_log` is reached from `_process_trunk` (WP-R1A section); `_use_struct` also holds the kiln branch (metal thread). Touch only the split_log branch lines.

**F4. MISSING FEATURE (GA-45; ledger activity:medium_fire / activity:bonfire; repair plan P2 Campfire bullet).** Tier state exists (40/1/41) but no event when it changes. Player-caused changes go through `_sync_fire_from_box` 9790 (store closed or unlit put), `_light` 7568, `_fuel` 7517 (ACT_FUEL has no client sender today; tests only). Smallest fix: in `_action` (as `fire_lit` is done at 1133-1139) or inside those three functions, compare `_fire_tier_of_state` before/after for a lit fire and emit `_goal_event(peer, "fire_tier", str(t))` for each tier newly reached (2, 3; a direct bonfire also credits medium per ledger "Medium = tier >= medium"). Burn-down and `_tend_fire` auto feeding stay uncredited (not player achievements). Damp wood lowers the state, so a wet bonfire credits only medium: matches the rule. Fire code has no listed owner; metal thread's 30 m charcoal pull reads fire stores, so coordinate if it edits `_fire_apply_store`.

**F5. TEST NEEDED (GA-36).** By code a new character can drink about 4 real seconds after spawning: refusal only at `wet >= cap - 1` (18407) while thirst drains ~0.28 mL per real second at rest (11601-11603); `drink` fires when wet rose (1104-1109). Eating at a full stomach adds weight, not `fed` (`_eat` cap logic), so `ate_food` needs fed below cap, which is true within seconds. The audit's "impossible until dehydration" is not supported by static read; the real problem is that the HUD shows 100 % and the player feels no need. Fix is goal wording/placement (guide-UI thread). Test: fresh character, wait 10 s, E at fresh water, assert `event:drink` = 1; same for a berry.

**F6. DESIGN COHERENCE PROPOSAL (rubric 3/8, P2 "respect charcoal/fuel economy").** Firewood is not conserved across the approved manual routes: Large block E-split = 4 firewood (firewood_per_large_block 4, code comment cites Dave 4 Nov BUG-014), but recipe 339/340 turns it into 4 small blocks that split into 2 each = 8. Chopping Block F gives 12 per species log = the direct route. Recommended minimal change: structures.json `chopping_block.firewood_per_block` 2 -> 1 (code default at 9200 is already 1; the 2 has no recorded provenance), which keeps Dave's 4 and makes every route conserve (plain Log then gives 3, not 6). Value change: log as an A-n assumption for Dave's review, or leave unchanged. structures.json is owned by the metal thread.

**F7. DESIGN COHERENCE PROPOSAL (rubric 4, tier value; master §2.1 hammer ladder Wooden, Stone, ...).** Stone - Hammer (recipe 156: 1 stone, 1 stick, 1 twine; tier 2; durability 4350) is available as early as the Wooden - Hammer (recipe 161: needs a chopped block; tier 1; durability 1500) and is better in every listed property, so the Wooden Hammer has no discernible purpose beyond teaching the block. Keep both (approved ladder); goals already accept either (`hammer` have_item_any). Report only; any recipe change is Dave's.

**F8. DESIGN COHERENCE PROPOSAL (duplicate recipe).** Recipe 232 `wooden_hammer_soft` duplicates recipe 161: 161 asks for the `wooden_block` group, which already includes `wooden_block_soft` (wood_species.json ingredient_groups). Two "Wooden - Hammer" rows in the crafting list. Proposal: retire 232 (recipes.json, metal-thread owned; retirement is outside ruling R-1, so it waits for owner review). starter_goals.json `hammer` lists a non-existent item `wooden_hammer_soft` (harmless; guide-UI file).

**F9. DEFECT AGAINST EXISTING APPROVED RULE, text only (GA-34; master §3.2 Stone - Wedge retired; `_light` 7566-7567 "no starter needed").** items.json descriptions are stale: `campfire_kit` "light it with fibre", `plant_fibre` "or use one to light a fire", `log` "or wedge it into planks", `wooden_block` "a small hardwood log" (no small hardwood log exists; the plain Log is softwood class, master §4.3). drops.json `trunk.leaves_note` still says a lean-to takes about 200 leaves (live cost 60; GA-16 says do not copy it); test_first_hour.gd:198-201 carries the same stale comment and admin-gives leaves/twine/sticks. items.json is metal-thread owned.

**F10. DESIGN COHERENCE PROPOSAL (master §2.6 "Charcoal ... burns longer"; §4 item 9 "a fuel burn time (longer than Hard firewood)").** cooking.json `fuel.charcoal` is 3600 game s against Hard firewood 28800. A literal per-piece fix (longer than 28800) with 12 charcoal per 2 firewood and 100 per Kiln log multiplies fuel many times over. The rule needs a basis (per piece vs per wood consumed) before any value changes; record as a lead/Dave question with no change now. Overlaps the metal thread's fuel-burn tuning (master §5).

**F11. TEST NEEDED.** F6 checks still owed: GA-17 bed under a Lean-to and near Crude walls; GA-25 doors/frames and Roof 65 corners (BUGLIST-001/002 ledgers); three shoulder logs into the fire store making a bonfire (store slots 30, logs unstackable); campfire placed on a Crude foundation (3740-3745); Chopping Block reachable in the starting biome (key-species tree present near spawn).

**F12. Observation only (rubric 5).** Tool rack and Vice raise the Wooden Workbench to L3 with primitive materials, the same level the Stone Workbench starts at; Carpenter's bench and Stone Workbench then add little level value. Approved as is (buildables_plan §4); no change proposed.

Out of WP-PRIM scope, noted for owners: got:<item> acquisition counters (GA-41/46, guide-UI); made: counts crafts not units (GA-44, guide-UI); kiln charcoal credit (GA-43, metal thread); tannin bark/pine tar/recipe water (WP-R1A); crops (WP-R1B).

## Existing tests per step (none run here)

| Step | Tests | Real acquisition? |
|---|---|---|
| 1 gather | test_first_hour.gd (heaps by hand, 109), test_playability_bot.gd, test_new_player_day.gd, test_server_items.gd:260-262 (gather), test_auto_pickup.gd | yes (first_hour, bot) |
| 2 tools | test_first_hour.gd 115-118, test_playability_bot.gd, test_new_player_day.gd (knife), test_goals.gd (twine/axe goals), test_tool_ladder.gd, test_ore.gd (pickaxe use) | mostly |
| 3 fell / species logs | test_all_trees_logs.gd, test_beech_logs.gd, test_fell_autosplit.gd, test_trunk_cutting.gd, test_felling_time.gd, test_fell_pose.gd, test_stump_chop.gd | yes; none asserts 3.0 m |
| 4 logs / 3 m sourcing | test_logs_carry.gd (shoulder, ground within 3 m), test_playability_bot.gd | yes |
| 5 hammer / Chopping Block | test_first_town.gd (drops a large block 133), test_mission001_walkthrough.gd (drops a large block 474), test_ingredient_groups.gd, test_tool_ladder.gd | no: large block is spawned |
| 6 chopping / splitting | test_first_town.gd 171-187 (log on ground -> 3 soft blocks -> E split), test_server_items.gd 1530-1580 (E split, admin-given blocks), test_station_storage.gd 359-396 (F recipes), test_e_priority.gd (E routing) | partly; no goal-event test |
| 7 fire | test_fire_fuel_tiers.gd (tiers, pot cap 117-122), test_fire_store.gd, test_fire_store_pack.gd, test_fire_wet_wood.gd, test_fire_coals.gd, test_fire_state_look.gd, test_first_hour.gd 164-175, test_goals.gd (fire_lit) | tiers tested with given wood; no tier-event test |
| 8 lean-to / bed / workbench | test_lean_to_bed.gd, test_bed.gd, test_leanto_collider.gd, test_blueprints.gd, test_stations.gd (add-on levels), test_goals.gd (shelter, workbench) | leaves admin-given in test_first_hour |
| 9 Crude shelter | test_thatch_pieces.gd, test_roof_panels.gd, test_doors.gd, test_door_looks.gd, test_placement_rules.gd | admin/free build |
| 10 drink / eat | test_goals.gd 85-88 (sets wet 1000), test_camp_bench_drink.gd, test_drinking_water.gd, test_first_hour.gd 181-189, test_new_player_day.gd (eat) | no "fresh full character drinks" test |
| 11 charcoal | test_mission001_walkthrough.gd make_charcoal 382-391 (firewood given), test_cooking_route.gd, test_station_storage.gd, test_iron_saw_route.gd, test_bronze_path.gd | firewood given |

Gap for the P2 gate: no single test walks hand -> tree -> blocks -> hammer -> Chopping Block -> firewood -> medium fire -> bonfire -> charcoal -> Lean-to -> Crude hut with zero gives and asserts each goal event once.

## Shared-file conflicts

- server_items.gd `_process_trunk` / `_chop_loose_log` / `split_trunk` and drops.json: WP-R1A (F2, F3a).
- server_items.gd `_use_struct` (kiln branch is metal thread's; WP-PRIM touches only the split_log branch) (F3b).
- server_items.gd goals section `_goal_*`: guide-UI thread; WP-PRIM adds call sites only, event names agreed with them (F3, F4).
- data/items/{items,structures,recipes}.json: metal thread (F6, F8, F9).
- starter_goals.json / goal text: guide-UI (F5, F8 dead id).
- cooking.json: no owner listed; F10 overlaps metal fuel tuning.

## Verified vs not verified

- Verified (static read at 08121e5 = d990abd for src/data): every file:line above; that no structures.json row has `kind`; recipe/blueprint costs; group membership; drink/eat thresholds.
- Not verified: any runtime behaviour, client rendering, F6 placement, multiplayer, save/load; tree heights per biome; whether key-species trees grow near the default spawn; whether the client log mesh encodes 2.44 m; the `_finish_site` goal loss has not been reproduced in a test.
