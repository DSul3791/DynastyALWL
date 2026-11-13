# BUGLIST-001 — Dynasty: A Life Well Lived — Audited Playtest Bugs
**Tracking ID:** BUGLIST-001  
**Issued:** 2026-11-13  
**Source:** Player playtest report dated 2026-11-13; CCR00–CCR03 approved decisions  
**Status:** 11 open user-reported issues; 1 approved design requirement requiring verification  
**Purpose:** Give Claude an evidence-driven, bounded implementation and QA backlog. This packet records player observations and approved expectations, **not confirmed root causes**.

## A. Authority, baseline and non-goals

1. Read the repository's current approved `CLAUDE.md`, constitution/workflow/test-gate documents, current design decisions, active mission records, and relevant agent handoffs before editing. The *repo's approved policies* control workflow; this packet controls the *reported playtest expectations* only. Escalate contradictions with exact evidence; do not silently invent rules.
2. `main` remains the protected-by-process stable milestone branch. Implement on feature branches using the team's approved PR/review/test gates, integrate to `dev`, and do **not** merge `dev` into `main` without explicit release approval. Inspect current actual branch and SHA; historical SHA `27d27fbbb` was a Mission 001 baseline, not necessarily today's HEAD.
3. Current playtest context: Mission 001 Phases 0–10 were integrated to `dev`, but gameplay acceptance remained outstanding. The master item-catalog proposal had not been approved. No broad item-catalog implementation is authorized by this packet.
4. **BLOCKER-001 Reset World is separate from these 11 items.** Implementation was reported complete, but gameplay verification was outstanding. Before declaring the next playtest unblocked, confirm it is present on the actual tested `dev` build and that Reset World removes **player modifications only** (terrain edits, character-built/placed objects and ground-dropped items), preserving procedural world generation, seed/parameters, naturally generated objects, character inventory, and progression. Do not reopen the reset implementation without evidence.
5. Preserve previously approved building fundamentals: minimum basic foundation footprint **4×4 m**; 2 m/4 m compatible wall system and full double-door opening; adjustable first-foundation vertical placement up to 2 m, existing snapping/stacking rules, grounding/support behavior, and larger/castle construction options. Check current authoritative documents for exact details; do not infer new geometry or support rules.
6. Do not modify unrelated systems: procedural generation, broader crafting/food design, First Hours Goals, journal shortcuts, player progression, unrelated UI, placeholder-art initiative, or the frozen master item catalog. Change scoped dependencies only when proven necessary and approved.
7. Resource-contention-related `test_flora_density` timeouts and the known `test_npc_view` shutdown crash were observed previously. Establish baselines and investigate genuine new regressions; do not falsely label an existing shutdown issue as caused by this repair work. Use risk-based targeted testing plus independent review and appropriately justified broader runs per the approved gates.

## B. Priority and sequencing

- **P0 separate prerequisite:** Verify BLOCKER-001 reset in a running `dev` playtest before clearing the prior playtest blocker.
- **P1 construction blockers:** BUG-008 foundation, BUG-009 wall preview/placement, BUG-007 path surveying; then BUG-010 doorway and BUG-011 modular roofs (these include expressly approved design corrections; do not use them to justify a broad redesign).
- **P2 core behavior:** BUG-001, BUG-003, BUG-005 (axe routing, physical effort and recovery; investigate together, root causes may differ).
- **P3 presentation/world fidelity:** BUG-006 vegetation/LOD, BUG-004 rain timing, BUG-002 campfire illumination. Order within these can follow dependency and team capacity.
- **Verification track:** DESIGN-001 backpacks (record pass/fail; if fail, isolate defect and correct within the approved equipment design).

Severity remains as the player's source report: BUG-007 through BUG-011 **High**; BUG-001 through BUG-006 **Medium**. Priority is an execution plan, **not a relabeling of severity**. Retain all records, including those not reproducible at first.

## C. Audited bug-by-bug acceptance criteria

### BUG-001 — Missed axe swings consume no exertion (Medium)
- **Observed:** Repeated axe swings in empty air did not raise exertion.
- **Required:** Every *actually executed* swing incurs an effort cost whether it hits or misses. An attempted input blocked by cooldown or another legitimate constraint is not a completed swing. Successful swings must not be charged twice; check other tools/weapons for the same failure mode without expanding scope without evidence.
- **Proof:** In a deterministic/testable state, measure exertion after equal counts of hit and miss swings, with movement/recovery accounted for; confirm each executed action incurs one appropriate cost. Preserve fitness/progression tuning unless expressly needed.

