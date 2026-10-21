extends RefCounted

# Animals, step B (data/animals/animals.json; design items/ANIMALS_DESIGN.md, Steve's plan 2026-10-21): the rabbit only.
# Records live on the server only (nothing is saved): spawned out of sight around each player, dropped when nobody is near.
# A rabbit grazes, hops a few metres now and then, and bolts away from a player who comes within spook_m. Movement uses the
# shared Steering module with NPCs. Ticks by distance to the nearest player (10 / 3 / 0.5 Hz), so far animals cost almost nothing.

const Steering := preload("res://src/shared/steering.gd")

const GRAZE := 0
const HOP := 1
const FLEE := 2
const ALERT := 3
const HIDDEN := 5               # in its burrow: never sent, never hunted
const STAGGER := 4              # a quarter of the animals are looked at each tick

var cfg: Dictionary = {}
var animals: Dictionary = {}       # id int -> {id, sp, num, pos Vector3, heading, state, target Vector3, timer, acc, home}
var ground_height: Callable        # (x, z) -> height
var blocked: Callable              # (x, z) -> bool (deep water)
var player_positions: Callable     # () -> Array of Vector3
var player_stances: Callable       # () -> Array of stances in player_positions order (0 stand, 1 crouch, 2 sit, 3 lie)
var wind: Callable                 # () -> the weather dictionary ("wind" 0..1 and "wind_dir" radians, the way it blows toward)
var died: Callable                 # (species, position, source peer) when an animal is killed
var ticks_run: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var blood: Array = []              # drops [position Vector3, born msec] a wounded animal left, oldest first
var _next_id: int = 1
var _spawn_acc: float = 0.0
var _tick_no: int = 0
var _top_idx: int = 0
var _next_herd: int = 1
var _wind_s: float = 0.0
var _wind_dir: Vector2 = Vector2.ZERO
var _herds: Dictionary = {}       # herd id -> Array of animal ids (3 to 6 deer)


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
		"target": pos, "timer": _graze_time(def), "acc": 0.0, "home": pos, "hp": float(def.get("health", 5.0)), "herd": 0, "alarm": -1.0, "burst": 0.0, "alert": 0.0, "burrow": pos if float(def.get("burrow_m", 0.0)) > 0.0 else Vector3.INF, "to_burrow": false}
	return id


# One drop of blood where a wounded animal is (a trail: every_m apart, at most max_drops per animal, max_total on the map,
# gone after life_s seconds).
func _drop_blood(a: Dictionary) -> void:
	var sp: Dictionary = cfg.get("blood", {})

	if int(a["drops"]) >= int(sp.get("max_drops", 24)):
		return

	a["drops"] = int(a["drops"]) + 1
	a["last_drop"] = a["pos"]
	blood.append([a["pos"], Time.get_ticks_msec()])

	while blood.size() > int(sp.get("max_total", 200)):
		blood.pop_front()


# The blood trail within send_radius_m of a point (nearest first, at most max_sent), dropping what has dried.
func blood_near(point: Vector3) -> PackedVector3Array:
	var life_ms: int = int(float(cfg.get("blood", {}).get("life_s", 240.0)) * 1000.0)
	var now: int = Time.get_ticks_msec()

	while not blood.is_empty() and now - int(blood[0][1]) > life_ms:
		blood.pop_front()

	var radius: float = float(cfg.get("send_radius_m", 120.0))
	var found: Array = []

	for drop in blood:
		var d: float = Vector2(drop[0].x - point.x, drop[0].z - point.z).length()

		if d <= radius:
			found.append([d, drop[0]])

	found.sort_custom(func(l, r): return l[0] < r[0])
	var out: PackedVector3Array = PackedVector3Array()

	for f in found.slice(0, int(cfg.get("blood", {}).get("max_sent", 80))):
		out.append(f[1])

	return out


