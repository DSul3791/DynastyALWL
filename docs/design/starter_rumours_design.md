# Ten starter-ring rumours on the news rail (design)

Steve, 7 Nov 2026, for proposal G-19 (`docs/design/GUIDING_DOCUMENT.md` section 9.2, #544). This is a design only. **No code until Dave reacts to G-19.**

The rule comes from DESIGN_IDEAS 13.6 and principle 3: **the game owns the facts, and the language model only speaks them.** A rumour is a fact the world already holds, with a place and a time it became true. The game stores it, checks it, and passes it to an NPC's line as one context fact (`data/npcs/ai_rules.json` allows up to 8 facts a line). The model words it. If the AI provider is down, an authored fallback line says it instead.

## 1. The ten rumours (ring 1: the starter town and near it, levels 1 to 5)

| # | rumour | fact it reads (already in the game) | teller | journal |
|---|---|---|---|---|
| R1 | "Something steals at night up by the hill caves." | `goblin_den_mouths` (#543) nearest the town; goblins `active` at night | Edda (guard) | goblin: Heard of, with a region |
| R2 | "A bear fishes the river bend past the ford." | a bear den (`server_animals` den; near fresh water, #545) | Hob (shopkeeper) | bear: Heard of |
| R3 | "Deer graze the east meadow at first light." | deer habitat biome and `active` hours | Hob | deer: Heard of |
| R4 | "A fox has a den by the old wall; mind your hens." | fox `burrow` position | Edda | fox: Heard of |
| R5 | "Boar root under the oaks. Don't corner one." | boar habitat (forest) and temperament (`defensive`) | Edda | boar: Heard of, plus a safe-approach hint |
| R6 | "Rabbits by the hundred on the south slope." | rabbit burrows and habitat | Hob | rabbit: Heard of |
| R7 | "There's a cave where a spring comes out of the hill. The pool is ice cold." | `spring_mouths` nearest the town; cave pool cold (BUG-008) | Hob | (place) the cave on the map as a rumour |
| R8 | "Folk found bones in a cave to the north. Not all of them animal." | `cave_bones` of kind 1 (human) in the nearest cave | Edda | (place) |
| R9 | "Out past the far hills the beasts are bigger and meaner." | the level gradient (#485: levels change strength, never placement) | Edda | none (it teaches the ring) |
| R10 | "Best fishing is where the brook meets the river." | the nearest confluence of the river cells to the town (at R6, from the record's reaches) | Hob | (place) |

These need no new creature or place. R2 and R10 use the Stage E readers. R9 states a rule, not a spot.

## 2. How a rumour is made, kept and told

- **Made.** At server start, and once each game day, `server_rumours.gd` builds each kind from its fact source:

  `{kind, subject (species id or site kind), at (world x, z), region (a bearing and distance band from the town, such as "north, past the ford"), true_since_s, teller}`

  It writes no positions into dialogue data.
- **Checked when told.** Just before an NPC says a rumour, the server checks the fact again: the den still holds goblins, and the bear still lives. A stale rumour is dropped, never told. The game never lies by accident. Lying on purpose (DESIGN_IDEAS 13.6, editors who are biased or mistaken) comes later, as a flag on the record.
- **Told.** The dialogue server adds one rumour fact to the line's context: `"rumour: goblins steal at night; place: hill caves, north-east of town"`. The fallback is a static line per kind in `data/npcs/rumours.json`, with `{region}` filled in. One rumour per conversation. The same player never hears the same rumour twice from the same NPC.
- **Stored.** `rumours.json` in the store folder holds the current rumours, plus each player key's heard list by **kind + subject**, never by position. Hearing one gives that species the journal rung **Heard of** (#547) and a rough region on the map.
- **Rebakes.** Positions are rebuilt from the world at each start, so a rebake moves the rumour along with the den. A heard list keyed by kind and subject stays valid.

## 3. Dependencies

1. **G-19 accepted by Dave.**
2. Two NPCs exist today: Hob and Edda. A hermit and a sailor come later (G-19 names them). Until then the rumours are split between Hob and Edda, as in the table.
3. **Journal state (#547).** Without it, a rumour is just a line.
4. **Stage E readers:** #543 (dens) and #545 (fresh water). R10 waits for R6's reaches. Until then it falls back to the 8 m river cells.
5. **No new art or models.** The map marker for a rumoured place uses the existing map, plus a faint ring (Kathleen, later).
