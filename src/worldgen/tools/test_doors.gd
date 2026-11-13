extends SceneTree

# Separate doors in empty doorway frames (BUGLIST-002, DOOR-001; contract docs/ai-team/missions/BUGLIST-002/CONTRACT.md). A door is its own blueprint piece
# (structures.json attach_to "doorway") and hangs in a doorway frame (a row with "opening") of the same opening, whatever the tier or material. Through the
# real PlacementRules (the ghost's rules) and a real server (ServerItems.place_piece, E, take-down, save and load, the structure grid):
#   data: 28 doors (7 tiers x 4 openings) each with an open twin, every frame empty, the retired open twins mapped to their frames;
#   rules: the door snaps to the frame's spot and turn for all 4 openings, ghost and server alike; "nodoorway", "mismatch" for every wrong pairing (with
#   the shape the doorway takes in words), "taken" by a shut or an open door; a Fortified door in a Crude frame is fine;
#   server: all 28 doors placed, opened, shut, taken down (refund exactly the cost, frame stays), a frame with a door refused take-down, E on a frame nothing,
#   shut doors stop walkers across the opening only, save and reload (open state kept, no duplicates, a legacy open twin loads as the frame).
#   godot --headless --path . --script res://src/worldgen/tools/test_doors.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Rules := preload("res://src/shared/placement_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const TIERS := ["crude", "rustic", "refined", "sturdy", "superior", "engineered", "fortified"]
const OPENINGS := ["single", "double", "single_arched", "double_arched"]
const OPENING_WIDTH := {"single": 1.0, "double": 2.0, "single_arched": 1.0, "double_arched": 2.0}
const FRAME_WIDTH := {"single": 2.0, "double": 4.0, "single_arched": 2.0, "double_arched": 4.0}
const LEGACY := {"thatch_doorway_open": "thatch_doorway", "log_doorway_open": "log_doorway", "door_open": "doorway_section", "stone_doorway_open": "stone_doorway",
	"brick_doorway_open": "brick_doorway", "engineered_doorway_open": "engineered_doorway", "fortified_doorway_open": "fortified_doorway",
	"double_doorway_open": "double_doorway", "iron_doorway_open": "iron_doorway", "steel_doorway_open": "steel_doorway"}

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var cfg: Dictionary = Rules.load_config()
	var structures: Dictionary = cfg["structures"]
	_data_checks(structures)
	_rule_checks(cfg)
	_server_checks(cfg)
	print("test_doors: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# The kinds of a door's rows: shut ones (no "_open" suffix) in a dictionary kind -> row.
func _shut_doors(structures: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for kind in structures:
		var row: Dictionary = structures[kind]

		if str(row.get("attach_to", "")) == "doorway" and not str(kind).ends_with("_open"):
			out[kind] = row

	return out


func _frames(structures: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for kind in structures:
		var row: Dictionary = structures[kind]

		if str(row.get("opening", "")) != "" and str(row.get("attach_to", "")) != "doorway":
			out[kind] = row

	return out


# The first frame kind with an opening (the 28 doors then hang in frames of other tiers and materials as often as not: tier never matters).
func _frame_for(frames: Dictionary, opening: String) -> String:
	for kind in frames:
		if str(frames[kind]["opening"]) == opening:
			return kind

	return ""


func _data_checks(structures: Dictionary) -> void:
	var doors: Dictionary = _shut_doors(structures)
	check(doors.size() == 28, "there are 28 doors: 7 tiers x 4 openings (%d)" % doors.size())
	var grid: Dictionary = {}
	var states: Dictionary = {}

	for kind in doors:
		var row: Dictionary = doors[kind]
		var open: Dictionary = structures.get(str(row.get("toggle", "")), {})
		var shape: String = str(row.get("opening", ""))
		grid["%s/%s" % [row.get("tier", ""), shape]] = kind
		check(str(row.get("toggle", "")) == "%s_open" % kind and not open.is_empty() and str(open.get("toggle", "")) == kind, "%s: shut and open twin toggle to each other" % kind)
		check(bool(row.get("piece", false)) and str(row.get("piece_kind", "")) == "door" and str(row.get("use", "")) == "door" and OPENING_WIDTH.has(shape), "%s: a door piece that E works, with an opening" % kind)
		check(str(open.get("opening", "")) == shape and str(open.get("attach_to", "")) == "doorway" and str(open.get("piece_kind", "")) == "door" and str(open.get("use", "")) == "door", "%s: the open twin is the same door" % kind)
		check(float(row.get("grid_x", 0.0)) == float(FRAME_WIDTH.get(shape, -1.0)) and not open.has("grid_x"), "%s: shut, it blocks animals across its whole frame (grid_x)" % kind)
		check(float(row.get("footprint_x", 0.0)) == float(OPENING_WIDTH.get(shape, -1.0)) and float(row.get("footprint_z", 0.0)) == 0.1 and float(open.get("footprint_x", 0.0)) == float(row.get("footprint_x", 0.0)), "%s: as wide as its opening, 0.1 m thick" % kind)
		check(bool(row.get("blocks_walk", false)) and not open.has("blocks_walk") and not open.has("variant_group") and not row.has("variant_group"), "%s: shut it stops walkers, open it does not, and it is no wall variant" % kind)
		check(int(row.get("use_pace_ms", 0)) == 400 and float(row.get("use_reach_m", 0.0)) == 3.0 and bool(row.get("gap_exempt", false)) and int(row.get("cap_per_chunk", 0)) == 200, "%s: pace, reach, gap exemption and cap" % kind)
		check(str(row["kit"]) == str(row["item"]) and str(open["kit"]) == str(row["kit"]), "%s: one item for both states" % kind)
		check(not states.has(int(row["state"])) and not states.has(int(open["state"])), "%s: its states are its own" % kind)
		states[int(row["state"])] = true
		states[int(open["state"])] = true

	for tier in TIERS:
		for shape in OPENINGS:
			check(grid.has("%s/%s" % [tier, shape]), "a %s %s door exists" % [tier, shape])

	var frames: Dictionary = _frames(structures)
	check(frames.size() >= 28, "there are doorway frames for all four openings and seven tiers (%d)" % frames.size())

	for kind in frames:
		var row: Dictionary = frames[kind]
		check(not row.has("use") and not row.has("toggle") and not bool(row.get("blocks_walk", false)) and str(row.get("piece_kind", "")) == "wall", "%s: an empty frame, no door, no use, never solid" % kind)
		check(float(row.get("footprint_x", 0.0)) == float(FRAME_WIDTH.get(str(row["opening"]), -1.0)), "%s: %s frame, %.0f m piece" % [kind, row["opening"], float(row.get("footprint_x", 0.0))])

	for shape in OPENINGS:
		check(_frame_for(frames, shape) != "", "a frame with a %s opening exists" % shape)

	for old in LEGACY:
		check(not structures.has(old) and (structures[LEGACY[old]].get("legacy_kinds", []) as Array).has(old), "the retired %s is a legacy kind of %s" % [old, LEGACY[old]])

	check(not structures.keys().any(func(k): return str(k).ends_with("doorway_open")), "no doorway toggles to an open twin any more")


func _rows_of(frame_state: int, at: Vector3, yaw: float, extra: Array = []) -> Array:
	return [{"pos": at, "state": frame_state, "yaw": yaw}] + extra


func _rule_checks(cfg: Dictionary) -> void:
	var structures: Dictionary = cfg["structures"]
	var doors: Dictionary = _shut_doors(structures)
	var frames: Dictionary = _frames(structures)
	var at: Vector3 = Vector3(300.0, 10.0, 300.0)

	for shape in OPENINGS:
		var frame_kind: String = _frame_for(frames, shape)
		var door_kind: String = ""

		for kind in doors:
			if str(doors[kind]["opening"]) == shape:
				door_kind = kind

		var rows: Array = _rows_of(int(frames[frame_kind]["state"]), at, 90.0)
		var kit: String = str(doors[door_kind]["kit"])

		for aim in [at + Vector3(0.1, 0.5, 0.2), at + Vector3(0.0, 1.5, -0.3), at + Vector3(0.0, 0.0, 1.2), at + Vector3(float(FRAME_WIDTH[shape]) * 0.5 - 0.2, 0.2, 0.0).rotated(Vector3.UP, -PI * 0.5)]:
			var answer: Array = Rules.snap(cfg, kit, aim, 0, rows)
			check(bool(answer[2]) and (answer[0] as Vector3).is_equal_approx(at) and int(answer[1]) == 90 and Rules.blocked(cfg, kit, answer[0], rows) == "", "%s: aimed at its %s frame it snaps to the frame's spot and turn (%s)" % [door_kind, shape, str(aim)])

		var again: Array = Rules.snap(cfg, kit, at, 90, rows)
		check(again[0] == at and int(again[1]) == 90, "%s: the snapped answer snaps to itself" % door_kind)
		var far: Vector3 = at + Vector3(6.0, 0.5, 0.0)
		var lost: Array = Rules.snap(cfg, kit, far, 0, rows)
		check(not bool(lost[2]) and lost[0] == far and Rules.blocked(cfg, kit, far, rows) == "nodoorway" and Rules.blocked(cfg, kit, far, []) == "nodoorway", "%s: far from any doorway it is red, nodoorway" % door_kind)
		check(Rules.blocked(cfg, kit, at + Vector3(0.0, 4.0, 0.0), rows) == "nodoorway", "%s: a doorway storey below does not take it" % door_kind)
		check(Rules.reason_text("nodoorway") != "", "nodoorway says why")

		for twin in [door_kind, door_kind + "_open"]:
			var hung: Array = rows + [{"pos": at, "state": int(structures[twin]["state"]), "yaw": 90.0}]
			check(Rules.blocked(cfg, kit, at, hung) == "taken" and Rules.reason_text("taken", shape).contains("door already"), "%s: a %s door in the doorway takes it" % [door_kind, "shut" if twin == door_kind else "open"])

		check(Rules.blocked(cfg, kit, at, rows + [{"pos": at + Vector3(6.0, 0.0, 0.0), "state": int(structures[door_kind]["state"]), "yaw": 0.0}]) == "", "%s: a door in another doorway does not take this one" % door_kind)

		for other in OPENINGS:
			if other == shape:
				continue

			var wrong: String = _frame_for(frames, other)
			var wrong_rows: Array = _rows_of(int(frames[wrong]["state"]), at, 0.0)
			var fit: Dictionary = Rules.doorway_fit(cfg, structures[door_kind], at, wrong_rows)
			var words: String = Rules.reason_text("mismatch", other)
			check(Rules.blocked(cfg, kit, at, wrong_rows) == "mismatch" and str(fit["opening"]) == other and words.ends_with("takes " + str(Rules.OPENING_DOORS[other])) and not words.contains("single"), "a %s door in a %s doorway: mismatch, '%s'" % [shape, other, words])
			check(bool(Rules.snap(cfg, kit, at + Vector3(0.1, 0.5, 0.1), 0, wrong_rows)[2]), "and its ghost sits on that doorway, red")

	# Tier and material never matter: a Fortified door in a Crude frame and a Crude door in a Fortified frame.
	var crude_frame: Array = _rows_of(int(structures["thatch_doorway"]["state"]), at, 0.0)
	check(Rules.blocked(cfg, str(structures["fortified_door"]["kit"]), at, crude_frame) == "", "a Fortified door goes in a Crude doorway")
	var fort_frame: Array = _rows_of(int(structures["fortified_doorway"]["state"]), at, 0.0)
	check(Rules.blocked(cfg, str(structures["crude_door"]["kit"]), at, fort_frame) == "", "a Crude door goes in a Fortified doorway")

	# The nearest frame takes it: two doorways 5 m apart, the cursor beside the second.
	var pair: Array = _rows_of(int(structures["thatch_doorway"]["state"]), at, 0.0, [{"pos": at + Vector3(5.0, 0.0, 0.0), "state": int(structures["thatch_double_doorway"]["state"]), "yaw": 0.0}])
	check(Rules.snap(cfg, str(structures["rustic_double_door"]["kit"]), at + Vector3(4.6, 0.5, 0.1), 0, pair)[0] == at + Vector3(5.0, 0.0, 0.0) and Rules.blocked(cfg, str(structures["rustic_double_door"]["kit"]), at + Vector3(5.0, 0.0, 0.0), pair) == "", "the doorway nearest the cursor takes the door")
	check(Rules.blocked(cfg, str(structures["rustic_double_door"]["kit"]), at, pair) == "mismatch", "and the one beside it is another shape")

	# A frame is never a door and a door never a frame: a door row is not a doorway for another door.
	var only_door: Array = [{"pos": at, "state": int(structures["rustic_door"]["state"]), "yaw": 0.0}]
	check(Rules.blocked(cfg, str(structures["sturdy_door"]["kit"]), at, only_door) == "nodoorway", "a door alone is no doorway")


# --- server ---

func _server(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.send_notice = func(_p, text): said.append(str(text))
	return items


func _find(items, kind: String, near: Vector3 = Vector3(INF, 0.0, 0.0)) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind and (is_inf(near.x) or (items._items[id]["pos"] as Vector3).distance_to(near) < 1.0):
			return id

	return 0


func _count(items, kind: String) -> int:
	var n: int = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			n += 1

	return n


func _all_rows(items) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct"):
			var p: Vector3 = items._items[id]["pos"]
			out.append([str(items._items[id]["struct"]["kind"]), snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(float(items._items[id]["struct"]["yaw"]), 0.1)])

	out.sort()
	return out


func _stand(items, at: Vector3) -> void:
	items.report_position(1, at + Vector3(0.0, 0.0, 2.0))
	items._last_use.clear()   # the door pace is its own test below


func _use(items, id: int) -> void:
	items._last_use.clear()
	items.action(1, Net.ACT_USE_STRUCT, id, 0, 0, Vector3.ZERO)


func _hang(items, door_kit: String, at: Vector3) -> void:   # aims the way a player does, near the frame, not exactly at it
	_stand(items, at)
	items.place_piece(1, door_kit, at + Vector3(0.1, 0.4, 0.15), 0)


func _server_checks(cfg: Dictionary) -> void:
	var structures: Dictionary = cfg["structures"]
	var doors: Dictionary = _shut_doors(structures)
	var frames: Dictionary = _frames(structures)
	var dir: String = "user://test_doors"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = _server(dir)
	items.peer_connected_hello(1, "doorskey000001")
	items.report_position(1, Vector3(100.0, 10.0, 102.0))
	var n: int = 0

	# All 28 doors: placed into a frame of their opening, at its spot and turn, shut -> open -> shut with E; the frame stays when the door comes out.
	for door_kind in doors:
		var def: Dictionary = doors[door_kind]
		var shape: String = str(def["opening"])
		var frame_kind: String = _frame_for(frames, shape)
		var at: Vector3 = Vector3(100.0 + float(n % 7) * 10.0, 10.0, 100.0 + float(floori(float(n) / 7.0)) * 10.0)
		var yaw: int = 90 if n % 2 == 1 else 0
		n += 1
		_stand(items, at)
		items.place_piece(1, str(frames[frame_kind]["kit"]), at, yaw)
		check(_count(items, frame_kind) >= 1 and _find(items, frame_kind, at) != 0, "%s: its %s frame stands" % [door_kind, frame_kind])
		_hang(items, str(def["kit"]), at)
		var id: int = _find(items, door_kind, at)
		check(id != 0 and (items._items[id]["pos"] as Vector3).is_equal_approx(at) and int(items._items[id]["struct"]["yaw"]) == yaw, "%s: hangs in the frame at its spot and turn" % door_kind)

		if id == 0:
			continue

		check(items._struct_state(items._items[id]) == int(def["state"]), "%s: shut state" % door_kind)
		_use(items, id)
		check(str(items._items[id]["struct"]["kind"]) == str(def["toggle"]) and items._struct_state(items._items[id]) == int(structures[str(def["toggle"])]["state"]), "%s: E opens it" % door_kind)
		_use(items, id)
		check(str(items._items[id]["struct"]["kind"]) == door_kind, "%s: E shuts it again" % door_kind)
		var along: Vector3 = Vector3(cos(deg_to_rad(float(yaw))), 0.0, -sin(deg_to_rad(float(yaw))))   # the frame's x axis in the world
		var half: float = float(OPENING_WIDTH[shape]) * 0.5
		var frame_half: float = float(FRAME_WIDTH[shape]) * 0.5   # grid_x: shut, the door stops animals across its whole frame, jambs too (the frame itself has no blocks_walk)
		check(items.structure_blocks(at.x, at.z, 0.0) and items.structure_blocks(at.x + along.x * (half - 0.05), at.z + along.z * (half - 0.05), 0.0), "%s: shut, it stops walkers across its opening" % door_kind)
		check(items.structure_blocks(at.x + along.x * (frame_half - 0.05), at.z + along.z * (frame_half - 0.05), 0.0) and items.structure_blocks(at.x - along.x * (frame_half - 0.05), at.z - along.z * (frame_half - 0.05), 0.0), "%s: shut, its frame's jambs stop walkers too" % door_kind)
		check(not items.structure_blocks(at.x + along.x * (frame_half + 0.2), at.z + along.z * (frame_half + 0.2), 0.0) and not items.structure_blocks(at.x - along.z * 0.6, at.z + along.x * 0.6, 0.0), "%s: and nothing past its frame or in front of it" % door_kind)
		_use(items, id)
		check(not items.structure_blocks(at.x, at.z, 0.0), "%s: open, walkers pass" % door_kind)
		_use(items, id)
		check(items.structure_blocks(at.x, at.z, 0.0) and _count(items, door_kind) == 1 and _count(items, str(def["toggle"])) == 0, "%s: shut again it blocks again, one row" % door_kind)

	# An empty frame lets walkers through and E on it does nothing (and offers nothing: no use, no toggle).
	var empty: Vector3 = Vector3(100.0, 10.0, 200.0)
	_stand(items, empty)
	items.place_piece(1, "log_doorway_kit", empty, 0)
	var empty_id: int = _find(items, "log_doorway", empty)
	check(empty_id != 0 and not items.structure_blocks(empty.x, empty.z, 0.0), "an empty frame is a passage")
	_use(items, empty_id)
	check(str(items._items[empty_id]["struct"]["kind"]) == "log_doorway", "E on an empty frame does nothing")

	# No doorway near: refused, saying so.
	said.clear()
	_stand(items, Vector3(150.0, 10.0, 150.0))
	items.place_piece(1, "rustic_door", Vector3(150.0, 10.0, 150.0), 0)
	check(_count(items, "rustic_door") == 1 and said.size() > 0 and str(said[-1]).contains("doorway"), "a door aimed at open ground is refused, saying a door goes in a doorway (%s)" % (str(said[-1]) if said.size() > 0 else "nothing said"))
	check(_find(items, "rustic_door", Vector3(150.0, 10.0, 150.0)) == 0, "and nothing stands there")

	# Wrong shapes: every wrong pairing is refused with the shape the doorway takes in the message, and nothing is placed.
	var pairs: Dictionary = {}

	for shape in OPENINGS:
		for kind in doors:
			if str(doors[kind]["opening"]) == shape:
				pairs[shape] = kind

	var wrong_at: Vector3 = Vector3(100.0, 10.0, 300.0)
	var spots: int = 0

	for frame_shape in OPENINGS:
		var spot: Vector3 = wrong_at + Vector3(float(spots) * 10.0, 0.0, 0.0)
		spots += 1
		_stand(items, spot)
		items.place_piece(1, str(frames[_frame_for(frames, frame_shape)]["kit"]), spot, 0)

		for door_shape in OPENINGS:
			if door_shape == frame_shape:
				continue

			var before: int = items._items.size()
			said.clear()
			_hang(items, str(doors[pairs[door_shape]]["kit"]), spot)
			check(items._items.size() == before and said.size() > 0 and str(said[-1]).contains("takes " + str(Rules.OPENING_DOORS[frame_shape]) + "."), "a %s door in a %s doorway is refused (%s)" % [door_shape, frame_shape, str(said[-1]) if said.size() > 0 else "nothing said"])

	# A Fortified door in a Crude frame, a Crude door in a Fortified one; a second door in the same doorway is refused.
	var mix: Vector3 = Vector3(100.0, 10.0, 400.0)
	_stand(items, mix)
	items.place_piece(1, "thatch_doorway_kit", mix, 0)
	_hang(items, "fortified_door", mix)
	check(_find(items, "fortified_door", mix) != 0, "a Fortified door hangs in a Crude doorway")
	said.clear()
	_hang(items, "crude_door", mix)
	check(_find(items, "crude_door", mix) == 0 and said.size() > 0 and str(said[-1]).contains("door already"), "a second door is refused: the doorway has one (%s)" % (str(said[-1]) if said.size() > 0 else "nothing said"))
	var fort: Vector3 = Vector3(110.0, 10.0, 400.0)
	_stand(items, fort)
	items.place_piece(1, "fortified_doorway_kit", fort, 0)
	_hang(items, "crude_door", fort)
	check(_find(items, "crude_door", fort) != 0, "a Crude door hangs in a Fortified doorway")
	_stand(items, mix)
	_use(items, _find(items, "fortified_door", mix))
	said.clear()
	_hang(items, "rustic_door", mix)
	check(_find(items, "rustic_door", mix) == 0 and said.size() > 0, "an open door still holds its doorway")

	# Take-down: a frame holding a door is refused; the door comes out (open or shut) and refunds exactly its cost; the frame stays; a new door goes in.
	var inv = items.inventory_of(1)
	var frame_id: int = _find(items, "thatch_doorway", mix)
	said.clear()
	items.action(1, Net.ACT_PICKUP, frame_id, 0, 0, Vector3.ZERO)
	check(_find(items, "thatch_doorway", mix) != 0 and _find(items, "fortified_door_open", mix) != 0 and said.size() > 0 and str(said[-1]) == "Take the door out first.", "a doorway with a door in it will not come down: Take the door out first. (%s)" % (str(said[-1]) if said.size() > 0 else "nothing said"))

	# The same frame while it is still a blueprint site: it will not come down either (the site path used to skip the guard and leave the door floating).
	items._items[frame_id]["struct"]["site"] = {"bp": 32, "have": {}}
	said.clear()
	items.action(1, Net.ACT_PICKUP, frame_id, 0, 0, Vector3.ZERO)
	check(_find(items, "thatch_doorway", mix) != 0 and said.size() > 0 and str(said[-1]) == "Take the door out first.", "a doorway still a site with a door in it will not come down either (%s)" % (str(said[-1]) if said.size() > 0 else "nothing said"))
	items._items[frame_id]["struct"].erase("site")

	var cases: Array = [["fortified_door_open", "thatch_doorway", mix]]

	for door_kind in ["rustic_double_door", "refined_arched_door"]:
		var frame_here: String = _frame_for(frames, str(doors[door_kind]["opening"]))
		var spot: Vector3 = Vector3(200.0 + float(spots) * 10.0, 10.0, 400.0)
		spots += 1
		_stand(items, spot)
		items.place_piece(1, str(frames[frame_here]["kit"]), spot, 0)
		_hang(items, door_kind, spot)
		cases.append([door_kind, frame_here, spot])

	for case in cases:
		var door_kind: String = case[0]
		var spot: Vector3 = case[2]
		var bp: Dictionary = items._blueprints[int(items._blueprint_of_kit[door_kind.trim_suffix("_open")])]
		var door_id: int = _find(items, door_kind, spot)
		check(door_id != 0, "%s: stands, to be taken down" % door_kind)

		if door_id == 0:
			continue

		var want: Dictionary = {}

		for need in bp["cost"]:
			var number: int = items._refund_number(items.table.number_of(str(need[0])))
			want[number] = int(want.get(number, 0)) + int(need[1])

		var had: Dictionary = {}

		for number in want:
			had[number] = inv.count_of(number)

		_stand(items, spot)
		items.action(1, Net.ACT_PICKUP, door_id, 0, 0, Vector3.ZERO)
		var refunded: bool = true

		for number in want:
			refunded = refunded and inv.count_of(number) - int(had[number]) == int(want[number])

		check(_find(items, door_kind, spot) == 0 and refunded, "%s: taken down it gives back exactly its blueprint cost %s" % [door_kind, str(bp["cost"])])
		check(_find(items, str(case[1]), spot) != 0, "%s: the %s is left standing" % [door_kind, case[1]])

	_stand(items, mix)   # the take-down cases above left the player at the last of their spots, out of reach of this doorway
	frame_id = _find(items, "thatch_doorway", mix)
	items.action(1, Net.ACT_PICKUP, frame_id, 0, 0, Vector3.ZERO)
	check(_find(items, "thatch_doorway", mix) == 0, "with the door out the doorway comes down")
	items.place_piece(1, "thatch_doorway_kit", mix, 0)
	_hang(items, "sturdy_door", mix)
	check(_find(items, "sturdy_door", mix) != 0, "a replacement door goes into a rebuilt doorway")

	# The door's pace: not faster than 400 ms, as every door.
	var paced: int = _find(items, "sturdy_door", mix)
	items._last_use.clear()
	items.action(1, Net.ACT_USE_STRUCT, paced, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_USE_STRUCT, paced, 0, 0, Vector3.ZERO)
	check(str(items._items[paced]["struct"]["kind"]) == "sturdy_door_open", "the door will not flap faster than its pace")
	items.report_position(1, Vector3(5000.0, 10.0, 5000.0))
	items._last_use.clear()
	items.action(1, Net.ACT_USE_STRUCT, paced, 0, 0, Vector3.ZERO)
	check(str(items._items[paced]["struct"]["kind"]) == "sturdy_door_open", "and a player out of reach cannot work it")

	# Save and load: frames, shut and open doors keep their kind, spot and turn, none twice; a legacy open twin loads as its frame and gets no door.
	items.report_position(1, Vector3(100.0, 10.0, 102.0))
	var legacy_at: Vector3 = Vector3(100.0, 10.0, 500.0)
	_stand(items, legacy_at)
	items.place_piece(1, "stone_doorway_kit", legacy_at, 0)
	var legacy_id: int = _find(items, "stone_doorway", legacy_at)
	items._items[legacy_id]["struct"]["kind"] = "stone_doorway_open"   # what an old save holds
	var turned_at: Vector3 = Vector3(110.0, 10.0, 500.0)
	_stand(items, turned_at)
	items.place_piece(1, "double_doorway_kit", turned_at, 90)
	_hang(items, "superior_double_door", turned_at)
	_use(items, _find(items, "superior_double_door", turned_at))
	var before_save: Array = _all_rows(items)
	items._dirty = true
	items.save()
	items._finish_writer()
	var again = _server(dir)
	again.peer_connected_hello(1, "doorskey000001")
	var after: Array = _all_rows(again)
	var expect: Array = []

	for row in before_save:
		var copy: Array = (row as Array).duplicate()

		if copy[0] == "stone_doorway_open":
			copy[0] = "stone_doorway"

		expect.append(copy)

	expect.sort()
	check(after == expect and after.size() == before_save.size(), "every frame and door stands again after a save and a reload, none twice (%d rows)" % after.size())
	check(_find(again, "superior_double_door_open", turned_at) != 0 and _find(again, "superior_double_door", turned_at) == 0 and _find(again, "stone_doorway", legacy_at) != 0 and _count(again, "stone_doorway_open") == 0, "the open double door is still open, the legacy open twin is its empty frame")   # by spot: the 28-door run above left other doors and frames of these kinds standing
	check(_find(again, "superior_double_door_open", turned_at) != 0 and int(again._items[_find(again, "superior_double_door_open", turned_at)]["struct"]["yaw"]) == 90, "and keeps its turn")
	check(not again.structure_blocks(turned_at.x, turned_at.z, 0.0), "an open door still lets walkers through after a reload")
	check(again.structure_blocks(100.0, 100.0, 0.0), "a shut door is solid again after a reload")

	for old in LEGACY:
		check(again._kind_now(old) == LEGACY[old], "a saved %s loads as %s" % [old, LEGACY[old]])
