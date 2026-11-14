# GOALS-REPAIR (CCR05 repair) — execution state

Lead thread "Repair progression and build player guide" (project DynastyALWL2), started 14 Nov 2026 00:34Z from Dave's brief. Lead branch `claude/project-thread-21lhdk`. Decisions and assumptions: [REPAIR_DECISIONS.md](REPAIR_DECISIONS.md). Final evidence report (created when tests begin): `docs/design/PLAYER_PROGRESSION_REPAIR_VERIFICATION.md`.

Ledger states: NOT STARTED / IN PROGRESS / IN REVIEW / IN DEV / BLOCKED. Evidence levels (repair plan §2): STATIC_READ, AUTOMATED_TEST, HEADLESS_GODOT, PLAYED_F6, MULTIPLAYER_RESTART. Nothing is passed on compile alone; admin-spawned or direct-server tests do not prove the player route.

## Standing instructions for this mission

- Dave 14 Nov 00:34Z: the brief (implement, independently review and integrate the approved repairs and player guide into `dev`; `main` untouched).
- Dave 14 Nov 00:35Z: work autonomously from the documents; he checks in for updates.
- Dave 14 Nov 00:36Z (verbatim in REPAIR_DECISIONS.md §3 intro): questions meant for him are answered from his earlier rulings with a reasonable assumption and logged in REPAIR_DECISIONS.md, section "Assumed on Dave's behalf, for his review". Not for `main`, destructive or security-sensitive actions, or live/retrospective payouts. Reach into catalog data: ruling R-1.
- Godot tests only on Dave's machines (lane B David4 preferred, via the coordinator with an exact reviewed SHA). Never in the cloud.

## Baseline (R0)

| Item | Value |
|---|---|
| Starting `dev` | `1382118e` (13 Nov 22:34 -04:00) |
| PR #1085 (CCR05 doc cleanup, head `86d23cf`) | Independent gate review PASS WITH MINOR NOTES (7 minor); merge-check green; merged to `dev` at **`d990abd`** (14 Nov). Minor findings 1-6 fixed on the lead branch (this PR); 7 optional, left. |
| Overlapping doc PRs | #1084 (claude/docs-cleanup-gameplay-rules-20261113): competing edit of the same Appendix A; its useful points (Appendix retitle, `forge` labelling, item 827 note) are now carried by the #1085 follow-up, so #1084 is **superseded** (left open for its owner to close). #1083 (entry-point docs: START_HERE, RULES, WORKFLOW, DOCUMENT_AUTHORITY): no overlap with this mission's files except one table row in DOCUMENT_CONTRADICTIONS; not reviewed here. #1082 (door docs, based on older `cdd7eca`): not in this mission's path; door behaviour itself is in `dev` (PRs #1077, #1078). |
| Protocol | 118 (`src/stream/terrain_net.gd`) |
| Already in `dev` and retained | Door system (empty frames, 28 separate doors, Iron/Steel doorways retired; #1077/#1078); packs without slots (#1079); BUGLIST-001 and PLAYTEST-001 fixes; Admin Reset World; catalog Mission 001 baseline. All still NEEDS PLAYER VERIFICATION per their ledgers. |
| Earlier "Add current goal display" thread | Stopped by Dave pending his design; PLAYER_JOURNAL_GOALS_UI.md is that design now. Branch check in baseline below. |

Baseline investigations (read-only, in progress): R1 resources/water/farming; goal runtime + Journal/HUD + keys; metalworking stations/bins. Results feed the work packages below.

## Shared-file ownership

`src/stream/server_items.gd` (18.5k lines) and shared `data/items/*.json` carry a per-file owner lock (CATALOG_IMPLEMENTATION_PLAN §1). Until proposed refinement D-E1 (per-section lock) is adopted, the plan's **per-file** lock holds: one writer of server_items.gd and of each shared JSON at a time, recorded here; every PR rebases on `dev` before merge. `src/stream/terrain_net.gd` `PROTOCOL_VERSION` + `PROTOCOL.md`: one bump owner at a time, assigned here.

| Shared file / section | Current owner | Since |
|---|---|---|
| (none assigned yet) | | |

## Work packages

| WP | Phase | Scope | Owner | Depends on | State | Branch / PR | dev SHA | Evidence |
|---|---|---|---|---|---|---|---|---|
| WP-00 | R0 | #1085 review + merge, follow-up fixes, tracker | lead | — | IN REVIEW | lead branch | #1085 → `d990abd` | gate review 14 Nov |

## Next actions

1. Finish baselines; assign first ready packages (R1 sources/water/farming, admin Ctrl+Shift shortcuts, goal-state sync foundation).
2. Ask the coordinator to start separate threads for large independent packages (Journal/HUD/placard UI; charcoal Map; smelting/smithy chain) with self-contained briefs.
