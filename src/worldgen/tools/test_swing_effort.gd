extends SceneTree

# BUGLIST-001 (Dave's playtest report), swings and effort:
# BUG-001: every swing that is really made costs effort once, a miss as much as a hit; a swing blocked by the cooldown is not a swing.
# BUG-003: an axe right-clicked away from water says nothing about ice; at the water, off the ice, it says so; on the ice it cuts.
# BUG-005: a walk recovers strain slowly, standing faster; a jog and a sprint build it; strenuous work to a walk to standing falls in steps.
#   godot --headless --path . --script res://src/worldgen/tools/test_swing_effort.gd

const HeldItem := preload("res://src/client/held_item.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []
var rock: bool = false
var near_water: bool = false
var ice: float = 0.0
var animal_hit: bool = false
var standing: Dictionary = {7: true}


class FakeAction:
	extends RefCounted
	var calls: Array = []

	func rpc_id(_peer: int, kind: int, a: int, b: int, count: int, at: Vector3) -> void:
		calls.append([kind, a, b, count, at])


class FakeNet:
	extends RefCounted
	var inventory_action: FakeAction = FakeAction.new()


class FakeInventory:
	extends RefCounted
	var numbers: Array = []
	var counts: Array = []


class FakeView:
	extends Node
	var table
	var inventory = FakeInventory.new()

	func refresh_hotbar() -> void:
		pass

	func _on_notice(_text: String) -> void:
		pass

	func text_px(size: int) -> int:
		return size

	func fire_light_near(_point: Vector3, _radius: float) -> bool:
		return false

	func edible_slot(_slot: int) -> bool:
		return false

	func is_broken(_slot: int) -> bool:
		return false

	func key_slot(key: int) -> int:
		return key if key >= 0 and key < 10 and int(inventory.numbers[key]) != 0 else -1


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	run.call_deferred()


func run() -> void:
	_server()
	await _client()
	print("swing effort tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _make(tag: String):
	var dir: String = "user://test_swing_effort_%s_%d" % [tag, Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(dir)
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	w.send_notice = func(_p, text): said.append(str(text))
	w.setup(ItemTableScript.load_default(), dir)
	w.ground_height = func(_x, _z): return 10.0
	w.game_seconds = func(): return 5000.0
	w.rock_at = func(_x, _z): return rock
	w.hit_animal = func(_p, _from, _dir, _reach, _dmg): return animal_hit
	w.water_near = func(_pos, _reach): return near_water
	w.ice_cover_at = func(_pos): return ice
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(1.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(0.0, 10.0, 0.0))
	return w


# What one swing leaves: the effort it holds and for how long (data/items/exertion.json tool_effort, work_s). Cleared before each swing.
func _cost(w) -> Array:
	return [float(w._work_level.get(1, 0.0)), int(w._work_until.get(1, 0)) - Time.get_ticks_msec()]


func _server() -> void:
	var w = _make("a")
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	var inv = w.inventory_of(1)
	var slot: int = HeldTool.slot_of(w, "axe")
	var axe_effort: float = float(w._exertion_cfg["tool_effort"]["axe"])
	var ground: Vector3 = Vector3(2.0, 10.0, 0.0)
	var air: Vector3 = Vector3(0.0, 11.6, -2.5)   # eye height, 2.5 m ahead: what the client sends for a swing at nothing
	check(slot >= 0, "an axe is in the hotbar")

	# BUG-001: a hit on bare rock, a swing at soil and a swing into the air each cost the same, once.
	var costs: Dictionary = {}
	var wears: Dictionary = {}

	for kind in ["rock", "soil", "air"]:
		rock = kind == "rock"
		w._work_until.clear()
		w._work_level.clear()
		w._last_mine.clear()
		var wear_before: int = int(inv.wear[slot])
		w.action(1, Net.ACT_MINE, slot + 1, 0, 0, air if kind == "air" else ground)
		costs[kind] = _cost(w)
		wears[kind] = int(inv.wear[slot]) - wear_before

	check(is_equal_approx(float(costs["rock"][0]), axe_effort) and costs["rock"][1] > 2000, "a hit on rock holds the axe's effort (%s)" % str(costs["rock"]))
	check(is_equal_approx(float(costs["soil"][0]), float(costs["rock"][0])) and absi(int(costs["soil"][1]) - int(costs["rock"][1])) < 200, "a swing at soil costs what the hit does, a miss as much as a hit (%s)" % str(costs["soil"]))
	check(is_equal_approx(float(costs["air"][0]), float(costs["rock"][0])) and absi(int(costs["air"][1]) - int(costs["rock"][1])) < 200, "a swing into the air costs what the hit does (%s)" % str(costs["air"]))
	check(int(wears["rock"]) > 0 and int(wears["soil"]) == 0 and int(wears["air"]) == 0, "only the stone struck wears the axe (%s)" % str(wears))
	rock = false
	w._work_until.clear()
	w._work_level.clear()
	w._last_mine.clear()
	w.action(1, Net.ACT_MINE, slot + 1, 0, 0, air)
	check(w.effort_of(1) >= 1.0, "after one swing into the air the body works as hard as running (%.2f)" % w.effort_of(1))

	# A swing inside the cooldown is not a swing: it holds nothing new.
	w._work_until.clear()
	w.action(1, Net.ACT_MINE, slot + 1, 0, 0, air)
	check(not w._work_until.has(1), "a second click inside the swing's cooldown costs nothing")
	# Nothing in hand, or a tool that is not a pick or axe: no swing, no effort.
	w._last_mine.clear()
	w.action(1, Net.ACT_MINE, 0, 0, 0, air)
	check(not w._work_until.has(1), "nothing in hand: no swing, no effort")

	# Wood: a blow on a standing tree charges once and says nothing about ice.
	said.clear()
	w._work_until.clear()
	w._work_level.clear()
	w._last_hit.clear()
	w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))
	check(is_equal_approx(float(_cost(w)[0]), axe_effort) and _cost(w)[1] > 2000, "a blow on a tree holds the same effort (%s)" % str(_cost(w)))
	check(said.filter(func(t): return t.to_lower().contains("ice")).is_empty(), "a wood hit says nothing about ice (%s)" % str(said))

	# A weapon: a jab that misses tires as much as one that lands.
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("wooden_spear"), 0, 1, Vector3.ZERO)
	var spear: int = -1

	for s in range(inv.slot_count):
		if inv.numbers[s] == w.table.number_of("wooden_spear"):
			spear = s

	check(spear >= 0, "a spear is in the pack")
	var jabs: Dictionary = {}

	for landed in [true, false]:
		animal_hit = landed
		w._work_until.clear()
		w._work_level.clear()
		w._last_strike.clear()
		w.action(1, Net.ACT_STRIKE, spear, 0, 0, Vector3(0.0, 0.0, -1.0))
		jabs[landed] = _cost(w)

	check(float(jabs[false][0]) > 0.0 and is_equal_approx(float(jabs[true][0]), float(jabs[false][0])) and absi(int(jabs[true][1]) - int(jabs[false][1])) < 200, "a spear jab that misses costs what one that lands does (%s)" % str(jabs))
	animal_hit = false

	# BUG-003: the right click with an axe.
	said.clear()
	near_water = false
	ice = 0.0
	w._hole_blows.clear()
	w.action(1, Net.ACT_ICEHOLE, slot, 0, 0, Vector3.ZERO)
	check(said.is_empty(), "an axe right-clicked away from any water says nothing (%s)" % str(said))
	near_water = true
	w.action(1, Net.ACT_ICEHOLE, slot, 0, 0, Vector3.ZERO)
	check(said.size() == 1 and said[0] == str(w._fishing_data()["ice"]["say_no_ice"]), "at the water, off the ice, it says there is no ice to cut (%s)" % str(said))
	said.clear()
	ice = 1.0

	for blow in range(int(w._fishing_data()["ice"]["blows_needed"])):
		w._hole_blows[1] = [blow, -100000]
		w.action(1, Net.ACT_ICEHOLE, slot, 0, 0, Vector3.ZERO)

	check(said.has(str(w._fishing_data()["ice"]["say_hole"])) and not said.has(str(w._fishing_data()["ice"]["say_no_ice"])), "on the ice the blows open a hole, with no complaint (%s)" % str(said))
	# The left click swing at the air or the ground, at the water or not, never speaks of ice.
	said.clear()
	ice = 0.0
	rock = false

	for point in [air, ground]:
		w._last_mine.clear()
		w.action(1, Net.ACT_MINE, slot + 1, 0, 0, point)

	check(said.filter(func(t): return t.to_lower().contains("ice")).is_empty(), "swings at the air and the ground say nothing about ice (%s)" % str(said))

	_strain()


