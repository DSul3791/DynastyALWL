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


const AnimalContact := preload("res://src/shared/animal_contact.gd")   # how near a charge comes to a player (AnimalContact.stop_at)

const WARN := 10
const CHARGE := 11
const RECOVER := 12
const WARN_POP := 16            # the second rung of the warning: the jaw-pop and ground swat (13 to 15 are the thief's and the flock's)

var host                        # ServerAnimals
var player_info: Callable       # () -> Array of {peer, pos, ...} (the same list the wolves read)
var hurt_player: Callable       # (peer, amount, lethal, cause) -> "hurt" / "maimed" / "dead"
var notice: Callable            # (peer, text)
var struck: Callable            # (animal, peer, hurt result) after a charge lands (bandit camps stage 4b; it changes nothing about the blow)


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


# What this animal is warning at or charging: the dog it stood to (foe_dog, while that dog lives), else the player it took on (foe_peer)
# for as long as it fights and that player stays within calm_m, else the nearest player, who is then its foe (Dave 23 Nov 2026, the real
# server: with two players near it turned from one to the other every step, as the nearest changed by a step, and never pressed a charge home).
func _foe(a: Dictionary) -> Dictionary:
	if a.has("foe_dog") and host.animals.has(int(a["foe_dog"])):
		return {"pos": host.animals[int(a["foe_dog"])]["pos"], "dog": int(a["foe_dog"])}

	if a.has("foe_peer") and handles(a):
		var calm: float = float(host.species_def(a["sp"]).get("defend", {}).get("calm_m", 32.0))

		for info in (player_info.call() if player_info.is_valid() else []):
			if int(info.get("peer", 0)) == int(a["foe_peer"]) and Vector2(info["pos"].x - a["pos"].x, info["pos"].z - a["pos"].z).length() <= calm:
				return info

	var near: Dictionary = _nearest(a["pos"])

	if near.is_empty():
		a.erase("foe_peer")
	else:
		a["foe_peer"] = int(near.get("peer", 0))

	return near


# Start a warning at a player (or a short one when provoked). Returns true when the animal took it. Its temperament decides
# whether it attacks at all (host.may_attack: never the young, passive or friendly ones unless forced, as a mother for her young).
func warn(a: Dictionary, at: Vector3, warn_s: float = -1.0, forced: bool = false) -> bool:
	var def: Dictionary = host.species_def(a["sp"]).get("defend", {})

	if def.is_empty() or float(a.get("cool", 0.0)) > 0.0 or handles(a) or not host.may_attack(a, forced):
		return false

	_start_warn(a, at, warn_s if warn_s > 0.0 else float(def.get("warn_s", 2.2)), forced)
	return true


# A blow from a player within provoked_m (ServerAnimals.damage; Dave 21 Nov 2026 play test: elephants "turned to face me but just stood there
# and died"). A warning already under way ends in the charge at once (it has been warned enough); a charge carries on; one standing after a
# charge, or still cooling down from one, warns again (short). A jab lands every 0.6 s, inside the 0.8 s provoked warning, and each one used
# to turn the warning into a flight that the next step turned back into a fresh warning: it faced the player until it died. Returns true
# when the animal fights (the caller leaves it be); false when it may not attack at all (it runs).
func provoke(a: Dictionary, at: Vector3, warn_s: float) -> bool:
	if host.species_def(a["sp"]).get("defend", {}).is_empty() or not host.may_attack(a):
		return false

	var state: int = int(a["state"])

	a.erase("foe_dog")   # the one hurting it is the foe now, not a dog it stood to
	var hurter: Dictionary = _nearest(at)

	if not hurter.is_empty() and Vector2(hurter["pos"].x - at.x, hurter["pos"].z - at.z).length() < 3.0:
		a["foe_peer"] = int(hurter.get("peer", 0))

	if state == WARN or state == WARN_POP:
		a["timer"] = 0.0
		a["no_bluff"] = true   # hurt, it presses home
		a["heading"] = atan2(at.z - a["pos"].z, at.x - a["pos"].x)
		return true

	if state == CHARGE:
		return true

	_start_warn(a, at, warn_s, false)
	return true


# A hunter giving chase to a player running away from it (ServerAnimals._chases_runner; docs/design/ANIMAL_BEHAVIOUR.md HB-2): no warning
# and no bluff, a charge straight away that runs up to `run_m` (the hunter's own chase length, longer than a defending charge) before it
# gives up. The same cool-down and the same dodge as any charge. Returns true when it charges.
func chase(a: Dictionary, at: Vector3, run_m: float) -> bool:
	if host.species_def(a["sp"]).get("defend", {}).is_empty() or float(a.get("cool", 0.0)) > 0.0 or handles(a) or not host.may_attack(a):
		return false

	a.erase("foe_dog")
	a["state"] = CHARGE
	a["heading"] = atan2(at.z - a["pos"].z, at.x - a["pos"].x)
	a["dir"] = a["heading"]
	a["ran"] = 0.0
	a["hit"] = false
	a["bluff"] = false
	a["run_m"] = run_m
	return true


