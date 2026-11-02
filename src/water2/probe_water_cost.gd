extends SceneTree

# Dynasty water: cost of the starter-tile window over time (Sonny, 31 Oct 2026): awake blocks, cells stepped and milliseconds per simulated second, every 30 s for 5 simulated minutes.
#   godot --headless --path . --script res://src/water2/probe_water_cost.gd

const Hub2 := preload("res://src/water2/water_hub2.gd")
const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const TF := preload("res://src/worldgen/tile/tile_file.gd")


func _init() -> void:
	var path: String = "res://worlds/base_world/tiles/tile_3_4.tile"
	var head: Dictionary = TF.read_header(path)
	var td = TileTerrainData.new()
	td.samples = int(head["header"]["samples"])
	td.heights = TF.decode_height(TF.read_section(path, head["table"], "height")["raw"], TF.height_step_of(head["header"]))
	td._load_sim_water(path)
	var built: Dictionary = Hub2.build(td)
	var f = built["field"]
	var wet: int = 0

	for k in range(f.w * f.h):
		if f.depth[k] > 0.0:
			wet += 1

	print("window %d x %d, %d wet cells at the start" % [f.w, f.h, wet])
	var ms: float = 0.0
	var cells: int = 0

	for s in range(1, 301):
		var t0: int = Time.get_ticks_usec()
		f.step(1.0)
		ms += float(Time.get_ticks_usec() - t0) / 1000.0
		cells += f.cells_stepped

		if s % 30 == 0:
			print("t=%3d s  awake blocks %2d of 64  cells/s %6d  ms per simulated second %.1f  us per cell %.1f" % [s, f.awake_blocks(), cells / 30, ms / 30.0, ms * 1000.0 / maxf(float(cells), 1.0)])
			var w: int = 0

			for k in range(f.w * f.h):
				if f.depth[k] > 0.0:
					w += 1

			var p0: int = Time.get_ticks_usec()
			Hub2.publish_levels(built["base"], td.samples, f, built["origin"])
			print("        wet cells %d (%.0f percent of the window), publish_levels %.1f ms on the main-path (every 15 s)" % [w, 100.0 * w / (f.w * f.h), float(Time.get_ticks_usec() - p0) / 1000.0])
			ms = 0.0
			cells = 0

	quit(0)
