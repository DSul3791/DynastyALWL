extends SceneTree
const S := preload("res://src/water/water_store.gd")
func _init() -> void:
	var d: PackedFloat32Array = S.load_depth(OS.get_cmdline_user_args()[0], 1921)
	print("size ", d.size())
	var wet := 0
	var vol := 0.0
	for v in d:
		if v > 0.0:
			wet += 1
			vol += v
	print("wet %d mean depth %.2f" % [wet, vol / maxf(wet, 1)])
	for spot in [Vector2(51603, 69331), Vector2(51609, 69364)]:
		var c: int = int(spot.x / 8.0) - 5760
		var r: int = int(spot.y / 8.0) - 7680
		print("spot ", spot, " col ", c, " row ", r)
		for dr in range(-3, 4, 3):
			var line := ""
			for dc in range(-12, 13):
				var v: float = d[(r + dr) * 1921 + c + dc]
				line += "%4.1f " % v
			print(" row%+d %s" % [dr, line])
	quit()
