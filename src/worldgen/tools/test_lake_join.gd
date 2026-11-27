extends SceneTree

# A flat lake takes in water standing against it (a bay, piled water) but never lifts the river leaving it (WaterGrid._flatten_lakes,
# BugsList 157: a river 2 m below the lake was drawn at the lake's level out to the chunk's edge, two water levels side by side).
#   godot --headless --path . --script res://src/worldgen/tools/test_lake_join.gd

const WG := preload("res://src/worldgen/runtime/water_grid.gd")
const COUNT := 9


class FakeTile:
	var placeholder: bool = false
	var x0: float = 0.0
	var z0: float = 0.0
	var samples: int = 64
	var water_class: PackedByteArray = PackedByteArray()
	var heights: PackedFloat32Array = PackedFloat32Array()

	func _init() -> void:
		water_class.resize(samples * samples)
		heights.resize(samples * samples)
		heights.fill(1.5)

		for j in range(COUNT):
			for i in range(4):
				water_class[j * samples + i] = WG.LAKE_CLASS        # the lake: columns 0 to 3

	func nearest(x: float, z: float) -> int:
		return int(round(z / 8.0)) * samples + int(round(x / 8.0))


var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(COUNT * COUNT)

	for j in range(COUNT):
		for i in range(COUNT):
			var level: float = 3.78 + (0.05 if (i + j) % 2 == 0 else -0.05)    # the lake, sloshing a little

			if i == 4:
				level = 4.2 if j == 0 else 3.6                                    # piled water and a bay against the lake
			elif i > 4:
				level = 1.8                                                       # the river leaving it, 2 m lower

			levels[j * COUNT + i] = level

	WG._flatten_lakes(null, FakeTile.new(), Vector2.ZERO, COUNT, 8.0, levels)
	var lake: float = levels[0]
	check(absf(levels[4 * COUNT + 2] - lake) < 0.001 and absf(lake - 3.78) < 0.06, "the lake is flat at its median (%.2f)" % lake)
	check(absf(levels[4] - lake) < 0.001, "piled water over the lake joins it (%.2f)" % levels[4])
	check(absf(levels[4 * COUNT + 4] - lake) < 0.001, "a bay %.2f m under the lake joins it" % (lake - 3.6))
	check(absf(levels[4 * COUNT + 6] - 1.8) < 0.001 and absf(levels[8 * COUNT + 8] - 1.8) < 0.001, "the river 2 m below keeps its own level (%.2f)" % levels[4 * COUNT + 6])
	print("lake join: %d failures" % failures)
	quit(1 if failures > 0 else 0)
