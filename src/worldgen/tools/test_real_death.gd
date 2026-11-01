extends SceneTree

# Real death (data/items/death.json real_death, off until Dave answers the death cards): switched off the character comes back as always; switched on, a character past
# novice grace is marked dead, the remains stay, final_death goes out and nobody is brought back; logging in again as a dead character gets the screen again.
#   godot --headless --path . --script res://src/worldgen/tools/test_real_death.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const DeathScreen := preload("res://src/client/death_screen.gd")

var failures: int = 0
var finals: Array = []
var died: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.send_died = func(p, cause, point): died.append([p, cause, point])
	items.send_final_death = func(p, cause): finals.append([p, cause])
	items.setup(ItemTableScript.load_default(), dir)
	items.ground_height = func(_x, _z): return 10.0
	return items


func _init() -> void:
	# Off (the default): a level 10 character who dies comes back.
	var a = make("user://test_real_death_a")
	check(not bool(a._death_cfg.get("real_death", true)), "real_death is off in the shipped data")
	a.peer_connected_hello(1, "realdeathkey0001")
	a.report_position(1, Vector3(100.0, 12.0, 100.0))
	a._characters["realdeathkey0001"]["skills"] = {"foraging": 90.0}
	a._death_cfg["novice_grace"] = {"mode": "never"}
	check(a.kill(1, "wolves"), "kill works")
	check(finals.size() == 1 and died.size() == 1 and not bool(a._characters["realdeathkey0001"].get("dead", false)), "off: final_death is told as before but the character comes back (died sent, not marked dead)")

	# On: marked dead, no return.
	finals.clear()
	died.clear()
	var b = make("user://test_real_death_b")
	b._death_cfg["real_death"] = true
	b._death_cfg["novice_grace"] = {"mode": "never"}
	b.peer_connected_hello(1, "realdeathkey0002")
	b.report_position(1, Vector3(100.0, 12.0, 100.0))
	b.action(1, 66, b.table.number_of("stone"), 0, 5, Vector3.ZERO)
	check(b.kill(1, "wolves"), "on: kill works")
	check(finals.size() == 1 and str(finals[0][1]) == "wolves", "on: final_death goes out with the cause")
	check(died.is_empty(), "on: nobody is brought back")
	check(bool(b._characters["realdeathkey0002"].get("dead", false)), "on: the character is marked dead")
	check(not b.remains_ids().is_empty(), "on: the remains stay in the world")
	b.save()

	# A dead character that logs in again gets the screen again.
	finals.clear()
	var c = make("user://test_real_death_b_reload")
	c._death_cfg["real_death"] = true
	DirAccess.copy_absolute("user://test_real_death_b/characters.json", "user://test_real_death_b_reload/characters.json")
	c._load_characters()
	c.peer_connected_hello(1, "realdeathkey0002")
	check(finals.size() == 1 and str(finals[0][1]) == "", "a dead character logging in gets the death screen again")

	# Novice grace still protects: a low level character comes back whatever real_death says.
	finals.clear()
	died.clear()
	var d = make("user://test_real_death_d")
	d._death_cfg["real_death"] = true
	d._death_cfg["novice_grace"] = {"mode": "always"}
	d.peer_connected_hello(1, "realdeathkey0003")
	d.report_position(1, Vector3(100.0, 12.0, 100.0))
	d.kill(1, "wolves")
	check(finals.is_empty() and died.size() == 1, "novice grace: no final death, the character comes back")

	# The screen's words.
	var lines: Array = DeathScreen.lines("wolves", "Ada")
	check(str(lines[0]) == "Ada has died (wolves)." and lines.size() == 3, "the screen names who died and how")
	check(str(DeathScreen.lines("", "")[0]) == "Your character has died.", "an already dead character: no cause")

	print("test_real_death: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
