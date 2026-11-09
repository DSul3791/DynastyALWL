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


# The spawn clear of trees and shrubs (docs/design/no_spawn_placement_design.md 2): flora is placed at run time and the bake's picker cannot
# see it, so the server moves the spawn off a trunk at start. `at` stays when no trunk stands within clear_m; else the first point, ring by
# ring (ring_m apart out to search_m, ring_points each), with no trunk within clear_m, dry (wet_at false), over the sea (ground above 0) and
# within max_rise_m of the ground at `at`. None clear: `at` stays. trunks: the trees' and shrubs' ground points (x, z); grass and flowers do
# not block. ground_at(x, z) -> metres, wet_at(x, z) -> bool. The numbers are judged.
static func clear_of(at: Vector2, trunks: PackedVector2Array, ground_at: Callable, wet_at: Callable, rules: Dictionary = {}) -> Vector2:
	var clear_m: float = float(rules.get("clear_m", 2.0))

	if _trunk_free(at, trunks, clear_m):
		return at

	var ring_m: float = maxf(float(rules.get("ring_m", 1.0)), 0.1)
	var search_m: float = float(rules.get("search_m", 30.0))
	var points: int = maxi(int(rules.get("ring_points", 16)), 1)
	var max_rise: float = float(rules.get("max_rise_m", 0.5))
	var base: float = float(ground_at.call(at.x, at.y))
	var r: float = ring_m

	while r <= search_m + 0.001:
		for n in range(points):
			var p: Vector2 = at + Vector2.from_angle(TAU * float(n) / float(points)) * r

			if not _trunk_free(p, trunks, clear_m) or bool(wet_at.call(p.x, p.y)):
				continue

			var ground: float = float(ground_at.call(p.x, p.y))

			if not is_nan(ground) and ground > 0.0 and absf(ground - base) <= max_rise:
				return p

		r += ring_m

	return at


static func _trunk_free(p: Vector2, trunks: PackedVector2Array, clear_m: float) -> bool:
	for t in trunks:
		if p.distance_to(t) < clear_m:
			return false

	return true
