extends SceneTree

# Build 9257 saves load on today's code (coordinator, 23 Nov 2026: the next package installs over the live world, saved by build 9257, main
# a27c98df). save_fixtures/build_9257 holds the item files of a store a real 9257 server and bots wrote, with 9257 code then adding
# three characters (packs, worn pieces, every skill, one trained), every placeable structure, blueprint sites part filled and built, every
# one of its 1,507 items in a store or on the ground, crops in planters and fires (build_9257.gd.txt made it, snapshot.gd.txt read it).
# expected_snapshot.json is what 9257 code read from it after every character joined and left. Today's code must read the same: every
# item by id in every pack, worn place, store and on the ground, every structure and site, every crop, and every skill's value and cap.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_9257.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const SkillWeb := preload("res://src/shared/skill_web.gd")
const FIXTURE := "res://src/worldgen/tools/save_fixtures/build_9257"
const DIR := "user://test_save_9257"
const NEW_SKILLS := ["hand_to_hand", "spear"]   # skills.json skills added since 9257

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func copy_fixture() -> void:
	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(DIR + sub)

		for file in DirAccess.get_files_at(DIR + sub):
			DirAccess.remove_absolute(DIR + sub + "/" + file)

	for sub in ["", "/world_items"]:
		for file in DirAccess.get_files_at(FIXTURE + sub):
			if file.ends_with(".json") and file != "expected_snapshot.json":
				var to: String = DIR + ("/" + ItemsScript.AREA_DIR if sub != "" else "") + "/" + file
				var f: FileAccess = FileAccess.open(to, FileAccess.WRITE)
				f.store_string(FileAccess.get_file_as_string(FIXTURE + sub + "/" + file))
				f.close()


func boot():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 6.0
	items.setup(ItemTableScript.load_default(), DIR)
	return items


func slots(table, inv) -> Array:
	var out: Array = []

	for s in inv.slot_count:
		if inv.numbers[s] != 0:
			out.append("%s x%d w%d" % [idn(table, inv.numbers[s]), inv.counts[s], inv.wear[s]])

	out.sort()
	return out


func idn(table, number: int) -> String:
	return table.id_of(number) if table.id_of(number) != "" else "#%d" % number


