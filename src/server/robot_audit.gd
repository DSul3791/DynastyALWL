extends Node

# The server half of the robot play-testers (--robot-audit; tools/robots.sh, tools/robot_check.py; 23 Nov 2026).
# Build 9257's first hour on Dave's server found faults no one-machine test had: animals teleporting and passing through players,
# the pack not updating after a queued craft. With this flag the server prints what it believes, so tools/robot_check.py can hold each
# robot client's view against it:
#   AUDIT pack <peer> <unix ms> <signature> <slots used>   the pack's signature each time it changes (looked at every 0.25 s)
#   AUDIT reject <peer> <unix ms> <reason>                   each refusal sent (reject())
#   AUDIT jump <animal id> <species> <unix ms> <metres> <seconds> <from> <to>   an animal that moved farther in one step than its top speed allows
#   AUDIT inside <animal id> <species> <peer> <unix ms> <metres>   an animal's middle inside a player's capsule (closer than INSIDE_M, level with them)
#   AUDIT jump_detail / jump_after <animal id> ...   with a jump: its looks before and after, its accumulated step time, the longest frame
#   AUDIT wolfpack <pack id> <unix ms> <phase> <target peer> <n> wolves   a wolf pack's phase or target changed
#   AUDIT strike <peer> <unix ms> reach seen present judged ... target, hit or miss, the nearest animal then and now   each melee blow at an animal
#   AUDIT enemy_hit <peer> <unix ms> <cause[/weapon]> from <x,z> player <x,z> gap <m> result <hurt|maimed|...> shield <share>   each goblin,
#     bandit or big game blow at a player (hurt_player / hurt_armed wrapped)
#   AUDIT snare <id> ...   each snare set, with its trail share
#   AUDIT where <animal id> <species> <unix ms> <x> <z> <state>   plan kind_ only, after its control command
#   AUDIT stuck <animal id> <species> <unix ms> <x> <z> <state> to <m> ahead <wall|water|steep|animal|player|fire|none>   an animal near a
#     player with somewhere to go (its target STUCK_TARGET_M or more off) that kept within STUCK_M of one spot for STUCK_S; AUDIT stuck_end
#     <animal id> <species> <unix ms> <seconds> when it gets going again or is gone; AUDIT near <unix ms> <species>:<mean> ... span_s:<s>
#     every NEAR_EVERY_S of real time, the mean number of animals near a player by kind over that span (how long each kind was watched: tools/robot_stuck.py counts stuck per game day)
#   AUDIT control <unix ms> <command>   a robot's server_control.txt command done (plan cold): the only place this node changes the game
#   AUDIT chest <world id> <unix ms> <signature> <slots used>   each container's contents when they change (looked at every 0.25 s)
#   AUDIT total <unix ms> <item>:<count> ...   after control "count <x> <z> <item> ...": how many of each there are in every pack and container
#     and loose on the ground within COUNT_M of x, z, together, when that changes (plan pack_fuzz: nothing doubled or lost, tools/robot_check.py)
# No protocol change, and with the flag off this node is never made.

const RobotRules := preload("res://src/shared/robot_rules.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")
const Steering := preload("res://src/shared/steering.gd")
const SIG_EVERY_S := 0.25
const ANIMAL_EVERY_S := 0.1
const INSIDE_M := 0.35          # a player capsule's radius is about 0.35 m; an animal's middle this close stands inside it
const JUMP_SLACK := 1.6         # an animal step may run this much over its top speed (a lunge, a server hitch) before it counts as a jump
const JUMP_FLOOR_M := 2.5       # steps shorter than this never count (a turn, a settle onto the ground)
const STEP_CAP_S := 1.0         # an animal steps at least once a second near a player (hz_mid 3); a longer still spell gives no allowance
const STUCK_S := 6.0            # an animal with somewhere to go that keeps within STUCK_M of one spot this long is stuck (animals thread,
const STUCK_M := 0.5            # coordinator 23 Nov 2026: stuck against walls, fences, rocks, steep ground, water, each other, in fires)
const STUCK_TARGET_M := 2.0
# Standing there is the behaviour, with an old target kept (gate review of #1793): alert (server_animals ALERT, a grazer watching a player
# in its alert ring), hidden, a wolf rolling or playing (server_wolves ROLL, PLAY), warning, recovering, sneaking, jaw-pop, a companion
# sitting, lying (companions and grazers), a camp bandit sitting or asleep (server_bandits SIT, LIE).
const STILL_STATES := [3, 5, 8, 9, 10, 12, 13, 16, 18, 19, 23, 24]
const PACK_MOVING := ["prowl", "stalk", "rush"]   # a pack wolf's target is kept only in these phases (server_wolves.gd); waiting, feeding or guarding its den it stands
const NEAR_EVERY_S := 60.0

