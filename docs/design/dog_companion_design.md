# Dog companion: the first Companion bond (design)

Steve, 8 Nov 2026. This builds Dave's decisions 5 and 6 (8 Nov 2026, "I agree to all recommendations"):
- **5:** build the companion system on the dog first, then reuse it for wolf pups.
- **6:** an heir inherits a companion at 70 % of its bond.

It is guiding document section 8.2 (G-09, the Companion bond; D-03 puts the companion first), and it uses the record that `field_journal_design.md` section 5 already laid out. The wolf pup (`wolf_pup_taming_design.md`) uses the same system later. **Runtime only, no rebake.** Step 1 below has no protocol change. Step 2 adds commands, which need one new client action.

## 1. Today [Existing]

- **The dog** is species 34. It has a WildMesh Labrador model (`models.json` dog) and a fox-like `defend` row.
  - It never spawns wild (`target_per_player` 0). Farm animals don't spawn wild.
- **Animals are not saved:** they spawn near players and are dropped when no one is near.
- **What exists to build on:**
  - young follow their mother (`_step_young`, `follow_m`);
  - horses have a per-animal tame value;
  - `field_journal_design.md` section 5 defines `companions.json`.
- **The heir flow is not built yet:** `send_final_death` says "the new-character / heir flow is not built". Decision 6 gets a hook now and acts when heirs exist.

## 2. Where a dog comes from

**A stray** (my recommendation, for the coordinator).
- Near the starter town, one stray dog per player (`stray.per_player` 1) turns up within `stray.ring_m` (60 to 150 m) of the town point, by day, until the player has a dog.
- It is wary, not wild: it keeps `stray.keep_m` (12 m) away and comes closer to a player who is crouched and still.

Buying a dog from a villager would fit later, when villagers trade animals.

## 3. Approach, offer, wait, bond (G-09's verbs)

1. **Approach:** the stray watches a player within 30 m. Walking at it makes it back off to `keep_m`.
2. **Offer:** food dropped within 4 m of it (raw or cooked meat, or fish) is eaten once the player is `trust_gap_m` (6 m) away. Each meal is +1 trust, at most once a game day per player.
3. **Wait:** after `trust_to_follow` (3) meals on 3 game days, the dog **follows** that player. It becomes their companion:
   - a record is written in `companions.json`;
   - it gets a name from `names` (step 2 lets the player rename it);
   - its bond starts at `bond_start` (0.1).
4. **Bond:**
   - +`bond_per_day` (0.05) for each game day the owner is near it for `bond_near_s` (10 real minutes) and it has been fed that day;
   - −`bond_hungry` (0.05) for a game day it goes unfed while out with its owner;
   - at 0 it leaves, goes stray again, and the history records "lost".
   - A dog left at home (step 2, "stay") does not go hungry. Hunger needs it out with its owner, so a dog is never punished for a player being away.

## 4. What a companion dog does (bond-gated)

| bond | ability | step |
|---|---|---|
| 0.1 | **Follows** its owner at `follow_m` (3 m), runs to keep up, and stops at walls and fires (the animal rules). It never steals from its owner, and the wild spawner never makes it | 1 |
| 0.3 | **Warns:** barks when a bear, a wolf pack or goblins are within `warn_m` (40 m) of its owner. The existing animal call ("threat" on `state_changed`) carries the bark, so there is no protocol change | 1 |
| 0.5 | **Stay** and **come** on command (a new client action, the `G` key) | 2 |
| 0.7 | **Fetch:** brings back a small game kill (rabbit, grouse) its owner shot, or a thrown stick | 2 |
| 0.9 | **Guard:** bites a creature that attacks its owner (needs animal-versus-animal fighting, not built) | later |

## 5. Saved and inherited

- **`companions.json`** follows #547 section 5: `{id, species, name, born_s, level, temperament, bond, owner_key, home (stay point or null), fed_day, near_s_today, history: [{s, event, key}]}`.
  - The id is a server serial that is never reused.
  - It is written when it changes, at most every 30 s, through `server_items`' file writer.
