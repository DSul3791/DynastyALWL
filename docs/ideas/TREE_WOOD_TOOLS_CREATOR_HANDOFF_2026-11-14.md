# Tree harvesting, wood processing and starter tools — creator handoff
Date: 14 November 2026
Reviewed and revised: 15 November 2026
Repository: DSul3791/DynastyALWL
Status: Dave requested this handoff and a prompt for Claude to build the discussed system. This is a temporary implementation brief, not an independently edited official design document. Claude remains lead designer and implementation authority.
Scope: Replace the existing tree/wood workflow and integrate the approved tool, station, furniture and transport changes. Preserve unrelated designs.

## 1. Provenance and authority
Source: the creator discussion beginning “How felling trees work,” through Dave's request to put the decisions into documents and prepare Claude's build prompt. Quoted excerpts below are verbatim; other requirements are summaries.
- “I want trees to fall, break into logs and logs are able to roll.”
- “yes there is now one firewood type.”
- “there are no large or small blocks just Wooden Blocks.”
- “so the first tool will be a stone axe and the second is a stone hammer.”
- “Hammer/Repair Tool - Repair structures, place blueprints or harvest stones and ores”
- Carving station: “it just need too wooden blocks at first and whatever knife you have in your inventory.” The intended quantity is TWO Wooden Blocks, confirmed repeatedly in the discussion.
- Knife menu: “any simple stations that only require wood to make or wood and twine, could be on the knife build menu”
This request authorizes the scoped implementation handoff; it does not approve unrelated catalog changes or promotion to main. Dave's acceptance of this handoff is scoped design input, not blanket approval of a breaking save/protocol or major architectural change. Follow current decision authority for any such implementation choice and identify the concrete decision rather than asking Dave to reapprove the already agreed gameplay.

### Applying the existing catalog freeze
Current docs/ai-team/DECISION_AUTHORITY.md permits implementation of Dave-approved catalog decisions but forbids discretionary ingredient, station, blueprint and recipe redesign. The confirmed changes below are the specific approved input; they do not lift that freeze globally.
- Implement the explicit changes: unified Firewood and Wooden Block, Copper-first saw access, two-block carving-station cost, log/Twine longbow inputs, approved menus and transport roles.
- Preserve compatible existing costs/yields. For unspecified new ingredient counts, new furniture/vehicle costs, block/firewood yields or other discretionary catalog choices, produce ONE concise proposal table identifying proposed values, rationale and dependencies. Obtain the required approval only for those unresolved entries; do not ask Dave to approve the already settled concept again.
- Distinguish code parameters within delegated authority from frozen catalog choices. A provisional label does not authorize writing an unapproved recipe into live data.
- Continue independent coding, validation and documentation while such decisions are pending; checkpoint the exact blocked rows. Avoid a mission-wide stop or an artificial claim of completion.
- The requested Stone Hammer replaces the starter pick role; the final disposition of any redundant Stone Pickaxe and later Wooden Hammer records must be explicit. Do not silently delete saved identities, or keep the Stone Pickaxe as a required progression step.

## 2. Confirmed design

### 2.1 Felling and materials
- Trees physically fall. Large softwood and hardwood trees automatically separate into collectible logs when they land. No second chopping stage to turn a fallen trunk into logs.
- Logs remain physical world objects capable of rolling on terrain.
- Smaller softwood and hardwood trees fall and break directly into 0.5 m Firewood, providing early fuel without a saw or sawbuck.
- There is ONE Firewood material. Eliminate the hard/soft distinction in recipes, fuels and player-facing names.
- There is ONE Wooden Block material identity, referred to collectively as Wooden Blocks, with no large/small or softwood/hardwood variants. Use one canonical item ID; plural wording must not create multiple materials.
- Keep softwood versus hardwood log identity, including useful species identity, because the sawn outputs differ.
- Retain the established 3 m full-log baseline and yields: one suitable softwood/basic log makes SIX Planks; one hardwood log makes FOUR Hardwood Boards. These remain separate ingredients with no substitution.

