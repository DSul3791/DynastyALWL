extends SceneTree

# Single birds in flight, step 1 (docs/design/bird_flight_server_design.md): a pheasant sits tight until a player is within 9 m, bursts up
# 10 to 15 m, flies 120 to 300 m, glides the last part (state 17) and lands; its flight is the same ticked at 10 Hz or 0.5 Hz; over a hill
# it stays 3 m or more over the ground; a goose (Dave 25 Nov 2026: geese "refusing to fly away") takes off from a player, flies 150 to 400 m
# with its own fly and glide clips, and comes down on a lake's surface, never under it; a crow flies to the trees and sits 8 m up, stays there through a storm, and comes down after.
#   godot --headless --path . --script res://src/worldgen/tools/test_bird_flight.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

const GROUND := 10.0

var failures: int = 0
var hill: bool = false
var lake: bool = false   # a lake beyond x 100: its surface at GROUND, its bed 3 m below


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func ground(x: float, _z: float) -> float:
	if hill and x > 60.0 and x < 140.0:
		return GROUND + 40.0 * sin((x - 60.0) / 80.0 * PI)   # a 40 m hill across the way it flies

	if lake and x > 100.0:
		return GROUND - 3.0

	return GROUND


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return ground(x, z)
	a.blocked = func(_x, _z): return false
	a.water_level = func(x, _z): return GROUND if lake and x > 100.0 else NAN
	a.setup()
	a.traits = false
	a.rng.seed = 21
	return a


func flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


func fly_until_down(a, b: Dictionary, dt: float, limit_s: float) -> Dictionary:
	var seen: Dictionary = {"glide": false, "low": 0, "t": 0.0}

	while b.has("fly") and float(seen["t"]) < limit_s:
		a._step(b, dt, INF, Vector3.INF, INF, Vector3.INF)
		seen["t"] = float(seen["t"]) + dt
		seen["glide"] = bool(seen["glide"]) or int(b["state"]) == 17

		if b.has("fly") and float(seen["t"]) > 1.6:
			var land: Vector3 = b["fly"]["segs"].back()[1]

			if (int(b["state"]) == 15 or flat(b["pos"], land) > 10.0) and b["pos"].y < ground(b["pos"].x, b["pos"].z) + 2.99:
				seen["low"] = int(seen["low"]) + 1

	return seen


