# Critique: redrawn pieces in the real game (2026-10-30, Kathleen)

Rig: `tools/look_rig.sh --pieces NAME,... --views close:...`, spawn area, 12:00 clear. Severity 1 minor, 2 should fix, 3 must fix.

| Piece | Picture | Reading | Flaw | Sev | Action |
|---|---|---|---|---|---|
| Tool rack | row1_...jpg | reads as a wooden rack with a cross rail and shelf | small against trees; tools on it hard to tell at this distance | 1 | none |
| Vice | row2_remains_vice_path.jpg | first version: a tall bare stump with tiny jaws, read as a post | jaws too small for the stump | 2 | fixed: wider top plank, taller jaws, long screw with cross handle, iron bands (checked offline, not re-shot in game) |
| Remains | row2_...jpg | a brown pack with scattered bones and a few ribs | bones thin and few | 1 | thickened the bones (offline checked) |
| Snare trap | row1_...jpg | a thin bent arm and small wire loop; reads as a snare but is easy to miss | very small | 1 | open |
| Rock pile | row1_...jpg | a dark heap of rocks | in shadow; reads as a rock heap | - | none |
| Path patch | row2_...jpg | brown packed-earth patch with edge stones | edge stones large for a 1 m patch | 1 | open |

The white sphere that showed in row 1 where the remains should be was a loose STONE. Cause found: the six pickup models in assets/natural_pickups carry their colours in vertex colours, but the imported glTF material does not use them, so inventory_view painted every stone flat white (albedo 1.3 plus a glow). Stones are drawn at about 1 m (PICKUP_SIZE_MULT 3), so they looked like white spheres. Fix: vertex colours switched on in inventory_view._pickup_group, brightness 0.9, glow cut to 0.02. Pictures: stones_white_before.jpg, stones_after_dark.jpg (brightness 0.55, too dark), stones_after_mid.jpg (0.9). In the last the stone variants read dark slate to charcoal in this spot; the brightness still needs a look on open sunlit ground (unverified).

## Stone brightness check, second try (2026-10-30, Kathleen)

Two matched runs (`--ground-close stone:6` and `stick:6`, height 0.6 m, distance 1.2 m, pitch -40, noon, spawn point). Lesson: in the rig, down is a negative pitch; my first runs used +40 and photographed the sky. In the -40 pictures the camera looks down but neither pile is in frame (the player body sits at upper left and the middle is bare ground), so the close brightness is still NOT confirmed. What the frames do show: the small loose stones and sticks in the far ground at the horizon read as mid-grey and dark grey lumps in sun and shade, none chalk-white, so the white-sphere fault is gone. Brightness stays at PICKUP_BRIGHT 0.9 until a clear close shot exists. Next: frame the pile with `--ground-close` plus an explicit `--drop-dist` and a lower pitch, or add a rig hook that stands the camera on the pile.

Third try (`--yaw 25`, same settings): still no pile in frame; the player body is in the picture and the ground in front is bare. So the fault is in the rig (the drop spot is not where the close camera looks, or the dropped stones are not drawn yet at shot time), not in the stone look. Stone brightness remains unconfirmed; PICKUP_BRIGHT stays 0.9.

## Later evidence (2026-10-30, Kathleen)

- Stones on open sunlit grass: in the `--give log --cam left` frame (`shoulder_log.png`, same scene) the loose stones in the middle distance read grey and blue-grey in full sun, none white. This is as close as the rig has come to confirming PICKUP_BRIGHT 0.9; close up it stays **unverified in game**.
- Shoulder log: `--give log:1` and `--give log_oak:1 --cam left --dist 3` show no log on the shoulder (nothing is carried in third person here: `set_shoulder` in held_item.gd belongs to the first-person view, and the give probably needs `--admin`). Not seen in game; needs a first-person run (`--cam first`) with `--admin --give log_oak:1`, next.
