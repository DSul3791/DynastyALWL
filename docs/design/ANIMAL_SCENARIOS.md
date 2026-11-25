# Animal behaviour by scenario (25 Nov 2026)

Status: **RESEARCH**, for the fix threads. Nothing here is built yet. Where a line says "in our game", it says what the animal
should do; the gap list at the end says where today's game differs, biggest first, one fix per item.

Asked by Dave, 25 Nov 2026, after playing live build 10587: "compile a behaviour document on how they should behave in the scenarios
they will encounter in our game. sleeping, eating, relaxing, scared, threatend, injured and any others I cant think of. make a list of
scenarios and research them." Then: "work on applying those behaviours. Also remember fire keeps everything away from the players."

What prompted it (his play test, a bear): "the bear really should be able to out run me. also a threatened bear should turn and fight
back. first it should stand its ground and standup on its hind legs. then it should attack with its claws or mouth."; "as a new person it
should have made short work of me. but also It should have run away unless it was starving or trapped."; "the goal will be to learn how
to trap them"; "the bear roaring constantly in the woods is unrealistic. look up how real bears behave. these are typical black bears
according to the model look."

**Dave's words win.** Where real animals and Dave's words differ, the "in our game" line follows Dave and says so. Real numbers are given
so the fix threads can tune from them.

Earlier work this builds on, not replaced: the temperament table and hunters (`ANIMAL_BEHAVIOUR.md`), notice / flee / safe distances
(`ANIMAL_REACTIONS.md`), the bear warning ladder (`bear_threat_design.md`), resting (`ANIMAL_RESTING.md`), routines, trails and snares
(`ANIMAL_ROUTINES_TRAILS_TRAPPING.md`), weather (`animals_in_weather_design.md`), voices (`../SOUND_MAP.md`).

## Rules every animal keeps (standing rulings)

1. **Fire keeps everything away from players** (Dave, 25 Nov 2026). See "Fire" below. It beats hunger, cornering, young and dens: by
   Dave's standing rule "newer rules override older ideas" (23 Nov 2026) it replaces the older den rulings of 6 and 8 Nov (see "Fire").
2. Animals **stare before fleeing** and **warn before attacking** (growl, huff, stamp; Dave 23 Nov 2026).
3. No teleporting, sliding or passing through players; every animal can be hit; each model uses **its own** moves and attacks (Dave's
   play-test rulings 19 to 24 Nov 2026, relayed by the coordinator; see `ANIMAL_NETCODE.md`).
4. Blood trails and bleeding to death stay.
5. Sound is directional and easy to pinpoint (Dave 23 Nov 2026, `../SOUND_MAP.md` "Direction").
6. **Core rule** (Dave 23 Nov 2026, quoted in `src/worldgen/tools/test_survival_loop.gd`): "this game doesn't want you to die unless you do
   something really stupid"; at 1 health no blow takes more (the test checks a wolf bite).
   An animal that has beaten a player down to 1 health has won: it stops and leaves (a defensive animal) or stands over them only
   while they stay down (none today).
7. Snares catch rabbits and foxes on game trails. A fire, building, placed torch or tilled bed within 20 m empties a rabbit warren.
8. A game day is one real hour, so "a game hour" is 2.5 real minutes. Clock words below (dawn, dusk, night) are game time.

## Fire (all animals)

Today (code, 25 Nov 2026): `server_items.fire_spots()` lists every keep-off spot, and `server_animals._fire_guard` keeps animals out of
them. An animal inside one bolts away; none wanders in; none charges or stalks a player who stands inside one.

| Light | Keep-off radius today | Where it is set |
|---|---|---|
| Small campfire (sticks, kindling) | 5 m | `data/items/cooking.json` fire_tiers protect_m |
| Campfire (3+ firewood) | 10 m | same |
| Bonfire (3+ logs) | 20 m | same |
| Torch or lantern carried, lit | 9 m | `server_items.gd` TORCH_PROTECT_M |
| Standing torch, torch post, pillar, iron stand (lit) | 8 m | `data/items/structures.json` protect_m |

Exceptions in the code today, from older rulings that Dave's 25 Nov words replace under his 23 Nov rule "newer rules override older
ideas" (the coordinator tells Dave, who can bring them back) (the bear den: Dave
6 Nov 2026 in the brown bear row note, "a torch does not protect you at its den", and `bear_threat_design.md` "Fire still does not help
inside the den ring"; the wolf pup den: `wolf_packs_and_pups_design.md`, "torch or not", a campfire still holds): a bear at its den ignores a torch or fire (`_in_den`); a mother with a player
between her and her young attacks "torch or not"; a wolf pack rushes a player near its pups' den "torch or not" (a campfire still holds
it); wolf packs skip the general fire check and use their own (`a.has("pack")`).

Real animals: most wild mammals avoid fire and smoke, and people at a camp. Food-conditioned bears and wolves do walk into camps for
food (NPS, bear.org), and fire alone does not stop a determined predator. Dave's rule wins: in our game a lit fire always holds.

In our game (recommended):
- Keep today's radii. They scale with the fire's size, which is easy to learn.
- **No exceptions** (the den, mother and pup-den exceptions are removed under the 25 Nov ruling). A starving animal circles at the edge of the light and waits, it does not come in. A cornered animal next to a fire
  breaks away along the edge, never through the light and never at the player in it. A mother whose young is near a player standing in
  firelight calls the young away instead of charging. A den guard holds at the edge.
- The player should see where safe is. Today the glow is smaller than the keep-off ring for the small and medium fires (light 3.5 and
  7 m against 5 and 10 m, `cooking.json`), so the glow edge is not the safe edge; align them or keep the ring larger than the glow.
- A trapped animal (in a snare or trap) does not move; fire near it changes nothing.
- Fire is not a weapon: an animal already charging when the player lights a torch turns off at the edge of the new radius, it does not
  pass through. (Today a charge is locked; check it.)

## The scenarios

Each animal section answers these, in this order. Short names are used in the tables.

| # | Scenario | What it covers |
|---|---|---|
| S1 | Unaware, relaxing | wandering, standing, grooming, normal walk |
| S2 | Eating, drinking | grazing, browsing, foraging, at water |
| S3 | Sleeping, resting | when, where, how long, how deep |
| S4 | Notices a player far off | first reaction, the stare, how far it can sense us |
| S5 | Player comes closer | the flight distance, warnings |
| S6 | Scared, fleeing | how fast, how far, where to |
| S7 | Chased | a player keeps after it |
| S8 | Cornered | water, cliff, wall, dead end; run down by the chase |
| S9 | Threatened up close | surprise at close range, at its food or kill, at its den |
| S10 | Hurt, bleeding | hit and running, bedding down, the blood trail |
| S11 | Dying | last moments, sounds |
| S12 | Caught in a snare or trap | how it struggles, what it does when a player comes |
| S13 | With young | mothers, hiding young |
| S14 | Hungry, starving | late winter, spring, poor food years |
| S15 | Hunting prey | predators only |
| S16 | Meets another animal | predator, prey, rival |
| S17 | Herd, pack, family | group size, alarm, sentinels |
| S18 | Night and day | active hours |
| S19 | Weather and seasons | rain, wind, snow, cold, heat, rut, denning |
| S20 | Fire, torches, camps, buildings | see "Fire" |
| S21 | Sounds | which sound in which scenario, and how often |

---

## Bears (written first: another thread is fixing the bear now)

Our game has two bear species. Both are North American forest bears.
- **Black bear** (`black_bear`, species 18): model `assets/animals/black_bear/SK_BlackBear.fbx` (WildMesh BlackBear). Real species:
  American black bear, *Ursus americanus*. Health 90.
- **Brown bear** (`bear`, species 14): three looks, two on `SK_Bear.fbx` (WildMesh BrownBear) and one on `bear_2/SK_Bear.fbx` (WildMesh
  "Bear", the darker one). Real species: brown bear or grizzly, *Ursus arctos*. Health 120. Has a den near rivers.

Dave says the bears he met look like typical black bears. Both species roam the same forests (temperate, mixed, boreal) at about the same
share, so the one he chased may have been either; the darker brown bear look reads as a black bear too. **Recommendation: in our world
both behave by the black bear rules below, with the brown bear differences listed after.**

### Real numbers (black bear)

