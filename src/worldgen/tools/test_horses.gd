extends SceneTree

# Wild horses (Radar, 2026-10-21): each is born with a tamable value; flighty ones run from far, friendly ones let you close and
# walk up to you. godot --headless --path . --script res://src/worldgen/tools/test_horses.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(players: Array):
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.player_stances = func(): return [0]
	a.wind = func(): return {"wind": 0.0, "wind_dir": 0.0}
	a.setup()

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.rng.seed = 5
	return a


func _init() -> void:
	var def: Dictionary = AnimalsScript.new().cfg
	var players: Array = [Vector3(30.0, 10.0, 0.0)]
	var flighty = make(players)
	var f: int = flighty.spawn("horse", 0.0, 0.0)
	flighty.animals[f]["tame"] = 0.0
	flighty.animals[f]["timer"] = 100.0
	var friendly = make(players)
	var t: int = friendly.spawn("horse", 0.0, 0.0)
	friendly.animals[t]["tame"] = 1.0
	friendly.animals[t]["timer"] = 100.0

	for n in 40:
		flighty.tick(0.05)
		friendly.tick(0.05)

	check(flighty.animals[f]["state"] == AnimalsScript.FLEE, "a flighty horse runs from a player at 30 m")
	check(friendly.animals[t]["state"] != AnimalsScript.FLEE, "a friendly horse stays at 30 m")
	check(flighty.species_def("horse").has("tame"), "horses have the tame block")

	# A curious horse comes to a calm player and stops about stop_m short.
	var calm = make([Vector3(30.0, 10.0, 0.0)])
	var c: int = calm.spawn("horse", 0.0, 0.0)
	calm.animals[c]["tame"] = 0.9
	calm.animals[c]["timer"] = 0.1

	for n in 4000:
		calm.tick(0.05)

		if calm.animals[c]["state"] == AnimalsScript.FLEE:
			break

	var d: float = Vector2(calm.animals[c]["pos"].x - 30.0, calm.animals[c]["pos"].z).length()
	check(calm.animals[c]["state"] != AnimalsScript.FLEE and d < 20.0 and d >= 5.0, "a curious horse walks up and stops short (%.1f m away)" % d)

	# Born values vary.
	var herd = make([Vector3(500.0, 10.0, 0.0)])
	var seen: Dictionary = {}

	for k in 20:
		seen[snappedf(herd.animals[herd.spawn("horse", float(k) * 3.0, 0.0)]["tame"], 0.1)] = true

	check(seen.size() >= 5, "horses are born with different tame values (%d)" % seen.size())
	print("horses: %d failures" % failures)
	quit()
