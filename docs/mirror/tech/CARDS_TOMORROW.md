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

## Ocean and digging on the beach (OCEAN_DIG_NOTE.md; Sonny's 6 lines, one card each; add Steve's answer on the sim first)
8. Is the sea an unlimited source at sea level for the live sim: any dug cell connected to the sea and below 0 m fills to 0 m (so a trench to the beach floods, players can dig harbours and canals)? Recommend Yes.
9. Is inland reach limited by the ground height only (water stands at 0 m, so it only fills ground below 0 m)? Recommend Yes.
10. Can players dam it back (wall or earth fill above 0 m); water already inside stays as a pond at 0 m once the connection is cut? Recommend Yes.
11. Do river mouths stay sea-connected (tide and river meet at 0 m), and does damming the mouth raise the river behind it (flood)? Recommend Yes.
12. Is it OK that the sea is a boundary and not simulated cells, with a cap of 50 m3/s per connection so a huge pit fills over minutes? Recommend Yes (the number is tunable in data).
13. Is the dug beach and its water saved like other edits? Recommend Yes.
14. Should a tunnel or room below 0 m that connects to the sea flood and drown like the river-flood rule (with a plain warning line when you dig below sea level near the coast)? Recommend Yes.
