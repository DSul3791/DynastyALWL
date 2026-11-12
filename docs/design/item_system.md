# Item system

**HISTORICAL-DRAFT PRECEDENCE (added after later owner review):** This 10 Nov document remains useful for implementation history and rationale, but its earlier phrase "FINAL source for Parts B and C" was **final at that date**, not a higher-priority authority over Dave's later category approvals. For current item list, naming, counts, tools, weapons, armour, personal carrying, mounted equipment, vehicles, cooking, storage, physical warehouse cargo and optional four-digit crate/chest codes, see **[DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md)** and its approved decisions [D1]–[D13]. For workflow detail, consult [STORAGE_WAREHOUSING_DESIGN.md](STORAGE_WAREHOUSING_DESIGN.md) and [FOOD_PREPARATION_PRESERVATION_SERVING.md](FOOD_PREPARATION_PRESERVATION_SERVING.md). Preservation's two-route workflow and edible-serving-platter mechanic are owner-directed but their **exact item rosters are pending review**. Do not count or implement them on the strength of this older draft. None of the above grants permission to change gameplay files or merge.

Morgan, 10 Nov 2026. Docs only. **Status: draft 7, FINAL source for Parts B and C (draft 6 plus the coordinator's confirmations of all three reversals and the workbench level table, 10 Nov 05:58).** Draft 2 was built on the coordinator's rulings of 10 Nov and `item_master_list.md`. This draft fixes what Sonny's deep review (`buildables/item_system_review.md`, findings A1 to G) found against the live data on main c615a93e. Where a fix needs a ruling, it is in section 12 with my recommendation, and the draft uses the recommendation. Costs and inputs are first-pass. Jamie owns numbering; Kathleen owns look names; Steve owns station levels and slots.

Status keys: **HAVE** (live, name and recipe as live), **RENAME** (live, new display name), **CHANGE** (live, recipe changes), **FUTURE** (in data, not playable), **NEW** (not in data), **NEW-F** (new, gated on a future system), **PARKED** (named, not built; reason in section 11).

## 1. Naming rules

1. **A tier word only where the item comes in more than one material (coordinator ruling B1).** Those items are **"Tier - Item"**: tier word first, " - ", item in sentence case (`Stone - Axe`, `Hide - Boots`, `Wooden - Workbench`, `Brick - Forge`). This widens Dave's #875 scope to stations with several materials and overrides buildables ruling 4: the base workbench is **Wooden - Workbench**. **Single-version items are plain:** Kiln, Oven, Sawmill, Vice, Hand mill, Bucket, Waterskin, Whetstone, Hot stone, Fishing rod, Snare, Campfire, Torch, Clay jug, Wooden bowl, Spyglass (the first one is **Wooden - Spyglass**, since it comes in three materials). Everything built from one material only is plain (Fish trap, Drying rack, Tanning rack, Oil press, Smoker, Sap tap, Skep, Loom, Anvil, Sling, Bedroll and so on), unless a second material is planned. Clothing and furniture families keep their tier words. Pots take tier words only because Copper - Pot is added: Clay - Pot, Copper - Pot.
2. The tier word is the item's **main material**, one of the materials in section 7. The ladders in section 2 only say which materials make a progression. Style words (Rough, Canopy, Sturdy) are not tier words.
3. **Wooden** means any worked wood (stick, block or plank). **Log** means whole logs. **Stone**, **Brick**, **Thatch**, **Fibre** (plant fibre; "Grass" is retired as a tier word), **Hide**, **Leather**, **Fur**, **Wool**, **Linen**, **Clay**, **Wicker**, **Bone**, **Flint**: one word per material.
4. **Plurals:** what is gathered or used by the handful keeps its natural plural (Berries, Nails, Hinges, Seeds). What is counted one by one is singular (`Oak log`, `Oak beam`, `Feather`, `Stone`). Roughly 40 log and beam species rename to singular. **Planks becomes Plank** (ruled); Jamie gets the rename list.
5. Generic recipe groups that players see are named **"Any torch fuel", "Any forge fuel", "Any firewood", "Any stuffing", "Any bedding", "Any fodder", "Any knife", "Any saw", "Any needle", "Any candle"**.
6. Kits are hidden. Since #1003 (11 Nov) a kit row carries its piece's name (rule 7: kit and piece are one object in two states); the four log kits keep Log bench, Log table, Log trough and Log shelf. Ids never change.
7. Two live items never share a display name **unless they are one object in two states** (lit and doused torch, carried and set snare, kit and piece). Those keep one name.
8. Names are at most four words (`validate_items.gd`), sentence case after the dash, and never start with a verb.

## 2. Tier ladders and properties

| Family | Ladder (low to high) | Notes |
|---|---|---|
| Tools and weapons | Wooden, Stone, **Bronze, Iron, Steel** | Copper is an ingot for bronze, coins and fittings today. **Copper tools are a future option** on the backlog, not ruled out (decision 70, 11 Nov 2026). Obsidian parked. |
| Hammer | Wooden (1), Stone (2), Bronze, Iron, Steel (3) | Any metal is tier 3 for building. |
| Building | Thatch, Wooden, Log, Stone, Brick | One-storey Thatch; no Thatch ceiling. |
| Armour (metal) | Bronze, Iron, Steel | |
| Containers | Wicker, Wooden, Clay, Hide, Iron | Chests: Wicker, Wooden, Iron. |
| Furniture | Straw, Wooden, Log, Stone, Iron | Beds use Thatch, Straw, Feather, Canopy bed (comfort steps, section 6). |

### Clothes are materials with properties, not a ladder (Sonny C1)

Live warmth: Fur - Cloak 0.42, Hide - Cloak 0.30, Gambeson 0.30, Wool - Tunic 0.30, Hide - Tunic 0.24, Leather - Jerkin 0.22, Linen - Shirt 0.10 (cap 0.85). So Leather is colder than Hide and Linen is last.

| Material | Warmth | Armour | Wet | Gate | Climate |
|---|---|---|---|---|---|
| Fibre | low | none | dries fast | hand | warm |
| Hide | medium | light | bad | hand + needle | any |
| Leather | medium-low | medium | good | tanning rack | any |
| Fur | high | light | bad | hide + needle, fur animals | cold |
| Wool | medium-high | none | warm when wet | spinning/loom (future) | cold, temperate |
| Linen | lowest | none | dries fast | flax, loom (future) | warm |

### Station levels (Sonny A2)

A station's level is its own level plus 1 for each different add-on kind within 5 m (`station_level_of`, the Valheim model). Today a Wooden workbench with a vice and a tool rack reaches level 3, the same as a Stone workbench, so add-ons must be listed per station:

| Station | Own level | Add-ons | Highest level |
|---|---|---|---|
| Wooden - Workbench | 1 | Vice, Tool rack | 3 |
| Log - Workbench | 2 | Vice, Tool rack | 4 |
| Stone - Workbench | 3 | Vice, Tool rack | 5 |

### Workbench levels (design, assigned by Morgan on the coordinator's brief)

Level reached: **1** Wooden alone. **2** Wooden plus one add-on (Vice or Tool rack), or Log - Workbench alone. **3** Wooden plus both add-ons, or Log plus one, or Stone alone. **4** Log plus both, or Stone plus one. **5** Stone plus both.

Each bench tier unlocks something a player wants: level 1 is the first stone tools, bow and blocks (day one); level 2 is real kit (leather armour, longbow, shield, saw); level 3 is the spyglass and the cold-climate garments (fur, wool, linen, backpack); levels 4 and 5 are fine metalwork assembly (bronze and steel spyglasses, compass, mail, cuirass, crossbows). The hammer-built pieces no longer need a workbench (buildables ruling 3); these levels apply to **crafted items** only.

| Level | Recipes (live or planned) |
|---|---|
| 1 | Cobblestone, Stone block (8 Stone), Stone shingle, Wooden pin, Plank (by hand or saw too), Wooden - Bow, Stone - Spade, Stone - Hoe, Stone - Sickle, Scraper, Javelin, Leather strap |
| 2 | Iron - Saw (and Bronze - Saw assembly), Leather - Jerkin, Fibre - Gambeson, Wooden - Shield, Wooden - Longbow, Leather - Quiver, Leather - Cap, Leather - Boots, Leather - Gloves, Leather - Trousers, Wicker - Shield upgrade, Leather - Belt |
| 3 | Wooden - Spyglass, Water wheel, Leather - Backpack, Fur garments (Fur - Hat, Fur - Trousers, Fur - Boots, Fur - Mittens, Fur - Cloak), Wool garments (Wool - Cap, Tunic, Trousers, Mittens, Cloak), Linen - Shirt, Linen - Trousers, Heavy leather items, Stonecutter's carved-stone work |
| 4 | Bronze - Spyglass (assembly), Bronze - Compass, Bronze - Scale shirt, Iron - Mail shirt, Bronze/Iron - Helm and Greaves fitting, Horn - Bow, Wooden - Crossbow (fitting) |
| 5 | Steel - Spyglass, Steel - Cuirass, Steel - Helm and Greaves fitting, Steel - Crossbow (fitting), Steel - Gauntlets, Iron - Gauntlets |

Station (`also:`) levels for forge recipes stay on the forge. Steve and Jamie apply this table; Obsidian - Knife and other parked items are not assigned.
| Stone - Forge | 1 | none | 1 |
| Brick - Forge | 2 | Anvil | 3 |
| Large forge, Master forge | PARKED (the unpark is withdrawn) | | |

**Forge levels (ruled):** Stone - Forge level 1 = copper, tin, bronze. **Brick - Forge level 2 = iron smelting, nails, hinges, rivets.** **Brick - Forge plus Anvil = level 3 = steel smelting and steel working** (both at 3). The anvil costs iron ingots, so the first anvil needs the level-2 forge and the order holds. **The bellows is dropped** (Brick forge 2 plus a bellows would give level 3 with no anvil, breaking "the anvil is the steel step").

**Code requirement for Steve (ruled; Sonny's wiring): a recipe names a station *body* and a level.** Give the blacksmithy its own station id `brick_forge` with `also: {forge: 1}` so it still does bronze work; the Anvil gets `addon_of: brick_forge`, so the Stone - Forge has no add-ons and can never reach iron. Iron smelting and working need `brick_forge` level 2; steel needs `brick_forge` level 3. The Clay bloomery is its own body and the other iron road (below). Anvil cost 5 Iron ingot + 1 Log (#883).

### Progression gates

1. **Hand:** sticks, stone, plant fibre, twine. Stone tools, snare, campfire, thatch bed. Campfire makes the first charcoal, bricks and clay pots.
2. **Camp:** Workbench, Wooden - Bow, Wicker - Shield, Hide clothing (needs Bone - Needle), Fibre sandals.
3. **Log house:** Log - Workbench, Log walls, Tanning rack (leather), Drying rack, Kiln.
4. **Bronze:** Stone - Forge (copper and tin ore, charcoal from the campfire), Bronze tools and weapons, Stone - Workbench.
5. **Iron:** Brick - Forge (level 2), iron tools, armour, Iron - Chest, Kiln.
6. **Steel:** Brick - Forge plus Anvil within 5 m (level 3).
7. **Trade and comfort:** Silver and Gold ingots, jewellery, coins, banners, Feather and Canopy beds, mead.

## 3. Tools and hand equipment

"Group" means a kept ingredient group (section 7): any member satisfies the recipe.

| Name | Status | Station | Inputs |
|---|---|---|---|
| Stone - Axe | HAVE | hand | as live |
| Bronze - Axe | FUTURE | forge 1 | 2 Bronze ingot, 1 Stick, 1 Leather strap |
| Iron - Axe, Steel - Axe | NEW-F | forge 2, 3 | 2 ingot, 1 Stick, 1 Leather strap |
| Stone/Bronze/Iron/Steel - Pickaxe | HAVE / FUTURE | hand, forge 1, 2, 3 | as live |
| Wooden/Stone - Spade, Wooden/Stone - Hoe | HAVE | hand, workbench | as live |
| Bronze - Spade, Bronze - Hoe | NEW-F | forge 1 | 2 Bronze ingot, 2 Stick |
| Iron/Steel - Spade, Iron/Steel - Hoe | FUTURE | forge 2, 3 | as live |
| Stone - Sickle | RENAME (Sickle) | workbench | 1 Flint, 1 Stick, 1 Twine |
| Bronze/Iron/Steel - Sickle | NEW-F | forge 1, 2, 3 | 1 ingot, 1 Stick |
| Iron - Scythe | RENAME (Scythe) | forge 2 | as live (two-handed, fields) |
| Steel - Scythe | NEW-F | forge 3 | 2 Steel ingot, 2 Stick |
| Stone - Knife, Bronze - Knife | HAVE / FUTURE | hand, forge 1 | as live |
| Iron/Steel - Knife | NEW-F | forge 2, 3 | 1 ingot, 1 Stick |
| Wooden/Stone/Bronze - Hammer | HAVE / FUTURE | | as live |
| Iron - Hammer, Steel - Hammer | NEW-F | forge 2, 3 | 2 ingot, 1 Stick (buildables B0: items 560, 561) |
| Iron - Saw | RENAME (Hand saw) | workbench | as live: Saw blade, 2 Stick, 2 Twine. The live blade is 2 Iron ingot, so it is an iron saw. |
| Bronze - Saw | NEW-F | forge 1 | 2 Bronze ingot, 2 Stick |
| Steel - Saw | NEW-F | forge 3 | 2 Steel ingot, 2 Stick |
| Saw blade | HAVE | forge 2 | kept for the Sawmill only |
| Bronze/Iron/Steel - Chisel | NEW-F | forge 1, 2, 3 | 1 ingot, 1 Stick. **A kept tool** (group "Any chisel"); the Stonecutter's bench needs a Bronze - Chisel. |
| Stone - Wedge | HAVE | hand | as live |
| Scraper | RENAME (Hide scraper) | workbench | as live |
| Bone - Needle | CHANGE | hand | **Revive `sewing_needle`, item 49 (retired, locked), 1 Bone. Kept, not used up.** Required for everything sewn: garments of hide, leather, fur, wool, linen, and backpack, quiver, waterskin, bedroll, sack, pouch, belt. Woven grass and fibre items do not need it. About 25 live recipes gain a needle: Jamie needs that list. |
| Iron - Needle | NEW-F | forge 2 | 1 Iron ingot. Lasts five times as long. |
| Whetstone | NEW | hand | 1 Stone. Kept tool (durability 40, 1 per hone). With one in the pack, R on a tool hones it with no materials: +25% durability, never above 75%; past that the real repair applies (`part_c_code_plan.md` s4). Plain name, single version. |
| Mortar and pestle | NEW | hand | 2 Stone. Medicine and dye grinding. (Hand mill stays for grain.) |
| Fishing rod | HAVE (plain) | hand | 2 Stick, 2 Twine. Hook: Hook (NEW, 1 Bone, kept as the rod's hook) |
| Fishing net | RENAME (Fishing net) | hand | as live |
| Fish trap | NEW | hand | 10 Stick, 4 Twine. Only in water at least 0.3 m deep; catches from the fishing cell (`fishing.json`). |
| Fishing spear | NEW | hand | 1 Stick, sharpened with any knife (group) |
| Fishing bait | NEW | hand | any raw fish scrap, or Worm (small chance when digging soil, `digging.json`). One item. |
| Torch | HAVE | hand | as live. **The doused torch keeps the name Torch** (Dave, 6 Nov; `test_torch_douse.gd`). |
| Candle | RENAMED from Tallow - Candle (10 Nov 2026) | hand | 1 Tallow, 1 Plant fibre → 3. The animal-fat recipe (200) is retired (2 per fat beat tallow's 1.5, so no one would render tallow). |
| Beeswax - Candle | NEW-F | hand | 1 Beeswax, 1 Plant fibre → 3. Candle group "Any candle" for lanterns and chandelier. |
| Steel - Striker | FUTURE | forge 3 | as live |
| Spyglass | HAVE | workbench | as live (design 9 Nov, three tiers) |
| Bronze - Spyglass | NEW-F | forge 1 | per `spyglass_design.md`, bronze tube instead of brass |
| Steel - Spyglass | NEW-F | forge 3 | per the design; Fine leather grip (gives Fine leather a use) |
| Bronze - Compass | NEW-F | forge 1 | 1 Bronze ingot, 1 Crystal lens, 1 Lodestone (rare drop from skarn iron ore) |
| Bucket | HAVE (plain) | hand | as live; holds 8 L |
| Waterskin | HAVE (plain) | hand | as live; holds 1.5 L |
| Drinking horn, Tankard | NEW-F | hand | 1 Horn; 1 Wooden block, 1 Twine (cup and tankard also gifts) |
| Drop spindle | NEW-F | hand | 2 Stick, 1 Stone. Hand yarn before the spinning wheel. |
| Awl | FOLDED into Bone - Needle | | |

Dropped: Iron - Tongs (an ingredient eaten by one recipe is noise; if tongs are wanted, make them a kept tool from level 2), Wooden - Watering can (the bucket already waters a plot; see C9/D3), Herb table (the mortar and the hand mill cover it), Iron - Shears (no sheep to shear; parked), Stone - Mortar and pestle (renamed above, four-word limit).

## 4. Weapons and ammunition

| Name | Status | Station | Inputs |
|---|---|---|---|
| Wooden - Club | HAVE | hand | as live |
| Bone - Club | NEW | hand | 2 Bone, 2 Twine |
| Stone - Mace | HAVE | hand | as live |
| Bronze/Iron/Steel - Mace | FUTURE / NEW-F | forge 1, 2, 3 | 2 ingot, 1 Stick, 1 Leather strap |
| Wooden - Spear, Stone - Spear | HAVE | hand | as live |
| Bronze/Iron/Steel - Spear | NEW-F | forge 1, 2, 3 | 1 ingot, 1 Stick |
| Bronze/Iron/Steel - Sword | FUTURE | forge 1, 2, 3 | as live: 2 ingot, 1 Leather |
| Bronze/Iron/Steel - Dagger | NEW-F | forge 1, 2, 3 | 1 ingot, 1 Leather strap |
| Iron/Steel - Battle axe | NEW-F | forge 2, 3 | 3 ingot, 2 Stick |
| Iron/Steel - Halberd (late) | NEW-F | forge 2, 3 | 3 ingot, 2 Stick |
| Steel - Greatsword | NEW-F | forge 3 | 5 Steel ingot, 1 Leather strap |
| Javelin | FUTURE | hand | as live |
| Wooden - Bow | HAVE | workbench | as live |
| Wooden - Longbow | NEW | workbench | **1 large Wooden block, 1 Sinew, 2 Twine** (one stave) |
| Horn - Bow (late) | NEW-F | workbench | 2 Horn, 2 Sinew, 1 Wooden block |
| Wooden - Crossbow | NEW-F | forge level 2 (Rivets are level 2) | 4 Plank, 2 Twine, 2 Rivets |
| Steel - Crossbow | NEW-F | forge 3 | Wooden - Crossbow, 2 Steel ingot |
| Sling | NEW | hand | 1 Hide, 1 Twine. Ammo: Sling stone |
| Sling stone | NEW | hand | 1 Gravel → 5 |
| Wooden/Stone/Bone - Arrow | HAVE / NEW | hand | as live. Fibre - Arrow becomes a second Wooden - Arrow recipe (fibre is only the fletching), like `quill_arrow`. |
| Bronze/Iron/Steel - Arrow | NEW-F | forge 1, 2, 3 | 1 ingot → 8, **4 Feather per 8** |
| Fire arrow | NEW | hand | (`fire: true`; lit on loosing if a lit fire, torch or light is within 3 m, else flies as a plain arrow) 1 **Wooden - Arrow**, 1 Pitch, 1 Plant fibre (from the wooden arrow only, so no arrow group) |
| Poison arrow | NEW-F | hand | 1 Wooden - Arrow, 1 Belladonna berries or Wolfsbane roots |
| Iron/Steel - Bolt | NEW-F | forge 2, 3 | 1 ingot → 8 |
| Hide - Quiver | RENAME (Quiver) | hand | as live |
| Leather - Quiver | NEW | workbench | 2 Leather, 2 Leather strap |
| Wicker - Shield | HAVE | hand | as live |
| Wooden - Shield | RENAME (Plank - Shield) | workbench | **as live: 3 Planks, 1 Hide, 1 Hide glue** |
| Bronze/Iron/Steel - Shield | RENAME (Kite shield) | forge 1, 2, 3 | **as live: 2 Planks + 1 or 2 ingots** (a wooden shield with a metal rim: the better design) |
| Snare | HAVE | hand | as live. **The set trap keeps the name Snare** (two states of one thing; a name starting with "Set" fails `validate_items`). |
| Bird trap | NEW | hand | 8 Stick, 2 Twine. Birds are caught by this, not the snare. |
| Jaw trap | NEW-F | forge 2 | 3 Iron ingot, 2 Hinges |

Skipped: whip, pit trap, throwing stones and axes, guns, explosives.

## 5. Clothing and armour

Everything sewn needs **Bone - Needle** (kept tool, section 3). Slots (Sonny C2): `clothing.json` had six (head, body, legs, feet, hands, back), so a cloak could not go over a tunic. **Done (#921, protocol 104):** slots **outer** (cloaks) and **waist** (belt, quiver) are live, eight in all. **Fur - Coat is dropped** (same recipe and slot as the live Fur - Cloak).

| Slot | Names |
|---|---|
| Head | Hide - Hood, Leather - Cap, Fur - Hat, Wool - Cap, Straw - Hat (NEW), Bronze/Iron/Steel - Helm. Coif skipped. |
| Body | Hide - Tunic, Leather - Jerkin, Wool - Tunic, Linen - Shirt, **Fibre - Gambeson** (RENAME of Gambeson: it is made of fibre cloth, not linen; a Linen - Gambeson can come later), **Iron - Mail shirt** (RENAME), **Steel - Cuirass** (RENAME of Plate cuirass), Bronze - Cuirass (NEW-F; 4 Bronze ingot, 1 Leather) |
| Legs | Fibre - Skirt (RENAME of Grass - Skirt), Hide - Trousers (**merge Hide - Leggings into it**), Leather - Trousers (NEW), Fur - Trousers (NEW-F), Wool - Trousers, Linen - Trousers (NEW-F), Bronze/Iron/Steel - Greaves (NEW-F; 2 ingot, 1 Leather) |
| Feet | Fibre - Sandals, Hide - Boots, Leather - Boots (NEW), Fur - Boots. **No metal boots.** |
| Hands | Hide - Gloves, Hide - Mittens, Leather - Gloves (NEW), Fur - Mittens (NEW-F), Wool - Mittens, Iron/Steel - Gauntlets (NEW-F) |
| Cloak (outer slot) | Fibre - Cloak (RENAME of Grass - Cloak), Hide - Cloak, Fur - Cloak, Wool - Cloak (NEW-F; 3 Wool cloth, 1 Twine) |
| Back and waist | Hide - Backpack (RENAME), Leather - Backpack (NEW), Leather - Belt (NEW, waist slot, fastened with **Toggle**, NEW, 1 Bone → 2), quiver (section 4) |
| Jewellery | Silver - Ring, Gold - Ring (NEW-F, with their ore items), Bone - Necklace, **Claw - Necklace** (NEW-F; Claw is live, dropped by 14 species and has no use; replaces Amber, which is placed nowhere) |

**Hide - Sack and Basket are small placed storage** (early-tier chests, 6 slots; ruled). Hide - Pouch parked. Iron - Shears parked until a domestic sheep exists.

**Fur supply (C4):** only fox, wolf, bear and black bear drop Fur. Add Fur to beaver, otter, mink, pine marten, lynx, seal and reindeer in `carcass.json` (Steve/Jamie), or six fur garments rest on four species.

## 6. Furniture, stations, containers (buildables rows live in `buildables_plan.md`)

Furniture B3, lights B4, garden B5 and water B6 rows are **not** repeated here. Draft 2 repeated some with other costs; those rows are removed (Sonny E1): Stone - Workbench, Wooden - Shelf, Cupboard, Wooden - Barrel, Compost bin, Scarecrow and Iron - Brazier now live only in the buildables plan, and the plan's costs and names win. The workbench ladder stops at Stone (level 3).

### Beds and soft furnishing

| Name | Status | Inputs |
|---|---|---|
| Thatch - Bed | RENAME (Rough bed) | 10 Thatch, 4 Stick, 2 Twine. **Remove the live straw recipe** from it (duplicate of the Straw - Bed). |
| Straw - Bed | RENAME (Straw bed) | 12 Straw, 6 Stick, 2 Twine |
| Feather - Bed | RENAME (Feather bed) | **the kit upgrade costs win; blueprints match them** (A12) |
| Canopy bed | RENAME (Canopy bed; one version, the top bed) | as live |
| Bedroll | NEW | 3 Hide, 2 Twine, needle. Portable sleep: in the pack, open and dry, sleep quality 0.85 instead of 0.6 and a 0.05 warmth bonus; rain still stops sleep (code plan s5). |
| Hide - Rug, Wool - Rug | HAVE / FUTURE | as live |
| Antler mount | RENAME | as live. Tusk mount NEW now (Tusk is live, item 347). **Skull - Mount dropped.** |
| Weapon rack, Armour stand | NEW | 6 and 8 Planks, 2 Twine |
| Tool rack | HAVE | as live (it is the workbench add-on) |
| Flower pot | RENAME (absorbs Garden pot) | 2 Clay, 1 Soil |
| Cloth - Banner, Cloth - Tapestry | NEW-F | **Allowed: NO FLAGS means code feature flags.** The buildables row that bans them is wrong and is fixed. Use Linen or Wool cloth once they exist. |
| Sign | NEW | 2 Planks, 1 Stick |
| Standing torch | HAVE (item 543, unbuilt) | reuse the id for B4's Wooden - Torch post |

### Stations

**Code requirement for Steve (section 6 restatement):** a tier's recipes require both the station **body** and the **level**. Iron smelting and iron working need the brick_forge body at level 2; steel needs the brick_forge body at level 3. The anvil is `addon_of: brick_forge`, so the Stone - Forge has no add-ons and never makes iron.

| Name | Status | Gate and notes |
|---|---|---|
| Campfire, Campfire pot | HAVE | as live. Smoked fish and meat move from the campfire to the Smoker. |
| Roasting spit | DROPPED (campfire roasting and the Clay hearth's spit cover it) | |
| Wooden - Workbench | RENAME (Workbench) | the base; ruled |
| Log - Workbench | RENAME (Sturdy workbench) | ruling 4, buildables |
| Stone - Workbench | per buildables B3 | not repeated here; B3 has no Iron - Workbench; the workbench ladder's own levels stop at Stone (3), reachable top 5 with add-ons |
| Stone - Forge | RENAME | bronze; add-on: Anvil |
| Brick - Forge | RENAME (Blacksmith's forge) | iron. **New cost (ruled): 20 Brick, 10 Stone, 4 Clay mortar. Kathleen reskins it: brick body, keep the hood and iron straps.** |
| Anvil | NEW | **Brick - Forge add-on** (`addon_of: brick_forge`) within 5 m. 5 Iron ingot + 1 Log (as #883). **The bellows is dropped.** |
| Large forge, Master forge | PARKED | The unpark is withdrawn; the anvil is the steel step. |
| **Clay hearth** | **HAVE, stays** | **A cooking station (26 recipes; the Oven needs it near). Not a kiln.** |
| Kiln | NEW | One kiln (single version, plain name; supersedes draft 3's Clay - Kiln and Brick - Kiln). Hammer; 30 Brick, 8 Clay, 4 Clay mortar. **Brick yield doubles (2 Clay → 6 Brick; the campfire gives 3) and 2 Firewood → 2 Charcoal (campfire: 1).** Glass (Sand + Potash) and Potash are made here. **Pots stay at the campfire.** The campfire makes the first bricks, pots and charcoal. |
| Oven | RENAME (Brick oven; single version, plain) | as live; still needs the Clay hearth near it |
| Tanning rack | NEW | 6 Log, 4 Twine. **Move the live leather recipe here with the same inputs** (Scraped hide + 2 Tanbark + 1 Water; Heavy leather too) and remove the campfire-pot version. |
| Drying rack | NEW | 8 Stick, 4 Twine. Jerky, dried fruit, herbs. |
| Brewing barrel | NEW-F | absorbs Keg. Mead, ale, cider. |
| Preserving jar | NEW | 6 Clay. Jam, pickles, compote, sauerkraut. |
| Oil press | NEW | 12 Stone, 4 Log. **Lamp oil comes from the press (linseed, walnut, olive) or from fish or seal fat at the Campfire pot; the tallow route is removed** (buildables B4 row fixed). |
| Smoker | NEW | 16 Stone, 6 Clay |
| Root cellar (Stone - Cold store) | NEW-F | **Needs no ice (D1).** Inside, temperature is the site's mean annual air temperature (soil about 2 m down holds it all year); in a cave cell it is 5.5 C (#717). Spoilage follows that. An ice house can come later. 20 Stone block, 6 Clay mortar. |
| Sap tap | NEW-F | on maple or birch; sap and resin. 2 Planks. |
| Skep | NEW-F | the hive: honey, beeswax (replaces the Wooden hive; ruled yes) |
| Loom, Spinning wheel | NEW-F | When they arrive, the hand recipes for Wool cloth and Linen go (say so in section 7). |
| Wooden - Compost bin | per buildables B5 | |
| Cheese press | NEW-F | with dairy; cheese is live now (4 Milk + Salt at the pot) and moves later |
| Hand mill | HAVE (plain; id quern) | single version |
| Sawmill, Vice | RENAME to plain (Sawmill; Wooden vice → Vice) | single versions |
| Woodworking table | RETIRED | recipes move to Log - Workbench |

Skipped and ruled out: research bench, windmill, boatyard (with boats), umbrella, vest, serving tray, smoke bomb, secateurs, compost bucket, papyrus (with paper), toys. **Holes the review found, each added or skipped (C7):** crucible and casting moulds (skipped), forge add-ons bellows and grinding wheel (**bellows dropped; cooler and grinding wheel skipped**), cauldron (the Campfire pot is the cauldron; Copper - Pot is the ruled upgrade (never breaks; NEW-F, 4 Copper ingot, forge 1)), pottery wheel (skipped: kiln only), adze (skipped), awl (folded into the needle), tankard (added), sled (future), harpoon (skipped), fish hook (**Hook added**), pitchfork, rake and flail (skipped: hand tools suffice), drop spindle (added; hand yarn before the wheel), lodestone (a rare drop, section 7).


### Added from section 16 (coordinator rulings, 10 Nov 05:53)

| Name | Status | Gate and notes |
|---|---|---|
| Stonecutter's bench | NEW (plain name, one material) | Stone gate. Cost 20 Cobblestone, 4 Log. **The live block recipe (8 Stone at the workbench) stays**, so stone building does not wait for bronze (Sturdy - Wall needs 12 Stone block). The bench gives more blocks per stone, and carved stone, using a kept Bronze (or better) - Chisel. |
| Clay bloomery | NEW | Bronze gate. Smelts bog iron and iron ore **directly to Iron ingot at 5 ore → 1, slowly** (the forge is 4 → 1, so the bloomery is cruder and slower but earlier). No Iron bloom item. Pairs with Sonny's bog iron. Iron tools still need the `brick_forge` body. |

**Numbers given to Jamie (10 Nov):** Clay bloomery blueprint 24 Clay, 10 Stone, 2 Clay mortar, hammer 1, charcoal fuel, no bronze in the cost. Stonecutter's bench: Stone block 6 Stone (workbench stays 8), Carved stone block and Carved stone shingle 1 for 1 from their plain version; each needs a kept chisel (group "Any chisel"). The bench can be placed before any chisel exists; chisels are future items with locked forge recipes (1 ingot, 1 Stick).
| Storage jar | NEW | Placed storage, 4 slots, grain/oil/water, capacity 20 L. |
| Crock | MERGED into Preserving jar | |
| Bronze - Scale shirt | NEW-F | The bronze body armour (bronze has no mail live): 4 Bronze ingot, 1 Leather. Other armour types skipped. |
| Tub | NEW-F | Wooden gate. Comfort and warmth; fills from a bucket; heated by a fire within 3 m. Future until hygiene exists. |
| Iron - Hanging brazier | NEW-F | B4 later. Sconce = Wall torch (merged). |
| Wooden wheel | NEW-F | Component, with the cart. |
| Horseshoes | FUTURE | with horses |
| Fruit juice | NEW | one recipe family: any berry or fruit + water, by hand; alongside Cider. |
| Fruit wine | NEW-F | family under the Brewing barrel, with wine. |
| Fish soup, Meatballs | NEW | Copper - Pot recipes; the other Valheim dishes merged. |
| Parsnip (temperate), Rice (warm biome, future) | NEW / NEW-F | crops; the rest of the Vintage Story crops skipped. |
| Pickled vegetables | NEW | at the Preserving jar. Cured meat = Jerky; rendered fat = Tallow (merged). |
| Sled | FUTURE | |

Merged or skipped: Jeweller's bench (jewellery at the forge), Mining bag, Trunk, Treasure chest, Tool shelf, Falx, Simple bag, grain beers (one Ale), biome dishes, cheese kinds (one Cheese), skill potions, grindstone, armour/fletching benches, water barrel (large), animal feed, daub (merged into Clay mortar; a wattle-and-daub wall is parked as a buildables question), Clay shingles (parked), clay planter (merged), moulds and crucible (skipped).

### Containers and vessels

| Name | Status | Notes |
|---|---|---|
| Wooden - Barrel, Wooden - Crate | per buildables B3 | one piece type; the Rain barrel is the B3 Wooden - Barrel |
| Clay jug | HAVE (plain) | 2 L |
| Clay - Pot, Copper - Pot | RENAME (Clay pot) / NEW-F | 3 L; the pot takes a tier word because it comes in two materials |
| Hide - Sack, Basket | NEW | small placed storage, 6 slots (early chests); Hide - Sack 2 Hide, 1 Twine, needle; Basket 8 Stick, 4 Twine |
| Wooden bowl | HAVE (plain) | 0.3 L |
| Mug | NEW | 2 Clay; `capacity_ml` 400 |
| Cup, Plate, Spoon | NEW | 1 Wooden block each |
| Bottle | NEW-F | 1 Glass; `capacity_ml` 750 |
| Waterskin | HAVE (plain) | |

## 7. Materials, sources and groups

| Item | Status and rule |
|---|---|
| Plank | RENAME (Planks → Plank; counted one by one; Jamie gets the list) |
| **Clay mortar** | RENAME (from Mortar). The live mortar is 2 Sand + 1 Clay, so name it for what it is. (Lime mortar dropped 10 Nov: lime powder is the concrete binder, section 17) A true lime mortar from kiln-burnt limestone (limestone is placed in the geology) can come later as a better one (B8). |
| Copper, Tin, Bronze, Iron, Steel ingot | HAVE. **Bronze ratio:** live 1 Copper + 1 Tin → 2 Bronze is half tin (real bronze is about one part in ten). Use 3 Copper + 1 Tin → 4 Bronze; halves the tin needed. |
| Silver ingot, Gold ingot | NEW-F; **no ore items exist** though the geology places both (silver veins 0.35, gold arcs 0.3, veins 0.65, placers). Add Silver ore and Gold ore items. |
| Nails, Hinges, Rivets | HAVE. Iron smelting and working gain level 2. **Bronze nails** (894) and **Bronze hinges** (895) are made at the Stone - Forge, 1 Bronze ingot → 100 or 20, and fill any nails or hinges cost through the `nails` and `hinges` ingredient groups (#1001); a taken-down piece gives back the bronze kind once #1004 lands. Iron band has no bronze stand-in. |
| Linen thread, Wool yarn | NEW-F |
| **Fibre cloth** | RENAME (from Cloth; made from 8 Plant fibre by hand). Banners and tapestries are better as Linen or Wool. |
| Wool cloth (3 Wool), Linen (4 Flax → 2) | HAVE, by hand; those recipes go when yarn, thread, wheel and loom arrive |
| Leather, Fine leather, Heavy leather, Leather strap | HAVE. Fine leather finally gets a use (Steel - Spyglass grip). |
| **Pine tar** | RENAME (from "Pine pitch"; that is what its own description says). Keep Tar (5 Pine tar → 1). |
| **Pitch** | HAVE as the display of the pitch ingredient group (resin, pine tar, animal fat) shown **"Any torch fuel"**. **No merge** (draft 2 was wrong: the torch and the water wheel need both). |
| Forge fuel and fire fuel | Two groups stay apart: **"Any forge fuel"** (charcoal, coal) and **"Any firewood"** (firewood, softwood firewood). Retire the future `charcoal_wood`. |
| Beeswax | NEW-F |
| Dyes | NEW-F: six colours (red, blue, yellow, green, black, white) from plants plus a mordant (**Alum**, placed in the geology). There is no "single Dye" live to replace. |
| Wild grain | RENAME (from `seed_bundle`). Gathered wild grain: eat, mill (`wild_grain_flour` takes 3) or sow. Per-crop seeds stay separate and keep "Seeds". The old rule "dedupe into one seed per crop" refers only to the per-crop seeds. |
| Rock salt | NEW; the geology places salt but every salt recipe uses `sea_salt`. Rock salt gives the same Salt, so inland players can cure meat. |
| Paper, Ink | PARKED |
| Down, Wooden pin | Down is feather-bed only; **Wooden pin is kept** (the Stool and Chair blueprints use it). Claw, Tusk and Soap are **trade goods** (Dave, 4 Nov); Soap waits for the dirtiness system, no medicine use. |
| Flour | HAVE |

### Ingredient groups to add (A5)

Knife, saw, needle, axe, pick and hammer groups so a kept tool of any tier works (`craft_planner.gd` checks each `keeps` entry by exact item today; an Iron - Knife would not cut a leather strap). Steve confirms groups expand in `keeps` as well as in `needs`. Also: Any candle.

### Ingredients with no source (A13): proposed sources

| Missing | Needed by | Proposed source |
|---|---|---|
| Horn | Horn - Bow, B4 horn panes, drinking horn | Carcass part for mountain goat, wild sheep, bighorn, chamois, goat, cow, buffalo, wildebeest, pronghorn. Fix `carcass.json`: buffalo, wildebeest and rhino drop **antler** but have horns. Horn panes are pressed horn, so make B4's panes from Horn, not antler. |
| Gut | Sausage, bowstrings | Carcass part for mammals over about 20 kg |
| Worm | Fishing bait | Small chance when digging soil; or bait from any raw fish. **No Fish offal.** |
| Lodestone | Bronze - Compass | Rare drop from skarn iron ore |
| Potash | Glass | **Exists** (gathered item 1108, from saltbush; soap uses it). Fire ash at the Kiln is a second source. |
| Ice | (cold store) | Not needed: root cellar (D1) |
| Silver ore, Gold ore | ingots | New ore items |
| Lime powder | Concrete binder | Limestone, Kiln; with Sand and Stone at the Mixer makes Concrete (section 17) |
| Beeswax, Honey | candle, mead | Skep (NEW-F) |

## 8. Food, drink, medicine, transport, farming, trade

- **Food:** keep ours. Add drinks: Mead, Ale, Cider (apples are everywhere), Wine (future). Hops future crop; mustard future; pepper skipped. Meat skewer and Sausage (campfire pot; Gut) NEW. Oat porridge future. Cheese is live now and moves to the press later.
- **Medicine:** add Herb antidote. Pills skipped. Bandage, poultice, salve, splint stay.
- **Transport (separate design doc):** Log - Raft, Wooden - Rowboat, Wooden - Sailboat, Wooden - Cart, Leather - Saddle as NEW-F placeholders. Snowshoes now: item id `wooden_snowshoes`, display name **Snowshoes** (single material, no tier word), worn in the feet slot with `snow_walk: true`; needs Steve's snow-walking rule first (code plan s7).
- **Farming:** Chicken coop, **Fodder trough** (named so no one takes it for the B6a water troughs), Scarecrow (buildables B5; the plan's name wins), Bonemeal (second fertiliser beside Compost; 2 Bone at the hand mill). Irrigation per the buildables plan.
- **Water items against Sonny's rules and Steve's #912 (D3):** the bucket holds 8 L, so the well draw fills the held container (B6a's "E draws 10 L" becomes the container size). Plot store 100 L at 1% per litre: an 8 L bucket adds 8%. Glass bottle and Clay mug need `capacity_ml`. Filling a container at a trough, tap or cistern takes the network's quality tag. The water wheel and sawmill need moving water: a paddle over a river cell of the 8 m levels at least 0.3 m deep with at least 0.3 m/s (final numbers when scheduled).
- **Hot stone (D2):** a 1 kg stone at about 80 C down to 35 C holds about 36 kJ. Against the body at 10 to 20 W that is 30 to 60 minutes. Proposal: a small warmth bonus fading to nothing over 1 game hour (75 to 150 real seconds), after 10 game minutes heating at a fire. Name **Hot stone** (plain). Dave's numbers.
- **Trade:** coins stay. Gift trinkets arrive with jewellery.

## 9. Renames (old → new)

| Old | New |
|---|---|
| Sickle / Scythe | Stone - Sickle / Iron - Scythe |
| Hand saw | Iron - Saw |
| Hide scraper | Scraper |
| Fishing net | Fishing net |
| Tallow - Candle | Candle |
| Quiver | Hide - Quiver |
| Plank - Shield | Wooden - Shield |
| Bronze/Iron/Steel - Kite shield | Bronze/Iron/Steel - Shield |
| Gambeson | Fibre - Gambeson |
| Mail shirt / Plate cuirass | Iron - Mail shirt / Steel - Cuirass |
| Grass - Skirt / Grass - Cloak | Fibre - Skirt / Fibre - Cloak |
| Backpack | Hide - Backpack |
| Rough bed / Straw bed / Feather bed | Thatch - Bed (thatch cost) / Straw - Bed / Feather - Bed |
| Canopy bed | Canopy bed (unchanged) |
| Log seat | Log - Seat |
| Antler mount | Antler mount (kept plain: one material, 10 Nov 2026) |
| Flower pot | Flower pot |
| Workbench / Sturdy workbench | Wooden - Workbench / Log - Workbench |
| Planks | Plank |
| Clay pot | Clay - Pot |
| Stone forge / Blacksmith's forge | Stone - Forge / Brick - Forge (new brick cost) |
| Brick oven | Oven |
| Wooden vice | Vice |
| Timber set / Timber prop | Wooden - Beam / Wooden - Post |
| Mortar | Clay mortar |
| Cloth (`fibre_cloth`) | Fibre cloth |
| Pine pitch (`pine_tar`) | Pine tar |
| Seeds (`seed_bundle`) | Wild grain |
| Oak logs, Birch logs, Oak beams, Reed stems | Oak log, Birch log, Oak beam, Reed stem |
| Large Forge / Master Forge | Large forge / Master forge (parked) |

**Not renamed:** Torch (lit and doused), Snare (item and set), Hand mill, Bucket, Waterskin, Fishing rod, Clay jug, Wooden bowl, Clay hearth, Sawmill, Spyglass. Ids never change.

## 10. Merges

| Merge | Result |
|---|---|
| Hide - Leggings into Hide - Trousers | one item (load-time migration for worn and stored leggings: Steve) |
| Garden pot into Flower pot | Flower pot |
| Keg into Brewing barrel | Brewing barrel |
| Bait kinds | one Fishing bait |
| Candle recipes | tallow only (plus beeswax later) |
| Straw bed recipes | Straw - Bed only |
| Fertiliser tiers | Compost plus Bonemeal |

**Not merged (draft 2 was wrong):** Pine tar and Pitch, forge fuel and firewood.

## 11. Parked

| Item | Why |
|---|---|
| Obsidian - Knife | Obsidian ladder not wanted |
| Large forge, Master forge | Anvil is the steel step; no job for them yet |
| Paper, Ink, Map, Papyrus | No paper chain |
| Prospecting pick, whip, pit trap, coif, named armour sets | Ruled out |
| Lockpick, guns, explosives, power, tech-tree items, smoke bomb | Not our fantasy |
| Runes, altars, wardstones | Magic not designed |
| Windmill, research bench, serving tray, toys, secateurs, compost bucket, umbrella, vest | Ruled out or later |
| Iron - Shears | No living sheep |
| Hide - Pouch | Needs a bag feature (Sack and Basket are placed storage, section 6) |
| Boatyard, Piers, Docks | Boats batch (B7) |
| Cheese press, Loom, Spinning wheel, Skep, Sap tap, Cold store, Brewing barrel | Future systems (NEW-F) |

## 12. Rulings applied and open points

**Decided by the coordinator, 10 Nov (all folded in above):** naming scope (tier word only for multi-material items; base is Wooden - Workbench; Planks → Plank), Large forge parked again, slots outer and waist, banners and tapestries allowed (NO FLAGS means code flags), bog iron approved for Sonny after the playtest (iron is only in skarns; none on tile 3,4), zinc no longer placed, lead placed with no item, Copper - Pot added, brick forge cost, one Kiln, root cellar, hot stone as an estimate.

**Draft 6 changes that reverse or adjust a coordinator ruling (from Sonny's re-check; all three reversals confirmed by the coordinator, 10 Nov 05:58):** (1) the **bellows is dropped** (it let a Brick forge reach steel with no anvil); (2) the **Clay bloomery** gives Iron ingot directly at 5 ore → 1 (no Iron bloom), because the earlier 2 → 1 beat the forge and the bloom would still need the Brick forge; (3) the Stonecutter's bench **does not gate Stone block**, the live 8-Stone workbench recipe stays; (4) **tier words dropped from every single-material item** (Fish trap, Drying rack, Tanning rack, Oil press, Smoker, Sap tap, Skep, Loom, Anvil, Sling, Bedroll and about 25 more) to apply your rule 1 uniformly, and the first spyglass is Wooden - Spyglass; (5) workbench recipes must be assigned to levels 2 to 5 or the Log and Stone benches gate nothing; (6) Soap keeps its trade-good role (no medicine use).

**Known gaps (not decisions):** rock iron is still not on the land of the starter tiles (both iron bodies there lie under the sea), so land iron is **bog iron** (live 11 Nov, #996 and #997: a spade digs Iron ore from fen, marsh, swamp and bog mud). The boulder ore lookup bug is fixed (#913). **Tin answer (Jamie's check of #913):** from the temporary spawn, tin and copper are both within 500 m (tin 23%, copper 18% of spots, before the 0.4 boulder share), so the Bronze tier stands. **No coal within 4 km of either spawn** (granite and fold belt; coal lies only in basins), so early forge fuel is charcoal, which backs keeping charcoal at the campfire. **Risk:** the tile spawn has no ore within 1 km; this matters only if the spawn moves back.

**Open for Dave (only these two):**
1. **Hot-stone numbers** (the estimate: warmth fading over 1 game hour after 10 game minutes heating).
2. **Brick at the bronze gate.** A Bronze - Hammer is tier 3 and bricks come from the campfire, so brick building arrives at the bronze gate. Consistent; change only if Dave wants brick later.

## 13. Numbering plan

Jamie owns numbers. **Counters on main (11 Nov 2026, bd3146aa): next item 896, next gathered item 1177, next recipe 407, next blueprint 186, next structure state 230 (229 is BOG_STATE, the bog iron deposit row, in code only), protocol 106.** Read the `next_number` fields in items.json, gathered.json, recipes.json and blueprints.json before taking one; states have no counter, so take the highest `state` in structures.json plus one, skipping 229. The history below is the plan as it was reserved.

History: items 628 to 756 and recipes 348 to 352 were taken by the buildables batches; this section then asked for item 757, recipe 353, blueprint 150, state 188.

- **Items:** about 100 new items (tools and weapons about 50, clothing about 20, furniture/stations about 20, materials about 10). Request a block at **757**, size 110. Two NEW rows reuse existing ids and need no new number: Bone - Needle is `sewing_needle` 49; Standing torch is 543.
- **Recipes:** from **353**, size 110.
- **Blueprints and states:** stations only: Kiln, Tanning rack, Drying rack, Preserving jar, Oil press, Smoker, Root cellar, Sap tap, Skep, Anvil and a few more: about 15 blueprints from **150**, about 30 states from **188**. Furniture, lights, garden and water are in the buildables ranges.
- Renames need no new numbers.
- **Taken, building tier ladder (section 17; data PR #966, 10 Nov):** items **853 to 891** (Bark shingle 853, Wooden shingle 854, Clay roof tile 855, Limestone 856, Lime powder 857, Concrete 858, Iron band 859, Mixer kit and piece 860 and 861, then the Engineered and Fortified kits and pieces 862 to 891), recipes **399 to 404**, blueprints **170 to 185**, states **210 to 228**. Next free after it was item 892, recipe 405, blueprint 186, state 229. Since taken: 892 and 893 (dark lanterns, #977), 894 Bronze nails and 895 Bronze hinges with recipes 405 and 406 (#1001), state 229 (bog iron, #996).

## 14. Checks

- Every ladder row in section 2 has a row per tier in sections 3 and 4, except where ruled out.
- Every renamed item appears once in section 9; the exceptions are in "Not renamed".
- No raw material carries a tier word. No two live items share a display name unless one object in two states.
- Open points are in section 12 and nowhere else.


## 17. Building tier ladder: seven quality words (Dave, locked 10 Nov; supersedes every Thatch, Log, Wooden, Stone and Brick tier word on building pieces above)

**Crude, Rustic, Refined, Sturdy, Superior, Engineered, Fortified** (all seven live on main, 11 Nov). Applies to building pieces only: Foundation, Wall, Doorway, Window, Ceiling, Roof, Roof corner, Stairs, Pillar, Fence, Gate (Double doorway follows Doorway). Metal pieces keep Iron and Steel. Furniture, stations, containers, tools and weapons keep material words (Wooden - Bench, Stone - Forge, Brick - Forge, Stone - Workbench, Stone - Axe). Palisade and Palisade gate are plain names. Single-material stone items (Well, Cistern, Raised cistern, Torch pillar, Brazier, Planter) drop the tier word. Workbench bodies: Wooden - Workbench (level 1), **Carpenter's bench** (level 2, replaces Log - Workbench), Stone - Workbench (level 3). Log - Bench, Table and Trough are dropped; Log - Seat becomes plain **Seat**. Rustic - Foundation is a 2 m cube log frame (four legs, criss-cross bracing, logs on top).

**Wall, ceiling and roof by tier** (roof is a different material from the wall; no concrete roof): see wood_tier_note.md table. Roofs: Crude thatch, Rustic bark shingle, Refined wooden shakes, Sturdy stone slab, Superior and Engineered clay roof tile (unparks "roof tiles"); Fortified has no roof. Ceilings: plank joists Refined to Superior, log poles Rustic, concrete slab Engineered, none for Crude and Fortified.

**New rows (numbered and live: items 853 to 891, see section 13):** Bark shingle, Wooden shingle, Clay roof tile, Limestone, Lime powder, Concrete, Iron band, Mixer, and the Engineered and Fortified pieces. The earlier "Lime - Lime mortar" row is replaced: Lime powder, no lime mortar. Clay mortar stays the only mortar.

**Roof tiles:** the master list parks "roof tiles"; this ruling unparks them as a Kiln product (Clay roof tile).
