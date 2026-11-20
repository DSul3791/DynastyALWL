# Plumbing and wells: design (14 Nov 2026)

Dave, 14 Nov 2026 06:30Z: "pipes were originally made from wood so lets establish some wooden plumbing system. iron pipes and plumbing can be made once
you unlock the master smithy." 06:35Z: wells in three tiers, Primitive (logs, a limited amount of water per day), Improved (stones, clay and planks,
double), Advanced (twice the size, round, a four-posted roof, even more), each enough for a different size of community ("a starting idea").

Status: PROVISIONAL throughout. Every number below is a first guess for Dave to retune; the assumed values are logged in
`docs/ai-team/missions/GOALS-REPAIR/REPAIR_DECISIONS.md` (sent through the coordinator).

## 1. What exists in dev (14 Nov, 008def03)

- The water network engine is built and tested: `src/shared/water_network.gd` (pieces with an inlet and an outlet, solved like a power grid,
  accounting only; the live water sim never sees it) and the server half in `src/stream/server_items.gd` (pieces join when built, wells and
  pumps are worked with E, a source with nothing below it pours into the worker's containers, E at a trough drinks or fills from it, tank litres
  saved in `crops.json`). Tests: `test_water_network.gd`, `test_water_pieces.gd` (they use stand-in rows: "No water rows exist yet").
- The 21 catalog water pieces (structures states 166-187, blueprints 128-149) carry an older draft of the data ("ports", "open" meaning an open
  channel) that the engine does not read: no inlet or outlet (nothing links), no "windlass"/"pump"/"ground_water" (E does nothing), "open": false
  on pipes (the engine reads that as a shut gate), no "litres_max" on tanks. All 21 blueprints are `known: false, locked: true`.
- There is no wooden pipe, no pipe tee, and no E toggle for the Sluice.

So the work is: wire the catalog pieces to the engine, add the missing pieces, and unlock each piece only once it works.

## 2. How water flows

source (a well; no pumps since 20 Nov 2026, s10) -> conduits (channels: open, downhill only; pipes: closed, carry under head) -> tanks (troughs,
cisterns: hold litres; drink or fill a container at them with E) or straight into the worker's containers when nothing is linked below.

- Wells are the source end. Each well has a daily yield: it holds at most one day's water and fills again at its yield over a game day
  (a game day is one real hour). Drawing (E, a windlass bucket of 10 L at a time, slower the deeper the water) takes from that store; a
  drawn-dry well says so and stops. A well needs fresh water within 200 m and no deeper than it reaches (the engine's existing rule).
- Channels and pipes are 2 m pieces snapped end to end; a corner turns, a tee splits equally. The engine's rules stand (no water climbs between
  open pieces, no siphons, loops refused, 256 pieces a network).

## 3. Build order (one reviewable PR each, all into dev)

1. **Wells** (this PR). Primitive - Well (new), Improved - Well (the existing `stone_well`, id and number kept, renamed from "Well"; its cost is
   already stones, clay mortar and planks), Advanced - Well (new). Daily yield store, saved with the tanks in `crops.json`. Unlocked.
