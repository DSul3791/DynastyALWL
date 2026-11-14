extends SceneTree

# The client half of farming (GOALS-REPAIR WP-R1B): what E on a tilled bed says and asks for (FarmRules.bed_action, held by inventory_view._bed_interaction), which seed sows which crop, and
# that every crop in crops.json has a placeholder stage look (CropLook), and the hoe's Garden list and click (FarmRules.plantables, garden_action). The server's own checks are in test_farming.gd.
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

	# An empty bed: sow what is held or carried (the request carries that seed's pack slot as b), else say what the bed wants.
	var plan: Dictionary = FarmRules.bed_action(crops, "", -1, 7, "wheat seeds", -1)
	check(plan["act"] == "sow" and plan["b"] == 7 and plan["prompt"] == "Press E to sow wheat seeds", "an empty bed with seeds in pack slot 7: 'Press E to sow wheat seeds' sends a sow with b = 7")
	plan = FarmRules.bed_action(crops, "", -1, 0, "flax seeds", 4)
	check(plan["act"] == "sow" and plan["b"] == 0, "seeds in slot 0 sow with b = 0, even with a filled container in hand")
	plan = FarmRules.bed_action(crops, "", -1, -1, "", 4)
	check(plan["act"] == "none" and str(plan["prompt"]).contains("seeds"), "an empty bed without seeds asks for seeds and sends nothing (even with water in hand)")

	# A crop short of ripe: water with the filled container in hand (b = its slot), else say so; never harvest, never sow a full bed.
	for stage in range(3):
		plan = FarmRules.bed_action(crops, "flax", stage, 7, "wheat seeds", 4)
		check(plan["act"] == "water" and plan["b"] == 4 and plan["prompt"] == "Press E to water the flax (%s)" % FarmRules.STAGE_NAMES[stage], "flax at stage %d with a filled container in slot 4: water it, b = 4" % stage)
		plan = FarmRules.bed_action(crops, "flax", stage, 7, "wheat seeds", -1)
		check(plan["act"] == "none" and str(plan["prompt"]).begins_with("Flax, %s" % FarmRules.STAGE_NAMES[stage]), "flax at stage %d with no water in hand: says its stage, sends nothing" % stage)

	# Ripe: harvest (b unused), and say a sickle gives the full yield only where the crop needs one.
	plan = FarmRules.bed_action(crops, "flax", 3, -1, "", 4)
	check(plan["act"] == "harvest" and plan["b"] == 0 and plan["prompt"] == "Press E to harvest the flax (a sickle gives the full yield)", "ripe flax harvests, even with water in hand, and names the sickle")
	plan = FarmRules.bed_action(crops, "carrot", 3, -1, "", -1)
	check(plan["act"] == "harvest" and plan["prompt"] == "Press E to harvest the carrot", "ripe carrot is harvested by hand: no tool in the line")
	plan = FarmRules.bed_action(crops, "unknown_crop", 3, -1, "", -1)
	check(plan["act"] == "harvest", "a crop this client has no data for still harvests (the server decides)")

	# The hoe's Garden mode: what the pack can plant (seeds and dug-up bushes, once each, in pack order) and what one click does.
	var rows: Array = FarmRules.plantables(crops, ["", "stick", "hazel_bush", "wheat_seeds", "hazel_bush", "flax_seeds", "bronze_sickle"])
	check(rows.size() == 3 and rows[0] == {"id": "hazel_bush", "kind": "bush"} and rows[1] == {"id": "wheat_seeds", "kind": "seed"} and rows[2]["id"] == "flax_seeds", "plantables: hazel bush, wheat seeds, flax seeds once each in pack order; sticks and sickles are not")
	check(FarmRules.plantables(crops, ["", "stick"]).is_empty(), "plantables: nothing to plant in a pack of sticks")
	check(FarmRules.garden_action("seed", true, "")["act"] == "sow", "garden: seeds on an empty bed sow it")
	check(FarmRules.garden_action("seed", true, "flax")["act"] == "none", "garden: seeds on a growing bed do nothing and say so")
	plan = FarmRules.garden_action("seed", false, "")
	check(plan["act"] == "till" and str(plan["say"]) == "", "garden: seeds on open ground till a bed (and are sown when it is there)")
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
	check(FarmRules.nearest_first([Vector2(5, 0), Vector2(1, 0), Vector2(3, 0)], Vector2.ZERO)[0] == Vector2(1, 0), "hoe grid: nearest the aim first")
	check(FarmRules.on_square(Vector2(0.6, 0.0), Vector2.ZERO, 0.55, 45.0) and not FarmRules.on_square(Vector2(0.5, 0.5), Vector2.ZERO, 0.55, 45.0) and FarmRules.on_square(Vector2(0.5, 0.5), Vector2.ZERO, 0.55, 0.0), "on_square: a bed turned 45 degrees holds its own diamond, not the unturned corner")
	check(FarmRules.level_ok([10.0, 10.5, 9.4]) and not FarmRules.level_ok([10.0, 10.0, 12.5]) and not FarmRules.level_ok([]) and not FarmRules.level_ok([10.0, NAN]), "garden level test: within 1 m of the average tills, more than 1 m does not (Dave: up or down 1 m)")
	check(FarmRules.garden_action("till", false, "")["act"] == "till" and FarmRules.garden_action("till", true, "")["act"] == "none", "till a garden: open ground tills, a bed already there is shown red")
	check(FarmRules.garden_action("bush", false, "")["act"] == "plant_bush", "garden: a bush on open ground is planted")
	check(FarmRules.garden_action("bush", true, "")["act"] == "none", "garden: a bush is not planted in a bed")
	check(FarmRules.garden_action("", false, "")["act"] == "none", "garden: nothing picked sends nothing")
	# Tree seeds (a felled tree drops 1 to 5 of its own <Tree> seed); planted in open ground through the bush action, 3 m apart.
	var trees: Dictionary = {"oak_seed": "oak", "maple_keys": "maple"}
	var with_trees: Array = FarmRules.plantables(crops, ["oak_seed", "wheat_seeds", "maple_keys", "stone"], "_bush", trees)
	check(with_trees.size() == 3 and with_trees[0] == {"id": "oak_seed", "kind": "tree"} and with_trees[1]["kind"] == "seed" and with_trees[2] == {"id": "maple_keys", "kind": "tree"}, "plantables: tree seeds list as trees (%s)" % str(with_trees))
	check(FarmRules.plantables(crops, ["oak_seed"]).is_empty(), "plantables: no tree seed table, no tree rows")
	check(FarmRules.garden_action("tree", false, "")["act"] == "plant_bush" and FarmRules.garden_action("tree", true, "")["act"] == "none", "garden: a tree seed goes in open ground, not a bed")
	# A click's plan: a 2 m plot holding several 1 m points takes one seed (its first point); no ground and the pack's count stop the rest; a far point plants
	# when the player walks over (it is queued, marked far).
	var spots: Array = [[Vector3(0.5, 1.0, 0.5), 7, ""], [Vector3(1.5, 1.0, 0.5), 7, ""], [Vector3(0.5, 1.0, 1.5), 0, ""], [Vector3(1.5, NAN, 1.5), 0, ""], [Vector3(9.5, 1.0, 0.5), 0, ""], [Vector3(-0.5, 1.0, 0.5), 8, "flax"], [Vector3(2.5, 1.0, 0.5), 0, ""]]
	var made: Array = FarmRules.garden_plan("seed", spots, Vector3.ZERO, 3.7, 3)
	check(made.size() == 5 and made[0]["act"] == "sow" and int(made[0]["bed"]) == 7 and made.filter(func(c): return int(c["bed"]) == 7).size() == 1, "garden plan: the plot is sown once, from its first point (%s)" % str(made))
	check(made[1]["act"] == "till" and made[2]["act"] == "none" and str(made[2]["say"]) == "No ground to plant there" and made[3]["act"] == "till" and bool(made[3]["far"]) and not bool(made[1]["far"]), "garden plan: open ground tills; no ground says why; a far point is planted later")
	check(made[4]["act"] == "none" and int(made[4]["bed"]) == 8, "garden plan: a growing bed is shown, not sown")
	check(made.filter(func(c): return bool(c["ok"])).size() == 3, "garden plan: three seeds in the pack plant three points and the plan stops at the fourth")
	# A plot of several square metres: each square metre ("bed:cell") is sown once, two grid points on one square metre count once.
	var cell_spots: Array = [[Vector3(0.4, 1.0, 0.4), 7, "", "7:0"], [Vector3(0.6, 1.0, 0.6), 7, "", "7:0"], [Vector3(1.5, 1.0, 0.5), 7, "", "7:1"], [Vector3(1.5, 1.0, 1.5), 7, "wheat", "7:3"]]
	var by_cell: Array = FarmRules.garden_plan("seed", cell_spots, Vector3.ZERO, 3.7, 9)
	check(by_cell.size() == 3 and by_cell[0]["act"] == "sow" and by_cell[1]["act"] == "sow" and by_cell[2]["act"] == "none", "garden plan: a plot's square metres are sown one each, a growing one is left (%s)" % str(by_cell))
	check(FarmRules.bed_side({"footprint_x": 1.0}) == 1 and FarmRules.bed_side({"footprint_x": 2.0, "footprint_z": 2.0}) == 2 and FarmRules.bed_side({"footprint_x": 3.0, "footprint_z": 3.0}) == 3 and FarmRules.bed_side({"footprint_x": 0.6}) == 1 and FarmRules.bed_side({"footprint_x": 3.0, "footprint_z": 2.0}) == 2, "bed_side: 1, 2 and 3 m beds hold 1, 2 and 3 square metres a side; a pot one")
	# The queue: a till goes out and holds the next till 600 ms; its own sow waits for the bed up to 3 s (others go first meanwhile), then is dropped; a bed that
	# shows is sown once; a point out of reach waits until the player is near.
	var queue: Array = [{"act": "till", "pos": Vector3(0.5, 1.0, 0.5)}, {"act": "sow_at", "pos": Vector3(0.5, 1.0, 0.5), "until": 0}, {"act": "sow", "bed": 4, "pos": Vector3.ZERO}]
	var bed_there: Array = [0, ""]   # changed in place below: a lambda keeps the array it captured
	var bed_at := func(_pos: Vector3) -> Array:
		return bed_there.duplicate()

	var step: Dictionary = FarmRules.garden_step(queue, 1000, bed_at)
	check(step["send"]["act"] == "till" and int(step["next"]) == 1000 + FarmRules.GARDEN_TILL_MSEC and queue.size() == 2 and int(queue[0]["until"]) == 1000 + FarmRules.GARDEN_BED_WAIT_MSEC, "garden queue: the till goes, the next move waits 600 ms, its sow starts waiting 3 s")
	step = FarmRules.garden_step(queue, 1600, bed_at)
	check(step["send"]["act"] == "sow" and int(step["send"]["bed"]) == 4 and queue.size() == 1 and queue[0]["act"] == "sow_at" and int(step["next"]) == 1600 + FarmRules.GARDEN_STEP_MSEC, "garden queue: while a sow waits for its bed, the one behind it goes, 150 ms apart")
	step = FarmRules.garden_step(queue, 1750, bed_at)
	check(step["send"].is_empty() and queue.size() == 1, "garden queue: nothing goes while the bed is not there yet")
	bed_there[0] = 12
	var waiting: Array = queue.duplicate(true)
	step = FarmRules.garden_step(queue, 1900, bed_at)
	check(step["send"]["act"] == "sow" and int(step["send"]["bed"]) == 12 and queue.is_empty(), "garden queue: once the bed shows, the waiting sow sows it")
	bed_there[0] = 0
	step = FarmRules.garden_step(waiting, 4001, bed_at)
	check(step["send"].is_empty() and waiting.is_empty(), "garden queue: a bed that never shows is given up after 3 s")
	bed_there[0] = 12
	bed_there[1] = "wheat"
	waiting = [{"act": "sow_at", "pos": Vector3.ZERO, "until": 5000}]
	step = FarmRules.garden_step(waiting, 4000, bed_at)
	check(step["send"].is_empty() and waiting.is_empty(), "garden queue: a bed already sown is not sown again")
	var walk: Array = [{"act": "plant_bush", "pos": Vector3(9.0, 0.0, 0.0)}, {"act": "plant_bush", "pos": Vector3(1.0, 0.0, 0.0)}]
	var near_origin := func(pos: Vector3) -> bool:
		return pos.length() <= 3.7

	step = FarmRules.garden_step(walk, 5000, bed_at, near_origin)
	check(step["send"]["pos"] == Vector3(1.0, 0.0, 0.0) and walk.size() == 1, "garden queue: the point in reach goes first")
	step = FarmRules.garden_step(walk, 5200, bed_at, near_origin)
	check(step["send"].is_empty() and walk.size() == 1, "garden queue: a point out of reach waits for the player")

	# Placeholder looks: every crop, every stage, a tuft grid for a 1 m bed and a 2 m plot, taller with the stage.
	var all_built: bool = true
	var taller: bool = true

	for id in crops:
		var last_top: float = -1.0

		for stage in range(4):
			var look: Node3D = CropLook.build(str(id), stage, 1.0)
			var top: float = (look.get_child(0) as MeshInstance3D).position.y if look.get_child_count() > 0 else -1.0
			all_built = all_built and look.get_child_count() == 4
			taller = taller and top > last_top
			last_top = top
			look.free()

	check(all_built and taller, "every crop has four stage looks of 4 tufts on a bed, each taller than the last")
	var plot: Node3D = CropLook.build("wheat", 3, 2.0)
	check(plot.get_child_count() == 16, "a 2 m garden plot gets 16 tufts")
	plot.free()
	print("farm prompt: %d failures" % failures)
	quit(1 if failures > 0 else 0)
