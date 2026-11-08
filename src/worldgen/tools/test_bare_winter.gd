extends SceneTree
# Headless check of bare broadleaves in winter (--bare-winter, docs/design/trees_weather_design.md part B, never-see 2): with the
# switch, the temperate deciduous broadleaves are built per season (so winter draws their bare build) and the evergreens are not.

const FloraView := preload("res://src/flora/flora_view.gd")

const EVERGREEN := ["tropical_hardwood", "mangrove", "acacia", "olive", "orange", "lemon", "mango", "fig", "pomegranate", "spruce", "scots_pine", "balsam_fir", "everember", "wardpine"]

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _flora_rows() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))

	if parsed is Array:
		return parsed

	if parsed is Dictionary:
		for value in (parsed as Dictionary).values():
			if value is Array:
				return value

	return []


func _init() -> void:
	var rows: Array = _flora_rows()
	_check(rows.size() > 40, "the flora table loads (%d rows)" % rows.size())
	var names: Dictionary = {}

	for row in rows:
		names[str(row.get("name", ""))] = true

	for tree_name in FloraView.DECIDUOUS:
		_check(names.has(tree_name), "%s is a flora.json species" % tree_name)

	var berries: Array = ["raspberry", "blueberry"]
	var off: Dictionary = FloraView.seasonal_names(berries, rows, false)
	var on: Dictionary = FloraView.seasonal_names(berries, rows, true)
	_check(not off.has("oak") and off.has("raspberry") and off.has("wild_apple"), "switch off: only the fruit bearers and seasonal rows are built per season, as today")

	for tree_name in FloraView.DECIDUOUS:
		_check(on.has(tree_name), "switch on: %s is built per season (bare in winter)" % tree_name)

	for tree_name in EVERGREEN:
		_check(not on.has(tree_name), "switch on: %s keeps its leaves" % tree_name)

	_check(on.has("raspberry") and on.has("wild_apple"), "switch on: the fruit bearers stay seasonal")

	# The view: deciduous names are leaf-only (no stripped build) and skip the in-leaf impostor cards in winter only.
	var view = FloraView.new()
	view._setup_entries = rows

	for row in rows:
		view._slugs[int(row["id"])] = str(row["name"])

	FloraView.bare_winter_on = true
	view.set_fruiting(berries)
	_check(view._leaf_only.has("oak") and not view._leaf_only.has("raspberry") and not view._leaf_only.has("wild_apple"), "oak is leaf-only, the fruit bearers are not")
	var oak_id: int = -1
	var spruce_id: int = -1

	for row in rows:
		if str(row["name"]) == "oak":
			oak_id = int(row["id"])
		elif str(row["name"]) == "spruce":
			spruce_id = int(row["id"])

	view.season = "winter"
	_check(view._leafless_now(oak_id) and not view._leafless_now(spruce_id), "winter: a far oak draws its bare far model, a far spruce its impostor")
	view.season = "summer"
	_check(not view._leafless_now(oak_id), "summer: the oak's impostor card is used as today")
	FloraView.bare_winter_on = false
	view.season = "winter"
	_check(not view._leafless_now(oak_id), "switch off: unchanged")
	view.free()

	print("bare winter: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
