# Animals on ice, and the ice look's server asks

**Owner:** Steve, for `server_animals.gd`, `server_wolves.gd`, `server_items.gd` (holes and moat) and the `ice_holes` message.
**Asked by:**
- MikeW, `docs/design/ANIMAL_WEATHER_LOOKS.md` (ice section): deer and boar skirt frozen ponds, wolves cross them, birds stand on the ice at open-water edges;
- Kathleen, `docs/design/frozen_water_look.md` (#729) section 9: holes to the client, the thaw moat, and the frozen brook check (that one is in #720).
**Research:** Jamie, `docs/knowledge/animals-on-ice-and-snow.md` (#736): ice strength by mass, the per-animal table, deer on bare ice, water birds at the edge.
**Decided:** coordinator, 8 Nov 2026 (yes to all three of Kathleen's asks; Jamie's rule for the ice). Dave may revert.
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
- **Lighter animals cross ice that holds them for sure** (Jamie's rule, below), walking at the ice's surface over deep water.
  - Foxes and hares cross the starter island's skim (2.8 cm).
  - A wolf needs 6.7 cm, so in a hard winter a pack takes the short way over a lake, but never on the starter island.
  - Thinner ice over deep water still stops them.
- **Ducks, geese and seabirds on a frozen pond** stand on the ice 2 m back from the nearest open water, such as a moat or an unfrozen patch within 40 m. A pond frozen all over has no flock (Jamie #736: water birds stand at the ice edge by open water, and leave a pond that is frozen over).
- **The thaw moat is open water:**
  - a player standing in it is not on ice (`_on_ice` false), so they drink there without a hole;
  - a wolf does not cross it.
  - The walk itself (the collider) is the client's, Kathleen's `flora_view._draw_ice`.

## 3. The rules

**Ice strength** (Jamie #736, from the Minnesota DNR table): with h the ice thickness in cm (Ice.cover × 20),
- ice holds an animal of mass m kg for sure if m ≤ 0.9 × h² (`sure_k`);
- it breaks if m > 3.5 × h² (`break_k`), with a chance in between;
- halve h for white (snow) ice and near springs and inflows.

| Animal (game species) | Mass | May hold (3.5 h²) | Holds for sure (0.9 h²) |
|---|---|---|---|
| Raven (`crow`) | 1.2 kg | 0.6 cm | 1.2 cm |
| Hare (`rabbit`) | 3.5 kg | 1.0 cm | 2 cm |
| Fox | 6 kg | 1.3 cm | 2.6 cm |
| Roe deer | 25 kg | 2.7 cm | 5.3 cm |
| Wolf | 40 kg | 3.4 cm | 6.7 cm |
| Sheep | 60 kg | 4.1 cm | 8.2 cm |
| Person | 80 kg | 4.8 cm | 9.4 cm (the 10 cm rule; `_on_ice`'s cover 0.5) |
| Red deer hind, boar | 90 kg | 5.1 cm | 10 cm |
| Red deer stag | 150 kg | 6.5 cm | 13 cm |

So the starter ice (2.8 to 5.6 cm) carries birds, hares and foxes. It may carry a wolf or a roe deer, and never red deer, boar or people.

1. **The ice at a point** (`ice_at(x, z)`):
   - 0 on dry land or in the moat (`ice_moat_at`);
   - otherwise `Ice.cover` at the water's surface.
   - `Ice.cover` runs an hourly loop over weeks, so it is kept per 1 km band of z and 5 m of height for `cache_s` 60 real seconds.
2. **Animals keep off doubtful ice** (judged). They step only on ice that holds them for sure, so the chance band is not used for animals yet. It is the band for a future break-through.
3. **Skirting** (deer role, plus `skirt_species` boar and warthog): the walker's block is "deep water, or ice of `skirt_cover` 0.1 or more".
   - Jamie: deer on bare ice fall and stay down, one fall in three running strides.
   - They also weigh 90 kg, more than any ice on the island holds.
4. **Crossing** (any other species in `mass_kg`; the wolf in its pack and den walks too):
   - its ground is the water's surface where the ice holds it for sure (`ice_holds`);
   - its block is deep water only where it does not.
   - `mass_kg`: crow 1.2, rabbit 3.5, fox 6 and wolf 40 come from #736. Duck 1.1, goose 4 and seabird 1 are judged.
   - Species not in the table keep the plain rules.
5. **Flocks:** a water flock about to settle on ice that holds one of its birds looks out to `edge_search_m` 40 m for water whose ice would not (open water or skim it swims through), in 8 directions and 4 m steps. It settles `edge_back_m` 2 m back from the first such water it finds, on the ice. With none, it does not settle.
6. **Swimmers** (the moose, the beaver) keep their swim rules. Ice under a swimmer is left for later.

**Left out, for later steps:**
- **Halving h for white ice and near springs:** the server has no snow on ice and no spring positions yet (#719 step 2, Sonny's snow window).
- **Wolves chasing deer onto ice, and deer falling there:** needs the fall state and the client's pose first.
- **Snow:** sinking (a coyote-like animal 9.5 cm, a lynx-like one 7.7 cm, deer belly-deep and hampered over 50 cm), predators using packed trails about half the time, and snow building on a standing animal's back over 15 to 30 game minutes. All of these need lying snow on the server, from Sonny's A4 snow window.

## 3b. By springs (Jamie #739)

- **The rule:** a spring never freezes. Its brook stays open for Jamie's open length (440 m × √(L/s) at −5 °C calm, in #720's `drink_rules.open_length_m`), and ice is half as thick within 10 to 30 m of a spring mouth or an inflow.
- **The hook:** `spring_ice_x(pos)`, on `server_animals` and on `server_items._on_ice`, multiplies the ice cover: 0 on the open brook, 0.5 near a mouth or inflow, 1 elsewhere.
- **Not wired yet:** it waits for #719 step 2's baked spring rows.
- **The effect:** the open water below springs is open to the flock search, so water birds gather there in a freeze. Wolves do not walk on it.

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
- **Mass rule:**
  - 2.8 cm holds a fox over deep water, not a wolf (0.9 × 2.8² = 7.1 kg);
  - a wolf crosses a 12 cm sheet at the surface, and is blocked by 6 cm.
- **Moat:** it stops a wolf, and `_on_ice` is false in it.
- **Flocks:** a duck flock on ice stands at the open water's edge. A pond frozen all over has none. On open water it floats where it was.
- **Holes:** `ice_holes_near` gives live holes within 120 m, nearest first, with their closing time.
