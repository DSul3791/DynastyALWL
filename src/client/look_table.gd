extends RefCounted
# One table of the building-piece looks: look name (structures.json "look") -> the PieceLook builder and its arguments. Adding a look is one
# line here; an unknown name draws a visible placeholder box and warns once (inventory_view._model_for_state). tools/check_look_names.py
# reads this file's keys, so every structures.json look must be here or in the dispatcher's own match.

const PieceLookScript := preload("res://src/client/piece_look.gd")

const LOOKS := {
	"wall": {"builder": "wall", "args": []},
	"floor": {"builder": "floor_piece", "args": []},
	"ceiling": {"builder": "ceiling", "args": []},
	"roof": {"builder": "roof", "args": []},
	"flat_roof": {"builder": "flat_roof", "args": []},
	"foundation": {"builder": "foundation", "args": []},
	"prop": {"builder": "prop", "args": []},
	"set": {"builder": "timber_set", "args": []},
	"ladder": {"builder": "ladder", "args": []},
	"path": {"builder": "path", "args": []},
	"rock_pile": {"builder": "rock_pile", "args": []},
	"window_wall": {"builder": "window_wall", "args": []},
	"door_shut": {"builder": "doorway", "args": [false]},
	"door_open": {"builder": "doorway", "args": [true]},
	"log_wall": {"builder": "log_wall", "args": [false]},
	"door_basic": {"builder": "door", "args": [1.0, 1, "none", false, false]},
	"door_plank": {"builder": "door", "args": [1.0, 1, "bar", false, false]},
	"door_double": {"builder": "door", "args": [2.0, 2, "bar", false, false]},
	"door_steel": {"builder": "door", "args": [1.0, 1, "steel", true, false]},
	"door_wrought": {"builder": "door", "args": [1.0, 1, "steel", true, false]},
	"brace_short": {"builder": "brace", "args": [1.5]},
	"brace_mid": {"builder": "brace", "args": [3.0]},
	"brace_long": {"builder": "brace", "args": [5.0]},
	"saw_mill": {"builder": "saw_mill", "args": []},
	"water_wheel": {"builder": "water_wheel", "args": []},
	"woodworking_table": {"builder": "woodworking_table", "args": []},
	"rough_bed": {"builder": "rough_bed", "args": []},
	"thatch_wall": {"builder": "thatch_wall", "args": []},
	"tripod_pot": {"builder": "tripod_pot", "args": []},
	"clay_hearth": {"builder": "clay_hearth", "args": []},
}

static var _warned: Dictionary = {}
static var _builders: RefCounted   # an instance only so the static builders can be called by name


static func has_look(look: String) -> bool:
	return LOOKS.has(look)


# The model for a look name (a fresh node each time; PieceLook caches the meshes and materials). Unknown: a visible placeholder.
static func build(look: String) -> Node3D:
	if not LOOKS.has(look):
		if not _warned.has(look):
			_warned[look] = true
			push_warning("Unknown piece look '%s': drawing a placeholder box" % look)

		var box: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(1.0, 1.0, 1.0)
		box.mesh = mesh
		box.position = Vector3(0.0, 0.5, 0.0)
		var holder: Node3D = Node3D.new()
		holder.add_child(box)
		return holder

	if _builders == null:
		_builders = PieceLookScript.new()

	var entry: Dictionary = LOOKS[look]
	return _builders.callv(str(entry["builder"]), entry["args"])
