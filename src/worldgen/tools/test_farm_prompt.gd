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
	# Rows and grids: one cell, a row of 5 along the way the player faces, 3 by 3 and 5 by 5 on the 1 m cells for seeds; bushes 2 m apart; nearest the aim first.
	var one: Array = FarmRules.garden_cells(0, "seed", Vector3(3.7, 10.0, -2.2), Vector3(1.0, 0.0, 0.0))
	check(one == [Vector2(3.5, -2.5)], "garden cells: one seed cell, the aimed 1 m cell's centre (%s)" % str(one))
	var row: Array = FarmRules.garden_cells(1, "seed", Vector3(3.7, 10.0, -2.2), Vector3(0.9, 0.0, 0.2))
	check(row.size() == 5 and row[0] == Vector2(3.5, -2.5) and row.all(func(c): return is_equal_approx(c.y, -2.5)) and row.any(func(c): return is_equal_approx(c.x, 5.5)) and row.any(func(c): return is_equal_approx(c.x, 1.5)), "garden cells: a row of 5 runs along x when facing x (%s)" % str(row))
	row = FarmRules.garden_cells(1, "seed", Vector3(3.7, 10.0, -2.2), Vector3(0.1, 0.0, -1.0))
	check(row.all(func(c): return is_equal_approx(c.x, 3.5)), "garden cells: and along z when facing z")
	check(FarmRules.garden_cells(2, "seed", Vector3.ZERO, Vector3.FORWARD).size() == 9 and FarmRules.garden_cells(3, "seed", Vector3.ZERO, Vector3.FORWARD).size() == 25, "garden cells: 3 by 3 is 9 cells, 5 by 5 is 25")
	var bushes: Array = FarmRules.garden_cells(2, "bush", Vector3(0.3, 0.0, 0.3), Vector3.FORWARD)
	check(bushes[0] == Vector2(0.3, 0.3) and bushes.any(func(c): return c.is_equal_approx(Vector2(2.3, 2.3))), "garden cells: bushes round the aim itself, 2 m apart")
	check(FarmRules.garden_action("bush", false, "")["act"] == "plant_bush", "garden: a bush on open ground is planted")
	check(FarmRules.garden_action("bush", true, "")["act"] == "none", "garden: a bush is not planted in a bed")
	check(FarmRules.garden_action("", false, "")["act"] == "none", "garden: nothing picked sends nothing")
	# Tree seeds (a felled tree drops 1 to 5 of its own <Tree> seed); planted in open ground through the bush action, 3 m apart.
	var trees: Dictionary = {"oak_seed": "oak", "maple_keys": "maple"}
	var with_trees: Array = FarmRules.plantables(crops, ["oak_seed", "wheat_seeds", "maple_keys", "stone"], "_bush", trees)
	check(with_trees.size() == 3 and with_trees[0] == {"id": "oak_seed", "kind": "tree"} and with_trees[1]["kind"] == "seed" and with_trees[2] == {"id": "maple_keys", "kind": "tree"}, "plantables: tree seeds list as trees (%s)" % str(with_trees))
	check(FarmRules.plantables(crops, ["oak_seed"]).is_empty(), "plantables: no tree seed table, no tree rows")
	check(FarmRules.garden_action("tree", false, "")["act"] == "plant_bush" and FarmRules.garden_action("tree", true, "")["act"] == "none", "garden: a tree seed goes in open ground, not a bed")
	var tree_cells: Array = FarmRules.garden_cells(1, "tree", Vector3(0.3, 0.0, 0.3), Vector3(1.0, 0.0, 0.0))
	check(tree_cells[0] == Vector2(0.3, 0.3) and tree_cells.any(func(c): return c.is_equal_approx(Vector2(6.3, 0.3))), "garden cells: a row of tree seeds 3 m apart round the aim (%s)" % str(tree_cells))
	# A click's plan: a 2 m plot holding several 1 m cells takes one seed (its first cell); reach from the feet, no ground, and the pack's count stop the rest.
	var spots: Array = [[Vector3(0.5, 1.0, 0.5), 7, ""], [Vector3(1.5, 1.0, 0.5), 7, ""], [Vector3(0.5, 1.0, 1.5), 0, ""], [Vector3(1.5, NAN, 1.5), 0, ""], [Vector3(9.5, 1.0, 0.5), 0, ""], [Vector3(-0.5, 1.0, 0.5), 8, "flax"], [Vector3(2.5, 1.0, 0.5), 0, ""]]
	var made: Array = FarmRules.garden_plan("seed", spots, Vector3.ZERO, 3.7, 2)
	check(made.size() == 5 and made[0]["act"] == "sow" and int(made[0]["bed"]) == 7 and made.filter(func(c): return int(c["bed"]) == 7).size() == 1, "garden plan: the plot is sown once, from its first cell (%s)" % str(made))
	check(made[1]["act"] == "till" and made[2]["act"] == "none" and str(made[2]["say"]) == "No ground to plant there" and made[3]["act"] == "none" and str(made[3]["say"]).begins_with("Too far"), "garden plan: open ground tills; no ground and out of reach say why")
	check(made[4]["act"] == "none" and int(made[4]["bed"]) == 8, "garden plan: a growing bed is shown, not sown")
	check(made.filter(func(c): return bool(c["ok"])).size() == 2, "garden plan: two seeds in the pack plant two cells and the plan stops at the third")
	# The queue: a till goes out and holds the next till 600 ms; its sow waits for the bed (moving to the back) up to 3 s, then is dropped; a bed that shows is sown once.
	var queue: Array = [{"act": "till", "pos": Vector3(0.5, 1.0, 0.5)}, {"act": "sow_at", "pos": Vector3(0.5, 1.0, 0.5), "until": 0}, {"act": "sow", "bed": 4, "pos": Vector3.ZERO}]
	var bed_there: Array = [0, ""]   # changed in place below: a lambda keeps the array it captured
	var bed_at := func(_pos: Vector3) -> Array:
		return bed_there.duplicate()

	var step: Dictionary = FarmRules.garden_step(queue, 1000, bed_at)
	check(step["send"]["act"] == "till" and int(step["next"]) == 1000 + FarmRules.GARDEN_TILL_MSEC and queue.size() == 2 and int(queue[0]["until"]) == 1000 + FarmRules.GARDEN_BED_WAIT_MSEC, "garden queue: the till goes, the next move waits 600 ms, its sow starts waiting 3 s")
	step = FarmRules.garden_step(queue, 1600, bed_at)
	check(step["send"].is_empty() and queue[0]["act"] == "sow" and queue[1]["act"] == "sow_at", "garden queue: a sow whose bed is not there yet goes to the back")
	step = FarmRules.garden_step(queue, 1750, bed_at)
	check(step["send"]["act"] == "sow" and int(step["send"]["bed"]) == 4 and queue.size() == 1 and int(step["next"]) == 1750 + FarmRules.GARDEN_STEP_MSEC, "garden queue: a queued sow goes out, 150 ms apart")
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
