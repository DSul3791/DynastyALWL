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
