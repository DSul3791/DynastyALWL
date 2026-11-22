extends SceneTree

# Snare odds on flat open ground (MikeW, 3 Nov 2026: can a new player feed themselves with snares in the first hour?).
# One player stands still; six snares (the per-player cap) lie 10 to 30 m from rabbit homes, where a player who saw rabbits would
# set them; the real rabbit top-up and grazing run. Each
# check_s it does what server_traps.gd does: a rabbit inside lure_m is caught with base_chance x trail; with none inside, the
# nearest within draw_m is drawn to the snare with that chance x draw_share (animals.lure_to). Prints catches per snare per hour with and
# without the draw, on unworn ground (trail factor 0.1) and on a worn run (1.0).
#   godot --headless --path . --script res://src/worldgen/tools/snare_odds.gd [-- --minutes=60]

const AnimalsScript := preload("res://src/stream/server_animals.gd")


func run(minutes: float, trail: float, draw: bool, cfg: Dictionary) -> float:
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return 10.0
	a.blocked = func(x, z): return false
	a.player_positions = func(): return [Vector3(0.0, 10.0, 0.0)]
	a.hour_now = func(): return 12.0
	a.setup()
	a.traits = false   # seeded checks from before temperaments and young (test_big_game covers those)

	for sp in a.cfg["species"]:
		if sp != "rabbit":
			a.cfg["species"][sp]["target_per_player"] = 0

	a.rng.seed = 11
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var snares: Array = []

	for n in 600:
		a.tick(0.1)   # let the top-up fill in first

	var homes: Array = []

	for id in a.animals:
		homes.append(a.animals[id]["home"])

	for n in int(cfg["per_player"]):
		var home: Vector3 = homes[n % homes.size()]
		var ang: float = rng.randf() * TAU
		var r: float = rng.randf_range(float(cfg.get("test_home_min_m", 10.0)), float(cfg.get("test_home_max_m", 30.0)))
		snares.append(home + Vector3(cos(ang) * r, 0.0, sin(ang) * r))

	var p: float = float(cfg["base_chance"]) * trail
	var caught: int = 0
	var t: float = 0.0
	var next: float = float(cfg["check_s"])

	while t < minutes * 60.0:
		a.tick(0.1)
		t += 0.1

		if t < next:
			continue

		next += float(cfg["check_s"])

		for s in snares:
			var inside: Array = a.list_near(s, float(cfg["lure_m"]))

			if not inside.is_empty():
				if rng.randf() < p:
					a.snare(int(inside[0]["id"]))
					caught += 1
				continue

			if not draw:
				continue

			var best: int = 0
			var best_d: float = 1.0e9

			for row in a.list_near(s, float(cfg["draw_m"])):
				var d: float = Vector2(row["pos"].x - s.x, row["pos"].z - s.z).length()

				if row["sp"] == "rabbit" and d < best_d:
					best = int(row["id"])
					best_d = d

			if best != 0 and rng.randf() < p * float(cfg.get("draw_share", 1.0)):
				a.lure_to(best, s)

	return float(caught) / float(snares.size()) / (minutes / 60.0)


func _init() -> void:
	var minutes: float = 60.0

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = float(arg.substr(10))

	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/traps.json"))

	for trail in [0.1, 1.0]:
		print("trail factor %.1f: catches per snare per hour, lure only %.2f, with the draw (draw_m %.0f) %.2f" % [trail, run(minutes, trail, false, cfg), float(cfg.get("draw_m", 0.0)), run(minutes, trail, true, cfg)])

	quit(0)
