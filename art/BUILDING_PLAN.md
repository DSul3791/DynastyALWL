# Building plan: pieces, snapping and materials
Kathleen_ArtisticDirector, 2026-10-22. Art and sound side only. Piece ids, costs and snap data stay with Sal (`structures.json`, `recipes.json`). Status: PROPOSED, questions at the end.

## 1. What we have today (build 652, Sal)
- One cell grid: **2 m** (`snap_m` 2.0). Foundation 4 x 4 m, 0.3 m thick, with anchors for 8 walls (two 2 m walls per edge), 4 floor cells, 5 roof spots.
- Pieces: foundation, wall, doorway (shut and open), window wall, floor, roof, timber prop, timber set.
- Costs now: wall and floor 4 lumber + 1 cordage; roof 5 lumber + 2 cordage + 2 sticks; doorway 3 lumber + 1 cordage; foundation 8 stone + 2 clay. All at a workbench level 1.
- Look today: `piece_look.gd` makes board and stone textures in code (128 px, no files). Door sounds, place sounds and the foundation thump exist.

## 2. What the three games do (short)
- **RuneScape: Dragonwilds:** build mode with a ghost piece. Pieces snap on a fixed grid, tiers go wood, stone and later better. Easy to learn, readable at a glance. Sources: [Mobalytics guide](https://mobalytics.gg/gamebase/guides/runescape-dragonwilds-building-guide), [wiki: Construction](https://dragonwilds.runescape.wiki/w/Construction).
- **Ark:** foundation first, then walls, doorways, ceilings on a grid. Tiers thatch, wood, stone, metal. Stability from foundations and pillars. Known pain: free-placing pieces that do not line up, and ceiling/foundation spam. [Ark wiki: Building](https://ark.wiki.gg/wiki/Building).
- **Atlas:** same family as Ark, with forts. Thatch, wood, stone tiers and the same piece set. [Atlas structures](https://atlas.wiki.fextralife.com/Structures).
- Note: I have only the search listings, not full page text, so the points above are from those and general knowledge. Dave, if a DragonWilds detail matters (for example its stairs), name it and I will check.

## 3. Recommended snap system
Take what works from all three, keep it dead simple (Dave: no micromanagement, ghost is green or red).
1. **One 2 m grid for everything.** Wall 2 m wide x 2.4 m tall. Floor cell 2 x 2 m. Foundation = 2 x 2 cells (what Sal has). Everything snaps to cell edges, no free placing.
2. **Foundation first, anchors do the rest.** Walls, floors and roofs only go on a foundation or on another piece of the same house. No floating. (Matches Sal's anchors.)
3. **Ghost shows green or red, and the snap edge glows.** Dragonwilds style. Press R to rotate in 90 degree steps.
4. **Wall slot takes a variant.** Plain wall, doorway, window wall and later arch/gate all use the same 2 m slot, so a wall can be swapped without rebuilding. Door opens with E (exists).
5. **Floors double as ceilings** for the storey above (one piece, textured both sides). Roof pieces are sloped halves that meet at a ridge.
6. **Stairs and ramps** use the same 2 x 2 cell and climb 2.4 m in one cell (a straight stair). A ladder is a cheap tier-1 alternative.
7. **Ground rule:** foundation top is 0.3 m, with a stone course below that follows the slope (a skirt that goes down into the ground so there is no gap on hills). This one is art plus Steve/Sal.
8. **Stability** (Ark style) is left for later. Not tier 1.

## 4. What a board, a stone block and a brick look like
Standard reusable looks. All real-sized so a designer can read size from the picture. Colours stay natural (Dave: materials stay natural). Textures stay generated in code, no art files.
- **Board (lumber):** 20 cm wide x 2 cm thick x any length, rough sawn, visible grain along the length, darker nail-less seams. Colour comes from the tree species (pine pale yellow, oak mid brown). Wall = vertical boards, floor = horizontal, roof = overlapping boards.
- **Beam:** 15 x 15 cm squared, used for corners, posts and roof ribs. Same species colour, darker.
- **Stone block:** 40 x 20 x 20 cm, rough-cut face, uneven joints, grey from the local stone (limestone paler, granite speckled, slate dark blue-grey). Laid in staggered courses, thin pale mortar line (clay-brown at tier 1, lime-white later).
- **Brick:** 22 x 10 x 7 cm, fired clay, red-brown with slight variation per brick, light grey mortar joints 1 cm. Used for chimneys, forges and the nicer house walls.
- **Thatch:** bundles of straw/reed in rows, golden-grey, mossy over time, thick 30 cm roof edge.
- **Mud/wattle (daub):** woven sticks plastered with clay, tan with sticks showing at the edges. Optional cheapest wall.
- **Logs:** whole logs stacked with notched corners, bark on, for the first rustic hut and the fort palisade.
Each gets one shared tileable texture and one flat colour fallback for far distance.

## 5. Piece list (art set)
Tier numbers: **T1** needed to start playing, **T2** soon after, **T3** later.

| Piece | Tier | Notes |
|---|---|---|
| Foundation (stone skirt) | T1 | exists |
| Wall, plain | T1 | exists |
| Doorway + door (open/shut) | T1 | exists |
| Window wall | T1 | exists, add a shutter later |
| Floor | T1 | exists |
| Roof (slope) | T1 | exists; ridge and corner roof pieces are T2 |
| Timber prop (bracing) | T1 | exists, mine tunnels |
| Stairs (straight, 2 m cell) | T2 | new |
| Ladder | T1 | cheap, easy for Sal; gets people upstairs on day one |
| Half wall / fence | T2 | |
| Gate (double door) | T2 | for yards and forts |
| Chimney / hearth wall | T2 | brick |
| Thatch roof variant | T1 | cheapest roof, stays tier 1 skin |
| Shutters, bed/table/shelf furniture | T3 | furniture is a separate plan |
| Fort: palisade (log wall), gatehouse, watchtower, battlement wall | T3 | stone variant of wall plus walkway |
| Pillar/column, arch | T3 | |
| Dock/pier | T3 | Sonny's water, later |

## 6. Materials list, prioritised
**Tier 1 (start playing, all have items today or soon):**
1. Stone (loose) and clay for the foundation. In game.
2. Lumber (sawn boards, via saw mill). In game as placeholder.
3. Cordage (joins everything). In game.
4. Sticks (roof ribs, props). In game.
5. Logs for the rustic hut and palisade. In game.
6. Thatch bundles (straw/reed) for the cheap roof. Not in items yet: Sal to add (item "thatch").
**Tier 2:**
7. Beams (squared timber). In game per species.
8. Wooden pins/nails/hinges (the design says pins first, nails from the smith).
9. Cut stone block (stonemason). New item.
10. Brick (kiln, from clay). Uses fireclay as the design notes. New item.
11. Mortar: clay mortar first, lime mortar later. New item.
**Tier 3:** roof tile or slate, glass, iron fittings, ornamental stone.

## 7. Plan for art and sound (what I do, in order)
1. Lock the board / beam / stone block / brick / thatch looks in `piece_look.gd` (generated textures, species-colour aware where cheap). RUNTIME change.
2. Thatch roof skin and log-hut skin for the same roof and wall slots (needs a `material` field per piece from Sal, see questions).
3. Stairs and ladder model once Sal has the ids.
4. Sounds: place and break per material (board, stone, brick, thatch), door and gate variants, footsteps on wood floor and stone floor (class sounds exist for dirt, grass, sand; wood and stone floor are new).
5. Fort pieces after the above.
Nothing is bulk generated until this plan is approved.

## 8. Open questions (recommendation first)
1. **Piece tiers by skin, not by new ids?** Recommend: one piece id per slot plus a `material` (thatch, wood, stone, brick) so upgrading a wall changes its look, not its place. Sal owns this.
2. **Grid size 2 m, wall 2.4 m high?** Recommend yes (matches Sal's anchors, a person is 1.8 m).
3. **Ladder at tier 1 before stairs?** Recommend yes, stairs T2.
4. **Do boards take the tree species colour?** Recommend yes, free from the item id.
5. **Stone block size 40 x 20 x 20 cm and brick 22 x 10 x 7 cm?** Recommend yes, real-world sizes.
6. **Sal to add items:** thatch, cut stone block, brick, mortar, ladder. Needs the coordinator to relay.
