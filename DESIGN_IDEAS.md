# Design Vision and Ideas

Record of the design brainstorming sessions from 2026-10-11 onward. This is a planning document. The world generator described in Section 14 is partly built; the game systems in Sections 5 to 13 are design only and no code exists for them yet.

**Revision history**

- **Version 1 (2026-10-11):** vision, world generation and bake, harvesting and farming, characters and heirs, NPCs and towns, soft law, building and fire.
- **Version 2 (2026-10-12):** added Satisfactory as an inspiration; production and logistics; road threats and pacing; town finances, markets, warehouses, trade routes, businesses, banking, letters of credit and forgery; crime memory, delayed discovery and disguises; inheritance of money and debt; the shared principles those systems rely on. Open questions and the work ordering were rewritten.
- **Version 3 (2026-10-12, later):** lifespan targets (start at about 15, die at about 80, in about 700 hours of play); families age with the player; the rescue-first philosophy and party composition; heirs arriving partly trained; the tension between server-owned towns and "no towns at the start"; and the clock arithmetic showing that one clock for aging and seasons is probably not workable. Open questions were updated.
- **Version 4 (2026-10-12, latest):** two clocks decided (a world calendar for seasons and crops, and an aging clock); a one-to-two-week seasonal cycle; NPC aging at the average player's speed (70 years per real year); the weekly farming rhythm and a note on avoiding calendar years of exactly 7 or 14 days; Farming Simulator as an inspiration; no starting towns; and the civil engineer town-planning idea. The lifespan pacing figure changed from 65 to 70 years (15 to 85).
- **Version 5 (2026-10-12, evening):** the "play what you like" and "no micromanagement" goals; server-clock aging for everyone as an idea; children, twins, wills and choosing an heir; 60-minute game days, seasonal day length and night; the weekend farming rhythm, crop tiers, farm labor and work buildings; stock levels, the order chain and building maintenance; the budget for language model use and self-hosting; town roles, land and property; quests and pastimes; real-money ideas, with gambling flagged for later; and the plan for growing the tile map one side at a time.
- **Version 6 (2026-10-12, night):** minimum hardware target (older quad-core, 8 GB RAM, SATA SSD); the 15 to 16 hour tile bake and a proposal to bake 2D maps and generate voxels at runtime, with a table of what is baked, what the server works out and what the client does; language service hosting and scaling; NPC backgrounds, memory, honesty and conversation traits; a tile size of 15 by 15 regions (15.36 km) and a comparison with Atlas; a world-first sketch where islands come from ocean-floor features; a danger map; an islands-first tile pipeline; geology stored as a feature list with ore placed by how deposits really form; surveying skill and prospecting clues; the surveyor's book; a massive pre-planned world, an arid equator on the origin row and three climate zones with transition rows; tile downloads and the client tile cache; a developer-built starter town (replacing "no starting towns"); natural animal behavior; rarer flotsam; several starter tiles; a full-size world filled with placeholder ocean tiles; a matrix of tile specifications; a recommendation to start with voxel streaming; a square final world (proposed 21 by 21); polar sea ice; years of travel; the admin town warehouse; the town founding sequence from town block to planner, builders, roads and buildings; admin warehouse access, NPC production limits and worthless starter items; the 21 by 21 world confirmed; eight temperate starter tiles in an inner and an outer set; cool desert dugouts; and a pointer to the draft world format specification.
- **Version 7 (2026-10-14):** the generator work through climate, geology and ore, and natural caves (steps 10 to 12); the resource list (gems, marble, chalk, flint, alum, bitumen, graphite, bog iron, saltpeter) and the rule that every resource needs a use; renewable, semi-renewable and non-renewable resources; mine stability; quality tiers; reputation as personal and per viewer; admin town buying; duress, receivership and takeover; notifications; the free-to-play model; children, dynasty transfer, adoption and inclusion; the temple; town spirit and local weather; town decline, rubble and abandoned towns; contesting town claims; managers, remote control and in-world mail; the ultimate island; remains of the dead; resource passes and edge matching.

## How to read this document

Every item carries a status tag.

- **[Decided]** Stated or clearly agreed to by the project owner.
- **[Idea]** Raised by the project owner as a direction or wish ("we could...", "maybe...", "it would be nice to eventually..."), not yet firmly settled.
- **[Proposed]** Suggested by Claude during brainstorming. It was accepted in passing or not objected to, but never explicitly confirmed.
- **[Open]** A question that has not been answered yet. Section 15 collects them.
- **[Superseded]** Replaced by a later decision. Kept briefly for reference. When two statements disagree, the newest one from the project owner is the right one.

When something is both a decision and a question, the decision is recorded in its section and the unresolved part appears in Section 15.

---

## 1. Vision

A persistent, rough-medieval, multiplayer online world: a survival, exploration and town-building game with a "Sims vibe".

**Inspirations**

| Game | What it contributes |
|---|---|
| Valheim | Simple, stylized graphics. Terraforming, leveling land, building up walls. Realistic building fires. |
| ARK: Survival Evolved | Exploring a huge-feeling island with many climates. Fantasy (Dungeons and Dragons style) flora and fauna. The unconscious-before-death state. |
| Atlas | Building ships and sailing between islands. |
| Space Engineers and Minecraft | Digging and mining. Stumbling into natural caves, abandoned mineshafts and labyrinths. Sharing blueprints through Steam downloads. |
| Medieval Dynasty | Founding villages, villagers with jobs, seasons, marriage, children and heirs. Farming huts and barns with worker slots, field preparation and crop rotation schedules. |
| Aska | Work buildings that villagers staff and run on schedules. |
| Satisfactory | Building components and tools from materials to help mine and climb. Railways, machinery and automated movement of materials out of mines and on to town. |
| Farming Simulator (22 and the franchise) | Fields with rotating crops, and a relaxed farming loop where a player can log in once a week to harvest and plant. |
| Warcraft-style strategy games | A town planner proposes buildings and roads, the player approves, and builders carry them out. |

**Core goals**

- **[Decided]** The client stays light enough for older computers to play comfortably.
- **[Decided]** Most of the workload happens on the developer's machines at bake time. The server carries some of the load.
- **[Decided]** The world can grow over time without breaking what already exists.
- **[Decided]** Players are encouraged to build ships and sail, because islands are separated by real ocean.
- **[Decided]** The world should feel alive: carts, wagons and NPCs moving through it.
- **[Decided]** Eventually the world is massive, larger than most games available, and it feels alive mainly because of AI-driven NPCs.
- **[Decided]** The game is designed to keep players alive even though the whole world is trying to kill them. Layers of rescue (party mates, helpful NPCs) catch a fallen character before they die (Section 6.5).
- **[Decided] Play what you like.** Players should never have to switch games to change style. Farmer, miner, trader, town manager, hunter or trapper selling to the butcher and furrier, caravan sword for hire, adventurer, someone who plays board games or roleplays conversations in the pub, or someone who wanders the rivers and fields enjoying nature. Each style needs a complete loop of its own.
- **[Decided] No micromanagement.** Every avenue can be done by hand for fun, or handed off to NPCs, whether family or hirelings. Doing it yourself pays more. Delegating costs a cut but keeps things running.

---

## 2. Terminology

- **Region:** one 1,024 m by 1,024 m storage file holding all 7 LODs. It is the natural unit to stream from server to client.
- **Town block (town marker):** the marker a player places to claim a town. It has no physical form: it is a floating arrow only the owner can see, which the owner can switch on and off, and it creates an entry in the owner's ledger saying they own a claim. It is the centre of the town and the centre of its circle of influence. Town settings are reached through the town's office building, not through the marker (Section 8.17). An **outpost marker** works the same way for an outpost.
- **Island tile:** a block of 15 by 15 regions, 15,360 m (about 15.36 km) on a side. Each tile is baked on its own and addressed by a permanent integer coordinate. (It was 10 by 10 regions and 10.24 km until 2026-10-12. The old generator still builds 10 by 10 tiles until it is retired.)
- The project owner sometimes says "chunk". Depending on context that means a region or an island tile.
- **[Decided]** Sizes are multiples of 1,024 because voxel data aligns best that way.
- **Baked** data is produced once by the generator and never changes. **Server layer** data is what players and NPCs change while the game runs.

---

## 3. Guiding principles

- **[Decided] Soft limits with real consequences.** The world rarely says "no." It lets the player try and then responds. Examples: depth heat instead of a hard floor, tool strength, soft law instead of permission locks, and offline risk instead of invulnerability.
- **[Proposed] Baked immutable base plus a server-owned living layer.** The baked world never changes. Everything players and NPCs change lives in a separate server-owned layer. This matches the existing code, where the base world is marked immutable.
- **[Proposed] Lazy resolution.** Store "this happened at time T" and work out the result when someone looks, instead of simulating constantly. Used for crop growth, plant regrowth, aging, NPC memory decay, ruin decay, offline events, production, tax settlement and loan payments.
- **[Proposed] Data-driven tables.** Materials, tools, rocks, traits, plants, machine recipes and workplace types each have a table of numbers that all systems read, so balance changes are edits to data and not code.
- **[Proposed] The game owns the facts; the language model only speaks.** Money, items, relationships and crimes are structured data. The model voices NPCs but cannot invent facts, and its output must pass game rules before changing anything.
- **[Proposed] Server authority with simulation level of detail.** Simulate in detail near players and coarsely elsewhere, like terrain LOD.
- **[Proposed] Materialize from schedules.** Wagons, miners, patrols and similar moving things are data on the world clock. They are created physically only where someone can see them, with simplified versions at medium range and nothing drawn beyond sight. NPC identity, traits, memories and relationships exist all the time. Only their step-by-step movement is skipped when unseen.
- **[Proposed] Same odds seen or unseen.** An event resolved by numbers when nobody is near (an ambush, a fire, a raid) uses the same odds as the version played out in front of a player.
- **[Proposed] One shared business structure** for every workplace (Section 13.4), and **one obligations list** for debts, taxes, wages and tolls (Section 6.4).
- **[Proposed] Provenance and identity.** Crafted items and animals are individual, with a maker's mark or brand and an ownership history. Bulk goods such as ore and grain are counted in totals, or in batches with a source tag where theft matters.
- **[Proposed] News travels with people.** Warrants, reputation, threat warnings and price news are facts with a place and time of origin that spread slowly through travelers, wagons and ships (Section 13.6).
- **[Proposed] Legibility.** Hidden rules feel unfair. Show the ledger, risk overlays, estimated effects and the reason an action is blocked or risky.
- **[Proposed] Money is stored as whole numbers of the smallest coin,** never decimals, so balances never drift.
- **[Decided] Safe, kind, generous, in that order.** (2026-10-14) The game is built on the idea that people should be safe, then kind, then generous. If you cannot be generous, be safe and kind. If you cannot be kind, at least be safe. If you cannot manage all three, remove yourself from the situation. Systems for safety (protection from abuse, ways to leave a bad situation), kindness (rescue, understanding, second chances) and generosity (gifts, charity, adoption, helping struggling dynasties) are treated as core design, not extras.
- **[Decided] We do not dictate relationships.** (2026-10-14) A spouse can be any gender, and the game supports couples of any kind. Where a couple cannot have children, the game offers adoption and other routes (Section 6.9). The goal is to be understanding and inclusive.
- **[Decided] Every resource needs a use.** (2026-10-14) A resource, rock or material is added only when we can say what it will be used for in the game. Nothing is added just because it exists in the real world.
- **[Decided] Build the generator first, with the whole design in mind.** The immediate work is the generator that produces the giant adventuring world, but every system in this document should be considered while it is built, so nothing baked now blocks something wanted later.
- **[Decided] Language model budget.** Rules drive routine NPC work (a smith making nails, a farmhand harvesting, builders repairing). The model handles conversation with players and occasional judgment calls, such as a warehouse manager reviewing stock about once per game season. Its output is bounded and structured, game rules validate it, and a simple formula or rule takes over when no model is available. Each decision is logged with its reason.
- **[Proposed] Reward checking in, never punish a weekly rhythm.** Frequent visits earn more, but a player who logs in once a week still gets a complete, productive loop.
- **[Proposed] Management rights are hard locks; physical actions stay soft.** Nobody can open a town panel without the right role, but anyone can physically steal, with consequences.
- **[Decided] Older machines must be able to play.** The client has to run on an older quad-core such as an Intel i5-4690 (4 cores, 4 threads) or older, ideally with 8 GB of RAM and a SATA SSD. Nobody should be excluded because of an older machine.
- **[Proposed] Design to the minimum machine from the start.** With 8 GB of RAM the game has perhaps 3 to 4 GB once the operating system takes its share, and four cores shared by the game loop, voxel meshing and networking. Meshing is likely the largest client cost, so view distance, active LODs and mesh style are the main knobs. Flora, grass and buildings get count caps and quality settings (low, medium, high). The client never runs heavy generation or language model work. A target frame rate on the minimum machine (Section 15) gives every system a budget to design against.

---

## 4. World generation and bake

### 4.1 Tiles and islands

- **[Decided]** One island should feel as big as the original ARK island: many climates and hours of travel. An official ARK size figure was not confirmed, but from the preview image the current tile holds an island of very roughly 60 to 70 square kilometers, so area alone is likely already comparable. The feeling of size must come from varied, winding terrain and travel time.
- **[Decided]** A generator **island properties panel** controls, per tile: how many islands, how big each is, and where each is placed in the tile.
- **[Decided]** Tiles are baked and added to the map one at a time over the life of the project.
- **[Decided]** Island size and the distance between islands should be varied across the world, from small islets up to ARK-scale.
- **[Decided]** Tile size is 15 by 15 regions, 15,360 m: the multiple of the 1,024 m region size nearest to 15 km. Every LOD stays aligned, 8 m map samples divide it exactly (1,920 intervals), and the next candidates were 14 regions (14.3 km) and 16 regions (16.4 km, a power of two).
- **[Decided]** Tiles can hold several similar small or medium islands, or a large or great island with a random chance of a few islets or small islands just off it (`WORLD_FORMAT_SPEC.md`, Section 6).
- **[Decided]** Sailing should feel adventurous and epic, as in Atlas. For scale: the project owner recalls the whole ARK map, ocean included, at about 48 km². Atlas is 15 by 15 grids (225 cells, wrapping at the edges, per its wiki), and its developer says crossing the whole map takes about 30 hours nonstop. Atlas does not publish a grid size. One player estimated about 212 km across the whole map (about 14 km per grid). That estimate is unverified, but it fits Atlas's own grid editor warning against grids over 1,400,000 Unreal units (14 km). One tile here is about 236 km², so the 21 by 21 world (about 322 km across) is about 1.5 times Atlas's length on a side.
- **[Idea]** Once tiles generate in reasonable time, the whole massive world can be planned ahead of time, tile by tile.
- **[Proposed]** A **world plan** file lists every planned tile (islands, sizes, character) at its permanent coordinate. Tiles can all be baked up front and still be released gradually by growing the active rectangle (Section 4.7). Open-ocean tiles are nearly free to store and help a huge world feel huge without needing content everywhere.
- **[Open]** How large a world can be designed and still managed and served (Section 15).
- **[Idea]** Generate the entire map at once, filling every unassigned tile with an ocean tile for now, and generate replacement tiles at predetermined coordinates later.
- **[Idea]** Before baking, build a **matrix of tile specifications**. A randomized generator picks between zero and 4 or 5 islands per tile and sizes them, giving a mix of big islands, smaller clusters and archipelagos.
- **[Proposed]** With 2D tile maps, ocean tiles cost almost nothing, so the world can be its full planned size from day one. The wrap bounds then never change, and growing the world becomes replacing placeholder tiles instead of adding rows and columns (Section 4.7 still applies if the world ever needs to grow beyond the plan).
- **[Proposed]** Replacing a placeholder needs rules: only tiles marked as placeholders can be replaced; anything players left there (anchored ships, floating items, seabed edits) is moved or the new islands avoid it; and the tile's revision number rises so clients refresh their cached copy.
- **[Proposed]** The matrix is a file you can read and edit. Each cell holds the tile's kind (ocean, starter, islands), island count, sizes, characters and seeds. Rules shape the random picks: a size mix, minimum sailing distances, starter tiles hand-tuned to be town friendly (flat land, a river, a harbor, varied resources nearby), and each climate zone getting a fair share of key resources. A whole-world preview image shows the result before anything is baked.
- **[Decided]** 21 by 21, provided it gives a world that takes years to traverse.
- **[Proposed]** Use an odd number so the desert row sits exactly in the middle and the north and south edges have matching climates where they wrap. **21 by 21** is the suggestion: 441 tiles, about 322 km on a side, about 104,000 km² (most of it ocean; the first plan puts about 6% of it as land). Rows and columns run from -10 to 10. 19 by 19 is the smaller alternative.

| Rows (21 tall) | Zone |
|---|---|
| -1 to 1 | Desert (3 rows) |
| ±2 | Transition |
| ±3 to ±6 | Temperate (4 rows each side) |
| ±7 | Transition |
| ±8 to ±10 | Arctic (3 rows each side, 6 rows meeting across the wrap seam) |

- **[Decided]** Starter tiles sit in the middle of the temperate zone, so new players do not suffer extreme climates.
- **[Decided]** Starter islands in the northern hemisphere have rocky, steep north shores and long sandy beaches along the south shore. Islands in the southern hemisphere are the opposite. Town areas sit on nice, flattish ground near the beaches, or on a river, with a large port.
- **[Proposed]** Implemented in the world sketch: each starter island's poleward side gets sea cliffs and a narrow, fast-dropping shore; its equator-facing side gets wide sandy shallows, a long gentle coastal plain (rising about 28 m over half the way inland) and a sheltered bay with a narrow mouth for the port, ringed by flat harbor ground. Every starter tile now has at least 2 km² of flat town ground (checked by a test). Rivers come with the detailed tile maps; the tile bake should prefer to run a river into each starter bay, so the port also sits at a river mouth.
- **[Decided]** Starters sit on a **large landmass**, not a small separate island. Most players spend their first few weeks adventuring and questing there, so it must hold the starter town, farmland, wilderness, quest sites and room for several player towns.
- **[Proposed]** Every starter landmass gets a guaranteed minimum size so no starter is short-changed. The tile plan currently gives very uneven results (inner starters 39 to 90 km² for their largest island, outer 31 to 240 km²). Land will be densely covered with flora, fauna, trees and rocks to gather; for scale, the ARK island (about 6 by 6 km) took weeks to explore. Proposed targets: inner starter landmass 50 to 100 km² (one and a half to three ARK islands), outer 70 to 150 km² (outer starters are more dangerous and reward it with more land). Nearby satellite islands across a strait are welcome on top of that, and smaller neighbors may join by a narrow land bridge (owner, 2026-10-13).
- **[Proposed]** Implemented (2026-10-13): the starter island itself is drawn at the target size (inner 64 to 78 km², outer 86 to 104 km² before coastline roughness), and a 1.2 km strait at least 80 m deep is cleared around it so shelf hills stay separate satellites instead of merging into one huge landmass. Current sizes: inner 54, 81, 89, 96 km²; outer 72, 81, 138, 148 km². A test keeps every starter in range.
- **[Decided]** Like Atlas, there are several starter towns, since the map is so big, so people can coordinate with friends when they first log in. Inner set at (-3,4), (3,4), (-3,-4), (3,-4); outer set at (-6,6), (6,6), (-6,-6), (6,-6). (The outer set was first proposed at columns ±8, row ±5, and moved inward so it sits in the medium danger zone, Section 4.13.) Each outer starter is about 3.6 tiles (55 km) from the nearest inner starter, and 4.5 tiles (69 km) from the deadly east-west edge. Row 6 is the last temperate row, so the outer starters are a little cooler. The desert center is left for players to expand into.
- **[Proposed]** Open the inner set at launch and the outer set as the population grows. With placeholder ocean tiles, starter tiles can be baked first.
- **[Proposed]** Traversal: crossing 322 km is tens of hours on foot and, at Atlas's roughly 7 km/h (derived from its 30 hours for about 212 km), about 46 hours of sailing. Ship speeds are not yet set. "Years" comes from exploring: a few hundred island tiles of up to ARK scale, at many hours each, is thousands of hours, several years for a player at 12 to 16 hours a week.
- **[Proposed]** A tile with zero islands is simply an open-ocean tile. This gives ships real distances without any special system.
- **[Proposed]** Irregular coastlines with small offshore islets, instead of the current rounded-square outline.

Constraints inherited from the current generator:

- Every tile edge converges to the same deep-ocean floor so independently baked neighbors match. Islands therefore keep a margin from the tile edge and can never cross a tile border. The largest island is about one tile.
- Two islands in neighboring tiles can never be closer than the sum of their edge margins, so a regular grid of ocean lanes can appear if every tile holds a similar big island. Mixed sizes and positions hide it.

### 4.2 Climate

- **[Decided]** Climate is driven by distance north or south from the origin tile. The origin is the equator (hottest). Climate cools gradually toward the poles.
- **[Decided]** The 500 km arctic line mentioned in discussion was only an example. The real scale is undecided.
- **[Decided]** Tile (0,0) and its whole east-west row are the most arid, desert zone.
- **[Idea]** Three zones (desert, temperate, arctic), with a transition row between zones where one zone gradually changes into the next as you travel north or south. The world's height in tiles decides how wide each zone is.
- **[Proposed]** Because the world wraps north to south, the zones run symmetrically from the desert row: desert, transition, temperate, transition, arctic at both the north and south edges, where the wrap seam joins arctic to arctic. The final 21-row world is laid out in the table in Section 4.1.
- **[Idea]** At the north and south poles there should be sea ice, with the ocean frozen like Earth's poles.
- **[Proposed]** Because the world wraps north to south, both poles are the same place: the wrap seam. Permanent pack ice covers the outermost arctic rows, and seasonal ice grows outward in winter and retreats in summer, worked out at runtime from latitude and the season so nothing seasonal is baked. Ice thickness decides whether ships can pass and whether people can walk or sled across. Broken ice refreezes over time.
- **[Proposed]** Sea ice makes crossing the pole a seasonal event: a summer sailing passage, or a winter sled route, or an icebreaker later. It also supports the cold-climate life already planned (seal hunting, ice fishing, polar creatures). Arctic islands carry glaciers and snowfields baked as surface materials.
- **[Proposed]** Temperature is a smooth function of the tile row, so transitions happen naturally and there are no seams. Altitude still cools mountains, and moisture can vary per island so not every desert-row island is sand.
- **[Proposed]** The climate function must be fixed in absolute tile rows for the planned **final** world height before the first tile is kept. If it were scaled to the current world size, growing the world would change the climate of tiles already baked. Growing north and south alternately keeps the wrap seam joining matching climates.
- **[Decided]** Climate strongly affects soil type, flora and fauna.
- **[Proposed]** Climate varies smoothly across a tile, so there are no seams at tile borders.
- **[Proposed]** Altitude lowers temperature too, so tall equatorial mountains can have snowcaps.
- **[Proposed]** Bake the average climate. Apply seasons at runtime (shader and rule changes), so one baked world can have winter and summer. Seasonal swing could grow with distance from the equator.
- **[Decided]** Seasons exist. Characters experience spring, summer, autumn and winter (Section 7.3).
- **[Idea]** Weather affects how things grow and what work can be done. Soil that is too dry or too wet cannot be worked.
- **[Idea]** Regions specialize naturally. Too far north and the soil is too cold for some crops. Too close to the equator and it is too dry. Hot regions suit camels and desert plants. Temperate regions suit horses, sheep, pigs and cows. In the extreme cold, people survive by fishing, hunting seals and other creatures, and mining.
- **[Proposed]** Weather is calculated from the world seed and the server clock, so every client works it out itself with no network traffic, and everyone sees the same rain.

Note: climate depends only on position, so each tile can compute it without looking at neighbors, which matches how tiles already work. Anything baked into a tile (surface materials) is permanent, so the climate curve should be settled before many tiles are baked.

