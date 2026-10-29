extends RefCounted

# The version of the flora layout: where every plant and tree stands, chunk by chunk (flora_placer.gd and the patch placer).
# Removed-plant marks are saved by "item N in chunk C" (server_flora.gd flora_removed.json, server_items.gd picked and stripped), so they
# only mean something while the plants stand where they did. BUMP THIS whenever a change moves, adds or drops plants (patches, new
# species spacing, a changed seed): the server then clears the old marks at the next start instead of removing the wrong plants.
# A save from before the stamp existed counts as version 1.

const VERSION := 5      # 5: thatching grass patches (Dave 2026-10-24); 4: tree belts (softwood foothill belt, fertility weights, plateau hardwoods, fuller montane patches), Dave 2026-10-24
