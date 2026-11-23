extends SceneTree

# No animal attack goes through a wall (coordinator, 23 Nov 2026: wolves bit through walls; every other attack checked too). The real
# server_items and server_animals wired as the server scene wires them (terrain_server.gd: the big game's hurt_player with its 10-health
# floor, the walls hook on structure_blocks_step), a 10 m log wall across the way:
#   1. every big game charge (bear, boar, moose, buffalo, the big cats, hyena, rhino, elephant, dog) lands in the open, and never on a
#      player standing hard behind the wall; the animal stays on its own side;
#   2. a hunter's chase (a puma at a runner) the same;
#   3. a player who pins an animal against the wall does not push it out through the other side (make_way).
# The wolves' bites and kills: test_wolves 6b and 5c, test_wolf_pups 5b. Shut doors and gates: test_animal_gates (the same hook).
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_attack_walls.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

const DIR := "user://test_animal_attack_walls"
const DT := 0.05
const WALL_X := 101.6        # the wall's middle; its faces are 0.125 m either side
const BEHIND := Vector3(101.2, 10.0, 0.0)
const CHARGERS := ["bear", "black_bear", "boar", "moose", "buffalo", "lion", "tiger", "leopard", "puma", "lynx", "hyena", "rhino", "elephant", "dog"]

var failures: int = 0
var items
var animals
var landed: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "attackwalls0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 10.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return items.peer_positions()
	animals.player_stances = func(): return [0]
	animals.setup()
	animals.traits = false

	for sp in animals.cfg["species"]:
		animals.cfg["species"][sp]["target_per_player"] = 0   # only the animals put down here

	animals.cfg["senses"] = {}
	animals.rng.seed = 7
	animals.walls = func(x0, z0, x1, z1, margin): return items.structure_blocks_step(x0, z0, x1, z1, margin)
	animals.big_game.player_info = func(): return items.wolf_info()
	animals.big_game.hurt_player = func(peer, amount, lethal, cause, from):
		var r: String = items.hurt_player(peer, amount, lethal, cause, 10.0, "", 0.0, from)
		landed.append([amount, r])
		return r

	var walls: Array = []

	for z in [-4.0, -2.0, 0.0, 2.0, 4.0]:   # five 2 m log walls turned to run north and south: 10 m of wall, too long to go round in a charge
		walls.append(items.dev_place("log_wall@%.1f,%.1f,90" % [WALL_X, z]))

	check(not walls.has(0) and animals.wall_between(Vector3(103.0, 10.0, 0.0), BEHIND), "a 10 m log wall stands across the way at x %.1f" % WALL_X)

	_charges()
	_chase()
	_pinned()

	items._finish_writer()
	print("test_animal_attack_walls: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


# A calm `sp` at (x, 0), facing west (toward the player), with no cool-down.
func put(sp: String, x: float) -> Dictionary:
	animals.animals.clear()
	var id: int = animals.spawn(sp, x, 0.0)
	var a: Dictionary = animals.animals[id]
	a["heading"] = PI
	a["cool"] = 0.0
	return a


func stand(at: Vector3) -> void:
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0
	v.erase("limp")
	items.report_position(1, at)
	landed.clear()


# Ticks `seconds`; returns the smallest x the animal reached (it comes from the east).
func run(a: Dictionary, seconds: float) -> float:
	var closest: float = INF

	for k in int(round(seconds / DT)):
		animals.tick(DT)

		if animals.animals.has(int(a["id"])):
			closest = minf(closest, float(animals.animals[int(a["id"])]["pos"].x))

	return closest


# 1. A forced warning (no bluff) and its charge: in the open it lands; at a player hard behind the wall it never does.
func _charges() -> void:
	for sp in CHARGERS:
		stand(Vector3(0.0, 10.0, 0.0))
		var open: Dictionary = put(sp, 8.0)
		var warned: bool = animals.big_game.warn(open, Vector3(0.0, 10.0, 0.0), -1.0, true)
		run(open, 8.0)
		check(warned and not landed.is_empty(), "%s: its charge lands on a player in the open (%d blows)" % [sp, landed.size()])

		stand(BEHIND)
		var walled: Dictionary = put(sp, 106.0)
		animals.big_game.warn(walled, BEHIND, -1.0, true)
		var closest: float = run(walled, 12.0)
		check(landed.is_empty() and closest > WALL_X, "%s: its charge at a player behind the wall never lands (%d blows) and it stays on its side (nearest x %.2f)" % [sp, landed.size(), closest])


# 2. A hunter giving chase to a runner (no warning, no bluff) is the same charge: never through the wall.
func _chase() -> void:
	stand(Vector3(0.0, 10.0, 0.0))
	var open: Dictionary = put("puma", 8.0)
	var chased: bool = animals.big_game.chase(open, Vector3(0.0, 10.0, 0.0), 30.0)
	run(open, 6.0)
	check(chased and not landed.is_empty(), "a puma's chase lands on a runner in the open (%d blows)" % landed.size())

	stand(BEHIND)
	var walled: Dictionary = put("puma", 106.0)
	animals.big_game.chase(walled, BEHIND, 30.0)
	var closest: float = run(walled, 6.0)
	check(landed.is_empty() and closest > WALL_X, "a puma's chase at a runner behind the wall never lands (%d blows; nearest x %.2f)" % [landed.size(), closest])


# 3. A deer against the wall's east face, a player walking into it from the east: it steps aside, never out through the wall.
func _pinned() -> void:
	var face: float = WALL_X + 0.125
	var player: Vector3 = Vector3(102.4, 10.0, 0.0)
	var deer: Dictionary = put("deer", 101.9)

	for k in 20:
		animals.make_way(deer, player, 0.1, [player])

	check(float(deer["pos"].x) > face, "a deer a player pins against the wall does not step out through it (x %.2f, the face at %.2f)" % [float(deer["pos"].x), face])

