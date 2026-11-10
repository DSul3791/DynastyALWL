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

## Numbering (Jamie, 10 Nov)

Committed on Jamie's stacked branches, not yet on main: B0 (items 560, 561; recipes 346, 347), B1a (above), **B2 fences and gates** blueprints 64 to 77, items 580 to 607 (kit then piece), states 92 to 112 (each gate has an open twin state right after it), **B1c pillars and roof corners** blueprints 78 to 87, items 608 to 627, states 113 to 122. Ids follow Kathleen's look names (`wood_fence`, `wood_gate`, `wooden_pillar`, `wooden_roof_corner`). **Next free: item 628, recipe 348, blueprint 88, state 123.** B1b (stairs, railings, double/iron/steel doorways) takes numbers from there once Steve rules on railings. **Where a later batch table below shows other numbers, the batch is renumbered from this list when it is scheduled.**

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
| Bronze - Hammer | 1 bronze ingot, 1 stick, 1 twine | **already exists** as bronze_hammer, future; becomes playable | 460 / 292 (live) |
| Iron - Hammer | 1 iron ingot, 1 stick, 1 twine | crafted at the forge, forge level 2 | 560 / 346 |
| Steel - Hammer | 1 steel ingot, 1 stick, 1 twine | crafted at the forge, forge level 3 | 561 / 347 |

All three are hammer tier 3 and future, like every iron and steel tool. Numbers confirmed by Jamie, 10 Nov.

### B1a. Foundations, doorways, windows, ceiling (finish the five live tiers)

Also removes the workbench-station requirement from existing hammer blueprints (ruling 3, Jamie). Closes the holes in Jamie's tier table. Every piece sits on the existing 2 m grid; foundations share the 4 x 4 m footprint, 2 m stack step and 0.6 m max rise that #902 gave Stone, Thatch and Wooden.

| # | Blueprint (Tier - Item) | Cost | Footprint m (w x d x h) | Snap, function | Hammer | Blueprint / item / state |
|---|---|---|---|---|---|---|
| 1 | Log - Foundation | 10 log, 6 stone, 2 twine | 4 x 4 x 0.3 | foundation anchors (8 wall, 4 ceiling, 5 roof); log sills on stone footings | 1 | 55 / 562/563 (kit / piece) / 79 |
| 2 | Brick - Foundation | 16 brick, 4 mortar, 4 stone | 4 x 4 x 0.3 | same anchors; brick plinth | 1 | 56 / 564/565 (kit / piece) / 80 |
| 3 | Log - Doorway | 5 log, 2 twine | 2.0 x 0.25 x 2.4 | wall edge; carries its plank-and-strap door | 1 | 57 / 566/567 (kit / piece) / 81 and 82 (open twin) |
| 4 | Stone - Doorway | 9 cut stone block, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; timber lintel and door | 1 | 58 / 568/569 (kit / piece) / 83 and 84 (open twin) |
| 5 | Brick - Doorway | 12 brick, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; timber door | 1 | 59 / 570/571 (kit / piece) / 85 and 86 (open twin) |
| 6 | Thatch - Window | 15 thatch, 8 stick, 3 twine | 2.0 x 0.25 x 2.4 | wall edge; open hole (as Wooden - Window) | 1 | 60 / 572/573 (kit / piece) / 87 |
| 7 | Log - Window | 5 log, 2 twine | 2.0 x 0.25 x 2.4 | wall edge; open hole | 1 | 61 / 574/575 (kit / piece) / 88 |
| 8 | Stone - Window | 9 cut stone block, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; open hole, stone sill | 1 | 62 / 576/577 (kit / piece) / 89 |
| 9 | Brick - Window | 12 brick, 3 mortar | 2.0 x 0.25 x 2.4 | wall edge; open hole, brick arch | 1 | 63 / 578/579 (kit / piece) / 90 |

