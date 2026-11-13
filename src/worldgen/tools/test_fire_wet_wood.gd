extends SceneTree

# Wet wood (docs/design/fire_coals_design.md, step 3; coordinator decision 8 Nov 2026, Dave may revert): a loose stick in rain 0.5 is wet for 4
# game hours and dries in 4; a log needs 168; wet and dry stacks do not join, and a join keeps the wetter; wet kindling lights at half the
# chance, and normally with dry tinder in the fire; a wet firewood fire burns 1.5 times as long at small-fire heat and smokes, then comes up to
# its size once dry; wood in a lit fire's store dries 6 times as fast; a pack in the rain keeps its wood dry.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_wet_wood.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_fire_wet_wood"
const AT := Vector3(2.0, 10.0, 0.0)

var failures: int = 0
var rain: float = 0.0
var roof: float = 0.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(key: String):
	var f = ItemsScript.new()
	f.send_full = func(_p, _b): pass
	f.send_slots = func(_p, _b): pass
	f.send_world_items = func(_p, _a, _r): pass
	f.send_notice = func(_p, _t): pass
	f.setup(ItemTableScript.load_default(), DIR)
	f.ground_height = func(_x, _z): return 10.0
	f.rain_now = func(): return rain
	f.cover_at = func(_p): return roof
	f.peer_connected_hello(1, key)
	f._characters[f._peer_key[1]]["grace_s"] = 0.0
	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	return f


