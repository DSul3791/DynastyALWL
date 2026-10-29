# River start at the head pond: hand-over notes (water/terrain thread, 2026-10-20)

Symptom (Dave, build 200, screenshot at x 53234 z 68477): the river does not visibly start from pond A. Grass bench and a brown rectangular patch beyond the pond, no channel leaving the water.

## Where
`src/worldgen/tile/tile_water.gd`, `_carve_guides(rivers)`, rules in `worlds/base_world/plan/tile_rules.json` (water section). Pond A: sample col 899, row 882 of tile (3,4) (tile origin x 46080, z 61440, 8 m samples, 1921 per side). Pond level 27.83 m, bench 28.8 m (flat, ~1 m above the pond). Pond B: col 965, row 988, level ~427, plateau 419-428 m.

## Order of operations in `_carve_guides`
1. For every world head pond: `_bench` (flat plateau at the pond level, radius + shore 40 m, faded over wall_fade), then `_stamp_pond` (bowl, 10 m deep).
2. `bench_land` = copy of the ground after the ponds, before any river.
3. `_guard` array: `_guard_shore(centre, R, lip = level - head_pond_outlet_drop_m (now 3.0), shore)` marks the shore ring so cuts can't go below lip - (dist-R)*fall.
4. Rivers (main loop, `_stamp_at` per point, pools, ledges).
5. Brooks: `_cut_brook_path(carved, bench_land, centre, R, rim=level, path, head_bed, width, depth, slope, strength, flow)` for each pond head: start_bed = rim - head_pond_outlet_drop_m, outlet widened to head_pond_outlet_width_m (40) blending over head_pond_outlet_blend_m (90), apron fall head_pond_outlet_fall (0.12). Skips points within 0.8 R of the pond centre.
6. Spur smoothing (skips guarded cells).
7. `_seal_pond_rim(carved, ..., placed[1] - 1.5, shore)` for every placed pond: raises the shore ring back to "just under the lip" with a HARD-CODED 1.5 m (also line ~1095 `rim_low - 1.5`, and `_bench(..., rim_low ...)` at ~778). I changed the outlet drop to 3 m (build 190) but NOT these: the seal may refill the outlet to 1.5 m under the rim again. Strong lead, untested.

## What the data shows (fresh bake of tile 3,4, before/after my change)
- Only ~70-110 cells changed around each pond. Around pond A the new trench is 3-4 cells (24-32 m) wide at the shore, 4-8 cells further out, bed -3..-7 m under pond level, bench cells beside it at +1.
- Pond level reported by the baked water_surface is unchanged (27.83 / 427.03), as it is set by rim, not sill.
- The live sim (`water_live.gd`, native core) puts the pond level at roughly sill + flow depth; with a sill only 1 m below a flat bench the water spills as thin film on the bench (seen as a flashing rectangular patch at x 53201 z 68536). Film drawing (`_show_channel`) is removed since build 190.
- The 3,4 tile bake in this repo is only what the generator makes: Dave's committed tiles from before build 190 still have the old outlet. Dave was mid-bake at build 190/200: check that his latest tiles are from a bake of build >= 190.

## Why I think the river does not start from the pond
Likely one or more of: (a) `_seal_pond_rim` re-raising the outlet to 1.5 m under the rim (see above); (b) river/brook paths start inside 0.8 R of the pond centre and are skipped, so the first cut point can lie beyond the apron, leaving an uncut gap of bench between pond edge and trench (brown rectangular patch = channel apron/stamp seen from above); (c) the brook path begins on the pond side where bench_land is flat and `_guard` forbids cutting below lip - dist*fall, which can leave the first cells above the sill; (d) Dave's tiles may be older than the generator change.

## Evidence
/mnt/project-files/pondA_outlet.png, pondA_view.png (2D maps). Scratchpad dumps from `dump_heights.gd` (writes out_*.f32 in the project dir; run `~/bin/godot --headless --path . -s dump_heights.gd`; 2 min) are in /tmp/claude-0/-home-claude-dynastyalwl/9710f82f-a962-5d3d-a7fb-a460f09328ff/scratchpad (old/ = before change, out_* = after).

Rules: keep the river cut last, never reshape a pond, nothing draws water above its local surface (Dave 2026-10-20). Ask TD for a build number first. Tests: test_worldgen (6 min), test_water_sim, test_water_grid_flow, test_water_falls.
