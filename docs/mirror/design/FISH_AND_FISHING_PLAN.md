# Fish schools and fishing: design plan

**STATUS: FINAL (Dave answered YES to all 5 cards, 24 Oct 2026).** Decisions:
1. Species list in section 1 is approved (salmon and trout in rivers; herring to tuna in the sea).
2. Fish stay hidden stock with moving schools, never swimming creatures.
3. Salmon run is autumn-only; trout the rest of the year.
4. Dark fish shadows in clear shallow water, plus jumps (off at Low).
5. Sea fishing from shore and shallows only until boats exist.
Plus Dave's spawn rule: fish follow the water only (section 5).
Build order is in section 7. Nothing is built; all of it waits for the devstop to end.

Asked by Dave 24 Oct 2026 15:37 UTC. DESIGN ONLY (devstop on, no code).
Facts read from claude/generator-v2: `data/items/fishing.json`, `data/animals/animals.json`, `items/ANIMALS_DESIGN.md`, `tech/OCEAN_WATER_NOTE.md`, `design/WATER_LAND_TYPES.md`, `design/EARLY_GAME_LIST.md`.
Species lists are my picks (the island reads as North Atlantic: moose, blueberry, ADT). Dave to confirm (Q1).

## 0. What exists today
1. Fishing is a **server roll on a hidden stock**, no fish anywhere. Stock is per 128 m cell (4-12 fish, regrows 1 per 15 real min).
2. The cell's type is stream, pond or lake (by position). Species: stream = trout 70% / perch 30%; pond = carp / perch; lake = pike / perch / carp. **No ocean, no salmon.**
3. Rod (bait, 8 m reach) and spear (3 m, depth up to 1.5 m, still, 20-60% hit) are built. Ice holes built. **Not built: nets, bow on water, fish drawn, any jump.**
4. Creatures (rabbit to horse) are server records with no physics, sent only within 120 m of a player, caps 30 per player / 150 total. Fish will NOT use this; see 3.

## 1. Species by water and depth
| Water | Depth | Species (common first) | Notes |
|---|---|---|---|
| Brook / small river | 0.3-1.5 m | brook trout, brown trout | year round, small, jump at dawn/dusk |
| River (class 3, wide) | 1-5 m | trout, **Atlantic salmon** (autumn run), eel (night, later) | salmon only in autumn, bigger, jump a lot |
| Lake (class 2) | 0-3 m shallows | perch, carp | existing |
| Lake | 3 m+ | pike, trout (cold deep water) | pike ambush near reeds |
| Pond | any | carp, perch | existing |
| Sea shallows | 0-5 m | herring, sprat, smelt, flounder, mackerel (summer) | small, big schools, reachable from shore |
| Sea mid | 5-30 m | cod, haddock, pollock, mackerel, sea bass | needs a boat or pier (future) |
| Sea deep | 30 m+ | big cod, halibut, tuna, later shark | boat only, later |
Sizes scale with depth. Weights and meat yield go in `fishing.json` (data, RESTART).

## 2. What a "school" is
1. **Not an entity.** A school is a computed record: cell, species, size (fish count), centre point, radius (3-8 m), drift. It is the existing cell stock given a place and a species.
2. **Placement with no re-bake:** the server already knows each water cell's class and depth (tile `water_class`, ground height below 0 m for sea depth, `water_depth_at` hook). For each active 128 m cell it picks 0-3 schools from a hash of (cell, species, game day), and puts each centre on a valid water cell for that species (right depth band, river speed under about 1.5 m/s for trout rests). Nothing is stored in the tile.
3. **Drift:** centre moves by a smooth function of (hash, time), so every client and the server agree with no saved state. Rivers: trout hold in pools and slow reaches; salmon centre moves upstream during the autumn run. Sea: schools drift along the shore and out with tide-free time of day (deeper at noon).
4. **Stock still rules:** catching removes from the cell stock as today; a school with 0 stock is gone until it regrows. Overfishing still hurts.
5. **Size:** school size follows stock (4-12 now; sea cells larger, ~20-40 and regrow faster).

## 3. The jump signal
1. Server, per player, every 1 s: for schools within ~100 m, chance of a jump = size x time (dawn/dusk x1.5, midday x0.5) x weather (rain x1.2, storm x0.3, cold x0.6). Roughly one jump per 10-30 s near a big school. At most 1 jump event per 3 s per player.
2. Event = new message `fish_jump` (x, z, size class, species group, seed), about 10 bytes, sent only to players within 100 m. One protocol bump.
3. Client look: splash column (small for trout, bigger for salmon, a quick silver flash), 2-3 expanding ripple rings for ~3 s, a few drops. One pooled emitter set (8 max alive).
4. Sound: short splash (3 variants, size-scaled), positional, quieter with distance, muffled by rain. Reuses the emitter API (server `emit_sound` is the piece the emitter notes say waits for the first server-owned entity; check it is in).
5. **Meaning:** the jump point is inside the school's radius. Throwing, shooting or casting near it gets the school bonus (4). Jumps are the only tell on cloudy/rainy water.

