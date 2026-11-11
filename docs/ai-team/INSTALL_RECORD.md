# AI Team Operating System v1.0 — install record
**Status: INSTALLED in repo (11 Nov 2026, on Dave's written instruction "First install and validate our new AI Team Operating System"). Handoff freeze for game development stays ON until Dave explicitly authorizes development.** The `PROPOSED`/`STAGING` status lines inside the package files are kept verbatim for provenance; this record says what is now in force.

## Dave's instructions (verbatim source: project thread "Install AI Team Operating System", 11 Nov 2026 17:40 UTC)
- Install and validate the AI Team Operating System from the configuration package.
- Preserve the existing game's code, designs, decisions and completed handoff.
- Do not resume game development until Dave explicitly authorizes it.
- The `dev` branch is for nightly playtesting; `main` remains protected and stable.
- Keep communication with Dave brief; technical documentation is handled internally.

## What was installed (source: `Dynasty_AI_Team_Operating_System_v1_0.zip`, reviewed before install: Markdown, one static Python checker, skill ZIPs; no scripts that write, delete or call out)
| Package path | Repo path |
|---|---|
| `CLAUDE.md` | `CLAUDE.md` (no earlier root CLAUDE.md or AGENTS.md existed) |
| `.claude/agents/*.md` (8) | `.claude/agents/` |
| `.claude/skills/*/SKILL.md` (7) | `.claude/skills/` (identical to the Cowork upload ZIPs; checked file by file) |
| `docs/ai-team/*.md` (16) | `docs/ai-team/` |
| `README_FIRST.md`, `REVISION_AND_AUDIT_LOG.md`, `cowork/` | `docs/ai-team/package/` (package-only files kept out of the repo root) |
| `tools/check_ai_team_package.py` | `tools/` (paths adjusted to the layout above; also now fails if `docs/START_HERE.md` or `RULES.md` revive a superseded branch rule) |

*Later change (11 Nov 2026): Ponytail v5.3.3 added three skills (10 in total), five agent edits and checker rules; see `PONYTAIL_INSTALL.md`. The evidence lines below are for the v1.0 install SHAs.*

Existing `.claude/settings.json` permissions (push to `main`, force push, deletes denied) are unchanged.

## Legacy conflicts (`KNOWN_CONFLICTS.md`) — resolution at install
| # | Resolution |
|---|---|
| 1 | `docs/START_HERE.md` branch rule replaced by task branch -> `dev` -> gated `main`; old 2 Nov rule named as superseded. |
| 2 | `RULES.md` Git section reconciled to `dev`; "Dave says go" before `main` kept. Decision 61 text untouched. |
| - | Gate review found `WORKFLOW.md` lets routine gated promotions to `main` skip Dave; annotated that Dave's go stays required until he changes it (`RULES.md`). |
| 3 | `docs/DOC_MAP.md` banner points to the AI team docs; the file list stays STALE (a full refresh is documentation work for later). |
| 4-8 | Not changed: they touch roles, machines, QA links and design provenance, which need the Library handoff files (not reachable from this project) or Dave. Open, carried forward. |
| 9 | Re-verified: `main` = `ff650afb811088720ea3f046fbac128588a76821` before install. |
| 10 | `dev` did not exist; created at the verified `main` SHA `ff650afb` (no game changes). |

## Validation evidence
- PASS: `python3 -I tools/check_ai_team_package.py` (19 core files, 8 agents, 7 skills, frontmatter, entry-point pointers, superseded rules). Negative check: the old `main` versions of `docs/START_HERE.md` and `RULES.md` contain the superseded strings the checker now rejects.
- PASS: the same check added to CI (`.github/workflows/merge_check.yml`), which also now runs on pushes to `dev`. Static only, no Godot.
- PASS (observed live, 11 Nov 2026, Claude Code project thread on this branch): all 8 `.claude/agents` appeared as agent types and all 7 `.claude/skills` appeared as skills without any account upload. One live trial: `gate-reviewer` reviewed head `4fc1cbdd` read-only (tools Read/Grep/Glob only, as its allowlist says) and returned PASS with one real finding (WORKFLOW vs RULES on Dave's go), fixed in `379ea4fd`.
- NOT RUN: the other live agent cases (`EVALUATION_CASES.md`), Phase 4 smoke trial, any Godot test (none allowed in the cloud; development paused).
- NOT VERIFIED: GitHub branch protection / required checks on `main` and `dev` (repository settings are not readable from this session); Cowork account skills; Library copies (`/mnt/project-files/START_HERE.md`, `HANDOFF.md`) — SYNC PENDING, they are not in this project's shared folder.

## Remaining steps for Dave (settings only Dave can change)
1. GitHub > Settings > Branches: protect `main` (PR required, `merge-check` required, no force push); optionally protect `dev` the same way.
2. Optional: paste `docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt` into the project instructions.
3. Say when game development may resume.
