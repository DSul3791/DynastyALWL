# Animal routines, game trails and trapping (22 Nov 2026)

Dave, 22 Nov 2026: "we need to add trapping for players to gather food early before they are skilled at hunting ... add the idea
of Game trails ... where animals might travel occasionally and we could set traps or snares ... start with trapping smaller stuff
like rabbits and eventually trap larger ... trapping and taming live later." And: "plan animals to have routines like sleeping at
certain times or based on the sun and traveling and certain times and eating and drinking near the water at certain times ...
design an idea around it then build your system around the idea." He loves the way grass mats down where he walks.

Status: PROVISIONAL design by the trails thread under Dave's 21 Nov rule (questions go to the coordinator, answered from research,
recorded). Values marked TR-n are provisional and live in data files.

## What is already in dev (built on, not duplicated)

- `server_animals.gd`: species `active` shares by period (day, dusk, night), resting and lying (`ANIMAL_RESTING.md`, #1471), deer
  and stock walk to water at twilight (`animals_at_water_server.md`), herds, burrows (a rabbit's spawn spot), per-species behaviour
  (`ANIMAL_BEHAVIOUR.md`, #1467).
- `server_trails.gd` (21 Oct): a sparse 4 m grid of worn cells; every animal step into a new cell adds a little and the clock wears
  it away. Sent to clients (protocol 65), drawn by `grass_view.gd` as lower, paler grass.
- `server_traps.gd` (25 Oct): the Snare (twine 3, stick 2, by hand) is set as `snare_trap`; while a player is within 150 m it looks
  every 30 s for a rabbit or fox within 2.5 m (or draws one from 30 m) and rolls 0.35 x the worn-trail factor x night x bait x
  storm. A catch lays a carcass. The Bird trap is a second kind. The fish trap is separate.

What is missing, and why trails never really showed: the client kept the worn blocks but never laid them into the grass map (`grass_view._rebuild_trails` was never called; now it is). And animals have one home point and wander a few metres round it. Nothing walks
the same line twice, so the worn grid is a blob round each home, 4 m cells draw as a wide smudge, not a path, and animals (and so
trails) only exist within 300 m of a player and are made at random spots each visit. A snare catches only while its owner stands
within 150 m.

## What the research says

| Finding | Source |
|---|---|
| Deer are crepuscular: feed about 5 times a day, most at dawn and dusk; bucks bed by day in screening cover (64% of the day bedded, 27% feeding, 9% walking; 47/39/14 at night). | onX [1]; Mississippi State [2] |
| Deer travel set corridors between bedding and food; staging areas lie between; food and bedding kept within about 200 yd (180 m) in management; daily travel about 900 m by day. Water several times a day, one bed near water. | [1], [2] |
| Rabbits are active late afternoon to early morning; graze near the warren first and move out as it gets dark; usually within 150-200 m of the warren (home range 0.2-2 ha); stay above ground at night; less active in wind and rain; get most water from green plants. | NSW DPI [3]; Agriculture Victoria [4] |
| Runs are trampled, well-used paths that are reused nightly. A snare is set ON the run, loop about a fist wide, a hand high, where the feet land on a fast stretch (not where it sits); choke points (under a log, between stems) are best. 15 snares took 3 hares the first night. | Shooting UK [5]; MeatEater [6]; Wildwood [7] |
| Game trails are lines of least resistance between water, food and cover, round obstacles, at fords and the narrowest crossings; on slopes large mammals keep about a third and two thirds up. They are narrow, fade and reappear. | Wikipedia "natural lines of drift" [8]; Codidact [9]; Nebraska Game and Parks [10] |
| theHunter: Call of the Wild gives each species fixed feed, drink and rest zones and times (whitetail: feed 5:00-9:30 and 15:00-21:30, drink 12:00-15:30, rest 9:00-12:30 and 21:00-5:30). Players learn the zones and the paths between them. | gameplay.tips [11] |
| Red Dead Redemption 2 keeps food-chain logic and routines for about 200 species; carcasses rot and are scavenged. Permafrost's rabbit trap catches over game days on a spot; The Long Dark rolls a snare's catch over time away (wiki page refused our reader). | Medium [12]; allthings.how [13] |

Sources: [1] onxmaps.com/hunt/learn/collections/whitetail/hunting-tactics/deer-movement; [2] extension.msstate.edu understanding-buck-movement;
[3] dpi.nsw.gov.au rabbit-biology; [4] agriculture.vic.gov.au european-rabbit; [5] shootinguk.co.uk/news/how-do-i-set-rabbit-snares;
[6] themeateater.com how-to-snare-a-snowshoe-hare; [7] wildwoodsurvival.com rabbitsnarerb; [8] en.wikipedia.org/wiki/Natural_lines_of_drift;
[9] outdoors.codidact.com/posts/50397; [10] magazine.outdoornebraska.gov/?p=137007; [11] gameplay.tips/guides/4433; [12] medium.com
the-reality-of-red-dead-redemption-2s-ai-part-1; [13] allthings.how permafrost rabbit trap.

## The idea

**Animals belong to places, and keep a daily clock between them. The paths between the places are the game trails.**

1. **Places are fixed in the world**, worked out from position (a hash of the square), never saved, the same every visit and on
   every server: a rabbit **warren** in some 64 m squares of open grassland, and a deer **range** (a bed in sheltered ground and a
   feeding ground 80-200 m away, plus the water the twilight drink already finds) in each 256 m square that suits deer. An animal
   is made at its place, so the animals a player meets tomorrow live where today's did.
2. **A daily clock** per species, on the periods the animals already use (night, dawn, day, dusk): rabbits lie up at the warren by
   day and go out along their runs to graze from dusk, through the night, back at dawn; deer bed by day, walk the trail to the
   feeding ground at dusk (drinking on the way, as now), feed and lie there at night, and walk back to bed at dawn. The existing
   active shares still decide how many are up or lying at each place.
3. **Trails are the routes between places.** Each route is laid once from the ground: it bends round steep ground (keeps to the
   easier line, as real trails do) and never crosses deep water. Animals on a trip walk the route point by point (normal walking,
   no sliding), single file as deer do. The route is a trail from the start (trails in the wild are years old); animals walking it
   keep the old worn grid wearing as before.
4. **The grass shows it.** The client gets each square's routes with its trail block and lays them into a fine map round the player,
   so the grass on a trail lies matted down the way it does where a player walked (the same squash and colour Dave likes), a narrow
   line for a rabbit run and a wider one for a deer trail. It never stands back up while the place lasts.
5. **Snares go on the runs.** A snare right on a run (within half a metre of the line) fishes at full strength, one a metre or two
   off much less, one in open grass hardly at all (the existing trail factor). The rabbits that walk the runs at dusk pass through
   the loop. And because real snares are set at dusk and checked at dawn, a snare on a run now also catches while nobody is near,
   at a slow rate by the hour and the warren's activity (no animal is simulated or taken; the carcass is laid as now).

Server cost: places and routes are worked out once per 256 m square when a player first needs it (about 30 routes of a few dozen
ground-height reads), at most one square per tick, kept in memory and dropped when no player is near. A trip is a list of points
on the animal (the step code is unchanged). A snare away from players is one roll per check (30 s). Network: a square's routes ride
in the trail block already sent when it changes (a few hundred bytes deflated). Client: one 256 x 256 texture rebuilt when blocks
arrive or the player moves 16 m.

## Stages

**Stage 1 (this work)**
- 1a, PR 1: places, the daily clock for rabbits and deer, routes as trails, trips along them, routes on the wire (protocol bump),
  the matted-grass look, spawn at the places. Tests: routes repeatable and off steep ground, rabbits out at dusk and home at dawn,
  deer bed by day and feed by night, a trip walks the route, the block codec round trip.
- 1b, PR 2: snares on runs (distance to the line), catches while away, an early goal ("Snare a rabbit", after "Twist twine";
  coordinator ruling needed, catalog control). Tests: on-run vs off-run rates, away catches by the hour, the goal event.

**Stage 2**: the clock on the real sunrise and sunset (weather.gd `sunrise_hour`, the sun the sky draws) for every species, not the
fixed hours; elk and moose ranges; fox and boar routines; signs along trails (tracks, droppings: `tracking.gd`); players' own
paths wearing the same way; a choke point (a log over the run) doubles a snare's chance.

**Stage 3 (larger game)**: a deadfall for fox, raccoon, mink and the like; heavier snares (wire, from the smithy) on deer trails,
taking deer only on trails; a pit trap for boar and deer by trail crossings. Each a station or hammer/knife plus blueprint recipe
with only that stage's tools and materials (no kits).

**Stage 4 (live trapping and taming)**: a box trap (wood, nails) and a pen; a live catch stays alive in the trap, is fed and calmed,
and can become a penned animal (rabbits, then goats, pigs); builds on the companion system (the stray dog befriended with food).

## Provisional values (TR-n)

- TR-1 warren chance 0.45 per 64 m square of open ground with rabbit biome weight, slope under 0.35; 2-3 runs of 15-40 m each.
- TR-2 deer range: one per 256 m square where deer may live; bed on the steepest acceptable side ground (sheltered, above the
  bottom), feeding ground on the flattest open ground 80-200 m from it.
- TR-3 routes: a point every 12 m, each tried 3, 6 or 12 m either side of the last one's line, the gentlest climb kept, drifting at most 30 m off the straight line; round deep water by a dry point 20-60 m to one side of the middle; a small wiggle every 4 m.
- TR-4 clock: rabbits out from dusk to dawn (dusk and night periods), deer to feed at dusk and back at dawn.
- TR-5 the look: a run 0.35 m wide, a deer trail 0.6 m, fading over 0.4 m either side; the grass squashed by the trample's own squash (0.75, data/look/grass_trample.json) and shaded the same, so a trail looks like ground just walked.
- TR-6 snares: full factor within 0.5 m of a run, falling to the old factor at 2 m; away catches tuned to about one rabbit in three
  nights for a snare on a busy run (Wildwood's 3 in 15 the first night).

## Not done / risks

- Periods are still the fixed hours (stage 2 moves them onto the sun).
- Places use terrain, biome and water only (tree cover is not known far from players, and must give the same answer every visit).
- Animals leave ground people settle: a place inside a no-spawn zone (20 m round anything a player put down) is not used, its
  animals keep their old home, and its routes are not sent, so the trail grows back. Real wildlife abandons settled ground.
- Rabbits drink little (green plants give their water), so only deer take the drinking leg; rabbits' runs end at grazing.
