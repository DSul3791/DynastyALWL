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

## 7. Bridges: blueprints in 5 m, 10 m and 20 m, per tier (Dave 15:55 UTC; plan only, build after the devstop)
Placed like a foundation: scroll wheel turns it, Shift + scroll raises or lowers it. Each blueprint is a whole bridge: deck, a sloping ramp at BOTH ends, and its own supports where the span needs them. 2 m wide (one grid cell); a wide version is a later size row. A ford (shallow stepping stones) is terrain and needs no piece.

### Sizes, tiers and materials (rows in a table; more or adjusted sizes are a row edit)
Deck length is between the ramps; ramps are extra. Cost is per metre of deck; supports are paid for in the same blueprint.
| tier | deck per metre | support (post/pier) | max free span | sizes | load (whole bridge) | in a flood |
|---|---|---|---|---|---|---|
| 1 Basic (log and rope) | 1 log + 3 sticks + 4 twine | none | 5 m | 5 m only | 300 kg | washes out when the deck is wet or flow over 2 m/s |
| 2 Plank | 3 rough planks + 4 nails | log trestle every 5 m: 4 logs + 8 nails per metre of height | 5 m | 5, 10, 20 | 500 kg | washes out (deck wet or flow over 2 m/s) |
| 3 Fine wood | 2 lumber + 6 nails | lumber trestle every 5 m: 4 lumber + 12 nails per m of height | 5 m | 5, 10, 20 | 800 kg | washes out (deck wet or flow over 2.5 m/s) |
| 4 Log | 2 logs + 4 wooden pins | log crib pier every 6 m: 6 logs per m of height | 6 m | 5, 10, 20 | 1,500 kg | holds to 0.5 m of water over the deck and 3 m/s |
| 5 Cobblestone | 6 cobblestones + 1 mortar | stone pier every 8 m: 12 cobblestones + 4 mortar per m of height | 8 m | 5, 10, 20 | 3,000 kg | holds to 1.5 m over the deck and 4 m/s |
| 6 Mason | 3 cut stone blocks + 1 mortar | mason pier every 10 m: 6 cut blocks + 4 mortar per m of height | 10 m | 5, 10, 20 | 6,000 kg | holds to 1.5 m over the deck and 5 m/s |
Ramps: slope 1 in 6, never steeper; length is set from the deck height above the ground at that end (a 1 m rise is a 6 m ramp, capped at 12 m); ramp material is the deck material per metre. Washed-out wooden bridges drop half their wood downstream.

### Placement (reuses the foundation code)
- Same path as `foundation_section`: kit item, `piece: true`, `footprint_x` = length, `footprint_z` = 2, grid snap 2 m, ghost green/red with a reason (`PlacementRules`), ACT_PLACE with lift steps, yaw and position (`held_item.gd` `_blueprint_*`).
- Turn: scroll wheel, 15 degree steps for bridges (foundations keep their grid turn). Raise/lower: Shift + scroll, 0.25 m steps, up to 12 m above the ground (foundations stay 0.1 m, 1 m). Both shown in the ghost caption.
- The ghost builds the ramps itself: it samples the ground at each end and lengthens the ramp to meet it. The server repeats the sampling and refuses if a ramp end is more than 0.3 m off the ground, if a support stands on a cell with more than 0.3 m of fast water (speed over the tier limit), or if the deck underside is under the flood height + 0.5 m ("deck is under flood level"; until the flood plan has that height it is the river depth + 1 m).
- One blueprint per size and tier (18 kits, ids `bridge_<tier>_<size>m_kit`) generated from the size table by a script, so adding 15 m or 30 m is a row.
- Open question for Dave (card posted): supports built into the blueprint (my recommendation) or placed separately.

### Code and data changes
1. structures.json: `bridge` kind rows from the table above (deck_clear_m, max_flow_ms, load_kg, support spacing, tier). items.json and recipes.json: 18 kits (written by tools/gen_bridges.py from the table). Label RESTART.
2. placement_rules.gd: bridge footprint (length x 2), ground sampling at both ends, support cells check, flood-height rule, `lift_max_m` and `lift_step_m` per structure (foundations keep today's 0.1 m x 10).
3. held_item.gd: wheel handling by kind: bridge turns on wheel, lifts on Shift + wheel; foundation unchanged.
4. Look: Kathleen builds the deck, rails, ramps, trestle and pier meshes from length (parametric, like PieceLook).
5. Server: cover and walking collision for the deck and ramps (like a floor section), the once-a-minute footprint wash-out check from the flood plan (10.1 point 5), salvage drop on washout, saved in the same world_items rows.
6. Tests: placement rows (ramp meets ground, flood rule, steep bank refused), recipe table, wash-out of a plank bridge under test water, stone bridge stays.

Order: data and kits, then plank and log tiers with the flood check, then stone tiers.
