# Buildables plan: the hammer list, complete

Morgan, 10 Nov 2026. Plan only, no code. Inputs: Jamie's hammer audit (`buildables/hammer_audit.md`, main plus #902), Kathleen's look vocabulary, `structures.json`, `blueprints.json`, `items.json`, `design/TOOL_TIERS.md`, the 22 Oct and 25 Oct building-tier decisions (`items/BLUEPRINT_BUILD_DESIGN.md`, `BUILDING_TIERS_AUDIT.md`) and `FURNITURE_BALANCE.md`. Dave's list of 10 Nov: foundations, walls, ceilings and roofs for every tier; fences in tiers; benches, chairs, tables, work benches; lanterns, standing torches, lanterns on poles; garden plots, flower pots; irrigation hand pumps; troughs and pipelines. **Status: approved 10 Nov by the coordinator, with the rulings below. Jamie commits it as a docs-only PR.** This becomes the building chapter of the item system (`item_system.md`).

## Rulings 10 Nov

1. B0 metal hammers approved; they are crafted at the forge.
2. **Thatch - Ceiling is dropped.** Thatch is a one-storey tier. (Removed from B1a; later numbers shifted by one.)
3. The workbench-station requirement on existing hammer blueprints is removed (the standing rule wins). Jamie does it in B1a.
4. Display renames approved: Wooden - Stairs, Wooden - Bench, Wooden - Chair, Wooden - Table, Log - Workbench.
5. Costs stay first-pass. The nails pass and wall thickness are later balance tasks, not now.
6. Water: the graph model is approved; river intake is accounting only; no change to the live water sim. Sonny confirms the details.
7. Jamie commits this document as a docs-only PR.

## 1. Rulings this plan follows

| Ruling | How it is applied |
|---|---|
| No "floor" pieces | The foundation is the floor of the ground storey; the ceiling is the floor of the next. No floor blueprint is added. (The ids `floor_section` and `log_floor` stay as ids only; display names are already "Ceiling".) |
| Names are sentence case, `Tier - Item` | Every new name is `Tier - Item` ("Log - Foundation", "Iron - Hand pump"). Existing breaches to rename (display only, ids kept): Stairs -> Wooden - Stairs; Bench, Chair, Table -> Wooden - Bench, Wooden - Chair, Wooden - Table; Sturdy workbench -> Log - Workbench; Workbench stays Workbench (the base). |
| Hammers of any metal | Hammer tier 3 means any metal hammer (bronze, iron or steel). **None exists today** (TOOL_TIERS lists only wooden and stone), so batch B0 adds three hammer items first; every metal piece below is hammer 3. |
| No flags | No flag, banner or standard pieces in any batch. |
| Hammer blueprints, no kits | Every row is a hammer blueprint taken down for a refund. No kit recipes. |
| Jamie owns numbering | The numbers below are a **reservation request** starting at the free numbers she gave (item 560, recipe 346, blueprint 55, state 77). She may shift any range when #883 and #902 settle. |

## 2. Tiers

Five live building tiers, in order: **Thatch, Wooden, Log, Stone, Brick.** Metal pieces (fences, lights, pumps, doors) use **Iron** and **Steel** names. Plank and Mason were decided on 25 Oct but have no pieces today; they are out of scope here and listed in section 8.

