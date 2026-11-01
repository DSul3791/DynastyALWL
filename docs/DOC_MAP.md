# Document map (Jamie, 1 Nov 2026)

Every markdown file in git outside `docs/archive/` (226 files), `.claude/` and `addons/`: **353 files**. Owner = who maintains it now (roles from `MODERATOR_QA_LOG.md`). Updated = date of the last commit that touched the file (not always a real content change). Verdicts come from headers, dates and cross-checks, not from reading every file; "keep" means no problem seen yet. I change nothing in an owner's document without telling the owner first. Start page for newcomers: `docs/START_HERE.md`.

Verdict words: **keep**, **FIX** (wrong or stale fact), **MERGE** (into the named file, then archive the rest), **ARCHIVE** (to `docs/archive/YYYY-MM/`, with git mv), **review** (overlap seen, owner to decide).

## Groups (not listed file by file)
| Group | Files | Owner | Updated | Verdict |
|---|---|---|---|---|
| `docs/mirror/` (tech 66, items 35, design 17, CONTROLS, README) | 120 | nobody (Technical Director retired) | last copy 22 Oct | keep frozen: `tools/merge_check.py`, `ship.sh`, `nightly_backup.py`, `RULES.md`, `HANDOFF.md` still name paths in it; its CONTROLS.md is older than the root one. Archive only after those references move |
| `tech/ACTION_PLANS/` | 49 | previous Steve/Sal (24-25 Oct) | 24-25 Oct | ARCHIVE candidate: finished plans for builds 787-826; `RULES.md`, `ground_watchdog.gd`, `data/items/bow.json`, `tools/selftest_gate_tools.sh` cite the folder, so fix those first |
| `art/CRITIQUES/` | 45 | Kathleen | 30-31 Oct | keep; Kathleen archives rounds Dave has judged |

