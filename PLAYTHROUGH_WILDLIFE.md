# PLAYTHROUGH_WILDLIFE: what lives in the game, what a new player can hunt, and what "teeming" needs

Date 2026-10-31. Sources: `data/animals/animals.json`, `src/stream/server_animals.gd`, `data/animals/spawn_plan.json` (Sal, 44 species, read by nothing), `FAUNA_BY_BIOME.md`, `FAUNA_SPAWN_PLAN.md`, `data/items/carcass.json`, `traps.json`, `bow.json`, `fishing.json`, and a headless run of the real animal code on the real baked terrain and flora (`art/playthrough/probe_wildlife.gd`, output `probe_wildlife_output.txt`, `wildlife_survey.json`). Pictures: `art/playthrough/animals/`.

## 1. What exists today

Seven species have server rules and a model. Everything else in the fauna files is a proposal.

| Species | Spawn rule today (`animals.json`) | Health | Flees from | Model | Loot (carcass.json) | Notes |
|---|---|---|---|---|---|---|
| Rabbit | 6 a player, forest or open | 5 | 14 m (alerts at 24 m) | yes, small and low | meat 1-2, hide 1, bone 1-2 | owns a burrow within 40 m, goes to ground |
| Red deer | 5 a player in herds of 3 to 6, prefers a spot under trees | 20 | 30 m (alerts at 50 m) | yes (stag with antlers, and a hind) | meat, hide, bone, sinew, fat, antler | herd bolts together, blood trail, bleeds out |
| Fox | 1 a player, share 0.5, forest | 12 | 22 m | yes | meat 2-3, hide, bone, sinew | |
| Moose | 1 a player, share 0.2; **excluded within 1,500 m of 53301, 68427** (the old spawn) | 90 | 28 m | yes | meat, hide, bone, sinew, fat, antler | |
| Wild horse | 2 a player in herds of 3 to 6, open ground; same 1,500 m exclusion | 60 | 25 m | yes (reads as a deer-llama, see section 5) | **no carcass row** | |
| Duck | 1 flock (6 to 14 birds) a player, needs water | 3 | 22 m | yes (blobby) | meat, feather, bone, down | |
| Wolf | **0**: `natural` false, admin spawn only | 30 | none | yes | meat, hide, bone, sinew, claw | pack brain exists (`server_wolves.gd`) |

Behaviours the code has: grazing, hopping, alert (freeze and watch), flee (zig-zag bolt, then trot), herd follow with a sentinel, rabbit burrows, wind and crouch senses, forest sight blocking, blood trails, bleeding out, snares, arrows and spear jabs, carcass dressing by knife, fish schools in water.

## 2. What a player actually sees: the simulation

Real `server_animals.gd`, real terrain, flora crowns as the forest test, one player standing at the spawn (53316, 68476), 10 simulated minutes, three seeds (art/playthrough/probe_wildlife_output.txt):

| Seed | Total animals alive | Within 100 m | Within 300 m | Herd sizes |
|---|---|---|---|---|
| 7 | 16 | **0** | 9 deer, 6 rabbits, 1 fox | 4, 5 |
| 11 | 12 | **0** | 5 deer, 6 rabbits, 1 fox | 5 |
| 23 | 13 | **0** | 6 deer, 6 rabbits, 1 fox | 6 |

* **The count is reached in two minutes and never changes** (target per player is a cap, not a population).
* **Nothing lives within 100 m of the spawn**: animals appear 150 to 250 m away, "out of sight", and a standing player never meets them. All three species stay in grazing, hopping or alert states: nothing hunts, nothing fishes, nothing flies.
* **Only three species appear**: rabbit, deer, fox. No moose, horse or duck turned up in any seed (moose and horse are excluded from the starter area, ducks need water and a flock lane).
* **Day and night are identical**: the animal code has no clock, no season and no biome input (grep of `server_animals.gd` for night, hour, season finds nothing).
* Per player cap 30, server cap 150: the whole server tops out at 150 animals.
* Compared with the plants (about 125 trees and 240 ferns per hectare in the same forest, `WORLD_ALIVE_LOG.md`), the animal layer is thin: about 13 animals within 300 m of a player, a 28 hectare disc of forest.

## 3. What is wired and what is not: the 44 planned species

`spawn_plan.json` is data, read by nothing. Against what exists:

