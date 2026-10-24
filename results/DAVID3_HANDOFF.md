# David3 handoff, 24 Oct 2026 ~23:50 UTC
Box: container dynasty-david3, 6-core cap, GTX 1050 Ti. Never touch game containers, keys, main. Push claude/* only.
Copies: /work/repo (do not switch branch: untracked .uid files block checkouts), /work/bake (bake clone and test copy), /work/pics (export of merge-793 a0e158df; use it for pictures only, never for gates).
Helpers in /tmp are lost on restart: shot_gpu.sh (NVIDIA ICD shot), look_rig.sh (= claude/david3-rig-only), /tmp/gbin/godot link (tools/godot shim is Windows only). Recreate: link /opt/godot/godot as godot on PATH and set GODOT_EXE=/opt/godot/godot for local_check.

## Done and pushed
- claude/david3-rig-only e792d7c5: look_rig.sh on Linux (merged by Tyler). claude/david3-shot-gpu 843e24c4: GPU shot script.
- Bakes of tile (3,4), branches claude/david3-bake-<hash>: c2eeb8e3, 6f4801e8, 4f442c54 (starved water), e9a91504 (water-v9: settle steady, 117076 wet cells, 3 FAIL: east seam, river ends inland near x60192 z76704, 1 river inland). Logs in results/20261024_bake34*.
- Pictures index: results/PICTURES_INDEX.md, how to request: results/PICTURE_REQUESTS.md.
- Tests reported: steve-new-player 81a3407e pass; tyler-790a d8d7a602 pass; sonny-final c2eeb8e3/22585d73/6f4801e8 parse pass; merge-793 a0e158df 5 pass 1 fail (6 new warnings in basin_census, water_settler, erosion_delta, hollow_finder); tyler-791a 02e0910c pass (duplicate sweep clean).

## Open
1. 792 gate, thatch shelter claude/sal-thatch-shelter e2986139: NOT PASS, not reported yet. parse_scan 0 problems, local_check pass (233), test_thatch_pieces passes, but the full run was 73 pass, 10 fail. On the base (generator-v2 47f7af7f) test_first_hour, test_first_town, test_inventory and test_slot_sounds PASS, so those 4 are regressions of the shelter branch: stone axe and spear no longer made by hand (recipe change axe 1 stone + 1 stick + 5 twine), tree and log steps follow. Tests that fail on both (old, not the shelter): test_drainage_flow, test_head_pond_fill, test_pond_outlet, test_showroom (FakeView 'net'), test_water_soak. test_worldgen: also FAILS on the base (readonly database errors, likely the box), so not the shelter. Fire state 1 check belongs to the fire-tiers gate.
2. Bed tests (test_bed, test_animal_senses, test_warmth) on claude/steve-rough-bed 6459b079: not started.
3. Pictures not done: 13 from the e9a91504 bake (lakes 17 ha at x58183 z73092, 6 ha at x54311 z75282, 3-4 ha lakes at x58376 z72600, x58005 z73467, x54328 z75263, x58347 z71337, head ponds, river window z75053-75780, pit window x53772-53788 z68570-68586, spawn x53316 z68476) with the bake branch claude/david3-bake-e9a91504 checked out in /work/pics, not /work/bake. Kathleen close-ups (conifer, cane, ferns sun/shade, stone pile) on generator-v2 e1fcbdf5, folder results/<date>_kathleen_close. Held-tools and stone centred redo go to Mike.
4. Dry-start settle (tick 9000, memory flat): command from Tyler in MERGE_CHECK_NEXT3.md, not run.
5. Raw-heights export: Mike has it; only if his job fails.
6. Bowl 1 (53760,68650 east): thin sheet over a flat plane in two renders, unexplained (Mike's Windows picture decides).
## Next steps
Report item 1 to the coordinator and Tyler first. Then bed tests, then pictures one at a time at nice 19 under the load 6 and PAUSE rules.
