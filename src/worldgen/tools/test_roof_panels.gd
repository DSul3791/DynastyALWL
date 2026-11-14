extends SceneTree

# Crude - Roof 45 and Crude - Roof 65 (BUG-011, BUGLIST-001): a sloped roof PANEL only, no posts, either end resting on a wall top, a ceiling edge or another
# panel's end, rising or falling from it. Data (names, ids, numbers kept), the shared snap rules (both slopes x both anchored ends x both facings, the answer
# snapping to itself, ceiling edges, a chain of panels, a ridge), the server's refusals (nothing to rest on, into the ground, a second on the same spot),
# saved and loaded, the cover box under it, and the mesh and collider (no legs, the slab's two ends where the rules say). GOALS-REPAIR A-35/A-36: every
# tier's roof above Crude is the same panel at 45 and 65 degrees (ids, numbers and states of the 45s kept), checked the same way (_tier_checks). A-37: every
# tier's roof corner is a hip over a corner square, resting where two wall tops meet, its 45 or 65 shape following the panel beside it (_hip_checks).
#   godot --headless --path . --script res://src/worldgen/tools/test_roof_panels.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Rules := preload("res://src/shared/placement_rules.gd")
const Cover := preload("res://src/shared/cover.gd")
const LookTable := preload("res://src/client/look_table.gd")

const KITS := {45: "thatch_roof_kit", 65: "thatch_roof_65"}
# The tier roofs: id -> [tier, item number, blueprint number, state] of the 45 (all kept from the old gable on posts); the 65 is id + "_65".
const TIERS := {"log_roof": ["Rustic", 469, 18, 52], "roof_section": ["Refined", 197, 3, 24], "stone_roof": ["Sturdy", 475, 38, 55],
	"brick_roof": ["Superior", 481, 22, 58], "engineered_roof": ["Engineered", 877, 178, 219]}
# The roof corners: id -> [blueprint name, state of the 45 shape, state of the 65 shape] (one item and blueprint each, two placed shapes, A-37).
const CORNERS := {"thatch_roof_corner": ["Crude - Roof corner", 118, 385], "wooden_roof_corner": ["Refined - Roof corner", 119, 386],
	"log_roof_corner": ["Rustic - Roof corner", 120, 387], "stone_roof_corner": ["Sturdy - Roof corner", 121, 388],
	"brick_roof_corner": ["Superior - Roof corner", 122, 389], "engineered_roof_corner": ["Engineered - Roof corner", 220, 390]}

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

		var fell: Array = Rules.snap(cfg, kit, cursor, 0, wall, 1)
		check(Rules.snap(cfg, kit, fell[0], int(fell[1]), wall, 0)[0] == fell[0], "%d degrees: a falling panel's middle sent with mode 0 (a replayed building plan) is still that falling panel" % slope)
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

	# A panel is a shelter whose spot is its middle, metres up a wall: rest and respawn points are the floor under it, never mid-air.
	var key: String = str(items._peer_key[1])
	var rests: Array = items._characters[key].get("rests", [])
	check(rests.size() > 0 and rests.all(func(r): return absf(float(r[1]) - 10.0) < 0.01), "building a panel records its rest point on the ground (%s)" % str(rests))
	items.report_position(1, Vector3(200.0, 10.0, 202.0))
	items._note_shelter(1)
	var saved: Array = items._characters[key].get("shelter", [])
	check(saved.size() == 3 and absf(float(saved[1]) - 10.0) < 0.01, "sleeping under a panel saves the ground as the shelter point (%s)" % str(saved))
	check(absf(items.respawn_for(1).y - 10.0) < 0.01, "and a respawn there is on the ground, not at the panel's middle (y %.2f)" % items.respawn_for(1).y)
	check(absf(items.rest_point_for(1, Vector3(200.0, 10.0, 205.0)).y - 10.0) < 0.01, "so is a rejoin at the nearest rest point")

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


