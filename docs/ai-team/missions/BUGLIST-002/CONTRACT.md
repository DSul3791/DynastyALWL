# BUGLIST-002 implementation contract (lead, 13 Nov 2026)

Authority: `docs/buglists/BUGLIST-002.md`, `docs/design/DYNASTY_MASTER_ITEMS.md` s3.0 and s3.2, `docs/design/buildables_plan.md`, `art/BUILDING_PLAN.md` (Dave's corrected documents, branch `buglist/002-door-system`). This file fixes the shared names, numbers and data shapes so the data, systems and look work can be built in parallel. Base: `origin/buglist/002-door-system` (= dev `bd5a00b` + Dave's 21 doc commits).

## Dave's decisions (13 Nov 2026, project chat 14:41-14:43Z)

1. **How a door is made (Dave: "the same way they make a wall or any other construction piece, but it has to snap into a doorway").** A door is a **hammer blueprint** like every placed piece (buildables plan ruling "Hammer blueprints, no kits"; kits retired 5 Nov; decision 60: building pieces are placed by hammer blueprint). The blueprint cost is the director-approved door recipe exactly. It places only into a matching empty doorway; take-down refunds the cost in full (existing rule) and leaves the doorway standing. Door hammer level = its tier's doorway (Crude..Engineered 1, Fortified 3). No station.
2. **Empty frame costs (Dave: "The empty doorway frames cost the same as a wall").** Each frame costs its tier's wall; arched the same; a double (two wall cells) twice that. Iron/Steel doorways have no matching wall: old cost minus hinges, pending Dave.
3. **Names (Dave: "We don't use the word single it's implied"; "That is only four words").** No "Single" in any name (`<Tier> - Door`, `<Tier> - Arched door`, `<Tier> - Arched doorway`); validate_items does not count the tier "-" as a word.

## Reconciliation: existing records

| Tier | Single doorway (kept id) | Change | Old open twin (state retired, kind -> legacy_kinds) |
|---|---|---|---|
| Crude | `thatch_doorway` bp 32, item 266, state 44 | already empty (BUG-010); cost 6 twine 25 thatch 12 stick -> 15 thatch 8 stick 3 twine; description fixed | `thatch_doorway_open` 91 (already retired) |
| Rustic | `log_doorway` bp 57, item 567, state 81 | door removed; cost unchanged 5 log 2 twine | `log_doorway_open` 82 |
| Refined | `doorway_section` bp 5, item 201, state 26, look `door_shut` -> `doorway_section` | door removed; cost unchanged 3 lumber 1 twine | `door_open` 28 |
| Sturdy | `stone_doorway` bp 58, item 569, state 83 | door removed; cost unchanged | `stone_doorway_open` 84 |
| Superior | `brick_doorway` bp 59, item 571, state 85 | door removed; cost unchanged | `brick_doorway_open` 86 |
| Engineered | `engineered_doorway` bp 173, item 867, state 213 | door removed; 8 concrete 2 lumber 2 hinges -> 8 concrete | `engineered_doorway_open` 214 |
| Fortified | `fortified_doorway` bp 182, item 885, state 223 | door removed; 9 concrete 5 iron band 3 lumber 2 hinges -> 9 concrete 5 iron band | `fortified_doorway_open` 224 |
| Refined double | `double_doorway` bp 104, item 661, state 139 | door removed; 6 lumber 2 twine 2 hinges -> 6 lumber 2 twine | `double_doorway_open` 140 |
| (material row) | `iron_doorway` bp 105, item 663, state 141 | kept as an empty single frame; 3 lumber 2 iron ingot 12 nails 2 hinges -> 3 lumber 2 iron ingot 12 nails | `iron_doorway_open` 142 |
| (material row) | `steel_doorway` bp 106, item 665, state 143 | kept as an empty single frame; 6 steel ingot 2 hinges -> 6 steel ingot | `steel_doorway_open` 144 |

Retired kit items (200, 265, 566, 568, 570, 660, 662, 664, 866, 884) stay retired. Gates (`*_gate`, fence pieces) are NOT doorways and are out of scope.

## New records (numbers in this exact order)

Item rows follow the M001/BUG-011 shape: one item row of kind `structure`, no kit item; the structure row's `kit` and `item` are the item id itself (as `thatch_roof_65`). Look name = structure kind.

### 20 new empty frames: blueprints 252-271, items 1256-1275, states 292-311

Order: tiers Crude, Rustic, Refined, Sturdy, Superior, Engineered, Fortified; within a tier: double (skipped for Refined, which exists), single arched, double arched.

