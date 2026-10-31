extends SceneTree

# Finds tall-grass clumps with a clear line of sight from a camera spot 25 m and 40 m away (no trunk or shrub within 1.2 m of the line).
#   godot --headless --path . --script res://src/worldgen/tools/clump_sight.gd -- --at=53301,68427

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(53301.0, 68427.0)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--at="):
			var p: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(p[0]), float(p[1]))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var grass: Array = []
	var blockers: Array = []

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var chunk: Vector2i = placer.chunk_of(at.x + float(dx) * 256.0, at.y + float(dz) * 256.0)
			var made: Dictionary = placer.chunk_items(chunk)

			for n in range(made["ids"].size()):
				var sp: Dictionary = placer.species_of(made["ids"][n])
				var p: Vector3 = made["positions"][n]
				var q: Vector2 = Vector2(p.x, p.z)

				if sp["name"] == "tall_grass":
					grass.append(q)
				elif int(sp["kind"]) == PlacerScript.KIND_TREE:
					blockers.append([q, 0.8])
				elif float(sp.get("height_max", 0.0)) >= 0.9 and sp["name"] != "thatch_grass":
					blockers.append([q, 1.2])

	var seen: Array = []
	var rows: Array = []

	for g in grass:
		if g.distance_to(at) > 120.0:
			continue

		var near: bool = false

		for s in seen:
			if s.distance_to(g) < 4.0:
				near = true
				break

		if near:
			continue

		seen.append(g)
		var clump: Array = []

		for h in grass:
			if h.distance_to(g) < 2.5:
				clump.append(h)

		if clump.size() < 12:
			continue

		var centre: Vector2 = Vector2.ZERO

		for h in clump:
			centre += h

		centre /= float(clump.size())

		for k in range(16):
			var dir: Vector2 = Vector2.RIGHT.rotated(TAU * float(k) / 16.0)
			var ok: Array = []

			for dist in [25.0, 40.0]:
				var cam: Vector2 = centre + dir * dist
				var clear: bool = true

				for b in blockers:
					var pos: Vector2 = b[0]
					var d: float = pos.distance_to(cam)

					if d < 2.5:
						clear = false
						break

					var t: float = clampf((pos - cam).dot(centre - cam) / (centre - cam).length_squared(), 0.0, 1.0)
					var onseg: Vector2 = cam + (centre - cam) * t

					if pos.distance_to(onseg) < float(b[1]) + 0.4 and pos.distance_to(centre) > 3.0:
						clear = false
						break

				ok.append(clear)

			if ok[0] and ok[1]:
				rows.append([centre.distance_to(at), centre, k, clump.size()])

	rows.sort_custom(func(a, b): return a[0] < b[0])

	for r in rows.slice(0, 12):
		var yaw_deg: float = rad_to_deg(atan2(-(Vector2.RIGHT.rotated(TAU * float(r[2]) / 16.0)).x, (Vector2.RIGHT.rotated(TAU * float(r[2]) / 16.0)).y))
		print("clump %s plants %d, %.0f m from spot, camera bearing k=%d (camera at clump + 40 m in direction %s)" % [str(r[1]), r[3], r[0], r[2], str(Vector2.RIGHT.rotated(TAU * float(r[2]) / 16.0))])

	quit(0)
