extends SceneTree

# BUGLIST-001 BUG-008 and BUG-009 (Dave's 12 Nov 2026 playtest): a Crude - Foundation turned red "too steep" on ground the server would take, and a green Crude - Wall at a
# foundation corner was refused with "You cannot place that there". Foundation slope: level, moderate, boundary and steep ground, sampled at the turn the piece is placed at
# (the server's snapped turn, not the camera's). Wall: every wall anchor of a foundation on a slope lifted off the ground, and of a stacked foundation, with completed walls and
# blueprint sites beside it, the ghost's rule (PlacementRules.off_ground) agreeing with the server's.
#   godot --headless --path . --script res://src/worldgen/tools/test_foundation_wall_placement.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Rules := preload("res://src/shared/placement_rules.gd")

const BASE_KIT := "thatch_floor_kit"   # Crude - Foundation
const BASE_KIND := "thatch_floor"
const WALL_KIT := "thatch_wall_kit"    # Crude - Wall
const WALL_KIND := "thatch_wall"

var failures: int = 0
var items
var said: Array = []
var slope: Array = [0.0, 0.0]   # [rise per metre along x, x where the ground is 10 m]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func rows_of(kind: String) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			out.append(id)

	return out


# Stands the player beside the spot, then places a piece the way the ghost's click does (the server snaps it again).
func place(kit: String, at: Vector3, yaw: int = 0, lift: int = 0) -> void:
	said.clear()
	items.report_position(1, Vector3(at.x, 10.0 + slope[0] * (at.x - slope[1]), at.z - 1.0))
	items.place_piece(1, kit, at, yaw, lift)


