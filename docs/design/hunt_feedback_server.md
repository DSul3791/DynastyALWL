# Hunt feedback: what the server tells every client (Steve, 8 Nov 2026)

These are the server half of MikeW's client hunting feedback (`HUNT_FEEDBACK.md` on his branch, flag `hunt_feedback`): his requests 1 and 2, accepted together behind one protocol bump. Request 3, blood in weather, waits for Sonny's snow window.

## 1. Today

- **The hit:** protocol 85/86 `hit_number(at, amount)` floats the damage. It goes **to the hunter only**, with no animal id and no zone.
- **The animal row:** `[id, number, position, heading, state]`. States 10 to 12 with a dog foe add the dog's position as field 6. The row has **no health**.
- **Damage:** `ServerAnimals.damage` takes `hp` down, and a wounded animal bleeds and lays blood every `blood.every_m`.

## 2. Health on the row (request 1)

- An animal that has been hurt gets **one more field at the end of its row: its health share, 0.1 to 1, snapped to 0.1**. A healthy animal's row is unchanged, so the wire cost is near nothing.
- The health share is `hp / hp_max`. `hp_max` is kept from the first hit, when the animal's full (level-scaled) `hp` is set aside before the damage comes off.
- **Layouts the client reads:**
  - `[id, number, position, heading, state]`
  - `[..., state, dog position]` (a Vector3)
  - `[..., state, health]` (a float)
  - `[..., state, dog position, health]`

  The dog is always field 6 and a Vector3. The health is always the last field and a float.
- **The client:** MikeW's `hunt_feedback` reads the limp (below 0.5) from this field, not from its own count of the hunter's hits. It is right for every player, and after a reconnect.

## 3. The hit event (request 2)

- **New message `animal_hit(id, zone, at)`**, sent to every player within `hit_send_m` 60 m of the animal, the hunter included. `hit_number` stays as it is, sent to the hunter only.
- **The zone is the server's own.** The point is where the arrow or spear path comes closest to the animal's chest centre: the closest point of the arrow's segment, or of the jab's aim line within reach. Zones are 1 head, 2 chest, 3 hip, 4 leg (0 unknown).
- **The zone uses MikeW's client rule**, with the body length taken as twice the species' hit radius (`hit_radius_m`, 0.6 m when unset):
  - `along` is the forward offset from the feet, as a share of half the length;
  - `up` is the height over the feet, as a share of 0.6 of the length;
  - **leg** if `up` < 0.3, **head** if `along` > 0.55 and `up` > 0.5, **hip** if `along` < -0.45, otherwise **chest**.
- The event is also sent when the hit kills the animal, so the death fall can play on every client.
- **The client** takes the reacting animal by id and the zone from the event, instead of the nearest model to the hit point.

## 4. Wire

- Protocol 96. #685 takes 95 for the fire states; whichever merges second keeps its number above the other's.
- New RPC `animal_hit(id: int, zone: int, at: Vector3)`, authority to client, reliable.
- New key `animals.json` `hit_send_m` 60.

## 5. Tests

`test_hunt_feedback`:
- a deer's row has no health field until it is hit;
- after a hit to half its health the row ends in 0.5;
- a dog foe and health together keep the dog at field 6;
- an arrow along the deer's head line gives zone head, one at its rump gives hip, one low through its legs gives leg, and one through its middle gives chest;
- a jab at the chest gives chest;
- the hit event goes to a player 50 m off and not to one 70 m off, and it goes when the hit kills.
