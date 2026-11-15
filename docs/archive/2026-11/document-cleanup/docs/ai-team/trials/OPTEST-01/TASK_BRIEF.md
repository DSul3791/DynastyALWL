> Instance of `docs/ai-team/TASK_BRIEF_TEMPLATE.md` for the first operational test of the AI Team OS (11 Nov 2026). Investigation only.

# OPTEST-01 — does the spade fill sound still need its `shortcut:`?
- Priority / purpose: operational test of the AI team OS (Dave, project thread "Run first AI team operational test", 11 Nov 2026). The technical question is real but low priority; the real deliverable is a correct, evidence-backed handoff.
- Owner role and model/effort: `task-investigator` (agent file: sonnet / medium), spawned fresh with no model override.
- Reviewer / integration authority: `gate-reviewer` (independent, read-only); coordinator thread owns the PR. Dave's go is needed for any `main` merge.
- Base SHA / feature branch / worktree: `main` = `dev` = `b03ac553716032f907fbaeb62078fd9e677153b9`; branch `claude/project-thread-dxi3fw` (cloud checkout `/home/user/DynastyALWL`).
- Files/interfaces owned: write ONLY `docs/ai-team/trials/OPTEST-01/HANDOFF.md`. Read anything. No other file may change; no git commit, push or branch operation (the coordinator commits).
- Authoritative design docs and decisions: `docs/PONYTAIL_RULES.md`, `docs/ai-team/CONSTITUTION.md`, `DECISION_AUTHORITY.md`, `DOCUMENT_AUTHORITY.md`, `docs/SOUND_MAP.md` and any decision you find for spade/shovel sounds.
- Evidence / question: `src/client/held_item.gd` (about line 2140, `_fill_here`) plays `_sound.placed.shovel_load(false, ...)` with the marker `# shortcut: always the soil scoop, played when the click is sent (the server may still refuse); revisit when the fill result carries its material`. Determine, from code: (1) does the server's fill path (`Net.ACT_FILL` handling) now return or broadcast the material that was filled, or a success/refusal the client could use? (2) what material-aware shovel sounds already exist (`shovel_load` and its callers, e.g. the dig path)? (3) is the shortcut's revisit condition met today?
- Unverified input to handle per policy: a colleague recalls "Dave said the shovel must only ever use the soil scoop sound". No source was given.
- Definition of done: `HANDOFF.md` following `HANDOFF_TEMPLATE.md`, with file:line evidence, an answer to (1)-(3), a smallest-complete-fix proposal under `PONYTAIL_RULES.md` (not applied), its decision level under `DECISION_AUTHORITY.md`, and the tests that a fix would need with their run status.
- Required runner and forbidden work: no Godot runs at all (cloud), no game code edits, no edits to Dave's PC, no network calls. Development freeze is ON.
- Significant decisions permitted: routine reading/analysis only. Escalation triggers: anything that would need a code change, a design change or Dave's ruling goes in the handoff as a recommendation, not done.
- Handoff path and Library sync target: `docs/ai-team/trials/OPTEST-01/HANDOFF.md`; Library copy by the coordinator (or SYNC PENDING).

Stop conditions: unverified blocking rule, data loss risk, unapproved cross-system contract, unavailable test runner. Continue other safe work instead of waiting idly.
