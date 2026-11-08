# Young animals: size, gait, wobble, keeping close

Young come from the server (Dave 6 Nov 2026): a mother with young spawns 1 or 2 of them in spring and summer (animals.json `young`),
sent as species number + 100. They follow her at `follow_m` (3 m for most grazers, 4 for bears) and run when she runs. That part
already works and is not changed here. This note is the client look, behind the flag `young_gait` (default off).

## Size

- Row key `young_look.scale` in models.json: fawn 0.45, elk calf 0.42, moose calf 0.4, foal 0.55, donkey foal 0.5, cow calf 0.45,
  buffalo calf 0.4, kid 0.45, piglet 0.3, pup (dog, wolf) 0.35, bear cub 0.3, camel calf 0.5, elephant calf 0.35.
- Without the flag every young one is drawn at 0.5 (YOUNG_SCALE), as today. A species with its own young model (young_model, the
  calf) keeps that model's own size either way.

## Gait: shorter stride, higher step rate

- The walk and run clips are played at speed / travel_mps, where travel_mps is the clip's ground speed measured at the adult's size.
  A young one drawn at scale s covers s times the ground per step, so it plays at speed / (travel_mps x s): a foal at 0.55 walking
  beside its mother takes nearly twice the steps, with no foot sliding. Clamped to 3 times the clip's rate (adults: 2).

## Wobble under 10 days

- A newborn sways side to side on the Rig's roll, up to 6 degrees at birth and fading to nothing at `young_look.wobble_days` (10),
  quicker while walking than standing.
- The server keeps no birthdays (animals are not saved), so the client gives each young one a steady age from its id: 0 to 40 days
  in spring, 60 and more later in the year. About a quarter of spring young are under 10 days. When the server sends a birth day,
  `_young_age` reads it instead.

## Keeping 3 m from the mother

- Server-owned (`_step_young`, `follow_m`); every grazer row is already 3.0. Nothing to build on the client.

## Check on the PC

Run sheet m23: deer, horse and cow with two young each at age 3 days, walking. Pass: the young are smaller than their mother,
take quicker steps with no sliding, and sway.

## Part 2: size by age, and the mother (8 Nov 2026)

### Size by age (flag `young_gait`)

- `young_look` now has `scale` (at birth), `grown_scale` (at `grown_days`, 180) and `wobble_days`. The drawn size runs on a straight
  line between them by the young one's age (`_young_age`: 0 to 40 days in spring, 60 and more later in the year), set when it is
  first drawn. A fawn seen in late summer is visibly bigger than one seen in April.
- Checked across every species with young in animals.json (22). Each now has a row, from birth length over adult length:

| Species | Birth | 180 days | Species | Birth | 180 days |
|---|---|---|---|---|---|
| deer | 0.45 | 0.70 | buffalo | 0.40 | 0.62 |
| moose | 0.40 | 0.65 | pronghorn | 0.42 | 0.70 |
| horse | 0.55 | 0.75 | warthog | 0.25 | 0.55 |
| boar | 0.25 | 0.55 | wildebeest | 0.45 | 0.70 |
| bear, black bear | 0.25 | 0.45 | rhino | 0.35 | 0.50 |
| donkey | 0.50 | 0.72 | elephant | 0.32 | 0.42 |
| elk | 0.42 | 0.68 | camel | 0.50 | 0.68 |
| bighorn, mountain goat, chamois | 0.40 | 0.65 | kangaroo (joey out of the pouch) | 0.30 | 0.55 |
| cow (own calf model: keeps its own size) | 0.45 | 0.65 | mammoth | 0.32 | 0.42 |
| goat | 0.40 | 0.65 | | | |

- Before this, nine species with young had no row and drew every young one at 0.5 (bighorn, mountain goat, chamois, pronghorn,
  warthog, wildebeest, rhino, kangaroo, mammoth); a warthog piglet at half its mother was too big, a wildebeest calf about right.

### Following the mother (flag `young_follow`)

- The server already keeps each young one at its place beside its mother (`_step_young`, `follow_m` 3 m, 4 for bears) and runs it
  when she runs. It sends no link, so the client takes the nearest grown animal of its kind within 8 m as the mother (every 2 s).
- Grazing beside her (still, within 3 m), the young one looks to her head for 1.5 to 3 s every 6 to 15 s, through its look bones.
- Every 40 to 120 s it nurses for 6 to 12 s: it moves in under her flank (the Rig, at most 1 m, as the herd spacing does, which
  stands aside while it nurses) with its head up to her belly. Moving or any other state ends it.
- For Steve, later: play runs (fawns and foals sprinting short loops round the mother) would be a server state; not in this layer.

Check: run sheet m35 (deer and horse with two young each at 20 days, `--follow`: the young turn to the mother, then one goes in
under her flank).
