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
- There is no wooden pipe, no iron pipe tee, and no E toggle for the Sluice or the Tap.

So the work is: wire the catalog pieces to the engine, add the missing pieces, and unlock each piece only once it works.

## 2. How water flows

source (well, hand pump, deep-well pump) -> conduits (channels: open, downhill only; pipes: closed, carry under head) -> tanks (troughs,
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
   Wooden - Hand pump, and new Wooden - Pipe / Pipe elbow / Pipe tee (bored logs: the first closed pipe). Unlocked.
3. **Stone channels, cisterns** (the same data conversion). Unlocked, except the Raised cistern: only a force pump fills it, so it
   stays locked until iron plumbing brings the Deep-well pump. **Clay plumbing is retired** (Dave, 14 Nov 2026: "I don't think clay plumbing
   would make sense. We should remove clay plumbing altogether."): Clay pipe (730), Clay - Pipe (740), Clay - Pipe elbow (742) and
   Clay - Pipe tee (744) are retired with their numbers kept, blueprints 141-143 retired, structure states 179-181 retired (rows kept for their numbers, no look or water block), the Clay pipe
   recipe (352) retired; a saved Clay pipe loads as Clay. Closed pipe is the Wooden - Pipe (PR 2) until iron.
4. **FUTURE, deferred (Dave, 14 Nov 2026: "finish up what you're working on, but put the rest aside under future"). Not built.**
   **Iron plumbing, gated on the Master smithy.** A new material, Iron pipe section, forged only at the Master smithy (learned there by
   discovery); Iron - Pipe / Pipe elbow / new Pipe tee, Tap (E toggle), Iron - Hand pump and Deep-well pump cost it. Unlocked once the
   recipe exists, so the gate is the Master smithy itself.

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
the Iron saw, so they arrive at the iron stage; the Advanced well also needs Bark shingles and twice the stone.

The Improved and Advanced windlass hauls a 10 L bucket: at 5 m down about 52 L a real minute, so a full Improved well (200 L) is drawn in about four
real minutes. The Primitive well's 3 L clay pot gives about 16 L a minute there, so its 100 L take about six. Each is full again a game day (one real
hour) later. Wells are a source of clean water and keep the engine's 4-sources-a-chunk limit.

Goals: `build:stone_well` (Build Well) keeps its id; its title follows the rename. Goals for the two new wells belong to the goals thread.

## 5. Wooden plumbing (PR 2), PROVISIONAL values

| Piece | Water block | Cost |
|---|---|---|
| Wooden - Hand pump (unlocked) | suction source, 7 m (less 1 m per 1,000 m up), 0.8 L/s at 40 W: 48 L/min at 4 m; spout 0.7 m up, 0.27 m to +Z | unchanged |
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
- What a player does: build a well or hand pump, lay channels from its spout downhill to a trough, open the sluices, and work the pump (E).
  Drink or fill a container at the trough (E). Lay log pipes from a trough's base downhill to another trough.

## 6. Stone channels and cisterns (PR 3), PROVISIONAL values

| Piece | Water block | Cost |
|---|---|---|
| Stone - Channel / corner / tee | open, 300 L/min, ends 0.13 m up, 1 cm fall a piece, catches like a flume | unchanged |
| ~~Clay - Pipe / elbow / tee~~ | retired 14 Nov 2026 (Dave: remove clay plumbing altogether); a closed run uses the Wooden - Pipe | - |
| Stone - Trough | tank 200 L, rim 0.58 m, base outlet like the wooden trough | unchanged |
| Cistern | tank 2,000 L; catches over its 1 m rim from up to 1.2 m across and 2 m above; base outlet at +Z; its water stands 0.5 m over the outlet (`head_m`), so a level log pipe from it runs at about half cap | unchanged |
| Raised cistern (locked until iron plumbing, FUTURE) | tank 2,000 L on a 2 m plinth; outlet at its foot with the tank 2.5 m over it (a level pipe runs full); fills only through its riser at the foot (-Z) from a pipe whose water surface reaches its top (`lift_m` 2.85: a force pump, iron plumbing, FUTURE), never from a hand pump | unchanged |

Engine additions (water_network.gd): a tank's `head_m` (its water over its base outlet) and `lift_m` (a riser-fed tank takes water only from a
surface that high over its inlet). The cisterns' "overflow" is not modelled: a full tank backs up, as the engine already does.

## 7. FUTURE: iron plumbing (deferred, not built), PROVISIONAL design

**Deferred 14 Nov 2026** (Dave: "Regarding the plumbing finish up what you're working on, but put the rest aside under future"). Nothing below
is in the game. The design is kept so it can be picked up later; a working implementation of it was reviewed (gate PASS) but never merged, and
sits in the project Library bundle `plumbing/plumbing-stack.bundle` (branch `plumbing-iron`) (it predates the clay retirement, so it needs
rebasing and its clay references removed). The plumbing number block's unused numbers are released (docs/mirror/tech/NUMBER_RESERVATIONS.md),
so a revival takes fresh numbers for the Iron pipe section, Iron - Pipe tee, the Tap's open twin and the forge recipe.

