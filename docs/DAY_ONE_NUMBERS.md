# Day-one survival numbers

Worked out from `data/items/vitals.json`, `sickness.json`, `spoilage.json` and `exertion.json` (3 Nov 2026). One game day is 1 real hour (24:1 clock).

## Burn and capacity
| Thing | Value |
|---|---|
| Start weight | 75 kg |
| Rest burn | 22 kcal/kg/day = 1,650 kcal/day |
| Work burn | up to 1,500 kcal/day x exertion (0 to 1) |
| Light-work day (exertion 0.4) | about 2,250 kcal |
| Hard-work day (exertion 1.0) | about 3,150 kcal |
| Stomach cap | 2,400 kcal (+25% overeat) |
| Body fat | 7,700 kcal per kg, so a day's 800 kcal shortfall is about 0.1 kg |
| Water cap | 2,400 ml |
| Water burn | 1,000 ml/day rest + 1,200 ml/day x exertion |
| One drink at the water edge | 300 ml; filling a container 500 ml |

So a player needs about one full meal set a day (about 2,250 kcal at light work) and about 3 to 6 drinks.

## Early foods (kcal each)
roast_forage 400, raw_meat 250, wild_apples 80, crab_apples 60, nettles 20, seed_bundle 60. A day of light work needs about 5 roast_forage or 9 raw meat.

## Sickness (the harsh part)
`sickness.json`: sick for 24 game hours = 1 real hour, a symptom every 90 s, so 40 symptoms. The two symptoms alternate: vomit costs 80 kcal and 100 ml, diarrhoea 30 kcal and 150 ml.

- Total per episode: about 2,200 kcal and about 5,000 ml.
- That is a full day of food, and twice the water cap (2,400 ml).
- raw_meat spoils fast (`spoilage.json`: 18). One bad raw rabbit therefore costs far more than the rabbit gives (250 kcal).

Not changed here, because it is on Dave's review list. If he wants it gentler, the simplest knob is `symptom_every_s` 90 to 240: 15 symptoms, about 825 kcal and 1,900 ml per episode. Medicine and sleep (4x faster fade) already shorten it.
