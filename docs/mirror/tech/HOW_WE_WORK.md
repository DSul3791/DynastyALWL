# How we work (one-page summary, 2026-10-22; Technical Director). Details live in the linked files; this page only points and summarizes. Update it when any of them changes.

## Team (Dave approved 2026-10-22; Steve and Willy retired)
| Role | Thread | Owns |
|---|---|---|
| Coordinator | project chat | routing, moderator every 30 min, Dave's reports, logs Dave's ideas, memory |
| Technical Director + Guru | Tyler_Guru_SenDev | tech/ docs, approvals, build numbers, question page, test card, BEST_PRACTICES daily check, HANDOFF.md, review of risky pushes. Docs only |
| World | Sonny | ground, loading, tunnels, bracing, collapse, water, ice, swim |
| Items and World objects | Sal_Crafts (was Radar) | items, crafting, NPCs, animals, buildings, trade |
| Systems | Steve_ProblemSolver (was Tyler_002) | server, network, HUD, movement, performance, saves, crash hunt, anything unassigned |
| Art and Sound | Kathleen_ArtisticDirector (was Mandy) | look, animation, audio |
| Local runner | MikeW_LocalAgent (was MichealW_Local_agent) | on Dave's PC: warnings, headless tests, GPU/editor checks, long runs |
Workers run ON DEMAND from the queue (BP-T20). Ownership table: PROCESS.md "Who owns what".

## Rules (all in BEST_PRACTICES.md, 80 entries; policy at its top)
- Read it daily after the Guru's check; before anything NEW find its entry, none = ask the Technical Director and take another job (PROCESS.md RULE 4).
- Cross-talk (BP-T22, Dave): only for dependencies/second owner/review; one message, one question; answer in 1 to 3 lines within about 30 min; 2 open requests per thread, 3 messages per topic then the Technical Director decides; no A-B-C chains; never edit another thread's code.
- Priority (BP-T23, Dave): P0 Dave/data loss/crash/broken branch (now); P1 blocks a running job (about 30 min); P2 reviews, test card (same day); P3 daily check, docs. Request type decides, not thread; aging after 24 h; same scheme for every thread, queue per thread.
- Ideas (BP-T24, Dave): Dave blurts, coordinator logs in tech/IDEAS.md (verdict ledger), owner says NOW (job with P-level) or LATER (reason) within one cycle, design ideas then go into DESIGN_IDEAS.md (the one permanent file). DESIGN_IDEAS_BY_CHATGPT.md stays the temporary ChatGPT inbox.
- Design reading (BP-T25, Dave): BIG_PICTURE.md (all, repo root) + tech/DESIGN_ROLE_MAP.md (your sections) + tech/DESIGN_CHANGELOG.md (lines since your last read).
- Questions for Dave: threads ask Tyler, Tyler posts them (pickable answers, questions/QUESTIONS.md; section 'How threads ask questions'). Test asks: tech/TEST_QUEUE.md, grouped test card (RULE 2). Builds/tests that fit run on Dave's PC via MikeW (RULE 3). Never wait for Dave: park and take the next job.
- Reports to Dave: SUCCINCT; "Test done: X pass, Y fail" with one line per failure; "Finished:" for big jobs; end with "Still waiting on:".

- Lessons and debrief (BP-T26, Dave approved): running `tech/LESSONS.md`; at the end the debrief checklist and starter kit in `tech/PROJECT_DEBRIEF_KIT.md`.

## How threads ask questions (Dave 17:14; BP-T33)
1. A thread asks Tyler_Guru (through the coordinator), one question per message, with its own recommended answer and what it will do meanwhile.
2. Tyler decides: can it be answered from best practices, DECISIONS.md, ANSWERS.md or the design docs? Then Tyler answers the thread himself and records it in DECISIONS.md.
3. If it truly needs Dave, Tyler posts it on Dave's page (questions/QUESTIONS.md) as multiple choice with Tyler's recommendation marked, then reports "Question added: <title>". A test ask becomes a "Things to check" card the same way.
4. Threads do NOT write to QUESTIONS.md themselves. They keep working on the recommended option, or park the job and move on (the "stuck thread moves on" rule stays).
5. Dave answers when he can. Tyler reviews ANSWERS.md at each 30-minute check and tells the asking thread the answer, always checking it against best practices, and records any new rule.
6. Tyler lists which threads are waiting on which question in tech/QUESTION_OWED.md.

How the QA page and its files work (reusable): tech/QA_SYSTEM.md.

## Approved infrastructure changes (Dave, "approve all"; plan in IMPLEMENTATION_PLAN.md)
Daily docs mirror (T18); per-thread branches merged by the Technical Director (C107); CI on push (C85, gated); dated save backups (C93); Git LFS for tiles (C108, gated, forward-only). Gated = Dave's go plus a MikeW run first.

## Restart plan ("go" from Dave; dev is paused now)
1. Guru mirrors docs and posts "BP ready". 2. Coordinator re-arms the 30 minute moderator, assigns thread branches, wakes only threads with queued jobs. 3. MikeW runs the warning baseline and CI-script/LFS/backup prerequisites. 4. Technical Director adds CI and .gitattributes after MikeW passes. 5. Workers resume in Dave's order (cc-first-job): Steve_ProblemSolver (crashes, saves, version check, build const), then Sonny (water/ground), Sal_Crafts (items, building), Kathleen_ArtisticDirector (art, sound), each reading BP entries and design changelog lines since 2026-10-22.

## Where each piece lives
BEST_PRACTICES.md, PROCESS.md, DECISIONS.md, JOBS.md, BUILD_LOG.md, TEST_QUEUE.md, IDEAS.md, TEAM_PROPOSAL.md (team + efficiency review), IMPLEMENTATION_PLAN.md, DESIGN_ROLE_MAP.md, DESIGN_CHANGELOG.md, LESSONS.md, PROJECT_DEBRIEF_KIT.md (all in `/mnt/project-files/tech/`); HANDOFF.md, BIG_PICTURE.md, DESIGN_IDEAS.md, questions/ (repo, branch claude/generator-v2).

## Goodnight checklist (Dave 2026-10-23; BP-T38 to T41)
1. Coordinator asks every thread to finish, push and report "finished" plus tomorrow's first job. Nudges (BP-T38) go both ways between coordinator and Guru.
2. Guru merges everything ready, renumbers, updates BUILD_LOG, DECISIONS, HANDOFF, TEST_CARDS_TONIGHT, and tells the coordinator the head is FINAL.
3. NOBODY is blocked or waiting (BP-T41): every question a thread needs is already a card on Dave's page; every thread has a next job that does not depend on an unanswered card.
4. Dave pulls, closes the game fully, starts it and confirms it starts and plays. Then MikeW runs the backup (nightly_backup.py).
5. After the backup the Guru posts the night's test and picture cards (BP-T40; each with simple instructions and a Notes box). Dave plays and answers.
6. Next morning: answer sweep (ANSWERS.md into DECISIONS.md, relay to threads), then the first 3 jobs.

## Safe place wording (BP-T42, Dave 2026-10-23)
The game is a safe place and never says anything that might divide people. No "Womens Health", "Mens Health" or similar labels on plants, tools, items, tooltips, sounds or lines. Describe the use, never who it is for. Every new piece of player-visible text is checked against this.
