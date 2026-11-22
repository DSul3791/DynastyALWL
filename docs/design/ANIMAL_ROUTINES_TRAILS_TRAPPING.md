# Animal routines, game trails and trapping (22 Nov 2026)

Dave, 22 Nov 2026: "we need to add trapping for players to gather food early before they are skilled at hunting ... add the idea
of Game trails ... where animals might travel occasionally and we could set traps or snares ... start with trapping smaller stuff
like rabbits and eventually trap larger ... trapping and taming live later." And: "plan animals to have routines like sleeping at
certain times or based on the sun and traveling and certain times and eating and drinking near the water at certain times ...
design an idea around it then build your system around the idea." He loves the way grass mats down where he walks.

Coordinator rulings D-TRAP-1 (goal, away catches with limits, protocol 149), D-TRAP-2 (night activity) and D-TRAP-3 (players'
worn paths shown to all at half the animal rate on a cheap grid, fading over about a game week (provisional, to tune), its cost measured; the sun clock for animals only) are recorded in
the coordinator log. Status: PROVISIONAL design by the trails thread under Dave's 21 Nov rule (questions go to the coordinator, answered from research,
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
- Changed 22 Nov 2026 (Dave: "the server doesn't have to do any work once a trap is put out"): no looks and no draw. A catchable
  animal stepping within lure_m of a set snare (animals step only near players) gets one roll for that pass. A snare off any animal
  trail never catches. With nobody near nothing runs; when a player comes back within 200 m (the animals' own active radius) the time away is rolled once, by the
  rabbits' activity at each hour (latest 24 h). Snares sit in a 32 m grid. No limit on how many a player sets.

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

Server cost: places and routes are worked out once per 256 m square when a player first needs it (about 30 routes, one job per
warren square or deer range, a deer job some 150-250 ground reads), jobs run until 0.6 ms of a tick is spent (one job may run over;
to be measured on the PC), only once the ground tiles under the square are loaded, kept in memory and dropped when no player is near.
A snare's distance to a run looks only at routes whose box passes near it. A trip is a list of points
on the animal (the step code is unchanged). A snare away from players costs nothing until a player comes back (one roll for the time away). Network: a square's routes ride
in the trail block already sent when it changes (a few hundred bytes deflated). Client: one 256 x 256 texture rebuilt when blocks
arrive or the player moves 16 m.

## Stages

**Stage 1 (this work)**
- 1a: places, the daily clock for rabbits and deer, routes as trails, trips along them, routes on the wire (protocol bump),
  the matted-grass look, spawn at the places. Tests: routes repeatable and off steep ground, rabbits out at dusk and home at dawn,
  deer bed by day and feed by night, a trip walks the route, the block codec round trip.
- 1b (same PR, one lane run): snares on runs (distance to the line), catches while away (D-TRAP-1: one roll a game hour, only on a
  rabbit run, a sprung snare holds its catch, carcasses rot as before), the starter goal "Snare a rabbit" after "Twist twine"
  (D-TRAP-1; event snare_catch when a snared carcass is worked). Tests: `test_traps` away_checks, `test_animal_trips`.

**Stage 2a (built, D-TRAP-3)**: animals' periods on the real sun (server_animals `period_now`: dawn from an hour before sunrise to two
after, dusk from sunset to three after, from weather.gd `sunrise_hour`, so equal to the fixed hours at the equinox; bandits and
companions keep `period_of`); the trip clock as offsets from sunrise and sunset (TR-7); moose and elk ranges like deer (TR-8), a
moose's feeding ground by water when it can be, on a deer trail (kind 1; a wider moose trail would touch the grass code and its tests for little). The rest of stage 2 (fox rounds,
player paths, choke points, signs) is folded in here as each part lands. Sources for 2a: Delisle et al. 2024, Sci. Rep.
(deer activity in windows 2 h either side of sunrise and sunset); scienceinsights.org on moose (feeding peaks at dawn and dusk, water in heat).

**Stage 2b (built)**: fox rounds (TR-9). A fox earth in some trail blocks, on side ground near the warrens; it keeps no trail
of its own (not drawn, not sent, not a run for a snare), and each night the fox walks one of its rounds by way of 2 to 4 warrens, a
different one from the night before (picked by the night, turning at noon, so midnight does not start a second round), out half an hour after sunset and home a quarter hour before sunrise. Once the ground round a
player is worked out, foxes are made only at earths (as rabbits at warrens), so foxes live where the rabbits are. A snare on a run
near an earth may take a fox while nobody is near (TR-10). The server's "ranges: block ... worked out" line now gives the jobs' own
time and the slowest job in ms (a fox earth is one job per round, so no job lays more than a few legs), so a lane can tell ranges work from other ground waits. Sources: wildlifeonline.me.uk on red fox
activity and ranging (Oxford radio-tracking: about 4.5 km a night over about 18 ha; first long activity about 30 min after sunset,
ending about 15 min before dawn).

**Stage 2c (built, D-TRAP-3)**: players' own paths. Each step into a new 4 m cell wears the player's path in a grid of its own
(server_trails `pblocks`) at half a deer's wear, on the ground only. Paths are drawn and sent with the trails (the more worn of the two
in a cell), saved with them, and fade by about a game week from well walked. Nothing wears more than 1.5 m above or below the ground (a floor, a tunnel, swimming). Snares and Tracking still read only the animals' trails,
so a path to the well does not catch rabbits. Cost: a cell lookup per player per tick, and a write only on entering a new cell. A
choke point (TR-12): a snare on a run within 1.2 m of a tree's root or a boulder's edge catches 1.5 times as often (snarers set where
the run squeezes past stems or a rock). Placed logs do not count, since they settle the ground and the animals leave.

