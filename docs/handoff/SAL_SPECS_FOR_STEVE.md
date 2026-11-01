# Specs Sal hands to Steve (1 Nov 2026)

Each spec: data already in the daily, the code still missing, the exact next step, why. Sal wrote the data; Steve writes the code. Sal's section of `docs/CLOSING_PLAN.md` item 4.

## 1. Stump drops by size (data done)
- Data: `data/items/drops.json` `stump.final_by_radius`, rows `{max_radius_m, rows}`; first row whose `max_radius_m` is at or above the stump radius wins, the last row has no limit. The old `final` row stays as the fallback.
- Code: `_chop_stump` in `src/stream/server_items.gd` reads only `final`. Next step: read `final_by_radius` when present, else `final`. Test: stump of 0.15 m gives 1 to 2 firewood; 0.5 m gives 3 to 5.
- Why not done: it is server code, not data.

## 2. Heavy build kits (needs Dave's answer, QA card `heavy-kits-carry`)
- Problem: stone wall kit 314 kg, fireplace about 79 kg, brick wall about 57 kg, brick floor about 54 kg against about 52 kg carried (0.7 x body kg).
- Recommended code (option A): a recipe at a station also counts ingredients lying as world items within 3 m of the station. Next step after Dave says yes: add the lookup in the craft check and consume those items first; add a test with 12 cut stone blocks on the ground beside a workbench.
- Fallback (option B, data, mine): brick wall 12 bricks + 3 mortar, brick floor 16 bricks + 3 sand. Stone stays too heavy, so B alone does not fix stone.

## 3. Furniture `gap_exempt` (data done)
- Data: the flag is on comfort furniture rows in `structures.json`. Code: the placement gap check (`gap_m` 2.0) must skip pieces with `gap_exempt`. Next step: add the skip in the placement check; test two beds 1 m apart place, two campfires still refuse.

## 4. Backlog from my old branches (code owner Steve)
- Bridges (`sal-bridge-note`): a bridge placeable across water. Next step: read the note on that branch; decide port or write as a card.
- Plank tier and thatch window (`sal-building-tiers-p1`): building tiers; next step: port the data keys, add the window piece.
- No stack caps (`sal-no-stack-caps`, `-build`): remove the per-slot stack limit for chosen items. A design call; Steve to write a card for Dave if he wants it.

## 5. Smaller items
- `needs_material` for ore picks (a pick only works on matching ore): data key to be read by the mining code.
- `sow_season` list: crops may only be sown in listed seasons; `seasons.json` holds the data, the server must refuse out of season.
- Quality grades on tools and food: probably not built; no data written. Next step: Dave decides if wanted.
