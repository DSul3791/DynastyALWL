extends SceneTree

# The hunting loop, over server restarts (the coordinator, 23 Nov 2026): a kill trains Hunting and Tracking; the carcass lies where the
# animal fell, anyone may cut it, every knife tier cuts it, it gives its species' parts (data/items/carcass.json) into the pack; two players
# on one carcass share its parts with none made twice; a carcass, whole or half cut, is still there after a restart with what is left of
# it; it rots away in the end; the parts go on: hide to scraped hide (drying rack, scraper) to leather (tanning rack), heavy and fine
# leather; bone, sinew, fat, gut and antler each have a use; raw meat cooks to a roast that keeps longer.
#   godot --headless --path . --script res://src/worldgen/tools/test_hunting_loop.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ServerAnimals := preload("res://src/stream/server_animals.gd")

const DIR := "user://test_hunting_loop"
const KEY_A := "hunt-key-0000000a"
const KEY_B := "hunt-key-0000000b"

var failures: int = 0
var passes: int = 0
var clock: Array = [100.0 * 86400.0 + 12.0 * 3600.0]


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1

	print(("ok   " if ok else "FAIL ") + what)


func start(wipe: bool):
	DirAccess.make_dir_recursive_absolute(DIR)

	if wipe:
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + file)

		DirAccess.make_dir_recursive_absolute(DIR + "/world_items")

		for file in DirAccess.get_files_at(DIR + "/world_items"):
			DirAccess.remove_absolute(DIR + "/world_items/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return clock[0]
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, KEY_A)
	items.peer_connected_hello(2, KEY_B)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.report_position(2, Vector3(1.0, 10.0, 0.0))
	return items


func save(items) -> void:
	items._dirty = true
	items.save()
	items._finish_writer()


func skill(items, peer: int, name: String) -> float:
	return float(items._skill_records(peer).get(name, {}).get("p", 0.0))


func knife_in_hand(items, peer: int, knife: String) -> int:
	var inv = items.inventory_of(peer)
	var number: int = items.table.number_of(knife)

	if inv.numbers.find(number) < 0:
		items.give(peer, number, 1)

	return inv.numbers.find(number)


# Every blow until the carcass is gone (or `blows` of them), by `peer` with `knife`. Returns the blows struck.
func cut(items, peer: int, id: int, knife: String, blows: int = 99) -> int:
	var struck: int = 0
	var slot: int = knife_in_hand(items, peer, knife)
	if items._items.has(id):
		items.report_position(peer, items._items[id]["pos"] + Vector3(0.5, 0.0, 0.0))

	for n in blows:
		if not items._items.has(id):
			break

		items._last_process.clear()   # the blow cooldown is real time
		var before: int = int(items._items[id]["struct"].get("blows", 0))
		items._process_carcass(peer, items.inventory_of(peer), id, slot)

		if not items._items.has(id) or int(items._items[id]["struct"].get("blows", 0)) > before:
			struck += 1

	return struck


func counts(items, peer: int, ids: Array) -> Dictionary:
	var out: Dictionary = {}
	var inv = items.inventory_of(peer)

	for id in ids:
		out[id] = inv.count_of(items.table.number_of(id))

	return out