| What | Number | Source |
|---|---|---|
| Top speed | "Lean bears can exceed 30 mph" (13.4 m/s and up). Fat bears in winter coats "overheat and tire quickly" | [BO27] |
| Our player | runs 9.0 m/s (`terrain_client.gd` RUN_SPEED); an unfit player is over-exerted after about 35 s (pace x0.9) and faints at about 50 s (`data/items/exertion.json`) | code |
| Smell | strongest sense; "a scent from over a mile away" (1.6 km), "seven times better than a bloodhound" | [FWC] |
| Hearing | about twice as sensitive as ours; "often hear humans before we see them" | [FWC], [BO27] |
| Sight | colour, good close up; forms at about 90 m, details within about 27 m | [FWC], [BO27] |
| Hours | active from half an hour before sunrise, one or two naps by day, beds down an hour or two after sunset; some active at night | [BO27] |
| Group | solitary; mother with cubs; pairs in the mating season (late May to early July); gather only at rich food | [FWC], [BO27] |
| Young | cubs stay 16 to 17 months; litters of 1 to 3 (our data: 1 to 3) | [BO27] |
| Home range | core: females 3 to 10 km across, males 13 to 24 km | [BO27] |
| Denning | up to 7 months in the north; born in the den in January or February | [BO27] |
| Food | nuts, acorns, fruit, insects, greens; meat when preferred food is scarce | [BO27] |
| Danger | 61 people killed in North America since 1900; "most attacks ... are defensive reactions to a person who is too close"; the killings were rare predatory attacks | [BO254] |

### Sounds: why "roaring constantly" is wrong

Real black bears are quiet animals:
- "Usually silent"; "does not threaten by growling" [BO27]. "Black bears seldom, if ever, growl" [BS]. A threatened bear "does not roar
  or growl" [FWC].
- Afraid or nervous: **loud blowing (huffing)** and **clacking the teeth (jaw-popping)**, slapping the ground [BO27], [BS], [FWC].
- Calm with other bears: tongue clicks and grunts. A mother sends cubs up a tree with "a single huff" and calls them down with grunts [BS].
- Cubs bawl and moan when upset. Treed or trapped bears **moan**, which people mistake for growls [BS], [FWC].
- Bluff charges "may vocalize loudly" [NPS]. Predatory attacks, feeding and play are **silent** [BS].

What our game does today (`scenes/terrain_client/terrain_client.gd` and `src/client/creature_sounds.gd`):
- Every bear call is the brown bear's growl or roar; the black bear borrows them (`CALL_AS`).
- **Every time a bear starts to flee or to watch, it growls** (states 2 and 3 play "alert" = `bear_growl`). A bear that stares, runs,
  stops and runs again growls each time.
- Warning and charge **roar** (`bear_roar`).
- On top of that, a natural "idle" bear growl plays somewhere in the forest every 7 to 15 minutes by day, whether or not a bear is near.

In our game (recommended):

