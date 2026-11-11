# Dynasty master items catalog

**Status: DRAFT 2 FOR DAVE'S REVIEW (11 Nov 2026). Documentation only.** Nothing in `data/items/*.json`, `data/npcs/*.json` or the game code has been changed. The item catalog is frozen (Dave, 11 Nov 2026): this document reconciles and flags; it does not add, remove, rename or redesign anything by itself. No JSON or gameplay change follows from it until Dave approves this corrected catalog.

Draft 2 applies the review on PR #1035 (review 5866741315, posted from Dave's account `DSul3791`, 11 Nov 2026 23:31Z), which transcribes Dave's 11 Nov design conversation. That conversation itself was not available to this session, so the review is the recorded source for those decisions (**SOURCE: PR #1035 review**; verbatim conversation unverified).

Data read: `data/items/items.json` (889 rows, next number 896), `recipes.json` (404 rows, next 407), `blueprints.json` (185 rows, next 186), `structures.json` (216 rows, highest state 228; state 229 is bog iron in code only), on `dev` at `7f8aabf4` (identical to `main` for `data/items/`).

## 1. Authority and decision labels

Every decision below carries one label:

- **APPROVED**: Dave's decision. Source either **[B]** Dave's brief "Master Items Catalog — Reconciliation Assignment" (11 Nov 2026) or **[R]** the PR #1035 review of Dave's 11 Nov design conversation, or an older Dave ruling cited by name.
- **RECOMMENDED**: this document's (or the review's) proposal. Needs Dave's sign-off before any data change.
- **UNRESOLVED**: no decision and no recommendation yet; Dave decides.

| Rank | Source | Use |
|---|---|---|
| 1 | Dave, 11 Nov 2026: brief [B] and design conversation as transcribed in review [R] | APPROVED; wins over everything below |
| 2 | Older Dave words: `ITEM_DECISION_LOG.md` (rows "Dave"), `docs/mirror/design/ITEM_TRIM_DECISIONS.md`, decisions quoted in `docs/FINAL_HANDOFF_REPORT_11Nov.md` s7 (61, 69, 70, 71, 73) | APPROVED where rank 1 is silent |
| 3 | Agent-written plans: `docs/design/item_system.md` draft 7 (coordinator rulings 10 Nov), `buildables_plan.md`, `progression.md`, `wood_tier_note.md` | Intended design only where they agree with ranks 1 and 2 |
| 4 | `data/items/*.json` | Implementation truth: what exists. Ids and numbers are preserved |

`design/decisions_pending.md` (85 decisions, old Library) was not readable from this session; only the decisions quoted in the final handoff report are used (**SOURCE UNVERIFIED** for the rest).

### 1.1 Older rulings superseded by Dave's 11 Nov decisions

| Older ruling (source) | Dave, 11 Nov 2026 | Result |
|---|---|---|
| Bellows dropped (item_system.md s2, s6, s12; coordinator 10 Nov) | Bellows is a Smithy upgrade [B][R] | Superseded |
| Clay bloomery 5 ore → 1 ingot (item_system.md s6; live item 795, recipe 367) | No Clay Bloomery [B]; matches Dave's 30 Oct "no bloomery" | Superseded; retire |
| Large forge and Master forge parked; "the anvil is the steel step" (item_system.md s2, s6, s11) | Smelter + Blast Furnace (steel) + Smithy (forge, anvil, bench built in) + distinct Master Smithy [B][R] | Superseded |
| "One forge model, upgraded in tiers" (Dave 25 Oct) | Separate Smelter, Blast Furnace, Smithy, Master Smithy [B] | Superseded by Dave's newer decision |
| Stone - Wedge kept; wedge lumber route (item_system.md s3; moderator QA) | Stone Wedge retired [B]; bootstrap without the wedge [R] | Superseded |
| Stone - Spade, Stone - Sickle kept (item_system.md s3) | Both retired [B][R] | Superseded |
| Bronze Spade, Bronze Hoe, Bronze Saw, Iron Needle planned NEW-F (item_system.md s3) | Not in the approved ladders [R] | Dropped |
| Whetstone hone: +25 %, never above 75 %, then material repair (`drops.json tool_wear.hone`, Part C plan) | Whetstone + water sharpens to 100 % automatically, costing max durability [R] | Superseded |
| Grindstone skipped (item_system.md s6 C7) | Grindstone is a faster, NPC-operable sharpener [R] | Superseded |
| Stonecutter's bench needs a kept chisel (item_system.md s6; recipes 368–370) | Chisels are sculpture tools, not mandatory for stone construction [R] | Superseded for construction (s3.4) |
| Names at most four words (`validate_items.gd`, item_system.md s1 rule 8) | Dynamic enhanced names are not bound by the four-word rule [R] | Superseded for dynamic names only |

## 2. Status keys and id rules

- **KEEP**: stays as in data. **UPDATE**: same id and number; a field, name, recipe or station changes. **ADD**: new row, number taken from `next_number` at implementation time (none reserved here). **RETIRE**: `"retired": true`; row and number stay forever, never reused. **FUTURE**: in data or planned, not obtainable yet.
- Never reuse a retired id or number. The retired `fine_board` (227) and `rough_plank` (226) are **not** revived. `sewing_needle` (49) was revived before this rule and stays live.
- Reusing an existing *future* (never obtainable) id for a new station is reasonable but needs implementation and migration review [R]; each such case is marked RECOMMENDED.

## 3. Hand tools

### 3.1 Approved tool ladders [R]

| Family | Approved ladder | Role [R] |
|---|---|---|
| Axe | Stone, Bronze, Iron, Steel | Fells and works wood. Sharpened (metal). |
| Pickaxe | Stone, Bronze, Iron, Steel | Mines. Sharpened (metal). |
| Spade | Wooden, Iron, Steel (no Stone, no Bronze) | Digs. |
| Hammer | Wooden, Stone, Bronze, Iron, Steel | Builds. Better hammers gain **only** a longer automatic material-sourcing range and more durability (range numbers provisional). Any metal hammer builds any tier (decision 73). |
| Hoe | Wooden, Stone, Iron, Steel (no Bronze) | Six modes: Flatten, Smooth (slope-preserving averaging), Pathen, Survey a Road (two stakes, pathfinding), Create Garden Plot, Plant. |
| Knife | Stone, Bronze, Iron, Steel | A weapon too. Harvests a carcass by repeated attacks, giving resources progressively. Sharpened (metal). |
| Hand saw | Iron, Steel (no Bronze) | Hand sawing, intentionally slow. Metal edged. |
| Sickle | Bronze, Iron, Steel (Stone retired) | Portable, precise harvesting. Metal edged. |
| Scythe | Bronze, Iron, Steel | Large-area harvesting. Metal edged. |
| Chisel | Bronze, Iron, Steel | Optional sculpture and art; not required for stone construction. Metal edged. |
| Sewing needle | One reusable needle (no tiers) | Sewing; with thread, portable simple repairs. |

### 3.2 Maintenance [B][R]

- **Stone tools are disposable** (APPROVED): no repair; a stone tool that wears out vanishes. Applies to Stone - Axe 6, Stone - Knife 11, Stone - Pickaxe 297, Stone - Hammer 244, Stone - Hoe 222. (Stone - Spade 45 and Stone - Sickle 298 are retired.)
- **Metal axes, pickaxes and knives are sharpened** (APPROVED); other metal edged tools (saws, sickles, scythes, chisels) follow the same design where applicable (APPROVED as a principle; per-tool fit is an implementation detail).
- **Sharpening behaviour** (APPROVED): with a portable **Whetstone** and accessible water, the player's eligible tools are sharpened automatically, one after another, to 100 % sharpness. A fully dull tool takes up to five real minutes. Sharpening permanently uses up maximum durability in proportion to the sharpening done. The player uses nearby seating where there is some. A **Grindstone** is a faster alternative an NPC can operate.
- This replaces the live hone rule (`drops.json tool_wear.hone`: R on an `edge: true` tool, +25 %, cap 75 %). It implies two per-instance values per sharpened tool, **sharpness** and **maximum durability**, beside today's wear. Exact rates and numbers are UNRESOLVED.
- **Non-edged metal tools** (spades, hoes, hammers): a separate maintenance decision is needed; blade sharpening is not applied to them (APPROVED principle). Their repair treatment is UNRESOLVED (U3).
- Wooden tools, stone and flint weapons (Stone - Spear 7, Stone - Mace 313, javelin) and the flint Scraper 293 are not named by either rule: UNRESOLVED (U4).

### 3.3 Family tables

`tN` = the live `tier` field. Live stations: `hand`; `workbench` with level; `forge` = Stone - Forge; `brick_forge` = Brick - Forge (L2 iron, L3 steel with the Anvil). Recipe stations for new rows follow s5 and are not set here.

| Family | # | id | Name | Live tier / station | Status | Label | Notes |
|---|---|---|---|---|---|---|---|
| **Axe** | 6 | stone_axe | Stone - Axe | stone t1, hand | UPDATE | APPROVED | Disposable: drop `repair`. |
| | 459 | bronze_axe | Bronze - Axe | bronze t2, forge | UPDATE | APPROVED | Sharpening per 3.2. |
| | — | new | Iron - Axe | | ADD | APPROVED | |
| | — | new | Steel - Axe | | ADD | APPROVED | |
| **Pickaxe** | 297 | stone_pickaxe | Stone - Pickaxe | stone t2, hand | UPDATE | APPROVED | Disposable. |
| | 458 | bronze_pickaxe | Bronze - Pickaxe | bronze t2, forge | UPDATE | APPROVED | Gains sharpening (no `edge` today). |
| | 33 | iron_pickaxe | Iron - Pickaxe | iron t2, brick_forge L2 | UPDATE | APPROVED | Gains sharpening. |
| | 34 | steel_pickaxe | Steel - Pickaxe | steel t3, brick_forge L3 (locked) | FUTURE → UPDATE | APPROVED | Gains sharpening when live. |
| **Spade** | 19 | wooden_spade | Wooden - Spade | hand | KEEP | APPROVED | |
| | 45 | stone_spade | Stone - Spade | stone t2, workbench | RETIRE | APPROVED [B] | Recipe 26 retires. Saved-game handling U1. |
| | 46 | iron_spade | Iron - Spade | iron t3, brick_forge L2 | KEEP | APPROVED | Maintenance U3. |
| | 47 | steel_spade | Steel - Spade | steel t4, brick_forge L3 | FUTURE | APPROVED | |
| | 213–220 | spade sizes | | | RETIRED (already) | | |
| **Hammer** | 247 | wooden_hammer | Wooden - Hammer | wood t1, hand | KEEP | APPROVED | Role: sourcing range + durability only. |
| | 244 | stone_hammer | Stone - Hammer | stone t2, hand | UPDATE | APPROVED | Disposable. |
| | 460 | bronze_hammer | Bronze - Hammer | bronze t3, forge | KEEP | APPROVED | |
| | 560 | iron_hammer | Iron - Hammer | iron t3, brick_forge L2 | KEEP | APPROVED | |
| | 561 | steel_hammer | Steel - Hammer | steel t3, brick_forge L3 | FUTURE | APPROVED | |
| **Hoe** | 221 | wooden_hoe | Wooden - Hoe | hand | KEEP | APPROVED | Six modes (3.1) are a code feature. |
| | 222 | stone_hoe | Stone - Hoe | stone t2, workbench | UPDATE | APPROVED | Disposable. |
| | 223 | iron_hoe | Iron - Hoe | iron t3, brick_forge L2 | KEEP | APPROVED | |
| | 224 | steel_hoe | Steel - Hoe | steel t4, brick_forge L3 | FUTURE | APPROVED | |
| **Knife** | 11 | stone_knife | Stone - Knife | t1, hand | UPDATE | APPROVED | Disposable. Group `knife` (821). |
| | 461 | bronze_knife | Bronze - Knife | bronze t2, forge | UPDATE | APPROVED | Sharpening. Weapon role and carcass harvesting are code features. |
| | — | new | Iron - Knife, Steel - Knife | | ADD | APPROVED | Must join group `knife`. |
| | 296 | obsidian_knife | Obsidian - Knife | obsidian t2 | FUTURE | — | Not in the approved ladder; stays parked as today (no change). |
| **Hand saw** | 245 | hand_saw | Iron - Saw | iron t3, workbench L2 | UPDATE | APPROVED | Sharpening; its odd repair (1 Twine, 1 Stick) is replaced by the metal maintenance rule. |
| | — | new | Steel - Saw | | ADD | APPROVED | A `saw` group then lets either saw do hand sawing (RECOMMENDED). |
| **Sickle** | 298 | sickle | Stone - Sickle | stone t1, workbench | RETIRE | APPROVED [R] | Recipe 187 retires. Generic id `sickle` stays with the retired row; the new rows take new ids. |
| | — | new | Bronze - Sickle, Iron - Sickle, Steel - Sickle | | ADD | APPROVED | |
| **Scythe** | — | new | Bronze - Scythe | | ADD | APPROVED [R] | Missing from draft 1. |
| | 299 | scythe | Iron - Scythe | iron t3, brick_forge L2 | KEEP | APPROVED | Sharpening. |
| | — | new | Steel - Scythe | | ADD | APPROVED | |
| **Chisel** | 798 | bronze_chisel | Bronze - Chisel | bronze t2, forge | KEEP | APPROVED | Sculpture tool (3.4). |
| | 799 | iron_chisel | Iron - Chisel | iron t3, brick_forge L2 | KEEP | APPROVED | |
| | 800 | steel_chisel | Steel - Chisel | steel t4, brick_forge L3 (locked) | FUTURE | APPROVED | |
| **Needle** | 49 | sewing_needle | Bone - Needle | hand | KEEP | APPROVED | The one reusable needle. Kept by 27 live recipes. |

### 3.4 Chisels and stone construction

Chisels are not mandatory for stone construction (APPROVED [R]). Today: plain Stone block is made at any workbench from 8 Stone (recipe 127, no chisel), so stone building is not gated. The Stonecutter's bench recipes all keep a chisel: 368 `bench_stone_block` (Stone block from 6 Stone), 369 `carved_stone_block`, 370 `carved_stone_shingle`. RECOMMENDED: drop the chisel from 368 (it is construction); keep it on 369 and 370 only if carved stone counts as sculpture or ornament. Dave confirms (U9).

### 3.5 Other tools

| # | id | Name | Status | Label | Notes |
|---|---|---|---|---|---|
| 815 | whetstone | Whetstone | UPDATE | APPROVED | Portable sharpener with water (3.2). Its own wear and `repair` (1 Stone) need re-checking against the new rule. |
| — | new | Grindstone | ADD | APPROVED [R] | Faster sharpener, NPC-operable. Placed or carried, cost and speed UNRESOLVED (U2). |
| — | (thread) | thread for needle repairs | ADD or reuse | RECOMMENDED | "Needle and thread for portable simple repairs" [R]: no thread item is live (Linen thread and Wool yarn are item_system NEW-F only). RECOMMENDED: use Twine until a thread item is approved. U8. |
| 293 | hide_scraper | Scraper | KEEP | — | U4 (flint). |
| 807, 344, 75, 260, 557, 12/542, 311, 668/669/892/893 | | Mortar and pestle, Hand mill, Fishing rod, Fishing net, Wooden - Spyglass, Torch, Candle, lanterns | KEEP | — | Unaffected. |
| 294 | steel_striker | Steel - Striker | FUTURE | — | Unaffected. |

## 4. Wood: Logs, Planks, Hardwood boards and sawing [B][R]

APPROVED: **basic Logs → Planks; hardwood species Logs → Hardwood boards**, by hand saw (intentionally slow) or the **waterwheel-powered vertical reciprocating sawmill**. No board sizes and no extra Fine board step. Hardwood boards are for fine furniture and construction, chests, barrels, carts, wagons and carriages.

| # | id | Name | Status | Label | Notes |
|---|---|---|---|---|---|
| 4 | log | Log | KEEP | APPROVED | Basic log; also the group `log`. |
| 100, 103, 106, 124, 148, 172 | log_oak, log_beech, log_birch, log_tropical_hardwood, log_walnut, log_maple | Oak, Beech, Birch, Mahogany, Walnut, Sugar maple log | KEEP | APPROVED | Hardwood species logs (`wood_species.json` class hardwood) → Hardwood boards. |
| 109, 112 | log_scots_pine, log_spruce | Scots pine, Spruce log | KEEP | RECOMMENDED | Softwood species: treat as basic Logs → Planks. |
| 27 | lumber | Plank | KEEP | APPROVED | Display name stays singular "Plank" (naming rule). Used by 9 live recipes and 69 live blueprints. |
| — | new | Hardwood board | ADD | APPROVED | New id and number (not `fine_board` 227). Yields, times and which recipes and blueprints switch from Plank to it: UNRESOLVED (U5, U6). |
| 245 | hand_saw | Iron - Saw | KEEP | APPROVED | Recipe 159 `lumber_by_hand` (1 log → 2 Plank, 24 s). Gains a hardwood-board recipe. |
| 241 | saw_mill | Sawmill | KEEP | APPROVED | Already waterwheel-driven (`structures.json saw_mill.needs_running_water`); recipe 16 (1 log → 4 Plank, 6 s). Gains a hardwood-board recipe. Description may add "vertical reciprocating" (optional). |
| 238, 239 | saw_blade, water_wheel | Saw blade, Water wheel | KEEP | APPROVED | Sawmill parts. |
| 101–174 | lumber_*, beam_* (species) | species lumber and beams | FUTURE → RETIRE | RECOMMENDED | Superseded by one Hardwood board with no sizes [R]; retire rather than reuse. Dave confirms (U6). |
| 226, 227 | rough_plank, fine_board | | RETIRED (already) | | Never reused. |
| 353 | stone_wedge | Stone - Wedge | RETIRE | APPROVED [B] | Recipes 227 `stone_wedge` and 230 `lumber_wedge` retire. |
| 243 | woodworking_table | Woodworking table | RETIRE | RECOMMENDED [R] | Live structure (state 35) and blueprint 12, but no live recipe; redundant with the Carpenter's bench. Dave signs off (U7). |

