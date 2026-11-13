extends SceneTree

# The admin spyglass (Dave 9 Nov 2026, docs/design/spyglass_design.md): zoom range and field of view, the mouse scale, picking
# the animal nearest the centre, the readout text, and the server side: rows out to the spyglass radius, info_of, a watched
# animal kept living past the freeze line. The player spyglass item (10 Nov 2026, data/items/spyglass.json): tier 1 at a fixed 3x with a near
# blur and no readout; the server checks the item (no admin needed), wears one use per look and sends animals out to 150 m.
#   godot --headless --path . --script res://src/worldgen/tools/test_spyglass.gd

const Spyglass := preload("res://src/client/spyglass.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var glass = Spyglass.new()
	check(not glass.active and glass.toggle() and glass.active and is_equal_approx(glass.zoom, Spyglass.START_ZOOM), "Ctrl+L raises it at 4x")
	check(absf(glass.fov(75.0) - 21.7) < 0.2, "4x narrows 75 degrees to about 22 (%.1f)" % glass.fov(75.0))
	check(is_equal_approx(glass.mouse_scale(), 0.25), "the mouse slows by the zoom")

	for _n in 40:
		glass.wheel(false)

	check(is_equal_approx(glass.zoom, Spyglass.MAX_ZOOM), "the wheel stops at 40x")

	for _n in 40:
		glass.wheel(true)

	check(is_equal_approx(glass.zoom, Spyglass.MIN_ZOOM), "and at 2x")

	# Picking: 100 m ahead, one animal on the line and one 5 m to the side (about 3 degrees: outside 3 / zoom).
	glass.zoom = 4.0
	var bodies: Array = [[7, Vector3(5.0, 0.0, -100.0)], [9, Vector3(0.0, 0.0, -100.0)], [11, Vector3(0.0, 0.0, 400.0)]]
	check(glass.pick(Vector3(0.0, 0.6, 0.0), Vector3(0.0, 0.0, -1.0), bodies) == 9, "the animal on the line of sight is watched")
	check(glass.pick(Vector3(0.0, 0.6, 0.0), Vector3(0.05, 0.0, -1.0), [[7, Vector3(5.0, 0.0, -100.0)]]) == 7, "turn a little and the other one is")
	check(glass.pick(Vector3(0.0, 0.6, 0.0), Vector3(0.0, 0.0, -1.0), [[7, Vector3(5.0, 0.0, -100.0)]]) == 0, "nothing near the centre: none")
	check(glass.pick(Vector3(0.0, 0.6, 0.0), Vector3(0.0, 0.0, 1.0), bodies) == 0, "farther than any sent animal: none")
	check(not glass.toggle() and glass.watched == 0 and glass.info.is_empty(), "Ctrl+L again lowers it and forgets the watched one")

	var text: String = Spyglass.readout({"name": "Red deer", "level": 4, "hp": 17.6, "hp_max": 24.0, "state": 21, "temper": "defensive", "group": 3}, 182.4)
	check(text == "Red deer\nLevel 4\nHealth 18 / 24\ndrinking\nTemperament: defensive\nHerd 3\n182 m", "the readout lines (%s)" % text.c_escape())
	check(Spyglass.readout({}, 10.0) == "", "nothing has come yet: no readout")

	# Server: rows out to the spyglass radius, the readout, and a watched animal kept living beyond active_radius_m.
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.water_level = func(_x, _z): return NAN
	a.blocked = func(_x, _z): return false
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	a.player_positions = func(): return players
	a.player_stances = func(): return [0]
	a.hour_now = func(): return 7.0   # morning: deer are about (none sent off for the hour)
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.rng.seed = 3
	var near_id: int = a.spawn("deer", 50.0, 0.0)
	var far_id: int = a.spawn("deer", 250.0, 0.0)
	check(near_id > 0 and far_id > 0, "two deer, 50 m and 250 m away")
	var ids_of = func(rows: Array) -> Array: return rows.map(func(r): return int(r[0]))
	var normal: Array = ids_of.call(a.rows_near(players[0]))
	check(near_id in normal and not (far_id in normal), "normally only the near one is sent (120 m)")
	var spy: Dictionary = a.cfg.get("spyglass", {})
	check(float(spy.get("send_radius_m", 0.0)) == 300.0 and int(spy.get("cap", 0)) == 60, "animals.json spyglass: 300 m, nearest 60")
	var wide: Array = ids_of.call(a.rows_near(players[0], float(spy["send_radius_m"]), int(spy["cap"])))
	check(near_id in wide and far_id in wide and wide.find(near_id) < wide.find(far_id), "through the spyglass both, nearest first")

	var info: Dictionary = a.info_of(far_id)
	check(str(info.get("name", "")) == str(a.species_def("deer").get("name", "")) and info.has("level") and float(info["hp"]) > 0.0 and float(info["hp_max"]) >= float(info["hp"]), "info_of: name, level, health (%s)" % str(info))
	check(a.info_of(99999).is_empty(), "info_of a gone animal is empty")

	var far: Dictionary = a.animals[far_id]
	far["state"] = 1
	far["target"] = far["pos"] + Vector3(20.0, 0.0, 0.0)
	var start: Vector3 = far["pos"]

	for _n in 40:
		a.tick(0.25)

	check(far["pos"] == start, "beyond the 200 m freeze line it stands still")
	a.watched[far_id] = true

	for _n in 40:
		a.tick(0.25)

	check(far["pos"] != start, "watched through the spyglass it keeps living (moved %.1f m)" % far["pos"].distance_to(start))

	item_checks()
	print("test_spyglass: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


# The player spyglass: the tier's view on the client, and the server's check, wear and reach.
func item_checks() -> void:
	var cfg: Dictionary = Spyglass.tier_config(1)
	check(not cfg.is_empty() and float(cfg["send_radius_m"]) == 150.0 and float(cfg["blur_near_m"]) == 20.0, "spyglass.json tier 1: 150 m, soft closer than 20 m")
	var glass = Spyglass.new()
	glass.look_item(true, 1, cfg)
	check(glass.active and is_equal_approx(glass.zoom, 3.0) and not glass.can_zoom() and not glass.has_readout(), "tier 1 looks at a fixed 3x with no readout")
	glass.wheel(false)
	check(is_equal_approx(glass.zoom, 3.0), "the wheel does not zoom tier 1")
	glass.look_item(false, 1, cfg)
	check(not glass.active and glass.tier == 0, "letting go lowers it")
	check(glass.toggle() and glass.has_readout() and glass.can_zoom(), "the admin glass is as it was after an item look")
	glass.toggle()

	var dir: String = "user://test_spyglass_item"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 0.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "spy-key-00000001")
	items.report_position(1, Vector3.ZERO)
	var number: int = items.table.number_of("spyglass")
	check(number != 0 and str(items.table.entry("spyglass").get("tool_class", "")) == "spyglass", "the spyglass item exists")
	items.action(1, Net.ACT_ADMIN_GIVE, number, 0, 1, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(number)
	items.admin_ok = func(_p): return false      # a player, not an admin

	items.action(1, Net.ACT_SPYGLASS, 2, 0, slot, Vector3.ZERO)
	check(int(items.spyglass.get(1, -9)) == 0 and int(items.spyglass_tier.get(1, 0)) == 1, "a player looks through a spyglass in the pack, no admin needed")
	var reach: Array = items.spyglass_reach(1, {"send_radius_m": 300.0, "cap": 60})
	check(float(reach[0]) == 150.0 and int(reach[1]) == int(cfg["cap"]), "the server sends animals out to the tier's 150 m")
	check(items.inventory_of(1).wear[slot] == 1, "one look wears one use")
	items.action(1, Net.ACT_SPYGLASS, 2, 77, slot, Vector3.ZERO)
	check(items.inventory_of(1).wear[slot] == 1 and int(items.spyglass[1]) == 0, "a resend while looking costs nothing and watches nothing (tier 1 has no readout)")
	items.action(1, Net.ACT_SPYGLASS, 0, 0, slot, Vector3.ZERO)
	check(not items.spyglass.has(1) and not items.spyglass_tier.has(1) and float(items.spyglass_reach(1, {})[0]) < 0.0, "lowered: the normal send")
	items.action(1, Net.ACT_SPYGLASS, 2, 0, slot, Vector3.ZERO)
	check(items.inventory_of(1).wear[slot] == 2, "a new look wears another use")
	items.action(1, Net.ACT_SPYGLASS, 0, 0, slot, Vector3.ZERO)

	var other: int = (slot + 1) % items.inventory_of(1).slot_count
	items.action(1, Net.ACT_SPYGLASS, 2, 0, other, Vector3.ZERO)
	check(int(items.spyglass.get(1, 0)) == -1 and not items.spyglass_tier.has(1), "no spyglass in that slot: refused")
	items.spyglass.erase(1)
	items.inventory_of(1).wear[slot] = 100000
	items.action(1, Net.ACT_SPYGLASS, 2, 0, slot, Vector3.ZERO)
	check(int(items.spyglass.get(1, 0)) == -1, "a broken spyglass is refused")
	items.spyglass.erase(1)
	items.action(1, Net.ACT_SPYGLASS, 1, 0, 0, Vector3.ZERO)
	check(int(items.spyglass.get(1, 0)) == -1, "the admin glass is still refused to a player")
