extends SceneTree

# Animals lie down to rest (docs/design/ANIMAL_RESTING.md, Dave 21 Nov 2026, protocol 148): a grazer is sent as state 19 (LIE) when it
# is resting, or when its fixed draw is at or over its active chance (a deer herd by day about 60% bedded, at dusk all up); drinking
# (21) and hunched (20) come first; a moving or fleeing animal is never sent lying; a flock never lies; a hidden rabbit is not alarmed
# by a mate; the client takes a lying clip by name, never a change of pose or a death, and a lying clip is never the standing idle.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_rest.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const AnimalViewScript := preload("res://src/client/animal_view.gd")

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


# The first whole hour at which `def`'s active chance is `chance` (within 0.01), or -1.
func hour_at(a, def: Dictionary, chance: float) -> float:
	for h in 24:
		hour = float(h)

		if absf(a.activity_chance(def) - chance) < 0.01:
			return hour

	return -1.0


func lying_count(a, herd: Array) -> int:
	var n: int = 0

	for x in herd:
		n += 1 if a._wire_state(x) == a.LIE else 0

	return n


func clips(names: Array) -> AnimationPlayer:
	var p := AnimationPlayer.new()
	var lib := AnimationLibrary.new()

	for n in names:
		lib.add_animation(StringName(n), Animation.new())

	p.add_animation_library("", lib)
	return p


func _init() -> void:
	var a = make()
	var deer: Dictionary = a.species_def("deer")
	check(a.LIE == 19, "LIE is wire state 19")
	var herd: Array = []

	for n in 20:
		var d: Dictionary = a.animals[a.spawn("deer", float(n) * 3.0, 0.0)]
		d["state"] = a.GRAZE
		herd.append(d)

	var day_h: float = hour_at(a, deer, 0.4)
	var dusk_h: float = hour_at(a, deer, 1.0)
	var night_h: float = hour_at(a, deer, 0.2)
	check(day_h >= 0.0 and dusk_h >= 0.0 and night_h >= 0.0, "the deer row has day 0.4, dusk 1.0, night 0.2 (%.0f %.0f %.0f)" % [day_h, dusk_h, night_h])

	hour = dusk_h
	check(lying_count(a, herd) == 0, "at dusk every deer is up (%d of 20 lying)" % lying_count(a, herd))
	hour = day_h
	var by_day: int = lying_count(a, herd)
	check(by_day >= 8 and by_day <= 16, "by day about 60% of a herd is bedded (%d of 20)" % by_day)
	hour = night_h
	check(lying_count(a, herd) > by_day, "at night more are bedded than by day (%d)" % lying_count(a, herd))

	# A bedded deer: drinking and hunched come first; moving or fleeing it is never sent lying.
	var bed: Dictionary = {}

	for x in herd:
		if bed.is_empty() and a._wire_state(x) == a.LIE:
			bed = x

	check(not bed.is_empty(), "one deer is bedded at night")

	if not bed.is_empty():
		bed["drinking"] = true
		check(a._wire_state(bed) == a.DRINK, "a drinking deer is sent drinking, not lying")
		bed.erase("drinking")
		bed["hunch"] = true
		check(a._wire_state(bed) == a.HUNCH, "a hunched deer is sent hunched, not lying")
		bed.erase("hunch")

		for st in [a.HOP, a.FLEE, a.ALERT]:
			bed["state"] = st
			check(a._wire_state(bed) == st, "a deer in state %d is sent as it is, not lying" % st)

		bed["state"] = a.GRAZE

	# Resting (out of its hours) always lies.
	var horse: Dictionary = a.species_def("horse")

	if not horse.is_empty():
		var low: float = -1.0

		for h in 24:
			hour = float(h)
			low = hour if low < 0.0 and a.resting(horse) else low

		if low >= 0.0:
			hour = low
			var hs: int = a.spawn("horse", 0.0, 300.0)

			if hs != 0:
				a.animals[hs]["state"] = a.GRAZE
				check(a._wire_state(a.animals[hs]) == a.LIE, "a resting horse is sent lying")

	# A flock species never lies, at any hour.
	for sp in a.cfg.get("species", {}).keys():
		var def: Dictionary = a.species_def(str(sp))

		if def.has("flock") or def.has("flight"):
			var fid: int = a.spawn(str(sp), 500.0, 0.0)

			if fid != 0 and a.animals.has(fid):
				a.animals[fid]["state"] = a.GRAZE
				var ever: bool = false

				for h in 24:
					hour = float(h)
					ever = ever or a._wire_state(a.animals[fid]) == a.LIE

				check(not ever, "a %s (flock or bird) is never sent lying" % str(sp))

	# A rabbit in its burrow is not alarmed by a mate bolting outside.
	var r1: Dictionary = a.animals[a.spawn("rabbit", 0.0, 900.0)]
	var r2: Dictionary = a.animals[a.spawn("rabbit", 2.0, 900.0)]
	r1["herd"] = 777
	r2["herd"] = 777
	a._herds[777] = [r1["id"], r2["id"]]
	r2["state"] = a.HIDDEN
	r2["alarm"] = -1.0
	a._alarm_herd(r1, a.species_def("rabbit"))
	check(float(r2["alarm"]) < 0.0, "a hidden rabbit is not set to bolt by its mate")

	# The client: a lying clip by name, never a change of pose or a death; the standing idle is never a lying or sleeping clip.
	var v = AnimalViewScript.new()
	var p: AnimationPlayer = clips(["Idle", "Walk", "Idle_to_Lying", "Lying_Down", "Death_Lying", "Lying_Get_Up", "Lying_Idle_02"])
	check(v._role_clip(p, {}, "19") == "Lying_Idle_02", "the lying clip is Lying_Idle_02 (%s)" % v._role_clip(p, {}, "19"))
	var only_change: AnimationPlayer = clips(["Idle", "Lying_Down", "Idle_to_Lying"])
	check(v._role_clip(only_change, {}, "19") == "", "with only change-of-pose clips there is no lying clip (%s)" % v._role_clip(only_change, {}, "19"))
	var dog: AnimationPlayer = clips(["idle_lay_01", "sleep_idle", "idle_stand"])
	check(v._role_clip(dog, {}, "0") == "idle_stand", "the standing idle is not a lying or sleeping clip (%s)" % v._role_clip(dog, {}, "0"))
	check(v._role_clip(dog, {}, "19") == "idle_lay_01" or v._role_clip(dog, {}, "19") == "sleep_idle", "the dog lies on its lay or sleep clip (%s)" % v._role_clip(dog, {}, "19"))
	p.free()
	only_change.free()
	dog.free()
	v.free()

	print("test_animal_rest: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
