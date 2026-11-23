extends SceneTree

# Dave 17 Nov 2026: "many of them stay green even though you cant place them ... if something is blocking the blueprint should be red" and "it wont let me
# place anything on top of a foundation ... I should be able to place stations and furniture etc on foundations and on top of ceilings like on the second
# floor of a building". The ghost (PlacementRules.snap + blocked, every fire and structure as rows) and the server (_place) must give the same answer for
# stations and furniture on a foundation, on an upper floor, beside a wall and through one; the piece rests on the floor's top and is saved there.
#   godot --headless --path . --script res://src/worldgen/tools/test_placement_on_floors.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Rules := preload("res://src/shared/placement_rules.gd")
const StructureLook := preload("res://src/shared/structure_look.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const BASE_KIT := "thatch_floor_kit"   # Crude - Foundation, 4 x 4 m, top 0.3 m
const WALL_KIT := "thatch_wall_kit"    # Crude - Wall
const CEILING_KIND := "log_floor"      # a 2 x 2 m ceiling cell
const STOREY_M := 2.4                  # a wall's height: the ceiling over the ground floor lies on the wall tops

var failures: int = 0
var items
var cfg: Dictionary = {}
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# Every fire and structure the server holds, as the client's placement_rows sends them to the ghost.
func rows() -> Array:
	var out: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("fire"):
			out.append({"pos": it["pos"], "state": int(it["fire"]["state"]), "yaw": 0.0})
		elif it.has("struct"):
			out.append({"pos": it["pos"], "state": int(items._structures[str(it["struct"]["kind"])]["state"]), "yaw": float(it["struct"]["yaw"])})

	return out


# What the ghost says for `kit` aimed at `aim`: [spot, "" or the red reason]. The ground here is flat at 10 m, so steep and water never apply.
func ghost(kit: String, aim: Vector3, yaw: int) -> Array:
	var grid: Array = Rules.snap(cfg, kit, aim, yaw, items._foundation_rows())
	var why: String = Rules.blocked(cfg, kit, grid[0], rows(), float(grid[1]))

	if why == "":
		why = Rules.off_ground(cfg, kit, (grid[0] as Vector3).y, 10.0, bool(grid[2]), grid.size() > 3)

	return [grid[0], why]


# Places `kit` at `at` as the ghost's click does (the server snaps it again); the new item's id, else -1.
func put(kit: String, at: Vector3, yaw: int = 0) -> int:
	said.clear()
	items.report_position(1, Vector3(at.x, at.y, at.z - 1.5))
	var id: int = items._next_id

	if items._blueprint_of_kit.has(kit):
		items.place_piece(1, kit, at, yaw)
	else:
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(kit), 0, 1, Vector3.ZERO)
		items.place_item(1, items.table.number_of(kit), at, 0, yaw)

	return id if items._items.has(id) else -1


# The ghost and the server agree on `kit` at `aim`; the piece is taken away again unless `keep`. Returns the placed id or -1.
func agree(kit: String, aim: Vector3, yaw: int, want_ok: bool, what: String, keep: bool = false) -> int:
	var says: Array = ghost(kit, aim, yaw)
	var id: int = put(kit, aim, yaw)
	check((str(says[1]) == "") == want_ok and (id >= 0) == want_ok, "%s: ghost '%s', server %s %s" % [what, str(says[1]), "placed" if id >= 0 else "refused", str(said)])

	if id >= 0:
		check(((items._items[id]["pos"] as Vector3) - (says[0] as Vector3)).length() < 0.01, "%s: it stands where the ghost showed it (%s, ghost %s)" % [what, str(items._items[id]["pos"]), str(says[0])])

		if not keep:
			items._items.erase(id)

	return id


