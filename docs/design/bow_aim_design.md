# Bow: loading, drawing and aim (Dave 10 Nov 2026)

Dave's playtest note: the bow "doesn't work at all but it makes funny sounds". He then gave the whole flow, below. All numbers are in `data/items/bow.json` (the `"aim"` block). The shared rules live in `src/shared/bow_aim.gd`. The client draws with them (`src/client/held_item.gd`), and the server (`server_items._shoot`) takes the spread and the damage from them.

## Why it did not work

`fibre_arrow` is the only arrow made without feathers, so it is the first arrow a new player makes. It was missing from the `ammo` list in bow.json and from the client's `BOW_AMMO`. Every shot with fibre arrows ended at "You have no arrows", and only the draw sound played. Arrows that did fly were also invisible: the client drew nothing in flight, only the sounds. Both are fixed. The ammo list is now stone, bone, wooden and fibre, and the client flies a model of the arrow along the same arc the server steps.

## The flow

| Step | What happens |
|---|---|
| Load | Drag arrows onto the bow on the hotbar. The bow is loaded with that arrow type, and the bow's slot shows how many of them are in the pack. If the loaded arrows run out, or the bow was never loaded, the bow takes the first ammo in the pack (the bow.json order). |
| Raise | Hold the right mouse button. The bow comes up to sight, the string is drawn with the pull sound, a cross reticle shows in the middle of the screen, and the view narrows a little (`zoom_fov_share` 0.85). |
| Steady | For `steady_s` seconds at full draw the aim holds still. That is 2 s with no skill (Dave), 3 s at 50 and 4.5 s at 100. |
| Wobble | After that the aim sways a little, a slow figure of two sines (`wobble_hz` 0.6). The sway turns the whole view and the cross stays in the middle of the screen (see Sway below). It grows by `wobble_deg_per_s` (0.5°/s with no skill, 0.1°/s at 100) up to `wobble_max_deg` 1.2°. |
| Loose | Left click while drawn fires through the cross in the middle of the screen. If the right button is still held, the bow draws again for the next arrow. |
| Land | An arrow stops at the first animal, tree trunk or ground on its path. In a trunk it sticks at the hit point, along its flight, for `stuck_s` 300 s unless picked up (see Arrows in trees below). |
| Lower | Let go of the right button and the bow goes back to the ready stance (both hands on it, an arrow nocked, Kathleen's pose) with no shot. |

## Bow skill

The bow skill is the hunting skill's working level, from 0 to 100. Every curve is a list of [level, value] points with straight lines between them.

- **Steady time and wobble:** as in the table above.
- **Aim assist (client):** each animal in view has two vital zones, the head (0.45 m forward, 0.8 m up) and the heart (0.15 m forward, 0.5 m up). The zone nearest the middle of the view, within `pull_cone_deg` 4°, draws the view toward it by the `pull` share. The share is 0 with no skill (no snap at all), 0.05 at 10, and 0.6 at 100. Like the sway, the pull turns the whole view, so the cross in the middle shows where the arrow goes.
- **Spread (server):** the server turns every shot at random by up to `spread_deg`. That is 2.5° with no skill (about 0.9 m off at 20 m), 1° at 50 and 0.2° at 100. Luck narrows the draw, as it does everywhere else.
- **Damage (server):** the arrow's damage × draw power × `damage_mult`. The multiplier is 1.0 with no skill, 1.25 at 50 and 1.6 at 100.

## Server authority

The client sends the bow slot, the draw time, the loaded arrow and the aim direction. The server clamps the draw time and keeps the pace check, as before. It checks that the loaded arrow is ammo and is in the pack, and otherwise takes the first ammo. It applies the spread and the damage from its own skill record. The aim assist only turns the direction the client sends, which a player could already aim by hand, so it gives a cheat nothing.

## Sighting along the shaft

Dave: "the string should always be inline with the bow wooden part. then you place the arrow over the left side and then draw back and sight along the arrow shaft." Kathleen's pose (#887) holds the grip, the string and the drawing hand on one line about 10 cm under the eye, with the nocked arrow on the string and resting over the left of the bow hand. It shows while the bow is up and the pack has an arrow. So the shaft points where the eye looks, and the reticle stays in the middle of the screen with no offset. The shot leaves along that same eye line.

## Sway (Dave, 10 Nov 2026)

Dave: "the crosshairs shouldnt move around like they do the whole screen should move like that but much less. it my aiming thats moving not just the crosshairs."

- Each frame the client scene sets the eye camera back to the mouse's look. It then turns the camera by `held_item.bow_view_turn()`, the sway and the pull together, in degrees. `BowAim.turn_of` gives the turn from the aim that `aim_direction()` works out.
- The cross is drawn in the middle of the screen at all times, and the shot leaves along the camera's forward, through the cross.
- The sway is a third of what the cross used to move: `wobble_max_deg` went from 4 to 1.2, and `wobble_deg_per_s` from 1.5/0.8/0.3 to 0.5/0.27/0.1.
- The camera's own pitch and yaw are only offset while drawn. The mouse look (`pitch`, the body's yaw) is never changed, so letting go puts the view back where the mouse left it.

## Arrows in trees (Dave, 10 Nov 2026)

Dave: "I just stood right infront of a tree and shot an arrow and it did not hit the tree or stick into it. there should be an arrow in that tree until I collect it or it fades out in 5 minutes."

Before this change the server's arrow stopped only at an animal, the ground or its range, so it flew through trunks.

- **Server.** Each flight step asks `trunks_near` (terrain_server `_arrow_trunks`) for the standing trunks near the step. These come from the cached tree cells the hints use, and each trunk's radius is its collider's: the species trunk scaled by the tree's height. `BowAim.segment_trunk` finds where the step first meets a trunk's cylinder.
- **Breaking.** An arrow that hits a trunk breaks at its tip's `break_chance`, as on the ground.
- **The stuck arrow.** Otherwise it becomes a loose arrow at the hit point. It is not let down to the ground. It points along its flight (`rot_y` and `tilt`), lasts `stuck_s` 300 s and never joins another arrow's pile.
- **Saving.** A save writes it at the foot of the tree, lying.
- **Client.** The client draws the stuck arrow at its point, with its tip in the bark. The flying arrow model stops at the first collider it meets (a physics ray each frame) and waits there 1.5 s, until the server's stuck arrow is drawn. The thunk sound is "wood" when the flight meets an upright collider.

## No held-item line

Dave: "it doesnt need to say wooden bow in hand. or anything. on the hud like that". The line over the hotbar no longer names what either hand holds, and it gives no how-to hints. It shows only a state the player must know: the picked blueprint and why it is red, the hammer's mode, why a placement is red, and the spade's or hoe's mode (`held_item._caption`).

## Not in this change

- The bow's size (about 1.7 m) and how it is held are Kathleen's, in a separate PR. Her pose reads `bow_state()` ("idle", "raised" or "drawn") and `bow_draw()` (0 to 1) from held_item.
- Carts and pack animals don't exist yet, so arrows come from the pack only.