var items          # server_items.gd
var animals        # server_animals.gd

var _sig: Dictionary = {}        # peer -> last printed signature
var _sig_t: float = 0.0
var _animal_t: float = 0.0
var _last: Dictionary = {}       # animal id -> [pos, unix ms]
var _trail: Dictionary = {}      # animal id -> its last few looks "ms:x,z:state" (printed with a jump, and the looks after it)
var _after: Dictionary = {}      # animal id -> looks still to print after a jump
var _frame_max: float = 0.0      # the longest server frame since the last animal look
var _top_mps: Dictionary = {}    # species number -> fastest _mps in animals.json
var _names: Dictionary = {}      # species number -> name
var _snares_seen: Dictionary = {}  # world item id -> true: each snare set is printed once with how much trail it sits on
var _pack_phase: Dictionary = {}  # wolf pack id -> "phase target" last printed
var _control_t: float = 0.0
var _chest_sig: Dictionary = {}   # container world id -> its contents' signature last printed (AUDIT chest)
var _where_sp: int = -1           # plan kind_ (control "where <species number>"): every WHERE_EVERY_S, the server's own place of each of that species
var _where_t: float = 0.0
const WHERE_EVERY_S := 0.5
var _cold: bool = false            # plan cold: the weather the server's vitals read is a hard frost (control file)
var _stuck: Dictionary = {}       # animal id -> [spot Vector3, unix ms there since, printed stuck]
var _near_from: int = -1         # unix ms the AUDIT near span began
var _near_looks: int = 0          # looks in the span (each ANIMAL_EVERY_S or a frame later)
var _near_count: Dictionary = {}  # species name -> animals near a player at the last look
var _count_ids: PackedStringArray = PackedStringArray()   # control "count": the items whose totals are printed
var _total_said: String = ""
var _count_at: Vector2 = Vector2.ZERO   # loose items count within COUNT_M of here (the robots' spot), not the whole world's natural ones
const COUNT_M := 40.0


func setup(server_items, server_animals) -> void:
	items = server_items
	animals = server_animals
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))

	if cfg is Dictionary:
		for sp in cfg.get("species", {}):
			var row: Dictionary = cfg["species"][sp]
			var top: float = RobotRules.top_speed(row)

			_top_mps[int(row.get("number", 0))] = top
			_names[int(row.get("number", 0))] = str(sp)

	var reject: Callable = items.send_reject
	items.send_reject = func(peer, reason):
		reject.call(peer, reason)
		print("AUDIT reject %d %d %d" % [int(peer), RobotRules.now_ms(), int(reason)])
	_wrap_hits.call_deferred()   # items.hit_animal is set after this setup (terrain_server.gd)
	_wrap_enemy.call_deferred()
	print("AUDIT on: robot audit lines follow (src/server/robot_audit.gd)")


