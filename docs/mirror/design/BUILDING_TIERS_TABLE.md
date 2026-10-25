# Building tiers table (Sal, 25 Oct 2026; start of the living table Dave asked for)
Six tiers, every tier the same slots on the 2 m grid (wall 2.4 m high): wall, doorway, window wall, floor, roof, foundation. Sources: art/BUILDING_TIERS_PLAN.md, design/BUILDING_TIERS_AUDIT.md, Dave's 09:06 rule (fine wood and lower by hand, higher by hammer blueprint). Owner of every row: items, recipes, structures and blueprints = Sal; looks (PieceLook builders and models) = Kathleen. Kit item = the item in the pack or the takedown key; piece item = the placed thing. Higher tiers by blueprint take no kit into the pack: the kit is the internal takedown key.

| Tier | Slot | Kit item | Piece item | World state | Made | Cost | Model (PieceLook) | Status |
|---|---|---|---|---|---|---|---|---|
| Basic | wall | 252 | 253 | 37 | by hand (recipe 167, sal-hand-crafts) | 20 twine, 50 thatch, 15 stick | thatch_wall | exists |
| Basic | doorway | 265 | 266 | 44 | by hand (recipe 169, sal-hand-crafts) | 12 twine, 25 thatch, 12 stick | thatch_doorway | exists |
| Basic | window | 350 | 351 | 47 | by hand (recipe 180) | 12 twine, 20 thatch, 10 stick | thatch_window (new) | NEW |
| Basic | floor | 261 | 262 | 42 | by hand (recipe 166, sal-hand-crafts) | 6 twine, 20 thatch | thatch_floor | exists |
| Basic | roof | 263 | 264 | 43 | by hand (recipe 168, sal-hand-crafts) | 10 twine, 40 thatch, 12 stick | thatch_roof | exists |
| Basic | foundation | - | - | - | none: stakes in the ground | - | - | by design |
| Plank | wall | 352 | 353 | 48 | by hand (recipe 181) | 5 rough plank, 1 twine | plank_wall | NEW |
| Plank | doorway | 354 | 355 | 49 / 50 open | by hand (recipe 182) | 4 rough plank, 1 twine | plank_doorway | NEW |
| Plank | window | 356 | 357 | 51 | by hand (recipe 183) | 4 rough plank, 1 twine | plank_window | NEW |
| Plank | floor | 358 | 359 | 52 | by hand (recipe 184) | 5 rough plank | plank_floor | NEW |
| Plank | roof | 360 | 361 | 53 | by hand (recipe 185) | 5 rough plank, 2 stick, 2 twine | plank_roof | NEW |
| Plank | foundation | 362 | 363 | 54 | by hand (recipe 186) | 8 stone, 2 clay | plank_foundation (standard 4x4) | NEW |
| Fine wood | wall | 192 | 193 | 22 | by hand (recipe 119) | 4 lumber, 1 twine | wall_section (rename only) | exists, rename |
| Fine wood | doorway | 200 | 201 | 26 / 28 open | by hand (recipe 123) | 3 lumber, 1 twine | doorway_section (rename only) | exists, rename |
| Fine wood | window | 202 | 203 | 27 | by hand (recipe 124) | 3 lumber, 1 twine | window_section (rename only) | exists, rename |
| Fine wood | floor | 194 | 195 | 23 | by hand (recipe 120) | 4 lumber, 1 twine | floor_section (rename only) | exists, rename |
| Fine wood | roof | 196 | 197 | 24 | by hand (recipe 121) | 5 lumber, 2 twine, 2 stick | roof_section (rename only) | exists, rename |
| Fine wood | foundation | 198 | 199 | 25 | by hand (recipe 122) | 8 stone, 2 clay | foundation_section (rename only) | exists, rename |
| Log | wall | 364 | 365 | 55 | hammer blueprint 17 | 3 log, 1 twine | loghouse_wall | NEW |
| Log | doorway | 366 | 367 | 56 / 57 open | hammer blueprint 18 | 3 log, 1 twine | loghouse_doorway | NEW |
| Log | window | 368 | 369 | 58 | hammer blueprint 19 | 3 log, 1 twine | loghouse_window | NEW |
| Log | floor | 370 | 371 | 59 | hammer blueprint 20 | 3 log | loghouse_floor | NEW |
| Log | roof | 372 | 373 | 60 | hammer blueprint 21 | 4 log, 2 bark | loghouse_roof | NEW |
| Log | foundation | 374 | 375 | 61 | hammer blueprint 22 | 20 stone, 4 clay | loghouse_foundation (large 6x6) | NEW |
| Cobblestone | wall | 376 | 377 | 62 | hammer blueprint 23 | 10 cobblestone, 2 mortar | cobble_wall | NEW |
| Cobblestone | doorway | 378 | 379 | 63 / 64 open | hammer blueprint 24 | 10 cobblestone, 2 mortar | cobble_doorway | NEW |
| Cobblestone | window | 380 | 381 | 65 | hammer blueprint 25 | 10 cobblestone, 2 mortar | cobble_window | NEW |
| Cobblestone | floor | 382 | 383 | 66 | hammer blueprint 26 | 8 cobblestone, 2 mortar | cobble_floor | NEW |
| Cobblestone | roof | 384 | 385 | 67 | hammer blueprint 27 | 4 lumber, 6 cobblestone, 2 mortar | cobble_roof | NEW |
| Cobblestone | foundation | 386 | 387 | 68 | hammer blueprint 28 | 20 stone, 4 clay, 4 mortar | cobble_foundation (large 6x6) | NEW |
| Mason | wall | 388 | 389 | 69 | hammer blueprint 29 | 8 stone block, 3 mortar | mason_wall | NEW |
| Mason | doorway | 390 | 391 | 70 / 71 open | hammer blueprint 30 | 8 stone block, 3 mortar | mason_doorway | NEW |
| Mason | window | 392 | 393 | 72 | hammer blueprint 31 | 8 stone block, 3 mortar | mason_window | NEW |
| Mason | floor | 394 | 395 | 73 | hammer blueprint 32 | 6 stone block, 2 mortar | mason_floor | NEW |
| Mason | roof | 396 | 397 | 74 | hammer blueprint 33 | 8 stone block, 2 mortar | mason_roof | NEW |
| Mason | foundation | 398 | 399 | 75 | hammer blueprint 34 | 16 stone block, 6 mortar | mason_foundation (mason 8x8) | NEW |

## Foundation sizes
standard 4 x 4 m (Plank, Fine wood), large 6 x 6 m (Log, Cobblestone), mason 8 x 8 m with a deep stone skirt (Mason). Basic has no foundation (stakes in the ground). Mixing tiers on one foundation is allowed because the slots match.
