# RULE 1 (Dave 2026-10-22, permanent): QUESTIONS FOR DAVE
(Dave 17:14, BP-T33: threads ask the Guru, who posts to the page; threads do NOT write to QUESTIONS.md themselves.) Every question with pickable answers (or a short typed answer) for Dave goes ONLY in `questions/QUESTIONS.md` on branch claude/generator-v2 (format in `questions/README.md`), then the thread reports "Question added: <title>" to the coordinator. Never ask Dave in chat or any other file or card. Answers come back in `questions/ANSWERS.md`. No look-at or test tasks in that file; those stay in chat.

# How threads work with Technical direction

Threads cannot message each other, so everything goes through the coordinator (`message_thread`). Dave decided 2026-10-20: **big changes only** need approval.

## Needs approval (send a short request: what, why, which files, what it costs at the Low tier)
- Changes to how server, client or admin code is split, or the network protocol.
- Save formats, the block store, `TERRAIN_VERSION` bumps, anything that invalidates saved ground or edits.
- A change that two threads both touch (shared files, shared constants, the flora or water interfaces).
- New dependencies, new native code, new engine settings (LOD counts, block size, streaming mode).
- Anything that adds per-frame cost that is not behind the quality setting.

## Does not need approval
Bug fixes and tuning inside your own area (water thread: water and terrain generation; ground thread: loading; sound; art looks within ART_DIRECTION.md). Still: run the performance routine, say what it does at Low, and take a build number.

## Build numbers
Dave's rule (2026-10-20): numbers are handed out one at a time, in order, when a job starts. Send Technical direction a cross-session message (session id cse_0111SmjyMaTAj3PtyQqHboYJ, or through the coordinator) saying thread and job; the reply is the next number. Use it for that job's push. Unused numbers stay unused. See BUILD_LOG.md.

## Reply format from Technical direction
Approved / Approved with changes / Rejected, plus one line why and any condition. Decisions are written to `tech/DECISIONS.md` so a replaced session can read them.

## Which code is running (build 89)
Build numbers are in blocks per thread, so they are not in time order. The HUD now shows `build N (abcdef1)`: the short id of the commit the checkout is on. Newer code = the id GitHub shows for the latest commit on `claude/generator-v2`; if the HUD id differs, pull. Every push message should name its build number and the thread so the commit list reads the same way.

If upstream already shows a higher BUILD when you rebase, keep the number Technical direction gave you; the HUD also shows the commit id, so newest code is identified by that.

Never take a number from the 'Next number' line in BUILD_LOG.md yourself: only a reply from Technical direction counts (two threads once took the same number that way).

## Before every push (added 2026-10-20 after conflict markers reached generator-v2 for 5 minutes, d7844db, fixed in bce297f)
1. `git pull --rebase origin claude/generator-v2` first, resolve conflicts fully.
2. `git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- '*.gd' '*.json' '*.md' '*.tscn'` must print nothing.
3. Run the headless Godot parse/flight check for the files you touched; no script errors.
4. Then push. Never push a merge you did not re-check.

## Inputs live in CONTROLS.md (added 2026-10-20, Dave: record all inputs in our documents)
Any change that adds or changes a key, mouse button, hold versus tap, or context prompt updates `CONTROLS.md` in the same push. Before pushing run `python3 tools/check_controls.py`; it fails when a KEY_* or MOUSE_BUTTON_* used in code is missing from the first column of the CONTROLS.md tables (add a new constant to its LABELS table if it reports one it does not know). Add this to the pre-push list above as step 3b. Items and Ground own most keys. Stances (sit, lie, crouch) are decided but not built; X is taken by the admin dig key.

## Best-practice check with Tyler (Dave, 2026-10-21 13:32, standing rule)
Before starting a NEW KIND of job, a thread reads /mnt/project-files/tyler/BEST_PRACTICES.md and FINDINGS.md; if the topic is not covered, it messages Tyler (Problem Solver) for a few lines of best practice and keeps working on something else meanwhile. Skip when the thread already has practice on that topic. Nobody idles waiting: Tyler answers briefly.

## Never wait for Dave (standing rule 2026-10-21 20:52)
Blocked on Dave? Park the job in JOBS.md under "Set aside, waiting on Dave" with the exact question, take the next independent job, and return when answered. Never cross another thread's code or files.

