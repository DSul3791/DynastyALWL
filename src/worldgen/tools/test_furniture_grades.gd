extends SceneTree

# Graded furniture (Mission 001 phase 3, master docs/design/DYNASTY_MASTER_ITEMS.md s3.5 and s2.3 items 3-5): Crude, Rustic, Fine, Ornate chests,
# chairs and tables, Crude and Fine benches, and the single board pieces are built from Hardwood boards, never Planks (the Crate keeps Planks);
# each grade costs more boards than the one below and places from its blueprint; chest slots rise by grade; comfort counts only the best graded
# seat and the best graded table.
#   godot --headless --path . --script res://src/worldgen/tools/test_furniture_grades.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const LookTable := preload("res://src/client/look_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

# Blueprint (and structure) ids, lowest grade first.
const FAMILIES := {
	"Chest": ["crude_chest", "plank_chest", "fine_chest", "iron_chest"],
	"Chair": ["crude_chair", "chair", "iron_chair", "ornate_chair"],
	"Table": ["crude_table", "table", "iron_table", "ornate_table"],
	"Bench": ["bench", "iron_bench"],
}
const GRADES := {"Chest": ["Crude", "Rustic", "Fine", "Ornate"], "Chair": ["Crude", "Rustic", "Fine", "Ornate"], "Table": ["Crude", "Rustic", "Fine", "Ornate"], "Bench": ["Crude", "Fine"]}
const SINGLES := ["wooden_shelf", "wooden_cupboard", "wooden_barrel", "weapon_rack", "armour_stand", "canopy_bed"]

var failures: int = 0
var items
var bps: Dictionary = {}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _need(id: String, item: String) -> int:
	for row in bps[id]["cost"]:
		if str(row[0]) == item:
			return int(row[1])

	return 0


func _give(id: String, count: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, count, Vector3.ZERO)


func _have(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _clear() -> void:
	var inv = items.inventory_of(1)

	for slot in range(inv.SLOTS):
		inv.numbers[slot] = 0
		inv.counts[slot] = 0
		inv.wear[slot] = 0


func _standing_at(kind: String, spot: Vector3) -> int:
	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == kind and it["pos"].distance_to(spot) < 0.5:
			return id

	return 0


func add_struct(kind: String, at: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": 0, "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	items._next_id += 1
	return id


func _data_checks() -> void:
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))["items"]

	for family in FAMILIES:
		var ids: Array = FAMILIES[family]

		for n in ids.size():
			var id: String = ids[n]
			var grade: String = GRADES[family][n]
			var bp: Dictionary = bps[id]
			var want: String = "%s - %s" % [grade, family]
			check(str(bp["name"]) == want and str(names[str(items._structures[str(bp["structure"])]["item"])]["name"]) == want, "%s: blueprint and item are named %s" % [id, want])
			check(not bool(names[str(items._structures[str(bp["structure"])]["item"])].get("future", false)), "%s: the item is live" % id)
			check(_need(id, "hardwood_board") > 0 and _need(id, "lumber") == 0, "%s: costs Hardwood boards, no Planks (%s)" % [id, str(bp["cost"])])
			check(int(bp.get("hammer", 1)) == (3 if grade in ["Fine", "Ornate"] else 1), "%s: %s takes hammer %d" % [id, grade, int(bp.get("hammer", 1))])
			check(LookTable.has_look(str(items._structures[str(bp["structure"])]["look"])) or str(items._structures[str(bp["structure"])]["look"]) == "chest", "%s: its look is drawable" % id)

			if grade == "Crude":
				check(_need(id, "nails") == 0 and _need(id, "hinges") == 0 and _need(id, "wooden_pin") > 0, "%s: Crude is pinned, with no nails or hinges" % id)
			else:
				check(_need(id, "nails") > 0 and _need(id, "wooden_pin") == 0 and _need(id, "twine") == 0, "%s: %s is nailed" % [id, grade])

			if family == "Chest":
				check((_need(id, "hinges") > 0) == (grade != "Crude"), "%s: hinges on the lid from Rustic up" % id)

			if n > 0:
				var below: String = ids[n - 1]
				check(_need(id, "hardwood_board") > _need(below, "hardwood_board") and _need(id, "nails") >= _need(below, "nails"), "%s: more boards and nails than %s" % [id, below])

	check(_need("iron_chair", "leather") > 0 and _need("ornate_chair", "leather") > _need("iron_chair", "leather") and _need("ornate_chair", "wool_cloth") > 0, "seats: Fine has Leather, Ornate more Leather and a Wool cloth cushion")
	check(_need("iron_bench", "leather") > 0, "the Fine bench seat has Leather")
	check(_need("iron_chest", "iron_band") > 0 and _need("iron_chest", "iron_ingot") == 0, "the Ornate chest is bound with Iron bands, not ingots")

	for id in ["table", "iron_table", "ornate_table", "plank_chest", "fine_chest", "iron_chest"]:
		check(_need(id, "leather") == 0 and _need(id, "wool_cloth") == 0, "%s: no cloth or leather on a bare table or chest" % id)

	for id in SINGLES:
		check(_need(id, "hardwood_board") > 0 and _need(id, "lumber") == 0, "%s: costs Hardwood boards, no Planks" % id)

	check(_need("wooden_crate", "lumber") > 0 and _need("wooden_crate", "hardwood_board") == 0, "the Crate is still a Plank packing box")

	# Slots: Crate 10 < Crude < Rustic 20 < Fine < Ornate 30, and the weight limit rises with them.
	var ladder: Array = ["wooden_crate"] + FAMILIES["Chest"]
	var slots: Array = ladder.map(func(k): return int(items._structures[k]["slots"]))
	var kg: Array = ladder.map(func(k): return float(items._structures[k]["max_kg"]))
	check(slots[0] == 10 and slots[2] == 20 and slots[4] == 30 and slots[0] < slots[1] and slots[1] < slots[2] and slots[2] < slots[3] and slots[3] < slots[4], "chest slots rise by grade %s" % str(slots))
	check(kg[0] < kg[1] and kg[1] < kg[2] and kg[2] < kg[3] and kg[3] < kg[4], "chest weight limits rise by grade %s" % str(kg))


