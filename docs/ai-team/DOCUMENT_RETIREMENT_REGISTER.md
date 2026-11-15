# Document retirement register

**Status: PROPOSED CUT LIST — no removals executed.** Snapshot: `dev` at `b58ae229589c2df8bdf89a85f246492e19abab3b` (15 Nov 2026). All 1,030 tracked `.md`, `.markdown`, `.txt`, `.rst` and `.adoc` files are listed once, plus 18 structured `.csv`/`.json` documentation and evidence files under docs/ (1,048 total rows). This includes operational text files; it is not a count of human-authored manuals alone. Earlier unpublished cleanup drafts are excluded.

Dave approved a seven-day recovery window and dependency-scoped blocking. This register proposes the cut list. No document is declared retired merely by appearing here; retirement/expiry dates are assigned only after its content/dependency gates pass. No cleanup is executed by this register. Dave's instruction is to finish the plan, review it with him, and only then implement it. Publishing this proposal on a draft branch does not approve the cuts or alter live policy.

## Proposed cut

| Action | Files | Meaning |
|---|---:|---|
| KEEP | 68 | Retain a distinct authority/reference; trim in place. |
| DEPENDENCY | 72 | Retain operational instructions/metadata until reader, package or license obligations are checked. |
| CONSOLIDATE | 199 | Transfer applicable unique material to the named existing destination, repair consumers, then retire the source. |
| RETIRE | 709 | Remove from normal reading after preservation/dependency checks; remove from the current branch after seven days with recoverable Git history. |

These are planning classifications from full-text inventory, contextual topic review and current authority routing. Named destinations are proposed homes after reconciliation, not a claim that their present text already contains the source or is up to date. Multi-topic documents transfer each applicable decision into its owning topic; the listed primary destination is not permission to dump unrelated material into it. A proposed cut is not proof that every historical decision is already preserved. KEEP/DEPENDENCY total 140; that is a provisional destination, not a quota or permission to discard essential content.

## Execution gates

- **Preserve:** compare the source with the target; transfer unique applicable approvals, knowledge and evidence without turning proposals into decisions. Recover unresolved findings into current assigned work and resolve/verify them before advancing the dependent work. Archiving cannot conceal an issue.
- **Repair:** update incoming links, launchers, packaged instructions and actual file readers. Literal source references are investigation leads, not certified reader dependencies. Consolidation targets remain KEEP/DEPENDENCY in this register; no target cycles are permitted.
- **License/attribution:** required notices and provenance remain with the assets wherever distribution terms require them. An expired recovery window never authorizes removing a still-required notice. Keep these rows as DEPENDENCY until the obligation itself ends or an equivalent required notice is correctly retained.
- **Recover:** verify the source blob at this snapshot is retrievable. Every row identifies the baseline commit and blob; Git history is retained, with no history rewriting.
- **Retire then expire:** record the actual retirement timestamp and an expiry exactly seven days later. Exclude the file from routine agent reading immediately. Source age is not proof that its recovery window has elapsed. Delete from the current branch only after expiry and final checks; do not preserve a second permanent archive directory.
- **Review:** independently review the exact change and run relevant static/tool checks. The existing archive-only checker and its documentation must be updated together to encode Dave's new seven-day/history policy before expiry deletions. Missing evidence holds the affected batch, not unrelated work.

## Batch order

1. Consolidate the policy needed to implement seven-day retirement, adapt/check its enforcement and establish the short active reading list.
2. Verify and retire old archive/mirror copies, obsolete install packages and dated personal handoffs. Start each actual seven-day window; do not infer dates.
3. Consolidate completed mission paperwork and superseded guides into current decisions/state/evidence. Preserve reproducibility or update dependent tools as a unit.
4. Consolidate overlapping feature/research pages by the targets below. Preserve approved-but-unimplemented designs and explicit rejected ideas.
5. After each batch's seven-day expiry, verify recovery and references, then remove expired copies from the current branch. Recount the remaining maintained set.

The register is temporary execution material, not a new permanent rulebook. Keep it while the cleanup is active; consolidate its essential recovery receipts into the final retirement record, then apply the same retirement policy to it.

## Implementation specification for review

**Scope and ownership:** one cleanup lead owns the inventory, source-to-target reconciliation and each focused PR to `dev`; an independent reviewer checks the exact proposed tree and receipts. Do not modify `main`, gameplay/data behavior, code-removal rules or asset distribution obligations as part of documentation cleanup. Dave reviews this proposal before implementation begins. Merge this planning file only if useful; its publication alone starts nothing.

**Small reading set:** retain `README.md` as the short human entry point and `CLAUDE.md` as the agent entry point, both pointing into `docs/DOC_MAP.md`. Keep operating authority in `CONSTITUTION.md`, `DECISION_AUTHORITY.md`, `WORKFLOW.md` and `TEST_GATES.md` under `docs/ai-team/`. Read specialist references, mission records and installed roles/skills only when relevant. Navigation points to authority instead of restating its rules. Paramount design/art/catalog authorities remain separately maintained because their subjects differ.

**Batch 1 change set:** reconcile the archival rule in the authority/workflow/map and installed/package readers; update `tools/deletion_rules.py`, `tools/test_deletion_rules.py` and any reader of `proposed_removals/REMOVALS.md` together. Add a separate, strictly parsed document-retirement section to that existing ledger, preserving its current code-removal sections. Do not create another permanent policy manual or daily audit report. Use one row per file with original path, source commit/blob, preserved target/section or justified history-only disposition, actual-reader check, issue/verification receipt, retirement merge commit, UTC retirement/expiry times, and deletion commit when complete. Never infer completion from this proposal's action column.

**Time and recovery:** retirement becomes effective only when the reviewed retirement change is merged into `dev`; derive its UTC time from that merge's recorded integration event, and verify the ledger against that event. Expiry is retirement plus 168 hours. If ledger finalization follows the merge, calculate from the actual event rather than silently resetting the window. Retired material can stay at its existing path or be moved once to the existing archive area during the window, explicitly marked historical and excluded from all routine reading indexes. Preserve the exact pre-retirement blob before adding any historical banner. At deletion, verify both baseline and last pre-retirement content against reachable history; a changed source needs renewed reconciliation. Recovery command: `git show <source-commit>:<original-path> > <restore-path>` followed by a blob/content check. Do not restore directly over current authority without comparison.

**Expiry execution:** after approval of the implementation plan, add a daily GitHub Actions run with manual dispatch that prepares/updates a focused expiry PR for eligible rows. The same validation runs in the existing merge guard; merge requires independent review and passing checks. No direct scheduled deletion on `dev`, guessed historical retirement dates, blanket directory exemptions or bypass flags. A failed recovery/reader/license check retains that file and blocks its dependent work until resolved; unaffected eligible rows can proceed. Seven days is the recovery period, not a promise to delete still-required material. The expiry job must expose held rows in its failing check output, without generating another standing report document.

**Acceptance tests:** the retirement validator must reject missing/malformed receipts, fabricated integration events, future retirement timestamps, deletion before 168 hours, changed source blobs, unreachable recovery commits, missing preservation targets, stale actual readers and required notices. A future expiry is valid during recovery when it equals verified retirement plus 168 hours. It must accept a fully evidenced expired retirement and leave unrelated code/asset safeguards intact. Check dynamic path construction and directory/package scans manually as well as literal references. Compare stable item/goal IDs and structured evidence unchanged unless a separately approved technical migration requires edits. Run `python3 -I tools/test_deletion_rules.py`, `python3 -I tools/check_ai_team_package.py`, `MERGE_CHECK_BASE=origin/dev python3 tools/merge_check.py`, targeted reader/package tests, a scoped link check and `git diff --check` on each batch. Godot/player checks apply only if a genuine runtime dependency is changed; no gameplay verification claim follows from static checks.

**Refresh and stop:** before the first implementation batch, fetch current `dev`, compare every proposed source blob with this baseline, add newly introduced documents and reclassify changed/deleted sources. Compare the resulting tree with the reviewed cut, not an unpublished cleanup draft. A batch is complete only when preservation, verified issue disposition, reader repair, recovery, review and checks have receipts. The cleanup is complete when all 1,048 baseline rows and new arrivals are reconciled, eligible expired copies are removed, and the remaining maintained files have one purpose and an owner. Retain only compact recovery receipts in the existing ledger, retire this temporary register, and use Git history for old narratives. Further consolidation stops when it would combine unrelated authorities, erase useful provenance, or increase reading/maintenance cost more than it reduces duplication.

## Full cut list

Classifications: Paramount = core intent/authority/navigation; Necessary = contracts/operations/current work; Helpful = distinctive explanations/evidence; Nice to have = optional research/critique; Dead weight in checkout = superseded/frozen material occupying today's tree. These labels concern present placement, not whether historical user decisions matter.

For any row, recover the original at `https://github.com/DSul3791/DynastyALWL/blob/b58ae229589c2df8bdf89a85f246492e19abab3b/<path>`. The blob SHA is the content identity. No retirement or expiry date has started for this proposed list.

