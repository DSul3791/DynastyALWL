# Drawing the 2 m water (Sullivan water, Sonny, 7 Nov 2026)

Design first (Dave's top rule). The guide's sections 5, 27 and 29 cover the look. Its build-order table puts the look at M6. This is the first piece of it: dug ditches, and rivers inside a dig region, drawn from the 2 m grid instead of from 8 m samples.

## Why
The dig regions (`src/sullivan_water/live/dig_windows.gd`) simulate 2 m cells. Until now they were drawn only through the hub's 8 m levels, where each 8 m sample shows the mean of its wet 2 m cells. A 3 m ditch therefore showed as 8 m blobs, or not at all where fewer than 4 of a sample's 16 cells were wet. Dino's #506 picture showed water in the dug slot, but it could not prove the drawing followed the ditch.

## The rule
1. **Server.** At every hub publish, each dig region (running or asleep) becomes one texture packet, wherever it lies. The format is the one the 8 m window already uses (`water_flow_texture.gd`, protocol 85): one RGBAF texel per 2 m cell, with R the surface (or the bed where dry), G and B the flow, and A the depth. Sea cells (bed below 0) are left to the sea, exactly as in the 8 m window. The packets go out in one message, `deliver_fine_water(keys, packets)`:
   - `keys` names every region that is drawn. A client drops any fine sheet it holds that is not named.
   - `packets` carries the texture of each running region, and of each sleeping one every fourth publish. That way a player who joins late gets sleeping ditches within a minute.
2. **Client.** Each key gets its own `LiquidSurface` sheet in fine mode (`show_fine`). It uses 1 m vertex spacing over a texture of 2 m cells, with the same shader and therefore the same look.
3. **Handover.** Inside a fine region the 8 m sheets step aside: the live window's sheet and every chunk sheet. They take up to 8 rectangles (`set_fine_holes`). Both sides use the same `fine_blend()`, a 6 m band whose inner edge wanders up to 2 m. The fine sheet fades in over that band from its edge, and the 8 m sheets fade out over it, so together they always add up to one water and no straight line shows (the BUG-006 rule).
4. **Unchanged.** Gameplay still reads the 8 m levels: swimming, prompts, steps, sound. Only the picture changes. The 8 m levels keep the regions' water through `publish()`, so nothing that reads them loses it.

## Limits, labelled
- Gameplay (the 8 m levels) sees a region's water only on the hub's one simulated tile, because the hub publishes only that tile. The picture shows every region.
- The old grid look (`water_material.gd`) does not take the fine holes. It already steps aside wherever a liquid sheet draws, and chunk sheets cover the rivers. If a picture shows the grid look on top of a ditch, it gets the same uniform.
- The baked rivers outside dig regions are still drawn at 8 m. Handing the whole river to the 2 m grid comes after this works.

## Check (Dino, after David4)
Dig the #506 ditch with `--dig-ditch=53240,68342,20`, wait 2 minutes, and take one picture from 6 m up looking along the ditch. **Pass:** water follows the 3 m slot with banks about 2 m wide, there is no 8 m square around it, no line shows where the fine sheet meets the river, and the shader error count is 0.
