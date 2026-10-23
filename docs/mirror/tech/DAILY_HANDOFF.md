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
