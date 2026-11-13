# GOALS-AUDIT: runtime workstream (completion, persistence, payout, events)

Baseline: dev dc2fa52, branch `claude/project-thread-d8jals`. This audit only read the code and data. Every claim is CODE_VERIFIED unless a test is cited, and no tests or Godot were run. Machine-readable results are in `ws_runtime.json` (63 goal entries: the 28 legacy goals, 5 activities, 20 gather goals, 6 craft goals made by paths that skip the hooks, and 4 double-milestone overlaps). `S` below means `src/stream/server_items.gd`.

## How the current engine works (summary)

- **Data.** `S:15632-15642` loads `data/items/starter_goals.json` (18 goals) and `camp_goals.json` (10 goals). The `_about` lines in both files still say "read by nothing yet", which is stale.
- **Counters.** Counters are stored per character in `goal_counts`:
  - `_goal_event` (`S:15662-15676`) writes `event:<name>` and `event:<name>:<what>`.
  - `_goal_made` (`S:15679-15688`) writes `made:<item>`.
  - `note_talked` (`S:15200-15223`) writes `hit:<goal>`.
  - `_night_walk_tick` (`S:15226-15251`) writes `moved_lit_night`.
  - Counters are recorded for every item and kind, whether or not a goal uses them, from the moment the character exists.
- **Checks.** `_goal_met` (`S:15691-15737`) accepts these check types: event counter, `what_any`, `made_item` (plus `or_have`), `have_item`, `have_item_any` (plus `or_event`), `worn_warmth`, `talked`, `moved_lit_night`.
- **Completion.** `_goals_check` (`S:15749-15789`) loops over all goals until nothing changes. It skips goals that are done or locked (`_goal_open` checks `after`, `S:15740-15747`), sets `goals_done[id]`, and pays `coin_copper` through `add_coins` or `item` through `give`. Only these two reward types exist; `rep` is ignored. It then posts one notice line.
- **When checks run.** On every event, and for every connected peer on every slow tick (0.25 s, `S:376`, `S:1395`).
- **Journal/HUD.** Completion and payout never touch the Journal or HUD, and nothing has to be claimed. `goals_state` (`S:15825`) is read-only.
- **Tests.** `src/worldgen/tools/test_goals.gd` asserts:
  - drink pays 2 copper and the notice names the coins (84-90);
  - fibre completes with 12 held (93-95);
  - twine waits for fibre, then completes and gives 4 sticks (96-98);
  - axe completes when crafted (104-106) or held (245-250);
  - fell gives kindling (117);
  - placing a fire does not complete `fire`, lighting it does (121-129);
  - shelter and workbench complete on placement (131-142);
  - finished goals survive a restart (144-150);
  - story counts Edda at night, but not Hob or noon (190-200);
  - night_walk completes at 100 m (202-212);
  - a log_workbench completes workbench (235-238);
  - the fish catch counter works (241-244).

  These are AUTOMATED_TESTED only for those exact behaviours, and the tests were not run here.

## Findings

### R-01 HIGH: `after` gating blocks out-of-order completion
- **Affected goals:** all 28 legacy goals, chiefly the 25 that depend on `fibre`.
- **Evidence:** `S:15740-15747` and `S:15763`. The starter and camp `after` lists form a chain: fibre → twine → axe → fell → hammer/fire → hoe/path/berries/shelter/bed/workbench/torch_night…, and fibre → sell → order.
- **Behaviour now:**
  - Counter goals are only deferred: their counts keep building and they pay the moment the goal unlocks (test_goals.gd:92-98).
  - Have-item goals lose credit if the item is gone by the time the goal opens.
- **Why it matters:** the draft requires that "any valid earlier/out-of-order completion must earn the goal" (`PLAYER_GOALS_REWARDS_DRAFT.md:10`) and that ordering "is not an in-game unlock gate" (line 19). The draft is still PROPOSAL status, and the brief states the same requirement.
- **Fix:** drop `after` from the completion test. Keep it only as display order for the Journal and HUD (`goals_state`).

