# Dynasty — Trees, wood, starter tools, carving and hauling

**Current design, 15 November 2026. The one authoritative document for this topic.** It consolidates Dave's confirmed design from the creator handoff (PR #1147, `docs/ideas/TREE_WOOD_TOOLS_CREATOR_HANDOFF_2026-11-14.md`, which retires once this file and the documents in s7 carry it) and records how the game implements it. Item identities stay in [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md); this file wins on how trees, wood, the starter toolkit, the Wood Carving Station, the knife menu and hauling work. Older rules that conflict with it were removed from the official documents in the same change (old text is in Git history).

Labels: **[DAVE]** confirmed by Dave in the handoff (15 Nov 2026 review) or his later messages; **[DELEGATED]** an engineering/balance value chosen within delegated authority (`docs/ai-team/DECISION_AUTHORITY.md` level A/B), tunable; **[FOR DAVE]** a catalog choice (item row, name, recipe, blueprint cost, recipe move) listed in s6; Dave answered some directly and adopted the rest as provisional values to adjust after play.

## 1. Confirmed design [DAVE]

### 1.1 Felling and materials
- Trees physically fall. A **large** tree separates by itself into collectible logs when it lands; there is no second chopping stage.
- Logs are physical world objects that can roll on terrain.
- A **small** tree falls and breaks directly into 0.5 m **Firewood** (early fuel without a saw).
- **One Firewood** material (no hard/soft) and **one Wooden Block** material (no large/small, no softwood/hardwood), each one item id.
- Softwood and hardwood **log** identities stay (with species), because their sawn outputs differ: one softwood/basic 3 m log makes **6 Planks**, one hardwood 3 m log makes **4 Hardwood Boards**, with no substitution either way.
- Every felled tree still drops its 1 to 5 "<Tree> seed" (Dave 14 Nov 2026); fruit and nuts are just food.

### 1.2 Carrying and hauling
- A character visibly carries **up to two logs** at once; an average character carries two with ordinary equipment and supplies (axe, food, water).
- The whole Firewood yield of one small tree is carryable by an average character with an axe, food and water.
- Logs can be carried home or loaded onto a log sled, the Handcart or a wagon.
- **Handcart:** hand-operated only, small, light, simple. Practical loads (alternatives, not cumulative): about three small trees' Firewood, one barrel, or a load of carrots.
- **Log sled and Wagon each come Small / Medium / Large:** Small pulled by hand; Medium needs one horse; Large needs one ox or two horses. The log sled is for hauling wood. Sled surfaces are not settled (s6).
- No wheelbarrow.

### 1.3 Sawing
- A hand saw cuts a log into **Wooden Blocks** on the ground (slow but possible without a sawbuck), and into Planks or Hardwood Boards on the ground.
- **Sawbuck:** built from Planks and Nails; speeds up cutting logs into Wooden Blocks.
- **Sawmill** speeds up Planks and Hardwood Boards. Better saws and the mill are faster; the 6 / 4 yields never change.
- Wooden Blocks are the step from a large-tree log to Firewood. Hand sawing must stay tolerable for small jobs.

### 1.4 Starter tools and the hammer
- **Stone Axe first, Stone Hammer second, Stone Knife** completes the toolkit. No artificial order lock.
- The Stone Hammer takes over early stone and ore harvesting from the Stone Pickaxe, which is no longer a required step.
- The hammer's top menu option is **"Hammer/Repair Tool"**: *"Repair structures, place blueprints, or harvest stone and ore."* Hitting a structure repairs it, hitting a rock or ore harvests it within the tool's capability; blueprint placement stays in the menu. A failed or unneeded repair never damages the structure; it says what is missing or "No repair needed". Any ordinary hammer repairs; War Hammers never do.
- **Right click with a knife in hand** opens the knife's blueprint menu: simple furnishings and stations made only of wood, or wood and twine. They leave the hammer menu. Structural house pieces stay with the hammer. Normal previews, rotation, sourcing and placement checks apply; the knife does not create sawn materials.

