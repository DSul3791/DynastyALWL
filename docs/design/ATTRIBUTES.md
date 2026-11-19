# Character attributes: 0 to 100

**Status:** Dave's ruling, 19 Nov 2026 (project thread "Fix attributes rolling below zero"), after two new characters showed Luck below zero. Built on `dev`; nobody has played it yet.

**Dave's words:**
- "all attributes should be between 0 and 100 acting like a percentage. this keeps math simple and the numbers easy for people to understand."
- "I would like it to be a graded random assignment some how so its super easy to get 0-50% harder to get 51-75% and even harder to get 76-100%"
- On three or five grades: "I like it keep that 5" (five weighted grades, 0-40 most likely; replaced the same evening).
- Then: "I would assume the most common attribute number people will ever have should be between 40-60 making it like an average attribute but lower or higher like 20-39 or 61-80 should be uncommon and 0-19 and 81-100 should be even rarer but not impossible."
- On fitness: "no fitness should just start rolled in the middle range" and "but only for player characters. when rolling NPCs they could be all over the place".

## What it does
- Every attribute (luck, fitness, strength, memory, dexterity, perception, charisma) is a whole number from 0 to 100, shown as a percent on the Tab screen. The server keeps every value inside 0 to 100 wherever it is set, loaded or read (`src/shared/attributes.gd`).
- A new player character rolls every attribute once on the game server (`data/items/attributes.json`): a band is picked by weight, then a whole number uniformly inside it.

| Values | Share of characters |
|---|---|
| 0 to 19 | 5 % |
| 20 to 39 | 20 % |
| 40 to 60 | 50 % |
| 61 to 80 | 20 % |
| 81 to 100 | 5 % |

The average is 50 and the shape is symmetric: half of all rolls land 40 to 60, 1 in 20 lands 0 to 19 and 1 in 20 lands 81 to 100.
- A player's fitness instead rolls evenly from 40 to 60 (`player_bands`). NPCs have no attributes yet; when they get them, `Attributes.roll_character(rng, cfg, false)` gives them the full roll, fitness included.
- 50 is an average person. Below 50 hinders, above 50 helps; each 5 points does what one point did on the old -10 to +10 scale, so luck, fitness, skill-trait and trade tuning keeps its meaning (luck 100 takes a 50 % chance to about 63 %, luck 0 to about 37 %).
- Fitness training is rescaled so it takes the same play time as before (200 XP a point, 5 points for the old 1,000).
- Tools and unit tests build the item server without the game server, and there a new character starts at 50 in everything (`roll_new_characters` off), so their numbers do not move from run to run; `terrain_server.gd` turns rolling on.
- Old saves: a `characters.json` from before this change (version 1) is converted once when the server loads it (new = 50 + 5 x old, so old 0 is 50 and old -3 is 35); the next save writes version 2. A value outside the range in any save is clamped. An older build cannot read a version 2 file.

## For Dave (assumed on his behalf, provisional)
- ATTR-1: 50 is the neutral point, so a character with luck 20 is unlucky and one with 80 lucky.
- ATTR-3: existing characters keep their attributes, moved onto the new scale; nobody is re-rolled, and attributes they never had read as 50.
- ATTR-4: the bell weights 5/20/50/20/5 are the coordinator's reading of Dave's description (one table in `attributes.json` to tune).
- The character creator's draft attribute screen (`src/client/character/character_record.gd`, point buy and dice on -10 to +10) is not connected to the game and was left as it is; it should move to this scale when it is built.
- Fitness no longer starts at a fixed 75 (FIT-1's "a fit 20 year old"); Dave's 19 Nov words replace it.
