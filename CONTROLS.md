# Controls

The single complete list of every input (keyboard, mouse, held versus tap, context prompts). Dave's rule (2026-10-20): any change that adds or changes an input updates this file in the same push. `python3 tools/check_controls.py` fails if a key or mouse button bound in code is missing from the first column of the tables below; run it before every push.

## Now (terrain client, build 23)

| Control | Action |
|---|---|
| Mouse | Look around |
| Wheel (mouse) | Scroll out (wheel down) from first person to third person: the camera moves up and back a little at each step (1.6 m to 7 m behind, 0.4 m a step); in third person scrolling out pulls further, scrolling in comes closer and, past the nearest step, back to first person. The distance is remembered between sessions (`user://view.txt`); you always start in first person. The camera pulls in when a wall, the ground or a trunk is in the way. Works while flying. A plain placeholder body is drawn until there is a real character. Only while the mouse is captured (menus and the inventory keep their own scrolling) |
| W A S D | Walk (1.4 m/s) |
| Double-tap W (within 0.30 s) | Jog (3.2 m/s) |
| Shift + W | Run (6 m/s) |
| B (held with a shield in the off hand) | Block with the shield while held |
| Shift + right click with a hoe | Sets grade point A, then B (stakes show); a third click starts a new line |
| Hold Shift + left click with a hoe | Grades the ground within 1.5 m of the A-B line toward a straight ramp (0.25 m per stroke, within 12 m of A, free; only the hoe wears) |
| (automatic) | Very slight camera bob and sway when moving on the ground, in step with the feet: down and leaning to the stepping side at each footfall, back up in between. Strides are longer when jogging (4.2 m) and running (6 m) than walking (3 m) |
| Space | Jump (walking) or go up (flying); on a ladder, let go and drop back |
| Ladder (W / S) | Walk up to a placed ladder facing it and hold W to grab on and climb (1.1 m/s); S climbs down and steps off at the bottom; at the top W steps you onto the edge |
| Ctrl | Go down (flying) |
| G | Switch between walking and flying |
| P | Auto pickup on or off (toggle, default off, remembered). "Auto pickup ON/OFF" shows slightly above the middle of the screen for 1.5 s. When on, loose items within reach and in view are picked up, one at a time, 4 a second (the server still refuses what is too heavy or needs a tool); what you just dropped is left alone for 15 s. Off while swimming, placing a blueprint, asleep, dead or with a screen open |
| F | Open the chest, station or remains beside you (your pack left, its contents right; T moves the selected stack across). Carrying a log with nothing to open: F twice within 0.6 s puts the log down (the first F says so); Q does too |
| / (key with ? on it) | Inspection mode on or off (toggle). A brain icon shows near the top. Shows the name and key note of what the crosshair points at, in the middle of the screen: Oak, Beach sand, Coal, Hemlock (Toxic). What you see depends on what your character knows: it may say Unknown or Might be (a wrong guess). Flying (admin) always shows the truth |
| + / - (also numpad) | Raise or lower how much every spring pours, by about 10 % per press (tuning tool, x0.5 to x40; every pond starts at x10 = 100 m3/s; above x10 rivers and ponds turn muddy brown). Shows "Water flow rate: x10.00 = 100.0 m3/s per spring (1,585,000 gal/min)" for 3 seconds. The water then runs by real physics for two simulated hours ("running...") and redraws as it moves |
| C | Crouch (toggle): lower eye, slower; kept while moving |
| Q | Lay down the large log on your shoulder (D does it too in the inventory with nothing selected) |
| X | Sit (toggle): lower still, no movement; any movement key stands you up. Resting drops exertion (the server side is Items') |
| Energy (no key) | The Energy bar sits with the other bars at the top of the inventory and Tab screens. It drains with time and exertion (about 3 game days, 3 real hours, of ordinary play), refills by sitting (to 75%), lying down and sleeping (8 game hours from empty), and at 0 you collapse asleep and cannot move until rested. Use (E) on an Energy bar or Herbal tea gives energy at once but wears down your fitness |
| Warmth (no key) | The Warmth bar sits with the other bars at the top of the inventory and Tab screens. Cold air, wind, rain or snow on you and swimming lower it; a lit campfire within 4 m or standing under cover raises it. Below 40 you shiver and stop healing; below 20 the cold costs health, never below 1 |
| E at remains | Press E at the remains of a fallen character to search them: the owner from the moment they fall, anyone from the second day. Things can only be taken out. They are cleaned up after seven days |
| Z | Lie down (toggle): eye almost at the ground, no movement; any movement key stands you up. While lying, **hold Z for 3 seconds to sleep** (the screen dims to about 60% dark, "Hold Z to sleep" shows while lying): exertion falls up to twice as fast as lying and health heals up to twice as fast, best under a roof or tree crown, 60% of that on open dry ground. Rain that reaches you stops you sleeping and wakes you; a movement key, a hit or fall, or Z again wakes you; resting at zero exertion for 10 s wakes you rested. Tapping Z while lying still stands you up |
| Ctrl+R | Admin: put a rabbit on the ground where the crosshair points (up to 40 m away), for testing animals |
| Ctrl+N | Admin: stand next to the nearest NPC that is drawn (they are sent within 120 m), then press E to talk |
| 1 to 5 (in a talk panel) | Pick the numbered answer |
| Ctrl+X | Admin: dig a 2 m hole where the crosshair meets the ground (up to 80 m away). Water flows into holes that open toward it (testing digging against the water) |
| F2 | Cycle quality: Low, Medium, High, Ultra (Low is the minimum machine) |
| F4 | All the overlay text on the screen (build, fps, position, last sound, debug lines) on or off; remembered between runs (default on). The server link bars at the top left stay. |
| (no key) | Look-angle ruler: underground or in water, ticks beside the crosshair every 10 degrees from -40 (down) to +40 (up) plus one at 45, a number on 0, 20 and 40, and a yellow marker at the angle you are looking. |
| F3 | Debug details on or off (the long diagnostic list; default HUD is only build, position, last sound). Also Esc > Settings. Threads add lines with `debug_hud.add_line(name, callable)`. |
| Esc > Advanced > Measure this machine | About 1 minute: stands still and slowly turns at Low, Medium and High and shows fps, 1% low, worst frame, CPU and GPU ms, draw calls and video memory per tier; saved to machine_run.txt in the game data folder. Press it again to stop or to close the table |
| Ctrl+Shift+G | GPU probe: stand still, press once; after about 20 s it lists what each piece (grass, trees, ground, sea, shadows, SSAO, glow, fog, anti-aliasing) costs in GPU ms; also saved to gpu_probe.txt in the game data folder |
| Ctrl+Shift+V | Colour the water by what the shader sees (debug): red = running water, blue = still, green = foam; press again to go back |
| Ctrl+Shift+W | Hide or show every river and lake drawing (debug: if an odd patch stays with the water hidden, it is ground, not water) |
| J | Float jitter test: fly to the next far-from-origin spot (admin test, build 68) |
| Esc > Controls | One screen listing every hotkey (Dave 2026-10-21); keep its text (HELP_TEXT in terrain_client.gd) in step with this file |
| Esc | Options menu: Resume, Controls (every hotkey), Settings (quality, Resolution 1280x720 to 1920x1080, Window: windowed or fullscreen windowed, VSync, sound volume 100/75/50/25 % or off), Advanced (Clear blocks (was Clear saved ground), which takes effect at once), Quit game. Esc again resumes |
| I | Open or close the crafting and inventory screen (about 3/4 of the screen): recipes on the left (the ones you can make now lit and on top, the rest greyed out, each alphabetical), inventory on the right, one search box filtering both; pick a recipe to see what it needs (have / need), choose how many and press Craft: the crafts line up in a queue under the recipe list (name, count, time left on the first) and run on the server even with the screen closed. Click an entry in the queue to cancel it and get its ingredients back. Click a slot, then another, to move; Drop stack / Drop one. Esc closes it first |
| 1 to 9, 0 | The hotbar: hold what is in pack slot 1 to 10 (the first ten slots, shown as a strip along the bottom of the screen with the held one lit). The same key again puts it away, empty hands. Drag an item from the inventory (or another slot) onto a hotbar box to put it there. Tools must be on the hotbar to work. In the inventory, Use (E) on a tool, weapon or kit holds it (moving it into a free hotbar slot first if it is deeper in the pack) and again puts it away |
| Tab | Open or close the character screen: health, exertion, beating heart, food, water, attributes (luck) and skills. Esc closes it first |
| Left click | Use the held item (spear: jab; stone axe: swing, with the hit sound of what it strikes, and a blow on bare rock gives a stone; a held torch lights the way; on a tree trunk, repeated blows fell the tree into a trunk and a stump) |
| Right click (hold) | Spear: aim a throw; then left click throws. Letting go returns to the normal stance |
| Right click with a spade held | Switches the spade between Dig and Raise mode (the held name shows which) |
| Left click with a spade in Raise mode | Adds ground at the point under the crosshair, using shovelfuls of soil, sand, gravel, clay or stone from your pack: 1 for a small spade, 4 medium, 8 large (a 0.9 m heap each, wider for bigger spades) |
| Left click with a spade held | Digs the ground under the crosshair within 3 m: a 0.9 m hole each swing (every 0.7 s), the sound, grass and pebbles there vanish. The server checks the spade, wears it, keeps the hole through restarts and re-bakes |
| Left click with a campfire kit held | Place the fire where the ring shows: yellow ring = open ground (rain puts the fire out), green = under a tree's crown (the fire survives rain) |
| Left click with a lean-to kit held | Place the lean-to where the ghost shows; its open front faces you. E near it takes it down (kit back). Anyone under its roof counts as under cover (fires survive rain) |
| E at a chest | Opens the chest screen: click a stack on the left to take it, a stack in your pack on the right to put it in. Hold E (0.6 s) takes an empty chest down. Esc or I closes |
| E at a chopping block | (prompt: "Press E to split firewood") Splits one log into 4 firewood (needs an axe on the hotbar and wears it); hold E to keep splitting every 0.6 s. Shift+E takes the block down. E at a fire burns firewood first, then sticks, then logs |
| E at a fire | Burning: tap E adds fuel (firewood, then sticks, then logs), hold E (0.6 s) roasts one raw forage item. Burnt-out or rained-out: Press E to add firewood, then Press E to light (uses one plant fibre as tinder; open fires will not light in rain). A placed campfire (10 stones and 20 sticks) starts lit with 20 sticks of fuel: a stick burns 2 game minutes, firewood 30, a log 2 game hours (1 game minute = 2.5 real seconds) |
| E at a lean-to | Hold E (0.6 s) takes it down |
| E at the water's edge | "Press E to drink" shows when water lies at your feet or a step or two ahead and you are not full: one mouthful (300 ml, 13% of a full body) per press, about one a second at most. Needs at least one drink a game day (a full body lasts a whole day); the Water bar at the top of the inventory screen shows it, a drop symbol appears under 15%, and when parched health stops recovering. Plants and loose items in reach take the prompt only when water is not ahead |
| E at the water with a water container in hand | "Press E to fill": 500 ml per press into the bowl, pot, bucket or waterskin you hold (hotbar key to hold it); a full one lets E drink from the water as before. With a container that holds water in hand, E away from water drinks a mouthful (300 ml) from it; Use (E) in the inventory does the same. A container shows its water in the slot name and tooltip; its water counts as carry weight (1 kg a litre) |
| E | Gather: the prompt only says "Press E to gather" (it never names the item) and shows only when something pickable lies in the general direction you look (a wide cone, about 70 degrees each side; anything within 0.8 m always counts). Tap E takes the nearest loose item in view within 3 m, or with none, the nearest pickable plant or shrub in view within 2.5 m. Hold E (after 0.35 s): takes one thing at a time, about 5 a second, from anything within 2 m around you whether or not you look at it, until nothing is left in reach or the pack is full (let go of E to try again). A missing tool or a full pack or too far gives the refusal cue and a short message, not a different prompt. Roots and bulbs need a spade, bark, gum and sap a stone knife, wood an axe; a picked plant bears again after 3 game days |
| Right click (tap) with food or medicine held | Eat it / apply it (the health, exertion, food and water bars are at the top of the inventory screen; there are no bars on the main screen). The inventory panel's "Eat / use" button does the same for the selected slot |
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
- E is the standard interaction key. The centre-screen prompt ("Press E to ...") shows when it will work or why not, and vanishes on pick, with no message after picking. Tap E acts once, hold E (0.6 s) does the heavier action (take a structure down); holding E near loose items and plants keeps gathering one at a time.
- Shift+E is the safe take-down variant at the chopping block (plain E uses it).
- Left click uses the held item; right click is the secondary (aim a throw, eat/apply).
- Effect symbols (brain, ghosted house, more later) sit side by side in one row at the top, recentred.

## Planned / not decided

- Stances (Dave, 2026-10-20, decided, build 229 Ground thread, not built yet): C = crouch, X = sit, Z = lie down, all toggles; any movement key stands you up. No movement while sitting or lying. Admin dig moves from X to Ctrl+X (the table row for X changes when it lands).

- Spear (Dave, 2026-10-20, decided, not built): normal attack keys jab; hold right click to raise and aim a throw, left click throws, release right click returns to normal stance.

- Dave's other two "things" from the old design (not yet given).
- Potions, horses and dragons will move much faster than running; ground loading is built to keep up.

- Carrying: no key; the inventory panel shows "Carrying x of y kg". Up to 80% of what you can carry nothing slows you; past that a heavy pack slows walking, jogging and running smoothly; flying is unaffected.
- Rest (Ground adds the keys: C crouch, X sit, Z lie, all toggles; any movement key stands you up): sitting or lying brings exertion down to 0, lying fastest; standing under a heavy pack only rests it to about half. Over-exerted: about 10 percent slower (tunable over_speed_factor in exertion.json) but you can keep running and keep pushing until you black out. Past the faint threshold you black out smoothly, not in steps: right at the threshold it takes about 14 s and you lie down at the end, and the further over you push the faster it comes on (about 1.5 s a long way over). The heart beats about 175 bpm at the threshold and 200 at the peak of a blackout; there are no breathing noises. Then you wake slowly.
- Picking a plant or shrub now removes it from the world (like a stone); out-of-season or empty plants show no prompt at all.
| Text - / Text + (crafting screen, click) | Smaller or larger text on the crafting and inventory screen (small, medium (default), large, extra large); saved with the display settings. Esc > Settings > "Crafting screen text size" cycles it too. Craftable recipes are green, the rest greyed out |
| Sort drop-down (inventory, click) | Unsorted (order the item kinds were picked up), name, weight (ascending or descending) or value (ascending or descending). It only changes where the slots sit on screen; the choice is saved with the display settings. Values are placeholder prices in items.json |
| E, D, S, R, T (inventory or chest screen open) | Quick keys on the slot under the mouse (else the selected slot), also on the buttons: Use (E) eats, applies a medicine, or holds a tool (a tool deep in the pack moves to a free hotbar slot first; pressing it again puts it away), Drop (D) drops the stack (Shift+D drops one), Split (S) halves the stack, Repair (R) repairs a worn tool, Transfer (T) moves the stack between your pack and an open container (chest screen only). Outside the screen E is the interact key and D and S are walking; while the screen is open WASD does not move you |

## Swimming (build 377)
In deep water (over about 1.3 m) you float at the surface and swim at 2 m/s (Shift: 3 m/s, tires you faster). Space swims up, Ctrl dives. Walking into a bank or ice edge less than about 1.1 m above the water pulls you out. Wading slows you in water over the knees. Under a floe or ice sheet you drift to open water; frozen in with no gap you come up through the ice. Swimming counts as work: the server prices it from your position.

## Filling ground (build 378)
With a spade in hand, right click fills the ground under the crosshair (one shovelful of soil, sand, gravel, clay or stone from the pack per fill, 0.9 m round, within 4.5 m). Fills are saved like digs and survive restarts and re-bakes; water rises or stops at them.
