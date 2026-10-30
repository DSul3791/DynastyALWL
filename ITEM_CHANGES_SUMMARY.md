# Every item change on branch sal-items: one page for Dave (2026-10-30)

All changes are data on branch `sal-items` (plus two test edits). Nothing is on main. Everything new is marked `future` (not obtainable in the game yet). Nothing is deleted: retired items keep their numbers. Tests run after each change: validate_items, dishes, server_items, first_hour, inventory, stations, save_compat (all pass); the full suite and the animal, wolf and trade scenarios were not run.

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
| 305 to 307 | Hide tunic, Hide trousers, Hide gloves | clothing (worn using the existing cloak, leggings and mittens drawings until Kathleen makes new ones) |

## New recipes (all hidden until discovered, none over 3 ingredients)
Kindling from sticks; Processed hide (hide, kept scraper); Hide scraper; Javelin; Obsidian knife; Steel striker; Rivets; Bronze ingot (copper ingot plus tin ingot, forge 2); Stone pickaxe; Sickle; Scythe; Wooden club; four smelting recipes (copper ore to ingot and tin ore to ingot at forge 1, iron ore to ingot at forge 1, steel from two iron ingots plus coal at forge 2); Hide tunic, trousers, gloves.

## Documents on the branch
ITEM_GROUPS_AND_NAMES.md (all games grouped, names recommended, Part B decisions); ITEM_DECISION_LOG.md (every question and answer, what Dave must read at the top); ITEM_TIER_BALANCE.md; ITEM_ART_REQUESTS.md (for Kathleen, done on her branch); ITEM_CODE_HANDOFF.md (work only a code owner can do: species tag for lumber and beams, Clay Oven and Iron Stove, finishing the vice, ore gathering, quality grades).

## What is still not done
Lumber and Beam species merge; Clay Oven and Iron Stove; ore gathering in the world (the ore items exist but nothing yields them yet); the large and master forge cannot be built; quality grades; magic items; swords, maces, shields, slings and armour above hide; farming crops, windmill, animals, boats, carts, furniture, gliders and climbing items (all catalogued in ITEM_GROUPS_AND_NAMES.md, none in data).