- **The live dog** is spawned from its record beside its owner when they join or come near its home, and dropped when they leave. It never despawns as a wild animal does, and it is never sent to other spawners.
- **Death:** a companion killed in the world records "died", and its record is kept for the journal.
- **Heir (decision 6):** `inherit(old_key, heir_key)` moves every companion of the old character to the heir with `inherit_bond_share` (0.7) of its bond, plus an "inherited" history event. It is built now, tested headless, and called by the heir flow when that exists.

## 6. Data (`animals.json` dog, new `companion` block)

```json
"companion": {"stray": {"per_player": 1, "ring_m": [60, 150], "keep_m": 12, "day_only": true},
  "food": ["raw_meat", "roast_meat", "raw_fish", "cooked_fish"], "trust_gap_m": 6, "trust_to_follow": 3,
  "bond_start": 0.1, "bond_per_day": 0.05, "bond_hungry": 0.05, "bond_near_s": 600, "follow_m": 3, "warn_m": 40,
  "inherit_bond_share": 0.7, "names": ["Bran", "Skye", "Rook", "Tess", "Moss", "Fen", "Juno", "Pike"]}
```

The wolf pup later gets its own `companion` block with `only_young` and `only_orphan`. The code is the same.

## 7. Systems touched (step 1)

| file | change |
|---|---|
| `server_companions.gd` (new) | records, save and load, bond per day, `inherit()`, spawning a live companion for its owner, the follow and warn step |
| `server_animals.gd` | the hook in `_step` for animals with a companion record or a stray row; strays in `_top_up` near the town point |
| `server_items.gd` | the offer: food dropped near a stray is eaten (taken) when its dropper is `trust_gap_m` away, using the `by` mark (#604) |
| `terrain_server.gd` | wiring: `key_of`, game seconds, the store folder, player join and leave |
| `animals.json` | the dog's `companion` block |

## 8. How we know it works (headless on the PC, then Dino)

- **Headless test (`test_dog_companion.gd`):**
  - a stray appears by day near the town point and keeps 12 m off;
  - food dropped near it is eaten only once the player is 6 m away, and counts once a day;
  - after 3 days it follows, and a record is written;
  - the bond rises with a fed day near the owner, and falls with an unfed day out;
  - at 0 it goes stray;
  - the dog barks (a warn event) at a bear 30 m from the owner;
  - the record survives a save and a load;
  - `inherit()` moves it to the heir at 70 %.
- **On the PC:** a dog following at a run, a bark at a bear, and 0 shader errors.

## 9. Must not break

- The wild spawner never makes a companion or a second stray.
- A companion keeps out of fires like every animal.
- Hunting cannot target your own companion: a spear hit on it does nothing, and other players' hits are a player-versus-player question for Dave.
- Animal caps count a companion as one of its owner's animals.

## 10. Step 1 as built (notes for the gate and for step 2)

These settle small points the sections above left open. The coordinator chose the stray (8 Nov 2026).
- **Smell, not 4 m:** the stray backs off to 12 m, so food "within 4 m of it" would rarely happen. It goes to food its player left within `stray.smell_m` (15 m), once that player is `trust_gap_m` (6 m) from the food. A player crouched and still (moving under 0.3 m/s) is kept off at only `stray.still_share` (0.4) of `keep_m`, and the stray edges toward them.
- **Whose food:** the `by` mark (#604) says who dropped it. A stray eats only its own player's food; a dog eats only its owner's. `server_items.stealable_near` rows now carry the item id as a fifth field.
- **Food list:** raw and roast meat, trout, salmon, and roast, smoked and salted fish. The game has no `raw_fish` or `cooked_fish` items.
- **States** follow MikeW's clips (`docs/design/DOG_COMPANION_CLIPS.md`). The bark is state 10, so the existing threat call carries the sound. Sit or stay is 18, for step 2. Lie down is 19: after 8 s at heel, the dog lies down. Following uses the walk or the run, by speed. The bloodhound has no bark clip and draws standing. The dog barks at most once per threat every 20 s, and never at an animal that is hidden or in a cave.
- **Fires:** a fire within 1.5 m of the owner is the owner's own torch, and the dog comes to heel beside it. Any other fire's keep-off ring it waits outside.
- **Bond time** `bond_near_s` is real seconds within 15 m of the owner (10 real minutes, a sixth of a game day).
- **Never frozen:** a companion is never frozen by distance or sent off for its off hours. When its owner logs off it leaves the world, and it is made again beside them when they return. It steps over snares.
- **Hits:** a hit from its owner does nothing. Other players' hits hurt it like any animal's, pending Dave's player-versus-player rules. A killed companion's record is kept, with a "died" event.
- **At bond 0** the record is kept with no owner and a "lost" event, and that player can befriend a new stray.

## 11. Wild animals and the dog (MikeW's `DOG_REACTIONS.md`, 8 Nov 2026)

MikeW's plan (his branch `claude/mikew-eye-placement`, `docs/design/DOG_REACTIONS.md`) treats the player's dog as a second presence for wild animals. Everything here uses states the client already draws.

- **The presence:** each tick, every companion dog (`dogs.species`) is a presence `[id, position, barking]`. Barking means it barked within `dogs.bark_s` (3 s). Wild animals sense it as they sense a standing player, with the wind's scent and the ground in the way. It is never crouched, and a barking dog is heard `dogs.bark_x` (2) times as far.
- **Species rows** get a `dog` block: `notice_m`, `flee_m`, `reaction`, and `attack_m` for a stand. The first values are MikeW's:

  | Animal | notice_m | flee_m | reaction | attack_m |
  |---|---|---|---|---|
  | deer, elk, pronghorn | 60 | 40 | flee | |
  | rabbit | 30 | 20 | flee | |
  | fox, raccoon, mink | 25 | 15 | flee | |
  | boar, warthog | 25 | | stand | 8 |
  | bear, black bear | 30 | | stand (at its den too) | 10 |
  | moose, cow | 30 | 20 | stand, mothers with young only, otherwise flee | 12 |

- **Flee:** within `flee_m` the animal bolts and alarms its herd and its alarm group. Within `notice_m` it watches the dog (ALERT, facing it). A player close enough to spook it comes first.
- **Stand:** within `notice_m` it warns at the dog (state 10, `big_game.warn`). The dog is its foe (`foe_dog`). It keeps warning while the dog stays outside `attack_m`, calms if the dog goes past `calm_m`, and charges once the dog comes within `attack_m`. The charge hits the dog through the damage hook, and a player in its path is still hit. So a dog can bring a bear onto its owner.
- **Wolves:** a pack that is prowling, stalking or waiting goes for a dog within `distract_m` (80 m) before any deer. At the dog it bites every `wolves.dog_bite_s` (1 s) for `dog_bite` (25), through the damage hook. A dead dog is the companion's death (section 10). `wolves.dog_prey` false turns this off.
- **Goblins:** a barking dog within `dog_back_m` (20 m) makes a goblin step back `dog_back_step_m` (5 m), face the dog (ALERT) and hold `dog_back_s` (4 to 8 s). Then it comes on again. Two barking dogs make it flee. A silent dog does nothing, and a goblin already fighting is not stopped.
- **Left for later:**
  - MikeW's "a dog beside its armed owner makes a goblin flee": the server does not yet know what a player holds outside the wolves' `spear` flag;
  - the dog fighting back;
  - dogs among the senses for flocks and thieves.

**Test:** `test_dog_reactions`.
- a deer watches a dog at 50 m and bolts at 39 m;
- a rabbit 35 m away ignores a silent dog but flees a barking one;
- a goblin backs off, holds, faces the dog, comes on again once it is quiet, and flees two dogs;
- a bear warns, keeps warning at 25 m, then charges and hits the dog at 9 m;
- a moose with no calf flees;
- a prowling pack goes for the dog and bites it.
