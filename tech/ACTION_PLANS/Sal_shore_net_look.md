# Action plan: the shore net looks like a net (Sal)
Branch: claude/sal-net-look (from generator-v2 8bb28cc4). Dave 25 Oct: the held shore net looked like a small hammer.

## Cause
looks.json gives the shore net the shape "cloth" (a flat folded-cloth block). held_item.gd only turns shapes listed in HELD_LOOK_TURN (axe, pick, hoe, knife, spade, shaft), so "cloth" returns no held mesh and _make_other_model falls back to its generic tool: a 0.6 m stick with a 6 x 10 x 10 cm block on the end. That is the hammer.

## Fix
- New shape "net" in basic_look.gd (one match arm; the same mesh lies on the ground and is held): a 0.9 m pole, a 28 cm oval hoop at the head, a hanging bag of 8 twine strings and 2 rings (light twine colour), and 4 cork floats on the hoop. Reads as a net on a pole at normal tool size.
- looks.json: shore_net shape "cloth" -> "net" (item number and recipe unchanged).
- held_item.gd: one entry "net" in HELD_LOOK_TURN (same turn as the knife: pole in the hand, hoop forward). Three small hunks in Kathleen's two files (basic_look.gd, held_item.gd); kept additive so her grip and pose work merges cleanly. item_sounds.gd: "net" -> cloth sound.
- Test: test_net_look.gd: shore net look shape is net, the mesh builds, its long axis is 0.7 to 1.0 m, and it is held through the look path (not the fallback block).
- After the gate David3 re-shoots the held shore net set (hands10).
## Not in this plan
Torch head (wrapped head with flame) is the next small plan.