### BUG-002 — Large campfire illumination too weak (Medium)
- **Observed:** Large campfire lights a smaller area than a handheld torch; nearby vegetation/terrain are too dark.
- **Required:** The large fire's light **output** is at least **4× the torch's**; this is *not* a 4× radius requirement. Appropriate larger reach, warm flame-coupled flicker across nearby surfaces, size-based illumination, natural falloff, darkness beyond the lit zone.
- **Proof:** Inspect/compare configured effective output and range in equivalent units or document an equivalent defensible comparison; nighttime side-by-side screenshots/video of terrain, trees and bushes, with frame-rate/performance check. Do not globally increase ambient illumination to fake the fix.

### BUG-003 — Axe swing says “There is no ice to cut here” (Medium)
- **Observed:** An axe swung into empty air emits the ice-specific error.
- **Required:** Ordinary attack/chop swings execute without irrelevant ice messages; specialized ice interactions still produce correct contextual feedback when intentionally selected.
- **Proof:** Test empty air, normal wood/resource hit, genuine ice interaction, and relevant alternate action controls. Compare BUG-001 code paths but do not assume a shared cause.

### BUG-004 — Puddle/rain audio precedes visible rainfall (Medium)
- **Observed:** Puddle-like impacts play while sky appears clear and no raindrops are visible; rain follows later.
- **Required:** Audio and visual weather state agree. Early drops favor leaf/branch impacts; then soil/rock as precipitation grows; puddle/standing-water sounds when water exists or accumulates. Existing puddles can respond to the *first actual drops*. Preserve natural approach and fade transitions.
- **Proof:** Record a dry-to-rain-to-dry weather transition with precipitation state, visual emission, wetness and audio-layer start/stop timing; verify no puddle-rain layer fires before relevant precipitation/water conditions. Do not introduce an unrelated fluid-simulation feature.

### BUG-005 — Normal walking raises exertion (Medium)
- **Observed:** Walking increased exertion.
- **Required:** Walking causes slow **net** recovery in ordinary conditions; standing/resting recovers faster; jogging and sprinting increase exertion relative to effort. Preserve reasonable transitions and existing fitness mechanics.
- **Proof:** Compare exertion/time in idle, walk, jog and sprint under controlled conditions (without other actions). Verify order and signs of rates; test transition from strenuous activity to walking and then idle. Review interaction with BUG-001 to prevent double charging or masking costs.

### BUG-006 — Distant grass appears flat and then drops/aligns onto slopes (Medium)
- **Observed:** Flattened-looking grass patches at distance become correctly hill-conforming on approach; screenshot evidence was supplied in original playtest.
- **Required:** Grass/vegetation placement conforms to the actual intended terrain surface across LODs, preserving hill silhouettes with no conspicuous vertical repositioning as the player approaches.
- **Proof:** Reproduce on same hillside at multiple known distances and LOD transitions, with matching camera views or video; test after relevant terrain edit/reset if supported. Diagnose height sampling, mesh/data synchronization and placement separately. **Do not change terrain seed/world-generation rules merely to hide the symptom.**

### BUG-007 — “Survey a Path” immediately says road is finished (High)
- **Observed:** A new survey action immediately declares completion.
- **Required:** A fresh path-survey operation begins the real existing survey/proposed-route workflow; surveying, construction and completion have distinct truthful states and messages. Completion only after its actual defined requirements.
- **Proof:** New unsurveyed area → begin survey → meaningful route/progress state → valid construction → completion; verify early repeated invocation, cancel/restart (if already supported), save/load (if persisted), and completion messaging. Consult current approved road specification for workflow details; do not fabricate new road-building mechanics.

### BUG-008 — Crude foundation falsely rejects tolerable slope (High)
- **Observed:** Red preview with “Ground is too steep” on apparently suitable ground.
- **Required:** Placement succeeds within the established approved slope/grounding tolerance and correctly rejects genuinely invalid surfaces; reasons must describe actual blocker. Preserve **4×4 m minimum** footprint and preapproved elevation/snapping/grounding behavior.
- **Proof:** Log inspected terrain samples/normal/slope across *full intended footprint*, actual threshold and collision/obstruction reason; test level, moderate, boundary and truly steep ground, both initial and snapped foundations. Do **not** loosen a threshold blindly or flatten the underlying generated terrain.

