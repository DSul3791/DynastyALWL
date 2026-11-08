extends RefCounted

# Goblin den life (docs/design/goblin_den_life_design.md, Dave's docs/GOBLINS.md behaviour, 7 Nov 2026): by day a band sleeps in its den deep in
# the cave, walking the cave's floor path (tile goblin_den_paths) between the mouth and the den; at night it comes out and, besides the ordinary
# skittish ranging round the mouth, creeps to the edge of a fire's light to watch, or forages at a berry bush. Species opt in with a "den_life"
# block in animals.json. Everything here keys on that block or on a cave path, so other species do not change.
#
# In the cave a goblin moves only along its path (no surface steering: the ground height there is the hill above). It reacts only to players on
# its own level (den_life.cave_level_m vertically from the path), drives deeper from one who comes inside spook_m, and gives a player inside its
# threat range a short warning and then a lunge along the path: backing off during the warning avoids it, the big-game contract.
#
# Stealing (docs/design/goblin_stealing_design.md, Dave 8 Nov 2026): at night a goblin may creep (SNEAK) to one small loose thing outside every
# fire's light, take one piece, run home with it (CARRY) and lay it on the den pile, where a player can find it and take it back.
#
# Friendship, step 1 (docs/design/goblin_friendship_step1_design.md, Dave 8 Nov 2026): a thing a player dropped that the band takes is a gift
# (once a night). A Tolerated player is watched, not fled from, until within watch_spook_m; a Known player's things are no longer stolen
# (their food still is: a gift), and a goblin that watched at a fire beside them leaves a return gift; a player who hurts one makes the band
# wary of them, and it runs from them at twice spook_m.

const SNEAK := 13              # the thief's states (server_thieves.gd): the client's creep and carry poses
const CARRY := 14

const Steering := preload("res://src/shared/steering.gd")
const TrustScript := preload("res://src/stream/server_goblin_trust.gd")

var host                       # ServerAnimals
var stealable: Callable        # (centre Vector3, radius) -> Array of [world id, position]: loose small things on the ground (server_items.stealable_near)
var take_one: Callable         # (world id) -> [item number, 1], or [] when it is gone (server_items.take_one)
var hoard_drop: Callable       # (item number, count, position, lifetime s) -> bool: lays a piece on a den pile (server_items.drop_in_world)
var peer_key: Callable         # (peer) -> the player's character key (server_items.key_of); friendship is per character
var item_number: Callable      # (item id) -> item number (the item table), for return gifts
var gift_drop: Callable        # (item number, count, position, by) -> bool: lays a return gift, marked as the band's (server_items.drop_in_world)
var trust = TrustScript.new()  # friendship (docs/design/goblin_friendship_step1_design.md): per band and character


# Length (m) of a cave path, mouth to den.
static func path_length(path: PackedVector3Array) -> float:
	var total: float = 0.0

	for k in range(1, path.size()):
		total += path[k - 1].distance_to(path[k])

	return total


# The point `s` metres along a path from the mouth (clamped to its ends).
static func point_at(path: PackedVector3Array, s: float) -> Vector3:
	if path.is_empty():
		return Vector3.INF

	var left: float = maxf(s, 0.0)

	for k in range(1, path.size()):
		var leg: float = path[k - 1].distance_to(path[k])

		if left <= leg:
			return path[k - 1].lerp(path[k], left / leg) if leg > 0.0 else path[k]

		left -= leg

	return path[path.size() - 1]


# The nearest point of a path to `p`: [metres along the path, the point].
static func project(path: PackedVector3Array, p: Vector3) -> Array:
	var best_s: float = 0.0
	var best_q: Vector3 = path[0] if not path.is_empty() else Vector3.INF
	var best_d: float = INF
	var walked: float = 0.0

	for k in range(1, path.size()):
		var a: Vector3 = path[k - 1]
		var b: Vector3 = path[k]
		var leg: Vector3 = b - a
		var t: float = clampf((p - a).dot(leg) / leg.length_squared(), 0.0, 1.0) if leg.length_squared() > 0.0 else 0.0
		var q: Vector3 = a + leg * t
		var d: float = q.distance_to(p)

		if d < best_d:
			best_d = d
			best_q = q
			best_s = walked + leg.length() * t

		walked += leg.length()

	return [best_s, best_q]


