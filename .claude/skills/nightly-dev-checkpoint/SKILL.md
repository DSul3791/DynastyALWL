---
name: nightly-dev-checkpoint
description: Use at evening integration to produce a fully committed dev branch for Dave to playtest, without forcing a main merge.
---
# Nightly Dev Checkpoint
**Scope:** repeatable workflow, not a higher-priority authority. Obey `docs/ai-team/CONSTITUTION.md` and the current freeze/permission state. **This file is auto-discovered by Claude Code when installed; Cowork requires account-enabled skills.**

## Procedure
Freeze risky new integration. Gather only reviewed, committed branches and known compatible dependencies. Verify exact dev head SHA and targeted CI; request PC smoke test when Dave is not using his Godot session. If critical check cannot run, do NOT state playable; identify last known good. Keep main untouched. Update short release note, current tasks, known defects and build SHA. Send Dave <=4 concise lines, technical evidence stays repo/Library.

## Output contract
Produce short next-action to coordinator; durable task/decision/checkpoint file with source links and evidence. State PASS, FAIL, NOT RUN and SYNC PENDING accurately. Never claim a merge, test or backup before an observable result.
