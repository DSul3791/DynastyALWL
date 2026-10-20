# Controls

Tracks what the controls are now and what is planned. Update it whenever a control changes.

## Now (terrain client, build 23)

| Control | Action |
|---|---|
| Mouse | Look around |
| W A S D | Walk (6 m/s) |
| Double-tap W (within 0.30 s) | Jog (8.5 m/s) |
| Shift + W | Run (11 m/s) |
| (automatic) | Very slight camera bob and sway when moving on the ground, in step with the feet: down and leaning to the stepping side at each footfall, back up in between. Strides are longer when jogging (4.2 m) and running (6 m) than walking (3 m) |
| Space | Jump (walking) or go up (flying) |
| Ctrl | Go down (flying) |
| G or F | Switch between walking and flying |
| / (key with ? on it) | Inspection mode on or off (toggle). A brain icon shows near the top. Shows the name and key note of what the crosshair points at, in the middle of the screen: Oak, Beach sand, Coal, Hemlock (Toxic). What you see depends on what your character knows: it may say Unknown or Might be (a wrong guess). Flying (admin) always shows the truth |
| + / - (also numpad) | Raise or lower how much every spring pours, by about 10 % per press (tuning tool, x0.5 to x20; above x1 rivers and ponds turn muddy brown). Shows "Water flow rate: x1.21 = 12.1 m3/s per spring (191,800 gal/min)" for 3 seconds. The water then runs by real physics for two simulated hours ("running...") and redraws as it moves |
| X | Admin: dig a 2 m hole where the crosshair meets the ground (up to 80 m away). Water flows into holes that open toward it (testing digging against the water) |
| F2 | Cycle quality: Low, Medium, High, Ultra (Low is the minimum machine) |
| F8 | GPU probe: stand still, press once; after about 20 s it lists what each piece (grass, trees, ground, sea, shadows, SSAO, glow, fog, anti-aliasing) costs in GPU ms; also saved to gpu_probe.txt in the game data folder |
| J | Float jitter test: fly to the next far-from-origin spot (admin test, build 68) |
| Esc | Options menu: Resume, Settings (quality, Resolution 1280x720 to 1920x1080, Window: windowed or fullscreen windowed, VSync, sound volume 100/75/50/25 % or off), Advanced (Clear saved ground, which takes effect at once), Quit game. Esc again resumes |
| I | Open or close the inventory (click a slot, then another to move; Drop stack / Drop one; "Make by hand" lists the crafts: cordage, stone axe, spear, campfire). Esc closes it first |
| 1 to 8 | Hold what is in inventory slot 1 to 8 (the first row) |
| Left click | Use the held item (spear: jab; stone axe: swing, with the hit sound of what it strikes) |
| Right click (hold) | Spear: aim a throw; then left click throws. Letting go returns to the normal stance |
| E | Pick up the nearest item on the ground within 3 m; with nothing there, gather the nearest plant or shrub within 2.5 m (flax, nettle and reeds give fibre, shrubs give sticks) |
| ] | Admin test tool: give 10 each of stone, stick, plant fibre and log |

Gait rules:
- Minecraft style: double-tap W toggles jogging on, and Shift adds running while held.
- Letting go of Shift drops back to jogging (if on) or walking. Only letting go of W drops back to walking.
- Walking shows no label. Jogging shows "Jogging". Running shows "Running".
- Other status words (underwater, waiting for ground) still show.
- Flying is an admin look-around tool (noclip). Shift multiplies flying speed.
- Temporary admin compass (2026-10-19): a strip at the top of the screen scrolls as you turn, N, NE, E, SE, S, SW, W, NW with a tick every 10 degrees and the exact heading under the red pointer (north is -z, east is +x).

## Planned / not decided

- Spear (Dave, 2026-10-20, decided, not built): normal attack keys jab; hold right click to raise and aim a throw, left click throws, release right click returns to normal stance.

- Dave's other two "things" from the old design (not yet given).
- Potions, horses and dragons will move much faster than running; ground loading is built to keep up.
