extends RefCounted

# The version of the flora layout: where every plant and tree stands, chunk by chunk (flora_placer.gd and the patch placer).
# Removed-plant marks are saved by "item N in chunk C" (server_flora.gd flora_removed.json, server_items.gd picked and stripped), so they
# only mean something while the plants stand where they did. BUMP THIS whenever a change moves, adds or drops plants (patches, new
# species spacing, a changed seed): the server then clears the old marks at the next start instead of removing the wrong plants.
# A save from before the stamp existed counts as version 1.

const VERSION := 13      # 13: moss in cushions and mushrooms in troops (patches), 2026-10-31; 12: starter clearing (no tree or shrub within 10 m of the spawn or 6 m of an NPC marker), 2026-10-31; 11: tree density x4.6 (150 trees per hectare in temperate forest, Dave: dense old-growth), 2026-10-31; 10: understory shrubs, beech and maple per hectare, tree density x2.6 (2026-10-31); 9: shore species stand near water (reeds, riverbraid, alder...), 2026-10-31; 8: fallen logs, hollow logs, old stumps (2026-10-31); 7: more beach shore plants, forest mushrooms and moss (2026-10-31); 6: tall grass patches, more berry/shrub/reed ground (flora density fix, 2026-10-30); 5: thatching grass patches (Dave 2026-10-24); 4: tree belts (softwood foothill belt, fertility weights, plateau hardwoods, fuller montane patches), Dave 2026-10-24