# The one damage hook for animals (spears now, traps and others later): returns true when it killed. A hurt animal bolts.
func damage(id: int, amount: float, source_peer: int = -1, _kind: String = "spear") -> bool:
	if not animals.has(id) or amount <= 0.0:
		return false

	var a: Dictionary = animals[id]
	a["hp"] -= amount

	if a["hp"] <= 0.0:
		animals.erase(id)

		if died.is_valid():
			died.call(a["sp"], a["pos"], source_peer)

		return true

	a["wound"] = true
	a["drops"] = 0
	a["last_drop"] = a["pos"]
	_drop_blood(a)
	a["state"] = FLEE
	a["target"] = a["pos"] + Vector3(cos(a["heading"] + PI), 0.0, sin(a["heading"] + PI)) * float(species_def(a["sp"]).get("flee_run_m", 25.0))
	return false


# The animal a jab from `origin` along `dir` reaches: nearest within reach and about 35 degrees of the aim; 0 for none.
func target_along(origin: Vector3, dir: Vector3, reach: float) -> int:
	var flat: Vector2 = Vector2(dir.x, dir.z).normalized()
	var best: int = 0
	var best_d: float = reach

	for id in animals:
		if animals[id]["state"] == HIDDEN:
			continue

		var to: Vector2 = Vector2(animals[id]["pos"].x - origin.x, animals[id]["pos"].z - origin.z)
		var d: float = to.length()

		if d <= best_d and (d < 0.6 or to.normalized().dot(flat) > 0.82) and absf(animals[id]["pos"].y - origin.y) < 3.5:
			best_d = d
			best = id

	return best


func _graze_time(def: Dictionary) -> float:
	var span: Array = def.get("graze_s", [3.0, 10.0])
	return rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how long an animal grazes


func tick(delta: float) -> void:
	var players: Array = player_positions.call() if player_positions.is_valid() else []
	var active_r: float = float(cfg.get("active_radius_m", 200.0))
	var near_m: float = float(cfg.get("near_m", 60.0))
	var mid_m: float = float(cfg.get("mid_m", 120.0))
	var despawn_m: float = float(cfg.get("despawn_m", 300.0))
	var budget_us: int = int(float(cfg.get("tick_budget_ms", 1.0)) * 1000.0)
	var started: int = Time.get_ticks_usec()
	var gone: Array = []
	_tick_no += 1
	var ids: Array = animals.keys()
	var count: int = ids.size()
	var stances: Array = player_stances.call() if player_stances.is_valid() else []
	var weather: Dictionary = wind.call() if wind.is_valid() else {}
	_wind_s = float(weather.get("wind", 0.0))
	_wind_dir = Vector2.from_angle(float(weather.get("wind_dir", 0.0)))

	# A quarter of the animals per tick (id mod 4), each one's elapsed time kept in acc so its step still gets the true dt; if the
	# tick's AI budget runs out the rest wait for the next one (the rotating start keeps that fair).
	for k in count:
		var id: int = int(ids[(k + _tick_no * 7) % count])
		var a: Dictionary = animals[id]
		a["acc"] += delta

		if (id + _tick_no) % STAGGER != 0:
			continue

		if k > 0 and Time.get_ticks_usec() - started > budget_us:
			continue   # out of budget: this one waits (its acc keeps growing, so its next step is longer, not lost)

		var near_d: float = INF
		var near_p: Vector3 = Vector3.INF
		var seen_d: float = INF   # the distance as the animal perceives it: wind, stance and cover stretch or shrink it
		var seen_p: Vector3 = Vector3.INF
		var def_s: Dictionary = species_def(a["sp"])
		var reach_m: float = maxf(float(def_s.get("alert_m", 0.0)), float(def_s.get("spook_m", 14.0))) * float(cfg.get("senses", {}).get("far_factor", 1.5))

		for pi in players.size():
			var p: Vector3 = players[pi]
			var d: float = Vector2(p.x - a["pos"].x, p.z - a["pos"].z).length()

			if d < near_d:
				near_d = d
				near_p = p

			if d <= reach_m:
				var sensed: float = d / _sense_factor(a, def_s, p, d, int(stances[pi]) if pi < stances.size() else 0)

				if sensed < seen_d:
					seen_d = sensed
					seen_p = p

		if seen_p == Vector3.INF:
			seen_d = near_d
			seen_p = near_p

		if near_d > despawn_m:
			gone.append(id)
			continue

		if near_d > active_r:
			a["acc"] = 0.0
			continue   # frozen: nothing runs until a player comes within active_radius_m

		var hz: float = float(cfg.get("hz_near", 10.0)) if near_d <= near_m else (float(cfg.get("hz_mid", 3.0)) if near_d <= mid_m else float(cfg.get("hz_far", 0.5)))

		if a["acc"] < 1.0 / hz:
			continue

		var dt: float = minf(a["acc"], 1.0)
		a["acc"] = 0.0
		_step(a, dt, near_d, near_p, seen_d, seen_p)

	for id in gone:
		animals.erase(id)

	_spawn_acc += delta

	# One player's share is looked at per pass, so with 20 players each is still topped up every spawn_every_s but never in one tick.
	if not players.is_empty() and _spawn_acc >= float(cfg.get("spawn_every_s", 2.0)) / float(players.size()):
		_spawn_acc = 0.0
		_top_idx = (_top_idx + 1) % players.size()
		_top_up(players, _top_idx)


