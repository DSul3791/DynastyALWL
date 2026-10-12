# Design Vision and Ideas

Record of the design brainstorming sessions of 2026-10-11 and 2026-10-12. This is a planning document only. Nothing described here has been implemented, and no code was changed.

**Revision history**

- **Version 1 (2026-10-11):** vision, world generation and bake, harvesting and farming, characters and heirs, NPCs and towns, soft law, building and fire.
- **Version 2 (2026-10-12):** added Satisfactory as an inspiration; production and logistics; road threats and pacing; town finances, markets, warehouses, trade routes, businesses, banking, letters of credit and forgery; crime memory, delayed discovery and disguises; inheritance of money and debt; the shared principles those systems rely on. Open questions and the work ordering were rewritten.
- **Version 3 (2026-10-12, later):** lifespan targets (start at about 15, die at about 80, in about 700 hours of play); families age with the player; the rescue-first philosophy and party composition; heirs arriving partly trained; the tension between server-owned towns and "no towns at the start"; and the clock arithmetic showing that one clock for aging and seasons is probably not workable. Open questions were updated.
- **Version 4 (2026-10-12, latest):** two clocks decided (a world calendar for seasons and crops, and an aging clock); a one-to-two-week seasonal cycle; NPC aging at the average player's speed (70 years per real year); the weekly farming rhythm and a note on avoiding calendar years of exactly 7 or 14 days; Farming Simulator as an inspiration; no starting towns; and the civil engineer town-planning idea. The lifespan pacing figure changed from 65 to 70 years (15 to 85).
- **Version 5 (2026-10-12, evening):** the "play what you like" and "no micromanagement" goals; server-clock aging for everyone as an idea; children, twins, wills and choosing an heir; 60-minute game days, seasonal day length and night; the weekend farming rhythm, crop tiers, farm labor and work buildings; stock levels, the order chain and building maintenance; the budget for language model use and self-hosting; town roles, land and property; quests and pastimes; real-money ideas, with gambling flagged for later; and the plan for growing the tile map one side at a time.
- **Version 6 (2026-10-12, night):** minimum hardware target (older quad-core, 8 GB RAM, SATA SSD); the 15 to 16 hour tile bake and a proposal to bake 2D maps and generate voxels at runtime, with a table of what is baked, what the server works out and what the client does; language service hosting and scaling; NPC backgrounds, memory, honesty and conversation traits.

## How to read this document

Every item carries a status tag.

- **[Decided]** Stated or clearly agreed to by the project owner.
- **[Idea]** Raised by the project owner as a direction or wish ("we could...", "maybe...", "it would be nice to eventually..."), not yet firmly settled.
- **[Proposed]** Suggested by Claude during brainstorming. It was accepted in passing or not objected to, but never explicitly confirmed.
- **[Open]** A question that has not been answered yet. Section 15 collects them.

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
- **[Decided]** The game is designed to keep players alive even though the whole world is trying to kill them. Layers of rescue (party mates, helpful NPCs) catch a fallen character before they die (Section 6.5).
- **[Decided] Play what you like.** Players should never have to switch games to change style. Farmer, miner, trader, town manager, hunter or trapper selling to the butcher and furrier, caravan sword for hire, adventurer, someone who plays board games or roleplays conversations in the pub, or someone who wanders the rivers and fields enjoying nature. Each style needs a complete loop of its own.
- **[Decided] No micromanagement.** Every avenue can be done by hand for fun, or handed off to NPCs, whether family or hirelings. Doing it yourself pays more. Delegating costs a cut but keeps things running.

---

## 2. Terminology

- **Region:** one 1,024 m by 1,024 m storage file holding all 7 LODs. It is the natural unit to stream from server to client.
- **Island tile:** a block of 10 by 10 regions, 10,240 m (about 10.24 km) on a side. Each tile is baked on its own and addressed by a permanent integer coordinate.
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
- **[Proposed]** A tile with zero islands is simply an open-ocean tile. This gives ships real distances without any special system.
- **[Proposed]** Irregular coastlines with small offshore islets, instead of the current rounded-square outline.

Constraints inherited from the current generator:

