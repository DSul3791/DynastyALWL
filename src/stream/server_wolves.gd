extends RefCounted

# Wolves (Dave's wolf card answers, 2026-10-21; design items/WOLF_CARD.md; tuning data/animals/animals.json "wolves").
# A wolf is an ordinary animal record (species wolf, so rows, damage, blood and carcasses are shared); what is new is the pack
# brain: one decision per pack, wolves only follow it. A pack prowls its home; a player who comes within notice_m is stalked at
# stalk_m for 10 to 20 s (a long warning). A lone player who is hurt or carries raw meat is rushed; the pack maims first (health
# falls to maim_hp, no lower), backs off for retreat_s (5 real minutes) and, if the player is still around when it comes back,
# kills. A fire or a torch is a keep-out zone: wolves never step into its light, they circle just outside it (fires) or
# approach only through shadow and hover at the edge (torches). Two players together, a wolf killed or badly hurt, or a spear on
# the hotbar of a healthy player send the pack away. Prey (a deer) near a waiting pack draws it off: it feeds and forgets.
# Pure server code; the animals module calls tick() once per server tick and owns the records.

const Steering := preload("res://src/shared/steering.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const STALK := 6      # wire states (animal rows): 0 graze, 1 hop, 6 stalk or circle, 7 attack
const ATTACK := 7
const ROLL := 8       # idle: rolling in the grass
const PLAY := 9       # idle: playing like dogs
const DAY_S := 86400.0
const GAME_PER_REAL := 24.0   # game seconds per real second (game_clock.gd RATIO)
const DENS_FILE := "wolf_dens.json"

var host                          # the animals module (animals, cfg, rng, ground_height, blocked, species_def, spawn, damage)
var take_meat: Callable           # (peer) -> int: takes every piece of meat out of the pack, returns how many
var player_info: Callable         # () -> Array of {peer, pos, stance, hp 0..1, meat bool, spear bool, torch bool}
var fires: Callable               # () -> Array of Vector3, burning fires
var hurt_player: Callable         # (peer, damage, lethal, cause) -> "hurt" | "maimed" | "dead"
var notice: Callable              # (peer, text)
var fire_radius: Callable         # (fire position) -> metres wolves keep from that fire (its tier's protect_m); invalid = animals.json fire_light_m
var is_day: Callable              # () -> bool, play only by day (invalid = always)
var events: Array = []            # sounds for the client/Mandy: {kind "growl"|"howl", pos}, newest last, capped
var game_seconds: Callable        # () -> game seconds (game_clock.seconds); pups' season and orphans' days
var store_dir: String = ""        # "" = dens not saved (tests)
var dens: Dictionary = {}         # saved per den (docs/design/wolf_packs_and_pups_design.md): den key -> {"rest_until_s", "orphan": {den [x,y,z], pups, since_s, trust}}
var _peer_speed: Dictionary = {}  # peer -> m/s over the last tick (pups hide from a moving player)
var _peer_last: Dictionary = {}
var _dens_dirty: bool = false

var packs: Dictionary = {}        # id -> {id, ids Array, phase, timer, target peer, home, maimed Dictionary, hurt, prey, point, bite Dictionary}
var cells: Dictionary = {}        # natural pack cells: "cx,cz" -> {pack id or 0, dead_until msec}
var _next_pack: int = 1
var _fire_cache: Array = []
var _fire_age: float = 99.0
var _natural_acc: float = 0.0
var _clock: float = 0.0


func cfgw() -> Dictionary:
	return host.cfg.get("wolves", {})


# Pack wolves only: pups and companion wolves are not counted against max_wolves.
func wolf_count() -> int:
	var n: int = 0

	for id in host.animals:
		n += 1 if host.animals[id]["sp"] == "wolf" and host.animals[id].has("pack") else 0

	return n


# Admin and tests: a whole pack at once around (x, z). Returns the pack id or 0.
func spawn_pack(x: float, z: float) -> int:
	var size: Array = host.species_def("wolf").get("pack_size", [3, 5])
	var count: int = host.rng.randi_range(int(size[0]), int(size[1]))   # luck-exempt: how many wolves in a pack
	var pid: int = _next_pack
	_next_pack += 1
	var pack: Dictionary = {"id": pid, "ids": [], "pups": [], "key": "%d,%d" % [int(x), int(z)], "phase": "prowl", "timer": 0.0, "target": -1, "home": Vector3(x, 0.0, z), "maimed": {}, "hurt": false, "prey": 0, "den": Vector3(x, 0.0, z), "joined": false, "point": Vector3.INF, "bite": {}, "ignore": {}, "angle": 0.0, "sprint": 0.0, "stalk_s": 0.0, "hunger": float(cfgw().get("hunger_start", 0.4)), "for_meat": false, "meat_hits": 0}

	for k in count:
		var angle: float = TAU * float(k) / float(count)
		var id: int = host.spawn("wolf", x + cos(angle) * 4.0, z + sin(angle) * 4.0)

		if id != 0:
			host.animals[id]["pack"] = pid
			pack["ids"].append(id)

	if pack["ids"].is_empty():
		return 0

	pack["home"] = host.animals[pack["ids"][0]]["pos"]
	packs[pid] = pack
	return pid


# A wolf died (jab, bleeding out): the pack backs off; an emptied natural cell rests for respawn_s.
func on_death(id: int, pack_id: int) -> void:
	if not packs.has(pack_id):
		return

	var pack: Dictionary = packs[pack_id]
	pack["ids"].erase(id)
	pack["hurt"] = true

	if pack["ids"].is_empty():
		for key in cells:
			if int(cells[key].get("pack", 0)) == pack_id:
				cells[key]["pack"] = 0
				cells[key]["dead_until"] = _clock + float(cfgw().get("respawn_s", 7200.0))

		_orphan(pack)
		packs.erase(pack_id)


func on_hit(a: Dictionary) -> void:
	if packs.has(a.get("pack", 0)):
		packs[a["pack"]]["hurt"] = true


func tick(delta: float) -> void:
	_clock += delta
	_fire_age += delta
	var infos: Array = player_info.call() if player_info.is_valid() else []

	if _fire_age >= 1.0:
		_fire_cache = fires.call() if fires.is_valid() else []
		_fire_age = 0.0

	for info in infos:
		var was: Vector3 = _peer_last.get(info["peer"], info["pos"])
		_peer_speed[info["peer"]] = Vector2(info["pos"].x - was.x, info["pos"].z - was.z).length() / maxf(delta, 0.001)
		_peer_last[info["peer"]] = info["pos"]

	_tend_orphans(infos, delta)

	if bool(cfgw().get("natural", false)):
		_natural_acc += delta

		if _natural_acc >= 5.0:
			_natural_acc = 0.0
			_natural(infos)

	for pid in packs.keys():
		if packs.has(pid):
			_think(packs[pid], delta, infos)


# --- light ---

# Whether a ground point is inside a fire's light or a torch carrier's (wolves will not enter).
func lit(x: float, z: float, infos: Array) -> bool:
	for f in _fire_cache:
		if Vector2(f.x - x, f.z - z).length() < _fire_m(f):
			return true

	var torch_m: float = float(cfgw().get("torch_light_m", 9.0))

	for info in infos:
		if bool(info.get("torch", false)) and Vector2(info["pos"].x - x, info["pos"].z - z).length() < torch_m:
			return true

	return false


# How far wolves keep from one fire: its tier's protection (a bigger fire holds them further off).
func _fire_m(f: Vector3) -> float:
	return float(fire_radius.call(f)) if fire_radius.is_valid() else float(cfgw().get("fire_light_m", 10.0))


# The nearest burning fire within r of a point, or Vector3.INF.
func fire_near(p: Vector3, r: float) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_d: float = r

	for f in _fire_cache:
		var d: float = Vector2(f.x - p.x, f.z - p.z).length()

		if d < best_d:
			best_d = d
			best = f

	return best


# --- the pack brain ---

# 0 far from the den .. 1 at the den: the closer a player is to it the braver the pack (longer notice, attacks healthier players).
func boldness(pack: Dictionary, p: Vector3) -> float:
	var den_m: float = float(cfgw().get("den_m", 300.0))
	return clampf(1.0 - Vector2(p.x - pack["den"].x, p.z - pack["den"].z).length() / den_m, 0.0, 1.0)


func _event(kind: String, pos: Vector3) -> void:
	events.append({"kind": kind, "pos": pos})

	while events.size() > 20:
		events.pop_front()


# A howl pulls the other prowling packs within howl_m toward the same player (at most howl_packs of them).
func _howl(pack: Dictionary, c: Vector3, target: int) -> void:
	_event("howl", c)
	var w: Dictionary = cfgw()
	var joined: int = 0

	for pid in packs:
		var other: Dictionary = packs[pid]

		if pid == pack["id"] or other["phase"] != "prowl" or joined >= int(w.get("howl_packs", 2)):
			continue

		var members: Array = _members(other)

		if members.is_empty() or _centre(members).distance_to(c) > float(w.get("howl_m", 1500.0)):
			continue

		other["phase"] = "stalk"
		other["target"] = target
		other["stalk_s"] = float(w.get("stalk_s", [10.0, 20.0])[1])
		other["angle"] = host.rng.randf() * TAU   # luck-exempt: which side a summoned pack circles from
		other["joined"] = true
		joined += 1


func _members(pack: Dictionary) -> Array:
	var out: Array = []

	for id in pack["ids"]:
		if host.animals.has(id):
			out.append(host.animals[id])

	return out


func _centre(members: Array) -> Vector3:
	var c: Vector3 = Vector3.ZERO

	for m in members:
		c += m["pos"]

	return c / float(maxi(members.size(), 1))


func _info_of(infos: Array, peer: int) -> Dictionary:
	for info in infos:
		if int(info["peer"]) == peer:
			return info

	return {}


# Does this pack want what the player carries? Raw meat always; cooked meat only when the pack is hungry (Dave 2026-10-21).
func wants_meat(pack: Dictionary, info: Dictionary) -> bool:
	if bool(info.get("meat", false)):
		return true

	return bool(info.get("meat_cooked", false)) and float(pack["hunger"]) >= float(cfgw().get("hungry_at", 0.6))


func _say_to(peer: int, text: String) -> void:
	if notice.is_valid() and peer >= 0:
		notice.call(peer, text)


func _think(pack: Dictionary, dt: float, infos: Array) -> void:
	var members: Array = _members(pack)

	if members.is_empty():
		packs.erase(pack["id"])
		return

	var c: Vector3 = _centre(members)
	var active: float = float(host.cfg.get("active_radius_m", 200.0))
	var near_any: bool = false

	for info in infos:
		near_any = near_any or Vector2(info["pos"].x - c.x, info["pos"].z - c.z).length() <= active

	if not near_any:
		return   # frozen until a player comes within active_radius_m

	var w: Dictionary = cfgw()
	pack["timer"] -= dt
	pack["hunger"] = minf(float(pack["hunger"]) + dt / maxf(float(w.get("hunger_full_s", 3600.0)), 1.0), 1.0)

	# Prey draws a pack that is stalking or waiting (never one in the middle of a rush).
	# A player's dog draws a prowling pack too (dog_companion_design.md 11).
	if pack["phase"] in ["stalk", "wait", "prowl_target", "prowl"] and pack["phase"] != "feed":
		var prey: int = _prey_near(c, float(w.get("distract_m", 80.0))) if pack["phase"] != "prowl" else _dog_near(c, float(w.get("distract_m", 80.0)))

		if prey != 0:
			pack["phase"] = "feed"
			pack["prey"] = prey
			pack["timer"] = float(w.get("feed_s", 60.0))
			pack["target"] = -1
			pack["maimed"] = {}

	if pack["phase"] in ["prowl", "stalk", "wait", "prowl_target"]:
		_guard_check(pack, infos)

	match pack["phase"]:
		"den_guard":
			_den_guard(pack, members, c, dt, infos)
		"prowl":
			_prowl(pack, members, c, dt, infos)
		"stalk":
			_stalk(pack, members, c, dt, infos)
		"rush":
			_rush(pack, members, c, dt, infos)
		"wait":
			_wait(pack, members, c, dt, infos)
		"feed":
			_feed(pack, members, c, dt, infos)

	for m in members:
		var moved: bool = bool(m.get("moving", false))
		m["state"] = ATTACK if pack["phase"] == "rush" or (pack["phase"] == "den_guard" and bool(pack.get("guard_rush", false))) else (STALK if pack["phase"] in ["stalk", "den_guard"] else (int(m["play_kind"]) if float(m.get("play", 0.0)) > 0.0 else (1 if moved else 0)))


# A player's dog within reach comes first (dog_companion_design.md 11, MikeW's DOG_REACTIONS.md: wolves go for the dog); otherwise the nearest deer or moose.
func _prey_near(c: Vector3, r: float) -> int:
	var best: int = _dog_near(c, r)
	var best_d: float = r

	if best != 0:
		return best

	for id in host.animals:
		var a: Dictionary = host.animals[id]

		if not (a["sp"] in ["deer", "moose"]) or a["state"] == host.HIDDEN:
			continue

		var d: float = Vector2(a["pos"].x - c.x, a["pos"].z - c.z).length()

		if d < best_d:
			best_d = d
			best = id

	return best


# The nearest player's dog within r of c (0 for none, or with wolves.dog_prey off).
func _dog_near(c: Vector3, r: float) -> int:
	var best: int = 0
	var best_d: float = r

	if not bool(cfgw().get("dog_prey", true)):
		return 0

	for dog in host._dogs:
		var dd: float = Vector2(dog[1].x - c.x, dog[1].z - c.z).length()

		if dd < best_d:
			best_d = dd
			best = int(dog[0])

	return best


# Wolves in a snowfall (animals_in_weather_design.md 9, lesson 5): in animals.json weather.wolf_snow_from (0.3) snow or more the pack walks
# and trots wolf_snow.speed_x (0.6) as fast and prowls wolf_snow.roam_x (0.5) as far; the chase is unchanged. 1 otherwise.
func _snow_x(key: String) -> float:
	var r: Dictionary = host._wx_rules()

	if not host._wx_on() or float(host._wx.get("snow", 0.0)) < float(r.get("wolf_snow_from", 0.3)):
		return 1.0

	return float((r.get("wolf_snow", {}) as Dictionary).get(key, 0.6 if key == "speed_x" else 0.5))


func _walk(m: Dictionary, goal: Vector3, speed: float, dt: float, infos: Array) -> bool:
	var host_blocked: Callable = host.ice_blocked(host.blocked, host.ice_mass("wolf")) if host.ice_on() and not is_nan(host.ice_mass("wolf")) else host.blocked   # ice that holds a wolf is ground (animals_on_ice_server.md)
	var ground: Callable = host.ice_ground(host.ground_height, host.ice_mass("wolf")) if host.ice_on() and not is_nan(host.ice_mass("wolf")) else host.ground_height
	var me = self
	var shy: Callable = func(x, z): return (host_blocked.is_valid() and bool(host_blocked.call(x, z))) or me.lit(x, z, infos)
	var r: Dictionary = Steering.step(m["pos"], goal, speed, dt, ground, shy, 0.5, m["heading"], host.crossing)
	m["moving"] = bool(r["moved"])

	if r["moved"]:
		m["pos"] = r["pos"]
		m["heading"] = r["heading"]

	return bool(r["arrived"])


func _prowl(pack: Dictionary, members: Array, c: Vector3, dt: float, infos: Array) -> void:
	var w: Dictionary = cfgw()
	var def: Dictionary = host.species_def("wolf")

	# Notice: the nearest player as the leader perceives them (wind, crouch, cover) within notice_m starts a stalk.
	var lead: Dictionary = members[0]
	var best: Dictionary = {}
	var best_d: float = float(w.get("notice_m", 35.0))
	var calm: bool = true

	for info in infos:
		if pack["ignore"].has(info["peer"]) and float(pack["ignore"][info["peer"]]) > _clock:
			continue

		for m in members:
			var d: float = Vector2(info["pos"].x - m["pos"].x, info["pos"].z - m["pos"].z).length()
			var seen: float = d / host._sense_factor(m, def, info["pos"], d, int(info.get("stance", 0))) / (1.0 + boldness(pack, info["pos"]) * float(w.get("den_notice_gain", 1.0)))
			calm = calm and seen > float(w.get("notice_m", 35.0)) * 2.0

			if seen < best_d:
				best_d = seen
				best = info

	if not best.is_empty():
		pack["phase"] = "stalk"
		pack["target"] = int(best["peer"])
		pack["stalk_s"] = host.rng.randf_range(float(w.get("stalk_s", [10.0, 20.0])[0]), float(w.get("stalk_s", [10.0, 20.0])[1]))   # luck-exempt: how long a pack shadows a player
		pack["angle"] = host.rng.randf() * TAU   # luck-exempt: which side a pack circles from
		_say_to(int(best["peer"]), str(w.get("say_watched", "Something is watching you from the trees.")))
		_event("growl", c)

		for m2 in members:
			m2["play"] = 0.0

		if not pack["joined"] and host.rng.randf() < float(w.get("howl_chance", 0.5)):   # luck-exempt: whether the pack howls
			_howl(pack, c, int(best["peer"]))

		return

	# Calm and unaware by day: they roll in the grass and play like dogs (a quiet, downwind watcher can see it).
	var daytime: bool = not is_day.is_valid() or bool(is_day.call())

	if calm and daytime:
		var playing: bool = false

		for m3 in members:
			m3["play"] = float(m3.get("play", 0.0)) - dt
			playing = playing or float(m3["play"]) > 0.0

		if not playing and pack["timer"] <= 0.0 and host.rng.randf() < float(w.get("play_chance", 0.3)):   # luck-exempt: whether an unaware pack plays
			for k in members.size():
				members[k]["play"] = host.rng.randf_range(8.0, 15.0)   # luck-exempt: how long they play
				members[k]["play_kind"] = ROLL if k % 2 == 0 else PLAY
				members[k]["moving"] = false

		if playing:
			return

	# Wander the home area; at dawn and dusk, near the water the prey drink at (animals_at_water_server.md).
	var water: Vector3 = host.wolf_wait_point(pack["home"])
	var centre: Vector3 = pack["home"] if water == Vector3.INF else water
	var roam: float = float(w.get("prowl_m", 40.0)) * _snow_x("roam_x") if water == Vector3.INF else float(host._drink_cfg().get("wolf_ring_m", 12.0))

	for m in members:
		if pack["timer"] <= 0.0 or m["pos"].distance_to(m["target"]) < 1.0:
			var angle: float = host.rng.randf() * TAU   # luck-exempt: where a wolf prowls
			m["target"] = centre + Vector3(cos(angle), 0.0, sin(angle)) * host.rng.randf_range(2.0, roam)   # luck-exempt: as above

		_walk(m, m["target"], float(def.get("walk_mps", 2.0)) * _snow_x("speed_x"), dt, infos)

	if pack["timer"] <= 0.0:
		pack["timer"] = host.rng.randf_range(8.0, 20.0)   # luck-exempt: how long between prowl legs


func _stalk(pack: Dictionary, members: Array, c: Vector3, dt: float, infos: Array) -> void:
	var w: Dictionary = cfgw()
	var def: Dictionary = host.species_def("wolf")
	var info: Dictionary = _info_of(infos, int(pack["target"]))

	if info.is_empty() or Vector2(info["pos"].x - c.x, info["pos"].z - c.z).length() > float(w.get("lose_m", 120.0)):
		pack["phase"] = "prowl"
		pack["target"] = -1
		return

	var p: Vector3 = info["pos"]
	var fire: Vector3 = Vector3.INF
	var fire_d: float = 1.0e9

	for f in _fire_cache:
		var d: float = Vector2(f.x - p.x, f.z - p.z).length()

		if d < _fire_m(f) + 3.0 and d < fire_d:
			fire_d = d
			fire = f

	var stalk_m: float = host.fog_stalk_m(float(w.get("stalk_m", 25.0)), p)   # closer in fog, to half the visibility (animals_in_fog_server.md 4.3)

	if fire != Vector3.INF:
		# Circle just outside the firelight, visible at its edge: each wolf on its own bearing, drifting round the fire.
		pack["angle"] += dt * float(w.get("circle_rad_s", 0.12))
		var ring: float = _fire_m(fire) + float(w.get("circle_gap_m", 1.5))

		for k in members.size():
			var ang: float = pack["angle"] + TAU * float(k) / float(members.size())
			var goal: Vector3 = fire + Vector3(cos(ang), 0.0, sin(ang)) * ring
			_walk(members[k], goal, float(def.get("trot_mps", 5.0)) * _snow_x("speed_x"), dt, infos)

		return   # while someone sits in firelight the pack never attacks

	# Shadow the player at stalk_m: close in when farther, hold when near (torch light keeps them out of the shadows' way).
	for k in members.size():
		var m: Dictionary = members[k]
		var ang2: float = pack["angle"] + TAU * float(k) / float(members.size())
		var goal2: Vector3 = p + Vector3(cos(ang2), 0.0, sin(ang2)) * stalk_m
		var d: float = Vector2(m["pos"].x - goal2.x, m["pos"].z - goal2.z).length()

		if d > 2.0:
			_walk(m, goal2, float(def.get("trot_mps", 5.0)) * _snow_x("speed_x"), dt, infos)
		else:
			m["moving"] = false
			m["heading"] = atan2(p.z - m["pos"].z, p.x - m["pos"].x)

	pack["stalk_s"] -= dt

	if pack["stalk_s"] > 0.0:
		return

	# Decide. Attack only a lone player who is hurt, carries raw meat, or was maimed already and is still here.
	var target: int = int(pack["target"])
	var others: int = 0

	for o in infos:
		if int(o["peer"]) != target and Vector2(o["pos"].x - p.x, o["pos"].z - p.z).length() <= float(w.get("group_m", 10.0)):
			others += 1

	var maimed: bool = pack["maimed"].has(target)
	var bold: float = boldness(pack, p)
	var meaty: bool = wants_meat(pack, info)
	var starving: bool = float(pack["hunger"]) >= float(w.get("starving_at", 0.9))
	var hurt_weak: bool = float(info.get("hp", 1.0)) < float(w.get("weak_hp", 0.6)) + bold * float(w.get("den_weak_gain", 0.5)) or maimed
	var weak: bool = hurt_weak or meaty or starving
	var armed: bool = bool(info.get("spear", false)) and float(info.get("hp", 1.0)) >= float(w.get("spear_ignore_hp", 0.3)) and not maimed and bold < float(w.get("den_spear_bold", 0.7))
	var torch: bool = bool(info.get("torch", false)) and not maimed

	if others > 0 or armed or torch or pack["hurt"] or not weak:
		pack["ignore"][target] = _clock + float(w.get("ignore_s", 180.0))
		pack["phase"] = "prowl"
		pack["target"] = -1
		pack["timer"] = 0.0
		return

	pack["phase"] = "rush"
	pack["sprint"] = 0.0
	pack["bite"] = {}
	pack["meat_hits"] = 0
	pack["for_meat"] = meaty and not hurt_weak and not starving   # only after the meat: dropping it ends the attack
	_say_to(target, str(w.get("say_rush", "The wolves are coming for you!")))
	_event("growl", c)


func _rush(pack: Dictionary, members: Array, c: Vector3, dt: float, infos: Array) -> void:
	var w: Dictionary = cfgw()
	var def: Dictionary = host.species_def("wolf")
	var target: int = int(pack["target"])
	var info: Dictionary = _info_of(infos, target)

	if info.is_empty():
		pack["phase"] = "prowl"
		return

	var p: Vector3 = info["pos"]
	var others: int = 0

	for o in infos:
		if int(o["peer"]) != target and Vector2(o["pos"].x - p.x, o["pos"].z - p.z).length() <= float(w.get("group_m", 10.0)):
			others += 1

	var lit_target: bool = lit(p.x, p.z, infos)
	var low: bool = false

	for m in members:
		low = low or float(m["hp"]) < float(def.get("health", 30.0)) * float(w.get("flee_hp_share", 0.4))

	if others > 0 or pack["hurt"] or low or lit_target:
		_retreat(pack, members, c, p, float(w.get("hurt_retreat_s", 45.0)), false)
		return

	# The player dropped the meat (or lost it): a pack that only came for the meat lets go.
	if bool(pack["for_meat"]) and not wants_meat(pack, info) and not pack["maimed"].has(target):
		pack["ignore"][target] = _clock + float(w.get("ignore_s", 180.0))
		_retreat(pack, members, c, p, float(w.get("hurt_retreat_s", 45.0)), false)
		return

	pack["sprint"] += dt
	var speed: float = float(def.get("sprint_mps", 10.5)) if pack["sprint"] <= float(def.get("sprint_s", 5.0)) else float(def.get("chase_mps", 7.0))

	for m in members:
		_walk(m, p, speed, dt, infos)
		var id: int = int(m["id"])
		pack["bite"][id] = float(pack["bite"].get(id, 0.0)) - dt

		if Vector2(m["pos"].x - p.x, m["pos"].z - p.z).length() <= float(w.get("reach_m", 3.0)) and absf(m["pos"].y - p.y) < 3.0 and float(pack["bite"][id]) <= 0.0 and hurt_player.is_valid():
			pack["bite"][id] = float(w.get("bite_every_s", 1.0))
			var result: String = str(hurt_player.call(target, float(w.get("bite", 8.0)) * host.level_x(m, "damage"), pack["maimed"].has(target), "wolves"))   # a higher-level wolf bites harder

			# Meat is the prize: a few bites in, the pack tears it out of the pack and runs (never in a fire's or torch's light).
			if result == "hurt" and bool(pack["for_meat"]) and not lit_target and take_meat.is_valid():
				pack["meat_hits"] = int(pack["meat_hits"]) + 1

				if int(pack["meat_hits"]) >= int(w.get("steal_bites", 3)) and int(take_meat.call(target)) > 0:
					pack["hunger"] = 0.0
					pack["ignore"][target] = _clock + float(w.get("stolen_ignore_s", 900.0))
					_say_to(target, str(w.get("say_stolen", "The wolves tear your meat away and run off with it.")))
					_retreat(pack, members, c, p, float(w.get("hurt_retreat_s", 45.0)), false)
					return

			if result == "maimed":
				pack["maimed"][target] = true
				_retreat(pack, members, c, p, float(w.get("retreat_s", 300.0)), true)
				return

			if result == "dead":
				pack["maimed"].erase(target)
				_retreat(pack, members, c, p, float(w.get("hurt_retreat_s", 45.0)), false)
				return


# Back off away from the victim; `wait` is how long before the pack may come back (a maimed player is remembered).
func _retreat(pack: Dictionary, members: Array, c: Vector3, from: Vector3, wait_s: float, keep_target: bool) -> void:
	var w: Dictionary = cfgw()
	var away: Vector2 = Vector2(c.x - from.x, c.z - from.z)
	away = away.normalized() if away.length() > 0.1 else Vector2.RIGHT
	pack["point"] = c + Vector3(away.x, 0.0, away.y) * float(w.get("retreat_m", 120.0))
	pack["phase"] = "wait"
	pack["timer"] = wait_s
	pack["hurt"] = false

	if not keep_target:
		pack["target"] = -1


func _wait(pack: Dictionary, members: Array, c: Vector3, dt: float, infos: Array) -> void:
	var w: Dictionary = cfgw()
	var def: Dictionary = host.species_def("wolf")

	for k in members.size():
		var m: Dictionary = members[k]
		var spot: Vector3 = pack["point"] + Vector3(cos(float(k)), 0.0, sin(float(k))) * 5.0

		if Vector2(m["pos"].x - spot.x, m["pos"].z - spot.z).length() > 3.0:
			_walk(m, spot, float(def.get("trot_mps", 5.0)) * _snow_x("speed_x"), dt, infos)
		else:
			m["moving"] = false

	if pack["timer"] > 0.0:
		return

	var target: int = int(pack["target"])
	var info: Dictionary = _info_of(infos, target)

	if target < 0 or info.is_empty() or Vector2(info["pos"].x - c.x, info["pos"].z - c.z).length() > float(w.get("return_m", 250.0)):
		pack["maimed"].erase(target)
		pack["phase"] = "prowl"
		pack["target"] = -1
		pack["home"] = c
		return

	# The player is still around: the pack comes back for the kill.
	pack["phase"] = "rush"
	pack["sprint"] = 0.0
	pack["bite"] = {}
	_say_to(target, str(w.get("say_return", "The wolves are back.")))


func _feed(pack: Dictionary, members: Array, c: Vector3, dt: float, infos: Array) -> void:
	var def: Dictionary = host.species_def("wolf")
	var prey_id: int = int(pack["prey"])

	if prey_id != 0 and host.animals.has(prey_id):
		var prey: Dictionary = host.animals[prey_id]

		for m in members:
			_walk(m, prey["pos"], float(def.get("sprint_mps", 10.5)), dt, infos)

		if Vector2(members[0]["pos"].x - prey["pos"].x, members[0]["pos"].z - prey["pos"].z).length() <= float(cfgw().get("reach_m", 3.0)):
			if prey.has("companion_id"):
				# A dog fights back and is bitten, a bite every dog_bite_s, through the one damage hook (its death is the companion's death).
				pack["dog_bite_in"] = float(pack.get("dog_bite_in", 0.0)) - dt

				if float(pack["dog_bite_in"]) <= 0.0:
					pack["dog_bite_in"] = float(cfgw().get("dog_bite_s", 1.0))

					if host.damage(prey_id, float(cfgw().get("dog_bite", 25.0)), -1, "bite") or not host.animals.has(prey_id):
						pack["hunger"] = 0.0
						pack["prey"] = 0

				return

			host.animals.erase(prey_id)   # a wolf kill leaves nothing to dress
			pack["hunger"] = 0.0
			pack["prey"] = 0
		return

	for m in members:
		m["moving"] = false

	if pack["timer"] <= 0.0:
		pack["phase"] = "prowl"
		pack["home"] = c
		pack["timer"] = 0.0


# --- natural packs: one home per 2 km x 2 km cell (about 4 sq km), decided by a hash of the cell ---

func _natural(infos: Array) -> void:
	var w: Dictionary = cfgw()
	var cell_m: float = float(w.get("cell_m", 2000.0))
	var ex: Array = w.get("exclude", [0.0, 0.0, 0.0])
	var active: float = float(host.cfg.get("active_radius_m", 200.0))

	if wolf_count() >= int(w.get("max_wolves", 15)):
		return

	for info in infos:
		var p: Vector3 = info["pos"]

		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var cx: int = int(floor(p.x / cell_m)) + dx
				var cz: int = int(floor(p.z / cell_m)) + dz
				var key: String = "%d,%d" % [cx, cz]
				var rec: Dictionary = cells.get(key, {})

				if int(rec.get("pack", 0)) != 0 and packs.has(int(rec["pack"])):
					continue

				if float(rec.get("dead_until", 0.0)) > _clock:
					continue

				var h: int = hash(key + str(w.get("seed", 7)))
				var home: Vector2 = Vector2((float(cx) + float(absi(h) % 1000) / 1000.0) * cell_m, (float(cz) + float(absi(h / 1000) % 1000) / 1000.0) * cell_m)

				if absi(h / 1000000) % 100 >= int(float(w.get("cell_share", 1.0)) * 100.0):
					continue   # a cell without a pack

				if Vector2(home.x - float(ex[0]), home.y - float(ex[1])).length() < float(ex[2]):
					continue

				if near_town(home.x, home.y):
					continue   # wolves den away from the town (wolf_packs_and_pups_design.md 3)

				if _den_resting(key):
					continue   # a killed pack's den: its orphans live there, or it rests for respawn_s (saved across restarts)

				var d: float = Vector2(home.x - p.x, home.y - p.z).length()

				if d > active or d < float(host.cfg.get("spawn_min_m", 150.0)) * 0.9:
					continue

				var score: float = host._habitat_score(host.species_def("wolf"), home.x, home.y, p.y)

				if score < 0.0:
					continue

				var pid: int = spawn_pack(home.x, home.y)
				cells[key] = {"pack": pid, "dead_until": 0.0}

				if pid != 0:
					packs[pid]["key"] = key
					make_pups(pid)

				return


# --- pups and orphans (docs/design/wolf_packs_and_pups_design.md, Dave 8 Nov 2026 decisions 3 and 4) ---

# Whether a den at (x, z) would be within town_keep_m of the town point: no natural pack lives there (dens lie far from villages:
# Białowieża, Can. J. Zool. 2003).
func near_town(x: float, z: float) -> bool:
	return host.starter.x != INF and Vector2(x - host.starter.x, z - host.starter.y).length() < float(cfgw().get("town_keep_m", 1200.0))


func _now_s() -> float:
	return float(game_seconds.call()) if game_seconds.is_valid() else 0.0


func pup_cfg() -> Dictionary:
	return cfgw().get("pups", {})


# Late spring to about 3 months on (pups.days, day of the year): pups are at the den.
func pup_season() -> bool:
	var days: Array = pup_cfg().get("days", [60, 150])
	var doy: int = int(floorf(_now_s() / DAY_S)) % 365
	return doy >= int(days[0]) and doy <= int(days[1])


# The pack's pups at its den: natural packs in pup season (forced: tests and admin). Returns how many the pack has.
func make_pups(pid: int, forced: bool = false) -> int:
	if not packs.has(pid) or (not forced and not pup_season()):
		return 0

	var pack: Dictionary = packs[pid]
	var span: Array = pup_cfg().get("count", [2, 5])
	var n: int = host.rng.randi_range(int(span[0]), int(span[1]))   # luck-exempt: how many pups in a litter

	for k in n:
		var id: int = _spawn_pup(pack["den"], k)

		if id != 0:
			host.animals[id]["pup_of"] = pid
			pack["pups"].append(id)

	return (pack["pups"] as Array).size()


func _spawn_pup(den: Vector3, k: int) -> int:
	var ang: float = TAU * float(k) / 5.0
	var id: int = host.spawn("wolf", den.x + cos(ang) * 2.0, den.z + sin(ang) * 2.0)

	if id == 0:
		return 0

	var a: Dictionary = host.animals[id]
	a["num"] = int(a["num"]) + int(host.YOUNG_NUM)   # sent as young: the client draws it small
	a["hp"] = float(a["hp"]) * float(pup_cfg().get("hp_x", 0.25))
	a["den_at"] = Vector3(den.x, a["pos"].y, den.z)
	a["young"] = true
	return id


func _live_pups(pack: Dictionary) -> Array:
	var out: Array = []

	for id in pack.get("pups", []):
		if host.animals.has(id) and host.animals[id].has("pup_of"):
			out.append(id)

	return out


func _flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


# A pup (wild or orphan): it keeps within play_m of the den and plays there by day; a player within hide_m who stands or moves sends it
# into the den (HIDDEN: not sent, not hunted); a crouched, still player it lets be.
func step_pup(a: Dictionary, dt: float) -> void:
	var pc: Dictionary = pup_cfg()
	var den: Vector3 = a.get("den_at", a["home"])
	var scared: bool = false

	for info in (player_info.call() if player_info.is_valid() else []):
		if _flat(info["pos"], den) <= float(pc.get("hide_m", 25.0)) and (int(info.get("stance", 0)) == 0 or float(_peer_speed.get(info["peer"], 0.0)) > 0.3):
			scared = true

	if scared:
		a["state"] = host.HIDDEN
		a["pos"] = den
		a["timer"] = 5.0
		a["playing"] = false
		return

	a["timer"] = float(a["timer"]) - dt

	if int(a["state"]) == host.HIDDEN and float(a["timer"]) > 0.0:
		return   # it waits a little before it comes out again

	if float(a["timer"]) <= 0.0:
		var ang: float = host.rng.randf() * TAU   # luck-exempt: where a pup potters
		a["target"] = den + Vector3(cos(ang), 0.0, sin(ang)) * host.rng.randf_range(0.5, float(pc.get("play_m", 8.0)))   # luck-exempt: as above
		a["timer"] = host.rng.randf_range(4.0, 10.0)   # luck-exempt: how long until it moves on
		a["playing"] = (not is_day.is_valid() or bool(is_day.call())) and host.rng.randf() < 0.4   # luck-exempt: whether it plays

	if bool(a.get("playing", false)):
		a["state"] = PLAY
		return

	var r: Dictionary = Steering.step(a["pos"], a["target"], 1.0, dt, host.ground_height, host.blocked, 0.4, a["heading"], host.crossing)

	if r["moved"]:
		a["pos"] = r["pos"]
		a["heading"] = r["heading"]

	a["state"] = host.HOP if r["moved"] else host.GRAZE


# A player near the den while the pups are there: the pack comes home and warns (den_guard).
func _guard_check(pack: Dictionary, infos: Array) -> void:
	if _live_pups(pack).is_empty():
		return

	for info in infos:
		if _flat(info["pos"], pack["den"]) <= float(pup_cfg().get("guard_m", 40.0)):
			pack["phase"] = "den_guard"
			pack["target"] = int(info["peer"])
			pack["timer"] = float(pup_cfg().get("warn_s", 3.0))
			pack["guard_rush"] = false
			_event("growl", pack["den"])
			_say_to(int(info["peer"]), str(pup_cfg().get("say_warn", "Wolves snarl at you from near their den.")))
			return


# A pup hurt: its pack comes at the one who did it at once.
func pup_hurt(a: Dictionary, peer: int) -> void:
	var pack: Dictionary = packs.get(int(a.get("pup_of", 0)), {})

	if pack.is_empty() or peer < 0:
		return

	pack["phase"] = "den_guard"
	pack["target"] = peer
	pack["timer"] = 0.0
	pack["guard_rush"] = true
	pack["sprint"] = 0.0
	pack["bite"] = {}
	_event("growl", pack["den"])


# Placed fires only: a torch bearer's own light does not hold a pack at its den (the torch rule is lifted there; a campfire still holds).
func fire_lit(x: float, z: float, infos: Array) -> bool:
	for f in _fire_cache:
		var bearer: bool = false

		for info in infos:
			bearer = bearer or (bool(info.get("torch", false)) and _flat(info["pos"], f) <= 1.5)

		if not bearer and Vector2(f.x - x, f.z - z).length() < _fire_m(f):
			return true

	return false


func _walk_den(m: Dictionary, goal: Vector3, speed: float, dt: float, infos: Array) -> void:
	var host_blocked: Callable = host.ice_blocked(host.blocked, host.ice_mass("wolf")) if host.ice_on() and not is_nan(host.ice_mass("wolf")) else host.blocked
	var ground: Callable = host.ice_ground(host.ground_height, host.ice_mass("wolf")) if host.ice_on() and not is_nan(host.ice_mass("wolf")) else host.ground_height
	var me = self
	var shy: Callable = func(x, z): return (host_blocked.is_valid() and bool(host_blocked.call(x, z))) or me.fire_lit(x, z, infos)
	var r: Dictionary = Steering.step(m["pos"], goal, speed, dt, ground, shy, 0.5, m["heading"], host.crossing)
	m["moving"] = bool(r["moved"])

	if r["moved"]:
		m["pos"] = r["pos"]
		m["heading"] = r["heading"]


# The den guard: the pack stands between the den and the player for warn_s (circling, growling); a player who backs out past guard_m
# ends it; one still within rush_m after the warning is rushed, torch or not. A campfire by the player and a second player still hold it.
func _den_guard(pack: Dictionary, members: Array, c: Vector3, dt: float, infos: Array) -> void:
	var w: Dictionary = cfgw()
	var pc: Dictionary = pup_cfg()
	var def: Dictionary = host.species_def("wolf")
	var target: int = int(pack["target"])
	var info: Dictionary = _info_of(infos, target)
	var den: Vector3 = pack["den"]

	if info.is_empty() or _live_pups(pack).is_empty():
		_end_guard(pack)
		return

	var p: Vector3 = info["pos"]
	var d: float = _flat(p, den)

	if d > float(pc.get("guard_m", 40.0)) + 5.0:
		_end_guard(pack)   # backed off: it is over
		return

	var others: int = 0

	for o in infos:
		if int(o["peer"]) != target and _flat(o["pos"], p) <= float(w.get("group_m", 10.0)):
			others += 1

	var low: bool = false

	for m in members:
		low = low or float(m["hp"]) < float(def.get("health", 30.0)) * float(w.get("flee_hp_share", 0.4))

	var held: bool = fire_lit(p.x, p.z, infos)

	if others > 0 or low:
		pack["guard_rush"] = false
		_retreat(pack, members, c, p, float(w.get("hurt_retreat_s", 45.0)), false)
		return

	if not bool(pack.get("guard_rush", false)):
		var toward: Vector2 = Vector2(p.x - den.x, p.z - den.z).normalized()
		var side: Vector2 = Vector2(-toward.y, toward.x)

		for k in members.size():
			var spot: Vector2 = Vector2(den.x, den.z) + toward * minf(d * 0.5, 10.0) + side * (float(k) - float(members.size() - 1) * 0.5) * 2.5
			var m: Dictionary = members[k]

			if _flat(m["pos"], Vector3(spot.x, 0.0, spot.y)) > 1.0:
				_walk_den(m, Vector3(spot.x, m["pos"].y, spot.y), float(def.get("sprint_mps", 10.5)), dt, infos)
			else:
				m["moving"] = false
				m["heading"] = atan2(p.z - m["pos"].z, p.x - m["pos"].x)

		if float(pack["timer"]) <= 0.0 and d <= float(pc.get("rush_m", 25.0)) and not held:
			pack["guard_rush"] = true
			pack["sprint"] = 0.0
			pack["bite"] = {}
			_say_to(target, str(w.get("say_rush", "The wolves are coming for you!")))
			_event("growl", c)

		return

	if held or d > float(pc.get("rush_m", 25.0)) + 10.0:
		pack["guard_rush"] = false   # beside a campfire, or well back: it goes back to warning
		pack["timer"] = float(pc.get("warn_s", 3.0))
		return

	pack["sprint"] = float(pack.get("sprint", 0.0)) + dt
	var speed: float = float(def.get("sprint_mps", 10.5)) if float(pack["sprint"]) <= float(def.get("sprint_s", 5.0)) else float(def.get("chase_mps", 7.0))

	for m in members:
		_walk_den(m, p, speed, dt, infos)
		var id: int = int(m["id"])
		pack["bite"][id] = float(pack["bite"].get(id, 0.0)) - dt

		if _flat(m["pos"], p) <= float(w.get("reach_m", 3.0)) and absf(m["pos"].y - p.y) < 3.0 and float(pack["bite"][id]) <= 0.0 and hurt_player.is_valid():
			pack["bite"][id] = float(w.get("bite_every_s", 1.0))
			var result: String = str(hurt_player.call(target, float(w.get("bite", 8.0)) * host.level_x(m, "damage"), pack["maimed"].has(target), "wolves"))

			if result == "maimed" or result == "dead":
				if result == "maimed":
					pack["maimed"][target] = true

				pack["guard_rush"] = false
				_retreat(pack, members, c, p, float(w.get("hurt_retreat_s", 45.0)), false)
				return


func _end_guard(pack: Dictionary) -> void:
	pack["phase"] = "prowl"
	pack["target"] = -1
	pack["guard_rush"] = false
	pack["timer"] = 0.0


# The last adult of a pack died: its pups at the den are orphans (decision 3: only a killed pack leaves orphans). The den stays empty of
# packs while they live; with no pups it rests for respawn_s. Both are saved.
func _orphan(pack: Dictionary) -> void:
	var key: String = str(pack.get("key", ""))
	var pups: Array = _live_pups(pack)

	if pups.is_empty():
		dens[key] = {"rest_until_s": _now_s() + float(cfgw().get("respawn_s", 7200.0)) * GAME_PER_REAL}
		_dens_dirty = true
		return

	var den: Vector3 = host.animals[pups[0]].get("den_at", pack["den"])
	dens[key] = {"rest_until_s": 0.0, "orphan": {"den": [den.x, den.y, den.z], "pups": pups.size(), "since_s": _now_s(), "trust": {}}}

	for id in pups:
		host.animals[id].erase("pup_of")
		host.animals[id]["orphan"] = key

	_dens_dirty = true


func orphan_of(a: Dictionary) -> Dictionary:
	return dens.get(str(a.get("orphan", "")), {}).get("orphan", {})


func _den_resting(key: String) -> bool:
	var rec: Dictionary = dens.get(key, {})

	if rec.is_empty():
		return false

	if rec.has("orphan"):
		var o: Dictionary = rec["orphan"]

		if _now_s() < float(o["since_s"]) + float(cfgw().get("orphan_days", 5.0)) * DAY_S and int(o["pups"]) > 0:
			return true

		_end_orphans(key)
		return true

	return _now_s() < float(rec.get("rest_until_s", 0.0))


# The orphans of a den are gone (all taken or lost, or orphan_days passed): the den rests for respawn_s.
func _end_orphans(key: String) -> void:
	for id in host.animals.keys():
		if str(host.animals[id].get("orphan", "")) == key:
			host.animals.erase(id)

	dens[key] = {"rest_until_s": _now_s() + float(cfgw().get("respawn_s", 7200.0)) * GAME_PER_REAL}
	_dens_dirty = true


# One orphan fewer: tamed (taken) or killed (lost).
func orphan_gone(a: Dictionary) -> void:
	var key: String = str(a.get("orphan", ""))
	var o: Dictionary = orphan_of(a)
	a.erase("orphan")

	if o.is_empty():
		return

	o["pups"] = int(o["pups"]) - 1
	_dens_dirty = true

	if int(o["pups"]) <= 0:
		_end_orphans(key)


var _orphan_acc: float = 99.0


# Once a second: orphans past orphan_days are gone; a player near an orphans' den finds them there (made again from the record); dirty dens
# are saved.
func _tend_orphans(infos: Array, delta: float) -> void:
	_orphan_acc += delta

	if _orphan_acc < 1.0:
		return

	_orphan_acc = 0.0
	var active: float = float(host.cfg.get("active_radius_m", 200.0))

	for key in dens.keys():
		if not dens.has(key) or not dens[key].has("orphan"):
			continue

		var o: Dictionary = dens[key]["orphan"]

		if _now_s() >= float(o["since_s"]) + float(cfgw().get("orphan_days", 5.0)) * DAY_S:
			_end_orphans(key)
			continue

		var den: Vector3 = Vector3(float(o["den"][0]), float(o["den"][1]), float(o["den"][2]))
		var near: bool = false

		for info in infos:
			near = near or _flat(info["pos"], den) <= active

		if not near:
			continue

		var live: int = 0

		for id in host.animals:
			live += 1 if str(host.animals[id].get("orphan", "")) == key else 0

		for k in range(live, int(o["pups"])):
			var id: int = _spawn_pup(den, k)

			if id != 0:
				host.animals[id]["orphan"] = key

	if _dens_dirty:
		save_dens()


func save_dens() -> void:
	_dens_dirty = false

	if store_dir != "":
		ItemsScript._write_file(store_dir + "/" + DENS_FILE, JSON.stringify({"version": 1, "dens": dens}, "\t"))


func load_dens() -> void:
	if store_dir == "" or not FileAccess.file_exists(store_dir + "/" + DENS_FILE):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(store_dir + "/" + DENS_FILE))

	if typeof(parsed) == TYPE_DICTIONARY:
		dens = parsed.get("dens", {})
