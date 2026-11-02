extends SceneTree

# Structure looks are not changed by accident (Kathleen, 2026-10-31; the tier-look commit once pointed the lean-to at "log_wall"): every structure that existed before the tier pieces keeps the look it
# had (GOLDEN), the ten tier pieces name their own new looks (TIERS), and the new looks are in the look table (tools/check_look_names.py checks every structure's look name).
#   godot --headless --path . --script res://src/worldgen/tools/test_structure_looks.gd

const LookTable := preload("res://src/client/look_table.gd")

const GOLDEN := {
	"lean_to": "lean_to",
	"chest": "chest",
	"chopping_block": "chopping_block",
	"plank_chest": "chest",
	"remains": "remains",
	"workbench": "workbench",
	"tool_rack": "tool_rack",
	"vice": "vice",
	"log_workbench": "log_workbench",
	"saw_mill": "saw_mill",
	"woodworking_table": "woodworking_table",
	"stone_forge": "stone_forge",
	"blacksmithy": "blacksmithy",
	"carcass": "carcass",
	"large_forge": "big_forge",
	"master_forge": "big_forge",
	"wall_section": "wall",
	"floor_section": "ceiling",
	"roof_section": "roof",
	"foundation_section": "foundation",
	"doorway_section": "door_shut",
	"window_section": "window_wall",
	"door_open": "door_open",
	"timber_prop": "prop",
	"timber_set": "set",
	"ladder": "ladder",
	"path_patch": "path",
	"tilled_bed": "path",
	"rough_bed": "rough_bed",
	"thatch_wall": "thatch_wall",
	"campfire_pot": "tripod_pot",
	"clay_hearth": "clay_hearth",
	"snare_trap": "snare_trap",
	"oven": "oven",
	"thatch_floor": "thatch_floor",
	"thatch_roof": "thatch_roof",
	"thatch_doorway": "thatch_doorway",
	"rock_pile": "rock_pile",
}
const TIERS := {
	"stairs_wood": "stairs",
	"log_wall": "log_wall",
	"log_floor": "log_floor",
	"log_roof": "log_roof",
	"stone_wall": "stone_wall",
	"stone_floor": "stone_floor",
	"stone_roof": "stone_roof",
	"brick_wall": "brick_wall",
	"brick_floor": "brick_floor",
	"brick_roof": "brick_roof",
}

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL " + what)
		_failures += 1


func _init() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var rows: Dictionary = parsed.get("structures", parsed)

	for id in GOLDEN:
		_check(rows.has(id), "structure %s still exists" % id)

		if rows.has(id):
			_check(str(rows[id].get("look", "")) == str(GOLDEN[id]), "%s draws '%s' (it drew '%s' before the tier pieces)" % [id, str(rows[id].get("look", "")), str(GOLDEN[id])])

	for id in TIERS:
		_check(rows.has(id) and str(rows[id].get("look", "")) == str(TIERS[id]), "tier piece %s draws its own look '%s'" % [id, str(TIERS[id])])

	for look in TIERS.values():
		_check(LookTable.has_look(str(look)), "look '%s' is in the look table" % str(look))

	print("structure looks: %d originals, %d tier pieces, %d failures" % [GOLDEN.size(), TIERS.size(), _failures])
	quit(_failures)
