# Concerns: MikeW_LocalAgent (2026-10-22, after re-reading HOW_WE_WORK, REVIEW_VERDICT, DECISIONS)
Raised for Dave's PC. None stops the restart; items 1 to 3 should be settled first.
1. Hash gate across platforms: the "scratch hash" and edge-match gates were set with the Linux cloud build. Dave's Windows custom engine may give different float results, so a hash could differ with no real bug. Run the gate once on the PC, store the result as the new baseline, and keep tiles baked only on the PC.
2. Permission prompts: the auto-mode checker refused fetch, pull, commit and push until Dave's rules were committed (d3ecdc7). A local run that stops on a prompt silently blocks every cloud thread waiting on it. Need: rules confirmed after each session restart, and a thread told to report "blocked on permission" in one line.
3. Line endings: Windows git warns LF to CRLF. A CRLF `.sh` breaks in Git bash and CRLF changes file hashes. Add `.gitattributes` with `*.sh text eol=lf` before local_check.sh lands.
4. Shared machine: tests, bots (bots.sh waits 40 s per server start) and Dave's own game share 8 GB and one GPU. Long gates (882 tests, bakes) must run when Dave is not playing; MikeW needs a queue and a "Dave is playing" stop word.
5. Windows pieces still missing: godot shim lives in /tmp today (fix: tools/godot.cmd in repo), no ffmpeg (sound tools), no WSL. The server in bots.sh may trigger a Windows firewall prompt on first run.
6. PC must stay awake and Claude Desktop open; if it sleeps, local-first stalls. Needs keep-awake (a Desktop setting I can request).
7. Untested: the 882-test total runtime and tools/items_check.py, check_controls.py, sound_check.py on Windows. Will time them on the first run.
8. Run only through `--script` or a named scene; a bare `godot --headless --path .` starts a terrain server.
