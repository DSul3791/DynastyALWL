# WP-MAP — character-discovered charcoal Map (separate thread)

**Goal:** the approved foundation in PLAYER_CARTOGRAPHY_MAP_DESIGN.md §1, which is authoritative. A per-character, server-owned discovery record. The Journal Map page draws only discovered ground as a charcoal sketch. Mapping skill makes the sketch more accurate. Skill grows through genuine exploration. Revisiting a region at higher skill redraws that region. Never reveal unexplored geography. Never send undiscovered terrain to the client. Read [COMMON.md](COMMON.md) first.

**Not in scope (R-1 condition 4):** Map Scroll recipes, knowledge transfer, sale and inheritance. Leave a clean seam for them. Do not invent them. XP numbers, thresholds and accuracy curves may be provisional engineering constants, tagged and logged (COMMON.md §3), tuned to the anti-exploit rules in §2 of the map design. There is no XP for standing still, opening the map, or redrawing unchanged areas.

**Architecture (design §3, recommended):**
- A sparse per-character discovery cell record: observed features, skill at observation, timestamp. Saved with the character, and safe against world expansion and rebakes.
- A new server module, e.g. `src/stream/server_map.gd`. Keep server_items.gd changes to a minimal hook. Ask the lead.
- Event-based updates on movement thresholds, not per-frame scans.
- A client renderer that caches a charcoal-style 2D projection of discovered cells and redraws only dirty parts.
- Mapping skill uses the existing skill system if there is one. Investigate first.

**Dependencies:**
- WP-GUIDE-UI provides the Journal shell and the Map page slot. You need a protocol bump after theirs: ask the lead for the next number.
- You can start the server record, skill and renderer in parallel. Integrate into the page when the shell is in `dev`.

**Tests:**
- A new character sees a blank charcoal page.
- Walking records an area that persists across quit/rejoin and is player-specific.
- Skill rises only on meaningful events.
- A revisit improves accuracy. A skill increase alone reveals nothing new.
- Tile boundaries stitch correctly.
- No world leak in the network payload.
- Refresh cost is benchmarked.

Visual quality of the sketch is NEEDS PLAYER VERIFICATION (headless lane has no pictures). Report each PR to the lead.
