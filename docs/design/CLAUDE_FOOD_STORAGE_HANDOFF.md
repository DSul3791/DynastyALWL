# Claude coordinator handoff — Items, food, warehousing and learned meal combinations
**Date:** 12 November 2026
**Repository:** `DSul3791/DynastyALWL`
**Design PR:** #1035; branch `claude/project-thread-39uvpg`
**Status:** OWNER DESIGN HANDOFF, DOCUMENTATION WORK ONLY. The complete master catalog is **not finally approved**. **No gameplay code, JSON, implementations, merges, deployment or promotion to `dev` / `main` is authorized.**

## 1. Start here — source of truth

1. Read the **current** `docs/design/DYNASTY_MASTER_ITEMS.md` in full, especially §§2.5, 3.12–3.16 and the count/status/audit sections.
2. Read `docs/design/FOOD_PREPARATION_PRESERVATION_SERVING.md` and `docs/design/STORAGE_WAREHOUSING_DESIGN.md`.
3. Review older `docs/design/item_system.md`, `docs/design/INVENTORY_CRAFTING_LOOK.md` and `docs/design/field_journal_design.md` **for compatibility**, not to override the newer owner decisions. Older "FINAL" statements are historical.
4. Inspect real item IDs and available ingredients in `data/items/items.json`, existing dishes in `data/items/dishes.json`, `data/items/vitals.json`, `data/items/spoilage.json`, `data/items/fitness.json`, `data/items/exertion.json`; read-only until implementation is authorized. Re-fetch head/file SHA before each write. Another Claude agent may be editing the same PR.

**Approval and counting:** Approved catalog currently claims **174 ADD** and **4 new FUTURE** (previous 165 ADD / 3 FUTURE, plus nine new approved serving ADD and one FUTURE Ploughman's Board). Do a careful count/cross-document consistency audit; **do not** promote the unapproved preservation list to approved. Master catalog wins over any divergent companion document.

## 2. Binding owner decisions — preserve verbatim in substance

### Storage [D13]
- Sixteen approved new storage concepts including Warehouse Crate and Warehouse Desk; existing crate/chest IDs retained. Storage Sign/Desk is a view over **real nearby separate physical container inventories**; does not add capacity or magically teleport items.
- A **loaded crate** can physically move with contents on carts/wagons and later ships; the **current local** warehouse's desk (or future ship Captain's Table) links automatically. Leaving a location revokes the old link. Per-instance owner/lock, actual mass, perishability, contents and cargo identity persist; no duplication or stale remote access.
- Direct interaction with an accessible crate/chest always works; the desk is optional convenience.
- An owner can access their **own locked crate** via an in-range Warehouse Desk **without entering a code**. Merely owning a desk does not grant access to another person's crates.
- Crates/chests may have **owner-set four-digit codes, including leading zeroes**; another player who knows the code may access **that particular container** without unlocking it for the world.
- Wrong attempts by a player on one container cause increasing wait **10, 20, 30, 40... seconds**; correct code resets that player's failure streak. The timer persists across direct/desk/ship interfaces. Server must later enforce checks; no implementation now.
- Future ship and Captain's Table are cross-references, not current approved item IDs.

### Cooking [D12], preservation [D14]
- Food Preparation Table has built-in knives/cutting board/rolling pin; do not invent inventory knife for cooking. Assemble only food requiring real preparation, and finish once at a compatible station; basic cooking directly at a fire is fine.
- **Preservation process is approved**: one finishing operation in Smoker/Drying Rack/Oven/Pot where appropriate, or bulk sealed jars mature **passively** with elapsed game time. Hundreds of jars are valid when real vessels/ingredients exist. No extra curing-tub chores, repeated manual jars, false jam safety, or spoilage resets during transit.
- **Preservation item roster P14-v2 is STILL PROPOSED, NOT APPROVED**: Sealable Preserve Jar, Smoked Meat, Dried Mushrooms, Dried Herbs, Cured Olives (five possible ADD, zero new stations). Existing dried foods, Jerky, Salted Fish, Smoked Fish, placed Preserving Jar/Storage Jar/Barrel/Root Cellar/Smoker/Drying Rack reused. Granary as layout instead of a new magical store; Butter/cheese/press remain already FUTURE. Don't silently create separate `Maturing X` item IDs: assess technical tradeoffs and report.

### Nine serving boards [D15] — OWNER APPROVED, not 15 or 20
Exactly **nine named edible boards**:
1. Seafood Platter
2. Roast Platter
3. Mixed Grill Platter
4. Charcuterie Board
5. Ploughman's Board (**FUTURE:** Cheese #418 and Pickled Vegetables #834 unavailable yet)
6. Harvest Platter
7. Tavern Supper Board
8. Breakfast Platter
9. Dessert Platter

One reusable **Serving Platter** is the physical display carrier for all nine; individual named boards are real prepared-food inventory outputs, with real ingredients and edible portions. Table displays visibly empty as portions are eaten. Roast Beef is **not** a tenth item; can be a Roast Platter variant after actual beef is approved/available. Remove Fisherman's, extra roasts/feasts, Traveller's Board and Fruit Board as duplicates; do not resurrect prior 15/20-item proposals.

