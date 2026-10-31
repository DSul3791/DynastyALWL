# First-hour food (Sal, 2026-10-31)

Numbers read from data/items/vitals.json, drops.json, spoilage.json, weights.json and the orchard rows (fruit_tree). A game day is one real hour; the world starts on day 100, early summer.

## The hunger clock
- Stomach holds 2400 kcal (cap) plus 25 percent overeat (3000). A new character starts full.
- Burn per game day (real hour): rest 22 kcal per kg of body weight x 75 kg = **1650 kcal**, plus work 1500 x exertion (0 to 1). Ordinary walking and chopping (exertion about 0.3 to 0.6) burns **2100 to 2550 kcal an hour**. A full stomach therefore lasts **about 55 to 70 minutes** of normal play, and about 45 minutes of hard work. This matches the "hunger reaches 0 near 55 minutes" in the test log: it is the design, not a bug.
- Empty stomach: weight drops (7700 kcal per kg), health stops regenerating; nothing kills (vitals.json note). So a player who lights the first fire at minute 15 to 20 does not starve; he is hungry from about minute 55.
- One bite takes 0.8 s (eat_pace_ms 800).

## What a new player can eat in the first hour, near the spawn (early summer)
| Food | Where | kcal each | How many to fill the stomach (2400) | Notes |
|---|---|---|---|---|
| Raspberries, blueberries, strawberries | bushes (one E gives up to 150 per bush; scaled by plant size) | **90** (suffix "berries") | 27 berries | **The berry number looks too generous**: 150 berries x 90 kcal = 13,500 kcal per bush, and they weigh 4 g each. See the question below. |
| Early summer apples | orchard near the spawn (30 to 80 per tree, 5 per press, limited by pack weight) | 110 | 22 apples | weight 0.15 kg each: 22 apples = 3.3 kg. Spoil in 72 game hours (3 real hours) |
| Summer apples, summer pears, plums, sour cherries | orchard | 120, 105, 70, 75 | 20, 23, 34, 32 | spoil in 7, 4, 4 and 2 game days |
| Crab apples, wild pears, cherries (wild) | forest trees | 120 (suffix "apples", "pears", "cherries") | 20 | autumn |
| Hazelnuts, acorns | trees | 200, 150 | 12, 16 | autumn only |
| Raw meat (rabbit gives 1 to 2) | hunt with the spear, dress with the knife | 250 raw, 700 roasted | 3.4 roast | needs a fire; raw meat makes you sick |
| Fish (trout) | pond with a rod or net | 220 raw, 650 roasted | 3.7 roast | needs a fire |
| Roast forage (berries/nuts/roots at the fire) | fire | 400 | 6 | the starter cooked item |
| Smoked fish, dried apples, trail bread | later | 700, 280, 950 | | for storing |

## Timeline of a typical first hour
- Minute 0: stomach 2400, thirst full.
- Minute 15 to 20: first fire (needs about 17 minutes by my estimate).
- Minute 20 to 40: berries and apples are free calories any time; a rabbit gives one roast meal.
- Minute 55 to 70: stomach near empty with normal activity. By then the player must have eaten once: any of the foods above refills a third to the whole stomach in a few bites.

## Findings and data changes
1. **Apples are about right:** 110 to 125 kcal is a real apple; one bite is 5 percent of the stomach, a handful of 8 to 10 is a snack, 22 a full meal. No change.
2. **Early apple rots in 3 real hours:** the item description now says "it keeps only 3 game days" (and the others name "game days" as the unit). The hint "Ripe fruit spoils fast. Eat it soon" fires when fruit is in the pack.
3. **Berries at 90 kcal each are out of scale** (a real berry is about 1 to 5 kcal; the other fruit here use realistic per-piece numbers). Because a bush gives 150 at once, one bush can fill the stomach five times over in summer, which makes starvation impossible and apples and meat pointless in summer. **Question for Dave: scale berries to about 5 kcal each (a handful of 20 is a snack, a bush of 150 is 750 kcal, a third of a stomach)?** I did not change it because the berry numbers are Dave's (vitals.json by_suffix, Dave's 2026-10-21 hunger design).
4. Starting food: the character starts with a full stomach and nothing in the pack; nothing in the data blocks the first meal.