2. **Wooden plumbing.** Wooden - Channel / corner / tee, Sluice (E opens and shuts it, doors' toggle-twin pattern), Wooden - Trough,
   Wooden - Hand pump (retired 20 Nov 2026, s10), and new Wooden - Pipe / Pipe elbow / Pipe tee (bored logs: the first closed pipe). Unlocked.
3. **Stone channels, cisterns** (the same data conversion). Unlocked, except the Raised cistern: only a force pump fills it, so it
   stays locked; Dave, 20 Nov 2026: cisterns are big tanks, not pumps (section 10). **Clay plumbing is retired** (Dave, 14 Nov 2026: "I don't think clay plumbing
   would make sense. We should remove clay plumbing altogether."): Clay pipe (730), Clay - Pipe (740), Clay - Pipe elbow (742) and
   Clay - Pipe tee (744) are retired with their numbers kept, blueprints 141-143 retired, structure states 179-181 retired (rows kept for their numbers, no look or water block), the Clay pipe
   recipe (352) retired; a saved Clay pipe loads as Clay. Closed pipe is the Wooden - Pipe (PR 2), and copper since section 9.
4. **Iron plumbing: dropped** (Dave, 19 Nov 2026: iron would rust; section 7). Pipes are wood or copper, and taps and drip heads are copper only
   (section 9). The Iron - Hand pump and the Deep-well pump are retired with all pumps (Dave, 20 Nov 2026, section 10).

## 4. Wells (PR 1), PROVISIONAL values and why

Water a character uses in a game day (data in dev): drinking 1.0-1.2 L (`vitals.json` thirst rest/work_ml_day); cooking, about two water
ingredients at 0.5 L each (`unit_ml` 500, A-1); a garden bed up to 8 L (crops `pour_ml`, A-3); tanning, concrete and animals now and then.
Call it **about 20 L a person a day** with a couple of beds.

| Tier | Id | Size | Daily yield | Serves | Reaches down | Cost | Hammer |
|---|---|---|---|---|---|---|---|
| Primitive - Well | `primitive_well` (new) | 1.6 x 1.6 m, log curb | 100 L | a household, ~5 | 6 m | 8 Log, 4 Twine, 1 Clay - Pot | 1 |
| Improved - Well | `stone_well` (kept) | 1.6 x 1.6 m, stone curb | 200 L (double) | a hamlet, ~10 | 25 m | 30 Cobblestone, 8 Clay mortar, 4 Plank, 1 Rope, 1 Bucket (unchanged) | 1 |
| Advanced - Well | `advanced_well` (new) | 3.2 x 3.2 m, round, four-posted roof | 600 L (triple) | a village, ~30 | 40 m | 60 Cobblestone, 16 Clay mortar, 12 Plank, 4 Log, 16 Bark shingle, 2 Rope, 2 Bucket | 1 |

**The gate is the materials, not the hammer** (all three are hammer tier 1): the Primitive well is first-day work (logs, twine and a
campfire Clay - Pot, which hauls 3 L at a time); the Improved and Advanced wells need Planks (and a Bucket, itself 6 Planks), and Planks need
a saw (the Copper saw is the first), so they arrive once a Primitive Smithy has made one; the Advanced well also needs Bark shingles and twice the stone.

The Improved and Advanced windlass hauls a 10 L bucket: at 5 m down about 52 L a real minute, so a full Improved well (200 L) is drawn in about four
real minutes. The Primitive well's 3 L clay pot gives about 16 L a minute there, so its 100 L take about six. Each is full again a game day (one real
hour) later. Wells are a source of clean water and keep the engine's 4-sources-a-chunk limit.

Goals: `build:stone_well` (Build Well) keeps its id; its title follows the rename. Goals for the two new wells belong to the goals thread.

## 5. Wooden plumbing (PR 2), PROVISIONAL values

| Piece | Water block | Cost |
|---|---|---|
| Wooden - Hand pump (retired 20 Nov 2026, s10; was unlocked) | suction source, 7 m (less 1 m per 1,000 m up), 0.8 L/s at 40 W: 48 L/min at 4 m; spout 0.7 m up, 0.27 m to +Z | unchanged |
| Wooden - Channel / corner / tee (unlocked) | open, 120 L/min, ends 0.23 m up, 1 cm built-in fall per piece (full flow on a level run); catches a spout up to 0.4 m across and 1 m above | unchanged |
| Sluice (unlocked) | a channel with a gate; built shut, E opens and shuts it (open twin `wooden_sluice_open`, state 422) | unchanged |
| Wooden - Trough (unlocked) | tank 100 L; catches water over its rim (0.48 m) from up to 1 m across and 1.5 m above; a bung at its base (0.15 m up at +X) feeds a pipe | unchanged |
| Wooden - Pipe / elbow / tee (new, 1352-1354) | a bored log, closed, 60 L/min under head, ends 0.13 m up | 1 Log + 1 Twine (tee 2 Log + 1 Twine) |

How it fits together:
- **Channels and pipes have no fixed direction.** Whichever end the water reaches is the inlet; the server turns every channel and pipe from the
  sources down whenever a piece is built or taken away, and again at load, so build order does not matter.
- **Open channels** run downhill (the engine's rules: no climbing between open pieces; full flow from a 0.5 % fall). A spout, a well's rim or
  a channel's end pours into a channel or trough below it.
- **Log pipes** are closed: they carry water under head from a trough's or cistern's base outlet, downhill, with no siphons. A trough on higher
  ground gives a small head (12 cm gives 12 % of 60 L/min); a cistern (PR 3) gives more.
- What a player does: build a well, lay channels from its spout downhill to a trough, open the sluices, and work the well (E). (The hand pump was retired 20 Nov 2026, s10.)
  Drink or fill a container at the trough (E). Lay log pipes from a trough's base downhill to another trough.

## 6. Stone channels and cisterns (PR 3), PROVISIONAL values

| Piece | Water block | Cost |
|---|---|---|
| Stone - Channel / corner / tee | open, 300 L/min, ends 0.13 m up, 1 cm fall a piece, catches like a flume | unchanged |
| ~~Clay - Pipe / elbow / tee~~ | retired 14 Nov 2026 (Dave: remove clay plumbing altogether); a closed run uses the Wooden - Pipe | - |
| Stone - Trough | tank 200 L, rim 0.58 m, base outlet like the wooden trough | unchanged |
| Cistern | tank 2,000 L; catches over its 1 m rim from up to 1.2 m across and 2 m above; base outlet at +Z; its water stands 0.5 m over the outlet (`head_m`), so a level log pipe from it runs at about half cap | unchanged |
| Raised cistern (locked; a big tank, not a pump, Dave 20 Nov 2026, section 10) | tank 2,000 L on a 2 m plinth; outlet at its foot with the tank 2.5 m over it (a level pipe runs full); fills only through its riser at the foot (-Z) from a pipe whose water surface reaches its top (`lift_m` 2.85: a force pump; no pumps now, see section 10), never from a hand pump | unchanged |

Engine additions (water_network.gd): a tank's `head_m` (its water over its base outlet) and `lift_m` (a riser-fed tank takes water only from a
surface that high over its inlet). The cisterns' "overflow" is not modelled: a full tank backs up, as the engine already does.

## 7. Iron plumbing: SUPERSEDED (Dave, 19 Nov 2026)

The deferred iron plan (Iron pipe section, Iron - Pipe / elbow / tee, and an iron tap) is dropped: taps and drip heads are copper only (Dave, 19 Nov 2026, restated 20 Nov). Dave, 19 Nov 2026 15:06Z: "There's really no need
to go into iron cause iron would rust and steel would do the same thing so there's no point in having iron or steel [...] copper would be the best".
Section 9 replaces it. The old design stays in git history (and the unmerged bundle `plumbing/plumbing-stack.bundle`); nothing of it is built. The
Iron - Hand pump, the Deep-well pump and the Raised cistern were not part of that ruling and stayed locked; since then the pumps are retired and the
Raised cistern is kept as a big tank (Dave, 20 Nov 2026, section 10).

## 8. Assumed on Dave's behalf, for his review

Every value below is PROVISIONAL (coordinator ruling: build costs and numbers may be assumed and tuned later). Reasoning in the sections named.

- P-1 Well yields 100 / 200 / 600 L a game day, at about 20 L a person a day (s4); Primitive reaches 6 m, Improved 25 m, Advanced 40 m.
- P-2 Primitive - Well: 8 Log, 4 Twine, 1 Clay - Pot; hauls a 3 L pot, so it is first-day work (s4).
- P-3 Advanced - Well: 60 Cobblestone, 16 Clay mortar, 12 Plank, 4 Log, 16 Bark shingle, 2 Rope, 2 Bucket; 3.2 m round, hammer 1 (s4).
- P-4 Improved - Well is the existing `stone_well` renamed (coordinator-approved), cost unchanged; windlass bucket 10 L (s4).
- P-5 Wooden channels 120 L/min with a built-in 1 cm fall a piece; Wooden - Trough 100 L with a base outlet; Sluice built shut, E toggles (s5).
- P-6 New Wooden - Pipe / elbow / tee: closed bored logs, 60 L/min under head; 1 Log + 1 Twine (tee 2 Log + 1 Twine) (s5).
- P-7 Wooden - Hand pump 0.8 L/s at 40 W (48 L/min at 4 m) (s5). Retired 20 Nov 2026 (s10).
- P-8 Stone channels 300 L/min; Stone - Trough 200 L (s6). (Clay pipes retired by Dave, not assumed.)
- P-9 Cistern 2,000 L, 0.5 m head; Raised cistern 2,000 L, 2.5 m head, filled only by a force pump, so locked (Dave, 20 Nov 2026: a big tank, not a pump, s10).
- P-10 A saved Clay pipe loads as Clay (renames.json): nothing else uses it, and its recipe took 3 Clay for 2 (s3).
- (19 Nov 2026, s9) PV-1 Wooden - Pipe: 1 Log + 1 Twine by hand, knife kept; 2 m a piece, 60 L/min; wears to 0.25 in 56 game days, flow x condition.
- PV-2 Copper - Pipe: 1 Copper ingot at the Primitive smithy for 3 m; 180 L/min; never wears.
- PV-3 A run is straight, up to 30 m, paid in whole pieces; the start must be a connection point; within 6 m reach of where you stand at each click.
- PV-4 Copper - Tap: 1 Copper ingot; only on a pipe's end or joint; its 3 slots fill water containers at up to 30 L a real minute between them (Dave 19 Nov 20:11Z gave E to drink, F with about 3 slots; the fill rate is assumed). Water reaches it from the first tank up its pipes that holds any.
- PV-5 Copper - Drip head: 1 Copper ingot; draws 2 L/min while water reaches it; Dave (19 Nov 20:09Z) set the 10 m circle; assumed: the beds and plots there are kept fully watered, at any height within 10 m.
- PV-6 Barrel: 200 L; water or goods, never both; rain 1 L a real minute at full rain in the open; a pipe from its foot runs as if its water stood 0.4 m deep (about half full; the network gives a tank one fixed head, as a cistern's 0.5 m).
- PV-7 Linked barrels (by any pipe, copper or wooden) level to one water surface, height respected; levelled at most every 3 real seconds while changing.
- PV-8 A barrel's bottom point feeds pipes out but takes no water in (it fills from above or by rain).
- PV-9 (Dave 19 Nov 20:31Z) A pipe is a row of segments, one per pack piece (Wooden 2 m, Copper 3 m) counted from the end it was laid from; each joint between them is a connection point. A tap or drip head fits on any end or joint not already taken, and a barrel set down with its bottom point within 0.6 m across (0.25 m up or down) of one moves so the middle of its bottom lands exactly on it (Dave 21:56Z); pipes and fittings keep no building gap (they lie through anything); a joint splits the run in two there (pieces shared, none made). A run's second click may be on the ground (or anything) within 6 m. Assumed: a junction made with the sliding start point measures its new half's joints from that point.
- PV-10 (Dave 19 Nov 20:31Z, "pipes without taps or drips do not leak any water") A pipe end with nothing on it is capped: no water leaves it. Assumed: an end laid right over a trough, trench or barrel top still pours into it, as before, because that water is caught, not lost (the irrigation trench is fed this way).

## 9. Pipes, taps and barrels (Dave, 19 Nov 2026), PROVISIONAL values

Dave, project chat 19 Nov 2026 (voice, read through the typos): 15:06Z wood is the original pipe, "big thick pipes like 6 inches around" that "break
down faster"; "copper would be the best and one copper it could make about 3 meters of pipe"; a pipe snaps to the end of another and pivots there
until a click sets it, "so we should be able to lay pipes out in any direction"; "a copper tap or a copper irrigation drip head"; copper pipes join
barrels to barrels, and "any barrels connected together would share their contents equally [...] like water does [...] if you added multiple
barrels". 15:08Z: "Pipes can be run anywhere so they can go through things so they would ignore collision". 15:11Z: with pipe in hand the barrels
show a glowing connection point at the bottom centre, every laid pipe lights up (bright blue) and is a connection point anywhere along it (a dot
slides along it where you look); the first click starts, a line follows you, green while the pipe in the pack covers the distance and red (blocked)
past it; a click on the next connection point lays the whole run, taking the pipes it needs from the pack; a barrel's point takes any number of pipes.

### 9.1 How it works

- **One model for every run.** Pipe is a pack item. With it in hand, the connection points show: the bottom centre of every barrel (a glowing
  ring), the base outlet of every trough and cistern, the spout of every well, and every laid pipe along its whole length (lit bright
  blue). Left click on one starts a run there. A line runs from that point to where you aim, at any angle and through anything (walls, ground,
  other pieces); it is green while the pack holds enough pipe for its length and you are in reach, red otherwise. The second left click lays it:
  on another connection point the run ends there; anywhere else it ends in the open at the aimed point (where a tap or drip head goes, or over
  a barrel, trough, plot or trench to pour in). Right click or Esc lets go of the start. This is Dave's pivot (the start is the fixed end, the run
  swings and tilts round it as you look) and his click-to-click run in one: the start always snaps, the far end snaps when it is on a point.
- **A run is one straight pipe** of any length up to 30 m (PV-3), paid in whole pieces: a wooden piece covers 2 m, a copper piece 3 m (Dave's
  "one copper [...] about 3 meters"). A 7 m copper run takes 3 Copper - Pipe. Taking a run down (hold E on it) gives back exactly what it took.
- **Junctions anywhere.** A run started in the middle of a laid pipe splits that pipe there (its pieces shared out, none lost or gained), so
  three pipe ends meet and the water splits or joins there as at a tee. That is why the elbows and tees are retired: any angle and any branch is
  a run. Ends that meet are sealed; an end joined to another pipe never spills into what is under the joint.
- **Wooden - Pipe**: a bored log 15 cm (6 in) across, 2 m a piece, 60 L/min under head, made by hand from 1 Log and 1 Twine with a knife kept
  (the old blueprint cost). It wears three times as fast as other wood: down to a quarter in 56 game days (building wear, about 2.3 real days),
  and a worn pipe leaks, carrying only its condition's share of its flow; a hammer repair (1 Log, 1 Twine share) makes it good again (PV-1).
- **Copper - Pipe**: 3 m a piece, 1 Copper ingot at the Primitive smithy, 180 L/min under head, never wears (PV-2).
- **Copper - Tap** (1 Copper ingot, Primitive smithy; Dave 19 Nov 2026 20:11Z): in hand, left click on a pipe's end or joint fits it there. "Press E
  to take a drink"; F opens its 3 slots, and a water container put there fills. Both work only while its pipes reach a water source that holds
  water, such as a barrel: the water comes out of that tank. It lets no water out otherwise (PV-4). It is not opened and shut (the first plan's
  open twin, state 460, is retired).
- **Copper - Drip head** (1 Copper ingot, Primitive smithy; Dave 19 Nov 2026 20:09Z): fitted on a pipe's end or joint the same way. While its pipes
  bring it any water it irrigates the soil in a circle of 10 m radius round it: every tilled bed and garden plot there is kept fully watered.
  It draws 2 L/min while water reaches it (PV-5).
- **Barrels hold water** (PV-6): 200 L, as well as their 8 slots of goods, but never both at once: a barrel with goods in it takes no water and
  one holding water takes no goods ("It holds water."). Out in the open (not under a roof or tree) a barrel catches rain: 1 L a real minute in
  full rain (its 0.25 m2 top at about 10 mm a game hour), less in lighter rain. A pipe end or open tap over its rim pours in. E at a barrel holding
  water drinks or fills the container in hand; one with no water opens as before.
- **Linked barrels level out** (PV-7): barrels whose bottom points are joined by pipe (copper or wooden, any number of runs and junctions) share
  their water so the surfaces stay at one height, like water does: rain into the outdoor barrel spreads to every barrel linked to it, and a
  barrel on lower ground fills before one higher up. The server levels a linked set only while its water is changing, at most every 3 real
  seconds, so it costs nothing while the water stands. A barrel's bottom point also feeds a pipe like a trough's outlet (to a tap, a drip head
  or a trough), but water never climbs into a barrel through its bottom (PV-8).

### 9.2 Catalog changes (Dave's rework; numbers in docs/mirror/tech/NUMBER_RESERVATIONS.md)

| Item | What happens |
|---|---|
| Wooden - Pipe (1352) | Kept, now a pack item made by hand (recipe 746), laid from the hand; the placed run keeps the `wooden_pipe` kind (state 423) |
| Copper - Pipe (1508, new) | Pack item, recipe 747 at the Primitive smithy; laid run state 458 |
| Copper - Tap (1509, new) | Pack item, recipe 748; fitted state 459 with 3 slots; `copper_tap_open` (state 460) retired before release, loads as the tap |
| Copper - Drip head (1510, new) | Pack item, recipe 749; fitted state 461 |
| Barrel (649) | Kept; also holds 200 L of water (above) |
| Wooden - Pipe elbow (1353), Wooden - Pipe tee (1354) | Retired (any angle and junctions anywhere replace them); a saved one loads as a 2 m Wooden - Pipe |
| Iron - Pipe (746), Iron - Pipe elbow (748), Tap (750, iron) | Retired (Dave: no iron or steel pipe); they were never buildable |
| Blueprints 342-344 (wooden pipes), 144-146 (iron pipes and Tap) | Retired: pipes are laid from the hand, not built with the hammer |

### 9.3 Not built here

Filling a bucket straight from a tap (put a barrel or trough under it); water climbing into a barrel through its bottom; a run that bends
(lay two runs); pipes over 30 m in one go (lay another from its end); freezing.

## 10. Gravity and rain water, no pumps (Dave's direction, 20 Nov 2026)

Dave, project chat 20 Nov 2026 22:04Z: "In my world we are still medievalish and using buckets in wells and dont have pump technology yet. the best
we be using gravity to move water from a barrel in a river to another barrel lower through copper pipes and then being able to use pipes to
distribute water from that barrel. the other idea would be to use barrels to collect rain water and through copper pipes distribute water to taps
and drip heads. we could also plumb into advanced cooking stations so they could draw water from the rain water and pipe system. does that make
sense. ultimately we would end up with people building and pumbing rain water systems."

The ruling: water moves by gravity only, from wells by bucket, from a barrel in a river, or from rain barrels, through pipes to lower barrels, taps,
drip heads and possibly advanced cooking stations. No pump technology for now. He asked whether it makes sense; the proposal below answers it.

Against dev (41415196), the proposal put to Dave:

- Already works as he describes (section 9): rain fills a barrel in the open; linked barrels level out and a lower barrel fills first; a barrel's
  bottom feeds copper or wooden pipes to Copper - Taps and Copper - Drip heads; a pipe end over a barrel, trough, plot or trench pours in.
- Missing: a barrel stood in a river or stream does not take water from it (a river intake); no cooking station draws piped water.
- Pumps in the catalog: the Iron - Hand pump and the Deep-well pump (both locked, never buildable), the Raised cistern (locked; only a force pump
  fills it) and the Wooden - Hand pump (live now). Proposed: retire all four (narrowed by Dave, below).
- **Decided (Dave, 20 Nov 2026 22:06Z, "Retire all pumps"):** the Iron - Hand pump, the Deep-well pump and the Wooden - Hand pump are retired
  (numbers kept; retired in the data by the pump PR). Dave, 20 Nov 2026 22:42Z: "the wooden hand pumps should be gone too. I did not approve
  ever having those. they were an ai accident." A pump standing in a saved world is cleared when the world loads and leaves its materials on the
  ground where it stood (a site leaves what had been put into it). Water comes from rain, from wells by bucket and from river barrels (below).
- **Cisterns stay (Dave, 20 Nov 2026 22:06Z):** "the cistern can be copper lined and the frame can be made of wood and iron nails etc. cisterns are
  not pumps"; 22:07Z "they are just big tanks". Proposed for a later PR (our reading, for Dave to confirm): the Raised cistern becomes a big tank
  that behaves like a bigger barrel in the pipe system, copper lined on a wooden frame with iron nails, filled by gravity (a pipe from a higher
  barrel) or by rain and feeding pipes from its bottom, with no riser or force pump; cost and size provisional.
- **Next (Dave, 20 Nov 2026 22:42Z):** "yes make the cistern, the river barrel is just a barrel that sits in a river and fills up with river water
  gradually. it will have a fill speed that is pretty fast and it can have copper pipes attached. the pipes need to run down hill because they are
  gravity fed." Order: the cistern as a big tank, then the river barrel; advanced cooking stations drawing piped water later.
