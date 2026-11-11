---
name: session-handoff
description: Use when a worker finishes a unit of work, is context saturated, or the coordinator must refresh.
---
# Session Handoff
**Scope:** repeatable workflow, not a higher-priority authority. Obey `docs/ai-team/CONSTITUTION.md` and the current freeze/permission state. **This file is auto-discovered by Claude Code when installed; Cowork requires account-enabled skills.**

## Procedure
Checkpoint task ID, branch/head SHA, authoritative decision links, files changed, verification evidence, failed approaches and exact next step. Save to repo and Library or mark second copy SYNC PENDING. Coordinator updates small state board; new session reads brief+checkpoint and verifies reality. Retire old session only after state is accessible. Do not assume Cowork workers automatically transfer to new root conversation.

## Output contract
Produce short next-action to coordinator; durable task/decision/checkpoint file with source links and evidence. State PASS, FAIL, NOT RUN and SYNC PENDING accurately. Never claim a merge, test or backup before an observable result.
