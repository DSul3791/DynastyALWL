# Flight rigs: golden eagle, raven and owl (MikeW, 8 Nov 2026)

The golden eagle, the raven and the owl are on Dave's Meshy list (the pack has no realistic eagle, raven or owl; its stylized eagle breaks the realistic art rule). This note says what each model must bring so it drops into the game with the existing tools, and what the server and client need for a single bird that flies (today only flocks fly: ducks and gulls take off together in state 15, `server_flocks.gd`).

## 1. What the model must bring (for Dave's Meshy work)
- **One rigged mesh, wings folded in the rest pose.** A bird imported with its wings spread is sized from that pose (the crow needed `size_clip`); folded wings avoid it.
- **Faces one axis, any units:** the row's `yaw_deg` turns it and `length_m` sizes it (bill to tail).
- **Clips, looping where marked, with no travel in them (in place)**:
  | Role | Clip | Loop |
  |---|---|---|
  | perch / graze (0) | standing, head turns, preening | yes |
  | alert (3) | head up, wings tight | yes |
  | walk | a few hops or steps (ravens walk; eagles and owls hop) | yes |
  | takeoff | jump and first wing beats | no |
  | fly (15) | flapping | yes |
  | glide (17, new) | wings held, small adjustments | yes |
  | land | flare and touch down | no |
  | attack (11) | talons forward (eagle and owl) | no |
  If Meshy's auto-rig gives no clips, the gait builder (`gait` in a model row) can make the loops from bones: wing beat = shoulder and elbow swing on one axis, glide = a held wing angle with a slow roll; the creature check shows them before use.
- **Bone names stay as exported;** the row maps clips by name and the gait by bone name, so nothing in the file needs renaming.

## 2. Server: a single bird that flies
A row key `"flight": {"cruise_m": 30, "soar_m": 120, "fly_mps": 12, "glide_share": 0.6, "perch": "tree"|"cliff"|"ground", "night": false}`.
- States: perched (0), alert (3), takeoff (15 with a timer), flying (15), gliding (17), landing (back to 0 at a perch). The bird's height is the ground plus `cruise_m` while flying; an eagle soars at `soar_m` in wide circles over open ground (the updrafts of the guiding document's `sky` key can steer this later).
- Perches: `tree` uses the flora canopy hook already used for forest habitat, `cliff` the slope test (a spot steeper than `slope_max` beside a drop), `ground` any open spot.
- Spook: a perched bird takes off at `spook_m` and lands at a perch beyond `safe_m`, the same flee logic with a height.
- The raven follows a player at a distance (it does in life near hunters) and lands at a carcass: later, with the carcass hook.
- The owl is active at night only (`active`), silent in flight (no step or wing sound).
- Wire: the same five values per row; the height is already in the position. State 17 is new; the client falls back to 15 for an older row.

## 3. Client
- Roles 15 (fly) and 17 (glide) are air states: they play their own clip at any speed (`AIR_STATES`, added for the duck flock); add 17 to it.
- Takeoff and land play once, then the role's loop.
- Eye shine: eagle and raven none (birds have no tapetum); the owl has none either, but its large eyes catch the torch as an ordinary highlight.

## 4. Order
1. Dave's models (eagle first: biggest sight in the sky).
2. Install with `tools/install_animal_models.py`, check every clip with `tools/creature_check.gd --clips`.
3. Species rows with `tools/add_species.py` (raven and owl have carcass and sign rows already; eagle has its carcass row).
4. The server flight states and test (a perched bird takes off when a player comes close and lands beyond `safe_m`, never below the ground), then the client glide role.