- Every tile edge converges to the same deep-ocean floor so independently baked neighbors match. Islands therefore keep a margin from the tile edge and can never cross a tile border. The largest island is about one tile.
- Two islands in neighboring tiles can never be closer than the sum of their edge margins, so a regular grid of ocean lanes can appear if every tile holds a similar big island. Mixed sizes and positions hide it.

### 4.2 Climate

- **[Decided]** Climate is driven by distance north or south from the origin tile. The origin is the equator (hottest). Climate cools gradually toward the poles.
- **[Decided]** The 500 km arctic line mentioned in discussion was only an example. The real scale is undecided.
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
- **[Decided]** Trees and other plants are **objects, not voxels**. At bake time the generator writes a compact placement list per region (position, species, size, rotation). The client downloads it with the region. The server loads the same list.
- **[Decided]** Grass is never stored or synced. The client draws it near the player only, driven by ground type and a quality setting.
- **[Decided]** Fauna is server-controlled spawning, based on climate, biome and terrain. It is never baked.
- **[Decided]** Fantasy (Dungeons and Dragons style) species.
- **[Proposed]** A removed tree is recorded as "item N in region R is gone." Because the list is the truth, changing placement rules later only affects newly baked tiles.
- **[Proposed]** Climate and soil should also be queryable at runtime from the same function the generator uses, so the server and generator never disagree. This matters for farming.
- **[Proposed]** Slate as a new rock type (shale metamorphoses into slate), tied to folded or deformed regions. Slate would make some islands valuable for roofing.

### 4.4 Natural structures and lair sites

- **[Decided]** Caves, abandoned mineshafts, labyrinths and similar discoveries, as in Minecraft.
- **[Proposed]** Underground structures are baked as real voxels, since players can dig into and through them. They become destinations for NPC quests and bandit camps. If the layering in Section 4.8 is adopted, only each structure's site (position, type, seed) is baked, and the server carves the voxels from it with the same deterministic generator as the rest of the terrain.
- **[Decided]** Towns are **not** baked. Players found towns (Section 8).
- **[Decided]** Eventually a threats system will pinpoint areas that make natural bandit camp places. Premade goblin camps can also be dropped in like a blueprint, creating a small cave system filled with goblins (Section 12).
- **[Proposed]** At bake time the generator scores natural hiding spots (caves, ruins, ridgelines, forest edges: defensible and out of sight) and places **dormant lair sites**: empty caves and camps that nobody lives in yet. At runtime the server only changes a site's state ("site 14 is held by a goblin horde"). That needs no terrain editing and no client download.
- **[Idea]** People in extreme cold may build underground bases and grow things that need no light, such as mushrooms.
- **[Proposed]** Cave generation should include some large, usable caverns and not only narrow tunnels, so underground bases and farms are possible.

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
- **[Decided]** The world grows one side at a time by adding a full row or column. For example, a 4 by 4 map grows by picking a side and adding 4 tiles, making it 5 by 4. The next expansion picks a side and adds 4 or 5 tiles depending on which side is chosen.
- **[Proposed]** Alternate opposite sides as the world grows (north then south, east then west), so the origin tile stays near the middle. That keeps the equator central and makes the north-south wrap seam join two equally cold edges.
- **[Proposed]** A new row or column is baked into a staging folder and only goes live, at a server restart, once the whole row or column is complete. The existing builder and server already work this way (GENERATION_GUIDE.md).
- **[Proposed]** Because growth is rare, new rows and columns can be baked on a separate machine and copied into the staging folder, so baking never competes with the running server.

### 4.8 Bake time and where work happens

