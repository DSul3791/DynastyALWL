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

1. **Fire keeps everything away from players** (Dave, 25 Nov 2026). See "Fire" below. It is the one rule that beats hunger, cornering
   and young.
2. Animals **stare before fleeing** and **warn before attacking** (growl, huff, stamp; Dave 23 Nov 2026).
3. No teleporting, sliding or passing through players; every animal can be hit; each model uses **its own** moves and attacks.
4. Blood trails and bleeding to death stay.
5. Sound is directional and easy to pinpoint.
6. **Core rule:** the game does not want the player dead unless they do something deliberately stupid. At 1 health no blow takes more.
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

Exceptions in the code today, which **break Dave's rule**: a bear at its den ignores a torch or fire (`_in_den`); a mother with a player
between her and her young attacks "torch or not"; a wolf pack rushes a player near its pups' den "torch or not" (a campfire still holds
it); wolf packs skip the general fire check and use their own (`a.has("pack")`).

Real animals: most wild mammals avoid fire and smoke, and people at a camp. Food-conditioned bears and wolves do walk into camps for
food (NPS, bear.org), and fire alone does not stop a determined predator. Dave's rule wins: in our game a lit fire always holds.

In our game (recommended):
- Keep today's radii. They scale with the fire's size, which is easy to learn.
- **No exceptions.** A starving animal circles at the edge of the light and waits, it does not come in. A cornered animal next to a fire
  breaks away along the edge, never through the light and never at the player in it. A mother whose young is near a player standing in
  firelight calls the young away instead of charging. A den guard holds at the edge.
- The light edge is a visible line in play (the glow), so the player can see where safe is.
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
| Our player | runs 9.0 m/s and never tires (`terrain_client.gd` RUN_SPEED; no stamina) | code |
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
| S2 Eating | Forages berries, nuts, insects, roots, carrion. Reluctant to leave rich food; a bluff charge "when you confront a bear that is trying to get a meal" [NH]. | Grazes and forages (graze clips). At a carcass or berry patch it holds its ground and warns a player within 20 m instead of fleeing at once. |
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
| S14 Hungry, starving | In poor food years bears range farther and come to people's food [FWC]. | **Dave: it runs "unless it was starving or trapped."** A starving bear (spring after the den, or a poor autumn) does not run from a player: it stands its ground, comes to camps and food left out, takes carcasses, and attacks by the ladder if pushed. It still never enters firelight. |
| S15 Hunting | Mostly a forager; takes fawns and calves in spring; rare predatory attacks on people are silent, by a stalking bear [BS], [BO254]. | Only aggressive-born bears (5%) stalk a player, silently, at 1.2 m/s; never into firelight; never by night. Takes fawns in spring if animal-on-animal hunting is added. |
| S16 Meets another animal | Yields to brown bears; wolves may harass it; deer avoid it. | Deer, elk and moose treat a bear like a player (flee). A black bear gives way to a brown bear. |
| S17 Group | Solitary. | Single; mothers with 1 to 3 cubs (share 0.3 today). |
| S18 Day and night | Day and dusk; naps by day; mostly beds at night. | Today: day 1.0, dusk 1.0, night 0.05. Keep, add the midday rest. |
| S19 Weather, seasons | Dens up to 7 months in the north; spring hungry; autumn eats heavily (hyperphagia). Heat makes them rest. | Winter: in dens, not out (or very few). Spring: hungrier, bolder (threat x1.5 today). Autumn: busy feeding, warier of people (x0.7 today). Rain: little change. |
| S20 Fire | Avoids people and fire unless food-conditioned. | Fire rule above, no den exception. |
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

## Other animals

(In progress. The temperate forest animals come next, then birds, mountain, plains and the big game.)

---

## Gap list (biggest first, one fix each)

(Bear items now; the rest is added as each section lands.)

1. **Bears never fight back when born "passive"** (half of all black bears: temperament passive 0.5). Passive means `attacks: false`, so
   `server_big_game.provoke` and `_threat_m` do nothing: hurt or cornered, it only runs. Fix: bears get no passive share (black bear
   defensive 0.85, neutral 0.1, aggressive 0.05), and a cornered or run-down bear fights (S8).
   `data/animals/animals.json` black_bear temperament; `server_animals.gd` on hit, `_at_bay`.
2. **A fleeing bear can be caught on foot.** Flee 9 m/s for 6 s (`burst_s`), then 4.5 m/s (`trot_share` 0.5); the player runs 9 m/s for
   ever. Fix: bear flee 12.5 to 13.5 m/s for 8 s, then at least 10 m/s until `safe_m` 150 m. Both bears. Check the run clip's rate cap
   (`animal_gait.gd` RATE_MAX 2.5) keeps legs matched at 13 m/s.
3. **Bears growl and roar all the time.** Fleeing and watching play `bear_growl`; warning and charge play `bear_roar`; a natural growl
   plays in the forest every 7 to 15 minutes. Fix: no bear call when fleeing, watching, eating or wandering; no natural far bear calls;
   huff at the first warning, jaw-pop at the second, a bawl in a fight, moans when trapped (sound table above). Needs huff, jaw-pop,
   bawl and moan recordings (Dave's listening). `terrain_client.gd` `state_changed` hook, `creature_sounds.gd` KINDS bear `every`.
4. **No hind-leg stand, swipe or bite for the black bear** (see the model table). Fix: one of options (a) to (c).
5. **Threatened bears do not rear up first.** Today warning is the angry stand (brown) or plain breathing (black). Fix: the ladder is
   rear up on hind legs, huff, drop, jaw-pop, then charge with a swipe or bite (Dave's order).
6. **A starving bear is not modelled.** Only the season scales boldness. Fix: a hunger flag (spring after the den; poor food) that stops
   it running from a player and draws it to camps and carcasses, never into firelight.
7. **Fire exceptions break "fire keeps everything away".** The bear den ignores torches and fires; mothers and wolf pup dens attack "torch
   or not". Fix: remove them; hold at the light's edge instead.
8. **A bear that has beaten a player to 1 health does not leave** (check: the core rule stops the damage, nothing tells the bear it won).
9. **No bear trap.** Snares catch rabbits and foxes only. Fix: a baited heavy snare or pit (trap stage 3), caught bear tethered 2 m.
10. **No midday rest or bedding for bears**; the black bear's `LyingBreathing` clip is unused.

## Sources

- [BO27] North American Bear Center, "Quick black bear facts": https://bear.org/?p=27
- [BO254] Lynn Rogers, North American Bear Center, "How dangerous are black bears?": https://bear.org/?p=254
- [NH] New Hampshire Fish and Game, "Bear talk" (Ben Kilham): https://www.wildlife.nh.gov/wildlife-and-habitat/black-bears-new-hampshire/bear-talk
- [BS] Get Bear Smart Society, "Communication": https://bearsmart.com/about-bears/communication
- [FWC] Florida Fish and Wildlife Conservation Commission, "Bear behavior": https://myfwc.com/wildlifehabitats/wildlife/bear/facts/behavior/
- [NPS] US National Park Service, "Bear attacks": https://nps.gov/articles/bearattacks.htm
- [PC] Parks Canada, "If an attack occurs" (black bear): https://parks.canada.ca/docs/v-g/oursnoir-blackbear/page4
- Bombieri et al. 2019, brown bear attacks on humans, Scientific Reports: https://www.nature.com/articles/s41598-019-44341-w
