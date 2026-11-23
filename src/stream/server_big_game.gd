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
const WALL_LOOK_S := 0.2        # each charging step keeps this far (at its speed) plus its own nose clear of a wall: the client draws a charge
                                # carried on past its newest point by up to two legs (MotionBuffer.at, AHEAD_CARRY_S), so a charge run up to a wall
                                # was drawn into it for a moment (coordinator's walls audit, 23 Nov 2026). A near leg is 0.1 s, or 4 server frames
                                # when slower (ServerAnimals STAGGER: 0.13 s at 30 fps): two of them are covered with the nose and the 0.3 m wall
                                # margin. shortcut: a 20 fps server (0.2 s legs) or a far-band charge (3 Hz) can still be drawn a little way in.
const WALL_TRIES := 3           # charges again after one a wall kept from its foe, before it calms

var host                        # ServerAnimals
var player_info: Callable       # () -> Array of {peer, pos, ...} (the same list the wolves read)
var hurt_player: Callable       # (peer, amount, lethal, cause, from: the attacker's position, for a raised shield) -> "hurt" / "maimed" / "dead"
var notice: Callable            # (peer, text)
var struck: Callable            # (animal, peer, hurt result) after a charge lands (bandit camps stage 4b; it changes nothing about the blow)
var weapon_of: Callable         # (animal) -> the items.json id of the weapon it strikes with, "" for its own body (a camp bandit's, by his level)
var hurt_armed: Callable        # (peer, amount, lethal, cause, from, weapon id) -> as hurt_player, with the blow's damage mode and pen taken from that weapon
var ping_ms: Callable           # (peer) -> the link's round trip in ms (ENet), for a fair dodge; unset: 0


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
	var runner: Dictionary = _nearest(at)   # the player it chases is its foe (_foe), not one it warned at before

	if not runner.is_empty() and Vector2(runner["pos"].x - at.x, runner["pos"].z - at.z).length() < 3.0:
		a["foe_peer"] = int(runner.get("peer", 0))
	else:
		a.erase("foe_peer")

	a["state"] = CHARGE
	a["heading"] = atan2(at.z - a["pos"].z, at.x - a["pos"].x)
	a["dir"] = a["heading"]
	a["ran"] = 0.0
	a["charged_s"] = 0.0
	a["hit"] = false
	a.erase("late")
	a.erase("walled_start")   # a hunter's chase is not tried again at a wall
	a.erase("round_to")
	a["bluff"] = false
	a["run_m"] = run_m
	return true