| Scenario | Sound | How often |
|---|---|---|
| Unaware, eating, sleeping, fleeing, stalking | none (steps, branches breaking under it, splashing) | never a call |
| Notices a player, stands to look | a sniff or a soft snort, heard within about 30 m | once per watch |
| Stressed, first warning (rung 1) | a loud huff (blow), and a ground slap or stomp | once or twice |
| Final warning (rung 2) | jaw-pop, teeth clacking (the black bear has `ClackTeeth` clips) | 2 to 5 clacks |
| Charge | a loud blow or bawl | once |
| Fighting, hurt | a bawl or roar-like bellow (Dave's "growl before attacking" holds through the huff and jaw-pop) | once per hit taken |
| Caught in a trap, treed, cornered | moaning, huffing, jaw-pops | every few seconds while a player is within 30 m |
| Cubs | bawl when separated or hurt | while upset |
| Dying | a low moan | once |
| Natural far calls in the woods | **none for bears** (keep for wolves, birds, deer, fox) | |

A roar is not a black bear sound. Keep `bear_roar` only, if at all, for a brown bear in a real attack.

### Black bear by scenario

| # | What the real black bear does | In our game |
|---|---|---|
| S1 Unaware | Walks slowly, nose down, alone. Mostly silent. | Wander at walk 1.2 to 1.3 m/s; no calls. |
| S2 Eating | Forages berries, nuts, insects, roots, carrion. Reluctant to leave rich food; a bluff charge "when you confront a bear that is trying to get a meal" [NH]. | **Dave 25 Nov 2026: "this world is abundant with berries so that's what they spend most of their time doing is eating and they like to fish so they will go to the streams and rivers."** Most of its day it walks from berry bush to berry bush or to a fishing spot on a stream or river bank, and grazes there (graze clips; `den.berry_share`/`fish_share`, black bear `feeds`). At a carcass or berry patch it holds its ground and warns a player within 20 m instead of fleeing at once. |
| S3 Sleeping | Naps once or twice by day, beds at night in thick cover or at the foot of a big tree [BO27]. | Rest a game hour around midday and through the night, lying (`LyingBreathing`); wakes at 0.6 of its flee distance (rest rule). |
| S4 Notices far | Hears or smells us first. **Stands on its hind legs to see and smell better: curiosity, "not a sign of aggression"** [FWC]. | Within 50 m: stops, sniffs, maybe stands up for a few seconds, then usually walks or runs off. No growl. |
| S5 Comes closer | Usually leaves; a startled one "runs away, often to a tree" [BO254]. | Flee at 32 m (today's table). |
| S6 Fleeing | Fast: 13 m/s and up in a sprint. | **Outruns the player (Dave).** Sprint 12.5 to 13.5 m/s for about 8 s, then a lope of at least 10 m/s (faster than our 9 m/s run) until 150 m away or out of sight, then walks. |
| S7 Chased | Keeps running or climbs a tree. | It gets away. If a player stays within 10 m of it for 5 s, or it is blocked, it counts as cornered (S8). |
| S8 Cornered, trapped | Bluff charges; fights if it must. | **Dave: "a threatened bear should turn and fight back. first it should stand its ground and standup on its hind legs. then it should attack with its claws or mouth."** It turns, stands its ground, rears up on its hind legs (huff), drops and jaw-pops, then attacks with swipes and bites. Every bear, of every temperament. |
| S9 Threatened close (surprise, food, cubs) | Defensive: huff, jaw-pop, slap ground, bluff charge, usually veers off [NPS], [FWC]. | The warning ladder (`bear_threat_design.md`): rear up, huff, jaw-pop, then charge (black bear bluff share 0.75). A player who backs off is let go. One who runs away during the warning gets a real charge. |
| S10 Hurt | No study of wounded bears in these sources. Hunters report wounded bears run hard into thick cover. | **Dave: it fights back.** Hurt with the attacker within 12 m: a short warning, then it attacks. Hurt from farther: it runs (S6) and bleeds; it beds down in cover after about 200 m and stands up and charges a player who follows the trail within 10 m. |
| S11 Dying | Collapses; hunters describe a death moan. | Bleeds out on the trail (blood rule); one low moan; its own death clip (brown bear has them; black bear: `WalkSlowWounded2Lying` then lying). |
| S12 Snared, trapped | Biologists catch bears with baited foot snares (a cable on the foot, anchored) and barrel traps. A caught bear tears up the ground in reach, moans and huffs, lunges at people. | **Dave: "the goal will be to learn how to trap them."** A bear trap (a later trap stage: heavy cable snare or pit, baited with meat, fish or honey). A bear smells bait downwind from about 200 m. Caught, it stays within 2 m of the anchor, faces the player, huffs, jaw-pops, moans, and lunges with a swipe at anyone inside 2.5 m. It can be killed from outside its reach. A weak trap may break after a few game hours. |
| S13 With cubs | Black bear mothers rarely defend cubs by attacking: "defense of cubs is a grizzly bear trait"; a sow "may send her cubs up a tree and false-charge you" [BO27], [NH]. | Cubs follow within 4 m. A mother bluff charges a player within 10 m of a cub; she attacks for real only if the player hurts a cub or stays after the bluff. |
| S14 Hungry, starving | In poor food years bears range farther and come to people's food [FWC]. | **Dave: it runs "unless it was starving or trapped."** **Dave 25 Nov 2026: a bear "will eat berries until it's not starving anymore ... so the only real dangerous time will be early in the spring."** Bears are born starving only in the first month of spring, and a starving bear is fed after three meals at a berry bush or fishing spot. A starving bear does not run from a player: it stands its ground, comes to camps and food left out, takes carcasses, and attacks by the ladder if pushed. It still never enters firelight. |
| S15 Hunting | Mostly a forager; takes fawns and calves in spring; rare predatory attacks on people are silent, by a stalking bear [BS], [BO254]. | Only aggressive-born bears (10% of black bears, 5% of brown bears) stalk a player, silently, at 1.2 m/s; never into firelight; never by night. Takes fawns in spring if animal-on-animal hunting is added. |
| S16 Meets another animal | Yields to brown bears; wolves may harass it; deer avoid it. | Deer, elk and moose treat a bear like a player (flee). A black bear gives way to a brown bear. |
| S17 Group | Solitary. | Single; mothers with 1 to 3 cubs (share 0.3 today). |
| S18 Day and night | Day and dusk; naps by day; mostly beds at night. | Today: day 1.0, dusk 1.0, night 0.05. Keep, add the midday rest. |
| S19 Weather, seasons | Dens up to 7 months in the north; spring hungry; autumn eats heavily (hyperphagia). Heat makes them rest. | Winter: in dens, not out (or very few). Spring: hungrier, bolder (threat x1.5 today). Autumn: busy feeding, warier of people (x0.7 today). Rain: little change. |
| S20 Fire | Avoids people and fire unless food-conditioned. | Fire rule above (no den exception, 25 Nov ruling). |
| S21 Sounds | See the sound table. | See the sound table. |

### Brown bear: what differs

Brown bears (grizzlies) are bigger, defend cubs and food more often, and stand their ground more than black bears; most of their attacks
are defensive, and about 5% predatory (Bombieri et al. 2019). Running from one may trigger a chase (NPS). In our game: health 120, the same
ladder with a lower bluff share (0.6), a mother attacks for real for her cubs, it guards a den by a river (den threat 15 m) and a carcass.
It outruns the player the same way. Same quiet sound rules, but a brown bear in a real attack may roar.

### How hard a bear fight is for a new player

Dave: "as a new person it should have made short work of me." Today a black bear hits for 25 on a charge (brown bear 35, strikes at 0.8 of
that). Recommended: a swipe 30, a bite 40, about one blow every 1.5 s close up, so a fresh 100-health player is down to 1 health in three
or four blows (about 5 s). Then the core rule: at 1 health it stops, and a defensive bear leaves at a walk once the player is down
(a defensive attack ends when the threat ends). A player with a spear who fights well can win; one who runs from it cannot.

### What the bear models have to show it

| Move Dave asked for | Black bear file (136 clips) | Brown bear files |
|---|---|---|
| Stand on hind legs | No clip named for it. `A_StandStraight_*` (9 to 11 s) may be a stand: look at it before use | `IdleHind_Idle_01`, `Idle_to_IdleHind` |
| Huff | `Snorting`, `Calling_1` to `_3` | none named; angry breathing |
| Jaw-pop | `ClackTeeth`, `ClackTeeth_x3`, `ClackTeeth_x5` (unused today) | `Attack_IdleAngry_01_Low` (a low swat) |
| Claw swipe | **none** | `Attack_IdleAngry_01_High`, `_02_High`; `bear_2`: `Attack_MeleeLeft`, `Attack_SwingForward` |
| Bite | **none** | `Attack_Run_01_AttackF`; `bear_2`: `Attack_BiteForward` |
| Hit, death | `A_Hit*2Frighten_F`, `WalkSlowWounded2Lying`; wounded walks and runs | `Hit_*`, `Death_*` |

The black bear model cannot swipe or bite with its own moves. Options for the fix thread: (a) draw black bears with the darker brown bear
look (`bear_2`, which has a bite, two strikes and an angry stand) and keep the black bear file for calm moves only; (b) retarget the
brown bear's attack clips onto the black bear rig if the bones match; (c) a new model. (a) is the quickest and keeps "each model uses its
own attack moves".

---

## Every animal in the game

Taken from `data/animals/animals.json` (52 species rows, 50 animals) and `data/animals/models.json`. Goblins and bandits are people, not animals,
and are left out (`../GOBLINS.md`, `BANDIT_CAMPS.md`). "Today" columns are the live data: health, flee speed and how long it holds it
(`flee_mps` for `burst_s` seconds, then `trot_share` of it), and the temperament shares (P passive, D defensive, N neutral, A aggressive,
F friendly). The player runs 9.0 m/s for about 35 s before strain slows them to 8.1 m/s, and faints at about 50 s
(`exertion.json`).

| Species row | Real species the model is | Where | Health | Flee today | Temperament today |
|---|---|---|---|---|---|
| rabbit | European rabbit (WildMesh Rabbit) | grass, heath, forest edge | 5 | 7.5 m/s 3 s, then 3.8 | runs, burrows |
| deer | white-tailed deer / red deer (WildMesh Deer, 7 looks) | forest, grass, marsh | 20 | 12 m/s 6 s, then 6 | P .8 D .2 |
| elk | wapiti / red deer stag (WildMesh Elk) | forest, grass, alpine | 70 | 13 m/s 8 s, then 5.9 | D .7 N .3 |
| moose | moose (WildMesh Moose) | boreal, mixed, marsh | 90 | 10 m/s 8 s, then 4.5 | D .7 N .3 |
| wolf | grey wolf (WildMesh Wolf_1) | packs, own brain (`server_wolves.gd`) | 30 | pack decides | pack |
| fox | red fox (WildMesh Fox_1) | forest, grass, heath | 12 | 11 m/s 6 s, then 6 | P .8 N .15 F .05 |
| boar | wild boar (WildMesh WildBoar) | forest, grass, marsh | 40 | 8 m/s 6 s, then 4 | P .3 D .65 A .05 |
| lynx | Eurasian lynx (WildMesh Lynx) | boreal, mixed | 30 | 12 m/s 6 s, then 6.6 | P .9 N .1 |
| bear, black_bear | brown bear, American black bear | forest | 120, 90 | 9 m/s 6 s, then 4.5 | see Bears |
| puma | cougar (WildMesh Puma) | mountains, forest | 60 | 13 m/s 6 s, then 7.2 | P .6 D .3 A .1, hunter |
| tiger, leopard | tiger, leopard | forest, marsh; savanna | 120, 55 | 13 m/s 6 s, then 7.2 | P .4 D .4 A .2; P .6 D .3 A .1 |
| lion, hyena | lion (two looks), spotted hyena | savanna, grassland | 110, 45 | 12 and 11 m/s 6 s | P .3 D .5 A .2; P .5 D .4 A .1 |
| beaver | North American beaver | water in forest, marsh | 14 | 4 m/s (swims) | runs to water |
| mink | American mink | marsh, banks | 6 | 5.2 m/s | P .85 D .15 |
| raccoon | raccoon | forest, marsh | 10 | 7 m/s | P .6 N .25 F .15 |
| rat | brown rat | marsh, forest, beach | 2 | 3 m/s | runs |
| bighorn, mountain_goat, chamois | bighorn sheep, mountain goat, chamois | alpine, rock | 30, 28, 22 | 11, 9, 12 m/s | P .8 D .2 |
| pronghorn, wildebeest, kangaroo | pronghorn, blue wildebeest, eastern grey kangaroo | open plains | 22, 60, 40 | 16, 13, 12 m/s 6 s | P .8 D .2 |
| horse, donkey, camel | feral horse, donkey, dromedary | grass, heath, savanna | 60, 45, 70 | 13.7, 11, 9 m/s 8 s | defensive, tame value |
| buffalo ("Wild ox") | Cape buffalo look, wild cattle | grass, savanna | 110 | 10 m/s 8 s | D .6 N .2 A .2 |
| cow, goat, chicken, cat, dog | farm and stray animals | near people (target_per_player 0) | 80, 25, 3, 6, 25 | | stock |
| warthog, honey_badger | warthog, honey badger | savanna | 35, 25 | 8, 7 m/s | P .2 D .75 A .05; D .6 N .4 |
| rhino, elephant, mammoth | rhinoceros, African elephant, woolly mammoth | savanna; tundra (mammoth) | 160, 300, 300 | 10, 6, 6 m/s 8 s | mostly defensive |
| alligator | American alligator | marsh, forest water | 110 | 4 m/s, swims | P .4 D .5 A .1 |
| songbirds, crow, pheasant, grouse, guineafowl | small birds, crow, ring-necked pheasant, grouse, helmeted guineafowl | ground birds, flush or perch | 1 to 6 | fly | flocks |
| duck, goose, seabird | mallard flock, goose, gull | water, shore | 3 to 10 | fly, swim | flocks |
| frog, seal | frog, harbour seal | water's edge | 1, 20 | jumps or slides into water | runs to water |

### The rules that hold for every species (from the research)

1. **Prey sprints first, then keeps going faster than a person.** Deer reach 15.6 m/s, elk 18 to 20, moose 15.6, wolves 15.6, foxes 13.4,
   pronghorn 24 (18 for several km, 12.5 for 10 km), horses 15 to 19. A healthy animal is never run down on foot. Our player runs 9 m/s for about 35 s,
   and every species drops to half speed or less after a 3 to 8 s burst, so in our game **every animal can be run down** well inside that. That is the biggest single gap (gap 1).
2. **Stare, then signal, then go.** Most prey first lifts its head and looks, then gives its alarm (deer snort, stamp and flag the tail;
   elk cow barks; rabbits thump; chamois whistle; geese honk; crows caw; guineafowl chatter), then runs to cover. Our "stare before
   fleeing" ruling fits.
3. **Most animals are silent when they run.** The calls belong to the alarm, the warning, the fight and the hurt, not to the flight.
4. **Hurt animals that are left alone lie down soon.** A deer hit through the lungs sprints off and lies down and dies after a short run;
   pushing it makes it run hundreds of metres more (TPWD). This is how a blood trail ends in a body.
5. **Defence is a ladder.** Big animals warn before they hit: moose ears back, hackles up, lip licking; elk teeth grinding; boar
   snorting and mock charging; bears huffing and jaw-popping; kangaroos standing tall; cats hissing. Most charges are bluffs.
6. **Mothers matter most.** The worst danger from deer, elk, moose, boar, cattle, geese and most big game is a mother with young. Young
   of hiders (deer, elk, pronghorn, hares) lie still alone; young of followers (moose, horse, wildebeest) run with the mother.
7. **Predators hunt from cover and give up quickly.** Cats stalk to 5 to 20 m and rush under 100 to 200 m; lynx ambush by trails; wolves
   test and chase over hundreds of metres to a few kilometres; a lone wolf kills an adult elk only 2% of the time (NPS). Running from a
   predator can start a chase (Panthera, NPS).
8. **Wind and smell.** For deer, wolves, bears, boar, elephants and rhinos smell is the best sense; walking downwind of them is how
   hunters get close. Wolves in Sweden fled earlier when the wind carried human scent to them (Frontiers 2022).
9. **Fire.** Wild animals flee fire and smoke. Bears, raccoons, gulls, crows, hyenas and stray dogs come to camps for food. No agency
   advises a campfire as a deterrent. Dave's rule wins (see "Fire"): they circle the edge of the light and wait.

### Rabbit (European rabbit; cottontail notes)

Numbers: cottontail top speed 8 m/s in zig-zag bounds; groups of 2 to 20 at a warren; home range 2 to 3 ha; active dusk to dawn, rests by
day in a form or burrow; feeding peaks 2 to 3 h after dawn and in the hour after sunset; strong wind, heavy rain and a full moon cut
activity (Wildlife Online, ADW).
- S1 to S3: grazes near cover, hops; rests in the burrow or a form by day. In game: as today (warrens, runs, out 18:00 to 08:00).
- S4 to S6: freezes, slinks low, then a zig-zag dash to the burrow, white tail showing; may sit up to look. A hind-foot **thump** warns
  the others. In game: freeze and stare (startle), thump (sound), then zig-zag to the burrow. Already close.
- S7, S8: goes to ground. Cornered or caught: kicks, struggles, gives a loud **distress scream** (ADW).
- S10, S11: a wounded rabbit dives into its burrow on its trail (the server's burrow on the trail; the client's `BURROW_KINDS` only stops a rabbit that goes to ground being drawn as killed). Dies with a squeal.
- S12 snare: struggles and screams, then goes still. Dave 25 Nov: it lies in the snare, E collects it and resets the snare.
- S13: the doe visits the nest once a day for a few minutes; young stay hidden. No defence.
- S15 to S17: prey of fox, lynx, wolves, birds of prey; groups feed together and one thump sends all.
- S19: less out in wind, rain and bright moon (today: small animals cut by wind; add moon if the moon is modelled).
- S20: a fire, building, placed torch or tilled bed within 20 m empties the warren (ruling).
- S21 sounds: thump when alarmed (once or twice), scream when caught or hurt, otherwise silent. Today: `rabbit_thump` idle and alert,
  `rabbit_squeak` threat; fine, but no idle thump with nobody near (a natural thump means danger).

### Deer (white-tailed deer, red deer notes)

Numbers: top 15.6 m/s, jumps 2.4 m (Indiana DNR, Maryland DNR); red deer stag clocked at 19 m/s. Flight from a car: median 69 m (PLoS ONE
2014); no good figure on foot (our flee 35 m, notice 60 m are fine). Home range about 2.6 km². Does and fawns together, bucks alone or in
bachelor bands; red deer hinds about 5 to 7 in a group. Active dawn and dusk, beds by day.
- S1 to S3: browse and graze, bed in cover by day chewing the cud (today: lying by share, ANIMAL_RESTING).
- S4: head up, ears forward, stare; a **head-bob and foot stamp**; a **snort**, which carries far (MDC). In game: stare, stamp, snort.
- S5, S6: bounds off with the white tail flagged (white-tailed) or a bark (red deer). In game: as today plus the tail flag if the model
  allows, and sprint 13 to 15 m/s then **lope at least 10 m/s** to 70 m.
- S7: keeps running, uses cover and jumps; a pushed deer leaves the area. Being chased in winter costs it fat (Idaho F&G).
- S8: a cornered or caught deer strikes with the front hooves; a buck in rut may use antlers. In game: deer are passive or defensive;
  a cornered one strikes (needs a strike move: the deer file has none named, gap 4).
- S9: surprised close it bolts; a rutting buck may stand.
- S10: hit through heart or lungs: jumps or kicks, sprints the way it faced, then lies down and dies after a short run; followed too soon
  it runs hundreds of metres (TPWD). In game: a wounded deer runs, then **beds down within 100 to 200 m** if not followed, and bleeds out
  there; one pushed within 30 m gets up and runs again.
- S11: falls, kicks; may bleat or groan.
- S12: fights the trap and can die of stress (capture myopathy). Deer are never snared in our game today (traps.json); keep it.
- S13: fawns lie hidden alone for about 3 weeks; the doe visits 2 to 3 times a day; a fawn freezes, heart rate down to a third. In game:
  a found fawn lies still; the doe stamps and snorts nearby; a doe charges only a player who touches the fawn.
- S14: late winter: weak, slow, stays in sheltered yards.
- S16: flees wolves, bears, cougars, lynx, dogs as it flees players.
- S17: herd 3 to 6 (today), one watches; the first to bolt alarms the rest (today).
- S18: dawn and dusk most, some night (today day 0.4, dusk 1, night 0.5).
- S19: rut October to mid-December: bucks move more, grunt, fight (snort-wheeze); deer move more on windy days, less on windy nights
  (Penn State). Snow: yards up.
- S21 sounds: snort (alarm, once), stamp, bleat (fawn, hurt), grunt (rut, doe to fawn). Never a call while fleeing.

### Elk (wapiti)

Numbers: herds up to a few hundred (cows, calves, young bulls); old bulls apart until autumn; feed morning and evening, rest at midday;
NPS asks people to stay 30 m away; top speed about 18 to 20 m/s (widely quoted, not checked). Wolves' main prey (85% of winter kills,
Yellowstone).
- S4, S5: head up, ears turning, stiff walk; a cow **barks** to warn the herd; the herd moves off together.
- S9, S13: cows with calves (late spring) and bulls in rut (August to early winter) kick or chase people; teeth grinding and pinned ears
  are the warning; an elk that walks toward you is dangerous (NPS Grand Canyon).
- S10: as deer.
- S13: calves are hidden alone in tall grass for about 2 weeks, then join the herd.
- S19: rut September to mid-October; bulls **bugle** (rising squeal, then grunts) at dawn and dusk and through the night in the rut;
  winter moves downhill.
- S21: cow bark (alarm), bugle (rut only, often), calf mew; no call when fleeing. Today: elk borrows the moose's snort and bellow.
- In game: flee as deer (faster lope); cows with calves and rutting bulls warn and charge (today defensive 0.7 does this).

### Moose

Numbers: gallops to 15.6 m/s in short runs; swims up to 19 km; poor sight, keen hearing and smell; feeds dawn and dusk; mostly alone,
cow and calf pairs, winter groups up to 12 to 15; cannot bear long heat over 24 °C (SUNY ESF, Michigan DNR).
- S4, S5: often stands and watches instead of running; walks off if pushed.
- S9: warning signs: **ears laid back, hump hair raised, lip licking**, walking toward you (ADF&G). Most charges are bluffs. A real one:
  kicks with the front hooves and may stomp a downed person until they lie still. "It won't chase you very far." (ADF&G)
- S13: cows are very protective in late spring and summer; calves follow (they do not hide).
- S14: worse-tempered hungry and tired in deep snow in late winter (ADF&G).
- S16: treats dogs as wolves and kicks them.
- S19: rut September to November (bulls grunt and bellow, cows moan); in heat it stands in water and shade.
- S21: grunt (rut), cow moan, calf bawl; silent otherwise.
- In game: today D .7 N .3 with a ladder: fits. Its charge already stops at 24 m (`charge_m`), which fits "it won't chase you very far". Add: a moose that has put a
  player down to 1 health stands over them a few seconds and then walks off. In summer heat it stands in water.

### Wolf

Numbers: trots 2.2 m/s for hours, top 15.6 m/s; up to 72 km a day; packs average 9.8 (Yellowstone), lone wolves 2 to 5%; smell best,
excellent night sight; a lone wolf kills an adult elk 2% of the time, success rises with pack size to about 4; howls carry 11 km in
forest, 16 km in the open; about four times more howling in February than in May (NPS).
- S4, S5 (people): in Sweden 18 of 21 GPS wolves fled walkers, mostly before the walkers came closest, moved a median 1.5 km, and stayed
  away about 75 minutes (Frontiers 2022). In game: a pack that is not hunting slips away from a player it notices.
- S15: tests a herd, picks the weak, chases over hundreds of metres to kilometres.
- S13: pups born mid-April in a den; the pack defends the den.
- S17: today's pack brain (`server_wolves.gd`, wolf pups design) covers stalk, rush, den guard.
- S20: no study shows a campfire deters wolves; Dave's rule wins: no pack enters firelight (today the den guard rushes "torch or not":
  gap 7).
