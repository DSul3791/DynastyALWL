extends SceneTree

# Animals lie down to rest (docs/design/ANIMAL_RESTING.md, Dave 21 Nov 2026, protocol 148): a grazing animal out of its hours is sent
# as state 19 (LIE); in its hours it is sent grazing (0); drinking (21) and hunched (20) come first; a flock or a bird never lies.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_rest.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var hour: float = 12.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.hour_now = func(): return hour
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.traits = false
	a.rng.seed = 7
	return a


# The first whole hour at which `def` is resting (want true) or active (want false), or -1.
func hour_where(a, def: Dictionary, want: bool) -> float:
	for h in 24:
		hour = float(h)

		if a.resting(def) == want:
			return hour

	return -1.0


func _init() -> void:
	var a = make()
	var deer: Dictionary = a.species_def("deer")
	var d: Dictionary = a.animals[a.spawn("deer", 0.0, 0.0)]
	d["state"] = a.GRAZE

	check(a.LIE == 19, "LIE is wire state 19")

	var rest_h: float = hour_where(a, deer, true)
	var up_h: float = hour_where(a, deer, false)
	check(rest_h >= 0.0 and up_h >= 0.0, "the deer has resting and active hours (rest %.0f, up %.0f)" % [rest_h, up_h])

	hour = rest_h
	check(a._wire_state(d) == a.LIE, "a grazing deer out of its hours is sent lying (%d)" % a._wire_state(d))
	d["drinking"] = true
	check(a._wire_state(d) == a.DRINK, "a drinking deer is sent drinking, not lying")
	d.erase("drinking")
	d["hunch"] = true
	check(a._wire_state(d) == a.HUNCH, "a hunched deer is sent hunched, not lying")
	d.erase("hunch")

	hour = up_h
	check(a._wire_state(d) == a.GRAZE, "in its hours it is sent grazing (%d)" % a._wire_state(d))

	d["state"] = a.FLEE
	hour = rest_h
	check(a._wire_state(d) == a.FLEE, "a fleeing deer is never sent lying")

	# A flock species never lies.
	for sp in a.cfg.get("species", {}).keys():
		var def: Dictionary = a.species_def(str(sp))

		if def.has("flock") or def.has("flight"):
			var fh: float = hour_where(a, def, true)

			if fh >= 0.0:
				var f: Dictionary = a.animals[a.spawn(str(sp), 50.0, 0.0)]
				f["state"] = a.GRAZE
				check(a._wire_state(f) != a.LIE, "a resting %s (flock or bird) is not sent lying" % str(sp))

	print("test_animal_rest: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
