extends SceneTree

# Floating damage numbers (Dave 2 Nov 2026): a landed hit sends hit_number to the hitter with the damage, a miss sends nothing; the client
# draws the number and the Gameplay toggle (display_settings damage_numbers) is on by default and saved; protocol 86 is wired both ways.
#   godot --headless --path . --script res://src/worldgen/tools/test_hit_numbers.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const DisplayScript := preload("res://src/client/display_settings.gd")
const HitNumbers := preload("res://src/client/hit_numbers.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_hit_numbers"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	var sent: Array = []
	items.send_hit_number = func(peer, at, amount): sent.append([peer, at, amount])
	var lands: Array = [true]
	items.hit_animal = func(_peer, _origin, _aim, _reach, _amount) -> bool: return lands[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "hit-numbers-key-01")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("spear"), 0, 1, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(items.table.number_of("spear"))
	var damage: float = float(items.table.entry("spear").get("damage", 0.0))

	# A jab that lands: one number, the spear's damage, in front of the player.
	items.action(1, Net.ACT_STRIKE, slot, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(sent.size() == 1 and int(sent[0][0]) == 1 and int(sent[0][2]) == int(round(damage)), "a landed jab sends the spear's damage to the hitter (%s)" % str(sent))
	check(sent.size() == 1 and (sent[0][1] as Vector3).z > 10.0, "the number is in front of the player")

	# A miss: nothing.
	lands[0] = false
	items._last_strike.clear()
	items.action(1, Net.ACT_STRIKE, slot, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(sent.size() == 1, "a miss sends no number")

	# A tree or a boulder shows its share of 100 a blow; tiny shares still show 1.
	sent.clear()
	items.hit_number(1, Vector3.ZERO, ItemsScript.HIT_POINTS / 40.0)
	items.hit_number(1, Vector3.ZERO, ItemsScript.HIT_POINTS / 400.0)
	items.hit_number(1, Vector3.ZERO, 0.0)
	check(sent.size() == 2 and int(sent[0][2]) == 3 and int(sent[1][2]) == 1, "shares round, never below 1, and zero sends nothing (%s)" % str(sent))

	# The client draws it.
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	var label: Label3D = HitNumbers.spawn(holder, Vector3(1.0, 2.0, 3.0), 8)
	check(label.get_parent() == holder and label.text == "8" and label.position.y == 2.0, "the client shows the number where the hit landed")
	check(HitNumbers.text_for(0) == "1", "never shows 0")

	# The Gameplay toggle: on by default, saved, reset turns it back on.
	var settings = DisplayScript.new()
	check(settings.damage_numbers, "damage numbers are on by default")
	settings.path = "user://test_hit_numbers_display.cfg"
	settings.damage_numbers = false
	settings.save()
	var back = DisplayScript.new()
	back.path = settings.path
	back.load_saved()
	check(not back.damage_numbers, "turning them off is saved")
	back.reset()
	check(back.damage_numbers, "reset turns them back on")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))

	# Wire: the message, the server send, the client receive and the menu switch.
	var net_text: String = FileAccess.get_file_as_string("res://src/stream/terrain_net.gd")
	check(net_text.contains("func hit_number(at: Vector3, amount: int)") and net_text.contains("signal hit_number_received(at: Vector3, amount: int)"), "terrain_net declares hit_number")
	check(FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd").contains("net.hit_number.rpc_id(peer, at, amount)"), "the server sends it")
	check(FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd").contains("net.hit_number_received.connect"), "the client receives it")
	check(FileAccess.get_file_as_string("res://src/client/game_menu.gd").contains("\"Damage numbers\""), "Gameplay has the Damage numbers switch")

	items._finish_writer()
	holder.free()
	print("test_hit_numbers: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