func _cfg(def: Dictionary) -> Dictionary:
	return def.get("den_life", {})


func _span(row: Dictionary, key: String, fallback: Array) -> float:
	var span: Array = row.get(key, fallback)
	return host.rng.randf_range(float(span[0]), float(span[1]))   # luck-exempt: how long a goblin keeps at one thing


# Put a goblin into its den (made by day, or back at the mouth at dawn): a little short of the den node, on the floor.
func enter_den(a: Dictionary) -> void:
	var path: PackedVector3Array = a["cave_path"]
	var length: float = path_length(path)
	a["in_cave"] = true
	a["cave_at"] = 0.0
	a["cave_rest"] = maxf(length - host.rng.randf_range(0.0, 3.0), 0.0)   # luck-exempt: where in the den each one beds down
	a["task"] = ""
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(host.species_def(a["sp"]))
	a["target"] = a["pos"]


# Make a goblin already asleep in the den (a group made by day).
func place_in_den(a: Dictionary) -> void:
	enter_den(a)
	a["cave_at"] = a["cave_rest"]
	a["pos"] = point_at(a["cave_path"], a["cave_at"])


# One step of den life. Returns true when it moved the goblin (ServerAnimals._step stops), false to leave it to the ordinary behaviour.
func step(a: Dictionary, dt: float, seen_d: float, seen_p: Vector3) -> bool:
	var def: Dictionary = host.species_def(a["sp"])

	if bool(a.get("in_cave", false)):
		_step_cave(a, def, dt)
		return true

	var row: Dictionary = _cfg(def)
	a["steal_wait"] = float(a.get("steal_wait", 0.0)) - dt

	if host.big_game.handles(a) or int(a["state"]) == host.FLEE:
		a["task"] = ""
		return false

	if _dog_back_off(a, def, row, dt):
		return true

	var band: String = str(a.get("lair", ""))
	var who: String = _who_at(seen_p)

	# A band that was hurt by this player runs from them at twice the distance.
	if who != "" and trust.wary(band, who) and seen_d <= host._spook_m(a, def) * 2.0:
		a["task"] = ""
		host._bolt(a, seen_p, def)
		return true

	# Carrying loot (after a fright, or picked up again): home with it.
	if a.has("loot") and str(a.get("task", "")) != "carry":
		a["task"] = "carry"

	if str(a.get("task", "")) == "carry":
		return _step_carry(a, def, dt)

	if str(a.get("task", "")) == "steal":
		return _step_steal(a, def, dt)

	var path: PackedVector3Array = a.get("cave_path", PackedVector3Array())

	# Dawn: back to the mouth and in. The ordinary HOP walks it there (and still bolts from a player or a fire on the way).
	if host.resting(def) and not path.is_empty():
		a["task"] = ""
		var mouth: Vector3 = a.get("den_out", path[0])

		if Vector2(mouth.x - a["pos"].x, mouth.z - a["pos"].z).length() <= 3.0:
			a["pos"] = path[0]
			enter_den(a)
			return true

		if int(a["state"]) == host.GRAZE or int(a["state"]) == host.HOP:
			a["state"] = host.HOP
			a["target"] = mouth

		return false

	if str(a.get("task", "")) == "watch":
		return _step_watch(a, def, dt, seen_d, seen_p)

	# A Tolerated player is watched openly, not fled from, until they come within watch_spook_m.
	if who != "" and trust.at_least(band, who, "tolerated") and seen_d <= host._spook_m(a, def) and seen_d > float(row.get("watch_spook_m", 6.0)):
		a["state"] = host.ALERT
		a["alert"] = 1.0
		a["heading"] = atan2(seen_p.z - a["pos"].z, seen_p.x - a["pos"].x)
		return true

	if str(a.get("task", "")) == "forage":
		# The ordinary HOP takes it to the bush; once there it eats for forage_s instead of an ordinary idle, then the task ends.
		if int(a["state"]) == host.GRAZE and not bool(a.get("eating", false)) and Vector2(a["bush"].x - a["pos"].x, a["bush"].z - a["pos"].z).length() > 2.0:
			a["task"] = ""   # it stopped short (it watched a player on the way, or could not get there): the task is over
		elif int(a["state"]) == host.GRAZE and not bool(a.get("eating", false)):
			a["eating"] = true
			a["timer"] = _span(_cfg(def), "forage_s", [20.0, 60.0])
			a["heading"] = atan2(a["bush"].z - a["pos"].z, a["bush"].x - a["pos"].x)
		elif int(a["state"]) == host.GRAZE and float(a["timer"]) - dt <= 0.0:
			a["task"] = ""
			a["eating"] = false

		return false

	# At night, as an ordinary idle runs out, it may pick something to do: steal, else watch a fire, else forage.
	if int(a["state"]) == host.GRAZE and float(a["timer"]) - dt <= 0.0 and not host.resting(def):
		if float(a["steal_wait"]) <= 0.0 and host.rng.randf() < float(row.get("steal_share", 0.0)) and _pick_steal(a, def):   # luck-exempt: whether a goblin goes stealing
			return true

		if _pick_watch(a, def):
			return true

		_pick_forage(a, def)

	return false


