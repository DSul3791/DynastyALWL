# Tool and weapon tier balance: proposal (Sal, 2026-10-30)

Not applied to any data. Built from the live numbers in `data/items/items.json` and the tier table in `design/TOOL_TIERS.md`. Dave decides before anything changes.

## What the data does today
- Durability (uses): wooden spade/hoe 2025; stone spade/hoe 4050, stone hammer 4350, stone axe 900, stone knife 540; iron spade/hoe 20250 and iron pickaxe 9000; steel spade/hoe 40500 and steel pickaxe 22500. Per rung: wood to stone about 2 times, stone to iron about 5 times, iron to steel 2 times.
- Weapons: wooden spear damage 6, thrown 5; stone spear 8, thrown 6; wooden bow 400 durability.
- Prices (copper): stone tools 20 to 35, iron tools 90 to 120, steel 140 to 300.

## Proposed ladder for the final list (applies to new items; existing numbers untouched)
| Rung | Materials (Dave's ladder) | Melee damage | Durability multiple of the wooden tool | Price band (copper) |
|---|---|---|---|---|
| 1 | wood, bone | 6 to 7 | 1 | 10 to 20 |
| 2 | stone, flint, obsidian | 8 to 9 (obsidian +1, brittle: durability about 0.6 of flint) | 2 | 20 to 60 |
| 3 | copper, bronze | 10 to 12 | 5 (copper 4, bronze 6) | 70 to 150 |
| 4 | iron | 12 to 14 | 10 | 90 to 200 |
| 5 | steel | 15 to 17 | 20 | 140 to 400 |
Thrown weapons: damage per throw about 1.2 times the same rung's thrown spear; the javelin is the exception by design (9 against the spear's 6) with low durability (120).
Gaps this exposes: today's rung 3 is iron; copper and bronze would slot between stone and iron, which means the iron rung moves from tier 3 to tier 4 in `tier` numbers or copper and bronze share tier 2 and 3 with stone. That renumbering touches digging.json tier_extra, hammer blueprint tiers and saves (TOOL_TIERS.md warns about this), so Sal recommends giving copper and bronze tools tier 2 and 3 values only when Dave asks for a copper tool rung, and keeping existing tool tiers.

## Questions for Dave
1. Add a copper and bronze tool rung, or keep copper and bronze as ingot and weapon materials only?
2. Pickaxes sit one tier earlier than spades (iron pick 2, iron spade 3): intended?
