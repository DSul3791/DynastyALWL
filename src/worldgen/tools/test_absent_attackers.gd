extends SceneTree

# A player whose line drops is out of the world for attackers after 15 s (coordinator's ruling, 23 Nov 2026; server_items is_absent and
# _park_quiet, the players thread): a wolf pack rushing them lets go and bites no more, a bear charging them lands nothing and calms, and
# neither stays at the spot or takes them up again. The real server_items and server_animals wired as the server scene wires them.
#   godot --headless --path . --script res://src/worldgen/tools/test_absent_attackers.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const BigGame := preload("res://src/stream/server_big_game.gd")

const DIR := "user://test_absent_attackers"
const DT := 0.1
const SPOT := Vector3(0.0, 10.0, 0.0)
const OTHER := Vector3(-150.0, 10.0, 0.0)

var failures: int = 0
var items
var animals
var bites: int = 0
var blows: int = 0


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
	items.peer_connected_hello(1, "absentattack01")
	items.report_position(1, SPOT)
	items.peer_connected_hello(2, "absentattack02")   # a second player stays, 150 m off (beyond the pack's notice and the bear's calm_m), so the
	items.report_position(2, OTHER)                   # animals keep ticking when the first is parked (with nobody near they freeze or go)

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
	animals.cfg["wolves"]["cell_share"] = 0.0
	animals.rng.seed = 5
	animals.big_game.player_info = func(): return items.wolf_info()
	animals.big_game.hurt_player = func(_peer, _amount, _lethal, _cause, _from):
		blows += 1
		return "hurt"
	animals.wolves.player_info = func(): return items.wolf_info()
	animals.wolves.fires = func(): return []
	animals.wolves.notice = func(_p, _t): pass
	animals.wolves.hurt_player = func(_peer, _dmg, _lethal, _cause, _from):
		bites += 1
		return "hurt"

	_wolves()
	_bear()

	items._finish_writer()
	print("test_absent_attackers: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func back() -> void:
	items.report_position(1, SPOT)
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0


func park() -> void:
	var now: int = Time.get_ticks_msec()
	items._heard_ms[1] = now - ItemsScript.ABSENT_MS - 5000
	items._park_check_ms = 0
	items._park_quiet(now)


func run(seconds: float) -> void:
	for k in int(round(seconds / DT)):
		items.report_position(2, OTHER)   # the second player keeps reporting
		animals.tick(DT)


# 1. A pack rushing the player: parked, it lets go of them (no target) and bites no more.
func _wolves() -> void:
	back()
	var pid: int = animals.wolves.spawn_pack(20.0, 0.0)
	var pack: Dictionary = animals.wolves.packs[pid]
	pack["den"] = Vector3(9000.0, 0.0, 0.0)
	pack["phase"] = "rush"
	pack["target"] = 1
	pack["sprint"] = 0.0
	pack["bite"] = {}
	bites = 0
	run(3.0)
	var before: int = bites
	park()
	check(items.is_absent(1) and not items.is_absent(2) and items.wolf_info().size() == 1, "a quiet player is parked: out of the attackers' list (the other stays)")
	run(2.0)
	check(int(pack["target"]) != 1 and not (str(pack["phase"]) in ["rush", "stalk"]), "the pack lets go of a parked player (phase %s, target %d)" % [str(pack["phase"]), int(pack["target"])])
	run(30.0)
	check(bites == before, "and bites no more (%d bites after parking)" % (bites - before))
	check(int(pack["target"]) != 1, "nor takes them up again while they are parked (target %d)" % int(pack["target"]))
	back()
	check(not items.is_absent(1), "the player reports again: back in the world")

	animals.animals.clear()
	animals.wolves.packs.clear()


# 2. A bear charging the player: parked mid-warning, the charge lands nothing and it calms; it does not warn at the empty spot again.
func _bear() -> void:
	back()
	animals.animals.clear()
	var id: int = animals.spawn("bear", 8.0, 0.0)
	var bear: Dictionary = animals.animals[id]
	bear["heading"] = PI
	bear["cool"] = 0.0
	blows = 0
	animals.big_game.warn(bear, SPOT, -1.0, true)
	run(0.5)
	park()
	run(15.0)
	var state: int = int(animals.animals[id]["state"]) if animals.animals.has(id) else -1
	check(blows == 0, "a bear's charge at a parked player lands nothing (%d blows)" % blows)
	check(animals.animals.has(id) and not (state in [BigGame.WARN, BigGame.WARN_POP, BigGame.CHARGE, BigGame.RECOVER]) and int(animals.animals[id].get("foe_peer", -1)) != 1, "and it calms, with no foe kept (state %d)" % state)
	back()