**Stage 2d (built, TR-13)**: signs along trails, worked out on each client from the routes it already has (src/client/trail_signs.gd,
data/look/trail_signs.json; design /mnt/project-files/trails/STAGE2D_SIGNS_DESIGN.md). Pellet latrines lie 1 to 3 m off each run's
ends (warren and grazing), a scrape where runs of two warrens meet, deer prints where a trail crosses water (one line per 30 m),
and deer droppings by the bed. A player sees them from Tracking 25 (latrines, droppings) and 50 (scrapes, prints), within 15 m
rising to 30 m at 100. Nothing is made or drawn while the world loads round the player, or below Tracking 25; signs are
worked out afresh (routes within reach plus 40 m only) when the player moves 8 m, so water loaded since shows. Heaps take the lowest
of three ground probes, so one by a trunk lies on the ground. Settled ground's routes stop, and its signs
go with them. Not yet: a look hint on a sign, fen and bog ground as wet (only water counts now), fox scat. Sources: Ziege et al. 2016,
BMC Ecology (rabbit latrines); onX, Texas Parks and Wildlife and Idaho Fish and Game on deer sign.

**Next**: boar routines once the research is verified; a worn-earth mark where a trail crosses ground with no grass.

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
- TR-5 the look: a run 0.8 m wide, a deer trail 1.2 m, fading over 0.5 m either side (first 0.35 and 0.6 m: Lane A pictures 22 Nov showed nothing, too thin to read through the tufts; a walked path, the trample Dave likes, is 1.6 m); the grass squashed by the trample's own squash (0.75, data/look/grass_trample.json) and shaded the same, so a trail looks like ground just walked. Log lines for a lane: server "ranges: block ... worked out" (places and their homes) and "trails: block ... with N bytes of routes", client "grass runs: block ... came with N routes" and "grass runs: N routes near, T texels matted".
- TR-7 sun clock: rabbits out 1 h before sunset, home 1 h after sunrise; deer, moose and elk out half an hour before sunset, home
  half an hour after sunrise (jitter 0.75 h each way). At the starter row sunrise runs 04:51 (midsummer) to 07:09 (midwinter).
- TR-8 moose (salt 300): 12 tries, feeding ground within 40 m of deep water preferred, bed and feed 80-220 m apart, trail kind 1; elk: deer's
  rules (salt 600, so its spots and rolls share no hash with moose or deer), 100-230 m apart; both take a spot in a less liked biome at its weight (weight_roll), as the random spawn did. How many a player sees is to tune after Dave plays.
- TR-6 snares: full factor within 0.5 m of a run, falling to the old factor at 2 m; away catches 0.045 a game hour at full rabbit
  activity: a snare squarely on a run takes about two rabbits in five nights, about one a game day in two (Wildwood's 3 in 15 the
  first night); six snares on runs feed one player well (there is no limit on how many a player sets). Off a run, none while away.
- TR-9 fox (salt 900): an earth in half the blocks (times the fox biome weight), 8 tries, the spot nearest slope 0.25 (at most
  0.6, dry), with at least 2 warrens within 200 m; 3 rounds of 2-4 warrens each. Clock: out sunset + 0.5 h, home sunrise - 0.25 h,
  jitter 0.5 h.
- TR-10 away fox: a snare on a run within 300 m of an earth may take a fox at 0.2 of the rabbit rate times the fox's activity, so
  about one catch in six there is a fox (which animal it was goes through the owner's luck, the fox being the bigger catch).
- TR-11 players' paths: 0.04 a pass (half a deer's 0.08), drawn from about 6 walks there and back, fading 0.14 a game day (a
  well-walked path is gone in about a game week, against 4 days for an animal trail), none more than 1.5 m above the ground.
- TR-13 signs: see data/look/trail_signs.json (latrine 1-3 m off, 8-15 pellets; scrape where runs pass within 2 m, 5 m clear of
  a warren; prints 4-6 on water within 3 m, one line per 30 m; droppings within 4 m of a bed; Tracking 25 and 50; 15 to 30 m).
- TR-12 choke point: within 1.2 m of a tree's root or a boulder's edge, on a rabbit run (the snare's prey), x1.5; the Bird trap takes no lift.

## Cost on the server tick

The places are worked out in jobs (a warren, a deer, moose or elk range, a fox earth then each of its rounds) within budget_ms
(0.6 ms) a tick. A single range job measured 34 to 67 ms on Lane B (22 Nov, a throttled machine), almost all in laying one trail
(a ground and water read for 7 tries every 12 m). So a job past the budget now stops at its next read and runs again next tick from the
reads its block kept: it makes at least fresh_reads_min (4) new reads a tick and comes out the same as worked in one go. A late tick
of a long job also replays its kept reads (look-ups, not ground reads), so a tick may run somewhat over budget; the "slowest ms" on
the ranges log line is the measure, to be read on Lane A. On a slow machine a block takes longer to be worked out (seconds to
minutes). Nothing is worked out for hold_after_join_s (40 s) after a player joins, at most once in 120 s, so a cold join's own
ground load does not share the CPU with it (the gate thread's reading of a longer first-join freeze); until then animals spawn on the
old random spots and snares use the old trail factor.

## Not done / risks

- Places use terrain, biome and water only (tree cover is not known far from players, and must give the same answer every visit).
- Animals leave ground people settle: a place inside a no-spawn zone (20 m round anything a player put down) is not used, its
  animals keep their old home, and its routes are not sent, so the trail grows back. Real wildlife abandons settled ground.
- Rabbits drink little (green plants give their water), so only deer take the drinking leg; rabbits' runs end at grazing.
