extends SceneTree

# Server join stall profile (Radar, 2026-10-22): real generator, one player joins at the spawn, then 3 s of 20 Hz ticks.
# Prints the slowest ticks and the time of each scatter / sync pass.
#   godot --headless --path . --script res://src/worldgen/tools/profile_join.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")


func _init() -> void:
	var world_dir: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var dir: String = "user://profile_join"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	var calls: Array = [0, 0.0, 0.0]   # count, total ms, worst ms
	items.ground_height = func(x, z):
		var t0: int = Time.get_ticks_usec()
		var h: float = generator.surface_height(x, z)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		calls[0] += 1
		calls[1] += ms
		calls[2] = maxf(calls[2], ms)
		return h

	items.ground_ready = func(x, z) -> bool:
		if generator.tile_cached(x, z):
			return true

		generator.prefetch_tile(x, z)
		return false

	items.world_seed = int(settings.master_seed)
	items.setup(ItemTableScript.load_default(), dir)
	var t_join: int = Time.get_ticks_usec()
	items.peer_connected_hello(1, "profilekey01")
	items.report_position(1, Vector3(53301.0, 100.0, 68427.0))
	print("join: %.1f ms" % (float(Time.get_ticks_usec() - t_join) / 1000.0))
	var worst: Array = []

	for n in 100:
		var t0: int = Time.get_ticks_usec()
		items.tick(0.05)
		worst.append(float(Time.get_ticks_usec() - t0) / 1000.0)

	worst.sort()
	print("ticks: worst %.1f ms, 95th %.1f ms, median %.1f ms" % [worst[-1], worst[95], worst[50]])
	print("ground_height: %d calls, %.1f ms total, worst single %.1f ms" % [calls[0], calls[1], calls[2]])
	OS.delay_msec(3000)   # the worker thread finishes the tile read
	var after: Array = []

	for n in 40:
		var t2: int = Time.get_ticks_usec()
		items.tick(0.05)
		after.append(float(Time.get_ticks_usec() - t2) / 1000.0)
		OS.delay_msec(50)

	after.sort()
	var loose: int = 0

	for id in items._items:
		loose += 1 if items._items[id].has("scatter") else 0

	print("after the tile arrived: worst tick %.1f ms, %d loose stones and sticks laid out" % [after[-1], loose])

	for step in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(-1.0, 0.0)]:
		var t1: int = Time.get_ticks_usec()
		generator.surface_height(53301.0 + step.x * float(settings.tile_size_m), 68427.0 + step.y * float(settings.tile_size_m))
		print("surface_height at tile offset %s: %.1f ms" % [step, float(Time.get_ticks_usec() - t1) / 1000.0])

	items._finish_writer()
	quit(0)
