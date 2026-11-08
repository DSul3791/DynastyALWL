# The animal life layer: index (MikeW, 8 Nov 2026)

Everything that makes a drawn animal look alive on top of its clips, all client side (nothing on the wire changes), in `src/client/animal_view.gd` and the bone layer `src/client/bone_offsets.gd` (a SkeletonModifier3D under each model's skeleton). Turned on per species by its `data/animals/models.json` row; the global flags are on `AnimalView` (the client sets them). Checked with `tools/creature_check.gd` (stills) and `tools/creature_motion.gd` (moving frames); the run sheet is PC_SESSION_MIKEW.md.

| Layer | What it does | Row key | Global flag (default) | Doc |
|---|---|---|---|---|
| Posture fix | turns bones a fixed amount over every clip (the crow upright) | `bone_offsets` | none (on) | #582 |
| Clip loops | a window of a clip looped, ends eased (the mink) | `clip_loop` | none (on) | #582 |
| Hand-made gait | a walk, run or swim loop built from bones | `gait` (`gait_fallback` kept ready) | none | #584 |
| Eye shine | eyes glow in the player's own torchlight | `shine_color`, `shine` | needs `torch_light` (on) | EYE_SHINE_AND_WET.md |
| Eye placement | glossy eyes where the file has none | `eye_bones` / `eye_offset` | none (on) | POSE_FIXES_PICTURES.md |
| Wet look | darker and shinier in water, dries in 3 min | `wet_dark`, `wet_rough`, `wet_shed` | needs `water_level` (on) | EYE_SHINE_AND_WET.md, WET_LINE_SHADER.md |
| Dog companion clips | bark 10, sit 18, lie 19 | `clips` | none | DOG_COMPANION_CLIPS.md |
| Tail motion | wag, flick, fly swish | `tail_motion` | none (on) | TAIL_MOTION.md |
| Ears | turn to the player, flat when threatening | `ear_motion` | none (on) | EAR_AND_BREATH.md |
| Breathing | chest swell at the species' rate | `breath` | none (on) | EAR_AND_BREATH.md |
| Head tracking | grazers glance, predators track | `look` | none (on) | HEAD_TRACKING.md |
| Posed states | a bone-built pose for a state with no clip (black bear jaw-pop) | `state_poses` | none (on) | POSED_STATES.md |
| Hop arc | rabbits and kangaroos bound | `hop` | none (on) | HOP_ARC.md |
| Sleep | bedded-down animals lie, curl or doze | `clips.sleep`, `wake_clip`, `state_poses` -1 | needs `conditions_now` (on) | ANIMAL_SLEEP.md |
| Herds | same facing, 2 m apart, look up together | `herd` | none (on) | HERD_CLIENT.md |
| Footfall hook | landing with its ground (water, puddle, snow, mud, dust) | none | `footfall` signal (on) | FOOTFALL.md |
| Puffs and splashes | dust, mud, snow puffs; droplets in water and puddles | none | `footfall_fx` (**off**) | FOOTFALL.md |
| Prints | fading hoof, paw, claw and bird prints in snow and mud | none (sign group) | `prints_fx` (**off**) | FOOTFALL.md |
| Slope pitch | the body pitches with the slope | none | `slope_tilt` (**off**) | FOOTFALL.md |
| Stalk and pounce | crouch, creep, freeze when prey looks up; pounce arc | `stalk`, `pounce` | `stalk_fx` (**off**) | STALK_POUNCE.md |
| Wind | ears back and tails swing above about 0.5 | none | needs `wind_now` (on) | STALK_POUNCE.md (wind note) |
| Seasonal coat colour | coat tint by season (deer, elk, moose, wolf, fox, rabbit) | `season_tint` | `season_coats` (**off**) | COAT_SHADER.md |
| Bird flight | take-off, flap and glide in turns at the wingbeat, bob, landing flare | `flight` | none (on) | BIRD_FLIGHT.md |
| Foot reach | each foot reaches the ground under it | `feet` | `foot_ik` (**off**), needs `ground_height` | FOOTFALL.md |

**Already in main before the layer:** root-motion strip, flat-clip guard and fallback, skinned bounds, size by clip pose, flock models, young models, swimming, foot-speed measurement (#538 to #591).

**Order a new species goes through:** model row (clips, size) → creature check → the layer keys it needs (most species: `tail_motion`, `ear_motion`, `breath`, `look`, `herd` where it fits, `clips.sleep`).