**Count:** Eight current board ADD + one serving carrier ADD = **nine ADD**; Ploughman's Board = **one FUTURE**.

### Food effects / XP [D16] — owner direction, numerical tuning pending
- Food grants **temporary effects** coherent with type and quality; better recipes generally stronger and/or longer.
- Protein-rich foods can increase **Fitness XP earned while genuinely exercising**, e.g. +20% suggested illustratively. Red-meat/hearty meals may improve health regeneration. **Bread/grains/potatoes give quick energy/recovery but NO XP boost just for carbs**. Fruit/vegetables help recovery/endurance. **Desserts provide quick short-lived energy and may penalize XP gain**.
- Better balanced meals may temporarily increase **all actively earned skill XP**, where those skills exist. **No permanent skill/Fitness stat increases on eating**. Apply modifiers **when XP is earned**, not at the midnight payout of previously accumulated Fitness XP; don't double-multiply broad-skill and Fitness-specific bonuses.
- **Exactly up to THREE simultaneously active food-benefit slots**. Each food belongs to **ONE primary group**, different from the other active ones: Main Meals; Breads & Grains; Fruit & Vegetables; Desserts; Beverages (these group names are provisional and must be validated against actual items). A fourth distinct-group food prompts a replace-one selection; same-group eating replaces that group's existing bonus. The three effect timers are independent. Ordinary hunger/calories operate regardless of buff slots. Three roasts / three dinners / three sweets cannot all buff at once. Main + grain + drink, main + dessert + drink, etc. work.
- XP bonuses from different food groups **must not multiply**; choose one strongest eligible XP bonus, then make handling of dessert penalties explicit/clear in the future tuning proposal. No buff stacking or rebuff exploits. Check actual beverage data before claiming **Coffee** exists; do not invent mana or spellcasting XP.

### In-world meal advice [P17] — owner-suggested FUTURE, do not invent items
NPC cooks/innkeepers/hunters/trainers/healers/sages and readable books may **teach** effective three-group combinations for warrior, wizard/scholar, miner, builder, traveller, etc. Use existing skill/food realities; **do not invent class restrictions or mana**. The player can discover combinations without the guide. Guides reveal information, not secret extra buffs or profession-locked foods. Optionally record discoveries in a future personal knowledge journal (existing `field_journal_design.md` concerns animals). **Individual guide books and NPC dialogue roster not yet approved** as new item definitions.

## 3. Your authorized next actions — DOCS only

1. **Reconcile:** Bring master catalog, companion food/storage design, item system and inventory-look/UI notes into alignment. Resolve stale claims such as "only one active food", "15/20 boards pending", "one extra Roast Beef board", wrong approved ADD totals, a Warehouse Desk bypassing owners' locks, nonexistent Coffee as shipped item, or maturing jars creating unapproved IDs. Never silently erase owner intent. Distinguish approved owner design vs unapproved proposed mechanics/recipe IDs.
2. **Audit repeatedly:** Whole-system design review for duplicate item names/roles, source-item availability, station gating, class-specific effect assumptions, spoilage/warehousing persistence, XP timing, all-skill XP and Fitness XP overlap, per-profile categorical slots and durations. Compare exact baseline IDs; note dependencies and untested assumptions.
3. **Produce concise final proposal** for unresolved [P14-v2] five-item preservation roster and optional [P17] nutritional guides; keep them explicitly **pending Dave's approval**. Propose initial XP-bonus/penalty/duration numbers only as a **separate suggested tuning sheet**, never as owner-approved facts. Explain tradeoffs only where substantive.
4. **Scenario tests (design only):** three different group buffs, duplicate-group replace, fourth-group replace, mixed meal/coffee/dessert example (if real drink exists), temporary earned XP at event not midnight, sweets penalty, no retroactive XP, NPC/books give hints but no hidden stats, container owner/4-digit sharing/wrong guess lockout, loaded crate warehouse→ship→different warehouse without duping/spoilage reset, 200 real sealed jars maturing, a real platter eaten portion-by-portion.
5. **Maintain one source of truth:** the master catalog for approvals/totals. Companion docs for behavior and test cases; old designs only as references. Keep a written mini-audit of conflicts found and fixes. Repeat cross-document review until no substantive conflicts remain.
6. **Commit documentation only** to PR #1035 branch, using current blob SHAs/re-fetch after other edits. Leave a PR comment stating changed files, audit checks, remaining questions, and a concise owner-decision list. Tell Dave the PR/commit and what still needs approval. **Do not merge this PR.**

## 4. Required final report back to Dave

Keep the user update short:
- Docs/commit updated (paths and link to PR #1035).
- Verified [D12]–[D16], including nine boards, three distinct-group effects, and jar/warehouse rules.
- List only genuinely unresolved **owner** choices (e.g. preservation P14-v2 and future numeric tuning/books).
- Explicit sentence: **No gameplay implementation or merge.**

**Important:** Publishing files/PR comments doesn't automatically alert or resume a Claude agent. Coordinator should inspect the PR in its actual session and assign documentation-only audits to appropriate agents, not assume someone read a comment automatically.
