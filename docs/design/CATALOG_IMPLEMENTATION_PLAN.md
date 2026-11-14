# Dynasty — Catalog Implementation and New Progression Integration

**Updated 13 November 2026.** The original Mission 001 Phases 0–10 delivered a baseline catalog to `dev` under the previous station designs, and its exact original phase ledger and test evidence remain at `docs/ai-team/missions/M001/STATE.md` and Git history. **Those earlier station names, recipes, tech progression and test pass claims are not instructions to implement again.** This file is the current work sequencing for newer creator-approved mechanics. It is a **design/implementation plan, not blanket permission to edit gameplay** or merge to `main`.

**Design authority:** [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md) §§2.1–2.7, 3.3 and 3.13; [progression.md](progression.md) for complete dependency path; [PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md](PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md) for the root defects, tests and scope; [PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md](PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md) for 80 audit findings and 651 baseline goals; [PLAYER_CARTOGRAPHY_MAP_DESIGN.md](PLAYER_CARTOGRAPHY_MAP_DESIGN.md) for new skill-based player Map. No historical Draft 7 or 12 Nov forge instructions may supply missing values in the current design.

## 1. Current implementation baseline and non-goals

Current `data/items` JSON, client scenes and server code describe what has been implemented, not automatically what is now approved. Existing structures and item numbers must be preserved/mapped safely; do not invent a new ID for a surviving object if an existing ID can represent it without losing legitimate data. Do not delete functional unrelated food/storage/gear systems merely because the metalworking route changes.

Retired production logic **must not** return as an alternate player route: direct iron through Primitive Smelter; standalone Stone/Brick Forge progression; external Anvil in five-metre crafting range; Clay Bloomery; standalone Smithy Bellows/Quenching Trough; detached Windmill for Advanced Smelter; temperature-driven recipes; old multi-ore ingot yields; automatic wood fuel loading; a special Repair Hammer; or a permanently omniscient World Map.

`main` stays stable; development uses a scoped branch/PR, independent review and tested `dev` integration. Per-file owner lock for shared JSON and `src/stream/server_items.gd` (refined 14 Nov 2026 for GOALS-REPAIR to per-section locks on server_items.gd; see `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` D-E1). All changes to save/network formats require tested versioning and documented migration/rejection. The old full backup/migration pass for private pre-release worlds is not a mandatory prerequisite, but **no silent item loss or duplication** is acceptable for saves that the new version claims to support. Explicit world reset is allowed only with a transparent notice and approval when necessary.

## 2. New integration sequence

| Phase | Deliverable | Hard dependencies and evidence |
|---|---|---|
| R0 | Reconcile master/catalog, goals, controls, authoritative data source matrix | No contradictory active instructions; old Mission 001 ledger remains historical; identify any missing station bill of materials, stable mapping and current data discrepancies |
| R1 | Root gameplay blockers: Oak Tannin Bark, Scots Pine Tar, filled Water for recipes, client farming sow/water/harvest | Server-authoritative, reachable player actions; no admin spawn; test full tan/leather, pine tar→tar→water wheel, real water consumption, farming over seasons |
| R2 | Primitive Smelter and Smithy using stone tools, copper/tin/bronze conversion and meaningful Copper tools | **No metal/Planks/Nails in prerequisite builds**; 20 fuel, 20 input and **ground-output ingots**; 20s/ingot; 1:1 ore and 1+1 ore→2 Bronze |
| R3 | Improved Smelter/Smithy, human bellows and Iron Saw/Anvil | Bronze fittings first; 40/40/80; unmanned 20s/ingot no Iron, manned 1.30×/~15.38s/ingot and Iron enabled; Improved Smithy Iron-on-bronze wear |
| R4 | Advanced Smithy using Iron Anvil, Advanced Smelter with integrated windmill/two bellows, Steel Anvil for Master | 80/80/160, **no production in insufficient wind**, two ingots per ~11.83s nominal; Steel uses Iron Ore + Coal/Charcoal separately in input AND hopper fuel; ratio must be approved before final Steel recipe |
| R5 | Master Smithy and station wear/repair, Tempered steel/masterwork | Built with Steel Anvil; quencher integrated; worn/broken Smithy remains, warns **"Needs repair"**, equipped normal hammer right-click Repair, **War Hammers excluded**; repair materials carried/nearby storage/ground; cost to be settled |
| R6 | Specialized resource bins and fuel auto-pulls | Existing `open_storage_bin` identity reconciled, sizes 1000/5000/10000, recipes 16+32/32+64/64+128 Planks/Nails, single assigned type until empty; fuel pulls 30m/300s, oldest first, Coal/Charcoal from bins/kilns/fires, **no permission check** |
| R7 | Correct 651-goal content and runtime truth, new tier/skill coverage | No old recipe numbers; correct stable IDs and source prerequisites; no manual goal activation; exact existing coin values preserved; all genuine crafting, gathering, building and activity events counted exactly once |
| R8 | Simple one-window Journal/Goals/HUD and new discovery-based charcoal Map | Match Inventory/Crafting look, two-item thin-border HUD, J/G/M; Map is NEW per-character observation/Mapping-skill design, not a hook into nonexistent full-world atlas; Map Scroll sharing/sales scoped only once approved |
| R9 | Practical F6/end-to-end/multiplayer persistence and re-audit | Start empty, gather legitimately, test each material tier, logs, tools, doors/roof variants, Farming/Water, bins/repair/wind and every goal grouping; rerun audit with test evidence; no false retrospective PASS |

