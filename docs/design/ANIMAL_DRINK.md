# Animals and drinking (MikeW, 8 Nov 2026)

The client side of Steve's drinking water design (#719, `docs/design/drinking_water_design.md`) and Sonny's springs research
(`docs/water/springs_and_drinking_water.md`). Behind `drink_looks` (off). It reads only what the client already has: the server's
animal positions and states, and the existing `water_level` (water_life's drinking spot). Steve's `water_source(pos, reach_m)` is a
server callable (spring, brook, river, lake, wet ground; never salt; ice needs a hole); the client does not sample water itself.

## What animals do
- **Herds walk to water at dawn and dusk**, to springs (always a drink: Sonny's spring water is the year mean plus 1 C, 6.5 C at
  cave 8002, never frozen) and to pool and brook edges. That is movement: a server step (requests below).
- **The drink:** head down, a few sips, a pause, the head lifted to look round, then down again.
- **Used spots** get tracks and a churned, trampled bank.
- **Birds bathe** in shallows: they stand in the edge and beat their wings, throwing water.
- **Wolves wait near water at dusk**, where the prey must come (server).

## In the game (flag `drink_looks`, with `water_life` for the drinking spot)
| Look | How (`_drink_look`) |
|---|---|
| Sip and look round | while water_life's drinking spot is set (grazing with water just ahead of the muzzle), every 6 to 14 s the head lifts for 1.5 to 3 s (the look bones' glance), then the graze clip carries on (head down) |
| Churned bank | the first drink at a spot lays a trampled patch at the drinker's feet, in the animal-sign pool (ground "mud", three game days), with `animal_sign` on; tracks there are animal_sign's own |
| Birds bathing | a bird with a flight row standing in water under 30 percent of its height: a 0.8 s burst of its flap clip at double speed with small splashes, every 4 to 9 s |

## Requests to Steve (server; no client sampler)
1. **To water at dawn and dusk:** herds (deer, stock) set their target to the nearest `water_source` within a few hundred metres at
   dawn and dusk (springs first, by its order), stand there grazing for a few minutes (state 0, so the client's drinking spot lights
   up when the water is ahead of the muzzle), then go back.
2. **Wolves at water at dusk:** a pack's dusk wait point at a drinking place of its prey.
3. **Optional:** a drinking state (the client can map it to the drink with no water probe), if he prefers it to the grazing stand.
Nothing here reads `water_source` on the client; if he sends a drinking state, that is the one new thing the client reads.

## Check
Run sheet m55 (a deer drinking at a bank: head lifting between sips and a trampled patch; a crow in 5 cm of water bathing) and
DINO_SHOTS.md.
