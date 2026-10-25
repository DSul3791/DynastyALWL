extends SceneTree

# Eat-once learning (data/items/eat_memory.json): first-hour protection, remembered harm, the hint and the confirm press, save and reload.
#   godot --headless --path . --script res://src/worldgen/tools/test_eat_once.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []
var thoughts: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.send_sick = func(_p, _h): pass
	items.send_thought = func(_p, id, text, kind): thoughts.append([id, text, kind])
	items.setup(ItemTableScript.load_default(), dir)
	return items


func eat(items, id: String) -> void:
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(items.table.number_of(id)), 0, 0, Vector3.ZERO)


func _init() -> void:
	var dir: String = "user://test_eat_once"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	items.peer_connected_hello(1, "eat-once-key-01")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	check(items.grace_of(1) > 3500.0, "a new character starts with the first hour")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("raw_meat"), 0, 4, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("rotten_food"), 0, 2, Vector3.ZERO)
	var v: Dictionary = items.vitals_of(1)
	v["fed"] = 1500.0
	v["wet"] = 1500.0
	eat(items, "raw_meat")
	check(not items.is_sick(1), "unknown raw meat in the first hour does not make you sick")
	check(float(v["fed"]) < 1400.0 and float(v["wet"]) < 1400.0, "but it costs food and water")
	check(items.tried_of(1).get("raw_meat", "") == "harm", "and the harm is remembered")
	check(said.has(items._eat_cfg_value("say_first_hour", "?")), "the player is told")

	said.clear()
	var packed: int = items.inventory_of(1).count_of(items.table.number_of("raw_meat"))
	eat(items, "raw_meat")
	check(items.inventory_of(1).count_of(items.table.number_of("raw_meat")) == packed, "the same food again is stopped, still in the pack")
	check(said.has(items._eat_cfg_value("say_warn", "?")) and thoughts.back()[2] == "hint_harm", "with a notice and the inner-voice hint")
	check(not items.is_sick(1), "and nobody is sick")
	eat(items, "raw_meat")
	check(items.inventory_of(1).count_of(items.table.number_of("raw_meat")) == packed - 1, "a second press within the window eats it")
	check(items.is_sick(1), "and a known harm costs the full sickness, as today")
	v["sick"] = 0.0
	eat(items, "rotten_food")
	check(not items.is_sick(1) and items.tried_of(1).get("rotten_food", "") == "harm", "rotten food, unknown, in the first hour: no sickness, remembered")

	# After the hour: full price.
	items._characters[items._peer_key[1]]["grace_s"] = 0.0
	eat(items, "rotten_food")
	eat(items, "rotten_food")
	check(items.is_sick(1), "after the first hour a remembered harm is the full sickness")

	# Safe food is recorded ok and never warned.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("trail_bread"), 0, 2, Vector3.ZERO)
	v["fed"] = 500.0
	said.clear()
	eat(items, "trail_bread")
	check(items.tried_of(1).get("trail_bread", "") == "ok" and not said.has(items._eat_cfg_value("say_warn", "?")), "safe food is recorded ok, no warning")

	# Grace counts down online time only, saves and reloads.
	items._characters[items._peer_key[1]]["grace_s"] = 100.0
	items._vitals_tick(30.0)
	check(absf(items.grace_of(1) - 70.0) < 0.01, "the first hour counts down with online time")
	items._save_characters()
	var again = make(dir)
	again.peer_connected_hello(1, "eat-once-key-01")
	check(again.tried_of(1).get("raw_meat", "") == "harm" and absf(again.grace_of(1) - 70.0) < 0.01, "tried foods and the remaining hour survive a reload")

	# An old save without the fields loads with defaults and no protection.
	var old = make("user://test_eat_once_old")
	old._characters["old-key-0000001"] = {"luck": 0}
	old.peer_connected_hello(1, "old-key-0000001")
	check(old.tried_of(1).is_empty() and old.grace_of(1) == 0.0, "an old character has nothing tried and no first hour")

	print("test_eat_once: ", failures, " failures")
	quit(1 if failures > 0 else 0)
