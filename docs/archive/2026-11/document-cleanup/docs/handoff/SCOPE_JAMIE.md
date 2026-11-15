# Scope: Jamie: Documentation (1 Nov 2026)

> **CURRENT FLOW (fact check, 5 Nov 2026; supersedes the branch and merge lines below):** there is no daily branch: `DailyDev_20261029` was merged into `main` (PR #11, `a8c4d545`) and deleted on 1 Nov, so "the daily" below means `main`. Each agent cuts a new branch from `origin/main` each day and opens one pull request per job into `main`; agents never merge themselves. Tyler merges when CI is green and `tools/run_tests.sh` passes on the merged result. "Never merge to main" below means "never merge it yourself", not "never open a PR". Commit heads, test counts and "in the daily" claims below are as of the date in the title; `git log origin/main` and CI are the truth now. Priorities and job owners: `/mnt/project-files/BACKLOG.md`.

## 1. The job, where it starts and stops
Keep the project's markdown accurate, concise, non-conflicting and non-duplicating, so a new agent or a new thread of Dave's finds the truth in one place. I review documents, build and maintain `docs/DOC_MAP.md` (every `.md` outside `docs/archive/`, `.claude/`, `addons/`: path, owner, purpose, last real update, verdict), fix wrong facts, merge duplicates, archive the dead, and write `docs/START_HERE.md`. I need no Godot (work is git, grep, reading); where code or data can settle a conflict I read it and say what I checked.
Stops at: game design and numbers (Dave and the moderator decide); the content of a document an owner maintains (I tell the owner first and wait for or note the answer; I fix only facts, wording, links and structure); anything unsettled (I report it to the moderator); main (never merge; I push only my branch `claude/jamie-docs-3b8c05`, the moderator merges). I archive to `docs/archive/YYYY-MM/` with `git mv`, never delete, and leave a one-line pointer where useful.

## 2. Done so far
- Read `HANDOFF_MODERATOR.md`, `SCOPE_MODERATOR.md`, the 2026-11-01 entries of `MODERATOR_QA_LOG.md` and the headers and role lines of all 18 files in `docs/handoff/`.
- First conflicts found (not yet fixed): both moderator documents still describe six agents with Flora and Guide; `HANDOFF_KATHLEEN.md` and `HANDOFF_MIKEW.md` call `godot.windows.editor.x86_64.exe` the "standard" exe and say "not the voxel build", but that file IS the voxel build (checked: it contains `VoxelTerrain` 10 times, `Godot_v4.7.2-stable_win64.exe` 0 times; `tools/godot` and `tools/godot.cmd` default to it; the standard exe is `Godot_v4.7.2-stable_win64_console.exe`); `SCOPE_SONNY.md` and `HANDOFF_SONNY.md` bodies still describe the character lane under a banner.

## 3. Plan, in order
1. `docs/DOC_MAP.md` from a script-built inventory (about 350 files), verdicts assigned by reading headers and `git log` dates.
2. Conflicts between the handoff/scope documents and the current roles (roles: Sonny terrain and water mechanics; Kathleen and Kathreen all looks incl. water and fire; Sal all items; MikeW plant and animal density, placement, behaviour; Steve sub-systems rules and code; Tyler Q&A testing and tooling; Dino playthrough guides; Jason audio; Jamie documentation; moderator coordinates). One small commit per fix, owner told first.
3. Duplicates and bloat among the top-level documents (`HANDOFF.md`, `ITEM_CODE_HANDOFF.md`, `DESIGN_IDEAS.md`, `MORNING_PLAYTEST_CHECKLIST*.md`, `PLAYTHROUGH_*.md`, `docs/*.md`): merge or archive.
4. `docs/START_HERE.md`, one page: what the game is, the roles, where the rules are, how to run tests (standard vs voxel exe) and the game, the rules (no main without Dave's go; max 3 heavy Godot jobs via `tools/godot_slot.sh`).
5. Standing instruction: when done, invent three more tasks for my job, do them, repeat. Candidates: a link checker for dead relative links; a "who owns what" table kept only in `START_HERE.md` and removed from the other documents; a stale-number sweep (test counts, hashes) in old handoffs.

## 4. Top five priorities
1. `DOC_MAP.md` (everything else depends on it).
2. Wrong facts that would make an agent do the wrong thing (wrong exe, wrong owner, wrong rule).
3. `START_HERE.md`.
4. Duplicated top-level documents (one truth per topic).
5. Archive of finished status/log documents with pointers.

## 5. Dependencies
I depend on each owner's answer before I change their document, on the moderator for conflicts I cannot settle, on Dave's role decisions in `MODERATOR_QA_LOG.md` (the source for roles). The moderator and new agents depend on me for a map and a start page that match the code.

## 6. Finished when, and rhythm
The map covers every document with a verdict, no two documents disagree on a role, an exe, a rule or a number I could check, each topic has one home, `START_HERE.md` is read by a new agent without further questions, and archived documents have pointers. The job never fully ends; I propose a light pass (documents changed in the diff) after every merge into the daily, and a full pass weekly and before each merge to main.

## 7. Skipped or not verified
Nothing run in Godot. Document contents of the hundreds of older files are judged from headers, dates and links until each is read in turn.
