# Steve: Spawn column first (branch claude/steve-spawn-column)

Goal (Tyler): standing on the ground within 10 s of joining. Dave 25 Oct: sometimes the game starts with the player in the air; the ground under them is then never built and the player floats, so tests fail ("never finding ground").
Found in the code (terrain_client.gd):
1. The ground-under-the-player machinery (ask the server for the ground height, dive the streaming viewer to ground + 2 m, stage only the finest levels) runs ONLY while `flying`. A player who is not flying but airborne (the join at spawn + 28 m, a resumed saved spot in the air, a respawn, go-to-spawn) keeps the viewer at their own height, so the column below is built late or not at all.
2. `_ground_ready()` looks only 300 m down. An airborne start higher than that (a saved spot, a bad spawn y) never reads ready: the body glides level for ever.
Change (RUNTIME, client only, no protocol, no server change):
a. `_update_anchor`: the dive (surface request, viewer at ground + 2 m, finest-levels stage) also runs while `waiting_for_ground` (not only flying). Nothing else about following changes.
b. `_ground_ready()`: the down ray is 3000 m (same as `_collider_below`), so any height finds the collider once the column is built; `_arrive_on_ground` already sets the player just above it with the protection time. Fall distance is never real (arrival, no damage).
c. JOIN log line adds "column: asked at +N s, answer +N s, collider +N s" so a slow column is visible.
d. Test (test_spawn_column.gd, headless, no Godot scene): pure helper `column_wanted(flying, waiting, anchor_set, answered)` and ray length; plus a David3 run: start at 400 m and at 1500 m above the spawn (--start=x,y,z), expect ready under 10 s after the welcome and 0 "waiting for ground" after.
Shot runner: unaffected (it already waits for waiting_for_ground == false); the landing check in claude/steve-shot-landing treats an airborne start as "not landed" until the arrival drop, then counts the settle time from there, so the picture is never taken in the air. Branch is cut from steve-shot-landing for that reason.
Risk: dive for a waiting walker uses the existing server surface answer (one request per stop). Ray 3000 m costs one ray per frame while waiting only.

## Build notes (Tyler GO, conditions 1-5)
Built: `column = flying or waiting_for_ground` gates the dive in _update_anchor (viewer back to the player when not waiting: _viewer_ground_y reset each follow, stage view cleared); dive needs ground more than 40 m below, so a normal +28 m join, walker, go-to-spawn, respawn, and a player in a cave/tunnel (below the surface) are unchanged; _ground_ready ray 3000 m; join window adds "The ground is taking long: N blocks received, N failed, N still arriving, player height" after 60 s; JOIN log "column answer N s after the welcome".
David3 test: start at 400 m and 1500 m above the spawn (--start), expect "ground ready" within 10 s of the welcome; normal join unchanged.
Cave rule covered by headless test_spawn_column.gd (src/client/ground_column.gd dive rule); expect 'Test done: 8 pass, 0 fail'.

## Spawn near the ground (Tyler GO, Dave 25 Oct)
Instead of asking the server for the surface (David3 saw the column answer 19-23 s after the welcome), the client uses what the welcome already carries: the server computes the spawn y as surface height at the spawn x,z + 2 m at start (terrain_server._spawn_point). Join, go-to-spawn, death respawn and the cave-in respawn now put the player at the spawn point + 0.5 m (was +28 m), so the first frame is within 3 m of the ground; the player waits level for ground as before and arrival sets them down. A moved spawn only changes x,z on the server; y follows from it. Test: first frame within 3 m of ground and standing within 10 s for join, respawn, go-to-spawn.
