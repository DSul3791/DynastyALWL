# Fog pools and sea fog: the two limits of valley fog

Jamie, 8 Nov 2026. This follows `docs/design/valley_fog.md` (#603), which left two known limits. It belongs with Kathleen's `docs/design/art_weather_light.md` (#598, section 7), and her document stays the source of truth for the look.

1. **One top height for the whole island.** Basins above the top get no fog. Part A below is a spec for Sonny's R6 record.
2. **The open sea goes white under valley fog.** Part B is the sea fog rule, coded on the branch stacked on #603.

## Part A: a cold-air pooling mask in the R6 record (spec for Sonny)

### The real thing

- On clear, calm nights the ground cools by radiation. The cold, dense air drains downhill as a katabatic flow and pools in valleys and basins "much like water filling a lake". It stays trapped until daytime heating or a new air mass breaks the inversion.
- Pools can be many hundreds of feet deep, and they are where radiation fog and frost form (Cold-air pool, Wikipedia; Clements, Whiteman and Horel 2003 on the Peter Sinks basin, Utah, the classic measured case).
- So valley fog belongs in **enclosed low ground at any height**, not only near sea level. A mountain basin at 600 m can be full of fog while the coast below is clear.

### What the record should hold

Treat cold air as a liquid that fills the terrain to its spill point. That is the same priority-flood the rebuild already runs for lakes (C1 and C2, Barnes et al. 2014).

- **Pools.** For each closed or nearly closed depression of the ground, a "cold-air lake" record with:
  - `pool_id`;
  - `spill_m`, the height of its lowest saddle (the pour point);
  - `floor_m`;
  - `area_m2`;
  - the outline polygon at `spill_m`.

  Keep only pools at least 10 m deep (spill minus floor) and at least 0.25 km² in area. Smaller hollows are frost pockets, not fog lakes.
- **Valleys that drain.** Most valley fog is not in closed basins. It lies along valley floors, where cold air flows down slowly and backs up behind narrows.

  For each cell, store `pool_depth_m`: how far the cell sits below the cold-air surface of its valley, capped at 150 m. Work it out with a "fill to the next constriction" pass:
  - walk down each valley (the R5 reach network);
  - at each narrowing (valley floor width at 20 m above the bed less than half of the width upstream), treat the narrow as a weir for cold air;
  - the surface upstream of a weir is the weir crest plus a share of the valley depth (the `valley_pool_share` proposal below).
- **Per-cell byte for the client.** `fog_pool` (0 to 255) = clamp(`pool_depth_m` / 150) × 255, at 64 m resolution, like R4's groundwater grid. It is about 7 KB per 5 km island and can sit next to the other record rasters.
- **Never-see checks:**
  - no fog pool on a slope over 15°;
  - no pool surface above its spill point;
  - every pool has a named cause (closed basin, or valley narrows at a named reach).

### How the client would use it (later, not in this change)

Godot's height fog has one global top, so pools at different heights cannot be drawn by it.

- Each pool, and each valley stretch, gets a **fog sheet mesh**: a flat, soft surface at its cold-air top. It is drawn like still water, with a depth fade against the terrain so its edge is soft where it meets the slope, lit from above (white by day, gold where the low sun hits, blue-grey at night). This is how lakes already get a flat surface from their level.
- A sheet shows only when the weather's `mist` is above 0. Its top is `min(spill_m, floor_m + mist_depth)`, so a weak night only half-fills a basin.
- Inside a pool (camera below its sheet), the distance fog thickens as in #603.
- The global height fog stays for the sea-level layer (coastal lowlands and sea fog).

**Proposal numbers, not from a source** (judged, to check on Dino's pictures):
- `valley_pool_share` 0.3;
- `mist_depth` of a full night 60 m;
- the 10 m and 0.25 km² minimum pool size;
- the 150 m cap.

## Part B: the sea fog rule (coded on the branch stacked on #603)

### The real thing

- **Mechanism.** Sea fog is **advection fog**. Mild, moist air moves over colder sea, and its moisture condenses (Met Office, coastal fog). On the British east coast it is called haar or sea fret.
- **Season.** It is most common in spring and summer, when the land warms but the sea stays cold. Haar comes mostly between April and September.
- **Wind.** It is carried by a light-to-moderate onshore wind or the sea breeze, not by a calm.
- **Inland reach and burn-off.** It can reach several miles inland. Over warm land it burns off quickly, and over cool land it lingers.
- **The sea under valley fog.** Radiation fog forms over land, not over the open sea. Under a calm night's valley fog the sea should stay clear, apart from wisps drifting off the shore.

### The rule (`src/shared/weather.gd`)

`state()` gains three values:
- `sea_fog` (0 to 1): strength over the sea;
- `sea_fog_land` (0 to 1): how far it lies over the land;
- `sea_fog_top_m`: its top above sea level, or 0.

`sea_fog` is a product of:
- **season**: 1 at late spring (year phase 0.2), 0.5 at the solstices, 0 in mid-autumn: 0.5 + 0.5·cos(2π·(phase − 0.2));
- **wind**: none in a calm (up to wind 0.2), full from 0.3 to 0.55, gone by 0.7;
- **dry**: none while it rains or snows;
- **no thick cloud**: front noise up to 0.6 (the same limit as valley fog);
- **a day noise**: rarer than valley fog, smoothstep(0.45, 0.85);
- **zone**: temperate 1, transition 0.8, desert 0.6 (cold-current desert coasts are famous for it), arctic 0.8.

`sea_fog_land` is `sea_fog` thinned by daytime heating: full at night and in the early morning, down to 35% in the afternoon. The fog retreats toward the coast as the land warms and comes back in the evening.

The top is a new height each day, from 60 to 200 m, lower while the fog is thin.

### The look (`src/client/weather_look.gd`, `src/client/water_material.gd`)

- **Over land:** the engine's height fog takes the stronger of valley fog and sea fog over land (`max(mist, sea_fog_land)`), with that layer's top.
- **Colour:** sea fog is greyer than valley fog, whitened 30% instead of 55%, as Kathleen's "grey bank offshore".
- **Over the water:** the water shader now writes its own fog, the same sums as Godot's (distance fog, height fog, aerial colour, sun glow), fed each frame from the environment. Fresh water (rivers and lakes) takes the land layer, so valley fog lies on lakes. The **sea plane takes only the sea fog layer**, so a calm night's valley fog leaves the open sea clear. Underwater, both take the underwater fog as before.
- **Inside a layer** (either one, camera below its top), the distance fog thickens and hides the sky as in #603.
- **The "fog" test kind** stays valley fog. Sea fog has no test kind of its own yet (a kind needs its own sounds in `weather_sounds.gd`). Use the shot runner.
- **Shot runner:** `--shots` takes the weather `seafog` (full sea fog, 120 m top, over land too).

## Known limits after this change

- **Part A is a spec.** Basins above the coastal layer still get no fog until the R6 record and the fog sheets exist.
- **Shore wisps.** Valley fog stops sharply at the shoreline on the sea plane. Real radiation fog drifts a little way out to sea. A soft band could use the sea shader's shore distance later.
- **One top for sea fog.** Sea fog over land uses the same single top everywhere, so it reaches every valley below it, not just "several miles" from the coast.

## Sources

- Cold-air pool: https://en.wikipedia.org/wiki/Cold-air_pool
- Clements, C. B., Whiteman, C. D. and Horel, J. D. (2003), cold-air-pool structure and evolution in the Peter Sinks basin, Journal of Applied Meteorology (found 8 Nov, not yet read in full): https://www.inscc.utah.edu/~whiteman/homepage/articles/Clements2003J%20Appl%20Meteorol.pdf
- Met Office, coastal fog: https://weather.metoffice.gov.uk/learn-about/weather/types-of-weather/fog/coastal-fog
- Haar: https://en.wikipedia.org/wiki/Haar_(fog)
- Priority flood: Barnes, Lehman and Mulla (2014), as already used by the rebuild (`docs/water/watershed_rebuild_design.md`).
