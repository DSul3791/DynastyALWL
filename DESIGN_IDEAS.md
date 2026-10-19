# Design Vision and Ideas

Record of the design brainstorming sessions from 2026-10-11 onward. This is a planning document. The world generator described in Section 14 is partly built; the game systems in Sections 5 to 13 are design only and no code exists for them yet.

**Revision history**

This list records what changed and when. Later entries override earlier ones, and the numbered sections below are always the current rules.

- **Version 1 (2026-10-11):** vision, world generation and bake, harvesting and farming, characters and heirs, NPCs and towns, soft law, building and fire.
- **Version 2 (2026-10-12):** added Satisfactory as an inspiration; production and logistics; road threats and pacing; town finances, markets, warehouses, trade routes, businesses, banking, letters of credit and forgery; crime memory, delayed discovery and disguises; inheritance of money and debt; the shared principles those systems rely on. Open questions and the work ordering were rewritten.
- **Version 3 (2026-10-12, later):** lifespan targets (start at about 15, die at about 80, in about 700 hours of play); families age with the player; the rescue-first philosophy and party composition; heirs arriving partly trained; the tension between server-owned towns and "no towns at the start"; and the clock arithmetic showing that one clock for aging and seasons is probably not workable. Open questions were updated.
- **Version 4 (2026-10-12):** two clocks decided (a world calendar for seasons and crops, and an aging clock); a one-to-two-week seasonal cycle; NPC aging at the average player's speed (70 years per real year); the weekly farming rhythm and a note on avoiding calendar years of exactly 7 or 14 days; Farming Simulator as an inspiration; no starting towns; and the civil engineer town-planning idea. The lifespan pacing figure changed from 65 to 70 years (15 to 85).
- **Version 5 (2026-10-12, evening):** the "play what you like" and "no micromanagement" goals; server-clock aging for everyone as an idea; children, twins, wills and choosing an heir; 60-minute game days, seasonal day length and night; the weekend farming rhythm, crop tiers, farm labor and work buildings; stock levels, the order chain and building maintenance; the budget for language model use and self-hosting; town roles, land and property; quests and pastimes; real-money ideas, with gambling flagged for later; and the plan for growing the tile map one side at a time.
- **Version 6 (2026-10-12, night):** minimum hardware target (older quad-core, 8 GB RAM, SATA SSD); the 15 to 16 hour tile bake and a proposal to bake 2D maps and generate voxels at runtime, with a table of what is baked, what the server works out and what the client does; language service hosting and scaling; NPC backgrounds, memory, honesty and conversation traits; a tile size of 15 by 15 regions (15.36 km) and a comparison with Atlas; a world-first sketch where islands come from ocean-floor features; a danger map; an islands-first tile pipeline; geology stored as a feature list with ore placed by how deposits really form; surveying skill and prospecting clues; the surveyor's book; a massive pre-planned world, an arid equator on the origin row and three climate zones with transition rows; tile downloads and the client tile cache; a developer-built starter town (replacing "no starting towns"); natural animal behavior; rarer flotsam; several starter tiles; a full-size world filled with placeholder ocean tiles; a matrix of tile specifications; a recommendation to start with voxel streaming; a square final world (proposed 21 by 21); polar sea ice; years of travel; the admin town warehouse; the town founding sequence from town block to planner, builders, roads and buildings; admin warehouse access, NPC production limits and worthless starter items; the 21 by 21 world confirmed; eight temperate starter tiles in an inner and an outer set; cool desert dugouts; and a pointer to the draft world format specification.
- **Version 7 (2026-10-14):** the generator work through climate, geology and ore, and natural caves (steps 10 to 12); the resource list (gems, marble, chalk, flint, alum, bitumen, graphite, bog iron, saltpeter) and the rule that every resource needs a use; renewable, semi-renewable and non-renewable resources; mine stability; quality tiers; reputation as personal and per viewer; admin town buying; duress, receivership and takeover; notifications; the free-to-play model; children, dynasty transfer, adoption and inclusion; the temple; town spirit and local weather; town decline, rubble and abandoned towns; contesting town claims; managers, remote control and in-world mail; the ultimate island; remains of the dead; resource passes and edge matching.
- **Version 8 (2026-10-14, cleanup):** removed superseded rules; unlabeled times are game time and real-time items are labeled (Section 7.1); succession and inheritance regrouped (Section 6.7); PvP zones are lawless; abandoned-town paths clarified; the wear rule with minimum integrity (Section 8.13); mine supports and abandonment (Section 11.2); the settlement ladder from camp to grand city, one camp at a time, and outpost sizes and points (Sections 8.10, 8.17); the seven-day remains timeline and the wizard retrieval service (Section 6.1); friends groups (Section 6.13); Section 15 reduced to open items only.
- **Version 9 (2026-10-15, audit passes):** homestead (a private home that starts as a tent and grows into estates and keeps, separate from the town ladder); abandoned homes (two game months unpaid, notice after the first; buyer chooses furnished or empty); no extra risk for being offline; who can raid whom (NPCs everywhere, players only in PvP zones); receivership of 14 real days; the temple (town owner builds one, a second at city stage); dropped items follow the remains timeline; roaming scavengers; role-weighted NPC rolls with variance; `DESIGN_REJECTED.md` and `DESIGN_PRINCIPLES.md` started; the nomadic household (wagon camp) logged as an open design item.
- **Version 10 (2026-10-16):** the owner's brainstorm with ChatGPT folded in as ideas to discuss (rescue director, short blackout and self-rescue, injuries, classless parties, companions who flee, countryside residents, rumors and newspapers, rare supernatural rescuers, journals and libraries, sixth sense, inner voice and instincts, a minimal HUD, NPC memory processing); real plus fantasy flora.

## How to read this document

Every item carries a status tag.

- **[Decided]** Stated or clearly agreed to by the project owner.
- **[Idea]** Raised by the project owner as a direction or wish ("we could...", "maybe...", "it would be nice to eventually..."), not yet firmly settled.
- **[Proposed]** Suggested by Claude during brainstorming. It was accepted in passing or not objected to, but never explicitly confirmed.
- **[Open]** A question that has not been answered yet. Section 15 collects them.
- **(brainstorm)** after a tag: the item came from the owner's brainstorming with ChatGPT (2026-10-16). There, **[Idea]** means the owner liked the direction, **[Proposed]** a suggested mechanism, and **[Open]** a question still to settle. None of it is approved: these are ideas to raise in design discussions and fold into the game where they fit.

When something is both a decision and a question, the decision is recorded in its section and the unresolved part appears in Section 15.

Ideas the project owner has turned down are kept in `DESIGN_REJECTED.md`, with reasons. Check it before proposing something new.

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
- **[Decided] Art direction (owner, 2026-10-17; a direction, not a task).** The long-term look is as good as or better than Valheim. Water, weather and lighting are ultra-realistic, like the near-photoreal AI videos the owner likes. The world itself looks like the best of old fantasy book illustrations. Characters fit that world but are more heroic, with just a hint of cartoon, like hand-drawn D&D characters in epic poses. No visuals change now.
  - **[Idea] What it implies for trees (suggestion only).** Trees are procedural today (trunk and leaf shapes built in code). Later, modeled tree variants per species with detail levels (full model up close, simpler shapes farther away, flat cards at a distance) would fit this look. Wind sway and seasonal color suit the lighting and weather goals.
- **[Decided] Sound stage (owner, 2026-10-17; a direction, not a task).** Content, visuals and audio count equally (`DESIGN_PRINCIPLES.md` Section 4). Someday the world should have a rich, full-spectrum sound stage: birds, water birds, waves, wind, cracking sticks, small animals, placed in space so a player can close their eyes and believe they are there, inspired by theHunter: Call of the Wild. Nothing is built yet.
  - **[Decided] Natural, muted colors (owner, 2026-10-17).** The first colors read as childish. Ground and foliage colors are muted toward natural earth tones; autumn tints are kept but less saturated.
- **[Idea] Inspection mode (owner, 2026-10-17).** The `/` key (with `?` on it) toggles inspection mode. While on, whatever the player looks at shows its name and its key information in the middle of the screen, in the same style as the status messages: Rock, Spruce Tree, Hemlock (Mild Poison), Iron, Coal, Bitumen. First version built (build 17): ground soil and rock, ore, trees, shrubs and plants, with the first listed property in brackets. **[Open]** Whether what it shows depends on what the character has learned (a herbalist recognizes poison, a beginner sees only "Plant"); today it shows everything.
- **[Decided] Inspection needs checks (owner, 2026-10-17).** What a character sees when inspecting is limited by what they know. The first time they look at a kind of thing: (1) a **memory check**: they may by chance remember it, and then it is added to their memory; (2) if not, a **horticulture and wisdom or intelligence check** (geology for rock and ore): a smart enough character knows they don't know and the label says **Unknown**; a character who fails it makes something up, such as **"Might be Nightshade"**, and keeps believing that until corrected. All plants and animals carry a **look-alikes list** (`look_alikes` in `flora.json`, seeded by real-world or visual resemblance; animals get the same field when they exist) and a wrong guess is drawn from it. First version built (build 19): placeholder character stats, a per-character notebook that remembers known things and wrong beliefs, a base **familiarity** chance (0 to 100 percent) on every inspectable table (`familiarity` in flora, soils, rocks, resources), plus 5 percent per point of memory, and admin look-around (flying) sees the truth. **[Open]** how a character is corrected (teacher, book, tasting, a second look with better skill), whether a wrong belief can cause accidents (eating the wrong mushroom), and whether looking again with better skill can overturn a guess. The look-alike lists for the fantasy species are guesses by Claude for the owner to review.
- **[Decided] Familiarity and look-alikes cover everything inspectable (owner, 2026-10-17).** Each thing has a base **familiarity**, the chance a character already recognizes it the first time: a 20 year old has surely seen strawberries and blueberries but may not know hemlock or chamomile. It is high at both ends: everyday things (a strawberry, a deer, sand) and famous or legendary ones (a dragon, a famous sword) that anyone would recognize, and low for obscure ones. The same system, with look-alike lists and the Unknown or "Might be" results, applies to animals, rocks and ore, magical weapons, legendary items and places. Seeded values are by everyday commonness with rarity as a guide, set by Claude and open to the owner's review (flagged: Valerian, Yarrow, Feverfew, Mugwort, Burdock, Tinder fungus, Lingonberry, Cloudberry). Items, animals and places are not built yet; they will carry the same `familiarity` and `look_alikes` fields.
- **[Decided] Light install, growing cache (owner, 2026-10-17).** The download stays as small as possible. The world is not shipped pre-built; ground is built and saved as each player travels, so local data grows with where they have been. Plan: a client cache size limit and a clear-cache control (`ARCHITECTURE_BUDGET.md` Section 7). The minimum target machine is a GTX/RTX 1050-class card, 8 GB RAM and a SATA drive; its frame-rate goal of 30 fps is **[Decided]** (owner, 2026-10-17); stronger machines can enjoy more.

---

## 2. Terminology

- **Region:** one 1,024 m by 1,024 m storage file holding all 7 LODs. It is the natural unit to stream from server to client.
- **Town block (town marker):** the marker a player places to claim a town. It has no physical form: it is a floating arrow only the owner can see, which the owner can switch on and off, and it creates an entry in the owner's ledger saying they own a claim. It is the centre of the town and the centre of its circle of influence. Town settings are reached through the town's office building, not through the marker (Section 8.17). An **outpost marker** works the same way for an outpost.
- **Island tile:** a block of 15 by 15 regions, 15,360 m (about 15.36 km) on a side. Each tile is baked on its own and addressed by a permanent integer coordinate. (The old generator still builds 10 by 10 tiles until it is retired.)
- The project owner sometimes says "chunk". Depending on context that means a region or an island tile.
- **[Decided]** Sizes are multiples of 1,024 because voxel data aligns best that way.
- **Game time and real time:** unlabeled times are game time; "real" is written out where a rule is tied to the player's life (Section 7.1). A **game month** is about 30 real hours; a **real month** is calendar time.
- **Established town:** a camp with two guards, or a larger claim with a manager building, a guard building and the first guard wages paid (Section 8.18). Established towns are PvE except inside PvP zones.
- **Spirit:** a town's mood, 0 to 100 (Section 8.12).
- **Settlement ladder:** the stages of a claim and the radius of its circle of influence: camp 150 m, settlement 200, hamlet 300, village 450, town 675, city 1,000, grand city 1,500 (Section 8.17). A new claim starts as a **camp**. Only a hamlet and above has homes and villagers.
- **Homestead:** a private home that starts as a tent (a homestead camp) and can grow into a bigger home such as an estate or keep. It is not a town and is not on the settlement ladder (Section 8.17).
- **Friends group:** a group above the dynasty where friends join to see each other, talk and share permissions without sharing a dynasty (Section 6.13). Other groups are the **adventuring party** (temporary) and a **town** (its residents).
- **Duress:** stress on a neglected dynasty, 10 percent for each full real month away (Section 6.1).
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
- **[Decided] Safe, kind, generous, in that order.** The game is built on the idea that people should be safe, then kind, then generous. If you cannot be generous, be safe and kind. If you cannot be kind, at least be safe. If you cannot manage all three, remove yourself from the situation. Systems for safety (protection from abuse, ways to leave a bad situation), kindness (rescue, understanding, second chances) and generosity (gifts, charity, adoption, helping struggling dynasties) are treated as core design, not extras.
- **[Decided] We do not dictate relationships.** A spouse can be any gender, and the game supports couples of any kind. Where a couple cannot have children, the game offers adoption and other routes (Section 6.9). The goal is to be understanding and inclusive.
- **[Decided] Every resource needs a use.** A resource, rock or material is added only when we can say what it will be used for in the game. Nothing is added just because it exists in the real world.
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
- **[Proposed]** Implemented: the starter island itself is drawn at the target size (inner 64 to 78 km², outer 86 to 104 km² before coastline roughness), and a 1.2 km strait at least 80 m deep is cleared around it so shelf hills stay separate satellites instead of merging into one huge landmass. Current sizes: inner 54, 81, 89, 96 km²; outer 72, 81, 138, 148 km². A test keeps every starter in range.
- **[Decided]** Like Atlas, there are several starter towns, since the map is so big, so people can coordinate with friends when they first log in. Inner set at (-3,4), (3,4), (-3,-4), (3,-4); outer set at (-6,6), (6,6), (-6,-6), (6,-6). (The outer set was first proposed at columns ±8, row ±5, and moved inward so it sits in the medium danger zone, Section 4.13.) Each outer starter is about 3.6 tiles (55 km) from the nearest inner starter, and 4.5 tiles (69 km) from the deadly east-west edge. Row 6 is the last temperate row, so the outer starters are a little cooler. The desert center is left for players to expand into.
- **[Decided]** For testing, one starter town is enough: tile (3,4) and its surrounding tiles, until the game runs with terrain and flora (owner, 2026-10-16).
- **[Proposed]** Open the inner set at launch and the outer set as the population grows. With placeholder ocean tiles, starter tiles can be baked first.
- **[Proposed]** Traversal: crossing 322 km is tens of hours on foot and, at Atlas's roughly 7 km/h (derived from its 30 hours for about 212 km), about 46 hours of sailing. Ship speeds are not yet set. "Years" comes from exploring: a few hundred island tiles of up to ARK scale, at many hours each, is thousands of hours, several years for a player at 12 to 16 hours a week.
- **[Proposed]** A tile with zero islands is simply an open-ocean tile. This gives ships real distances without any special system.
- **[Proposed]** Irregular coastlines with small offshore islets, instead of the current rounded-square outline.

Neighboring tiles agree because they read the same world data (the world elevation map, world-coordinate noise and the world river network), so islands may cross tile borders and no empty lanes of ocean show the grid (Sections 4.12 and `WORLD_FORMAT_SPEC.md` 4b).

### 4.2 Climate

- **[Decided]** Climate is driven by distance north or south from the origin tile. The origin is the equator (hottest). Climate cools gradually toward the poles.
- **[Decided]** The world is 21 rows tall (Section 4.1), which sets the width of each zone.
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
- **[Decided]** Seasons exist. Characters experience spring, summer, autumn and winter (Section 7.2).
- **[Idea]** Weather affects how things grow and what work can be done. Soil that is too dry or too wet cannot be worked.
- **[Idea]** Regions specialize naturally. Too far north and the soil is too cold for some crops. Too close to the equator and it is too dry. Hot regions suit camels and desert plants. Temperate regions suit horses, sheep, pigs and cows. In the extreme cold, people survive by fishing, hunting seals and other creatures, and mining.
- **[Proposed]** Weather is calculated from the world seed and the server clock, so every client works it out itself with no network traffic, and everyone sees the same rain.

Note: climate depends only on position, so each tile can compute it without looking at neighbors, which matches how tiles already work. Anything baked into a tile (surface materials) is permanent, so the climate curve should be settled before many tiles are baked.

### 4.3 Soil, flora and fauna

- **[Decided]** Soil and surface materials are baked.
- **[Decided]** Trees and other plants are **objects, not voxels**.
- **[Decided]** Flora placement is worked out at runtime from the biome map and a per-tile placement seed. Only removals are stored. The map grid is 8 m.
- **[Decided]** Grass is never stored or synced. The client draws it near the player only, driven by ground type and a quality setting.
- **[Decided]** Fauna is server-controlled spawning, based on climate, biome and terrain. It is never baked.
- **[Decided]** Animals run on simple, classic programmed AI (not the language model), improved gradually over time with AI help. Behavior must not be ridiculously predictable or unnatural: a deer jumps and runs away when spooked, and a troll does not stomp around turning its back on you because it needs to walk around a tree.
- **[Proposed]** Animal behavior built from perception (sight cones, hearing, smell carried by the wind), a short list of weighted needs (graze, flee, hunt, guard, rest), and steering. Steering lets a creature move around obstacles while still facing its target, so a predator sidesteps a tree instead of turning away. Herds react together and some individuals startle first. A little randomness in timing keeps it unpredictable. All of this runs on the server with simulation level of detail; the client only animates and smooths movement.
- **[Decided]** Fantasy (Dungeons and Dragons style) species.
- **[Proposed]** A removed tree is recorded as "item N in region R is gone." Because each tile freezes its generator version, placement never shifts under existing removals.
- **[Proposed] Built first version (plan step 15, 2026-10-16).** Species live in a data table (`data/tables/flora.json`): density per biome, moisture, slope, altitude and water limits, size, and yields for harvesting later. Placement runs per 256 m chunk; the "region" of a removal is the chunk and the item number is the species plus its grid cell, so adding a species or cutting a tree never moves anything else. Woods are patchy (glades with more shrubs). The server works flora out and sends it to clients like terrain, minus removals; clients never need the tile files. First species are real-world (oak, beech, pine, spruce, birch, alder, willow, palms, hazel, bramble, gorse, heather, reeds, wild flax for fibre and rope, ferns, nettles, mushrooms and so on); fantasy species can be added to the table later.
- **[Proposed]** The density setting changes item numbers, so it must be frozen once players start cutting trees in a world.
- **[Decided]** Flora is rich in edible and useful wild plants: berries (blueberry, strawberry, raspberry, blackberry and more), culinary and medicinal herbs, edible roots, greens, nuts and mushrooms. It must be rich enough that a player can make a living gathering plants and selling them or making potions, sauces, food and ointments (owner, 2026-10-16).
- **[Decided]** Real plants plus fantasy additions (owner, 2026-10-16).
- **[Decided]** Many fantasy plants, because they keep the world alive and give a reason to explore. Even a veteran who has mapped everything around them should one day stumble on a rare plant or herb that is extremely valuable (owner, 2026-10-16).
- **[Decided]** (owner kept them all, 2026-10-16) 42 fantasy species (`"fantasy": true` in the flora table), each with a magical use, named to avoid clashes with other games (checked by web search; six first names were changed). Rimecap is also a homage (Section 6.12). By rarity:
  - Common: dewlantern (glowing dew at dawn), honeyspindle (nectar for mead), marrowroot (filling root, stamina), riverbraid (river reed for waterproof rope), brinebell (seaside preserving salt), sleetberry (winter berry, cold resistance).
  - Uncommon: emberroot (warmth, fire resistance), rimecap (cold resistance), drakethorn (strength berries), sunberry (vitality), hushfern (sleep, visions), gloomthistle (wards off spirits), tideglass weed (water breathing), quenchbell (tempering for smiths), whisperfern (keen hearing), cinderfoot (burn healing), duskmallow (calming, opens at dusk), tanglewort (snares and binding), stormreed (lightning ward), staunchmoss (stops bleeding), lumencap (glowing mushroom, arcane, night).
  - Rare: owlpetal (night sight, night), wispbloom (glowing marsh reed, night), mirrorbark (warding tree, wand wood), wardpine (resin wards off ghosts), hag willow (bog-witch hexes), heartroot (revives a downed character), truthsage (tea that makes lying hard), mirrorcap (disguise, night), echo moss (carries a voice for messages), hearthwood (wood that burns for days), nightcrown (high-mountain night flower, arcane), mournbloom (see spirits, night), pilgrim's cup (pitcher of clean water, antidote).
  - Very rare, worth recording as a discovery: sunsilver vine (gilding dye), frostglass orchid (stops decay), sevenyear lily (flowers once every 7 game years, longevity), stillwater lotus (lake lotus, prophecy).
  - Legendary, a few per tile: gloaming star (blooms only at dusk, luck), everember (tree with ember leaves, revival), witness tree (giant tree whose bark shows the past), tidecrown (shore reed that grows pearls, water breathing).
