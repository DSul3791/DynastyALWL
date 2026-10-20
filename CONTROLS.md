# Controls

The single complete list of every input (keyboard, mouse, held versus tap, context prompts). Dave's rule (2026-10-20): any change that adds or changes an input updates this file in the same push. `python3 tools/check_controls.py` fails if a key or mouse button bound in code is missing from the first column of the tables below; run it before every push.

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
| C | Crouch (toggle): lower eye, slower; kept while moving |
| X | Sit (toggle): lower still, no movement; any movement key stands you up. Resting drops exertion (the server side is Items') |
| Z | Lie down (toggle): eye almost at the ground, no movement; any movement key stands you up |
| Ctrl+X | Admin: dig a 2 m hole where the crosshair meets the ground (up to 80 m away). Water flows into holes that open toward it (testing digging against the water) |
| F2 | Cycle quality: Low, Medium, High, Ultra (Low is the minimum machine) |
| F3 | Debug details on or off (the long diagnostic list; default HUD is only build, position, last sound). Also Esc > Settings. Threads add lines with `debug_hud.add_line(name, callable)`. |
| Ctrl+Shift+G | GPU probe: stand still, press once; after about 20 s it lists what each piece (grass, trees, ground, sea, shadows, SSAO, glow, fog, anti-aliasing) costs in GPU ms; also saved to gpu_probe.txt in the game data folder |
| J | Float jitter test: fly to the next far-from-origin spot (admin test, build 68) |
| Esc | Options menu: Resume, Settings (quality, Resolution 1280x720 to 1920x1080, Window: windowed or fullscreen windowed, VSync, sound volume 100/75/50/25 % or off), Advanced (Clear saved ground, which takes effect at once), Quit game. Esc again resumes |
| I | Open or close the crafting and inventory screen (about 3/4 of the screen): recipes on the left (the ones you can make now lit and on top, the rest greyed out, each alphabetical), inventory on the right, one search box filtering both; pick a recipe to see what it needs (have / need), choose how many and press Craft. Click a slot, then another, to move; Drop stack / Drop one. Esc closes it first |
| 1 to 8 | Hold what is in inventory slot 1 to 8 (the first row) |
| Left click | Use the held item (spear: jab; stone axe: swing, with the hit sound of what it strikes, and a blow on bare rock gives a stone; a held torch lights the way; on a tree trunk, repeated blows fell the tree into a trunk and a stump) |
| Right click (hold) | Spear: aim a throw; then left click throws. Letting go returns to the normal stance |
| Left click with a campfire kit held | Place the fire where the ring shows: yellow ring = open ground (rain puts the fire out), green = under a tree's crown (the fire survives rain) |
| Left click with a lean-to kit held | Place the lean-to where the ghost shows; its open front faces you. E near it takes it down (kit back). Anyone under its roof counts as under cover (fires survive rain) |
| E at a chest | Opens the chest screen: click a stack on the left to take it, a stack in your pack on the right to put it in. Hold E (0.6 s) takes an empty chest down. Esc or I closes |
| E at a chopping block | Splits one log into 4 firewood (needs an axe on the hotbar and wears it); hold E to keep splitting every 0.6 s. Shift+E takes the block down. E at a fire burns firewood first, then sticks, then logs |
| E at a fire | Burning: tap E adds fuel (firewood, then sticks, then logs), hold E (0.6 s) roasts one raw forage item. Burnt-out or rained-out: Press E to add firewood, then Press E to light (uses one plant fibre as tinder; open fires will not light in rain). A placed campfire (10 stones and 20 sticks) starts lit with 20 sticks of fuel: a stick burns 2 game minutes, firewood 30, a log 2 game hours (1 game minute = 2.5 real seconds) |
| E at a lean-to | Hold E (0.6 s) takes it down |
| E | Pick up the nearest item on the ground within 3 m; with nothing there, harvest the nearest pickable plant or shrub within 2.5 m (the prompt "Press E to harvest" shows when it will work, or why not, e.g. needs spade). Hold E: keeps picking every pickable plant within 2 m, about 5 a second, until nothing is left or you let go. Roots and bulbs need a spade, bark, gum and sap a stone knife, wood an axe; a picked plant bears again after 3 game days |
| Right click (tap) with food or medicine held | Eat it / apply it (hunger and health bars at the bottom left). The inventory panel's "Eat / use" button does the same for the selected slot |
| ] | Admin test tool: give 10 each of stone, stick, plant fibre and log |

Gait rules:
- Minecraft style: double-tap W toggles jogging on, and Shift adds running while held.
- Letting go of Shift drops back to jogging (if on) or walking. Only letting go of W drops back to walking.
- Walking shows no label. Jogging shows "Jogging". Running shows "Running".
- Other status words (underwater, waiting for ground) still show.
- Flying is an admin look-around tool (noclip). Shift multiplies flying speed.
- Temporary admin compass (2026-10-19): a strip at the top of the screen scrolls as you turn, N, NE, E, SE, S, SW, W, NW with a tick every 10 degrees and the exact heading under the red pointer (north is -z, east is +x).

Other scenes: the terrain preview scene (admin look-around, scenes/terrain_preview) uses W A S D, Space, Ctrl, Shift and G like the client; it has no gameplay inputs.

Input rules (Dave):
- E is the standard interaction key. The centre-screen prompt ("Press E to ...") shows when it will work or why not, and vanishes on pick, with no message after picking. Tap E acts once, hold E (0.6 s) repeats or does the heavier action (sweep harvest, take a structure down).
- Shift+E is the safe take-down variant at the chopping block (plain E uses it).
- Left click uses the held item; right click is the secondary (aim a throw, eat/apply).
- Effect symbols (brain, ghosted house, more later) sit side by side in one row at the top, recentred.

## Planned / not decided

- Stances (Dave, 2026-10-20, decided, build 229 Ground thread, not built yet): C = crouch, X = sit, Z = lie down, all toggles; any movement key stands you up. No movement while sitting or lying. Admin dig moves from X to Ctrl+X (the table row for X changes when it lands).

- Spear (Dave, 2026-10-20, decided, not built): normal attack keys jab; hold right click to raise and aim a throw, left click throws, release right click returns to normal stance.

- Dave's other two "things" from the old design (not yet given).
- Potions, horses and dragons will move much faster than running; ground loading is built to keep up.

- Carrying: no key; the inventory panel shows "Carrying x of y kg". A heavy pack slows walking, jogging and running; flying is unaffected.
- Rest (Ground adds the keys: C crouch, X sit, Z lie, all toggles; any movement key stands you up): sitting or lying brings exertion down to 0, lying fastest; standing under a heavy pack only rests it to about half. Over-exerted: speed capped, no sprint; keep pushing and you faint, then wake slowly.
