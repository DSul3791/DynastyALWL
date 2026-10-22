# Idea inbox: verdict ledger for Dave's blurts (NOT a second ideas file). Process: BP-T24 in BEST_PRACTICES.md.

The permanent home for design ideas is `DESIGN_IDEAS.md` (repo root). This inbox only tracks who owns a fresh blurt and the NOW/LATER verdict. Once decided, the owner folds a design idea into DESIGN_IDEAS.md with its status tag and this row becomes a one-line pointer ("-> DESIGN_IDEAS.md section X"); non-design ideas become a JOBS.md job. Rows older than 14 days that are only pointers are deleted.

How it works: Dave blurts an idea. The coordinator logs it here the same cycle, in Dave's own words, and routes it to the owner thread (PROCESS.md "Who owns what"). The owner replies with a verdict: NOW (becomes a job in JOBS.md with a P-level per BP-T23) or LATER (one-line reason, and what would make it NOW). Design ideas also get folded into DESIGN_IDEAS.md (or DESIGN_REJECTED.md if Dave rejects). The Technical Director reviews this log in the daily check: nothing without an owner, no idea without a verdict for more than 24 hours, LATER items re-read weekly.

Status values: NEW (logged, owner not answered), NOW, LATER, DONE, REJECTED.

| # | Date | Idea (Dave's words) | Owner thread | Status | Verdict / reason | Job / P-level |
|---|---|---|---|---|---|---|
| 1 | 2026-10-22 | "eventually I want to be able to zip our entire project nightly after I say goodnight each night and to save it as DynastyALWL_ProjectBackup_TheDateTime.zip in my large drive at E:\Software\godotDev\DynastyALWL_ProjectBackups" | MikeW_LocalAgent (his PC), Guru reviews | NOW (P2, small job; closes the backup gap C93) | Plan in BEST_PRACTICES BP-C110. Retention: every nightly 30 days, then one per week (oldest of each ISO week) kept forever in weekly\ (Dave 15:32). Needs MikeW feasibility check (size, E: drive, game-closed check). | job in JOBS.md "MikeW: nightly backup" |
