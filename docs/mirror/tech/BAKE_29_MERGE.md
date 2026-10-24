# Bake 29 merge plan (Tyler, 24 Oct 04:35 UTC). TERRAIN_VERSION 33. Code and tiles go out as ONE build (BP-T53).
Inputs
- Code: claude/tyler-seam32 (32142d7b = head 776 + sonny-foothills bc7282c5 + steve-river-settle 399341a4; island_checks.json kept at head's version) + sonny-foothills f49a1033 + steve-river-settle fa7bdadc (final; report-only changes since 399341a4) + passing gate list 4 items.
- Tiles: claude/mike-bake-v29 (9 tiles of f49a1033 + 9 settled .water + docs/bake29 tables).
Dry run done (04:35 UTC, on tyler-seam32): sonny-foothills f49a1033 and the six list 4 branches (sound-1 9a2e1ba9, sound-slots 0ff7769b, shrub-lod 250730e0, mike-batch 11e03851, goal2-a e986e7e7, showroom-rows 8e79c4a0) all merge clean; parse_scan 374 files 0 problems; merge_check clear; TERRAIN_VERSION 33.
Steps when Mike's v29 and list 4 PASS arrive
1. git fetch; checkout generator-v2; merge the TESTED hashes only (not branch names): mike-bake-v29 (it must contain f49a1033 and the settle hash he used: check with merge-base --is-ancestor), then tyler-seam32, then each passing list 4 branch.
2. island_checks.json conflict: keep head's version.
3. merge_check.py, parse_scan.py; confirm TERRAIN_VERSION 33 and tile count 9 + water 9.
4. Gate: Mike's table for v29: seams under 0.5 m (target), river gate; list the remaining FAIL rows for Dave as known flaws, as for 775.
5. Bump NUMBER (next free: 777 if list 4 not merged first), BUILD_LOG (both copies), HANDOFF line 2 (TERRAIN_VERSION 33), DAY_LOG; push; tell the coordinator.
Dave's pull steps (send with the build)
1. Close the game fully; in Task Manager end any leftover Godot process (the old server).
2. GitHub Desktop: Fetch origin, Pull.
3. Start the game (F6). HUD must show "ground v33" and a new tiles hash.
4. Esc > Admin > Reset all terrain edits.
5. Esc > Admin > Clear blocks.
6. Walk from spawn (spawn and buildings may shift; report where).
Notes for Dave: earlier digs/buildings will not match the new ground; flora layout and tree belts follow when Kathleen's VERSION 4 merges.
HOLD 04:50 UTC: build 777 (bake 29, mike-bake-v29 ba9b7d27) held for Dave until spawn gate fails (slope 9.9 vs 7.0, 5 water samples) are fixed by Sonny. List 4 merges continue.

UPDATE 04:55 UTC: spawn fix. Code: sonny-foothills a1824d00 (TERRAIN_VERSION 34, on f49a1033, only tile (3,4) changes). Tiles: claude/mike-bake-v29b (9 tiles, new (3,4) re-settled). River-settle final fa7bdadc (code only, merged on top; no new settle needed). HOLD lifts when Mike's table shows the spawn gate PASS.
Mixed stamps are fine: a tile file carries no TERRAIN_VERSION. Its header holds only FORMAT_VERSION 1 and GENERATOR_VERSION 1 (tile_file.gd). TERRAIN_VERSION is ONE code constant (terrain_layout.gd, 34) sent by the server, and the saved ground and the client cache are keyed by "version + md5 of all tile files" (server_block_store.gd:70, terrain_client.gd:909). So the game never compares tiles to each other: all 9 tiles are read with version 34 rules and any changed tile file changes the stamp, which clears the saved ground (Dave resets edits anyway). No restamp, no full rebake is needed because of the version label.
Merge order for 777: mike-bake-v29b (must contain a1824d00 or merge sonny-foothills a1824d00 with it), then tyler-seam32, fa7bdadc, then passing list 4 branches. HUD check for Dave: "ground v34".