# The same reading as save_fixtures/build_9257/snapshot.gd.txt (run on 9257 code to make expected_snapshot.json), after every character
# has joined and left.
func snapshot(items) -> Dictionary:
	var table = items.table
	var peer: int = 500

	for key in items._characters.keys():
		items.peer_connected_hello(peer, key)
		items.report_position(peer, Vector3(58167.0, 6.0, 71364.0))
		items.tick(0.25)
		items.peer_left(peer)
		peer += 1

	var snap: Dictionary = {"characters": {}, "packs": {}, "worn": {}, "structs": {}, "ground": {}, "stores": {}, "crops": {}, "trees": 0, "fires": {}, "sites": {}}
	var cfg: Dictionary = SkillWeb.config()

	for key in items._characters:
		var c: Dictionary = items._characters[key]
		var sk: Dictionary = {}

		for s in c.get("skills", {}):
			var row: Variant = c["skills"][s]
			sk[s] = snappedf(float(row.get("p", 0.0)) if row is Dictionary else float(row), 0.001)

		var eff: Dictionary = {}

		for s in cfg["skills"]:
			var v: float = SkillWeb.effective(cfg, str(s), c.get("skills", {}))

			if v > 1.0001:
				eff[s] = "%.2f cap %d" % [v, SkillWeb.cap_of(cfg, str(s), c.get("skills", {}))]

		snap["characters"][key] = {"effective": eff, "skills": sk, "purse": c.get("purse", {}), "learned": (c.get("learned", {}) as Dictionary).keys(), "last": c.get("last", {}).get("pos", []), "stats": [c.get("fitness"), c.get("dexterity"), c.get("perception"), c.get("luck")]}
		var worn: Array = []

		for w in c.get("worn", []):
			if int(w[0]) != 0:
				var bag: Array = []
				var inst: Variant = w[3] if w.size() > 3 else {}

				if inst is Dictionary and inst.has("bag"):
					bag = [str(inst["bag"]).length()]

				worn.append("%s w%d %s" % [idn(table, int(w[0])), int(w[2]), str(bag)])

		snap["worn"][key] = worn

	for key in items._inventories:
		snap["packs"][key] = slots(table, items._inventories[key])

	for id in items._items:
		var it: Dictionary = items._items[id]
		var where: String = "%d,%d" % [roundi(it["pos"].x * 10.0), roundi(it["pos"].z * 10.0)]

		if it.has("tree"):
			snap["trees"] += 1
		elif it.has("fire"):
			snap["fires"][where] = {"state": int(it["fire"]["state"]), "burn_left": snappedf(float(it["fire"].get("burn_left", 0.0)), 1.0), "number": idn(table, int(it["number"]))}

			if items._chests.has(int(it["fire"].get("uid", 0))):
				snap["stores"]["fire@" + where] = slots(table, items._chests[int(it["fire"]["uid"])])
		elif it.has("struct"):
			var st: Dictionary = it["struct"]
			var k: String = str(st["kind"]) + "@" + where
			snap["structs"][k] = {"number": idn(table, int(it["number"])), "owner": str(st.get("owner", "")), "wear": int(it.get("wear", 0)), "fields": st.keys().filter(func(f): return not ["yaw", "uid", "born", "seq"].has(f))}

			if st.has("site"):
				snap["sites"][k] = st["site"].get("have", {})

			if items._chests.has(int(st.get("uid", 0))):
				snap["stores"][k] = slots(table, items._chests[int(st["uid"])])
		else:
			var gk: String = idn(table, int(it["number"]))
			snap["ground"][gk] = int(snap["ground"].get(gk, 0)) + int(it["count"])

	for key in items._crops:
		snap["crops"][key] = [str(items._crops[key]["crop"]), snappedf(float(items._crops[key]["age"]), 0.01)]

	return JSON.parse_string(JSON.stringify(snap))   # the same number types as the file it is compared with


# Every item id held in a pack, a store or on the ground.
func kinds_in(snap: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for part in ["packs", "stores"]:
		for k in snap[part]:
			for row in snap[part][k]:
				out[str(row).get_slice(" x", 0)] = true

	for k in snap["ground"]:
		if k != "#0":   # world records with no item (a loose log's or a carcass's own row)
			out[k] = true

	return out


# Every difference between what 9257 read and what this code reads, as lines.
func differences(a: Variant, b: Variant, path: String, out: Array) -> void:
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				out.append("lost %s/%s" % [path, k])
			else:
				differences(a[k], b[k], path + "/" + str(k), out)

		for k in b:
			if not a.has(k):
				out.append("new %s/%s: %s" % [path, k, str(b[k]).left(120)])
	elif a is Array and b is Array and (a + b).all(func(e): return e is String):
		for e in a:
			if not b.has(e):
				out.append("lost %s: %s" % [path, e])

		for e in b:
			if not a.has(e):
				out.append("new %s: %s" % [path, e])
	elif a != b:
		out.append("changed %s: %s -> %s" % [path, str(a).left(120), str(b).left(120)])


# Seeds are counted one by one since 23 Nov 2026 (#1628): a 9257 seed comes back as today's pinch (crops.json sow_seeds, old_seed_units),
# once, so what 9257 read is put in today's units before it is compared (test_save_9257_life.gd checks the counting itself).
func in_todays_seeds(snap: Dictionary, table) -> void:
	var crops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))
	var per: Dictionary = {}

	for crop in crops["crops"]:
		if int(crops["crops"][crop].get("sow_seeds", 1)) > 1:
			per[str(crops["crops"][crop].get("seed", ""))] = int(crops["crops"][crop]["sow_seeds"])

	for id in crops.get("old_seed_units", {}):
		if not str(id).begins_with("_"):
			per[str(id)] = int(crops["old_seed_units"][id])

	for k in snap["ground"]:
		snap["ground"][k] = float(snap["ground"][k]) * float(per.get(str(k), 1))

	for part in ["packs", "stores"]:
		for k in snap[part]:
			var rows: Array = []

			for row in snap[part][k]:
				var id: String = str(row).get_slice(" x", 0)
				var count: int = int(str(row).get_slice(" x", 1).get_slice(" ", 0))
				rows.append("%s x%d %s" % [id, count * int(per.get(id, 1)), str(row).get_slice(" ", str(row).get_slice_count(" ") - 1)] if per.has(id) else row)

			rows.sort()
			snap[part][k] = rows


