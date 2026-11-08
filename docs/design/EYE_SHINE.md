# Eye shine at night

What a player should see when light finds an animal's eyes in the dark, and how the game draws it. Knowledge first, then the code.
It extends the torchlight shine of #596 (EYE_SHINE_AND_WET.md: per-species `shine_color` and `shine` in models.json).

## How it works in life
- Many night-active mammals have a **tapetum lucidum**, a mirror layer behind the retina that sends light back out through it a
  second time. The light leaves the eye almost exactly the way it came in, so it acts as a **retroreflector**.
- So you only see the glow when **the light is close to your own line of sight**: a torch in your hand, a headlamp, or a low moon
  behind you. A torch held by someone 10 m to your side lights the animal, but its eyes glow for them, not you.
- The animal has to be **looking roughly at you**: inside about 60 degrees of its gaze the glow is there, strongest straight on.
- **It carries.** Two points of light show far beyond where the body can be made out, which is why a torch sweep across a field at
  night turns up pairs of eyes long before any shape.
- **It fades as the angle opens** between the light and your eye, from the animal's point of view. At 30 m a torch at your hip is
  about 1 degree off and glows fully; up close the same torch is 10 degrees off and the glow is much weaker; past about 12 degrees it
  is gone.

## Colours by species
| Animal | Glow | Game row |
|---|---|---|
| Deer, elk | green-white | deer `#e6f5dc`, shine 3 |
| Wolf, dog | yellow-green | `#c8dc5a`, 3 |
| Fox | yellow-green, pale | `#dcf0b4`, 3 |
| Cats (lynx, puma, lion, leopard, tiger, house cat) | green | `#b4e05a`, 3 |
| Bears | orange-red | `#f09a3c`, 2 |
| Horse, donkey | blue-green | `#5ac8b4`, 2 |
| Cattle, buffalo, wildebeest | green | `#64c896`, 2 |
| Goats, sheep, chamois | yellow-green | `#a0d26e`, 2 |
| Owl | red | `#e0583c`, 1.5 (pending model) |
| Rabbit, rat | faint red (no true tapetum; the red is blood behind the retina) | `#dc3c32`, 0.5 |
| Pigs (boar, warthog), most birds, humans | none | shine 0 |

## In the game (flag `eye_shine`, off)
`_eye_shine_night` in animal_view.gd replaces the torch-only shine when the flag is on:
- **Lights:** the player's own held torch (`torch_light`), and the moon from the client's day cycle (`night_light`: night level,
  moon phase, direction to the moon). Daylight turns it off (night below 0.15, full from 0.4).
- **Retroreflection:** each light gives 1 - angle/12 degrees between eye-to-light and eye-to-viewer, so a torch in hand glows strongly
  at range and weakly up close, and the moon only when it is behind the player.
- **Facing:** full when the animal's head is within 30 degrees of the viewer, gone past 60.
- **Torch reach:** six times the torch's light radius, falling off with distance squared. The moon counts half as much as a torch.
- **Far-off dots:** for every species with placed eyes (`eye_bones` or `eye_offset`), each eye carries a small additive point that is
  the same size on screen at any distance, shown from 8 m out (fully from 15 m), so two eyes read in the dark far past the body.
  Species whose files have their own eye surfaces glow on the eye material only.
- **Cost:** one angle test per drawn model animal with eyes, and two quads each.

## Check
Run sheet m36 (deer, wolf, cat, bear and horse at night, a torch at the camera, 30 m off: two coloured points each) and m37 (the
same by full moon behind the camera, no torch: fainter points).