### 2.2 Carrying and hauling
- A character can visibly carry up to TWO logs simultaneously.
- Balance log weights so an average character can carry two with ordinary equipment and supplies. Real timber mass must not defeat this gameplay target.
- The complete Firewood yield of one small tree must be carryable by an average character already carrying an axe, food and water.
- Logs may be carried home or loaded onto a log sled, handcart or wagon.
- Handcart: hand-operated only, small, light and simple. Practical loads include about THREE small trees' worth of Firewood, ONE barrel of goods, or a load of carrots. These are alternative load examples, not cumulative capacity.
- Log sleds AND wagons have Small/Medium/Large versions:
  - Small: pulled by a character by hand.
  - Medium: requires one horse.
  - Large: one ox OR two horses.
- The log sled is intended for hauling wood. Surface restrictions were not settled; see section 4 rather than treating an all-terrain or snow-only rule as newly approved.
- Do not bring back the rejected wheelbarrow.
- Reconcile the older animal cart and wagon catalog with these decisions; do not silently remove unrelated passenger vehicles or carriage designs.

### 2.3 Sawing and production
- A handsaw can cut logs into Wooden Blocks on the ground. This is slow but possible without a sawbuck, solving first-block access.
- A handsaw can also cut logs into Planks or Hardwood Boards on the ground without a sawbuck.
- Sawbuck: built from Planks and Nails. Speeds up cutting logs into Wooden Blocks.
- A sawmill speeds up plank/board production.
- Hand sawing takes long enough to encourage better production equipment, but small jobs must remain tolerable. Do not turn the upgrade incentive into excessive grind.
- Preserve the approved plank/board yields with hand saws and the mill. Performance upgrades should be based on speed/durability rather than silently changing those yields.
- Blocks are the intermediate used to make Firewood from large-tree logs. The exact splitting action is an open recommendation in section 4.

### 2.4 Starter tools and context menus
- Stone Axe is the first tool; Stone Hammer is the second. Stone Knife completes the useful starting toolkit. Do not create artificial tutorial locks forcing this order if the game otherwise permits out-of-order crafting.
- Stone Hammer takes over early stone/ore harvesting previously assigned to Stone Pickaxe. Reconcile Stone Pickaxe recipes, goals and references; do not leave it as a mandatory duplicate starter tool. Metal pick progression remains subject to dependency review.
- Top hammer context option: “Hammer/Repair Tool”.
- Description: “Repair structures, place blueprints, or harvest stone and ore.”
- Contextual targeting: hitting a structure attempts repair; hitting a rock/mineral harvests it within tool capability. Blueprint placement remains available.
- Failed repair or an already repaired structure must not accidentally become a demolition attack. Show missing materials or “No repair needed” as appropriate.
- Preserve existing ordinary-hammer repair sourcing and War Hammer exclusion.
- Equipped knife right-click opens simple furnishing/station blueprints. Move eligible blueprints out of the hammer menu.
- Include simple wooden stations/furnishings requiring only wood or wood and twine. Evaluate functional suitability as well as costs; do not automatically move structural house pieces merely because they are wooden.
- Stone Knife can use this menu. Normal placement previews, rotation, material sourcing and placement validation apply. A knife does not bypass the need to obtain sawn ingredients.

### 2.5 Copper Handsaw and first-block dependency
- Copper Handsaw is the first saw, crafted at the Primitive Smithy using smelted copper and a wooden handle. Its recipe must not require Wooden Blocks, Planks, Hardwood Boards or another saw.
- Primitive Smelter and Primitive Smithy must remain buildable with stone-stage resources/tools, without metal, nails or sawn wood.
- Early Firewood must support campfire charcoal production before the first metal. Preserve Coal versus Charcoal distinction.
- Copper saw slowly produces blocks and appropriate planks/boards. Bronze, Iron and Steel saws form later upgrade options; exact costs and performance are balance choices.
- Functional journey: gather stone/sticks/fibre → Stone Axe/Hammer/Knife → small-tree Firewood and large-tree logs → campfire charcoal and copper ore → Primitive Smelter/Smithy → Copper Handsaw → blocks/planks/boards → carving station, sawbuck and expanded woodworking.
- Do not retain old “no Bronze saw” or “first boards require Iron Saw” rules as active constraints.