# Time passes as the item tick runs it: fires, item lifetimes, wet wood.
func run(f, seconds: float, dt: float) -> void:
	var t: float = 0.0

	while t < seconds - 0.0001:
		var step: float = minf(dt, seconds - t)
		f._fires(step)
		f._expire_items(step)
		f._wood_tick(step)
		t += step


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var f = make("firewetwood01")
	var table = f.table
	var cfg: Dictionary = table.wet_wood()
	var stick: int = table.number_of("stick")
	var beech: int = table.number_of("log_beech")
	var wet_h: Dictionary = cfg.get("wet_h", {})
	# JSON numbers load as floats, and a Dictionary == compares 4.0 and 4 as different, so the hours are compared one by one.
	check(wet_h.size() == 3 and is_equal_approx(float(wet_h.get("weak", -1.0)), 4.0) and is_equal_approx(float(wet_h.get("firewood", -1.0)), 36.0)
			and is_equal_approx(float(wet_h.get("log", -1.0)), 168.0), "cooking.json wet_wood: sticks 4 h, firewood 36 h, logs 168 h (%s)" % str(wet_h))
	check(table.wood_class(stick) == "weak" and table.wood_class(beech) == "log" and table.wood_class(table.number_of("apple")) == "", "the item table knows which items are wood")

	# 1. A loose stick in rain 0.5 is wet for 4 game hours, and out of the rain dries in 4 (600 real s); a log needs 168 game hours.
	f._items[950] = {"number": stick, "count": 1, "pos": Vector3(30.0, 10.0, 30.0), "left": 1.0e9, "wear": 0}
	f._items[951] = {"number": beech, "count": 1, "pos": Vector3(34.0, 10.0, 30.0), "left": 1.0e9, "wear": 0}
	rain = 0.5
	run(f, 15.0, 5.0)
	check(int(f._items[950]["wear"]) == 40, "a loose stick in the rain is wet for 4 game hours (%d)" % int(f._items[950]["wear"]))
	check(int(f._items[951]["wear"]) == 1680, "a loose log is wet for 168 (%d)" % int(f._items[951]["wear"]))
	rain = 0.0
	run(f, 585.0, 5.0)
	check(int(f._items[950]["wear"]) > 0, "not dry before 4 game hours (%d)" % int(f._items[950]["wear"]))
	run(f, 20.0, 5.0)
	check(int(f._items[950]["wear"]) == 0, "dry after 4 game hours (%d)" % int(f._items[950]["wear"]))
	check(int(f._items[951]["wear"]) > 1600, "the log is still wet (%d)" % int(f._items[951]["wear"]))
	f._items.erase(950)
	f._items.erase(951)

	# 2. Wet and dry stacks do not join; a join within 2 game hours keeps the wetter.
	var inv = InventoryScript.new()
	inv.table = table
	inv.add(stick, 3, 40)
	inv.add(stick, 3, 0)
	check(inv.numbers.count(stick) == 2, "a wet and a dry stack of sticks stay apart")
	inv.add(stick, 2, 30)
	var wet_slot: int = -1

	for slot in inv.slot_count:
		if inv.numbers[slot] == stick and inv.wear[slot] > 0:
			wet_slot = slot

	check(inv.numbers.count(stick) == 2 and wet_slot >= 0 and inv.counts[wet_slot] == 5 and inv.wear[wet_slot] == 40, "a stack 1 game hour drier joins the wet one and keeps the wetter")

	# 3. Kindling that is all wet lights at half the chance; dry tinder in the fire lights it as usual.
	f.action(1, Net.ACT_ADMIN_GIVE, table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, f.inventory_of(1).numbers.find(table.number_of("campfire_kit")), 0, 0, AT)
	var id: int = 0

	for k in f._items:
		if f._items[k].has("fire"):
			id = k

	var fire: Dictionary = f._items[id]["fire"] if id != 0 else {}
	check(bool(fire.get("synced", false)) and float(fire.get("burn_left", 0.0)) > 0.0, "a placed fire holds its first stick in its store")
	var box = f._chests[int(fire["uid"])]
	rain = 0.5
	run(f, 15.0, 5.0)
	rain = 0.0
	check(int(fire.get("damp", 0)) == 40, "rain on the laid fire wets the stick in its store (%d)" % int(fire.get("damp", 0)))
	var wet_lit: int = 0

	for _n in 40:
		fire["state"] = 9
		f.action(1, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
		wet_lit += 1 if ItemsScript.fire_is_lit(int(fire["state"])) else 0

	check(wet_lit > 5 and wet_lit < 35, "wet kindling lights about half the time (%d of 40)" % wet_lit)
	box.add(table.number_of(str(f._cooking.get("tinder", "plant_fibre"))), 1)
	var tinder_lit: int = 0

	for _n in 40:
		fire["state"] = 9
		f.action(1, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
		tinder_lit += 1 if ItemsScript.fire_is_lit(int(fire["state"])) else 0

	check(tinder_lit == 40, "with dry tinder in it, it lights every time (%d of 40)" % tinder_lit)

	# 4. Wood in a lit fire's store dries 6 times as fast as in an unlit one under a roof.
	fire["state"] = ItemsScript.FIRE_STATE_SURVIVAL
	var lit_before: int = int(box.wear[box.numbers.find(stick)])
	run(f, 30.0, 5.0)
	var lit_dried: int = lit_before - int(box.wear[box.numbers.find(stick)])
	check(lit_dried == 12, "two drying steps in a lit fire's store take 12 tenths (%d)" % lit_dried)
	f._put_out_fire(1, id)
	roof = 2.0
	var laid_before: int = int(box.wear[box.numbers.find(stick)])
	run(f, 30.0, 5.0)
	check(laid_before - int(box.wear[box.numbers.find(stick)]) == 2, "and 2 in a laid fire under a roof (%d)" % (laid_before - int(box.wear[box.numbers.find(stick)])))
	roof = 0.0
	f._items.erase(id)

	# 5. A wet firewood fire (3 pieces, a medium fire when dry) burns 1.5 times as long at small-fire heat and smokes; dry, it is medium again.
	var wf: Dictionary = {"state": 9, "burn_left": 0.0, "covered": false, "recheck": 0.0}

	for _n in 3:
		f._fire_add(wf, "firewood", 360)

	f._items[952] = {"number": table.number_of("campfire_kit"), "count": 1, "pos": Vector3(60.0, 10.0, 0.0), "left": 1.0e9, "fire": wf}
	wf["state"] = f._fire_best_state(wf)
	var start: float = float(wf["burn_left"])
	check(int(wf["state"]) == ItemsScript.FIRE_STATE_SURVIVAL, "wet firewood lights a tier low, at small-fire heat (state %d)" % int(wf["state"]))
	run(f, 600.0, 1.0)
	check(absf(start - float(wf["burn_left"]) - 400.0) < 2.0, "it burns 1.5 times as long (%.0f s burned in 600)" % (start - float(wf["burn_left"])))
	check(int(f._fire_extra(f._items[952]).get("smoke", 0)) == 1, "and smokes")
	run(f, 330.0, 1.0)
	check(int(wf.get("damp", 0)) == 0 and int(wf["state"]) == 1, "dried by the fire it comes up to a medium fire (state %d, damp %d)" % [int(wf["state"]), int(wf.get("damp", 0))])
	check(not f._fire_extra(f._items[952]).has("smoke"), "and stops smoking")
	f._items.erase(952)

	# 6. A pack in the rain keeps its wood dry.
	f.action(1, Net.ACT_ADMIN_GIVE, stick, 0, 5, Vector3.ZERO)
	rain = 0.9
	run(f, 60.0, 5.0)
	rain = 0.0
	var pack = f.inventory_of(1)
	var pack_wet: bool = false

	for slot in pack.slot_count:
		pack_wet = pack_wet or (pack.numbers[slot] == stick and pack.wear[slot] > 0)

	check(not pack_wet, "sticks in the pack stay dry in the rain")

	print("test_fire_wet_wood: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
