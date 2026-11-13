# Dynasty master items catalog

**Status: DRAFT 18 — EVERY CATEGORY HAS AN OWNER DECISION ([D1]–[D17]); NO OPEN OWNER QUESTIONS; SUBMITTED FOR DAVE'S FINAL APPROVAL OF THE COMPLETE CATALOG. NO GAMEPLAY IMPLEMENTATION OR MERGE AUTHORIZED UNTIL HE APPROVES IT.** All Dave rulings ([B], [D1]–[D17], [DE]) and ChatGPT's delegated decisions ([C], [C7]) are written into the catalog. This document changes nothing in `data/items/*.json`, `data/npcs/*.json`, recipes, station behaviour or game code. The item catalog stays frozen until Dave approves this catalog.

**Companion reference documents (not separate sources of item-approval authority):** [Storage, warehouse cargo and locks](STORAGE_WAREHOUSING_DESIGN.md); [Food preparation, preservation and edible boards](FOOD_PREPARATION_PRESERVATION_SERVING.md). The final audit is [CATALOG_FINAL_AUDIT_2026-11-12.md](CATALOG_FINAL_AUDIT_2026-11-12.md), the implementation plan [CATALOG_IMPLEMENTATION_PLAN.md](CATALOG_IMPLEMENTATION_PLAN.md) and the save rules [CATALOG_SAVE_MIGRATION.md](CATALOG_SAVE_MIGRATION.md); the earlier food and storage audit is [FOOD_STORAGE_AUDIT_2026-11-12.md](FOOD_STORAGE_AUDIT_2026-11-12.md); ChatGPT's brief is [CLAUDE_FOOD_STORAGE_HANDOFF.md](CLAUDE_FOOD_STORAGE_HANDOFF.md). These elaborate owner decisions and list future tests. This master catalog is authoritative for approved items and counts.

Data read: `data/items/items.json` (889 rows, next number 896), `recipes.json` (404 rows, 287 live, next 407), `blueprints.json` (185 rows, next 186), `structures.json` (216 rows, highest state 228; state 229 is bog iron in code only), on `dev` at `7f8aabf4` (unchanged on 12 Nov). Open PR #1036 retires the Woodworking table separately.

Layout: s1 sources and labels; s2 design decisions; s3 approved catalog categories; s4 implementation details (no new design); s5 numbers still to set; s6 audit matrix; s7 JSON change list; s8 readiness, blockers and risks; Appendix A the full 889-row catalog.

