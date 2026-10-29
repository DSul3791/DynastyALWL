# Steve: always-playable smoke row (branch claude/steve-smoke-row c227ff8)
Class: rig measurements. One small thing: `look_rig.sh --frametime S --quality 0-3` prints ONE line "shot runner: frametime quality Low frames N avg A ms p95 P ms max M ms (OK|FAIL over 33 ms)" after a 10 s warm-up. Rig-only code (src/debug/shot_runner.gd, tools/look_rig.sh), no game behaviour change, TEST_RECIPE row added.
Test: Mike runs `look_rig.sh --frametime 20 --quality 0` once; one number (p95) per build. Parse_scan clean.
Questions for Tyler: (1) is p95 under 33 ms the right pass line for Low? (2) should the number be added to the daily Mike batch line?

## Tyler reply (03:50 UTC 24 Oct, once; BP-T52). GO, branch claude/steve-smoke-row (already pushed, c227ff8), label RUNTIME (debug only). Answers: (1) Yes, p95 under 33 ms is the right pass line for Low (30 fps floor on the minimum 1050-class machine), with the two extra lines below. (2) Yes, add the line to Mike's batch and keep a table.
Best-practice suggestions (standard frame-time practice: percentiles and hitches matter more than the average):
1. **Report avg, p95, p99 and max, plus the count of frames over 50 ms.** An average of 20 ms hides stutter. PASS = p95 under 33 ms AND frames over 100 ms = 0 after warm-up; WARN if p99 is over 50 ms.
2. **Repeatable scene.** Fixed spot, fixed camera path or fixed pose, fixed time of day and weather, same seed, flora and water on; print the spot and the build number in the line. Compare only like with like.
3. **Take out measurement noise.** Turn VSync off for the run (VSync snaps times to 16.7 ms multiples), run the 10 s warm-up so shader and mesh builds do not count, close other apps, and take the median of 3 short runs when a number is borderline.
4. **Say what machine.** Add GPU name, driver, quality tier and window size to the line, so a number from Dave's PC and from Mike's can be told apart.
5. **Table per build.** Mike appends one row per build to tech/FRAMETIME.md (build, tier, avg, p95, p99, max, >50 ms count, machine); a rise of more than 10 percent versus the last build is a named regression to the owner of the newest merge. This is Mike's goal 4 and the engine-health number for Steve's goal 1.
6. **Also run Mid and High once a day** (quality 1-3) so a tier-specific regression shows; the pass line applies to Low only.
7. **Docs.** Header of look_rig.sh and a row in TEST_RECIPE.md (FRAMETIME). Merge: next hourly gate.