func _process(delta: float) -> void:
	if items == null:
		return

	_sig_t += delta

	if _sig_t >= SIG_EVERY_S:
		_sig_t = 0.0

		for peer in items.peer_ids():
			var inv = items.inventory_of(int(peer))
			var sig: String = RobotRules.signature(inv)

			if _sig.get(peer, "") != sig:
				_sig[peer] = sig
				print("AUDIT pack %d %d %s %d" % [int(peer), RobotRules.now_ms(), sig, RobotRules.used(inv)])

		_containers()

	_control_t += delta

	if _control_t >= 0.5:
		_control_t = 0.0
		_read_control()

	_where_t += delta

	if _where_sp >= 0 and animals != null and _where_t >= WHERE_EVERY_S:
		_where_t = 0.0
		var ms: int = RobotRules.now_ms()

		for id in animals.animals:
			var w: Dictionary = animals.animals[id]

			if RobotRules.species_of(int(w.get("num", 0))) == _where_sp:
				print("AUDIT where %d %d %d %.2f %.2f %d" % [int(id), _where_sp, ms, (w["pos"] as Vector3).x, (w["pos"] as Vector3).z, int(w.get("state", 0))])

	_animal_t += delta
	_frame_max = maxf(_frame_max, delta)

	if animals == null or _animal_t < ANIMAL_EVERY_S:
		return

	_animal_t = 0.0
	var now: int = RobotRules.now_ms()
	_wolf_packs(now)
	_snares(now)
	var players: Array = []

	for peer in items.peer_ids():
		var at: Variant = items.position_of(int(peer))

		if at != null:
			players.append([int(peer), at])

	var seen: Dictionary = {}
	_near_looks += 1

	for id in animals.animals:
		var a: Dictionary = animals.animals[id]
		var pos: Vector3 = a["pos"]
		var num: int = RobotRules.species_of(int(a.get("num", 0)))
		seen[id] = true

		# Only the animals near a player matter (the far ones are moved in big coarse steps by design).
		var near: bool = false

		for p in players:
			var d: float = Vector2(pos.x - p[1].x, pos.z - p[1].z).length()

			if d < 150.0:
				near = true

			if d < INSIDE_M and absf(pos.y - p[1].y) < 1.6 and int(a.get("state", 0)) != animals.HIDDEN:
				print("AUDIT inside %d %s %d %d %.2f" % [int(id), str(_names.get(num, num)), int(p[0]), now, d])

		_stuck_look(int(id), a, pos, num, near, players, now)

		if near:
			var nm: String = str(_names.get(num, num))
			_near_count[nm] = int(_near_count.get(nm, 0)) + 1

		# Measured from its last change of place, not from the last look: an animal farther off, or one the tick budget skipped, steps
		# less often and further each time (server_animals.gd hz_near, hz_mid, tick_budget_ms).
		if not _last.has(id):
			_last[id] = [pos, now, int(a.get("moved_ms", -1))]
		elif pos != _last[id][0]:
			var was: Array = _last[id]
			# The server's own step times (moved_ms) when it keeps them: an animal far off steps every 1/hz with its whole accumulated time,
			# which the looks may halve (animals thread, 23 Nov 2026); else the time between looks. Capped: a rest is not credit for a jump.
			var moved: int = int(a.get("moved_ms", -1))
			var span_ms: int = moved - int(was[2]) if moved > 0 and int(was[2]) > 0 and moved > int(was[2]) else now - int(was[1])
			var dt: float = clampf(float(span_ms) / 1000.0, 0.05, STEP_CAP_S)
			var step: float = Vector2(pos.x - was[0].x, pos.z - was[0].z).length()
			var allowed: float = float(_top_mps.get(num, 15.0)) * dt * JUMP_SLACK

			if near and step > maxf(allowed, JUMP_FLOOR_M) and int(a.get("state", 0)) != animals.HIDDEN:
				print("AUDIT jump %d %s %d %.1f %.2f %s %s state %d" % [int(id), str(_names.get(num, num)), now, step, dt, str(was[0].round()), str(pos.round()), int(a.get("state", 0))])
				# For the animals thread: the looks before (every ANIMAL_EVERY_S, server unix ms:x,z:state), its accumulated step time (acc),
				# the longest server frame since the last look, and (AUDIT jump_after) the next three looks.
				print("AUDIT jump_detail %d before %s acc %.3f moved_ms %d longest frame %.0f ms" % [int(id), " ".join(_trail.get(id, [])), float(a.get("acc", -1.0)),
					int(a.get("moved_ms", -1)), _frame_max * 1000.0])
				_after[id] = 3

			_last[id] = [pos, now, int(a.get("moved_ms", -1))]

		var look: String = "%d:%.1f,%.1f:%d" % [now, pos.x, pos.z, int(a.get("state", 0))]
		var looks: Array = _trail.get(id, [])
		looks.append(look)

		while looks.size() > 3:
			looks.pop_front()

		_trail[id] = looks

		if int(_after.get(id, 0)) > 0:
			_after[id] = int(_after[id]) - 1
			print("AUDIT jump_after %d %s acc %.3f" % [int(id), look, float(a.get("acc", -1.0))])

	_frame_max = 0.0

	for id in _last.keys():
		if not seen.has(id):
			_last.erase(id)
			_trail.erase(id)
			_after.erase(id)

	for id in _stuck.keys():
		if not seen.has(id):
			_end_stuck(int(id), now)

	if _near_from < 0:
		_near_from = now

	if now - _near_from >= int(NEAR_EVERY_S * 1000.0):
		var parts: Array = []

		for nm in _near_count:
			parts.append("%s:%.2f" % [nm, float(_near_count[nm]) / float(maxi(_near_looks, 1))])   # the mean near over the looks of that span

		parts.append("span_s:%.1f" % (float(now - _near_from) / 1000.0))
		_near_from = now
		_near_looks = 0

		print("AUDIT near %d %s" % [now, " ".join(parts)])
		_near_count.clear()


