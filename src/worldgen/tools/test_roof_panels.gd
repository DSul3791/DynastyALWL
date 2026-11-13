extends SceneTree

# Crude - Roof 45 and Crude - Roof 65 (BUG-011, BUGLIST-001): a sloped roof PANEL only, no posts, either end resting on a wall top, a ceiling edge or another
# panel's end, rising or falling from it. Data (names, ids, numbers kept), the shared snap rules (both slopes x both anchored ends x both facings, the answer
# snapping to itself, ceiling edges, a chain of panels, a ridge), the server's refusals (nothing to rest on, into the ground, a second on the same spot),
# saved and loaded, the cover box under it, and the mesh and collider (no legs, the slab's two ends where the rules say).
#   godot --headless --path . --script res://src/worldgen/tools/test_roof_panels.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Rules := preload("res://src/shared/placement_rules.gd")
const Cover := preload("res://src/shared/cover.gd")
const LookTable := preload("res://src/client/look_table.gd")

const KITS := {45: "thatch_roof_kit", 65: "thatch_roof_65"}

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.001


# Where the anchored end of the panel `answer` ([middle, yaw, on_base]) of `def` lies: the low end (mode 0) or the high end (mode 1), as the rules put it.
func _anchored_end(def: Dictionary, answer: Array, mode: int) -> Vector3:
	var turn: float = deg_to_rad(float(answer[1]))
	var rising: Vector2 = Vector2(-sin(turn), -cos(turn))
	var half_run: float = float(def["run_m"]) * 0.5
	var half_rise: float = Rules.roof_panel_rise(def) * 0.5
	var end: float = 1.0 if mode > 0 else -1.0   # the high end is at +rising, the low end at -rising
	var middle: Vector3 = answer[0]
	return Vector3(middle.x + end * rising.x * half_run, middle.y + end * half_rise, middle.z + end * rising.y * half_run)


