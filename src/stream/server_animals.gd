extends RefCounted

# Animals, step B (data/animals/animals.json; design items/ANIMALS_DESIGN.md, Steve's plan 2026-10-21): the rabbit only.
# Records live on the server only (nothing is saved): spawned out of sight around each player, dropped when nobody is near.
# A rabbit grazes, hops a few metres now and then, and bolts away from a player who comes within spook_m. Movement uses the
# shared Steering module with NPCs. Ticks by distance to the nearest player (10 / 3 / 0.5 Hz), so far animals cost almost nothing.

const Steering := preload("res://src/shared/steering.gd")

const GRAZE := 0
const HOP := 1
const FLEE := 2

var cfg: Dictionary = {}
var animals: Dictionary = {}       # id int -> {id, sp, num, pos Vector3, heading, state, target Vector3, timer, acc, home}
var ground_height: Callable        # (x, z) -> height
var blocked: Callable              # (x, z) -> bool (deep water)
var player_positions: Callable     # () -> Array of Vector3
var ticks_run: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _next_id: int = 1
var _spawn_acc: float = 0.0


func setup() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	rng.randomize()   # luck-exempt: world wildlife placement, no player outcome


func species_def(sp: String) -> Dictionary:
	return cfg.get("species", {}).get(sp, {})


# Admin and tests: put an animal down at once (x, z; the ground gives y). Returns its id or 0.
func spawn(sp: String, x: float, z: float) -> int:
	var def: Dictionary = species_def(sp)

	if def.is_empty() or animals.size() >= int(cfg.get("server_cap", 150)):
		return 0

	var y: float = float(ground_height.call(x, z)) if ground_height.is_valid() else 0.0

	if is_nan(y):
		return 0

	var id: int = _next_id
	_next_id += 1
	var pos: Vector3 = Vector3(x, y, z)
	animals[id] = {"id": id, "sp": sp, "num": int(def.get("number", 0)), "pos": pos, "heading": rng.randf() * TAU, "state": GRAZE,   # luck-exempt: which way a new animal faces
		"target": pos, "timer": _graze_time(def), "acc": 0.0, "home": pos}
	return id


func _graze_time(def: Dictionary) -> float:
	var span: Array = def.get("graze_s", [3.0, 10.0])
	return rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how long an animal grazes


func tick(delta: float) -> void:
	var players: Array = player_positions.call() if player_positions.is_valid() else []
	var active_r: float = float(cfg.get("active_radius_m", 200.0))
	var near_m: float = float(cfg.get("near_m", 60.0))
	var mid_m: float = float(cfg.get("mid_m", 120.0))
	var despawn_m: float = float(cfg.get("despawn_m", 300.0))
	var gone: Array = []

	for id in animals:
		var a: Dictionary = animals[id]
		var near_d: float = INF
		var near_p: Vector3 = Vector3.INF

		for p in players:
			var d: float = Vector2(p.x - a["pos"].x, p.z - a["pos"].z).length()

			if d < near_d:
				near_d = d
				near_p = p

		if near_d > despawn_m:
			gone.append(id)
			continue

		if near_d > active_r:
			continue   # frozen: nothing runs until a player comes within active_radius_m

		var hz: float = float(cfg.get("hz_near", 10.0)) if near_d <= near_m else (float(cfg.get("hz_mid", 3.0)) if near_d <= mid_m else float(cfg.get("hz_far", 0.5)))
		a["acc"] += delta

		if a["acc"] < 1.0 / hz:
			continue

		var dt: float = a["acc"]
		a["acc"] = 0.0
		_step(a, dt, near_d, near_p)

	for id in gone:
		animals.erase(id)

	_spawn_acc += delta

	if _spawn_acc >= float(cfg.get("spawn_every_s", 2.0)):
		_spawn_acc = 0.0
		_top_up(players)