**The gate is the Master smithy.** The pieces are known from the start and need an iron hammer (tier 3). Every one of them costs the new
material **Iron pipe section** (new item, number to reserve). It is forged only at the Master smithy (`master_forge`, station `master_smithy`) by a new recipe:
1 Iron ingot gives 2 sections in 20 s. It is learned by discovery, the first time an Iron ingot is in the pack at the Master smithy.

| Piece | Water block | Cost |
|---|---|---|
| Iron pipe section (new material) | none | the recipe above |
| Iron - Pipe / elbow (unlocked) | closed, 240 L/min under head, ends 0.1 m up | 2 Iron pipe sections each |
| Iron - Pipe tee (new) | closed, 240 L/min, one inlet and two outlets | 3 Iron pipe sections |
| Tap (unlocked) | a closed 30 L/min gate on a pipe's end; built shut, E opens and shuts it (open twin `iron_tap_open`); its spout is 0.22 m up, so a trough under it stands lower | 1 Iron pipe section, 1 Hinges |
| Iron - Hand pump (unlocked) | suction source, 7 m, 1.2 L/s at 50 W (72 L/min cap); spout 0.76 m up | 2 Iron pipe sections, 4 Iron ingot, 1 Hide, 1 Hinges |
| Deep-well pump (unlocked) | force pump, lifts from 40 m, 1.0 L/s at 60 W, closed outlet pushing 10 m up an iron pipe (fills a Raised cistern) | 4 Iron pipe sections, 4 Iron ingot, 2 Hide, 2 Hinges, 12 Nails |

What a player does once the Master smithy stands: forge Iron pipe sections there, build a Deep-well pump, lay iron pipe from it to a Raised cistern's
riser, work the pump (E), and run iron pipe from the cistern's foot to Taps over troughs around the village. Open a Tap with E.

Engine addition (water_network.gd `_capped`): a closed outlet joined to a closed piece's inlet (the next pipe, a Tap) pours nowhere else, so a
pipe's end under a shut Tap does not spill into the trough below it; order-independent (`add` drops such a spill when the cap comes later).

Not modelled (PROVISIONAL): the catalog's Deep-well pump "for a stone well" (the old data's `"on": "stone_well"`) is not enforced; it lifts
ground water within 200 m like any well or pump. The Tap is placed freely (no snap to a pipe port): its inlet must land within 0.3 m of a pipe
end, a play check on the PC. The Raised cistern would be unlocked with it, once the Deep-well pump can fill it.

## 8. Assumed on Dave's behalf, for his review

Every value below is PROVISIONAL (coordinator ruling: build costs and numbers may be assumed and tuned later). Reasoning in the sections named.

- P-1 Well yields 100 / 200 / 600 L a game day, at about 20 L a person a day (s4); Primitive reaches 6 m, Improved 25 m, Advanced 40 m.
- P-2 Primitive - Well: 8 Log, 4 Twine, 1 Clay - Pot; hauls a 3 L pot, so it is first-day work (s4).
- P-3 Advanced - Well: 60 Cobblestone, 16 Clay mortar, 12 Plank, 4 Log, 16 Bark shingle, 2 Rope, 2 Bucket; 3.2 m round, hammer 1 (s4).
- P-4 Improved - Well is the existing `stone_well` renamed (coordinator-approved), cost unchanged; windlass bucket 10 L (s4).
- P-5 Wooden channels 120 L/min with a built-in 1 cm fall a piece; Wooden - Trough 100 L with a base outlet; Sluice built shut, E toggles (s5).
- P-6 New Wooden - Pipe / elbow / tee: closed bored logs, 60 L/min under head; 1 Log + 1 Twine (tee 2 Log + 1 Twine) (s5).
- P-7 Wooden - Hand pump 0.8 L/s at 40 W (48 L/min at 4 m) (s5).
- P-8 Stone channels 300 L/min; Stone - Trough 200 L (s6). (Clay pipes retired by Dave, not assumed.)
- P-9 Cistern 2,000 L, 0.5 m head; Raised cistern 2,000 L, 2.5 m head, filled only by a force pump, so locked until iron plumbing (s6).
- P-10 A saved Clay pipe loads as Clay (renames.json): nothing else uses it, and its recipe took 3 Clay for 2 (s3).
- Iron plumbing values (s7) are FUTURE and unreviewed by Dave: Iron pipe section 1 Iron ingot for 2 at the Master smithy; Iron - Pipe and elbow 2
  sections, Pipe tee 3, 240 L/min; Tap 1 section + 1 Hinges, 30 L/min; Iron - Hand pump 72 L/min; Deep-well pump lifts 40 m and pushes 10 m.
