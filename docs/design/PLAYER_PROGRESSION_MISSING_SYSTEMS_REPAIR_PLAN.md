# Dynasty — Missing Mechanics, Item Coherence & Full-Game Progression Repair Plan

**Status: REVIEW PLAN — creator-approved direction to FIX missing gameplay rather than delete tutorial goals. This file is NOT a blanket authorization to change approved item/recipe/progression rules or to implement/reprice the goals.**
**Date:** 13 November 2026. **Baseline reviewed:** `dev` merge `950af5ae3234b31ce430d91a603867fbc6413e4` (GOALS-AUDIT PR #1081). Revalidate against the actual HEAD at execution.

## 1. Objective, scope, and boundaries

Restore a coherent, genuinely playable path from first gathering to highest-tier production, using the audit as a defect inventory **and** an opportunity to assess whether every item family, tier, tool, workstation and construction step makes sense to a player.

- **FIX rather than remove:** Do not silently delete tutorial goals, simplify recipes to hide defects, or mark approved functional content FUTURE to make audit counts look better. Repair approved-but-broken acquisition/production/interaction mechanisms and make them testable.
- **Separate defect vs design choice:** Restore already-approved mechanics in code under their existing authoritative contracts; changes to item identity, tier order, role, recipe costs, unlocking policy or material substitution require an explicit creator decision. Keep a reasoned proposal, not an unapproved edit.
- **Guide, not gate:** Gameplay stays free-form. Goal order is instructional only, with optional branches, and no artificial recipe locks. This project is the complete game guide, NOT a short onboarding tutorial.
- **Rewards deferred:** Keep all coin reward amounts and the proposed 651-goal catalog unchanged during mechanics repairs. The audit's 3,059 vs 15,670 copper models are preliminary and time-untested. A later separately authorized economy pass will tune payouts.
- **Existing design decisions remain in force:** Planks and Hardwood Boards never substitute; Iron/Steel hand saws and Sawmill have equal lumber yields (different speed); Bronze is a meaningful optional/alternative route without blocking the approved wilderness iron-saw route; doors are separate from empty doorway frames; approved roof slopes and door configuration rules stand; no unauthorized item renaming or adding stations.
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
- **Metals:** Smelter → ingots, Smithy (must be lit or have suitable charcoal/coal when cold) → Iron Saw/tools; Stone Forge/bronze as a viable branch; Blast Furnace → Steel; Master Smithy/Tempered and craftsmanship as currently approved; meaningful tool tiers, repairs and sharpening. Check that every forge or station adds a real ability or convenience. Do not force the bronze path as a prerequisite to the approved independent bog-iron route.
- **Other implemented mechanics:** storage, trade, fishing, farming, tool repair, weapon crafting, mounts/vehicles only where approved and actually live. Identify missing player interactions, but keep unrelated FUTURE content out of this repair mission until separately authorized.

**Gate:** At least one legitimate input-to-final-output play/automated test for each major station family, plus its claimed upgrade benefit. No active station should be mechanically pointless unless its convenience/throughput advantage is explicitly intentional.

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
6. **Alternative routes:** Are approved alternatives retained (Stone Forge vs Smithy bronze, Iron Saw vs Sawmill, manual chopping vs Chopping Block) and explained accurately without secretly forcing one?
7. **Construction coherence:** Can a player complete a whole useful tier of building, including doors in doorway frames and proper roof pieces, before the guide moves on?
8. **Resource realism and supply:** Is an ordinary player able to source the amount without unreasonable busywork? Differentiate scarcity by deliberate design from accidental missing drops.
9. **System integration:** Does it use existing crafting/repair/placement/transport/storage/fuel/quality rules consistently, including server/save authority?
10. **Player instruction:** Can an inexperienced player reproduce the entire step with the actual controls and enough detail, but without massive repeated text?

Tag discrepancies as **DEFECT AGAINST EXISTING APPROVED RULE**, **DESIGN COHERENCE PROPOSAL**, **MISSING FEATURE**, **FUTURE/OUT OF SCOPE**, or **TEST NEEDED**. Only the first category can be fixed without further design approval when evidence is unambiguous. Every other change must retain original approved wording and request a targeted creator decision.

## 6. Decisions and sign-off

**Already established for planning:** Repair missing mechanics rather than delete goals; review whole item/progression design, not just goal JSON; do not balance reward amounts now; keep guide comprehensive and optional; preserve approved item/door/wood/metal decisions unless the creator explicitly revises them.

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