# An animal near a player that has somewhere to go (target STUCK_TARGET_M or more off) but has kept within STUCK_M of one spot for STUCK_S
# prints AUDIT stuck once, with what lies a metre and a half toward its target; AUDIT stuck_end when it moves on, stops wanting to, or is gone.
func _stuck_look(id: int, a: Dictionary, pos: Vector3, num: int, near: bool, players: Array, now: int) -> void:
	var target: Vector3 = a.get("target", pos)
	var to: Vector2 = Vector2(target.x - pos.x, target.z - pos.z)
	var free: bool = not near or to.length() < STUCK_TARGET_M or STILL_STATES.has(int(a.get("state", 0))) or a.has("fly") \
		or bool(a.get("perched", false)) or bool(a.get("in_cave", false)) or a.has("bound_by") or not _pack_moving(a)
	var w: Array = _stuck.get(id, [])

	if free or w.is_empty() or Vector2(pos.x - w[0].x, pos.z - w[0].z).length() > STUCK_M:
		_end_stuck(id, now)   # prints only for a spell that was printed

		if not free:
			_stuck[id] = [pos, now, false, str(_names.get(num, num))]

		return

	if not bool(w[2]) and now - int(w[1]) >= int(STUCK_S * 1000.0):
		w[2] = true
		var ahead: Vector3 = pos + Vector3(to.x, 0.0, to.y).normalized() * 1.5
		print("AUDIT stuck %d %s %d %.2f %.2f %d to %.1f ahead %s" % [id, str(w[3]), now, pos.x, pos.z, int(a.get("state", 0)), to.length(), _ahead_of(id, a, pos, ahead, players)])


# A pack wolf whose pack is prowling, stalking or rushing (its target kept); true for any animal not in a pack.
func _pack_moving(a: Dictionary) -> bool:
	var wolves = animals.get("wolves")

	if not a.has("pack") or wolves == null or not (wolves.packs as Dictionary).has(a["pack"]):
		return true

	return PACK_MOVING.has(str(wolves.packs[a["pack"]].get("phase", "")))


func _end_stuck(id: int, now: int) -> void:
	var w: Array = _stuck.get(id, [])

	if not w.is_empty() and bool(w[2]):
		print("AUDIT stuck_end %d %s %d %.1f" % [id, str(w[3]), now, float(now - int(w[1])) / 1000.0])

	_stuck.erase(id)