- **[Decided]** Baking one tile with the current generator takes about 15 to 16 hours (measured by the project owner). An efficiency review was started elsewhere but nothing was changed.
- **[Proposed]** That cost does not fit a world that grows by adding unique tiles, especially since any generator change forces a rebake. The likely cause, from reading the code (not yet profiled): the bake fills a complete 3D volume from +2,048 m down to -4,000 m at all 7 LODs, using simulated geology (tectonic deformation, faults, folds, igneous intrusions, strata, caves and minerals) evaluated voxel by voxel in GDScript. The output is probably also many gigabytes per tile, which conflicts with the minimum hardware target (Section 3) if clients must hold it.
- **[Proposed]** Keep the foundation, change what the bake produces. Keep: the region format, catalog and mapper, wrapping, tile seeds, the complete-rectangle check, the resumable atomic bake, the shared deep-ocean tile edge, the coast model and the 2D hydrology (ocean mask, flow, lakes, channels on the 8 m grid). Change: the bake writes compact 2D maps per tile, and voxels come from a fast, deterministic generator at runtime. Volumetric folds and faults are dropped or simplified, since players will not notice them. Mining to about 3 km needs rock layers by depth, caves and ore, which can be simple functions of the maps and seed.
- **[Proposed]** Voxel Tools appears to offer native generators (a graph generator, or one driven by a heightmap) that should be far faster than per-voxel GDScript, and to store only edited blocks. Both claims need checking against the Godot 4.7 build in use.
- **[Proposed]** Each generated block is saved once on the server (an SQLite-style store), so it is never generated twice.
- **[Proposed]** Each tile records the generator version it was created with, and that version is frozen once players have built there, so a later generator change cannot alter terrain under existing buildings. New tiles can use newer versions. This replaces the current rule that rejects mixed generator versions.

**[Proposed] What lives where**

| Layer | Contents | Why |
|---|---|---|
| Baked once per tile, permanent | Tile seed and generator version; height, coast, rivers and lakes; climate zone; soil and biome class; flora placement lists; sites for caves, mineshafts, labyrinths and dormant lairs; possibly deposit identities and land-suitability layers | Defines the place. Changing it later moves coastlines and landmarks under players. Small: about 1,280 by 1,280 cells per map at 8 m. |
| Server, deterministic from the baked maps | Voxel fill, rock layers by depth, caves, ore, structure carving, fauna spawning, plant growth, weather | Cheap to produce on demand. Frozen per tile once players build there. |
| Server, living layer | Voxel edits, removed trees, buildings, NPCs, crops, economy | Changes constantly. Saved as deltas on top of the baked and generated base. |
| Client | Meshing, LOD display, fog and horizon impostors, grass and foliage shaders, animation, sound, weather visuals | Keeps the minimum machine light. |

