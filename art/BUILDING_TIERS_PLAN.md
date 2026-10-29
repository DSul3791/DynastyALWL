# Building tiers plan (revised BUILDING_PLAN point 1)
Sal_Crafts, 2026-10-22 20:40. Replaces "one piece plus a material skin". Dave 20:10-20:15: walls come in TIERS, each a real different build. Status: PROPOSED. No building code until Dave approves. Kathleen shows the looks; this page is items, recipes, foundations and what happens to what we already built.

## 1. The six tiers (Dave's words, my numbers)
| # | Tier | Made of | Wall thickness | Foundation | Roof | Floor |
|---|---|---|---|---|---|---|
| 1 | Basic | thatch, twine and sticks woven | 0.1 m | none (stakes in the ground) | thatch bundles | beaten earth with woven mat |
| 2 | Plank | rough planks, smooth side in, bark side out | 0.1 m | standard 4 x 4 m (what we have) | plank shingles | rough plank floor |
| 3 | Fine wood | quality lumber and nails | 0.15 m | standard 4 x 4 m | lumber, nailed | lumber, nailed |
| 4 | Log | large round logs, notched corners | 0.4 m | LARGE 6 x 6 m (3 x 3 cells) | log and bark | split-log floor |
| 5 | Cobblestone | cobblestones and mortar | 0.5 m | LARGE 6 x 6 m | slab or heavy plank on beams | flagstone |
| 6 | Mason | very large carved bricks, castle style | 0.6 m | MASON 8 x 8 m (4 x 4 cells), deep stone skirt | stone slab | cut stone block |

Every tier has the same five slots on the same 2 m grid, 2.4 m walls: wall, doorway, window wall, floor, roof. Only the foundation size differs (the grid does not change). A tier-1 house sits on the ground; tiers 2 and 3 use the standard slab; tiers 4 and 5 need the large slab; tier 6 the mason slab. Mixing tiers on one foundation is allowed (a fine-wood door in a log wall) because the slots match.

## 2. Items and recipes (all at a workbench level 1 unless said)
New ingredients (appended to items.json, none yet): **rough plank** (split from a log at a chopping block, 4 per log, bark on one face), **nails** (iron ingot at a forge: 1 ingot = 20 nails), **cobblestone** (workbench: 3 stone, a rounded rock; stack 20). Already there: sticks, cordage, plant fibre, **thatch** (gathered), lumber, logs, clay, sand, **mortar, stone block, brick** (build 671).
| Piece | Basic | Plank | Fine wood | Log | Cobblestone | Mason |
|---|---|---|---|---|---|---|
| Wall | 6 sticks, 2 thatch, 1 cordage | 5 rough planks, 1 cordage | 4 lumber, 6 nails (replaces the cordage) | 3 logs, 1 cordage | 10 cobblestone, 2 mortar | 8 stone blocks, 3 mortar |
| Floor | 4 sticks, 2 thatch | 5 rough planks | 4 lumber, 6 nails | 3 logs | 8 cobblestone, 2 mortar | 6 stone blocks, 2 mortar |
| Roof | 6 thatch, 2 sticks, 1 cordage | 5 rough planks, 2 sticks, 2 cordage | 5 lumber, 8 nails | 4 logs, 2 bark | 4 lumber, 6 cobblestone, 2 mortar | 8 stone blocks, 2 mortar |
| Doorway / window | wall cost -1 stick | wall cost -1 plank | 3 lumber, 4 nails | wall cost | wall cost | wall cost |
| Foundation | - | standard: 8 stone, 2 clay (as now) | same | LARGE: 20 stone, 4 clay | LARGE + 4 mortar | MASON: 16 stone blocks, 6 mortar |
Carry weights follow the "never heavier than the inputs" rule. A mason wall of 8 stone blocks is about 200 kg, so it is built from the pack in pieces, not carried far (Dave can veto that).
Skills: higher tiers only need the building skill we already plan; no new skill.

## 3. What the build 671 items and the `material` field become
- **Stone block, mortar, brick, ladder stay.** Stone block + mortar are the mason and cobble inputs; brick stays for chimney, hearth and forge walls (not a wall tier). Ladder is unchanged (tier-agnostic).
- **`material` field on structures becomes `tier`** ("basic", "plank", "fine", "log", "cobble", "mason"). Existing pieces get "fine" (they are lumber walls). The word material stays only for item kind.
- **Pieces get one id per tier and slot** (30 states, appended from state 32; nothing renumbered). The existing wall, floor, roof, doorway, window and foundation ids stay and become the FINE WOOD tier and the standard foundation. Nothing already placed in the world changes.
- Wall thickness is in the footprint (footprint_z); a thick wall is centred on the grid line, so neighbouring tiers still join (corner and edge joins from the snap work keep working).
- Kathleen's `PieceLook` takes the tier, not a material skin. Sounds per tier go in structures.json `sound` (thatch, board, log, stone, brick-like for mason).

## 4. Order of work if you approve
1. Rough plank, nails, cobblestone items and the tier field (data, RESTART, small).
2. Fine wood and Plank tiers (cheap, wood only), then Basic.
3. Large foundation + Log and Cobblestone, then the mason foundation + Mason.
Stability (Ark-style) stays later. Ladder climbing stays with Steve.

## 5. Questions for Dave (recommendation first)
1. Are the existing lumber pieces the FINE WOOD tier (add nails to their recipe)? Recommend yes.
2. Foundation sizes 4 x 4 (standard), 6 x 6 (large), 8 x 8 (mason)? Recommend yes.
3. May tier-1 basic buildings sit on the bare ground with no foundation? Recommend yes (it is the first hut).
4. Rough planks come from splitting a log at a chopping block (4 per log)? Recommend yes.
5. Nails: 1 iron ingot = 20 nails at a forge? Recommend yes.
6. Mason walls so heavy you build them where you stand (about 200 kg)? Recommend yes.
