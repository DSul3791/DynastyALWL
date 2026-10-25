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

## State at 25 Oct ~18:30 UTC: DEAD STOP (Dave's order); nothing running, nothing queued
Latest reported (all with full HEAD= in the thread): traps 9aadcbb4 PASS, sound hookup 1c488691 PASS, snare 7a1de565 PASS, settle sweep 9188ffc6 PASS, smoke flags2 f9059cf5 PASS, test_bed hardening 9da17707 PASS, Kathleen looks 1798c127 PASS, roof fix 9d8ba335 PASS, new looks 43fac154 PASS (108 pass 0 fail), hide clothing 6bb00a51 PASS, look-shots 83db2539 PASS, land-types 1b9c6f82/land-types2 fdc7b4e0/c1999b6e PASS (bake tile 3,4: 288570 field cells), land-types2-springfeed 5e0038e6 FAIL (test_head_pond_fill spring 2681336), piece-shots 9c88de5e PASS. Not started (went to Mike): item cut 6f2ae555, building tiers p1 5d42ec40.
Pictures in results/: placeables_2ba70df1, placeables_1798c127, thatchroof_9d8ba335, looks_43fac154, itemshots_*.
Rules now: never delete any result or file (BP-T79); keep gates in their own export folder (a shared /work/bake checkout broke one of my picture runs); baseline test list is empty; warning baseline 227; merge_check.py needs a git checkout (/work/bake) and fails only on build number when the base is stale.

## State at 25 Oct ~13:30 UTC (Dave away until ~14:55)
Reported since the first handoff (all with HEAD= full hash in the thread): generator speed-up 3a/3b proofs (md5 identical, 600-tick settle identical), flora mutex, thread-safety, spawn column (merged head d002d4fe: 10x respawn/go-to-spawn clean), Sal A/B/C, hammer blueprints/list, torch, inner voice, eat-once 75fd9ff3 PASS, item shots ed93634d PASS, fish B ff873d0b / C 03db354a / balance 8558333c PASS, bow shoot 42075f59 PASS vs plain generator-v2 9f55bbf0, FINAL 793 (lake-size c30d6d5f + tiles ee50b0e2: only merge_check fails: stale base, conflict marker in ambience_slots.gd.uid, build 806 < 808), test re-pin d845e8ec (103 pass, only test_showroom fails; drainage rises found 16), lake bakes (lake-size, lake-4-3 c30d6d5f: (4,3) guaranteed lake 8.5 ha), flora-wet test, drainage rises list. Open results: hearth/oven 0f190ff2 FAIL (test_dishes: flatbread/honey_loaf/roast_joint not made at the lit fire).
Running: item master 422beb3b, then tool tiers ad07a34b parse_scan (script /tmp/q27.sh).
Build 810 baseline (generator-v2 9f55bbf0): failures drainage_flow, head_pond_fill, river_ore, river_surface, showroom, water_soak (the test re-pin branch fixes five of them; test_pond_outlet retired). Warning baseline now 227.
Scripts: results/david3_scripts (older), plus the gate function in /tmp/q*.sh (fullgate: export hash to /work/q_<8hex>, import, parse_scan, marker grep, local_check, all test_*.gd, duplicate sweep).

## Running / queued (in this order)
1. thread-safety dba07947255c486dedd528bd2225030061a0ffdb then spawn-column bbb4977df2dca19fe55547a4517fa5dd7286ad4e (script /tmp/two.sh; results /tmp/g_ts2.txt, /tmp/g_sc2.txt).
2. kathleen-weak-looks 5ef0b60e8ecf23bd670060f9190963b77469c922: parse, local_check 233, check_look_names, test_pick_axes 0 failures.
3. Sal B edcfefee / C 03c2e9ee are superseded: B 15616045ecf22bd3ef1bb7f71cc6f13b427310c7, C b9c6afb86ed5fccec8445975a97bb50fa567d90c (gate in order, tests in /work/bake via gate script); sal-hand-crafts 3c5dde01; sonny-test-fixes dde9ff2e3dda35c8b14d5a6eed57b2d4c56d20a1 (test_pond_outlet retired); remove-old-builder 5c2ac5bb273c30cd06da8556b44e121ef027461c; water-soak b028ffc2; steve-rough-bed 6459b079 and bed-respawn; net-look b2aad0eb (K20 picture, cloth look compare).
4. Pending Dave: memory 15 GB (steps sent), standard picture set K01-K19 (quick set K01 K03 K05 K09 + a tool) once Tyler names a build; picture wait rule: shoot after landing check (needs the fix in the spawn-column line).
## Known issues
- shot_runner landing check false failure was fixed in later heads. Column answer takes about 20 s after the welcome in my rig. Server crash: _plateau_cache race (fixed by flora-mutex). bowl 1 hill picture thin-sheet unexplained.

## How to run each gate (for MikeW, if David3 is lost). Scripts are copies in results/david3_scripts/ (they use Linux paths /work/..., /opt/godot; on Windows use tools/look_rig.sh and the editor exe from tools/godot).
- Always: first result line `HEAD=<full 40-char hash>`; check out exactly that commit in a clean copy (on the box I used git archive <hash> into a folder, because untracked .uid files blocked checkouts in /work/repo). Import once (`godot --headless --path . --import`), then:
- Standard gate: `python3 tools/parse_scan.py` (expect 0 problems); `bash tools/local_check.sh` (expect "no new warnings against baseline (233 total)"; on Linux put a `godot` link on PATH and set GODOT_EXE); all `src/worldgen/tools/test_*.gd` via `godot --headless --path . --script res://src/worldgen/tools/<name>.gd` (script gateN2.sh loops them: pass = exit 0 and no "N fail"/FAIL/SCRIPT ERROR). A branch passes if it adds no failure beyond the base list in results/20261025_baseline (test_pond_outlet retired by Dave's OK).
- Duplicate sweep: python over data/items/items.json and recipes.json (keys are names; check "number" unique, next_number > max); expected items max 266 next 267, recipes max 169 next 170 at the time.
- Pictures: shot_land2.sh (server GPU, Xvfb, own temp store, server --threads=4 default via SRVARGS) with SHOTSPEC="name:x,agl,z,yaw,pitch,hour,weather,-1;..." and EXTRA flags; look for "landed" lines; picture wait: --wait 40 --settle 10..15 while the landing check is trusted. Check duplicates with pubcheck.sh before publishing; publish with run_jobs.sh publish (PNG in <dir>/shots become JPEGs in box-results).
- Spawn/crash gates: two.sh (thread-safety dba07947 then spawn-column bbb4977d), mutex.sh (hybrid flora file swap); the client hangs forever if the server dies: wd2.sh kills it.
- Generator proofs: su2.sh (bake_tiles 3,4;4,4 with/without cache, md5 against /work/out_base made from merge-793 5b9d9f9, memory sampled from the cgroup), gs2.sh (600-tick settle .water md5, old vs new .so), test_gen_core.gd. No bakes without Dave's go.
## Caveats
- taskset pinning (`taskset -c 0-3`) was used in the mutex/thread-safety/two.sh runs until 04:50 UTC; now a no-op shim and server --threads=4 instead. The mutex 10-run proof used a hybrid tree (spawn-column 82e01b1a with flora_placer.gd swapped) and printed no SPAWNTEST lines.
- Pictures taken with 10 s waits (before the landing fix) can be mid-air; use heads with the landing check.
- The box cannot compile the C++ .so; the Linux .so used is the one committed in the branch.
