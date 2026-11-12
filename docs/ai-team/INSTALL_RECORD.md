# AI Team Operating System v1.0 — install record
**Status: INSTALLED in repo (11 Nov 2026, on Dave's written instruction "First install and validate our new AI Team Operating System"). IN FORCE; the general handoff freeze was lifted by Dave on 12 Nov 2026** (rulings in `DECISION_AUTHORITY.md`). The policy files' status lines now say IN FORCE; the package copies under `package/` keep their original STAGING text for provenance. This record says what is in force.

## Dave's instructions (verbatim source: project thread "Install AI Team Operating System", 11 Nov 2026 17:40 UTC)
- Install and validate the AI Team Operating System from the configuration package.
- Preserve the existing game's code, designs, decisions and completed handoff.
- Do not resume game development until Dave explicitly authorizes it. *(Lifted by Dave 12 Nov 2026.)*
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

Existing `.claude/settings.json` permissions (push to `main`, force push, recursive and branch deletes denied) are unchanged. They apply only to Claude Code on a machine (Dave's PC, Remote Control); cloud project threads do not apply them (see platform notes below).

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
- NOT RUN: the other live agent cases (`EVALUATION_CASES.md`), Phase 4 smoke trial, any Godot test (none allowed in the cloud; development was paused then, lifted 12 Nov 2026).
- OBSERVED (OPTEST-01, 11 Nov 2026): GitHub reports `main` **protected** and `dev` **not protected** (branch list API). The exact rule set (required checks, reviews, force push) is not readable from a cloud session; see `docs/ai-team/trials/OPTEST-01/RESULTS.md` for the non-destructive PR check.
- KNOWN LIMITATION (OPTEST-01, PR #1032, 11 Nov 2026), recorded for future improvement: GitHub does not mechanically enforce "Dave's go before `main`". PR #1032 showed `mergeable_state: clean` with CI green and no approving review, and AI sessions open and merge PRs through Dave's own GitHub account, so GitHub cannot tell an AI merge from Dave's. The rule is process-enforced (`RULES.md`, `CLAUDE.md`, agent tool allowlists, `.claude/settings.json` push denies). Dave (11 Nov 2026): record it; raise it again only with a practical recommended solution. Candidate directions to evaluate later, none adopted: a separate bot/App identity for AI writes so a required review by Dave becomes meaningful; protecting `dev`.
- NOT VERIFIED: Cowork account skills; Library copies (`/mnt/project-files/START_HERE.md`, `HANDOFF.md`) — SYNC PENDING, they are not in this project's shared folder.

## Platform notes (observed 12 Nov 2026, cloud project thread; audit PR #1052 and its review)
- Cloud threads clone the default branch `main`, so `CLAUDE.md` and the policy docs they first see are `main`'s. Project instructions (set 12 Nov 2026) tell threads to fetch `origin/dev` and read the rules there; `CLAUDE.md` says the same.
- `.claude/settings.json` deny rules are **not applied** in cloud threads (probe: `git clean -n` and `git branch -d <missing>` ran unblocked; Anthropic docs agree). Auto mode and in-thread approvals are the cloud guard; GitHub protection on `main` is the only mechanical one.
- Repo `.claude/agents` (8) and `.claude/skills` (10) **were available** in cloud threads on 11 and 12 Nov, although Anthropic's Projects docs say they are not loaded; re-check per thread rather than rely on it. The project conversation (coordinator) has only built-in skills.
- Remote Control auto mode blocked a reviewed, CI-green merge into `dev` (PR #1051) until Dave typed the approval in that thread.
- VERIFIED in a fresh cloud thread ("Verify new thread instructions", 12 Nov 2026, after dev merge `00bea31`), observed not assumed: clone started on `main` `be491ba6`, then the thread cut its branch from `origin/dev` `00bea31` citing the project instructions; it reported the freeze lifted with protected decisions still Dave's and the catalog freeze unchanged; it would document and request the next assignment, not create work; it quoted Decision 61 as Dave's 12 Nov clarification; its test PR #1054 targeted `dev` (closed unmerged); all 8 agents and 10 skills were available; PASS on the six instruction checks; deny-rule probe observed separately (`git clean -n` ran despite the deny rule).
- GitHub enforcement, read from the branch-protection API on 12 Nov 2026: `main` requires a pull request (no direct push), blocks force push and deletion, requires conversation resolution, and applies to admins; it requires **0 approving reviews** and **no required status checks** (the `merge-check` CI is not a required check). `dev` has no protection; no rulesets exist. So Dave's go before `main`, independent review and green CI are process rules, not mechanical gates. Practical options, not adopted: add `merge-check` as a required status check on `main` (works today); a required approving review is meaningful only once AI sessions push and open PRs under a separate GitHub identity (bot account or GitHub App), with Dave as required reviewer or code owner.
- KNOWN LIMITATION: the `CLAUDE.md` a cloud thread auto-loads is `main`'s, which still says the handoff freeze is on. Only the project instructions correct it until `dev` is promoted to `main` (Dave's go). Test branch `claude/project-thread-1hjif5` (PR #1054) could not be deleted from the cloud and is left on GitHub.

## Remaining steps for Dave (settings only Dave can change)
1. GitHub > Settings > Branches: `main` is reported protected (11 Nov 2026, Dave says configured); read 12 Nov 2026: it requires a PR and blocks force push, but `merge-check` is **not** a required check and 0 approvals are required (see platform notes). Optional: protect `dev` the same way (still unprotected).
2. Done 12 Nov 2026: short project instructions (dev base, PRs to dev, pointers) set by the coordinator on Dave's approval; the Cowork STAGING template was not used.
3. Done 12 Nov 2026: general freeze lifted.