# What stands between a stuck animal and its way (the first that fits): a wall or station, deep water, a rise steeper than a walker climbs
# (Steering.MAX_SLOPE), another
# animal or a player at its body, a fire it keeps from; "none" when nothing here explains it (a steering fault).
func _ahead_of(id: int, a: Dictionary, pos: Vector3, ahead: Vector3, players: Array) -> String:
	if animals.wall_between(pos, ahead):
		return "wall"

	if animals.blocked.is_valid() and bool(animals.blocked.call(ahead.x, ahead.z)):
		return "water"

	if animals.ground_height.is_valid() and absf(float(animals.ground_height.call(ahead.x, ahead.z)) - pos.y) > Steering.MAX_SLOPE * 1.5:   # up or down: Steering refuses both
		return "steep"

	var body: float = AnimalContact.body_m(str(a.get("sp", "")))

	for other in animals.animals:
		if int(other) != id:
			var o: Vector3 = animals.animals[other]["pos"]

			if Vector2(o.x - ahead.x, o.z - ahead.z).length() < body + AnimalContact.body_m(str(animals.animals[other].get("sp", ""))) and absf(o.y - pos.y) < 2.0:
				return "animal"

	for p in players:
		if Vector2(p[1].x - pos.x, p[1].z - pos.z).length() < AnimalContact.contact_m(str(a.get("sp", ""))) + 1.0:
			return "player"

	if animals.fires.is_valid():
		for f in animals.fires.call():
			var keep: float = float(animals.fire_radius.call(f)) if animals.fire_radius.is_valid() else 5.0

			if Vector2(f.x - ahead.x, f.z - ahead.z).length() < keep:
				return "fire"

	return "none"


# Each wolf pack's phase and target when it changes (server_wolves.gd: prowl, stalk, rush, wait, feed, den_guard): the robots' wolf fight
# (plan wolves) reads when a rush began and ended.
func _wolf_packs(now: int) -> void:
	var wolves = animals.get("wolves")

	if wolves == null:
		return

	for pid in wolves.packs:
		var pack: Dictionary = wolves.packs[pid]
		var said: String = "%s %d" % [str(pack.get("phase", "")), int(pack.get("target", -1))]

		if _pack_phase.get(pid, "") != said:
			_pack_phase[pid] = said
			print("AUDIT wolfpack %d %d %s %d wolves" % [int(pid), now, said, (pack.get("ids", []) as Array).size()])


# Every melee blow at an animal and what it struck: `AUDIT strike <peer> <ms> <reach> <seen ms> <target id or 0> <its distance then>`.
func _wrap_hits() -> void:
	var hit: Callable = items.hit_animal

	if not hit.is_valid():
		print("AUDIT strike off: items.hit_animal is not set, melee blows are not audited")
		return

	items.hit_animal = func(peer, origin, dir, reach, amount):
		var seen: Array = items.strike_seen.get(peer, [-1, -1])
		var target: int = animals.target_along(origin, dir, reach, int(seen[0]), int(seen[1]))
		var answer: Variant = hit.call(peer, origin, dir, reach, amount)
		var judged_at: PackedStringArray = PackedStringArray()   # animals within 40 m: id:x,z at the judged moment, then now
		var near: float = INF        # the nearest animal now
		var then: float = INF        # the nearest at the moment the blow is judged (the place target_along uses)
		var judged: int = -1

		for id in animals.animals:
			var a: Dictionary = animals.animals[id]
			near = minf(near, Vector2(a["pos"].x - origin.x, a["pos"].z - origin.z).length())
			var j: int = animals.judged_ms(a, int(seen[0]), int(seen[1]))
			var at: Vector3 = animals.pos_at(a, j)
			var d: float = Vector2(at.x - origin.x, at.z - origin.z).length()

			if d < 40.0:
				judged_at.append("%d:%.1f,%.1f/%.1f,%.1f" % [int(id), at.x, at.z, a["pos"].x, a["pos"].z])

			if d < then:
				then = d
				judged = j

		print("AUDIT strike %d %d reach %.1f seen %d present %d judged %d (server now %d) target %d %s, nearest judged %.2f m, now %.2f m; judged/now %s" % [int(peer), RobotRules.now_ms(), float(reach),
			int(seen[0]), int(seen[1]), judged, Time.get_ticks_msec(), target, "hit" if (answer is Dictionary and not (answer as Dictionary).is_empty()) or (answer is bool and answer) else "miss", then, near, " ".join(judged_at)])
		return answer