| ID | Class | Action | Document | Existing destination / recovery | Literal refs | Source blob |
|---|---|---|---|---|---:|---|
| DOC-0001 | Necessary | DEPENDENCY | `.claude/agents/art-reviewer.md` | `.claude/agents/art-reviewer.md` | 0 | `fafc931bf38b9a07d77027bdc43019c16851958f` |
| DOC-0002 | Necessary | DEPENDENCY | `.claude/agents/doc-steward.md` | `.claude/agents/doc-steward.md` | 0 | `cdaf297dc6d0723b274342c49764c99d4694a36f` |
| DOC-0003 | Necessary | DEPENDENCY | `.claude/agents/gameplay-designer.md` | `.claude/agents/gameplay-designer.md` | 0 | `fa5d5648fcf43908bca02d1f1c556dadd81ee665` |
| DOC-0004 | Necessary | DEPENDENCY | `.claude/agents/gate-reviewer.md` | `.claude/agents/gate-reviewer.md` | 1 | `3c15ca2a018c69fb5d3b37420a19437fe3908bb0` |
| DOC-0005 | Necessary | DEPENDENCY | `.claude/agents/item-data.md` | `.claude/agents/item-data.md` | 0 | `77f39a4ec37b56550cdf247c36546b9e994d464a` |
| DOC-0006 | Necessary | DEPENDENCY | `.claude/agents/systems-engineer.md` | `.claude/agents/systems-engineer.md` | 0 | `6d1cd04362947e14081574d5372edf2ddfea8ad3` |
| DOC-0007 | Necessary | DEPENDENCY | `.claude/agents/task-investigator.md` | `.claude/agents/task-investigator.md` | 0 | `94621e981b1c4533323a40476b3043af67b7647d` |
| DOC-0008 | Necessary | DEPENDENCY | `.claude/agents/terrain-water.md` | `.claude/agents/terrain-water.md` | 0 | `c9ef9c079d505a7e422832f783a33f3839ab80ce` |
| DOC-0009 | Necessary | DEPENDENCY | `.claude/skills/bug-investigation/SKILL.md` | `.claude/skills/bug-investigation/SKILL.md` | 0 | `25d59589a6634278c72caf59052e7c1fa3c2e479` |
| DOC-0010 | Necessary | DEPENDENCY | `.claude/skills/decision-provenance/SKILL.md` | `.claude/skills/decision-provenance/SKILL.md` | 0 | `01877449931cf2453bb78c0ac67aa68675a6aa4a` |
| DOC-0011 | Necessary | DEPENDENCY | `.claude/skills/documentation-sync/SKILL.md` | `.claude/skills/documentation-sync/SKILL.md` | 0 | `8c4bdd561077195b89d981d7db96d9b5688322de` |
| DOC-0012 | Necessary | DEPENDENCY | `.claude/skills/merge-validation/SKILL.md` | `.claude/skills/merge-validation/SKILL.md` | 0 | `a201ff6050c65b0708072f82be3158cd5fb8a80c` |
| DOC-0013 | Necessary | DEPENDENCY | `.claude/skills/nightly-dev-checkpoint/SKILL.md` | `.claude/skills/nightly-dev-checkpoint/SKILL.md` | 1 | `97860532ee9ed22ab2852762f60b549955cacfaf` |
| DOC-0014 | Necessary | DEPENDENCY | `.claude/skills/ponytail-audit/SKILL.md` | `.claude/skills/ponytail-audit/SKILL.md` | 0 | `67507986ab0f9d618599ae36dc5db0ce2083a82b` |
| DOC-0015 | Necessary | DEPENDENCY | `.claude/skills/ponytail-debt/SKILL.md` | `.claude/skills/ponytail-debt/SKILL.md` | 0 | `4644da02236b73f4fd0c456d72fc132a69df13dd` |
| DOC-0016 | Necessary | DEPENDENCY | `.claude/skills/ponytail-review/SKILL.md` | `.claude/skills/ponytail-review/SKILL.md` | 0 | `e0db31ea9d241d9c9d168dd11abe3959c51e5aa5` |
| DOC-0017 | Necessary | DEPENDENCY | `.claude/skills/session-handoff/SKILL.md` | `.claude/skills/session-handoff/SKILL.md` | 0 | `a1f0abc4b65443b379b54f52e2d1aa0eb9361a8f` |
| DOC-0018 | Necessary | DEPENDENCY | `.claude/skills/task-intake/SKILL.md` | `.claude/skills/task-intake/SKILL.md` | 0 | `36c705e984fcc04bb2c777495e61eeab4d682dee` |
| DOC-0019 | Helpful | CONSOLIDATE | `ANIMAL_PRODUCTS.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `c7985f14001a9932115cfa8665436d2cec3032cb` |
| DOC-0020 | Helpful | KEEP | `ANIMAL_SPEC.md` | `ANIMAL_SPEC.md` | 0 | `f3e13a19ae7ee41ec05dcc6b29e087b89535cfd6` |
| DOC-0021 | Necessary | KEEP | `ARCHITECTURE_BUDGET.md` | `ARCHITECTURE_BUDGET.md` | 0 | `7304fa427ffd80d189e4f03a4b1f9f2b050c16db` |
| DOC-0022 | Dead weight in checkout | RETIRE | `ART_ASSET_INVENTORY.md` | `art/Art_Direction.md` | 0 | `34b0d8312140cfbccf40d519c8e7ea0ece11aee8` |
| DOC-0023 | Necessary | CONSOLIDATE | `ART_DIRECTION.md` | `art/Art_Direction.md` | 0 | `b9a21fde1e4b9c9a4b41fba907c5e8712c705836` |
| DOC-0024 | Dead weight in checkout | RETIRE | `AUDIT_ITEMS.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `b0589f24643a296090ab418a3321520e496374a8` |
| DOC-0025 | Dead weight in checkout | RETIRE | `BALANCE_SHEET.md` | `ECONOMY_PLAN.md` | 0 | `2193e7772c50ede8da767d3b8b8c531e7b74a8d5` |
| DOC-0026 | Necessary | CONSOLIDATE | `BIG_PICTURE.md` | `DESIGN_IDEAS.md` | 0 | `9db95a365813b03e7ae42675b7c78a0a0fdabc24` |
| DOC-0027 | Dead weight in checkout | RETIRE | `BUILD_ORDERS.md` | `docs/design/progression.md` | 0 | `ac419a4dde98fc749af265d9f5082338ae430d0a` |
| DOC-0028 | Helpful | CONSOLIDATE | `CHARACTER_DESIGN_VISION.md` | `docs/DYNASTY_BODY.md` | 0 | `4fd54e3d6a8d0301180d6d84f303dc52bb3e36b1` |
| DOC-0029 | Paramount | KEEP | `CLAUDE.md` | `CLAUDE.md` | 1 | `d5013897d317500263c898de8ca2f9c15cac63ad` |
| DOC-0030 | Dead weight in checkout | RETIRE | `CLOTHING_WARMTH.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `989dbfdf7404bb97d741ebaa69630c0956ef1372` |
| DOC-0031 | Dead weight in checkout | RETIRE | `CODE_MISMATCHES.md` | `docs/ai-team/TEST_GATES.md` | 0 | `cd1b69913cb1133c6e045ee179e61ffb09fa540d` |
| DOC-0032 | Necessary | KEEP | `CONTROLS.md` | `CONTROLS.md` | 2 | `2c42f3ade5b3b0ce81ae1e10273f50b2a15dacee` |
| DOC-0033 | Dead weight in checkout | RETIRE | `CRAFT_PACING.md` | `ECONOMY_PLAN.md` | 0 | `b59c4462d6567f8c5a9aeaf18eba1ba6eaeca1de` |
| DOC-0034 | Helpful | KEEP | `DESIGN_IDEAS.md` | `DESIGN_IDEAS.md` | 0 | `2cbfa8f6d2a4ef6fcc6ebd475d41c07405920750` |
| DOC-0035 | Paramount | KEEP | `DESIGN_PRINCIPLES.md` | `DESIGN_PRINCIPLES.md` | 0 | `45d3ae4b170851cfe09c7cfc224a4e11b017a848` |
| DOC-0036 | Paramount | KEEP | `DESIGN_REJECTED.md` | `DESIGN_REJECTED.md` | 0 | `6767b89436073d259394182cb397da9b84756fa5` |
| DOC-0037 | Helpful | KEEP | `DIGGING_DESIGN.md` | `DIGGING_DESIGN.md` | 0 | `79f7b906002c44930fa511aa865ec5488f4ce1dd` |
| DOC-0038 | Helpful | KEEP | `ECONOMY_PLAN.md` | `ECONOMY_PLAN.md` | 0 | `f762ecbf7104631c5dad1de67ee9687079137e03` |
| DOC-0039 | Dead weight in checkout | RETIRE | `FARMING_SPEC.md` | `docs/design/HOE_GARDENING_DESIGN.md` | 0 | `ba924ddccaeda213f5f97beef2388c6269d244f1` |
| DOC-0040 | Helpful | CONSOLIDATE | `FAUNA_BY_BIOME.md` | `ANIMAL_SPEC.md` | 0 | `6ec7c3420271d2a47b43cc262fe6810c594e5cd3` |
| DOC-0041 | Helpful | CONSOLIDATE | `FAUNA_SPAWN_PLAN.md` | `ANIMAL_SPEC.md` | 0 | `446679549d1ddaac3976ad48dfeed4339adcb959` |
| DOC-0042 | Dead weight in checkout | RETIRE | `FELLING_DESIGN.md` | `docs/design/TREE_WOOD_TOOLS_DESIGN.md` | 0 | `0a74ad66636e020c0d6643dc01068e5a7ca276ac` |
| DOC-0043 | Necessary | DEPENDENCY | `FIRST_DAY_GUIDE.md` | `FIRST_DAY_GUIDE.md` | 1 | `23e1e63b833461811fa676b6eb0fee81a2a83159` |
| DOC-0044 | Necessary | DEPENDENCY | `FIRST_HOUR_FOOD.md` | `FIRST_HOUR_FOOD.md` | 1 | `906247740f5c0dc9d6bb871e97bb8329dc85d598` |
| DOC-0045 | Dead weight in checkout | RETIRE | `FIRST_WEEK_WALK.md` | `docs/design/progression.md` | 0 | `8949fcef0dfc211907477d91f5d9652385c2c80f` |
| DOC-0046 | Helpful | CONSOLIDATE | `FISHING_DATA.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `656d0bc69ddaf06e8730bede9844469db41bad0f` |
| DOC-0047 | Dead weight in checkout | RETIRE | `FLINT_ORE_SPEC.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `43a8b56e423eba5409db9303db9aa1ceff5ccd30` |
| DOC-0048 | Dead weight in checkout | RETIRE | `FOOD_VARIETY.md` | `docs/design/FOOD_PREPARATION_PRESERVATION_SERVING.md` | 0 | `038e8076683a30e23089a256a8ba7f43359a91fa` |
| DOC-0049 | Helpful | CONSOLIDATE | `FRUIT_TREES.md` | `docs/design/HOE_GARDENING_DESIGN.md` | 0 | `3451466c5fca996e8bbe779a02da83c03865bbbe` |
| DOC-0050 | Dead weight in checkout | RETIRE | `FURNITURE_BALANCE.md` | `ECONOMY_PLAN.md` | 0 | `84b14c5baca1cd30ed4e2812e9e431964e9339c3` |
| DOC-0051 | Dead weight in checkout | RETIRE | `GAP_PLANS.md` | `docs/design/progression.md` | 0 | `b56cd1f1e7a2da9ef58862e91ff8c566ba55efb0` |
| DOC-0052 | Dead weight in checkout | RETIRE | `GENERATION_GUIDE.md` | `docs/water/watershed_rebuild_design.md` | 0 | `24bd683a781a4b91a9c025b025cb78f317267152` |
| DOC-0053 | Helpful | CONSOLIDATE | `GENERATOR_NOTES.md` | `docs/water/watershed_rebuild_design.md` | 0 | `883572a52d6c5ee18c9734d7329c206ba378e7a5` |
| DOC-0054 | Helpful | KEEP | `GENERATOR_VISION.md` | `GENERATOR_VISION.md` | 0 | `ffcdc2e39125eee584eb1cca26bf208983f36e37` |
| DOC-0055 | Dead weight in checkout | RETIRE | `GUIDE_TASKS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `52c234e12765c8b3f8d2c742463da589624fce84` |
| DOC-0056 | Necessary | CONSOLIDATE | `HANDOFF.md` | `docs/ai-team/WORKFLOW.md` | 0 | `a497044c5ba5aefaa218bb2465a6286a6ddac5e1` |
| DOC-0057 | Dead weight in checkout | RETIRE | `HINTS_AND_CAMP_EVENTS_SPEC.md` | `docs/design/PLAYER_JOURNAL_GOALS_UI.md` | 0 | `09acf259fac6bbafa756533cd92a77f75dcd3ab0` |
| DOC-0058 | Dead weight in checkout | RETIRE | `INSTALL_README.txt` | `docs/ai-team/WORKFLOW.md` | 0 | `aa5eb5c91263663ad2767624cb2fa3dfe83f0202` |
| DOC-0059 | Dead weight in checkout | RETIRE | `ITEMS_DESIGN.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `182f8b63c0bb33fb6840035fd63520d837f9ad95` |
| DOC-0060 | Dead weight in checkout | RETIRE | `ITEM_ART_REQUESTS.md` | `art/Art_Direction.md` | 0 | `3aaae78eb47d492bb224bf53cb39c9c9bae48119` |
| DOC-0061 | Dead weight in checkout | RETIRE | `ITEM_CHANGES_SUMMARY.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `26c52d8afbcc512989161fd4306749f7897e8d87` |
| DOC-0062 | Dead weight in checkout | RETIRE | `ITEM_COMBAT_TIER_LIST.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `62b0cc3be221817fe4f0746f514c2fbda9734b40` |
| DOC-0063 | Dead weight in checkout | RETIRE | `ITEM_DECISION_LOG.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `ba30568b1b1162ebc108f4b92e9934055291a7f6` |
| DOC-0064 | Dead weight in checkout | RETIRE | `ITEM_FARMING_GAP_CHECK.md` | `docs/design/HOE_GARDENING_DESIGN.md` | 0 | `19a1e1c06f89fa71957212f1c7bbd079774929a2` |
| DOC-0065 | Dead weight in checkout | RETIRE | `ITEM_GLOSSARY.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `ba552a28a3f91c54686e641028cc9b8b70707ed9` |
| DOC-0066 | Dead weight in checkout | RETIRE | `ITEM_GROUPS_AND_NAMES.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `f18514c6890512f6aa55d07d7367db6efb443afb` |
| DOC-0067 | Dead weight in checkout | RETIRE | `ITEM_TIER_BALANCE.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `9c7b9ba99657c43d8d203fcb66804f4261e58786` |
| DOC-0068 | Dead weight in checkout | RETIRE | `LEARN_SYSTEM_SPEC.md` | `docs/design/progression.md` | 0 | `7eb3d8b0a3ded13076a518cb254b0a641371a03a` |
| DOC-0069 | Dead weight in checkout | RETIRE | `LOG_SPECIES_SPEC.md` | `docs/design/TREE_WOOD_TOOLS_DESIGN.md` | 0 | `d2cf04f37c7803e719ab9a0371cab3d1f8fe5480` |
| DOC-0070 | Helpful | CONSOLIDATE | `MEDICINE_CHAIN.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `0cca6f0024bc8dd765fd8a977785b85e8eaca0d5` |
| DOC-0071 | Helpful | CONSOLIDATE | `MODERATOR_QA_LOG.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `4feb72bfae398fa05fe12fab86ad772972054fa6` |
| DOC-0072 | Necessary | CONSOLIDATE | `MORNING_PLAYTEST_CHECKLIST.md` | `docs/design/PLAYER_PROGRESSION_REPAIR_F6.md` | 1 | `83c6048abdbb811a7886fbd0beb5edf546ca295d` |
| DOC-0073 | Dead weight in checkout | RETIRE | `PLAYTHROUGH_BUDGET.md` | `ECONOMY_PLAN.md` | 0 | `42f170d0110c116d199c25e6a93d46ec6731f1f0` |
| DOC-0074 | Dead weight in checkout | RETIRE | `PLAYTHROUGH_CHAPTERS.md` | `docs/design/progression.md` | 0 | `154d6ca00bf41c644e7abf77bd131e58d901a45e` |
| DOC-0075 | Dead weight in checkout | RETIRE | `PLAYTHROUGH_FINDINGS.md` | `docs/design/progression.md` | 0 | `cd4d0d286ed95094b4298616ae5ec6e7a231d536` |
| DOC-0076 | Necessary | DEPENDENCY | `PLAYTHROUGH_GUIDE.md` | `PLAYTHROUGH_GUIDE.md` | 1 | `2bc197cfee83f908cedd0af68646cb0d61a22739` |
| DOC-0077 | Dead weight in checkout | RETIRE | `PLAYTHROUGH_STATUS.md` | `docs/design/progression.md` | 0 | `9c88c11ce58790c293a5135b4d46e4167e84123b` |
| DOC-0078 | Dead weight in checkout | RETIRE | `PLAYTHROUGH_STEP_STATUS.md` | `docs/design/progression.md` | 0 | `f8e8aea931ba52a9ca523728715eb793364e8371` |
| DOC-0079 | Dead weight in checkout | RETIRE | `PLAYTHROUGH_WILDLIFE.md` | `ANIMAL_SPEC.md` | 0 | `4f8235c44f0bca9f15e2be74c2e42c757c4e68a1` |
| DOC-0080 | Helpful | CONSOLIDATE | `PROJECT_ROADMAP.md` | `DESIGN_IDEAS.md` | 0 | `f2c117135dd48e5b5c8205975c4ff2c0e68c871d` |
| DOC-0081 | Necessary | KEEP | `PROTOCOL.md` | `PROTOCOL.md` | 1 | `a7823b42837894134eb0a9a183a2b103d9834e64` |
| DOC-0082 | Helpful | CONSOLIDATE | `QUALITY_GRADES_SPEC.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `df684fabf53904c95ab16f1d824e12725ddd340b` |
| DOC-0083 | Necessary | KEEP | `README.md` | `README.md` | 1 | `f1a98154233329691dcca9fa664fda9c332c9b98` |
| DOC-0084 | Necessary | CONSOLIDATE | `RULES.md` | `docs/ai-team/WORKFLOW.md` | 2 | `e4b80e5f85b8f5a6c76c40bb6e49845212b98f5c` |
| DOC-0085 | Helpful | CONSOLIDATE | `SCALING_PLAN.md` | `ARCHITECTURE_BUDGET.md` | 0 | `be62d35e083f73306dcc452c5a3ccc1db458150d` |
| DOC-0086 | Helpful | CONSOLIDATE | `SEASONALITY_WINTER.md` | `ECONOMY_PLAN.md` | 0 | `f601f39c5979f3759c11c4ef7528a4eb2a0bb9a8` |
| DOC-0087 | Dead weight in checkout | RETIRE | `SOUND_AUDIT.md` | `docs/design/sound_outdoors_design.md` | 0 | `1bcdd83fca0938abad95294916cabed408531e29` |
| DOC-0088 | Necessary | DEPENDENCY | `TARGETS.md` | `TARGETS.md` | 1 | `4f0a505fcb0954de12e5142ff352f938427605e5` |
| DOC-0089 | Helpful | CONSOLIDATE | `TOWN_NPC_SPEC.md` | `ECONOMY_PLAN.md` | 0 | `4221dc49a6b9c21c8d86c45299b2d69f49a04ab7` |
| DOC-0090 | Necessary | DEPENDENCY | `TUTORIAL_FIRST_30_MIN.md` | `TUTORIAL_FIRST_30_MIN.md` | 1 | `66161f8feccaeb4887d8917d5989afa2a8df67b0` |
| DOC-0091 | Dead weight in checkout | RETIRE | `TYLER_TEST_SYSTEM_REVIEW.md` | `docs/ai-team/TEST_GATES.md` | 0 | `5f807edf156901e2d0c57d7208b42ccd145510f6` |
| DOC-0092 | Dead weight in checkout | RETIRE | `WATER_GATHER_SPEC.md` | `docs/design/drinking_water_design.md` | 0 | `2eb804be7892f503f1286cafaacb41c72a0ef826` |
| DOC-0093 | Necessary | DEPENDENCY | `WORLD_ALIVE_LOG.md` | `WORLD_ALIVE_LOG.md` | 1 | `9a7587f0666e698eb4dd9a763a08f86d5d68719b` |
| DOC-0094 | Necessary | KEEP | `WORLD_FORMAT_SPEC.md` | `WORLD_FORMAT_SPEC.md` | 0 | `b692c9ecd5fe2347efa08c2ba74ea0b6e1753285` |
| DOC-0095 | Nice to have | CONSOLIDATE | `art/ART_TASKS.md` | `art/Art_Direction.md` | 0 | `7486966bfe7f64b5632bed26683dd4bfe01512f2` |
| DOC-0096 | Paramount | KEEP | `art/Art_Direction.md` | `art/Art_Direction.md` | 0 | `dfd41979a1fd9fa574373eaa01fe9423b5745fb8` |
| DOC-0097 | Nice to have | CONSOLIDATE | `art/BUILDING_PLAN.md` | `docs/design/buildables_plan.md` | 0 | `6bd861be4127d3fa29bd4f65a97d213ef5974c02` |
| DOC-0098 | Nice to have | CONSOLIDATE | `art/BUILDING_TIERS_LOOKS.md` | `docs/design/buildables_plan.md` | 0 | `fdc02c5032bd0dd7cf570d16fe5ec093e3827814` |
| DOC-0099 | Nice to have | CONSOLIDATE | `art/BUILDING_TIERS_PLAN.md` | `docs/design/buildables_plan.md` | 0 | `d50ce8712b85450338df36611e2b96bd5a68f3de` |
| DOC-0100 | Nice to have | RETIRE | `art/CRITIQUES/_archive/leanto_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `afd725eaa4b528ec2fb6bc0e01fe23e71e38acc2` |
| DOC-0101 | Nice to have | RETIRE | `art/CRITIQUES/_archive/leanto_2026-10-31/R6_README.md` | `Git history` | 0 | `ed1abf93c98eec5f77bf743097005712456d0f82` |
| DOC-0102 | Nice to have | RETIRE | `art/CRITIQUES/_archive/leanto_2026-10-31/README.md` | `Git history` | 0 | `40627dff8fd12217ab6af41fc925560459238904` |
| DOC-0103 | Nice to have | RETIRE | `art/CRITIQUES/_archive/meadow_flowers_2026-10-31/README.md` | `Git history` | 0 | `b203e79ea536dd5727adcbd00591d4107edc07bf` |
| DOC-0104 | Nice to have | RETIRE | `art/CRITIQUES/animal_parts_shore_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `43db20a30a2def78e1c61dcea5863ca410fd08b8` |
| DOC-0105 | Nice to have | RETIRE | `art/CRITIQUES/animal_sheets_2026-11-02/RATINGS.md` | `Git history` | 0 | `becdfc19b61dcbc2379fcf41d6fd2f2db52e9c72` |
| DOC-0106 | Nice to have | RETIRE | `art/CRITIQUES/animals_pr64_2026-11-02/CRITIQUE.md` | `Git history` | 0 | `004cae2b2a525d65f30d98fff0ba2574d7a82d88` |
| DOC-0107 | Nice to have | RETIRE | `art/CRITIQUES/animals_review_2026-11-02/README.md` | `Git history` | 0 | `f1c35828d1aac09d03bf4a8306d24d8f98c4d3dc` |
| DOC-0108 | Nice to have | RETIRE | `art/CRITIQUES/apples_2026-10-31/README.md` | `Git history` | 0 | `4084593d24f888e7c366bca4937ef760aa25e8bb` |
| DOC-0109 | Nice to have | RETIRE | `art/CRITIQUES/armour_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `8dea01e07e047fa4ba472a6f195f3d69946df2a2` |
| DOC-0110 | Nice to have | RETIRE | `art/CRITIQUES/armour_worn/README.md` | `Git history` | 0 | `c51641b54e05431de16fa759363d95bf1a807780` |
| DOC-0111 | Nice to have | RETIRE | `art/CRITIQUES/beach_props_2026-10-31/README.md` | `Git history` | 0 | `d22e7f896159fc2bfbea883cc335663d74fd6ef6` |
| DOC-0112 | Nice to have | RETIRE | `art/CRITIQUES/bedding_2026-10-30/CRITIQUE.md` | `Git history` | 0 | `0983e50e035e8f89387353a72831c94d20396616` |
| DOC-0113 | Nice to have | RETIRE | `art/CRITIQUES/body_details_2026-11-01/README.md` | `Git history` | 0 | `8369c3c1e4db39a0db02e4dafc84c2030d53e898` |
| DOC-0114 | Nice to have | RETIRE | `art/CRITIQUES/bronze_tools_2026-10-31/README.md` | `Git history` | 0 | `ef521fb391fa1d3b653ed895d02f8ae14bc950dd` |
| DOC-0115 | Nice to have | RETIRE | `art/CRITIQUES/comfort_2026-10-31/README.md` | `Git history` | 0 | `db76e343ed9607d3bc9fb181a64eed210d535b99` |
| DOC-0116 | Nice to have | RETIRE | `art/CRITIQUES/craftables_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `f4c066f1a5223fe8d62397fa5be099194f272aaf` |
| DOC-0117 | Nice to have | RETIRE | `art/CRITIQUES/creator_2026-11-01/README.md` | `Git history` | 0 | `74b8748072c76f59fcf13f810b5cbf13f80927a8` |
| DOC-0118 | Nice to have | RETIRE | `art/CRITIQUES/crops_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `b07e1eae3be8cf97208620c2d345316c44784f2f` |
| DOC-0119 | Nice to have | RETIRE | `art/CRITIQUES/crown_variety_2026-10-31/README.md` | `Git history` | 0 | `47ec1ff7e0574f2a1d277b1010d268fa5303b2fb` |
| DOC-0120 | Nice to have | RETIRE | `art/CRITIQUES/dynasty_base_male_2026-11-01/clip_stats.md` | `Git history` | 0 | `facd28c060912b2c9fba4eee3a9a28721d0ee909` |
| DOC-0121 | Nice to have | RETIRE | `art/CRITIQUES/dynasty_base_male_2026-11-01/clip_stats_98.md` | `Git history` | 0 | `61d064b7da1a3e9cd39c7cac9103298b1af1cf73` |
| DOC-0122 | Nice to have | RETIRE | `art/CRITIQUES/fauna_2026-10-30/CRITIQUE.md` | `Git history` | 0 | `9c4418aef0091e08f8574938320b2ae41ab685b8` |
| DOC-0123 | Nice to have | RETIRE | `art/CRITIQUES/felled_bark_2026-10-31/README.md` | `Git history` | 0 | `ae01f42b7c78e7aba433ddb9c427489fbbceecba` |
| DOC-0124 | Nice to have | RETIRE | `art/CRITIQUES/fibre_cloth_2026-10-31/README.md` | `Git history` | 0 | `305ab53fe802a4cc230ad93780abdf493f38bd76` |
| DOC-0125 | Nice to have | RETIRE | `art/CRITIQUES/fire_light_2026-10-31/README.md` | `Git history` | 0 | `5acc3a4fe2b3948eef30b29b935910e9f5c17abd` |
| DOC-0126 | Nice to have | RETIRE | `art/CRITIQUES/forest_floor_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `86ba925b27f45c1337c11f889222fcd41f6ea00d` |
| DOC-0127 | Nice to have | RETIRE | `art/CRITIQUES/forge_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `5ae8e4ed949a5c5e01673f92d10aa48767ed7bfc` |
| DOC-0128 | Nice to have | RETIRE | `art/CRITIQUES/fruit_trees_2026-10-31/README.md` | `Git history` | 0 | `c48d300c627ab90e6188a90742ccb4312ff24dcb` |
| DOC-0129 | Nice to have | RETIRE | `art/CRITIQUES/kits_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `a3bd8c624452e1f917ca1f4f6023ed798b0a4c1c` |
| DOC-0130 | Nice to have | RETIRE | `art/CRITIQUES/kits_2026-10-31/README.md` | `Git history` | 0 | `42aaa5bc4e785b45003347af8f7570d2807c75cf` |
| DOC-0131 | Nice to have | RETIRE | `art/CRITIQUES/lit_2026-10-31/README.md` | `Git history` | 0 | `e55129adddfa5a6917f7b1825ade32efff1077b4` |
| DOC-0132 | Nice to have | RETIRE | `art/CRITIQUES/pictures_for_dave_2026-10-31/README.md` | `Git history` | 0 | `90f1b4b08ee88b418066e6fda25839f8b30a379d` |
| DOC-0133 | Nice to have | RETIRE | `art/CRITIQUES/pieces_2026-10-30/CRITIQUE.md` | `Git history` | 0 | `d63127fd6fbebfc2ffd1f7ed6296c7fe3c42787c` |
| DOC-0134 | Nice to have | RETIRE | `art/CRITIQUES/plants_2026-10-30/CRITIQUE.md` | `Git history` | 0 | `140d9fe4031e2b09cb1d3038b1c1a8607a27ca04` |
| DOC-0135 | Nice to have | RETIRE | `art/CRITIQUES/plants_2026-10-31/TALL_GRASS_R4.md` | `Git history` | 0 | `e901d11297f088c777e71715e7bc7d06976ef1f1` |
| DOC-0136 | Nice to have | RETIRE | `art/CRITIQUES/real_game_2026-10-31/README.md` | `Git history` | 0 | `12eae1b7cd64b511f82d5074ca0291a715360ae6` |
| DOC-0137 | Nice to have | RETIRE | `art/CRITIQUES/rig3_2026-11-02/RATINGS.md` | `Git history` | 0 | `32034252bfe46575be7958ea452f4ef11460ef19` |
| DOC-0138 | Nice to have | RETIRE | `art/CRITIQUES/rough_bed/README_manger.md` | `Git history` | 0 | `af3599a39363d05b6caa8c23731e72387a4b73a1` |
| DOC-0139 | Nice to have | RETIRE | `art/CRITIQUES/rough_bed/README_poles.md` | `Git history` | 0 | `78c8da57aa9393ac32d28530005ce70555475291` |
| DOC-0140 | Nice to have | RETIRE | `art/CRITIQUES/rough_bed_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `b590e2f3fbdc1752b9dc3dc0b8d58a1d51c618dc` |
| DOC-0141 | Nice to have | RETIRE | `art/CRITIQUES/shore_props_2026-10-31/README.md` | `Git history` | 0 | `43a09dfbc420a0bde9919386a0ecb0b8e4c02a16` |
| DOC-0142 | Nice to have | RETIRE | `art/CRITIQUES/spawn_coast_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `0e5b539c4d60ee05562d79883c29af528e33b359` |
| DOC-0143 | Nice to have | RETIRE | `art/CRITIQUES/starter_area_2026-11-03/CRITIQUE.md` | `Git history` | 0 | `3b00df237ed2a103d22a3652d1e1039fbb54b6a1` |
| DOC-0144 | Nice to have | RETIRE | `art/CRITIQUES/starter_area_2026-11-03/SHADOW_TINT_PROPOSAL.md` | `Git history` | 0 | `1c440f839480aae0e5dd73602dec610e60e303d6` |
| DOC-0145 | Nice to have | RETIRE | `art/CRITIQUES/structure_looks_2026-10-31/README.md` | `Git history` | 0 | `615742e514f72287f839146a3885f7d68d113a14` |
| DOC-0146 | Nice to have | RETIRE | `art/CRITIQUES/tiers_2026-10-31/README.md` | `Git history` | 0 | `0fc16112bae4aebba230dfaa297d4f150d79bdf9` |
| DOC-0147 | Nice to have | RETIRE | `art/CRITIQUES/tools_2026-10-30/CRITIQUE.md` | `Git history` | 0 | `649af8da4877b5fd9b3f552a2afba1aef23f55b7` |
| DOC-0148 | Nice to have | RETIRE | `art/CRITIQUES/tree_shading_2026-10-31/README.md` | `Git history` | 0 | `78671cfbdb92f5c0aaef27c427a012d5c3a5a439` |
| DOC-0149 | Nice to have | RETIRE | `art/CRITIQUES/trees_2026-10-30/CRITIQUE.md` | `Git history` | 0 | `aa5b8630fc55ce8eca8fce28810e8c14b3df5890` |
| DOC-0150 | Nice to have | RETIRE | `art/CRITIQUES/trunk_cutting_2026-10-31/BARK_README.md` | `Git history` | 0 | `22d93b0cf0a894dc196a14110975eee48a41a37d` |
| DOC-0151 | Nice to have | RETIRE | `art/CRITIQUES/trunk_cutting_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `d157817d572facaa800ca876fe1e44d06d8de50c` |
| DOC-0152 | Nice to have | RETIRE | `art/CRITIQUES/water_look_2026-11-01/README.md` | `Git history` | 0 | `485393e7f60e5076d01c84c474e326e2076da2f0` |
| DOC-0153 | Nice to have | RETIRE | `art/CRITIQUES/weapons_2026-10-31/CRITIQUE.md` | `Git history` | 0 | `0b44735c003232ae7f9d827533e70a080f6a3290` |
| DOC-0154 | Nice to have | RETIRE | `art/CRITIQUES/wishlist_2026-10-31/README.md` | `Git history` | 0 | `a39a99491c1a735f43dad1b6bee42ee712c12209` |
| DOC-0155 | Nice to have | RETIRE | `art/CRITIQUES/yarrow_chamomile_2026-11-01/README.md` | `Git history` | 0 | `50c10397e7f79e40a39f006867eedd06ea4e70b8` |
| DOC-0156 | Nice to have | CONSOLIDATE | `art/ITEM_ART_STATUS.md` | `art/Art_Direction.md` | 0 | `b83718692732a7dc561fb9680bb0e1296d02ba70` |
| DOC-0157 | Nice to have | CONSOLIDATE | `art/WET_TUNNEL_PLAN.md` | `docs/design/art_caves.md` | 0 | `6adf1f0b50d059453c7a0d0e5064b0022c5afa97` |
| DOC-0158 | Nice to have | RETIRE | `art/character_proto/bench.txt` | `Git history` | 0 | `62a28df34f3902906fb816d6b0d256413403f24f` |
| DOC-0159 | Nice to have | RETIRE | `art/character_proto/motion/strips.txt` | `Git history` | 0 | `ae912679dad3509dd101108990405d40ef25056a` |
| DOC-0160 | Necessary | DEPENDENCY | `art/character_proto/perf.txt` | `art/character_proto/perf.txt` | 1 | `7037777930e6dfd13d40b5f4bb8cf532074e0855` |
| DOC-0161 | Nice to have | RETIRE | `art/character_proto/voxel45/bench.txt` | `Git history` | 0 | `0abef40ef652bc679a3737c02b061ddf917017a8` |
| DOC-0162 | Necessary | DEPENDENCY | `art/clips_in/SOURCES.txt` | `art/clips_in/SOURCES.txt` | 0 | `a82a048cacd42c31e4371f3ee2717447da861344` |
| DOC-0163 | Nice to have | RETIRE | `art/parked/README.md` | `Git history` | 0 | `6f95a6a6fb25247b7b6092f82bea4a686247d2d0` |
| DOC-0164 | Nice to have | RETIRE | `art/playthrough/RIG_PLACE.md` | `Git history` | 0 | `a04532684528d9ccf20b635c096b1ffa68166ee8` |
| DOC-0165 | Nice to have | RETIRE | `art/playthrough/audit.md` | `Git history` | 0 | `55404e9c2a41667f29265e7d80a51367bc8a94bc` |
| DOC-0166 | Nice to have | RETIRE | `art/playthrough/hunt_tests_output.txt` | `Git history` | 0 | `b6d1293d29aec04433c7b508338a1d6322ed292a` |
| DOC-0167 | Nice to have | RETIRE | `art/playthrough/items_check_output.txt` | `Git history` | 0 | `858662666d2e47a2dcd220e94145ba9c21099ff7` |
| DOC-0168 | Nice to have | RETIRE | `art/playthrough/probe_bot_output.txt` | `Git history` | 0 | `1f701cb19348b5815466bbba16288c4dabb2a59e` |
| DOC-0169 | Nice to have | RETIRE | `art/playthrough/probe_cook_after.txt` | `Git history` | 0 | `b85a681641f39df537b8bd59f082a036930d2952` |
| DOC-0170 | Nice to have | RETIRE | `art/playthrough/probe_cook_before.txt` | `Git history` | 0 | `b61cf291911c496a061c603edb3c9ec0c689204f` |
| DOC-0171 | Nice to have | RETIRE | `art/playthrough/probe_cook_output.txt` | `Git history` | 0 | `7c174a4f9efd550d7118997c54d7dfeb998ea45e` |
| DOC-0172 | Nice to have | RETIRE | `art/playthrough/probe_hunt_output.txt` | `Git history` | 0 | `37280220e961c5e50a4b36adc0422107c680d9e0` |
| DOC-0173 | Nice to have | RETIRE | `art/playthrough/probe_logs_output.txt` | `Git history` | 0 | `36804fb03ac52c5936ad81e8c1fbaa896df2d6b9` |
| DOC-0174 | Nice to have | RETIRE | `art/playthrough/probe_output.txt` | `Git history` | 0 | `b642b8aaa1151deb47ef77b1a1b3e9539b295f8c` |
| DOC-0175 | Nice to have | RETIRE | `art/playthrough/probe_place_output.txt` | `Git history` | 0 | `7bae0c0db2168ec76327ae7620dc5f77d2d3b432` |
| DOC-0176 | Nice to have | RETIRE | `art/playthrough/probe_shelter_output.txt` | `Git history` | 0 | `ea36b58151af3a00904b46723ff68fca9ccdd3a7` |
| DOC-0177 | Nice to have | RETIRE | `art/playthrough/probe_spawn_output.txt` | `Git history` | 0 | `26cdf924c35c7a7aae28656742006a38ce307d39` |
| DOC-0178 | Nice to have | RETIRE | `art/playthrough/probe_structures_output.txt` | `Git history` | 0 | `41b06c4376876ea8881dd593a388a38064d23846` |
| DOC-0179 | Nice to have | RETIRE | `art/playthrough/probe_wildlife_output.txt` | `Git history` | 0 | `d8d85bd3b904ea3982e818555fa9aa618f54cef3` |
| DOC-0180 | Nice to have | RETIRE | `art/playthrough/reachability.txt` | `Git history` | 0 | `3416306b1c4264ec40a0901fffdd73408500644c` |
| DOC-0181 | Nice to have | RETIRE | `art/playthrough/refresh1nov/RESULTS.md` | `Git history` | 0 | `098f5aedacb7634d7dff9d663b6152f0e7f93b71` |
| DOC-0182 | Nice to have | RETIRE | `art/playthrough/run_status_log.txt` | `Git history` | 0 | `27522a30a993d5860811be1b553168ba3c4e1194` |
| DOC-0183 | Nice to have | RETIRE | `art/playthrough/smoke/notes.md` | `Git history` | 0 | `b66952206b193efef98b6421390d40bf9301ab73` |
| DOC-0184 | Nice to have | RETIRE | `art/playthrough/smoke_run_log.txt` | `Git history` | 0 | `e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` |
| DOC-0185 | Nice to have | RETIRE | `art/playthrough/wildlife_day.txt` | `Git history` | 0 | `1db52638168791ce19bedd5f6e772187adc37e3d` |
| DOC-0186 | Nice to have | RETIRE | `art/playthrough/wildlife_night.txt` | `Git history` | 0 | `957d9fe47cc71fc10f7558b9ae5cc3aae383f21c` |
| DOC-0187 | Necessary | DEPENDENCY | `assets/audio/CREDITS.md` | `assets/audio/CREDITS.md` | 0 | `0c81489c0ad117eaf72771ee479803d317e90e2a` |
| DOC-0188 | Necessary | DEPENDENCY | `assets/audio/LOUDNESS.md` | `assets/audio/LOUDNESS.md` | 0 | `67f04340fee4eb89159958e984549331e8e9e8ce` |
| DOC-0189 | Necessary | DEPENDENCY | `assets/audio/README.md` | `assets/audio/README.md` | 0 | `bea97401638d2deebed65a4b8e4ef8d59011461b` |
| DOC-0190 | Necessary | DEPENDENCY | `assets/audio/SOUND_DROP_IN.md` | `assets/audio/SOUND_DROP_IN.md` | 0 | `41ccfe725743cf793f6de4f3c456f41d6a9a0de0` |
| DOC-0191 | Necessary | DEPENDENCY | `assets/audio/SOUND_PACK.md` | `assets/audio/SOUND_PACK.md` | 0 | `b6915dc06c9a600558f0608190235d038981f83e` |
| DOC-0192 | Necessary | DEPENDENCY | `assets/audio/inner_voice/README.md` | `assets/audio/inner_voice/README.md` | 0 | `fcd35ca334346a0ddc2b087acfc411d1e720fe98` |
| DOC-0193 | Necessary | DEPENDENCY | `assets/character/README.md` | `assets/character/README.md` | 0 | `45d6c49bcc1b6d0a688147347b866201b4442968` |
| DOC-0194 | Necessary | DEPENDENCY | `assets/natural_pickups/README.md` | `assets/natural_pickups/README.md` | 0 | `2618b349001aefcf3321e6c22d945905f65779f4` |
| DOC-0195 | Necessary | DEPENDENCY | `assets/tools/handsaws/README.md` | `assets/tools/handsaws/README.md` | 0 | `1af351b676f6fff8ce3f40a99cd73e0625cec87e` |
| DOC-0196 | Necessary | DEPENDENCY | `assets/ui/fonts/FONTS_LICENSE.md` | `assets/ui/fonts/FONTS_LICENSE.md` | 0 | `253c7ccbe2ab71e0e6aa27d9491278e74d5ca7cd` |
| DOC-0197 | Necessary | DEPENDENCY | `assets/ui/goal_placard/README.md` | `assets/ui/goal_placard/README.md` | 0 | `383cf47a71f1cee8db355b98a8766c1e582c3f4d` |
| DOC-0198 | Necessary | DEPENDENCY | `data/items/look_wishlist.md` | `data/items/look_wishlist.md` | 0 | `9d8100ff7c2e32b12ea5f9c1b55d019295b3394f` |
| DOC-0199 | Nice to have | CONSOLIDATE | `design/ANIMALS_BATCHES.md` | `docs/design/art_animals.md` | 0 | `584a33923c960e56f4a37470d46a04610929ec36` |
| DOC-0200 | Necessary | DEPENDENCY | `design/CREATURE_PROGRESS.md` | `design/CREATURE_PROGRESS.md` | 1 | `49a9b6d9eb6f13ffa84e4c6e98c63d555f5c233a` |
| DOC-0201 | Nice to have | CONSOLIDATE | `design/GATE_BEFORE_AFTER.md` | `docs/ai-team/TEST_GATES.md` | 0 | `25443218fef7e213498702e9246f45a7e0480ac8` |
| DOC-0202 | Necessary | DEPENDENCY | `design/TOOL_TIERS.md` | `design/TOOL_TIERS.md` | 1 | `0b3546813001d4e1a0c4d2e44bb7144eaa1a41cf` |
| DOC-0203 | Necessary | CONSOLIDATE | `docs/BLUEPRINT_SITES.md` | `docs/design/buildables_plan.md` | 0 | `a24b08f988812d1e5b57bac65e138c4f3baabf37` |
| DOC-0204 | Dead weight in checkout | RETIRE | `docs/BUG5_TREE_HITS_FINDINGS.md` | `Git history` | 0 | `a07783cb4fb0e42d54c8d8d9abab45f3f6d2f576` |
| DOC-0205 | Dead weight in checkout | RETIRE | `docs/BUGS_FOUND_IN_PLAY.md` | `Git history` | 0 | `50596447f62104222eb870f111ce18171764257e` |
| DOC-0206 | Necessary | CONSOLIDATE | `docs/CARRY_WEIGHTS.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `3a46cd440d0e4a1b623418caa5ff8066b9e8de2b` |
| DOC-0207 | Helpful | KEEP | `docs/CHARACTER_SYSTEM.md` | `docs/CHARACTER_SYSTEM.md` | 0 | `ae119cf7f1afb14a468b9b15e7297ba1781adf80` |
| DOC-0208 | Dead weight in checkout | RETIRE | `docs/CLOSING_PLAN.md` | `Git history` | 0 | `bb6f6048fb427063b4c8c8584771b0bbdc519b69` |
| DOC-0209 | Helpful | KEEP | `docs/COMFORT_DESIGN.md` | `docs/COMFORT_DESIGN.md` | 0 | `409640d7e0053dbf2b8442620042c465a158f818` |
| DOC-0210 | Dead weight in checkout | RETIRE | `docs/DAY_ONE_NUMBERS.md` | `Git history` | 0 | `c1871dd6f42b7901cc81efd63d83c3806132d160` |
| DOC-0211 | Dead weight in checkout | RETIRE | `docs/DEAD_END_MATERIALS.md` | `Git history` | 0 | `22832d7bf49cc1855ebdd66c9f8e60b9ca4e7095` |
| DOC-0212 | Paramount | KEEP | `docs/DOC_MAP.md` | `docs/DOC_MAP.md` | 0 | `24e7de680f6d04af63280e6fbc46de426f2d1948` |
| DOC-0213 | Helpful | KEEP | `docs/DYNASTY_BODY.md` | `docs/DYNASTY_BODY.md` | 0 | `71e3bc08974718b9d5e01854a20ccf22cfc4e245` |
| DOC-0214 | Necessary | CONSOLIDATE | `docs/DYNASTY_WATER_DESIGN.md` | `docs/water/watershed_rebuild_design.md` | 0 | `62c6cfc3abc6e1eeac7c5a9b9d77e5f202d2d8f1` |
| DOC-0215 | Helpful | CONSOLIDATE | `docs/DYNASTY_WATER_HISTORY.md` | `docs/water/watershed_rebuild_design.md` | 0 | `70ac3b417eae4cf2db557a61cd606d70b6483589` |
| DOC-0216 | Dead weight in checkout | RETIRE | `docs/DYNASTY_WATER_TASKS.md` | `Git history` | 0 | `0c5fbb1535aac7247d6af643b5f54a437f995064` |
| DOC-0217 | Dead weight in checkout | RETIRE | `docs/EARLY_FORAGE_20261103.md` | `Git history` | 0 | `3ad1eef47216dd9de019595a109be50a34aded97` |
| DOC-0218 | Necessary | CONSOLIDATE | `docs/ECONOMY_FIRST_DAY.md` | `ECONOMY_PLAN.md` | 0 | `83fde967496a2b7687841ad7600a98504daca713` |
| DOC-0219 | Dead weight in checkout | RETIRE | `docs/FAUNA_BEHAVIOUR_AUDIT_20261102.md` | `Git history` | 0 | `d6445a57f9d1ab70eaaa4d7d4f68c80edc4721f8` |
| DOC-0220 | Dead weight in checkout | RETIRE | `docs/FAUNA_MEASUREMENT_20261102.md` | `Git history` | 0 | `a390098068ee9f3ff497c35fb0255204899712e5` |
| DOC-0221 | Helpful | KEEP | `docs/FEEL_TUNING.md` | `docs/FEEL_TUNING.md` | 0 | `f36f011a9069fd79555a32d7e8a6753f859becde` |
| DOC-0222 | Dead weight in checkout | RETIRE | `docs/FINAL_HANDOFF_REPORT_11Nov.md` | `Git history` | 0 | `78ccfa2613ba7572681df45406c454f75226231d` |
| DOC-0223 | Dead weight in checkout | RETIRE | `docs/FLORA_HANDOVER.md` | `Git history` | 0 | `cce70e4318d636c5b290e8ea9976c6cd810b793f` |
| DOC-0224 | Dead weight in checkout | RETIRE | `docs/FLORA_NEXT_TASKS.md` | `Git history` | 0 | `d3c76839827ebb13b0312eb1e2044316c2ffc734` |
| DOC-0225 | Necessary | CONSOLIDATE | `docs/FRUIT_TREES_PLAN.md` | `docs/design/HOE_GARDENING_DESIGN.md` | 0 | `ff0a419955c8568c2ea30de69e16e17231bfd888` |
| DOC-0226 | Helpful | KEEP | `docs/GOBLINS.md` | `docs/GOBLINS.md` | 0 | `1622a2e0bd911066d46be5fd4cfeaceea6e626ab` |
| DOC-0227 | Dead weight in checkout | RETIRE | `docs/ISLAND_FAUNA_20261103.md` | `Git history` | 0 | `3206adc944a564bb9719acc71988ab82bc3071f2` |
| DOC-0228 | Dead weight in checkout | RETIRE | `docs/ITEMS_HANDOVER.md` | `Git history` | 0 | `14390da0b166d10a3a8eaf2aea770be6ca466be2` |
| DOC-0229 | Dead weight in checkout | RETIRE | `docs/KATHLEEN_NEXT_TASKS.md` | `Git history` | 0 | `6773d0d4f46edac517df9decfd0c4dc8c5746af3` |
| DOC-0230 | Dead weight in checkout | RETIRE | `docs/OLD_BRANCH_REVIEW.md` | `Git history` | 0 | `b4d9ae1cd85002e4392d74549788bb5a9f334932` |
| DOC-0231 | Necessary | KEEP | `docs/PONYTAIL_RULES.md` | `docs/PONYTAIL_RULES.md` | 1 | `b1eef979964f7bc5b46af730d5591f75e21fe78c` |
| DOC-0232 | Dead weight in checkout | RETIRE | `docs/PROJECT_START_HERE.md` | `Git history` | 0 | `7230a543f683042173f0cb544de9c33cf613bc84` |
| DOC-0233 | Helpful | CONSOLIDATE | `docs/SEASONS_DATA.md` | `docs/design/art_weather_light.md` | 0 | `c4f24bb6f73e0e7e97652f7798b5a4d7d2c0fa79` |
| DOC-0234 | Helpful | CONSOLIDATE | `docs/SOUND_MAP.md` | `docs/design/sound_outdoors_design.md` | 0 | `3cbc1fc8d71acf1df73e59944195f9722a662208` |
| DOC-0235 | Dead weight in checkout | RETIRE | `docs/SPAWN_BEAUTY_CHECK.md` | `Git history` | 0 | `0a9ccaf1f8ae2167c2980209a066a1c78fa36951` |
| DOC-0236 | Necessary | CONSOLIDATE | `docs/START_HERE.md` | `CLAUDE.md` | 1 | `7710fb17f8ed653810a5f8177777828d25ebc525` |
| DOC-0237 | Dead weight in checkout | RETIRE | `docs/TERRAIN_WATER_BACKLOG.md` | `Git history` | 0 | `0a221bff176974443b0b89a6c26379d7765a9bf3` |
| DOC-0238 | Dead weight in checkout | RETIRE | `docs/TYLER_NEXT_TASKS.md` | `Git history` | 0 | `733c97c83c6503a995fb8b9d637c64f25d1373ee` |
| DOC-0239 | Necessary | CONSOLIDATE | `docs/WILD_CROP_PLANTS_PLAN.md` | `docs/design/HOE_GARDENING_DESIGN.md` | 0 | `7458323270dd3e2169a12c00137a04cdf7af490c` |
| DOC-0240 | Necessary | CONSOLIDATE | `docs/ai-team/AUDIT_MATRIX.md` | `docs/ai-team/TEST_GATES.md` | 0 | `91318bbd6bde8f2ef5b58cdc4dc08aaebfa84287` |
| DOC-0241 | Paramount | KEEP | `docs/ai-team/CONSTITUTION.md` | `docs/ai-team/CONSTITUTION.md` | 1 | `3738850427898c88bed017b6f3fb60387eaa7af8` |
| DOC-0242 | Necessary | CONSOLIDATE | `docs/ai-team/COORDINATOR_STATE_TEMPLATE.md` | `docs/ai-team/TASK_BRIEF_TEMPLATE.md` | 1 | `fb67a0e796946fa48c0a38276e1bdf001eab3cd4` |
| DOC-0243 | Paramount | KEEP | `docs/ai-team/DECISION_AUTHORITY.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 1 | `74784f27f47cc2aeef0ba9798f05102d2a30da09` |
| DOC-0244 | Necessary | CONSOLIDATE | `docs/ai-team/DECISION_RECORD_TEMPLATE.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `60902559e2b9f79f8fe7bcb09cedc848e5886f66` |
| DOC-0245 | Necessary | CONSOLIDATE | `docs/ai-team/DOCUMENT_AUTHORITY.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 1 | `8479456d6ee8fbfa2f720de9a368e90f721e72a9` |
| DOC-0246 | Necessary | CONSOLIDATE | `docs/ai-team/EVALUATION_CASES.md` | `docs/ai-team/TEST_GATES.md` | 1 | `64504636052361518fe53c0be1d735df4af0dbe2` |
| DOC-0247 | Necessary | KEEP | `docs/ai-team/HANDOFF_TEMPLATE.md` | `docs/ai-team/HANDOFF_TEMPLATE.md` | 1 | `718db91a37339836d5b84ff4b6057052903c8054` |
| DOC-0248 | Helpful | CONSOLIDATE | `docs/ai-team/INSTALL_RECORD.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `487698bcadab838cfe59be466fc923e3c096796a` |
| DOC-0249 | Necessary | CONSOLIDATE | `docs/ai-team/KNOWN_CONFLICTS.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 1 | `d6341403f25b32accc129a68fdbb787552216fee` |
| DOC-0250 | Necessary | DEPENDENCY | `docs/ai-team/MIGRATION_PLAN.md` | `docs/ai-team/MIGRATION_PLAN.md` | 1 | `78215203dfa19d46c1aec74e300736a2e9f80a11` |
| DOC-0251 | Necessary | DEPENDENCY | `docs/ai-team/PONYTAIL_INSTALL.md` | `docs/ai-team/PONYTAIL_INSTALL.md` | 1 | `4b14c66be4cee68e4ccdd4052d7f500143f609d1` |
| DOC-0252 | Necessary | CONSOLIDATE | `docs/ai-team/ROLE_CATALOG.md` | `docs/ai-team/WORKFLOW.md` | 1 | `c3acf10c8388c5d22a1287f48259ac1ec281b51f` |
| DOC-0253 | Necessary | CONSOLIDATE | `docs/ai-team/SESSION_LIFECYCLE.md` | `docs/ai-team/WORKFLOW.md` | 1 | `1ec4dc4d750217b82df19b2c5c24174414761fec` |
| DOC-0254 | Necessary | CONSOLIDATE | `docs/ai-team/SOURCES_AND_ASSUMPTIONS.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 1 | `b42ef3c60e4fa47d590db9008dc41d4174e99984` |
| DOC-0255 | Necessary | KEEP | `docs/ai-team/TASK_BRIEF_TEMPLATE.md` | `docs/ai-team/TASK_BRIEF_TEMPLATE.md` | 1 | `19a8a5164ed41bef625ff0eb749ab56349e2a7a9` |
| DOC-0256 | Necessary | KEEP | `docs/ai-team/TEST_GATES.md` | `docs/ai-team/TEST_GATES.md` | 1 | `5d4924fb1da531a03f4d34037f4eb29a8c481de8` |
| DOC-0257 | Necessary | KEEP | `docs/ai-team/WORKFLOW.md` | `docs/ai-team/WORKFLOW.md` | 1 | `143e046c6b1672cfa98999670625480bd232419e` |
| DOC-0258 | Helpful | CONSOLIDATE | `docs/ai-team/audits/2026-11-12_projects_beta_instruction_audit.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `4983d9c750e81c27468eedd907de29f48654172f` |
| DOC-0259 | Helpful | CONSOLIDATE | `docs/ai-team/audits/2026-11-15_operating_rules_reconciliation.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `4b3a137ec1962d1542a461e63bf2e22c68f57e42` |
| DOC-0260 | Necessary | DEPENDENCY | `docs/ai-team/missions/B001/BRIEF.md` | `docs/ai-team/missions/B001/BRIEF.md` | 0 | `a3d8c03090f1f8557d75ede3e94662513f83e8c8` |
| DOC-0261 | Necessary | DEPENDENCY | `docs/ai-team/missions/B001/RESULTS.md` | `docs/ai-team/missions/B001/RESULTS.md` | 0 | `28b627c76b872e8c5211953fdc0de9976ab276ed` |
| DOC-0262 | Helpful | RETIRE | `docs/ai-team/missions/BUGLIST-001/backpack.md` | `Git history` | 0 | `62cdfa2104302b1b0d5b5cd73c3f0ab29adc3a87` |
| DOC-0263 | Helpful | RETIRE | `docs/ai-team/missions/BUGLIST-001/construction-pieces.md` | `Git history` | 0 | `f29501ac502db72ea0284d923f74bc5840185e39` |
| DOC-0264 | Helpful | RETIRE | `docs/ai-team/missions/BUGLIST-001/construction-placement.md` | `Git history` | 0 | `40414e05fa9a0adc584870cabe1c4bb5c00bd936` |
| DOC-0265 | Helpful | RETIRE | `docs/ai-team/missions/BUGLIST-001/effort-axe.md` | `Git history` | 0 | `ca3f5898f80092d01508407fdaef8c00693d1115` |
| DOC-0266 | Helpful | RETIRE | `docs/ai-team/missions/BUGLIST-001/environment-presentation.md` | `Git history` | 0 | `6c2e5675376c6ddec8b8cb69ec00589b1fba87be` |
| DOC-0267 | Helpful | RETIRE | `docs/ai-team/missions/BUGLIST-001/roads.md` | `Git history` | 0 | `ab2bf3f2c43307710d98bda20b2c8711e41db83b` |
| DOC-0268 | Helpful | RETIRE | `docs/ai-team/missions/BUGLIST-001/vegetation.md` | `Git history` | 0 | `52729a2e102e6f9d24214f194e9e9431e72397a3` |
| DOC-0269 | Necessary | KEEP | `docs/ai-team/missions/BUGLIST-002/CONTRACT.md` | `docs/ai-team/missions/BUGLIST-002/CONTRACT.md` | 0 | `473a4ddf69841b6359e7a87d7949ec34dd862d9f` |
| DOC-0270 | Necessary | KEEP | `docs/ai-team/missions/BUGLIST-002/LEDGER.md` | `docs/ai-team/missions/BUGLIST-002/LEDGER.md` | 0 | `bda35ca785611218875d869e027ad388e01f6c33` |
| DOC-0271 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/README.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `c6e482f3c90e6758e8ee238a3c2467f1302c94b5` |
| DOC-0272 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/STATE.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `7c1a37ae7042c6f12a96de34226c6c9b245ae588` |
| DOC-0273 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/WORKSTREAM_RULES.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `d4e91345f165cc45f0c51cc3c6329d690c3d90c7` |
| DOC-0274 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/david4_evidence_dc2fa52.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `30b6c96ffdfcfd570278382610625750ded8b550` |
| DOC-0275 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/goals_parsed.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `a62ef30fca161fa494b3b5e34fe21a6a62a002fe` |
| DOC-0276 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/lead_findings.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `9cca73010baaabb34b94442b50b865c8ed5349f9` |
| DOC-0277 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ledger_stats.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `beabfd9fa90d5bfa5fc079ae9913eb2f5ff30ee7` |
| DOC-0278 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/obtainability.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `3de7e45d826fe7e8436ef96c6710d3b11bf37958` |
| DOC-0279 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/pass1_summary.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `baa92960c4b9f7c3e2d6c8c7822721cbe0ea21af` |
| DOC-0280 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/pass2_deps.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `16c48c0d1095fe5f785c4b885b4c659e6941524b` |
| DOC-0281 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/pass2_report.txt` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `a877a69639ab18dfbbc6e505e3d6f6dca14b308a` |
| DOC-0282 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/raw_inputs.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `3910521161d613ff0aecf83c6938345407c0f91a` |
| DOC-0283 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/review_log.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `332c33883f9fc3e533c9940f4d656b17d021b466` |
| DOC-0284 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/source_mentions.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `9e936a801dbae91eb3cdfcaf59d61539a1e70b35` |
| DOC-0285 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_acquisition.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `46e0a4e59cef27d70396d892067ffcbcc229d673` |
| DOC-0286 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_acquisition.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `31866674ed3dbb9f6ca5dd793b8d387485379abf` |
| DOC-0287 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_catalog.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `5f65086b285ea41b37f7be13c5bebcaa11fd6d6f` |
| DOC-0288 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_catalog.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `eda25c5b0e675bc8dfdb1fac4aaf8d9af4424cd4` |
| DOC-0289 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_economy.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `c8c455202c6203daa6b370338d18ebaa28dd8a94` |
| DOC-0290 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_economy.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `88a5f25ebc7eacdbe938888565017237195df96a` |
| DOC-0291 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_runtime.json` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `5081a3b5a96937b04b677e26244f1a4bad64c344` |
| DOC-0292 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_runtime.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `77926df00069dc9e754550b3e138ab8b90f4c74c` |
| DOC-0293 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_ui.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `733c014a922acc30c0389f025af8e1c62f5c2ee5` |
| DOC-0294 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_walk_early.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `9abb860543a55772fa47a866e09066ae7cd4b4ea` |
| DOC-0295 | Helpful | RETIRE | `docs/ai-team/missions/GOALS-AUDIT/work/ws_walk_late.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `084890ed1d71114a82005eb6b883ad56759f122f` |
| DOC-0296 | Necessary | KEEP | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `3035141ae322d8fb9ff8405137f8a842f60cde7a` |
| DOC-0297 | Necessary | KEEP | `docs/ai-team/missions/GOALS-REPAIR/STATE.md` | `docs/ai-team/missions/GOALS-REPAIR/STATE.md` | 0 | `3c82cd29e62a0083f10f8aa6e5c38c57284ad214` |
| DOC-0298 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/baseline/GOALS_UI_KEYS_1382118.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `0a889d4c5c45e2e473b85ab6d07a7e3b69412d4d` |
| DOC-0299 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/baseline/METAL_STATIONS_1382118.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `1543f3fcd9b018b30bcca1e11b8639e30946fbca` |
| DOC-0300 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/baseline/PRIMITIVE_ROUTE_d990abd.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `e3a092c61bc26d670c7c4bf5ee2d1ad4bad04814` |
| DOC-0301 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/baseline/R1_SOURCES_WATER_FARMING.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `fec7d878e20aaa2cacaf9761b13cc6404efcb9bb` |
| DOC-0302 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/briefs/COMMON.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `214e2e56750652522ac8fefff2bb5d71373cd9d7` |
| DOC-0303 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/briefs/WP-GUIDE-UI.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `908fba243c28584a8fc6f4968da40448ea8aaeac` |
| DOC-0304 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/briefs/WP-MAP.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `82c5622fba106000143167c89abe39931d074d04` |
| DOC-0305 | Helpful | CONSOLIDATE | `docs/ai-team/missions/GOALS-REPAIR/briefs/WP-METAL.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `f6ac0009957c9247a4c24b6892a0122f452b36ec` |
| DOC-0306 | Helpful | RETIRE | `docs/ai-team/missions/M001/MISSION_REPORT.md` | `Git history` | 0 | `0dee53c5dee562c852a113571376be172e21334f` |
| DOC-0307 | Necessary | DEPENDENCY | `docs/ai-team/missions/M001/STATE.md` | `docs/ai-team/missions/M001/STATE.md` | 0 | `c5f813b75f54273b7bc8990bebf24c51af52c842` |
| DOC-0308 | Helpful | RETIRE | `docs/ai-team/missions/M001/T04B_RESULTS.md` | `Git history` | 0 | `92929fb92561cbe7a973ca6dc9a008128619a00f` |
| DOC-0309 | Helpful | RETIRE | `docs/ai-team/missions/M001/T04C_RESULTS.md` | `Git history` | 0 | `8ae751e661b316ce79090443cbc1d0a43956b296` |
| DOC-0310 | Helpful | RETIRE | `docs/ai-team/missions/M001/T04_BRIEF.md` | `Git history` | 0 | `baa486a1883560f8599d2c71e0884a856ed23da6` |
| DOC-0311 | Helpful | RETIRE | `docs/ai-team/missions/M001/T04_RESULTS.md` | `Git history` | 0 | `eb392f485612b2a0c09de1bd0acf6adfd8fee591` |
| DOC-0312 | Helpful | RETIRE | `docs/ai-team/missions/M001/T07_BRIEF.md` | `Git history` | 0 | `d582dac90201027a678d0f7272a15ff78eda4a35` |
| DOC-0313 | Helpful | RETIRE | `docs/ai-team/missions/M001/T07_RESULTS.md` | `Git history` | 0 | `3cd73fb554d4f50bc73fc18e89052f491752e1a6` |
| DOC-0314 | Helpful | RETIRE | `docs/ai-team/missions/M001/T08_BRIEF.md` | `Git history` | 0 | `4410db8c4c9b591ebc49a22bcff79343a2fee43f` |
| DOC-0315 | Helpful | RETIRE | `docs/ai-team/missions/M001/T08_RESULTS.md` | `Git history` | 0 | `5629f6054149a59677811b7cfa2123928a878065` |
| DOC-0316 | Helpful | RETIRE | `docs/ai-team/missions/M001/T09_RESULTS.md` | `Git history` | 0 | `16f70b4f9032efd32112b861326061a53fc20421` |
| DOC-0317 | Helpful | RETIRE | `docs/ai-team/missions/M001/T10_RESULTS.md` | `Git history` | 0 | `448435b986af138dce6562bb08a999597032554c` |
| DOC-0318 | Helpful | RETIRE | `docs/ai-team/missions/M001/T11_BRIEF.md` | `Git history` | 0 | `640aa9b56cc9b4f3988ff6bd417a7eb870c6a02a` |
| DOC-0319 | Helpful | RETIRE | `docs/ai-team/missions/M001/T11_RESULTS.md` | `Git history` | 0 | `cf00fca6ff96525de04048891c1c4881b6e2fc7f` |
| DOC-0320 | Helpful | RETIRE | `docs/ai-team/missions/M001/T12_BRIEF.md` | `Git history` | 0 | `bb3eb85bb97c6be1aa4f2f9546746f5224679cd2` |
| DOC-0321 | Helpful | RETIRE | `docs/ai-team/missions/M001/T12_RESULTS.md` | `Git history` | 0 | `88127f4ccd46fbe82cbdb50287f0e462738ac961` |
| DOC-0322 | Helpful | RETIRE | `docs/ai-team/missions/M001/T13_BRIEF.md` | `Git history` | 0 | `8f3ddc2e609b7b3d1498eddb9028ee61039bbe05` |
| DOC-0323 | Helpful | RETIRE | `docs/ai-team/missions/M001/T13_RESULTS.md` | `Git history` | 0 | `9a4f3db1b1f430bb634eb112875e0404b8f222f0` |
| DOC-0324 | Helpful | RETIRE | `docs/ai-team/missions/M001/T14_RESULTS.md` | `Git history` | 0 | `2825e4395fdff34374cccd2d153db482ff720b55` |
| DOC-0325 | Helpful | RETIRE | `docs/ai-team/missions/M001/T15_BRIEF.md` | `Git history` | 0 | `1a13bf9bc6e94e283f82aaa66448d9c2c5b397c5` |
| DOC-0326 | Helpful | RETIRE | `docs/ai-team/missions/M001/T15_RESULTS.md` | `Git history` | 0 | `9969dbe5742160778520d821d7586697fff4a842` |
| DOC-0327 | Helpful | RETIRE | `docs/ai-team/missions/M001/T16_BRIEF.md` | `Git history` | 0 | `26f7b9c1d7c291cc852ec43271ef66ff4363400f` |
| DOC-0328 | Helpful | RETIRE | `docs/ai-team/missions/M001/T16_RESULTS.md` | `Git history` | 0 | `8393820333f3d5f4b3901d8cde87bf9e1af7c777` |
| DOC-0329 | Helpful | RETIRE | `docs/ai-team/missions/M001/T17_BRIEF.md` | `Git history` | 0 | `c29f53f03c991c50a486fd92775ed9ce4f395c82` |
| DOC-0330 | Helpful | RETIRE | `docs/ai-team/missions/M001/T17_RESULTS.md` | `Git history` | 0 | `2fe81b67d871007d70aa9a233f9e56d731f0691a` |
| DOC-0331 | Helpful | RETIRE | `docs/ai-team/missions/M001/T18_BRIEF.md` | `Git history` | 0 | `4026395481804887a5a86ea6467f727423e42582` |
| DOC-0332 | Helpful | RETIRE | `docs/ai-team/missions/M001/T18_RESULTS.md` | `Git history` | 0 | `8a591e14e6f91a3ccd6cb6369554f1094c99aa83` |
| DOC-0333 | Helpful | RETIRE | `docs/ai-team/missions/M001/T19_BRIEF.md` | `Git history` | 0 | `5484d997aba53b61c8ab804e1bba8579ea989b41` |
| DOC-0334 | Helpful | RETIRE | `docs/ai-team/missions/M001/T19_RESULTS.md` | `Git history` | 0 | `b84eaecb69f32ad9bd913dfac652a4a3d562dcd3` |
| DOC-0335 | Helpful | RETIRE | `docs/ai-team/missions/PLAYTEST-001/combat-tools.md` | `Git history` | 0 | `ffb5946efd0ef0da285c8eac166e90335f95e8c4` |
| DOC-0336 | Helpful | RETIRE | `docs/ai-team/missions/PLAYTEST-001/crafting.md` | `Git history` | 0 | `96940b8831942ee0615cab4028fe7c5ea47005b7` |
| DOC-0337 | Helpful | RETIRE | `docs/ai-team/missions/PLAYTEST-001/environment.md` | `Git history` | 0 | `aef90fa93b896e4ee9706b60513dc0f831808046` |
| DOC-0338 | Helpful | RETIRE | `docs/ai-team/missions/PLAYTEST-001/hotbar.md` | `Git history` | 0 | `08e05330ada46bd2abc8ee31acff8f47524e420c` |
| DOC-0339 | Helpful | RETIRE | `docs/ai-team/missions/PLAYTEST-001/trading.md` | `Git history` | 0 | `3ecb1581590ee6daa4022f2f53ff277c9cb12897` |
| DOC-0340 | Necessary | KEEP | `docs/ai-team/missions/WOOD-SYSTEM/STATE.md` | `docs/ai-team/missions/WOOD-SYSTEM/STATE.md` | 0 | `0efb9dfa86a0e01a86f25b7e9c98de2340b88636` |
| DOC-0341 | Necessary | DEPENDENCY | `docs/ai-team/package/README_FIRST.md` | `docs/ai-team/package/README_FIRST.md` | 1 | `4083b9df35e7acf24164ab17469450afe0b58dc2` |
| DOC-0342 | Necessary | DEPENDENCY | `docs/ai-team/package/REVISION_AND_AUDIT_LOG.md` | `docs/ai-team/package/REVISION_AND_AUDIT_LOG.md` | 1 | `b6ea242489b20bda2cf0dcbe59901ecfcbbb6b9e` |
| DOC-0343 | Necessary | DEPENDENCY | `docs/ai-team/package/cowork/COORDINATOR_BOOTSTRAP.md` | `docs/ai-team/package/cowork/COORDINATOR_BOOTSTRAP.md` | 1 | `cb0dff18a0862235ac4568bd20712ddce144f880` |
| DOC-0344 | Dead weight in checkout | RETIRE | `docs/ai-team/package/cowork/INSTALL_ORDER.md` | `docs/ai-team/WORKFLOW.md` | 0 | `b72b18d47dc72faabca4ab0b24c1c62c34ff10df` |
| DOC-0345 | Necessary | DEPENDENCY | `docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt` | `docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt` | 1 | `3713b48a79aabf1d9bd342af3eb5a695c1817cd3` |
| DOC-0346 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/ADMINMODE-01/RESULTS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `57b1711787f3ed054a0c837a23b9cf945b3ddf47` |
| DOC-0347 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/ADMINMODE-01/evidence/plan.json` | `docs/ai-team/WORKFLOW.md` | 0 | `5f9bc7f14bfd4c4cbf72c843d644f880db95c4d9` |
| DOC-0348 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/ADMINMODE-01/evidence/smoke_1b539086.txt` | `docs/ai-team/WORKFLOW.md` | 0 | `8416d5ee4a2831d33b5596e9c2daf9f7164076a7` |
| DOC-0349 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/HANDOFF.md` | `docs/ai-team/WORKFLOW.md` | 0 | `840149e307617c399c3d9e67f3cb887deea3b3a0` |
| DOC-0350 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/RESULTS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `e55a3df5ed5f76d42799080e580eddf9dba680b9` |
| DOC-0351 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/REVIEW_1.md` | `docs/ai-team/WORKFLOW.md` | 0 | `7ad858994f6289a1c039e11703721f9f4ce679b4` |
| DOC-0352 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/TASK_BRIEF.md` | `docs/ai-team/WORKFLOW.md` | 0 | `57ca23cc61d9b8459bf80f415f687609ee511f4d` |
| DOC-0353 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/evidence/affected_plan.json` | `docs/ai-team/WORKFLOW.md` | 0 | `54e0d005261a77a3b56d60ff4686f91e87bce6fd` |
| DOC-0354 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/evidence/affected_tests_full2_summary.txt` | `docs/ai-team/WORKFLOW.md` | 0 | `ea4d36e08160d05f88eb7c72a7bdb7824ac69b76` |
| DOC-0355 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/evidence/smoke2.extract.txt` | `docs/ai-team/WORKFLOW.md` | 0 | `4805f8eebda551d853062922f880ab45ee5ce89b` |
| DOC-0356 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/evidence/smoke3.extract.txt` | `docs/ai-team/WORKFLOW.md` | 0 | `828a5137d2821b6e0b79da795c20a708fcb704ac` |
| DOC-0357 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/evidence/smoke_base3.extract.txt` | `docs/ai-team/WORKFLOW.md` | 0 | `3a4d421be6d366e5a1b8a1ed281246d5f3561618` |
| DOC-0358 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/DEVTEST-01/evidence/smoke_base4.extract.txt` | `docs/ai-team/WORKFLOW.md` | 0 | `eed1b8ad821a2c665e20bcf7fea7c023cc6090b3` |
| DOC-0359 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/OPTEST-01/HANDOFF.md` | `docs/ai-team/WORKFLOW.md` | 0 | `6e25d12f2dc4fd8715226871a85ce6db63b14a75` |
| DOC-0360 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/OPTEST-01/RESULTS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `7990e957f7ee1e5925ae805ef78ae70a49e5864a` |
| DOC-0361 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/OPTEST-01/REVIEW_1.md` | `docs/ai-team/WORKFLOW.md` | 0 | `365de82d9400dc47609f8bbe5589f0add1b444b0` |
| DOC-0362 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/OPTEST-01/REVIEW_2.md` | `docs/ai-team/WORKFLOW.md` | 0 | `f1b47bc7f240894cd43b8e73aa60b296a6979da6` |
| DOC-0363 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/OPTEST-01/REVIEW_3.md` | `docs/ai-team/WORKFLOW.md` | 0 | `cec88a7da15428fa3e42869cbf81f5fcccedd6b5` |
| DOC-0364 | Dead weight in checkout | RETIRE | `docs/ai-team/trials/OPTEST-01/TASK_BRIEF.md` | `docs/ai-team/WORKFLOW.md` | 0 | `57ddb81e6411e0ac9a658aefde8cfacdea125810` |
| DOC-0365 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/CHANGES_THIS_PASS.md` | `Git history` | 0 | `2b89c1945700ddd0f196fcd37f2f1fa77fab25ac` |
| DOC-0366 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/DESIGN_IDEAS_REVISION_HISTORY.md` | `Git history` | 0 | `b13d5aae0878eade80e9fb3fd8479de5641a97f1` |
| DOC-0367 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/DESIGN_REVIEW.md` | `Git history` | 0 | `03aaad57280ecd6ef94c4d53899645425b1e37bf` |
| DOC-0368 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/HANDOFF_FULL_2026-10-29.md` | `Git history` | 0 | `07d76363e9d5dab671d2ef3f375a1e387333319a` |
| DOC-0369 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/MORNING_PLAYTEST_CHECKLIST_FULL.md` | `Git history` | 0 | `69c95a999c59443b54c48ab168a890ef1101de9f` |
| DOC-0370 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/README.md` | `Git history` | 0 | `003da0614ddd353790e1e5282fe8d7d1c4219354` |
| DOC-0371 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/audit_instructions/MASTER_AUDIT.md` | `Git history` | 0 | `d2e5e898f1a07315d5fffecf1c919c5c67187867` |
| DOC-0372 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/audit_instructions/PHASE_1_INVENTORY.md` | `Git history` | 0 | `9ba6d20fab9da8d955e49b86e4b1e45a677f3875` |
| DOC-0373 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/audit_instructions/PHASE_2_AUTHORITY.md` | `Git history` | 0 | `a82935e4aee9e1ceee75361c56cfa7c09ba4136d` |
| DOC-0374 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/audit_instructions/PHASE_3_DOCUMENTATION.md` | `Git history` | 0 | `581d09afff8530ea7ff97780f97734b8297ed4c7` |
| DOC-0375 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/audit_instructions/PHASE_4_ARCHITECTURE.md` | `Git history` | 0 | `e3371b5404c99f9e522800d68ae515b2eb5fea7b` |
| DOC-0376 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/audit_instructions/PHASE_5_OPTIMIZATION.md` | `Git history` | 0 | `a9e0de51f72473130a351dd56f2ad9aa8cc35d55` |
| DOC-0377 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/audit_instructions/PHASE_6_VERIFICATION.md` | `Git history` | 0 | `97029d254555fd39219038a62e0f5df1ce56fade` |
| DOC-0378 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake28/island_table.txt` | `Git history` | 0 | `b13174d2400499352ac4e118c4e1a03f84dacf16` |
| DOC-0379 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake28/river_settle_report5.txt` | `Git history` | 0 | `57d0e71c68edae5da59c2116e57038a119d7f0a4` |
| DOC-0380 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake28/river_settle_report6.txt` | `Git history` | 0 | `be8c6ecc5c975f8d0f950ad0afdcddeed837d22b` |
| DOC-0381 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake29b/island_table.txt` | `Git history` | 0 | `1c58c738785198918734199d78a672fbd27d7638` |
| DOC-0382 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake29b/river_settle_report_3_4.txt` | `Git history` | 0 | `27a9586906447ac9ccdf2deb59862b12da461089` |
| DOC-0383 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30/gullies.txt` | `Git history` | 0 | `da6cd02dbfb09cf9ba6361070e1c481a3bdf6268` |
| DOC-0384 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30/island_table.txt` | `Git history` | 0 | `e531273a82908f73c242db65ff99a541c8fdb8bc` |
| DOC-0385 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30/river_settle_report_3_4.txt` | `Git history` | 0 | `36257dea903b9d2c105c35e2d76b0cc7143ca023` |
| DOC-0386 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30b/pond_probes.txt` | `Git history` | 0 | `b6ae86f65698bda82b35bc84b1f593be34b07aff` |
| DOC-0387 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30b/probe_52976_73368.txt` | `Git history` | 0 | `8b9793885f1bdd32aad5451a4a67cb4fecee00de` |
| DOC-0388 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30b/probe_53144_73544.txt` | `Git history` | 0 | `b87bfad1d2346a7e2e9b2f0f14f6826de06dadbb` |
| DOC-0389 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30b/probe_53200_73560.txt` | `Git history` | 0 | `f6666452130cab08e70ee0e9bdddf9da69b9989b` |
| DOC-0390 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30b/river_settle_report_3_4_stitched.txt` | `Git history` | 0 | `1f818e2735cc67849db7032c11c5edf238724fb9` |
| DOC-0391 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake30b/stitch.txt` | `Git history` | 0 | `efe15c4a973eaabe00245b91b930fadf82e63e0e` |
| DOC-0392 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake31/breach_pits.txt` | `Git history` | 0 | `1697734f27d216c8c3937fa5695fb8496a805752` |
| DOC-0393 | Necessary | DEPENDENCY | `docs/archive/2026-10/docs/bake31/island_table.txt` | `docs/archive/2026-10/docs/bake31/island_table.txt` | 1 | `ed64f83bb8895e37f74c1db503f33247b90373d7` |
| DOC-0394 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake31/river_settle_report_3_4.txt` | `Git history` | 0 | `5ddfe9eaa1efb04e5003152cf6817bf3aa94bf16` |
| DOC-0395 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake31/stitch.txt` | `Git history` | 0 | `3c121b4b3d87f02dae12f98562b7d09f41705e9a` |
| DOC-0396 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake31/test_totals.txt` | `Git history` | 0 | `9842616c13b0d0534b2fa5b902808a4b164995bb` |
| DOC-0397 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake793_lake_c30d/bake_summary.txt` | `Git history` | 0 | `088a42555d8692839a010f2e79b30566cc1f7e03` |
| DOC-0398 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake793_lake_c30d/island_table.txt` | `Git history` | 0 | `9bfc3b49aaad8682bf0bc889781b88e699f5f46f` |
| DOC-0399 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake793_lake_c30d/settle_times.txt` | `Git history` | 0 | `9fd0164b756d704637ea4ebe6562477d35f99119` |
| DOC-0400 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake793_lake_c30d/tiles_md5.txt` | `Git history` | 0 | `b1a13c67db87304543566f11e75e05b37b97864a` |
| DOC-0401 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/bake793_lake_c30d/water_md5.txt` | `Git history` | 0 | `32995d208b35c84897e3d970cd2699a46071d09e` |
| DOC-0402 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/OPEN_Kathleen_ArtisticDirector.md` | `Git history` | 0 | `8b6c00e72a407e678f116656e3bf6110b34dcb31` |
| DOC-0403 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Kathleen.txt` | `Git history` | 0 | `ee4bc2592b2f6dc6419a52ecb5bca08e58430bfb` |
| DOC-0404 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Mike.txt` | `Git history` | 0 | `7f0e36f7d55fd3493c198930516e8c5d0b725d01` |
| DOC-0405 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Moderator.txt` | `Git history` | 0 | `2822f55f0cebab597a569f347f2371b806583f92` |
| DOC-0406 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Sal.txt` | `Git history` | 0 | `c439c6272e10907574d585c5b347da54516cceb2` |
| DOC-0407 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Sonny.txt` | `Git history` | 0 | `d573c23c6b81766fb99247264b1ea14d86fe12a9` |
| DOC-0408 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Steve.txt` | `Git history` | 0 | `3e0ef713260492792a7da00d685873097d7f8c11` |
| DOC-0409 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goalpads/WhatamIDoingtoReachMyGoal_Tyler.txt` | `Git history` | 0 | `babefc5975b2e04b15163376bb47f77460925704` |
| DOC-0410 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goals/goals_Kathleen.md` | `Git history` | 0 | `310e60bdb62fcc3c83c9fc5029d07f9f6fdec9eb` |
| DOC-0411 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goals/goals_Mike.md` | `Git history` | 0 | `aa7f86ee5560e2c2a4ad7169a9389923ca379d0b` |
| DOC-0412 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goals/goals_Moderator.md` | `Git history` | 0 | `4f4fbe091c3c03790eb513616c42f4f606b554f9` |
| DOC-0413 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goals/goals_Sal.md` | `Git history` | 0 | `84ac617d1c526cb337d47ce843e3601acc5fa43d` |
| DOC-0414 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goals/goals_Sonny.md` | `Git history` | 0 | `a2eb2cf326d62fdaa70ed34fc81b6a2604f97966` |
| DOC-0415 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goals/goals_Steve.md` | `Git history` | 0 | `e018f21f64ea71674c1b96881b6ee694846ef2a5` |
| DOC-0416 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/goals/goals_Tyler.md` | `Git history` | 0 | `f7bcc98b364154dbf735d21899d2cd8d784d522f` |
| DOC-0417 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/ART_HANDOFF.md` | `Git history` | 0 | `5b1824c86ef6a43fd306e709ee84fa828433c5fb` |
| DOC-0418 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/GROUND_HANDOFF.md` | `Git history` | 0 | `a3bd49cec92898dcb1eca51702b671ef4feeed25` |
| DOC-0419 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/ITEMS_HANDOFF.md` | `Git history` | 0 | `766a0e2414c6005a46a5b309cca055983d8f6c79` |
| DOC-0420 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/ITEMS_HANDOFF_2.md` | `Git history` | 0 | `be4ed23c496a2c7511c8d7385bef52d4d6c1a820` |
| DOC-0421 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Mandy_001_HANDOFF.md` | `Git history` | 0 | `39fd831edf144f7b437edcae8a644b2ce6bcc478` |
| DOC-0422 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Mandy_002_HANDOFF.md` | `Git history` | 0 | `40db60ee34e681b770e0c0184ca1359e5d903070` |
| DOC-0423 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/RIVER_START_HANDOFF.md` | `Git history` | 0 | `d109595ead917689165412d95841e0d1f923c2a5` |
| DOC-0424 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Radar_001_HANDOFF.md` | `Git history` | 0 | `e3b879a987b291dab9b461226feef898f72ea654` |
| DOC-0425 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Radar_002_HANDOFF.md` | `Git history` | 0 | `dee9b2925c5216db2729a60fdd698d7438947be6` |
| DOC-0426 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Sonny_001_HANDOFF.md` | `Git history` | 0 | `ecfdfdb2fb817d336121381cb8defb405e4581e2` |
| DOC-0427 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Sonny_002_HANDOFF.md` | `Git history` | 0 | `73bf775307ab64635b916c19323ec1ebe8a82b9a` |
| DOC-0428 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Sonny_003_HANDOFF.md` | `Git history` | 0 | `d5a95a71c135e063ebcde457e5171f85394e66b2` |
| DOC-0429 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Sonny_WorksDep_002_HANDOFF.md` | `Git history` | 0 | `1af37652e9a54e2383cd56a93b24a85060d7e694` |
| DOC-0430 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Steve_001_HANDOFF.md` | `Git history` | 0 | `5858726665d7c9018e900efcaf990c49cffc8e05` |
| DOC-0431 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Steve_002_HANDOFF.md` | `Git history` | 0 | `5ea2e3a5ec00d5caace6aed0487632f0eb016ef1` |
| DOC-0432 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/TECHNICAL_DIRECTION_HANDOFF.md` | `Git history` | 0 | `a47b52a9b18b1be57434e34a37c06e8d9c75bb10` |
| DOC-0433 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Tyler_001_HANDOFF.md` | `Git history` | 0 | `205a5c824a8432a4bac63dcc4ace8673adedb211` |
| DOC-0434 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Tyler_002_HANDOFF.md` | `Git history` | 0 | `fa640d6e237ca1d37f3da6768d2fc1f0611207a0` |
| DOC-0435 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Willy_001_HANDOFF.md` | `Git history` | 0 | `b147ef9301cbd006919381901e6d1bdc8de409d0` |
| DOC-0436 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/Willy_002_NOTES.md` | `Git history` | 0 | `fdae6d8b9ea682e0c24e17c23a4da0f96e49f8b0` |
| DOC-0437 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/ditch_check.gd.txt` | `Git history` | 0 | `e4f615977b570d28359a1335fde38dc1258f8e8e` |
| DOC-0438 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/gen_speed_bench.gd.txt` | `Git history` | 0 | `4c46cc7921d768c1630d914a6b8ef18f39ddc15e` |
| DOC-0439 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/handoff/willy_grounds_keeper_2.md` | `Git history` | 0 | `4d0f93f6e3edea6727fbe5bcb4b44339bd839a4a` |
| DOC-0440 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Erosion_fill_cap.md` | `Git history` | 0 | `b03f2eb0ecb5320b24806c28a19a678aec6ca896` |
| DOC-0441 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Erosion_fill_cap_REPLY.md` | `Git history` | 0 | `35b2c366e36318377974ebd70bf153eb07b4eb82` |
| DOC-0442 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Erosion_precarve.md` | `Git history` | 0 | `e52932b5de9d946a9fea274b062abbbfa00cc0e2` |
| DOC-0443 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Erosion_precarve_REPLY.md` | `Git history` | 0 | `c5a6c3edefe60033893c00abc3e8e878c0788746` |
| DOC-0444 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Generator_speedup_REPLY.md` | `Git history` | 0 | `a605d1c2cfdfebad7ea2a1f5575446d4af1ec5f2` |
| DOC-0445 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_building_looks.md` | `Git history` | 0 | `564a038b2b9872f39f5be2aab17cefffa18c45cb` |
| DOC-0446 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_building_tiers_looks_REPLY.md` | `Git history` | 0 | `65a65cb7d13843502028d1441c0d04588b72491a` |
| DOC-0447 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_flora_gaps.md` | `Git history` | 0 | `e05812ea71f89f81233fb033c709f0ecbda317a8` |
| DOC-0448 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_goal2_batch_a.md` | `Git history` | 0 | `dca7423c2f8876555ac2b3c2409953a1e864a2a5` |
| DOC-0449 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_goal2_batch_b.md` | `Git history` | 0 | `439ae96a3d4d16d444f121d90f96e4f85c7bc43e` |
| DOC-0450 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_goal2_batch_c.md` | `Git history` | 0 | `7be77e0a19a4e6c320ebe263ac19f235dd902317` |
| DOC-0451 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_held_pose_REPLY.md` | `Git history` | 0 | `9aee045fbafe527d01ee21338f7753c6fea07453` |
| DOC-0452 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_held_tools_REPLY.md` | `Git history` | 0 | `7e643a241f5bd157e450a6d3998abf04f022f02f` |
| DOC-0453 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_held_tools_pose_heads.md` | `Git history` | 0 | `a9ec01ed143435ad41ae377c5fad8e8252a56bb7` |
| DOC-0454 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_item_looks_batch.md` | `Git history` | 0 | `24bbe8ac26c3b359bd857f2c4d2de8cb6c552c25` |
| DOC-0455 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_metal_surface.md` | `Git history` | 0 | `5792a0a3e89729816a0d14fe916aad19100f18e9` |
| DOC-0456 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_metal_surface_REPLY.md` | `Git history` | 0 | `8042ae120cce8ad171a148fcabaefa6ab8b84dbe` |
| DOC-0457 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_sound_batch_1.md` | `Git history` | 0 | `81989a817d7995ea2e83614c746c0a69bb0981d0` |
| DOC-0458 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_sound_batch_2.md` | `Git history` | 0 | `1c251b3a620cb641968cc4fce98ae8a8c3600c7e` |
| DOC-0459 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_tool_pass.md` | `Git history` | 0 | `f7f0ff7ccb8bb4086d8df44beaf2b48eac847fc8` |
| DOC-0460 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_tool_pass_REPLY.md` | `Git history` | 0 | `4b1719082b8ee6b338964ebb1feb87b347cb2924` |
| DOC-0461 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_tree_belts.md` | `Git history` | 0 | `a75aa2ed301f21d26c7efe398297db3cad4607e7` |
| DOC-0462 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_weak_looks_batch.md` | `Git history` | 0 | `4edecb0d8a788a58bd6a1d6bb84e750da5af71fd` |
| DOC-0463 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_weak_looks_batch_REPLY.md` | `Git history` | 0 | `197ef247018939734384e70f9560ca335442e304` |
| DOC-0464 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Kathleen_worn_clothing.md` | `Git history` | 0 | `274752af0077f0115eae926c96d5e4104215f6bf` |
| DOC-0465 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/README.md` | `Git history` | 0 | `5bc59901a5ece771ca9dca90ab5ee3a6ba91a194` |
| DOC-0466 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_Steve_fish_net.md` | `Git history` | 0 | `6bb415c321a3d479beac21cedc86739324585dc3` |
| DOC-0467 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_auto_pickup_build_REPLY.md` | `Git history` | 0 | `49d3e709da9b716655e5b0c639b05e31c26a1fa4` |
| DOC-0468 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_bed_recipe_sort.md` | `Git history` | 0 | `060ed5ad0d197c4df3aa3de6baa34dfe703cea06` |
| DOC-0469 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_bed_recipe_sort_REPLY.md` | `Git history` | 0 | `98b05d12b453fe3ce7aecd6bd1a876c49322bcdd` |
| DOC-0470 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_bow_items.md` | `Git history` | 0 | `ed464dd4c86b4487660c88c01d6d7597f6affa78` |
| DOC-0471 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_bow_items_REPLY.md` | `Git history` | 0 | `b8b32803951e8d1f9baf0733a08f21f25f4633ee` |
| DOC-0472 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_building_look_names.md` | `Git history` | 0 | `1d58098b81a368eb2fe84e32bcf63174828fcb68` |
| DOC-0473 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_building_tiers_REPLY.md` | `Git history` | 0 | `23c06bef02a0d01ffbcdf4a7bfd745c46ef60cba` |
| DOC-0474 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_campfire_pot.md` | `Git history` | 0 | `a9dcb7fdc96f3bee71dfa1d2867c10895b26ab4e` |
| DOC-0475 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_campfire_pot_REPLY.md` | `Git history` | 0 | `7dc953c8ca7d7041f85fe997321a5b93ef211372` |
| DOC-0476 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_cooking_stations.md` | `Git history` | 0 | `14c2cc6a852d4dfc471f0837f69da9ebd7f6b25c` |
| DOC-0477 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_fire_tiers_REPLY.md` | `Git history` | 0 | `699b67cc1272cf244e86e0618969ce0947f8ecf9` |
| DOC-0478 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_fish_data.md` | `Git history` | 0 | `ca6d492c0d30895ddcc955549f5800e870495664` |
| DOC-0479 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hammer_blueprints.md` | `Git history` | 0 | `010aa8e952948987cc4b4cffd8094d1a3649b4f3` |
| DOC-0480 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hammer_blueprints_BUILD1.md` | `Git history` | 0 | `3fe8f584d5323d74fddecc841a5a466b334eec99` |
| DOC-0481 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hammer_blueprints_BUILD2.md` | `Git history` | 0 | `45a4196460bdec6e65a76b9ef904eb2a64a88832` |
| DOC-0482 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hammer_blueprints_REPLY.md` | `Git history` | 0 | `b4da0033d63f5b3c145de90514095cfac9a1260e` |
| DOC-0483 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hand_fine_blueprint_stations.md` | `Git history` | 0 | `73cb48db1f5cacc2190928397464badd6e154751` |
| DOC-0484 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hand_fine_blueprint_stations_REPLY.md` | `Git history` | 0 | `565009be9fe6576833c5bfb8a45caa6610d7b54f` |
| DOC-0485 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hearth_oven_REPLY.md` | `Git history` | 0 | `3797101908f9d53cfe2e1d2adb7b7429ff028486` |
| DOC-0486 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hide_clothing.md` | `Git history` | 0 | `37ab827423f26f9388df51500cbf9f3a25e3cf66` |
| DOC-0487 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_hide_clothing_REPLY.md` | `Git history` | 0 | `cd90b63a20a88058192d4aa856c7da8d0ea13d88` |
| DOC-0488 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_island_checks.md` | `Git history` | 0 | `1e15b29c91edcf4c47c68dfcbc27e27d88a32210` |
| DOC-0489 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_item_cut_REPLY.md` | `Git history` | 0 | `c749ff984a2d2fb16f1f87313834460109b6430b` |
| DOC-0490 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_item_master.md` | `Git history` | 0 | `0925a5dc1476b244a4c9c8c9e12c6c16ae5fa66a` |
| DOC-0491 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_item_master_list.md` | `Git history` | 0 | `537df7b82396926cc7db839db07b27fe4e3df7c4` |
| DOC-0492 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_item_master_list_REPLY.md` | `Git history` | 0 | `ddfff81d9585a8072a3256637cfedd482b7ee5f0` |
| DOC-0493 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_key_woods.md` | `Git history` | 0 | `d306f3d588a0db6b60fe656565ff02e2b4761fcb` |
| DOC-0494 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_no_stack_caps_build_REPLY.md` | `Git history` | 0 | `8fd512fae3cd48da61b8c63d9206e88a2fc050d3` |
| DOC-0495 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_r1_pieces.md` | `Git history` | 0 | `c88ae217b3cef44d58d4ba8fc73a968e865ce9e5` |
| DOC-0496 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_r1_pieces_REPLY.md` | `Git history` | 0 | `e1748ad6c44b15a3b863d57ef4417f47e9932409` |
| DOC-0497 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_shore_net_look_REPLY.md` | `Git history` | 0 | `fdfc62dda0006c16c3dcd5ada89f9bd6e37ccac0` |
| DOC-0498 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_showroom_real_items.md` | `Git history` | 0 | `b13beb5a54f7affc1714661b7603e4e1aadc7abe` |
| DOC-0499 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_snare_items.md` | `Git history` | 0 | `176982918b4e4db817ab72b86673067261e6d1b5` |
| DOC-0500 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_snare_items_REPLY.md` | `Git history` | 0 | `295baa3e7f30ff316c9dd057a602a347ed14c6aa` |
| DOC-0501 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_thatch_floor_hand_REPLY.md` | `Git history` | 0 | `8662d66632a73a39835ef32559d8f26a019e14ad` |
| DOC-0502 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_tool_tiers.md` | `Git history` | 0 | `1ad5610cf1da8cf5f3326fadee85c732c1319af0` |
| DOC-0503 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_tool_tiers_REPLY.md` | `Git history` | 0 | `62c85f30f793f9caeeb9be09cb06a02a7047ad84` |
| DOC-0504 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_tools_batch1.md` | `Git history` | 0 | `66019b7144cad33ee71593e1b5a70e25e1697691` |
| DOC-0505 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_torch_head.md` | `Git history` | 0 | `88f0f26995a08af529d4bb49d61de2d4d5cedc37` |
| DOC-0506 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_torch_head_REPLY.md` | `Git history` | 0 | `7b7e5b6e212c7b195d2e55d7e0aeae64205f73ba` |
| DOC-0507 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sal_weight_audit_REPLY.md` | `Git history` | 0 | `ce58bcff78dd3a27cd29bfe9b3957871fb99e0c0` |
| DOC-0508 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_bend_swing_fade_REPLY.md` | `Git history` | 0 | `48c9f4b392e196fed62d4d31ffc2726c3055bb71` |
| DOC-0509 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_foothills_centre.md` | `Git history` | 0 | `65ec607819fd0b97193b94ebb00100f5d7929175` |
| DOC-0510 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_gullies_to_sea.md` | `Git history` | 0 | `3f401ee575e3d01b481f33d064e694f5a6baf0f6` |
| DOC-0511 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_land_types_REPLY.md` | `Git history` | 0 | `0cb63c8a8733f7f0ab14c314dfda47b897a63a5b` |
| DOC-0512 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_remove_old_builder_REPLY.md` | `Git history` | 0 | `f44bfdc6c7af7a1ccb1f8a051c5ef5cb86bfdcea` |
| DOC-0513 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_river_heads_natural.md` | `Git history` | 0 | `6b1ddf9a76c1ea9e8760f6cfaa663b6540bbe7a4` |
| DOC-0514 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_river_ore_guarantee_REPLY.md` | `Git history` | 0 | `67db2c859744b99253c6bedb9fcc0a82741ce389` |
| DOC-0515 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_seam_edge_flow.md` | `Git history` | 0 | `ad0db0680f8dd9e2182a95c6abe40ca0db73a844` |
| DOC-0516 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Sonny_tile_lake_guarantee_REPLY.md` | `Git history` | 0 | `483914d23db0470af1b1d697e572600f25b5e065` |
| DOC-0517 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Speedup_step3b_REPLY.md` | `Git history` | 0 | `6d397de7a1fdc6011f2cd1cc66b428a4adef36e7` |
| DOC-0518 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_bed_respawn_REPLY.md` | `Git history` | 0 | `8bc3f5cbe914246d2d94069c5d2f03fa6f5f07aa` |
| DOC-0519 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_biome_lookup.md` | `Git history` | 0 | `66b00b17c87ebbc458423b7c767d3ae013479e3f` |
| DOC-0520 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_bow_shoot_REPLY.md` | `Git history` | 0 | `5f3c7095b59b0e3ddb55f9b7550793c9320c582e` |
| DOC-0521 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_cave_air.md` | `Git history` | 0 | `d5a01de4f74b8ee2c670d4a901fc36805ee57689` |
| DOC-0522 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_eat_once_REPLY.md` | `Git history` | 0 | `c3924c19a7c423a5fc413faa817f87fde8066229` |
| DOC-0523 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_fall_quiet_REPLY.md` | `Git history` | 0 | `85319d656f695bbfe3ef6db3ecb333b23fef0962` |
| DOC-0524 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_fish_balance_REPLY.md` | `Git history` | 0 | `162ae612a3b6e0b5049d773a2a3a6c5a43239a9d` |
| DOC-0525 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_fish_classifier.md` | `Git history` | 0 | `1a68eceb9124c03d8b055dfd7b213bd800c9ca07` |
| DOC-0526 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_fish_schools.md` | `Git history` | 0 | `96d3cd522eabc49e36728ded440fd18df0324e5e` |
| DOC-0527 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_fish_schools_REPLY.md` | `Git history` | 0 | `d240a0aed7b47e031ddb4ca13f5a5a19f0e45a86` |
| DOC-0528 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_forest_bed_REPLY.md` | `Git history` | 0 | `a681b8c36eea6af33a308f14604f73e5784a640c` |
| DOC-0529 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_ground_quiet_REPLY.md` | `Git history` | 0 | `61f93b01ad8bccc421fd26595aaa565d04911cd4` |
| DOC-0530 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_harvest_field.md` | `Git history` | 0 | `53f8fe2f9002ce574188dd282f41e86a470c557f` |
| DOC-0531 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_hide_traps_REPLY.md` | `Git history` | 0 | `6b7f72ac70b28a5302023a943a311f4c922f265e` |
| DOC-0532 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_inner_voice_panel_REPLY.md` | `Git history` | 0 | `d6efb0aa64a3c050294f06f062ed09ae8138d74b` |
| DOC-0533 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_item_shots_REPLY.md` | `Git history` | 0 | `8c12261c8b1007d87186b323848d83bb0c31e07d` |
| DOC-0534 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_look_shots_REPLY.md` | `Git history` | 0 | `74e0eb203b626c723d87e5629fb6b70b20e913f2` |
| DOC-0535 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_new_player.md` | `Git history` | 0 | `8a29cc52d6bb8144ba1ff9d4f7a31c947beca931` |
| DOC-0536 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_piece_shots_REPLY.md` | `Git history` | 0 | `2e727e66a23b4980ca7cc72ff801229ea778e032` |
| DOC-0537 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_rig_item.md` | `Git history` | 0 | `6b89651b1ede832c49e85fe12b681f5a142b3320` |
| DOC-0538 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_rig_pieces.md` | `Git history` | 0 | `a69f7d70386353f30dd597187dd8df109bda42b4` |
| DOC-0539 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_rig_showroom.md` | `Git history` | 0 | `9863ed9a45f536aeccb2c14734d8af54c914d58a` |
| DOC-0540 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_river_head.md` | `Git history` | 0 | `499d97f98003101c23acb70ab5362fb5364e4293` |
| DOC-0541 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_river_seams.md` | `Git history` | 0 | `ae5ae0107520a6e190e0210869bb5b80f93cc465` |
| DOC-0542 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_river_settle.md` | `Git history` | 0 | `5b34f6522236abdc42b63f4491536ffc2773db61` |
| DOC-0543 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_rough_bed_REPLY.md` | `Git history` | 0 | `0f8b0f5a658f884bd7571c324d9409eeeee21292` |
| DOC-0544 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_settle_memory_REPLY.md` | `Git history` | 0 | `bded57f64fa968b25ec13162b5922ee1cf094d58` |
| DOC-0545 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_settle_sweep_REPLY.md` | `Git history` | 0 | `b96c63be467079a3e0ffc0dfd109ac191df308df` |
| DOC-0546 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_shore_net.md` | `Git history` | 0 | `707cc22ce2db638078b300b564ee85487958fb85` |
| DOC-0547 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_shot_landing_REPLY.md` | `Git history` | 0 | `0ab0349583721401845bbaa6ca48731803cdd10b` |
| DOC-0548 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_smoke_flags2_REPLY.md` | `Git history` | 0 | `8ce9be29dfac9d9e9b317ea51675da16075ba3ec` |
| DOC-0549 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_smoke_frametime.md` | `Git history` | 0 | `6b893f247f09557e7c94eacb25d4d93c7b1b3a10` |
| DOC-0550 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_sound_batch2.md` | `Git history` | 0 | `d4118c75e381f3b2f429b1d211e41701f683a447` |
| DOC-0551 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_sound_hookup_REPLY.md` | `Git history` | 0 | `ecd2d1f63dc34f6fc916a54bdcada45cc194514a` |
| DOC-0552 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_sound_menu_REPLY.md` | `Git history` | 0 | `66f23cb0e60346012cdcfc87579a02bd340b0e8c` |
| DOC-0553 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_sound_slots.md` | `Git history` | 0 | `3ccb90d93d357aebb873f11dcd62f645db3d0235` |
| DOC-0554 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_sound_test_free_REPLY.md` | `Git history` | 0 | `e729d6975bc74af55e85f0ae2c411afdcd18fa06` |
| DOC-0555 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_spawn_column_REPLY.md` | `Git history` | 0 | `c59a085324f327567e963e6b6ee7cea1c27989d4` |
| DOC-0556 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_spring_feed_REPLY.md` | `Git history` | 0 | `105d81a2e7cde892a40e527a0645b81a74e46195` |
| DOC-0557 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_thread_safety_REPLY.md` | `Git history` | 0 | `20426dfbb0d894b887b58edc62ad5e849e3797b1` |
| DOC-0558 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_wind_bus_REPLY.md` | `Git history` | 0 | `9ca8c20330f18d0ca2b763baa410b3af6b9e6b4d` |
| DOC-0559 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_wind_surf_REPLY.md` | `Git history` | 0 | `f1c28a474d0c75b6ee499b59e91a2927a8050644` |
| DOC-0560 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/Steve_worn_attach.md` | `Git history` | 0 | `a9dc76a5f096004ef63e426545b19c7ce6681127` |
| DOC-0561 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/ACTION_PLANS/cave_dark_6e40ee7.md` | `Git history` | 0 | `bb649fa2ba94a4538b1fe35787c11ca7311c037d` |
| DOC-0562 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/AUDITS/AUDIT_2026-10-23.md` | `Git history` | 0 | `9a83a6ce8ce39493bf13a7523d95114ee83a8eec` |
| DOC-0563 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/BAKE_28_MERGE.md` | `Git history` | 0 | `4cf1ced282883613c56fd643e06158422b9c6eab` |
| DOC-0564 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/BAKE_29_MERGE.md` | `Git history` | 0 | `6a89bfa64f431dafa407a44baec9517f32fb131a` |
| DOC-0565 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/BAKE_30_MERGE.md` | `Git history` | 0 | `edd428c9abc8200d39e7890eaf8bcf0ad57d3770` |
| DOC-0566 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/BAKE_31_MERGE.md` | `Git history` | 0 | `07d3635a060b814b369d29571119692c2bc1086e` |
| DOC-0567 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CARDS_TOMORROW.md` | `Git history` | 0 | `d1bba116b6e1f282d67031d003310c8c4aa2cf66` |
| DOC-0568 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS2_Kathleen.md` | `Git history` | 0 | `414992d819e4e23c36077d7455afee05c199543c` |
| DOC-0569 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS2_MikeW_LocalAgent.md` | `Git history` | 0 | `1e20cb695d2b82ed87895096fd0ed6422bfe46d6` |
| DOC-0570 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS2_Sal_Crafts.md` | `Git history` | 0 | `f33a5a51f320212b6b4b9a040e23e400e632d85c` |
| DOC-0571 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS2_Sonny.md` | `Git history` | 0 | `eda0cc9c63d7039e2d7a1a134b63651313c2822c` |
| DOC-0572 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS2_Tyler.md` | `Git history` | 0 | `dee4fd1c167c66999aca0c9097b96496c2c30956` |
| DOC-0573 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS3_MikeW_LocalAgent.md` | `Git history` | 0 | `83c6d13fbfa5244a0b35a0b1416fe8a998636916` |
| DOC-0574 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS3_Sal_Crafts.md` | `Git history` | 0 | `02d6b9e7a419d807bc4ba6730e80b64f04d221b2` |
| DOC-0575 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS3_Sonny.md` | `Git history` | 0 | `989d8e03c893bdbd855d4f099c8f93056236549f` |
| DOC-0576 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS3_Tyler.md` | `Git history` | 0 | `e796d991a29a2eca6a119c5d8808d8d708e4b5e8` |
| DOC-0577 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS_Guru.md` | `Git history` | 0 | `9d3e5366deaac85a56cff7d095e7e06aa875b7da` |
| DOC-0578 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS_Kathleen.md` | `Git history` | 0 | `33204d8700656e379d9b1d0c1ed459508b3a2e33` |
| DOC-0579 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS_MikeW_LocalAgent.md` | `Git history` | 0 | `5c96ff2e0b21e93aed8b25670e47d7b74452c3c6` |
| DOC-0580 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS_RESOLUTIONS.md` | `Git history` | 0 | `69f6e4ac4d23eb66405d4299b1faf40a4f5ca962` |
| DOC-0581 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS_Sal_Crafts.md` | `Git history` | 0 | `72aa22c761c5d6df8e0e87d0d62381f236383f67` |
| DOC-0582 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS_Sonny.md` | `Git history` | 0 | `66916f7aa234e73f96ed36e348a511852907c805` |
| DOC-0583 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/CONCERNS_Tyler.md` | `Git history` | 0 | `02034c586f494a0f4d4488e0d4c7a58cd06aeb19` |
| DOC-0584 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/DAILY_AUDIT_2026-10-24.md` | `Git history` | 0 | `c0e6093fbb4eca6434c12c09ea7e6c724b949ec7` |
| DOC-0585 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/DAVID3_HANDOVER.md` | `Git history` | 0 | `acb9be229540ad70207b285dcddb058e995b4243` |
| DOC-0586 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/DAY_LOG.md` | `Git history` | 0 | `c4953cd464cf1572a4910b2f7c20390762f31350` |
| DOC-0587 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/DIRECTIVE_REVIEW.md` | `Git history` | 0 | `eb23b337775c3709ea1bbb5dd8d34d53b64953c4` |
| DOC-0588 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/HANDOFF_Tyler_2026-10-24_2340.md` | `Git history` | 0 | `4eccf7d00b665b3566100b3955037b5dd8c06867` |
| DOC-0589 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/HANDOFF_Tyler_2026-10-25_draft.md` | `Git history` | 0 | `157e2471b99f4aae1471b1546775f5e4d11a335b` |
| DOC-0590 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/HOW_WE_WORK.md` | `Git history` | 0 | `5226ada4f7942f5992edb6e210b8e59d4d8b86a1` |
| DOC-0591 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/MERGE_CHECK_NEXT.md` | `Git history` | 0 | `1f20cb24378efce3aa2554f33e25f6530590b038` |
| DOC-0592 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/MERGE_CHECK_NEXT2.md` | `Git history` | 0 | `52ad82a1c5558e8d1c0a38bf8676a52c778b05e8` |
| DOC-0593 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/MERGE_CHECK_NEXT3.md` | `Git history` | 0 | `a3df7f030f393576db2a64a348a4518f152ddacd` |
| DOC-0594 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/MERGE_CHECK_TONIGHT.md` | `Git history` | 0 | `5f1a8d70606a3d4253b9cf91bf51768a7cf26617` |
| DOC-0595 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/NEXT_BAKE_WATER_BUNDLE.md` | `Git history` | 0 | `55c4fe9ca7d3c2e232071357ac8192f04ce2cd58` |
| DOC-0596 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/OPEN_MikeW_LocalAgent.md` | `Git history` | 0 | `3da7fb0d92e7285dc34b760768056e68cb45da67` |
| DOC-0597 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/OVERNIGHT_PLAN_2026-10-24.md` | `Git history` | 0 | `cf25db3d272e9418c9fe2a701f71e24df4153dc3` |
| DOC-0598 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/OVERNIGHT_RESULTS.md` | `Git history` | 0 | `aa860a7830b7e4e9d5f0fa2a60bec4d068ce11df` |
| DOC-0599 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/OVERNIGHT_TESTS.md` | `Git history` | 0 | `99cebbcfee0527dc01b5bc2ab9cca22ef309522c` |
| DOC-0600 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/PROCESS.md` | `Git history` | 0 | `b0dcd9dc20d82f393c2548e5de6a8271d145148e` |
| DOC-0601 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/RENDER_AUDIT.md` | `Git history` | 0 | `953f5ab0e547c367d788675bc8b595c7d89bb8b1` |
| DOC-0602 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/RETRO_DAY2.md` | `Git history` | 0 | `ca51471d3810cf761ffad5def9e5cb45c223333d` |
| DOC-0603 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/REVIEW_BRIEF.md` | `Git history` | 0 | `f27247125df77647e40b1395f3085bf3603cd1b8` |
| DOC-0604 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/REVIEW_Kathleen.md` | `Git history` | 0 | `5a6ebf1d29073af748584d6d52422ce077bada5c` |
| DOC-0605 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/REVIEW_MikeW_LocalAgent.md` | `Git history` | 0 | `c2cb238c904531fe3daf0e2804c3feddc5b74ca3` |
| DOC-0606 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/REVIEW_Sal_Crafts.md` | `Git history` | 0 | `d1520ce056d6e08b63f1e5e20b38c7f909048e4c` |
| DOC-0607 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/REVIEW_Sonny.md` | `Git history` | 0 | `a28f778dfc420d39419afc23abb6cb4b58b9ad07` |
| DOC-0608 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/REVIEW_Tyler.md` | `Git history` | 0 | `369d61a70adf3bdfc9a8c376ecc9a0f0d770b3c1` |
| DOC-0609 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/REVIEW_VERDICT.md` | `Git history` | 0 | `48a874d05678e7fe66d412dc1f5ff6ddca5c5497` |
| DOC-0610 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/TEAM_AND_RULES.md` | `Git history` | 0 | `bd62b826b0cee75820a50579489b2ad00f078c8b` |
| DOC-0611 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/TEAM_PROPOSAL.md` | `Git history` | 0 | `3530eeb36a02032a0ff3229f4896b5ab1f166a8a` |
| DOC-0612 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/TERRAIN_REVIEW.md` | `Git history` | 0 | `24b7a5a43433bf15651644bbe1249d4d2d9f82c6` |
| DOC-0613 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/TEST_CARDS_TONIGHT.md` | `Git history` | 0 | `01900b334e08e6889a968826c2fa8361927f1cd9` |
| DOC-0614 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/TEST_RECIPE_ARCHIVE_2026-10-23.md` | `Git history` | 0 | `50a87b77ec8da7be89eef2999f9acc43dbe83806` |
| DOC-0615 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tech/TEST_TONIGHT.md` | `Git history` | 0 | `f17a7ae1e405db66ddf0ebd46eead5c2e21f13ff` |
| DOC-0616 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tyler/BEST_PRACTICES.md` | `Git history` | 0 | `7937e63d07ba74d923fa5f0099d692c6f7f5ab86` |
| DOC-0617 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/docs/mirror/tyler/FINDINGS.md` | `Git history` | 0 | `c2149aac85c9b8d8e8d20a9fe9267e1b7098f9f6` |
| DOC-0618 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/handoff/Kathleen_ArtisticDirector_001_HANDOFF.md` | `Git history` | 0 | `df5f590b2b8edb500366952c291e51e96f62225b` |
| DOC-0619 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/handoff/Tyler_004_HANDOFF.md` | `Git history` | 0 | `153cb672c67e06695cb06f2d81ef75c82d93fc65` |
| DOC-0620 | Dead weight in checkout | RETIRE | `docs/archive/2026-10/handoff/Tyler_005_HANDOFF.md` | `Git history` | 0 | `92a335b60c040cb09df9f1020ddc74490273a0db` |
| DOC-0621 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/BUILDING_TIERS_LOOKS_2026-10-22.md` | `Git history` | 0 | `3703e23c842b4c60e53f3a105f451bb220da29f6` |
| DOC-0622 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/DAVE_MORNING_ITEMS.md` | `Git history` | 0 | `020f8c7e21c4ccfbfb235d8672f8b378e4c0980a` |
| DOC-0623 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/DYNASTY_WATER_STATUS.md` | `Git history` | 0 | `dc2653c971d03203f95c6ff804cd70ca53b91f7b` |
| DOC-0624 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/GENERATOR_V2_PLAN.md` | `Git history` | 0 | `f288df4828912d4e28ad02d74654f95a6f9f6d8c` |
| DOC-0625 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/HANDOFF_2026-10-29_state_and_rules_copy.md` | `Git history` | 0 | `d9d94c5f1d74f7d1a689067d079aa9cfac7b776d` |
| DOC-0626 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/HANDOFF_KATHLEEN_2026-11-01.md` | `Git history` | 0 | `7ba5484e2c2cdedd4a135ed503978bc2abd27997` |
| DOC-0627 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/HEAVY_KITS_OPTIONS.md` | `Git history` | 0 | `bb341ac836e2146094181366372d3becb5d51f8f` |
| DOC-0628 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/ITEM_CODE_HANDOFF.md` | `Git history` | 0 | `cdffdba130e49df61e43bed71e6d406fce9e9907` |
| DOC-0629 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/MERGE_WATCH.md` | `Git history` | 0 | `53165e8cf53386180234d944dafd69e766cb6eb1` |
| DOC-0630 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/PHASE7_PLAN.md` | `Git history` | 0 | `b05d4aaf79f73cb32e96acd4c0362c0cb0ab65a5` |
| DOC-0631 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/PLAYTHROUGH_PLANS.md` | `Git history` | 0 | `8a95c41c7232e2990617c76432c67505e16f39c3` |
| DOC-0632 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/SMOKE_TEST.md` | `Git history` | 0 | `56d15e8d2543dad9db083e0ce3273752faec5e05` |
| DOC-0633 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/TYLER_GATES_REVIEW.md` | `Git history` | 0 | `34c49d760478f34250f61ee84ae01e05620aa507` |
| DOC-0634 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/TYLER_NEXT_PLANS.md` | `Git history` | 0 | `b9772c129a158b0b493ff1961882ef0518c61e83` |
| DOC-0635 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/TYLER_QUEUED_TESTS.md` | `Git history` | 0 | `f446a55c354c6cdf3d60b67df169a4bb95abf26b` |
| DOC-0636 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/WATER_HANDOVER.md` | `Git history` | 0 | `4b5a607692679893b7603d9d20499ff9917a7b5e` |
| DOC-0637 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/WATER_PLAN.md` | `Git history` | 0 | `71928387b7aeab840db775c20c4111d15715f343` |
| DOC-0638 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/docs/design/items_recipe_audit.md` | `Git history` | 0 | `26b63e6e63ed04961b814ae399923df735125ec5` |
| DOC-0639 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/old_branch_plans/Sal_auto_pickup_P.md` | `Git history` | 0 | `a2b50b14ad0be480435f09f1cdf099c6a223d32a` |
| DOC-0640 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/old_branch_plans/Sal_fire_tiers.md` | `Git history` | 0 | `dc428b38615a7b2bb2f047fe59a2d397542f4c9b` |
| DOC-0641 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/old_branch_plans/Sal_no_stack_caps.md` | `Git history` | 0 | `c26a9333ed6c062323a9bb1e9915f3400f348b67` |
| DOC-0642 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/old_branch_plans/Sal_thatch_sources.md` | `Git history` | 0 | `0ca7595800df0132852c7a6939c885a661d49aed` |
| DOC-0643 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_bow_items.md` | `Git history` | 0 | `ed464dd4c86b4487660c88c01d6d7597f6affa78` |
| DOC-0644 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_campfire_pot.md` | `Git history` | 0 | `a9dcb7fdc96f3bee71dfa1d2867c10895b26ab4e` |
| DOC-0645 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_hammer_blueprints_BUILD1.md` | `Git history` | 0 | `3fe8f584d5323d74fddecc841a5a466b334eec99` |
| DOC-0646 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_hammer_blueprints_BUILD2.md` | `Git history` | 0 | `45a4196460bdec6e65a76b9ef904eb2a64a88832` |
| DOC-0647 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_hand_fine_blueprint_stations.md` | `Git history` | 0 | `73cb48db1f5cacc2190928397464badd6e154751` |
| DOC-0648 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_hide_clothing.md` | `Git history` | 0 | `37ab827423f26f9388df51500cbf9f3a25e3cf66` |
| DOC-0649 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_item_master_list.md` | `Git history` | 0 | `537df7b82396926cc7db839db07b27fe4e3df7c4` |
| DOC-0650 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_snare_items.md` | `Git history` | 0 | `176982918b4e4db817ab72b86673067261e6d1b5` |
| DOC-0651 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_tool_tiers.md` | `Git history` | 0 | `1ad5610cf1da8cf5f3326fadee85c732c1319af0` |
| DOC-0652 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Sal_torch_head.md` | `Git history` | 0 | `88f0f26995a08af529d4bb49d61de2d4d5cedc37` |
| DOC-0653 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_cave_air.md` | `Git history` | 0 | `e3b4af5b8ef28c4603020c40d78a2ec658ed5950` |
| DOC-0654 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_eat_once.md` | `Git history` | 0 | `ac8b9efc7bc3499ecb9dead59264aca5fcbf0354` |
| DOC-0655 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_fall_quiet.md` | `Git history` | 0 | `8c80e50bd79c796a88e205aea80a428d06f0d117` |
| DOC-0656 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_fish_balance.md` | `Git history` | 0 | `6f0f8b40f130a70214334de4d56d883d69d9d123` |
| DOC-0657 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_fish_classifier_NOTES.md` | `Git history` | 0 | `cfbc7929611f6b3aed233a262426c2efb3ca0864` |
| DOC-0658 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_fish_schools.md` | `Git history` | 0 | `f8eb3f87b74cd35dd34202b9cc9d19751e371e44` |
| DOC-0659 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_fish_schools_NOTES.md` | `Git history` | 0 | `324ded1deef51d8061062b4f244f8f88e325e27b` |
| DOC-0660 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_forest_bed.md` | `Git history` | 0 | `3c985a30c4f2a5d521cc03ef42e3df93326880e0` |
| DOC-0661 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_go_spawn.md` | `Git history` | 0 | `6d461a55f8f2fbcf7fc8d920b7deefbca8277084` |
| DOC-0662 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_ground_hang.md` | `Git history` | 0 | `7e478bb256c18844360b6cd8854883e091376de1` |
| DOC-0663 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_inner_voice_panel.md` | `Git history` | 0 | `2ef66c510cdffcc02c6c62ebcf744c3db2456571` |
| DOC-0664 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_item_shots.md` | `Git history` | 0 | `58c613fe01d55601b814bb7bc93b521af26a7574` |
| DOC-0665 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_look_shots.md` | `Git history` | 0 | `86f333cb31c73a18c053dcbbb330c764c15b60bf` |
| DOC-0666 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_new_player.md` | `Git history` | 0 | `526bea2eae56758117b43bc52872794964a9156e` |
| DOC-0667 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_piece_shots.md` | `Git history` | 0 | `a1bc04a69e97ee3bd688efb90980b664f9849740` |
| DOC-0668 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_rig_item.md` | `Git history` | 0 | `21e0a2c9deb21a2cbc9cb256f8a4add82b52e4fd` |
| DOC-0669 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_rough_bed.md` | `Git history` | 0 | `c5551687ef9ea86049091af52b8ef37b08e20b02` |
| DOC-0670 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_settle_memory.md` | `Git history` | 0 | `0aff2dc19d660ac6a7fcd011fa280863e74aff71` |
| DOC-0671 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_settle_sweep.md` | `Git history` | 0 | `dce7a18b01d9934b580f167118463f525b4f5bc9` |
| DOC-0672 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_shore_net.md` | `Git history` | 0 | `5f1cec8b689d0cca09de5f9a03a4145a2f068687` |
| DOC-0673 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_shot_landing.md` | `Git history` | 0 | `2dfd09cec60800b1bb91d641e604a378c65eb1e9` |
| DOC-0674 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_smoke_flags2.md` | `Git history` | 0 | `75c2ccf8f15d15fdb6c0f9fa4c28530a8dbb3561` |
| DOC-0675 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_sound_hookup.md` | `Git history` | 0 | `a079e60ddda7d819d2c25258763736455fb8369e` |
| DOC-0676 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_sound_sliders.md` | `Git history` | 0 | `37328da949e4328f79c73757d73d328f5ba3b0be` |
| DOC-0677 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_sound_test_free.md` | `Git history` | 0 | `e3611a7fcaf55e47116ec5770a1b20ca54a7c358` |
| DOC-0678 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_spawn_column.md` | `Git history` | 0 | `f80f9f01a869c59fc0ba10f81b8acd58434fe413` |
| DOC-0679 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_test_repin.md` | `Git history` | 0 | `1908ca8dbacdc15f431c635267ca411112c2f806` |
| DOC-0680 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_thread_safety.md` | `Git history` | 0 | `92991cb343049127c1d6e0cd77e633609175865f` |
| DOC-0681 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_wind_bus.md` | `Git history` | 0 | `7e6bafc74e1fabfee5704259e0f502b6cc9c0e2d` |
| DOC-0682 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/Steve_wind_surf.md` | `Git history` | 0 | `164016512e06f171f59d6a62905cf2ad88f1c494` |
| DOC-0683 | Dead weight in checkout | RETIRE | `docs/archive/2026-11/tech_ACTION_PLANS/cave_dark_6e40ee7.md` | `Git history` | 0 | `4c54f712284b8445b0bc8a1a6c0c650ec9fb4bfc` |
| DOC-0684 | Dead weight in checkout | RETIRE | `docs/archive/HANDOFF_FULL_2026-10-22.md` | `Git history` | 0 | `8a0bfcb575bea60e00e89eff5d3fa13950be1b9b` |
| DOC-0685 | Dead weight in checkout | RETIRE | `docs/archive/HANDOFF_TOPBLOCK_2026-10-23_0435.md` | `Git history` | 0 | `17af39702d03461cf04bb7ad6c6b45b46643f286` |
| DOC-0686 | Dead weight in checkout | RETIRE | `docs/archive/HANDOFF_TOPBLOCK_2026-10-24_1100.md` | `Git history` | 0 | `e5d262e62dbfe9e58eb9642e1ff74ef595bf957a` |
| DOC-0687 | Dead weight in checkout | RETIRE | `docs/archive/HANDOFF_TOPBLOCK_2026-10-25_1100.md` | `Git history` | 0 | `e9fd6bcff01b12869345104fa17c518b8e3c0041` |
| DOC-0688 | Dead weight in checkout | RETIRE | `docs/archive/old_branch_plans/BUILDING_TIERS_PLAN.md` | `Git history` | 0 | `07c15f28617566506e795e516d19c31d3a3bb8de` |
| DOC-0689 | Dead weight in checkout | RETIRE | `docs/archive/old_branch_plans/BUILDING_TIERS_TABLE.md` | `Git history` | 0 | `46e6f063f632f1de0158f5f26ad08b6a664e697a` |
| DOC-0690 | Dead weight in checkout | RETIRE | `docs/archive/old_branch_plans/Sal_auto_pickup_P.md` | `Git history` | 0 | `a2b50b14ad0be480435f09f1cdf099c6a223d32a` |
| DOC-0691 | Dead weight in checkout | RETIRE | `docs/archive/old_branch_plans/Sal_fire_tiers.md` | `Git history` | 0 | `dc428b38615a7b2bb2f047fe59a2d397542f4c9b` |
| DOC-0692 | Dead weight in checkout | RETIRE | `docs/archive/old_branch_plans/Sal_no_stack_caps.md` | `Git history` | 0 | `c26a9333ed6c062323a9bb1e9915f3400f348b67` |
| DOC-0693 | Dead weight in checkout | RETIRE | `docs/archive/old_branch_plans/Sal_thatch_sources.md` | `Git history` | 0 | `43883e8b9a5066fe682cf5c7cafa0cef126dcebb` |
| DOC-0694 | Dead weight in checkout | RETIRE | `docs/archive/old_branch_plans/Steve_bed_respawn.md` | `Git history` | 0 | `bb7ef41447409f4a25b2f8bdad7d5970e17c72fc` |
| DOC-0695 | Necessary | DEPENDENCY | `docs/buglists/BUGLIST-002.md` | `docs/buglists/BUGLIST-002.md` | 0 | `a0f928d1f90569ef6bfa33f4464fd20be0cb8e43` |
| DOC-0696 | Necessary | CONSOLIDATE | `docs/design/ADMIN_KEYBINDINGS_POLICY.md` | `CONTROLS.md` | 0 | `352b8e3c9357b95ff81dfac3967fa5c3ac3df456` |
| DOC-0697 | Helpful | CONSOLIDATE | `docs/design/ALLIGATOR_SWIMMING.md` | `ANIMAL_SPEC.md` | 0 | `51c1138be38c9df9f72bab8b294192f1e1eb48df` |
| DOC-0698 | Helpful | CONSOLIDATE | `docs/design/BAT_RIG.md` | `docs/design/art_animals.md` | 0 | `46d83c25a02bfe4ab747755fa9044840f8421fc4` |
| DOC-0699 | Necessary | CONSOLIDATE | `docs/design/CATALOG_IMPLEMENTATION_PLAN.md` | `docs/ai-team/missions/GOALS-REPAIR/STATE.md` | 0 | `ed90fdda8c8b3355f0268933a305102e789a957c` |
| DOC-0700 | Necessary | KEEP | `docs/design/CATALOG_SAVE_MIGRATION.md` | `docs/design/CATALOG_SAVE_MIGRATION.md` | 0 | `15a33403fbdabf8fd030d6fba6f6693ef4f1a9d9` |
| DOC-0701 | Helpful | CONSOLIDATE | `docs/design/CLAUDE_FOOD_STORAGE_HANDOFF.md` | `docs/design/FOOD_PREPARATION_PRESERVATION_SERVING.md` | 0 | `cca3332c4a081728667ffb7000f9ad59ab2cb7bc` |
| DOC-0702 | Helpful | CONSOLIDATE | `docs/design/CLAY_POTTERY_DESIGN.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `0a0759b78442d2964ea23db5423caf3afdc01683` |
| DOC-0703 | Helpful | CONSOLIDATE | `docs/design/DOCUMENT_CONTRADICTIONS_RECONCILED_2026-11-13.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `c8218fc903cb3dd2c13580ab0cf275edb3ecb4f8` |
| DOC-0704 | Paramount | KEEP | `docs/design/DYNASTY_MASTER_ITEMS.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 1 | `ac1b401a608d5ed9d31ac87502643b83a9e6e0bd` |
| DOC-0705 | Helpful | CONSOLIDATE | `docs/design/EYE_SHINE_AND_WET.md` | `docs/design/art_animals.md` | 0 | `2e5c4ba05f2019f9acf2e38caca55dabbd6310ab` |
| DOC-0706 | Helpful | CONSOLIDATE | `docs/design/FLIGHT_RIGS.md` | `docs/design/art_animals.md` | 0 | `ccd147646bc776d249bcbff7ad27d5f4f28ece6f` |
| DOC-0707 | Necessary | KEEP | `docs/design/FOG_DESIGN_DAVE.md` | `docs/design/FOG_DESIGN_DAVE.md` | 0 | `9ef151a029160aea33f217d85be151f2de43fcaf` |
| DOC-0708 | Helpful | CONSOLIDATE | `docs/design/FOG_F6.md` | `docs/design/FOG_DESIGN_DAVE.md` | 0 | `7e2d64ff6189623d73408291e27d487489d57a7d` |
| DOC-0709 | Helpful | CONSOLIDATE | `docs/design/FOG_PLAN.md` | `docs/design/FOG_DESIGN_DAVE.md` | 0 | `cd4a15d96472cf079ac6091f36ae673545c9f28a` |
| DOC-0710 | Necessary | KEEP | `docs/design/FOOD_PREPARATION_PRESERVATION_SERVING.md` | `docs/design/FOOD_PREPARATION_PRESERVATION_SERVING.md` | 0 | `2dcb4f33f863364fcf4748888ef3ad426c875bb2` |
| DOC-0711 | Helpful | CONSOLIDATE | `docs/design/FOOD_STORAGE_AUDIT_2026-11-12.md` | `docs/design/FOOD_PREPARATION_PRESERVATION_SERVING.md` | 0 | `73ac412a8822a02e46f2a8ed92d04c98fabb0ab6` |
| DOC-0712 | Helpful | CONSOLIDATE | `docs/design/FOOT_SLIDING.md` | `docs/design/art_animals.md` | 0 | `e6e22de54a7c30fb742b12d389c07ec854c10508` |
| DOC-0713 | Necessary | CONSOLIDATE | `docs/design/GUIDING_DOCUMENT.md` | `DESIGN_IDEAS.md` | 0 | `9fe5da6988587838d9bfb5754c71bd1a64e7c8bb` |
| DOC-0714 | Helpful | CONSOLIDATE | `docs/design/HERD_GROUPS.md` | `ANIMAL_SPEC.md` | 0 | `f4071a7eee5349144e5dbf3c2fa3efb01323aeb8` |
| DOC-0715 | Necessary | KEEP | `docs/design/HOE_GARDENING_DESIGN.md` | `docs/design/HOE_GARDENING_DESIGN.md` | 0 | `dd00a713d04464d2e9a0f0f674118f19785995c5` |
| DOC-0716 | Helpful | KEEP | `docs/design/INVENTORY_CRAFTING_LOOK.md` | `docs/design/INVENTORY_CRAFTING_LOOK.md` | 0 | `ba5211c98e592b8ab3c3c5d65c1aa77ef63eff1c` |
| DOC-0717 | Helpful | CONSOLIDATE | `docs/design/INVENTORY_CRAFTING_REPORT.md` | `docs/design/INVENTORY_CRAFTING_LOOK.md` | 0 | `f969f547bc5aa7e11f14dc4a13b7b1665d408900` |
| DOC-0718 | Helpful | CONSOLIDATE | `docs/design/KATHLEEN_PICTURE_PLAN.md` | `art/Art_Direction.md` | 0 | `785f0becde7f6956d1276e1768dbf70651fe60f0` |
| DOC-0719 | Helpful | CONSOLIDATE | `docs/design/MISSING_MODELS_BRIEF.md` | `docs/design/art_animals.md` | 0 | `99545409e165c027f610e02f102c44f5fa0b2648` |
| DOC-0720 | Helpful | CONSOLIDATE | `docs/design/MODEL_QUIRKS.md` | `docs/design/art_animals.md` | 0 | `6600c4298eb3e8f64eb87278a303d82cbf6c1c81` |
| DOC-0721 | Helpful | CONSOLIDATE | `docs/design/OVERNIGHT_DECISIONS_8NOV.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `4cc98902b39fb4e890bb1d046c804e7787649ca8` |
| DOC-0722 | Necessary | KEEP | `docs/design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md` | `docs/design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md` | 0 | `1db9f00ec6230e5cc25038a1a44b4fbbc62b44a4` |
| DOC-0723 | Helpful | RETIRE | `docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv` | `Git history` | 2 | `6abe62027b20eb9842aa219c1d32d091ff8a7676` |
| DOC-0724 | Necessary | DEPENDENCY | `docs/design/PLAYER_GOALS_CATALOG_CORRECTED.csv` | `docs/design/PLAYER_GOALS_CATALOG_CORRECTED.csv` | 0 | `2fee12e23aa110e0c6952b4e1f1d6fbfb8b737d5` |
| DOC-0725 | Necessary | KEEP | `docs/design/PLAYER_GOALS_CATALOG_CORRECTED.md` | `docs/design/PLAYER_GOALS_CATALOG_CORRECTED.md` | 0 | `b05c730924aa6af780a1b9a06b03dc6589d48a43` |
| DOC-0726 | Necessary | CONSOLIDATE | `docs/design/PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md` | `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` | 0 | `75c22b3a48ff618692e586e9e149662fb5592648` |
| DOC-0727 | Necessary | DEPENDENCY | `docs/design/PLAYER_GOALS_REWARDS_AUDIT.md` | `docs/design/PLAYER_GOALS_REWARDS_AUDIT.md` | 1 | `b54e45baeb28bb331d02b9dfb4a5a5ea3520c706` |
| DOC-0728 | Necessary | DEPENDENCY | `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` | `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` | 1 | `b8ba1d948bbdd5d7b386ecc78681f7d5e663d374` |
| DOC-0729 | Necessary | KEEP | `docs/design/PLAYER_JOURNAL_GOALS_UI.md` | `docs/design/PLAYER_JOURNAL_GOALS_UI.md` | 0 | `c9566e944cba395fc648f982af189c7245eddaaf` |
| DOC-0730 | Necessary | CONSOLIDATE | `docs/design/PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md` | `docs/ai-team/missions/GOALS-REPAIR/STATE.md` | 0 | `bd35aaba00899085ba2c02ca84c953cdfe3a5b33` |
| DOC-0731 | Necessary | KEEP | `docs/design/PLAYER_PROGRESSION_REPAIR_F6.md` | `docs/design/PLAYER_PROGRESSION_REPAIR_F6.md` | 0 | `bb473fc9e28c795e439cedd981313a566b4462ec` |
| DOC-0732 | Necessary | KEEP | `docs/design/PLAYER_PROGRESSION_REPAIR_VERIFICATION.md` | `docs/design/PLAYER_PROGRESSION_REPAIR_VERIFICATION.md` | 0 | `4c78af2491d3e5fad8cb9be989209e8762b291d2` |
| DOC-0733 | Necessary | KEEP | `docs/design/PLUMBING_DESIGN.md` | `docs/design/PLUMBING_DESIGN.md` | 0 | `b41440fea6a51fd94bc78cd7891343fdb04a8ffa` |
| DOC-0734 | Helpful | CONSOLIDATE | `docs/design/POSE_FIXES_PICTURES.md` | `docs/design/art_animals.md` | 0 | `ed9fff7650e0ad19c5eb50f8b0d3a091097d0680` |
| DOC-0735 | Necessary | KEEP | `docs/design/RESUME_SPOT.md` | `docs/design/RESUME_SPOT.md` | 0 | `b87bc54967c9aa1601c3a11f129330b0f75e9a39` |
| DOC-0736 | Necessary | KEEP | `docs/design/STORAGE_WAREHOUSING_DESIGN.md` | `docs/design/STORAGE_WAREHOUSING_DESIGN.md` | 0 | `bd38281e74c073629387c5a9b4ce636c2b3b2e04` |
| DOC-0737 | Necessary | KEEP | `docs/design/TREE_WOOD_TOOLS_DESIGN.md` | `docs/design/TREE_WOOD_TOOLS_DESIGN.md` | 0 | `174294b6dacea7dfc35df83b6d2450bdfb1ea1f2` |
| DOC-0738 | Helpful | CONSOLIDATE | `docs/design/animals_at_water_server.md` | `ANIMAL_SPEC.md` | 0 | `76fbfc62dd1b9ffaf3b22e4543347966a9a08f9a` |
| DOC-0739 | Helpful | CONSOLIDATE | `docs/design/animals_drink_client_design.md` | `docs/design/art_animals.md` | 0 | `11826a8d64b9035c2e929cdb8977d7ab5ffac75a` |
| DOC-0740 | Helpful | CONSOLIDATE | `docs/design/animals_in_fog_server.md` | `ANIMAL_SPEC.md` | 0 | `cacffac73b1752d65c7169a0756f38b2cb90aa33` |
| DOC-0741 | Helpful | KEEP | `docs/design/animals_in_weather_design.md` | `docs/design/animals_in_weather_design.md` | 0 | `f6c180b7cbc6b83ecd98f180515afe0f9dc17cbc` |
| DOC-0742 | Helpful | CONSOLIDATE | `docs/design/animals_on_ice_server.md` | `ANIMAL_SPEC.md` | 0 | `d1df86f594aaad7027c5e3c2ab73e7911cd540ae` |
| DOC-0743 | Helpful | KEEP | `docs/design/art_animals.md` | `docs/design/art_animals.md` | 0 | `9c466d6c51bb3f5a834eb10677309223db4a014a` |
| DOC-0744 | Helpful | KEEP | `docs/design/art_caves.md` | `docs/design/art_caves.md` | 0 | `50d1f0ef4b782f515eafd67a28391859e58dbba1` |
| DOC-0745 | Helpful | KEEP | `docs/design/art_mountains.md` | `docs/design/art_mountains.md` | 0 | `9acca45a162e2061c6eade940b5cb179a1fed2b8` |
| DOC-0746 | Helpful | KEEP | `docs/design/art_water.md` | `docs/design/art_water.md` | 0 | `6294faeb83561b2db28997217809c4f2a186c6b7` |
| DOC-0747 | Helpful | KEEP | `docs/design/art_weather_light.md` | `docs/design/art_weather_light.md` | 0 | `91ca02d6d07c220920e9497d55ddb1bb10b1173f` |
| DOC-0748 | Helpful | CONSOLIDATE | `docs/design/bear_threat_design.md` | `ANIMAL_SPEC.md` | 0 | `1cde31f06dafb7bb38614d317efe62f4a8eda41c` |
| DOC-0749 | Helpful | CONSOLIDATE | `docs/design/bird_flight_server_design.md` | `ANIMAL_SPEC.md` | 0 | `1b8358e92b299f536d69dda3be69d5e544dcc62c` |
| DOC-0750 | Helpful | CONSOLIDATE | `docs/design/birds_and_thunder_server.md` | `ANIMAL_SPEC.md` | 0 | `0a69f99c07e7536791c9d2b8f4665390614d3998` |
| DOC-0751 | Helpful | CONSOLIDATE | `docs/design/blueprint_gather_design.md` | `docs/design/buildables_plan.md` | 0 | `954ce879c96ee2ca0bab42fe9392ce3f069e278d` |
| DOC-0752 | Helpful | CONSOLIDATE | `docs/design/body_in_weather_design.md` | `docs/COMFORT_DESIGN.md` | 0 | `e8b97d4c18672ec13a9a60071382baaa937227bb` |
| DOC-0753 | Helpful | CONSOLIDATE | `docs/design/bow_aim_design.md` | `docs/FEEL_TUNING.md` | 0 | `6bb1c7f2accb34d96a8faae2a78b43ef2f4c1831` |
| DOC-0754 | Necessary | KEEP | `docs/design/buildables_plan.md` | `docs/design/buildables_plan.md` | 0 | `db49328f8c9e79f5acffd4c748ffbe8a6c1d142d` |
| DOC-0755 | Helpful | CONSOLIDATE | `docs/design/canopy_drip_design.md` | `docs/design/art_weather_light.md` | 0 | `7125d803c5f1504a70b69809f60b76e106efc28f` |
| DOC-0756 | Necessary | DEPENDENCY | `docs/design/catalog_ledger.json` | `docs/design/catalog_ledger.json` | 3 | `6b3ba6eb40fdf6eb3c691b0134b57f8182cc0b96` |
| DOC-0757 | Helpful | CONSOLIDATE | `docs/design/cave_climate_design.md` | `docs/design/art_caves.md` | 0 | `97fb9c2368089eb286c582d0e34685224e998b52` |
| DOC-0758 | Helpful | CONSOLIDATE | `docs/design/cave_dens_after_rebuild_design.md` | `docs/GOBLINS.md` | 0 | `1de233b6aa516f336a8171b14fc0a63decfc5bbf` |
| DOC-0759 | Helpful | CONSOLIDATE | `docs/design/cave_light_design.md` | `docs/design/art_caves.md` | 0 | `689816dbc73755eee7169529e6b0d4895ca032b4` |
| DOC-0760 | Helpful | CONSOLIDATE | `docs/design/cave_lod_carving_design.md` | `docs/design/art_caves.md` | 0 | `0b6a092e13d255069d2b1f2dbb3870cb0f74d077` |
| DOC-0761 | Helpful | CONSOLIDATE | `docs/design/chain_pictures_design.md` | `docs/water/watershed_rebuild_design.md` | 0 | `1e7f0250bfc1895147781c1e10109524e893fa6b` |
| DOC-0762 | Helpful | CONSOLIDATE | `docs/design/cover_by_season_design.md` | `docs/design/art_weather_light.md` | 0 | `fed25b84b28984634518431797d726f4b16dc821` |
| DOC-0763 | Helpful | CONSOLIDATE | `docs/design/craft_list_order_design.md` | `docs/design/INVENTORY_CRAFTING_LOOK.md` | 0 | `fe5da9e54a2092ce32b22b2054a23f63be815638` |
| DOC-0764 | Helpful | KEEP | `docs/design/dog_companion_design.md` | `docs/design/dog_companion_design.md` | 0 | `83f0180595b1a0496562b54ceff2983de28779cb` |
| DOC-0765 | Helpful | CONSOLIDATE | `docs/design/drink_prompt_design.md` | `docs/design/drinking_water_design.md` | 0 | `03a517928615491a68eb85182c92bcb0c65ddf4e` |
| DOC-0766 | Helpful | KEEP | `docs/design/drinking_water_design.md` | `docs/design/drinking_water_design.md` | 0 | `46531d58b27d6346baf3760f7f6da0cf715fa7a2` |
| DOC-0767 | Helpful | CONSOLIDATE | `docs/design/drinking_water_step2b_design.md` | `docs/design/drinking_water_design.md` | 0 | `43f08ffc8b4bc16da01673236ef751a70aa418f8` |
| DOC-0768 | Helpful | CONSOLIDATE | `docs/design/felled_crown_design.md` | `docs/design/TREE_WOOD_TOOLS_DESIGN.md` | 0 | `dcc710400ab2e785ab94e26ab27c4fca90de3429` |
| DOC-0769 | Helpful | CONSOLIDATE | `docs/design/field_journal_design.md` | `docs/design/PLAYER_JOURNAL_GOALS_UI.md` | 0 | `6a4771408becc0cf95a7e5e3332545dc3df4feb7` |
| DOC-0770 | Helpful | KEEP | `docs/design/fire_coals_design.md` | `docs/design/fire_coals_design.md` | 0 | `fec6ae827946f0a800a5a11cb9e58b57668159cb` |
| DOC-0771 | Helpful | CONSOLIDATE | `docs/design/fire_smoke_wind_design.md` | `docs/design/art_weather_light.md` | 0 | `c5c8317cad6ba0375e8fd1476289aee0fa9160b3` |
| DOC-0772 | Helpful | CONSOLIDATE | `docs/design/firelight_weather_design.md` | `docs/design/art_weather_light.md` | 0 | `b2f3eda2a86ce8ef519392178222f7b2b9c63d75` |
| DOC-0773 | Helpful | CONSOLIDATE | `docs/design/fog_pools_and_sea_fog.md` | `docs/design/FOG_DESIGN_DAVE.md` | 0 | `d0d5ca4ab7f355a67fbe9d5ceb2aadbc96c8fe60` |
| DOC-0774 | Helpful | KEEP | `docs/design/frozen_water_look.md` | `docs/design/frozen_water_look.md` | 0 | `7d0ee0d421e4c58ba185065221b2d3beecc5a6ed` |
| DOC-0775 | Helpful | CONSOLIDATE | `docs/design/glacial_speed_design.md` | `docs/water/watershed_rebuild_design.md` | 0 | `50cab3035eb93f52c7ccaff01645d7a35b92529d` |
| DOC-0776 | Helpful | KEEP | `docs/design/goblin_ally_design.md` | `docs/design/goblin_ally_design.md` | 0 | `ccec76fb28cc1fe81e871c424c1ce0edbe1b3c6a` |
| DOC-0777 | Helpful | CONSOLIDATE | `docs/design/goblin_den_life_design.md` | `docs/GOBLINS.md` | 0 | `f098afff40134f82b0e22e744378d4a16dd20ab0` |
| DOC-0778 | Helpful | CONSOLIDATE | `docs/design/goblin_friendship_step1_design.md` | `docs/GOBLINS.md` | 0 | `3fccef94be7d180196e70ddb08270ccbc9e7da33` |
| DOC-0779 | Helpful | CONSOLIDATE | `docs/design/goblin_stealing_design.md` | `docs/GOBLINS.md` | 0 | `d3c84bd4372ab2dbc53732d30945d218540b59ba` |
| DOC-0780 | Helpful | CONSOLIDATE | `docs/design/heartbeat_design.md` | `docs/FEEL_TUNING.md` | 0 | `baac855de8e7bb20f1cc697e4524c8d345813517` |
| DOC-0781 | Helpful | CONSOLIDATE | `docs/design/hunt_feedback_server.md` | `ANIMAL_SPEC.md` | 0 | `c5858298006270082043eace1a31d08427abe316` |
| DOC-0782 | Helpful | CONSOLIDATE | `docs/design/ice_walk_feel.md` | `docs/design/frozen_water_look.md` | 0 | `633da3ad82538e3b73ca8e7a4501abc7870afd41` |
| DOC-0783 | Helpful | CONSOLIDATE | `docs/design/interaction_cards_design.md` | `docs/design/INVENTORY_CRAFTING_LOOK.md` | 0 | `d736fc5d6212fd3d99055a2b7a43bab3a00dd590` |
| DOC-0784 | Necessary | CONSOLIDATE | `docs/design/item_system.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `96469c8460078a27f4e8bd0b34866ed22db1b746` |
| DOC-0785 | Helpful | CONSOLIDATE | `docs/design/no_spawn_placement_design.md` | `docs/water/watershed_rebuild_design.md` | 0 | `d5624cf044db7cebcf400640ea2b4cbf4a7bd28a` |
| DOC-0786 | Helpful | KEEP | `docs/design/one_sky_design.md` | `docs/design/one_sky_design.md` | 0 | `e4acffed94bdfa9830397703f71900644d3758f5` |
| DOC-0787 | Helpful | CONSOLIDATE | `docs/design/one_temperature.md` | `docs/design/art_weather_light.md` | 0 | `f234b32a1044894b97b12a44ede6df7d60f3fb9e` |
| DOC-0788 | Helpful | CONSOLIDATE | `docs/design/prevailing_wind.md` | `docs/design/art_weather_light.md` | 0 | `600759b05e0a11bdd53d9d2c5bdbebaca39f72f8` |
| DOC-0789 | Necessary | KEEP | `docs/design/progression.md` | `docs/design/progression.md` | 0 | `83d57cf7391162f9b491ba606ebb4bb37aafc09a` |
| DOC-0790 | Helpful | CONSOLIDATE | `docs/design/r7_plan.md` | `docs/water/watershed_rebuild_design.md` | 0 | `9e5d2502e0660cc324deb90efaa5c7c7445f479f` |
| DOC-0791 | Helpful | CONSOLIDATE | `docs/design/rain_look_design.md` | `docs/design/art_weather_light.md` | 0 | `25452d4084d42f469c520f97cc8d5e0b125d34e3` |
| DOC-0792 | Helpful | CONSOLIDATE | `docs/design/riparian_growth_design.md` | `docs/water/watershed_rebuild_design.md` | 0 | `28582e07347f0309b1b93b756fe24b3b945643cc` |
| DOC-0793 | Helpful | CONSOLIDATE | `docs/design/settle_speed_design.md` | `docs/water/watershed_rebuild_design.md` | 0 | `da973ead8ad0d511c13e8b08174b8e048dfff34e` |
| DOC-0794 | Helpful | CONSOLIDATE | `docs/design/signs_design.md` | `docs/design/PLAYER_JOURNAL_GOALS_UI.md` | 0 | `f89c00f9e5f4e2d43cbda9820209c5d2d720ab3a` |
| DOC-0795 | Helpful | KEEP | `docs/design/sound_outdoors_design.md` | `docs/design/sound_outdoors_design.md` | 0 | `dff1592da71b3cd2b6fea0b9c9a45f699631aeb4` |
| DOC-0796 | Helpful | CONSOLIDATE | `docs/design/spring_head_damp_patch.md` | `docs/water/watershed_rebuild_design.md` | 0 | `6ab1fdbf1bd9e29078525c12c0ee1313ab6bea8f` |
| DOC-0797 | Helpful | CONSOLIDATE | `docs/design/spring_heads_lower_design.md` | `docs/water/watershed_rebuild_design.md` | 0 | `53d11674facb042b7ed57406262be8a862e0c888` |
| DOC-0798 | Helpful | CONSOLIDATE | `docs/design/spring_to_river_flow.md` | `docs/water/watershed_rebuild_design.md` | 0 | `97577727d83d14e7aa46b677b2876b59daaf4010` |
| DOC-0799 | Helpful | CONSOLIDATE | `docs/design/spyglass_design.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `4b79539862c6d67745c67c7cb8ea94f935bc46c3` |
| DOC-0800 | Helpful | CONSOLIDATE | `docs/design/starter_rumours_design.md` | `docs/design/PLAYER_JOURNAL_GOALS_UI.md` | 0 | `6f9f06d7cd5f54327b6a95dda4fcce946c092db9` |
| DOC-0801 | Helpful | CONSOLIDATE | `docs/design/station_highlight_design.md` | `docs/design/INVENTORY_CRAFTING_LOOK.md` | 0 | `2973e573f1cc6e70eb90d9f8b087fb280ec429c7` |
| DOC-0802 | Helpful | CONSOLIDATE | `docs/design/still_water_ice.md` | `docs/design/frozen_water_look.md` | 0 | `3c658516cecebf0f320948e5ef93da430c638b47` |
| DOC-0803 | Helpful | CONSOLIDATE | `docs/design/thunder_delay_design.md` | `docs/design/art_weather_light.md` | 0 | `f69b9f984804ad22310b946e9ea6e4426e70405b` |
| DOC-0804 | Helpful | CONSOLIDATE | `docs/design/trees_weather_design.md` | `docs/design/art_weather_light.md` | 0 | `70a2ad305fbfd1f1f4d58e6d83d925fad4a5bd3f` |
| DOC-0805 | Helpful | CONSOLIDATE | `docs/design/valley_fog.md` | `docs/design/FOG_DESIGN_DAVE.md` | 0 | `b84e1eaa37531b7a23c07710a019fc5042cf35b1` |
| DOC-0806 | Helpful | CONSOLIDATE | `docs/design/water_look_after_rain.md` | `docs/design/art_water.md` | 0 | `e6cdc8582dc9b17d4bbd618c6f3adc38513c9aef` |
| DOC-0807 | Helpful | CONSOLIDATE | `docs/design/wolf_packs_and_pups_design.md` | `ANIMAL_SPEC.md` | 0 | `6dba4e10831f2902cd946c1c78e879aba87c0b41` |
| DOC-0808 | Helpful | CONSOLIDATE | `docs/design/wolf_pup_taming_design.md` | `docs/design/dog_companion_design.md` | 0 | `410ed71051a5a92e1e5ee005f2bb07549b1f01d9` |
| DOC-0809 | Helpful | CONSOLIDATE | `docs/design/wood_tier_note.md` | `docs/design/buildables_plan.md` | 0 | `6943491f6ca500f376134f8d9612a530861e88ff` |
| DOC-0810 | Dead weight in checkout | RETIRE | `docs/handoff/DINO_BUG_CHECKS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `6d052d9d9bc7e6c4e4f59356b9a73b1bb1057cc4` |
| DOC-0811 | Dead weight in checkout | RETIRE | `docs/handoff/DINO_ROUND1_REPORT.md` | `docs/ai-team/WORKFLOW.md` | 0 | `0edaff5a789f5b937f98b180fa548a1efe472b0b` |
| DOC-0812 | Dead weight in checkout | RETIRE | `docs/handoff/DINO_ROUND2_REPORT.md` | `docs/ai-team/WORKFLOW.md` | 0 | `9b097e6dcc2273b7407a499ee00889e2a66955cc` |
| DOC-0813 | Dead weight in checkout | RETIRE | `docs/handoff/DINO_ROUND3_PC_COMMANDS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `a5f56e23395a96b7bf1fa5d7fde85da7d1da833a` |
| DOC-0814 | Dead weight in checkout | RETIRE | `docs/handoff/DINO_ROUND4_HINTS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `1c2a9e1b9b96c3123e653fab8efb568c8e6e0ad7` |
| DOC-0815 | Dead weight in checkout | RETIRE | `docs/handoff/DINO_ROUND5_EARLY_GAME.md` | `docs/ai-team/WORKFLOW.md` | 0 | `1aad3ba064138fb2291ce673c351e8b73a24a8bb` |
| DOC-0816 | Dead weight in checkout | RETIRE | `docs/handoff/DINO_ROUND6_GOALS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `ae924bd66f480584e0a7eef7ca17286673f49dad` |
| DOC-0817 | Dead weight in checkout | RETIRE | `docs/handoff/FINDINGS_REPORT.md` | `docs/ai-team/WORKFLOW.md` | 0 | `2f39cf3fdffc4aa1a34abe5dbf09e17d618d669c` |
| DOC-0818 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_DINO.md` | `docs/ai-team/WORKFLOW.md` | 0 | `86d9919ea939897b5f3e9d6d62217da3b857fd15` |
| DOC-0819 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_JASON.md` | `docs/ai-team/WORKFLOW.md` | 0 | `c8391a4b4eb486f6e2532aa47aa07871b6b500dd` |
| DOC-0820 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_KATHLEEN.md` | `docs/ai-team/WORKFLOW.md` | 0 | `233c9d3328ea3efc50ef332bd6d5391630cbfa3a` |
| DOC-0821 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_KATHREEN.md` | `docs/ai-team/WORKFLOW.md` | 0 | `87cb2ca37376e0fcf80c7525f4ca76ed8b8b76ae` |
| DOC-0822 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_MIKEW.md` | `docs/ai-team/WORKFLOW.md` | 0 | `ee2326eb2c0a0794cfbef22d9b67fa9c82c90cc1` |
| DOC-0823 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_MODERATOR.md` | `docs/ai-team/WORKFLOW.md` | 0 | `74dc310c34264654953cf2bafc93dbcf1794cb06` |
| DOC-0824 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_SAL.md` | `docs/ai-team/WORKFLOW.md` | 0 | `ec98370a6079db3c43d1a369be3040a32ffd57a3` |
| DOC-0825 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_SONNY.md` | `docs/ai-team/WORKFLOW.md` | 0 | `9f896c2395a2fdcaa2b825df0c57d8de84a785e8` |
| DOC-0826 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_STEVE.md` | `docs/ai-team/WORKFLOW.md` | 0 | `27f77658ca20d5f614809bf24b68aa831fbaf8aa` |
| DOC-0827 | Dead weight in checkout | RETIRE | `docs/handoff/HANDOFF_TYLER.md` | `docs/ai-team/WORKFLOW.md` | 0 | `2f68446c3002c91ce21c9db1252b18f8aa001928` |
| DOC-0828 | Dead weight in checkout | RETIRE | `docs/handoff/JASON_NEXT_TASKS.md` | `docs/ai-team/WORKFLOW.md` | 0 | `12139ea18fb576b6d2a9d88d91fa8f435da3a7d7` |
| DOC-0829 | Dead weight in checkout | RETIRE | `docs/handoff/PHASE2_RUNBOOK.md` | `docs/ai-team/WORKFLOW.md` | 0 | `5d9bb9c458997b7f516d53a91dbb3ceab6aa861b` |
| DOC-0830 | Dead weight in checkout | RETIRE | `docs/handoff/SAL_SPECS_FOR_STEVE.md` | `docs/ai-team/WORKFLOW.md` | 0 | `59968abba197d339db53b1c931c04a33cbd7649c` |
| DOC-0831 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_DINO.md` | `docs/ai-team/WORKFLOW.md` | 0 | `78de880475255ca6da78b8dbbe0596e10f9d62b0` |
| DOC-0832 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_JAMIE.md` | `docs/ai-team/WORKFLOW.md` | 0 | `80ad324b576cf6992e912dc0d1fe8685cabaa1ff` |
| DOC-0833 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_JASON.md` | `docs/ai-team/WORKFLOW.md` | 0 | `63c12bd5a8f34868a8ca98168066ac6753e94735` |
| DOC-0834 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_KATHLEEN.md` | `docs/ai-team/WORKFLOW.md` | 0 | `e8a989764f785e7057af28424c2a33511b0737cd` |
| DOC-0835 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_KATHREEN.md` | `docs/ai-team/WORKFLOW.md` | 0 | `83907bd593952c1e5b14c052747e075485bed9b4` |
| DOC-0836 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_MIKEW.md` | `docs/ai-team/WORKFLOW.md` | 0 | `7698f7195541c75bebdb782f8597e402287b3563` |
| DOC-0837 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_MODERATOR.md` | `docs/ai-team/WORKFLOW.md` | 0 | `c7a9be07aee9cec814e54ff394259905042a47d7` |
| DOC-0838 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_SAL.md` | `docs/ai-team/WORKFLOW.md` | 0 | `3f1952813d9fa16dd1c71ef3d5ee324c8ee7894c` |
| DOC-0839 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_SONNY.md` | `docs/ai-team/WORKFLOW.md` | 0 | `785a6e281cf348c52448d340d35989e374ff2f55` |
| DOC-0840 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_STEVE.md` | `docs/ai-team/WORKFLOW.md` | 0 | `629c924669fa7cf24ae000230f802a494835a104` |
| DOC-0841 | Dead weight in checkout | RETIRE | `docs/handoff/SCOPE_TYLER.md` | `docs/ai-team/WORKFLOW.md` | 0 | `ecad0f99d428d0d0e261d75bbd1fd674ed544bdf` |
| DOC-0842 | Helpful | CONSOLIDATE | `docs/knowledge/CONTRADICTIONS.md` | `docs/ai-team/DECISION_AUTHORITY.md` | 0 | `12b4e3cab0829531d48b351f5a1e933a67f100f5` |
| DOC-0843 | Necessary | KEEP | `docs/knowledge/README.md` | `docs/knowledge/README.md` | 1 | `c6b2027ff8b469d478569ebdce48e8ec537e10dc` |
| DOC-0844 | Helpful | CONSOLIDATE | `docs/knowledge/animal-behaviour.md` | `ANIMAL_SPEC.md` | 0 | `390504ae5a90222f8243ed12daca7d79216812b7` |
| DOC-0845 | Helpful | CONSOLIDATE | `docs/knowledge/animal-tracks-sign.md` | `ANIMAL_SPEC.md` | 0 | `e4f192c4050608cc49357cc429fdd0f449d95502` |
| DOC-0846 | Helpful | CONSOLIDATE | `docs/knowledge/animals-in-weather.md` | `ANIMAL_SPEC.md` | 0 | `ace9418fe815749e6db019fc9b27d465b1b4b3b7` |
| DOC-0847 | Helpful | CONSOLIDATE | `docs/knowledge/animals-on-ice-and-snow.md` | `ANIMAL_SPEC.md` | 0 | `2c4edd94e0d31cf3364e23355cb02ce0b6025a02` |
| DOC-0848 | Helpful | CONSOLIDATE | `docs/knowledge/body-in-weather.md` | `docs/COMFORT_DESIGN.md` | 0 | `0d1d77add2ad9cf37107b2c9a583eb1128fc5ab9` |
| DOC-0849 | Helpful | CONSOLIDATE | `docs/knowledge/breath-and-steam-in-cold.md` | `docs/COMFORT_DESIGN.md` | 0 | `827787ec3e201d1f1a07ff9bbe21417ed78bffd6` |
| DOC-0850 | Helpful | CONSOLIDATE | `docs/knowledge/cave-microclimate.md` | `docs/design/art_caves.md` | 0 | `97dd54991defd036ee00f6cb83f2896319606f9d` |
| DOC-0851 | Helpful | CONSOLIDATE | `docs/knowledge/caves.md` | `docs/design/art_caves.md` | 0 | `d08bd869cc815111208a2f2e17f458e080fe12c3` |
| DOC-0852 | Helpful | CONSOLIDATE | `docs/knowledge/cirques-and-horns.md` | `docs/design/art_mountains.md` | 0 | `796863d421fdf19c8f29f7a6c93cc8e3c03c4c2f` |
| DOC-0853 | Helpful | CONSOLIDATE | `docs/knowledge/creature-models.md` | `docs/design/art_animals.md` | 0 | `c479f7a3d1e71e646708fdd088a0c4ca348414ff` |
| DOC-0854 | Helpful | CONSOLIDATE | `docs/knowledge/fire-outdoors.md` | `docs/design/fire_coals_design.md` | 0 | `b2bf14154ecc294d5e652eb4b3fd1ef3ddf85b40` |
| DOC-0855 | Helpful | CONSOLIDATE | `docs/knowledge/firelight-in-weather.md` | `docs/design/art_weather_light.md` | 0 | `2a829f584a11cea9a028c7395835f372f2e12dd2` |
| DOC-0856 | Helpful | CONSOLIDATE | `docs/knowledge/foam-falls-rapids.md` | `docs/design/art_water.md` | 0 | `fab6821e513f5cc27de2c3a06624934c7bdaa093` |
| DOC-0857 | Helpful | CONSOLIDATE | `docs/knowledge/fog-and-visibility.md` | `docs/design/FOG_DESIGN_DAVE.md` | 0 | `4072b7c63215cfad9dfe4c2c222ec952abf1efe4` |
| DOC-0858 | Helpful | CONSOLIDATE | `docs/knowledge/glaciers-mountains.md` | `docs/design/art_mountains.md` | 0 | `5db8f72e038d2f1a2f812e0dd6974f40a4f1b6d1` |
| DOC-0859 | Helpful | CONSOLIDATE | `docs/knowledge/groundwater-layers-recession.md` | `docs/water/watershed_rebuild_design.md` | 0 | `03659023abef8aaeeb5c3d0d9d304981274e2c7c` |
| DOC-0860 | Necessary | CONSOLIDATE | `docs/knowledge/guiding-document.md` | `docs/ai-team/WORKFLOW.md` | 0 | `4e64915bbff727794645b989cc255d558816412b` |
| DOC-0861 | Helpful | CONSOLIDATE | `docs/knowledge/hearing-distance-weather.md` | `docs/design/sound_outdoors_design.md` | 0 | `7e087081b48f52bee2ca27be9cb4e21f8fdc9df6` |
| DOC-0862 | Helpful | CONSOLIDATE | `docs/knowledge/moonlight-starlight.md` | `docs/design/one_sky_design.md` | 0 | `36a526fb2ace739e44ba04c0382d4e0215dbf662` |
| DOC-0863 | Helpful | CONSOLIDATE | `docs/knowledge/one-sky.md` | `docs/design/one_sky_design.md` | 0 | `2a9e5a6fb99f83aff11aab7376c76520fba3613b` |
| DOC-0864 | Helpful | CONSOLIDATE | `docs/knowledge/prevailing-wind-34s.md` | `docs/design/art_weather_light.md` | 0 | `a934dbba4bfa72f6d3e69833931ba2bccd23f527` |
| DOC-0865 | Helpful | CONSOLIDATE | `docs/knowledge/prevailing-wind-57s.md` | `docs/design/art_weather_light.md` | 0 | `a62eede24898d0cc6aef3496ca65aa96c67d4faf` |
| DOC-0866 | Helpful | CONSOLIDATE | `docs/knowledge/rivers-floodplains.md` | `docs/water/watershed_rebuild_design.md` | 0 | `9d796e078f2982ceeda91b11de127e05329a42d8` |
| DOC-0867 | Helpful | CONSOLIDATE | `docs/knowledge/sea-and-shore.md` | `docs/water/watershed_rebuild_design.md` | 0 | `be31d2394b76661d266816e80eef789ed06d991f` |
| DOC-0868 | Helpful | CONSOLIDATE | `docs/knowledge/snow-lines-mountain-climate.md` | `docs/design/art_mountains.md` | 0 | `c2613959eee2b797721bc6b240d2862f20e581cb` |
| DOC-0869 | Helpful | CONSOLIDATE | `docs/knowledge/snow-on-slopes.md` | `docs/design/art_mountains.md` | 0 | `32c569b7559622461a846c1c80176c404da79af3` |
| DOC-0870 | Helpful | CONSOLIDATE | `docs/knowledge/soils-ground-wetness.md` | `docs/water/watershed_rebuild_design.md` | 0 | `34a27877dacd88f86ebf4de44c1dcb9762abf71c` |
| DOC-0871 | Helpful | CONSOLIDATE | `docs/knowledge/sound-outdoors.md` | `docs/design/sound_outdoors_design.md` | 0 | `a9fb054ea5e58894d1603590d9a2ff9ad3c13d9a` |
| DOC-0872 | Helpful | CONSOLIDATE | `docs/knowledge/specific-yield.md` | `docs/water/watershed_rebuild_design.md` | 0 | `9aba145d77bd8bd1c188f5296faf5d2885b50eac` |
| DOC-0873 | Helpful | CONSOLIDATE | `docs/knowledge/springs-and-brooks-in-winter.md` | `docs/water/watershed_rebuild_design.md` | 0 | `990ac073accafb7fb37185c9f9554ddafff0533d` |
| DOC-0874 | Helpful | CONSOLIDATE | `docs/knowledge/torches-fire.md` | `docs/design/fire_coals_design.md` | 0 | `73a1c7dd020feda963d6b2c0ec4b5dca24547d72` |
| DOC-0875 | Helpful | CONSOLIDATE | `docs/knowledge/trees-in-weather.md` | `docs/design/art_weather_light.md` | 0 | `917b546d44e0cee08b263cac74f705499f7edab8` |
| DOC-0876 | Helpful | CONSOLIDATE | `docs/knowledge/underground-climate.md` | `docs/design/art_caves.md` | 0 | `b882b34b0c60baf06deea61080c425ec33829304` |
| DOC-0877 | Helpful | CONSOLIDATE | `docs/knowledge/upland-streams-numbers.md` | `docs/water/watershed_rebuild_design.md` | 0 | `4d01cdc02f9a06b971964e804b495a5b7b131ea1` |
| DOC-0878 | Helpful | CONSOLIDATE | `docs/knowledge/warmth-weather.md` | `docs/COMFORT_DESIGN.md` | 0 | `ee0d0ab7ba90173da4aa886d03b9706160b50717` |
| DOC-0879 | Helpful | CONSOLIDATE | `docs/knowledge/water-clarity-after-rain.md` | `docs/design/art_water.md` | 0 | `a9e8608d762193dbf300f200aff37e6998f63226` |
| DOC-0880 | Helpful | CONSOLIDATE | `docs/knowledge/water.md` | `docs/water/watershed_rebuild_design.md` | 0 | `b00f74ff54748eae7555aff1384320d4c61a8c40` |
| DOC-0881 | Helpful | CONSOLIDATE | `docs/knowledge/weather-water-sounds.md` | `docs/design/sound_outdoors_design.md` | 0 | `cca8a2b1be99272edd271658ea3df0702ab918b2` |
| DOC-0882 | Helpful | CONSOLIDATE | `docs/knowledge/wind-over-terrain.md` | `docs/design/art_weather_light.md` | 0 | `6f2d5a2d9ca880c91055632f5a65fd13470b9cb7` |
| DOC-0883 | Dead weight in checkout | RETIRE | `docs/mirror/CONTROLS.md` | `Git history` | 0 | `8f8b4b04052db487efccf020faacfb2cf3ec5376` |
| DOC-0884 | Dead weight in checkout | RETIRE | `docs/mirror/README.md` | `Git history` | 0 | `2942a27e74938d3e50c6d8b565c6cb77489eff4a` |
| DOC-0885 | Dead weight in checkout | RETIRE | `docs/mirror/art/PBR_DOWNLOADS.md` | `Git history` | 0 | `c6f70f999059494ae2b55cf665cb718451b77645` |
| DOC-0886 | Dead weight in checkout | RETIRE | `docs/mirror/design/BUILDING_TIERS_AUDIT.md` | `Git history` | 0 | `4f68daf25b776a1750a770c222190790b0b25e7a` |
| DOC-0887 | Dead weight in checkout | RETIRE | `docs/mirror/design/CRAFTING_STATIONS_RULE.md` | `Git history` | 0 | `814337fad2af7660b7f97f90ed0233c4cd836be4` |
| DOC-0888 | Dead weight in checkout | RETIRE | `docs/mirror/design/EARLY_GAME_LIST.md` | `Git history` | 0 | `12519caf99c76b647b62556703b78e20472bf64c` |
| DOC-0889 | Dead weight in checkout | RETIRE | `docs/mirror/design/EARLY_GAME_PRINCIPLES.md` | `Git history` | 0 | `5ecf2654dd7bb96f608ec65db8fde23f8474dd3d` |
| DOC-0890 | Dead weight in checkout | RETIRE | `docs/mirror/design/FIRST_HOUR_WALKTHROUGH.md` | `Git history` | 0 | `4f074ff18de08b12b4239aee59807b1585b8e2bc` |
| DOC-0891 | Dead weight in checkout | RETIRE | `docs/mirror/design/FISH_AND_FISHING_PLAN.md` | `Git history` | 0 | `4516c1750d14f05e1c39062e617c758e359d48a5` |
| DOC-0892 | Dead weight in checkout | RETIRE | `docs/mirror/design/GATE_AUDIT.md` | `Git history` | 0 | `d9722f78c1487e12e51875ba2795ce45eeab0852` |
| DOC-0893 | Dead weight in checkout | RETIRE | `docs/mirror/design/GATE_BEFORE_AFTER.md` | `Git history` | 0 | `25443218fef7e213498702e9246f45a7e0480ac8` |
| DOC-0894 | Dead weight in checkout | RETIRE | `docs/mirror/design/GATE_FIX_PLAN.md` | `Git history` | 0 | `81c1243952ea5466a746311d8c4d95cdd55d8994` |
| DOC-0895 | Dead weight in checkout | RETIRE | `docs/mirror/design/ITEM_TRIM_DECISIONS.md` | `Git history` | 0 | `6d695500da777405cf445ea02e2b2d756b5bab46` |
| DOC-0896 | Dead weight in checkout | RETIRE | `docs/mirror/design/ITEM_TRIM_LIST.md` | `Git history` | 0 | `bd0aae162f3e85a257abaf3dd1a0a611a48c63dc` |
| DOC-0897 | Dead weight in checkout | RETIRE | `docs/mirror/design/PLAYABILITY_PREP.md` | `Git history` | 0 | `ffd967071638a128562b8d1ca4fe2eb7893993b7` |
| DOC-0898 | Dead weight in checkout | RETIRE | `docs/mirror/design/QA_ANSWERS_24OCT.md` | `Git history` | 0 | `66b3db34cbc6c60c37abc86805233c7025f5d930` |
| DOC-0899 | Necessary | DEPENDENCY | `docs/mirror/design/TOOL_TIERS.md` | `docs/mirror/design/TOOL_TIERS.md` | 1 | `0b3546813001d4e1a0c4d2e44bb7144eaa1a41cf` |
| DOC-0900 | Dead weight in checkout | RETIRE | `docs/mirror/design/WATER_ACTION_PLANS.md` | `Git history` | 0 | `e541606352943a4d560521c46b91710954e67cbb` |
| DOC-0901 | Dead weight in checkout | RETIRE | `docs/mirror/design/WATER_LAND_TYPES.md` | `Git history` | 0 | `3f69acf5e29183fe1d6a87e0773b7d305b93db3f` |
| DOC-0902 | Dead weight in checkout | RETIRE | `docs/mirror/design/research/Tyler_Valheim.md` | `Git history` | 0 | `765f48a889378ec5dcda7ad248c48c619acf89f3` |
| DOC-0903 | Dead weight in checkout | RETIRE | `docs/mirror/items/ANIMALS_DESIGN.md` | `Git history` | 0 | `1017875bcc619b016b0e8e329608c390b18befc5` |
| DOC-0904 | Dead weight in checkout | RETIRE | `docs/mirror/items/ANIMAL_ART_NEEDS.md` | `Git history` | 0 | `d2028e245abfec85aa8b99b3c6d63ae3cf0c1163` |
| DOC-0905 | Dead weight in checkout | RETIRE | `docs/mirror/items/ANIMAL_ROSTER_CARD.md` | `Git history` | 0 | `de38102584286056651619f163ca1d94b6cbab70` |
| DOC-0906 | Dead weight in checkout | RETIRE | `docs/mirror/items/ARMOUR_LADDER.md` | `Git history` | 0 | `3d5179a9473ab80cb8994399a0de8fa264d00b91` |
| DOC-0907 | Dead weight in checkout | RETIRE | `docs/mirror/items/BALANCE.md` | `Git history` | 0 | `9734d7d468fd6b93ae52837506a4ed180d634d3f` |
| DOC-0908 | Dead weight in checkout | RETIRE | `docs/mirror/items/BRACING_ITEMS.md` | `Git history` | 0 | `28e48d10ea5d85bc85b98ab4137a759e26e17bcb` |
| DOC-0909 | Dead weight in checkout | RETIRE | `docs/mirror/items/CHOPPING_BLOCK_DESIGN.md` | `Git history` | 0 | `50dc8d0a99d25861fe20a43b300e298251a90f78` |
| DOC-0910 | Dead weight in checkout | RETIRE | `docs/mirror/items/CLOTHING_AND_WARMTH_DESIGN.md` | `Git history` | 0 | `0fd816b191c4b9aa6ed8d269735ed6b3f25e9bd0` |
| DOC-0911 | Dead weight in checkout | RETIRE | `docs/mirror/items/COINS.md` | `Git history` | 0 | `5cf18e0df50421a47f403c0c9041e7b58aecc42c` |
| DOC-0912 | Dead weight in checkout | RETIRE | `docs/mirror/items/CRAFT_QUEUE_DESIGN.md` | `Git history` | 0 | `b9f5e8c6c78d040591ff1f8c3d98d6c1fc6d4987` |
| DOC-0913 | Dead weight in checkout | RETIRE | `docs/mirror/items/DEATH_RESPAWN_DESIGN.md` | `Git history` | 0 | `ee968826e1a233310456281d37d7c79993a59618` |
| DOC-0914 | Dead weight in checkout | RETIRE | `docs/mirror/items/DIG_UNDER_TREES_DESIGN.md` | `Git history` | 0 | `33964e02128cac1d643ef8589f0514b686c2b852` |
| DOC-0915 | Dead weight in checkout | RETIRE | `docs/mirror/items/DISHES.md` | `Git history` | 0 | `abaf444eea1496fde5c938ecc47be6ac7df84fd5` |
| DOC-0916 | Dead weight in checkout | RETIRE | `docs/mirror/items/DROP_AUDIT.md` | `Git history` | 0 | `25ae2f33ee2398ab651281dad3ee73b856c6db05` |
| DOC-0917 | Dead weight in checkout | RETIRE | `docs/mirror/items/EXERTION_TOOLS.md` | `Git history` | 0 | `8f8bfba52f9439c5b716e3eee7c4e6247999e8f5` |
| DOC-0918 | Dead weight in checkout | RETIRE | `docs/mirror/items/FISHING_COOKING_POLISH.md` | `Git history` | 0 | `fe54ee2e5643149649e5677ab3f1ab36fd15e9bf` |
| DOC-0919 | Dead weight in checkout | RETIRE | `docs/mirror/items/FOOD_SPOILAGE_DESIGN.md` | `Git history` | 0 | `9db64c00acca59724fcdbb4e06a55e4010f59437` |
| DOC-0920 | Dead weight in checkout | RETIRE | `docs/mirror/items/HUNTING_PREREQUISITES.md` | `Git history` | 0 | `04708e44f231399d71b335326a82d41e0dd08d0c` |
| DOC-0921 | Dead weight in checkout | RETIRE | `docs/mirror/items/INVENTORY_TAB_AUDIT.md` | `Git history` | 0 | `a212a7fa79793fab448d10bd198bf4046ebd7136` |
| DOC-0922 | Dead weight in checkout | RETIRE | `docs/mirror/items/LUCK_DESIGN.md` | `Git history` | 0 | `9489417b0870831d62ac37a0fcf067067f66ac4b` |
| DOC-0923 | Dead weight in checkout | RETIRE | `docs/mirror/items/LUCK_NUMBERS.md` | `Git history` | 0 | `aeee25534d0978a74d19137fb650cfd714963a06` |
| DOC-0924 | Dead weight in checkout | RETIRE | `docs/mirror/items/NPC_DESIGN.md` | `Git history` | 0 | `a689233aff27ad4ee169ac40d6ed2402891e47c6` |
| DOC-0925 | Dead weight in checkout | RETIRE | `docs/mirror/items/RECIPE_GRAPH.md` | `Git history` | 0 | `6740442b9d970c9932876f5378cec8d2a2a3b766` |
| DOC-0926 | Dead weight in checkout | RETIRE | `docs/mirror/items/SHELTER_CHEST_DESIGN.md` | `Git history` | 0 | `cfeec8a7de47e6e7ff07e86201347896c9a9d436` |
| DOC-0927 | Dead weight in checkout | RETIRE | `docs/mirror/items/SKILLS_AND_ATTRIBUTES.md` | `Git history` | 0 | `7b2bded193b0b994711eacb91ef5ea1b174f550d` |
| DOC-0928 | Dead weight in checkout | RETIRE | `docs/mirror/items/SKILLS_WEB_DESIGN.md` | `Git history` | 0 | `8cb1a8041402a9568635b5bc2e7e95cc744bec5f` |
| DOC-0929 | Dead weight in checkout | RETIRE | `docs/mirror/items/SLEEP_DESIGN.md` | `Git history` | 0 | `ed12791fab27149ba735b6484859e41f74ae8142` |
| DOC-0930 | Dead weight in checkout | RETIRE | `docs/mirror/items/STATION_TIERS_DESIGN.md` | `Git history` | 0 | `6900fde1166a0ef896ae7618343f90b1c521b3dc` |
| DOC-0931 | Dead weight in checkout | RETIRE | `docs/mirror/items/STRESS_20_PLAYERS.md` | `Git history` | 0 | `32d26710218f1df63b472bfc3927e18437f33746` |
| DOC-0932 | Dead weight in checkout | RETIRE | `docs/mirror/items/TEST_WALKTHROUGH.md` | `Git history` | 0 | `26a9b06b3c053987cf26134d40e99884f6beaebd` |
| DOC-0933 | Dead weight in checkout | RETIRE | `docs/mirror/items/TOOL_WEAR.md` | `Git history` | 0 | `71c45addf650712acb5fb8921ab84395acd4b692` |
| DOC-0934 | Dead weight in checkout | RETIRE | `docs/mirror/items/VITALS_DESIGN.md` | `Git history` | 0 | `f4d0596a93aa691e2ac27ce3d32987812397b94d` |
| DOC-0935 | Dead weight in checkout | RETIRE | `docs/mirror/items/WATER_CONTAINERS_DESIGN.md` | `Git history` | 0 | `8a8a103e5cf5f8b9aebc7bda2d2eebe3abf1e3b1` |
| DOC-0936 | Dead weight in checkout | RETIRE | `docs/mirror/items/WEIGHTS_AUDIT.md` | `Git history` | 0 | `26832b57a6f3c890915ee2dd9aef76a28b2dc731` |
| DOC-0937 | Dead weight in checkout | RETIRE | `docs/mirror/items/WOLF_CARD.md` | `Git history` | 0 | `c7840b7e924cf11222265b6e5ba7138788722fe7` |
| DOC-0938 | Dead weight in checkout | RETIRE | `docs/mirror/tech/AI_PROVIDER_CONTRACT.md` | `Git history` | 0 | `0accfa8810079a99046c995e2b703f844091b4f9` |
| DOC-0939 | Dead weight in checkout | RETIRE | `docs/mirror/tech/BACKUP_PLAN.md` | `Git history` | 0 | `ca8153987e765f82c29e0d89c67fa2e315d86142` |
| DOC-0940 | Dead weight in checkout | RETIRE | `docs/mirror/tech/BEST_PRACTICES.md` | `Git history` | 0 | `8d3e7c73cccd1f23718638df0cde62473e47caea` |
| DOC-0941 | Dead weight in checkout | RETIRE | `docs/mirror/tech/BOTS.md` | `Git history` | 0 | `c45a713dbed5833258910bdb7e46d71389a73b92` |
| DOC-0942 | Dead weight in checkout | RETIRE | `docs/mirror/tech/BP_DIGESTS.md` | `Git history` | 0 | `a5b5f18cfb83fa9e81c70c21b06875252a6ed29e` |
| DOC-0943 | Dead weight in checkout | RETIRE | `docs/mirror/tech/BUG_LIST.md` | `Git history` | 0 | `58662f73cb045f1c345a0a9d7e5b460abf4dc50b` |
| DOC-0944 | Dead weight in checkout | RETIRE | `docs/mirror/tech/BUILD_LOG.md` | `Git history` | 0 | `fee6bf5db493a8b1de794bc5006f15d869b4be9a` |
| DOC-0945 | Dead weight in checkout | RETIRE | `docs/mirror/tech/CAMERA_TURN_RECIPE.md` | `Git history` | 0 | `ffe06b4335d4600405364053df084ce9935b6ff1` |
| DOC-0946 | Dead weight in checkout | RETIRE | `docs/mirror/tech/CAVE_IN_DEATH_DESIGN.md` | `Git history` | 0 | `647a7e2677303c901a62dac5b78f411f104e6aed` |
| DOC-0947 | Dead weight in checkout | RETIRE | `docs/mirror/tech/COVER_QUERY.md` | `Git history` | 0 | `c5e89bda11ff2a65f18892f4f0ddf47606e53f6f` |
| DOC-0948 | Dead weight in checkout | RETIRE | `docs/mirror/tech/DAILY_HANDOFF.md` | `Git history` | 0 | `f4d994672577f90eac08a948f883cf3c3fbb554b` |
| DOC-0949 | Dead weight in checkout | RETIRE | `docs/mirror/tech/DECISIONS.md` | `Git history` | 0 | `90857abcb7f2e82e29dd7755a4c29f69b8d2c3cd` |
| DOC-0950 | Dead weight in checkout | RETIRE | `docs/mirror/tech/DESIGN_CHANGELOG.md` | `Git history` | 0 | `1b2587649f6a9bd3e6f48794f3522de1c34a2960` |
| DOC-0951 | Dead weight in checkout | RETIRE | `docs/mirror/tech/DESIGN_COVERAGE.md` | `Git history` | 0 | `58f7ebc65159d9efb1d8df03eb090a25c753fc75` |
| DOC-0952 | Dead weight in checkout | RETIRE | `docs/mirror/tech/DESIGN_ROLE_MAP.md` | `Git history` | 0 | `1f6af5125118e7844b8e669dbf84b2afc0f97e61` |
| DOC-0953 | Dead weight in checkout | RETIRE | `docs/mirror/tech/DROWNING_DESIGN.md` | `Git history` | 0 | `92f4f4c512c1db2d7f76ba457b1416c4a658afc1` |
| DOC-0954 | Dead weight in checkout | RETIRE | `docs/mirror/tech/EROSION_RESEARCH_24OCT.md` | `Git history` | 0 | `7878f659bfedfabeaef80b05208b7e93a59b4e94` |
| DOC-0955 | Dead weight in checkout | RETIRE | `docs/mirror/tech/EXCAVATION_BRACING_GROUND_DESIGN.md` | `Git history` | 0 | `21718543b7e2cc272f4128743e9ed48fcf3971cd` |
| DOC-0956 | Dead weight in checkout | RETIRE | `docs/mirror/tech/FALL_COORDS_POND_B.md` | `Git history` | 0 | `6334ccb1acc1ab31cdf0e2bb83e590bad09e9bb9` |
| DOC-0957 | Dead weight in checkout | RETIRE | `docs/mirror/tech/FITNESS_NOTE.md` | `Git history` | 0 | `69fedca0c9890a4dec16df6e574344fda8d63ff1` |
| DOC-0958 | Dead weight in checkout | RETIRE | `docs/mirror/tech/FLAKY_TESTS.md` | `Git history` | 0 | `12707d3487c0c0d67f8af7899469e29e86299862` |
| DOC-0959 | Dead weight in checkout | RETIRE | `docs/mirror/tech/FRAMETIME.md` | `Git history` | 0 | `7fa4f1479e9ac35edcc79c8ad97df8e1f40a7f37` |
| DOC-0960 | Dead weight in checkout | RETIRE | `docs/mirror/tech/GOALS.md` | `Git history` | 0 | `f6b9c535c8383d57f87a11be9f2376c5884cb33a` |
| DOC-0961 | Dead weight in checkout | RETIRE | `docs/mirror/tech/GROUND_COMPACTION_DESIGN.md` | `Git history` | 0 | `85c8563eafe375c9d4448b6763c8c964aa9fefa1` |
| DOC-0962 | Dead weight in checkout | RETIRE | `docs/mirror/tech/ICE_DESIGN.md` | `Git history` | 0 | `c6062d13bb69c384ffdeca5637ec81efa7d721d0` |
| DOC-0963 | Dead weight in checkout | RETIRE | `docs/mirror/tech/IDEAS.md` | `Git history` | 0 | `bbc6f5b97a754d8f9f9d56c9cb4fae71e5a9ef6b` |
| DOC-0964 | Dead weight in checkout | RETIRE | `docs/mirror/tech/ID_CLAIMS.md` | `Git history` | 0 | `eb16eaa4d66027ae40afda7c89c18989429ceffe` |
| DOC-0965 | Dead weight in checkout | RETIRE | `docs/mirror/tech/IMPLEMENTATION_PLAN.md` | `Git history` | 0 | `8ec1dc86fcbedd2444dbfe12f9787abe163a6a45` |
| DOC-0966 | Dead weight in checkout | RETIRE | `docs/mirror/tech/ISLAND_SHAPE_PLAN.md` | `Git history` | 0 | `1a7d75b26b7c579345dfd326f1b141fcb7486e82` |
| DOC-0967 | Dead weight in checkout | RETIRE | `docs/mirror/tech/ISLAND_SHAPE_RESEARCH.md` | `Git history` | 0 | `66aa617cb8f726905b8f5c406757e62834936c30` |
| DOC-0968 | Dead weight in checkout | RETIRE | `docs/mirror/tech/ITEM_MASTER.md` | `Git history` | 0 | `5c0791d2c6369d1b9526d367168c8f5ac14647e5` |
| DOC-0969 | Dead weight in checkout | RETIRE | `docs/mirror/tech/JOBS.md` | `Git history` | 0 | `db78648e3d6b91f7e382c190e92417cfbaaffccb` |
| DOC-0970 | Dead weight in checkout | RETIRE | `docs/mirror/tech/LAPTOP_SETUP.md` | `Git history` | 0 | `5cff0c5e74c0d1e9badc728a10945f5ce414aed2` |
| DOC-0971 | Dead weight in checkout | RETIRE | `docs/mirror/tech/LESSONS.md` | `Git history` | 0 | `a919f81aa72e606ca6fb7d618d9b8710f33c64f1` |
| DOC-0972 | Dead weight in checkout | RETIRE | `docs/mirror/tech/NUMBER_RESERVATIONS.md` | `Git history` | 0 | `6854a4c9df99c90338c5d22a8977d4b1f8dfee12` |
| DOC-0973 | Dead weight in checkout | RETIRE | `docs/mirror/tech/OCEAN_DIG_NOTE.md` | `Git history` | 0 | `d94c3e3b05bf1adf9b5e2be529c3ec38ea1e72bc` |
| DOC-0974 | Dead weight in checkout | RETIRE | `docs/mirror/tech/OCEAN_WATER_NOTE.md` | `Git history` | 0 | `40e7292bf60fcdf0b5ca0850f864627ea965ae23` |
| DOC-0975 | Dead weight in checkout | RETIRE | `docs/mirror/tech/OPEN_ITEMS_TEMPLATE.md` | `Git history` | 0 | `8e5057ad7826ebc1cc0166ca7c4363bd47774110` |
| DOC-0976 | Dead weight in checkout | RETIRE | `docs/mirror/tech/PHOTOREAL_RESEARCH_24OCT.md` | `Git history` | 0 | `48447757977eb514cf93e867d008037032f4e856` |
| DOC-0977 | Dead weight in checkout | RETIRE | `docs/mirror/tech/PLAN_CHECKLISTS.md` | `Git history` | 0 | `738474ecd01fe237479ae6eb4dbe8c1c45191251` |
| DOC-0978 | Dead weight in checkout | RETIRE | `docs/mirror/tech/PLAYTESTER_IDEA.md` | `Git history` | 0 | `8abec59bb03e3c8651a199ce6b72cf7e3e7428de` |
| DOC-0979 | Dead weight in checkout | RETIRE | `docs/mirror/tech/PROJECT_DEBRIEF_KIT.md` | `Git history` | 0 | `3519164ca6024c1b8962f1e6dfa7f4a862545a9a` |
| DOC-0980 | Dead weight in checkout | RETIRE | `docs/mirror/tech/QA_POSTING_HOWTO.md` | `Git history` | 0 | `d97a1f0eed9eb8269c6efee57bebbaf244eccba6` |
| DOC-0981 | Dead weight in checkout | RETIRE | `docs/mirror/tech/QA_SYSTEM.md` | `Git history` | 0 | `6f02eaabcaa5c9ea75551553c6b018951c0b1dcf` |
| DOC-0982 | Dead weight in checkout | RETIRE | `docs/mirror/tech/RESTART_CHECKLIST.md` | `Git history` | 0 | `73842a0e7c5674bb063ff32a471e94c4ba26dd0a` |
| DOC-0983 | Dead weight in checkout | RETIRE | `docs/mirror/tech/RESTORE_PROCEDURE.md` | `Git history` | 0 | `c4fb43b0093dd5e9a262ddc65d4dfcc53a3fe6af` |
| DOC-0984 | Dead weight in checkout | RETIRE | `docs/mirror/tech/RIVER_START_NOTES.md` | `Git history` | 0 | `d70d70a5f1700dc3f16452e01111393e28f8b905` |
| DOC-0985 | Dead weight in checkout | RETIRE | `docs/mirror/tech/SAVED_GROUND_EDITS_DESIGN.md` | `Git history` | 0 | `1ec7bca7ba9854d0b787203319e9ae1a981951ab` |
| DOC-0986 | Dead weight in checkout | RETIRE | `docs/mirror/tech/SCALE_PLAN.md` | `Git history` | 0 | `c67cddca11ec3ac15851011ce25adde2ca87a2d3` |
| DOC-0987 | Dead weight in checkout | RETIRE | `docs/mirror/tech/SERVER_FOR_TESTS.md` | `Git history` | 0 | `c516acc45e71b232dbe2aca27417bd2ca7e65b32` |
| DOC-0988 | Dead weight in checkout | RETIRE | `docs/mirror/tech/SOUND_GAPS.md` | `Git history` | 0 | `43a3b602aa2c90a78ecd11766b8c266d70c3c3dc` |
| DOC-0989 | Dead weight in checkout | RETIRE | `docs/mirror/tech/STANDARD_SHOTS.md` | `Git history` | 0 | `f9df43e30465f032b3abbae6fa1467e2f66fd9cf` |
| DOC-0990 | Dead weight in checkout | RETIRE | `docs/mirror/tech/TEAM_TESTS.md` | `Git history` | 0 | `51659c1e7047c4b768874b81e517af8285611d18` |
| DOC-0991 | Dead weight in checkout | RETIRE | `docs/mirror/tech/TEST_BASELINE.md` | `Git history` | 0 | `9ca1a16da4e2bf7a5025bff8f7adc7fa9da5b71e` |
| DOC-0992 | Dead weight in checkout | RETIRE | `docs/mirror/tech/TEST_QUEUE.md` | `Git history` | 0 | `bd5ea2878904e6bbf94b41d44ac0034dc9d97798` |
| DOC-0993 | Dead weight in checkout | RETIRE | `docs/mirror/tech/TEST_RECIPE.md` | `Git history` | 0 | `b94a5f3eb3470776be1643222e11acefd08750a0` |
| DOC-0994 | Dead weight in checkout | RETIRE | `docs/mirror/tech/TILE_BORDER_WATER_DESIGN.md` | `Git history` | 0 | `b99e192bea94d60c1480b6a3d1e20440dd2269a2` |
| DOC-0995 | Dead weight in checkout | RETIRE | `docs/mirror/tech/TRACE.md` | `Git history` | 0 | `0043547fe35104db787c3ddc37ffbc2eb854c396` |
| DOC-0996 | Dead weight in checkout | RETIRE | `docs/mirror/tech/WATER_COST_REPORT.md` | `Git history` | 0 | `4067d109f94af8819e53e21e0ed207f273c0cc29` |
| DOC-0997 | Dead weight in checkout | RETIRE | `docs/mirror/tech/WATER_FLOOD_PLAN.md` | `Git history` | 0 | `f641e19e758fbdadd7a73bb9812c82567646b6dc` |
| DOC-0998 | Dead weight in checkout | RETIRE | `docs/mirror/tech/WATER_NINE_TILES_PLAN.md` | `Git history` | 0 | `6788d20030e06c2dbe037a2f20fb53fbf267b643` |
| DOC-0999 | Dead weight in checkout | RETIRE | `docs/mirror/tech/WATER_OPTIONS_RESEARCH.md` | `Git history` | 0 | `0047712f596f306c0bea6b6db46602809fda89e1` |
| DOC-1000 | Dead weight in checkout | RETIRE | `docs/mirror/tech/items/BLUEPRINT_BUILD_DESIGN.md` | `Git history` | 0 | `f5ed8385a56838e6e328d99d2b053460395c2a4f` |
| DOC-1001 | Dead weight in checkout | RETIRE | `docs/mirror/tech/items/ROCK_PILE_DESIGN.md` | `Git history` | 0 | `8ffcc19d84d4b7f560ba6ec3aaec86c5c01038ab` |
| DOC-1002 | Dead weight in checkout | RETIRE | `docs/mirror/tech/items/TREE_SPECIES_USES_DRAFT.md` | `Git history` | 0 | `85267182a65a240e7f7ff0756ba0667be3ea66d7` |
| DOC-1003 | Dead weight in checkout | RETIRE | `docs/mirror/tech/items/TREE_SPECIES_USES_V1.md` | `Git history` | 0 | `8071d79bba28e2d579c1f7a84999847ddd77bb87` |
| DOC-1004 | Nice to have | CONSOLIDATE | `docs/ui/inventory_crafting_redesign.md` | `docs/design/INVENTORY_CRAFTING_LOOK.md` | 0 | `02b390c6e71d8aca50e05e3ce015dfb3bcd0cfda` |
| DOC-1005 | Nice to have | CONSOLIDATE | `docs/ui/item_icons.md` | `docs/design/INVENTORY_CRAFTING_LOOK.md` | 0 | `994dda1d2882aefabfb9b997b3b8546a46cc95fe` |
| DOC-1006 | Helpful | KEEP | `docs/water/Dynasty_How_Natural_Watersheds_Work.md` | `docs/water/Dynasty_How_Natural_Watersheds_Work.md` | 0 | `947e315905b59328e5d920d1b10f243e2d388ce9` |
| DOC-1007 | Helpful | KEEP | `docs/water/Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md` | `docs/water/Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md` | 0 | `e7909562006ba8de7834756e1e2804760b601ec2` |
| DOC-1008 | Helpful | CONSOLIDATE | `docs/water/fine_drawing_2m.md` | `docs/water/watershed_rebuild_design.md` | 0 | `ff3a0e4e62551c4f97116fe525fdb24527788e4d` |
| DOC-1009 | Helpful | CONSOLIDATE | `docs/water/follow_players_2m.md` | `docs/water/watershed_rebuild_design.md` | 0 | `dac49735effae5f0229e59eedd03394727cd3653` |
| DOC-1010 | Helpful | CONSOLIDATE | `docs/water/follow_region_repair.md` | `docs/water/watershed_rebuild_design.md` | 0 | `ae6573307d4b95174638eb6ee7eca32ae31e6358` |
| DOC-1011 | Helpful | CONSOLIDATE | `docs/water/generation_cost_audit.md` | `docs/water/watershed_rebuild_design.md` | 0 | `3a92c1638183deb4d607642a9f4e5bb7967585d1` |
| DOC-1012 | Helpful | CONSOLIDATE | `docs/water/glacial_summit_fix.md` | `docs/water/watershed_rebuild_design.md` | 0 | `a9892ed3966e8366646631555c8844bab4c245fc` |
| DOC-1013 | Helpful | CONSOLIDATE | `docs/water/ocean_m5.md` | `docs/water/watershed_rebuild_design.md` | 0 | `a2d064df1c9b6cec3331e6f24a7d006bde9a5593` |
| DOC-1014 | Helpful | CONSOLIDATE | `docs/water/rock_uplift_note.md` | `docs/water/watershed_rebuild_design.md` | 0 | `7ac0ff9f215f623271452f3de23e4b365e40e4dd` |
| DOC-1015 | Helpful | CONSOLIDATE | `docs/water/rule6_build_plan.md` | `docs/water/watershed_rebuild_design.md` | 0 | `faae5ec67e2cf341ca2a0ad9f68cef1bb7a532d4` |
| DOC-1016 | Helpful | CONSOLIDATE | `docs/water/rule6_what_dave_sees.md` | `docs/water/watershed_rebuild_design.md` | 0 | `24bde3840c8ebd7d9c1bfcda01a9b1c9d56bae7e` |
| DOC-1017 | Helpful | CONSOLIDATE | `docs/water/runtime_inventory.md` | `docs/water/watershed_rebuild_design.md` | 0 | `116f3c55fc84d6f403f2d15021490a67b0d5bb5c` |
| DOC-1018 | Helpful | KEEP | `docs/water/spring_store_build_plan.md` | `docs/water/spring_store_build_plan.md` | 0 | `c61026842e3347a50d71b257e3d2f0db1d71adeb` |
| DOC-1019 | Helpful | CONSOLIDATE | `docs/water/springs_and_drinking_water.md` | `docs/design/drinking_water_design.md` | 0 | `c92f5791493b7920f39cba4748c53ca890f4a96d` |
| DOC-1020 | Helpful | KEEP | `docs/water/stage_e_readers_design.md` | `docs/water/stage_e_readers_design.md` | 0 | `901540dfa4009675f40cf4211f1cd6d3adde8d9e` |
| DOC-1021 | Helpful | KEEP | `docs/water/watershed_rebuild_design.md` | `docs/water/watershed_rebuild_design.md` | 0 | `4eb2939300ae243e998ac0063dc636b9b6b777b4` |
| DOC-1022 | Nice to have | CONSOLIDATE | `items/BLUEPRINT_BUILD_DESIGN.md` | `docs/design/buildables_plan.md` | 0 | `18c1dc4a130ab38c1e968686ee71fb3996d3402b` |
| DOC-1023 | Nice to have | RETIRE | `mutation_results/lk1.txt` | `Git history` | 0 | `f3d5f1707b9622e2b807abd56af87105071d211e` |
| DOC-1024 | Necessary | CONSOLIDATE | `proposed_removals/README.md` | `docs/ai-team/WORKFLOW.md` | 0 | `b64fb120465d5b802100936a8449bb81dc73eff5` |
| DOC-1025 | Necessary | DEPENDENCY | `proposed_removals/REMOVALS.md` | `proposed_removals/REMOVALS.md` | 1 | `a82837c68f911a72940221b1663aa017571a3147` |
| DOC-1026 | Necessary | DEPENDENCY | `proposed_removals/docs/HEAVY_KITS_OPTIONS.md` | `proposed_removals/docs/HEAVY_KITS_OPTIONS.md` | 0 | `2bfea59625b20be1bdcdeb0d8019d404ceb96c5a` |
| DOC-1027 | Necessary | DEPENDENCY | `proposed_removals/tools/island_queue.txt` | `proposed_removals/tools/island_queue.txt` | 0 | `189b87a0c04a314522a888b5f0a370c8e92f895e` |
| DOC-1028 | Necessary | DEPENDENCY | `src/sullivan_water/README.md` | `src/sullivan_water/README.md` | 0 | `608b1f105f23ceb287e9b03db4a96211ea3e6f3f` |
| DOC-1029 | Nice to have | CONSOLIDATE | `tech/ACTION_PLANS/Sal_hammer_blueprints.md` | `docs/design/buildables_plan.md` | 0 | `010aa8e952948987cc4b4cffd8094d1a3649b4f3` |
| DOC-1030 | Nice to have | CONSOLIDATE | `tech/ACTION_PLANS/Sal_shore_net_look.md` | `art/Art_Direction.md` | 0 | `d388ebbfa523c76f0d05b0ae442138830740de47` |
| DOC-1031 | Nice to have | CONSOLIDATE | `tech/ACTION_PLANS/Steve_bow_shoot.md` | `docs/FEEL_TUNING.md` | 0 | `bec45b1993fb3a767d973e249f65dc224c3d7d4c` |
| DOC-1032 | Nice to have | CONSOLIDATE | `tech/ACTION_PLANS/Steve_ground_quiet.md` | `ARCHITECTURE_BUDGET.md` | 0 | `1ad11b922dcf98b8a01f86c6bc961ddb9ccdf7a3` |
| DOC-1033 | Nice to have | CONSOLIDATE | `tech/ACTION_PLANS/Steve_hide_traps.md` | `docs/design/DYNASTY_MASTER_ITEMS.md` | 0 | `e36c036babfec277f2a58dd3cd1b260aaa0a3f8b` |
| DOC-1034 | Nice to have | CONSOLIDATE | `tech/ACTION_PLANS/Steve_shot_lock.md` | `docs/FEEL_TUNING.md` | 0 | `c36d925c62a39cebeaa4a6ff0bc6c5b1aadd2e5f` |
| DOC-1035 | Nice to have | CONSOLIDATE | `tech/ACTION_PLANS/Steve_spring_feed.md` | `docs/water/watershed_rebuild_design.md` | 0 | `f185e719426fe9b40751f858b9fdb9232c5cc972` |
| DOC-1036 | Nice to have | CONSOLIDATE | `tech/TEST_BASELINE_PC.md` | `docs/ai-team/TEST_GATES.md` | 0 | `331bcb87be5d4022e6a9a15c125583304c8b27f0` |
| DOC-1037 | Necessary | DEPENDENCY | `tools/erosion_precarve/README.md` | `tools/erosion_precarve/README.md` | 0 | `b0379d09c67df90a0a20c9c788d71f11e2004f98` |
| DOC-1038 | Necessary | DEPENDENCY | `tools/known_red.txt` | `tools/known_red.txt` | 0 | `5c89cf7842e7cd5006137a7563082c495205d584` |
| DOC-1039 | Necessary | DEPENDENCY | `tools/pc_queue.example.txt` | `tools/pc_queue.example.txt` | 0 | `637e9611f5b8e7d735ee2afd71888a5ed3726a4f` |
| DOC-1040 | Necessary | DEPENDENCY | `tools/test_args.txt` | `tools/test_args.txt` | 0 | `3af9b7960e1989875db6408858b7f2f489e8b523` |
| DOC-1041 | Necessary | DEPENDENCY | `tools/warning_baseline.txt` | `tools/warning_baseline.txt` | 0 | `d9e1d9ecd77973e59b9fdf9e48eb8f92d15eed18` |
| DOC-1042 | Necessary | DEPENDENCY | `tools/watershed/README.md` | `tools/watershed/README.md` | 0 | `3ad0b1bcf1f7e6fc661fa0287a61faa0a0674aea` |
| DOC-1043 | Necessary | DEPENDENCY | `worlds/base_world/plan/buildable_summary.txt` | `worlds/base_world/plan/buildable_summary.txt` | 0 | `e26a242d4a9d95de28ea3de4dc47bdfdaacc6f86` |
| DOC-1044 | Necessary | DEPENDENCY | `worlds/base_world/plan/matrix_summary.txt` | `worlds/base_world/plan/matrix_summary.txt` | 0 | `7de621688e0275c300666ed60131a3b1289131bb` |
| DOC-1045 | Necessary | DEPENDENCY | `worlds/base_world/plan/sketch_summary.txt` | `worlds/base_world/plan/sketch_summary.txt` | 0 | `e60b412d346877019b5e649346966589736f5d0e` |
| DOC-1046 | Necessary | DEPENDENCY | `worlds/base_world/plan/tile_plan_summary.txt` | `worlds/base_world/plan/tile_plan_summary.txt` | 0 | `573b616b39e9051ed51705ef22deb7db5b38f7b8` |
| DOC-1047 | Necessary | DEPENDENCY | `worlds/base_world/regions/README.md` | `worlds/base_world/regions/README.md` | 0 | `8631155723010ba0e4ff0286f3d5e9ba5387bdfa` |
| DOC-1048 | Necessary | DEPENDENCY | `worlds/base_world/starter_cache/tiles_stamp.txt` | `worlds/base_world/starter_cache/tiles_stamp.txt` | 1 | `ba3d2295bd2e42a4e4e74dc6371c2c1c75df6de2` |

