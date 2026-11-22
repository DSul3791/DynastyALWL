# How each animal behaves, and how the game does it (21 Nov 2026)

Status: **PROVISIONAL** values HB-1 to HB-3, set 21 Nov 2026 under Dave's rule of the same day (agents' questions are answered from
research and common sense, and recorded). Dave, 21 Nov 2026: "Agressive animals should be aggressive and passive animals should be
passive etc. list each animal and look up how they should naturally behave in situations like, relaxing, eating, being approached by a
human, being attacked etc. then find a way to work those findings into the animals ai."

Data: `data/animals/animals.json` (species `temperament`, `hunter`, `defend`, `active`; `temperament.kinds`). Code:
`src/stream/server_animals.gd` (`_step`, `_chases_runner`), `src/stream/server_big_game.gd` (warn, charge, recover). Test:
`src/worldgen/tools/test_animal_hunters.gd`. Distances: `docs/design/ANIMAL_REACTIONS.md`.

## What the game already did (unchanged)

Every animal is born with a temperament, drawn from its species' shares (Dave, 6 Nov 2026):
- **passive**: runs, never attacks (a mother defending her young is the exception);
- **defensive**: runs, but warns and charges a player inside its threat range, and fights back when hurt;
- **neutral**: ignores a player until it is inside its threat range, then as defensive;
- **aggressive**: does not run, and attacks from twice its threat range;
- **friendly**: comes up to a player and stops short, never attacks.

Also already in: notice / flee / safe distances, senses (wind, stance, cover, noise, a running player), herds and alarm groups,
active hours and resting, mothers with young, seasons (rut, spring hunger), dens, fire and torches, dogs, bluff charges for bears.

## What changed

- **HB-1, temperament shares by species** (table below). Some species had the generic small-carnivore mix, so 15% of tigers, lions,
  leopards, pumas and hyenas were "friendly" and walked up to the player. They now follow the research.
- **HB-2, predators chase a runner.** A predator with a `hunter` row that may attack (defensive, neutral or aggressive) charges at
  once, with no warning and no bluff, at a player running away from it at 5 m/s or more inside `hunter.chase_m`, and runs up to
  `hunter.run_m` before it gives up (a defending charge runs only `defend.charge_m`). The charge is dodged as any other: step aside.
  The usual cool-down follows. Wildlife agencies advise not to run from big cats and bears,
  because running "may trigger an instinct to chase" (Panthera) and people who run "are statistically more likely to be attacked"
  (bears). A passive or friendly one never does.
- **HB-3, aggressive predators hunt.** A `hunter` born aggressive walks in on a player it has noticed (within its notice distance), at
  `hunter.stalk_mps`, until its threat range starts the warning and the charge. This is the rare predatory animal (5% of brown bear
  attacks, most fatal black bear attacks, man-eating big cats). It never walks into a fire's or torch's light, never out of its active
  hours, never as a young one, and not while it cools down after a charge. Aggressive animals without a `hunter` row (boar, buffalo, rhino, alligator) stand their ground and
  charge from close, as before; they do not stalk.

Cost: one distance test and one dot product per hunter step, only for the seven hunter species near a player.

Hunter values (`chase_m` / `run_m` / `stalk_mps`): brown bear 25 / 50 / 1.3, black bear 15 / 35 / 1.2, puma 20 / 40 / 1.0, lion
25 / 50 / 1.1, leopard 15 / 35 / 1.0, tiger 25 / 45 / 1.0, hyena 15 / 60 / 1.3 (hyenas run prey down over distance).

## The table

"In game" gives the temperament shares (P passive, D defensive, N neutral, A aggressive, F friendly) and anything special. Rows marked
**new** changed on 21 Nov.

