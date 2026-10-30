extends SceneTree

# Runs the live water simulation on one baked tile from a dry start (springs fill the land) and reports where the
# water goes: do the baked channels carry it, or does it spill onto land and pool (wetlands)? Read-only. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/water_spread_report.gd -- --tile=3,4 --hours=6 --minutes=30
#
# Options: --tile=X,Z (default 3,4); --hours=H simulated hours to run (default 6); --minutes=M real-time limit (default 30);
#   --rate=R spring flow multiplier (default WaterLive.DEFAULT_RATE); --world=DIR world folder (default res://worlds/base_world). See GENERATOR_NOTES.md.

const WaterLive := preload("res://src/water/water_live.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const WET_M := 0.12            # depth at which a cell counts as wet
const POOL_M := 0.3            # depth at which water on land counts as standing water


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var hours: float = 6.0
	var minutes: float = 30.0
	var rate: float = WaterLive.DEFAULT_RATE
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--hours="):
			hours = float(argument.trim_prefix("--hours="))
		elif argument.begins_with("--minutes="):
			minutes = float(argument.trim_prefix("--minutes="))
		elif argument.begins_with("--rate="):
			rate = float(argument.trim_prefix("--rate="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(tile, hours, minutes, rate, world_dir))


func _run(tile: Vector2i, hours: float, minutes: float, rate: float, world_dir: String) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var data = generator.get_tile(tile)

	if data == null or data.placeholder:
		push_error("tile %s has no baked file" % str(tile))
		return 1

	var live = WaterLive.new()
	live.setup(tile, data, "", 3.0, generator, true)
	var started: int = Time.get_ticks_msec()
	live.begin()
	print("Simulation built in %.0f s (%d springs)" % [float(Time.get_ticks_msec() - started) / 1000.0, live.sim.springs.size()])
	var target_s: float = hours * 3600.0
	var limit_ms: int = started + int(minutes * 60000.0)
	var ticks: int = 0
	var next_report: float = 3600.0

	while live.seconds() < target_s and Time.get_ticks_msec() < limit_ms:
		live.tick(rate)
		ticks += 1

		if live.seconds() >= next_report:
			print("  simulated %.1f h after %.0f s real time (%d ticks)" % [live.seconds() / 3600.0, float(Time.get_ticks_msec() - started) / 1000.0, ticks])
			next_report += 3600.0

	print("Stopped at %.2f simulated hours (%d ticks, %.0f s real time)" % [live.seconds() / 3600.0, ticks, float(Time.get_ticks_msec() - started) / 1000.0])
	_report(data, live.sim.get_depth())
	return 0


func _report(data, depth: PackedFloat32Array) -> void:
	var side: int = int(data.samples)
	var cls: PackedByteArray = data.water_class
	var ground: PackedFloat32Array = data.heights
	var land: int = 0
	var channel_wet: int = 0
	var channel_dry: int = 0
	var channel_total: int = 0
	var spill: int = 0
	var standing: int = 0
	var spill_mark: PackedByteArray = PackedByteArray()
	spill_mark.resize(depth.size())
	var bands: Dictionary = {}

	for k in range(depth.size()):
		if ground[k] <= 0.3:
			continue

		land += 1
		var in_channel: bool = cls[k] == 2 or cls[k] == 3

		if in_channel:
			channel_total += 1

			if depth[k] >= WET_M:
				channel_wet += 1
			else:
				channel_dry += 1
		elif depth[k] >= WET_M:
			spill += 1
			spill_mark[k] = 1

			if depth[k] >= POOL_M:
				standing += 1

			var band: String = "under 30 m" if ground[k] < 30.0 else ("30 to 120 m" if ground[k] < 120.0 else ("120 to 400 m" if ground[k] < 400.0 else "over 400 m"))
			bands[band] = int(bands.get(band, 0)) + 1

	print("Land cells: %d (%.1f km2)" % [land, float(land) * 64.0 / 1.0e6])
	print("Baked river and lake cells on land: %d; wet %d (%.0f%%), dry %d (%.0f%%)" % [
		channel_total, channel_wet, 100.0 * float(channel_wet) / maxf(float(channel_total), 1.0), channel_dry, 100.0 * float(channel_dry) / maxf(float(channel_total), 1.0)
	])
	print("Wet cells OUTSIDE the baked channels (spill): %d (%.2f km2, %.2f%% of land); standing 0.3 m or deeper: %d" % [
		spill, float(spill) * 64.0 / 1.0e6, 100.0 * float(spill) / maxf(float(land), 1.0), standing
	])
	print("Spill by ground height: %s" % str(bands))
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(depth.size())
	var pools: Array = []

	for start in range(depth.size()):
		if spill_mark[start] == 0 or seen[start] == 1:
			continue

		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var size: int = 0
		var sum: float = 0.0
		var deepest: float = 0.0
		var touches_channel: bool = false

		while not stack.is_empty():
			var k: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			size += 1
			sum += depth[k]
			deepest = maxf(deepest, depth[k])
			var col: int = k % side
			var row: int = k / side

			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					if dr == 0 and dc == 0:
						continue

					var nc: int = col + dc
					var nr: int = row + dr

					if nc < 0 or nr < 0 or nc >= side or nr >= side:
						continue

					var n: int = nr * side + nc

					if (cls[n] == 2 or cls[n] == 3) and depth[n] >= WET_M:
						touches_channel = true

					if spill_mark[n] == 1 and seen[n] == 0:
						seen[n] = 1
						stack.append(n)

		pools.append([size, sum / float(size), deepest, touches_channel])

	pools.sort_custom(func(a, b): return a[0] > b[0])
	print("Spill patches: %d; the 12 largest (cells, area ha, mean depth m, deepest m, touches a wet channel):" % pools.size())

	for p in range(mini(12, pools.size())):
		print("  %6d cells, %6.1f ha, mean %.2f, max %.2f, %s" % [pools[p][0], float(pools[p][0]) * 0.0064, pools[p][1], pools[p][2], "yes" if pools[p][3] else "no"])
