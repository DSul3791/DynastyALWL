# Dynasty — Missing Mechanics, Item Coherence & Full-Game Progression Repair Plan

**Status: REVIEW PLAN — creator-approved direction to FIX missing gameplay rather than delete tutorial goals. This file is NOT a blanket authorization to change approved item/recipe/progression rules or to implement/reprice the goals.**
**Date:** 13 November 2026. **Baseline reviewed:** `dev` merge `950af5ae3234b31ce430d91a603867fbc6413e4` (GOALS-AUDIT PR #1081). Revalidate against the actual HEAD at execution.

## 1. Objective, scope, and boundaries

Restore a coherent, genuinely playable path from first gathering to highest-tier production, using the audit as a defect inventory **and** an opportunity to assess whether every item family, tier, tool, workstation and construction step makes sense to a player.

- **FIX rather than remove:** Do not silently delete tutorial goals, simplify recipes to hide defects, or mark approved functional content FUTURE to make audit counts look better. Repair approved-but-broken acquisition/production/interaction mechanisms and make them testable.
- **Separate defect vs design choice:** Restore already-approved mechanics in code under their existing authoritative contracts; changes to item identity, tier order, role, recipe costs, unlocking policy or material substitution require an explicit creator decision. Keep a reasoned proposal, not an unapproved edit.
- **Guide, not gate:** Gameplay stays free-form. Goal order is instructional only, with optional branches, and no artificial recipe locks. This project is the complete game guide, NOT a short onboarding tutorial.
- **Rewards deferred:** Keep all coin reward amounts and the proposed 651-goal catalog unchanged during mechanics repairs. The audit's 3,059 vs 15,670 copper models are preliminary and time-untested. A later separately authorized economy pass will tune payouts.
- **Existing design decisions remain in force:** Planks and Hardwood Boards never substitute; Iron/Steel hand saws and Sawmill have equal lumber yields (different speed); the creator's newer copper → bronze → improved smithy/bellows → iron route replaces the earlier optional-bronze/no-bronze-required first Iron Saw route; reconcile the old master catalog before implementation; doors are separate from empty doorway frames; approved roof slopes and door configuration rules stand; no unauthorized item renaming or adding stations.
- **Versioned evidence:** `main` stays stable. Use the established feature-branch → review → merge-to-`dev` gate, with small PRs and clear rollback. Actual gameplay changes require tests and the creator's normal development approvals.

## 2. Evidence and tracking

Read first: `docs/design/PLAYER_GOALS_REWARDS_AUDIT.md`, `docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv`, `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md`, `docs/design/PLAYER_JOURNAL_GOALS_UI.md`, `docs/design/DYNASTY_MASTER_ITEMS.md`, `docs/design/CATALOG_IMPLEMENTATION_PLAN.md`, `docs/design/catalog_ledger.json`, current `CLAUDE.md` and related approved authority files. Source-of-truth data: `data/items/{items,recipes,blueprints,structures,cooking,drops,gathered,crops}.json`, `data/tables/flora.json`, and actual server/client runtime.

**Audit baseline:** 651 proposed goals: 230 PASS, 247 NEEDS_CORRECTION, 30 NEEDS_TEST, 144 BLOCKED; 26 additional candidate activity goals are recommendations, not yet approved. 323 were read individually and 328 only rule-checked; no goal has been gameplay-verified. The 144 BLOCKED are not 144 independent fixes: about 120 have source-chain blockers and 24 refer to locked blueprints (source counts overlap). Do not claim the status improves without re-running the verified ledger on a new commit.

Create/maintain a separate repair execution tracker at `docs/ai-team/missions/GOALS-REPAIR/STATE.md` when implementation begins. Every work item must record: audit GA IDs, exact symptoms, intended approved behavior with citation, proposed implementation, dependencies, responsible specialist, test cases, verified artifact SHA, regression risk, and PASS/FAIL/BLOCKED/NOT_RUN. Keep the **original audit unchanged as historical evidence**; use a separately versioned post-repair verification report and reconciliation rather than overwriting the baseline.

**Acceptance evidence levels:** STATIC_READ, AUTOMATED_TEST, HEADLESS_GODOT, PLAYED_F6, MULTIPLAYER_RESTART. 'PASS' must state which kind. A test that injects raw item IDs, forcibly calls a server function, admin-spawns materials, or skips acquisition does **not** prove a player can follow the tutorial.

## 3. Prioritized repair work packages

### P0 — Baseline contracts, reproducible blockers, and shared test harness

**Priority:** Immediate. **Depends on:** Audit baseline only. **Scope:** Docs/test harness, no gameplay changes.

- Reproduce every root blocker at the checked-out `dev` SHA; audit `GA-01` through `GA-04`, `GA-10` through `GA-13`, `GA-20` through `GA-31`, `GA-40` through `GA-49`, and all 24 locked-blueprint entries. Resolve mistaken audit claims before coding.
- Define a start-from-empty character test route (without item spawning), progression milestones, a separate side-branch test set, and stable deterministic seeds/conditions. Use only real public player actions or their proper gameplay interfaces.
- Make an ingredient-source coverage matrix: every material used by approved active recipes must be obtainable, have a meaningful alternative, or be explicitly flagged for owner review; track biome/season/tool restrictions.
- Create a progression-coherence matrix per item/station family: first availability, input source, preceding equipment, tangible benefit, higher-tier replacement, alternative route, cost/effort, station level, and gameplay verification.
- Recheck approved/future/retired status. Keep code, master catalog and effective active content clearly separated. No renames or recipe changes yet.

**Gate:** Evidence-based root cause map and repair tickets; no false assumption that rule-only PASS items were manually validated.

### P1 — Fix missing natural resources, water, and farming interaction

**Priority:** First gameplay unblock. **Depends on:** P0. **Can parallelize by subsystem**, with one writer per shared data/server file.

1. **Tanbark / tanning source (GA-01):** Data currently describes bark/tannin from suitable trees, but normal E-on-tree is blocked. Implement a legitimate, server-authoritative tree/bark harvesting path consistent with approved forestry rules (inspect whether it should be stripped from a standing or felled tree; prefer minimum added mechanic and reuse existing tree/drop systems). Respect reach, depleted/duplicate harvesting, resource quantities, season/world persistence where applicable. Test actual acquisition → Scraper/processed hide → Tanning Rack → Leather.
2. **Pine tar (GA-02):** Scots pine data advertises pine tar but actual trunk loot only emits resin. Repair production in the correct tree species and harvesting/felling path, preserving all intended existing drops and deterministic quantities. Confirm raw pine tar → Tar → Water wheel; do not fabricate materials for tests.
3. **Recipe water (GA-04):** Filling buckets/waterskins stores liquid as volume, but a recipe consumes a stackable `water` item; this disconnect blocks Leather, Concrete and many others. Design one consistent liquid-ingredient adapter that draws water from real authorized filled containers (inventory/station sourcing as applicable). Validate volume units/quantity, consumption only on successful craft, freshwater suitability, partial volumes, overflow, ownership, save/load and multiplayer; do **not** mint unlimited stackable water or arbitrarily define one water unit without an approved mapping.
4. **Farming crop actions (GA-03):** Server implements sow/harvest/watering but the client lacks the corresponding actions. Wire actual UI/input to authorized server handlers, proper bed/seed states, tool requirements, time/season, validation, feedback, growth and persistence; test wheat, barley, oats, rye and flax as appropriate for their actual season. Verify the entire flax → linen and grain → milling/food path in gameplay.
5. **Broader acquisition coverage:** Recheck remaining suspected raw-source gaps, including ore/bog iron, clay/sand/limestone, flint, wool, hides, seeds, wild ingredients, fuel and shoreline harvest. Fix demonstrably missing links without inventing spawning rules. Particular attention to a typical starting biome and the approved wilderness route to an Iron Saw.

**Gate:** Real client-controlled acquisition and crafting checks for bark, tar, liquid water and farm harvest; previously blocked source chains become mechanically achievable (not merely reachable by admin spawn). Trace affected goal IDs in the ledger.

### P2 — Make the primitive tutorial route actually playable

**Priority:** High. **Depends on:** P1 source fixes where used; otherwise parallel test preparation.

- Starting character can pick up sticks and stones, harvest fibre, craft Twine, basic Stone Knife/Axe/Pickaxe, fell an appropriate tree and reliably understand which log species yields small vs large blocks (GA-10/12/35). Ensure a route to the Wooden Hammer and Chopping Block is accurately described and obtainable from a normal start.
- Chopping logs and splitting firewood: reconcile manual axe-on-block actions, Chopping Block interaction, direct recipes and item naming. Both legitimate paths must yield the intended wood and generate an observable completion signal (GA-13/43/45). Respect charcoal/fuel economy and preserved manual alternatives.
- Campfire: build, place, fuel, light; reach medium with three firewood pieces and bonfire with three whole logs, accounting for wet wood, pots and fuel burn-down. Confirm tier state in world and its user-facing feedback; any goal event must reflect an actual player-caused achievement.
- Food/water early tutorial: a new character starts with full thirst/hunger; do not teach a goal that appears impossible until dehydration. Correct goal wording/placement or completion semantics by matching intended gameplay (GA-36). This is distinct from recipe-water mechanics.
- First functional shelter: actual foundation/wall/empty doorway/separate door/roof 45 and roof 65, Lean-to, bed, and Workbench. Check attachment and placement with genuine F6 runtime evidence, including known playtest issues. Keep legitimate build rules; report design conflicts rather than papering them over.

**Gate:** One fresh-player walkthrough can complete the primitive route without hidden developer-only steps, mystery ingredients, impossible prerequisite, or cheating. Note that this is gameplay verification of mechanics, not automatic certification of the entire new goal system.

### P3 — Make the meaningful production branches work end-to-end

**Priority:** High. **Depends on:** P1 and the necessary early stations from P2.

- **Leather/textiles:** Hunting and butchering before hide, appropriate tools/animal availability; Scraper → processed hide → tannin bark + liquid water + Tanning Rack → Leather; then Leatherworking, Tailoring, Loom, Thread, cloth, flax/linen and wearable products. Check garment usefulness, station roles and resource sourcing.
- **Cooking/preservation:** Campfire cooking, Drying Rack, Smoker, Food Preparation Table, Clay Hearth/Oven, Preserving Jar and real maturing/use; validate correct intermediate dishes, recipes, seasonal ingredients, fluids and food effects as implemented. Separate missing engine interactions from optional instructional goals.
- **Forestry/woodworking:** Logs → blocks/firewood; first Iron Saw → Planks and Hardwood Boards by hand (equal finished yield to Sawmill, slower); Workbench level 1/2/3 upgrades and add-ons; Nail/Hinge production; Sawmill's actual waterwheel and elevated river foundation rules. Preserve distinct material identities and ensure the Sawmill does not require an exclusive product it alone produces.
- **Metals — creator's newer progression:** Stone tools gather stone/clay/wood and permit construction of BOTH the Primitive Smelter and Primitive Smithy without metal parts or sawn boards. Primitive Smelter makes copper and tin ingots; Primitive Smithy makes first **copper tools**. Copper + tin become bronze in the Primitive Smelter; bronze output and bronze fittings enable construction of the next, **Bronze Smithy**. Forced-air Bellows Smelter then produces iron, and **the Bronze Smithy must be capable of forging both the Iron Saw and the Iron Anvil**. The Iron Saw unlocks sawn Planks and Hardwood Boards; **the Iron Anvil is a required construction component for the next, iron-anvil-equipped top-tier Smithy**. Working these iron components on the Bronze Smithy's bronze anvil is possible but accelerates station wear. The improved smithy then provides more efficient ironworking and advanced tooling/quality; wind-driven Blast Furnace adds steel and batch throughput. Do not silently restore the old no-bronze-required iron route or omit copper tools. Validate each metal, ingredient, station, forging durability, fuel source and acquisition step, and flag exact new recipes/item records for creator approval.
- **Other implemented mechanics:** storage, trade, fishing, farming, tool repair, weapon crafting, mounts/vehicles only where approved and actually live. Identify missing player interactions, but keep unrelated FUTURE content out of this repair mission until separately authorized.

**Gate:** At least one legitimate input-to-final-output play/automated test for each major station family, plus its claimed upgrade benefit. No active station should be mechanically pointless unless its convenience/throughput advantage is explicitly intentional.

### Creator-directed smelting progression and dedicated Coal Bin supply (13 Nov 2026)

**Creator-directed design captured for implementation planning, with exact construction recipes, radii, capacities and intervals still to be specified.** The older idea of drawing fuel directly from kilns, fires or ordinary storage is **deleted** from this plan: the source rule below replaces it, not an additional fallback.

- **Tier 1 — Primitive Smelting Furnace:** stone and clay construction with a tall chimney and natural draft; handles lower-temperature copper, tin and bronze production. Ore input, coal/charcoal fuel hopper and ingot output.
- **Tier 1 — Primitive Smithy (first metalworking shop):** buildable using only materials and stone tools obtainable at the start (stone, clay, wooden blocks and logs, per creator's stated concept). No iron, bronze, nails, boards or preexisting metal parts required. It uses a simple charcoal fire and stone anvil, and shapes copper ingots into the first copper tools and bronze ingots into early bronze tools and fittings. It **does not smelt ore**. Confirm exactly which copper tools exist, or propose new approved definitions, and check access to copper/tin with stone gathering tools.
- **Tier 2 — Bellows Smelter:** metal fittings (e.g. pins/hinges) allow manually worked bellows to increase furnace heat and process iron. Design how pumping heat is maintained without repetitive busywork.
- **Tier 2 — Bronze Smithy:** built after bronze production, with an improved forge, bellows and bronze anvil; it can work copper/bronze and **forge the Iron Saw AND Iron Anvil from iron ingots** produced at the Bellows Smelter. Ironwork on the bronze anvil causes accelerated wear, not an arbitrary recipe ban. The Iron Saw unlocks Planks, Hardwood Boards, nails-based bins and more advanced construction. **The Iron Anvil made here is mandatory for construction of the next iron-anvil-equipped top-tier Smithy**; do not require that next Smithy to manufacture its own Iron Anvil. The advanced Smithy has a better forge, bellows, iron anvil, tool racks and quenching capability. Preserve previously approved masterwork capabilities, but reconcile whether the older separate *Master Smithy* is this top tier or a further prestige tier before defining names/IDs. Avoid hidden prerequisites: bronze pins/hinges, bellows leather/tannin, fuel, iron ingots and tools needed for the upgrade must all be obtainable beforehand.
- **Tier 3 — Windmill-powered Blast Furnace:** a windmill mechanically drives two bellows; automatic queued batch processing uses a large ore store, coal/charcoal fuel hopper and ingot output. Stronger wind increases processing speed; calm weather slows but does not stop processing. Wind changes throughput, **not ingot yield per ore**.
- **New buildable item: Coal Bin.** Dedicated bulk fuel storage, not a generic chest. It accepts **only Coal and Charcoal**. It must expose available quantities and honor ownership/access controls, finite capacity, world persistence and authorized manual deposits/withdrawals. Its materials, quantity, size, visual design, capacity and build tier require a separate item/recipe approval; do not invent these as existing facts.
- **Strict source rule — smelters AND smithy forges:** All tiers of smelter and the heated forges contained within all smithy tiers may periodically replenish their internal fuel hopper **only from nearby accessible Coal Bins**. Check infrequently/eventually rather than every game tick; pull available Coal/Charcoal up to free hopper capacity, with safe and deterministic behavior for competing consumers. Do **not** auto-source from kilns, campfires, ordinary chests, loose world items or other workstation inventories, even if they contain Coal or Charcoal.
- **Absolute item restriction:** Automatic fuel collection is restricted to item types **Coal and Charcoal**. Never auto-pull wood of any kind (sticks, kindling, branches, logs, blocks, firewood, planks or boards), or any other combustible material. Do not treat a generic `fuel` ingredient group as permission to pull wood.
- **Charcoal byproducts:** Any applicable wood-burning fire or kiln may leave collectable Charcoal under the approved charcoal-production rules. That charcoal does **not** teleport directly to the furnace or smithy. It must first be placed in a Coal Bin through a legitimate player/storage interaction; any future automation of bin filling is a separate design decision, **not** authorized by this plan. Do not steal fuel that is actively burning or reserved by another operation.
- **Manual fuel handling:** The restriction concerns **automatic sourcing**; do not silently delete existing legitimate manual fuel-loading mechanics while implementing the new Coal Bin path. Clarify any difference between manually accepted furnace fuel and Coal Bin's Coal/Charcoal-only inventory before coding.
- **Processing safety:** Stop or pause cleanly when fuel, ore or output space is insufficient. Every Coal Bin-to-consumer transfer must conserve items, respect access permissions, be atomic under multiplayer and survive saves/restarts; choose collection radius, polling interval and contention policy during engineering tuning.
- **Progression gate:** From a fresh stone-tool character, produce copper and bronze; build the Bronze Smithy; use Bellows Smelter iron ingots at the Bronze Smithy to craft an **Iron Saw** and an **Iron Anvil**, then use the produced anvil to build the advanced iron-anvil Smithy. Assert that the advanced Smithy, iron anvil, and iron saw do not require each other as prerequisites in a cycle. Measure increased bronze-anvil wear during ironworking. Do not simply spawn finished iron parts to pass this gate.
- **Acceptance test:** Fill a Coal Bin with Coal/Charcoal near a Primitive Smelter, Bellows Smelter, Blast Furnace and smithy forge; verify authorized transfer. Put Coal/Charcoal in ordinary chests, kilns, campfires and other stations within the same radius; verify **zero automatic transfer** from them. Place all forms of wood nearby; verify **zero automatic wood transfer**. Test full hoppers, empty bins, two consumers competing, owner permissions, persistence, manual refueling, and no duplication. Verify charcoal produced by burning is first obtainable and reaches the consuming workstation only after it has been deposited in a Coal Bin.

**Creator authority reconciliation required:** On 13 Nov 2026 the creator explicitly described the revised progression: stone tools → Primitive Smelter + Primitive Smithy → copper tools → copper/tin/bronze → Bronze Smithy → forced-air iron production → **Iron Saw and Iron Anvil crafted at Bronze Smithy** → iron-anvil top-tier Smithy. This **supersedes the earlier master s2.7 first-Iron-Saw route that required no bronze**, for progression design. Do not leave two competing rules or pretend the older wilderness route remains unchanged. Before changing runtime/catalog files, prepare the exact obsolete-rule deletion/replacement in `DYNASTY_MASTER_ITEMS.md`, `CATALOG_IMPLEMENTATION_PLAN.md`, `progression.md`, recipe/blueprint requirements and test scenarios for the creator's design approval. Preserve the separation: smelters make ingots; smithies shape ingots and never smelt ore. No automatic gameplay authorization comes from this planning note.

### P4 — Construction-tier consistency, functional item value and unavailable blueprints

**Priority:** High after material chains; design review can start immediately. **Depends on:** P0/P1, P2 for basic builds.

- Verify all seven approved construction quality labels and each tier's actual practical build set: Foundation → Walls → empty Doorway → installed Door → Window → Floor/Ceiling → Roof/Stairs as appropriate; separate arched/double variants and gates. Present each tier in the guide as a buildable home, not disconnected foundations and late doors.
- Check material tiers and source progression: Crude/Refined/Rustic/Sturdy/Superior/Engineered/Fortified, plus the approved door formulas, roof pitches and no Plank/Hardwood Board substitution. Identify non-monotonic requirements, useless grades, inconsistent role descriptions, or misplaced material bottlenecks; propose rather than silently change creator-approved formulas.
- Verify actual item value: a higher-grade tool should provide a defined capability, efficiency, durability or other benefit; station upgrades should unlock real recipes or improve throughput; furniture grades should affect intended comfort/storage/looks/value, not arbitrary recipe expense. Distinguish **upgrade**, **alternate style**, and **optional convenience**; avoid artificial progression gates.
- Inspect the **24 locked-blueprint goal targets** (GA-31) individually: 23 catalog KEEP rows and one FUTURE Wool Rug according to the audit. For each, distinguish currently approved/expected playable content, an inactive future mechanic, an absent implementation, and a learnability/UI wiring defect. **Do not blindly set known=true or unlock broken pipe/water features.** Make currently intended systems functional and teachable; propose a separately approved implementation scope for genuinely missing systems. Never delete these goals from the design.
- Verify Stonecutter's Bench Bronze Chisel gate against master section 2.1 (chisel is for sculpture/art only, not required for stone construction). Treat this as a design/data conflict; restore approved behavior if the authority is clear.
- Audit stale live recipes yielding FUTURE items and retired-but-active item rows. Lock impossible/not-yet-approved recipes correctly; never turn an unreleased item live just to satisfy an audit.

**Gate:** Each approved playable tier can be completed as a useful functional structure with the tools and materials available at that point, and every locked blueprint has an explicit justified state/next action.

### P5 — Align instructions and automatic goal detection with repaired gameplay

**Priority:** After mechanics stabilize. **Depends on:** P1–P4. **Not authorization to activate the 651-goal proposal or change rewards.**

- Independently read and correct all 651 instructional rows, including 328 formerly rule-only entries. Rebuild ingredient/station/acquisition graph against repaired code. Track every correction to audit GA IDs in a review revision (not silent rewrite of an approved catalog).
- Remove runtime `after` gating from **reward eligibility** while preserving guide display ordering; support out-of-order acquisition/made/placed event history. Keep legacy goal IDs and a defensible migration plan. Ensure no duplicate payouts from overlapping basic and tier-item goals.
- Design reliable first-hand acquisition and actual-action hooks; distinguish item acquisition from transfer, purchase or admin grant, and count produced quantities consistently. Define which event types count before implementation.
- Avoid 651 per-player goal checks every quarter second; evaluate indexed affected goals on events, reconstruct once on join, persist reward and completion atomically and promptly; benchmark on representative multiplayer sessions.
- Maintain goal rewards as coins only per earlier creator decision; **do not rebalance their amounts yet**. Any conversion of legacy item rewards or retroactive rewards, migration payout policy and HUD display behavior must be separately approved and regression-tested before release.
- Add goal-state synchronization and placard-ready completion events to the deferred Journal/HUD implementation only after the content/engine gate; prevent celebratory replay on join and avoid notification floods.

**Gate:** Verified goal catalog, corrected how-to text, reliable completion and regression tests; separate explicit creator approval to make the new catalog live.

### P6 — End-to-end playability and closeout

**Priority:** After each vertical slice and again at integration.

- On `dev`, play a fresh character from empty hands through primitive shelter, established metal-and-saw route, working farms and leather, useful steel equipment, and highest currently supported construction tier. For long-running or season-gated chains, record limitations and perform controlled tests without conflating state injection with genuine play.
- Check alternate material routes and at least one meaningful item per side family; verify the 328 formerly rule-only goals individually before publication. Playtests in F6 on Dave's PC are the final confirmation, never replaced by headless scripts.
- Validate save/reload, multiplayer authority, farming/season clocks, world persistence, correct station range, performance and no inventories/coin duplication.
- Re-run audit scripts and generate a **post-repair delta**: which root defects closed, which of 144 BLOCKED goal paths now have actual sources, which findings remain, exact new commit, and tests/evidence. Never edit the original `950af5a` audit as if it had always passed.
- Hold the reward economy and final Journal presentation for the agreed later stage, after measured actual effort and usable content are established.

**Gate:** Credible source-to-endgame evidence with explicit unresolved issues; no claim of 100% playable if an active branch remains untested.

## 4. Concrete priority and sequencing

| Order | Work | Unlocks / why now | Evidence milestone |
|---|---|---|---|
| 0 | P0 baseline, test harness and source matrix | Prevents false positives and unauthorized design changes | Repro test suite + dependency/coherence inventory |
| 1 | Tanbark, pine tar, recipe water | Unblocks leather, Water wheel/Sawmill, concrete and many dependent goals | Real-character obtain-and-craft tests |
| 2 | Farming client sow/water/harvest + source coverage | Unlocks grains, flax, clothing and foods | Client-controlled crop cycle test |
| 3 | Primitive route: logs/blocks, hammer, firewood, three fire sizes | Makes the tutorial beginning genuinely playable | New-character F6 walkthrough |
| 4 | Leather/textile, woodwork/saw, smelter/forge/steel production | Connects raw sources to useful equipment and stations | Workstation-family end-to-end tests |
| 5 | Building tiers, water/well blueprints, doors, meaningful upgrade review | Completes structures and identifies design changes requiring approval | Complete-tier build checks + owner-decision log |
| 6 | Goal tracking and text revision, after mechanical correctness | Accurate rewarded tutorial, no false completion | Rebuilt ledger + all-rows review |
| 7 | Final integration walk-through; defer economy/UI to subsequent authorized work | Release-grade understanding of true blockers | Post-repair audit and player evidence |

These orders are dependency-based, not deadlines. Work can parallelize when no shared writer or dependency blocks it. Each PR should be a small testable vertical slice, not a single massive rewrite.

## 5. Explicit item/progression quality rubric (run across every work package)

For each relevant item, recipe, station, material and quality tier answer, with evidence:

1. **Purpose:** What does this unlock, improve or enable for a player? Is the benefit discernible in gameplay?
2. **Timing:** Can this be acquired at the moment the guide introduces it, without unexplained resource/biome/season/tool gating?
3. **Dependency sanity:** Are inputs available and credible? Do quantities and station/tool requirements make sense and avoid accidental circularity or premium-material demands on basic objects?
4. **Tier value:** Does the next tier make a meaningful improvement rather than cost more for no benefit? If deliberately decorative, present it as an alternate, not a required power step.
5. **Station purpose:** Does each specialized or advanced station unlock unique production, genuine speed/scale/convenience, or a clear quality advantage? If not, mark it as potentially redundant, with options.
6. **Alternative routes:** Are currently approved alternatives retained (Iron Saw vs Sawmill, manual chopping vs Chopping Block), while the superseded old Stone Forge / no-bronze iron route is not silently reintroduced? Does the Primitive Smithy genuinely support copper/bronze tools and the Bronze Smithy upgrade without circular prerequisites, and can the Bronze Smithy make both the Iron Saw and Iron Anvil before either is needed to build the higher Smithy?
7. **Construction coherence:** Can a player complete a whole useful tier of building, including doors in doorway frames and proper roof pieces, before the guide moves on?
8. **Resource realism and supply:** Is an ordinary player able to source the amount without unreasonable busywork? Differentiate scarcity by deliberate design from accidental missing drops.
9. **System integration:** Does it use existing crafting/repair/placement/transport/storage/fuel/quality rules consistently, including server/save authority?
10. **Player instruction:** Can an inexperienced player reproduce the entire step with the actual controls and enough detail, but without massive repeated text?

Tag discrepancies as **DEFECT AGAINST EXISTING APPROVED RULE**, **DESIGN COHERENCE PROPOSAL**, **MISSING FEATURE**, **FUTURE/OUT OF SCOPE**, or **TEST NEEDED**. Only the first category can be fixed without further design approval when evidence is unambiguous. Every other change must retain original approved wording and request a targeted creator decision.

## 6. Decisions and sign-off

**Already established for planning:** Repair missing mechanics rather than delete goals; review whole item/progression design, not just goal JSON; do not balance reward amounts now; keep guide comprehensive and optional; preserve approved item/door/wood/metal decisions unless the creator explicitly revises them.

**New creator-directed metalworking sequence (13 Nov):** Primitive Smelter and Primitive Smithy are stone-tool buildable; the Primitive Smithy makes copper tools; the Primitive Smelter makes bronze from copper and tin; bronze supports the Bronze Smithy; iron processing follows the improved forced-air smelter; **the Bronze Smithy crafts both the Iron Saw and the Iron Anvil, and that Iron Anvil is required to build the next top-tier Smithy**. This replaces the former no-bronze-required early-iron metalworking sequence. Exact copper item catalog, bronze fitting costs, required fuel, metal/ore stone-tool accessibility and balance remain to audit before any implementation.

**Open for precise design review before any affected implementation:** Exact water volume-to-recipe-unit consumption convention; tree bark stripping and pine-tar yield interactions where approved rules are silent; distinction between intended-live vs genuinely future water-pipe/garden infrastructure; whether any recipes/tool-tier requirements need intentional change (including Stonecutter/Chisel); detailed reward migration and new 26 optional goals when goal implementation is authorized. Resolve one explicit decision at a time with alternatives and evidence.

**Final approved repair sequence** should be issued to Claude only after the creator reviews this plan. The coordinator must not reinterpret review of this plan as blanket authorization for catalog, economic or gameplay-design changes.

## 7. Durable output locations for implementation phase

- **This plan (authority for scheduling, NOT permission to rewrite catalog):** `docs/design/PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md`.
- **Execution status & handoffs:** `docs/ai-team/missions/GOALS-REPAIR/STATE.md`.
- **Implementation findings and proposed design decisions:** `docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md`.
- **Post-repair evidence/report:** `docs/design/PLAYER_PROGRESSION_REPAIR_VERIFICATION.md` (created when actual tests begin).
- **Baseline immutable comparison:** `docs/design/PLAYER_GOALS_REWARDS_AUDIT.md` and `docs/design/PLAYER_GOALS_AUDIT_LEDGER.csv` at merge `950af5a`.

## 8. Required iterative review before execution

Have one independent reviewer examine dependencies/obtainability, one examine item-and-tier usefulness against the master catalog, and one examine testability/security/persistence. Reconcile objections in the plan, check for unapproved rules, conflicts with active missions and missing upstream prerequisites, and repeat until no additional substantive plan improvement appears. Report remaining uncertainties rather than claiming perfect coverage.