## 4. Catch methods
Chance = today's formula x **school factor**: 1.0 inside the school radius, 0.5 within 2x radius, 0.15 outside (still possible, so no dead water). Jump in the last 10 s: x1.3.
| Method | Reach | Rules | Yield |
|---|---|---|---|
| Rod / line | cast 8 m (future: cast to a point, bite near school) | existing bait, skill, time, weather | 1 fish |
| Spear (thrown 12 m or jab 3 m) | water up to 1.5 m deep, fish must be in shallows | thrown spear at the jump/shadow point; existing still-rule on jab | 1 fish, spear wears |
| Net (the early-game shore net, 20 twine + 4 stones) | thrown / dragged from shore, 5 m reach, water up to 1.2 m | covers a 2.5 m circle; catches 1-4 by school size; net wears 1 per use; dawn/dusk best | several small fish |
| Bow | shallow water up to 1 m, target a jump or shadow | low chance (15-35%), arrow lost 50% in water; salmon big enough to feel worth it | 1 fish |
| Cast net (better, bench) | 8 m | wider circle 4 m | more |
Net, spear and bow on the sea: shallows only (a few metres from shore). Deeper needs a boat/pier (future).

## 5. Spawn (Dave rule, 24 Oct 15:47)
1. Nothing is placed because it is close to spawn. Fish follow the water only: no stock floors, no extra schools near spawn.
2. Once the world is settled, the spawn point is chosen near the resources (water, fish, stone, wood). Early-game step 10 ("fish source within 300 m") is met by moving spawn then, not by adding fish.
3. For reference only: river 93 m SW of today's spawn (53301, 68427) already holds trout and perch by the normal rules; lake 361 m SE; sea ~900 m.

## 6. Server load and frame rate
1. **Server:** no fish entities, no physics. Per player: about 9 nearby cells x up to 3 schools = 27 hash evaluations once per second (microseconds), plus jump rolls. Jump events ~0.1-0.3/s per player x 10 bytes = about 3 bytes/s. Far below the animals budget (2 ms/tick); target under 0.1 ms/tick at 20 players. Measured in the stress run before shipping.
2. **No saves:** schools are rebuilt from hash + stock. Stock is in memory today (restart = full, which is fine).
3. **Client:** splash/ripple pool of 8, plus optional fish shadows (4). Target under 0.3 ms CPU, under 0.2 ms GPU. Off at Low: no shadows, 3 splashes max.
4. **Shadows (optional look):** dark fish-shaped decals just under the surface for schools within 40 m in clear shallow water; hidden in rain, murky/storm water, at night, and where water is deeper than 2 m (cheap instanced quads, max 6 schools drawn).

## 7. What needs building (each its own push, with claim of a build number)
1. **A. Data:** fishing.json adds sea and river types, species by depth band, school and jump numbers, net/bow/spear factors. RESTART. (Sal)
2. **B. Water classifier:** server function: (x, z) to {brook, river, lake, pond, sea_shallow, sea_mid, sea_deep} + depth. Uses tile `water_class`, height, existing hooks. RESTART. (Steve / Sonny review)
3. **C. School module:** `server_fish.gd` placement, drift, stock link, salmon run by season. RESTART + tests. (Steve)
4. **D. Jump event:** protocol bump, `fish_jump`, rate limits, PROTOCOL.md note. RESTART. (Steve)
5. **E. Client:** splash, ripples, shadows, sound set (3 splash, 1 big splash), Low-tier fallbacks. RUNTIME. (Kathleen)
6. **F. Items:** raw fish items per species (salmon, herring, mackerel, cod, haddock, halibut, tuna; trout/perch/carp/pike exist), icons, models, weights, cook/smoke recipes. (Sal)
7. **G. Catch methods:** shore net item + action, bow-on-water hit test, thrown-spear water hit, school factor in the roll. (Sal / Steve)
8. **H. Tests:** school placement is deterministic, never outside water, stock conservation, jump rate caps, 20-player stress numbers.
Order: A, B, C, G (net) first so early game works; D/E (jump) next; F/other species after.

## 8. Not now
Boats, deep-sea fishing, sharks, lobster pots, fish farms/ponds, line cast aiming, fish AI that flees nets. Eels and ice-fish species later.
