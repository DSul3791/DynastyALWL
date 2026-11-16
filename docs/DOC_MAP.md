# Dynasty — Main Design Index

Start here to find a design topic, then read its source and the relevant working record. This index routes readers; it does not repeat designs, grant approval or certify implementation. Approval, proposals, provisional choices and verification status remain in their owning records.

## Vision and ideas

| Topic | Source | Purpose |
|---|---|---|
| Game vision and future ideas | [DESIGN_IDEAS](../DESIGN_IDEAS.md) | Remaining mixed-status collection; extracted topics retain routes there. Tags alone do not verify approval. |
| Aging ideas and recorded decisions awaiting source verification | [Aging and lifespan](../Design_Ideas_Unapproved.md#aging-and-lifespan) | Proposals separate from source-unverified recorded decisions; qualifications and original-source receipt retained. No implementation or verification certification. Approved/Built records await supporting evidence. |
| Children and family growth | [Family collection](../Design_Ideas_Unapproved.md#children-and-family-growth) | Childhood/teaching, siblings and adoption; proposals and open questions separated from source-unverified recorded decisions. |
| Death and rescue | [Death collection](../Design_Ideas_Unapproved.md#death-and-rescue) | Recorded decisions, rescue proposals and open questions; [dated implementation plan](https://github.com/DSul3791/DynastyALWL/blob/b8130aecd2d6325a772c065b9e73959953f3d64a/docs/mirror/items/DEATH_RESPAWN_DESIGN.md) remains separate from current verification. |
| Succession and inheritance | [Succession collection](../Design_Ideas_Unapproved.md#succession-and-inheritance) | Handover, estate/debt/reputation, benefactor tax, household merging and check-in; recorded decisions remain source-unverified. |
| NPC population and migration | [NPC collection](../Design_Ideas_Unapproved.md#npc-population-and-migration) | Roles, births, scavengers, country folk and displacement; [technical plan](https://github.com/DSul3791/DynastyALWL/blob/b8130aecd2d6325a772c065b9e73959953f3d64a/docs/mirror/items/NPC_DESIGN.md) and [roster](../TOWN_NPC_SPEC.md) retain dated status. |
| Design principles | [DESIGN_PRINCIPLES](../DESIGN_PRINCIPLES.md) | Values and constraints behind the designs. |
| Rejected ideas | [DESIGN_REJECTED](../DESIGN_REJECTED.md) | Preserve explicit rejections and their reasons. |
| Living-world proposals | [GUIDING_DOCUMENT](design/GUIDING_DOCUMENT.md) | Living-world concepts, recorded decisions and proposals; not another operating rulebook. |
| Visual identity | [Art Direction](../art/Art_Direction.md) | The master aesthetic; specialist designs apply it. |

## Current topic routes

These retain the existing topic routes, with design sources separated from implementation records. Use the linked source's scope and status; an index entry does not make every paragraph approved.

| Topic | Design source | Scope | Working record |
|---|---|---|---|
| Item catalog and crafting definitions | [Master items](design/DYNASTY_MASTER_ITEMS.md) | Identities, names, catalog entries and recipe definitions. [Item-system reference](design/item_system.md) supports the catalog. | Goals/progression repair below |
| Production progression | [Progression](design/progression.md) | The production journey and prerequisites. | Goals/progression repair below |
| Trees, wood, tools and hauling | [Wood system](design/TREE_WOOD_TOOLS_DESIGN.md) | Felling, processing, tools, carving and transport. | [WOOD-SYSTEM state](ai-team/missions/WOOD-SYSTEM/STATE.md) |
| Construction | [Buildables](design/buildables_plan.md) | Pieces, frames, roof shapes and placement behavior; item definitions remain in the catalog. | Door records below |
| Backpacks | [Backpack design](design/BACKPACKS.md) | Backpack design and carrying rules; values and decision status stay in the source. | Relevant task record |
| Storage and fuel supply | [Storage and warehousing](design/STORAGE_WAREHOUSING_DESIGN.md) | Bins, storage movement, permissions and fuel supply. | Goals/progression repair below |
| Food | [Preparation, preservation and serving](design/FOOD_PREPARATION_PRESERVATION_SERVING.md) | Food categories, stations and workflows. | Goals/progression repair below |
| Journal and goal presentation | [Journal and Goals UI](design/PLAYER_JOURNAL_GOALS_UI.md) | Journal, HUD, automatic completion and reward presentation. | Goals/progression repair below |
| Goal catalog review | [Working walkthrough draft](design/PLAYER_GOALS_REWARDS_DRAFT.md), [corrected review catalog](design/PLAYER_GOALS_CATALOG_CORRECTED.md) | Draft authoring and review package. The corrected catalog flags pre-wood rows for regeneration from the walkthrough draft; this is not activation permission. | [Repair decisions](ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md) |
| Player map | [Cartography](design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md) | Player-discovered mapping and related design ideas. | Goals/progression repair below |
| Environment, sky and frozen-water appearance | [Environmental design](design/art_weather_light.md) | Main appearance/behavior entry; Dave's fog instruction retains authority. | [Sky math/checks](design/one_sky_design.md), [frozen-water integration/checks](design/frozen_water_look.md) |
| Fog | [Dave's fog design](design/FOG_DESIGN_DAVE.md) | Approved appearance and occurrence; technical implementation is separate. | Fog records below |
| Drinking water | [Drinking water](design/drinking_water_design.md) | Supported collection and drinking features; inspect dated subfeature records. | [Step 2b record](design/drinking_water_step2b_design.md) |
| World-water reference | [Water design](DYNASTY_WATER_DESIGN.md) | Water-system design and dated feature support; broader watershed sources are listed below. | Use the relevant current task record |
| Save compatibility | [Catalog/save policy](design/CATALOG_SAVE_MIGRATION.md) | Approved compatibility and preservation requirements. | Relevant mission verification record |
| Admin/debug input | [Keyboard policy](design/ADMIN_KEYBINDINGS_POLICY.md) | Admin/debug bindings; [CONTROLS](../CONTROLS.md) owns the controls reference. | Relevant task record |

## Working records

Keep these separate from the design: they own assignments, implementation state, assumptions, blockers and evidence. Read status there instead of copying progress into this index.

| Work area | Records | Purpose |
|---|---|---|
| Goal authoring | [Working walkthrough draft](design/PLAYER_GOALS_REWARDS_DRAFT.md), [corrected review catalog](design/PLAYER_GOALS_CATALOG_CORRECTED.md) | Current walkthrough authoring/regeneration inputs; use mission decisions for approvals, amounts and activation. |
| Goals/progression repair | [State](ai-team/missions/GOALS-REPAIR/STATE.md), [decisions](ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md) | Current mission state and scoped decisions/assumptions. |
| Repair planning | [Integration plan](design/CATALOG_IMPLEMENTATION_PLAN.md), [missing-systems plan](design/PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md) | Repair sequence and dependencies; not new gameplay authorization. |
| Repair verification | [Verification evidence](design/PLAYER_PROGRESSION_REPAIR_VERIFICATION.md), [F6 checklist](design/PLAYER_PROGRESSION_REPAIR_F6.md) | Actual checks and the player-validation checklist. |
| Wood implementation | [WOOD-SYSTEM state](ai-team/missions/WOOD-SYSTEM/STATE.md) | Phases, provisional choices, evidence and remaining player checks. |
| Doors and doorways | [Contract](ai-team/missions/BUGLIST-002/CONTRACT.md), [ledger](ai-team/missions/BUGLIST-002/LEDGER.md), [design correction](buglists/BUGLIST-002.md) | Approved task scope and actual implementation/verification records. |
| Fog implementation | [Technical plan](design/FOG_PLAN.md), [F6 checklist](design/FOG_F6.md) | Implementation details and appearance checks for the director's fog design. |

## Reviewed character and wildlife references

Separate references for distinct topics. Dated implementation notes preserve code pointers and ideas; they do not establish current behavior or approve proposals.

| Topic | Reference | Scope and status |
|---|---|---|
| Character records | [Character system](CHARACTER_SYSTEM.md) | Static 2 Nov create/save/load/delete map, with future heir/account ideas retained; later location design is in [Resume spot](design/RESUME_SPOT.md). |
| Body and animation | [Dynasty body](DYNASTY_BODY.md) | Body adoption and proportions decisions, consolidated rig/clip reference and remaining appearance ideas; dated evidence is separate from current verification. |
| Movement and action feel | [Feel tuning](FEEL_TUNING.md) | Parameter locator and recorded 2 Nov settings; current values are in the named code. |
| Comfort and Rested | [Comfort](COMFORT_DESIGN.md) | Comfort/Rested behavior, tuning, open questions and integration reference; recipes route to the master catalog. No blanket approval or runtime certification. |
| Wildlife coverage | [Animal specification](../ANIMAL_SPEC.md) | 30–31 Oct data audit/species proposals and 8 Nov alarm-group design; not a current species census or passing test certificate. |

## Further design areas — routing review pending

These sources remain available. Their inclusion preserves discoverability; it does not settle conflicting versions or promote proposals. Review them in small topic batches before choosing or consolidating authorities.

| Area | References to review |
|---|---|
| Goblins | [Goblins](GOBLINS.md) |
| Generation and natural watersheds | [Generator vision](../GENERATOR_VISION.md), [Dave's watersheds](water/Dynasty_How_Natural_Watersheds_Work.md), [watershed build design](water/watershed_rebuild_design.md) |
| Outdoor audio | [Sound outdoors](design/sound_outdoors_design.md) |
| Families, dynasty, NPCs, settlements and other future systems | [Game ideas](../DESIGN_IDEAS.md), [living-world proposals](design/GUIDING_DOCUMENT.md) |
| Supporting research | [Research index](knowledge/README.md) |

## Evidence and historical inputs

| Record | Use |
|---|---|
| [Goal audit](design/PLAYER_GOALS_REWARDS_AUDIT.md), [audit CSV](design/PLAYER_GOALS_AUDIT_LEDGER.csv) | Preserved baseline findings, not a current gameplay rulebook or player-verification result. |
| [Goal decision recovery](design/PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md) | Audit dispositions and earlier source decisions; consult current mission decisions for later rulings. |
| [Food/storage audit](design/FOOD_STORAGE_AUDIT_2026-11-12.md) | Dated evidence for its own stage, not an additional design authority. |
| [Retirement receipts](retirements.json) | Source identities and timestamps for historical material. Deletion is manual, subject to the existing recovery and dependency checks. |

## Technical contracts and operating rules

Technical references: [network protocol](../PROTOCOL.md), [world formats](../WORLD_FORMAT_SPEC.md), [performance budget](../ARCHITECTURE_BUDGET.md).

Operating authority: [Constitution](ai-team/CONSTITUTION.md), [Workflow](ai-team/WORKFLOW.md), [Test gates](ai-team/TEST_GATES.md), [Ponytail engineering method](PONYTAIL_RULES.md). [CLAUDE.md](../CLAUDE.md) remains the agent entry point. These own the process; the design index adds no alternate rules.
