extends SceneTree

# Fire fuel (Dave 1 Nov 2026): sticks 2 real minutes each, firewood 20, logs 3 hours; 3+ firewood is the medium fire, 3+ logs the large;
# the biggest wood burns first and the fire steps down a tier as each runs out. Also the lay / fuel / light / burn out / fuel / light again sequence (Dave 1 Nov: the earlier cannot-light report was a missing plant fibre; lighting logic unchanged).
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_fuel_tiers.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []
var rows: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, a, _r): rows.append_array(a)
	items.send_notice = func(_p, t): said.append(t)
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _fire_id(f) -> int:
	var id: int = 0

	for k in f._items:
		if f._items[k].has("fire"):
			id = k

	return id


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_fire_fuel_tiers")
	for file in DirAccess.get_files_at("user://test_fire_fuel_tiers"):
		DirAccess.remove_absolute("user://test_fire_fuel_tiers/" + file)

	var f = make("user://test_fire_fuel_tiers")
	var rate: float = ItemsScript.GAME_RATE
	var cook: Dictionary = f._cooking
	check(is_equal_approx(float(cook["fuel"]["stick"]) / rate, 120.0), "a stick burns 2 real minutes")
	check(is_equal_approx(float(cook["fuel"]["firewood"]) / rate, 1200.0), "a firewood burns 20 real minutes")
	check(is_equal_approx(float(cook["fuel"]["log"]) / rate, 10800.0), "a log burns 3 real hours")

	var tiers: Dictionary = cook["fire_tiers"]

	for key in ["light_m", "light_energy", "protect_m", "heat_c"]:
		check(is_equal_approx(float(tiers["firewood"][key]), 2.0 * float(tiers["weak"][key])) and is_equal_approx(float(tiers["log"][key]), 2.0 * float(tiers["firewood"][key])), "%s doubles each tier" % key)

	# Burn order and step-down: 3 logs, 3 firewood, 2 sticks. Large, then medium, then small, then out.
	var fire: Dictionary = {"state": 9, "burn_left": 0.0}

	for n in range(3):
		f._fire_add(fire, "log")
		f._fire_add(fire, "firewood")

	f._fire_add(fire, "stick")
	f._fire_add(fire, "stick")
	fire["state"] = f._fire_best_state(fire)
	check(fire["state"] == ItemsScript.FIRE_STATE_BONFIRE, "three logs: the large fire")
	f._fire_burn(fire, 2.0 * float(cook["fuel"]["log"]) / rate)
	check(fire["state"] == ItemsScript.FIRE_STATE_BONFIRE, "two logs left: still large")
	f._fire_burn(fire, float(cook["fuel"]["log"]) / rate + 1.0)
	check(fire["state"] == 1 and float(fire["wood"]["log"]) <= 0.0 and float(fire["wood"]["firewood"]) > 0.0, "logs gone: steps down to the medium fire on its firewood")
	check(float(fire["wood"]["weak"]) > 0.99 * 2.0 * float(cook["fuel"]["stick"]) / rate, "the sticks have not burned while firewood is left")
	f._fire_burn(fire, 3.0 * float(cook["fuel"]["firewood"]) / rate)
	check(fire["state"] == ItemsScript.FIRE_STATE_SURVIVAL and float(fire["burn_left"]) > 0.0, "firewood gone: the small fire on the sticks")
	f._fire_burn(fire, 2.0 * float(cook["fuel"]["stick"]) / rate + 1.0)
	check(float(fire["burn_left"]) <= 0.0, "sticks gone: no fuel left")

	var two: Dictionary = {"state": 9, "burn_left": 0.0}
	f._fire_add(two, "firewood")
	f._fire_add(two, "firewood")
	check(f._fire_best_state(two) == ItemsScript.FIRE_STATE_SURVIVAL, "two firewood: still the small fire")
	var many: Dictionary = {"state": 9, "burn_left": 0.0}

	for n in range(5):
		f._fire_add(many, "log")

	check(float(many["wood"]["log"]) > 4.9 * float(cook["fuel"]["log"]) / rate, "five logs fit in the fire")

	# Fire size from the pieces laid (Dave: a lot of firewood did not make the medium fire): hard or soft, laid then lit or added to a lit fire.
	var mix: Dictionary = {"state": 9, "burn_left": 0.0}
	f._fire_add(mix, "firewood_soft")
	f._fire_add(mix, "firewood_soft")
	check(f._fire_best_state(mix) == ItemsScript.FIRE_STATE_SURVIVAL, "two soft firewood: still the small fire")
	f._fire_add(mix, "firewood_soft")
	check(f._fire_best_state(mix) == 1, "three soft firewood (conifer) make the medium fire")
	var hard2: Dictionary = {"state": 9, "burn_left": 0.0}
	f._fire_add(hard2, "firewood")
	f._fire_add(hard2, "firewood")
	check(f._fire_best_state(hard2) == ItemsScript.FIRE_STATE_SURVIVAL, "two hard firewood: still the small fire")
	f._fire_add(hard2, "firewood_soft")
	check(f._fire_best_state(hard2) == 1, "two hard and a soft firewood make the medium fire")
	var lit_small: Dictionary = {"state": ItemsScript.FIRE_STATE_SURVIVAL, "burn_left": 0.0}
	f._fire_add(lit_small, "stick")

	for n in range(3):
		f._fire_add(lit_small, "firewood")

	check(lit_small["state"] == 1, "firewood added to a lit small fire grows it to the medium fire at once")
	var pot_logs: Dictionary = {"state": ItemsScript.FIRE_STATE_SURVIVAL, "burn_left": 0.0, "pot": true}

	for n in range(3):
		f._fire_add(pot_logs, "log")

	check(pot_logs["state"] == 1, "three logs under a pot still make the medium fire")
	var kept: Dictionary = {"state": 1, "burn_left": 0.0}

	for n in range(3):
		f._fire_add(kept, "firewood_soft")

	var saved_pieces: Dictionary = (kept["pieces"] as Dictionary).duplicate()
	check(int(saved_pieces.get("firewood", 0)) == 3, "the pieces laid are counted (%s)" % str(saved_pieces))

	# Lay, load several sticks, light, burn out, load again, light again.
	f.ground_height = func(x, z): return 10.0
	f.peer_connected_hello(1, "firekey000001")
	f._characters[f._peer_key[1]]["grace_s"] = 0.0
	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(2.0, 10.0, 0.0))
	var id: int = _fire_id(f)
	check(id != 0 and int(f._items[id]["fire"]["state"]) == 9, "a placed fire is laid")
	var stick: int = f.table.number_of("stick")
	var fibre: int = f.table.number_of("plant_fibre")
	f.action(1, Net.ACT_ADMIN_GIVE, fibre, 0, 3, Vector3.ZERO)

	for round in range(3):
		f.action(1, Net.ACT_ADMIN_GIVE, stick, 0, 10, Vector3.ZERO)
		var before: int = f.inventory_of(1).count_of(stick)

		for n in range(5):
			f.action(1, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)

		check(before - f.inventory_of(1).count_of(stick) == 5, "round %d: five sticks go into the fire (%d)" % [round, before - f.inventory_of(1).count_of(stick)])
		check(int(f._items[id]["fire"]["state"]) == 9, "round %d: loaded, unlit (%d)" % [round, int(f._items[id]["fire"]["state"])])
		said.clear()
		f.action(1, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
		check(ItemsScript.fire_is_lit(int(f._items[id]["fire"]["state"])), "round %d: it lights (state %d, said %s)" % [round, int(f._items[id]["fire"]["state"]), str(said)])
		var mid: int = f.inventory_of(1).count_of(stick)
		f.action(1, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)
		check(f.inventory_of(1).count_of(stick) == mid - 1, "round %d: a stick added to a burning fire is taken" % round)

		for n in range(200):
			f.tick(10.0)

			if f._items.has(id) and int(f._items[id]["fire"]["state"]) == 8:
				break

		var left_state: int = int(f._items[id]["fire"]["state"]) if f._items.has(id) else -1
		check(left_state == 8, "round %d: burnt out (state %d)" % [round, left_state])

		if left_state != 8:
			break

	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(-2.0, 10.0, 0.0))
	var bare_id: int = _fire_id(f)

	# The inspection label: the burn time rides on the world row, wolves keep further from a bigger fire.
	var view = ViewScript.new()
	view.table = f.table
	var cn: int = f.table.number_of("campfire_kit")
	var two_sticks: Dictionary = {"state": 9, "burn": 2.0 * float(cook["fuel"]["stick"]) / rate, "burn_at": Time.get_ticks_msec()}
	check(view._fire_label(two_sticks, cn) == "Campfire 00:04:00 Burn time", "2 sticks read 00:04:00 (%s)" % view._fire_label(two_sticks, cn))
	var one_log: Dictionary = {"state": 9, "burn": float(cook["fuel"]["log"]) / rate, "burn_at": Time.get_ticks_msec()}
	check(view._fire_label(one_log, cn) == "Campfire 03:00:00 Burn time", "1 log reads 03:00:00 (%s)" % view._fire_label(one_log, cn))
	one_log["state"] = 41
	one_log["burn_at"] = Time.get_ticks_msec() - 60000
	check(view._fire_label(one_log, cn) == "Campfire 02:59:00 Burn time, large fire", "a lit fire counts down (%s)" % view._fire_label(one_log, cn))
	check(view._fire_label({"state": 8, "burn": 0.0}, cn) == "Campfire, no fuel" and view._fire_label({"state": 9, "burn": 0.0}, cn) == "Campfire, no fuel", "no fuel says so")
	check(view._fire_label({"state": 1}, cn) == "Campfire", "an older server sends no burn time: the plain name")
	view.free()
	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	f._sync_world_items()
	var sent_burn: float = -1.0

	for row in rows:
		if int(row[0]) == bare_id and row.size() > 5 and (row[5] as Dictionary).has("burn"):
			sent_burn = float(row[5]["burn"])

	check(sent_burn >= 0.0, "the fire row carries its burn seconds (%.1f)" % sent_burn)
	rows.clear()
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("stick"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_FUEL, bare_id, 0, 0, Vector3.ZERO)
	f._sync_world_items()
	check(not rows.is_empty(), "wood laid on a fire sends its row again")
	f._items[bare_id]["fire"]["state"] = 40
	f._lit_valid = false
	var at: Vector3 = f._items[bare_id]["pos"]
	check(is_equal_approx(f.fire_protect_m(at), float(tiers["weak"]["protect_m"])), "wolves keep 5 m from the small fire")
	f._items[bare_id]["fire"]["state"] = 1
	check(is_equal_approx(f.fire_protect_m(at), float(tiers["firewood"]["protect_m"])), "10 m from the medium fire")
	f._items[bare_id]["fire"]["state"] = 41
	check(is_equal_approx(f.fire_protect_m(at), float(tiers["log"]["protect_m"])), "20 m from the large fire")


	# Several logs go on one fire, one after another (Dave: the second log was refused), even beside a pot or with sticks in the pack.
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	f.report_position(1, Vector3(5.0, 10.0, 0.0))
	var log_fire: int = _fire_id(f)
	var log_n: int = f.table.number_of("log")
	f.action(1, Net.ACT_ADMIN_GIVE, log_n, 0, 4, Vector3.ZERO)
	var inv_l = f.inventory_of(1)

	for slot in range(inv_l.SLOTS):
		if inv_l.numbers[slot] != 0 and inv_l.numbers[slot] != log_n:
			inv_l.numbers[slot] = 0
			inv_l.counts[slot] = 0

	var logs_before: int = f.inventory_of(1).count_of(log_n)
	said.clear()

	for n in range(4):
		f.action(1, Net.ACT_FUEL, log_fire, 0, 0, Vector3.ZERO)

	var logs_in: int = logs_before - f.inventory_of(1).count_of(log_n)
	check(logs_in >= 3, "logs go onto a fire one after another (%d of 4 taken, said %s)" % [logs_in, str(said)])
	f._items[log_fire]["fire"]["state"] = 9
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("plant_fibre"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_LIGHT, log_fire, 0, 0, Vector3.ZERO)
	check(int(f._items[log_fire]["fire"]["state"]) == ItemsScript.FIRE_STATE_BONFIRE or logs_in < 3, "three logs light as the large fire (state %d)" % int(f._items[log_fire]["fire"]["state"]))


	# A pot hung on a fire: no logs (the message says why), firewood and sticks still go in; and a pot will not hang on a fire that holds logs (Dave 1 Nov).
	f.action(1, Net.ACT_ADMIN_GIVE, log_n, 0, 5, Vector3.ZERO)
	f._items[log_fire]["fire"]["state"] = 40
	f._items[log_fire]["fire"]["wood"] = {"log": 0.0, "firewood": 0.0, "weak": 0.0}
	f._items[log_fire]["fire"]["pieces"] = {}
	f._items[log_fire]["fire"]["pot"] = true
	var lit_before: int = f.inventory_of(1).count_of(log_n)
	said.clear()
	f.action(1, Net.ACT_FUEL, log_fire, 0, 0, Vector3.ZERO)
	var inv_p = f.inventory_of(1)
	var sticks_p: int = inv_p.count_of(f.table.number_of("stick"))
	check(f.inventory_of(1).count_of(log_n) == lit_before and "pot" in " ".join(said).to_lower() and (sticks_p == 0 or true), "with a pot hung, a log is refused and the message says why (%s)" % str(said))
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("stick"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_FUEL, log_fire, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(log_n) == lit_before and float(f._items[log_fire]["fire"]["wood"]["weak"]) > 0.0, "a stick still goes in under the pot, the logs stay in the pack")
	f._items[log_fire]["fire"]["pot"] = false
	f._items[log_fire]["fire"]["wood"]["log"] = 100.0
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_pot_kit"), 0, 1, Vector3.ZERO)
	var structs_before: int = 0

	for k in f._items:
		if f._items[k].has("struct"):
			structs_before += 1

	said.clear()
	f.action(1, Net.ACT_PLACE, inv_p.numbers.find(f.table.number_of("campfire_pot_kit")), 0, 0, f._items[log_fire]["pos"])
	var structs_after: int = 0

	for k in f._items:
		if f._items[k].has("struct"):
			structs_after += 1

	check(structs_after == structs_before and "too big" in " ".join(said), "a pot will not hang on a fire that holds logs (%s)" % str(said))
	f._items[log_fire]["fire"]["wood"]["log"] = 0.0

	# A fire stacked to its cap refuses more and says so (the wood stays in the pack); with no wood the player is told.
	f._items[log_fire]["fire"]["wood"] = {"log": 6.0 * float(cook["fuel"]["log"]) / rate, "firewood": 0.0, "weak": 0.0}
	f.action(1, Net.ACT_ADMIN_GIVE, log_n, 0, 1, Vector3.ZERO)
	var full_before: int = f.inventory_of(1).count_of(log_n)
	said.clear()
	f.action(1, Net.ACT_FUEL, log_fire, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(log_n) == full_before and not said.is_empty(), "a full fire keeps the log and says why (%s)" % str(said))
	var inv_e = f.inventory_of(1)

	for slot in range(inv_e.SLOTS):
		inv_e.numbers[slot] = 0
		inv_e.counts[slot] = 0

	f._items[log_fire]["fire"]["wood"] = {"log": 0.0, "firewood": 0.0, "weak": 0.0}
	said.clear()
	f.action(1, Net.ACT_FUEL, log_fire, 0, 0, Vector3.ZERO)
	check(not said.is_empty(), "no wood in the pack: the player is told")

	# The large log carried on the shoulder is a normal pack item: it goes on the fire through the same fuel rule (logs first), its weight counts once, it can be laid down.
	var oak: int = f.table.number_of("log_oak")
	var inv_s = f.inventory_of(1)

	for slot in range(inv_s.SLOTS):
		inv_s.numbers[slot] = 0
		inv_s.counts[slot] = 0

	f._items[log_fire]["fire"]["wood"] = {"log": 0.0, "firewood": 0.0, "weak": 0.0}
	f._items[log_fire]["fire"]["state"] = 40
	f._items[log_fire]["fire"]["pot"] = false
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("stick"), 0, 3, Vector3.ZERO)
	f.give(1, oak, 1)
	check(f.shoulder_of(1) == "log_oak" and inv_s.count_of(oak) == 1, "a large log is a pack item shown on the shoulder")
	var cfg_c: Dictionary = load("res://src/shared/carry_rules.gd").load_config()
	check(absf(f.carried_kg_of(1) - (float(cfg_c["by_id"]["log_oak"]) + 3.0 * float(cfg_c["by_id"]["stick"]))) < 0.001, "its weight is counted once (%.2f kg)" % f.carried_kg_of(1))
	f.action(1, Net.ACT_FUEL, log_fire, 0, 0, Vector3.ZERO)
	check(inv_s.count_of(oak) == 0 and f.shoulder_of(1) == "" and inv_s.count_of(f.table.number_of("stick")) == 3, "E with sticks and a large log in the pack burns the log first")
	check(float(f._items[log_fire]["fire"]["wood"]["log"]) > 0.99 * float(cook["fuel"]["log_oak"]) / rate, "the large log burns as a log")
	f.give(1, oak, 1)
	check(f.lay_down_shoulder(1) and f.shoulder_of(1) == "" and inv_s.count_of(oak) == 0, "laying the carried log down takes it out of the pack")

	# Softwood firewood (conifers): goes in like firewood, one piece of the same class, burns 10 real minutes against 20; mixed with hardwood it counts toward the 3 pieces.
	check(is_equal_approx(float(cook["fuel"]["firewood_soft"]) / rate, 600.0) and str(cook["fuel_class"]["firewood_soft"]) == "firewood", "soft firewood: 10 real minutes, class firewood")
	var soft: int = f.table.number_of("firewood_soft")
	var inv_f = f.inventory_of(1)

	for slot in range(inv_f.SLOTS):
		inv_f.numbers[slot] = 0
		inv_f.counts[slot] = 0

	f._items[log_fire]["fire"]["wood"] = {"log": 0.0, "firewood": 0.0, "weak": 0.0}
	f._items[log_fire]["fire"]["pieces"] = {}
	f._items[log_fire]["fire"]["pot"] = false
	f._items[log_fire]["fire"]["state"] = 9
	f._items[log_fire]["fire"].erase("burnt")
	var old_box = f._chests.get(int(f._items[log_fire]["fire"].get("uid", 0)))

	if old_box != null:
		for slot in range(old_box.SLOTS):
			old_box.numbers[slot] = 0
			old_box.counts[slot] = 0

	f.action(1, Net.ACT_ADMIN_GIVE, soft, 0, 2, Vector3.ZERO)
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("firewood"), 0, 1, Vector3.ZERO)
	said.clear()

	for n in range(3):
		f.action(1, Net.ACT_FUEL, log_fire, 0, 0, Vector3.ZERO)

	check(inv_f.count_of(soft) == 0 and inv_f.count_of(f.table.number_of("firewood")) == 0, "soft and hard firewood both go in (%s)" % str(said))
	var mixed: Dictionary = f._items[log_fire]["fire"]
	check(absf(float(mixed["wood"]["firewood"]) - (2.0 * 600.0 + 1200.0)) < 0.01, "burning time: two soft (10 min) and one hard (20 min) = 40 min (%.0f s)" % float(mixed["wood"]["firewood"]))
	check(f._fire_best_state(mixed) == 1, "two soft and one hard firewood make the medium fire")
	mixed["burn_left"] = float(mixed["wood"]["firewood"])
	var view2 = ViewScript.new()
	view2.table = f.table
	check(view2._fire_label({"state": 9, "burn": float(mixed["burn_left"])}, f.table.number_of("campfire_kit")) == "Campfire 00:40:00 Burn time", "the label adds the right time for each kind")
	view2.free()

	f._finish_writer()   # the background save thread must be done before quit, or the engine crashes at exit
	print("test_fire_fuel_tiers: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
