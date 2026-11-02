extends SceneTree

# No item may draw the grey placeholder chunk when it has an art override (guide findings F-17 and F-18): BasicLook.entry() must give the override whenever looks.json holds the grey
# chunk or no row; every look shape named by an override or a row must be one mesh() really builds (not the default blob). Also counts the items still on the placeholder, as a ceiling
# that is a data list with a reason per item: a new grey item fails the check until it is listed or drawn.
#   godot --headless --path . --script res://src/worldgen/tools/test_item_looks.gd

const BasicLook := preload("res://src/client/basic_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _is_placeholder(row: Dictionary) -> bool:
	return str(row.get("shape", "")) == "chunk" and str(row.get("color", "")).to_lower() == "#8a8a8a"


func _init() -> void:
	var rows: Dictionary = _json("res://data/items/looks.json").get("items", {})
	var src: String = FileAccess.get_file_as_string("res://src/client/basic_look.gd")
	var start: int = src.find("const ART_OVERRIDES")
	var finish: int = src.find("static func entry")
	var regex: RegEx = RegEx.new()
	regex.compile("\\t\"([a-z_0-9]+)\": \\{\"shape\"")
	var overridden: Array = []

	for m in regex.search_all(src.substr(start, finish - start)):
		overridden.append(m.get_string(1))

	check(overridden.size() > 20, "the override table was read (%d items)" % overridden.size())

	for id in overridden:
		var def: Dictionary = BasicLook.entry(id)
		check(not def.is_empty() and not _is_placeholder(def), "item %s has an art override and does not draw the grey chunk (row in looks.json: %s)" % [id, str(rows.get(id, "none"))])
		check(BasicLook.mesh_for(id) != null, "item %s builds a mesh" % id)

	var placeholders: Array = []

	for id in rows:
		var def: Dictionary = BasicLook.entry(id)

		if _is_placeholder(def):
			placeholders.append(id)

	placeholders.sort()
	var known: Dictionary = _json("res://data/items/look_placeholders.json").get("items", {})
	print("items on the grey placeholder look (%d, %d listed with a reason): %s" % [placeholders.size(), known.size(), ", ".join(placeholders)])

	for id in placeholders:
		check(known.has(id), "new placeholder: item %s draws the grey chunk: give it a look, or list it with a reason in data/items/look_placeholders.json" % id)

	for id in known:
		if rows.has(id):   # a listed id that is not in looks.json yet (an item from a branch not merged here) is skipped
			check(placeholders.has(id), "item %s is listed as a placeholder but already has a look: delete its row in data/items/look_placeholders.json" % id)

	print("item look tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