- S21: howl (night, more in winter; replies at kills and pup sites), growl and snarl at a fight, bark-howl alarm near the den, silent
  while hunting.

### Red fox

Numbers: top 13.4 m/s; mostly dawn, dusk and night; home range 13 to 26 km²; kits 4 to 5, out of the den at 4 to 5 weeks; about 12 calls;
mouse-pounce in a high arc (CPW, MDC).
- S2, S15: mouses: stands still, listens, leaps high onto prey under grass or snow.
- S4 to S6: cautious, watches, slips away; town foxes bolder. In game: today P .8 N .15 F .05 fits.
- S8: cornered or caught: gapes, screams, bites.
- S12: snare: struggles, then lies low (trap studies: smaller, nimble species hurt themselves more).
- S13: moves kits if the den is disturbed.
- S19: winter breeding: the **scream** (mid to late winter nights), barks and yips near kits.
- S21: bark (night, often), scream (winter), silent while hunting or fleeing. Today fine.

### Wild boar

Numbers: forages about 1 km/h, trots 6 to 10 km/h, flees to 11 m/s; smell best, poor sight; mostly nocturnal, starts about an hour
before sunset, rests up to 12 h by day in thick cover; sounders up to 6 sows plus litters (to 30); adult males alone (Wildlife Online,
Forestry England, eXtension).
- S4: hears or smells people first and often **walks toward the noise to look**, which looks like aggression (Forestry England); old
  males stand and watch.
