# Erosion pre-carve: carve the whole island with a million years of water (BAKE; one plan)
Branch claude/erosion-precarve (fb4e738, from claude/export-raw-heights 804eef3). Terrain owner: Sonny. Dave: "make it so" (24 Oct).
Today: TileErosion carves each tile alone (32 m, few steps, change faded to 0 at the tile edge), so valleys cannot cross tiles and never get a catchment.
Plan:
1. Offline tool tools/erosion_precarve/ (numpy+numba, written from Braun and Willett 2013, no GPL code). Input: Sonny's raw_X_Z.f32 (pre-erosion heights, 9 tiles, 8 m) averaged to 32 m. 250 steps of 4,000 years: priority-flood routing once per step, uplift (ramps from 0 at the coast to full 12 km inland), implicit stream power K*A^0.5, hillslope diffusion, sediment dropped into pits (floodplains, lakes), last 40% of time without uplift. Sea level 0 is the base. Measured: 1441x1441 cells, 117 s on one core at nice 19, 8.3 MB output.
2. Output erosion_delta_v1.bin ("ERD1": header then float32 height change per 32 m cell, whole island, faded to 0 over 1.5 km at the grid edge; sea cells 0). Format in src/worldgen/tile/erosion_delta.gd.
3. tile_baker.gd: if worlds/base_world/erosion_delta_v1.bin exists, the delta is sampled by world position and added to the WHOLE frame (margin included) and to raw_frame (what water.routing_raw uses), after height and before ledges/scree/spawn pin; TileErosion is skipped. No file = old behaviour. TERRAIN_VERSION 41 -> 42.
4. valley_guides: ON first (tile_rules precarve.valley_guides, default true), because the carve was computed on heights that include them. If doubled valleys show, set false, re-export raw heights with the same switch, re-run (2 minutes), rebake. Decision for Sonny.
Best-practice questions for Tyler: (a) keep the delta as a loaded file in the world folder or bake it into the tiles stamp so a changed file always changes tiles_stamp; (b) bilinear sampling of 32 m on 8 m is smooth, is a bicubic worth it; (c) where the delta file lives for the server (copy with tiles, size 8 MB).
Tests (David3, nothing baked in cloud): 
- parse_scan, local_check 233.
- Run the tool twice on the same raw files: erosion_delta_v1.bin byte-identical (cmp).
- Bake tile (3,4) twice: .tile files byte-identical; then all 9 tiles together, seam table 0 differences on every shared edge.
- Numbers at 8 m after the bake (after ledges and scree): summit and relief bands vs Sal's island table (island 8: 1000-1450 m), land under 250 m with slope under 10 deg (target 90%+), flat/walkable shares and walkable routes, spawn x53301 z68427 flat and dry within 450 m, no closed pits except lakes, rivers reaching the sea (count), basins.
- Pictures: before/after hillshade of the island with rivers and lakes (tool writes before_after.png), plus Mike's in-game views of one valley.
Nine-tile rebake needs: Mike/David3 box, all 9 tiles in one go (3,4 and its 8 neighbours), Dave holds play during it, then server block store reset (TERRAIN_VERSION bump does it), then Dave Fetch+Pull and Clear blocks. Seam FAIL is expected until all 9 are rebaked together.
Tuning knobs if bands fail: U/K sets the summit, D and the coast ramp set farmland slope, basins list sets lakes (tools/erosion_precarve/README.md).
Label BAKE.