func _step(a: Dictionary, dt: float, near_d: float, near_p: Vector3) -> void:
	ticks_run += 1
	var def: Dictionary = species_def(a["sp"])

	if near_d <= float(def.get("spook_m", 14.0)) and a["state"] != FLEE:
		var away: Vector2 = Vector2(a["pos"].x - near_p.x, a["pos"].z - near_p.z).normalized()
		var run: float = float(def.get("flee_run_m", 25.0))
		a["state"] = FLEE
		a["target"] = a["pos"] + Vector3(away.x, 0.0, away.y) * run

	if a["state"] == GRAZE:
		a["timer"] -= dt

		if a["timer"] <= 0.0:
			var wander: float = float(def.get("wander_m", 6.0))
			var angle: float = rng.randf() * TAU   # luck-exempt: where a grazing animal hops next
			a["target"] = a["home"] + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.0, wander)   # luck-exempt: as above
			a["state"] = HOP

		return

	var speed: float = float(def.get("flee_mps", 7.5)) if a["state"] == FLEE else float(def.get("walk_mps", 1.5))
	var r: Dictionary = Steering.step(a["pos"], a["target"], speed, dt, ground_height, blocked, 0.4, a["heading"])

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]

	if r["arrived"] or not r["moved"]:
		if a["state"] == FLEE and near_d < float(def.get("safe_m", 35.0)):
			# Still too close: keep running away from the player.
			var away: Vector2 = Vector2(a["pos"].x - near_p.x, a["pos"].z - near_p.z).normalized()

			if not r["moved"]:
				away = away.rotated(rng.randf_range(-1.2, 1.2))   # luck-exempt: which way a cornered animal breaks

			a["target"] = a["pos"] + Vector3(away.x, 0.0, away.y) * float(def.get("flee_run_m", 25.0))
			return

		if a["state"] == FLEE:
			a["home"] = a["pos"]

		a["state"] = GRAZE
		a["timer"] = _graze_time(def)


# Keep each player's share topped up: new animals out of sight (spawn_min_m..spawn_max_m away), never near any player.
func _top_up(players: Array) -> void:
	var per_player: int = int(cfg.get("per_player_cap", 30))
	var never: float = float(cfg.get("never_within_m", 60.0))

	for p in players:
		for sp in cfg.get("species", {}):
			var def: Dictionary = species_def(sp)
			var have: int = 0
			var all_near: int = 0

			for id in animals:
				if Vector2(animals[id]["pos"].x - p.x, animals[id]["pos"].z - p.z).length() <= float(cfg.get("spawn_max_m", 250.0)):
					all_near += 1
					have += 1 if animals[id]["sp"] == sp else 0

			if have >= int(def.get("target_per_player", 6)) or all_near >= per_player or animals.size() >= int(cfg.get("server_cap", 150)):
				continue

			var angle: float = rng.randf() * TAU   # luck-exempt: where wildlife appears
			var dist: float = rng.randf_range(float(cfg.get("spawn_min_m", 150.0)), float(cfg.get("spawn_max_m", 250.0)))   # luck-exempt: as above
			var x: float = p.x + cos(angle) * dist
			var z: float = p.z + sin(angle) * dist
			var too_near: bool = false

			for q in players:
				too_near = too_near or Vector2(q.x - x, q.z - z).length() < maxf(never, float(cfg.get("spawn_min_m", 150.0)) * 0.9)

			if too_near or (blocked.is_valid() and bool(blocked.call(x, z))):
				continue

			spawn(sp, x, z)


# Rows [id, species number, position, heading radians, state] within send_radius_m of a point, nearest first, at most per_player_cap.
func rows_near(point: Vector3) -> Array:
	var radius: float = float(cfg.get("send_radius_m", 120.0))
	var found: Array = []

	for id in animals:
		var a: Dictionary = animals[id]
		var d: float = Vector2(a["pos"].x - point.x, a["pos"].z - point.z).length()

		if d <= radius:
			found.append([d, [id, a["num"], a["pos"], snappedf(a["heading"], 0.01), a["state"]]])

	found.sort_custom(func(l, r): return l[0] < r[0])
	var rows: Array = []

	for f in found.slice(0, int(cfg.get("per_player_cap", 30))):
		rows.append(f[1])

	return rows