# Each blow a charging foe lands (server_big_game.gd: moose, bear, goblin, bandit): `AUDIT enemy_hit <peer> <unix ms> <species> from <x>,<z>
# player <x>,<z> gap <m> result <hurt|maimed|dead|...>`, the server's own distance at the landing (robot plans fight_goblin, fight_bandit).
func _wrap_enemy() -> void:
	var bg = animals.big_game

	if bg == null or not bg.hurt_player.is_valid():
		print("AUDIT enemy_hit off: big_game.hurt_player is not set")
		return

	var say := func(peer, cause, from: Vector3, answer, shield: float) -> void:
		var p: Vector3 = Vector3.INF

		for info in (bg.player_info.call() if bg.player_info.is_valid() else []):
			if int(info["peer"]) == int(peer):
				p = info["pos"]

		var gap: float = Vector2(p.x - from.x, p.z - from.z).length() if p.is_finite() and from.is_finite() else -1.0
		print("AUDIT enemy_hit %d %d %s from %.1f,%.1f player %.1f,%.1f gap %.2f result %s shield %.2f" % [int(peer), RobotRules.now_ms(), str(cause), from.x, from.z, p.x, p.z, gap, str(answer), shield])
	var shield_of := func(peer, from: Vector3) -> float:   # read before the blow: a shield it breaks reads 0 after it
		return float(items.shield_share(int(peer), from)) if items.has_method("shield_share") else -1.0
	var hurt: Callable = bg.hurt_player
	bg.hurt_player = func(peer, amount, lethal, cause, from):
		var shield: float = shield_of.call(peer, from)
		var answer: Variant = hurt.call(peer, amount, lethal, cause, from)
		say.call(peer, cause, from, answer, shield)
		return answer

	if bg.hurt_armed.is_valid():   # an armed bandit's blow goes this way (server_big_game.gd: the weapon's damage mode)
		var armed: Callable = bg.hurt_armed
		bg.hurt_armed = func(peer, amount, lethal, cause, from, weapon):
			var shield: float = shield_of.call(peer, from)
			var answer: Variant = armed.call(peer, amount, lethal, cause, from, weapon)
			say.call(peer, str(cause) + "/" + str(weapon), from, answer, shield)
			return answer


# Robot runs only (plan cold): tools/robots.sh gives the server ROBOT_SHARE; a robot writes server_control.txt there, one command per line:
#   cold <peer>             the weather turns to -25 C with wind (weather_now and weather_at, which the warmth reads; every player on
#                           this server), and that peer starts at health 6, warmth 15 (cold hurts)
#   warm <peer>             the weather is the world's own again
#   health <peer> <value>   that peer's health is set, at least 1 (the 1-health floor under blows)
#   where <species number>  from now on, every 0.5 s: AUDIT where <animal id> <species> <unix ms> <x> <z> <state> for each of that species
#                           (plan kind_: where the server has the animal between blows; tools/robot_kinds.py)
# Each command is done once and printed as AUDIT control; the file is then emptied. Nothing of this exists without --robot-audit.
var _weather_was: Array = []      # [weather_now, weather_at] before the cold


func _read_control() -> void:
	var share: String = OS.get_environment("ROBOT_SHARE")

	if share == "" or not FileAccess.file_exists(share.path_join("server_control.txt")):
		return

	var text: String = FileAccess.get_file_as_string(share.path_join("server_control.txt")).strip_edges()

	if text == "":
		return

	var f: FileAccess = FileAccess.open(share.path_join("server_control.txt"), FileAccess.WRITE)

	if f != null:
		f.store_string("")
		f.close()

	for line in text.split("\n"):
		var p: PackedStringArray = line.strip_edges().split(" ")
		var peer: int = int(p[1]) if p.size() > 1 else 0
		var v: Dictionary = items.vitals_of(peer) if peer != 0 else {}

		if p[0] == "cold" and not v.is_empty():
			if not _cold:
				_cold = true
				var now_was: Callable = items.weather_now
				var at_was: Callable = items.weather_at
				_weather_was = [now_was, at_was]
				items.weather_now = func():
					return _frost((now_was.call() if now_was.is_valid() else {}) as Dictionary)
				items.weather_at = func(pos: Vector3):
					return _frost((at_was.call(pos) if at_was.is_valid() else (now_was.call() if now_was.is_valid() else {})) as Dictionary)

			v["health"] = 6.0
			v["warmth"] = 15.0
			items._sync_vitals(peer, true)
		elif p[0] == "warm" and not v.is_empty():
			if _cold:
				_cold = false
				items.weather_now = _weather_was[0]
				items.weather_at = _weather_was[1]

			v["warmth"] = maxf(float(v.get("warmth", 0.0)), 60.0)
			items._sync_vitals(peer, true)
		elif p[0] == "count" and p.size() > 3 and p[1].is_valid_float() and p[2].is_valid_float():
			_count_at = Vector2(float(p[1]), float(p[2]))
			_count_ids = p.slice(3)
			_total_said = ""
		elif p[0] == "where" and p.size() > 1 and p[1].is_valid_int():
			_where_sp = int(p[1])   # a species number, not a peer
		elif p[0] == "health" and not v.is_empty() and p.size() > 2 and p[2].is_valid_float():
			v["health"] = maxf(float(p[2]), 1.0)
			items._sync_vitals(peer, true)
		else:
			print("AUDIT control refused: %s" % line)
			continue

		print("AUDIT control %d %s" % [RobotRules.now_ms(), line])


