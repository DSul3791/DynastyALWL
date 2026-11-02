# Wooden club, stone mace, javelin, wicker shield (guide finding F-09), 2026-10-31, Kathleen

Cause of the white blobs: `BasicLook.entry()` only used my ART_OVERRIDES when an item had no row in looks.json. Sal's rows for these items are the grey placeholder chunk, so the override was skipped and the grey chunk (drawn near white) showed. Fixed: an override now also replaces a placeholder row (`_is_placeholder`: shape chunk, colour #8a8a8a). That fixes every override item with a grey row at once (club, javelin, flint, pyrite, obsidian, leather, rivets, ingots, tools, ores...). Offline preview note: items are lifted 0.06 m in tools/look_view.gd because models lie below their origin.

References: stone mace = pear or ovoid pecked stone head with a drilled shaft hole on a wooden haft, Late Neolithic to Early Bronze Age (Fitzwilliam Museum macehead records data.fitzmuseum.cam.ac.uk/id/object/49567, Penn Museum object 279574); wicker shield = round woven board, hazel rim, woven willow boss, flat handle (British Museum, "How to make an Iron Age shield out of bark", the Enderby shield).

| Item | Picture | Critique | Rating | Next to improve |
|---|---|---|---|---|
| Wooden club | club_after_override.png | recognisable club with a swollen head and a wrapped grip; head pale against a darker shaft | 3 | more wood grain tone, a knot, in-game check |
| Stone mace | stone_mace_round1.png (white head, too light), round2 (lighter grey), round3 (mid grey) | pear-shaped grey head on a tan haft with a wrapped grip and a lashing under the head, haft tip through the top | 3 | chips and hammer-dressed facets on the stone, in-game check |
| Wicker shield | wicker_shield_round1.png (all but the boss hidden under the preview ground: preview bug), round2 | round woven board: pale and dark rings out from a domed boss, hazel rim, radial stakes; reads as a wicker shield from above | 3 | back view with the handle and straps; held look (shields are offhand) |
| Javelin | not re-rendered | override is a light shaft with a metal head (set earlier) | 2 | stone or flint leaf-shaped head, a binding, fletching or a notch; needs its own rounds |

None of the four has been seen in the real game yet (the rig's dropped-item frames stay empty). Stone head colour #46433e after the preview's brightening.
