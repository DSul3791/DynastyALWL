# Field journal and companion records (design)

Steve, 7 Nov 2026, for Phase 2 of the guiding document (`docs/design/GUIDING_DOCUMENT.md`, #544: section 9.1, proposal G-18; section 8.2, proposal G-09; section 14). This is a design only. **No code until Dave reacts to G-18.**

## 1. What a character knows about a creature

The journal records knowledge per character and per species. Each species climbs a ladder of five rungs. The whole ladder can be climbed without killing (G-18).

| rung | how it is reached (all server side) | what it shows |
|---|---|---|
| 1 Heard of | An NPC talks about it, a rumour on the news rail (G-19) names it, or the character reads a journal that has it | name, a rough region |
| 2 Sighted | The species is within sight and in front of the player for 2 s or more (within the animal send radius, `send_radius_m`, plus a line-of-sight test and the view cone), or the player hears its call within reach | picture, size, the biome it was seen in |
| 3 Observed | The player watches one animal at no more than its alert distance, for 20 s spread over at least two of its states (graze, rest, fish, forage), while it is **not** fleeing. This uses the animal's state machine and `alert_m` | habits, active hours (`active`), diet, temperament |
| 4 Tracked | The player inspects 3 of its signs (`data/animals/animal_sign.json`, two kinds at least) and then sights the animal within 300 m of the last one, within one game day | range, den or burrow, the season it moves |
| 5 Studied | Three of these, each from a different encounter: a harvest without a kill (milk, wool, eggs, honey), a carcass examined, a tamed one handled (G-09), or a library lesson | weak points, drops, safe approach, lore |

Each rung needs the one below it. A kill can count for Studied (as the carcass) but it is never required. The thresholds are data in `data/animals/journal.json`, never code per species.

**Detection.** The server already knows each player's position and the animals' positions, states and alert timers (`server_animals.gd`: `rows_near`, the `alert` timer, the state machine). The journal hooks into the existing per-tick update at the points where an animal and a player meet. It adds no new scan, so the cost stays at "per player, per nearby animal", as today. Each event is a small call, `journal.note(key, species, event)`, and it only ever adds to the state.

## 2. Storage

- One record per character, kept on the server in `journal.json` in the store folder. It is keyed by the character key, as `vitals.json` is:

  `{species_id: {rung, counters, first_s, last_s, where}}`

  Here `where` holds at most the last 5 sightings, as world x and z.
- Species are named by their stable `id` string from `animals.json`, never by the per-run animal number. Animals are not saved and are made fresh every run, so nothing in the journal points at an individual wild animal.
- Each record carries a version field. A saved rung is never taken away by later data changes; new rows simply start at zero.
- The client gets the rungs only. They are sent when they change and when the player joins, the same as warmth.

## 3. Heirs (two layers; adopted 7 Nov via the coordinator, flagged for Dave with G-18)

DESIGN_IDEAS 6.15 is Dave's own text, so it wins over D-04 as first written. D-04 now reads: **family knowledge is inherited by the heir; journal pages are copyable items that are not inherited by themselves.**

- **Family knowledge.** The rungs belong to the dynasty's knowledge, and the heir gets them whole. This is the dynasty's long game.
- **Journal pages.** A written page is an item copied from that knowledge. It can be traded, lost or looted, and it follows the remains rules (DESIGN_IDEAS 6.1). Reading a page raises the reader's own rungs up to the page's rungs.

The heir and new-character flow is not built yet (`send_final_death` has nothing set). The journal therefore exposes `inherit(from_key, to_key)`, and the heir flow calls it when that flow lands.

## 4. Rebakes

Nothing in the journal uses tile positions as identity. The `where` points are just pictures on the map, and an old point that ends up in water after a rebake is still a fact about the past.

Species ids are stable across bakes. A species removed from `animals.json` keeps its record but hides it. So a world rebake or a tile rebake (R6) leaves every journal valid. The same rule as #541 applies: never store a record id or a cave id across rebakes.

## 5. Companions (for G-09 later; designed now so the storage fits)

A tamed animal becomes a named individual that persists. It is saved in `companions.json` in the store folder:

`{id, species, name, born_s, level, traits (temperament, tamable value), bond 0..1, owner_key, history: [{s, event, key}]}`

- The id is a server serial that is never reused.
- The bond rises with days of presence and falls when the owner neglects it. These are the rates in G-09's ladder (`trust_per_day`).
- The ownership history records events: tamed, given, sold, inherited, lost and died.
- An heir inherits companions with the dynasty: an `inherit` event, and the bond drops to a share set in data.
- The live animal is spawned from the record near its owner or its stable when the owner is in range. The wild spawner never makes it.
- This reuses the young-follow-mother code for following.

## 6. Dependencies

1. **G-18 accepted by Dave**, including the two-layer heir rule (section 3).
2. **Sign kinds per species** in `animal_sign.json` (MikeW, Phase 2), for Tracked.
3. **The journal page look** (Kathleen) and the client page. The client needs only the rungs.
4. **The heir flow** (not built), which calls `inherit`. Until it exists, the journal is per character.
5. **G-19 rumours** (news rail), for Heard of. Until they exist, Heard of comes from NPC dialogue lines and from reading journals.
6. **G-09 taming design**, for companions (Phase 4). The storage above is ready for it.
7. Nothing from the water rebuild is needed, except that dens use the Stage E readers (#543, #545).
