# Tree species uses, version 1 (Guru, 2026-10-23 ~11:30 UTC): Dave said yes but keep it simple (answers species-uses-1 to 4). Replaces the draft table in TREE_SPECIES_USES_DRAFT.md.
## What Dave decided (10:18 to 10:24 UTC)
- Yes, species matter, but do not overcomplicate it; not too simple either.
- Hardness affects how long it takes to FELL a tree: hardwoods are harder but THINNER; softwoods are much THICKER around. So hits to fell are similar-to-fewer for hardwood: species-uses-3 NO: do not add extra axe wear for hard woods ("they might be harder, but you don't have to hit them as much because they are smaller").
- Burn time: hardwood burns long, softwood burns fast, even though softwoods are bigger.
- Logs are named after their trees. Softwoods suit pillars and beams (big, round, straight; cedar for those too); some hardwoods (birch) suit a different type of board. Ask Tyler: which wood is best for what, with a small set of numbers, not micromanagement.
- Firewood and wooden blocks of different species stay in separate piles (no mixed piles). Foundations are exempt from the rot-proof rule: "a foundation is a foundation" (video game logic).
## Research (general sources, checked 2026-10-23)
- Janka hardness (lbf, wikipedia.org/wiki/Janka_hardness_test): white oak 1360, red oak 1290, American beech 1300, yellow birch 1260, sugar maple 1450, white ash 1320, black walnut 1010, hickory 1820 (all hardwoods, about 1000 to 1800); Douglas fir 660, eastern white pine 380, western red cedar 350 (softwoods, about 350 to 660). Hardwood is about 2 to 4 times as hard.
- Firewood heat (almanac.com, gallons of fuel oil per cord): oak, beech, yellow birch, sugar maple, white ash HIGH (200 to 250); white birch and red maple MEDIUM (150 to 200); Douglas fir MEDIUM; pine, spruce, western red cedar LOW (100 to 150). Softwoods burn faster and give more sap, pitch and creosote: good for kindling and short fires.
- Not found in these sources (from general knowledge, NOT verified here): rot resistance (white oak, sweet chestnut and cedar are durable; pine, spruce, beech and birch rot fast outdoors), and workability (pine and spruce are straight and easy to saw; oak is harder to work). Treat these two as a design choice, not a measured fact.
## The small set of numbers (1 to 5, tunable in data; two classes plus a few exceptions)
Class HARDWOOD: trunk thin, felling 8 hits, burn 4 to 5 (long), board type FINE boards (furniture and floors), beams short and strong.
Class SOFTWOOD: trunk thick, felling 12 hits, burn 2 (fast), board type PLANK boards (rough planks, framing), pillars and beams (big round straight logs), cedar also rot-resistant.
| Tree | Class | Hits to fell | Burn | Best use |
| oak | hardwood | 8 | 5 | fine boards, strong short beams |
| beech | hardwood | 8 | 5 | firewood, fine boards |
| birch | hardwood | 7 | 4 | fine boards (Dave: a different board), firewood, bark for twine and tar |
| maple | hardwood | 8 | 5 | fine boards, floors |
| ash | hardwood | 8 | 5 | tool handles, fine boards |
| walnut | hardwood | 8 | 4 | fine boards (valuable) |
| sweet chestnut | hardwood | 8 | 4 | outdoor posts, shingles |
| alder, rowan, apple, pear, cherry | hardwood | 6 to 7 | 4 | small boards, tool parts |
| scots pine | softwood | 12 | 2 | planks, pillars, beams, tar |
| spruce | softwood | 12 | 2 | planks, pillars, beams |
| balsam fir | softwood | 11 | 2 | planks, torches, resin |
| cedar (add later if a cedar tree exists) | softwood | 12 | 2 | pillars, beams, rot-resistant |
| willow | hardwood (soft) | 5 | 2 | baskets, twine, light frames |
Hits to fell are tuning numbers; Sal and Steve set them from real tree size so thick softwoods take more hits and thin hardwoods fewer (Dave's logic). Axe wear stays the SAME per hit for every species (no extra wear for hardwood).
## Rules (simple)
1. Logs, blocks and firewood carry the species in their name ("Oak logs", "Pine logs"); recipes can say hardwood log or softwood log.
2. Boards: softwood logs make plank boards, hardwood logs make fine boards (birch included); pillars and beams prefer softwood logs.
3. Burn time of firewood by class (hardwood long, softwood short); different species stay in separate piles; no mixed piles.
4. Rot-proof rule for piers and wet posts (oak, chestnut, cedar, alder) EXCEPT foundations: a foundation is a foundation.
5. Not simulated now: rot rate, grain, shrinkage. Later if Dave asks.
## Owners and next steps
Sal: put class, hits to fell and burn in data (flora/trees data), recipes by class. Steve: felling hits uses trunk size. Kathleen: nothing new. Guru: no card needed (Dave answered; this is the small set he asked for). Open only if Dave wants to change a number.