| Class | Planned | Have a carcass row | Have a model |
|---|---|---|---|
| land mammals | 14 (hare, beaver, otter, badger, pine marten, porcupine, lynx, bear, boar, reindeer, mountain goat, wild sheep, grass snake, seal) | 12 | 0 |
| birds | 8 (grouse, pheasant, goose, gull, raven, owl, eagle, seabird) | 6 | 0 |
| ambient (red squirrel, hedgehog, bat, woodpecker, songbirds, frog, toad, newt, adder, lizard, bee, butterfly, dragonfly, firefly, beetle) | 15 | 0 | 0 |
| water and shore (salmon, eel, cod, crab, mussel, kelp, shore crab node) | 7 | 0 | 0 |
| **Total** | **44** | **18 have a loot row** | **0 have a model (only the 7 live species do)** |

What must change for "teeming", in order (owner, size):

1. **Biome and time gating in the spawn loop** (`_top_up` ignores biome, time and season; Sal's `FAUNA_SPAWN_PLAN.md` lists five code steps). Tyler. Medium.
2. **Models**: 37 species need one (the 7 live builders are in `animal_view.gd`; the rest would draw nothing). Kathleen. Large (start with the 12 land mammals that already have loot: hare, badger, boar, beaver, otter, bear, porcupine, lynx, reindeer, goat, sheep, seal; and the six birds that have loot).
3. **Carcass rows** for the 26 species without one (every ambient species, the pine marten and grass snake, the raven and owl, and all water and shore species). Sal. Medium; ambient species may need no loot at all (a design call).
4. **Nothing near the spawn**: a first-minutes scatter (or `spawn_min_m` 60 for rabbits and ambient animals) so the spawn does not look empty. Tyler. Small.
5. **Ambient life you can see**: today the nature layer is sound only (`ambient_life.gd`, `insect_bed.gd` are audio). No butterflies, birds in flight, frogs or insects exist as things in the world. Kathleen and Tyler. Large.
6. **Predation and ecology**: wolves are admin-only; nothing hunts prey, nothing is hunted by anything but the player. Tyler. Large, later.
7. **A horse carcass** and what a horse is for (tame, ride, haul). Sal. Small.

## 4. First-hour hunting, fishing and trapping route (new player)

Every row was checked in data and in the existing headless tests (re-run by `art/playthrough/run_hunt_tests.sh`; output `hunt_tests_output.txt`): test_bow 19 pass, test_traps 26 pass, test_big_game 0 failures, test_fishing 0 failures, test_fish_schools 16 pass, test_fish_water 14 pass, test_fish_balance 16 pass, test_animal_senses 0 failures, test_shore_net 0 failures. I did not drive a whole kill-to-roast chain by hand.

| Step | Needs | Where the animals are | Result | Status |
|---|---|---|---|---|
| Spear | wooden spear: 1 stick, keeps a stone (damage 6); stone spear: + 2 twine (damage 8) | n/a | craftable from nothing | PASS |
| Find prey | walk 150 m from the spawn | rabbits, deer, fox appear 150-250 m out in a ring | a standing player sees none (section 2) | PASS with caveat (F-30) |
| Approach | crouch (x0.6), upwind (x0.5 scent), terrain cover | rabbit alerts at 24 m, bolts at 14 m, burrow 40 m; deer alerts at 50 m, bolts at 30 m | hard but fair; blood trail follows a wounded animal, bleeds out in about 80 s | PASS |
| Kill by spear | jab, cooldown 0.6 s | rabbit 5 HP = 1 jab; fox 12 HP = 2 stone jabs; deer 20 HP = 3 stone jabs (4 wooden) | works (animals tests) | PASS |
| Kill by bow | wooden bow at a workbench: 2 sticks, 3 twine; arrows: fibre arrow 2 sticks + 1 fibre makes 4 (damage 3.5), wooden arrow needs 2 feathers (damage 5), stone arrow (8) | same | range 80 m, shot noise alarms animals within 40 m; a deer needs about 6 fibre arrows | PASS |
| Dress the carcass | stone knife: 2 stones + 1 stick; 4 blows | at the kill | rabbit: meat, hide, bone; fox: + sinew; deer: + sinew, fat, antler (antler is a grey blob, F-18) | PASS |
| Cook | raw meat roasts at a lit fire (hold E): becomes roast meat; raw meat eaten raw makes you sick for 24 h | camp | works | PASS |
| Use the hide | waterskin (2 hide + 1 twine); hide clothes 1 to 3 hides each | | craftable; leather and processed hide need flint (F-02) | PASS to cloth, BLOCKED to leather |
| Snare | 3 twine + 2 sticks; open ground well away from buildings | catches rabbit (weight 1.0), fox (0.4), duck (0.5); never deer or bigger | test_traps 26 pass | PASS |
| Fishing line | rod: 2 sticks + 2 twine; bait: berries, raw meat or plant fibre; water must be near | the spawn pond: carp 60 %, perch 40 % (pond table); streams trout 70 %, perch 30 %; lakes pike 30, perch 40, carp 30 | fish roast to roast fish | PASS (fish look good on `items_01.jpg`) |
| Shore net | 8 twine + 4 stones, hold at the water's edge about 20 s | 1 to 3 small fish | test_shore_net 0 failures | PASS |
| Big game | moose 90 HP, horse 60 HP | **not within 1,500 m of 53301, 68427** | cannot be met near the spawn | MISSING (F-28) |

## 5. The animals as drawn (art/playthrough/animals/animals_side.jpg and animals_front34.jpg)

Made with `art/playthrough/animal_sheet.gd` from the client's own builders (`animal_view.gd`), no server, no world.

| Animal | Rating | Problem | Owner |
|---|---|---|---|
| rabbit | 3 | tiny and low; ears and white tail read at close range only | Kathleen |
| fox | 4 | good colour and brush | Kathleen |
| red deer (stag) | 3.5 | antlers read; legs thin and straight; neck long | Kathleen |
| deer (second variant) | 3 | no antlers, same stiff legs | Kathleen |
| moose | 3 | dark hump and drooping neck read as an animal but the head is small and the legs are straight posts | Kathleen |
| horse | 2.5 | long neck, upright ears and thin legs read as a deer or a llama; the horse is the weakest | Kathleen |
| wolf | 3.5 | grey, hunched, believable at a distance | Kathleen |
| duck flock | 3 | blobby, flocks of ducks sit on single bodies; a flock of three birds is visible | Kathleen |

(`art/CRITIQUES/fauna_2026-10-30/CRITIQUE.md` already has Kathleen's rounds on the deer, fox and rabbit.)

## 6. Action rows (F-28 and up)

| ID | Sev | What | Evidence | Owner | Size |
|---|---|---|---|---|---|
| F-28 | HIGH | **Only seven species are alive, and near the spawn only three** (rabbit, deer, fox). Moose and horse are excluded within 1,500 m of the OLD spawn point 53301, 68427, which is still the exclusion centre; ducks need a water flock lane; wolves are admin-only. | probe_wildlife_output.txt (three seeds); animals.json `exclude` rows | Tyler (exclusion centre and radius), Sal | small |
| F-29 | HIGH | **Spawning ignores biome, time of day and season.** The same rabbit, deer and fox appear in forest, grass, heath and marsh, day and night; the 44-species plan is read by nothing. | `server_animals.gd _top_up`; `FAUNA_SPAWN_PLAN.md` | Tyler | medium |
| F-30 | MEDIUM | **The spawn looks empty**: nothing lives within 100 m of the player ever, and ambient fauna (birds, insects, frogs) exists only as sound. | probe_wildlife (0 within 100 m); `ambient_life.gd`, `insect_bed.gd` are audio | Tyler (near spawn), Kathleen (ambient models) | small / large |
| F-31 | HIGH | **37 of 44 planned species have no model** and 26 have no carcass row; wired today they would be invisible or unbutcherable. | spawn_plan.json vs animal_view.gd builders vs carcass.json | Kathleen (models), Sal (carcass rows) | large |
| F-32 | LOW | The horse has no carcass row. | carcass.json | Sal | small |
| F-33 | MEDIUM | No predation or ecology: only the player hunts; wolves are admin spawn. | animals.json `natural` false | Tyler | large |
| F-34 | MEDIUM | The horse and moose models look weak (horse reads as a llama). | `animals/animals_side.jpg` | Kathleen | medium |

## 7. How to re-run

```bash
godot --headless --path . --script res://art/playthrough/probe_wildlife.gd        # the simulation (about 2 minutes)
godot --path . --script res://art/playthrough/animal_sheet.gd -- --out=art/playthrough/animals   # pictures
bash art/playthrough/run_hunt_tests.sh                                              # the existing hunting, fishing and trap tests
```
