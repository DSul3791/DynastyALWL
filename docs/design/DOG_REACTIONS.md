# How animals react to the player's dog (server, for Steve)

The player's dog is a companion (DOG_COMPANION_CLIPS.md). Today wild animals sense only players. This note is a server plan for
treating the dog as a second presence. Nothing here is built; the client needs no change, because every reaction is a state the
client already draws (flee 2, alert 3, warn 10, the dog's bark 10).

## The rule

- A companion dog counts as a threat for wild animals with its own distances, read from a new `dog` block in each species row
  in animals.json: `notice_m`, `flee_m`, and `reaction` (`flee`, `stand`, `back_off`, `attack`).
- Senses apply as for players (scent with the wind, terrain blocks sight), but a dog is never crouched: its factor is 1, and a
  barking dog (dog state 10) is heard at `bark_x` (2) times the distance.

## First values

| Animal | notice_m | flee_m | reaction | Note |
|---|---|---|---|---|
| Deer, elk, pronghorn | 60 | 40 | flee | Deer bolt from a dog at 40 m, further than from a walking player |
| Rabbit, hare | 30 | 20 | flee | Runs for its burrow as from a player |
| Boar, warthog | 25 | 0 | stand, then attack at 8 m | A boar faces a dog down |
| Bear, black bear | 30 | 0 | stand (warn 10), attack at 10 m when the dog keeps coming | A dog can bring a bear onto its owner |
| Wolf pack | 40 | 0 | attack the dog | Wolves kill dogs; the pack's brain (server_wolves.gd) targets the dog first |
| Moose, cow with young | 30 | 0 | attack at 12 m | A mother with young charges a dog |
| Goblins | 20 | 0 | back off | A barking dog makes goblins step back 5 m and hold; a silent dog does not |
| Fox, raccoon, mink | 25 | 15 | flee | |

## Goblins and a barking dog

- When the dog barks (state 10) within 20 m of a goblin, the goblin backs off 5 m away from the dog, faces it and waits 4 to 8 s
  before coming on again. Two dogs, or a dog beside its armed owner, make it flee instead.
- Goblins already in a fight with the owner are not stopped by barking.

## Server steps (Steve)

1. A `presences` list per tick: players plus companion dogs with position, noise (bark) and a kind.
2. Each species' perception loop runs over presences, with the `dog` block's distances for dogs.
3. Wolves target a dog presence; the dog's health and flee response come from its companion row.
4. Goblin back-off as a new small state on the goblin brain (it reuses state 3 alert on the client while backing).
5. Test: a deer at 50 m holds, at 39 m bolts; a goblin at 15 m backs off when the dog barks and comes on again after it stops.

## Built by Steve (#659) and the client check (MikeW, 8 Nov 2026)

Steve built this as #659 (dog_companion_design.md section 11). The client draws every state it uses: flee 2, warn 10 (head low,
ears flat), charge 11, goblin ALERT 3 while it holds. One fix on the client: a goblin stepping back 5 m while facing the dog used to
slide backward on a forward walk; an animal moving against its facing now plays its walk in reverse. Known gap: a warning animal's
head turns toward the player (HEAD_TRACKING.md), not toward the dog it is warning; when the server sends the foe's position, the look
can take it.
