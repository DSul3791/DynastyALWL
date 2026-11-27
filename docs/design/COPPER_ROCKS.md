# Copper and tin rocks

**Status: Dave's requests, 16 and 17 Nov 2026 (project thread "Rework copper rocks and placement"). Values in "For Dave" are provisional choices made on his behalf; he may change any of them.**

## What Dave asked for
**Copper (16 Nov).** A photo of real copper ore (rough rocks almost wholly coated in green to blue-green malachite, darker blue-black patches, a yellow-green dusting, among tan limestone; a blue pen for scale; pieces from fist size to a boulder about 40-50 cm across):

> this is what real copper rocks look like. there is a blue pen in the photo for scale. I want to change our copper rocks to look like these rocks. they should come in various sizes that have various amounts of copper in them. they should be strewn about the lands a bit and more abundant along river beds and shores. larger boulders should happen near the base of mountains some times.

**Tin (17 Nov).** A photo of cassiterite (a pale speckled granite block crossed by white quartz veins carrying dark brown-black glassy crystals with rust staining; a smaller chunk crusted with the crystals; six smooth, dark, water-worn pebbles a few cm across):

> this is tin or cassiterite it is found along riverbeds often smaller the further down stream you go and the closer to the mountains it should be in bolder sizes and can be harvested by hammer. the smaller rocks should be picked by hand.

**Tin in rivers (17 Nov, after seeing the picture):**

> the river stream tin rocks should look like glass rocks shiny and reflective the size of plumbs

**One rule for both (21 Nov, play test, after finding copper but no tin by the river at the new spawn):**

> both copper and tin should be placed along or close to rivers being more abundant and bigger near the mountains and smaller and less abundant closer to the ocean but they should both be there. they should even have a small chance of randomly being almost anywhere

> they should also be very abundant if they are right over an ore vein of their type

**Copper by hand (17 Nov):**

> copper should be the same smaller rocks can be picked by hand and the larger rocks should be harvested with a hammer.

## What the game does now
- **Look.** Copper and tin rocks share three lumpy, broken-faced meshes and each has its own material (`src/client/ore_rock_look.gd`, used by `inventory_view._show_boulder` for any boulder row whose ore is copper or tin):
  - copper: green to teal malachite coat, blue-black patches, yellow-green dust on upper faces, a little pale host rock, a crusty grain;
  - tin: pale speckled granite with grey patches, a white quartz vein carrying dark brown-black cassiterite crystals (a little shinier), rust stain along the vein.
  The old streaked-granite outcrop looks for copper and tin (`OUTCROP_LOOK`) are deleted; iron, coal, salt and limestone keep theirs.
