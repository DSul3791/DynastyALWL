# Validation gates and trusted testing environment
**Status: PROPOSED — implement mechanical enforcement, not prompt-only promises.**

## dev playtest gate (each nightly commit)
1. Agent commits are recorded; dev merge result is an immutable **exact SHA**.
2. Relevant automated checks pass on the proper machine. Full suite is not mandatory for dev but critical targeted checks cannot be skipped without labeling dev 'untested'.
3. Dedicated local Godot 4.7.2 voxel-tools build loads correct scene; PC-based startup/world load smoke test passes without stealing resources from Dave's active playtest.
4. Dev reviewer checks contract compliance, no unapproved data schema migration, and no known critical regression. Changed visual/audio content is explicitly marked 'not visually checked' unless evidence exists.
5. Every skipped/blocked gate, newly introduced serious defect, and known issue appears in short dev release notes and machine-readable test evidence. If critical smoke fails, do NOT announce dev playable. If smoke test could not run because Dave is playing or local access is unavailable, say `DEV COMMITTED — PLAYABILITY UNVERIFIED` and offer the last known green SHA. Never label NOT RUN as PASS.

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
