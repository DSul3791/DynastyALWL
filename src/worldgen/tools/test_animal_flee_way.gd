extends SceneTree

# A frightened animal gets away by a real route (Dave 24 Nov 2026 play test, at a marsh by the starter town: "this deer seems stuck he just
# spins in circles not able to run away ... until I hit him then he ran"). Its flight line ran across water: Steering turns at most a right
# angle off a target, so it stepped to and fro along the bank, a metre each way every tenth of a second, and never got away. Now a flight
# line blocked near at hand takes the clear way nearest to away from the threat (server_animals _flee_target, _open_way), a flight that goes
# round in circles is given one, and an animal with no way at all stands at bay facing the threat instead of spinning.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_flee_way.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

const GROUND := 10.0

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func _animals(players: Array, water: Callable) -> Object:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return GROUND
	a.blocked = water
	a.player_positions = func(): return players
	a.player_stances = func(): return [0]
	a.wind = func(): return {"wind": 0.0, "wind_dir": 0.0}
	a.setup()
	a.traits = false

	for s in a.cfg["species"]:
		a.cfg["species"][s]["target_per_player"] = 0

	a.rng.seed = 7
	a.big_game.player_info = func(): return [{"peer": 1, "pos": players[0], "stance": 0, "hp": 1.0}]
	return a


# A passive deer at `at` bolts from a player standing at `player`, then runs `seconds` of 0.1 s ticks. Returns {start, end, path, flips,
# bay (a tick at bay seen), far (its farthest from the player)}. A flip: a step turned more than 120 degrees from the one before.
func run(at: Vector3, player: Vector3, water: Callable, seconds: float) -> Dictionary:
	var players: Array = [player]
	var a = _animals(players, water)
	var id: int = a.spawn("deer", at.x, at.z)
	var b: Dictionary = a.animals[id]
	b["pos"] = at
	b["temper"] = "passive"
	b["protective"] = false
	a._bolt(b, player, a.species_def("deer"))
	var was: Vector3 = b["pos"]
	var last: Vector2 = Vector2.ZERO
	var out: Dictionary = {"start": at, "path": 0.0, "flips": 0, "bay": false, "far": 0.0}
	var t: float = 0.0

	while t < seconds and a.animals.has(id):
		a.tick(0.1)
		t += 0.1
		var step: Vector2 = Vector2(b["pos"].x - was.x, b["pos"].z - was.z)

		if step.length() > 0.05:
			if last != Vector2.ZERO and step.normalized().dot(last) < cos(deg_to_rad(120.0)):
				out["flips"] = int(out["flips"]) + 1

			last = step.normalized()
			out["path"] = float(out["path"]) + step.length()

		out["bay"] = bool(out["bay"]) or bool(b.get("bay", false))
		out["far"] = maxf(float(out["far"]), Vector2(b["pos"].x - player.x, b["pos"].z - player.z).length())
		was = b["pos"]

	out["end"] = b["pos"]
	return out


func _init() -> void:
	# A bank: water north of z = 0, the deer 1.5 m from it, the player 3 m south of the deer, so straight away is into the water.
	var bank: Callable = func(_x: float, z: float) -> bool: return z >= 0.0
	var r: Dictionary = run(Vector3(0.0, GROUND, -1.5), Vector3(0.3, GROUND, -4.5), bank, 4.0)
	var got: float = Vector2((r["end"] as Vector3).x - (r["start"] as Vector3).x, (r["end"] as Vector3).z - (r["start"] as Vector3).z).length()
	check(int(r["flips"]) <= 1, "a deer whose flight line is across water does not step to and fro on the bank (%d about-turns)" % int(r["flips"]))
	check(got > 20.0 and float(r["far"]) > 20.0, "it gets away along the bank: %.1f m from where it was, %.1f m from the player at most, in 4 s" % [got, float(r["far"])])
	check(got > 0.6 * float(r["path"]), "by a real route, not round in circles (%.1f m gained of %.1f m run)" % [got, float(r["path"])])
	check(not bool(r["bay"]), "with a way out it never stands at bay")

	# The way out itself: along the bank (neither into the water nor back past the player).
	var way: Vector3 = AnimalsScript._open_way(Vector3(0.0, GROUND, -1.5), Vector3(0.3, GROUND, -4.5), Vector2(-0.1, 1.0).normalized(), func(_x, _z): return GROUND, bank)
	check(way != Vector3.INF and way.z < 0.0 and absf(way.x) >= AnimalsScript.OPEN_MIN_M, "the way out found runs along the bank (%s)" % str(way))

	# Cornered: an islet 3 m across, the player on it. No way out: it stands at bay facing them, not spinning, and does not leave the islet.
	var islet: Callable = func(x: float, z: float) -> bool: return Vector2(x, z).length() > 1.5
	var c: Dictionary = run(Vector3(-0.8, GROUND, 0.0), Vector3(0.9, GROUND, 0.0), islet, 4.0)
	check(bool(c["bay"]) and int(c["flips"]) <= 1, "a deer with no way out stands at bay (%s), not to and fro (%d about-turns)" % [str(c["bay"]), int(c["flips"])])
	check(Vector2((c["end"] as Vector3).x, (c["end"] as Vector3).z).length() <= 1.5, "and stays on dry ground")

	# Open ground: as before, straight away on its zig-zag.
	var open_ground: Callable = func(_x: float, _z: float) -> bool: return false
	var o: Dictionary = run(Vector3(0.0, GROUND, 0.0), Vector3(0.0, GROUND, -4.0), open_ground, 3.0)
	check((o["end"] as Vector3).z > 20.0 and int(o["flips"]) == 0 and not bool(o["bay"]), "on open ground it runs straight away as before (%.1f m north)" % (o["end"] as Vector3).z)

	print("test_animal_flee_way: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