# BUG-005: strain per second at a ground speed (effort from the server's own speed curve), from a mid strain, in a calm warm day's worth of extra work.
func _rate(w, speed: float, extra: float) -> float:
	w._strain[1] = {"s": 0.8, "state": 0, "t": 0.0}
	w._exertion[1] = w._effort_at_speed(speed)
	w._moving[1] = 1.0 if speed > 0.4 else 0.0
	w._overheat[1] = extra / 0.5   # heat_effort 0.5: this much extra effort from worn clothes on a warm day
	w._work_until.clear()

	for n in range(40):
		w._strain_tick(1, 0.25)

	return (float(w._strain[1]["s"]) - 0.8) / 10.0


func _strain() -> void:
	var w = _make("b")
	var walk: float = float(load("res://scenes/terrain_client/terrain_client.gd").get_script_constant_map()["WALK_SPEED"])
	var run: float = float(load("res://scenes/terrain_client/terrain_client.gd").get_script_constant_map()["RUN_SPEED"])

	for extra in [0.0, 0.06]:
		var idle: float = _rate(w, 0.0, extra)
		var stroll: float = _rate(w, walk, extra)
		var jog: float = _rate(w, 6.0, extra)
		var sprint: float = _rate(w, run, extra)
		check(idle < stroll and stroll < 0.0 and 0.0 < jog and jog < sprint, "idle %.4f < walk %.4f < 0 < jog %.4f < sprint %.4f a second (extra effort %.2f)" % [idle, stroll, jog, sprint, extra])
		check(stroll > idle * 0.5, "a walk recovers slowly, well under the standing pace (%.4f against %.4f)" % [stroll, idle])

	# Strenuous work, then a walk, then standing still: each step down recovers, the last fastest.
	w._strain[1] = {"s": 0.2, "state": 0, "t": 0.0}
	w._overheat[1] = 0.0
	w._moving[1] = 1.0
	w._exertion[1] = w._effort_at_speed(run)

	for n in range(60):
		w._strain_tick(1, 0.25)

	var after_sprint: float = float(w._strain[1]["s"])
	w._exertion[1] = w._effort_at_speed(walk)

	for n in range(80):
		w._strain_tick(1, 0.25)

	var after_walk: float = float(w._strain[1]["s"])
	w._moving[1] = 0.0
	w._exertion[1] = 0.0

	for n in range(40):
		w._strain_tick(1, 0.25)

	var after_idle: float = float(w._strain[1]["s"])
	check(after_sprint > 0.2 and after_walk < after_sprint and (after_sprint - after_walk) / 20.0 > 0.0, "sprint raises strain, the walk after it brings it down (%.2f then %.2f)" % [after_sprint, after_walk])
	check((after_walk - after_idle) / 10.0 > (after_sprint - after_walk) / 20.0, "standing still then brings it down faster than the walk did (%.2f)" % after_idle)


