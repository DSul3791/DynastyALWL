---
name: merge-validation
description: Use before promoting dev into protected main or reviewing any release-grade PR.
---
# Merge Validation
**Scope:** repeatable workflow, not a higher-priority authority. Obey `docs/ai-team/CONSTITUTION.md` and the current freeze/permission state. **This file is auto-discovered by Claude Code when installed; Cowork requires account-enabled skills.**

## Procedure
Confirm intended exact commit SHA, independent review, green required CI, full correct-Godot PC suite, visually relevant checks, design approval and no high-severity regressions. Verify GitHub branch protections are technical rules, not prose. Never push directly to main or change rules to make red CI green. If fail, hold merge and log precise blocker. After successful authorized merge verify actual new main SHA and tag.

## Output contract
Produce short next-action to coordinator; durable task/decision/checkpoint file with source links and evidence. State PASS, FAIL, NOT RUN and SYNC PENDING accurately. Never claim a merge, test or backup before an observable result.
