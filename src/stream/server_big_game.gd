extends RefCounted

# Big game that defends itself (Radar, 2026-10-21, Dave's animal rules, items/ANIMAL_ROSTER_CARD.md): the moose now, boar and bear
# later use the same module. They avoid the player like every wild animal; only a protective one (defending a calf), a cornered
# one or a wounded one stands and fights. EVERY attack is dodgeable: first a WARN (head down, stamping) of warn_s seconds, then a
# CHARGE in a locked direction that turns only turn_rad_s radians a second, ending in RECOVER (panting) whatever happens.
# A player who steps aside, or walks away during the warning, is not hurt. Numbers: the species' "defend" block in animals.json.
#
# The threat ladder (docs/design/bear_threat_design.md, Dave 8 Nov 2026), for rows that set its keys (the bears): the warning has two rungs,
# a huff (WARN, the first huff_share of it) and a jaw-pop (WARN_POP, the rest), so a player can read it and back away. A charge may be a
# bluff (bluff_share, scaled by the temperament's bluff_x and by den_bluff_x at the den) that stops bluff_stop_m short with no hit. A player
# who runs away during the warning (faster than run_trigger_mps away from it) skips the rest of it, and that charge is never a bluff; nor is a mother's for
# her young. A row without these keys behaves as before: one warning, every charge real.

const Steering := preload("res://src/shared/steering.gd")

const WARN := 10
const CHARGE := 11
const RECOVER := 12
const WARN_POP := 16            # the second rung of the warning: the jaw-pop and ground swat (13 to 15 are the thief's and the flock's)

var host                        # ServerAnimals
var player_info: Callable       # () -> Array of {peer, pos, ...} (the same list the wolves read)
var hurt_player: Callable       # (peer, amount, lethal, cause) -> "hurt" / "maimed" / "dead"
var notice: Callable            # (peer, text)


func handles(a: Dictionary) -> bool:
	return (int(a["state"]) >= WARN and int(a["state"]) <= RECOVER) or int(a["state"]) == WARN_POP


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


# Start a warning at a player (or a short one when provoked). Returns true when the animal took it. Its temperament decides
# whether it attacks at all (host.may_attack: never the young, passive or friendly ones unless forced, as a mother for her young).
func warn(a: Dictionary, at: Vector3, warn_s: float = -1.0, forced: bool = false) -> bool:
	var def: Dictionary = host.species_def(a["sp"]).get("defend", {})

	if def.is_empty() or float(a.get("cool", 0.0)) > 0.0 or handles(a) or not host.may_attack(a, forced):
		return false

	a["state"] = WARN
	a["timer"] = warn_s if warn_s > 0.0 else float(def.get("warn_s", 2.2))
	a["huff_s"] = float(a["timer"]) * (1.0 - float(def.get("huff_share", 1.0)))   # the jaw-pop starts when this much warning is left
	a["heading"] = atan2(at.z - a["pos"].z, at.x - a["pos"].x)
	a["target"] = a["pos"]
	a["no_bluff"] = forced   # a mother for her young presses home
	return true


# Whether the charge about to start is a bluff: bluff_share, scaled by the temperament (bluff_x) and at the den (den_bluff_x); never after
# a run during the warning or for a mother's young.
func _bluffs(a: Dictionary, def: Dictionary) -> bool:
	if bool(a.get("no_bluff", false)):
		return false

	var share: float = float(def.get("bluff_share", 0.0)) * float(host._temper_row(a).get("bluff_x", 1.0))
	var row: Dictionary = host.species_def(a["sp"])

	if row.has("den") and host._in_den(a, row):
		share *= float(def.get("den_bluff_x", 1.0))

	return share > 0.0 and host.rng.randf() < share   # luck-exempt: whether a warned-off bear bluffs or presses home


# One step of WARN, CHARGE or RECOVER (called from ServerAnimals._step instead of the ordinary behaviour).
func step(a: Dictionary, dt: float) -> void:
	var def: Dictionary = host.species_def(a["sp"]).get("defend", {})
	var near: Dictionary = _nearest(a["pos"])
	var state: int = int(a["state"])

	if state == WARN or state == WARN_POP:
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

		# Running away makes it worse (a fleeing animal is chased): the rest of the warning is skipped and the charge is real. Backing off slowly,
		# or running in and stopping, gets the whole warning.
		var away: Vector2 = Vector2(to.x - a["pos"].x, to.z - a["pos"].z).normalized()

		if def.has("run_trigger_mps") and host.player_velocity_at(to).dot(away) > float(def["run_trigger_mps"]):
			a["timer"] = 0.0
			a["no_bluff"] = true

		if state == WARN and a["timer"] > 0.0 and a["timer"] <= float(a.get("huff_s", 0.0)):
			a["state"] = WARN_POP   # the huff is over: the jaw-pop and swat, the last warning

		if a["timer"] <= 0.0:
			a["state"] = CHARGE
			a["dir"] = a["heading"]   # locked now: the player can still step aside
			a["ran"] = 0.0
			a["hit"] = false
			a["bluff"] = _bluffs(a, def)

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

		# A bluff stops short of the nearest player (or at the end of its run) and never hits.
		if bool(a.get("bluff", false)):
			var short: bool = not near.is_empty() and Vector2(near["pos"].x - a["pos"].x, near["pos"].z - a["pos"].z).length() <= float(def.get("bluff_stop_m", 4.0))

			if short or float(a["ran"]) >= float(def.get("charge_m", 24.0)) or not r["moved"]:
				a["state"] = RECOVER
				a["timer"] = float(def.get("recover_s", 5.0))

			return

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
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(host.species_def(a["sp"]))
	a["alert"] = 0.0
	a["cool"] = float(def.get("cool_s", 30.0))
	a["home"] = a["pos"]


# Called every animal tick for the cool-down after a charge.
func cool_down(a: Dictionary, dt: float) -> void:
	if float(a.get("cool", 0.0)) > 0.0:
		a["cool"] = float(a["cool"]) - dt
