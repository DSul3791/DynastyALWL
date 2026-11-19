extends SceneTree

# The client half of farming (GOALS-REPAIR WP-R1B): what E on a tilled bed says and asks for (FarmRules.bed_action, held by inventory_view._bed_interaction), which seed sows which crop, and
# that every crop in crops.json has a placeholder stage look (CropLook), and the hoe's plant list and grid (FarmRules.plantables, grid_points); the server decides each grid point (test_farming.gd). The server's own checks are in test_farming.gd.
#   godot --headless --path . --script res://src/worldgen/tools/test_farm_prompt.gd

const FarmRules := preload("res://src/shared/farm_rules.gd")
const CropLook := preload("res://src/client/crop_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var crops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))["crops"]

	# Seeds.
	check(FarmRules.crop_of_seed(crops, "flax_seeds") == "flax" and FarmRules.crop_of_seed(crops, "rye_seeds") == "rye", "flax seeds sow flax, rye seeds rye")
	check(FarmRules.crop_of_seed(crops, "bronze_sickle") == "" and FarmRules.crop_of_seed(crops, "") == "", "a sickle, or nothing, sows nothing")

	# An empty bed: E never sows (Dave play test 19 Nov 2026: seeds went in without the hoe in hand); it says the hoe's Plant grid sows, and sends nothing, whatever is in hand.
	var plan: Dictionary = FarmRules.bed_action(crops, "", -1, -1)
	check(plan["act"] == "none" and plan["prompt"] == "A tilled bed: " + FarmRules.EMPTY_BED_PROMPT and str(plan["prompt"]).contains("hoe") and str(plan["prompt"]).contains("Plant"), "an empty bed sends nothing and points to the hoe's Plant (%s)" % str(plan["prompt"]))
	plan = FarmRules.bed_action(crops, "", -1, 4)
	check(plan["act"] == "none", "an empty bed with water in hand still sends nothing")

	# A crop short of ripe: water with the filled container in hand (b = its slot), else say so; never harvest.
	for stage in range(3):
		plan = FarmRules.bed_action(crops, "flax", stage, 4)
		check(plan["act"] == "water" and plan["b"] == 4 and plan["prompt"] == "Press E to water the flax (%s)" % FarmRules.STAGE_NAMES[stage], "flax at stage %d with a filled container in slot 4: water it, b = 4" % stage)
		plan = FarmRules.bed_action(crops, "flax", stage, -1)
		check(plan["act"] == "none" and str(plan["prompt"]).begins_with("Flax, %s" % FarmRules.STAGE_NAMES[stage]), "flax at stage %d with no water in hand: says its stage, sends nothing" % stage)

	# The soil's moisture in the line (garden moisture, Dave 19 Nov 2026: "if it needs water it should show its moisture content"), from the row's "moist".
	var moist_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))["moisture"]
	plan = FarmRules.bed_action(crops, "chamomile", 0, -1, 15, moist_cfg)
	check(plan["act"] == "none" and plan["prompt"] == "Chamomile, seedling, soil 15% dry, needs water: hold a filled bucket or waterskin and press E to water it", "a dry seedling says its soil is dry and needs water (%s)" % plan["prompt"])
	plan = FarmRules.bed_action(crops, "chamomile", 1, 4, 45, moist_cfg)
	check(plan["act"] == "water" and plan["prompt"] == "Press E to water the chamomile (young, soil 45% damp)", "with water in hand it says the soil too (%s)" % plan["prompt"])
	plan = FarmRules.bed_action(crops, "", -1, -1, 80, moist_cfg)
	check(plan["act"] == "none" and plan["prompt"] == "A tilled bed (soil 80% wet): hold the hoe, right click and choose Plant to sow it", "an empty bed says its soil (%s)" % plan["prompt"])
	check(FarmRules.soil_words(-1, moist_cfg) == "", "a row without moisture says nothing of the soil")

	# Ripe: harvest (b unused), and say a sickle gives the full yield only where the crop needs one.
	plan = FarmRules.bed_action(crops, "flax", 3, 4)
	check(plan["act"] == "harvest" and plan["b"] == 0 and plan["prompt"] == "Press E to harvest the flax (a sickle gives the full yield)", "ripe flax harvests, even with water in hand, and names the sickle")
	plan = FarmRules.bed_action(crops, "carrot", 3, -1)
	check(plan["act"] == "harvest" and plan["prompt"] == "Press E to harvest the carrot", "ripe carrot is harvested by hand: no tool in the line")
	plan = FarmRules.bed_action(crops, "unknown_crop", 3, -1)
	check(plan["act"] == "harvest", "a crop this client has no data for still harvests (the server decides)")

	# The hoe's Plant list: what can be planted (seeds and dug-up bushes, once each, in order).
	var rows: Array = FarmRules.plantables(crops, ["", "stick", "hazel_bush", "wheat_seeds", "hazel_bush", "flax_seeds", "bronze_sickle"])
	check(rows.size() == 3 and rows[0] == {"id": "hazel_bush", "kind": "bush"} and rows[1] == {"id": "wheat_seeds", "kind": "seed"} and rows[2]["id"] == "flax_seeds", "plantables: hazel bush, wheat seeds, flax seeds once each in pack order; sticks and sickles are not")
	check(FarmRules.plantables(crops, ["", "stick"]).is_empty(), "plantables: nothing to plant in a pack of sticks")
	# The hoe grid (Dave 14 Nov 2026): width by length, turned by the wheel, spaced for the plant; unturned 1 m grids sit on the metre cells.
	var one: Array = FarmRules.grid_points(1, 1, 1.0, FarmRules.grid_centre(1, 1, 1.0, Vector2(3.7, -2.2), 0, Vector2(3.5, -2.5)), 0)
	check(one.size() == 1 and one[0].is_equal_approx(Vector2(3.5, -2.5)), "hoe grid: one point, moved onto the aimed metre cell's centre (%s)" % str(one))
	var even: Array = FarmRules.grid_points(2, 3, 1.0, FarmRules.grid_centre(2, 3, 1.0, Vector2(3.7, -2.2), 0, Vector2(3.5, -2.5)), 0)
	check(even.size() == 6 and even.all(func(c): return is_equal_approx(fposmod(c.x, 1.0), 0.5) and is_equal_approx(fposmod(c.y, 1.0), 0.5)) and even.any(func(c): return c.is_equal_approx(Vector2(3.5, -2.5))), "hoe grid: 2 by 3 is 6 points, every one on a cell centre, one on the aimed cell (%s)" % str(even))
	var xs: Dictionary = {}
	var zs: Dictionary = {}

	for c in even:
		xs[snappedf(c.x, 0.01)] = true
		zs[snappedf(c.y, 0.01)] = true

	check(xs.size() == 2 and zs.size() == 3, "hoe grid: width runs along x and length along z when unturned")
	var turned: Array = FarmRules.grid_points(3, 1, 1.0, Vector2.ZERO, 90)
	check(turned.any(func(c): return c.is_equal_approx(Vector2(0.0, 1.0))) and turned.any(func(c): return c.is_equal_approx(Vector2(0.0, -1.0))), "hoe grid: turned 90 degrees, a row across x lies along z (%s)" % str(turned))
	var tilt: Array = FarmRules.grid_points(2, 2, 1.0, Vector2.ZERO, 15)
	check(is_equal_approx(tilt[0].distance_to(tilt[1]), 1.0) and is_equal_approx(tilt[0].distance_to(tilt[2]), 1.0), "hoe grid: turned 15 degrees, the points stay 1 m apart")
	check(FarmRules.spacing_of("seed") == 1.0 and FarmRules.spacing_of("bush") == 2.0 and FarmRules.spacing_of("tree") == 3.0 and FarmRules.spacing_of("seed", {"spacing_m": 2.0}) == 2.0, "hoe grid: spacing by kind (1, 2, 3 m), a crop row's spacing_m wins")
	check(FarmRules.on_square(Vector2(0.6, 0.0), Vector2.ZERO, 0.55, 45.0) and not FarmRules.on_square(Vector2(0.5, 0.5), Vector2.ZERO, 0.55, 45.0) and FarmRules.on_square(Vector2(0.5, 0.5), Vector2.ZERO, 0.55, 0.0), "on_square: a bed turned 45 degrees holds its own diamond, not the unturned corner")
	# Tree seeds (a felled tree drops 1 to 5 of its own <Tree> seed); planted in open ground through the bush action, 3 m apart.
	var trees: Dictionary = {"oak_seed": "oak", "maple_keys": "maple"}
	var with_trees: Array = FarmRules.plantables(crops, ["oak_seed", "wheat_seeds", "maple_keys", "stone"], "_bush", trees)
	check(with_trees.size() == 3 and with_trees[0] == {"id": "oak_seed", "kind": "tree"} and with_trees[1]["kind"] == "seed" and with_trees[2] == {"id": "maple_keys", "kind": "tree"}, "plantables: tree seeds list as trees (%s)" % str(with_trees))
	check(FarmRules.plantables(crops, ["oak_seed"]).is_empty(), "plantables: no tree seed table, no tree rows")
	check(FarmRules.bed_side({"footprint_x": 1.0}) == 1 and FarmRules.bed_side({"footprint_x": 2.0, "footprint_z": 2.0}) == 2 and FarmRules.bed_side({"footprint_x": 3.0, "footprint_z": 3.0}) == 3 and FarmRules.bed_side({"footprint_x": 0.6}) == 1 and FarmRules.bed_side({"footprint_x": 3.0, "footprint_z": 2.0}) == 2, "bed_side: 1, 2 and 3 m beds hold 1, 2 and 3 square metres a side; a pot one")
	# Stage looks: every crop, every stage, four plants on a 1 m bed and sixteen on a 2 m plot, taller with the stage. Dave's painted crops (CropLook.PICTURE_HEIGHT_M)
	# are picture cards from the start; the rest are placeholder tufts until the wild plant's model is passed in.
	var all_built: bool = true
	var taller: bool = true
	var right_kind: bool = true

	for id in crops:
		var last_top: float = -1.0

		for stage in range(4):
			var look: Node3D = CropLook.build(str(id), stage, 1.0)
			var first: MeshInstance3D = look.get_child(0) as MeshInstance3D if look.get_child_count() > 0 else null
			var top: float = first.position.y + first.get_aabb().end.y if first != null else -1.0
			all_built = all_built and look.get_child_count() == 4
			taller = taller and top > last_top
			last_top = top
			right_kind = right_kind and bool(look.get_meta("placeholder", true)) != CropLook.PICTURE_HEIGHT_M.has(str(id))
			look.free()

	check(all_built and taller, "every crop has four stage looks of 4 plants on a bed, each taller than the last")
	check(right_kind, "the painted crops are picture cards, the others placeholder tufts when no wild model is given")
	check(crops.has("wheat") and crops.has("cabbage") and CropLook.PICTURE_HEIGHT_M.keys().all(func(k): return crops.has(k)), "every painted crop is a crop in crops.json")
	var ripe: MeshInstance3D = CropLook.build("wheat", 3, 1.0).get_child(0) as MeshInstance3D
	var young: MeshInstance3D = CropLook.build("wheat", 0, 1.0).get_child(0) as MeshInstance3D
	var cabbage: MeshInstance3D = CropLook.build("cabbage", 0, 1.0).get_child(0) as MeshInstance3D
	var ripe_tex: Texture2D = (ripe.material_override as StandardMaterial3D).albedo_texture
	check(ripe_tex != null and ripe_tex.get_height() == 512 and is_equal_approx(ripe.get_aabb().end.y, 1.0) and (young.material_override as StandardMaterial3D).albedo_texture != ripe_tex, "ripe wheat wears its 512 px picture 1 m tall; a wheat seedling the green blades")
	check((cabbage.material_override as StandardMaterial3D).albedo_texture.get_width() > 100 and (cabbage.material_override as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "a cabbage seedling is its own picture, cut out")

	for card in [ripe, young, cabbage]:
		card.get_parent().free()

	var plot: Node3D = CropLook.build("wheat", 3, 2.0)
	check(plot.get_child_count() == 16, "a 2 m garden plot gets 16 plants")
	plot.free()
	print("farm prompt: %d failures" % failures)
	quit(1 if failures > 0 else 0)