Look families (Kathleen's four): Thatch family covers Thatch and Log (bark poles, lashed joints); Wood family covers Wooden (planks, pegged joints); Stone family covers Stone (cut stone, mortar joints); Metal family covers Brick and Iron/Steel (brick, tile, riveted iron). Colours, flame colour (1.0, 0.65, 0.15) and "collision is a few boxes" are hers; this plan does not repeat them. Her single-tier tables map as: Fence/Gate -> B2, Lantern/pole -> B4, Garden plot -> B5, Pump/trough/pipe -> B6.

## 3. What exists today (53 blueprints)

| Piece | Thatch | Wooden | Log | Stone | Brick |
|---|---|---|---|---|---|
| Foundation 4 x 4 | yes (#29) | yes (#902) | **missing** | yes (#4) | **missing** |
| Wall | yes (#30) | yes (#1) | yes (#16) | yes (#19) | yes (#20) |
| Doorway | yes (#32) | yes (#5) | **missing** | **missing** | **missing** |
| Window | **missing** | yes (#6) | **missing** | **missing** | **missing** |
| Ceiling | n/a (one-storey tier) | yes (#2) | yes (#17) | yes (#37) | yes (#21) |
| Roof | yes (#31) | yes (#3) | yes (#18) | yes (#38) | yes (#22) |
| Stairs | missing | yes (#36) | missing | missing | missing |
| Pillar, roof corner, railing | none | none | none | none | none |
| Fence, gate | none | none | none | none | none |

Other groups today: furniture is wood-only (log seat, stool, bench, chair, table, three beds, two rugs, two chests); lights are wall torch, chandelier, fireplace and the unbuilt standing/wedged torch; garden is the flower pot and the tilled bed (not on the hammer); water is nothing (only the held bucket). Total new: **96 blueprints, 8 component items, 3 hammers**.

Existing rows that disagree with the rest (for Jamie to decide, not changed here):
1. Stone - Ceiling, Stone - Roof, Wooden - Stairs, Chair, Table, Bench, Wooden - Chest and others name a **workbench** as their station. The standing rule is that hammer blueprints never need a workbench. New rows here need none.
2. The Wooden doorway and window cost less than the wall (3 against 4 lumber) while the Thatch doorway costs more than the thatch wall. New openings use about three quarters of their wall.
3. Wooden costs have no nails; Dave's 22 Oct wood chain puts nails in anything built from wood. Costs here follow the live rows (lumber and twine); a nails pass is a separate balance task.
4. All current walls are 2.0 x 0.25 m whatever the tier; the decided design had thick log and stone walls (0.4 to 0.6 m). Not changed here.

## 4. Design basis for the new rows

- **Costs** scale from live rows of the same tier: opening about 0.75 x wall; roof corner 0.6 x the straight roof; pillar 0.1 x wall; stairs about 2 x wall; fence section about 0.25 x wall; stone and brick items add mortar at about 1 mortar per 3 blocks. Metal pieces use iron ingots, nails (1 ingot = 100 nails) and hinges. All numbers are first-pass for Jamie and Tyler to tune.
- **Footprints and snaps:** build pieces use the grid and anchors in the audit (wall 2.0 x 0.25, ceiling 2 x 2, roof 2.4 x 2.4, foundation 4 x 4 with 8 wall, 4 ceiling and 5 roof anchors). Fences and railings are 2 m sections, end to end, 45 or 90 degree turns. Furniture, lights and garden pieces are free placed (cap 12 per chunk) unless stated.
- **Per-row fields every batch must carry** (so a PR is just data): `structure` row (footprint, state, piece flag, anchors or cap), `blueprint` row (category, `Tier - Item` name, cost, hammer), `item` row for the placed piece, `look_names` entry (Kathleen), a `placed_sounds` kind (Jason), a `check_look_names` pass, and a line in `CONTROLS.md` only if an input changes. Taking a piece down gives the cost back (existing rule).

## 5. The catalogue, in build order

Priority order Dave gave: build pieces and fences first, then furniture, lights, garden, water. Each batch is one PR of about 10 to 14 rows. B0 comes first because metal rows depend on it. Numbers are provisional reservations.

### B0. Metal hammers (gate for every metal piece)

Ruling: hammers of any metal count as the top hammer tier. Today only the Wooden and Stone hammers exist (`design/TOOL_TIERS.md`), so no metal piece can be built until these three items exist. Hammer tier 3 = any of them. No blueprints in this batch.

Component and carried items (an item row and a recipe row each, no blueprint or state):

| Item | Recipe | Notes | Item / recipe |
|---|---|---|---|
| Bronze - Hammer | 1 bronze ingot, 1 stick, 1 twine | crafted at the forge (ruling 1) | 560 / 346 |
| Iron - Hammer | 1 iron ingot, 1 stick, 1 twine | same | 561 / 347 |
| Steel - Hammer | 1 steel ingot, 1 stick, 1 twine | same | 562 / 348 |

### B1a. Foundations, doorways, windows, ceiling (finish the five live tiers)

Also removes the workbench-station requirement from existing hammer blueprints (ruling 3, Jamie). Closes the holes in Jamie's tier table. Every piece sits on the existing 2 m grid; foundations share the 4 x 4 m footprint, 2 m stack step and 0.6 m max rise that #902 gave Stone, Thatch and Wooden.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Log - Foundation | 10 log, 6 stone, 2 twine | 4 x 4 x 0.3 | foundation anchors (8 wall, 4 ceiling, 5 roof); log sills on stone footings | 1 | 55 / 563 / 77 |
| 2 | Brick - Foundation | 16 brick, 4 mortar, 4 stone | 4 x 4 x 0.3 | same anchors; brick plinth | 1 | 56 / 564 / 78 |
| 3 | Log - Doorway | 5 log, 2 twine | 2.0 x 0.25 x 2.4 | wall edge; carries its plank-and-strap door | 1 | 57 / 565 / 79 |
| 4 | Stone - Doorway | 9 cut stone block, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; timber lintel and door | 1 | 58 / 566 / 80 |
| 5 | Brick - Doorway | 12 brick, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; timber door | 1 | 59 / 567 / 81 |
| 6 | Thatch - Window | 15 thatch, 8 stick, 3 twine | 2.0 x 0.25 x 2.4 | wall edge; open hole (as Wooden - Window) | 1 | 60 / 568 / 82 |
| 7 | Log - Window | 5 log, 2 twine | 2.0 x 0.25 x 2.4 | wall edge; open hole | 1 | 61 / 569 / 83 |
| 8 | Stone - Window | 9 cut stone block, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; open hole, stone sill | 1 | 62 / 570 / 84 |
| 9 | Brick - Window | 12 brick, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; open hole, brick arch | 1 | 63 / 571 / 85 |

Reserves blueprints 55-63, items 563-571, states 77-85.

### B1b. Stairs, railings, extra doors

Stairs exist only in wood (and are the one name that breaks `Tier - Item`). Upper floors need a railing, or players fall off ceilings.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Log - Stairs | 8 log, 2 twine | 1.0 x 2.4 x 2.4 | as Wooden - Stairs: foundation or ceiling edge up to the next ceiling | 1 | 64 / 572 / 86 |
| 2 | Stone - Stairs | 20 cobblestone, 4 mortar | 1.0 x 2.4 x 2.4 | as above | 1 | 65 / 573 / 87 |
| 3 | Brick - Stairs | 20 brick, 4 mortar | 1.0 x 2.4 x 2.4 | as above | 1 | 66 / 574 / 88 |
| 4 | Wooden - Railing | 2 lumber, 1 twine | 2.0 x 0.1 x 1.0 | ceiling and stair edge; stops falls; end to end | 1 | 67 / 575 / 89 |
| 5 | Iron - Railing | 2 iron ingot, 4 nails | 2.0 x 0.1 x 1.0 | as above; hammer 3 | 3 | 68 / 576 / 90 |
| 6 | Wooden - Double doorway | 6 lumber, 2 twine, 2 hinges | 4.0 x 0.25 x 2.4 | two adjacent wall cells; look door_double (already planned) | 1 | 69 / 577 / 91 |
| 7 | Iron - Doorway | 3 lumber, 2 iron ingot, 12 nails, 2 hinges | 2.0 x 0.25 x 2.4 | reinforced door; look door_wrought; hammer 3 | 3 | 70 / 578 / 92 |
| 8 | Steel - Doorway | 6 steel ingot, 2 hinges | 2.0 x 0.25 x 2.4 | look door_steel; hammer 3 | 3 | 71 / 579 / 93 |

Reserves blueprints 64-71, items 572-579, states 86-93.

### B1c. Pillars and roof corners

Pillars were decided on 22 Oct (centre and four corners of a foundation cell or ceiling). Roof corners finish the roofs; 65 degree variants wait for Dave's call (section 8).

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Thatch - Pillar | 6 stick, 2 twine | 0.4 x 0.4 x 2.6 | pillar anchors on foundation/ceiling cell | 1 | 72 / 580 / 94 |
| 2 | Wooden - Pillar | 2 lumber, 1 twine | 0.4 x 0.4 x 2.6 | same | 1 | 73 / 581 / 95 |
| 3 | Log - Pillar | 1 log, 1 twine | 0.4 x 0.4 x 2.6 | same | 1 | 74 / 582 / 96 |
| 4 | Stone - Pillar | 8 cobblestone, 2 mortar | 0.5 x 0.5 x 2.6 | same | 1 | 75 / 583 / 97 |
| 5 | Brick - Pillar | 8 brick, 2 mortar | 0.5 x 0.5 x 2.6 | same | 1 | 76 / 584 / 98 |
| 6 | Thatch - Roof corner | 4 twine, 18 thatch, 8 stick | 2.4 x 2.4 x 2.6 | roof edge; cost = 0.6 x the straight roof, rounded up: 4 twine, 18 thatch, 8 stick | 1 | 77 / 585 / 99 |
| 7 | Wooden - Roof corner | 3 lumber, 2 twine, 2 stick | 2.4 x 2.4 x 2.6 | 0.6 x Wooden - Roof | 1 | 78 / 586 / 100 |
| 8 | Log - Roof corner | 3 log, 12 thatch, 2 twine | 2.4 x 2.4 x 2.6 | 0.6 x Log - Roof | 1 | 79 / 587 / 101 |
| 9 | Stone - Roof corner | 12 stone shingle, 4 lumber | 2.4 x 2.4 x 2.6 | 0.6 x Stone - Roof | 1 | 80 / 588 / 102 |
| 10 | Brick - Roof corner | 10 brick, 4 lumber | 2.4 x 2.4 x 2.6 | 0.6 x Brick - Roof | 1 | 81 / 589 / 103 |

Reserves blueprints 72-81, items 580-589, states 94-103.

### B2. Fences and gates

Every live tier plus iron. A fence section is 2 m long with a post at each end (neighbours share the post), stands on bare ground (no foundation), turns at 45 or 90 degrees, follows the ground within 1.0 m rise, cap 200 per chunk. A gate fills one section and opens like a door.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Thatch - Fence | 12 stick, 2 twine | 2.0 x 0.2 x 1.0 | stake and wattle, lashed | 1 | 82 / 590 / 104 |
| 2 | Thatch - Gate | 14 stick, 3 twine | 2.0 x 0.2 x 1.0 | wattle hurdle on twine hinges | 1 | 83 / 591 / 105 |
| 3 | Wooden - Fence | 3 lumber, 1 twine | 2.0 x 0.15 x 1.1 | picket | 1 | 84 / 592 / 106 |
| 4 | Wooden - Gate | 3 lumber, 1 twine, 1 hinges | 2.0 x 0.15 x 1.1 | plank gate with a Z brace | 1 | 85 / 593 / 107 |
| 5 | Log - Fence | 3 log, 1 twine | 2.0 x 0.2 x 1.1 | split rail into pegged posts | 1 | 86 / 594 / 108 |
| 6 | Log - Gate | 4 log, 2 twine | 2.0 x 0.2 x 1.1 | rail gate | 1 | 87 / 595 / 109 |
| 7 | Log - Palisade | 6 log, 2 twine | 2.0 x 0.4 x 2.6 | pointed stakes; blocks goblins and wolves; cap 100 per chunk | 1 | 88 / 596 / 110 |
| 8 | Log - Palisade gate | 8 log, 3 twine, 2 hinges | 2.0 x 0.4 x 2.6 | palisade section that opens | 1 | 89 / 597 / 111 |
| 9 | Stone - Fence | 10 cobblestone | 2.0 x 0.4 x 1.0 | low dry-stone wall with capstones; no mortar | 1 | 90 / 598 / 112 |
| 10 | Stone - Gate | 6 cobblestone, 3 lumber, 2 hinges | 2.0 x 0.4 x 1.2 | timber gate between stone piers | 1 | 91 / 599 / 113 |
| 11 | Brick - Fence | 10 brick, 2 mortar | 2.0 x 0.3 x 1.1 | brick on a stone plinth | 1 | 92 / 600 / 114 |
| 12 | Brick - Gate | 6 brick, 2 mortar, 3 lumber, 2 hinges | 2.0 x 0.3 x 1.2 | timber gate between brick piers | 1 | 93 / 601 / 115 |
| 13 | Iron - Fence | 3 iron ingot, 6 nails | 2.0 x 0.1 x 1.4 | railing on a brick plinth; hammer 3 | 3 | 94 / 602 / 116 |
| 14 | Iron - Gate | 4 iron ingot, 2 hinges | 2.0 x 0.1 x 1.4 | hammer 3 | 3 | 95 / 603 / 117 |

Reserves blueprints 82-95, items 590-603, states 104-117.

### B3. Furniture tiers and work benches

Furniture is wood-only today. Add log, stone and iron-bound versions of the bench, table and chair, two stone and iron work benches, and storage furniture. Free-placed (no grid), cap 12 per chunk. The existing Bench, Chair, Table are renamed Wooden - Bench, Wooden - Chair, Wooden - Table (display only, ids kept). Station level and which recipes each work bench unlocks belong to Steve and Tyler; this batch only supplies the placeable pieces.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Log - Bench | 2 log, 1 twine | 2.0 x 0.4 x 0.45 | seats 2; no workbench needed | 1 | 96 / 604 / 118 |
| 2 | Log - Table | 3 log, 2 twine | 1.4 x 0.7 x 0.8 | hand-hewn top | 1 | 97 / 605 / 119 |
| 3 | Stone - Bench | 10 cobblestone, 2 mortar | 2.0 x 0.4 x 0.45 | heavy; cannot be moved, only taken down | 1 | 98 / 606 / 120 |
| 4 | Stone - Table | 14 cobblestone, 3 mortar, 2 lumber | 1.4 x 0.8 x 0.85 | thick top, stone-footed | 1 | 99 / 607 / 121 |
| 5 | Iron - Bench | 4 lumber, 1 iron ingot, 12 nails | 2.0 x 0.4 x 0.45 | iron-bound timber; hammer 3 | 3 | 100 / 608 / 122 |
| 6 | Iron - Chair | 4 lumber, 1 iron ingot, 12 nails, 1 hide | 0.6 x 0.6 x 0.9 | hammer 3 | 3 | 101 / 609 / 123 |
| 7 | Iron - Table | 6 lumber, 1 iron ingot, 20 nails | 1.4 x 0.7 x 0.8 | hammer 3 | 3 | 102 / 610 / 124 |
| 8 | Stone - Workbench | 20 cobblestone, 4 mortar, 6 lumber | 2.0 x 1.0 x 0.9 | stone-topped; station tier large; takes the tool rack and vice add-ons | 1 | 103 / 611 / 125 |
| 9 | Iron - Workbench | 12 lumber, 3 iron ingot, 80 nails | 2.0 x 1.0 x 0.9 | iron vice bench; station tier epic; hammer 3 | 3 | 104 / 612 / 126 |
| 10 | Wooden - Shelf | 3 lumber, 1 twine | 1.2 x 0.3 x 1.2 | container: 8 slots, 30 kg; wall-hugging | 1 | 105 / 613 / 127 |
| 11 | Wooden - Cupboard | 6 lumber, 12 nails, 2 hinges | 1.0 x 0.5 x 1.8 | container: 16 slots, 60 kg; closes (hides contents) | 1 | 106 / 614 / 128 |
| 12 | Wooden - Barrel | 4 lumber, 2 twine, 8 nails | 0.7 x 0.7 x 0.9 | container: 8 slots, 60 kg; or holds 100 L water (see B6) | 1 | 107 / 615 / 129 |

Reserves blueprints 96-107, items 604-615, states 118-129.

### B4. Lights: lanterns, torch posts, lamp posts, braziers

No lantern exists, only the held torch. Reference: a torch gives 12 m of light and 8 m of wolf protection (Dave). All lights use the one flame colour Color(1.0, 0.65, 0.15) (Kathleen). Burn times are in game days (1 game day = 1 real hour) and are first-pass numbers for Steve to tune. A lantern is rain-proof (horn panes), unlike a torch.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Wooden - Hanging lantern | 1 lumber, 1 twine, 2 horn pane, 1 candle | 0.3 x 0.3 x 0.4 | hooks to a ceiling or wall beam; 8 m light; 1 candle burns 1 game day | 1 | 108 / 616 / 130 |
| 2 | Iron - Hanging lantern | 1 iron ingot, 2 horn pane, 1 lamp oil | 0.3 x 0.3 x 0.4 | hooks to a ceiling or wall beam; 14 m; 1 lamp oil burns 3 game days; hammer 3 | 3 | 109 / 617 / 131 |
| 3 | Iron - Wall lantern | 1 iron ingot, 2 horn pane, 1 lamp oil | 0.3 x 0.3 x 0.5 | bracket arm on a wall edge; 14 m; hammer 3 | 3 | 110 / 618 / 132 |
| 4 | Wooden - Torch post | 1 log, 1 twine, 2 tallow | 0.3 x 0.3 x 2.2 | hammer-built standing torch with a pitch-soaked head; 12 m; burns out in the open rain like a torch | 1 | 111 / 619 / 133 |
| 5 | Stone - Torch pillar | 8 cobblestone, 2 mortar, 1 iron ingot, 2 tallow | 0.5 x 0.5 x 2.0 | stone pillar with an iron bowl; 12 m; rain-shielded by the bowl hood; hammer 3 | 3 | 112 / 620 / 134 |
| 6 | Iron - Torch stand | 2 iron ingot, 2 tallow | 0.3 x 0.3 x 1.8 | 12 m; hammer 3 | 3 | 113 / 621 / 135 |
| 7 | Wooden - Lamp post | 3 lumber, 2 twine, 1 Wooden - Lantern | 0.3 x 0.3 x 3.0 | lantern on a pole, hook arm; 10 m; candle lasts 1 game day | 1 | 114 / 622 / 136 |
| 8 | Iron - Lamp post | 4 iron ingot, 1 Iron - Lantern | 0.3 x 0.3 x 3.4 | 16 m; oil lasts 3 game days; hammer 3 | 3 | 115 / 623 / 137 |
| 9 | Stone - Lamp post | 8 cobblestone, 2 mortar, 1 Iron - Lantern | 0.5 x 0.5 x 3.0 | lantern on a stone post; 16 m; hammer 3 for the lantern | 3 | 116 / 624 / 138 |
| 10 | Stone - Brazier | 12 cobblestone, 3 mortar | 0.8 x 0.8 x 0.7 | burns logs/firewood from the pack; 10 m light and 4 m warmth; counts as a fire for comfort | 1 | 117 / 625 / 139 |
| 11 | Iron - Brazier | 3 iron ingot | 0.7 x 0.7 x 0.8 | same; portable (take down returns the iron); hammer 3 | 3 | 118 / 626 / 140 |

Reserves blueprints 108-118, items 616-626, states 130-140.

Component and carried items (an item row and a recipe row each, no blueprint or state):

| Item | Recipe | Notes | Item / recipe |
|---|---|---|---|
| Horn pane | 1 antler -> 2 panes | workbench; thin scraped horn (no glass yet, Kathleen) | 627 / 349 |
| Lamp oil | 3 tallow -> 1 lamp oil | campfire pot; fuel for Iron lanterns | 628 / 350 |
| Wooden - Lantern (carried) | 1 lumber, 1 twine, 2 horn pane, 1 candle | left-hand item like the torch; 8 m; Steve decides the hotbar rule | 629 / 351 |
| Iron - Lantern (carried) | 1 iron ingot, 2 horn pane, 1 lamp oil | left-hand item; 14 m; also the lantern consumed by lamp posts | 630 / 352 |

### B5. Garden: plots, planters, compost

Only the flower pot and the tilled bed exist. Plots are framed beds on the 2 m grid that hold a 2 x 2 area of tilled soil, sit on bare ground (no foundation), and use the existing seeds and farming rhythm. Moisture is a 0 to 100 value per plot. Rain sets it to 100 in heavy rain; it falls each game day by 15 percent (hot) or 5 percent (cool) times the tier factor; a bucket press adds 8 percent to a 2 x 2 plot; an adjacent open channel or pipe outlet tops it up automatically (B6). Tier factors: tilled bed 1.0, Thatch 0.85, Wooden 0.7, Stone and Brick 0.6 (frames hold water in).

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Thatch - Garden plot | 10 stick, 2 twine, 6 soil | 2.0 x 2.0 x 0.3 | stick-edged bed; grid cell; E plants/tends like a tilled bed | 1 | 119 / 631 / 141 |
| 2 | Wooden - Garden plot | 8 lumber, 2 twine, 6 soil | 2.0 x 2.0 x 0.4 | plank raised bed | 1 | 120 / 632 / 142 |
| 3 | Stone - Garden plot | 10 cobblestone, 2 mortar, 6 soil | 2.0 x 2.0 x 0.4 | stone-edged bed | 1 | 121 / 633 / 143 |
| 4 | Brick - Garden plot | 10 brick, 2 mortar, 6 soil | 2.0 x 2.0 x 0.4 | brick bed | 1 | 122 / 634 / 144 |
| 5 | Wooden - Planter box | 2 lumber, 2 soil | 0.8 x 0.3 x 0.3 | window box: 2 herbs/flowers; free placed | 1 | 123 / 635 / 145 |
| 6 | Stone - Planter | 6 cobblestone, 1 mortar, 3 soil | 0.8 x 0.8 x 0.6 | big pot: 1 dwarf shrub or herb | 1 | 124 / 636 / 146 |
| 7 | Wooden - Trellis | 10 stick, 4 twine | 1.6 x 0.1 x 2.0 | climbing crops (beans, hops later); beside a plot | 1 | 125 / 637 / 147 |
| 8 | Wooden - Compost bin | 4 lumber, 1 twine | 1.0 x 1.0 x 0.8 | takes plant waste and manure; yields Compost (item 345) after 3 game days | 1 | 126 / 638 / 148 |
| 9 | Thatch - Scarecrow | 6 stick, 10 thatch, 2 twine | 0.6 x 0.6 x 2.0 | keeps crows off plots within 6 m (ties to the crow sign in the creature plan) | 1 | 127 / 639 / 149 |
| 10 | Wooden - Cold frame | 3 lumber, 1 twine, 4 horn pane | 1.0 x 1.0 x 0.5 | plot cover: protects seedlings from frost | 1 | 128 / 640 / 150 |

Reserves blueprints 119-128, items 631-640, states 141-150.

### B6a. Water 1: well, hand pumps, troughs, wooden channels

Nothing on the hammer touches water today except the held bucket. This batch is the source, the tanks and the first conduit. The flow rules are in section 6; they are a proposal for Sonny and Steve to confirm. Interim placement rule until the watershed record exists: within 30 m of a fresh-water surface and no more than 5 m above it.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Stone - Well | 30 cobblestone, 8 mortar, 4 lumber, 1 rope, 1 bucket | 1.6 x 1.6 x 1.1 | place where the water table is within 12 m; windlass and bucket: E draws 10 L; shared footprint with a pump on its cap | 1 | 129 / 641 / 151 |
| 2 | Wooden - Hand pump | 6 lumber, 20 nails, 2 twine, 1 hide | 0.5 x 0.5 x 1.1 | old style lever pump on a bored shaft; place where the water table is within 7 m (suction limit); hold E: 2 L/s into a held container or the connected chain | 1 | 130 / 642 / 152 |
| 3 | Iron - Hand pump | 6 iron ingot, 1 hide, 1 hinges | 0.5 x 0.5 x 1.1 | cast-iron pitcher pump: handle, spout, plinth; same rule, 3 L/s; hammer 3 | 3 | 131 / 643 / 153 |
| 4 | Log - Trough | 2 log, 1 twine | 1.6 x 0.5 x 0.5 | hollow log; holds 60 L; animals drink here | 1 | 132 / 644 / 154 |
| 5 | Wooden - Trough | 4 lumber, 1 twine | 2.0 x 0.6 x 0.5 | holds 100 L; animals drink here; can sit at a channel end | 1 | 133 / 645 / 155 |
| 6 | Wooden - Rain barrel | 4 lumber, 2 twine, 8 nails | 0.7 x 0.7 x 0.9 | holds 100 L; collects 20 L per game hour of rain within a roof's reach; same 100 L as the storage Wooden - Barrel (B3), one piece type | 1 | 134 / 646 / 156 |
| 7 | Wooden - Channel | 3 lumber, 1 twine | 2.0 x 0.4 x 0.3 | open flume on trestles, straight; ports at both ends | 1 | 135 / 647 / 157 |
| 8 | Wooden - Channel corner | 3 lumber, 1 twine | 2.0 x 2.0 x 0.3 | 90 degree turn | 1 | 136 / 648 / 158 |
| 9 | Wooden - Channel tee | 4 lumber, 1 twine | 2.0 x 2.0 x 0.3 | splits flow; the branch carries a sluice setting | 1 | 137 / 649 / 159 |
| 10 | Wooden - Sluice | 2 lumber, 1 hinges | 2.0 x 0.4 x 0.6 | gate: E opens/closes, a channel piece with a closed/open port | 1 | 138 / 650 / 160 |

Reserves blueprints 129-138, items 641-650, states 151-160.

### B6b. Water 2: stone and pipe conduits, deep pump, taps

Later water tier. Closed pipes can run level with the ground and carry more water than an open flume. Clay pipe is fired like bricks; iron pipe needs a forge.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Stone - Trough | 12 cobblestone, 3 mortar | 2.0 x 0.7 x 0.6 | holds 200 L; carved, never freezes through | 1 | 139 / 651 / 161 |
| 2 | Stone - Channel | 8 cobblestone, 2 mortar | 2.0 x 0.5 x 0.3 | straight; 60 L/min at 2 percent fall | 1 | 140 / 652 / 162 |
| 3 | Stone - Channel corner | 8 cobblestone, 2 mortar | 2.0 x 2.0 x 0.3 | 90 degree turn | 1 | 141 / 653 / 163 |
| 4 | Stone - Channel tee | 10 cobblestone, 2 mortar | 2.0 x 2.0 x 0.3 | split | 1 | 142 / 654 / 164 |
| 5 | Clay - Pipe | 2 clay pipe | 2.0 x 0.3 x 0.3 | closed straight; 40 L/min; cracks in hard frost unless drained | 1 | 143 / 655 / 165 |
| 6 | Clay - Pipe elbow | 2 clay pipe | 2.0 x 2.0 x 0.3 | 90 degrees | 1 | 144 / 656 / 166 |
| 7 | Clay - Pipe tee | 3 clay pipe | 2.0 x 2.0 x 0.3 | split | 1 | 145 / 657 / 167 |
| 8 | Iron - Pipe | 2 iron ingot | 2.0 x 0.2 x 0.2 | closed straight; 80 L/min; carries water uphill when a pump pushes (head); hammer 3 | 3 | 146 / 658 / 168 |
| 9 | Iron - Pipe elbow | 2 iron ingot | 2.0 x 2.0 x 0.2 | hammer 3 | 3 | 147 / 659 / 169 |
| 10 | Iron - Tap | 1 iron ingot, 1 hinges | 0.3 x 0.3 x 0.4 | shut-off at a pipe end or over a trough; E opens/closes; hammer 3 | 3 | 148 / 660 / 170 |
| 11 | Iron - Deep-well pump | 8 iron ingot, 2 hide, 2 hinges, 12 nails | 0.8 x 0.8 x 1.6 | on a Stone - Well; lifts from up to 25 m; 2 L/s; two players or an animal can work it; hammer 3 | 3 | 149 / 661 / 171 |
| 12 | Stone - Cistern | 24 cobblestone, 6 mortar | 2.0 x 2.0 x 1.0 | holds 2,000 L; filled by a pipe or rain barrel overflow | 1 | 150 / 662 / 172 |

Reserves blueprints 139-150, items 651-662, states 161-172.

Component and carried items (an item row and a recipe row each, no blueprint or state):

| Item | Recipe | Notes | Item / recipe |
|---|---|---|---|
| Clay pipe | 3 clay -> 2 clay pipe | fire in the kiln/clay hearth like bricks | 663 / 353 |

## 6. Water flow rules (proposal for Sonny and Steve to confirm)

The aim is a small, cheap system that fits an old machine, reads the watershed rebuild's results, and stays out of the 2 m live water sim. It is a **graph**, like a power grid, not a fluid simulation.

**Pieces.** Sources (well, hand pump, deep-well pump, rain barrel, a river intake), tanks (troughs, barrels, cistern), conduits (channels, pipes, taps, sluices) and consumers (garden plots, animals drinking, players filling containers).

**Rules.**
1. **Ports.** Every conduit and tank has an inlet and an outlet with a ground height. Pieces snap end to end on the 2 m grid, so ports meet by construction; a trestle or plinth holds the piece at its height.
2. **Gravity.** Water moves from a higher outlet to a lower or equal inlet. A level run trickles at 5 L/min. A fall of 2 percent or more gives full rate: wooden channel 30 L/min, stone channel 60, clay pipe 40, iron pipe 80. Uphill needs a pump head (below).
3. **Pumps.** A hand pump runs only while a player holds E: 2 L/s (wooden), 3 L/s (iron), 2 L/s deep-well. It also gives 1.5 m of head, so it can fill a trough or a pipe raised up to 1.5 m. Hand pumps sit where the water table is within 7 m (the real suction limit); deeper needs the deep-well pump (up to 25 m) on a Stone - Well; a Stone - Well alone draws by bucket from up to 12 m.
4. **Splits and gates.** A tee splits flow equally between open branches. A sluice or tap shuts a branch. Closed branches get nothing and the rest take it.
5. **Tanks.** Troughs and barrels hold litres (60, 100, 200, 2,000). Full tanks stop taking water and the chain backs up; nothing overflows onto the ground in the first version.
6. **Consumers.** A garden plot beside a channel or pipe outlet draws what it needs: 1 L restores about 4 percent moisture to a 2 x 2 plot. Animals drink from a trough at their normal rate (hook for MikeW). A held container fills from a trough, well or pump as it does from water now (500 ml per press).
7. **Solving.** Server side and lazy: a network is re-solved only when a source starts or stops, a gate changes or a piece is added or taken away, in one downhill pass from the sources, splitting as above. A network is at most 64 pieces, at most 4 networks per chunk, and the budget is 1.5 ms per solve. Idle networks cost nothing (the lazy-resolution principle in `DESIGN_IDEAS.md` 3).
8. **Persistence.** Only the litres in each tank are saved, on its structure row. Pipes hold no water; the graph is rebuilt from positions on load.
9. **Frost** (later): open channels and troughs ice over below 0 C and stop; clay pipe cracks if frozen full, unless drained at a tap.

**Where it touches the rebuild, for Sonny to answer.**
- **Placement of wells and pumps.** `DESIGN_IDEAS.md` 4.9a already proposes a runtime "well water" value (depth to the water table from moisture, height above the nearest water and soil). The watershed record gives depth to the water table (rebuild C3, step R4/R6). Interim rule so B6 can start: within 30 m of fresh water and no more than 5 m above it, from the current baked water.
- **River intakes.** A Wooden - Channel touching a river could take water as accounting only (N L/min against the reach's recorded low-flow discharge, capped at 5 percent), with no change to the live surface. Recommended, because it ties diversion to the same discharge numbers that size the rivers. If Sonny prefers a real draw from the 2 m sim, B6 would need his API first.
- **Does anything here change the live sim?** Recommended: no.

**For Steve.** A server `water_network` module (graph, solve, tank save); the plot-moisture hook on the tilled bed rows; the held-container fill from structures; the "hold E to pump" action and exertion cost (recommended: light, like chopping a few logs' worth of effort per minute). **For MikeW.** Animals drinking from troughs is the first livestock water use. **For Kathleen.** Her water look table (hollow-log trough, plank trough and flume on trestles, carved stone trough, cast-iron pitcher pump, iron pipe with elbows and tap) maps one to one onto B6a and B6b.

## 7. Priority, PR order and owners

| Order | Batch | Rows | Needs first |
|---|---|---|---|
| 1 | B0 Metal hammers | 3 items | none |
| 2 | B1a Foundations, doorways, windows (and drop the workbench requirement on existing rows) | 9 | none (Jamie's first batch) |
| 3 | B1b Stairs, railings, extra doors | 8 | B0 for the iron rows |
| 4 | B1c Pillars and roof corners | 10 | anchor table for pillars (Steve) |
| 5 | B2 Fences and gates | 14 | B0 for iron rows |
| 6 | B3 Furniture tiers and work benches | 12 | B0 for iron rows; station levels from Steve and Tyler |
| 7 | B4 Lights | 11 plus 4 items | B0; horn pane and lamp oil recipes; burn rule from Steve |
| 8 | B5 Garden | 10 | plot moisture hook (Steve) |
| 9 | B6a Water 1 | 10 | flow rules confirmed by Sonny and Steve |
| 10 | B6b Water 2 | 12 plus 1 item | B6a |

Per batch the work is the same: **Jamie** data rows and numbers; **Kathleen** looks (headless bounds test, pictures from Dino); **Jason** one placed-sound kind per material; **Steve** the shared hooks named above; **Tyler** the gate and validators; **Dino** the picture check on Dave's PC. No test or bake runs in the cloud.

## 8. Not in this plan, and open points

- **Plank and Mason tiers** (decided 25 Oct, no pieces today), the **large and Mason foundations**, and **65 degree roofs**. Add after B1c if Dave still wants them; the numbering plan leaves room.
- **Shutters, chimneys, trapdoors, gutters** (a gutter would feed rain barrels automatically).
- **Windmill or water wheel pumps** for automatic water; the sawmill's wheel rule (needs running water) is the model.
- **A lamplighter NPC job** so town lamps light at dusk; until then a lantern is lit by hand (E).
- **Weight and carry** of the heavy stone pieces: taking them down returns materials, never the piece.
- **Numbering collisions:** Steve's anvil (#883) and #902 both want blueprint 54 (Jamie's note); this plan starts at 55.
- **Tuning:** every cost, light radius, burn time and flow rate is a first-pass number.
