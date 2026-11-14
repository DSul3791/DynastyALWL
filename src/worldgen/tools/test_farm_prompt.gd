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
	check(FarmRules.garden_action("seed", "wheat seeds", true, "")["act"] == "sow", "garden: seeds on an empty bed sow it")
	check(FarmRules.garden_action("seed", "wheat seeds", true, "flax")["act"] == "none", "garden: seeds on a growing bed do nothing and say so")
	plan = FarmRules.garden_action("seed", "wheat seeds", false, "")
	check(plan["act"] == "till" and str(plan["say"]).contains("click it again"), "garden: seeds on open ground till a bed first")
	check(FarmRules.garden_action("bush", "hazel bush", false, "")["act"] == "plant_bush", "garden: a bush on open ground is planted")
	check(FarmRules.garden_action("bush", "hazel bush", true, "")["act"] == "none", "garden: a bush is not planted in a bed")
	check(FarmRules.garden_action("", "", false, "")["act"] == "none", "garden: nothing picked sends nothing")

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
