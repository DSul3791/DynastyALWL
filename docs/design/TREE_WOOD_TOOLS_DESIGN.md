# Dynasty — Trees, wood, starter tools, carving and hauling

**Current design, 15 November 2026. The one authoritative document for this topic.** It consolidates Dave's confirmed design from the creator handoff (PR #1147, `docs/ideas/TREE_WOOD_TOOLS_CREATOR_HANDOFF_2026-11-14.md`, which retires once this file and the documents in s7 carry it) and records how the game implements it. Item identities stay in [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md); this file wins on how trees, wood, the starter toolkit, the Wood Carving Station, the knife menu and hauling work. Older rules that conflict with it were removed from the official documents in the same change (old text is in Git history).

Labels: **[DAVE]** confirmed by Dave in the handoff (15 Nov 2026 review) or his later messages; **[DELEGATED]** an engineering/balance value chosen within delegated authority (`docs/ai-team/DECISION_AUTHORITY.md` level A/B), tunable; **[FOR DAVE]** a frozen catalog choice (item row, name, recipe, blueprint cost, recipe move) that waits for Dave in s6 and is not written into live data until he answers.

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
- Journey: stone, sticks, fibre → Stone Axe, Hammer, Knife → small-tree Firewood and large-tree logs → campfire charcoal and copper ore (Stone Hammer) → Primitive Smelter and Smithy → Copper saw → blocks, planks, boards → Wood Carving Station, sawbuck, woodworking.

### 1.6 Wood Carving Station
- Cost exactly **two Wooden Blocks**; placed from the knife menu. Look: one upright carving block and one block with a worn seat, sawdust and shavings around (decorative knives may lie about; they give no usable tool).
- Opens the normal station crafting window. Materials come from the station, the character's pack or nearby ground (and eligible nearby storage under the existing sourcing rules).
- Carving recipes need a **knife in the character's inventory** as a kept tool (not consumed); the Stone Knife counts. The knife wears by its normal durability rules.
- The **Longbow** is made here from logs and Twine (no Wooden Block, no stave item, no partial logs).
- It is separate from the Chopping Block (firewood).

