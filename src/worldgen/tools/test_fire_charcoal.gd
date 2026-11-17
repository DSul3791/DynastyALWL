extends SceneTree

# Charcoal left by burning wood (Dave 17 Nov 2026: "I shouldn't have to craft charcoal it should just automatically get left in the campfire as wood
# burns"; "anything that burns wood should leave behind charcoal"; cooking.json charcoal_left, server_items.gd _fire_leave_charcoal):
#   1. a lit campfire's firewood leaves charcoal_left Charcoal a piece (by burn time) in its own store, a log its share; sticks leave none;
#   2. charcoal is no campfire fuel: a store of only charcoal has no burn time, the store refuses it, and the charcoal left is never burned;
#   3. the charcoal outlasts the fire: coals, warm ash and cold ash keep it, the cold fire waits a day while it holds charcoal, goes once it is taken, or leaves it on the ground after the day;
#   3b. a half-burnt piece taken back out owes back its charcoal;
#   4. a store with no room: the charcoal lands on the ground beside the fire;
#   5. save and load keep the store's charcoal and the part-made lump;
#   6. a lit Fireplace and a Stone brazier drop charcoal at their foot by the fuel they burn; a Wall torch (sticks) drops none;
#   7. the campfire charcoal recipe (341) is retired: nothing crafts charcoal at a campfire.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_charcoal.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_fire_charcoal"
const HERE := Vector3(0.0, 10.0, 0.0)

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_notice = func(_p, t): said.append(str(t))
	s.send_chest = func(_p, _id, _b): pass
	s.ground_height = func(_x, _z): return 10.0
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	s.peer_connected_hello(1, "firecharcoal1")
	s.report_position(1, HERE)
	s.vitals_of(1)["weight"] = 5000.0
	return s


func n(id: String) -> int:
	return items.table.number_of(id)


# A lit campfire at `at` whose store holds `wood` ({item id: count}), as a placed fire is (its store is what burns).
func fire_at(at: Vector3, wood: Dictionary) -> int:
	var id: int = items._next_id
	items._next_id += 1
	items._items[id] = {"number": n("campfire_kit"), "count": 1, "pos": at, "left": 1.0e9, "fire": {"state": 9, "burn_left": 0.0, "wood": {"log": 0.0, "firewood": 0.0, "weak": 0.0}, "covered": true, "recheck": 1.0e6, "synced": true}}
	var fire: Dictionary = items._items[id]["fire"]
	var box = items._fire_store(fire)

	for wood_id in wood:
		box.add(n(str(wood_id)), int(wood[wood_id]))

	items._fire_apply_store(fire, box)
	fire["state"] = items._fire_best_state(fire)
	return id


func store(id: int):
	return items._chests[int(items._items[id]["fire"]["uid"])]


func charcoal_in(id: int) -> int:
	return store(id).count_of(n("charcoal"))


func burn(seconds: float, step: float = 10.0) -> void:
	for _i in range(int(ceil(seconds / step))):
		items._fires(step)