### 1.5 First saw: Copper
- The **Copper saw** is the first saw, made at the **Primitive Smithy** from smelted copper and a wooden handle; its recipe needs no Wooden Blocks, Planks, Hardwood Boards or other saw. Bronze, Iron and Steel saws are later upgrades. The old "no Bronze saw" and "first boards need the Iron Saw" rules are gone.
- Primitive Smelter and Primitive Smithy stay buildable with stone-stage resources and tools (no metal, nails or sawn wood). Early Firewood feeds campfire charcoal before the first metal; Coal and Charcoal stay distinct.
- Journey (our summary of the points above, not a quote): stone, sticks, fibre → Stone Axe, Hammer, Knife → small-tree Firewood and large-tree logs → campfire charcoal and copper ore (Stone Hammer) → Primitive Smelter and Smithy → Copper saw → blocks, planks, boards → Wood Carving Station, sawbuck, woodworking.

### 1.6 Wood Carving Station
- Cost exactly **two Wooden Blocks**; placed from the knife menu. Look: one upright carving block and one block with a worn seat, sawdust and shavings around (decorative knives may lie about; they give no usable tool).
- Opens the normal station crafting window. Materials come from the station, the character's pack or nearby ground (and eligible nearby storage under the existing sourcing rules).
- Carving recipes need a **knife in the character's inventory** as a kept tool (not consumed); the Stone Knife counts. The knife wears by its normal durability rules [DELEGATED, not Dave's wording].
- The **Longbow** is made here from logs and Twine (no Wooden Block, no stave item, no partial logs).
- It is separate from the Chopping Block (firewood); the model shows a bench beside a chopping block, look only.

