extends SceneTree

# Playthrough probe 6 (read-only): can a new player set down and light a campfire, a lean-to and a bed at the spawn and at five other spots?
# The real server_items.gd with the real baked ground heights (terrain_generator.surface_height) as ground_height; water depth from the same heights (sea at 0).
#   godot --headless --path . --script res://art/playthrough/probe_place.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var generator
var items
var last_notice: String = ""
var next_peer: int = 2


func h(x: float, z: float) -> float:
	return generator.surface_height(x, z)


func n(id: String) -> int:
	return items.table.number_of(id)


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var dir: String = "user://probe_place"
	DirAccess.make_dir_recursive_absolute(dir)

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): last_notice = t
	items.ground_height = func(x, z): return h(x, z)
	items.water_depth_at = func(pos: Vector3): return maxf(0.0 - h(pos.x, pos.z), 0.0)
	items.tree_info = func(_c, _i): return {}
	items.cut_tree = func(_c, _i): return false
	items.water_near = func(_pos, _reach): return false
	items.setup(ItemTableScript.load_default(), dir)
	var spawn: Vector2 = Vector2(53316.0, 68476.0)
	var spots: Array = [["spawn", spawn], ["clearing (walk picture)", Vector2(53301.0, 68427.0)]]
	# scan 300 m round the spawn on a 6 m grid: a meadow-ish spot 60 m out, the steepest grass slope, the first beach (1 to 3 m), a spot at 0.3 to 1 m
	var best_slope: float = 0.0
	var slope_at: Vector2 = spawn
	var beach: Vector2 = Vector2.ZERO
	var low_beach: Vector2 = Vector2.ZERO

	for dz in range(-300, 301, 6):
		for dx in range(-300, 301, 6):
			var x: float = spawn.x + float(dx)
			var z: float = spawn.y + float(dz)
			var y: float = h(x, z)

			if y < 1.2:
				continue

			var rise: float = maxf(absf(h(x + 0.8, z) - h(x - 0.8, z)), absf(h(x, z + 0.8) - h(x, z - 0.8)))

			if rise > best_slope and y > 3.0:
				best_slope = rise
				slope_at = Vector2(x, z)

			if y < 3.0 and beach == Vector2.ZERO:
				beach = Vector2(x, z)

			if y < 1.0 and low_beach == Vector2.ZERO:
				low_beach = Vector2(x, z)

	for dz in range(-300, 301, 6):
		for dx in range(-300, 301, 6):
			var x: float = spawn.x + float(dx)
			var z: float = spawn.y + float(dz)
			var y: float = h(x, z)

			if y > 0.15 and y < 1.0 and low_beach == Vector2.ZERO:
				low_beach = Vector2(x, z)

	spots.append(["60 m east", spawn + Vector2(60.0, 0.0)])
	spots.append(["60 m north", spawn + Vector2(0.0, -60.0)])
	spots.append(["steepest slope in 300 m (rise %.2f m over 1.6 m)" % best_slope, slope_at])

	if beach != Vector2.ZERO:
		spots.append(["first beach square (ground 1 to 3 m)", beach])

	if low_beach != Vector2.ZERO:
		spots.append(["wet beach (ground 0.15 to 1 m)", low_beach])

	for s in spots:
		var at: Vector2 = s[1]
		print("probe6: SPOT ", s[0], " at ", Vector2(roundf(at.x), roundf(at.y)), " ground ", snappedf(h(at.x, at.y), 0.01))

		var shift: float = 0.0

		for kit in ["campfire_kit", "lean_to_kit", "rough_bed_kit"]:
			var at0: Vector2 = at
			at = Vector2(at0.x + shift, at0.y)   # each kit 8 m from the last one: the structure gap is 2.5 m and a fire next to it would refuse the next kit
			shift += 8.0
			var p: int = next_peer
			next_peer += 1
			items.peer_connected_hello(p, "probe6%08d" % p)
			var ground: float = h(at.x, at.y)
			items.report_position(p, Vector3(at.x - 2.0, ground, at.y))
			items.vitals_of(p)["weight"] = 900.0
			items.give(p, n(kit), 1)
			last_notice = ""
			var before: int = items._items.size()
			items.action(p, Net.ACT_PLACE, items.inventory_of(p).numbers.find(n(kit)), 0, 0, Vector3(at.x, ground, at.y))
			var placed: bool = items._items.size() > before
			print("probe6:   ", kit, " -> ", "PLACED" if placed else "REFUSED", " notice: '", last_notice, "'" if last_notice != "" else "(silent: no reason sent to the player)")

			if placed and kit == "campfire_kit":
				var id: int = items._items.size() and items._items.keys().back()

				for tinder in ["plant_fibre", "birch_bark"]:
					items.give(p, n(tinder), 1)
					last_notice = ""
					items.action(p, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
					var fire: Dictionary = items._items[id].get("fire", {})
					print("probe6:     light with ", tinder, " -> fire state ", fire.get("state", "?"), " notice '", last_notice, "'")

					if int(fire.get("state", 9)) != 9:
						break

			at = at0

	quit()
