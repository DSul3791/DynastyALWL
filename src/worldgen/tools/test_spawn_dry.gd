extends SceneTree

# A new player starts dry and the town stands clear of trees (Sonny, 31 Oct 2026). Guide's pictures showed a dark water-like plane at the spawn and the NPC Edda inside a fir:
# the spawn (x, z from terrain_server SPAWN_OVERRIDE) must lie on land at least 2 m above any settled water level within 12 cells (8 m each) and at least 5 m from a wet cell; no
# tree or shrub (real flora placer) within 2 m of the spawn or 1.5 m of any NPC marker; and the NPC town within 40 m of the spawn (the level spawn pad) (markers).
#   godot --headless --path . --script res://src/worldgen/tools/test_spawn_dry.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const ServerScript := preload("res://scenes/terrain_server/terrain_server.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")


var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _level(data, x: float, z: float) -> float:
	var k: int = data.nearest(x, z)

	if k >= 0 and k < data.sim_levels.size() and not is_nan(data.sim_levels[k]):
		return data.sim_levels[k]

	return data.water_surface[k] if k < data.water_surface.size() else NAN


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var spawn: Vector2 = ServerScript.SPAWN_OVERRIDE
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(Vector2i(int(floor(spawn.x / generator.tile_size_m)), int(floor(spawn.y / generator.tile_size_m))))
	var ground: float = float(generator.surface_height(spawn.x, spawn.y))
	var near: float = 1e9
	var near_level: float = -1e9
	var here: float = _level(data, spawn.x, spawn.y)

	for dz in range(-12, 13):
		for dx in range(-12, 13):
			var l: float = _level(data, spawn.x + dx * 8.0, spawn.y + dz * 8.0)

			if not is_nan(l) and Vector2(dx * 8.0, dz * 8.0).length() < near:
				near = Vector2(dx * 8.0, dz * 8.0).length()
				near_level = l

	_check(is_nan(here), "the spawn cell holds no water")
	_check(is_nan(here) and (near > 12.0 * 8.0 or ground >= near_level + 2.0), "the spawn ground (%.1f m) is at least 2 m above the nearest water (level %.1f m)" % [ground, near_level])
	_check(near >= 5.0, "the nearest wet cell is %.0f m from the spawn (at least 5 m)" % near)
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var kinds: Dictionary = {}

	for entry in tables.get_entries("flora"):
		kinds[str(entry["name"])] = str(entry.get("kind", ""))

	var blockers: PackedVector2Array = PackedVector2Array()
	var markers: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/markers.json")) as Dictionary)["markers"]
	var lo: Vector2i = placer.chunk_of(spawn.x - 60.0, spawn.y - 60.0)
	var hi: Vector2i = placer.chunk_of(spawn.x + 60.0, spawn.y + 60.0)

	for ci in range(lo.x, hi.x + 1):
		for cj in range(lo.y, hi.y + 1):
			var made: Dictionary = placer.chunk_items(Vector2i(ci, cj))

			for n in range(made["ids"].size()):
				if str(kinds.get(str(placer.species_of(made["ids"][n]).get("name", "?")), "")) != "plant":
					blockers.append(Vector2((made["positions"][n] as Vector3).x, (made["positions"][n] as Vector3).z))

	_check(_nearest(blockers, spawn) >= 2.0, "no tree or shrub within 2 m of the spawn (%.1f m)" % _nearest(blockers, spawn))
	var worst: float = 1e9
	var farthest: float = 0.0

	for m in markers:
		var at: Vector2 = Vector2(float(m["x"]), float(m["z"]))
		var d: float = _nearest(blockers, at)
		worst = minf(worst, d)
		farthest = maxf(farthest, at.distance_to(spawn))

		if d < 1.5:
			_check(false, "marker %s stands %.1f m from a tree or shrub (a marker must not be inside a flora collider)" % [m["id"], d])

	_check(worst >= 1.5, "every one of %d NPC markers is at least 1.5 m from a tree or shrub (nearest %.1f m)" % [markers.size(), worst])
	_check(farthest <= 40.0, "the NPC town lies within 40 m (the level pad) of the spawn (farthest marker %.0f m)" % farthest)
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)


func _nearest(points: PackedVector2Array, at: Vector2) -> float:
	var best: float = 1e9

	for p in points:
		best = minf(best, p.distance_to(at))

	return best
