extends SceneTree

# A fire saved part-way through its burn loads with the same state, burn time, wood by class and laid pieces, keeps burning down from there,
# and a fire that was out stays out (Moderator 1 Nov 2026: fire saved and loaded mid-burn).
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_midburn_save.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const DIR := "user://test_fire_midburn_save"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), DIR)
	return items


func fires_of(f) -> Array:
	var out: Array = []

	for k in f._items:
		if f._items[k].has("fire"):
			out.append(f._items[k]["fire"])

	return out


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var table = ItemTableScript.load_default()
	var a = make()
	var rate: float = ItemsScript.GAME_RATE
	var cook: Dictionary = a._cooking
	var number: int = table.number_of("campfire_kit")

	var lit: Dictionary = {"state": 9, "burn_left": 0.0, "covered": false, "recheck": 0.0}

	for n in range(3):
		a._fire_add(lit, "log")

	a._fire_add(lit, "firewood")
	a._fire_add(lit, "stick")
	lit["state"] = a._fire_best_state(lit)
	a._fire_burn(lit, 1.5 * float(cook["fuel"]["log"]) / rate)   # part-way: one and a half logs gone
	a._items[900] = {"number": number, "count": 1, "pos": Vector3(5.0, 10.0, 5.0), "left": 1.0e9, "fire": lit}

	var out: Dictionary = {"state": 8, "burn_left": 0.0, "covered": false, "recheck": 0.0}
	a._items[901] = {"number": number, "count": 1, "pos": Vector3(40.0, 10.0, 40.0), "left": 1.0e9, "fire": out}
	var before_wood: Dictionary = a._fire_wood(lit).duplicate()
	var before_burn: float = float(lit["burn_left"])
	var before_state: int = int(lit["state"])
	var before_pieces: Dictionary = (lit["pieces"] as Dictionary).duplicate()
	a._dirty = true
	a.save()
	a._finish_writer()

	var b = make()
	var loaded: Array = fires_of(b)
	check(loaded.size() == 2, "both fires load (%d)" % loaded.size())

	var mid: Dictionary = {}
	var cold: Dictionary = {}

	for fire in loaded:
		if int(fire["state"]) == 8:
			cold = fire
		else:
			mid = fire

	check(not mid.is_empty(), "the burning fire loads")
	check(int(mid.get("state", 0)) == before_state, "same size of fire (%d)" % int(mid.get("state", 0)))
	check(absf(float(mid.get("burn_left", 0.0)) - before_burn) < 0.01, "same burn time left")
	var wood: Dictionary = b._fire_wood(mid)

	for cls in ["log", "firewood", "weak"]:
		check(absf(float(wood[cls]) - float(before_wood[cls])) < 0.01, "same %s burn seconds" % cls)

	check(mid.get("pieces", {}) == before_pieces, "same laid pieces: %s vs %s" % [str(mid.get("pieces", {})), str(before_pieces)])
	check(not cold.is_empty() and float(cold.get("burn_left", 1.0)) <= 0.0, "the out fire stays out")

	# It carries on from there: one more log burns off the loaded fire the same as it would have.
	var step: float = float(cook["fuel"]["log"]) / rate
	a._fire_burn(lit, step)
	b._fire_burn(mid, step)
	check(int(lit["state"]) == int(mid["state"]) and absf(float(lit["burn_left"]) - float(mid["burn_left"])) < 0.01, "after the load it burns down as the original does")

	# A second save of the loaded world is the same fire again (no drift through save, load, save, load).
	b._dirty = true
	b.save()
	b._finish_writer()
	var c = make()
	var again: Dictionary = {}

	for fire in fires_of(c):
		if int(fire["state"]) != 8:
			again = fire

	check(absf(float(again.get("burn_left", 0.0)) - float(mid["burn_left"])) < 0.01 and int(again.get("state", 0)) == int(mid["state"]), "save, load, save, load: no drift")

	print("test_fire_midburn_save: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