### 4.3 Soil, flora and fauna

- **[Decided]** Soil and surface materials are baked.
- **[Decided]** Trees and other plants are **objects, not voxels**.
- **[Decided]** Flora placement is worked out at runtime from the biome map and a per-tile placement seed, replacing the earlier plan of baked placement lists. Only removals are stored. The map grid is 8 m.
- **[Decided]** Grass is never stored or synced. The client draws it near the player only, driven by ground type and a quality setting.
- **[Decided]** Fauna is server-controlled spawning, based on climate, biome and terrain. It is never baked.
- **[Decided]** Animals run on simple, classic programmed AI (not the language model), improved gradually over time with AI help. Behavior must not be ridiculously predictable or unnatural: a deer jumps and runs away when spooked, and a troll does not stomp around turning its back on you because it needs to walk around a tree.
- **[Proposed]** Animal behavior built from perception (sight cones, hearing, smell carried by the wind), a short list of weighted needs (graze, flee, hunt, guard, rest), and steering. Steering lets a creature move around obstacles while still facing its target, so a predator sidesteps a tree instead of turning away. Herds react together and some individuals startle first. A little randomness in timing keeps it unpredictable. All of this runs on the server with simulation level of detail; the client only animates and smooths movement.
- **[Decided]** Fantasy (Dungeons and Dragons style) species.
- **[Proposed]** A removed tree is recorded as "item N in region R is gone." Because each tile freezes its generator version, placement never shifts under existing removals.
- **[Proposed]** Climate and soil should also be queryable at runtime from the same function the generator uses, so the server and generator never disagree. This matters for farming.
- **[Proposed]** Slate as a new rock type (shale metamorphoses into slate), tied to folded or deformed regions. Slate would make some islands valuable for roofing.

### 4.4 Natural structures and lair sites

- **[Decided]** Caves, abandoned mineshafts, labyrinths and similar discoveries, as in Minecraft.
- **[Decided]** (2026-10-13) The world generator places natural caves now (step 12). Abandoned mineshafts and labyrinths come later as add-ons.
- **[Proposed]** Underground structures are baked as real voxels, since players can dig into and through them. They become destinations for NPC quests and bandit camps. If the layering in Section 4.8 is adopted, only each structure's site (position, type, seed) is baked, and the server carves the voxels from it with the same deterministic generator as the rest of the terrain.
- **[Decided]** Towns are **not** baked. Players found towns (Section 8).
- **[Decided]** Eventually a threats system will pinpoint areas that make natural bandit camp places. Premade goblin camps can also be dropped in like a blueprint, creating a small cave system filled with goblins (Section 12).
- **[Proposed]** At bake time the generator scores natural hiding spots (caves, ruins, ridgelines, forest edges: defensible and out of sight) and places **dormant lair sites**: empty caves and camps that nobody lives in yet. At runtime the server only changes a site's state ("site 14 is held by a goblin horde"). That needs no terrain editing and no client download.
- **[Idea]** People in extreme cold may build underground bases and grow things that need no light, such as mushrooms.
- **[Proposed]** Cave generation should include some large, usable caverns and not only narrow tunnels, so underground bases and farms are possible.
- **[Decided]** (2026-10-13) Caves come with inherent danger. They house creatures such as bears, snakes and bats. On starter islands these are low level, but still dangerous for a new player with no skills or gear; danger rises with the region's danger level (Section 4.13).
- **[Decided]** Caves have natural hazards: steep slopes, thin natural rock bridges over drops, and tight squeezes just big enough to get through that slow the player down, sometimes with a cliff or other danger waiting on the far side.
- **[Decided]** Cave delving pays off: large amounts of limestone to mine, and ore deposits exposed in cave walls.
- **[Proposed]** How the generator supports this: each cave system is stored as a skeleton of passages (points with a width and height) whose segments are tagged (passage, chamber, squeeze, rock bridge, ledge, pit or shaft, water), plus entrances and creature dens. Dens carry a creature tier from the regional danger and the cave depth, and the server fills them at runtime. Passages are routed to pass through nearby ore bodies so ore shows in the walls, and limestone caves are cut in limestone, so the rock itself is the reward. Suggested density on a starter tile: 10 to 20 cave systems plus a few small rock shelters.

### 4.5 Depth, heat and altitude

- **[Decided]** No hard floor for players. The limit is soft and realistic.
- **[Decided]** Depth is measured from **sea level**, so one fixed number applies everywhere. Mountain interiors are therefore the best places to mine.
- **[Decided]** Around 3 km below sea level it becomes too hot to survive. Heat does not kill instantly. Stamina drains first, the player can no longer dig deeper, and health drops slowly while they stay.
- **[Decided]** Better skills, ventilation, cooling and magic push the practical limit deeper, but no protection removes the wall entirely.
- **[Decided]** At altitude, cold and thin air drain stamina in the same way.
- **[Decided]** Items dropped at deep or dangerous places can be retrieved later by better-equipped characters.
- **[Proposed]** Keep the world bottom at -4,000 m and treat the lethal depth as an adjustable number. The lethal level is a runtime value (cheap to change). The world bottom is baked into every file (expensive to change). The extra kilometer acts as a buffer and can be baked cheaply as plain solid rock.
- **[Proposed]** One shared "environmental resistance" idea for heat, cold and thin air, modified by gear, skill, cooling stations and magic.
- **[Proposed]** Ventilation as a range effect (a station reduces heat within a distance), not a true airflow simulation.
- **[Idea]** Volcanic areas run hotter at shallower depth.
- **[Decided]** In the desert, people can dig down to make a cooler living area, as long as they do not dig so deep it starts getting hot again.
- **[Proposed]** Follow real ground behavior: daily swings vanish within a few meters, and from about 10 to 15 m down the ground sits near the surface's year-round average, then warms with depth. A desert dugout is cooler than the day and warmer than the cold desert night. Real examples are Coober Pedy in Australia and the pit homes of Matmata in Tunisia.
- **[Idea]** Underground is warmer than the surface in cold regions, which is one reason people there spend time in mining operations.
- **[Proposed]** Underground temperature blends the surface climate (the year-round average just below ground, as in the real world) with the heat that rises with depth. Each region then has a comfortable underground band: a few hundred meters down in the far north, and shallow caves that are cooler than the scorching surface in hot regions.
- **[Open]** How far altitude effects reach, given the current 2,048 m world ceiling.
- **[Open]** What limits diving, and whether the deep ocean floor can be dug.

### 4.6 Expansion and wrapping (existing behavior)

These already exist in the repository and match the vision:

- Each tile's seed is a hash of the world identity seed (stored in every region file header) and the tile coordinate. Tiles never read their neighbors.
- Finalized region files never move or regenerate. The builder skips them.
- The server scans every header at startup, rejects mixed generator versions or seeds, requires a complete rectangle with no holes, and publishes the authoritative wrap bounds.
- The world wraps in both directions at the outer edge of the rectangle. Because every tile edge is the same ocean floor, the seam is invisible.
- Expanding the world takes effect when the server restarts.
- Persistent objects are saved as source region plus local position, so they survive later expansion.

**[Open]** Whether the world rectangle should stay centered on the origin so the north-south wrap joins arctic to arctic.

### 4.7 Growing the map

- **[Decided]** Work starts with the map. The first step is to generate a first island tile that lets people get started.
- **[Decided]** After that, the generator keeps creating unique tiles over time, with different sizes and numbers of islands.
- **[Decided]** Because the world wraps at its edges, the set of tiles must always stay a complete rectangle, and growth has to be planned with that in mind.
- **[Superseded]** The world grows one side at a time by adding a full row or column. The full 21 by 21 world is now planned from day one, with placeholder ocean tiles that are replaced as tiles are built (Section 4.1). Adding rows and columns is only a fallback if the world ever has to be enlarged beyond the plan.
- **[Proposed]** Alternate opposite sides as the world grows (north then south, east then west), so the origin tile stays near the middle. That keeps the equator central and makes the north-south wrap seam join two equally cold edges.
- **[Proposed]** A new row or column is baked into a staging folder and only goes live, at a server restart, once the whole row or column is complete. The existing builder and server already work this way (GENERATION_GUIDE.md).
- **[Proposed]** Because growth is rare, new rows and columns can be baked on a separate machine and copied into the staging folder, so baking never competes with the running server.

### 4.8 Bake time and where work happens

The draft of the permanent formats (world settings, tile file, tile matrix) is in `WORLD_FORMAT_SPEC.md`.

- **[Decided]** Baking one tile with the current generator takes about 15 to 16 hours (measured by the project owner). An efficiency review was started elsewhere but nothing was changed.
- **[Proposed]** That cost does not fit a world that grows by adding unique tiles, especially since any generator change forces a rebake. The likely cause, from reading the code (not yet profiled): the bake fills a complete 3D volume from +2,048 m down to -4,000 m at all 7 LODs, using simulated geology (tectonic deformation, faults, folds, igneous intrusions, strata, caves and minerals) evaluated voxel by voxel in GDScript. The output is probably also many gigabytes per tile, which conflicts with the minimum hardware target (Section 3) if clients must hold it.
- **[Proposed]** Keep the foundation, change what the bake produces. Keep: the region format, catalog and mapper, wrapping, tile seeds, the complete-rectangle check, the resumable atomic bake, the shared deep-ocean tile edge, the coast model and the 2D hydrology (ocean mask, flow, lakes, channels on the 8 m grid). Change: the bake writes compact 2D maps per tile, and voxels come from a fast, deterministic generator at runtime. Volumetric folds and faults are dropped or simplified, since players will not notice them. Mining to about 3 km needs rock layers by depth, caves and ore, which can be simple functions of the maps and seed.
- **[Proposed]** Voxel Tools appears to offer native generators (a graph generator, or one driven by a heightmap) that should be far faster than per-voxel GDScript, and to store only edited blocks. Both claims need checking against the Godot 4.7 build in use.
- **[Proposed]** Each generated block is saved once on the server (an SQLite-style store), so it is never generated twice.
- **[Proposed]** Each tile records the generator version it was created with, and that version is frozen once players have built there, so a later generator change cannot alter terrain under existing buildings. New tiles can use newer versions. This replaces the current rule that rejects mixed generator versions.

**[Proposed] What lives where**

| Layer | Contents | Why |
|---|---|---|
| Baked once per tile, permanent | Tile seed and generator version; height, coast, rivers and lakes; climate zone; soil and biome class; sites for caves, mineshafts, labyrinths and dormant lairs; possibly deposit identities and land-suitability layers | Defines the place. Changing it later moves coastlines and landmarks under players. Small: about 1,921 by 1,921 samples per map at 8 m. |
| Server, deterministic from the baked maps | Voxel fill, rock layers by depth, caves, ore, structure carving, fauna spawning, plant growth, weather | Cheap to produce on demand. Frozen per tile once players build there. |
| Server, living layer | Voxel edits, removed trees, buildings, NPCs, crops, economy | Changes constantly. Saved as deltas on top of the baked and generated base. |
| Client | Meshing, LOD display, fog and horizon impostors, grass and foliage shaders, animation, sound, weather visuals | Keeps the minimum machine light. |

**[Proposed] Islands first, rock derived.** The current pipeline takes surface height from the geology simulation, erodes it, and then the coast model forces everything outside a rounded square to ocean, which is why a tile holds one island. Reverse the order. Each tile is built in 2D on the 8 m grid (1,921 by 1,921 samples):

1. Layout from the island properties panel: islands with position, size, shape seed and character (mountainous, rolling, volcanic, archipelago). A warped-noise land mask gives irregular coasts, and small islets appear where the noise breaks the surface near shore.
2. Elevation: rising with distance from the coast, mountain spines and ridge noise, then shelf, beaches and cliffs down to the shared deep-ocean edge.
3. Rivers and lakes, with the existing flow, lake and channel code.
4. A simple erosion pass on the 2D grid for valleys and winding terrain.
5. Climate from north-south position and altitude, moisture from distance to the sea and rain shadow, giving a biome map.
6. Soil and surface from biome, slope and the existing surficial deposit map.
7. Geology as a feature list (Section 4.9).
8. Placement: cave and mineshaft entrances and dormant lair sites. Flora is not baked: it is derived at runtime (Section 4.3).

A tile should then take minutes, and `world_preview.gd` could show island panel changes almost live. The hardest part is the runtime generator that turns 8 m maps into convincing 1 m terrain (smooth interpolation, detail noise, rock layers, caves and ore) quickly. Voxel Tools' graph generator may do it natively. If not, a small native (C++) generator is the fallback.

**[Proposed] How terrain reaches the client.** Either the server streams compressed blocks and clients cache them on disk, or clients download a tile's small 2D maps and generate unedited terrain themselves. The recommendation and the trade-offs are in Section 4.10 (streamed blocks first). Measure before changing.

### 4.9 Geology, resources and surveying

- **[Decided]** Rocks, minerals and valuable resources are placed by simulating where they would really form, not by fixed depth bands. There should be no "dig to this level and you find diamonds."
- **[Decided]** A different system is fine if it reaches the same result faster and lighter. The project owner is happy to drop the full tectonic and fault simulation for whatever works best.
- **[Decided]** Characters with a higher surveyor skill sense things more easily and get better visual clues, such as ore looking more colorful or obvious. With a very high skill they automatically mark the general areas where they notice things on their map.
- **[Proposed]** The current mineral sampler already ties ore to geology (tin and copper around granite contacts, gold along dikes, faults). Those rules stay. What changes is that the geology itself is stored per tile as a short **feature list** (perhaps 20 to 200 entries) instead of being worked out again for every voxel: granite intrusions (position, size, depth), faults (a line with a dip angle), fold belts and sedimentary basins (areas, each with its own layer stack), and volcanic zones. Layers bend with folds through a cheap 2D warp map.
- **[Proposed]** Ore bodies are derived from those features as objects with a shape (vein, lens, pipe, layer or halo), a grade, an amount and a stable ID. Stable IDs let NPC miners draw a specific deposit down (Section 11.4). At runtime the generator only checks the few bodies that touch the block it is building, through a spatial lookup.

| Resource | Where it forms |
|---|---|
| Tin | Roofs and edges of granite intrusions |
| Copper | Large, lower-grade halos around smaller intrusions |
| Iron, copper, zinc | Where granite meets limestone |
| Gold and silver | Thin, steep quartz veins along faults |
| Placer gold and tin | River gravels downstream of eroding veins, using the river data |
| Coal | Seams in sedimentary basins, bent with the folds |
| Salt and gypsum | Layers in basins, sometimes pushed up as domes |
| Lead and zinc | Hosted in limestone |
| Gems (decided 2026-10-14: individual gems, not one "gemstone") | Diamond: deep volcanic pipes (very rare). Ruby and sapphire: marble beside granite. Emerald: granite edges in shale country. Topaz and aquamarine: crystal pockets (pegmatites) at granite edges. Amethyst and agate: geodes in basalt lava. Garnet: folded slate, and with diamonds in pipes. Opal: volcanic rock near vents. Hard gems also wash into river gravels like placer gold |
| Marble (rock, decided 2026-10-14) | Limestone baked in a ring around granite intrusions, and limestone buried deep in fold belts |
| Chalk (rock, decided 2026-10-14) | Soft white limestone at the top of sedimentary basins (white cliffs) |
| Flint (decided 2026-10-14) | Nodules scattered through chalk layers, and thinner chert through limestone. Flint pebbles also lie on beaches and in river gravels below chalk outcrops, so new players can pick them up without digging (derived at runtime from the rock and soil maps, not stored) |
| Alum (decided 2026-10-14) | Bands in shale (alum shale) in basins, and lenses in volcanic rock altered by hot gases near vents. Used to fix dyes and tan leather |
| Glass sand (decided 2026-10-14) | The existing sand deposits, with a glass quality: clean beach sand best, inland sand fair, muddy river sand poor (`glass_quality` in the soil and deposit tables) |
| Bitumen (decided 2026-10-14) | Natural tar seeping up beside salt domes and here and there in sedimentary basins, reaching the surface as tar pits. Use: waterproofing ships and roofs; a regional trade good, since most islands rely on pine tar made from trees instead |
| Graphite (decided 2026-10-14) | Rare bands in shale deep in fold belts, where old plant-rich mud was cooked under pressure. Use: graphite crucibles. Early game uses plain clay crucibles; a lucky late-game discovery that graphite makes better, heat-proof crucibles gives a higher crucible tier for casting metals |
| Bog iron (decided 2026-10-14) | Rust-colored lumps in marshes and peat bogs, where iron-rich groundwater meets air. An early iron source for a new player without a mine. Not stored in tiles: derived at runtime from the marsh biome and peat soil (like flint pebbles), and it regrows slowly |
| Saltpeter (decided 2026-10-14) | Bat droppings (guano) on dry cave floors, in caves with bat dens, and white crusts on dry cave walls. Derived at runtime from the cave sites and their dens, not stored separately. Uses: fertilizer that raises farm fertility (Section 5), curing and preserving meat, and later gunpowder |
| Nickel | Retired (2026-10-14): no medieval use. Kept in the table so its ID is never reused |
| Aluminum | Not used: it was unknown in medieval times (first isolated in the 1820s) |
| Clay and peat | Wetlands and the surface deposit map |

- **[Proposed]** Depth matters loosely but never predictably. A gold vein might outcrop on a hillside or start 800 m down along the same fault. Mountains stay the best places to mine, since erosion exposes deeper rock there.
- **[Proposed]** Surface clues for prospecting: rusty, stained soil (gossan) above buried sulfide ore; indicator plants that grow only on certain mineral-rich soils; placer gold in a stream leading upstream to its vein; outcrops, mineral springs and the shape of the land. They are baked or derived from the ore bodies, so they are always truthful.
- **[Proposed]** Surveyor skill scales how strongly ore and clues are highlighted, the distance at which they are noticed, and the threshold for automatic map marks. Marks are fuzzy areas whose size shrinks as skill rises, not exact points.
- **[Proposed]** Survey marks are knowledge the character owns. They can be shared, sold as survey maps, or produced by NPC surveyors a town hires, which ties into the economy and the town planner.
- **[Idea]** A **surveyor's book** helps map resources. While it is out it changes how the character sees the world: hovering markers over things already discovered, and glowing marks or areas on the ground where something is probably present.
- **[Proposed]** The book is the home of the character's survey knowledge (the marks above). The glow's strength and size show confidence, which grows with skill and with repeated observation. Having the book out has a cost, such as slower movement and no fighting, so it is a deliberate prospecting mode rather than a permanent overlay.
- **[Proposed]** The book is an item. Pages can be copied and sold or given away, and the book can be dropped, lost or stolen like other belongings, so a rival who takes it gains its knowledge.
- **[Proposed]** The overlay is drawn by the client from the marks the server has sent, so it costs almost nothing on the minimum machine.
- **[Proposed]** The server sends survey clues and marks to each player based on their own skill, so a low-skill player's client never receives what a high-skill one sees.
- **[Proposed]** Ore inside voxels a client has received can be revealed by a modified client (an "x-ray" cheat). The streaming recommendation in Section 4.10 answers it: the server withholds ore that has not been exposed and sends ore materials only for exposed or nearby blocks.

- **[Decided]** (2026-10-14) There are several crucible types. Plain clay crucibles come first; graphite crucibles, which survive much higher heat, are a lucky later discovery (graphite in Section 4.9).

### 4.9a Review of the geology and resource list (2026-10-14)

Question from the project owner: do we have all the building blocks, with a safe way to add more resources later without hurting anything that exists?

**What the first version of a tile can express.** Rock types (10): sediment, shale, limestone, coal, granite, slate, basalt, sandstone, marble, chalk. Province kinds (4): granite, basin, fold belt, volcanic. Feature types (7): intrusion, fault, basin, fold belt, volcanic vent, volcanic pipe, salt dome. Ore shapes (7): vein, lens, pipe, layer, halo, scatter, placer. Resources: IDs 1 to 31, of which 2 are retired (nickel, gemstone) and 2 are derived at runtime (bog iron, saltpeter). Flint pebbles on beaches are also derived at runtime, from the flint resource (ID 27) in chalk.

- **[Decided]** (2026-10-14) New resources must be addable later without moving or removing anything that exists. The design for this is the resource pass (`WORLD_FORMAT_SPEC.md` Section 4a): a numbered, seeded step that only adds new records to tiles.
- **[Proposed]** The only truly permanent part of the geology is the rock layer stack of each province, because it decides which rock voxels appear where. Everything else (ore bodies, features, sites) can be extended by passes. So the rock list is the one list to get right before tiles are kept. A new rock can still arrive later as a small lens or pocket (a rock body), but not as a new layer of a whole province.
- **[Proposed]** The building blocks are enough. No new ore shape is needed now. A "blanket" shape (a thin surface layer of weathered rock, for ochre and similar) may be worth adding when pigments arrive, and a shape is only code, so it can be added later.

**Possible gaps, each with the use that would justify it** (principle: every resource needs a use). None is added yet; each needs a yes or no.

| Candidate | Where it would form | Use | Needed before tiles are kept? |
|---|---|---|---|
| Fireclay | Layer under coal seams | Furnace bricks and linings, middle-tier crucibles between clay and graphite (Section 5) | No, can be a pass |
| Obsidian | Lens at volcanic vents and old lava flows | Early blades and arrowheads, a trade good | No, can be a pass |
| Tuff | Volcanic province layers | Easy-to-cut stone for dugouts and cave dwellings (desert and cold regions, Section 4.5) | Yes if it should fill whole layers; no if it is small lenses |
| Amber, jet | Amber in basins with coal forests; jet in coal seams | Jewellery, trade | No, can be a pass |
| Ochre (iron earth), lapis lazuli, malachite and azurite | Weathered iron caps; marble contacts; copper oxidation zones | Pigments and dyes for paint, banners and cloth | No, when the dye system exists |
| Cinnabar (mercury), arsenic minerals | Hot-spring and volcanic zones | Mercury for gold amalgam, pigment, poison | No, later |
| Soapstone | Metamorphic belts | Cooking pots and hearths in the far north | No, later |
| Quartz crystal, mica | Pegmatites and veins | Lenses, early window panes | No, later |
| Fuller's earth, kaolin | Clay beds in basins | Cloth finishing, fine pottery | No, can be a pass |
| Hot and mineral springs (a site type) | Volcanic and fault zones | Baths and healing at the temple, sulfur, a prospecting clue | No, but a new site type |

- **[Proposed]** Things that need no tile data because they are worked out at runtime: sea salt (from coastal pans), well water (depth to the water table from moisture, height above the nearest water and soil, needed for the "established" town in Section 8.15), flint pebbles, bog iron, saltpeter.
- **[Open]** Which candidates, if any, to add before tiles are kept. The recommendation is tuff only if whole-layer volcanic stone matters; everything else can come in a pass when its system is built.
- **[Open]** Rock list completeness: whether gneiss or schist (hard metamorphic rock at fold belt roots), dolomite or quartzite are needed for stone variety. They have no gameplay use yet, so by the principle they stay out.

### 4.10 Tile downloads and the client cache