**[Open] How terrain reaches the client.** Either the server streams compressed blocks and clients cache them on disk (simplest, server authoritative), or clients download a tile's small 2D maps, generate unedited terrain themselves and receive only edits (far less bandwidth, but different CPUs might produce slightly different results, causing seams or desyncs). Measure before choosing the second.

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
- **[Open]** Prepared ground (tilling) as a terrain edit, or seeds on any suitable surface.
- **[Open]** Whether things regrow at different speeds and whether rocks and minerals ever return.
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
- **[Idea]** The base can be in a town that belongs to another player or to the player. A town belonging to the server was also mentioned, but there are no starting towns (Section 8.1), so that could only happen later.
- **[Decided]** Children age too.
- **[Idea]** Couples realistically keep having children, about one every year or two, and twins are possible. That is one every 5 to 10 real days, or about a dozen children between parent ages 22 and 40 over about three months of real time.
- **[Idea]** Population control: if a family has many children, one might fall sick and die or have a farming accident.
- **[Proposed]** Tie that risk to conditions the player can see and influence (poor food, a crowded house, no healer nearby, unsupervised dangerous work) plus a low baseline of childhood illness for every family, instead of a penalty for family size. Food, housing and land costs make a large family a real expense. Child death is emotionally heavy and can affect age ratings, so it may need gentle handling.
- **[Decided]** A character who is killed with no way to recover, or who is too old or wounded to recover, dies. The player restarts as a new character.
- **[Decided]** If the player restarts as their child, the child inherits everything that remains. The child's first quest may be to find the fallen parent, or hire local adventurers or services to retrieve the parent's gear.
- **[Decided]** ARK-style unconsciousness before death. A downed character can be revived, carried or dragged to safety by party members.
- **[Decided]** Characters age **slower** while their player is offline, but they stay in the world and remain vulnerable. Their body can fall unconscious, be burned or be killed while offline. Friends can pick them up, put them on a wagon, or drag them to cover.
- **[Decided]** Characters and their families age slower while the player is offline, so the household ages together. The mismatch is between the household and the rest of the world, not within the family.
- **[Idea]** Replace the rule above: since lifespans are averaged over about a year anyway, everyone (players, families and NPCs) simply ages on the server clock at the same rate, 70 years per real year. Claude recommended this because it removes the offline aging speed question and the household mismatch, and because the slower-offline rule only narrowed the gap in play hours per life a little (about 300 to 1,100 hours instead of 260 to 1,300 for 5 to 25 hours a week). It has not been confirmed. Its costs: time away ages a character (four weeks is about 5.4 years, two months about 12), and the clock must survive server downtime (Section 7.6).
- **[Decided]** Spouses and children stay in the world while the player is away. Events such as bandit raids, dragons and sickness can affect them, which gives players a reason to return.
- **[Decided]** Co-op: friends can tend animals and harvest crops for an absent owner, with permission.
- **[Decided]** Because offline characters stay vulnerable, the downed timer keeps running while the player is offline.
- **[Proposed]** Age is computed as online time at full speed plus offline time at a reduced rate.
- **[Proposed]** Downed window or recovery chance depends on age and condition.
- **[Proposed]** Ownership held at the **dynasty** (family line) level, so nothing needs transferring when a character dies. This is consistent with the heir inheriting everything that remains.
- **[Proposed]** Logging out in a bed, inn or your own town makes a character **safer** (not invulnerable), while logging out in the wilderness leaves the body exposed. The project owner agreed and noted inns can be abandoned, attacked or burned, with occupants inside.
- **[Proposed]** A "while you were away" report on login, with events resolved by game rules and optionally narrated by the language model.
- **[Open]** Whether the game warns about the risk of a logout location.
- **[Open]** A grace period for accidental disconnects.
- **[Open]** Whether long absences get a special rule, or time simply passes.
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
- **[Idea]** When a character dies, the player chooses which heir to become. An older child has better skills but less time left to play.
- **[Idea]** A will lists the children with their skills and attributes and leaves the farm or the town to a chosen child. It should be set long before death and can be updated at any time.
- **[Proposed]** If a parent dies at 80, an heir aged 20 has about 11 months of real time left on average, one aged 35 about 8.6 months, and one aged 50 about 6 months.
- **[Proposed]** Which character the player plays and who inherits the property could be separate choices. Playing one child while the will leaves the farm to another creates a sibling story.
- **[Proposed]** A death without a will falls back on the town's inheritance law (eldest child, equal split, spouse first), set in the town control panel. NPC siblings with greed or resentment might contest a will, and a forged will would use the forgery system. Adult children who have moved away still appear on the list.
- **[Open]** Whether the will decides who the player becomes, who owns the property, or both as separate choices.

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

---

## 7. World time

Aging, marriage, children growing up, crop growth, regrowth, decay, taxes, loan payments, work hours, patrol and trade schedules, memory fading and seasons all depend on time.

### 7.1 Lifespan targets

- **[Decided]** For pacing, a typical 15-year-old character ages to 85, which is 70 years over about one real year and about 700 hours of play. Lifespan varies, averaging 72 to 90 years (Section 6.1). An earlier version of this document used 15 to about 80 (65 years).
- **[Decided]** The expected player plays 12 to 16 hours a week (for example four hours on three nights, or eight hours on each of two nights), about a year of real time per character, allowing for two missed weeks. That is 50 weeks, so 600 to 800 hours, about 700 in the middle.
- **[Proposed]** Skills should feel competent in tens of hours and mastered in a few hundred, so a character gets time at the peak before aging slows them. That much play time needs enough depth to stay interesting.

### 7.2 Why one clock does not work

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
- **[Open]** The offline aging speed (or whether everyone simply ages on the server clock, Section 6.1), the exact length of the calendar year, and whether age is shown as a number or a life stage.

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

- **[Decided]** The world starts with no towns. Players found them by placing a **town block** that they own. They can assign themselves as owner or leave governance to AI.
- **[Decided]** There are no starting towns. In the first playthrough the players are the project owner's friends and family, and it is their job to build the first towns.
- **[Idea]** Towns might become server-owned later (for example abandoned player towns), since a town belonging to the server was mentioned. Nothing is placed at the start, so this does not affect the bake.
- **[Decided]** Players build roads and buildings, choosing from premade blueprints.
- **[Decided]** The town block interface sets rules and settings: militia, elite guards, a town bank and town funds, tax rates and tax rules. Towns can build and improve defenses.
- **[Decided]** Player-run towns can fall into ruin.
- **[Proposed]** Ruins as landmarks that decay lazily over time.
- **[Open]** Whether ruins last forever or fade.

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
- **[Proposed]** A dynasty owning several businesses is several entries in the shared business structure (Section 13.4). The town gains from successful businesses through taxes, so a manager NPC offering contracts or loans to struggling businesses follows naturally.

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

