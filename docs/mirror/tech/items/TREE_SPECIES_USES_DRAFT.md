# Tree species and what they are good for: first draft (Guru, 2026-10-23 04:00 UTC; Dave 03:57)
Dave: "differnet trees start to become more valuable for certain things". Logs are named Treename_Logs, so the species travels with the log. Draft only; Sal uses it later. No building tonight.
## Species in the game (data/tables/flora.json): oak, beech, birch, scots pine, spruce, alder, willow, rowan, wild apple, wild pear, wild cherry, sweet chestnut, walnut, maple, balsam fir, hazel (shrub); fantasy: mirrorbark, wardpine, hearthwood, everember, witness tree (left out of v1).
## Four numbers per species (1 to 5), real-world based
- HARDNESS (beams, tools, strength), BURN (firewood heat and length), ROT (outdoor life, wet use), WORK (easy to cut, plane, split).
| Species | Hard | Burn | Rot | Work | Best for |
| oak | 5 | 4 | 5 | 2 | strong beams, posts, foundations, wet use, tool handles |
| sweet chestnut | 4 | 3 | 5 | 3 | outdoor posts, fences, shingles (rots slowly) |
| beech | 4 | 5 | 1 | 3 | firewood, tool handles, indoor furniture |
| maple | 4 | 4 | 2 | 3 | floors, tools, furniture |
| walnut | 4 | 3 | 3 | 4 | fine boards, furniture (valuable) |
| birch | 3 | 4 | 1 | 4 | firewood (burns even green), bark for twine and tar |
| scots pine | 2 | 3 | 3 | 5 | planks, lumber, tar (resin) |
| spruce | 2 | 3 | 2 | 5 | planks, lumber, roof frames |
| balsam fir | 1 | 2 | 2 | 5 | light planks, torches, resin |
| alder | 2 | 2 | 5 (in water) | 4 | pilings, piers, docks (rot-proof under water) |
| willow | 1 | 1 | 1 | 5 | baskets, twine, light frames, fast fuel |
| hazel | 2 | 3 | 1 | 5 | wattle, fences, thin rods |
| rowan | 3 | 3 | 2 | 4 | tool handles, charms (later) |
| wild apple, pear, cherry | 3 | 4 | 2 | 4 | tool heads, handles, smoking and cooking fuel |
## How it could be used (small, one rule at a time)
1. Recipes take a class, not a species: "any log" still works; a better species gives a better result (stronger beam = longer span or higher brace value; a durable tool handle = less wear; good firewood = longer burn).
2. Cost: rare or hard species (oak, walnut) cost more effort to chop (more axe wear) so they feel valuable.
3. Pile and merge: firewood and blocks merge by species (beech firewood and pine firewood are different piles; no mixed piles).
4. Brace, pillar and beam values read HARD; rot time outside reads ROT; wooden pier posts need ROT >= 4 (oak, chestnut, alder).
## Plan for Dave (cards posted: species-uses-1 to 4)
