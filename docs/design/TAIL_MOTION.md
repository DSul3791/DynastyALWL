# Tail motion laid over the clips (MikeW, 8 Nov 2026)

A tail says a lot: a dog wags by its owner, a cat or lynx flicks the tip when it watches something, a horse or cow swishes at flies while it grazes in summer. None of the pack's clips does these on their own, and they must play on top of whatever clip is running.

**How:** the bone-offsets modifier (`src/client/bone_offsets.gd`, the crow's posture fix) also swings chosen bones after the clip: each tail bone turns about one of its own axes by `swing × sin(2π(t / period + phase))`, the phase stepping down the tail so the motion travels to the tip. A model row says:
```
"tail_motion": {"period_s": 0.4, "when": "rest", "bones": {"Tail01": [0.0, 12, "y"], "Tail02": [0.08, 14, "y"], ...}}
```
`when` sets how much it swings (eased in and out):
- `rest` (dog): full while standing, sitting or lying still (states 0, 12, 18, 19), a little while moving.
- `alert` (cat, lynx): full while alert or stalking (3, 6), a slow twitch otherwise.
- `flies` (horse, donkey, cow, wild ox, wildebeest): full while grazing still, less while walking, and only in spring and summer (`season_now`, set by the client when it knows the season; unknown counts as summer).

**Rows set now:** dog (both looks), lynx, cat, horse, donkey, cow, wild ox, wildebeest; bone names read from the model files, axes a first guess (side to side about the bone's own up axis) until the creature check shows them. The check needs a moving picture, so the PC check is a short clip of frames (or the live game), not a still strip.
