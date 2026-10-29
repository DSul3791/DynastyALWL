# Review: Tyler (Systems / Steve_ProblemSolver), 2026-10-22
## 1 Keep
- Questions only on the page, pickable (RULE 1): kept me from waiting on Dave; I never lost a day.
- Grouped test card (RULE 2) + TEST_QUEUE.md: one ask per few builds instead of five single asks.
- BUILD_LOG line per build with "restart needed or not": Dave and Steve always knew what to restart.
- Headless load + check_warnings before every push: no broken pull in 15 pushes.
- P0-P3 priorities (BP-T23): "present focus" let me drop scale work cleanly.
## 2 Change
- Build numbers collide: 3 renumbers this session (613, 627, 640). Each costs a rebase, a BUILD_LOG edit, a second push. Fix: `tools/next_build.sh` that reads origin's BUILD_LOG and prints the next free number, run right before commit. Saving: about 4 tool calls per push (guess).
- Every thread edits terrain_client.gd (5,200 lines): BUILD conflicts, huge reads. Fix: rule "new client logic goes in src/client/<feature>.gd, terrain_client.gd only wires it"; BUILD const moves to its own file src/shared/build.gd (one line, own merge). Saving: most rebase conflicts, and 10-20k tokens per full read (guess).
- Status-check hooks every 5 minutes force a checklist post even when nothing changed. Fix: only when a step changes or 20 min pass. Saving: small, but noise for Dave.
- Cold-cloud headless runs wait 40 s per test and fail on slow joins (three flaky tests this session). Fix: long runs go to MikeW (RULE 3), cloud only for parse + warnings. Saving: about 2-3 minutes per run (measured).
- Dave's crash and telemetry logs never reach the repo, so crash hunts were blind. Fix: keep the plain crash note (619); add telemetry summary of last 5 minutes into the on-screen note so a screenshot is enough. Saving: whole crash-hunt rounds (guess).
## 3 Missing
- BP entry for load/bot tests (tools/bots.sh, tech/BOTS.md): what to run before claiming a number.
- BP entry for "server restart needed" wording and the stale-server rule (621 handles it in code; the doc should say it).
- BP entry for headless repro of player-physics bugs (--embed-test, --dig-next-test pattern).
## 4 Conflicts
- "Never edit another thread's code" vs reality: bug fixes in shared files (terrain_client.gd, server_items.gd) overlap (my void rescue and Willy's rock rescue were written in parallel). Needs: owner per function, or ask the owner first.
- "Questions: pickable only" vs bugs where the answer is free text (inside the hole or on the rim?). I asked in the thread; the rule allows no path.
## 5 My area
- Server/client version mismatch was the likely cause of the "0 blocks" join hang (joined an old server). Best practice is a handshake that carries a build id and refuses a mismatch with a plain message; we only added a launcher workaround (621). Recommend: add `build` to the welcome and show "server is out of date, restarting" on mismatch (protocol bump, small).
## 6 Token moves
- Read BEST_PRACTICES by section, not whole (26 KB); skip BIG_PICTURE re-reads unless changed.
- Replies to Dave: result + one waiting line; long detail goes in BUILD_LOG or a file.
- Use grep/line ranges on big files, never full reads; avoid re-reading after edit.
- Handoff one page (done), no recap of pushed builds already in BUILD_LOG.
## 7 Verdict
Process good for now, needs changes (build numbers, big shared client file, free-text question path).
