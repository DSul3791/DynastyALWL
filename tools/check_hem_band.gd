extends SceneTree

# Headless check (Sonny): cloth vertices carry how far inside their cloth they lie in the fraction of vertex alpha; edges (hems, cuffs, collar) are lower than the
# interior, skin vertices are untouched, and the material id still decodes from alpha.
#   godot --headless --path . --script res://tools/check_hem_band.gd

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	var boot_edges: int = 0

	for preset in ["average", "broad", "lean", "stocky"]:
		var built: Dictionary = Generator.build(Generator.make_genome(preset), 0.04, false)
		var colors: PackedColorArray = (built["arrays"] as Array)[Mesh.ARRAY_COLOR]
		var counts: Dictionary = {}
		var low: Dictionary = {}
		var high: Dictionary = {}

		for c in colors:
			var id: int = int(floor(c.a * 8.0))
			var frac: float = (c.a * 8.0 - float(id) - 0.05) / 0.9
			counts[id] = int(counts.get(id, 0)) + 1

			if id >= 3:
				if frac < 0.25:
					low[id] = int(low.get(id, 0)) + 1
				elif frac > 0.75:
					high[id] = int(high.get(id, 0)) + 1

		_ok(int(counts.get(0, 0)) > 0 and int(counts.get(3, 0)) > 0 and int(counts.get(4, 0)) > 0 and int(counts.get(5, 0)) > 0, "%s: skin, tunic, trousers and boots all decode from alpha" % preset)

		boot_edges += int(low.get(5, 0))

		# The boots now cover the toes too, so their only edge is where they meet the trousers: some presets (stocky) have none at this resolution; all four together must.
		for id in [3, 4, 5]:
			if id == 5:
				_ok(int(high.get(5, 0)) > 0, "%s: boots have interior vertices (%d)" % [preset, int(high.get(5, 0))])
				continue

			_ok(int(low.get(id, 0)) > 0 and int(high.get(id, 0)) > 0, "%s: material %d has edge vertices (%d) and interior vertices (%d)" % [preset, id, int(low.get(id, 0)), int(high.get(id, 0))])

	_ok(boot_edges > 0, "the boots have edge vertices in at least one body type (%d)" % boot_edges)
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)
