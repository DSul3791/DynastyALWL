# Spyglass (design, Steve, 9 Nov 2026)

Dave, 17:23 local:

> "a spyglass of sorts. there should be different tiers of spyglasses. a simple one that is simple and fixed. a more complex one made from better materials and is more durable and probably variable focus and lighter, and the top tier that will be made from the finest of materials, rugged, has the best zoom of all and can tell you stuff about animals like their names, levels and health. but for now I need an admin spyglass so I can watch animals from distance"

The admin spyglass is built. Tier 1 of the player spyglass is built too (10 Nov 2026, see "Tier 1, built" below); tiers 2 and 3 come later, from this page.

## Player tiers

| Tier | Name | Materials (first pass) | Zoom | Focus | Durability, weight | What it tells you |
|---|---|---|---|---|---|---|
| 1 | Spyglass | wooden tube, leather strap, 1 crystal lens | 3× fixed | fixed: a soft blur closer than 20 m | 200 uses, 0.6 kg | nothing |
| 2 | Brass spyglass | bronze or copper tube, leather, 2 glass lenses (or crystal) | 2× to 6× on the wheel | variable: sharp at any range | 600 uses, 0.4 kg | nothing |
| 3 | Fine spyglass | steel tube, tanned leather grip, 3 ground glass lenses (or crystal) | 2× to 12× on the wheel | variable | 2,000 uses, rugged (no break on a fall), 0.35 kg | the animal at the centre: its name, level and health |

- **Lenses (settled 9 Nov 2026).** Tier 1 uses a lens of polished clear quartz, a "crystal lens". It is a rare find when breaking rock and gravel, so a player can make a spyglass early, with no developer gate. Tiers 2 and 3 use kiln glass once glass arrives (items review stage 2: sand fired in the kiln/smelter). A crystal lens is still allowed in any tier, as an alternative with its own character: a little less zoom and a faint tint, but it never cracks. That follows Dave's "no stupid developer rules".
- **Use.** Hold the spyglass in hand. Right mouse looks through it, and the wheel zooms on tiers 2 and 3. Looking through it narrows the field of view and slows the mouse by the same factor. A dark round vignette frames the view. Each look costs one use of durability.
- **Animal range.** Animals are only sent within 120 m of a player, and only exist out to about 300 m. While looking, the tiers raise that: tier 1 to 150 m, tier 2 to 220 m, tier 3 to 300 m.
- **Tier 3 readout.** It needs the server, as the admin version below does, but without the admin check.

## Tier 1, built (10 Nov 2026)

- **Item.** `spyglass` (557), tool_class `spyglass`, tier 1, 200 uses, made at a workbench from a wooden block, a leather strap and a crystal lens (Jamie's data PR). Numbers by tier are in `data/items/spyglass.json`.
- **Use.** With the spyglass in hand, hold the right mouse button to look; let go to lower it. Esc or Ctrl+L also lowers it. Putting it away or breaking it lowers it.
- **View.** The same view as the admin glass (vignette, field of view by the zoom, the mouse slowed by it), at a fixed 3×. The wheel does nothing at tier 1. Closer than 20 m is soft (the camera's near depth-of-field blur, `blur_near_m`), so it is a far-seeing glass, not a magnifier. No readout: tier 1 tells you nothing about the animal.
- **Server.** ACT_SPYGLASS a = 2 with the pack slot in `count`. The server checks that the slot holds an unbroken spyglass (no admin check), wears one use per look (not per resend), and sends the animals within the tier's `send_radius_m` 150, nearest `cap` 40. No item or a broken one: refused (animal_info −1), the client's glass comes down. The admin glass (a = 1) is unchanged. No protocol bump: an older server reads a = 2 as "not looking" and sends the normal 120 m.

## Admin spyglass (built)

- **Key.** Ctrl+L, in the Admin and debug group of the key list, so it can be rebound. It needs no item and no icon.
- **Who.** Admins only, on the existing admin check (`server_admin.gd` `is_admin`). With `check_admin` off, which is local play and the current setting, everyone is an admin. On a public server the server refuses a non-admin, and the client gets nothing extra.
- **View.**
  - The wheel zooms 2× to 40×, starting at 4×.
  - The field of view is 2·atan(tan(37.5°) / zoom), so 75° at 1×.
  - The mouse slows by the zoom.
  - Each wheel notch multiplies or divides the zoom by 1.25.
  - There is a round black vignette with a centre dot.
  - Esc or Ctrl+L again leaves, and the field of view goes back to normal.
  - It does not work inside the photo camera.
- **Animals.**
  - While an admin looks through it, the server sends the animals within 300 m, the despawn distance (all that exist round you), nearest 60. Normally it is 120 m, nearest 30.
  - The client draws up to 60.
  - The animal nearest the centre dot, within 3° divided by the zoom, is "watched".
  - The watched animal keeps living past the 200 m freeze line and is not sent off for the hour, so it never stands still as a statue.
- **Readout.** For the watched animal, the server sends its info twice a second (protocol 102, rpc `animal_info`). The panel under the dot shows:
  - the species name and "young" if it is young;
  - its level;
  - health, as current/full;
  - what it is doing: grazing, moving, fleeing, alert, drinking, warning, charging and so on;
  - its temperament;
  - distance in metres;
  - its herd or pack id.
- **No flags.** It ships on, gated only by the admin check.

**Later (not in this PR):** the three tiers as items with recipes, the in-hand model and the durability. These reuse the same view code, with the zoom range and readout taken from the item row.
