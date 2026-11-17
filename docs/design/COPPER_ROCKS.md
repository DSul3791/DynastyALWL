# Copper and tin rocks

**Status: Dave's requests, 16 and 17 Nov 2026 (project thread "Rework copper rocks and placement"). Values in "For Dave" are provisional choices made on his behalf; he may change any of them.**

## What Dave asked for
**Copper (16 Nov).** A photo of real copper ore (rough rocks almost wholly coated in green to blue-green malachite, darker blue-black patches, a yellow-green dusting, among tan limestone; a blue pen for scale; pieces from fist size to a boulder about 40-50 cm across):

> this is what real copper rocks look like. there is a blue pen in the photo for scale. I want to change our copper rocks to look like these rocks. they should come in various sizes that have various amounts of copper in them. they should be strewn about the lands a bit and more abundant along river beds and shores. larger boulders should happen near the base of mountains some times.

**Tin (17 Nov).** A photo of cassiterite (a pale speckled granite block crossed by white quartz veins carrying dark brown-black glassy crystals with rust staining; a smaller chunk crusted with the crystals; six smooth, dark, water-worn pebbles a few cm across):

> this is tin or cassiterite it is found along riverbeds often smaller the further down stream you go and the closer to the mountains it should be in bolder sizes and can be harvested by hammer. the smaller rocks should be picked by hand.

**Copper by hand (17 Nov):**

> copper should be the same smaller rocks can be picked by hand and the larger rocks should be harvested with a hammer.

## What the game does now
- **Look.** Copper and tin rocks share three lumpy, broken-faced meshes and each has its own material (`src/client/ore_rock_look.gd`, used by `inventory_view._show_boulder` for any boulder row whose ore is copper or tin):
  - copper: green to teal malachite coat, blue-black patches, yellow-green dust on upper faces, a little pale host rock, a crusty grain;
  - tin: pale speckled granite with grey patches, a white quartz vein carrying dark brown-black cassiterite crystals (a little shinier), rust stain along the vein.
  The old streaked-granite outcrop looks for copper and tin (`OUTCROP_LOOK`) are deleted; iron, coal, salt and limestone keep theirs.