### 4.1 First-Plank bootstrap (RECOMMENDED [R])

Without the wedge, and with no Bronze Saw (APPROVED), the first Planks come from:
1. **Buying Planks at the starter-town lumbermill.** No shop sells Planks today (`data/npcs/shops.json` has only Hob, who *buys* boards: Dave 2 Nov). Needs a new seller row (and the lumbermill as a place or NPC): RECOMMENDED, Dave signs off.
2. **In the wilderness: dig bog iron → Smelter → Iron ingot → Saw blade → Iron - Saw.** Constraint (APPROVED principle [R]): **nothing on the Smelter/Smithy path may cost Planks.** Checked today: Stone - Forge (24 Stone, 10 Clay, 2 Hide) and Brick - Forge (20 Brick, 10 Stone, 4 Clay mortar) need no Planks; the Iron - Saw needs workbench level 2, which the Wooden - Workbench (Sticks, Twine, Stone) plus a Vice (Sticks, Stone) or Tool rack (Sticks, Twine) reaches without Planks. The new Smelter, Smithy, Bellows and Quenching Trough blueprints must keep to this.

## 5. Metalworking stations [B][R]

APPROVED design: a dedicated **Smelter** smelts copper, tin and bog iron to ingots (copper, tin, iron) and makes bronze alloy. The **Blast Furnace** is its advanced, high-capacity tier and makes steel. The ordinary **Smithy** already contains a forge, an anvil and a bench, with **Bellows** and **Quenching Trough** as nearby upgrades. A distinct, ornate **Master Smithy** makes special or masterwork items with +1 or +2 physical craftsmanship (s7). Wizard enchantments are separate from both. **No Clay Bloomery.**

| Station | Existing row | Status | Label | Notes |
|---|---|---|---|---|
| Smelter | none | ADD | APPROVED | Takes recipes 190 `smelt_copper`, 191 `smelt_tin`, 192 `smelt_iron`, 185 `bronze_ingot`. Cost, fuel and throughput UNRESOLVED (U5). No Planks in its cost (4.1). |
| Blast Furnace | none; future Large forge 92/93 could carry it | ADD | APPROVED | Takes 193 `smelt_steel` (locked today). Reusing the `large_forge` id: RECOMMENDED only after migration review; otherwise a new row and Large forge stays FUTURE. |
| Smithy | Brick - Forge 90 (`blacksmithy`, station `brick_forge`) | UPDATE | RECOMMENDED | Proposed: the Brick - Forge becomes the Smithy (rename; id stays). Takes the metalworking recipes: bronze working (204–206, 215, 290–293, 371, 394, 397, 405, 406, today at `forge`) and iron and steel working (18, 19, 27, 28, 141, 142, 145, 149, 152, 183, 184, 188, 207–212, 217–220, 346, 347, 351, 372, 373, 404, today at `brick_forge`). Migration of station ids and levels UNRESOLVED (U10). |
| Bellows | none | ADD | APPROVED | Add-on of the Smithy (`addon_of`), within reach. What it improves UNRESOLVED (U11). Reverses the 10 Nov drop. |
| Quenching Trough | none | ADD | APPROVED | Add-on of the Smithy. What it improves UNRESOLVED (U11). Not the water troughs (B6a) or the Fodder trough. |
| Master Smithy | future Master forge 94/95 (ornate description fits) | UPDATE or ADD | RECOMMENDED | Rename the never-obtainable `master_forge` rows to Master Smithy, after migration review. Gives masterwork +1/+2 physical craftsmanship. |
| Anvil | 827 `iron_anvil` (`addon_of: brick_forge`, the steel step today) | RETIRE or KEEP | UNRESOLVED | The Smithy already contains an anvil [R], and steel moves to the Blast Furnace, so a separate Anvil add-on has no job. RECOMMENDED: retire it, with placed anvils handled per U1. |
| Stone - Forge | 88 `stone_forge` (station `forge`: smelts copper and tin, makes bronze and bronze tools) | UNRESOLVED | UNRESOLVED | Its smelting goes to the Smelter and its bronze working to the Smithy. Retire, rename, or keep as an early Smithy: U10. Old forge roles are not treated as approved [R]. |
| Clay bloomery | 795, structure state 200, blueprint 162, recipe 367 | RETIRE | APPROVED [B] | Placed bloomeries in saves: U1. |
| Large forge | 92/93 | FUTURE | — | See Blast Furnace. |

`repair_station: "forge"` on 26 metal tools and weapons names the old station; it changes with the maintenance rule and U10.

## 6. Leather and textile stations [B][R]

APPROVED: **Tanning** and **drying** for hides and leather; a **Leatherworking Table** for leather goods; a **Tailor's Table** for clothing; the **Loom** for weaving. Needle and thread give portable simple repairs; repair at a workstation is also supported. Full production does not need an extra needle tier.

| Station | Existing row | Status | Label | Notes |
|---|---|---|---|---|
| Tanning rack | 773 (state 189, blueprint 151) | KEEP | APPROVED | Recipes 234 `leather`, 235 `heavy_leather`. |
| Drying rack | 775 (state 190, blueprint 152) | UPDATE | APPROVED | Gains the hide/leather drying step (today it dries food only: 268, 270, 282, 288). Which recipe and inputs: UNRESOLVED (U5). Food drying stays. |
| Leatherworking Table | none | ADD | APPROVED | Matches Dave's 30 Oct "leather working table early". Takes leather goods now at `workbench` L2/L3: 213 leather cap, 214 jerkin, 356 quiver, 358 trousers, 359 boots, 360 gloves, 361 backpack, 392 belt; and 278 `leather_strap` (RECOMMENDED). Exact list and levels: U10. |
| Tailor's Table | none | ADD | APPROVED | Takes clothing: 216 gambeson, 237–241 wool and linen, 242–244 fur; and hide garments now sewn by hand (39–42, 194–196) (RECOMMENDED; whether hand sewing stays: U10). |
| Loom | 846 (future) | FUTURE → ADD blueprint and state | APPROVED | Weaving. The hand cloth recipes (245 `linen`, 334 `fibre_cloth`, 342 `wool_cloth`) move or go when it lands (item_system s6). |
| Spinning wheel | 845 (future) | FUTURE | — | Not in Dave's list; unchanged. |
| Repairs | — | — | APPROVED | Clothing and leather repair with needle and thread anywhere, or at these stations. Amounts UNRESOLVED (U5). |

## 7. Universal item enhancements [B][R]

APPROVED:
1. **Every item schema supports one physical slot and two magical slots**, hidden when empty. Effects belong to the **individual item instance**, not the item type.
2. **Physical craftsmanship** improves what suits the item type: weight, durability, sharpness, damage, efficiency or value. Where numeric, the most is **+2 physical**. The Master Smithy makes masterwork (+1/+2). Masterwork stations for other crafts are not defined.
3. **Magical slots** carry separate supernatural effects (wizard enchantments, separate from smithing).
4. **Physical and magical modifiers are calculated separately and add where they affect the same statistic.** Example: **Mighty Steel Sword +4** = +2 physical damage + 2 magical damage. **Light Flaming Steel Sword of Might +2** shows three distinct effects.
5. **Names are assembled dynamically** from the actual enhancements (for example "Light Hammer"); they are not bound by the static four-word rule in `validate_items.gd`.

Implementation notes (not decisions): enhancements are per-instance save data like tool wear, so they need no `items.json` rows; saves and the network protocol change; the static name rule must exempt dynamic names; `items.json` needs no per-item slot field if every item has the same three slots.

UNRESOLVED (U12): removing or replacing an enhancement; how enhancements work with stackable items and consumables (food, ammunition, materials); the word order and wording table for names; what items fill magical slots (Dave 30 Oct: the magic system gets its own pass later).

## 8. Findings

### 8.1 Missing items (APPROVED to add)
Iron and Steel Axe; Iron and Steel Knife; Steel Saw; Bronze, Iron and Steel Sickle; Bronze and Steel Scythe; Hardwood board; Grindstone; Smelter; Blast Furnace; Bellows; Quenching Trough; Master Smithy (or rename of 94/95); Leatherworking Table; Tailor's Table; Loom blueprint and state. RECOMMENDED: a thread item (or Twine), and a starter-town Plank seller.

### 8.2 Obsolete items
APPROVED to retire: Stone - Spade 45, Stone - Wedge 353, Stone - Sickle 298, Clay bloomery 795. RECOMMENDED to retire: Woodworking table 243, Anvil 827, species lumber and beams (future rows 101–174). UNRESOLVED: Stone - Forge 88.

### 8.3 Duplicate functions
- Iron smelting at the Clay bloomery (367) and the Brick - Forge (192): resolved by the retirement and the Smelter.
- Smelting and smithing in one body today (Stone - Forge, Brick - Forge) versus the approved Smelter / Smithy split.
- The Anvil add-on versus the anvil built into the Smithy.
- Woodworking table versus Carpenter's bench.
- Plank by hand twice (hand saw 159 and wedge 230): the wedge route goes.
- Leather and cloth goods at the workbench versus the new tables.
- Species lumber rows versus one Hardwood board.

### 8.4 Conflicting recipes and data
- **C1** No Plank before iron once the wedge goes: answered by 4.1 (RECOMMENDED).
- **C2** Stone tools have `repair` and `edge: true` (honed); both contradict disposable stone tools (APPROVED fix: remove both).
- **C3** The live hone rule (25 %, 75 % cap) contradicts approved sharpening (s3.2).
- **C4** `edge: true` is on bronze axe and knife, saw, scythe and chisels, but not on pickaxes, which are approved for sharpening: the eligibility flag must change.
- **C5** `tier` numbers disagree across families (Bronze and Iron Pickaxe both t2; Iron Spade t3; Steel Hammer t3 but Steel Spade t4; no tier on wooden spade and hoe). `digging.json tier_extra` reads the spade tier. Pre-existing; for the catalog pass.
- **C6** Iron - Saw repairs with Twine and a Stick, unlike every other iron tool (replaced by the metal rule).
- **C7** Stonecutter's bench recipes need a chisel for construction blocks (3.4).
- **C8** Brick - Forge and Anvil descriptions say the anvil is for steel; steel moves to the Blast Furnace.
- **C9** No shop sells Planks (4.1).

## 9. Affected recipes, blueprints and workstations

| File | Rows | Change | Label |
|---|---|---|---|
| items.json | 45, 298, 353, 795 | RETIRE | APPROVED |
| items.json | 6, 11, 222, 244, 297 | remove `repair` and `edge` (disposable) | APPROVED |
| items.json | 33, 34, 458, 459, 461, 245, 299, 798–800 | sharpening eligibility; replace material repair per the metal rule | APPROVED (numbers U5) |
| items.json | 815 | Whetstone role | APPROVED |
| items.json | new rows in 8.1 | ADD | APPROVED |
| items.json | 90, 94/95, 92/93, 88, 827, 243, 101–174 | rename, reuse or retire | RECOMMENDED / UNRESOLVED |
| recipes.json | 26, 187, 227, 230, 367 | RETIRE | APPROVED |
| recipes.json | new: tool recipes (8.1), Hardwood board by saw and sawmill, hide drying, Grindstone | ADD | APPROVED (amounts U5) |
| recipes.json | 185, 190–193 → Smelter / Blast Furnace; metalworking rows (s5) → Smithy; leather and clothing rows (s6) → tables; 368 drop chisel | station moves | RECOMMENDED (U9, U10) |
| blueprints.json | 162 | RETIRE | APPROVED |
| blueprints.json | new: Smelter, Blast Furnace, Bellows, Quenching Trough, Master Smithy, Leatherworking Table, Tailor's Table, Loom, Grindstone (if placed) | ADD (no Planks on the Smelter/Smithy path) | APPROVED (costs U5) |
| blueprints.json | 9, 10, 12, 164 | rename or retire with their stations | RECOMMENDED / UNRESOLVED |
| structures.json | `clay_bloomery` (state 200) | RETIRE | APPROVED |
| structures.json | new states from 230; `addon_of` the Smithy for Bellows and Quenching Trough | ADD | APPROVED |
| structures.json | `blacksmithy`, `master_forge`, `large_forge`, `stone_forge`, `iron_anvil`, `woodworking_table` | migrate | RECOMMENDED / UNRESOLVED |
| wood_species.json `ingredient_groups` | `knife` + iron and steel knives; new `saw` group | ADD members | APPROVED / RECOMMENDED |
| drops.json `tool_wear.hone` | replace with the approved sharpening rule | UPDATE | APPROVED |
| data/npcs/shops.json | Plank seller at the starter-town lumbermill | ADD | RECOMMENDED |

Workstations affected: Smelter, Blast Furnace, Smithy, Bellows, Quenching Trough, Master Smithy, Stone - Forge, Brick - Forge, Anvil, Clay bloomery, Large forge, Master forge, Sawmill, Woodworking table, Carpenter's bench, workbenches (recipes leave them), Stonecutter's bench, Tanning rack, Drying rack, Leatherworking Table, Tailor's Table, Loom, Grindstone.

## 10. JSON changes required (only after Dave approves this catalog)

APPROVED, ready when the item-data role takes numbers:
1. `items.json`: `"retired": true` on 45 `stone_spade`, 298 `sickle`, 353 `stone_wedge`, 795 `clay_bloomery`.
2. `recipes.json`: `"retired": true` on 26 `stone_spade`, 187 `sickle`, 227 `stone_wedge`, 230 `lumber_wedge`, 367 `bloomery_iron`.
3. `blueprints.json`: `"retired": true` on 162 `clay_bloomery`. `structures.json`: retire the `clay_bloomery` row (state 200 never reused).
4. `items.json`: remove `repair` and `edge` from 6, 11, 222, 244, 297; code removes a worn-out disposable tool (today a broken tool stays in its slot).
5. `items.json` and `recipes.json`: add the tools in 8.1 (Iron/Steel Axe, Iron/Steel Knife, Steel Saw, Bronze/Iron/Steel Sickle, Bronze/Steel Scythe) with recipes at the Smithy; add Hardwood board with sawmill and hand-saw recipes; add Grindstone.
6. `items.json`, `structures.json`, `blueprints.json`: add Smelter, Blast Furnace, Bellows, Quenching Trough, Leatherworking Table, Tailor's Table, Loom blueprint and state; new structure states from 230, blueprints from 186. Matching rows in `weights.json`, `looks.json`, `look_placeholders.json`, descriptions and encyclopedia.
7. `drops.json`: replace `tool_wear.hone` with the sharpening rule (rates U5); items gain the per-instance sharpness and maximum-durability values in code.
8. Save format and protocol: per-instance enhancement slots and sharpness (code).

RECOMMENDED or UNRESOLVED (wait for Dave): Smithy and Master Smithy renames and id reuse, Blast Furnace id, Anvil, Stone - Forge, Woodworking table, species lumber, recipe station moves, chisel on 368, thread item, Plank seller, all costs and yields.

Files that reference the rows being retired and must change with them (code and tests untouched by this document): `weights.json`, `looks.json`, `showroom.json`, `design_names.json`, `descriptions_voice.json`, `encyclopedia.json`; tests `test_server_items.gd`, `test_tool_looks.gd`, `test_stations.gd` (stone spade), `test_lumber_route.gd`, `test_logs_carry.gd` (wedge), `test_bloomery_bench.gd`, `test_blueprints.gd`, `test_structure_looks*.gd` (bloomery), `test_whetstone.gd` (hone rule); client `basic_look.gd`, `piece_look.gd`, `look_table.gd`; `tools/gen_looks.py` and the icon painters. Run `tools/items_check.py` (validate_items, stations, save_compat) on the authorized PC after the data change.

## 11. Still needing Dave

The basic design is approved; these are the remaining sign-offs.

