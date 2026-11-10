extends SceneTree

# Every member of the inventory view that its parts reach into (view.<name> in src/client/ui/inventory/*.gd, _inv.<name> in held_item.gd) must
# exist on inventory_view.gd (Dave 10 Nov 2026: #971 removed _chest_last as unused, but pack_grid.gd and container_panel.gd still wrote it from
# their mouse_entered lambdas, and opening a fire broke the game). The parts' own tests use fake views, so they cannot see such a removal.
#   godot --headless --path . --script res://src/worldgen/tools/test_view_members.gd

const VIEW_PATH := "res://src/client/inventory_view.gd"
const PARTS_DIR := "res://src/client/ui/inventory/"
const HELD_PATH := "res://src/client/held_item.gd"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _members(script: Script) -> Dictionary:
	var out: Dictionary = {}

	for row in script.get_script_property_list():
		out[str(row["name"])] = true

	for row in script.get_script_method_list():
		out[str(row["name"])] = true

	for row in script.get_script_signal_list():
		out[str(row["name"])] = true

	for key in script.get_script_constant_map():
		out[str(key)] = true

	var base: String = script.get_instance_base_type()

	for row in ClassDB.class_get_property_list(base):
		out[str(row["name"])] = true

	for row in ClassDB.class_get_method_list(base):
		out[str(row["name"])] = true

	return out


func _uses(path: String, alias: String, members: Dictionary) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\b" + alias + "\\.([A-Za-z_][A-Za-z0-9_]*)")
	var seen: int = 0

	for found in pattern.search_all(text):
		var member: String = found.get_string(1)
		seen += 1
		check(members.has(member), "%s uses %s.%s, which inventory_view.gd does not have" % [path.get_file(), alias, member])

	return seen


func _init() -> void:
	var members: Dictionary = _members(load(VIEW_PATH))
	check(members.has("_chest_hover") and members.has("chest_mode"), "the view's members were read (%d)" % members.size())
	var uses: int = 0

	for file in DirAccess.get_files_at(PARTS_DIR):
		if file.ends_with(".gd"):
			uses += _uses(PARTS_DIR + file, "view", members)

	uses += _uses(HELD_PATH, "_inv", members)
	check(uses > 100, "the parts reach into the view (%d uses read)" % uses)
	print("test_view_members: %d uses, %d failures" % [uses, failures])
	quit(1 if failures > 0 else 0)
