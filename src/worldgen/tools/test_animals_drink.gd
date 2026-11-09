extends SceneTree

# Animals at water, the server half (docs/design/animals_at_water_server.md section 6; MikeW ANIMAL_DRINK.md): at dawn and dusk a deer
# walks to the nearest fresh water's edge and stands drinking (wire state 21), then goes home; not at noon, not to the sea; a wolf pack
# prowls by the water at those hours. Always on (the drink.on switch is gone). The client half: a drinking animal lifts its head now and
# then (animal_view.drink_looking).
#   godot --headless --path . --script res://src/worldgen/tools/test_animals_drink.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const AnimalViewScript := preload("res://src/client/animal_view.gd")

var failures: int = 0
var hour: float = 6.0
var sea: Array = [false]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 0.0 if sea[0] else 10.0
	a.water_level = func(x, _z): return (0.0 if sea[0] else 10.5) if x > 100.0 else NAN   # a lake (or the sea) east of x 100
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.hour_now = func(): return hour
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.traits = false
	a.rng.seed = 5
	return a


func row_state(a, x: Dictionary) -> int:
	var rows: Array = a.rows_near(x["pos"]).filter(func(r): return int(r[0]) == int(x["id"]))
	return int(rows[0][4]) if rows.size() == 1 else -1


func _init() -> void:
	var a = make()
	var deer: Dictionary = a.species_def("deer")
	var dc: Dictionary = a._drink_cfg()
	var d: Dictionary = a.animals[a.spawn("deer", 0.0, 0.0)]
	d["home"] = Vector3(0.0, 10.0, 0.0)

	check(not dc.has("on") and a.drink_on(), "drink is always on (no switch)")
	dc["chance"] = 1.0

	# The search: the lake edge east of x 100, the stand on dry ground just short of it.
	var found: Array = a.drink_spot(Vector3(0.0, 10.0, 0.0), 300.0)
	check(found.size() == 2 and found[1].x > 100.0 and found[0].x <= 100.0 and found[0].x > 95.0, "the stand is at the lake's edge (%s)" % str(found))

	# Dawn: it goes, stands drinking (state 21 on the wire), then goes home.
	check(a._drink_wander(d, deer) and d.has("drink_home") and d["home"].x > 90.0, "at dawn a deer heads for the water (home x %.0f)" % d["home"].x)
	d["pos"] = d["drink_at"]
	check(a._drink_wander(d, deer) and bool(d.get("drinking", false)) and float(d["timer"]) >= 60.0, "at the bank it stands drinking for a few minutes (%.0f s)" % float(d["timer"]))
	check(row_state(a, d) == AnimalsScript.DRINK, "the wire shows the drinking state (%d)" % row_state(a, d))
	check(absf(d["heading"]) < 0.5, "it faces the water (heading %.2f)" % d["heading"])
	check(not a._drink_wander(d, deer) and not d.has("drink_home") and d["home"].x < 1.0, "then it goes home")
	check(not a._drink_wander(d, deer), "once a twilight")

	# Noon: no.
	hour = 12.0
	check(not a._drink_wander(d, deer), "at noon it does not go to water")

	# The sea is never a drink.
	hour = 19.0
	sea[0] = true
	a._water_spots.clear()
	check(a.drink_spot(Vector3(0.0, 0.0, 0.0), 300.0).is_empty(), "the sea is not a drinking place")
	sea[0] = false
	a._water_spots.clear()

	# Wolves wait back from the water at dusk, and at noon prowl their home.
	var wait: Vector3 = a.wolf_wait_point(Vector3(0.0, 10.0, 0.0))
	check(wait != Vector3.INF and wait.x > 70.0 and wait.x < 95.0, "at dusk a pack waits back from the prey's water (x %.0f)" % wait.x)
	hour = 12.0
	check(a.wolf_wait_point(Vector3(0.0, 10.0, 0.0)) == Vector3.INF, "at noon it prowls its home")

	# The client: a drinking animal's head comes up now and then, for 1.5 to 3 s, at its own moments.
	var looks: Array = [0, 0]
	var longest: float = 0.0
	var run: float = 0.0
	var apart: bool = false

	for step in range(0, 6000):
		var t: float = float(step) * 0.1
		var up1: bool = AnimalViewScript.drink_looking(1, t)
		looks[0] += 1 if up1 else 0
		looks[1] += 1 if AnimalViewScript.drink_looking(2, t) else 0
		apart = apart or up1 != AnimalViewScript.drink_looking(2, t)
		run = run + 0.1 if up1 else 0.0
		longest = maxf(longest, run)

	check(looks[0] > 0 and looks[0] < 6000 / 4, "a drinking animal looks up now and then (%d of 6000 tenths)" % looks[0])
	check(longest >= 1.4 and longest <= 3.05, "a look lasts 1.5 to 3 s (longest %.1f s)" % longest)
	check(apart, "two animals of a herd look up at different moments")

	print("animals at water: %d failures" % failures)
	quit(1 if failures > 0 else 0)
