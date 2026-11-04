extends SceneTree
# scratch probe (not committed): run the sim from the saved water and watch one lake's chequer
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")
const WaterStore := preload("res://src/water/water_store.gd")

func rough(sim, side, ci, cj, r) -> String:
	var tot := 0.0; var cnt := 0; var mx := 0.0
	var d: PackedFloat32Array = sim.get_depth()
	for j in range(cj - r, cj + r):
		for i in range(ci - r, ci + r):
			var k: int = j * side + i
			if d[k] > 0.3 and d[k + 1] > 0.3:
				var a: float = sim.ground[k] + d[k]; var b: float = sim.ground[k + 1] + d[k + 1]
				tot += absf(a - b); cnt += 1; mx = maxf(mx, absf(a - b))
	return "mean step %.3f max %.2f over %d pairs" % [tot / maxf(cnt, 1), mx, cnt]

func _initialize() -> void:
	var W := "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(W + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(W + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	tables.load_directory()
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, W + "/tiles")
	var data = generator.get_tile(Vector2i(3, 4))
	var side: int = data.samples
	var sim = WaterSettler.build(data, 10.0, generator)
	sim.spring_multiplier = 10.0
	sim.set_depth(WaterStore.load_depth(W + "/water/tile_3_4.water", side))
	sim.wake_all_wet()
	var spots := [[716, 969, "funnel lake"], [588, 1402, "hollow 50781"], [1564, 1388, "lake 58590"]]
	for s in spots: print("start ", s[2], ": ", rough(sim, side, s[0], s[1], 12))
	for t in range(1, 1201):
		sim.step()
		if t % 15 == 0: sim.level_map()
		if t % 300 == 0:
			for s in spots: print("tick ", t, " ", s[2], ": ", rough(sim, side, s[0], s[1], 12))
	quit(0)