| Animal | Relaxing / eating | Approached by a person | Attacked or cornered | In game |
|---|---|---|---|---|
| Rabbit | Grazes near cover at dawn and dusk; freezes | Freezes, then bolts to its burrow | Flees | Runs, hides in its burrow |
| Deer | Grazes and browses in small herds; one watches | Stares, stamps, flags tail, bounds off | Flees; a rutting stag can strike | P .8 D .2, bolder in autumn |
| Elk | Grazes in herds, dawn and dusk | Watches, moves off as a herd | Flees; bulls in rut and cows with calves charge | D .7 N .3 |
| Moose | Browses alone; often stands its ground | Ears back, hackles up, lip licking, walks toward you; usually flees if pushed | Charges and kicks (most charges are bluffs); cows with calves and rutting bulls worst (ADF&G) | D .7 N .3, calves, autumn rut |
| Wolf | Rests and travels in packs | Avoids people; watches from a distance | Pack defends; rare attacks | Pack brain (`server_wolves.gd`), unchanged |
| Fox | Mouses alone at dusk and night | Watches, slips away; town foxes bolder | Flees; bites if grabbed | **new** P .8 N .15 F .05 |
| Brown bear | Forages berries, roots, fish; sleeps by day in heat | Usually avoids people; stands up to smell; huffs, jaw-pops | Defensive attack when surprised or with cubs; 5% of attacks predatory (Bombieri 2019) | **new** D .75 N .2 A .05, hunter |
| Black bear | Forages; climbs trees | Usually flees or trees; mock charges | Rarely defends cubs; most fatal attacks were predatory (Herrero) | **new** P .5 D .4 A .1, hunter |
| Wild boar | Roots and wallows in groups, mostly at night | Shy, flees; old males stand and watch | Sows with piglets, wounded or cornered boars charge; mock charges first (Forestry England) | **new** P .3 D .65 A .05 |
| Warthog | Grazes on its knees by day | Trots off, tail straight up | Sows and cornered boars charge with tusks | **new** P .2 D .75 A .05 |
| Lynx | Rests in cover by day, hunts at night | Very shy, gone before seen | Bites only if cornered | **new** P .9 N .1 |
| Puma | Rests by day; ambush hunter | Avoids people; attacks "extremely low" risk; do not run (Panthera) | Fights if cornered; rare stalking attacks | **new** P .6 D .3 A .1, hunter |
| Lion | Rests most of the day in prides | Resting lions stay put; growl, tail flick; do not run (Panthera) | Charges (often a bluff); some prides hunt people | **new** P .3 D .5 A .2, hunter |
| Leopard | Rests in trees by day | Usually long gone; growls, shows teeth if cornered | Very dangerous when wounded or cornered; rare man-eaters | **new** P .6 D .3 A .1, hunter |
| Tiger | Rests by day; ambush from behind | Resting tigers stay put; do not run (Panthera) | Attacks if cornered; man-eaters stalk people | **new** P .4 D .4 A .2, hunter |
| Hyena | Rests by day, forages and scavenges at night | Steers clear by day, bolder at night | Bites when cornered; attacks on sleeping people at night | **new** P .5 D .4 A .1, hunter, night hours |
| Honey badger | Digs for food alone | Tries to avoid trouble, but does not flee far | Rushes at the attacker, hackles up, musk (Discover Wildlife) | **new** D .6 N .4 |
| Cape buffalo | Grazes and wallows in herds | Stares, may move off; herd may charge together | Wounded ones ambush and charge; among the most dangerous game | **new** D .6 N .2 A .2 |
| Rhino | Grazes or browses, wallows | Poor sight; snorts, charges when surprised | Charges; cows with calves | **new** D .6 N .15 A .25 |
| Elephant | Feeds and bathes in family herds | Ears spread, head up, mock charge; matriarch protects calves | Real charges; musth bulls aggressive unprovoked | **new** D .7 N .25 A .05 |
| Mammoth | As the elephant | As the elephant | As the elephant | **new** D .7 N .25 A .05 |
| Alligator | Basks on banks; hunts at dusk and night from the water | "Normally avoid humans", slides into the water; hisses (UF/IFAS) | Females at nests hiss and charge; rarely pursue on land | **new** P .4 D .5 A .1 |
| Bighorn, mountain goat, chamois | Graze steep ground in bands | Watch, climb away | Flee; males butt in rut | P .8 D .2 |
| Pronghorn, wildebeest | Graze in herds on open ground | Watch, then run far | Flee; cornered ones kick or hook | P .8 D .2 |
| Kangaroo | Grazes at dawn and dusk, rests in shade | Watches, hops off | Big males box and kick if cornered | P .8 D .2 |
| Horse, donkey, camel | Graze in groups | Watch; some come over (tame value) | Flee; kick or bite if cornered | Tame value, D |
| Cow, goat | Graze, chew the cud lying down | Watch; stock animals let people close | Cows with calves push or charge | As before |
| Beaver | Feeds by the water at dusk | Tail slap, dives | Bites if cornered | Runs to water |
| Mink | Hunts the banks alone | Slips away | Bites hard if cornered | **new** P .85 D .15 |
| Raccoon | Forages at night | Watches, waddles off; town ones bold | Bites if cornered | P .6 N .25 F .15 |
| Rat, cat, dog | Forage near people | Keep off; some strays come over | Bite if cornered | As before |
| Birds (songbirds, crow, pheasant, grouse, guineafowl, chicken, duck, goose, seabird) | Feed on the ground or water in groups | Walk off, then fly; grouse and pheasant sit tight then burst up | Fly | Flocks, flush, perch |
| Frog, seal | Sit by or in the water | Jump or slide into the water | Flee | Runs to water |

