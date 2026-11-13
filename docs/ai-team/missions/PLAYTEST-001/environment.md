# Playtest Repair Mission 001: environment (TEST-007, TEST-011)

Dave's playtest findings of 12 Nov 2026, environmental realism (priority 4). Base: `origin/dev` at `b922cc88a59586dfbd41f806744d9ccedfe2bf26`. Branch `claude/project-thread-ebb1tq`.

## Ledger

| Test | Status | Evidence |
|---|---|---|
| TEST-007 Tree canopies missing central foliage | NEEDS PLAYER VERIFICATION | Cause found and fixed in the tree models; `test_canopy_cover` written. Tests PASS on the PC (50b05ed5); not yet seen on screen. |
| TEST-011 Campfire smoke disappears at canopy height | NEEDS PLAYER VERIFICATION | Tall plume in dev (PR #1060, PC PASS at 50b05ed5). Second round (13 Nov, this branch): twice-the-average-tree height, wind rules, far smoke to 2 km (protocol 114); `test_fire_smoke` extended, `test_far_smoke` new. PC run pending; not yet seen on screen. |

## TEST-007: cause

Not culling, LOD or rendering. The player's own 64 m cell always draws the full model (`flora_view.gd` `_level`), leaf cards are drawn double-sided (`cull_disabled`) and the leaf textures have no mipmaps (`mipmaps/generate=false`), so cards do not thin out at a distance.

The gap is in the models. The limb-built hardwood crowns (`tree_builder.gd` `_maple`, `_beech`, `_oak`, `_chestnut` for sweet chestnut and walnut) hang every leaf clump on the limb tips, and the limbs spread outward to the crown's egg-shaped shell (`_maple_limb` and `_oak_limb` add an "away from the centre" push to every child limb). Nothing fills the upper middle of the crown over the trunk, so looking up from under the tree the sky shows straight through it. Conifers (spruce, fir) are covered overhead; Scots pine is open by design (a light canopy).

Measured with a Python port of the builders and the real leaf textures (alpha 0.5 cut, as the foliage shader): the share of the sky within 20 degrees of overhead covered by leaves, standing 1 m from the trunk, 16 builds per species:

| Species (reference height) | Before | After |
|---|---|---|
| Oak (19.5 m) | 26% (worst 5%) | 82% (worst 74%) |
| Maple (15.5 m) | 67% (worst 47%) | 90% (worst 84%) |
| Beech (17 m) | 74% (worst 59%) | 92% (worst 88%) |

About one crown in eight is meant to be dying, with a wedge of its upper crown bare (`_crown_variety`, moderator 31 Oct 2026); that is unchanged and will still show sky.

## TEST-007: fix

`tree_builder.gd` `_crown_core`: a few leaf clumps under the top of the crown's egg, spread over the middle of its width (golden-angle disc), each with one card laid nearly flat (`_clump` `flat` 0.3; the default 1.1 is unchanged for every other caller). 14 clumps for maple, beech, sweet chestnut and walnut, 22 for the oak's wider, flatter dome. Near models only, summer and autumn models only (not the bare winter one), and its own random stream, so every other card of every tree is built exactly as before.

Cost: about 42 cards (84 triangles) on a 700 to 900 card maple or beech crown (about 6%), 66 on an oak's 560. Not measured on the PC (Ponytail: unmeasured).

## TEST-011: cause

The campfire plume (`building_look.gd` `_campfire_smoke`, `data/look/fire_smoke.json`) lives 20 s and slows as it rises, to 40% of its start: in a calm it has thinned to a third by about 7 m and is gone by 11 m; in a 1 m/s breeze it gets about 5 m up. The crowns about it stand 15 to 35 m.

## TEST-011: fix

A second, sparse "tall" plume on every lit campfire (`_tall_smoke_plume`, every number in `fire_smoke.json` "tall"). Its puffs leave the flames with the near plume but are unseen for their first 6% of life (the near plume is the smoke there), then carry the column on for 60 s, slowing, spreading to about 8 m wide and fading. It follows the same world wind as the near plume (`set_fire_air`, once a second).

| Air | Where a puff is at 70% of its life (still about a quarter as thick) |
|---|---|
| Calm | about 44 m straight up |
| 2 m/s breeze | about 34 m up, 43 m downwind |
| Still clear night | rises to about 30 m and spreads flat there (the cold air holds it down) |

Performance limits: 24, 36 or 48 puffs per fire (small, medium, large), stepped at 10 fps with interpolation, so the warm start costs the same 600 steps as the near plume's; only the 6 lit fires nearest the camera draw it (the rest are hidden, so not simulated, and start again warm when they come back into the nearest six). A fire past the nearest six starts hidden, so it never pays the warm start. Not measured on the PC.

Limit (a `shortcut:` comment in the code): a fire is drawn only while the server sends it, within 100 m (`server_items.gd` `NEAR_M`). So the smoke is seen from up to 100 m, not from a hill farther off. Seeing camps from farther needs the server to send a list of distant lit fires (a network change in a shared server file); left for Dave to decide.

## TEST-011: second round (Dave, 13 Nov 2026)

Dave's rules: smoke can be seen up to 2 km (he approved the far-fires plan); "smoke should rise at least twice the height of the average tree before it starts to dissipate to much"; "strong wind the smoke stays low and sideways. low wind it climbs higher and dissipates slower"; "it also needs to go with the wind direction".

- Height: the average tree (each species' middle height weighted by plants per hectare, `flora.json`) is about 19 m, so twice is about 38 to 42 m. The tall plume now rises faster and lives 70 s; a medium fire reaches 42 m at about 30 s in a calm and 32 s in a 2 m/s breeze while still about 75% as thick as at its thickest. A still clear night stops it at about 45 m.
- Wind (`building_look.gd` `tall_rise`, `tall_fade_share`, `tall_fade`; numbers in `fire_smoke.json` "tall"): up to 2 m/s nothing changes. Above that the rise is cut (a medium fire 0.5 m/s at 5 m/s wind, 0.3 at 8) and the fade after the thickest point is squeezed (0.5 of the rest of its life at 6 m/s, 0.4 at 8). At 8 m/s a puff is about 9 m up and 120 m downwind halfway through its life. Both plumes move along the world wind's heading (`set_fire_air`).
- Far smoke: the server keeps the lit campfires from its once-a-second world sync (`server_items.gd` `far_fires_near`) and sends each player those 100 m to 2048 m away, nearest 32, with their tier, when the set changes (`terrain_server.gd`, new message `far_fires`, protocol 114; 112 and 113 are claimed by the open hotbar and combat branches). The client (`src/client/far_smoke.gd`) gives each the tall smoke column only (the same materials, so the same wind), drops those past its terrain view distance (768 m Low, 1280 m Medium, 2048 m High and up) and draws only the nearest 8. Fog and haze dim them as the ground.
- Cost: one small message per player when a far fire is lit or put out or the player walks past one; at most 8 far columns (42 puffs each for a campfire, stepped at 8 fps) drawn. Not measured on the PC.

## Tests

| Test | What | Run |
|---|---|---|
| `test_canopy_cover` (new) | builds the near models of maple, beech, oak, sweet chestnut and walnut as the game does and checks leaves cover at least 92% (oak 82%, all four oak variants) of the sky within 20 degrees of overhead (card shapes); no leaves, so no core, on the winter model; the core is near-only and inside the crown | PASS (PC, 50b05ed5) |
| `test_far_smoke` (new) | the server's far list (100 m to 2048 m, nearest first, at most 32, tiers, cold fires and coals left out), protocol 114, the client's plumes (one per fire, nearest 8 drawn, none past the view distance, gone fires dropped, a grown fire gets the bigger plume, the near fires' materials, smoke only) | pending (PC) |
| `test_fire_smoke` (extended) | the tall plume: unseen at the fire, above 35 m in a calm and 25 m in a breeze, stops at about 30 m on a still night, spreads, cull box holds it, warm start no dearer than the near plume; the nearest-six cap and its hand-over when a fire goes out; 13 Nov: at twice the average tree still 60% thick (tiers 1 to 3, calm and 2 m/s), an 8 m/s wind lays it low, sideways and thins it sooner, it goes with the wind heading | PASS (PC, 50b05ed5); 13 Nov checks pending (PC) |

PC run, 12 Nov 2026, Dave's PC (ManlandRyzen5), Godot 4.7.2 voxel build, separate worktree at `50b05ed5a9145cd18f75dceac283424ab5584477`: **68/68 PASS** (68 distinct tests after removing the names on both lists). Scoped plan agreed by the gate reviewer: the selector's set for the non-trigger files (60, the always set included) plus test_fire_state_look, test_lit_fixture, test_forge_models, test_flora_budget, test_flora_load_order, test_flora_close, test_fruit_tree, test_fruit_share, test_season_fruit, test_fell_autosplit, test_bare_winter, test_tree_sway, test_leanto_collider, test_cave_not_rock, test_buildable_looks_b4. The full selection (202, from the shared `tree_builder.gd` and `building_look.gd`) is deferred to the broad run before `main`.

- Canopy cover measured (card shapes, 20 degrees overhead): maple 98 and 99%, beech 100 and 99%, oak 98, 96, 98, 96% (all four variants), sweet chestnut 100%, walnut 100 and 100%; sweet chestnut variant 0 skipped (a dying crown by design). Winter models: no leaves.
- Smoke: tall plume a fifth as thick at 44 m in a calm, 34 m up and 43 m downwind in a 2 m/s breeze, stops at about 30 m on a still night, puffs 10 m wide at the end; 9 fires: the 6 nearest draw it.
- Near-model triangles (flora_tris, variant 0): oak 4350, sweet chestnut 4196, walnut 3466, beech 3260, maple 2382.
- Warnings: no file this change touches is over `tools/warning_baseline.txt`; five other files already on dev are over (server_items.gd and four from M001/B001 work), not from this change.
- Startup/world-load smoke (headless, play role): world loaded and joined in 33 s, 17 flora chunks, client frames 11.3 ms on average; the known abnormal headless exit (139). The log's "already initialized RID" and null-parameter errors were not compared with a dev baseline.
- Not checked: anything on screen (both items stay NEEDS PLAYER VERIFICATION), frame time with many fires.

## What Dave should look at

1. Stand under an oak, a maple and a beech in summer and look straight up: the middle and top of the crown should be leafy, with only small gaps.
2. Light a campfire in a forest and step back 30 to 80 m: in light wind the smoke should climb to about twice the treetops before it thins; in a strong wind it should stay low and stream sideways, always downwind.
2b. Walk or climb a hill 300 m to 2 km away (High quality for the full 2 km; Medium shows 1.3 km, Low 770 m): the column should still be seen over the trees.
3. Light six or more fires close together and watch the frame rate.

## Review

Independent gate review of 23df315 (PR #1063): PASS WITH FIXES, no must-fix; fixed next: 10 m overlap at the 100 m hand-over, at most 2 far plumes newly shown a second (warm start), the PROTOCOL.md table row, an order-free resend hash, stale notes.

Independent gate review of c7175588: PASS WITH FIXES. Fixed in the next commit: the cap test now builds its fires after the scene tree starts (`_initialize` + `await process_frame`); a tall plume past the cap starts hidden; each plume is ranked by its own viewport's camera; per-species canopy thresholds, oak variants 2 and 3, and a winter check. Open for Dave's look: the small (one-rock-ring) fire now also sends smoke up over the trees; TEST-011 is partial past 100 m.
