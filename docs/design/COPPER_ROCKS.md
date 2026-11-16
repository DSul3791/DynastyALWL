# Copper rocks

**Status: Dave's request, 16 Nov 2026 (project thread "Rework copper rocks and placement"). Values in "For Dave" are provisional choices made on his behalf; he may change any of them.**

## What Dave asked for
Dave sent a photo of real copper ore (rough rocks almost wholly coated in green to blue-green malachite, darker blue-black patches, a yellow-green dusting, among tan limestone; a blue pen for scale; pieces from fist size to a boulder about 40-50 cm across) and wrote:

> this is what real copper rocks look like. there is a blue pen in the photo for scale. I want to change our copper rocks to look like these rocks. they should come in various sizes that have various amounts of copper in them. they should be strewn about the lands a bit and more abundant along river beds and shores. larger boulders should happen near the base of mountains some times.

## What the game does now
- **Look.** Every copper rock is drawn with its own lumpy, broken-faced mesh (three shapes) and a malachite material: green to teal coat, blue-black patches, yellow-green dust on upper faces, a little pale host rock, a crusty grain. `src/client/copper_rock_look.gd`, used by `inventory_view._show_boulder` for any boulder row whose ore is copper. The old granite boulder with thin green streaks (`OUTCROP_LOOK["copper"]`) is deleted.
- **Rocks are boulder rows.** A copper rock is a server boulder with ore `copper`, mined like any outcrop (a pick, or the Stone Hammer, any material). No item was added, renamed or removed; the pieces are the existing Copper ore and Stone.
- **Copper amount.** Each copper rock has a grade (the share of its pieces that are Copper ore), fixed from its key. Its pieces follow its size (the boulder volume rule in `boulders.json`), so the copper in a rock is its pieces times its grade: a fist-sized rock is 1 piece, a rock 40 cm across about 37 pieces (6-22 copper ore), one 60 cm across about 125 (25-75 ore), a 2 m mountain-foot boulder about 4,600 (900-2,800 ore). Geology copper outcrops get a grade too, in place of the old flat `piece_share` 0.3.
- **Placement** (`boulders.json` `copper_rocks`, `server_items._lay_out_copper_rocks`; per 32 m cell, from the cell's own seeded stream; nothing depends on where spawn is):
  - strewn thinly over all dry land;
  - far commoner on river and lake beds in shallow water and on dry banks within 3 m of water; never in deeper water;
  - one extra try per cell for a big copper boulder at the foot of a mountain: gentle ground where the land climbs more than 20 m within 48 m.
  - The copper outcrop boulders of the geology (`boulder_share` of the boulders near a copper body) stay, now drawn as copper rocks.
- **Keys.** A cell's boulders use keys 0-7, copper rocks 8-15 (15 is the mountain-foot boulder), so worked rocks are saved like boulders and never move another boulder.
- **Cost.** Four cheap draws per try; most tries are refused before any water or height read. Measured cost: NOT MEASURED yet (the slow-cell log line now has a "copper rocks" part).

## For Dave (provisional, assumed on his behalf)
| ID | Choice | Value | Why |
|---|---|---|---|
| CR-1 | Small copper rocks need a pick or Stone Hammer; none are picked up by hand | as boulders | Earlier ruling: ore is mined with a pick, a stone pick is enough. |
| CR-2 | "Strewn about the lands" means everywhere on dry land, thinly, not only near copper geology | 4 tries a cell, 2% each (about 1 rock per 12 cells, roughly 3 within 100 m of a player) | His words name the lands, not ore areas; geology copper outcrops still add more in copper country. |
| CR-3 | River beds and shores | 50% per try in water up to 0.8 m deep or on a bank within 3 m of water; none deeper | Shallow so a player can see and reach them. About 25 times the land density. |
| CR-4 | Sizes | radius 6-30 cm (12-60 cm across), small ones commoner | Matches the photo's fist size to 50 cm boulder. |
| CR-5 | Mountain-foot boulders | 8% a cell where the ground is gentle and climbs over 20 m within 48 m; radius 0.6-1.3 m | "Larger boulders ... near the base of mountains some times." |
| CR-6 | Copper per rock | grade 0.2-0.6 per rock (avg 0.4), copper = pieces x grade | "Various amounts of copper"; geology outcrops were 0.3 flat, now 0.2-0.6. |
| CR-7 | Geology copper outcrop boulders stay and get the new look | kept | They are the game's existing copper rocks, which he asked to look like the photo. |

## Not changed
- Tin, iron, coal, salt and limestone outcrops keep their look and rules.
- The ore check's body depth (noticed in the "Find where copper and tin spawn" lookup) is untouched; that is Dave's call.
- Item catalog: no additions, renames or removals.

## Checks
- `src/worldgen/tools/test_copper_rocks.gd`: land vs river density, none in deep water, sizes, grades, key range, same layout every time, mountain-foot boulders only at the foot, geology outcrops graded, a richer rock gives more copper, the meshes.
- `tools/copper_rock_view.gd` (with `tools/shot_node.gd`): picture of the rocks at their real sizes with a 14 cm pen, on Dave's PC.