# GOALS-REPAIR A-35/A-36: each tier roof above Crude is a panel, 45 and 65 degrees, on the Crude panel's rules: the data (names, kept numbers, the 65's own
# numbers, same materials), resting on a wall top rising and falling, on another panel's end both ways, and placed, saved and loaded by a real server.
func _tier_checks(cfg: Dictionary) -> void:
	var blueprints: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json")) as Dictionary)["blueprints"]
	var items: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json")) as Dictionary)["items"]
	var enc: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/encyclopedia.json")) as Dictionary)["items"]
	var bp_numbers: Dictionary = {}
	var states: Dictionary = {}

	for id in blueprints:
		bp_numbers[int(blueprints[id]["number"])] = int(bp_numbers.get(int(blueprints[id]["number"]), 0)) + 1

	for kind in cfg["structures"]:
		if typeof(cfg["structures"][kind]) == TYPE_DICTIONARY and (cfg["structures"][kind] as Dictionary).has("state"):
			states[int(cfg["structures"][kind]["state"])] = int(states.get(int(cfg["structures"][kind]["state"]), 0)) + 1

	var wall_state: int = int(cfg["structures"]["wall_section"]["state"])
	var top: Vector3 = Vector3(300.0, 12.7, 300.0)
	var wall: Array = [{"pos": Vector3(300.0, 10.3, 300.0), "state": wall_state, "yaw": 0.0}]
	var cursor: Vector3 = Vector3(300.1, 12.0, 300.1)

	for id in TIERS:
		var tier: String = TIERS[id][0]
		var id65: String = id + "_65"
		var s45: Dictionary = cfg["structures"][id]
		var s65: Dictionary = cfg["structures"][id65]
		check(str(blueprints[id]["name"]) == tier + " - Roof 45" and int(blueprints[id]["number"]) == int(TIERS[id][2]) and str(blueprints[id]["structure"]) == id, "%s is %s - Roof 45 and keeps its blueprint number" % [id, tier])
		check(str(blueprints[id65]["name"]) == tier + " - Roof 65" and str(blueprints[id65]["structure"]) == id65 and str(blueprints[id65]["cost"]) == str(blueprints[id]["cost"]) and int(bp_numbers[int(blueprints[id65]["number"])]) == 1, "%s - Roof 65 is a blueprint of its own on the same materials" % tier)
		check(str(items[id]["name"]) == tier + " - Roof 45" and int(items[id]["number"]) == int(TIERS[id][1]) and str(items[id65]["name"]) == tier + " - Roof 65" and str(enc[id]["name"]) == tier + " - Roof 45" and str(enc[id65]["name"]) == tier + " - Roof 65", "%s: the items and encyclopedia carry both names, the 45 keeps item %d" % [tier, int(TIERS[id][1])])
		check(int(s45["state"]) == int(TIERS[id][3]) and int(states[int(s45["state"])]) == 1 and int(states[int(s65["state"])]) == 1, "%s: the 45 keeps state %d and the 65 has a state of its own" % [tier, int(TIERS[id][3])])
		check(str(s65["material"]) == str(s45["material"]) and str(s65["sound"]) == str(s45["sound"]), "%s: both slopes are the same material and sound" % tier)

		for pair in [[s45, 45.0, "thatch_roof"], [s65, 65.0, "thatch_roof_65"]]:
			var def: Dictionary = pair[0]
			check(str(def["piece_kind"]) == Rules.ROOF_PANEL_KIND and float(def["footprint_x"]) == 2.0 and float(def["height"]) == 0.0, "%s is a roof panel 2 m wide" % str(def["item"]))
			check(float(def["slope_deg"]) == float(pair[1]) and float(def["cover_below_m"]) == float(cfg["structures"][str(pair[2])]["cover_below_m"]), "%s: the Crude panel's slope and cover box" % str(def["item"]))

		for kit in [str(s45["kit"]), id65]:
			var def: Dictionary = Rules.structure_of_kit(cfg, kit)
			var rise: float = Rules.roof_panel_rise(def)

			for mode in [0, 1]:
				var answer: Array = Rules.snap(cfg, kit, cursor, 0, wall, mode)
				var label: String = "%s %s" % [str(def["item"]), "falling from the wall top" if mode == 1 else "rising from it"]
				check(bool(answer[2]) and _near(_anchored_end(def, answer, mode), top), "%s: rests by its %s end on the wall top (%s)" % [label, "high" if mode == 1 else "low", str(answer)])
				check(absf((answer[0] as Vector3).y - (top.y + (rise * 0.5 if mode == 0 else -rise * 0.5))) < 0.001, "%s: the middle is half a rise from the wall top" % label)

			# On another panel's end: this tier's panel goes on up from a Crude 45's high end, and facing back falls from it (a ridge).
			var first: Array = Rules.snap(cfg, "thatch_roof_kit", cursor, 0, wall, 0)
			var rows: Array = wall + [{"pos": first[0], "state": int(cfg["structures"]["thatch_roof"]["state"]), "yaw": float(first[1])}]
			var high_end: Vector3 = Vector3(300.0, top.y + 2.0, 298.0)
			var up: Array = Rules.snap(cfg, kit, Vector3(300.0, 14.5, 298.2), 0, rows, 0)
			check(bool(up[2]) and _near(_anchored_end(def, up, 0), high_end) and (up[0] as Vector3).z < 298.0, "%s: goes on up from another panel's high end (%s)" % [str(def["item"]), str(up)])
			var ridge: Array = Rules.snap(cfg, kit, Vector3(300.0, 14.5, 298.2), 180, rows, 1)
			check(bool(ridge[2]) and _near(_anchored_end(def, ridge, 1), high_end) and (ridge[0] as Vector3).y < high_end.y, "%s: facing back, falls from that end (%s)" % [str(def["item"]), str(ridge)])

			# And the reverse: a Crude panel rests on this tier panel's high end.
			var own: Array = Rules.snap(cfg, kit, cursor, 0, wall, 0)
			var own_rows: Array = wall + [{"pos": own[0], "state": int(def["state"]), "yaw": float(own[1])}]
			var on_it: Array = Rules.snap(cfg, "thatch_roof_kit", Vector3(300.0, top.y + rise, 298.2), 0, own_rows, 0)
			check(bool(on_it[2]) and _near(_anchored_end(cfg["structures"]["thatch_roof"], on_it, 0), Vector3(300.0, top.y + rise, 298.0)), "%s: another panel rests on its high end (%s)" % [str(def["item"]), str(on_it)])

	# A real server: each tier's 45 rises from a wall top, its 65 goes on from the 45's high end, another 45 falls from the next wall; all reload.
	var dir: String = "user://test_roof_panels_tiers"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var server = _server(dir)
	server.peer_connected_hello(1, "roofpanelkey2")
	var x: float = 400.0

	for id in TIERS:
		var kit45: String = str(cfg["structures"][id]["kit"])
		var rise_65: float = Rules.roof_panel_rise(cfg["structures"][id + "_65"])
		server.report_position(1, Vector3(x, 10.0, 402.0))
		server.place_piece(1, "wall_section_kit", Vector3(x, 10.0, 400.0), 0)
		server.place_piece(1, kit45, Vector3(x, 12.0, 400.1), 0, 0)
		var rising: Array = _rows(server, id)
		check(rising.size() == 1 and _near(rising[0], Vector3(x, 13.4, 399.0)), "%s: placed, it rises from the wall top (%s)" % [id, str(rising)])
		server.place_piece(1, id + "_65", Vector3(x, 14.0, 398.2), 0, 0)
		var steep: Array = _rows(server, id + "_65")
		check(steep.size() == 1 and _near(steep[0], Vector3(x, 14.4 + rise_65 * 0.5, 397.0)), "%s_65: placed, it goes on from the 45's high end (%s)" % [id, str(steep)])
		server.place_piece(1, kit45, Vector3(x, 12.0, 400.1), 0, 1)
		check(_count(server, id) == 2, "%s: a second 45 falls from the same wall top" % id)
		x += 10.0

	var before: Array = _all_rows(server)
	server._dirty = true
	server.save()
	var again = _server(dir)
	again.peer_connected_hello(1, "roofpanelkey2")
	check(_all_rows(again) == before and before.size() == TIERS.size() * 4, "every tier's walls and panels stand again after a save and a reload (%d rows)" % before.size())


