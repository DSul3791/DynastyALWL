# Dynasty: A Life Well Lived — World Resource Distribution Architecture

**Purpose:** Architectural handoff describing the resource distribution Claude needs to implement in the world. Read the intended experience first, then the system responsibilities and acceptance criteria.

**Date:** November 21, 2026  
**Design source:** David Sullivan's direction in this discussion.  
**Authority:** Claude is the lead designer and implementation authority. This handoff describes the required world behaviour; Claude determines the code structure and reconciles it with the existing project. It does not claim that these features already exist or amend official design documents.

## Part 1 — The intended world

### 1. The central idea

The island should have a coherent resource landscape. Players begin near the sea with small, accessible stones. Following rivers inland brings them into areas containing additional metals, larger rocks, exposed deposits and increasingly difficult terrain. The distribution should be understandable through exploration rather than a uniform scattering of unrelated resource nodes.

Iron is broadly available from the beginning. Copper is available across a smaller inland area, and tin across a smaller but still substantial interior area. Travelling inland adds materials to those already available. It does not replace iron with copper or copper with tin.

The intended early sequence is wood and stone, copper, bronze made using copper and tin, then iron enabled by improved processing equipment. Players may already know several iron locations before they can process it. Tin should take more exploration than copper or iron, but the first useful supply must be reachable on the starting island without ships or an excessive expedition.

### 2. Overlapping resource areas: the paint analogy

Imagine pouring iron-coloured paint from the island's centre until it spreads over almost the whole island. A smaller pour of copper-coloured paint covers much of the interior. A smaller pour of tin-coloured paint covers less of the interior again.

| Map area | Resources that can occur |
| --- | --- |
| Broad outer iron area | Iron, ordinary rocks and relevant non-metal materials |
| Overlapping copper area | Copper and iron, alongside ordinary rocks |
| Overlapping tin area | Tin, copper and iron, alongside ordinary rocks |

These areas should have irregular, terrain-informed outlines resembling overlapping blobs on a topographical map. They must not become perfect concentric circles, rigid bands or a checkerboard of resource types. An irregular island may have several interior hill or mountain groups rather than one useful point at its geometric centre.

Dave's examples of 80% copper coverage and 60% tin coverage explained the analogy. They are estimates, not selected coverage percentages, distance thresholds, deposit quantities or implementation constants.

“Layers” here means overlapping resource availability on the map. It does not mean vertically stacked underground sheets or solid iron beneath every square metre. Availability determines where deposits and finds can occur; individual occurrences remain separated by ordinary terrain and rock.

### 3. Rock form changes along the journey

The same progression in size and shape applies to ordinary rocks and ore-bearing rocks. Resources also occur on land away from rivers throughout their availability areas. Rivers provide especially readable routes and transported finds; they are not the only places resources spawn.

| Position in the landscape | Dominant rock form | Intended result |
| --- | --- | --- |
| Shore and lower river reaches | Rounded, fist-sized loose stones | Accessible gathering and recognizable early ore finds |
| Farther upriver | Larger rounded rocks mixed with small stones | Increasing quantities and usefulness of tools |
| Interior rivers and foothills | Larger, less-rounded rocks and small boulders | First useful tin in its distribution area; worthwhile bronze-stage exploration |
| Upper rivers and headwaters near mountains | Angular boulders, jagged outcrops and exposed ore | More obstructed travel and substantial mining opportunities |

Transitions must be gradual and varied. Small gravel can remain among large boulders, and occasional exceptions should prevent an artificial appearance. The dominant visual pattern must still be clear.

Rivers are natural navigation routes. A player following one inland should encounter clues that help explain the surrounding resources. Larger and more angular material generally points toward a nearby source. Mountains, steep ground, boulders, jagged outcrops and existing dangers increasingly constrain travel.

### 4. Tin must be practical to find

Tin belongs to a substantial inland area, not one tiny randomly selected spot. Players should reach the first workable tin before the most difficult mountain terrain. It must provide enough material for meaningful bronze progression, not merely one decorative specimen.

Continuing upstream should reward players with larger sources and more productive extraction. The hardest terrain provides better sustained supply; it must not be the only place to obtain early tin.

Small river finds can extend downstream from an inland source. This is a limited, source-linked extension of the resource area, not permission to distribute tin along every shoreline. Copper and tin should retain their inland identity.

