# Controls

Tracks what the controls are now and what is planned. Update it whenever a control changes.

## Now (terrain client, build 20)

| Control | Action |
|---|---|
| Mouse | Look around |
| W A S D | Walk (6 m/s) |
| Double-tap W (within 0.30 s) | Jog (11 m/s) |
| Shift + W | Run (18 m/s) |
| (automatic) | Very slight camera bob and sway when moving on the ground; steps faster when jogging or running |
| Space | Jump (walking) or go up (flying) |
| Ctrl | Go down (flying) |
| G or F | Switch between walking and flying |
| / (key with ? on it) | Inspection mode on or off (toggle). A brain icon shows near the top. Shows the name and key note of what the crosshair points at, in the middle of the screen: Oak, Beach sand, Coal, Hemlock (Toxic). What you see depends on what your character knows: it may say Unknown or Might be (a wrong guess). Flying (admin) always shows the truth |
| F2 | Cycle quality: Low, Medium, High, Ultra (Low is the minimum machine) |
| Esc | Options menu: Resume, Settings (quality), Advanced (Clear saved ground), Quit game. Esc again resumes |

Gait rules:
- Minecraft style: double-tap W toggles jogging on, and Shift adds running while held.
- Letting go of Shift drops back to jogging (if on) or walking. Only letting go of W drops back to walking.
- Walking shows no label. Jogging shows "Jogging". Running shows "Running".
- Other status words (underwater, waiting for ground) still show.
- Flying is an admin look-around tool (noclip). Shift multiplies flying speed.

## Planned / not decided

- Dave's other two "things" from the old design (not yet given).
- Potions, horses and dragons will move much faster than running; ground loading is built to keep up.
