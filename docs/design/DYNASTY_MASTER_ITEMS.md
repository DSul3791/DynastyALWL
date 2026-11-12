# Dynasty master items catalog

**Status: DRAFT 8, FINAL CONSISTENCY AUDIT DONE (12 Nov 2026). READY FOR DAVE'S FINAL CATALOG APPROVAL; NOT APPROVED FOR IMPLEMENTATION.** All Dave rulings ([B], [D1]–[D5], [DE]) and ChatGPT's delegated decisions ([C], [C7]) are written into the catalog. This document changes nothing in `data/items/*.json`, `data/npcs/*.json`, recipes, station behaviour or game code. The item catalog stays frozen until Dave approves this catalog.

Data read: `data/items/items.json` (889 rows, next number 896), `recipes.json` (404 rows, 287 live, next 407), `blueprints.json` (185 rows, next 186), `structures.json` (216 rows, highest state 228; state 229 is bog iron in code only), on `dev` at `7f8aabf4` (unchanged on 12 Nov). Open PR #1036 retires the Woodworking table separately.

Layout: s1 sources and labels; s2 design decisions; s3 the catalog by row (KEEP / UPDATE / ADD / RETIRE / FUTURE); s4 implementation details (no new design); s5 numbers still to set; s6 audit matrix; s7 JSON change list; s8 completed design resolutions and remaining implementation risks; Appendix A the full 889-row catalog.

**Totals (Draft 7).** Existing rows: KEEP 506, UPDATE 54, RETIRE 23, FUTURE 53, already retired 253 (889). New rows: ADD 24 (18 tools and stations, 6 furniture grades in s3.5). No number or id is reused.

## 1. Sources and labels

| Tag | Source | Weight |
|---|---|---|
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

Labels in sections 3 and 7 and Appendix A: **APPROVED** (Dave), **DECIDED** (ChatGPT for Dave, [C]), **ENGINEERING** (follows directly from the above; no new design), **OPEN** (s8, for ChatGPT).

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
8. **No Clay Bloomery.** No save-game migration is needed for any retirement or reuse: Dynasty has never been publicly released or played by other players [D1].

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
| Wicker - Chest, Stool, Seat, log furniture, Stone - Bench and Table, Straw and Feather beds, rugs | not graded | 23, 503, 502, 629, 631, 719, 848, 633, 635, 509, 510, 507, 508 | KEEP | No boards involved | Early comfort and storage |

**Notes:**
- Value follows the material cost, checked by the `items_check.py` economy test.
- Each grade needs its own look (`looks.json`) and its own structure state.
- Furniture needs no station; every row stays a hammer blueprint.
- Every material named exists and is sourced today: Hardwood Board (ADD), Wooden pin 233 (recipe 150), Twine 5, `nails` 228/894, `hinges` 232/895, Leather 283 (Tanning rack), Wool cloth 548 (Loom), Iron band 859 (Smithy), Feathers, Fibre cloth 517.

Food, medicine, coins and most gear and placeables are not touched by any decision and stay KEEP (Appendix A).

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
    - The Smelter, Stone - Forge, Smithy and Leatherworking Table blueprints use no Planks and no metal beyond what 2.7 names, so the wilderness route and the first Bronze - Axe (which needs a Leather strap) stay open before the first saw.
    - Smithy crafting needs a lit fuel state. Bellows and Quenching Trough are `addon_of` the Smithy, not independent stations; the trough unlocks suitable improved/tempered output at that Smithy.
    - Today the Large and Master forge rows carry station `forge` (levels 3, 4). As the Blast Furnace and Master Smithy they get their own station ids, so the Blast Furnace does not become a bronze workshop. The Smithy keeps `also: {forge: 1}` so it works bronze.
    - The Anvil today raises the Brick - Forge to level 3. With it retired, the steel recipes at `brick_forge` L3 (19, 28, 142, 183, 210–212, 219, 220, 347, 373) and 404 (Iron band) need no level: Steel ingots from the Blast Furnace already gate the steel rows.
    - Every station row gains input and output capacity fields; station inventories join the crafting source order (pack, ground stock, containers; DEVTEST-01 "lowest group member first" stays).
