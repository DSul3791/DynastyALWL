# WOOD-SYSTEM mission checkpoint

Thread: "Rebuild tree harvesting and wood system" (Dave, 15 Nov 2026 06:06Z). Design and phases: `docs/design/TREE_WOOD_TOOLS_DESIGN.md`. Source brief: PR #1147 (`docs/ideas/TREE_WOOD_TOOLS_CREATOR_HANDOFF_2026-11-14.md` on branch `feature/wood-system-creator-handoff-2026-11-14`). Base: dev 40bea035. Branch: `claude/project-thread-dgoucu`.

| Phase | State | Head | Tests |
|---|---|---|---|
| 1 Documents | DONE, merged to dev (PR #1148) | 3761fb79 | docs only |
| 2 Materials and tools | DONE, merged to dev (PR #1149) | dev 19808e87 (head 3bde6c01) | Lane A 279/279 at 3db7f28b, validate_items 0 errors at 3bde6c01; lane B key tests 18/18, smokes 3/3. NEEDS PLAYER VERIFICATION |
| 3 Trees and logs | DONE, merged to dev (PR #1150) | dev e3b6f01b (head 44061063) | Both lanes passed after two stale trunk tests were updated. NEEDS PLAYER VERIFICATION |
| 4 Carving and knife menu | DONE, merged to dev (PR #1151) | dev e09e920a (head f7ecb9fd) | Both lanes passed after test-layout, triangle-cap and cost-compare fixes; client chest step NOT RUN (fails on dev too, W-27). NEEDS PLAYER VERIFICATION |
| 5 Hauling | DONE, merged to dev (PR #1152) | dev 735ef18d (head 87b3b51e) | Both lanes passed after three test fixes (one log per give, live logs only, row total 235). NEEDS PLAYER VERIFICATION |
| Rolling collisions and drag (Dave 15 Nov 16:50Z) | DONE, merged to dev (PR #1154) | dev d13ed508 (head 481157c2) | Gate review passed on the second pass; lane A 229/230 (test_flora_density timeout, known PC flake), lane B 7/7 key tests and 3/3 smokes. NEEDS PLAYER VERIFICATION |
| Trees fall already in logs (Dave 16 Nov 00:57Z) | DONE, merged to dev (PR #1177) | dev 5352ecf4 (head 4d3f7ca9) | The whole trunk, delayed split, crowd check, hand-cut trunk path, yellow band and trunk cap are deleted; pieces swing down over 1.5 s and crush on landing (s5 Felling fall, W-30). Both lanes passed. NEEDS PLAYER VERIFICATION |
| Logs use real physics (Dave 16 Nov 17:36Z) | IN REVIEW (branch claude/project-thread-dgoucu) | pending | Loose logs are Jolt rigid bodies on the server; walking into a log stops the walker and pushes it (ACT_PUSH_LOG, protocol 125); the scripted rolling (W-28) and the client kick of logs are deleted (s5 Rolling, W-31). New test_log_physics.gd. Cloud: gdparse and the Python checks only. Lanes: pending. NEEDS PLAYER VERIFICATION |

Approvals: W-3, W-4, W-5, W-6 and part of W-8 were answered by Dave directly (15 Nov 2026 06:18Z to 06:21Z). For every other W row he said "Just make them reasonable and we can adjust them later", so those rows are adopted, provisional, and Dave adjusts them after play. No W row is open. Nothing is playable-verified.

All five phases are in dev at 735ef18d (15 Nov 2026). Automated tests passed on both PC lanes per phase; nothing has been played. Open for Dave's F6 pass: the looks (carving station, benches, sawbuck, sled and wagon are placeholders), the second carried log, rolling logs, the knife menu through the client (the items_check chest step fails on dev too, W-27), and every provisional value in s6 (W-1 to W-28).
