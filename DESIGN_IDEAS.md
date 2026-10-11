# Design Vision and Ideas

Record of the design brainstorming session of 2026-10-11. This is a planning document only. Nothing described here has been implemented, and no code was changed.

## How to read this document

Every item carries a status tag.

- **[Decided]** Stated or clearly agreed to by the project owner.
- **[Idea]** Raised by the project owner as a direction ("we could...", "maybe..."), not yet firmly settled.
- **[Proposed]** Suggested by Claude during brainstorming. It was accepted in passing or not objected to, but never explicitly confirmed.
- **[Open]** A question that has not been answered yet. Section 12 collects them.

When something is both a decision and a question, the decision is recorded in its section and the unresolved part appears in Section 12.

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
| Medieval Dynasty | Founding villages, villagers with jobs, seasons, marriage, children and heirs. |

**Core goals**

- **[Decided]** The client stays light enough for older computers to play comfortably.
- **[Decided]** Most of the workload happens on the developer's machines at bake time. The server carries some of the load.
- **[Decided]** The world can grow over time without breaking what already exists.
- **[Decided]** Players are encouraged to build ships and sail, because islands are separated by real ocean.

---

## 2. Terminology

- **Region:** one 1,024 m by 1,024 m storage file holding all 7 LODs. It is the natural unit to stream from server to client.
- **Island tile:** a block of 10 by 10 regions, 10,240 m (about 10.24 km) on a side. Each tile is baked on its own and addressed by a permanent integer coordinate.
- The project owner sometimes says "chunk". Depending on context that means a region or an island tile.
- **[Decided]** Sizes are multiples of 1,024 because voxel data aligns best that way.

---

## 3. Guiding principles

- **[Decided] Soft limits with real consequences.** The world rarely says "no." It lets the player try and then responds. Examples: depth heat instead of a hard floor, tool strength, soft law instead of permission locks, and offline risk instead of invulnerability.
- **[Proposed] Baked immutable base plus a server-owned living layer.** The baked world never changes. Everything players and NPCs change lives in a separate server-owned layer. This matches the existing code, where the base world is marked immutable.
- **[Proposed] Lazy resolution.** Store "this happened at time T" and work out the result when someone looks, instead of simulating constantly. Used for crop growth, plant regrowth, aging, NPC memory decay, ruin decay and offline events.
- **[Proposed] Data-driven tables.** Materials, tools, rocks, traits and plants each have a table of numbers that all systems read, so balance changes are edits to data and not code.
- **[Proposed] The game owns the facts; the language model only speaks.** Money, items, relationships and crimes are structured data. The model voices NPCs but cannot invent facts, and its output must pass game rules before changing anything.
- **[Proposed] Server authority with simulation level of detail.** Simulate in detail near players and coarsely elsewhere, like terrain LOD.

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
- **[Open]** Whether seasons are wanted at all. Medieval Dynasty suggests yes.

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

### 4.4 Natural structures

- **[Decided]** Caves, abandoned mineshafts, labyrinths and similar discoveries, as in Minecraft.
- **[Proposed]** Underground structures are baked as real voxels, since players can dig into them. They become destinations for NPC quests and bandit camps.
- **[Decided]** Towns are **not** baked. Players found towns (Section 8).

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

---

## 5. Harvesting, tools and farming

- **[Decided]** Everything is harvestable with strong enough tools: all trees, all plants (except basic grass), rocks and minerals.
- **[Proposed]** A shared rule: every harvestable thing and every rock type has a hardness, every tool has a power, and a tool works if power is at least hardness. The project already has excavation resistance values for rock types and a resource list that can seed this.
- **[Proposed]** Grass can be handled as small patches if needed, with harvested cells hidden by clients.
- **[Proposed]** Lazy regrowth: store when something was harvested and resolve regrowth when someone is near. Records for regrown plants disappear.
- **[Decided]** Farming comes later. Seeds and grain are found or bought, then planted, grown and harvested.
- **[Proposed]** Wild versions of crops exist in the right climates and drop seeds. Planted crops are server-owned objects with a planted-at time, and growth stage is computed on demand.
- **[Proposed]** Crops respond to climate and soil, so climate must be queryable at runtime.
- **[Open]** Prepared ground (tilling) as a terrain edit, or seeds on any suitable surface.
- **[Open]** Whether things regrow at different speeds and whether rocks and minerals ever return.
- **[Open]** Whether tool and item type changes what a harvest yields.
- **[Open]** Whether mining the terrain itself (tunnels and veins) is in the first version or only surface rocks. Digging and leveling land are wanted overall.