### 5. Coal has its own landscape pattern

Coal does not use the nested metal-area rule. Place coal districts using suitable hillsides and mountain edges near water, particularly slopes above bog-like areas below hills and mountains.

Coal should appear as exposed seams or deposits within rock faces, eroded banks and gullies. Loose coal near an exposure can help reveal it. It should be possible to discover an exposed seam and follow it into the hillside.

Use sedimentary host rock where the world supports it. The wet basin and hillside relationship guides the appearance and placement; not every present-day bog must contain coal, and coal should not become an evenly scattered black-boulder resource.

### 6. Minerals and valuable discoveries

Mining a metal deposit or following a coal seam should occasionally expose additional minerals or valuable material: gems, crystals, gold, silver and other supported resources.

The discovery should exist in the world as a pocket, vein or associated deposit. Removing surrounding material reveals something players can inspect and extract. It should not be only a random bonus item added to inventory when an unrelated rock breaks.

Associations must be selective. This does not require gold, silver and every gem to occur inside coal, or every primary deposit to contain treasure. A discovery may be in adjacent host rock exposed during excavation. Claude determines appropriate associations using existing resources and practical geological references.

### Desired results and failure patterns

| What we want | What we do not want |
| --- | --- |
| Overlapping irregular resource areas | Exclusive metal bands, perfect rings or uniform random scattering |
| Practical early tin on the starting island | A tiny lucky find, an excessive expedition or a ship requirement |
| Early iron sightings with later processing | Iron hidden until the player unlocks its use |
| Gradual changes in rock size and shape | Identical ore boulders everywhere or abrupt size boundaries |
| Finds that lead toward useful sources | Decorative clues with no meaningful resource relationship |
| Surface entry points into mining | Blind underground digging as the only progression route |
| Difficult inland terrain with greater extraction rewards | Every early tin route blocked by mountains or boulders |
| Coal seams exposed in suitable hillsides | Coal as evenly scattered generic black rocks |
| Occasional physical discoveries of valuable material | Every resource dropping every valuable item through a universal loot roll |

## Part 2 — Architecture Claude should implement

### 7. One connected generation model

Resource placement must connect broad availability, actual deposits, surface objects and underground discoveries. Independent random placement must not contradict those relationships.

| Responsibility | Required output |
| --- | --- |
| Landscape context | Island boundaries and interior, river connectivity and reaches, hills and mountains, slope, water proximity and available host-rock information |
| Resource availability | Broad iron coverage, smaller overlapping copper and tin areas, and separately selected coal districts |
| Deposit generation | Finite resource occurrences with a location, extent, material, extractable quantity and discoverable exposure where required |
| Surface representation | Loose stones, larger rocks, boulders and outcrops consistent with location and source |
| Associated discoveries | Occasional material pockets related to a deposit or its surrounding rock |
| Validation and persistence | Reachable early resources, stable generation, region continuity and retained extraction state |

These are responsibilities, not mandated new classes or services. Reuse existing world-generation and mining capabilities where possible. First inspect the actual code and data; no repository inspection has been performed for this document.

### 8. Terrain and river context

Use the island's actual landmass and terrain to distinguish coast, lower rivers, interior, foothills and headwaters. Do not use world-origin distance as a substitute for island context or absolute elevation as the only measure of inland progression.

River placement must understand upstream and downstream connectivity, including tributaries. A find below a confluence may originate from one tributary; the other tributary need not contain the same resource. Lakes and disconnected drainage must not create fictitious upstream links.

Where river data exists, use it. If essential context is missing, Claude should identify the smallest addition needed to support this distribution rather than silently substituting unrelated random spawns.

### 9. Availability fields and actual occurrences

Create broad, irregular availability fields that preserve the paint model. Copper generally extends farther toward the coast than tin. Iron remains broadly available within both. Distribution should follow the island interior and terrain without forcing exact geometric nesting at every boundary.

Blend deposit frequency across edges so visible resource placement does not reveal a hard invisible line. The fields may describe suitability or density rather than binary membership, provided the resulting world preserves the intended overlapping areas.

Generate actual deposits within these areas. Keep frequency, deposit size, extractable quantity and surface evidence as separate tuning controls. A broad tin area can contain scattered occurrences while still being dependable to search.

