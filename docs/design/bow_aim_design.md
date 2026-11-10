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
| Wobble | After that the aim sways a little, a slow figure of two sines (`wobble_hz` 0.6). The sway grows by `wobble_deg_per_s` (1.5°/s with no skill, 0.3°/s at 100) up to `wobble_max_deg` 4°. |
| Loose | Left click while drawn fires at the reticle. If the right button is still held, the bow draws again for the next arrow. |
| Lower | Let go of the right button and the bow goes back to the ready stance (both hands on it, an arrow nocked, Kathleen's pose) with no shot. |

## Bow skill

The bow skill is the hunting skill's working level, from 0 to 100. Every curve is a list of [level, value] points with straight lines between them.

- **Steady time and wobble:** as in the table above.
- **Aim assist (client):** each animal in view has two vital zones, the head (0.45 m forward, 0.8 m up) and the heart (0.15 m forward, 0.5 m up). The zone nearest the reticle, within `pull_cone_deg` 4°, draws the aim toward it by the `pull` share. The share is 0 with no skill (no snap at all), 0.05 at 10, and 0.6 at 100. The reticle shows where the arrow is aimed after the pull.
- **Spread (server):** the server turns every shot at random by up to `spread_deg`. That is 2.5° with no skill (about 0.9 m off at 20 m), 1° at 50 and 0.2° at 100. Luck narrows the draw, as it does everywhere else.
- **Damage (server):** the arrow's damage × draw power × `damage_mult`. The multiplier is 1.0 with no skill, 1.25 at 50 and 1.6 at 100.

## Server authority

The client sends the bow slot, the draw time, the loaded arrow and the aim direction. The server clamps the draw time and keeps the pace check, as before. It checks that the loaded arrow is ammo and is in the pack, and otherwise takes the first ammo. It applies the spread and the damage from its own skill record. The aim assist only turns the direction the client sends, which a player could already aim by hand, so it gives a cheat nothing.

## Sighting along the shaft

Dave: "the string should always be inline with the bow wooden part. then you place the arrow over the left side and then draw back and sight along the arrow shaft." Kathleen's pose (#887) holds the grip, the string and the drawing hand on one line about 10 cm under the eye, with the nocked arrow on the string and resting over the left of the bow hand. It shows while the bow is up and the pack has an arrow. So the shaft points where the eye looks, and the reticle stays in the middle of the screen with no offset. The shot leaves along that same eye line.

## No held-item line

Dave: "it doesnt need to say wooden bow in hand. or anything. on the hud like that". The line over the hotbar no longer names what either hand holds, and it gives no how-to hints. It shows only a state the player must know: the picked blueprint and why it is red, the hammer's mode, why a placement is red, and the spade's or hoe's mode (`held_item._caption`).

## Not in this change

- The bow's size (about 1.7 m) and how it is held are Kathleen's, in a separate PR. Her pose reads `bow_state()` ("idle", "raised" or "drawn") and `bow_draw()` (0 to 1) from held_item.
- Carts and pack animals don't exist yet, so arrows come from the pack only.