1. **U1 Saved worlds:** what happens to Stone Spades, Stone Sickles, Stone Wedges and placed Clay bloomeries (and Anvils, if retired) that players already have?
2. **U2 Grindstone:** placed or carried, its cost, and how much faster it is.
3. **U3 Non-edged metal tools** (spades, hoes, hammers): how are they maintained?
4. **U4 Edge cases of "stone tools":** do wooden tools, stone and flint weapons (Stone - Spear, Stone - Mace, Javelin) and the flint Scraper also vanish when worn out?
5. **U5 Numbers:** yields, throughput, sharpening rates and all resource costs (sawmill and hand-saw board yields, smelter, blast furnace, new stations, hide drying, repairs).
6. **U6 Hardwood board uses:** which existing recipes and blueprints switch from Plank to Hardwood board; retire the species lumber and beam rows (recommended)?
7. **U7 Woodworking table:** retire (recommended, redundant with the Carpenter's bench)?
8. **U8 Thread:** use Twine for needle repairs, or add a thread item?
9. **U9 Carved stone:** is it sculpture (keeps the chisel) or construction (chisel dropped)?
10. **U10 Migration:** station ids, levels and names (Brick - Forge → Smithy, Master forge → Master Smithy, Large forge → Blast Furnace, Stone - Forge, Anvil), and which recipes move to the Smithy, Leatherworking Table and Tailor's Table; does hand sewing of hide garments stay?
11. **U11 Smithy upgrades:** what exactly do the Bellows and the Quenching Trough improve?
12. **U12 Enhancements:** removing or replacing them, stackables and consumables, and the name wording table.
13. **Bootstrap (RECOMMENDED, needs sign-off):** starter-town lumbermill sells Planks; wilderness route via bog iron → Smelter → Iron - Saw, with no Planks on that path.

Also for the catalog pass (pre-existing): tier numbering across families (C5).

## Appendix A. Full catalog of existing items (generated from `data/items/items.json`)

Generated from dev `7f8aabf4`. 889 rows; next free item number 896. Status counts: FUTURE 70, KEEP 544, RETIRE 6, RETIRED 253, UPDATE 16.
`RETIRED` = already retired before this document (kept only for its number). `Made at` is the station of the first live recipe that gives the item (`hand` = no station; L = station level); blank = not crafted (gathered, dropped, built from a blueprint, or a group placeholder). Purpose is the live tooltip description. Gathered wild items (`gathered.json`, numbers 1000+) are outside this catalog.

### A.tool (54 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 6 | `stone_axe` | Stone - Axe | stone t1 | hand | UPDATE | **APPROVED: disposable stone tool (s3.2).** A stone bound to a handle. Fells trees, breaks rock and works wood. |
| 11 | `stone_knife` | Stone - Knife | t1 | hand | UPDATE | **APPROVED: disposable stone tool (s3.2).** A flaked stone on a handle. Dresses a kill and cuts bark. |
| 12 | `torch` | Torch | t1 | hand | KEEP | A stick wrapped in fibre and dipped in pitch. Lights your way after dark. |
| 19 | `wooden_spade` | Wooden - Spade |  | hand | KEEP | A sharpened wooden blade. Digs roots and bulbs. |
| 33 | `iron_pickaxe` | Iron - Pickaxe | iron t2 | brick_forge L2 | UPDATE | **APPROVED: sharpening (s3.2).** An iron head on a hardwood handle. One blow breaks one stone off a boulder. |
| 34 | `steel_pickaxe` | Steel - Pickaxe | steel t3 | brick_forge L3 | FUTURE | **APPROVED: sharpening when live (s3.2).** A steel head on a hardwood handle. One blow breaks one stone off a boulder, and it lasts longest. |
| 45 | `stone_spade` | Stone - Spade | stone t2 | workbench | RETIRE | **APPROVED: Stone Spade retired.** A spade with a stone blade. Digs deeper and lasts longer than wood. |
| 46 | `iron_spade` | Iron - Spade | iron t3 | brick_forge L2 | KEEP | A spade with an iron blade. |
| 47 | `steel_spade` | Steel - Spade | steel t4 | brick_forge L3 | FUTURE | A spade with a steel blade. |
| 49 | `sewing_needle` | Bone - Needle |  | hand | KEEP | **APPROVED: the one reusable needle.** A needle carved from bone. For sewing hide and cloth. |
| 75 | `fishing_rod` | Fishing rod |  | hand | KEEP | A stick, line and hook. Cast at water, then click again when something bites. |
| 221 | `wooden_hoe` | Wooden - Hoe |  | hand | KEEP | A flat blade on a long handle. Paths the ground and tills beds. |
| 222 | `stone_hoe` | Stone - Hoe | stone t2 | workbench | UPDATE | **APPROVED: disposable stone tool (s3.2).** A hoe with a stone blade. Lasts longer than wood. |
| 223 | `iron_hoe` | Iron - Hoe | iron t3 | brick_forge L2 | KEEP | A hoe with an iron blade. |
| 224 | `steel_hoe` | Steel - Hoe | steel t4 | brick_forge L3 | FUTURE | A hoe with a steel blade. |
| 244 | `stone_hammer` | Stone - Hammer | stone t2 | hand | UPDATE | **APPROVED: disposable stone tool (s3.2).** A hafted stone hammer. Hold it to place big builds from blueprints. |
| 245 | `hand_saw` | Iron - Saw | iron t3 | workbench L2 | UPDATE | **APPROVED: sharpening; hand sawing (s3.2, s4).** A bow saw. Keep it on the hotbar to saw a log into 2 planks by hand, slower than a mill. |
| 247 | `wooden_hammer` | Wooden - Hammer | wood t1 | hand | KEEP | A wooden head on a stick. The weakest hammer; it wears out fast. |
| 260 | `shore_net` | Fishing net |  | hand | KEEP | A weighted twine net. Throw it on water, pull it back; a bigger school fills it more. |
| 293 | `hide_scraper` | Scraper | t1 | workbench | KEEP | A flint blade on a handle. Scrapes flesh and hair off a raw hide. |
| 294 | `steel_striker` | Steel - Striker | t4 | brick_forge L3 | FUTURE | A strip of hard steel. Strike flint on it for a shower of sparks. |
| 296 | `obsidian_knife` | Obsidian - Knife | obsidian t2 | workbench | FUTURE | A razor-sharp black glass blade. Cuts better than flint, but chips more easily. |
| 297 | `stone_pickaxe` | Stone - Pickaxe | stone t2 | hand | UPDATE | **APPROVED: disposable stone tool (s3.2).** A heavy stone head on a haft. Breaks boulders and ore, slowly. |
| 298 | `sickle` | Stone - Sickle | stone t1 | workbench | RETIRE | **APPROVED: Stone Sickle retired.** A curved flint blade on a short handle. Cuts grain and grass by the handful. |
| 299 | `scythe` | Iron - Scythe | iron t3 | brick_forge L2 | KEEP | **APPROVED: sharpening (s3.2).** A long curved blade on a tall handle. Mows grass, thatch and grain in wide sweeps. |
| 311 | `candle` | Candle | t1 | hand | KEEP | A wick dipped in tallow. A small steady light, and what a wooden lantern burns. |
| 344 | `quern` | Hand mill |  | hand | KEEP | Two flat stones for grinding grain by hand. Slow but steady. |
| 353 | `stone_wedge` | Stone - Wedge |  | hand | RETIRE | **APPROVED: Stone Wedge retired.** A flaked stone wedge. Driven into a log at a workbench, it splits two planks. |
| 458 | `bronze_pickaxe` | Bronze - Pickaxe | bronze t2 | forge | UPDATE | **APPROVED: sharpening (s3.2).** A bronze head on a hardwood handle. Breaks rock quickly and takes iron ore out of a boulder. |
| 459 | `bronze_axe` | Bronze - Axe | bronze t2 | forge | UPDATE | **APPROVED: sharpening (s3.2).** A bronze blade on a hardwood handle. Fells trees faster and lasts longer than stone. |
| 460 | `bronze_hammer` | Bronze - Hammer | bronze t3 | forge | KEEP | A cast bronze head on a short haft. Hold it to place big builds from blueprints. |
| 461 | `bronze_knife` | Bronze - Knife | bronze t2 | forge | UPDATE | **APPROVED: sharpening (s3.2).** A bronze blade on a bone grip. Dresses a kill cleanly and cuts bark. |
| 542 | `torch_doused` | Torch | t1 |  | KEEP | A stick wrapped in fibre. Lights your way after dark. |
| 557 | `spyglass` | Wooden - Spyglass | t1 | workbench L3 | KEEP | A wooden tube with a crystal lens. Hold it and right-click to see three times closer. |
| 560 | `iron_hammer` | Iron - Hammer | iron t3 | brick_forge L2 | KEEP | A forged iron head on a short haft. Hold it to place big builds from blueprints. |
| 561 | `steel_hammer` | Steel - Hammer | steel t3 | brick_forge L3 | FUTURE | A forged steel head on a short haft. Hold it to place big builds from blueprints. |
| 668 | `wooden_lantern` | Wooden - Lantern |  | workbench L1 | KEEP | A plank lantern with horn panes. Takes a candle; does not go out in the rain. |
| 669 | `iron_lantern` | Iron - Lantern |  | brick_forge L2 | KEEP | An iron lantern with horn panes. Burns lamp oil; does not go out in the rain. |
| 798 | `bronze_chisel` | Bronze - Chisel | bronze t2 | forge | KEEP | **APPROVED: sculpture tool (s3.4).** A solid cast bronze chisel. Squares and carves stone at a stonecutter's bench. |
| 799 | `iron_chisel` | Iron - Chisel | iron t3 | brick_forge L2 | KEEP | **APPROVED: sculpture tool (s3.4).** An iron chisel. Keeps its edge on stone far longer than bronze. |
| 800 | `steel_chisel` | Steel - Chisel | steel t4 | brick_forge L3 | FUTURE | **APPROVED: sculpture tool (s3.4).** A steel chisel. Cuts the hardest stone cleanly. |
| 807 | `mortar_pestle` | Mortar and pestle |  | hand | KEEP | A hollowed stone and a round grinder for crushing herbs into poultices and cures. |
| 815 | `whetstone` | Whetstone |  | hand | UPDATE | **APPROVED: portable sharpener with water (s3.2).** A fine flat stone for honing an edge. Brings a worn blade back without new parts. |
| 892 | `wooden_lantern_dark` | Wooden - Lantern |  |  | KEEP | A lantern gone out. Press its key to light it, with a candle in your pack if it burned out. |
| 893 | `iron_lantern_dark` | Iron - Lantern |  |  | KEEP | A lantern gone out. Press its key to light it, with lamp oil in your pack if it burned out. |

Already retired (9; numbers never reused): 213 `wooden_spade_medium` Medium wooden spade; 214 `wooden_spade_large` Large wooden spade; 215 `stone_spade_medium` Medium stone spade; 216 `stone_spade_large` Large stone spade; 217 `iron_spade_medium` Medium iron spade; 218 `iron_spade_large` Large iron spade; 219 `steel_spade_medium` Medium steel spade; 220 `steel_spade_large` Large steel spade; 246 `stone_adze` Stone adze.

### A.weapon (21 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 7 | `spear` | Stone - Spear | t2 | hand | KEEP | A stone point on a long shaft. Jab with it or throw it; it kills a rabbit in one blow. |
| 10 | `wooden_spear` | Wooden - Spear | t1 | hand | KEEP | A sharpened stick. Jab with it or throw it. |
| 269 | `wooden_bow` | Wooden - Bow | t1 | workbench | KEEP | A bow of bent wood and twine. Needs arrows. |
| 295 | `javelin` | Javelin | t2 | workbench | KEEP | A light, balanced throwing spear. Flies farther and straighter than a plain spear. |
| 300 | `wooden_club` | Wooden - Club | t1 | hand | KEEP | A stout length of hardwood, heavy at one end. Hits hard and needs no skill. |
| 312 | `wicker_shield` | Wicker - Shield | t1 | hand | KEEP | Sticks woven tight with fibre. Light, and good for a few hits. |
| 313 | `stone_mace` | Stone - Mace | t2 | hand | KEEP | A heavy stone lashed to a stick. Cracks armour and bone. |
| 314 | `plank_shield` | Wooden - Shield | t2 | workbench L2 | KEEP | Boards bound with hide. Sturdier than wicker. |
| 315 | `bronze_sword` | Bronze - Sword | t3 | forge | FUTURE | A bronze blade on a short grip. Quick and sharp. |
| 316 | `bronze_mace` | Bronze - Mace | t3 | forge | FUTURE | A cast bronze head on a stout haft. |
| 317 | `bronze_shield` | Bronze - Shield | t3 | forge | FUTURE | A plank shield with a bronze rim and boss. |
| 318 | `iron_sword` | Iron - Sword | t4 | brick_forge L2 | FUTURE | A forged iron blade with a leather grip. |
| 319 | `iron_mace` | Iron - Mace | t4 | brick_forge L2 | FUTURE | A flanged iron head that breaks armour. |
| 320 | `iron_shield` | Iron - Shield | t4 | brick_forge L2 | FUTURE | Boards held by iron bands. Hard to break. |
| 321 | `steel_sword` | Steel - Sword | t5 | brick_forge L3 | FUTURE | A tempered steel blade. Keeps its edge. |
| 322 | `steel_mace` | Steel - Mace | t5 | brick_forge L3 | FUTURE | A steel flanged head on a long haft. |
| 323 | `steel_shield` | Steel - Shield | t5 | brick_forge L3 | FUTURE | A long steel-faced shield that covers shoulder to shin. |
| 761 | `bone_club` | Bone - Club | t1 | hand | KEEP | A heavy leg bone bound with twine at the grip. Hits harder than wood and lasts longer. |
| 763 | `wooden_longbow` | Wooden - Longbow | t2 | workbench L2 | KEEP | A tall bow cut from one stave of hardwood and strung with sinew. Needs arrows. |
| 813 | `sling` | Sling | t1 | hand | KEEP | A hide pouch on two cords. Whirl it and let go to throw a stone fast and far. |
| 816 | `fishing_spear` | Fishing spear | t1 | hand | KEEP | A long stick split and sharpened into barbed prongs. Stab fish in the shallows. |

### A.material (245 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 1 | `stone` | Stone |  |  | KEEP | A fist-sized stone. Pick it up from the ground, or break it off a boulder. |
| 2 | `stick` | Stick |  |  | KEEP | A fallen branch. Burns, and makes handles, frames and fences. |
| 3 | `plant_fibre` | Plant fibre |  |  | KEEP | Stringy strands from nettles and grass. Twist 3 into twine, or use one to light a fire. |
| 4 | `log` | Log |  |  | KEEP | **APPROVED: basic Log to Planks.** A heavy length of trunk. Split it for firewood, or wedge it into planks. |
| 5 | `twine` | Twine |  | hand | KEEP | Twisted fibre cord. Binds tools, frames and kits. |
| 9 | `seed_bundle` | Wild grain |  |  | KEEP | A bundle of seeds. Eat them, or plant them. |
| 13 | `bark` | Bark |  |  | KEEP | Bark stripped from a felled trunk. |
| 14 | `leaves` | Leaves |  |  | KEEP | A handful of green leaves from a felled tree. Roofs a shelter. |
| 18 | `tree_roots` | Roots |  |  | KEEP | Roots from the base of a felled tree. |
| 26 | `firewood` | Firewood |  |  | KEEP | Split wood. Burns long and steady. |
| 27 | `lumber` | Plank |  | saw_mill | KEEP | **APPROVED: Planks; display name Plank.** Boards from a log. Make them at a saw mill, or wedge them at a workbench. |
| 30 | `driftwood` | Driftwood |  |  | KEEP | A bleached branch washed up on a bank. Dry, so it burns well. |
| 31 | `iron_ingot` | Iron ingot |  | brick_forge L2 | KEEP | A bar of smelted iron. Hard, for tools and nails. |
| 32 | `steel_ingot` | Steel ingot |  | brick_forge L3 | FUTURE | A bar of steel. Placeholder until smelting exists. |
| 35 | `soil` | Soil |  |  | KEEP | A shovelful of dark earth, dug from the ground. |
| 36 | `clay` | Clay |  |  | KEEP | A heavy, sticky shovelful of clay. Fire it for bricks and pots. |
| 37 | `sand` | Sand |  |  | KEEP | A shovelful of sand. |
| 38 | `gravel` | Gravel |  |  | KEEP | A shovelful of small stones and grit. |
| 43 | `hide` | Hide |  |  | KEEP | A raw animal skin. Scrape and tan it for leather, or sew it into clothes. |
| 44 | `rope` | Rope |  | hand | KEEP | Twisted twine, strong enough to haul and to lash a frame. |
| 48 | `bone` | Bone |  |  | KEEP | A cleaned bone. Sharpen it into an arrow point, or boil it with hide for glue. |
| 55 | `rotten_food` | Rotten food |  |  | KEEP | Food that has gone bad. Do not eat it. |
| 70 | `sinew` | Sinew |  |  | KEEP | Tough strands from an animal's legs. Makes strong thread and bowstrings. |
| 71 | `animal_fat` | Animal fat |  |  | KEEP | Fat from a kill. Render it for tallow, or cook with it. |
| 72 | `feather` | Feather |  |  | KEEP | A bird's feather. Fletch arrows with it, or stuff a bed. |
| 100 | `log_oak` | Oak log |  |  | KEEP | A full-size oak log. Too big for the pack: carried alone on the shoulder. |
| 101 | `lumber_oak` | Oak lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn oak boards. |
| 102 | `beam_oak` | Oak beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared oak beams for building. |
| 103 | `log_beech` | Beech log |  |  | KEEP | A full-size beech log. Too big for the pack: carried alone on the shoulder. |
| 104 | `lumber_beech` | Beech lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn beech boards. |
| 105 | `beam_beech` | Beech beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared beech beams for building. |
| 106 | `log_birch` | Birch log |  |  | KEEP | A full-size birch log. Too big for the pack: carried alone on the shoulder. |
| 107 | `lumber_birch` | Birch lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn birch boards. |
| 108 | `beam_birch` | Birch beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared birch beams for building. |
| 109 | `log_scots_pine` | Scots pine log |  |  | KEEP | A full-size scots pine log. Too big for the pack: carried alone on the shoulder. |
| 110 | `lumber_scots_pine` | Scots pine lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn scots pine boards. |
| 111 | `beam_scots_pine` | Scots pine beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared scots pine beams for building. |
| 112 | `log_spruce` | Spruce log |  |  | KEEP | A full-size spruce log. Too big for the pack: carried alone on the shoulder. |
| 113 | `lumber_spruce` | Spruce lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn spruce boards. |
| 114 | `beam_spruce` | Spruce beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared spruce beams for building. |
| 124 | `log_tropical_hardwood` | Mahogany log |  |  | KEEP | A full-size mahogany log. Too big for the pack: carried alone on the shoulder. |
| 125 | `lumber_tropical_hardwood` | Mahogany lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn mahogany boards. |
| 126 | `beam_tropical_hardwood` | Mahogany beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared mahogany beams for building. |
| 148 | `log_walnut` | Walnut log |  |  | KEEP | A full-size walnut log. Too big for the pack: carried alone on the shoulder. |
| 149 | `lumber_walnut` | Walnut lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn walnut boards. |
| 150 | `beam_walnut` | Walnut beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared walnut beams for building. |
| 172 | `log_maple` | Sugar maple log |  |  | KEEP | A full-size sugar maple log. Too big for the pack: carried alone on the shoulder. |
| 173 | `lumber_maple` | Sugar maple lumber |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Sawn sugar maple boards. |
| 174 | `beam_maple` | Sugar maple beam |  |  | FUTURE | **RECOMMENDED: retire, superseded by Hardwood board (U6).** Heavy squared sugar maple beams for building. |
| 208 | `cut_stone_block` | Stone block |  | workbench L1 | KEEP | A squared block of stone, 40 by 20 by 20 cm. Heavy, and laid in courses with mortar. |
| 209 | `brick` | Brick |  | campfire | KEEP | A fired clay brick. Builds the clay hearth and the oven. |
| 210 | `mortar` | Clay mortar |  | hand | KEEP | A bucketful of sand and clay paste that binds stone blocks and bricks. |
| 228 | `nails` | Nails | iron | brick_forge L2 | KEEP | Small iron nails. Fix boards in builds; bronze ones do the same job. |
| 229 | `cobblestone` | Cobblestone |  | workbench L1 | KEEP | A rounded stone, dressed to lay in a wall or a floor. |
| 230 | `stone_shingle` | Stone shingle |  | workbench L1 | KEEP | A thin flat slab of stone for a roof. |
| 231 | `tar` | Tar |  | campfire | KEEP | Thick black tar, boiled down. Seals a flat roof and soaks logs against rot. |
| 232 | `hinges` | Hinges | iron | brick_forge L2 | KEEP | A pair of iron hinges for a door, a gate or a lid. |
| 233 | `wooden_pin` | Wooden pin |  | workbench L1 | KEEP | A hardwood pin or dowel that joins logs and beams without iron. |
| 234 | `wooden_block` | Wooden block |  | hand | KEEP | A short round of a small log, bark still on. Burns longer than firewood, or split it on a chopping block. |
| 236 | `firewood_soft` | Softwood firewood |  |  | KEEP | Split pine, spruce or fir. It catches fast and burns out quick. |
| 237 | `wooden_block_soft` | Softwood block |  | hand | KEEP | A short round of a small softwood log. Burns longer than soft firewood, or split it on a chopping block. |
| 238 | `saw_blade` | Saw blade |  | brick_forge L2 | KEEP | A pair of iron saw blades for a sawmill frame. |
| 239 | `water_wheel` | Water wheel |  | workbench L3 | KEEP | A wooden wheel with paddles. It turns where running water pushes it. |
| 270 | `wooden_arrow` | Wooden - Arrow |  | hand | KEEP | A hardened stick with feather fletching. Needs a bow. |
| 271 | `stone_arrow` | Stone - Arrow |  | hand | KEEP | An arrow with a flaked stone point. Hits harder than wood. |
| 279 | `flint` | Flint |  |  | KEEP | A hard grey stone that sparks when struck. Common near rivers. |
| 280 | `pyrite` | Pyrite |  |  | FUTURE | A brassy, heavy stone. Struck with flint it throws good sparks. |
| 281 | `obsidian` | Obsidian |  |  | FUTURE | Black volcanic glass. Breaks into razor-sharp edges, and is prized. |
| 282 | `processed_hide` | Scraped hide |  | hand | KEEP | A hide scraped clean of flesh and hair, ready for the tannery. |
| 283 | `leather` | Leather |  | tanning_rack | KEEP | Tanned hide: tough and supple. |
| 284 | `fine_leather` | Fine leather |  | campfire_pot | KEEP | The best of a batch of leather, soft and even. |
| 285 | `heavy_leather` | Heavy leather |  | tanning_rack | KEEP | Thick, stiff leather for armour and harness. |
| 286 | `rivets` | Rivets |  | brick_forge L2 | KEEP | Small iron pins that hold layers of leather or metal together. |
| 287 | `copper_ingot` | Copper ingot |  | forge | KEEP | Smelted copper. Soft, but good for early tools. |
| 288 | `tin_ingot` | Tin ingot |  | forge | KEEP | Smelted tin. Mixed with copper it makes bronze. |
| 289 | `bronze_ingot` | Bronze ingot |  | forge | KEEP | Copper and tin melted together. Harder than copper. |
| 290 | `flour` | Flour |  | hand | KEEP | Ground grain. The start of bread. |
| 291 | `yeast` | Yeast |  |  | FUTURE | A frothy starter that makes dough rise and ale ferment. |
| 301 | `copper_ore` | Copper ore |  |  | KEEP | A heavy lump streaked green and red. Smelts to copper in a forge. |
| 302 | `tin_ore` | Tin ore |  |  | KEEP | A dark, very heavy lump. Smelts to tin in a forge. |
| 303 | `iron_ore` | Iron ore |  |  | KEEP | A rusty brown lump. Smelts to iron in a clay bloomery, or in a brick forge. |
| 304 | `coal` | Coal |  |  | KEEP | A black lump that burns hot. Smelts iron and makes steel. |
| 332 | `wheat` | Wheat |  |  | KEEP | Golden heads of grain. Thresh and grind for flour. |
| 333 | `barley` | Barley |  |  | KEEP | Hardy grain for bread and brewing. |
| 334 | `carrot` | Carrot |  |  | KEEP | A sweet orange root grown in a tilled bed. |
| 335 | `potato` | Potato |  |  | KEEP | A starchy tuber that keeps well. |
| 336 | `turnip` | Turnip |  |  | KEEP | A round root, good in stew. |
| 337 | `flax` | Flax |  |  | KEEP | Tall stalks with strong fibres inside. |
| 338 | `wheat_seeds` | Wheat seeds |  |  | KEEP | Seeds for sowing wheat. Plant them in a tilled bed in spring. |
| 339 | `barley_seeds` | Barley seeds |  |  | KEEP | Seeds for sowing barley. Plant in a tilled bed. |
| 340 | `carrot_seeds` | Carrot seeds |  |  | KEEP | Seeds for sowing carrot. Plant in a tilled bed. |
| 341 | `potato_seeds` | Potato seeds |  |  | KEEP | Seeds for sowing potato. Plant in a tilled bed. |
| 342 | `turnip_seeds` | Turnip seeds |  |  | KEEP | Seeds for sowing turnip. Plant in a tilled bed. |
| 343 | `flax_seeds` | Flax seeds |  |  | KEEP | Seeds for sowing flax. Plant in a tilled bed. |
| 345 | `compost` | Compost |  | hand | KEEP | Rotted plant matter. Feeds a tilled bed. |
| 346 | `antler` | Antler |  |  | KEEP | A shed or taken antler. Hard, and can be worked like bone. |
| 347 | `tusk` | Tusk |  |  | KEEP | A boar's curved tusk. Ivory-hard. |
| 348 | `claw` | Claw |  |  | KEEP | A large predator's claw. A trophy or a charm. |
| 349 | `down` | Down |  |  | KEEP | Soft insulating feathers from a water bird. Warm for its weight. |
| 350 | `quill` | Quill |  |  | KEEP | A stiff spine from a porcupine. Sharp, and can be used as a pin or a point. |
| 351 | `hide_glue` | Hide glue |  | campfire_pot | KEEP | Hide boiled down to a sticky glue. Holds wood, bone and feathers. |
| 352 | `bone_arrow` | Bone - Arrow |  | hand | KEEP | An arrow with a sharpened bone point. |
| 360 | `sea_salt` | Salt |  | campfire_pot | KEEP | Salt boiled out of sea water, broken from rock salt or dug from a salt flat. Keeps meat and fish. |
| 364 | `wool` | Wool |  |  | KEEP | Fleece from a wild sheep. Warm, and spun into thread. |
| 365 | `linen` | Linen |  | hand | KEEP | Cloth woven from flax. Light, and cool in summer. |
| 374 | `oats` | Oats |  |  | KEEP | Hardy grain for porridge and bread in cool, wet ground. |
| 375 | `rye` | Rye |  |  | KEEP | A tough grain that grows where wheat will not. |
| 376 | `cabbage` | Cabbage |  |  | KEEP | A heavy leafy head. Keeps through the winter. |
| 377 | `onion` | Onion |  |  | KEEP | A pungent bulb. Flavours food and keeps well. |
| 378 | `peas` | Peas |  |  | KEEP | Green pods of sweet peas. Dry them for winter. |
| 379 | `beet` | Beet |  |  | KEEP | A deep red root, sweet when roasted. |
| 380 | `oats_seeds` | Oats seeds |  |  | KEEP | Seeds for sowing oats. Plant in a tilled bed. |
| 381 | `rye_seeds` | Rye seeds |  |  | KEEP | Seeds for sowing rye. Plant in a tilled bed. |
| 382 | `cabbage_seeds` | Cabbage seeds |  |  | KEEP | Seeds for sowing cabbage. Plant in a tilled bed. |
| 383 | `onion_seeds` | Onion seeds |  |  | KEEP | Seeds for sowing onion. Plant in a tilled bed. |
| 384 | `peas_seeds` | Peas seeds |  |  | KEEP | Seeds for sowing peas. Plant in a tilled bed. |
| 385 | `beet_seeds` | Beet seeds |  |  | KEEP | Seeds for sowing beet. Plant in a tilled bed. |
| 413 | `tallow` | Tallow |  | campfire_pot | KEEP | Animal fat rendered clean in a pot. Burns well and keeps. |
| 414 | `soap` | Soap |  | campfire_pot | KEEP | Tallow and ash lye boiled and cut into a bar. Cleans wounds and cloth. |
| 415 | `leather_strap` | Leather strap |  | workbench | KEEP | A strip of leather for straps, belts and harness. |
| 426 | `radish` | Radish |  |  | KEEP | A peppery red root that grows fast in cool ground. |
| 427 | `lettuce` | Lettuce |  |  | KEEP | Soft green leaves that grow fast and spoil fast. |
| 428 | `radish_seeds` | Radish seeds |  |  | KEEP | Seeds for sowing radish. Plant in a tilled bed. |
| 429 | `lettuce_seeds` | Lettuce seeds |  |  | KEEP | Seeds for sowing lettuce. Plant in a tilled bed. |
| 430 | `sea_water` | Sea water |  |  | KEEP | Salt water taken from the sea. Not for drinking. Boil it down for salt. |
| 517 | `fibre_cloth` | Fibre cloth |  | hand | KEEP | Plant fibre woven flat on a frame. Covers a bed, and wraps a canopy. |
| 518 | `hazel_bush` | Hazel bush |  |  | KEEP | A hazel bush dug up whole, roots and all. Plant it again somewhere else. |
| 519 | `bramble_bush` | Bramble bush |  |  | KEEP | A bramble bush dug up whole, roots and all. Plant it again somewhere else. |
| 520 | `juniper_bush` | Juniper bush |  |  | KEEP | A juniper bush dug up whole, roots and all. Plant it again somewhere else. |
| 521 | `gorse_bush` | Gorse bush |  |  | KEEP | A gorse bush dug up whole, roots and all. Plant it again somewhere else. |
| 522 | `dwarf_birch_bush` | Dwarf birch bush |  |  | KEEP | A dwarf birch bush dug up whole, roots and all. Plant it again somewhere else. |
| 523 | `saltbush_bush` | Saltbush bush |  |  | KEEP | A saltbush bush dug up whole, roots and all. Plant it again somewhere else. |
| 524 | `cactus_bush` | Cactus bush |  |  | KEEP | A cactus bush dug up whole, roots and all. Plant it again somewhere else. |
| 525 | `raspberry_bush` | Raspberry bush |  |  | KEEP | A raspberry bush dug up whole, roots and all. Plant it again somewhere else. |
| 526 | `elder_bush` | Elder bush |  |  | KEEP | An elder bush dug up whole, roots and all. Plant it again somewhere else. |
| 527 | `wild_rose_bush` | Wild rose bush |  |  | KEEP | A wild rose bush dug up whole, roots and all. Plant it again somewhere else. |
| 528 | `blackthorn_bush` | Blackthorn bush |  |  | KEEP | A blackthorn bush dug up whole, roots and all. Plant it again somewhere else. |
| 529 | `hawthorn_bush` | Hawthorn bush |  |  | KEEP | A hawthorn bush dug up whole, roots and all. Plant it again somewhere else. |
| 530 | `sea_buckthorn_bush` | Sea buckthorn bush |  |  | KEEP | A sea buckthorn bush dug up whole, roots and all. Plant it again somewhere else. |
| 531 | `rosemary_bush` | Rosemary bush |  |  | KEEP | A rosemary bush dug up whole, roots and all. Plant it again somewhere else. |
| 532 | `wild_banana_bush` | Wild banana bush |  |  | KEEP | A wild banana bush dug up whole, roots and all. Plant it again somewhere else. |
| 533 | `prickly_pear_bush` | Prickly pear bush |  |  | KEEP | A prickly pear bush dug up whole, roots and all. Plant it again somewhere else. |
| 534 | `drakethorn_bush` | Drakethorn bush |  |  | KEEP | A drakethorn bush dug up whole, roots and all. Plant it again somewhere else. |
| 535 | `sunberry_bush` | Sunberry bush |  |  | KEEP | A sunberry bush dug up whole, roots and all. Plant it again somewhere else. |
| 536 | `hagwillow_bush` | Hag willow bush |  |  | KEEP | A hag willow bush dug up whole, roots and all. Plant it again somewhere else. |
| 537 | `honeyspindle_bush` | Honeyspindle bush |  |  | KEEP | A honeyspindle bush dug up whole, roots and all. Plant it again somewhere else. |
| 538 | `sleetberry_bush` | Sleetberry bush |  |  | KEEP | A sleetberry bush dug up whole, roots and all. Plant it again somewhere else. |
| 539 | `sunsilver_vine_bush` | Sunsilver vine bush |  |  | KEEP | A sunsilver vine bush dug up whole, roots and all. Plant it again somewhere else. |
| 540 | `wooden_block_large` | Large wooden block |  |  | KEEP | A thick round of a big trunk. Split it into firewood or 4 small blocks, or make a chopping block of it. |
| 541 | `wooden_block_soft_large` | Large softwood block |  |  | KEEP | A thick round of a big softwood trunk. Split it into soft firewood or 4 small blocks, or a chopping block. |
| 547 | `charcoal` | Charcoal |  | campfire | KEEP | Firewood burned slow and starved of air. The best smelting fuel. |
| 548 | `wool_cloth` | Wool cloth |  | hand | KEEP | Wool spun and woven into a warm cloth. Tunics, caps and rugs are cut from it. |
| 549 | `fur` | Fur |  |  | KEEP | A thick pelt with the hair on, from a wolf, fox or bear. The warmest thing to wear. |
| 550 | `fish` | Fish |  |  | KEEP | Any fish: trout, pike, perch, salmon and the rest. |
| 551 | `mushrooms` | Mushrooms |  |  | KEEP | Any edible mushroom: porcini, chanterelles, morels or puffball. |
| 552 | `nuts` | Nuts |  |  | KEEP | Any nuts: hazelnuts, chestnuts, walnuts or beechnuts. |
| 553 | `berries` | Berries |  |  | KEEP | Any sweet berries: raspberries, blueberries, strawberries and the rest. |
| 554 | `fuel` | Fuel |  |  | KEEP | Charcoal or coal: what a forge burns to smelt. |
| 555 | `pitch` | Pitch |  |  | KEEP | Resin, pine tar or animal fat: what a torch head burns. |
| 556 | `crystal_lens` | Crystal lens |  |  | KEEP | Clear quartz worn smooth into a lens. A rare find when digging rock or gravel. |
| 666 | `horn_pane` | Horn pane |  | workbench L1 | KEEP | A thin pane of scraped horn. Lets lantern light through. |
| 667 | `lamp_oil` | Lamp oil |  | campfire_pot | KEEP | Oil from herring, linseed or walnuts. Burns three game days in an iron lantern. |
| 730 | `clay_pipe` | Clay pipe |  | campfire | KEEP | A fired clay pipe section. Two make a length of closed water pipe. |
| 757 | `horn` | Horn |  |  | KEEP | A hollow horn from a goat, sheep or ox. Pressed thin it lets light through; carved, it holds a drink. |
| 758 | `gut` | Gut |  |  | KEEP | Cleaned intestine from a large kill. Casing for sausage, and strong cord when dried and twisted. |
| 759 | `toggle` | Toggle |  | hand | KEEP | A short bone peg with a groove. Fastens a belt or a cloak through a loop. |
| 760 | `hook` | Hook |  | hand | KEEP | A fish hook ground from bone. A fishing rod needs one. |
| 769 | `worm` | Worm |  |  | KEEP | A fat earthworm turned up by the spade in rich soil. Fish take it as bait. |
| 801 | `carved_stone_block` | Carved stone block |  | stonecutters_bench | KEEP | A stone block dressed smooth and carved at the edges. For fine walls and doorways. |
| 802 | `carved_stone_shingle` | Carved stone shingle |  | stonecutters_bench | KEEP | A stone shingle cut thin and even, so a roof lies tight. |
| 805 | `fruit` | Fruit |  |  | KEEP | Any juicy fruit or berry: apples, pears, plums, cherries, sloes and the berries. |
| 809 | `bonemeal` | Bonemeal |  | hand | FUTURE | Bone ground to a pale powder. Feeds a crop bed as well as compost. |
| 810 | `parsnip` | Parsnip |  |  | FUTURE | A pale sweet root grown in a tilled bed. Frost makes it sweeter. |
| 811 | `parsnip_seeds` | Parsnip seeds |  |  | FUTURE | Seeds for sowing parsnip. Plant in a tilled bed. |
| 814 | `sling_stone` | Sling stone |  | hand | KEEP | A smooth round stone the size of an egg, picked for the sling. |
| 817 | `fire_arrow` | Fire arrow |  | hand | KEEP | A wooden arrow with a pitch-soaked fibre head. Light it at a fire before you loose it. |
| 818 | `fishing_bait` | Fishing bait |  | hand | KEEP | Cut worm or fish on the hook. Fish bite sooner. |
| 821 | `knife` | Knife |  |  | KEEP | Any knife: stone, obsidian, bronze or better. |
| 833 | `vegetable` | Vegetable |  |  | KEEP | Any root or cabbage-type vegetable: carrot, beet, onion, turnip, cabbage, parsnip, radish. |
| 839 | `claw_necklace` | Claw - Necklace |  | hand | FUTURE | Animal claws strung on a cord. Worn for luck and to show what you have hunted. |
| 853 | `bark_shingle` | Bark shingle |  | hand | KEEP | A flat slab of bark, peeled and pressed. Laid in rows it roofs a log cabin. |
| 854 | `wooden_shingle` | Wooden shingle |  | workbench | KEEP | A thin split board, thicker at one end. Laid in rows it roofs a plank house. |
| 855 | `clay_roof_tile` | Clay roof tile |  | kiln | KEEP | A curved tile of fired clay. Roofs a brick or concrete house and does not burn. |
| 856 | `limestone` | Limestone |  |  | KEEP | A pale lump of soft rock. Burnt in a kiln it crumbles to lime. |
| 857 | `lime_powder` | Lime powder |  | kiln | KEEP | Burnt limestone ground to a white powder. The binder in concrete. |
| 858 | `concrete` | Concrete |  | mixer | KEEP | Lime powder, sand and stone mixed wet. Sets hard as rock in a mould or a wall. |
| 859 | `iron_band` | Iron band |  | brick_forge L3 | KEEP | A flat iron strap with nail holes. Ties concrete walls and gates against a siege. |
| 894 | `bronze_nails` | Bronze nails | bronze | forge | KEEP | Small bronze nails. Fix boards in builds, the same as iron ones. |
| 895 | `bronze_hinges` | Bronze hinges | bronze | forge | KEEP | A pair of bronze hinges for a door, a gate or a lid. |

Already retired (56; numbers never reused): 115 `log_alder` Alder log; 116 `lumber_alder` Alder lumber; 117 `beam_alder` Alder beam; 118 `log_willow` Willow log; 119 `lumber_willow` Willow lumber; 120 `beam_willow` Willow beam; 121 `log_coconut_palm` Coconut palm log; 122 `lumber_coconut_palm` Coconut palm lumber; 123 `beam_coconut_palm` Coconut palm beam; 127 `log_acacia` Acacia log; 128 `lumber_acacia` Acacia lumber; 129 `beam_acacia` Acacia beam; 130 `log_mangrove` Mangrove log; 131 `lumber_mangrove` Mangrove lumber; 132 `beam_mangrove` Mangrove beam; 133 `log_rowan` Rowan log; 134 `lumber_rowan` Rowan lumber; 135 `beam_rowan` Rowan beam; 136 `log_wild_apple` Crab apple log; 137 `lumber_wild_apple` Crab apple lumber; 138 `beam_wild_apple` Crab apple beam; 139 `log_wild_pear` Wild pear log; 140 `lumber_wild_pear` Wild pear lumber; 141 `beam_wild_pear` Wild pear beam; 142 `log_wild_cherry` Wild cherry log; 143 `lumber_wild_cherry` Wild cherry lumber; 144 `beam_wild_cherry` Wild cherry beam; 145 `log_sweet_chestnut` Sweet chestnut log; 146 `lumber_sweet_chestnut` Sweet chestnut lumber; 147 `beam_sweet_chestnut` Sweet chestnut beam; 151 `log_date_palm` Date palm log; 152 `lumber_date_palm` Date palm lumber; 153 `beam_date_palm` Date palm beam; 154 `log_mirrorbark` Mirrorbark log; 155 `lumber_mirrorbark` Mirrorbark lumber; 156 `beam_mirrorbark` Mirrorbark beam; 157 `log_wardpine` Wardpine log; 158 `lumber_wardpine` Wardpine lumber; 159 `beam_wardpine` Wardpine beam; 160 `log_hearthwood` Hearthwood log; 161 `lumber_hearthwood` Hearthwood lumber; 162 `beam_hearthwood` Hearthwood beam; 163 `log_everember` Everember log; 164 `lumber_everember` Everember lumber; 165 `beam_everember` Everember beam; 166 `log_witness_tree` Witness tree log; 167 `lumber_witness_tree` Witness tree lumber; 168 `beam_witness_tree` Witness tree beam; 169 `log_balsam_fir` Balsam fir log; 170 `lumber_balsam_fir` Balsam fir lumber; 171 `beam_balsam_fir` Balsam fir beam; 226 `rough_plank` Rough plank; 227 `fine_board` Fine board; 278 `kindling_duplicate` Kindling; 292 `salt` Salt; 354 `fibre_arrow` Fibre - Arrow.

### A.clothing (33 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 60 | `grass_skirt` | Fibre - Skirt |  | hand | KEEP | Woven grass hung from the waist. Barely warm, and it rots quickly. |
| 61 | `grass_cloak` | Fibre - Cloak |  | hand | KEEP | Woven grass over the shoulders. Keeps a little wind off. |
| 62 | `fibre_sandals` | Fibre - Sandals |  | hand | KEEP | Twisted fibre soles tied to the foot. |
| 63 | `hide_cloak` | Hide - Cloak |  | hand | KEEP | A wrapped animal hide. Warm over the shoulders. |
| 64 | `hide_boots` | Hide - Boots |  | hand | KEEP | Hide stitched around the foot. Warm and tough. |
| 65 | `hide_hood` | Hide - Hood |  | hand | KEEP | A close hood of hide with the hair turned in. |
| 66 | `hide_mittens` | Hide - Mittens |  | hand | KEEP | Stitched hide mittens. Warm hands. |
| 305 | `hide_tunic` | Hide - Tunic |  | hand | KEEP | A sewn hide shirt with sleeves. Warmer than a cloak. |
| 306 | `hide_trousers` | Hide - Trousers |  | hand | KEEP | Hide sewn into trousers. Warm, and tough on rough ground. |
| 307 | `hide_gloves` | Hide - Gloves |  | hand | KEEP | Stitched hide gloves with fingers. For work and cold. |
| 324 | `leather_cap` | Leather - Cap |  | workbench L2 | KEEP | A close leather cap. Better than bare hide. |
| 325 | `leather_jerkin` | Leather - Jerkin |  | workbench L2 | KEEP | A stiff leather vest. Turns a glancing blow. |
| 326 | `bronze_helm` | Bronze - Helm |  | forge | FUTURE | A beaten bronze cap with a nose guard. |
| 327 | `gambeson` | Fibre - Gambeson |  | workbench L2 | KEEP | Quilted cloth padding. Cheap armour that soaks a blow. |
| 328 | `iron_helm` | Iron - Helm |  | brick_forge L2 | FUTURE | A riveted iron helmet. |
| 329 | `mail_shirt` | Iron - Mail shirt |  | brick_forge L2 | FUTURE | Rings of iron riveted together. Heavy but sound. |
| 330 | `steel_helm` | Steel - Helm |  | brick_forge L3 | FUTURE | A fitted steel helm with leather lining. |
| 331 | `plate_cuirass` | Steel - Cuirass |  | brick_forge L3 | FUTURE | Shaped steel plates over a leather harness. The best body armour. |
| 366 | `wool_tunic` | Wool - Tunic |  | workbench L3 | KEEP | A woven wool shirt. Warm. |
| 367 | `wool_trousers` | Wool - Trousers |  | workbench L3 | KEEP | Heavy woven wool trousers. |
| 368 | `wool_cap` | Wool - Cap |  | workbench L3 | KEEP | A snug knitted wool cap. |
| 369 | `wool_mittens` | Wool - Mittens |  | workbench L3 | KEEP | Thick wool mittens. |
| 370 | `linen_shirt` | Linen - Shirt |  | workbench L3 | KEEP | A light linen shirt. Cool in summer heat. |
| 371 | `fur_cloak` | Fur - Cloak |  | workbench L3 | KEEP | A heavy cloak of fur pelts. The warmest body cover. |
| 372 | `fur_hat` | Fur - Hat |  | workbench L3 | KEEP | A fur hat with ear flaps. |
| 373 | `fur_boots` | Fur - Boots |  | workbench L3 | KEEP | Fur boots with the hair turned in. |
| 764 | `leather_trousers` | Leather - Trousers |  | workbench L2 | KEEP | Leather trousers laced with straps. Tougher than hide and better in the wet. |
| 765 | `leather_boots` | Leather - Boots |  | workbench L2 | KEEP | Leather boots with a strapped ankle. They keep the feet dry for longer. |
| 766 | `leather_gloves` | Leather - Gloves |  | workbench L2 | KEEP | Leather gloves with fingers. For work, the bowstring and the cold. |
| 768 | `straw_hat` | Straw - Hat |  | hand | KEEP | A wide hat of plaited straw. Light, and it keeps sun and a little rain off. |
| 820 | `wooden_snowshoes` | Snowshoes |  | workbench | KEEP | Bent-wood frames laced with leather. Spread your weight so you sink less in snow. |
| 838 | `bronze_scale_shirt` | Bronze - Scale shirt |  | forge | FUTURE | Bronze scales laced over leather. Bronze body armour, lighter than mail. |

Already retired (1; numbers never reused): 67 `hide_leggings` Hide - Leggings.

### A.gear (6 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 50 | `backpack` | Hide - Backpack |  | hand | KEEP | A hide pack with straps. Worn on the back, it lets you carry more. |
| 272 | `quiver` | Hide - Quiver |  | hand | KEEP | A hide tube worn on the back. Holds 40 arrows. |
| 762 | `leather_quiver` | Leather - Quiver |  | workbench L2 | KEEP | A stiff leather tube worn on the back. Holds 60 arrows and keeps them dry. |
| 767 | `leather_backpack` | Leather - Backpack |  | workbench L3 | KEEP | A leather pack with a frame of straps. Worn on the back, it carries more than a hide pack. |
| 819 | `bedroll` | Bedroll |  | hand | KEEP | Hides sewn into a roll to sleep on. Better rest in the open, but it is not a bed. |
| 828 | `leather_belt` | Leather - Belt |  | workbench L2 | KEEP | A leather belt with a toggle. Hangs a pouch, a knife or a quiver at the waist. |

### A.container (7 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 39 | `wooden_bowl` | Wooden bowl |  | hand | KEEP | A bowl hollowed from a bolt of wood. Carries a little water. |
| 40 | `clay_pot` | Clay - Pot |  | campfire | KEEP | A fired pot of clay. Holds three litres of water. |
| 41 | `bucket` | Bucket |  | hand | KEEP | A wooden bucket bound with cord. Holds eight litres of water. |
| 42 | `waterskin` | Waterskin |  | hand | KEEP | A sewn skin bag for carrying a drink. |
| 308 | `clay_jug` | Clay jug |  | campfire | KEEP | A tall fired jug with a handle and a narrow mouth. Holds water, ale or mead. |
| 812 | `mug` | Mug |  | campfire | KEEP | A small fired clay cup with a handle. Holds a drink. |
| 835 | `copper_pot` | Copper - Pot |  | forge | FUTURE | A hammered copper pot. Holds three litres and cooks soups over a fire. |

### A.medicine (5 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 16 | `poultice` | Herb poultice |  | hand | KEEP | Crushed herb leaves bound on a wound. |
| 17 | `bandage` | Herb bandage |  | hand | KEEP | Leaves and fibre bound round a wound. |
| 309 | `herb_salve` | Herb salve |  | hand | KEEP | Comfrey worked into fat. Soothes burns and sore skin. |
| 310 | `splint` | Splint |  | hand | KEEP | Two straight sticks bound to a limb to hold a broken bone still. |
| 808 | `herb_antidote` | Herb antidote |  | hand | KEEP | Plantain and comfrey ground into water. A cure for poison and a sick stomach. |

### A.food (116 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 15 | `roast_forage` | Roasted forage |  | clay_hearth | KEEP | Nuts, mushrooms or fruit roasted on the hearth. |
| 51 | `energy_bar` | Nut cake |  | hand | KEEP | Nuts pressed with honey into a cake. Quick energy that wears on your fitness. |
| 52 | `herbal_tea` | Herbal tea |  | campfire_pot | KEEP | Mint steeped in hot water. A small lift of energy. |
| 53 | `magic_tonic` | Magic tonic |  |  | FUTURE | A shimmering draught. A great lift of energy. |
| 57 | `stomach_tea` | Stomach tea |  | campfire_pot | KEEP | A folk remedy: mint and chamomile steeped for a sick stomach. Settles vomiting and the runs. |
| 58 | `chamomile_tea` | Chamomile tea |  | campfire_pot | KEEP | A folk remedy: chamomile flowers steeped in water. Calms the stomach and helps you sleep. |
| 59 | `willow_bark_tea` | Willow bark tea |  | campfire_pot | KEEP | A folk remedy: bitter willow bark steeped for pain and fever. It also eases a sick stomach a little. |
| 68 | `raw_meat` | Raw meat |  |  | KEEP | Fresh meat. Cook it before you eat it, and do not keep it long. |
| 69 | `roast_meat` | Roast meat |  |  | KEEP | Meat roasted over a fire. Filling, and it keeps a couple of days. |
| 76 | `trout` | Trout |  |  | KEEP | A cold-water fish from streams. Cook it before you eat it. |
| 77 | `perch` | Perch |  |  | KEEP | A common fish of ponds and lakes. Cook it before you eat it. |
| 78 | `carp` | Carp |  |  | KEEP | A heavy fish of still ponds. Cook it before you eat it. |
| 79 | `pike` | Pike |  |  | KEEP | A long hunting fish of lakes. Cook it before you eat it. |
| 80 | `roast_fish` | Roast fish |  |  | KEEP | Fish cooked over a fire. Filling, and keeps a day or two. |
| 175 | `berry_compote` | Berry compote |  | preserving_jar | KEEP | Berries stewed sweet. Quick energy. |
| 176 | `nut_paste` | Nut paste |  | campfire_pot | KEEP | Ground hazelnuts and honey. Keeps well. |
| 177 | `roast_roots` | Roast roots |  | clay_hearth | KEEP | Roots baked in the embers. Plain and filling. |
| 178 | `acorn_mash` | Acorn mash |  | campfire_pot | KEEP | Leached acorns boiled to a mash. Famine food. |
| 179 | `baked_apples` | Baked apples |  | clay_hearth | KEEP | Crab apples baked sweet in the ashes. |
| 180 | `mushroom_skewer` | Mushroom skewer |  | clay_hearth | KEEP | Mushrooms and wild garlic grilled on a stick. |
| 181 | `herb_fish` | Herb fish |  | campfire | KEEP | A fish roasted with wild herbs. |
| 182 | `garlic_meat` | Garlic meat |  | campfire | KEEP | Meat roasted with wild garlic and rosemary. |
| 183 | `chestnut_cakes` | Chestnut cakes |  | clay_hearth | KEEP | Flat cakes of chestnut, honey and linseed. Good travelling food. |
| 184 | `fruit_leather` | Fruit leather |  | clay_hearth | KEEP | Dried fruit pressed flat. Keeps for a long journey. |
| 185 | `smoked_fish` | Smoked fish |  | smoker | KEEP | Salted fish smoked over the fire. Lasts for weeks. |
| 186 | `hunters_stew` | Hunter's stew |  | campfire_pot | KEEP | A thick meat and root stew. Warms you through. |
| 187 | `forager_stew` | Forager's stew |  | campfire_pot | KEEP | Greens, roots and mushrooms in one pot. |
| 188 | `fish_stew` | Fish stew |  | campfire_pot | KEEP | Perch, cress and root in a thin broth. |
| 189 | `trail_bread` | Trail bread |  | clay_hearth | KEEP | Dense seed and nut loaves. Barely spoils. |
| 190 | `hearty_pottage` | Hearty pottage |  | campfire_pot | KEEP | A rich pot of flour, roots, herbs and fat. Fills and warms. |
| 191 | `feast_roast` | Roast beast |  | campfire | KEEP | Herb-rubbed, fat-basted roast. The best meal a campfire makes. |
| 273 | `flatbread` | Flatbread |  | clay_hearth | KEEP | A flat cake baked on hot clay. Plain and filling. |
| 274 | `honey_loaf` | Honey loaf |  | oven | KEEP | A sweet loaf baked in the oven. Keeps well. |
| 275 | `roast_joint` | Rosemary joint |  | oven | KEEP | Meat roasted whole in the oven with herbs. |
| 355 | `seaweed` | Seaweed |  |  | KEEP | Wet strands of kelp and wrack from the tide line. Edible, salty and rich in minerals. |
| 356 | `shellfish` | Shellfish |  |  | KEEP | Mussels, limpets and cockles prised off the shore rocks. Eat cooked. |
| 357 | `crab_meat` | Crab meat |  |  | KEEP | White meat from a shore crab. |
| 358 | `egg` | Egg |  |  | KEEP | A wild bird's egg from a nest. Boil or fry it. |
| 359 | `seal_meat` | Seal meat |  |  | KEEP | Dark, rich meat from a seal. Cook it well. |
| 361 | `roast_shellfish` | Steamed shellfish |  |  | KEEP | Shellfish steamed open on hot coals. Salty and sweet. |
| 362 | `boiled_egg` | Boiled egg |  | campfire_pot | KEEP | An egg boiled hard. Keeps well and fills the belly. |
| 363 | `roast_seal` | Seal steak |  |  | KEEP | Seal meat roasted over a fire. Rich and fatty. |
| 386 | `oat_porridge` | Oat porridge |  | campfire_pot | KEEP | Oats simmered thick with crushed nuts. |
| 387 | `barley_broth` | Barley broth |  | campfire_pot | KEEP | A thin warm broth of barley and carrot. |
| 388 | `rye_flatbread` | Rye flatbread |  | clay_hearth | KEEP | A dense salty flatbread baked on the hot clay. |
| 389 | `pea_soup` | Pea soup |  | campfire_pot | KEEP | A thick green soup of peas and onion. |
| 390 | `turnip_mash` | Turnip mash |  | campfire_pot | KEEP | Boiled turnip mashed with fat. |
| 391 | `baked_potato` | Baked potato |  | clay_hearth | KEEP | A potato baked in the embers and split with fat. |
| 392 | `cabbage_stew` | Cabbage stew |  | campfire_pot | KEEP | Cabbage, meat and onion stewed together. |
| 393 | `beet_roast` | Beet roast |  | clay_hearth | KEEP | Beets roasted in the coals with thyme. |
| 394 | `onion_roast` | Onion roast |  | clay_hearth | KEEP | Onions roasted soft and sweet in fat. |
| 395 | `seaweed_soup` | Seaweed soup |  | campfire_pot | KEEP | A salty soup of seaweed and shellfish. |
| 396 | `mussel_stew` | Mussel stew |  | campfire_pot | KEEP | Shellfish stewed with wild garlic. |
| 397 | `crab_cakes` | Crab cakes |  | campfire | KEEP | Crab meat and flour fried into cakes. |
| 398 | `egg_nettle_fry` | Egg and nettle fry |  | campfire_pot | KEEP | Eggs fried with young nettle greens. |
| 399 | `herb_omelette` | Herb omelette |  | campfire_pot | KEEP | Eggs beaten with thyme and fried. |
| 400 | `seal_stew` | Seal stew |  | campfire_pot | KEEP | Dark seal meat stewed with turnip. |
| 401 | `venison_pie` | Venison pie |  | oven | KEEP | Meat and fat baked in a flour crust. |
| 402 | `fish_pie` | Fish pie |  | oven | KEEP | Fish and onion baked in a flour crust. |
| 403 | `juniper_trout` | Juniper trout |  | campfire | KEEP | A fish roasted over the coals with juniper berries. |
| 404 | `garlic_bread` | Garlic bread |  | clay_hearth | KEEP | Flat bread rubbed with wild garlic. |
| 405 | `oat_cakes` | Oat cakes |  | clay_hearth | KEEP | Oats and fat pressed and baked into cakes. |
| 406 | `jerky` | Jerky |  | drying_rack | KEEP | Salted meat strips dried over smoke. Keeps for weeks. |
| 407 | `salted_fish` | Salted fish |  | campfire_pot | KEEP | Fish cured in salt in a pot. Keeps for weeks. |
| 408 | `dried_berries` | Dried berries |  | drying_rack | KEEP | Berries dried by the fire. Sweet and long lasting. |
| 409 | `sauerkraut` | Sauerkraut |  | preserving_jar | KEEP | Salted cabbage fermented in a pot. |
| 410 | `hazelnut_butter` | Hazelnut butter |  | campfire_pot | KEEP | Hazelnuts ground to a rich paste. |
| 411 | `banana_fritter` | Banana fritter |  | clay_hearth | KEEP | Banana and flour fried golden. |
| 412 | `cactus_fry` | Cactus fry |  | clay_hearth | KEEP | Prickly pear fried with onion. |
| 416 | `milk` | Milk |  |  | FUTURE | Fresh milk from a tame animal. Drink it soon or make it keep. |
| 417 | `butter` | Butter |  | hand | FUTURE | Milk churned thick and golden. Keeps for weeks. |
| 418 | `cheese` | Cheese |  | campfire_pot | FUTURE | Milk curdled, pressed and salted. Keeps for months. |
| 419 | `salmon` | Salmon |  |  | KEEP | A big silver river fish that runs upstream in autumn. Rich and oily. |
| 420 | `herring` | Herring |  |  | KEEP | A small oily silver sea fish that swims in shoals. |
| 421 | `mackerel` | Mackerel |  |  | KEEP | A striped oily sea fish of summer. Spoils fast, so cook it soon. |
| 422 | `smelt` | Smelt |  |  | KEEP | A tiny silver fish from shallow coastal water. Fry it whole. |
| 423 | `eel` | Eel |  |  | KEEP | A long slippery fish. Must be cooked: raw eel blood is toxic. |
| 424 | `cod` | Cod |  |  | KEEP | A big white sea fish. Lean and flaky when cooked. |
| 431 | `apple_early` | Early summer apple |  |  | KEEP | A small tart apple of July. Eat it soon: it keeps only 3 game days. |
| 432 | `apple_summer` | Summer apple |  |  | KEEP | A sweet juicy apple of August. Keeps about 7 game days. |
| 433 | `apple_autumn` | Autumn apple |  |  | KEEP | A crisp all-round apple of September and October. Keeps about 20 game days. |
| 434 | `apple_keeping` | Keeping apple |  |  | KEEP | A hard russet apple picked late. Stored cool and dark it lasts until spring. |
| 435 | `apple_cooking` | Cooking apple |  |  | KEEP | A big sour apple that goes soft and sweet when cooked. Keeps a month. |
| 436 | `pear_summer` | Summer pear |  |  | KEEP | A small sweet pear of August. It goes soft in 4 game days. |
| 437 | `pear_autumn` | Autumn pear |  |  | KEEP | A juicy pear of September and October. Keeps a couple of weeks. |
| 438 | `pear_winter` | Winter pear |  |  | KEEP | A hard pear picked in November that ripens in store. Lasts into February. |
| 439 | `sour_cherries` | Sour cherries |  |  | KEEP | Dark tart cherries of July. Good cooked, sharp raw. They spoil in 2 game days. |
| 440 | `plums` | Plums |  |  | KEEP | Soft purple plums of August and September. They spoil in 4 game days. |
| 441 | `damsons` | Damsons |  |  | KEEP | Small tart blue plums of autumn. Best cooked or preserved. |
| 442 | `quince` | Quince |  |  | KEEP | A hard fragrant yellow fruit of late autumn. Bitter raw, sweet and pink cooked. |
| 443 | `medlar` | Medlar |  |  | KEEP | A brown fruit eaten only after frost has softened it. Sweet and winey. |
| 444 | `figs` | Figs |  |  | KEEP | Soft sweet figs of late summer. They spoil in days unless dried. |
| 445 | `olives` | Olives |  |  | KEEP | Small bitter fruits of late autumn. Cured in salt they keep for months. |
| 446 | `pomegranates` | Pomegranates |  |  | KEEP | A hard red fruit full of juicy seeds. Keeps for weeks. |
| 447 | `mangoes` | Mangoes |  |  | KEEP | A big sweet orange fruit of the tropics. Ripe ones spoil fast. |
| 448 | `oranges` | Oranges |  |  | KEEP | Sweet round citrus of winter. Keeps well. |
| 449 | `lemons` | Lemons |  |  | KEEP | Sour yellow citrus. A little juice brightens food, and it keeps for weeks. |
| 450 | `dried_apples` | Dried apples |  | drying_rack | KEEP | Autumn apples sliced and dried by the fire. Chewy and sweet, they keep for months. |
| 451 | `apple_sauce` | Apple sauce |  | preserving_jar | KEEP | Cooking apples stewed soft with honey. |
| 452 | `apple_pie` | Apple pie |  | oven | KEEP | Cooking apples and fat baked in a flour crust. |
| 453 | `plum_jam` | Plum jam |  | preserving_jar | KEEP | Plums boiled down with honey. Keeps through winter in a crock. |
| 454 | `stewed_pears` | Stewed pears |  | campfire_pot | KEEP | Pears stewed soft in honey. Good hot or cold. |
| 455 | `preserved_damsons` | Preserved damsons |  | preserving_jar | KEEP | Damsons sealed in sweet syrup. A winter store. |
| 456 | `dried_figs` | Dried figs |  | drying_rack | KEEP | Figs dried until sticky and sweet. They last for months. |
| 457 | `quince_paste` | Quince paste |  | campfire_pot | KEEP | Quince boiled with honey into a firm sweet paste. |
| 483 | `stewed_berries` | Stewed berries |  | campfire_pot | KEEP | Berries stewed in a pot with a splash of water. Sweeter than raw. |
| 484 | `wild_apples` | Wild apples |  |  | KEEP | Small green-red apples from forest trees. Sweet-sour and good raw. |
| 485 | `nettles` | Nettles |  |  | KEEP | Stinging green leaves. Safe once steeped or cooked: make tea, soup or a fry. |
| 486 | `nettle_tea` | Nettle tea |  | campfire_pot | KEEP | Nettle leaves steeped in hot water. Green, earthy, and good for tired muscles. |
| 803 | `meat_skewer` | Meat skewer |  | campfire | KEEP | Chunks of meat and wild garlic roasted on a stick. |
| 804 | `sausage` | Sausage |  | campfire_pot | KEEP | Salted meat packed into gut and simmered. Keeps for weeks. |
| 806 | `fruit_juice` | Fruit juice |  | hand | KEEP | Fresh fruit crushed with a little water. Quenches thirst and gives a little strength. |
| 834 | `pickled_vegetables` | Pickled vegetables |  | preserving_jar | FUTURE | Roots and cabbage packed in salt brine. Sour, and keeps for months. |
| 836 | `fish_soup` | Fish soup |  | campfire_pot | FUTURE | Fish, wild garlic and salt simmered in a copper pot. Hot and filling. |
| 837 | `meatballs` | Meatballs |  | campfire_pot | FUTURE | Minced meat rolled with flour and salt and cooked in a copper pot. |

Already retired (1; numbers never reused): 56 `medicine` Medicine.

### A.coin (4 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 96 | `coin_copper` | Copper coin |  |  | FUTURE | A small copper coin. The smallest money there is. |
| 97 | `coin_bronze` | Bronze coin |  |  | FUTURE | A bronze coin, worth ten copper. |
| 98 | `coin_silver` | Silver coin |  |  | FUTURE | A silver coin, worth ten bronze. |
| 99 | `coin_gold` | Gold coin |  |  | FUTURE | A gold coin, worth ten silver. |

### A.placeable (195 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 8 | `campfire_kit` | Campfire |  | hand | KEEP | Stones and sticks for a fire. Set it down, then light it with fibre. |
| 25 | `chopping_block` | Chopping block |  | hand | KEEP | A log set on end. Split wooden blocks into firewood on it. |
| 92 | `large_forge_kit` | Large forge |  |  | FUTURE | **follows large_forge.** A big arched forge with a riveted iron frame, ready to raise. |
| 94 | `master_forge_kit` | Master forge |  |  | UPDATE | **follows master_forge.** An ornate black iron and gold forge set with red gems, ready to raise. |
| 235 | `rock_pile` | Rock pile |  | hand | KEEP | A heap of 45 stones. Set it down to store rock; pick it up to carry it. |
| 242 | `woodworking_table_kit` | Woodworking table |  |  | RETIRED | **already retired kit.** A heavy table with vices and clamps for fine woodwork. Set it down in a workshop. |
| 250 | `rough_bed_kit` | Thatch - Bed |  | hand | KEEP | Sticks, branches and rough bedding lashed with twine. Set it under a roof and lie down to sleep. |
| 276 | `snare` | Snare |  | hand | KEEP | A loop of twine on a bent stick. Set it on a worn animal path. |
| 822 | `fish_trap` | Fish trap |  | hand | FUTURE | A cone of woven sticks set in the water. Fish swim in and cannot find the way out. |
| 824 | `bird_trap` | Bird trap |  | hand | FUTURE | A stick cage propped on a trigger. A ground bird that steps in for the bait brings it down. |

Already retired (185; numbers never reused): 20 `lean_to_kit` Lean-to; 22 `chest_kit` Wicker - Chest; 24 `chopping_block_kit` Chopping block; 28 `plank_chest_kit` Wooden - Chest; 73 `workbench_kit` Wooden - Workbench; 81 `tool_rack_kit` Tool rack; 83 `vice_kit` Vice; 85 `log_workbench_kit` Carpenter's bench; 87 `stone_forge_kit` Stone - Forge; 89 `blacksmithy_kit` Brick - Forge; 192 `wall_section_kit` Refined - Wall; 194 `floor_section_kit` Refined - Ceiling; 196 `roof_section_kit` Refined - Roof; 198 `foundation_section_kit` Sturdy - Foundation; 200 `doorway_section_kit` Refined - Doorway; 202 `window_section_kit` Refined - Window; 204 `timber_prop_kit` Post; 206 `timber_set_kit` Beam; 211 `ladder_kit` Ladder; 240 `saw_mill_kit` Sawmill; 252 `thatch_wall_kit` Crude - Wall; 254 `campfire_pot_kit` Campfire pot; 256 `clay_hearth_kit` Clay hearth; 261 `thatch_floor_kit` Crude - Foundation; 263 `thatch_roof_kit` Crude - Roof; 265 `thatch_doorway_kit` Crude - Doorway; 268 `oven_kit` Oven; 462 `stairs_wood_kit` Refined - Stairs; 464 `log_wall_kit` Rustic - Wall; 466 `log_floor_kit` Rustic - Ceiling; 468 `log_roof_kit` Rustic - Roof; 470 `stone_wall_kit` Sturdy - Wall; 472 `stone_floor_kit` Sturdy - Ceiling; 474 `stone_roof_kit` Sturdy - Roof; 476 `brick_wall_kit` Superior - Wall; 478 `brick_floor_kit` Superior - Ceiling; 480 `brick_roof_kit` Superior - Roof; 482 `log_cabin_set_kit` Log cabin set; 487 `log_seat_kit` Seat; 488 `bench_kit` Wooden - Bench; 489 `chair_kit` Wooden - Chair; 490 `table_kit` Wooden - Table; 491 `hide_rug_kit` Hide - Rug; 492 `wool_rug_kit` Wool - Rug; 493 `straw_bed_kit` Straw - Bed; 494 `feather_bed_kit` Feather - Bed; 495 `canopy_bed_kit` Canopy bed; 496 `wall_torch_kit` Wall torch; 497 `chandelier_kit` Chandelier; 498 `fireplace_kit` Fireplace; 499 `flower_pot_kit` Flower pot; 500 `antler_mount_kit` Antler mount; 501 `stool_kit` Stool; 558 `wood_foundation_kit` Refined - Foundation; 562 `log_foundation_kit` Rustic - Foundation; 564 `brick_foundation_kit` Superior - Foundation; 566 `log_doorway_kit` Rustic - Doorway; 568 `stone_doorway_kit` Sturdy - Doorway; 570 `brick_doorway_kit` Superior - Doorway; 572 `thatch_window_kit` Crude - Window; 574 `log_window_kit` Rustic - Window; 576 `stone_window_kit` Sturdy - Window; 578 `brick_window_kit` Superior - Window; 580 `thatch_fence_kit` Crude - Fence; 582 `thatch_gate_kit` Crude - Gate; 584 `wood_fence_kit` Refined - Fence; 586 `wood_gate_kit` Refined - Gate; 588 `log_fence_kit` Rustic - Fence; 590 `log_gate_kit` Rustic - Gate; 592 `log_palisade_kit` Palisade; 594 `log_palisade_gate_kit` Palisade gate; 596 `stone_fence_kit` Sturdy - Fence; 598 `stone_gate_kit` Sturdy - Gate; 600 `brick_fence_kit` Superior - Fence; 602 `brick_gate_kit` Superior - Gate; 604 `iron_fence_kit` Iron - Fence; 606 `iron_gate_kit` Iron - Gate; 608 `thatch_pillar_kit` Crude - Pillar; 610 `wooden_pillar_kit` Refined - Pillar; 612 `log_pillar_kit` Rustic - Pillar; 614 `stone_pillar_kit` Sturdy - Pillar; 616 `brick_pillar_kit` Superior - Pillar; 618 `thatch_roof_corner_kit` Crude - Roof corner; 620 `wooden_roof_corner_kit` Refined - Roof corner; 622 `log_roof_corner_kit` Rustic - Roof corner; 624 `stone_roof_corner_kit` Sturdy - Roof corner; 626 `brick_roof_corner_kit` Superior - Roof corner; 628 `log_bench_kit` Log bench; 630 `log_table_kit` Log table; 632 `stone_bench_kit` Stone - Bench; 634 `stone_table_kit` Stone - Table; 636 `iron_bench_kit` Iron - Bench; 638 `iron_chair_kit` Iron - Chair; 640 `iron_table_kit` Iron - Table; 642 `stone_workbench_kit` Stone - Workbench; 644 `wooden_shelf_kit` Shelf; 646 `wooden_cupboard_kit` Cupboard; 648 `wooden_barrel_kit` Barrel; 650 `log_stairs_kit` Rustic - Stairs; 652 `stone_stairs_kit` Sturdy - Stairs; 654 `brick_stairs_kit` Superior - Stairs; 656 `wooden_railing_kit` Wooden - Railing; 658 `iron_railing_kit` Iron - Railing; 660 `double_doorway_kit` Refined - Double doorway; 662 `iron_doorway_kit` Iron - Doorway; 664 `steel_doorway_kit` Steel - Doorway; 670 `wooden_hanging_lantern_kit` Wooden - Hanging lantern; 672 `iron_hanging_lantern_kit` Iron - Hanging lantern; 674 `iron_wall_lantern_kit` Wall lantern; 676 `wooden_torch_post_kit` Torch post; 678 `stone_torch_pillar_kit` Torch pillar; 680 `iron_torch_stand_kit` Torch stand; 682 `wooden_lamp_post_kit` Wooden - Lamp post; 684 `iron_lamp_post_kit` Iron - Lamp post; 686 `stone_lamp_post_kit` Stone - Lamp post; 688 `stone_brazier_kit` Stone - Brazier; 690 `iron_brazier_kit` Iron - Brazier; 692 `thatch_garden_plot_kit` Thatch - Garden plot; 694 `wooden_garden_plot_kit` Wooden - Garden plot; 696 `stone_garden_plot_kit` Stone - Garden plot; 698 `brick_garden_plot_kit` Brick - Garden plot; 700 `wooden_planter_box_kit` Planter box; 702 `stone_planter_kit` Stone - Planter; 704 `wooden_trellis_kit` Trellis; 706 `wooden_compost_bin_kit` Compost bin; 708 `thatch_scarecrow_kit` Scarecrow; 710 `wooden_cold_frame_kit` Cold frame; 712 `stone_well_kit` Well; 714 `wooden_hand_pump_kit` Wooden - Hand pump; 716 `iron_hand_pump_kit` Iron - Hand pump; 718 `log_trough_kit` Log trough; 720 `wooden_trough_kit` Wooden - Trough; 722 `wooden_channel_kit` Wooden - Channel; 724 `wooden_channel_corner_kit` Wooden - Channel corner; 726 `wooden_channel_tee_kit` Wooden - Channel tee; 728 `wooden_sluice_kit` Sluice; 731 `stone_trough_kit` Stone - Trough; 733 `stone_channel_kit` Stone - Channel; 735 `stone_channel_corner_kit` Stone - Channel corner; 737 `stone_channel_tee_kit` Stone - Channel tee; 739 `clay_pipe_run_kit` Clay - Pipe; 741 `clay_pipe_elbow_kit` Clay - Pipe elbow; 743 `clay_pipe_tee_kit` Clay - Pipe tee; 745 `iron_pipe_kit` Iron - Pipe; 747 `iron_pipe_elbow_kit` Iron - Pipe elbow; 749 `iron_tap_kit` Tap; 751 `iron_deep_well_pump_kit` Deep-well pump; 753 `stone_cistern_kit` Cistern; 755 `stone_raised_cistern_kit` Raised cistern; 770 `kiln_kit` Kiln; 772 `tanning_rack_kit` Tanning rack; 774 `drying_rack_kit` Drying rack; 776 `smoker_kit` Smoker; 778 `oil_press_kit` Oil press; 780 `storage_jar_kit` Storage jar; 782 `hide_sack_kit` Hide - Sack; 784 `wicker_basket_kit` Basket; 786 `weapon_rack_kit` Weapon rack; 788 `armour_stand_kit` Armour stand; 790 `sign_kit` Sign; 792 `tusk_mount_kit` Tusk mount; 794 `clay_bloomery_kit` Clay bloomery; 796 `stonecutters_bench_kit` Stonecutter's bench; 826 `iron_anvil_kit` Anvil; 829 `preserving_jar_kit` Preserving jar; 831 `root_cellar_kit` Root cellar; 847 `log_shelf_kit` Log shelf; 849 `wooden_crate_kit` Crate; 851 `iron_chest_kit` Iron - Chest; 860 `mixer_kit` Mixer; 862 `engineered_foundation_kit` Engineered - Foundation; 864 `engineered_wall_kit` Engineered - Wall; 866 `engineered_doorway_kit` Engineered - Doorway; 868 `engineered_window_kit` Engineered - Window; 870 `engineered_pillar_kit` Engineered - Pillar; 872 `engineered_stairs_kit` Engineered - Stairs; 874 `engineered_floor_kit` Engineered - Ceiling; 876 `engineered_roof_kit` Engineered - Roof; 878 `engineered_roof_corner_kit` Engineered - Roof corner; 880 `fortified_foundation_kit` Fortified - Foundation; 882 `fortified_wall_kit` Fortified - Wall; 884 `fortified_doorway_kit` Fortified - Doorway; 886 `fortified_gate_kit` Fortified - Gate; 888 `fortified_pillar_kit` Fortified - Pillar; 890 `fortified_wall_top_kit` Fortified - Wall top.

### A.structure (203 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 21 | `lean_to` | Lean-to |  |  | KEEP | A ridge pole on two forks, with a roof of leaned sticks and boughs down to the ground. Crawl in under it. |
| 23 | `chest` | Wicker - Chest | wicker |  | KEEP | A woven chest for storing things. |
| 29 | `plank_chest` | Wooden - Chest | planks |  | KEEP | A plank chest for storing more things. |
| 54 | `remains` | Remains |  |  | KEEP | A fallen traveller and the pack they carried. |
| 74 | `workbench` | Wooden - Workbench |  |  | KEEP | A camp bench. It counts as a workbench: stand near it to make the things that need one. |
| 82 | `tool_rack` | Tool rack |  |  | KEEP | A tool rack. Beside a camp bench it raises the bench a level. |
| 84 | `vice` | Vice |  |  | KEEP | A wooden vice. Beside a camp bench it raises the bench a level. |
| 86 | `log_workbench` | Carpenter's bench |  |  | KEEP | A pinned plank bench with its own rack and vice. Stand near it to make the things that need a work table. |
| 88 | `stone_forge` | Stone - Forge |  |  | UPDATE | **UNRESOLVED: role after Smelter/Smithy split (U10).** A clay and rough stone forge under a log lean-to. Stand near it to work metal. |
| 90 | `blacksmithy` | Brick - Forge |  |  | UPDATE | **RECOMMENDED: becomes the Smithy (s5).** A brick forge with a stepped hood and iron straps. Smelts and works iron; an anvil beside it makes steel. |
| 91 | `carcass` | Carcass |  |  | KEEP | A freshly killed animal. Work it with a knife for meat, hide and bones. |
| 93 | `large_forge` | Large forge |  |  | FUTURE | **RECOMMENDED: possible Blast Furnace id (s5).** A big arched forge with a riveted iron frame and a brick-lined firebox. |
| 95 | `master_forge` | Master forge |  |  | UPDATE | **RECOMMENDED: becomes the Master Smithy (s5).** An ornate black iron and gold forge set with red gems, always glowing. |
| 193 | `wall_section` | Refined - Wall | planks |  | KEEP | A plank wall, two metres wide. Set pieces edge to edge to build a house. |
| 195 | `floor_section` | Refined - Ceiling | planks |  | KEEP | A plank ceiling, two metres square: the ceiling of the room below, set on walls. Set pieces edge to edge. |
| 197 | `roof_section` | Refined - Roof | planks |  | KEEP | A plank roof on four posts, to set over walls and ceilings. |
| 199 | `foundation_section` | Sturdy - Foundation | stone |  | KEEP | A stone and clay slab, four metres square. Walls and ceilings snap onto it. |
| 201 | `doorway_section` | Refined - Doorway | planks |  | KEEP | A plank wall with a gap you can walk through, one metre wide and two high. |
| 203 | `window_section` | Refined - Window | planks |  | KEEP | A plank wall with an opening at chest height to see through. |
| 205 | `timber_prop` | Post | wood |  | KEEP | A log stood on end to hold up a low roof of earth. Short reach, quick to wear. |
| 207 | `timber_set` | Beam | wood |  | KEEP | A post and cap frame that braces a tunnel. Longer reach and slower to wear. |
| 212 | `ladder` | Ladder | wood |  | KEEP | A wooden ladder, 2.4 m tall. Set it against a wall or an edge and climb. |
| 225 | `path_patch` | Path | earth |  | KEEP | Trodden ground, a metre of path. |
| 241 | `saw_mill` | Sawmill |  |  | KEEP | **APPROVED: waterwheel reciprocating sawmill (s4).** A water-driven sawmill. Stand near it to saw logs into planks. |
| 243 | `woodworking_table` | Woodworking table |  |  | RETIRE | **RECOMMENDED: redundant with Carpenter's bench (U7).** A woodworking table. Stand near it for fine woodwork. |
| 251 | `rough_bed` | Thatch - Bed |  |  | KEEP | A low frame of sticks and branches with a heap of rough bedding, like a manger. |
| 253 | `thatch_wall` | Crude - Wall |  |  | KEEP | A thatch wall. |
| 255 | `campfire_pot` | Campfire pot |  |  | KEEP | A pot hung over a small fire. It cooks while the fire is lit. The fire stays at firewood. |
| 257 | `clay_hearth` | Clay hearth |  |  | KEEP | A clay hearth with a spit. |
| 262 | `thatch_floor` | Crude - Foundation |  |  | KEEP | A thatch foundation on stakes. Walls and roofs stand on it. |
| 264 | `thatch_roof` | Crude - Roof |  |  | KEEP | A thatch roof. It keeps the rain off. |
| 266 | `thatch_doorway` | Crude - Doorway |  |  | KEEP | A thatch doorway with a hanging door. |
| 267 | `oven` | Oven |  |  | KEEP | A brick oven with a door. Bakes what a clay hearth cooks, and bread and joints besides. |
| 277 | `snare_trap` | Snare |  |  | KEEP | A snare set on the ground. |
| 425 | `tilled_bed` | Tilled bed | earth |  | KEEP | A metre of hoed soil, ready to sow. |
| 463 | `stairs_wood` | Refined - Stairs |  |  | KEEP | A wooden flight of stairs, 2.4 m long. |
| 465 | `log_wall` | Rustic - Wall |  |  | KEEP | A log wall, two metres wide. |
| 467 | `log_floor` | Rustic - Ceiling |  |  | KEEP | A ceiling of laid logs. |
| 469 | `log_roof` | Rustic - Roof |  |  | KEEP | A log-framed thatch roof. |
| 471 | `stone_wall` | Sturdy - Wall |  |  | KEEP | A stone wall, two metres wide. |
| 473 | `stone_floor` | Sturdy - Ceiling |  |  | KEEP | A cobbled stone ceiling. |
| 475 | `stone_roof` | Sturdy - Roof |  |  | KEEP | A stone-shingle roof. |
| 477 | `brick_wall` | Superior - Wall |  |  | KEEP | A brick wall, two metres wide. |
| 479 | `brick_floor` | Superior - Ceiling |  |  | KEEP | A brick ceiling. |
| 481 | `brick_roof` | Superior - Roof |  |  | KEEP | A tiled brick roof. |
| 502 | `log_seat` | Seat |  |  | KEEP | A log seat. Sit on it by the fire. |
| 503 | `stool` | Stool |  |  | KEEP | A lashed stool. Sit on it. |
| 504 | `bench` | Wooden - Bench |  |  | KEEP | A plank bench that seats two or three. |
| 505 | `chair` | Wooden - Chair |  |  | KEEP | A chair with a back. Sit and rest. |
| 506 | `table` | Wooden - Table |  |  | KEEP | A plank table on trestles. |
| 507 | `hide_rug` | Hide - Rug |  |  | KEEP | A pelt on the floor. |
| 508 | `wool_rug` | Wool - Rug |  |  | FUTURE | A striped woven rug. |
| 509 | `straw_bed` | Straw - Bed |  |  | KEEP | A bed with a heaped straw tick. |
| 510 | `feather_bed` | Feather - Bed |  |  | KEEP | A bed with a feather tick and a blanket. |
| 511 | `canopy_bed` | Canopy bed |  |  | KEEP | A canopy bed with curtains. |
| 512 | `wall_torch` | Wall torch |  |  | KEEP | A torch on the wall. It lights when fuelled. |
| 513 | `chandelier` | Chandelier |  |  | KEEP | A hanging hoop of candles. It lights when fuelled. |
| 514 | `fireplace` | Fireplace |  |  | KEEP | A brick hearth with a chimney. It lights when fuelled. |
| 515 | `flower_pot` | Flower pot |  |  | KEEP | A pot of flowers. |
| 516 | `antler_mount` | Antler mount |  |  | KEEP | Antlers mounted on a board. |
| 543 | `standing_torch` | Standing torch |  |  | KEEP | A torch stuck in the ground. Hold E to take it back. |
| 544 | `torch_sconce` | Wedged torch |  |  | KEEP | A torch wedged on a wall. Hold E to take it back. |
| 559 | `wood_foundation` | Refined - Foundation | wood |  | KEEP | A log and plank base, four metres square. Walls and ceilings snap onto it. |
| 563 | `log_foundation` | Rustic - Foundation | log |  | KEEP | Log sills on stone footings, four metres square. Walls and ceilings snap onto it. |
| 565 | `brick_foundation` | Superior - Foundation | brick |  | KEEP | A brick plinth, four metres square. Walls and ceilings snap onto it. |
| 567 | `log_doorway` | Rustic - Doorway | log |  | KEEP | A log wall with a plank door, one metre wide and two high. |
| 569 | `stone_doorway` | Sturdy - Doorway | stone |  | KEEP | A stone wall with a timber lintel and a door, one metre wide and two high. |
| 571 | `brick_doorway` | Superior - Doorway | brick |  | KEEP | A brick wall with a timber door, one metre wide and two high. |
| 573 | `thatch_window` | Crude - Window | thatch |  | KEEP | A thatch wall with an opening at chest height to see through. |
| 575 | `log_window` | Rustic - Window | log |  | KEEP | A log wall with an opening at chest height to see through. |
| 577 | `stone_window` | Sturdy - Window | stone |  | KEEP | A stone wall with a sill and an opening at chest height to see through. |
| 579 | `brick_window` | Superior - Window | brick |  | KEEP | A brick wall with an arched opening at chest height to see through. |
| 581 | `thatch_fence` | Crude - Fence | thatch |  | KEEP | Stakes woven with sticks and lashed with twine, two metres long. |
| 583 | `thatch_gate` | Crude - Gate | thatch |  | KEEP | A woven hurdle hung on twine hinges. Opens like a door. |
| 585 | `wood_fence` | Refined - Fence | wood |  | KEEP | A picket fence of planks, two metres long. |
| 587 | `wood_gate` | Refined - Gate | wood |  | KEEP | A plank gate with a Z brace. Opens like a door. |
| 589 | `log_fence` | Rustic - Fence | log |  | KEEP | Split rails pegged into log posts, two metres long. |
| 591 | `log_gate` | Rustic - Gate | log |  | KEEP | A rail gate of split logs. Opens like a door. |
| 593 | `log_palisade` | Palisade | log |  | KEEP | Pointed log stakes taller than a man. Keeps out wolves and goblins. |
| 595 | `log_palisade_gate` | Palisade gate | log |  | KEEP | A palisade section that swings open like a door. |
| 597 | `stone_fence` | Sturdy - Fence | stone |  | KEEP | A low dry-stone wall with capstones, two metres long. |
| 599 | `stone_gate` | Sturdy - Gate | stone |  | KEEP | A timber gate between stone piers. Opens like a door. |
| 601 | `brick_fence` | Superior - Fence | brick |  | KEEP | A low brick wall on a stone plinth, two metres long. |
| 603 | `brick_gate` | Superior - Gate | brick |  | KEEP | A timber gate between brick piers. Opens like a door. |
| 605 | `iron_fence` | Iron - Fence | iron |  | KEEP | Iron railings on a brick plinth, two metres long. |
| 607 | `iron_gate` | Iron - Gate | iron |  | KEEP | A wrought iron gate. Opens like a door. |
| 609 | `thatch_pillar` | Crude - Pillar | thatch |  | KEEP | A thatch pillar 2.6 m tall. Stands on the middle or a corner of a foundation or ceiling. |
| 611 | `wooden_pillar` | Refined - Pillar | wood |  | KEEP | A wooden pillar 2.6 m tall. Stands on the middle or a corner of a foundation or ceiling. |
| 613 | `log_pillar` | Rustic - Pillar | log |  | KEEP | A log pillar 2.6 m tall. Stands on the middle or a corner of a foundation or ceiling. |
| 615 | `stone_pillar` | Sturdy - Pillar | stone |  | KEEP | A stone pillar 2.6 m tall. Stands on the middle or a corner of a foundation or ceiling. |
| 617 | `brick_pillar` | Superior - Pillar | brick |  | KEEP | A brick pillar 2.6 m tall. Stands on the middle or a corner of a foundation or ceiling. |
| 619 | `thatch_roof_corner` | Crude - Roof corner | thatch |  | KEEP | The corner of a thatch roof, where two slopes meet. |
| 621 | `wooden_roof_corner` | Refined - Roof corner | wood |  | KEEP | The corner of a wooden roof, where two slopes meet. |
| 623 | `log_roof_corner` | Rustic - Roof corner | log |  | KEEP | The corner of a log roof, where two slopes meet. |
| 625 | `stone_roof_corner` | Sturdy - Roof corner | stone |  | KEEP | The corner of a stone roof, where two slopes meet. |
| 627 | `brick_roof_corner` | Superior - Roof corner | brick |  | KEEP | The corner of a brick roof, where two slopes meet. |
| 629 | `log_bench` | Log - Bench |  |  | KEEP | A split log on two stumps. Seats two or three. |
| 631 | `log_table` | Log - Table |  |  | KEEP | A table with a hand-hewn log top. |
| 633 | `stone_bench` | Stone - Bench |  |  | KEEP | A heavy stone slab on stone feet. Seats two or three. |
| 635 | `stone_table` | Stone - Table |  |  | KEEP | A thick stone-footed table with a plank top. |
| 637 | `iron_bench` | Iron - Bench |  |  | KEEP | A timber bench bound with iron. Seats two or three. |
| 639 | `iron_chair` | Iron - Chair |  |  | KEEP | An iron-bound chair with a hide seat. |
| 641 | `iron_table` | Iron - Table |  |  | KEEP | A plank table bound with iron. |
| 643 | `stone_workbench` | Stone - Workbench |  |  | KEEP | A stone-topped workbench, the biggest of the three. Takes the tool rack and vice. |
| 645 | `wooden_shelf` | Shelf |  |  | KEEP | Plank shelves to set against a wall. Holds 8 stacks. |
| 647 | `wooden_cupboard` | Cupboard |  |  | KEEP | A tall plank cupboard with doors. Holds 16 stacks. |
| 649 | `wooden_barrel` | Barrel |  |  | KEEP | A hooped plank barrel. Holds 8 stacks. |
| 651 | `log_stairs` | Rustic - Stairs |  |  | KEEP | A flight of hewn log steps up to the next ceiling. |
| 653 | `stone_stairs` | Sturdy - Stairs |  |  | KEEP | A flight of mortared stone steps up to the next ceiling. |
| 655 | `brick_stairs` | Superior - Stairs |  |  | KEEP | A flight of brick steps up to the next ceiling. |
| 657 | `wooden_railing` | Wooden - Railing |  |  | KEEP | A plank railing along a ceiling or foundation edge. Stops falls. |
| 659 | `iron_railing` | Iron - Railing |  |  | KEEP | An iron railing along a ceiling or foundation edge. Stops falls. |
| 661 | `double_doorway` | Refined - Double doorway |  |  | KEEP | A plank wall four metres wide with a pair of doors. |
| 663 | `iron_doorway` | Iron - Doorway |  |  | KEEP | A plank wall with an iron-strapped door, one metre wide and two high. |
| 665 | `steel_doorway` | Steel - Doorway |  |  | KEEP | A wall with a steel door, one metre wide and two high. |
| 671 | `wooden_hanging_lantern` | Wooden - Hanging lantern |  |  | KEEP | A plank lantern on a hook. Burns a candle a game day; rain cannot reach it. |
| 673 | `iron_hanging_lantern` | Iron - Hanging lantern |  |  | KEEP | An iron lantern on a hook. Lamp oil lasts three game days. |
| 675 | `iron_wall_lantern` | Wall lantern |  |  | KEEP | An iron lantern on a bracket arm. Lamp oil lasts three game days. |
| 677 | `wooden_torch_post` | Torch post |  |  | KEEP | A tall post with a tallow-soaked head. Keeps wolves off; rain puts it out. |
| 679 | `stone_torch_pillar` | Torch pillar |  |  | KEEP | A stone pillar with a hooded iron bowl. Keeps wolves off, rain or shine. |
| 681 | `iron_torch_stand` | Torch stand |  |  | KEEP | An iron stand with a torch bowl. Keeps wolves off; rain puts it out. |
| 683 | `wooden_lamp_post` | Wooden - Lamp post |  |  | KEEP | A wooden lantern on a pole with a hook arm. Rain cannot reach it. |
| 685 | `iron_lamp_post` | Iron - Lamp post |  |  | KEEP | An iron lantern on a tall iron post. |
| 687 | `stone_lamp_post` | Stone - Lamp post |  |  | KEEP | An iron lantern on a stone post. |
| 689 | `stone_brazier` | Stone - Brazier |  |  | KEEP | A stone fire bowl. Burns logs for light. |
| 691 | `iron_brazier` | Iron - Brazier |  |  | KEEP | An iron fire bowl on legs. Burns logs for light. |
| 693 | `thatch_garden_plot` | Thatch - Garden plot |  |  | KEEP | A stick-edged bed of soil, two metres square. Sow and tend it like a tilled bed. |
| 695 | `wooden_garden_plot` | Wooden - Garden plot |  |  | KEEP | A plank raised bed, two metres square. Holds its water better than open ground. |
| 697 | `stone_garden_plot` | Stone - Garden plot |  |  | KEEP | A stone-edged raised bed, two metres square. Holds its water best. |
| 699 | `brick_garden_plot` | Brick - Garden plot |  |  | KEEP | A brick raised bed, two metres square. Holds its water best. |
| 701 | `wooden_planter_box` | Planter box |  |  | KEEP | A plank window box of soil for herbs and flowers. |
| 703 | `stone_planter` | Stone - Planter |  |  | KEEP | A big stone pot of soil for a herb or a small shrub. |
| 705 | `wooden_trellis` | Trellis |  |  | KEEP | A lattice of sticks to set beside a plot for climbing plants. |
| 707 | `wooden_compost_bin` | Compost bin |  |  | KEEP | A slatted bin that rots plant waste down into compost. |
| 709 | `thatch_scarecrow` | Scarecrow |  |  | KEEP | A straw figure on a pole to watch over the plots. |
| 711 | `wooden_cold_frame` | Cold frame |  |  | KEEP | A horn-paned box over a plot that keeps frost off seedlings. |
| 713 | `stone_well` | Well |  |  | KEEP | A stone well with a windlass and bucket. E draws ten litres. |
| 715 | `wooden_hand_pump` | Wooden - Hand pump |  |  | KEEP | An old lever pump on a bored shaft. Hold E to pump water into a bucket or trough. |
| 717 | `iron_hand_pump` | Iron - Hand pump |  |  | KEEP | A cast-iron pitcher pump. Hold E to pump water into a bucket or trough. |
| 719 | `log_trough` | Log - Trough |  |  | KEEP | A hollowed log that holds sixty litres. Animals drink from it. |
| 721 | `wooden_trough` | Wooden - Trough |  |  | KEEP | A plank trough that holds a hundred litres. Can sit at a channel's end. |
| 723 | `wooden_channel` | Wooden - Channel |  |  | KEEP | An open plank flume on trestles, two metres long. Water runs downhill along it. |
| 725 | `wooden_channel_corner` | Wooden - Channel corner |  |  | KEEP | A flume that turns a quarter circle. |
| 727 | `wooden_channel_tee` | Wooden - Channel tee |  |  | KEEP | A flume that splits its water two ways. |
| 729 | `wooden_sluice` | Sluice |  |  | KEEP | A flume with a gate. E opens or shuts it. |
| 732 | `stone_trough` | Stone - Trough |  |  | KEEP | A carved stone trough that holds two hundred litres. |
| 734 | `stone_channel` | Stone - Channel |  |  | KEEP | An open stone channel, two metres long. Carries more than a flume. |
| 736 | `stone_channel_corner` | Stone - Channel corner |  |  | KEEP | A stone channel that turns a quarter circle. |
| 738 | `stone_channel_tee` | Stone - Channel tee |  |  | KEEP | A stone channel that splits its water two ways. |
| 740 | `clay_pipe_run` | Clay - Pipe |  |  | KEEP | A closed clay pipe, two metres long. Drain it before a hard frost. |
| 742 | `clay_pipe_elbow` | Clay - Pipe elbow |  |  | KEEP | A clay pipe that turns a quarter circle. |
| 744 | `clay_pipe_tee` | Clay - Pipe tee |  |  | KEEP | A clay pipe that splits its water two ways. |
| 746 | `iron_pipe` | Iron - Pipe |  |  | KEEP | A closed iron pipe, two metres long. A force pump can push water up it. |
| 748 | `iron_pipe_elbow` | Iron - Pipe elbow |  |  | KEEP | An iron pipe that turns a quarter circle. |
| 750 | `iron_tap` | Tap |  |  | KEEP | A shut-off tap for a pipe's end. E opens or shuts it. |
| 752 | `iron_deep_well_pump` | Deep-well pump |  |  | KEEP | A force pump for a stone well. Lifts from deep and pushes water up an iron pipe. |
| 754 | `stone_cistern` | Cistern |  |  | KEEP | A stone tank that holds two thousand litres, with an overflow at the rim. |
| 756 | `stone_raised_cistern` | Raised cistern |  |  | KEEP | A cistern on a tall stone plinth. Fed by a force pump, it feeds a town by gravity. |
| 771 | `kiln` | Kiln |  |  | KEEP | A domed brick kiln. Fires bricks twice as well as a campfire and burns wood to charcoal. |
| 773 | `tanning_rack` | Tanning rack |  |  | KEEP | **APPROVED: tanning.** A log frame to stretch scraped hides on while bark tannin turns them to leather. |
| 775 | `drying_rack` | Drying rack |  |  | UPDATE | **APPROVED: adds hide drying (s6).** A rack of sticks in the air and sun. Dries meat into jerky and fruit to keep. |
| 777 | `smoker` | Smoker |  |  | KEEP | A stone and clay smoke chamber over a slow fire. Smokes fish to keep for weeks. |
| 779 | `oil_press` | Oil press |  |  | KEEP | A stone press on a log frame. Squeezes linseed and walnuts for lamp oil. |
| 781 | `storage_jar` | Storage jar |  |  | KEEP | A tall lidded clay jar for grain, oil or water. Small, but it keeps damp and mice out. |
| 783 | `hide_sack` | Hide - Sack |  |  | KEEP | A hide sack tied at the neck. A first store for a camp before there are planks for a chest. |
| 785 | `wicker_basket` | Basket |  |  | KEEP | A woven basket of sticks and twine. A first store for a camp. |
| 787 | `weapon_rack` | Weapon rack |  |  | KEEP | A plank rack against a wall for spears, bows and blades. |
| 789 | `armour_stand` | Armour stand |  |  | KEEP | A plank figure to hang a set of armour and clothes on. |
| 791 | `sign` | Sign |  |  | KEEP | A plank board on a stick to mark a camp or a path. |
| 793 | `tusk_mount` | Tusk mount |  |  | KEEP | A pair of boar tusks on a plank. Hang it on a wall for comfort. |
| 795 | `clay_bloomery` | Clay bloomery |  |  | RETIRE | **APPROVED: no Clay Bloomery.** A clay chimney furnace fed with charcoal. Smelts iron ore to an ingot, slowly, before a brick forge. |
| 797 | `stonecutters_bench` | Stonecutter's bench |  |  | KEEP | A heavy stone bench for squaring and carving stone. Gets more blocks from the stone, but needs a metal chisel. |
| 823 | `fish_trap_set` | Fish trap |  |  | KEEP | A fish trap set in the water. |
| 825 | `bird_trap_set` | Bird trap |  |  | KEEP | A bird trap set on the ground. |
| 827 | `iron_anvil` | Anvil |  |  | RETIRE | **RECOMMENDED: Smithy has an anvil built in (s5).** A forged iron anvil on a banded log stump. Set beside a brick forge, it raises the forge a level, for steel. |
| 830 | `preserving_jar` | Preserving jar |  |  | KEEP | A wide-mouthed clay jar with a lid, for pickling and preserving. |
| 832 | `root_cellar` | Root cellar |  |  | KEEP | A stone-lined store dug into the ground. Cool all year, so food keeps far longer. |
| 840 | `chicken_coop` | Chicken coop |  |  | FUTURE | A thatched coop for four chickens. They lay eggs. |
| 841 | `fodder_trough` | Fodder trough |  |  | FUTURE | A plank trough that holds fodder for penned animals. |
| 842 | `tub` | Tub |  |  | FUTURE | A wooden bathtub filled from a bucket. Warm it with a fire close by. |
| 843 | `sap_tap` | Sap tap |  |  | FUTURE | A wooden spout driven into a maple or birch to catch sap. |
| 844 | `cheese_press` | Cheese press |  |  | FUTURE | A wooden press that squeezes curds into cheese. |
| 845 | `spinning_wheel` | Spinning wheel |  |  | FUTURE | **not in Dave's list; unchanged.** A treadle wheel that spins wool and flax into thread. |
| 846 | `loom` | Loom |  |  | FUTURE | **APPROVED: weaving station (s6).** A wooden frame loom for weaving thread into cloth. |
| 848 | `log_shelf` | Log - Shelf |  |  | KEEP | Split logs lashed between two log uprights. A first shelf to set against a wall. |
| 850 | `wooden_crate` | Crate |  |  | KEEP | A braced plank crate with a nailed lid. Holds 10 stacks. |
| 852 | `iron_chest` | Iron - Chest |  |  | KEEP | A plank chest plated and strapped in iron. Holds 30 stacks, more than a wooden chest. |
| 861 | `mixer` | Mixer |  |  | KEEP | A stone trough with a cranked wooden paddle. Mixes lime powder, sand, stone and water into concrete. |
| 863 | `engineered_foundation` | Engineered - Foundation |  |  | KEEP | A poured concrete slab on a stone footing, four metres square. Walls and ceilings snap onto it. |
| 865 | `engineered_wall` | Engineered - Wall |  |  | KEEP | A poured concrete wall, two metres wide. |
| 867 | `engineered_doorway` | Engineered - Doorway |  |  | KEEP | A concrete wall with a plank door, two metres wide. |
| 869 | `engineered_window` | Engineered - Window |  |  | KEEP | A concrete wall with a window opening, two metres wide. |
| 871 | `engineered_pillar` | Engineered - Pillar |  |  | KEEP | A square concrete pillar to hold up a ceiling or a roof. |
| 873 | `engineered_stairs` | Engineered - Stairs |  |  | KEEP | A flight of poured concrete steps up to the next storey. |
| 875 | `engineered_floor` | Engineered - Ceiling |  |  | KEEP | A concrete slab cast over planks. A ceiling below and a floor above. |
| 877 | `engineered_roof` | Engineered - Roof |  |  | KEEP | Clay roof tiles on pinned plank rafters. Does not burn. |
| 879 | `engineered_roof_corner` | Engineered - Roof corner |  |  | KEEP | A clay tile roof corner on pinned plank rafters. |
| 881 | `fortified_foundation` | Fortified - Foundation |  |  | KEEP | A concrete slab tied with iron bands, four metres square. The base of a fort. |
| 883 | `fortified_wall` | Fortified - Wall |  |  | KEEP | A concrete wall banded with iron, two metres wide. Built to stand a siege. |
| 885 | `fortified_doorway` | Fortified - Doorway |  |  | KEEP | A banded concrete wall with a heavy iron-strapped door. |
| 887 | `fortified_gate` | Fortified - Gate |  |  | KEEP | A heavy plank gate strapped with iron, hung between concrete posts. |
| 889 | `fortified_pillar` | Fortified - Pillar |  |  | KEEP | A concrete pillar bound with iron bands. |
| 891 | `fortified_wall_top` | Fortified - Wall top |  |  | KEEP | A crenellated concrete parapet with iron ties. Cover for whoever holds the wall. |

