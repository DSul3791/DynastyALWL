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

Every other species keeps its old numbers. Flock species (ducks, seabirds) notice at their flock's own `flock.alert_m`, which stays in the flock block; their table row sets only flee and safe distances. `tools/add_species.py` writes a new species' row into the table. These are the author's judgement, not a sourced figure: deer-sized prey should notice and run well before a player reaches them, while small animals sit tight until the player is close. Predators and livestock are governed by their temperament and `defend` rows, as before.

**RX-2: the upwind cut is smaller.** `senses.scent_loss` is 0.25, where the old cut was 0.5. Upwind, an animal loses only the scent. In a full wind the factor is therefore 0.75, not 0.5. The downwind gain (`scent_gain` 0.5) is unchanged.

**RX-3: running players are noticed farther.** A player moving at `senses.run_ms` (5 m/s) or faster over two noise samples is sensed `run_x` (1.5) times farther off, by eye and ear. Walking (3.2 m/s) is unchanged. Riding or rowing that fast counts too.

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

- This work (19 Nov) did not change animal attacks. Dave said on 19 Nov that attacks doing nothing was fine for now. The 21 Nov fix below found why a stabbed animal never hit back.
- Crouching, lying and cover keep their factors, so stalking still works.

## Attacks up close (21 Nov 2026)

Dave, 21 Nov 2026 play test: "I just stabbed two elephants to death with a stone spear while standing under them because they never actually attacked me. they turned to face me but just stood there and died."

**Cause.** A blow from a player within `provoked_m` starts a short warning (`provoked_warn_s`, 0.8 s for the elephant), and then the charge. A melee jab lands every 0.6 s (`STRIKE_COOLDOWN_MS`). The next jab came during the warning. The warning refused to start again, so the blow fell through to "run away" (`FLEE`). On its next step the player was inside `threat_m`, so it started a fresh warning, facing the player. Each jab reset it, so it stood facing the player until it died. Every animal with a `defend` row had this, not only the elephant.

**Change.** A blow on an animal that may attack now goes through `server_big_game.provoke`:
- one already warning charges at once, pressing home with no bluff;
- one charging carries on;
- one standing after a charge, or cooling down from one, warns again (short).

The charge hits a player within `hit_m` of the animal's centre, including one standing under it.

- **AT-1 (provisional):** being hurt overrides the cool-down after a charge, so a hunter who keeps stabbing gets charged again after each recovery.
- **AT-2 (provisional):** the elephant and the mammoth reach further and hit harder: `hit_m` 3.0 (was 2.2; the body is about 6 m long) and `damage` 40 (was 25). A charge is still not lethal on its own: health stops at 10 and the player is maimed (`hurt_player` floor).

Passive and friendly animals still run when hurt, as before. Their temperament has `attacks` false.

## Drawing animals on the server's timeline (21 Nov 2026)

Dave, 21 Nov 2026: "animals are still teleporting and not actually running".

**Cause.** The 19 Nov fix drew each animal between its sent points by the time the rows arrived. An animal steps on the server 3 to 10 times a second on its own beat, and the rows go out 4 times a second. On arrival times, a running animal therefore covered two steps in one interval and none in the next. A client frame hitch (the lag thread measured 100 to 150 ms about once a second) held rows back and handed two over at once. The animal jumped, stood, and its run clip flicked to walk.

**Change.** This is protocol 147. Each row carries the server milliseconds at which its animal reached that position, and each batch carries the server clock. The client puts those times on its own clock and draws between the points by them (`src/client/motion_buffer.gd`), 0.4 s behind the newest moment (one gap between rows plus `LEAD_S` 0.15, provisional MV-1). There is no extra server work, and each row is about 8 bytes bigger. The test drives an elephant at 10 m/s through a hitch: it is drawn at 8.5 to 11.5 m/s every frame, where arrival times gave 7.5 to 20.

## For Dave

Please review the values above. They can be changed in `animals.json` without any code change.

## Stare before running, growl before attacking (23 Nov 2026)

Dave, 23 Nov 2026: animals "should look up and stare at the player before running away or growling before attacking. fight should not just be animals teleporting around almost impossible to hit." The coordinator's steer: the stare must be clearly readable, about 1.5 to 2 s when the player is first noticed at a distance and down toward 0.5 s only when they are close or running at it; the growl long enough to hear, turn and react, about 1 s.

