# Animal voices: calls by state (MikeW, 8 Nov 2026)

The sound side of the life layer. Today `animal_view.state_changed` sends every alert, flee, warn and charge to
`creature_sounds.call_at` as "alert" or "threat", for the eight kinds that file knows (deer, rabbit, fox, wolf, moose, horse, duck,
bear). This note gives every species its own calls, named by what they are for, and says which server state asks for which.
Built behind `voice_fx` (off): with it on, `data/animals/voices.json` decides, and the old call is skipped.

## The calls
- **Alarm:** the call as it bolts (state 2): a deer's bark-snort, a rabbit's foot thump, a pheasant's whirring cackle as it bursts
  up (#661's flush, state 15). Carries far, low and sharp.
- **Alert:** it has noticed something (3): a snort, a huff, a crow's caw. Quieter, shorter.
- **Warn and charge (10, 16, 11):** big game and the dog. A bear's jaw-pop and huff on warn, a roar only on the charge; a boar's
  squeal; a cow's bellow. The companion dog's bark is state 10 too, the same bark Steve's dog presence (#659) counts as barking.
- **Contact:** the call that keeps a group together (a whinny, a wolf's howl at night, a crow's caw, goose honks). Natural calls by
  zone and hour stay with creature_sounds' wild system; state changes do not trigger them.
- **Rut:** autumn only (red deer roar, elk bugle, moose bellow, bighorn horn clash, the fox's winter scream). Natural calls by season
  (creature_sounds `seasons`), not by state.
- **Young:** a young one fleeing (2) calls with its young call (fawn bleat, calf bawl, piglet squeak, cub bawl), and its mother is
  the one that answers (her warn).
- **Silent on purpose:** wolf stalk (6), goblin sneak (13), hunch (20) and glide (17) play nothing.

## When a state calls
`_voice` in animal_view.gd: on a state change, the species' `states` map names the call; one call per animal every 4 s
(`cooldown_s`) and at most 6 a second in all (`per_second`), so a herd bolting is a few calls, not twenty. terrain_client plays a
`mood` call through creature_sounds (its own files and voice budget) and a `slot` call through the sound slots, which skip a slot
with no file: a missing sound is silence, never an error.

## Distance and the outdoors
Each slot call carries its source level and carry (`db`, `unit`, `reach`): a bugle or bray 600 to 900 m, a snort 120 to 200 m, a
fawn's bleat 80 m. Jamie's sound-outdoors rules (#642) and Kathleen's outdoor hook (#662) scale `unit_size` and the filtering at play
time: farther at night and downwind, nearer and duller in forest, rain and snow, high calls lost first. The calls only give the
honest source numbers; nothing here bends them.

## What is on Dave's PC and what is missing
Read from `assets/audio/creatures` (generated), `assets/audio/recorded/creatures` (recorded, wins) and the filled slots in
`data/sound/*_slots.json`. "missing" plays nothing until a file is added.

| Species | Call | Sound | On Dave's PC |
|---|---|---|---|
| deer | alarm | `deer_snort` (creature_sounds) | generated |
| deer | alert | `deer_snort` (creature_sounds) | generated |
| deer | contact | `deer_grunt` (creature_sounds) | recorded |
| deer | rut | `deer_roar` (slot) | missing |
| deer | young | `deer_fawn_bleat` (slot) | missing |
| elk | alarm | `elk_bark` (slot) | missing |
| elk | alert | `elk_bark` (slot) | missing |
| elk | warn | `elk_grunt` (slot) | missing |
| elk | charge | `elk_grunt` (slot) | missing |
| elk | rut | `elk_bugle` (slot) | missing |
| elk | young | `elk_calf_mew` (slot) | missing |
| moose | alarm | `moose_snort` (creature_sounds) | generated |
| moose | alert | `moose_snort` (creature_sounds) | generated |
| moose | warn | `moose_bellow` (creature_sounds) | recorded |
| moose | charge | `moose_bellow` (creature_sounds) | recorded |
| moose | rut | `moose_bellow` (creature_sounds) | recorded |
| moose | young | `moose_calf_bawl` (slot) | missing |
| horse | alarm | `horse_whinny` (creature_sounds) | recorded |
| horse | alert | `horse_snort` (creature_sounds) | generated |
| horse | warn | `horse_snort` (creature_sounds) | generated |
| horse | charge | `horse_whinny` (creature_sounds) | recorded |
| horse | contact | `horse_whinny` (creature_sounds) | recorded |
| horse | young | `foal_nicker` (slot) | missing |
| donkey | alarm | `donkey_bray` (slot) | missing |
| donkey | alert | `donkey_snort` (slot) | missing |
| donkey | warn | `donkey_bray` (slot) | missing |
| cow | alarm | `cow_moo` (slot) | missing |
| cow | warn | `cow_bellow` (slot) | missing |
| cow | charge | `cow_bellow` (slot) | missing |
| cow | young | `calf_bawl` (slot) | missing |
| boar | alarm | `boar_grunt_alarm` (slot) | missing |
| boar | alert | `boar_grunt` (slot) | missing |
| boar | warn | `boar_squeal` (slot) | missing |
| boar | charge | `boar_squeal` (slot) | missing |
| boar | young | `piglet_squeak` (slot) | missing |
| bear | alert | `bear_growl` (creature_sounds) | recorded |
| bear | warn | `bear_growl` (creature_sounds) | recorded |
| bear | charge | `bear_roar` (creature_sounds) | generated |
| bear | young | `bear_cub_bawl` (slot) | missing |
| black_bear | alert | `?` (creature_sounds: no row for this kind) | missing |
| black_bear | warn | `?` (creature_sounds: no row for this kind) | missing |
| black_bear | charge | `?` (creature_sounds: no row for this kind) | missing |
| black_bear | young | `bear_cub_bawl` (slot) | missing |
| wolf | alert | `wolf_growl` (creature_sounds) | generated |
| wolf | warn | `wolf_growl` (creature_sounds) | generated |
| wolf | attack | `wolf_growl` (creature_sounds) | generated |
| wolf | contact | `wolf_howl` (creature_sounds) | recorded |
| fox | alarm | `fox_scream` (creature_sounds) | recorded |
| fox | alert | `fox_bark` (creature_sounds) | recorded |
| fox | contact | `fox_bark` (creature_sounds) | recorded |
| fox | rut | `fox_scream` (creature_sounds) | recorded |
| rabbit | alarm | `rabbit_thump` (creature_sounds) | generated |
| rabbit | alert | `rabbit_thump` (creature_sounds) | generated |
| rabbit | hurt | `rabbit_squeak` (creature_sounds) | generated |
| dog | warn | `dog_bark` (slot) | missing |
| dog | alert | `dog_woof` (slot) | missing |
| dog | contact | `dog_whine` (slot) | missing |
| goat | alarm | `goat_bleat` (slot) | missing |
| goat | warn | `goat_snort` (slot) | missing |
| goat | young | `kid_bleat` (slot) | missing |
| bighorn | alarm | `sheep_snort` (slot) | missing |
| bighorn | alert | `sheep_snort` (slot) | missing |
| bighorn | rut | `horn_clash` (slot) | missing |
| bighorn | young | `lamb_bleat` (slot) | missing |
| crow | flush | `?` (creature_sounds: no row for this kind) | missing |
| crow | alert | `?` (creature_sounds: no row for this kind) | missing |
| crow | contact | `crow_caw` (slot) | missing |
| pheasant | flush | `pheasant_flush_cackle` (slot) | missing |
| pheasant | contact | `pheasant_crow` (slot) | missing |
| duck | flush | `duck_quack` (creature_sounds) | recorded |
| duck | contact | `duck_quack` (creature_sounds) | recorded |
| goose | flush | `goose_honk` (slot) | missing |
| goose | warn | `goose_hiss` (slot) | missing |
| goose | contact | `goose_honk` (slot) | missing |
| owl | contact | `owl_hoot` (slot) | slot filled |
| raven | flight | `raven_croak` (slot) | missing |
| raven | alert | `raven_knock` (slot) | missing |
| golden_eagle | flight | `eagle_chirp` (slot) | missing |
| goblin | alert | `goblin_hiss` (slot) | missing |
| goblin | warn | `goblin_snarl` (slot) | missing |
| goblin | charge | `goblin_shriek` (slot) | missing |


**Raw recordings already in Dave's Downloads, not yet in the game** (licences to be checked into `assets/audio/CREDITS.csv` before
use): `Deer Call Sound Only.mp3` (deer rut or contact), `Moose Call-SoundBible.com-55857102.wav` and `Moose-SoundBible.com-1052749099.wav`
(moose rut or calf), `436__fox.mp3` (fox), `Crow Angry.mp3` and `crow calls 3 sets of 3each.mp3` (crow alert and contact),
`sounds bird wings flapping speed normal.mp3` (take-off for the flight block), `Frog sounds various.mp3` (frogs). Jason or Kathleen
cut them into slot files.

**Most wanted first** (the ones a player meets in the starter area): pheasant flush cackle, crow caw, dog bark, boar grunt and squeal,
elk bark, goose honk, cow moo, goat bleat, fawn bleat.

## Check
Run sheet: with `voice_fx` on in a game session, a deer herd bolting gives two or three snorts, not one per deer, and a warning bear
huffs, then roars only when it charges. No strip (the motion tool has no sound).
