# David3 handoff (updated 25 Oct ~05:00 UTC; Dave away until ~14:55 UTC)
Box: container dynasty-david3, 9 CPUs (no pinning now), memory 10 GB (15 GB request pending Dave), swap 0. Push claude/* only. BP-T70: HEAD=<full hash> on the first line of every result.
Recreate after a restart (/tmp is lost): /tmp/gbin/godot -> /opt/godot/godot, GODOT_EXE=/opt/godot/godot; shot scripts (shot_gpu / shot_land2 with a 4-thread server default and no taskset); a watchdog that kills the client when the server dies.
Work copies (export folders, not git worktrees): /work/bake (bake clone, tests), /work/gs3a (generator-speedup 690ee171), /work/su_base (merge-793 5b9d9f9), /work/ts2 (thread-safety dba07947), /work/sc2 (spawn-column bbb4977d), /work/out_base (reference tiles 3,4 and 4,4).

## Reported
- Speed-up proof cbe31f76: 8 pass, 0 fail, md5 identical (results/20261025_speedup_cbe31f76). 3a 690ee171: 600-tick settle .water md5 identical (e35ba275...), test_gen_core 0 fail. The four tile bakes and 3b timing are run by the review thread's box.
- Flora mutex 8394ee6f: unfixed file crashed the server in run 1, fixed 0 of 10 (caveat: no SPAWNTEST lines printed, hybrid tree).
- Gate A sal-cooking-tripod d79a4a44: PASS (78 pass, 6 fail = base six). Baseline FAIL lines: results/20261025_baseline.
- thread-safety 0e23eb0a headless: 0.250 us per call, swap test 1 pass.
- Bakes of tile (3,4): c2eeb8e3, 6f4801e8, 4f442c54, e9a91504 (branches claude/david3-bake-*), no bakes allowed now except generator proofs.

## Running / queued (in this order)
1. thread-safety dba07947255c486dedd528bd2225030061a0ffdb then spawn-column bbb4977df2dca19fe55547a4517fa5dd7286ad4e (script /tmp/two.sh; results /tmp/g_ts2.txt, /tmp/g_sc2.txt).
2. kathleen-weak-looks 5ef0b60e8ecf23bd670060f9190963b77469c922: parse, local_check 233, check_look_names, test_pick_axes 0 failures.
3. Sal B edcfefee / C 03c2e9ee are superseded: B 15616045ecf22bd3ef1bb7f71cc6f13b427310c7, C b9c6afb86ed5fccec8445975a97bb50fa567d90c (gate in order, tests in /work/bake via gate script); sal-hand-crafts 3c5dde01; sonny-test-fixes dde9ff2e3dda35c8b14d5a6eed57b2d4c56d20a1 (test_pond_outlet retired); remove-old-builder 5c2ac5bb273c30cd06da8556b44e121ef027461c; water-soak b028ffc2; steve-rough-bed 6459b079 and bed-respawn; net-look b2aad0eb (K20 picture, cloth look compare).
4. Pending Dave: memory 15 GB (steps sent), standard picture set K01-K19 (quick set K01 K03 K05 K09 + a tool) once Tyler names a build; picture wait rule: shoot after landing check (needs the fix in the spawn-column line).
## Known issues
- shot_runner landing check false failure was fixed in later heads. Column answer takes about 20 s after the welcome in my rig. Server crash: _plateau_cache race (fixed by flora-mutex). bowl 1 hill picture thin-sheet unexplained.
