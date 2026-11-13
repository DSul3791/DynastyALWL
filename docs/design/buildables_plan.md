# Dynasty — Building Pieces, Doors, Roofing and Infrastructure

**Current active buildables design: 13 November 2026.** Replaces older batch notes containing the wrong doorway-frame costs, integral-door geometry, 65°-roof deferral, Brick Forge manufacturing and temporary numbering assumptions. The old discussion is retained only in Git history. **This document is a target specification, not evidence of code implementation.** Approved specific item/recipe authority: [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md) §3.0 and §2.3; metalwork dependencies: [progression.md](progression.md); relevant test defects: `docs/buglists/BUGLIST-002.md`.

## 1. Quality tiers and construction families

**Seven building quality words only:** **Crude, Rustic, Refined, Sturdy, Superior, Engineered, Fortified**. These name buildings, **not** Smithy/Smelter tiers, tools or ordinary furniture. Planks and Hardwood Boards remain different non-substituting materials. There is no additional Iron or Steel doorway-tier family.

| Quality | Main character | Prerequisite material path |
|---|---|---|
| Crude | Scrounged sticks, thatch, twine and other early material | Hands, Stone Axe, basic Hammer |
| Rustic | Whole-log structural framing | Logs from sufficiently large trees |
| Refined | Sawn wooden construction | Iron Saw (from Improved Smithy), Planks / Hardwood Boards as specifically costed |
| Sturdy | Cut stone and mortar | Stone processing and suitable metal/tool access |
| Superior | Brick and masonry | Campfire/Kiln brick plus relevant processing |
| Engineered | Concrete structures | Limestone→Lime Powder, Mixer, Sand/Stone and Water from filled containers |
| Fortified | Reinforced concrete, Iron Bands and defenses | Working Iron Smithy and advanced construction |

Where a family exists, build a **usable enclosing set**, not lone foundations: Foundation, Wall, **empty Doorway**, separately installed Door, Window, Ceiling where appropriate, Roof 45 and Roof 65, plus compatible Stairs, Pillars, Roof corners, Fences/Gates and defensive pieces. The ground-storey foundation is already the ground floor; a ceiling can serve as the upper storey's floor. Crude/thatched buildings remain one storey and need no Crude Ceiling.

All true construction pieces use the established building hammer and placement validation, **not** a second craft-and-install workstation. Manufactured components may still need their correct workstation. Use the actual blueprint IDs/states from current `data/items/blueprints.json` and `structures.json`, never temporary reservation numbers from an earlier planning batch.

## 2. Doorways versus doors — approved separate objects

**A doorway is a complete wall with an empty functional opening, not an image of a closed door.** Door items are fabricated and placed separately. Straight and arched doorways are alternate frame shapes; each grade's arched frame uses the same material amounts as its straight frame. **Double frames cost exactly twice** the corresponding single frame. Doors likewise follow their approved material counts, with **double doors double** and arched doors the same as corresponding non-arched. The final door item recipes remain in master §3.0 — do not invent separate variants here.

**Every empty doorway frame costs the same as one wall of its tier**, and double = twice the wall:

| Wall quality | Single straight or arched empty frame | Double straight or arched empty frame |
|---|---|---|
| **Crude** | 3 Twine, 20 Thatch, 6 Stick | 6 Twine, 40 Thatch, 12 Stick |
| **Rustic** | 6 Logs, 2 Twine | 12 Logs, 4 Twine |
| **Refined** | 4 Planks, 1 Twine | 8 Planks, 2 Twine |
| **Sturdy** | 12 Cut Stone Blocks, 4 Mortar | 24 Cut Stone Blocks, 8 Mortar |
| **Superior** | 16 Brick, 4 Mortar | 32 Brick, 8 Mortar |
| **Engineered** | 11 Concrete | 22 Concrete |
| **Fortified** | 13 Concrete, 4 Iron Band | 26 Concrete, 8 Iron Band |

No separate Iron/Steel Doorway grade. Existing retired Iron/Steel doorway IDs must not be reused; for explicitly supported old saves use the reviewed mapping **Iron Doorway→Refined empty doorway**, **Steel Doorway→Fortified empty doorway** without losing other placed contents. The practical placement must snap a real door object into a real frame; reject blocked walls and missing actual openings.