func carcasses(items, species: String = "") -> Array:
	var out: Array = []

	for id in items._items:
		var st: Dictionary = items._items[id].get("struct", {})

		if str(st.get("kind", "")) == "carcass" and (species == "" or str(st.get("species", "")) == species):
			out.append(id)

	return out


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/carcass.json"))
	var items = start(true)

	# Every species' parts are real items, and the big ones give plenty (Dave: "we are not gate keeping by limiting resources").
	var missing: Array = []

	for sp in cfg["species"]:
		for part in cfg["species"][sp].get("parts", []):
			if items.table.number_of(str(part[0])) == 0:
				missing.append("%s:%s" % [sp, part[0]])

	check(missing.is_empty(), "every part of every species is a real item (%s)" % str(missing))
	var deer_meat: Array = (cfg["species"]["deer"]["parts"] as Array).filter(func(p): return p[0] == "raw_meat")
	check(not deer_meat.is_empty() and int(deer_meat[0][1]) >= 8, "a deer gives 8 or more raw meat")

	# A kill: Hunting and Tracking train; the carcass lies where it fell.
	var h0: float = skill(items, 1, "hunting")
	var t0: float = skill(items, 1, "tracking")
	items._last_practice.clear()
	var deer: int = items.make_carcass("deer", Vector3(5.0, 10.0, 5.0), 1)
	check(items._items.has(deer) and str(items._items[deer]["struct"]["species"]) == "deer", "a deer killed leaves a deer carcass")
	# The animal's own body lies there (Dave 26 Nov 2026: not the hand-built one): its look, row number and the way it faced go with the carcass row and its save.
	var shot: Dictionary = ServerAnimals.dead_body_of({"id": 4321, "num": 102, "heading": 0.5})
	var own: int = items.make_carcass("deer", Vector3(7.0, 10.0, 5.0), -1, shot)
	var own_extra: Dictionary = items._struct_extra(items._items[own])
	check(int(own_extra.get("look", -1)) == 4321 and int(own_extra.get("num", 0)) == 102, "a carcass row names the dead animal's look and row number (%s)" % str(own_extra))
	check(absf(angle_difference(deg_to_rad(float(own_extra["yaw"])), -0.5 - PI * 0.5)) < 0.01, "and lies the way it faced (yaw %.1f)" % float(own_extra["yaw"]))
	var kept: Variant = JSON.parse_string(str(items._save_copy(own)["struct"]["state_json"]))
	check(kept is Dictionary and int(kept.get("look", -1)) == 4321 and int(kept.get("num", 0)) == 102, "and its save keeps them (%s)" % str(kept))
	check(not items._struct_extra(items._items[deer]).has("look"), "a carcass with no animal named (admin, trap) sends no look")
	check(skill(items, 1, "hunting") > h0 and skill(items, 1, "tracking") > t0, "the kill trains Hunting (%.1f -> %.1f) and Tracking (%.1f -> %.1f)" % [h0, skill(items, 1, "hunting"), t0, skill(items, 1, "tracking")])

	# Every knife tier cuts a rabbit up.
	var knives: Array = []

	for id in items.table._by_id:
		if str(items.table.entry(id).get("tool_class", "")) == "knife":
			knives.append(id)

	var all_cut: Array = []

	for knife in knives:
		var rabbit: int = items.make_carcass("rabbit", Vector3(20.0, 10.0, 20.0), -1)
		var meat0: int = items.inventory_of(1).count_of(items.table.number_of("raw_meat"))
		cut(items, 1, rabbit, knife)

		if not items._items.has(rabbit) and items.inventory_of(1).count_of(items.table.number_of("raw_meat")) > meat0:
			all_cut.append(knife)

	check(knives.size() >= 6 and all_cut.size() == knives.size(), "every knife tier cuts a carcass up (%s of %s)" % [str(all_cut), str(knives)])

	# The deer, cut whole by one player: its parts in the rolled amounts.
	var parts: Array = ["raw_meat", "hide", "bone", "sinew", "animal_fat", "antler", "gut"]
	var a0: Dictionary = counts(items, 1, parts)
	var blows: int = cut(items, 1, deer, "stone_knife")
	var a1: Dictionary = counts(items, 1, parts)
	check(blows == int(cfg["species"]["deer"].get("blows", cfg["blows"])) and not items._items.has(deer), "a deer takes %d blows (%d)" % [int(cfg["species"]["deer"].get("blows", cfg["blows"])), blows])
	var got_all: bool = true

	for part in cfg["species"]["deer"]["parts"]:
		var gain: int = int(a1[str(part[0])]) - int(a0[str(part[0])])
		got_all = got_all and gain >= mini(int(part[1]), 1)

	check(got_all, "and gives every part it lists (%s)" % str(parts.map(func(p): return "%s %d" % [p, int(a1[p]) - int(a0[p])])))

	# Two players on one carcass: anyone may cut; the parts are shared out, none made twice.
	var boar: int = items.make_carcass("boar", Vector3(40.0, 10.0, 40.0), 1)
	var b_a0: Dictionary = counts(items, 1, parts)
	var b_b0: Dictionary = counts(items, 2, parts)
	cut(items, 1, boar, "stone_knife", 1)
	var rolled: Array = (items._items[boar]["struct"]["parts"] as Array).duplicate(true) if items._items.has(boar) else []
	var given_first: Dictionary = counts(items, 1, parts)
	cut(items, 2, boar, "bronze_knife", 1)
	cut(items, 1, boar, "stone_knife")
	cut(items, 2, boar, "bronze_knife")
	var b_a1: Dictionary = counts(items, 1, parts)
	var b_b1: Dictionary = counts(items, 2, parts)
	var total_ok: bool = not items._items.has(boar)
	var shared: bool = false

	for part in ["raw_meat", "hide", "bone"]:
		var first_blow: int = int(given_first[part]) - int(b_a0[part])
		var left_after: int = 0

		for r in rolled:
			if str(r[0]) == part:
				left_after = int(r[1])

		var got: int = (int(b_a1[part]) - int(b_a0[part])) + (int(b_b1[part]) - int(b_b0[part]))
		total_ok = total_ok and got == first_blow + left_after
		shared = shared or int(b_b1[part]) > int(b_b0[part])

	check(total_ok and shared, "two players cut one boar: each gets a share and the parts add up to its roll, none twice")

	# A restart while a carcass lies whole, and one half cut: both are still there with what is left of them.
	var moose: int = items.make_carcass("moose", Vector3(60.0, 10.0, 60.0), 1)
	check(moose != 0, "a moose carcass is laid")
	var elk: int = items.make_carcass("elk", Vector3(80.0, 10.0, 80.0), 1)
	cut(items, 1, elk, "stone_knife", 1)
	var elk_left: Array = (items._items[elk]["struct"]["parts"] as Array).duplicate(true)
	var elk_blows: int = int(items._items[elk]["struct"]["blows"])
	var elk_life: float = float(items._items[elk]["left"])
	save(items)
	items = start(false)
	var moose_back: Array = carcasses(items, "moose")
	var elk_back: Array = carcasses(items, "elk")
	check(moose_back.size() == 1 and int(items._items[moose_back[0]]["struct"].get("blows", 0)) == 0, "after a restart the whole moose is still there")
	check(elk_back.size() == 1 and int(items._items[elk_back[0]]["struct"].get("blows", 0)) == elk_blows and str(items._items[elk_back[0]]["struct"].get("parts", [])) == str(elk_left), "and the half cut elk with its blows and the parts still in it (%s)" % (str(items._items[elk_back[0]]["struct"]) if elk_back.size() == 1 else "gone"))
	check(elk_back.size() == 1 and absf(float(items._items[elk_back[0]]["left"]) - elk_life) < 60.0, "keeping its time left to rot")

	if elk_back.size() == 1:
		var e0: Dictionary = counts(items, 1, parts)
		cut(items, 1, elk_back[0], "stone_knife")
		var e1: Dictionary = counts(items, 1, parts)
		var meat_left: int = 0

		for r in elk_left:
			if str(r[0]) == "raw_meat":
				meat_left = int(r[1])

		check(int(e1["raw_meat"]) - int(e0["raw_meat"]) == meat_left, "cut up after the restart it gives the rest and no more (%d raw meat)" % (int(e1["raw_meat"]) - int(e0["raw_meat"])))

	# It rots away in the end.
	if moose_back.size() == 1:
		items._expire_items(float(items._items[moose_back[0]]["left"]) + 1.0)
		check(not items._items.has(moose_back[0]), "a carcass left long enough rots away")

	# The parts go on.
	var rec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))
	rec = rec.get("recipes", rec)
	var uses: Callable = func(item: String) -> Array:
		return rec.keys().filter(func(k): return typeof(rec[k]) == TYPE_DICTIONARY and (rec[k].get("needs", []) as Array).any(func(n): return str(n[0]) == item))
	var made_by: Callable = func(item: String) -> Array:
		return rec.keys().filter(func(k): return typeof(rec[k]) == TYPE_DICTIONARY and typeof(rec[k].get("gives", null)) == TYPE_ARRAY and str(rec[k]["gives"][0]) == item)
	var scraped: Array = made_by.call("processed_hide")
	check(not scraped.is_empty() and str(rec[scraped[0]].get("station", "")) == "drying_rack" and str(rec[scraped[0]]["needs"][0][0]) == "hide", "a hide is scraped on the drying rack")
	var leather: Array = made_by.call("leather")
	check(not leather.is_empty() and str(rec[leather[0]].get("station", "")) == "tanning_rack" and (rec[leather[0]]["needs"] as Array).any(func(n): return str(n[0]) == "processed_hide"), "and tanned to leather on the tanning rack")
	var gathered: String = FileAccess.get_file_as_string("res://data/items/gathered.json")
	check(gathered.contains("\"tannin_bark\""), "the tannin bark it needs is gathered")
	check(not made_by.call("heavy_leather").is_empty() and not made_by.call("fine_leather").is_empty(), "heavy and fine leather are made from it")

	for part in ["hide", "leather", "bone", "sinew", "animal_fat", "gut", "antler", "raw_meat"]:
		check(not uses.call(part).is_empty(), "%s has a use (%s)" % [part, str(uses.call(part).slice(0, 3))])

	var cooking: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
	check(str(JSON.stringify(cooking)).contains("\"raw_meat\":\"roast_meat\"") and float(cooking.get("cooked_life_mult", 2.0)) > 1.0, "raw meat roasts to a roast that keeps longer")

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