Place ordinary rock throughout the landscape using the same regional form rules. Do not make every rock inside a resource field ore-bearing. Visually distinguish harvestable iron ore from ordinary rock with a rusty surface; colour alone must not turn every red-brown stone into useful ore.

### 10. Source-linked surface material

Connect surface finds to a local mineralized area or a specific source deposit. Choose the level of bookkeeping that fits the existing generator, while retaining a meaningful spatial relationship.

- At a source, expose ore-bearing rock and place angular fragments or boulders nearby.
- Downhill, allow a patchy scatter of material derived from that source.
- Along connected rivers, allow transported rounded material downstream, with sizes generally decreasing away from the source.
- Keep transported quantities and reach limited enough to preserve the inland copper and tin progression.

A river stone points upstream; it does not promise a vein directly beneath it. A nearby angular fragment points toward the local source. Visible clues must be useful often enough for players to learn and trust the pattern.

The architecture does not require a physical erosion simulation. Generation can approximate transport using source position, drainage connectivity and configurable distance and size biases.

### 11. Boulders, outcrops and underground bodies

Treat loose stones, large rocks, boulders and exposed deposits as related resource forms. Their visuals, collision, interaction and rewards must agree. A large visible boulder must not behave like an unrelated tiny pickup.

Rock obstructions should contribute to the difficult upper-river landscape. However, generated obstructions must not seal every viable route to the first required copper or tin supply.

Exposed ore and coal must connect to extractable material where players are invited to follow them. Repeated isolated node placement must not create a visual promise of a continuous vein that ends immediately without explanation.

The exact terrain representation—voxel materials, resource objects, deposit volumes or a compatible combination—is Claude's implementation choice. Integrate with the existing excavation and tool systems. If the current system cannot support following a seam or revealing a pocket, identify that gap and the necessary implementation stage explicitly.

### 12. Valuable pockets and reveal behaviour

Define a configurable association table for supported minerals, crystals, gems and precious metals. Each association should identify eligible primary deposits or host rocks, rarity, pocket form and extraction requirements.

Place discoveries deterministically when the relevant world area or deposit is generated, before extraction reveals them. They may remain unloaded until needed; their identity and position must not change because the player approaches from another direction or reloads.

Excavation reveals the associated material at its actual location. Different deposits can have different possibilities, and many deposits should contain no valuable pocket. Do not use a universal loot table that makes every mined material yield every precious resource.

Use the existing resource catalogue where possible. Exact gem species, mineral associations, pocket frequency and yields are implementation and balancing details to resolve; this handoff does not invent new crafting uses or promise every valuable type on every island.

### 13. Progression and accessibility validation

Validate the starting island as a playable resource landscape, using the current tools, yields, recipes and movement constraints.

| Requirement | Acceptance condition |
| --- | --- |
| Initial copper | Obtainable using the gathering or tools available before copper equipment |
| First useful tin | Reachable on the starting island before ships and the hardest mountain traversal |
| Bronze progression | Accessible copper and tin quantities cover the intended first bronze equipment and required construction costs |
| Iron discovery | Iron is visibly present before iron processing becomes available |
| Iron processing | The resource layout works with the kiln/charcoal or coal route and improved bellows-equipped smelting progression |
| Tool access | Essential early supplies do not require tools made from the resource they unlock |
| Surface discovery | Essential early sources have usable visible finds, exposures or connected clues |
| Inland reward | Going farther inland produces larger and more productive extraction opportunities alongside greater traversal difficulty |

Check actual routes, not only straight-line distances or total ore counts. Use existing danger information where available to avoid placing all early tin behind encounters beyond that stage. Do not create new enemy or hazard systems as part of resource generation.

If an island fails, deterministically adjust suitable local areas or deposits while retaining the intended terrain pattern. Do not repair it by scattering arbitrary ore everywhere. Travel-time targets and minimum quantities must be established from the actual game; the earlier 80%/60% examples cannot serve as substitutes.

Preserve current recipes and equipment rules. If their dependencies conflict with the intended sequence, report the conflict for resolution rather than silently changing crafting or smelting. Charcoal remains a dependable intended fuel route; this architecture does not require players to discover coal before progressing when charcoal is available.

### 14. Generation, saves and performance

