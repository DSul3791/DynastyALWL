extends SceneTree

# Floating damage numbers (Dave 2 Nov 2026): a landed hit sends hit_number to the hitter with the damage, a miss sends nothing; the client
# draws the number and the Gameplay toggle (display_settings damage_numbers) is on by default and saved; protocol 86 is wired both ways.
#   godot --headless --path . --script res://src/worldgen/tools/test_hit_numbers.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const SkillWebScript := preload("res://src/shared/skill_web.gd")
const DisplayScript := preload("res://src/client/display_settings.gd")
const HitNumbers := preload("res://src/client/hit_numbers.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const MeleeRules := preload("res://src/shared/melee_rules.gd")

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

	# Anything in hand is a weapon (Dave 19 Nov 2026 play test: an axe did nothing to a pig): a tool or food strikes for its data/items/melee.json row.
	lands[0] = true
	var melee: Dictionary = MeleeRules.load_config()
	var struck: Array = []
	items.hit_animal = func(_peer, _origin, _aim, reach, amount) -> bool:
		struck.append([reach, amount])
		return true

	items._skill_records(1).clear()   # the jabs above trained a little; the melee rows are checked at skill 1 (factor 1.0)

	for id in ["stone_axe", "steel_axe", "berries"]:
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, 1, Vector3.ZERO)
		items._last_strike.clear()
		items.action(1, Net.ACT_STRIKE, items.inventory_of(1).numbers.find(items.table.number_of(id)), 0, 0, Vector3(0.0, 0.0, 1.0))
		items._skill_records(1).clear()

	var axe_row: Dictionary = melee["tool"]["tool_axe"]
	check(struck.size() == 3 and is_equal_approx(float(struck[0][1]), float(axe_row["damage"])) and is_equal_approx(float(struck[1][1]), float(axe_row["damage"]) + 3.0 * float(melee["tier_step"])),
			"a Stone axe strikes an animal for its melee damage and a Steel axe three tiers harder (%s)" % str(struck))
	check(struck.size() == 3 and is_equal_approx(float(struck[2][1]), float(melee["other"]["damage"])) and float(struck[2][0]) < float(struck[0][0]), "berries in hand strike weakly and at a shorter reach (%s)" % str(struck))
	check(float(MeleeRules.blow(items.table.entry("spear"), melee)["reach_m"]) == 3.0 and float(MeleeRules.blow(items.table.entry("spear"), melee)["damage"]) == 0.0, "a spear keeps its own damage and 3 m reach")
	# The server's hook answers where the blow struck: the number floats just above that point, not in front of the eye (Dave 19 Nov 2026).
	sent.clear()
	items.hit_animal = func(_peer, _origin, _aim, _reach, _amount) -> Dictionary: return {"at": Vector3(10.0, 0.6, 12.0)}
	items._last_strike.clear()
	items.action(1, Net.ACT_STRIKE, slot, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(sent.size() == 1 and (sent[0][1] as Vector3).is_equal_approx(Vector3(10.0, 0.9, 12.0)), "the number floats where the blow struck the animal (%s)" % str(sent))
	items.hit_animal = func(_peer, _origin, _aim, _reach, _amount) -> Dictionary: return {}
	items._last_strike.clear()
	items.action(1, Net.ACT_STRIKE, slot, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(sent.size() == 1, "an empty answer is a miss: no number")

	# Bare hands punch (Dave 23 Nov 2026): slot -1 (nothing in hand) or an empty slot strikes for melee.json bare_hand times the Hand to hand
	# skill factor, at its short reach, and a punch that lands trains Hand to hand.
	var punched: Array = []
	items.hit_animal = func(_peer, _origin, _aim, reach, amount) -> Dictionary:
		punched.append([reach, amount])
		return {"at": Vector3(10.0, 1.0, 11.0)}
	var skill_before: float = items.working_level(1, "hand_to_hand")
	items._last_strike.clear()
	items._last_practice.clear()
	items.action(1, Net.ACT_STRIKE, -1, 0, 0, Vector3(0.0, 0.0, 1.0))
	var bare: Dictionary = melee["bare_hand"]
	var want: float = float(bare["damage"]) * items.skill_factor(1, "punch")
	check(punched.size() == 1 and is_equal_approx(float(punched[0][0]), float(bare["reach_m"])) and absf(float(punched[0][1]) - want) < 0.5 and float(punched[0][1]) > 0.0,
			"an empty hand punches for bare_hand times the skill (%s, want about %.2f)" % [str(punched), want])
	# Everyone starts at 1 in every skill and gains by doing (Dave 23 Nov 2026; SKILLS_WEB_DESIGN.md 1, 5): Hand to hand is the design's Brawling
	# under Fighting, locked until Fighting 15 (and Fighting until Athleticism 15), so a new player's punch trains the nearest unlocked parent.
	var records: Dictionary = items._skill_records(1)
	check(float(records.get("athletics", {}).get("p", 0.0)) > 0.0 and not records.has("hand_to_hand"), "a new player's punch trains Athleticism, which unlocks Fighting (%s)" % str(records.keys()))
	check(items.working_level(1, "hand_to_hand") >= skill_before, "and never lowers Hand to hand")
	var web: Dictionary = items._skills_cfg
	records["athletics"] = {"p": SkillWebScript.units_for(web, "athletics", 16.0)}
	records["fighting"] = {"p": SkillWebScript.units_for(web, "fighting", 16.0)}
	items._last_strike.clear()
	items._last_practice.clear()
	items.action(1, Net.ACT_STRIKE, -1, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(float(records.get("hand_to_hand", {}).get("p", 0.0)) > 0.0, "once Fighting is 15 a punch trains Hand to hand itself")
	punched.clear()
	items._last_strike.clear()
	items._last_practice.clear()
	items.action(1, Net.ACT_STRIKE, slot, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(float(records.get("spear", {}).get("p", 0.0)) > 0.0, "a spear blow that lands trains Spear")
	check(ItemsScript._blow_action("steel_rapier", items.table.entry("steel_rapier")) == "strike_rapier" and ItemsScript._blow_action("iron_sword", items.table.entry("iron_sword")) == "strike_sword"
		and ItemsScript._blow_action("stone_axe", items.table.entry("stone_axe")) == "strike_fighting" and ItemsScript._blow_action("stone_knife", items.table.entry("stone_knife")) == "strike_knife", "each weapon trains its skill")
	records.erase("hand_to_hand")
	records.erase("spear")
	records.erase("fighting")
	records["athletics"] = {"p": 0.0}
	items.action(1, Net.ACT_STRIKE, -1, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(punched.size() == 1, "punches keep bare_hand's pace (recover_ms)")
	var empty_slot: int = items.inventory_of(1).numbers.find(0)
	items._last_strike.clear()
	items.action(1, Net.ACT_STRIKE, empty_slot, 0, 0, Vector3(0.0, 0.0, 1.0))
	check(empty_slot >= 0 and punched.size() == 2, "an empty slot in hand punches too")
	sent.clear()
	sent.clear()
	items.hit_animal = func(_peer, _origin, _aim, _reach, _amount) -> bool: return lands[0]

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
	var client_text: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(client_text.contains("net.animal_hit_point_received.connect") and client_text.contains("animal_view.flinch(id)") and client_text.contains("sound.spear.hit(\"flesh\", at, 1.0)"), "a landed blow on an animal thuds and the body flinches")
	var server_text: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server_text.contains("return {\"at\": point}"), "the server's hook answers where it struck")
	check(FileAccess.get_file_as_string("res://src/client/game_menu.gd").contains("\"Damage numbers\""), "Gameplay has the Damage numbers switch")

	items._finish_writer()
	holder.free()
	print("test_hit_numbers: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
