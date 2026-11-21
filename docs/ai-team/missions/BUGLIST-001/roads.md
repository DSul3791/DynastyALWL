# BUGLIST-001 roads ledger: BUG-007 "Survey a Path" immediately says the road is finished

Baseline SHA: f5d6b54 (origin/dev). Branch: claude/buglist001-roads. No Godot run (cloud): tests below are NOT RUN until the test PC run.

## BUG-007

**Reproduction (by code trace, not run).** Hoe in "Survey a path" mode, left click on the ground:
client `_grade_point_here` (src/client/held_item.gd) sends `ACT_HOE_GRADE_POINT` with b=0 (first marker) ->
server `_hoe_grade_point` -> `_road_marker` (src/stream/server_items.gd) creates the job `{"head": here, "markers": [], "seg": null}` and says "Road started at this marker".
The next server tick (`tick` calls `_road_tick` every frame) finds `seg == null`, `_road_next_segment` returns false (no markers), so the tick erases the job, sends
`road_marker_done` for the head (flag comes down) and says "The road is finished." - within one frame of the first click.

**Root cause (evidence).** `_road_tick` treated "no markers left" as "road done" without asking whether any road had been built. A freshly started job always has zero markers,
so it finished the instant it was created. The existing test (test_server_items.gd) never ticked between marker 1 and marker 2, so it never saw this.
Not a guess: the control flow above is the only path that emits that message.

**Spec followed.** The Dave 3 Nov 2026 surveyor-mode comment in server_items.gd: "The first marker of an idle job is where the road starts ... the builder ... goes for the next nearest.
The job is done when none are left." Kept; no new road mechanics. The fix only distinguishes a job that has built something from one that is still being surveyed.

**Change (src/stream/server_items.gd).**
- Job gains `"built"` (set true when the builder takes up its first stretch in `_road_next_segment`).
- `_road_tick`: with no segment and no markers, a job that has not built stays alive (still surveying); only a built job finishes with "The road is finished."
- Distinct messages: first marker "Survey begun at this marker: set the next marker and the road builds toward it."; later markers "Marker set: the road builds toward it from the first marker." (surveying) or
  "Marker set: the road builds toward the nearest one, then the next." (building); "The road is finished." only after a road was built.
- Restart/cancel: because a lone start marker now persists (it used to vanish with the false "finished"), `_road_marker` takes a new `chained` argument (the existing `b` field of
  ACT_HOE_GRADE_POINT, which the client already sends: 1 = within 40 m of the previous marker, 0 = starts a road). An unchained marker replaces a job that has only its start marker
  (old flag comes down via `_road_abandon`). A road already being built is not restarted. No protocol change (the `b` field was already sent, previously ignored).
- Losing the hoe still abandons the job (flags down); a disconnect still erases it.

**Not changed / persistence.** Road jobs are in-memory only (`_roads`), not saved; nothing to save/load. Client and PROTOCOL.md untouched.

**Tests (NOT RUN).** src/worldgen/tools/test_server_items.gd, extended in the existing road block:
a fresh survey stays a survey over 20 ticks with only its start marker; says "Survey begun", never "finished"; start flag stays up; an unchained marker restarts a lone survey (old flag down);
next marker joins; a tick then builds (built true, not finished); an unchained marker does not restart a road under construction; building to the end gives "The road is finished." exactly once.
The existing two-marker and three-marker road checks are unchanged and should still pass. Would fail before the fix: the first tick erased the job.

**Regression risks.** (1) A lone start marker now stays until the player sets another, drops the hoe, or restarts; the red flag stays until then (previously it came down at once, falsely).
(2) If the builder catches up with a walking player after the last marker, the road is "finished" (by design); the next marker then starts a new road at that marker, and the client's "Marker set: the road builds behind you" is generic. Pre-existing, not touched.
(3) Markers all more than 40 m from a lone start are skipped (flags down) and the job keeps surveying.

**Status: NEEDS PLAYER VERIFICATION.**

**F6 check.** Equip a hoe, pick "Survey a path", left click the ground once: expect "Survey begun at this marker..." and the red flag staying up with no "road is finished".
Walk about 10 m and click again: the road builds toward the marker and "The road is finished." appears only once it has reached it with no markers waiting.

## Test evidence (PC run, 13 Nov 2026)

Every GDScript test marked "NOT RUN" above has now run (below); picture lanes and visual or sound checks have still not run. Ran on the David4 test PC (Linux, Godot 4.7.2 voxel build, headless, 2 jobs, fresh import) on `claude/buglist001-integration` at 8e46c4b254ed8061938cecee06a2cbb8665393c9 (dev f5d6b54 + all seven BUGLIST-001 heads). Result: 370 pass, 0 fail, no retries (fast 361/361, timing 8/8, slow 1/1 test_worldgen). validate_items PASS (0 errors), check_look_names PASS, warnings: none new over tools/warning_baseline.txt. Startup smoke: welcome 15.7 s, ground ready 133 s, 0 script errors, exit 134 (known headless exit). Picture lanes (5): NOT RUN; visuals and sound not checked. Logs: David4 /work/lanerun/bl001b_plan, /work/lanerun/bl001b_extra. An earlier run on a0b5365 failed 2 tests (test_hammer_list counts, test_server_items road restart height) plus 3 warnings; those were test-only fixes, reviewed, and are in 8e46c4b. Merged to dev by PRs #1068-#1074; dev add271196 has the identical tree (c6ec74eb). Status stays NEEDS PLAYER VERIFICATION until Dave's F6 check.
