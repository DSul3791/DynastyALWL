# Cards held for tomorrow (Dave 00:57: hold all remaining simple questions until tomorrow). Guru posts in this order.
Format: Yes/No + Why-not box (BP-T39) unless marked T or P (BP-T40).

## Kathleen (round 4 designs; images in /mnt/project-files/art/tiers/, pushed on kathleen-tools-v6)
1. (tiers_walls.png 4th wall + tiers_log_corner.png) Does the log wall look right: only this wall's logs, ends offset left and right, open spaces where a joining wall's logs pass through, no curved notch?
2. (tiers_ceilings.png) Do the six ceilings look right now: log = rounded undersides, fine boards full length with no strips, cobblestone looks like cobblestone, mason unchanged?
3. (tiers_roof_pieces.png) Kathleen read "65 degrees" as measured from the vertical, so a low roof: 45 degrees rises 2.0 m per 2 m run, 65 rises only 0.93 m. Is that the shorter peak you meant?
4. (tiers_braces.png) Do the braces look right: round logs joined with wooden pins, each of the three sizes in a plain and a tar-soaked version?
5. (tiers_floor_frames.png) Do the cobblestone and mason floors look right: stone on top, a log split in half along each of the four edges underneath, plank floor under the cobblestones?

## Guru (re-ask)
6. Esc menu: should Character open the Tab screen from the menu? (answered No with no reason on 2026-10-23)

## Sal (drafts in items/BLUEPRINT_BUILD_DESIGN.md; post as one card per line when Sal sends the final lines)
- cost table v2: foundation costs by tier (dirt, wooden, stone; small/large), stone floor and roof costs with the wooden layer underneath, wood pillar = 1 log (8 ft = 2.4 m), braces from logs and wooden pins in plain and tar-soaked versions, wrought iron door with wood and nails.
- floor-brace design (split log in half around the bottom edge in quarters).

## Sonny
7. Should we store the list of lakes and basins (where each is, how deep, where it overflows) in the tile file, so the game always puts water at the bottom of the same basins? Recommend Yes. (Note tech/TERRAIN_B_BASINS_NOTE.md; it adds a BASINS section to the tile format: Guru approval needed for the format change, BP-T28.)

## Steve
- Esc menu rework (plain names, sound test page with a scrolling list, slide switches): cards only if something is unclear.

## Kathleen later
- looks for the 8 new items (rough plank, fine board, nails, cobblestone, stone shingle, tar, hinges, wooden pin) as a picture card after MikeW renders.

## Ocean and digging on the beach (OCEAN_WATER_NOTE.md joint recommendation by Guru and Sonny; Steve confirms the sim parts first; the old OCEAN_DIG_NOTE.md is superseded)
8. Is the sea an endless source at sea level, so a beach pit dug below 0 m and connected to the sea fills to sea level (trenches flood, harbours and canals possible)? Recommend Yes.
9. Does a pit you dam off from the sea keep its water as a puddle? Recommend Yes.
10. Do tunnels or rooms below sea level that connect to the sea flood and drown like the river-flood rule, with a plain warning line when you dig below sea level near the coast? Recommend Yes.
11. Should the sea feed a pit at most 50 m3/s per connection, so a huge pit fills over minutes instead of instantly (tunable number)? Recommend Yes.
12. Do river mouths stay sea-connected, so damming a mouth floods the river behind it (intended risk)? Recommend Yes.
13. Tides later, not now? Recommend Yes.
14. Can players build up land under the sea to make their own islands, by filling shallow sea with soil, sand, gravel, clay or stone with the spade (big islands cost lots of material)? Recommend Yes.
15. (multiple choice) How deep may players fill sea by hand? Sal says shallow only, up to 1.5 m; Sonny says up to 6 m; Guru recommends about 4 m. Deeper water needs pillars.
16. Does water displaced by fill just vanish into the sea? Recommend Yes.
17. Can loose soil and sand slope away under water while rock and stone hold their shape (so a sand island needs rock edges)? Recommend Yes (Sonny).
18. Can you build piers (Valheim style) as a row of foundation cells or pillars from the shore onto filled rock into shallow water? Recommend Yes.
19. May a pier cell sit on the bed under up to 0.5 m of water? Recommend Yes (Sal).
20. Is spade fill with stone enough, with no separate rock-pile item? Recommend Yes (Sal).
21. Do fortress and town foundations on your own island need ground about 1 m above sea level, with the normal blueprint and load rules? Recommend Yes.
(Sea boundary link: Steve confirmed the sim only drains into the sea; a recommended sea boundary link in water_sim.gd is needed for cards 8 to 10, server restart, so it is part of the answer to card 8.)