func _start_warn(a: Dictionary, at: Vector3, warn_s: float, forced: bool) -> void:
	var def: Dictionary = host.species_def(a["sp"]).get("defend", {})
	a.erase("run_m")   # a warned charge runs the species' own charge_m
	a.erase("walled")   # set again by the charge this warning ends in (a bluff never sets it)
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
			a["charged_s"] = 0.0
			a["hit"] = false
			a.erase("late")
			a["bluff"] = _bluffs(a, def)
			# Its foe behind a wall: on a second try it charges for a way round the wall's end (a point near the foe it can see them from,
			# in its own sight now) instead of into the wall again, then squares up and charges home from there (_way_round).
			a["walled_start"] = not near.is_empty() and not near.has("dog") and host.wall_between(a["pos"], near["pos"])
			a.erase("round_to")

			if bool(a["walled_start"]) and int(a.get("wall_tries", 0)) > 0 and not bool(a["bluff"]):
				var round_to: Vector3 = _way_round(a, near["pos"])

				if round_to != Vector3.INF:
					a["round_to"] = round_to
					a["dir"] = atan2(round_to.z - a["pos"].z, round_to.x - a["pos"].x)
					a["heading"] = float(a["dir"])

		return

	if state == CHARGE:
		if a.has("late"):
			_judge_late(a, def, dt)
			return

		var speed: float = float(def.get("charge_mps", 11.0))
		# strike_min_s (a defend row's): a blow lands only once the charge has run this long, so every client draws the strike before it
		# lands (robots over a 60 ms 2% loss link, 23 Nov 2026: a bandit who warned from 1.4 m struck on the charge's first step, still drawn
		# warning). 0 (rows without it): as before.
		a["charged_s"] = float(a.get("charged_s", 0.0)) + dt
		var may_land: bool = float(a["charged_s"]) >= float(def.get("strike_min_s", 0.0)) - 0.0001
		var step_m: float = speed * dt

		if a.has("round_to") and not near.is_empty() and not host.wall_between(a["pos"], near["pos"]):
			# Round the wall's end with its foe in sight: it squares up to them (a short warning) and charges home from here, pressing it
			# home (no bluff). A try too, so a foe who steps back behind the wall each time does not keep it at this forever: with none
			# left it charges on at them as it runs.
			a.erase("round_to")

			if int(a.get("wall_tries", 0)) < WALL_TRIES:
				a["wall_tries"] = int(a.get("wall_tries", 0)) + 1
				_start_warn(a, near["pos"], float(def.get("provoked_warn_s", 0.8)), true)
				return

		if not near.is_empty():
			var to2: Vector3 = a["round_to"] if a.has("round_to") else near["pos"]
			var want: float = atan2(to2.z - a["pos"].z, to2.x - a["pos"].x)
			var turn: float = clampf(angle_difference(float(a["dir"]), want), -float(def.get("turn_rad_s", 0.25)) * dt, float(def.get("turn_rad_s", 0.25)) * dt)
			a["dir"] = float(a["dir"]) + turn

		# Already at the player before the blow may land: it holds the strike where it stands (drawn as the charge) rather than running
		# through them; the blow lands from here once strike_min_s has passed.
		if not may_land and not near.is_empty() and not near.has("dog") and Vector2(near["pos"].x - a["pos"].x, near["pos"].z - a["pos"].z).length() <= AnimalContact.contact_m(str(a["sp"])) + 0.3:
			a["heading"] = float(a["dir"])
			return

		var goal: Vector3 = a["pos"] + Vector3(cos(float(a["dir"])), 0.0, sin(float(a["dir"]))) * step_m * 2.0
		var species: Dictionary = host.species_def(str(a["sp"]))
		var ground_for: Callable = host.ground_height
		var blocked_for: Callable = host.blocked

		if host.swims(species):      # a swimmer (the alligator) charges through water and out onto the bank
			ground_for = func(x: float, z: float) -> float: return host.swim_height(species, x, z)
			blocked_for = Callable()

		var r: Dictionary = host.walk_step(a["pos"], goal, speed, dt, ground_for, blocked_for, 0.05, float(a["dir"]), _charge_cross(a, near, speed))
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
		if may_land and not bool(a["hit"]) and near.has("dog") and host.animals.has(int(near["dog"])):
			var dog_at: Vector3 = host.animals[int(near["dog"])]["pos"]

			if _off_path(dog_at, start, a["pos"]) <= float(def.get("hit_m", 2.2)) and not host.wall_between(a["pos"], dog_at):
				a["hit"] = true
				host.damage(int(near["dog"]), float(def.get("damage", 25.0)) * host.level_x(a, "damage"), -1, "charge")

		if may_land and not bool(a["hit"]):
			for info in (player_info.call() if player_info.is_valid() else []):
				var p: Vector3 = info["pos"]

				# Never through a wall: one stopped against a wall's near side is within hit_m of a player hard behind it (Dave: never hitting through walls).
				if _off_path(p, start, a["pos"]) <= float(def.get("hit_m", 2.2)) and absf(p.y - a["pos"].y) < 2.5 and not host.blow_blocked(a["pos"], p) and hurt_player.is_valid():
					a["hit"] = true
					a["pos"] = AnimalContact.stop_at(p, start, a["pos"], AnimalContact.contact_m(str(a["sp"])))   # it stops against the player, not through them (Dave 23 Nov 2026)
					# A hunter's chase of a runner is not judged late: running from a predator is what gets you caught (ANIMAL_BEHAVIOUR.md HB-2,
					# bear_threat_design.md), and a sprinter would be 3 to 4 m clear by then (gate review of #1824). Only chase() sets run_m.
					var wait_s: float = 0.0 if a.has("run_m") else late_s(def, int(info["peer"]))

					if wait_s > 0.0:
						# A fair dodge over the link: judged once the player has seen the blow land and their step has come back (see late_s).
						a["late"] = {"peer": int(info["peer"]), "left_s": wait_s, "from": start, "to": a["pos"] + Vector3(cos(float(a["dir"])), 0.0, sin(float(a["dir"]))) * float(def.get("hit_m", 2.2))}
						return

					_land(a, def, int(info["peer"]))
					break

		if bool(a["hit"]) or float(a["ran"]) >= float(a.get("run_m", def.get("charge_m", 24.0))) or not r["moved"]:
			a["state"] = RECOVER
			a["timer"] = float(def.get("recover_s", 5.0))
			a.erase("run_m")
			a["walled"] = not bool(a["hit"]) and (bool(a.get("walled_start", false)) or int(a.get("wall_tries", 0)) > 0)   # it missed a foe behind a wall, or after coming round one
			a.erase("round_to")

		return

	# RECOVER: it stands blowing, whatever happened; afterwards it is calm and will not warn again for a while. One that set off at a foe
	# behind a wall and missed is still angry: it warns again (short) and charges again, for a way round the wall when it sees one, up to
	# WALL_TRIES times while the foe stays within calm_m, so one short wall piece is no shield and getting round it is followed by a real
	# attack (coordinator, 23 Nov 2026); then it calms as after any charge.
	a["timer"] -= dt

	if a["timer"] <= 0.0:
		var foe: Dictionary = _foe(a) if bool(a.get("walled", false)) else {}
		a.erase("walled")

		var calm_m: float = float(def.get("calm_m", 32.0))

		if not foe.is_empty() and not foe.has("dog") and int(a.get("wall_tries", 0)) < WALL_TRIES and Vector2(foe["pos"].x - a["pos"].x, foe["pos"].z - a["pos"].z).length() <= calm_m:
			a["wall_tries"] = int(a.get("wall_tries", 0)) + 1
			_start_warn(a, foe["pos"], float(def.get("provoked_warn_s", 0.8)), bool(a.get("no_bluff", false)))
			return

		_calm(a, def)


