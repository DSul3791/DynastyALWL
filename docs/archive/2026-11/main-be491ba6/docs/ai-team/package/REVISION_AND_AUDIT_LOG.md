# Design reviews — 11 November 2026
**Scope:** staged artifacts, not deployed runtime. No live Cowork / game agent evaluations have been performed.

## Iteration 1 — architecture review
Found risk: parallel long-lived agents repeat decisions and rely on compaction. Changed: permanent role catalog + temporary task sessions + durable task board/checkpoints. Found risk: Coordinator assumed to be disposable like worker. Changed: explicit Cowork root limitation and manual transition protocol.

## Iteration 2 — authority and conflicting documents
Found risk: 'latest document wins' could cement hallucinated AI restrictions. Changed: decision provenance, narrow scope, source verification, separate delegated decisions from Director-approved. Found live repo conflict: `docs/START_HERE.md` rejects daily branch; `RULES.md` uses old DailyDev; user approved committed nightly `dev`. Changed: activation migration gate, conflict inventory, clear staging freeze.

## Iteration 3 — platform correctness and operation
Found risk: `.claude/agents` and repo skills mistakenly assumed to configure Cowork automatically. Changed: separate Cowork instructions, account-enabled skill installation, Code-only subagent profiles, capability verification. Found risk: 'nightly merge to main' inconsistent with user approval. Changed: nightly dev play, main only on full gate. Found risk: tests on wrong machine and game interrupted. Changed: explicit PC/tool/record/slot checks and truthful NOT RUN statuses.

## Remaining deployment checks (NOT PASSED YET)
- Correct Claude Cowork loading and real worker creation after project instructions.
- Actual Claude Code CLI version and `claude plugin validate` support for subagent definitions.
- Correct GitHub protection and required check names; actual test runner access.
- Files in private Library beyond uploaded START_HERE; current live QA and decision bodies.
- Real-world five-task evaluation and rollback drill.

**Current verdict:** coherent staging candidate after three internal review passes, but implementation and behavioral validation remain mandatory. 'No further meaningful textual improvements found' is not a guarantee of correctness or permanent completion.

## Iteration 4 — independent cold audit, compatibility and authorization
Verified live `main` is `ff650afb` and the final doc merges are complete. Found hidden risk: Code reviewers could edit files even if told not to; restricted the gate and art reviewer tool lists to `Read, Grep, Glob`. Found danger that a failed/absent PC smoke test might be called playable; now dev gate explicitly says `PLAYABILITY UNVERIFIED` when NOT RUN. Found daily backup consent would require repeated questions; clarified one-time agreement on scope, destination, retention, after which daily jobs run without interruptions. Found Cowork skill upload uses lowercase `skill.md` vs Claude Code uppercase `SKILL.md`; ship separate skill archives. Found new Claude project UI rollout means coordinator rotation cannot be assumed identical across accounts; add surface-detection requirement. Added explicit adoption rules for external ChatGPT research papers.

## Cross-system consistency check (static)
The validation script checks all eight agent definitions, seven skill files, the major routing entry points, authority/status markers, protected branch terms and no superseded active branch phrases. Scenarios in `EVALUATION_CASES.md` are *designed tests*, not actual Claude worker passes. Neither the local static test nor this document demonstrates that the new configuration loads in the user's Claude account.

## Iteration 5 — stopping criterion
Re-read the entry points, role profiles, decision authority, documentation authority, workflow and gates after the changes. No further material *textual* conflict was identified in this package. Key unknowns explicitly remain as deployment verification gates: Claude account project surface, skill installation, actual test runner routing, GitHub checks/permissions, private Library sync, real agent behavior. Do not translate this into a claim that the system is already working.
