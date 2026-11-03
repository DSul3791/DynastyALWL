# First-day economy: cheap goods and sell lots (Sal, 1 Nov 2026)

**Dave's rule (2 Nov, replaces the 1 Nov one):** an average person picking and scraping all day earns a poor wage, barely enough for a meal and maybe a place to sleep that night. About 195 copper for 4 hours was too much.

## Target
4 hours of full-time picking pays about 40 to 60 copper. At the trader a meal (roast_forage, value 6) costs about 8 and a night's bed or lean-to rent is the other 30 to 40, so one day of gathering buys one meal and a bed and nothing else. Clothing, a waterskin or a metal tool (waterskin about 20, hide cloak about 33, iron spade about 117) take several days of picking, or a craft. Crafted goods and lumber pay more per hour than picking (skilled work); see the lumber note at the bottom.

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
| stone | 6 | 30 | 0.20 | 48 |
| stick | 12 | 60 | 0.20 | 48 |
| leaves | 12 | 60 | 0.20 | 48 |
| plant_fibre | 10 | 50 | 0.20 | 48 |
| bark | 6 | 30 | 0.20 | 48 |
| nettles | 8 | 40 | 0.20 | 48 |
| feather | 1 | 6 | 0.17 | 40 |
| soil | 4 | 20 | 0.20 | 48 |
| clay | 4 | 20 | 0.20 | 48 |
| sand | 4 | 20 | 0.20 | 48 |
| gravel | 4 | 20 | 0.20 | 48 |
| wheat_seeds | 3 | 15 | 0.20 | 48 |
| firewood_soft | 3 | 12 | 0.25 | 60 |
| wooden_pin | 3 | 12 | 0.25 | 60 |
| nails | 3 | 15 | 0.20 | 48 |

Lots are sized so every gathered item pays about 0.2 copper a minute (about 48 in 4 hours); the bigger lots weigh at most 30 kg (stone) so they can be carried. Mixed gathering earns the same as the best single item because a player spends the minutes once.

## Applied (2 Nov)
`sell_lot` raised on the rows above in `data/items/items.json` (stone 5 -> 30, stick 15 -> 60, seeds 4 -> 15 and so on). Items with value above 1 are not touched. The 1 Nov lots (stone 5 and so on) gave about 195 copper in 4 hours.

## What is not covered
Crafted goods (twine, kits, tools) sell at their value x 0.55 with demand fall-off; a full crafting-for-sale check is in `ECONOMY_PLAN.md`. Other traders and player-to-player trade are out of scope.

## Lumber route (recheck 1 Nov 2026, after all-trees-logs and softwood boards)
Every felled tree now gives logs, and spruce/pine saw to 7 lumber in 5 s. Lumber is worth 8, so Hob pays about 4 each: roughly 30 copper per spruce log, more than any gathered item per minute. Hob's purse (300 cap, +100 per game day = one real hour) still limits income, so this fills the purse fastest rather than breaking the economy. No change made; if Dave wants it slower, lower lumber `value` (8) or set a `sell_lot` on it. Eight items_check steps pass on the daily at ab8d5b9b.
