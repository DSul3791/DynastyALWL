# Wolf, seal, trout: critique of the PR 64 sheets (Kathleen, 2 Nov 2026)

Pictures: `wolf_pr64.png`, `seal_pr64.png`, `trout_pr64.png` on branch `claude/pics-pr64-20261102` (offline sheet, four views, no game light). Scale 1 to 5 (4 = reads as the real animal at 10 m).

## Wolf: 2 / 5 (round 1 was also 2; the change is barely visible)
- Reads as a grey dog-like animal from the side, but the legs are straight square posts with block feet: no elbow, no hock bend, no paw. This is the biggest problem.
- The muzzle is a pale box stuck on the front of the head; a wolf's muzzle tapers and is grey on top, pale only underneath.
- From the side the ears are a single thin stick. They should be wide triangles, upright.
- The body is two equal blobs, so the back looks humped. A wolf has a deep chest, a tucked waist and a straight back.
- The tail is good: bushy, held low, dark tip. Keep it.
- **Fix order:** (1) legs in two parts (upper and lower) with a backward hock on the hind legs and a forward-sloping pastern on the front legs, with tapered cylinders, not boxes; (2) a tapered muzzle: a cone or stretched ball, grey on top; (3) triangle ears; (4) a deeper chest ball and a smaller hip ball. Then a new sheet.

## Seal: 2 / 5, fixed in this branch (needs a new sheet)
- The dark blotches hovered above the skin toward the rear (they were all at one height while the body curves down). **Fixed:** each blotch now sits on the curved body or rear surface (`_make_seal`).
- The hind flippers lay as flat grey discs on the ground, apart from the body. **Fixed:** they are thicker, joined to the rear and tipped up a little.
- Still weak: the head reads as a ball on the body; the neck needs a slight thickening between them. The front flippers are fine.

## Trout: not ratable
- The fish is about 10 pixels long in every view: the sheet camera is set for a deer-sized animal. Re-shoot with the camera close:
  `godot --path . --script res://tools/shot_node.gd -- --script=res://tools/animal_sheet.gd --animal=trout --out=<path>/trout_close.png --height=0.4 --pitch=-10`
  (and a smaller distance if shot_node takes one). The earlier rating was 2 (spots read as studs, box tail).

## For the PC thread
1. A new seal sheet from this branch.
2. The trout close sheet above.
3. After the wolf leg fix, a new wolf sheet and one in-game shot at 10 m at night (the wolf is what players meet in the dark).
