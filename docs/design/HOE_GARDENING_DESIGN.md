# Hoe gardening and levelling (14 Nov 2026)

Thread "Add gardening to the Hoe". Dave's words (14 Nov 2026):
- "gardening should also be another option on the right click of the Hoe that allows you to make garden plots or plant seeds, plants, shrubs trees etc."
- "Trees should drop some seeds when cut down. a random number of seeds between 1 and 5 seeds per tree."
- "the hoe should work very much like the Valheim Hoe plus the plugin plant easy and plant everything." This is a feel reference only; the code and art are our own.
- "ground leveling currently works but its to small an area and its too week"; "make the ground level with where you are standing and if you are standing on say a foundation it make the ground just a little bit below your feet".

The master items catalog (s2.1) already lists the hoe's "Create Garden Plot" and "Plant" modes.

## What is built
1. **Garden mode (PR #1119).** The hoe's right-click list gains Garden. Choosing it opens a second list: the garden plots you know, then what the pack can plant, with counts.
   - Seeds go in a tilled bed or garden plot.
   - Dug-up bushes and tree seeds go in open ground.
   - The client sends the existing ACT_SOW / ACT_TILL / ACT_PLANT_BUSH, so there is no protocol change. The server rules on reach, season, ground and spacing.
2. **Levelling (PR #1119).** Smooth levels a 1 m grid within 3 m to the ground under your feet. When you stand on a piece (0.2 m or more above the ground, such as a foundation), it levels to 0.1 m under your feet.
   - Heights are read through the saved dig/fill log, so strokes add up and stop once level.
   - Constants are in `src/stream/server_items.gd` (`SMOOTH_REACH_M`, `LEVEL_*`).
3. **Garden plots with the hoe.**
   - Picking a plot in the Garden list shows its ghost, as with the hammer, and left click lays it out.
   - The server accepts a hoe on the hand bar for plot blueprints of hammer tier 1. Other plots still need their hammer.
4. **Rows and grids with a preview.**
   - The mouse wheel picks one cell, a row of 5 along the way you face, 3 by 3 or 5 by 5 (`FarmRules.GARDEN_GRIDS`).
   - Green markers show where a click will plant, red where it will not.
   - A grid never takes more than the pack holds of the pick, and a 2 m plot takes one seed.
   - Requests go out paced: tills 600 ms apart, sows 150 ms apart (`FarmRules.garden_step`).
5. **Tree seeds.** See the next PR and section "Tree seeds" below once it lands.

Herbs and flowers have no items, so they are left out. Cold frame and Compost bin stay locked.

## Assumed on Dave's behalf, for his review
These are PROVISIONAL values the thread or the coordinator chose under Dave's standing order. Each can be changed by editing the named constant or data row.

| # | Assumption | Where |
|---|---|---|
| G-1 | A seed clicked on open ground tills a bed there and then sows it, with no second click. | `FarmRules.garden_action`, `held_item._garden_here` |
| G-2 | Levelling reach 3 m (was 1.5); up to 4 edits a stroke of up to 0.5 m each (was 0.25), with 2.5 m spheres. On a piece, it levels to 0.1 m under the feet, at most 1.5 m above the ground under them. The soil is free (not volume balanced), Valheim-style. | `server_items.gd` `SMOOTH_REACH_M`, `LEVEL_MAX_OPS`, `LEVEL_MAX_M`, `LEVEL_SPHERE_M`, `LEVEL_BELOW_PIECE_M`, `LEVEL_MAX_RAISE_M` |
| G-3 | The Garden list holds plots first, then seeds, bushes and tree seeds in pack order. | `held_item._hoe_menu_choose` |
| G-5 | The hoe lays out garden plot blueprints. The Thatch plot (hammer tier 1) needs no hammer; plots of a higher tier keep their hammer. | `server_items._can_blueprint` |
| G-6 | Grid sizes are one, a row of 5, 3 by 3 and 5 by 5. Seeds go 1 m apart and bushes 2 m apart. | `FarmRules.GARDEN_GRIDS`, `SEED_SPACING_M`, `BUSH_SPACING_M` |
| G-7 | Client planting reach is 3.7 m from the feet, inside the server's 4 m. | `held_item.GARDEN_REACH_M` |
| G-8 | Garden pacing: tills 600 ms apart (the server's hoe pace is 500 ms), sows 150 ms apart. A sow waits up to 3 s for the bed its till asked for. | `FarmRules.GARDEN_*_MSEC` |

G-4 is the coordinator's ruling "a species' own fruit or nut is its seed".