---

## 6. Characters, aging, death and heirs

- **[Decided]** Players age. They can woo a partner and have children.
- **[Decided]** A character who is killed with no way to recover, or who is too old or wounded to recover, dies. The player restarts as a new character.
- **[Decided]** If the player restarts as their child, the child inherits everything that remains. The child's first quest may be to find the fallen parent, or hire local adventurers or services to retrieve the parent's gear.
- **[Decided]** ARK-style unconsciousness before death. A downed character can be revived, carried or dragged to safety by party members.
- **[Decided]** Characters age **slower** while their player is offline, but they stay in the world and remain vulnerable. Their body can fall unconscious, be burned or be killed while offline. Friends can pick them up, put them on a wagon, or drag them to cover.
- **[Decided]** Spouses and children stay in the world while the player is away. Events such as bandit raids, dragons and sickness can affect them, which gives players a reason to return.
- **[Decided]** Co-op: friends can tend animals and harvest crops for an absent owner, with permission.
- **[Proposed]** Age is computed as online time at full speed plus offline time at a reduced rate.
- **[Proposed]** Downed window or recovery chance depends on age and condition.
- **[Proposed]** Ownership held at the **dynasty** (family line) level instead of the character level, so nothing needs transferring when a character dies.
- **[Proposed]** Logging out in a bed, inn or your own town makes a character **safer** (not invulnerable), while logging out in the wilderness leaves the body exposed. The project owner agreed and noted inns can be abandoned, attacked or burned, with occupants inside.
- **[Proposed]** A "while you were away" report on login, with events resolved by game rules and optionally narrated by the language model.
- **[Open]** Whether the game warns about the risk of a logout location.
- **[Open]** A grace period for accidental disconnects.
- **[Open]** What happens when a character dies with no heir.
- **[Open]** How permanent offline loss should be (can family members die, can buildings be destroyed).
- **[Open]** Who can raid whom: only NPC bandits, monsters and sickness, or other players as well.
- **[Open]** Whether dropped items expire, and whether items in hard-to-reach places last longer.
- **[Decided]** Because offline characters stay vulnerable, the downed timer keeps running while the player is offline.
- **[Open]** Whether other players and NPCs can rob or finish a downed character. The intended answer is that it is a crime handled by the legal system (Section 9), not a blocked action.

---

## 7. World time

Aging, marriage, children growing up, crop growth, regrowth, decay, taxes and seasons all depend on one world clock.

- **[Proposed]** One server world clock with a fixed ratio to real time.
- **[Open]** The ratio (for example, how many real days make a game year). It affects everything above, so it should be decided early.

---

## 8. NPCs and towns

### 8.1 Towns

- **[Decided]** The world starts with no towns. Players found them by placing a **town block** that they own. They can assign themselves as owner or leave governance to AI.
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
- **[Proposed]** Each memory stores a strength and timestamp. Decay is computed only when the NPC recalls it, and recall reinforces it. Strongest relevant memories plus traits form the context for a conversation.
- **[Proposed]** Language model calls are used for player-NPC conversation. NPC-to-NPC activity runs on rules.
- **[Proposed]** NPC population caps per island or region.

### 8.3 Displacement and migration

- **[Decided]** When a town falls, displaced NPCs migrate toward the nearest town, with some randomness (sometimes the second nearest).
- **[Decided]** On arrival they look for work they are good at, may take a new job, may build a house or inn if wealthy enough, or may become bandits or join a traveling circus or bandit group.
- **[Proposed]** Choices are weighted random, with traits shifting the weights.
- **[Proposed]** Travel is abstract when no player is near (departure time plus travel time), using wrap-aware distances.
- **[Open]** Whether NPCs can cross the ocean on their own. If not, islands are separate populations unless ships connect them.

---

## 9. Law and consequences

