# Tyler reply (once, 25 Oct 00:58 UTC): Steve respawn at own bed - GO, directly after the rough bed in 792
Base: claude/steve-bed-respawn, cut from steve-rough-bed 6459b079 (merges after it; if the rough bed head moves, Steve rebases once). No new item/recipe numbers. RESTART, save field `bed` in characters.json, no protocol change. Approved as written (claim by lying on a covered bed, order own bed then shelter then spawn, bed gone = one line and fallback, shared beds in R1, New player clears it, data in bed.json).
Conditions:
1. **Landing must be free.** A bed inside a closed room (roof + 3 walls, door) or against a wall can leave the 1.2 m landing point inside a wall or on the bed. Search a short ring (up to 3 m, 8 directions, same height or a step down) for a free standing spot; if none, land on the bed position raised 0.5 m; never fail to the void. Tests: closed room, bed against a wall, bed on a foundation edge.
2. **A death loop must be impossible.** If the bed is where the player died and the cause is still there (cave-in, fire, flood), the third respawn in 10 minutes at the same bed falls through to shelter or world spawn, one line says why. Keep it small: a counter on the character, data row in bed.json.
3. **Cover check at respawn time** as written; flood or washaway of the bed (water plans later) also counts as "bed gone".
4. Save: old saves load with no `bed`; a saved `bed` pointing at a removed structure is dropped quietly with the one line at first lookup.
5. Gate: David3 test_bed_respawn.gd (cases listed plus 1 and 2 above), test_bed.gd, items_check, validate_items, dup sweep, parse_scan, local_check 233. Mike plays: lie, die, come back, rain, closed room (when Dave's PC is free).
Order: rough bed 6459b079 then this head; sound hookup after.