**Numbers confirmed by Jamie, 10 Nov.** Blueprints 55 to 63, items 562 to 579 (each piece has a retired kit item, which the server keys placement on, then the piece item), states 79 to 90. Also state 91 is `thatch_doorway_open`, the fix for thatch doors turning wooden. `wood_foundation` moved to state 78, because 76 and 77 are the fire's coals and ash.

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
| 1 | Stone - Well | 30 cobblestone, 8 mortar, 4 lumber, 1 rope, 1 bucket | 1.6 x 1.6 x 1.1 | place where the water table is within 25 m (interim rule, section 6); windlass and bucket: E draws 10 L; shared footprint with a pump on its cap | 1 | 129 / 641 / 151 |
| 2 | Wooden - Hand pump | 6 lumber, 20 nails, 2 twine, 1 hide | 0.5 x 0.5 x 1.1 | old style lever pump on a bored shaft; place where the water table is within 7 m (suction limit); hold E: 0.8 L/s cap into a held container, trough or channel under the spout (lifts only) | 1 | 130 / 642 / 152 |
| 3 | Iron - Hand pump | 6 iron ingot, 1 hide, 1 hinges | 0.5 x 0.5 x 1.1 | cast-iron pitcher pump: handle, spout, plinth; same rule, 1.2 L/s cap; hammer 3 | 3 | 131 / 643 / 153 |
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
| 2 | Stone - Channel | 8 cobblestone, 2 mortar | 2.0 x 0.5 x 0.3 | straight; 300 L/min cap at 0.5 percent fall | 1 | 140 / 652 / 162 |
| 3 | Stone - Channel corner | 8 cobblestone, 2 mortar | 2.0 x 2.0 x 0.3 | 90 degree turn | 1 | 141 / 653 / 163 |
| 4 | Stone - Channel tee | 10 cobblestone, 2 mortar | 2.0 x 2.0 x 0.3 | split | 1 | 142 / 654 / 164 |
| 5 | Clay - Pipe | 2 clay pipe | 2.0 x 0.3 x 0.3 | closed straight; 120 L/min; cracks in hard frost unless drained | 1 | 143 / 655 / 165 |
| 6 | Clay - Pipe elbow | 2 clay pipe | 2.0 x 2.0 x 0.3 | 90 degrees | 1 | 144 / 656 / 166 |
| 7 | Clay - Pipe tee | 3 clay pipe | 2.0 x 2.0 x 0.3 | split | 1 | 145 / 657 / 167 |
| 8 | Iron - Pipe | 2 iron ingot | 2.0 x 0.2 x 0.2 | closed straight; 240 L/min; carries water uphill only when the deep-well force pump pushes (head); hammer 3 | 3 | 146 / 658 / 168 |
| 9 | Iron - Pipe elbow | 2 iron ingot | 2.0 x 2.0 x 0.2 | hammer 3 | 3 | 147 / 659 / 169 |
| 10 | Iron - Tap | 1 iron ingot, 1 hinges | 0.3 x 0.3 x 0.4 | shut-off at a pipe end or over a trough; E opens/closes; hammer 3 | 3 | 148 / 660 / 170 |
| 11 | Iron - Deep-well pump | 8 iron ingot, 2 hide, 2 hinges, 12 nails | 0.8 x 0.8 x 1.6 | on a Stone - Well; force pump: lifts from up to 25 m and pushes up to 10 m above its spout into an iron pipe; 1.0 L/s cap; two players or an ox for full rate; hammer 3 | 3 | 149 / 661 / 171 |
| 13 | Stone - Raised cistern | 28 cobblestone, 8 mortar, 6 lumber | 2.0 x 2.0 x 3.0 | cistern on a stone plinth up to 10 m above ground; filled by the deep-well force pump through an iron pipe; feeds a gravity main from its rim overflow port | 1 | (to number) |
| 12 | Stone - Cistern | 24 cobblestone, 6 mortar | 2.0 x 2.0 x 1.0 | holds 2,000 L; filled by a pipe or rain barrel overflow; has a rim overflow port | 1 | 150 / 662 / 172 |

Reserves blueprints 139-150, items 651-662, states 161-172.

Component and carried items (an item row and a recipe row each, no blueprint or state):

| Item | Recipe | Notes | Item / recipe |
|---|---|---|---|
| Clay pipe | 3 clay -> 2 clay pipe | fire in the kiln/clay hearth like bricks | 663 / 353 |

## 6. Water flow rules (approved: Sonny, 10 Nov 2026)

Source of the amendments: `buildables/water_flow_rules_sonny.md`. The graph model is approved (lazy solving, 1.5 ms budget), river intake is **accounting only**, and nothing here changes the live water sim. The aim is a small graph, like a power grid, not a fluid simulation.

**Pieces.** Sources (well, hand pump, deep-well pump, rain barrel, river intake), tanks (troughs, barrels, cisterns), conduits (channels, pipes, taps, sluices) and consumers (garden plots, animals drinking, players filling containers).

