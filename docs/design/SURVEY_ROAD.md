# Survey a path: the survey line

Status: built on branch `claude/project-thread-cc8lqc` (17 Nov 2026), not played. Source: Dave, 17 Nov 2026, in the project chat (his request, the coordinator's rephrase and his corrections, quoted below).

## What Dave asked for

The fault: "if I go a short distance it works fine. if I go longer it says this is the starting point again."

The wanted behaviour, in his words and corrections:

- "the first marker should go down and then it should be place a marker and then create a bright green line on the ground showing a straight line from that marker to where I am aiming on the ground so I can see where its going to go."
- "I should be able to place it no matter what. if it goes through stuff just go right under it. if I go right through a tree just draw right through it."
- "trees fall down and stumps are destroyed leaving stuff like I chopped them. buildings are the only exception. the line must turn from green to red if we hit a building with it and it must block the path building. this will force us to go around buildings."
- Rocks (final answer): "I take that back rocks are left on the path to be broken with tools later".
- "if a path goes over a stump that should get rid of the grass 2m to either side of the path and stop trees and rocks from respawning on the path."

## Cause of the fault

The client sent a marker as "the next of this survey" only when it was within 40 m of the last one (`held_item.gd _grade_point_here`); farther, it sent a fresh start, and the server began a new survey there ("Survey begun at this marker"). The server also skipped any marker more than 40 m from the road (`ROAD_MAX_M`). Both limits are deleted.

## How it works now

- **Markers.** Hoe in Survey mode, left click (or Shift + right click in any mode) sets a marker where the crosshair meets anything up to 150 m away (the server takes the ground under that spot and allows up to 160 m from the player). After the first, every marker is the next of the same survey, at any distance. Clicking within 1.5 m of the last marker ends the survey (the next marker starts a new road); putting the hoe away ends it too.
- **The line** (client only, `held_item.gd _survey_line`). While a survey is going and the hoe is in hand, a bright line runs from the last marker to the spot under the crosshair. It lies on the ground and over rocks and logs, passes through tree trunks, and is drawn over everything so grass and trees never hide it. It is green, or red when a building is in the way; a red line's marker is refused ("A building is in the way: survey the road round it"). Rebuilt ten times a second only when the aim moves, with at most 160 ground rays.
- **Buildings** (`src/shared/survey_line.gd`, the same test on client and server). A building is any placed structure that is not walked over (structures.json `walkover`: paths, tilled beds) and is not left-overs (remains, a carcass), blueprint sites included, and a campfire. It is in the way when its footprint (turned with the piece) comes within the road's 1 m half width of the straight line. The server checks again when the marker arrives and refuses it the same way, so a client cannot build through a house; a refused marker's flag comes down and the surveyor's line goes back to the last kept marker (`survey_refused`). The client knows buildings within about 100 m, so a far one may show green and still be refused.
- **The road** is built marker to marker in the order set (the line the surveyor saw), a station every 0.7 m every 0.5 s, as before. It is laid straight under rocks (the old rule that a road patch keeps 1 m off a rock no longer applies to a surveyed road; hand-trodden paths keep it).
- **Trees on the road** (standing trees whose trunk is within the half width of the line) fall as if chopped: `_fell`, so they come down already in their logs and the logs are physics logs (#1188). They fall away from the road's middle line. Each flora chunk's trees near the line are listed once, when the road comes within reach of that chunk (`terrain_server._trees_along`, chunks whose full list the server already holds only, so making a chunk never stalls it; one not made yet is asked again at the next station), and fall in order as the stations reach them, at most 2 a station, so a road through thick forest fells as it goes and never all at once.
- **Stumps on the road** (one already there, or the stump of a tree the road felled, once it has landed) are broken up where they stand: what the last axe blow on a stump gives (drops.json `stump`, `_stump_final_rows`) is left on the ground beside it. A world drop: no player's luck, nobody's gathering goals.
- **Rocks** are left standing, untouched, for the player's tools.
- **Grass.** A surveyed road's patches carry `road`; the client keeps grass and small plants off 3 m round each (the road's 1 m half width plus 2 m), thinning out to 3.4 m. Hand-trodden path patches keep their narrow 0.6 to 1.1 m bare patch. The mark is saved with the patch (world_items.json structure row index 20).
- **No regrowth.** Every road patch is something put down, so it opens a no-spawn zone round it (`spawn_zones.gd`, #1215: nothing wild appears or regrows within its radius), and a broken boulder never comes back, so neither trees nor rocks return on a road. A rock still standing on a road stays until broken.
- **Multiplayer.** Other players see the road, the felled trees and their logs through the normal world sync. Only the surveyor sees the line.

## For Dave (provisional, adjust after play)

| # | Choice | Value |
|---|---|---|
| SV-1 | How far away you can aim a marker | the crosshair picks out ground up to 150 m from you (the length of its aiming ray; server allows 160 m). This is not a road limit: walk on and the next marker joins the last at any distance. Aiming past 150 m says so plainly |
| SV-2 | Ending a survey | click within 1.5 m of the last marker, or put the hoe away |
| SV-3 | What counts as a building | every placed structure except paths, tilled beds, remains and carcasses; blueprint sites and campfires count. Hob and other NPCs have no structures, so nothing of theirs blocks |
| SV-4 | Grass cleared | 3 m from the road's middle line (1 m half width + 2 m), thinning to 3.4 m |
| SV-5 | Which trees fall | trunk within 1 m of the line plus its own radius; at most 2 a station (every 0.5 s) |
| SV-6 | Fall direction | away from the road's middle line, to the side the tree stands on |
| SV-7 | A stump's pieces | the last-blow rows of drops.json `stump` by its radius, rolled with no luck, left on the ground |
| SV-8 | Order of building | marker to marker in the order set (was: the nearest waiting marker first, 3 Nov 2026) |
| SV-9 | Line colour and width | bright green / red, 12 cm wide, drawn over everything |

## Known limits

- No cap on path patches (Dave 17 Nov 2026: "It really doesnt need a limit for paths"): the old 400 a chunk `cap_per_chunk` is deleted, for hand paths and roads. Each patch is a world item the client draws as its own node; the frame cost of a very long road in view is not measured yet.
- A flora chunk the server never makes while the road passes (nobody near it) keeps its trees: the road goes under them.
- A tree the world regrew from a sapling is not on the road's tree list (as with the dig-under-trees rule); the road goes under it.
- At most 24 markers can wait for the builder (`ROAD_MAX_MARKERS`); unchanged.