- Derive stable placement from the world seed and world-space location. Region loading order must not change deposits or discoveries.
- Keep resource fields, veins and seams continuous across generation boundaries. Give shared deposits stable identities so they are not duplicated.
- Match rocks and deposits to terrain: no floating boulders, detached seams or inaccessible interaction points caused by placement errors.
- Preserve collected objects, excavation, revealed pockets and remaining resources through normal saves, reloads and streaming.
- A resource body has a bounded recoverable amount. Replenishment or world reset follows existing project policy; this handoff does not establish a new respawn policy.
- Generate and load resources within the existing terrain and streaming budgets. Broad resource fields should not require every visible object across the whole island to be instantiated at once.
- Assess compatibility with existing saved worlds before changing generation. Explain migration or regeneration needs; do not reset player worlds implicitly.

### 15. Diagnostics and review evidence

Provide development views or equivalent diagnostics showing availability fields, actual deposits, coal districts, source-linked surface finds and early-resource access. Keep these out of normal player presentation unless the existing game already exposes them.

Review representative islands and adverse seeds. Check the coast-to-headwaters visual progression, the first copper and tin journeys, obtainable yields with stage-appropriate tools, river clues, seam continuity and a revealed valuable pocket. Verify stable results across region boundaries and reloads.

The document is ready for implementation planning when Claude can show how each responsibility maps onto existing systems, identify missing capabilities and propose a bounded sequence. It is ready for gameplay acceptance when the generated world satisfies the experience and checks above.

### 16. Scope and implementation order

Implement the resource landscape described here: availability, source deposits, surface forms, coal placement, associated discoveries and the validation and persistence needed for those features.

A practical dependency order is:

1. Inspect existing terrain, resource placement, interactions, excavation and progression dependencies.
2. Establish island and river context plus the overlapping resource fields.
3. Connect deposits and surface forms, including coal exposures and early-resource validation.
4. Connect extractable bodies and associated discoveries to excavation and persistence.
5. Tune and verify the complete player journey across representative seeds.

Claude may revise this order to fit the codebase, but should distinguish complete behaviour from temporary stages. Do not expand this handoff into unrelated gameplay systems or alter official design decisions to make implementation easier.

### 17. Parameters Claude must resolve

The architecture fixes the relationships and required outcomes. It leaves numerical tuning and code design to Claude, including:

- Field extents and edge variation; resource and ordinary-rock densities.
- Size and roundness distributions along rivers and across terrain.
- Source-to-surface scatter distances and downstream transport limits.
- Deposit dimensions, extraction quantities and surface exposure rates.
- Existing tool compatibility for each resource form.
- Precious-resource associations, rarity and pocket quantities.
- Reachability thresholds and practical first-resource travel targets.
- Compatibility with current world generation, saves and streaming budgets.

Do not interpret these unspecified values as permission to weaken tin accessibility, eliminate overlap, remove visible discovery or distribute all materials uniformly.

## Research background

Gameplay takes priority over exact geological simulation. These references explain the natural patterns behind the architecture; they are not additional implementation requirements.

- [USGS — Alluvial placer tin model](https://pubs.usgs.gov/bul/b1693/html/bull3pke.htm): stream concentrations and coarser cassiterite near its source.
- [USGS — Tin](https://pubs.usgs.gov/publication/pp1802S): granite-associated tin systems.
- [USGS — Porphyry copper deposit model](https://pubs.usgs.gov/sir/2010/5070/b/pdf/SIR10-5070B.pdf): mineralized bodies, veins and weathered copper minerals.
- [Geoscience Australia — Iron](https://www.ga.gov.au/education/minerals-energy/australian-mineral-facts/iron): widespread iron minerals and concentrated ore deposits.
- [Geoscience Australia — Coal](https://www.ga.gov.au/education/minerals-energy/australian-energy-facts/coal): sedimentary coal seams and basin formation.
- [Historic England — Pre-industrial ironworks](https://historicengland.org.uk/images-books/publications/iha-preindustrial-ironworks/heag221-pre-industrial-ironworks/): charcoal-fired bloomeries and bellows.
- [Vintage Story — Mining](https://wiki.vintagestory.at/Mining): visible clues connected to deposits.
- [Factorio — Friday Facts 258](https://factorio.com/blog/post/fff-258): dependable starting resources within a variable generated world.
