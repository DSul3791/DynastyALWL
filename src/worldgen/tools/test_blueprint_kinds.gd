extends SceneTree

# A blueprint gives back the very items put into it (coordinator, 23 Nov 2026: a group cost came back as its cheapest member, Bronze nails put in
# returned as Copper nails). A blueprint with a group cost is filled with the group's dearest member: taken down as a half-filled site, as the built
# piece, and as the built piece after a restart, it returns that member. A 9257 row (23 values, no kinds) still takes down as before.
#   godot --headless --path . --script res://src/worldgen/tools/test_blueprint_kinds.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const DIR := "user://test_blueprint_kinds"
const HERE := Vector3(200.0, 10.0, 200.0)
const SPOT := Vector3(200.0, 10.0, 203.0)

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_notice = func(_p, _t): pass
	s.ground_height = func(_x, _z): return 10.0
	s.setup(ItemTableScript.load_default(), DIR)
	s.peer_connected_hello(1, "bpkindskey01")
	s.report_position(1, HERE)
	s.vitals_of(1)["weight"] = 400.0
	return s


func clear_pack() -> void:
	var inv = items.inventory_of(1)

	for slot in inv.slot_count:
		inv.clear_slot(slot)


func have(number: int) -> int:
	return items.inventory_of(1).count_of(number)


func site_ids(bp: Dictionary) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == str(bp["structure"]):
			out.append(id)

	return out


# A hammer blueprint with one group cost whose dearest member is not the one a refund gives by default: [blueprint, cost id, dearest member].
func pick() -> Array:
	for number in items._blueprints:
		var bp: Dictionary = items._blueprints[number]

		if bool(bp.get("retired", false)) or bool(bp.get("locked", false)) or not bp.get("spent", []).is_empty() or str(bp.get("tool", "hammer")) != "hammer":
			continue

		if bp["cost"].any(func(need): return str(need[0]).begins_with("log") or items.is_shoulder_item(items.table.number_of(str(need[0])))):
			continue   # logs ride on the shoulder one at a time: a piece of pack materials keeps the test plain

		for need in bp["cost"]:
			var order: PackedInt32Array = items.table.spend_order(items.table.number_of(str(need[0])))

			if order.size() >= 2:
				return [bp, str(need[0]), int(order[order.size() - 1])]

	return []


func give_cost(bp: Dictionary, group_id: String, member: int, share: float) -> void:
	for need in bp["cost"]:
		var count: int = maxi(1, int(ceil(float(need[1]) * share)))
		items.give(1, member if str(need[0]) == group_id else items.table.number_of(str(need[0])), count)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "/" + ItemsScript.AREA_DIR)

	for sub in [DIR, DIR + "/" + ItemsScript.AREA_DIR]:
		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)

	items = make_server()
	var found: Array = pick()
	check(not found.is_empty(), "a hammer blueprint with a group cost exists")

	if found.is_empty():
		quit(1)
		return

	var bp: Dictionary = found[0]
	var group_id: String = found[1]
	var member: int = found[2]
	var cheapest: int = items._refund_number(items.table.number_of(group_id))
	var need_n: int = 0

	for need in bp["cost"]:
		if str(need[0]) == group_id:
			need_n = int(need[1])

	print("  %s: %d %s, filled with %s (a plain refund gives %s)" % [str(bp["structure"]), need_n, group_id, items.table.id_of(member), items.table.id_of(cheapest)])
	var hammer: int = items.table.number_of("steel_hammer") if items.table.number_of("steel_hammer") > 0 else items.table.number_of("stone_hammer")

	# 1. A half-filled site taken down: the dearest member comes back.
	clear_pack()
	items.give(1, hammer, 1)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, SPOT)
	var ids: Array = site_ids(bp)
	check(ids.size() == 1 and items._items[ids[0]]["struct"].has("site"), "the blueprint site is set down")
	give_cost(bp, group_id, member, 0.5)
	var put_in: int = have(member)
	HeldTool.hit_site(items, ids[0])
	var held: int = int(items._items[ids[0]]["struct"]["site"]["have"].get(group_id, 0))
	check(held > 0 and have(member) == put_in - held, "a hammer hit puts %d %s in" % [held, items.table.id_of(member)])
	items.action(1, Net.ACT_PICKUP, ids[0], 0, 0, Vector3.ZERO)
	check(site_ids(bp).is_empty() and have(member) == put_in and (cheapest == member or have(cheapest) == 0), "the half-filled site taken down gives back %d %s, none as %s" % [have(member), items.table.id_of(member), items.table.id_of(cheapest)])

	# 2. Built and taken down, and 3. built, saved, restarted and taken down: the same.
	for restart in [false, true]:
		clear_pack()
		items.give(1, hammer, 1)
		give_cost(bp, group_id, member, 1.0)
		var before: int = have(member)
		items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, SPOT)
		ids = site_ids(bp)
		HeldTool.hit_site(items, ids[0])
		check(ids.size() == 1 and not items._items[ids[0]]["struct"].has("site") and have(member) == before - need_n, "the piece is built from %d %s" % [need_n, items.table.id_of(member)])

		if restart:
			items.save()
			items._finish_writer()
			items = make_server()
			ids = site_ids(bp)
			check(ids.size() == 1 and items._items[ids[0]]["struct"].get("kinds", {}).has(group_id), "after a restart the piece still knows what went in")

		items.action(1, Net.ACT_PICKUP, ids[0], 0, 0, Vector3.ZERO)
		check(site_ids(bp).is_empty() and have(member) == before and (cheapest == member or have(cheapest) == 0), "the built piece taken down%s gives back %d %s" % [" after a restart" if restart else "", have(member), items.table.id_of(member)])

	# 4. A row from build 9257 (no kinds column): built, it takes down as before, the group cost as its cheapest member.
	clear_pack()
	items.give(1, hammer, 1)
	give_cost(bp, group_id, member, 1.0)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, SPOT)
	HeldTool.hit_site(items, site_ids(bp)[0])
	items.save()
	items._finish_writer()
	var cut: int = 0

	for file in DirAccess.get_files_at(DIR + "/" + ItemsScript.AREA_DIR):
		if not file.ends_with(".json"):
			continue

		var path: String = DIR + "/" + ItemsScript.AREA_DIR + "/" + file
		var area: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))

		for row in area.get("items", []):
			if row.size() > 23 and str(row[9]) == str(bp["structure"]):
				row.resize(23)
				cut += 1

		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(area))
		f.close()

	items = make_server()
	ids = site_ids(bp)
	check(cut == 1 and ids.size() == 1 and not items._items[ids[0]]["struct"].has("kinds"), "a 9257 row (23 values) loads, with no kinds")
	clear_pack()
	items.action(1, Net.ACT_PICKUP, ids[0], 0, 0, Vector3.ZERO)
	check(site_ids(bp).is_empty() and have(cheapest) == need_n, "and takes down as before: %d %s" % [have(cheapest), items.table.id_of(cheapest)])
	items._finish_writer()

	print("blueprint kinds: %d failures" % failures)
	quit(1 if failures > 0 else 0)