# A-37: each tier's roof corner rests where two wall tops meet at a corner (a wall along X and one turning the corner), covering the square between
# them; its shape is its 45 row or its 65 twin: the panel beside it decides, else the wheel (mode). Same item and blueprint for both; saved and loaded.
func _hip_checks(cfg: Dictionary) -> void:
	var blueprints: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json")) as Dictionary)["blueprints"]
	var wall_state: int = int(cfg["structures"]["wall_section"]["state"])
	var walls: Array = [{"pos": Vector3(300.0, 10.3, 300.0), "state": wall_state, "yaw": 0.0}, {"pos": Vector3(299.0, 10.3, 301.0), "state": wall_state, "yaw": 90.0}]
	var middle: Vector2 = Vector2(300.0, 301.0)   # the corner square between them: one run on from each wall top, rising +Z and +X (turned 180)
	var top: float = 12.7

	for id in CORNERS:
		var base: Dictionary = cfg["structures"][id]
		var twin_id: String = id + "_65"
		var twin: Dictionary = cfg["structures"].get(twin_id, {})
		var kit: String = str(base["kit"])
		check(str(base["piece_kind"]) == Rules.ROOF_HIP_KIND and float(base["slope_deg"]) == 45.0 and str(base["slope_twin"]) == twin_id and int(base["state"]) == int(CORNERS[id][1]), "%s: a roof corner at 45 degrees, its 65 shape %s, state kept" % [id, twin_id])
		check(str(twin.get("piece_kind", "")) == Rules.ROOF_HIP_KIND and float(twin.get("slope_deg", 0.0)) == 65.0 and str(twin.get("kit", "")) == kit and str(twin.get("item", "")) == str(base["item"]) and int(twin.get("state", 0)) == int(CORNERS[id][2]), "%s: the 65 shape is the same kit and item, state %d" % [twin_id, int(CORNERS[id][2])])
		check(str(blueprints[id]["name"]) == str(CORNERS[id][0]) and str(Rules.structure_of_kit(cfg, kit)["kind"]) == id and not blueprints.has(twin_id), "%s: one blueprint (%s), no second one for the 65" % [id, str(CORNERS[id][0])])
		var def: Dictionary = Rules.structure_of_kit(cfg, kit)
		var r45: float = Rules.roof_panel_rise(base) * 0.5
		var r65: float = Rules.roof_panel_rise(twin) * 0.5
		var plain: Array = Rules.roof_hip_pick(cfg, def, Vector3(300.2, 13.0, 300.8), 0, walls)
		check(plain.size() == 3 and str(plain[2]) == id and _near(plain[0], Vector3(middle.x, top + r45, middle.y)) and int(plain[1]) == 180, "%s: on the corner of two wall tops, no panel beside it, the wheel's first shape is 45 (%s)" % [id, str(plain)])
		var steep: Array = Rules.roof_hip_pick(cfg, def, Vector3(300.2, 13.0, 300.8), 1, walls)
		check(steep.size() == 3 and str(steep[2]) == twin_id and _near(steep[0], Vector3(middle.x, top + r65, middle.y)), "%s: the wheel turns it to its 65 shape (%s)" % [id, str(steep)])
		check(_near(Rules.roof_hip_pick(cfg, def, steep[0], 1, walls)[0], steep[0]) and _near(Rules.roof_hip_pick(cfg, def, plain[0], 0, walls)[0], plain[0]), "%s: an answer snaps to itself" % id)
		var snapped: Array = Rules.snap(cfg, kit, Vector3(300.2, 13.0, 300.8), 0, walls)
		check(bool(snapped[2]) and snapped[0] == plain[0] and int(snapped[1]) == 180, "%s: snap puts it there too" % id)
		check(Rules.roof_hip_pick(cfg, def, Vector3(300.2, 13.0, 300.8), 0, [walls[0]]).is_empty(), "%s: one wall top alone is no corner" % id)

		for slope in [45, 65]:   # a panel already standing beside it (continuing the +Z face, one run along +X) sets the shape whatever the wheel says
			var panel_kind: String = "thatch_roof" if slope == 45 else "thatch_roof_65"
			var rise: float = Rules.roof_panel_rise(cfg["structures"][panel_kind]) * 0.5
			var beside: Array = walls + [{"pos": Vector3(302.0, top + rise, 301.0), "state": int(cfg["structures"][panel_kind]["state"]), "yaw": 180.0}]
			var want: String = id if slope == 45 else twin_id

			for mode in [0, 1]:
				var picked: Array = Rules.roof_hip_pick(cfg, def, Vector3(300.2, 13.0, 300.8), mode, beside)
				check(picked.size() == 3 and str(picked[2]) == want and absf((picked[0] as Vector3).y - (top + rise)) < 0.001, "%s: beside a Roof %d panel it takes %d degrees (wheel %d: %s)" % [id, slope, slope, mode, str(picked)])

			var other: Array = walls + [{"pos": Vector3(300.0, top + rise, 303.0), "state": int(cfg["structures"][panel_kind]["state"]), "yaw": 270.0}]   # beside the other face: one run along +Z, rising +X
			check(str(Rules.roof_hip_pick(cfg, def, Vector3(300.2, 13.0, 300.8), 1 if slope == 45 else 0, other)[2]) == want, "%s: so does a Roof %d panel beside its other face" % [id, slope])

	# A real server: each corner on its own corner of two walls, by the wheel 45 or 65 in turn; the shape is saved and loads again.
	var dir: String = "user://test_roof_panels_hips"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var server = _server(dir)
	server.peer_connected_hello(1, "roofpanelkey3")
	var x: float = 500.0
	var n: int = 0

	for id in CORNERS:
		var kit: String = str(cfg["structures"][id]["kit"])
		var mode: int = n % 2
		var kind: String = id if mode == 0 else id + "_65"
		server.report_position(1, Vector3(x, 10.0, 504.0))
		server.place_piece(1, "wall_section_kit", Vector3(x, 10.0, 500.0), 0)
		server.place_piece(1, "wall_section_kit", Vector3(x - 1.0, 10.0, 501.0), 90)
		server.place_piece(1, kit, Vector3(x, 13.0, 501.0), 0, mode)
		var placed: Array = _rows(server, kind)
		var rise: float = Rules.roof_panel_rise(cfg["structures"][kind]) * 0.5
		check(placed.size() == 1 and _near(placed[0], Vector3(x, 12.4 + rise, 501.0)), "%s: placed by the wheel's %s shape on the corner of two walls (%s)" % [id, "45" if mode == 0 else "65", str(placed)])
		server.place_piece(1, kit, Vector3(x, 13.0, 501.0), 0, mode)
		check(_count(server, id) + _count(server, id + "_65") == 1, "%s: a second corner on the same square is refused" % id)
		x += 10.0
		n += 1

	var before: Array = _all_rows(server)
	server._dirty = true
	server.save()
	var again = _server(dir)
	again.peer_connected_hello(1, "roofpanelkey3")
	check(_all_rows(again) == before and before.size() == CORNERS.size() * 3, "every corner keeps its shape after a save and a reload (%d rows)" % before.size())

	# The looks: no posts, two convex faces, solid on each face, open air over and under them.
	for id in CORNERS:
		for kind in [id, id + "_65"]:
			var def: Dictionary = cfg["structures"][kind]
			var look: String = str(def["look"])
			check(LookTable.has_look(look), "%s is in the look table" % look)
			var node: Node3D = LookTable.build(look)
			get_root().add_child(node)
			var half_rise: float = Rules.roof_panel_rise(def) * 0.5
			var box: AABB = _mesh_box(node)
			check(box.position.x >= -1.2 and box.end.x <= 1.2 and box.position.z >= -1.2 and box.end.z <= 1.2 and box.position.y >= -half_rise - 0.3 and box.end.y <= half_rise + 0.3, "%s: the mesh is the corner square and nothing else, no posts (%s)" % [look, box])
			check(node.find_children("*", "CollisionShape3D", true, false).size() == 2, "%s: two colliders, one per face" % look)
			var face_z: Vector3 = Vector3(-1.0 / 3.0, -half_rise / 3.0, 1.0 / 3.0)    # the middle of the face rising toward -Z
			var face_x: Vector3 = Vector3(1.0 / 3.0, -half_rise / 3.0, -1.0 / 3.0)    # and of the one rising toward -X
			check(_hull_at(node, face_z) and _hull_at(node, face_x), "%s: solid on both faces" % look)
			check(not _hull_at(node, face_z + Vector3(0.0, 0.5, 0.0)) and not _hull_at(node, Vector3(0.0, -half_rise - 0.5, 0.0)) and not _hull_at(node, Vector3(0.9, -half_rise * 0.5, 0.9)), "%s: open air over a face, under the corner and over the low outer corner" % look)
			node.queue_free()


