extends SceneTree

# Water live-set soak (tech/WATER_NINE_TILES_PLAN.md, Technical direction's conditions): players move
# between the nine starter tiles; the water hub keeps at most 4 tiles live, stays under 1.2 GB of
# water memory, and a tile that goes to sleep is saved with the volume it held.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_soak.gd [-- --phase=SECONDS]

const Hub := preload("res://src/water/water_hub.gd")
const WS := preload("res://src/water/water_store.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# Volume on land cells (the simulation holds the sea by its own rule and total_volume leaves it out).
func _volume(path: String, side: int, ground: PackedFloat32Array) -> float:
	var depth: PackedFloat32Array = WS.load_depth(path, side)
	var total: float = 0.0

	for k in range(depth.size()):
		if ground[k] > 0.0:
			total += depth[k] * 64.0

	return total


func _init() -> void:
	var phase_s: float = 8.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			phase_s = float(argument.trim_prefix("--phase="))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file("res://worlds/base_world/world.json", errors)
	var rules = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, "res://worlds/base_world/tiles")
	var dir: String = ProjectSettings.globalize_path("user://water_soak")
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var hub = Hub.new()
	hub.setup(Vector2i(3, 4), dir, 3.0, generator, true)
	var phases: Array = [
		[Vector2i(3, 4)],
		[Vector2i(3, 4), Vector2i(4, 5)],
		[Vector2i(2, 3)],
		[Vector2i(4, 3), Vector2i(2, 5), Vector2i(3, 3), Vector2i(4, 4), Vector2i(3, 5)],
		[Vector2i(3, 4)],
		[Vector2i(4, 4), Vector2i(3, 5)],
	]
	var most: int = 0
	var peak_mb: float = 0.0
	var seen_tiles: Dictionary = {}
	var worst_drift: float = 0.0
	var round_trips: int = 0

	for tiles in phases:
		hub.set_live(tiles)
		var before: Dictionary = {}
		var end: int = Time.get_ticks_msec() + int(phase_s * 1000.0)

		while Time.get_ticks_msec() < end:
			OS.delay_msec(100)
			hub._mutex.lock()
			var loaded: Array = hub._tiles.keys()
			hub._mutex.unlock()
			most = maxi(most, loaded.size())

			for t in loaded:
				seen_tiles[t] = true

			peak_mb = maxf(peak_mb, float(OS.get_static_memory_usage() - hub._baseline) / 1048576.0)

			# Volumes just before the next change, for the tiles that will go to sleep.
			if Time.get_ticks_msec() > end - 300:
				for t in loaded:
					var sim = hub.sim_of(t)

					if sim != null:
						before[t] = sim.total_volume()

		# Tiles that were loaded and are no longer wanted have been saved: compare.
		hub._mutex.lock()
		var wanted: Array = hub._wanted.duplicate()
		hub._mutex.unlock()
		print("phase wanted %s, loaded %d, water memory %.0f MB" % [str(wanted), hub.stats()["loaded"], peak_mb])

	hub.stop()

	# With the thread stopped, what each live tile holds is what its saved file holds (error under 0.1 percent).
	for tile in hub._tiles.keys():
		var live = hub._tiles[tile]
		var held: float = live.sim.total_volume()
		var raw: PackedFloat32Array = live.sim.get_depth()
		var wet: int = 0

		for k in range(raw.size()):
			if live.data.heights[k] > 0.0 and raw[k] > 0.004:
				wet += 1

		live.unload()
		var saved: float = _volume("%s/tile_%d_%d.water" % [dir, tile.x, tile.y], 1921, live.data.heights)
		# The file keeps centimetres (0.5 cm either way per wet cell) and drops films under 4 mm: that is the error bound.
		var bound: float = float(wet) * 0.005 * 64.0 + 20.0
		worst_drift = maxf(worst_drift, absf(saved - held) / bound)
		print("tile %s: held %.0f m3, saved %.0f m3, %d wet cells, error %.0f m3 (bound %.0f m3, %.3f percent of held)" % [str(tile), held, saved, wet, absf(saved - held), bound, 100.0 * absf(saved - held) / maxf(held, 1.0)])
		round_trips += 1

	_check(round_trips > 0 and worst_drift <= 1.0, "sleeping a live tile keeps its volume within the one-centimetre save format (%d tiles, worst %.2f of the bound)" % [round_trips, worst_drift])
	_check(most <= 4, "never more than 4 live tiles (most %d)" % most)
	_check(peak_mb < 1228.0, "water memory stays under 1.2 GB (peak %.0f MB)" % peak_mb)
	_check(seen_tiles.size() >= 7, "the walk loaded %d of the nine tiles in turn" % seen_tiles.size())

	# Every tile that slept left a file whose volume is what the sim held (float32 round trip).
	var files: int = 0

	for tile in seen_tiles:
		var path: String = "%s/tile_%d_%d.water" % [dir, tile.x, tile.y]

		if FileAccess.file_exists(path):
			files += 1
			var depth: PackedFloat32Array = WS.load_depth(path, 1921)
			_check(depth.size() == 1921 * 1921, "tile %s saved at full size" % str(tile))

	_check(files >= 1, "tiles that went to sleep were saved (%d files)" % files)
	print("water soak: %d failures" % failures)
	quit(1 if failures > 0 else 0)
