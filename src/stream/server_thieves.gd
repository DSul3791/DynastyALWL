extends RefCounted

# Opportunists (Radar, 2026-10-21, Dave: "creatures of opportunity"): the fox. A fox that can SMELL uncovered food lying on the ground
# (distance shortened downwind by the same wind as the animal senses) creeps up and takes it, then runs off with it and eats it far
# away. Food in a chest or the pack is safe. A player near the food or near the fox, a fire at the food, or a fox that is hurt or
# frightened, stops it: it never goes near people for a meal unless nobody is around. Numbers: the species' "thief" block in animals.json.

const Steering := preload("res://src/shared/steering.gd")

const SNEAK := 13
const CARRY := 14

var host                        # ServerAnimals
var loose_food: Callable        # (centre Vector3, radius) -> Array of [id, position Vector3]
var take_food: Callable         # (id) -> Array [item number, count] taken, or [] when it is gone
var player_positions: Callable  # () -> Array of Vector3 (host's list is used when unset)
var fires: Callable             # () -> Array of Vector3, burning fires


func handles(a: Dictionary) -> bool:
	return int(a["state"]) == SNEAK or int(a["state"]) == CARRY


func _players() -> Array:
	return host.player_positions.call() if host.player_positions.is_valid() else []


func _frightened(pos: Vector3, r: float) -> bool:
	for p in _players():
		if Vector2(p.x - pos.x, p.z - pos.z).length() < r:
			return true

	return false


func _fire_near(pos: Vector3, r: float) -> bool:
	for f in (fires.call() if fires.is_valid() else []):
		if Vector2(f.x - pos.x, f.z - pos.z).length() < r:
			return true

	return false


# A calm fox looks for a meal about every look_s seconds: true when it set off after one.
func try_sneak(a: Dictionary, dt: float) -> bool:
	var def: Dictionary = host.species_def(a["sp"]).get("thief", {})

	if def.is_empty() or not loose_food.is_valid():
		return false

	a["look"] = float(a.get("look", 0.0)) - dt

	if float(a["look"]) > 0.0:
		return false

	a["look"] = float(def.get("look_s", 2.0))
	var smell: float = float(def.get("smell_m", 30.0))
	var best: Array = []
	var best_eff: float = INF

	for row in loose_food.call(a["pos"], smell * 1.6):
		var food: Vector3 = row[1]
		var d: float = Vector2(food.x - a["pos"].x, food.z - a["pos"].z).length()
		var f: float = 1.0

		if host._wind_s > 0.0 and d > 0.01:
			var scent_way: Vector2 = Vector2(a["pos"].x - food.x, a["pos"].z - food.z).normalized()   # the scent drifts from the food to the fox
			f = maxf(1.0 + float(host.cfg.get("senses", {}).get("scent_gain", 0.5)) * host._wind_s * scent_way.dot(host._wind_dir), 0.5)

		if d / f <= smell and d / f < best_eff and not _frightened(food, float(def.get("scare_m", 18.0))) and not _fire_near(food, float(def.get("fire_m", 10.0))):
			best_eff = d / f
			best = row

	if best.is_empty():
		return false

	a["food"] = int(best[0])
	a["state"] = SNEAK
	return true


func step(a: Dictionary, dt: float) -> void:
	var def: Dictionary = host.species_def(a["sp"]).get("thief", {})

	if int(a["state"]) == SNEAK:
		var goal: Variant = _food_pos(int(a.get("food", -1)), a["pos"])

		# Gone, or a person came near the food or the fox, or a fire was lit: it gives up and slips away.
		if goal == null or _frightened(a["pos"], float(def.get("scare_m", 18.0))) or _frightened(goal, float(def.get("scare_m", 18.0))) or _fire_near(goal, float(def.get("fire_m", 10.0))):
			_give_up(a)
			return

		var r: Dictionary = Steering.step(a["pos"], goal, float(def.get("sneak_mps", 2.5)), dt, host.ground_height, host.blocked, 0.8, a["heading"])

		if r["moved"]:
			a["pos"] = r["pos"]
			a["heading"] = r["heading"]

		if r["arrived"]:
			var taken: Array = take_food.call(int(a["food"])) if take_food.is_valid() else []

			if taken.is_empty():
				_give_up(a)
				return

			a["loot"] = taken
			a["state"] = CARRY
			var away: Vector2 = Vector2.from_angle(a["heading"] + PI)
			a["target"] = a["pos"] + Vector3(away.x, 0.0, away.y) * float(def.get("run_m", 70.0))
			a["ran"] = 0.0
		elif not r["moved"]:
			_give_up(a)

		return

	# CARRY: sprint away with the food and eat it far off.
	var r2: Dictionary = Steering.step(a["pos"], a["target"], float(def.get("run_mps", 9.0)), dt, host.ground_height, host.blocked, 1.0, a["heading"])

	if r2["moved"]:
		a["ran"] = float(a["ran"]) + a["pos"].distance_to(r2["pos"])
		a["pos"] = r2["pos"]
		a["heading"] = r2["heading"]

	if r2["arrived"] or not r2["moved"] or float(a["ran"]) >= float(def.get("run_m", 70.0)):
		host.animals.erase(a["id"])   # it eats the meal somewhere out of sight; a fox elsewhere will turn up later


func _food_pos(id: int, from: Vector3) -> Variant:
	for row in (loose_food.call(from, 80.0) if loose_food.is_valid() else []):
		if int(row[0]) == id:
			return row[1]

	return null


func _give_up(a: Dictionary) -> void:
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(host.species_def(a["sp"]))
	a["look"] = float(host.species_def(a["sp"]).get("thief", {}).get("again_s", 20.0))
