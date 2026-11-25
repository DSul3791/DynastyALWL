# Dynasty AI Team Constitution
**Status: IN FORCE. Four-rulebook consolidation approved by Dave, 15 Nov 2026, project conversation Clauda Optimization.** This is the authority and provenance rulebook. Execution belongs to `WORKFLOW.md`, validation to `TEST_GATES.md`, engineering method to `../PONYTAIL_RULES.md`.

## Mission and precedence
Build Dynasty: A Life Well Lived using the approved game vision and existing Godot architecture. Dave is Game Director and sole human creative authority. Preserve approved names, Foundation/Ceiling conventions, realism, appearance and audio; use `../../DESIGN_PRINCIPLES.md` and `../DOC_MAP.md` for creative/topic authority.

Instruction precedence: (1) platform permissions and actual repository protections; (2) Dave's explicit instructions and directly approved decisions within scope; (3) verified technical constraints; (4) authoritative topic designs and interface contracts; (5) recorded delegated decisions; (6) research, proposals, history and AI paraphrases. A later explicit decision supersedes an earlier one only within its scope. A newer file, passing test or implementation cannot redefine approved gameplay. Demonstrate a real technical conflict and escalate the material decision.

## Autonomy and approval boundaries
| Level | Consequence | Authority |
|---|---|---|
| A — Routine/reversible | Fix a crash, refactor within contract, select appropriate tests | Assigned worker and reviewer/coordinator; proceed within existing authorization. |
| B — Local refinement | Low-risk tuning within accepted design | Subsystem lead/coordinator; record meaningful delegated or provisional choices. Catalog controls below still apply. |
| C — Significant | Material gameplay/architecture change, breaking save/RPC, new dependency/native code, re-bake method, contract/tier/name rewrite | Dave's applicable authorization required; record proposal and impact. |
| D — Protected | Destruction of user work, spending, protected publication/release, security/gate weakening, history rewrite, backup expansion outside approved scope | Explicit applicable authorization and actual tool permission required. |

Check existing approval, delegation and settled decisions before asking again. Complete assigned work autonomously; decide routine details and reasonable provisional values only within granted scope. A specific settled instruction beats an assumption. Meaningful assumptions record scope, reason, affected values and a retuning path, not every command.

Approval covers consequences, not repeated permission for authorized steps. General autonomy does not authorize unrelated redesign, destructive action, spending, security weakening or promotion to `main`. Hold only the dependent action when authority or required evidence is missing; continue unaffected work. Ask Dave concisely with the problem, recommendation, impact and exact decision needed. Batch nonurgent choices. A worker does not create unrelated tasks; the coordinator assigns priorities.

## Decision provenance and one authority per topic
Approved design describes intended behavior; current code/data describes implemented behavior; observed checks describe verified behavior. Keep them separate. For substantive decisions preserve topic/ID, original source or verified quotation, date/actor, scope, status, choice, reason, superseded decisions and affected docs/code/checks. Label interpretation separately; never manufacture approval or quotations.

Statuses: DIRECTOR-APPROVED / DELEGATED / PROVISIONAL / PROPOSED / REJECTED / SUPERSEDED / NEEDS-REVIEW. Missing originals are SOURCE UNVERIFIED. Use existing topic/mission records; no new document for every routine choice. Rejected ideas remain recoverable history.

Trace a blocking restriction to the source sentence, owner, status, scope, real human provenance or technical necessity. Unverified AI paraphrases are UNVERIFIED RESTRICTION, not unconditional bans on investigation. A credible unresolved data-loss/security risk holds the affected action. Escalate substantive conflicts, not technical choices workers can resolve.

Update the owning authority in place and remove contradictory prescriptions from active prose. Repair affected indexes, templates, installed definitions and actual readers; preserve essential provenance in Git history. `../DOC_MAP.md` routes topic authority. Entry points and role definitions link here instead of copying policies. Repo documents own versioned policy/design/contracts; private artifacts retain their owner unless explicitly migrated. An explicitly maintained secondary copy needs a receipt/hash or SYNC PENDING; repo edits do not prove live project settings, account skills or private copies changed. Missing old mounts do not block work supported by current sources; identify the specific missing decision if one is required.