**The stare (`server_animals.gd _stares`).** A grazing or walking animal that a player comes within its flee distance of stops, lifts its head and stares at them (ALERT, state 3, heading on the player; the client turns the head to them and plays its alert call), then bolts. The stare is `reactions.startle_s` [0.5, 1.75] s: the long end for a player at the flee distance, shorter as they are nearer, the short end for one running at it. It bolts at once when hurt, when it was already watching them (it stared as they came from its notice distance), when a player is within `reactions.startle_close_m` (3 m), for birds, and for temperaments that never watch. Herd mates set off by the first one still follow after their own alarm moment.

**The growl (`server_big_game.gd warn_min_s`).** Every warning before a charge lasts at least `warn_min_s` (1.0 s): the head-down stand and the warning call. A player running off, or a blow during the warning, cuts it to no less. Goblins and bandits (`give_way` "player") keep their own short squaring-up. A hunter giving chase to a player who is already running has no stand: it roars as it sets off (the client voices the charge as a threat call).

**Voices.** Twelve kinds had no voice, so their warnings were silent. They borrow one until Dave's recordings exist (docs/SOUND_MAP.md, "Stand-in animal voices").

**The blow waits for its lunge (`strike_min_s`, 0.6 s; goblins and bandits 0.35 s).** A charge's blow lands only once the charge has run this long, so every screen draws the lunge first (a warthog charging from 1 m used to hit 0.18 s in, drawn 1.7 to 2.8 m short of the player; at 0.35 s a rhino charging from 3.6 m still struck before a robot over 120 ms drew its charge). A charge set off close runs at the pace that reaches the player as the blow may land (at least `CLOSE_PACE_X`, 0.3, of its charge speed), not at full speed into a hold; a chase of a runner keeps its full speed.

## The models' own attacks up close (23 Nov 2026, protocol 167)

Dave, 23 Nov 2026: "not all animals charge they actually have actions built in to them and I believe attacks are in there"; "make sure to use models that have the actions we need." The clip lists are in `data/animals/model_clips.json`; the coordinator's list is `animal-fights/MODEL_ATTACKS_2026-11-23.md` in the project files.

**Close blows (`server_big_game.gd _close_attack`, `_step_close`).** A warning that ends with its player already at the animal (within `contact_m + start_m`) ends in a blow where it stands, not a charge: `strike` (state 25: a swipe, bite, horn, tusk or stomp) or, for the donkey and the goat, `kick` (state 26: it turns its back and kicks; the donkey, which has both, takes turns, kick first). It winds up for `windup_s` (0.5 to 0.9 s), then lands `damage_x` of its damage on a player still within `contact_m + reach_m`, inside `arc_deg` of where it faces (behind it for a kick), judged after the fair-dodge wait as a charge's blow is. `start_m` is 0.2 m inside `reach_m`, so a player who stands still is struck and one who steps back or aside in the wind-up is not. Then it recovers for `recover_s`. A bluff, a dog, a wall between or a player farther off still gets the charge. Kinds: fox, boar, bear, donkey, bighorn, goat, puma, lion, leopard, rhino, elephant, kangaroo, mammoth, tiger (their `defend` rows in `animals.json`). Wolves keep their own pack attack. Kinds with no attack clip on any model we own stay as they were.

**The clips (`animal_view.gd _close_blow`).** The client plays the model's `strike` clip (taking turns with `strike2` where a model has two) or its `kick` clip once, sped so its blow (`hit_at` of the clip, 0.45 unless the model row says) comes `windup_s` after the state began, and started the rows' lateness into it, so the paw or hoof lands on screen when the server's blow does. The numbers are first guesses for the Lane A picture check.

**The models.** Wolf, fox and donkey are drawn only from the look that has attack clips (Wolf_1, Fox_1, the dark donkey). The lion's second look is the lioness with attacks (Lioness_1); the Lioness look without one and the second boar are no longer drawn. The bear_2 look (melee attacks) is no longer drawn either (coordinator 26 Nov 2026, Lane A pictures at 96ec6be0): it has no clip that rears on its hind legs, which Dave asks of a bear up close; every brown bear is the BrownBear look, with its rear, jaw-pop, strikes and bite.

**Built for the "server sends plans" choice.** The server decides the blow and when it lands; the client only plays the clip to that time. If Dave chooses to have the server send plans for the client to play, these states are already plans of that kind.