## Dependency leads

Review these literal path references before retiring or relocating their source. Mentions and readers must be distinguished during the batch.

| Document | Referencing source files |
|---|---|
| `.claude/agents/gate-reviewer.md` | `tools/check_ai_team_package.py` |
| `.claude/skills/nightly-dev-checkpoint/SKILL.md` | `tools/check_ai_team_package.py` |
| `CLAUDE.md` | `tools/check_ai_team_package.py` |
| `CONTROLS.md` | `src/worldgen/tools/test_playability_bot.gd`, `tools/check_controls.py` |
| `FIRST_DAY_GUIDE.md` | `tools/guide_vs_recipe.py` |
| `FIRST_HOUR_FOOD.md` | `tools/guide_vs_recipe.py` |
| `MORNING_PLAYTEST_CHECKLIST.md` | `tools/guide_vs_recipe.py` |
| `PLAYTHROUGH_GUIDE.md` | `tools/guide_vs_recipe.py` |
| `PROTOCOL.md` | `tools/test_deletion_rules.py` |
| `README.md` | `tools/test_deletion_rules.py` |
| `RULES.md` | `tools/check_ai_team_package.py`, `tools/test_deletion_rules.py` |
| `TARGETS.md` | `tools/world_alive.gd` |
| `TUTORIAL_FIRST_30_MIN.md` | `tools/guide_vs_recipe.py` |
| `WORLD_ALIVE_LOG.md` | `tools/world_alive.gd` |
| `art/character_proto/perf.txt` | `tools/proto_perf.gd` |
| `design/CREATURE_PROGRESS.md` | `tools/add_species.py` |
| `design/TOOL_TIERS.md` | `tools/tool_tiers.py` |
| `docs/PONYTAIL_RULES.md` | `tools/check_ai_team_package.py` |
| `docs/START_HERE.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/CONSTITUTION.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/COORDINATOR_STATE_TEMPLATE.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/DECISION_AUTHORITY.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/DOCUMENT_AUTHORITY.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/EVALUATION_CASES.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/HANDOFF_TEMPLATE.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/KNOWN_CONFLICTS.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/MIGRATION_PLAN.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/PONYTAIL_INSTALL.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/ROLE_CATALOG.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/SESSION_LIFECYCLE.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/SOURCES_AND_ASSUMPTIONS.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/TASK_BRIEF_TEMPLATE.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/TEST_GATES.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/WORKFLOW.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/package/README_FIRST.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/package/REVISION_AND_AUDIT_LOG.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/package/cowork/COORDINATOR_BOOTSTRAP.md` | `tools/check_ai_team_package.py` |
| `docs/ai-team/package/cowork/PROJECT_INSTRUCTIONS.txt` | `tools/check_ai_team_package.py` |
| `docs/archive/2026-10/docs/bake31/island_table.txt` | `tools/test_deletion_rules.py` |
| `docs/design/DYNASTY_MASTER_ITEMS.md` | `tools/catalog_ledger.py` |
| `docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv` | `docs/ai-team/missions/GOALS-AUDIT/tools/build_ledger.py`, `docs/ai-team/missions/GOALS-AUDIT/tools/write_report.py` |
| `docs/design/PLAYER_GOALS_REWARDS_AUDIT.md` | `docs/ai-team/missions/GOALS-AUDIT/tools/write_report.py` |
| `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md` | `docs/ai-team/missions/GOALS-AUDIT/tools/goals_audit.py` |
| `docs/design/catalog_ledger.json` | `src/worldgen/tools/test_armour.gd`, `src/worldgen/tools/test_tool_care.gd`, `tools/catalog_ledger.py` |
| `docs/knowledge/README.md` | `tools/test_deletion_rules.py` |
| `docs/mirror/design/TOOL_TIERS.md` | `tools/tool_tiers.py` |
| `proposed_removals/REMOVALS.md` | `tools/merge_check.py` |
| `worlds/base_world/starter_cache/tiles_stamp.txt` | `src/worldgen/tools/test_starter_cache_stamp.gd` |
