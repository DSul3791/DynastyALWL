---
name: bug-investigation
description: Use when Dave reports a bug during playtesting or a reproducible regression is observed.
---
# Bug Investigation
**Scope:** repeatable workflow, not a higher-priority authority. Obey `docs/ai-team/CONSTITUTION.md` and the current freeze/permission state. **This file is auto-discovered by Claude Code when installed; Cowork requires account-enabled skills.**

## Procedure
Record tested SHA, expected vs actual, scene, steps, weather/simulation state, logs/screenshots. Start independent triage immediately; do not interrupt Dave PC tests or touch active checkout. Consult knowledge/previous attempts. Hypothesize and design smallest fix. Run allowed targeted tests via assigned runner, report pass/fail/skip and hand off reviewed branch. No speculative fixed-claim without evidence.

## Output contract
Produce short next-action to coordinator; durable task/decision/checkpoint file with source links and evidence. State PASS, FAIL, NOT RUN and SYNC PENDING accurately. Never claim a merge, test or backup before an observable result.
