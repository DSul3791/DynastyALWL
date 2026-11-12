# Decision authority and low-interruption rules
**Status: PROPOSED. Read `CONSTITUTION.md` first.**

| Level | Example | Default actor | Record | Human approval |
|---|---|---|---|---|
| A — Routine/reversible | Fix crash, refactor within contract, test strategy | Task agent + reviewer/coordinator | Task log | No |
| B — Local design refinement | Adjust deer perception thresholds, recipe timing within approved progression | Subsystem lead/coordinator | DELEGATED entry with before/after and evidence | No if low-risk and fits accepted design |
| C — Cross-system significant | Breaking saves/RPCs, re-bake method, architecture change, gameplay tier/name rewrite | Coordinator recommends | PROPOSED, impact map | Yes |
| D — Protected/irreversible | Delete uncommitted work, spend money, publish, weaken security/gates, force push, new backup location if policy requires | Dave and actual tool permissions | Explicit authorization and evidence | Always |

When uncertain, select the least disruptive reversible option, preserve evidence and escalate **only if stakes are material**. A question from Dave is not automatically a 'go' for destructive changes. Direct new instructions from Dave can grant ordinary work authority but do not bypass external permission prompts or the current handoff freeze unless explicit.

**Escalation format, maximum 4 lines to Dave:** Problem; Recommended choice; Why/impact; Required yes/no. Batch unrelated nonurgent choices; continue unaffected jobs. Never pass off a DELEGATED decision as a direct quote or confirmed director approval.

**Suspected obstruction:** Check the source sentence, owner, date, status, last real human source and technical basis. If likely AI paraphrase, label UNVERIFIED RESTRICTION; do not let it suppress investigation. Preserve earlier approved intent and request an explicit judgment only for a substantive conflict.

**Water standing ruling:** 11 November 2026: Dave authorized Sonny to decide water without ongoing 'buts'; observations from Dave may become subsequent fixes. Treat as delegated technical authority **within water's scope**, not permission to alter game vision, delete backups, override platform restrictions or redefine other systems.

**Item catalog freeze (standing ruling, DIRECTOR-APPROVED):** 11 November 2026, Dave, project thread "Make Admin Mode off by default": "Freeze all discretionary additions, removals, renames, and recipe redesigns in the item catalog. ChatGPT and I are going to review and approve the definitive catalog. Claude's job afterward will be implementation, validation, and reporting problems—not independently redesigning the items." In force until Dave lifts it or adopts the definitive catalog. Scope: `data/items/` items, recipes, names, ids, ingredients, stations and blueprints, and the code lists that name items. No agent adds, removes, renames, retires or redesigns an item or recipe on its own judgment, at any decision level (the level B "recipe timing" example above does not apply while the freeze holds). Allowed: implementing what Dave approves, validation, tests, and fixing code so it honours the data as written. A catalog problem found in the work (a broken chain, a missing station, a duplicate, a bad name) is **reported** with path and evidence, not fixed in the data.
