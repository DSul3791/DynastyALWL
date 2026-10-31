extends SceneTree

# Placement refusals say why (Dave 31 Oct 2026: the ghost just did nothing) and a rough bed can go INSIDE a lean-to (the bigger lean-to, 2.6 x 2.4 m, covered box 1.3 x 1.2 half).
# Each refusal sends one plain notice: too far, ground too wet, off the ground, too close to another fire, something in the way, too many fires; the bed inside the lean-to's box is
# placed, the same bed 2 m outside it (still within the 2.5 m gap) is refused, and the lean-to covers the bed.
#   godot --headless --path . --script res://src/worldgen/tools/test_placement_notices.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []
var ground: Array = [10.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func give(id: String, n: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, n, Vector3.ZERO)


func place(kit: String, at: Vector3, yaw: int = 0) -> void:
	said.clear()

	if at.distance_to(Vector3(0.0, 10.0, 0.0)) < 30.0:
		items.report_position(1, Vector3(at.x - 1.0, ground[0] + 0.0, at.z - 1.0) if at.y < 5.0 else Vector3(at.x - 1.0, at.y, at.z - 1.0))   # stand beside the spot (near reach)

	var slot: int = items.inventory_of(1).numbers.find(items.table.number_of(kit))
	items.action(1, Net.ACT_PLACE, slot, yaw, 0, at)


func rows(kind_item: String) -> int:
	var n: int = 0

	for k in items._items:
		n += 1 if int(items._items[k].get("number", 0)) == items.table.number_of(kind_item) else 0

	return n


func _init() -> void:
	var dir: String = "user://test_placement_notices"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return ground[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "placenotice01")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	give("campfire_kit", 4)
	give("lean_to_kit", 2)
	give("rough_bed_kit", 3)

	place("campfire_kit", Vector3(40.0, 10.0, 0.0))
	check(said.has("Too far to place that.") and rows("campfire_kit") == 0, "too far: told so (%s)" % str(said))
	ground[0] = 0.5
	place("campfire_kit", Vector3(2.0, 0.5, 0.0))
	check(said.has("The ground is too wet here."), "wet low ground: told so (%s)" % str(said))
	ground[0] = 10.0
	place("campfire_kit", Vector3(2.0, 14.0, 0.0))
	check(said.has("You cannot place that there."), "a point 4 m off its ground: told so (%s)" % str(said))
	place("campfire_kit", Vector3(2.0, 10.0, 0.0))
	check(rows("campfire_kit") == 1 and said.is_empty(), "a good spot places the fire with no complaint")
	place("campfire_kit", Vector3(2.5, 10.0, 0.5))
	check(said.has("Too close to another fire."), "a second fire beside it: told so (%s)" % str(said))
	give("chest_kit", 1)
	place("chest_kit", Vector3(3.0, 10.0, 1.0))
	check(said.has("Something is in the way."), "a chest within the gap of a fire: told so (%s)" % str(said))

	# Lean-to and bed.
	place("lean_to_kit", Vector3(8.0, 10.0, 6.0))
	var lean: Dictionary = {}

	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "lean_to":
			lean = items._items[k]

	check(not lean.is_empty(), "the lean-to is placed")
	place("rough_bed_kit", Vector3(8.0, 10.0, 6.0), 37)
	check(rows("rough_bed") == 1 and said.is_empty(), "a rough bed goes inside the lean-to (%s)" % str(said))
	place("rough_bed_kit", Vector3(8.0, 10.0, 8.0))
	check(rows("rough_bed") == 1 and said.has("Something is in the way."), "a second bed 2.0 m off, outside the box but within the gap, is refused (%s)" % str(said))
	var bed_row: Dictionary = {}

	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "rough_bed":
			bed_row = items._items[k]

	check(not bed_row.is_empty() and is_equal_approx(float(bed_row["struct"]["yaw"]), float(lean["struct"]["yaw"])), "the bed lies along the lean-to (yaw %s against %s)" % [str(bed_row["struct"].get("yaw")), str(lean["struct"]["yaw"])])
	var def: Dictionary = items._structures.get("lean_to", {})
	check(float(def.get("half_x", 0.0)) >= 1.3 and float(def.get("half_z", 0.0)) >= 1.2, "the lean-to is big enough for a bed: covered box %.1f x %.1f m half-sizes" % [float(def.get("half_x", 0.0)), float(def.get("half_z", 0.0))])
	print("placement notices: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
