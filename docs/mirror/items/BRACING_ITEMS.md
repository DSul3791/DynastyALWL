# Bracing items (item side of the dig-and-brace rule; proposal, nothing built)

Dave (2026-10-22): no limit on excavating, but after digging you add bracing or it collapses: a grace window, then the earth shakes more and more, then it collapses unless braced. Willy_002 owns the ground side (timer, shaking, collapse). This note covers the items. Sources are DESIGN_IDEAS.md section numbers; anything marked NEW is not in the docs.

## What the docs already settle (use as is)
- 11.2 [Decided]: man-made openings need supports, the bigger the opening the more support; supports are timbers or pillars; they slowly wear and need maintenance. "A deliberate difference from games where players can dig out huge spaces for free." (The no-limit-on-digging rule fits this.)
- 11.2 [Decided]: supports work like torches: each holds up the ground within its reach, strongest at the support, fading with distance; overlapping supports add up to a cap of full strength; widest spacing leaves the weakest spot in the middle.
- 11.2 [Proposed] starting numbers: reach 10 m, so one every 20 m just touches; a spot holds while total strength x support condition >= what the opening needs, which grows with opening size. The server stores only each support's position, kind and install time.
- 11.2 and 8.13 [Decided]: supports follow the general wear rule: slow wear while owned and maintained, faster wear the longer care is missing; mine timbers are dry, so they keep well while maintained; repair on a town's schedule is paid from the owner's account. Neglect: weak middle spots go first (about days 4 to 5), supports reach their floor in about 168 game days.
- 11.2 [Decided]: a collapse refills the workings with rubble; the land above does not sink; rubble can be dug out again; ruins stay on the surface.
- 11.2 [Open]: how big an opening needs supports, what kinds exist (timber, stone pillars, masonry arches, later iron), whether a collapse injures miners, whether natural caves can collapse when widened. This note proposes answers to the item parts of that.

## Support kinds (items; all data in items.json / structures.json)
| Kind | Reach (m) | Strength at the support | Wear to floor | Made from |
|---|---|---|---|---|
| Timber prop | 3 | 0.5 | 60 game days | 1 log or beam, 1 cordage |
| Timber set (post and cap) | 6 | 0.7 | 120 game days | 2 beams, 1 cordage, 1 stick wedge |
| Stone pillar | 8 | 0.85 | 400 game days | 3 stone blocks (needs a mason's table) |
| Masonry arch | 10 | 1.0 | 1000 game days | 3 stone blocks, 1 lime mortar |
| Iron frame (later) | 12 | 1.0 | 1500 game days | 2 iron ingots, 1 beam |

- Reach 10 m is the docs' starting number for the standard timber set; the smaller props are cheap early help for a new digger (NEW).
- Wood species: harder woods (oak, chestnut) give a longer wear floor, softwood shorter (the species logs and beams already exist: lumber_<species>, beam_<species>) (NEW).
- Three-ingredient recipes (the rule): every kind above is three or fewer ingredients; more ingredients = better piece (an extra beam makes a prop a "braced prop" with +0.1 strength) (NEW, from the crafting rule).

## Placing, strength and the timer (item side)
- A support is a placeable (like the chest and lean-to kits): E to place, only inside or beside an excavation, needs solid ground to stand on, a minimum gap between props (about 1 m) (NEW, structure framework in structures.json).
- Strength per spot = the sum of nearby supports' strength faded by distance, capped at 1.0, times condition (docs 11.2). The excavation's need grows with its open span and height.
- Timer link (to settle with Willy_002): when a spot's strength x condition >= need, the grace window is paused (safe); a new support placed before the window ends restarts the full grace window for the spots it now covers (NEW). Shaking strength follows the remaining share of the window; a collapse happens when the window reaches zero at a spot still short of its need.
- Warning feedback: creaks and dust before the shake, a floating "needs bracing" hint in inspection mode (/) on a spot that is short (NEW).

## Wear, repair and rot
- Each support has a condition 0..1, wearing slowly while owned (8.13) and faster when abandoned; the server computes it lazily from install time (docs).
- Repair: replace or "re-wedge" with the same kind of materials (one timber for a prop or set), through the existing repair verb; stone and arches cost mortar (NEW). A town's maintenance schedule repairs supports inside its block automatically and bills the owner (docs 11.2).
- Rot: wood supports rot faster in wet ground (water near the support or below the water table) and slower dry (NEW, link to water data).

## Open for Dave (small; recommended answers)
1. Should a collapse hurt a player trapped inside? Recommend yes, by fall-damage rules (a rubble fall), not instant death, in line with "the game tries to keep you from dying" (6.x).
2. Can natural caves collapse when widened by players? Recommend yes, the same rule as man-made openings (the docs leave it open).

## Build order when the stop lifts
Prop and set items plus the placeable support, then the strength field with Willy_002's timer, then wear and the town repair schedule, then stone and arch kinds after the mason's table.
