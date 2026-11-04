extends SceneTree

# Seasonal fruit and flowers (Kathleen, 2026-10-31): a berry bush shows berries only in its fruiting season (ripe_in from flora.json "season"), and a flower or herb row flagged
# "seasonal": true is not built at all out of season.
#   godot --headless --path . --script res://src/worldgen/tools/test_season_fruit.gd

const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const GameClock := preload("res://src/shared/game_clock.gd")
const GatherRules := preload("res://src/shared/gather_rules.gd")

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	_failures += 0 if ok else 1


func _verts(mesh: ArrayMesh) -> int:
	var n: int = 0

	for s in range(mesh.get_surface_count()):
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	return n


func _init() -> void:
	var rows: Dictionary = {}

	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json")).get("entries", []):
		rows[str(row["name"])] = row

	var mats: Dictionary = {"bark": StandardMaterial3D.new(), "broad": StandardMaterial3D.new()}
	var blue: Dictionary = (rows["blueberry"] as Dictionary).duplicate()   # blueberry fruits in summer only
	var summer: int = _verts(TreeBuilder.build(blue, 1.0, 0, false, mats, "summer"))
	var winter: int = _verts(TreeBuilder.build(blue, 1.0, 0, false, mats, "winter"))
	print("blueberry vertices: summer %d, winter %d" % [summer, winter])
	_check(summer > winter, "a blueberry bush has berries in summer and fewer vertices in winter")
	var lav: Dictionary = (rows["lavender"] as Dictionary).duplicate()
	lav["seasonal"] = true
	var bloom: int = _verts(TreeBuilder.build(lav, 0.6, 0, false, mats, "summer"))
	var gone: int = _verts(TreeBuilder.build(lav, 0.6, 0, false, mats, "winter"))
	print("lavender (seasonal) vertices: summer %d, winter %d" % [bloom, gone])
	_check(bloom > 0 and gone == 0, "a seasonal lavender is drawn in summer and not at all in winter")
	var plain: int = _verts(TreeBuilder.build(rows["lavender"], 0.6, 0, false, mats, "winter"))
	_check(plain > 0, "without the seasonal flag a flower row keeps its winter model")
	# Dave, 4 Nov 2026: the game starts when there is food on the vines and trees. A new world's clock must land in a season
	# where the berry bushes and fruit trees near spawn can be picked.
	var start: String = GameClock.new().season()
	print("new world starts in %s" % start)
	_check(start == "summer", "a new world starts in summer")
	for name in ["raspberry", "bramble", "blueberry", "wild_strawberry", "wild_cherry", "apple_early", "plum"]:
		_check(GatherRules.in_season(rows[name], start), "%s can be picked on the first day" % name)
	# BUG-018: no raspberries in spring is right; the look-at line says "Raspberries - Out of Season" (harvest.gd product_name_at).
	_check(not GatherRules.in_season(rows["raspberry"], "spring") and GatherRules.in_season(rows["raspberry"], "summer"), "raspberries are out of season in spring and in season in summer")
	_check(str(preload("res://src/client/harvest.gd").OUT_OF_SEASON_FORMAT) % "Raspberries" == "Raspberries - Out of Season", "the out of season look-at line reads Raspberries - Out of Season")
	print("season fruit test: %d failures" % _failures)
	quit(_failures)
