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
Never invent a Dave quote or approval. Quote Dave only from his own words, with date and place; label your own reading of them as yours ("coordinator's reading"). A proposal stays PROPOSED until Dave approves it; a quote whose original cannot be found is SOURCE UNVERIFIED and does not block work as a ban. Keep approved design, implemented code and observed checks apart. One authority per topic (`../DOC_MAP.md` routes them): update it in place, remove the contradicting text elsewhere, repair its readers; Git history is the archive. A secondary copy (Library, account skill, project settings) that cannot be confirmed updated is reported SYNC PENDING.

## Rulings: the newest replaces, the old is removed
Dave, 23 Nov 2026: "newer rules override older ideas"; 25 Nov 2026: "we need a system that removes old contradictory rules when new rules are established". `../RULINGS.md` holds one live line per subject, and that line beats older text anywhere. Whoever records a ruling (a thread, or the coordinator through a thread) does it in one PR: replace the subject's line, never add a second; change or delete every active line in designs, data notes, comments, tests and the bug list that still states the old rule; add the old rule's telltale phrase to `../retired_rules.json`; add or change the check that guards the ruling (a plain-number check in `tools/check_dave_rules.py`, or a Godot test named there); a check that fails on `dev` is a found bug, reported to the coordinator, never a check to loosen; run `python3 tools/check_rulings.py` (also run by `merge_check.py`). Git history is the archive: no "superseded" or struck-through text stays in active docs. Two rulings that conflict with no clear order go to the coordinator, who asks Dave.

**Rules and suggestions.** Dave, 26 Nov 2026: "Only explicit rules where I say don't do something or lock something in are rules. everything else are suggestions"; "make it correct according to playtesting not according my old rules. its ok if playtesting finds that my rules were not right." Each line in `../RULINGS.md` is marked rule, suggestion or unclear (the threads' and coordinator's reading of his words). Coordinator's reading, not Dave's words: a rule is never overridden by a thread; if play-testing shows one wrong, the finding goes to the coordinator, who asks Dave. A suggestion is the starting point: when play-testing shows something better, make the game correct, change the suggestion's line and its check by the procedure above in the same PR, and report the finding to the coordinator. An unclear line counts as a rule until the coordinator settles it. The checks block on rules and unclear lines and only note suggestions; a rule's mark changes only with a new dated line in his words (`tools/merge_check.py` fails a rule softened on the same date).

Testing on Dave's PC: R-TEAM-LANE-C-DRIVE (full rule in `TEST_GATES.md`, "Environment constraints").

## Standing authorizations and scoped holds
Task-specific holds remain limited to their stated scope. Dave approves substantive amendments to authority or creative policy; status, typo and pointer fixes proceed under existing delegation with proportionate review. Independent review and release requirements are owned by `TEST_GATES.md`.

**Water:** Dave, 11 Nov 2026, delegated technical water decisions without ongoing questions; his observations can lead to later fixes. This does not expand authority into other systems, game vision, deletion of backups or platform restrictions.


## Catalog control and scoped delegation

**Standing ruling, DIRECTOR-APPROVED:** Dave, 11 Nov 2026, project thread "Make Admin Mode off by default": "Freeze all discretionary additions, removals, renames, and recipe redesigns in the item catalog. ChatGPT and I are going to review and approve the definitive catalog. Claude's job afterward will be implementation, validation, and reporting problems—not independently redesigning the items."

Default scope: items, names, IDs, recipes, ingredients, stations, blueprints and code lists naming them. Implement approved changes, validate and report unrelated catalog problems; do not independently redesign the catalog. Level B refinements are subject to this rule. Later specific approvals and delegated values are permitted within their recorded scope, not evidence that the whole freeze ended.

Scoped delegations (GOALS-REPAIR, WOOD-SYSTEM, goals/rewards) and their limits live in their own records: `missions/GOALS-REPAIR/REPAIR_DECISIONS.md` and `missions/WOOD-SYSTEM/STATE.md`. A scoped delegation does not turn every coordinator assumption into a Dave approval.
