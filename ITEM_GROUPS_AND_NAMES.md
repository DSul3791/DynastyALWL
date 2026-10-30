# Item groups and names: DynastyALWL

> Status 2026-10-30: Parts 1 to 12 are the grouping with Dave's answers recorded; PART B at the end holds Sal's autonomous decisions (Dave approved Sal deciding). Dave can overrule any line.

Prepared by Sal, 2026-10-30. DRAFT for Dave's decision. Nothing here changes any data table.

## How to read this

- **Source:** `Items_in_other_games_Analysis.md` (the "analysis") plus our `data/items/items.json` ("ours", numbers are item numbers) and `docs/mirror/design/ITEM_TRIM_LIST.md` (Tyler's proposals, not yet approved).
- **Flag after a name:** none = the analysis marks the row C (sub-agent says it read it; "likely", not proof). `*` = the analysis marks it U (unconfirmed). Names are as the analysis lists them, sometimes shortened by me; a few rows group several items under one name.
- **Weak coverage:** Atlas, Aska, Medieval Engineers, Medieval Dynasty, Farming Simulator, Space Engineers and Astroneer are thin; Rust is a sample; The Forest, Don't Starve, Vintage Story, Valheim and No Man's Sky are partial. A game missing from a group may simply not have been catalogued. Absence is not evidence.
- **Not used for grouping:** sci-fi, electronics, nuclear, spaceship, magic and Tek-tier items (Satisfactory/NMS/Space Engineers/Astroneer/Ark Tek/Dragonwilds magic). They are listed in the closing "Excluded" section so nothing is hidden.
- **Tier:** where the analysis gives a stage I quote it; otherwise I use our own ladder: T0 hand-gathered (no tool), T1 stone/wood/bone, T2 copper/bronze era, T3 iron, T4 steel. (Our tables have iron and steel ingots and pickaxes today; copper/tin/bronze appear only as coins and in the resources table. REC: confirm the metal ladder with Dave.)
- **REC** = my recommendation only. "Alt" = other names that would also suit a medieval setting. Where I name a medieval term I use ordinary English words; I have not checked their historical accuracy beyond common usage, and Dave should veto any he dislikes.
- **Standing rulings I am keeping to** (from ITEM_TRIM_LIST.md, which records Dave's words): (CORRECTED 2026-10-30: Dave did NOT mean benches are only for weapons and tools. Benches are for crafting; some things make sense by hand and others at a work station, decided item by item.) Tailoring by hand, as Tyler recorded; wooden bowl, driftwood and hand saw stay; one tool per material, not per size.

---

## 1. Raw materials

| Group | Games and exact names | Function | Tier | Ours | REC name / function |
|---|---|---|---|---|---|
| Wood (log) | Ark Wood; Atlas Wood (species list); 7DtD Wood; Rust Wood*; Dragonwilds logs (per tree); Conan Wood; MD Logs; Forest Log; Valheim wood types | Basic building/fuel; cut from trees | T0/T1 | Log 4; species logs 100,106,109,112,124,148,172 | REC **Log**, species remembered on the item (matches Tyler group C). Alt: Timber (for cut/large pieces). |
| Cut wood (board) | Ark none*; Atlas none; Conan Shaped Wood, Boards via bench; DS Boards; Valheim Fine Wood*; Minecraft planks (cosmetic per species) | Sawn board for building and crafting | T1-T2 | Lumber 27, Rough plank 226, Fine board 227 | REC **Lumber** (rough sawn) and **Fine board** (finished). Retire Rough plank into Lumber (Tyler C). Alt: Plank. |
| Beam | Ark Wood set; Conan Shaped Wood*; Valheim Log Beam (building) | Structural member | T2 | beams per species 102,108,111,114,126,150,174 | REC single **Beam**. |
| Stick / branch | Ark none; Conan Branch; MD Sticks; Forest Stick; Aska none | Light wood, tool/fire fuel | T0 | Stick 2 | REC **Stick**. |
| Stone | Ark Stone; Atlas Stone (types); 7DtD Small Stone; Rust Stones*; MD Stone; Forest Rock; Conan Stone | Hand-gathered rock | T0 | Stone 1 | REC **Stone**. Alt: Rock. |
| Flint (DECIDED: a type of Stone) | Ark Flint; Atlas Flint; Valheim Flint (axe/knife/spear names) | Sharp stone for edges and sparks | T0/T1 | none as item (Stone knife 11) | REC decide whether flint is separate from Stone: the analysis shows three games do. Question Q1. |
| Plant fibre | Ark Fiber; Atlas Fibers; 7DtD Plant Fibers; Conan Plant Fiber; MD Straw; Forest none | Cordage base, cloth early | T0 | Plant fibre 3 | REC **Plant fibre**. |
| Cordage | Conan Twine, Rope*, Fiber Bindings*; Rust Rope; Forest Rope; DS Rope*; VS none | Binding material | T0/T1 | Twine 5, Rope 44 | REC keep **Twine** (thin) and **Rope** (thick). |
| Hide / leather | Ark Hide; Atlas Hide (Leather, Pelt, Skin...); 7DtD Leather; Rust Leather*; Conan Hide, Leather, Thick Hide, Thick Leather; Forest Deer/Boar Skin; MD Leather | Animal skin, raw and tanned | T0-T2 | Hide 43 | DECIDED (Dave): **Hide** (raw), **Leather** (tanned) and potentially **Heavy leather** (Conan Thick Leather). Open: tannery station (Q2). Tannery appears in Atlas* and Conan*. |
| Fur / wool | Ark Pelt, Wool; Atlas Hide (Pelt); MD Wool; Forest Rabbit Fur | Cold-weather material | T1-T2 | none | gap candidate (list at end). |
| Bone | Ark none (Keratin/Chitin); Atlas Keratinoid (Bone); 7DtD Bone; Conan Bone; Forest Bone; Aska none | Tool/needle/arrow material | T0 | Bone 48 | REC **Bone**. |
| Sinew, fat, feather | 7DtD/MD Feather; Forest Feather; Ark none | Cordage, fletching, tallow | T0 | Sinew 70, Animal fat 71, Feather 72 | REC keep. |
| Coal / charcoal | Ark Charcoal, Atlas Coal, 7DtD Coal, Aska Charcoal, Valheim Coal (charcoal) | Fuel and smelting | T1-T2 | not in item list (resources table has coal 1) | REC **Charcoal** (made) and **Coal** (mined) as separate names. |
| Clay / sand / gravel / soil | Ark Clay*, Sand; 7DtD Clay Soil, Crushed Sand; MD Clay; Astroneer Clay, Soil | Ground materials, bricks, glass | T0-T2 | Clay 36, Sand 37, Gravel 38, Soil 35 | REC keep. |
| Ores and ingots | Ark Metal Ingot*; Atlas Copper/Iron/Silver/Tin/Cobalt/Iridium Ingot*; 7DtD Iron, Lead, Forged Iron, Forged Steel; Valheim Copper, Tin, Iron, Silver bars, Bronze, Black Metal, Flametal; Conan Iron Bar, Steel Bars; VS Copper, Tin, Bismuth, Zinc, Lead, Bronze, Brass; MD Copper/Tin/Bronze Bar; Aska Iron Bloom, Slag (bloom step rejected by Dave) | Smelted metal | T2-T4 | Iron ingot 31, Steel ingot 32 | REC use **X ingot** (matches ours) rather than "bar" or "bloom". Add Copper, Tin, Bronze ingots if Dave confirms the copper/bronze era (Q3). Alt: Bloom for raw iron before refining (Aska, VS). |
| Nails, hinges | 7DtD Nails; Valheim Bronze/Iron Nails; Conan Iron Reinforcement | Metal fixings | T2-T3 | Nails 228, Hinges 232 | REC keep. |
| Brick, mortar, cement | Conan Hardened Brick, Stone Consolidant; 7DtD Cement, Cobblestone; Ark Cementing Paste* | Masonry | T2 | Brick 209, Mortar 210, Stone block 208, Cobblestone 229 | REC keep Brick, Mortar, Stone block; merge Cobblestone into Stone block (Tyler D). |
| Tar / resin | Conan Tar; Ark Resin; Astroneer Resin | Waterproofing, torches | T1-T2 | Tar 231 | REC keep Tar only if a use is built (Tyler: hold). |
| Kindling (NEW, Dave idea) | none of the sources list it as an item; Forest/DS use sticks and leaves as fire fuel | Small fuel that starts fires; dropped as a small amount when cutting or processing trees and tree by-products | T0 | none | REC **Kindling**; species remembered on the item if tree-type flame effects are adopted. Note: Tyler D merges Softwood firewood into Firewood; tree-type flame effects would argue for keeping species on the item (still one item number). |
| Fuel | Ark none; Rust Low Grade Fuel*; Satisfactory Fuel | Burnable | - | Firewood 26 | REC **Firewood**. |

## 1b. Stones: sizes, types and fire (Dave's direction 2026-10-30; sizes and types are REC, to confirm)

**Dave's rule:** there are many real kinds of stone with different jobs, and size matters. Keep it simple and interesting for the average gamer, with a hint of education.

**Sizes (REC, a ladder the player can read at a glance):**

| Size | Meaning in the game (REC) | Ours today |
|---|---|---|
| Pebble | small round stone, smaller than a hand | none |
| Stone | the classic hand-sized stone, smooth or rough | Stone 1 (1 kg per stone in boulders.json) |
| Rock | larger, heavier to carry | Rock pile 235 is a placeable, not a rock item |
| Large rock | bigger still, likely a two-hand carry or a placed block | none |
| Boulder | huge, various sizes, not carried; broken into stones with a pick | data/items/boulders.json (Dave 2026-10-21) |

I could not confirm formal geology size names on the web (the search returned nothing on the Wentworth scale), so real-world cut-offs for pebble, cobble and boulder are NOT checked. Use the game's own sizes above unless Dave wants real ranges.

**Types by job (REC; real facts are sourced, the game names are mine):**

| Type | Job | Real-world support |
|---|---|---|
| Plain stone (smooth or rough) | building, hammer, the ring around a fire | none needed |
| Flint (DECIDED: its own stone item, common near rivers) | strike sparks; shapes into edges for knives, spear and arrow heads | Flint is a cryptocrystalline quartz and a variety of chert; flint, chert and obsidian break with a curved "conchoidal" fracture, giving sharp edges, which is why they are the usual knapping stones ([Conchoidal fracture](https://en.wikipedia-on-ipfs.org/wiki/Conchoidal_fracture), [Flint knapping](https://outdoors.nordling.de/area/flint-knapping/)) |
| Chert | same as flint, a second tool stone | same sources |
| Obsidian (DECIDED IN, mid tier) | very sharp glassy tool and weapon stone, jewellery, possible magic component (Dave); brittle | same sources; our rocks table has basalt and tuff but no obsidian |
| Pyrite (or marcasite) | historic spark-maker used with flint before steel | [Fire striker](https://en.wikipedia.org/wiki/Fire_striker): iron pyrite or marcasite was used with flint before steel. One less established wiki says its sparks are cooler and shorter than steel's; unconfirmed |

Note: `data/tables/rocks.json` is terrain geology (shale, limestone, granite, basalt, sandstone, marble, chalk, tuff and so on). The conchoidal fracture page describes flint as a chert found in chalk or marly limestone, so our chalk and limestone beds are a natural place for the world owner to put flint; Dave also wants it common by rivers.

**Obsidian plan (Dave's direction; details are REC):** found on dormant-volcano islands past the starter islands, as rocks on or just under the surface; recognised by gamers as valuable, so it is also a trade good and a reason to sail. Uses (REC): obsidian knife, spear head, arrowhead and blade (sharp, wears faster than flint); obsidian jewellery as a high-value crafted item; magic component only if a magic system exists (magic is excluded from this list so far, Q14). DECIDED uses (Dave, 2026-10-30): obsidian knives, arrows, spears, swords, jewellery and magic components, plus any good extra ideas. REC extras for Dave to pick: obsidian mirror (the web search lists mirrors as a historic use; also a natural scrying item for the magic system), ceremonial knife or ornament (listed historic use), hide scraper (Dave likes it, 2026-10-30; used to turn Hide into Leather, see Q2; flint scraper first, obsidian better) and sickle blade (general knowledge of stone-age tools, not in my search). Nothing about it is in any data table yet.

**Making fire: what is real (sourced) and a simple game version (REC):**
- Real: striking flint or chert on high-carbon steel sheds hot steel particles; they catch on char cloth or tinder; the ember is blown into flame in a tinder bundle ([Fire striker](https://en.wikipedia.org/wiki/Fire_striker), [Outdoor Life](https://www.outdoorlife.com/blogs/survivalist/survival-video-how-work-flint-and-steel/)). Steel gives hotter, more plentiful sparks than pyrite.
- I found nothing backing "two ordinary stones make sparks reliably". Dave's 8 or 9 tries for flint and stone is a game choice, not something I confirmed. The education that IS supported: the old way was flint with pyrite, and steel replaced it.
- REC ladder, one E action with three levels: (1) **Flint and stone**, about 8 or 9 tries (Dave); (2) later **Flint and steel** using a **Steel striker** item, usually about two strikes (Dave); (3) kindling plays the part of tinder so the spark takes. Steel striker is a new gap item. Pyrite (Dave likes it) is found in coal seams, black shale and mineral veins (sources: [Geology In](https://www.geologyin.com/2024/04/pyrite-properties-uses-occurrence.html), [Rockhounding.org](https://rockhounding.org/maps/specimen/pyrite); both low-to-medium reliability); in our terrain that points at the coal and shale beds in data/tables/rocks.json. REC for the world owner, not decided. Dave decides whether pyrite exists as a middle step (Q13).
- Char cloth (real tinder) is NOT recommended, to keep the game simple, unless Dave wants it.

**Leather chain (Dave's rough idea, 2026-10-30; details to be worked out later, names are his words or REC):**
1. Raw hide -> **Leather working table** (early station) -> **Processed hide**.
2. Processed hide -> **Tannery** (tubs and drying racks) -> **Rough leather**, sorted by quality.
3. Higher quality rough leather -> **Fine leather** or **Heavy leather**.
4. With iron: several layers of leather plus rivets -> **Bound leather**, then leather armour.
Open: the hide scraper may be the hand tool used at step 1. The leather working table is allowed (Dave: benches are for crafting). Also needs rivets (not in our list; we have nails 228) and a quality-sorting mechanic (Q15).

**Cooking ladder (Dave's idea, 2026-10-30; stages and names are REC, details later):** Dave enjoys Valheim's oven and wants it explored further: a basic oven, then larger clay and stone ovens (pizza-oven style), then an iron stove with an oven. Each stage holds more and/or cooks more smoothly. Lower tiers cook slower and may burn part of the food, lowering its quality rating; higher tiers cook faster and give higher quality food. Our stations today: Campfire 8, Campfire pot 254, Clay hearth 256, Oven 268. Sources: Valheim lists Cooking Station, Iron Cooking Station*, Stone Oven; Dragonwilds Stone Range, Grill; 7DtD Cooking Pot, Grill; Conan Firebowl Cauldron; VS Cooking pot (analysis rows, partly unconfirmed; I have not checked how Valheim's oven works). REC ladder: Campfire (spit/stick) -> Campfire pot -> Clay hearth -> **Clay oven** (holds more, bakes) -> **Stone oven** -> **Iron stove with oven** (alt name: Range, as in Dragonwilds "Stone Range"). Needs the quality system (Q15) for burn chance and quality.

CORRECTION (Dave, 2026-10-30): Dave described THREE ovens, not the six rungs I listed: (1) a basic oven like Valheim's, (2) larger clay and stone ovens, pizza-oven style, (3) an iron stove with an oven. My separate Clay oven and Stone oven are one rung (2). Our Oven 268 ("a brick oven, built with a hammer next to a clay hearth", items.json) IS rung 1, the basic oven (Dave confirmed 2026-10-30). NAME DECIDED (Dave): **Basic Oven**, to emphasise it is the basic one (a display rename of item 268 for later; no data changed). Missing: rung 2 (larger clay and stone ovens) and rung 3 (iron stove with oven).

**TO DO (Dave, 2026-10-30: do not forget food):** a full food pass. Crops and animal products (grain, flour, honey, yeast, eggs, milk, fruit, vegetables, berries, meats) to dishes: breads, cakes, jams and compotes, soups, stews, dumplings, meat meals with a protein effect, drinks and spirits; recipe tiers by ingredient count (simple 1 to 2, mid 2 to 3 with oven or pot, high 3 to 4) and effect strength and duration per tier. Sources in the analysis: Valheim (about 45 dishes), Atlas (food, drink, medicine, berries, herbs), Dragonwilds, 7DtD, Ark, Don't Starve crock pot, NMS cooked food, Minecraft. Our existing dishes: items 15, 175-191, 273-275 (and the teas 52, 57-59).

## 2. Hand tools (gathering)

| Group | Games and exact names | Function | Tier | Ours | REC |
|---|---|---|---|---|---|
| Axe (wood) | Ark Stone Hatchet*, Metal Hatchet*; Atlas Stone/Metal Hatchet; Rust Stone Hatchet; 7DtD Stone Axe, Iron Fireaxe*; Dragonwilds Stone Logging Axe*, "Logging Axes Bronze-Rune"*; Valheim Stone Axe, Flint Axe, Bronze/Iron Axe; Conan Stone/Iron/Steel Hatchet*; Forest Crafted Axe; MD Stone axe; DS Axe; VS Axe; Aska Iron Axe | Fell trees; also weak weapon | T1 stone, T3 iron | Stone axe 6 (no iron/steel axe in list) | REC **Axe**, with material in the name (Stone axe, Iron axe...). Add Iron axe and Steel axe (gap, see end). Alt: Hatchet for the small one-handed form. |
| Pickaxe | Ark Stone Pick*, Metal Pick*; Atlas Stone/Metal Pick; Rust Pickaxe; 7DtD Iron/Steel Pickaxe*; Dragonwilds Stone/Bone/Bronze...Rune Pickaxe; Conan Stone/Iron/Steel Pick*; Minecraft pickaxe (wooden to netherite); MD Stone pickaxe; DS Pickaxe; VS Pickaxe | Mine rock and ore | T1-T4 | Iron pickaxe 33, Steel pickaxe 34 (no stone pickaxe) | REC **Pickaxe**; add Stone pickaxe for T1 (gap). Alt: Pick. |
| Shovel / spade | 7DtD Stone/Iron/Steel Shovel*; Minecraft shovel; Dragonwilds Spades*; Valheim Shovel*; DS Shovel; VS Shovel; Atlas Shovel* | Dig soil, sand, gravel | T1-T4 | Wooden 19, Stone 45, Iron 46, Steel 47 + sizes 213-220 | REC **Spade** (our word), one per material; sizes merged (Tyler A). Alt: Shovel. |
| Hoe | Minecraft hoe; MD Wooden hoe, Copper/Bronze hoe; Dragonwilds none; VS Hoe | Till farmland | T1-T4 | Hoes 221-224 | REC keep. |
| Knife | Valheim Flint Knife, Copper Knife; 7DtD Bone Knife*, Hunting Knife*; Forest none; MD Stone knife; VS Knife; Conan none | Skin, cut, carve; weak weapon | T1-T3 | Stone knife 11 | REC **Knife**; add Iron knife later. |
| Hammer | Rust Hammer; Valheim Hammer*; 7DtD Claw Hammer*; DS Hammer; VS Hammer; MD Wooden hammer; Conan Repair Hammer*; Atlas Repair Hammer*; Aska Hammer | Build/repair, also smithing tool | T1-T3 | Wooden hammer 247, Stone hammer 244 | REC one **Hammer** line (Tyler B). Smithing hammer is a different job: REC **Smith's hammer** (VS lists a separate Helve Hammer; I have not checked what it does). |
| Saw | VS Saw; Dragonwilds none; 7DtD none | Cut boards | T2+ | Hand saw 245, Saw blades 238 | REC keep (Dave ruling). |
| Sickle / scythe | Ark Metal Sickle*; Atlas Metal Sickle*; Valheim Scythe; VS Scythe, Cleaver; Dragonwilds Iron Secateurs* | Harvest crops/plants | T2-T3 | none | gap candidate. Alt: Reaping hook. |
| Shears | Atlas Scissors*; Minecraft Shears; DS Shears; MD Bronze shearing scissors; VS Shears | Shear wool | T2 | none | gap candidate if sheep exist. Alt: Sheep shears. |
| Fishing rod | Ark none; Atlas Fishing Rod*; Rust Fishing Rod; Minecraft Fishing rod; Valheim Fishing Rod; DS Fishing Rod; Dragonwilds Fishing Rods (Ash, Oak, Willow...) | Catch fish | T1 | Fishing rod 75 | REC keep. |
| Fishing net | Dragonwilds Fishing Nets (Coarse, Wool, Fine); Atlas none | Catch fish passively | T1-T2 | Shore net 260 | REC keep. |
| Fire starter | Minecraft Flint and steel; VS Firestarter; Forest Lighter; Atlas none | Light fires | T0-T2 | not an item (campfire 8) | DECIDED (Dave): no fire-starter item; lighting is a character action using flint and stone (Q4). |
| Prospecting | VS Prospecting Pick, Wooden Pan; DS Gold Pan; 7DtD none | Find ore | T2 | none | gap candidate. |
| Climbing | Ark Climbing Pick*; Atlas Grappling Hook*, Zipline*; Satisfactory Zipline/Jetpack; Forest Climbing Axe | Scale cliffs | T3 | none (Dave noted climb/mining tools) | Q5. |


## 3. Weapons

| Group | Games and exact names | Function | Tier | Ours | REC |
|---|---|---|---|---|---|
| Club | Ark Wooden Club*; Valheim Club; Conan Stone Club*; 7DtD Wooden Club*; Dragonwilds Stone Club, Bone Club; Forest Crafted Club; VS Club | Early blunt melee | T1 | none | REC **Club**; add (gap). |
| Spear | Ark Spear*, Pike*; Atlas Spear; Valheim Flint/Bronze/Iron... Spear; 7DtD Stone Spear*, Iron/Steel Spear*; Rust Wooden Spear; Forest Weak/Upgraded Spear; DS Spear; VS Spear (stone to steel); MD Wooden spear, Copper/Bronze spear; Conan Javelin*, Stygian Bronze Spear*, Iron Pike* | Reach melee, thrown, hunting | T1-T4 | Wooden spear 10, Stone spear 7 | REC **Spear** by material; **Javelin** (Conan*) as the throwing one only if thrown/melee are split (Q6). |
| Knife / dagger | Valheim Flint/Copper Knife; Dragonwilds Stone/Bone/Bronze... Dagger; Conan Stone Dagger*, Iron Poniard*; Atlas none | Short melee | T1-T3 | Knife is a tool | REC **Dagger** as the weapon version, **Knife** stays the tool. |
| Sword | Ark Sword*; Atlas Sword; Valheim Bronze/Iron/Silver Sword; 7DtD none; Dragonwilds Bronze...Rune Sword; Conan Stone Sword*, Iron Broadsword*, Longsword*; Minecraft Swords; VS Falx, Blackguard shortsword; MD none | One-handed blade | T2-T4 | none | gap candidate (list at end). Alt: Arming sword. |
| Mace / hammer-weapon | Atlas Mace; Valheim Bronze/Iron Mace; Dragonwilds Bronze...Rune Mace; Conan Iron Warhammer*; Minecraft Mace | Armour-breaking blunt melee | T2-T3 | none | REC **Mace**. |
| Axe-weapon | Valheim Bronze/Iron Axe, Battleaxe; Dragonwilds Greataxe line; Conan Cimmerian Battle-Axe*; Conan Throwing Axe; Minecraft Axes | Chop weapon | T1-T4 | tool only | REC the axe tool doubles as weak weapon; **Battleaxe** later. |
| Two-handed / polearm | Valheim Atgeir; Dragonwilds Greatsword, Warhammer; Conan Iron Pike*; Ark Pike*; DS Halberd; Atlas none | Heavy reach melee | T3+ | none | later; Alt: Halberd (DS), Pike. |
| Bow | Ark Bow*; Atlas Bow; Valheim Crude Bow, Finewood Bow, Huntsman Bow; 7DtD Primitive Bow, Wooden Bow*; Rust Hunting Bow; Forest Crafted Bow; Conan Hunting Bow, Hyrkanian Bow; MD Bow; VS Crude/Simple bow, Longbow, Recurve bow; Dragonwilds Shortbow, Longbow | Ranged weapon | T1-T3 | Wooden bow 269 | REC keep **Wooden bow**; **Longbow** as a later tier. |
| Crossbow | Ark Crossbow*; 7DtD Iron Crossbow*; Conan Crossbow; Dragonwilds Bronze...Rune Crossbow; Minecraft Crossbow; MD bolts; Valheim Arbalest* | Mechanical ranged weapon | T3+ | none | gap candidate. |
| Sling | Ark Slingshot*; Forest Slingshot; VS Sling | Thrown stone | T0-T1 | none | gap candidate (cheap, T0). |
| Thrown / trap weapon | Ark Bola*, Boomerang*; Atlas Bola, Throwing Knife; DS Boomerang; Conan Throwing Axe | Short-range throw | - | none | skip unless Dave wants. |
| Firearms, explosives, siege | Ark/Atlas/7DtD/Rust/Forest guns; Atlas Cannon, Ballista, Catapult; Conan siege none; ME siege machines | Gunpowder or siege | late | none | Q7: gunpowder era in or out? Medieval siege (ballista, catapult, ram) is a candidate. |

## 4. Ammunition

| Group | Games and names | Ours | REC |
|---|---|---|---|
| Arrows by head | Ark Stone Arrow*, Flame Arrow*, Metal Arrow*; Valheim Wood, Flinthead, Bronzehead, Ironhead, Fire, Poison Arrow; 7DtD Stone/Iron/Steel Arrow, Flaming, Exploding; Conan Flinthead, Razor, Fire, Ironhead, Snake Arrows; Dragonwilds Stone Arrow*, Bronze...Mithril, Fire/Poison/Barbed variants; VS Arrow crude/flint/obsidian/bone/copper... | Wooden arrow 270, Stone arrow 271 | REC **<Head> arrow** (Flint/Bone/Iron arrow...). Fire arrow later. |
| Bolts | 7DtD Stone/Iron/Steel Crossbow Bolt; Dragonwilds Bolts; MD bolt; Minecraft none | none | with crossbow. |
| Quiver | Forest Quiver; VS none | Quiver 272 | keep. |
| Sling stones | none confirmed | none | with sling. |

## 5. Armour, clothing and shields

| Group | Games and names | Tier | Ours | REC |
|---|---|---|---|---|
| Plant / cloth wear | Ark Cloth Armor; Atlas Cloth set; Conan Coarse Tunic/Handwraps/Leggings/Footwraps; DS Grass Suit; Dragonwilds Adventurer's Tunic; VS none | T0-T1 | Grass skirt 60, Grass cloak 61, Fibre sandals 62 | REC keep. Alt: Tunic as woven plant tunic (Conan "Coarse Tunic"). |
| Hide / leather wear | Ark Hide Armor; Atlas Hide set; Valheim Leather Armor; 7DtD Primitive set; Conan Light set; Dragonwilds Leather set; VS Leather jerkin/armor, Hide armor | T1 | Hide cloak 63, boots 64, hood 65, mittens 66, leggings 67 | REC keep; no chest piece besides cloak (gap: **Hide jerkin** / Leather jerkin; VS name). |
| Padded | VS Gambeson; Valheim Padded Armor; Dragonwilds Studded Leather set | T2 | none | REC **Gambeson** (VS name, also the period term). |
| Mail / scale | VS Chain armor, Scale armor, Lamellar; Valheim Iron Armor; Dragonwilds Bronze/Iron/Steel set; Conan Medium set; Ark Flak* | T3 | none | REC **Mail shirt** / **Mail coif**, **Scale armour** later. |
| Plate | VS Plate armor, Brigandine; Conan Heavy set; Atlas Plate set; Dragonwilds Rune set | T4 | none | later. |
| Fur / cold | Ark Fur Armor; Atlas Fur set; Valheim Wolf Armor; Forest Snow Shoes; DS Winter Hat | T2 | none | gap candidate (cold-biome gear). |
| Shields | Ark Wooden/Metal Shield*; Valheim Wood Shield, Wood Tower Shield, Bronze Buckler; Conan Wood Shield, Wood Targe, Iron Targe, Steel Heater Shield; Dragonwilds Wooden/Leather/Bronze... Shield; Minecraft Shield | T1-T4 | none | REC **Wooden shield**, **Buckler**, **Heater shield**, **Targe** all appear in sources; keep Wooden shield + Buckler first. |
| Helmets / caps | 7DtD sets; Conan Medium Cap/Heavy Helmet; DS Battle Helm; VS (inside sets) | T2+ | Hide hood 65 | pair with armour tiers. |

## 6. Containers, bags and water

| Group | Games and names | Ours | REC |
|---|---|---|---|
| Waterskin | Ark Waterskin*; Atlas Waterskin*; Conan Sealed Waterskin*; Forest Waterskin | Waterskin 42 | keep. |
| Bucket | Atlas Bucket*; 7DtD Bucket*; Minecraft Bucket; VS Wooden bucket | Bucket 41 | keep. |
| Pot / jar / jug | Atlas Water Jar*; VS Crock, Storage vessel, Jug; Forest Old Pot | Clay pot 40 | keep Clay pot; Jug later (water/ale). |
| Bowl | VS Bowl | Wooden bowl 39 | keep (Dave). |
| Backpack / bag | Ark none; Forest Pouch, Stick Bag, Rock Bag; VS Hand basket, Linen sack, Backpack, Mining bag; DS Backpack; MD Simple bag; Dragonwilds Lumber Backpack | Backpack 50 | keep Backpack; Basket as an early step (VS Hand basket) is a candidate. |
| Chest / box | Ark Storage Box; Atlas Large Storage Box; 7DtD Wood Storage Crate; Rust Wood Storage Box; Valheim chests; VS Reed chest, Chest, Trunk, Crate; Dragonwilds Ash Chest; DS Chest | Woven chest 22, Plank chest 28 | keep. |
| Barrel / cask | Atlas Barrel; Ark Storage Barrel*; VS Barrel | none | gap candidate (liquids, salted food). |
| Rack / shelf | VS Tool rack, Shelf, Bookshelf; Ark Wooden Cabinet | Tool rack 81 | keep. |
| Quiver | see ammo | 272 | |

*Sections 3-6 saved. Sections 7 onward follow below.*

## 7. Food, drink and medicine

| Group | Games and names | Ours | REC |
|---|---|---|---|
| Raw meat / fish | Ark Raw Meat, Raw Fish, Raw Prime Meat; Atlas Animal Meat, Fish Meat; Valheim raw meats; Minecraft Raw meat, raw fish | Raw meat 68, Trout 76, Perch 77, Carp 78, Pike 79 | keep. |
| Cooked meat / fish | Ark Cooked Meat; Atlas Cooked Animal Meat; 7DtD Grilled/Charred/Boiled Meat; Dragonwilds Grilled Trout; Valheim cooked meats | Roast meat 69, Roast fish 80 | keep. |
| Preserved food | Atlas Salted Fish*, Salted Meat*, Hardtack*; Ark Meat Jerky*; Valheim Boar/Wolf Jerky; Minecraft Dried kelp; Ark Preserving Salt*; DS Jerky, Drying Rack | Smoked fish 185, Fruit leather 184 | REC **Jerky**, **Salted meat**, **Hardtack** (Atlas*) are the common forms; Salt is a gap (see end). |
| Stew / soup | Valheim Carrot Soup, Deer Stew, Turnip Stew; 7DtD Vegetable Stew*; Dragonwilds Meat Stew, Vegetable Soup; Minecraft Mushroom stew, Rabbit stew; Atlas Celery Soup; Ark Calien Soup | Campfire Stew 15, Hunter's 186, Forager's 187, Fish stew 188, Hearty pottage 190 | keep per Tyler E; serve in wooden bowl (Dave). |
| Bread / baked | Valheim Bread; 7DtD Pumpkin Bread; Minecraft Bread, Cookie; Atlas Jack Buns; NMS Bread | Flatbread 273, Trail bread 189, Honey loaf 274 | keep. Needs flour (VS Quern, FS Grain mill): gap. |
| Pies | Valheim Lox Meat Pie, Piquant Pie; Atlas Pork Pie; Minecraft Pumpkin pie; VS pie | none | later. |
| Tea / brew | Ark Medical Brew*; 7DtD Honey Tea, Goldenrod Tea; Atlas Berry Tea; Valheim Mead; Atlas Ale; 7DtD Beer; Dragonwilds Brewing Cauldron* | Teas 52, 57, 58, 59 | keep; Ale/mead: Q8. |
| Fruit, nuts, berries | Ark berry line; Atlas berries; Forest Berries; Minecraft Sweet berries | Berry compote 175, Nut paste 176, Baked apples 179 | keep. |
| Medical | Ark Narcotic*, Stimulant*; 7DtD Bandage, First Aid Kit; Rust Bandage; Forest Meds*; ME Bandages; DS Healing Salve | Herb poultice 16, Herb bandage 17, Medicine 56 | keep poultice/bandage; **Salve** (DS) is an alt name for an ointment. Cut Medicine 56 (Tyler E). |

## 8. Crafting stations (Dave: benches are for crafting; hand-crafting vs station decided item by item)

| Group | Games and names | Job | Ours | REC |
|---|---|---|---|---|
| Basic bench | Valheim Workbench*; Rust Workbench Level 1-3; 7DtD Workbench; Conan Woodworking Bench*; Minecraft Crafting table; DS Science Machine | Tool/weapon crafting, gates tiers | Log workbench 85, Woodworking table 242, Tool rack 81 | keep; "Log workbench" is our T1. |
| Forge / furnace | Valheim Forge, Smelter, Black Forge; 7DtD Forge; Rust Furnace; Conan Furnace*; Aska Furnace, Forge; VS Forge, Bloomery, Crucible; Minecraft Furnace, Blast furnace; Atlas Forge* | Smelt and work metal | Basic/Medium/Large/Master Forge 87-95 | keep four tiers; NO bloomery step (Dave). |
| Anvil | 7DtD Anvil; VS Anvil (copper/bronze; iron/steel); Minecraft Anvil; Aska Wood Anvil | Shape hot metal | none | gap candidate. |
| Cooking | Valheim Cooking Station; Ark Cooking Pot; 7DtD Cooking Pot, Grill; Conan Firebowl Cauldron; VS Cooking pot; Dragonwilds Stone Range, Grill; DS Crock Pot | Cook meals | Campfire 8, Campfire pot 254, Clay hearth 256, Oven 268, Chopping block 25 | keep. |
| Tannery | Atlas Tannery*; Conan Tannery* | Hide to leather | none | Q2. |
| Loom / spinning | Atlas Loom*; Valheim Spinning Wheel*, Standing Loom* | Thread and cloth | none | Dave said tailoring is by hand; skip unless wanted. |
| Sawmill | FS Sawmill | Boards from logs | Sawmill 240 | keep. |
| Kiln | Valheim Charcoal Kiln*; VS Pit kiln | Charcoal and pottery | Clay hearth 256 | check whether Clay hearth covers pottery firing. |
| Mill / quern | VS Quern; FS Grain mill | Grind grain | none | gap candidate. |
| Research bench | Rust Research Table*; ME Research Table | Unlock recipes | none | our design is learning by doing; skip. |

## 9. Building and furniture

| Group | Games and names | Ours | REC |
|---|---|---|---|
| Foundation, floor, wall, roof, door, window by material | Ark Thatch/Wood/Stone/Adobe/Metal sets; Conan Sandstone/Stonebrick/Reinforced sets; Dragonwilds Ash Palisades and building pieces; Valheim piece sets; 7DtD Wood/Cobblestone/Building Block | Wall 192, Floor 194, Roof 196, Foundation 198, Doorway 200, Window wall 202, Thatch set 252-266 | keep; thatch, wood, stone is the common ladder. |
| Stairs / pillar | Conan Stairs, Pillar | Ladder 211, Timber prop 204 | stairs: gap candidate. |
| Gate / fence / palisade | Ark Behemoth Gate; Conan Fence, Gate; Dragonwilds Ash Palisades; DS Stone/Wood Wall; 7DtD Barbed Wire Fence | none | gap candidate (defence). |
| Door | Rust Wooden Door; 7DtD Wood Door*; Conan Wooden Door | Doorway only | gap candidate (hung door). |
| Bed | Ark Simple Bed; Rust Bed, Sleeping Bag; 7DtD Bedroll; Dragonwilds Bed Roll; Conan Fiber Bedroll*; VS Bed (hay, wooden); ME Bed; DS Tent | Rough bed 250 | keep; **Bedroll** as the portable early one (4 games). |
| Table / chair | Atlas Wood Table, Wood Chair | Camp bench 73 (Tyler: merge) | furniture scope: Q9. |
| Sign | Atlas Wooden Sign; Ark Metal Sign | none | low priority. |

## 10. Light, traps, farming, transport

| Group | Games and names | Ours | REC |
|---|---|---|---|
| Torch | Ark, Rust, Atlas, Conan, Forest, DS, VS, MD Torch | Basic torch 12 | keep. |
| Lantern / candle / lamp | Atlas Lantern*, Belt Oil Lantern*; Conan Candle Stub*; VS Oil lamp, Candle, Small/Large lantern; DS Lantern; Valheim Dvergr Lantern | none | gap candidate (candle earlier, lantern later). |
| Campfire | all | Campfire 8 | keep. |
| Snare / trap | Forest Dead Fall Trap*, Noose Trap*; DS Trap, Bird Trap, Tooth Trap; Ark Bear Trap*; 7DtD Wood Spikes* | Snare 276 | keep Snare; bear trap and spikes later. |
| Seeds / crops | Ark berries; Atlas Wheat, Maize, Turnip, Potato; Minecraft Wheat, Carrot; Dragonwilds seeds; MD Field; 7DtD Farm Plot | Seeds 9, Roots 18 | farming items mostly missing: Q10. |
| Compost / fertiliser | Ark Re-Fertilizer*; Atlas Fertilizer*; Dragonwilds Compost; FS Manure, Slurry; MD Manure | none | gap candidate. |
| Beehive / animals | Ark Bee Hive; 7DtD Apiary, Chicken Run; DS Bee Box, Rabbit Hutch; Dragonwilds Livestock* | none | later. |
| Boats | Atlas ships; Valheim Raft, Karve, Longship; DS Log Raft, Row Boat; VS Raft; Minecraft Boat | none | Q11. |
| Cart / mount | Valheim Cart*; 7DtD Bicycle; Minecraft Saddle; Ark saddles; MD Donkey | none | later. |
| Money | 7DtD Old Cash*; Space Engineers Space Credits | Coins 96-99 | keep. |

## 12. Farming items (draft for Dave, 2026-10-30; REC unless marked)

**Dave's direction:** crop to food, simple, a little education. Grow grain, mill it at a windmill, mix flour with water, honey and yeast for bread; eggs and milk for cakes; fruit, vegetables and berries for jams and compotes; vegetables and water for soups; flour for stews and dumplings; meat for better protein.

**What we have:** Seeds 9, Roots 18 (item_uses says the seed bundle is "planted in a farm patch"), hoes 221-224, spades, Bucket 41, Waterskin 42. The flora table has wild plants only (flax, wild carrot, wild garlic, hazel, wild apple, pear, cherry, chestnut, walnut, many berries and herbs, reeds, thatch grass) and no cultivated grain or vegetables.

| Group | Games and names (analysis rows, flag as before) | Function | REC for us |
|---|---|---|---|
| Grain crops | Atlas Wheat, Maize, Rice; Minecraft Wheat; FS Wheat, Barley, Oats; ME Wheat; VS crops; MD (rye and wheat threshed in a barn) | Flour, bread, ale | **Wheat, Barley, Oats, Rye**. Maize and rice only if we have New World or tropical islands (Q17). |
| Fibre crop | Dragonwilds flax seeds; ME flax straw -> thread; our flora has wild flax | Thread, cloth | **Flax** as a crop (and linen thread later). |
| Roots and veg | Atlas Carrot, Celery, Garlic, Onion, Potato, Turnip; Minecraft Carrot, Potato, Beetroot; Dragonwilds cabbage, onion seeds; FS Red Beet, Carrots, Parsnips | Soups, stews, roast roots | **Carrot, Turnip, Onion, Garlic, Cabbage, Parsnip, Beetroot**. **Potato** is a New World crop (general knowledge, not in my search): educational hook, or leave out of a medieval setting (Q17). |
| Legumes | Atlas Beans, Chickpea | Protein, pottage | **Peas, Beans**. |
| Squash and gourd | Minecraft Melon, Pumpkin; ME Pumpkin; 7DtD Pumpkin Bread | Soups, pies | **Pumpkin** (later). |
| Fruit and berries | Atlas many berries; Minecraft Sweet berries; our flora has wild berries, apple, pear, cherry | Jams, compotes, drinks | gather from wild and orchard trees; no crop item needed at first. |
| Herbs | Atlas Parsley, Mint, Rosemary, Thyme; our flora has many | Flavour, medicine | gather wild; a herb garden plot later. |
| Seeds | Dragonwilds seeds per crop; Minecraft seeds; 7DtD seeds | Plant a crop | **one seed item per crop** (Wheat seeds...) replaces generic Seeds 9 (Q17). |
| Plot / field | Dragonwilds Ash Farming Plot; 7DtD Farm Plot; Forest Small Garden*; MD Field; Ark Small Crop Plot | Place where crops grow | **Farm plot** (placeable) or tilled ground by the hoe (Q17). |
| Tools | Valheim Cultivator, Hoe; Atlas Metal Sickle*; Dragonwilds Iron Secateurs*; VS Scythe, Hoe; MD hoe | Till, plant, harvest | Hoe exists; **Scythe** for grain (Tyler keeps scythe, cuts sickle: Dave to decide). Bucket/Waterskin for watering. |
| Compost / fertiliser | Dragonwilds Compost Bin, Compost; Atlas Fertilizer*; Ark Re-Fertilizer*; MD Manure; FS Manure, Slurry | Better yield | **Compost bin** and **Compost**; **Manure** from animals. Rotten food 55 already says "usable as compost" in Tyler's list. |
| Milling | FS Grain mill; VS Quern; Valheim none | Grain to flour | **Quern** (hand, early), **Windmill** (Dave), **Flour**. Possibly **Water mill** (our Water wheel 239 exists). |
| Baking inputs | Dave: water, honey, yeast; FS Bakery (flour, sugar, milk, eggs, butter) | Bread, cake | **Yeast** (new; real source: baking and brewing, not researched), **Honey**, **Eggs**, **Milk**, **Butter**. |
| Animal husbandry | 7DtD Chicken Run, Apiary; Ark Bee Hive; DS Bee Box, Rabbit Hutch; MD Hen/Goose houses; FS Dairy | Eggs, milk, honey, wool | **Chicken coop**, **Beehive**, later cow/sheep pens; wool needs shears (Tyler cut shears: revisit). |
| Preserving | Atlas Salted Meat*, Preserving Salt*; MD Salt; Valheim jerky; DS Drying Rack | Keep food longer | **Salt**, **Drying rack** (also leather chain), **Barrel**. |

Questions: Q17 how strictly medieval Europe are the crops (potato, maize, rice); one seed item per crop; plot item versus hoed ground; keep sickle or only scythe; which animals first.

## 11. Excluded from grouping (so nothing is hidden)
Ark Tek/Genesis gear, kibble, eggs, creature saddles, artifacts; Satisfactory production parts, nuclear and packaged fluids; NMS starship, exosuit, exocraft, base tech; Space Engineers and Astroneer sci-fi parts; Minecraft redstone and brewing; Dragonwilds magic weapons, armour and per-skill potions (EXCLUDED FOR NOW only; Dave says a huge magic system is coming, so a separate magic-items pass is needed); Conan thralls and deity altars; Rust electrical; gunpowder-era firearms (pending Q7). Named boss/loot weapons (Valheim Dyrnwyn etc.) are not grouped.

---

## Questions for Dave
1. **DECIDED (Dave, 2026-10-30): flint is a type of stone**, not a separate item. REC for implementation: stone type remembered on the Stone item, as with wood species (to confirm with Dave if he meant otherwise).
2. **DECIDED (Dave, 2026-10-30): a tannery station IS wanted (tubs and drying racks); see the leather chain in section 1b. We have both Hide and Leather, and potentially Heavy leather** (Conan lists Thick Hide, Thick Leather). Still open: whether a tannery station does the tanning, and whether Heavy leather is in the first list.
3. **DECIDED (Dave, 2026-10-30): metals are smelted into ingots, including copper, tin and bronze before iron and steel. No bloomery step** (felt like extra for its own sake in Aska); ore is smelted straight to an ingot in a forge. Alloy detail (bronze from copper and tin) to be worked out.
4. **DECIDED (Dave, 2026-10-30): the first fire is built, not an item.** Rocks make the circle, sticks are the first fuel. NEW ITEM IDEA: **Kindling**, small bits gained a little each time trees or tree by-products are cut or processed, used to start fires. POTENTIAL IDEA (not decided): firewood/kindling from different tree types gives different flame effects. FIRE RULES (Dave, 2026-10-30): a fire is crafted as an inventory item and placed with a blueprint; the sticks used as the recipe are stored in the placed campfire's own inventory as its first fuel. Pressing E on a fire lights or extinguishes it: the character sparks flint and stone a few times to light it, or stomps it out. So lighting needs no fire-starter item (flint is a stone type). DECIDED (Dave): lighting needs one Stone and one Flint in inventory; flint is its OWN stone item (many stone types with different jobs; see section 1b); flint and stone takes about 8 or 9 tries, a later flint and steel about two strikes. Flint should be a common find near rivers (a world-placement note for whoever owns rocks and gathering, not an item-table change). Open detail: does the campfire's inventory hold other fuel (firewood, kindling)?
5. **DECIDED (Dave, 2026-10-30): IN.** Climbing picks, placeable climbable ropes with anchors, and gliders to leap off mountains and fly. Tiering to be worked out.
6. **DECIDED (Dave): Javelin is its own item.** A normal spear can be thrown, but a javelin flies farther and straighter and does more damage.
7. **DECIDED (Dave): both gunpowder-era weapons and siege equipment (ballista, catapult, ram) are IN, properly tiered.** Dave's example: Atlas ballistas for fighting whales from ships. Still to do: a firearms/siege catalogue pass and tier placement (Atlas, Ark, 7DtD, Rust, Valheim have the source rows).
8. **DECIDED (Dave): yes, all kinds of drinks and spirits (ale, mead, brewing)**, giving food effects like Atlas.
9. **DECIDED (Dave): furniture is IN and should be fun and useful**: stools (sit to work and improve things), chairs (rest), big comfy benches for several friends, a throne to command a militia in a keep. Dave says the earlier "benches only for weapons and tools" rule was never his (withdrawn).
10. **DECIDED (Dave): farming from crop to food, kept simple with a little education.** Grow grain, mill it at a windmill, combine flour with water, honey and yeast for bread; add eggs and milk for cakes; fruit, vegetables and berries make jams and compotes; water plus vegetables make soups; flour makes stews and dumplings; meat gives better protein so the effects on the character change. Recipe tiers by number of ingredients: simple 1 to 2 found items, mid tier 2 to 3 (introduces oven or cook pot), high tier 3 to 4; each tier gives better qualities and longer effects. New items implied: windmill, yeast, milk, eggs, flour, honey (Honey loaf 274 and Flatbread 273 already exist in items.json).
11. **DECIDED (Dave): IN. Many types of boats and carts, with types, sizes and qualities.** Dave's cart examples (ideas only): hand cart, hay cart, large horse-drawn hay cart, lumber wagon, caravan wagon, carriage, stage coach, fine carriage. Sources in the analysis for boats: Atlas, Valheim (Raft, Karve, Longship), Don't Starve, Vintage Story, Minecraft.
13. **Pyrite: Dave likes the idea (2026-10-30)** as the middle step between flint-and-stone and flint-and-steel. Where it is found: see below. DECIDED (Dave, 2026-10-30): **obsidian is in**, a mid-tier stone: found on islands beyond the starter islands, ones with dormant volcanoes, as rocks lying on or just under the surface. Intended uses (Dave): valuable tool and weapon material, jewellery, possible magic component. Details in section 1b.
14. **DECIDED (Dave, 2026-10-30): a huge magic system is planned for later.** Obsidian can be a magic component. Open: when magic items (staves, wands, components, potions, enchanted gear) get their own catalogue pass, and which sources to use (Dragonwilds, Valheim staves and Eitr, Minecraft brewing and enchanting, Ark Element are the ones the analysis covers).
15. **Leather chain:** confirm the steps above, rivets, and how quality sorting works.
16. **DECIDED (Dave): Oven 268 is the basic oven (rung 1).** Open: names and quality details for rungs 2 and 3.
17. **Farming** (section 12): strictness of crop list (potato, maize, rice), one seed item per crop, plot item or hoed ground, sickle or scythe only, first animals.
12. **Tyler's trim list has groups A to J (not A-E). Dave asked to see them (2026-10-30); shown in chat, not yet decided.** Groups touching Dave's decisions: F (merge four forges into one), J (cuts loom and tanning rack), B (camp bench merge), I (sickle, shears).

## First thoughts on progression gaps (NOT a recommendation; for the later progression review)
Missing from ours but present in many of the other games: stone pickaxe; iron and steel axe; club; sword, mace and shield; sling; mail/gambeson/scale body armour and helmets; sickle or scythe, shears; anvil and smith's hammer; kindling (Dave idea); lantern and candle; barrel; salt and preserved foods; mill/quern and flour; stairs, gate/fence, hung doors, bedroll; compost; a copper/tin/bronze tier (our copper, silver and gold exist only as coins).

## Weaknesses of this document
Names come from a partly unconfirmed analysis; where a game column says "none" or a game is absent it may mean "not catalogued". Functions are one-line generalisations of the analysis rows, not wiki quotes. Tier is only as exact as the analysis gives. No web research was done for this draft.

---

# PART B: Sal's autonomous decisions and catalogues (2026-10-30)

Dave approved the plan and said to decide without him where possible, research online first, and make sure items **make sense, are fun and are reasonable to make**. Everything below is a DECISION BY SAL unless it says Dave. Dave can overrule any line. Web sources are quick searches of mixed quality (history sites, wikis, hobby pages); dates are approximate.

## B1. Design test every item must pass
1. **Makes sense:** a player can guess what it is and why it exists (real-world logic, with a hint of education).
2. **Fun:** it does something different from its neighbours, or gives a choice, a risk or a reward. If two items do the same job, merge them.
3. **Reasonable to make:** DAVE'S RULE (2026-10-30): three ingredients at most for normal recipes; only a really special, powerful top-tier item may use 4 or 5. So: simple tier 1 to 2 found things and no station; mid tier 2 to 3 with one station; high tier 3 with a better station; 4 to 5 only for special powerful items. This replaces the earlier 3-to-4 for high-tier food. No step exists just to add a step (Dave on Aska's bloomery).

## B2. Open questions: my decisions
| # | Decision |
|---|---|
| 3, metals | Dave: ore smelts straight to ingots. Ladder: Stone/bone/flint/obsidian (T1) -> Copper (T2a) -> Bronze, made at a forge from copper and tin ingots (T2b) -> Iron (T3) -> Steel (T4). Forge tiers stay as the gate (see F below). |
| 12, Tyler's trim list | See B3. |
| 15, quality | One simple **quality grade** on food, leather, crafted tools/weapons/armour: Poor, Common, Good, Fine, Excellent. Set by the maker's skill, the station tier and (for food) burning risk. Items-list job: only flag which items carry a grade (food, leather, weapons, armour, boats, carts). The system itself belongs to the game-systems owner. |
| 15, rivets | Add **Rivets** (iron, small): needed for bound leather and mail. Nails stay for wood. |
| 15, hide scraper | Keep both: Hide scraper is the hand tool; the Leather working table is where processed hide gets finished. |
| 16, oven names | Rung 1 **Basic Oven** (item 268). Rung 2 **Clay Oven** (one item; stone as a build material option later). Rung 3 **Iron Stove** (with oven; "Range" is an alternate name). |
| 17, crops | Core crops are medieval European (wheat, barley, rye, oats, peas, beans, cabbage, turnip, onion, leek, carrot, parsnip, flax). Potato and maize reached Europe only after 1492 (general knowledge; my search did not cover it). Decision: keep them OUT of the starter lands and offer them, with rice and similar, as **exotic crops from far islands** (trade or exploration reward). One seed item per crop. No Farm plot item: the hoe tills ground into a field (garden bed placeable later). |
| Sickle | CUT (Tyler I): the Scythe harvests grain and grass. |
| First animals | Chicken (eggs), bees (honey), then sheep (wool), goats/cows (milk), pigs. |

## B3. Tyler's trim list A to J: my decisions
| Group | Decision | Reason |
|---|---|---|
| A spade sizes | **YES** merge (one spade per material) | 12 spades for one verb is noise. |
| B | Hammer: **YES** one hammer line. Vice: **YES** merge into workbench. Camp bench: **NO, keep** (Dave: furniture is fun). Sewing needle: **NO, keep** as a bone needle (cheap, educational, used for clothes) | Fun and reasonable. |
| C wood | **YES** one Lumber, one Beam; tree type kept on the item (also feeds flame effects) | matches Dave's ideas. |
| D | Cobblestone -> Stone block **YES**; stone shingle, wooden pin **cut**; Softwood firewood/block -> Firewood/Wooden block **YES** (type kept on item); Tar **hold**; Driftwood **keep** (Dave) | |
| E | Cut Herbal tea, Medicine, Energy bar; Nut paste -> Acorn mash; Campfire Stew = plain stew; Magic tonic **hold for the magic system** | |
| F forges | **REVERSED: keep four forge tiers** | Dave builds ladders from separate stations (ovens); tiers gate bronze, iron, steel. Anvil, tongs, bellows stay forge parts, not carried items. |
| G building pieces | **YES** generic pieces with material as a variant (thatch, wood, stone, later brick) | |
| H | Hide mittens -> **Gloves** YES. Bronze coin **KEEP**: data/items/coins.json already defines 10 copper = 1 bronze, 10 bronze = 1 silver, 10 silver = 1 gold | Tyler's note contradicts the coin table. |
| I | Scythe keep; sickle cut; rake cut; **shears KEEP** (sheep are coming) | |
| J | **Loom ADDED** (flax -> thread -> linen cloth is a good education chain); tanning rack is part of the Tannery (Dave's leather chain); Kiln keep (charcoal, pottery, brick); Cooking station = the oven ladder; tongs, bellows, anvil are forge parts; defer instruments (one flute and one drum first), dice, chess, book | |

## B4. Food catalogue (Dave's farming and cooking rules)
**Effects (simple):** Hunger fill (every food), then one main effect by food group: grain/bread = Stamina; vegetables and soups = Health regeneration; meat = Strength (protein); sweets = quick energy; fish = alertness/focus; herbs = resistance or cure. Eating three groups in a day gives a small Balanced bonus. Dave's rule: higher tiers give better effects for longer, and quality grade scales it.

**Ingredients (new ones marked *):** Grain: wheat, barley, rye, oats. *Flour (from a quern or the Windmill). *Yeast (barm from ale or a starter; see sources). Honey, *Eggs, *Milk, *Butter, *Cheese, salt, herbs, fat. Vegetables: carrot, turnip, onion, leek, cabbage, parsnip, peas, beans. Fruit and berries: apple, pear, cherry, berries (wild now). Meat: beef, mutton, pork, fowl, game, fish.

| Tier | Ingredients | Where | Dishes (existing in **bold**) |
|---|---|---|---|
| Simple | 1 to 2 | campfire, spit, hot stone | **Roast meat 69, Roast fish 80, Roast roots 177**, **Baked apples 179**, boiled egg, berries and honey, **Fruit leather 184**, jerky (meat + salt), **Flatbread 273** (flour + water), porridge (oats + water) |
| Mid | 2 to 3 | campfire pot, clay hearth, **Basic Oven** | **Campfire Stew 15**, vegetable soup, pottage (**Hearty pottage 190**), bread (flour + water + yeast), **Honey loaf 274** (flour + honey + yeast), jam (berries + honey), **Berry compote 175**, dumplings (flour + fat + water), **Fish stew 188**, **Smoked fish 185**, cheese |
| High | 3 (4 only for a special feast dish) | Clay Oven, Iron Stove | meat pie (flour + meat + vegetable), **Hunter's stew 186**, **Forager's stew 187**, dumpling stew (meat + vegetable + flour), sweet cake (flour + egg + honey; milk optional as a Feast version), fruit tart, fish pie, roast fowl with herbs, **Roast Beast 191** |
Existing dishes not placed: **Herb fish 181, Garlic meat 182, Chestnut cakes 183, Trail bread 189, Rosemary joint 275, Mushroom skewer 180, Nut paste 176, Acorn mash 178** (placing them is a later data job).

**Drinks (Dave: all kinds, with food effects like Atlas):** Simple: water, milk, herbal infusions (the four teas 52, 57 to 59 stay). Mid: ale (grain + water + yeast), mead (honey + water + yeast), cider (apples), berry wine. High: wine (grapes, warm lands), spirits by distillation. Sources: ale was the peasant staple, mead is honey wine, cider from apples, wine imported in the north, barm (ale foam) was the bread leaven, and distilled drinks do not appear before the 15th century ([Barm](https://en.wikipedia.org/wiki/Barm), [BYO: Searching for medieval ale](https://byo.com/articles/searching-for-medieval-ale/), [SCA: Introduction to Brewing](https://adora.lochac.sca.org/files/2024/09/Introduction-to-Brewing.pdf)). Spirits therefore sit at the top tier. Brewing station: Brewing barrel/cauldron (Valheim Fermenter*, Dragonwilds Brewing Cauldron*); distilling needs a Still.

## B5. Farming catalogue (see also section 12)
Crops by tier: T1 oats, peas, turnip, cabbage, onion; T2 wheat, barley, rye, carrot, parsnip, leek, beans, flax; exotics from far islands: potato, maize, rice. Sources: wheat, barley, rye and oats were the main medieval cereals; peas and beans the legumes; cabbage, turnips, onions, leeks and carrots the vegetables ([History Crunch](https://historycrunch.com/food-and-farming-in-the-middle-ages/), [Wikipedia: Regional cuisines of medieval Europe](https://en.wikipedia.com/wiki/Regional_cuisines_of_medieval_Europe)).
Support items: hoe (exists), spade (exists), bucket (exists), **Scythe**, **Compost bin + Compost**, **Manure**, **Quern** (hand mill, T1), **Windmill** (Dave; grinds more, wind powered), **Water mill** (uses Water wheel 239), **Drying rack**, **Barrel**, **Salt**, **Chicken coop**, **Beehive**, **Hay** (animal feed), **Sack** (flour, grain).

## B6. Siege and gunpowder (Dave: both in, tiered)
Sources: battering ram and siege tower are ancient; the counterweight trebuchet replaced the mangonel in the 12th and 13th centuries; artillery appears in the 14th century; gunpowder arms (arquebus, cannon, mortar) end the age of siege engines around the late 15th century ([History Crunch: siege weapons](https://historycrunch.com/medieval-siege-weapons/), [Wikipedia: siege engines](https://www.Wikipedia.org/wiki/List_of_siege_engines)). Weak sources; dates approximate.
| Tier | Items (REC) | Notes |
|---|---|---|
| Early | **Battering ram**, **Siege ladder**, **Siege tower** | wood and rope; assault fortifications |
| Mid | **Ballista** (Dave: great against sea creatures from ships; Atlas*), **Catapult / Mangonel** (Atlas*, Medieval Engineers) | uses Bolts, Stone shot; ship mountable |
| Mid-late | **Trebuchet** (Medieval Engineers siege machines*) | biggest range, heavy build |
| Late (gunpowder) | **Hand cannon**, **Arquebus**, **Musket**, **Pistol**, **Cannon** (Atlas*, Ark*), **Mortar** | needs **Gunpowder** (charcoal + sulphur + saltpetre, ingredients real; Atlas, Rust and Satisfactory list Gunpowder) and **Shot**, **Powder charge**; fire and misfire risk |
Small throwables fit before this: **Javelin** (Dave), **Throwing axe** (Conan), **Sling**.

## B7. Boats and carts (Dave: many types, sizes, qualities)
Boats (sources: [Wikipedia: Medieval ships](https://en.wikipedia.org/wiki/Medieval_ships), other pages of mixed quality): dugout (oldest, hollowed from one log), coracle (wicker frame, hide cover), raft, **Karve** (small longship, war and transport), **Longship** (Viking warship), **Knarr** (short broad cargo ship, up to about thirty tons), **Cog** (northern merchant ship, high sides; sources disagree on its date). Our tier order (REC): Raft, Dugout canoe, Coracle (river), Rowboat/Skiff, Karve, Longship, Knarr, Cog. Sizes: small / medium / large; quality grade as above. Ship parts: oars, sail, anchor, rudder, hull planks; weapons mount (ballista, cannon). Existing refs: Valheim Raft, Karve, Longship; Atlas ships and shipyard; Don't Starve boats.
Carts and wagons (Dave's list plus sources: carts for farm goods long predate passenger vehicles; four-wheeled covered wagons were common in the late Middle Ages; horse litters carried the sick and the high born; passenger coaches spread across Europe by the 16th century, and the stagecoach is an early-modern form ([Gilbey: Early Carriages and Roads](https://gutenberg.org/cache/epub/66597/pg66597-images.html)). Because our game is fantasy-medieval, Dave's later vehicles stay but sit at the top tier):
| Tier | Vehicle | Pulled by |
|---|---|---|
| T1 | **Hand cart**, **Wheelbarrow** | player |
| T2 | **Hay cart**, **Pack saddle / saddlebags** (Vintage Story saddlebags*), **Litter** | donkey / horse |
| T3 | **Large hay cart**, **Lumber wagon**, **Caravan wagon** | horse / ox |
| T4 | **Carriage**, **Stage coach**, **Fine carriage** | horse team |
Needs draft animals (horse, donkey, ox): a future animal list. Sizes small/medium/large; quality grade.

## B8. Furniture and comfort
Dave: furniture should be fun and useful. REC set: **Stool** (sit to work; small crafting-quality or speed bonus), **Chair** (rest; heals/rests faster), **Bench** (seats 3, social: friends sitting and drinking get a morale bonus), **Table**, **Throne** (a keep's command seat for commanding a militia), **Bed** tiers (Rough bed 250, then Straw bed, Bed with linen), **Chest**, **Shelf**, **Wardrobe**, **Rug**, **Banner**, **Candlestick**, **Mug/Tankard** (drinks), **Barrel seat**. A comfort score from furniture was already a Valheim design in docs/mirror/design/research/Tyler_Valheim.md (Rested/Comfort); I have not re-read it. Existing: Camp bench 73, Rough bed 250, Tool rack 81, chests 22 and 28.

## B9. Climbing, traversal and gliders (Dave: in)
**Climbing pick** (Ark*, Forest climbing axe; T2+, pair of picks to climb cliffs), **Grappling hook** (Atlas*, Ark*, Valheim*; T3, rope and iron hook), **Anchored rope** (placeable; hammer an anchor into rock, rope hangs; Ark's zip-line anchor*, Satisfactory zipline), **Rope ladder**, **Glider** (Vintage Story lists Glider; Dave wants gliding off mountains: frame of wood, linen sail from flax, a good use for the loom chain; T3 to T4, limited by wind/stamina), **Pitons** (optional). Fun test: all of these reward exploration and mountains.

## B10. Remaining categories: recommended item families
(Each family is by material tier; a family is one item line, material is in the name. Counts are rough, to be fixed when data work starts.)
| Category | Families (REC) |
|---|---|
| Tools | Axe, Pickaxe, Spade, Hoe, Knife, Hammer (and Smith's hammer), Saw, Scythe, Shears, Fishing rod, Net, Hide scraper, Chisel (stone/carving, Vintage Story), Prospecting pan, Climbing pick, Torch/lantern, Bucket |
| Melee weapons | Club, Spear, Javelin, Dagger, Short sword, Sword, Longsword, Mace, Warhammer, Battleaxe, Halberd / polearm |
| Ranged | Sling, Hunting bow, Longbow, Crossbow, Throwing axe; guns at the top |
| Shields | Round shield, Buckler, Heater shield, Tower shield |
| Armour | Plant/cloth, Hide, Leather, Heavy leather, Bound leather, Gambeson (padded), Mail, Scale, Brigandine, Plate; helmets, gloves, boots, cloaks |
| Containers | Basket, Sack, Backpack, Barrel, Chest types, Pot, Jug, Waterskin, Quiver |
| Stations | Workbench tiers, Forge tiers, Kiln, Tannery, Leather table, Loom, Basic Oven, Clay Oven, Iron Stove, Still, Windmill, Quern, Carpenter/sawmill, Anvil as forge part |
| Building | Material tiers thatch, wood, stone, brick; stairs, gates, fences, palisades, hung doors, towers |
| Light | Torch, Candle, Oil lamp, Lantern |
| Medical | Bandage, Poultice, Salve, Herbal brews, Splint, Antidote |

**Extras (the "10 percent more", REC, each useful and cheap):** Glider; Anchored rope; Obsidian mirror; Hide scraper; Spyglass (Atlas Spyglass; general knowledge says it is a 17th-century invention, so it sits in the late fantasy tier); Compass and Map (Atlas, Minecraft, Forest; compass use in medieval Europe dates to roughly the 12th century, general knowledge, not in my searches); Treasure map (Atlas); Windmill; Still; Beehive; Chicken coop; Loom; Bedroll; Stool/Chair/Bench/Throne.

## B11. What I could not confirm
Real-world yeast sourcing details for the game recipe; spyglass and compass dates; whether Valheim's oven or Atlas's drink effects work as I summarised (I used only analysis rows); exact dates for cannon and cog; all game recipe ingredients (the analysis rarely has them). Numbers for effects, durations and tiers are design proposals for later tuning, not measurements.

## B12. Data edits done (batch 1, 2026-10-30, branch sal-items)
Small and reversible; nothing merged or retired yet, because merges touch recipes, blueprints and saves and need a game test (and Dave said no bakes).
- `data/items/items.json`: items 267 and 268 renamed **Basic Oven** (blueprint 14 in `blueprints.json` too). Added 15 materials, all marked `"future": true` (not obtainable yet), numbers 278 to 292, `next_number` now 293: Kindling 278, Flint 279, Pyrite 280, Obsidian 281, Processed hide 282, Leather 283, Fine leather 284, Heavy leather 285, Rivets 286, Copper ingot 287, Tin ingot 288, Bronze ingot 289, Flour 290, Yeast 291, Salt 292.
- Checked: JSON loads; `tools/check_dupe_names.py` ok; `tools/check_look_names.py` ok. NOT run: the game itself.
- Next data batch (not done): tools and weapons with their class fields (Hide scraper, Steel striker, Javelin, obsidian tools), the Tyler merges with old-number conversion, recipes, and the missing ovens (Clay Oven, Iron Stove).
- Batch 2: Hide scraper 293, Steel striker 294, Javelin 295, Obsidian knife 296 (tools and weapons, all `future`); `next_number` now 297. Decisions and sources are also listed in ITEM_DECISION_LOG.md.
