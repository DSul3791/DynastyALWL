# Spring heads: the damp patch (Kathleen, 9 Nov 2026)

**Status:** built in `src/client/spring_heads.gd` (the trickle in `cave_water_sounds.gd`), on Steve's #837 drink points. Client only. The coordinator took all three recommendations below on 9 Nov 2026.

## The problem

Dave asked for every ground spring to be hidden under a clump of low shrubs, with "the water just run out from under the bush" (flora_placer `_spring_cover`).

The clump is there (12 to 16 plants, 2.0 to 2.8 m across). But nothing shows water coming out of it. The settled water is on an 8 m grid, so it shows no water at the head and usually none for the first few metres. A player sees a bush and gets "Spring — Press E to drink" with no sign of why.

## What it looks like

One prop per spring head, made of three parts:

1. **A wet ground patch.** This is a projected Decal on the terrain only, the same way the trodden path is done (`PieceLook.trodden_path`, terrain-only cull mask). It does not move the bushes or the water.
   - The colour is dark wet soil, with a ragged moss-green rim and a soft fade at the edge.
   - It is about 4 m across, so it shows about 1 m past the clump on every side.
   - It is drawn longer downhill (about 4 x 6 m), so the ground is visibly wettest where the water leaves.
2. **The runnel.** A narrow wet streak runs from the clump's downhill edge for 3 to 6 m. It is also a Decal: a dark line about 0.4 m wide with a glinting middle, ending where the record brook starts (the first brook cell of the head's drink points).
   - It shows that the water comes from under the bush and where it goes.
   - It is not a water surface, so nothing reads it as deep water.
3. **Pebbles and a glint.** Five to eight small wet stones line the runnel's first metre, made from the existing loose-stone mesh (RockLook), darker and glossier.
   - A tiny moving highlight on the runnel's centre line makes it read as running water from 20 m away.

## Where it goes

- **Heads.** The heads come from #837's `drink_points` springs (x, z per chunk). They are already on the client and are already limited to what the server sends.
- **Direction.** Downhill is toward the nearest record brook cell within 16 m in the same chunk's drink points. If there is none, it is the steepest of 8 ground samples 3 m from the head.
- **Height.** The prop sits at the ground height at the head. A Decal projects onto whatever is there, so it needs no exact y.
- **Lifetime.** Props are added when a chunk's drink points arrive and dropped with `_forget_drink`. The 600-chunk cap that bounds the drink cache bounds the props too.

## Seasons and weather

- **Never dry.** Ground springs are perennial (the drink rule always gives a drink at a head), so the patch shows all year.
- **Snow.** In snow the patch stays dark and the snow is pushed back, as a spring at its year-mean temperature melts it. In practice the decal is drawn after the snow cover, so it reads as a bare wet hole in the white.
- **Frost.** The runnel's far end glazes over (a pale ice tint for its last 1 to 2 m) when the ice rule says the brook below is frozen. The head itself never freezes.

## Sound

There is a quiet trickle within about 6 m of a head. It is a small loop from the existing water sound bank, quieter than a brook, and stops beyond 8 m.

## Cost

- There are 351 spring heads in the world, and usually fewer than 10 in the loaded area. Each prop is two Decals and up to 8 small meshes.
- The decals fade out from 50 to 60 m, like the path decals.
- There is no new network traffic and no server work. #837 already sends the points.

## Choices (decided by the coordinator, 9 Nov 2026 12:04 UTC: all three recommendations)

- **(a) Patch size.** 4 m across, showing past the clump, is recommended. The other choice is 3 m, showing only at the edge.
- **(b) The runnel's length.** It can run to the first brook cell (recommended) or always be 4 m.
- **(c) Sound.** Include the trickle loop now (recommended), or add it later.

## As built

- **`src/client/spring_heads.gd`** holds the heads per chunk from `drink_points`. `terrain_client.gd` hands it each chunk, drops it with `_forget_drink`, clears it on a ground reset and updates it each frame.
- **Building.** A head is built once the player is within 70 m and a ray finds ground under it.
- **Frost and the glint.** The frozen runnel end follows `weather_look.puddles.ice`. The glint follows the sun (`day.elevation`), so it does not glow at night.
- **Textures** are made in code (`patch_image`, `runnel_image`, `ice_image`): there are no image assets.
- **Trickle.** `cave_water_sounds.gd` plays its "trickle" loop at the nearest drawn head (`heads_built`) within 8 m. It is the brook loop at -27 dB and pitch 1.35, on the Foley bus.
- **Check.** `src/worldgen/tools/test_spring_heads.gd` covers the runnel rule, the chunk bookkeeping, the textures and the trickle's nearest head.
- **Pictures.** They are Dino's, at a known head (the #802 spot, x 54048 z 71408), from 5 m and 20 m.