func _client() -> void:
	var table = ItemTableScript.load_default()
	var view: FakeView = FakeView.new()
	view.table = table
	view.inventory.numbers.resize(30)
	view.inventory.numbers.fill(0)
	view.inventory.counts.resize(30)
	view.inventory.counts.fill(0)
	view.inventory.numbers[1] = table.number_of("stone_axe")
	root.add_child(view)
	var camera: Camera3D = Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0.0, 1.6, 0.0)
	var world: Node3D = Node3D.new()
	view.add_child(world)
	var layer: CanvasLayer = CanvasLayer.new()
	view.add_child(layer)
	var net: FakeNet = FakeNet.new()
	var held = HeldItem.new()
	view.add_child(held)
	await process_frame
	held.setup(view, net, camera, world, layer, Callable())
	held.set_first_person(true)
	held.holding = false
	held.press_slot(1)
	held._process(0.05)
	check(held.held_id() == "stone_axe", "the axe is in hand")

	# A swing at nothing (an empty world: the ray hits nothing) tells the server, with a point 2.5 m ahead and the held slot.
	held._strike()
	var calls: Array = net.inventory_action.calls
	var ahead: Vector3 = camera.global_position - camera.global_basis.z * HeldItem.MISS_POINT_M
	check(calls.size() == 1 and calls[0][0] == Net.ACT_MINE and calls[0][1] == 2 and (calls[0][4] as Vector3).distance_to(ahead) < 0.001, "a swing at nothing sends ACT_MINE with the held slot and a point in the air (%s)" % str(calls))
