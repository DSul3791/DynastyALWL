extends SceneTree

# Fishing balance (plan 5b): a new player hauling the shore net at one spot for hours, with the real server rules. Targets (Tyler): first hour at most 26,
# a steady hour 8 to 20 inside a school, outside every school above 1 and under 8 (midday). Prints the numbers so the data can be retuned.
#   godot --headless --path . --script res://src/worldgen/tools/test_fish_balance.gd      Prints "Test done: N pass, N fail".

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var passes: int = 0
var failures: int = 0
var said: Array = []


# Stands in for the school module: one fixed factor everywhere.
class StubSchools:
	extends RefCounted
	var factor: float = 1.0

	func factor_at(_x: float, _z: float, _day: int, _season: String, _now_s: float, _stock: Callable, _memo: Dictionary = {}) -> Dictionary:
		return {"factor": factor, "species": "", "active": true}


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func fish_count(items) -> int:
	var n: int = 0

	for fish in ["trout", "perch", "carp", "pike"]:
		n += items.inventory_of(1).count_of(items.table.number_of(fish))

	return n


# Hours of netting at one spot: returns the fish caught in each hour.
func run(hour_of_day: float, factor: float, hours: int, key: String) -> Array:
	var dir: String = "user://test_fish_balance_" + key
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var clock: Array = [1.0e9]
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.unix_now = func(): return clock[0]
	items.game_seconds = func(): return hour_of_day * 3600.0
	items.ground_height = func(_x, _z): return 10.0
	items.water_near = func(_p, _r): return true
	items.water_depth_at = func(_p): return 0.6
	items.water_kind_at = func(_x, _z): return {"kind": "lake", "depth": 0.6}
	items.setup(ItemTableScript.load_default(), dir)
	items._fate_rng.seed = 424242      # the same hours every run
	var stub = StubSchools.new()
	stub.factor = factor
	items._schools = stub
	items.peer_connected_hello(1, "bal-key-0000001")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	var net_no: int = items.table.number_of("shore_net")
	items.action(1, Net.ACT_ADMIN_GIVE, net_no, 0, 40, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(net_no)
	var water: Vector3 = Vector3(8.0, 9.5, 5.0)
	var per_hour: Array = []
	var haul_s: float = float(items._fishing_data()["net"]["hold_s"]) + float(items._fishing_data()["cooldown_s"])

	for _hour in hours:
		var before: int = fish_count(items)
		var spent: float = 0.0

		while spent < 3600.0:
			clock[0] += haul_s
			spent += haul_s
			items._last_fish.clear()
			items.action(1, Net.ACT_NET, slot, 0, 0, water)

			if items._fishing.has(1):
				items._fishing[1]["at"] = Time.get_ticks_msec() - 1
				items._fish_tick()

			if items.inventory_of(1).numbers[slot] != net_no:      # a worn-out net: a new one from the admin bag
				items.action(1, Net.ACT_ADMIN_GIVE, net_no, 0, 1, Vector3.ZERO)
				slot = items.inventory_of(1).numbers.find(net_no)

		per_hour.append(fish_count(items) - before)

	return per_hour


func _init() -> void:
	var midday: Array = run(12.0, 1.0, 3, "in_noon")
	var dawn: Array = run(6.0, 1.0, 3, "in_dawn")
	var dusk: Array = run(18.0, 1.0, 3, "in_dusk")
	var far_factor: float = float(JSON.parse_string(FileAccess.get_file_as_string("res://data/items/fish_schools.json"))["factor"]["far"])
	var out_noon: Array = run(12.0, far_factor, 4, "out_noon")
	var out_dawn: Array = run(6.0, far_factor, 2, "out_dawn")
	print("fish per hour, net, inside a school: midday %s dawn %s dusk %s" % [str(midday), str(dawn), str(dusk)])
	print("fish per hour, net, outside every school (factor %.2f): midday %s dawn %s" % [far_factor, str(out_noon), str(out_dawn)])

	for series in [midday, dawn, dusk]:
		check(int(series[0]) <= 26, "first hour inside a school: at most 26 (%d)" % int(series[0]))

		for h in range(1, series.size()):
			check(int(series[h]) >= 8 and int(series[h]) <= 20, "steady hour inside a school: 8 to 20 (%d)" % int(series[h]))

	var out_sum: int = 0

	for h in out_noon.size():
		out_sum += int(out_noon[h])

	var out_avg: float = float(out_sum) / float(out_noon.size())
	check(out_avg > 1.0 and out_avg < 8.0, "outside every school at midday: above 1 and under 8 an hour on average (%.1f)" % out_avg)

	check(int(out_dawn[1]) > 1, "outside every school at dawn: still above 1 (%d)" % int(out_dawn[1]))
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
