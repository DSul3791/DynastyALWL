# Building tiers: appearance record (baseline 11 Nov 2026; doors updated 13 Nov)

Owner: Kathleen (art). This page records the building tier looks and their code locations. Non-door descriptions include an 11 Nov historical baseline; **BUGLIST-002 separate-door changes are already implemented on `dev` but still require player visual verification**. Costs, ids, stations and rules are not here; they are in `docs/design/item_system.md` (s13, s17), `docs/design/progression.md` and `data/items/blueprints.json`. The 22 Oct design pictures this page used to describe (old tier names Basic, Plank, Fine wood, Log, Cobblestone, Mason) are superseded and archived in `docs/archive/2026-11/BUILDING_TIERS_LOOKS_2026-10-22.md`.

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

- One builder, `piece_look.pitched_roof(kind, corner)`, driven by `ROOF_SPEC` (cover colour, rows of shingles or tiles, thickness, underside material, ridge style, posts, verges, post width). Pitch `ROOF_PITCH` 0.3 rad, half span 1.2 m, eaves at 2.45 m.
- Corners are hip ends (`*_roof_corner`), built by clipping the same rows (`_clip_band`), so the courses line up with the straight piece.
- Rows are real geometry (no texture tiles): the edge of every course shows against the sky.
- Triangle caps: default 300; clay-tile roofs 350 and their corners 400 (`TILE_ROOFS` in `test_look_table.gd`).
- Crude keeps the older thatch builder (`thatch_roof`), now a sloped panel with no posts: `Crude - Roof 45` (`thatch_roof`) and `Crude - Roof 65` (`thatch_roof_65`), BUG-011; it rests on wall tops and ceiling edges (`placement_rules.gd` `roof_panel_spot`). The Crude doorway is an open frame with no door (BUG-010).

## Fortified (#989; world shots by Dino 10 Nov, passed)

- `concrete_wall(true)`: 0.3 m thick, plinth course at the foot, two iron bands across both faces with bolt heads, an iron strap up each end.
- **Fortified doorway (`fortified_doorway`) is an empty, banded concrete frame**; the earlier iron-clad leaf, bar and integral open-twin behavior have been removed. A separate **Fortified - Door** is a riveted all-metal iron-and-steel door, built and attached by hammer blueprint. The same empty-frame/separate-door distinction applies to all seven tiers and four configurations; details are in `docs/design/DYNASTY_MASTER_ITEMS.md` §3.0 and `docs/buglists/BUGLIST-002.md`. Actual appearance is pending F6 verification.
- `fortified_gate`: lintel 2.0 x 0.24 x 0.3 at 2.52 m, iron stiles, diagonal brace, pintles; open twin swings it out.
- `fortified_wall_top`: merlons at x ±0.5 (0.6 wide) with arrow slits; reads as a continuous battlement over pillars (joint check `kathleen/fortified_wall_top_joint.png`).
- `concrete_foundation(true)`: banded footing battered out; since #1017 both footing steps run down to the body's foot, so a dipped corner shows no ledge (Dino's beach shot read it as a 0.2 m float).
- Historical (#989) geometry cap: old Fortified doorway 450 triangles; the separate-door implementation now has different geometry and needs F6 frame-rate/triangle review. The gate remains a separate construction type.

## Icons

Roof and corner icons are drawn from their looks (`tools/paint_look_icons.py`, `CORNER_VIEW`, `SHORTEN (0.1, 0.6, 0.3)`), not painted flat. Counts in `docs/ui/item_icons.md`.

## Pictures (shared folder)

`/mnt/project-files/kathleen/roof_ladder_sheet.png`, `fortified_sheet.png`, `fortified_wall_top_joint.png`; Dino's world shots `/mnt/project-files/fortified_world_*.png` and `fortified_beach_*.png` (11:00, beach sand at 52752, 67792).

## Not built yet (future looks, in design notes)

Log bridge, Mine brace, Wooden ladder, half-timber Refined wall, shutters, chimneys and gutters were pending in this historical art pass. **Crude - Roof 65 is implemented** (BUGLIST-001 BUG-011); do not treat its construction piece as future. Any other entries need fresh verification against `dev` before assigning work.
