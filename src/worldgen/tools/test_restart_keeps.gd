extends SceneTree

# What a restart used to lose is kept, and the live build's files (9257, main a27c98df) still load (live server restart for the 25 Nov update):
#   a Smithy's part-burnt fuel unit (smithies.json "fuel"), a lit light's part-made Charcoal (lights.json row [4]), who lit a burning Kiln
#   (kilns.json row [3], ADD-18 credit) and cold ash that already gave its charcoal one wait (world item fire row [18]).
# The old files are this build's own, with the new values taken out: build 9257 wrote exactly those shapes (lights rows of 4 values, kilns rows
# of 3, smithies.json with only "smithies", fire rows of 18 values).
#   godot --headless --path . --script res://src/worldgen/tools/test_restart_keeps.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const KEY := "abcdef123456"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir + "/" + ItemsScript.AREA_DIR)

	for sub in [dir, dir + "/" + ItemsScript.AREA_DIR]:
		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)


func read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func write(path: String, data: Variant) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func find(items, kind: String) -> Dictionary:
	for id in items._items:
		var it: Dictionary = items._items[id]

		if (kind == "fire" and it.has("fire")) or (it.has("struct") and str(it["struct"].get("kind", "")) == kind):
			return {"id": id, "it": it}

	return {}


func _init() -> void:
	var dir: String = "user://test_restart_keeps"
	wipe(dir)
	var a = make(dir)
	var stone: int = a.table.number_of("stone")
	var smithy_id: int = a._next_id
	a._items[smithy_id] = {"number": a.table.number_of("blacksmithy"), "count": 1, "pos": Vector3(20.0, 10.0, 20.0), "left": 1.0e9, "struct": {"kind": "blacksmithy", "yaw": 0.0, "uid": 901, "fuel_left": 1234.5}}
	a._smithies.burning[smithy_id] = true
	a._next_id += 1
	a._items[a._next_id] = {"number": a.table.number_of("stone_brazier"), "count": 1, "pos": Vector3(24.0, 10.0, 20.0), "left": 1.0e9, "struct": {"kind": "stone_brazier", "yaw": 0.0, "lit": true, "fuel_left": 300.0, "char": 0.625}}
	a._next_id += 1
	var kiln_id: int = a._next_id
	a._items[kiln_id] = {"number": a.table.number_of("kiln"), "count": 1, "pos": Vector3(28.0, 10.0, 20.0), "left": 1.0e9, "struct": {"kind": "kiln", "yaw": 0.0, "uid": 902, "lit": true, "kiln": {"left": 20, "t": 1.0}}}
	a._kiln_lit_by[kiln_id] = KEY
	a._next_id += 1
	a._items[a._next_id] = {"number": stone, "count": 1, "pos": Vector3(32.0, 10.0, 20.0), "left": 5000.0, "fire": {"state": 8, "burn_left": 0.0, "recheck": 0.0, "covered": false, "kept": true}}
	a._next_id += 1
	a._dirty = true
	a.save()
	a._finish_writer()

	# The new files bring all four back.
	var b = make(dir)
	var smithy: Dictionary = find(b, "blacksmithy")
	var light: Dictionary = find(b, "stone_brazier")
	var kiln: Dictionary = find(b, "kiln")
	var fire: Dictionary = find(b, "fire")
	check(not smithy.is_empty() and is_equal_approx(float(smithy["it"]["struct"].get("fuel_left", 0.0)), 1234.5) and b._smithies.burning.has(smithy["id"]), "the Smithy's part-burnt unit is kept (1234.5 s)")
	check(not light.is_empty() and bool(light["it"]["struct"].get("lit", false)) and is_equal_approx(float(light["it"]["struct"].get("char", 0.0)), 0.625), "the lit brazier keeps its part-made Charcoal (0.625)")
	check(not kiln.is_empty() and str(b._kiln_lit_by.get(kiln["id"], "")) == KEY, "the burning Kiln still knows who lit it")
	check(not fire.is_empty() and bool(fire["it"]["fire"].get("kept", false)), "the cold ash keeps that its charcoal wait is spent")
	b._finish_writer()

	# Build 9257's files: the same, without the new values.
	var smithies: Dictionary = read(dir + "/smithies.json")
	smithies.erase("fuel")
	write(dir + "/smithies.json", smithies)
	var lights: Dictionary = read(dir + "/lights.json")

	for row in lights["lit"]:
		row.resize(4)

	write(dir + "/lights.json", lights)
	var kilns: Dictionary = read(dir + "/kilns.json")

	for uid in kilns["kilns"]:
		kilns["kilns"][uid].resize(3)

	write(dir + "/kilns.json", kilns)
	var cut_fires: int = 0

	for file in DirAccess.get_files_at(dir + "/" + ItemsScript.AREA_DIR):
		if not file.ends_with(".json"):
			continue

		var area: Dictionary = read(dir + "/" + ItemsScript.AREA_DIR + "/" + file)

		for row in area.get("items", []):
			if row.size() > 18 and typeof(row[9]) != TYPE_STRING:   # a fire row (a structure's [9] is its kind)
				row.resize(18)
				cut_fires += 1

		write(dir + "/" + ItemsScript.AREA_DIR + "/" + file, area)

	check(cut_fires == 1, "the fire row was cut back to build 9257's 18 values (%d)" % cut_fires)
	var c = make(dir)
	smithy = find(c, "blacksmithy")
	light = find(c, "stone_brazier")
	kiln = find(c, "kiln")
	fire = find(c, "fire")
	check(not smithy.is_empty() and not smithy["it"]["struct"].has("fuel_left") and c._smithies.burning.is_empty(), "a 9257 smithies.json loads: the Smithy starts its next unit, as before")
	check(not light.is_empty() and bool(light["it"]["struct"].get("lit", false)) and is_equal_approx(float(light["it"]["struct"].get("fuel_left", 0.0)), 300.0) and not light["it"]["struct"].has("char"), "a 9257 lights.json loads: lit, 300 s of fuel, no part lump")
	check(not kiln.is_empty() and bool(kiln["it"]["struct"].get("lit", false)) and int(kiln["it"]["struct"].get("kiln", {}).get("left", 0)) == 20 and not c._kiln_lit_by.has(kiln["id"]), "a 9257 kilns.json loads: lit with 20 left, lighter unknown")
	check(not fire.is_empty() and int(fire["it"]["fire"]["state"]) == 8 and not fire["it"]["fire"].has("kept"), "a 9257 fire row loads: cold ash, no kept flag")
	c._finish_writer()

	print("restart keeps: %d failures" % failures)
	quit(1 if failures > 0 else 0)
