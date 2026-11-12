# Mission 001 state (master items catalog implementation)

**Read this first when resuming.** Brief: Dave's "MISSION 001 — MASTER ITEMS CATALOG IMPLEMENTATION", project thread "Mission 001", 12 Nov 2026 05:33Z (authorizes Phases 0–10 and 1b; catalog Draft 18 approved; no `main` merge without Dave). Plan: `docs/design/CATALOG_IMPLEMENTATION_PLAN.md`. Ledger: `docs/design/catalog_ledger.json` (`python3 -I tools/catalog_ledger.py --check`).

Updated: 2026-11-12 (UTC). Mission lead: Claude Code thread session on Dave's PC (ManlandRyzen5), branch `claude/project-thread-e3pz0o`, working clone `E:\Software\godotDev\mission001` (a `git clone --shared` of Dave's checkout; Dave's checkout `C:\GodotProjects\DynastyALWL` is never switched or edited).

## Dave's rulings for this mission
| When (UTC) | Ruling | Effect |
|---|---|---|
| 12 Nov 05:33 | Mission 001 brief | Phases 0–10 and 1b authorized without per-phase go; catalog design fixed. |
| 12 Nov 05:42 | "you have autonomy nothing should stop you. if they have questions for me I expect you to answer them taking your guidance from the documents..." | Questions are decided from the documents and recorded here, not sent to Dave. Brief limits still stand. |
| 12 Nov 05:41 | "this is a new game so there are no existing things in the world don't worry about stuff that exists." | No old-save migration or retired-structure recovery (plan, "Dave's new-game ruling"). New content must still save and load. |

## Baseline
- `dev` = `bd0628a33` (PR #1034 Admin Mode merged 12 Nov). `data/items` identical to `7f8aabf4`, which Draft 18 was written against: items 889 (next 896), recipes 404 (287 live, next 407), blueprints 185 (next 186), structures 216 (top state 228).
- `main` untouched by this mission.

## Operational preflight (12 Nov)
| Check | Result |
|---|---|
| Project instructions readable (CLAUDE.md, ai-team docs, Ponytail) | PASS |
| Repo agents and skills invocable | PASS: the session lists all `.claude/agents` types and skills; `gate-reviewer` launched as a background subagent for PR #1035. |
| Durable records | PASS: this file, the plan and the ledger are in the repo. |
| Branch ownership | PASS: one mission branch; task branches cut from it or from `dev`; Dave's checkout untouched. |
| PC testing without disturbing Dave | Via the guarded runner (`tools/godot_slot.sh`, max 3 jobs) from the mission clone, headless with timeouts. |
| Limitations (actual) | Subagents run only while this session is active: no unattended progress between sessions. Cowork workers are not used. The clone shares objects with Dave's checkout (`--shared`): do not run `git gc --prune` there while it exists. |

## Task queue
| Task | Phase | Owner | Branch | Status | Reviewer | Next action |
|---|---|---|---|---|---|---|
| M001-T00 PR #1035 docs into `dev` | 0 | mission lead | `claude/project-thread-39uvpg` @ `0707384` | review running | gate-reviewer (independent) | merge after PASS |
| M001-T01 plan, ledger, state | 0 | mission lead | `claude/project-thread-e3pz0o` | in development | gate-reviewer | review, PR into `dev` |
| M001-T02 Woodworking Table retirement (PR #1036) | 0 | mission lead | `claude/project-thread-e3pz0o` | not started | gate-reviewer | #1036 breaks `test_blueprints.gd` (it counts 180 live blueprints and uses the Woodworking table as its sample piece); carry the change with the test fix, close #1036 as superseded |
| M001-T03 Phase 1 data rows | 1 | systems-engineer (agent) | task branch | not started | gate-reviewer | after T01 |

## Decisions needing Dave
None open. Q1 (existing FUTURE rows) was decided under the 05:42 direction: see the plan, "Existing FUTURE rows switched on".

## Coordinator decisions (ENGINEERING, recorded for review)
- Reinforced wagon wheel is FUTURE-GATED with the animal vehicles: it serves only them (s3.11; s8 "only the Handcart before").
- Meatballs 837 goes live in Phase 6 with Uncooked Meatballs (s3.12 DELEGATED default).
- Phase 2 is split 2a/2b/2c and Phase 4 into 4a/4b to fix the dependency contradiction and to bring craftsmanship into Mission 001.
- Ledger adds two baseline states, NO CHANGE (catalog KEEP) and RETIRED BEFORE CATALOG, so all 889 existing rows are accounted for.

## Evaluation log (mission section 13)
| Date | Event |
|---|---|
| 12 Nov | Preflight found PR #1036 would break `test_blueprints.gd`; CI `merge-check` passed it because CI is static only. |