---

## 9. Law, crime and recognition

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
- **[Idea]** Railways, and machinery that moves materials out of mines up to the surface: minecarts, steam-powered engines, windmills.
- **[Proposed]** A progression from the existing resources (copper, tin and iron for tools, coal for steam), tied to the tool-power-versus-hardness rule so each step unlocks harder rock and deeper mining.
- **[Proposed]** Machines are building pieces with inputs, outputs and a rate, listed in a recipe table.
- **[Proposed]** Water wheels take power from the river flow the generator already computes, and windmills from the climate layer's wind.
- **[Proposed]** Production chains are computed as rates from timestamps, not by moving every item all the time. The visible carts and moving ore exist only near a player.

### 11.2 The mine chain

- **[Idea]** Villagers work in the mine during work hours, mining ore and filling the ore receptacle. Machinery gradually moves it up to the surface in an assembly-line way. Other villagers load it on wagons and move it to town, where craftspeople buy it to make tools, weapons, hinges and building parts.
- **[Proposed]** Output depends on the miners' skill, their tools and the ore richness. The depth heat limit applies to miners, so deep mines need ventilation stations and staff.
- **[Proposed]** Tracks and roads use the same leveling rules as blueprints.

### 11.3 Life in the world

- **[Decided]** Moving carts and NPCs add life to the world, so they should be real, visible things and not just numbers.
- **[Proposed]** Close up: fully animated NPCs, carts and machinery. Medium and far: simple shapes and basic motion (a wagon train crawling along a distant road, smoke from a mine). Beyond sight: schedule only. Distances and counts are graphics settings, so older machines can reduce them.
- **[Proposed]** Valheim-style simple models make large numbers of distant moving things cheap to draw.

### 11.4 Open questions

- **[Open]** How NPC miners dig: physically carving tunnels (many terrain edits to store) or drawing down a deposit's remaining ore as a number and extending tunnels in stages (much cheaper, but each deposit needs a permanent ID and a starting amount in the baked data).
- **[Open]** Whether ore deposits are finite or renew.
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
- **[Open]** Whether a ruined town can become a bandit stronghold.
- **[Open]** Whether a failing town can recover (bounties, adventurer help, aid from neighbors) or can fall for good. A robbed town has less money for guards and gets robbed more, which is a death spiral unless something breaks it.

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
- **[Open]** How overlapping town blocks are settled: first claim, nearest town block, or shared.
- **[Open]** What rights player residents of a town have (leave, protest, vote out the owner) or whether the owner rules unchallenged.
- **[Open]** How many tax levers there are: a few simple sliders (shop tax, farm tax, militia budget) or detailed rules for goods and groups.

### 13.2 Markets

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
- **[Open]** Whether orders are given through warehouse forms and menus, free conversation with the merchant that is translated into validated actions, or both.

### 13.4 Businesses

- **[Decided]** Reputation counts for the business, the owner and the manager.
- **[Proposed]** Warehouses, shops, smithies, inns, farms and mines share one **business structure**: an owner, a treasury, employees on wages, an inventory and taxes. Finance, wages, taxes, bankruptcy and the ledger are built once. Each workplace type is mostly a table of what it makes, uses and employs. The militia budget and town finances could reuse it.
- **[Proposed]** The value of goods on the road is the business's exposure. A sensible rule is that exposure should not exceed what its reserve could cover. The manager NPC refuses orders beyond it, and the owner can override at their own risk.
- **[Proposed]** The owner can set policies: reserve target, escorts per wagon, acceptable risk.
- **[Proposed]** A business that cannot pay shuts down. Its NPC staff lose their jobs and become displaced, which feeds the migration and rogue-NPC systems.
- **[Proposed]** The manager takes the reputation hit from a loss and might lose the job.
- **[Open]** Whether every workplace really does share the same business structure.

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

