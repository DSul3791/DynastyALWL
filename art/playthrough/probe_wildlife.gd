extends SceneTree

# Playthrough probe 5 (read-only): the real server_animals.gd on the real baked terrain and flora, one player standing at the spawn, 10 simulated minutes.
# Prints, every 2 minutes and at the end, the animals alive within 100 / 300 / 1000 m of the player by species and by behaviour state, and the
# results of three seeds (the code has no time-of-day or season input, so "day" and "night" are identical: that is one of the findings).
#   godot --headless --path . --script res://art/playthrough/probe_wildlife.gd -- [--x=53316 --z=68476] [--minutes=10]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

var generator
var placer
var crowns: Dictionary = {}   # 16 m cell -> Array of [x, z, radius]


func _cells(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / 16.0)), int(floor(z / 16.0)))


func _load_crowns(cx: float, cz: float, tables) -> void:
	var flora: Dictionary = {}

	for entry in tables.get_entries("flora"):
		flora[str(entry["name"])] = entry

	var lo: Vector2i = placer.chunk_of(cx - 400.0, cz - 400.0)
	var hi: Vector2i = placer.chunk_of(cx + 400.0, cz + 400.0)

	for ci in range(lo.x, hi.x + 1):
		for cj in range(lo.y, hi.y + 1):
			var made: Dictionary = placer.chunk_items(Vector2i(ci, cj), true)

			for n in range(made["ids"].size()):
				var sp: Dictionary = placer.species_of(made["ids"][n])
				var row: Dictionary = flora.get(str(sp.get("name", "")), {})
				var p: Vector3 = made["positions"][n]
				var cell: Vector2i = _cells(p.x, p.z)

				if not crowns.has(cell):
					crowns[cell] = []

				crowns[cell].append([p.x, p.z, float(row.get("crown_m", 3.0)) * 0.5])


func _under_tree(p: Vector3) -> bool:
	var c: Vector2i = _cells(p.x, p.z)

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for t in crowns.get(Vector2i(c.x + dx, c.y + dz), []):
				if Vector2(p.x - t[0], p.z - t[1]).length() <= t[2]:
					return true

	return false


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var cx: float = 53316.0
	var cz: float = 68476.0
	var minutes: float = 10.0
	var hour: float = 12.0          # the game hour for the spawn gate (flora session 2026-10-31: --hour=N, --unwired for the old behaviour)
	var wired: bool = true

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--x="):
			cx = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--z="):
			cz = float(argument.trim_prefix("--z="))
		elif argument.begins_with("--minutes="):
			minutes = float(argument.trim_prefix("--minutes="))
		elif argument.begins_with("--hour="):
			hour = float(argument.trim_prefix("--hour="))
		elif argument == "--unwired":
			wired = false

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	_load_crowns(cx, cz, tables)
	var state_names: Array = ["graze", "hop", "flee", "alert"]
	var biome_names: Dictionary = {}

	for biome_entry in tables.get_entries("biomes"):
		biome_names[int(biome_entry["id"])] = str(biome_entry["name"])

	var all_runs: Array = []

	for seed in [7, 11, 23]:
		var players: Array = [Vector3(cx, generator.surface_height(cx, cz) + 1.7, cz)]
		var a = AnimalsScript.new()
		a.ground_height = func(x, z): return generator.surface_height(x, z)
		a.blocked = func(x, z): return generator.surface_height(x, z) <= 0.3
		a.player_positions = func(): return players
		a.canopy = func(p: Vector3): return _under_tree(p)

		if wired:
			a.hour_now = func(): return hour
			a.starter = Vector2(cx, cz)
			a.biome_at = func(x, z):
				var tile_data = generator.get_tile(generator.tile_of(x, z))
				return "" if tile_data.placeholder else str(biome_names.get(int(tile_data.biome[tile_data.nearest(x, z)]), ""))

		a.setup()
		a.rng.seed = seed
		var snapshots: Array = []
		var steps: int = int(minutes * 60.0 / 0.1)

		for n in range(steps):
			a.tick(0.1)

			if n % 1200 == 1199:   # every 2 minutes
				snapshots.append(_count(a, players[0], state_names, float(n + 1) * 0.1))

		var last: Dictionary = _count(a, players[0], state_names, minutes * 60.0)
		print("wildlife: seed ", seed, " after ", minutes, " min: ", JSON.stringify(last))
		all_runs.append({"seed": seed, "snapshots": snapshots, "final": last})

	var f: FileAccess = FileAccess.open("res://art/playthrough/wildlife_survey.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(all_runs, " "))
	f.close()
	quit()


func _count(a, player: Vector3, state_names: Array, t: float) -> Dictionary:
	var rings: Array = [100.0, 300.0, 1000.0]
	var by_ring: Array = [{}, {}, {}]
	var states: Dictionary = {}
	var herd_sizes: Array = []

	for id in a.animals:
		var an: Dictionary = a.animals[id]
		var d: float = Vector2(an["pos"].x - player.x, an["pos"].z - player.z).length()

		for r in range(3):
			if d <= float(rings[r]):
				by_ring[r][an["sp"]] = int(by_ring[r].get(an["sp"], 0)) + 1
				break

		var key: String = "%s:%s" % [an["sp"], state_names[clampi(int(an["state"]), 0, 3)]]
		states[key] = int(states.get(key, 0)) + 1

	for hid in a._herds:
		herd_sizes.append(a._herds[hid].size())

	return {"t_s": t, "within_100": by_ring[0], "within_300": by_ring[1], "within_1000": by_ring[2], "states": states, "herd_sizes": herd_sizes, "total": a.animals.size()}
