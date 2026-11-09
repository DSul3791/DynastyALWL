extends SceneTree

# Herd groups (docs/design/HERD_GROUPS.md, MikeW 8 Nov 2026): with animals.json groups.enabled a deer herd keeps round its leader as it
# grazes, the leader drifts into a light wind (Steve's _upwind_angle), the herd stands closer in rain, scatters on alarm and regroups once safe. Off: unchanged.
#   godot --headless --path . --script res://src/worldgen/tools/test_herd_groups.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = [Vector3(150.0, 10.0, 0.0)]
var weather: Dictionary = {"wind": 0.0, "wind_dir": 0.0, "rain": 0.0, "storm": 0.0}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)
	else:
		print("ok   ", what)


func make(on: bool):
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.wind = func(): return weather
	a.setup()
	a.traits = false

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0   # no spawning: the test makes its own herd

	a.cfg["groups"]["enabled"] = on
	a.cfg["weather"]["on"] = true      # the weather rules (Steve's #651): upwind drift and bunching read them
	a.rng.seed = 11
	var hid: int = 77
	a._herds[hid] = []

	for k in 5:
		var id: int = a.spawn("deer", float(k) * 4.0 - 8.0, float(k % 2) * 4.0)
		a.animals[id]["herd"] = hid
		a._herds[hid].append(id)

	return a


func run(a, seconds: float) -> void:
	for n in int(seconds / 0.05):
		a.tick(0.05)


# The widest distance of a member from the leader.
func spread(a) -> float:
	var ids: Array = a._herds[77].filter(func(i): return a.animals.has(i))
	var lead: Vector3 = a.animals[ids[0]]["pos"]
	var far: float = 0.0

	for i in ids:
		far = maxf(far, Vector2(a.animals[i]["pos"].x - lead.x, a.animals[i]["pos"].z - lead.z).length())

	return far


func _init() -> void:
	var a = make(true)
	var lead_id: int = a._herds[77][0]
	var start: Vector3 = a.animals[lead_id]["pos"]
	weather["wind"] = 0.4
	weather["wind_dir"] = PI      # blowing toward -x: deer drift into it (upwind, below a gale), toward +x
	run(a, 90.0)
	var dry: float = spread(a)
	check(dry < 14.0, "the herd keeps round its leader while grazing (widest %.1f m)" % dry)
	check(a.animals[lead_id]["pos"].x > start.x + 2.0, "the leader drifts into the wind (moved %.1f m toward +x)" % (a.animals[lead_id]["pos"].x - start.x))

	weather["rain"] = 1.0
	run(a, 90.0)
	var wet: float = spread(a)
	check(wet < dry or wet < 9.0, "the herd stands closer in rain (%.1f m, dry %.1f m)" % [wet, dry])

	# A player walks up: the herd scatters, fanning out.
	var mid: Vector3 = a.animals[lead_id]["pos"]
	players[0] = mid + Vector3(-12.0, 0.0, 0.0)
	run(a, 1.5)
	var heads: Array = []

	for i in a._herds[77]:
		if a.animals.has(i) and int(a.animals[i]["state"]) == a.FLEE:
			heads.append(Vector2(a.animals[i]["target"].x - a.animals[i]["pos"].x, a.animals[i]["target"].z - a.animals[i]["pos"].z).angle())

	var fan: float = 0.0

	for h in heads:
		fan = maxf(fan, absf(angle_difference(float(heads[0]), float(h))))

	check(heads.size() >= 3, "the herd bolts together (%d fleeing)" % heads.size())
	check(fan > deg_to_rad(10.0), "it scatters, not in single file (spread %.0f degrees)" % rad_to_deg(fan))

	players[0] = mid + Vector3(-140.0, 0.0, 0.0)      # well past safe_m, inside the active radius
	run(a, 120.0)
	check(spread(a) < 16.0, "it regroups once safe (widest %.1f m)" % spread(a))

	# In fog the leader's drift keeps to the wood edge (animals_in_fog_server.md 4.5): a wood west of x -10, so open ground from x -10 to 5 has
	# crowns within 15 m. From x 0 an 8 m drift east would leave the edge; with fog it tries other headings until one keeps it.
	var f = make(true)
	var fog_lead: Dictionary = f.animals[f._herds[77][0]]
	f.canopy = func(p: Vector3) -> bool: return p.x < -10.0
	f._fog_cfg()["on"] = true
	f._fog_cfg()["edge_tries"] = 12
	f.cfg["groups"]["drift_m"] = 8.0
	f._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0}, 0.1)
	var edge_kept: int = 0

	for k in 20:
		fog_lead["home"] = Vector3(0.0, 10.0, 0.0)
		fog_lead["drift_dir"] = 0.0   # heading east, off the edge
		f._group_target(fog_lead, f.species_def("deer"))

		if f.fog_edge_ok(fog_lead["home"]):
			edge_kept += 1

	check(f.fog_edge_wanted(f.species_def("deer")) and edge_kept == 20, "in fog the leader's drift stays on the wood edge (%d of 20)" % edge_kept)

	# Off: the old herd pull only.
	var b = make(false)
	run(b, 5.0)
	check(not b.animals[b._herds[77][0]].has("drift_dir"), "groups off: no leader drift")

	print("test_herd_groups: %d failures" % failures)
	quit(1 if failures > 0 else 0)
