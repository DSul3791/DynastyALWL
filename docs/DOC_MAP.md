# Dynasty — Main Design Index

Start here to find a design topic, then read its source and the relevant working record. This index routes readers; it does not repeat designs, grant approval or certify implementation. Approval, proposals, provisional choices and verification status remain in their owning records.

## Vision and ideas

| Topic | Source | Purpose |
|---|---|---|
| Game vision and future ideas | [DESIGN_IDEAS](../DESIGN_IDEAS.md) | Remaining mixed-status collection; extracted topics retain routes there. Tags alone do not verify approval. |
| Compact game orientation | [Big picture](../BIG_PICTURE.md) | Vision/principles overview and clearly dated-status historical scope; current operation routes through CLAUDE and the live missions. |
| Aging and lifespan | [Approved specification](../Design_Ideas_Approved.md#aging-and-lifespan); [proposals](../Design_Ideas_Unapproved.md#aging-and-lifespan) | Values and qualifications recorded once; runtime remains unverified. |
| Children and family growth | [Approved specification](../Design_Ideas_Approved.md#children-and-family-growth); [proposals](../Design_Ideas_Unapproved.md#children-and-family-growth) | Childhood/teaching and adoption decisions; siblings, adoption eligibility and other open questions remain separate. |
| Death and rescue | [Approved specification](../Design_Ideas_Approved.md#death-and-rescue); [proposals](../Design_Ideas_Unapproved.md#death-and-rescue) | Downed/rescue, remains, gear protection and wizard retrieval; unresolved expiry and historical implementation evidence stay explicit. |
| Succession and inheritance | [Approved offer order and final-child fallback](../Design_Ideas_Approved.md#succession-order-and-final-child-fallback); [remaining succession collection](../Design_Ideas_Unapproved.md#succession-and-inheritance) | Dave clarified family grouping and fallback on 16 Nov 2026. Other inheritance, tax, household and check-in records retain their own status. |
| NPC population and migration | [NPC collection](../Design_Ideas_Unapproved.md#npc-population-and-migration) | Roles, births, scavengers, country folk and displacement; [technical plan](https://github.com/DSul3791/DynastyALWL/blob/b8130aecd2d6325a772c065b9e73959953f3d64a/docs/mirror/items/NPC_DESIGN.md) and [roster](../TOWN_NPC_SPEC.md) retain dated status. |
| Property and town management | [Property/management collection](../Design_Ideas_Unapproved.md#property-and-town-management) | Planning, permissions, property/reputation, contested claims, remote management, mail and server-town purchases; source-unverified decisions and proposals remain distinct. |
| Founding and settlement construction | [Founding collection](../Design_Ideas_Unapproved.md#founding-and-building-a-settlement) | Markers/territory, establishment, proposed first-ten list and separately recorded planner order; numeric stage tables and open questions retained. |
| Outposts and settlement decline | [Outpost/decline collection](../Design_Ideas_Unapproved.md#outposts-and-settlement-decline) | Outpost points/sizes and separate player/server-town decline paths; numeric tables, road/rubble persistence and claim/deletion exceptions retained. |
| Dave's rulings | [RULINGS](RULINGS.md) | One live line per subject; beats older text in every topic doc. |
| Design principles | [DESIGN_PRINCIPLES](../DESIGN_PRINCIPLES.md) | Values and constraints behind the designs. |
| Approved design provenance | [Approved records](../Design_Ideas_Approved.md) | Source-backed status records; full specifications remain in owning topic files. Original-source retrieval limits are explicit. |
| Implementation evidence | [Built records](../Design_Ideas_Built.md) | Implementation commits, checks and remaining gaps; built/tested/player-verified are separate. |
| Rejected ideas | [DESIGN_REJECTED](../DESIGN_REJECTED.md) | Preserve explicit rejections and their reasons. |
| Creature and exploration proposals | [GUIDING_DOCUMENT](design/GUIDING_DOCUMENT.md) | Habitat concepts, worked interaction cards and recorded G/D history; dated dependency plan, not family/town design or an operating rulebook. |
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
| Chests by nail tier | [Chest tiers](design/CHEST_TIERS.md) | Which chest each nail metal builds, the "or better" nails and hinges groups, provisional CT-1..CT-5. | Relevant task record |
| Character attributes | [Attributes 0 to 100](design/ATTRIBUTES.md) | Every attribute 0 to 100 like a percent, 50 average; the bell-shaped creation roll (player fitness 40 to 60); old saves converted; provisional ATTR-1, ATTR-3, ATTR-4. | This design's For Dave section |
| Skill training and caps | [Skill training](design/SKILL_TRAINING.md) | Dave's rule: 1 to 24 by use alone, a trainer for each band after; a visit jumps to the band floor (25, 50, 75) and speeds gains. Numbers in data/items/skills.json. | This design |
| Autoload | [Autoload](design/AUTOLOAD.md) | A container loads an item from the ground within 30 m, once or every 10 minutes; provisional AL-1 to AL-5. | This design's For Dave section |
| No spawning near builds | [No-spawn zones](design/NO_SPAWN_ZONES.md) | Nothing wild spawns or regrows within 20 m of what players put down; grass cleared close round it. | This design's For Dave section |
| Server pick page (client) | [Server pick page](design/SERVER_PICK_PAGE.md) | Approved by Dave 19 Nov: official server, saved servers with live status and padlock, passwords (3 tries), plain failure words. | This design's For Dave section |
| Torches and Tree sap | [Torches and Tree sap](design/TORCH_TREE_SAP.md) | Simple and Improved torch recipes, where Tree sap comes from; provisional values TS-1..TS-7. | Relevant task record |
| Smelters | [Smelters light like a campfire](design/SMELTER_LIGHTING.md) | E lights and puts out every smelter tier, fire shown only while lit; provisional choices SL-1..SL-8. | Relevant task record |
| Craft finish and countdown | [A craft ends with its product or a reason](design/CRAFT_FINISH.md) | Kept items count from the ground and nearby containers at both ends of a craft; the countdown is the finish; provisional CF-1..CF-2. | This design's For Dave section |
| Edda and Hob's camp | [Camp under the oak](design/NPC_CAMP.md) | Hob and Edda under the oak by the spawn with a large campfire nobody can use; provisional CAMP-1..CAMP-6. | Relevant task record |
| Goblin trading camp | [The Ragtooth camp](design/GOBLIN_CAMP.md) | Three wary goblins at a cave mouth by a river who talk and trade; tribes with attitudes in data; provisional GOBLIN-1..GOBLIN-8. | Relevant task record |
| Character and creature meshes | [Mesh checklist](design/CHARACTER_MESHES.md) | Dave's rule (20 Nov 2026) for every character and creature mesh: shadows On, not Double-Sided; textures VRAM Compressed; where the shipped meshes stand. | Relevant task record |
| Garden moisture and irrigation | [Garden moisture](design/GARDEN_MOISTURE.md) | Soil moisture shown on beds, rain and hand watering, dry days slow crops; pipe water onto plots and the hoe's irrigation trench; provisional GM-1..GM-8. | This design's assumptions section |
| Survey a path | [Survey a path: the survey line](design/SURVEY_ROAD.md) | Hoe survey roads at any distance, the green/red aim line, trees felled and stumps broken on the road, grass cleared 2 m each side; provisional SV-1..SV-9. | Relevant task record |
| Bandit camps | [Bandit camps](design/BANDIT_CAMPS.md) | Seed-fixed bandit sites woken by road traffic (stage 1) and the camp laid on them: fire, Lean-tos, tethered horses, bandits levelled by distance (stage 2); warnings: signs, lookout (stage 3); clearing: surrender, tying, bounty, dissolving (stage 5); provisional BANDIT-1..BANDIT-27. | Relevant task record |
| Ore veins and mines | [Ore veins and mines](design/ORE_VEIN_MINING.md) | Midgame vein mining from the existing geology; Dave's 17 Nov answers in s9; build waits for his go; provisional OV-1..OV-15. | Relevant task record |
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
| Who is an admin on a server | [Admin check](design/ADMIN_CHECK.md) | Server-decided admin keys (`--dedicated`), the audit of every admin path; provisional AC-1..AC-4. | This design's assumptions section |

## Working records

Keep these separate from the design: they own assignments, implementation state, assumptions, blockers and evidence. Read status there instead of copying progress into this index.

| Work area | Records | Purpose |
|---|---|---|
| Robot play-testers | [Robot play-testers](ROBOT_PLAYTESTERS.md) | Headless robot players over a simulated internet link (delay, jitter, loss) checking pack sync, animal and player jumps, held items, crouch movement and rejoin against the server. |
| Picture checker | [Picture checker and sweep](PICTURE_CHECK.md) | In-game pictures of every animal, tool, worn item, building piece and graphics tier, looked at by the Claude API on Dave's credits under a hard cap; findings are leads for the bug list. |
| To-do list | [TODO](TODO.md), [current bugs](../BugsList_Current.md), [fixed bugs](../BugsList_Fixed.md) | What is not built yet, grouped into thread-sized pieces; Dave's play-test problems until he has played the fix. |
| Goal authoring | [Working walkthrough draft](design/PLAYER_GOALS_REWARDS_DRAFT.md), [corrected review catalog](design/PLAYER_GOALS_CATALOG_CORRECTED.md) | Current walkthrough authoring/regeneration inputs; use mission decisions for approvals, amounts and activation. |
| Goals/progression repair | [State](ai-team/missions/GOALS-REPAIR/STATE.md), [decisions](ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md) | Current mission state and scoped decisions/assumptions. |
| Repair planning | [Integration plan](design/CATALOG_IMPLEMENTATION_PLAN.md), [missing-systems plan](design/PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md) | Repair sequence and dependencies; not new gameplay authorization. |
| Repair verification | [Verification evidence](design/PLAYER_PROGRESSION_REPAIR_VERIFICATION.md), [F6 checklist](design/PLAYER_PROGRESSION_REPAIR_F6.md) | Actual checks and the player-validation checklist. |
| Wood implementation | [WOOD-SYSTEM state](ai-team/missions/WOOD-SYSTEM/STATE.md) | Phases, provisional choices, evidence and remaining player checks. |
| Doors and doorways | [Contract](ai-team/missions/BUGLIST-002/CONTRACT.md), [ledger](ai-team/missions/BUGLIST-002/LEDGER.md), [design correction](buglists/BUGLIST-002.md) | Approved task scope and actual implementation/verification records. |
| Fog implementation | [Technical plan](design/FOG_PLAN.md), [F6 checklist](design/FOG_F6.md) | Implementation details and appearance checks for the director's fog design. |
| First-load lag (BugsList 108, 93) | [Local server at the first load](design/LOCAL_SERVER_FIRST_LOAD_PLAN.md) | Plan only: evidence, candidate causes and options for the launcher's server and the client competing at the first join; not an approval. |

## Reviewed character and wildlife references

Separate references for distinct topics. Dated implementation notes preserve code pointers and ideas; they do not establish current behavior or approve proposals.

| Topic | Reference | Scope and status |
|---|---|---|
| Character records | [Character system](CHARACTER_SYSTEM.md) | Static 2 Nov create/save/load/delete map, with future heir/account ideas retained; later location design is in [Resume spot](design/RESUME_SPOT.md). |
| Body and animation | [Dynasty body](DYNASTY_BODY.md) | Body adoption and proportions decisions, consolidated rig/clip reference and remaining appearance ideas; dated evidence is separate from current verification. |
| Movement and action feel | [Feel tuning](FEEL_TUNING.md) | Parameter locator and recorded 2 Nov settings; current values are in the named code. |
| Comfort and Rested | [Comfort](COMFORT_DESIGN.md) | Comfort/Rested behavior, tuning, open questions and integration reference; recipes route to the master catalog. No blanket approval or runtime certification. |
| Wildlife coverage | [Animal specification](../ANIMAL_SPEC.md) | 30–31 Oct data audit/species proposals and 8 Nov alarm-group design; not a current species census or passing test certificate. |
| Animal reactions to players | [Animal reactions](design/ANIMAL_REACTIONS.md) | Provisional 19 Nov 2026 reaction table (notice / flee / safe per species) and the sense changes RX-1 to RX-3, for Dave's review; values live in data/animals/animals.json. |
| Server scale (hundreds, then thousands of players) | [Server scale](design/SERVER_SCALE.md) | 23 Nov 2026 load tests at 32 to 256 bots (what breaks first, top costs with numbers) and the plan in order of gain; the 32-player cap stays Dave's call. |
| Animals over a real connection | [Animal netcode](design/ANIMAL_NETCODE.md) | 23 Nov 2026 research (how other games sync, move and fight animals, with sources), the diagnosis of Dave's live-server play test (ENet's throttle, the draw delay, pass-through, robot steering) and the protocol 154 fixes; the order of the next steps. |
| Animals lying down, rabbit groups | [Animal resting](design/ANIMAL_RESTING.md) | 21 Nov 2026 (D-ANIM-1, protocol 148): grazers sent lying (state 19) by their active share; rabbits in groups of 2 to 4 (HB-4, provisional). |
| Animal routines, game trails, trapping | [Routines, trails and trapping](design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md) | 22 Nov 2026 (protocol 149, D-TRAP-1/2/3): warrens and deer ranges, daily trips along trails drawn as matted grass, snares on runs and while away, "Snare a rabbit" goal; stage 2a animals keep to the sun, moose and elk ranges; stage 2b fox earths and night rounds by the warrens, a fox now and then in a snare while away; stage 2c players' own worn paths and choke points; stage 2d signs along trails by Tracking; stages 3-4 planned. |
| Animal behaviour by scenario | [Animal scenarios](design/ANIMAL_SCENARIOS.md) | 25 Nov 2026 research for Dave: every animal in the game by scenario (sleeping, eating, scared, threatened, hurt, trapped, starving, fire, sounds ...), real numbers with sources, "in our game" lines, and a gap list biggest first for the fix threads. Bears first. |
| Hunting signs, reading sign, fresh tracks | [Hunting signs](design/HUNTING_SIGNS.md) | 23 Nov 2026: signs for everyone with a faint highlight by Tracking, deer beds and rubbed trees, read a sign with E, trails flatter and paler in grass, fresh prints from live animals. |

## Further design areas — routing review pending

These sources remain available. Their inclusion preserves discoverability; it does not settle conflicting versions or promote proposals. Review them in small topic batches before choosing or consolidating authorities.

| Area | References to review |
|---|---|
| Goblins | [Goblins](GOBLINS.md) |
| Caves, cave dens and abandoned mines | [Cave dens and mines](design/CAVE_DENS_AND_MINES.md) (Dave 19 Nov 2026; provisional answers given for him) |
| Generation and natural watersheds | [Generator vision](../GENERATOR_VISION.md), [Dave's watersheds](water/Dynasty_How_Natural_Watersheds_Work.md), [watershed build design](water/watershed_rebuild_design.md) |
| Outdoor audio | [Sound outdoors](design/sound_outdoors_design.md) |
| Other future systems awaiting topic review | [Remaining mixed ideas](../DESIGN_IDEAS.md) |
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
