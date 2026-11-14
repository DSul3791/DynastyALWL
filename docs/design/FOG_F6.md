# Fog: F6 play checklist

All NEEDS PLAYER VERIFICATION. The test lane runs headless and cannot see. Design: [FOG_DESIGN_DAVE.md](FOG_DESIGN_DAVE.md). Numbers: [FOG_PLAN.md](FOG_PLAN.md).

**To get fog now:** Esc > Settings > Sound > Sound test, then press **"Sound test weather: change"** until it says **fog**. That gives full valley fog lying 90 m deep over the low ground, so stand in a valley or basin. Press it until it says it follows the game's weather to end it. Real fog comes on calm, clear autumn nights and mornings in low ground. Set graphics to Ultra first; check Medium and Low after.

## PR "fog look"

- [ ] **Interim wash-out fix (#1137).** On a real mist morning by a river, the grass at your feet is not whitened while the sky is clear.
- [ ] **Distance, in daylight, fog kind.** Within about 10 m the ground, tools and your hands are easy to see. 10 to 20 m is noticeably foggy. 20 to 40 m shows shapes and silhouettes. Beyond that it is mostly gone. There is no clear bubble around you and no wall where the fog starts.
- [ ] **Every direction.** Look up: the sky, clouds and stars are hidden, and the sun is a soft faint disc. Look down a slope: the low ground is fogged too.
- [ ] **Climb above it.** Walk or fly up a hillside past the top (90 m above the valley floor for the fog kind). The sky clears gradually, the fog lies in the valley below with clear hills standing out of it, and the sun is bright again.
- [ ] **Entering and leaving.** Walk in and out of the layer's top. It changes gradually and never switches on or off at a line.
- [ ] **Darkness.** At night the fog is dark, not a glowing white landscape.
- [ ] **With a torch** (night, fog). A soft halo is around the flame. On High and Ultra, a glow in the fog around it, and things behind it stay hidden. Without a torch it stays dark.
- [ ] **Campfire in fog.** The same halo and glow around the fire.
- [ ] **Through a doorway.** Inside a built room the air is clear; looking out of the doorway shows the fog outside. In a cave the fog is gone deep inside, and the mouth shows it.
- [ ] **Drift (High and Ultra).** Slow, broad patches, thicker and thinner, drifting gently with the wind (the fog kind is dead calm: they only creep). No boiling, no repeating pattern, not following you.
- [ ] **Clear day unchanged.** On a clear day, far hills haze to the sky colour as before.
- [ ] **Presets.** Ultra: everything above. High: the same with a coarser body. Medium: distance, sky and halos, no drifting body. Low: no weather fog (the switch), clear-day haze as before. Note the frame rate in fog on each.

## PR "fog where and when"

- [ ] **Valleys fill, hills stay clear.** With the fog kind on, look from a hill: the valleys and low basins below are white, and the hilltops and upper slopes stand clear. A basin high in the hills fills too.
- [ ] **No line where it starts.** Walk down from a hill into a valley in fog. You enter it gradually, and it does not move with you.
- [ ] **Real mornings** (no test kind). Over several in-game days in autumn: fog forms on calm, clear nights in low ground, deepens toward dawn and clears over a few hours after sunrise, longer after rain. A warm, dry, windy afternoon has none.
- [ ] **Fog in light rain.** Sometimes a thin fog comes with light, cool rain. It never comes in heavy rain.
- [ ] **Steam by the water.** On a cold, calm morning, low wisps lie over rivers and lakes and fade away from the bank.
- [ ] **Sea fog.** A bank offshore on a light onshore breeze, coming in over the coast.