# Charcoal lying loose on the ground within `radius` of `at`.
func charcoal_near(at: Vector3, radius: float = 2.0) -> int:
	var total: int = 0

	for id in items._items:
		var it: Dictionary = items._items[id]

		if int(it["number"]) == n("charcoal") and not it.has("fire") and not it.has("struct") and (it["pos"] as Vector3).distance_to(at) <= radius:
			total += int(it["count"])

	return total


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	var cfg: Dictionary = items._cooking["charcoal_left"]
	var each_s: float = float(cfg["game_s_each"])
	var per_firewood: float = float(items._cooking["fuel"]["firewood"]) / each_s
	var per_log: float = float(items._cooking["fuel"]["log_oak"]) / each_s
	var firewood_s: float = float(items._cooking["fuel"]["firewood"]) / ItemsScript.GAME_RATE
	check(is_equal_approx(per_firewood, 3.0) and is_equal_approx(per_log, 27.0) and not (cfg["classes"] as Array).has("weak"), "charcoal_left: a Firewood leaves %.1f, a log %.1f, sticks and kindling none" % [per_firewood, per_log])

	# 1. Three firewood on a medium fire, burned through.
	var a: int = fire_at(HERE + Vector3(2.0, 0.0, 0.0), {"firewood": 3})
	check(int(items._items[a]["fire"]["state"]) == 1, "three firewood light a medium fire")
	burn(firewood_s * 0.5)
	check(charcoal_in(a) == int(floor(per_firewood * 0.5 + 0.0001)), "half a firewood burned: %d Charcoal already in the store" % charcoal_in(a))
	burn(firewood_s * 2.5 + 20.0)
	check(charcoal_in(a) == int(round(per_firewood * 3.0)) and store(a).count_of(n("firewood")) == 0, "three firewood burned leave %d Charcoal in the fire's store and no firewood (%d)" % [int(round(per_firewood * 3.0)), charcoal_in(a)])
	var log_fire: int = fire_at(HERE + Vector3(6.0, 0.0, 0.0), {"log_oak": 1})
	burn(float(items._cooking["fuel"]["log_oak"]) / ItemsScript.GAME_RATE + 30.0, 60.0)
	check(charcoal_in(log_fire) == int(round(per_log)), "one oak log burned leaves %d Charcoal (%d)" % [int(round(per_log)), charcoal_in(log_fire)])
	var sticks: int = fire_at(HERE + Vector3(10.0, 0.0, 0.0), {"stick": 6, "kindling": 4})
	burn(1200.0)
	check(not ItemsScript.fire_is_lit(int(items._items[sticks]["fire"]["state"])) and charcoal_in(sticks) == 0, "a fire of sticks and kindling burns out and leaves no charcoal")

	# 2. Charcoal is no campfire fuel.
	var only: int = fire_at(HERE + Vector3(14.0, 0.0, 0.0), {"charcoal": 10})
	check(float(items._items[only]["fire"]["burn_left"]) <= 0.0 and not items._fire_takes("charcoal"), "a store of only charcoal has no burn time, and the store takes no charcoal from the pack")
	var mixed: int = fire_at(HERE + Vector3(18.0, 0.0, 0.0), {"charcoal": 10, "firewood": 1})
	burn(firewood_s + 30.0)
	check(charcoal_in(mixed) == 10 + int(round(per_firewood)), "charcoal in a burning fire is not burned: 10 + %d after its firewood (%d)" % [int(round(per_firewood)), charcoal_in(mixed)])

	# 3. It outlasts the fire.
	check(int(items._items[a]["fire"]["state"]) == ItemsScript.FIRE_STATE_COALS, "the burnt-out medium fire is coals")

	for _stage in range(3):   # coals -> warm ash -> cold ash -> (stays)
		items._items[a]["left"] = 0.0
		items._expire_items(1.0)

	check(items._items.has(a) and int(items._items[a]["fire"]["state"]) == 8 and charcoal_in(a) == int(round(per_firewood * 3.0)), "coals, warm ash and cold ash keep the charcoal, and the cold fire stays while it holds it")
	items.report_position(1, items._items[a]["pos"] + Vector3(1.0, 0.0, 0.0))
	items.action(1, Net.ACT_CHEST_OPEN, a, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_TAKE, store(a).numbers.find(n("charcoal")), a, charcoal_in(a), Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(items.inventory_of(1).count_of(n("charcoal")) == int(round(per_firewood * 3.0)) and charcoal_in(a) == 0, "the player takes the charcoal from the fire's store")
	items._items[a]["left"] = 0.0
	items._expire_items(1.0)
	check(not items._items.has(a), "taken, the cold ash goes as before")
	var left_at: Vector3 = items._items[mixed]["pos"]
	var left_count: int = charcoal_in(mixed)

	for _stage in range(4):   # coals -> warm ash -> cold ash -> kept a day -> goes
		items._items[mixed]["left"] = 0.0
		items._expire_items(1.0)

	check(not items._items.has(mixed) and charcoal_near(left_at) == left_count, "charcoal never taken: after its day the fire goes and leaves the %d Charcoal on the ground (%d)" % [left_count, charcoal_near(left_at)])

	# 3b. A half-burnt firewood taken back out owes back the charcoal it made: no charcoal from wood that never burned.
	var owe: int = fire_at(HERE + Vector3(24.0, 0.0, 0.0), {"firewood": 1})
	burn(firewood_s * 0.5)
	var owe_box = store(owe)
	owe_box.remove(n("firewood"), 1)
	items._fire_apply_store(items._items[owe]["fire"], owe_box)
	owe_box.add(n("firewood"), 1)
	items._fire_apply_store(items._items[owe]["fire"], owe_box)
	items._items[owe]["fire"]["state"] = items._fire_best_state(items._items[owe]["fire"])
	burn(firewood_s + 30.0)
	check(charcoal_in(owe) == int(round(per_firewood)), "a firewood taken out half-burnt and put back leaves %d Charcoal in all, not more (%d)" % [int(round(per_firewood)), charcoal_in(owe)])

	# 4. No room in the store: it lands beside the fire.
	var slots_was: int = int(items._cooking["fire_slots"])
	items._cooking["fire_slots"] = 2
	var full: int = fire_at(HERE + Vector3(30.0, 0.0, 0.0), {"firewood": 2, "stone": 1})   # one firewood stays in its slot while the first burns
	burn(firewood_s + 30.0)
	check(charcoal_in(full) == 0 and charcoal_near(items._items[full]["pos"]) == int(round(per_firewood)), "a full store: the %d Charcoal land on the ground beside the fire (%d)" % [int(round(per_firewood)), charcoal_near(items._items[full]["pos"])])
	items._cooking["fire_slots"] = slots_was

	# 5. Save and load.
	var kept: int = fire_at(HERE + Vector3(40.0, 0.0, 0.0), {"firewood": 2})
	burn(firewood_s * 0.5)
	var part: float = float(items._items[kept]["fire"].get("char", 0.0))
	var had: int = charcoal_in(kept)
	var kept_at: Vector3 = items._items[kept]["pos"]
	check(part > 0.0 and had == 1, "half a firewood: one Charcoal made and %.2f of the next" % part)
	items.save()
	items._finish_writer()
	items = make_server()
	kept = 0

	for id in items._items:
		if items._items[id].has("fire") and (items._items[id]["pos"] as Vector3).distance_to(kept_at) < 0.1:
			kept = int(id)

	check(kept > 0 and charcoal_in(kept) == had and absf(float(items._items[kept]["fire"].get("char", 0.0)) - part) < 0.001, "save and load keep the store's Charcoal and the part-made lump")

	# 6. Lights that burn wood.
	var place: Vector3 = HERE + Vector3(60.0, 0.0, 0.0)
	var fireplace: int = items.dev_place("fireplace@%f,%f,0,lit" % [place.x, place.z])
	var brazier: int = items.dev_place("stone_brazier@%f,%f,0,lit" % [place.x + 6.0, place.z])
	var torch: int = items.dev_place("wall_torch@%f,%f,0,lit" % [place.x + 12.0, place.z])
	var fp_burn: float = items.light_burn_s(items._structures["fireplace"])
	var br_burn: float = items.light_burn_s(items._structures["stone_brazier"])

	for _i in range(int(ceil(fp_burn / 10.0))):   # the Fireplace burns one of its two Firewood; the brazier and the torch burn all they were lit with (twice one fuel)
		items._lights_tick(10.0)

	check(charcoal_near(items._items[fireplace]["pos"], 1.0) == int(round(per_firewood)), "a Fireplace that burned a Firewood leaves %d Charcoal at its foot (%d)" % [int(round(per_firewood)), charcoal_near(items._items[fireplace]["pos"], 1.0)])
	check(br_burn * 2.0 <= fp_burn and charcoal_near(items._items[brazier]["pos"], 1.0) == int(round(per_log * 2.0)), "a Stone brazier that burned its two logs leaves %d Charcoal (%d)" % [int(round(per_log * 2.0)), charcoal_near(items._items[brazier]["pos"], 1.0)])
	check(charcoal_near(items._items[torch]["pos"], 1.0) == 0, "a Wall torch (sticks) leaves none")

	# 7. No campfire recipe.
	var crafted: bool = false

	for number in items.recipes.numbers():
		var row: Dictionary = items.recipes.recipe(int(number))

		if items.table.number_of("charcoal") == int((row.get("gives", [0, 0]) as Array)[0]) and str(row.get("station", "")) == "campfire":
			crafted = true

	check(not crafted and items.recipes.recipe(341).is_empty(), "no recipe makes charcoal at a campfire (341 retired)")

	print("test_fire_charcoal: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	items._finish_writer()
	quit(1 if failures > 0 else 0)