## 3. Roof slopes and attachment (creator rule)

Each roof panel is a **simple roof surface with NO support legs**. The player can build at least the **Crude Roof 45** and **Crude Roof 65** shapes; their 45°/65° pitch is real geometry, not a decorative alternative or a future-only note. Attach along a wall top or any appropriate **horizontal end/edge of a roof panel** so the panel can continue **upward or downward** from its attachment. No fictional posts under each panel, no unintended placements in ordinary valid corners, and no separate roof-slope selection popup beyond existing hammer build/rotate controls. Include corresponding wall/roof corner and collision integration as appropriate to actually form a watertight roof. Test real Godot F6 geometry and placement rather than a green preview alone.

## 4. Other buildables: retain approved useful roles

- **Fences and Gates:** meaningful terrain-following sections and actual opening gates, not duplicate door items. Honor established material tiers and the existing foundation/terrain placement conventions.
- **Workbench and Carpentry:** Wooden Workbench, Carpenter's Bench, Stone Workbench and approved Vice/Tool Rack upgrades retain their own material names and levels. **Metalworking is separate:** Primitive, Improved, Advanced Smelters; Primitive, Improved, Advanced, Master Smithies. No Stone Forge or Brick Forge manufacturing stages, no nearby free-standing Anvil required for forge level.
- **Furniture:** graded furniture follows the master catalog's Crude/Rustic/Fine/Ornate quality rules (different from seven construction tiers); Crude furniture never arbitrarily needs late metals.
- **Lighting:** standing/wall torches, lantern posts and braziers have real usable lighting/fuel, and player interaction remains normal.
- **Gardening:** tilled plots, garden furniture, planters, raised beds, compost and cold frames must correspond to actual sow/water/harvest actions. Some blueprints remain locked because the underlying gameplay is missing: **do not simply set known=true** and claim the feature works.
- **Water infrastructure:** approved types include wells, pumps, troughs, open channels, cisterns, pipes, taps and deep pumps, subject to a working actual water-network implementation. Retain the separate procedural/live water authority; pipe/channels should transfer water according to verified physical/graph rules, not magic remote inventory sources.

## 5. Water-network modeling and implementation boundary

The prior design approved a local network graph for built water structures without replacing the natural-world water simulation. Each source/output/pump is a physically placed structure. Supported behavior must include valid connections, directional flow where appropriate, storage in real tanks/cisterns, intake from a valid natural source, pump operation with an actual player/NPC/motor, and the ability to irrigate reachable plots. Actual intake rates, pressure, pump depth, resource depletion, seasonal freezing and connection rules must derive from the water-system implementation and its authority documents, not assumed numbers in this building overview.

**Current 651-goal audit finding GA-31:** 23 approved water/garden blueprint targets are still locked in current data, plus the independently future Wool Rug. Each needs a functional server/player interaction and learning/unlock path before the Journal can mark it achievable; do not unlock a dead blueprint to satisfy a test. Character water for cooking/concrete comes from appropriately filled containers, not a magic Water inventory item.

## 6. Stable IDs, source dependencies and acceptance gates

The live item, recipe, blueprint and structure files hold stable numeric IDs, and old IDs cannot be recycled. Current master §3.0 holds exact door identities and material costs. New buildable sizes/items (including the three resource-bin capacities and their Planks/Nails recipes) are designed separately; avoid duplicate Open Storage Bin IDs. Reconcile existing families to approved items rather than installing a second buildables system.

Playtest: build an early Crude shelter without Iron Saw; place Crude roofs 45/65 including corners and inverted edges; make walls with actual open doorways and add physical doors, both arched and double; build one full example of each seven-tier family where currently implemented; take down/restore construction materials without loss; verify copper/bronze-to-iron station route; test the 23 currently locked infrastructure targets after their mechanics ship; reproduce earlier unwanted "ground too steep" and falsely blocked green ghosts with coordinates. Do not claim completion from static tables or thumbnails.

**Development:** independently reviewed small feature branches into `dev`; `main` stays stable. This document makes no gameplay code or save-format change.
