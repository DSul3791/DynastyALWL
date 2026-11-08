# Alligator: swimming so it can come in (MikeW, 8 Nov 2026)

The pack's American alligator is the last land-and-water animal not yet a species. It waits for swimming: an alligator lives in the water of marsh and slow rivers, basks on the bank and ambushes from the surface. Today a land animal stays out of water (the water edge rule in `_habitat_score`, the blocked check in movement), and only flocks sit on water (ducks: one record placed at the water level).

## What the model gives
`Realistic Animals/AmericanAligator/SK_AmericanAligator.fbx`, textures `T_American_Alligator.png` and an eye texture. Its clips still need listing with `tools/creature_check.gd --clips`; WildMesh water animals in this pack carry swim clips (the duck and goose have `SwimSteady_*` and `SwimMove*`, the leopard and tiger `Swim-IP`), so a swim, an idle on land and a walk are expected.

## Smallest change that works
1. **Where it lives (server, `server_animals.gd`).** A new optional row key `"water": {"swim": true, "surface_sink_m": 0.25, "bank_m": 6.0, "bask_share": 0.4}`. A swimming species may stand on water cells: its height there is the water level minus `surface_sink_m` (the duck flock already reads `water_level`). The habitat score accepts water cells and land within `bank_m` of water; everything else is -1. `bask_share` of its graze time it spends on the bank, the rest in the water.
2. **How it moves.** The same state machine as every animal (graze, alert, flee, warn, charge). Fleeing heads for the nearest deep water instead of away on land; a charge from the water lunges `charge_m` onto the bank and stops at `bank_m`. No diving, no underwater; it rides the surface. Speed in water and on land come from `swim_mps` and `walk_mps`.
3. **How it is drawn (client, `animal_view.gd`).** One new role, `swim`, chosen when the record's height is at or below the water level at its spot (the client already has the water height for the duck flock). The row's clips name the swim clip; walk and run stay for land.
4. **Habitat keys.** It uses the guiding document's optional keys: `water_kind: ["fen", "bog", "river", "lake"]`, `lair: "den"` (a bank burrow), with biome `marsh`. The keys are already accepted by the loader (#552).
5. **Danger.** Defend values from the bear's row scaled to an ambush predator: short `threat_m` (3 m), long `corner_m` in water, a single hard bite (`damage` about 30), `recover_s` long. Fire keeps it off the bank like other animals.

## Tests
- `test_animal_spawn_wiring`: an alligator spawns only on water or within `bank_m` of it, never inland.
- A swim test (new, small): a swimming record placed on a water cell sits at the water level minus `surface_sink_m`; it flees towards deeper water; a non-swimming species never enters water (unchanged behaviour for all others).

## What it reuses and what it adds
Reuses: species row recipe (`tools/add_species.py`), model checks, the flock's water-level lookup, the defend and temperament system. Adds: one row key (`water`), a water branch in the habitat score and the movement step, and one client role (`swim`). The same pieces would later let the beaver, goose and moose swim; the goose and beaver rows only need `"water": {"swim": true}` and their swim clips named.

## Open points for Dave
- Alligators are New World animals; on the island they would read as a fantasy marsh beast. Keep the name "alligator" or call it a marsh drake or bog lizard?
- Should it attack a swimming player in deep water (a real danger at river crossings) or only on the bank?
