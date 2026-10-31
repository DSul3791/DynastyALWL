extends SceneTree

# Playthrough probe 7 (read-only): the lean-to as a home. Place a lean-to at the spawn, place a rough bed INSIDE its footprint, lie down and sleep on it,
# check the cover under the lying player, the good-bed conditions (bed.json), and where a death brings the player back. PASS/FAIL per step with numbers.
# The real server_items.gd and the real cover index (cover.gd Index), the real baked ground heights.
#   godot --headless --path . --script res://art/playthrough/probe_shelter.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var generator
var items
var cover
var last_notice: String = ""


func h(x: float, z: float) -> float:
	return generator.surface_height(x, z)


func n(id: String) -> int:
	return items.table.number_of(id)


func say(step: String, ok: bool, detail: String) -> void:
	print("probe7: ", "PASS" if ok else "FAIL", " | ", step, " | ", detail)


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	cover = CoverScript.Index.new()
	var dir: String = "user://probe_shelter"
	DirAccess.make_dir_recursive_absolute(dir)

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): last_notice = t
	items.ground_height = func(x, z): return h(x, z)
	items.water_depth_at = func(pos: Vector3): return maxf(0.0 - h(pos.x, pos.z), 0.0)
	items.tree_info = func(_c, _i): return {}
	items.cut_tree = func(_c, _i): return false
	items.water_near = func(_pos, _reach): return false
	items.roof_add = func(roof: Array): return cover.add_roof(roof)
	items.cover_at = func(pos: Vector3): return CoverScript.at(pos, cover) * 2.0   # built roofs read 2.0 in the game; here only roofs exist in the index
	items.rain_now = func(): return 0.0
	items.send_died = func(_p, cause, back): print("probe7: send_died cause ", cause, " back ", back)
	items.setup(ItemTableScript.load_default(), dir)
	var spawn: Vector2 = Vector2(53316.0, 68476.0)
	var ground: float = h(spawn.x, spawn.y)
	var peer: int = 2
	items.peer_connected_hello(peer, "probe700000002")
	items.report_position(peer, Vector3(spawn.x - 2.0, ground, spawn.y))
	items.vitals_of(peer)["weight"] = 900.0
	items.respawn_point = Vector3(spawn.x, ground, spawn.y)
	print("probe7: spawn ", spawn, " ground ", snappedf(ground, 0.01), " | lean-to def: ", items._structures["lean_to"])
	print("probe7: rough bed def: ", items._structures["rough_bed"])

	# 1. lean-to
	items.give(peer, n("lean_to_kit"), 1)
	last_notice = ""
	items.action(peer, Net.ACT_PLACE, items.inventory_of(peer).numbers.find(n("lean_to_kit")), 0, 0, Vector3(spawn.x, ground, spawn.y))
	var lean_id: int = -1

	for id in items._items:
		if items._items[id].has("struct") and items._items[id]["struct"]["kind"] == "lean_to":
			lean_id = id

	say("1 place lean-to at the spawn", lean_id >= 0, "notice '%s'" % last_notice)

	if lean_id < 0:
		quit()
		return

	var lean: Dictionary = items._items[lean_id]
	var lp: Vector3 = lean["pos"]
	var yaw: float = deg_to_rad(float(lean["struct"]["yaw"]))
	var def: Dictionary = items._structures["lean_to"]
	print("probe7: lean-to at ", lp, " yaw ", rad_to_deg(yaw), " roof key ", lean["struct"].get("roof", "none"), " | cover box half ", def["half_x"], " x ", def["half_z"], " = ", float(def["half_x"]) * 2.0, " x ", float(def["half_z"]) * 2.0, " m, height ", def["height"], " | footprint ", def["footprint_x"], " x ", def["footprint_z"])
	say("2 roof is in the cover index", lean["struct"].has("roof"), "key %s" % str(lean["struct"].get("roof", "none")))
	var cx := Vector3(cos(yaw), 0.0, sin(yaw))
	var cz := Vector3(-sin(yaw), 0.0, cos(yaw))

	# 3. cover at the centre, at the four corners inside the box, just outside
	var at_c: float = CoverScript.at(lp + Vector3(0.0, 0.3, 0.0), cover)
	say("3 cover.at the lean-to centre (lying height 0.3 m)", at_c > 0.0, "%s" % at_c)
	var corners_ok: int = 0
	var corner_txt: String = ""

	for sx in [-0.9, 0.9]:
		for sz in [-0.75, 0.75]:
			var c: float = CoverScript.at(lp + cx * sx + cz * sz + Vector3(0.0, 0.3, 0.0), cover)
			corners_ok += int(c > 0.0)
			corner_txt += " (%.2f,%.2f):%d" % [sx, sz, int(c)]

	say("4 cover at 4 inner points (+-0.9 m along, +-0.75 m across)", corners_ok == 4, corner_txt)
	var out: float = CoverScript.at(lp + cx * 1.5 + Vector3(0.0, 0.3, 0.0), cover)
	say("5 cover.at 1.5 m past the roof edge is open", out == 0.0, "%s" % out)

	# 6. can a bed be placed inside the footprint? try the centre, then offsets
	var results: Array = []
	var bed_id: int = -1

	for off in [Vector3.ZERO, cx * 0.5, cx * -0.5, cz * 0.5, cx * 0.9]:
		items.give(peer, n("rough_bed_kit"), 1)
		last_notice = ""
		items.report_position(peer, lp + cx * 0.0 + cz * 2.5)
		var before: int = items._items.size()
		var want: Vector3 = Vector3(lp.x + off.x, h(lp.x + off.x, lp.z + off.z), lp.z + off.z)
		items.action(peer, Net.ACT_PLACE, items.inventory_of(peer).numbers.find(n("rough_bed_kit")), 0, 0, want)
		var placed: bool = items._items.size() > before
		results.append("offset(%.1f,%.1f) %s '%s'" % [off.x, off.z, "PLACED" if placed else "REFUSED", last_notice])

		if placed:
			bed_id = items._items.keys().back()
			break

	say("6 place rough bed inside the lean-to footprint", bed_id >= 0, " ; ".join(results))
	say("6b note", true, "structure gap (structures.json gap_m) is %.2f m between pieces, the lean-to's own footprint is %.1f x %.1f m" % [items._struct_gap_m, float(def["footprint_x"]), float(def["footprint_z"])])

	if bed_id < 0:
		# for the record: how far outside does the bed place?
		for d in [1.0, 1.5, 2.0, 2.5, 3.0]:
			items.give(peer, n("rough_bed_kit"), 1)
			last_notice = ""
			var before2: int = items._items.size()
			var w2: Vector3 = lp + cz * d
			w2.y = h(w2.x, w2.z)
			items.report_position(peer, w2 + cz * 2.0)
			items.action(peer, Net.ACT_PLACE, items.inventory_of(peer).numbers.find(n("rough_bed_kit")), 0, 0, w2)

			if items._items.size() > before2:
				bed_id = items._items.keys().back()
				print("probe7: nearest bed spot beside the lean-to: ", d, " m from its centre across, notice '", last_notice, "'")
				break
			else:
				print("probe7: bed ", d, " m from the lean-to centre: REFUSED '", last_notice, "'")

	if bed_id < 0:
		quit()
		return

	var bed: Dictionary = items._items[bed_id]
	var bp: Vector3 = bed["pos"]
	var bdef: Dictionary = items._structures["rough_bed"]
	print("probe7: bed at ", bp, " distance to lean-to centre ", snappedf(Vector2(bp.x - lp.x, bp.z - lp.z).length(), 0.01), " footprint ", bdef["footprint_x"], " x ", bdef["footprint_z"])
	var bed_covered: float = CoverScript.at(bp + Vector3(0.0, 0.3, 0.0), cover)
	say("7 bed spot is under the lean-to roof", bed_covered > 0.0, "cover.at %s" % bed_covered)

	# 8. lie down on the bed (stance 3), energy lowered so sleep is allowed
	items.report_position(peer, Vector3(bp.x, bp.y + 0.3, bp.z))
	items.vitals_of(peer)["energy"] = 40.0
	items.action(peer, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	items.tick(2.0)
	say("8 lie down (stance 3)", int(items._stance.get(peer, 0)) == 3, "stance %s" % items._stance.get(peer, "?"))
	say("9 server finds the bed under the lying player", items._bed_of(peer) == bed_id, "bed id %s of %s, reach %.1f m" % [items._bed_of(peer), bed_id, float(items._bed_cfg.get("reach_m", 1.2))])
	say("10 cover under the lying player", float(items.cover_at.call(items._peer_pos[peer])) > 0.5, "cover %s at %s" % [items.cover_at.call(items._peer_pos[peer]), items._peer_pos[peer]])
	say("11 good bed (bed + cover)", items.on_good_bed(peer), "sleep quality %s (bed.json quality %s, comfort %s, regen x%s, drain x%s)" % [items._sleep_quality(peer), items._bed_cfg.get("quality"), items._bed_cfg.get("comfort"), items._bed_cfg.get("regen_mult"), items._bed_cfg.get("drain_mult")])
	last_notice = ""
	items.action(peer, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	say("12 fall asleep", items._asleep.has(peer), "notice '%s'" % last_notice)
	var e0: float = items.energy_of(peer)

	for s in range(60):
		items.tick(1.0)

	say("13 energy rises asleep (60 s)", items.energy_of(peer) > e0, "%.2f -> %.2f" % [e0, items.energy_of(peer)])
	var walls: String = "no wall pieces: the closed-room bonus (3 walls within 3 m + roof) is not met by a lean-to alone"
	print("probe7: closed room? ", walls)

	# 14. shelter noted -> death respawn
	var row: Dictionary = items._characters.get(items._peer_key.get(peer, ""), {})
	say("14 shelter noted for respawn", row.get("shelter", []).size() == 3, "character row shelter %s" % str(row.get("shelter", [])))
	items.action(peer, Net.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	items.report_position(peer, Vector3(spawn.x + 40.0, h(spawn.x + 40.0, spawn.y), spawn.y))
	items.kill(peer, "probe")
	var back: Vector3 = items._peer_pos[peer]
	var dist: float = Vector2(back.x - lp.x, back.z - lp.z).length()
	say("15 death respawns at the lean-to, not the world spawn", dist < 5.0, "respawn %s, %.1f m from the lean-to centre, %.1f m from the world spawn" % [back, dist, Vector2(back.x - spawn.x, back.z - spawn.y).length()])
	say("16 respawn point is clear of the lean-to and bed", CoverScript.at(back + Vector3(0.0, 0.3, 0.0), cover) == 0.0, "cover at respawn %s" % CoverScript.at(back + Vector3(0.0, 0.3, 0.0), cover))
	quit()