- S9, S13: a sow puts herself between people and piglets, snorting, while others lead the young away; she may mock charge if people keep
  coming.
- S8, S10: wounded or cornered boars charge with tusks.
- S19: wallows in heat (no sweat glands); more active on humid nights.
- S21: alarm bark (loud, once), grunts while feeding, squeals in fights, piglets whine; males rarely call. Today the boar borrows the
  moose's snort and bellow: it needs its own bark, grunt and squeal.
- In game: today fits (P .3 D .65 A .05, night active). Flee 8 m/s is under the real 11: raise to 11 with a lope over 9.

### Lynx (Eurasian; Canada lynx notes)

Numbers: ambush hunter, mostly walks, short rushes of tens of metres; mainly nocturnal (more by day in March to April mating); one roe
deer a week, feeds on a kill 3 days and stays near it; "lynx are no threat to humans" (KORA); Canada lynx eat 1 to 2 hares a day.
- S4 to S6: very shy, usually gone before seen. Today P .9 N .1: fits.
- S8, S12: cornered: hisses, swipes. Trapped cats tend to sit rather than fight the trap.
- S15: lies by small game trails and pounces (our rabbit runs are the place).
- S16: climbs trees to escape wolves.
- S21: silent hunting; mating calls in spring; hiss and growl when cornered. Today the lynx borrows the bear's growl and roar: a lynx
  needs a hiss, a growl and a spring call (its file has `idle_call_01`, `_02`).

### Cougar (puma)

Numbers: dusk to dawn, also by day; stalks, then a short rush from behind; one deer-sized kill every 6 to 12 days, cached under leaves and
revisited; solitary; bounds 12 m; cannot roar: growls, hisses, chirps and the mating scream (CPW, CDFW, Arizona Extension). Attacks on
people are rare; running can start a chase; most people who fight back drive it off.
- In game: today P .6 D .3 A .1 with stalking: fits. Add: it guards a cached kill (S9); silent stalking; a hiss and growl warning;
  **never a roar** (today it borrows the bear roar); a scream at night in its mating season.

### Beaver, mink, raccoon, rat

- **Beaver:** nocturnal, out in the evening; colonies of 2 to 12; startled, it **slaps its tail** on the water and dives (stays under 6 to
  8 min); slow on land, lives by water and lodge (Maine IF&W, Smithsonian). Cornered on land: hisses and bites. In game: run to water,
  tail slap sound, dive (today runs to water: add the slap).
- **Mink:** nocturnal, alone, checks every hole along banks; musk when threatened. Cornered: hisses, screeches, bites. In game: as today.
- **Raccoon:** top 4.5 to 6.7 m/s, short; escapes up the nearest tree; nocturnal; raids camps and food; threat: lowered head, bared teeth,
  arched back, hisses, growls. In game: at night it comes to food left out but stops at the firelight edge; cornered it hisses and
  bites (today P .6 N .25 F .15; the friendly share should only mean "bold near camps", not walking up to players).
- **Rat:** dusk and night, rarely more than 120 m from its burrow; shy of new things and traps for days; squeaks when caught. In game: as
  today.

### Birds

- **Songbirds:** flush at 5 to 20 m from a walking person; dawn chorus, silent at night; a thin "seet" for a hawk overhead, harsh chips
  to mob a cat or owl. In game: as today (flocks, perch).
- **Crow:** flush 15 to 50 m; recognise faces; loud repeated cawing is the alarm and mobbing call, which draws other crows; scavenges
  carcasses and camps after people leave. In game: crows come to a carcass once the player is 30 m off; caw at a predator.
- **Pheasant:** runs into cover first, bursts up at 2 to 10 m with a whirr and a "kuk-kuk-kuk"; cocks crow at dawn in spring.
- **Grouse:** sits tight, explodes up at 3 to 10 m and puts trees between; ruffed grouse drum at dawn in spring (heard 400 m); a hen with
  chicks does a broken-wing act or rushes at intruders.
- **Duck (mallard):** flush 20 to 100 m, take off straight up from water; only hens quack (alarm on take-off); hens do the broken-wing act
  for ducklings; flightless 3 to 4 weeks in late summer.
- **Goose:** pairs for life; at the nest the gander hisses, spreads wings, runs or flies at a person and hits with wings and bill;
  honks in flight and on alarm. In game: a nesting goose charges and pecks lightly (small damage), never follows far.
