# Playtest Repair Mission 001: environment (TEST-007, TEST-011)

Dave's playtest findings of 12 Nov 2026, environmental realism (priority 4). Base: `origin/dev` at `b922cc88a59586dfbd41f806744d9ccedfe2bf26`. Branch `claude/project-thread-ebb1tq`.

## Ledger

| Test | Status | Evidence |
|---|---|---|
| TEST-007 Tree canopies missing central foliage | NEEDS PLAYER VERIFICATION | Cause found and fixed in the tree models; `test_canopy_cover` written. Not yet seen on screen; Godot tests not yet run on the PC. |
| TEST-011 Campfire smoke disappears at canopy height | NEEDS PLAYER VERIFICATION | Tall plume added; `test_fire_smoke` extended. Not yet seen on screen; Godot tests not yet run on the PC. Seen from 100 m at most (see limits). |

## TEST-007: cause

Not culling, LOD or rendering. The player's own 64 m cell always draws the full model (`flora_view.gd` `_level`), leaf cards are drawn double-sided (`cull_disabled`) and the leaf textures have no mipmaps (`mipmaps/generate=false`), so cards do not thin out at a distance.

The gap is in the models. The limb-built hardwood crowns (`tree_builder.gd` `_maple`, `_beech`, `_oak`, `_chestnut` for sweet chestnut and walnut) hang every leaf clump on the limb tips, and the limbs spread outward to the crown's egg-shaped shell (`_maple_limb` and `_oak_limb` add an "away from the centre" push to every child limb). Nothing fills the upper middle of the crown over the trunk, so looking up from under the tree the sky shows straight through it. Conifers (spruce, fir) are covered overhead; Scots pine is open by design (a light canopy).

Measured with a Python port of the builders and the real leaf textures (alpha 0.5 cut, as the foliage shader): the share of the sky within 20 degrees of overhead covered by leaves, standing 1 m from the trunk, 16 builds per species:

| Species (reference height) | Before | After |
|---|---|---|
| Oak (19.5 m) | 26% (worst 5%) | 82% (worst 74%) |
| Maple (15.5 m) | 67% (worst 47%) | 90% (worst 84%) |
| Beech (17 m) | 74% (worst 59%) | 92% (worst 88%) |

About one crown in eight is meant to be dying, with a wedge of its upper crown bare (`_crown_variety`, moderator 31 Oct 2026); that is unchanged and will still show sky.

## TEST-007: fix

`tree_builder.gd` `_crown_core`: a few leaf clumps under the top of the crown's egg, spread over the middle of its width (golden-angle disc), each with one card laid nearly flat (`_clump` `flat` 0.3; the default 1.1 is unchanged for every other caller). 14 clumps for maple, beech, sweet chestnut and walnut, 22 for the oak's wider, flatter dome. Near models only, summer and autumn models only (not the bare winter one), and its own random stream, so every other card of every tree is built exactly as before.

Cost: about 42 cards (84 triangles) on a 700 to 900 card maple or beech crown (about 6%), 66 on an oak's 560. Not measured on the PC (Ponytail: unmeasured).

## TEST-011: cause

The campfire plume (`building_look.gd` `_campfire_smoke`, `data/look/fire_smoke.json`) lives 20 s and slows as it rises, to 40% of its start: in a calm it has thinned to a third by about 7 m and is gone by 11 m; in a 1 m/s breeze it gets about 5 m up. The crowns about it stand 15 to 35 m.

## TEST-011: fix

A second, sparse "tall" plume on every lit campfire (`_tall_smoke_plume`, every number in `fire_smoke.json` "tall"). Its puffs leave the flames with the near plume but are unseen for their first 6% of life (the near plume is the smoke there), then carry the column on for 60 s, slowing, spreading to about 8 m wide and fading. It follows the same world wind as the near plume (`set_fire_air`, once a second).

| Air | Where a puff is at 70% of its life (still about a quarter as thick) |
|---|---|
| Calm | about 44 m straight up |
| 2 m/s breeze | about 34 m up, 43 m downwind |
| Still clear night | rises to about 30 m and spreads flat there (the cold air holds it down) |

Performance limits: 24, 36 or 48 puffs per fire (small, medium, large), stepped at 10 fps with interpolation, so the warm start costs the same 600 steps as the near plume's; only the 6 lit fires nearest the camera draw it (the rest are hidden, so not simulated, and start again warm when they come back into the nearest six). A fire past the nearest six starts hidden, so it never pays the warm start. Not measured on the PC.

Limit (a `shortcut:` comment in the code): a fire is drawn only while the server sends it, within 100 m (`server_items.gd` `NEAR_M`). So the smoke is seen from up to 100 m, not from a hill farther off. Seeing camps from farther needs the server to send a list of distant lit fires (a network change in a shared server file); left for Dave to decide.

## Tests

| Test | What | Run |
|---|---|---|
| `test_canopy_cover` (new) | builds the near models of maple, beech, oak, sweet chestnut and walnut as the game does and checks leaves cover at least 92% (oak 82%, all four oak variants) of the sky within 20 degrees of overhead (card shapes; to be calibrated on the first PC run); no leaves, so no core, on the winter model; the core is near-only and inside the crown | NOT RUN |
| `test_fire_smoke` (extended) | the tall plume: unseen at the fire, above 35 m in a calm and 25 m in a breeze, stops at about 30 m on a still night, spreads, cull box holds it, warm start no dearer than the near plume; the nearest-six cap and its hand-over when a fire goes out | NOT RUN |

Godot runs only on Dave's PC; nothing has run yet. The selector picks 202 fast tests (the shared `tree_builder.gd` and `building_look.gd`); a scoped plan is proposed in the PR for the gate reviewer.

## What Dave should look at

1. Stand under an oak, a maple and a beech in summer and look straight up: the middle and top of the crown should be leafy, with only small gaps.
2. Light a campfire in a forest and step back 30 to 80 m, or climb a nearby rise within 100 m: the smoke should climb past the treetops, lean with the wind and spread into a haze.
3. Light six or more fires close together and watch the frame rate.

## Review

Independent gate review of c7175588: PASS WITH FIXES. Fixed in the next commit: the cap test now builds its fires after the scene tree starts (`_initialize` + `await process_frame`); a tall plume past the cap starts hidden; each plume is ranked by its own viewport's camera; per-species canopy thresholds, oak variants 2 and 3, and a winter check. Open for Dave's look: the small (one-rock-ring) fire now also sends smoke up over the trees; TEST-011 is partial past 100 m.