- **[Decided]** A client starts in one tile. It downloads that tile and the surrounding tiles, and as the player travels it downloads the tiles around the current tile ahead of time.
- **[Decided]** Players choose how much hard drive space to use for tiles. Tiles they have visited stay recorded in their maps, but the tiles furthest away are removed when space runs out and downloaded again if needed.
- **[Proposed] Recommended start: voxel streaming.** The server sends compressed terrain blocks near the player and the client keeps them in an on-disk cache of the size the player chooses, so the caching idea still applies, at the block level. It is simpler and more reliable (no risk of different CPUs producing different terrain), lighter on the client's CPU, and lets the server withhold ore that has not been exposed, which answers the x-ray concern (Section 4.9). The cost is more network traffic and server work per player, which needs measuring.
- **[Proposed]** Clients still download each tile's small 2D maps, at low resolution, for the world map and for drawing distant terrain cheaply, while nearby terrain arrives as streamed voxels.
- **[Proposed]** If bandwidth becomes the problem later, switch to clients generating unedited terrain from the tile maps.
- **[Proposed]** Generating on the client from the small tile maps (Section 4.8) is the alternative: a ring of 3 by 3 tiles is perhaps tens of megabytes, where streamed voxel blocks for the same area would be far larger. Generation then runs on the client, so it must be fast on the minimum machine, and different CPUs must produce identical terrain. Test that before relying on it.
- **[Open]** The world is one coordinate space about 322 km across. Single-precision positions lose detail far from the origin (about 1.6 cm at 160 km), so the client needs a floating origin (shifting the world around the player) or an engine build with double precision. The wrap lets the client recentre whenever it crosses the seam. Test early in the terrain steps.
- **[Proposed]** Edits travel separately as small deltas per region. The existing region manifest already has a revision number per region, which tells a client whether its cached edits are stale.
- **[Proposed]** The player's map is kept separately from the tile cache, so removing a far tile does not erase what the player has explored.

### 4.11 At sea

- **[Decided]** Players can dive on wrecks and fish with spears, as in Atlas. The open-ocean floor at tile edges is therefore -2,000 m instead of the world bottom, leaving rock beneath and shelves near islands within diving reach (`WORLD_FORMAT_SPEC.md`).
- **[Decided]** Finding flotsam and jetsam and scooping it up with a grappling hook, as in Atlas, is a loved dynamic, but in Atlas it is far too abundant.
- **[Proposed]** Flotsam comes from real events: a merchant ship lost in a storm or to pirates leaves its actual cargo drifting, following the same economy and same-odds rules as everything else. Some background flotsam keeps the sea interesting, at a rare rate. Items drift with currents and eventually sink or wash ashore.

### 4.12 World sketch: islands from the ocean floor

- **[Decided]** The first tile-by-tile plan did not look natural ("a very dirty napkin"). Islands usually form from underwater mountain chains, and the map should reflect that.
- **[Proposed]** Why it looked wrong: every tile rolled its own dice, so the texture was even everywhere; each tile kept its islands near the middle and every tile edge dropped to deep ocean, leaving empty lanes that showed the grid; island rotations were random instead of aligned along ridges; sizes lacked the steep real-world spread of a few big islands and very many small ones; the sea had no depth variation.
- **[Decided]** The world-first approach is approved (2026-10-13). The first version is built: see `WORLD_FORMAT_SPEC.md` Section 5b and `plan/world_relief.png`.
- **[Proposed] World first, tiles second.** The randomizer places 5 to 10 large features across the whole wrapped world: island arcs (curved volcanic chains beside trenches, like the Aleutians), hotspot tracks (a young volcano at one end, older eroded islands, then atolls and seamounts, like Hawaii), continental fragments (large varied islands on shallow shelves, like the British Isles), mid-ocean ridges (rarely breaking the surface, like Iceland), abyssal plains, and coral reefs and atolls in warm water. A coarse elevation map of the whole world (about 160 m per sample, about 2,016 by 2,016) comes from those features, and islands are wherever it rises above sea level.
- **[Proposed]** Each feature also sets its islands' geology: arcs give volcanic rock, copper and gold; continental fragments give granite, basins and fold belts (coal, iron, tin); hotspots give basalt and sulfur; atolls give limestone. Resource placement follows how land really formed (Section 4.9).
- **[Proposed]** Drop the rule that every tile edge falls to deep ocean. Neighboring tiles agree because both read the same world elevation map and the same detail noise in world coordinates, so islands may cross tile borders. Each island's rivers are worked out for the whole island, so both tiles get the same rivers. Tiles still bake one at a time.
- **[Proposed]** The tile matrix becomes a result of the sketch (which tiles hold land, which feature they belong to), not a dice roll. Starter tiles sit on continental fragments.
- **[Proposed]** The world sketch is fixed before tiles are kept. A placeholder ocean tile replaced later can only gain islands that do not reach already-baked neighbors.
- **[Proposed]** The preview becomes a shaded-relief map with depth-tinted sea, an optional tile grid and feature names.

### 4.13 Danger by region

- **[Decided]** Tile (0,0) is potentially the most dangerous tile. It and its surrounding tiles have an abyssal deep-sea floor with possible caverns, and in the future very dangerous pirate ships, possibly a kraken, and whales that attack ships.
- **[Decided]** The whole equator row is higher level: more wreckage to explore but more danger in the water. Its islands have meaner mythical creatures.
- **[Decided]** The north and south polar regions are similar, with yetis and other mythical creatures.
- **[Decided]** The temperate zones near the starter islands are low level and fairly easy. Sailing further east and west gets more dangerous: higher-level and more dangerous creatures, more dangerous landscapes (cliffs, volcanoes), terrible storms and various sea creatures. Getting closer to the edges makes things worse.
- **[Proposed]** A **danger map** in the world settings: a smooth level for every position, combining a latitude part (lowest in the middle of the temperate bands, rising toward the equator row and the poles), a distance-from-starters part, and a peak at the abyss around (0,0). The server reads it at runtime for creature levels, sea monsters, pirates, storm strength and wreck density, so those can be tuned at any time. The world sketch reads it once to choose terrain: more cliffs, volcanic arcs and trenches where danger is high, gentle shelves near starters. Only that terrain part is permanent.
- **[Decided]** An abyssal trench runs through the middle of the world in an oblong shape, covering rows -1, 0 and 1 in the center columns.
- **[Proposed]** Implemented as a fixed world feature in `world.json` (`central_trench`): an east-west oblong centered on tile (0,0), covering columns -2 to 2 and rows -1 to 1 (fifteen tiles), with its danger easing off over about 1.2 tiles beyond its edge. The tile plan keeps those fifteen tiles free of islands, and the danger map peaks inside it, deadliest at (0,0).
- **[Proposed]** Trench floor about -2,800 m, just above the lethal heat depth (about -3,000 m from sea level, Section 4.5), so its floor caverns are the deepest reachable places in the world and anything deeper is deadly hot. The world bottom is -4,000 m.
- **[Decided]** At the very center, (0,0), sits a huge island with a volcano peak, a desert climate and scorched earth. It is the worst island in the whole game: the worst creatures, climate and storms, with castles and caves.
- **[Decided]** The center island is fixed: it must come out exactly the same every time the world is generated.
- **[Proposed]** Implemented as a fixed world feature in `world.json` (`center_island`): an oblong about 20 km east-west and 12 km north-south (about 164 km², roughly four times the largest ordinary island), volcano peak 1,900 m (the world top is 2,048 m), desert and scorched flanks, rising out of the middle of the trench so the abyss is its moat. It reaches into tiles (-1,0) and (1,0), which needs the world-first change that lets islands cross tile borders (Section 4.12). Its size, shape, height and position come only from `world.json`, its seed from the world seed, and its tile is locked, so no random rule can change it. A test checks it is identical even when the random rules change.
- **[Decided]** The center island sits on the hottest row of the world, so it is a giant desert with desert features, not jungle, and scorched earth around the volcano where it has erupted in the past. (This replaces the earlier "large jungle areas".)
- **[Decided]** An area is prepared for the fallen society's city from the far past.
- **[Proposed]** Implemented in the world sketch: sand and red-rock desert with stepped mesas, dry wadis running off the volcano, salt flats in the lowland basins, sea cliffs, a blackened field of lava rock and ash on the upper slopes with old lava flows running down several sides, and the lava river from the crater breach. The fallen city gets a broad, stepped plateau (about 9 km², three low terraces rising to a citadel) on the northwest flank, away from the lava river and the old flows, with an old road (see below).
- **[Decided]** The old road winds from the plateau around the island to places that were probably villages along the shore long ago. It never goes up over the volcano. It is a ruined road, overgrown but still sort of passable, leading to or near the old villages, and it now acts as the path to the caves, castles and labyrinths.
- **[Proposed]** Implemented in the world sketch: a loop around the island at low to middle height that picks the most level line as it goes, a short link from the city, and spurs down to six ruined shore villages (small flattened patches). The lava river and the old lava flows bury the road where they cross it, so it is broken in places. Spur paths to the castles, caves, labyrinths and boss lairs are added at the tile bake, when those sites are placed. Ruins, walls and buildings are placed at the tile bake, from the `ruined_city` entry in `world.json`.
- **[Decided]** The center island is hostile terrain. It will have treacherous flora and fauna, and because it is huge it can hold a few caves, castles, labyrinths and bosses.
- **[Decided]** It may have land enough for a town, but its incredibly harsh climate and terrors would destroy a town long before it got established.
- **[Decided]** (2026-10-14) Working name: the **ultimate island**. The world setting key stays `center_island`. It is the most dangerous place on the whole map, and it holds the greatest riches and the greatest rewards.
- **[Decided]** It is a desert island with a giant volcano. Its dangers include dragons and wyverns, mystical and mythical creatures, giant sandworms and scorpions, ruins, temples, caves and labyrinths, all of them hostile.
- **[Decided]** The ruins, labyrinths and dragons mean treasure hoards and loot are scattered around it.
- **[Decided]** Many fallen adventurers lie on the island with their gear still on them (see Section 6.1, remains). Some are placed with the world, some are players or NPCs who died there.
- **[Proposed]** The placed remains are created by the server when the world starts, not baked into tiles, with gear tier chosen from the region's danger. They need nothing in the tile file.
- **[Idea]** Over time, AI helps create dilapidated ruins and roads hinting at a fallen civilization, probably one that used strong magic and fell, leaving the island poisoned with many magics and terrible threats.
- **[Proposed]** Implemented in the world sketch: jagged ridges and nine ravines radiating from the volcano, 180 m sea cliffs, swampy basins sunk behind the cliffs, and a lava river from the crater breach to the sea. Its share of flat town ground fell from 57 km² to small, broken patches. The island's entry in `world.json` reserves 3 castles, 2 labyrinths, 4 cave systems, 3 boss lairs, ruins and ruined roads, placed deterministically when the center tiles are baked, plus a lore note.
- **[Proposed]** Ruins and roads authored with AI help become fixed data (sites and placed structures) once approved, so they are the same on every generation.
- **[Idea]** Eventually the volcano is drilled out, filled with lava, and overflowing.
- **[Proposed]** The crater is terrain, so its shape is permanent: a crater 1.4 km across and 250 m deep with a breach in the rim facing south-southeast, recorded now in `world.json` so the center tiles bake with it. The lava itself is not voxels. Like water, it is a surface level plus a glowing, moving shader, with heat, fire and damage handled by game rules. The overflow follows a lava river worked out at bake time with the same flow code used for rivers, from the breach down to the sea, where it can steam. Lava that cools could later harden into new basalt as a living-layer change.
- **[Proposed]** Real trenches sit beside volcanic island arcs (the Mariana Trench and the Mariana Islands, for example). The world sketch could place a volcanic arc along one side of the trench, giving dramatic, dangerous islands with meaner creatures next to the abyss. Being in the desert row, the trench pairs the hottest seas with the most dangerous waters.
- **[Proposed]** Implemented as the danger map in `world.json` (curves by column and by row, plus the abyss peak) with five tiers: easy, moderate, medium, hard, deadly. Inner starters read about 0, outer starters about 0.44 (medium), tile (0,0) and the east-west and polar edges about 1. The east-west wrap seam is the dangerous edge; danger is continuous across it. A danger map image is drawn with the world plan (`plan/danger_map.png`).

---

## 5. Harvesting, tools and farming

- **[Decided]** Everything is harvestable with strong enough tools: all trees, all plants (except basic grass), rocks and minerals.
- **[Proposed]** A shared rule: every harvestable thing and every rock type has a hardness, every tool has a power, and a tool works if power is at least hardness. The project already has excavation resistance values for rock types and a resource list that can seed this.
- **[Proposed]** Grass can be handled as small patches if needed, with harvested cells hidden by clients.
- **[Proposed]** Lazy regrowth: store when something was harvested and resolve regrowth when someone is near. Records for regrown plants disappear.
- **[Decided]** Farming comes later. Seeds and grain are found or bought, then planted, grown and harvested.
- **[Decided]** Farming should work on a relaxed rhythm: several fields with rotating crops, and a player who logs in once a week to harvest and plant new crops (Section 7.3). Seasons are driven by the world calendar.
- **[Proposed]** Wild versions of crops exist in the right climates and drop seeds. Planted crops are server-owned objects with a planted-at time, and growth stage is computed on demand.
- **[Proposed]** Crops respond to climate and soil, so climate must be queryable at runtime.
- **[Decided]** The generated fertility map is only the natural starting value. Farmers can improve poor land with time, money and tools: lime, manure and other soil treatment, and terracing or other terraforming. In principle a player could cultivate a whole hillside or a whole heath coast into fertile farmland. Heath stays in the biome mix because it adds realism.
- **[Proposed]** Because of that, fertility needs a changeable layer on top of the generated one: player changes (soil treatment, terraces) are stored as small saved deltas per area, not baked into the tile files, and fertility is used up by growing crops, not by the passage of time alone. Crops read generated fertility plus the delta. Growing crops draws fertility down (some crops more than others, which is where rotation and fallow fields matter); lime and manure build it back. Whether fallow land recovers by itself is open.
- **[Open]** Prepared ground (tilling) as a terrain edit, or seeds on any suitable surface.
- **[Decided]** (2026-10-14) **Three kinds of resource, by how they renew.** The world is not instant-respawn: nothing comes back an hour later.
  - **Renewable:** living things (trees, crops, grass, wild plants). They regrow in stages, so a cleared area fills with seedlings, then young trees, then medium trees, then mature ones, with different species for each biome and climate. Grass keeps spreading into bare neighboring ground, and a forest slowly refills around a clearing.
  - **Semi-renewable:** things nature keeps delivering slowly, such as placer gold, tin and gems in river gravels (worn from veins upstream, so they trickle back), river gravel, pebbles and sand, bog iron, flint pebbles on beaches, saltpeter crusts and clay.
  - **Non-renewable:** rock and ore in the ground (stone, coal, iron, copper, tin, gold veins, gems in the rock, salt and so on). A rock is not renewable. When a deposit is mined out it is gone for good.
- **[Proposed]** How it fits the generator: each ore body has a stable ID and a total tonnage (step 11), so the server keeps a small record per body of how much has been taken, and does the same for each placer. A semi-renewable deposit refills at a slow rate set per resource (a fraction of its capacity per game year, resolved lazily from timestamps like crops), so a panned river stays workable if worked gently and runs thin if stripped. Worked-out non-renewable deposits stay at zero, so the world's supply of coal and iron is finite, which gives islands and trade real value.
- **[Proposed]** Plant regrowth uses the same lazy rule as Section 5 above: store when something was cut, and work out the stage of the replacement when someone is near.
- **[Open]** Whether tool and item type changes what a harvest yields.
- **[Open]** Whether mining the terrain itself (tunnels and veins) is in the first version or only surface rocks. Digging and leveling land are wanted overall.

### 5.1 Farming rhythm

- **[Decided]** Players who log on only Friday and Saturday nights can plant crops and harvest them the next week. With alternating crops they can plant one field on Friday and one on Saturday, then harvest one on each night the following week.
- **[Decided]** Crops get reasonable leeway before and after becoming ripe, so a player who logs in a couple of hours later than usual still finds them ready.
- **[Decided]** The goal is several crops and animals in rotation.
- **[Proposed]** Crop tiers: quick crops of 2 to 3 real days (vegetables, herbs) for players who drop in often; standard crops of about a week (grains) for weekend players; long crops of weeks (orchards, vineyards) as long-term investments.
- **[Proposed]** A ripeness window instead of a single ripe moment. With 60-minute days, a standard crop could be ripe about 6 real days after planting and harvestable until about day 8 or 9.
- **[Proposed]** Overripe crops lose quality gradually instead of spoiling outright, so being late costs a little and never wipes out a field.
- **[Open]** Whether crop growth times follow realistic fractions of the year (in the real world spring wheat takes roughly 100 to 130 days, and winter wheat is sown in autumn and harvested the next summer) or are tuned freely for gameplay.

### 5.2 Farm work and labor

- **[Idea]** Fields and soil work as a simplified version of Medieval Dynasty. A farming hut comes with 3 or 4 worker slots, filled by hired NPCs, the player's children or spouse.
- **[Idea]** Specific buildings control specific jobs. Whoever is assigned to the farm shed handles the fields and crops. Whoever is assigned to the animal pens and barns tends the animals. A person can be assigned to several buildings.
- **[Idea]** Workers, or the player, prepare the soil with manure and then plant. Crop rotation schedules are set on the farm building, as in Medieval Dynasty or Aska, and workers work all available fields until they are done.
- **[Decided]** Children or hired hands work the farm while the player is offline, so it keeps earning and can pay taxes and bills.
- **[Decided]** Hired hands take a cut when they harvest and sell, and the farm stays productive. Working it yourself or with your children earns the dynasty more.
- **[Decided]** Work has priorities in three tiers: urgent (daily animal feeding, fires, rescues), deadline (harvest before rain or frost, planting within the season) and routine (woodcutting, repairs, hauling).
- **[Proposed]** Each field keeps a small soil fertility value. Repeating one crop drains it. Rotation, legumes, fallow and manure restore it. That gives rotation a mechanical reason to exist.
- **[Proposed]** Animals eat crops and hay, produce milk, eggs, wool and manure, and need daily feeding, which is the work hands and children cover while the player is away.
- **[Proposed]** Market saturation: if every farm sells wheat, the price falls, so diversifying protects income.
- **[Proposed]** A hand low in lawfulness might skim, using the theft and provenance systems.
- **[Proposed]** Balance rule: the hands' cut must leave an absent player's modest farm earning more than its taxes and upkeep.
- **[Open]** Whether hands are paid a share of the harvest (sharecropping), a fixed wage, or the employer's choice.

---

## 6. Characters, aging, death, heirs and personal finance

### 6.1 Aging and death

