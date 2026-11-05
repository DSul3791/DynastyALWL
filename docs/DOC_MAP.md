# Document map (Jamie, 1 Nov 2026; files added 2 to 5 Nov listed by MikeW, 5 Nov)

Every markdown file in git outside `docs/archive/`, `.claude/` and `addons/`: **about 328 files** (120 of them the frozen `docs/mirror/`). Owner = who maintains it now (roles from `MODERATOR_QA_LOG.md`). Updated = date of the last commit that touched the file (not always a real content change).

Verdict words: **keep**, **FIX** (wrong or stale fact), **MERGE** (into the named file, then archive the rest), **ARCHIVE** (to `docs/archive/YYYY-MM/`, with git mv), **review** (overlap seen, owner to decide).

## Groups (not listed file by file)
| Group | Files | Owner | Updated | Verdict |
|---|---|---|---|---|
| `docs/mirror/` (tech 66, items 35, design 17, CONTROLS, README) | 120 | nobody (Technical Director retired) | last copy 22 Oct | keep frozen: cited by `tools/merge_check.py` (skip prefix), `tools/ship.sh` and `next_build.sh` (write `docs/mirror/tech/BUILD_LOG.md`), `balance_sheet.py` (writes `docs/mirror/items/BALANCE.md`), `tool_tiers.py` (reads `docs/mirror/design/TOOL_TIERS.md`), `nightly_backup.py` (cites BACKUP_PLAN.md); its CONTROLS.md is older than the root one. Archive only after those references move |
| `tech/ACTION_PLANS/` | 4 left (41 archived to `docs/archive/2026-11/tech_ACTION_PLANS/`) | previous Steve/Sal | 24-25 Oct | kept: `Steve_ground_quiet` (cited in `ground_watchdog.gd`), `Steve_hide_traps` (`data/animals/traps.json`), `Steve_bow_shoot` (`data/items/bow.json`), `Sal_hammer_blueprints` (bridge not built). `tools/selftest_gate_tools.sh` uses the folder name only as a fake path |
| `art/CRITIQUES/` | 43 rounds + `_archive/` | Kathleen | 30-31 Oct | keep; Kathleen archives rounds Dave has judged |

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
| `BIG_PICTURE.md` | moderator | Big picture (read this first, every thread; about 2 KB; kept current by the Te | 10-22 | keep (fixed 9c01369a; points to START_HERE) |
| `BUILD_ORDERS.md` | Sal | Build orders by tier (Sal, 2026-10-31) | 10-31 | keep |
| `CHARACTER_DESIGN_VISION.md` | Kathreen | Character design vision (Sonny; research and plan, 30 Oct 2026; for Dave to re | 10-31 | keep |
| `CLOTHING_WARMTH.md` | Sal | Clothing and warmth tiers (Sal, 2026-10-31) | 10-31 | keep |
| `CODE_MISMATCHES.md` | Sal / Steve | Data against Tyler's new systems: audit (Sal, 2026-10-31) | 10-31 | keep: history; Steve triages open rows (sow_seasons list, boulder needs_material) |
| `CONTROLS.md` | Steve | Controls | 10-31 | keep (docs/mirror/CONTROLS.md is an older copy) |
| `CRAFT_PACING.md` | Sal | Crafting time and pacing pass (Sal, 2026-10-31) | 10-31 | keep |
| `DESIGN_IDEAS.md` | moderator | Design Vision and Ideas | 10-31 | keep; bloat risk (2074 lines): ask Dave about a split by section |
| `DESIGN_PRINCIPLES.md` | Dave/moderator | Design Principles | 10-17 | keep |
| `DESIGN_REJECTED.md` | Dave/moderator | Rejected Ideas | 10-15 | keep |
| `DIGGING_DESIGN.md` | Sonny | Digging the ground with a spade (design note, Ground loading, 2026-10-21) | 10-21 | keep |
| `ECONOMY_PLAN.md` | Sal | Trade and economy plan (Sal, 2026-10-31) | 10-31 | keep |
| `FARMING_SPEC.md` | Sal / Steve | Farming code spec for Tyler (Sal, 2026-10-31) | 10-31 | keep: Steve (rules), Sal (data); mostly built |
| `FAUNA_BY_BIOME.md` | Sal | Fauna by biome (Sal, 2026-10-31; generated from data/animals/fauna_proposal.js | 10-31 | keep |
| `FAUNA_SPAWN_PLAN.md` | Sal | Fauna spawn data plan (Sal, 2026-10-31) | 10-31 | keep |
| `FELLING_DESIGN.md` | Steve | Tree felling state: design note (2026-10-20, Items and crafting thread) | 10-20 | keep |
| `FIRST_DAY_GUIDE.md` | Sal | Your first day: one page for Dave (Sal, 2026-10-31) | 10-31 | keep |
| `FIRST_HOUR_FOOD.md` | Sal | First-hour food (Sal, 2026-10-31) | 10-31 | keep |
| `FIRST_WEEK_WALK.md` | Sal | First-week balance walk (Sal, 2026-10-31) | 10-31 | keep |
| `FISHING_DATA.md` | Sal | Fishing data (Sal, 2026-10-31) | 10-31 | keep |
| `FLINT_ORE_SPEC.md` | Sal / Steve | Flint, obsidian, ore and coal sources: data decisions and code spec (Sal, 2026 | 10-31 | keep: Steve; flint built, ore/coal unchecked |
| `FOOD_VARIETY.md` | Sal | Food variety check (Sal, 2026-10-31) | 10-31 | keep |
| `FRUIT_TREES.md` | Sal | Fruit trees: item and calendar data (Sal, 2026-10-31, for Dave's request) | 10-31 | keep |
| `FURNITURE_BALANCE.md` | Sal | Comfort furniture: cost against the first week (Sal, 2026-10-31) | 10-31 | keep |
| `GAP_PLANS.md` | Sal | Three biggest gaps: iron, leather, crops (Sal, 2026-10-31) | 10-31 | keep |
| `GENERATION_GUIDE.md` | Sonny | Modular Island Generation Guide | 10-14 | keep |
| `GENERATOR_NOTES.md` | Sonny | Generator notes: how it works, why, and what we measured | 10-30 | keep |
| `GENERATOR_V2_PLAN.md` | Sonny | New Generator Plan | 10-16 | keep |
| `GENERATOR_VISION.md` | Sonny | Generator vision (Dave, 29 Oct 2026; Claude's review and additions) | 10-29 | keep |
| `GUIDE_TASKS.md` | Dino | Guide session: self-made task rounds (standing instruction from Dave, via the  | 11-01 | keep; rename to Dino when he next edits |
| `HANDOFF.md` | moderator | NOW (29 Oct 2026) | 10-29 | keep (banner added 9c01369a; state section is 29 Oct, to trim) |
| `HINTS_AND_CAMP_EVENTS_SPEC.md` | Sal / Steve | Hints on screen and the camp-goal events: code spec for Tyler (Sal, 2026-10-31 | 10-31 | keep: Steve; built except client goal list |
| `ITEMS_DESIGN.md` | Sal | Items and inventory: design note (2026-10-20, Items and crafting thread) | 10-24 | keep |
| `ITEM_ART_REQUESTS.md` | Sal | Item art requests for Kathleen (from Sal, items) | 10-30 | keep |
| `ITEM_CHANGES_SUMMARY.md` | moderator | Every item change on branch sal-items: one page for Dave (2026-10-30) | 10-31 | keep |
| `ITEM_COMBAT_TIER_LIST.md` | Sal | Weapon, shield and armour tier list (proposal, names and recipes only; Sal, 20 | 10-30 | keep |
| `ITEM_DECISION_LOG.md` | moderator | Item decision log (for Dave to review) | 10-31 | keep |
| `ITEM_FARMING_GAP_CHECK.md` | Sal | Farming crops and tools gap check (Sal, 2026-10-30) | 10-30 | keep |
| `ITEM_GLOSSARY.md` | moderator | Item name glossary (generated 2026-10-30 from data/items/items.json) | 10-30 | keep |
| `ITEM_GROUPS_AND_NAMES.md` | moderator | Item groups and names: DynastyALWL | 10-30 | keep |
| `ITEM_TIER_BALANCE.md` | Sal | Tool and weapon tier balance: proposal (Sal, 2026-10-30) | 10-30 | keep |
| `LEARN_SYSTEM_SPEC.md` | Sal / Steve | Recipe learning: rule and code spec (Sal, 2026-10-31, fixes F-01) | 10-31 | keep: Steve; built |
| `LOG_SPECIES_SPEC.md` | Sal / Steve | log_* species chains: code spec for Tyler (Sal, 2026-10-31; guide finding F-11 | 10-31 | keep: Steve; fixed per Sal, build unknown |
| `MEDICINE_CHAIN.md` | Sal | Medicine, poisons and cures (Sal, 2026-10-31) | 10-31 | keep |
| `MERGE_WATCH.md` | Tyler | Merge watch | 10-31 | keep |
| `MODERATOR_QA_LOG.md` | moderator | Night of 30-31 Oct 2026 (Dave asleep; moderator in charge) | 11-01 | keep (source of roles; first heading missing) |
| `MORNING_PLAYTEST_CHECKLIST.md` | Dino | Dave's play-test: one page (daily branch 3494d612, 31 Oct) | 10-31 | keep (head hash removed 9c01369a) |
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
| `QUALITY_GRADES_SPEC.md` | Sal / Steve | Quality grades: data and rules spec for Tyler (Sal, 2026-10-31) | 10-31 | keep: Steve; nothing built |
| `README.md` | moderator | Baked Voxel Game — Modular Island Generator | 10-14 | keep (marked old generator) |
| `RULES.md` | moderator | Rules (one file; replaces TEAM_AND_RULES, HOW_WE_WORK and PROCESS, 29 Oct 2026 | 10-31 | keep (team sentence fixed 9c01369a; ship.sh flow still to check) |
| `SCALING_PLAN.md` | Steve | Scaling plan: loading and entities (50 players, villages, animals, enemies), 2 Nov | 11-02 | keep |
| `SEASONALITY_WINTER.md` | Sal | Seasonality and the winter survival chain (Sal, 2026-10-31) | 10-31 | keep |
| `SMOKE_TEST.md` | Dino | SMOKE_TEST: the daily branch head, run through the real server and client | 10-31 | keep |
| `SOUND_AUDIT.md` | Jason | SOUND_AUDIT: cave-in rumble and rain-like sound in clear weather | 10-31 | keep; owner is Jason now (Dino wrote it) |
| `TARGETS.md` | Tyler | World-alive targets (proposal by Tyler, 31 Oct 2026) | 10-30 | keep |
| `TOWN_NPC_SPEC.md` | Sal | First-island town and NPC data spec (Sal, 2026-10-31) | 10-31 | keep |
| `TUTORIAL_FIRST_30_MIN.md` | Dino | Your first 30 minutes (tutorial script) | 10-31 | keep |
| `TYLER_GATES_REVIEW.md` | Tyler | Gate cards gates-a to gates-f: Tyler's review (30 Oct 2026) | 10-30 | keep (Tyler: merge gates are his again) |
| `TYLER_TEST_SYSTEM_REVIEW.md` | Tyler | Test and gate system review (Tyler, 30 Oct 2026) | 10-31 | keep |
| `WATER_GATHER_SPEC.md` | Sal / Steve | Gather from water and shore: code spec for Tyler (Sal, 2026-10-31; needed for  | 10-31 | keep: Steve (server), Kathleen/Sonny (client edge); server built |
| `WATER_PLAN.md` | Sonny | Land and water: findings, research and plan (Sonny, 30 Oct 2026) | 10-31 | keep |
| `WORLD_ALIVE_LOG.md` | Tyler | World-alive log | 10-31 | keep (log) |
| `WORLD_FORMAT_SPEC.md` | Sonny | World Format Specification (draft) | 10-29 | keep |
| `art/ART_TASKS.md` | Kathleen | Kathleen's art task queue (standing instruction from Dave: finish, make up thr | 11-01 | keep |
| `art/Art_Direction.md` | Dave / Kathleen | Dave's master art direction, copied unchanged; all art follows it | 11-02 | keep (the master; root `ART_DIRECTION.md` is the older working copy: review) |
| `art/BUILDING_PLAN.md` | Kathleen | Building plan: pieces, snapping and materials | 10-22 | keep |
| `art/BUILDING_TIERS_LOOKS.md` | Kathleen | Building tiers: the looks (designs) | 10-23 | keep |
| `art/BUILDING_TIERS_PLAN.md` | Kathleen | Building tiers plan (revised BUILDING_PLAN point 1) | 10-22 | keep |
| `art/ITEM_ART_STATUS.md` | Kathleen | Item art status (Kathleen) | 10-31 | keep |
| `art/WET_TUNNEL_PLAN.md` | Kathleen | Wet tunnels under water: looks and sounds (design) | 10-23 | keep |
| `art/playthrough/RIG_PLACE.md` | Dino | Placing structures for screenshots (testing only) | 10-31 | keep |
| `art/playthrough/audit.md` | Dino | Playthrough audit (generated by art/playthrough/audit_playthrough.py) | 11-01 | keep |
| `art/playthrough/refresh1nov/RESULTS.md` | Tyler | Smoke rerun results on daily 224e78bd (1 Nov evening) | 11-01 | keep: history |
| `art/playthrough/smoke/notes.md` | Dino | Felling pictures (art/playthrough/world3/fell*.jpg, stump_*.jpg), 07:40 | 10-31 | keep |
| `assets/audio/CREDITS.md` | Jason | Sound credits | 10-20 | keep |
| `assets/audio/LOUDNESS.md` | Jason | Loudness table (make with `python3 assets/audio/loudness_report.py --md`) | 10-20 | keep |
| `assets/audio/README.md` | Jason | Sounds | 10-21 | keep; Jason owns sound now (was Kathleen) |
| `assets/audio/SOUND_DROP_IN.md` | Jason | Where Dave's animal recordings go (Kathleen, 2026-10-23) | 10-23 | keep (Kathleen is the 23 Oct author; Jason owns) |
| `assets/audio/SOUND_PACK.md` | Jason | Sound pack manifest | 10-21 | keep |
| `assets/audio/inner_voice/README.md` | Jason | (no heading) | 10-21 | keep |
| `assets/character/README.md` | Kathreen | Ragdoll character | 10-21 | keep |
| `assets/natural_pickups/README.md` | Kathleen | Dynasty — natural pickup props | 10-20 | keep |
| `data/items/look_wishlist.md` | Sal | Look wishlist for Kathleen (Sal, 2026-10-31) | 10-31 | keep |
| `design/GATE_BEFORE_AFTER.md` | Tyler | Gate before/after (Tyler, 28 Oct 2026). Plan: GATE_FIX_PLAN.md | 10-28 | keep |
| `design/TOOL_TIERS.md` | Sal | Tool tiers | 10-25 | keep |
| `docs/BUG5_TREE_HITS_FINDINGS.md` | Sal | Bug 5 (tree takes over 20 hits): findings from the code, 2 Nov | 11-02 | keep: history |
| `docs/BUGS_FOUND_IN_PLAY.md` | Tyler | Dave's in-play bug list with the owner triage table | 11-04 | keep (live; `bug-list-2026-11-03-triage.md` in the project folder is the triage) |
| `docs/COMFORT_DESIGN.md` | Sal | Comfort and the Rested buff (Sal, 2026-10-31) [Proposed] | 10-31 | keep (design/data Sal; rules Steve) |
| `docs/DAY_ONE_NUMBERS.md` | Sal | Day-one survival numbers (burn, stomach, water, sickness) from vitals data, 3 Nov | 11-03 | keep |
| `docs/DEAD_END_MATERIALS.md` | Sal | Materials made but used by nothing, with proposed uses, 2 Nov | 11-02 | FIX: all seven now used (validator, 5 Nov; #369); soap and compost wait for rules |
| `docs/DYNASTY_WATER_DESIGN.md` | Sonny | Dynasty water: design (Sonny, 31 Oct 2026, branch `dynasty-water`, code in `sr | 10-31 | keep |
| `docs/DYNASTY_WATER_HISTORY.md` | Sonny | Dynasty water: history for the next team (Sonny, 1 Nov 2026) | 11-01 | keep |
| `docs/DYNASTY_WATER_STATUS.md` | Sonny | Dynasty water: status (Sonny, 31 Oct 2026, branch `dynasty-water`) | 10-31 | keep (Sonny works from it; he archives it himself) |
| `docs/DYNASTY_WATER_TASKS.md` | Sonny | Dynasty water: task list (Sonny, from 1 Nov 2026) | 11-01 | keep |
| `docs/EARLY_FORAGE_20261103.md` | MikeW | Early-game forage at the starter spawn, 3 Nov | 11-04 | keep |
| `docs/FAUNA_BEHAVIOUR_AUDIT_20261102.md` | MikeW | Fauna behaviour audit, 2 Nov | 11-02 | keep: history (fixes merged #194-#239, #328) |
| `docs/FAUNA_MEASUREMENT_20261102.md` | MikeW | Fauna counts measured at the starter spawn, 2 Nov | 11-02 | keep: history |
| `docs/FEEL_TUNING.md` | Kathleen | First-person feel: every movement, tool and hit number and where it is tuned | 11-04 | keep |
| `docs/FLORA_HANDOVER.md` | MikeW | Flora system handover (flora session, 2026-10-31) | 10-31 | keep |
| `docs/FLORA_NEXT_TASKS.md` | MikeW | Flora: next tasks (standing instruction from Dave, 2026-11-01) | 11-01 | keep |
| `docs/FRUIT_TREES_PLAN.md` | MikeW | Fruit trees with a real fruit store (flora session, 2026-10-31; built: store,  | 10-31 | keep |
| `docs/HEAVY_KITS_OPTIONS.md` | Sal | Heavy kits: options and recommendation, 2 Nov | 11-01 | ARCHIVE: superseded by no kits (#292, Dave 4 Nov) |
| `docs/ISLAND_FAUNA_20261103.md` | MikeW | Starter island fauna (frogs, ducks, gulls, seals by water), 3 Nov | 11-04 | keep |
| `docs/ITEMS_HANDOVER.md` | Sal | Items data handover (Sal, 2026-10-31): one page for Dave | 10-31 | keep (now holds \"Needs code\") |
| `docs/PONYTAIL_RULES.md` | moderator | Ponytail rules (for the Dynasty water build) | 10-31 | keep (Dave's rule for water) |
| `docs/SEASONS_DATA.md` | MikeW | Season data for the looks (flora session, 2026-10-31) | 10-31 | keep |
| `docs/SPAWN_BEAUTY_CHECK.md` | MikeW | Spawn-area beauty check (flora session, 2026-10-31) | 10-31 | keep |
| `docs/TYLER_NEXT_TASKS.md` | Tyler | Tyler's self-assigned tasks (standing instruction from Dave, 1 Nov 2026) | 11-01 | keep (Tyler's one task list) |
| `docs/WATER_HANDOVER.md` | Sonny | Water handover for Dave (Sonny, 31 Oct 2026) | 10-31 | review: overlaps DYNASTY_WATER_STATUS/HISTORY |
| `docs/WILD_CROP_PLANTS_PLAN.md` | Sal | Wild plants for the eight seedless crops (Dave option A), 3 Nov | 11-03 | keep |
| `docs/handoff/DINO_BUG_CHECKS.md` | Dino | What each bug means for the first-hour guide and how Dave confirms each fix, 2 Nov | 11-02 | keep: history |
| `docs/handoff/DINO_ROUND1_REPORT.md` | Dino | Round 1 paper review: placement refusals, tutorial numbers against data, 2 Nov | 11-02 | keep: history |
| `docs/handoff/DINO_ROUND2_REPORT.md` | Dino | Round 2 paper review: hearth cost drift, stale items, kits against looks, 2 Nov | 11-01 | keep: history |
| `docs/handoff/DINO_ROUND3_PC_COMMANDS.md` | Dino | Round 3: PC commands for the checks, 2 Nov | 11-01 | keep: history |
| `docs/handoff/DINO_ROUND4_HINTS.md` | Dino | Round 4: in-game hints left behind by the 2 Nov fixes | 11-02 | keep: history |
| `docs/handoff/DINO_ROUND5_EARLY_GAME.md` | Dino | Round 5: early-game text the player reads, 3 Nov | 11-02 | keep: history |
| `docs/handoff/DINO_ROUND6_GOALS.md` | Dino | Round 6: starter goals checked against data, 3 Nov (hint triggers table Sal works from) | 11-04 | keep |
| `docs/handoff/FINDINGS_REPORT.md` | Dino | Guide findings for the moderator (1 Nov 2026, daily d05e86b3 / 27dfe828) | 11-01 | keep |
| `docs/handoff/HANDOFF_DINO.md` | Dino | Handoff: Dino: Guides and Walkthrough (formerly Guide, first-hour playthrough) | 11-01 | keep |
| `docs/handoff/HANDOFF_KATHLEEN.md` | Kathleen | Handoff: Kathleen (art and looks), written 2026-11-01 | 11-01 | keep (exe fix done 7936bc74) |
| `docs/handoff/HANDOFF_MIKEW.md` | MikeW | Handoff: MikeW, flora and fauna plus Grass leftovers (rewritten 5 Nov) | 11-05 | keep |
| `docs/handoff/HANDOFF_MODERATOR.md` | moderator | Handoff: moderator (written 1 Nov 2026, for Dave's new thread) | 11-01 | keep (roster fixed 75a414e1) |
| `docs/handoff/HANDOFF_SAL.md` | Sal | Handoff: Sal (items agent), written 1 Nov 2026 | 11-01 | keep |
| `docs/handoff/HANDOFF_SONNY.md` | Sonny | Handoff: Sonny (character and Dynasty water), 1 Nov 2026 | 11-01 | keep (terrain and water only, fixed) |
| `docs/handoff/HANDOFF_STEVE.md` | Steve | Handoff: Steve: Systems (written 1 Nov 2026, paper only, no Godot run) | 11-01 | keep |
| `docs/handoff/HANDOFF_TYLER.md` | Tyler | Handoff: Tyler: Q&A Testing, 1 Nov 2026 | 11-01 | keep |
| `docs/handoff/SCOPE_DINO.md` | Dino | Scope: Dino: Guides and Walkthrough (formerly Guide, first-hour playthrough),  | 11-01 | keep |
| `docs/handoff/SCOPE_JAMIE.md` | Jamie | Scope: Jamie: Documentation (1 Nov 2026) | 11-01 | keep |
| `docs/handoff/SCOPE_KATHLEEN.md` | Kathleen | Scope: Kathleen (art and looks), 2026-11-01 | 11-01 | FIX: no mention of the Kathreen split |
| `docs/handoff/SCOPE_KATHREEN.md` | Kathreen | Scope: Kathreen (art assistant: character, animal and plant looks), 1 Nov 2026 | 11-01 | keep |
| `docs/handoff/SCOPE_MIKEW.md` | MikeW | Scope: MikeW: Flora and Fauna Density and Placement (formerly Flora), 1 Nov 20 | 11-01 | keep |
| `docs/handoff/SCOPE_MODERATOR.md` | moderator | Scope: moderator (1 Nov 2026) | 11-01 | keep (roster fixed 75a414e1) |
| `docs/handoff/SCOPE_SAL.md` | Sal | Scope: Sal, the items agent (written 1 Nov 2026) | 11-01 | keep |
| `docs/handoff/SCOPE_SONNY.md` | Sonny | Scope: Sonny (character and Dynasty water), 1 Nov 2026 | 11-01 | keep (terrain and water only, fixed) |
| `docs/handoff/SCOPE_STEVE.md` | Steve | Scope: Steve: Systems (written 1 Nov 2026, paper only: no Godot run, read-thro | 11-01 | keep |
| `docs/handoff/SCOPE_TYLER.md` | Tyler | Scope: Tyler: Q&A testing and tooling, 1 Nov 2026 | 11-01 | keep |
| `items/BLUEPRINT_BUILD_DESIGN.md` | Sal | Blueprint build system (design only; Sal_Crafts, 2026-10-22 22:50; from Dave 2 | 10-22 | keep |
| `proposed_removals/README.md` | moderator | proposed_removals: nothing is deleted without Dave's approval | 10-25 | keep (RULES.md: nothing deleted) |
| `proposed_removals/REMOVALS.md` | moderator | Proposed removals (waiting for Dave's approval) | 10-30 | keep |
| `tech/TEST_BASELINE_PC.md` | Tyler | Test baseline on Dave's PC (Windows, Git bash), per platform (Mike, 25 Oct 202 | 10-30 | keep |
| `tools/erosion_precarve/README.md` | Tyler | Erosion pre-carve: action plan for Tyler (one plan, one branch) | 10-24 | keep |
| `worlds/base_world/regions/README.md` | Sonny | Baked regions | 10-11 | keep |

Jason's three, all keep: `SOUND_AUDIT.md` (findings record), `docs/SOUND_MAP.md` (hook audit and sound map), `docs/handoff/SCOPE_JASON.md` (plan). `docs/START_HERE.md`, `docs/DOC_MAP.md` and `docs/handoff/SCOPE_JAMIE.md` were added after the table was built; `docs/handoff/` now holds 21 files.

Added at handoff (1 Nov, all keep): `docs/CLOSING_PLAN.md` (moderator: what each agent finishes; "done" defined), `docs/OLD_BRANCH_REVIEW.md` (moderator: unmerged branches and verdicts), `docs/ECONOMY_FIRST_DAY.md` (Sal: cheap goods and sell lots), `docs/TERRAIN_WATER_BACKLOG.md` (Sonny), `docs/KATHLEEN_NEXT_TASKS.md` (Kathleen), `docs/handoff/HANDOFF_JASON.md` and `JASON_NEXT_TASKS.md` (Jason), `docs/handoff/HANDOFF_KATHREEN.md` (Kathreen), `docs/handoff/SAL_SPECS_FOR_STEVE.md` (Sal to Steve), `docs/handoff/PHASE2_RUNBOOK.md` (Dino: commands and the 14-step walk, run only after RESTART). `art/CRITIQUES/` rounds Dave judged are now in `art/CRITIQUES/_archive/` (Kathleen), 43 folders remain.

Added 1 Nov evening (keep): `docs/CARRY_WEIGHTS.md` (Sal: why picking overloaded Dave, new item weights in `data/items/weights.json`; capacity left unchanged), `docs/DYNASTY_BODY.md` (Kathleen: Dave's body glb, how it is wired, clip table, what is left; flag `--oldbody`), `art/CRITIQUES/dynasty_base_male_2026-11-01/` (body clip stats). `CONTROLS.md` gained K (photo camera) and `/` (inspection mode). `HANDOFF_MODERATOR.md` and `SCOPE_MODERATOR.md` were updated by the moderator.

## Backlogs: where each agent's open work is written (final pass, 1 Nov; plan: `docs/CLOSING_PLAN.md`)
Done = merged in the daily, or written in the owner's backlog with owner, next step and why not done.
| Agent | Backlog | State |
|---|---|---|
| Sonny | `docs/TERRAIN_WATER_BACKLOG.md`; `docs/handoff/HANDOFF_SONNY.md`; `docs/DYNASTY_WATER_TASKS.md` | exists |
| Kathleen | `docs/KATHLEEN_NEXT_TASKS.md`; `docs/handoff/HANDOFF_KATHLEEN.md`; `art/ART_TASKS.md` | exists |
| Kathreen | `docs/handoff/HANDOFF_KATHREEN.md`; `docs/handoff/SCOPE_KATHREEN.md` | exists |
| Sal | `docs/handoff/HANDOFF_SAL.md` "Next tasks"; `docs/ITEMS_HANDOVER.md` "Needs code"; `docs/handoff/SAL_SPECS_FOR_STEVE.md` (specs handed to Steve) | exists |
| MikeW | `docs/FLORA_NEXT_TASKS.md`; `docs/handoff/HANDOFF_MIKEW.md` | exists |
| Steve | `docs/handoff/HANDOFF_STEVE.md` "Exact next steps"; `docs/handoff/SCOPE_STEVE.md` | exists (no separate STEVE_NEXT_TASKS) |
| Tyler | `docs/TYLER_NEXT_TASKS.md`; `docs/handoff/HANDOFF_TYLER.md` | exists |
| Dino | `GUIDE_TASKS.md`; `docs/handoff/HANDOFF_DINO.md`; `docs/handoff/PHASE2_RUNBOOK.md` | exists |
| Jason | `docs/handoff/JASON_NEXT_TASKS.md`; `docs/handoff/HANDOFF_JASON.md`; `docs/SOUND_MAP.md` | exists |
| Jamie | `docs/handoff/SCOPE_JAMIE.md` | exists |
| Moderator | `docs/handoff/HANDOFF_MODERATOR.md` "Known open items"; `docs/handoff/PHASE2_RUNBOOK.md` for the Phase 2 order | updated by the moderator; "Final state" section (stuck slots, held branches) added by Jamie |

## Which pacing / playthrough document answers what (overlap review, 1 Nov)
Read, not merged: each is owned (Sal or Dino) and two are generated, so the fix is one home per question, not a merge.
| Question | Read | Note |
|---|---|---|
| What can be built at each tier, in what order? | `BUILD_ORDERS.md` (Sal, generated from recipes) | `PLAYTHROUGH_PLANS.md` repeats a milestone table from the budget; read it for the three plans only |
| How many minutes does each milestone take? | `PLAYTHROUGH_BUDGET.md` (generated by `art/playthrough/build_orders.py`; edit parameters, not the file) | `FIRST_WEEK_WALK.md` is Sal's separate paper walk of week one; `CRAFT_PACING.md` is the proposal for craft seconds (no recipe changed) |
| Which first-hour steps work end to end? | `PLAYTHROUGH_STEP_STATUS.md` (Dino, hand-written, being refreshed in Phase 2) | |
| Which findings (F-numbers) are fixed? | `PLAYTHROUGH_STATUS.md` (generated from `PLAYTHROUGH_FINDINGS.md`; do not edit) | |
Duplicate removed 1 Nov: `PLAYTHROUGH_PLANS.md` no longer copies the budget table (links to `PLAYTHROUGH_BUDGET.md`).

## Conflicts and gaps found so far (fixes are separate commits)
1. `godot.windows.editor.x86_64.exe` is the **voxel build**, not "standard" (checked: it contains `VoxelTerrain`, `Godot_v4.7.2-stable_win64*.exe` does not; `tools/godot` defaults to it). The standard exe is `Godot_v4.7.2-stable_win64_console.exe`. Was wrong in `HANDOFF_KATHLEEN.md`, `HANDOFF_MIKEW.md` (fixed).
2. Rosters: `HANDOFF_MODERATOR.md`, `SCOPE_MODERATOR.md`, `BIG_PICTURE.md`, `RULES.md` ("the team is retired, one session") described an old team (moderator documents, BIG_PICTURE, RULES fixed; `SCOPE_SONNY.md`/`HANDOFF_SONNY.md` still two-lane, asked Sonny).
3. (Settled 1 Nov by Steve and Sal: Steve owns the rules code of all eight; see Verdict column.) Eight Sal code specs said "for Tyler" (`FARMING_SPEC`, `HINTS_AND_CAMP_EVENTS_SPEC`, `LEARN_SYSTEM_SPEC`, `LOG_SPECIES_SPEC`, `QUALITY_GRADES_SPEC`, `WATER_GATHER_SPEC`, `CODE_MISMATCHES`, `FLINT_ORE_SPEC`); neither `SCOPE_STEVE.md` nor `SCOPE_TYLER.md` names them, so their code had no named owner; Steve is adding them to SCOPE_STEVE.md Sources.
4. (Settled) Sound moved to Jason; `SOUND_AUDIT.md` carries his owner banner.
5. Standing-instruction task lists live in five files (`GUIDE_TASKS`, `docs/TYLER_NEXT_TASKS`, `docs/FLORA_NEXT_TASKS`, `docs/DYNASTY_WATER_TASKS`, `art/ART_TASKS`): one per owner is fine (Tyler's three were merged into one; the other two archived).

## Archiving rule for tools
`tools/merge_check.py` fails a merge when a `.md` file under `art/`, `assets/`, `design/`, `docs/`, `items/`, `src/`, `scenes/`, `worlds/` or `data/` disappears from its old path unless it is in `proposed_removals/` (it skips `docs/archive/` as a *deleted-from* path only, not as a destination). Root files and `tech/` pass. So archiving a file from `docs/`, `art/` or `design/` needs a `proposed_removals/` pointer or a rule change by Tyler (tools owner): not done yet.

## Dead references (Jamie, 2 Nov 2026; found by scanning backticked `.md` names)
These named documents are in no tracked path. Owner to restore, repoint or drop the mention (not fixed by Jamie: content is theirs).
| Mentioned in | Missing | Note | Owner |
|---|---|---|---|
| `ART_ASSET_INVENTORY.md` | `art/MODEL_INVENTORY.md`, `art/MODEL_PLAN.md`, `art/REFERENCE_PHOTOS.md`, `art/GOAL2_RANKING.md` | copies exist only in the Dynasty project shared folder, not in git | Kathleen |
| `ITEM_GROUPS_AND_NAMES.md` | `Items_in_other_games_Analysis.md` | not in git | Sal |
| `DYNASTY_WATER_DESIGN.md`, `HANDOFF_SONNY.md` | `docs/WATER_OWN_SYSTEM_PROPOSAL.md` | not in git | Sonny |
| `HANDOFF_STEVE.md`, `SCOPE_STEVE.md`, `SCOPE_TYLER.md` | `docs/CHARACTER_SYSTEM.md` | not in git | Steve |
| `assets/audio/README.md` | `/mnt/project-files/...` (SOUND_GAPS, SWEEP, EMITTER_API, STEP_LEVELS) | paths on another machine | Jason |
| many | `questions/QUESTIONS.md`, `questions/ANSWERS.md` | fine: they live on branch `qa` | none |

Checker for real links: `python3 tools/check_doc_links.py` (0 dead markdown links today).
