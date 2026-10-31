# Animal product chain (Sal, 2026-10-31)

Data added this round: Tallow, Soap, Leather strap, Milk, Butter, Cheese (items 413 to 418, recipes 275 to 280). Everything else in the chain already existed.

| Source | Raw drop | Process | Product | Used by |
|---|---|---|---|---|
| any large animal | hide | scrape (hide scraper, needs flint), tan (tannin bark + water, campfire pot) | Processed hide, Leather, Heavy leather, Fine leather | leather cap, jerkin, gambeson, armour, **Leather strap** (leather + stone knife, 2 straps) |
| any animal | animal fat | render in a campfire pot (2 fat) | **Tallow** | Tallow candle (3 candles from 1 tallow + 1 fibre), **Soap** (2 tallow + potash) |
| any animal | bone | hand or tool | bone arrow, hide glue (with hide) | bows, joining |
| deer, boar, bear, wolf | sinew | hand | sinew cord, fur clothes | clothing recipes |
| birds | feather, down | hand | arrows, down for warm clothes | arrows, wool/fur tier clothing |
| wild sheep | wool | hand (spin later) | wool tunic, trousers, cap, mittens | CLOTHING_WARMTH.md |
| deer, moose, reindeer | antler | hand | tool handles, charms | future tools |
| boar | tusk | hand | charms, carving | future |
| bear, lynx, badger, wolf | claw | hand | charms | future |
| porcupine | quill | hand | pins and decoration | future |
| seabirds, wild birds | egg | cook | boiled egg, egg dishes | FOOD_VARIETY.md |
| tame cow, goat, sheep | **Milk** | churn (3 milk, by hand) / press (4 milk + salt, campfire pot) | **Butter**, **Cheese** | dishes, trade |

Milk, Butter, Cheese and Leather strap are `future` items: there are no domestic animals and no leather source yet. Tallow and Soap are obtainable now (animal fat from any kill, potash from saltbush ash).

## What is not here, by design
- Domestic animals (cows, goats, sheep, chickens): need an animal code lane (taming exists for horses only: animals.json horse `tame`), pens and feed. ANIMAL_SPEC.md lists them as later work.
- Spinning and weaving (wool to cloth): tailoring is by hand in the current design (Dave); the wool clothes are made straight from wool.
- Bone tools: the sewing needle was retired by Dave (25 Oct); bone awl and bone knife are possible later but add tools needing held models.

## Real-world basis (general knowledge, not individually sourced)
Rendering fat into tallow for candles and soap, tanning hide with oak bark tannin, hide glue from boiled hide, sinew as thread and bowstring, down for insulation, and butter and cheese from milk are all traditional uses. The recipe quantities are game numbers, not historical ratios.