| Tier | Double doorway | Arched doorway | Double arched doorway | Superseded cost (now: the tier's wall; double 2x) |
|---|---|---|---|---|
| Crude | `thatch_double_doorway` | `thatch_arched_doorway` | `thatch_double_arched_doorway` | 15 thatch, 8 stick, 3 twine |
| Rustic | `log_double_doorway` | `log_arched_doorway` | `log_double_arched_doorway` | 5 log, 2 twine |
| Refined | (exists: `double_doorway`) | `wood_arched_doorway` | `wood_double_arched_doorway` | 3 lumber, 1 twine |
| Sturdy | `stone_double_doorway` | `stone_arched_doorway` | `stone_double_arched_doorway` | 9 cut_stone_block, 3 mortar |
| Superior | `brick_double_doorway` | `brick_arched_doorway` | `brick_double_arched_doorway` | 12 brick, 3 mortar |
| Engineered | `engineered_double_doorway` | `engineered_arched_doorway` | `engineered_double_arched_doorway` | 8 concrete |
| Fortified | `fortified_double_doorway` | `fortified_arched_doorway` | `fortified_double_arched_doorway` | 9 concrete, 5 iron_band |

Names: `<Tier> - Double doorway`, `<Tier> - Arched doorway`, `<Tier> - Double arched doorway` (existing singles keep `<Tier> - Doorway`). Hammer level as the tier's doorway (Fortified 3, others 1). Category "Walls and doors". Structure rows copy the tier's single doorway row (material, sound, cap, max_rise, piece_kind `wall`, variant_group `wall`, footprint_z) with footprint_x 2.0 (single) or 4.0 (double) and NO `use`, `toggle`, `blocks_walk`.

### 28 doors: blueprints 272-299, items 1276-1303, states 312-367

Order: tiers as above; within a tier: single, double, single arched, double arched. Door i (0..27) has blueprint 272+i, item 1276+i, shut state 312+2i, open state 313+2i.

| Kind pattern | Name |
|---|---|
| `<tier>_door` | `<Tier> - Door` |
| `<tier>_double_door` | `<Tier> - Double door` |
| `<tier>_arched_door` | `<Tier> - Arched door` |
| `<tier>_double_arched_door` | `<Tier> - Double arched door` |

`<tier>` = crude, rustic, refined, sturdy, superior, engineered, fortified. Open twin kind = `<kind>_open` (same `kit`/`item`, its own state and look `<kind>_open`).

Costs (blueprint `cost`, exactly; double and double arched = the double column):

| Tier | Single / Single arched | Double / Double arched |
|---|---|---|
| Crude | stick 50, twine 100 | stick 100, twine 200 |
| Rustic | lumber 5 | lumber 10 |
| Refined | hardwood_board 6, iron_ingot 1 | hardwood_board 12, iron_ingot 2 |
| Sturdy | lumber 6, iron_ingot 2 | lumber 12, iron_ingot 4 |
| Superior | hardwood_board 12, iron_ingot 2, steel_ingot 1 | hardwood_board 24, iron_ingot 4, steel_ingot 2 |
| Engineered | lumber 12, iron_ingot 4 | lumber 24, iron_ingot 8 |
| Fortified | iron_ingot 10, steel_ingot 10 | iron_ingot 20, steel_ingot 20 |

## Data shapes (new fields)

- Every doorway frame row (old and new): `"opening": "single" | "double" | "single_arched" | "double_arched"`.
- Every door row (shut and open): `"piece": true`, `"piece_kind": "door"`, `"attach_to": "doorway"`, `"opening"` (same values), `"use": "door"`, `"toggle"` (shut <-> open), `"use_pace_ms": 400`, `"use_reach_m": 3.0`, `"tier"`, `"material"` (`wood` / `iron` / `steel` as appropriate; Fortified `iron`), `"sound"` (timber for wood doors, metal for Fortified), footprint_x = opening width (1.0 single, 2.0 double), footprint_z 0.1, cap_per_chunk 200, `"gap_exempt": true`, `"clears_grass": false`; the shut row has `"blocks_walk": true` and `"grid_x"` = its frame width (2.0 / 4.0), so the server grid stops animals across the whole frame, jambs included (gate review SHOULD 3; frames themselves have no `blocks_walk`). Open rows have no `variant_group`.
- Opening geometry (shared by frame and door, client and server): single = 1.0 m wide x 2.0 m clear; double = 2.0 m x 2.0 m inside the 4 m piece; arched openings keep the same outer envelope with a rounded top: single arched = semicircle of radius 0.5 m springing at 1.5 m (crown 2.0 m); double arched = one segmental arch over the 2.0 m span springing at 1.5 m with crown 2.0 m (radius 1.25 m). The door leaf fills exactly its opening; a double door is two leaves meeting in the middle, each with its half of the arch.
- Compatibility: a door fits a doorway iff `opening` is equal. Tier and material never matter.

## Behaviour (systems)

- Door placement (`attach_to: doorway`, shared `PlacementRules` code for ghost and server, like the Serving Platter `attach_to: table`): snaps to the nearest doorway frame within reach; spot = the frame's spot, yaw = the frame's yaw. Refusals with reasons: no doorway near ("nodoorway"), the nearest doorway has a different opening ("mismatch": say which door it needs), the doorway already has a door ("taken"). Ghost and server agree.
- E on a door toggles shut/open (existing `use: door` / `toggle`). Frames have no `use`.
- Take-down of a door refunds its blueprint cost and leaves the frame. Take-down of a frame holding a door, built or still a blueprint site, is refused: "Take the door out first."
- Saved worlds: rows are kind/pos/yaw; old `*_open` doorway kinds load as the empty frame through `legacy_kinds` (`_kind_now`). A legacy doorway does not get a door added; the player builds one. No save-format or protocol change.
