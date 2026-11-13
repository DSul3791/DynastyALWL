# Dynasty — Playable progression and tutorial dependency map

**Current design: 13 November 2026; creator-approved tier capabilities, mechanics and naming. Implementation is not implied.** This is the practical progression outline for Goal instructions; exact new station blueprint costs not yet approved. Full item authority: [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md) §§2.1–2.7, 3.0, 3.3, 3.13. Detailed root-blocker work: [PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md](PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md). Do not treat this outline as a linear unlock gate: the Goals page automatically tracks all eligible goals and players may perform any working action out of order.

## Gate 1 — Hands and stone tools

Collect sticks, stone, plant fibre, twine and suitable logs; make the Wooden/Stone Hammer and Stone Axe/Pickaxe. Construct a Campfire, Crude building pieces (including separate empty doorways and independently placed doors), Thatch Bed, Lean-to and Workbench with accessible materials. Craft basic charcoal at the campfire; a Kiln is a later bulk charcoal upgrade, **not** mandatory to access first metal. A full-grown tree produces a real log while tiny trees may yield only firewood/kindling. Building/repair materials follow existing player inventory, nearby storage and nearby ground sourcing. A repair action requires an equipped ordinary hammer's **right-click → Repair** (never a War Hammer).

## Gate 2 — Campsite, leather and early production

Build working Workbench, Tanning Rack and useful shelter and cooking facilities. Harvest suitable **oak** for Tannin Bark through the approved-to-be-implemented tree extraction, and **Scots Pine** for Pine Tar through its existing trunk/drop route once repaired. Process Hide into Leather using verified real water-filled containers; do not claim a loose free-standing Water item spawns in a way unsupported by game code. Sow, water and harvest real crops using client controls wired to the server, rather than showing nonfunctional menu options. Leatherwork, weaving and preservation branches are available as their actual materials/tools arrive. These are repair dependencies, not newly invented special XP gates.

## Gate 3 — First copper and bronze

With **stone tools**, build **Primitive Smelter** (natural draft) and **Primitive Smithy** (stone anvil), without Planks, Nails, Iron or pre-existing metal equipment. Stone Pick can find Copper/Tin-bearing boulders. Primitive Smelter:
- Hopper **20 Coal/Charcoal**, input **20 material units**, **NO output inventory**; completed ingots drop safely on the ground in front.
- **20 seconds per ingot**. **1 Copper Ore → 1 Copper Ingot**, **1 Tin Ore → 1 Tin Ingot**, **1 Copper Ore + 1 Tin Ore → 2 Bronze Ingots**.
- No tracked temperature mechanic. Hopper fuel quantity and per-ingot consumption are distinct; fuel rates need tuning.
The Primitive Smithy shapes copper tools and bronze items/fittings. Use Bronze tools to reach iron-bearing deposits as the existing ore data requires. Copper tool roster and performance need actual recipes/tool definitions; do not imagine all material families must have a copper rung.

## Gate 4 — Improved stations and iron

Construct **Improved Smithy** with integrated **Bronze Anvil**, forge and bellows; it can work iron, at accelerated station wear. Use Bronze fittings for **Improved Smelter**: hopper **40**, input **40**, finished-ingot rack **80**. With no player operating the bellows it produces Copper/Tin/Bronze at the **Primitive baseline 20 s/ingot**, no iron. A player operating the bellows allows **Iron Ingots** and raises throughput by **30%** (~**15.38 s/ingot**); leaving pauses unfinished Iron work. **1 Iron Ore → 1 Iron Ingot**. Forge **Iron Saw** and **Iron Anvil** at Improved Smithy. Iron Saw cuts a suitable 3 m softwood Log into **6 Planks**, or hardwood Log into **4 Hardwood Boards**, with no material substitution. Never require those boards to build the pre-saw stations.

## Gate 5 — Advanced steel production and craftwork

