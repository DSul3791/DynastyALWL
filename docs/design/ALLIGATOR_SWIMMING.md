# Alligator: swimming so it can come in (MikeW, 8 Nov 2026)

The pack's American alligator is the last land-and-water animal not yet a species. It waits for swimming: an alligator lives in the water of marsh and slow rivers, basks on the bank and ambushes from the surface. Today a land animal stays out of water (the water edge rule in `_habitat_score`, the blocked check in movement), and only flocks sit on water (ducks: one record placed at the water level).

## What the model gives
Dave's own model, `assets/animals/alligator/Alligator_Al.glb` (27 Nov 2026; the WildMesh alligator was never in the pack). About 1.9 m in the file, drawn 3.8 m (`length_m`); its own baked material and textures; one skeleton whose rest pose lies belly and tail on the ground. Its nine clips are borrowed from other animals, so the row maps each role by name (`data/animals/models.json`):

| Role | Clip | Why |
|---|---|---|
| graze/stand 0, 12 | `fox_mon_xiaohuli_01_idle1` | a quiet idle, head low; `cat_idle2` plays now and then |
| alert 3, warn 10 (and jaw pop 16) | `cat_idle2` | the head comes up to watch |
| walk | `cat_walk` | Dave: "ignore the dog walk its terrible", so the dog's `Walking` is never used |
| run, charge 11 | `Running` (dog) | the only run |
| lie 19 | `cat_shuijiao` (cat sleep) | lifted 0.3 m (`ground_clips`): the clip lowers the body |
| bite | `leopard_skill_feipu` (pounce) | the lunge |
| strike | `leopard_skill_shuaiwei` (tail swipe) | an alligator's tail blow |
| die | `leopard_dead` | rolls onto its side |

No swim, hit or drink clip: in water and at the bank it plays its state's clip (swimming itself is the plan below, not built for this model).

**Tail.** Every clip holds the tail up like a cat's. Dave: "all the actions need to let the tail drag on the ground". `src/client/tail_drag.gd` (a `SkeletonModifier3D`, like `bone_offsets.gd`) runs after the clip each frame: each tail bone keeps the clip's sideways heading, so the sway and the tail swipe stay, and is pitched so the next joint lies at its rest height above the floor, sloping down at most 35 degrees from a raised body (the dog run carries it high). Row key `"tail_drag": [base ... tip bones]`. Checked off line on the file's bones: the tail tip sits on the ground through all nine clips; only mid-pounce, with the whole body in the air, does it slope up from the ground. Limit: the lie clip lowers the body by its toes, so the tail may sit a few cm off the ground there (Lane A pictures show it).

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

## Decided (coordinator for Dave, 8 Nov 2026)
- The name stays "alligator" (realistic, light fantasy exaggeration).
- It attacks a swimming player and anyone at the water's edge: that is what makes a swamp dangerous. Its threat range applies in deep water as on the bank; a swimming player cannot outrun it.