## Documents (individually)
| Path | Owner | Purpose | Updated | Verdict |
|---|---|---|---|---|
| `ANIMAL_PRODUCTS.md` | Sal | Animal product chain (Sal, 2026-10-31) | 10-31 | keep |
| `ANIMAL_SPEC.md` | Sal | Animal and fauna spec (Sal, 2026-10-30) | 10-31 | keep |
| `ARCHITECTURE_BUDGET.md` | Tyler | Architecture and performance budget | 10-20 | keep |
| `ART_ASSET_INVENTORY.md` | Kathleen | Art asset inventory | 10-30 | keep |
| `ART_DIRECTION.md` | Kathleen | Art direction | 10-30 | keep |
| `AUDIT_ITEMS.md` | Sal | Item data audit (Sal, 2026-10-31) | 10-31 | keep |
| `BALANCE_SHEET.md` | Sal | Early-game balance sheet (Sal, 2026-10-31) | 10-31 | keep |
| `BIG_PICTURE.md` | moderator | Big picture (read this first, every thread; about 2 KB; kept current by the Te | 10-22 | FIX: roles and "paused" are from 22 Oct; point to START_HERE |
| `BUILD_ORDERS.md` | Sal | Build orders by tier (Sal, 2026-10-31) | 10-31 | keep |
| `CHARACTER_DESIGN_VISION.md` | Kathreen | Character design vision (Sonny; research and plan, 30 Oct 2026; for Dave to re | 10-31 | keep |
| `CLOTHING_WARMTH.md` | Sal | Clothing and warmth tiers (Sal, 2026-10-31) | 10-31 | keep |
| `CODE_MISMATCHES.md` | Sal | Data against Tyler's new systems: audit (Sal, 2026-10-31) | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `CONTROLS.md` | Steve | Controls | 10-31 | keep (docs/mirror/CONTROLS.md is an older copy) |
| `CRAFT_PACING.md` | Sal | Crafting time and pacing pass (Sal, 2026-10-31) | 10-31 | keep |
| `DAVE_MORNING_ITEMS.md` | Sal | Dave's morning: five things to look at in game in the item area (Sal) | 10-31 | ARCHIVE after Dave plays (one-off list, partly stale) |
| `DESIGN_IDEAS.md` | moderator | Design Vision and Ideas | 10-31 | keep; bloat risk (2074 lines): ask Dave about a split by section |
| `DESIGN_PRINCIPLES.md` | Dave/moderator | Design Principles | 10-17 | keep |
| `DESIGN_REJECTED.md` | Dave/moderator | Rejected Ideas | 10-15 | keep |
| `DIGGING_DESIGN.md` | Sonny | Digging the ground with a spade (design note, Ground loading, 2026-10-21) | 10-21 | keep |
| `ECONOMY_PLAN.md` | Sal | Trade and economy plan (Sal, 2026-10-31) | 10-31 | keep |
| `FARMING_SPEC.md` | Sal | Farming code spec for Tyler (Sal, 2026-10-31) | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `FAUNA_BY_BIOME.md` | Sal | Fauna by biome (Sal, 2026-10-31; generated from data/animals/fauna_proposal.js | 10-31 | keep |
| `FAUNA_SPAWN_PLAN.md` | Sal | Fauna spawn data plan (Sal, 2026-10-31) | 10-31 | keep |
| `FELLING_DESIGN.md` | Steve | Tree felling state: design note (2026-10-20, Items and crafting thread) | 10-20 | keep |
| `FIRST_DAY_GUIDE.md` | Sal | Your first day: one page for Dave (Sal, 2026-10-31) | 10-31 | keep |
| `FIRST_HOUR_FOOD.md` | Sal | First-hour food (Sal, 2026-10-31) | 10-31 | keep |
| `FIRST_WEEK_WALK.md` | Sal | First-week balance walk (Sal, 2026-10-31) | 10-31 | keep |
| `FISHING_DATA.md` | Sal | Fishing data (Sal, 2026-10-31) | 10-31 | keep |
| `FLINT_ORE_SPEC.md` | Sal | Flint, obsidian, ore and coal sources: data decisions and code spec (Sal, 2026 | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `FOOD_VARIETY.md` | Sal | Food variety check (Sal, 2026-10-31) | 10-31 | keep |
| `FRUIT_TREES.md` | Sal | Fruit trees: item and calendar data (Sal, 2026-10-31, for Dave's request) | 10-31 | keep |
| `FURNITURE_BALANCE.md` | Sal | Comfort furniture: cost against the first week (Sal, 2026-10-31) | 10-31 | keep |
| `GAP_PLANS.md` | Sal | Three biggest gaps: iron, leather, crops (Sal, 2026-10-31) | 10-31 | keep |
| `GENERATION_GUIDE.md` | Sonny | Modular Island Generation Guide | 10-14 | keep |
| `GENERATOR_NOTES.md` | Sonny | Generator notes: how it works, why, and what we measured | 10-30 | keep |
| `GENERATOR_V2_PLAN.md` | Sonny | New Generator Plan | 10-16 | keep |
| `GENERATOR_VISION.md` | Sonny | Generator vision (Dave, 29 Oct 2026; Claude's review and additions) | 10-29 | keep |
| `GUIDE_TASKS.md` | Dino | Guide session: self-made task rounds (standing instruction from Dave, via the  | 11-01 | keep; rename to Dino when he next edits |
| `HANDOFF.md` | moderator | NOW (29 Oct 2026) | 10-29 | FIX: state is 29 Oct (build 826); keep commands/setup, drop state and the copy of RULES |
| `HINTS_AND_CAMP_EVENTS_SPEC.md` | Sal | Hints on screen and the camp-goal events: code spec for Tyler (Sal, 2026-10-31 | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `ITEMS_DESIGN.md` | Sal | Items and inventory: design note (2026-10-20, Items and crafting thread) | 10-24 | keep |
| `ITEM_ART_REQUESTS.md` | Sal | Item art requests for Kathleen (from Sal, items) | 10-30 | keep |
| `ITEM_CHANGES_SUMMARY.md` | moderator | Every item change on branch sal-items: one page for Dave (2026-10-30) | 10-31 | keep |
| `ITEM_CODE_HANDOFF.md` | Sal | Item work that needs a code owner (one hand-off page, Sal, 2026-10-30) | 10-30 | MERGE into docs/ITEMS_HANDOVER.md (section "needs code"); code owner is Steve now |
| `ITEM_COMBAT_TIER_LIST.md` | Sal | Weapon, shield and armour tier list (proposal, names and recipes only; Sal, 20 | 10-30 | keep |
| `ITEM_DECISION_LOG.md` | moderator | Item decision log (for Dave to review) | 10-31 | keep |
| `ITEM_FARMING_GAP_CHECK.md` | Sal | Farming crops and tools gap check (Sal, 2026-10-30) | 10-30 | keep |
| `ITEM_GLOSSARY.md` | moderator | Item name glossary (generated 2026-10-30 from data/items/items.json) | 10-30 | keep |
| `ITEM_GROUPS_AND_NAMES.md` | moderator | Item groups and names: DynastyALWL | 10-30 | keep |
| `ITEM_TIER_BALANCE.md` | Sal | Tool and weapon tier balance: proposal (Sal, 2026-10-30) | 10-30 | keep |
| `LEARN_SYSTEM_SPEC.md` | Sal | Recipe learning: rule and code spec (Sal, 2026-10-31, fixes F-01) | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `LOG_SPECIES_SPEC.md` | Sal | log_* species chains: code spec for Tyler (Sal, 2026-10-31; guide finding F-11 | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `MEDICINE_CHAIN.md` | Sal | Medicine, poisons and cures (Sal, 2026-10-31) | 10-31 | keep |
| `MERGE_WATCH.md` | Tyler | Merge watch | 10-31 | keep |
| `MODERATOR_QA_LOG.md` | moderator | Night of 30-31 Oct 2026 (Dave asleep; moderator in charge) | 11-01 | keep (source of roles; first heading missing) |
| `MORNING_PLAYTEST_CHECKLIST.md` | Dino | Dave's play-test: one page (daily branch 3494d612, 31 Oct) | 10-31 | FIX: names head 3494d612; keep as Dave's page |
| `MORNING_PLAYTEST_CHECKLIST_FULL.md` | Dino | Morning playtest checklist | 10-31 | MERGE into the short checklist (status column) or ARCHIVE after Dave plays |
| `PHASE7_PLAN.md` | Sonny | Phase 7: natural rivers on, more lakes, one planned re-bake (Sonny, 31 Oct 202 | 10-31 | keep |
| `PLAYTHROUGH_BUDGET.md` | Dino | PLAYTHROUGH_BUDGET: how long each milestone takes a new player | 10-31 | review: overlaps FIRST_WEEK_WALK, CRAFT_PACING |
| `PLAYTHROUGH_CHAPTERS.md` | Dino | PLAYTHROUGH_CHAPTERS: the guide by tier | 10-31 | keep |
| `PLAYTHROUGH_FINDINGS.md` | Dino | Playthrough findings: spawn to first shelter, tools and weapons | 11-01 | keep |
| `PLAYTHROUGH_GUIDE.md` | Dino | Dynasty: your first days, from nothing to a shelter, tools and weapons | 10-31 | keep |
| `PLAYTHROUGH_PLANS.md` | Dino | Three plans toward functioning item build orders | 10-31 | review: overlaps BUILD_ORDERS.md |
| `PLAYTHROUGH_STATUS.md` | Dino | PLAYTHROUGH_STATUS (generated by art/playthrough/status_check.py) | 11-01 | keep (generated; do not edit by hand) |
| `PLAYTHROUGH_STEP_STATUS.md` | Dino | PLAYTHROUGH_STEP_STATUS: the 22 first-hour steps, which work end to end (paper | 11-01 | keep; overlaps PLAYTHROUGH_STATUS (one of them) |
| `PLAYTHROUGH_WILDLIFE.md` | Dino | PLAYTHROUGH_WILDLIFE: what lives in the game, what a new player can hunt, and  | 10-31 | keep |
| `PROJECT_ROADMAP.md` | Sonny | World Generation Roadmap | 10-14 | keep |
| `PROTOCOL.md` | Tyler | Protocol (PROTOCOL_VERSION 56, src/stream/terrain_net.gd) | 10-31 | keep (protocol version 56: verify against code before relying) |
| `QUALITY_GRADES_SPEC.md` | Sal | Quality grades: data and rules spec for Tyler (Sal, 2026-10-31) | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `README.md` | moderator | Baked Voxel Game — Modular Island Generator | 10-14 | keep (marked old generator) |
| `RULES.md` | moderator | Rules (one file; replaces TEAM_AND_RULES, HOW_WE_WORK and PROCESS, 29 Oct 2026 | 10-31 | FIX: says the team is retired and one session works; ship.sh flow vs daily branch |
| `SEASONALITY_WINTER.md` | Sal | Seasonality and the winter survival chain (Sal, 2026-10-31) | 10-31 | keep |
| `SMOKE_TEST.md` | Dino | SMOKE_TEST: the daily branch head, run through the real server and client | 10-31 | keep |
| `SOUND_AUDIT.md` | Jason | SOUND_AUDIT: cave-in rumble and rain-like sound in clear weather | 10-31 | keep; owner is Jason now (Dino wrote it) |
| `TARGETS.md` | Tyler | World-alive targets (proposal by Tyler, 31 Oct 2026) | 10-30 | keep |
| `TOWN_NPC_SPEC.md` | Sal | First-island town and NPC data spec (Sal, 2026-10-31) | 10-31 | keep |
| `TUTORIAL_FIRST_30_MIN.md` | Dino | Your first 30 minutes (tutorial script) | 10-31 | keep |
| `TYLER_GATES_REVIEW.md` | Tyler | Gate cards gates-a to gates-f: Tyler's review (30 Oct 2026) | 10-30 | ARCHIVE candidate (gate cards reviewed 30 Oct); ask Tyler |
| `TYLER_NEXT_PLANS.md` | Tyler | Tyler's next three plans (31 Oct 2026, self-approved under the moderator's sta | 10-31 | MERGE with docs/TYLER_NEXT_TASKS.md and TYLER_QUEUED_TESTS.md into one task list |
| `TYLER_QUEUED_TESTS.md` | Tyler | Tests to run when the computer is back (Tyler, 31 Oct 2026) | 10-31 | MERGE (see TYLER_NEXT_PLANS) |
| `TYLER_TEST_SYSTEM_REVIEW.md` | Tyler | Test and gate system review (Tyler, 30 Oct 2026) | 10-31 | keep |
| `WATER_GATHER_SPEC.md` | Sal | Gather from water and shore: code spec for Tyler (Sal, 2026-10-31; needed for  | 10-31 | keep; code owner not named: "for Tyler", now Steve (asked moderator) |
| `WATER_PLAN.md` | Sonny | Land and water: findings, research and plan (Sonny, 30 Oct 2026) | 10-31 | keep |
| `WORLD_ALIVE_LOG.md` | Tyler | World-alive log | 10-31 | keep (log) |
| `WORLD_FORMAT_SPEC.md` | Sonny | World Format Specification (draft) | 10-29 | keep |
| `art/ART_TASKS.md` | Kathleen | Kathleen's art task queue (standing instruction from Dave: finish, make up thr | 11-01 | keep |
| `art/BUILDING_PLAN.md` | Kathleen | Building plan: pieces, snapping and materials | 10-22 | keep |
| `art/BUILDING_TIERS_LOOKS.md` | Kathleen | Building tiers: the looks (designs) | 10-23 | keep |
| `art/BUILDING_TIERS_PLAN.md` | Kathleen | Building tiers plan (revised BUILDING_PLAN point 1) | 10-22 | keep |
| `art/ITEM_ART_STATUS.md` | Kathleen | Item art status (Kathleen) | 10-31 | keep |
| `art/WET_TUNNEL_PLAN.md` | Kathleen | Wet tunnels under water: looks and sounds (design) | 10-23 | keep |
| `art/playthrough/RIG_PLACE.md` | Dino | Placing structures for screenshots (testing only) | 10-31 | keep |
| `art/playthrough/audit.md` | Dino | Playthrough audit (generated by art/playthrough/audit_playthrough.py) | 11-01 | keep |
| `art/playthrough/smoke/notes.md` | Dino | Felling pictures (art/playthrough/world3/fell*.jpg, stump_*.jpg), 07:40 | 10-31 | keep |
| `assets/audio/CREDITS.md` | Jason | Sound credits | 10-20 | keep |
| `assets/audio/LOUDNESS.md` | Jason | Loudness table (make with `python3 assets/audio/loudness_report.py --md`) | 10-20 | keep |
| `assets/audio/README.md` | Jason | Sounds | 10-21 | keep; Jason owns sound now (was Kathleen) |
| `assets/audio/SOUND_DROP_IN.md` | Jason | Where Dave's animal recordings go (Kathleen, 2026-10-23) | 10-23 | FIX: names Kathleen; Jason now |
| `assets/audio/SOUND_PACK.md` | Jason | Sound pack manifest | 10-21 | keep |
| `assets/audio/inner_voice/README.md` | Jason | (no heading) | 10-21 | keep |
| `assets/character/README.md` | Kathreen | Ragdoll character | 10-21 | keep |
| `assets/natural_pickups/README.md` | Kathleen | Dynasty — natural pickup props | 10-20 | keep |
| `data/items/look_wishlist.md` | Sal | Look wishlist for Kathleen (Sal, 2026-10-31) | 10-31 | keep |
| `design/GATE_BEFORE_AFTER.md` | Tyler | Gate before/after (Tyler, 28 Oct 2026). Plan: GATE_FIX_PLAN.md | 10-28 | keep |
| `design/TOOL_TIERS.md` | Sal | Tool tiers | 10-25 | keep |
| `docs/COMFORT_DESIGN.md` | Sal | Comfort and the Rested buff (Sal, 2026-10-31) [Proposed] | 10-31 | keep (design/data Sal; rules Steve) |
| `docs/DYNASTY_WATER_DESIGN.md` | Sonny | Dynasty water: design (Sonny, 31 Oct 2026, branch `dynasty-water`, code in `sr | 10-31 | keep |
| `docs/DYNASTY_WATER_HISTORY.md` | Sonny | Dynasty water: history for the next team (Sonny, 1 Nov 2026) | 11-01 | keep |
| `docs/DYNASTY_WATER_STATUS.md` | Sonny | Dynasty water: status (Sonny, 31 Oct 2026, branch `dynasty-water`) | 10-31 | MERGE into DYNASTY_WATER_HISTORY (newer, "for the next team") if Sonny agrees |
| `docs/DYNASTY_WATER_TASKS.md` | Sonny | Dynasty water: task list (Sonny, from 1 Nov 2026) | 11-01 | keep |
| `docs/FLORA_HANDOVER.md` | MikeW | Flora system handover (flora session, 2026-10-31) | 10-31 | keep |
| `docs/FLORA_NEXT_TASKS.md` | MikeW | Flora: next tasks (standing instruction from Dave, 2026-11-01) | 11-01 | keep |
| `docs/FRUIT_TREES_PLAN.md` | MikeW | Fruit trees with a real fruit store (flora session, 2026-10-31; built: store,  | 10-31 | keep |
| `docs/ITEMS_HANDOVER.md` | Sal | Items data handover (Sal, 2026-10-31): one page for Dave | 10-31 | keep; absorbs ITEM_CODE_HANDOFF |
| `docs/PONYTAIL_RULES.md` | moderator | Ponytail rules (for the Dynasty water build) | 10-31 | keep (Dave's rule for water) |
| `docs/SEASONS_DATA.md` | MikeW | Season data for the looks (flora session, 2026-10-31) | 10-31 | keep |
| `docs/SPAWN_BEAUTY_CHECK.md` | MikeW | Spawn-area beauty check (flora session, 2026-10-31) | 10-31 | keep |
| `docs/TYLER_NEXT_TASKS.md` | Tyler | Tyler's self-assigned tasks (standing instruction from Dave, 1 Nov 2026) | 11-01 | MERGE (see TYLER_NEXT_PLANS) |
| `docs/WATER_HANDOVER.md` | Sonny | Water handover for Dave (Sonny, 31 Oct 2026) | 10-31 | review: overlaps DYNASTY_WATER_STATUS/HISTORY |
| `docs/handoff/FINDINGS_REPORT.md` | Dino | Guide findings for the moderator (1 Nov 2026, daily d05e86b3 / 27dfe828) | 11-01 | keep |
| `docs/handoff/HANDOFF_DINO.md` | Dino | Handoff: Dino: Guides and Walkthrough (formerly Guide, first-hour playthrough) | 11-01 | keep |
| `docs/handoff/HANDOFF_KATHLEEN.md` | Kathleen | Handoff: Kathleen (art and looks), written 2026-11-01 | 11-01 | FIX: calls the voxel exe "standard" |
| `docs/handoff/HANDOFF_MIKEW.md` | MikeW | Handoff: MikeW: Flora and Fauna Density and Placement (formerly Flora), 1 Nov  | 11-01 | FIX: calls the voxel exe "standard" |
| `docs/handoff/HANDOFF_MODERATOR.md` | moderator | Handoff: moderator (written 1 Nov 2026, for Dave's new thread) | 11-01 | FIX: six agents, Flora/Guide/Tyler-systems; add Steve, Kathreen, Dino, Jason, Jamie |
| `docs/handoff/HANDOFF_SAL.md` | Sal | Handoff: Sal (items agent), written 1 Nov 2026 | 11-01 | keep |
| `docs/handoff/HANDOFF_SONNY.md` | Sonny | Handoff: Sonny (character and Dynasty water), 1 Nov 2026 | 11-01 | FIX: body still describes the character lane |
| `docs/handoff/HANDOFF_STEVE.md` | Steve | Handoff: Steve: Systems (written 1 Nov 2026, paper only, no Godot run) | 11-01 | keep |
| `docs/handoff/HANDOFF_TYLER.md` | Tyler | Handoff: Tyler: Q&A Testing, 1 Nov 2026 | 11-01 | keep |
| `docs/handoff/SCOPE_DINO.md` | Dino | Scope: Dino: Guides and Walkthrough (formerly Guide, first-hour playthrough),  | 11-01 | keep |
| `docs/handoff/SCOPE_JAMIE.md` | Jamie | Scope: Jamie: Documentation (1 Nov 2026) | 11-01 | keep |
| `docs/handoff/SCOPE_KATHLEEN.md` | Kathleen | Scope: Kathleen (art and looks), 2026-11-01 | 11-01 | FIX: no mention of the Kathreen split |
| `docs/handoff/SCOPE_KATHREEN.md` | Kathreen | Scope: Kathreen (art assistant: character, animal and plant looks), 1 Nov 2026 | 11-01 | keep |
| `docs/handoff/SCOPE_MIKEW.md` | MikeW | Scope: MikeW: Flora and Fauna Density and Placement (formerly Flora), 1 Nov 20 | 11-01 | keep |
| `docs/handoff/SCOPE_MODERATOR.md` | moderator | Scope: moderator (1 Nov 2026) | 11-01 | FIX: same stale roster |
| `docs/handoff/SCOPE_SAL.md` | Sal | Scope: Sal, the items agent (written 1 Nov 2026) | 11-01 | keep |
| `docs/handoff/SCOPE_SONNY.md` | Sonny | Scope: Sonny (character and Dynasty water), 1 Nov 2026 | 11-01 | FIX: body still describes the character lane |
| `docs/handoff/SCOPE_STEVE.md` | Steve | Scope: Steve: Systems (written 1 Nov 2026, paper only: no Godot run, read-thro | 11-01 | keep |
| `docs/handoff/SCOPE_TYLER.md` | Tyler | Scope: Tyler: Q&A testing and tooling, 1 Nov 2026 | 11-01 | keep |
| `items/BLUEPRINT_BUILD_DESIGN.md` | Sal | Blueprint build system (design only; Sal_Crafts, 2026-10-22 22:50; from Dave 2 | 10-22 | keep |
| `proposed_removals/README.md` | moderator | proposed_removals: nothing is deleted without Dave's approval | 10-25 | keep (RULES.md: nothing deleted) |
| `proposed_removals/REMOVALS.md` | moderator | Proposed removals (waiting for Dave's approval) | 10-30 | keep |
| `tech/TEST_BASELINE_PC.md` | Tyler | Test baseline on Dave's PC (Windows, Git bash), per platform (Mike, 25 Oct 202 | 10-30 | keep |
| `tools/erosion_precarve/README.md` | Tyler | Erosion pre-carve: action plan for Tyler (one plan, one branch) | 10-24 | keep |
| `worlds/base_world/regions/README.md` | Sonny | Baked regions | 10-11 | keep |

## Conflicts and gaps found so far (fixes are separate commits)
1. `godot.windows.editor.x86_64.exe` is the **voxel build**, not "standard" (checked: it contains `VoxelTerrain`, `Godot_v4.7.2-stable_win64*.exe` does not; `tools/godot` defaults to it). The standard exe is `Godot_v4.7.2-stable_win64_console.exe`. Wrong in `HANDOFF_KATHLEEN.md`, `HANDOFF_MIKEW.md`.
2. Rosters: `HANDOFF_MODERATOR.md`, `SCOPE_MODERATOR.md`, `BIG_PICTURE.md`, `RULES.md` ("the team is retired, one session") describe an old team.
3. Eight Sal code specs say "for Tyler" (`FARMING_SPEC`, `HINTS_AND_CAMP_EVENTS_SPEC`, `LEARN_SYSTEM_SPEC`, `LOG_SPECIES_SPEC`, `QUALITY_GRADES_SPEC`, `WATER_GATHER_SPEC`, `CODE_MISMATCHES`, `FLINT_ORE_SPEC`); neither `SCOPE_STEVE.md` nor `SCOPE_TYLER.md` names them, so their code has no named owner. Needs the moderator.
4. Sound moved to Jason; `assets/audio/*` and `SOUND_AUDIT.md` still name Kathleen or the guide.
5. Standing-instruction task lists live in seven files (`GUIDE_TASKS`, `TYLER_NEXT_PLANS`, `TYLER_QUEUED_TESTS`, `docs/TYLER_NEXT_TASKS`, `docs/FLORA_NEXT_TASKS`, `docs/DYNASTY_WATER_TASKS`, `art/ART_TASKS`): one per owner is fine; Tyler's three merge into one.
