# MikeW's animal branch: one page for Dave

Branch `claude/mikew-eye-placement` (plus #596 eye shine and the wet-look branch). Everything here is client side: how the animals
look and sound on screen. None of it changes what the server does; herd groups, the one server piece, went to Steve's stack as
#666. Every new look sits behind its own switch, off by default, so merging changes nothing until a switch is turned on after
its PC check. The PC run sheet is PC_SESSION_MIKEW.md (about 90 minutes, the core in 55).

## The 11 PRs, in merge order
| # | PR | What you would see | Switches | Needs new models? | PC strips |
|---|---|---|---|---|---|
| 1 | Eye shine (#596) | eyes glow in your torchlight | none | no | m8 |
| 2 | Wet look | coats darken and shine after swimming or rain | none | no | m7 (its own branch's gate) |
| 3 | Always-on looks | glossy eyes on painted-eye models, dog sit and lie, tails wag and swish, ears turn, breathing, heads track you, bear jaw-pop, hopping, sleeping animals, herds facing one way | none | no | m1 to m10 |
| 4 | Footfall and feet | dust puffs, splashes, prints in snow and mud, feet on uneven ground, body tilt on slopes | `footfall_fx`, `prints_fx`, `foot_ik`, `slope_tilt` | no | m11 to m14 |
| 5 | Predators and birds | wolves crouch and creep, fox and lynx pounce, ears and tails in the wind, birds take off, flap and glide | `stalk_fx` | no | m15 to m18 |
| 6 | Coats, young, water, idles | seasonal coat colour, fur in wind, dust after rolling, young smaller with quick steps, drinking and swimming, scratching and grooming | `season_coats`, `coat_ruffle`, `coat_dust`, `young_gait`, `water_life`, `idle_variety` | no | m19 to m27 |
| 7 | Herd groups (#666, server) | herds move as one, scatter and regroup | `groups.enabled` | no | Steve's gate |
| 8 | Flight part 2 and wiring | birds bank in turns, raven rolls, goblins step back properly, animals look at the dog they warn | `flight_bank`, `look_at_foe` | raven for the roll | m28 to m34 |
| 9 | Young, new models, voices, night eyes | young grow and nurse, the six Meshy rows and import checklist, bat swarm and whale spout, calls by state, eye shine by torch and moon | `young_follow`, `swarm_fx`, `sea_life`, `voice_fx`, `eye_shine` | bat, whale, dolphin, eagle, raven, owl for their parts | m35 to m37 |
| 10 | Animal sign | tracks on soft ground by stride, droppings, browse, beds | `animal_sign` | no | m38 to m40 |
| 11 | Weather looks | dogs and wolves shake off after rain, grazers turn their tails to a gale, herds huddle in the cold with heads low, steam breath below 5 C, snow on sleeping backs | `weather_looks` | no | m41 to m44 |

## Which need models you must bring
Only parts of 8 and 9: the raven (roll), bat (swarm), whale and dolphin (spout), and the eagle and owl rows. Their code is ready and
waits; NEW_MODEL_IMPORT.md is the 10-minute import per model. Everything else uses the 50 animals already in the game.

## Most for the least PC time
1. **PR 3, always-on looks** (strips m1 to m10, about 10 minutes): the biggest visible change, with no switches to turn on; every
   animal breathes, looks, wags and sleeps.
2. **PR 1 and 2, eye shine and wet look** (m7, m8, a few minutes, plus their gates): small, finished, already reviewed.
3. **PR 10, animal sign** (m38 to m40, about 3 minutes): tracks a hunter can follow, one switch, no models.

## Conflicts checked (8 Nov 2026)
Against main 066f6cc9 and Kathleen's open #647, #670, #674, #676, #680 and #681: no conflicts. Against Steve's open chain (#643 to
#671): the only files this branch shared with it were the herd groups server code and data, now removed from this branch; the
remaining conflicts in those PRs are between Steve's chain and main itself (GOBLINS.md, terrain_server, server_goblins,
server_items, server_big_game), not this branch.