# A barking dog (dog_companion_design.md 11, MikeW's DOG_REACTIONS.md): a goblin within dog_back_m backs off dog_back_step_m from it, faces it and
# holds for dog_back_s before it comes on again; two barking dogs make it flee. A silent dog does nothing, and a goblin already fighting
# (big game states, handled before this) is not stopped. True while the back-off decides the step.
func _dog_back_off(a: Dictionary, def: Dictionary, row: Dictionary, dt: float) -> bool:
	var dogs: Array = host.barking_dogs_near(a["pos"], float(row.get("dog_back_m", 20.0)))

	if dogs.size() >= 2:
		a["task"] = ""
		a.erase("dog_hold")
		host._bolt(a, dogs[0][0], def)
		return true

	if not dogs.is_empty() and not a.has("dog_hold"):
		var at: Vector3 = dogs[0][0]
		var away: Vector2 = Vector2(a["pos"].x - at.x, a["pos"].z - at.z).normalized()
		a["task"] = ""
		a["eating"] = false
		a["dog_hold"] = _span(row, "dog_back_s", [4.0, 8.0])
		a["dog_at"] = at
		a["target"] = a["pos"] + Vector3(away.x, 0.0, away.y) * float(row.get("dog_back_step_m", 5.0))
		a["state"] = host.HOP
		return false   # the ordinary HOP walks it back

	if not a.has("dog_hold"):
		return false

	if not dogs.is_empty():
		a["dog_at"] = dogs[0][0]

	if int(a["state"]) == host.HOP:
		return false   # still stepping back

	a["dog_hold"] = float(a["dog_hold"]) - dt
	var seen: Vector3 = a["dog_at"]

	if float(a["dog_hold"]) <= 0.0:
		a.erase("dog_hold")
		a.erase("dog_at")
		a["state"] = host.GRAZE
		a["timer"] = host._graze_time(def)
		return true

	a["state"] = host.ALERT   # it faces the dog and waits
	a["alert"] = 1.0
	a["heading"] = atan2(seen.z - a["pos"].z, seen.x - a["pos"].x)
	return true


