extends SceneTree

# Saved building plans (src/client/building_plans.gd and the hammer menu rows in hammer_blueprints.gd): a structure is captured whole, kept
# relative to its lowest piece, turns and moves when placed again, costs the sum of its pieces and survives a save and load.
#   godot --headless --path . --script res://src/worldgen/tools/test_building_plans.gd

const Plans := preload("res://src/client/building_plans.gd")
const ListScript := preload("res://src/client/hammer_blueprints.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.05


func _init() -> void:
	var rows: Array = [
		{"pos": Vector3(100.0, 10.3, 104.0), "state": 50, "yaw": 90.0, "piece": true},   # a log wall, a step above the floor
		{"pos": Vector3(100.0, 10.0, 100.0), "state": 51, "yaw": 90.0, "piece": true},   # a log floor: the lowest, so the anchor
		{"pos": Vector3(300.0, 10.0, 300.0), "state": 50, "yaw": 0.0, "piece": true},    # another house far away: not part of it
		{"pos": Vector3(102.0, 10.0, 102.0), "state": 22, "yaw": 0.0, "piece": true},    # a kit wall beside it: no blueprint, counted as skipped
	]
	var states: Dictionary = {50: 16, 51: 17}
	check(Plans.capture(rows, states, Vector3(0.0, 0.0, 0.0)).is_empty(), "nothing placeable near the aim saves nothing")
	var found: Dictionary = Plans.capture(rows, states, Vector3(100.0, 10.0, 101.0))
	check(not found.is_empty() and found["plan"]["pieces"].size() == 2, "the floor and the wall joined to it are captured, the far house is not")
	check(int(found["skipped"]) == 1, "the kit wall beside it is reported as left out (%s)" % str(found.get("skipped")))
	var plan: Dictionary = found["plan"]
	check(int(plan["pieces"][0]["bp"]) == 17 and float(plan["pieces"][0]["dy"]) == 0.0, "the lowest piece is the anchor and comes first")
	var back: Array = Plans.placements(plan, Vector3(100.0, 10.0, 100.0), 90.0)
	check(near(back[1]["pos"], Vector3(100.0, 10.3, 104.0)) and int(back[1]["yaw"]) == 90 and int(back[0]["yaw"]) == 90, "placed where it stood, it lands where it stood")
	var moved: Array = Plans.placements(plan, Vector3(50.0, 20.0, 60.0), 180.0)
	check(near(moved[1]["pos"], Vector3(54.0, 20.3, 60.0)) and int(moved[1]["yaw"]) == 180, "set down turned half way round from yaw 90, the wall that was 4 m one way is 4 m the other (%s)" % str(moved[1]["pos"]))

	var table = ItemTableScript.load_default()
	var pack = InventoryScript.new(table)
	var path: String = "user://test_building_plans_tmp.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var list = ListScript.new()
	list.setup(table, pack, null, path)
	var saved: Dictionary = list.save_plan_near(rows, Vector3(100.0, 10.0, 101.0))
	check(bool(saved["ok"]) and saved["name"] == "Plan 1" and int(saved["pieces"]) == 2, "the menu saves a plan as Plan 1")
	check(not bool(list.save_plan_near(rows, Vector3(0.0, 0.0, 0.0))["ok"]), "saving with nothing near says no")
	var entries: Array = list.entries(1)
	check(entries[0]["kind"] == "repair" and entries[1]["kind"] == "save" and entries[entries.size() - 1]["kind"] == "plan", "the menu has Repair, Save building plan, the blueprints, then the plan last")
	check(not list.can_afford(1) and not bool(entries[entries.size() - 1]["can"]), "an empty pack cannot afford the plan")

	var again = ListScript.new()
	again.setup(table, pack, null, path)
	check(again.plans.plans.size() == 1 and again.plans.plans[0]["pieces"].size() == 2, "the plan is still there after a save and load")

	again.set_open(true, 1)
	again.move(false, 1)   # up from the first row wraps to the last: the plan
	again.choose(1)
	check(again.plan_picked == 0 and again.picked == 17 and again.mode == "place", "choosing the plan picks it and its anchor blueprint")

	var cost: Dictionary = again.plan_cost(again.plans.plans[0])

	for id in cost:
		pack.add(table.number_of(str(id)), int(cost[id]))

	check(again.can_afford(1), "with every piece's materials the plan is affordable")
	again.set_open(true, 1)
	again.choose(1)   # the highlight starts on the picked plan, so this keeps it
	check(again.plan_picked == 0, "the highlight starts on the picked plan")
	again.set_open(true, 1)
	again.move(true, 1)   # wraps to the first row: Repair
	again.move(true, 1)   # then Save building plan
	again.choose(1)
	check(again.mode == "save" and again.picked == 0 and again.plan_picked == -1, "Save building plan switches the hammer to saving")
	check(again.delete_highlighted(1) == "", "Delete on Save building plan removes nothing")
	again.set_open(true, 1)
	again.move(false, 1)
	check(again.delete_highlighted(1) == "Plan 1" and again.plans.plans.is_empty(), "Delete on a plan removes it")
	again.clear()
	check(again.mode == "place", "putting the hammer away clears saving")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("test_building_plans: %d fail" % failures)
	quit(1 if failures > 0 else 0)