### BUG-009 — Green crude-wall preview is rejected (High)
- **Observed:** A preview indicates green at a corner, but final click returns “You cannot place that there”; seen at **two of four corners**, adjacent blue wall blueprints visible, no visible obstruction.
- **Required:** Preview and commit use equivalent authoritative validation and actual geometry, including snapping/occupancy and compatible building pieces. A valid green preview places; invalid placement is red and reports correct specific reason. No unconditional “force place.” Preserve 2 m/4 m wall compatibility and double-door design.
- **Proof:** Recreate all four corner orientations with blueprints and with completed adjacent walls; compare preview and commit validator inputs/results; test rotation, collisions, occupancy and at least one save/load case if placement persistence affected.

### BUG-010 — Doorway wall looks solid/contains nonfunctional door (High; scoped design correction)
- **Observed:** “Doorway” appears to have a built-in unusable door and blocks passage.
- **Required:** Doorway wall = genuine framed **open passage**, no integral door. Player and NPC can pass; door is a separate installable/operable item that attaches to compatible doorway. Preserve approved 4 m wall/double-door fitting requirements.
- **Proof:** Inspect visual mesh, actual collision and navigation clearance (not only rendered gap), walk through with no door, install functional separate door **where already supported/approved**, test opening/closing/blocked passage, snapping and persistence. **Catalog freeze constraint:** if a *new* door item/recipe or unapproved master-catalog entry is essential, surface exact dependency for authorization rather than silently modifying the frozen catalog. Fix open-frame geometry and collision independently where feasible.

### BUG-011 — Crude roof mesh and attachment wrong (High; scoped design correction)
- **Observed:** Current crude roof is the wrong shape/attachment concept.
- **Required:** Components named exactly **`Crude - Roof 45`** (45°) and **`Crude - Roof 65`** (65°), each a sloped roof *panel only*, with **no legs/posts**. Either end attaches to compatible wall-top/horizontal connection and may rise or fall from its anchor; correct modular snapping, preview, collider and placed result.
- **Proof:** Test both slopes × both anchor ends × upward/downward orientation, wall-top and other *existing compatible* horizontal attachment points; assemble a simple roof from multiple panels; verify no phantom supports, no clipping and accurate collision. Check how replacing existing roof variants affects saved placements/IDs; do not silently delete placed roofs or add a whole new building tier.

### DESIGN-001 — Backpacks improve carry weight, not inventory slots (Approved requirement; verify)
- **Requirement:** Equipping a backpack must **not** change the count of inventory slots. It improves comfortable carry-weight capacity/encumbrance through better weight distribution; different backpack quality may change this effect. This is **not automatically a confirmed defect**.
- **Proof:** Compare slot count and weight/encumbrance thresholds before equipping, with backpack equipped, and after unequipping; verify no item loss/duplication, including near capacity and saved games. If current implementation differs, log the actual bug and fix only the approved behavior.

## D. Repair work groups and evidence standard

| Work group | IDs | Primary risk |
|---|---|---|
| Construction and build placement | BUG-008, 009, 010, 011 | Existing geometry, snapping, support, saved blueprints |
| Physical effort and axe interactions | BUG-001, 003, 005 | Duplicate exertion charges, recovery interactions, contextual action dispatch |
| Roads | BUG-007 | State transitions and false completion |
| Terrain/vegetation fidelity | BUG-006 | LOD height mismatch, worldgen side effects, performance |
| Environmental presentation | BUG-002, 004 | Lighting performance and weather/audio sync |

For **each** record, capture: baseline branch/SHA; a reproducible case (or explicit *not reproduced*); root cause supported by code/logs, clearly distinguished from guesses; minimal change and affected files; automated checks with pass/fail; manual/in-game visual confirmation required where applicable; regression risks; review/PR/commit; final status `Fixed—automated verified`, `Ready for player verification`, `Verified in game`, or `Blocked—with exact reason`. Never equate screenshots/headless tests with full player acceptance. Preserve original 11 IDs for traceability.

## E. Release / next-playtest handoff

Deliver a concise table for all 11 BUG IDs and DESIGN-001 with: severity, status, root cause, PR/commit, tests, and **exact F6 player action**. List outstanding risks and any needed design decisions in a separate short section; do not turn this into a new multi-feature roadmap. `dev` only, following approved review/merge gates. Verify BLOCKER-001 in game before telling the player the prior playtest blocker is closed. `main` remains unchanged without explicit release authorization.
