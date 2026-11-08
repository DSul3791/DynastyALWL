# Hunting feedback on the client (MikeW, 8 Nov 2026)

What a hunter sees when a spear or arrow lands, behind `hunt_feedback` (off). Read against the server's hit code: arrows and thrown
spears hit along their flight with a 3D test (`server_animals.target_on_segment`), jabs at reach (`server_items` jab), damage comes
off `hp`, a wounded animal bleeds `blood.bleed_hp_per_s` and drops blood every `every_m` while it runs (protocol 55 blood points),
and dies where its health runs out; big game warns, charges and recovers (server_big_game.gd). The carcass is a server item.

## What the client is told today
- **The hit:** protocol 85, the floating hit number: the point where it landed and the damage, **sent only to the hunter**. No
  zone, no animal id.
- **The animal row:** id, species, position, heading, state (plus the foe while it warns at a dog). **No health and no wounded
  flag.**
- **The blood trail:** protocol 55 points near each player, already drawn as ragged splashes that dry on the server's `life_s`.
- **The death:** the animal leaves the rows within 1.5 s of a hit near it (`killed_by_hit`), which plays the fall sound.

## What is built (flag `hunt_feedback`)
- **Which animal, which zone** (`_hit_reaction`): the nearest drawn model within 3 m of the hit point takes it; the zone comes from
  where the point sits on its body (forward along its length, height over its feet): **head** (front quarter, upper half),
  **chest** (front half), **hip** (back quarter), **leg** (lower third).
- **Reactions** (`_hunt_motion`, on the Rig over 0.45 s): head, a toss up and back; chest, a stumble with the front dipping; hip,
  the hind end jolting; leg, a buckle sideways; anything else, a flinch.
- **Hip hit:** from then on the hind end sits low and swings at each stride (a dragged hind leg).
- **Wounded gait:** once the damage this client has seen reaches half the species' `health` (animals.json), the animal limps: an
  uneven roll and bob each stride and the walk or run clip played up to 15 percent slower.
- **Death fall** (`_death_fall`): instead of vanishing, the body goes down onto its side over 0.8 s, downhill, coming to rest along
  the ground's slope across its body (`ground_height` sampled a body's width either side); the legs slow and stop; it is freed 1.5 s
  later as the carcass item appears.
- **Blood trail:** the server's protocol 55 drops, as now (spacing and drying are the server's `every_m` and `life_s`). They are not
  copied into the animal-sign pool, so every client sees the same trail. Jamie's puddle rules (blood washed by rain, stronger on
  snow) are a server step: the drops' `life_s` would shorten in rain; see the requests.

## Requests to Steve
1. **A wounded flag on the row** (or health in eighths), so every client, not only the hunter, sees the limp, and it is right after
   a respawn of the view or a reconnect. The client uses its own count of the hunter's hits until then.
2. **The hit zone and animal id with the hit**, sent to players within 60 m (not only the hunter), so others see the reaction and
   the zone is the server's own (it already knows where the segment met the body).
3. **Blood in weather:** drops dry sooner in rain (`life_s` x 0.5 at rain 0.6) and none are laid in water; on lying snow they last
   until the next snowfall.

## Steve's answer (8 Nov 2026)
Requests 1 and 2 are accepted together behind one protocol bump, after his fire step 3 and the state-20 cover change: the animal row
gets one field, **health 0 to 1 snapped to 0.1, sent only while the animal is hurt**, and the **hit event (zone and animal id) goes
to every player within 60 m**. When it lands, `hunt_feedback` reads the health field for the limp (below 0.5) instead of the
hunter's own count, and takes the zone from the event instead of working it out from the hit point. Request 3 waits for the snow
window.

## The client readers, ready for Steve's PR
- **Health on the row:** `on_rows` reads every field after the first five by type: a Vector3 is the foe (#659), a number is the
  health 0 to 1 by tenths. With a health field the animal is `wounded` below 0.5 (the server's number wins over the hunter's own
  count); a row with none is unhurt, so the limp stops.
- **The hit event:** `on_hit_event(id, zone)`, zone as an index into `HIT_ZONES` (body, head, chest, hip, leg) or its name. Its
  protocol number is the constant `HIT_EVENT_PROTOCOL` in animal_view.gd (96, Steve's #705). terrain_client connects it
  only when the network has the signal `animal_hit_received(id, zone)`, so nothing changes until his PR adds it. From the first event
  on, the hunter's own guess from the hit number is not used.
- Steve's #705 matches: protocol 96, `animal_hit_received(id, zone)` with zone 0 body, 1 head, 2 chest, 3 hip, 4 leg; health is the last
  number after the first five fields, the dog foe stays a Vector3 at field 6. His second signal `animal_hit_point_received(id, zone, at)`
  is not used (the zone is enough to choose the reaction).

## What a hunter can read
A head toss or stumble says the shot struck; a dragging hind end says a hip hit, a slow follow; a limp says the animal is past half
its strength; the blood trail leads to where it fell, lying along the slope.

## Check
Run sheet m45 (deer hit in the hip while walking: a jolt, then the hind end low and swinging), m46 (deer hit in the head standing:
a toss), m47 (deer killed on the strip's flat ground: it goes down onto its side and lies still).
