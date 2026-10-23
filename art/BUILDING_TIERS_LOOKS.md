# Building tiers: the looks (designs)
Kathleen_ArtisticDirector, 2026-10-22. Pictures: art/tiers/tiers_walls.png, tiers_floors.png, tiers_roofs.png, tiers_plan.png (all to scale). Costs, foundations and ids are Sal's (art/BUILDING_TIERS_PLAN.md). Revises BUILDING_PLAN.md point 1: tiers replace material skins. These are design pictures, not engine renders. Rebuild with `python3 tools/design_tiers.py <dir>`.

## Real examples I based them on
- Basic: wattle and daub / woven hazel hurdles (Iron Age roundhouse walls), stakes with rods woven over and under, straw packed in, thatch eaves.
- Plank: slab or waney-edge siding: boards split from a round log, bark left on the outer face, flat face inside.
- Fine wood: lapped clapboard (weatherboard) with nails and corner trim.
- Log: Scandinavian/Appalachian log cabin, round logs, notched corners with ends sticking out, chinking (moss and clay) between logs.
- Cobblestone: fieldstone/cobble walls, rounded stones in thick lime or clay mortar.
- Mason: castle ashlar, big dressed blocks in staggered courses, chisel-draft margins, plinth course at the foot.

## Walls (2 m wide, 2.4 m high)
| Tier | Look | Real geometry |
|---|---|---|
| 1 Basic | vertical stakes every 15 cm, light rods woven over and under, twine lashing, straw along the top | flat panel 0.1 m |
| 2 Plank | half-round planks, smooth and rounded on the OUTSIDE (Dave 22:20), flat rough face INSIDE, dark gaps | two layers: rounded smooth outside, flat rough inside, 0.1 m |
| 3 Fine wood | lapped boards 12 cm, nail heads, corner trim, top plate | panel 0.15 m with trim posts |
| 4 Log | 8 round logs 30 cm, bark on, saddle-notched corners that interlock (the log that runs through the corner alternates each course, opposite on the two ends of a wall; picture tiers_log_corner.png), chinking | real cylinders (8 per wall), 0.4 m |
| 5 Cobblestone | rounded stones 20 to 40 cm, thick pale mortar, mixed grey, brown, blue-grey | panel 0.5 m, rounded mortar relief by texture |
| 6 Mason | blocks 80 x 40 cm staggered, dressed centre and chisel margin, small stains, projecting plinth | panel 0.6 m with plinth and top course |

## Floors (2 m square)
1 beaten earth, straw and a woven mat. 2 rough planks, gaps, pegs. 3 planed boards, nail pairs. 4 split logs flat side up, bark edges. 5 flagstone, narrow joints. 6 cut stone blocks 50 cm, tight joints.

## Roofs (2.4 m square, eave at the bottom)
1 thatch, bound courses, thick eave edge. 2 riven plank shingles, ragged. 3 sawn shingles, nailed. 4 bark sheets over log rafters with a ridge log. 5 stone slabs on visible beam ends. 6 dressed slabs, carved ridge cap.

## Doors and windows (same slots, per tier)
Doors take the tier's look but stay wood: basic = woven hurdle, plank = bark door, fine = nailed boards with iron straps, log = thick planks, cobble and mason = heavy planks with iron bands. Windows: shutters from tier 3 up, plain opening below.

## Sounds
Place and door sounds per tier: thatch (basic), board (plank, fine), log (new: deep thud, creak), stone (cobble), heavy stone (mason, new). Floor footsteps already exist: dirt/thatch, plank, slab.

## Other fixes from Dave's answers
- Bucket: now wood (light ash staves with visible joints, dark wooden hoops, rope bail).
- Axe: a wedge head, thick at the stick and thinning to a sharp edge, sticking out sideways so from the side it reads like a hoe.
- Spade sizes: small 1.0, medium 1.25, large 1.5 of the same spade.

## Questions (recommendation first)
1. Roof of tier 5: stone slabs on beams as Sal wrote; tier 6: dressed slabs. Recommend yes (cobble = rough slate-like slabs, mason = tidy dressed slabs).
2. Log walls are real cylinders and not a texture so the notched corners show. Recommend yes (8 small meshes per wall).
3. (answered: smooth rounded outside, rough flat inside). Recommend yes.
4. Do doors/windows follow the tier look? Recommend yes (table above).

## Doors and windows (Dave 22:20; picture art/tiers/tiers_doors.png)
1 Basic: woven hurdle with thatch and twine ties. 2 Plank: planks with two battens, wooden latch. 3 Reinforced: planks with iron bands and rivets. 4 Wrought iron: iron frame with crossed bars over dark planks. 5 Steel and iron: steel panels in an iron frame, brass handle. Double door: two leaves, 2 m wide, fills the slot. Window and double window (two lights, 2 m). All fit a door or window frame in the 2 m wall slot; mouse wheel scrolls wall / window / door frame / double door frame / double window frame while placing (Steve and Sal).

## Roof slopes, corners and pillars (Dave 23:08; picture art/tiers/tiers_roof_pieces.png)
- Two roof angles, 45 and 65 degrees. A slope piece covers 2 m of run: at 45 degrees rise 2.0 m, slope length 2.83 m; at 65 degrees rise 4.29 m, slope length 4.73 m (a steep, tall roof).
- Each angle has a straight slope piece, a HIP corner piece (outside corner) and a VALLEY corner piece (inside corner of an L-shaped house): 6 roof pieces per tier look.
- Pillars: round log post, squared timber, stone pillar, mason column (base and capital). A pillar snaps to the centre or any of the 4 corners of a foundation (4 x 4 m) or a floor/ceiling cell (2 x 2 m): 5 snap points.
- Foundation sentence for the page: every building starts on a foundation. A foundation goes on the ground anywhere level enough to hide the whole bottom; on a slope it must be levelled first. Foundations join side by side to make the floor and the shape of the house, then you build up from them. Most pieces snap to most other pieces in a sensible way. (Sal/Steve own the rule.)

## Door and window changes (Dave 23:01)
Windows are just holes in the wall (no frame piece, no glass); shutters come later as separate hinged wood pieces. A double door sits in a full 2 x 2.4 m wall slot with 10 cm clear all round (leaves 1.8 m wide, 2.2 m high), like Ark. Picture tiers_doors.png redrawn.

## Round 3 (Dave 23:40 to 00:00)
- Log corners redrawn after a real log cabin: round saddle notch, each log overlaps the course below, the crossing log shows end-on tucked into the notch, opposite on the two ends (tiers_walls.png).
- Double door: 10 cm gap at the top and sides only, leaves reach the floor. Handles are steel bar pulls, no knobs: basic door has no handle at all; steel door has a steel handle and no black crossband (tiers_doors.png).
- Ceilings per tier (seen from below): tiers_ceilings.png. Flat tarred roof: tiers_flat_roof.png.
- Braces in three widths, 1.5, 3 and 5 m: tiers_braces.png.