### 1.7 Simple furnishings
- Knife-placed **log bench**, single and double: a thick half-log slab seat with a flat top and rough edge on two short round log sections laid on their sides, set in from the ends (Dave's reference picture, 15 Nov 2026: `art/references/wood_system_2026-11-15/log_bench_reference.png`; "That would be the single version, and then you could simply make it longer to be the double version"). Made of existing logs/blocks; no split-log material.
- A second bench with a backrest (Dave's design sheet, 15 Nov 2026: `art/references/wood_system_2026-11-15/log_bench_with_backrest_design.png`) so several seats can stand round a fire; row and cost W-17.
- Block seats, log tables and eligible wooden stations form the knife menu.

## 2. What the game did before this change (dev 40bea035) and what changes

| Area | Before | Now |
|---|---|---|
| Felling | Already physical: a tree falls (`_fell_record`), lands, splits by itself into 3 m species logs (`split_trunk`); a trunk under 3 m breaks into firewood, kindling and sticks (`_split_small`). Crown litter, bark, seeds as drops. | Kept. The small-tree rule changes from "shorter than one log" to the s5 threshold, and small trees give Firewood (unified), not species firewood. |
| Logs on the ground | Static loose items. | They roll downhill and settle (server, s5). |
| Carrying | One shoulder log at a time (`_give_shoulder`). | Up to two; a third is refused; tools are put away while carrying. |
| Axe on a loose log | 3 blocks (large blocks from a shoulder log). | Removed. An axe splits a **Wooden Block** into Firewood anywhere; the Chopping Block does it faster. |
| Blocks | `wooden_block`, `wooden_block_soft`, `wooden_block_large`, `wooden_block_soft_large`. | One `wooden_block` (234), "Wooden block". The other three retire (numbers kept; saved stacks convert, s4). |
| Firewood | `firewood` (Hard), `firewood_soft`. | One `firewood` (26), "Firewood". `firewood_soft` (236) retires and converts 1:1. |
| Chopping Block station | Recipes 720 and 721 (log → 12 species firewood) are already retired on dev and inert; the live block already splits Wooden Blocks. | Costs 1 Wooden Block; Wooden Block → 4 Firewood, faster than by hand, drawing blocks from pack, ground, cart or containers in reach; recipes 720 and 721 stay retired (blocks only come from sawing). |
| Saws | Iron saw (legacy brick forge) and Steel saw (brick forge level 3); hand-saw recipes for Planks (6) and Hardwood boards (4). | Copper saw first (Primitive Smithy), then Bronze, Iron, Steel; each saws blocks, planks and boards, better saws faster. |
| Stone pickaxe | Required for copper, tin and coal ore (a stone axe already breaks plain boulders at 0.5 stones a blow). | The Stone Hammer harvests them. The Stone Pickaxe recipe retires; saved Stone Pickaxes keep working. Metal picks stay (iron ore needs a bronze or better pick). |
| Hammer | Repair mode, Save plan, blueprints. | Repair mode becomes "Hammer/Repair Tool" and also harvests rock and ore. |
| Knife | Carcass work, recipes keep it. | Right click opens the knife blueprint menu. |
| Carving | Bowls, platters, clubs, quarterstaff by hand from a block; longbow at the workbench from a large block. | Wood Carving Station (s6 rows for which recipes move). |
| Vehicles | Handcart exists (`server_carts.gd`, 12 slots, 300 kg); other vehicles are future rows. | Handcart takes logs and the s1.2 loads; Small log sled and Small wagon use the same hand-pulled controller. Medium and Large wait for animal keeping (s6). |

## 3. Phases (each a reviewed PR into `dev`)

1. **Documents** (this file, s7 reconciliations, the s6 table). No game change.
2. **Materials and tools:** unified Firewood and Wooden Block with save conversion; Stone Hammer harvesting and the "Hammer/Repair Tool" mode; axe splits blocks; log-on-ground axe route removed; saw speeds by material; Copper/Bronze saws and saw-made blocks per the adopted s6 rows.
3. **Trees and logs:** small-tree threshold and Firewood; two-log carrying with tools stowed; rolling logs.
4. **Carving and knife menu:** sawbuck, Wood Carving Station, recipe moves, knife blueprint menu, log benches and table.
5. **Hauling:** Handcart loads and logs; Small log sled and Small wagon. Medium/Large after animal keeping.

Godot tests run only on Dave's machines through the coordinator's test lanes; each phase is reported with its exact SHA, the tests run and NOT RUN, and the F6 checks Dave still has to do. Nothing here is a completed playable system until played.

## 4. Saves [DELEGATED under `CATALOG_SAVE_MIGRATION.md`]

Supported: worlds and characters saved by dev 40bea035 or later. Retired wood rows load through `data/items/renames.json` wherever saved items are read (packs, chests, station stores, ground items, worn slots, hotbar keys): `firewood_soft` → 1 `firewood`; `wooden_block_soft` → 1 `wooden_block`; `wooden_block_large` and `wooden_block_soft_large` → **4** `wooden_block` each (the old large-to-small recipes 339/340 gave 4, so the wood is the same). A craft queue holding a retired recipe refunds its inputs. Item numbers are never reused.

## 5. Engineering values [DELEGATED, tunable]

| Value | Setting | Why |
|---|---|---|
| Log weight | Hardwood 22 kg, softwood 18 kg, light (birch) 15 kg, plain Log 18 kg (live in `weights.json` since phase 3: the 25 species logs, by their old 45 / 32 / 26 kg groups) | A 75 kg character carries 52.5 kg (0.7 × body); two hardwood logs (44 kg) plus Stone Axe, Stone Hammer, Stone Knife, 2 L of water and a day's bread (6.6 kg) come to 50.6 kg and fit (`test_wood_phase3.gd` checks it with the real `give`). No lowering was needed. Planks (6 × 3 kg) and boards (4 × 4 kg) stay no heavier than their log except birch: 6 Planks weigh 18 kg against its 15 kg, kept as designed. |
| Logs carried | Two (`weights.json` `shoulder_logs_max`); a third is refused with "You can carry two logs at most. Put one down first (Q)."; Q lays one down at a time; tool swings are refused while any log is carried | Dave 15 Nov 2026 (s1.2). The client counts the logs in its own pack, so the carry message (protocol 64) is unchanged. |
| Wooden Block weight | 3.0 kg | Six per log. |
| Firewood weight | 0.75 kg | Four per block (W-3). |
| Small tree | Felled length under 8 m, or drawn butt radius under 0.12 m | Saplings, young trees and most fruit trees give Firewood; full-grown timber gives logs. |
| Small-tree Firewood | 3 per metre of trunk, rounded, 2 to 24 (`drops.json` `trunk.small_tree`, with the 8 m and 0.12 m thresholds; the old 2 to 3 Firewood a small blow is gone, kindling and sticks stay) | The largest small tree gives 24 (18 kg), carryable with the toolkit (`test_wood_phase3.gd`: 24 Firewood plus gear is 24.6 kg); a full 3 m log gives 24 through blocks. Hand cutting a small trunk gives the same total over its small blows. |
| Saw speed (× the old hand-saw time) | Copper 0.5, Bronze 0.75, Iron 1.0, Steel 1.25; a sawbuck doubles block cutting | "Slow but tolerable"; upgrade incentive by speed, not yield. |
| Hammer on rock (stones per blow) | Stone 1 (the old stone pick), a Wooden hammer does not break rock, Bronze 1.5, Iron and Steel 2 (the hammer ladder in master s2.1 has no Copper hammer); picks keep their higher rates and stay the only tool for iron ore | The hammer takes over the starter role without making picks pointless. |
| Rolling | A loose log (shoulder log or plain Log) on ground steeper than 0.35 across its length (read over 0.4 m either side of it, from its turn) rolls downhill, gaining 2 m/s² up to 3 m/s, and stops on flatter ground, in water deeper than 5 cm, at a wall, or after 60 m, and only while it lies within 0.5 m of the ground (`rest_m`: not on a floor, a deck or a rock) (`drops.json` `rolling`) | Plausible without full physics. Server: only a log just dropped, split or moved is checked, then it sleeps; a log with no turn of its own (laid down with Q, dropped from the pack) is given one from its id when it wakes, and the first row sent carries it, so the client draws the log the way it rolls (the player does not choose it); its position is saved; players who see it are told 10 times a second (`items_moved`) and their client glides it. Limits (a `shortcut:` in `server_items.gd`): the height field does not know saved digs and fills, and a log does not stop against trees, boulders or other logs. |

## 6. For Dave (catalog choices)

Dave answered W-3, W-4, W-5 and part of W-8 directly (15 Nov 2026 06:18Z). For every other row he said (06:19Z): **"Just make them reasonable and we can adjust them later."** So each remaining proposal below is **ADOPTED, PROVISIONAL**: it goes into live data as written and stays open for Dave to adjust after playing.

| # | Choice | Proposal | Blocks |
|---|---|---|---|
| W-1 | Copper saw row | New item "Copper - Saw" (tool, saw, copper). Recipe: 2 Copper ingot + 2 Stick at the Primitive Smithy. | First blocks |
| W-2 | Bronze saw row | New item "Bronze - Saw": 2 Bronze ingot + 2 Stick at the Primitive Smithy. Iron and Steel saws keep their recipes. | Bronze upgrade |
| W-3 | Blocks per log | **ANSWERED (Dave, 15 Nov 2026 06:18Z): "Six wooden blocks per log each splitting into four firewood each."** A saw cuts a log (any species) into 6 Wooden Blocks; each splits into 4 Firewood (a log → 24 Firewood). | — |
| W-4 | Sawbuck | **ANSWERED (Dave, 06:18Z): "The sawbuck requires eight planks and at least 16 nails."** New structure "Sawbuck", 8 Planks + 16 Nails (placed from the hammer menu: it has nails, so not the knife menu). | — |
| W-5 | Chopping Block | **ANSWERED (Dave, 06:18Z): "chopping block cost one block and yes, the chopping block just allows you to cut blocks into firewood, and it will pick up blocks from the ground or from a cart or from any container around you or your inventory."** Cost 1 Wooden Block. Its only job: Wooden Block → 4 Firewood (axe kept), drawing blocks from the pack, the ground, a cart or any container in reach (the existing craft-stock sourcing and its permissions); log → firewood recipes 720 and 721 stay retired. | — |
| W-6 | Wood Carving Station | New structure "Wood carving station", knife blueprint, 2 Wooden Blocks (Dave 15 Nov 06:20Z: "only needs two blocks one to sit on and want to use like a little table"). Model (Dave, same message): looks like the new log bench sitting next to a chopping block, with wood shavings all over the ground around it. Dave 06:21Z: "all it's going to require is two blocks. But when it makes it, it's gonna look like a bench next to a chopping block with wood shavings on the ground." The cost is exactly 2 blocks; the bench is only the look. | — (cost and look are Dave's) |
| W-7 | Recipes that move to the carving station (each keeps a knife, same ingredients) | Wooden bowl (1 block), Serving platter (2 blocks), Quarterstaff (1 block), Wooden club (1 block), Wooden hammer (1 block + 1 stick + 1 twine; duplicate soft recipe 232 retires). Spyglass and crossbows stay where they are. | Carving |
| W-8 | Bows: a ladder (Dave, 06:18Z: "we should have a short bow and a primitive bow ... They should be options so people can build their way up.") | Three rungs, all at the carving station keeping a knife unless said: **Primitive bow** (new item; weakest, short range, wears out fast like other primitive gear): 2 Sticks + 2 Plant fibre, a hand craft (no station), so it comes before any saw. **Shortbow** (existing 269, today 2 Sticks + 3 Twine at the workbench): 1 Wooden Block + 2 Twine at the carving station. **Longbow** (existing 763): 1 Log (any) + 3 Twine (Dave's "logs and Twine", no other input; was 1 large block + 1 Sinew + 2 Twine). Strength by `bow.json` multipliers: Primitive 0.7 speed / 0.7 damage / 0.6 range, Shortbow as now (1.0), Longbow as now. Built in phase 4 (15 Nov 2026): recipes 170 (Shortbow), 357 (Longbow) and the new 729 (Primitive bow); the Longbow's old workbench level and Sinew are gone. | Bows |
| W-9 | Knife menu (moves out of the hammer menu) | Seat, Log bench single and double, Log table, Stool, Wood carving station, Chopping block, Drying rack, Tool rack, Firewood rack, Log rack, Tanning rack, Tailor's table, Food preparation table, Wicker chest, Basket, and the Crude grade wood-only furniture (Crude chair, table, bench, shelf, chest). Walls, floors, roofs, fences, doors, stairs, pipes and garden pieces stay with the hammer. | Knife menu |
| W-10 | Log benches | Single = existing "Log - Bench" (629, its retired blueprint 88 returns), 1.2 m, seats one, cost 1 Log. Double = new "Log - Double bench", 2.2 m, seats two, cost 2 Logs. | Benches |
| W-17 | Log bench with a backrest (Dave's design sheet, 15 Nov 2026: `art/references/wood_system_2026-11-15/log_bench_with_backrest_design.png`) | New item "Log - Backed bench", knife menu: live-edge slab seat about 1.5 m long and 45 cm high on two half-log bases, live-edge backrest on two round log posts leaning slightly back, about 90 cm tall; seats two; cost 3 Logs + 2 Twine. | Backed bench |
| W-18 | Starter "hammer" goal (data/items/starter_goals.json) | Assumed on Dave's behalf while he slept (15 Nov 2026, phase 2 review): the goal becomes "Make a Stone - Hammer" and counts a made or held Stone or Wooden hammer, because a Wooden hammer now needs a sawn block (after the Copper saw) and s1.4 makes the Stone Hammer the second tool. Coin reward unchanged. Also assumed: the Sawbuck speeds only sawing logs into Wooden blocks (s1.3), not Planks or Boards (the Sawmill does those). | ADOPTED, PROVISIONAL |
| W-19 | Phase 3 values (small trees, two logs, rolling) | Assumed on Dave's behalf while he slept (15 Nov 2026, phase 3): the s5 small-tree, log-weight and rolling values above. In detail: small-tree Firewood is 3 per metre rounded, 2 to 24. Log weights are not cut, because two hardwood logs plus the starter kit come to 50.6 kg, under the 52.5 kg limit. Birch (15 kg) stays lighter than its 6 Planks (18 kg). A laid-down log's turn is chosen by the game, so on a steep slope it may roll. Other players do not see the second carried log yet. Rolling logs in old saves are not woken on load. | ADOPTED, PROVISIONAL |
| W-11 | Log table | Existing "Log - Table" (631, blueprint 89 returns) at its old cost, 3 Logs + 2 Twine, knife menu. | Log table |
| W-12 | Stone pickaxe | Retire recipe 186 (no longer craftable); keep item 297 so saved ones load and still work. Copper pickaxe and the metal picks stay. | Starter tools |
| W-13 | Unified names | "Firewood" (26) and "Wooden block" (234); the other four wood rows retire (s4). | Phase 2 |
| W-14 | Hauling rows | Small log sled (new, hand-pulled): 2 Logs + 6 Sticks + 4 Twine, hammer blueprint, pre-saw. Small wagon (new, hand-pulled): 8 Planks + 4 Wooden cart wheels + 2 Axles + 16 Wooden pins. Medium log sled = existing Cargo sled (1194), Medium wagon = existing Light cargo cart (1192), Large log sled new, Large wagon = existing Timber wagon (1196); Farm, covered, traveller's wagons, gig, carriage and sleigh unchanged. Medium and Large wait for animal keeping (your 12 Nov ruling). | Hauling |
| W-15 | Handcart load | Handcart limit 300 kg → 120 kg (about three small trees' Firewood, one barrel, or two to five logs). | Handcart |
| W-16 | Sled surfaces | Small log sled works on any ground, slower on bare rock, gravel and road, faster on snow and wet grass. | Sled |
| W-19 | Phase 4 build values (15 Nov 2026) | **Assumed on Dave's behalf while he slept**, [DELEGATED] and tunable: the Wood carving station is 1.9 x 1.1 m, blocks walking, reach 3.0 m (it serves a crafter within 4 m), at most 4 a chunk; its look is the 1.2 m slab bench at one end, a chopping block at the other and 24 shavings on the ground, about 260 triangles (placeholder quality). The Primitive bow: tier 1, durability 150, value 8, weight 0.6 kg, 10 s to make; its look is a placeholder bow of the Shortbow's shape. The moved recipes keep their craft times. | ADOPTED, PROVISIONAL |
| W-20 | Phase 4 knife menu (15 Nov 2026) | **Assumed on Dave's behalf**: right click with a knife (or R) opens the same window as the hammer's, titled Knife, listing blueprint rows with `"tool": "knife"` in `blueprints.json`; the hammer's list no longer shows them (hammer list 228 to 212 rows, knife list 21). The knife list starts on a plain "Knife" line so a knife taken back to a carcass can drop its pick, has no Repair or Save line and no saved plans. The server refuses a knife row without a knife in the hand bar and a hammer row without a hammer, each with its own message; free-build admin is unchanged. A knife builds every row of its list (no tier). Mapping of W-9: Seat is Log - Seat, Chopping block stays a by-hand placeable (it is no blueprint), Basket is Wicker - Basket, Wicker chest is Wicker - Chest, and the Crude bench and Crude shelf are the existing Bench and Wooden shelf rows (there is no separate Crude grade bench or shelf blueprint). Also moved: Stool, Crude chair, Crude table, Crude chest, Drying rack, Tool rack, Firewood rack, Log rack, Tanning rack, Tailor's table, Food preparation table. | ADOPTED, PROVISIONAL |
| W-21 | Phase 4 benches (15 Nov 2026) | **Assumed on Dave's behalf**: Log - Bench 1.2 x 0.45 m (state 123, blueprint 88 back), Log - Double bench 2.2 x 0.45 m (new state 444, blueprint 354), Log - Backed bench 1.5 x 0.6 m (new state 445, blueprint 355), Log - Table 1.4 x 0.7 m (state 124, blueprint 89 back). Seats are on the long axis, 0.45 m up: one for the single bench, two 1.0 m apart for the double, two 0.7 m apart for the backed one (sat from the front, its back at the rear); the single and double are sat from either side. Costs as W-10, W-11 and W-17 (single 1 Log, double 2 Logs, backed 3 Logs + 2 Twine, table 3 Logs + 2 Twine). The old 2.0 m "Log - Bench" look is replaced. | ADOPTED, PROVISIONAL |
| W-22 | Carving does not wear the knife (15 Nov 2026) | Section 1.6 says the knife "wears by its normal durability rules". The game's kept-tool recipes do not wear what they keep (only recipes with `wears_tool` do), so carving keeps the knife whole like every other knife recipe; no `wears_tool` was added. Say if carving should wear it. | ADOPTED, PROVISIONAL |

## 7. Documents reconciled with this design
`DYNASTY_MASTER_ITEMS.md` (s2.1 to s2.4, s2.6, s3.1, s3.2, s3.11), `item_system.md`, `progression.md`, `buildables_plan.md`, `STORAGE_WAREHOUSING_DESIGN.md`, `PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md`, `CATALOG_IMPLEMENTATION_PLAN.md`, `CATALOG_SAVE_MIGRATION.md`, `docs/DOC_MAP.md`, `PLAYER_JOURNAL_GOALS_UI.md`, `PLAYER_GOALS_REWARDS_DRAFT.md`, `PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md`, `wood_tier_note.md`, `PLUMBING_DESIGN.md`, `PLAYER_GOALS_CATALOG_CORRECTED.md` (banner). `CONTROLS.md` describes live controls and changes with the phase 2 and 3 code. Mission checkpoint: `docs/ai-team/missions/WOOD-SYSTEM/STATE.md`.
