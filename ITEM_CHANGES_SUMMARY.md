# Every item change on branch sal-items: one page for Dave (2026-10-30)

All changes are data on branch `sal-items` (plus two test edits). Nothing is on main. Everything new is marked `future` (not obtainable in the game yet). Nothing is deleted: retired items keep their numbers. Tests run after each change: validate_items, dishes, server_items, first_hour, inventory, stations, save_compat (all pass); the full suite and the animal, wolf and trade scenarios were not run.

## MAIN THING FOR DAVE: everything built from lumber waits on iron, and iron has no source
- Lumber is only made at the sawmill or with the hand saw, and both need iron. Iron has no way to enter the game yet (the ore items and smelting recipes exist, but nothing gives out ore). So nails, hinges, saw blades, lumber, fine board, chests, building sections, the ladder and the water wheel cannot be reached from a fresh start.
- Flint, obsidian, pyrite and coal also have no world source, which blocks the hide scraper, javelin, sickle and obsidian knife.
- **Proposed fix (one, reversible):** add a stone-age path to the first lumber: a **Stone wedge** (stone + stick, hand-made) that splits a log into 2 rough planks, no iron needed. Planks from the wedge cover the early builds; the sawmill and hand saw stay as the faster, cleaner iron-age route. Pair it with the code job already on the hand-off page (ore, flint, obsidian and coal gathering) so iron arrives mid-game, not at the start.
- Status: proposal only. Nothing built. Say yes and I will add the item and recipe as `future`.

## Renamed
- Oven (items 267, 268 and blueprint 14) is now **Basic Oven** (Dave).

## Retired (kept in the files, no longer used)
- Spade sizes 213 to 220 (medium and large wooden, stone, iron, steel). The base spades carry a bite size instead: stone 4 pieces, iron and steel 8, wooden 1 (Sal's mapping). Recipes 131 to 138 retired.
- Sewing needle 49 and its recipe (Dave, 25 Oct).
- Duplicate Kindling 278 (kindling already exists as gathered item 1080).
- Vice kit: recipe retired only (can no longer be crafted); placed vices keep working.

## Changed
- Hunter's stew, Forager's stew, Fish stew, Trail bread: 4 ingredients cut to 3. Hearty pottage and Roast Beast stay at 5 (special top-tier dishes). Food points unchanged.

## New items (all `future`)
| Number | Item | Kind |
|---|---|---|
| 279 to 281 | Flint, Pyrite, Obsidian | stones |
| 282 to 285 | Processed hide, Leather, Fine leather, Heavy leather | leather chain |
| 286 | Rivets | material |
| 287 to 289 | Copper ingot, Tin ingot, Bronze ingot | metals |
| 290 to 292 | Flour, Yeast, Salt | food materials |
| 293 to 296 | Hide scraper, Steel striker, Javelin, Obsidian knife | tools and weapon |
| 297 to 300 | Stone pickaxe, Sickle, Scythe, Wooden club | tools and weapon |
| 301 to 304 | Copper ore, Tin ore, Iron ore, Coal | ores |
| 308 to 310 | Clay jug, Herb salve, Splint | container and medicine (storage and medicine gap check) |
| 311 | Candle | light |
| 305 to 307 | Hide tunic, Hide trousers, Hide gloves | clothing (worn using the existing cloak, leggings and mittens drawings until Kathleen makes new ones) |

## New recipes (all hidden until discovered, none over 3 ingredients)
Kindling from sticks; Processed hide (hide, kept scraper); Hide scraper; Javelin; Obsidian knife; Steel striker; Rivets; Bronze ingot (copper ingot plus tin ingot, forge 2); Stone pickaxe; Sickle; Scythe; Wooden club; four smelting recipes (copper ore to ingot and tin ore to ingot at forge 1, iron ore to ingot at forge 1, steel from two iron ingots plus coal at forge 2); Hide tunic, trousers, gloves; Clay jug (clay 4), Herb salve (comfrey leaves 2, animal fat), Splint (sticks 2, twine).

## Documents on the branch
ITEM_GROUPS_AND_NAMES.md (all games grouped, names recommended, Part B decisions); ITEM_DECISION_LOG.md (every question and answer, what Dave must read at the top); ITEM_TIER_BALANCE.md; ITEM_ART_REQUESTS.md (for Kathleen, done on her branch); ITEM_CODE_HANDOFF.md (work only a code owner can do: species tag for lumber and beams, Clay Oven and Iron Stove, finishing the vice, ore gathering, quality grades).

## What is still not done
Lumber and Beam species merge; Clay Oven and Iron Stove; ore gathering in the world (the ore items exist but nothing yields them yet); the large and master forge cannot be built; quality grades; magic items; swords, maces, shields, slings and armour above hide; farming crops, windmill, animals, boats, carts, furniture, gliders and climbing items (all catalogued in ITEM_GROUPS_AND_NAMES.md, none in data).

## Combat items (added 2026-10-30, all `future`)
Items 312 to 331 and recipes 201 to 220: 4 swords/maces per metal tier, 5 shields, 8 armour pieces. Details and open choices in ITEM_COMBAT_TIER_LIST.md. Needs the ore and smelting code and the lumber source to be obtainable.