# Each grade places from its blueprint: Planks in place of the boards leave a blueprint site and are never taken; the boards finish it.
func _place_checks() -> void:
	var x: float = 300.0

	for family in FAMILIES:
		for id in FAMILIES[family]:
			var bp: Dictionary = bps[id]
			var boards: int = _need(id, "hardwood_board")
			var spot: Vector3 = Vector3(x, 10.0, 300.0)
			x += 5.0
			items.report_position(1, spot + Vector3(0.0, 0.0, -1.5))
			_clear()
			_give("iron_hammer", 1)

			for row in bp["cost"]:
				_give("lumber" if str(row[0]) == "hardwood_board" else str(row[0]), int(row[1]))

			items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, spot)
			var piece: int = _standing_at(str(bp["structure"]), spot)
			check(piece != 0 and items._items[piece]["struct"].has("site") and _have("lumber") == boards, "%s: with Planks for the boards it is only a site and no Plank is taken" % id)

			if piece == 0:
				continue

			items.action(1, Net.ACT_USE_STRUCT, piece, 0, 0, Vector3.ZERO)
			check(items._items[piece]["struct"].has("site") and _have("lumber") == boards, "%s: E on the site takes no Plank for a board (%d Planks left)" % [id, _have("lumber")])
			_give("hardwood_board", boards)
			items.action(1, Net.ACT_USE_STRUCT, piece, 0, 0, Vector3.ZERO)
			check(not items._items[piece]["struct"].has("site") and _have("hardwood_board") == 0 and _have("lumber") == boards, "%s: with %d Hardwood boards it stands" % [id, boards])

			if family == "Chest":
				var box = items._chest_of(1, piece)
				check(box != null and int(box.usable) == int(items._structures[id]["slots"]), "%s: opens with %d slots" % [id, int(items._structures[id]["slots"])])


# Comfort: graded seats and tables count once per class, the best grade; ungraded seats still count by kind.
func _comfort_checks() -> void:
	for family in ["Chair", "Table", "Bench"]:
		var points: Array = FAMILIES[family].map(func(k): return int(items._comfort_kind(str(items._structures[k].get("comfort", k))).get("points", 0)))
		var ok: bool = points[0] > 0

		for n in range(1, points.size()):
			ok = ok and points[n] > points[n - 1]

		check(ok, "%s comfort rises by grade %s" % [family, str(points)])

	check(int(items._comfort_kind("chair")["points"]) == 2 and int(items._comfort_kind("table")["points"]) == 2 and int(items._comfort_kind("bench")["points"]) == 1, "today's points stay: Rustic chair 2, Rustic table 2, Crude bench 1")
	items._items.clear()
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var level: Callable = func() -> int: return int(items.comfort_at(1, true)["level"])
	var ornate_chair: int = 0

	for kind in FAMILIES["Chair"] + FAMILIES["Bench"]:
		var id: int = add_struct(kind, Vector3(1.0 + 0.5 * float(items._items.size()), 10.0, 1.0))

		if kind == "ornate_chair":
			ornate_chair = id

	var best_seat: int = int(items._comfort_kind("ornate_chair")["points"])
	check(level.call() == 1 + best_seat, "four chair grades and two benches count as the Ornate chair alone (%d)" % level.call())

	for kind in FAMILIES["Table"]:
		add_struct(kind, Vector3(-1.0 - 0.5 * float(items._items.size()), 10.0, -1.0))

	var best_table: int = int(items._comfort_kind("ornate_table")["points"])
	check(level.call() == 1 + best_seat + best_table, "and four table grades as the Ornate table alone (%d)" % level.call())
	add_struct("log_seat", Vector3(3.0, 10.0, -2.0))
	check(level.call() == 2 + best_seat + best_table, "an ungraded log seat still adds its point (%d)" % level.call())
	items._items.erase(ornate_chair)
	check(level.call() == 2 + int(items._comfort_kind("fine_chair")["points"]) + best_table, "without the Ornate chair the next best seat counts (%d)" % level.call())
	items._comfort_cache.clear()
	var tip: String = items.comfort_tip(1)
	check((tip.contains("Fine chair") or tip.contains("Fine bench")) and not tip.contains("Crude chair") and not tip.contains("Crude table"), "the tooltip names the seat that counts and offers no lower grade (%s)" % tip.replace("\n", " | "))


func _init() -> void:
	var dir: String = "user://test_furniture_grades"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.cover_at = func(_p): return 1.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "furnituregrades1")
	bps = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]
	_data_checks()
	_place_checks()
	_comfort_checks()
	print("test_furniture_grades: %d fail" % failures)
	quit(1 if failures > 0 else 0)
