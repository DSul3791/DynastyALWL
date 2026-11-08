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
