# Cover query spec (Technical direction, 2026-10-20)

Dave's rules: under any tree's canopy diameter counts as covered (yes/no, one fixed mild value, any tree type or season). Rain soaks the ground everywhere except under canopies. Cover gives mild shelter from sun and rain, not heat or cold. Fires under cover survive rain; open fires go out. Blueprints: yellow in the open, green under cover.

## API (one shared pure function, no network traffic)
- File `src/shared/cover.gd`, class functions:
  - `Cover.at(pos: Vector3, trees: CoverIndex) -> float` returns 0.0 (open) or 1.0 (covered). Horizontal test only: (x,z) inside any tree's crown circle (crown_m / 2 from the species table; the item's size scale applies) and pos.y no higher than the tree top. Roofs later add to the same function.
  - `CoverIndex`: a coarse hash grid (cell 16 m) of `[x, z, crown_radius, top_y]`, built from the flora list each side already holds.
- Client: `flora_view.gd` fills the index when a chunk plan is made (trees only, already iterated), drops it with the chunk. Query is a few cell lookups, no rays.
- Server: `flora_placer` data fills the same index (needed for "rain puts out open fires" and server-side fire). Server and client agree because both use the same list and function.
- Removed trees (flora_removed) are removed from the index, so felling a tree opens the ground.

## Cost at Low
Memory about 16 bytes per tree (about 2 MB for 125k items; only chunks inside the view are indexed). Per query under 10 microseconds. Called: once per frame for the player (sounds, sun/rain exposure), per blueprint while placing, per fire once a second on the server. No new draw cost.

## Rain wetness
Rain soaking the ground (wet look, puddles, wet footsteps) uses Cover.at per ground sample point at most once per second for the player area; the ground wetness shader uses a coarse cover mask texture only if Art needs it (their call, tier-gated, off at Low).

## Owner and order
Build: Water and terrain thread (owns the weather state). One job, small. Consumers: Art (wet ground, rain particles skip under canopy), Sounds (replace the `forest` weight proxy in weather_sounds.gd with Cover.at for drips and rain loop), Items and crafting (campfire blueprint, rain puts out fire). No save format or network change, so no approval needed beyond this spec; touching `flora_view.gd` needs a heads-up to Art.
