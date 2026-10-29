# Armour ladder (proposal, nothing built)

Dave's answer (2026-10-22): armour starts with cloth, then cloth with stick or bark, hide, leather, leather banded, "and many more along those lines". This page continues that ladder through metal in the same spirit. Numbers are placeholders for the balance pass; every rung is data (clothing.json / items.json), no new code per rung.

## Rules that stay
- Same six body slots as clothing.json (head, body, legs, feet, hands, back). Armour is a kind of clothing: it also gives warmth, weight and wear.
- Each piece has: `armour` (share of damage taken off, 0 to 0.8 per piece, summed and capped at 0.75), `weight_kg`, `durability`, `warmth`, and a repair recipe.
- More ingredients = better piece (crafting rule): a plain piece is a rung; added padding or banding lifts it to the next.
- Boar and bear stay on hold until at least rungs 1 to 4 exist.

## The ladder (body piece shown; head/legs/feet/hands scale at about 0.5/0.6/0.3/0.2 of body value)
| # | Rung | Made from | Armour | Weight kg | Notes |
|---|------|-----------|--------|-----------|-------|
| 1 | Cloth | woven cloth | 0.05 | 1.5 | warm, no real protection |
| 2 | Padded cloth | cloth, stuffing, cordage | 0.10 | 3 | soaks blunt blows |
| 3 | Cloth with sticks | cloth, split sticks, cordage | 0.14 | 3.5 | Dave's "cloth, stick, bark" |
| 4 | Cloth with bark | cloth, bark plates, cordage | 0.17 | 4 | bark by tree species (birch light, oak heavy) |
| 5 | Hide | raw hide, cordage | 0.20 | 5 | stiff, rots if wet and left |
| 6 | Cured hide | tanned hide, cordage | 0.26 | 5 | needs the tanning rack |
| 7 | Leather | leather, thread | 0.32 | 6 | the first good rung |
| 8 | Studded leather | leather, iron studs | 0.38 | 7 | |
| 9 | Leather banded | leather, wooden or iron bands | 0.44 | 8 | Dave's "leather banded" |
| 10 | Brigandine | leather, riveted iron plates | 0.52 | 10 | |
| 11 | Chain (iron mail) | iron rings | 0.58 | 12 | forge, long work |
| 12 | Scale | iron or steel scales on leather | 0.62 | 13 | |
| 13 | Splinted / banded iron | iron splints and leather | 0.66 | 14 | |
| 14 | Steel mail | steel rings | 0.68 | 11 | lighter than iron |
| 15 | Half plate | steel plates over mail | 0.74 | 18 | Master forge |
| 16 | Full plate | fitted steel plate | 0.80 | 22 | Master forge, admin-gated at first |

## Notes for later
- Damage types (cut, pierce, blunt) can split `armour` into three numbers; rungs 2 to 4 are good vs blunt, 11 to 14 vs cut.
- Weight and exertion: heavy rungs raise strain (sleep/exertion design) and slow movement beyond the carry limit.
- Beasts: boar tusk (pierce) is stopped well by hide and leather; bear (cut and blunt) needs rung 9 or better to be survivable.
- Repair uses the tool-repair rule: iron and steel need a forge; a smith mends for coin.
- Open: whether helms, gauntlets and boots follow every rung or only some (suggest: head and feet from rung 5, hands from rung 7).
