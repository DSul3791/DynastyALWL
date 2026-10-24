extends SceneTree

# Vertex budget table for flora models (goal 2, Kathleen): plants 600 near / 150 far, shrubs 4000 near / 800 far.
# Builds every species at its mid height and fails when one is over. Run: godot --headless --path . -s src/worldgen/tools/test_flora_budget.gd

const TreeBuilderScript := preload("res://src/flora/tree_builder.gd")
const LIMITS := {"plant": [600, 150], "shrub": [4000, 800]}
# Species already over budget when this test was added (24 Oct) may not grow: their counts are the ceiling until they are brought under.
const BASELINE_PATH := "res://data/flora_budget_baseline.json"


func _init() -> void:
	var materials: Dictionary = {}

	for key in ["bark", "birch_bark", "smooth_bark", "chrome", "ember", "broad", "conifer", "palm", "grass", "twig", "oak", "willow", "rowan", "maple", "witness"]:
		materials[key] = StandardMaterial3D.new()

	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var failed: int = 0
	var checked: int = 0
	var over: Dictionary = {}
	var baseline: Dictionary = {}

	if FileAccess.file_exists(BASELINE_PATH):
		baseline = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))

	for entry in table["entries"]:
		var kind: String = str(entry.get("kind", ""))

		if not LIMITS.has(kind):
			continue

		var h: float = (float(entry["height_m"][0]) + float(entry["height_m"][1])) * 0.5
		var counts: Array = []

		for far in [false, true]:
			var mesh: ArrayMesh = TreeBuilderScript.build(entry, h, 0, far, materials)
			var v: int = 0

			if mesh != null:
				for s in range(mesh.get_surface_count()):
					v += mesh.surface_get_array_len(s)

			counts.append(v)

		checked += 1
		var limit: Array = LIMITS[kind]

		if counts[0] > limit[0] or counts[1] > limit[1]:
			over[entry["name"]] = counts
			var allowed: Array = baseline.get(entry["name"], [limit[0], limit[1]])

			if counts[0] > maxi(allowed[0], limit[0]) or counts[1] > maxi(allowed[1], limit[1]):
				failed += 1
				print("OVER BUDGET %s (%s): near %d (allowed %d) far %d (allowed %d)" % [entry["name"], kind, counts[0], maxi(allowed[0], limit[0]), counts[1], maxi(allowed[1], limit[1])])

	if OS.get_cmdline_user_args().has("--write-baseline"):
		var file: FileAccess = FileAccess.open("res://data/flora_budget_baseline.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(over, " ", true))
		file.close()

	print("flora budget: %d of them over budget but at or under their recorded ceiling," % (over.size() - failed))
	print("flora budget: %d species checked, %d over budget" % [checked, failed])
	quit(1 if failed > 0 else 0)