func _step(a: Dictionary, dt: float, near_d: float, near_p: Vector3, seen_d: float, seen_p: Vector3) -> void:
	ticks_run += 1
	var def: Dictionary = species_def(a["sp"])

	if a["state"] == HIDDEN:
		a["timer"] -= dt

		if a["timer"] <= 0.0:
			if seen_d > float(def.get("spook_m", 14.0)) * 1.5:
				a["state"] = GRAZE
				a["timer"] = _graze_time(def)
			else:
				a["timer"] = 3.0   # a player is still close to the burrow: stay down a little longer

		return

	if a["alarm"] >= 0.0:
		a["alarm"] -= dt

		if a["alarm"] < 0.0 and a["state"] != FLEE:
			a["alarm"] = -1.0
			_bolt(a, near_p, def)

	if seen_d <= float(def.get("spook_m", 14.0)) and a["state"] != FLEE:
		_bolt(a, seen_p, def)

		# The sentinel (the first to notice) alarms the herd: each mate follows after a short random moment.
		if a["herd"] != 0:
			var span: Array = def.get("alarm_s", [0.2, 0.9])

			for mate_id in _herds.get(a["herd"], []):
				if mate_id != a["id"] and animals.has(mate_id) and animals[mate_id]["state"] != FLEE and animals[mate_id]["alarm"] < 0.0:
					animals[mate_id]["alarm"] = rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how fast a herd mate reacts

	var alert_m: float = float(def.get("alert_m", 0.0))

	if a["state"] == ALERT:
		a["alert"] -= dt

		if seen_d <= float(def.get("spook_m", 14.0)):
			_bolt(a, seen_p, def)
		elif a["alert"] <= 0.0 or seen_d > alert_m * 1.3:
			a["state"] = GRAZE
			a["timer"] = _graze_time(def)

		return

	if a["state"] != FLEE and alert_m > 0.0 and seen_d <= alert_m and a["alert"] <= 0.0 and seen_d > float(def.get("spook_m", 14.0)):
		var span2: Array = def.get("alert_s", [1.0, 2.0])
		a["state"] = ALERT
		a["alert"] = rng.randf_range(float(span2[0]), float(span2[1]))   # luck-exempt: how long an animal watches
		a["heading"] = atan2(seen_p.z - a["pos"].z, seen_p.x - a["pos"].x)
		return

	if a["state"] == GRAZE and seen_d > alert_m:
		a["alert"] = 0.0   # it forgets once the player is well away

	if a["state"] == GRAZE:
		a["timer"] -= dt

		if a["herd"] != 0 and float(def.get("herd_pull_m", 0.0)) > 0.0:
			var centre: Vector3 = _herd_centre(a["herd"])

			if centre != Vector3.INF and a["home"].distance_to(centre) > float(def.get("herd_pull_m", 12.0)):
				a["home"] = a["home"].lerp(centre, 0.5)

		if a["timer"] <= 0.0:
			var wander: float = float(def.get("wander_m", 6.0))
			var angle: float = rng.randf() * TAU   # luck-exempt: where a grazing animal hops next
			a["target"] = a["home"] + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.0, wander)   # luck-exempt: as above
			a["state"] = HOP

		return

	var speed: float = float(def.get("walk_mps", 1.5))

	if a["state"] == FLEE:
		# Sprint for burst_s seconds, then trot: an animal cannot outrun a chase for ever.
		a["burst"] += dt
		speed = float(def.get("flee_mps", 7.5)) * (1.0 if a["burst"] <= float(def.get("burst_s", 3.0)) else float(def.get("trot_share", 0.5)))
	var r: Dictionary = Steering.step(a["pos"], a["target"], speed, dt, ground_height, blocked, 0.4, a["heading"])

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]

		if a.get("wound", false) and a["pos"].distance_to(a["last_drop"]) >= float(cfg.get("blood", {}).get("every_m", 2.5)):
			_drop_blood(a)

	if a["state"] == FLEE and a["to_burrow"] and (r["arrived"] or not r["moved"]):
		a["to_burrow"] = false

		if r["arrived"]:
			var hide: Array = def.get("hide_s", [20.0, 40.0])
			a["state"] = HIDDEN
			a["pos"] = a["burrow"]
			a["timer"] = rng.randf_range(float(hide[0]), float(hide[1]))   # luck-exempt: how long an animal stays in its burrow
			return

	if r["arrived"] or not r["moved"]:
		if a["state"] == FLEE and near_d < float(def.get("safe_m", 35.0)):
			# Still too close: keep running away from the player.
			var away: Vector2 = Vector2(a["pos"].x - near_p.x, a["pos"].z - near_p.z).normalized()

			if not r["moved"]:
				away = away.rotated(rng.randf_range(-1.2, 1.2))   # luck-exempt: which way a cornered animal breaks

			a["target"] = a["pos"] + _zig(away, def) * float(def.get("zig_leg_m", float(def.get("flee_run_m", 25.0))))
			_to_burrow(a, away, def)
			return

		if a["state"] == FLEE:
			a["home"] = a["pos"]

		a["state"] = GRAZE
		a["timer"] = _graze_time(def)