### 2.6 Wood Carving Station
- Construction cost: exactly TWO Wooden Blocks.
- Permanent appearance: one upright cutting/carving block and another block with a worn sitting surface, with sawdust and wood shavings scattered around the ground.
- Opens the normal station crafting interface with selectable recipes.
- Recipes source materials from station inventory, character inventory or nearby ground. Retain existing eligible nearby-storage behaviour where compatible with current sourcing rules; do not invent a permission bypass.
- Carving recipes require a suitable knife in the character's inventory as a reusable tool, not a consumed ingredient. Support Stone Knife.
- A usable knife is supplied by the character. Decorative knife props are permitted (Dave described knives around the work area); they do not grant a free usable tool or bypass the recipe requirement.
- Longbow belongs here, using logs and Twine instead of Wooden Blocks. Exact quantities remain for review; no extra stave item, partial-log system or batch of bows is implied. Yield efficiency is a balance consideration, not a mandatory fractional-log feature.
- Other carved goods such as bowls and platters are candidates for recipe reassignment after auditing their real requirements. Do not invent their approval or exact new costs.

### 2.7 Simple furnishings
- Knife-placeable log bench resembling the supplied reference: a rough split-log seat/top resting on two short round log supports.
- Single-seat and double-seat sizes, suitable around a fire pit.
- Simple block seats, log tables and eligible wooden stations form the initial menu direction; select a coherent useful set based on existing assets/recipes.
- The Wood Carving Station is knife-placeable, separate from the firewood Chopping Block. Its carving surface does not automatically make it a fuel-processing station.
- No new “split-log” inventory material is approved merely to depict the bench; use existing logs/blocks unless Dave approves another material.

## 3. Required compatibility audit before replacing the old routes
Inspect CURRENT dev code/data, not just the old catalog appendix. Earlier desk checks found:
- Wooden Hammer uses a block: Stone Hammer now covers starter construction. Reconcile its recipe/goals without making Wooden Hammer an early dependency; outright deletion of all later wooden tools is not authorized.
- Blocks feed bowls, clubs, hammer, spyglass, quarterstaff, crossbows and platters; large blocks feed Chopping Block and longbow. Map these uses explicitly to the single block material or the new carving recipe. Do not lose goods or create further size variants.
- Existing identity candidates: firewood (26), firewood_soft (236), wooden_block (234), wooden_block_soft (237), wooden_block_large (540), wooden_block_soft_large (541). Recheck IDs against current data before migration; preserve retired numbers.
- Existing recipe families include hand/mill Planks and Hardwood Boards, direct chopping-station log→firewood, large→small block conversion and campfire charcoal from hard firewood.
- Preserve whole logs as valid materials for construction, stations, wells/pipes, log furniture and kiln charcoal. Physical hand carrying must not make them unavailable to those consumers.
- Preserve bark→Twine/shingles, oak tanning bark→Leather/Heavy Leather, Scots pine pine tar→Tar, and all other actual tree-sourced dependencies (roots, sticks, kindling, seeds, resin or species products where current data uses them). Determine real sources; do not assume all should become random felling drops.
- Migrate fuel references, burn durations/heat, shops/prices, NPC jobs, storage/racks, goals/rewards/tutorials and UI descriptions. Preserve exact-item storage assignment during merging.
- Prevent duplication when a physical log is held, dropped, loaded, stored, consumed or saved. Remove it from the source exactly once.
- Follow current CATALOG_SAVE_MIGRATION.md: blanket compatibility with every experimental world is NOT required. Declare which save versions are supported. For supported saves, explicitly map affected items, queues, drops and container contents without silent loss or duplication. If an older version is unsupported, reject it clearly before mutation; do not erase characters or auto-reset the world. Review resource equivalence when large and small blocks merge; identical item counts or coin values are not automatically equivalent wood quantities.
- Confirm basic copper/tin are harvestable with Stone Hammer, and that neither first smithy requires saw-produced resources.
- Inspect runtime species/material ingredient matching, not only JSON: every eligible softwood/hardwood species must reach its proper processing route, and generic whole-log construction costs must accept the intended logs without enabling Plank/Hardwood Board substitution.
- Use the existing authoritative multiplayer transaction model. Concurrent pickup, crafting, repair and vehicle loading must reserve/consume materials once; cancellation, full output, tool breakage and disconnect must not lose or duplicate them. Loading a carried log must release its held representation.
- Ground/source ranges and access permissions remain those of the relevant existing system. No global or remote sourcing is implied.
- Preserve already approved Reset World semantics for newly introduced felled-tree records, player-moved logs, vehicle cargo and stations. Explicitly classify natural versus player-changed state; do not invent new character/inventory deletion or world-generation changes.
- Inventory IDs, display text, generated catalog tables, menu filters and goals must all agree. Keep historical audit evidence labelled historical rather than rewriting its past findings.

