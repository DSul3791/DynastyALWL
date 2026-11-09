extends SceneTree

# The admin spyglass (Dave 9 Nov 2026, docs/design/spyglass_design.md): zoom range and field of view, the mouse scale, picking
# the animal nearest the centre, the readout text, and the server side: rows out to the spyglass radius, info_of, a watched
# animal kept living past the freeze line.
#   godot --headless --path . --script res://src/worldgen/tools/test_spyglass.gd

const Spyglass := preload("res://src/client/spyglass.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

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

	print("test_spyglass: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