Use the Iron Anvil as a component to construct **Advanced Smithy**; this smithy crafts a **Steel Anvil** later. Build **Advanced Smelter** as **ONE combined station** with windmill and two mechanically driven bellows. Hopper **80**, material input **80**, finished-ingot output **160**. When wind is strong enough, its nominal throughput is **2 ingots per ~11.83-second cycle** (each lane 30% faster than actively staffed Improved); more wind may increase throughput, but **too little wind = ZERO processing** until it returns. For Steel put **Iron Ore and a separately consumed Coal/Charcoal carbon ingredient together in the material input**, with additional Coal/Charcoal in the **fuel hopper**. Carbon:iron quantity still needs review; never copy old 2 Iron Ingots + fuel or old temperature rules.

## Gate 6 — Master Smithy and high-tier industry

Create Steel Anvil at **Advanced Smithy**, use it to build ornate **Master Smithy**, with its **integrated quencher**. Masterwork equipment supports +1/+2 physical craftsmanship, separately from enchantment effects. Tempering where suitable is a property of the specific crafted steel item, not a second catalog item or an add-on station. Smithies break into an unusable **"Needs repair"** state at zero durability while remaining placed; use an equipped ordinary hammer's right-click **Repair** with required materials carried, stored nearby or lying on the ground. War Hammers are not construction tools. Repairs do not delete station contents; actual material cost/restoration are pending balance.

## Gate 7 — Settlement, trade, storage and discovery

Use **Small/Medium/Large Resource Bins**, each holding only one type at a time, assigned by first item and freed for reassignment only when emptied. Capacities **1,000 / 5,000 / 10,000 units**; construction **16 Planks + 32 Nails / 32 + 64 / 64 + 128**. Solid sides/open top show a single vertically moving material-surface mesh. Never mix Coal and Charcoal in one bin. Smithy/Smelter hopper fuel auto-pulls available Coal/Charcoal from appropriate bins, kilns and fires within **30 m** every **300 s**, oldest consumer first, without permission checks; it never pulls wood, ground items or generic chests, and never uses the steel carbon INPUT automatically.

Production branches include Leather, Tailoring, Farming, Water, Sawmill, high-tier construction and approved storage/warehousing. Where buildables in these branches remain locked or their actions missing, the corresponding tutorial goal is **not ready** until its actual gameplay is repaired. Keep all goals automatically eligible and completion-aware, never requiring manual acceptance.

The Journal **Map** page does **not** display an existing omniscient world map. Each player discovers the world while travelling and sees a **charcoal-drawn map**, initially rough, whose accuracy grows with **Mapping skill** from exploration and drawing Map Scrolls. Revisit older explored territory to improve the drawing with new skill. Scrolls may later be shared/sold. The Journal keeps clean existing Inventory/Crafting styling, with no cluttered separate mapping screen. Full [Map design](PLAYER_CARTOGRAPHY_MAP_DESIGN.md).

## Buildings: seven material tiers, separate from smithy/smelter tiers

| Building quality | First availability / principle |
|---|---|
| Crude | First gathered resources; 45° and 65° roof panels attach to wall tops and horizontal ends, not freestanding legs. |
| Rustic | Logs and elementary carpentry; doors separate from empty frames. |
| Refined | Planks/Hardwood Boards after Iron Saw, according to actual recipes (never interchangeable). |
| Sturdy | Stonework and relevant metal fittings. |
| Superior | Brick/advanced masonry; exact door recipes in master §3.0. |
| Engineered | Concrete and iron fittings where the blueprint requires. |
| Fortified | Concrete/strong iron fittings, defensive structures. |

Do not teach one isolated foundation or a decorative fake-doorway as a functioning complete tier. Check Foundation, Wall, Doorway, Door, Window and both roof slopes as a family at each tier that actually supports them.

## Playability proof required

Use a fresh non-admin character; gather all inputs legitimately; build the exact stations in prerequisite order; operate bellows by player input; stop/restart windmill machinery; save/reload all inventories and queues; check unit conservation, Repair interactions, bin assignments and mixed storage/ground repair sourcing, roof and door placement. Validate each associated automatic goal triggers exactly once regardless of what the HUD shows. **No design document is proof of a working F6 playthrough.**
