# Dynasty AI Team Operating System — implementation candidate v1.0
**Prepared 11 November 2026. STATUS: STAGING / NOT ACTIVE.**

This is an installable *draft*, not a modification of `DSul3791/DynastyALWL` or Claude Cowork. The current handoff freeze stays in force until Dave explicitly ends it. Nothing in this package authorizes GitHub writes, deletion, pushing, merging, backups, testing, or an end to handoff mode.

## What to give Claude
Give the whole ZIP to a **new Claude Cowork coordinator** with the message in `cowork/COORDINATOR_BOOTSTRAP.md`. Keep a copy in the project Library. The coordinator should first inspect compatibility and propose a staged implementation plan; no code edits before Dave lifts the freeze.

## Files and consumers
- `cowork/PROJECT_INSTRUCTIONS.txt`: paste into Claude Cowork **project instructions**; a concise launcher, not a system-prompt override.
- `cowork/COORDINATOR_BOOTSTRAP.md`: paste as the first message to the coordinator.
- `CLAUDE.md`: install at repo root for **Claude Code** only after reviewing old rules.
- `.claude/agents/*.md`: reusable specialized *Claude Code* subagent profiles; not guaranteed to appear as Cowork worker windows.
- `.claude/skills/*/SKILL.md`: Claude Code skills. Cowork and cloud project threads need equivalent skills enabled on the Claude account; do not assume repository skill files automatically sync. Individual upload-ready ZIPs are under `cowork/skill_uploads/`; their contents use the Cowork `skill.md` filename while the Code versions use canonical `SKILL.md`. Verify the account UI and permissions before loading them.
- `docs/ai-team/*.md`: canonical technical policy for team operations **once activated**, referenced by short entry points. Must be indexed in both START_HERE documents and synced into project Library as appropriate.
- `tools/check_ai_team_package.py`: static checks of this package's formats and required links. **It does not establish actual Claude performance, permission safety, or Godot correctness.**

## Distinct existing START_HERE files
- Cowork Library `/mnt/project-files/START_HERE.md`: map of shared Library docs (not this package).
- Repo `docs/START_HERE.md`: code-work entry point (contains historical workflow restrictions).
Keep both. Link them; do not rename or confuse them. Tech/code/data masters reside in the repo where specified by the handoff audit. Library copies may be working copies.

## Key findings from live repository reads
On 11 November the live `docs/START_HERE.md` still said **'NO daily branch'**. `RULES.md` still described an old `DailyDev_YYYYMMDD` workflow and requires Dave's consent to all main merges. Those conflict with new approvals: task branches -> committed `dev` for nightly play -> gated `main`. A `dev` branch did not appear in a branch-name search. GitHub `main` was verified at `ff650afb811088720ea3f046fbac128588a76821` after the four final documentation PRs. Do **not** trust old branch instructions until migrated; do **not** merely add this package and leave both sets authoritative.

`docs/DOC_MAP.md` openly says it is stale. `docs/knowledge/README.md` is valuable existing research guidance. The latest handoff reported water record on E: with backup on the same physical drive; do not trigger terrain bakes on test hosts without it.

## Minimum safe activation sequence
1. Leave freeze in place. Review `docs/ai-team/MIGRATION_PLAN.md` and `KNOWN_CONFLICTS.md` against current repo and Cowork Library; verify latest branch/PR state.
2. Create or identify a **staging branch only after Dave authorizes writes**; import package as proposals, review the exact diff.
3. Resolve conflicting old documents, add provenance to decisions and update indexes in the **same reviewed change**. Preserve historical documents without silently altering previous decisions.
4. Configure GitHub branch protection and real test/check permissions. `CLAUDE.md` and skills are guidance, not a security boundary. Test installation in actual Cowork/Claude Code.
5. Get explicit written activation from Dave; end the freeze; then create `dev` from the verified agreed baseline, apply branch gates and run a dry-run before regular development.

Read the architecture docs in `docs/ai-team/` for policies and the tests in `EVALUATION_CASES.md` for acceptance criteria.
