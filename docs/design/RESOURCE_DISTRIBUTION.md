# World resource distribution: implementation

**Status:** stage 1 implemented on branch `claude/project-thread-1mwrkm` (not yet tested on a lane, not yet played). Stages 2 and 3 in progress.
**Design source:** Dave, 21 Nov 2026, `docs/handoff/RESOURCE_DISTRIBUTION_ARCHITECTURE.md` (dev 53fb11a9) and his assignment in project thread "Implement world resource distribution". That handoff is the requirement; this file maps it onto the code and records the provisional values (RD-n). Values here are PROVISIONAL unless marked otherwise.

## How it fits the existing game

| Handoff responsibility | Where it lives now |
|---|---|
| Landscape context (island, interior, rivers, hills, water) | `src/stream/resource_context.gd`, built once a run from the baked tiles' coarse maps (`low_height`, `low_water_class`, 32 m) on a 64 m grid, on a worker thread at server start (`server_items.start_resources`). Islands, distance to the sea, each island's widest distance and peak, the high ground near each cell, a priority-flood drainage (receivers and drained area) that follows tributaries and confluences. |
| Resource availability | Same file: `journey` (shore 0 to headwaters 1) and one `field` per metal (iron, copper, tin). |
| Deposit generation | Same file: finite sources per metal on a world grid, with size, radius and a stable id; the starting-island check adds an assured source where needed. |
| Surface representation | `server_items.gd`: `_lay_out_sources` (outcrops at a source, fragments downhill), `_lay_out_ore_rocks` (copper, tin and iron rocks now limited to their area or their river clue, sizes and shapes by journey), `_lay_out_boulders` (plain rocks bigger, commoner and more angular inland). Shapes on the client: `ore_rock_look.gd` (rounded, broken, jagged) chosen by the row's `ang`. |
| Associated discoveries | Stage 2 (below). |
| Validation and persistence | Deterministic from the seed and the tiles: nothing new is saved for the landscape. Worked and taken rocks keep the existing saves (`boulders`, `_taken` keys). Starting-island route check in `_assure`. |

The existing geology (tile ore bodies, coal layers, gem lenses) stays as it is: it is in the baked tiles, and changing it would mean a new `TERRAIN_VERSION` and a re-bake. Its copper, tin and iron outcrops now show only inside that metal's area (`_boulder_ore`). **No terrain version change and no bake.**

## Stage 1 (this PR): landscape, areas, sources, river clues, rock form

1. **Journey** (RD-1): `0.5 x inland + 0.25 x height share + 0.25 x high ground share`, each 0..1 against the island's own widest inland distance (at least 1,500 m) and its peak (at least 150 m); high ground = the highest ground within 768 m. Not absolute height alone, not world-origin distance.
2. **Areas, the paint** (RD-2): per metal, `journey + 0.55 x (warped value noise - 0.5)` (waves 3.2 km, warped by 1.6 km), cut at the island's own quantile so iron covers 90%, copper 60% and tin 40% of a large island, blended over a narrow band. Different noise per metal, so the areas overlap irregularly and are not rings. Small islands get less (none below about 400 m inland width; iron never under 60% of its share). Dave's 80%/60% were examples; these shares are tuning values.
   On the starting island (96 km², peak 1,375 m): iron 90%, copper 60%, tin 40%; inside the tin area iron is present in 99.8% and copper in 96%; inside copper, iron in 96%.
