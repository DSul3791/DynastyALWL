# Hunger, health and body weight (built, build 206, protocol 18)

Server-owned, saved per player in vitals.json (version 1, atomic write, unusable file kept as .bad). Drains only while the player is connected. No death from hunger.

## Energy balance (data/items/vitals.json)
- Stomach holds up to 2400 kcal (overeat allowance 25%). HUD hunger = stomach percent.
- Daily need = rest (22 kcal per kg of body weight per game day) + work (1500 kcal at full exertion). Exertion comes from movement and tool use.
- Empty stomach: the deficit burns body weight (7700 kcal per kg). Surplus beyond full adds weight at 80% efficiency.
- A full stomach lasts about 1.07 game days at exertion 0.4 (a game day = 24 game hours = 1 real hour at 24:1, so about 64 real minutes); longer at rest.
- One meal a day: slow weight loss. Many meals with little work: weight gain. Weight limits 40-150 kg, start 75.
- Health regenerates slowly; at zero hunger only a warning and slower regen.

## Items
- Food kcal and heal values in vitals.json (by id and by suffix). Poultice +30, bandage +15.
- Poison plants are spat out and kept.

## Wire
ACT_EAT (18); RPC vitals(hunger, health, weight_dkg). Events for Sounds: eat, heal.