# A small loose thing outside every fire's light, not on a den pile and with no player within steal_scare_m of it: the nearest to the goblin.
func _pick_steal(a: Dictionary, def: Dictionary) -> bool:
	if not stealable.is_valid():
		return false

	var row: Dictionary = _cfg(def)
	var best: Array = []
	var best_d: float = INF

	var band: String = str(a.get("lair", ""))

	for found in stealable.call(_home(a), float(row.get("steal_reach_m", 150.0))):
		var at: Vector3 = found[1]
		var d: float = Vector2(at.x - a["pos"].x, at.z - a["pos"].z).length()
		var by: String = str(found[2]) if found.size() > 2 else ""

		if by.begins_with("goblin:"):
			continue   # a band's own return gift, left for a player

		# A Known player's things are not stolen any more; the food they leave is a gift, and is taken.
		if by != "" and trust.at_least(band, by, "known") and (str(found[3]) if found.size() > 3 else "") != "food":
			continue

		if d < best_d and _may_take(at, def):
			best_d = d
			best = found

	if best.is_empty():
		return false

	a["task"] = "steal"
	a["prize"] = int(best[0])
	a["prize_at"] = best[1]
	a["prize_by"] = str(best[2]) if best.size() > 2 else ""
	a["state"] = SNEAK
	return true


# Whether a goblin may take the thing at `at` now: unlit, not on a goblin den's pile, no player near it.
func _may_take(at: Vector3, def: Dictionary) -> bool:
	if host._fire_guard(at) != Vector3.INF or _scared(at, def):
		return false

	var den_m: float = float(def.get("den", {}).get("den_m", 12.0))

	for id in host.animals:
		var other: Dictionary = host.animals[id]

		if other.has("cave_path") and (other["den"] as Vector3).distance_to(at) <= den_m:
			return false

	return true


func _scared(at: Vector3, def: Dictionary) -> bool:
	var scare_m: float = float(_cfg(def).get("steal_scare_m", 8.0))

	for p in (host.player_positions.call() if host.player_positions.is_valid() else []):
		if Vector2(p.x - at.x, p.z - at.z).length() < scare_m:
			return true

	return false


func _give_up(a: Dictionary, def: Dictionary) -> bool:
	a["task"] = ""
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(def)
	return true


# SNEAK: creep to the thing and take one piece; a player near the goblin or the thing, the light reaching it, or the thing gone, and it gives up.
func _step_steal(a: Dictionary, def: Dictionary, dt: float) -> bool:
	var row: Dictionary = _cfg(def)
	var prize_at: Vector3 = a["prize_at"]
	var there: bool = false

	for found in (stealable.call(prize_at, 2.0) if stealable.is_valid() else []):
		there = there or int(found[0]) == int(a["prize"])

	if not there or host.resting(def) or _scared(a["pos"], def) or host._fire_guard(prize_at) != Vector3.INF or _scared(prize_at, def):
		return _give_up(a, def)

	var lit: Vector3 = host._fire_guard(a["pos"])

	if lit != Vector3.INF:
		a["task"] = ""
		host._bolt(a, lit, def)
		return true

	var r: Dictionary = Steering.step(a["pos"], prize_at, float(row.get("sneak_mps", 1.0)), dt, host.ground_height, host.blocked, 0.8, a["heading"], host.crossing)

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]

	if not r["arrived"]:
		return _give_up(a, def) if not r["moved"] else true

	var taken: Array = take_one.call(int(a["prize"])) if take_one.is_valid() else []

	if taken.is_empty():
		return _give_up(a, def)

	a["loot"] = taken
	trust.gift(str(a.get("lair", "")), str(a.get("prize_by", "")))   # a thing a player left in the dark: a gift, once a night
	a["task"] = "carry"
	a["state"] = CARRY
	return true


