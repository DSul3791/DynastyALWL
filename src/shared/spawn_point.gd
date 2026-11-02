extends RefCounted

# The starter spawn point (x, z in world metres) in one place: the server's spawn (terrain_server.gd SPAWN_OVERRIDE) and the flora placer's
# clearing around it (flora_placer.gd) both read it from here. See terrain_server.gd for why it is where it is.

const OVERRIDE := Vector2(53316.0, 68476.0)
