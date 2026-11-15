# Starter area against Art_Direction.md (Kathleen, 3 Nov 2026)

What a new player sees in the first minutes, judged against Dave's `art/Art_Direction.md` ("realistic enough to believe in, colourful enough to inspire wonder"). Sources: the rig pictures on `claude/pics-rig2-20261102` (pr57_ground_pbr_spawn_yaw0, orchard_close) and `claude/pics-rig3-20261102` (ground_grass30m, fell_before, fell_falling, apples). Offline judgement, no new run.

## What already belongs in Dynasty
- **Grass and meadow (4/5):** dense, varied blades, sunlit patches, yellow flowers. The best thing on screen; it already reads as a real meadow.
- **Oak and broadleaf trunks (4/5):** bark texture, flare at the base, broken limb stubs: believable and weathered.
- **Paths (3.5/5):** worn dirt track through the grass in the fell shots reads right.

## What breaks the direction, ranked by how much of the screen it covers
| # | Problem | Seen in | Direction it breaks | Fix (owner) |
|---|---|---|---|---|
| 1 | Broadleaf crowns are near-black green walls: no sky gaps, almost no light inside, the forest reads gloomy at noon | spawn, orchard, apples, grass30m | "Sunlight warm and inviting, deep beautiful greens" | Lighter crown interiors (foliage shader backlight / ambient on leaves), more gaps between clumps (apple trees started in PR #177); the same treatment for oak, beech, maple. Kathleen, with MikeW on cost. |
| 2 | Shade has a cool cyan-blue cast: ferns and shrubs under trees read blue-grey, not green | orchard_close, apples, grass30m | "Rich, vibrant, natural colours", warm palette | Warmer shadow and sky-ambient tint in `look_settings.gd` (Technical direction rule: ask first, it is a shared setting); shrub/fern vertex colours a step greener. Kathleen proposes, Steve/tech reviews. |
| 3 | Pine and spruce boughs are flat hard-edged planes radiating like spokes: they read low-poly | fell_before, fell_falling | "Avoid low-poly" | Softer bough cards (feathered alpha, more droop, two crossed cards per bough) in tree_builder conifer builder. Kathleen with Kathreen. |
| 4 | Felled log only seen end-on; no picture of its length or cut face | fell shots | (unchecked) | Side-on rig shot (asked of the PC thread). |
| 5 | Loose items are flat single-colour parts that look plastic close up | item sheets | "No plastic look; wood grain, stone variation" | Surface grain on all loose items, PR #185. |
| 6 | Campfire flames pale cream where tongues overlap | QA pic-campfire-lit-real | "Taverns and fires radiate warm firelight" | Three-stop flame colour, PR #180. |

## Next steps in order
1. PC pictures for PRs #177, #180, #185 (listed to the PC thread).
2. Crown interiors (item 1) for the oak first: the most common tree at spawn.
3. Proposal for the shadow tint (item 2) to Technical direction before any change.
4. Conifer boughs (item 3) once Kathreen confirms she is not in tree_builder's conifer code.
