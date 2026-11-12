# Validation gates and trusted testing environment
**Status: PROPOSED — implement mechanical enforcement, not prompt-only promises.**

## dev playtest gate (each nightly commit)
1. Agent commits are recorded; dev merge result is an immutable **exact SHA**.
2. Relevant automated checks pass on the proper machine. Full suite is not mandatory for dev but critical targeted checks cannot be skipped without labeling dev 'untested'.
3. Dedicated local Godot 4.7.2 voxel-tools build loads correct scene; PC-based startup/world load smoke test passes without stealing resources from Dave's active playtest.
4. Dev reviewer checks contract compliance, no unapproved data schema migration, and no known critical regression. Changed visual/audio content is explicitly marked 'not visually checked' unless evidence exists.
5. Every skipped/blocked gate, newly introduced serious defect, and known issue appears in short dev release notes and machine-readable test evidence. If critical smoke fails, do NOT announce dev playable. If smoke test could not run because Dave is playing or local access is unavailable, say `DEV COMMITTED — PLAYABILITY UNVERIFIED` and offer the last known green SHA. Never label NOT RUN as PASS.

## Risk-based test selection for dev
Before an expensive PC run, use `tools/tests_for_diff.py <base_sha> <head_sha>` (or `--paths`) and read its selected lanes **and** `why` explanations. Start with a test for the new behavior, affected callers/contracts, persistence and security where relevant, then required integration and startup checks. Do not automatically add `--all` or `--full` for routine `dev` changes.

The selector is deliberately conservative: for example, any `src/stream/terrain_net.gd` edit selects all fast tests. A wide selection is a **review trigger**, not proof that every selected test is essential for this specific `dev` change. Inspect the actual diff and affected consumers. If a smaller set appears safe, the coordinator may choose a **dev-only** scoped plan after an independent gate reviewer accepts the evidence and confirms no critical affected check is missing. Record the original selection and reasons, the tests run/deferred, rationale, residual risk, exact SHA and where the broader run belongs. Deferred tests run after the `dev` merge (next nightly `--full` run, and in any case before `main`) unless a specific, named risk requires them first. If the risk cannot be bounded, keep the selector's full plan or report the `dev` candidate as unverified.

A change that alters network message meaning, serialization or saves is also a Class C decision (`DECISION_AUTHORITY.md`): it needs Dave's approval for the change itself, and its test plan may grow, never shrink, under this section.

Never bypass required CI, weaken security/data-integrity or multiplayer checks, alter test-lane rules just to avoid a run, or relax the `main` promotion gate. Distinguish machine test runtime from Claude token cost; retain full test artifacts but send concise summaries. Reuse earlier results only where the same code, environment and checked behavior still apply.

Provenance: Dave, project chat, 12 Nov 2026 19:39 UTC (BLOCKER-001): "Use risk-based testing. Run the tests directly relevant to [the change] ... Keep the independent data-loss and regression review. If those checks pass, merge into dev ... Run the broader regression suite later unless you identify a specific reason it is necessary before merging. Our objective is reliable development, not unnecessary testing overhead." Status: DIRECTOR-APPROVED for `dev`; the `main` gate below is unchanged.

## main promotion gate (stronger)
All required CI on exact proposed merge SHA green; required suite including correct voxel build and environment-specific tests completed; independent human/AI non-author review recorded; game launch/world load and affected visuals/interaction verified on PC; no known severe regressions; material contract/architecture changes are specifically approved; actual GitHub branch rules require checks/reviews. After merge verify new main exact SHA and tag. If GitHub 'merge queue' changes commit SHA, rerun/verify checks for the actual candidate per branch settings.

## Environment constraints from 11 Nov handoff
- No cloud headless testing, terrain baking, renders or other heavy Godot jobs. GitHub CI lint/static checks may still be used if permitted; distinguish from forbidden cloud Godot tests.
- Water record ~1 GB, 129 files, ignored by git: live `E:\Software\godotDev\probe_bake\worlds\base_world\record`; verified copy `E:\Software\godotDev\_WaterFile\record`. Both on E:, not disaster-safe. Do NOT bake on David4's host without record. Bakes without record can silently rule-bake tiles. Separate-drive backup requires Dave's authorization.
- Godot voxel-enabled editor: `C:\GodotInstaller\godot.windows.editor.x86_64.exe`; generic standard Godot executable is not valid for full world tests. Before running anything verify actual current paths and versions.
- Dave's checkout `C:\GodotProjects\DynastyALWL` is protected against worker experiments. Dino's copies under E: are separate. Use guarded slots/timeouts; don't kill Godot processes blindly.
- At handoff, final main was **not** fully retested: reported 155 passes on final commit vs 342 on earlier fully tested checkpoint. Treat as historical reported state, not current passing gate.

## Evidence format
Task ID, base SHA, head SHA, final merged SHA (if any), runner identity, machine, tool/Godot version, test plan, test counts including skips, output location, screenshots/visual review if applicable, reviewer, decision on safe promotion. A claim without output/commit reference is NOT a passed gate.
