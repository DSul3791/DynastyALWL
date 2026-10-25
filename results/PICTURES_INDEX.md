## 2026-10-25 Mike (Windows rig): world pictures on generator-v2 build 810 (9f55bbf0) with the c30d6d5f bake
Branch claude/mike-evidence-kathleen-13df38ae, folder evidence/world_810/: world_spawn_a-d (spawn four directions), world_river_a-d, world_farmland_slope, second_pass_world_biglake_3_4 and second_pass_world_lake_4_3, aerial_world_biglake_3_4_aerial (x52552 z69016, 465 m up, pitch -60) and aerial_world_biglake_3_4_aerial_top. Finding: both lakes carry trees standing in the water (forest blocks with square edges inside the (3,4) lake).

- 2026-10-25 Mike (Windows rig): world pictures on land-types 1b9c6f82 + claude/mike-bake-land tiles (TERRAIN_VERSION 43): branch claude/mike-evidence-kathleen-13df38ae, evidence/world_land_1b9c6f82/: land_spawn_a-d, land_river_a-d, land_farmland_slope, land_foothill_east/west (x53968 z68864), land_lake_shore_3_4, land_lake_aerial_3_4, land_lake_4_3, land_walk (HUD). Compare with evidence/world_810 (before).

- 2026-10-25 Mike (Windows rig): clay_hearth, oven, thatch_floor, rough_bed on Kathleen f536fea7 (piece views front/side/top/diag): branch claude/mike-evidence-kathleen-13df38ae, evidence/placeables_f536fea7/pf_<piece>_<view>.png (16 pictures).

- 2026-10-25 Mike (Windows rig): placeables on build 817 with Steve's piece views (claude/steve-piece-shots 4c4fb42c): branch claude/mike-evidence-kathleen-13df38ae, evidence/placeables_817_views/pv_<piece>_front|side|top|diag.png for rough_bed, thatch_floor, clay_hearth, oven, lean_to, thatch_wall, thatch_roof, thatch_doorway (32 pictures, all views ok in the fit log).

- 2026-10-25 Mike (Windows rig): placeables on build 817 (generator-v2 8328efba) built with the game's ghost builder, 4 m ahead, straight and turned 135 degrees, three framings each: branch claude/mike-evidence-kathleen-13df38ae, evidence/placeables_817/ (clay_hearth, oven, rough_bed, thatch_floor, thatch_wall, thatch_roof, thatch_doorway, lean_to). Framing is small (pieces rig camera); rough bed and thatch floor are only a small flat shape at this distance.

- 2026-10-25 Mike (Windows rig), tool pass: branch claude/mike-evidence-kathleen-13df38ae, folders evidence/toolpass_<hash> (held: first person 35 down, third person a-d, top) and evidence/ground_<hash> (Steve's item job: front, side, top, diag + log) for Kathleen's hashes a01d6527 ... 7c806b9d: spades, hoes, hand saw, axe, hammers, knife, rod, spears, pin, torch (rounds 1-6), bow 60e82f3e / e4a8e44e, stone arrow 7c806b9d. Index of the newest per item: bow e4a8e44e, stone arrow 7c806b9d, torch 302f8279, spades acf53a86, stone hoe 023e44b3, knife 106c4899.

# Pictures index (newest first). One line per set: folder, topic, build, notes.
All pictures: server GPU (GTX 1050 Ti), JPEG 1280x720, 1.7 m eye unless noted. Details in each folder's README.md or summary.txt.

- results/20261024_791a - thatch_grass flora row at spawn - claude/tyler-791a 02e0910c
- results/20261024_stone2 - Kathleen stone look before/after, sun and shade (framing weak) - generator-v2 f221c667 vs claude/kathleen-stone-look 3b1f0066
- results/20261024_bowl2 - bowl 1 re-render after long wait, aerial at Dave's point 53698,130,68481 yaw 138 - generator-v2 2c2cc8af
- results/20261024_bowl - bowl views east of the hill, pool and 60 m west - generator-v2 2c2cc8af
- results/20261024_rig_flora - look_rig --flora raspberry,bramble on Linux - claude/david3-rig-only
- results/20261024_spawn_gpu - spawn shot from Dave's testbox run - generator-v2 2c2cc8af
- results/20261024_publish - first server GPU test shot at spawn - generator-v2 2c2cc8af
- results/20261024_bake34, 34b, 34c - logs and island tables of tile (3,4) bakes (no pictures) - c2eeb8e3, 6f4801e8, 4f442c54
- results/20261024_island_map - top-down island map (3840x2880): lakes, rivers, farmland, spawn; v1 = merge-793 5b9d9f91 v31 tiles + erosion_delta_v1 on heights (water not re-routed); redo from Mike's bake when it lands