# CARRY: run home to the mouth with the piece and go in (the cave step lays it on the den pile). Without a cave path it lays it at the mouth.
func _step_carry(a: Dictionary, def: Dictionary, dt: float) -> bool:
	var path: PackedVector3Array = a.get("cave_path", PackedVector3Array())
	var mouth: Vector3 = _home(a)
	var lit: Vector3 = host._fire_guard(a["pos"])

	if lit != Vector3.INF:
		host._bolt(a, lit, def)   # it keeps the loot and heads home again after
		return true

	a["state"] = CARRY
	var r: Dictionary = Steering.step(a["pos"], mouth, float(_cfg(def).get("carry_mps", 4.5)), dt, host.ground_height, host.blocked, 1.0, a["heading"], host.crossing)

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]

	if not r["arrived"] and r["moved"]:
		return true

	if path.size() >= 2:
		a["pos"] = path[0]
		enter_den(a)   # the cave step takes it to the den and lays the loot down
	else:
		stash(a)
		_give_up(a, def)

	return true


# Lay a goblin's loot on its den pile (the den floor; the mouth for a band without a cave path).
func stash(a: Dictionary) -> void:
	if not a.has("loot"):
		return

	var def: Dictionary = host.species_def(a["sp"])
	var path: PackedVector3Array = a.get("cave_path", PackedVector3Array())
	var pile: Vector3 = path[path.size() - 1] if path.size() >= 2 else a.get("den", a["pos"])

	if hoard_drop.is_valid():
		hoard_drop.call(int(a["loot"][0]), int(a["loot"][1]), pile, float(_cfg(def).get("hoard_life_s", 604800.0)))

	a.erase("loot")
	a["steal_wait"] = float(_cfg(def).get("steal_again_s", 120.0))


# Where a goblin ranges round at night: the mouth it came out of.
func _home(a: Dictionary) -> Vector3:
	return a.get("den_out", a["home"])


# A burning fire (or torch bearer) within watch_reach_m of home, and a spot at the edge of its light, outside every fire's radius, on the side
# toward the cave. watch_share of the time.
func _pick_watch(a: Dictionary, def: Dictionary) -> bool:
	var row: Dictionary = _cfg(def)

	if host.rng.randf() >= float(row.get("watch_share", 0.5)):   # luck-exempt: whether a goblin goes to watch a fire
		return false

	var home: Vector3 = _home(a)
	var best: Array = []
	var best_d: float = INF

	for f in host._fire_cache:
		var at: Vector3 = f[0]
		var d: float = Vector2(at.x - home.x, at.z - home.z).length()

		if d <= float(row.get("watch_reach_m", 150.0)) and d < best_d:
			best_d = d
			best = f

	if best.is_empty():
		return false

	var fire: Vector3 = best[0]
	var toward: Vector2 = Vector2(home.x - fire.x, home.z - fire.z)
	toward = toward.normalized() if toward.length() > 0.01 else Vector2.from_angle(a["heading"])
	var edge: float = float(best[1]) + float(row.get("watch_gap_m", 2.0))

	for turn in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var dir: Vector2 = toward.rotated(turn)
		var spot: Vector3 = Vector3(fire.x + dir.x * edge, 0.0, fire.z + dir.y * edge)

		if host._fire_guard(spot) != Vector3.INF or (host.blocked.is_valid() and bool(host.blocked.call(spot.x, spot.z))):
			continue

		spot.y = float(host.ground_height.call(spot.x, spot.z)) if host.ground_height.is_valid() else fire.y

		if is_nan(spot.y):
			continue

		a["task"] = "watch"
		a["watching"] = false
		a["fire"] = fire
		a["fire_r"] = float(best[1])
		a["target"] = spot
		a["state"] = host.HOP
		return true

	return false


