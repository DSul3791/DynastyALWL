# Ocean and digging on the beach (Guru first view, 2026-10-23 01:10; Sonny and Steve refine, then Yes/No cards for Dave tomorrow)

Dave's question: if a player digs on the beach, should the ocean flow in?

Guru recommendation (simple rule, cheap to simulate):
1. The sea is a fixed boundary at sea level (an endless source, never drains). Land above sea level never floods by itself.
2. A hole dug on the beach that goes below sea level and connects to the sea (through open ground or sand) fills up to sea level, like a real beach pit. Water level in the pit = sea level.
3. How far it spreads: only into cells that are below sea level AND connected to the sea. So a flat beach just above sea level gives only a shallow pool; a deep trench far inland stays dry unless it reaches a below-sea-level cell that is connected.
4. Players can dam it back: filling the connecting cells with soil, sand or stone cuts the connection and the pit stops being "sea water" (a cut-off pit keeps its water as an ordinary puddle that evaporates or is bailed out). Tunnels under the sea: sea-level connection means they flood (collapse design note: flood = death, existing river-flood rule applies).
5. Rivers meeting the sea: the river outlet sits at sea level; the river just ends in the sea; tides are not simulated (later idea).
6. Sim cost: the sea is a boundary condition, not simulated cells. On every dig edit near the coast we recompute a connected "below sea level" patch (small flood fill, local). No per-tick work for the open sea.
7. Safety: cap the flood fill per edit (for example 200,000 cells) so one dig can never stall the server; beyond the cap the dig is refused with a plain message.

Open choices for Dave (Yes/No cards, tomorrow): (a) endless sea source that fills beach pits to sea level? (b) pits cut off by a dam keep their water as a puddle? (c) tunnels or rooms below sea level that connect to the sea flood and kill like river flood? (d) tides later, not now?

## Joint recommendation (Guru + Sonny, merged 2026-10-23; supersedes OCEAN_DIG_NOTE.md; Steve to confirm the sim parts)
Agreed: sea = endless source at 0 m, only ground below 0 m connected to the sea floods, dam cuts it off (cut-off pit keeps water as a puddle), flooded tunnels kill like river flood, no tides now, cost small, flood fill capped per edit (Guru: 200,000 cells).
Sonny adds:
- Feed rate cap per connection (recommend 50 m3/s) so a huge pit fills over minutes instead of instantly; the cell cap stops stalls, the rate cap stops pops. Two separate limits.
- River mouths: the baked estuary (last 160 m, bed below sea level) is sea-connected, so damming a mouth floods the river behind it (intended risk, a real dam rule).
- Far water: flooded beach pits count as changed cells in the far layer (FAR_WATER_NOTE).
- Open question for Steve: today the sim drains into the sea but, I believe, does not feed from it; a sea boundary link is needed for dug cells (runtime, server restart).
Cards for Dave (Yes/No, each recommended Yes): (a) endless sea source fills beach pits to sea level; (b) a dammed-off pit keeps its water; (c) tunnels below sea level connected to the sea flood and kill; (d) feed-rate cap so big pits fill over minutes; (e) tides later, not now.

## Systems check of the sim (Steve, 2026-10-23, read from src/water/water_sim.gd)
- Sonny is right: the sim DRAINS into the sea, it does not FEED from it. Cells with ground at or below 0 m are "sea": held at sea level, no cell of their own, and the face code says `q = 0.0  # the sea never flows back onto land` when the flow would run from a sea cell onto land. Water that reaches them is only counted in `sea_m3`.
- A second trap for beach digs: a dug cell whose ground drops to 0 m or below becomes a SEA cell by that rule. So a pit dug below sea level beside the water would act as a drain (water poured in disappears), not as a pit that fills with sea water.
- Needed: a sea boundary link. Recommendation: (1) a sea cell next to a land cell whose water level is below 0 m feeds it (flow capped, 50 m3/s per connection as Sonny proposes); (2) a land cell with ground below 0 m is a normal cell (not sea) unless it is connected to the sea by below-sea-level cells, in which case it fills to 0 m; a cut-off pit keeps what it has; (3) the feed uses the same _face maths with the sea height fixed at 0 m, so no new physics; (4) cost: only cells within the dig's wake are awake, cap one dig's wake at about 200,000 cells as Tyler says. This is a RESTART server change in water_sim.gd (Sonny's area) plus a test; I can write the sim change with Sonny's review, or he can: his call.

## Building out into the sea: islands, piers, fortress (Dave 01:09; Guru first view, Sonny and Steve add the sim parts)
1. Islands by fill: YES. Raise mode (spade, shovelfuls from the pack) and later barrows or builders may place soil, sand, gravel, clay or stone into shallow sea. Each shovelful is a real piece of ground, so a big island costs a lot of material and time: that is the natural limit.
2. Depth limit for fill: about 4 m of water (shallow sea near the shore). Deeper water cannot be filled by hand; it needs pillars (point 4). The limit is a number in data.
3. Displaced water: the sea is a boundary at 0 m, so water pushed out by fill simply vanishes into the sea. Fill that rises above 0 m becomes dry land. A new island needs a top at least 0.5 m above sea level to keep dry (the blueprint foundation rule: a foundation needs level ground, see the foundation answer).
4. Piers like Valheim: YES. A pier is pillars driven into the seabed (pillars anchor to the ground, stack, act like foundations and connect 3 spaces out, per Dave's 00:00 answer) with foundations, floors and walls on top; pillar stacks reach the seabed in deeper water. A pier above water counts as normal building.
5. A fortress on your own island: YES, once the island is dry land with foundations on it. Load limit and blueprint rules apply as on land.
6. Who: every player in their own town area; no special permission. Optional later: claims and protected zones. Costs: material only (no coin cost).
7. Sim cost: fill into sea is an ordinary edit; the sea boundary needs no cells; the flood fill stays capped per edit.
Cards for Dave tomorrow (Yes/No, each recommended Yes): (1) islands by filling shallow sea with soil, sand, gravel, clay or stone; (2) fill allowed up to about 4 m of water, deeper only with pillars; (3) displaced water just vanishes into the sea; (4) piers built from pillars driven into the seabed with floors on top; (5) fortresses and towns on your own island with the normal blueprint and load rules.
