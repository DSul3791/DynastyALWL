# Design Vision and Ideas

Record of the design brainstorming sessions of 2026-10-11 and 2026-10-12. This is a planning document only. Nothing described here has been implemented, and no code was changed.

**Revision history**

- **Version 1 (2026-10-11):** vision, world generation and bake, harvesting and farming, characters and heirs, NPCs and towns, soft law, building and fire.
- **Version 2 (2026-10-12):** added Satisfactory as an inspiration; production and logistics; road threats and pacing; town finances, markets, warehouses, trade routes, businesses, banking, letters of credit and forgery; crime memory, delayed discovery and disguises; inheritance of money and debt; the shared principles those systems rely on. Open questions and the work ordering were rewritten.

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
| Medieval Dynasty | Founding villages, villagers with jobs, seasons, marriage, children and heirs. |
| Satisfactory | Building components and tools from materials to help mine and climb. Railways, machinery and automated movement of materials out of mines and on to town. |

**Core goals**

- **[Decided]** The client stays light enough for older computers to play comfortably.
- **[Decided]** Most of the workload happens on the developer's machines at bake time. The server carries some of the load.
- **[Decided]** The world can grow over time without breaking what already exists.
- **[Decided]** Players are encouraged to build ships and sail, because islands are separated by real ocean.
- **[Decided]** The world should feel alive: carts, wagons and NPCs moving through it.

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

### 4.4 Natural structures and lair sites

- **[Decided]** Caves, abandoned mineshafts, labyrinths and similar discoveries, as in Minecraft.
- **[Proposed]** Underground structures are baked as real voxels, since players can dig into and through them. They become destinations for NPC quests and bandit camps.
- **[Decided]** Towns are **not** baked. Players found towns (Section 8).
- **[Decided]** Eventually a threats system will pinpoint areas that make natural bandit camp places. Premade goblin camps can also be dropped in like a blueprint, creating a small cave system filled with goblins (Section 12).
- **[Proposed]** At bake time the generator scores natural hiding spots (caves, ruins, ridgelines, forest edges: defensible and out of sight) and places **dormant lair sites**: empty caves and camps that nobody lives in yet. At runtime the server only changes a site's state ("site 14 is held by a goblin horde"). That needs no terrain editing and no client download.

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

## 6. Characters, aging, death, heirs and personal finance

### 6.1 Aging and death

- **[Decided]** Players age. They can woo a partner and have children.
- **[Decided]** A character who is killed with no way to recover, or who is too old or wounded to recover, dies. The player restarts as a new character.
- **[Decided]** If the player restarts as their child, the child inherits everything that remains. The child's first quest may be to find the fallen parent, or hire local adventurers or services to retrieve the parent's gear.
- **[Decided]** ARK-style unconsciousness before death. A downed character can be revived, carried or dragged to safety by party members.
- **[Decided]** Characters age **slower** while their player is offline, but they stay in the world and remain vulnerable. Their body can fall unconscious, be burned or be killed while offline. Friends can pick them up, put them on a wagon, or drag them to cover.
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
- **[Open]** Whether an heir gets a small head start in the skills the parent practiced, consistent with NPC children growing up with skills similar to their parents.

### 6.3 Personal finances

- **[Decided]** Each individual has a finances tab showing what they own, what they owe, how much they have banked and how much they carry on them.
- **[Decided]** Money in the bank is reached at the bank in person. A character away from their own town can instead try to write a letter of credit, based on their reputation (Section 13.5).
- **[Proposed]** The tab also shows a calendar of upcoming payments and a forecast ("your account covers the next three payments").
- **[Proposed]** Carried cash is exposed: it can drop on death or be stolen like any item. Banked money is safe but needs a visit to a bank.

### 6.4 Obligations

- **[Proposed]** Loans, tax bills, wages and tolls are all one kind of record: who owes whom, how much, and when it is next due.
- **[Proposed]** At each periodic settlement the server pays what is due from the account, whether or not the player is online. A payment that cannot be made is a missed payment, with a reputation hit and eventually penalties or seizure of collateral.
- **[Proposed]** Missed payments while away appear in the "while you were away" report.

---

## 7. World time

Aging, marriage, children growing up, crop growth, regrowth, decay, taxes, loan payments, work hours, patrol and trade schedules, memory fading and seasons all depend on one world clock.

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
- **[Proposed]** Each memory stores a strength, an importance and a timestamp. Decay is computed only when the NPC recalls it, and recall reinforces it. Importance slows fading. Strongest relevant memories plus traits form the context for a conversation.
- **[Proposed]** Language model calls are used for player-NPC conversation. NPC-to-NPC activity runs on rules.
- **[Proposed]** NPC population caps per island or region.
- **[Idea]** NPC merchants eventually appear on their own. They need somewhere to live and somewhere to work, so they only appear where a profitable opportunity (a price gap and a connecting road) coincides with available housing and workspace.

### 8.3 Displacement and migration

- **[Decided]** When a town falls, displaced NPCs migrate toward the nearest town, with some randomness (sometimes the second nearest).
- **[Decided]** On arrival they look for work they are good at, may take a new job, may build a house or inn if wealthy enough, or may become bandits or join a traveling circus or bandit group.
- **[Proposed]** Choices are weighted random, with traits shifting the weights.
- **[Proposed]** Travel is abstract when no player is near (departure time plus travel time), using wrap-aware distances.
- **[Open]** Whether NPCs can cross the ocean on their own. If not, islands are separate populations unless ships connect them.

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
- **[Decided]** The merchant is responsible for the wagon and its contents. If it is lost they lose reputation, the wholesale value of the goods has to be paid, and they lose their own wagon and potentially the driver.
- **[Decided]** The warehouse has to keep enough money to cover wagons, guards or escorts, and problems. Losses are paid from the warehouse's own funds.
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

**Not checked**

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

1. Is seasonal change wanted, and should its strength grow with distance from the equator?
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

11. What is the real-time to game-time ratio?
12. Do dropped items expire, and do hard-to-reach ones last longer?
13. What happens when a character dies with no heir?
14. Is there a grace period for accidental disconnects, and does the game warn about risky logout spots?
15. How permanent is offline loss for family and buildings?
16. Does an heir get a head start in the parent's skills?

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

---

## 16. Candidate work, in dependency order

Nothing here is committed. It is a suggested ordering based on what affects baked data first, since baked changes force rebakes.

1. Settle the open questions that change baked data: climate scale, seasons, world bottom, what the bake stores about soil and flora, whether deposits get stable IDs, and how dormant lair sites are scored and placed.
2. Island properties panel, irregular coasts, small islets and open-ocean tiles.
3. Climate layer and soil or surface materials.
4. Flora placement lists written at bake time.
5. Natural structures: caves, mineshafts, labyrinths, ruins, dormant lair sites. Slate and any new rock types.
6. A planner that takes a target rectangle and bakes only the missing tiles.
7. Server-to-client region streaming and a layer for player changes.
8. Runtime systems on top of that foundation: harvesting, building and blueprints, characters and aging, NPCs, law and recognition, fire, towns, then production, threats, trade and banking.

Growing the generator first keeps the foundation solid. Most gameplay systems in Sections 5 to 13 live in the server layer and can be added later without rebaking terrain. They are also numerous enough that a small first playable slice will need to be chosen before building them.