func _start_warn(a: Dictionary, at: Vector3, warn_s: float, forced: bool) -> void:
	var def: Dictionary = host.species_def(a["sp"]).get("defend", {})
	a.erase("run_m")   # a warned charge runs the species' own charge_m
	a["state"] = WARN
	a["timer"] = warn_s
	a["huff_s"] = float(a["timer"]) * (1.0 - float(def.get("huff_share", 1.0)))   # the jaw-pop starts when this much warning is left
	a["heading"] = atan2(at.z - a["pos"].z, at.x - a["pos"].x)
	a["target"] = a["pos"]
	a["no_bluff"] = forced   # a mother for her young presses home
	var foe: Dictionary = _nearest(at)   # the player it warns at (or who hurt it) is its foe until it is done (_foe)

	if not foe.is_empty() and Vector2(foe["pos"].x - at.x, foe["pos"].z - at.z).length() < 3.0:
		a["foe_peer"] = int(foe.get("peer", 0))
	else:
		a.erase("foe_peer")


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
	var near: Dictionary = _foe(a)
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

		# A dog: it keeps warning until the dog comes within the species' dog.attack_m (dog_companion_design.md 11).
		if near.has("dog") and a["timer"] <= 0.0 and d > float(host.species_def(a["sp"]).get("dog", {}).get("attack_m", 10.0)):
			a["timer"] = 0.5
			return

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
		var species: Dictionary = host.species_def(str(a["sp"]))
		var ground_for: Callable = host.ground_height
		var blocked_for: Callable = host.blocked

		if host.swims(species):      # a swimmer (the alligator) charges through water and out onto the bank
			ground_for = func(x: float, z: float) -> float: return host.swim_height(species, x, z)
			blocked_for = Callable()

		var r: Dictionary = host.walk_step(a["pos"], goal, speed, dt, ground_for, blocked_for, 0.05, float(a["dir"]), host.crossing)
		a["heading"] = float(a["dir"])
		var start: Vector3 = a["pos"]   # the charge hits whoever is within hit_m of the ground it covered this step, the start included (a player under it)

		if r["moved"]:
			a["ran"] = float(a["ran"]) + a["pos"].distance_to(r["pos"])
			a["pos"] = r["pos"]

		# A bluff stops short of the nearest player (or at the end of its run) and never hits.
		if bool(a.get("bluff", false)):
			var short: bool = not near.is_empty() and Vector2(near["pos"].x - a["pos"].x, near["pos"].z - a["pos"].z).length() <= float(def.get("bluff_stop_m", 4.0))

			if short or float(a["ran"]) >= float(a.get("run_m", def.get("charge_m", 24.0))) or not r["moved"]:
				a["state"] = RECOVER
				a["timer"] = float(def.get("recover_s", 5.0))
				a.erase("run_m")

			return

		# A charge at a dog: the dog is hit when it is within hit_m (a player in the way is still hit below).
		if not bool(a["hit"]) and near.has("dog") and host.animals.has(int(near["dog"])):
			var dog_at: Vector3 = host.animals[int(near["dog"])]["pos"]

			if _off_path(dog_at, start, a["pos"]) <= float(def.get("hit_m", 2.2)):
				a["hit"] = true
				host.damage(int(near["dog"]), float(def.get("damage", 25.0)) * host.level_x(a, "damage"), -1, "charge")

		if not bool(a["hit"]):
			for info in (player_info.call() if player_info.is_valid() else []):
				var p: Vector3 = info["pos"]

				if _off_path(p, start, a["pos"]) <= float(def.get("hit_m", 2.2)) and absf(p.y - a["pos"].y) < 2.5 and hurt_player.is_valid():
					a["hit"] = true
					a["pos"] = AnimalContact.stop_at(p, start, a["pos"], AnimalContact.contact_m(str(a["sp"])))   # it stops against the player, not through them (Dave 23 Nov 2026)
					var landed: String = str(hurt_player.call(int(info["peer"]), float(def.get("damage", 25.0)) * host.level_x(a, "damage"), false, str(a["sp"])))   # a higher-level animal hits harder

					if struck.is_valid():
						struck.call(a, int(info["peer"]), landed)
					break

		if bool(a["hit"]) or float(a["ran"]) >= float(a.get("run_m", def.get("charge_m", 24.0))) or not r["moved"]:
			a["state"] = RECOVER
			a["timer"] = float(def.get("recover_s", 5.0))
			a.erase("run_m")

		return

	# RECOVER: it stands blowing, whatever happened; afterwards it is calm and will not warn again for a while.
	a["timer"] -= dt

	if a["timer"] <= 0.0:
		_calm(a, def)


# How far a point is, on the ground, from the stretch a charge covered this step (a0 to a1). A step can be longer than hit_m when the
# server runs slowly, so the end point alone could pass a player by.
static func _off_path(p: Vector3, a0: Vector3, a1: Vector3) -> float:
	var seg: Vector2 = Vector2(a1.x - a0.x, a1.z - a0.z)
	var rel: Vector2 = Vector2(p.x - a0.x, p.z - a0.z)
	var f: float = clampf(rel.dot(seg) / seg.length_squared(), 0.0, 1.0) if seg.length_squared() > 0.000001 else 0.0
	return (rel - seg * f).length()


func _calm(a: Dictionary, def: Dictionary) -> void:
	a.erase("foe_dog")
	a.erase("run_m")   # a chase's run length, for that chase only
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(host.species_def(a["sp"]))
	a["alert"] = 0.0
	a["cool"] = float(def.get("cool_s", 30.0))
	a["home"] = a["pos"]


# Called every animal tick for the cool-down after a charge.
func cool_down(a: Dictionary, dt: float) -> void:
	if float(a.get("cool", 0.0)) > 0.0:
		a["cool"] = float(a["cool"]) - dt
