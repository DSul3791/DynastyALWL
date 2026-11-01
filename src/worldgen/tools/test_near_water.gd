extends SceneTree

# near_water() (the two-pass version) equals the nine-neighbour definition on a random map, edges included (Sonny, 1 Nov 2026).
#   godot --headless --path . --script res://src/worldgen/tools/test_near_water.gd

const DataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")


func _init() -> void:
	var data = DataScript.new()
	var side: int = 61
	data.samples = side
	data.water_class.resize(side * side)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7

	for k in range(side * side):
		data.water_class[k] = rng.randi_range(0, 3) if rng.randf() < 0.08 else 0

	var got: PackedByteArray = data.near_water()
	var wrong: int = 0

	for j in range(side):
		for i in range(side):
			var hit: int = 0

			for dj in range(maxi(j - 1, 0), mini(j + 2, side)):
				for di in range(maxi(i - 1, 0), mini(i + 2, side)):
					var kind: int = data.water_class[dj * side + di]

					if kind == 2 or kind == 3:
						hit = 1

			if got[j * side + i] != hit:
				wrong += 1

	print(("ok   " if wrong == 0 else "FAIL ") + "near_water equals the brute-force 3x3 on %d samples (%d differ)" % [side * side, wrong])
	quit(0 if wrong == 0 else 1)
