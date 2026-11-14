extends SceneTree

# Every look in src/client/look_table.gd builds a model, and a piece stays under the near triangle budget (Tyler, 300; log walls and the
# sawmill are drawn with more cylinders, so they get their own larger cap here).
#   godot --headless --path . --script res://src/worldgen/tools/test_look_table.gd

const LookTable := preload("res://src/client/look_table.gd")
const NEAR_TRIANGLES := 300
const BIG := {"rock_pile": 900, "rough_bed": 1300, "log_wall": 1500, "saw_mill": 1500, "water_wheel": 800, "woodworking_table": 600, "foundation": 600, "clay_hearth": 600, "oven": 450, "thatch_floor": 300, "thatch_doorway": 400, "log_seat": 400, "wool_rug": 950, "hide_rug": 520, "straw_bed": 400, "feather_bed": 500, "canopy_bed": 1150, "chandelier": 600, "flower_pot": 720}   # the comfort furniture (Kathleen, 2026-10-31)
# Buildables B1a (Kathleen, 10 Nov 2026): each new piece gets the cap of the piece it matches. The log foundation the stone foundation's (600); the thatch
# window the thatch doorway's (400); the log doorway and window are log courses split either side of a gap, so nearly
# twice a log wall's logs (log_wall itself 1500), 800; the stone and brick doorways and windows are masonry_wall with jamb blocks or a brick arch,
# 450 (the oven's).
const B1A := {"log_foundation": 600, "thatch_window": 400, "log_doorway": 800, "log_window": 800,
	"stone_doorway": 450, "brick_doorway": 450, "stone_window": 450, "brick_window": 450}
# Buildables B1b to B6 (Kathleen, 10 Nov 2026), again the cap of the piece each matches. The log stairs are the stone stairs' ten steps (240) on two log
# stringers, 350. The thatch and log roof corners are their straight roofs (log 300)
# with a third eave or a fascia and a corner post, 400 (the thatch doorway's). A fence section or gate is a 2 m wall piece between two shared
# eight-sided posts, 600 (door_double's); the log palisade is six whole sharpened stakes, a log wall stood upright, 900 (under log_wall's 1500). The
# barrel, the stone well and the deep well pump are round builds like the clay hearth and flower pot, 500 (the well 550); the stone torch pillar
# and the lamp posts are a round pillar or iron standard with a lantern on it, 450 (the oven's; the chandelier is 600); the thatch garden plot is
# a 2 m bed with four lashed stakes and a woven edge, 600 (the foundation's).
const FENCES := ["thatch_fence", "thatch_gate", "thatch_gate_open", "wood_fence", "wood_gate", "wood_gate_open", "log_fence", "log_gate", "log_gate_open",
	"stone_fence", "stone_gate", "stone_gate_open", "brick_fence", "brick_gate", "brick_gate_open", "iron_fence", "iron_gate", "iron_gate_open"]
const B1B_B6 := {"log_stairs": 350,
	"thatch_roof_corner": 400, "log_roof_corner": 400, "log_palisade": 900, "log_palisade_gate": 900, "log_palisade_gate_open": 900,
	"wooden_barrel": 500, "stone_well": 550, "primitive_well": 700, "advanced_well": 700, "iron_deep_well_pump": 500, "stone_torch_pillar": 450, "wooden_lamp_post": 450, "iron_lamp_post": 450,
	"stone_lamp_post": 450, "thatch_garden_plot": 600}
# The pitched tier roof corners (Kathleen, 10 Nov 2026): the clay tile roofs add a rib down the slope every 0.24 m and a round ridge tile to the courses;
# the straight roofs are panels since GOALS-REPAIR A-35/A-36 (tier_panel, 132 to 216 triangles, under the default cap);
# their hip corners carry the ribs over three faces and two hip caps, 400 (the thatch and log corners').
const TILE_ROOFS := {"brick_roof_corner": 400, "engineered_roof_corner": 400}
# The Fortified set proper (Kathleen, 10 Nov 2026): the doorway is the stone doorway's family with bolted bands, 450.
const FORTIFIED := {"fortified_doorway": 450}
# BUGLIST-002 (13 Nov 2026): the new empty doorway frames. The double is the single's wall twice as wide, so the single's cap; an arched frame adds the wall steps and
# a ring of voussoirs, bent sticks or timbers round the curve (measured with tools/look_runtime.py at 252 to 1056). A door is one parametric builder: a single leaf
# 180 to 744 triangles, a double leaf pair twice that (Fortified double arched 1488); the open look is the same leaf swung.
const DOOR_FRAMES := {"thatch_double_doorway": 400, "thatch_arched_doorway": 700, "thatch_double_arched_doorway": 700,
	"log_double_doorway": 800, "log_arched_doorway": 1150, "log_double_arched_doorway": 1150,
	"double_doorway": 450, "wood_arched_doorway": 550, "wood_double_arched_doorway": 550,
	"stone_double_doorway": 450, "stone_arched_doorway": 800, "stone_double_arched_doorway": 800,
	"brick_double_doorway": 500, "brick_arched_doorway": 700, "brick_double_arched_doorway": 700,
	"engineered_arched_doorway": 500, "engineered_double_arched_doorway": 550,
	"fortified_arched_doorway": 800, "fortified_double_arched_doorway": 850}
const DOOR_SINGLE := 800
const DOOR_DOUBLE := 1600

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _triangles(node: Node) -> int:
	var total: int = 0

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += floori(float((node as MeshInstance3D).mesh.get_faces().size()) / 3.0)

	for child in node.get_children():
		total += _triangles(child)

	return total


func _cap(look: String) -> int:
	if look in FENCES:
		return 600

	if ("_door" in look) and not ("doorway" in look):      # a door (shut or open): one leaf, or two for a double
		return DOOR_DOUBLE if "double" in look else DOOR_SINGLE

	return int(BIG.get(look, B1A.get(look, B1B_B6.get(look, TILE_ROOFS.get(look, FORTIFIED.get(look, DOOR_FRAMES.get(look, NEAR_TRIANGLES)))))))


func _init() -> void:
	for look in LookTable.LOOKS:
		var model: Node3D = LookTable.build(look)
		var tris: int = _triangles(model)
		check(model != null and model.get_child_count() > 0, "look %s builds a model" % look)
		check(tris <= _cap(look), "look %s stays under its triangle cap (%d)" % [look, tris])
		model.free()

	var unknown: Node3D = LookTable.build("no_such_look_name")
	check(unknown.get_child_count() == 1, "an unknown look draws a placeholder box")
	unknown.free()
	print("look table: %d looks, %d failures" % [LookTable.LOOKS.size(), failures])
	quit(failures)