- **[Idea]** People buy the game for a reasonable price and pay a monthly subscription, roughly the same as World of Warcraft's.
- **[Idea]** Players can earn credits in game toward the subscription. A town earns credits for its owner and management team, more with more population and trade, encouraging people to run and grow towns.
- **[Idea]** The subscription can be reduced to a minimum of about $5 a month. Whether players could earn the whole subscription was left undecided.
- **[Idea]** NPC-run shops sell cosmetics with real money: skins, costumes, event items and other things that do not much affect play.
- **[Idea]** Players can buy in-game currency with real money. The project owner considers this fair because it is their own disposable income, while players who play all day earn credits in game. During testing the admins may buy credits too.
- **[Decided]** Gambling (including wagering at the pub) is flagged for a future discussion, to be revisited when that work starts.
- **[Proposed]** Credits created by the game cost real subscription revenue and give cheaters a cash incentive (fake trade between their own towns, extra accounts, bots), so they need strong anti-cheat, such as counting only trade with real, distinct players, plus caps.
- **[Proposed]** A token model avoids that: one player buys a token with real money and sells it for in-game currency, and another player uses currency to pay the subscription. EVE Online (PLEX) and World of Warcraft (WoW Token) work this way. The developer is paid either way and no new money enters the economy. Running a successful town would earn currency that buys tokens.
- **[Proposed]** Keep a subscription minimum, since every player costs real money to host, including the language model.
- **[Proposed]** Currency bought from the game buys real power in a player-driven economy (land, guards, armies) and adds inflation. Caps or the token model reduce both.
- **[Proposed]** Selling currency, and especially combining it with gambling, can fall under gambling, consumer protection and payment processor rules that vary by country. Get legal advice before any real money is involved.
- **[Proposed]** Until then, design the economy to work without real money. The whole-number ledger already makes a token model easy to add later.
- **[Open]** Whether earned credits come from the game or from other players through tokens, and whether a player can earn the whole subscription.

---

## 14. Current code status

From a read-through of the repository on 2026-10-11 (Godot 4.7, GDScript, about 29,600 lines, Voxel Tools).

**Already matches the vision**

- Deterministic per-tile generation with permanent tile coordinates.
- Resumable baking that skips finalized region files.
- Server-owned region catalog, complete-rectangle validation and wrap mapping.
- Region manifest with per-region revision, and canonical position mapping for persistent objects.
- A geology and hydrology pipeline: tectonics, folds, faults, strata, caves, minerals, erosion, rivers, lakes and surficial deposits.
- A baked, read-only base world with a note that player changes will live in separate save data.
- Ocean is classified at sea level without baking water voxels.

**Not built yet**