func _init() -> void:
	copy_fixture()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE + "/expected_snapshot.json"))
	var items = boot()
	in_todays_seeds(expected, items.table)
	var got: Dictionary = snapshot(items)
	var out: Array = []
	differences(expected, got, "", out)
	# What may differ: the raw practice in a trained character's records (lifted once so they read as before, checked by value below), and
	# skills that did not exist in 9257 (they read from their family's floor like every other).
	out = out.filter(func(line: String) -> bool: return not line.contains("/skills/") and not NEW_SKILLS.any(func(s): return line.begins_with("new /characters/") and line.contains("/effective/%s:" % s)))

	for line in out.slice(0, 40):
		print("  ", line)

	check(out.is_empty(), "a build 9257 store reads the same on today's code (%d differences)" % out.size())
	var kinds_then: Dictionary = kinds_in(expected)
	var kinds_now: Dictionary = kinds_in(got)
	check(kinds_then.size() > 1000 and kinds_now.size() == kinds_then.size() and not kinds_now.keys().any(func(k): return str(k).begins_with("#")), "every item kind the 9257 store holds is still an item, by its id (%d kinds, %d then)" % [kinds_now.size(), kinds_then.size()])

	# The trained character (Trades once, Athletics twice under the 9257 rule, a floor 5 over the band) keeps what its skills read:
	# Fighting under Athletics 55, Crafting under Trades 30, not today's band floors 50 and 25.
	var cfg: Dictionary = SkillWeb.config()
	var trained: Dictionary = items._characters["fixture9257c03"]["skills"]
	check(is_equal_approx(snappedf(SkillWeb.effective(cfg, "fighting", trained), 0.01), 55.0) and is_equal_approx(snappedf(SkillWeb.effective(cfg, "crafting", trained), 0.01), 30.0), "a 9257 training keeps its old floor in the family (Fighting %.2f, Crafting %.2f)" % [SkillWeb.effective(cfg, "fighting", trained), SkillWeb.effective(cfg, "crafting", trained)])
	check(int(items._characters["fixture9257c03"].get("skills_v", 0)) == 3, "the character is marked as read under today's rule (skills_v 3)")

	# Saved and read again: nothing moves a second time.
	var before: Dictionary = got["characters"]
	items.save()
	items._finish_writer()
	var again = boot()
	var after: Dictionary = snapshot(again)
	var out2: Array = []
	differences(before, after["characters"], "/characters", out2)
	check(out2.is_empty(), "saved and read again, every skill reads the same (%s)" % str(out2.slice(0, 5)))

	# A character trained under today's rule (skills_v 3) is not lifted to the old floor.
	var now_rule: Dictionary = {}
	SkillWeb.train(cfg, "athletics", now_rule, 100.0)
	again._characters["fixture9257c03"]["skills"] = now_rule
	again.save()
	again._finish_writer()
	var third = boot()
	check(is_equal_approx(snappedf(SkillWeb.effective(cfg, "fighting", third._characters["fixture9257c03"]["skills"]), 0.01), 25.0), "a training under today's rule keeps today's floor (Fighting %.2f)" % SkillWeb.effective(cfg, "fighting", third._characters["fixture9257c03"]["skills"]))
	third._finish_writer()
	print("save 9257: %d failures" % failures)
	quit(1 if failures > 0 else 0)