- **[Decided]** Players age. They can woo a partner and have children.
- **[Decided]** Characters start at about age 15.
- **[Decided]** Lifespan is variable. The average person lives between 72 and 90 years, so a typical character dies at about 80 to 85 unless cut down early.
- **[Decided]** For pacing, a typical character ages from 15 to 85 (70 years) over about one real year and about 700 hours of play (Section 7).
- **[Idea]** In their early 20s, players will hopefully settle down, establish a home and a spouse, and make that their base of operations.
- **[Idea]** The base can be in a town that belongs to another player or to the player. A town belonging to the server was also mentioned. The developer-built starter town (Section 8.1) is the first such town.
- **[Decided]** Children age too.
- **[Idea]** Couples realistically keep having children, about one every year or two, and twins are possible. That is one every 5 to 10 real days, or about a dozen children between parent ages 22 and 40 over about three months of real time.
- **[Idea]** Population control: if a family has many children, one might fall sick and die or have a farming accident.
- **[Proposed]** Tie that risk to conditions the player can see and influence (poor food, a crowded house, no healer nearby, unsupervised dangerous work) plus a low baseline of childhood illness for every family, instead of a penalty for family size. Food, housing and land costs make a large family a real expense. Child death is emotionally heavy and can affect age ratings, so it may need gentle handling.
- **[Decided]** A character who is killed with no way to recover, or who is too old or wounded to recover, dies. The player restarts as a new character.
- **[Decided]** If the player restarts as their child, the child inherits everything that remains. The child's first quest may be to find the fallen parent, or hire local adventurers or services to retrieve the parent's gear.
- **[Decided]** (2026-10-14) **Remains.** When a character dies they leave a two-dimensional image of themselves, a decayed body or skeleton with a backpack and all their gear still on it, instead of a tombstone or loot bag.
- **[Decided]** Intelligent creatures may come along, pick up the gear and add it to their hoards. Otherwise it lies where it fell, waiting for someone to pick it up.
- **[Decided]** In the desert, remains can be partly covered by sand, so they can be found but are not obvious.
- **[Proposed]** The heir's retrieval quest (above) leads to these remains, so the mechanics line up: a creature that took the gear makes a hoard to raid.
- **[Open]** How long remains last (see question 12 on dropped items), whether the image is a flat sprite that faces the player, how sand cover is worked out, which creatures collect gear, and whether NPC adventurers who die also leave remains.
- **[Decided]** ARK-style unconsciousness before death. A downed character can be revived, carried or dragged to safety by party members.
- **[Superseded]** Characters age slower while their player is offline. Replaced by the single server clock below. Characters still stay in the world and remain vulnerable while offline: their body can fall unconscious, be burned or be killed, and friends can pick them up, put them on a wagon, or drag them to cover.
- **[Superseded]** Characters and their families age slower while the player is offline, so the household ages together. Replaced by the single server clock below, under which everyone ages together anyway.
- **[Decided]** (2026-10-14) **One clock.** Everyone (players, families and NPCs) ages on the server clock at the same rate, whether or not the player is online. Ageing follows ordinary human rules: pregnancy lasts about nine months, women go through menopause, and a couple can have as many children as they choose to and as biology allows. At 70 years per real year, one year of age is about 5.2 real days, so a pregnancy is about 3.9 real days, a child reaches 10 after about 52 real days and 15 after about 78. Time away ages a character (four weeks is about 5.4 years). The clock must survive server downtime (Section 7.6).
- **[Decided]** Spouses and children stay in the world while the player is away. Events such as bandit raids, dragons and sickness can affect them, which gives players a reason to return.
- **[Decided]** Co-op: friends can tend animals and harvest crops for an absent owner, with permission.
- **[Decided]** Because offline characters stay vulnerable, the downed timer keeps running while the player is offline.
- **[Proposed]** Fertility numbers, to tune: fertile from about age 15, menopause at a random age between roughly 45 and 55 per character. Everything else follows from the server clock.
- **[Proposed]** Downed window or recovery chance depends on age and condition.
- **[Proposed]** Ownership held at the **dynasty** (family line) level, so nothing needs transferring when a character dies. This is consistent with the heir inheriting everything that remains.
- **[Proposed]** Logging out in a bed, inn or your own town makes a character **safer** (not invulnerable), while logging out in the wilderness leaves the body exposed. The project owner agreed and noted inns can be abandoned, attacked or burned, with occupants inside.
- **[Proposed]** A "while you were away" report on login, with events resolved by game rules and optionally narrated by the language model.
- **[Open]** Whether the game warns about the risk of a logout location.
- **[Open]** A grace period for accidental disconnects.
- **[Decided]** (2026-10-14) Long absences are a soft limit, not deletion. A character is never deleted for being away. After about a month away, **duress** starts to build on the dynasty, and each further month it becomes more stressful to run: crop yields drop (for example 10 percent, then 20 percent), animals get sickly and illnesses start to befall the family. Left long enough, the dynasty is run into the ground and the character becomes an NPC again.
- **[Decided]** A character who reverts to an NPC may seek help from the temple and become one of the less fortunate of the town, join the nearest bandit camp, or, if they have skills, look for work in the nearest town and join the local workforce.
- **[Decided]** When a dynasty reverts to NPC, its assets (houses, businesses, farmland, mines and other resource sources) appear on the town manager's operations screen so the town can claim them (Section 8.6).
- **[Decided]** (2026-10-14) **How duress rises and falls.** Duress rises slowly: 10 percent for each full month away (one month away gives 10 percent, two months 20 percent, and so on). It does not start rising again until the player has been away a full month of real time.
- **[Decided]** When the player comes back, duress instantly drops by half of what it is. After that it falls by 10 percent for each real day the player logs in (separate days), so it falls faster than it rose. Example: four months away is 40 percent. The player returns and it drops to 20 percent. Two logins on separate days clear the rest, and the crops grow and the NPC family works the farm or business at full strength again.
- **[Decided]** (2026-10-14) **What duress does.** It applies stress to a neglected dynasty. Crop yields drop, animals may not grow to full weight, reputation takes a small hit over time, and with continued stress the degradation of properties speeds up a little. Bills do not go up because of stress. Costs rise only naturally, because there is more to fix.
- **[Proposed]** Duress maps directly onto the penalties: a duress of 20 percent means a 20 percent yield penalty, with illness chances for animals and family rising with it. At 100 percent (about ten months away) the dynasty is run into the ground and reverts to NPCs. It is resolved lazily from the last-seen time, so it costs nothing while nobody is looking.
- **[Decided]** (2026-10-14) There is no separate free vacation notice. The month before duress starts is the built-in vacation: anyone who is away for up to a month is still within the grace period. Longer absences are covered by a paid block.
- **[Superseded]** **Duress block (real money, future).** A player who will be away for a long time, such as a migrant worker away for 48 days or three months at a time, could pay for a block of time that stops duress: for example $10 for three months, $18 for six months and $34 for a year (early examples, replaced by the per-month account-balance model below). The dynasty stays alive and keeps its place, the NPC family keeps working on the servers and adds to the world, and the player's account keeps bringing value. This fits the real-money ideas in Section 13.8.
- **[Decided]** A block stops duress only. The character keeps aging (the dynasty clock still runs), so someone away long enough can age out. They then come back to their own funeral and choose a successor (Section 6).
- **[Proposed]** The block is a convenience, not an advantage: it adds no bonus, and a player who is simply active never needs one. It follows the principle of never punishing a weekly rhythm.
- **[Decided]** (2026-10-14) **Takeover by marriage.** When a dynasty falls into ruin naturally, the spouse becomes available to remarry. If they marry another player within a set time, that player may pay the town in game currency to cover the back taxes and any unpaid bills, and so claim the dynasty's properties and businesses. A player with enough money who finds a widow or widower that still has property can propose and take over that dynasty. What it costs depends on the dynasty's size, assets and liabilities. After the window ends, the town claims the assets instead (Section 8.6).
- **[Decided]** A player who returns after their dynasty has completely fallen into ruin sees a screen telling them it fell into ruin and that they must start over.
- **[Decided]** (2026-10-14) **Receivership.** A dynasty that has fallen into ruin is said to be **in receivership**. For a week or two (in real time) the family stays on the dynasty's land and property, and in that window other players can approach the spouse to discuss taking on the dynasty. The spouse and family are in dire need of help, so depending on their personalities, traits and how stressed they are, they are more than likely open to the idea.
- **[Decided]** The conversation is the start of the relationship, and the memories the new player has with that spouse begin there (Section 8.8). How it goes is affected by the new player's reputation and affiliations (Section 13.3): a trusted player is welcomed, one with a bad name or an unwelcome allegiance is turned away or treated with suspicion.
- **[Decided]** (2026-10-14) The receivership window is a week or two of **real** time, which gives the original player ample opportunity to come back.
- **[Decided]** If the original player returns during receivership, they can take their dynasty back as their own successor. It comes back in a very bad state of disrepair and poverty, which gives them something to strive for. Duress drops drastically on return and keeps falling each day they log in (see the duress rules above).
- **[Decided]** A returning player can go to the bank for a loan based on their reputation, to buy animals, replant crops or buy food for the winter until they are back on their feet. Loan rates for this are very reasonable, because the town wants to see them succeed (Section 13.5).
- **[Proposed]** The window is real time, so the original player and anyone else who wants the property both have a fair chance to act. If the original player returns, other players' takeover offers end and the dynasty goes back to its owner. Rescue loans are a normal bank loan with a lower rate and a size limit, so they cost the town little and the repayment still comes out of the dynasty's income.
- **[Proposed]** Receivership has a clear start and end, shown on the town manager's screen and to nearby players, so the window is visible. It ends when someone completes a takeover or when the time runs out, after which the town claims the assets (Section 8.6) and the family moves on as NPCs (temple, bandit camp or work).
- **[Decided]** (2026-10-14) **Takeover price and process.** The new player must pay the arrears: the taxes, bills and debts owed. There is no premium on top. They apply to take over the property, and the spouse has to be agreeable. They then wait until the end date of the receivership. At that time, if they have enough in game currency to cover the debts and the original player has not come back to reclaim their account, the transaction goes through. If the original player has returned, the takeover does not happen.
- **[Proposed]** During the window the town cannot yet claim the properties, and the NPC spouse's own personality and memory of the player count (Section 8.8). The new player takes the dynasty with its debts and assets together, so the bank and the town are made whole.
- **[Decided]** **Notifications.** The player is told what is happening to their dynasty while away, by email and later through a phone or device app. Examples: how the harvest went and what the crop sold for at market; a new baby; the spouse won the local lottery; lightning struck the barn and killed some animals; a child was killed by bandits on a delivery to market; the dynasty has reached 10 percent duress, then 20 percent.
- **[Decided]** (2026-10-14) Notifications have priorities. Urgent ones (a death, a child killed, a fire, a takeover offer, duress about to apply or rising, receivership) are sent right away. Routine ones (the harvest, ordinary market sales) go into a weekly update. Exactly which events fall in which group will be decided as those systems are designed.
- **[Decided]** Email comes first, and a phone or device app comes later. Players choose which kinds of notification they get (immediate, daily summary, weekly summary or off), but duress warnings, including the 24-hour warning, stay on by default.
- **[Decided]** Messages are plain templates filled in with the facts from the server's event log, with no language model, so they cost nothing per message and work for the free tier. Notifications only ever carry the player's own information.
- **[Decided]** (2026-10-14) **Duress protection is paid from an account balance.** When the free first month has gone by, the player is told by email or the app that their first level of duress is about to apply, and is offered the chance to clear it. That takes them to a web page where they can put money into their account. The account holds real money that can be used for protection or for buying things in the game.
- **[Decided]** (2026-10-14) Paying is not the only way to clear duress. When the first month ends, the player is notified and can clear it simply by logging in, with no payment. If they do not log in within the next 24 hours, the duress is applied. After that they get regular weekly updates showing how the dynasty is being affected, and at any point they can correct the situation by logging in (duress falls as described above) or by paying for protection.
- **[Decided]** Protection time depends on the money in the account. As an example, protection costs $5 per month. Whenever additional duress is about to apply, the game checks the account and, if there is money, applies protection one month at a time and sends a notification. There is no limit on how long: it depends only on how much money the player has put in.
- **[Decided]** The moment protection is bought or applied from the account, all current duress is erased.
- **[Proposed]** The earlier example prices ($10 for three months and so on) are replaced by the per-month price, which is set by the market analysis (Section 13.8). Phone app stores generally require their own in-app purchase system for digital goods and take a fee, and the whole system should work without real money until then. Players can also buy a block directly from the web page instead of keeping a balance. A balance of real money, with purchases and refunds, is stored value, so check payment and consumer rules by country before building it, and decide whether unused balance can be refunded.
- **[Open]** What happens when several players apply for the same dynasty, whether the money is held (escrowed) from the time of application, whether a failed payment at the end date passes the offer to the next applicant, and the final prices for blocks. (A free vacation notice was decided against; notification channels are set above.)
- **[Decided]** Short absences are covered by the free first month before duress starts (see above).
- **[Open]** What happens when a character dies with no heir.
- **[Open]** How permanent offline loss should be (can family members die, can buildings be destroyed).
- **[Open]** Who can raid whom: only NPC bandits, monsters and sickness, or other players as well.
- **[Open]** Whether dropped items expire, and whether items in hard-to-reach places last longer.
- **[Open]** Whether other players and NPCs can rob or finish a downed character. The intended answer is that it is a crime handled by the legal system (Section 9), not a blocked action.

### 6.2 What an heir inherits

- **[Decided]** The heir inherits equipment, businesses, properties and bank accounts. The only thing missing is the character's personal skills.
- **[Decided]** Debts pass to heirs along with everything else. A debt that expects a regular payment becomes the heir's obligation, stays on the books and is paid accordingly.
- **[Proposed]** The dead character's assets pay creditors first, so dying cannot be used to dodge debt. If the estate is worth less than its debts, creditors take what is there and nothing more.
- **[Proposed]** A business's own record carries over, but the heir's personal reputation starts blank. A **family name** could carry some standing, good or bad, from the dynasty.
- **[Proposed]** Early on an heir leans on NPC employees and managers for skills they lack, and must learn the trade or hire for it.
- **[Idea]** Children learn some skills from their parents as they grow, so when a parent dies the heir is a partially trained character already waiting. The project owner described this as a theory for now.
- **[Open]** How large that head start is, and how it works for player heirs compared with NPC children.
- **[Decided]** When a character retires or dies, the player chooses a successor from their children, whichever spouse they came from. The whole dynasty passes to that one successor (Section 6.7). An older child has better skills but less time left to play.
- **[Idea]** The will names the successor and lists the children with their skills and attributes and leaves the farm or the town to a chosen child. It should be set long before death and can be updated at any time.
- **[Proposed]** If a parent dies at 80, an heir aged 20 has about 11 months of real time left on average, one aged 35 about 8.6 months, and one aged 50 about 6 months.
- **[Superseded]** Which character the player plays and who inherits the property could be separate choices. Playing one child while the will leaves the farm to another creates a sibling story.
- **[Decided]** (2026-10-14) Without a will, the family decides. The children and the spouses decide among themselves who should be next. A child may not want it, may lack the skills, and may have other plans (their own dynasty, pig farming, adventure). For a player's character the result is a random choice among the eligible, so it is wise to make a will while able to. There is no automatic "eldest child" rule.
- **[Proposed]** NPC siblings with greed or resentment might contest a will, and a forged will would use the forgery system. Adult children who have moved away still appear on the list.
- **[Decided]** The person you play and the owner of the dynasty are the same: the successor.

### 6.3 Personal finances

- **[Decided]** Each individual has a finances tab showing what they own, what they owe, how much they have banked and how much they carry on them.
- **[Decided]** Money in the bank is reached at the bank in person. A character away from their own town can instead try to write a letter of credit, based on their reputation (Section 13.5).
- **[Proposed]** The tab also shows a calendar of upcoming payments and a forecast ("your account covers the next three payments").
- **[Proposed]** Carried cash is exposed: it can drop on death or be stolen like any item. Banked money is safe but needs a visit to a bank.

### 6.4 Obligations

- **[Proposed]** Loans, tax bills, wages and tolls are all one kind of record: who owes whom, how much, and when it is next due.
- **[Proposed]** At each periodic settlement the server pays what is due from the account, whether or not the player is online. A payment that cannot be made is a missed payment, with a reputation hit and eventually penalties or seizure of collateral.
- **[Proposed]** Missed payments while away appear in the "while you were away" report.

### 6.5 Staying alive

- **[Decided]** Design intent: the game tries to keep you from dying, even though the whole world is trying to kill you.
- **[Decided]** Systems let good NPCs rescue a character who has fallen, and let friends save them.
- **[Idea]** In the future, a normal adventuring party is two or three real players plus perhaps one or two NPCs.
- **[Proposed]** The downed state (Section 6.1) is the rescue window. Its length depends on age and condition.
- **[Proposed]** NPC companions use the same traits, skills and memory systems as other NPCs. Their ability to help (carry, drag, heal) depends on their skill and on being nearby.
- **[Proposed]** Rescue comes in layers: party mates and companions first, then nearby well-meaning NPCs or travelers, then town guards and patrols. Death should come from several layers failing, not from one bad moment. After death, the heir's retrieval quest (Section 6.1) is the final layer.
- **[Open]** How NPC rescue works in practice: companions only, passersby, or patrols dispatched to a call, and how to stop it from making death meaningless or being farmed.
- **[Open]** Whether NPC companions count toward party size, and what they cost (wages, upkeep).

### 6.6 Children and family growth

- **[Decided]** Having a child is a joint decision. The player discusses it with the spouse, they agree, and the pregnancy begins. It is not automatic and a bot-run household does not breed on its own.
- **[Decided]** A baby and young child are a cost on the household (food, care, the spouse's time), not a worker. The child becomes useful around age 10 to 12.
- **[Decided]** At about that age the player talks with the child about what direction to take and can set markers that steer them (farming, mining, a trade, adventure, schooling, being the heir). The child follows the markers according to their own interests and abilities.
- **[Decided]** The default for a child with no markers is idleness: play, little work, few skills. An unattended household therefore raises children with weak skills and a farm that stagnates.
- **[Decided]** An engaged player can teach the children, so different children can serve different branches of the dynasty (one runs the mine, others work the farm, some adventure). All of these bring wealth and options to the family.
- **[Proposed]** Teaching speed depends on the parent's own skill in the trade and the time they spend with the child. This links to the partial-training idea in Section 6.2.
- **[Proposed]** The child's own traits can pull against the markers, so a strong push against a child's nature gives slower, grumbling progress.
- **[Open]** How much time teaching costs the parent, and whether NPC tutors or apprenticeships can stand in for the parent.

### 6.7 Automation and dynasty transfer (discussion)

- **[Proposed]** Bots and client automation are banned in the terms of service. Hands-off play via NPC staff is allowed by design, and the household economy already pays less for neglect (Section 6.6).
- **[Proposed]** A weekly check-in that clears duress could require one real choice (sign off on the ledger, answer a letter, pick a family task), so a bare login does nothing.
- **[Decided]** Dynasties transfer inside the game by several routes: marriage, adoption, will, or sale to a successor, with a transfer tax. The login itself is not sold, so identity, reputation and record stay with the person.
- **[Open]** Whether the weekly check-in needs a real choice. The project owner is undecided for now.
- **[Decided]** A person has only one dynasty. Taking over another dynasty (purchase, marriage, rescue) merges the two by combining the entire families. Everyone comes in under the player: the player gains a new spouse or spouses and stepchildren, and all the properties, businesses, debts and everything else that goes with the dynasty.
- **[Decided]** A dynasty may have several spouses over time. They die off from age or sickness, and each adds assets and holdings to the dynasty.
- **[Decided]** Duress stays simple. It slowly applies stress to an ignored dynasty, which can then die off, be sold or fall apart. It is a money sink only indirectly, through the effects above and the extra repairs they cause.
- **[Proposed]** Duress is one value per dynasty, so merging never multiplies the upkeep. The merged dynasty takes the higher value on the day of the merge, or the buyer's own, whichever the design settles on.
- **[Decided]** Only the chosen successor inherits. The whole dynasty passes to that one person. It does not matter which spouse a child came from, since all are the head's children and all are eligible to be successor at retirement or death.
- **[Decided]** When the dynasty passes, the previous head's spouses become cared-for elders in the household. The new head must find a partner of their own.
- **[Decided]** (2026-10-14) **Retirement.** A character who lives into old age and becomes too old and frail to carry on can choose a successor and retire. The player then takes over the successor's body, and the retired character becomes a senior or elderly NPC who lives out their remaining days on the farm.
- **[Decided]** (2026-10-14) **Naming a successor can be tested while alive.** Because NPCs talk through the language model, a player can say to a child, stepchild or spouse, "I am thinking of making you my successor", and they answer as themselves: proud, nervous, or unwilling. Naming someone does not bind them. They can still decline when the handover comes.
- **[Decided]** (2026-10-14) **The handover chain (order of succession).** When the dynasty is handed on (death or retirement), the named successor, if any, is asked first. If there is none, or they decline, the offer goes down this line, and each person in turn accepts or declines. A spouse always comes after her own children:
  1. All of the player's own blood children, grouped together and taken oldest to youngest, whichever spouse they came from. (Five children with the first wife and two with the second are one group of seven, by age.)
  2. The first spouse, if able. An elderly or dead spouse cannot take it.
  3. The second spouse's children from before (the player's stepchildren), oldest to youngest, then the second spouse.
  4. The third spouse's stepchildren, then the third spouse, and so on in the order the spouses were married.
  If the first spouse has children of her own from before, they come between the blood children and her. A living spouse who is able will accept. Whoever takes it may become the player's character.
- **[Decided]** (2026-10-14) **Each person in line chooses; with no will, the chain is the order of asking.** The chain is the order in which the offer is presented. Each person in turn may accept or refuse, and a refusal passes it to the next in line. With no will, nobody is named, so the offer simply goes down the chain.
- **[Decided]** (2026-10-14) **A will raises the odds, but is never a certainty.**
  - If a successor is named, the chance they accept is much higher.
  - It is not 100% just because it is a parent's will. It is certain only if the successor agreed beforehand.
  - If a child told the parent they truly do not want it and is named anyway, the chance of accepting rises by about 50%, so it becomes a coin flip. If they refuse, it passes to the next in line.
  - **Character attributes decide the odds.** Loyalty, a sense of duty and greed each push toward accepting, so most people will accept. There is always some chance they will not.
  - The one exception is the last in line, who must accept (above).
- **[Decided]** (2026-10-14) **The last in line must accept.** If the offer goes all the way down the chain and everyone has declined or is dead, the last person on the line, which is the youngest child (not the last spouse), accepts no matter what. A player who has built any lineage always keeps their dynasty.
- **[Decided]** (2026-10-14) **No lineage at all: the mysterious will.** If the player has no dynasty or lineage left, they roll a new character, who receives the whole dynasty through a mysterious will from a stranger. The server charges a heavy inheritance tax on it.
- **[Decided]** (2026-10-14) **Inheritance tax is money only, and the player chooses what to sell.**
  - The tax is always money and must be paid before the character can play.
  - If the character cannot pay, a screen lets them pick which equipment and properties to sell to raise it. It is always their choice.
  - **The server never takes items.** Nothing is taken away from anyone: not hard-won gear, boss drops, bought cosmetics, or anything they enjoy. Only money is ever asked for.
  - **Dying poor:** if there is not enough to sell without losing their best things, the player may borrow from the nearest town to cover the tax, and the temple may cover part of it based on their reputation with the temple. The more they have done for the temple, the more it offsets the tax.
- **[Decided]** So it pays a character to spend time encouraging the children to want to be the successor (conversation, teaching and the markers in Section 6.6).
- **[Decided]** Siblings who are not the successor stay in the household and age out over time, unless they leave (see below).
- **[Decided]** A dynasty can have many living spouses at once. The aim is to grow a dynasty as in medieval times and plan against sickness and age. Spouses are people who help run the day-to-day work of the dynasty and household and help raise children.

### 6.8 Non-successor siblings (to design later)

- **[Idea]** A sibling outside the succession line decides for themselves, using their traits, skills, memory and preferences, whether to stay with the dynasty or break off and live their own life.
- **[Idea]** A sibling might marry another player and join that player's dynasty, or take a local job (temple, inn) and become a town character who keeps a tie to the family.
- **[Idea]** A sibling who leaves chooses between their own house and living at the homestead, where their income counts toward the dynasty's income.
- **[Open]** All of this is deferred. It needs the NPC decision system (traits, preferences, language) and the household income model first.

### 6.9 Adoption and inclusion (to explore more)

