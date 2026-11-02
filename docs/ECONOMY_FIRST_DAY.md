# First-day economy: cheap goods and sell lots (Sal, 1 Nov 2026)

**Dave's rule (1 Nov):** cheap easy things must be really inexpensive. One full day of gathering and selling earns enough copper to buy basic food, drink, clothing and perhaps a basic metal tool, and no more.

## Target
Prices at the trader (value x 1.3, rounded up; `data/items/coins.json` trade): three meals (roast_forage, value 6) about 24, a waterskin (15) about 20, clothing (hide_cloak, 25) about 33, a basic iron tool (iron_spade, 90) about 117. **Total about 195 copper.**

## How income works in the code
- Hob pays value x 0.55, at least 1 copper per unit for anything worth a copper. At value 1 that is exactly 1 copper per unit, so before lots 40 sticks paid 40.
- `sell_lot` (items.json, default 1): units are sold in whole lots and one lot pays one unit price, so a lot of 15 sticks pays 1 copper.
- The demand fall-off (3 percent per unit, floor 30 percent) does not bite on value-1 goods because of the 1-copper minimum, so the lot is the only lever.
- Hob's purse is a second ceiling: cap 300 copper, refills 100 copper per game day, and a game day is one real hour (`purse_regen_per_day` in shops.json). A player can never draw more than about 300 + 100 per hour from one trader.

## Assumptions (Dave, please correct)
- **4 hours of play a day**, all of it gathering and selling. At 8 hours every total doubles.
- **Pick rates are guesses**, not measured: nothing has timed gathering. The server allows up to 12 picks a second when holding E, but walking between plants dominates. Change `RATES` in `tools/economy_first_day.py` and rerun to see the effect.
- Selling happens in bulk, the trader buys every kind (shops.json `buys`), and the player has the packs/trips to carry the stock.

## Table (4 hours, `python tools/economy_first_day.py 4`)
| item | picks/min (assumed) | sell_lot | copper/min | copper in 4 h |
|---|---|---|---|---|
| stone | 6 | 5 | 1.20 | 288 |
| stick | 12 | 15 | 0.80 | 192 |
| leaves | 12 | 15 | 0.80 | 192 |
| plant_fibre | 10 | 12 | 0.83 | 200 |
| bark | 6 | 8 | 0.75 | 180 |
| nettles | 8 | 10 | 0.80 | 192 |
| feather | 1 | 2 | 0.50 | 120 |
| soil, clay, sand, gravel | 4 | 5 | 0.80 | 192 |
| any `*_seeds` | 3 | 4 | 0.75 | 180 |
| firewood_soft | 3 | 5 | 0.60 | 144 |
| wooden_pin | 3 | 5 | 0.60 | 144 |
| nails | 3 | 10 | 0.30 | 72 |

Almost every item lands at 180 to 200 copper in 4 hours, the shopping list. Stone is the exception at 288: Dave asked for about 5 per copper, and 6 would give 240. Mixed gathering earns the same as the best single item because a player spends the minutes once.

## Applied
`sell_lot` lines added to the rows above in `data/items/items.json` (stone 5 from before). Nothing else changed. Items with value above 1 are not touched.

## What is not covered
Crafted goods (twine, kits, tools) sell at their value x 0.55 with demand fall-off; a full crafting-for-sale check is in `ECONOMY_PLAN.md`. Other traders and player-to-player trade are out of scope.

## Lumber route (recheck 1 Nov 2026, after all-trees-logs and softwood boards)
Every felled tree now gives logs, and spruce/pine saw to 7 lumber in 5 s. Lumber is worth 8, so Hob pays about 4 each: roughly 30 copper per spruce log, more than any gathered item per minute. Hob's purse (300 cap, +100 per game day = one real hour) still limits income, so this fills the purse fastest rather than breaking the economy. No change made; if Dave wants it slower, lower lumber `value` (8) or set a `sell_lot` on it. Eight items_check steps pass on the daily at ab8d5b9b.
