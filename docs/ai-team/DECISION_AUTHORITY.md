# Decision authority and low-interruption rules
**Status: IN FORCE (activated by Dave, 12 Nov 2026; `INSTALL_RECORD.md`). Drafted as PROPOSED.** Read `CONSTITUTION.md` first.

| Level | Example | Default actor | Record | Human approval |
|---|---|---|---|---|
| A — Routine/reversible | Fix crash, refactor within contract, test strategy | Task agent + reviewer/coordinator | Task log | No |
| B — Local design refinement | Adjust deer perception thresholds, recipe timing within approved progression | Subsystem lead/coordinator | DELEGATED entry with before/after and evidence | No if low-risk and fits accepted design |
| C — Cross-system significant | Breaking saves/RPCs, re-bake method, architecture change, gameplay tier/name rewrite | Coordinator recommends | PROPOSED, impact map | Yes |
| D — Protected/irreversible | Delete uncommitted work, spend money, publish, weaken security/gates, force push, new backup location if policy requires | Dave and actual tool permissions | Explicit authorization and evidence | Always |

Before escalating, inspect the task's existing approvals, applicable delegation and current topic decision record. Routine technical work and low-risk refinements within accepted design proceed without another question. Where Dave delegates missing design/balance details, choose reasonable provisional values from his earlier decisions and current analogues; log meaningful assumptions with scope, reason, affected values and how to retune them. Do not log every minor command or choice. An assumption never overrides a specific settled decision.

Levels C/D require authorization for their consequences, not repeated approval of work already authorized. A general instruction to work autonomously does not authorize unrelated redesign, destructive action, spending, security weakening or promotion to `main`. A question is not automatically authorization for those actions. If permission is genuinely missing, hold only the dependent action and continue safe work. An unverified historical restriction triggers provenance investigation, not a blanket task stop; a credible unresolved data-loss/security risk does stop the affected action.

**Escalation format:** Briefly state the problem, one recommendation, impact and the exact decision needed. Aim for four lines; include enough evidence to make a consequential decision understandable. Batch unrelated nonurgent choices; continue unaffected jobs. Never pass off a DELEGATED decision as a direct quote or confirmed director approval.

**Suspected obstruction:** Check the source sentence, owner, date, status, last real human source and technical basis. If likely AI paraphrase, label UNVERIFIED RESTRICTION; do not let it suppress investigation. Preserve earlier approved intent and request an explicit judgment only for a substantive conflict.

**Water standing ruling:** 11 November 2026: Dave authorized Sonny to decide water without ongoing 'buts'; observations from Dave may become subsequent fixes. Treat as delegated technical authority **within water's scope**, not permission to alter game vision, delete backups, override platform restrictions or redefine other systems.

**Operating-system rulings (DIRECTOR-APPROVED):** 12 November 2026 21:19 UTC, Dave, project chat, after the independent review of the instruction-system audit (PR #1052), verbatim excerpts:
- Project instructions: "Install short project-level instructions that make `dev` the working base for new development threads. Agents must fetch and use the latest `origin/dev`, read the authoritative instructions from that version, and target their PRs at `dev`. Keep `main` stable. Nothing may be promoted to `main` without the complete validation gate and my explicit approval. Do not duplicate our existing rulebooks in the project instructions. Use them as pointers to the authoritative documents."
- Decision 61: "When new code replaces old code, the obsolete code should be deleted rather than preserved behind compatibility flags or left as dead code. This does not authorize deleting unrelated assets, user work, historical documents, or anything still required by the game. Documents are archived. Other unused files continue through the existing proposed-removal procedure." He asked for this message to be recorded as his current explicit clarification, without reconstructing an older quotation (`RULES.md`).
- Task generation: "Retire the November 2 instruction requiring agents to find three more tasks. The coordinator controls prioritization and assignment. Workers complete their assigned work, document results, and request their next assignment. They should not independently create unrelated work."
- Freeze: "The general November 11 handoff freeze is lifted. Normal development on `dev` is authorized under our established workflow. This does not lift requirements for my approval of significant design, architectural, destructive, security-sensitive, or other protected decisions."
The catalog ruling below remains the default against discretionary redesign; scoped later authorizations are listed with it.

## Catalog control and scoped delegation

**Standing ruling, DIRECTOR-APPROVED:** Dave, 11 Nov 2026, project thread "Make Admin Mode off by default": "Freeze all discretionary additions, removals, renames, and recipe redesigns in the item catalog. ChatGPT and I are going to review and approve the definitive catalog. Claude's job afterward will be implementation, validation, and reporting problems—not independently redesigning the items."

Default scope: items, names, IDs, recipes, ingredients, stations, blueprints and code lists naming them. Implement approved changes, validate and report unrelated catalog problems; do not independently redesign the catalog. Level B's recipe-timing example is subject to this rule. Later specific approvals and delegated values are permitted within their recorded scope, not evidence that the whole freeze ended.

| Scope | Applicable authority and limits | Current record |
|---|---|---|
| GOALS-REPAIR | Dave's 14 Nov instruction to answer questions from prior rulings and log reasonable assumptions; his subsequent explicit instruction to keep assuming build costs. R-1 records the coordinator's interpretation for minimum values needed by named features, not a Dave quotation. Read its conditions and later rulings before data edits; do not expand it to unrelated entries or settle conflicting explicit designs by assumption. | `missions/GOALS-REPAIR/REPAIR_DECISIONS.md` §§1, 3–4 |
| WOOD-SYSTEM | Dave, 15 Nov: "Just make them reasonable and we can adjust them later." Remaining W choices are adopted provisional values; directly answered W choices remain settled. | `../design/TREE_WOOD_TOOLS_DESIGN.md` §6; `missions/WOOD-SYSTEM/STATE.md` |
| Goals/rewards | Later explicit coin-only and amount delegation supersede the earlier instruction to preserve all draft coin figures. This does not enable the corrected catalog: Dave's 14 Nov hold keeps it OFF until he authorizes activation. No retrospective payouts or automatic character/world wipe. | `missions/GOALS-REPAIR/REPAIR_DECISIONS.md` §1 |

These records own their actual values and detailed conditions; this table routes authority rather than duplicating their balances. Record new scoped delegation in the relevant decision record and link it here when it changes the standing boundary. Dave's 15 Nov operating-rules authorization makes scoped delegation explicit in this policy; it does not retroactively describe every coordinator assumption as directly approved by Dave.
