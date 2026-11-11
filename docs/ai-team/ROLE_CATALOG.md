# Permanent roles, temporary sessions
**Status: PROPOSED. Cowork coordinator remains the human-facing root chat.**

| Role | Existing name | Scope | Default model guidance |
|---|---|---|---|
| Coordinator | Coordinator | Plan, delegate, prioritize, route questions, sync records. Does not code or bless own PR | Sonnet/Opus medium; Fable only when architecture demands it |
| Systems architect | Steve | GDScript systems, contracts, networking, player systems | Opus high for new architecture; Sonnet high for bounded changes |
| Terrain & water lead | Sonny | Geology, hydrology, world bake contracts, water quality | Opus high for difficult design; Sonnet high for implementation |
| Art director | Kathleen | Approved look, scenes, rigs, lighting, visual QA | Sonnet high; escalate expensive reasoning when warranted |
| Gameplay designer | Morgan | Meaningful item/crafting progression, game loop, acceptance scenarios | Opus high for large design, Sonnet high for audits |
| Item data steward | Jamie | Recipe/item IDs, exact names, tier taxonomy, item tools | Sonnet medium/high; code-driven validation |
| Integration gatekeeper | Tyler | Branches, independent review/checks and approval evidence | Sonnet high or Opus medium for critical review |
| PC test runner | Dino | Heavy local Godot runs, bakes only where authorized, screenshots | Sonnet medium; precise steps + machine permissions |
| Backup test runner | David4 | Test plan, gate scripts where feasible (no water bake absent record) | Sonnet medium |
| Chief architecture critic | Spawn per task | Challenge high-risk design and consistency | Opus high or Fable when available |

Roles are jobs, **not permanent living contexts**. Staffing uses only the workers needed. Most active teams need 2-4 workers; the coordinator should not launch every role at once. A specialist retains ownership through files and task tickets, not a continuously growing thread. Use one architect + one implementer + one independent reviewer for high-risk work, not redundant Opus agents debating forever.

The Claude project may be an older Cowork project or a newer one-conversation/multiple-thread project (rollout varies). Detect the actual surface and test what launches/retains context; do not assume model routing, automatic retirement or coordinator replacement work in all variants. Native worker windows are distinct from Claude Code `.claude/agents/*.md`. Treat the latter as *Code* templates only until actual Cowork loading is proven. Model aliases are suggestions, not a guarantee of model entitlement, effort level, or tool access.

Communication: Dave -> Coordinator; Coordinator -> tasks; limited direct peer coordination for precise dependencies. Dave can speak to worker directly; that worker must log substantive changes in shared task state and alert coordinator. Do not elevate casual conversational paraphrases into approved project law.
