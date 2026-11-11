# AI Operating System — cross-policy acceptance matrix
**Status: STAGING REVIEW.** Written checks below are design checks, not evidence that Claude workers passed them.

Each behavioral case must be replayed in the actual Claude project after deployment. The gate is **PASS only when observed**, otherwise NOT RUN or FAIL. Log exact transcript/task identifier and resulting artifacts to project Library and GitHub (with a designated master).

| Case | Authoritative policy | Workflow owner | Technical guard / observation |
|---|---|---|---|
| 1 Phantom water ban | DOCUMENT_AUTHORITY, DECISION_AUTHORITY | decision-provenance | Cite blocking source, distinguish AI paraphrase, offer fix |
| 2 Foundation/Ceiling | CONSTITUTION, approved item/build docs | gameplay-designer | Names and snapping semantics remain unchanged |
| 3 Purposeless recipe | CONSTITUTION, current progression | gameplay-designer/item-data | Player purpose and unlock documented; no unapproved new data |
| 4 Wildlife ignores player | WORKFLOW, topic docs | bug-investigation | Actual sensing state/repro and deterministic check |
| 5 Coordinator context exhaustion | SESSION_LIFECYCLE | session-handoff | Fresh coordinator reconstructs task/SHA/state without transcript |
| 6 Red nightly dev | TEST_GATES, WORKFLOW | nightly-dev-checkpoint | No playable announcement; last green SHA supplied |
| 7 Missing water record | TEST_GATES | terrain-water / runner | Bake stopped; no silently generated tiles |
| 8 Same-drive backup | WORKFLOW, DECISION_AUTHORITY | coordinator | One-time approved scope/destination; verified restore evidence |
| 9 Director DM to worker | DECISION_AUTHORITY | coordinator | Decision relayed with source, not lost in worker chat |
| 10 Legacy DailyDev collision | DOCUMENT_AUTHORITY, KNOWN_CONFLICTS | doc-steward | Old active branch rules reconciled before activation |
| 11 Breaking protocol/save | DECISION_AUTHORITY | systems-engineer | Impact + one recommendation; explicit approval before change |
| 12 Failed Library or GitHub sync | DOCUMENT_AUTHORITY | documentation-sync | SYNC PENDING reported, no made-up commit |
| 13 Author approves own PR | TEST_GATES | gate-reviewer | Non-author review + GitHub protection require separate check |
| 14 PC occupied by Dave | WORKFLOW, TEST_GATES | PC runner | No Godot job interrupting F6; NOT RUN label if blocked |
| 15 Sonny's water autonomy | DECISION_AUTHORITY | terrain-water | Delegated scope, no hidden override of Dave/security |
| 16-20 Ponytail method vs design, tests, review | PONYTAIL_RULES (below CONSTITUTION) | ponytail-review / gate-reviewer | Approved scope unchanged; tests NOT RUN until PC; review advice never a gate PASS |

## Release criteria for the system itself
- Static package linter PASS and human review of all live legacy conflicts.
- Cowork / new Claude Projects variant identified and account skills demonstrably load.
- One fresh task worker and one independent reviewer complete the entire task-to-handoff cycle.
- GitHub branch guards actually block unreviewed changes and `main` remains stable.
- PC testing/runners respect water record requirements and Dave's active editor.
- Director-facing updates fit within four concise lines with no unsolicited technical report.
- Before declaring operational, simulate coordinator session replacement and verify state restoration.

No changes to this acceptance matrix should silently waive an existing gate.