- Server-to-client streaming. The client reads region files locally. The server sends a welcome message and a manifest that the client does not act on yet.
- Any layer for player changes (the client voxel stream's save function does nothing).
- A "grow the world to this rectangle" command. Tiles are queued by hand.
- Any vegetation, climate, biome or soil system.
- An island properties panel, irregular coasts, or multiple islands per tile. The coast model produces one large rounded-square island per tile.
- Lair sites, or any structure placement.
- Players, NPCs, towns, building, law, economy, machinery, or any gameplay systems.

**Measured**

- Baking one tile takes about 15 to 16 hours (reported by the project owner). Where the time goes has not been profiled. Section 4.8 proposes changing what the bake produces.

**Not checked**

- Total disk size of one baked tile.
- How the current client performs on the minimum machine (Section 3).

- Whether individual mineral deposits have stable identities, which NPC miners drawing down a deposit would need (Section 11.4).
- Whether river flow data could be queried at runtime to power water wheels.

**Current values**

- World height: -4,000 m to +2,048 m, sea level 0.
- 7 LODs, 16-voxel data blocks, 1,024 m regions, 10 by 10 regions per tile.
- Rock types: sediment, shale, limestone, coal, granite. Resources: coal, iron, copper, tin, lead, zinc, nickel, silver, gold, salt, sulfur, clay, gypsum, graphite, gemstone, peat.
- Default server capacity: 32 clients.

**Compatibility warning.** The server rejects any world whose region files come from different generator versions. Once the generator gains islands, climate, soil, lair sites or structures, tiles baked earlier will need rebaking. Until the generator's feature set settles, tiles baked now should be treated as test tiles.

---

## 15. Open questions

World and bake

1. Seasons are decided. Should their strength grow with distance from the equator?
2. Should the world rectangle stay centered on the origin so the north-south wrap seam joins matching climates?
3. How much variety in island size is wanted, from tiny rocks to ARK-scale?
4. Is the world bottom at -4,000 m confirmed, with the lethal depth near -3,000 m kept adjustable?
5. Should the bottom kilometer be detailed for possible future content or baked simply?
6. How far should altitude effects reach, given the 2,048 m ceiling?
7. What limits diving, and can the deep ocean floor be dug?
8. Is mining the terrain itself in the first version?
9. Are ore deposits finite or renewing, and do NPC miners carve tunnels or draw down a deposit's amount?
10. How big should automation get, and how far away should simplified distant life appear?

Time and persistence

11. Does everyone age on the server clock (Section 6.1), or keep the slower offline aging speed? How long is the calendar year exactly (avoiding 7 or 14 days), and is age shown as a number or a life stage? (Section 7)
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
21. Do ruins last forever or decay, and can a ruined town become a bandit stronghold?
22. Are threats fixed lairs, roaming groups, or both, and can a failing town recover?

Towns, economy and platform

23. How are overlapping town blocks settled?
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

32. Do towns ever become server-owned later (for example abandoned player towns), or are all towns player-run? There are no starting towns.
33. How does NPC rescue work in practice, and how is it kept from trivializing death? Do NPC companions count toward party size and what do they cost?
34. Should the bake include coarse land-suitability layers (slope, fertility, water access) for the town planner, and can plans run unattended? (Section 8.4)

Farming, families, time and money

35. Do crop times follow realistic fractions of the year or get tuned for gameplay, and are hands paid by share, by wage, or the employer's choice? (Section 5)
36. Does the will decide who the player becomes, who owns the property, or both? Do long absences get a special rule? (Section 6)
37. 60 or 72 minutes per game day, and how dangerous is night? (Section 7.5)
38. Do earned subscription credits come from the game or from other players through tokens, and can a player earn the whole subscription? (Section 13.8) Gambling is flagged for a later discussion.

Map growth

39. What size is the first live world (one tile for testing, or several before players arrive), and which side grows first? (Section 4.7)
40. How far apart are the climate bands in tiles? This sets what surface materials get baked into every tile, so it must be settled before baking tiles to keep (Section 4.2).

Generator, hardware and hosting

41. Is realistic volumetric geology (faults, folds, intrusions) wanted for its own sake, or are rock layers by depth, caves and ore enough for gameplay? (Section 4.8)
42. Is runtime voxel generation on the server acceptable instead of reading everything from baked files? (Section 4.8)
43. Does terrain reach the client as streamed blocks, or as small maps the client generates from? (Section 4.8)
44. Can players host a world on their own machine? If so, one minimum-spec machine runs both server and client. (Section 3)
45. What frame rate and view distance should the minimum machine reach? (Section 3)

---

## 16. Candidate work, in dependency order

Nothing here is committed. It is a suggested ordering based on what affects baked data first, since baked changes force rebakes.

1. Decide the bake layering (Section 4.8, questions 41 to 43), measure where the current bake spends its time, and test the current client on the minimum machine.
2. Settle the open questions that change baked data: climate scale, seasons, world bottom, what the bake stores about soil and flora, whether deposits get stable IDs, how dormant lair sites are scored and placed, and whether to bake coarse land-suitability layers for the town planner (Section 8.4).
3. Generate the first playable island tile, then the island properties panel, irregular coasts, small islets and open-ocean tiles, then grow the rectangle one side at a time (Section 4.7).
4. Climate layer and soil or surface materials.
5. Flora placement lists written at bake time.
6. Natural structures: caves, mineshafts, labyrinths, ruins, dormant lair sites. Slate and any new rock types.
7. A planner that takes a target rectangle and bakes only the missing tiles.
8. Server-to-client region streaming and a layer for player changes.
9. Runtime systems on top of that foundation: harvesting, building and blueprints, characters and aging, NPCs, law and recognition, fire, towns, then production, threats, trade and banking.

Growing the generator first keeps the foundation solid. Most gameplay systems in Sections 5 to 13 live in the server layer and can be added later without rebaking terrain. They are also numerous enough that a small first playable slice will need to be chosen before building them.
