extends RefCounted

# Big game that defends itself (Radar, 2026-10-21, Dave's animal rules, items/ANIMAL_ROSTER_CARD.md): the moose now, boar and bear
# later use the same module. They avoid the player like every wild animal; only a protective one (defending a calf), a cornered
# one or a wounded one stands and fights. EVERY attack is dodgeable: first a WARN (head down, stamping) of warn_s seconds, then a
# CHARGE in a locked direction that turns only turn_rad_s radians a second, ending in RECOVER (panting) whatever happens.
# A player who steps aside, or walks away during the warning, is not hurt. Numbers: the species' "defend" block in animals.json.

const Steering := preload("res://src/shared/steering.gd")

const WARN := 10
const CHARGE := 11
const RECOVER := 12

var host                        # ServerAnimals
var player_info: Callable       # () -> Array of {peer, pos, ...} (the same list the wolves read)
var hurt_player: Callable       # (peer, amount, lethal, cause) -> "hurt" / "maimed" / "dead"
var notice: Callable            # (peer, text)


func handles(a: Dictionary) -> bool:
	return int(a["state"]) >= WARN and int(a["state"]) <= RECOVER


func defends(a: Dictionary) -> bool:
	return host.species_def(a["sp"]).has("defend")


# The nearest player to an animal: {} for none.
func _nearest(pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	var infos: Array = player_info.call() if player_info.is_valid() else []

	for info in infos:
		var d: float = Vector2(info["pos"].x - pos.x, info["pos"].z - pos.z).length()

		if d < best_d:
			best_d = d
			best = info

	return best


# What this animal is warning at or charging: the dog it stood to (foe_dog, while that dog lives), else the nearest player.
func _foe(a: Dictionary) -> Dictionary:
	if a.has("foe_dog") and host.animals.has(int(a["foe_dog"])):
		return {"pos": host.animals[int(a["foe_dog"])]["pos"], "dog": int(a["foe_dog"])}

	return _nearest(a["pos"])


# Start a warning at a player (or a short one when provoked). Returns true when the animal took it. Its temperament decides
# whether it attacks at all (host.may_attack: never the young, passive or friendly ones unless forced, as a mother for her young).
func warn(a: Dictionary, at: Vector3, warn_s: float = -1.0, forced: bool = false) -> bool:
	var def: Dictionary = host.species_def(a["sp"]).get("defend", {})

	if def.is_empty() or float(a.get("cool", 0.0)) > 0.0 or handles(a) or not host.may_attack(a, forced):
		return false

	a["state"] = WARN
	a["timer"] = warn_s if warn_s > 0.0 else float(def.get("warn_s", 2.2))
	a["heading"] = atan2(at.z - a["pos"].z, at.x - a["pos"].x)
	a["target"] = a["pos"]
	return true


# One step of WARN, CHARGE or RECOVER (called from ServerAnimals._step instead of the ordinary behaviour).
func step(a: Dictionary, dt: float) -> void:
	var def: Dictionary = host.species_def(a["sp"]).get("defend", {})
	var near: Dictionary = _foe(a)
	var state: int = int(a["state"])

	if state == WARN:
		a["timer"] -= dt

		if near.is_empty():
			_calm(a, def)
			return

		var to: Vector3 = near["pos"]
		var d: float = Vector2(to.x - a["pos"].x, to.z - a["pos"].z).length()
		a["heading"] = atan2(to.z - a["pos"].z, to.x - a["pos"].x)   # it watches the player while it warns

		if d > float(def.get("calm_m", 32.0)):
			_calm(a, def)   # the player backed off during the warning: no charge
			return

		# A dog: it keeps warning until the dog comes within the species' dog.attack_m (dog_companion_design.md 11).
		if near.has("dog") and a["timer"] <= 0.0 and d > float(host.species_def(a["sp"]).get("dog", {}).get("attack_m", 10.0)):
			a["timer"] = 0.5
			return

		if a["timer"] <= 0.0:
			a["state"] = CHARGE
			a["dir"] = a["heading"]   # locked now: the player can still step aside
			a["ran"] = 0.0
			a["hit"] = false

		return

	if state == CHARGE:
		var speed: float = float(def.get("charge_mps", 11.0))
		var step_m: float = speed * dt

		if not near.is_empty():
			var to2: Vector3 = near["pos"]
			var want: float = atan2(to2.z - a["pos"].z, to2.x - a["pos"].x)
			var turn: float = clampf(angle_difference(float(a["dir"]), want), -float(def.get("turn_rad_s", 0.25)) * dt, float(def.get("turn_rad_s", 0.25)) * dt)
			a["dir"] = float(a["dir"]) + turn

		var goal: Vector3 = a["pos"] + Vector3(cos(float(a["dir"])), 0.0, sin(float(a["dir"]))) * step_m * 2.0
		var r: Dictionary = Steering.step(a["pos"], goal, speed, dt, host.ground_height, host.blocked, 0.05, float(a["dir"]), host.crossing)
		a["heading"] = float(a["dir"])

		if r["moved"]:
			a["ran"] = float(a["ran"]) + a["pos"].distance_to(r["pos"])
			a["pos"] = r["pos"]

		# A charge at a dog: the dog is hit when it is within hit_m (a player in the way is still hit below).
		if not bool(a["hit"]) and near.has("dog") and host.animals.has(int(near["dog"])):
			var dog_at: Vector3 = host.animals[int(near["dog"])]["pos"]

			if Vector2(dog_at.x - a["pos"].x, dog_at.z - a["pos"].z).length() <= float(def.get("hit_m", 2.2)):
				a["hit"] = true
				host.damage(int(near["dog"]), float(def.get("damage", 25.0)) * host.level_x(a, "damage"), -1, "charge")

		if not bool(a["hit"]):
			for info in (player_info.call() if player_info.is_valid() else []):
				var p: Vector3 = info["pos"]

				if Vector2(p.x - a["pos"].x, p.z - a["pos"].z).length() <= float(def.get("hit_m", 2.2)) and absf(p.y - a["pos"].y) < 2.5 and hurt_player.is_valid():
					a["hit"] = true
					hurt_player.call(int(info["peer"]), float(def.get("damage", 25.0)) * host.level_x(a, "damage"), false, str(a["sp"]))   # a higher-level animal hits harder
					break

		if bool(a["hit"]) or float(a["ran"]) >= float(def.get("charge_m", 24.0)) or not r["moved"]:
			a["state"] = RECOVER
			a["timer"] = float(def.get("recover_s", 5.0))

		return

	# RECOVER: it stands blowing, whatever happened; afterwards it is calm and will not warn again for a while.
	a["timer"] -= dt

	if a["timer"] <= 0.0:
		_calm(a, def)


func _calm(a: Dictionary, def: Dictionary) -> void:
	a.erase("foe_dog")
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(host.species_def(a["sp"]))
	a["alert"] = 0.0
	a["cool"] = float(def.get("cool_s", 30.0))
	a["home"] = a["pos"]


# Called every animal tick for the cool-down after a charge.
func cool_down(a: Dictionary, dt: float) -> void:
	if float(a.get("cool", 0.0)) > 0.0:
		a["cool"] = float(a["cool"]) - dt