# A way round a wall to `foe`: the nearest point on a ring round them (contact plus 1 m, then 2 m further) from which the foe is in sight
# (no wall between) and which is in its own sight now, not inside a wall's margin. Vector3.INF when there is none (a long wall: it slides).
# Cost: at most 32 wall checks, once a charge that sets off at a walled foe.
func _way_round(a: Dictionary, foe: Vector3) -> Vector3:
	var pos: Vector3 = a["pos"]
	var ring: float = AnimalContact.contact_m(str(a["sp"])) + 1.0

	for r in [ring, ring + 2.0]:
		var best: Vector3 = Vector3.INF
		var best_d: float = INF

		for k in 16:
			var turn: float = TAU * float(k) / 16.0
			var c: Vector3 = Vector3(foe.x + cos(turn) * float(r), pos.y, foe.z + sin(turn) * float(r))
			var d: float = Vector2(c.x - pos.x, c.z - pos.z).length()

			if d >= best_d or host.crosses_wall(c.x, c.z, c.x, c.z) or host.wall_between(c, foe) or host.wall_between(pos, c):
				continue

			best = c
			best_d = d

		if best != Vector3.INF:
			return best

	return Vector3.INF


# Steering's `cross` for one charging step: the step, carried on its nose and WALL_LOOK_S of running, keeps clear of every wall, so the
# charge turns along a wall it meets early (the slide it always made, now begun before the wall) and the client's carried-on drawing of
# its newest leg runs along the wall, never into it. It still runs on round the wall's end and charges home (coordinator, 23 Nov 2026: one
# short wall piece is no shield). Its foe standing nearer in front of it, no wall between (a player with their back to a wall): the plain
# check, so it is charged home and hit.
func _charge_cross(a: Dictionary, near: Dictionary, speed: float) -> Callable:
	var look: float = AnimalContact.body_m(str(a["sp"])) + speed * WALL_LOOK_S
	var pos: Vector3 = a["pos"]

	if not near.is_empty():
		var foe: Vector3 = near["pos"]

		if Vector2(foe.x - pos.x, foe.z - pos.z).length() <= look and not host.wall_between(pos, foe):
			return host.crossing

	return func(x0: float, z0: float, x1: float, z1: float) -> bool:
		var on: Vector2 = Vector2(x1 - x0, z1 - z0)

		if on.length_squared() < 0.000001:
			return host.crosses_wall(x0, z0, x1, z1)

		on = on.normalized() * look
		return host.crosses_wall(x0, z0, x1 + on.x, z1 + on.y)