11. **Recipe moves:** 185, 190–192 → Smelter; 193 → Blast Furnace; bronze working at `forge` (204–206, 215, 290–293, 371, 394, 397, 405, 406) stays at the Stone - Forge and the Smithy; iron and steel working at `brick_forge` (18, 19, 27, 28, 141, 142, 145, 149, 183, 184, 188, 207–212, 217–220, 346, 347, 351, 372, 373, 404) → Smithy; leather and clothing rows per 3.4; Loom takes 245, 334, 342. New Bronze - Sickle and Bronze - Scythe recipes go to `forge`.
12. **Furniture [D4]:** blueprint cost changes, renames and the 6 new item, blueprint and structure rows exactly as in s3.5. **Comfort:** `comfort.json` counts each kind once and only the best bed. Graded families must count once per class at their best grade (as beds do), or a player could stack four chair grades for comfort; give each grade a `kinds` row with its points and extend the best-one rule from beds to seats and tables (small code change). Storage slots go on each structure row (`slots`).
13. **Tool tiers:** today's numbers clash across families (Bronze and Iron - Pickaxe both t2; Iron - Spade t3; Steel - Hammer t3 vs Steel - Spade t4; no tier on Wooden spade and hoe). Renumber by material rank in every family (Wooden 1, Stone 2, Bronze 3, Iron 4, Steel 5) and remap `digging.json tier_extra` and blueprint `hammer` values so any metal hammer still builds any tier (decision 73). No saves to migrate.
14. **Names:** an ingredient group is shown under its key item's name, so after the renames a `firewood` cost would read "Hard firewood" and a `wooden_block` cost "Hardwood block" while still taking the softwood kinds. Group costs need a group label ("Firewood", "Wooden block") in the recipe and site lists (`recipe_list.gd`, `inventory_view.gd`, `_site_view`). Dynamic enhanced names are exempt from the `validate_items.gd` four-word check; static names keep it. The renames in 3.2 and 3.3 keep the naming rules.
15. **Tempered [C7]:** a per-instance flag, set only when the player picks the Tempered output at a Smithy with the Quenching Trough attached. **Eligible:** steel tools (Pickaxe, Spade, Hoe, Hammer, Chisel and the new Axe, Knife, Saw, Sickle, Scythe), weapons (Sword, Mace, Shield) and armour (Helm, Cuirass); not the Steel - Striker (a fire-lighting tool), bronze or iron. All are future rows that go live with the Blast Furnace's steel. **Effect:** a higher base maximum durability, set once at crafting; slower sharpness loss only on rows with `edge: true` (Sword, Chisel, Axe, Knife, Saw, Sickle, Scythe, Pickaxe), never on mace, shield, spade, hoe, hammer or armour. **No multiplication:** a physical craftsmanship durability bonus adds to the tempered base (2.9 item 4), sharpening lowers the current maximum, and repair restores up to it; repair, reheating and sharpening never set or repeat the flag. Not a catalog row; no enhancement slot used. Same save and network path as item 16.
16. **Enhancements:** per-instance save data (like wear and sharpness), no `items.json` rows; saves and network protocol change; enhanced items never stack with plain ones; slot writes refuse an occupied magical slot.
17. **Related rows to update with each retirement or rename:** `weights.json`, `looks.json`, `showroom.json`, `design_names.json`, `descriptions_voice.json`, `encyclopedia.json`, `data/stations/forge_sizes.json`, `data/npcs/town_proposal.json` (names `stone_forge`); tests `test_server_items.gd`, `test_tool_looks.gd`, `test_stations.gd`, `test_lumber_route.gd`, `test_logs_carry.gd`, `test_bloomery_bench.gd`, `test_blueprints.gd`, `test_structure_looks*.gd`, `test_whetstone.gd`; client `basic_look.gd`, `piece_look.gd`, `look_table.gd`; `tools/gen_looks.py` and the icon painters. Run `tools/items_check.py` on the authorized PC after the data change.

