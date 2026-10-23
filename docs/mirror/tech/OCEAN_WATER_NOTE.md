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
