# Standing setup for every picture run (Mike, Dave approved 25 Oct 2026: "keep this setup")

Do not change without Dave's say.

- Branch: claude/mike-rig-v4 (tools/look_rig.sh, src/debug/shot_runner.gd), merged with claude/steve-shot-lock (be20764e: mouse look ignored in a shots run) and claude/steve-ground-quiet (2a1d3fc6: the watchdog no longer kills a slow healthy stream).
- Call: `bash tools/look_rig.sh --item <id> --cam right --dist 1.5 --turns 3 --name tool_<id> --ground-max 120 --out <dir>`
  - Third-person tool shots: the body stays still, the camera orbits 0, +90, +180 degrees round it (same distance and height), pictures _a _b _c.
  - First-person shots turn the body; the pose is held every frame; read-back line `shot runner: pose ...` flags POSE MISMATCH (over 0.5 degrees).
- Waits: the shot fires 10 s after the client's "ground ready" (`--ground-settle` 10), at most 120 s (`--ground-max 120`), 2 s settle after each turn; the server wait polls the log for "listening" every 0.5 s (no fixed sleep).
- A shot taken while ground is not ready is saved as `<name>_FAILED_ground_not_ready.png` and the run ends with exit 4. Three identical pictures end with exit 3 (duplicate check).
- Warm client cache between runs: E:\Software\godotDev\rig_appdata (not Dave's game folder). The ground comes ready in about 2 s on a warm cache; a run of 3 pictures takes about 40 s.
- Server: its own throwaway store, a port nobody holds, shown in a visible window titled "Test server" (log tail, kept after the run with "--- run finished ---", closed at the start of the next run; `NOWINDOW=1` turns it off). Timings printed as `rig timing:` lines.
- Never run while Dave plays; tell him when the run starts and ends (mouse off during the run).
- First-person hand and tool cannot be drawn by the runner (it turns the first-person hand off); real-view mode `--realview` keeps hand, held tool and HUD on with the look-down set as a pose.
