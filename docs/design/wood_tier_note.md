# Dynasty — Wood and Building-Tier Design

**Current owner-approved building and wood rules (13 November 2026).** Replaces the earlier running discussion and rejected Stone/Brick Forge, Brick-Forge-with-Anvil and incomplete building-tier ideas. Old discussion text remains available in Git history but is no longer an active instruction. See [master items §§2.3 and 3.0](DYNASTY_MASTER_ITEMS.md), [progression](progression.md) and [goal recovery](PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md).

## Materials and processing

- Trees provide species-appropriate real logs, branches, leaves and other resource drops. A **full-size Log is 3 m**, and only a tree large enough for one yields that item; small trees may yield firewood and kindling instead. Harvesting resource drops must use actual gameplay actions.
- Logs serve **Rustic log construction**, chopping into Blocks/Firewood, and production at the hand saw or Sawmill. A Chop/Firewood workstation may be convenient but is not mandatory to chop by hand where that action works.
- **Iron/Steel Saw** or Waterwheel Sawmill converts one suitable softwood/basic Log into **6 Planks**, or one hardwood Log into **4 Hardwood Boards**. **No substitutions** between these item types. Retire redundant species-specific lumber/beam rows, keep species logs, and preserve approved dimensions (**Plank 6 in wide ×4 in thick, rough; Hardwood Board 6 in wide ×2 in thick, smooth**).
- The **first Iron Saw is crafted at the Improved Smithy**, after operating the Improved Smelter bellows to make Iron Ingots. All components of the Primitive Smelter, Primitive Smithy and Improved Smelter/Smithy prerequisite route must be obtainable without already having an Iron Saw, Planks or Hardwood Boards.

## Seven quality tiers for building pieces

The quality words apply to building families, **not** to workstations, tools or furniture:

| Tier | Material direction and stage |
|---|---|
| **Crude** | Sticks, stones, fibre/thatch gathered with stone tools. First shelter tier. |
| **Rustic** | True Logs/log framing and primitive joinery. |
| **Refined** | Sawn Planks or Hardwood Boards as specified by each real recipe; no substitution. |
| **Sturdy** | Cut Stone and required fittings/mortar. |
| **Superior** | Fired Brick and appropriate masonry. |
| **Engineered** | Concrete and required supports/fittings. |
| **Fortified** | Reinforced Concrete, Iron Bands and appropriate upper-tier defensive fittings. |

Each applicable tier is a coherent construction *family*: Foundation, Wall, Doorway, Window, Roof 45, Roof 65 and other actual compatible pieces (Ceiling, Floor, corner, Stair, Pillar, Fence, Gate where designed). Do not insert dead placeholder tiers with foundations but no usable enclosing walls/roof. Sturdy etc. are not alternate names for Stone or Brick Smithies.

**Roof geometry:** Crude Roof 45 and Crude Roof 65 are roof *panels without support legs*. Snap at a wall top or suitable horizontal panel edge, with the chosen attachment controlling its upward/downward direction. Test real collision, slopes and corner placement, not just color of a ghost.

**Door rules:** Doorway is a wall with an **empty real opening**. The Door is a distinct placeable/openable item, not painted geometry. Arched and straight door shapes use the same material quantities for a given grade; **Double doors cost twice** their corresponding single shape. Exact approved door recipes and all approved styles are at [master §3.0](DYNASTY_MASTER_ITEMS.md). Never create automatically embedded fake doors in the doorway wall.

## Metal/masonry dependencies

- Stone pick/Stone tools access Copper/Tin before Iron; Primitive Smelter + Primitive Smithy are stone-tool buildable, and Bronze tools/fittings precede Improved Smelter and staffed Iron processing. **No Clay Bloomery, stand-alone Stone/Brick Forge or Anvil-within-five-metres station ladder.**
- **Iron Bands**, if required by upper-tier construction, come from Iron Ingots at the appropriate actual smithy (Improved/Advanced), not an obsolete proximity-level Brick Forge. Exact ingredient counts remain governed by their approved item recipe when reconciled with live data; never invent new requirements.
- **Concrete** follows Limestone → Kiln → Lime Powder, plus Sand, Stone and actual Water from a filled container at a Mixer. Real player access to a water source/filled container must be available before presenting this construction path as complete.
- Construction material sourcing for a player uses inventory, eligible nearby storage and **nearby ground items**. This is unrelated to the specialized automatic Smelter/Smithy Coal/Charcoal pulls (30 m / 300s, no permission).
- All buildable-grade and roof descriptions require in-game verification before they are labelled playable or used as finished goal how-tos.

## Catalog and goal alignment

Do not revive older "Thatch/Wooden/Stone/Brick" tier labels for buildings. Keep the seven names consistently in Master, Blueprints, Goals, inventory/build menu, tests and future art. This document does not change code, IDs or coin rewards. The automatic full-game Goal journal must accurately teach material, tool, station and placement dependencies without imposing mandatory linear progression.