# Whether `point` (in `node`'s space) is inside any convex collider of `node`: inside every plane of its hull (the planes through three of its points
# with all the others on one side).
func _hull_at(node: Node3D, point: Vector3) -> bool:
	for child in node.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = child
		var hull: ConvexPolygonShape3D = cs.shape as ConvexPolygonShape3D

		if hull == null:
			continue

		var local: Vector3 = (node.global_transform.affine_inverse() * cs.global_transform).affine_inverse() * point
		var pts: PackedVector3Array = hull.points
		var inside: bool = true

		for i in pts.size():
			for j in range(i + 1, pts.size()):
				for k in range(j + 1, pts.size()):
					var plane: Plane = Plane(pts[i], pts[j], pts[k])

					if plane.normal.length() < 0.5:
						continue

					var above: int = 0
					var below: int = 0

					for q in pts:
						var d: float = plane.distance_to(q)
						above += 1 if d > 0.001 else 0
						below += 1 if d < -0.001 else 0

					if above > 0 and below > 0:
						continue   # not a face of the hull

					var side: float = plane.distance_to(local)

					if (above == 0 and side > 0.001) or (below == 0 and side < -0.001):
						inside = false

		if inside:
			return true

	return false


func _look_checks(cfg: Dictionary) -> void:
	var kinds: Array = ["thatch_roof", "thatch_roof_65"]

	for id in TIERS:
		kinds += [id, id + "_65"]

	for kind in kinds:
		var def: Dictionary = cfg["structures"][kind]
		var look: String = str(def["look"])
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
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
	_tier_checks(cfg)
	_hip_checks(cfg)
	_look_checks(cfg)
	print("test_roof_panels: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
