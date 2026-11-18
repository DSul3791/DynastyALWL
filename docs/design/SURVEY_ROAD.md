# Survey a path: the survey line

Status: in dev (#1214, 17 Nov 2026); trees dropping and the doubled pace (18 Nov 2026) on branch `claude/project-thread-cc8lqc`. Not played. Source: Dave, 17 Nov 2026, in the project chat (his request, the coordinator's rephrase and his corrections, quoted below).

## What Dave asked for

The fault: "if I go a short distance it works fine. if I go longer it says this is the starting point again."

The wanted behaviour, in his words and corrections:

- "the first marker should go down and then it should be place a marker and then create a bright green line on the ground showing a straight line from that marker to where I am aiming on the ground so I can see where its going to go."
- "I should be able to place it no matter what. if it goes through stuff just go right under it. if I go right through a tree just draw right through it."
- "trees fall down and stumps are destroyed leaving stuff like I chopped them. buildings are the only exception. the line must turn from green to red if we hit a building with it and it must block the path building. this will force us to go around buildings."
- Rocks (final answer): "I take that back rocks are left on the path to be broken with tools later".
- "if a path goes over a stump that should get rid of the grass 2m to either side of the path and stop trees and rocks from respawning on the path."
- On the road's uneven speed (18 Nov 2026): "if they are felled by this tool they just drop. no animation." and "lets double the speed for road building for our first try".

## Cause of the fault

The client sent a marker as "the next of this survey" only when it was within 40 m of the last one (`held_item.gd _grade_point_here`); farther, it sent a fresh start, and the server began a new survey there ("Survey begun at this marker"). The server also skipped any marker more than 40 m from the road (`ROAD_MAX_M`). Both limits are deleted.

## How it works now

- **Markers.** Hoe in Survey mode, left click (or Shift + right click in any mode) sets a marker where the crosshair meets anything up to 150 m away (the server takes the ground under that spot and allows up to 160 m from the player). After the first, every marker is the next of the same survey, at any distance. Clicking within 1.5 m of the last marker ends the survey (the next marker starts a new road); putting the hoe away ends it too.
- **The line** (client only, `held_item.gd _survey_line`). While a survey is going and the hoe is in hand, a bright line runs from the last marker to the spot under the crosshair. It lies on the ground and over rocks and logs, passes through tree trunks, and is drawn over everything so grass and trees never hide it. It is green, or red when a building is in the way; a red line's marker is refused ("A building is in the way: survey the road round it"). Rebuilt ten times a second only when the aim moves, with at most 160 ground rays.
- **Buildings** (`src/shared/survey_line.gd`, the same test on client and server). A building is any placed structure that is not walked over (structures.json `walkover`: paths, tilled beds) and is not left-overs (remains, a carcass), blueprint sites included, and a campfire. It is in the way when its footprint (turned with the piece) comes within the road's 1 m half width of the straight line. The server checks again when the marker arrives and refuses it the same way, so a client cannot build through a house; a refused marker's flag comes down and the surveyor's line goes back to the last kept marker (`survey_refused`). The client knows buildings within about 100 m, so a far one may show green and still be refused.
- **The road** is built marker to marker in the order set (the line the surveyor saw), a station every 0.7 m every 0.25 s: about 2.8 m/s (Dave 18 Nov 2026: twice the old 0.5 s). The pace is kept by the clock: a slow server moment is made up on the next ticks, at most 4 stations in one tick, so the road keeps a steady speed instead of slowing whenever the server is busy. Each new piece of road goes out to the players within 0.25 s (it used to wait for the once-a-second world update). There is no wait at a marker any more. It is laid straight under rocks (the old rule that a road patch keeps 1 m off a rock no longer applies to a surveyed road; hand-trodden paths keep it).
- **Trees on the road** (standing trees whose trunk is within the half width of the line) just drop (Dave 18 Nov 2026: no fall, no animation): the tree is gone and what chopping it gives lies still on the ground beside the road, on the side the tree stood: its logs at their usual lengths, end to end, pointing away from the road, the rest of its pieces, and its stump's last-blow pieces (`_road_drop`). Nothing lies within 1.3 m of the middle line. No stump is left. The logs are ordinary loose logs from then on (pushed, carried, rolled when something strikes them); none is woken into the physics when it is laid. Hand felling is unchanged. Each flora chunk's trees near the line are listed once, when the road comes within reach of that chunk (`terrain_server._trees_along`, chunks whose full list the server already holds only, so making a chunk never stalls it; one not made yet is asked again at the next station), and are cleared in order as the stations reach them, at most 2 a station, so a road through thick forest clears as it goes and never all at once.
- **Stumps on the road** (one already there before the road came) are broken up where they stand: what the last axe blow on a stump gives (drops.json `stump`, `_stump_final_rows`) is left on the ground beside it. A world drop: no player's luck, nobody's gathering goals.
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
| SV-5 | Which trees are cleared | trunk within 1 m of the line plus its own radius; at most 2 a station (every 0.25 s, so up to 8 a second) |
| SV-6 | Where a cleared tree lies | dropped at once (no fall, no crush), on the side the tree stood, logs pointing away from the road, nothing within 1.3 m of the middle line (`ROAD_CLEAR_M`) |
| SV-7 | A stump's pieces | the last-blow rows of drops.json `stump` by its radius, rolled with no luck, left on the ground |
| SV-8 | Order of building | marker to marker in the order set (was: the nearest waiting marker first, 3 Nov 2026) |
| SV-9 | Line colour and width | bright green / red, 12 cm wide, drawn over everything |
| SV-10 | Road speed | a station (0.7 m) every 0.25 s, about 2.8 m/s (`ROAD_STATION_M`, `ROAD_STEP_S` in server_items.gd; Dave 18 Nov 2026: double as a first try) |
| SV-11 | Making up lost time | at most 4 stations in one tick after a slow moment (`ROAD_CATCHUP`); a longer stall is not made up |
| SV-12 | How soon others see new road | within 0.25 s while a road builds (`ROAD_SYNC_S`); the rest of the world still every 1 s |

## Known limits

- A dropped tree hurts nobody. Dave's 17 Nov "like normal when trees fall" assumed trees fall; with no fall there is no landing to hurt anyone under it.
- Doing a station's ground edits in one go was left out: the ground has no batch edit, and each edit is its own message to the players and its own redraw. On a slope a station still makes up to 3 edits; at the doubled pace that is up to 12 a second while the road climbs. If slopes still slow the road, the next step is fewer, larger edits.
- Each station still looks through every world item once (stumps, rocks, patches near it), now 4 times a second instead of 2.

- No cap on path patches (Dave 17 Nov 2026: "It really doesnt need a limit for paths"): the old 400 a chunk `cap_per_chunk` is deleted, for hand paths and roads. Each patch is a world item the client draws as its own node; the frame cost of a very long road in view is not measured yet.
- A flora chunk the server never makes while the road passes (nobody near it) keeps its trees: the road goes under them.
- A tree the world regrew from a sapling is not on the road's tree list (as with the dig-under-trees rule); the road goes under it.
- At most 24 markers can wait for the builder (`ROAD_MAX_MARKERS`); unchanged.