## Rulings: the newest replaces, the old is removed
Dave, 23 Nov 2026: "newer rules override older ideas"; 25 Nov 2026: "we need a system that removes old contradictory rules when new rules are established". `../RULINGS.md` holds one live line per subject, and that line beats older text anywhere. Whoever records a ruling (a thread, or the coordinator through a thread) does it in one PR: replace the subject's line, never add a second; change or delete every active line in designs, data notes, comments, tests and the bug list that still states the old rule; add the old rule's telltale phrase to `../retired_rules.json`; add or change the check that guards the ruling (a plain-number check in `tools/check_dave_rules.py`, or a Godot test named there); a check that fails on `dev` is a found bug, reported to the coordinator, never a check to loosen; run `python3 tools/check_rulings.py` (also run by `merge_check.py`). Git history is the archive: no "superseded" or struck-through text stays in active docs. Two rulings that conflict with no clear order go to the coordinator, who asks Dave.

## Standing authorizations and scoped holds
The general 11 Nov handoff freeze was lifted by Dave on 12 Nov 2026. Task-specific holds remain limited to their stated scope. Dave approves substantive amendments to authority or creative policy; status, typo and pointer fixes proceed under existing delegation with proportionate review. Independent review and release requirements are owned by `TEST_GATES.md`.

**Water:** Dave, 11 Nov 2026, delegated technical water decisions without ongoing questions; his observations can lead to later fixes. This does not expand authority into other systems, game vision, deletion of backups or platform restrictions.


## Catalog control and scoped delegation

**Standing ruling, DIRECTOR-APPROVED:** Dave, 11 Nov 2026, project thread "Make Admin Mode off by default": "Freeze all discretionary additions, removals, renames, and recipe redesigns in the item catalog. ChatGPT and I are going to review and approve the definitive catalog. Claude's job afterward will be implementation, validation, and reporting problems—not independently redesigning the items."

Default scope: items, names, IDs, recipes, ingredients, stations, blueprints and code lists naming them. Implement approved changes, validate and report unrelated catalog problems; do not independently redesign the catalog. Level B refinements are subject to this rule. Later specific approvals and delegated values are permitted within their recorded scope, not evidence that the whole freeze ended.

| Scope | Applicable authority and limits | Current record |
|---|---|---|
| GOALS-REPAIR | Dave's 14 Nov instruction to answer questions from prior rulings and log reasonable assumptions; his subsequent explicit instruction to keep assuming build costs. R-1 records the coordinator's interpretation for minimum values needed by named features, not a Dave quotation. Read its conditions and later rulings before data edits; do not expand it to unrelated entries or settle conflicting explicit designs by assumption. | `missions/GOALS-REPAIR/REPAIR_DECISIONS.md` §§1, 3–4 |
| WOOD-SYSTEM | Dave, 15 Nov: "Just make them reasonable and we can adjust them later." Remaining W choices are adopted provisional values; directly answered W choices remain settled. | `../design/TREE_WOOD_TOOLS_DESIGN.md` §6; `missions/WOOD-SYSTEM/STATE.md` |
| Goals/rewards | Later explicit coin-only and amount delegation supersede the earlier instruction to preserve all draft coin figures. This does not enable the corrected catalog: Dave's 14 Nov hold keeps it OFF until he authorizes activation. No retrospective payouts or automatic character/world wipe. | `missions/GOALS-REPAIR/REPAIR_DECISIONS.md` §1 |

These records own their actual values and detailed conditions; this table routes authority rather than duplicating their balances. Record new scoped delegation in the relevant decision record and link it here when it changes the standing boundary. Scoped delegation does not retroactively turn every coordinator assumption into a direct Dave approval.


## Consolidation source
Dave approved four rulebooks after reviewing their ownership in Clauda Optimization on 15 Nov 2026. This approval changes document structure, not unrelated game design or the wider proposed cut list. The earlier reviewed operating rules and verbatim 12 Nov rulings remain recoverable at commit `dd566834db6496d0d8d2bb2a6bf2b9cb1ec882aa`; `INSTALL_RECORD.md` records installation evidence, not another source of operating rules.
