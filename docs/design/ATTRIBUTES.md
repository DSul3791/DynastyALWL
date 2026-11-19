# Character attributes: 0 to 100

**Status:** Dave's ruling, 19 Nov 2026 (project thread "Fix attributes rolling below zero"), after two new characters showed Luck below zero. Built on `dev`; nobody has played it yet.

**Dave's words:**
- "all attributes should be between 0 and 100 acting like a percentage. this keeps math simple and the numbers easy for people to understand."
- "I would like it to be a graded random assignment some how so its super easy to get 0-50% harder to get 51-75% and even harder to get 76-100%"
- On three or five grades, after the five below were put to him: "I like it keep that 5".

## What it does
- Every attribute (luck, fitness, strength, memory, dexterity, perception, charisma) is a whole number from 0 to 100, shown as a percent on the Tab screen. The server keeps every value inside 0 to 100 wherever it is set, loaded or read (`src/shared/attributes.gd`).
- The creation roll (`data/items/attributes.json` `roll_bands`): a band is picked by weight, then a whole number uniformly inside it.

| Values | Share of characters |
|---|---|
| 0 to 40 | 45 % |
| 41 to 60 | 25 % |
| 61 to 75 | 15 % |
| 76 to 90 | 10 % |
| 91 to 100 | 5 % |

So about 70 % of characters get 60 or less and 1 in 20 gets over 90.
- 50 is an average person. Below 50 hinders, above 50 helps; each 5 points does what one point did on the old -10 to +10 scale, so luck, fitness, skill-trait and trade tuning keeps its meaning (luck 100 takes a 50 % chance to about 63 %, luck 0 to about 37 %).
- Fitness keeps its start value (Dave 18 Nov, provisional FIT-1: "characters should not start out feeble"): 75, the old +5. Its training is rescaled so it takes the same play time as before (200 XP a point, 5 points for the old 1,000).
- Old saves: a `characters.json` from before this change (version 1) is converted once when the server loads it (new = 50 + 5 x old, so old 0 is 50 and old -3 is 35); the next save writes version 2. A value outside the range in any save is clamped. An older build cannot read a version 2 file.

## For Dave (assumed on his behalf, provisional)
- ATTR-1: 50 is the neutral point, so a character with luck 20 is unlucky and one with 80 lucky. The other reading (0 = no help, nobody ever unlucky) would also fit "a percentage"; say if you prefer it.
- ATTR-2: only luck is rolled today, as before; it is the only attribute the server gives a new character. Strength, memory, dexterity, perception and charisma start at 50 (average) until their design says how they are set. Fitness starts at 75 (FIT-1).
- ATTR-3: existing characters keep their luck, moved onto the new scale; nobody is re-rolled.
- The character creator's draft attribute screen (`src/client/character/character_record.gd`, point buy and dice on -10 to +10) is not connected to the game and was left as it is; it should move to this scale when it is built.