**Production times are approved:** Primitive **20s/ingot**; Improved unmanned **20s**, manned **20/1.30 = ~15.38s/ingot**; Advanced at nominal sufficient wind has two production lanes, each an additional 30% faster (**2 ingots per ~11.83s**, aggregate ~5.92s/ingot). Wind stronger than the running threshold can increase production speed, *never* yield. Threshold/curve need engineering tuning. Existing timed recipes cannot overrule these.

**Closed recipes:** 1 Copper Ore→1 Copper Ingot; 1 Tin Ore→1 Tin Ingot; 1 Iron Ore→1 Iron Ingot; 1 Copper Ore+1 Tin Ore→2 Bronze Ingots. **Steel carbon quantity is not closed:** do not transfer obsolete `2 Iron Ingots+fuel` recipe. The extra carbon ingredient enters the Advanced Smelter INPUT, distinct from fuel hopper.

## 3. Minimal interface and content rules

No extra player-facing forge-level windows, special hammer repair menus beyond the existing right-click action, dedicated bin-assignment modal, optional manual goal activation, or omniscient world atlas. Design should look integrated with the existing Inventory/Crafting UI. Resource assignment happens on first deposit and resets on fully empty. The Map content is a charcoal sketch of only discovered ground; exploration and Map Scroll drawing raise skill; revisiting improves local map accuracy.

Buildables/recipes must never depend on future materials made only at the station they are supposed to construct. Preserve item ID integrity and no Plank/Hardwood Board substitution. Provide negative tests for each removed behavior as well as positives for current rules.

## 4. Remaining real owner decisions and gates

- Exact Steel carbon ingredient quantity per Iron Ore/Steel Ingot; separate from fuel burn.
- Exact Smithy tier repair material recipes/restore amount and any hammer wear.
- Map Scroll production, transfer of learned geography, recipient reading, value, sale, inheritance rules; these do not block the basic discovered charcoal Map design.
- Exact newly constructed station costs and component IDs, Copper tool coverage, wind curve and fuel rates require coherent engineering proposal / relevant approval, not guessed constants.
- Coin redistribution/reward balance and old-character retrospective payouts are a later explicit economy/migration approval and should not delay mechanic repair tests.

## 5. Proof and delivery format

For each R phase: short ticket with authoritative rule citation, exact code/data targets, tests and negative regression cases, known blockers, status (`STATIC_READ / AUTOMATED_TEST / HEADLESS_GODOT / PLAYED_F6 / MULTIPLAYER_RESTART`) and resulting `dev` SHA. Preserve the original M001 execution evidence without reintroducing its outdated design. Only creator-approved and running-game verified systems should appear in a final playable Journal tutorial.
