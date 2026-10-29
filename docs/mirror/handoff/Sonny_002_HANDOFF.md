# Sonny_002 handoff (Water Works), 2026-10-22 night, for Sonny_003
Read Sonny_001_HANDOFF.md first (rules, recipes). Dave stopped work for the night at 05:34. Nothing tile-touching was pushed.

## Pushed this iteration (all runtime, branch claude/generator-v2)
- 608: water_grid.gd thread safety (fall_levels / sim_levels read once per chunk; the worker raced the main-thread swap in _poll_water).
- 623: head pond spring fix. water_settler.gd: the spring goes to the highest head (heads sorted by ground height), `_pond_near` prefers the highest bowl, `_pond_middle` only takes cells within 2 m of the pond's own level (POND_LEVEL_TIE_M). Cause: the v25 plunge pool basin beside the head pond got the spring; the real pond (east bowl x ~53800 z 69340, surface 427 m) stayed dry and the pool spilled south. 4 h dry sim: bowl 11.2 m deep and stable. Server restart needed. Dave's check lines are in tech/TEST_QUEUE.md.
- 628: Ctrl+Shift+W hides/shows all water drawing (to tell the brown squares on the spawn lake: water draw or ground). Result not back yet.

## Findings
- "New lake in front of the head pond" = the plunge pool of the first chute (designed, 21 Oct chute push). Not a regression in the bake. The south spill ("300 m fall") is that pool leaking over its south wall (water ~404.7 m, wall 401 to 403 m).
- Server starts water DRY by design (unless --settled-water); "starter none" on the HUD is the client ground cache only.
- Brown squares on the spawn lake: settled water has zero holes there; water mesh is one material; suspect is ground/solid-box blocks (Willy/Tyler slab hunt) or sorting (Willy). Wait for the Ctrl+Shift+W answer.
- Flood plan: tech/WATER_FLOOD_PLAN.md approved for steps A to D (runtime), Dave then said focus on the present; not started.

## HELD, do not push until Steve names the bake: spill chute (Steve chose B, DECISIONS 05:25)
Patch: /mnt/project-files/handoff/Sonny_002_spill_chute.patch (also local commit on branch sonny-chute-held, lost if the container ends). Files: src/worldgen/tile/tile_water.gd (`_find_spill`, `_spill_mode`, rivers loop is now a while loop so a spill river can be appended, spill width in `_terrace` and the width rule), worlds/base_world/plan/tile_rules.json (spill_* rules), terrain_layout.gd TERRAIN_VERSION 26.
How it works: after a plunge pool is stamped, a minimax flood finds the lowest rim not in the river's direction; if it is within spill_margin_m (3 m) of the river's own way out, a guide river is cut from that saddle down the steepest descent (smoothed) until flat, water or 24 cells from the frame, through the normal pipeline (one clean ramp chute 16 m wide, plunge pool at the foot). Gated by `spill_chutes` rule, only from non-spill rivers.
Scratch bake of tile 3,4 (scratchpad, ~140 s + 65 s setup): chute from x 53650 z 69300 to the 41 m lowland at x 53500 z 69030, monotone, 2 cells wide, 145 more wet cells, west river unchanged in the map. Baseline scratch bake hash 61ceab28... differs from Dave's committed tile 436799f9... (Linux vs Windows or code drift), so use before/after scratch bakes for the hash gate, not the committed tile.
Still to do for the gate: 882-test suite (test_worldgen), edge match (tools edge_match.gd), scratch hashes on tiles 3,3 3,4 4,4 before/after (other tiles may also get spill chutes: check or set spill_chutes only where wanted), Willy's hillshade review, and the FLOW SPLIT check (west must keep at least half). My sea-inflow method is useless (all water ends in the sea either way). Better: Manning estimate at equal elevation on both chutes, or dam the sea end. Width is 16 m, not 10 to 14 (8 m grid whole cells).