**Rules.**
1. **Ports and direction.** Every conduit and tank has an inlet and an outlet with a ground height. Pieces snap end to end on the 2 m grid. **Flow direction is fixed when a piece is placed** (an arrow on the ghost, inlet to outlet). A piece that would close a loop joins nothing, so every network is acyclic and the solve is one pass.
2. **Open channels need a fall the whole way.** Full rate from **0.5 percent** (1 cm per 2 m piece), half rate from 0.1 percent, a level run trickles at 5 L/min. A snapped piece takes its inlet from the last outlet and sets its own outlet 1 cm lower by default, so players never fiddle with falls. Trestles stretch to the ground.
3. **Closed pipes need only head end to end.** Water flows when the outlet is lower than the source's water surface (a tank level or a force pump's push). The route may rise and fall in between as long as every point stays below that surface. No siphon over a point above the source (needs priming). Full rate from 1 m of head, in proportion under that.
4. **Conduit caps (game caps):** wooden channel 120 L/min, stone channel 300, clay pipe 120, iron pipe 240.
5. **Pump rates come from effort:** Q (L/s) = P (W) / (9.81 H (m)), P about 40 W for a simple piston pump with one player (50 W for the iron hand pump), H = depth to the table plus 1 m to the spout. Caps: **Wooden - Hand pump 0.8 L/s, Iron - Hand pump 1.2 L/s, Iron - Deep-well pump 1.0 L/s** (two players 80 W, an ox or horse 150 W). Pumping from deep is honest work, about as hard as sawing.
6. **Hand pumps lift, they cannot push.** Water starts at spout height (about 1 m) and runs by gravity from there. It pours into a held container, a trough beside it, or a channel whose inlet sits under the spout. **No 1.5 m of head.** Suction limit 7 m, minus 1 m per 1,000 m of height.
7. **The deep-well pump is the force pump.** It pushes water up to **10 m above its spout** into an iron pipe, filling a raised cistern that feeds a town by gravity (B6b). It needs two players or an ox for full rate.
8. **Wells go to 25 m**, so the deep pump has a reason to exist. Bucket draw time is about 4 s plus 1.5 s per metre for 10 L (22 s at 12 m, 42 s at 25 m). No drawdown in the first version.
9. **Where wells and pumps may go (interim):** depth to the table is the ground height minus the level of the nearest fresh water within 200 m (river, lake or spring pool from the 8 m levels, never the sea). Beyond 200 m of fresh water, no well or pump. When Sonny's `depth_to_table_m` layer (16 m, `groundwater.npz`) reaches the tiles, wells and pumps read it directly and this rule goes. It overstates depth under slopes, so any spot it allows truly has water.
10. **River intakes (accounting only).** A channel or pipe inlet below the river surface where the 8 m levels show water. Until reach low-flow discharges are in the tiles, cap each intake at **60 L/min** and allow **one intake per 50 m** of river. The live sim never sees it.
11. **Splits and tanks.** A tee splits equally between open branches; a full tank downstream counts as a closed branch. **Every tank has a rim overflow port**: a full tank passes its inflow through it when something is connected, otherwise the chain backs up. Nothing spills onto the ground.
12. **Solving.** Server side and lazy. Litres in a tank are worked out lazily: litres at the last event plus net rate times time since, computed only when read or saved. Events: a source starts or stops, a gate changes, a piece is added or taken away, **a tank becomes full or empty, a plot reaches full moisture.** The last two are scheduled, their times being known from the net rate. **Networks hold up to 256 pieces**, at most 4 per chunk, 1.5 ms solve budget (an estimate; measure on David4 with Steve's module).
13. **Persistence.** Only the litres in each tank are saved. Pipes hold no water; the graph rebuilds from positions on load.
14. **Frost (later):** open channels and troughs ice over below 0 C; clay pipe cracks if frozen full unless drained at a tap.
15. **Plots and quality (hooks for Steve).** 1 L on a 2 x 2 plot is 0.25 mm. Plot loss follows the weather's evaporation: 12 to 20 L a day per plot in summer, less in cool weather, none in rain. Water is tagged by source: well, pump and rain are clean; river intake is river water; water standing in a trough or cistern for more than a few game days is still water. The sickness table is Steve's (`docs/water/springs_and_drinking_water.md`).

**Sonny still owes:** the `depth_to_table_m` layer and the reach low-flow discharge in the tiles, after the playtest.

**For Steve.** A server `water_network` module (graph, solve, tank save); the plot-moisture hook on the tilled bed rows; the held-container fill from structures; the "hold E to pump" action and its exertion cost.

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
