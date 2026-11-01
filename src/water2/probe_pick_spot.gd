extends SceneTree

# Where in the starter window is there real river or lake (bed above the sea), for a look-rig picture (Sonny, 1 Nov 2026).
#   godot --headless --path . --script res://src/water2/probe_pick_spot.gd

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
	var f = Hub2.build(td)["field"]
	var o: Vector2i = Hub2.build(td)["origin"]
	var best: Array = []

	for j in range(0, f.h, 4):
		for i in range(0, f.w, 4):
			var m: int = j * f.w + i
			if f.bed[m] > 1.0 and f.depth[m] > 0.5:
				best.append([f.depth[m], i, j])

	best.sort_custom(func(a, b): return a[0] > b[0])
	print("wet cells above sea sampled: %d" % best.size())
	for k in range(mini(8, best.size())):
		var i: int = best[k][1]
		var j: int = best[k][2]
		print("depth %.1f bed %.1f at world x %.0f z %.0f speed %.2f" % [best[k][0], f.bed[j * f.w + i], td.x0 + (o.x + i) * 8.0, td.z0 + (o.y + j) * 8.0, 0.0])
	quit()
