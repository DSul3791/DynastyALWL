# TOMORROW EFFICIENCY PLAN (24 Oct; from tech/AUDITS/AUDIT_2026-10-23.md and the new tech/TEST_RECIPE.md). EVERY THREAD READS THIS FIRST AT 8 AM.
| # | Change | Owner | Measurable target (checked 20:00 ADT) |
|---|--------|-------|----------------------------------------|
| 1 | Merge-check batch: Mike runs ONE batch per hour from a fixed list file (MERGE_CHECK pattern), PASS/FAIL per branch line; Tyler merges passes the same hour | Tyler + MikeW | Every branch pushed before 17:00 ADT is merged or has a named FAIL line by 19:00; no branch waits more than 2 h on a batch |
| 2 | Allow rules: any command Mike gets refused gets one allow rule that day (settings_mike_all.json), Dave only restarts | Tyler | 0 Mike runs lost to refused commands after 10:00 ADT |
| 3 | Start-up smoke test: client must start headless for 10 s with zero errors before any pull into Dave's folder (local_check parse + check_dupe_names + smoke) | Steve (script), Mike (runs) | 0 builds reach Dave that do not start |
| 4 | Card checklist (grep ANSWERS/DECISIONS, picture pushed under 1 MB, team-doable steps never on Dave's page) | Tyler; every thread uses qa_post | 0 cards answered "already answered" / "no picture" / "you do the test" |
| 5 | Test recipe: one labelled row, one picture; groupable REQUEST template; T-GROUND replaces dig/drop/pile; every step measurable | All threads request; Steve adds missing numbers to the state line | Mike renders at most 1 batch/hour; picture count per kind = 1; 0 pass-less tests |
| 6 | Ready queues in JOBS.md top block; threads take next line without asking; standing GO written in each queue (Sonny bake go, merge order) | Tyler refills 8 AM and at each merge | 0 threads idle >10 min; 0 "waiting for Tyler's go" lines on Dave's page |
| 7 | Relay hygiene: one message per fact, thread posts when the hourly limit is near, files in the repo (docs/mirror/tech) not only /mnt | Tyler + coordinator | <= 12 messages/hour from Tyler to coordinator |

How it is checked: at 20:00 ADT Tyler writes tech/AUDITS/AUDIT_2026-10-24.md with the 7 targets as pass/fail and tomorrow-vs-today numbers.
8 AM start text for every thread (coordinator pastes): "Read tech/DAILY_HANDOFF.md TOMORROW EFFICIENCY PLAN, tech/TEST_RECIPE.md, then the top block of tech/JOBS.md for your queue; take the next line without asking."

# Daily handoff and thread reset (Dave 23 Oct 17:07: "set up a proper handoff and resetting of all threads ... every day at 8 AM"; owner Guru)
Rule: once a day each thread writes a handoff, pushes, and is then reset (a fresh session that starts from the files, not from chat). Skipping it makes threads slow and confused, as today.

## What each thread does (in this order, about 15 minutes)
1. Push everything: branch pushed with a clear last commit message; report the branch name to the coordinator ("branch X, ready/not ready, label RUNTIME/RESTART/BAKE").
2. Write `handoff/<Name>_<NNN>_HANDOFF.md` (NNN = this iteration number): what you finished today, what is half done (file, function, why), the next 3 jobs in order, traps and lessons, what you are waiting on and from whom, how to run your checks. Five to eight short paragraphs; no chat history.
3. Update your `tech/OPEN_<Name>.md` list (BP-T30): every item with a status; nothing lives only in chat.
4. Put anything from Dave that is not yet in DECISIONS.md into your handoff and tell Guru (Guru sweeps ANSWERS into DECISIONS).
5. Save lasting facts to project memory (one file per subject; no secrets).
6. Post to the coordinator one line: "Handoff in: handoff/<Name>_<NNN>_HANDOFF.md, branch <X>".

## What the Guru does
1. Merge every ready branch (merge_check clear, NEVER commit when it fails or `git status` shows UU), number the build, BUILD_LOG line, DECISIONS sweep.
2. Rewrite the NOW block at the top of HANDOFF.md (head build, rules, latest answers, open work, held branches) and add a day line to tech/DAY_LOG.md. Archive the old block in docs/archive if it grew.
3. Mirror docs (docs/mirror/tech/) and tell the coordinator "head FINAL, all handoffs in" so threads can be reset.

## What a reset means
The coordinator ends the old thread and starts a new one with the same role. The new iteration's first job: read HANDOFF.md NOW block, BIG_PICTURE.md, its own handoff file (highest NNN), its OPEN_ file, DECISIONS.md tail. No other history is carried over. Do NOT reset a thread that has an unpushed branch or is mid-bake (MikeW).

## Thread name iteration scheme
`<Name>_<NNN>` with NNN counting from 001 for the first thread of that role: Steve_ProblemSolver_003 follows Steve_ProblemSolver_002; handoff file handoff/Steve_ProblemSolver_002_HANDOFF.md is written BY iteration 002 FOR iteration 003. Existing files use this (Tyler_001, Tyler_002). Today's iterations are treated as the next number after the latest file in handoff/ for that name (names without a file are 001 -> write _001).

## When
Every day at 8:00 AM Atlantic (ADT = 11:00 UTC until 1 Nov 2026, then AST = 12:00 UTC; cron `0 11 * * *` now, change to `0 12 * * *` on 1 Nov). The 8 AM run: the coordinator wakes every thread to run the steps above, Guru merges and writes the NOW block, then the coordinator resets the threads and Dave's morning starts from a clean head. The 9 pm routine (backup) stays. Dave says "goodnight" = same steps, plus backup.