# A berry bush within forage_m of home, outside every fire's light: it walks there (the ordinary HOP) and eats.
func _pick_forage(a: Dictionary, def: Dictionary) -> void:
	if not host.berry_bushes.is_valid():
		return

	var row: Dictionary = _cfg(def)
	var home: Vector3 = _home(a)
	var bushes: PackedVector3Array = host.berry_bushes.call(home, float(row.get("forage_m", 70.0)))
	var open: Array = []

	for at in bushes:
		if host._fire_guard(at) == Vector3.INF:
			open.append(at)

	if open.is_empty():
		return

	var bush: Vector3 = open[host.rng.randi_range(0, open.size() - 1)]   # luck-exempt: which bush a goblin forages at
	var side: Vector2 = Vector2(a["pos"].x - bush.x, a["pos"].z - bush.z)
	side = side.normalized() if side.length() > 0.01 else Vector2.RIGHT
	a["task"] = "forage"
	a["eating"] = false
	a["bush"] = bush
	a["target"] = Vector3(bush.x + side.x * 0.8, bush.y, bush.z + side.y * 0.8)   # it stands at the bush, not in it
	a["state"] = host.HOP


# Creep to the edge of the light and watch. While on this task it bolts only from a player within watch_spook_m (the people at the fire see the
# eyes in the dark), from a fire's light reaching it, or when the fire goes out.
func _step_watch(a: Dictionary, def: Dictionary, dt: float, seen_d: float, seen_p: Vector3) -> bool:
	var row: Dictionary = _cfg(def)
	var fire: Vector3 = a["fire"]
	var still_lit: bool = false

	for f in host._fire_cache:
		still_lit = still_lit or (f[0] as Vector3).distance_to(fire) <= 2.0

	if seen_p != Vector3.INF and seen_d <= float(row.get("watch_spook_m", 6.0)):
		a["task"] = ""
		host._bolt(a, seen_p, def)
		return true

	var lit: Vector3 = host._fire_guard(a["pos"])

	if lit != Vector3.INF:
		a["task"] = ""
		host._bolt(a, lit, def)
		return true

	if not still_lit:
		a["task"] = ""
		a["state"] = host.GRAZE
		a["timer"] = host._graze_time(def)
		return true

	if bool(a.get("watching", false)):
		a["alert"] = float(a["alert"]) - dt
		a["heading"] = atan2(fire.z - a["pos"].z, fire.x - a["pos"].x)

		if float(a["alert"]) <= 0.0:
			_return_gift(a, def)
			a["task"] = ""
			a["state"] = host.GRAZE
			a["timer"] = host._graze_time(def)

		return true

	var r: Dictionary = Steering.step(a["pos"], a["target"], float(def.get("walk_mps", 1.2)), dt, host.ground_height, host.blocked, 0.4, a["heading"], host.crossing)

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]

	if r["arrived"] or not r["moved"]:
		a["watching"] = true
		a["state"] = host.ALERT   # the client's watching pose
		a["alert"] = _span(row, "watch_s", [60.0, 180.0])
		a["heading"] = atan2(fire.z - a["pos"].z, fire.x - a["pos"].x)

	return true


# The character key of the player standing at a point ("" for none or unknown): the player_info entry within 1 m of it.
func _who_at(p: Vector3) -> String:
	if p == Vector3.INF or not peer_key.is_valid() or not host.big_game.player_info.is_valid():
		return ""

	for info in host.big_game.player_info.call():
		if (info["pos"] as Vector3).distance_to(p) <= 1.0:
			return str(peer_key.call(int(info["peer"])))

	return ""


# After watching at a fire with a Known player beside it, a goblin leaves a return gift at its spot (once a day per band and player).
func _return_gift(a: Dictionary, def: Dictionary) -> void:
	if not peer_key.is_valid() or not host.big_game.player_info.is_valid() or not gift_drop.is_valid() or not item_number.is_valid():
		return

	var band: String = str(a.get("lair", ""))
	var fire: Vector3 = a["fire"]
	var gifts: Array = def.get("ally", {}).get("return_gifts", [])

	for info in host.big_game.player_info.call():
		var who: String = str(peer_key.call(int(info["peer"])))

		if Vector2(info["pos"].x - fire.x, info["pos"].z - fire.z).length() > float(a.get("fire_r", 10.0)) + 10.0 or not trust.return_gift_due(band, who, true):
			continue

		var total: float = 0.0

		for g in gifts:
			total += float(g.get("weight", 1.0))

		var roll: float = host.rng.randf() * total   # luck-exempt: which return gift a band leaves
		for g in gifts:
			roll -= float(g.get("weight", 1.0))

			if roll <= 0.0:
				var number: int = int(item_number.call(str(g["item"])))

				if number > 0:
					gift_drop.call(number, int(g.get("count", 1)), a["pos"], "goblin:" + band)

				break

		return