func _init() -> void:
	var cfg: Dictionary = Rules.load_config()
	var dir: String = "user://test_foundation_wall_placement"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(x, _z): return 10.0 + float(slope[0]) * (float(x) - float(slope[1]))
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "foundwall0001")
	_slope_checks(cfg)
	_off_ground_checks(cfg)
	_wall_corner_checks(cfg)
	print("foundation and wall placement: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# BUG-008: the rise across the 4 x 4 m footprint is read at the turn it is placed at; level, moderate, boundary and steep ground, first foundation.
func _slope_checks(cfg: Dictionary) -> void:
	var limit: float = float(cfg["structures"][BASE_KIND]["max_rise_m"])
	var cases: Array = [["level", 0.0, true], ["moderate (rise 0.4 m over 4 m)", 0.10, true], ["just inside the limit", limit / 4.0 - 0.0002, true], ["just over the limit", limit / 4.0 + 0.0002, false], ["truly steep (rise 2 m over 4 m)", 0.5, false]]
	var x: float = 1000.0

	for c in cases:
		slope = [float(c[1]), x]
		var before: int = rows_of(BASE_KIND).size()
		place(BASE_KIT, Vector3(x, 10.0, 500.0))
		var placed: bool = rows_of(BASE_KIND).size() == before + 1
		check(placed == bool(c[2]), "foundation on %s ground: %s (%s)" % [str(c[0]), "placed" if placed else "refused", str(said)])

		if not bool(c[2]):
			check(said.has("The ground is too steep there."), "the steep refusal names the ground (%s)" % str(said))

		# The same ground, the ghost's rule at the turn the server uses.
		var plane: Callable = func(px: float, _pz: float) -> float: return 10.0 + float(c[1]) * (px - x)
		check((Rules.steep(cfg, BASE_KIT, Vector3(x, 10.0, 500.0), 0.0, plane) == "") == bool(c[2]), "the ghost's slope rule agrees on %s ground" % str(c[0]))
		x += 40.0

	# Turned a camera's 45 degrees the same 4 m square reaches 2.83 m from its middle (rise 0.79 m on a 0.14 slope), but a foundation is placed at a quarter turn: the
	# server samples 2 m corners and takes it, so the ghost must sample the snapped turn (held_item passes the snapped yaw) and not the camera's.
	slope = [0.14, x]
	var plane14: Callable = func(px: float, _pz: float) -> float: return 10.0 + 0.14 * (px - x)
	check(Rules.steep(cfg, BASE_KIT, Vector3(x, 10.0, 500.0), 0.0, plane14) == "" and Rules.steep(cfg, BASE_KIT, Vector3(x, 10.0, 500.0), deg_to_rad(45.0), plane14) == "steep", "a 0.14 slope: quarter turn passes, the camera's 45 degrees would read it as steep")
	var before45: int = rows_of(BASE_KIND).size()
	place(BASE_KIT, Vector3(x, 10.0, 500.0), 45)
	check(rows_of(BASE_KIND).size() == before45 + 1, "the server takes that foundation asked at 45 degrees (it snaps to a quarter turn; %s)" % str(said))


func _off_ground_checks(cfg: Dictionary) -> void:
	check(Rules.off_ground(cfg, BASE_KIT, 10.9, 10.0, false, false) == "" and Rules.off_ground(cfg, BASE_KIT, 11.1, 10.0, false, false) == "float", "a foundation on the ground may stand 1 m off it")
	check(Rules.off_ground(cfg, BASE_KIT, 11.4, 10.0, true, false) == "" and Rules.off_ground(cfg, BASE_KIT, 11.6, 10.0, true, false) == "float", "a foundation beside another may stand 1.5 m off the ground")
	check(Rules.off_ground(cfg, BASE_KIT, 12.0, 10.0, true, true) == "" and Rules.off_ground(cfg, BASE_KIT, 18.0, 10.0, true, true) == "", "a stacked foundation gets a body (2 m) of reach per layer")
	check(Rules.off_ground(cfg, WALL_KIT, 12.3, 10.0, true, false) == "" and Rules.off_ground(cfg, "campfire_kit", 12.3, 10.0, true, false) == "", "a piece standing on a foundation is never refused for the ground under it")
	check(Rules.off_ground(cfg, WALL_KIT, 12.0, 10.0, false, false) == "float" and Rules.reason_text("float") != "", "a wall hung 2 m off the ground is red, with a reason in words")


# BUG-009: a foundation on a 0.12 slope lifted 1 m off the ground (the wheel's most) has its two downhill wall anchors 1.54 m under the wall's spot; a stacked foundation's
# anchors are 2.3 m up. Every one of the eight anchors takes a Crude - Wall, whatever stands beside it: completed walls and blueprint sites.
func _wall_corner_checks(cfg: Dictionary) -> void:
	var anchors: Array = cfg["structures"][BASE_KIND]["anchors"]["wall"]
	var cx: float = 2000.0
	slope = [0.12, cx]
	place(BASE_KIT, Vector3(cx, 11.0, 500.0), 0, 10)
	var base_ids: Array = rows_of(BASE_KIND)
	var lifted: Dictionary = {}

	for id in base_ids:
		if (items._items[id]["pos"] as Vector3).distance_to(Vector3(cx, 11.0, 500.0)) < 0.1:
			lifted = items._items[id]

	check(not lifted.is_empty(), "a foundation on a 0.12 slope, lifted 1 m, is placed (%s)" % str(said))

	if lifted.is_empty():
		return

	var top: float = (lifted["pos"] as Vector3).y + float(cfg["structures"][BASE_KIND]["top_m"])
	_walls_on(cfg, anchors, Vector3(cx, (lifted["pos"] as Vector3).y, 500.0), top, "lifted foundation on a slope")
	# The same walls refused by the ghost's rule would show red with a reason: at the downhill anchor the old rule's gap.
	var low: Vector3 = Vector3(cx - 2.0, top, 499.0)
	var ground_low: float = 10.0 + 0.12 * (low.x - cx)
	check(absf(ground_low - low.y) > Rules.BASE_REACH_M and Rules.off_ground(cfg, WALL_KIT, low.y, ground_low, true, false) == "", "the downhill anchor lies %.2f m over the ground, past a foundation's reach, and the wall is still allowed" % (low.y - ground_low))
	# A run of foundations downhill keeps the first one's height: the second (1.48 m over its ground) goes, the third (1.96 m) would float and says so.
	var runs: int = rows_of(BASE_KIND).size()
	place(BASE_KIT, Vector3(cx - 4.0, 11.0, 500.0))
	check(rows_of(BASE_KIND).size() == runs + 1, "a foundation beside the lifted one takes its height (%s)" % str(said))
	place(BASE_KIT, Vector3(cx - 8.0, 11.0, 500.0))
	check(rows_of(BASE_KIND).size() == runs + 1 and said.has("You cannot place that there: it is too far above or below the ground."), "a third one 1.96 m over its ground is refused, naming the ground (%s)" % str(said))
	# Stacked foundation on flat ground.
	var sx: float = 2100.0
	slope = [0.0, sx]
	place(BASE_KIT, Vector3(sx, 10.0, 500.0))
	place(BASE_KIT, Vector3(sx, 10.3, 500.0))
	var upper: Dictionary = {}

	for id in rows_of(BASE_KIND):
		var p: Vector3 = items._items[id]["pos"]

		if absf(p.x - sx) < 0.1 and absf(p.y - 12.0) < 0.1:
			upper = items._items[id]

	check(not upper.is_empty(), "aiming at the middle stacks a second foundation 2 m up (%s)" % str(said))

	if not upper.is_empty():
		_walls_on(cfg, anchors, upper["pos"], (upper["pos"] as Vector3).y + float(cfg["structures"][BASE_KIND]["top_m"]), "stacked foundation")


func _walls_on(cfg: Dictionary, anchors: Array, base: Vector3, top: float, label: String) -> void:
	var walls_before: int = rows_of(WALL_KIND).size()
	var placed: int = 0
	var why: Array = []

	for a in anchors:
		# Aimed a little off the anchor, as a cursor is: the corner anchors of two sides are 1.4 m apart.
		var aim: Vector3 = Vector3(base.x + float(a[0]) * 1.0 + 0.2 * signf(float(a[0])), top, base.z + float(a[1]) + 0.2 * signf(float(a[1])))
		var count: int = rows_of(WALL_KIND).size()
		place(WALL_KIT, aim, int(a[2]))

		if rows_of(WALL_KIND).size() == count + 1:
			placed += 1
			var newest: int = items._next_id - 1

			if placed % 2 == 0 and items._items.has(newest):   # every other neighbour is a blueprint site, the rest are built walls
				items._items[newest]["struct"]["site"] = {"bp": 30, "have": {}}
		else:
			why.append("%s: %s" % [str(a), str(said)])

	check(placed == anchors.size() and rows_of(WALL_KIND).size() == walls_before + anchors.size(), "%s: all %d wall anchors take a Crude - Wall beside built walls and blueprint sites (%d placed; %s)" % [label, anchors.size(), placed, str(why)])

	for id in rows_of(WALL_KIND).slice(walls_before):
		var y: float = (items._items[id]["pos"] as Vector3).y
		check(absf(y - top) < 0.01, "%s: the wall stands on the foundation top (y %.2f, top %.2f)" % [label, y, top])
		break