## 4. Open points and recommendations — NOT verbatim creator decisions
Claude should choose routine engineering/balance defaults only within current decision authority and the catalog-freeze boundary above. Record recommendations distinctly from approved data. Batch required catalog decisions and other consequential unresolved design choices for Dave; continue independent work rather than blocking the entire mission.
- Recommended: axe splits Wooden Blocks into Firewood anywhere; Chopping Block speeds that operation. Never reintroduce axe-cut logs→blocks, since blocks now come from sawing. Resolve whether retaining this optional ground operation fits the intended station progression.
- Propose tree size thresholds, logs/tree, Firewood/tree, blocks/log, Firewood/block, weights and recipe costs. Honour carrying targets and established board yields; route frozen catalog choices through the approval table rather than treating this list as approval of arbitrary values.
- Define tolerable durations, saw wear, copper/bronze/iron/steel benefits and sawbuck/mill operating requirements. Distinguish game-time duration from real-world elapsed interaction time using project terminology. Check the existing time conversion before tuning; no mandatory real-world waits are approved.
- Define directional fall control, collision damage to characters/animals/buildings, obstructed falls, and log settling. Impact damage was discussed as a question, NOT explicitly approved.
- Define stump persistence/removal and regrowth; preserve existing approved behaviour until intentionally reconciled.
- Set vehicle dimensions, cargo capacities, terrain handling, recipes, loading controls and visible loads. Small sled pre-metal access is not settled.
- Check animal/harness implementation before claiming medium/large hauling is playable. Reuse existing paired-draft design where compatible; one ox must work for the newly approved large-hauler option.
- Determine the log sled's usable surfaces and practical drag resistance; do not silently make the forestry sled snow-only or frictionless on every surface.
- First-tool recipes must use gathered stone, sticks and fibre/Twine, not blocks, planks, carved handles, leather or products from the stations those tools are meant to unlock. Check the full prerequisite chain for early containers, furnace materials, fuel and copper access.
- Log seats using Wooden Blocks are naturally post-saw. For a bench whose supports appear block-shaped, explicitly choose a log/block recipe and its legitimate tool stage; the knife menu does not create a pre-copper block source.
- “Reusable knife” means not consumed as an ingredient. Preserve existing durability rules; decide and record recipe wear rather than silently making the knife indestructible.
- Define a concrete ordinary starting load and average-character capacity from actual game data for carry tests. Test both wood classes, two carried logs, and all Firewood from the largest eligible small tree. Do not grant infinite capacity, suppress all other carried weight, add backpack slots or auto-drop belongings to satisfy the target.
- No automatic approval to rebuild all passenger transport, forestry ecology, combat or the general inventory system.

## 5. Official documents Claude must reconcile
Use docs/DOC_MAP.md to revalidate paths. Update the canonical rule in place, removing obsolete live instructions; use Git history for historical text rather than stacking conflicting overrides.
| Document | Required reconciliation |
|---|---|
| docs/design/DYNASTY_MASTER_ITEMS.md | Tool roles/ladders §§2.1–2.2; wood/Chopping Block §§2.3–2.4; fuel §2.6; first saw §2.7; material/station identities and recipes; vehicles §3.11; affected storage/carved goods and generated tables |
| docs/design/item_system.md | Unified materials, Copper-first sawing, contextual hammer, knife placement, carving station and sources |
| docs/design/progression.md | Real starting dependency journey, early charcoal, first blocks, early ores and vehicles |
| docs/design/buildables_plan.md | Knife versus hammer blueprint ownership, simple furnishings and new station placement |
| docs/design/STORAGE_WAREHOUSING_DESIGN.md | Two-log handling, physical-log sourcing, merged materials, racks and vehicle cargo |
| docs/design/PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md; CATALOG_IMPLEMENTATION_PLAN.md | Integrate this scoped replacement into the real repair sequence |
| docs/design/CATALOG_SAVE_MIGRATION.md | Explicit block/firewood mappings, queues/storage/world entities and no-loss handling |
| Current goals/recovery/tutorial documents and actual goal data | Revised tool/material/station actions; preserve rewards unless a separate change is approved |
| docs/DOC_MAP.md; CONTROLS.md and affected current specs | Correct discovery links and context menus; remove contradictory active descriptions |
Inspect other CURRENT references and runtime data for matching dependencies. Do not rewrite unrelated authoritative rules or historical evidence.