- **Small rocks by hand.** A copper or tin rock under 10 cm radius (20 cm across) is a loose Copper ore or Tin ore lying on the ground, picked up with E like a stone; once taken it stays gone. Their loose look (`basic_look.gd`): copper a small malachite-coated lump; tin three smooth dark water-worn pebbles with a dull shine. The inventory icons are unchanged (the icon bake runs on Dave's PC).
- **Bigger rocks are boulder rows** with ore `copper` or `tin`, broken with a hammer (the Stone Hammer, any material) or a pick, like any outcrop. No item was added, renamed or removed; the pieces are the existing Copper ore, Tin ore and Stone.
- **Ore amount.** Each rock has a grade (the share of its pieces that are ore), fixed from its key. Its pieces follow its size (the boulder volume rule in `boulders.json`), so the ore in a rock is its pieces times its grade: a rock 40 cm across is about 37 pieces (copper 7-22 ore), 60 cm about 125 (25-75), a 2 m boulder about 4,600 (copper 900-2,800). Geology copper and tin outcrops get a grade too, in place of the old flat `piece_share` 0.3.
- **Copper placement** (`boulders.json` `copper_rocks`; per 32 m cell, from the cell's own seeded stream; nothing depends on where spawn is):
  - strewn thinly over all dry land;
  - far commoner on river and lake beds in shallow water and on dry banks within 3 m of water; never in deeper water;
  - one extra try per cell for a big copper boulder at the foot of a mountain: gentle ground where the land climbs more than 12 m within 24 m.
- **Tin placement** (`boulders.json` `tin_rocks`): only in shallow water or on banks, and only within 80 m of a tin body of the geology (its river placers, laid along rivers downstream of tin, and the guaranteed one per river tile). Its size follows how steeply the ground climbs within 24 m: where the valley side rises 12 m or more (near the mountains) it is a boulder of 0.5-1 m radius; on flat ground (far downstream) a pebble; between, in proportion, with some spread.
- Geology copper and tin outcrop boulders (`boulder_share` of the boulders near an ore body) stay, now drawn with the new looks.
- **Keys.** A cell's boulders use slots 0-7, copper 8-15 (15 the mountain-foot boulder), tin 16-23. Copper boulders keep the boulder key form; tin boulders and every rock picked by hand use `ORE_KEY` (bit 52), so nothing moves another rock and taken or worked rocks are saved.
- **Reads stay in loaded ground.** The mountain-foot and tin relief probes reach at most 26 m (SCATTER_PAD_M - 4), inside the tiles the scatter has already loaded, so they never load a tile on the server's main thread.
- **Cost.** Five draws per try; about half the copper tries and 40% of the tin tries are refused before any read; the rest read the ground and the water depth, dry-bank tries two water probes; tin also asks the geology once and reads 4 heights. NOT MEASURED yet (the slow-cell log line has a "copper and tin rocks" part).
- **Known, not changed:** ore rocks count toward the client's boulder draw cap (24 at Low), first come; near a river at Low a few may take places of plain boulders. The grade is sent to clients with the row (unused there). `tools/outcrops_near.gd` lists every copper or tin rock as an outcrop.

## For Dave (provisional, assumed on his behalf)
| ID | Choice | Value | Why |
|---|---|---|---|
| CR-1 | Small copper rocks are picked up by hand; "small" ends at 20 cm across | radius under 10 cm: loose Copper ore, 1 piece | His 17 Nov ruling; 20 cm is about what one hand lifts. (Was: all need a pick.) |
| CR-2 | "Strewn about the lands" means everywhere on dry land, thinly, not only near copper geology | 4 tries a cell, 2% each (about 1 rock per 12 cells, roughly 3 within 100 m of a player) | His words name the lands, not ore areas; geology copper outcrops still add more in copper country. |
| CR-3 | River beds and shores | 50% per try in water up to 0.8 m deep or on a bank within 3 m of water; none deeper | Shallow so a player can see and reach them. About 25 times the land density. |
| CR-4 | Sizes | radius 6-30 cm (12-60 cm across), small ones commoner; about 4 in 10 are small enough to pick up | Matches the photo's fist size to 50 cm boulder. |
| CR-5 | Mountain-foot boulders | 8% a cell where the ground is gentle and climbs over 12 m within 24 m; radius 0.6-1.3 m | "Larger boulders ... near the base of mountains some times." |
| CR-6 | Copper per rock | grade 0.2-0.6 per rock (avg 0.4), copper = pieces x grade | "Various amounts of copper"; geology outcrops were 0.3 flat, now 0.2-0.6. |
| CR-7 | Geology copper outcrop boulders stay and get the new look | kept | They are the game's existing copper rocks, which he asked to look like the photo. |
| CR-8 | A pick still breaks copper and tin rocks as well as a hammer | kept | He named the hammer; nothing he said takes the pick away, and the pick ladder (iron needs bronze) is unchanged. |
| TN-1 | Tin only by water, and only near tin geology | shallow water or a bank within 3 m, within 80 m of a tin body; none on dry land away from water | "Found along riverbeds"; the geology already lays tin placers along rivers downstream of tin. |
| TN-2 | How common | 4 tries a cell, 60% each where allowed | Rarer than copper overall because it needs a tin body nearby. |
| TN-3 | "Smaller further downstream, boulders near the mountains" | size from how far the ground climbs within 24 m: 12 m or more = boulder radius 0.5-1 m; flat = pebble; in between in proportion | Downstream rivers run through flatter land; near mountains the valley sides are steep. Cheap: 4 height reads. |
| TN-4 | Small tin by hand; "small" ends at 20 cm across | radius under 10 cm: loose Tin ore, 1 piece | His words; same line as copper. |
| TN-5 | Tin per boulder | grade 0.15-0.45 (avg 0.3, the old tin share) | Tin sits in veins, so less of the rock is ore than copper's coat. |
| TN-6 | Loose Tin ore looks like his water-worn pebbles, loose Copper ore like a small malachite lump | item looks only | Same item, new ground look; icons unchanged until a PC icon bake. |

## Not changed
- Iron, coal, salt and limestone outcrops keep their look and rules.
- The ore check's body depth (noticed in the "Find where copper and tin spawn" lookup) is untouched; that is Dave's call.
- Item catalog: no additions, renames or removals.

## Checks
- `src/worldgen/tools/test_copper_rocks.gd`: copper land vs river density, none in deep water, sizes, small ones loose and picked up by hand (and stay taken), grades, key ranges, same layout every time, mountain-foot boulders only at the foot, geology outcrops graded, a richer rock gives more copper, the meshes and looks; tin only by water near a tin body, pebbles on flat ground, boulders on steep valley sides, graded, same every time.
- `tools/ore_rock_view.gd` (with `tools/shot_node.gd`): picture of both rocks at their real sizes and the loose ores, with a 14 cm pen, on Dave's PC.
