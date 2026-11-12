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
- `dev` = `bd0628a33` at start (PR #1034 Admin Mode merged 12 Nov); `e314789cd` after PR #1035 (catalog docs) merged 12 Nov 05:49Z. `data/items` identical to `7f8aabf4`, which Draft 18 was written against: items 889 (next 896), recipes 404 (287 live, next 407), blueprints 185 (next 186), structures 216 (top state 228).
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
| Task | Phase | Owner | Branch @ head | Status | Review | Next action |
|---|---|---|---|---|---|---|
| M001-T00 PR #1035 docs into `dev` | 0 | mission lead | merged `e314789` | DONE | gate-reviewer PASS WITH NOTES on `0707384` | — |
| M001-T01 plan, ledger, state | 0 | mission lead | `claude/project-thread-e3pz0o` | review fixes applied | gate-reviewer PASS WITH NOTES on `159b566`; findings 1–6 fixed | PR into `dev` with T02 and T03 |
| M001-T02 Woodworking table retirement (from PR #1036) | 0 | mission lead | same | tests PASS | same review: no live dependency left, expectations right | merge with T01; close PR #1036 as carried |
| M001-T03 Phase 1 rows (180, numbers 896–1075) | 1 | item-data agent | `m001/p1-rows` @ `8911012a6` (clone `E:\Software\godotDev\m001_p1`) | implemented, static checks PASS | pending | PC tests (validate_items, item looks), review |
| M001-T04 Phase 1b instance data | 1b | systems-engineer agent | `m001/p1b-instances` (clone `m001_p1b`), brief `T04_BRIEF.md` | in development | pending | agent report |

## Evidence so far
- T02 at `159b566` (voxel build, this PC): `tools/run_tests.sh` over the 205 tests `tests_for_diff.py` picks: 201 PASS, 4 FAIL (audio `.import` files missing from the clone); after copying the untracked `.import` files from Dave's checkout, the 4 PASS (`scratchpad/t02b`). Total 205/205.
- Startup smoke at `159b566` from the mission clone (world data copied from Dave's checkout): client reached the welcome and loaded the world, 0 script errors, 2 leaf textures missing (import cache mismatch in the clone only), exit 127 (known headless-exit issue).
- **Smoke harness issue:** after the client quit, its terrain server (started by the client, `--quit-when-empty`) kept running on port 24600; it would have caught Dave's next F6. Stopped by PID after checking its command line named the mission clone. Every smoke run must check for and stop its own server the same way, and never touch a server from Dave's checkout.

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
| 12 Nov | Review of T01 found 5 should-fix items (ledger phase mapping, 2a/2b saw dependency, Q1 over-reach on Copper pot and Fish soup, records not updated, `--check` gaps); all fixed before merge. |
| 12 Nov | Fresh clones lack untracked `.import` files and `worlds/` data: 4 audio tests failed until copied. Copy both into every test clone. |
| 12 Nov | Smoke run left its terrain server alive (see Evidence). |
