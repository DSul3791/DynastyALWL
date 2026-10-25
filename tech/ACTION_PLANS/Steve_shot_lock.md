# Steve: shot_lock, mouse look off while taking pictures (branch claude/steve-shot-lock)

RUNTIME, client only, behind the shot flag (normal play untouched). From Tyler's tech/CAMERA_TURN_RECIPE.md part A.
- terrain_client.gd: `var shot_lock := false`; the mouse-look branch needs `not shot_lock`; when the ShotRunner is created (a `--shots=` run) `shot_lock = true` and the mouse goes VISIBLE; the three places that capture the mouse capture only when not locked.
- shot_runner.gd is not touched (the lock is set where the runner is created). Parts B and C of the recipe (pose read-back, turn left 90) stay with Mike/David3 in the shot runner.
Test: a --shots run under Xvfb/display with the mouse moved: read-back yaw stays what the runner set. Normal play: mouse look unchanged (no --shots argument).