- **[Decided]** (owner, 2026-10-16) **Discoveries.** A very rare or legendary plant is a discovery: the finder can record it in their journal (Section 6.15), name it, and then guard it (claim the land around it as an outpost, Section 8.17), harvest it in secret, or sell the secret (a map or journal page, or a tip to a library or herbalist). Rarity is placement density only for now; time of day (`time_of_day`), discovery and the seven-year bloom are data that later systems will read.
- **[Decided]** How deep gathering and crafting go: an easy floor and a deep ceiling (Section 5.3).
- **[Proposed] Built (2026-10-16).** The flora table now has 83 species, 55 of them added for gathering: berries (blueberry, lingonberry, cranberry, cloudberry, wild strawberry, raspberry, crowberry, elder, rowan, rose hips, sloes, haws, sea buckthorn), fruit and nut trees (crab apple, wild pear, wild cherry, sweet chestnut, walnut), kitchen herbs and greens (wild garlic, thyme, water mint, sorrel, dandelion, wild carrot, watercress, samphire, marjoram, sage, rosemary, lavender), healing herbs (yarrow, plantain, chamomile, comfrey, St John's wort, valerian, meadowsweet, feverfew, burdock, mugwort, arnica, angelica, aloe), poisons and potion reagents (foxglove, deadly nightshade, wolfsbane, henbane, fly agaric), mushrooms (chanterelle, porcini, morel, puffball, tinder fungus) and warm-climate food plants (wild banana, date palm, prickly pear). Each species lists its yields, season, rarity, uses (food, sauce, tea, brewing, medicine, ointment, potion, poison, dye and so on) and properties (wound healing, fever, sleep, toxic and so on) for the gathering and crafting tables to come. A 1 km square of the starter tile holds 55 species. Fantasy (Dungeons and Dragons style) herbs can be added to the same table later.
- **[Proposed]** Seasons are data only for now: plants are always placed, and the season says when their yield can be gathered. Using it waits for the world calendar.
- **[Proposed]** Climate and soil should also be queryable at runtime from the same function the generator uses, so the server and generator never disagree. This matters for farming.
- **[Proposed]** Slate as a new rock type (shale metamorphoses into slate), tied to folded or deformed regions. Slate would make some islands valuable for roofing.
- **[Decided] Tree colors (Dave, 2026-10-17).** Hardwood (broadleaf) trees get gray trunks and one autumn leaf color each (yellow, gold, orange, red, crimson, rust), fixed per tree. Softwood (conifer) trunks are dark brown. Built in the stand-in meshes; real models later.
- **[Decided] Balsam fir (Dave asked for it and accepted the models, 2026-10-18).** First species with its own procedural model (`model: "balsam_fir"` in flora.json, `_balsam_fir` in `src/flora/tree_builder.gd`), built from field-guide descriptions of New Brunswick's provincial tree: 12 to 21 m, a narrow dense cone ending in a slender spire, level whorled branches that droop low and lift high, flat layered sprays, dark green, dark purple cones standing upright on the top branches, and trees in a stand keep a few dead twigs below a higher live crown. From Dave's photos (2026-10-18): not as even as a pine (boughs differ in length, some missing), the lower crown often bare on one side and thin on the other, and young trees bright green, darkening with age (`young_color` by height). Bark is smooth ash gray browning with age (true to life), an exception to the dark brown conifer trunk rule above (Dave's photos show gray trunks; models accepted 2026-10-18). Grows in boreal and mixed forest on damp ground. Preview: `src/worldgen/tools/tree_mesh_dump.gd` then `tools/render_trees.py`.
- **[Proposed] Birch (Dave asked for it with summer, autumn and winter photos, 2026-10-18).** Own procedural model (`model: "birch"`, `_birch` in `src/flora/tree_builder.gd`): a slim chalk-white trunk with dark lenticel dashes and black patches (`assets/trees/bark_birch.png`), black and rough at the foot; the trunk carries on as a leader; limbs leave steeply, arch out and droop at the tips, with curtains of fine dark twigs and small leaves hanging from them, giving an airy oval crown. Variants: open grown (low broad crown), stand grown (high narrow crown), and a leaning one of each. Autumn leaves are golden yellow (`autumn_colors` in flora.json, picked instead of the shared autumn palette). A bare winter model exists (`season == "winter"`, twig curtains from `twig_birch.png`) for when seasons arrive; the game shows autumn for now. White bark is an exception to the gray hardwood trunk rule, from Dave's photos.
- **[Proposed] Sugar maple (Dave asked for it with summer, autumn and winter photos, 2026-10-18).** New species `maple` (id 126, temperate and mixed forest) with its own model (`_maple` in `src/flora/tree_builder.gd`): a stout, straight gray-brown trunk forking about a third of the way up into a few big limbs climbing in a vase, splitting again and again into a dense, broad, rounded crown; open-grown and stand-grown variants. Autumn leaves fiery red, orange and yellow (`autumn_colors`); a bare winter model of fine upright twigs is ready for when seasons arrive. Yields wood and spring sap for syrup and sugar.
- **[Proposed] Wardpine model (from Dave's summer, autumn and winter picture, 2026-10-18).** Own model (`_wardpine` in `src/flora/tree_builder.gd`): an ancient, massive pine with a short, thick trunk twisting with ropey ridges, great roots over the ground, heavy crooked limbs from low down and a broad rounded cone of layered, tufted needle pads turned up at the ends. Its needles turn fiery orange, red and gold in autumn (`autumn_colors`; a conifer with autumn colors is tinted like a hardwood) and it keeps them in winter. Summer color made a fresher green to match the picture.
- **[Proposed] Scots pine model (from Dave's summer, autumn and winter photos, 2026-10-18).** Own model (`_scots_pine` in `src/flora/tree_builder.gd`): a tall, straight trunk bare for half its height, thick gray-brown plated bark low down turning orange-red higher up and on the limbs, a few dead stubs below the crown; long nearly level limbs curving up at the ends with blue-green needle tufts, making an open, irregular, round-topped dome. Evergreen, the same in every season. Open-grown and stand-grown variants, each also leaning.
- **[Proposed] Spruce model (from Dave's summer, autumn and winter photos, 2026-10-18).** Own model (`_spruce` in `src/flora/tree_builder.gd`): a straight brown trunk under a narrow, dense, dark green cone with a sharp spire; boughs slope down from the trunk and turn up at their ends (Dave's point), with curtains of branchlets hanging below; full nearly to the ground on open-grown trees (bottom 4 feet bare), higher crowns on stand-grown ones. Evergreen.
- **[Proposed] Oak model (from Dave's photos, leaf photos and notes, 2026-10-18).** Own model (`_oak`, lobed leaf texture `leaf_oak.png` via `"leaf": "oak"`): truly large shade trees, common but sparse (fewer per hectare, 9 m spacing radius); a short, massive, rugged trunk 1 to 2 m across with twisted furrows, splitting low into heavy crooked limbs; a broad dome 12 to 24 m wide; golden-brown and orange autumn; a dense tangle of crooked twigs in winter. Oak and beech differ mainly in trunk and leaf (Dave), not crown.
- **[Proposed] Beech model (from Dave's mature and young beech photos, 2026-10-18).** Own model (`_beech`, smooth gray bark texture `bark_smooth.png`): a mature beech has a massive trunk fluted and buttressed at the foot, splitting into many climbing limbs under a huge, dense, rounded crown; a young beech is a slim straight pole with a leader and short climbing limbs, an airy upright crown. Copper-orange autumn. Height range widened to 6 to 28 m so young trees appear; trees under 14 m (`young_below_m`) use the young variants.
- **[Proposed] Alder model (from Dave's young and mature alder photos, 2026-10-18).** Own model (`_alder`): gray bark with paler patches; most alders grow two, three or four trunks from the ground and only a few have one (Dave); the stems lean apart into one airy rounded-oval crown; young stems are slim with sparse short limbs; leaves turn only a dull yellow-green in autumn; dark catkins on the bare winter twigs. Trees under 11 m use the young variants.
- **[Proposed] Weeping willow model (from Dave's young and mature willow photos, 2026-10-18).** Own model (`_willow`, hanging-strand leaf texture `leaf_willow.png`): curtains of narrow-leaved strands hang from every limb nearly to the ground; golden yellow in autumn; bare hanging strands in winter. Mature: short, thick, dark furrowed trunk splitting low into big limbs that climb and arch out into a broad dome. Young: a slim stem with lighter limbs, strands hanging to a third of its height. Height range 5 to 16 m; under 9 m uses the young variants.
- **[Proposed] Rowan model (from Dave's young and mature rowan photos and flower and berry close-ups, 2026-10-18).** Own model (`_rowan`, compound-leaf texture `leaf_rowan.png`): orange-red autumn leaves; big scarlet berry clusters in autumn (what the game shows now) and flat creamy flower heads on mature trees in summer, both drawn a little larger than life so they read; mature trees fork into a rounded crown, young ones are slim stems with an airy crown (under 8 m).
- **[Proposed] Wild apple model (from Dave's young and mature photos in all four seasons, 2026-10-18).** Own model (`_wild_apple`): a short scaly gray-brown trunk splitting low into crooked limbs under a broad rounded crown; white blossom flushed pink in spring, small red apples on the crown's outside in autumn (what the game shows now) and a few left in winter, drawn about twice life size so they read; yellow-orange autumn leaves. Young trees (under 6 m) are slim stems with a light crown. Height range 4 to 10 m.
- **[Proposed] Wild pear model (from Dave's young and mature photos in all four seasons, 2026-10-18).** Built on the wild apple model (`_wild_apple` with `pear`): a taller, more upright crown, dark rugged bark broken into blocks, pure white blossom in spring, small green-gold pears with a russet blush hanging inside the crown in autumn (about twice life size), yellow-gold autumn leaves. Young trees under 8 m are slim stems; height range 4 to 15 m.
- **[Proposed] Sugar maple model (from Dave's young and mature photos in all four seasons, 2026-10-18).** The existing maple (id 126, already yields sap for syrup and sugar) is now the sugar maple: five-lobed leaves (leaf_maple.png), open-grown and stand-grown mature trees with crowns reaching low, and young trees under 10 m as slim pale stems with airy upright crowns; height range 5 to 26 m.
- **[Proposed] Wild cherry model (from Dave's young and mature photos in all four seasons, 2026-10-18).** Built on the wild apple model: a taller clear trunk of smooth gray bark with darker horizontal bands, a rounded crown, in spring the whole crown light purple blossom with no green leaves (Dave), bunches of red cherries in summer and autumn, orange-red and yellow autumn leaves. Young trees under 8 m are slim stems; height range 4 to 18 m.
- **[Proposed] Sweet chestnut model (from Dave's young and mature photos in all four seasons, 2026-10-18).** A thick trunk with deep furrows spiralling up it, a broad rounded crown, long creamy catkins in spring and summer, spiny green burrs holding brown nuts in autumn (drawn about twice life size), golden-brown autumn leaves. Young trees under 10 m are slim stems; height range 5 to 24 m, crown about 16 m across.
- **[Proposed] Walnut model (from Dave's young and mature photos in all four seasons, 2026-10-18).** Built on the chestnut model: a broad, open, rounded crown on a thick pale-gray trunk with straight deep furrows, compound leaves, long yellow-green catkins on grown trees in spring, golden-yellow autumn leaves with green husked nuts. Young trees under 9 m are slim stems; height range 5 to 22 m.
- **[Proposed] Mirrorbark model (fantasy, from Dave's pictures in all four seasons, 2026-10-18).** Shaped like an ordinary hardwood with green leaves turning orange in autumn, but the bark is polished chrome: a fully metallic, mirror-smooth material (`chrome`) broken into faceted patches that each catch the light differently, on a trunk whose strands twist like rope as it climbs. Leaf color changed from silvery to green to match the pictures. Young trees under 8 m are slim stems; height range 4 to 20 m. The mirror look needs checking on a real GPU.
- **[Proposed] Hearthwood model (fantasy, from Dave's description and pictures, 2026-10-18).** Tall and straight like a softwood: a perfectly round trunk 30 cm (12 in) across for most of its height, tapering only in the crown, in tight reddish-brown bark with fine vertical ridges; a clear central leader; many thin light limbs instead of a few heavy ones; small oval leaves in a narrow, elongated crown; light green in spring, amber, copper and golden orange in autumn. Best firewood tree and good for strong beams (`beams` added to its uses). Logs per tree are not modeled yet: when harvesting tables come, a hearthwood should give many more good-sized logs than other trees. Young trees under 10 m; height range 5 to 26 m.
- **[Proposed] Everember model and groves (fantasy, from Dave's description, pictures and night forest scene, 2026-10-18).** Follows his numbers: mature trees 70 to 110 m on trunks about 6 to 7 m across with huge buttress roots and heavy vertical ridges, foliage only on the upper half in a high narrow cone; a quarter are young (8 to 20 m, slim, densely branched nearly to the ground). Dark bark with glowing amber-red veins in an emissive `ember` material, strongest at the roots and running up the trunk into the biggest limbs; near the player one warm light per 24 m of grove lights the ground (at most 24 per chunk). Placement: grows only in groves (new `grove` field: trees about 11 m apart, grove radius 90 to 150 m, so roughly 200 to 600 trees; one grove square every 4 km with a 35% chance). Yields now include glowing `everember_sap` (tapping to come). Collision uses one trunk size scaled by height, so young trees get a wider trunk collider than they look; to fix when harvesting arrives. Glow and lights need checking in a night playtest. One grove is placed by hand about 1 km west-north-west of the tile 3,4 spawn (grove `fixed`, about 360 trees) so it can be visited from the starter town. Grove species and the witness tree (`place_first`) now claim ground before the common woods; before that the witness tree never found room.
- **[Proposed] Woods that grow like real woods (Dave, 2026-10-18).** Built in the runtime placer (`flora_placer.gd`).
  - **Spacing:** big mature trees stand apart (spacing grows with tree height, up to 12 m), while young trees crowd close but never nearer than 6 ft.
  - **Stands:** birch grows in stands of hundreds about 10 ft apart (plain birch cut to a third). Alder and young balsam fir and spruce form thickets 2 m apart.
  - **Shade:** no young trees grow under a dense crown. Under a light crown (birch, alder, pines, fruit trees) shade-tolerant young trees (firs, beech) grow freely and others only now and then.
  - **Shrubs:** three times as many, no longer pushed out of the woods, and allowed under trees, keeping clear only of trunks.
  - **Draw distance:** cut to pay for it, from 560 to 420 m for trees and from 300 to 160 m for shrubs.
  - **Measured over the 13 by 13 chunks around the starter spawn:** trees per chunk 234 to 318, shrubs 111 to 535, trees drawn around the player about 3,500 to 2,700, shrubs drawn about 480 to 660, and placement 89 to 140 ms per chunk.
  - **Note:** item ids change, which is fine before launch but must be frozen once players cut trees.
- **[Proposed] Common hazel (Dave's 8-panel and notes, 2026-10-19).** Hazel is a woodland understory clump, not a tree: many slender smooth gray-brown stems rise from one root base and fan out like a vase into a broad, rounded, dense crown. Long pale yellow catkins hang in early spring; summer is dense green; autumn turns golden yellow with clusters of brown nuts in frilly leafy husks; winter is bare stems with next spring's tight red-brown catkins hanging. Mature clumps are 4 to 7 m tall (about 5 m on average) and about 4 m wide; 30% are young at 1 to 2.5 m.
  - **Placement:** hazel grows mostly in groups of about 3 to 12 clumps a few meters apart; one group in five is a thicket of 20 to 50 clumps 2 m apart, with a few scattered clumps between. Near the starter spawn that is about 110 clumps per 256 m chunk of forest, two thirds of them in groups. Each clump has a small stool collider.
  - **Not built yet:** dense hazel should slow movement and block sight, most in summer. No movement-slowdown or sight hook exists yet; add one when ground cover gets movement effects.
- **[Proposed] Witness tree model (fantasy, from Dave's design and pictures, 2026-10-18).** Mature trees are 18 to 28 m with a straight trunk 60 to 120 cm across, gracefully spreading limbs and a broad rounded crown. Bark is smooth silvery gray with a violet undertone; mature trees add shallow swirling grooves and 2 to 4 knots like half-closed eyes. Leaves are oval, finely toothed and violet-veined (`leaf_witness.png`), with the odd faint eye mark. Pale purple flower clusters come in spring, autumn turns violet, burgundy and crimson, and the tree is bare in winter. At night the leaves glow soft lavender: the `witness` leaf material is emissive, young trees glow weakly, and a faint purple light sits in each mature crown near the player. Young trees are 4 to 8 m (30% of them) and slim. The tree is now uncommon and scattered singly (was legendary at 1 per 10 km^2; now about 1 per 25 to 30 ha of temperate forest). The glow needs checking in a night playtest.
- **[Proposed] Witnessleaf tea: Truthsight and Veilsight (Dave's design, 2026-10-18; not built yet).** Witness tree leaves brewed as tea temporarily sharpen perception. Drying and preparing the leaves concentrates them; fresh leaves brewed at once are weak.
  - **Truthsight** comes from autumn leaves. For 15 to 30 game minutes, a speaker who knowingly lies shows a faint red aura. It detects intent, not accuracy: an honest mistake or withholding without a false statement shows nothing.
  - **Veilsight** comes from spring leaves. For 15 to 30 game minutes, hidden or magically concealed things show subtle shimmering purple outlines: invisible creatures, concealed doors and passages, hidden compartments, magical traps, some illusions and deliberately concealed objects in view. It never sees through solid walls.
  - **Summer leaves** make weaker, balanced versions of either tea. Winter has no leaves, so no harvest.
  - **Overconsumption** temporarily brings distorted colors and patterns, false shimmering outlines, trouble telling real effects from distortion, sensitivity to bright light, and less reliable Truthsight and Veilsight.
  - **Uses:** investigators, magistrates, merchants checking agreements, adventurers in ruins, guards, thieves. The seasonal potency gives a reason to revisit known trees through the year. Durations, harvesting rules, rarity and limits are starting values for balancing. In flora.json the tree now yields `witness_leaves` and lists `truthsight_tea` and `veilsight_tea` uses and `truthsight` and `veilsight` properties.
- **[Decided] Hardwood crowns reach low (Dave, 2026-10-18).** A hardwood's canopy covers the top three quarters of the tree; only the bottom quarter of the trunk is bare. Applied to the generic broadleaf, birch, maple and oak (low "skirt" limbs that droop at the ends).
- **[Decided] Leaves let light through (Dave, 2026-10-18).** Autumn leaves are about 60% opaque, so a crown with the sun behind it glows: the foliage shader passes about 40% of the light through (backlight; less for needles and grass, none for bare twigs).

### 4.4 Natural structures and lair sites

- **[Decided]** Caves, abandoned mineshafts, labyrinths and similar discoveries, as in Minecraft.
- **[Decided]** The world generator places natural caves now (step 12). Abandoned mineshafts and labyrinths come later as add-ons.
- **[Proposed]** Underground structures are baked as real voxels, since players can dig into and through them. They become destinations for NPC quests and bandit camps. If the layering in Section 4.8 is adopted, only each structure's site (position, type, seed) is baked, and the server carves the voxels from it with the same deterministic generator as the rest of the terrain.
- **[Decided]** Towns are **not** baked. Players found towns (Section 8).
- **[Decided]** Eventually a threats system will pinpoint areas that make natural bandit camp places. Premade goblin camps can also be dropped in like a blueprint, creating a small cave system filled with goblins (Section 12).
- **[Proposed]** At bake time the generator scores natural hiding spots (caves, ruins, ridgelines, forest edges: defensible and out of sight) and places **dormant lair sites**: empty caves and camps that nobody lives in yet. At runtime the server only changes a site's state ("site 14 is held by a goblin horde"). That needs no terrain editing and no client download.
- **[Idea]** People in extreme cold may build underground bases and grow things that need no light, such as mushrooms.
- **[Proposed]** Cave generation should include some large, usable caverns and not only narrow tunnels, so underground bases and farms are possible.
- **[Decided]** Caves come with inherent danger. They house creatures such as bears, snakes and bats. On starter islands these are low level, but still dangerous for a new player with no skills or gear; danger rises with the region's danger level (Section 4.13).
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

### 4.6 Expansion and wrapping

These were built in the old generator and are kept by the new one, except where noted:

- Each tile's seed is the SHA-256 of the world identity seed and the tile coordinate. Tiles do not read their neighbors' files; they agree because they read the same world data.
- Finalized region files never move or regenerate. The builder skips them.
- The server scans every header at startup, rejects mixed generator versions or seeds, requires a complete rectangle with no holes, and publishes the authoritative wrap bounds.
- The world wraps in both directions at the outer edge of the rectangle. Wrap-seamless noise and edge matching make the seam invisible (`WORLD_FORMAT_SPEC.md` Section 4b).
- Expanding the world takes effect when the server restarts.
- Persistent objects are saved as source region plus local position, so they survive later expansion.

The new world is planned at its full 21 by 21 size from the start, centered on the origin, so the north-south wrap joins arctic to arctic.

### 4.7 Growing the map

- **[Decided]** Work starts with the map. The first step is to generate a first island tile that lets people get started.
- **[Decided]** After that, the generator keeps creating unique tiles over time, with different sizes and numbers of islands.
- **[Decided]** Because the world wraps at its edges, the set of tiles must always stay a complete rectangle, and growth has to be planned with that in mind.
- **[Proposed]** Alternate opposite sides as the world grows (north then south, east then west), so the origin tile stays near the middle. That keeps the equator central and makes the north-south wrap seam join two equally cold edges.
- **[Proposed]** A new row or column is baked into a staging folder and only goes live, at a server restart, once the whole row or column is complete. The existing builder and server already work this way (GENERATION_GUIDE.md).
- **[Proposed]** Because growth is rare, new rows and columns can be baked on a separate machine and copied into the staging folder, so baking never competes with the running server.

### 4.8 Bake time and where work happens

The draft of the permanent formats (world settings, tile file, tile matrix) is in `WORLD_FORMAT_SPEC.md`.

- **[Decided]** Baking one tile with the old generator took about 15 to 16 hours (measured by the project owner). An efficiency review was started elsewhere but nothing was changed.
- **[Proposed]** That cost does not fit a world that grows by adding unique tiles, especially since any generator change forces a rebake. The likely cause, from reading the code (not yet profiled): the bake fills a complete 3D volume from +2,048 m down to -4,000 m at all 7 LODs, using simulated geology (tectonic deformation, faults, folds, igneous intrusions, strata, caves and minerals) evaluated voxel by voxel in GDScript. The output is probably also many gigabytes per tile, which conflicts with the minimum hardware target (Section 3) if clients must hold it.
- **[Proposed]** Keep the foundation, change what the bake produces. Keep: the region format, catalog and mapper, wrapping, tile seeds, the complete-rectangle check, the resumable atomic bake, the coast model and the 2D hydrology (ocean mask, flow, lakes, channels on the 8 m grid). Change: the bake writes compact 2D maps per tile, and voxels come from a fast, deterministic generator at runtime. Volumetric folds and faults are dropped or simplified, since players will not notice them. Mining to about 3 km needs rock layers by depth, caves and ore, which can be simple functions of the maps and seed.
- **[Proposed]** Voxel Tools appears to offer native generators (a graph generator, or one driven by a heightmap) that should be far faster than per-voxel GDScript, and to store only edited blocks. Both claims need checking against the Godot 4.7 build in use.
- **[Proposed]** Each generated block is saved once on the server (an SQLite-style store), so it is never generated twice.
- **[Proposed]** Each tile records the generator version it was created with, and that version is frozen once players have built there, so a later generator change cannot alter terrain under existing buildings. New tiles can use newer versions. This replaces the current rule that rejects mixed generator versions.

- **[Decided]** The new generator follows this plan: it bakes compact 2D maps and lists per tile (about 2 minutes for the starter tile, Section 14), and voxels come from a runtime generator (plan step 14).

**[Proposed] What lives where**

| Layer | Contents | Why |
|---|---|---|
| Baked once per tile, permanent | Tile seed and generator version; height, coast, rivers and lakes; climate zone; soil and biome class; sites for caves, mineshafts, labyrinths and dormant lairs; possibly deposit identities and land-suitability layers | Defines the place. Changing it later moves coastlines and landmarks under players. Small: about 1,921 by 1,921 samples per map at 8 m. |
| Server, deterministic from the baked maps | Voxel fill, rock layers by depth, caves, ore, structure carving, fauna spawning, plant growth, weather | Cheap to produce on demand. Frozen per tile once players build there. |
| Server, living layer | Voxel edits, removed trees, buildings, NPCs, crops, economy | Changes constantly. Saved as deltas on top of the baked and generated base. |
| Client | Meshing, LOD display, fog and horizon impostors, grass and foliage shaders, animation, sound, weather visuals | Keeps the minimum machine light. |

**[Proposed] Islands first, rock derived.** The old pipeline took surface height from the geology simulation, erodes it, and then the coast model forces everything outside a rounded square to ocean, which is why a tile holds one island. Reverse the order. Each tile is built in 2D on the 8 m grid (1,921 by 1,921 samples):

1. Layout from the island properties panel: islands with position, size, shape seed and character (mountainous, rolling, volcanic, archipelago). A warped-noise land mask gives irregular coasts, and small islets appear where the noise breaks the surface near shore.
2. Elevation: rising with distance from the coast, mountain spines and ridge noise, then shelf, beaches and cliffs down to the sea floor.
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
| Gems (individual gems, not one "gemstone") | Diamond: deep volcanic pipes (very rare). Ruby and sapphire: marble beside granite. Emerald: granite edges in shale country. Topaz and aquamarine: crystal pockets (pegmatites) at granite edges. Amethyst and agate: geodes in basalt lava. Garnet: folded slate, and with diamonds in pipes. Opal: volcanic rock near vents. Hard gems also wash into river gravels like placer gold |
| Marble (rock) | Limestone baked in a ring around granite intrusions, and limestone buried deep in fold belts |
| Chalk (rock) | Soft white limestone at the top of sedimentary basins (white cliffs) |
| Flint | Nodules scattered through chalk layers, and thinner chert through limestone. Flint pebbles also lie on beaches and in river gravels below chalk outcrops, so new players can pick them up without digging (derived at runtime from the rock and soil maps, not stored) |
| Alum | Bands in shale (alum shale) in basins, and lenses in volcanic rock altered by hot gases near vents. Used to fix dyes and tan leather |
| Glass sand | The existing sand deposits, with a glass quality: clean beach sand best, inland sand fair, muddy river sand poor (`glass_quality` in the soil and deposit tables) |
| Bitumen | Natural tar seeping up beside salt domes and here and there in sedimentary basins, reaching the surface as tar pits. Use: waterproofing ships and roofs; a regional trade good, since most islands rely on pine tar made from trees instead |
| Graphite | Rare bands in shale deep in fold belts, where old plant-rich mud was cooked under pressure. Use: graphite crucibles. Early game uses plain clay crucibles; a lucky late-game discovery that graphite makes better, heat-proof crucibles gives a higher crucible tier for casting metals |
| Bog iron | Rust-colored lumps in marshes and peat bogs, where iron-rich groundwater meets air. An early iron source for a new player without a mine. Not stored in tiles: derived at runtime from the marsh biome and peat soil (like flint pebbles), and it regrows slowly |
| Saltpeter | Bat droppings (guano) on dry cave floors, in caves with bat dens, and white crusts on dry cave walls. Derived at runtime from the cave sites and their dens, not stored separately. Uses: fertilizer that raises farm fertility (Section 5), curing and preserving meat, and later gunpowder |
| Nickel | Retired: no medieval use. Kept in the table so its ID is never reused |
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

- **[Decided]** There are several crucible types. Plain clay crucibles come first; graphite crucibles, which survive much higher heat, are a lucky later discovery (graphite in Section 4.9).

### 4.9a Review of the geology and resource list 

Question from the project owner: do we have all the building blocks, with a safe way to add more resources later without hurting anything that exists?

**What the first version of a tile can express.** Rock types (11): sediment, shale, limestone, coal, granite, slate, basalt, sandstone, marble, chalk, tuff. Province kinds (4): granite, basin, fold belt, volcanic. Feature types (7): intrusion, fault, basin, fold belt, volcanic vent, volcanic pipe, salt dome. Ore shapes (7): vein, lens, pipe, layer, halo, scatter, placer. Resources: IDs 1 to 31, of which 2 are retired (nickel, gemstone) and 2 are derived at runtime (bog iron, saltpeter). Flint pebbles on beaches are also derived at runtime, from the flint resource (ID 27) in chalk.

- **[Decided]** New resources must be addable later without moving or removing anything that exists. The design for this is the resource pass (`WORLD_FORMAT_SPEC.md` Section 4a): a numbered, seeded step that only adds new records to tiles.
- **[Proposed]** The only truly permanent part of the geology is the rock layer stack of each province, because it decides which rock voxels appear where. Everything else (ore bodies, features, sites) can be extended by passes. So the rock list is the one list to get right before tiles are kept. A new rock can still arrive later as a small lens or pocket (a rock body), but not as a new layer of a whole province.
- **[Proposed]** The building blocks are enough. No new ore shape is needed now. A "blanket" shape (a thin surface layer of weathered rock, for ochre and similar) may be worth adding when pigments arrive, and a shape is only code, so it can be added later.

**Possible gaps, each with the use that would justify it** (principle: every resource needs a use). None is added yet; each needs a yes or no.

| Candidate | Where it would form | Use | Needed before tiles are kept? |
|---|---|---|---|
| Fireclay | Layer under coal seams | Furnace bricks and linings, middle-tier crucibles between clay and graphite (Section 5) | No, can be a pass |
| Obsidian | Lens at volcanic vents and old lava flows | Early blades and arrowheads, a trade good | No, can be a pass |
| Tuff | Volcanic province layers | Easy-to-cut stone for dugouts and cave dwellings (desert and cold regions, Section 4.5) | **Done (plan step 12b).** Rock ID 11; a 40 to 200 m layer on top of the basalt in volcanic provinces |
| Amber, jet | Amber in basins with coal forests; jet in coal seams | Jewellery, trade | No, can be a pass |
| Ochre (iron earth), lapis lazuli, malachite and azurite | Weathered iron caps; marble contacts; copper oxidation zones | Pigments and dyes for paint, banners and cloth | No, when the dye system exists |
| Cinnabar (mercury), arsenic minerals | Hot-spring and volcanic zones | Mercury for gold amalgam, pigment, poison | No, later |
| Soapstone | Metamorphic belts | Cooking pots and hearths in the far north | No, later |
| Quartz crystal, mica | Pegmatites and veins | Lenses, early window panes | No, later |
| Fuller's earth, kaolin | Clay beds in basins | Cloth finishing, fine pottery | No, can be a pass |
| Hot and mineral springs (a site type) | Volcanic and fault zones | Baths and healing at the temple, sulfur, a prospecting clue | No, but a new site type |

- **[Proposed]** Things that need no tile data because they are worked out at runtime: sea salt (from coastal pans), well water (depth to the water table from moisture, height above the nearest water and soil, needed for town wells in Section 8.18), flint pebbles, bog iron, saltpeter.
- **[Decided]** Add **tuff** to the volcanic province rock layers before tiles are kept, because it fills whole layers. Everything else on this list can come later by resource passes.
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
- **[Proposed] Built first version (plan step 16, 2026-10-16).** Streamed blocks as recommended above: the server answers from its edits store, then its generated-block cache, then the generator; the client keeps one cache file per tile and tile revision and drops the farthest tiles first when over the player's size limit. Ore buried more than 2 m below any surface is withheld. Each missing block also brings its neighbors as low-priority prefetch, which made loading about three times faster. Measured on one machine: a cold 2 km view in about 33 s and 7 MB; from the client cache in 0.4 s.
- **[Proposed]** For now any edit raises its whole tile's revision, so every client re-downloads that tile's blocks. Fine while edits are rare; move to per-region revisions (as suggested above) before players dig in earnest.

### 4.11 At sea

- **[Decided]** Players can dive on wrecks and fish with spears, as in Atlas, so shelves near islands stay within diving reach (Section 4.12).
- **[Decided]** Finding flotsam and jetsam and scooping it up with a grappling hook, as in Atlas, is a loved dynamic, but in Atlas it is far too abundant.
- **[Proposed]** Flotsam comes from real events: a merchant ship lost in a storm or to pirates leaves its actual cargo drifting, following the same economy and same-odds rules as everything else. Some background flotsam keeps the sea interesting, at a rare rate. Items drift with currents and eventually sink or wash ashore.

### 4.12 World sketch: islands from the ocean floor

- **[Decided]** The first tile-by-tile plan did not look natural ("a very dirty napkin"). Islands usually form from underwater mountain chains, and the map should reflect that.
- **[Proposed]** Why it looked wrong: every tile rolled its own dice, so the texture was even everywhere; each tile kept its islands near the middle and every tile edge dropped to deep ocean, leaving empty lanes that showed the grid; island rotations were random instead of aligned along ridges; sizes lacked the steep real-world spread of a few big islands and very many small ones; the sea had no depth variation.
- **[Decided]** The world-first approach is approved. The first version is built: see `WORLD_FORMAT_SPEC.md` Section 5b and `plan/world_relief.png`.
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
- **[Decided]** The center island sits on the hottest row of the world, so it is a giant desert with desert features, not jungle, and scorched earth around the volcano where it has erupted in the past.
- **[Decided]** An area is prepared for the fallen society's city from the far past.
- **[Proposed]** Implemented in the world sketch: sand and red-rock desert with stepped mesas, dry wadis running off the volcano, salt flats in the lowland basins, sea cliffs, a blackened field of lava rock and ash on the upper slopes with old lava flows running down several sides, and the lava river from the crater breach. The fallen city gets a broad, stepped plateau (about 9 km², three low terraces rising to a citadel) on the northwest flank, away from the lava river and the old flows, with an old road (see below).
- **[Decided]** The old road winds from the plateau around the island to places that were probably villages along the shore long ago. It never goes up over the volcano. It is a ruined road, overgrown but still sort of passable, leading to or near the old villages, and it now acts as the path to the caves, castles and labyrinths.
- **[Proposed]** Implemented in the world sketch: a loop around the island at low to middle height that picks the most level line as it goes, a short link from the city, and spurs down to six ruined shore villages (small flattened patches). The lava river and the old lava flows bury the road where they cross it, so it is broken in places. Spur paths to the castles, caves, labyrinths and boss lairs are added at the tile bake, when those sites are placed. Ruins, walls and buildings are placed at the tile bake, from the `ruined_city` entry in `world.json`.
- **[Decided]** The center island is hostile terrain. It will have treacherous flora and fauna, and because it is huge it can hold a few caves, castles, labyrinths and bosses.
- **[Decided]** It may have land enough for a town, but its incredibly harsh climate and terrors would destroy a town long before it got established.
- **[Decided]** Working name: the **ultimate island**. The world setting key stays `center_island`. It is the most dangerous place on the whole map, and it holds the greatest riches and the greatest rewards.
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
- **[Decided]** Farming should work on a relaxed rhythm: several fields with rotating crops, and a player who logs in once a week to harvest and plant new crops (Section 7.2). Seasons are driven by the world calendar.
- **[Proposed]** Wild versions of crops exist in the right climates and drop seeds. Planted crops are server-owned objects with a planted-at time, and growth stage is computed on demand.
- **[Proposed]** Crops respond to climate and soil, so climate must be queryable at runtime.
- **[Decided]** The generated fertility map is only the natural starting value. Farmers can improve poor land with time, money and tools: lime, manure and other soil treatment, and terracing or other terraforming. In principle a player could cultivate a whole hillside or a whole heath coast into fertile farmland. Heath stays in the biome mix because it adds realism.
- **[Proposed]** Because of that, fertility needs a changeable layer on top of the generated one: player changes (soil treatment, terraces) are stored as small saved deltas per area, not baked into the tile files, and fertility is used up by growing crops, not by the passage of time alone. Crops read generated fertility plus the delta. Growing crops draws fertility down (some crops more than others, which is where rotation and fallow fields matter); lime and manure build it back. Whether fallow land recovers by itself is open.
- **[Open]** Prepared ground (tilling) as a terrain edit, or seeds on any suitable surface.
- **[Decided]** **Three kinds of resource, by how they renew.** The world is not instant-respawn: nothing comes back an hour later.
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
- **[Proposed]** Crop tiers: quick crops of 2 to 3 real days (vegetables, herbs) for players who drop in often; standard crops of about a week (grains) for weekend players; perennials (orchards, vineyards) that take a game year or more (15 real days or more) before the first harvest, as long-term investments. Crop tiers are written in real days because they follow the player's rhythm.
- **[Proposed]** A ripeness window instead of a single ripe moment. With 60-minute days, a standard crop could be ripe about 6 real days after planting and harvestable until about day 8 or 9.
- **[Proposed]** Overripe crops lose quality gradually instead of spoiling outright, so being late costs a little and never wipes out a field.
- **[Proposed]** Crop growth times are tuned for gameplay, not realistic fractions of the year (real spring wheat takes 100 to 130 days). Planting and harvest still fall in sensible seasons.

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

### 5.3 Crafting

The owner approved the direction of the crafting proposal deck ("How Deep Should Crafting Go", 2026-10-16) as an easy floor and a deep ceiling. The details below are from that deck; numbers are tunable.

- **[Decided]** Crafting should be fun, never a chore: simple things become simple tools easily, without being swamped by things to craft (owner).
- **[Decided]** **Four depths, each a choice and never a gate:** hand (anywhere, seconds: torch, rope, stone knife, poultice), camp bench (fits a tent or wagon, so nomadic households are never shut out: bow, wooden tools, stew, herbal tea, snares), workshop (the existing work buildings: smithy, apothecary, kitchen), and master work (skill plus rare finds: heartroot revival draught, hearthwood, a named blade).
- **[Decided]** **Hand-craft rule:** at most two ingredients, no station, a few seconds, known from day one or learned by picking the thing up. Hand-made items are crude: useful, but a bench-made or bought one is better.
- **[Decided]** Everything can be bought, commissioned or hired out (do it yourself or hire it out). Chains are about three steps (gather, prepare, make, then refine for masters), and any step can be bought instead.
- **[Decided]** Crafting pays: making it yourself costs about 35 to 50 percent of the shop price, hiring about 60 to 75 percent, buying 100 percent (tunable). Wear and maintenance keep crafters in demand.
- **[Decided]** Specialist paths, starting with smith, herbalist, cook and brewer, carpenter, tailor and tanner, and mason; anyone can dabble in all of them.
- **[Decided]** Mastery rewards: better quality within a tier, a maker's mark and reputation that spread with the news, secret recipes found by experiment and kept in the journal (sold or guarded, like discoveries), and a family trade taught to children and apprentices.
- **[Decided]** Recipes: the basics are known, the rest discovered (deck recommendation, approved with the direction).
- **[Decided]** How many skills one character can master depends on how long they live: characters can live very long (Section 6.10), so there is no fixed cap (owner, 2026-10-16).
- **[Decided]** **Build order: from the foundation up.** The first trades to design are the labour-intensive ones that make building materials: felling and sawing boards, quarrying and cutting stone, making bricks, making rope, then the buildings, walls and other structures built from them (owner, 2026-10-16). This replaces the deck's suggestion to build the herbalist path first.

### 5.4 Skills

- **[Decided]** **Each skill has three parts** (owner, 2026-10-16):
  - **Innate ability:** the talent the person was born with.
  - **Trained ability:** learned from books and teachers.
  - **Practice:** ability gained by actually doing the work.
- **[Decided]** Innate plus trained ability is the **base**. A share of practice, about 20 percent, also feeds the base.
- **[Decided]** An unused skill slowly decays, but never below 20 percent of the highest level that person reached. Using it again brings the lost part back quickly, like re-honing. Someone who stops woodworking to take up swordplay sees their woodworking drift down while they fight, but they keep excellent skills.
- **[Decided]** **Attributes feed skills through a web of connections** (owner, 2026-10-16). A naturally strong character is naturally good at strength skills, a dexterous one at dexterity skills, and a skill that needs both (say strength and dexterity) inherits points from both. Every trait works this way: each skill names the attributes it draws on and how much from each.
- **[Decided]** **Skills form a tree:** a broad catch-all group (swords), then categories and sub-groups, then specific skills (broadsword, rapier). The same pattern holds for axes, hammers, spears, the other weapon families and every other kind of skill (crafts, gathering and so on).
  - Practice in a specific skill goes about 80 percent to that skill and 20 percent to its parent group. Training with the broadsword makes you better with swords in general, so a little better with a rapier too; later rapier practice likewise feeds back into swords.
  - The working skill for a specific item is the parent's skill plus the specific skill (broadsword = sword + broadsword), all the way up the tree.
- **[Open]** The exact formula: how the three parts combine into the working skill, how fast practice grows and decays, and how fast regained skill returns. How this meets aging (skills fall with physical ability, Section 6.7) and children learning from parents (Section 6.6).

### 6.15b Water features: spring ponds and plunge pools

- **[Decided] (owner, 2026-10-17)** Every river head gets a spring pond or marsh pool, and the first stretch of channel narrows toward it so the brook grows out of the pond. Built 2026-10-17 in `tile_water.gd` (pond about 22 m wide, taper over 140 m); tuning values are in `tile_rules.json`.
- **[Decided] (owner, 2026-10-17)** Where water drops steeply (waterfall or cascade), a **plunge pool** lies at the foot, a basin the water has scoured out (built: 10 to 26 m wide, 2.5 m deep, at the end of any steep run dropping 5 m or more).
- **[Open]** Marsh plants around spring ponds; a real waterfall look (white water, mist, sound) on steep stretches; ground and soil washed out around pools (gravel, sand); ponds on slopes may still look like a flat lid on a hillside and need damming.


---

## 6. Characters, aging, death, heirs and personal finance

### 6.1 Aging and death

#### Aging and family

- **[Decided]** Players age. They can woo a partner and have children.
- **[Decided]** Characters start at age 20. Marriage and children are possible from age 18 at the earliest.
- **[Decided]** **Lifespan is drawn at birth** from a bell curve around 62 years with a spread of about 8, never below 45 or above 85, to account for genetics. Sickness, accidents and fights come on top of that.
- **[Decided]** For pacing, a typical character lives from 20 to about 62 (42 years) over about 21 months of real time, roughly 1,270 hours of play at 14 hours a week (Section 7). Retirement comes around 50, after about 15 months.
- **[Idea]** In their early 20s, players will hopefully settle down, establish a home and a spouse, and make that their base of operations.
- **[Idea]** The base can be in a town that belongs to another player or to the player. A town belonging to the server was also mentioned. The developer-built starter town (Section 8.1) is the first such town.
- **[Decided]** Children age too.
- **[Idea]** Couples realistically keep having children, about one every year or two, and twins are possible. That is one every 15 to 30 real days, or about a dozen children between parent ages 22 and 40 over about nine months of real time.
- **[Idea]** Population control: if a family has many children, one might fall sick and die or have a farming accident.
- **[Proposed]** Tie that risk to conditions the player can see and influence (poor food, a crowded house, no healer nearby, unsupervised dangerous work) plus a low baseline of childhood illness for every family, instead of a penalty for family size. Food, housing and land costs make a large family a real expense. Child death is emotionally heavy and can affect age ratings, so it may need gentle handling.
- **[Decided]** **One clock.** Everyone (players, families and NPCs) ages on the server clock at the same rate, whether or not the player is online. Ageing follows ordinary human rules: pregnancy lasts about nine months, women go through menopause, and a couple can have as many children as they choose to and as biology allows. One year of age is one calendar year of 365 game days, which at the default ratio of 24 (Section 7.2) is 15.2 real days. A pregnancy is about 11.4 real days, a child reaches 10 after about 152 real days and 18 after about 274. Time away ages a character (four weeks is about 1.8 years). The clock must survive server downtime (Section 7.6).
- **[Decided]** Spouses and children stay in the world while the player is away. Events such as bandit raids, dragons and sickness can affect them, which gives players a reason to return.
- **[Decided]** Fertility: marriage and children from 18 at the earliest; the chance falls gradually from 35; menopause at a random age between 45 and 55 set at birth; men stay fertile for life, with the chance dropping after 60.
- **[Proposed]** Ownership held at the **dynasty** (family line) level, so nothing needs transferring when a character dies. This is consistent with the heir inheriting everything that remains.

#### Danger, rescue and logging out

- **[Decided]** A character who is killed with no way to recover, or who is too old or wounded to recover, dies. The player restarts as a new character.
- **[Decided]** If the player restarts as their child, the child inherits everything that remains. The child's first quest may be to find the fallen parent, or hire local adventurers or services to retrieve the parent's gear.
- **[Decided]** ARK-style unconsciousness before death. A downed character can be revived, carried or dragged to safety by party members.
- **[Decided]** Because offline characters stay vulnerable, the downed timer keeps running while the player is offline.
- **[Idea] (brainstorm)** Not every defeat downs a character for rescue. Bandits and the like may knock a player out, rob and mock them, and leave them alive. After a brief blackout (about 20 to 30 seconds, not settled) the player wakes and can try to get away: crawl, limp, hide, seek cover, bandage, call for help, abandon gear or head home while help may be coming. The character is never left helpless just waiting for an NPC. To settle: how this fits the ARK-style downed state above (which defeats down you, which knock you out briefly).
- **[Idea] (brainstorm)** Waking can be dangerous in itself: in a cave, standing up may draw the creature that knocked you out, while crawling or staying hidden may get you out. Going alone should feel risky, which makes companions worth bringing.
- **[Idea] (brainstorm)** Escape should be frightening and costly but never twenty minutes of empty, forced crawling: meaningful choices (when to move, hide, stand, bandage, call for help, drop gear), not punishment by boredom. Being hurt must not mean being unable to play.
- **[Idea] (brainstorm)** Injuries (broken limbs, soreness, exhaustion, poison, wounds) lower speed, endurance, fighting and other skills for several game days (a game day is one real hour). The character can still do suitable work while recovering; temples and healers speed it up. Death by sickness stays rejected (`DESIGN_REJECTED.md`), so poison needs care not to bring it back.
- **[Proposed]** Downed window or recovery chance depends on age and condition.
- **[Proposed]** Logging out in a bed, inn or your own town makes a character **safer** (not invulnerable), while logging out in the wilderness leaves the body exposed. The project owner agreed and noted inns can be abandoned, attacked or burned, with occupants inside.
- **[Proposed]** A "while you were away" report on login, with events resolved by game rules and optionally narrated by the language model.
- **[Open]** Whether the game warns about the risk of a logout location.
- **[Open]** A grace period for accidental disconnects.
- **[Decided]** Co-op: friends in the same friends group (Section 6.13) can tend animals and harvest crops for an absent owner, with permission.

#### Remains

- **[Decided]** **Remains.** When a character dies they leave a two-dimensional image of themselves, a body with a backpack and all their gear still on it, instead of a tombstone or loot bag. The body decays over time (timeline below).
- **[Decided]** Intelligent creatures may come along, pick up the gear and add it to their hoards. Otherwise it lies where it fell, waiting for someone to pick it up.
- **[Proposed]** The heir's retrieval quest (above) leads to these remains, so the mechanics line up: a creature that took the gear makes a hoard to raid.
- **[Decided]** **Remains timeline (real days).** Remains follow a fixed seven-day timeline, then are cleaned up.
  - **Day 1:** the character falls to the ground and looks like a fresh dead body, as they looked in life. For this first real day **only the owner** (the dead character's player or dynasty) can pick up the gear. That is at least one day of grace to come back for it.
  - **Days 2 to 7:** the body gradually decomposes until it is a skeleton, and slowly sinks into the ground a little, as if the terrain or the sand were absorbing it. From day 2 **anyone** can pick up the gear, and intelligent creatures (goblins, bandits, trolls, dragons) may come along and take it into their hoards. Only intelligent creatures collect gear.
  - **Day 8:** the remains disappear and are cleaned up off the server.
  - **On rock:** where the ground is rock and nothing can sink into it, the remains weather instead. They shrink and fade over the same seven days, getting smaller and harder to see.
- **[Decided]** **Remains must never be lost.** The tombstone problem of other games (remains that fall through the ground or vanish) is a design requirement here. The remains are a server record with a position, not a physics object, and the server checks them:
  - When created, the server finds the surface by looking straight down from the death position, and places the remains on it, even over water's edge or a cliff.
  - Every time the area loads, and when terrain changes under them, the remains are checked and moved back onto the surface if the ground is missing or has changed.
  - The sinking is only a visual offset applied to the model, never to the stored position. The record is never deleted before day 8.
  - The heir's retrieval quest map marks the spot to within about 20 m.
- **[Proposed]** Remains are a flat image facing the player over a mark on the ground. NPC adventurers who die leave remains too, and each tile keeps at most 50 sets, with the oldest turning to bones only. Remains placed by the server at world start (old adventurers, Section 4.13) are scenery and do not follow this timeline.
- **[Decided]** **The wizard can retrieve your remains.** At the nearest wizard tower, the town wizard (town mage, Section 8.15) will fetch your remains for a fee.
  - He retrieves everything from every one of your unretrieved dead bodies still in the world, so if you died six times and none has disappeared yet, one visit gathers all six.
  - The gear is delivered to you, and the remains are deleted or marked retrieved on your map.
- **[Proposed]** Details (tunable): the fee is about 10 percent of the value of the gear retrieved, with a minimum of 1 gold, and it is paid before the gear is handed over. The wizard can only fetch gear that is still on the remains: gear already taken by a creature into its hoard stays there. He fetches only your own gear and the gear of the NPCs in your party (see below), never another player's or anyone else's. A town with no wizard tower cannot offer the service, which gives the wizard tower another use (Section 8.15).
- **[Decided]** **Party leader retrieval.** If you were the party leader when party members died, the wizard also retrieves the gear of your NPC party members. Another player character in the party has to retrieve their own remains, or hire the wizard themselves. Each player pays for their own retrieval.
- **[Decided]** **Any wizard tower works.** You can use the service at any wizard tower, in any town. Later, some random unaffiliated wizard towers may be placed around the map.
- **[Decided]** **Day 8 cleans up everything on the body.** Gear still on the remains goes with them when they are cleaned up, with no warning notice.
- **[Decided]** **Death marker on the map.** Each set of remains has a marker on the owner's map, such as a skull and crossbones or a tombstone, with a countdown timer showing how long is left before the remains are cleaned up. The marker is deleted or flagged as retrieved when the gear is collected, including by the wizard.

#### Absence and duress

- **[Decided]** Long absences are a soft limit, not deletion. A character is never deleted for being away. After about a real month away, **duress** starts to build on the dynasty, and each further real month it becomes more stressful to run: crop yields drop (for example 10 percent, then 20 percent), animals get sickly and illnesses start to befall the family. Left long enough, the dynasty is run into the ground and the character becomes an NPC again.
- **[Decided]** A character who reverts to an NPC may seek help from the temple and become one of the less fortunate of the town, join the nearest bandit camp, or, if they have skills, look for work in the nearest town and join the local workforce.
- **[Decided]** When a dynasty reverts to NPC, its assets (houses, businesses, farmland, mines and other resource sources) appear on the town manager's operations screen so the town can claim them (Section 8.6).
- **[Decided]** **How duress rises and falls.** Duress rises slowly: 10 percent for each full real month away (one real month away gives 10 percent, two real months 20 percent, and so on). Nothing starts until the player has been away a full real month.
- **[Decided]** When the player comes back, duress instantly drops by half of what it is. After that it falls by 10 percent for each real day the player logs in (separate days), so it falls faster than it rose. Example: four real months away is 40 percent. The player returns and it drops to 20 percent. Two logins on separate days clear the rest, and the crops grow and the NPC family works the farm or business at full strength again.
- **[Decided]** **What duress does.** It applies stress to a neglected dynasty. Crop yields drop, animals may not grow to full weight, reputation takes a small hit over time, and with continued stress the degradation of properties speeds up a little. Bills do not go up because of stress. Costs rise only naturally, because there is more to fix.
- **[Decided]** **Duress effect sizes (starting numbers, to be tested).** Duress runs from 0 to 100 percent and every effect scales in a straight line: the crop yield penalty equals the duress; animals reach a final weight reduced by half the duress; reputation loses 1 point per real month for each 10 percent of duress, on a 0 to 100 scale, capped at 20 points, and it all comes back when duress clears; properties wear up to 1.5 times faster at 100 percent; the chance of sickness for the family is multiplied by up to 3 at 100 percent. At 100 percent (about ten real months away) the dynasty is run into the ground and reverts to NPCs. It is resolved lazily from the last-seen time, so it costs nothing while nobody is looking.
- **[Decided]** Duress stays simple. It slowly applies stress to an ignored dynasty, which can then die off, be sold or fall apart. It is a money sink only indirectly, through the effects above and the extra repairs they cause.
- **[Decided]** There is no separate free vacation notice. The first real month is the built-in vacation: anyone who is away for up to a real month is still within the grace period. Longer absences are covered by a paid block.
- **[Decided]** A block stops duress only. The character keeps aging (the dynasty clock still runs), so someone away long enough can age out. They then come back to their own funeral, and the dynasty has passed by the handover chain (Section 6.7).
- **[Proposed]** The block is a convenience, not an advantage: it adds no bonus, and a player who is simply active never needs one. It follows the principle of never punishing a weekly rhythm.

#### Receivership and takeover

- **[Decided]** **Takeover by marriage.** When a dynasty falls into ruin naturally, the spouse becomes available to remarry. If they marry another player within a set time, that player may pay the town in game currency to cover the back taxes and any unpaid bills, and so claim the dynasty's properties and businesses. A player with enough money who finds a widow or widower that still has property can propose and take over that dynasty. What it costs depends on the dynasty's size, assets and liabilities. After the window ends, the town claims the assets instead (Section 8.6).
- **[Decided]** A player who returns after their dynasty has completely fallen into ruin sees a screen telling them it fell into ruin and that they must start over.
- **[Decided]** **Receivership.** A dynasty that has fallen into ruin is said to be **in receivership**. For **14 real days**, which gives the original player ample opportunity to come back, the family stays on the dynasty's land and property, and in that window other players can approach the spouse to discuss taking on the dynasty. The spouse and family are in dire need of help, so depending on their personalities, traits and how stressed they are, they are more than likely open to the idea.
- **[Decided]** The conversation is the start of the relationship, and the memories the new player has with that spouse begin there (Section 8.8). How it goes is affected by the new player's reputation and affiliations (Section 13.3): a trusted player is welcomed, one with a bad name or an unwelcome allegiance is turned away or treated with suspicion.
- **[Decided]** If the original player returns during receivership, they can take their dynasty back as their own successor. It comes back in a very bad state of disrepair and poverty, which gives them something to strive for. Duress drops drastically on return and keeps falling each day they log in (see the duress rules above).
- **[Decided]** A returning player can go to the bank for a loan based on their reputation, to buy animals, replant crops or buy food for the winter until they are back on their feet. Loan rates for this are very reasonable, because the town wants to see them succeed (Section 13.5).
- **[Proposed]** Because the window is real time, the original player and anyone else who wants the property both have a fair chance to act. If the original player returns, other players' takeover offers end and the dynasty goes back to its owner. Rescue loans are a normal bank loan with a lower rate and a size limit, so they cost the town little and the repayment still comes out of the dynasty's income.
- **[Proposed]** Receivership has a clear start and end, shown on the town manager's screen and to nearby players, so the window is visible. It ends when someone completes a takeover or when the time runs out, after which the town claims the assets (Section 8.6) and the family moves on as NPCs (temple, bandit camp or work).
- **[Decided]** **Takeover price and process.** The new player must pay the arrears: the taxes, bills and debts owed. There is no premium on top. They apply to take over the property, and the spouse has to be agreeable. They then wait until the end date of the receivership. At that time, if they have enough in game currency to cover the debts and the original player has not come back to reclaim their account, the transaction goes through. If the original player has returned, the takeover does not happen.
- **[Proposed]** During the window the town cannot yet claim the properties, and the NPC spouse's own personality and memory of the player count (Section 8.8). The new player takes the dynasty with its debts and assets together, so the bank and the town are made whole.

#### Notifications and protection

- **[Decided]** **Notifications.** The player is told what is happening to their dynasty while away, by email and later through a phone or device app. Examples: how the harvest went and what the crop sold for at market; a new baby; the spouse won the local lottery; lightning struck the barn and killed some animals; a child was killed by bandits on a delivery to market; the dynasty has reached 10 percent duress, then 20 percent.
- **[Decided]** Notifications have priorities. Urgent ones (a death, a child killed, a fire, a takeover offer, duress about to apply or rising, receivership) are sent right away. Routine ones (the harvest, ordinary market sales) go into a weekly update. Exactly which events fall in which group will be decided as those systems are designed.
- **[Decided]** Email comes first, and a phone or device app comes later. Players choose which kinds of notification they get (immediate, daily summary, weekly summary or off), but duress warnings, including the 24-hour warning, stay on by default.
- **[Decided]** Messages are plain templates filled in with the facts from the server's event log, with no language model, so they cost nothing per message and work for the free tier. Notifications only ever carry the player's own information.
- **[Decided]** **Duress protection is paid from an account balance.** When the free first real month has gone by, the player is told by email or the app that their first level of duress is about to apply, and is offered the chance to clear it. That takes them to a web page where they can put money into their account. The account holds real money that can be used for protection or for buying things in the game.
- **[Decided]** Paying is not the only way to clear duress. When the first real month ends, the player is notified and can clear it simply by logging in, with no payment. If they do not log in within the next 24 real hours, the duress is applied. After that they get regular weekly updates showing how the dynasty is being affected, and at any point they can correct the situation by logging in (duress falls as described above) or by paying for protection.
- **[Decided]** Protection time depends on the money in the account. As an example, protection costs $5 per real month. Whenever additional duress is about to apply, the game checks the account and, if there is money, applies protection one real month at a time and sends a notification. There is no limit on how long: it depends only on how much money the player has put in.
- **[Decided]** The moment protection is bought or applied from the account, all current duress is erased.
- **[Proposed]** The per-real-month price is set by the market analysis (Section 13.8). Phone app stores generally require their own in-app purchase system for digital goods and take a fee, and the whole system should work without real money until then. Players can also buy a block directly from the web page instead of keeping a balance. A balance of real money, with purchases and refunds, is stored value, so check payment and consumer rules by country before building it, and decide whether unused balance can be refunded.

- **[Decided]** **No extra risk for being offline.** Logging off adds no hidden penalty. Family members and buildings are lost only through the normal causes (sickness, age, fire, raids, wear), and being away matters only through duress and the wear rule (Section 8.13).
- **[Decided]** **Who can raid whom.** NPC threats (bandits, monsters and so on) can hit anyone, anywhere. Players can raid other players only inside PvP zones (Section 9.0).
- **[Decided]** **Dropped items follow the remains timeline** (Section 6.1, Remains): freely takeable on day one, decaying over the week, and gone by day eight. Items in hard-to-reach places follow the same timeline.

#### Open items

- **[Open]** What happens when several players apply for the same dynasty, whether the money is held (escrowed) from the time of application, whether a failed payment at the end date passes the offer to the next applicant, and the final prices for blocks. (A free vacation notice was decided against; notification channels are set above.)
- **[Open]** Whether other players and NPCs can rob or finish a downed character. The suggested answer is that outside PvP zones it is a crime handled by the legal system (Section 9), not a blocked action; inside PvP zones there is no protection (Section 9.0).

### 6.2 What an heir inherits

- **[Decided]** The heir inherits equipment, businesses, properties and bank accounts. The only thing missing is the character's personal skills.
- **[Decided]** Debts pass to heirs along with everything else. A debt that expects a regular payment becomes the heir's obligation, stays on the books and is paid accordingly.
- **[Proposed]** The dead character's assets pay creditors first, so dying cannot be used to dodge debt. If the estate is worth less than its debts, creditors take what is there and nothing more.
- **[Proposed]** A business's own record carries over, but the heir's personal reputation starts blank (see below).
- **[Decided]** **Reputation belongs to the person.** Every player and every NPC has their own reputation score. The dynasty itself has no reputation. Nothing passes between dynasties when they merge.
- **[Decided]** **The dynasty average.** For large loans and purchases, the head of a dynasty also counts the wealth of their dynasty, and everyone under the umbrella (children, stepchildren, spouses) has a reputation that is averaged in. A child who becomes a criminal makes the head and the dynasty look bad. The head's own reputation can be so good that people ignore it, because it is a mean average.
- **[Proposed]** How to compute it (tunable): the head's standing for credit counts 60 percent, and the average of the other adult members counts 40 percent, plus a wealth bonus for loans. The head's own reputation stays the head's. This number is only used for credit and for how NPCs size up the family, not as a score anyone can see or hold.
- **[Proposed]** Early on an heir leans on NPC employees and managers for skills they lack, and must learn the trade or hire for it.
- **[Idea]** Children learn some skills from their parents as they grow, so when a parent dies the heir is a partially trained character already waiting. The project owner described this as a theory for now.
- **[Open]** How large that head start is, and how it works for player heirs compared with NPC children.
- **[Decided]** When a character retires or dies, the whole dynasty passes to one successor, chosen by the handover chain (Section 6.7). An older child has better skills but less time left to play.
- **[Idea]** The will names the successor and lists the children with their skills and attributes and leaves the farm or the town to a chosen child. It should be set long before death and can be updated at any time.
- **[Proposed]** For scale: an heir aged 20 has about 21 real months of play left on average, one aged 35 about 13 real months, and one aged 50 about 6 real months.
- **[Decided]** Without a will, the handover chain in Section 6.7 applies. Each person in the order may accept or refuse according to their traits and plans, and a will raises the odds of acceptance.
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
- **[Idea] (brainstorm)** Dynasty is not a die, respawn and run back loop. Characters get many believable chances to survive defeat, serious injury, poisoning, exposure or being stranded. Death stays possible and meaningful but rare, not the usual price of losing a fight; surviving can still cost gear, wealth, time, mobility, trust, reputation and recovery.
- **[Idea] (brainstorm)** Several independent rescue chances overlap: getting yourself out, friends and hired companions, passing hunters, merchants and travelers, hermits and other country folk, guards and patrols, family and town searches, temples and healers, and, very rarely, a kind supernatural being (Section 8.2).
- **[Proposed] (brainstorm)** A quiet server-side **rescue director** checks whether a character has a realistic way to safety, whether help is coming and whether they can make progress, and favors believable encounters (a traveler on that road, a patrol turning up) over teleported help, obvious saviors or secret invulnerability. It stops long helplessness; it does not remove the danger of death.
- **[Open] (brainstorm)** The real risk of permanent death in extreme cases, and when the rescue director should not step in.

### 6.6 Children and family growth

- **[Decided]** Having a child is a joint decision. The player discusses it with the spouse, they agree, and the pregnancy begins. It is not automatic and a bot-run household does not breed on its own.
- **[Decided]** A baby and young child are a cost on the household (food, care, the spouse's time), not a worker. The child becomes useful around age 10 to 12.
- **[Decided]** At about that age the player talks with the child about what direction to take and can set markers that steer them (farming, mining, a trade, adventure, schooling, being the heir). The child follows the markers according to their own interests and abilities.
- **[Decided]** The default for a child with no markers is idleness: play, little work, few skills. An unattended household therefore raises children with weak skills and a farm that stagnates.
- **[Decided]** An engaged player can teach the children, so different children can serve different branches of the dynasty (one runs the mine, others work the farm, some adventure). All of these bring wealth and options to the family.
- **[Proposed]** Teaching speed depends on the parent's own skill in the trade and the time they spend with the child. This links to the partial-training idea in Section 6.2.
- **[Proposed]** The child's own traits can pull against the markers, so a strong push against a child's nature gives slower, grumbling progress.
- **[Open]** How much time teaching costs the parent, and whether NPC tutors or apprenticeships can stand in for the parent.

### 6.7 Succession, inheritance and the dynasty

#### Handover chain (succession)

- **[Decided]** Only the chosen successor inherits. The whole dynasty passes to that one person. It does not matter which spouse a child came from, since all are the head's children and all are eligible to be successor at retirement or death.
- **[Decided]** **Retirement is the player's choice, driven by aging.** As a character ages, their skills fall with their physical ability. At some point the player decides it is time to move on, makes sure a successor is chosen, and chooses to retire. This is usually a conversation with a spouse. There is no fixed retirement age.
- **[Decided]** **Retirement.** A character who lives into old age and becomes too old and frail to carry on can choose a successor and retire. The player then takes over the successor's body, and the retired character becomes a senior or elderly NPC who lives out their remaining days on the farm.
- **[Decided]** **Naming a successor can be tested while alive.** Because NPCs talk through the language model, a player can say to a child, stepchild or spouse, "I am thinking of making you my successor", and they answer as themselves: proud, nervous, or unwilling. Naming someone does not bind them. They can still decline when the handover comes.
- **[Decided]** **The handover chain (order of succession).** When the dynasty is handed on (death or retirement), the named successor, if any, is asked first. If there is none, or they decline, the offer goes down this line, and each person in turn accepts or declines. A spouse always comes after her own children:
  1. All of the player's own blood children, grouped together and taken oldest to youngest, whichever spouse they came from. (Five children with the first wife and two with the second are one group of seven, by age.)
  2. The first spouse, if able. An elderly or dead spouse cannot take it.
  3. The second spouse's children from before (the player's stepchildren), oldest to youngest, then the second spouse.
  4. The third spouse's stepchildren, then the third spouse, and so on in the order the spouses were married.
  If the first spouse has children of her own from before, they come between the blood children and her. Whoever takes it becomes the player's character.
- **[Decided]** **Each person in line chooses; with no will, the chain is the order of asking.** The chain is the order in which the offer is presented. Each person in turn may accept or refuse, and a refusal passes it to the next in line. With no will, nobody is named, so the offer simply goes down the chain.
- **[Decided]** **A will raises the odds, but is never a certainty.**
  - If a successor is named, the chance they accept is much higher.
  - It is not 100% just because it is a parent's will. It is certain only if the successor agreed beforehand.
  - If a child told the parent they truly do not want it and is named anyway, the chance of accepting rises by about 50%, so it becomes a coin flip. If they refuse, it passes to the next in line.
  - **Character attributes decide the odds.** Loyalty, a sense of duty and greed each push toward accepting, so most people will accept. There is always some chance they will not.
  - The one exception is the last in line, who must accept (above).
- **[Decided]** **The last in line must accept.** If the offer goes all the way down the chain and everyone has declined or is dead, the last person on the line, which is the youngest child (not the last spouse), accepts no matter what. A player who has built any lineage always keeps their dynasty.
- **[Decided]** So it pays a character to spend time encouraging the children to want to be the successor (conversation, teaching and the markers in Section 6.6).
- **[Decided]** Siblings who are not the successor stay in the household and age out over time, unless they leave (see below).

#### Inheritance from an unknown benefactor

- **[Decided]** **No lineage at all: the mysterious will.** If the player has no dynasty or lineage left, they roll a new character, who receives the whole dynasty through a mysterious will from a stranger. The server charges the inheritance tax below on it.
- **[Decided]** **Inheritance tax applies only to a will from an unknown benefactor, is money only, and the player chooses what to sell.** An heir from the family chain (above) pays no inheritance tax.
  - The tax is always money and must be paid before the character can play.
  - If the inheritance has too little gold, the character can pick which common items to sell from a screen (see the bankruptcy rule below). It is their choice first.
  - **The server never takes items.** Nothing is taken away from anyone: not hard-won gear, boss drops, bought cosmetics, or anything they enjoy. Only money is ever asked for, and only common items can be sold to raise it.
  - **Dying poor:** if there is not enough to sell without losing their best things, the player may borrow from the nearest town to cover the tax. (The temple's reputation discount is described below.)
- **[Decided]** **The tax size depends on the benefactor's reputation.**
  - The town and the temple both know who the benefactor was, and the benefactor's reputation with each decides how large a discount the new character gets.
  - A benefactor with a very high reputation with both could leave a tax of one gold, payable on inheriting.
- **[Decided]** **The tax starts around 40%.** The base rate for a benefactor with no reputation is about 40% of the money and sellable assets inherited. The better the benefactor's reputation with the town and the temple, the lower it goes, down to a fee of 1 gold. The aim is to give the new character everything if the benefactor was well regarded, and not to take it all when they were not. The 1 gold is a delivery fee for getting the dynasty to the starter town.
- **[Decided]** **The tax amount.** The tax is 40% of the inheritance at no reputation, or 1 gold, whichever is higher, and limited to what is available in the inheritance.
- **[Decided]** **Bankruptcy rule: only common items can be forced.**
  - If the inheritance has no gold, or not enough, the new character can be made to sell common items (all basic items) to raise the tax.
  - Anything magical, or bought from an event (costumes, cosmetics, special gear), cannot be forced out of them. Once the common items are sold, that money is all that can be taken. The tax is paid from it and the rest stays.
  - **Example:** a normal sword, an iron sword and a cheap leather suit of armor can be sold. A really nice suit of armor, a magical sword and a couple of bought costumes cannot. These stay where the dead player stored them. If they were in a house, they are still in that house, waiting for the new character.
- **[Decided]** **Order of forced sale.**
  - Always take the least valuable things first, starting with common items.
  - Magic items, costumes and event-bought items can never be forced.
  - Houses, businesses and other property can be forced to sell only when there are not enough other assets to cover the debt. In that case the player is given the choice: sell the property, or take out a loan from the town and pay it back.
  - Loans have terms measured in game time.
- **[Decided]** **Gift items are not safe if the other assets fall short.** Items named in the will can be sold for the tax when there is nothing else to cover it, under the same least-valuable-first order. Magic, costume and event items are still never forced.
- **[Decided]** **The new character may ask for a loan.** If they wish, they can take a loan from the town to cover the tax and to keep all of the items. The interest rate depends on their new reputation.
- **[Decided]** **Loan rate numbers (accepted; to be tested and tuned).** From 4% per game year for a new character with a high reputation up to 16% for one with a low reputation, and higher again for a character whose benefactor was hated. The loan can be renegotiated as their reputation grows.
- **[Decided]** **Items left to the new character in the will.** The will can name which items go to the new character on creation. For example: "leave my magic equipment in storage where it is, but give my iron sword, my iron pickaxe and my horse Ajax to the new player to get started." On creation, the tax is taken first, then the named sword, pickaxe and horse are handed over with a "good luck, adventurer".
- **[Decided]** **A will can carry its own tax money.** A player who writes a will will usually set aside gold with it to cover the inheritance tax, for example 100 gold, and the tax is taken from that gold. The tax relates to the size of the dynasty (money, worth, number of buildings and so on), and the writer's reputation with the town lowers it, so the successor gets what was left to them.
- **[Decided]** **The discount splits 50-50.** The benefactor's town reputation can remove half of the 40% and the temple reputation the other half. The figures are tunable.
- **[Decided]** **Where the next character starts.**
  - When the dynasty passes to a successor for any reason, the player restarts automatically wherever that successor is.
  - With no successor, a starter town picker pops up. It suggests the nearest town where they own property (a home or apartment), or the nearest town if they own none, and the player may choose another.
- **[Decided]** **An early character who dies with nothing.** If a young character is killed out adventuring with no will and no successor, and owns only a couple of simple tools, the town and the temple take pity. They keep their basic tools and equipment. They owe the 1 gold fee as a debt, and their first adventure can be to gather materials worth about one gold piece to pay it off.
- **[Decided]** **No will and no dynasty at all.** The equipment the dead character has on them is handed over automatically to the next character, who owes 1 gold to the town where they spawn.
- **[Decided]** **The benefactor's reputation passes on in part.**
  - Wherever the benefactor had a reputation, the new character gains some of it as word spreads in the town. People respect the benefactor and pass some of that respect on.
  - NPCs could offer condolences, offer to show the new character around town, find them work, or help on the farm, because they speak highly of the benefactor.
  - **Residency:** to be accepted as a resident, a character needs enough reputation. If the benefactor was a resident of that town, the new character is automatically set to the minimum required reputation. If the benefactor stood higher, the new character also gains a percentage of the excess.
  - **A bad benefactor:** with a terribly low reputation the opposite happens. The tax goes up, and the new character may lack the reputation to live in the town. They may be forced to sell the property, or take a loan at an elevated interest rate until they can renegotiate it on their own reputation.
- **[Decided]** **Starting numbers for passed-on reputation (accepted; to be tested and tuned).**
  - In a town where the benefactor was a resident: the new character is set to the residency minimum plus 25% of the benefactor's reputation above that minimum.
  - In a town where the benefactor was known but not a resident: 10% of the benefactor's reputation there.
  - The same rule applies to the temple.

#### Merging dynasties and households

- **[Decided]** A person has only one dynasty. Taking over another dynasty (purchase, marriage, rescue) merges the two by combining the entire families. Everyone comes in under the player: the player gains a new spouse or spouses and stepchildren, and all the properties, businesses, debts and everything else that goes with the dynasty.
- **[Decided]** A dynasty may have several spouses over time. They die off from age or sickness, and each adds assets and holdings to the dynasty.
- **[Decided]** **Duress ends with the merge.** When a player buys or takes over a dynasty and merges it into theirs, the duress on the absorbed dynasty ceases to exist, because it was caused by its previous player not logging in and playing. The buyer takes on no duress from it. Duress stays one value per dynasty, so merging never multiplies the upkeep.
- **[Decided]** Dynasties transfer inside the game by marriage, adoption, will, or sale to a successor. The login itself is not sold, so identity, reputation and record stay with the person.
- **[Decided]** **Households have no hard cap; cost is the limit.** Each member needs a bed, food and some care, so a big household is an expense, and extra people sleep in tents or at the inn if the house is full. Household size does not change duress. As a backstop for server load, marriage and adoption pause once a dynasty has about 40 living members.
- **[Decided]** A dynasty can have many living spouses at once. The aim is to grow a dynasty as in medieval times and plan against sickness and age. Spouses are people who help run the day-to-day work of the dynasty and household and help raise children.

#### Check-in and automation

- **[Proposed]** Bots and client automation are banned in the terms of service. Hands-off play via NPC staff is allowed by design, and the household economy already pays less for neglect (Section 6.6).
- **[Decided]** **The check-in needs a real action.** To count, the player must log in and do something: talk to someone, buy something in a shop, go on an adventure, pick a crop, feed an animal, or anything else that shows they really did something. The action should also work as robot detection, so a bot that runs in circles or runs into a wall does not count.
- **[Proposed]** How to build it: only actions that change the world and are checked by the server count (an item bought or harvested, a conversation completed, a task finished). Movement alone never counts, and the same action repeated within a minute counts once.
- **[Open]** The list of qualifying actions, and how many different kinds are needed.

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

- **[Decided]** A dynasty can exist with no spouse and no children. A character in that position may seek immortality or a longer life during their lifetime.
- **[Idea]** **Ways to get it.** Paying a large sum to the local mage; a journey or quest whose reward is a wish or some other special mechanic; or an arrangement with an otherworldly being that grants longer life or slower aging.
- **[Idea]** **What it can do.** The character ages very slowly, has their age frozen at a chosen age, or is turned back to a chosen age. For example, a 70-year-old who completes a quest for a wish may wish to be 30 forever. If the server judges the wish reasonable, it locks the age in and makes them younger.
- **[Decided]** It does not stop sickness or death. A long-lived character can still fall ill or be killed.
- **[Idea]** **Others notice.** Over the years friends see that something is strange. The character may be labeled a witch or evil, because people do not understand. They would have to move from town to town to put distance between themselves and people who know them.
- **[Idea]** **A new identity every 20 years.**
  - The character keeps their old name but must re-establish a new identity about every 20 years, claiming to be the son or daughter of the earlier person.
  - Returning to an old town, the people who knew them are old or dead. If they are old, the character can say the earlier person was their mother, father or grandparent.
- **[Decided]** **Wishes have rules, and they are not fairy-tale traps.**
  - A wish is earned by a great adventure and is not a trick. It does not come with a punishment or a moral lesson.
  - **Forbidden wishes:** nothing that affects other people, no bringing back the dead, and no making people fall in love with you.
  - **The granter talks to the character.** It may be a gold dragon, a great wizard, a spirit, a witch or a ring. The character and the granter hold a conversation, and the granter makes sure the wish is on the allowed list and is worth no more than the value the server gave that adventure.
  - **Example offers:** "I want to be the richest character in the world" is answered with a smaller grant, such as 5,000 or 50,000 gold. Other offers: everyone forgets who you are; your bad reputation in an area is erased; a lifelong boon of better reputation so people tend to like you; slower aging; being made 30 again and living another 500 years, or 100 years.
- **[Decided]** **All characters age at the server clock** (Section 6.1), unless a wish changes it. Familiars age at the same speed as their handlers.
- **[Decided]** **"I wish to live forever" is answered with a smaller grant.** The granter says it cannot make anyone live forever, but it can extend life and roll back years. The character is made half the age they are now, and one trait is changed so that they age significantly slower.
- **[Proposed]** **How much slower.** Three tiers tied to the value of the adventure: aging at half speed for an ordinary wish, a third for a large one, a quarter for a great one. As an example, a 60-year-old made 30 who ages at a quarter speed has about 32 years of life left at the normal rate, which stretches to about 128 calendar years, about 5.3 real years of play instead of about 1.3. The extra years still have to be renewed by another quest or payment, as above.
- **[Decided]** **Extra years run out and can be renewed.** During that time the character must do another quest, or pay another wizard, before they die to keep living that way. Money can buy a longer life, but it never buys skills or abilities. Those still have to be earned.
- **[Decided]** **Changing identity counts as retiring.** A character who never ages does not need to worry about retiring, but when they take a new identity it is treated like retiring or dying:
  - They get a picture on the wall of themselves, in the outfit they wore when they changed over.
  - They continue as the same person with all the same features and a new name. Their old name becomes the name of their parent, with a made-up co-parent they choose.
  - They can buy the new identity from a criminal organization. They pick the co-parent, the old name, the new name and where they are from, and then carry on.
- **[Open]** Loopholes in the wish rules (the project owner expects some); how the value of an adventure is set; whether the aging-speed tiers (half, third, quarter) are right; and how the 20-year new identity works for a slow-aging character.

### 6.11 Familiars (future)

- **[Idea]** Familiars, as in D&D, could be added later as companions that give comic relief. The model is Claptrap from Borderlands 2, but as a parrot, monkey, dog or similar animal that talks to you, constantly teases or mocks you, and says funny things.
- **[Idea]** Now and then a familiar could say a catchphrase in the style of a famous cartoon (such as a power-word shout), purely as a joke.
- **[Idea]** **How you get one.** A familiar might be granted on a quest, or given by a wizard. You can also raise and tame an animal you love, such as a dog, cat or crow. It becomes a basic familiar that cannot talk, follows you and works well with you.
- **[Idea]** **Upgrades.** A special quest line can give the familiar the ability to talk, or improve its abilities, perhaps by traveling to meet a famous wizard.
- **[Decided]** **Many kinds over time.** What a familiar can do depends on its type. More types of familiars and tamable animals and creatures will be added over time.
- **[Idea]** **Examples of what a type can be trained to do.**
  - **Dog:** hunt animals and other creatures; find lost children or goblins; warn of danger; seek out valuable resources. Walking down a country road, your dog might run into a field and bark, then point (like a German shorthair) at a deposit, or just at the ground, and if you dig you find something valuable.
  - **Crow or raven:** gather sticks, twigs or shiny things; eavesdrop from a windowsill; drop things where you cannot reach, such as a potion of exploding or a fire bomb on a bandit camp or an enemy; throw rocks at enemies.
  - **Monkey:** climb to interesting places and listen in on conversations; fetch you a beer from the bartender if your reputation there is good.
- **[Idea]** **Personalities.** Each pet has its own personality. It may reflect yours or be your opposite. A very loyal player may have a very loyal pet, or a loyal but less-than-legal pet that does not worry about right and wrong, so the two keep their own moral code and play in the shadows. The more you do together, the more the pet tends to become like you. The goal of a pet is to be a helpful partner.
- **[Idea]** **Fighting.** A pet may help in a fight or battle if it is not killed. It could be a bull mastiff, a Chihuahua, a dragon whelp, or a very smart raven that throws rocks.
- **[Idea]** **Talking with the pet.** The player and the language model work out the pet's personality in conversation while they talk to it.
- **[Idea]** **Player requests feed the content list.** Players can suggest or ask for a certain type of pet. If the game cannot provide it, the language model notes the request and reports it to the administrators ("this is what players are asking for"), so they can build that familiar and add it later.
- **[Open]** Whether a familiar ages or dies (and what happens to it when its owner does), and whether the jokes can be turned off.

### 6.12 Homages and Easter eggs (future)

- **[Idea]** Hide references throughout the game as homage to the creators of great fiction, games, films and stories. The project owner's son suggested a wizard's tower that looks like a small box or telephone booth from outside but is large inside, with a painting of a caricature of the Doctor (or of all the Doctors) on the wall.
- **[Idea]** Other examples: a religion whose god looks like a cartoon doctor from a famous time-travel show; in a wizard school's hallways, paintings of caricatured famous wizards from books, D&D games and films; a hall of heroes with caricatures that resemble famous cartoon heroes.
- **[Decided]** **Never copy exactly.** The references must not look exactly like the originals, to avoid infringing anyone's copyright. They are nods, not copies. (This follows the same rule as the original-characters-only approach for anything drawn.)
- **[Open]** Who decides what is a safe homage, and whether to review each one before release.
- **[Decided]** Rimecap (a fantasy mushroom, Section 4.3) is a nod to the RIME ring in Dungeons of Daggorath (owner, 2026-10-16).

### 6.13 Groups: parties, towns and friends groups

There are three kinds of group, from the shortest-lived to the longest-lived. None of them puts people in the same dynasty.

- **[Decided]** **Adventuring party.** A group that goes out and agrees to adventure together, with a party leader. It is temporary. Party mates are the first layer of rescue (Section 6.5), and the leader can have the wizard retrieve the NPC members' gear (Section 6.1).
- **[Decided]** **Town affiliation.** A resident of a town is a member of that town's group, and the town owner sets its rules (Section 8.6).
- **[Decided]** **Friends group (above the dynasty).** A level of group above the dynasty, where friends join so they can find each other and play together. Joining does not put anyone in the same dynasty. For example, two friends each keep their own dynasty and are both in the same group. The group allows members to:
  - see each other on the map;
  - communicate;
  - share permissions, such as letting a friend work in or control one of their towns, for example as a town overseer (Section 8.6).
- **[Decided]** Members of the owner's group count as the owner's presence for the claim timer (Section 8.14): a member inside the zone stops the countdown.
- **[Proposed]** Details (tunable): a person belongs to one friends group at a time; invitations are accepted by the invited person; a group has a leader (or a few) who can invite and remove members; membership suggestion is up to 50 people. Permissions are granted by the owner, per town and per role, and can be taken back at any time. Groups share nothing else by default: no money, no reputation (reputation belongs to the person) and no inheritance. A shared treasury may come later.
- **[Decided]** Name: the **friends group**. Plain and clear. (Company, fellowship, league and circle were considered.)
- **[Open]** Politics between groups (the factions and guild ideas) and what a group's leader can do beyond inviting and removing members.
- **[Idea] (brainstorm)** No character classes. People have jobs, skills, experience and roles they describe themselves. Fighter, ranger, cleric, rogue and wizard are handy shorthand, not classes or party slots: a temple worker may call themselves a healer or cleric, a guard a fighter, a hunter a ranger, and a former soldier who now bakes keeps their old skills. No fixed party size or make-up.
- **[Idea] (brainstorm)** Parties mix any number of players, friends, family and hired or invited NPCs. A tavern is a natural place to find locals or travelers for hire, and they should never feel like disposable menu units. Hiring is a conversation about real abilities, past trips, pay, expectations and whether they would come back for a fallen member; NPCs may exaggerate, sell themselves short or lie.
- **[Idea] (brainstorm)** Shared trips build trust, memories, friendships, grudges and reputation, and former companions may invite the player along later.
- **[Open] (brainstorm)** Party promises or contracts, pay, leadership (the party leader above is decided), shared loot, orders to companions and rescue duties.

### 6.14 Senses, thoughts and the minimal HUD

- **[Idea] (brainstorm)** Three separate systems, not one. **Sixth sense** (noticing): character-specific checks catch a rustle, movement or a threat at the edge of sight, depending on eyesight, hearing, attention, tiredness, fear, personality and experience. It can be wrong and is never server-omniscient. Urgent danger comes through sound, music, visual cues or reflexes, not speech.
- **[Idea] (brainstorm)** **Inner voice** (the character's own thoughts): optional spoken or subtitled remarks that carry memory, interpretation, confidence, fears, humor and know-how, when the player examines something or now and then by circumstance. Sparing, fitting and interruptible: never a running tutorial or narrator, and it may confidently misremember. A veteran steadies themselves or jokes after waking ("Well, here we go again"); a nervous apprentice thinks differently. Heirs do not inherit it. Not during urgent combat; thoughts can come afterwards.
- **[Idea] (brainstorm)** **Instincts** (trained reflexes): a veteran shifts stance, turns a torch toward a sensed flanker, guards an open side or steadies their breath; a hunter drops low. Reflexes help, never replace, the player: no spending valuable items, big moves or spells on their own.
- **[Idea] (brainstorm)** Keep camera control with the player. A subtle directional glow or sound at the edge of the screen marks a sensed threat; automatic camera turns are not wanted, and the earlier slow-time bubble is only an exploratory thought (it is also hard in multiplayer).
- **[Idea] (brainstorm)** (Update 2026-10-17: breathing and heartbeat are proposed to follow physical exertion only; see Section 6.16.) **No permanent health, stamina or magic bars**, and probably no heart icon. Numbers live in the inventory and character screen; in play the body tells you. Heartbeat (after Dungeons of Daggorath): silent at rest, faster and audible with effort, fear, pain or distress, pounding near fainting, when sight narrows and sound muffles, then returns slowly on waking. Hidden conditioning grows with lived effort and improves endurance, recovery, resilience and coming round, as related but separate traits rather than one super-stat; healing can depend on other factors.
- **[Idea] (brainstorm)** Breathing: silent normally, deep and rhythmic when running, panting when exhausted, shallow with fear, coughs when sick, grunts and groans with pain. These are heard in the world and can alert NPCs and enemies (thoughts are private). Temperament and training change them.
- **[Idea] (brainstorm)** Injury shows as a very dark, barely noticeable blood-red vignette at the edges that grows with injury and never covers the middle of the view, perhaps pulsing faintly with the heartbeat. A sensed threat shows as a bright red glow at the matching screen edge that may flicker, strengthen with urgency, follow the view and fade once noticed. Its strength reflects the character's senses and sense of urgency, not a radar or the enemy's real power.
- **[Open] (brainstorm)** Accessibility: subtle effects that color-blind players can still tell apart, and settings for motion, flashing, sound sensitivity and taste. Which reflexes are safe to automate. Which body traits are simulated and which abstracted. How a veteran's reflexes can feel better while staying fair in multiplayer.

### 6.15 What a character knows: journals and libraries

- **[Idea] (brainstorm)** Things carry no all-knowing labels. What a character notices, recognizes, remembers and believes depends on experience, senses, traits and imperfect memory, and can be wrong. A familiar berry is easy to name; a rare herb may be forgotten or misnamed; a character may remember a plant is dangerous without its name. Skill, repetition, how recent and how important shape recall.
- **[Idea] (brainstorm)** **Personal journals** are real objects: sketches of plants and animals, unknown finds, hand-drawn maps, ruins, caves, notes and travel. They can be traded, stored, lost, looted and inherited (they follow the remains rules, Section 6.1). Reading or copying one teaches its contents; being a descendant passes on nothing by itself.
- **[Idea] (brainstorm)** Wizards and libraries compare journals, identify unknowns and flag contradictions, and can be wrong or dishonest. Keep each claim's source and corrections instead of overwriting it. Regional libraries, caravans and ships spread discoveries, and books and articles become a history of what players did.
- **[Open] (brainstorm)** Journal interface, how fast knowledge transfers, checking research, library catalogues, provenance, what stays private, and one data model shared by journals, libraries, newspapers and rumor.


### 6.16 Exertion, fitness and health (brainstorm)

From the owner's chat with ChatGPT (2026-10-17), folded in as brainstorm. Nothing here is built. Where the owner stated a number or a rule it is marked "owner".

- **[Idea] (brainstorm)** **Three physical measures: Health, Exertion, Fitness.** Health is injury and damage. **Exertion** is the strain right now, rising and falling all the time (conceptually 0 to 100 percent). **Fitness** is longer-term conditioning. Exertion **replaces** a classic stamina pool; there is no separate stamina bar next to it (matches "no permanent bars" in Section 6.14: the numbers live on the character screen, in play the body tells you).
- **[Idea] (brainstorm)** **Activities raise exertion at their own rates.** Walking and resting let it recover. Jogging, running, sprinting, fighting, swimming (faster swimming more), heavy physical work and other hard effort raise it. Fitness changes how much each activity raises it, how fast it drops, and **how high an activity can be sustained**: a very fit runner can jog or run a long way at a steady elevated exertion well below collapse (perhaps slowing a little), while sprinting stays above anyone's sustainable level and in the end drives even that runner to severe exhaustion. An unfit character is winded jogging and must sit after a short sprint.
- **[Idea] (brainstorm)** **Escalating forced slowdown:** slight slowdown, stronger slowdown, severe exhaustion barely faster than walking, then stumbling and collapse. Exertion can force a lower real speed even while the player keeps asking for a jog, run or sprint. Collapse is gradual (staggering, slow fainting), and during unconsciousness the player hears breathing and heartbeat settle until control returns. Collapse from exertion is **not** combat damage and never kills; it meets the rescue layers in Section 6.5.
- **[Idea] (brainstorm)** **Model:** activity demand against fitness-dependent recovery, settling at an equilibrium for sustainable work. Hard activities have no safe equilibrium below near-total exhaustion. The slowdown lowers demand but must not make collapse impossible for everyone.
- **[Open]** Exact curves and numbers (the bands 0-40, 40-60, 60-75, 75-90, 90-100 percent were only examples), how to avoid rapid flicker between speeds, how to allow pushing past the automatic slowdown without "run until unconscious" being the best strategy, and whether load carried, slopes, swimming and heat (Section 4.5, altitude) also raise exertion. Recommendation: heavy load, steep slopes, heat and thin air raise the cost of each activity.
- **[Idea] (brainstorm)** **Fitness is a skill.** It grows from time spent at higher exertion (not from button presses), at the normal skill leveling speed (owner).
- **[Idea] (brainstorm)** **Detraining (owner):** exertion held at about 0 to 5 percent for a long time slowly lowers fitness, at **half** the corresponding gain rate. Ordinary rests do not count. The character's **all-time peak fitness** is kept, and inactivity never takes current fitness below **30 percent of that peak** (peak 90 gives a floor of 27, peak 100 a floor of 30). Stored as `current_fitness` and `peak_fitness`; the floor is `0.30 * peak_fitness`.
- **[Idea] (brainstorm)** **Injuries do not directly change fitness (owner).** A fitness 90 character with a broken leg keeps fitness 90, but the leg limits running and other actions until healed. Time lost to injury can still lower fitness through the ordinary detraining rule, never below the floor. Extra exertion from injured movement comes from the injury limits, not from a fitness penalty.
- **[Idea] (brainstorm)** **Breath and heartbeat follow physical exertion only, not fear (owner, for this proposal).** Low exertion is subtle or silent, severe exertion brings loud fast breathing and a strong heartbeat, and near collapse the ears ring and outside sound muffles. Players can hear exertion climb and recover, and footstep spacing slows in step with forced slowdown.
- **[Decided] (owner, 2026-10-17)** Breathing and heartbeat follow **exertion only** for now. Later, fear and pain may add adrenaline that affects them, but not yet.
- **[Decided] (owner, 2026-10-17)** **Stamina is no longer a metric.** When these ideas are built, they **replace** the old stamina system everywhere it is mentioned (altitude Section 4.5, flu Section 8.1, marrowroot `stamina` property, 6.14 endurance text).
- **[Decided] (owner, 2026-10-17)** The 30% fitness floor is only an example number; all such floors may end up the same value. Tune later.
- **[Decided] (owner, 2026-10-17)** Injuries never change fitness. They impose limits on the matching actions (a sprained knee limits jogging and running).
- **Conflicts and questions found when folding this in (for the owner to settle):**
  - **[Open] Heartbeat and breathing.** Section 6.14 ties heartbeat to effort, fear, pain or distress, and breathing to fear, sickness and pain too. This proposal makes both follow exertion alone. Recommendation: exertion drives breathing and heartbeat; fear, pain and sickness keep their own cues (grunts, coughs, the edge vignette).
  - **[Open] "Stamina" appears elsewhere** and should become exertion: altitude cold and thin air "drain stamina" (Section 4.5), the 24-hour flu "affects stamina" (Section 8.1), and the marrowroot flora property `stamina`. Recommendation: reword these to "raise exertion faster" or "slow recovery" when the system is built; nothing else changes now.
  - **[Open] Fitness decay floor.** Section 5.4 lets unused skills decay slowly to 20 percent of their best. Fitness here decays at half the gain rate to a 30 percent floor. Recommendation: fitness is a skill in the 5.4 tree with its own, higher floor (physical conditioning is kept better), keeping the owner's numbers. It also meets aging (skills fall with physical ability, Section 6.7).
  - **[Open] Injury effects.** Section 6.14's injury text lowers "endurance". Recommendation: read that as lowering what the character can do (speed, sustained effort) through injury limits, never as lowering the fitness score.
  - Nothing here conflicts with `DESIGN_REJECTED.md`: exhaustion never kills, so the "no death by disease" rule is untouched.

### 6.17 The sound stage (brainstorm)

Detail for the direction recorded in Section 1 and `DESIGN_PRINCIPLES.md` Section 4, from the same chat. Nothing is built; the cost limits are in `ARCHITECTURE_BUDGET.md` Section 9.

- **[Idea] (brainstorm)** **Goal.** A player standing on a sunny sandy beach, facing inland toward grass, bushes, trees and a small brook, should feel present with eyes closed. Start with a basic, extensible sound stage; character exertion audio belongs in it. Prefer sounds from real objects, creatures, terrain and events where practical, with ambient beds only for the diffuse background.
- **[Idea] (brainstorm)** **Layers** (biome-appropriate): (1) environmental bed (breeze, distant surf, nearby lapping, brook, distant canopy); (2) wind on materials (broadleaf rustle, conifer hiss, grass swish, creaking branches), with wind driving both plant motion and sound, including gusts; (3) water variants (flowing, over rocks, trickles, shallows, drops, breaking waves, pebbles); (4) wildlife with positions that vary by biome, season, weather and time of day (birds, waterfowl, frogs, insects, squirrels, woodpeckers, owls); (5) rare one-shots (snapped twig, falling cone, rolling pebble, rustling brush, splash, startled bird), never overused; (6) spatial audio (distance, direction, losing distant highs, hills and vegetation blocking sound, so a brook behind a hill is not heard beside you); (7) acoustic spaces (forest, field, valley, cave, stone and wood buildings each with their own echo and damping); (8) responsive wildlife that goes quiet or flees as you approach and returns later; (9) character foley (clothing, armour, packs, tools, splashes, brushing plants, jumping, landing, climbing, material-aware footsteps on wet and dry sand, grass, gravel, mud, leaves, wood, stone, snow); (10) physiological audio (Section 6.16); (11) settlements heard before seen (bells, dogs, livestock, carts, axes, hammers, saws, smiths, children, voices, tavern, doors); (12) dynamic mix and real silence, so not every second is filled.
- **[Idea] (brainstorm)** **Footsteps follow the feet.** Walking uses short strides, jogging longer, running longer again, with cadence following speed; a forced exertion slowdown changes the spacing to match. Surface-dependent sound triggered by foot contact, not a timer. The camera bob already works this way: stride 3 m walking, 4.2 m jogging, 6 m running (build 23), with a footfall at each step phase. The same step phase can fire the footstep sounds. **[Open]** surface tagging, what is sent over the network (footsteps of other players are played locally from their reported movement), and cost.
- **[Idea] (brainstorm)** **First prototype** (suggested, owner receptive): the sunny beach to grass, trees and brook scene with seven foundations: wind, vegetation, water, wildlife, rare events, character foley, spatial and distance processing. Settlement acoustics later. **[Open]** where sounds come from (made, licensed or recorded), how many sounds play at once and which are dropped first, the cost of blocking and echo, weather, and the low-tier limits. Not every unheard physical source is simulated: distant sources become cheap beds.
- **[Idea] (brainstorm)** The client stays light for older computers and the server, client and admin tool stay separate (`DESIGN_PRINCIPLES.md` Section 5): the server decides what happens (animals, events); the client renders the sound from nearby events.

### 6.18 Real simulated water (owner, 2026-10-17)

Replaces the painted rivers, lakes and ponds (Sections 6.15 and 6.15b), which kept floating on hillsides. The owner was frustrated with tuning static water, so this is built now.

- **[Decided]** **Water is simulated, level-based, with no pressure.** Water fills a basin to its own level, spills over the lowest rim and runs downhill. It keeps its volume. Water leaves the world only at the ocean (and the edge of a simulated area). Loose water on land (a broken dam, a shallow puddle, a farm trench) dries slowly; everything else is conserved. Rain adds water, so dug trenches fill.
- **[Decided]** (owner, 2026-10-18) **The world starts with dry fresh water**: only the ocean is wet and springs at head ponds start the flow at launch, so the real water paths show. Springs push water only to their own height. Head ponds are 240 m across and 10 m deep (first 60 m, then 30 m; owner 2026-10-18: 30 too deep, 10 is fine), bowl-shaped with a rounded rim and a walkable ramp (about 0.4 slope) up and out; they sit about 50 m uphill of the river head; one spring per pond; lakes are about half as deep as before. Rivers are about 20 m wide and 3 m deep (owner, 2026-10-18; replaces "at least 100 m wide and 20 m deep") and always slope steadily down from source to sea, never back up. The + and - keys change the amount and speed of spring water, never its height. Water must be flat, with clean shorelines.
- **[Decided]** **The generator places springs, not painted water.** A spring adds a stream's worth of water forever; mountain lakes and river heads are springs. **Springs and head ponds belong at the very top of a rise or on a plateau or flat high ground, never on a hillside**, where a basin can really hold water. The first version finds each river head and moves its spring to the flattest high ground within 120 m (`settle_water.gd`).
- **[Decided]** **Speed.** One cell per tick, fixed tick length, one tunable number; falling water moves about twice as fast as spreading water (`SPREAD_RATE`, `FALL_RATE` in `water_sim.gd`).
- **[Decided]** **Dams and digging.** Blocked water backs up and floods back over low ground. A trench dug off a source lets water run in. Breaking a dam lets the stored water run out at the same visible pace. The ground can be edited at any time (`set_ground`).
- **[Decided]** **Settled once at bake time in the admin tool**, saved, and only woken near edits and players at runtime. The server owns and saves the water; clients only draw its surface. Valleys flooding in the first tests is fine: we look at it, then fix the river code and add waterways. A flood picture from the admin tool shows where water went.
- **[Idea]** **Rivers swell in rain** (owner, 2026-10-17): rain raises spring flow and adds water, rivers rise and can flood, then fall again. Not built; the simulation has a `spring_multiplier` so rain only has to change one number.
- **[Decided]** **Depth and speed follow volume, fall and slope** (owner, 2026-10-17): the water in a river (its depth and how fast it runs) should come from how much water flows in, how far and how steeply it falls from inlet to outlet, and how fast it moves. More volume and more speed make deeper, faster water. Practical first step (built): one flow-rate number scales every spring, so a bigger flow gives a deeper, longer river. Later: per-cell flow speed from slope so steep stretches run shallow and fast and flat stretches deep and slow.
- **[Decided]** **Tuning control** (owner, 2026-10-17): the + and - keys change the flow rate of all water by about 10 % per press (range x0.1 to x10), and the screen shows "Water flow rate: xN" for 3 seconds. The server keeps ticking the water in the background and the client redraws it as it settles, so a good rate can be found by eye. The chosen number then goes into the bake (`WATER_BASE_RATE` and the settle tool's `--rate`).
- **[Open]** Build state (2026-10-17): heightfield simulation on the tile's 8 m grid, painted water as the starting state, one tile (3,4) at a time, drawn through the existing water mesh. Not yet built: wake near player edits at runtime, saving edits, water across tile borders, caves and overhangs (a column holds one water level), and a true voxel water mesh.

---

## 7. World time

One server clock drives aging, marriage, children growing up, crop growth, regrowth, decay, taxes, loan payments, work hours, patrol and trade schedules, memory fading and seasons.

### 7.1 Time conventions

- **[Decided]** **Unlabeled times are game time.** Any amount of time in this document, in the game or in the rules ("a month", "a year", "three days") means game time unless it says **real**. Real time is written out ("real hours", "real month") only where a rule is tied to the player's own life.
- **[Decided]** **Real-time items:** the presence timer, takeover and challenge windows, the 24-hour owner notice before a manager quits, the duress rules (a real month away; protection at $5 per real month; first real month free), receivership windows, remains lasting 8 real days, the reputation fade of about a real week, and trade offers that stand for a real week. 
- **[Decided]** **Crops** ripen on the game clock but their tiers are quoted in real days (Section 5.1), because they follow the player's rhythm. **Game-time items:** boat build times (6 game hours for the first tier, converted from 15 real minutes at the 24-to-1 ratio), aging and lifespans, pregnancy and growing up, seasons, loan and wage terms (loans 4 to 16 percent per game year, wage raises per game month), guard notice (one game month), work hours, shop hours, building and production schedules, wear and decay (Section 8.13) and expansion balance tests in game years. Town spirit decays on a real-day clock (Section 8.12).

### 7.2 The time ratio and the calendar

- **[Decided]** **One time ratio.** The server has one setting for the speed of time: game hours per real hour. The default is 24, so one real hour is one game day. Two more settings: days per year (default 365) and seasons per year (default 4). A game year is then 15.2 real days, a season 3.8 real days, and a game month (12 per year) about 30 real hours.
- **[Decided]** Everything in game time follows the one clock. The clock pauses when the server is down, so an outage never ages anyone or ripens a crop.
- **[Decided]** **Why 24.** It gives a 60-minute day (close to 7 Days to Die at 60 minutes and Medieval Dynasty at about 48) and a year of about two weeks. It also avoids repeating the same point of the year on every weekly visit: a year of 15.2 real days is not a multiple of 7, so a weekly player sees different seasons on each visit. Ratios near 26 or 52 would repeat the same point every week and are avoided.
- **[Decided]** **Three player types are all served:** the daily player sees a season change every three to four logins; the player on three evenings a week sees about half a season between visits; the weekend player sees one to two seasons between visits.
- **[Decided]** Characters experience four seasons (spring, summer, autumn, winter). Farming supports a once-a-week rhythm: a farmer can build several fields with rotating crops and log in on a weekend to harvest and plant (Farming Simulator is the inspiration).
- **[Proposed]** Crops grow on the calendar clock using lazy timestamps. A ripe crop stays ripe for a window at least as long as the typical gap between visits, so a weekly player is not punished. Absent farmers can rely on friends or hired NPC farmhands.
- **[Proposed]** The seasonal swing grows with distance from the equator. Near the equator the year is closer to wet and dry seasons than to hot and cold.
- **[Idea]** Seasons shape activities: ice fishing on frozen lakes in winter, boat fishing in summer, easier mining on firm ground in summer and winter, muddy roads in spring and autumn.

### 7.3 Lifespan targets

- **[Decided]** A typical character starts at 20 and dies at about 62 (Section 6.1): 42 years of age at one year per 15.2 real days, about 21 real months, roughly 1,270 hours of play at 14 hours a week. Retirement comes around 50, after about 15 real months.
- **[Decided]** The expected player plays 12 to 16 hours a week. This will be tested and tuned with the one time ratio (a ratio of 36 would give about 14 real months).
- **[Proposed]** Skills should feel competent in tens of hours and mastered in a few hundred, so a character gets time at the peak before aging slows them. That much play time needs enough depth to stay interesting.

### 7.4 NPC aging

- **[Decided]** NPCs age on the same clock as players, from a random starting age (roughly 20 to 30) to a death age drawn from the same bell curve. Showing age as a number plus a life stage (child, young adult, adult, elder) is available.
- **[Proposed]** An NPC who starts at 25 and dies at 62 lives about 18 real months. A child takes about 9 real months to reach 18. A town's population therefore turns over in about two real years, so births, marriage and migration matter. Birthdays come every 15.2 real days.

### 7.5 Day and night

- **[Decided]** One game day lasts one real hour at the default ratio. That gives more day and night cycles per session and encourages short weekday visits to keep up with farming, which spreads server load across the week. 72 minutes was rejected.
- **[Proposed]** Day length varies with the season and latitude, calculated on each client from the server clock, so it costs nothing on the network. Near the equator day and night stay about even; toward the poles summers have long days and winters long nights, and far-north winter darkness becomes another soft limit.
- **[Proposed]** Night is compressed: about two-thirds day and one-third night at mid-latitudes (around 40 minutes of day and 20 of night), with long, usable dusk and dawn.
- **[Proposed]** Night is never pitch black (moonlight and torches). Because players cannot sleep through the night in a persistent world, night has to be content: more danger, monsters, stealth for thieves, guards on watch.
- **[Proposed]** For comparison, from memory: Minecraft's full cycle is about 20 minutes and Valheim's about 30. The slower 60-minute day suits settling and farming.
- **[Proposed]** Shops, work hours and schedules run on game hours. A 10-hour work day is about 25 real minutes.
- **[Open]** How much more dangerous night is than day.

### 7.6 The server clock

- **[Proposed]** The server keeps one stored time counter that advances only while the server runs. Time of day, the calendar and age are all derived from it with different constants.
- **[Proposed]** Production in each town is settled once per game day (once per real hour), which keeps the server load small.

---

## 8. NPCs and towns

### 8.1 Towns

- **[Decided]** Players found towns by placing a **town block** that they own. They can assign themselves as owner or leave governance to AI.
- **[Decided]** Players start at a **starter town**. For now it is just a spawn point, where the initial developers build the first town. That town becomes the starting town for future players.
- **[Decided]** Players should spend years traveling and adventuring. Trade routes get established as towns are built.
- **[Decided]** The original players build the original towns. Once the first town is started, AI NPCs are added to manage, design, build and extract resources.
- **[Idea]** **Admin town warehouse.** Admins have a special menu that places an admin warehouse, a creative-mode style warehouse that supplies whatever is needed. Any NPC in that town can use it for building and for selling supplies, so the starter town's tradespeople always have basic supplies for sale and admin town building goes much faster. It might be a default for starter towns.
- **[Decided]** Only town admins, town NPCs and residents can take goods from the admin warehouse. It shows two supply numbers: a limited supply for residents who are not admins, and an unlimited supply for server town admins.
- **[Decided]** **Buy before manifesting.** Server admin towns with an admin warehouse always try to buy resources from player-run towns (when available) before using the warehouse's magical ability to manifest supplies. A new player therefore always finds a buyer waiting as soon as they start producing, and because all towns degrade and buildings need upkeep, that demand never ends.
- **[Decided]** To avoid imbalance, admin town buying has limits: how much it will buy from each town and how much in total per day. Budgets are a money amount per day, set in the town manager (Section 8.5). The warehouse manifests only what purchases could not cover.
- **[Decided]** The admin warehouse log shows both: goods bought from players and goods manifested.
- **[Decided]** **Two kinds of server-owned town.** A **designated server town** (the starter towns) has an admin warehouse and falls under special rules, below. A town that has **reverted to the server** because its owner's dynasty fell into receivership has no admin warehouse and declines under the normal rules (Sections 8.13 and 8.16).
- **[Decided]** **Special rules for a designated server town.**
  - It never gets a bad spirit.
  - It never runs out of money to pay its bills.
  - Its warehouse always has supplies.
  - A boost applies to everyone who lives there, because the spirit is always high: people are more productive, happier and more loyal, and feel fuller when they eat. Crops grow a little better, animals grow healthy, and there is less sickness.
  - **Purpose:** starter towns are the foundation of the game, a place where players can always start and be in a nice town.
- **[Decided]** **The boost covers the whole starter town:** everything inside the walls, the harbour, its outposts, and the surrounding farmland out to the edge of its grand-city-sized circle.
- **[Decided]** **The spirit hovers at about 75 percent,** not at the top. Good deeds by new characters can still lift it, so players on the starter islands feel they are doing something that matters.
- **[Decided]** **A wealthy temple.** Since these towns do so well, the temple is rich and can afford to help people who fall sick, so there is less illness in general.
- **[Decided]** **Sickness is checked each game day, by each person for themselves.**
  - Every NPC rolls once per game day to see whether they fall ill, so different people get sick at different times and nobody falls ill on a fixed weekday.
  - The chance falls as the town's spirit rises: the lower the spirit, the higher the chance. At a spirit of 100 it is lowest, and at 0 it is highest.
  - Once a person is sick they stop rolling. The sickness lasts up to a maximum length unless they get treatment at the temple, which rapidly improves their health and well-being.
  - Recovering lifts their own spirit.
- **[Decided]** **Two kinds of sickness, with reasonable frequency.** A person should have a reasonable chance of catching a cold at least twice in a game year. A major illness should happen maybe once or twice in a lifetime. At a spirit of 100 the chance of either is very low. At a spirit of 0 it is a medium chance, because it is constantly raining, people stay indoors and everyone is in a bad mood.
- **[Proposed]** **Numbers that fit those targets (tunable).** Each is a straight line from spirit 100 to spirit 0, checked once per game day (a game year is 365 game days; a working lifetime from 20 to about 62 is about 15,300 game days):

| Town spirit | Colds per game year | Chance of a cold per game day | Major illnesses per lifetime | Chance per game day |
|---|---|---|---|---|
| 100 | 1.0 | 0.27 percent | 0.5 | 0.003 percent |
| 75 (starter town) | 2.25 | 0.62 percent | 1.4 | 0.009 percent |
| 50 | 3.5 | 0.96 percent | 2.25 | 0.015 percent |
| 0 | 6.0 | 1.64 percent | 4.0 | 0.026 percent |

  A starter town at 75 therefore gives about two colds a game year and one or two major illnesses in a lifetime.
- **[Proposed]** **Cold (tunable).** A cold lasts at most about 5 game days (5 real hours) and slows work by about 10 percent. Temple treatment cuts it to a day.
- **[Decided]** **Major illness.**
  - It takes about 30 game days unless the person is treated at the temple. The sick NPC may be confined to the temple.
  - **A roll at the start decides life or death,** with a very small chance of death.
  - If the roll says they live, they gradually get better over 15 days because they are at the temple. The town's spirit goes up by 2 points.
  - If the roll says they die, they gradually get worse and die. The town's spirit goes down by 1 point.
- **[Proposed]** **Chance of death for NPCs (tunable).** Treated at the temple: about 2 percent for an adult under 50 and 5 percent from 50 on. Not treated (no temple, or not taken there): three times those. Over a lifetime of about 1.4 major illnesses that is roughly a 4 percent chance of dying of one for a treated person.
- **[Decided]** **Player characters never get major illnesses.** Dying of disease would be a terrible way to die in a game, and there are enough things trying to kill players already. People around them, such as spouses, children and townspeople, are affected, but adventurers spend their time out in the world and have strong constitutions. A player character can catch a cold for a little while, and going to the temple makes it go away faster. Nothing worse than that.
- **[Decided]** **The worst a player character gets is the 24-hour flu.** A bad bout of diarrhoea and dysentery: they make a lot of farting sounds, sweat a lot, and their stamina is affected for one game day (one real hour at the default ratio). It is played for comedy, not for punishment.
- **[Decided]** Everyone except player characters has a chance of dying from a major illness, including spouses and children.
- **[Proposed]** A death also brings grief for the spouse, children and friends, with a prayer request on the bulletin board (Section 8.12).
- **[Proposed]** To keep the server cheap, each person draws once the number of days until their next sickness (a geometric draw from the chance above) and does not roll every day. The draw is made again when spirit changes a lot or when they recover.
- **[Proposed]** The other boosts stay modest (tunable): about 5 percent for productivity, crop growth and animal growth, and about 10 percent more fullness from food.
- **[Decided]** The starter towns' prices are set by their merchant, not fixed by admins. The merchant reviews prices once a day and raises or lowers each one from supply, demand and other factors: an abundance of a good lowers its price, high demand raises it. Admin town buying pays these prices.
- **[Decided]** Goods bought from NPC tradespeople are limited by how fast they can actually make them. They have orders to keep a stock level, and when someone buys an item the NPC has to stop and make another to replenish it (Section 13.7).
- **[Decided]** Starter items are worthless to vendors, because everyone gets them from the starter town. A vendor asked to buy one says something like "you know how many of these I see in a day? I can't get rid of the stock I have."
- **[Decided]** Starter items are made of the most basic materials. Melting one down returns at most 80% of the material, and only with a really good skill.
- **[Proposed]** Starter items carry a "starter town" maker's mark under the provenance principle (Section 3), which is how vendors recognize them. Salvage yield rises with skill up to the 80% ceiling. Every admin warehouse withdrawal is logged.
- **[Decided]** **Founding.** The town block is a marker with no physical form (see Terminology). Until the owner puts down an office building (a keep or castle with an office, a house with an office, a town hall or a magistrate's office) they cannot reach the town settings. The building is also where the town manager lives and works. The marker is the centre of the town, so the well naturally goes over or beside it.
- **[Idea]** **Founding sequence.** After the first office come a town planner's office and a builders' guild. The planner surveys the land and suggests the best areas for roads, districts, suburbs and town walls. Once the player approves, builders level the land for roads and lay cobblestone paths or dirt roads, with bridges where required. With roads done, the planner suggests building locations with an explanation of where and why. If approved, the planner places the building, or the player places it.
- **[Decided]** Apart from the starter town, the first players (the project owner's friends and family) build the towns.
- **[Decided]** Towns become server-owned when a town owner's dynasty falls into receivership and nobody takes the town over, and are then offered for sale (Section 8.16). Nothing is placed at the start, so this does not affect the bake.
- **[Decided]** Players build roads and buildings, choosing from premade blueprints.
- **[Decided]** The town block interface sets rules and settings: militia, elite guards, a town bank and town funds, tax rates and tax rules. Towns can build and improve defenses.
- **[Decided]** Player-run towns can fall into ruin.
- **[Proposed]** Ruins as landmarks that decay lazily over time.
- **[Decided]** Ruins do not vanish. Buildings fall to rubble that stays until harvested, and roads stay (Section 8.13).
- **[Decided]** Players can found their own town on a starter landmass as long as it is far enough from the starter town center. Large islands can hold several towns, which can build tension between neighboring towns.
- **[Decided]** Mines owned by the starter town have guards to dissuade players from stealing.

### 8.2 NPC population

- **[Decided]** Population is controlled by aging, sickness, poverty and murder.
- **[Decided]** New NPCs spawn at about age 20. If two single NPCs live and work together they may marry and have children. Children start small and stay near or within a reasonable distance of their parents. They grow up with skills and temperament similar to their parents.
- **[Decided]** When a player builds a job building (for example a blacksmith blueprint), an NPC may come along and apply. The server rolls up a new NPC for that role (see "Role-weighted rolls" below) and places them in the world.
- **[Decided]** NPCs start at level 1 and simple. Over time they build stories, history, skills and fortitude. They can gain or lose wealth.
- **[Decided]** NPCs have core traits: goodness, lawfulness, physicalness, dexterity, wisdom, intelligence, charisma, and others. They also have skills like players.
- **[Decided]** **Role-weighted rolls.** NPCs are never rolled with flat random traits and skills. Every role (blacksmith, guard, scavenger, farmer and so on) has a **template** of weighted traits and skills that fit the job, and each NPC is rolled with **variance** around that template. A blacksmith comes out with blacksmith-shaped skills and traits, even if he is a weak one. A guard comes out "guardly", weighted toward physicalness and a sense of duty or lawfulness. Variance still makes individuals differ: a poor blacksmith is still weighted toward smithing, not a random mix. This applies to all NPC generation, including scavengers, the NPCs who apply to job buildings, orphans and displaced arrivals.
- **[Open]** The templates themselves (which weights and how much variance for each role) are designed per role as the roles are built.
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
- **[Decided]** **Scavengers (roaming pickers).** Some NPCs roam certain areas and live off the land. If one finds an unclaimed item on the ground (a dropped sword, discarded nails or iron), they pick it up and sell it at a reduced price to the nearest fitting tradesperson, such as scrap metal to the blacksmith, like a pawn shop. Picking up unclaimed goods is not a crime.
  - They use the ordinary NPC traits (honesty, lawfulness, goodness and the rest; Section 8.8), rolled from a scavenger template with variance (role-weighted rolls, above), not a separate system. The template is mostly low-to-middling skills with a wide spread in honesty and boldness. Most are harmless and take only what lies around. A bold, low-honesty one might steal from a player's person, and then it is a thief and the law system applies (Section 9); fencing stolen goods uses the existing fencing and stolen-goods economy.
  - Players cannot tell which kind they met from the archetype alone. A scruffy one may turn out to be honest and kind, and worth befriending, and another may be genuinely sketchy. It is found out through talking and watching, as with any NPC.
  - Details (how many, where they roam, how much they pay) are tunable.
- **[Idea] (brainstorm)** **Country folk.** Forests and roads around towns hold believable residents with territory, livelihoods and habits, and every shade of good, selfish, neutral and secretive: hermits, hunters, trappers, herbalists, scavengers (above), charcoal burners, wanderers. Some watch the player unseen. A secretive hermit may witness an attack and then rescue the player, report the danger, hide, or scavenge the aftermath, by personality and risk. They do not give away their home or what they know; getting to know locals can uncover secret homes, routes, rare plants or witnesses. Perhaps only the town wizard knows who the hermit is, and everyone else thinks it is a ghost.
- **[Proposed] (brainstorm)** Track these people as short timestamped observations and work out important memories only when they matter, rather than running conversations for distant NPCs.
- **[Idea] (brainstorm)** **Real supernatural beings.** Some mysterious rescuers are ordinary people; some really are ghosts, bog witches or other beings, and the player should not always know which. A cottage may seem real and then vanish behind you; the same figure or dwelling may turn up in different places within its region. The being and its territory persist while its visible form (cottage, campfire, figure, lights) comes and goes. Spirits may be kind, neutral, deceptive or dangerous, may attach to a dynasty and remember it across generations, and may become a family legend passed on by journals and stories, not inherited memory.
- **[Idea] (brainstorm)** A kind apparition is an extraordinary last resort, only when self-rescue, companions, travelers and guards cannot get the player safe in reasonable time. It is not the normal rescue.
- **[Open] (brainstorm)** How rare supernatural events are, what triggers them, whether the being is physically real, and whether misread events or hallucinations can produce the same stories.
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
- **[Idea]** **The road builder.** A separate tool from the town planner, pointed at the whole map instead of one town (see "Road, mine and tunnel builders", Section 8.17). The player picks two points; the builder proposes the best route, favoring the shortest or shallowest water crossings and choosing where bridges go. The player reviews and approves it (the same "planner proposes, player approves" pattern as above). Then it does the ground work itself, levelling, averaging and smoothing the terrain with the same checks as blueprint placement (Section 10.1), and lays the chosen surface (a rough wagon path, a dirt road, cobblestone). Road condition and wear follow Section 8.13.

### 8.5 Town roles and management

- **[Idea]** Players in a friends group (Section 6.13) can give each other rights in a town. A friend could be a town overseer with the right to hire, fire and manage NPCs.
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
- **[Decided]** A remarrying spouse can take over a ruined dynasty's property by paying the town its back taxes and bills (Section 6). If nobody does within the window, the town claims it.
- **[Decided]** A property owner who has gone long enough that their dynasty reverts to NPC (Section 6, duress) loses the property to the town: it appears on the town manager's screen and the town may claim the houses, businesses, farmland, mines and other resource sources. For a mine, the town pays for repairs before letting it collapse (Section 11.2).
- **[Decided]** **When a home is abandoned.** If a home's rent or bills go unpaid for **two game months**, it is deemed abandoned and returns to the market. The owner gets a **notice after the first game month** of non-payment. A game month is about 30 real hours, so the whole thing is roughly 60 real hours (2.5 real days). Bills are paid automatically from the dynasty's banked funds, even while the player is offline, so it is the player's responsibility to keep enough money banked to cover bills during absences (see duress and receivership, Section 6.1).
- **[Decided]** **Furnished or empty.** When an abandoned house goes up for sale, the buyer chooses: buy it **furnished** at full price, with the previous owner's belongings and stored goods still inside, or buy it **empty** at a reduced price. If the buyer takes it empty, the old belongings simply disappear. They are not stored anywhere for anyone to claim later.
- **[Decided]** Players can own houses, businesses and farmland in any town, several in one town or spread across towns, as long as each town accepts their reputation.
- **[Decided]** Players can also prospect their own land in the wilds and mark it with a **town stone** (to found a town, within the spacing rules in Section 8.17) or a **homestead marker** (a private home, Section 8.17).
- **[Decided]** Owning property in an enemy town is hard. Someone who owned property in two towns before they became enemies keeps it, but tensions can get weird and their loyalty, and so their reputation, may come into question in both.
- **[Decided]** A town is basically a group of friends, and the town owner sets its rules. Residents are already vetted because they are already in the town.
- **[Decided]** Buying into a town: players whose reputation with the town is at or above a score the owner sets are accepted automatically. Players below it must be approved, and meanwhile can stay at the inn.
- **[Decided]** Players below the score can earn their way in: work around town, adventures and quests for the town, and acts of kindness such as hunting and donating the food to the local temple or inn, ridding the area of bandits or goblins, or volunteering at the well or wherever help is needed. Once their reputation reaches the score they are accepted automatically.
- **[Decided]** The town owner can whitelist or blacklist players by **account**, not just by character name, so a banned player cannot come back as a new character.
- **[Proposed]** When two towns turn hostile, owners in both get a warning and a choice: keep both and accept the standing loss, or sell one.
- **[Decided]** Good deeds raise reputation mainly with the town that benefits, and a little with its allies once the news spreads. NPCs who witness or benefit from a deed remember it (Section 8.8).
- **[Decided]** Repeating the same deed counts for less each time, so reputation cannot be farmed (donating rabbits all day). The reduction cools down gradually, though: someone who keeps doing good deeds regularly over time, out of the goodness of their heart, earns a reputation as a good person rather than being penalized.
- **[Decided]** Roughly half of the reputation from a deed is permanent and half is temporary. The temporary half fades slowly (over about a real week) as people forget, so reputation drifts down unless it is kept up.
- **[Decided]** Reputation timing uses real days, so a deed lasts long enough for a weekly player to benefit.
- **[Decided]** Some deeds are never forgotten: epic quests, saving someone's life and the like. They become stories the village tells. The story starts with the person helped (whoever gave the quest, whoever was saved), who tells their closest friends; they tell theirs, and before long the whole town knows. Each teller passes it on through their own memory and honesty traits (Section 8.8), so the story changes a few times along the way, embellished, shrunk or muddled.
- **[Proposed]** A legendary deed is one story record (who, what, where, when, the facts) plus, per NPC who has heard it, their version: how strongly they remember it, which details they changed and who told them. Spreading follows each NPC's social ties, a step every so often in game time, with talkative and social NPCs passing it on faster. Reputation from such a deed is permanent and does not need the teller to remember the details right. Travelers and wagons carry it on to other towns through the news system (Section 13.6). When a player asks an NPC about it, the language model voices that NPC's version, so different villagers tell it differently.
- **[Proposed]** One way to do this: each kind of deed has a "recent count" that decays a little every day; a deed's value is divided by (1 + recent count), so a burst of the same deed quickly stops paying but the same deed once a day or so keeps paying almost full value. A steady habit over weeks (for example, a donation most days for a month) adds a lasting "known for good deeds" bonus. The temporary half of each gain fades linearly over seven real days; the numbers live in a tunable table.


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
- **[Idea] (brainstorm)** The server and database own the true world state. The language model adds occasional conversations, personality-driven readings and background social outcomes, never a model running every NPC every frame.
- **[Proposed] (brainstorm)** Keep a timestamped, ordered log of encounters and process each NPC's in order (independent NPCs in parallel when safe). Store short memories from each person's point of view instead of simulating every off-screen sentence. Process first the NPCs about to meet a player, guards searching for someone missing and other urgent events; the rest when load allows, keeping order and avoiding contradictions. Player-facing dialogue and background memory work are separate but read the same world data. Memories carry uncertainty, hearsay, source, misinformation, forgetting and confidence. Rules handle routine work, the model richer interpretation, with checks and a fallback when the model is slow or unavailable.
- **[Open] (brainstorm)** How long events are kept, batching, scheduling, cost, stopping NPCs from knowing what they should not, and how NPCs behave while their memory queue is behind.

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
- **[Decided]** An outpost is claimed with an outpost marker, in the same way as a town marker (Section 8.17).
- **[Proposed]** Outpost blueprints are built for slopes: terraces, stilts, stairs and a jetty, so the blueprint leveling check (Section 10.1) allows steeper ground for them than for town buildings.
- **[Proposed]** Danger matters: outposts in hard and deadly waters need a palisade and guards paid by the parent town, and are natural targets for raids, pirates and sea creatures, which ties into threats and pacing (Section 12). Losing an outpost cuts a supply line rather than ending a town.
- **[Proposed]** Volcanic islands drop steeply into deep water, which makes them good for docks. The geology already favors them for ore: copper and gold on arcs, sulfur and gems on hotspot volcanoes (Section 4.9). When ore bodies are placed at bake time, some should sit near outpost-friendly coves so mines and docks pair naturally.
- **[Proposed]** The generator does not need to bake outpost sites: they can be found at runtime from the tile maps (slope, height, shoreline, water depth), the same way the town planner surveys land. Natural harbors and coves can still be marked as sites at bake time.

- **[Decided]** **The basic outposts for now:** a logging camp, a stone quarry and a mine. A quarry is an open pit worked from the surface; a mine is drilled, with a shaft that goes down into the ground. The full list of outpost types and their rules will be decided later.
- **[Decided]** **Setting up an outpost.**
  - The player places an outpost marker and adjusts the area, the same way as placing a blueprint (including the ground check, Section 10.1).
  - The only prefabricated piece is a small building such as a mining shed. It designates the area. A line marks the border of the outpost, visible in building mode.
  - Once set up, the owner can hire NPCs to work it, from the existing pool of unemployed NPCs or from newly manufactured ones. They start working the area immediately.
  - The outpost comes in four sizes: small, medium, large and colossal.
- **[Decided]** **The size of a settlement limits its outposts.** The bigger the claim, the more outposts it can support, and the bigger they can be. A settlement might support two small outposts (say a logging camp and a quarry); a hamlet four small ones or two medium ones, so the owner can grow a quarry or add a mine. This is a working theory, to be rounded out as it is built.
- **[Proposed]** **Outpost points (tunable).** Each outpost has one of four sizes: **small, medium, large and colossal**. Its size costs points from its parent claim's budget: small 1 point (radius about 50 m), medium 2 (about 100 m), large 4 (about 150 m), colossal 8 (about 250 m). Growing an outpost costs the difference in points, plus the real cost of the expansion. The budget grows with the stage:

  | Parent stage | Outpost points | Example |
  |---|---|---|
  | Camp | 0 | none yet |
  | Settlement | 2 | two small outposts (logging camp, quarry) |
  | Hamlet | 4 | four small, or two medium |
  | Village | 8 | a large mine plus several small outposts |
  | Town | 12 | |
  | City | 20 | |
  | Grand city | 32 | |

- **[Proposed]** A watchtower or pigeon coop is always small. Other minimum sizes will be decided with each outpost type.
- **[Proposed]** Outposts may sit outside the parent's circle of influence, even on another island, and still count against the parent's budget. Each outpost needs guards and upkeep paid by its parent, so the budget is a money limit as well as a points limit. A town never drops a stage: it keeps its stage (a city stays a city) and falls into ruin instead (Section 8.13). Its outposts stop being paid and decline with it, as the mine rule describes (Section 11.2).
- **[Proposed]** Homesteads and individual players who own outposts directly get a small fixed budget (suggestion: 2 points), not tied to the town ladder (Section 8.17).
- **[Open]** The exact point values and budgets, the list of outpost types and their minimum sizes.

### 8.11 The temple

- **[Decided]** Every town can have a temple. It is non-denominational (no real-world religion) and built entirely on the principle "be safe, be kind, be generous" (Section 3).
- **[Decided]** The temple is the centre of kindness in a town. It is where a person goes for help: healing, food, shelter, and protection. It demands nothing from anyone. Donations are always welcome and improve the donor's reputation.
- **[Decided]** Players can simply talk with the clergy, like a counsellor, about philosophy and meaning. The teaching encourages: recognizing your inner voice, questioning why you think as you do, reflecting, self-help, self-worth, being useful to your community and helping neighbours, and being good to yourself in times of need.
- **[Decided]** The clergy are the most neutral religious experience possible. They are pleasant, but they are human and can have a bad day, while still doing their best.
- **[Decided]** The temple handles adoption (Section 6.9), takes in the displaced (Section 8.3) and receives donated food and goods.
- **[Proposed]** The clergy use the same NPC character, memory and conversation systems as other NPCs (Section 8.8). The conversation budget (Section 3) applies.
- **[Decided]** **Who builds it and how many.** The town owner builds the temple. A town has one, and a second becomes available at the city stage. (This is the starting rule.)
- **[Open]** What a temple costs (waits for the money scale).

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
- **[Decided]** **Starting spirit.** A new camp starts with a neutral or high spirit, because people are excited to build something new. (Suggestion: start at 70 on the 0 to 100 scale.) When the player arrives on a new island the weather should be nice or reasonable.
- **[Decided]** **What lowers spirit.** Rain during the day lowers it by a point or two. Rain at night makes no difference, because people are inside resting. An attack by goblins or bandits lowers it by about a point. Others, as they are added to the game: an NPC with a cold or sick, someone aging out and dying, someone attacked by a bear in the woods, starvation.
- **[Decided]** **What raises spirit.** Finishing buildings, getting the wall up, installing the well, and successfully repelling an attack, especially if every goblin is killed. If the attackers only retreat, tired of attacking, and just one or two die, fear remains and spirit may not rise. Feeding the town for a few days by hunting or fishing raises it a lot.
- **[Decided]** Fresh water, a temple and guards raise the base spirit, in addition to the permanent features above.
- **[Proposed]** Small daily events move spirit by 1 or 2 points and big deeds by about 10, matching the sizes above.
- **[Idea]** **Bulletin board on the manager building,** like the one in Medieval Dynasty, updated regularly like a town newspaper. First it lists things people are happy about. Under that come prayer requests ("please pray for Bob, he is very sick", "please pray for Mary, her husband was eaten by a bear yesterday"). At the bottom are job notices: looking for people to gather berries, to go hunting, to work in the local mine. These are temporary jobs that lift spirit and also bring wealth and food.
- **[Open]** How the notices are written (suggestion: by the language model from the town's real events) and how many jobs the board can hold at once.
- **[Open]** The sizes of each deed, how far its weather reaches around the town, and how it interacts with crop yields and with mood details.

### 8.13 Town decline, ruin and deletion

**Decline of a player-owned town**

- **[Decided]** **Two roads to an abandoned town.** (1) The owner says "let it go" or never answers the notice: the town falls to rubble and anyone can claim the marker for free ("Claiming an abandoned town" below). (2) The owner's dynasty falls into receivership and nobody takes it over: the town reverts to the server, declines under server ownership, and is sold from the server list (Section 8.16) before it falls apart. Designated server towns (Section 8.1) never decline.

- **[Decided]** A town always has an owner. Its welfare is paid from the town's coffers. When the coffers run empty, the owner can top them up from their own wealth or let the town lapse. They still own it either way.
- **[Decided]** **A lapsing town breaks down step by step.** There is not enough money to pay for things, so the town starts cutting costs and getting rid of its weakest links by firing people. The core survives longest: guards, healing, the inn, the temple and the well. Maintenance of the walls, gates, roads and the like is cut back constantly.
- **[Decided]** **People leave one by one, by their own reasons, not at a fixed time.** A guard does not simply quit after a month without pay. Whether and when someone leaves depends on whether they are eating, whether they are living well, and what is happening to the town's spirit. It also depends on their attributes and traits: they may be very loyal but bad at handling stress, or stalwart people who weather any storm. Some leave early and some late, and the town gradually collapses.
- **[Decided]** **The last to leave is the town manager,** who quits when the last coin is gone. The owner gets a notification and has **24 real hours** to act before the manager quits. The owner can put more money into the sinking town or say "let it go".
- **[Decided]** **"Let it go."** The town is flagged for further degradation. It falls into disrepair and collapses in on itself into piles of rubble. The moment the owner says let it go, anyone can come along and claim it (see "Claiming an abandoned town" below).
- **[Proposed]** How the leaving rule could work (tunable): each NPC has a stay score worked out from pay received, food, housing, town spirit and their own traits (loyalty, stress tolerance, stubbornness). They leave when it falls below a personal threshold, with some randomness. When the town cuts costs, it fires the lowest-value jobs first and keeps the core roles. A role's rank is set by how much the town needs it, not by pay.
- **[Proposed]** If the owner never answers the 24-real-hour notice, the manager quits and the town is treated as let go. The notice goes out through every channel the owner has, with the in-world delay (Section 8.15).


**Decline of a town that reverted to the server** (not a designated starter town, which never declines; see Section 8.1)

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
- **[Decided]** **The wear rule: slow while cared for, accelerating when not.** Everything that wears (buildings, supports, roads, equipment) follows one rule.
  - While it is owned and maintained, it wears slowly from a good state, and repairs restore it.
  - From the moment care stops, wear speeds up the longer care is missing: a tiny amount in the first stretch, noticeably more in the second, more again in the third, and so on, so the worse it gets, the faster it gets worse.
  - Each kind of thing has a **time to failure** `T`, the game time from stopping care to reaching its lowest condition. The condition lost is `(t / T)` squared, where `t` is the time since care stopped, scaled down to the material's floor (next bullet). Squaring gives the speed-up: wear in each step is bigger than in the one before. (Starting shape; tunable.)
  - `T` is adjustable for everything: every material, building, support and piece of equipment has its own value in data, not in code.
- **[Decided]** **Minimum integrity.** Every material also has a **minimum integrity**, the lowest condition it can wear down to, as a percentage of its original strength. Stone is always 100 (it never wears). Wood might wear only to 50. Treated wood might wear only to 75. The floor depends on where the material is: structural wood standing outside, in rain, sun and wind, might floor at 50, while the same wood in a mine, out of the weather and the sun, might floor at 75. Condition never goes below the floor, no matter how long care is missing.
- **[Proposed]** Starting examples (tunable, held in data): stone 100; metal 70 outdoors and 85 indoors or in a mine; untreated wood 50 outdoors and 75 in a mine; treated wood 75 outdoors and 90 in a mine. The floor and `T` are chosen per material and per setting (outdoors, indoors, underground).
- **[Proposed]** Starting numbers: a mine's supports have `T` = 168 game days, which is one real week, so a player who is away for a week finds the supports at their lowest condition (their floor). Using steps of one real day (24 game days), the condition lost is:

  | Real days since care stopped | Game days | Total condition lost | Lost in that day |
  |---|---|---|---|
  | 1 | 24 | 2% | 2% |
  | 2 | 48 | 8% | 6% |
  | 3 | 72 | 18% | 10% |
  | 4 | 96 | 33% | 15% |
  | 5 | 120 | 51% | 18% |
  | 6 | 144 | 73% | 22% |
  | 7 | 168 | 100% | 27% |

  **Duress stacks with the wear rule.** Neglect and duress are separate causes. A building is neglected when the dynasty has no money to pay for care. A dynasty is under duress when its player does not come back to the game. A dynasty can have either or both. When both apply, duress makes wear up to 1.5 times faster on top of the neglect speed-up (Section 6.1).

  Maintained wear is much slower: about 5 percent of condition per game year, restored by repairs. Buildings and roads get a much longer `T` than a mine (tuned later), so towns last longer than mines. Because the server only needs the time care stopped, the condition is worked out lazily when someone looks.
- **[Decided]** Degradation is partial, and each material stops at its minimum integrity (see the wear rule above). Rubble holds the bill of materials times each material's condition. Using the starting floors for outdoor buildings: a blueprint of 1000 stone, 2000 wood, 100 iron and 200 slate leaves at worst 1000 stone, 1000 wood (floor 50), 70 iron (floor 70) and all of the slate.
- **[Decided]** Rubble is a salvage source. A player who reclaims a town can harvest the rubble for most of the rebuild materials without cutting thousands of trees.
- **[Idea]** Salvage as a trade: businesses that go around clearing rubble from ruined towns and selling or reusing the materials. Harvested rubble is gone, and the harvester gets the contents minus degradation.
- **[Idea]** Wood left in rubble could count as aged wood (and in some places petrified wood), a different material from fresh wood with its own uses and quality. Treated, maintained wood degrades much more slowly.
- **[Idea]** Iron in rubble could slowly rust over a long time, giving less usable metal, while stone never changes. This is only a flavor idea and is left open.
- **[Proposed]** Rubble is stored as a pile of counted materials, not as individual pieces, so large ruined towns stay cheap to store and to draw on the minimum machine. Harvesting reduces the counts.
- **[Decided]** **The terrain stays as it was.** The ground under a fallen town does not reset. Whatever the terrain looked like while the town stood (levelled ground, foundations, cuts and roads) is what it still looks like after the buildings fall, because nothing in the world would explain it changing. The world is made from the seed and the baked maps, and every change players and towns made is kept as a record in the server's living layer on top of that, and is applied again each time the area loads.
- **[Proposed]** Rubble is stored in the living layer as a record per pile: position, size, counts of each material and age. One pile per 100 m² of building footprint, so a large ruin can be harvested a bit at a time.

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
- **[Decided]** **Presence keeps a claim safe (modelled on Atlas).**
  - A town marker is safe as long as the owner, or a real member of their friends group (Section 6.13), is inside the reserved zone.
  - When no real player is inside the zone, a 24-real-hour timer starts counting down. Anyone from the owner's friends group entering the zone stops and resets it.
- **[Decided]** **Buying a claim during the timer.**
  - While the timer runs, a player who tries to place a claim there is told that a claim already exists and asked if they want to request to buy it.
  - If they do, the owner gets a notification. The challenger makes an offer, and the owner can accept, decline or counter-offer.
  - Declining does not stop the timer.
- **[Decided]** **The 24-real-hour takeover.**
  - If the timer runs out with nobody back inside the zone, the challenger can start a 24-real-hour hostile takeover.
  - The owner or anyone in their friends group can stop it, and reset the countdown, just by logging in and being inside the zone.
- **[Decided]** **Paid guards make a town safe from hostile takeover.**
  - Hostile takeover is only possible before guards have been established on the property.
  - Once there are guards on the property and their wages are paid, the town is safe from hostile takeover and from griefing.
  - The guards keep being paid, and keep the town safe, as long as there is game currency in the owner's dynasty or the town's coffers.
- **[Proposed]** **Suggested details (tunable).**
  - The zone that counts for presence is the town's current circle of influence (150 m for a new camp), not the whole reserved area, otherwise someone 1.4 km away would hold the claim.
  - Guards: at least 2, and 1 per 25 residents as the town grows. If the coffers cannot pay, the guards give notice for one game month (about 30 real hours, so a game-time rule) before leaving. Protection ends when they leave, and the timers can start.
- **[Decided]** **No extra grace for new claims.** Every claim, new or old, has the same two rounds of 24-real-hour protection: 48 real hours to get back inside the claim. A player who places a marker must log back in within two real days. Before placing a claim, a player should have two NPCs to assign as guards and enough money to pay their first wages (Section 8.18), and should earn it by trading at the starter town or another town.
  - The shape of the zone is not settled.
- **[Decided]** When a hostile takeover succeeds, the challenger pays the previous owner a fixed amount based on the town's value (or its rubble if it is a ruin).
- **[Proposed]** The price is the rubble value of the buildings (the bill of materials minus degradation) plus the unpaid wages and debts the new owner takes on. The server works it out from the town ledger, with no negotiation.
- **[Decided]** A town that does nothing productive but still has a manager, clean water, a temple and guards is an expense on the owner's other towns or dynasty, so hoarding idle towns costs money.
- **[Decided]** Paid guards protect a town from hostile takeover (see above). Guards who go unpaid leave, which removes the protection and ties it to the town's money.
- **[Decided]** All claim windows are in real time. How the owner hears of an offer or a challenge depends on whether the town has a manager (Section 8.15).
- **[Open]** Whether walls add anything now, what happens to buildings, NPCs and debts when the owner changes, and (separately) the shape of the zone.

### 8.15 Managers, remote control, word and safe towns

- **[Decided]** A town with no manager has nobody to deliver word to the owner. There is no notification. If the owner is in the area, a visitor can see that and make an offer at the block. If the owner is away, a challenger simply puts in a claim, and if the owner does not return within the 48 real hours of protection (Section 8.14), the challenger gets the town.
- **[Decided]** The town stays on the former owner's ledger until the next time they visit it, because they still believe they own it. On arrival they find it is owned by someone else, and it drops from the ledger.
- **[Decided]** This is a deliberate exception to the legibility principle (Section 3): not knowing about a loss until you return is part of the cost of leaving a town unmanaged. A town with a manager has no such gap, since the manager sends word.
- **[Decided]** Without a manager, the owner must be physically at the town's office to change anything, give commands or read the town's books and interface.
- **[Decided]** With a manager, the owner can control the town remotely through the manager, and the manager makes certain decisions while the owner is away. The owner sets which decisions the manager may make.
- **[Decided]** The manager makes two kinds of decisions: ones he can make automatically, and ones where he must request approval or give the owner options to choose from.
- **[Decided]** A town is unsafe, a gray area, until it is established. A camp becomes established when two NPC guards are assigned to it; a larger claim, when it has a town manager building and a guard building and the first round of guard wages is paid (Section 8.18). Once established it is a PvE area, unless it lies inside a PvP zone (Section 9.0).
- **[Decided]** In a PvE area people can make offers and visit, but they cannot hurt anything. Nobody can raise an army and attack the town. Players who cross into a PvE area can no longer attack anyone.
- **[Decided]** Inside a PvP zone there is no established status and no protection: no PvE rules, no guard protection from takeover, no safe towns (Section 9.0).
- **[Proposed]** Word delivery uses a message system with distance delay and a carrier type (courier on horseback, pigeon, ship, later enchanted pigeon). Pigeons and couriers can fail or be intercepted. A manager can send word to the owner this way. This is separate from the real-world email notifications for the player's account (Section 6), which exist for duress and receivership.
- **[Decided]** In an established town, word can travel by carrier pigeon or by magic (this is a fantasy game). A town can have a pigeon tower or a wizard tower, run by the pigeon master or the town mage (see the tiers below). A message goes to the nearest tower or mage, then onward to the recipient.
- **[Decided]** Delay depends on distance: how long a pigeon flies, or how long magic takes to reach the nearest mage or tower and then the recipient.
- **[Decided]** Matters of the whole dynasty use real-time messaging in the app. In-world mail and delay cover town business at a distance, such as an offer on a town.
- **[Decided]** When someone makes an offer on a remotely controlled town, the owner is told that they will be notified in a stated number of hours or days, based on the delay for word to arrive. The offer then stands for a time.
- **[Decided]** How long an offer stands is the offerer's choice: a set period (for example a real week, since players must have time to log in) or a permanent standing offer. The time between offer and answer is expected, because communication takes time.
- **[Proposed]** A standing offer does not lock the offerer's money. Funds are checked when the owner accepts, and an offer that cannot be paid fails with a reputation cost. A short offer could instead hold the money in escrow.
- **[Decided]** Communication improves in tiers, in line with the early-to-late quality ladder (Section 11.1):
  1. Early: a rider on horseback, or a message carried by ship. Slow, and it can fail or be delayed.
  2. Next: a **pigeon master** with coops, a building and a business. Faster over the local region.
  3. Later: a **wizard tower** with a town wizard (also called the town mage or high mage). Enchanted pigeons work with ordinary pigeon masters and coops but fly much faster, about 10 to 100 times the speed of a normal pigeon (the exact figure is to be tuned). The recipient can write a reply and send it back on the same pigeon, which then returns.
- **[Decided]** The role names are pigeon master for the coops and town mage (or high mage) for the wizard tower.
- **[Idea]** The wizard handles many roles, not just mail: solving problems around the town, defence of the town (a magical shielding dome, fighting from the ramparts during goblin or bandit attacks or a hill giant coming to ravage the town), and day-to-day research that improves the town's technology and its communication with neighbours.
- **[Open]** What a wizard tower costs, what the wizard's research actually unlocks, how strong the defence is against each threat, and the limits that keep one wizard from solving everything (for example a cost, a cool-down, or a single point of failure if the wizard is lost or hostile).
- **[Open]** The cost of sending word, whether a standing offer needs a refresh or can be cancelled any time, and the delay formula.
- **[Decided]** **Real-world alerts follow the in-world delay.** An email or app alert about a claim (a request to buy, a timer starting) is sent only when the in-world message would have reached the player. If the player is logged out in the town, the alert is instant. If they are in another town or away on an adventure, it waits as long as the message would take to reach them. With a pigeon tower, that is a pigeon's flight time over the distance; with a wizard tower and a pigeon tower the pigeons are enchanted and much faster. Without a manager there is no notification at all. Hostile claims are not possible while the town has paid guards (Section 8.14), except in PvP zones.
- **[Open]** What the manager can decide automatically.

### 8.16 Buying a server-owned town

- **[Decided]** If a town owner's dynasty falls into receivership, the town is part of what can be taken over. If nobody takes it, it reverts to the server and an administrator owns it.
- **[Decided]** A server-owned town goes on a list that players can apply to buy. The price depends on the town's size, its population, its wealth and how long it has been without an owner. It is treated like a normal business: the buyer inherits a low-spirit town and also gets its potential for great wealth.
- **[Decided]** The exact price formula is worked out later, from the town's real value and its earning potential.
- **[Decided]** A town's price falls the longer it stays server-owned, because its value falls as money runs out, buildings decay and people leave (Section 8.13).
- **[Decided]** To apply, a buyer goes to the nearest town (which can be the town itself) and talks to the town manager, an NPC at this stage. The manager talks about the town's problems and says it is available if someone good enough can be found. The buyer negotiates with the manager. If the language model judges the negotiation to be in good faith, they reach an agreement. This must happen before the town falls apart.

- **[Open]** The price formula, how competing applicants are handled, and what the manager's good-faith judgment looks at.

### 8.17 Town marker, territory and outposts

- **[Decided]** The town block is a marker with no physical form: a floating arrow only the owner can see, which the owner can switch on and off. It adds an entry to the owner's ledger saying they own a claim. It marks the exact centre of the town.
- **[Decided]** Until an office building is placed (a keep or castle with an office, a house with an office, a town hall or a magistrate's office), the owner cannot reach the town settings. The building is where the town manager lives and works.
- **[Decided]** **Towns cannot overlap, so the land is reserved up front.** Claims come in stages (camp, settlement, hamlet, village, town, city, grand city). A list gives the physical size of each, and the largest, a grand city, is the maximum a claim can grow to. Placing a town marker reserves land from the marker out to the size of a grand city, so nobody can place a marker anywhere that its own maximum city would overlap another town's. The aim is that one person can build a town into a giant city with a castle, thriving businesses and a guild of a thousand real players.
- **[Proposed]** The minimum distance between two markers is then twice the grand-city radius R. The settlement ladder below puts R at 1.5 km.
- **[Proposed]** **The settlement ladder.** A new claim is a **camp**: a marker and a tent. Each paid expansion grows it by roughly 50 percent in radius (a smaller step for the first two), and the size names follow. Radius includes the surrounding farmland, since the circle runs out to the farms.

| Stage | Radius | Area | Rough population (NPCs and players) |
|---|---|---|---|
| Camp (a new claim) | 150 m | 0.07 km² | the player and guards |
| Settlement (preparing the ground) | 200 m | 0.13 km² | up to 10: builders and guards in tents and barracks, no villager homes yet |
| Hamlet (first homes and villagers) | 300 m | 0.28 km² | 10 to 100 |
| Village | 450 m | 0.64 km² | 100 to 400 |
| Town | 675 m | 1.4 km² | 400 to 1,500 |
| City | 1,000 m | 3.1 km² | 1,500 to 5,000 |
| Grand city (the maximum) | 1,500 m | 7.1 km² | 5,000 to 15,000 |

- **[Proposed]** The reservation (above) is a grand city: radius 1,500 m, so two markers must be at least 3 km apart, and every marker reserves about 7 km² even while it is still a camp. A 50 km² starter landmass then holds roughly 5 to 7 towns, and a 100 km² landmass roughly 12.
- **[Decided]** **The ladder sizes stand for now.** For scale, medieval London inside its walls was about 1.3 km², so a 1,000 m city is already large. Doubling every radius would cut the towns on a 50 km² island from about 5 to 7 down to 1 or 2. The sizes can be adjusted later, ideally with one scale setting for the whole ladder.
- **[Decided]** **One camp at a time.** A dynasty can hold only one claim below the hamlet stage. While you have a camp or a settlement, you cannot place another camp. You must first build it up to a hamlet, the stage where it has homes and villagers. Only then may you go exploring and place a second camp.
  - The camp is the tent. The settlement is the introductory stage where you prepare the ground for a liveable place. At the hamlet stage it actually has homes and villagers.
- **[Proposed]** Details to work out later: if a camp or settlement is let go, lost or abandoned, the player may place a new one; buying an existing town is not limited by this rule; a hamlet that falls into ruin keeps its stage, so it still counts as a hamlet for this rule. This also limits marker hoarding (Section 15).
- **[Proposed]** Moving up a stage needs the paid expansion plus a floor of buildings and population, so a stage name means something. "Established" status (Section 8.18) does not depend on the stage: a camp with two guards is already established.
- **[Decided]** **An expansion costs what it really costs, and the money does not vanish into the server's coffers.** The cost of a step is the materials and labor the expansion needs: more builders, more guards, more supplies, and wages for the people at the stonemason, the lumber mill and the rope making. It includes a new, bigger and stronger wall, for example palisade logs, then stonework, and spike walls outside the palisade.
- **[Decided]** **Costs are worked out from what the work takes.** Over time we calculate each expansion's cost from the materials it needs and the pay of the people who do it. Each stage must be priced with the next step in mind: once the expansion is done, the first building wanted next costs a certain amount, and the town needs the money to buy it, so that building can earn the money for the one after.
- **[Proposed]** **How to price a stage (tunable).**
  - Each stage has a plan: the new wall ring, new roads, the required buildings and the extra guards. The planner turns it into a bill of materials and a labor estimate. The gold price is that bill times the market prices, so it is calculated and not typed in.
  - Wall type grows with the stage: no wall for a camp (a tent), palisade for a settlement and hamlet, palisade with a ditch and outer spikes for a village, stone for a town and a city, stone with towers for a grand city.
  - The old wall is taken down and salvaged by its condition. A wall in good shape keeps all of its wood and all of its stone when it is taken down, so the next wall costs only the new material. Loss happens only through wear, down to each material's minimum integrity (Section 8.13).
  - A longer wall needs more guards: at least one guard for each 100 m of wall plus the one per 25 residents already proposed, whichever is larger.
  - **Balance test:** a stage is priced correctly when the town's net income at that stage repays the expansion in 1 to 2 game years (15 to 30 real days). If it takes longer, the stage is too expensive. If it pays back in days, it is too cheap.
- **[Proposed]** **Requirements still apply** (tunable): enough residents and buildings, so a stage name means something.

| Step | Residents | Buildings |
|---|---|---|
| Camp to settlement | none | a town manager building and a guard building, wages paid |
| Settlement to hamlet | 10 | the first ten, built, including homes |
| Hamlet to village | 100 | 25, including blacksmith, granary and mill, and healer |
| Village to town | 400 | 60, including a market hall and a second well |
| Town to city | 1,500 | 150, including a harbour or a major road hub |
| City to grand city | 5,000 | 400 |

- **[Proposed]** Population figures are guides, not caps. The NPC population cap per island and region (Section 8.2) and the language model budget (Section 3) limit the NPC share. The player share of a grand city is the thousand-strong guild case.
- **[Decided]** **Homestead.** A homestead is a home, not a town. It starts like a camp: the player places a marker and a tent, and that is a **homestead camp**. It does not grow into a town. It grows into a bigger home instead, such as a house, then an estate, then a keep or castle. The stages and sizes of homes are to be designed later.
- **[Proposed]** Details (tunable): a dynasty has one homestead at a time, and it does not use up the one-camp slot of the town ladder. A homestead has a small fixed circle (suggestion: about 100 m, growing with the home), needs no town manager, and can be protected by two guards in the same way as a camp. It gets a small outpost budget (suggestion: 2 points, Section 8.10).
- **[Decided]** An outpost reserves only its own area, whose size depends on its size class (Section 8.10).

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
- **[Open]** Whether the rings are fixed rules or only planner preferences, the maximum span and water depth of a bridge, the kinds of bridge (rope, timber, stone), and who maintains roads formed by travel. (Expansion costs come from real materials and labor, and abandoned markers are claimed as in Section 8.13.)

#### Road, mine and tunnel builders

- **[Idea]** **Road builder (player tool).** The player picks two points on the map. The builder works out what it thinks is the best route, weighing slope, shortest or shallowest water crossings (a ford where shallow, a bridge where not) and where bridges are placed. It shows the proposed path, and only after the player approves does it do the ground work (levelling, averaging, smoothing) and build the road surface in the chosen type. Road types, exact costs and workers are open. Related: the town planner (Section 8.4), road condition and wear (Section 8.13), blueprint levelling checks (Section 10.1).
- **[Open]** How the road builder relates to the NPC-formed dirt roads (above): whether it follows and upgrades them, whether it reuses their route, and who maintains the result.
- **[Idea]** **Mine builder (admin tool, not a player feature).** An administrator stands at a spot and says "dig a mine here". It places a small mine shack and an entrance, then digs the mine out in front of them: a descent at a chosen angle, cave bracing placed every so many meters (following the support and wear rules in Section 8.13), and a little randomness up and down and left and right so it looks hand-carved with a pickaxe and not laser-straight. It can also add side shafts at random and other small touches, and grow into a full working mine. At first it changes voxels in the living layer only (nothing is baked into the tile). An administrator X-ray view, or an AI that reads the tile's geology and ore bodies, could pick a spot worth mining.
- **[Idea]** **Tunnel builder.** The same machinery, horizontal: it picks an entrance and an exit on opposite sides of a mountain and digs a reasonably straight tunnel between them (the Mines of Moria idea). If it breaks into a natural cave it adapts: a narrow gap gets a bridge or land bridge; a cave too big to bridge gets a road carved down one wall, across the floor and up the other side. Once built, a tunnel is a normal route option for the road builder, like a ford or a bridge.
- **[Idea]** **Tunnel types.** Small, creepy tunnels, up to epic dwarven ones. The grand dwarven road is a highway through the mountain: wide enough for oxen and carts to pass travelers coming the other way, very high ceilings (so the smoke of giant braziers, the light source, can rise and stain the ceiling dark), massive bridges on tall pillars down to the cave floor over any cave however large, and enormous, magically opened doors at the entrances. Dwarves like things grand.
- **[Open]** Mine builder questions: how it relates to the player mine outposts and the mine chain (Section 11.2, supports and bracing) if at all, whether players can own or claim an admin-dug mine afterward, whether it can author dormant mineshafts and lairs (Section 4.4), and how tunable the randomness and the bracing interval are.
- **[Open]** Tunnel types and costs, who may build tunnels (admins only, or players as large engineering projects), the maximum tunnel length, and the door magic.

### 8.18 Becoming established, water, and the first steps for a new character

- **[Decided]** **A camp is established by two guards.** A claim starts as a camp: a marker and a tent. If the player has two NPCs travelling with them, they can assign them as guards, and the camp is immediately established and PvE safe (and protected from hostile takeover, Section 8.14). Their wages are paid as for any guard.
- **[Decided]** **From a settlement up, established is two buildings and a payroll:** a town manager building and a guard building, with the guards' first wages paid. A well and a temple are not required.
- **[Decided]** **Wells.** A well provides clean water without limit up to a number of units per day. A small population has plenty from one well. A larger one needs several. A town with no well can buy water and food from another city on the same island or on a neighbouring island.
- **[Proposed]** Suggested numbers (tunable): one well supplies 50 residents. Requests to buy supplies reach towns within 2 tiles (about 31 km) of the town marker, which keeps the supply route within one day's sail. Supplies arrive by NPC cart or ship, so delivery is not instant.
- **[Open]** Whether the supply distance is server-wide, a number of tiles or a number of kilometres (the suggestion above is a number of tiles).
- **[Decided]** **The design goal for the beginning:** the start is challenging, with a little ramp-up and onboarding. Once the hard early work is done, things get easier, so the early investment is valuable and players do not want to start over.
- **[Decided]** **A starting character's first steps.** Work on the starter island: freelance harvesting, adventuring, fishing and hunting, and selling goods at the starter village market, until there is enough wealth either to build their own town on the starter island or to build or buy a first ship.
- **[Decided]** **Getting a first ship.** Two ways:
  - Pay for the blueprint and gather all the materials yourself.
  - Pay a shipyard to build it. You provide all the game currency, the shipyard builds it over time, and you can watch it being built while you keep adventuring on the starter island.
- **[Decided]** **A ship is the first base.** It has value, can carry shipments and deliveries, and can go adventuring. A player can log out in it while anchored in friendly waters.
- **[Decided]** **Ship wear.** A ship degrades very little, or very slowly, over time. Damage comes from running into other ships, hitting rocks, very bad weather, or being shot by enemies.
- **[Idea]** The boat system is imagined as similar to Atlas. When we start building it we will review what we like and do not like and decide then.
- **[Decided]** **Many tiers of boats.**
  - Very small boats for getting around an island and fishing.
  - Small boats that handle longer voyages and are faster because they are longer.
  - Long, narrow boats built for speed.
  - Bigger, heavier boats built for cargo.
  - Massive ships at the top, which take days to build and are never starter boats.
- **[Decided]** **Build time grows with size.** The smaller the boat, the faster it is built. A first-tier boat is ready in about 6 game hours (15 real minutes; it may even be bought already built), the next tier about 12 game hours, then 18, then a full game day (one real hour). At the large end, the basic frame, deck and sails of a big ship takes about 24 game days (a full real day). Nobody should wait an hour or two of real time for their first boat.
- **[Decided]** **What a shipyard sells.** A purchase from a shipyard is the basic boat: hull, sails, anchor and decks. The owner installs the steering wheel and fits the ship out, as in Atlas, if it is a bigger ship. Smaller ships are pre-designed, again like Atlas.
- **[Decided]** **Boats are trade goods.** A town with its own shipyard can build boats for other players and sell them. An owner can sell a boat to someone else.
- **[Open]** Build times for the middle and top tiers, prices, blueprint prices against finished ships, and where players can anchor safely when logged out.

### 8.19 The first ten buildings

- **[Decided]** **The town manager building comes first.** It is the building where the owner makes decisions. The owner can hire a town manager to run it. Once there is a town manager, the same building can also hold a **town planner**, who uses AI to scan the area and decide where natural roads would go and where to put the well, the temple and the guards.
- **[Decided]** **The temple costs the town money but lifts the base town spirit.** It is a liability, but it gives a place for orphans, counselling, food or financial help, and protection. The **well** has upkeep, which is a cost to the town.
- **[Decided]** **Walls and the inner circle.** From the settlement stage up, a claim is surrounded by a wall (a camp is only a tent), even if it sits next to the water, so there is no open area that lets people into the innermost circle. The inner circle holds the core buildings, such as the manager's house and the guard house. The **harbour is always outside the wall**. The sawmill and the stonemason are **temporary fixtures** that start near a gate and are gradually moved further out of town later.
- **[Decided]** **Self-sufficient from the start.** The first settlement needs wood, stone and rope. Rope comes from harvesting plants for thatch and fibre. At first, rope and wooden pins join beams together to build walls, buildings and joinery. These are the rustic starter buildings, upgraded and improved over time. A blacksmith comes later. Until then the settlers can bring nails and hinges, or raw iron, bought at the starter village.
- **[Decided]** **The settlement starter kit.** A kit sold as one heavy box that takes one inventory slot. It would fill the weight of a second- or third-tier starter boat. It contains everything needed to start a town or a homestead camp, and the player must earn the money to buy it first.
- **[Proposed]** **The ten things a new settlement needs, in the order the planner builds them:**
  1. **Town manager building** (also the owner's house if the owner wants to live in it). Everything starts here.
  2. **Roads and the central square**, laid out first by the planner, with the well in the square.
  3. **Sawmill** (a lumber yard), near the gate on the road to the forest. Temporary.
  4. **Stonemason** (with a quarry crew), near the gate on the road to the mountains or quarry. Temporary.
  5. **Guard barracks**, with a guard captain and guards. Then the wall and gates.
  6. **Weaver and rope maker.** Uses fibre and thatch for rope, baskets, nets and cloth. Rope is how the first buildings are joined.
  7. **Storehouse** (settlement warehouse).
  8. **Homes** for the builders, at least three cottages.
  9. **Inn** with rooms and market stalls. Tents come first (see Section 8.20).
  10. **Temple** (a small chapel). A cost, but it lifts the base town spirit.
  The wall and its gates are infrastructure, not one of the ten. The blacksmith, granary and mill, farmland and healer come in the second wave.
- **[Proposed]** **What comes next** (second wave): blacksmith, granary and mill, farmland, tannery, baker and butcher, healer, a second well, more homes, the harbour and shipyard outside the wall, and then the sawmill and stonemason moved further out.
- **[Proposed]** **Space needed (estimates).** Inside the wall, with yards: manager building 200 m², well and square 1,600, barracks 400, storehouse 300, weaver 300, homes 840, inn 400, temple 400. Together about 4,400 m². Roads and paths add about 30 percent and room to grow doubles that, so the walled core is about 1.2 hectares. A wall around it at a radius of about 70 to 75 m is about 450 m long, with two gates, one toward the resources and one toward the water. The sawmill and stone yard sit just outside the gate, and the 200 m circle of a settlement (12.6 hectares) leaves the rest for farmland.
- **[Open]** Whether the first ten are the right ten, the exact footprints, and what the expansion steps cost (Section 15). Expansion is decided after the building list and sizes are settled.

### 8.20 Building a settlement: the planner's order

- **[Decided]** **The manager building.** The owner can live in it and can run the town without hiring a town manager, and can build everything by hand. The game makes this easier with NPCs who take up the jobs.
- **[Decided]** **A planner hired into a town** (with an owner and a town manager) is responsible for hiring a couple of builders. The planner studies the terrain around the manager building and plans in this order:
  1. Where the starter roads go, with room for a town square or circle, thinking about long-term growth.
  2. The blueprint for the wall around the property, at low priority so it is not built first.
  3. The sawmill and the stonemason near the opening in the wall where the road to the forest or the mountains passes, so resources come straight in. These start their logging and quarrying crews, and can hire NPCs to gather stone or dig it from the nearest mountain or quarry site.
  4. Then the first barracks, the guard captain and guards, then the wall and the gates.
  5. Whatever buildings supply the next materials needed.
  6. The first houses, because the builders need somewhere to live.
- **[Decided]** **Gates close at night.** Every worker comes in at dusk and must be inside before the gates close. At dawn the gates reopen and the working day continues.
- **[Proposed]** **Trades.** Fibre and thatch go to a weaver and rope maker, who makes rope, baskets, nets and cloth. Guards report to the barracks. Whether they live in it or in their own houses is open.
- **[Decided]** **Tents first.** Early on, supplies include tents that are set up during construction. Inside is a campfire in the middle, and each side of the tent has a bed and a storage chest. They are temporary shelter from the weather until the inn and houses are built.
- **[Decided]** **Hiring guards once the barracks stands.** The owner or manager can hire any available guards in the area, meaning existing NPCs with guard experience. Their wages are set by their experience, and also by how hungry they are and how low their own spirit is from being poor or unemployed.
- **[Decided]** **If no guards are available,** the barracks suggests four randomly generated new guards. They live in the barracks. Each has their own attributes, characteristics and skills.
- **[Decided]** **The guard captain.** Given enough time, one guard is promoted to guard captain by the town manager, or by the owner if the owner plays that role. The captain manages the guards and assigns patrols and night watches. Other jobs for guards will be added later.
- **[Proposed]** Wage rule to start with: a base wage times a factor for experience (0.8 for a rookie up to 1.5 for a veteran), times a discount of up to 30 percent for a guard who is hungry or has been out of work for a long time. The base wage is set with the rest of the economy. Guards who need work take less, but are less loyal if they feel underpaid later.
- **[Decided]** **Wage negotiation with a step-up.** A veteran guard who is tired and hungry may agree to start at a lower wage, but expects a raise over the year toward veteran pay: a small increase each month, agreed in the negotiation.
- **[Proposed]** How the step-up works: the raise per game month is the gap between the starting wage and the veteran wage, divided by 12, so the guard reaches full pay at the end of the first game year (15.2 real days; a game month is about 30 real hours). If the town skips a raise, the guard's loyalty falls and they may quit. The language model speaks the negotiation, but the game keeps the figures.
- **[Decided]** Guards who are generated for the barracks live in it. Other guards hired from the area may live in their own homes and report to the barracks. The player character chooses a place to live eventually.
- **[Open]** The base wage and the pay scale, and what else guards do besides patrols and night watches.


---

## 9. Law, crime and recognition

### 9.0 PvE and PvP

- **[Decided]** The starter areas are definitely PvE (no player-versus-player combat).
- **[Decided]** **PvP zones are a world-level map.** PvP is offered through zones. Each zone is a range of world coordinates ("from this coordinate to this coordinate is a PvP zone"), stored in `world.json`, not in the tiles. There can be several zones, and they can be moved or adjusted later.
- **[Decided]** **PvP zones are the wild West.** There are no protections. Nothing is safe, no town counts as established, and guards do not make a town safe from takeover. A player who wants a town there must run in and set up the town completely under the threat of PvP. Starter islands and PvE zones keep every protection in this document.
- **[Decided]** **Players do not choose PvE or PvP.** They get it by entering the different zones.
- **[Decided]** **A warning at the border with three choices.** A player in a PvE zone who travels toward a PvP zone gets a warning that they are entering a PvP zone, and what will happen. They choose one of three options: **go PvP**, **go spectator**, or **go back**. Until they choose, they cannot move forward. Going back takes them back out of the zone.
- **[Decided]** **Leaving takes a run (the project owner and his son's idea).** Once in a PvP zone, to get out a player must cross the border and then travel a further random distance into the PvE zone before their PvP status drops. The distance is rolled when they enter the PvP zone. This stops people from sniping or sneaking into a zone, taking shots, and running back to safety. A character caught doing something they should not, who is chased toward the PvE zone, can still be killed legally on the way.
- **[Decided]** **Entering has to be a real danger, unless you enter as a spectator.** A spectator can go into the zone, go on adventures and fight monsters, but cannot harm other people or other people's belongings. This lets players watch a war, an invasion or a server event while staying safe.
- **[Proposed]** Suggested details (tunable): the exit distance is rolled between 200 and 800 m. Spectators are visibly marked (for example a ribbon or glow) so others know they cannot be harmed or robbed, and spectators cannot take part in combat or pick up other players' things. A spectator who wants to fight must leave and re-enter through the border warning. Zones are rectangles or polygons in `world.json`. Starter islands are never inside a PvP zone. If a zone is moved while players are inside it, their status stays until they have run their exit distance.
- **[Open]** What dying in a PvP zone costs the dynasty, how PvP zones relate to war between towns, and which parts of the map get PvP zones first.

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

### 9.3 Missing people, abandonment and betrayal

- **[Idea] (brainstorm)** What a companion does after fleeing matters as much as fleeing. Fear is understandable; abandoning someone and hiding it is much worse; running for help can be heroic. Fleeing, reporting at once and bringing guards may earn praise as a rescuer; reporting honestly but refusing to go back gets mixed judgment; lying and hiding that someone is missing costs trust and may bring an investigation and penalties; stealing their things, inventing a story or breaking a paid promise of protection can be serious crimes.
- **[Idea] (brainstorm)** Towns respond quickly. A sharp gate guard remembers two people leaving together; when one comes back alone after dark, nervous or evasive, the guard asks where the other is, and a suspicious answer sends two guards to search at once. The aim is a fast rescue, not finding an abandoned player three game days later. Guards, innkeepers, spouses, family and companions can all notice someone missing. Rescue first, justice after.
- **[Proposed] (brainstorm)** A light **missing-person** system tracks witnessed departures, intended routes, overdue arrivals, conflicting reports and search parties, and moves those NPCs up the language model queue.
- **[Idea] (brainstorm)** Betrayal can lead to confrontation, fights, compensation, fines, court, debts or restitution from the offender's assets or estate. Suggested limits: feeling wronged does not make an attack lawful, and innocent relatives do not automatically pay personal debts.
- **[Idea] (brainstorm)** Reputation damage spreads through witnesses, reports, investigations and rumor, never an all-knowing server broadcast. Magistrates and guards work from evidence, imperfect testimony and context.
- **[Open] (brainstorm)** The law on personal revenge, what magistrates can do, and whether and how a dynasty's wealth answers for a member's debts; the minimum believable search when NPC reasoning fails.

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
- **[Proposed]** A shared material catalog for building pieces (flammability, strength, source of raw material, time to failure `T` and minimum integrity by setting, Section 8.13) read by fire, repair, wear, shelter and trade.
- **[Open]** Whether treatment is a crafted material (treated planks) or an upgrade applied to placed pieces.
- **[Open]** Whether weather and wind affect fire.
- **[Open]** Who fights fires: players, NPC brigades, or both.

---

## 11. Production and logistics

### 11.1 Tools, machines and automation

- **[Decided]** Eventually, players use materials to build components and tools that help them mine or climb mountains.
- **[Decided]** **Quality tiers for items.** Tools, weapons, cookware, crucibles and similar items come in material tiers, and a lower tier still works but does the job worse, which gives the game stages: crude stone and wood, bronze, iron, then steel, as in the Bronze Age and Iron Age. Examples: clay crucibles then graphite crucibles; iron tools then steel tools; unhardened then hardened edges (quenching and tempering).
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
- **[Decided]** Mines and caves can become unstable. A natural cave stays up as long as its openings are small enough; the bigger a man-made opening, the more it needs support. Miners must shore up their workings with timbers or pillars, and supports slowly wear and need maintenance. This is a deliberate difference from games where players can dig out huge spaces for free.
- **[Decided]** If a mine lies inside a town block or an outpost block, its support maintenance falls under the town's repair schedule. Builders do not have to be physically present: the supports age and are repaired automatically on the town's schedule, and the cost comes out of the mine owner's account.
- **[Decided]** **Every mine and outpost belongs to something.** An outpost, including a mine, is always attached to a town, a homestead or a player. It never stands alone.
- **[Decided]** **How a mine becomes abandoned.** There are two ways, and no separate abandonment timer:
  1. **Its owner stops paying.** If the owning town falls into decline and stops paying its bills, the mine is one of the things it stops paying for. The moment payment stops, the workers quit and repairs stop, and the mine declines on the same schedule as the town. If the town cut the mine off earlier, the mine decays earlier. A homestead or player owner works the same way: when the money for upkeep runs out, repairs stop.
  2. **The owner chooses to abandon it.** Repairs stop from that moment.
- **[Decided]** Once repairs stop, the supports gradually fail. Depending on how well supported the mine was, it may cave in completely, or only partly degrade and leave an old abandoned mineshaft behind. A cave-in only refills the workings with rubble. The land above does not sink.
- **[Decided]** **Supports follow the general wear rule** (Section 8.13): slow wear while owned and maintained, and wear that speeds up the longer care is missing. Mine timbers are dry and out of the sun, so they stay in good shape while maintained.
- **[Decided]** **Supports work like torches in Minecraft.** Each support holds up the ground within a reach of itself. Its strength is greatest at the support and fades with distance, and past the reach it is not enough. Supports placed closer than their reach overlap and add up, so a mine with closely spaced supports stays up much longer than one with the minimum. Supports placed at the maximum spacing leave the weakest spot in the middle between two of them. An abandoned mine therefore fails first at those middle spots, while the ground next to the old supports stays standing. That is how an old mineshaft survives in pieces.
- **[Proposed]** Starting numbers (tunable): a support reaches 10 m, so one every 20 m just touches; strength fades in a straight line from full at the support to a low value at the edge; overlapping supports add up to a cap of full strength; the strength a spot needs grows with the size of the opening; a spot holds while its total strength, multiplied by the supports' condition, is at least what the opening needs. A mine whose supports are left unmaintained fails by the wear schedule in Section 8.13: the weak middle spots go first (around days 4 to 5 of neglect in the table), and the supports reach their floor in about 168 game days (one real week); whether the mine caves depends on that floor and the strength its openings need. The server stores only each support's position, kind and install time, and works out strength lazily from timestamps.
- **[Open]** Exact fade shape, the strength an opening of each size needs, and which outcome happens in a given mine (full cave-in, partial degradation, or a surviving old shaft). Keep it simple: these are a few numbers, not a structural simulation.
- **[Proposed]** What the collapse does not do: it does not bring ore back (the tonnage taken stays taken), and rubble can be dug out again, so an abandoned mine can be reclaimed at the cost of clearing and re-shoring it. The server tracks each mine's support health as a few numbers (opening size, supports installed, last repaired, owner funded or not) and resolves wear and collapse lazily from timestamps, like regrowth, so it works while nobody is nearby.
- **[Decided]** When a player's mine does collapse (or is left to), it slowly reverts to its natural state: erosion and water filling it in. A ruin is left on the surface, such as a collapsed entrance, old timbers and spoil heaps, so other players can tell there used to be a mine there. That is a hint that resources may be nearby, though the ore taken is still gone. The ruins fade as the mine fills in.
- **[Decided]** Mines of dynasties that revert to NPC go to the town to claim (Section 8.6); the town pays for the repairs before allowing a cave-in.
- **[Open]** How big an opening needs supports, what kinds of supports there are (timber, stone pillars, masonry arches, later iron), whether a collapse can trap or injure miners inside, and whether natural caves can ever collapse after players dig them wider.

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
- **[Decided]** Town circles never overlap. Placing a town marker reserves land out to the size of a grand city (Section 8.17), so no one can place a marker whose full circle would overlap another.
- **[Open]** What rights player residents of a town have (leave, protest, vote out the owner) or whether the owner rules unchallenged.
- **[Open]** How many tax levers there are: a few simple sliders (shop tax, farm tax, militia budget) or detailed rules for goods and groups.

### 13.2 Markets

- **[Decided]** Market prices are not regulated. Players, player towns and businesses set their own prices and the market decides whether to buy at them: price too high and nothing sells, too low and stock sells out fast, leaving money on the table. NPC buyers (including admin towns) compare prices and buy where it suits them.
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
- **[Decided]** A future market interface, where players shop, make deals and set up trade agreements, shows each offer's price together with its distance, delivery time and how often shipments come. Delivery time is part of the deal: a cheap load of logs that takes two weeks can lose to one at twice the price that arrives tomorrow from the next island. Quantity matters too: each offer shows how much a shipment carries, so a ship from further away carrying ten times the logs at a better price per log can beat a closer wagon. Each offer also says whether it is a one-time shipment or an ongoing contract delivering at regular intervals (and how often). The market panel puts one-time offers and contracts on separate tabs.
- **[Proposed]** Delivery times come from the same route data the wagons and ships use (road or sea path, travel speed, waiting for a free wagon or ship), so what the interface promises is what actually happens. Offers can be sorted by price, by price per unit, by quantity, by arrival time or by total cost including transport.
- **[Decided]** **Reputation is personal, not global.** Each trader's reputation is worked out from our own point of view: our history with them, and their history with our allies. Things that hurt it include known piracy, taking money and not delivering, not supplying what was promised, and any similar breach. Affiliations count too: membership of a faction or political group we disapprove of lowers it, membership of a guild we like raises it. There are no factions yet; for now the groups are the town a player lives in and their friends group (Section 6.13). The market panel shows this reputation beside each offer.
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
- **[Proposed]** A dynasty owning several businesses is several entries in the shared business structure. The town gains from successful businesses through taxes, so a manager NPC offering contracts or loans to struggling businesses follows naturally.

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
- **[Idea] (brainstorm)** A rescued player's story (say, of a mysterious figure) spreads through rumor, changes how NPCs treat them, draws investigators and may end up in a local newspaper or the archive. Townsfolk react by belief, fear, doubt and relationships: one hears "ghost", another "criminal", another "just a hermit". Each witness (survivor, rescuer, innkeeper, guard, reporter) remembers the same event differently.
- **[Idea] (brainstorm)** A newspaper editor collects stories from people; the paper is not a truth feed. Editors can be careful, mistaken, biased or sensational, and wrong articles and journals can still shape later generations. Close to the town bulletin board idea (Section 8.12).
- **[Open] (brainstorm)** Printing in a medieval fantasy setting: technology, cost, how often, literacy, archives and the law on false reports.

### 13.7 Work buildings, stock and maintenance

- **[Idea]** Every job runs through a building with worker slots: farming huts, barns, mines, the smithy, the warehouse, the trade manager's and planner's offices. Slots are filled by the player, family or hired hands. Settings live on the building, and workers keep going until the work is done.
- **[Idea]** A mining town employs most of its villagers in the mines excavating stone, coal, ores and other valuables, ships them across the map to other towns for currency, and buys what it lacks from other towns.
- **[Idea]** Stock targets start at zero. When something is built, the largest amount needed becomes the stock target: a building needing 500 nails sets the nail target to 500. If 30 hinges are needed, the blacksmith makes the 30 and another 30 for the town warehouse. A larger requirement later becomes the new target.
- **[Idea]** Builders always pull supplies from the warehouse first. If something is missing they order it through the town manager. If the town has the tradesperson who makes it, they start filling the order and topping up stock automatically. If not, the order goes to the nearest town that has it. If no town has it, a notice is raised with the town manager, who tells the owner something needs attention.
- **[Idea]** All buildings degrade slowly and need maintenance. Builders do the repairs, and the cost comes from the individual shop or owner. This steadily uses up supplies.
- **[Idea]** The warehouse manager, merchant or shipper takes stock now and then and decides where to set stock amounts.
- **[Proposed]** Maintenance is the economy's steady sink for materials and money, which a long-running server needs to avoid surplus and collapsing prices.
- **[Proposed]** Materials affect upkeep through the wear rule (Section 8.13): each material has its own time to failure and minimum integrity, so stone outlasts wood and treated wood outlasts untreated. Wet or coastal climates rot wood faster. Neglect reduces function and shelter and eventually leads to ruin.
- **[Proposed]** A business schedules repairs automatically when it has the funds, and the "while you were away" report lists what was repaired and what it cost.
- **[Proposed]** The warehouse manager's review uses the language model budget in Section 3: about once per game season, given usage figures, replying with new targets within allowed limits, with the reason logged. Targets that go unused drift back down.
- **[Proposed]** A short "what is blocked" list in the town panel ("waiting on iron") keeps the chain visible.

### 13.8 Real money (future)

- **[Decided]** **Free to play, paid through small purchases.** The game is free and must run on older computers. There is no required monthly fee. Revenue comes from small, reasonable purchases:
  - cosmetics such as holiday outfits, and special or event versions of gear, never anything extremely overpowered;
  - simple goods that starter towns already sell, such as an iron sword or silver sword, for players who want to save time and effort on basics;
  - in-game currency, which also lets someone who wants to be rich buy a lot of it, and the owner does not mind. For example, a player could spend a couple of hundred dollars and use it to take over someone else's dynasty in receivership (Section 6), then spend more to repair it and inherit its tools, weapons, animals and family.
- **[Decided]** Paid duress blocks (Section 6) are a purchase of the same kind. Their prices are not set yet: they will come from a market analysis later, looking at what players will accept. For comparison, many players refuse $15 a month for games like World of Warcraft, but $5 a month or $60 a year would be much less of a dealbreaker.
- **[Decided]** Gambling (including wagering at the pub) is flagged for a future discussion, to be revisited when that work starts.
- **[Proposed]** Currency bought from the game buys real power in a player-driven economy (land, guards, armies) and adds inflation. Caps or the token model reduce both.
- **[Proposed]** Selling currency, and especially combining it with gambling, can fall under gambling, consumer protection and payment processor rules that vary by country. Get legal advice before any real money is involved.
- **[Proposed]** Until then, design the economy to work without real money. The whole-number ledger already makes a token model easy to add later.

---

## 14. Current code status

The new generator lives in `src/worldgen/` on branch `claude/generator-v2` (GDScript, run headless in Godot). The plan and its progress log are in `GENERATOR_V2_PLAN.md`.

**Built and tested (877 checks pass, 2026-10-16)**

- Step 14 first version: the runtime terrain generator (`src/worldgen/runtime/`), GDScript, about 18 ms per 32 m block, with a walk-and-fly preview scene. **[Proposed]** Keep it in GDScript until server streaming shows it is too slow, then move it into a small C++ module in the custom engine. Details in `GENERATOR_V2_PLAN.md`.
- Step 15 first version: runtime trees and plants from a species table, sent by the server, drawn in the client and preview, with removals stored (Section 4.3).
- Step 16 first version: a terrain server streaming blocks to a client with a disk cache (`src/stream/`, `scenes/terrain_server/`, `scenes/terrain_client/`). See Section 4.10 and `GENERATOR_V2_PLAN.md`.
- A Linux build of the project's engine (Godot 4.7.2 with Voxel Tools 1.7) for cloud sessions: `tools/build_godot_linux.sh`.

- World settings, SHA-256 seeds, append-only data tables (biomes, soils, rocks, resources, water classes, site types, feature types, province kinds).
- The world sketch and a seamless 160 m elevation map of the whole world, the fixed features (central trench, ultimate island), the danger map, and the derived tile plan (312 islands, 227 tiles with land).
- For one tile (the starter tile (3,4)): the 8 m height map, erosion, water (rivers, lakes), climate, biome, soil and fertility, geology (provinces, features, ore bodies, placers), and natural caves, dormant lairs, harbor and starter spawn. About 2 minutes in total.
- Preview images for each stage.
- The tile file writer and reader (`tile_file.gd`, step 13): header, section table, Zstandard sections with SHA-256 checks, atomic rename, all maps, low-resolution maps and lists; the starter tile is written and read back and every section checked.

**Not built yet**

- Flora regrowth and harvesting yields, grass near the player, the layer for player changes (beyond the test dig and test tree cut). (Rivers across tile edges, edge matching and wrap-seamless noise were built in step 13b; a first runtime terrain generator in step 14, see below.)
- Any game system: players, NPCs, towns, building, law, economy, machinery.

**Old generator.** The earlier volumetric pipeline (10 by 10 region tiles, about 15 to 16 hours per tile) is still in the repository and untouched until the new one replaces it (plan step 19). `README.md`, `GENERATION_GUIDE.md`, `PROJECT_ROADMAP.md` and `CHANGES_THIS_PASS.md` describe it.

**Not checked**

- How the client performs on the minimum machine (Section 3). The starter tile file measures 9.85 MB (the earlier estimate was about 52 MB before compression).
- Whether river flow data could be queried at runtime to power water wheels.

**Current values**

- World height -4,000 m to +2,048 m, sea level 0, 1 m voxels, 15,360 m tiles (15 by 15 regions of 1,024 m), 8 m map grid, 21 by 21 tiles.
- Rock types (11): sediment, shale, limestone, coal, granite, slate, basalt, sandstone, marble, chalk, tuff. Resources: IDs 1 to 31 (Section 4.9a).
- Default server capacity: 32 clients.

---

## 15. Open questions

Only genuinely open items are listed. Everything decided lives in its own section. Where a number is needed, a suggestion is given.

**World and bake**

1. Size variety of islands, from tiny rocks to ARK-scale (Section 4.1). Suggestion: the current plan's mix.
2. Diving limits, whether the deep ocean floor can be dug, and whether the bottom kilometer is detailed or baked simply (Section 4.5). Suggestion: bake simply, add detail later.
3. Whether terrain mining is in the first version (Section 11.2). Suggestion: no.
4. Whether NPC miners carve tunnels or draw down a deposit's amount (Section 11.4). Suggestion: draw down the amount.
5. How far altitude effects reach below the 2,048 m ceiling, and how far polar sea ice reaches (Sections 4.2, 4.5).
6. Island size classes against the bigger tiles: land fell from about 11% to about 6% of the world (Section 4.1). Suggestion: leave it until the first playtest.
7. Runtime voxel generation on the server against baked files, the streaming and cache plan, and floating origin against double precision (Sections 4.8, 4.10). Suggestion: streamed blocks plus a client cache, measured once a prototype runs.
8. Frame rate and view distance on the minimum machine, and whether players can host a world themselves (Section 3).
9. Protection against x-ray clients, and the largest world one server process can serve (Sections 4.9, 4.1).
10. Which geological features a tile stores. The first version is built; confirm before tiles are kept (step 18).
11. When the outer starter set opens, how many tiles are built before players arrive, and travel speeds on foot, horse and ship (Sections 4.1, 4.11).
12. Town spacing: 3 km from a starter town and 2 km between towns (Sections 4.1, 8.1).
13. Does fallow land recover fertility by itself, or only through lime and manure (Section 5)?

**Characters and time**

14. How large the heir's head start in the parent's skills is (Section 6.2).
15. Which actions count for the check-in (Section 6.7). Suggestion: buy, harvest, finish a conversation, finish a task.
16. Whether wish speed tiers (half, third, quarter) are right, how an adventure's value is set, and how long-lived characters fit the clock (Section 6.10).
17. Familiars: whether they die, what happens when the owner dies, and whether the jokes can be turned off (Section 6.11). Homages: who reviews each reference (Section 6.12).
18. How dangerous night is compared with day (Section 7.5).
19. Duress details: refund rules for a real-money balance, what a player gets back after their dynasty became NPCs, which events are urgent and which weekly, and payment handling (Sections 6.1, 13.8). The protection price comes from a market analysis.
20. What happens when several players apply for the same dynasty in receivership, and whether money is held in escrow (Section 6.1).
21. Whether other players and NPCs can rob or finish a downed character. Suggestion: outside PvP zones it is a crime, not a blocked action (Sections 6.1, 9.0).
22. The nomadic household: a dynasty with no fixed home (living in a ship, or a wagon with tents) still needs a household for children, food and safe logout, and today those assume a home base with fields and a bed. Perhaps the ship or wagon itself is the household unit; settling down means putting down a tent as at a camp. The project owner's refinement: a nomadic family travels with a wagon pulled by oxen (or horses; oxen suit this best). Settling is the same camp mechanic as Sections 8.17 and 8.18, only mobile: they put down the tent, and that camp becomes their house for as long as they stay. Then they can pack it up, move, and put the tent down again somewhere else, and that becomes home. On the road the player can ride the wagon and steer the animals personally, or hire a wagon master (teamster) as a hired hand who travels with the family and drives, which is the do-it-yourself-or-hire-it-out principle (`DESIGN_PRINCIPLES.md`, Section 2) applied to wagon travel. Travel orders to the teamster are a real conversation, not a menu: the player tells him where they want to go, both look at a map and the player points out the destination, and once he understands and the supplies are ready he agrees and drives. The language model voices the conversation, while the game owns the facts (destination, route, schedule), as in Sections 3, 8.8 and 8.9. Once everyone is in the wagon and the player says go, the teamster does all the driving while the family sits in the back and talks, or the player sits up front, as they like. He also makes the day's travel judgment himself: how far to go, and stopping to set up camp before nightfall so the family is not caught in the open after dark. Still to design: what the wagon stores, how logging out safely works on the road, whether a wagon camp gets the same two-guard protection as a camp, and how the animals are fed and cared for. Design later (`DESIGN_PRINCIPLES.md`, Section 3; Sections 6.1, 6.6, 8.17).

**Towns and claims**

23. The name "grand city" for the top stage is a placeholder. The top stage name "grand city" is a placeholder; alternatives are capital or great city.
24. The shape of the presence zone, how strong guards must be, what the manager can decide automatically, and whether a weekly player with no group member is treated fairly after 48 real hours away (Sections 8.14, 8.15).
25. What the town and the owner lose when ownership changes, and whether walls add anything (Section 8.14).
26. Price formula for server-owned towns, how competing applicants are handled, and what the good-faith judgment looks at (Section 8.16).
27. Stay-score numbers for NPCs leaving a declining town, decay stage names, collapse thresholds, administrator vote size, and what happens to records at deletion (Section 8.13). Whether a claimed ruin starts with the old spirit or a fresh low one.
28. Temple cost (Section 8.11); waits for the money scale.
29. Homestead details: size, growth stages (house, estate, keep or castle), whether it uses the camp slot, and its outpost budget (Section 8.17).
30. NPC role templates (weights and variance per role, including scavengers) as the roles are built (Section 8.2).
31. Bridges: maximum span and depth, kinds, and who maintains NPC dirt roads (Section 8.17). Ring layout: rules or planner preferences, and whether the owner can override (Section 8.17).
32. Marker hoarding: the one-camp-at-a-time rule limits it; still open is the cost or upkeep of a marker and when a reservation is released (Section 8.17).
33. Expansion and building prices wait for the money scale (below). Whether the first ten buildings are the right ten (Section 8.19).
34. Wizard tower cost, research, defence strength and limits; cost of sending word and the delay formula (Section 8.15).

**Law, threats and PvP**

35. Locks and security as soft barriers, how far justice and news spread, and whether NPCs can cross the ocean (Sections 9.1, 13.6).
36. Fixed lairs, roaming groups or both, and whether a ruined town can become a bandit stronghold (Section 12).
37. PvP: the cost of dying in a zone, how zones relate to war between towns, and which parts of the map get zones first (Section 9.0).
38. Danger tiers players see, and whether the curves need tuning once creatures exist (Section 4.13).

**Economy and production**

39. **Money scale.** Money has no anchor yet. Later: balance the value of time spent harvesting, fishing and building against prices, set starter numbers, and rebalance constantly (Section 13).
40. Player resident rights, number of tax levers, order forms versus conversation, one business structure for every workplace (Sections 8.5, 13.4).
41. Hands paid by share, wage or employer's choice (Section 5.2).
42. Blueprints built all at once or in stages; fire treatment as material or upgrade; wind and weather on fire; who fights fires; ventilation as a simple range effect (Sections 10.1, 10.2).
43. Whether admin buying splits its daily cap per resource, per seller or per player (Section 8.1).
44. Resource renewal rates, how a mine decays when abandoned (full cave-in, partial, or old shaft), support types and whether collapses hurt miners (Sections 5, 11.2).
45. Gambling and the real-money design (Section 13.8): to be revisited when that work starts. Steam and Workshop as a target.
46. Who hosts servers and pays for language model calls (Section 8.9).
47. How NPC rescue works without trivializing death, and the cost of NPC companions (Section 12.2).
48. Land-suitability layers in the bake for the town planner, and whether plans can run unattended (Section 8.4).
49. Factions and guilds between groups: none yet; friends groups, towns and parties exist (Section 6.13).

---

## 16. Candidate work, in dependency order

Nothing here is committed. It follows `GENERATOR_V2_PLAN.md`, ordered by what affects baked data first, since baked changes force rebakes.

1. Done: world settings, tables, world sketch, tile plan, and for one tile the height, erosion, water, climate, geology and sites (plan steps 2 to 12).
2. Done: the permanent parts of the tile file (`WORLD_FORMAT_SPEC.md` Section 4): the ID scheme, the geology list with tuff (step 12b), the resource pass design, the river plan.
3. Done (2026-10-15): the tile file writer and reader (step 13): the starter tile bakes to a 9.85 MB file in about 2.5 seconds of file work on top of the generator's 2 minutes.
4. Rivers across tile edges, overlap margins, wrap-seamless noise, and the final edge-matching pass (Section 4b of the spec).
5. Runtime terrain generator from the maps (step 14), then runtime flora (step 15).
6. Server streaming, the client cache and the layer for player changes (step 16), then the minimum machine test (step 17).
7. Build the inner starter tiles and their neighborhoods (step 18), then retire the old pipeline (step 19).
8. Game systems on top of that foundation: harvesting, building and blueprints, characters and aging, NPCs, towns, law and recognition, fire, then production, threats, trade and banking. A small first playable slice has to be chosen first.

Most gameplay systems in Sections 5 to 13 live in the server layer and can be added later without rebaking terrain.
