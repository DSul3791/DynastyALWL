# Old unmerged branches: review and assign (1 Nov 2026)

Dave: "review the unfinished work and assign it to whomever it should go to. They can decide if it is still relevant or not."

116 old remote branches (last commit 20 to 26 Oct) are not merged into the daily. `qa-poke` is kept (standing PR for the QA page button). Each owner decides per branch: **port** (cherry-pick or redo on a fresh branch from the daily), **already done** (the daily has it; say where) or **drop** (one-line reason). Reply to the moderator with a table. Branches are deleted only after the owner answers. "ahead" = commits not in the daily.

## Jason (sound) (13)
| branch | ahead | last commit |
|---|---|---|
| `claude/kathleen-basic-looks-2` | 2 | Basic item sounds by material class (8 classes, pick up and put down), dimmer bo |
| `claude/kathleen-creature-sounds` | 1 | Basic creature sounds: moose, horse, duck calls (placeholders) and animals call  |
| `claude/kathleen-door-sounds` | 1 | Door sounds: a door flipping between shut and open plays the door open/close, no |
| `claude/kathleen-sound-r1` | 1 | Sound batch R1: rough bed lie/rise, shore net cast/haul, thatch pick, twine lash |
| `claude/kathleen-water-soft` | 3 | Water and forest beds softer: river and fall loops dulled (centroid 5.0/5.5 kHz  |
| `claude/kathleen-wind-soft` | 1 | Wind loops softer and airier, no surf swell: low body 441 to 890 Hz, swell 12 to |
| `claude/steve-fall-quiet` | 1 | Quieter waterfalls: lower level, shorter reach, scaled by drawn flow |
| `claude/steve-mike-batch` | 4 | mike_queue: sound slots branches and test |
| `claude/steve-nature-debug` | 1 | F3: name the loudest Nature and Wind voice at the listener |
| `claude/steve-sound-sliders` | 2 | Sound pages: scroll inside the window, buttons wrap long text |
| `claude/steve-welcome-split` | 1 | Move the sound test menu buttons out of terrain_client.gd (sound_test_menu.gd) |
| `claude/steve-wind-bus` | 1 | Wind beds (desert, canyon) play on the Wind bus so the Wind slider controls them |
| `claude/tyler-790a` | 16 | cand: sound-sliders scroll fix |

## Kathleen / Kathreen (looks) (20)
| branch | ahead | last commit |
|---|---|---|
| `claude/kathleen-basic-looks` | 1 | Stage-one basic looks: 120 items get a shape from data/items/looks.json (RUNTIME |
| `claude/kathleen-body-details` | 1 | Ragdoll: nose, brow, chin, ears and thumbs |
| `claude/kathleen-clothing` | 1 | Basic clothing on the body: worn body, legs and feet items colour the third-pers |
| `claude/kathleen-dirt-pile` | 1 | Soil and clay piles: lumps half a dirt clump, packed tight (tight/jitter pile fi |
| `claude/kathleen-goal2-b` | 1 | Showroom: pickaxe and knife row for batch B |
| `claude/kathleen-held-pose` | 12 | First-person hands appear a little earlier (arm pitch 50), tool still about 17 d |
| `claude/kathleen-looks-v2` | 1 | Basic looks v2: pointed spear heads, bolder colours, every container and potion  |
| `claude/kathleen-looks-v5` | 1 | Basic looks v5: wooden bowl reads as wood, bigger axe head and axe, bigger bowls |
| `claude/kathleen-materials` | 4 | Building material skins (log, daub, stone block, brick, thatch) and place sounds |
| `claude/kathleen-photoreal-batch1` | 3 | Ground PBR: photo brightness, normal and roughness from the CC0 sets in the grou |
| `claude/kathleen-r1-looks` | 1 | Thatch material: fibrous straw instead of plank courses; fuller rough bed mat |
| `claude/kathleen-showroom-test` | 1 | test_showroom: follow the server-filled showroom (asks once, resolves ids, respa |
| `claude/kathleen-spades` | 7 | Looks for cut stone block, brick and mortar; block and brick shapes (RUNTIME) |
| `claude/kathleen-stone-look` | 1 | Ground stones: grey-brown tint at 1.05, no glow (were washed to flat white in su |
| `claude/kathleen-tool-pass` | 2 | Building tiers step 1: plank and fine wood wall, window wall, door (shut and ope |
| `claude/mike-evidence-bowl` | 1 | Evidence: the bowl SE of spawn from baked tiles with settled water (eye 1.7 m, l |
| `claude/mike-evidence-goal2b` | 9 | Evidence: pieces batch (rough_bed, thatch_wall, tripod_pot, clay_hearth) and the |
| `claude/mike-evidence-hands10` | 9 | Evidence: axe from the right at 2 m, real first-person view (Kathleen) |
| `claude/mike-pbr-ground` | 2 | PBR ground sets: 15 files (colour, NormalGL, roughness) from ambientCG Grass001, |
| `claude/sal-net-look` | 2 | Shore net: a hand net on a pole (hoop, bag, floats) instead of the hammer-like f |

## MikeW (flora and fauna) (6)
| branch | ahead | last commit |
|---|---|---|
| `claude/flora-wet-test` | 2 | test_flora_wet: skip reeds and water species; trees/shrubs beside water, any oth |
| `claude/kathleen-patches-now` | 1 | Patches now (existing stand placer): herbs, berry bushes and low berries grow in |
| `claude/project-thread-yttwff` | 1 | Action plan: no pollen in caves |
| `claude/sal-no-rose-berries` | 2 | Wild rose harvest gives rose petals (12 at 1x, in season), no berries |
| `claude/steve-cave-air` | 1 | Action plan: Steve_cave_air (cave air fade by depth, silent base, wet caves only |
| `claude/steve-flora-mutex` | 1 | Flora placer: guard the plateau cache with a mutex (server worker threads crashe |

## Sal (items) (19)
| branch | ahead | last commit |
|---|---|---|
| `claude/project-thread-5x1cni` | 2 | Item table and inventory class with tests (Items and crafting, no build number y |
| `claude/sal-bridge-note` | 11 | Building tiers plan: bridge ramps and supports reach into the ground |
| `claude/sal-building-items` | 1 | Building plan items: stone block, brick, mortar, ladder (state 31), piece materi |
| `claude/sal-building-tiers` | 1 | Plan and table: the six building tiers |
| `claude/sal-building-tiers-p1` | 3 | Move my two deleted master list files into proposed_removals |
| `claude/sal-ceiling-names` | 4 | Revert "Display text: floor sections are Ceiling sections (Dave: no item called  |
| `claude/sal-corner-snaps` | 1 | Building pieces join: wall to wall (straight and corner), wall on floor edge, fl |
| `claude/sal-hand-crafts` | 4 | Hand crafts only for the first tier: thatch four, plank chest, backpack, clothin |
| `claude/sal-hearth-oven` | 1 | Plan: clay hearth and oven as blueprints, tiered cooking stations |
| `claude/sal-item-cut` | 8 | Merge generator-v2 into item cut |
| `claude/sal-no-stack-caps` | 1 | Sal action plan: no stack caps, weight is the limit |
| `claude/sal-no-stack-caps-build` | 1 | No stack caps: a slot holds up to 65,535 (weight is the limit); 118 stack-1 item |
| `claude/sal-plan-updates` | 1 | Sal plans: Dave's QA answers (tools ladder, blueprint maker, bridge poles, fire  |
| `claude/sal-plans-r1` | 1 | Sal action plans: r1 recipes, rough bed, camp bench, cooking stations |
| `claude/sal-roast-names` | 1 | Roast names match Dave's: Roast Meat, Roast Fish, Roast Roots (RESTART, ids unch |
| `claude/sal-thatch-floor-hand` | 4 | Materials by hand: rough plank, cut stone block, cobblestone, stone shingle, woo |
| `claude/sal-thatch-sources` | 8 | Sal thatch plan: no spawn placement; flag spawn_boost |
| `claude/sal-tool-tiers` | 1 | Tool tiers: drop stone pick and saw per Dave's rulings; early tools plan |
| `claude/sal-weight-audit` | 2 | Weight audit: herbs and plants ultra light, audit note |

## Sonny (terrain and water) (30)
| branch | ahead | last commit |
|---|---|---|
| `claude/david3-bake-4f442c54` | 1 | David3 bake of 4f442c547658caa6baf4c80a32ae5f88a9395e2b: tiles, water, island ta |
| `claude/david3-bake-6f4801e8` | 1 | David3 bake of 6f4801e84dfc065e0ca0f62375b07034e2e86af5: tiles, water, island ta |
| `claude/david3-bake-c2eeb8e3` | 1 | David3 bake of c2eeb8e3aba8eed1932e6f5986a4964694e44fd5: tiles, water, island ta |
| `claude/david3-bake-e9a91504` | 1 | David3 bake of e9a91504cdcad7aa28ff328aac5fc4fce3d6d96a: tiles, water, island ta |
| `claude/erosion-fill-cap` | 1 | Action plan: cap erosion hill-foot fill (BAKE) |
| `claude/lake-lip` | 1 | Lakes: lip at least 4 m above the sea (coastal-flat bowls with lip 1-3 m flooded |
| `claude/land-types` | 5 | Merge remote-tracking branch 'origin/claude/generator-v2' into landtypes2 |
| `claude/land-types2` | 7 | River ore guarantee fires on every tile with a river unless the tile already has |
| `claude/land-types2-springfeed` | 11 | Merge remote-tracking branch 'origin/claude/steve-spring-feed' into combo2 |
| `claude/mike-bake-3adc` | 1 | Test bake (3,4) from sonny-outlets 3adc876b (TERRAIN_VERSION 38): tile, settled  |
| `claude/mike-bake-793` | 8 | Bake 793 (lake_c30d): settled water, stitch, island table |
| `claude/mike-bake-e23c` | 1 | Test bake (3,4) from sonny-outlets e23c5f99 (code id 5a5745de, TERRAIN_VERSION 4 |
| `claude/mike-bake-heads` | 1 | Heads bake (3,4) from sonny-final 7497a494: tile and the heads/breach/pits log l |
| `claude/mike-bake-land` | 8 | Bake land (land_1b9c): land types lines, test_tile_lakes |
| `claude/mike-bake-land2` | 9 | Bake land (land2): land types lines, test_tile_lakes |
| `claude/mike-bake-v29` | 1 | v29 bake: 9 tiles of sonny-foothills f49a1033 (TERRAIN_VERSION 33) + settled wat |
| `claude/mike-evidence-kathleen-13df38ae` | 102 | Evidence: world picture set on land-types2 fdc7b4e0 bake |
| `claude/mike-raw-heights` | 1 | Raw (pre-erosion) tile heights from claude/export-raw-heights 804eef36: 9 tiles, |
| `claude/mike-seam-test` | 8 | Mound read: DRAINAGE_PROBE=53900,68650 lines and the 8 m height dump x53700-5410 |
| `claude/pond-notch` | 1 | Kept pits: outlet notch starts 0.1 m under the rim (was 1.3 m under: the sim dra |
| `claude/sonny-farmland-tune` | 3 | TERRAIN_VERSION 35 for the farmland tune |
| `claude/sonny-held` | 2 | River mouth in the generator: estuary 300 m, bed to -2.5 m with a -0.6 m bar, 1: |
| `claude/steve-erosion-threads` | 1 | Bake tiles on several threads (--threads=N), files byte-identical |
| `claude/steve-ground-quiet` | 3 | test_ground_watchdog: dead stall with no failures retries at 30 s (the approved  |
| `claude/steve-river-seams` | 1 | tools/settle_block.sh: settle a block of tiles, stitch the seams, run the river  |
| `claude/steve-river-settle` | 11 | river_settle_report: a pond with a spring beside it whose river stays dry is FED |
| `claude/steve-settle-memory` | 1 | Settle: drain the native water core's changed-square list every 15 ticks (bad_al |
| `claude/steve-spring-feed` | 5 | test_head_pond_fill: do not test springs under 0.5 m3/s (they cannot fill a bowl |
| `claude/tyler-bake28` | 4 | Merge remote-tracking branch 'origin/claude/steve-river-settle' into tyler-bake2 |
| `claude/water-soak` | 1 | test_water_soak: count dropped films (under 4 mm) in the save-format error bound |

## Steve (systems) (9)
| branch | ahead | last commit |
|---|---|---|
| `claude/sal-auto-pickup` | 2 | Sal action plan: P toggles auto pickup |
| `claude/sal-fire-tiers` | 6 | Sal fire tiers plan: Dave's rules (biggest wood first, 3 pieces per tier) |
| `claude/sal-hoe` | 1 | Hoe smooth: no wear and a message when every edit is refused |
| `claude/sal-raise` | 1 | Shovel Raise mode and load: right click switches mode, drag soil or stone onto t |
| `claude/sal-shovel-sizes` | 1 | Shovel sizes: small 1, medium 4, large 8 pieces per stroke (RESTART, no save or  |
| `claude/steve-bed-respawn` | 5 | Respawn at your own bed: claim, landing search, repeat-death fallthrough, save |
| `claude/steve-go-spawn` | 1 | Esc > Admin > Go to spawn |
| `claude/steve-ground-debug` | 1 | Move the ground dump, ground self-check and hole probe out of terrain_client.gd  |
| `claude/steve-ladder` | 1 | Ladder climbing: grab with W facing a placed ladder, climb, step off the top |

## Tyler (Q&A testing and tooling) (19)
| branch | ahead | last commit |
|---|---|---|
| `Qwen3.8_9B_ReviewRefactor` | 1 | Qwen3.8_9B Code Review and Refactor Done |
| `claude/box-results` | 52 | David3 handoff: dead stop state 25 Oct 18:30 |
| `claude/david3-gate` | 1 | tools/gate.sh: trial merge in warm clones, parallel tests, timing lane with one  |
| `claude/david3-rig` | 13 | look_rig.sh: run on Linux (NVIDIA Vulkan under Xvfb), Windows path unchanged |
| `claude/david3-shot-gpu` | 1 | Add GPU variant of shot.sh (NVIDIA Vulkan ICD, no software render) |
| `claude/docker-test-box` | 12 | shot.sh: pick the NVIDIA Vulkan file by lookup, fall back to lavapipe; memory an |
| `claude/kathleen-biome-fix` | 1 | test_worldgen: flora biome check tolerates the float32 position falling across a |
| `claude/kathleen-crowd-fix` | 1 | test_worldgen: crown-spacing check skips pairs inside one shrub patch (wild rose |
| `claude/kathleen-shovel` | 2 | Placeholder soil_load and stone_load sounds for shovel raise mode (RUNTIME) |
| `claude/kathleen-tree-belts` | 1 | test_worldgen: skip pairs inside one shrub patch in the crown-spacing check |
| `claude/mike-goalpad` | 16 | Pad: Mike dead stop |
| `claude/mike-rig-v4` | 21 | Rig: wait at ground level, G to stand, notes |
| `claude/mike-rig-v5` | 38 | Rig: orbit-item mode (experimental), held-batch |
| `claude/steve-rig-item` | 1 | look_rig: ground default 31.25, exact showroom row match, --showroom-per N, over |
| `claude/steve-shot-landing` | 8 | Shot landing: judge by height only (a flying shot has no collider under it and a |
| `claude/steve-shot-lock` | 1 | shot_lock: ignore mouse look during a --shots run |
| `claude/steve-sqlite-warm` | 1 | Server block store: open the sqlite files once on the main thread before workers |
| `claude/steve-thread-safety` | 2 | Thread safety: guarded sim_levels snapshot, take_pair, locked cache swap, two he |
| `claude/steve-warning-699` | 1 | Move the confusable_local_declaration ignore back onto the admin_ok line. CHANGE |

# Verdicts received (owner answers; delete after the answer unless marked keep)

## MikeW (6 of 6, 1 Nov)
| branch | verdict | note |
|---|---|---|
| `claude/flora-wet-test` | PORT (keep until ported) | `test_flora_wet.gd` not in daily; MikeW cherry-picks onto a fresh branch, runs after RESTART |
| `claude/kathleen-patches-now` | DROP | superseded by `patch` rules (35 rows); porting would double-place |
| `claude/project-thread-yttwff` | DROP | 4-line note; plan archived in daily |
| `claude/sal-no-rose-berries` | KEEP until Sal answers | commit 1 already done; commit 2 (rose gives petals instead of hips) not in daily: Sal's call |
| `claude/steve-cave-air` | DROP | plan archived as `Steve_cave_air.md` |
| `claude/steve-flora-mutex` | ALREADY DONE | `_plateau_mutex` in daily `flora_placer.gd` |

## Jason (13 of 13, 1 Nov)
All 13 sound branches are already in the daily or to be dropped; none needs a port (git cherry and per-file diffs; not every hunk read). Full table in Jason's message; branches safe to delete.

## Steve (9 of 9, 1 Nov)
| branch | verdict | note |
|---|---|---|
| `sal-auto-pickup`, `sal-fire-tiers` | already done | code in daily; plan docs copied to `docs/archive/2026-11/old_branch_plans/` before deletion |
| `sal-hoe`, `sal-raise`, `sal-shovel-sizes`, `steve-go-spawn` | already done | patch-equivalent in daily (git cherry; not opened one by one) |
| `steve-ground-debug`, `steve-ladder` | already done | files in daily |
| `steve-bed-respawn` | PORT part, drop part | claim-by-lying superseded by E-on-bed `spawn_bed`; Steve redoes the landing search and repeat-death fallthrough on a fresh branch with `test_bed_respawn.gd`; keep branch until ported |
Open question for Dave (from Sal's fire-tiers doc): 3 pieces per fire tier; code already has 3 tiers, unchecked against the rule.

## Tyler (19 of 19, 1 Nov)
| branch | verdict | note |
|---|---|---|
| `Qwen3.8_9B_ReviewRefactor` | drop | 17 files of unreviewed Qwen 9B edits; not trusted; audit-doc text only if Jamie wants it |
| `claude/box-results`, `david3-gate`, `david3-rig`, `david3-shot-gpu`, `docker-test-box` | drop | Linux box and docker tooling; Windows gate is `run_tests.sh` + `tests_for_diff.py` |
| `kathleen-biome-fix`, `kathleen-crowd-fix`, `kathleen-tree-belts`, `steve-shot-landing`, `steve-sqlite-warm`, `steve-thread-safety` | already done | patch-equal in daily |
| `claude/kathleen-shovel` | PORT to Jason (keep until ported) | placeholder `soil_load`/`stone_load` sounds + `make_placed.py` not in daily (the spade look commit is) |
| `claude/steve-rig-item` | PORT (Tyler, keep) | `look_rig --showroom-per N`, exact showroom row match, ground default 31.25 |
| `claude/steve-shot-lock` | PORT (Tyler, keep) | mouse look ignored during a `--shots` run |
| `claude/mike-rig-v4` | Kathleen decides | rig part superseded; held-tool pose edits in `basic_look.gd`/`held_item.gd` are hers |
| `claude/mike-goalpad`, `mike-rig-v5`, `steve-warning-699` | drop | docs/logs only, experimental, one warning line |
