# If a player digs on the beach, does the ocean flow in? (Dave 2026-10-23 01:08) Draft by Sonny_WorksDep; Tyler_Guru and Steve_ProblemSolver to add their parts, then cards.
## What exists
The sea is a fixed level (0 m, with tide ease in the draw) and an unlimited drain for rivers. Ground below 0 m next to the sea is baked as ocean. Dug ground below 0 m is not.
## Recommendation (each line a Yes/No for Dave)
1. The sea is an unlimited SOURCE at sea level for the live sim: any dug cell connected to the sea and below 0 m fills to 0 m. Recommend Yes (a trench to the beach floods like real life; players can dig harbours and canals).
2. Inland reach is limited by the ground height only (water stands at 0 m, so it can only fill ground below 0 m); no extra rule. Recommend Yes. Beaches sit at 0 to 2 m so most digs flood only a few metres in unless dug below 0.
3. Players can dam it back (build a wall or fill with earth above 0 m): water already inside stays as a pond at 0 m, the sea stops feeding it once the connection is cut. Recommend Yes (natural result of the sim, no special code).
4. River mouths: the river's last stretch (estuary, bed under sea level) stays baked as sea-connected, so tide and river meet at 0 m; a player damming the mouth raises the river behind it (flood), which is the intended risk. Recommend Yes.
5. Sim cost: the sea is a boundary, not simulated cells; only dug/flooded cells near the beach join the live sim, and the 4 live tile limit still applies. Cost is small; the risk is a very long trench draining the whole bay into a big pit (cap: the sea feeds at most N m3/s per connection, recommend 50 so a huge pit fills over minutes, not instantly). Yes/No for the cap: recommend Yes.
6. Persistence: dug beaches and the water standing in them are saved like other edits; far water layer treats them as changed cells (FAR_WATER_NOTE).
## For Tyler and Steve to answer
- Steve: does the native sim already treat sea cells as a fixed 0 m source, or do dug cells need a new boundary link? (Sonny's belief: it drains into the sea today but does not feed from it.)
- Tyler: does any approved design (survival, boats, tides) assume the sea never floods land?

## Tyler_Guru answer (01:12)
No approved design assumes the sea never floods land: survival (swimming, oxygen bubble 60 s, river-flood YES, fall-channel YES), ocean ice (breaks into floating chunks, you can fall in or swim) and the tunnel collapse design only talk about rivers and ponds. Boats and tides are not designed yet. Two additions: (a) a tunnel or room dug below 0 m that connects to the sea floods, and the existing river-flood drowning rule applies (oxygen bubble 60 s); this needs a plain warning when digging below sea level next to the coast (a screen line like "Water seeps in here"); (b) the 50 m3/s cap is a tunable number in data (not hard-coded). All 6 lines approved by Guru as recommendations; they go to Dave as Yes/No cards tomorrow (CARDS_TOMORROW.md).
