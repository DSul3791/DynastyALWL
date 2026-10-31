extends SceneTree

# The lean-to as a home (Dave 31 Oct 2026): a rough bed is placed INSIDE a placed lean-to, the player lies on it under the lean-to's real roof (the cover index gets the box roof of
# the lean-to) so it is a good bed (sleep quality 1.0, regen and drain bonuses apply), the bed can be set as the spawn point (ACT_SET_SPAWN: "Spawn point set", one per character,
# saved), a dead or dropped character comes back at the bed, a new bed replaces the old, and with the bed taken down they come back at the spawn pad.
#   godot --headless --path . --script res://src/worldgen/tools/test_lean_to_bed.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func give(id: String, n: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, n, Vector3.ZERO)


func struct_ids(kind: String) -> Array:
	var out: Array = []

	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == kind:
			out.append(k)

	return out


func place(kit: String, at: Vector3) -> void:
	items.report_position(1, Vector3(at.x - 1.0, at.y, at.z - 1.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of(kit)), 0, 0, at)


func _init() -> void:
	var dir: String = "user://test_lean_to_bed"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var index = CoverScript.Index.new()
	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.roof_add = func(roof): return index.add_roof(roof)
	items.cover_at = func(p): return CoverScript.at(p, index)
	items.respawn_point = Vector3(100.0, 10.0, 100.0)
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "leantobed0001")
	items.vitals_of(1)["weight"] = 2000.0
	give("lean_to_kit", 1)
	give("rough_bed_kit", 2)
	place("lean_to_kit", Vector3(8.0, 10.0, 6.0))
	place("rough_bed_kit", Vector3(8.0, 10.0, 6.0))
	var beds: Array = struct_ids("rough_bed")
	check(struct_ids("lean_to").size() == 1 and beds.size() == 1, "a lean-to and a rough bed inside it are placed")
	var bed: Vector3 = items._items[beds[0]]["pos"]
	check(CoverScript.at(bed + Vector3(0.0, 1.0, 0.0), index) > 0.5, "the bed lies under the lean-to's roof (cover %.1f)" % CoverScript.at(bed + Vector3(0.0, 1.0, 0.0), index))
	items.report_position(1, bed + Vector3(0.0, 0.2, 0.0))
	items._stance[1] = 3
	check(items.on_good_bed(1), "lying on it under the lean-to is a good bed")
	check(is_equal_approx(items._sleep_quality(1), float(items._bed_cfg.get("quality", 1.0))), "sleep quality is the good-bed quality (%.2f)" % items._sleep_quality(1))
	check(float(items._bed_cfg.get("regen_mult", 1.0)) > 1.0 and float(items._bed_cfg.get("drain_mult", 1.0)) < 1.0, "and the bed's regen bonus (x%.2f) and drain cut (x%.2f) are in force" % [float(items._bed_cfg.get("regen_mult", 1.0)), float(items._bed_cfg.get("drain_mult", 1.0))])

	# Spawn point.
	check(items.respawn_for(1) != bed + Vector3(0.0, 0.3, 0.0), "before choosing, the character does not come back at the bed")
	said.clear()
	items.action(1, Net.ACT_SET_SPAWN, beds[0], 0, 0, Vector3.ZERO)
	check(said.has("Spawn point set"), "E on the bed: Spawn point set (%s)" % str(said))
	check(items.respawn_for(1).distance_to(bed) < 0.5, "a dead or dropped character comes back at the bed")
	# The same through E on the bed (ACT_USE_STRUCT), as the client prompt sends it.
	items._characters[items._peer_key[1]].erase("spawn_bed")
	said.clear()
	items.report_position(1, bed + Vector3(0.5, 0.2, 0.0))
	items.action(1, Net.ACT_USE_STRUCT, beds[0], 0, 0, Vector3.ZERO)
	check(said.has("Spawn point set") and items.respawn_for(1).distance_to(bed) < 0.5, "E on the bed (use set_spawn) sets the spawn point too")


	# A straw bed (comfort kind of class bed) in a third lean-to is a bed too: placed inside, lying on it is a good bed, E sets the spawn point.
	give("lean_to_kit", 1)
	give("straw_bed_kit", 1)
	place("lean_to_kit", Vector3(60.0, 10.0, 6.0))
	place("straw_bed_kit", Vector3(60.0, 10.0, 6.0))
	var straw: Array = struct_ids("straw_bed")
	check(straw.size() == 1, "a straw bed goes inside a lean-to too")

	if straw.size() == 1:
		var spos: Vector3 = items._items[straw[0]]["pos"]
		items.report_position(1, spos + Vector3(0.0, 0.2, 0.0))
		items._stance[1] = 3
		items._bed_cache.erase(1)
		check(items.on_good_bed(1), "lying on the straw bed under the lean-to is a good bed")
		items.action(1, Net.ACT_USE_STRUCT, straw[0], 0, 0, Vector3.ZERO)
		check(items.respawn_for(1).distance_to(spos) < 0.5, "E on the straw bed sets the spawn point")
		items._characters[items._peer_key[1]].erase("spawn_bed")
		items._stance[1] = 0

	# A second bed (in a second lean-to) replaces the first.
	give("lean_to_kit", 1)
	give("rough_bed_kit", 1)
	place("lean_to_kit", Vector3(30.0, 10.0, 6.0))
	place("rough_bed_kit", Vector3(30.0, 10.0, 6.0))
	var all_beds: Array = struct_ids("rough_bed")
	check(all_beds.size() == 2, "a second bed in a second lean-to")
	var second: int = all_beds[0] if all_beds[0] != beds[0] else all_beds[1]
	items.report_position(1, items._items[second]["pos"] + Vector3(0.5, 0.0, 0.0))
	items.action(1, Net.ACT_SET_SPAWN, second, 0, 0, Vector3.ZERO)
	check(items.respawn_for(1).distance_to(items._items[second]["pos"]) < 0.5, "choosing another bed unsets the first")

	# Saved, and gone when the bed is gone.
	items._save_characters()
	items._finish_writer()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.send_notice = func(_p, _t): pass
	again.ground_height = func(_x, _z): return 10.0
	again.respawn_point = Vector3(100.0, 10.0, 100.0)
	again.setup(ItemTableScript.load_default(), dir)
	again.peer_connected_hello(1, "leantobed0001")
	check(again._characters[again._peer_key[1]].get("spawn_bed", []).size() == 3, "the spawn bed is saved with the character")
	items._items.erase(second)
	check(items.respawn_for(1) == Vector3(100.0, 10.0, 100.0), "with that bed gone the character comes back at the spawn pad")
	print("lean to bed: %d failures" % failures)
	quit(1 if failures > 0 else 0)
