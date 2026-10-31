extends SceneTree
const Hub2 := preload("res://src/water2/water_hub2.gd")
const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const TF := preload("res://src/worldgen/tile/tile_file.gd")
func _init() -> void:
	var path := "res://worlds/base_world/tiles/tile_3_4.tile"
	var head: Dictionary = TF.read_header(path)
	var td = TileTerrainData.new()
	td.samples = int(head["header"]["samples"])
	td.heights = TF.decode_height(TF.read_section(path, head["table"], "height")["raw"], TF.height_step_of(head["header"]))
	td._load_sim_water(path)
	var b: Dictionary = Hub2.build(td)
	var f = b["field"]
	var o: Vector2i = b["origin"]
	var best := Vector2i.ZERO
	var deep := 0.0
	for j in range(f.h):
		for i in range(f.w):
			if f.depth[j*f.w+i] > deep:
				deep = f.depth[j*f.w+i]; best = Vector2i(i, j)
	print("origin ", o, " world x ", 3*15360 + o.x*8, " z ", 4*15360 + o.y*8, " deepest ", deep, " at world ", 3*15360 + (o.x+best.x)*8, " ", 4*15360 + (o.y+best.y)*8, " ground ", f.bed[best.y*f.w+best.x])
	quit(0)