### 1.7 Simple furnishings
- Knife-placed **log bench**, single and double: a thick half-log slab seat with a flat top and rough edge on two short round log sections laid on their sides, set in from the ends (Dave's reference picture, 15 Nov 2026: `art/references/wood_system_2026-11-15/log_bench_reference.png`; "That would be the single version, and then you could simply make it longer to be the double version"). Made of existing logs/blocks; no split-log material.
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
| Chopping Block station | Log → 12 species firewood (recipes 720, 721). | Wooden Block → Firewood, faster than by hand; the log recipes retire (blocks only come from sawing). |
| Saws | Iron saw (Improved Smithy) and Steel saw; hand-saw recipes for Planks/Boards. | Copper saw first (Primitive Smithy), then Bronze, Iron, Steel; each saws blocks, planks and boards, better saws faster. |
| Stone pickaxe | Required for stone, copper, tin and coal. | The Stone Hammer harvests them. The Stone Pickaxe recipe retires; saved Stone Pickaxes keep working. Metal picks stay (iron ore needs a bronze or better pick). |
| Hammer | Repair mode, Save plan, blueprints. | Repair mode becomes "Hammer/Repair Tool" and also harvests rock and ore. |
| Knife | Carcass work, recipes keep it. | Right click opens the knife blueprint menu. |
| Carving | Bowls, platters, clubs, quarterstaff by hand from a block; longbow at the workbench from a large block. | Wood Carving Station (s6 rows for which recipes move). |
| Vehicles | Handcart exists (`server_carts.gd`, 12 slots, 300 kg); other vehicles are future rows. | Handcart takes logs and the s1.2 loads; Small log sled and Small wagon use the same hand-pulled controller. Medium and Large wait for animal keeping (s6). |

## 3. Phases (each a reviewed PR into `dev`)

1. **Documents** (this file, s7 reconciliations, the s6 table). No game change.
2. **Materials and tools:** unified Firewood and Wooden Block with save conversion; Stone Hammer harvesting and the "Hammer/Repair Tool" mode; axe splits blocks; log-on-ground axe route removed; saw speeds by material; Copper/Bronze saws and saw-made blocks once s6 rows are answered.
3. **Trees and logs:** small-tree threshold and Firewood; two-log carrying with tools stowed; rolling logs.
4. **Carving and knife menu:** sawbuck, Wood Carving Station, recipe moves, knife blueprint menu, log benches and table.
5. **Hauling:** Handcart loads and logs; Small log sled and Small wagon. Medium/Large after animal keeping.

Godot tests run only on Dave's machines through the coordinator's test lanes; each phase is reported with its exact SHA, the tests run and NOT RUN, and the F6 checks Dave still has to do. Nothing here is a completed playable system until played.

## 4. Saves [DELEGATED under `CATALOG_SAVE_MIGRATION.md`]

Supported: worlds and characters saved by dev 40bea035 or later. Retired wood rows load through `data/items/renames.json` wherever saved items are read (packs, chests, station stores, ground items, worn slots, hotbar keys): `firewood_soft` → 1 `firewood`; `wooden_block_soft` → 1 `wooden_block`; `wooden_block_large` and `wooden_block_soft_large` → **4** `wooden_block` each (the old large-to-small recipes 339/340 gave 4, so the wood is the same). A craft queue holding a retired recipe refunds its inputs. Item numbers are never reused.

## 5. Engineering values [DELEGATED, tunable]

| Value | Setting | Why |
|---|---|---|
| Log weight | Hardwood 22 kg, softwood 18 kg, light (birch) 15 kg, plain Log 18 kg | A 75 kg character carries 52.5 kg; two hardwood logs (44 kg) plus axe, hammer, knife, food and water (about 5 kg) fit. Planks (6 × 3 kg) and boards (4 × 4 kg) stay no heavier than their log. |
| Wooden Block weight | 3.0 kg | Six per log. |
| Firewood weight | 1.5 kg | Two per block. |
| Small tree | Felled length under 8 m, or drawn butt radius under 0.12 m | Saplings, young trees and most fruit trees give Firewood; full-grown timber gives logs. |
| Small-tree Firewood | 2 per metre of trunk, 2 to 14 | The largest small tree gives 14 (21 kg), carryable with the toolkit. |
| Saw speed (× the old hand-saw time) | Copper 0.5, Bronze 0.75, Iron 1.0, Steel 1.25; a sawbuck doubles block cutting | "Slow but tolerable"; upgrade incentive by speed, not yield. |
| Hammer on rock (stones per blow) | Stone 1 (the old stone pick), Copper and Bronze 1.5, Iron and Steel 2; picks keep their higher rates and stay the only tool for iron ore | The hammer takes over the starter role without making picks pointless. |
| Rolling | A log on ground steeper than 0.35 across its length rolls downhill at up to 3 m/s, stops on flatter ground, water or a structure | Plausible without full physics. |

## 6. For Dave (catalog choices; batched; not in live data until answered)

Assumed values are proposals only. Phase work that does not depend on a row continues.

| # | Choice | Proposal | Blocks |
|---|---|---|---|
| W-1 | Copper saw row | New item "Copper - Saw" (tool, saw, copper). Recipe: 2 Copper ingot + 2 Stick at the Primitive Smithy. | First blocks |
| W-2 | Bronze saw row | New item "Bronze - Saw": 2 Bronze ingot + 2 Stick at the Primitive Smithy. Iron and Steel saws keep their recipes. | Bronze upgrade |
| W-3 | Blocks per log | 6 Wooden Blocks per 3 m log, any species, hand-saw recipe (keeps any saw) and a faster Sawbuck recipe. Each block splits into 2 Firewood (log → 12 Firewood, as the Chopping Block gives now). | First blocks |
| W-4 | Sawbuck | New structure "Sawbuck", hammer blueprint: 4 Planks + 8 Nails. | Sawbuck |
| W-5 | Chopping Block | Cost 4 Wooden Blocks (the old 1 large block). Its recipe becomes 1 Wooden Block → 2 Firewood (keeps an axe), faster than splitting by hand; log → firewood recipes 720 and 721 retire. | Firewood station |
| W-6 | Wood Carving Station | New structure "Wood carving station", knife blueprint, 2 Wooden Blocks (Dave's cost). | — (cost is Dave's) |
| W-7 | Recipes that move to the carving station (each keeps a knife, same ingredients) | Wooden bowl (1 block), Serving platter (2 blocks), Quarterstaff (1 block), Wooden club (1 block), Wooden hammer (1 block + 1 stick + 1 twine; duplicate soft recipe 232 retires). Spyglass and crossbows stay where they are. | Carving |
| W-8 | Longbow | 1 Log (any) + 1 Sinew + 2 Twine, keeps a knife, at the carving station (was 1 large block + 1 sinew + 2 twine at the workbench). | Longbow |
| W-9 | Knife menu (moves out of the hammer menu) | Seat, Log bench single and double, Log table, Stool, Wood carving station, Chopping block, Drying rack, Tool rack, Firewood rack, Log rack, Tanning rack, Tailor's table, Food preparation table, Wicker chest, Basket, and the Crude grade wood-only furniture (Crude chair, table, bench, shelf, chest). Walls, floors, roofs, fences, doors, stairs, pipes and garden pieces stay with the hammer. | Knife menu |
| W-10 | Log benches | Single = existing "Log - Bench" (629, its retired blueprint 88 returns), 1.2 m, seats one, cost 1 Log. Double = new "Log - Double bench", 2.2 m, seats two, cost 2 Logs. | Benches |
| W-11 | Log table | Existing "Log - Table" (631, blueprint 89 returns) at its old cost, 3 Logs + 2 Twine, knife menu. | Log table |
| W-12 | Stone pickaxe | Retire recipe 186 (no longer craftable); keep item 297 so saved ones load and still work. Copper pickaxe and the metal picks stay. | Starter tools |
| W-13 | Unified names | "Firewood" (26) and "Wooden block" (234); the other four wood rows retire (s4). | Phase 2 |
| W-14 | Hauling rows | Small log sled (new, hand-pulled): 2 Logs + 6 Sticks + 4 Twine, hammer blueprint, pre-saw. Small wagon (new, hand-pulled): 8 Planks + 4 Wooden cart wheels + 2 Axles + 16 Wooden pins. Medium log sled = existing Cargo sled (1194), Medium wagon = existing Light cargo cart (1192), Large log sled new, Large wagon = existing Timber wagon (1196); Farm, covered, traveller's wagons, gig, carriage and sleigh unchanged. Medium and Large wait for animal keeping (your 12 Nov ruling). | Hauling |
| W-15 | Handcart load | Handcart limit 300 kg → 120 kg (about three small trees' Firewood, one barrel, or two to five logs). | Handcart |
| W-16 | Sled surfaces | Small log sled works on any ground, slower on bare rock, gravel and road, faster on snow and wet grass. | Sled |

## 7. Documents reconciled with this design
`DYNASTY_MASTER_ITEMS.md` (s2.1 to s2.4, s2.6, s3.1, s3.2, s3.11), `item_system.md`, `progression.md`, `buildables_plan.md`, `STORAGE_WAREHOUSING_DESIGN.md`, `PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md`, `CATALOG_IMPLEMENTATION_PLAN.md`, `CATALOG_SAVE_MIGRATION.md`, `docs/DOC_MAP.md`, `CONTROLS.md`. Mission checkpoint: `docs/ai-team/missions/WOOD-SYSTEM/STATE.md`.
