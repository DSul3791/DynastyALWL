# Steve: shot runner waits for the camera to land (branch claude/steve-shot-landing)

David3 finding 25 Oct: the runner starts its settle timer at the first "ground under" line, before the camera has landed, so a short-wait picture was taken at 64.7 m over forest ("stopped flying at 65.0 m").
Cause: shot_runner._next() sets client.flying and puts the body at 400 m; once voxel ground exists it moves the body to ground + agl and starts the settle clock at once. The client is still flying and its collision/stream follow hasn't caught up.
Change (RUNTIME, debug only, src/debug/shot_runner.gd, no protocol):
1. After the body is placed, the settle clock (_moved_msec) stays unset until landed: client.flying is false or the body is within 0.6 m of ground + agl (absolute-height shots: within 0.6 m of that y), and client.waiting_for_ground is false.
2. Landed by 90 s after placement or the shot is marked: prints "shot runner: FAILED <name> never landed (y, wanted y)", still saves the picture as <name>_FAILED.png, goes to the next shot.
3. The existing "settle seconds" then run from the landing moment.
Test: run the 2-shot recipe with --shot-settle=10; the log must show a "landed" line before each "saved" line and heights within 0.6 m. Parse scan + check_controls.
Risk: none to the game; shot runs only.

## Build notes
Tyler GO: 0.5 m, 90 s, checked once per spot. Built in shot_runner.gd: _landed/_land_failed/_want_y/_placed_msec; log lines "shot runner: landed <name> at y .. (wanted ..) after .. s" and "shot runner: FAILED <name> never landed (y, wanted y)"; failed picture saved as <name>_FAILED.png. Branch also merges claude/steve-ground-quiet (same file). Force a failure by passing a shot whose y is wanted far above where the body can stand, e.g. a 2 m-wide ledge request is not needed: simplest is the test hook below.
