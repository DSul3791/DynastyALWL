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
# Nothing changes in the game itself: no protocol change, and with the flag off this node is never made.

const RobotRules := preload("res://src/shared/robot_rules.gd")
const SIG_EVERY_S := 0.25
const ANIMAL_EVERY_S := 0.1
const INSIDE_M := 0.35          # a player capsule's radius is about 0.35 m; an animal's middle this close stands inside it
const JUMP_SLACK := 1.6         # an animal step may run this much over its top speed (a lunge, a server hitch) before it counts as a jump
const JUMP_FLOOR_M := 2.5       # steps shorter than this never count (a turn, a settle onto the ground)
const STEP_CAP_S := 1.0         # an animal steps at least once a second near a player (hz_mid 3); a longer still spell gives no allowance

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
