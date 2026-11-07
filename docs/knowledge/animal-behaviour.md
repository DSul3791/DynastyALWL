# Animal behaviour: senses, fleeing, attacking, temperaments

**Last checked:** 2026-11-06 (web research by Jamie, our design from MikeW). **System owner:** MikeW. **Related:** `DESIGN_IDEAS.md` 4.13 (starter-island gradient), `docs/FAUNA_BEHAVIOUR_AUDIT_20261102.md`, `docs/FAUNA_MEASUREMENT_20261102.md`, `docs/ISLAND_FAUNA_20261103.md`, `data/animals/animals.json`, the server animal code (`ServerAnimals`, `server_big_game`).

## Lessons (read these first)

1. **Every reaction needs a cause the player can see.** theHunter's designers say a reaction without a visible reason feels like a bug. An animal that runs or charges should first look, call or warn. Ours warns before a charge (WARN, then CHARGE).
2. **Two ranges, one system.** A flee range (`spook_m`) and a closer threat range (`defend.threat_m`) cover most animals. Temperaments, seasons and young only scale these numbers; they don't add new code paths. Dave asked for one shared system (6 Nov).
3. **All attacks go through one gate.** `server_big_game.warn` asks `may_attack`, which covers the threat range, cornered and provoked attacks. A new attack path that skips it breaks temperaments and the fire rules.
4. **Use what the animal perceives, not the true distance.** Threat checks use the perceived distance, so a hunter the animal hasn't noticed is never charged. Senses (sight, hearing, smell) decide noticing; brush makes a little noise and the player's skill and speed decide whether animals hear it (Dave's rule, #445).
5. **New random draws break seeded tests.** Drawing a temperament at spawn shifts every random sequence after it. Put new traits behind the `ServerAnimals.traits` switch, which the old seeded tests turn off.
6. **Fire keeps animals away, with two exceptions.** A bear at its den and a mother with young ignore fire and torches (Dave 6 Nov). Wolves keep their own pack rules.
7. **Animals live on a schedule of needs.** theHunter gives each species zones to eat, drink and rest, on day or night schedules with some randomness; that is what makes animals findable and huntable. Our bear's fishing, foraging and sleeping trips are the start of this.
8. **Groups follow a leader.** In theHunter a herd leader decides and the others follow after finishing what they were doing. That small delay reads as natural; everyone turning at once reads as a machine. Boids (separation, alignment, cohesion) suit birds and fish.
9. **Levels rise with distance from the starter town; habitats don't change.** Every animal has a level: about 1-5 near the town, 5-10 further out, 10-20 on the far side. Each species still lives wherever is natural for it (Dave corrected this on 6 Nov; #479 placed species by distance; #485 fixes it).

## How ours works (6 Nov 2026)

- **Spawning:** species live in their natural habitat. The starter-island gradient sets each animal's level from its distance to the town point (spawn): about 1-5 near, 5-10 mid, 10-20 far (Dave 6 Nov). #479 first used it to decide which species spawn where; #485 makes it levels only.
- **Ranges** (`animals.json`): `spook_m` is the flee range; `defend.threat_m` is the attack range. Bear 15 m at its den and 9 m elsewhere, moose 8, boar 6, deer 3.5, horse 3, fox 2. Cornered animals hit weakly (4 to 10 damage).
- **Temperament** (`"temperament"` in `animals.json`, drawn at birth): passive (never attacks), defensive, neutral (never runs, attacks inside its range), aggressive (never runs, attacks from twice its range), friendly (walks up and stops 5 m short). Mixes: bear 60/25/15 defensive/neutral/aggressive, moose 70/30, boar 70/30 defensive/aggressive, deer 80/20 passive/defensive, fox 60/25/15 passive/neutral/friendly.
- **Seasons** (`"seasons"`): scale `threat_x` and `spook_x`. Bear ×1.5 in spring and ×0.7 in autumn; moose and deer ×1.5 in the autumn rut.
- **Young** (`"young"`): real animals with 30% of the mother's health that follow her and never attack. They go on the wire as species number + 100 and are drawn at half size. A mother flees ×1.4 sooner and attacks anyone within `between_m` of her young, torch or not. Chances: moose, bear and boar 30%, deer 25%, horse 20%.
- **Bear** (#480, open): 15 m den, roams up to 80 m, half its trips go fishing at a river edge, charges at 12 m/s for 35 damage, 120 HP.
- **Also:** animals stop at walls and heavy stations (#328); thrown spears hit for `throw_damage` (#224).

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| 2 Nov | Fauna behaviour audit and measurements | docs | Baseline for later work |
| 3-4 Nov | Starter island fauna note; frogs and ducks keep to fresh water | #209 | Worked |
| 4 Nov | Rabbit burrows and inland bird nests sent to the client | #236, #245, #329, #335 | Worked |
| 4 Nov | Thrown spears and javelins hit animals | #224 | Worked |
| 4 Nov | Animals stop at walls and heavy stations | #328 | Worked |
| 4-5 Nov | Coats, shadows, wolf looks, one barrel body with a smooth neck | #229, #266, #64, #347 | Worked (looks) |
| 5 Nov | Undergrowth never blocks the player but is louder to animals | #445 | Worked |
| 6 Nov | Starter island wildlife gradient: level bands that kept big game away from the town | #479 | Wrong reading of Dave's ask; merged, then reworked |
| 6 Nov | Levels change strength, never placement: each animal draws a level at birth (1-5 by the town, 5-10 half way, 10-20 far side) | #485 | Worked (merged) |
| 6 Nov | Bear, threat range, temperaments, seasons, young | #480 | Worked (merged) |
| 6 Nov | Realistic bought models (WildMesh FBX) drawn per species from data/animals/models.json; the code body is the fallback | #495 | Worked. The FBX keeps its cm scale on a bone, so size from the posed bones, not the mesh bounds (a 100x giant before). A black neck band on the bear was taken for fur cards drawn solid; alpha scissor added, look not yet rechecked. Model files are never committed (public repo) |
| 7 Nov | Offline animal sheet and live-game shots of animals: animal_sheet.gd `--models`, shot runner `--shot-animals=bear,deer` | #501 | animal_sheet works windowed only (the headless dummy renderer cannot draw). The live game shot had no way to place an animal before this |
| 7 Nov | Seven more WildMesh species (deer, moose, boar, wolf, fox, rabbit, horse) and a new donkey (species 15); clips found by role, saddles hidden | #505 | Worked: sizes right, saddles hidden, donkey clip names differ from the horse and the role lookup found them. Tests that use an "unknown" species number must derive it (highest known + 1) |
| 7 Nov | Realistic bear drew as a legless fur tube in the live game (it stood on the offline sheet) | #509 | Cause NOT pinned down. Ruled out: clip bone units (no rescale fired), clip pose height (guard never fired). A skin rebuild measured against an assumed mesh space broke 8 good animals (steady 1.4x offset): measure bind agreement across bones instead. After #509 the bear stands at 4 m with no guard firing. All three guards stay and log one line if they ever act; if the tube returns, read those lines first |

## What others do (with sources)

- **theHunter: Call of the Wild.** Senses for sight (motion matters most), hearing and wind-borne smell; an alert call and an on-screen hint showing which sense fired; need zones for eating, drinking and resting on day or night schedules; single-sex herds with a leader; flee distance depends on where the animal was hit; older males are warier; valleys and water make natural ambush points. https://www.gamedeveloper.com/design/thehunter-call-of-the-wild-designing-believable-simulated-animal-ai
- **Red Dead Redemption 2.** A GDC 2020 talk on bringing wildlife to life with animation: many small transitions and reactions sell the AI more than the decision logic does. https://gdconf.com/news/learn-how-rockstar-breathed-life-wildlife-red-dead-redemption-2-gdc
- **Boids in Godot.** Separation, alignment and cohesion for flocks and schools, with a worked Godot example. https://en.bioerrorlog.work/entry/boids-flocking-godot

## Decided / next

1. #480 through the PC gate, then a windowed look at the bear and a calf (Dino).
2. Poses for fishing, foraging and sleeping; hibernation later. A young animal's carcass is still full size.
3. Later: moods that change over time; toughness rising with the gradient.
4. Worth borrowing from theHunter: a visible cue for which sense spotted you, and need zones with schedules for every big species.

Open questions go on the QA page. The nine bear and gradient cards were answered on 6 Nov.
