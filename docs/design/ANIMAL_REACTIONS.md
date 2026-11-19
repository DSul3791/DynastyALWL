# Animal reactions to players

Status: **PROVISIONAL**, set 19 Nov 2026 for Dave's review. Values RX-1 to RX-3 are provisional. They follow Dave's 19 Nov play test: animals "are not reacting most of the time to a player nearby"; "they also need to react accordingly from reasonable distances". The values live in `data/animals/animals.json` and are read by `src/stream/server_animals.gd`.

## Why animals ignored him

Every species already had its own distances:
- a watch distance (`alert_m`)
- a run distance (`spook_m`)
- a distance it runs to (`safe_m`)

The senses shrink those distances by multiplying factors together.

**The upwind cut was too big.** When the animal stood upwind of the player in a full wind, the scent factor halved the distance, and it halved sight and hearing with it. Combined with the forest factor, a deer that runs at 30 m in the open noticed a walking player in woods upwind at about 11 m.

**Neutral animals ignore players.** Dave's temperament rule of 6 Nov makes about a quarter of the bigger animals "neutral". A neutral animal ignores players and does not even look up. This is unchanged here: it is Dave's rule.

## What changed

**RX-1: one reaction table.** `reactions.notice_flee_safe_m` holds `[notice_m, flee_m, safe_m]` for every species, in one place. The species rows no longer carry these values; `setup()` copies them into each row. The table's values are distances to a standing player in the open on a calm day. Two species changed:
- deer: 50 / 30 / 60 became 60 / 35 / 70
- elk: 55 / 35 / 70 became 70 / 40 / 80

Every other species keeps its old numbers. The reasoning follows how well-regarded hunting and survival games, and field flight-distance studies, treat prey: deer-sized prey notice and run well before you reach them, while small animals sit tight until close. Predators and livestock are governed by their temperament and `defend` rows, as before.

**RX-2: the upwind cut is smaller.** `senses.scent_loss` is 0.25, where the old cut was 0.5. Upwind, an animal loses only the scent. In a full wind the factor is therefore 0.75, not 0.5. The downwind gain (`scent_gain` 0.5) is unchanged.

**RX-3: running players are noticed farther.** A player moving at `senses.run_ms` (5 m/s) or faster is sensed `run_x` (1.5) times farther off, by eye and ear. Walking (3.2 m/s) is unchanged.

**Cost.** One speed comparison per player per noise sample, four times a second. Nothing is added per animal.

## The table (notice / flee / safe, metres)

| species | notice | flee | safe |
|---|---|---|---|
| rabbit | 24 | 14 | 35 |
| deer | 60 | 35 | 70 |
| wolf | 60 | 0 | 60 |
| moose | 55 | 28 | 70 |
| fox | 40 | 22 | 50 |
| duck | 45 | 22 | 60 |
| horse | 50 | 25 | 70 |
| boar | 40 | 22 | 45 |
| songbirds | 16 | 10 | 28 |
| frog | 8 | 5 | 14 |
| grouse | 24 | 14 | 35 |
| seal | 50 | 30 | 60 |
| seabird | 24 | 14 | 35 |
| bear | 50 | 25 | 50 |
| goblin | 60 | 30 | 60 |
| donkey | 50 | 15 | 50 |
| lynx | 50 | 30 | 70 |
| black_bear | 50 | 32 | 50 |
| elk | 70 | 40 | 80 |
| bighorn | 50 | 35 | 65 |
| mountain_goat | 50 | 28 | 60 |
| beaver | 24 | 20 | 40 |
| chamois | 50 | 40 | 70 |
| mink | 40 | 15 | 35 |
| raccoon | 40 | 18 | 40 |
| rat | 24 | 8 | 20 |
| crow | 24 | 16 | 35 |
| pheasant | 24 | 14 | 35 |
| goose | 24 | 20 | 35 |
| cow | 50 | 8 | 25 |
| goat | 50 | 8 | 25 |
| chicken | 24 | 14 | 35 |
| cat | 40 | 6 | 20 |
| dog | 40 | 5 | 20 |
| buffalo | 55 | 28 | 70 |
| puma | 50 | 30 | 70 |
| pronghorn | 50 | 45 | 90 |
| warthog | 40 | 22 | 45 |
| hyena | 40 | 25 | 50 |
| wildebeest | 50 | 35 | 80 |
| lion | 50 | 20 | 70 |
| leopard | 50 | 30 | 70 |
| rhino | 30 | 18 | 70 |
| elephant | 60 | 25 | 70 |
| camel | 50 | 15 | 70 |
| guineafowl | 24 | 14 | 35 |
| honey_badger | 40 | 8 | 20 |
| kangaroo | 50 | 30 | 60 |
| mammoth | 60 | 25 | 70 |
| tiger | 50 | 25 | 70 |
| alligator | 30 | 6 | 25 |

## Left as is

- This work does not change animal attacks. Dave said on 19 Nov that attacks doing nothing is fine for now. The attack path is `server_big_game.gd` and `server_wolves.gd` calling `server_items.hurt_player`, which does apply damage, so why attacks currently do nothing to him was not looked into here.
- Crouching, lying and cover keep their factors, so stalking still works.

## For Dave

Please review the values above. They can be changed in `animals.json` without any code change.
