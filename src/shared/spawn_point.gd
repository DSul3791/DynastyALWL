extends RefCounted

# The starter spawn point (x, z in world metres) in one place: the server's spawn (terrain_server.gd SPAWN_OVERRIDE) and the flora placer's
# clearing around it (flora_placer.gd) both read it from here. See terrain_server.gd for why it is where it is.

const OVERRIDE := Vector2(53296.0, 68080.0)   # moved 6 Nov 2026 (Sonny, #473) from x 53316 z 68476: with the rivers on the valley floor that spot was no longer 2 m over the water; Dave: move the spawn, do not adjust heights
