extends SceneTree

# NPC placement (Sonny, 31 Oct 2026): for each NPC marker, the distance to the nearest tree or shrub from the real flora placer, and the nearest flora-clear disk near the spawn pad where the
# town markers could stand. Edda sat inside a young fir at the chair markers (x 53298, z 68424) on the old spawn spot.
#   godot --headless --path . --script res://tools/npc_clear_spot.gd -- [--x=53316 --z=68476 --r=3.5]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var cx: float = 53316.0
	var cz: float = 68476.0
	var radius: float = 3.5

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--x="):
			cx = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--z="):
			cz = float(argument.trim_prefix("--z="))
		elif argument.begins_with("--r="):
			radius = float(argument.trim_prefix("--r="))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var flora: Dictionary = {}
	var kinds: Dictionary = {}

	for entry in tables.get_entries("flora"):
		flora[str(entry["name"])] = entry
		kinds[str(entry.get("kind", "?"))] = true

	print("flora kinds: ", kinds.keys())
	var blockers: PackedVector2Array = PackedVector2Array()
	var lo: Vector2i = placer.chunk_of(cx - 90.0, cz - 90.0)
	var hi: Vector2i = placer.chunk_of(cx + 90.0, cz + 90.0)

	for ci in range(lo.x, hi.x + 1):
		for cj in range(lo.y, hi.y + 1):
			var made: Dictionary = placer.chunk_items(Vector2i(ci, cj))

			for n in range(made["ids"].size()):
				var name: String = str(placer.species_of(made["ids"][n]).get("name", "?"))
				var kind: String = str(flora.get(name, {}).get("kind", ""))

				if kind == "tree" or kind == "shrub" or kind == "bush":
					var p: Vector3 = made["positions"][n]
					blockers.append(Vector2(p.x, p.z))

	print("%d trees and shrubs within 90 m of %.0f,%.0f" % [blockers.size(), cx, cz])
	var markers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/markers.json"))

	for m in markers["markers"]:
		var at: Vector2 = Vector2(float(m["x"]), float(m["z"]))
		print("  marker %s (%.0f, %.0f): nearest tree or shrub %.1f m" % [m["id"], at.x, at.y, _nearest(blockers, at)])

	var shifts: Array = []

	for sz in range(-40, 41, 2):
		for sx in range(-40, 41, 2):
			var origin: Vector2 = Vector2(53301.0 + sx + 15.0, 68427.0 + sz + 49.0)
			var worst: float = 1e9

			for m in markers["markers"]:
				worst = minf(worst, _nearest(blockers, Vector2(float(m["x"]) - 53301.0, float(m["z"]) - 68427.0) + origin))

			shifts.append([worst, origin, Vector2(sx + 15.0, sz + 49.0).distance_to(Vector2(0, 0))])

	shifts.sort_custom(func(a, b): return a[0] > b[0])
	print("whole town shifted so its square is at (x, z): the nearest tree to any marker (best five)")

	for k in range(5):
		print("  square at %.0f,%.0f: %.1f m clear for every marker, %.0f m from the old spot" % [shifts[k][1].x, shifts[k][1].y, shifts[k][0], shifts[k][2]])

	var best: Array = []

	for dz in range(-40, 41, 2):
		for dx in range(-40, 41, 2):
			var at: Vector2 = Vector2(cx + dx, cz + dz)
			var d: float = _nearest(blockers, at)

			if d >= radius:
				best.append([Vector2(dx, dz).length(), at, d])

	best.sort_custom(func(a, b): return a[0] < b[0])
	print("clear spots (>= %.1f m from any tree or shrub) within 40 m of the spawn, nearest first:" % radius)

	for k in range(mini(12, best.size())):
		print("  %.0f,%.0f  %.0f m from the spawn, %.1f m clear" % [best[k][1].x, best[k][1].y, best[k][0], best[k][2]])

	quit(0)


func _nearest(points: PackedVector2Array, at: Vector2) -> float:
	var best: float = 1e9

	for p in points:
		best = minf(best, p.distance_to(at))

	return best
