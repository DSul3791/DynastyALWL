extends RefCounted

# The starter spawn point (x, z in world metres) in one place: the server's spawn (terrain_server.gd _spawn_point), the flora placer's clearing
# and orchard round it (flora_placer.gd), the NPC town (server_npcs.gd markers) and the island checks all read it from here.
# Stage E M1 step 4 (docs/water/stage_e_readers_design.md 6e): when the starter tile carries a spawn picked by rule at bake time
# (starter.spawn_picked, tile_sites.gd _pick_spawn), that is the spawn, and the shipped NPC markers move with it as one piece (town_shift).
# With none, OVERRIDE stays the spawn and nothing moves. The picker is off until the R6 rebake, so today current() is OVERRIDE.

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")

const OVERRIDE := Vector2(53296.0, 68080.0)   # moved 6 Nov 2026 (Sonny, #473) from x 53316 z 68476: with the rivers on the valley floor that spot was no longer 2 m over the water; Dave: move the spawn, do not adjust heights
const STARTER_TILE := "tile_3_4.tile"

static var _current: Vector2 = OVERRIDE


# Reads the starter tile's picked spawn; call once at start, before anything reads current(). Returns the spawn now in use.
static func use_world(world_dir: String) -> Vector2:
	var path: String = world_dir + "/tiles/" + STARTER_TILE
	var starter: Dictionary = {}

	if FileAccess.file_exists(path):
		var head: Dictionary = TileFileScript.read_header(path)

		if head["ok"]:
			var section: Dictionary = TileFileScript.read_list(path, head["table"], "starter")

			if section["ok"] and typeof(section["value"]) == TYPE_DICTIONARY:
				starter = section["value"]

	_current = from_starter(starter)
	return _current


# The spawn a starter section gives: its spawn_picked when it has one, else OVERRIDE.
static func from_starter(starter: Dictionary) -> Vector2:
	var s: Variant = starter.get("spawn_picked", null)

	if typeof(s) == TYPE_ARRAY and (s as Array).size() >= 3:
		return Vector2(float(s[0]), float(s[2]))

	return OVERRIDE


static func current() -> Vector2:
	return _current


# How far the town moved with a picked spawn: the shipped NPC markers (data/npcs/markers.json, placed round OVERRIDE) move by this.
static func town_shift() -> Vector2:
	return _current - OVERRIDE


# For tests and tools: set the spawn directly (OVERRIDE undoes it).
static func set_current(at: Vector2) -> void:
	_current = at
