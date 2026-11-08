# Animals on ice, and the ice look's server asks

**Owner:** Steve, for `server_animals.gd`, `server_wolves.gd`, `server_items.gd` (holes and moat) and the `ice_holes` message.
**Asked by:**
- MikeW, `docs/design/ANIMAL_WEATHER_LOOKS.md` (ice section): deer and boar skirt frozen ponds, wolves cross them, birds stand on the ice at open-water edges;
- Kathleen, `docs/design/frozen_water_look.md` (#729) section 9: holes to the client, the thaw moat, and the frozen brook check (that one is in #720).
**Decided:** coordinator, 8 Nov 2026 (yes to all three of Kathleen's asks). Dave may revert.
**Status:** animal moves behind `animals.json` `ice.on` (off). The hole message (protocol 97) and the moat hook are live but quiet: nothing draws the holes until the ice look connects, and nothing wires the moat until Kathleen's `Ice.season` lands. Static checks only.

## 1. What happens today (read from the code, 8 Nov; not tested)

- **Ice:** the server's ice is `Ice.cover` at a 3 m pond depth (`server_items.ice_cover_at`): 0 open water, 1 a 20 cm sheet. Players need cover 0.5 (10 cm) to stand on it (`_on_ice`), and a hole to fish or drink there.
- **Animals ignore ice.** Water over 0.7 m deep blocks them (`blocked`), and shallower water is waded.
- **Holes:** a hole is `{pos, owner, until}` in `server_items._holes`. It is never sent to clients.
- **No moat:** a thaw has no moat on the server.
- **On the starter island the ice never bears** (Kathleen #729: 2.8 cm at the spawn pond, 5.6 cm at spring #8002). The physics stays honest, so there:
  - starter ponds only get skim;
  - no hole can be cut (the cut needs a bearing sheet, `say_no_ice`);
  - wolves never cross.
  - Only the deer's skirting shows.

## 2. What the player will notice (flag on)

- **Deer and boar walk round ice** of skim or more (2 cm, cover 0.1), even over shallows they would wade on an open day. Elk, moose, chamois and pronghorn go round too, since they share the deer role.
- **Wolves cross a sheet that bears** (10 cm), walking at the ice's surface over deep water. So in a hard winter a pack takes the short way over a lake. Thinner ice over deep water still stops them.
- **Ducks, geese and seabirds on a frozen pond** stand on the ice 2 m back from the nearest open water, such as a moat or an unfrozen patch within 40 m. A pond frozen all over has no flock.
- **The thaw moat is open water:**
  - a player standing in it is not on ice (`_on_ice` false), so they drink there without a hole;
  - a wolf does not cross it.
  - The walk itself (the collider) is the client's, Kathleen's `flora_view._draw_ice`.

## 3. The rules

1. **The ice at a point** (`ice_at(x, z)`):
   - 0 on dry land or in the moat (`ice_moat_at`);
   - otherwise `Ice.cover` at the water's surface.
   - `Ice.cover` runs an hourly loop over weeks, so it is kept per 1 km band of z and 5 m of height for `cache_s` 60 real seconds.
2. **Skirting** (deer role, plus `skirt_species` boar and warthog): the walker's block is "deep water, or ice of `skirt_cover` 0.1 or more".
3. **Crossing** (`cross_species`, the wolf, in its own walks, its pack walks and its den walks):
   - its ground is the water's surface where the ice bears (`bears_cover` 0.5);
   - its block is deep water only where the ice does not bear.
4. **Flocks:** when a water flock is about to settle on ice of `bird_cover` 0.25 (5 cm) or more, it looks out to `edge_search_m` 40 m for open water, in 8 directions and 4 m steps. It settles `edge_back_m` 2 m back from the first open water it finds, on the ice. With none, it does not settle.
5. **Swimmers** (the moose, the beaver) keep their swim rules. Ice under a swimmer is left for later.

## 4. The ice holes to the client (protocol 97)

- **Message:** new rpc `ice_holes(points: PackedVector3Array, untils: PackedFloat32Array)`. It carries up to 8 live holes within 120 m, nearest first, and the game second each stays open until.
- **When it is sent:** reliably, in the same per-player pass as nests and burrows, whenever the set changes (a hash, as theirs).
- **Client side:** `terrain_net` emits `ice_holes_received`. Kathleen's look turns `until` into an age with `fishing.json` `ice.hole_game_h`.
- **Why a new message:** there is no weather message to fold it into, because the client works the weather out from the seed. So this is a new message and a protocol bump (97), with a `PROTOCOL.md` row.

## 5. The moat

- **The hook:** `ice_moat_at(pos)` on both `server_items` and `server_animals`. When it says yes, the point is open water: `_on_ice` is false and the animal ice is 0.
- **Not wired yet:** the moat needs `thaw`, which comes from Kathleen's `Ice.season` (#729, section 6). When that lands, the terrain server wires the hook with her rule: water shallower than 1.6 × thaw m, at the point's depth.

## 6. Tests (static checks only in the cloud; run on Dave's PC)

New `test_animals_ice.gd`, with a stub pond (shallow to x 150, deep beyond):
- **Flag off:** nothing.
- **Skirting:** a deer and a boar are blocked by skim in the shallows, and wade open shallows.
- **Crossing:** a wolf crosses a 12 cm sheet over deep water at the surface, and is blocked by 6 cm.
- **Moat:** it stops a wolf, and `_on_ice` is false in it.
- **Flocks:** a flock on ice stands at the open water's edge. A pond frozen all over has none. On open water it floats where it was.
- **Holes:** `ice_holes_near` gives live holes within 120 m, nearest first, with their closing time.