## 6. Suggested implementation sequence and evidence
1. Read live rules and inspect current dev implementation. Produce a scoped dependency/material/ID mapping and check for concurrent work before changing shared paths.
2. Reconcile canonical documents with this creator brief; separate confirmed requirements from proposed balance decisions. Produce the bounded catalog proposal table required above for remaining discretionary data choices, and continue unblocked work.
3. Implement merged materials and the scoped supported-save/version policy, Stone Hammer harvesting/context mode, Copper-first sawing and first-block progression.
4. Implement physical tree falling/automatic log breakup, small-tree Firewood, rolling logs and two-log carrying.
5. Implement sawbuck, Wood Carving Station, recipe reassignment and knife blueprint placement/furniture.
6. Implement handcart and small sled/wagon, then horse/ox/paired-horse variants with the required animal dependencies. Scope phases coherently; do not claim the transport requirements complete while merely documenting them.
7. Run relevant checks and independent review under current repo gates. Integrate reviewed work into dev; do not promote main or modify Dave's active PC/playtest checkout without its established authorization.
Acceptance evidence:
- Fresh non-admin journey from gathered materials through first Copper Handsaw and first two blocks, without circular prerequisites.
- Small-tree Firewood fuels a fire and makes charcoal; copper route works without hardwood-biome dependence.
- Softwood/hardwood give correct, distinct sawn outputs with starter saw and mill.
- Large tree falls once and becomes correct log count once; small tree creates only its intended wood output, not duplicate logs plus full Firewood.
- Logs roll plausibly; carry one then two, refuse third, stow tools while carrying, transfer/drop/reload safely. Normal starting load meets carry targets.
- Carving station costs two blocks, requires but does not consume knife, and sources each approved location correctly; longbow uses logs/Twine.
- Knife menu owns eligible simple blueprints, previews/rotation/validation work, and two bench sizes are usable seating.
- Hammer repairs structures and harvests eligible deposits, with no accidental structure damage on failed repairs.
- Cancel sawing/carving mid-job, fill the output, break/remove the required tool, and disconnect/rejoin: verify coherent transaction and recovery behaviour using existing contracts.
- Two clients attempt the same log pickup or station/vehicle transfer: exactly one authoritative transfer occurs. Verify counts after moving out of streaming range and returning, save/reload and reconnect.
- Unsupported older saves fail clearly without mutation; supported conversions preserve inventories, queues, bin assignments and overflow safely.
- Every hauler size is tested with its approved puller and alternative handcart load examples; persistence works loaded/parked/hitched.
- Supported old firewood/block variants map across all supported saved locations without silent loss or duplication; explicitly unsupported versions are rejected before loading/mutation. Fuel and affected recipe consumers still function; document conversion quantities rather than assuming all old block sizes map 1:1.
Use relevant tests permitted by the actual gates. Clearly label code/data checks versus actual Godot/F6 validation, and tests not run. No test count or documentation update proves playability.
Remove replaced obsolete runtime code under the existing decision-61 rule after its consumers are migrated; do not leave competing legacy harvest paths or compatibility flags that revive the old design. Keep intentionally required supported-save readers distinct from obsolete gameplay code.
Use the current risk-based test gate, with relevant tests, required integration/startup checks and independent review. Do not run forbidden cloud Godot jobs or expand routinely to a full suite; label unavailable PC/F6 checks NOT RUN.
Checkpoint progress and remaining issues in the repo. Before completing, iteratively review the diff AND cross-document consistency until no substantive unresolved issue is hidden.