### R-02 HIGH: possession checks lose credit and accept non-earned items
- **Affected goals:** `fibre` (12 held at once), `hammer`, `hoe`, `winter_store`, the held-fish fallback of `fish`, and the `or_have` part of `axe`.
- **Evidence:** `S:15715-15734`.
- **Problems:**
  - Credit is lost when the item is consumed, broken, sold or dropped before the check passes.
  - A player who twists twine as fibre comes in may never hold 12 fibre. That blocks the root of the chain (R-01) and keeps "Gather plant fibre" on the HUD forever. The draft itself flags this risk at line 773.
  - The checks also pass for bought items (Hob sells plant_fibre, stone_axe, torch, twine, firewood: `data/npcs/shops.json` hob.stock), for admin gives and for chest withdrawals.
  - Draft line 768 says completion must "never merely" be an inventory item.
- **Fix:** use history counters instead of possession:
  - `made:wooden_hammer` and `made:wooden_hoe` (both wooden-hammer recipes give `wooden_hammer`);
  - `got:plant_fibre` ≥ 12, a cumulative count (see R-08);
  - for `winter_store`, decide whether "hold 5 at once" is the intended design. It needs a creator ruling because it is a possession goal by design.

### R-03 HIGH: item rewards break the money-only rule; crash can duplicate them
- **Affected goals:** `twine` gives 4 sticks and `fell` gives 3 kindling (`starter_goals.json` goals[2].reward, goals[4].reward). The draft pays 4 and 6 copper.
- **Other problems:**
  - Item rewards go to `inventories.json`, while `goals_done` goes to `characters.json`. Within one save batch, inventories is written first (`S:1490`, then `S:1545`). A crash between the two writes keeps the item but not the "done" mark, so the reward can be paid again.
  - The `story` reward's `rep: 1` is silently ignored (`S:15766-15775`).
- **Fix:**
  - Change both rewards to `coin_copper`.
  - Remove the `item` reward branch.
  - Decide whether `rep` belongs in a money-only system. It is a creator call.
  - Characters already marked done are not paid again; they keep the sticks or kindling.

### R-04 MEDIUM: persistence and crash window
- **What is safe:**
  - `goals_done`, `goal_counts` and `coins` sit in the same character row and are written to `characters.json` in one atomic tmp-and-rename write (`S:18178`, `S:5221-5260`). They are always consistent with each other: no double pay and no done-but-unpaid goal.
  - Several goals completing together are each paid inside one loop (`S:15758-15789`), so rewards are not lost.
  - Repeated events cannot pay twice, because `goals_done` is checked first.
  - Two connections on the same character share one row, and the code runs on one thread.
- **What can be lost:**
  - Saves happen every 30 s, and only when the state has changed (`_dirty`) (`S:50`, `S:1425-1435`). They are written in the background.
  - A crash loses up to about 30 s: completions, coins and the counters behind them. The player has to redo those actions.
  - A clean shutdown saves synchronously (`scenes/terrain_server/terrain_server.gd:2943`).
  - A disconnect needs no save: the row stays in memory until the next autosave.
- **Fix (optional):** after a completion, bring the next characters.json save forward (for example, cap `_save_in` at a few seconds). Measure the cost of writing the save file first. With money-only rewards, no cross-file duplication remains.

### R-05 HIGH (main route) / MEDIUM: some item-making paths never credit craft goals
- **Only hook:** `_goal_made` is called in exactly one place, `_craft_tick` (`S:17414`).
- **Paths that skip it:**
  - chopping-block hand split (`S:9170-9203`);
  - axe on a loose log (`S:9223-9278`);
  - the kiln's automatic charcoal (`S:9421-9449`);
  - fire-store cooking (`S:9834-9864`) and ACT_COOK (`S:7650-7668`);
  - pick and splinter yields;
  - the legacy immediate ACT_CRAFT (`S:1218`, `recipe_table.gd:118`), which only client test harnesses send.