- **[Decided]** The game does not restrict who can be spouses. Same-gender couples, and any couple that cannot have children, are fully supported.
- **[Decided]** Dynasties can adopt children. A couple can apply to the local temple, or the temple can reach out to them.
- **[Proposed]** Requirements to adopt: the dynasty has a home, enough income to raise a child, and a good enough reputation. A child who is adopted becomes family and can become the successor.
- **[Decided]** Adoptable children come first from displaced NPCs: children under a set age from collapsed dynasties who have no parent.
- **[Decided]** A displaced child who still has a parent can come with that parent. The temple may introduce a displaced spouse with children, and the couple may choose marriage, adoption or both.
- **[Decided]** When there are not enough displaced NPCs, the server keeps a number of pre-generated orphans at each temple, with the number picked at random each week. There is also a random chance of a spouse with one or two children waiting at the temple.
- **[Open]** How an adopted child's traits and background are generated, how the temple decides between applicants, and the age limit for a child to count as adoptable.
- **[Open]** Whether other routes should exist (guardianship of a relative's child, fostering) and how they differ from adoption.


### 6.10 Extended life and hiding it

- **[Decided]** (2026-10-14) A dynasty can exist with no spouse and no children. A character in that position may seek immortality or a longer life during their lifetime.
- **[Idea]** (2026-10-14) **Ways to get it.** Paying a large sum to the local mage; a journey or quest whose reward is a wish or some other special mechanic; or an arrangement with an otherworldly being that grants longer life or slower aging.
- **[Idea]** (2026-10-14) **What it can do.** The character ages very slowly, has their age frozen at a chosen age, or is turned back to a chosen age. For example, a 70-year-old who completes a quest for a wish may wish to be 30 forever. If the server judges the wish reasonable, it locks the age in and makes them younger.
- **[Decided]** (2026-10-14) It does not stop sickness or death. A long-lived character can still fall ill or be killed.
- **[Idea]** (2026-10-14) **Others notice.** Over the years friends see that something is strange. The character may be labeled a witch or evil, because people do not understand. They would have to move from town to town to put distance between themselves and people who know them.
- **[Idea]** (2026-10-14) **A new identity every 20 years.**
  - The character keeps their old name but must re-establish a new identity about every 20 years, claiming to be the son or daughter of the earlier person.
  - Returning to an old town, the people who knew them are old or dead. If they are old, the character can say the earlier person was their mother, father or grandparent.
- **[Open]** How this fits the succession chain (Section 6.7) and the single server clock (Section 6.1); how the server decides whether a wish is "reasonable"; whether the 20-year identity change is enforced by rules or only by how NPCs react; and what it costs.

### 6.11 Familiars (future)

- **[Idea]** (2026-10-14) Familiars, as in D&D, could be added later as companions that give comic relief. The model is Claptrap from Borderlands 2, but as a parrot, monkey, dog or similar animal that talks to you, constantly teases or mocks you, and says funny things.
- **[Idea]** (2026-10-14) Now and then a familiar could say a catchphrase in the style of a famous cartoon (such as a power-word shout), purely as a joke.
- **[Open]** What a familiar does besides talk (carries items, scouts, delivers pigeon mail), how it is obtained, whether it ages or dies, and whether it can be turned off.

### 6.12 Homages and Easter eggs (future)

- **[Idea]** (2026-10-14) Hide references throughout the game as homage to the creators of great fiction, games, films and stories. The project owner's son suggested a wizard's tower that looks like a small box or telephone booth from outside but is large inside, with a painting of a caricature of the Doctor (or of all the Doctors) on the wall.
- **[Idea]** (2026-10-14) Other examples: a religion whose god looks like a cartoon doctor from a famous time-travel show; in a wizard school's hallways, paintings of caricatured famous wizards from books, D&D games and films; a hall of heroes with caricatures that resemble famous cartoon heroes.
- **[Decided]** (2026-10-14) **Never copy exactly.** The references must not look exactly like the originals, to avoid infringing anyone's copyright. They are nods, not copies. (This follows the same rule as the original-characters-only approach for anything drawn.)
- **[Open]** Who decides what is a safe homage, and whether to review each one before release.

---

## 7. World time

Aging, marriage, children growing up, crop growth, regrowth, decay, taxes, loan payments, work hours, patrol and trade schedules, memory fading and seasons all depend on time.

### 7.1 Lifespan targets

- **[Decided]** For pacing, a typical 15-year-old character ages to 85, which is 70 years over about one real year and about 700 hours of play. Lifespan varies, averaging 72 to 90 years (Section 6.1). An earlier version of this document used 15 to about 80 (65 years).
- **[Decided]** The expected player plays 12 to 16 hours a week (for example four hours on three nights, or eight hours on each of two nights), about a year of real time per character, allowing for two missed weeks. That is 50 weeks, so 600 to 800 hours, about 700 in the middle.
- **[Proposed]** Skills should feel competent in tens of hours and mastered in a few hundred, so a character gets time at the peak before aging slows them. That much play time needs enough depth to stay interesting.

### 7.2 Why one clock does not work

**[Superseded in part]** (2026-10-14) The table below assumed ageing slower while offline. The decision is a single server clock for everything. The aging rate (70 years per real year) and the calendar rate (a 365-day year of 60-minute days is about 15.2 real days) are two rates derived from that one counter, which is why they can differ. Ageing offline is no longer a variable.

Assumptions: 70 game years of aging (15 to 85) over one real year with about 700 online hours and about 8,060 offline hours. Aging runs at full speed online and at a reduced "offline speed" while logged out, and the household ages with the player.

| Offline aging speed | One game year lasts (real time) | One season lasts | One online hour is worth |
|---|---|---|---|
| None (ages only online) | 10.0 online hours | 2.5 online hours | about 36 game days |
| One tenth | 0.90 days | about 5 hours | about 17 game days |
| One quarter | 1.6 days | about 10 hours | about 9 game days |
| One half | 2.8 days | about 17 hours | about 5 game days |
| Same as online | 5.2 days | about 31 hours | about 3 game days |

- Because a casual player is offline for more than 90 percent of the week, the offline aging speed matters as much as the online speed.
- If aging, seasons, crop growth and taxes all ran on one clock, a game year would last under a week in every row and a season would be about a day or less. A crop cycle would be shorter than a play session. That is why the game uses two clocks (Section 7.3).
- **[Proposed]** The offline aging speed also decides how much heavy and light players differ. With the average player fixed at 70 years per real year, a player online 25 hours a week ages about 95 years in a real year at one-tenth offline speed, 82 at one quarter and 74 at one half. A player online 5 hours a week ages about 52, 62 and 67. A higher offline speed keeps players closer together, and a low one makes heavy play shorten a character's real-time life.

### 7.3 Two clocks

- **[Decided]** The world has its own calendar clock, running at its own reasonable pace. Seasons depend on it.
- **[Decided]** Characters experience all four seasons (spring, summer, autumn, winter). A full seasonal cycle takes about one to two weeks of real time. The exact length does not matter as long as it feels reasonable, but it must let players put crops in the ground, watch them grow and harvest them.
- **[Decided]** Farming supports a once-a-week rhythm. A farmer can build several fields with rotating crops, log in on a weekend to harvest and plant, and enjoy the game that way. Farming Simulator 22 and the rest of that franchise are the inspiration.
- **[Proposed]** Avoid a calendar year of exactly 7 or 14 days. A player who logs in at the same time each week would see the same single point in the year (7 days) or only two opposite points (14 days), and might never see winter. A year of 9, 10 or 11 days steps a weekly player through the whole year over 9 to 11 logins.
- **[Proposed]** With 60-minute game days (Section 7.5), a 365-day year lasts about 15.2 real days, which is not a multiple of 7. About 168 game days (almost half a year) pass between weekly visits, so a weekend farmer plants in spring, harvests in late summer, and next visits in winter.
- **[Proposed]** Crops grow on the calendar clock, using the lazy timestamp approach. A ripe crop stays ripe for a window at least as long as the typical gap between visits before it spoils, so a weekly player is not punished.
- **[Proposed]** Absent farmers can rely on friends (Section 6.1) or hired NPC farmhands to harvest and replant.
- **[Proposed]** The seasonal swing grows with distance from the equator. Near the equator the year is closer to wet and dry seasons than to hot and cold.

### 7.4 NPC aging

- **[Decided]** NPCs age at about the same speed as a typical player: 70 years over one real year, from a random starting age to a random death age. Starting ages are roughly 20 to 30 and death comes roughly between 70 and 90. Their aging runs on the character aging clock, not on the calendar.
- **[Proposed]** At that speed one year of age is about 5.2 real days. An NPC who starts at 25 and dies at 80 lives about 9.4 months of real time. One who starts at 30 and dies at 70 lives about 7 months. A child takes about 11 weeks to reach 15. A town's population therefore turns over in about a year, so births, marriage and migration matter.
- **[Proposed]** An NPC's birthday comes every 5.2 days, not once per calendar year. With a 10-day calendar year an NPC ages about 1.9 years per calendar year. Showing age as a life stage (child, young adult, adult, elder) instead of an exact number could avoid that oddity.
- **[Decided]** Everyone ages on the server clock (Section 6.1). **[Open]** The exact length of the calendar year, and whether age is shown as a number or a life stage.

### 7.5 Day and night

- **[Idea]** One game day lasts one real hour (24 to 1). The project owner leans toward 60 minutes over 72: it gives more day and night cycles per session and encourages shorter weekday visits to keep up with farming, which spreads server load across the week instead of concentrating it on weekends.
- **[Proposed]** Day length varies with the season and with latitude, calculated on each client from the server clock, the day of the year and the latitude, so it costs nothing on the network. Near the equator day and night stay about even all year. Toward the poles summers have long days and winters long nights, and far-north winter darkness becomes another soft limit.
- **[Proposed]** Night is compressed compared with the real world, aiming for about two-thirds day and one-third night at mid-latitudes (around 40 minutes of day and 20 of night), with long, usable dusk and dawn.
- **[Proposed]** Night is never pitch black. Moonlight and torches keep it playable. A persistent multiplayer world cannot let players sleep through the night, so night has to be content, not waiting: more danger, monsters, stealth for thieves, guards on watch.
- **[Proposed]** For comparison, from memory: Minecraft's full cycle is about 20 minutes and Valheim's about 30. The slower 60-minute day suits a game about settling and farming.
- **[Proposed]** Shops, work hours and schedules run on game hours. A 10-hour work day is about 25 real minutes.
- **[Open]** 60 or 72 minutes per game day, and how much more dangerous night is than day.

### 7.6 The server clock

- **[Proposed]** The server keeps one stored time counter. Time of day, the calendar and age are all derived from it with different constants, so there is one source of truth.
- **[Proposed]** The counter advances only while the server runs, instead of following the wall clock, so a server outage does not suddenly age everyone or ripen every crop.
- **[Proposed]** Production in each town is settled once per game day, which is once per real hour with 60-minute days. That keeps the server load small.

---

## 8. NPCs and towns

### 8.1 Towns

- **[Decided]** Players found towns by placing a **town block** that they own. They can assign themselves as owner or leave governance to AI.
- **[Decided]** Players start at a **starter town**. For now it is just a spawn point, where the initial developers build the first town. That town becomes the starting town for future players. (This replaces the earlier "no starting towns" decision.)
- **[Decided]** Players should spend years traveling and adventuring. Trade routes get established as towns are built.
- **[Decided]** The original players build the original towns. Once the first town is started, AI NPCs are added to manage, design, build and extract resources.
- **[Idea]** **Admin town warehouse.** Admins have a special menu that places an admin warehouse, a creative-mode style warehouse that supplies whatever is needed. Any NPC in that town can use it for building and for selling supplies, so the starter town's tradespeople always have basic supplies for sale and admin town building goes much faster. It might be a default for starter towns.
- **[Decided]** Only town admins, town NPCs and residents can take goods from the admin warehouse. It shows two supply numbers: a limited supply for residents who are not admins, and an unlimited supply for server town admins.
- **[Decided]** (2026-10-13) **Buy before manifesting.** Server admin towns with an admin warehouse always try to buy resources from player-run towns (when available) before using the warehouse's magical ability to manifest supplies. A new player therefore always finds a buyer waiting as soon as they start producing, and because all towns degrade and buildings need upkeep, that demand never ends.
- **[Decided]** To avoid imbalance, admin town buying has limits: how much it will buy from each town and how much in total per day. Budgets are a money amount per day, set in the town manager (Section 8.5). The warehouse manifests only what purchases could not cover.
- **[Decided]** The admin warehouse log shows both: goods bought from players and goods manifested.
- **[Decided]** The starter towns' prices are set by their merchant, not fixed by admins. The merchant reviews prices once a day and raises or lowers each one from supply, demand and other factors: an abundance of a good lowers its price, high demand raises it. Admin town buying pays these prices.
- **[Decided]** Goods bought from NPC tradespeople are limited by how fast they can actually make them. They have orders to keep a stock level, and when someone buys an item the NPC has to stop and make another to replenish it (Section 13.7).
- **[Decided]** Starter items are worthless to vendors, because everyone gets them from the starter town. A vendor asked to buy one says something like "you know how many of these I see in a day? I can't get rid of the stock I have."
- **[Decided]** Starter items are made of the most basic materials. Melting one down returns at most 80% of the material, and only with a really good skill.
- **[Proposed]** Starter items carry a "starter town" maker's mark under the provenance principle (Section 3), which is how vendors recognize them. Salvage yield rises with skill up to the 80% ceiling. Every admin warehouse withdrawal is logged.
- **[Decided]** (2026-10-14) **Founding.** The town block is a marker with no physical form (see Terminology). Until the owner puts down an office building (a keep or castle with an office, a house with an office, a town hall or a magistrate's office) they cannot reach the town settings. The building is also where the town manager lives and works. The marker is the centre of the town, so the well naturally goes over or beside it.
- **[Idea]** **Founding sequence.** After the first office come a town planner's office and a builders' guild. The planner surveys the land and suggests the best areas for roads, districts, suburbs and town walls. Once the player approves, builders level the land for roads and lay cobblestone paths or dirt roads, with bridges where required. With roads done, the planner suggests building locations with an explanation of where and why. If approved, the planner places the building, or the player places it.
- **[Decided]** Apart from the starter town, the first players (the project owner's friends and family) build the towns.
- **[Decided]** Towns become server-owned when a town owner's dynasty falls into receivership and nobody takes the town over, and are then offered for sale (Section 8.12). Nothing is placed at the start, so this does not affect the bake.
- **[Decided]** Players build roads and buildings, choosing from premade blueprints.
- **[Decided]** The town block interface sets rules and settings: militia, elite guards, a town bank and town funds, tax rates and tax rules. Towns can build and improve defenses.
- **[Decided]** Player-run towns can fall into ruin.
- **[Proposed]** Ruins as landmarks that decay lazily over time.
- **[Decided]** Ruins do not vanish. Buildings fall to rubble that stays until harvested, and roads stay (Section 8.13).
- **[Decided]** Players can found their own town on a starter landmass as long as it is far enough from the starter town center. Large islands can hold several towns, which can build tension between neighboring towns.
- **[Superseded]** Minimum distance from a starter town center to a new town block about 3 km, and between any two town blocks about 2 km, both tunable in `world.json`. Replaced by the reservation rule in Section 8.17.
- **[Decided]** Mines owned by the starter town have guards to dissuade players from stealing.

### 8.2 NPC population

- **[Decided]** Population is controlled by aging, sickness, poverty and murder.
- **[Decided]** New NPCs spawn at about age 20. If two single NPCs live and work together they may marry and have children. Children start small and stay near or within a reasonable distance of their parents. They grow up with skills and temperament similar to their parents.
- **[Decided]** When a player builds a job building (for example a blacksmith blueprint), an NPC may come along and apply. The server rolls up a new NPC and places them in the world.
- **[Decided]** NPCs start at level 1 and simple. Over time they build stories, history, skills and fortitude. They can gain or lose wealth.
- **[Decided]** NPCs have core traits: goodness, lawfulness, physicalness, dexterity, wisdom, intelligence, charisma, and others. They also have skills like players.
- **[Decided]** NPC memory tries to remember everything but forgets over time, like a human.
- **[Decided]** NPCs are the main story drivers, offering work and adventure to players.
- **[Decided]** Players can converse with any NPC. Conversations are handled by a **language model**.
- **[Proposed]** Keep personality (goodness, lawfulness) conceptually separate from abilities (physicalness, dexterity, wisdom, intelligence, charisma). Personality drives choices, abilities decide whether choices succeed.
- **[Proposed]** Each memory stores a strength, an importance and a timestamp. Decay is computed only when the NPC recalls it, and recall reinforces it. Importance slows fading. Strongest relevant memories plus traits form the context for a conversation.
- **[Decided]** Language model use follows the budget in Section 3: conversation with players and occasional judgment calls use the model, and routine NPC work runs on rules.
- **[Decided]** The project owner intends to run a language model on their own Ubuntu machine as the game's AI source, and to add hardware as the game grows.
- **[Proposed]** Tools such as Ollama and llama.cpp run open-weight models on Ubuntu, and vLLM is built for serving many requests at once. Calls cost nothing per use, but hardware, power and capacity are real limits, and a small model is weaker than large hosted ones, so prompts should be tight and outputs structured and validated.
- **[Proposed]** Check each model's license before building a paid game on it. Some open-weight licenses restrict commercial use.
- **[Proposed]** If the model is busy or offline, NPCs fall back to rules or simple dialogue and the game keeps working.
- **[Proposed]** NPC population caps per island or region.
- **[Idea]** NPC merchants eventually appear on their own. They need somewhere to live and somewhere to work, so they only appear where a profitable opportunity (a price gap and a connecting road) coincides with available housing and workspace.

### 8.3 Displacement and migration

- **[Decided]** When a town falls, displaced NPCs migrate toward the nearest town, with some randomness (sometimes the second nearest).
- **[Decided]** On arrival they look for work they are good at, may take a new job, may build a house or inn if wealthy enough, or may become bandits or join a traveling circus or bandit group.
- **[Proposed]** Choices are weighted random, with traits shifting the weights.
- **[Proposed]** Travel is abstract when no player is near (departure time plus travel time), using wrap-aware distances.
- **[Open]** Whether NPCs can cross the ocean on their own. If not, islands are separate populations unless ships connect them.

### 8.4 Town planning and the civil engineer

- **[Idea]** Eventually, both AI and player characters can build and work on towns. A town owner could hire a civil engineer.
- **[Idea]** The engineer organizes town ideas and suggests routes for roads, areas for farmland, and how to lay out the town, with a little randomness.
- **[Idea]** In the town control panel the owner reviews the plans and approves or denies them. The engineer's job is to keep improving the town. Once a plan is approved the engineer arranges builders to start on houses, buildings and roads, in the style of the old Warcraft-type games.
- **[Proposed]** A plan is a data object (zones, road routes, field areas, building footprints) generated by an algorithm from terrain data (slope, water, soil, resources, existing buildings), with a seed for variety. The control panel shows it as an overlay, lets the owner approve or deny the whole plan or single items, and shows cost and time estimates.
- **[Proposed]** Approved items become jobs for NPC builders and use the same blueprint placement, leveling checks and material delivery as player building (Section 10.1).
- **[Proposed]** The engineer's skill and traits affect plan quality. The language model can explain a proposal in conversation, but placement and numbers come from the planner, following the rule that the game owns the facts.
- **[Proposed]** Planning runs in phases that each need approval: survey, district and wall plan, road plan and road building, then building lots. Each suggestion carries its reason ("flat, near the river, downwind of the tannery"), which the language model can phrase but the planner's numbers decide.
- **[Proposed]** The planner needs cheap terrain queries: slope, fertility, water access and resource proximity. Consider baking coarse land-suitability layers per region so the planner does not scan voxels at runtime. This has not been checked against the data the generator already produces.
- **[Open]** Whether plans can run unattended (for example auto-approval within a budget), how often the engineer proposes, and how plans account for existing player buildings and claims.
- **[Idea]** When the planner is told to build something, it orders workers to use supplies from the town warehouse. Wood can come from local mills or another town, stone from the town's own mines or elsewhere for fancy stone, and metal the same way.

### 8.5 Town roles and management

- **[Idea]** Players can party up with friends and give them rights in a town. A friend could be a town overseer with the right to hire, fire and manage NPCs.
- **[Idea]** Access comes in roles. Some people have full access. Others only oversee land sales, handle the guards and militia, manage tradespeople, approve road building, approve buildings and construction, or control the warehouse.
- **[Idea]** A town can have an NPC town manager with their own building. If there is no manager, the notices land on the owner's desk, because the owner is the town manager.
- **[Idea]** Later, a town can hire an AI trade manager with their own little building, who works with the warehouse, shippers and merchant NPCs to move goods. The player can visit to see their settings and history. At first this is done by hand.
- **[Proposed]** Rights are a list of named permissions, and roles are bundles of them. The owner has everything and can create custom roles.
- **[Proposed]** An action log records who approved, hired or sold what, which prevents arguments between friends.

### 8.6 Land and property

- **[Idea]** Before building a home in a town, a player buys a plot of land or a building that is for sale: a house or a business. Someone might buy the smithy to be the blacksmith, or own it and have an NPC run it.
- **[Idea]** Owners pay taxes on the lot or the business. If a player pays business taxes, it is in the town's interest to help them succeed.
- **[Idea]** A player can buy a farm outside the walls and build a house, barns, sheds and fields on their own property as they like.
- **[Idea]** A player can own several properties and build an empire over time: live on the farm, own the smithy and the bakery, with the spouse working one, a child or hireling running another, and children and hirelings working the farm.
- **[Idea]** A player might live in a town run by the server (if those exist later), in another player's town, or in their own.
- **[Decided]** Starter towns have houses and farmland for sale. A player who buys one can work the land and live on the starter island.
- **[Decided]** A home whose owner vacates is eventually deemed **abandoned** once enough time passes, and returns to the market.
- **[Decided]** (2026-10-14) A remarrying spouse can take over a ruined dynasty's property by paying the town its back taxes and bills (Section 6). If nobody does within the window, the town claims it.
- **[Decided]** (2026-10-14) A property owner who has gone long enough that their dynasty reverts to NPC (Section 6, duress) loses the property to the town: it appears on the town manager's screen and the town may claim the houses, businesses, farmland, mines and other resource sources. For a mine, the town pays for repairs before letting it collapse (Section 11.2).
- **[Open]** How long before a home counts as abandoned, whether the owner gets warnings, and what happens to belongings and stored goods.
- **[Decided]** (2026-10-13) Players can own houses, businesses and farmland in any town, several in one town or spread across towns, as long as each town accepts their reputation.
- **[Decided]** Players can also prospect their own land in the wilds and mark it with a **town stone** (to found a town, within the spacing rules in Section 8.1) or a **homestead stone** (a private holding).
- **[Decided]** Owning property in an enemy town is hard. Someone who owned property in two towns before they became enemies keeps it, but tensions can get weird and their loyalty, and so their reputation, may come into question in both.
- **[Decided]** (2026-10-13) A town is basically a group of friends, and the town owner sets its rules. Residents are already vetted because they are already in the town.
- **[Decided]** Buying into a town: players whose reputation with the town is at or above a score the owner sets are accepted automatically. Players below it must be approved, and meanwhile can stay at the inn.
- **[Decided]** Players below the score can earn their way in: work around town, adventures and quests for the town, and acts of kindness such as hunting and donating the food to the local temple or inn, ridding the area of bandits or goblins, or volunteering at the well or wherever help is needed. Once their reputation reaches the score they are accepted automatically.
- **[Decided]** The town owner can whitelist or blacklist players by **account**, not just by character name, so a banned player cannot come back as a new character.
- **[Proposed]** When two towns turn hostile, owners in both get a warning and a choice: keep both and accept the standing loss, or sell one.
- **[Decided]** (2026-10-14) Good deeds raise reputation mainly with the town that benefits, and a little with its allies once the news spreads. NPCs who witness or benefit from a deed remember it (Section 8.8).
- **[Decided]** Repeating the same deed counts for less each time, so reputation cannot be farmed (donating rabbits all day). The reduction cools down gradually, though: someone who keeps doing good deeds regularly over time, out of the goodness of their heart, earns a reputation as a good person rather than being penalized.
- **[Decided]** Roughly half of the reputation from a deed is permanent and half is temporary. The temporary half fades slowly (over about a week) as people forget, so reputation drifts down unless it is kept up.
- **[Decided]** (2026-10-14) Reputation timing uses in-game days.
- **[Decided]** Some deeds are never forgotten: epic quests, saving someone's life and the like. They become stories the village tells. The story starts with the person helped (whoever gave the quest, whoever was saved), who tells their closest friends; they tell theirs, and before long the whole town knows. Each teller passes it on through their own memory and honesty traits (Section 8.8), so the story changes a few times along the way, embellished, shrunk or muddled.
- **[Proposed]** A legendary deed is one story record (who, what, where, when, the facts) plus, per NPC who has heard it, their version: how strongly they remember it, which details they changed and who told them. Spreading follows each NPC's social ties, a step every so often in game time, with talkative and social NPCs passing it on faster. Reputation from such a deed is permanent and does not need the teller to remember the details right. Travelers and wagons carry it on to other towns through the news system (Section 13.6). When a player asks an NPC about it, the language model voices that NPC's version, so different villagers tell it differently.
- **[Proposed]** One way to do this: each kind of deed has a "recent count" that decays a little every day; a deed's value is divided by (1 + recent count), so a burst of the same deed quickly stops paying but the same deed once a day or so keeps paying almost full value. A steady habit over weeks (for example, a donation most days for a month) adds a lasting "known for good deeds" bonus. The temporary half of each gain fades linearly over seven in-game days; the numbers live in a tunable table.


### 8.7 Quests and pastimes

- **[Idea]** Quests are received by roleplaying with NPCs or by reading notices from NPCs on a bulletin board. A player looking for work might be told of an adventure, and if they agree, the AI brings in what is needed: a goblin camp, a bandit camp, a traveling merchant. Others can help.
- **[Idea]** Players can join a caravan as a sword for hire, hunt deer by pristine rivers, spend the day in their own mine or on their farm, or play the town manager handling rules and taxes like a Sims game.
- **[Idea]** Players can play simple board games with an AI NPC in the pub, or roleplay conversations with people there.
- **[Proposed]** Accepting a quest wakes one of the baked dormant lair sites (Section 4.4) instead of spawning a camp from nothing, so the world stays coherent, other players can find it, and the pacing director keeps it away from town gates.
- **[Proposed]** The quest itself (goal, reward, deadline) is structured data. The language model tells the story.
- **[Proposed]** A plain rules engine plays the board games and the model supplies the banter. Medieval games such as nine men's morris, hnefatafl and dice games add flavor. Wagering is part of the gambling topic flagged in Section 13.8.

### 8.8 NPC character, memory and conversation

To be fleshed out when the first NPC is designed.

- **[Decided]** NPCs are created with a randomly rolled background. The language model fills in the small details in between, and those details are saved for that character.
- **[Decided]** Memory works in a limited way, much like real people. Recent memories (who visited, what deals were made) are more detailed but not perfect, because people make mistakes. As memories age, say after a day or two, they get thinner and are often lost.
- **[Idea]** Some old memories stay, for example traumatic ones.
- **[Decided]** Memory quality is a score, so some NPCs remember a lot and others very little.
- **[Decided]** Honesty is a score. An honest NPC tries to tell the truth and admits uncertainty ("I am not sure about the date"). An NPC with low honesty flourishes and exaggerates.
- **[Decided]** Conversation traits are scores too, such as talkative, charismatic and social. Some NPCs talk your ear off, others constantly try to escape the conversation or are short with you.
- **[Proposed]** The rolled background (birthplace, family, trade, a few traits, one formative event) comes from data tables and is game-owned fact. The model's filled-in details are generated once, can be done in batches, and become the character's canon, so the NPC never contradicts itself.
- **[Proposed]** Each memory records what happened, who was involved, when, and how much it mattered. Strength fades with age (computed when the memory is read, per the lazy resolution principle). The memory score sets how fast memories fade, how often details are distorted, and how many the NPC keeps. Weak memories drop out or shrink to a one-line summary. Memories with a very high weight (trauma) fade very slowly or never, and can shape personality, so someone robbed on the north road stays wary of it.
- **[Proposed]** The model only sees the few strongest memories relevant to the conversation, which also bounds token use.
- **[Proposed]** Before the model speaks, the game builds a **statement plan** from memory strength and honesty: state plainly (honest, strong memory), hedge (honest, weak memory, so the doubt is real), embellish (low honesty; the game picks which detail grows: the amount, the danger, their own role), or lie (very low honesty). Distorted recall is also rolled by the game. The roll decides what is said and the model only phrases it.
- **[Proposed]** Real records stay exact. Money, debts and deals live in the ledger and obligations list, and only an NPC's recollection is fuzzy, so the record can contradict what a merchant remembers. Players can catch a liar by checking the ledger, a witness or a guard's memory. This ties into law, forgery and delayed discovery (Sections 9 and 13.5).
- **[Proposed]** What an NPC tells another becomes **hearsay** in the listener's memory, tagged with its source and that source's reliability, so rumors drift and grow as they spread through the news system (Section 13.6).
- **[Proposed]** Score effects: **memory** sets fading, distortion and capacity; **talkative** sets reply length, how much is volunteered and how long they stay in a conversation; **social** sets how many relationships they keep and how fast news passes through them (a chatty innkeeper is a gossip hub, making taverns good for rumors); **charisma** affects persuasion, prices, loans and how others feel about them. Vanity, fear, loyalty and the NPC's opinion of the player can feed the statement plan too.
- **[Proposed]** These traits fit the language model budget: quiet NPCs are cheap, and talkers get longer replies under a hard cap. Escaping a conversation is a game action with a cooldown (the NPC walks off or says they are busy), and the model only voices it.
- **[Proposed]** Roll mostly average people with a few standouts at the extremes, which feels more real than everyone being slightly random. Players learn who to ask: the gossip knows a lot but exaggerates, and the quiet clerk says little but remembers exactly.

### 8.9 Language service hosting

- **[Decided]** At first the game server and the language model host can be the same machine. Later the language host moves to its own machine.
- **[Idea]** Eventually a farm of language machines balances the load, deciding which machines handle which NPCs.
- **[Proposed]** Treat the language service as a separate component from the start, behind a simple request interface: the game server sends a job (this NPC, this situation, these facts, this priority) and gets text or a structured decision back later. Moving it to another machine is then a configuration change.
- **[Proposed]** The game server never waits on the language service. The game tick wins any contention for CPU while they share a machine. If the model runs on a GPU, the contention is much smaller.
- **[Proposed]** Workers hold no NPC state. The game server owns memory, traits, obligations and relationships, and each job carries the context it needs, so any worker can answer any job. A shared job queue balances the farm without assigning NPCs to machines. Inference servers such as vLLM already batch concurrent requests.
- **[Proposed]** Every job has a priority and an expiry. A player talking to an NPC outranks a background decision, and a job whose moment has passed is dropped or answered by rules.

### 8.10 Outposts and town satellites

- **[Idea]** A town on a good island has lots of land. Satellite outposts can be built on the hillsides of the mountainous island chains: a mine, a dock and an outpost master. Mines ship supplies back to the town. An outpost needs less room and can handle steeper slopes right next to the water.
- **[Proposed]** Measured on the first world sketch (`plan/buildable_summary.txt`): 36 islands have room for a town, but 289 have an outpost site (a foothold of at least 0.05 km² on slopes up to about 17 degrees at the shore, with water at least 8 m deep within about 500 m for a dock). 253 of those have no town site, so outposts are how most islands get used, and the volcanic chains in hard and deadly waters (134 outpost islands) become mining frontiers.
- **[Proposed]** An outpost is a business in the shared business structure (Section 13.4), owned by a town or player and run by an outpost master NPC. It claims a small plot (an outpost block with a much smaller radius than a town block) and links to its parent town's warehouse by a sea route. Ships run that route on a schedule (materialized only when seen, Section 3), carrying ore out and food, tools and wages in.
- **[Decided]** (2026-10-14) An outpost is claimed with an outpost marker, in the same way as a town marker (Section 8.17).
- **[Proposed]** Outpost blueprints are built for slopes: terraces, stilts, stairs and a jetty, so the blueprint leveling check (Section 10.1) allows steeper ground for them than for town buildings.
- **[Proposed]** Danger matters: outposts in hard and deadly waters need a palisade and guards paid by the parent town, and are natural targets for raids, pirates and sea creatures, which ties into threats and pacing (Section 12). Losing an outpost cuts a supply line rather than ending a town.
- **[Proposed]** Volcanic islands drop steeply into deep water, which makes them good for docks. The geology already favors them for ore: copper and gold on arcs, sulfur and gems on hotspot volcanoes (Section 4.9). When ore bodies are placed at bake time, some should sit near outpost-friendly coves so mines and docks pair naturally.
- **[Proposed]** The generator does not need to bake outpost sites: they can be found at runtime from the tile maps (slope, height, shoreline, water depth), the same way the town planner surveys land. Natural harbors and coves can still be marked as sites at bake time.

### 8.11 The temple

- **[Decided]** Every town can have a temple. It is non-denominational (no real-world religion) and built entirely on the principle "be safe, be kind, be generous" (Section 3).
- **[Decided]** The temple is the centre of kindness in a town. It is where a person goes for help: healing, food, shelter, and protection. It demands nothing from anyone. Donations are always welcome and improve the donor's reputation.
- **[Decided]** Players can simply talk with the clergy, like a counsellor, about philosophy and meaning. The teaching encourages: recognizing your inner voice, questioning why you think as you do, reflecting, self-help, self-worth, being useful to your community and helping neighbours, and being good to yourself in times of need.
- **[Decided]** The clergy are the most neutral religious experience possible. They are pleasant, but they are human and can have a bad day, while still doing their best.
- **[Decided]** The temple handles adoption (Section 6.9), takes in the displaced (Section 8.3) and receives donated food and goods.
- **[Proposed]** The clergy use the same NPC character, memory and conversation systems as other NPCs (Section 8.8). The conversation budget (Section 3) applies.
- **[Open]** Whether a temple is built by the town, by players, or both, what it costs, and how many a town can have.

### 8.12 Town spirit and local weather


- **[Idea]** Each town has a score for how well it is doing. Working name: **town spirit**. It rises when the town is helped: pests and bandits cleared, sickness cured, medicine brought in or made, the hungry fed, a temple built. It falls when the town is plagued by vermin, goblins, bandits, sickness, blight or hunger.
- **[Idea]** The score shapes local weather. A low-spirit town has thunderstorms, showers, sweltering heat and bitter cold. A high-spirit town has moderate weather with the right rain for crops, the right sun, and gentle breezes that keep windmills turning, plus butterflies and animals at play.
- **[Idea]** A low score also acts like a depression on the people: it lowers NPC and player moods.
- **[Proposed]** Weather stays deterministic and free of network traffic (Section 4). The score is one small number per town, sent to clients as part of the town's data, and each client adds it to the weather it already computes from the seed and clock.
- **[Proposed]** Weather near a town border blends smoothly between towns and open country, so there are no walls of rain.
- **[Proposed]** Safety valve, following "safe, kind, generous": a very low score must not trap people in a death spiral. Harsh weather is capped short of making farming impossible, and the worst towns get more help (the temple, rescue quests, outside aid) and not more punishment.
- **[Decided]** Climate (position north to south) sets a base harshness and the range of weather that is possible (a desert town never gets tropical rain), and town spirit modifies that base, moving the weather between harsher and gentler inside the range. Spirit does not decide the climate itself.
- **[Decided]** Spirit also affects people. Every NPC in a high-spirit town has a high spirit of their own, and one in a low-spirit town has a low one. It changes how they respond and react.
- **[Decided]** If the weather is too bad to grow crops, the town buys food from other towns. The starter towns' administrative warehouse (Section 8.1) always supplies the bare minimum of food and necessities for a price, so a town can live on mining and manufacturing money while its farms recover.
- **[Decided]** Spirit rises fast with good deeds and improvements and falls slowly. A new building, a new resident, a donation, a hunt delivered to the temple or inn, or a finished quest each add about 10 points. Each day with nobody doing anything takes about 1 point off. The decay clock is real days (see the Proposed note below).
- **[Proposed]** The decay clock is real days, not game days. A game day is one real hour (Section 7.5), so one point per game day would be 24 points per real day and erase a 10-point deed in about 10 real hours, which does not suit a weekly player. One point per real day lets a deed last about 10 days.
- **[Proposed]** Spirit sits on a fixed scale (for example 0 to 100) and decays toward a floor set by permanent things like a temple, no pests, and clean water, not toward zero.
- **[Decided]** NPC deeds count only a little toward spirit. They can barely maintain it, and a random event that pulls spirit down (bandits attacking caravans, for example) outweighs what the NPCs add. NPCs alone can never keep spirit high. Without real people playing in the town (quests, farming, donations, building), spirit slowly falls.
- **[Decided]** Permanent features raise the floor spirit can fall to: a temple, clean water, a town wall and a strong town guard. NPC upkeep of these can slow the fall, since they keep adding a little.
- **[Open]** The name of the score, the scale, the sizes of each deed, how far its weather reaches around the town, and how it interacts with crop yields and with mood details.

### 8.13 Town decline, ruin and deletion

**Decline of a server-owned town**

- **[Decided]** A town that stays server-owned loses spirit gradually and loses money, because it keeps paying for food and upkeep. When the money runs out the town falls into decay.
- **[Decided]** Once decay reaches a certain stage, every building slowly falls down. NPCs die off, move to other towns, join bandit camps, become bandits, or find work elsewhere.
- **[Decided]** Value drops as buildings decay and people leave. At the last moment of a town's life there is nothing but ruins and a town manager who has not yet left. A player can then buy the town for pennies on the dollar.
- **[Decided]** A new owner pays to hire the town manager and new builders, chooses the order of the rebuild and approves each rebuild. The blueprints and the dilapidated buildings are still in place.

**Flagging for deletion**

- **[Decided]** Flagging for deletion happens when nobody bought the town from its manager. At that moment the town manager leaves his post and the town's ledgers and ownership are gone.
- **[Decided]** An administrator can flag an abandoned town for deletion, and the server administrators vote. A flagged town is not removed. Its buildings keep degrading at the regular speed, looking more worn and dilapidated until each collapses into rubble. Players can walk through a collapsing town and see that one used to be here.
- **[Decided]** The manager becomes an ordinary NPC, available for others to hire. He keeps his skills and whatever money he held, and he lives on it until he finds work or falls into poverty over time.
- **[Decided]** The town marker stays, and so does the town's office building (dilapidated, like the rest). The marker is the centre of the town, and the town's circle of influence spreads from it. What is left is the marker, the office, roads and rubble.
- **[Decided]** The office keeps the town's blueprints and its history: which buildings it had, its peak income, its farming and trade, its name and its previous owners.

**Degradation and rubble**

- **[Decided]** Nothing disappears outright. Degradation takes some material away from each building (see below) and the rest falls into rubble that stays until someone harvests it.
- **[Decided]** The pile is called **rubble**. It is an item with models, and it is a chunk of the world.
- **[Decided]** Every building has a bill of materials from its blueprint. As it ages without care it slowly loses material (hinges break, nails rust and weaken, untreated wood suffers sun rot). When it collapses, the rubble holds its bill of materials minus what degradation took.
- **[Decided]** Degradation is partial. Wood loses at most about 50 percent, not all of it. Stone loses nothing. Metal loses some. Example: a blueprint of 1000 stone, 2000 wood, 100 iron and 200 slate leaves roughly 1000 stone, about 1000 wood, most of the iron and all of the slate.
- **[Decided]** Rubble is a salvage source. A player who reclaims a town can harvest the rubble for most of the rebuild materials without cutting thousands of trees.
- **[Idea]** Salvage as a trade: businesses that go around clearing rubble from ruined towns and selling or reusing the materials. Harvested rubble is gone, and the harvester gets the contents minus degradation.
- **[Idea]** Wood left in rubble could count as aged wood (and in some places petrified wood), a different material from fresh wood with its own uses and quality. Treated, maintained wood degrades much more slowly.
- **[Idea]** Iron in rubble could slowly rust over a long time, giving less usable metal, while stone never changes. This is only a flavor idea and is left open.
- **[Proposed]** Rubble is stored as a pile of counted materials, not as individual pieces, so large ruined towns stay cheap to store and to draw on the minimum machine. Harvesting reduces the counts.

**Roads**

- **[Decided]** Roads barely degrade (perhaps by a percentage) and never fully disappear. Buildings fall down and become rubble. Nothing erases itself completely.
- **[Decided]** Roads have visible condition. In a maintained town a road looks pristine, with no grass growing through it. A road in disrepair looks different (grass, mud, ruts).
- **[Decided]** Road condition has effects. A road in good repair lets you travel faster. A road in disrepair is muddier: it slows travel and makes travelers dirtier.
- **[Proposed]** Road maintenance is paid by the town, so road condition follows the town's money and spirit. A road between towns could be maintained by whichever town owns the stretch, or by tolls (Section 13).

**Claiming an abandoned town**

- **[Decided]** Anyone can open an abandoned town's office without claiming it and read that history before deciding.
- **[Decided]** Anyone can claim an abandoned town by taking over its marker, and claiming costs nothing. Nothing stops a claim.
- **[Decided]** A claimant uses blueprint mode to see every building of the old town as an outline, with what it was and the materials it needs. The rubble beneath each outline holds most of those materials. The owner harvests rubble piles and puts the materials into a blueprint, which rebuilds that building.
- **[Decided]** The owner can hire a town manager, builders and guards when affordable, or cut trees and build alone or with friends, or turn the place into a small farming community until they can afford a manager. All of these paths are open.
- **[Proposed]** The rebuild order is the owner's choice. A natural order is the town hall, then the temple and the well (which also raise the spirit floor, Section 8.12), then guards and the rest.
- **[Decided]** No limit or cooldown on claiming abandoned blocks. Travel by foot, horse and ship is slow, so the distance itself is the limit.

**Open**

- **[Open]** How many road condition levels exist, how dirt and cleanliness work for characters, and who owns and repairs roads between towns.
- **[Open]** How an abandoned block's circle of influence interacts with a new town block placed nearby, and whether a claimed town starts with the old spirit or a fresh low one.
- **[Open]** How long each stage lasts, what the decay stages are called, the thresholds that trigger collapse, how many administrators must vote, and what happens to a town's records when it is deleted.

### 8.14 Contesting a town claim

- **[Decided]** A town must have real things in it to be feasible. Someone who claims several towns and travels away needs managers and guards to hold each one.
- **[Decided]** Anyone can make an offer to buy any town at any time by talking to its town manager. The manager sends a notification to the owner that an offer has been made, with a recommendation: for example, whether it is in good faith and what the manager thinks the town could fetch in currency or resources.
- **[Decided]** The owner accepts, negotiates or declines. An accepted offer transfers the town at once. A good offer also gives owners a way to retire wealthy.
- **[Decided]** A town that is not yet established (Section 8.15) can be taken over by hostile means. If the owner declines an offer, the challenger can apply for a hostile takeover. The owner must get back to the town's circle of influence before the window ends to stop it, and the whole process then starts over.
- **[Decided]** The window depends on how developed the town is: a bare town block about 2 hours, and with a town manager about 4 hours.
- **[Decided]** An established town cannot be taken over hostilely. Offers can still be made, and the owner is free to refuse.
- **[Decided]** When a hostile takeover succeeds, the challenger pays the previous owner a fixed amount based on the town's value (or its rubble if it is a ruin).
- **[Decided]** A town that does nothing productive but still has a manager, clean water, a temple and guards is an expense on the owner's other towns or dynasty, so hoarding idle towns costs money.
- **[Superseded]** An earlier version had windows of about 24 hours for a town with a manager and guards and about 48 hours with a wall. Established towns are now fully protected, so those windows are no longer needed.
- **[Decided]** "Established" is what protects a town, not one hired guard (see Section 8.15 for what it includes). Guards who go unpaid leave, which removes the protection and ties it to the town's money.
- **[Proposed]** The windows are in real time. How the owner hears of an offer or a challenge depends on whether the town has a manager (Section 8.15).
- **[Open]** The minimum guard level, whether walls add anything now (for example a longer window for towns that are not yet fully guarded), and what happens to buildings, NPCs and debts when the owner changes.

### 8.15 Managers, remote control, word and safe towns

- **[Decided]** A town with no manager has nobody to deliver word to the owner. There is no notification. If the owner is in the area, a visitor can see that and make an offer at the block. If the owner is away, a challenger simply puts in a claim, and if the owner does not return within the window (about 2 hours for a bare block), the challenger gets the town.
- **[Decided]** The town stays on the former owner's ledger until the next time they visit it, because they still believe they own it. On arrival they find it is owned by someone else, and it drops from the ledger.
- **[Decided]** This is a deliberate exception to the legibility principle (Section 3): not knowing about a loss until you return is part of the cost of leaving a town unmanaged. A town with a manager has no such gap, since the manager sends word.
- **[Decided]** Without a manager, the owner must be physically at the town's office to change anything, give commands or read the town's books and interface.
- **[Decided]** With a manager, the owner can control the town remotely through the manager, and the manager makes certain decisions while the owner is away. The owner sets which decisions the manager may make.
- **[Decided]** The manager makes two kinds of decisions: ones he can make automatically, and ones where he must request approval or give the owner options to choose from.
- **[Decided]** A town is unsafe, a gray area, until it has established its basics: guards, fresh water from a well, a temple and probably walls. Once established it is a PVE area.
- **[Decided]** In a PVE area people can make offers and visit, but they cannot hurt anything. Nobody can raise an army and attack the town. Players who cross into a PVE area can no longer attack anyone.
- **[Idea]** Later, designated parts of the map can be PVP areas. Players who build a town there and want warfare are welcome to, and the PVE protections do not apply.
- **[Proposed]** Word delivery uses a message system with distance delay and a carrier type (courier on horseback, pigeon, ship, later enchanted pigeon). Pigeons and couriers can fail or be intercepted. A manager can send word to the owner this way. This is separate from the real-world email notifications for the player's account (Section 6), which exist for duress and receivership.
- **[Decided]** In an established town, word can travel by carrier pigeon or by magic (this is a fantasy game). A town can have a pigeon tower or a wizard tower, run by the pigeon master or the town mage (see the tiers below). A message goes to the nearest tower or mage, then onward to the recipient.
- **[Decided]** Delay depends on distance: how long a pigeon flies, or how long magic takes to reach the nearest mage or tower and then the recipient.
- **[Decided]** Matters of the whole dynasty use real-time messaging in the app. In-world mail and delay cover town business at a distance, such as an offer on a town.
- **[Decided]** When someone makes an offer on a remotely controlled town, the owner is told that they will be notified in a stated number of hours or days, based on the delay for word to arrive. The offer then stands for a time.
- **[Decided]** How long an offer stands is the offerer's choice: a set period (for example a week) or a permanent standing offer. The time between offer and answer is expected, because communication takes time.
- **[Proposed]** A standing offer does not lock the offerer's money. Funds are checked when the owner accepts, and an offer that cannot be paid fails with a reputation cost. A short offer could instead hold the money in escrow.
- **[Decided]** Communication improves in tiers, in line with the early-to-late quality ladder (Section 11.1):
  1. Early: a rider on horseback, or a message carried by ship. Slow, and it can fail or be delayed.
  2. Next: a **pigeon master** with coops, a building and a business. Faster over the local region.
  3. Later: a **wizard tower** with a town wizard (also called the town mage or high mage). Enchanted pigeons work with ordinary pigeon masters and coops but fly much faster, about 10 to 100 times the speed of a normal pigeon (the exact figure is to be tuned). The recipient can write a reply and send it back on the same pigeon, which then returns. This replaces the earlier idea of teleporting.
- **[Decided]** The role names are pigeon master for the coops and town mage (or high mage) for the wizard tower.
- **[Idea]** The wizard handles many roles, not just mail: solving problems around the town, defence of the town (a magical shielding dome, fighting from the ramparts during goblin or bandit attacks or a hill giant coming to ravage the town), and day-to-day research that improves the town's technology and its communication with neighbours.
- **[Open]** What a wizard tower costs, what the wizard's research actually unlocks, how strong the defence is against each threat, and the limits that keep one wizard from solving everything (for example a cost, a cool-down, or a single point of failure if the wizard is lost or hostile).
- **[Open]** The cost of sending word, whether a standing offer needs a refresh or can be cancelled any time, and the delay formula.
- **[Open]** Whether real-world app alerts also cover town challenges, what "established" requires exactly, what the manager can decide automatically, and where PVP areas are on the map.

### 8.16 Buying a server-owned town

- **[Decided]** Town spirit works like duress for a town. If a town owner's dynasty falls into receivership, the town is part of what can be taken over. If nobody takes it, it reverts to the server and an administrator owns it.
- **[Decided]** A server-owned town goes on a list that players can apply to buy. The price depends on the town's size, its population, its wealth and how long it has been without an owner. It is treated like a normal business: the buyer inherits a low-spirit town and also gets its potential for great wealth.
- **[Decided]** The exact price formula is worked out later, from the town's real value and its earning potential.
- **[Decided]** A town's price falls the longer it stays server-owned, because its value falls as money runs out, buildings decay and people leave (Section 8.13).
- **[Decided]** To apply, a buyer goes to the nearest town (which can be the town itself) and talks to the town manager, an NPC at this stage. The manager talks about the town's problems and says it is available if someone good enough can be found. The buyer negotiates with the manager. If the language model judges the negotiation to be in good faith, they reach an agreement. This must happen before the town falls apart.

- **[Open]** The price formula, how competing applicants are handled, and what the manager's good-faith judgment looks at.

### 8.17 Town marker, territory and outposts

- **[Decided]** (2026-10-14) The town block is a marker with no physical form: a floating arrow only the owner can see, which the owner can switch on and off. It adds an entry to the owner's ledger saying they own a claim. It marks the exact centre of the town.
- **[Decided]** Until an office building is placed (a keep or castle with an office, a house with an office, a town hall or a magistrate's office), the owner cannot reach the town settings. The building is where the town manager lives and works.
- **[Decided]** (2026-10-14) **Towns cannot overlap, so the land is reserved up front.** Settlements come in sizes (hamlet, village, town, city). A list gives the physical size of each, and the largest, a city, is the maximum a town can grow to. Placing a town marker reserves land from the marker out to the size of a maximum city, so nobody can place a marker anywhere that its own maximum city would overlap another town's. The aim is that one person can build a town into a giant city with a castle, thriving businesses and a guild of a thousand real players.
- **[Proposed]** The minimum distance between two markers is then twice the maximum city radius R. The settlement ladder below puts R at 1.5 km.
- **[Proposed]** (2026-10-14) **The settlement ladder.** A new claim is a **settlement**. Each paid expansion grows it by 50 percent in radius (or 25 percent for a smaller step), and the size names follow. Radius includes the surrounding farmland, since the circle runs out to the farms.

| Stage | Radius | Area | Rough population (NPCs and players) |
|---|---|---|---|
| Settlement (a new claim) | 200 m | 0.13 km² | up to 25 |
| Hamlet | 300 m | 0.28 km² | 25 to 100 |
| Village | 450 m | 0.64 km² | 100 to 400 |
| Town | 675 m | 1.4 km² | 400 to 1,500 |
| City | 1,000 m | 3.1 km² | 1,500 to 5,000 |
| Metropolis (the maximum) | 1,500 m | 7.1 km² | 5,000 to 15,000 |

- **[Proposed]** The reservation (above) is a metropolis: radius 1,500 m, so two markers must be at least 3 km apart, and every marker reserves about 7 km² even while it is still a settlement. A 50 km² starter landmass then holds roughly 5 to 7 towns, and a 100 km² landmass roughly 12.
- **[Proposed]** Moving up a stage needs the paid expansion plus a floor of buildings and population, so a stage name means something. The "established" status (Section 8.15) is reached at around the hamlet or village stage.
- **[Proposed]** Population figures are guides, not caps. The NPC population cap per island and region (Section 8.2) and the language model budget (Section 3) limit the NPC share. The player share of a metropolis is the thousand-strong guild case.
- **[Proposed]** An outpost has a fixed small radius, about 100 m, and reserves only that.

- **[Decided]** A town has a **circle of influence** around its marker.
- **[Idea]** The planner prefers rings, working outward from the centre:
  1. The core: the keep or castle, the main storage and warehouse, the guards, and extra storage and housing that can take people in during a defence.
  2. Businesses and tradespeople: the blacksmith, merchants, sales stalls and inns.
  3. The waterfront, on the side with water: the harbour and port with bars, shanties, shipping businesses and agents. On the landward sides this ring holds small farms or more storage.
  4. Beyond that, farmland.
- **[Decided]** An **outpost** is claimed with an outpost marker, like a town marker. The owner can then put buildings on it and hire a manager. The kind of building decides the kind of manager and outpost: a mine manager, or a lumber mill with a master who runs a few NPCs who cut wood, bring it in, process it and ship it to the town.
- **[Decided]** Outposts and towns exchange goods by NPC travel, and that travel makes roads. The NPCs path-find by least resistance, so the first road between an outpost and its town is a rough dirt road formed by the travel itself. This is a system to build in.
- **[Decided]** When a route needs a bridge, the NPCs tell the town builder, who arranges builders and decides where the road and the bridge go.
- **[Idea]** Bridges use bridge blueprints, or a special dynamic bridge blueprint that fits the gap.
- **[Idea]** Cheaper crossings: shallow fords that horses can walk through, or a causeway across shallows with pipes or culverts for the water.
- **[Open]** The default radius, the cost and the limits of expansion, whether the rings are fixed rules or only planner preferences, the maximum span and water depth of a bridge, the kinds of bridge (rope, timber, stone), who maintains roads formed by travel, and how an abandoned marker is seen and claimed by other players.

---

## 9. Law, crime and recognition

### 9.0 PvE and PvP

- **[Decided]** The starter areas are definitely PvE (no player-versus-player combat).
- **[Open]** How PvP is offered later for players who want it: flagged players, dangerous regions only, war between towns, or a mix (question 57).

### 9.1 Soft law

- **[Decided]** No hard permission locks. A player can physically take crops they do not own. If the owner gave permission nobody objects. If not, the player hopes nobody sees.
- **[Decided]** A victim can report a theft and the town starts an investigation.
- **[Decided]** If a player sells stolen goods to an NPC who suspects they are illegal, a warrant can be issued and the player is no longer safe in that town.
- **[Proposed]** The server records ownership on everything and logs events: who did what, to what, when, where, and who saw it. Items carry provenance (who they came from).
- **[Proposed]** NPC reactions depend on traits. A lawful NPC reports, a low-lawfulness NPC may buy and say nothing.
- **[Proposed]** Warrants belong to a town's jurisdiction and spread through the news system (Section 13.6) with delay.
- **[Proposed]** NPC conclusions come only from recorded events, never from what a player claims in chat.
- **[Proposed]** Event logs need a retention rule so old minor events are summarized or dropped.
- **[Proposed]** A third outline or warning state for placement and actions: allowed but illegal or risky.
- **[Open]** Whether locks and security are soft barriers (skill versus lock strength) or absent.

### 9.2 Crime memory and delayed discovery

- **[Decided]** Crimes are mostly remembered by NPCs. Guards remember more about recent crimes. As crimes get older they fade from memory, unless something is stupidly obvious, such as riding into town on horses stolen from there years ago.
- **[Decided]** Delayed discovery can happen after many kinds of events. A thief who sneaks into a business at night without alerting the guard, steals money and equipment and travels far away can still be caught in the distant future, when someone recognizes the stolen gear and the blacksmith's mark. The thief's options include selling the gear to a merchant who cannot remember who sold it to them.
- **[Decided]** People can put on disguises.
- **[Proposed]** Delayed discovery needs no feature of its own. It falls out of three parts: individual items with identity and ownership history, NPC memory that fades, and news that travels slowly.
- **[Proposed]** Recognition is checked only when an NPC meets a person or item tied to a crime (a sighting, a purchase, a gate check), not by scanning the world. The chance depends on how strong the memory still is, how strong the cue is (a branded horse in its home town is a strong cue, an ordinary sword a weak one), and the NPC's skill and traits. A strong cue can beat a faded memory.
- **[Proposed]** Crime severity slows memory fading. A murder is remembered much longer than a stolen loaf.
- **[Proposed]** Guards work from an **active wanted list** of recent and serious cases. Older cases drop off it but stay in the town's archive, so an investigator can reopen a **cold case**, which is a ready-made quest.
- **[Proposed]** Characters have a few recognizable features (face, build, hair, clothing, distinctive items). A disguise changes some but not all: clothes and hair are easy to change, height and build are not. Quality depends on disguise skill and materials, rolled on the server. Being caught in disguise can count against the wearer.
- **[Proposed]** Aging works against recognition, since a criminal twenty years older is harder to spot.
- **[Proposed]** Give the player a partial clue in the moment ("that mark looks familiar") so a later arrest feels earned.
- **[Proposed]** Stealth detection (sneaking in at night) uses a server-rolled model based on stealth skill, light, noise and guard alertness. That is a separate design for later.
- **[Open]** How far justice spreads. The news system is the proposed mechanism, but no limits were discussed.

---

## 10. Building, blueprints and fire

### 10.1 Building and blueprints

- **[Decided]** Building is **piece by piece**. Terrain digging and leveling are voxel edits.
- **[Decided]** Players can save blueprints from their creations and share them, building a collection of building types. Competitions let the community design and vote on favorites.
- **[Idea]** Blueprints are shared through Steam downloads, like Space Engineers does for ships.
- **[Decided]** Placing a blueprint automatically levels the immediate land under it.
- **[Decided]** A preview outline is red until the terrain is within a reasonable shape to be auto-leveled. Leveling is assumed free and instant once the outline is green.
- **[Proposed]** The client draws the preview for responsiveness. The server re-validates on placement.
- **[Proposed]** The outline explains why it is red.
- **[Proposed]** Blueprints are validated by the server (piece limits, valid pieces) and need moderation tools for shared content.
- **[Proposed]** Blueprint pieces can name roles ("roof") so players can substitute local materials.
- **[Proposed]** Per-building piece budgets and batched drawing protect older machines.
- **[Proposed]** Terraform edits are stored as compact instructions ("flatten this footprint to height H") and periodically folded into region snapshots.
- **[Open]** Whether the world has a single server library of blueprints or a Steam Workshop one, which depends on **[Open]** whether Steam is the release target.
- **[Open]** Whether blueprints are paid for all at once or built in stages with delivered materials (which makes NPC builders a natural job).

### 10.2 Fire

- **[Decided]** Building fires look and behave as realistically as in Valheim and can spread to other buildings.
- **[Decided]** This gives players reasons to build wider roads and use better materials.
- **[Decided]** Materials matter per piece. A wooden building with a stone slate roof will not catch fire from a neighbor's embers. A straw roof is much more likely to ignite.
- **[Decided]** If a roof catches fire, the fire spreads into the structure and burns the whole place down, unless the structure is mostly stone or the wood has been treated.
- **[Decided]** Fire treatment on wood is **permanent**. It never wears off.
- **[Decided]** People inside a burning building burn with it, including logged-out characters.
- **[Proposed]** Each piece has a type (wall, roof, floor) and a material with a flammability value. Neighbor fire and embers threaten the exposed piece. A fire started inside is not stopped by a stone roof.
- **[Proposed]** Ingredients for treatment already exist in the world data: limestone (lime), clay and gypsum.
- **[Proposed]** Burnt stone buildings remain as ruined shells that can be rebuilt.
- **[Proposed]** Fine-grained piece-by-piece fire where players are present, and building-level outcomes elsewhere, using the same rules. The server holds authoritative fire state and clients only draw flames.
- **[Proposed]** Fire effects are a quality setting and capped on older machines.
- **[Proposed]** Town building codes, fire brigades (an NPC job) and wells fit into the town block rules. Dry, hot climates burn easier.
- **[Proposed]** A shared material catalog for building pieces (flammability, strength, source of raw material) read by fire, repair, shelter and trade.
- **[Open]** Whether treatment is a crafted material (treated planks) or an upgrade applied to placed pieces.
- **[Open]** Whether weather and wind affect fire.
- **[Open]** Who fights fires: players, NPC brigades, or both.

---

## 11. Production and logistics

### 11.1 Tools, machines and automation

- **[Decided]** Eventually, players use materials to build components and tools that help them mine or climb mountains.
- **[Decided]** (2026-10-14) **Quality tiers for items.** Tools, weapons, cookware, crucibles and similar items come in material tiers, and a lower tier still works but does the job worse, which gives the game stages: crude stone and wood, bronze, iron, then steel, as in the Bronze Age and Iron Age. Examples: clay crucibles then graphite crucibles; iron tools then steel tools; unhardened then hardened edges (quenching and tempering).
- **[Proposed]** Each tier trades off a few numbers set in the item tables: durability (how soon it breaks and how fast it wears), effectiveness (the tool-power-versus-hardness rule below, damage for weapons, the heat a crucible or cookpot survives, the yield of a smelt), and sometimes weight, repair cost or how often it fails under load. Better tiers need better materials and know-how (fuel, furnaces, a skilled smith, a recipe discovered or learned), so a new player starts in the low tiers and moving up is progress. Worn items are repaired, resharpened or melted down for part of their metal, so low tiers stay useful and the economy keeps demand for them.
- **[Open]** How many tiers and which materials, whether a smith's skill adds a quality bonus within a tier, and how recipes are discovered (for example the lucky graphite crucible).
- **[Idea]** Railways, and machinery that moves materials out of mines up to the surface: minecarts, steam-powered engines, windmills.
- **[Proposed]** A progression from the existing resources (copper, tin and iron for tools, coal for steam), tied to the tool-power-versus-hardness rule so each step unlocks harder rock and deeper mining.
- **[Proposed]** Machines are building pieces with inputs, outputs and a rate, listed in a recipe table.
- **[Proposed]** Water wheels take power from the river flow the generator already computes, and windmills from the climate layer's wind.
- **[Proposed]** Production chains are computed as rates from timestamps, not by moving every item all the time. The visible carts and moving ore exist only near a player.

### 11.2 The mine chain

- **[Idea]** Villagers work in the mine during work hours, mining ore and filling the ore receptacle. Machinery gradually moves it up to the surface in an assembly-line way. Other villagers load it on wagons and move it to town, where craftspeople buy it to make tools, weapons, hinges and building parts.
- **[Proposed]** Output depends on the miners' skill, their tools and the ore richness. The depth heat limit applies to miners, so deep mines need ventilation stations and staff.
- **[Proposed]** Tracks and roads use the same leveling rules as blueprints.
- **[Decided]** (2026-10-14) Mines and caves can become unstable. A natural cave stays up as long as its openings are small enough; the bigger a man-made opening, the more it needs support. Miners must shore up their workings with timbers or pillars, and supports slowly wear and need maintenance. This is a deliberate difference from games where players can dig out huge spaces for free.
- **[Decided]** If a mine lies inside a town block or an outpost block, its support maintenance falls under the town's repair schedule. Builders do not have to be physically present: the supports age and are repaired automatically on the town's schedule, and the cost comes out of the mine owner's account.
- **[Decided]** If the owner stops playing for a set time (say three or six months) or their account runs out of in-game money, repairs stop and the supports gradually fail until the mine **caves in**. A cave-in only refills the workings with rubble. The land above does not sink.
- **[Proposed]** What the collapse does not do: it does not bring ore back (the tonnage taken stays taken), and rubble can be dug out again, so an abandoned mine can be reclaimed at the cost of clearing and re-shoring it. The server tracks each mine's support health as a few numbers (opening size, supports installed, last repaired, owner funded or not) and resolves wear and collapse lazily from timestamps, like regrowth, so it works while nobody is nearby.
- **[Decided]** (2026-10-14) When a player's mine does collapse (or is left to), it slowly reverts to its natural state: erosion and water filling it in. A ruin is left on the surface, such as a collapsed entrance, old timbers and spoil heaps, so other players can tell there used to be a mine there. That is a hint that resources may be nearby, though the ore taken is still gone. The ruins fade as the mine fills in.
- **[Decided]** Mines of dynasties that revert to NPC go to the town to claim (Section 8.6); the town pays for the repairs before allowing a cave-in.
- **[Open]** The abandonment time (three or six months, now tied to the duress timeline in Section 6), how big an opening needs supports, what kinds of supports there are (timber, stone pillars, masonry arches, later iron), whether a collapse can trap or injure miners inside, and whether natural caves can ever collapse after players dig them wider.

### 11.3 Life in the world

- **[Decided]** Moving carts and NPCs add life to the world, so they should be real, visible things and not just numbers.
- **[Proposed]** Close up: fully animated NPCs, carts and machinery. Medium and far: simple shapes and basic motion (a wagon train crawling along a distant road, smoke from a mine). Beyond sight: schedule only. Distances and counts are graphics settings, so older machines can reduce them.
- **[Proposed]** Valheim-style simple models make large numbers of distant moving things cheap to draw.

### 11.4 Open questions

- **[Open]** How NPC miners dig: physically carving tunnels (many terrain edits to store) or drawing down a deposit's remaining ore as a number and extending tunnels in stages (much cheaper). Ore bodies now have permanent IDs and tonnages (step 11), so the second option is possible.
- **[Decided]** Ore deposits are finite and do not renew. Living resources renew and some river and surface deposits renew slowly (Section 5).
- **[Open]** How big automation gets: a handful of linked machines per town, or Satisfactory-scale factories.
- **[Open]** How far away simplified distant life should appear, for example whether players see it across valleys or only when closer.

---

## 12. Threats and pacing

### 12.1 Road danger

- **[Decided]** Danger on the roads (bandits, goblins and other threats) is part of the driving force behind paying for guards and building towns for safety.
- **[Decided]** Wagons should generally travel hassle-free. Trouble happens when a bandit camp or goblin horde has moved into the area, or when an NPC has gone rogue.
- **[Decided]** Eventually a threats system will pinpoint natural bandit camp places. Premade goblin camps can also be dropped in like a blueprint, creating a small cave system filled with goblins (Section 4.4).
- **[Proposed]** A wagon trip has a danger level based on its route. If nobody is watching, the server rolls an encounter and resolves it with numbers (escort strength against threat strength). If a player is near, the ambush plays out for real, using the same odds.
- **[Proposed]** Danger comes from lairs and camps (the baked dormant sites occupied by hordes or by bandit groups formed from displaced NPCs), from low guard coverage, and from terrain and distance. Clearing a lair lowers danger until it slowly repopulates.
- **[Proposed]** The bake cannot know where roads will be, so it supplies generic dormant sites and the server chooses which to occupy based on where traffic flows and where guard coverage is weak. Threats follow trade.
- **[Proposed]** An NPC who is poor, low in lawfulness, wronged or in debt, with a grudge in memory, is a natural candidate to go rogue.
- **[Proposed]** Warnings come first as news: NPC gossip, notice boards, quests to clear the camp. The server decides the facts and the language model voices them.

### 12.2 Pacing and patrols

- **[Decided]** Something paces the threats, and NPC behavior also matters. If a town becomes too safe and guards stop patrolling the roads, bandits may eventually start attacking again.
- **[Idea]** Militia patrolling the countryside is important. If the militia budget is reduced, the chances of bad events go up.
- **[Proposed]** Two layers: a server-side **director** sets the overall pace (cooldowns between crises, a ceiling on active crises per region, scaling with player count), and NPC behavior and town choices decide where and why events occur within those limits.
- **[Proposed]** Each area has **pressure** (how much trouble the land produces, building slowly from desperate NPCs, wandering monsters and unclaimed lairs) and **coverage** (how well guards hold it down). When coverage stays low long enough an event fires.
- **[Proposed]** The budget loop is emergent: cutting wages drives guards out, and bitter ex-guards are exactly the NPCs who turn bandit.
- **[Proposed]** The town block shows a coverage and risk overlay on the roads and the estimated effect of the budget slider, so an attack after a budget cut feels earned.
- **[Proposed]** Danger tuning is a few adjustable numbers. Too deadly collapses trade, too safe makes guards pointless.
- **[Proposed]** Threat pressure must not be able to wipe out an absent player's supply chain in one night.
- **[Open]** Whether threats are fixed lairs that respawn slowly, roaming groups, or both.
- **[Proposed]** Displaced NPCs may become bandits or join camps (Sections 8.3 and 8.13). Whether a ruin itself becomes a stronghold is left to the threats system.
- **[Decided]** A failing town can recover: spirit rises with good deeds, the temple, clean water and aid, help comes from the starter towns' warehouse, and a town that cannot recover is sold or abandoned and can be rebuilt by someone else (Sections 8.12 to 8.16).

---

## 13. Economy, trade and banking

### 13.1 Town finances

- **[Decided]** A town balances financing public safety, providing help, paying for road upkeep, walls and defenses, while not over-taxing people.
- **[Decided]** Townspeople pay taxes on their shops, which cover defenses. Surrounding farmland pays taxes for decent roads, water ditches and patrols. Farmland is cheaper than living inside the town walls.
- **[Decided]** The town provides a market where farms sell food, crops and animals.
- **[Proposed]** NPCs weigh the trade-off in their own choices. If patrols fail, farmers pull into town and crowd it. If taxes inside the walls climb too high, shopkeepers leave. Over-taxing is something NPCs respond to, not a rule.
- **[Proposed]** Taxes and upkeep are settled periodically (for example once per game month), writing a few ledger entries. Road and wall condition decay lazily and are repaired by paid laborers when the budget allows.
- **[Proposed]** Ditches have an abstract effect (better yield or less flood damage), not a flow simulation.
- **[Proposed]** The town block has a ledger view of income, expenses and the estimated effect on road safety and resident happiness.
- **[Idea]** A road inside a town block's circle belongs to that town for taxing and upkeep. The length of road in the circle is added to the ledger automatically.
- **[Proposed]** Stretches of road between towns have no tax, no upkeep and no coverage. They are the natural danger zones, which gives players a reason to claim land or fund outposts there.
- **[Proposed]** A town block placed beside a busy road could collect tolls, like a toll castle. Traffic may reroute, and toll rates may need a cap.
- **[Decided]** Town circles never overlap. Placing a town marker reserves land out to the size of a maximum city (Section 8.17), so no one can place a marker whose full circle would overlap another.
- **[Open]** What rights player residents of a town have (leave, protest, vote out the owner) or whether the owner rules unchallenged.
- **[Open]** How many tax levers there are: a few simple sliders (shop tax, farm tax, militia budget) or detailed rules for goods and groups.

### 13.2 Markets

- **[Decided]** (2026-10-13) Market prices are not regulated. Players, player towns and businesses set their own prices and the market decides whether to buy at them: price too high and nothing sells, too low and stock sells out fast, leaving money on the table. NPC buyers (including admin towns) compare prices and buy where it suits them.
- **[Decided]** NPC merchants (including in the starter towns) review their prices once a day and move them with supply and demand: plentiful goods get cheaper, goods in high demand get dearer (Section 8.1).
- **[Proposed]** Local prices move with supply and demand. NPC consumption (everyone eats) creates steady demand without simulating each meal.
- **[Proposed]** Climate and soil make different regions grow different goods, so towns and islands have goods the others want. That gives wagons and ships a reason to travel.

### 13.3 Warehouses and trade routes

- **[Decided]** At first players seek out resources by hand. Once a town block and a warehouse exist, the player can command the NPC merchant who runs the warehouse to import goods from other towns.
- **[Decided]** If a town has a warehouse, anything it exports shows up in other warehouses as for sale. This can trigger a wagon to be sent to gather or trade supplies.
- **[Idea]** In the future, two players with towns can establish trade routes and trade via roads and carriages.
- **[Decided]** The merchant is responsible for the wagon and its contents. If it is lost they lose reputation, probably have to pay the wholesale value of the goods, and lose their own wagon and potentially the driver.
- **[Decided]** More than likely, the warehouse has to maintain its finances and keep enough money to cover wagons, guards or escorts, and problems.
- **[Proposed]** Reading those two together, the wholesale payment for a lost wagon comes out of the warehouse's treasury and not the merchant's personal funds, so the financial risk sits where the decisions are made.
- **[Proposed]** A trade route is a server-owned agreement: goods, quantity, frequency, price, wagons and drivers, and the road path. Routes are rate-based flows that keep working while owners are offline.
- **[Proposed]** Warehouse listings are visible only in connected towns (reachable by road or sea route), which keeps lists short.
- **[Proposed]** An import order and a standing contract create the same kind of wagon job.
- **[Proposed]** The server finds a route's path along connected road pieces once and reuses it. A burned bridge or cut road breaks the route until repaired. A leg could later be river or sea, so the same idea extends to ports and ships.
- **[Proposed]** Merchants weigh expected profit against danger from the threat map, gossip and their personality, and hire escorts, wait for patrols, or refuse on risky roads. Dangerous roads therefore raise prices and pressure towns to clear threats.
- **[Proposed]** Players running their own warehouse carry the same risk as NPCs.
- **[Proposed]** Funds are held until delivery so a lost wagon cannot leave one side cheated.
- **[Proposed]** Goods are tracked in batches with a source tag where theft matters. Commodities can stay as totals. Crafted items stay individual.
- **[Proposed]** Anti-exploit: prices respond to volume, transport has real costs, and money has sinks (upkeep, tolls, taxes), so endless trade loops with a friend do not pay.
- **[Decided]** (2026-10-13) A future market interface, where players shop, make deals and set up trade agreements, shows each offer's price together with its distance, delivery time and how often shipments come. Delivery time is part of the deal: a cheap load of logs that takes two weeks can lose to one at twice the price that arrives tomorrow from the next island. Quantity matters too: each offer shows how much a shipment carries, so a ship from further away carrying ten times the logs at a better price per log can beat a closer wagon. Each offer also says whether it is a one-time shipment or an ongoing contract delivering at regular intervals (and how often). The market panel puts one-time offers and contracts on separate tabs.
- **[Proposed]** Delivery times come from the same route data the wagons and ships use (road or sea path, travel speed, waiting for a free wagon or ship), so what the interface promises is what actually happens. Offers can be sorted by price, by price per unit, by quantity, by arrival time or by total cost including transport.
- **[Decided]** (2026-10-13) **Reputation is personal, not global.** Each trader's reputation is worked out from our own point of view: our history with them, and their history with our allies. Things that hurt it include known piracy, taking money and not delivering, not supplying what was promised, and any similar breach. Affiliations count too: membership of a faction or political group we disapprove of lowers it, membership of a guild we like raises it. There are no factions or guilds yet; for now the town a player lives in acts as their group. The market panel shows this reputation beside each offer.
- **[Proposed]** Reputation is built from the facts each side actually knows. Those facts arrive through the news system (Section 13.6), so a pirate's misdeeds take time to reach a distant island, and allies share what they know. Each player, town or guild can weight what matters to them (for example, piracy counts heavily, late delivery a little). The same per-viewer reputation drives NPC merchants' choices, bank credit (Section 13.5) and whether a town agrees to a contract, so the earlier mentions of "reputation" in this document read as reputation in the eyes of whoever is deciding.
- **[Open]** Whether orders are given through warehouse forms and menus, free conversation with the merchant that is translated into validated actions, or both.

### 13.4 Businesses

- **[Decided]** Reputation counts for the business, the owner and the manager.
- **[Proposed]** Warehouses, shops, smithies, inns, farms and mines share one **business structure**: an owner, a treasury, employees on wages, an inventory and taxes. Finance, wages, taxes, bankruptcy and the ledger are built once. Each workplace type is mostly a table of what it makes, uses and employs. The militia budget and town finances could reuse it.
- **[Proposed]** The value of goods on the road is the business's exposure. A sensible rule is that exposure should not exceed what its reserve could cover. The manager NPC refuses orders beyond it, and the owner can override at their own risk.
- **[Proposed]** The owner can set policies: reserve target, escorts per wagon, acceptable risk.
- **[Proposed]** A business that cannot pay shuts down. Its NPC staff lose their jobs and become displaced, which feeds the migration and rogue-NPC systems.
- **[Proposed]** The manager takes the reputation hit from a loss and might lose the job.
- **[Open]** Whether every workplace really does share the same business structure.
- **[Proposed]** A dynasty owning several businesses is several entries in the shared business structure (Section 13.4). The town gains from successful businesses through taxes, so a manager NPC offering contracts or loans to struggling businesses follows naturally.

### 13.5 Banking, letters of credit and forgery

- **[Decided]** Businesses can ask the town bank for loans, based on their reputation.
- **[Decided]** A character who is not in their own town can try to write a letter of credit (a letter of writ, an IOU like a check), based on their reputation. Otherwise they must go to the bank.
- **[Decided]** Banks pass letters back and forth and eventually send shipments of coins to cover the balances.
- **[Decided]** Banks form relationships with each other automatically between nearby towns.
- **[Decided]** Letters can be forged, based on skill. One roll decides how good the forgery is and another decides whether it is caught.
- **[Proposed]** The bank is a business with its own treasury and only lends money it actually has, never creating new money. A cap on how much of its holdings it can lend contains the damage of defaults. If too many people present letters at once and the vault is short, there is a bank run, which the reserve rule guards against.
- **[Proposed]** Credit comes from reputation (business, owner and manager, blended with adjustable weights) plus collateral such as buildings and stock. A default costs reputation and possibly assets.
- **[Proposed]** A letter is a server-side record: issuing bank, amount, payee and expiry. The player carries it as an item, so it can be lost, stolen or burned. Naming the payee keeps a stolen letter from being cashed. A "bearer" letter would behave like cash. The bank charges a fee, which is its income.
- **[Proposed]** Each bank keeps a running balance with the banks whose letters it honors. Balances mostly cancel out, so only the net difference moves, as a coin shipment (a wagon or ship job). Coin convoys are the most valuable cargo, which makes escorts matter and gives bandits a tempting target.
- **[Proposed]** Each bank links only to its nearest few connected banks. A new relationship starts with a low credit limit that grows as settlements go smoothly. A bank that cannot settle loses standing through the news system.
- **[Proposed]** Forgery: the forger's skill, tools and materials produce a hidden quality value. An inspecting banker rolls against it using their own skill and traits, and knowing the drawer personally can shift the odds. All rolls happen on the server.
- **[Proposed]** A forgery that fools the first banker can be discovered when banks settle and the issuing bank has no record of the letter. The loss lands on whoever accepted it, and the trail can be followed back through provenance and witnesses.

### 13.6 News

- **[Proposed]** One news system carries warrants, reputation changes, threat warnings, price news and bad-bank warnings. A fact with a place and time of origin spreads to other towns as travelers, wagons and ships carry it, so trade routes double as information routes.

### 13.7 Work buildings, stock and maintenance

- **[Idea]** Every job runs through a building with worker slots: farming huts, barns, mines, the smithy, the warehouse, the trade manager's and planner's offices. Slots are filled by the player, family or hired hands. Settings live on the building, and workers keep going until the work is done.
- **[Idea]** A mining town employs most of its villagers in the mines excavating stone, coal, ores and other valuables, ships them across the map to other towns for currency, and buys what it lacks from other towns.
- **[Idea]** Stock targets start at zero. When something is built, the largest amount needed becomes the stock target: a building needing 500 nails sets the nail target to 500. If 30 hinges are needed, the blacksmith makes the 30 and another 30 for the town warehouse. A larger requirement later becomes the new target.
- **[Idea]** Builders always pull supplies from the warehouse first. If something is missing they order it through the town manager. If the town has the tradesperson who makes it, they start filling the order and topping up stock automatically. If not, the order goes to the nearest town that has it. If no town has it, a notice is raised with the town manager, who tells the owner something needs attention.
- **[Idea]** All buildings degrade slowly and need maintenance. Builders do the repairs, and the cost comes from the individual shop or owner. This steadily uses up supplies.
- **[Idea]** The warehouse manager, merchant or shipper takes stock now and then and decides where to set stock amounts.
- **[Proposed]** Maintenance is the economy's steady sink for materials and money, which a long-running server needs to avoid surplus and collapsing prices.
- **[Proposed]** Materials affect upkeep: stone decays slower than wood, treated wood slower than untreated, and wet or coastal climates rot wood faster. Neglect reduces function and shelter and eventually leads to ruin.
- **[Proposed]** A business schedules repairs automatically when it has the funds, and the "while you were away" report lists what was repaired and what it cost.
- **[Proposed]** The warehouse manager's review uses the language model budget in Section 3: about once per game season, given usage figures, replying with new targets within allowed limits, with the reason logged. Targets that go unused drift back down.
- **[Proposed]** A short "what is blocked" list in the town panel ("waiting on iron") keeps the chain visible.

### 13.8 Real money (future)

- **[Decided]** (2026-10-14) **Free to play, paid through small purchases.** The game is free and must run on older computers. There is no required monthly fee. Revenue comes from small, reasonable purchases:
  - cosmetics such as holiday outfits, and special or event versions of gear, never anything extremely overpowered;
  - simple goods that starter towns already sell, such as an iron sword or silver sword, for players who want to save time and effort on basics;
  - in-game currency, which also lets someone who wants to be rich buy a lot of it, and the owner does not mind. For example, a player could spend a couple of hundred dollars and use it to take over someone else's dynasty in receivership (Section 6), then spend more to repair it and inherit its tools, weapons, animals and family.
- **[Decided]** Paid duress blocks (Section 6) are a purchase of the same kind. Their prices are not set yet: they will come from a market analysis later, looking at what players will accept. For comparison, many players refuse $15 a month for games like World of Warcraft, but $5 a month or $60 a year would be much less of a dealbreaker.
- **[Proposed]** The earlier ideas below (buying the game and a monthly subscription, a subscription minimum, earning subscription credits) are superseded by this decision, and are kept as options if the model changes. Because every player, free ones included, costs real money to host (server time, and the language model for NPC conversation), the free tier needs a per-player budget for the expensive parts (Section 3), and the revenue needs checking against that cost before launch. Selling currency still needs legal advice and care about gambling, consumer protection and payment rules.
- **[Superseded]** People buy the game for a reasonable price and pay a monthly subscription, roughly the same as World of Warcraft's.
- **[Superseded]** Players can earn credits in game toward the subscription. A town earns credits for its owner and management team, more with more population and trade, encouraging people to run and grow towns.
- **[Superseded]** The subscription can be reduced to a minimum of about $5 a month. Whether players could earn the whole subscription was left undecided.
- **[Decided]** Gambling (including wagering at the pub) is flagged for a future discussion, to be revisited when that work starts.
- **[Superseded]** Credits created by the game cost real subscription revenue and give cheaters a cash incentive (fake trade between their own towns, extra accounts, bots), so they need strong anti-cheat, such as counting only trade with real, distinct players, plus caps.
- **[Superseded]** A token model avoids that: one player buys a token with real money and sells it for in-game currency, and another player uses currency to pay the subscription. EVE Online (PLEX) and World of Warcraft (WoW Token) work this way. The developer is paid either way and no new money enters the economy. Running a successful town would earn currency that buys tokens.
- **[Superseded]** Keep a subscription minimum, since every player costs real money to host, including the language model.
- **[Proposed]** Currency bought from the game buys real power in a player-driven economy (land, guards, armies) and adds inflation. Caps or the token model reduce both.
- **[Proposed]** Selling currency, and especially combining it with gambling, can fall under gambling, consumer protection and payment processor rules that vary by country. Get legal advice before any real money is involved.
- **[Proposed]** Until then, design the economy to work without real money. The whole-number ledger already makes a token model easy to add later.
- **[Superseded]** Whether earned credits come from the game or from other players through tokens, and whether a player can earn the whole subscription.

---

## 14. Current code status

Updated 2026-10-14. The new generator lives in `src/worldgen/` on branch `claude/generator-v2` (GDScript, run headless in Godot). The plan and its progress log are in `GENERATOR_V2_PLAN.md`.

**Built and tested (798 checks pass)**

- World settings, SHA-256 seeds, append-only data tables (biomes, soils, rocks, resources, water classes, site types, feature types, province kinds).
- The world sketch and a seamless 160 m elevation map of the whole world, the fixed features (central trench, ultimate island), the danger map, and the derived tile plan (312 islands, 227 tiles with land).
- For one tile (the starter tile (3,4)): the 8 m height map, erosion, water (rivers, lakes), climate, biome, soil and fertility, geology (provinces, features, ore bodies, placers), and natural caves, dormant lairs, harbor and starter spawn. About 2 minutes in total.
- Preview images for each stage.

**Not built yet**

- The tile file writer and reader (step 13), the runtime terrain generator (step 14), runtime flora, server streaming and the client cache, the layer for player changes.
- Rivers that continue across tile edges, a final edge-matching pass, and wrap-seamless detail and climate noise (`WORLD_FORMAT_SPEC.md` Section 4b).
- Any game system: players, NPCs, towns, building, law, economy, machinery.

**Old generator.** The earlier volumetric pipeline (10 by 10 region tiles, about 15 to 16 hours per tile) is still in the repository and untouched until the new one replaces it (plan step 19). `README.md`, `GENERATION_GUIDE.md`, `PROJECT_ROADMAP.md` and `CHANGES_THIS_PASS.md` describe it.

**Not checked**

- The size of a baked tile on disk (the estimate is about 52 MB per tile before compression) and how the client performs on the minimum machine (Section 3).
- Whether river flow data could be queried at runtime to power water wheels.

**Current values**

- World height -4,000 m to +2,048 m, sea level 0, 1 m voxels, 15,360 m tiles (15 by 15 regions of 1,024 m), 8 m map grid, 21 by 21 tiles.
- Rock types (10): sediment, shale, limestone, coal, granite, slate, basalt, sandstone, marble, chalk. Resources: IDs 1 to 31 (Section 4.9a).
- Default server capacity: 32 clients.

---

## 15. Open questions

World and bake

1. Seasons are decided. Should their strength grow with distance from the equator?
2. Mostly settled: the desert row is the origin row and zones run symmetrically north and south (Section 4.2). Still open: the planned final height in tiles.
3. How much variety in island size is wanted, from tiny rocks to ARK-scale?
4. Is the world bottom at -4,000 m confirmed, with the lethal depth near -3,000 m kept adjustable?
5. Should the bottom kilometer be detailed for possible future content or baked simply?
6. How far should altitude effects reach, given the 2,048 m ceiling?
7. What limits diving, and can the deep ocean floor be dug?
8. Is mining the terrain itself in the first version?
9. Settled: ore is finite and does not renew; living and some river and surface resources do (Section 5). Still open: do NPC miners carve tunnels or draw down a deposit's amount? (Section 11.4)
10. How big should automation get, and how far away should simplified distant life appear?

Time and persistence

11. Settled: everyone ages on the server clock (Section 6.1). Still open: the exact length of the calendar year, and whether age is shown as a number or a life stage. (Section 7)
12. Do dropped items expire, and do hard-to-reach ones last longer?
13. What happens when a character dies with no heir?
14. Is there a grace period for accidental disconnects, and does the game warn about risky logout spots?
15. How permanent is offline loss for family and buildings?
16. How large is the heir's head start in the parent's skills?

Social, law and threats

17. Who can raid whom: NPCs only, or other players too?
18. Are locks and security soft barriers?
19. How far does justice spread, and are there limits to news?
20. Can NPCs cross the ocean themselves?
21. Settled: ruins stay as rubble and roads stay (Section 8.13). Still open: can a ruined town become a bandit stronghold?
22. Are threats fixed lairs, roaming groups, or both? (A failing town can recover: settled in Sections 8.12 to 8.16.)

Towns, economy and platform

23. Settled: town circles never overlap; a marker reserves a maximum city's worth of land (Section 8.17). Still open: the list of settlement sizes and the maximum.
24. What rights do player residents have, and how many tax levers exist?
25. Are orders given through forms, conversation, or both?
26. Does every workplace share one business structure?
27. Is Steam the release target, and therefore is the Workshop an option?
28. Are blueprints built all at once or in stages?
29. Is fire treatment a crafted material or an upgrade to placed pieces, do weather and wind affect fire, and who fights fires?
30. Does ventilation stay a simple range effect?

Language model

31. Who hosts the servers and pays for model calls: the developer, players hosting their own, or both? This decides which model options are practical.

Rescue and starting conditions

32. Who runs the developer-built starter town over time, and do other towns become server-owned later (for example abandoned player towns)?
33. How does NPC rescue work in practice, and how is it kept from trivializing death? Do NPC companions count toward party size and what do they cost?
34. Should the bake include coarse land-suitability layers (slope, fertility, water access) for the town planner, and can plans run unattended? (Section 8.4)

Farming, families, time and money

35. Do crop times follow realistic fractions of the year or get tuned for gameplay, and are hands paid by share, by wage, or the employer's choice? (Section 5)
36. Settled: the chosen successor inherits the whole dynasty, and the person you play is the owner (Sections 6.2 and 6.7). Long absences are covered by duress (Section 6).
37. 60 or 72 minutes per game day, and how dangerous is night? (Section 7.5)
38. Do earned subscription credits come from the game or from other players through tokens, and can a player earn the whole subscription? (Section 13.8) Gambling is flagged for a later discussion.

Map growth

39. Settled: the world is 21 by 21 from the start, with placeholder ocean tiles. Still open: how many tiles to build before players arrive, besides the starter tiles.
40. Settled: three zones with transition rows, desert on row 0, 21 rows tall (Section 4.1).

Generator, hardware and hosting

41. Settled: resources are placed by how they really form, and the full volumetric simulation can be replaced by anything faster that reaches the same result (Section 4.9). Still open: which geological features a tile stores, since that list becomes permanent. First version built in step 11 (intrusions, faults, volcanic vents and pipes, salt domes; ore as vein, lens, pipe, layer, halo and placer); to be confirmed before tiles are kept (step 13).
42. Is runtime voxel generation on the server acceptable instead of reading everything from baked files? (Section 4.8)
43. Recommended: start with streamed blocks plus a client cache and low-resolution maps for distance and the world map (Section 4.10). Confirm, and measure bandwidth once a prototype runs.
44. Can players host a world on their own machine? If so, one minimum-spec machine runs both server and client. (Section 3)
45. What frame rate and view distance should the minimum machine reach? (Section 3)
46. How much protection against "x-ray" clients that read ore from received voxels is worth its cost? (Section 4.9)
47. How large a world can be designed, managed and served, and is it one server process or split across several later? (Section 4.1)
48. Mostly settled: eight temperate starter tiles, inner at (±3, ±4) and outer at (±6, ±6) (Section 4.1). Still open: when the outer set opens.
49. Settled: flora is derived at runtime from the biome map and a placement seed, only removals are stored, and the map grid is 8 m (Sections 4.3 and 4.8).
50. Settled: 21 by 21 (Section 4.1). Still open: travel speeds on foot, by horse and by ship, which decide how long the world takes to cross.
51. How far does polar sea ice reach, and can ships cross the pole in summer? (Section 4.2)
52. Should island size classes grow with the bigger tiles? Island areas stayed the same when tiles grew from 10.24 km to 15.36 km, so land fell from about 11% to about 6% of the world. (Section 4.1)
53. How does the client handle positions far from the origin: floating origin or a double-precision build? (Section 4.10)
54. Settled: the world-first sketch was approved (2026-10-13), replacing per-tile dice and the shared deep-ocean tile edge (Section 4.12).
55. Settled: inner starters easy, outer starters medium, edges deadly (Section 4.13). Still open: how many tiers players see, and whether the curves need tuning once creatures exist.
56. Settled: starter landmass inner 50 to 100 km², outer 70 to 150 km². Still open: town spacing 3 km from a starter town, 2 km between towns? (Sections 4.1, 8.1)
57. How PvP works for players who want it, given the starter areas are PvE (Section 9.0).
58. How long before a vacated home is abandoned, and what happens to its contents (Section 8.6).
59. Does fallow land (farmland left unplanted) slowly recover fertility by itself, enabling medieval-style crop rotation, or only through lime and manure? To discuss later. (Section 5)
60. Admin town buying: settled that budgets are money per day, the log shows bought and manifested goods, and prices come from the merchant's daily review. Still open: whether the daily cap is split per resource, per selling town or per player, and whether it buys only from connected towns (Section 8.1).
61. Factions, political groups and guilds: none exist yet; ideas to come later. For now the town a player lives in acts as their group (Sections 8.6 and 13.3).
62. Resource renewal and mine support (Sections 5 and 11.2): how fast each semi-renewable resource refills, mine abandonment time, opening sizes that need support, support types and whether collapses can hurt miners.
63. Duress and absence (Section 6): all settled except the per-month protection price (market analysis, Section 13.8), refund rules for a real-money balance, what a player gets back after their dynasty became NPCs, which events count as urgent versus weekly, and payment handling.

Ambiguities found in the 2026-10-14 review (the newest statement was applied wherever two disagreed; these are the cases where it is still unclear)

64. **The aging clock.** Settled (2026-10-14): one server clock; everyone ages online or offline; human biology including menopause; no cap on children beyond biology (Section 6.1). Still open: the exact fertility ages (proposed: fertile from 15, menopause 45 to 55).
65. **One clock per system.** Everything runs on the single server clock. A "real time" window is server time, so it pauses when the server is down (proposed). Still open: reputation fades "over about a week" but "in-game days" means 7 real hours at 60-minute days; and whether a game day is 60 or 72 minutes.
66. **Town block.** Settled (2026-10-14): a marker with no physical form, visible only to the owner, with a ledger entry; settings are reached through an office building (Section 8.17). Still open: how another player sees and claims an abandoned marker, and what "touching the block" becomes (proposed: being at the office).
67. **The circle of influence.** Settled: grows by paid expansion, no overlap, a maximum-city reservation (Section 8.17). Proposed: a ladder from settlement (200 m) to metropolis (1,500 m radius), each step 50 percent larger, with population guides. Still open: confirm or change the numbers and names, the expansion cost, and what each stage requires.
68. **What "established" means.** Guards, a well, a temple and probably walls: how many guards, how strong, and does the town need all of them? What can players do to each other in a town that is not yet established (the "gray area")? Where do PvP and PvE rules live (Sections 8.15, 9.0, question 57)?
69. **Succession details.** Settled (2026-10-14): without a will the family decides and the player's choice is random among the eligible; otherwise the order is all the player's blood children by age, the first spouse, then for each later spouse her stepchildren followed by her (Section 6.7); a named successor can refuse; retirement means choosing a successor, taking over their body, and the retiree becoming an elderly NPC on the farm. Also settled: the last person in line (the youngest child) must accept; with no lineage at all, a new character gets the dynasty by a mysterious will with a money-only inheritance tax, never taking items, with town loans and temple help (Section 6.7). Superseded: the "random choice among the eligible" for no will; instead the chain is the order of asking, each person accepts or refuses by their own loyalty, duty and greed, and a will raises the odds (about 50-50 even for someone who said no). Still open: at what age or frailty a character may retire; and the size of the inheritance tax.
70. **Merging dynasties.** Settled (2026-10-14): the entire families combine under the player, with new spouses, stepchildren, properties, businesses and debts, and stepchildren can be successors. Still open: which duress value is kept and what happens to the absorbed dynasty's reputation.
71. **Weekly check-in for duress.** Should clearing duress need one real choice instead of a bare login? Left undecided by the project owner.
72. **Real-world alerts for town challenges.** Should an email or app alert also be sent when someone challenges a town? It is kinder, but it weakens the in-world distance and mail idea.
73. **Flagging a town for deletion.** The administrators vote, but there is no trigger, deadline or fallback if nobody does. Should there be an automatic rule (for example after a set time with no owner and no manager)?
74. **Server-town decay against the spirit floor.** A server-owned town with a temple and clean water keeps a spirit floor, but also loses money and decays. Which decides when buildings start to fall, and how long does it take?
75. **Hostile takeover payment.** "A fixed amount based on the town's value": who works out the value, and does it include the buildings, the stock and the NPCs?
76. **Weekly players and short windows.** A bare town block can be lost after a 2 hour window, which fights the principle "never punish a weekly rhythm". Is that acceptable, or should the windows be longer or the first claim protected for a while?
77. **Duress.** Settled (2026-10-14): duress does not raise bills. It lowers crop yields and animal growth, slightly lowers reputation, and speeds property degradation a little; costs rise only because more needs fixing (Section 6.1). Still open: the size of each effect at each level.
78. **Households without limits.** Many living spouses and children are allowed. Is there any cap, or only cost (housing, food, care)? How does a large household affect duress and the weekly player?
79. **Remains.** How long do remains last, are they flat images that face the player, how is sand cover worked out, which creatures collect gear, and do NPC adventurers leave remains too? (Sections 4.13 and 6.1)
80. **Rubble.** How big is a rubble chunk, and how is it stored in the server's living layer when terrain is regenerated?
81. **Tile ID scheme.** Confirm the recommendation: a record's identity is its home tile and local ID, the revision is only a cache marker, and records added by resource passes use local IDs from pass number × 10,000. (`WORLD_FORMAT_SPEC.md` Section 4)
82. **Which extra resources before tiles are kept.** Only tuff (whole-layer volcanic stone) might need to come first. The rest can be added later by passes. See the table in Section 4.9a.
83. **River network and edge matching.** Confirm the approach in `WORLD_FORMAT_SPEC.md` Section 4b (a world river network on the 160 m map, overlap margins, a final edge-matching pass) and that step 13b is done before any tile is kept.
84. **PvP zones.** If PvP areas are added later, they should be a world-level map in `world.json`, not part of tiles. Confirm.
85. **Temple.** Is a temple built by the town, by players, or both, what does it cost, and how many can a town have? (Section 8.11)
86. **Bridges and travel roads.** Maximum span and water depth of a bridge, which kinds exist (rope, timber, stone, causeway with culverts, ford), and who maintains the dirt roads that NPC travel creates. (Section 8.17)
87. **Ring layout.** Are the rings in Section 8.17 hard rules or only the planner's preferences, and can the owner override them?
88. **Marker hoarding.** Reserving a whole city's land with a marker lets a player block land by placing markers. What does a marker cost, does it need upkeep (or duress), and when is a reservation released (for example when a town is deleted)?
89. **Extended life.** How is a wish judged "reasonable", what does each route cost, and how does a long-lived character fit the succession chain, the single server clock and the 20-year new identity? (Section 6.10)
90. **Familiars.** What can they do besides talk, how are they obtained, do they age or die, and can the jokes be turned off? (Section 6.11)
91. **Homages.** Who reviews each reference so it stays a nod and not a copy? (Section 6.12)

---

## 16. Candidate work, in dependency order

Nothing here is committed. It follows `GENERATOR_V2_PLAN.md`, ordered by what affects baked data first, since baked changes force rebakes.

1. Done: world settings, tables, world sketch, tile plan, and for one tile the height, erosion, water, climate, geology and sites (plan steps 2 to 12).
2. Settle the permanent parts of the tile file (`WORLD_FORMAT_SPEC.md` Section 4): the ID scheme, the geology list (Section 4.9a), the resource pass design, the edge rule.
3. Tile file writer and reader (step 13).
4. Rivers across tile edges, overlap margins, wrap-seamless noise, and the final edge-matching pass (Section 4b of the spec).
5. Runtime terrain generator from the maps (step 14), then runtime flora (step 15).
6. Server streaming, the client cache and the layer for player changes (step 16), then the minimum machine test (step 17).
7. Build the inner starter tiles and their neighborhoods (step 18), then retire the old pipeline (step 19).
8. Game systems on top of that foundation: harvesting, building and blueprints, characters and aging, NPCs, towns, law and recognition, fire, then production, threats, trade and banking. A small first playable slice has to be chosen first.

Most gameplay systems in Sections 5 to 13 live in the server layer and can be added later without rebaking terrain.