# Keep each player's share topped up: new animals out of sight (spawn_min_m..spawn_max_m away), never near any player.
func _top_up(players: Array, only: int) -> void:
	for hid in _herds.keys():
		var alive: Array = []

		for mate_id in _herds[hid]:
			if animals.has(mate_id):
				alive.append(mate_id)

		if alive.is_empty():
			_herds.erase(hid)
		else:
			_herds[hid] = alive

	var per_player: int = int(cfg.get("per_player_cap", 30))
	var never: float = float(cfg.get("never_within_m", 60.0))

	for p in [players[only]]:
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

			var herd: Array = def.get("herd", [])

			if herd.is_empty():
				spawn(sp, x, z)
				continue

			var members: int = clampi(rng.randi_range(int(herd[0]), int(herd[1])), 1, maxi(per_player - all_near, 1))   # luck-exempt: how many deer in a herd
			var hid: int = _next_herd
			_next_herd += 1
			_herds[hid] = []

			for k in members:
				var id: int = spawn(sp, x + rng.randf_range(-6.0, 6.0), z + rng.randf_range(-6.0, 6.0))   # luck-exempt: herd spread

				if id != 0:
					animals[id]["herd"] = hid
					_herds[hid].append(id)


# Rows [id, species number, position, heading radians, state] within send_radius_m of a point, nearest first, at most per_player_cap.
func rows_near(point: Vector3) -> Array:
	var radius: float = float(cfg.get("send_radius_m", 120.0))
	var found: Array = []

	for id in animals:
		var a: Dictionary = animals[id]
		var d: float = Vector2(a["pos"].x - point.x, a["pos"].z - point.z).length()

		if d <= radius and a["state"] != HIDDEN:
			found.append([d, [id, a["num"], a["pos"], snappedf(a["heading"], 0.01), a["state"]]])

	found.sort_custom(func(l, r): return l[0] < r[0])
	var rows: Array = []

	for f in found.slice(0, int(cfg.get("per_player_cap", 30))):
		rows.append(f[1])

	return rows