## 5. Numbers still to set (tuning, not design)

Durability, repair materials and amounts; sharpening rate and maximum-durability cost per sharpening; grindstone speed; hand-saw time ("much slower" than the sawmill's 6 s per log); kiln burn time and self-consumption rate (Dave: not to be invented now); smelting fuel per ingot on the new 100-per-log charcoal scale (today 1 to 3 `fuel` per smelt); Bellows speed and fuel saving; Quenching Trough upgrade-gated improved metal recipes and quality (no universal bonus); Thread recipe (plant fibre per Thread) and Thread per sewing recipe; all new blueprint costs (Smelter, Smithy, Blast Furnace, Bellows, Quenching Trough, Master Smithy, Grindstone, Leatherworking Table, Tailor's Table, Loom, Chopping Block station) and the Sawmill's cost without a Saw blade; the Stone - Forge cost (live cost stays unless changed; it must stay iron-free); station storage capacities and sourcing radii; hammer sourcing ranges; 3 m log weight; Charcoal stack size (today 20, so one 600-charcoal kiln batch would fill all 30 pack slots) and value (today 3, against a Log's 4 for 100 Charcoal); the campfire charcoal rate of recipe 341 on the same scale; Thread and Hardwood board stack sizes; board and fitting counts, storage slots and comfort points for each furniture grade (s3.5; order fixed, numbers open); Tempered bonuses. The item-data and systems roles propose these in the implementation PR, checked by `items_check.py` economy and first-hour tests, and they are tuned in playtest.

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
| 28 | Food, medicine, coins | kinds food 116, medicine 5, coin 4 | Untouched by decisions | PASS | No changes. |
| 29 | Comfort stacking with graded furniture | `comfort.json rules.each_kind_once`, `one_bed_counts`, `kinds` | Four chair grades do not add up | ISSUE, needs code (small) | Best-one-per-class rule for seats and tables (s4 item 12). |
| 30 | Wood by biome | `flora.json` trees × `log_*` rows × `wood_species.json` class | Every forested biome can make Planks; boards where hardwood grows | PASS / RISK | Planks wherever trees grow (softwood or plain Log). No Hardwood Boards at all in alpine meadow, beach, dry scrub, hot desert, mangrove, marsh, savanna or volcanic waste; few in heath and grassland. Finished furniture there needs travel or trade (s8). Shelter, storage (Crate, Wicker) and beds stay possible. |
| 31 | Planks in fittings | recipe 150 (1 Plank → 20 Wooden pins) | Crude furniture reachable | PASS | Crude furniture needs a few Planks (for pins) plus boards; both come from the same saw. |
| 32 | Quenching Trough progression | Smelter → Stone - Forge / Smithy → Bellows, Quenching Trough add-ons → Blast Furnace steel | No recipe or quality softlock | PASS (desk) | No plain recipe needs the trough. Tempered applies only to steel, so the trough becomes useful once the Blast Furnace runs. The add-on is a buildable attached structure (`addon_of` the Smithy), not a station. |
| 33 | Early storage ladder | Wicker - Chest 12, Hide - Sack 6, Basket 6, Storage jar 4, Crate 10, Rustic - Chest 20, Ornate - Chest 30 slots | Storage grows with progress | PASS / NOTE | The Crate (10 slots, Planks and nails) holds less than the Wicker - Chest (12, sticks). Unchanged; noted only. |
| 34 | Name rule for grades | decision 71 (a tier word only where several versions exist); four-word check | "Grade - Object" fits | PASS | The grade word replaces the material word, as in "Stone - Axe". No clash with live names; "Fine board" 227 is retired. |
| 35 | Draft 6 claims | s6 rows 20, 21 and the Draft 6 readiness line | Withdrawn where [D4] changes them | DONE | Substitution analysis and its code list withdrawn; the durability-only Quenching Trough effect withdrawn. |
| 36 | Tempered scope | steel rows 34, 47, 224, 294, 321, 322, 323, 330, 331, 561, 800 and the new steel tools; `edge` flags | Only eligible steel; sharpness benefit only on edged rows; no stacking | PASS | Striker excluded; sharpness benefit limited to `edge: true` rows; durability adds, never multiplies (s4 item 15). |
| 37 | Counts and Appendix A | status per row vs s3 tables; Appendix A generator overrides | Totals agree | PASS | KEEP 506, UPDATE 54, RETIRE 23, FUTURE 53, already retired 253 (889); ADD 24. Every s3 UPDATE, RETIRE and FUTURE row carries the same status in Appendix A. |

