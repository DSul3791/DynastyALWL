# Coins, prices and reputation (Radar, 2026-10-21, build 537)

## The ladder (all tunable in data/items/coins.json)
1 bronze = 10 copper. 1 silver = 10 bronze = 100 copper. 1 gold = 10 silver = 1000 copper.
I chose a plain tens ladder over a historical 12/20 one because Dave reads totals at a glance, and the game has no feudal accounting to justify pounds, shillings and pence. The purse stores one number of copper and shows it richest coin first ("2 silver, 3 bronze, 4 copper"); change is made automatically. Coins are not pack items and weigh nothing. Every `value` in items.json is in COPPER.

## Price anchors (what one copper buys)
| Thing | Copper | Shown as |
|---|---|---|
| A stick or a stone | 1 | 1 copper |
| Loaf of bread, a pint of ale | 3 | 3 copper |
| A hot meal (roast meat 14, roast fish 12, roast forage 6) | 6 to 14 | about 1 bronze |
| A bed in an inn's common room for a night | 15 | 1 bronze 5 copper |
| A day's unskilled labour (carry, chop, dig) | 30 | 3 bronze |
| A day's skilled labour (smith, carpenter) | 60 | 6 bronze |
| Stone axe 20, stone knife 12, wooden spade 15 | 12 to 20 | 1 to 2 bronze |
| Hide cloak 25, backpack 40, lean-to kit 30 | 25 to 40 | 3 to 4 bronze |
| Iron pickaxe 120, iron spade 90 | 90 to 120 | about 1 silver |
| Steel pickaxe 300, steel spade 140 | 140 to 300 | 1.5 to 3 silver |
| A good iron sword (planned) | 600 | 6 silver |
| A steel sword (planned) | 1500 | 1 gold 5 silver |
| A pack mule (planned) | 2500 | 2 gold 5 silver |
| Stone forge kit 120, blacksmithy 600, large forge 900, master forge 3000 | | 1 silver to 3 gold |
Wages follow from this: a quest that fetches 4 logs (worth 16) pays 30, a bit more than the goods, because the NPC pays for your time. Rule of thumb for quest rewards: 1.5 to 2 times the goods' value, up to 5 times for danger. Selling to a trader pays `sell_share` 0.5 of value (not built yet; no trading screen).

## Reputation
Each NPC keeps a score per player (data/npcs/reputation.json). A dialogue effect `add_rep` adds points for that NPC. Ranks: Stranger 0, Known 2, Friend 5, Trusted 10 (cap 30). Rank effects: friendlier greeting barks (`greeting_friend`, `greeting_trusted`), better prices (Friend pays 10 percent less, Trusted 20 percent less; today that applies to trainer lessons), extra choices and quests by condition (`min_rep`, `rank`). Hob: the firewood quest now pays 2 roast forage and 5 copper and adds a point; at one point "Any more work?" offers four logs for 3 bronze; at Friend he gives a stone knife once. The Tab screen has a Reputation list (NPC name and rank word). Shown to the player with a message when a rank changes.

## Where it lives
Purse and reputation are saved in characters.json (`coins`, `rep`). Protocol 61: purse(copper) and reputation(ids, names, points). Coin rewards (`give_item` coin_copper, coin_bronze, coin_silver, coin_gold) go into the purse and show in the 'you got' feed as that coin. Hover text now shows an item's value in coins and key hints.
Open for Dave: do shopkeepers buy and sell with coins (a trade screen), and should death drop part of the purse onto the remains? Neither is built.

## Trading (build 546, Dave 2026-10-21)
Traders sell to you at a markup and buy from you at a discount over an item's value (copper). Plain stranger, no luck: you pay 130 percent of value (charged up to a whole copper), the trader pays 55 percent (paid down, at least 1 copper). Three things move both prices the same way, as a "shift": reputation rank (Stranger 0, Known +0.04, Friend +0.08, Trusted +0.12), charisma (+0.01 per point, -10 to +10 so +-0.10) and luck (0.04 per point times a quarter, so +-0.10 at 10). The trader charges 130 percent minus the shift, never under 105 percent, and pays 55 percent plus the shift, never over 90 percent, so buying back always costs more than you were paid. Worn tools pay in proportion to their remaining life, old food by freshness, worthless things nothing. A trader buys only the item kinds listed in data/npcs/shops.json. Today Hob trades (the "What do you sell?" choice opens his window: buy on the left, sell on the right, hover text on every row). His stock is unlimited for now. Charisma is a stat set at character creation (the attribute already exists; a later source could be clothing and training). Death: the whole purse lies with the remains. Banking and family coffers are written up as ideas in DESIGN_IDEAS.md (Banking, family coffers and big deals).

## Demand (build 548)
A trader tires of buying the same thing: each unit sold lowers the price for that item by 3 points (of 100), down to 30 percent, and it comes back 4 points a minute. Stops selling sticks by the hundred. data/items/coins.json trade.demand. Per NPC, not saved.
