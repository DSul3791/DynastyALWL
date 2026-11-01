# Scope: Dino: Guides and Walkthrough (formerly Guide, first-hour playthrough), 1 Nov 2026

> **CLARIFIED (Dave, 1 Nov 2026): your job is to BUILD the playthrough and walkthrough guides and TEST them.** You report your findings to the moderator, who hands each problem to whoever should fix it. You do not fix, and you do not route problems to owners yourself.

Read `HANDOFF_DINO.md` in the same folder first for how to run things. This file says what the job is.

## 1. The job, and where it starts and stops
**In plain words:** I pretend to be a brand-new player on the daily branch (`origin/DailyDev_20261029`) and try to get through the first hour: spawn, drink, gather, craft, axe, fell a tree, campfire, cook, lean-to, bed, sleep, bench, spear, rabbit. Where something is missing, broken, silent, confusing or ugly, I write it down with evidence and tell the owner. I keep a checklist for Dave and a status table that says, step by step, what really works.

**Starts:** at the daily branch head merged into my branch, and at the tutorial/checklist text.
**Clarified by Dave (1 Nov): I BUILD the playthrough and walkthrough guides and TEST them. I report findings only to the moderator (what, evidence path, suggested owner, severity); the moderator hands each problem to its owner. I no longer message owners directly.**

**Stops:** I read, play, probe, photograph and report. I do **not** change game code or data (one small `shot_runner.gd` change was allowed by Kathleen), I do not fix bugs I find (the owner does), I never merge to main, and I do not decide what the game should be (Dave and the moderator do). I do not decide whether a picture is good enough: Dave answers Yes/No on QA cards.

## 2. What I have done (grouped)
- **Probes against the real server code** (`art/playthrough/probe_*.gd`): fire/lean-to/bed placement (probe_place), lean-to roof + bed + lie + sleep + spawn point + respawn (probe_shelter, found the bed-refused-inside-lean-to bug, fixed by Tyler), campfire cooking (probe_cook), log use, spawn survey. Commits: 562b9e21, b57c9b14, b4be0897, 27d12f8d, 26451218, 835e583e.
- **Playthrough docs:** `PLAYTHROUGH_FINDINGS.md` (parts 11 and 12), `PLAYTHROUGH_STEP_STATUS.md` (22 steps; updated 1 Nov), `PLAYTHROUGH_STATUS.md` (24 fixed, 3 broken), `TUTORIAL_FIRST_30_MIN.md` (numbers matched to data), audits. Commits: 835e583e, 51176ef3, 6cb59bf3, 06882634.
- **Dave's play-test checklist:** one page `MORNING_PLAYTEST_CHECKLIST.md` (long one kept as `_FULL`). Commit b2bebde9.
- **Smoke test:** ran the full smoke (windowed walk, creator, 16 client self-tests), found the self-test gaps, wrote `SMOKE_TEST.md` and `smoke/notes.md`; reran sleep and snare on fresh servers (leftovers, not real). Commits: 6cb59bf3, 3b2eb13c.
- **Pictures on QA cards** (qa branch `C:/GodotProjects/DynastyALWL_qa`, last aabe3f2c; earlier f9bbdd1f): spawn, lean-to and bed, creator, lit campfire (no flames: bad), felled trunk (dark smooth: bad).
- **Handoff and task docs:** `docs/handoff/HANDOFF_DINO.md`, `GUIDE_TASKS.md`, this file. Commit 06882634 and the one for this file.

## 3. What I plan to do (full list, in order)
1. Finish the windowed walk of checklist steps 1-14 (rig pictures: creator, lean-to and bed views, spawn with Tab bars) and update the status table. Queued 1 Nov.
2. Re-probe silent placement refusals (beyond 6 m, wet beach, fire gap, per-chunk cap) and report which still give no message.
3. Walk steps 3, 8, 9, 14, 20 (drink, hotbar, fell, feed fire, bench) with rig pictures, one per step.
4. List every checklist step with no automated check; hand Tyler the exact test flags needed (sleep at low energy, bench, drink, pot).
5. Get the lit-fire and felled-trunk looks fixed: send findings to Kathleen/Sonny, re-photograph, put a new QA card.
6. Ask Sal for a tutorial step for the campfire pot and clay hearth; check tutorial and checklist numbers against data after every daily.
7. Ask Tyler to extend the playability bot through bench, bed, cook; the 60-stick budget is under the ~62 needed.
8. Check the 56 kits vs 19 looks (kits that look alike) and file the grey ones.
9. After each daily merge: run `run_status.sh`, probes, smoke; refresh the status and checklist; short delta note to the moderator.

## 4. Priorities (1 = most important)
1. **A new player can reach a safe night (fire, lean-to, bed, sleep) with no dead ends.** That is the game's first impression.
2. **Silent failures:** a refused action with no message looks like a bug to a player.
3. **Looks that are visibly wrong** (lit fire, felled trunk, creator back view): they decide whether Dave trusts the build.
4. **Test coverage of the first hour:** so regressions are caught without me.
5. **Docs that match the data:** a wrong number in the tutorial costs Dave play-test time.

## 5. Dependencies
- **I depend on:** the moderator (permission to run, the "COMPUTER BACK" signal, merging the daily); Tyler (placement rules, tests, bot, join freeze, chest test); Sal (item/recipe data, tutorial text for the pot/hearth); Kathleen (looks, `shot_runner.gd`, rig); Sonny (creator preview, water, sound, character); the flora session (flora_view error, nettle/plant looks); Dave (answers on QA cards, play-test notes).
- **Who depends on me:** Dave (the one-page checklist and the status table); the moderator (the honest step-by-step state and pass/fail reports); owners (they get bug reports with evidence and the probe that shows it).

## 6. How to tell the job is finished
- Every one of the 22 steps in `PLAYTHROUGH_STEP_STATUS.md` is WORKS and has been walked in a windowed client by me or Dave, with no OPEN rows.
- No silent refusal remains in the placement probe.
- Lit fire and felled trunk QA cards are answered Yes.
- Each of the 22 steps has an automated check or a rig picture that reruns on demand.
- Dave plays the first hour from the checklist without writing "stuck at step N".
