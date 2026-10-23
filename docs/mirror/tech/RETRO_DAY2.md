# Retrospective: did we get more done, and what slows us down? (Guru, 2026-10-23 05:20 UTC; Dave asked 04:48)
Dave's observation: about the same share (about 20%) of the weekly limit used today as yesterday. Honest scope: I can count what is in git and the docs. I CANNOT measure tokens per thread, so "more per token" is a judgment from output, not a measurement.
## 1. Numbers (from git history of claude/generator-v2; days in Atlantic time, 03:00 UTC to 03:00 UTC)
| | Day 1 (21 Oct) | Day 2 (22 Oct) | Day 3 so far (23 Oct 03:00-04:55 UTC) |
| all commits | 379 | 829 | 126 |
| of which Dave's QA page commits (answers) | 28 (about 14 answers) | 437 (about 218 answers) | 50 (about 25) |
| other commits (code, docs, merges) | 351 | 392 | 76 |
| merge commits (branches joined) | 4 | 31 | 15 |
| commits that mention fix/conflict/warning/duplicate | 24 | 25 | 4 |
| build number | not recorded in code yet | reached 695 (about 100 builds merged, 592 to 695) | 695 to 701 in under 2 h |
Reading: (a) Dave's decisions per day went up about 15x (the QA page and cards). (b) Integration went up about 8x (31 merges vs 4; about 100 numbered builds). (c) Raw code and doc commits are only about 12 percent higher. (d) The rework share (fix-like commits per commit) about halved, but tonight showed new kinds of rework (below). So: we got MORE DECIDED and MORE INTEGRATED for about the same budget, not obviously more raw code. Caveat: commit counts do not measure size or quality.
## 2. Bottlenecks I can evidence
1. Merges collide: tonight alone, duplicate item number 234 (wooden_block and rock_pile), two branches wanting action id 39/40, conflicts in game_menu.gd, server_items.gd, terrain_net.gd, test_tunnel_watch.gd; earlier (build 687) I committed conflict markers; warning-ignore line misplaced by a merge (234 warnings, fixed as 699); next_number not bumped (fixed as 701). Cause: every thread branches from a different head and picks "the next number" itself.
2. Late discovery: nobody can run Godot in the cloud, so local_check, the warning count and headless loads wait for MikeW on Dave's PC; failures (699, 701) came back after the merge, one round trip each.
3. Dave as the only tester: 12 test cards at night, most checkable by the team. Now BP-T45/T46 (showroom, team tests first).
4. Relay overhead: threads cannot message each other, so the coordinator relays and I relay back; long relays repeat Dave's full words to several parties, and I hit an hourly message limit earlier.
5. Card churn: card format wrong at first (Dave corrected 3 times), cards removed or reposted while he was answering, duplicate answer entries (I made one tonight), page code stale in his open tab (v7 vs v9).
6. Waiting: permission prompts in thread windows that Dave cannot see; threads waiting for a card answer. BP-T41/T44 address this.
7. Reading load: 83 docs in tech/, 46 best-practice rules, a long HANDOFF.md every thread reads at start; many rules are for me, not for them.
8. Stale chains: a 30-minute moderator check chain and repeated status checklists produce messages with nothing new.
9. Crash logs and telemetry committed to the repo several times (tracked files now ignored).
## 3. Five best fixes, ranked (with why)
1. PRE-MERGE GUARD SCRIPT AND CI (tools/merge_check.sh, then GitHub Actions headless Godot): checks conflict markers, duplicate item numbers and action ids, next_number, crash logs, JSON validity, and the warning baseline. Why: it would have caught every merge problem tonight BEFORE the merge, and removes the MikeW round trip. CI (C85) already exists in the plan, "gated"; this is the reason to turn it on. Needs a Godot headless build in CI (not verified: the 30-minute custom build may need caching).
2. RESERVED NUMBER RANGES: item numbers, action ids and protocol bumps allocated by a one-line claim file (tech/ID_CLAIMS.md) or per-thread ranges (Sal 300-399, Steve 400-499...). Why: duplicates 234 and 39/40 are pure collisions; a claim takes seconds.
3. TEAM TESTS FIRST (BP-T46) plus the showroom and the look rig on MikeW's PC (BP-T45). Why: moves the tester load off Dave and finds failures before cards.
4. INBOX FILES AND THREAD-TO-THREAD NOTES: each thread has tech/INBOX_<name>.md that the coordinator and I write DELTAS to (not full quotes), read at the start of every turn. Why: threads cannot message each other; one short file replaces several long relays. Not verified: whether threads reliably read it each turn.
5. SLIM THE READING: HANDOFF.md top block of at most 40 lines (done by me tonight: a first-jobs block); archive finished sections; one-line BP index per thread (only rules that apply to its job). Why: every thread reads this at every start.
## Token-heavy habits we could trim without losing quality
- Relaying Dave's full message to every thread: send only what changes for that thread (a delta).
- Status checklists after every tiny step and the 30-minute moderator chain when nothing changed: post only on result, blocker or question (BP already says two replies max).
- Rewriting the same card or answer entry: write once, correct by new card only if wrong.
- Full BUILD_LOG lines of several sentences: keep to merged/not run/needs check.
- Long reports duplicated in chat and a doc: doc plus one line in chat.
## Not measured
Tokens per thread or per task; how many of Dave's 218 answers changed real code; whether the extra merges are all useful or partly churn.
