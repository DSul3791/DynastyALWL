extends SceneTree

# How many baked wet cells of the starter window stay drawn over simulated time, and the volume kept (Sonny, 1 Nov 2026).
#   godot --headless --path . --script res://src/water2/probe_drain.gd

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
	var base: PackedFloat32Array = built["base"]
	var o: Vector2i = built["origin"]
	var v0: float = f.volume_m3()
	var t: int = 0

	for stop in [60, 180, 600, 1800]:
		while t < stop:
			f.step(1.0)
			t += 1

		var out: PackedFloat32Array = Hub2.publish_levels(base, td.samples, f, o)
		var wet: int = 0
		var drawn: int = 0
		var thin: int = 0
		var worst: float = 0.0

		for j in range(f.h):
			for i in range(f.w):
				var k: int = (o.y + j) * td.samples + o.x + i
				var m: int = j * f.w + i
				if f.bed[m] < 0.0 or is_nan(base[k]):
					continue
				wet += 1
				if not is_nan(out[k]):
					drawn += 1
				if f.depth[m] < 0.5 * (base[k] - f.bed[m]):
					thin += 1
				worst = maxf(worst, (base[k] - f.bed[m]) - f.depth[m])

		print("t=%4d s  drawn %d of %d (%.1f percent)  cells under half their baked depth %d  worst loss %.2f m  volume kept %.1f percent  awake blocks %d" % [t, drawn, wet, 100.0 * drawn / maxi(wet, 1), thin, worst, 100.0 * f.volume_m3() / maxf(v0, 1.0), f.awake_blocks()])

	quit()
