# MikeW's animal branch: one page for Dave

Branch `claude/mikew-eye-placement` (plus #596 eye shine and the wet-look branch). Everything here is client side: how the animals
look and sound on screen. None of it changes what the server does; herd groups, the one server piece, went to Steve's stack as
#666. Every new look sits behind its own switch, off by default, so merging changes nothing until a switch is turned on after
its PC check. The PC run sheet is PC_SESSION_MIKEW.md (about 92 minutes, the core in 55).

## The 20 PRs, in merge order
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
| 12 | Hunting feedback | a struck animal tosses its head or stumbles by where it was hit, drags a hind leg after a hip hit, limps past half health, and falls along the slope instead of vanishing | `hunt_feedback` | no | m45 to m47 |
| 13 | Posed birds | Meshy birds and bats flap, glide, fold and flare from their own wing bones, no clips needed | `bird_rig` | eagle, raven, owl, bat | m49 |
| 14 | Posed swimmers | the Meshy whale and dolphin swim from their own spines: tail beat, flippers, porpoising | `swim_rig` | whale, dolphin | m50 |
| 15 | Wind direction | stock and deer turn their rumps to wind and rain, deer graze into a breeze, fur lifts on the windward side, breath drifts downwind, birds take off into the wind | `wind_looks` | no | m51 |
| 16 | Fog | eye shine from dusk in fog, breath merging into mist, herds closer when they cannot see | `fog_looks` | no | m52 |
| 17 | Prevailing wind | the island's WNW wind by default, feathers ruffling, alert animals facing into the wind | `wind_looks` (with `coat_ruffle` for feathers) | no | m53 |
| 18 | Cave air | underground animals take the cave's air: no steam at 5.5 C deep in, coats drying by Steve's rates | `cave_air` | no | m54 |
| 19 | Drinking | herds sip and lift their heads to look round, used drinking spots churned, birds bathing in shallows | `drink_looks` (with `water_life`) | no | m55 |
| 20 | Ice and snow | deer slip on ice while wolves cross it surely, snow gathers on still backs and melts by the air, snow prints deeper | `ice_looks` | no | m56 |

## The PR branches, cut and pushed (8 Nov 2026; PRs not opened until Dave's PC gate)
Each branch is the stack up to its head; its PR's base is the branch above it, so each diff holds one family. The full branch
`claude/mikew-eye-placement` stays as the one Dino tests; its tree is the same as the last branch here. From PR 8 on the branches are
a copy of the full branch's commits with the old herd groups server commit left out (it is #666), so no client PR carries server code.
PR 1 (#596) is `claude/mikew-eyeshine`; PR 2, the wet look, is `claude/mikew-wet-look` off main, outside this stack; PR 7 is #666.

| PR | Branch | Base | Head | Strips |
|---|---|---|---|---|
| 3 | `claude/mikew-pr03-always-on` | claude/mikew-eyeshine (#596) | 6c9522c85847707eb84fe954420dedad2c0f92dc | m1 to m10 |
| 4 | `claude/mikew-pr04-footfall` | `claude/mikew-pr03` | d2f0a14aa4f34a52b8d5d3479275f5797993ab92 | m11 to m14 |
| 5 | `claude/mikew-pr05-predators-flight` | `claude/mikew-pr04` | 5924e90fc201bc71cbd0c67b5ab58d8712070cbc | m15 to m18 |
| 6 | `claude/mikew-pr06-coats-young-water-idles` | `claude/mikew-pr05` | cd4331724b906c203d48a4d2bade83be49ee8322 | m19 to m27 |
| 8 | `claude/mikew-pr08-flight2-foe-wiring` | `claude/mikew-pr06` | ff10094f56413f27a44f1546ab47c62496c947f9 | m28 to m34 |
| 9 | `claude/mikew-pr09-young2-models-voices-eyes` | `claude/mikew-pr08` | ced330b3fe5ef723be2bcc4814afcba00f65696e | m35 to m37 |
| 10 | `claude/mikew-pr10-animal-sign` | `claude/mikew-pr09` | 14891ada6009b6aae7a0cfbffc432a6016165dfc | m38 to m40 |
| 11 | `claude/mikew-pr11-weather-looks` | `claude/mikew-pr10` | 1fda5278dc1252f581396e968dfbc55f78ccd9d0 | m41 to m44 |
| 12 | `claude/mikew-pr12-hunt-feedback` | `claude/mikew-pr11` | c2679173440e92f9c4f77088723d7b4db51837d7 | m45 to m47 |
| 12b | `claude/mikew-pr13-cost-review` | `claude/mikew-pr12` | e812a7228da9e52e0b6030b79b6e05d92d4240fd | gate with --life-layer-off |
| 12c | `claude/mikew-pr14-airc-tracks-cover-shots` | `claude/mikew-pr13` | 9b3fc47a64c398ab4754cfe36ee292c0d44341f0 | m38, m39, m48 |
| 13 | `claude/mikew-pr15-posed-birds` | `claude/mikew-pr14` | 03f6e041a0356fda00164353453eb6dae501cecb | m49 |
| 14 | `claude/mikew-pr16-posed-swimmers` | `claude/mikew-pr15-posed-birds` | 5338fc064e9e6b0c81aa84682875f66a3c754f3b (the full branch's tree then, less this table row) | m50 |
| 15 | `claude/mikew-pr17-wind-direction` | `claude/mikew-pr16-posed-swimmers` | 50e53f97616f4c7e5e1dee574f39a7b01a97a546 | m51 |
| 16 | `claude/mikew-pr18-fog` | `claude/mikew-pr17-wind-direction` | 8791d5acee454b6d93b41172bb1541866ea061cb | m52 |
| 17 | `claude/mikew-pr19-prevailing-wind` | `claude/mikew-pr18-fog` | 530f895bf34816058fbc18f2fde33e1aa07546ce | m53 |
| 18 | `claude/mikew-pr20-cave-air` | `claude/mikew-pr19-prevailing-wind` | 1511831b5105f3b530a39fb620314b7369509082 | m54 |
| 19 | `claude/mikew-pr21-drinking` | `claude/mikew-pr20-cave-air` | a2568bbe5177e252378bf25659b5d54a5933d2fb | m55 |
| 20 | `claude/mikew-pr22-ice-snow` | `claude/mikew-pr21-drinking` | (cut from this commit; its head is reported in the thread) | m56 |

12b and 12c hold the cross-cutting passes that came after PR 12 in time (the cost pass and kill switch, the self review, then Weather.air_c,
Jamie's track numbers, state 20 in cover, the hunt readers and Dino's shot list); they cannot be folded back into earlier families
without rewriting history.

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