## GDScript conventions: zero warnings (Dave, 2026-10-21 23:39; screenshot: 233 warnings in the Debugger)
Logs must hold only real problems. Rules for ALL threads: (1) new and edited code adds zero GDScript warnings; (2) each thread cleans its own files in ONE dedicated build, no behaviour change (state "warning cleanup only" in the commit); (3) typical fixes: integer division -> use floori()/int() or float division on purpose; local or parameter shadowing a class member or Node3D property (basis, state, zone_group): rename the local; unused locals/params: prefix with underscore or delete; unused signals/vars: delete; implicit narrowing: add a cast; (4) never add @warning_ignore except with a one-line reason; (5) keep static typing (`var x: Type`, return types) as in the surrounding code; (6) a push touching .gd files runs the headless load AND the warning-count check (Willy's tool) and the count must not rise. Note from Steve: in this cloud engine a plain headless load or --editor --quit prints NO warnings (checked 2026-10-21), so Willy's check needs another route (e.g. a GDScript parse via GDScript.new() with reload and the analyzer, or a static scan for the known patterns); until it exists, review warnings in the Godot editor Debugger on your own machine (Dave's).

## Who owns what (Dave 2026-10-22 14:18, replaces the older table; Steve and Willy are RETIRED)
| Thread | Owns |
|---|---|
| Technical Director + Guru (Tyler_Guru_SenDev; took over Steve's duties) | tech/ docs (JOBS, DECISIONS, PROCESS, BUILD_LOG, TEST_QUEUE, BEST_PRACTICES), architecture approvals, build numbers, question page and grouped test card, daily doc check, HANDOFF.md |
| Sonny (World; took over Willy) | ground and how it is shaped (loading, generation, worldgen tests, tunnels, bracing, collapse) AND water sim/generation, ice, swim |
| Sal_Crafts (was Radar) | items, crafting, NPC/animal design, trade, buildings, server items |
| Steve_ProblemSolver (Systems; was Tyler_002) | everything not assigned: server stalls, networking, crash hunt/telemetry, HUD/UI plumbing, settings, performance, movement, threading, saves, scale plan |
| Kathleen_ArtisticDirector | art, animation, sounds/voice, client look files |
| MikeW_LocalAgent | on demand, on Dave's PC: warning count, headless tests, GPU/editor/visual checks, long runs |
| Coordinator | routing, moderator (30 min), Dave's reports, memory |
Anything unassigned goes to Steve_ProblemSolver. Where an older (Tyler in older lines = Steve_ProblemSolver; the retired Steve = Technical Director) line in this file or JOBS.md says Steve, read Technical Director; where it says Willy, read Sonny. Workers run ON DEMAND from the queue: start when a job is queued, park with a handoff when the queue is empty. Everyone follows: branch claude/generator-v2 only, zero warnings, build number logged before push.

## Build number rule (Steve_002, 2026-10-22, replaces asking Steve)
Before a push: `git fetch`, read `const BUILD` on origin/claude/generator-v2 and the last line of BUILD_LOG.md; your number is the higher of the two plus 1. Append your BUILD_LOG.md line and set BUILD in the SAME commit you push, then push at once. If the push is rejected, fetch, rebase and recompute the number (take the new maximum plus 1) before pushing again. Never reuse a number; a duplicate is renumbered by Steve (the later push becomes the next free one).

## Dev stop status (Steve_002, 2026-10-22 04:10)
DEV STOP LIFTED by Dave at 03:51. Normal work resumes. If a stop is called again it is written here and at the top of JOBS.md.

## RULE 2 (Dave 2026-10-22): no individual test requests; no waiting
1. No thread asks Dave for a test, a look or a screenshot in chat or in posts. A thread that needs one adds a line to tech/TEST_QUEUE.md (build number, what to look at, x y z, what to check).
2. The Technical Director owns the grouped test card: every few builds, or when 3 or more items are queued, ONE question in questions/QUESTIONS.md (README format): "Test the latest build N: look at x y z, check this, check that, tell us what you think". Options: A "I saw this, responded in text, you can delete this"; B "We already answered this"; C "Tested, all fine"; D "Found a problem (I will describe it)". Answered or stale items are removed from the queue; stale requests are withdrawn.
3. Stuck threads do not wait. A thread waiting on Dave posts its question in the question file (or queues the test), and moves on to another job in its queue, recorded in JOBS.md "Moves awaiting Steve" or its own queue.
4. The moderator (coordinator) checks every 30 minutes (Dave 2026-10-22, was 10) that threads with open jobs are moving, listing only threads changed since the last check. The Technical Director keeps JOBS.md current with each thread's next job so it can be seen at a glance.

## RULE 3 (Dave 2026-10-22 13:34): builds and tests that can run on Dave's PC run there
The "Local build and test" thread runs on Dave's PC (Godot, gh, Git bash). Anything that needs a real GPU, the editor, the full game, long headless runs, bake-like scratch jobs or visual checks is requested from it with exact commands and a short answer expected. The cloud is only for work that costs fewer tokens (reading, writing, small headless loads, doc work). Threads ask for local runs through the coordinator, not Dave.

## RULE 4 (Dave 2026-10-22 14:08, permanent): BEST PRACTICES FIRST
tech/BEST_PRACTICES.md is the guideline. The Guru (Tyler_Guru_SenDev) checks and updates it at least daily and logs the check at its bottom. Every thread reads it once a day AFTER the Guru's latest check and says "BP read <date>". Before starting anything NEW, a thread finds its entry and follows it. No entry: ask the Guru (through the coordinator), park that job in JOBS.md under "Waiting on Guru", take another job; the Guru posts an entry within one moderator cycle (about 10 minutes). Only after the entry is posted may the job start. Full text: POLICY section of BEST_PRACTICES.md.

## HOW WE WORK summary (2026-10-22)
One-page map of the team, BP-T22 to T25 (cross-talk, priority, ideas, design reading), the approved infrastructure changes and the restart plan: `tech/HOW_WE_WORK.md`. Keep it in step with this file.