func _bolt(a: Dictionary, from: Vector3, def: Dictionary) -> void:
	var away: Vector2 = Vector2(a["pos"].x - from.x, a["pos"].z - from.z).normalized()

	if away == Vector2.ZERO:
		away = Vector2.from_angle(a["heading"])

	a["state"] = FLEE
	a["burst"] = 0.0
	a["alert"] = 0.0
	a["target"] = a["pos"] + _zig(away, def) * float(def.get("zig_leg_m", float(def.get("flee_run_m", 25.0))))
	_to_burrow(a, away, def)


# A rabbit with its burrow in reach and away from the threat runs for it and goes to ground there.
func _to_burrow(a: Dictionary, away: Vector2, def: Dictionary) -> void:
	a["to_burrow"] = false

	if a["burrow"] == Vector3.INF:
		return

	var to_b: Vector2 = Vector2(a["burrow"].x - a["pos"].x, a["burrow"].z - a["pos"].z)

	if to_b.length() <= float(def.get("burrow_m", 0.0)) and (to_b.length() < 2.0 or to_b.normalized().dot(away) > 0.0):
		a["target"] = a["burrow"]
		a["to_burrow"] = true


# How much farther or nearer a player seems to an animal: downwind of the player it smells them from farther off, upwind it does
# not; a crouching or lying player is harder to see; with the ground in the way only scent and sound are left.
func _sense_factor(a: Dictionary, def: Dictionary, p: Vector3, d: float, stance: int) -> float:
	var sen: Dictionary = cfg.get("senses", {})
	var f: float = 1.0

	if _wind_s > 0.0 and d > 0.01:
		var to_animal: Vector2 = Vector2(a["pos"].x - p.x, a["pos"].z - p.z) / d
		f = maxf(1.0 + float(sen.get("scent_gain", 0.5)) * _wind_s * to_animal.dot(_wind_dir), 0.5)

	if stance == 1:
		f *= float(sen.get("crouch_factor", 0.6))
	elif stance == 3:
		f *= float(sen.get("lie_factor", 0.5))
	elif stance == 2:
		f *= float(sen.get("sit_factor", 0.8))

	if d > float(sen.get("always_notice_m", 8.0)) and not _sees(a, def, p, d, stance == 1 or stance == 3):
		f *= float(sen.get("blind_factor", 0.35))

	return f


# Line of sight over the ground only (trees do not block yet): the terrain along the line from the animal's eye to the player's.
func _sees(a: Dictionary, def: Dictionary, p: Vector3, d: float, low: bool) -> bool:
	if not ground_height.is_valid():
		return true

	var eye_a: float = a["pos"].y + float(def.get("eye_m", 0.5))
	var eye_p: float = p.y + (1.0 if low else 1.6)
	var n: int = clampi(int(d / float(cfg.get("senses", {}).get("los_step_m", 4.0))), 1, 24)

	for i in range(1, n):
		var t: float = float(i) / float(n)
		var h: float = float(ground_height.call(lerpf(a["pos"].x, p.x, t), lerpf(a["pos"].z, p.z, t)))

		if not is_nan(h) and h > lerpf(eye_a, eye_p, t) + 0.15:
			return false

	return true


# One leg of a zigzag away from the threat: the away direction turned by up to zig_deg either way.
func _zig(away: Vector2, def: Dictionary) -> Vector3:
	var turn: float = deg_to_rad(float(def.get("zig_deg", 0.0))) * rng.randf_range(-1.0, 1.0)   # luck-exempt: which way a fleeing animal jinks
	var dir: Vector2 = away.rotated(turn)
	return Vector3(dir.x, 0.0, dir.y)


func _herd_centre(hid: int) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0

	for mate_id in _herds.get(hid, []):
		if animals.has(mate_id):
			sum += animals[mate_id]["pos"]
			n += 1

	return sum / float(n) if n > 0 else Vector3.INF
