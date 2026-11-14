# Building tiers: the looks as built (current to main bd3146aa, 11 Nov 2026)

Owner: Kathleen (art). This page says how each building tier LOOKS in the game today and where that look lives in code. Costs, ids, stations and rules are not here; they are in `docs/design/item_system.md` (s13, s17), `docs/design/progression.md` and `data/items/blueprints.json`. The 22 Oct design pictures this page used to describe (old tier names Basic, Plank, Fine wood, Log, Cobblestone, Mason) are superseded and archived in `docs/archive/2026-11/BUILDING_TIERS_LOOKS_2026-10-22.md`.

## The ladder (shipped)

Display names are "Tier - Piece" (sentence case). The look keys still carry the old material word; ids never change.

| Tier (display) | Look key prefix | Walls | Roof covering | Ceiling / floor |
|---|---|---|---|---|
| Crude | `thatch_` | stick frame and rails filled with thick courses of straw bundles (`thatch_wall`) | thatch (`thatch_roof`, `thatch_roof_corner`) | sticks and thatch (`thatch_floor`) |
| Rustic | `log_` | round logs (`log_wall`) | bark shingles on split-log boards, log ridge, log posts | split logs flat side up on three joists |
| Refined | `wall_section` / `wood_` | planks (the original wood pieces) | split wooden shakes on sawn boards, board ridge | planks |
| Sturdy | `stone_` | cut stone blocks (`masonry_wall("stone")`) | slates on boards, stone ridge slab, flagstone verge | boards, a mortar bed and four big flagstones on three joists |
| Superior | `brick_` | fired brick (`masonry_wall("brick")`) | fired clay tiles with round ridge tiles | brick on boards on three joists |
| Engineered | `engineered_` | plain cast concrete, board-form tie lines, cast coping | deeper red clay tiles on planks (#972: NO concrete roof) | cast slab, no joists |
| Fortified | `fortified_` | concrete with iron bands bolted through, iron strap up each end, plinth course | none (wall top with battlements instead) | as Engineered |

Dave's words that set this (10 Nov 2026): the tier pieces get looks as a "placeholder type of blueprint until our department can create a better looking blueprint and actual design"; walls, ceilings and roofs must fit the tiers; roofs need their own material ("bandit concrete would not make a good roof").

## Roofs (#973)

- Straight roofs above Crude (GOALS-REPAIR A-35/A-36, 14 Nov 2026): `piece_look.tier_panel(kind, slope_deg)`, the Crude panel's shape (no posts, 2 m wide over a 2 m run) in the tier's `ROOF_SPEC` cover: boards, courses with proud low edges, tile ribs on the clay tiers, three rafters, a fascia; `<Tier> - Roof 45` and `<Tier> - Roof 65` (`*_roof_65`, `roof_65`). Fortified (Dave, 14 Nov 2026: every tier has both) is the Engineered tiles a shade darker with two iron straps across (`ROOF_SPEC["fortified"]`). Placeholder look, NEEDS PLAYER VERIFICATION.
- Corners (GOALS-REPAIR A-37, 14 Nov 2026): `piece_look.roof_hip(kind, slope_deg)`, a hip over the 2 m corner square where two wall tops, ceiling edges or panel ends meet, no posts: two triangular faces at 45 or 65 degrees (`*_roof_corner`, `*_roof_corner_65`) in the tier's `ROOF_SPEC` cover (thatch for Crude), a cap along the hip, eaves along both low edges, one convex collider per face. Placeholder look, NEEDS PLAYER VERIFICATION.
- Rows are real geometry (no texture tiles): the edge of every course shows against the sky.
- Triangle caps: every roof panel and corner is under the default 300 (`test_look_table.gd`).
- Crude keeps the older thatch builder (`thatch_roof`), now a sloped panel with no posts: `Crude - Roof 45` (`thatch_roof`) and `Crude - Roof 65` (`thatch_roof_65`), BUG-011; it rests on wall tops and ceiling edges (`placement_rules.gd` `roof_panel_spot`). The Crude doorway is an open frame with no door (BUG-010).

## Fortified (#989; world shots by Dino 10 Nov, passed)

- `concrete_wall(true)`: 0.3 m thick, plinth course at the foot, two iron bands across both faces with bolt heads, an iron strap up each end.
- `concrete_gap` banded (Fortified doorway): iron-clad door (`_iron_door`), drop-bar brackets and the bar; open twin swings the leaf in.
- `fortified_gate`: lintel 2.0 x 0.24 x 0.3 at 2.52 m, iron stiles, diagonal brace, pintles; open twin swings it out.
- `fortified_wall_top`: merlons at x ±0.5 (0.6 wide) with arrow slits; reads as a continuous battlement over pillars (joint check `kathleen/fortified_wall_top_joint.png`).
- `concrete_foundation(true)`: banded footing battered out; since #1017 both footing steps run down to the body's foot, so a dipped corner shows no ledge (Dino's beach shot read it as a 0.2 m float).
- Caps: Fortified doorway 450 (`FORTIFIED`); gate under the 300 c3c4 cap (264).

## Icons

Roof and corner icons: neither the roof panels (A-35/A-36) nor the hip corners (A-37) are in `tools/paint_look_icons.py` yet (no `tier_panel` or `roof_hip` in `tools/look_runtime.py`); their old icons wait for a PC re-render. Counts in `docs/ui/item_icons.md`.

## Pictures (shared folder)

`/mnt/project-files/kathleen/roof_ladder_sheet.png`, `fortified_sheet.png`, `fortified_wall_top_joint.png`; Dino's world shots `/mnt/project-files/fortified_world_*.png` and `fortified_beach_*.png` (11:00, beach sand at 52752, 67792).

## Not built yet (future looks, in design notes)

Log bridge, Mine brace, Wooden ladder, half-timber Refined wall, Plank and Mason tiers, 65° roofs, shutters, chimneys, gutters. Large forge look is parked (code parked).