- **Small rocks by hand.** A copper or tin rock under 10 cm radius (20 cm across) is a loose Copper ore or Tin ore lying on the ground, picked up with E like a stone; once taken it stays gone. Their loose look (`basic_look.gd`): copper a small malachite-coated lump; tin one smooth, glassy, dark red-brown river stone about 7 cm across, plum size (Dave 17 Nov: "the river stream tin rocks should look like glass rocks shiny and reflective the size of plumbs"), drawn with one shared glassy material (`basic_look._glass_material`: a sharp glint and a wider sheen from each light, dark with the light at night, and the game's sky reflected in its smooth surface; no reflection probe). The inventory icons are unchanged (the icon bake runs on Dave's PC).
- **Bigger rocks are boulder rows** with ore `copper` or `tin`, broken with a hammer (the Stone Hammer, any material) or a pick, like any outcrop. No item was added, renamed or removed; the pieces are the existing Copper ore, Tin ore and Stone.
- **Ore amount.** Each rock has a grade (the share of its pieces that are ore), fixed from its key. Its pieces follow its size (the boulder volume rule in `boulders.json`), so the ore in a rock is its pieces times its grade: a rock 40 cm across is about 37 pieces (copper 7-22 ore), 60 cm about 125 (25-75), a 2 m boulder about 4,600 (copper 900-2,800). Geology copper and tin outcrops get a grade too, in place of the old flat `piece_share` 0.3.
- **Placement, one rule for copper and tin** (21 Nov; `boulders.json` `ore_rocks`, which `copper_rocks` and `tin_rocks` share, each adding only its slot and grade; per 32 m cell, from the cell's own seeded stream per ore; nothing depends on where spawn is):
  - along every river and lake: in shallow water (0.8 m or less) and on dry banks within 8 m of water; never in deeper water;
  - more and bigger toward the mountains, fewer and smaller toward the sea, by the ground height at the spot: at 10 m or lower (the coastal plain) 30% a try and sizes cut to half (mostly loose pieces and small rocks); at 300 m or higher (the valleys under the mountains) 80% a try and full sizes up to 2 m across; in between in proportion;
  - a small chance anywhere on dry land, 1% a try;
  - over a body of its own ore (within 40 m of it), 70% a try wherever the spot lies, and sizes as if 150 m higher: very many rocks;
  - one extra try per cell for a big boulder at the foot of a mountain (gentle ground where the land climbs more than 12 m within 24 m), both ores.
  Before 21 Nov tin lay only by water within 80 m of a tin body, so a river away from tin geology (the one at the new spawn) had none, while copper lined every river.
- Geology copper and tin outcrop boulders (`boulder_share` of the boulders near an ore body) stay, now drawn with the new looks.
- **Keys.** A cell's boulders use slots 0-7, copper 8-15 (15 the mountain-foot boulder), tin 16-23, iron 24-30 (IR-1: loose stones and small all-ore rocks), meteorites 32-38 (MT-1). Copper boulders keep the boulder key form; tin boulders and every rock picked by hand use `ORE_KEY` (bit 52), so nothing moves another rock and taken or worked rocks are saved.
- **Reads stay in loaded ground.** The mountain-foot and tin relief probes reach at most 26 m (SCATTER_PAD_M - 4), inside the tiles the scatter has already loaded, so they never load a tile on the server's main thread.
- **Cost.** Five draws per try, 7 tries and the foot try per ore. Each ore asks the geology once per cell (its own body within reach of the cell) and, only in a cell by its body, once more per spot. Tries past the highest chance (80%, so 1 try in 5) stop before any read; the rest read the ground height, and only those under the chance for that height read the water depth, dry-bank tries two water probes. By the sea most tries stop after the height read. About twice the reads of the old copper rule per cell for copper and tin together; iron (IR-1) adds a third stream with a 90% top chance, so about half as much again. NOT MEASURED yet (the slow-cell log line has a "copper, tin and iron rocks" part).
- **Known, not changed:** the geology check reads only the tile under the spot, so tin just across a tile seam from its body is not laid (no stall, just none there). Ore rocks count toward the client's boulder draw cap (24 at Low), first come; near a river at Low a few may take places of plain boulders. The grade is sent to clients with the row (unused there). `tools/outcrops_near.gd` lists every copper or tin rock as an outcrop.

## For Dave (provisional, assumed on his behalf)
| ID | Choice | Value | Why |
|---|---|---|---|
| CR-1 | Small copper rocks are picked up by hand; "small" ends at 20 cm across | radius under 10 cm: loose Copper ore, 1 piece | His 17 Nov ruling; 20 cm is about what one hand lifts. (Was: all need a pick.) |
| CR-2 | (SUPERSEDED 21 Nov by OR-1..OR-6) "Strewn about the lands" means everywhere on dry land, thinly, not only near copper geology | 4 tries a cell, 2% each (about 1 rock per 12 cells, roughly 3 within 100 m of a player) | His words name the lands, not ore areas; geology copper outcrops still add more in copper country. |
| CR-3 | (SUPERSEDED 21 Nov by OR-1..OR-6) River beds and shores | 50% per try in water up to 0.8 m deep or on a bank within 3 m of water; none deeper | Shallow so a player can see and reach them. About 25 times the land density. |
| CR-4 | Sizes | radius 6-30 cm (12-60 cm across), small ones commoner; about 4 in 10 are small enough to pick up | Matches the photo's fist size to 50 cm boulder. |
| CR-5 | Mountain-foot boulders | 8% a cell where the ground is gentle and climbs over 12 m within 24 m; radius 0.6-1.3 m | "Larger boulders ... near the base of mountains some times." |
| CR-6 | Copper per rock | grade 0.2-0.6 per rock (avg 0.4), copper = pieces x grade | "Various amounts of copper"; geology outcrops were 0.3 flat, now 0.2-0.6. |
| CR-7 | Geology copper outcrop boulders stay and get the new look | kept | They are the game's existing copper rocks, which he asked to look like the photo. |
| CR-8 | A pick still breaks copper and tin rocks as well as a hammer | kept | He named the hammer; nothing he said takes the pick away, and the pick ladder (iron needs bronze) is unchanged. |
| TN-1 | (SUPERSEDED 21 Nov by OR-1..OR-6) Tin only by water, and only near tin geology | shallow water or a bank within 3 m, within 80 m of a tin body; none on dry land away from water | "Found along riverbeds"; the geology already lays tin placers along rivers downstream of tin. |
| TN-2 | (SUPERSEDED 21 Nov by OR-1..OR-6) How common | 4 tries a cell, 60% each where allowed | Rarer than copper overall because it needs a tin body nearby. |
| TN-3 | (SUPERSEDED 21 Nov by OR-1..OR-6) "Smaller further downstream, boulders near the mountains" | size from how far the ground climbs within 24 m: 12 m or more = boulder radius 0.5-1 m; flat = pebble; in between in proportion | Downstream rivers run through flatter land; near mountains the valley sides are steep. Cheap: 4 height reads. |
| TN-4 | Small tin by hand; "small" ends at 20 cm across | radius under 10 cm: loose Tin ore, 1 piece | His words; same line as copper. |
| TN-5 | Tin per boulder | grade 0.15-0.45 (avg 0.3, the old tin share) | Tin sits in veins, so less of the rock is ore than copper's coat. |
| TN-6 | Loose Tin ore looks like one of his water-worn pebbles (glassy since TN-7), loose Copper ore like a small malachite lump | item looks only | Same item, new ground look; icons unchanged until a PC icon bake. |
| TN-7 | "River stream tin rocks" means the small tin picked up by hand (loose Tin ore); tin boulders (20 cm across and up) keep the granite look he liked | one glassy stone per loose Tin ore, about 7 cm across (drawn size at the loose-item scale), dark red-brown, glassy (written-out glint and sheen from each light, roughness 0.05 for the sky reflection) | His plum size matches the hand-picked stones; he said "I like them" on seeing the picture of the rocks (ore_rocks.png). If he wants river tin boulders glassy too, that is the next step. |
| CR-9 | Copper and tin rocks to break, 0.5-2 m across (Dave 17 Nov: "anywhere from .5m to 2m in size ... for both of them") | radius 0.25-1.0, even spread; geology outcrops clamped to it; loose hand pieces kept: 40% of copper, tin on flat ground | His size ruling covers the rocks; he did not rule on the loose pieces, so they stay. |
| CR-10 | (SUPERSEDED 21 Nov by OR-1..OR-6) Copper "near rivers and mountains", land scatter kept (Dave 17 Nov) | banks within 10 m of water, 6 tries a cell at 70%; mountain foot 25% a cell, radius 0.6-1.0; land 2% a try | He could not find copper by a river. The client's boulder draw limit (24-120 by quality) is deleted: every boulder in range is drawn. |
| OR-1 | One placement rule for copper and tin (Dave 21 Nov) | `ore_rocks` shared; only slot and grade differ | His words name both together. Replaces CR-2, CR-3, CR-10 (placement parts), TN-1, TN-2 and TN-3. |
| OR-2 | "Near the mountains" vs "closer to the ocean" read from the ground height at the spot | 0 at 10 m or under, full at 300 m or over | Rivers climb toward the mountains; the island's height bands put the foothills at about 150 to 300 m. One height read, already taken. |
| OR-3 | "More abundant ... less abundant" along rivers | 7 tries a cell; 30% by the sea to 80% under the mountains, in shallow water or within 8 m of water | By the sea still about 1 to 2 of each ore per 32 m of river; under the mountains about 4. |
| OR-4 | "Bigger ... smaller" | size share x 0.5 by the sea, x 1 under the mountains; under 35% of the share a loose piece by hand, above it a rock 0.5 to 2 m across | By the sea mostly hand pieces and rocks under about 85 cm across; 2 m rocks only up the valleys. |
| OR-5 | "A small chance of randomly being almost anywhere" | 1% a try on any dry land (about 1 of each ore per 14 cells, roughly 2 within 100 m of a player) | Was 2% for copper, none for tin. |
| OR-6 | "Very abundant right over an ore vein of their type" | within 40 m of its own body: 70% a try anywhere, about 5 a cell, sizes as if 150 m higher | Uses the existing geology bodies (lenses, halos, veins, placers); a tin body does not raise copper or the other way round. |
| CR-11 | Copper "along all rivers" (Dave 27 Nov 2026, BugsList 186) | by water the chance is never under half of OR-3 outside the copper area or a river clue (`copper_rocks` water_floor 0.5) | Since the 21 Nov landscape the area (60% of each island, the upland part) and the clues gated the river chance too, so rivers on the lower 40% had no copper. Tin unchanged. |
| IR-1 | River iron stones (Dave 21 Nov: "there are reddish brown rocks everywhere normally so iron should be a common thing to find a long river bed as well"; "river iron rocks should be the same size as a rounded iron ingot and they are pickable so you gather them by hand"; "if there are any larger than that they need to be broken down like anormal rock with a pick bronze or better. 1 ingot sized iron rocks will be 50% of the stones out there, 30% of them should be double that size and 20% can be triple sized"; "picking up the single gives 1 Iron ore") | `iron_rocks` on the shared rule, slots 24..30: 3% a try on dry land, 40% by the sea to 90% under the mountains by water, over an iron body too; sizes 50% one ore (a loose Iron ore stone picked by hand), 30% two and 20% three (small all-ore rocks, 18 and 20 cm across, giving exactly 2 or 3 Iron ore and no stone to a bronze or better pick; any other tool is refused so the rock is not ground to stone); no mountain-foot boulder; geology iron outcrops unchanged (outcrops_unchanged) | Commoner than copper and tin everywhere. Iron ore drawn as a rounded red-brown stone the size of an Iron ingot (basic_look iron_stone), everywhere it shows; it still smelts in an Improved or Advanced smelter. |
| MT-1 | Iron-nickel meteorites (Dave 21 Nov: "lets have meteors about half as frequent as rocks ... they break into iron chunks that count as iron ingots ... basically iron chunk inherits from iron ingot") | `meteorite_rocks` on the shared rule, slots 32..39: 1.5% a try anywhere (half of iron's 3% on open ground), no water chances, no ore body, no mountain-foot boulder, full size everywhere; rocks to break 40-70 cm across at the plain boulder yield, grade 0.6-0.9 Iron chunk by weight, any pick or the Stone Hammer; loose pieces are Iron chunk by hand. New item 1517 Iron chunk fills every need for an Iron ingot (ingredient group: recipes, blueprints, the planner, repairs) | "Rocks" read as the iron rocks of the same request, on open ground, since meteorites fall evenly from the sky. About 1 every 10 cells, roughly 3 within 100 m of a player. A 70 cm one gives about 9 chunks. Usable iron from the first day, no smelter: Dave's call. |

## Not changed
- Iron, coal, salt and limestone outcrops keep their look and rules.
- The ore check's body depth (noticed in the "Find where copper and tin spawn" lookup) is untouched; that is Dave's call.
- Item catalog: no additions, renames or removals.

## Checks
- `src/worldgen/tools/test_copper_rocks.gd`: copper land vs river density, none in deep water, sizes, small ones loose and picked up by hand (and stay taken), grades, key ranges, same layout every time, mountain-foot boulders only at the foot, geology outcrops graded, a richer rock gives more copper, the meshes and looks; both ores along a river on the coastal plain with no body near, more and bigger by the same river under the mountains, graded; very many over a body of their own ore, not of the other; same every time.
- `tools/ore_rock_view.gd` (with `tools/shot_node.gd`): picture of both rocks at their real sizes and the loose ores, with a 14 cm pen, on Dave's PC.
- `tools/tin_stone_view.gd` (with `tools/shot_node.gd`, `--height=0.12 --pitch=-30`): close-up of the glassy loose Tin ore alone beside the pen.