## Sources

- Panthera, "What to do if you encounter a wild cat": https://www.panthera.org/blog-post/what-do-if-you-encounter-wild-cat
- Wikipedia, "Bear attack" (Herrero's black bear findings): https://en.wikipedia.org/wiki/Bear_attack
- Bombieri et al. 2019, brown bear attacks on humans: https://www.nature.com/articles/s41598-019-44341-w
- Alaska Department of Fish and Game, aggressive moose: https://www.adfg.alaska.gov/index.cfm%3Fadfg=livewith.aggressivemoose
- Utah Division of Wildlife Resources, moose behaviour: https://wildlife.utah.gov/news/utah-wildlife-news/1204-moose-behavior-avoid-conflicts-what-you-should-know.html
- Forestry England, wild boar in the Forest of Dean: https://www.forestryengland.uk/article/wild-boar-the-forest-dean
- Better Planet Education, hyenas and humans: https://betterplaneteducation.org.uk/factsheets/hyaenas-hyaenas-and-humans
- UF/IFAS, living with alligators: https://edis.ifas.ufl.edu/publication/UW230
- Discover Wildlife, why honey badgers are aggressive: https://www.discoverwildlife.com/wildlife/mammals/why-are-honey-badgers-so-aggressive
- Green Matters, Cape buffalo: https://www.greenmatters.com/nature/why-are-cape-buffalo-so-dangerous
- The Standard (Kenya), fight or flight zones: https://www.standardmedia.co.ke/amp/travelog/article/2001352868/the-fight-or-flight-zones-of-wild-animals

## Not done here

- **Lying down to rest.** A resting animal is sent as grazing, so it plays its grazing clip. Many models have lying clips
  (`Lying_Breathing_01`, `idle_lay_*`). Showing them needs a new animal state on the wire (a protocol number), so it is left for a
  later stage.
- Hippos and polar bears are not in the game.

## Fauna data review (coordinator's list, 21 Nov 2026), checked against the data

- **Ducks have no biomes or habitat row.** They do not need one: a duck is a flock record, and flocks are placed on water
  (`flock.fresh_only`, `_habitat_score`). No change.
- **Rabbits spawn singly.** Wild European rabbits live in warrens and feed in loose groups at dawn and dusk, so groups of 2 to 4 would
  be truer. Not changed here: it alters spawn counts that `test_animals` checks (one rabbit per share), so it goes with its own test
  change in a later stage.
- **Only the moose has seasons.** Not so: 16 species have a `seasons` row (deer, moose, both bears, elk, bighorn, mountain goat,
  chamois, goat, buffalo, pronghorn, wildebeest, rhino, elephant, kangaroo, mammoth). No change.
- **Low daytime activity** (rabbit 0.5, deer 0.4, boar 0.02). This is how they live: rabbits and deer feed mostly at dawn and dusk,
  and boar are mostly nocturnal where they are hunted (Forestry England, ScienceInsights). A player at noon should see fewer of them
  and more at dusk. No change.
- **spook_m, safe_m, flee_run_m and graze_s untuned in play.** The sources give no distances to use; the 19 Nov table
  (`ANIMAL_REACTIONS.md`) stays until Dave's play test says otherwise.