**Totals (Draft 18, complete catalog; verified 12 Nov).** Existing rows: KEEP 499, UPDATE 61, RETIRE 23, FUTURE 53, already retired 253 (889). New rows: **ADD 176** (18 tools and stations, 6 furniture grades in s3.5, 29 weapons and ammunition in s3.6, 14 armour pieces in s3.7, 17 clothing pieces in s3.8, 9 carrying items in s3.9, 20 animal tack items in s3.10, 13 vehicles and parts in s3.11, 7 cooking equipment and 16 prepared foods in s3.12, 16 storage pieces in s3.13, 2 preserved foods in s3.14, 8 food boards and the Serving Platter in s3.15) and **4 new FUTURE rows** (Steel bolt, Iron - Lance, Riding - Boots, Ploughman's Board). Vehicles add 10 blueprints and 10 structure states but no kit items. Storage layouts (Woodshed, Materials yard, Storehouse), the Granary layout and the Ship Captain's Table are not rows. [D16]/[D17] food effects add no rows. Nutrition-guide books [D17] are a future content set with no rows counted yet. Cross-listed rows are counted once. No number or id is reused; new rows take numbers from 896 in the implementation PR.

## 1. Sources and labels

| Tag | Source | Weight |
|---|---|---|
| **[D17]** | Dave, 12 Nov 04:49Z, resolving the last owner questions: keep Preserving Jar #830 and add no Sealable Preserve Jar; ADD Smoked Meat and Dried Mushrooms only; every food effect, benefit or penalty, is temporary, and energy aids lose their permanent Fitness cost; Large Wooden Chest keeps more weight and a larger footprint within 30 slots; tack and vehicles stay, with animal keeping a later implementation phase; nutrition guides through NPCs and books, later; teas and Fruit juice are the first beverages; the suggested effect numbers are the initial playtest values | **Owner decisions; closes [P14-v2] and [P17]** |
| [P17] | Dave-suggested nutrition advice from NPCs and books (s3.16) | Superseded: approved as future content by [D17] |
| [P14-v2] | Five-row preservation proposal (s3.14) | Superseded: [D17] approved two of the five rows |
| **[D16]** | Dave directed simple temporary food-profile buffs: protein meals can boost XP earned in Fitness training (illustrative +20%), better balanced recipes may boost actively earned skill XP generally; breads/grains give energy without XP bonus; sweets give quick energy but may reduce XP gain. Initial values set by [D17] (s3.16). | **Owner direction, future effects; NOT implementation permission** |
| **[D15]** | Dave approved exactly nine distinct functional edible prepared boards, collapsed from the 20- and 15-name drafts, plus one reusable Serving Platter; 8 current ADD boards, 1 FUTURE board and 1 ADD carrier | **Owner-approved platter category; no runtime approval** |
| **[D14]/[P14]** | Dave approved easy Food Preparation Table → one-step preserving or passive timed maturation for hundreds of sealed jars; the roster is set by [D17] (Smoked Meat, Dried Mushrooms) | **Approved workflow; roster closed by [D17]** |
| **[D13]** | Dave approved the attractive storage system (14 furniture/yard/ledger objects) and added Warehouse Crates and Warehouse Desks for linked bulk freight across warehouses and future ships; crates remain directly openable/manageable unless locked, and any linked desk obeys each crate's lock/permissions | **Owner-approved storage category only; NOT whole-catalog or runtime authorization** |
| **[D12]** | Dave approved full revised Cooking Proposal 2: Food Preparation Table (built-in knives/cutting board/rolling pin), 6 other cookware/attachments, 16 tangible prepared food intermediates and prepare→cook where food needs assembling; no personal inventory knife prep | **Owner-approved cooking category; NOT implementation permission** |
| **[D11]** | Dave approved ten carts/wagons/carriages and three reusable wheel/axle items; specifically removed Wheelbarrow as redundant with Handcart; paired animals remain one draft unit as in [D10] | **Approved vehicle category; NOT game implementation or complete-catalog approval** |
| **[D10]** | Dave approved 20 horse-tack items: original 18 plus Double Heavy Draft Harness and Double Ox Yoke; yoked animals move as one logical controller in fixed formation, with individual stamina/health and combined hauling | **Approved animal-tack category and technical rule; NOT approval of vehicles or implementation** |
| **[D9]** | Dave approved ChatGPT's entire Backpacks, Pouches & Carrying Equipment Proposal 1 (“lets do it”): retain 6 existing gear rows, add 9 distinct carrying aids; cross-list 3 already-existing containers; require realistic weight, volume, attachment and persistence | **Owner-approved carrying category; not full catalog or gameplay approval** |
| **[D8]** | Dave explicitly approved the full Clothing Proposal 1: 24 retained ordinary garment items; 17 new garments; Riding Boots future under mounted gear; 8 armour items cross-listed; layering and weather/climate effects | **Owner-approved category design; not implementation permission** |
| **[D7]** | Dave explicitly accepted the full Armour Proposal 1: 8 existing core armour pieces, 14 new armour variants, protective clothing/shields cross-listed, realistic modular layering and excluded redundancies | **Owner-approved category design; not game implementation approval** |
| **[D6]** | Dave, 12 Nov 2026 (PR #1035 comment 01:49Z): Weapons Proposal 2 approved in full, with his Poison Arrow addition; category approval only | Explicit Dave category decision |
| **[D5]** | Dave's later furniture clarification: Bronze and Iron nails are already sufficient; do not invent a separate luxury-nail ladder or insist on Iron nails for every Fine/Ornate recipe. Rustic furniture may be just Hardwood Boards plus nails; fancy furniture uses **more Hardwood Boards and more nails**, and **cloth/leather only where suitable** (such as upholstered seats, cushions, padded furnishings) | **Latest explicit Dave furniture rule; supersedes overcomplicated fastener requirements** |
| **[C7]** | ChatGPT's delegated confirmation of Draft 7: Tempered outputs are steel, per-item-instance, with no duplicate item IDs; furniture family scope in s3.5 accepted (four-grade chests/chairs/tables, two-grade benches, others single where appropriate) | **Confirmed catalog design, not implementation approval** |
| **[D4]** | Dave, 11 Nov Atlantic / 12 Nov UTC: Quenching Trough is a Smithy upgrade permitting better products (not an independent workstation); no Hardwood Board/Plank substitution; wooden furniture may use Crude, Rustic, Nice, Fancy grades, basic pieces using fewer Hardwood Boards and fancy pieces requiring more Hardwood Boards and better nails | **Explicit Dave rule; supersedes ChatGPT's earlier guesses** |
| **[D3]** | Dave, project chat, 12 Nov 2026 00:46Z: "ChatGPT is directing this reconciliation on my behalf"; final approval of the catalog stays with Dave | Makes [C] approved design input |
| **[C]** | ChatGPT on PR #1035: the nine decisions recorded in commit `5218134` and its handoff comment of 12 Nov 00:45Z | DECIDED via [D3]; loses to an explicit Dave decision |
| **[D2]** | Dave, 12 Nov 2026 00:25Z: review 5866741315 on PR #1035 is ChatGPT's review, approved unless his later decisions differ | Approves [R] |
| **[D1]** | Dave, "Final Design Decisions and Master Items Reconciliation", 12 Nov 2026 00:15Z | Dave's newest explicit decisions; wins over [R] and [C] |
| **[DE]** | Dave, 11 Nov 2026 (commit `7d32eb6`): enchantments are permanent | Dave's explicit decision |
| **[R]** | Review 5866741315 on PR #1035, 11 Nov 2026 23:31Z | APPROVED via [D2] |
| **[B]** | Dave, "Master Items Catalog — Reconciliation Assignment", 11 Nov 2026 | APPROVED |
| older Dave | `ITEM_DECISION_LOG.md` (rows "Dave"), `ITEM_TRIM_DECISIONS.md`, decisions quoted in `docs/FINAL_HANDOFF_REPORT_11Nov.md` s7 (61, 69, 70, 71, 73) | APPROVED where the above are silent |
| agent plans | `docs/design/item_system.md` draft 7, `buildables_plan.md`, `progression.md`, `wood_tier_note.md` | Not authoritative where they differ; superseded points in s2.10 |
| data | `data/items/*.json`, `data/npcs/shops.json` | What exists; ids and numbers preserved |

Labels in sections 3 and 7 and Appendix A: **APPROVED** (Dave), **DECIDED** (ChatGPT for Dave, [C]), **ENGINEERING** (follows directly from the above; no new design), **DELEGATED** (a technical default the implementing agent follows; changing it needs ChatGPT's or Dave's nod, but it changes no item, count or owner rule). **RECOMMEND** rows are Claude's engineering defaults and are treated as DELEGATED.

## 2. Design decisions

### 2.1 Tool ladders and roles [R][B][D1]

| Family | Ladder | Role |
|---|---|---|
| Axe | Stone, Bronze, Iron, Steel | Fells; chops logs into blocks and blocks into firewood [D1]. Sharpened (metal). |
| Pickaxe | Stone, Bronze, Iron, Steel | Mines. Sharpened (metal). |
| Spade | Wooden, Iron, Steel (Stone retired [B]; no Bronze) | Digs, including bog iron. |
| Hammer | Wooden, Stone, Bronze, Iron, Steel | Builds. Better hammers gain only automatic material-sourcing range and durability. Any metal hammer builds any tier (decision 73). Not needed for smithing: the Smithy has built-in tools [D1]. |
| Hoe | Wooden, Stone, Iron, Steel (no Bronze) | Six modes: Flatten, Smooth (slope-preserving averaging), Pathen, Survey a Road (two stakes, pathfinding), Create Garden Plot, Plant. |
| Knife | Stone, Bronze, Iron, Steel | A weapon too; harvests carcasses progressively by repeated attacks. Sharpened (metal). |
| Hand saw | Iron, Steel (no Bronze) | Same yields as the sawmill, much slower [D1]. |
| Sickle | Bronze, Iron, Steel (Stone retired) | Portable, precise harvesting. |
| Scythe | Bronze, Iron, Steel | Large-area harvesting. |
| Chisel | Bronze, Iron, Steel | Sculpture and art only; not required for stone construction. |
| Sewing needle | One reusable needle, no tiers | Sewing with consumed Thread; portable simple repairs. |

### 2.2 Durability, repair and sharpening [D1][R][C]

1. Stone tools are disposable and disappear at zero durability; no repair [D1].
2. **Primitive gear is disposable too [C]:** wooden tools (spade, hoe, hammer), stone and flint weapons (Stone - Spear, Stone - Mace, Javelin) and the flint Scraper disappear on breakage. A thrown Javelin that survives the impact can be picked up again; a broken one is gone. Bows, shields and other wooden weapons keep their own durability values.
3. **The Bone - Needle [C]** is reusable across many sewing jobs (the Thread is consumed, not the needle). When it finally breaks it is replaced by crafting a new one by hand from bone, not repaired.
4. Metal tools break at zero durability and stay in the inventory, unusable [D1].
5. A broken metal tool is repaired at the same type of workstation where it was crafted, with appropriate materials, and only up to its remaining maximum durability [D1].
6. Sharpening restores sharpness to 100 % and permanently lowers maximum durability, in proportion to the sharpening [D1].
7. Portable whetstone sharpening and the stationary grindstone are separate mechanics. Whetstone: with accessible water, the player's eligible tools are sharpened automatically one after another, up to five real minutes for a fully dull tool, using nearby seating where there is some. Grindstone: faster, and an NPC can operate it [D1].
8. Sharpening applies to metal axes, pickaxes and knives, and to other metal edged tools where it fits (saws, sickles, scythes, chisels). It is not applied to hammers, hoes and spades; those follow rules 4 and 5.

### 2.3 Wood and graded furniture [D1][R][B][C][D4]

1. A 3 m softwood/basic Log becomes 6 Planks; a 3 m hardwood species log becomes 4 Hardwood Boards. Iron/Steel hand saws and the waterwheel reciprocating sawmill have equal yields, but hand sawing is much slower. Felled full logs are 3.0 m; adjust weight and geometry consistently.
2. **NO SUBSTITUTION IN EITHER DIRECTION [D4].** Planks and Hardwood Boards are distinct ingredients. Hardwood Boards never meet a Plank cost, and Planks never meet a Hardwood Board cost, including recipes, blueprints, NPC jobs and automatic storage sourcing. Do not create a shared ingredient group or permission-based fallback.
3. **Furniture grades [D4]:** **Crude, Rustic, Fine, Ornate** (Fine is Dave's "Nice", Ornate his "Fancy"). They are production and appearance grades of furniture, separate from the +1/+2 physical craftsmanship slot and from enchantments. They are used only on families where a grade changes something real (storage slots or comfort points, look, value). Families, rows and costs: s3.5.
4. **Finished wooden furniture uses Hardwood Boards [D4][D5]:** Crude can use few boards and wooden pins/twine; **Rustic can be simply Hardwood Boards plus existing nails**, with hinges only on objects that require them. Fine and Ornate use progressively **more Hardwood Boards and more nails**, with extra quality shown in fit, finish and appearance. Upholstered/padded pieces may additionally require **cloth, leather, cushions or hides as relevant**; never force cloth or leather into a bare wooden table, chest or shelf just because it is Fancy. Use existing Bronze nails 894, iron Nails 228, Bronze hinges 895, iron Hinges 232, Wooden pin 233, Twine 5 and existing textiles/leathers. Do not invent premium nail tiers, demand iron-only nails just for a grade, or add unnecessary materials. Planks and Hardwood Boards still **never substitute** for each other.
5. **Not graded finished furniture [D4]:** the Crate (item 850, blueprint 168) is a rough packing box and stays on Planks; the Wicker - Chest (item 23, blueprint 26) stays the stick-and-twine starter. Log, stick, straw, hide, wool and stone furniture is not board furniture and is unchanged. Crude furniture needs no metal, so furniture is reachable as soon as the first saw makes Hardwood Boards.
6. Retire unused species-specific `lumber_*` and `beam_*` rows, but keep the species `log_*` rows. No board sizing or Fine Board processing step, no stone wedges, bronze saws or saw-blade intermediates.
7. An axe chops softwood Log → Softwood Blocks → Soft Firewood and hardwood Log → Hardwood Blocks → Hard Firewood. Hard Firewood delivers equal heat for longer burning. Whole logs remain usable for building or charcoal.
8. Planks and Hardwood Boards both start at the first Iron Hand Saw. Planks exist in every forested biome (softwood species and the plain Log); Hardwood Boards only where hardwood species grow (s6 row 30).

### 2.4 Chopping Block [D1]

Not retired. An optional firewood workstation: players still chop by hand anywhere; open it, choose Soft or Hard Firewood and a quantity; it sources eligible raw wood from storage within a configurable radius and may take logs through blocks to firewood; it never consumes planks, boards or other crafted wood; own input and output capacities; an NPC woodcutter can run it later; look: chopping stump, embedded axe, firewood pile that grows and shrinks with its inventory.

### 2.5 Universal workstation storage and sourcing [D1][R]

Every workstation where practical (Smelters, Blast Furnaces, Smithies, Kilns, Sawmills, Chopping Blocks, Looms, Tailor's Tables and others): configurable storage capacity; input and output capacities may differ; finished products stay in the station and never drop on the ground; full output pauses production; nearby authorized workstations draw ingredients from station inventories and other accessible storage within sourcing range (automatic material sourcing); players deposit and withdraw; world-visible inventory reflects actual quantities with efficient fill levels and grouped meshes; inputs and outputs look different.

### 2.6 Charcoal, fuel and kilns [D1]

Any wood-burning fire or workstation may give a small charcoal byproduct. Charcoal can replace wood as fuel and burns longer. Mined Coal and wood Charcoal are distinct. A Kiln turns 3 m logs into charcoal at 100 per log; a basic kiln holds about six logs (up to 600 per batch); production is gradual, as a batch; if it keeps burning after conversion it slowly consumes its own charcoal; it can be put out and relit like a fire, and putting it out keeps the contents; players take charcoal out, or nearby authorized workstations draw it. Larger kiln tiers can hold more. No exact times or fuel rates are set.

### 2.7 Metalworking [D1][R][B][C]

1. **Wilderness route to the first Iron Hand Saw, no purchases [D1]:** find bog iron (dug with any spade in wet ground); gather stone and clay and build a **Smelter**; gather kindling, sticks and firewood; make charcoal; smelt bog iron into Iron ingots; build a **Smithy** from stones, clay, logs and Iron ingots; craft the **Iron Hand Saw at the burning Smithy** from iron and wood.
2. The Smithy contains a forge, anvil and bench (built-in blacksmithing tools); no player-held smithing hammer and no Saw Blade ingredient [D1].
3. **Smelter**: copper, tin and iron ore (bog iron) to ingots, and bronze alloy. **Blast Furnace**: its advanced, high-capacity tier, and steel [D1]. No smelting at any forge or smithy [C].
4. **Bronze before iron [C]:** the **Stone - Forge (88)** stays as the bronze smithy. It shapes bronze items only, has an iron-free cost, and does no smelting. The ordinary Smithy also works bronze, and additionally iron and steel. This keeps Bronze a real rung before Iron and keeps the wilderness route to the Iron Hand Saw.
5. **Bellows and Quenching Trough are add-ons attached to the Smithy, not workstations [D4].** Bellows: faster warm-up and metalworking, lower fuel use [C]. The **Quenching Trough** upgrades the Smithy so it can make better metal goods; every plain recipe still works without it, so it never blocks progression. **Confirmed [C7]:** with the Quenching Trough attached, the Smithy can make eligible **steel** tools, weapons and armour as **Tempered** items. Tempering is a property of the **individual crafted instance**, not a duplicate master item definition or standalone workstation. It increases suitable maximum durability; slower sharpness loss applies **only to sharp-edged equipment**, never to blunt tools/weapons or armour without a sharpness mechanic. The name may show "Tempered" dynamically. It does not use craftsmanship or magical enhancement slots; it cannot be added by repair/reheating or stacked repeatedly. The normal steel recipe remains available without the add-on. Initial scope excludes bronze and low-carbon iron; specific bonuses, recipe effort and fuel remain balancing decisions.
6. **Master Smithy**: a distinct, ornate prestige workshop for special and masterwork items with +1/+2 physical craftsmanship. Wizard enchantments are separate [D1].
7. **Station rows [C]:** Brick - Forge 90 (`blacksmithy`) becomes the Smithy; the never-built Large forge rows 92/93 become the Blast Furnace; the never-built Master forge rows 94/95 become the Master Smithy; the standalone Anvil 827 retires, because the Smithy has its own anvil. Every reference, look, blueprint, recipe, name and test changes with the renames. Retired numbers are never reused.
8. **No Clay Bloomery.** No public-release migration is needed: Dynasty has never been publicly released or played by other players [D1]. Dave's 12 Nov request still adds a safe one-time migration for local and playtest saves, so no retirement or change loses items (`CATALOG_SAVE_MIGRATION.md`).

### 2.8 Leather and textiles [R][B][D1][C]

1. Tanning and drying for hides and leather; a **Leatherworking Table** for leather goods; a **Tailor's Table** for clothing; the **Loom** for weaving [R].
2. **Split [C]:** the Leatherworking Table makes leather straps, belts, quivers, backpacks and leather garments, boots and gloves. The Tailor's Table makes cloth, wool, linen, fibre-cloth and fur clothing. Metal armour stays at the smithies.
3. **Day one [C]:** basic hide garments stay hand-sewable with the Bone - Needle and Thread, so clothing needs no building.
4. **Thread [C]:** a distinct Thread item, separate from Twine (coarse binding cord). It is consumed in small amounts for hand sewing and portable repairs. It is hand-craftable from plant fibre (later also from spun wool); the Spinning wheel makes it faster when it is introduced; the Loom still does weaving.
5. Needle and Thread give portable simple repairs; repair at a workstation is also supported for suitable finished goods. Full production needs no extra needle tier.

### 2.9 Item enhancements [B][R][D1][DE][C]

1. At least three enhancement slots per eligible item instance: one physical craftsmanship, two magical. Empty slots are hidden (shown only where relevant).
2. Effects belong to individual item instances, not item definitions.
3. Physical craftsmanship improves what suits the type (weight, durability, sharpness, damage, efficiency or value), at most +2 where numeric. Magical slots carry separate supernatural effects.
4. Craftsmanship and magic coexist; physical and magical numeric bonuses are calculated separately and add on the same statistic (e.g. **Mighty Steel Sword +4** = +2 physical + 2 magical damage; **Light Flaming Steel Sword of Might +2** shows three distinct effects).
5. The display name reflects the actual enhancements rather than a generic +1 label, and dynamic names are not bound by the static four-word name rule.
6. **Permanent [DE]:** an enchantment can never be removed, replaced, overwritten, extracted, transferred or refunded. Each of the two magical slots may be filled only while empty, and the effect stays bound to its item for the item's lifetime. Physical craftsmanship is fixed when the item is crafted.
7. **Eligibility [C]:** at first, individually tracked tools, weapons, shields, armour, clothing and gear. Food, ammunition, bulk materials and other stackable consumables are excluded. The slot schema is the same for every item. Enhanced items never merge with ordinary stacks. Enchanting single units of a normally stackable item is not supported and would need its own approval.

### 2.10 Older rulings superseded

Bellows dropped; Clay bloomery added; Large forge and Master forge parked with the anvil as the steel step; one forge model upgraded in tiers (Dave 25 Oct, superseded by his newer decision); Stone wedge lumber route; Saw blade as saw and sawmill part; hand saw at half the sawmill's yield; hone +25 % with a 75 % cap; repair anywhere restoring 50 %; grindstone skipped; kiln 2 Firewood → 2 Charcoal; planned Bronze Spade, Bronze Hoe, Bronze Saw and Iron Needle; chisel required at the Stonecutter's bench; four-word limit on dynamic names; Twine as sewing thread; enchantment overwrite (draft 4).

## 3. Catalog by row

Stable ids and numbers are kept and never reused, including retired ones (`fine_board` 227 and `rough_plank` 226 stay retired). New rows take numbers from `next_number` at implementation; none are reserved here. Labels as in s1.

### 3.1 Tools

| # | id | Name | Status | Change |
|---|---|---|---|---|
| 6, 11, 222, 244, 297 | stone_axe, stone_knife, stone_hoe, stone_hammer, stone_pickaxe | Stone tools | UPDATE (APPROVED) | Disposable: remove `repair` and `edge`; disappear at zero. |
| 19, 221, 247 | wooden_spade, wooden_hoe, wooden_hammer | Wooden tools | UPDATE (DECIDED) | Disposable: remove `repair`. |
| 293, 7, 313, 295 | hide_scraper, spear, stone_mace, javelin | Scraper, Stone - Spear, Stone - Mace, Javelin | UPDATE (DECIDED) | Disposable: remove `repair`; an unbroken thrown Javelin is picked up again. |
| 49 | sewing_needle | Bone - Needle | UPDATE (DECIDED) | The one reusable needle (27 live recipes keep it). Remove `repair` (1 Bone); a broken needle is replaced by recipe 29. |
| 45 | stone_spade | Stone - Spade | RETIRE (APPROVED) | Recipe 26 retires. |
| 298 | sickle | Stone - Sickle | RETIRE (APPROVED) | Recipe 187 retires; new sickles take new ids. |
| 459, 461 | bronze_axe, bronze_knife | Bronze - Axe, Knife | UPDATE (APPROVED) | Break, repair at a bronze-working station, sharpening. |
| 458, 33 / 34 | bronze_pickaxe, iron_pickaxe / steel_pickaxe | Pickaxes | UPDATE / FUTURE | As above; pickaxes gain sharpening. |
| 46 / 47 | iron_spade / steel_spade | Spades | UPDATE / FUTURE | Break and repair; no sharpening. |
| 460, 560 / 561 | bronze_hammer, iron_hammer / steel_hammer | Hammers | UPDATE / FUTURE | Break and repair; role per 2.1. |
| 223 / 224 | iron_hoe / steel_hoe | Hoes | UPDATE / FUTURE | Break and repair; six modes (code). |
| 245 | hand_saw | Iron - Saw | UPDATE (APPROVED) | Crafted at the burning Smithy from iron and wood (recipe 157); sawmill yields, slower; sharpening. |
| 299 | scythe | Iron - Scythe | UPDATE (APPROVED) | Break, repair, sharpening. |
| 798, 799 / 800 | bronze/iron_chisel / steel_chisel | Chisels | UPDATE / FUTURE | Break, repair, sharpening; sculpture only. |
| 815 | whetstone | Whetstone | UPDATE (APPROVED) | Portable sharpening (2.2). |
| new | | Iron - Axe, Steel - Axe, Iron - Knife, Steel - Knife, Steel - Saw, Bronze - Sickle, Iron - Sickle, Steel - Sickle, Bronze - Scythe, Steel - Scythe | ADD (APPROVED) ×10 | Fill the ladders in 2.1. Bronze rows at the Stone - Forge or Smithy, iron and steel rows at the Smithy. New knives join group `knife`, new axes group `axe`, the Steel - Saw group `saw`. |
| new | | Grindstone | ADD (APPROVED) | Stationary sharpening; NPC-operable. |
| 296 | obsidian_knife | Obsidian - Knife | FUTURE | Not in the ladder; stays parked (its material Obsidian 281 is future too). |
| 807, 344, 75, 260, 557, 12/542, 311, 668/669/892/893, 294 | | Mortar and pestle, Hand mill, Fishing rod, Fishing net, Wooden - Spyglass, Torch, Candle, lanterns, Steel - Striker (future) | KEEP | Unaffected. |

### 3.2 Wood

| # | id | Name | Status | Change |
|---|---|---|---|---|
| 4 | log | Log | KEEP | Basic log → Planks (2.3); chops into Softwood blocks (s4 item 3). |
| 100, 103, 106, 124, 148, 172 | log_oak, log_beech, log_birch, log_tropical_hardwood, log_walnut, log_maple | Hardwood species logs | KEEP | → Hardwood Boards, Hardwood Blocks. |
| 109, 112 | log_scots_pine, log_spruce | Softwood species logs | KEEP | → Planks, Softwood Blocks. |
| 27 | lumber | Plank | UPDATE (APPROVED) | 6 per softwood or basic log (today 4 at the sawmill, 2 by hand saw). Name stays "Plank". |
| new | | Hardwood board | ADD (APPROVED) | Four per hardwood species log, sawmill or Iron/Steel Hand Saw. Distinct from Plank; no substitution. Finished furniture uses grade-appropriate counts of Hardwood Boards. |
| 234 | wooden_block | Wooden block | UPDATE (ENGINEERING) | Rename **Hardwood block** (Dave's term, singular by the naming rule). |
| 237 | wooden_block_soft | Softwood block | KEEP | |
| 26 | firewood | Firewood | UPDATE (ENGINEERING) | Rename **Hard firewood**; burns longer (2.3). |
| 236 | firewood_soft | Softwood firewood | UPDATE (ENGINEERING) | Rename **Soft firewood**. |
| 540, 541 | wooden_block_large, wooden_block_soft_large | Large wooden / softwood block | KEEP | Larger blocks from big trunks; still log → block → firewood. The Chopping Block item is made from 540 (recipe 15). |
| 25 | chopping_block | Chopping block | UPDATE (APPROVED) | Firewood workstation (2.4). Kit 24 stays retired. |
| 241 | saw_mill | Sawmill | UPDATE (APPROVED) | 6 Planks per softwood log, 4 Hardwood boards per hardwood log; no Saw blade in blueprint 11. |
| 238 | saw_blade | Saw blade | RETIRE (APPROVED) | Recipe 152 retires. |
| 239 | water_wheel | Water wheel | KEEP | Sawmill part. |
| 353 | stone_wedge | Stone - Wedge | RETIRE (APPROVED) | Recipes 227, 230 retire. |
| 101–174 (16 rows) | lumber_oak … beam_walnut | Species lumber and beams (future) | RETIRE (DECIDED) | Superseded by Plank and Hardwood board. References handled in s4 item 3 (`wood_species.json retired_to`, Hob's buy rules in `shops.json`). Species `log_*` rows stay. |
| 243 | woodworking_table | Woodworking table | RETIRE (APPROVED) | **In open PR #1036** (item 243, blueprint 12, structure state 35). Carpenter's bench 86 stays. |
| 205, 207 | timber_prop, timber_set | Post, Beam | KEEP | Building pieces. |
| see s3.5 | | Graded furniture | UPDATE ×14, ADD ×6 [D4] | Families, grades, costs and looks in s3.5. |

### 3.3 Metalworking, fuel and kilns

| # | id | Name | Status | Change |
|---|---|---|---|---|
| new | | Smelter | ADD (APPROVED) | Blueprint: stone and clay. Smelting recipes 190, 191, 192 and alloy 185 move here. |
| 88 | stone_forge | Stone - Forge | UPDATE (DECIDED) | Bronze smithy: shapes bronze items only, no smelting, iron-free cost (live: 24 Stone, 10 Clay, 2 Hide). |
| 90 | blacksmithy | Brick - Forge → **Smithy** | UPDATE (DECIDED) | Blueprint 10: stones, clay, logs, Iron ingots; built-in forge, anvil, bench; must be burning to craft. Works bronze, iron and steel. |
| 93 (92 kit) | large_forge | Large forge → **Blast Furnace** | UPDATE (DECIDED) | Goes live: steel (recipe 193) and advanced, high-capacity smelting. Kit 92 stays an unused future row. |
| 95 (94 kit) | master_forge | Master forge → **Master Smithy** | UPDATE (DECIDED) | Goes live: prestige workshop, masterwork +1/+2. Kit 94 stays an unused future row. |
| new | | Bellows, Quenching Trough | ADD (APPROVED) ×2 | Add-on structures to Smithy, NOT independent workstations. Quenching Trough enables better metalworking recipes/outputs in the upgraded Smithy; ordinary recipes remain. |
| 827 | iron_anvil | Anvil | RETIRE (DECIDED) | Blueprint 164 and structure state 204 retire; kit 826 is already retired. |
| 795 | clay_bloomery | Clay bloomery | RETIRE (APPROVED) | Structure state 200, blueprint 162, recipe 367 retire. |
| 771 | kiln | Kiln | UPDATE (APPROVED) | Batch charcoal from logs (2.6); bricks, roof tiles, lime stay. |
| 547 | charcoal | Charcoal | UPDATE (APPROVED) | 100 per log at the kiln; also a fire byproduct; can replace wood as fuel. |
| 304 | coal | Coal | KEEP | Distinct mined fuel. |

### 3.4 Leather and textiles

| # | id | Name | Status | Change |
|---|---|---|---|---|
| 773 | tanning_rack | Tanning rack | KEEP | Recipes 234, 235. |
| 775 | drying_rack | Drying rack | UPDATE (APPROVED) | Adds the hide drying step; food drying stays. |
| new | | Leatherworking Table | ADD (APPROVED) | Recipes 278 (Leather strap), 392 (belt), 356 (quiver), 361 (backpack), 213, 214, 358, 359, 360 (leather garments) move here. |
| new | | Tailor's Table | ADD (APPROVED) | Recipes 216 (Fibre - Gambeson) and 237–244 (wool, linen, fur clothing) move here. |
| new | | Thread | ADD (DECIDED) | Hand recipe from plant fibre (amounts s5). Replaces Twine in the 13 needle recipes that use it: 23, 39–42, 173, 194–196, 237, 238, 241, 388. |
| 5 | twine | Twine | KEEP | Binding cord for tools, buildings and gear; no longer sewing thread. |
| — | | Hand-sewn hide goods | KEEP | Recipes 23, 30, 39–42, 173, 194–196, 388 stay by hand with the needle (2.8 item 3). Fur garments 242–244 keep Sinew. |
| 846 | loom | Loom | UPDATE (APPROVED) | Goes live with a blueprint and structure state; cloth recipes 245 (Linen), 334 (Fibre cloth), 342 (Wool cloth) move to it. |
| 845 | spinning_wheel | Spinning wheel | FUTURE | Later: faster Thread and spun wool (2.8 item 4). |

### 3.5 Furniture [D4][D5][C7]

**Confirmed family scope [C7].** A family gets grades only where grades change useful storage/comfort and visual quality, not just a name:
- Chests get four grades, because storage is the main progression.
- Chairs and tables get four grades, for comfort.
- Benches get two, as a simple object.
- Shelf, Cupboard, Barrel, Weapon rack, Armour stand and Canopy bed stay single objects. They already form a ladder by object, and four copies of each would add nothing.

Existing rows are reused for grades wherever one fits, so only 6 rows are new.

**Material rule [D5].** Grades are told apart by **how many** Hardwood Boards and nails they use, by finish and look, and by upholstery where a piece has a seat or bedding. Fittings come from existing items only. `nails` and `hinges` are filled by either Bronze or iron ones through the existing groups (bronze is spent first). No grade demands iron-only nails, a new nail tier, or cloth or leather on a bare table, chest or shelf.

| Grade | Boards and nails | Hinges | Upholstery (seats only) | Hammer | Look |
|---|---|---|---|---|---|
| Crude | Fewest boards; Wooden pins and Twine, no nails | None (lids tied) | None | Any (`hammer` 1) | Rough boards, visible pegs and lashings |
| Rustic | More boards; `nails` | `hinges` on lids and doors | None | Any (`hammer` 1) | Plain nailed boards |
| Fine | More boards; more `nails` | `hinges` on lids and doors | Leather | Metal (`hammer` 3, as the Iron rows have today) | Planed, smooth, fitted joints |
| Ornate | Most boards; most `nails` | `hinges` on lids and doors | More Leather plus a Wool cloth cushion | Metal (`hammer` 3) | Carved trim, elaborate joinery |

**Rows** (item / blueprint / structure state; "new" rows take numbers at implementation):

| Family | Grade | Row | Status | Cost (materials; amounts in s5) | Utility |
|---|---|---|---|---|---|
| Chest | Crude | new | ADD | **Crude - Chest**: boards, Wooden pins, Twine | Slots between the Crate (10) and Rustic (20) |
| Chest | Rustic | item 29 / bp 27 / state 48 | UPDATE | Rename Wooden - Chest → **Rustic - Chest**: boards, `nails`, `hinges` (Planks and Twine dropped) | 20 slots (today) |
| Chest | Fine | new | ADD | **Fine - Chest**: more boards and `nails`, `hinges` | Between 20 and 30 |
| Chest | Ornate | item 852 / bp 169 / state 209 | UPDATE | Rename Iron - Chest → **Ornate - Chest**: most boards and `nails`, `hinges`, Iron bands (in place of today's 3 Iron ingots; the banded strongbox look this row already has) | 30 slots (today) |
| Chair | Crude | new | ADD | **Crude - Chair**: boards, Wooden pins | Lowest seat comfort |
| Chair | Rustic | item 505 / bp 42 / state 62 | UPDATE | Rename Wooden - Chair → **Rustic - Chair**: boards, `nails` (Planks, Hide and pins dropped) | Seat 2 (today) |
| Chair | Fine | item 639 / bp 93 / state 128 | UPDATE | Rename Iron - Chair → **Fine - Chair**: more boards and `nails`, Leather (Iron ingot and Hide dropped) | Above Rustic |
| Chair | Ornate | new | ADD | **Ornate - Chair**: most boards and `nails`, more Leather, Wool cloth | Highest seat comfort |
| Table | Crude | new | ADD | **Crude - Table**: boards, Wooden pins, Twine | Lowest table comfort |
| Table | Rustic | item 506 / bp 43 / state 63 | UPDATE | Rename Wooden - Table → **Rustic - Table**: boards, `nails` (Planks and Twine dropped) | Table 2 (today) |
| Table | Fine | item 641 / bp 94 / state 129 | UPDATE | Rename Iron - Table → **Fine - Table**: more boards and `nails` (Iron ingot dropped) | Above Rustic |
| Table | Ornate | new | ADD | **Ornate - Table**: most boards and `nails` | Highest table comfort |
| Bench | Crude | item 504 / bp 41 / state 61 | UPDATE | Rename Wooden - Bench → **Crude - Bench**: boards, Wooden pins, Twine | Seat 1 (today) |
| Bench | Fine | item 637 / bp 92 / state 127 | UPDATE | Rename Iron - Bench → **Fine - Bench**: more boards and `nails`, Leather (Iron ingot dropped) | Above Crude |
| Shelf | single | item 645 / bp 96 | UPDATE | Few boards, Wooden pins, Twine | 8 slots |
| Cupboard | single | item 647 / bp 97 | UPDATE | Boards, `nails`, `hinges` (as today, Planks → boards) | 16 slots |
| Barrel | single | item 649 / bp 98 | UPDATE | Boards, `nails`, Twine (as today, Planks → boards) | 8 slots |
| Weapon rack, Armour stand | single | items 787, 789 / bp 158, 159 | UPDATE | Boards, Twine (as today, Planks → boards) | 6 slots each |
| Canopy bed | single (the Ornate bed) | item 511 / bp 48 | UPDATE | Boards, Feathers, Fibre cloth (as today, Planks → boards) | Bed 5, the best bed |
| Crate | not graded | item 850 / bp 168 | KEEP | Planks, `nails` (a rough packing box) | 10 slots |
| Wicker - Chest, Stool, Seat, log furniture, Stone - Bench and Table, Straw and Feather beds, rugs | not graded | 23, 503, 502, 629, 631, 719, 848, 633, 635, 509, 510, 507, 508 | KEEP | No boards involved | Early comfort and storage. Log - Bench 629 and Log - Table 631 have retired blueprints (88, 89) and stay only for old saves; the Stool needs Wooden pins from Planks. |

**Notes:**
- Value follows the material cost, checked by the `items_check.py` economy test.
- Each grade needs its own look (`looks.json`) and its own structure state.
- Furniture needs no station; every row stays a hammer blueprint.
- Every material named exists and is sourced today: Hardwood Board (ADD), Wooden pin 233 (recipe 150), Twine 5, `nails` 228/894, `hinges` 232/895, Leather 283 (Tanning rack), Wool cloth 548 (Loom), Iron band 859 (Smithy), Feathers, Fibre cloth 517.

### 3.6 Weapons and ammunition [D6] (category approved by Dave, 12 Nov 2026)

Dave approved ChatGPT's Weapons Proposal 2 in full, plus his own Poison Arrow request (PR #1035 comment of 12 Nov 01:49Z). This is approval of the category only, not of the whole catalog. All metal weapon rows stay FUTURE until their metal is live in game. Balance numbers (damage, reach, speed, stamina, armour penetration, reload) are not set here (s5).

**Roles every weapon row carries:** one or two hands, and whether a torch or shield can be held with it; reach; recovery and stamina; armour penetration; for ranged weapons, reload time and the space they need. Durability, repair, sharpening, Tempered, craftsmanship and enchantments follow s2.2, 2.7 and 2.9 unchanged. Bronze weapons are made at the Stone - Forge or the Smithy, iron and steel weapons at the Smithy, and wooden weapons at hand or at the workbench like today's bows.

**Existing weapon rows (21 KEEP or UPDATE; ids unchanged):**

| # | id | Name | Status | Change |
|---|---|---|---|---|
| 10, 7 | wooden_spear, spear | Wooden - Spear, Stone - Spear | KEEP / UPDATE | Stone - Spear: disposable (s2.2); recipe 3 should **consume** its Stone head, not keep it (defect). |
| 300, 761, 313 | wooden_club, bone_club, stone_mace | Wooden - Club, Bone - Club, Stone - Mace | KEEP / KEEP / UPDATE | Stone - Mace disposable (s2.2). |
| 295 | javelin | Javelin | UPDATE | Disposable, recoverable when unbroken (s2.2). Fix the defect of `stack: 5` alongside `unstackable: true`; one javelin per slot. |
| 816 | fishing_spear | Fishing spear | KEEP | |
| 813 | sling | Sling | KEEP | Throws ordinary Stones; no sling ammunition item. |
| 269 | wooden_bow | Wooden - Bow → **Shortbow** | UPDATE | Rename only. |
| 763 | wooden_longbow | Wooden - Longbow → **Longbow** | UPDATE | Rename only. |
| 315, 318, 321 | bronze/iron/steel_sword | Swords | FUTURE | The versatile one-handed sword. Steel - Sword's description ("A tempered steel blade") is a defect: Tempered is optional (2.7 item 5). |
| 316, 319, 322 | bronze/iron/steel_mace | Maces | FUTURE | |
| 312, 314 | wicker_shield, plank_shield | Wicker - Shield, Wooden - Shield | KEEP | |
| 317, 320, 323 | bronze/iron/steel_shield | Metal shields | FUTURE | Bronze - Shield (recipe 206) needs Planks, which do not exist before the first Iron Hand Saw: defect. Rework it as a bronze-reinforced shield on a pre-saw base (Wicker or hide). |

**Dual-use tools (cross-listed, not duplicated):** Stone, Bronze, Iron and Steel Axes and Knives are also the hand-axe and dagger weapons. Iron and Steel Axe and Knife are already among the 18 tool and station ADD rows (s3.1 to s3.4), so they are not counted again. No separate Handaxe or Dagger rows.

**New weapon rows (24 ADD):**

| Group | New rows |
|---|---|
| Swords | Iron - Shortsword, Steel - Shortsword, Iron - Greatsword, Steel - Greatsword, Steel - Rapier, Steel - Scimitar |
| Axes and heavy | Iron - Battleaxe, Steel - Battleaxe, Iron - Greataxe, Steel - Greataxe, Iron - Warhammer, Steel - Warhammer, Steel - Maul |
| Spears, staves and polearms | Quarterstaff, Bronze - Spear, Iron - Spear, Steel - Spear, Iron - Pike, Iron - Halberd, Steel - Halberd, Iron - Trident |
| Ranged and defence | Light crossbow, Heavy crossbow, Iron - Buckler |

**Ammunition:**

| Rows | Status | Note |
|---|---|---|
| Wooden - Arrow 270, Stone - Arrow 271, Bone - Arrow 352, Fire arrow 817 | KEEP | |
| Bronze - Arrow, Iron - Arrow, Steel - Arrow | ADD ×3 | Arrowheads at the bronze or iron smithies. |
| Wooden bolt, Iron bolt | ADD ×2 | For the crossbows. |
| Steel bolt | FUTURE (new row) | |

**Other future rows:** Iron - Lance, with horses and mounted combat (FUTURE, new row).

**Poison arrows [D6].** A poison preparation is applied to an existing Wooden, Bone, Bronze, Iron or Steel Arrow. The arrow keeps its physical properties and adds poison over time, set by the poison's strength and the target's resistance. The coating is used up on impact; a recovered arrow comes back unpoisoned. **No poisoned-arrow item rows.** The coating is not an enchantment. It is a stack-level state: poisoned arrows of one base and one poison stack only with each other. The poison itself is designed in the later medicine and alchemy review.

**Left out on purpose:** Greatclub, Light hammer, Sickle as a weapon, Flail, Morningstar, Glaive, War pick, Dart, Hand crossbow, Blowgun, Whip, Net as a weapon, firearms, Recurve bow, Iron-shod staff, material-tiered Javelins, Throwing knives. Sickles stay harvesting tools and nets fishing gear.

**Counts for this category:** 21 existing weapons (2 renamed); 4 existing arrows kept; 29 ADD rows (24 weapons, 3 arrows, 2 bolts); 2 new FUTURE rows (Steel bolt, Iron - Lance); 0 retired. With the 8 cross-listed tools and the poison-arrow rule, this is the 65-entry roster Dave approved.

**3.7 reconciliation against the data (Claude, 12 Nov; desk review of `items.json`, `recipes.json`, `clothing.json` on dev `7f8aabf4`):**

| Check | Finding | Result / resolution |
|---|---|---|
| Ids and names | All 8 core armour rows and all 8 cross-listed clothing rows exist with the names and numbers above. The 6 metal core rows (326, 328, 329, 330, 331, 838) are FUTURE; Leather - Jerkin 325 and Fibre - Gambeson 327 are live. | PASS. Statuses unchanged in Appendix A. |
| Recipes and stations | Hide pieces by hand with the needle (39–42, 194–196). Leather pieces at workbench L2 → Leatherworking Table (s3.4). Gambeson 216 → Tailor's Table. Bronze Helm 215 and Scale shirt 397 at `forge` (Stone - Forge or Smithy). Iron 217, 218 and steel 219, 220 at `brick_forge` → Smithy, with the Anvil level dropped (s4 item 10). | PASS. Matches rule 4. |
| Materials for the 14 new rows | Everything they plausibly need already exists: Iron and Steel ingots, Rivets 184 (Smithy), Leather, Heavy leather 235 (Tanning rack), Fibre and Wool cloth (Loom). | PASS. Exact costs in s5. |
| Locked recipes | The six metal armour recipes (215, 217–220, 397) carry `locked`, like the metal weapons. | NOTE. Unlocking follows the same rule as metal weapons; no armour-only rule. |
| Iron and steel path | Bronze - Greaves join the bronze pieces at `forge`, before iron. Iron pieces need the Smithy; steel pieces need Blast Furnace steel. No armour recipe needs the Quenching Trough. | PASS. |
| Equipment slots | `clothing.json` has 8 slots (head, body, legs, feet, hands, back, outer, waist) and **one item per slot**. Rule 1 needs layering (coif under helm, gambeson or shirt under mail or plate, sabatons over boots, gauntlets over gloves). | **NEEDS CODE.** Recommended model below. |
| Protection | No item has a protection value, and weapons carry one `damage` number with no damage mode. Rule 2 (slashing, piercing, blunt, projectile; coverage; penetration) is a new combat system. | **NEEDS CODE**, and later balancing. |
| Tempered scope | s4 item 15 listed only the Steel - Helm and Cuirass among armour. | FIXED in s4 item 15: all steel armour rows in 3.7 are eligible, with durability only, never sharpness. |
| Steel - Cuirass 331 description | "The best body armour" is wrong once Half plate and Plate harness exist. | Defect recorded for the data change (rule 6). |
| Hide - Trousers 306 | It is protective hide clothing like the cross-listed Hide - Tunic 305, but it is not in the cross-list. | CLOSED by [D8]: ordinary clothing (s3.8). |

**Recommended layering model (engineering; superseded by the merged model in s3.8).** Each of head, body, hands, legs and feet takes up to three layers:
- **Clothing:** today's warmth pieces.
- **Padding or mail:** Gambeson, Leather - Jerkin, Bronze - Scale shirt, Iron - Mail shirt, Mail hauberk, Mail coif, Mail chausses.
- **Rigid:** helms, Brigandine, Breastplate, Cuirass, Half plate, Plate harness, Gauntlets, Greaves, Sabatons.

`outer`, `back` and `waist` stay single. An item names its layer with a new `layer` field beside its existing `slot`, so the current slot data stays valid. Protection combines across layers per damage mode with diminishing returns (the layers never simply add), and weight and fatigue add up. Old saves load with every worn item on its own slot's clothing layer.

Preserved foods keep today's rows; [D17] adds Smoked Meat and Dried Mushrooms (s3.14). Food recipes change under [D12], [D15] and [D16] (s7 items 18 and 20); medicine and coins are untouched (Appendix A).

### 3.7 Armour [D7] — APPROVED CATEGORY (NOT APPROVAL TO IMPLEMENT)

**Authority:** Dave explicitly accepted ChatGPT's complete Armour Proposal 1 immediately after approving the Weapons Proposal 2. This is CATEGORY design approval; the full Master Items Catalog and game implementation remain unapproved. Armour draws on the recognizable D&D 5e light/medium/heavy archetypes but uses Dynasty's own damage, coverage, fatigue, weather and crafting systems. Preserve all existing numeric item IDs. The armour category is not the clothing category: the shared clothing rows listed below are cross-references, not duplicated.

**Existing dedicated armour — 8 KEEP/UPDATE rows with stable IDs:**

| # | ID | Item | Gameplay role / catalog direction |
|---|---|---|---|
| 325 | `leather_jerkin` | Leather - Jerkin | Light flexible torso defence, separate from temperature clothing |
| 327 | `gambeson` | Fibre - Gambeson | Padded impact-reducing armour, allows under-armour layering |
| 838 | `bronze_scale_shirt` | Bronze - Scale shirt | Early flexible metal torso armour |
| 329 | `mail_shirt` | Iron - Mail shirt | Cut-resistant, flexible, heavy torso armour |
| 331 | `plate_cuirass` | Steel - Cuirass | Rigid advanced chest/back protection; still useful alongside full plate |
| 326 | `bronze_helm` | Bronze - Helm | First metal helmet, Stone Forge |
| 328 | `iron_helm` | Iron - Helm | Riveted general-purpose helmet, Smithy |
| 330 | `steel_helm` | Steel - Helm | Advanced steel helmet with fitting/possible visor, Smithy |

**NEW armour — 14 ADD concepts (all distinct master item rows, IDs/numbers assigned only when approved implementation occurs):**

| Group | Proposed item | Craft station | Distinct purpose |
|---|---|---|---|
| Torso | Iron - Brigandine | Smithy plus leather/cloth components | Concealed small plates fastened to a protective flexible shell |
| Torso | Iron - Breastplate | Smithy | Focused rigid front torso protection, lighter than full plate |
| Torso | Iron - Mail hauberk | Smithy | Longer mail with sleeves and thigh coverage; heavier than shirt |
| Torso | Steel - Half plate | Smithy | Substantial torso/shoulder protection with mobility trade-offs |
| Torso | Steel - Plate harness | Smithy | Articulated premium upper-body protection; not a one-item full-body magical suit |
| Head | Iron - Mail coif | Smithy | Flexible head/neck mail, different blunt defence from rigid helms |
| Hands | Iron - Gauntlets | Smithy | Metal hand/finger armour with dexterity trade-offs |
| Hands | Steel - Gauntlets | Smithy | Advanced articulated gauntlets |
| Legs | Bronze - Greaves | Stone Forge | Early metal lower-leg defence |
| Legs | Iron - Mail chausses | Smithy | Flexible extended chainmail leg coverage |
| Legs | Iron - Greaves | Smithy | Rigid lower-leg protection |
| Legs | Steel - Greaves | Smithy | Advanced articulated lower-leg protection |
| Feet | Iron - Sabatons | Smithy | Armour worn over suitable boots; protection/weight trade-off |
| Feet | Steel - Sabatons | Smithy | Advanced articulated foot plates |

**Existing protective clothing — 8 cross-listed KEEP rows (not eight additional armour items):** Hide - Tunic #305; Hide - Hood #65; Hide - Boots #64; Hide - Gloves #307; Leather - Cap #324; Leather - Trousers #764; Leather - Boots #765; Leather - Gloves #766. Ordinary clothing and survival utility remain their primary role, with modest realistic protection.

**Shield cross-list — 6, already in approved Weapons [D6]:** Wicker #312; Wooden #314; Bronze #317; Iron #320; Steel #323; proposed ADD Iron Buckler. DO NOT add or count a second shield catalogue definition.

**Protection & equipment rules:**
1. Armor is modular by body region: head, torso, hands, legs and feet. Ordinary shirts may go under mail and cloaks over armour. Padded liners may be part of metal armour. Head mail coif beneath helm, sabatons over boots, gambeson beneath other armour require explicit compatible layering rules in the equipment system; do not allow unlimited stacking of protection or duplicated full bonuses. Preserve existing `slot` metadata and plan a compatible sublayer schema, not a destructive replacement.
2. Protection depends on material, coverage, damage mode and penetration. Distinguish slashing, piercing, blunt force, and projectile impact. Fatigue, weight, temperature, wetness, noise, dexterity and movement are trade-offs; avoid fantasy blanket immunity.
3. Leather is lighter/quiet; padded gambeson helps impacts; bronze scales flexible; mail strong against cuts but less resistant to concentrated blunt force; breastplate/cuirass protect vitals; half plate/full harness increase covered area and require maintenance. Distinct armour types must have different useful roles, not mere progressively bigger defence scores.
4. Crafting: primitive hide by hand with reusable Bone Needle + consumed Thread; leather at Leatherworking Table; Gambeson at Tailor's Table; bronze at Stone Forge/Smithy; iron/steel at Smithy. Repairs at suitable original production stations, portable simple sewing for eligible clothing. Ordinary steel armour must not require the Quenching Trough. Master Smithy craftsmanship +1/+2 remains separate.
5. Optional `Tempered` property for eligible steel armour produced at a Smithy with the attached Quenching Trough, per instance with suitable durability benefit, **never sharpness benefit for armour**, no duplicate master item rows and no occupation of one of the two magical enchantment slots. Enchantments stay permanent, never replaceable; physical craftsmanship independent.
6. Armour model visuals should show plate/rivet/strap construction, worn condition and actual equipped components. Description for Steel - Cuirass #331 must not say it is universally the best armour after adding Half plate and Plate harness.
7. Exclude stand-alone Studded Leather, Ring Mail and Splint Armour as redundant/confusing. Brigandine supplies the realistic plated-fabric archetype.
8. Keep **horse barding** for saddles/animal equipment review; **monster-hide armour** for creature material design; **magical robes** for magic/clothing design; **legendary/ceremonial armour** for future quest or prestige design. Do not silently add them now.

**Counts:** 8 existing dedicated armour entries; 14 ADD; 8 existing protective clothing cross-listed; 6 shields cross-listed with approved Weapons = **36 armour-related entries, but only 14 new item rows**. No item IDs reused; deduplicate all cross-listed items when combining catalog totals.

**Cross-document reconciliation required before final catalog approval:** Inspect equipment slots `head/body/hands/legs/feet/outer`, durability, recipe/blueprint materials, smelting gates and skill stations, armour/body coverage, damage resistance and UI. Repair and layering tests are not established by this desk-approved design. (Historical: full-catalog readiness is now in s8.)

### 3.8 Clothing [D8] — OWNER APPROVED (NOT APPROVAL TO IMPLEMENT)

**Authority:** Dave explicitly approved ChatGPT's complete Clothing Proposal 1 together with prior category decisions. This is clothing-category approval only, not approval of the full Master Items Catalog or gameplay implementation. Separate from Armour [D7], with eight dedicated armour items cross-listed but not duplicated.

**Keep existing 24 non-armour clothing items with stable IDs:**

| Purpose | Existing item # and name |
|---|---|
| Primitive fibre | #60 Fibre - Skirt; #61 Fibre - Cloak; #62 Fibre - Sandals |
| Primitive hide | #63 Hide - Cloak; #64 Hide - Boots; #65 Hide - Hood; #66 Hide - Mittens; #305 Hide - Tunic; #306 Hide - Trousers; #307 Hide - Gloves |
| Everyday leather | #324 Leather - Cap; #764 Leather - Trousers; #765 Leather - Boots; #766 Leather - Gloves |
| Wool | #366 Wool - Tunic; #367 Wool - Trousers; #368 Wool - Cap; #369 Wool - Mittens |
| Linen | #370 Linen - Shirt |
| Fur | #371 Fur - Cloak; #372 Fur - Hat; #373 Fur - Boots |
| Climate/terrain | #768 Straw - Hat; #820 Snowshoes |

Retired Hide - Leggings #67 remains retired, redundant with Hide - Trousers. **Armour** #325 Leather - Jerkin; #327 Fibre - Gambeson; #326 Bronze - Helm; #328 Iron - Helm; #329 Iron - Mail shirt; #330 Steel - Helm; #331 Steel - Cuirass; #838 Bronze - Scale shirt are covered by [D7], not part of the 24 ordinary-clothing rows.

**Add these 17 ordinary clothing items (new distinct item definitions, numbers assigned at authorized implementation only):**

| Group | ADD item | Material and distinct use |
|---|---|---|
| Everyday | Linen - Trousers | Linen; breathable warm-weather legs |
| Everyday | Linen - Skirt | Linen; lightweight warm-weather garment |
| Everyday | Linen - Dress | Linen; one-piece body/leg coverage |
| Everyday | Wool - Dress | Wool cloth; warm one-piece body/leg coverage |
| Outer | Wool - Cloak | Wool cloth; everyday outer warmth |
| Outer | Wool - Coat | Wool cloth and Thread; fitted heavy cold-weather outerwear |
| Outer | Wool - Robe | Wool cloth; ordinary robe for civilians, scholars, clergy and mages (NOT automatically magic) |
| Outer/work | Oilcloth - Cloak | Linen plus suitable drying oil and finishing; rain-repellent, maintainable, not magic waterproof |
| Work | Linen - Apron | Linen; cooking, tailoring and household work |
| Work | Leather - Apron | Leather; sparks/abrasion protection for smithing/woodworking, not fireproof |
| Social | Tabard | Linen or Wool; faction heraldry and uniform colours as customizable appearance, no duplicate item row per emblem |
| Head | Linen - Headwrap | Linen; sun/dust/heat protection |
| Head | Leather - Broad-brim hat | Leather; more durable sun/rain protection |
| Hands | Fur - Mittens | Fur and Thread; extreme warmth with dexterity cost |
| Feet | Leather - Shoes | Leather; light/quiet everyday footwear |
| Inner feet | Wool - Socks | Wool; insulation under footwear, requires compatible liner slot |
| Neck | Wool - Scarf | Wool; small warmth layer at neck/face, compatible with reasonable equipment |

**Future, not in 17 immediate ADD:** Riding - Boots (FUTURE) belong with mounted gear and saddles; don't duplicate them in both category totals.

**Design, stations and mechanics [D8]:**
1. Clothing is mainly for temperature, wind, rain, wetness, mobility, comfort, appearance and social identity. Plant fibre cheap/fragile; hide warm but wet-stiff; leather abrasion-resistant but warm; linen cool; wool warm when somewhat damp but weighty soaked; fur extremely warm but hot; oilcloth rain-resistant but poorly breathable and needing maintenance.
2. Preserve existing `slot` fields and add targeted **compatible layers**: base torso; armour torso; overgarment; headwear/helm; hands/gloves/gauntlets; leg base/greaves; footwear/sabatons; inner socks; neck scarf. Dresses provide one-piece body and leg coverage without forcing two independent garment slots. Do not permit unlimited clothing to stack full thermal/armour bonuses. A cloak over armour and clothing under mail are intended.
3. Clothing is wearable by any player character independent of character creator's Male/Female/Other selection. Optional colours, patterns, faction heraldry, dirt, wear, tears, repairs, fit and shape are appearance/per-instance variables rather than hundreds of master item definitions.
4. Primitive Fibre/Hide by hand (Bone Needle reusable, Thread consumed where sewing needed). Linen/Wool/Fur tailoring at Tailor's Table; woven textiles from Loom. Leather pieces and work apron at Leatherworking Table. Oilcloth finishing at the Tailor's Table using a suitable existing oil/material route: verify appropriate hardening/curing material before adding another resource. No Iron Saw or smithy gate for sewn basics.
5. Fabric repairs portable needle+Thread where appropriate, or Tailor's Table; leather repairs at Leatherworking Table. Appropriate physical craftsmanship and two **permanent** magical enchantment slots apply when eligible. Never classify a mundane coloured robe as magically enchanted.
6. **Deliberately excluded:** Cotton and Silk materials until those ecosystems exist; hooded/unhooded duplicates for each cloak; identical garment colour variants as IDs; separate generic magical robe in ordinary clothing; dedicated Leather Vest (overlaps Leather Jerkin [D7]); duplicates of Leather Trousers.

**Counts for [D8]:** 24 existing ordinary clothing (keep or update as required by layering), **17 ADD ordinary clothing**, 1 FUTURE Riding - Boots to be owned by mounted equipment category, 8 armour pieces cross-listed (NO duplicate IDs). 50 clothing-related concepts by the proposal's counting method; only 17 immediate new item rows added to prior categories. Proposed numbers and stations should be audited for material accessibility and implementation consistency.

**3.8 reconciliation against the data (Claude, 12 Nov; desk review of `items.json`, `recipes.json`, `clothing.json`, `warmth.json` on dev `7f8aabf4`):**

| Check | Finding | Result / resolution |
|---|---|---|
| Ids and names | All 24 kept rows exist with the names and numbers above. With the 8 armour rows of [D7] and retired #67, they are every `clothing` row in `items.json` (33). Backpacks, quivers and the belt are `gear` and belong to the carrying category. None of the 17 ADD names clashes with a live or retired row. | PASS. All 24 stay KEEP in Appendix A. |
| Recipes and stations | Fibre and hide pieces are made by hand (Hide pieces keep the Bone - Needle). Leather pieces move from workbench L2 to the Leatherworking Table, and wool, linen and fur pieces from workbench L3 to the Tailor's Table. Both moves are already in s3.4. Straw - Hat is made by hand. Snowshoes are made at the workbench. | PASS. Matches rule 4. The station moves change recipes, not the item rows. |
| Materials for the 17 new rows | Linen 365, Wool cloth 548, Wool 364, Leather, Fur 549 and Thread (s3.4 [C]) all exist or are approved. Cloth comes from the Loom (s3.4). | PASS. |
| Oilcloth oil | No separate drying oil exists. Lamp oil 667 comes from linseed or walnuts at the Oil press (recipes 365, 366), and also from herring at the campfire pot (349). | **RECOMMEND:** Oilcloth - Cloak takes Lamp oil, with no new resource. Real oilcloth needs linseed oil and fish oil would not cure, but one oil item keeps the game simple. Splitting the oils is ChatGPT's call. |
| Tabard material | "Linen or Wool" for one row. | **RECOMMEND:** one Tabard row taking either cloth through an ingredient group (`item_table.gd load_groups`), keyed by Linen. The cheapest member is spent first. No second row. |
| Thread vs today's sewing | Today's recipes sew with Twine, Sinew or Leather strap. | NOTE. Moving existing sewing recipes to Thread is part of s3.4 [C], not a new clothing change. |
| Weather and wetness | `warmth.json` already has soak, wind chill and the body-in-weather wet strip, with one insulation value per worn item (`warmth`). It has no per-material wet behaviour, no breathability and no heat penalty. | **NEEDS CODE.** Rule 1 needs per-item fields such as wet insulation, rain shedding, breathability and overheating. Values are set in s5. |
| Slots | `clothing.json` has no neck slot and no sock liner, and it puts one item on each of its 8 slots. A Dress needs body and legs at once. | **NEEDS CODE.** Covered by the merged layer model below. |
| Hide - Trousers 306 | My [D7] question is resolved by [D8]. It is ordinary clothing in the 24 kept rows, not armour. | CLOSED. |
| Riding - Boots | Owned by the mounted-gear category. | Not counted here. |

**Merged layer model ([D7] + [D8]; engineering recommendation for the implementation PR).** This replaces the [D7] sketch in s3.7. Each item gets a `wear_layer` field beside its existing `slot` (`layer` is taken by the visual layer in `worn.json`), and each slot-and-layer pair holds one item:

| Slot | Layers, inside to outside | Examples |
|---|---|---|
| head | base · mail · rigid | Hood, caps, Headwrap · Mail coif · helms. Hats (Straw, Fur, Broad-brim) use the rigid layer, so no hat goes over a helm. |
| neck (new) | single | Wool - Scarf |
| body | base · padding · mail · rigid · over · outer (see the Mission 001 decision below) | tunics, shirts, Dress · Gambeson, Jerkin, mail, scale · Brigandine, Breastplate, Cuirass, plate · Tabard, aprons · cloaks, Coat, Robe, Oilcloth - Cloak |
| legs | base · mail · rigid | trousers, skirts · Mail chausses · greaves |
| hands | base · rigid | gloves, mittens · gauntlets |
| feet | socks · footwear · over | Wool - Socks · boots, shoes, sandals · sabatons or Snowshoes |
| back, waist | single (unchanged) | carrying gear |

Rules of the model:
- A Dress fills body base and legs base together.
- `outer` becomes the body's outer layer, so a coat and a cloak are not worn at once.
- Warmth and protection combine with diminishing returns, never full stacking.
- Old saves map each worn item to its slot's base layer, and `outer` to body outer.
- Per-instance looks (colour, pattern, heraldry, dirt, wear) need the per-instance data in s8. They are not new rows.

**Mission 001 coordinator decisions (12 Nov 2026, implemented in M001-T11, protocol 107; Dave may overrule):**
- **Padding and mail are separate body layers, padding inside mail.** Rule 1 of s3.7 puts a gambeson beneath other armour, so the table's "padding or mail" names what the layer holds, not a ban on wearing both. Body padding: Gambeson, Leather - Jerkin. Body mail: Mail shirt, Bronze - Scale shirt, Iron - Mail hauberk.
- **A misplaced piece in an old save goes to its own layer.** The old eight worn columns load into the first eight worn positions (each slot's base layer, the old outer column into body outer), as above. A piece whose own layer is another (a helm saved in the head column) moves to its own layer when that is free, instead of sitting in the base layer where a hood belongs. A piece that fits nowhere is left off with a warning (new game: no old-save migration).

*(Historical; these categories were since decided in [D9]–[D16].)* **Next category awaiting Dave's review:** Backpacks, pouches and carrying gear. Do NOT append new gear items as owner-approved until ChatGPT presents the entire category and Dave approves it. After that: saddles/saddlebags, carts/wagons/carriages, cooking, food preservation, other categories, and final whole-system re-audit.

### 3.9 Backpacks, pouches and carrying equipment [D9] — OWNER APPROVED CATEGORY

**Source:** Dave explicitly approved ChatGPT's full Backpacks, Pouches & Carrying Equipment Proposal 1 (“lets do it”) following approval of weapons, armour and clothing. CATEGORY APPROVAL only. No code, inventory data or merge authorized. Human personal equipment is designed here; pack-animal equipment, saddles and vehicles remain upcoming categories.

**Six existing gear rows, stable IDs (KEEP, with explicit necessary metadata/behavior UPDATE):**

| Item # | ID | Item | Role / needed reconciliation |
|---|---|---|---|
| 50 | `backpack` | Hide - Backpack | Basic early backpack; increases organized volume but total burden still counts **Note (13 Nov 2026, Dave): "Backpacks do not have slots. The only thing they do is give you more carry weight." Rows 50 and 767 have no `bag_slots`/`bag_takes` and hold nothing; `carry_bonus_kg` 12 and 18 is all they do. This supersedes the backpack-as-container reading of rules 1-3 and the volume wording of this row for those two rows only; every other bag in s3.9 keeps its slots. See docs/ai-team/missions/BUGLIST-001/backpack.md (Follow-up 13 Nov 2026).** |
| 767 | `leather_backpack` | Leather - Backpack | Larger, tougher and modestly more weather resistant **Note (13 Nov 2026, Dave): "Backpacks do not have slots. The only thing they do is give you more carry weight." Rows 50 and 767 have no `bag_slots`/`bag_takes` and hold nothing; `carry_bonus_kg` 12 and 18 is all they do. This supersedes the backpack-as-container reading of rules 1-3 and the volume wording of this row for those two rows only; every other bag in s3.9 keeps its slots. See docs/ai-team/missions/BUGLIST-001/backpack.md (Follow-up 13 Nov 2026).** |
| 272 | `quiver` | Hide - Quiver | 40 compatible arrows, carried visibly at hip or waist to coexist with backpack |
| 762 | `leather_quiver` | Leather - Quiver | 60 compatible arrows, better rain protection |
| 828 | `leather_belt` | Leather - Belt | Base for attachment points: pouch, quiver, scabbard or other sensible equipment |
| 819 | `bedroll` | Bedroll | Portable sleep aid, attachable to pack exterior (not another backpack slot) |

Existing quivers have `slot: waist` although descriptions say worn on back. Choose consistent waist/hip appearance and an attachment-based belt interface without losing compatibility with existing equipping.

**Nine distinct new carrying-gear items (ADD; new IDs/numbers only upon implementation approval):**

| New item | Production | Function / distinction |
|---|---|---|
| Fibre - Shoulder bag | Hand: plant fibre + twine | Very early small pack before animal hides |
| Wicker - Pack basket | Hand: sticks + twine | Cheap bulky/light cargo, awkward and poor wet-weather protection |
| Leather - Satchel | Leatherworking Table | Small shoulder carry for documents, valuables, food and other light personal items |
| Belt pouch | Hand from hide; appropriate leather craft option | Small quickly accessible waist inventory; coins/herbs/potions, not large tools/logs |
| Tool roll | Tailor's or Leatherworking Table | Organized limited small-tool and repair inventory; not a full backpack |
| Traveller's Rucksack | Tailor's Table, with cloth and leather straps | Largest general travel pack; increases volume but movement cost when loaded |
| Wooden - Pack frame | Carpenter's Bench, wood and straps | Carries awkward logs, ore sacks and construction loads; restrictive in climbing/sprinting/fighting |
| Weapon scabbard | Leatherworking Table | Compatible sheathing and draw of suitable swords on hip/back; not one new item per blade |
| Utility bandolier | Leatherworking Table | Limited quick-access slots for small consumables; no extra physical carrying-strength bonus |

**Three existing cross-listed containers/structures; NO new IDs:** Waterskin #42 for drink; placed Hide - Sack #783 and Basket #785 for early camp storage. Bucket, cookware and jars remain their relevant functional categories and are not automatically wearable bags.

**Rules and validation:**
1. Use a **sensible attachment/loadout scheme** rather than forcing belt and quiver into mutually exclusive slots: one principal back container, one shoulder bag if compatible, one belt with finite attachment points, optional small utility bandolier and strapped exterior bedroll. No multiple stacked giant backpacks or unlimited pouches.
2. **Volume, mass and object dimensions all matter.** A bigger pack organizes more, but never increases human muscle power; loaded weight affects stamina, exertion, balance, jump/climb/sprint/swim/combat. A bulky pack frame has an intentional movement penalty.
3. Contents stay with the physical container when carried, detached, dropped, traded or stored; disallow recursive bag nesting, item duplication and content loss. A full bag cannot vanish when unequipped; replicate per-instance inventories through save/network data with safe world drops. Existing 30-slot pack rules must be reconciled rather than contradicted.
4. Quivers accept appropriate arrows only and draw ammunition while equipped; hide 40 and leather 60 keep their existing capacity values. Rain/condition affect material differences but do not arbitrarily destroy ammo.
5. Scabbards attach only compatible weapons; quick-use equipment uses limited dedicated slots, not free storage. Item types and actual access are validated in interface code.
6. Condition and repair: fibre/wicker primitive; hide/leather repair at hand or Leatherworking Table as suitable; fabric at Tailor's Table. Water can soak and impair contents depending on material, closures and maintenance. Cosmetic variations stay per-instance looks.
7. **No new coin purse, herb pouch, magic bottomless bag, separate dagger sheath by material or duplicate small/large pouch sizes.** Saddle panniers, horse saddles and vehicles wait for their own category. No arbitrary capacity/durability/stamina tuning numbers locked in this design.

**Approved category counts:** 6 existing personal gear rows, **9 ADD** carrying items, 3 cross-listed existing containers/structures. The 18 related concept total is **not** 18 new items; only 9 new items are required. Deduplicate cross-category tool roll/scabbard interactions and preserve existing row IDs.

**3.9 reconciliation against the data (Claude, 12 Nov; desk review of `items.json`, `recipes.json`, `weights.json`, `worn.json` and the inventory and carry code on dev `7f8aabf4`):**

| Check | Finding | Result / resolution |
|---|---|---|
| Ids and names | All 6 kept rows and the 3 cross-listed rows exist with the numbers above. Waterskin 42 is a `container` holding 1500 ml. Hide - Sack 783 and Basket 785 are placed `structure` rows; their kits 782 and 784 are already retired. None of the 9 ADD names clashes with a live or retired row. | PASS. |
| Name style | "Traveller's Rucksack" capitalises its second word. The house style is sentence case, as in "Bone - Needle" and "Fishing rod". | DELEGATED: implementation applies the decision 71 house style, "Traveller's rucksack". Nothing is renamed here. |
| Recipes and stations | Hide - Backpack (recipe 30), Hide - Quiver (173) and Bedroll (388) are made by hand with the Bone - Needle. Leather - Quiver (356), Leather - Backpack (361) and Leather - Belt (392) move from the workbench to the Leatherworking Table, as s3.4 already lists. The Carpenter's bench 86 for the Pack frame exists and stays (PR #1036 retires only the Woodworking table). | PASS. |
| Materials for the 9 new rows | Plant fibre, Twine, Sticks, Hide, Leather, Leather strap, the cloths, Thread and Planks all exist or are approved. | PASS. |
| **Backpack carry bonus** | Hide - Backpack has `carry_bonus_kg` 12 and Leather - Backpack has 18. The server and client add this to the carry limit (`server_items.gd carry_bonus_kg`, `inventory_view.gd carry_body_kg`). Rule 2 says a pack never adds muscle power. | **CONFLICT.** Recommendation below. Rows 50 and 767 become UPDATE. **Note (13 Nov 2026, coordinator ruling for Dave's confirmation): BUGLIST-001 DESIGN-001 (backpacks improve carry weight, not inventory slots) supersedes this for rows 50 and 767: `carry_bonus_kg` 12 and 18 restored, starting values for Dave to tune; the `bag_slots` containers stay pending his ruling. See docs/ai-team/missions/BUGLIST-001/backpack.md.** **Note (13 Nov 2026, Dave): "Backpacks do not have slots. The only thing they do is give you more carry weight." Rows 50 and 767 have no `bag_slots`/`bag_takes` and hold nothing; `carry_bonus_kg` 12 and 18 is all they do. This supersedes the backpack-as-container reading of rules 1-3 and the volume wording of this row for those two rows only; every other bag in s3.9 keeps its slots. See docs/ai-team/missions/BUGLIST-001/backpack.md (Follow-up 13 Nov 2026).** |
| **Pack volume** | The inventory is one fixed 30-slot pack (`inventory.gd SLOTS`). No item has a volume, and a worn bag holds no contents of its own. | **NEEDS CODE.** Rule 3 needs per-instance container inventories that are saved, sent over the network and dropped with the bag. This is the largest new system in the category. |
| **Quiver slot** | Both quivers have `slot: waist`, the same slot as the Leather - Belt, so today a belt and a quiver cannot be worn together. Their descriptions say "worn on the back". | **CONFLICT** with rule 1. Rows 272 and 762 become UPDATE (slot model and description). Capacities of 40 and 60 arrows are unchanged. |
| Bedroll | It has no `slot` today. | KEEP. Strapping it to a pack is part of the attachment model, not a row change. |
| Visuals | `worn.json` already has a visual `layer` field (0 base, 1 clothing, 2 outer, 3 pack). `tools/validate_items.gd` requires a `worn.json` row for every item with a slot. | Every new wearable needs a `worn.json` row. The gameplay layer field from s3.8 is renamed `wear_layer` so it does not clash. |

**Recommended carry model (engineering, for the implementation PR; ChatGPT may override):**
- **Carry limit.** Body weight alone sets the limit, through `carry_kg_per_body_kg`, and `carry_bonus_kg` is retired. A pack's benefit becomes volume. The base inventory shrinks to what hands, belt and pockets hold, and a worn bag adds its own slots. Load still counts fully toward weight. This needs care: removing the bonus without the volume system would leave backpacks useless. The two must ship together, or the bonus stays until volume exists. **Note (13 Nov 2026, coordinator ruling for Dave's confirmation): BUGLIST-001 DESIGN-001 (backpacks improve carry weight, not inventory slots) supersedes this for rows 50 and 767: `carry_bonus_kg` 12 and 18 restored, starting values for Dave to tune; the `bag_slots` containers stay pending his ruling. See docs/ai-team/missions/BUGLIST-001/backpack.md.** **Note (13 Nov 2026, Dave): "Backpacks do not have slots. The only thing they do is give you more carry weight." Rows 50 and 767 have no `bag_slots`/`bag_takes` and hold nothing; `carry_bonus_kg` 12 and 18 is all they do. This supersedes the backpack-as-container reading of rules 1-3 and the volume wording of this row for those two rows only; every other bag in s3.9 keeps its slots. See docs/ai-team/missions/BUGLIST-001/backpack.md (Follow-up 13 Nov 2026).**
- **Loadout.**
  - `back`: one main container (Backpack, Rucksack, Pack basket or Pack frame). **Note (13 Nov 2026, Dave): "Backpacks do not have slots. The only thing they do is give you more carry weight." Rows 50 and 767 have no `bag_slots`/`bag_takes` and hold nothing; `carry_bonus_kg` 12 and 18 is all they do. This supersedes the backpack-as-container reading of rules 1-3 and the volume wording of this row for those two rows only; every other bag in s3.9 keeps its slots. See docs/ai-team/missions/BUGLIST-001/backpack.md (Follow-up 13 Nov 2026).**
  - A new `shoulder` slot: Shoulder bag or Satchel.
  - `waist`: the belt, with a fixed number of attachment points (3 recommended). A pouch, quiver, scabbard or tool roll each takes one point.
  - A new chest-strap slot: the bandolier.
  - The exterior of the back container holds a Bedroll.
- **Quivers without a belt.** An early archer can make a Hide - Quiver before the Leather - Belt, which needs the Leatherworking Table. A quiver worn without a belt therefore takes the belt position and has no attachment points.
- **Nesting.** A container (an object with its own inventory: bag, sack, crate, barrel) never goes inside another container. Empty jars and waterskins are ordinary items. Moving a full bag moves its contents with it. Vehicles, ship holds and freight do not break this rule: they carry whole container objects (crates, sacks, barrels) in cargo positions, never inside item slots, and the full mass of each container and its contents counts. Lifting a loaded crate moves it as one carried or cargo object, not into item slots.

*(Historical; tack was since approved as [D10].)* **Next:** ChatGPT is designing saddles, tack, saddlebags and pack animal equipment for Dave to review in one complete proposal. No horse equipment is owner-approved yet.

### 3.10 Saddles, saddlebags and draft animal tack [D10] — OWNER APPROVED CATEGORY

**Owner approval:** Dave accepted ChatGPT's complete 18-item Horse Equipment, Saddles & Saddlebags Proposal 1, then asked for Double Heavy Draft Harness and Double Ox Yoke (20 ADD concepts total) and explicitly specified **one combined movement controller for a yoked pair**, subsequently confirming "I like it." This is approval of the horse-equipment category and paired draft movement abstraction, not the remaining vehicles category or the complete master catalog. These animal items are NEW; no existing horse-specific tack item IDs exist on baseline `dev`. Numbers assigned at authorized implementation only.

**Approved 20 ADD equipment rows:**

| Family | Item | Use, distinctive function and crafting |
|---|---|---|
| Handling | Rope Halter | Lead/tie/handle an animal on foot; handcraft Rope; no metal gate |
| Handling | Leather Bridle | Mounted control, includes reins and bit; Leatherworking Table |
| Riding | Riding Saddle | Ordinary rider support; leather + wooden saddle tree and padding |
| Riding | Traveller's Saddle | Long-journey comfort, useful attachments; leather and cloth padding |
| Riding | War Saddle | More secure rider positioning during combat, greater weight; reinforced craft |
| Cargo | Pack Saddle | Back frame for animal loads, **not** the same as riding saddle; wooden frame + straps |
| Cargo | Leather Saddlebags | One matched pair of bags attached to compatible riding saddles |
| Cargo | Wicker Panniers | Balanced side baskets for pack saddles, larger volume/poor rain defence |
| Cargo | Cargo Lashings | Secure logs, cargo bundles and awkward equipment to pack saddles |
| Draft | Light Draft Harness | Single animal, lighter cart/work implements; leather breastcollar/traces |
| Draft | Heavy Horse Collar Harness | One animal, heavier steady pulling on suitable vehicles; padded collar/traces |
| Draft | **Double Heavy Draft Harness** | One complete two-animal hitch for suitably matched horses/donkeys; shared control and load transfer |
| Draft | **Double Ox Yoke** | One wooden yoke for two oxen, paired hauling of heavy wagons or farming implements |
| Care | Iron Horseshoes (Set) | Hoof protection under terrain/workload conditions; Smithy, not forced in every biome |
| Care | Padded Horse Blanket | Rest/cold-weather cover; Tailor's Table |
| Care | Feedbag | Portable hay/grain feeding (food items/sourcing verified later), not general inventory |
| Care | Grooming Kit | Brush/hoof care, improve husbandry interactions; hand/Carpenter's Bench |
| Barding | Padded Barding | Lightweight animal protection, warmth/heat trade-off; Tailor's Table |
| Barding | Iron Mail Barding | Flexible metal animal protection with heavier burden; Smithy |
| Barding | Steel Plate Barding | Advanced animal protection with high heat, weight and fatigue cost; Smithy |

**Related approved cross-references (NOT part of 20 ADD):** Riding - Boots is the previously approved **FUTURE** clothing/mounted accessory (count once here); Iron - Lance is the Weapons [D6] FUTURE weapon (counted there); animal feed and water troughs already in current data; player personal quivers, satchels and packs from [D9] are NOT horse cargo items. Do not invent saddlebags left/right variants or multiple cosmetic-grade IDs.

**Rules:** Saddle for riding OR pack use; compatible bridle/halter, harness and animal type; add-on storage requires compatible fitted saddle. Animal body mass, health, individual stamina, terrain, training, hydration, load mass/volume/balance govern practical hauling. Saddlebags improve storage organization, **not muscle strength**. Visible equipped gear, condition/wetness, repair and safe per-animal inventory persistence are required; animal loss/unloading must not silently destroy or duplicate bags and contents. A full Pack Saddle competes with normal riding; cannot wear conflicting double saddles, draft rig and impossible additional loads. Horseshoes and protective barding should not be mandatory for every horse. Iron/Steel armour construction retains ordinary Smithy/Blast Furnace/Quenching rules (only eligible steel can be optionally Tempered, no extra master IDs). Barding protected by Armour rules [D7] but remains animal tack, not duplicate human armour rows.

**Owner-approved simplified paired draft physics (mandatory [D10]):**
- Hitch **two suitable draft animals as one logical draft unit** for movement, with **one controller** for heading, acceleration, speed, steering, stopping, reversing and turning. Both animal visuals maintain fixed left/right side-by-side formation aligned in the same direction; vehicle connects to the single team controller.
- Combine available pulling strengths, subject to vehicle, surface, slope, fitness and matched gait; do not falsely treat the paired unit as two independently pulling rigid bodies, and do not simulate reins/trace tensions, joint strain or separate animal steering.
- Maintain each animal's identity, ownership, health and stamina; if one becomes unable to pull, the team must stop or transition safely to detachment; removing yoke/harness restores independent creatures.
- Future 4-animal teams can compose paired logical units, but no new 4-horse harness item or multi-body physics system is approved now.

**Material/recipe gates:** primitive halter without Smithy; Leatherworking Table for leather tack; Carpenter's Bench/wood for pack-saddle frame; Tailor's Table for cloth and padding; Smithy for iron horseshoes and metal barding. Bridle/saddle components can be integrated into each item (reins, bit, girth, stirrups, saddle tree, traces) without separate tiny item definitions. Require available sources for fodder, oil/conditioning, and fitted tack, and avoid wooden board/plank substitution contrary to s2.3.

**Deliberately excluded:** individual stirrups/bits/reins, multiple saddlebag size/colour material rows, generic Bronze/Steel horseshoes, exotic flying-mount saddles, magical tack, separate armoured animal limbs. Carts, wagons and carriages were later approved separately as [D11] (s3.11); their 1-/2-animal hitch requirements must be compatible with this approved system.

**3.10 reconciliation against the data (Claude, 12 Nov; desk review of `items.json`, `animals/animals.json` and the animal code on dev `7f8aabf4`):**

| Check | Finding | Result / resolution |
|---|---|---|
| Existing tack | No halter, bridle, saddle, harness, yoke, horseshoe, barding, feedbag or grooming row exists, live or retired. | PASS. 0 existing rows, 20 ADD. |
| Name clashes and style | No clash. Several names break the "Material - Object" and sentence-case style (decision 71). For example: Rope Halter, Leather Bridle, Leather Saddlebags, Wicker Panniers, Iron Horseshoes (Set), Iron Mail Barding and Steel Plate Barding. | DELEGATED: implementation applies decision 71. Forms: Rope - Halter, Leather - Bridle, Riding saddle, Traveller's saddle, War saddle, Pack saddle, Leather - Saddlebags, Wicker - Panniers, Cargo lashings, Light draft harness, Heavy collar harness, Double draft harness, Double ox yoke, Iron - Horseshoes (one item is a set of four), Padded - Horse blanket, Feedbag, Grooming kit, Padded - Barding, Iron - Mail barding, Steel - Plate barding. Nothing is renamed here. |
| Materials and stations | All of these exist or are approved: Rope 44, Leather, Leather strap 415, Sinew, Thread, the cloths, Iron and Steel ingots, Rivets, Planks and Hardwood Boards. So do the Leatherworking Table, Tailor's Table, Carpenter's bench 86, Smithy and Blast Furnace. | PASS. **RECOMMEND:** saddle trees and the Double ox yoke use Hardwood Boards, and the Pack saddle frame uses Planks, with no substitution (s2.3, [D4]). |
| Fodder | Troughs 719, 721 and 732 are live and Fodder trough 841 is FUTURE. No hay item exists. Grain exists, and straw is a gathered material. | NOTE. The Feedbag holds existing grain or straw. Hay waits for the cooking and food categories. |
| **Animals to equip** | Horses and donkeys exist as wild herd animals. Their `tame` block only changes spook distance. No code catches, owns, leads, rides or hitches an animal. The only ox is the Wild ox (`buffalo`), which has no `tame` block. | **DEPENDENCY.** Every [D10] row needs an animal-keeping system: capture or purchase, ownership, leading, riding and per-animal saving. The Double Ox Yoke also needs a tameable or domestic ox. **[D17]:** all tack and vehicles stay approved; animal keeping, riding and hitching are a separate later implementation phase (`CATALOG_IMPLEMENTATION_PLAN.md`, phase 11). |
| Animal equipment slots | None exist. | **RECOMMEND** below. |
| Cargo storage | Saddlebags, Panniers and Lashings carry goods. | Uses the same per-container inventory as [D9] rule 3 (s3.9), stored per animal. This is one system, not two. |
| Paired draft controller | No mount or draft controller exists. Animals run on the server herd AI. | **RECOMMEND:** one *draft unit* controller with 1 or 2 members. The single harnesses form a unit of one, so single and paired hitching share code, and a vehicle always attaches to a unit. This follows the [D10] rule. |
| Barding and Tempered | Steel - Plate barding is steel armour. | It is eligible for optional Tempered durability (s4 item 15). Iron - Mail barding is not. |
| Riding - Boots | Now owned here as a FUTURE row. | Counted once, in the new FUTURE rows below. |

**Recommended animal equipment slots (engineering; ChatGPT may override):**
- `head`: halter or bridle. The Feedbag replaces it while the animal eats.
- `back`: one of a riding saddle, pack saddle, blanket or barding. The blanket is a rest cover, so it is not worn under a saddle.
- `back add-on`: Saddlebags (riding saddles only), or Panniers and Lashings (Pack saddle only).
- `draft`: one harness, collar or yoke. It cannot be worn with any saddle.
- `hooves`: horseshoes, on horses and donkeys only.

**Counts:** 0 existing dedicated tack; **20 ADD** horse-care/riding/pack/harness/barding item rows. Cross-listed **1 FUTURE** Riding - Boots is owned here and must not be counted a second time against [D8]; existing FUTURE Lance is owned by [D6]. All 20 new rows are documentation plans; this section authorizes no JSON edits, code, merge or runtime implementation.

### 3.11 Carts, wagons and carriages [D11] — OWNER APPROVED (WHEELBARROW REMOVED)

**Authority:** Dave approved ChatGPT's complete Carts, Wagons & Carriages Proposal 1 with a specific change: **DROP the Wheelbarrow** because the Handcart serves its purpose. Dave then explicitly said "I like it all. make it so." This is owner approval for the **13-entry vehicle/components category**, not final approval of the complete Master Items Catalog or authorization to implement, merge, alter gameplay, create blueprints or deploy runtime code. No dedicated vehicle catalog items exist on current baseline `dev`.

**New vehicle types — ten distinct buildable world entities (ADD, new IDs/numbers assigned at authorized implementation only):**

| Class | New vehicle | Traction and hitch | Distinct purpose and limits |
|---|---|---|---|
| Human | Handcart | Person pushes or pulls, no harness | Earliest local settlement hauler; two wheels, more cargo than a backpack, awkward on narrow/steep/rough paths |
| One-animal | Light Cargo Cart | One compatible draft animal using Light Draft Harness, or suitable single heavy harness | Two-wheel farm/trade supplies, moderate cargo |
| One-animal | Passenger Gig | One suitable horse/donkey + compatible single harness | Lightweight two-wheel driver + one passenger, minimal freight |
| One-animal | Cargo Sled | One compatible draft animal; hand-pulled if lightly loaded | Wheel-free sled intended for snowy ground, poor on bare roads/stones |
| Two-animal | Farm Wagon | Double Heavy Draft Harness for matched horses/donkeys OR Double Ox Yoke for two oxen | Four-wheel sideboard wagon, crops/grain/hay/general hauling |
| Two-animal | Timber Flatbed Wagon | Compatible double animal draft unit | Long, open structural platform for logs, Hardwood Boards, Planks, stone and bulky construction loads |
| Two-animal | Covered Merchant Wagon | Compatible double animal draft unit | Weather-protected enclosed trading cargo; heavier than open wagon |
| Two-animal | Traveller's Wagon | Compatible double animal draft unit | Slower mobile sleeping/storage accommodation while parked, NOT automatic cooking/crafting workshop |
| Two-animal | Passenger Carriage | Compatible double animal draft unit | Enclosed upholstered passenger vehicle, relatively little cargo space |
| Two-animal | Passenger Sleigh | Compatible double animal draft unit | Snow-condition passenger transport on runners, not an all-season road wagon |

**New reusable vehicle components — three ADD inventory material/component definitions:**

| New component | Role |
|---|---|
| Wooden Cart Wheel | Replaceable basic wheel for Handcart, Light Cargo Cart, Passenger Gig and other compatible light builds |
| Reinforced Wagon Wheel | Heavier wheel for wagons and carriage builds |
| Axle Assembly | Replaceable common axle component for wheeled vehicles; validate size compatibility in construction/repair, no spokes or individual nails as separate item definitions |

The existing `water_wheel` item is a different mechanical system and MUST NOT become a substitute for a cart or wagon wheel.

**Total: 10 vehicle entity types + 3 reusable components = 13 proposed new catalog concepts.** No Wheelbarrow blueprint, item, structure or vehicle variant; do not count it as future or retained.

**Vehicles as world assets and construction:**
1. Vehicles are **persistent movable world entities**, not human pocket inventory items. Hammer construction blueprints create assembled vehicles; wheel and axle parts are ordinary craftable inventory items; record item/blueprint/structure/vehicle entity relationships explicitly before implementation and avoid auto-generating one carryable vehicle kit per vehicle unless a later approved design truly requires it.
2. Primitive Handcart is available before horses/donkeys/oxen and before a complex transportation tech tree. Early wooden cart material sourcing must respect real existing tools and gates. More complex cars/wagons can use **Hardwood Boards**, ordinary Planks, logs/blocks, Wooden Pins, Bronze/Iron Nails, Iron Bands, Leather and cloth with functional fitting logic. **No substitution** between Planks and Hardwood Boards, in either direction. Honour bronze-before-iron access and the Iron Hand Saw prerequisite for sawn boards.
3. Wheels and axles built at Carpenter's Bench with iron/bronze fittings as appropriate. Whole vehicle assembly is by Hammer blueprint, not a new universal Vehicle Workshop by default. Carriages can use upholstery and existing furniture/textile fabrication methods, no invented premium fastener tier.

**Owner-approved simple vehicle/draft physics, shared with [D10]:**
- **One controller per vehicle** handles locomotion/heading, steering, collisions, stop/start/reverse and plausible turning radius; animate wheels visually, no full separate physics simulation for each wheel or suspension spring.
- For two-animal vehicles, two compatible fitted animals join as the **one logical paired draft unit** specified in [D10]: same heading, speed, movement and facing with side-by-side spacing, combined effective pulling strength, individual health/stamina. Connect vehicle to the shared logical controller, not two competing physics bodies. Unhitching restores independent animals. A disabled animal causes safe halt or detach handling.
- Haulability uses real animal/human strength, loaded mass, volume/size, road/soil conditions, grades, water obstacles, stamina and physical terrain. The pair need not yield exactly double practical traction. The vehicle does not ignore weight by having more storage slots.
- Vehicle collision and route constraints matter: narrow paths, bridge width, rocks, deep mud, rivers, slope, snow, passengers and cargo all contribute. Passenger Sleigh/Cargo Sled require suitable surface; do not make every vehicle universally effective on all terrain.

**Cargo, passengers, repairs and persistence:**
- Container/inventory data belongs to each physical vehicle and persists with its location, ownership and attached animals across save/network, moving, parking, leaving world or dismantling. Prevent duplication, deletion and bag-within-bag exploits. Load mass/volume/geometry and load balance constrain cargo. Sacks inside a cargo wagon must count fully. Visible cargo where practical.
- Passengers occupy actual seats, count toward load and can board/exit when stationary. NPC and multiplayer passengers need later network controls; do not invent autonomous NPC coach-driving here.
- Damage may affect wheel, axle, frame or cloth cover; repair with appropriate materials/tool at the vehicle instead of arbitrary whole-vehicle replacement. Parked/abandoned vehicles remain world objects, not despawned because the owner walked away.
- Vehicle saddle/hitch compatibility needs the [D10] **single** draft options for one-animal vehicles and **Double Heavy Harness/Double Ox Yoke** for two-animal vehicles. Draft harnesses and barding are not new vehicle items; cross-listed only.

**Deliberately excluded:** Wheelbarrow (specifically rejected by Dave), Noble Coach (appearance variant of Passenger Carriage), separate Ox Cart (use existing cart/wagon with appropriate animal), Hay Wagon (Farm Wagon), Heavy Cargo Cart (covered by Light Cargo Cart and Farm Wagon), Armoured War Wagon (future warfare), Ploughs and Harvesters (agriculture), Siege Engines (warfare), and Boats/Ships (water transport). Appearance/paint/upholstery variants do not multiply catalog rows.

**3.11 reconciliation against the data (Claude, 12 Nov; desk review of `items.json`, `blueprints.json`, `structures.json`, `recipes.json` and the code on dev `7f8aabf4`):**

| Check | Finding | Result / resolution |
|---|---|---|
| Existing rows | No cart, wagon, carriage, sled, sleigh, axle, cart wheel or wheelbarrow row exists, live or retired, in the items, blueprints or structures. Water wheel 239 (KEEP; the Sawmill part) and Spinning wheel 845 (FUTURE) are unrelated wheels. | PASS. 0 existing rows, 13 ADD, no Wheelbarrow anywhere. |
| Row shape (no duplicate kits) | Placed things today use one item row of kind `structure` ("Placed piece: row state N"), one blueprint and one structure state. Their `*_kit` items are retired (for example 782 and 784). A structure row can already hold contents (`slots`, `max_kg`, `who`), as the Basket 785 does. | **RECOMMEND:** each vehicle has one item row, one Hammer blueprint and one structure state, and **no kit item**. Wheels and the axle are ordinary `material` items. The 13 ADD rows are item rows. The 10 blueprints and 10 states are not counted as items. Vehicle cargo reuses the structure `slots` and `max_kg` shape, and the per-container rules of [D9]. |
| **Movable world objects** | Every structure is static: grid-placed, with `footprint`, `cap_per_chunk` and `blocks_walk`. No moving, pushed or pulled world object exists in the code. | **NEEDS CODE.** A persistent movable entity, saved and sent over the network, with one controller (rule shared with [D10]). It is the largest new system so far. The animal vehicles also depend on the animal-keeping system noted in s3.10. |
| Sawing progression | The Carpenter's bench 86 costs Planks (`lumber`) and Wooden pins. Wooden pins come from 1 Plank (recipe 150). Planks come only from a saw: the Iron - Saw at the Smithy, or the Sawmill. | PASS / NOTE. Wheels, axles and every vehicle land **after the first saw**. The Handcart is still the first vehicle, before any animal, but it is not pre-metal. Nothing conflicts with s2.3 or [D4]. |
| Materials | All of these exist or are approved: Planks, Hardwood Boards, logs and blocks, Wooden pins, `nails`, `hinges`, Iron band 859, Leather, the cloths, Rope and Oilcloth (s3.8). | PASS. **RECOMMEND:** the Reinforced wagon wheel takes Hardwood Boards and Iron bands (an iron tyre). The Wooden cart wheel and the Axle assembly take Planks and an Iron band, so the Handcart can be built in the hardwood-free biomes (s6 row 30). The Covered merchant wagon cover is Linen or Oilcloth. Carriage seats follow the Fine furniture grade (s3.5). |
| Hitching | The single and double harnesses and the yoke are in s3.10. | PASS. The s3.10 draft-unit controller (1 or 2 animals) fits here. **RECOMMEND:** the Handcart uses the same vehicle controller, with the player as its puller. |
| Traveller's wagon sleeping | `comfort.json` counts only the best bed (`one_bed_counts`). | NOTE. The wagon's bed takes part in that rule. It is not an extra bed. |
| Name style | The names use title case ("Light Cargo Cart", "Wooden Cart Wheel"). | DELEGATED: implementation applies decision 71, in sentence case: Handcart, Light cargo cart, Passenger gig, Cargo sled, Farm wagon, Timber wagon, Covered wagon, Traveller's wagon, Passenger carriage, Passenger sleigh, Wooden - Cart wheel, Reinforced wagon wheel, Axle. Shorter forms keep within the four-word check. Nothing is renamed here. |

**Counts and dependencies:** 1 hand-powered + 3 single-animal + 6 paired-animal vehicles + 3 parts = **13 ADD**; 0 existing vehicle items. Cumulative new ADD total increases by 13 from the last audited baseline after reconciliation; no extra horse-tack, plated animal armour, animal food or duplicated individual wheel subparts. *(Historical: cooking [D12] and the preservation workflow [D14] have since been decided.)* Re-audit every completed category before calling the master catalog final.

### 3.12 Cooking and food preparation [D12] — OWNER APPROVED CATEGORY

**Owner authority:** Dave accepted ChatGPT's complete Cooking & Food Preparation Proposal 2 (“sounds good”), after directing the Food Preparation Table and a two-stage cooking workflow. This is **category design approval ONLY**. The full Master Items Catalog is not approved, and no recipes, gameplay files, merge or Godot implementation is authorized. New item IDs and structure states are assigned only at later authorized implementation. Keep existing finished-food item IDs stable.

**Existing cook stations retained (NOT ADD):** Campfire (existing placeable kit #8); Campfire Pot (existing structure #255); Clay Hearth (existing structure #257, already has roasting spit); Oven (existing structure #267). Existing Fireplace #514 stays primarily light/warmth, becomes cook-capable only with the approved Cooking Crane. Existing utensil items retained: Clay Pot #40, Copper Pot #835 (future), Wooden Bowl #39, Hand Mill #344, Mortar & Pestle #807, and existing knives as cross-listed **non-kitchen** tools. Exact cross-category totals must not count these twice.

**Seven new cooking equipment definitions (ADD):**

| Approved new item | Design role and station relationships |
|---|---|
| **Food Preparation Table** | **Required station** to assemble/mix/knead/shape food into actual uncooked/prepared item outputs; visually wooden table with built-in cutting board, kitchen knives and rolling pin; recipe UI and station-local sourcing; these kitchen implements are NOT individual tool or ingredient items |
| Clay Griddle | Suitable cooking surface for hearth/fire flatbreads, cakes and light frying |
| Campfire Roasting Spit | Basic Campfire attachment for larger meat roasting; distinct from the existing built-in Clay Hearth spit |
| Iron Grill Grate | Campfire/hearth grill attachment for multiple fish/meat/vegetables |
| Iron Frying Pan | Reusable cooking vessel for eggs, fritters, fish and similar fried meals |
| Iron Cauldron | Reusable large-batch vessel for stews and communal meals |
| Fireplace Cooking Crane | Smithy-made **add-on** to existing Fireplace #514, enabling suitable hanging-pot cooking, not a new standalone fireplace or station |

The griddle, spit, grate, pan and cauldron should be **equipment or compatible attachments**, not five gratuitous standalone cooking stations; only the Food Preparation Table is a new independently placeable food-preparation station. Attachment/vessel compatibility with Campfire, Campfire Pot, Clay Hearth and Oven must be explicitly modeled. Preserve original structure IDs/states and workstation-level inheritance. The Cooking Crane attaches to Fireplace #514.

**Sixteen new tangible prepared/uncooked food items (ADD):**

| New item | Final cooking destination; existing cooked output ID stays unchanged |
|---|---|
| Unbaked Flatbread | Clay Hearth or Clay Griddle → Flatbread #273 |
| Unbaked Rye Flatbread | Clay Hearth or Clay Griddle → Rye Flatbread #388 |
| Unbaked Garlic Flatbread | Clay Hearth or Clay Griddle → Garlic Bread #404 |
| Unbaked Honey Loaf | Oven → Honey Loaf #274 |
| Unbaked Trail Bread | Clay Hearth or Oven → Trail Bread #189 |
| Unbaked Oatcakes | Clay Griddle or Clay Hearth → Oat Cakes #405 |
| Unbaked Chestnut Cakes | Clay Griddle or Clay Hearth → Chestnut Cakes #183 |
| Unbaked Apple Pie | Oven → Apple Pie #452 |
| Unbaked Fish Pie | Oven → Fish Pie #402 |
| Unbaked Venison Pie | Oven → Venison Pie #401 |
| Uncooked Meatballs | Campfire Pot or Iron Frying Pan → Meatballs #837 (future) |
| Uncooked Sausages | Campfire Pot or Iron Grill Grate → Sausage #804 |
| Uncooked Meat Skewers | Campfire or Iron Grill Grate → Meat Skewer #803 |
| Uncooked Mushroom Skewers | Campfire or Iron Grill Grate → Mushroom Skewer #180 |
| Uncooked Crab Cakes | Clay Griddle or Iron Frying Pan → Crab Cakes #397 |
| Banana Fritter Batter | Clay Griddle or Iron Frying Pan → Banana Fritter #411 |

**MANDATORY owner rule (overrides previous recipes):**
1. **Prepare → Cook** only when food needs assembly, dough forming/kneading, shaping, stuffing or comparable processing. Food Preparation Table outputs inventory items, with identity/condition/spoilage, that can be stored/transported; proper cooking station consumes the **prepared output**, not all original ingredients a second time. Existing finished recipe IDs and final food IDs are preserved, recipes revised only at implementation.
2. **NO personal carried knives or separate chopping board/rolling-pin items for cooking**, and **NO inventory-only hand food preparation**. The Table visibly incorporates knives, cutting board and rolling pin and supplies their functionality. User explicitly says knives are used to skin animals, not to prepare food; keep existing tools' other approved non-cooking roles.
3. Simple food that needs no advance assembly can be cooked **directly at an appropriate food station**, such as fish over a campfire, water boiling in a pot, or simple soups in a pot. Avoid forced prep for each basic food and avoid meaningless duplicate intermediate items. Existing cook recipes are audited to route assembled foods via the Table and to correct unsuitable cooking destinations, e.g. Omelette currently at Campfire Pot → proper pan when supported.
4. Station prerequisites: real heat/fuel, attachable cookware, appropriate batch volumes, safe input sourcing from approved station storage. Prepared food may spoil, burn, undercook or overcook as applicable to the approved future systems. Include realistic cooking safety without simulating knife cuts or detailed food-chopping animations.
5. Cooking progression: basic Campfire + Campfire Pot, Clay Hearth, Oven; upgraded Fireplace + Cooking Crane; equipment allows grilling/frying/communal batches. No arbitrary mandatory iron gate for basic cooked survival meals. Table recipe UI, ingredient groups and local storage obey general workstation rules in s2.5.

**Exclusions:** No duplicate Cooking Kettle (pots suffice), Cooking Tripod (Campfire Pot built-in), Bread Oven (existing Oven), separate Baking Table/Kitchen Workbench (Food Preparation Table covers), dozens of per-metal pan tiers, separate ladle/spoon kitchen-tool requirements, or Cast-Iron Stove (already covered by existing cooking stations). Griddle/spit/grate/pan and Cauldron must offer **distinct methods**, not cosmetic duplicates.

**Approved counts:** **7 new equipment/add-on item definitions + 16 prepared-food item definitions = 23 ADD**. Existing cooking stations and vessels are cross-listed, **not** new ADD. Food items database currently includes 116 total items (not 116 prepared dishes); do not conflate ingredient and cooked meal counts. Audit recipes and station compatibility but DO NOT implement them until full catalog approval and a separate explicit implementation authorization.

**3.12 reconciliation against the data (Claude, 12 Nov; desk review of `items.json`, `recipes.json`, `blueprints.json` and `structures.json` on dev `7f8aabf4`):**

| Check | Finding | Result / resolution |
|---|---|---|
| Ids and names | Every retained station and utensil and all 16 target foods exist under the numbers given: 8, 255, 257, 267, 514, 40, 835 (FUTURE), 39, 344, 807, and foods 273 to 411 (Meatballs 837 is FUTURE). `items.json` has 116 `food` rows: 108 live, 7 FUTURE and 1 retired (56). None of the 23 ADD names clashes with an existing row. | PASS. The item rows stay KEEP. Only their recipes change (s7 item 18). |
| Recipe routes | The live recipes for the 16 targets make each food in one step at `clay_hearth`, `oven`, `campfire` or `campfire_pot` (Meatballs at `campfire_pot` is FUTURE). Some destinations change, all as approved: Crab cakes (now `campfire`) and Banana fritter (now `clay_hearth`) move to the Griddle or Pan; Mushroom skewer (now `clay_hearth`) moves to the Campfire or Grill. Herb omelette and Egg-nettle fry move from `campfire_pot` to the Clay Griddle or the Iron Frying Pan (rule 3 "proper pan"; the Griddle keeps them pre-iron under rule 5). | PASS. Recorded for the recipe rewrite. |
| **Hand-made foods** | Three live or FUTURE recipes make food by hand from the pack: Nut cake (`energy_bar` 51; nuts and nectar), Fruit juice (fruit and water) and Butter (milk; FUTURE). Rule 2 forbids food preparation from the pack alone. | **CONFLICT.** RECOMMEND: Nut cake and Fruit juice move to the Food Preparation Table, with no intermediate because neither is cooked. Butter stays FUTURE with dairy. DELEGATED default. |
| **Pre-iron progression** | Today Flatbread, skewers, oat cakes and the other breads need only a clay hearth or campfire, and no metal. If the Food Preparation Table were a board table like the Fine furniture (Hardwood Boards need a saw, s3.5), every prepared food would move behind the first Iron - Saw. That breaks rule 5. | **RECOMMEND:** the Table is a Hammer blueprint of logs and twine, like the Log - Table 631 (3 logs, 2 twine), with no Planks or boards. Its knives and board are visual only. Basic bread then stays pre-metal. |
| Pre-iron destinations | Each of the 16 prepared foods has at least one non-iron finish: Clay hearth, Clay griddle, Oven, Campfire or Campfire pot. The Oven costs brick, clay and stone. | PASS. The iron Pan, Grate, Cauldron and Crane only add methods. |
| **Uncooked Meatballs** | Counted ADD, but its only finish, Meatballs #837, is FUTURE (recipe 396 is locked, and the #837 tooltip still names the FUTURE Copper pot). Ploughman's Board is held FUTURE for the same kind of reason. | RECOMMEND: Uncooked Meatballs and Meatballs #837 go live together, with #837 finished at the Campfire Pot or Iron Frying Pan as [D12] routes it, so the count is unchanged. DELEGATED default. |
| Where food data lives | `tools/gen_dishes.py` rewrites the 57 dish rows in `items.json` (and their recipes, vitals and spoilage) from `dishes.json` on every run. | Recipe rewrites for generated dishes, and any new per-food field, go through `dishes.json` and the generator, or a separate data file keyed by item id, never hand edits to generated rows. |
| Attachments | `structures.json` already models add-ons with `addon_of`: the tool rack, vice and anvil, and the approved Bellows and Quenching Trough (s3.3). Cooking stations today are plain station strings (`campfire`, `campfire_pot`, `clay_hearth`, `oven`). | **RECOMMEND:** `addon_of` today only raises a placed station's level and adds no station tag, and the Campfire is built in code with no structure row. So the Clay griddle, Roasting spit, Grill grate, Frying pan and Cauldron are kept equipment (`keeps`, like Clay - Pot 40 in Campfire pot 255), used at `campfire`, `campfire_pot` or `clay_hearth`; the player still sees them set on the fire. Only the Fireplace Cooking Crane needs new attach code, because Fireplace 514 has no station. The Clay griddle keeps egg dishes and Crab cakes at campfire tier. |
| Preservation recipes | The live smoker, drying rack, preserving jar, salted fish, sauerkraut and jam recipes. | Changed under [D14, D17] (s3.14, s7 item 21). |
| Name style | The names use title case ("Unbaked Flatbread", "Iron Frying Pan"). | Implementation applies sentence case and the material prefix: "Unbaked flatbread", "Iron - Frying pan", "Clay - Griddle", "Food preparation table". Nothing is renamed here. |

**Food preservation:** workflow [D14] and roster [D17] approved (s3.14).

### 3.13 Storage, warehouse crates and consolidated inventory [D13] — OWNER APPROVED (DESIGN ONLY)

**Owner authority:** Dave explicitly approved ChatGPT's complete attractive/useful **Storage System — Proposal 1** ("I like it") and added the mandatory **warehouse crate + warehouse management desk + moving loaded crates to ships and other warehouses** concept. He then specified: "you can also just open a crate and see its inventory and manipulate it unless its locked". These latest owner rulings supersede any wording suggesting that a central interface is the *exclusive* way to open containers. **This is approval of storage-category design and these mechanics only; full master catalog and implementation are still NOT approved.**

**Existing KEEP / UPDATE, stable IDs, do NOT duplicate:**

| Existing item (row number) | Existing function/capacity (baseline) | Approved storage integration |
|---|---|---|
| Wicker - Chest #23 | 12 slots / 40 kg | Early general chest, direct access and optional zone grouping |
| Wooden - Chest #29 (becomes Rustic - Chest, s3.5) | 20 slots / 150 kg | General household storage |
| Iron - Chest #852 (becomes Ornate - Chest, s3.5) | 30 slots / 250 kg | Secure higher-capacity chest; lock support where authorized |
| Crate #850 | 10 slots / 80 kg | Remains useful; enable sensible stacking, movable per-instance inventory, warehouse linking; distinct from new heavy **Warehouse Crate** only where freight role warrants |
| Barrel #649 | 8 slots / 60 kg | Attractive bulk goods, grain/liquid compatibility according to storage rules |
| Cupboard #647 | 16 slots / 60 kg | Household pantry and general supplies |
| Wooden - Shelf #645 | 8 slots / 30 kg | Visible shelf storage |
| Log - Shelf #848 | 6 slots / 30 kg | Primitive shelf. Its blueprint 167 and structure state 207 are already retired in the data: the row stays KEEP so placed shelves in old saves keep working, but it cannot be built. |
| Hide - Sack #783; Basket #785 | 6 slots / 25 kg each | Early camp storage |
| Storage Jar #781 | 4 slots / 30 kg | Dry food, grains, oils and jars subject to real container rules |
| Weapon Rack #787; Armour Stand #789 | 6 slots / 40 kg each | Visibly display compatible weapons, armour and outfits |
| Root Cellar #832 | 12 slots / 120 kg; cold storage | Cold/seasonal foods; coordinate approved preservation methods later |

**Existing cross-reference, NO duplicate:** Rock Pile item #235 is a physical 45-stone pile, not a universal storage chest. Tool Rack #82 is primarily a Workbench upgrade, NOT an inventory container; do not silently reinterpret it as the new Tool Cabinet. Existing Jar/Barrel/Crate storage should not be retired or replaced by attractive future variants.

**Sixteen approved ADD definitions (14 from Storage Proposal 1 plus two warehouse-specific additions):**

| Family | ADD item | Distinct functionality |
|---|---|---|
| Household (1/6) | Large Wooden Chest | Larger general-purpose chest with genuine cost/footprint/capacity trade-off vs #29 |
| Household (2/6) | Wardrobe | Clothes, cloaks, boots, gear outfits in visible/tidy household furniture |
| Household (3/6) | Dresser | Small personal belongings and everyday items; not an infinite furniture container |
| Household (4/6) | Bookcase | Books, maps, scrolls and documents, visual occupancy |
| Household (5/6) | Apothecary Cabinet | Herbs, tonics, remedies and appropriate medical supplies |
| Household (6/6) | Bottle & Jar Rack | Stored vessels/preserves visible on shelves, appropriate size/contents |
| Workshop (1/2) | Tool Cabinet | Real tools and repair equipment; distinct from existing tool-rack workstation upgrade |
| Workshop (2/2) | Open Storage Bin | Loose stone, clay, ore, charcoal or similar materials, realistic contained bulk |
| Bulk (1/5) | Firewood Rack | Visibly stacked, drying/protected burn fuel |
| Bulk (2/5) | Log Rack | Whole logs, substantial bulk and physical limits |
| Bulk (3/5) | Lumber Rack | Planks, Hardwood Boards and beams without confusing them as interchangeable |
| Bulk (4/5) | Mason's Pallet | Stone blocks, bricks and heavy masonry |
| Bulk (5/5) | Ore & Metal Rack | Ore, ingots and worked metal, safe heavy loading |
| Zones (1/1) | Storage Sign / Ledger | Designates a physical local storage zone and provides a combined search/deposit/withdraw interface, NOT added capacity |
| Warehouse (1/2) | **Warehouse Crate** | Sturdy, stackable, movable **freight crate with persistent individual inventory**, suitable for loading **while full** onto a cart, wagon or ship; distinct from basic #850 by stronger cargo/secure-transfer role, not an arbitrary material grade |
| Warehouse (2/2) | **Warehouse Desk** | Physical warehouse management table/desk; connected inventory interface for nearby crates within the warehouse's local storage area (area rule: s3.13 reconciliation) |

**Building arrangements/layouts, NOT additional master item IDs:** Woodshed (Log/Firewood/Lumber racks), Materials Yard (Ore/Metal Rack/Mason's Pallets/Bins), Storehouse (Crates, Barrels, Shelves + Warehouse Desk/Storage Sign). Other attractive warehouse rooms, armouries, workshops, pantries and stables can be built from actual pieces; no "storehouse object" that magically creates capacity. Existing Root Cellar retained. The Granary is a fourth layout of approved storage pieces [D13, D17], not a row.

**Mandatory direct crate access — explicit latest owner correction:**
- Every existing **Crate #850** and newly designed **Warehouse Crate** remains a normal independently interactive physical inventory container. Standing at an accessible crate and opening it lets the player view, insert, withdraw, rearrange and transfer its contents directly, unless that crate is **locked** or their access is otherwise forbidden by valid in-game rules.
- An **unlocked** crate is directly accessible to nearby players; a **locked** crate rejects **unauthorized** access. **Explicit owner rule (Dave's latest clarification): the player who owns a crate can always view and manipulate their own crate's contents via an in-range Warehouse Desk, EVEN WHEN THAT CRATE IS LOCKED, without first unlocking it; the same owner entitlement applies to direct crate access and a future in-range ship Captain's Table.** An explicitly authorized nonowner may access according to granted rights. Owning or operating the Warehouse Desk / Storage Sign / ship Captain's Table **does not grant ownership of connected crates**. Each interface shows and allows transactions only for those particular crates for which the **interacting player's** personal permissions suffice. A desk must never bypass a crate lock for someone other than its owner or an authorized user; unauthorized contents are not revealed, including via aggregate lists/totals. Evaluate permissions on every operation server-side.
- The warehouse interface is **optional convenience**, NOT required to open/manage an individual accessible crate. It can show totals, location and search/filter of contents to which the interacting player has access. Capacity and contents remain in the actual crates, not the desk.

**Owner-approved four-digit combination locks for crates and chests (latest Dave correction):**
- Each applicable **crate or chest** (including existing Crate #850, Warehouse Crate, current chest grades and Large Wooden Chest) may be assigned a **four-digit numeric access code by its owner**, ranging from `0000` to `9999`; keep leading zeros. Treat the combination as a string, not an integer. This is an **optional lock mechanism/instance property**, **not** a separate new item or mandatory universal lock on baskets, shelves, racks and other furniture.
- A player who receives the correct code from the owner can **unlock/open and manipulate** that specific crate/chest directly and, when the crate is physically linked there, through the Warehouse Desk or a future ship Captain's Table. The **owner always has full access even without entering a code**. Other expressly authorized users retain permission according to owner grants. A desk's owner does not acquire access to someone else's coded containers merely by owning the desk.
- **A correct code grants the entering player access to the locked container; do not silently make it globally unlocked for everyone else.** Distinguish an intentionally unlocked/public container from a code-protected one. The owner can set, replace and remove the code and revoke previously granted access; owner code changes must invalidate stale code-based authorizations. Other people must not read the code through any desk UI, cargo manifest, network data or client inspection.
- **Owner-approved exact failed-code delay:** For each failed code attempt, that player cannot try that same container again for **10 seconds × their consecutive failure count**: first wrong code = 10 seconds, second = 20 seconds, third = 30 seconds, fourth = 40 seconds, etc.; **no maximum was set by Dave**. The delay starts after each failed attempt, and the user interface shows the remaining time. On a successful code entry, reset that player's failure count for that container to zero. Do not impose these guessing delays on the owner, who has direct owner-authorized access without code entry. Enforce the count and remaining lockout **server-side per player + persistent crate/chest ID**, consistently across direct UI, Warehouse Desk and future Captain's Table; changing interfaces, moving the crate or reconnecting must not bypass the wait. Count only wrong code submissions, not opening or browsing the interface. A four-digit code is game convenience rather than strong real-world security; do not require a physical key item.
- Moving a locked, loaded crate to another warehouse or ship preserves the same code, owner and contents; newly linked desks still enforce the same per-crate access. Protect stacked crates and all associated network/save/load/transfer paths. No combination sharing via global access or another container's credentials.


**Loaded freight mobility and adaptive local connections — mandatory owner mechanic:**
1. A warehouse can contain many stackable Warehouse Crates, each with unique persistent ID, true item inventory, locked/unlocked state, ownership/access data, physical size/mass, and contents condition/spoilage. A crate remains *the same crate* when transported; moving it never converts inventory into a separate remote ledger or duplicates an item.
2. When player physically moves a loaded crate using suitable cart/wagon or future ship mechanics, the full crate and contents travel as cargo. Include contents weight and dimensions, safe stacking height/clearance/load limits and collisions. Crates do **not** teleport via ledgers.
3. In a warehouse, qualifying crates physically within the warehouse's designated zone automatically become visible in **that Warehouse Desk**. On loading into a ship's actual cargo hold, they can automatically connect to that ship's **Captain's Table** (future ship-control/storage interface, **NOT an approved separate ADD item yet**). On unloading into a different warehouse, the new warehouse's desk connects to them. **Binding is location-derived** and revocable, not a destructive one-time assignment. Each crate belongs to **at most one active desk/ledger context at a time** (Storage signs included; overlap priority in the reconciliation table below), with an explicit unambiguous locality/ownership priority when areas overlap; no stale access through prior desk after crate departs.
4. Transfers are real transactions over physical container inventories, respect per-crate locks/permissions, cargo limits, time progression, multiplayer atomicity, server authority and persistence. Moving a crate does not auto-unlock, reset spoilage, duplicate contents or allow a client to remotely withdraw it from its previous warehouse.
5. A ship captain's table is a planned **ship feature**; ship mechanics, hull cargo holds, route/pathfinding, and table item/blueprint owner category remain **FUTURE and not implicitly approved** by this storage category. Reuse the Warehouse Desk/Storage Sign aggregation logic for ship storage when ship systems are approved.

**Unified storage rules and presentation:**
- Storage Sign creates a **local area view** of permitted physical containers/racks/barrels/bins; Warehouse Desk provides a warehouse-oriented view of crate freight and may also include eligible area containers. Do NOT make two incompatible inventory backends. Avoid a pointless second remote container inventory inside the desk/sign.
- Quick-deposit matching stacks, withdraw, search, filters, totals and human-understandable category names; existing station storage sourcing/nearby range [D1] must not be replaced by network-wide virtual storage. Crafting access is physical/local and permission-aware.
- Organize by physical bulk: rocks/ore/logs/boards require appropriate racks, pallet, bins, crate payloads with genuine mass, volume and shape; chest/wardrobe/bottle rack for suitable goods. No infinite capacity via stacking or ledger.
- Visible fullness changes for log racks/wood racks/shelves/weapon racks/wardrobes/crates using modest visual fill states; not one individually rendered object per resource item. Real item counts and quality/spoilage remain in storage records, not appearance.
- Several crates can be stacked within supported footprint, loading/height/weight constraints; access to their individual inventory must remain possible when accessible, otherwise safely use authorized warehouse desk. No clipping into ceilings or unlimited support.
- Existing `Crate #850` should also be usable with warehouse linking and simple stacking when appropriate; the **new Warehouse Crate** must earn its separate ID through meaningful sturdy shipping, stacking/handling and locking utility, not duplicating everything old crate already does.
- Material sourcing: basic storage before iron, stronger materials and hardware as necessary for heavy transport. Craft rates, storage slots, capacity/height numbers are **TBD for tuning**, not invented now.

**3.13 reconciliation against the data (Claude, 12 Nov; desk review of `items.json`, `structures.json`, `validate_items.gd` and s3.5 on dev `7f8aabf4`):**

| Check | Finding | Result / resolution |
|---|---|---|
| Ids and capacities | Every row in the baseline table exists, and its slots and kg match `structures.json` exactly. Root cellar 832 is the only `cold_store` row. Rock pile 235 (a `placeable`) and Tool rack 82 have no container fields, as the table says. | PASS. |
| **Names after [D4]** | The table uses today's names. Under s3.5 [D4], Wooden - Chest #29 becomes **Rustic - Chest** and Iron - Chest #852 becomes **Ornate - Chest**, both UPDATE. In the data, #645 is "Shelf" and #781 is "Storage jar". | DOC FIX: noted here. The s3.5 names win. No status changes. |
| **Large Wooden Chest vs chest grades** | s3.5 already grades chests: Crude (ADD), Rustic 20 slots, Fine (ADD) and Ornate 30 slots, all made from Hardwood Boards. A "larger general-purpose chest" next to #29 overlaps Fine and Ornate. | **DECIDED [D17]:** keep the row (ADD) with **greater weight capacity and a larger footprint, within the 30-slot limit** (`Inventory.SLOTS := 30` is shared by pack, containers, save and network). It may use the optional code lock. Delegated detail: its `max_kg` is above the Ornate - Chest's 250, its slot count is at most 30, and it cannot be lifted while loaded. |
| New household furniture | Wardrobe, Dresser, Bookcase, Apothecary cabinet, Bottle and jar rack and Tool cabinet are finished furniture. | They follow the s3.5 single-object rule: Hardwood Boards, `nails` and `hinges`, with cloth or leather only where it fits ([D5]). Each needs one board after the first saw. Pre-iron storage stays: Wicker - Chest, Hide - Sack, Basket and Storage jar (Log - Shelf can no longer be built; see the table above). |
| Storage Sign | A plain **Sign 791** already exists, "a plank board on a stick to mark a camp or a path" (KEEP). | RECOMMEND: the Storage sign is its own ADD row, so the path sign keeps its job. Use the name "Storage sign", without the slash. |
| **Locks and permissions** | Every container has a `who` field. Only `"anyone"` is built: 15 rows use it and 1 uses `"owner"`. `validate_items.gd` rejects other values until the ownership system lands. No lock or key exists. | **DEPENDENCY.** Locked crates and permission-aware desks need that ownership and lock system. Extending `who` is the natural hook. The code lock (s3.13, 4-digit codes) needs more than `who`: each container instance must store its owner, a hashed code, and the players who have entered the current code. Changing the code clears that list. The server checks every direct, desk and future Captain's Table action, and applies the wrong-code wait: 10 seconds more after each consecutive wrong attempt, counted per player and container, and reset by the correct code. All of this moves with a loaded crate. Container `who` values become the default access, and the code lock applies on top of them. Already built: each placed structure stores its `owner`, and the owner-only "keep out" tick excludes a chest from crafting sourcing. Not built: any owner check on opening (`_chest_of`) or transfer. |
| **Loaded, movable crates** | Structures are static, and a placed container cannot be picked up with its contents. | **NEEDS CODE**, and this shares one system with the [D9] per-container inventory and the [D11] movable vehicle. A loaded crate is a container that keeps its contents when lifted, carried or loaded. |
| Desk and sign aggregation | The live station sourcing (s2.5 [D1]) already reads nearby containers. | PASS. Desk and sign are a view over the same physical containers, with no second backend, as rule 1 requires. |
| **Moving or sourcing from a locked crate** | No document says who may lift, load or take down a locked crate, or whether stations and NPC jobs may draw from it. Taking down a loaded container is refused today ("Empty it first"). | DELEGATED DEFAULT: only the owner or a player with access may lift, load or take down a locked container, so a thief cannot carry it away. Locked containers feed crafting and NPC jobs only for players with access; sourcing never bypasses a lock. The existing "keep out" tick stays a separate setting with its own icon. |
| **Desk area** | No zone concept exists. Chest reach is 4 m and own-container craft sourcing is 12 m. | DELEGATED DEFAULT: a Warehouse Desk covers a stated radius or its enclosing building (number in s5). Dave's one-context rule applies to every desk and ledger, Storage signs included: where a sign and a desk cover the same crate, the desk takes priority (the deterministic priority the rule asks for). The 12 m craft reach is not the desk view. |
| **Crate #850 vs Warehouse Crate** | Both rows claim linking, stacking, locks and a movable inventory. | DELEGATED DEFAULT: #850 keeps every approved ability. The Warehouse Crate earns its row as freight: higher `max_kg`, stackable in wagon beds and cargo holds, and rated for ship loading. |
| **Ageing in new containers and in transit** | `spoilage.json place_mult` is keyed by structure kind, and a missing kind ages at 1.0. Ageing runs over all saved character packs, placed containers and ground items, so a crate on a cart or ship would not age at all. | NEEDS CODE: a `place_mult` row for each new container and for vehicle and ship cargo, and cargo in the ageing loop, so food keeps ageing in transit (recommended, so that moving never pauses or resets spoilage). |
| **Contracts** | Chest actions carry only world id, slot and count; structure save rows carry only `owner` and `keep_out`. | NEEDS CODE: locks, codes, attempt deadlines, the desk view and loaded crates need new `PROTOCOL.md` actions and save fields, reviewed as a contract change. |
| Name style | "Lumber Rack": `lumber` is the old data id for Planks, which s3.2 retires. "Ore & Metal Rack" and "Bottle & Jar Rack" use an ampersand. | Implementation names: "Board rack" (Planks and Hardwood Boards), "Ore and metal rack", "Bottle and jar rack", in sentence case throughout. Nothing is renamed here. |

**Count and scope:** **14 originally proposed additions + 2 warehouse-specific = 16 ADD catalog definitions**, **4 build-layout arrangements (Woodshed, Materials Yard, Storehouse, Granary), not items**, and **1 shared unified-storage capability**, **NOT extra inventory item(s)**. Existing stored objects retained and updated as needed. Ship Captain's Table is a future ship-system **cross-reference, not counted as a 17th new current storage item**.

**Related categories:** preservation is decided by [D14] and [D17] (s3.14, 2 ADD); the nine boards and the Serving Platter by [D15] (s3.15). **No code/gameplay JSON, no merge or authorization to implement any category, and the complete master catalog remains unapproved.**

### 3.14 Simplified food preservation [D14 workflow; D17 roster] — OWNER APPROVED (DESIGN ONLY)

**Owner process decision, binding [D14]:** Dave approved a simplified, single Food Preparation Table → finish workflow, with **two** possible finishes and no busywork. For cooked, smoked and dried foods, prepare only when needed and then finish at an appropriate existing Campfire/Oven/Smoker #777/Drying Rack #775/Cooking Pot. For sealed pickled and fermented foods, players can prepare **large batches** and **they passively mature into Ready after enough in-game time**, without re-opening, shuffling between stations or clicking each one. Owner's example expressly permits **hundreds of jars** when materials and storage actually exist.

**Owner roster decision, binding [D17]:** keep the existing placed **Preserving Jar #830**; do **not** add a Sealable Preserve Jar. **ADD Smoked Meat and Dried Mushrooms.** Do not add Dried Herbs or Cured Olives. Bulk preservation and passive maturation use existing item definitions, with no duplicate jar or food rows.

**Minimal rules [D14]:** Maturing → Ready → Spoiled, real ingredient consumption, per-batch ready time and shelf life, save/replication/warehouse-mobility persistence; no per-frame fermentation simulation; no resetting age on stacking, moving or splitting. Real prep happens at the Food Preparation Table [D12], not with carried knives. Direct Drying Rack use for plain fruit stays. Jam and other heat-processed preserves still require cooking; sealed raw sugared fruit is never treated as stable.

**Existing equipment and foods, KEEP:** Drying Rack #775; Smoker #777; Preserving Jar #830; Root Cellar #832; Storage Jar #781; Barrel #649; Cheese Press #844 (FUTURE). Jerky #406, Salted Fish #407, Smoked Fish #185, Dried Berries #408, Dried Apples #450, Dried Figs #456, Fruit Leather #184, Sauerkraut #409, Pickled Vegetables #834 (FUTURE), Plum Jam #453, Preserved Damsons #455, Berry compote, Apple sauce; dairy rows stay FUTURE.

| Status | New row [D17] | Process and role |
|---|---|---|
| ADD | **Smoked Meat** | Raw meat and salt at Smoker #777, one step. A heavier Main Meal joint (more kcal and weight per item) that keeps well and feeds the Roast, Mixed Grill and Charcuterie boards. Jerky #406 stays the light travel snack from the Drying Rack, with less kcal per item; the data records the difference. |
| ADD | **Dried Mushrooms** | One drying recipe per fresh mushroom (Mushrooms 551, porcini, chanterelles, morels, puffball) at Drying Rack #775. A light, long-keeping Fruit & Vegetables food and ingredient. It stays **out** of the `mushrooms` group (the group key 551 is itself a mushroom, so joining it would let it dry itself). Its uses are named directly: an extra Uncooked Mushroom Skewers recipe and the Harvest Platter. Mushrooms 551 and Puffball gain a shelf life so drying has a purpose. |

**Count: 2 ADD, 0 new stations.** Omitted by decision: Sealable Preserve Jar, Dried Herbs, Cured Olives; earlier omissions stay (Curing Tub, Butter Churn, Granary as an item, Prepared Meat Strips, Salted Meat, Smoked Sausage, Dried Fish, Salted Butter, Hard Cheese). The Granary is a storage layout [D13].

**Representation (delegated technical detail, Claude's design; no new IDs):**
- **Where sealing happens.** [D14] puts preparation at the Food Preparation Table; where a food needs cutting or mixing first, that is done there. Sealing is the one finishing step at #830. Sauerkraut and pickles need no prep (whole cabbage or vegetables, salt, water), so they go straight to #830 under [D14]'s own rule that direct station use is fine where no prep is needed.
- **The Preserving Jar #830 stays the sealing station.** It is a placed station with no inventory. Its passive recipes (Sauerkraut, recipe 271; Pickled Vegetables, recipe 393, FUTURE) take the real ingredients and give the finished food's own stack (Sauerkraut #409). The jar vessel is part of the food, as today: "a jar of sauerkraut" is one Sauerkraut. No vessel item is made, consumed or returned, so nothing can be duplicated.
- **Maturing.** Each passive recipe has a `ready_age`, read against the stack's existing spoilage age (`wear`). Below it the stack shows *Maturing* and cannot be eaten; at it the stack shows *Ready*; it spoils later at its normal shelf life, which must exceed `ready_age`. The age is never reset. The live clock is scaled by place and season, so a root cellar or winter slows ripening as well as spoiling; this is the simplest sound reading of Dave's "enough in-game time" and needs no new field.
- **Merging.** Stacks never merge across `ready_age`, so a Maturing stack cannot join a Ready one (today's rule merges within 10% of shelf life).
- **No shortcuts.** A passive recipe's output always starts at age 0, and sealing refuses inputs below half freshness, so old produce is not turned into instant Ready food. A Maturing stack cannot be eaten, used as an ingredient, drawn by stations or sold.
- **Long shelf lives.** Shelf life × `gentle_mult` must stay under the `wear` cap (6553.5 game hours); validation checks it (Pickled vegetables and Keeping apple exceed it today).
- **Bulk.** One craft at #830 makes a batch: a batch-size choice (for example ×1, ×10, ×50) multiplies the real inputs and outputs. #830 has no inventory, so output goes to the pack and then nearby containers, and the batch is capped by the free space there. 200 portions of Sauerkraut is 20 stacks of 10, with one timer per stack, not per portion. Any station inventory built later (s2.5) is a container kind with its own `place_mult` row, so food ages there too. Batch size limits are tuning (s5).
- **Heat rule.** Berry compote (102), Apple sauce (283), Plum jam (285) and Preserved damsons (287) are cooked preserves: their recipes move from the unheated #830 to the Campfire Pot or a cooking pot, and they are Ready when cooked. Only fermented and brined foods mature at #830.
- **Where stacks age:** wherever they are stored. New containers and vehicle or ship cargo need `place_mult` rows and must join the ageing loop (s3.13).

**Detailed process and test plan:** [FOOD_PREPARATION_PRESERVATION_SERVING.md](FOOD_PREPARATION_PRESERVATION_SERVING.md) §§2,4–5. Workflow [D14] and roster [D17] are decided; batch limits, `ready_age` values and capacities are tuning (s5).

### 3.15 Functional Serving Platters and prepared food boards [D15] — NINE OWNER-APPROVED RECIPES

**Owner decisions, now final for this category:** Dave wanted **one reusable Serving Platter** that can display a named, actual prepared food platter from inventory on a dining table, where servings can be eaten and visible contents diminish. He specifically told ChatGPT to merge repetitive boards; the final 9-item list was shown and he said "**sounds good**." The earlier proposed 20 and 15 names are SUPERSEDED by exactly **nine** named food-board recipes below. No separate platter object per food variant.

| Status | Owner-approved final prepared food item | Role / ingredient compatibility |
|---|---|---|
| ADD | **Seafood Platter** | Cooked fish, shellfish and crab; includes former Fisherman's Board / Smoked Fish Board / Coastal Feast concepts |
| ADD | **Roast Platter** | Distinct roast meat with roots and vegetables; absorbs Roast Dinner, Hunter's Feast, Grand Banquet and former separate Roast Beef Platter. Use existing generic Roast Meat #69 / Rosemary Joint #275 / Roast Beast #191; a *beef variant* is possible only when a real beef source is approved |
| ADD | **Mixed Grill Platter** | Cooked sausage, meat skewers, mixed grilled meats; absorbs Sausage Supper |
| ADD | **Charcuterie Board** | Cured meats, jerky, sausage and appropriate preserved sides; absorbs Traveller's Board |
| FUTURE (new) | **Ploughman's Board** | Bread, cheese and pickles; existing Cheese #418 and Pickled Vegetables #834 are FUTURE and must be genuinely available before recipe use; absorbs Bread & Cheese Board |
| ADD | **Harvest Platter** | Roasted vegetables, roots and mushrooms (seasonal vegetable display) |
| ADD | **Tavern Supper Board** | Prepared savoury pies, bread and vegetable sides |
| ADD | **Breakfast Platter** | Eggs, oatcakes and sausage |
| ADD | **Dessert Platter** | Apple pie, sweet breads/cakes and fruit; absorbs Orchard Fruit Platter, Sweet Treats Board |

**One additional ADD: Serving Platter** (generic reusable physical carrier to place and remove a prepared board on any compatible existing dining table). The prepared food board is crafted at the **Food Preparation Table [D12]** from real prepared ingredients and becomes a tangible inventory item. Placing consumes no extra food; eating removes real portions, visual mesh/fullness changes, leftovers and carrier can be recovered, and spoilage/ownership/save/network continuity persist. Food cannot be duplicated by moving, loading, consuming or picking up. Actual ingredient availability and nutrition effects are checked by later implementation; do not invent missing livestock or skip future flags.

**Final [D15] roster count:** **8 ADD food board rows + 1 FUTURE food board row + 1 ADD reusable Serving Platter = 9 new ADD and 1 new FUTURE.** Nine distinct edible boards, not 9 carrier objects. Earlier 20/15 recipe rosters were drafts and MUST NOT be counted in totals or carried into recipe generation. These rows are owner-approved **design**, not permission to edit JSON, code, recipes or merge.

**Board representation (DELEGATED default):** a board stack's count is its remaining portions. Placing moves the stack into the placed platter's inventory, and picking up returns it. A board's shelf life is set at assembly from its shortest-lived ingredient. Each portion eaten counts as one food of the board's group (s3.16), so it refreshes that group's effect but never stacks it. Boards can be eaten from the pack; the Serving Platter only displays them. Display on a table needs a table-surface attach point and a placed-platter structure with its own inventory (new code). NPC diners need an NPC hunger system, which does not exist, so NPC eating is FUTURE. The Serving Platter still needs a material and station; RECOMMEND a wooden recipe like Wooden bowl #39. Before the first saw no dining table can be built, so the Food Preparation Table also serves as a display surface.

**Reference:** [FOOD_PREPARATION_PRESERVATION_SERVING.md](FOOD_PREPARATION_PRESERVATION_SERVING.md) §3. The future systemic effects are in §3.16 [D16].

### 3.16 Temporary food effects and training XP [D16, D17] — OWNER APPROVED; INITIAL PLAYTEST VALUES SET

Dave directed that meals have meaningful, temporary effects related to their ingredients and tier, and *specifically* that food can improve XP earned during training and skill use, while ordinary grains/bread provide energy but no XP boost; sweets grant fast energy and may carry an XP-gain penalty. This is game design, not a medical or real-life nutrition claim.

**Keep a small number of effects, reuse existing character systems, no new permanent skill/attribute bars:**

| Food profile | Owner-directed temporary effect (initial values in the [D17] table below) | XP treatment |
|---|---|---|
| **Protein-rich** (meat, fish, eggs) | Physical work/endurance and reduced strain/exertion as appropriate | **More FITNESS XP from actual physical activity**; Dave's **+20% Fitness XP** example is the tier 3 initial value [D17] |
| **Red-meat / hearty roast** | Temporary health regeneration / recovery where appropriate, along with protein benefit | Fitness-training XP may apply as the meal's chosen XP profile; avoid automatically stacking separate XP bonuses |
| **Bread / grain / potatoes** | Useful short-term energy and stamina; baked meals may support movement or exertion recovery | **No training XP bonus simply for carbohydrates** |
| **Fruit / vegetables** | Sustained recovery, hydration/comfort or mild endurance consistent with existing vitals | No automatic XP multiplier unless part of a genuinely higher-tier balanced meal |
| **Sweets / desserts** | **Fast, short-lived energy boost** and/or rest comfort | **Possible temporary XP-gain reduction**, a deliberately game-like tradeoff; value/duration to tune |
| **Balanced higher-tier prepared meal / banquet** | Better, longer-lasting combined usefulness grounded in ingredients | **Optional bonus to ALL actively earned skill XP**, including Fitness only once (no double multiplication); this is owner-suggested and requires balancing |

**Progression:** simple low-tier foods grant small or short effects; quality/complex recipes offer larger or longer effects within caps. Recipe tier, not arbitrary mystical labels, decides the strength/duration. Do **not** permanently increase Fitness stat, skill ranks or XP when food is consumed. Existing Fitness + training XP is a separate established system. For Fitness's delayed daily XP payout, multiply **at each qualifying effort XP earning tick**, not at the midnight payout: eating immediately before midnight must not multiply an entire day's XP. Likewise, skill XP boosts apply only at the moment an actual skill earns XP.

**Three simultaneous food effects, DIFFERENT food groups, per Dave's follow-up:** allow **up to three active benefits from three different groups**, not three roasts/dinners or three desserts. Proposed practical grouping: **Main Meal** (roasts/stews/fish), **Bread & Grains** (bread/potatoes/porridge), **Fruit & Vegetables**, **Dessert**, **Beverage** (initially the existing teas and Fruit juice [D17]; coffee and other drinks may be added later). Any combination of up to 3 different groups is valid; Dave's examples include **Roast + Coffee + Dessert** and mixed meal/snack/drink configurations. An item has ONE primary group for slot compatibility (DELEGATED default: a board's group follows its main content, so the Dessert Platter is Dessert, the Harvest Platter is Fruit & Vegetables and the other seven are Main Meals). A new item in an already active group **replaces that group's prior effect**; a food from a fourth group while three are active prompts a simple replace-one choice. Each active food has its own timer. Normal hunger/calories still work independently from effect slots; eating does not arbitrarily stop hunger relief.

**Decided [D17]:**
- **Every food effect, benefit or penalty, is temporary** and lasts only its stated duration. The permanent Fitness training cost of the energy aids (`vitals.json energy_aids` and `_fitness_cost`, Dave's 21 Oct rule) is removed. DELEGATED defaults derived from [D17]: Nut cake (`energy_bar`) becomes a Dessert, with quick energy and the temporary dessert XP penalty; Herbal tea, Nettle tea and Magic tonic (FUTURE) become Beverages that keep their energy lift. Instant energy (energy aids and Desserts) is given only when that group's slot is newly filled or its timer has run out, so it cannot replace sleep; the amount comes from the Dessert table below for every dessert, so Nut cake (3 ingredient kinds, tier 2) gives +12 and its `energy_aids` energy changes from 25 to 12 to match Dave's accepted values.
- **Beverages are the existing teas and Fruit juice 806.** No coffee exists yet. DELEGATED defaults: Stomach, Chamomile and Willow bark teas keep their cure when the player is sick and give the Beverage effect at any time, so they are no longer refused when healthy. Energy-aid teas are no longer refused when the player is rested; they then give only the Beverage effect.
- **Initial playtest values** are the table below (accepted by Dave as starting values, not permanent balance).

**Delegated technical facts:** Rested's `skill_gain_mult` (1.00 to 1.10 by tier) applies only to skill practice, never to Fitness XP. Three slots, their timers and the HUD are new character, save and protocol state; the Rested record holds only one level and one end time. A food multiplier in the Fitness tick and instant energy from ordinary food are new code.

**Initial playtest values [D17]** (game hours; 1 game hour = 2.5 real minutes). Tier counts ingredient kinds over the whole chain (preparation plus finish, so a pie keeps its tier after [D12]) and is stored as a data field: T1 1–2 kinds, T2 3 kinds, T3 4+ kinds and boards. Foods outside `dishes.json` (jerky, teas, juice, Smoked Meat) get their tier in the same field. Board tier 3 is an initial value to retune in playtest.

| Group | T1 | T2 | T3 | Hook |
|---|---|---|---|---|
| Main Meal | Fitness XP +10 %, 2 h | +15 %, 6 h | +20 %, 12 h; a balanced T3 board may give all-skill XP +10 % instead | Fitness tick and skill `practice`. Red-meat and hearty mains also get `regen_mult` ×1.05 / ×1.10 / ×1.10. |
| Bread & Grains | energy drain −10 %, 4 h | −15 %, 8 h | −20 %, 12 h | `exhaustion_mult`. No XP. |
| Fruit & Vegetables | health regen ×1.05, 4 h | ×1.10, 8 h | ×1.15, 12 h | `regen_mult`. No XP. |
| Dessert | +8 energy at once | +12 | +15 | XP −5 % for 1 h, on its own timer. |
| Beverage | hunger and thirst drain −5 %, 2 h | −10 %, 4 h | — | `hunger_thirst_mult`. No XP. Medicinal teas also cure. |

**Combination rules (DELEGATED defaults with the [D17] values):**
- XP: the single best food XP bonus, minus any dessert penalty. Skill XP adds Rested (`skill_gain_mult − 1`), capped at +25 %. Fitness XP is food only, capped at +20 %. Both stay under the existing caps (Fitness `max_gain`, skill `day_cap_units`).
- Other multipliers: the larger of the food effect and the Rested or bed effect, never multiplied.
- The player is asked before a weaker food replaces a stronger effect in the same group. A declined fourth-group prompt gives calories only. Food with no effect profile (raw ingredients, salt) never touches a slot. Eating can still be refused at the stomach cap.
- Timers are saved with the character, kept through logout, and cleared on death.

**Anti-exploit minimal rules:** benefits from three different groups coexist; overlapping XP boosts do not multiply together. Use the **single strongest applicable XP-gain bonus** across active foods (and resolve any dessert penalty with one transparent rule at balancing time), without double applying “all skills” + “Fitness XP”. Don't permit eating 200 sweets to refresh stacked XP benefits. Durations, tiers and percentages start at the initial playtest values above and are retuned in playtest. Skill-specific XP schemas are not all present yet; apply the same shared earned-XP hook when they exist rather than hand-coding a rule per food or skill.

**In-world nutritional guides [D17: approved; NPC dialogue and readable books; implemented when the supporting systems exist]:** NPCs (innkeepers, cooks, hunters, trainers, healers, sages, merchants) and readable books can **teach suitable THREE-GROUP meal combinations** for different professions/playstyles. E.g. fighter/warrior: roast + bread + tea for Fitness training and energy; scholar/wizard: fish + fruit + tea for long study or future caster-focused skills; builder/miner: stew + grains + beverage for work/recovery. These examples are illustrative: final guide text must describe only effects in the approved tuning at that time, and no study, magic or caster skill exists in `skills.json` today. **Do not invent mana, magic XP or coffee availability** if those systems/items are not defined. Guides explain *existing actual effects* and suggested combinations, not hard class restrictions or secret new buffs; any player can experiment and receive the same results whether or not they read a guide. Learned tips may be remembered in the character's personal recipe/knowledge journal (future capability; `field_journal_design.md` currently concerns animals and is not permission to add another journal implementation). Readable guide books are a future content set: their item rows, recipes and where they are found are added in that later phase, held by the Bookcase [D13]; no book is mandatory, and there is no perk, hidden combo-bonus table or extra crafting step. Books/NPC dialogue are discovery and immersion, **not gameplay access gates**.

**Status:** design and initial values decided [D16, D17]; not implemented. No new food IDs represent buff levels; each food gets a `food_group` and effect tier as data (s7 item 20).

## 4. Implementation details (follow from the decisions; no new design)

1. **Repair data:** `repair_station` on each metal tool names its crafting station type (today 26 rows say `forge`; bronze tools: `forge`, which the Smithy also provides; iron and steel: the Smithy); `drops.json tool_wear.repair_restores` (0.5) becomes "restore up to the remaining maximum"; stone, wooden and primitive rows lose `repair`; code removes a disposable tool at zero, drops a surviving thrown Javelin as a pickup, and keeps a broken metal tool in its slot.
2. **Sharpness:** tools gain per-instance sharpness and current maximum durability beside wear; `tool_wear.hone` is replaced by the whetstone rule; `edge: true` marks sharpening-eligible metal tools (add to pickaxes, remove from stone tools).
3. **Wood data:**
   - Recipes 16 (sawmill) and 159 (hand saw) give 6 Planks per log; new sawmill and hand-saw recipes give 4 Hardwood boards per hardwood log; `recipes.json hand_saw_balance` and the `validate_items` check change with them.
   - Species with no own log item (alder, willow, rowan, sweet chestnut, fruit trees, balsam fir) give the plain Log (`server_items.gd _log_number`). Because basic Logs give Planks, `wood_species.json default.class` changes from `hardwood` to `softwood`, so a plain Log chops into Softwood blocks and Soft firewood, matching its Planks.
   - `wood_species.json retired_to` maps hardwood `lumber_*` to the Hardwood board, softwood `lumber_*` and all `beam_*` to the Plank.
   - Hob's `shops.json buy_rules`: the 16 species `lumber_*` and `beam_*` rules collapse into `lumber` (3 per copper, as today for softwood and plain) and a new Hardwood board rule (2 per copper, as today for hardwood).
   - Clean the 17 already-retired species logs out of the `log` group.
   - **No substitution [D4]:** the previous Draft 5 `lumber` group/Hardwood Board workaround is explicitly rejected. Keep these resources disjoint across crafting, blueprints, inventories, refunds and NPC/workstation sourcing. No permission prompt or fallback mechanic is needed.
   - **Furniture grades [D4]:** finished furniture recipes/blueprints require Hardwood Boards, with fewer for Crude/Rustic and more for Fine/Ornate, plus better nails/fittings at higher grades. Audit 27, 42, 43, 96, 97, 98, 48, 93, 94, 169 and additional furniture rows; Crate 168 may remain an ordinary-Plank utility packing box. Grade-specific additions must be listed before approval.
   - Log length (2.3 item 2): `drops.json log_length_m` 2.44 → 3.0, with log dimensions, segmentation (`max_logs`, `blows_per_log`), `weights.json` log masses and tests.
4. **Tool groups:** add groups `axe` (stone, bronze, iron, steel axes) and `saw` (Iron - Saw, Steel - Saw); extend `knife` with the iron and steel knives. Recipes that keep one specific primitive tool switch to the group, so a better tool works and a disposable one is not required forever: 20, 278, 344 (`stone_knife` → `knife`); 339, 340 (`stone_axe` → `axe`); 159 (`hand_saw` → `saw`). New tool rows carry `tool_class` and `material`, which the code reads; `boulders.json tools.axe` gains iron and steel.
5. **Hand saw recipe 157:** station Smithy (burning), iron and wood, no Saw blade, no workbench level.
6. **Sawmill blueprint 11:** drop `saw_blade` (replacement cost in s5).
7. **Chisels:** drop the chisel from recipe 368 `bench_stone_block` (construction). Recipes 369 and 370 (carved stone block and shingle) keep the `bronze_chisel` group: ornament only.
8. **First charcoal:** before a Kiln exists, the campfire gives charcoal. Keep recipe 341 (2 Firewood → 1 Charcoal at the campfire) until the fire byproduct is built, then retire it if the byproduct covers the wilderness route. Kiln recipe 364 becomes logs → 100 Charcoal each, as a batch.
9. **Charcoal as fuel:** fires burn by `cooking.json fuel` (burn seconds per item) and `fuel_class` (log, firewood, weak), not by an ingredient group. Charcoal gets a `fuel` burn time (longer than Hard firewood) and a `fuel_class` entry. It is **not** added to the `firewood` ingredient group: that would let recipe 341 turn Charcoal into Charcoal. Coal and Charcoal stay in the `fuel` group for smelting. Hard firewood already burns twice as long as Soft firewood (`fuel` 20 vs 10 real minutes).
10. **Stations:**
    - The Smelter, Stone - Forge, Smithy, Leatherworking Table and Loom blueprints use no Planks and no metal beyond what 2.7 names, so the wilderness route and the first Bronze - Axe (which needs a Leather strap) stay open before the first saw. (The Loom matters because Fibre cloth, needed by the pre-saw Feather - Bed and the Fibre - Gambeson, moves to it.)
    - Smithy crafting needs a lit fuel state. Bellows and Quenching Trough are `addon_of` the Smithy, not independent stations; the trough unlocks suitable improved/tempered output at that Smithy.
    - Today the Large and Master forge rows carry station `forge` (levels 3, 4). As the Blast Furnace and Master Smithy they get their own station ids, so the Blast Furnace does not become a bronze workshop. The Smithy keeps `also: {forge: 1}` so it works bronze.
    - The Anvil today raises the Brick - Forge to level 3. With it retired, the steel recipes at `brick_forge` L3 (19, 28, 142, 183, 210–212, 219, 220, 347, 373) and 404 (Iron band) need no level: Steel ingots from the Blast Furnace already gate the steel rows.
    - Every station row gains input and output capacity fields; station inventories join the crafting source order (pack, ground stock, containers; DEVTEST-01 "lowest group member first" stays).
11. **Recipe moves:** 185, 190–192 → Smelter; 193 → Blast Furnace; bronze working at `forge` (204–206, 215, 290–293, 371, 394, 397, 405, 406) stays at the Stone - Forge and the Smithy; iron and steel working at `brick_forge` (18, 19, 27, 28, 141, 142, 145, 149, 183, 184, 188, 207–212, 217–220, 346, 347, 351, 372, 373, 404) → Smithy; leather and clothing rows per 3.4; Loom takes 245, 334, 342. New Bronze - Sickle and Bronze - Scythe recipes go to `forge`.
12. **Furniture [D4]:** blueprint cost changes, renames and the 6 new item, blueprint and structure rows exactly as in s3.5. **Comfort:** `comfort.json` counts each kind once and only the best bed. Graded families must count once per class at their best grade (as beds do), or a player could stack four chair grades for comfort; give each grade a `kinds` row with its points and extend the best-one rule from beds to seats and tables (small code change). Storage slots go on each structure row (`slots`).
13. **Tool tiers:** today's numbers clash across families (Bronze and Iron - Pickaxe both t2; Iron - Spade t3; Steel - Hammer t3 vs Steel - Spade t4; no tier on Wooden spade and hoe). Renumber by material rank in every family (Wooden 1, Stone 2, Bronze 3, Iron 4, Steel 5) and remap `digging.json tier_extra` and blueprint `hammer` values so any metal hammer still builds any tier (decision 73). No saves to migrate.
14. **Names:** an ingredient group is shown under its key item's name, so after the renames a `firewood` cost would read "Hard firewood" and a `wooden_block` cost "Hardwood block" while still taking the softwood kinds. Group costs need a group label ("Firewood", "Wooden block") in the recipe and site lists (`recipe_list.gd`, `inventory_view.gd`, `_site_view`). Dynamic enhanced names are exempt from the `validate_items.gd` four-word check; static names keep it. The renames in 3.2 and 3.3 keep the naming rules.
15. **Tempered [C7]:** a per-instance flag, set only when the player picks the Tempered output at a Smithy with the Quenching Trough attached. **Eligible:** steel tools (Pickaxe, Spade, Hoe, Hammer, Chisel and the new Axe, Knife, Saw, Sickle, Scythe), weapons (Sword, Mace, Shield and every steel weapon in s3.6 except ammunition, which stacks) and armour (Helm, Cuirass and every steel piece in s3.7: Half plate, Plate harness, Gauntlets, Greaves, Sabatons); not the Steel - Striker (a fire-lighting tool), bronze or iron. All are future rows that go live with the Blast Furnace's steel. **Effect:** a higher base maximum durability, set once at crafting; slower sharpness loss only on rows with `edge: true` (Sword, Chisel, Axe, Knife, Saw, Sickle, Scythe, Pickaxe, and the new bladed or pointed steel weapons), never on mace, maul, warhammer, shield, spade, hoe, hammer or any armour. **No multiplication:** a physical craftsmanship durability bonus adds to the tempered base (2.9 item 4), sharpening lowers the current maximum, and repair restores up to it; repair, reheating and sharpening never set or repeat the flag. Not a catalog row; no enhancement slot used. Same save and network path as item 16.
16. **Enhancements:** per-instance save data (like wear and sharpness), no `items.json` rows; saves and network protocol change; enhanced items never stack with plain ones; slot writes refuse an occupied magical slot.
17. **Related rows to update with each retirement or rename:** `weights.json`, `looks.json`, `showroom.json`, `design_names.json`, `descriptions_voice.json`, `encyclopedia.json`, `data/stations/forge_sizes.json`, `data/npcs/town_proposal.json` (names `stone_forge`); tests `test_server_items.gd`, `test_tool_looks.gd`, `test_stations.gd`, `test_lumber_route.gd`, `test_logs_carry.gd`, `test_bloomery_bench.gd`, `test_blueprints.gd`, `test_structure_looks*.gd`, `test_whetstone.gd`; client `basic_look.gd`, `piece_look.gd`, `look_table.gd`; `tools/gen_looks.py` and the icon painters. Run `tools/items_check.py` on the authorized PC after the data change.

## 5. Numbers still to set (tuning, not design)

Durability, repair materials and amounts; sharpening rate and maximum-durability cost per sharpening; grindstone speed; hand-saw time ("much slower" than the sawmill's 6 s per log); kiln burn time and self-consumption rate (Dave: not to be invented now); smelting fuel per ingot on the new 100-per-log charcoal scale (today 1 to 3 `fuel` per smelt); Bellows speed and fuel saving; Quenching Trough upgrade-gated improved metal recipes and quality (no universal bonus); Thread recipe (plant fibre per Thread) and Thread per sewing recipe; all new blueprint costs (Smelter, Smithy, Blast Furnace, Bellows, Quenching Trough, Master Smithy, Grindstone, Leatherworking Table, Tailor's Table, Loom, Chopping Block station) and the Sawmill's cost without a Saw blade; the Stone - Forge cost (live cost stays unless changed; it must stay iron-free); station storage capacities and sourcing radii; hammer sourcing ranges; 3 m log weight; Charcoal stack size (today 20, so one 600-charcoal kiln batch would fill all 30 pack slots) and value (today 3, against a Log's 4 for 100 Charcoal); the campfire charcoal rate of recipe 341 on the same scale; Thread and Hardwood board stack sizes; board and fitting counts, storage slots and comfort points for each furniture grade (s3.5; order fixed, numbers open); Tempered bonuses. Food and storage: Warehouse Desk radius, jar batch size, each passive recipe's `ready_age`, portions per board, container capacities for the new storage rows, and retuning the [D17] initial food-effect values (s3.16). Clothing layers (Phase 4a, M001-T11; `warmth.json layers`): per slot, warmth sorted largest first sums as w1 + 0.6 w2 + 0.36 w3 ... (`layer_keep` 0.6), the slots add up to `max_insulation` 0.85; per-fabric `wet_keep`, `breath` and `rain_shed`, and `heat_effort` 0.5 over `heat_span_c` 10 for overdressing in heat; warmth values of the 4b rows. The item-data and systems roles propose these in the implementation PR, checked by `items_check.py` economy and first-hour tests, and they are tuned in playtest.

## 6. Audit matrix (second pass, 12 Nov 2026)

**Method and limits.** Desk review only: read-only Python scripts over `data/items/*.json`, `data/npcs/*.json`, `data/stations/*.json` and a reading of the dev GDScript named below, on `dev` at `7f8aabf4`. **No Godot test, headless run or `items_check.py` run was performed** (those run only on the authorized PC). "NEEDS CODE TEST" marks behaviour that the data supports but that only a Godot test can prove, or that needs new code.

| # | Check | Paths / ids checked | Expected | Result | Fix or recommendation |
|---|---|---|---|---|---|
| 1 | Number and state uniqueness | 889 items, 404 recipes, 185 blueprints, 216 structures | No duplicate numbers or states; no reuse | PASS | New rows take `next_number` (items 896, recipes 407, blueprints 186, states 230). |
| 2 | Live rows using already-retired items | recipes, blueprints, `repair` lists, groups | None | PASS (17 retired species logs still listed in group `log`, harmless) | Clean the `log` group (s4 item 3). |
| 3 | Unsourced live ingredients | needs, keeps, blueprint costs vs recipe outputs, `gathered.json`, drops, digging, carcass, fishing, nests, shops | Every ingredient obtainable | PASS (Obsidian 281 future; Rotten food from spoilage code) | None. |
| 4 | Live items with no source | all live items | Each item obtainable | PASS (22 dug-up bushes come from the pickaxe in code; dark lanterns, doused torch, log furniture are states) | None. |
| 5 | Stations without a buildable structure | 18 live recipe stations vs structures and live blueprints | Every station buildable | PASS (`campfire` is code-built) | None. |
| 6 | Rows using items this catalog retires | recipes 26, 152, 157, 187, 227, 230, 367; blueprints 11, 164; anvil level on 12 recipes | Each handled | PASS | s3, s4 items 5, 6, 10. |
| 7 | NPC, shop, loot, goal references to retiring items | `data/npcs/*.json`, `drops.json`, `carcass.json`, `nests.json`, `camp_goals.json`, `starter_goals.json`, `hints.json`, `item_uses.json`, `open_recipes.json` | None left orphaned | ISSUE, fixed in doc | Only Hob's 16 species-lumber buy rules; remapped in s4 item 3. `town_proposal.json` names `stone_forge`, which stays. |
| 8 | PR #1036 isolation | PR #1036 diff | Only the Woodworking table rows | PASS | Three one-line `retired` flags (item 243, blueprint 12, structure `woodworking_table`); no live recipe uses station `woodworking_table`; this PR changes no data. |
| 9 | Approved items present | s2 decisions vs `items.json` | Every approved item has a row or an ADD | PASS | 24 ADD rows with name and function: 18 tools and stations (s3.1 to 3.4) and 6 furniture grades (s3.5). Smithy, Blast Furnace, Master Smithy, Loom, Chopping Block and 8 furniture grades reuse existing rows. |
| 10 | Existing structure rows reused | `structures.json` states 7, 18, 20, 21 | Reuse, not duplicate | ISSUE, fixed in doc | The Chopping Block already has state 7 and the forges states 18, 20, 21; s7 item 5 now reuses them instead of adding new states. |
| 11 | Family ladders and tiers | `tier`, `material`, `tool_class` of all tools | Ascending by material in each family | ISSUE, fixed in doc | Bronze and Iron - Pickaxe both t2, Iron - Spade t3 and others; renumber (s4 item 13). Blueprint `hammer: 3` keeps meaning "any metal hammer" (decision 73). |
| 12 | Tool-specific `keeps` | recipes 20, 278, 344, 339, 340, 159 | A better tool of the class works | ISSUE, fixed in doc | Switch to groups `knife`, `axe`, `saw` (s4 item 4). Group `keeps` already work (recipe 384 keeps `knife`). |
| 13 | Material-keyed tool tables | `boulders.json tools`, `drops.json tool_wear.per_use`, `crops.json tool_to_harvest` | New tools covered | ISSUE, fixed in doc | `boulders.json tools.axe` lists only stone and bronze; add iron and steel with the new axes. Code reads `tool_class` and `material`, so new tool rows need no new code. |
| 14 | First hour | hand recipes, campfire, twine, hide garments, plank-free building sets | No Plank or metal needed | PASS | Log, thatch, stone and brick sets; Waterskin and Clay - Pot for water. Hide garments need Thread from plant fibre (hand recipe, s3.4). |
| 15 | Before the first saw | bog iron (`digging.json`, any spade) → Smelter → charcoal (recipe 341) → Iron ingot (192) → Smithy → recipe 157 | Route open with no Planks or purchases | PASS (desk) / NEEDS CODE TEST | Smelter, Stone - Forge, Smithy blueprints must stay Plank-free (s4 item 10). A first-hour test on the PC should walk the route. |
| 16 | Before the first bronze tool | copper and tin ore (`boulders.json ore`, stone pick allowed) → Smelter (190, 191, 185) → Stone - Forge (iron-free) | Bronze before iron | PASS | The Bronze - Axe also needs a Leather strap: see 17. |
| 17 | Before the first Leather strap | hide → Scraper (179) → Tanning rack (logs, twine; tannin bark, water) → Leather (234) → strap (278) | Strap available before bronze | PASS if the Leatherworking Table stays pre-metal and Plank-free | s4 item 10 and s8 risk. |
| 18 | Plank timing | 70 blueprints, recipes 22, 150, 203, 350, 400, Log workbench (L2) | Planks start at the first Iron Hand Saw (approved) | PASS (by design) | The Bucket, Wooden - Shield, Wooden longbow (workbench L2) and plank buildings come after first iron. |
| 19 | Grain before sickles | `crops.json` 5 crops `tool_to_harvest: sickle`; `server_items.gd` farming | Harvest possible without a sickle | PASS | Half yield until the Bronze - Sickle (Stone - Sickle retired). Accepted consequence of the ladder. |
| 20 | Plank and Hardwood Board separation [D4] | `item_table.gd load_groups`, `inventory.gd remove_fill`, `recipe_table.gd`, `server_items.gd` sites, refunds | Never substitute either way | PASS (desk) | Two plain ids with no shared group are matched exactly on every path (recipes, blueprint sites, repairs, refunds, containers). No code is needed; the Draft 6 permission and refund work is withdrawn. Hardwood board must not be added to any group. |
| 21 | Fittings by grade [D5] | groups `nails` (228, 894), `hinges` (232, 895); Wooden pin 233; Iron band 859; Leather 283; Wool cloth 548; s3.5 rows | Grades differ by board and nail counts, finish and seat upholstery; no iron-only nails; no cloth or leather on bare pieces | PASS | Rechecked every s3.5 row: Bronze or iron nails fill every nail cost; upholstery only on chairs and the Fine bench (and the Canopy bed's existing cloth); Iron band only on the Ornate - Chest, which replaces that row's existing Iron ingots. Draft 7's iron-only and Fine-leather rules are removed. |
| 22 | Charcoal as fire fuel | `cooking.json fuel`, `fuel_class`; group `firewood`; recipe 341 | Charcoal burns in fires; no loop | ISSUE, fixed in doc | Draft 5 put Charcoal in the `firewood` group, which fires do not read and which would let recipe 341 make Charcoal from Charcoal. Now `cooking.json` (s4 item 9). |
| 23 | Group display names after renames | `firewood` → "Hard firewood", `wooden_block` → "Hardwood block" | A group cost reads as a group | ISSUE, needs code | Group label in recipe and site lists (s4 item 14). |
| 24 | Inventory overflow | stacks: Charcoal 20, Plank 20, Log 5, species logs 1; pack 30 slots; `recipe_table.gd craft` | Outputs fit; crafting refuses rather than drops | ISSUE (tuning) | `craft` rolls back when the result does not fit. A 600-charcoal kiln batch is 30 stacks: stations keep output (2.5), and the Charcoal stack size and value are retuned (s5). |
| 25 | Enchantment instance and stack semantics | `inventory.gd` slots (number, count, wear, fav), `_mergeable`; `unstackable` on eligible kinds | One instance per slot; enhanced never merges | PASS (eligible kinds) / NEEDS CODE | All 88 live tools, weapons, clothing, gear and containers are single-stack. Per-instance slots, sharpness and current maximum durability need new per-slot save and network data (s4 items 2, 15). |
| 26 | Durability and repair data | `repair`, `repair_station`, `edge` on 54 tools; `drops.json tool_wear` | Matches 2.2 | ISSUE, fixed in doc | Iron - Saw repair is 1 Twine and 1 Stick and has no `repair_station`; stone tools carry `edge`; covered by s4 items 1, 2 and s7 item 2. |
| 27 | Duplicate function and names | ADD names vs live names; two-state objects; renames | No clash | PASS | Five shared names are allowed two-state objects. The 234 rename leaves Large wooden block 540 unrenamed; recommended later rename "Large hardwood block" for a parallel name (needs ChatGPT's nod, as the freeze bars discretionary renames). |
| 28 | Food, medicine, coins | kinds food 116, medicine 5, coin 4 | Item rows change only as approved | PASS / NOTE | No food row is added or removed outside s3.12 to s3.15. Nut cake 51 is UPDATE (tooltip: no Fitness cost). Food recipes and a new `food_group` field change (s7 items 18 and 20). |
| 29 | Comfort stacking with graded furniture | `comfort.json rules.each_kind_once`, `one_bed_counts`, `kinds` | Four chair grades do not add up | ISSUE, needs code (small) | Best-one-per-class rule for seats and tables (s4 item 12). |
| 30 | Wood by biome | `flora.json` trees × `log_*` rows × `wood_species.json` class | Every forested biome can make Planks; boards where hardwood grows | PASS / RISK | Planks wherever trees grow (softwood or plain Log). No Hardwood Boards at all in alpine meadow, beach, dry scrub, hot desert, mangrove, marsh, savanna or volcanic waste; few in heath and grassland. Finished furniture there needs travel or trade (s8). Shelter, storage (Crate, Wicker) and beds stay possible. |
| 31 | Planks in fittings | recipe 150 (1 Plank → 20 Wooden pins) | Crude furniture reachable | PASS | Crude furniture needs a few Planks (for pins) plus boards; both come from the same saw. |
| 32 | Quenching Trough progression | Smelter → Stone - Forge / Smithy → Bellows, Quenching Trough add-ons → Blast Furnace steel | No recipe or quality softlock | PASS (desk) | No plain recipe needs the trough. Tempered applies only to steel, so the trough becomes useful once the Blast Furnace runs. The add-on is a buildable attached structure (`addon_of` the Smithy), not a station. |
| 33 | Early storage ladder | Wicker - Chest 12, Hide - Sack 6, Basket 6, Storage jar 4, Crate 10, Rustic - Chest 20, Ornate - Chest 30 slots | Storage grows with progress | PASS / NOTE | The Crate (10 slots, Planks and nails) holds less than the Wicker - Chest (12, sticks). Unchanged; noted only. |
| 34 | Name rule for grades | decision 71 (a tier word only where several versions exist); four-word check | "Grade - Object" fits | PASS | The grade word replaces the material word, as in "Stone - Axe". No clash with live names; "Fine board" 227 is retired. |
| 35 | Draft 6 claims | s6 rows 20, 21 and the Draft 6 readiness line | Withdrawn where [D4] changes them | DONE | Substitution analysis and its code list withdrawn; the durability-only Quenching Trough effect withdrawn. |
| 36 | Tempered scope | steel rows 34, 47, 224, 294, 321, 322, 323, 330, 331, 561, 800 and the new steel tools; `edge` flags | Only eligible steel; sharpness benefit only on edged rows; no stacking | PASS | Striker excluded; sharpness benefit limited to `edge: true` rows; durability adds, never multiplies (s4 item 15). |
| 37 | Counts and Appendix A | status per row vs s3 tables; Appendix A generator overrides | Totals agree | PASS | KEEP 499, UPDATE 61, RETIRE 23, FUTURE 53, already retired 253 (889); ADD 176 and 4 new FUTURE rows (Draft 18). Every s3 UPDATE, RETIRE and FUTURE row carries the same status in Appendix A. |
| 38 | Weapons category [D6] | 21 weapon rows 7–816, arrows 270, 271, 352, 817; recipes 3, 170–172, 181, 201, 206, 226, 228, 336, 357, 381, 385 | Approved roster matches the data; no duplicates with tool ADDs | PASS / 4 defects recorded | All 21 ids exist (the 9 metal weapons are FUTURE). Iron and Steel Axe and Knife are counted once (s3.1). Defects recorded for implementation: recipe 3 keeps its Stone, Javelin `stack` 5 with `unstackable`, Bronze - Shield needs pre-saw Planks, Steel - Sword description. Recipes 228 and 336 give Wooden - Arrow, not the retired Fibre arrow 354. |
| 39 | Armour category [D7] | 8 core rows, 8 cross-listed clothing rows, recipes 39–42, 194–196, 213–220, 358–360, 397; `clothing.json` slots | Approved roster matches the data; stations and metals in order; layering supported | PASS / NEEDS CODE | Ids, stations and the bronze, iron, steel order hold (s3.7 table). Layering and protection need new code (recommended model in s3.7). Hide - Trousers 306 is ordinary clothing, settled by [D8]. |
| 40 | Clothing category [D8] | 24 kept rows, recipes 39–42, 194–196, 213, 214, 237–244, 358–360 and the hand fibre, straw and snowshoe recipes; `clothing.json`, `warmth.json` | Roster matches data; materials exist; layers and weather supported | PASS / NEEDS CODE | Ids, stations and materials hold (s3.8 table). Neck slot, sock liner, Dress span and per-material weather need code (merged model in s3.8). Oilcloth uses Lamp oil; Tabard uses a cloth group. |
| 41 | Carrying category [D9] | rows 50, 767, 272, 762, 828, 819, 42, 783, 785; recipes 30, 173, 356, 361, 388, 392; `weights.json`, `worn.json`, `inventory.gd`, `carry_bonus_kg` code | Roster matches data; carry, volume and slots consistent with rules 1–3 | PASS / CONFLICT / NEEDS CODE | Ids, stations and materials hold. Backpack `carry_bonus_kg` conflicts with rule 2, and the waist-slot quiver conflicts with rule 1 (recommendations in s3.9). Per-bag contents need new code. |
| 42 | Animal tack category [D10] | `items.json` (no tack rows; Rope, troughs, Fodder trough 841); `animals.json` horse, donkey, buffalo; animal code | Materials and stations exist; animals can be owned, equipped and hitched | PASS / DEPENDENCY | Materials and stations hold. No animal-keeping system exists, and no tameable ox exists, so all 20 rows wait for the separate later phase [D17]. Animal slots and the draft-unit controller are recommended in s3.10. Names: DELEGATED (decision 71). |
| 43 | Vehicle category [D11] | `items.json`, `blueprints.json`, `structures.json` (no vehicle rows; Water wheel 239); Carpenter's bench 86 cost; recipe 150; structure container fields | No clash; no kits; sawing order holds; movable objects supported | PASS / NEEDS CODE | 13 item rows, 10 blueprints, 10 states, no kits. Vehicles come after the first saw. A movable world entity needs new code. Animal vehicles depend on s3.10. Names: DELEGATED (decision 71). |
| 44 | Cooking category [D12] | 116 `food` rows; live food recipes; cook-station blueprints; `addon_of` structures | Targets exist; routes valid; no forced iron gate; no pack-only food preparation | PASS / CONFLICT | Ids and targets hold. Energy bar, Fruit juice and Butter are made by hand (they conflict with rule 2). A board-built Table would gate bread behind the saw; a log-built Table avoids that. Attachments are kept equipment (s3.12); only the Crane needs attach code. |
| 45 | Storage category [D13] | 16 baseline container rows in `structures.json`; Sign 791; `who` field and `validate_items.gd`; s3.5 chest grades | Capacities match; no duplicate of graded chests; locks and moving crates supported | PASS / OVERLAP / DEPENDENCY / NEEDS CODE | Capacities match exactly. The Large Wooden Chest is distinct by weight capacity and footprint within 30 slots [D17]. Locks need the ownership system (`who` only "anyone" today). Moving loaded crates shares the [D9]/[D11] container and movable-entity work. |
| 46 | Serving boards [D15] and food effects [D16] | Roast meat 69, Rosemary joint 275, Roast beast 191, Cheese 418 and Pickled vegetables 834 (both FUTURE); `fitness.json` training; `comfort.json` Rested tiers | Board sources exist; XP rule fits the training code; no stacking with existing buffs | PASS / NOTE | Every current board has live ingredients; Ploughman's waits on FUTURE rows. Fitness XP is earned every 10 s into `xp_today` and paid at midnight, so multiplying at the tick matches [D16]. **Rested** (`comfort.json`) has `skill_gain_mult` 1.00 to 1.10 for skill practice only, as one record with a refresh-not-stack rule. The three group slots ([D16]) are new state, not a reuse of that record. How food and Rested XP combine is in the s3.16 combination rules. [D17] removes the permanent Fitness cost of `vitals.json energy_aids` (Nut cake, Herbal tea, Nettle tea, Magic tonic); Nut cake's tooltip changes (UPDATE). |

## 7. JSON change list (none made; all wait for Dave's approval of this catalog; order and agents in `CATALOG_IMPLEMENTATION_PLAN.md`)

1. **Retire:** items 45, 238, 298, 353, 795, 827 and the 16 species `lumber_*` and `beam_*` rows; recipes 26, 152, 187, 227, 230, 367; blueprints 162 and 164 become `hidden` (not buildable, still used for take-down refunds; `CATALOG_SAVE_MIGRATION.md` rule 6); structures `clay_bloomery` (state 200) and `iron_anvil` (state 204) stay loadable. Each retirement lands in the phase that delivers its replacement. Woodworking table rows: PR #1036.
2. **Durability:** stone, wooden and primitive tools and weapons (6, 11, 222, 244, 297, 19, 221, 247, 293, 7, 313, 295) and the Bone - Needle 49 lose `repair`; stone tools lose `edge`. Metal tools: `repair_station` per crafting station, `edge` on sharpening-eligible metal tools. `drops.json`: replace `tool_wear.repair_restores` and `tool_wear.hone`.
3. **Wood:** recipes 16 and 159 to 6 Planks; Hardwood board item and its sawmill and hand-saw recipes (in no group); `hand_saw_balance`; renames of 234, 26, 236; recipe 157 to the Smithy with no Saw blade; blueprint 11 without the Saw blade; `wood_species.json` default class, `retired_to` and `log` group; Hob's buy rules; `log_length_m` 3.0 with weights.
4. **Charcoal:** kiln recipe 364 to logs → 100 Charcoal each, batch; Charcoal in `cooking.json fuel` and `fuel_class` (not the `firewood` group); Charcoal stack size and value rescaled (s5).
5. **Stations:** new independent production stations: Smelter, Grindstone, Leatherworking Table, Tailor's Table, Loom; Chopping Block reuses structure state 7 and gains its station identity. **Bellows and Quenching Trough are Smithy add-on item/blueprint/structure entries, not independent crafting stations.** Rename and re-cost Smithy #90, Blast Furnace #93, Master Smithy #95; preserve their existing structure states; station inventories on actual production stations.
6. **Tools:** add the 10 ladder tools with recipes; groups `axe`, `saw`, extended `knife`; recipes 20, 278, 344, 339, 340, 159 to the groups; tier renumbering.
7. **Recipes:** station moves (s4 item 11); anvil level dropped from the 12 steel and Iron band recipes; chisel off recipe 368.
8. **Textiles:** Thread item and hand recipe; Twine → Thread in recipes 23, 39–42, 173, 194–196, 237, 238, 241, 388.
9. **Enhancements:** per-instance slot data and the eligibility in 2.9 (code and save format, no item rows).
10. **Furniture (s3.5):** 14 blueprint cost changes and 8 renames; 6 new item, blueprint and structure rows; `comfort.json` grade kinds and the best-one rule; `slots` per chest grade; looks.
11. **Tempered [C7]:** confirmed per-instance steel quality, not duplicate item rows; Quenching Trough must be a Smithy add-on (s4 item 15).
12. **Weapons [D6] (s3.6):** renames of 269 and 763; 29 new item rows with recipes (bronze at `forge`, iron and steel at the Smithy, wooden at hand or workbench); FUTURE rows for Steel bolt and Iron - Lance; fix recipe 3 (consume the Stone), Javelin 295 `stack` 1, Bronze - Shield recipe 206 without Planks, Steel - Sword 321 description; a stack-level poison state on arrows (no new rows; the poison preparation itself is a later content item, plan phase 12).
13. **Armour [D7] (s3.7):** 14 new item rows with recipes at the stations in rule 4; Steel - Cuirass 331 description; protection values and damage modes (new combat system).
14. **Clothing [D8] (s3.8):** 17 new item rows with recipes at the Tailor's Table, Leatherworking Table or by hand; a `wear_layer` field on every clothing and armour row and the merged layer model (new neck slot, sock liner, Dress span, old-save mapping); per-material weather fields; a Linen-keyed cloth group for the Tabard.
15. **Carrying [D9] (s3.9):** 9 new item rows with `worn.json` rows; retire `carry_bonus_kg` once pack volume exists; per-bag contents in pack, save and network; `shoulder` and chest-strap slots, belt attachment points and the quiver slot; quiver descriptions.
16. **Animal tack [D10] (s3.10):** 20 new item rows, plus Riding - Boots when live; animal equipment slots; per-animal cargo through the [D9] container inventory; the draft-unit controller (1 or 2 animals). This depends on an animal-keeping system that is not yet designed.
17. **Vehicles [D11] (s3.11):** 13 new item rows (10 vehicles of kind `structure`, 3 `material` parts); 10 blueprints and 10 structure states, with no kit items; wheel and axle recipes at the Carpenter's bench; a persistent movable vehicle entity with one controller, cargo and passengers.
18. **Cooking [D12] (s3.12):** 23 new item rows (7 equipment, 16 prepared foods); the Food Preparation Table blueprint and structure state; the five attachments as kept equipment used at `campfire`, `campfire_pot` or `clay_hearth`, with attach code only for the Fireplace Cooking Crane; recipes reworked into prepare then cook for the 16 targets (generated dishes through `dishes.json`). DELEGATED defaults: the log-and-twine Table blueprint; the Herb omelette and Egg-nettle fry moved to the Clay Griddle or Iron Frying Pan; Nut cake and Fruit juice moved to the Table; Uncooked Meatballs live together with Meatballs #837.
19. **Storage [D13] (s3.13):** 16 new item rows with blueprints and structure states; container `slots`, `max_kg` and fill looks; locks through `who` once ownership lands, with the locked-crate movement and sourcing rule; `place_mult` rows for every new container and for cargo; loaded crates as movable containers; protocol and save-format additions; Storage sign and Warehouse desk as views over nearby containers, with no new backend.
20. **Serving boards [D15] and food effects [D16] (s3.15, s3.16):** 8 board rows, Ploughman's board (FUTURE) and the Serving Platter; board recipes at the Food Preparation Table; a placed-board structure that keeps portions and age per stack; a per-food effect profile and tier read by the earned-XP hook at each tick, with three group slots (one per food group, independent timers; the same group replaces, a fourth group asks which to replace) and a `food_group` and effect profile for every food row, kept in `dishes.json` or a separate data file keyed by item id (not hand edits to generated rows); the [D17] initial values (s3.16). See `FOOD_STORAGE_AUDIT_2026-11-12.md`.
21. **Preservation [D14, D17] (s3.14):** 2 new item rows (Smoked Meat at the Smoker; Dried Mushrooms at the Drying Rack, one recipe per fresh mushroom, outside the `mushrooms` group, plus a dried-mushroom skewer recipe); shelf lives for Mushrooms 551 and Puffball; the `wear`-cap validation; a `ready_age` on the Sauerkraut and Pickled Vegetables recipes at #830 and a batch size; recipes 102, 283, 285 and 287 moved to the Campfire Pot; the no-merge-across-`ready_age` rule.
22. **Energy aids and drinks [D17]:** `vitals.json energy_aids` loses the `fitness` cost (and `fitness_max_loss`); energy aids and medicinal teas are no longer refused when rested or healthy, and give instant energy only when their slot is newly filled or expired; Nut cake 51 tooltip without "wears on your fitness" and its `energy_aids` energy set to 12 (Dessert tier 2); teas and Fruit juice get the Beverage group.
23. **Saves:** the one-time migration in `CATALOG_SAVE_MIGRATION.md`.

## 8. Remaining issues and readiness

**Owner design questions open: none.** [D17] closed the last seven. The earlier Draft 7 points are settled [C7], and Dave's [D5] material rule is applied throughout.

**Completed design (owner or delegated owner decision):** every s3 roster, count, station route and rule tagged [D#] or [C]. **Delegated technical details:** every row marked DELEGATED; the implementing agent follows the stated default and records any change in its PR.

**Actual blockers to implementation:** none in the design. Implementation needs Dave's approval of this catalog and his separate go for each phase (Godot tests run only on his PC). Known risks, all planned for in `CATALOG_IMPLEMENTATION_PLAN.md`:
- **Contracts:** per-instance slot data, three food slots, container locks and codes, loaded movable containers, vehicles and portions need `PROTOCOL.md` and save-format bumps (the wire pack is 8 bytes per slot today).
- **Save safety:** `CATALOG_SAVE_MIGRATION.md`. One silent-loss path exists today (a worn item whose slot changes is blanked), so the clothing change must ship with its pre-pass.
- **Small code changes:** the best-one-per-class comfort rule for graded seats and tables (s6 row 29); group labels for the renamed `firewood` and `wooden_block` keys (row 23).
- **Animal keeping** is its own later phase [D17]; the 20 tack rows and the 9 animal vehicles go live with it (only the Handcart before).
- **Later trade decision:** furniture in the eight hardwood-free biomes depends on travel or on a trader selling Hardwood Boards (s6 row 30).
- **Baseline:** recheck against the latest `dev` before implementation (compared at `7f8aabf4`); PR #1036 stays separate.

**Readiness.** Every category is owner-approved: tools, wood and stations, furniture [D4, D5, C7], weapons [D6], armour [D7], clothing [D8], carrying [D9], tack [D10], vehicles [D11], cooking [D12], storage [D13], preservation [D14, D17], boards [D15] and food effects [D16, D17]. The complete catalog is submitted for Dave's final approval. Companion documents ([STORAGE_WAREHOUSING_DESIGN.md](STORAGE_WAREHOUSING_DESIGN.md), [FOOD_PREPARATION_PRESERVATION_SERVING.md](FOOD_PREPARATION_PRESERVATION_SERVING.md)) explain behaviour and tests; the final audit is [CATALOG_FINAL_AUDIT_2026-11-12.md](CATALOG_FINAL_AUDIT_2026-11-12.md). This master remains the source of truth for approval and item IDs. **Do not merge or implement until Dave explicitly approves the completed full catalog.**

## Appendix A. Full catalog of existing items (generated from `data/items/items.json`)

Generated from dev `7f8aabf4`. 889 rows; next free item number 896. Status counts: FUTURE 53, KEEP 499, RETIRE 23, RETIRED 253, UPDATE 61.
`RETIRED` = already retired before this document (kept only for its number). `Made at` is the station of the first live recipe that gives the item (`hand` = no station; L = station level); blank = not crafted (gathered, dropped, built from a blueprint, or a group placeholder). Purpose is the live tooltip description. Gathered wild items (`gathered.json`, numbers 1000+) are outside this catalog.

### A.tool (54 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 6 | `stone_axe` | Stone - Axe | stone t1 | hand | UPDATE | **APPROVED: disposable (s2.2).** A stone bound to a handle. Fells trees, breaks rock and works wood. |
| 11 | `stone_knife` | Stone - Knife | t1 | hand | UPDATE | **APPROVED: disposable (s2.2).** A flaked stone on a handle. Dresses a kill and cuts bark. |
| 12 | `torch` | Torch | t1 | hand | KEEP | A stick wrapped in fibre and dipped in pitch. Lights your way after dark. |
| 19 | `wooden_spade` | Wooden - Spade |  | hand | UPDATE | **DECIDED: disposable (s2.2).** A sharpened wooden blade. Digs roots and bulbs. |
| 33 | `iron_pickaxe` | Iron - Pickaxe | iron t2 | brick_forge L2 | UPDATE | **APPROVED: metal break/repair rule (s2.2).** An iron head on a hardwood handle. One blow breaks one stone off a boulder. |
| 34 | `steel_pickaxe` | Steel - Pickaxe | steel t3 | brick_forge L3 | FUTURE | **APPROVED: metal break/repair rule (s2.2) when live.** A steel head on a hardwood handle. One blow breaks one stone off a boulder, and it lasts longest. |
| 45 | `stone_spade` | Stone - Spade | stone t2 | workbench | RETIRE | **APPROVED: retired (s3.1).** A spade with a stone blade. Digs deeper and lasts longer than wood. |
| 46 | `iron_spade` | Iron - Spade | iron t3 | brick_forge L2 | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A spade with an iron blade. |
| 47 | `steel_spade` | Steel - Spade | steel t4 | brick_forge L3 | FUTURE | **APPROVED: metal break/repair rule (s2.2) when live.** A spade with a steel blade. |
| 49 | `sewing_needle` | Bone - Needle |  | hand | UPDATE | **DECIDED: the one reusable needle; replaced, not repaired (s2.2).** A needle carved from bone. For sewing hide and cloth. |
| 75 | `fishing_rod` | Fishing rod |  | hand | KEEP | A stick, line and hook. Cast at water, then click again when something bites. |
| 221 | `wooden_hoe` | Wooden - Hoe |  | hand | UPDATE | **DECIDED: disposable (s2.2).** A flat blade on a long handle. Paths the ground and tills beds. |
| 222 | `stone_hoe` | Stone - Hoe | stone t2 | workbench | UPDATE | **APPROVED: disposable (s2.2).** A hoe with a stone blade. Lasts longer than wood. |
| 223 | `iron_hoe` | Iron - Hoe | iron t3 | brick_forge L2 | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A hoe with an iron blade. |
| 224 | `steel_hoe` | Steel - Hoe | steel t4 | brick_forge L3 | FUTURE | **APPROVED: metal break/repair rule (s2.2) when live.** A hoe with a steel blade. |
| 244 | `stone_hammer` | Stone - Hammer | stone t2 | hand | UPDATE | **APPROVED: disposable (s2.2).** A hafted stone hammer. Hold it to place big builds from blueprints. |
| 245 | `hand_saw` | Iron - Saw | iron t3 | workbench L2 | UPDATE | **APPROVED: Smithy recipe, sawmill yields (s3.1).** A bow saw. Keep it on the hotbar to saw a log into 2 planks by hand, slower than a mill. |
| 247 | `wooden_hammer` | Wooden - Hammer | wood t1 | hand | UPDATE | **DECIDED: disposable (s2.2).** A wooden head on a stick. The weakest hammer; it wears out fast. |
| 260 | `shore_net` | Fishing net |  | hand | KEEP | A weighted twine net. Throw it on water, pull it back; a bigger school fills it more. |
| 293 | `hide_scraper` | Scraper | t1 | workbench | UPDATE | **DECIDED: disposable (s2.2).** A flint blade on a handle. Scrapes flesh and hair off a raw hide. |
| 294 | `steel_striker` | Steel - Striker | t4 | brick_forge L3 | FUTURE | A strip of hard steel. Strike flint on it for a shower of sparks. |
| 296 | `obsidian_knife` | Obsidian - Knife | obsidian t2 | workbench | FUTURE | A razor-sharp black glass blade. Cuts better than flint, but chips more easily. |
| 297 | `stone_pickaxe` | Stone - Pickaxe | stone t2 | hand | UPDATE | **APPROVED: disposable (s2.2).** A heavy stone head on a haft. Breaks boulders and ore, slowly. |
| 298 | `sickle` | Stone - Sickle | stone t1 | workbench | RETIRE | **APPROVED: Stone Sickle retired (s2.1).** A curved flint blade on a short handle. Cuts grain and grass by the handful. |
| 299 | `scythe` | Iron - Scythe | iron t3 | brick_forge L2 | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A long curved blade on a tall handle. Mows grass, thatch and grain in wide sweeps. |
| 311 | `candle` | Candle | t1 | hand | KEEP | A wick dipped in tallow. A small steady light, and what a wooden lantern burns. |
| 344 | `quern` | Hand mill |  | hand | KEEP | Two flat stones for grinding grain by hand. Slow but steady. |
| 353 | `stone_wedge` | Stone - Wedge |  | hand | RETIRE | **APPROVED: no wedges (s2.3).** A flaked stone wedge. Driven into a log at a workbench, it splits two planks. |
| 458 | `bronze_pickaxe` | Bronze - Pickaxe | bronze t2 | forge | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A bronze head on a hardwood handle. Breaks rock quickly and takes iron ore out of a boulder. |
| 459 | `bronze_axe` | Bronze - Axe | bronze t2 | forge | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A bronze blade on a hardwood handle. Fells trees faster and lasts longer than stone. |
| 460 | `bronze_hammer` | Bronze - Hammer | bronze t3 | forge | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A cast bronze head on a short haft. Hold it to place big builds from blueprints. |
| 461 | `bronze_knife` | Bronze - Knife | bronze t2 | forge | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A bronze blade on a bone grip. Dresses a kill cleanly and cuts bark. |
| 542 | `torch_doused` | Torch | t1 |  | KEEP | A stick wrapped in fibre. Lights your way after dark. |
| 557 | `spyglass` | Wooden - Spyglass | t1 | workbench L3 | KEEP | A wooden tube with a crystal lens. Hold it and right-click to see three times closer. |
| 560 | `iron_hammer` | Iron - Hammer | iron t3 | brick_forge L2 | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A forged iron head on a short haft. Hold it to place big builds from blueprints. |
| 561 | `steel_hammer` | Steel - Hammer | steel t3 | brick_forge L3 | FUTURE | **APPROVED: metal break/repair rule (s2.2) when live.** A forged steel head on a short haft. Hold it to place big builds from blueprints. |
| 668 | `wooden_lantern` | Wooden - Lantern |  | workbench L1 | KEEP | A plank lantern with horn panes. Takes a candle; does not go out in the rain. |
| 669 | `iron_lantern` | Iron - Lantern |  | brick_forge L2 | KEEP | An iron lantern with horn panes. Burns lamp oil; does not go out in the rain. |
| 798 | `bronze_chisel` | Bronze - Chisel | bronze t2 | forge | UPDATE | **APPROVED: metal break/repair rule (s2.2).** A solid cast bronze chisel. Squares and carves stone at a stonecutter's bench. |
| 799 | `iron_chisel` | Iron - Chisel | iron t3 | brick_forge L2 | UPDATE | **APPROVED: metal break/repair rule (s2.2).** An iron chisel. Keeps its edge on stone far longer than bronze. |
| 800 | `steel_chisel` | Steel - Chisel | steel t4 | brick_forge L3 | FUTURE | **APPROVED: metal break/repair rule (s2.2) when live.** A steel chisel. Cuts the hardest stone cleanly. |
| 807 | `mortar_pestle` | Mortar and pestle |  | hand | KEEP | A hollowed stone and a round grinder for crushing herbs into poultices and cures. |
| 815 | `whetstone` | Whetstone |  | hand | UPDATE | **APPROVED: portable sharpening (s2.2).** A fine flat stone for honing an edge. Brings a worn blade back without new parts. |
| 892 | `wooden_lantern_dark` | Wooden - Lantern |  |  | KEEP | A lantern gone out. Press its key to light it, with a candle in your pack if it burned out. |
| 893 | `iron_lantern_dark` | Iron - Lantern |  |  | KEEP | A lantern gone out. Press its key to light it, with lamp oil in your pack if it burned out. |

Already retired (9; numbers never reused): 213 `wooden_spade_medium` Medium wooden spade; 214 `wooden_spade_large` Large wooden spade; 215 `stone_spade_medium` Medium stone spade; 216 `stone_spade_large` Large stone spade; 217 `iron_spade_medium` Medium iron spade; 218 `iron_spade_large` Large iron spade; 219 `steel_spade_medium` Medium steel spade; 220 `steel_spade_large` Large steel spade; 246 `stone_adze` Stone adze.

### A.weapon (21 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 7 | `spear` | Stone - Spear | t2 | hand | UPDATE | **DECIDED: disposable; [D6]: recipe 3 consumes its Stone (s3.6).** A stone point on a long shaft. Jab with it or throw it; it kills a rabbit in one blow. |
| 10 | `wooden_spear` | Wooden - Spear | t1 | hand | KEEP | A sharpened stick. Jab with it or throw it. |
| 269 | `wooden_bow` | Wooden - Bow | t1 | workbench | UPDATE | **APPROVED [D6]: rename Shortbow (s3.6).** A bow of bent wood and twine. Needs arrows. |
| 295 | `javelin` | Javelin | t2 | workbench | UPDATE | **DECIDED: disposable, recoverable; [D6]: stack 1 (s3.6).** A light, balanced throwing spear. Flies farther and straighter than a plain spear. |
| 300 | `wooden_club` | Wooden - Club | t1 | hand | KEEP | A stout length of hardwood, heavy at one end. Hits hard and needs no skill. |
| 312 | `wicker_shield` | Wicker - Shield | t1 | hand | KEEP | Sticks woven tight with fibre. Light, and good for a few hits. |
| 313 | `stone_mace` | Stone - Mace | t2 | hand | UPDATE | **DECIDED: disposable (s2.2).** A heavy stone lashed to a stick. Cracks armour and bone. |
| 314 | `plank_shield` | Wooden - Shield | t2 | workbench L2 | KEEP | Boards bound with hide. Sturdier than wicker. |
| 315 | `bronze_sword` | Bronze - Sword | t3 | forge | FUTURE | A bronze blade on a short grip. Quick and sharp. |
| 316 | `bronze_mace` | Bronze - Mace | t3 | forge | FUTURE | A cast bronze head on a stout haft. |
| 317 | `bronze_shield` | Bronze - Shield | t3 | forge | FUTURE | **APPROVED [D6]: rework without pre-saw Planks (s3.6).** A plank shield with a bronze rim and boss. |
| 318 | `iron_sword` | Iron - Sword | t4 | brick_forge L2 | FUTURE | A forged iron blade with a leather grip. |
| 319 | `iron_mace` | Iron - Mace | t4 | brick_forge L2 | FUTURE | A flanged iron head that breaks armour. |
| 320 | `iron_shield` | Iron - Shield | t4 | brick_forge L2 | FUTURE | Boards held by iron bands. Hard to break. |
| 321 | `steel_sword` | Steel - Sword | t5 | brick_forge L3 | FUTURE | **APPROVED [D6]: description must not say tempered (s3.6).** A tempered steel blade. Keeps its edge. |
| 322 | `steel_mace` | Steel - Mace | t5 | brick_forge L3 | FUTURE | A steel flanged head on a long haft. |
| 323 | `steel_shield` | Steel - Shield | t5 | brick_forge L3 | FUTURE | A long steel-faced shield that covers shoulder to shin. |
| 761 | `bone_club` | Bone - Club | t1 | hand | KEEP | A heavy leg bone bound with twine at the grip. Hits harder than wood and lasts longer. |
| 763 | `wooden_longbow` | Wooden - Longbow | t2 | workbench L2 | UPDATE | **APPROVED [D6]: rename Longbow (s3.6).** A tall bow cut from one stave of hardwood and strung with sinew. Needs arrows. |
| 813 | `sling` | Sling | t1 | hand | KEEP | A hide pouch on two cords. Whirl it and let go to throw a stone fast and far. |
| 816 | `fishing_spear` | Fishing spear | t1 | hand | KEEP | A long stick split and sharpened into barbed prongs. Stab fish in the shallows. |

### A.material (245 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 1 | `stone` | Stone |  |  | KEEP | A fist-sized stone. Pick it up from the ground, or break it off a boulder. |
| 2 | `stick` | Stick |  |  | KEEP | A fallen branch. Burns, and makes handles, frames and fences. |
| 3 | `plant_fibre` | Plant fibre |  |  | KEEP | Stringy strands from nettles and grass. Twist 3 into twine, or use one to light a fire. |
| 4 | `log` | Log |  |  | KEEP | **APPROVED: basic Log gives Planks; softwood class (s4.3).** A heavy length of trunk. Split it for firewood, or wedge it into planks. |
| 5 | `twine` | Twine |  | hand | KEEP | **binding cord; sewing recipes switch to Thread (s3.4).** Twisted fibre cord. Binds tools, frames and kits. |
| 9 | `seed_bundle` | Wild grain |  |  | KEEP | A bundle of seeds. Eat them, or plant them. |
| 13 | `bark` | Bark |  |  | KEEP | Bark stripped from a felled trunk. |
| 14 | `leaves` | Leaves |  |  | KEEP | A handful of green leaves from a felled tree. Roofs a shelter. |
| 18 | `tree_roots` | Roots |  |  | KEEP | Roots from the base of a felled tree. |
| 26 | `firewood` | Firewood |  |  | UPDATE | **ENGINEERING: rename Hard firewood (s3.2).** Split wood. Burns long and steady. |
| 27 | `lumber` | Plank |  | saw_mill | UPDATE | **APPROVED: 6 per softwood log (s2.3).** Boards from a log. Make them at a saw mill, or wedge them at a workbench. |
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
| 101 | `lumber_oak` | Oak lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn oak boards. |
| 102 | `beam_oak` | Oak beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared oak beams for building. |
| 103 | `log_beech` | Beech log |  |  | KEEP | A full-size beech log. Too big for the pack: carried alone on the shoulder. |
| 104 | `lumber_beech` | Beech lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn beech boards. |
| 105 | `beam_beech` | Beech beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared beech beams for building. |
| 106 | `log_birch` | Birch log |  |  | KEEP | A full-size birch log. Too big for the pack: carried alone on the shoulder. |
| 107 | `lumber_birch` | Birch lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn birch boards. |
| 108 | `beam_birch` | Birch beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared birch beams for building. |
| 109 | `log_scots_pine` | Scots pine log |  |  | KEEP | A full-size scots pine log. Too big for the pack: carried alone on the shoulder. |
| 110 | `lumber_scots_pine` | Scots pine lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn scots pine boards. |
| 111 | `beam_scots_pine` | Scots pine beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared scots pine beams for building. |
| 112 | `log_spruce` | Spruce log |  |  | KEEP | A full-size spruce log. Too big for the pack: carried alone on the shoulder. |
| 113 | `lumber_spruce` | Spruce lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn spruce boards. |
| 114 | `beam_spruce` | Spruce beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared spruce beams for building. |
| 124 | `log_tropical_hardwood` | Mahogany log |  |  | KEEP | A full-size mahogany log. Too big for the pack: carried alone on the shoulder. |
| 125 | `lumber_tropical_hardwood` | Mahogany lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn mahogany boards. |
| 126 | `beam_tropical_hardwood` | Mahogany beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared mahogany beams for building. |
| 148 | `log_walnut` | Walnut log |  |  | KEEP | A full-size walnut log. Too big for the pack: carried alone on the shoulder. |
| 149 | `lumber_walnut` | Walnut lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn walnut boards. |
| 150 | `beam_walnut` | Walnut beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared walnut beams for building. |
| 172 | `log_maple` | Sugar maple log |  |  | KEEP | A full-size sugar maple log. Too big for the pack: carried alone on the shoulder. |
| 173 | `lumber_maple` | Sugar maple lumber |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Sawn sugar maple boards. |
| 174 | `beam_maple` | Sugar maple beam |  |  | RETIRE | **DECIDED: superseded by Plank and Hardwood board (s3.2).** Heavy squared sugar maple beams for building. |
| 208 | `cut_stone_block` | Stone block |  | workbench L1 | KEEP | A squared block of stone, 40 by 20 by 20 cm. Heavy, and laid in courses with mortar. |
| 209 | `brick` | Brick |  | campfire | KEEP | A fired clay brick. Builds the clay hearth and the oven. |
| 210 | `mortar` | Clay mortar |  | hand | KEEP | A bucketful of sand and clay paste that binds stone blocks and bricks. |
| 228 | `nails` | Nails | iron | brick_forge L2 | KEEP | Small iron nails. Fix boards in builds; bronze ones do the same job. |
| 229 | `cobblestone` | Cobblestone |  | workbench L1 | KEEP | A rounded stone, dressed to lay in a wall or a floor. |
| 230 | `stone_shingle` | Stone shingle |  | workbench L1 | KEEP | A thin flat slab of stone for a roof. |
| 231 | `tar` | Tar |  | campfire | KEEP | Thick black tar, boiled down. Seals a flat roof and soaks logs against rot. |
| 232 | `hinges` | Hinges | iron | brick_forge L2 | KEEP | A pair of iron hinges for a door, a gate or a lid. |
| 233 | `wooden_pin` | Wooden pin |  | workbench L1 | KEEP | A hardwood pin or dowel that joins logs and beams without iron. |
| 234 | `wooden_block` | Wooden block |  | hand | UPDATE | **ENGINEERING: rename Hardwood block (s3.2).** A short round of a small log, bark still on. Burns longer than firewood, or split it on a chopping block. |
| 236 | `firewood_soft` | Softwood firewood |  |  | UPDATE | **ENGINEERING: rename Soft firewood (s3.2).** Split pine, spruce or fir. It catches fast and burns out quick. |
| 237 | `wooden_block_soft` | Softwood block |  | hand | KEEP | A short round of a small softwood log. Burns longer than soft firewood, or split it on a chopping block. |
| 238 | `saw_blade` | Saw blade |  | brick_forge L2 | RETIRE | **APPROVED: no saw-blade intermediates (s2.3).** A pair of iron saw blades for a sawmill frame. |
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
| 304 | `coal` | Coal |  |  | KEEP | **APPROVED: distinct from Charcoal.** A black lump that burns hot. Smelts iron and makes steel. |
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
| 415 | `leather_strap` | Leather strap |  | workbench | KEEP | **made at the Leatherworking Table (s3.4).** A strip of leather for straps, belts and harness. |
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
| 540 | `wooden_block_large` | Large wooden block |  |  | KEEP | **larger blocks (s3.2).** A thick round of a big trunk. Split it into firewood or 4 small blocks, or make a chopping block of it. |
| 541 | `wooden_block_soft_large` | Large softwood block |  |  | KEEP | **larger blocks (s3.2).** A thick round of a big softwood trunk. Split it into soft firewood or 4 small blocks, or a chopping block. |
| 547 | `charcoal` | Charcoal |  | campfire | UPDATE | **APPROVED: 100 per log at the kiln; fuel (s2.6).** Firewood burned slow and starved of air. The best smelting fuel. |
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
| 331 | `plate_cuirass` | Steel - Cuirass |  | brick_forge L3 | FUTURE | **APPROVED [D7]: description must not say best (s3.7).** Shaped steel plates over a leather harness. The best body armour. |
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
| 50 | `backpack` | Hide - Backpack |  | hand | UPDATE | **APPROVED [D9]: pack volume replaces carry_bonus_kg (s3.9).** A hide pack with straps. Worn on the back, it lets you carry more. **Note (13 Nov 2026, coordinator ruling for Dave's confirmation): `carry_bonus_kg` restored (12, 18) by BUGLIST-001 DESIGN-001; see docs/ai-team/missions/BUGLIST-001/backpack.md.** **Note (13 Nov 2026, Dave): "Backpacks do not have slots. The only thing they do is give you more carry weight." Rows 50 and 767 have no `bag_slots`/`bag_takes` and hold nothing; `carry_bonus_kg` 12 and 18 is all they do. This supersedes the backpack-as-container reading of rules 1-3 and the volume wording of this row for those two rows only; every other bag in s3.9 keeps its slots. See docs/ai-team/missions/BUGLIST-001/backpack.md (Follow-up 13 Nov 2026).** |
| 272 | `quiver` | Hide - Quiver |  | hand | UPDATE | **APPROVED [D9]: belt attachment, not the waist slot; description (s3.9).** A hide tube worn on the back. Holds 40 arrows. |
| 762 | `leather_quiver` | Leather - Quiver |  | workbench L2 | UPDATE | **APPROVED [D9]: belt attachment, not the waist slot; description (s3.9).** A stiff leather tube worn on the back. Holds 60 arrows and keeps them dry. |
| 767 | `leather_backpack` | Leather - Backpack |  | workbench L3 | UPDATE | **APPROVED [D9]: pack volume replaces carry_bonus_kg (s3.9).** A leather pack with a frame of straps. Worn on the back, it carries more than a hide pack. **Note (13 Nov 2026, coordinator ruling for Dave's confirmation): `carry_bonus_kg` restored (12, 18) by BUGLIST-001 DESIGN-001; see docs/ai-team/missions/BUGLIST-001/backpack.md.** **Note (13 Nov 2026, Dave): "Backpacks do not have slots. The only thing they do is give you more carry weight." Rows 50 and 767 have no `bag_slots`/`bag_takes` and hold nothing; `carry_bonus_kg` 12 and 18 is all they do. This supersedes the backpack-as-container reading of rules 1-3 and the volume wording of this row for those two rows only; every other bag in s3.9 keeps its slots. See docs/ai-team/missions/BUGLIST-001/backpack.md (Follow-up 13 Nov 2026).** |
| 819 | `bedroll` | Bedroll |  | hand | KEEP | Hides sewn into a roll to sleep on. Better rest in the open, but it is not a bed. |
| 828 | `leather_belt` | Leather - Belt |  | workbench L2 | KEEP | A leather belt with a toggle. Hangs a pouch, a knife or a quiver at the waist. |

### A.container (7 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 39 | `wooden_bowl` | Wooden bowl |  | hand | KEEP | A bowl hollowed from a bolt of wood. Carries a little water. |
| 40 | `clay_pot` | Clay - Pot |  | campfire | KEEP | A fired pot of clay. Holds three litres of water. |
| 41 | `bucket` | Bucket |  | hand | KEEP | **needs Planks, so comes after the first Iron Hand Saw (s6).** A wooden bucket bound with cord. Holds eight litres of water. |
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
| 51 | `energy_bar` | Nut cake |  | hand | UPDATE | Nuts pressed with honey into a cake. Quick energy that wears on your fitness. |
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
| 25 | `chopping_block` | Chopping block |  | hand | UPDATE | **APPROVED: firewood workstation (s2.4).** A log set on end. Split wooden blocks into firewood on it. |
| 92 | `large_forge_kit` | Large forge |  |  | FUTURE | **kit row stays unused; numbers kept.** A big arched forge with a riveted iron frame, ready to raise. |
| 94 | `master_forge_kit` | Master forge |  |  | FUTURE | **kit row stays unused; numbers kept.** An ornate black iron and gold forge set with red gems, ready to raise. |
| 235 | `rock_pile` | Rock pile |  | hand | KEEP | A heap of 45 stones. Set it down to store rock; pick it up to carry it. |
| 250 | `rough_bed_kit` | Thatch - Bed |  | hand | KEEP | Sticks, branches and rough bedding lashed with twine. Set it under a roof and lie down to sleep. |
| 276 | `snare` | Snare |  | hand | KEEP | A loop of twine on a bent stick. Set it on a worn animal path. |
| 822 | `fish_trap` | Fish trap |  | hand | FUTURE | A cone of woven sticks set in the water. Fish swim in and cannot find the way out. |
| 824 | `bird_trap` | Bird trap |  | hand | FUTURE | A stick cage propped on a trigger. A ground bird that steps in for the bait brings it down. |

Already retired (186; numbers never reused): 20 `lean_to_kit` Lean-to; 22 `chest_kit` Wicker - Chest; 24 `chopping_block_kit` Chopping block; 28 `plank_chest_kit` Wooden - Chest; 73 `workbench_kit` Wooden - Workbench; 81 `tool_rack_kit` Tool rack; 83 `vice_kit` Vice; 85 `log_workbench_kit` Carpenter's bench; 87 `stone_forge_kit` Stone - Forge; 89 `blacksmithy_kit` Brick - Forge; 192 `wall_section_kit` Refined - Wall; 194 `floor_section_kit` Refined - Ceiling; 196 `roof_section_kit` Refined - Roof; 198 `foundation_section_kit` Sturdy - Foundation; 200 `doorway_section_kit` Refined - Doorway; 202 `window_section_kit` Refined - Window; 204 `timber_prop_kit` Post; 206 `timber_set_kit` Beam; 211 `ladder_kit` Ladder; 240 `saw_mill_kit` Sawmill; 242 `woodworking_table_kit` Woodworking table; 252 `thatch_wall_kit` Crude - Wall; 254 `campfire_pot_kit` Campfire pot; 256 `clay_hearth_kit` Clay hearth; 261 `thatch_floor_kit` Crude - Foundation; 263 `thatch_roof_kit` Crude - Roof; 265 `thatch_doorway_kit` Crude - Doorway; 268 `oven_kit` Oven; 462 `stairs_wood_kit` Refined - Stairs; 464 `log_wall_kit` Rustic - Wall; 466 `log_floor_kit` Rustic - Ceiling; 468 `log_roof_kit` Rustic - Roof; 470 `stone_wall_kit` Sturdy - Wall; 472 `stone_floor_kit` Sturdy - Ceiling; 474 `stone_roof_kit` Sturdy - Roof; 476 `brick_wall_kit` Superior - Wall; 478 `brick_floor_kit` Superior - Ceiling; 480 `brick_roof_kit` Superior - Roof; 482 `log_cabin_set_kit` Log cabin set; 487 `log_seat_kit` Seat; 488 `bench_kit` Wooden - Bench; 489 `chair_kit` Wooden - Chair; 490 `table_kit` Wooden - Table; 491 `hide_rug_kit` Hide - Rug; 492 `wool_rug_kit` Wool - Rug; 493 `straw_bed_kit` Straw - Bed; 494 `feather_bed_kit` Feather - Bed; 495 `canopy_bed_kit` Canopy bed; 496 `wall_torch_kit` Wall torch; 497 `chandelier_kit` Chandelier; 498 `fireplace_kit` Fireplace; 499 `flower_pot_kit` Flower pot; 500 `antler_mount_kit` Antler mount; 501 `stool_kit` Stool; 558 `wood_foundation_kit` Refined - Foundation; 562 `log_foundation_kit` Rustic - Foundation; 564 `brick_foundation_kit` Superior - Foundation; 566 `log_doorway_kit` Rustic - Doorway; 568 `stone_doorway_kit` Sturdy - Doorway; 570 `brick_doorway_kit` Superior - Doorway; 572 `thatch_window_kit` Crude - Window; 574 `log_window_kit` Rustic - Window; 576 `stone_window_kit` Sturdy - Window; 578 `brick_window_kit` Superior - Window; 580 `thatch_fence_kit` Crude - Fence; 582 `thatch_gate_kit` Crude - Gate; 584 `wood_fence_kit` Refined - Fence; 586 `wood_gate_kit` Refined - Gate; 588 `log_fence_kit` Rustic - Fence; 590 `log_gate_kit` Rustic - Gate; 592 `log_palisade_kit` Palisade; 594 `log_palisade_gate_kit` Palisade gate; 596 `stone_fence_kit` Sturdy - Fence; 598 `stone_gate_kit` Sturdy - Gate; 600 `brick_fence_kit` Superior - Fence; 602 `brick_gate_kit` Superior - Gate; 604 `iron_fence_kit` Iron - Fence; 606 `iron_gate_kit` Iron - Gate; 608 `thatch_pillar_kit` Crude - Pillar; 610 `wooden_pillar_kit` Refined - Pillar; 612 `log_pillar_kit` Rustic - Pillar; 614 `stone_pillar_kit` Sturdy - Pillar; 616 `brick_pillar_kit` Superior - Pillar; 618 `thatch_roof_corner_kit` Crude - Roof corner; 620 `wooden_roof_corner_kit` Refined - Roof corner; 622 `log_roof_corner_kit` Rustic - Roof corner; 624 `stone_roof_corner_kit` Sturdy - Roof corner; 626 `brick_roof_corner_kit` Superior - Roof corner; 628 `log_bench_kit` Log bench; 630 `log_table_kit` Log table; 632 `stone_bench_kit` Stone - Bench; 634 `stone_table_kit` Stone - Table; 636 `iron_bench_kit` Iron - Bench; 638 `iron_chair_kit` Iron - Chair; 640 `iron_table_kit` Iron - Table; 642 `stone_workbench_kit` Stone - Workbench; 644 `wooden_shelf_kit` Shelf; 646 `wooden_cupboard_kit` Cupboard; 648 `wooden_barrel_kit` Barrel; 650 `log_stairs_kit` Rustic - Stairs; 652 `stone_stairs_kit` Sturdy - Stairs; 654 `brick_stairs_kit` Superior - Stairs; 656 `wooden_railing_kit` Wooden - Railing; 658 `iron_railing_kit` Iron - Railing; 660 `double_doorway_kit` Refined - Double doorway; 662 `iron_doorway_kit` Iron - Doorway; 664 `steel_doorway_kit` Steel - Doorway; 670 `wooden_hanging_lantern_kit` Wooden - Hanging lantern; 672 `iron_hanging_lantern_kit` Iron - Hanging lantern; 674 `iron_wall_lantern_kit` Wall lantern; 676 `wooden_torch_post_kit` Torch post; 678 `stone_torch_pillar_kit` Torch pillar; 680 `iron_torch_stand_kit` Torch stand; 682 `wooden_lamp_post_kit` Wooden - Lamp post; 684 `iron_lamp_post_kit` Iron - Lamp post; 686 `stone_lamp_post_kit` Stone - Lamp post; 688 `stone_brazier_kit` Stone - Brazier; 690 `iron_brazier_kit` Iron - Brazier; 692 `thatch_garden_plot_kit` Thatch - Garden plot; 694 `wooden_garden_plot_kit` Wooden - Garden plot; 696 `stone_garden_plot_kit` Stone - Garden plot; 698 `brick_garden_plot_kit` Brick - Garden plot; 700 `wooden_planter_box_kit` Planter box; 702 `stone_planter_kit` Stone - Planter; 704 `wooden_trellis_kit` Trellis; 706 `wooden_compost_bin_kit` Compost bin; 708 `thatch_scarecrow_kit` Scarecrow; 710 `wooden_cold_frame_kit` Cold frame; 712 `stone_well_kit` Well; 714 `wooden_hand_pump_kit` Wooden - Hand pump; 716 `iron_hand_pump_kit` Iron - Hand pump; 718 `log_trough_kit` Log trough; 720 `wooden_trough_kit` Wooden - Trough; 722 `wooden_channel_kit` Wooden - Channel; 724 `wooden_channel_corner_kit` Wooden - Channel corner; 726 `wooden_channel_tee_kit` Wooden - Channel tee; 728 `wooden_sluice_kit` Sluice; 731 `stone_trough_kit` Stone - Trough; 733 `stone_channel_kit` Stone - Channel; 735 `stone_channel_corner_kit` Stone - Channel corner; 737 `stone_channel_tee_kit` Stone - Channel tee; 739 `clay_pipe_run_kit` Clay - Pipe; 741 `clay_pipe_elbow_kit` Clay - Pipe elbow; 743 `clay_pipe_tee_kit` Clay - Pipe tee; 745 `iron_pipe_kit` Iron - Pipe; 747 `iron_pipe_elbow_kit` Iron - Pipe elbow; 749 `iron_tap_kit` Tap; 751 `iron_deep_well_pump_kit` Deep-well pump; 753 `stone_cistern_kit` Cistern; 755 `stone_raised_cistern_kit` Raised cistern; 770 `kiln_kit` Kiln; 772 `tanning_rack_kit` Tanning rack; 774 `drying_rack_kit` Drying rack; 776 `smoker_kit` Smoker; 778 `oil_press_kit` Oil press; 780 `storage_jar_kit` Storage jar; 782 `hide_sack_kit` Hide - Sack; 784 `wicker_basket_kit` Basket; 786 `weapon_rack_kit` Weapon rack; 788 `armour_stand_kit` Armour stand; 790 `sign_kit` Sign; 792 `tusk_mount_kit` Tusk mount; 794 `clay_bloomery_kit` Clay bloomery; 796 `stonecutters_bench_kit` Stonecutter's bench; 826 `iron_anvil_kit` Anvil; 829 `preserving_jar_kit` Preserving jar; 831 `root_cellar_kit` Root cellar; 847 `log_shelf_kit` Log shelf; 849 `wooden_crate_kit` Crate; 851 `iron_chest_kit` Iron - Chest; 860 `mixer_kit` Mixer; 862 `engineered_foundation_kit` Engineered - Foundation; 864 `engineered_wall_kit` Engineered - Wall; 866 `engineered_doorway_kit` Engineered - Doorway; 868 `engineered_window_kit` Engineered - Window; 870 `engineered_pillar_kit` Engineered - Pillar; 872 `engineered_stairs_kit` Engineered - Stairs; 874 `engineered_floor_kit` Engineered - Ceiling; 876 `engineered_roof_kit` Engineered - Roof; 878 `engineered_roof_corner_kit` Engineered - Roof corner; 880 `fortified_foundation_kit` Fortified - Foundation; 882 `fortified_wall_kit` Fortified - Wall; 884 `fortified_doorway_kit` Fortified - Doorway; 886 `fortified_gate_kit` Fortified - Gate; 888 `fortified_pillar_kit` Fortified - Pillar; 890 `fortified_wall_top_kit` Fortified - Wall top.

### A.structure (203 rows)

| # | id | Name | Tier | Made at | Status | Purpose / note |
|---|---|---|---|---|---|---|
| 21 | `lean_to` | Lean-to |  |  | KEEP | A ridge pole on two forks, with a roof of leaned sticks and boughs down to the ground. Crawl in under it. |
| 23 | `chest` | Wicker - Chest | wicker |  | KEEP | **[D4]: stick-and-twine starter (s3.5).** A woven chest for storing things. |
| 29 | `plank_chest` | Wooden - Chest | planks |  | UPDATE | **DECIDED [D4]: becomes Rustic - Chest, Hardwood Boards (s3.5).** A plank chest for storing more things. |
| 54 | `remains` | Remains |  |  | KEEP | A fallen traveller and the pack they carried. |
| 74 | `workbench` | Wooden - Workbench |  |  | KEEP | A camp bench. It counts as a workbench: stand near it to make the things that need one. |
| 82 | `tool_rack` | Tool rack |  |  | KEEP | A tool rack. Beside a camp bench it raises the bench a level. |
| 84 | `vice` | Vice |  |  | KEEP | A wooden vice. Beside a camp bench it raises the bench a level. |
| 86 | `log_workbench` | Carpenter's bench |  |  | KEEP | A pinned plank bench with its own rack and vice. Stand near it to make the things that need a work table. |
| 88 | `stone_forge` | Stone - Forge |  |  | UPDATE | **DECIDED: bronze smithing only, no smelting (s2.7).** A clay and rough stone forge under a log lean-to. Stand near it to work metal. |
| 90 | `blacksmithy` | Brick - Forge |  |  | UPDATE | **DECIDED: becomes the Smithy (s2.7).** A brick forge with a stepped hood and iron straps. Smelts and works iron; an anvil beside it makes steel. |
| 91 | `carcass` | Carcass |  |  | KEEP | A freshly killed animal. Work it with a knife for meat, hide and bones. |
| 93 | `large_forge` | Large forge |  |  | UPDATE | **DECIDED: becomes the Blast Furnace, goes live (s2.7).** A big arched forge with a riveted iron frame and a brick-lined firebox. |
| 95 | `master_forge` | Master forge |  |  | UPDATE | **DECIDED: becomes the Master Smithy, goes live (s2.7).** An ornate black iron and gold forge set with red gems, always glowing. |
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
| 241 | `saw_mill` | Sawmill |  |  | UPDATE | **APPROVED: new yields, no Saw blade (s3.2).** A water-driven sawmill. Stand near it to saw logs into planks. |
| 243 | `woodworking_table` | Woodworking table |  |  | RETIRE | **APPROVED: retired in open PR #1036.** A woodworking table. Stand near it for fine woodwork. |
| 251 | `rough_bed` | Thatch - Bed |  |  | KEEP | A low frame of sticks and branches with a heap of rough bedding, like a manger. |
| 253 | `thatch_wall` | Crude - Wall |  |  | KEEP | A thatch wall. |
| 255 | `campfire_pot` | Campfire pot |  |  | KEEP | A pot hung over a small fire. It cooks while the fire is lit. The fire stays at firewood. |
| 257 | `clay_hearth` | Clay hearth |  |  | KEEP | A clay hearth with a spit. |
| 262 | `thatch_floor` | Crude - Foundation |  |  | KEEP | A thatch foundation on stakes. Walls and roofs stand on it. |
| 264 | `thatch_roof` | Crude - Roof 45 |  |  | KEEP | A thatch roof. It keeps the rain off. **BUGLIST-001 BUG-011 (13 Nov 2026): renamed from "Crude - Roof", id and number kept; now a 45 degree sloped panel with no posts.** |
| 1255 | `thatch_roof_65` | Crude - Roof 65 |  |  | ADD | A steep thatch roof panel. It keeps the rain off. **BUGLIST-001 BUG-011 (13 Nov 2026): the 65 degree panel, blueprint 251, state 291, same materials as Crude - Roof 45. Catalog change made on the strength of BUG-011, for Dave to confirm.** |
| 266 | `thatch_doorway` | Crude - Doorway |  |  | KEEP | A thatch doorway with a hanging door. **BUGLIST-001 BUG-010 (13 Nov 2026): the piece is now an open framed passage with no door; this text still says "hanging door" and is left for Dave's ruling (see the BUG-010 ledger entry).** |
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
| 504 | `bench` | Wooden - Bench |  |  | UPDATE | **DECIDED [D4]: becomes Crude - Bench (s3.5).** A plank bench that seats two or three. |
| 505 | `chair` | Wooden - Chair |  |  | UPDATE | **DECIDED [D4]: becomes Rustic - Chair (s3.5).** A chair with a back. Sit and rest. |
| 506 | `table` | Wooden - Table |  |  | UPDATE | **DECIDED [D4]: becomes Rustic - Table (s3.5).** A plank table on trestles. |
| 507 | `hide_rug` | Hide - Rug |  |  | KEEP | A pelt on the floor. |
| 508 | `wool_rug` | Wool - Rug |  |  | FUTURE | A striped woven rug. |
| 509 | `straw_bed` | Straw - Bed |  |  | KEEP | A bed with a heaped straw tick. |
| 510 | `feather_bed` | Feather - Bed |  |  | KEEP | A bed with a feather tick and a blanket. |
| 511 | `canopy_bed` | Canopy bed |  |  | UPDATE | **DECIDED [D4]: Hardwood Boards; the Ornate bed (s3.5).** A canopy bed with curtains. |
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
| 637 | `iron_bench` | Iron - Bench |  |  | UPDATE | **DECIDED [D4]: becomes Fine - Bench (s3.5).** A timber bench bound with iron. Seats two or three. |
| 639 | `iron_chair` | Iron - Chair |  |  | UPDATE | **DECIDED [D4]: becomes Fine - Chair (s3.5).** An iron-bound chair with a hide seat. |
| 641 | `iron_table` | Iron - Table |  |  | UPDATE | **DECIDED [D4]: becomes Fine - Table (s3.5).** A plank table bound with iron. |
| 643 | `stone_workbench` | Stone - Workbench |  |  | KEEP | A stone-topped workbench, the biggest of the three. Takes the tool rack and vice. |
| 645 | `wooden_shelf` | Shelf |  |  | UPDATE | **DECIDED [D4]: Hardwood Boards (s3.5).** Plank shelves to set against a wall. Holds 8 stacks. |
| 647 | `wooden_cupboard` | Cupboard |  |  | UPDATE | **DECIDED [D4]: Hardwood Boards (s3.5).** A tall plank cupboard with doors. Holds 16 stacks. |
| 649 | `wooden_barrel` | Barrel |  |  | UPDATE | **DECIDED [D4]: Hardwood Boards (s3.5).** A hooped plank barrel. Holds 8 stacks. |
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
| 771 | `kiln` | Kiln |  |  | UPDATE | **APPROVED: batch charcoal from logs (s2.6).** A domed brick kiln. Fires bricks twice as well as a campfire and burns wood to charcoal. |
| 773 | `tanning_rack` | Tanning rack |  |  | KEEP | **APPROVED: tanning.** A log frame to stretch scraped hides on while bark tannin turns them to leather. |
| 775 | `drying_rack` | Drying rack |  |  | UPDATE | **APPROVED: adds hide drying (s3.4).** A rack of sticks in the air and sun. Dries meat into jerky and fruit to keep. |
| 777 | `smoker` | Smoker |  |  | KEEP | A stone and clay smoke chamber over a slow fire. Smokes fish to keep for weeks. |
| 779 | `oil_press` | Oil press |  |  | KEEP | A stone press on a log frame. Squeezes linseed and walnuts for lamp oil. |
| 781 | `storage_jar` | Storage jar |  |  | KEEP | A tall lidded clay jar for grain, oil or water. Small, but it keeps damp and mice out. |
| 783 | `hide_sack` | Hide - Sack |  |  | KEEP | A hide sack tied at the neck. A first store for a camp before there are planks for a chest. |
| 785 | `wicker_basket` | Basket |  |  | KEEP | A woven basket of sticks and twine. A first store for a camp. |
| 787 | `weapon_rack` | Weapon rack |  |  | UPDATE | **DECIDED [D4]: Hardwood Boards (s3.5).** A plank rack against a wall for spears, bows and blades. |
| 789 | `armour_stand` | Armour stand |  |  | UPDATE | **DECIDED [D4]: Hardwood Boards (s3.5).** A plank figure to hang a set of armour and clothes on. |
| 791 | `sign` | Sign |  |  | KEEP | A plank board on a stick to mark a camp or a path. |
| 793 | `tusk_mount` | Tusk mount |  |  | KEEP | A pair of boar tusks on a plank. Hang it on a wall for comfort. |
| 795 | `clay_bloomery` | Clay bloomery |  |  | RETIRE | **APPROVED: no Clay Bloomery (s2.7).** A clay chimney furnace fed with charcoal. Smelts iron ore to an ingot, slowly, before a brick forge. |
| 797 | `stonecutters_bench` | Stonecutter's bench |  |  | KEEP | A heavy stone bench for squaring and carving stone. Gets more blocks from the stone, but needs a metal chisel. |
| 823 | `fish_trap_set` | Fish trap |  |  | KEEP | A fish trap set in the water. |
| 825 | `bird_trap_set` | Bird trap |  |  | KEEP | A bird trap set on the ground. |
| 827 | `iron_anvil` | Anvil |  |  | RETIRE | **DECIDED: the Smithy has a built-in anvil (s2.7).** A forged iron anvil on a banded log stump. Set beside a brick forge, it raises the forge a level, for steel. |
| 830 | `preserving_jar` | Preserving jar |  |  | KEEP | A wide-mouthed clay jar with a lid, for pickling and preserving. |
| 832 | `root_cellar` | Root cellar |  |  | KEEP | A stone-lined store dug into the ground. Cool all year, so food keeps far longer. |
| 840 | `chicken_coop` | Chicken coop |  |  | FUTURE | A thatched coop for four chickens. They lay eggs. |
| 841 | `fodder_trough` | Fodder trough |  |  | FUTURE | A plank trough that holds fodder for penned animals. |
| 842 | `tub` | Tub |  |  | FUTURE | A wooden bathtub filled from a bucket. Warm it with a fire close by. |
| 843 | `sap_tap` | Sap tap |  |  | FUTURE | A wooden spout driven into a maple or birch to catch sap. |
| 844 | `cheese_press` | Cheese press |  |  | FUTURE | A wooden press that squeezes curds into cheese. |
| 845 | `spinning_wheel` | Spinning wheel |  |  | FUTURE | **DECIDED: later, faster Thread (s2.8).** A treadle wheel that spins wool and flax into thread. |
| 846 | `loom` | Loom |  |  | UPDATE | **APPROVED: weaving station, goes live (s3.4).** A wooden frame loom for weaving thread into cloth. |
| 848 | `log_shelf` | Log - Shelf |  |  | KEEP | Split logs lashed between two log uprights. A first shelf to set against a wall. |
| 850 | `wooden_crate` | Crate |  |  | KEEP | **[D4]: rough packing box, stays on Planks (s3.5).** A braced plank crate with a nailed lid. Holds 10 stacks. |
| 852 | `iron_chest` | Iron - Chest |  |  | UPDATE | **DECIDED [D4]: becomes Ornate - Chest, Hardwood Boards, Iron bands (s3.5).** A plank chest plated and strapped in iron. Holds 30 stacks, more than a wooden chest. |
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
