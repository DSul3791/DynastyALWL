# Whales and dolphins at sea (MikeW, 8 Nov 2026)

Both are Meshy models for Dave (MISSING_MODELS_BRIEF.md has the model brief). The game has seals and seabirds on the coast but nothing
out at sea. This note is the code path; the client part is built behind `sea_life` (off), the server part is for Steve.

## Server (Steve)
- **Dolphin pod:** one record is a pod (a flock row like the duck's: `flock_of` [3, 10], `spread_m` 4). It lives in sea water deeper
  than 4 m within 600 m of the shore, swims along the coast at 2 to 6 m/s at 0.5 m under the surface, and in state 1 (travelling
  fast) runs in bounds (the client's hop arc draws the porpoising). A boat later: the pod comes to the bow within 100 m.
- **Whale:** one record, deeper than 30 m and beyond 800 m from the shore, seen from the coast. Swims slowly at the surface for 1 to
  3 minutes (blowing), then dives for 5 to 15 (out of sight, not sent). A rare breach as a one-shot event.
- **Events:** `breach` (whale), `leap` (dolphin, one bird of the pod) and `dive` as one-shot events like the raven roll; the client
  plays the row's `sea.breach`, `sea.leap` or `sea.dive` clip once.
- Both are harmless and not huntable in this version. The swim height comes from `swim_height` (the alligator's), at the sea surface.

## Client (built, flag `sea_life`)
- They swim on their `swim` clip through the existing swim block (a row with `swim` plays it whenever the body is below the water).
- `_sea_blow`: every `sea.blow_every_s` (whale 20 to 60 s, dolphin 8 to 20 s), within 1.5 m of the surface, a white spout rises
  `sea.spout_m` (whale 4 m, dolphin 0.6 m) and falls back. One particle burst, freed after 2 s.
- The dolphin's `hop.run` (bound 6 m, arc 1.2 m) makes the pod porpoise at speed with no new code.
- Not built: playing the breach, leap and dive clips on the server's events (needs the events), and the bow-riding (needs boats).

## Bats (BAT_RIG.md, for the same Meshy batch)
- The colony's day roost under a cave roof, the dusk exit and dawn return are Steve's (BAT_RIG.md 2).
- Client, built behind `swarm_fx` (off): `_swarm` keeps each bat on its own slow loop round its place in the colony while flying, so
  the swarm boils; at rest with `roost_flip` each bat hangs head down from the roof point. A roost clip, if the file has one, plays
  under it.