# How long after the server's blow it is judged, in seconds (defend row fair_dodge; robots over a 120 ms link, 23 Nov 2026: 0 of 9 side-steps
# got clear). A player sees the server's animals about dodge_view_ms behind (the row clock's draw delay plus the trip down) and their step
# takes the trip back up, so the blow is judged a round trip plus that delay later, against where the player then is: where they had stepped
# by the moment their screen showed the blow land. At most dodge_late_max_ms (a slow or lying link cannot stretch it), 0 without the row key.
func late_s(def: Dictionary, peer: int) -> float:
	if peer < 0 or not bool(def.get("fair_dodge", false)) or not ping_ms.is_valid():
		return 0.0

	var ms: float = float(host.cfg.get("dodge_view_ms", 350)) + maxf(float(ping_ms.call(peer)), 0.0)
	return clampf(ms, 0.0, float(host.cfg.get("dodge_late_max_ms", 600))) / 1000.0


# A blow held for a fair dodge: it stands at the player, drawn still charging, and when the time is up the blow lands only if the player is
# still on its line (within hit_m of the stretch it charged, carried hit_m on past where it stopped, so backing straight off is no dodge),
# level with it and not behind a wall. Either way it then recovers.
func _judge_late(a: Dictionary, def: Dictionary, dt: float) -> void:
	var late: Dictionary = a["late"]
	late["left_s"] = float(late["left_s"]) - dt

	if float(late["left_s"]) > 0.0:
		return

	a.erase("late")

	for info in (player_info.call() if player_info.is_valid() else []):
		var p: Vector3 = info["pos"]

		if int(info["peer"]) == int(late["peer"]) and _off_path(p, late["from"], late["to"]) <= float(def.get("hit_m", 2.2)) and absf(p.y - a["pos"].y) < 2.5 and not host.blow_blocked(a["pos"], p):
			_land(a, def, int(info["peer"]))
			break

	a["state"] = RECOVER
	a["timer"] = float(def.get("recover_s", 5.0))
	a.erase("run_m")


# The blow lands on `peer`: its damage (by level), the weapon's type of blow for an armed bandit, and the struck hook.
func _land(a: Dictionary, def: Dictionary, peer: int) -> void:
	var amount: float = float(def.get("damage", 25.0)) * host.level_x(a, "damage")   # a higher-level animal hits harder
	var weapon: String = str(weapon_of.call(a)) if weapon_of.is_valid() else ""
	# A bandit's blow cuts, pierces or batters as the weapon in his hand does (coordinator, 23 Nov 2026: every bandit blow counted blunt).
	var landed: String

	if weapon != "" and hurt_armed.is_valid():
		landed = str(hurt_armed.call(peer, amount, false, str(a["sp"]), a["pos"], weapon))
	else:
		landed = str(hurt_player.call(peer, amount, false, str(a["sp"]), a["pos"]))

	if struck.is_valid():
		struck.call(a, peer, landed)


# How far a point is, on the ground, from the stretch a charge covered this step (a0 to a1). A step can be longer than hit_m when the
# server runs slowly, so the end point alone could pass a player by.
static func _off_path(p: Vector3, a0: Vector3, a1: Vector3) -> float:
	var seg: Vector2 = Vector2(a1.x - a0.x, a1.z - a0.z)
	var rel: Vector2 = Vector2(p.x - a0.x, p.z - a0.z)
	var f: float = clampf(rel.dot(seg) / seg.length_squared(), 0.0, 1.0) if seg.length_squared() > 0.000001 else 0.0
	return (rel - seg * f).length()


func _calm(a: Dictionary, def: Dictionary) -> void:
	a.erase("walled")
	a.erase("walled_start")
	a.erase("round_to")
	a.erase("wall_tries")
	a.erase("late")
	a.erase("foe_dog")
	a.erase("foe_peer")
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