func _init() -> void:
	# 1. A pheasant sits tight at 12 m and bursts up at 8 m.
	var a = make()
	var ph: Dictionary = a.animals[a.spawn("pheasant", 0.0, 0.0)]
	var p12: Vector3 = Vector3(-12.0, GROUND, 0.0)
	a._step(ph, 0.1, 12.0, p12, 12.0, p12)
	check(int(ph["state"]) != 15, "a pheasant sits tight with a player 12 m off (state %d)" % int(ph["state"]))
	var p8: Vector3 = Vector3(-8.0, GROUND, 0.0)
	a._step(ph, 0.1, 8.0, p8, 8.0, p8)
	check(int(ph["state"]) == 15 and ph.has("fly"), "it bursts up with a player 8 m off (state %d)" % int(ph["state"]))

	# 2. Up 10 to 15 m after the 1.5 s burst, away from the player.
	for _k in 15:
		a._step(ph, 0.1, INF, Vector3.INF, INF, Vector3.INF)

	check(ph["pos"].y - GROUND >= 9.9 and ph["pos"].y - GROUND <= 15.1 and ph["pos"].x > 0.0, "after the burst it is 10 to 15 m up, away from the player (%.1f m)" % (ph["pos"].y - GROUND))

	# 3. It flies 120 to 300 m, glides the last part and lands.
	var seen: Dictionary = fly_until_down(a, ph, 0.1, 60.0)
	check(not ph.has("fly") and absf(ph["pos"].y - GROUND) < 0.01, "it lands (%.1f m up)" % (ph["pos"].y - GROUND))
	check(flat(ph["pos"], Vector3.ZERO) >= 119.0 and flat(ph["pos"], Vector3.ZERO) <= 301.0, "120 to 300 m off (%.0f m)" % flat(ph["pos"], Vector3.ZERO))
	check(bool(seen["glide"]), "gliding (state 17) on the way down")
	check(int(ph["state"]) == AnimalsScript.HOP, "then runs on into cover (state %d)" % int(ph["state"]))

	# 4. The same flight ticked at 10 Hz and at 0.5 Hz.
	var fast = make()
	var slow = make()
	var f1: Dictionary = fast.animals[fast.spawn("pheasant", 0.0, 0.0)]
	var s1: Dictionary = slow.animals[slow.spawn("pheasant", 0.0, 0.0)]
	fast._step(f1, 0.1, 5.0, p8, 5.0, p8)
	slow._step(s1, 0.1, 5.0, p8, 5.0, p8)

	for _k in 60:
		fast._step(f1, 0.1, INF, Vector3.INF, INF, Vector3.INF)

	for _k in 3:
		slow._step(s1, 2.0, INF, Vector3.INF, INF, Vector3.INF)

	check(f1["pos"].distance_to(s1["pos"]) < 0.05, "a flight is the same ticked at 10 Hz and 0.5 Hz (%.3f m apart)" % f1["pos"].distance_to(s1["pos"]))

	# 5. Over a 40 m hill it keeps 3 m or more over the ground (but where it comes down to land).
	hill = true
	var h = make()
	var hp: Dictionary = h.animals[h.spawn("pheasant", 0.0, 0.0)]
	h._step(hp, 0.1, 5.0, p8, 5.0, p8)
	var over: Dictionary = fly_until_down(h, hp, 0.1, 60.0)
	check(int(over["low"]) == 0, "over a hill it keeps 3 m over the ground (%d low samples)" % int(over["low"]))
	hill = false

	# 5b. A goose (wary kind) flies off from a player instead of waddling away, 150 to 400 m, and lands on the lake's surface.
	lake = true
	var g = make()
	var goose: Dictionary = g.animals[g.spawn("goose", 0.0, 0.0)]
	check(g.species_def("goose").has("flight"), "the goose has a flight row")
	var g_up: bool = false
	var g_ran: bool = false

	for _k in 100:   # up to 10 s: a stare first is allowed, a run on the ground is not
		g._step(goose, 0.1, 8.0, p8, 8.0, p8)

		if goose.has("fly"):
			g_up = true
			break

		g_ran = g_ran or int(goose["state"]) == AnimalsScript.FLEE

	check(g_up and not g_ran, "a goose takes off from a player 8 m off, not running on the ground (state %d)" % int(goose["state"]))
	var g_under: int = 0
	var g_t: float = 0.0

	while goose.has("fly") and g_t < 60.0:
		g._step(goose, 0.1, INF, Vector3.INF, INF, Vector3.INF)
		g_t += 0.1
		g_under += 1 if goose.has("fly") and goose["pos"].x > 100.0 and goose["pos"].y < GROUND - 0.11 else 0

	check(not goose.has("fly") and flat(goose["pos"], Vector3.ZERO) >= 149.0 and flat(goose["pos"], Vector3.ZERO) <= 401.0, "it flies 150 to 400 m (%.0f m)" % flat(goose["pos"], Vector3.ZERO))
	check(g_under == 0, "it never flies under the lake's surface (%d samples under)" % g_under)
	check(absf(goose["pos"].y - (GROUND - 0.1)) < 0.02, "it comes down on the water, riding the surface (%.2f m from it)" % (goose["pos"].y - GROUND))
	var clips: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/models.json")) as Dictionary)["species"]["goose"]["clips"]
	check(str(clips.get("15", "")) == "FlyFlapping" and str(clips.get("17", "")) == "FlyGliding", "it flies and glides with its own model's clips (%s)" % str(clips))
	lake = false

	# 6. A crow flies to the trees and sits 8 m up.
	var c = make()
	c.canopy = func(p): return p.x > 30.0   # trees beyond x 30
	var crow: Dictionary = c.animals[c.spawn("crow", 0.0, 0.0)]
	var p1: Vector3 = Vector3(-1.0, GROUND, 0.0)
	c._step(crow, 0.1, 1.0, p1, 1.0, p1)
	var _to_perch: Dictionary = fly_until_down(c, crow, 0.1, 60.0)
	check(bool(crow.get("perched", false)) and crow["pos"].x > 30.0 and absf(crow["pos"].y - GROUND - 8.0) < 0.5, "a crow sits 8 m up in the trees (%.1f m up at x %.0f)" % [crow["pos"].y - GROUND, crow["pos"].x])

	# 7. It stays up through a storm, and comes down after.
	crow["timer"] = 0.0
	c._wx = {"storm": 0.8}

	for _k in 20:
		c._step(crow, 0.5, INF, Vector3.INF, INF, Vector3.INF)

	check(bool(crow.get("perched", false)), "it stays perched through a storm")
	c._wx = {}
	c._step(crow, 0.5, INF, Vector3.INF, INF, Vector3.INF)
	var _down: Dictionary = fly_until_down(c, crow, 0.1, 30.0)
	check(not bool(crow.get("perched", false)) and absf(crow["pos"].y - GROUND) < 0.01, "after the storm it comes down to feed (%.1f m up)" % (crow["pos"].y - GROUND))

	print("test_bird_flight: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
