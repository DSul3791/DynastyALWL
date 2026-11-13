# Dynasty — Exploratory Cartography and the Journal Map

**Status:** Creator-directed design, 13 November 2026. **Not implemented or gameplay-verified.** This is an explicit refinement of the existing J/G/M Journal plan and supersedes its earlier assumption that the Map page can only be a "Coming Later" placeholder. Exact formulas, scroll recipes and transfer rules are **proposed engineering details, not approved gameplay facts**.

## 1. Creator decisions — authoritative

1. **There is no fully known world map at the start.** A character discovers and maps the world while travelling and exploring. Never pre-reveal the generated world or claim this feature exists in today's runtime.
2. The Journal's **Map** page displays the character's mapping knowledge as a **charcoal drawing/sketch**, not an omniscient satellite map, technical GIS display or an automatically accurate world overview.
3. **Mapping skill directly affects accuracy.** Inexperienced characters produce a rougher, less precise depiction of discovered terrain; the drawn representation improves with skill. Do not confuse a better map with having explored new places.
4. **Mapping skill grows by exploration and by drawing map scrolls.** Scrolls can eventually be shared with other characters or sold. The scroll-writing action is real meaningful cartography work, not an arbitrary UI button that immediately grants every map feature.
5. **Revisiting areas improves the character's existing map accuracy at their improved skill level.** Previously visited areas are not instantly globally redrawn just because a skill value increased; new observation/retracing is meaningful.
6. **Clean/simple UI**: keep one Journal window (J Index, G Goals, M Map) matching existing Inventory/Crafting look, with the charcoal-styled map artwork as the Map page content. Do not add a second map screen, cluttered minimap, mandatory tooltip series, persistent coordinate/XP overlays, intricate drawing minigame, or an intrusive separate tool panel without the creator's approval.

## 2. Proposed minimum practical experience (engineering default; verify with creator if it changes gameplay)

- Opening Map for a fresh character shows an **unmapped/blank charcoal-page state**, not a complete terrain atlas. The HUD Goals widget stays unchanged and separate.
- Exploration leaves a persistent, player-specific trail of observed map regions. Exploring new ground exposes only what the character plausibly surveyed. Unvisited parts stay blank/unmapped.
- The depiction is a simplified and somewhat imprecise charcoal-style sketch of landscape and navigable features. Render from **actually observed/discovered world positions**, never transmit all world terrain to the client disguised by a translucent overlay. Skill can control simplification, landmark detail, edge placement uncertainty and line clarity without hiding crucial controls or generating impossible-to-navigate random fake landmarks.
- On crossing an already mapped region later, update/re-sample that region **using the character's current mapping skill**. Adjacent regions should transition gracefully; no artificial giant seam or permanent false map data.
- Discover new regions and draw usable Map Scrolls to earn mapping experience. Award skill progression on meaningful exploration/drawing events; prevent XP exploits from standing still, opening/closing the map, continuously redrawing the same unchanged area or spamming worthless scrolls. **Do not invent XP numbers, skill caps, unlock thresholds, map distortion percentages or blank-map pricing here.**
- Drawing a Map Scroll may produce a tradeable artifact representing the cartographic information known at creation. **Whether scrolls transfer knowledge into a recipient's map, how partial knowledge blends, scroll recipes/tools, item costs, trade value, map-scale/region selection, and any inheritance rules are still deliberately unresolved.** A scroll should not reveal knowledge the author never possessed.
- Existing independently proposed **Field Journal animal knowledge** in `docs/design/field_journal_design.md` is a separate not-yet-approved wildlife feature; reuse one Journal window but do not conflate creature journal rungs with cartography skill or silently inherit the latter.

## 3. Practical Godot architecture (recommendation, not preauthorization)

- **Server-owned per-character discovery record**, in sparse area/chunk/tile cells rather than a massive full-world screenshot. Record what was observed, when/at what effective mapping skill, and enough observed feature summaries to reproduce or refine the sketch on revisit. Treat terrain expansion, rebakes, save upgrades, deleted tiles, multiplayer and rejoining deterministically.
- Keep exploration/skill events independent of the UI; opening the Journal simply renders state already recorded. Cache a charcoal-styled **2D map projection** of only discovered areas, redraw dirty portions on meaningful movement/skill/observation changes, use distance/chunk thresholds rather than per-frame scans. Efficient sparse fog-of-knowledge and chunk masks are well established in Godot practice; benchmark rather than assuming a particular rendering technique is free.
- The player should be able to navigate the map without a cluttered interface. Reuse the existing Journal page chrome and standard page controls, with a drawing surface and only essential labels/zoom/scroll interactions if needed.
- Keep saved discovered area and improved local accuracy separate: `discovered` does not mean `precisely mapped`, and an increase in skill alone must not reveal distant undiscovered areas. Character-permission and sharing behavior should be implemented once map scroll sharing is explicitly designed.
- Map scrolls are physical content with stable identifiers and item ownership/persistence when authorized. Do not make them simply a client bitmap of private data without a server-approved transfer contract.

## 4. Testing and release gates

1. New character: Map has no revealed world geometry and no false landmarks; J/G/M navigation and the separate two-goal HUD are unchanged.
2. Walk through an unmapped area: the sketch gradually records the area, persists across quit/rejoin, and remains player-specific.
3. Increase mapping skill through genuine exploration/drawing; compare rough vs more accurate results. Previously visited areas improve on **revisiting**, not instant retroactive omniscience.
4. Explore, revisit, travel over tile boundaries and after world expansion/rebakes: no missing records, world leak, bad stitching or disproportionate map refresh cost.
5. Map Scroll production/share/sell tests are a **separate later milestone** until recipe, item identity, skill impact, copying/recipient effects and economy are expressly approved.
6. Do not mark the Map implemented or change `main` based solely on this design.

## 5. Community/technical context

One Godot community example describes a clean separation among persistent minimap data, a stateless renderer and game event manager, plus per-chunk revealed visibility masks; other community implementations use tile fog or sparse recorded paths. They are **implementation references only**, not authority to turn Dynasty's hand-drawn skill-based Journal into a standard exact minimap.

- https://www.reddit.com/r/godot/comments/1t3f87z/minimap_with_fog_of_war_how_it_works/
- https://www.reddit.com/r/godot/comments/121ieb6
- https://www.reddit.com/r/godot/comments/1iokiur

**Non-goals:** omniscient atlas, automatic accurate map without travel, invented GPS-like UI, terrain rebake changes, extra player permission dialogs, map skill balance decisions without measurement, or a separate map window.