- **Gull:** bold scavenger at shores and camps; dive-bombs near nests with a "kek-kek" alarm.
- **Guineafowl:** runs rather than flies; loud "kek-kek-kaaa" alarm at the first sign of anything, which other animals heed (a sentinel:
  today's alarm group fits).
- **Chicken:** "eeee" for a hawk (crouch), loud cackle for a ground predator; roosts at dusk.

### Water's edge: frog, seal, alligator

- **Frog:** jumps into water at 1 to 3 m (bullfrogs farther); calls on warm wet nights (bullfrog "jug-o-rum" heard 1.6 km); hibernates
  in mud. In game: as today; calls at night near water in summer.
- **Seal:** raises its head, then humps to the water and goes in; slow and clumsy on land; flushes from walkers at shorter range than from
  ships (ships at 100 m flush almost all); bites if cornered on land. In game: flee to water (today); cornered on land it bites.
- **Alligator:** short land bursts of 4 to 5 m/s over a few metres only; ambush at the water's edge at dusk and night; usually slides into
  the water away from people; close up opens its mouth and **hisses**, then lunges or snaps; females guard nests June to September;
  dormant below 13 °C (FWC, UF/IFAS). In game: never chases on land beyond a few metres; hiss before a lunge; inactive in cold weather.

### Mountain animals: bighorn, mountain goat, chamois

- **Bighorn:** 14 to 15 m/s on flat ground; spots movement far off; ewes and lambs in groups of 10 or more; flees up to cliffs; rams clash
  heads in the rut (November to December), heard over 1 km. In game: flee uphill to rock, not away on the flat.
- **Mountain goat:** not fast (about 8 m/s bursts); escapes by climbing to ledges; salt-seeking goats follow hikers; rutting males gore
  (one fatal case, Olympic NP 2010); NPS: stay 45 m away. In game: walks off uphill; in the November rut a billy may follow and butt a
  player who stays near.
- **Chamois:** notices people at about 400 m in the open, alert at 176 m, flees at a mean 124 m (15 to 367) from hikers; most just walk off
  a few metres and 73% reacted only when people left the trail; dogs cause flights over 500 m; alarm: a sharp whistle-snort and foot
  stamp (Mutton 2019). In game: notice 50 m and flee 40 m today are much shorter than real; fine for play, but a whistle alarm and an
  uphill flight are missing.

### Open plains: pronghorn, wildebeest, kangaroo, horse, donkey, camel, wild ox

- **Pronghorn:** top 24 m/s, holds 18 m/s for several km and 12.5 m/s for over 10 km; sees movement at about 5 km; flees at 100 to 400 m; flashes its white rump to warn
  the herd; fawns hide 3 weeks. In game: the fastest thing in the world; never caught by running.
- **Wildebeest:** to 22 m/s; herds 10 to 1,000; stops, stares, snorts, then bolts and wheels; constant "gnu" grunts; calves run with the
  herd minutes after birth.
- **Kangaroo:** hops 14 to 17 m/s, cruises 6 to 7 m/s for long; dawn and dusk; mobs of 2 to 10; thumps a foot in alarm; warns by standing
  tall, chest-rubbing, growling; a big male grabs and kicks; heads for water when chased (Queensland Gov.).
- **Horse (feral):** gallops 15 to 19 m/s; family bands of 3 to 20; head up, snort, band bunches and runs with the lead mare in front;
  cornered: rears, strikes, kicks; whinny carries about 1 km. In game: today the horse is tame-able and curious; it should still run as
  a band when startled.
- **Donkey:** freezes and looks rather than bolting; hostile to dogs and wolves (kicks, bites, chases); bray carries about 3 km at dawn
  and dusk.
- **Camel:** sprints to 18 m/s; rutting bulls dangerous (gurgle, push out the pink dulla, bite); groans when disturbed.
- **Wild ox (buffalo row):** herds 50 to 500; stares, then moves off; lone bulls and wounded ones circle back and ambush hunters; a calf's
  bawl brings the herd. In game: wounded ones ambush from cover (S10), the herd answers a calf.

### Big game: lion, leopard, tiger, hyena, honey badger, warthog, rhino, elephant, mammoth

- **Lion:** charges 14 to 17 m/s but tires after 100 to 200 m, so it stalks first; rests 18 to 20 h a day; hunts at night and dawn, about
  25% success; prides of 3 to 30; roars at night heard 8 km; usually avoids people on foot; a growling mock charge stops at a few metres
  if the person stands. In game: charge limited to about 150 m; roars at night far off (not near the player as a warning: near it
  growls).
- **Leopard:** stalks to 5 to 10 m then pounces; nocturnal; hoists kills into trees; avoids people and is rarely seen; wounded or cornered
  ones are very dangerous; call is a rasping "sawing" of 10 to 15 strokes. In game: rarely seen; guards a kill in a tree.
- **Tiger:** stalks to 10 to 20 m, rushes under 100 m; nocturnal; 10 to 20 km a night; man-eaters attack from behind; prusten "chuff"
  greeting. In game: as today's hunter; attacks from behind only.
- **Hyena:** travels 2.8 m/s, chases at 14 m/s over 1 to 3 km; nocturnal; clans of 8 to 80; whoops heard 5 km; bold around camps at
  night; mobs lions at kills. In game: night only, comes to the edge of firelight and waits; whoops at night.
- **Honey badger:** solitary, digs; usually ignores people; threatened, it turns and charges with a rattling growl, bites, musks. In
  game: today D .6 N .4 fits; it never runs far.
- **Warthog:** 14 m/s, tail straight up; strictly by day; sleeps in burrows, backs in tusks out; flees at 50 to 100 m; mothers charge
  jackals. In game: by day only (today day 1, night 0.05: fits); bolts to a burrow.
- **Rhino:** poor sight (a still person past 30 m barely seen), superb smell and hearing; black rhino charges at sounds and smells then
  veers; white rhino usually runs. In game: walking upwind gets you close; a charge that misses runs on past.
- **Elephant:** 7 to 11 m/s; smell best, senses people at kilometres; rumbles heard 2 to 10 km; mock charge with ears out, head shaking,
  dust; real charge silent, ears pinned, head down; families bunch around calves; musth bulls aggressive for weeks. In game: today's
  ladder; a real charge is silent.
- **Mammoth:** as the elephant (no direct evidence); herds led by a matriarch; young males alone.

### Farm and strays: cow, goat, chicken, cat, dog

- **Cow:** tame cattle have no flight zone; range cattle have a big one; cows with new calves charge people and dogs; bulls paw and stand
  side-on before a charge; calm down 20 to 30 minutes after a scare (Grandin).
- **Goat:** sneeze-snort and stamp in alarm, the herd runs uphill; kids lie out while the mother browses; hates rain.
- **Chicken:** see Birds.
- **Cat (feral):** flees to cover at 10 to 30 m; cornered: arched back, hiss, spit, growl, then claws.
- **Dog (stray):** keeps 10 to 50 m off; barks; may bite from behind if a person runs (today's stray-dog taming fits).

---

## Gap list (biggest first, one fix each)

Each item: what is wrong today, what to do, where. Values are recommendations for the fix thread to tune; Dave plays and rules.

1. **Every animal can be run down on foot.** The player runs 9 m/s for about 35 s before strain cuts the pace to 8.1 m/s (faint at about
   50 s, `exertion.json`); every species falls far below that after its burst
   (`flee_mps` for `burst_s`, then `trot_share`): deer 12 then 6 m/s, elk 13 then 5.9, horse 13.7 then 6.9, pronghorn 16 then 8, bears
   9 then 4.5. Real deer, elk, moose, wolves, horses and bears all hold well over 9 m/s for a long way. Fix: for every large runner
   (deer, elk, moose, bears, wolves when fleeing, fox, horse, donkey, camel, pronghorn, wildebeest, kangaroo, big cats, boar, buffalo)
   a lope after the burst of at least 10 m/s (pronghorn 18) held until `safe_m`, then a walk; small animals go to burrow, water, tree or
   cover instead. A hurt animal runs slower (below). The other way, a shorter player sprint in `exertion.json`, is a call for Dave.
   `data/animals/animals.json` (new `lope_mps` or raise `trot_share`), `server_animals.gd` flee speed (line about 1723),
   `animal_gait.gd` RATE_MAX for the legs.
2. **Half the black bears never fight back** (passive 0.5). Bear item 1 above. `animals.json` black_bear temperament.
3. **Cornered or run-down animals that are "passive" never defend themselves.** Passive means `threat_x 0` and `attacks false` for the
   80% passive deer, bighorn, chamois, goats, pronghorn, wildebeest, kangaroo and 90% of lynx. Real cornered deer strike, cornered
   kangaroos kick, cornered cats claw. Fix: keep "passive" as "never starts a fight", but let a cornered or grabbed animal of any
   temperament strike once and break away (a small hit, then flight). `server_animals.gd` `_at_bay`, `server_big_game.provoke`.
   Built 25 Nov 2026 for the cornered case (`server_big_game.break_away`: a close strike or kick at 0.3 of its damage on a player
   within reach, then flight and its cool-down; never at a player in firelight; kinds that may fight still warn). The grabbed case
   waits until there is a way to grab an animal.
4. **Animals call when they flee or look up, and borrow other species' voices.** The client voices every flee (state 2) and alert
   (state 3) (`terrain_client.gd` `state_changed` hook), so a bear growls, a lion roars and a boar snorts like a moose each time it looks
   or runs; bears and big cats roar as their warning. Real: flight is silent; the alarm call is species-own (deer snort, elk bark,
   rabbit thump, beaver tail slap, chamois whistle, fox bark); cats and black bears do not roar. Fix: no call on flee; one alarm call on
   the first alert only for species that have one; warnings by species (huff and jaw-pop for bears, hiss and growl for cats, snort and
   stamp for deer and boar, lip-lick silent for moose); recordings needed for bear huff, jaw-pop, bawl and moan, boar bark and grunt,
   cat hiss and growl, elk bark and bugle, beaver slap. `creature_sounds.gd` KINDS and CALL_AS; Dave listens.
   Built 25 Nov 2026 with the voices we have (`creature_sounds.mood_for`, `animal_view` first look): every flight silent; a look-up
   calls only for deer, rabbit, fox, horse, duck and wolf, once per animal; borrowed voices look up in silence; bears, cats, boar and
   warthog warn with the low growl or snort; black bear, lynx and puma never roar. The recordings above are still needed.
5. **Natural far bear calls.** A bear growl plays in the forest every 7 to 15 minutes by day whatever is near. Fix: remove the bear's
   natural calls (the only big animal with them; cats borrow bear voices only for warnings) (keep wolf howls at night, more in winter; fox barks and screams at night, winter; frogs on warm nights; rut bugles and
   bellows in autumn; birds by day). `creature_sounds.gd` KINDS bear `every`.
6. **Animals that fight have no attack move of their own.** No bite, strike or kick clip is mapped for black bear, deer, moose, elk,
   lynx, mountain goat, horse, buffalo, warthog, hyena, wildebeest, alligator, honey badger, chamois, mink, raccoon, cow, cat, dog,
   pronghorn or camel (`models.json` clips `bite`, `strike`, `kick`). Several files have threat clips that are unused
   (`GrazingOnSpotA2IdleThreat` for moose, hyena and honey badger, `IdleThreat` for the fox; the buffalo already warns with it and the
   warthog's was turned down on purpose, it drops onto its haunches; `ClackTeeth` for the black bear; hyena `Howling_*`).
   Fix: map what each file has; for files with none, choose with the coordinator (borrow a look with moves, retarget, or a new model).
   The black bear first (bear item 4).
7. **Fire exceptions are removed** (Dave 25 Nov 2026 "fire keeps everything away from the players", newer than the bear den ruling
   of 6 Nov 2026 and the wolf pup den and bear ladder rulings of 8 Nov 2026, under his 23 Nov rule "newer rules override older ideas").
   Today the bear den ignores fire and torches (`_in_den`); a mother with a player near her young attacks "torch or not"; a wolf pack at
   its pups' den rushes "torch or not" (`wolf_packs_and_pups_design.md`); a charge already started is locked and may pass into new
   light. Fix: remove them; hold at the light's edge; a charge turns off at the edge. (The bear fix thread has this in hand.)
8. **A hurt animal does not slow down or bed in cover, and bleeds at one rate.** Every wound drains 0.15 health a second whatever the
   animal (a deer of 20 dies in about 2 minutes, an elephant of 300 in 33), and it flees at full speed (`bleed` says it "runs, rests and finally dies"; check how it rests). Real: a badly hit
   deer runs a short way and lies down; pushed, it runs much farther. Fix: a hurt animal runs slower (the wounded gait clips most files
   have: `RunFastWounded_F`, `WalkSlowWounded_F`), beds down in cover 100 to 200 m on if not followed, and is pushed on by a player who
   comes within its flee distance; bleed scaled by the hit (and by size) so a good hit ends within one blood trail. `server_animals.gd`
   `bleed`, `blood`; `animals.json` blood.
   Built 25 Nov 2026 on the server (`server_animals._runs_on_hurt`, `bleed`; `animals.json` blood bleed_s, bleed_max_s,
   wounded_speed_x, bed_m, bed_s): each wound bleeds its own damage over 60 s (never slower than its whole health over 15 minutes); hurt, its
   lope is 0.7 as fast; left alone it runs on 100 m, up to 200 m looking for trees, lies up (drawn lying) 5 to 10 minutes, and a player
   within its flee distance pushes it on. Not yet: the wounded gait clips on the client (the row does not say an animal is hurt).
9. **An animal that has beaten a player to 1 health has no ending** (check). The core rule stops damage, but nothing seen in the code tells the animal it won.
   Fix: a defensive animal (bear, moose, elk, boar, cattle) stops, watches for a few seconds and walks off; a hunting predator leaves
   too (the game never lets it eat the player).
10. **No starving state.** Only the season scales boldness (spring threat x1.5 for bears). Fix: a hunger flag for bears and predators
    (late winter, spring after the den, a poor year) that makes them stand their ground, come to camps, food and carcasses, and bolder
    with prey, never into firelight (bear item 6).
    Built 25 Nov 2026 (`animals.json` hunger rows and block; `server_animals` spawn, `may_attack`, `_threat_m`, `thief_row`): bears,
    black bears and the big cats and hyena are born starving at a season chance (bears: 40% in the first 30 days of spring only, after Dave's 25 Nov ruling below). A starving one
    stands its ground and warns by the ladder at 1.5 times its threat range, whatever its temperament, and comes for food left out
    unless a player is within 6 m of it (a mother with young is never born starving). Like any animal that may fight it chases a
    player who runs from it close by (hunter chase_m). Neither it nor a fox ever goes for food in, or creeps through, a fire's or a
    torch's light, and any warning, charge or blow ends when its foe is in such a light or it has come into one (`server_big_game.step`). Not yet: carcasses,
    bolder with prey, a poor food year.
    Bears feed (Dave 25 Nov 2026: a bear "will eat berries until it's not starving anymore and this world is abundant with berries so
    that's what they spend most of their time doing is eating and they like to fish so they will go to the streams and rivers so they
    will eat fish also so the only real dangerous time will be early in the spring"): a bear's hunger row is spring only, on days 0 to
    30 of its row's year (`hunger.days`; `server_animals._born_starving`). Brown bears go fishing half the time and to a berry bush
    (outside every fire's light) 80% of the rest; black bears, which have no den, feed the same way round their home (`feeds` row:
    fishing 30%, berries 80% of the rest). A starving bear that finishes a graze at its bush or fishing spot has had a meal, and after
    `hunger.meals` (3) it is starving no more (`_ate`). Cornered, trapped and run down are unchanged. The big cats keep their rows.
11. **Cornered by a chase is not a thing.** Today "cornered" means blocked by water or a cliff (`_at_bay`). Fix: a player who keeps
    within about 10 m of a fleeing animal for 5 s has cornered it: big animals turn and fight (Dave, for bears), small ones dive for
    cover.
    Built 25 Nov 2026 (`server_animals._run_down`, `animals.json` run_down): a big animal (one with a defend row) chased within 10 m
    for 5 s turns: a bear or one that may fight warns, then fights; one that will not strikes once if the player is on it, else runs on.
    Never at a torch bearer. Small animals keep going to burrow, water or cover as before.
12. **Mothers with young need species rules.** Today one rule: a player between a mother and young within `between_m` is attacked at
    once. Real: black bear and deer mothers mostly bluff; moose, elk, boar, cattle and brown bears really attack; hiders' young lie
    still alone, followers' young run with her. Fix: per species `young` rows for bluff or real, hide or follow.
    Built 25 Nov 2026 (`animals.json` young.bluff_share, young.hides): deer and black bear mothers bluff 8 charges in 10 for their
    young, pronghorn 6 in 10; the rest press home. Deer, elk and pronghorn young drop and lie still while the mother runs or warns,
    then go back to her; the rest run at her side.
13. **Predators guarding kills.** Cougars cache and revisit kills, leopards hoist them, lynx feed on one for 3 days, bears guard
    carcasses. Not modelled. Fix: once animals kill prey, a predator stays by its kill and warns a player who comes within 20 m.
14. **Bears and big animals have no trap.** Snares catch rabbits and foxes only (traps.json). Dave wants bears trapped. Fix: trap stage 3
    (heavy snare, pit, deadfall), baited; a caught animal stays tethered and fights at the end of its reach.
15. **Hours and rest.** Bears, lions and cats nap through the middle of the day; elk, bighorn and chamois rest on ledges or in shade at
    midday; boar rest up to 12 h by day. Today resting covers grazers by share (`ANIMAL_RESTING.md`). Fix: midday rest rows for the
    rest, lying clips where the file has them.
    Built 25 Nov 2026 (`active` midday values, `rest.midday_hours` 11 to 15, `server_animals._active_value`): bears and the cats nap
    (they rest), elk lie up, bighorn, chamois, mountain goat and warthog are mostly bedded at midday. Boar already rest all day.
16. **Seasons missing.** Rut calls and rut aggression (deer October to December, elk September to October, moose September to November,
    bighorn November to December, mountain goat November), bear dens in winter, fox screams in winter, frogs in spring and summer nights.
    Today 16 species have season rows for threat and spook only. Fix: add the calls and the winter bear den.
17. **Flight distances for mountain animals are short.** Chamois flee real hikers at a mean 124 m and notice them at 400 m (Mutton 2019);
    pronghorn at 100 to 400 m. Today 40 m and 45 m. Fix: raise for chamois, bighorn and pronghorn on open ground, flee uphill for the
    mountain three.
18. **Scavengers at camps.** Raccoons, crows, gulls, hyenas and stray dogs come to food and carcasses. Today only thieves (fox, raccoon,
    honey badger) steal. Fix: crows to carcasses once the player is 30 m off; hyenas and raccoons to the edge of firelight at night.
19. **Animals meeting animals.** Prey do not flee predators other than wolves, and predators do not hunt other animals (wolves aside).
    Fix later (it costs server time): prey treat a bear, cougar or lynx in view as a player.

## Sources

- [BO27] North American Bear Center, "Quick black bear facts": https://bear.org/?p=27
- [BO254] Lynn Rogers, North American Bear Center, "How dangerous are black bears?": https://bear.org/?p=254
- [NH] New Hampshire Fish and Game, "Bear talk" (Ben Kilham): https://www.wildlife.nh.gov/wildlife-and-habitat/black-bears-new-hampshire/bear-talk
- [BS] Get Bear Smart Society, "Communication": https://bearsmart.com/about-bears/communication
- [FWC] Florida Fish and Wildlife Conservation Commission, "Bear behavior": https://myfwc.com/wildlifehabitats/wildlife/bear/facts/behavior/
- [NPS] US National Park Service, "Bear attacks": https://nps.gov/articles/bearattacks.htm
- Bombieri et al. 2019, brown bear attacks on humans, Scientific Reports: https://www.nature.com/articles/s41598-019-44341-w

Other animals (main sources; the full list, with which were checked, is in `docs/knowledge/animal-research-notes-2026-11-25.md`):
- Indiana DNR, white-tailed deer: https://www.in.gov/dnr/fish-and-wildlife/wildlife-resources/animals/white-tailed-deer-biology/
- Maryland DNR, white-tailed deer: https://dnr.maryland.gov/wildlife/pages/hunt_trap/wtdeerbiology.aspx
- Missouri Department of Conservation, deer dialogue: https://mdc.mo.gov/magazines/conservationist/2014-11/deer-dialogue
- Deer flight from vehicles, PLoS ONE 2014: https://pmc.ncbi.nlm.nih.gov/articles/PMC4198184
- Texas Parks and Wildlife, after the shot: https://tpwd.texas.gov/education/hunter-education/online-course/hunting-skills-1/after-the-shot
- Penn State, wind and deer movement: https://www.deer.psu.edu/winds-surprising-effects-on-deer-movement/
- Idaho Fish and Game, winter disturbance: https://idfg.idaho.gov/press/winter-activities-can-affect-wildlife
- Wildlife Online, red deer: https://www.wildlifeonline.me.uk/animals/article/red-deer-behaviour-social-structure
- Alaska Department of Fish and Game, aggressive moose: https://www.adfg.alaska.gov/index.cfm%3Fadfg%3Dlivewith.aggressivemoose
- SUNY ESF, moose: https://www.esf.edu/aec/adks/mammals/moose.php ; Michigan DNR, moose: https://www.michigan.gov/dnr/education/michigan-species/mammals/moose/moose-biology-and-habitat
- NPS, elk (Rocky Mountain, Yellowstone, Grand Canyon): https://www.nps.gov/romo/learn/nature/elk.htm , https://www.nps.gov/yell/learn/nature/elk.htm , https://www.nps.gov/grca/learn/nature/elk-danger.htm
- NPS, Yellowstone wolf facts: https://www.nps.gov/articles/yellowstone-wolf-facts.htm ; limits of wolf hunting: https://www.nps.gov/yell/learn/ys-24-1-understanding-the-limits-to-wolf-hunting-ability.htm ; why wolves howl: https://www.nps.gov/articles/why-wolves-howl.htm
- Wolf responses to people, Frontiers in Ecology and Evolution 2022: https://www.frontiersin.org/articles/10.3389/fevo.2022.792916/full
- Colorado Parks and Wildlife, red fox: https://cpw.state.co.us/species/red-fox ; MDC red fox: https://mdc.mo.gov/node/240878
- Wildlife Online, European rabbit: https://www.wildlifeonline.me.uk/animals/species/european-rabbit ; ADW, eastern cottontail: https://animaldiversity.org/accounts/Sylvilagus_floridanus/
- Wildlife Online, wild boar: https://www.wildlifeonline.me.uk/animals/species/wild-boar ; Forestry England: https://www.forestryengland.uk/article/wild-boar-the-forest-dean ; eXtension feral hogs: https://wildlife-damage-management.extension.org/?p=888
- KORA, Eurasian lynx: https://www.kora.ch/en/species/lynx/profile ; Alaska F&G, lynx: https://www.adfg.alaska.gov/static/education/wns/lynx.pdf
- Maine IF&W, beaver: https://www.maine.gov/IFW/fish-wildlife/wildlife/species-information/mammals/beaver.html ; NY DEC, mink: https://dec.ny.gov/nature/animals-fish-plants/mink ; SUNY ESF, raccoon: https://www.esf.edu/aec/adks/mammals/raccoon.php ; ICWDM, Norway rat: https://icwdm.org/species/rodents/norway-rats/norway-rat-biology/
- NPS, grizzly facts and bear safety: https://www.nps.gov/yell/learn/yellowstone-grizzly-bear-facts.htm , https://www.nps.gov/subjects/bears/safety.htm , https://www.nps.gov/articles/yell-wildlife-bear-differences.htm
- CPW, mountain lions: https://cpw.state.co.us/living-mountain-lions ; CDFW, mountain lion behaviour: https://wildlife.ca.gov/Conservation/Mammals/Mountain-Lion/Behavior ; University of Arizona Extension: https://www.extension.arizona.edu/sites/extension.arizona.edu/files/attachment/MountainLions.pdf
- Pennsylvania Game Commission, capture myopathy: https://www.pa.gov/agencies/pgc/wildlife/wildlife-health/wildlife-diseases/capture-myopathy.html
- Colorado Parks and Wildlife, protect your campsite: https://cpw.state.co.us/protect-your-campsite-wildlife
- Mutton 2019, chamois and hikers in Tyrol: https://www.karwendel.org/wp-content/uploads/2022/04/2019_LEIGH-MUTTON_Human-Disturbance-of-Chamois-in-Tyrol_Masterarbeit_klein.pdf
- FWC, alligator facts: https://myfwc.com/wildlifehabitats/managed/alligator/facts/ ; NPS Olympic, mountain goats: https://www.nps.gov/olym/goats-and-your-safety.htm ; NPS, pronghorn: https://www.nps.gov/thro/learn/nature/pronghorn.htm ; Queensland Government, kangaroos: https://www.qld.gov.au/environment/plants-animals/animals/living-with/kangaroos ; Grandin, flight zone: https://www.grandin.com/behaviour/principles/flight.zone.html ; San Diego Zoo, spotted hyena: https://ielc.libguides.com/sdzg/factsheets/spottedhyena/behavior-ecology ; ElephantVoices: https://www.elephantvoices.org/elephant-acoustic-communication ; hunting success rates, BBC Wildlife: https://www.discoverwildlife.com/animal-facts/mammals/hunting-success-rates-how-predators-compare
- Panthera, wild cat encounters: https://www.panthera.org/blog-post/what-do-if-you-encounter-wild-cat