func _mesh_box(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false

	return box


func _solid_at(node: Node3D, point: Vector3) -> bool:
	for child in node.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = child
		var shape: BoxShape3D = cs.shape as BoxShape3D

		if shape == null:
			continue

		var local: Vector3 = (node.global_transform.affine_inverse() * cs.global_transform).affine_inverse() * point

		if absf(local.x) <= shape.size.x * 0.5 and absf(local.y) <= shape.size.y * 0.5 and absf(local.z) <= shape.size.z * 0.5:
			return true

	return false


func _data_checks(cfg: Dictionary) -> void:
	var blueprints: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json")) as Dictionary)["blueprints"]
	var items: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json")) as Dictionary)["items"]
	var enc: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/encyclopedia.json")) as Dictionary)["items"]
	var s45: Dictionary = cfg["structures"]["thatch_roof"]
	var s65: Dictionary = cfg["structures"]["thatch_roof_65"]
	check(str(blueprints["thatch_roof"]["name"]) == "Crude - Roof 45" and int(blueprints["thatch_roof"]["number"]) == 31 and str(blueprints["thatch_roof"]["structure"]) == "thatch_roof", "the old roof is Crude - Roof 45 and keeps its id, number and structure")
	check(str(blueprints["thatch_roof_65"]["name"]) == "Crude - Roof 65" and str(blueprints["thatch_roof_65"]["structure"]) == "thatch_roof_65" and blueprints["thatch_roof_65"]["cost"] == blueprints["thatch_roof"]["cost"], "Crude - Roof 65 is a blueprint on the same materials")
	var numbers: Dictionary = {}

	for id in blueprints:
		numbers[int(blueprints[id]["number"])] = int(numbers.get(int(blueprints[id]["number"]), 0)) + 1

	check(int(numbers[int(blueprints["thatch_roof_65"]["number"])]) == 1, "its blueprint number is its own")
	var states: Dictionary = {}

	for kind in cfg["structures"]:
		if typeof(cfg["structures"][kind]) == TYPE_DICTIONARY and (cfg["structures"][kind] as Dictionary).has("state"):
			states[int(cfg["structures"][kind]["state"])] = int(states.get(int(cfg["structures"][kind]["state"]), 0)) + 1

	check(int(s45["state"]) == 43 and int(s65["state"]) == 291 and int(states[43]) == 1 and int(states[291]) == 1, "the 45 keeps state 43 and the 65 has a state of its own")
	check(str(items["thatch_roof"]["name"]) == "Crude - Roof 45" and int(items["thatch_roof"]["number"]) == 264 and str(items["thatch_roof_65"]["name"]) == "Crude - Roof 65" and int(items["thatch_roof_65"]["number"]) == 1255, "the items carry the names and the 45 keeps 264")
	check(str(enc["thatch_roof"]["name"]) == "Crude - Roof 45" and enc.has("thatch_roof_65") and str(enc["thatch_roof_65"]["name"]) == "Crude - Roof 65", "the encyclopedia has both")

	for def in [s45, s65]:
		check(str(def["piece_kind"]) == Rules.ROOF_PANEL_KIND and float(def["footprint_x"]) == 2.0, "%s is a roof panel 2 m wide" % str(def["item"]))
		check(float(def["cover_below_m"]) >= Rules.roof_panel_rise(def) * 0.5 + Rules.WALL_HEIGHT_M, "%s: its cover box reaches down to the floor under a wall-top panel" % str(def["item"]))

	check(is_equal_approx(Rules.roof_panel_rise(s45), 2.0) and absf(Rules.roof_panel_rise(s65) - 4.2891) < 0.001, "the rise over the 2 m run is 2 m at 45 degrees and 4.29 m at 65")


func _snap_checks(cfg: Dictionary) -> void:
	var wall_state: int = int(cfg["structures"]["wall_section"]["state"])
	var top: Vector3 = Vector3(300.0, 12.7, 300.0)
	var wall: Array = [{"pos": Vector3(300.0, 10.3, 300.0), "state": wall_state, "yaw": 0.0}]
	var cursor: Vector3 = Vector3(300.1, 12.0, 300.1)

	for slope in KITS:
		var kit: String = KITS[slope]
		var def: Dictionary = Rules.structure_of_kit(cfg, kit)
		var rise: float = Rules.roof_panel_rise(def)

		for yaw in [0, 180]:        # facing -Z (the panel rises toward -Z) or +Z
			for mode in [0, 1]:
				var answer: Array = Rules.snap(cfg, kit, cursor, yaw, wall, mode)
				var label: String = "%d degrees, facing %d, %s" % [slope, yaw, "falling from the wall top" if mode == 1 else "rising from it"]
				var forward: float = -1.0 if yaw == 0 else 1.0
				check(bool(answer[2]) and int(answer[1]) == yaw, "%s: rests on the wall top, turned as the player faced (%s)" % [label, str(answer)])
				check(_near(_anchored_end(def, answer, mode), top), "%s: the anchored end is the wall top's middle (%s)" % [label, str(_anchored_end(def, answer, mode))])
				var middle: Vector3 = answer[0]
				var expect_z: float = 300.0 + forward * (1.0 if mode == 0 else -1.0)
				check(absf(middle.z - expect_z) < 0.001 and absf(middle.y - (top.y + (rise * 0.5 if mode == 0 else -rise * 0.5))) < 0.001 and absf(middle.x - 300.0) < 0.001, "%s: the middle is half a run and half a rise from it (%s)" % [label, str(middle)])
				check(Rules.snap(cfg, kit, answer[0], int(answer[1]), wall, mode)[0] == answer[0], "%s: the answer snaps to itself (the client sends the ghost's middle, the server snaps again)" % label)

		var along: Array = Rules.snap(cfg, kit, cursor, 90, wall, 0)
		check(not bool(along[2]), "%d degrees: looking along the wall top there is no edge across the facing, so it is not placed on one" % slope)

	# Two walls 2 m apart: a panel from one reaches the other, and its own answer does not jump to the other wall.
	var two: Array = wall + [{"pos": Vector3(300.0, 10.3, 298.0), "state": wall_state, "yaw": 0.0}]
	var def45: Dictionary = Rules.structure_of_kit(cfg, "thatch_roof_kit")
	var span: Array = Rules.snap(cfg, "thatch_roof_kit", Vector3(300.0, 12.0, 300.2), 0, two, 0)
	check(Rules.snap(cfg, "thatch_roof_kit", span[0], 0, two, 0)[0] == span[0] and _near(_anchored_end(def45, span, 0), top), "between two walls the panel stays on the wall it was set on")

	# A ceiling's edge: the 2 m floor piece's top edge.
	var ceiling_state: int = int(cfg["structures"]["floor_section"]["state"])
	var ceiling: Array = [{"pos": Vector3(310.0, 10.0, 310.0), "state": ceiling_state, "yaw": 0.0}]
	var on_ceiling: Array = Rules.snap(cfg, "thatch_roof_kit", Vector3(310.0, 10.1, 309.2), 0, ceiling, 0)
	check(bool(on_ceiling[2]) and _near(_anchored_end(def45, on_ceiling, 0), Vector3(310.0, 10.0 + Rules.CEILING_TOP_M, 309.0)), "a panel rests on a ceiling's edge (%s)" % str(on_ceiling))

	# A chain: a second panel on the first one's high end continues the slope; facing back it falls the far side, a ridge.
	var first: Array = Rules.snap(cfg, "thatch_roof_kit", cursor, 0, wall, 0)
	var panel_rows: Array = wall + [{"pos": first[0], "state": int(def45["state"]), "yaw": float(first[1])}]
	var high_end: Vector3 = Vector3(300.0, top.y + 2.0, 298.0)
	var def65: Dictionary = Rules.structure_of_kit(cfg, "thatch_roof_65")
	var steeper: Array = Rules.snap(cfg, "thatch_roof_65", Vector3(300.0, 14.5, 298.2), 0, panel_rows, 0)
	check(bool(steeper[2]) and _near(_anchored_end(def65, steeper, 0), high_end) and (steeper[0] as Vector3).z < 298.0, "a 65 degree panel goes on up from the 45's high end (%s)" % str(steeper))
	var ridge: Array = Rules.snap(cfg, "thatch_roof_kit", Vector3(300.0, 14.5, 298.2), 180, panel_rows, 1)
	check(bool(ridge[2]) and _near(_anchored_end(def45, ridge, 1), high_end) and (ridge[0] as Vector3).z < 298.0 and (ridge[0] as Vector3).y < high_end.y, "facing back and falling, a panel on the high end is the ridge's other side (%s)" % str(ridge))
	var under: Array = Rules.snap(cfg, "thatch_roof_kit", Vector3(300.0, 12.0, 300.3), 0, panel_rows, 0)
	check(under[0] == first[0], "the wall top's own panel is taken: another on it is the same spot")
	check(Rules.blocked(cfg, "thatch_roof_kit", first[0], panel_rows) == "close", "and the ghost says close, like the server")

	# Into the ground.
	var flat: Callable = func(_x, _z): return 10.0
	var falls_65: Array = Rules.snap(cfg, "thatch_roof_65", cursor, 0, wall, 1)
	var falls_45: Array = Rules.snap(cfg, "thatch_roof_kit", cursor, 0, wall, 1)
	check(Rules.roof_panel_buried(cfg, "thatch_roof_65", falls_65[0], int(falls_65[1]), flat), "a 65 degree panel falling from a 2.4 m wall runs into flat ground")
	check(not Rules.roof_panel_buried(cfg, "thatch_roof_kit", falls_45[0], int(falls_45[1]), flat), "a 45 degree one falling from it clears the ground")
	var rises_65: Array = Rules.snap(cfg, "thatch_roof_65", cursor, 0, wall, 0)
	check(not Rules.roof_panel_buried(cfg, "thatch_roof_65", rises_65[0], int(rises_65[1]), flat), "rising from the wall top nothing is buried")
	check(Rules.reason_text("nopanel") != "" and Rules.reason_text("buried") != "", "both red states say why in words")


func _server_checks() -> void:
	var dir: String = "user://test_roof_panels"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = _server(dir)
	items.peer_connected_hello(1, "roofpanelkey1")
	items.report_position(1, Vector3(200.0, 10.0, 202.0))
	var said: Array = []
	items.send_notice = func(_p, text): said.append(str(text))
	items.place_piece(1, "wall_section_kit", Vector3(200.0, 10.0, 200.0), 0)
	check(_count(items, "wall_section") == 1, "a wall stands (its top is 2.4 m up)")
	items.place_piece(1, "thatch_roof_kit", Vector3(203.0, 10.0, 205.0), 0)
	check(_count(items, "thatch_roof") == 0 and said.size() > 0 and str(said[-1]).contains("rests on"), "a panel with nothing to rest on is refused, saying so (%s)" % (str(said[-1]) if said.size() > 0 else "nothing said"))
	items.place_piece(1, "thatch_roof_kit", Vector3(200.0, 12.0, 200.1), 0, 0)
	var rising: Array = _rows(items, "thatch_roof")
	check(rising.size() == 1 and _near(rising[0], Vector3(200.0, 13.4, 199.0)), "a 45 panel rises from the wall top (%s)" % str(rising))
	items.place_piece(1, "thatch_roof_kit", Vector3(200.0, 12.0, 200.1), 0, 0)
	check(_count(items, "thatch_roof") == 1, "a second on the same spot is refused")
	items.place_piece(1, "thatch_roof_65", Vector3(200.0, 12.0, 200.1), 0, 1)
	check(_count(items, "thatch_roof_65") == 0 and str(said[-1]).contains("sink"), "a 65 panel falling from the wall top into the ground is refused (%s)" % str(said[-1]))
	items.place_piece(1, "thatch_roof_kit", Vector3(200.0, 12.0, 200.1), 0, 1)
	check(_count(items, "thatch_roof") == 2, "a 45 panel falling from the wall top stands")
	items.place_piece(1, "thatch_roof_65", Vector3(200.0, 14.0, 198.2), 0, 0)
	var steep: Array = _rows(items, "thatch_roof_65")
	var rise_65: float = Rules.roof_panel_rise(Rules.load_config()["structures"]["thatch_roof_65"])
	check(steep.size() == 1 and _near(steep[0], Vector3(200.0, 14.4 + rise_65 * 0.5, 197.0)), "a 65 panel goes on from the 45's high end (%s)" % str(steep))

	# Saved and loaded: the same pieces in the same places.
	var before: Array = _all_rows(items)
	items._dirty = true
	items.save()
	var again = _server(dir)
	again.peer_connected_hello(1, "roofpanelkey1")
	check(_all_rows(again) == before and before.size() == 4, "the wall and panels stand again after a save and a reload (%d rows)" % before.size())
	check(again._kind_now("thatch_doorway_open") == "thatch_doorway", "a saved open Crude doorway loads as the doorway")

	# The cover under a panel: a spot under it, from the floor up, is covered; one on top of it or beside it is not.
	var def: Dictionary = Rules.load_config()["structures"]["thatch_roof"]
	var index = Cover.Index.new()
	index.add_roof(Cover.structure_roof(def, Vector3(200.0, 13.4, 199.0), 0.0))
	check(Cover.at(Vector3(200.0, 11.0, 199.0), index) > 0.5 and Cover.at(Vector3(200.4, 10.2, 199.6), index) > 0.5 and Cover.at(Vector3(200.0, 14.2, 199.0), index) < 0.5 and Cover.at(Vector3(204.0, 11.0, 199.0), index) < 0.5, "a panel keeps the rain off the ground under it, not beside it or on top of it")


func _server(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _count(items, kind: String) -> int:
	var n: int = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			n += 1

	return n


func _rows(items, kind: String) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			out.append(items._items[id]["pos"])

	return out


func _all_rows(items) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct"):
			var p: Vector3 = items._items[id]["pos"]
			out.append([str(items._items[id]["struct"]["kind"]), snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(float(items._items[id]["struct"]["yaw"]), 0.1)])

	out.sort()
	return out


func _look_checks(cfg: Dictionary) -> void:
	for look in ["thatch_roof", "thatch_roof_65"]:
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
		var def: Dictionary = cfg["structures"][look]
		var half_rise: float = Rules.roof_panel_rise(def) * 0.5
		var box: AABB = _mesh_box(node)
		check(box.position.x >= -1.05 and box.end.x <= 1.05 and box.position.y >= -half_rise - 0.3 and box.end.y <= half_rise + 0.3 and box.position.z >= -1.3 and box.end.z <= 1.3,
			"%s: the mesh is the panel and nothing else, no posts below its low end (%s)" % [look, box])
		check(node.find_children("*", "CollisionShape3D", true, false).size() == 1, "%s: one collider, the slab (no legs)" % look)
		check(not _solid_at(node, Vector3(0.9, -half_rise - 0.6, 0.9)) and not _solid_at(node, Vector3(0.0, 0.4, 0.0)) and not _solid_at(node, Vector3(0.0, -0.4, 0.0)), "%s: nothing solid under or over the middle" % look)
		check(_solid_at(node, Vector3.ZERO) and _solid_at(node, Vector3(0.9, 0.0, 0.0)), "%s: the slab is solid through the middle" % look)
		check(_solid_at(node, Vector3(0.0, -half_rise * 0.96, 0.96)) and _solid_at(node, Vector3(0.0, half_rise * 0.96, -0.96)), "%s: the collider runs to both ends, the low one at +Z and the high one at -Z" % look)
		check(not _solid_at(node, Vector3(0.0, half_rise * 0.96, 0.96)) and not _solid_at(node, Vector3(0.0, -half_rise * 0.96, -0.96)), "%s: and is tilted the right way (the other corners are open air)" % look)
		node.queue_free()


func _run() -> void:
	await process_frame
	var cfg: Dictionary = Rules.load_config()
	_data_checks(cfg)
	_snap_checks(cfg)
	_server_checks()
	_look_checks(cfg)
	print("test_roof_panels: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