func _init() -> void:
	cfg = Rules.load_config()
	check(Rules.blocked(cfg, "chest_kit", Vector3(1.0, 10.0, 0.0), [{"pos": Vector3.ZERO + Vector3(0.0, 10.0, 0.0), "state": StructureLook.FIRE_COALS, "yaw": 0.0}]) == "close", "a fire burnt down to coals keeps a chest its gap away on the ghost too, as on the server")
	var dir: String = "user://test_placement_on_floors"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "floorkey0001")
	var top: float = 10.0 + float(items._structures["thatch_floor"].get("top_m", 0.3))
	var kits: Array = ["chest_kit", "workbench_kit", "bench_kit", "crude_table"]   # two stations, two pieces of furniture

	for n in kits.size():
		var kit: String = kits[n]
		var x: float = float(n) * 40.0
		check(put(BASE_KIT, Vector3(x, 10.0, 0.0)) >= 0, "%s: a foundation stands at x %d" % [kit, int(x)])
		var wall: int = put(WALL_KIT, Vector3(x, top, -1.9))
		check(wall >= 0 and absf(float(items._items[wall]["pos"].z) + 2.0) < 0.01 and absf(float(items._items[wall]["pos"].x) - (x - 1.0)) < 0.01, "%s: a wall stands on its back edge, the left 2 m (%s)" % [kit, str(items._items[wall].get("pos", "none") if wall >= 0 else "none")])

		for c in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:   # the floor of the storey above, on the wall tops
			items._items[items._next_id] = {"number": items.table.number_of(str(items._structures[CEILING_KIND]["item"])), "count": 1, "pos": Vector3(x + c.x, top + STOREY_M, c.y), "left": 1.0e9, "struct": {"kind": CEILING_KIND, "yaw": 0.0}}
			items._grid_add(items._next_id, items._items[items._next_id])
			items._next_id += 1

		var upper: float = top + STOREY_M + Rules.anchor_top(items._structures[CEILING_KIND])
		agree(kit, Vector3(x + 0.3, top, 0.4), 0, true, "%s on the foundation" % kit)
		agree(kit, Vector3(x + 0.3, top + 0.2, 0.4), 90, true, "%s aimed a little above the foundation's top, turned" % kit)
		agree(kit, Vector3(x - 0.5, upper, 0.6), 0, true, "%s on the upper floor" % kit)
		var back_z: float = -2.0 + float(items._structures["thatch_wall"]["footprint_z"]) * 0.5 + float(Rules.structure_of_kit(cfg, kit)["footprint_z"]) * 0.5 + 0.03   # its back 3 cm off the wall's face
		agree(kit, Vector3(x - 0.5, top, back_z), 0, true, "%s against the wall, not in it" % kit)
		agree(kit, Vector3(x - 0.5, top, -2.0), 0, false, "%s through the wall (furniture too since 23 Nov 2026; wall mounts still go in it)" % kit)
		var low: Array = ghost(kit, Vector3(x + 0.3, top, 0.4), 0)
		check(is_equal_approx((low[0] as Vector3).y, top), "%s: aimed at the ground floor under a ceiling it stands on the foundation, not the floor above (%s)" % [kit, str(low[0])])
		check(not bool(Rules.snap(cfg, kit, Vector3(x + 3.0, 10.0, 0.0), 0, items._foundation_rows())[2]), "%s: off the foundation it stands on the ground" % kit)

	# Turned: a workbench (1.5 x 1.0 m) 0.6 m in front of the wall's face clears it square on, but turned a quarter its 1.5 m runs into the wall.
	var bench_z: float = -2.0 + float(items._structures["thatch_wall"]["footprint_z"]) * 0.5 + 0.6
	agree("workbench_kit", Vector3(39.0, top, bench_z), 0, true, "a workbench square on, 0.1 m off the wall")
	agree("workbench_kit", Vector3(39.0, top, bench_z), 90, false, "the same workbench turned a quarter, through the wall")

	# Beds and plots: one to a square metre, on the ghost as on the server (shared plots_clash).
	var plot_state: int = int(cfg["structures"]["small_garden_plot"]["state"])
	check(Rules.blocked(cfg, "small_garden_plot", Vector3(500.0, 10.0, 0.0), [{"pos": Vector3(500.0, 10.0, 0.0), "state": plot_state, "yaw": 0.0}]) == "bed", "a garden plot on another is red: a bed or planter is already there")
	check(Rules.blocked(cfg, "small_garden_plot", Vector3(501.0, 10.0, 0.0), [{"pos": Vector3(500.0, 10.0, 0.0), "state": plot_state, "yaw": 0.0}]) == "", "and beside it is free")

	# A station on the floor keeps a new wall out of its room, and another station its gap; the wall on the other edge still goes up.
	var x2: float = 200.0
	put(BASE_KIT, Vector3(x2, 10.0, 0.0))
	var chest: int = agree("chest_kit", Vector3(x2, top, 1.75), 0, true, "a chest by the front edge", true)
	check(chest >= 0 and is_equal_approx(float(items._items[chest]["pos"].y), top), "the chest stands on the foundation's top, %.2f m" % top)
	var says_wall: Array = ghost(WALL_KIT, Vector3(x2, top, 1.9), 0)
	check(str(says_wall[1]) == "overlap" and put(WALL_KIT, Vector3(x2, top, 1.9)) < 0, "a wall through the chest is red and refused (%s %s)" % [str(says_wall[1]), str(said)])
	check(str(ghost(WALL_KIT, Vector3(x2, top, -1.9), 0)[1]) == "" and put(WALL_KIT, Vector3(x2, top, -1.9)) >= 0, "a wall on the back edge goes up")
	agree("workbench_kit", Vector3(x2 + 0.5, top, 0.0), 0, false, "a workbench 1.8 m from the chest (stations keep their gap)")

	# A floor with a station on it is not taken down from under it.
	var base_id: int = -1

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "thatch_floor" and absf(float(items._items[id]["pos"].x) - x2) < 0.01:
			base_id = id

	check(base_id >= 0 and items._holds_station(items._items[base_id], Rules.structure_of_state(cfg, int(cfg["structures"]["thatch_floor"]["state"]))), "the foundation under the chest knows something stands on it, so it is not taken down from under it")

	# A fire on a foundation still, never on a ceiling (it stands on foundations only, PROVISIONAL PL-1).
	check(not is_nan(Rules.support_top(cfg, Vector3(x2, top, 0.0), items._foundation_rows(), false)), "a fire finds the foundation's top")
	check(is_nan(Rules.support_top(cfg, Vector3(0.0, top + STOREY_M + 0.12, 0.0), items._foundation_rows(), false)), "and not a ceiling's")

	# Saved and loaded: the chest on the floor comes back at the same height.
	items._dirty = true
	items.save()
	items._finish_writer()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	var back: bool = false

	for id in again._items:
		if again._items[id].has("struct") and str(again._items[id]["struct"]["kind"]) == "chest" and absf(float(again._items[id]["pos"].y) - top) < 0.01 and absf(float(again._items[id]["pos"].x) - x2) < 0.01:
			back = true

	check(back, "after a save and a load the chest still stands on the foundation's top")
	print("placement on floors: %d failures" % failures)
	again._finish_writer()
	quit(1 if failures > 0 else 0)
