# Real-game fire shot (Kathleen, 2026-10-31)
Rig works again; the place/light shot still fails. Findings: (1) the shot was taken before the drop/place step: fixed (shot_runner waits for the drop and settle); (2) the place action goes to the kit's slot (slot 0, logged): the frame shows only the green placement ghost of the held kit at the spot (campfire_lit4.png, campfire_lit5.png), no placed fire, so the server did not place it (silent refusal: not found in the server log; suspects: PlacementRules.snap or the ground/reach checks in server_items._place, or the client needing a held-kit placement flow). campfire_lit.png / campfire_lit3.png: earlier frames (no place yet / grass hiding the spot).
Fallback: the laid, lit and burnt fires as built by the real builder in a direct scene: art/CRITIQUES/pictures_for_dave_2026-10-31/fires*.png (rating 3).
Next: send ACT_PLACE through the client's own place path (client.held ghost confirm) instead of the raw action, or log the server's refusal reason.

## 2026-10-31 evening: placed with Tyler's --dev-place (rig, hour 21)
- game_leanto_bed_fire_dusk_far.png (lean-to with rough bed, lit campfire 4 m in front, 9 m away): reads as a stick shelter with a fire; rating 3.5. The campfire light pool looks good.
- game_leanto_bed_close.png (front, 5 m): sticks, lashing, a bed with hay inside; rating 3.5. At dusk the thatch and bed are very dark; next to improve: nothing in the model, only light.
- game_lit_furniture.png (fireplace with `lit`, wall torch and chandelier placed beside it): the fireplace is placed and brick reads well, but it shows NO fire or glow and the torch and chandelier are not visible from this spot; so the `lit` state does not reach the client picture (client draws no flame or light for a lit fireplace, or the torch is out of frame). Not a model problem; needs the game side that draws the light (Tyler or the flame code).

## Lit fixtures with Tyler's client flames (branch claude/tyler-gates-fee5f7)
- game_lit_fireplace_torch.png: fireplace and wall torch, hour 21. The warm light pool on the ground and the glowing jambs read well; rating 4. Flames are small and come out cream-white, not orange (emission too high, so the colour clips); the fire fills only about a sixth of the opening.
- game_lit_furniture2.png / _close.png: chandelier at left, six candle flames visible, ground warm; rating 3.5 (flames tiny at 8 m).