# Harm (Dave's ally design): a player who hurts one of the band resets their trust with it and makes it wary of them.
func harm(a: Dictionary, peer: int) -> void:
	if peer >= 0 and peer_key.is_valid() and a.has("lair"):
		trust.harm(str(a["lair"]), str(peer_key.call(peer)))


# The nearest player in the cave with this goblin: {d: metres along the cave, s: where along the path, pos, peer}, {} for none. A player counts
# when the path passes within cave_level_m of them vertically: in the cave, or at the mouth; never on the hill above.
func _cave_player(a: Dictionary, def: Dictionary) -> Dictionary:
	var path: PackedVector3Array = a["cave_path"]
	var level_m: float = float(_cfg(def).get("cave_level_m", 6.0))
	var infos: Array = []

	if host.big_game.player_info.is_valid():
		infos = host.big_game.player_info.call()
	elif host.player_positions.is_valid():
		for p in host.player_positions.call():
			infos.append({"peer": -1, "pos": p})

	var best: Dictionary = {}

	for info in infos:
		var p: Vector3 = info["pos"]
		var on: Array = project(path, p)
		var q: Vector3 = on[1]

		if absf(p.y - q.y) > level_m:
			continue

		var d: float = absf(float(on[0]) - float(a["cave_at"])) + Vector2(p.x - q.x, p.z - q.z).length()

		if best.is_empty() or d < float(best["d"]):
			best = {"d": d, "s": float(on[0]), "pos": p, "peer": int(info.get("peer", -1))}

	return best


# Walk along the path toward `goal` (metres from the mouth). Returns true when it got there.
func _walk(a: Dictionary, goal: float, speed: float, dt: float) -> bool:
	var at: float = float(a["cave_at"])
	var step_m: float = speed * dt
	var next: float = goal if absf(goal - at) <= step_m else at + signf(goal - at) * step_m
	var path: PackedVector3Array = a["cave_path"]
	var from: Vector3 = a["pos"]
	a["cave_at"] = next
	a["pos"] = point_at(path, next)

	if Vector2(a["pos"].x - from.x, a["pos"].z - from.z).length() > 0.01:
		a["heading"] = atan2(a["pos"].z - from.z, a["pos"].x - from.x)

	return is_equal_approx(next, goal)