# Every container's contents (by its world id, the id the clients know it by) when they change, and with control "count" the totals.
func _containers() -> void:
	var now: int = RobotRules.now_ms()
	var totals: Dictionary = {}

	for id in _count_ids:
		totals[items.table.number_of(id)] = 0

	# Without a count only the containers a player has open (a whole-world walk every 0.25 s would be a server hitch the audit then reads as animal faults).
	var ids: Array = items._items.keys() if not _count_ids.is_empty() else items._chest_viewer.values()

	for id in ids:
		var it: Dictionary = items._items.get(id, {})

		if it.is_empty():
			continue

		if not it.has("struct"):
			if totals.has(int(it.get("number", 0))) and Vector2((it["pos"] as Vector3).x, (it["pos"] as Vector3).z).distance_to(_count_at) <= COUNT_M:
				totals[int(it["number"])] += int(it.get("count", 1))

			continue

		var uid: Variant = (it["struct"] as Dictionary).get("uid", null)

		if uid == null or not items._chests.has(int(uid)):
			continue

		var box = items._chests[int(uid)]
		var sig: String = RobotRules.signature(box)

		if _chest_sig.get(id, "") != sig:
			_chest_sig[id] = sig
			print("AUDIT chest %d %d %s %d" % [int(id), now, sig, RobotRules.used(box)])

		_add_counts(box, totals)

	if totals.is_empty():
		return

	for peer in items.peer_ids():
		_add_counts(items.inventory_of(int(peer)), totals)

	var parts: PackedStringArray = PackedStringArray()

	for id in _count_ids:
		parts.append("%s:%d" % [id, int(totals[items.table.number_of(id)])])

	var said: String = " ".join(parts)

	if said != _total_said:
		_total_said = said
		print("AUDIT total %d %s" % [now, said])


static func _add_counts(inv, totals: Dictionary) -> void:
	if inv == null:
		return

	for s in range(inv.numbers.size()):
		if totals.has(int(inv.numbers[s])):
			totals[int(inv.numbers[s])] += int(inv.counts[s])


# A copy of a weather state with a hard frost (the original may be a cached dictionary: never changed).
static func _frost(w: Dictionary) -> Dictionary:
	var out: Dictionary = w.duplicate()
	out["temp_c"] = -25.0
	out["wind"] = 1.0
	return out


# Each snare set: `AUDIT snare <id> <unix ms> <x> <z> trail <0..1> owner <key>`, the trail share server_traps.trail_at gives it (catch
# chance and Tracking practice need on_trail_min / snare_min of it).
func _snares(now: int) -> void:
	var traps = items.get("_traps")

	if traps == null:
		return

	for id in items._items:
		if _snares_seen.has(id):
			continue

		var it: Dictionary = items._items[id]

		if str((it.get("struct", {}) as Dictionary).get("kind", "")) != "snare_trap":
			continue

		_snares_seen[id] = true
		var at: Vector3 = it["pos"]
		print("AUDIT snare %d %d %.1f %.1f trail %.2f owner %s" % [int(id), now, at.x, at.z, float(traps.trail_at(at)), str((it["struct"] as Dictionary).get("owner", ""))])