- **Affected goals:**
  - `craft:firewood`: main route, draft line 46 teaches the hand split, so this goal can never complete;
  - `craft:firewood_soft`, `craft:wooden_block`, `craft:wooden_block_soft`;
  - `craft:charcoal` through the kiln (the draft's campfire recipe works);
  - `craft:roast_forage` through fire cooking (the draft's clay-hearth recipe works);
  - `activity:chop_log_blocks` (see R-07).
- **Fix:** add one `_credit_made(peer, item, units)` helper and call it from these player-driven paths.
  - Kiln and fire-store output has no acting peer. Record the peer who loaded or lit it on the row, or exclude these paths by design.
  - Purchases, trade and loot should not count as "made". The creator should confirm this.

### R-06 MEDIUM: made counts are per craft action, not per unit
- **Evidence:** one `_goal_made` call per completed craft (`S:17414`):
  - a sealed batch of N counts once (`S:17396-17401`);
  - a chop of one log that gives 12 firewood counts once.
- **Affected goals:**
  - `twine` (2): the sinew_cord recipe gives 2 per craft but still counts 1;
  - `jerky` (2): needs 2 crafts, which is 4 jerky;
  - `dry_berries` (3);
  - any catalog goal whose count is above 1.
- **Fix:** define the unit. Recommended: count units produced, written as `made:<item>` += gives × times, with the existing data rewritten to match. The other option is to state "crafts" in the How-to text.

### R-07 MEDIUM: three activity goals need new events

**Already supported:**
- `activity:place_campfire` is supported (`S:3829`).
- `activity:place_chopping_block` is supported (`S:8499`).

**`activity:chop_log_blocks`** needs a new `log_chopped` event in `_chop_loose_log` (`S:9266-9277`). What actually happens today:
- an axe on a loose `log` or a shoulder log (ACT_PROCESS → `_process_trunk`, `S:6440`) removes the log;
- it drops 3 blocks on the ground (`structures.json` chopping_block.blocks_per_log 3, blocks_per_shoulder_log 3);
- a pick turns the log into kindling instead.

CONTROLS.md:72 says 4 and 12 blocks, which is stale.

**`activity:medium_fire` and `activity:bonfire`** need a single fire state-change helper that emits `fire_tier` events to the acting peer.

The draft's fire claims are verified:
- min_pieces is 3 (`cooking.json`);
- firewood class → state 1 (medium), log class → state 41 (bonfire) (`S:7345-7365`);
- a hanging pot caps the fire at the firewood tier (`S:7354-7355`, `S:7531`, `S:8378`);
- damp wood holds the fire one tier lower until it dries (`S:7361`, `S:4123-4128`).

Corrections to the draft:
- "3 firewood" should be "3 pieces of the firewood class", which includes wooden blocks and charcoal;
- a laid fire lit with 3 firewood or 3 logs already in it goes straight to that tier on E (`S:7614`);
- for a lit fire, new wood takes effect when the store window closes (`S:1148-1149`, `S:9790-9822`).

Tier changes happen in at least ten places (`S:2460`, `S:4127`, `S:4544`, `S:7440/7443`, `S:7484`, `S:7512`, `S:7548`, `S:7581`, `S:7614`, `S:9819`). The drying, pot-removal and coals ones have no acting peer, so store `last_peer` on the fire. One design question remains: should reaching a bonfire also complete `medium_fire`? I recommend "tier ≥ 2" for medium.

### R-08 MEDIUM: gather goals have no acquisition event
- **Affected goals:** all 20 `gather:*` goals.
- **Evidence:**
  - no acquisition path calls the goal hooks;
  - the only central gain hook, `_report_gains` (`S:4929-4947`), just feeds the client;
  - chest withdrawals are reported as `pickup` (`S:10042-10066`).
- **Fix:**
  - add `got:<item>` counters, fed from `_send_changes`, but only for first-hand sources: pickup, harvest, dig, mine, carcass, crop, fishing;
  - add a container source tag (and keep the existing trade tag excluded);
  - the creator should decide whether bought, looted or chest items count.

### R-09 MEDIUM: one item pays two milestones
- **Cases:**
  - `hammer` accepts `stone_hammer`, which also pays `craft:stone_hammer`;
  - `hoe` accepts `stone_hoe` and `steel_hoe`, which also pay `craft:stone_hoe` and `craft:steel_hoe` (and `iron_hoe` is missing from the list);
  - `workbench` accepts `log_workbench`, which also pays `build:log_workbench`, worth 40 copper;
  - `axe` with `or_have` pays for a bought axe.
- **Data error:** `wooden_hammer_soft` in the hammer list is a recipe id, not an item (`items.json` has no such item).
- **Draft:** line 776 asks for this to be clarified.
- **Fix:**
  - legacy goals should check only their own basic item;
  - each upgrade is paid only by its own goal.

### R-10 MEDIUM: performance (see the section below)

### R-11 MEDIUM: goals are per character, which allows alt-character farming
- **Identity:** `local:<key>`. Account and character are the same thing today (`identity_provider.gd:1-24`).
- **New characters:** every new key, including one made after `forget_key` (`S:593-604`), can earn the whole catalog again: 15,670 copper per character, 2,826 on the main route.
- **Moving coins between characters:** coins can be looted from remains (`S:9948`; anyone may loot from day 2 under death.json).
- **On death:** death keeps `goals_done` and counters but moves the whole purse into the remains (`S:12811-12815`). Real death is off, and there is no heir flow.
- **Decision needed:** this is a creator decision on the economy (per-account caps or accept). It ties into the economic review the draft mentions.

### R-12 LOW: legacy checks that do not match the draft text exactly
- **fell:** felling a tree by digging under it is not counted (`S:3346`).
- **fire:** lighting by fire arrow (`S:2460`) or from coals is not counted; relighting counts again.
- **story:** only Edda counts, any conversation counts, and there is no fire or sitting check.
- **night_walk:** a torch in the pack is enough, and "stumbling" is not checked.
- **bed:** "under cover" is not checked.
- **path:** "camp to water" is not checked.
- **berries:** any food counts.
- **torch_night:** crafting is enough; carrying it at night is not checked.
- **knife:** any knife counts.
- **smoke_fish and dry_berries:** the draft text names the wrong station and ingredients (smoker with fish and sea salt; drying rack).

All per-goal details are in `ws_runtime.json`.

### R-13 LOW: stale metadata and controls text
- `needs_code: true` is wrong for `jerky`, `salted_fish`, `story` and `night_walk`. Recipes exist (cook_jerky, cook_salted_fish, sea_salt), and the code and tests cover story and night_walk.
- Both `_about` notes say the data is "read by nothing yet".
- The old hint "Put sticks on it with F" is out of date: F opens the store (`key_bindings.gd:29`). ACT_FUEL is never sent by the client, and the fire is placed already laid with sticks (`S:3822-3827`).
- **Fire controls, verified:**
  - E lights a laid or warm-ash fire (`inventory_view.gd:855-860` → `S:1134-1139`, `S:7568`), and no starter is needed.
  - Warm ash with a tinder item lights instantly.
  - E on a burning fire puts it out (`S:4563-4577`).
  - `fire_lit` fires only for a laid or ash fire that becomes lit.

### R-14 LOW: admin actions earn goals
ACT_ADMIN_GIVE satisfies possession checks (`S:1232-1241`). Free admin crafts call `_goal_made`. free_build placements fire `placed` (`S:8435`). Admin actions should be excluded, or admin characters flagged.

### R-15 LOW: some completions are not visible to the player
- Each goal finished in the same pass gets its own notice. Per TEST-009 (`S:15778-15779`), only the last one stays on screen. Coins are still paid.
- Batch the lines, or let the placard queue show them.

### R-16 LOW: re-placement and site crediting
- Taking a piece down or picking it up, then placing it again, counts as a new placement. Goals pay once, so there is no money risk. But any build goal with a count above 1 could be met by moving one piece.
- A blueprint site is credited to whoever deposits its last material (`S:8948-8956`), not to the player who placed it.

### R-17 INFO (outside this scope): security note for ws coordinator
The legacy ACT_CRAFT path (`recipe_table.gd:118-136`) skips the station, the craft time and the learned-recipe checks for any client that sends it.

## Migration plan (if the 651-row catalog replaces the 28 goals)

1. **Keep the 28 legacy ids exactly.** The draft does this. These ids live in:
   - `goals_done` in every characters.json row;
   - 14 `hints.json` goal references (drink, fibre, twine, axe, fell, fire, bed, workbench, spear, knife, fish, berries ×2, shelter ×2);
   - `test_goals.gd`.

   Renaming any of them (for example `hammer` to `craft:wooden_hammer`) would pay existing characters again.
2. **Keep the `goal_counts` key formats:** `event:<name>[:<what>]`, `made:<item>`, `hit:<goal>`, `moved_lit_night`. Hints read `event:drink`, `made:stone_axe`, `event:tree_felled`, `made:campfire_kit`, `event:placed:{campfire,lean_to,rough_bed,workbench,log_workbench,campfire_pot}`, `event:fire_lit`, `made:spear` and `event:dug_under` (`S:15408-15473`).
3. **Retroactive credit is a creator decision.** `made:*` and `event:placed:*` have been recorded for every craft and placement since goals shipped (31 Oct 2026), so many `craft:`/`build:` goals would complete on the first check after deploy. Options:
   - (a) pay them, which fits "earlier completion must earn";
   - (b) mark them done without paying, which grandfathers existing characters;
   - (c) pay only main-route goals.

   Actions taken before counters existed, and new kinds (`got:`, `log_chopped`, `fire_tier`), cannot be credited retroactively.
4. **Add `goals_v` to the character row,** as `skills_v` does (`S:18354-18359`). Run the one-time migration on load: changed rewards, the retroactive policy, and dropping `after`. Do the check at join, not on the slow tick, to avoid a payout burst (see performance).
5. **Ids removed from data:** their `goals_done` entries can stay harmlessly. Never reuse a removed id for different content.
6. **Already-done goals keep what they paid.** `twine`/`fell` characters keep their sticks and kindling and are not topped up with copper, unless the creator decides otherwise.
7. **Replace the two legacy files with one canonical goals file,** as the draft says at line 774. The loader in `S:15632` becomes the index builder below. Update `test_goals.gd`: its item-reward and `after` assertions (lines 92-98, 117) change by design.

## Performance

- **Current cost per check.** Every slow tick (4 per second), `_goals_check` runs for every connected peer. It loops over all goals, and all of the work below repeats on every tick:
  - per not-done goal: string allocations from `str(check.get("event"))` (up to 4 per goal), string concatenation for counter keys, and `inventory_of` / `table.number_of`;
  - for `have_item`: a full pack slot scan.
- **Extra full scans.** Every `_goal_event`/`_goal_made` also runs a full synchronous scan: each path patch, sip, placement and craft. Each completion restarts the loop and scans all goals again for the "Next" line.
- **Estimates.** These assume about 3-8 µs per not-done goal in GDScript. They are ESTIMATES and were not measured:

  | Catalog | Players | Per slow tick | CPU per second |
  |---|---|---|---|
  | 28 | 1 | 0.1-0.2 ms | 0.4-0.9 ms |
  | 651 | 1 | 2-5 ms | 8-20 ms |
  | 651 | 8 | 16-40 ms | 64-160 ms |
  | 651 | 32 | 65-170 ms (the slow-tick log budget is 100 ms, `S:68`) | 260-680 ms |

  A migration burst of 100 goals completing for one character costs about 100 × 651 × 2 checks, roughly 0.2-0.6 s on the main thread.
- **Measured data.** The existing slow-tick split (`S:15818-15822`, `_goals_detail`) already reports goal time, so it can measure this. A lag run on 5 Nov logged 43-102 ms for goals and hints combined, before the split.
- **Recommended design (not implemented): index goals by event.**
  1. **At load, compile index maps:**
     - `by_counter["event:placed:lean_to"] → [goal idx]`;
     - `by_counter["made:twine"]`;
     - `by_counter["got:stone"]`;
     - `by_counter["event:fire_tier:3"]`;
     - a short `continuous` list (`worn_warmth`, `moved_lit_night`).

     Pre-convert item ids to numbers and pre-build counter key strings.
  2. **On an event or a craft,** bump the counter, then test only the goals listed under that key (usually 1-3). Cost becomes O(1) instead of O(651).
  3. **On the slow tick,** test only the continuous goals for each peer. If possession checks remain, test them only for item numbers that just changed in `_send_changes`.
  4. **At join (and after a data or version change),** run one full catch-up pass for that character.
  5. **With no `after` gating,** there is no unlock cascade. The "Next" text comes from the display order, computed only for the notice.

  Expected cost: well under 0.1 ms per event and tick per player, regardless of catalog size.