func _step_cave(a: Dictionary, def: Dictionary, dt: float) -> void:
	var path: PackedVector3Array = a["cave_path"]
	var length: float = path_length(path)
	var defend: Dictionary = def.get("defend", {})
	var near: Dictionary = _cave_player(a, def)
	var state: int = int(a["state"])
	host.big_game.cool_down(a, dt)

	# The warning, the lunge and the rest after it: big game's states, moved along the path.
	if state == host.WARN:
		a["timer"] = float(a["timer"]) - dt

		if near.is_empty() or float(near["d"]) > float(defend.get("calm_m", 25.0)):
			_calm(a, def)
			return

		a["heading"] = atan2(near["pos"].z - a["pos"].z, near["pos"].x - a["pos"].x)

		if float(a["timer"]) <= 0.0:
			a["state"] = host.big_game.CHARGE
			a["ran"] = 0.0
			a["hit"] = false

		return

	if state == host.big_game.CHARGE:
		var goal: float = float(near["s"]) if not near.is_empty() else float(a["cave_at"])
		var from: float = float(a["cave_at"])
		var there: bool = _walk(a, goal, float(defend.get("charge_mps", 5.0)), dt)
		a["ran"] = float(a["ran"]) + absf(float(a["cave_at"]) - from)

		if not near.is_empty() and not bool(a["hit"]) and (near["pos"] as Vector3).distance_to(a["pos"]) <= float(defend.get("hit_m", 1.0)) + 0.6 and host.big_game.hurt_player.is_valid():
			a["hit"] = true
			host.big_game.hurt_player.call(int(near["peer"]), float(defend.get("damage", 8.0)) * host.level_x(a, "damage"), false, str(a["sp"]))

		if bool(a["hit"]) or float(a["ran"]) >= float(defend.get("charge_m", 15.0)) or there:
			a["state"] = host.big_game.RECOVER
			a["timer"] = float(defend.get("recover_s", 3.0))

		return

	if state == host.big_game.RECOVER:
		a["timer"] = float(a["timer"]) - dt

		if float(a["timer"]) <= 0.0:
			_calm(a, def)

		return

	# Threatened: inside its threat range (the den's, at the den end), it warns, then lunges.
	if not near.is_empty():
		var at_den: bool = float(a["cave_at"]) >= length - float(def.get("den", {}).get("den_m", 12.0))
		var threat_m: float = float(def.get("den", {}).get("threat_m", 8.0)) if at_den else float(defend.get("threat_m", 3.0))

		if float(near["d"]) <= threat_m and host.big_game.warn(a, near["pos"], float(defend.get("threat_warn_s", 0.5))):
			return

		# Too close: it goes deeper, toward the den (cornered there, the den threat range above takes over).
		if float(near["d"]) <= host._spook_m(a, def):
			a["state"] = host.FLEE
			_walk(a, length, float(def.get("flee_mps", 5.5)) * float(def.get("trot_share", 0.6)), dt)
			return

		# Near enough to worry about: it stays where it is and watches, rather than walk out toward the player at night.
		if float(near["d"]) <= host._spook_m(a, def) * 1.5 and not host.resting(def):
			a["state"] = host.ALERT
			a["heading"] = atan2(near["pos"].z - a["pos"].z, near["pos"].x - a["pos"].x)
			return

	# Home with loot: down to the den, where it goes on the pile.
	if a.has("loot"):
		if _walk(a, length, float(def.get("walk_mps", 1.2)), dt):
			stash(a)
			a["state"] = host.GRAZE
		else:
			a["state"] = host.HOP

		return

	if host.resting(def):
		# By day: to its sleeping spot in the den, then it lies there.
		if _walk(a, float(a.get("cave_rest", length)), float(def.get("walk_mps", 1.2)), dt):
			a["state"] = host.GRAZE
		else:
			a["state"] = host.HOP

		return

	# Night: out along the path; at the mouth it becomes an ordinary surface goblin there, unless a fire's light covers the mouth.
	if not _walk(a, 0.0, float(def.get("walk_mps", 1.2)), dt):
		a["state"] = host.HOP
		return

	var mouth: Vector3 = path[0]
	var ground: float = float(host.ground_height.call(mouth.x, mouth.z)) if host.ground_height.is_valid() else mouth.y

	if host._fire_guard(mouth) != Vector3.INF:
		a["state"] = host.GRAZE
		return

	a["in_cave"] = false
	a["pos"] = Vector3(mouth.x, mouth.y if is_nan(ground) else ground, mouth.z)
	a["home"] = a["pos"]
	a["den_out"] = a["pos"]
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(def)


func _calm(a: Dictionary, def: Dictionary) -> void:
	a["state"] = host.GRAZE
	a["timer"] = host._graze_time(def)
	a["alert"] = 0.0
	a["cool"] = float(def.get("defend", {}).get("cool_s", 20.0))