### Review record — 15 November 2026
This review checked the conversation, the committed handoff and current dev versions of the master catalog, item system, progression, buildables, storage, save policy and decision/test rules.
1. Creator-decision pass: preserved confirmed behaviour; removed an unsupported restriction on decorative knives, moved sled surface assumptions to open choices, and clarified that longbow yield efficiency is not a new fractional-log requirement.
2. Dependency/compatibility pass: corrected blanket migration overreach to the actual supported-save policy; added first-tool prerequisites, species-aware input matching, transaction/interruption handling and existing reset semantics.
3. Scenario/prompt pass: walked the fresh copper/first-block route, post-saw furniture access, carried/stored/processed log lifecycle, concurrent pickup and unsupported-save rejection. Clarified how to retrieve the brief while implementing from current dev. Remaining undecided design/balance points stay explicitly listed in section 4.
4. Authority/execution pass: read the complete current decision-authority rule and rechecked starter recipes. The three stone tools already use gathered materials. Corrected the brief's overbroad delegation of unspecified catalog choices: preserve approved decisions, batch only unresolved frozen-data entries, and continue independent implementation. Added obsolete-code cleanup and explicit risk-based test boundaries.
No gameplay code or official design documents were changed by this review. Static handoff review does not prove runtime correctness or absolute completeness.

## 7. Ready-to-use Claude build prompt
Read this handoff in full and implement the scoped tree harvesting, wood processing, starter-tool, carving, knife-blueprint and hauling replacement it describes.

Start from current origin/dev, read CLAUDE.md and the active workflow/test/authority rules, and work on reviewed feature branches targeting dev. The brief is in PR #1147 on branch feature/wood-system-creator-handoff-2026-11-14 at docs/ideas/TREE_WOOD_TOOLS_CREATOR_HANDOFF_2026-11-14.md. If absent from current dev, fetch that branch and read its latest file (for example with git show origin/feature/wood-system-creator-handoff-2026-11-14:docs/ideas/TREE_WOOD_TOOLS_CREATOR_HANDOFF_2026-11-14.md). Do not base implementation on its older dev snapshot or blindly merge/cherry-pick the handoff branch. Recheck PR status and concurrent work first. Inspect current runtime code and data before deciding what already works. Treat section 2 as Dave's confirmed target, section 3 as a dependency checklist to recheck, and section 4 as explicitly unresolved recommendations/balance choices.

As lead designer and implementation authority, consolidate the requirements into the official documents listed in section 5, replacing obsolete live rules rather than adding contradictory override notes. Preserve unrelated approved designs, stable IDs and supported-save contents under the current compatibility policy. This request is scoped authorization to implement these changes, not permission for unrelated catalog redesign or main promotion.

Make the starting journey playable: Stone Axe/Hammer/Knife; small-tree Firewood; campfire charcoal; copper harvesting/smelting/smithing; Copper Handsaw; first Wooden Blocks; knife-built two-block Wood Carving Station; sawbuck; appropriate woodworking; physical logs and approved hauling. Keep the established six-Plank/four-Hardwood-Board yields.

Use the phased sequence and acceptance evidence in section 6. Resolve routine engineering details within your authority. The catalog freeze still applies: implement the confirmed changes, preserve compatible existing values, and batch unspecified catalog costs/yields or recipe redesigns in one proposal table for the approval that the current rule requires. Do not use provisional values as permission to change frozen live data. Escalate other consequential design choices only when genuinely undecided. Do not block all independent work on an open detail. Continue through implementation and relevant verification, with independent review and normal dev integration gates. Report exact commits, completed behaviour, known limitations and any F6 checks Dave still needs to perform. Do not call the full mission complete while required transport or runtime verification remains missing.

Before finishing, review the implementation and all affected current documents iteratively for old material variants, iron-only saw gates, obsolete starter pick/hammer dependencies, duplicate blueprint ownership, missing tree products and item-loss/duplication routes. Leave a durable checkpoint if the work spans sessions. Retire this temporary brief only after its decisions and unresolved dispositions are safely incorporated.