3. **Sources** (RD-3): one candidate per metal per 384 m square, a source with chance `base x field x (0.4 + 0.6 x journey)`, base iron 0.10, copper 0.22, tin 0.22. Size 0..1 grows with journey; radius 8 to 30 m. Never in the sea, a lake or a river cell. Starting island today (cloud mirror of the code, not a lane run): about 130 iron, 200 copper, 150 tin sources over the nine baked tiles.
4. **Starting-island check** (RD-4, handoff 13): walking cost from spawn over the island (`64 m x (1 + 8 x slope²)`, +150 m per river cell, slopes over 0.7 refused, ground above 60% of the island peak refused). If no source of a metal lies within its budget (iron 3 km, copper 3 km, tin 6 km), the best reachable cell of its area becomes an assured source. Today: nearest iron 0.6 km, copper 1.4 km, tin 2.0 km by route from spawn, highest ground on the tin route about 140 m (peak 1,375 m), so nothing is assured. Logged at server start ("resources: ...").
5. **River clues** (RD-5): from each source down its own drainage; strength 1 at the source, falling by `exp(-step / transport)` along a channel (iron 3 km, copper 1.8 km, tin 1.2 km) and `exp(-step / 300 m)` down a hillside; a lake ends it; nothing runs up another tributary. Copper and tin rocks by water count the clue like their area; their size shrinks with the clue (down to 0.4) so finds get smaller downstream.
6. **Copper, tin and iron rocks** (RD-6): the shared `ore_rocks` rule stays (Dave 21 Nov: rivers, more and bigger toward the mountains, a little on land, very many over their own ore body), with three changes: `upland` is the journey, not height; every chance is scaled by the metal's area (by water: by area or river clue, whichever is higher); a mountain-foot boulder needs the area. Outside its area and away from its clues an ore does not appear. **This supersedes the 21 Nov "both should be there [near the ocean] ... small chance almost anywhere" for copper and tin where they conflict**: the handoff is Dave's later direction ("copper and tin should retain their inland identity"; tin by the sea only as a source-linked river find). Iron stays almost everywhere. Meteorites unchanged.
7. **Sources on the ground** (RD-7): at a source, 2 to 8 angular outcrop boulders inside its radius (0.5 to 1.4 m radius by size), grade 0.4 to 0.8 by size; below it 4 to 14 broken fragments strewn down the slope up to 40 to 120 m, smaller the farther, the smaller ones loose ore to pick up by hand. Same rules for iron (its outcrops still need a bronze or better pick). Keys: cell slots 64 and up.
8. **Rock form** (RD-8): every boulder row gets `ang` 0..1 (journey plus a little jitter, water-worn rocks x 0.45). The client draws ore rocks rounded under 0.35, broken (the photos' shape, unchanged) up to 0.7, jagged above; plain boulders keep their rounded mesh unless jagged. Plain boulders: chance x 0.6 at the shore to x 1.5 at the headwaters, radius x 0.55 to x 1.25 (so the biggest common boulder is about 3 m across at the headwaters, provisional against Dave's open choice "3 m common, 5 m landmarks").

## Stage 2 (next): coal seams and finds revealed by digging

- **Coal districts:** hillsides and mountain edges with wet ground (marsh, fen, bog, swamp, lake) below them within a few hundred metres, sedimentary host rock where the tile says so; noise so not every such slope has coal.
- **Seams:** a seam runs along the hillside at one height for 60 to 200 m; where it crosses steep ground it shows as a line of dark banded outcrops with loose coal below. Digging with a shovel inside the seam's band yields coal, so a player can follow it into the hill.
- **Pockets:** a configurable association table (sources and host rock -> possible finds, rarity, pocket size, tools). Pockets are placed with the sources, deterministically, under the ground. A dig that opens one shows it as a rock in the hole to break with a pick, holding its find. Most sources have none. New finds (coordinator decision D-ORE-1, 21 Nov, under Dave's rule that agents' questions go to the coordinator): Gold nugget, Silver ore, Amethyst, Garnet, Agate, sell value only, no recipes; plus the existing Crystal lens (quartz). Associations: gold as nuggets in river gravels below sources and in quartz veins; silver with copper; amethyst and agate in quartz cavities; garnet in hard mountain rock.
- Revealed pockets and what is left in them are saved with the world.

## Stage 3: diagnostics, access, tuning

A Godot tool draws the landscape (areas, sources, clues, coal, routes) as a picture from the real code for Lane A, and a lane run checks the cost of the build at server start and of the scatter.

## Where each ore is findable by game stage (for the goals thread)

| Stage | Iron | Copper | Tin |
|---|---|---|---|
| First hour (hands, stone tools) | Visible everywhere: rust-red loose Iron ore stones along rivers, bog iron in wet ground (any shovel), rusty outcrops at sources. Hand-picked stones give Iron ore; outcrops need a bronze or better pick. | Loose Copper ore and copper rocks along rivers and at sources inland of the coast; nearest source about 1.4 km by route from spawn. Any pick or the Stone Hammer. | River finds near the coast only below a source (rounded, small); first tin source about 2 km by route from spawn, below the high mountains. Any pick or the Stone Hammer. |
| Bronze | Bronze pick takes iron outcrops; iron needs the improved smelter and bellows to use. | Bigger copper outcrops farther inland. | Bigger tin outcrops and richer sources farther inland and up the rivers. |
| Iron and later | Bigger iron sources inland. | Same. | Same. |

## Saves and existing worlds

Nothing is regenerated and no world is reset. Scatter is not saved; it is laid out again from the seed each run, as before. In an existing world, rocks nobody has touched move to the new layout. A rock that was partly worked keeps its saved count under its key, capped at what the rock now at that key holds (the same as every scatter change since #1411). Loose pieces already taken stay taken by key.

## Not done yet (tracked)

- Coal seams, digging pockets, the five new finds (stage 2).
- Lane measurement of the build time (cloud mirror took 5 s in Python; GDScript expected 1 to 3 s on a worker thread, NOT MEASURED) and of the scatter cost per cell (NOT MEASURED).
- Pictures (Lane A): rounded, broken and jagged rocks; a source with its outcrops and fragments; a river with clues.
- Danger information on routes: the check avoids the high mountain ground only; it does not yet read goblin or bandit camps.
