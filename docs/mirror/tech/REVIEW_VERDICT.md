# Process review verdict (Guru, 2026-10-22 15:10). Inputs: REVIEW_Steve_ProblemSolver (file REVIEW_Tyler.md), REVIEW_Sonny, REVIEW_Sal_Crafts (Radar's role), REVIEW_Kathleen, REVIEW_MikeW_LocalAgent, plus my own.

## Verdict
KEEP the structure. All five threads say "good for now". CHANGE eight things (on the question page) and add token habits.

## Research (sources) and where it agrees or disagrees with us
- Anthropic: agents use about 4x and multi-agent about 15x the tokens of chat; multi-agent fits poorly when agents share context or depend on each other; most coding tasks have fewer parallel parts than research; agents are "not yet great at coordinating in real time". https://www.anthropic.com/engineering/multi-agent-research-system
  AGREES with: BP-T20 on-demand workers, team merges (6 workers), BP-T22 routed cross-talk limits. Warns about: more threads = more cost, so no new threads (TEAM_PROPOSAL).
- Claude Code best practices: the context window is the most important resource; give the agent a check it can run; keep instruction files short and prune them (long files get ignored); use subagents/fresh context for investigation and review; /clear between tasks. https://code.claude.com/docs/en/best-practices
  AGREES with: local_check script (BP-C83, C80), CI (C85), short HANDOFF (T05). DISAGREES with our practice: BEST_PRACTICES.md (83 entries) read whole daily is itself the "over-specified instruction file" (fix: role digests, question rv-bp-digest).
- GitHub Git LFS: free plan 10 GiB storage and 10 GiB bandwidth; over the cap with no payment method LFS is disabled until next month or pushes are blocked. https://docs.github.com/en/billing/concepts/product-billing/git-lfs
  WAS: partly disagrees with BP-C108 (LFS caps). CORRECTED 15:20 after Dave: cloud never uses tiles (RULE 3) and the repo is 142 MB, so LFS is unnecessary; keep tiles in git as backup (question rv-lfs).
- Trunk-based development: short-lived branches merged quickly are linked with high delivery performance; slow or inconsistent review undermines velocity (secondary source, DORA only mentioned, not verified). https://www.minware.com/guide/best-practices/trunk-based-development
  AGREES with BP-C107 but warns the Technical Director merge must happen every cycle (fast path in IMPLEMENTATION_PLAN step 2).

## Changes, ranked by saving (savings are guesses unless the review measured)
1. Build numbers assigned at merge + `tools/next_build.sh` + BUILD const in its own file (BP-C101, C107). Saves about 3 renumbers and 5 re-pushes per evening. [Dave: rv-build-numbers]
2. Split the 3 huge files (server_items.gd 5,000 lines, inventory_view.gd 3,800, terrain_client.gd 5,200). Saves 20-30 percent of tokens on each Items/Systems edit, fewer conflicts. Big fix. [Dave: rv-big-files]
3. Local-first with one command `tools/local_check.sh` (addons load, validate_items, warnings --changed, touched tests, pass/fail only); long gates (882 tests, edge match, scratch bakes) go to MikeW. Saves about 20k tokens per gate and 2-3 min per run (Steve_ProblemSolver measured). [Dave: rv-local-first]
4. Commit the warning baseline (233) so only new warnings report. Saves 1-2 reruns per push. [Dave: rv-warning-baseline]
5. Role digests (about 15 lines) of BEST_PRACTICES instead of the whole document daily. Saves 10-15 KB per thread per day. [Dave: rv-bp-digest]
6. One-line data hooks allowed in another thread's file, announced in BUILD_LOG (real overlap: piece_look.gd, placed_sounds.gd, terrain_client.gd). [Dave: rv-shared-files]
7. "Still waiting on:" only when something is pending (a conflict with RULE 2 "never wait", Sal). [Dave: rv-waiting-line]
8. LFS with cloud skip. [Dave: rv-lfs]
Done by me without Dave: BP-T27 token habits, BP-T28 (11 gap entries from the reviews), wording fixes C60/C80/T08, handshake build id approved as a small protocol bump.

## Jobs for restart (from the reviews; queue after Dave's go)
Steve_ProblemSolver: build-id handshake; next_build.sh; BUILD const file; split terrain_client wiring; telemetry summary on screen. Sonny: probes folder; test_head_pond_fill.gd (would have caught the 623 pond bug); command list for MikeW gates. Sal_Crafts (Radar's role): structures.json carries look, clears_grass, sound (about 50 percent fewer edits per new piece); one container model. Kathleen: deterministic asset scripts; tools/look_sheet scene for MikeW. MikeW: local_check.sh, godot shim in repo, .gitignore for crash reports and temp dll, test runner with timings.
Note: the review calls Radar's role "Sal_Crafts"; Dave should confirm the rename so docs use one name.