## 7. JSON change list (none made; all wait for Dave's approval of this catalog)

1. **Retire:** items 45, 238, 298, 353, 795, 827 and the 16 species `lumber_*` and `beam_*` rows; recipes 26, 152, 187, 227, 230, 367; blueprints 162, 164; structures `clay_bloomery` (state 200) and `iron_anvil` (state 204). Woodworking table rows: PR #1036.
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

## 8. Remaining issues and readiness

**Design questions open:** none. ChatGPT settled both Draft 7 points [C7], and Dave's [D5] material rule is applied throughout s2.3, s3.5, s4 and s6.

**Substantive remaining issues:** none in the catalog. What is left belongs to the implementation PR:
- **Small code changes the catalog relies on:** the best-one-per-class comfort rule for graded seats and tables (s6 row 29); group labels for the renamed `firewood` and `wooden_block` keys (row 23).
- **New systems:** per-instance data (sharpness, current maximum durability, Tempered, enhancement slots) in pack, save and network; station storage and sourcing; kiln batches; sharpening.
- **Runtime tests on the authorized PC:** the first-hour route, the route to the first saw, the pre-iron Leatherworking Table and bronze working (s6 rows 15–17). Every check in s6 is a desk review; no Godot test was run.
- **Later trade decision:** furniture in the eight hardwood-free biomes depends on travel or on a trader selling Hardwood Boards (s6 row 30).
- **Baseline:** recheck against the latest `dev` before implementation (compared at `7f8aabf4`); PR #1036 stays separate.

**Readiness.** The catalog is ready for Dave's final approval. **Do not merge or implement until Dave explicitly approves it.**

## Appendix A. Full catalog of existing items (generated from `data/items/items.json`)

Generated from dev `7f8aabf4`. 889 rows; next free item number 896. Status counts: FUTURE 53, KEEP 506, RETIRE 23, RETIRED 253, UPDATE 54.
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
| 7 | `spear` | Stone - Spear | t2 | hand | UPDATE | **DECIDED: disposable (s2.2).** A stone point on a long shaft. Jab with it or throw it; it kills a rabbit in one blow. |
| 10 | `wooden_spear` | Wooden - Spear | t1 | hand | KEEP | A sharpened stick. Jab with it or throw it. |
| 269 | `wooden_bow` | Wooden - Bow | t1 | workbench | KEEP | A bow of bent wood and twine. Needs arrows. |
| 295 | `javelin` | Javelin | t2 | workbench | UPDATE | **DECIDED: disposable; recoverable if unbroken (s2.2).** A light, balanced throwing spear. Flies farther and straighter than a plain spear. |
| 300 | `wooden_club` | Wooden - Club | t1 | hand | KEEP | A stout length of hardwood, heavy at one end. Hits hard and needs no skill. |
| 312 | `wicker_shield` | Wicker - Shield | t1 | hand | KEEP | Sticks woven tight with fibre. Light, and good for a few hits. |
| 313 | `stone_mace` | Stone - Mace | t2 | hand | UPDATE | **DECIDED: disposable (s2.2).** A heavy stone lashed to a stick. Cracks armour and bone. |
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