- **[Decided]** No hard permission locks. A player can physically take crops they do not own. If the owner gave permission nobody objects. If not, the player hopes nobody sees.
- **[Decided]** A victim can report a theft and the town starts an investigation.
- **[Decided]** If a player sells stolen goods to an NPC who suspects they are illegal, a warrant can be issued and the player is no longer safe in that town.
- **[Proposed]** The server records ownership on everything and logs events: who did what, to what, when, where, and who saw it. Items carry provenance (who they came from).
- **[Proposed]** NPC reactions depend on traits. A lawful NPC reports, a low-lawfulness NPC may buy and say nothing.
- **[Proposed]** Warrants belong to a town's jurisdiction and spread by rumor or messenger with delay.
- **[Proposed]** NPC conclusions come only from recorded events, never from what a player claims in chat.
- **[Proposed]** Event logs need a retention rule so old minor events are summarized or dropped.
- **[Proposed]** A third outline state for placement and actions: allowed but illegal or risky.
- **[Open]** Whether locks and security are soft barriers (skill versus lock strength) or absent.
- **[Open]** How far justice spreads (one town, or across the island through rumor).

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

## 11. Current code status

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
- Players, NPCs, towns, building, law, or any gameplay systems.

**Current values**

- World height: -4,000 m to +2,048 m, sea level 0.
- 7 LODs, 16-voxel data blocks, 1,024 m regions, 10 by 10 regions per tile.
- Rock types: sediment, shale, limestone, coal, granite. Resources: coal, iron, copper, tin, lead, zinc, nickel, silver, gold, salt, sulfur, clay, gypsum, graphite, gemstone, peat.
- Default server capacity: 32 clients.

**Compatibility warning.** The server rejects any world whose region files come from different generator versions. Once the generator gains islands, climate, soil or structures, tiles baked earlier will need rebaking. Until the generator's feature set settles, tiles baked now should be treated as test tiles.

---

## 12. Open questions

World and bake

1. Is seasonal change wanted, and should its strength grow with distance from the equator?
2. Should the world rectangle stay centered on the origin so the north-south wrap seam joins matching climates?
3. How much variety in island size is wanted, from tiny rocks to ARK-scale?
4. Is the world bottom at -4,000 m confirmed, with the lethal depth near -3,000 m kept adjustable?
5. Should the bottom kilometer be detailed for possible future content or baked simply?
6. How far should altitude effects reach, given the 2,048 m ceiling?
7. What limits diving, and can the deep ocean floor be dug?
8. Is mining the terrain itself in the first version?

Time and persistence

9. What is the real-time to game-time ratio?
10. Do dropped items expire, and do hard-to-reach ones last longer?
11. What happens when a character dies with no heir?
12. Is there a grace period for accidental disconnects, and does the game warn about risky logout spots?
13. How permanent is offline loss for family and buildings?

Social and law

14. Who can raid whom: NPCs only, or other players too?
15. Are locks and security soft barriers?
16. How far does justice spread?
17. Can NPCs cross the ocean themselves?
18. Do ruins last forever or decay?

Building and platform

19. Is Steam the release target, and therefore is the Workshop an option?
20. Are blueprints built all at once or in stages?
21. Is fire treatment a crafted material or an upgrade to placed pieces?
22. Do weather and wind affect fire, and who fights fires?
23. Does ventilation stay a simple range effect?

Language model

24. Who hosts the servers and pays for model calls: the developer, players hosting their own, or both? This decides which model options are practical.

---

## 13. Candidate work, in dependency order

Nothing here is committed. It is a suggested ordering based on what affects baked data first, since baked changes force rebakes.

1. Settle the open questions that change baked data: climate scale, seasons, world bottom, and what the bake stores about soil and flora.
2. Island properties panel, irregular coasts, small islets and open-ocean tiles.
3. Climate layer and soil or surface materials.
4. Flora placement lists written at bake time.
5. Natural structures: caves, mineshafts, labyrinths, ruins. Slate and any new rock types.
6. A planner that takes a target rectangle and bakes only the missing tiles.
7. Server-to-client region streaming and a layer for player changes.
8. Runtime systems on top of that foundation: harvesting, building and blueprints, characters and aging, NPCs, law, fire, towns.

Growing the generator first keeps the foundation solid. Most gameplay systems in Sections 5 to 10 live in the server layer and can be added later without rebaking terrain.
